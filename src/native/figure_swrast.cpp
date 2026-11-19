// FIGURE's CPU renderer of Dear ImGui's draw data (figure_swrast.h): what imgui_impl_opengl3.cpp asks of a GPU, done
// on the CPU, for the pictures of headless and remote modes (#7 S1; the spike's measurements are in capture.md).
//
// The pipeline, as the OpenGL 3 backend sets it up:
//   - triangles from the index buffer, placed by the backend's orthographic projection and the viewport, no culling;
//   - the scissor rectangle of each command exactly as the backend computes it for glScissor (int truncation of its
//     corner and of its size);
//   - fragment = vertex colour (interpolated) * texel (RGBA8, clamp to edge);
//   - the sampler: linear by default (the backend's sampler object); after DrawCallback_SetSamplerFromTex the
//     texture's own filter (a user texture's `smooth`); after DrawCallback_ResetRenderState linear again;
//     DrawCallback_SetSamplerLinear and DrawCallback_SetSamplerNearest as named;
//   - blending rgb = src * a + dst * (1 - a) (glBlendFuncSeparate(SRC_ALPHA, ONE_MINUS_SRC_ALPHA, ...)) into an 8-bit
//     RGB framebuffer, rounded after every triangle, as a GL RGBA8 back buffer is.
// Rasterization: vertices placed as the backend's vertex shader and the viewport transform place them (single
// precision), snapped to 1/256 pixel (8 sub-pixel bits, as desktop GPUs), integer edge functions sampled
// at pixel centres, the image's top-left tie rule (a pixel centre exactly on an edge belongs to the triangle whose
// edge is a top or a left one, so two triangles sharing an edge never both draw it; the convention of Direct3D and of
// the GPU the spike measured), attributes interpolated by barycentric weights in single precision.
//
// The arithmetic is fixed: integers for coverage, and for colours the same float operations in the same order for
// every pixel, in every path (a flat triangle's table of results is those operations, done once per byte value). With
// the native layer built with -ffp-contract=off (no fused multiply-add), the picture is the same on every compiler,
// platform and thread count.
//
// Speed: rows are split in bands of BAND rows, rendered by default_threads() threads that take the next band in turn;
// every band runs every command in order, so each pixel sees the same blends in the same order whatever the split.
// Each row of a triangle is one span computed from the three edge functions (no per-pixel inside test), and a
// triangle of one colour and one texel (every rectangle and most text backgrounds) blends through a table of the 256
// results per channel.
//
// Vertices far outside the picture (beyond LIMIT pixels, where 64-bit edge functions would overflow) are first
// clipped against a guard band around the picture, in double precision, as a GPU's clipper does.
#include "figure_swrast.h"

#include "imgui_internal.h"

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <system_error>
#include <thread>
#include <vector>

namespace figure_swrast {

namespace {

constexpr long long SUB = 256;       // sub-pixel steps per pixel
constexpr bool      GL_TIES = false; // true: OpenGL's tie rule (top-left in its y-up window: bottom-left here), as
                                     // Mesa's llvmpipe; false: the image's top-left (Direct3D, the GPU measured)
constexpr double    LIMIT = 2097152.0; // [pixels] (2^21): beyond, a triangle is clipped first (64-bit products)
constexpr double    GUARD = 64.0;      // [pixels] the guard band around the picture that clipping keeps
constexpr int       BAND = 16;         // rows per band of work
constexpr int       MAX_THREADS = 64;

// The value of each byte in [0, 1], as the GPU reads an 8-bit channel.
struct unorm_t {
   float v[256];
   unorm_t() {
      for (int i = 0; i < 256; ++i) v[i] = static_cast<float>(i) * (1.0f / 255.0f);
   }
};
const unorm_t U8F;

inline unsigned char f2u8(float v) {
   v = v < 0.0f ? 0.0f : (v > 1.0f ? 1.0f : v);
   return static_cast<unsigned char>(v * 255.0f + 0.5f);
}

inline long long floor_div(long long a, long long b) { // b > 0
   return a >= 0 ? a / b : -((-a + b - 1) / b);
}
inline long long ceil_div(long long a, long long b) { return -floor_div(-a, b); } // b > 0

// A command's sampler: its texture and filter.
struct sampler_t {
   const texture_t *t = nullptr;
   bool             linear = true;

   void texel(int x, int y, float out[4]) const {
      if (t->channels == 1) {
         out[0] = out[1] = out[2] = 1.0f;
         out[3] = U8F.v[t->pixels[static_cast<size_t>(y) * t->width + x]];
         return;
      }
      const unsigned char *p = t->pixels + (static_cast<size_t>(y) * t->width + x) * 4;
      for (int c = 0; c < 4; ++c) out[c] = U8F.v[p[c]];
   }

   void sample(float u, float v, float out[4]) const {
      if (!t) {
         out[0] = 1.0f, out[1] = 0.0f, out[2] = 1.0f, out[3] = 1.0f; // magenta: a texture without pixels
         return;
      }
      const int w = t->width, h = t->height;
      if (!linear) {
         const int x = std::clamp(static_cast<int>(std::floor(u * static_cast<float>(w))), 0, w - 1);
         const int y = std::clamp(static_cast<int>(std::floor(v * static_cast<float>(h))), 0, h - 1);
         texel(x, y, out);
         return;
      }
      const float fx = u * static_cast<float>(w) - 0.5f, fy = v * static_cast<float>(h) - 0.5f;
      const float x0f = std::floor(fx), y0f = std::floor(fy);
      const float ax = fx - x0f, ay = fy - y0f;
      int x0 = static_cast<int>(x0f), y0 = static_cast<int>(y0f);
      const int x1 = std::clamp(x0 + 1, 0, w - 1), y1 = std::clamp(y0 + 1, 0, h - 1);
      x0 = std::clamp(x0, 0, w - 1), y0 = std::clamp(y0, 0, h - 1);
      float p00[4], p10[4], p01[4], p11[4];
      texel(x0, y0, p00), texel(x1, y0, p10), texel(x0, y1, p01), texel(x1, y1, p11);
      for (int c = 0; c < 4; ++c) {
         const float a = p00[c] + (p10[c] - p00[c]) * ax;
         const float b = p01[c] + (p11[c] - p01[c]) * ax;
         out[c] = a + (b - a) * ay;
      }
   }
};

// A vertex in the picture: position in fixed point, attributes.
struct fvtx_t {
   long long x = 0, y = 0;
   float     u = 0.0f, v = 0.0f, c[4] = {0.0f, 0.0f, 0.0f, 0.0f};
   bool      far = false; // beyond LIMIT (or not finite): its triangles are clipped first
};

// A draw command ready to draw: scissor [x0, x1) x [y0, y1) in pixels, its sampler, its triangles.
struct command_t {
   int                x0 = 0, y0 = 0, x1 = 0, y1 = 0;
   texture_t          tex;
   bool               has_tex = false;
   bool               linear = true;
   const ImDrawIdx   *idx = nullptr;
   unsigned int       count = 0;
   const fvtx_t      *vtx = nullptr;  // the list's vertices from the command's VtxOffset
   const ImDrawVert  *orig = nullptr; // the same, as Dear ImGui gave them (the clipped path)
};

struct frame_t {
   unsigned char *fb = nullptr;
   int            width = 0, height = 0;
   ImVec2         off, scale;
};

inline long long edge(const fvtx_t &a, const fvtx_t &b, long long px, long long py) {
   return (b.x - a.x) * (py - a.y) - (b.y - a.y) * (px - a.x);
}

// The edge a->b (positive area, y down) owns the pixel centres exactly on it.
inline bool owned(const fvtx_t &a, const fvtx_t &b) {
   const long long dx = b.x - a.x, dy = b.y - a.y;
   return GL_TIES ? (dy < 0 || (dy == 0 && dx < 0)) : (dy < 0 || (dy == 0 && dx > 0));
}

// One triangle, its rows within [ry0, ry1) and its columns within [rx0, rx1).
void triangle(const frame_t &f, int rx0, int ry0, int rx1, int ry1, fvtx_t A, fvtx_t B, fvtx_t C,
              const sampler_t &smp, stats_t &st) {
   long long area = edge(A, B, C.x, C.y);
   if (area == 0) return;
   if (area < 0) std::swap(B, C), area = -area;
   const long long minx = std::min({A.x, B.x, C.x}), maxx = std::max({A.x, B.x, C.x});
   const long long miny = std::min({A.y, B.y, C.y}), maxy = std::max({A.y, B.y, C.y});
   // the pixels whose centre ((p + 1/2) * SUB) is inside the bounding box
   const int px0 = static_cast<int>(std::max<long long>(rx0, ceil_div(minx - SUB / 2, SUB)));
   const int px1 = static_cast<int>(std::min<long long>(rx1 - 1, floor_div(maxx - SUB / 2, SUB)));
   const int py0 = static_cast<int>(std::max<long long>(ry0, ceil_div(miny - SUB / 2, SUB)));
   const int py1 = static_cast<int>(std::min<long long>(ry1 - 1, floor_div(maxy - SUB / 2, SUB)));
   if (px0 > px1 || py0 > py1) return;
   const long long b0 = owned(B, C) ? 0 : 1, b1 = owned(C, A) ? 0 : 1, b2 = owned(A, B) ? 0 : 1;
   const long long d0 = -(C.y - B.y) * SUB, d1 = -(A.y - C.y) * SUB, d2 = -(B.y - A.y) * SUB; // per pixel in x
   const long long kmax = px1 - px0;
   const long long cx0 = static_cast<long long>(px0) * SUB + SUB / 2;
   // the span of one row: k in [klo, khi] (pixels from px0) where every edge function is at least its bias
   auto span = [&](long long e0, long long e1, long long e2, long long &klo, long long &khi) {
      klo = 0, khi = kmax;
      const long long e[3] = {e0, e1, e2}, d[3] = {d0, d1, d2}, b[3] = {b0, b1, b2};
      for (int i = 0; i < 3; ++i) {
         if (d[i] > 0) klo = std::max(klo, ceil_div(b[i] - e[i], d[i]));
         else if (d[i] < 0) khi = std::min(khi, floor_div(e[i] - b[i], -d[i]));
         else if (e[i] < b[i]) khi = -1;
      }
   };
   const bool flat_uv = A.u == B.u && A.u == C.u && A.v == B.v && A.v == C.v;
   const bool flat_c = std::memcmp(A.c, B.c, sizeof A.c) == 0 && std::memcmp(A.c, C.c, sizeof A.c) == 0;
   float tex0[4] = {1.0f, 1.0f, 1.0f, 1.0f};
   if (flat_uv) smp.sample(A.u, A.v, tex0);
   if (flat_uv && flat_c) { // one colour: the same blend for every pixel, by the destination's byte
      const float a = A.c[3] * tex0[3];
      if (a <= 0.0f) return;
      float src[3];
      for (int c = 0; c < 3; ++c) src[c] = A.c[c] * tex0[c] * a;
      const float ia = 1.0f - a;
      const bool  table = static_cast<long long>(px1 - px0 + 1) * (py1 - py0 + 1) > 1536;
      unsigned char lut[3][256];
      if (table)
         for (int c = 0; c < 3; ++c)
            for (int i = 0; i < 256; ++i) lut[c][i] = f2u8(src[c] + U8F.v[i] * ia);
      for (int y = py0; y <= py1; ++y) {
         const long long cy = static_cast<long long>(y) * SUB + SUB / 2;
         long long klo, khi;
         span(edge(B, C, cx0, cy), edge(C, A, cx0, cy), edge(A, B, cx0, cy), klo, khi);
         if (klo > khi) continue;
         st.fragments += khi - klo + 1;
         unsigned char *d = f.fb + (static_cast<size_t>(y) * f.width + static_cast<size_t>(px0 + klo)) * 3;
         unsigned char *end = d + static_cast<size_t>(khi - klo + 1) * 3;
         if (table)
            for (; d != end; d += 3) d[0] = lut[0][d[0]], d[1] = lut[1][d[1]], d[2] = lut[2][d[2]];
         else
            for (; d != end; d += 3)
               for (int c = 0; c < 3; ++c) d[c] = f2u8(src[c] + U8F.v[d[c]] * ia);
      }
      return;
   }
   const float inv = 1.0f / static_cast<float>(area);
   for (int y = py0; y <= py1; ++y) {
      const long long cy = static_cast<long long>(y) * SUB + SUB / 2;
      const long long e0r = edge(B, C, cx0, cy), e1r = edge(C, A, cx0, cy), e2r = edge(A, B, cx0, cy);
      long long klo, khi;
      span(e0r, e1r, e2r, klo, khi);
      if (klo > khi) continue;
      st.fragments += khi - klo + 1;
      long long e0 = e0r + klo * d0, e1 = e1r + klo * d1;
      unsigned char *d = f.fb + (static_cast<size_t>(y) * f.width + static_cast<size_t>(px0 + klo)) * 3;
      for (long long k = klo; k <= khi; ++k, e0 += d0, e1 += d1, d += 3) {
         const float w0 = static_cast<float>(e0) * inv, w1 = static_cast<float>(e1) * inv;
         const float w2 = 1.0f - w0 - w1;
         float col[4], tex[4];
         if (flat_c) std::memcpy(col, A.c, sizeof col);
         else
            for (int c = 0; c < 4; ++c) col[c] = A.c[c] * w0 + B.c[c] * w1 + C.c[c] * w2;
         if (flat_uv) std::memcpy(tex, tex0, sizeof tex);
         else smp.sample(A.u * w0 + B.u * w1 + C.u * w2, A.v * w0 + B.v * w1 + C.v * w2, tex);
         const float a = col[3] * tex[3];
         if (a <= 0.0f) continue;
         for (int c = 0; c < 3; ++c) d[c] = f2u8(col[c] * tex[c] * a + U8F.v[d[c]] * (1.0f - a));
      }
   }
}

inline fvtx_t snap(double x, double y, float u, float v, const float c[4]) {
   fvtx_t f;
   f.x = std::llround(x * static_cast<double>(SUB));
   f.y = std::llround(y * static_cast<double>(SUB));
   f.u = u, f.v = v;
   std::memcpy(f.c, c, sizeof f.c);
   return f;
}

// A triangle with a vertex beyond LIMIT: clipped against the guard band in double precision (attributes
// interpolated linearly), then drawn as a fan.
void clipped_triangle(const frame_t &f, int rx0, int ry0, int rx1, int ry1, const ImDrawVert *v[3],
                      const sampler_t &smp, stats_t &st) {
   struct pv_t {
      double a[8]; // x, y, u, v, r, g, b, alpha
   };
   // a triangle clipped by 4 planes has at most 7 vertices: fixed arrays, no allocation on a worker thread
   struct poly_t {
      pv_t   v[8];
      size_t n = 0;
      void   push(const pv_t &p) { v[n++] = p; }
   };
   poly_t poly, next;
   for (int i = 0; i < 3; ++i) {
      pv_t p;
      p.a[0] = (static_cast<double>(v[i]->pos.x) - f.off.x) * f.scale.x;
      p.a[1] = (static_cast<double>(v[i]->pos.y) - f.off.y) * f.scale.y;
      if (!std::isfinite(p.a[0]) || !std::isfinite(p.a[1])) return;
      p.a[2] = v[i]->uv.x, p.a[3] = v[i]->uv.y;
      const ImU32 c = v[i]->col;
      p.a[4] = U8F.v[(c >> IM_COL32_R_SHIFT) & 0xFF], p.a[5] = U8F.v[(c >> IM_COL32_G_SHIFT) & 0xFF];
      p.a[6] = U8F.v[(c >> IM_COL32_B_SHIFT) & 0xFF], p.a[7] = U8F.v[(c >> IM_COL32_A_SHIFT) & 0xFF];
      poly.push(p);
   }
   const double lo[2] = {-GUARD, -GUARD}, hi[2] = {f.width + GUARD, f.height + GUARD};
   for (int plane = 0; plane < 4 && poly.n > 0; ++plane) {
      const int    axis = plane / 2;
      const bool   upper = plane % 2 == 1;
      const double bound = upper ? hi[axis] : lo[axis];
      auto inside = [&](const pv_t &p) { return upper ? p.a[axis] <= bound : p.a[axis] >= bound; };
      next.n = 0;
      for (size_t i = 0; i < poly.n; ++i) {
         const pv_t &p = poly.v[i], &q = poly.v[(i + 1) % poly.n];
         const bool pin = inside(p), qin = inside(q);
         if (pin) next.push(p);
         if (pin != qin) {
            const double t = (bound - p.a[axis]) / (q.a[axis] - p.a[axis]);
            pv_t r;
            for (int k = 0; k < 8; ++k) r.a[k] = p.a[k] + (q.a[k] - p.a[k]) * t;
            r.a[axis] = bound;
            next.push(r);
         }
      }
      poly = next;
   }
   if (poly.n < 3) return;
   auto vertex = [](const pv_t &p) {
      const float c[4] = {static_cast<float>(p.a[4]), static_cast<float>(p.a[5]), static_cast<float>(p.a[6]),
                          static_cast<float>(p.a[7])};
      return snap(p.a[0], p.a[1], static_cast<float>(p.a[2]), static_cast<float>(p.a[3]), c);
   };
   const fvtx_t first = vertex(poly.v[0]);
   for (size_t i = 1; i + 1 < poly.n; ++i)
      triangle(f, rx0, ry0, rx1, ry1, first, vertex(poly.v[i]), vertex(poly.v[i + 1]), smp, st);
}

// The rows [y0, y1) of every command, in order.
void band(const frame_t &f, const std::vector<command_t> &cmds, int y0, int y1, stats_t &st) {
   for (const command_t &cmd : cmds) {
      const int ry0 = std::max(y0, cmd.y0), ry1 = std::min(y1, cmd.y1);
      if (ry0 >= ry1) continue;
      sampler_t smp;
      smp.t = cmd.has_tex ? &cmd.tex : nullptr;
      smp.linear = cmd.linear;
      const long long top = static_cast<long long>(ry0) * SUB, bottom = static_cast<long long>(ry1) * SUB;
      for (unsigned int e = 0; e + 2 < cmd.count; e += 3) {
         const fvtx_t &A = cmd.vtx[cmd.idx[e]], &B = cmd.vtx[cmd.idx[e + 1]], &C = cmd.vtx[cmd.idx[e + 2]];
         if (A.far || B.far || C.far) {
            const ImDrawVert *v[3] = {cmd.orig + cmd.idx[e], cmd.orig + cmd.idx[e + 1], cmd.orig + cmd.idx[e + 2]};
            clipped_triangle(f, cmd.x0, ry0, cmd.x1, ry1, v, smp, st);
            continue;
         }
         // rows first: most triangles miss most bands
         if (std::max({A.y, B.y, C.y}) < top || std::min({A.y, B.y, C.y}) >= bottom) continue;
         triangle(f, cmd.x0, ry0, cmd.x1, ry1, A, B, C, smp, st);
      }
   }
}

} // namespace

int default_threads() {
   if (const char *v = std::getenv("FIGURE_RENDER_THREADS")) {
      const int n = std::atoi(v);
      if (n >= 1 && n <= MAX_THREADS) return n;
   }
   const unsigned int hw = std::thread::hardware_concurrency();
   return std::clamp(static_cast<int>(hw), 1, 8);
}

void render(const ImDrawData *dd, int width, int height, const float clear[3], std::vector<unsigned char> &rgb,
            lookup_t lookup, int threads, stats_t *stats) {
   stats_t total;
   if (width <= 0 || height <= 0) {
      rgb.clear();
      if (stats) *stats = total;
      return;
   }
   rgb.resize(static_cast<size_t>(width) * height * 3);
   const unsigned char cc[3] = {f2u8(clear[0]), f2u8(clear[1]), f2u8(clear[2])};
   for (size_t i = 0; i < rgb.size(); i += 3) rgb[i] = cc[0], rgb[i + 1] = cc[1], rgb[i + 2] = cc[2];
   if (!dd || !dd->Valid) {
      if (stats) *stats = total;
      return;
   }
   frame_t f;
   f.fb = rgb.data(), f.width = width, f.height = height;
   f.off = dd->DisplayPos, f.scale = dd->FramebufferScale;
   const ImGuiPlatformIO &pio = ImGui::GetPlatformIO();
   // imgui_impl_opengl3.cpp's orthographic projection (x: L to R, y: T to B onto -1 to 1, top up)
   const float L = dd->DisplayPos.x, R = dd->DisplayPos.x + dd->DisplaySize.x;
   const float T = dd->DisplayPos.y, B = dd->DisplayPos.y + dd->DisplaySize.y;
   const float proj[4] = {2.0f / (R - L), (R + L) / (L - R), 2.0f / (T - B), (T + B) / (B - T)};
   const float half_w = 0.5f * static_cast<float>(width), half_h = 0.5f * static_cast<float>(height);
   // the vertices of every list in the picture's fixed point, and the commands with their state, in order
   std::vector<std::vector<fvtx_t>> verts(static_cast<size_t>(dd->CmdLists.Size));
   std::vector<command_t> cmds;
   bool linear = true, from_tex = false;
   for (int l = 0; l < dd->CmdLists.Size; ++l) {
      const ImDrawList *dl = dd->CmdLists[l];
      std::vector<fvtx_t> &tv = verts[static_cast<size_t>(l)];
      tv.resize(static_cast<size_t>(dl->VtxBuffer.Size));
      for (int i = 0; i < dl->VtxBuffer.Size; ++i) {
         const ImDrawVert &v = dl->VtxBuffer[i];
         fvtx_t &t = tv[static_cast<size_t>(i)];
         // the backend's vertex shader, ProjMtx * (pos, 0, 1), in single precision, then the viewport transform
         // xw = (width / 2) xd + width / 2 (yw likewise, counted from the bottom): where a GPU puts the vertex before
         // it snaps it (the exact (pos - DisplayPos) * scale differs by a rounding, which moves a tie)
         const float nx = proj[0] * v.pos.x + proj[1], ny = proj[2] * v.pos.y + proj[3];
         const double x = static_cast<double>(nx * half_w + half_w);
         const double y = static_cast<double>(static_cast<float>(height) - (ny * half_h + half_h));
         t.far = !(std::fabs(x) <= LIMIT && std::fabs(y) <= LIMIT); // NaN too
         if (!t.far) t.x = std::llround(x * static_cast<double>(SUB)), t.y = std::llround(y * static_cast<double>(SUB));
         t.u = v.uv.x, t.v = v.uv.y;
         const ImU32 c = v.col;
         t.c[0] = U8F.v[(c >> IM_COL32_R_SHIFT) & 0xFF], t.c[1] = U8F.v[(c >> IM_COL32_G_SHIFT) & 0xFF];
         t.c[2] = U8F.v[(c >> IM_COL32_B_SHIFT) & 0xFF], t.c[3] = U8F.v[(c >> IM_COL32_A_SHIFT) & 0xFF];
      }
      for (const ImDrawCmd &cmd : dl->CmdBuffer) {
         if (cmd.UserCallback) {
            ++total.callbacks;
            if (cmd.UserCallback == pio.DrawCallback_ResetRenderState) linear = true, from_tex = false;
            else if (cmd.UserCallback == pio.DrawCallback_SetSamplerFromTex) from_tex = true;
            else if (cmd.UserCallback == pio.DrawCallback_SetSamplerLinear) linear = true, from_tex = false;
            else if (cmd.UserCallback == pio.DrawCallback_SetSamplerNearest) linear = false, from_tex = false;
            continue; // a program's own callback draws nothing here
         }
         if (cmd.ElemCount < 3) continue;
         const ImVec2 cmin((cmd.ClipRect.x - f.off.x) * f.scale.x, (cmd.ClipRect.y - f.off.y) * f.scale.y);
         const ImVec2 cmax((cmd.ClipRect.z - f.off.x) * f.scale.x, (cmd.ClipRect.w - f.off.y) * f.scale.y);
         if (cmax.x <= cmin.x || cmax.y <= cmin.y) continue;
         // the backend's glScissor(x, fb_height - max.y, max.x - min.x, max.y - min.y), back in rows from the top
         const int gx = static_cast<int>(cmin.x), gw = static_cast<int>(cmax.x - cmin.x);
         const int gy = static_cast<int>(static_cast<float>(height) - cmax.y), gh = static_cast<int>(cmax.y - cmin.y);
         command_t c;
         c.x0 = std::max(0, gx), c.x1 = std::min(width, gx + gw);
         c.y0 = std::max(0, height - (gy + gh)), c.y1 = std::min(height, height - gy);
         if (c.x0 >= c.x1 || c.y0 >= c.y1) continue;
         const ImTextureData *td = cmd.TexRef._TexData;
         if (td) { // Dear ImGui's own texture (the font atlas): its pixels, linear
            if (td->Pixels && (td->Format == ImTextureFormat_RGBA32 || td->Format == ImTextureFormat_Alpha8)) {
               c.tex.width = td->Width, c.tex.height = td->Height;
               c.tex.channels = td->Format == ImTextureFormat_Alpha8 ? 1 : 4;
               c.tex.pixels = td->Pixels;
               c.tex.smooth = true;
               c.has_tex = true;
            }
         } else if (lookup && lookup(cmd.TexRef._TexID, &c.tex)) {
            c.has_tex = c.tex.pixels && c.tex.width > 0 && c.tex.height > 0 &&
                        (c.tex.channels == 1 || c.tex.channels == 4);
         }
         if (!c.has_tex) ++total.unknown_textures;
         c.linear = from_tex ? (c.has_tex ? c.tex.smooth : true) : linear;
         c.idx = dl->IdxBuffer.Data + cmd.IdxOffset;
         c.count = cmd.ElemCount;
         c.vtx = tv.data() + cmd.VtxOffset;
         c.orig = dl->VtxBuffer.Data + cmd.VtxOffset;
         total.triangles += cmd.ElemCount / 3;
         cmds.push_back(c);
      }
   }
   const int nbands = (height + BAND - 1) / BAND;
   const int n = std::clamp(threads > 0 ? threads : default_threads(), 1, std::min(MAX_THREADS, nbands));
   std::vector<stats_t> part(static_cast<size_t>(n));
   std::atomic<int> next{0};
   auto work = [&](int t) {
      for (int b; (b = next.fetch_add(1)) < nbands;)
         band(f, cmds, b * BAND, std::min(height, (b + 1) * BAND), part[static_cast<size_t>(t)]);
   };
   std::vector<std::thread> pool;
   for (int t = 1; t < n; ++t) {
      try {
         pool.emplace_back(work, t);
      } catch (const std::system_error &) { // no more threads: the others (and this one) take its bands
         break;
      }
   }
   work(0);
   for (std::thread &t : pool) t.join();
   for (const stats_t &p : part) total.fragments += p.fragments;
   if (stats) *stats = total;
}

} // namespace figure_swrast
