// FIGURE's 3-D view: a software rasterizer (see figure_view3d.h, and docs/guide/view3d.md).
//
// A render, when something changed:
//   1. transform: each visible mesh's vertices (the program's real64 array, read in place) to clip space by one 4x4
//      matrix, with a colour (the colormap of the vertex scalar, or the mesh's colour) and a two-sided headlight term;
//   2. triangles: rejected when outside a clipping plane, clipped against the near plane in clip space (a polygon of up
//      to 4 vertices, drawn as a fan), then rasterized by edge functions over their bounding box with the top-left rule
//      (no pixel drawn twice along a shared edge): a float z-buffer, an id buffer (the triangle under each pixel, for
//      picking), Gouraud or flat shading, and the clipping planes tested per pixel (perspective-correct) only for the
//      triangles that cross one;
//   3. lines (line meshes and surface edges): clipped against the planes in world space and the near plane in clip
//      space, drawn one pixel wide, depth-tested with a small bias, without writing depth or ids.
// Stages 1 and 2-3 split over the view's threads: vertex ranges, then bands of rows (no pixel shared). The result is
// uploaded into a texture (FIGURE's user textures: GL in a window, sent to the browser in remote mode, ids only in
// headless mode) and drawn as an image; while the user moves the camera, at half resolution if asked (a second
// texture, linear filtering), at full resolution again when the move ends.
#include "figure_native.h"
#include "figure_view3d.h"

#include "imgui.h"
#include "imgui_internal.h"
#include "implot.h"

#include "ImGuizmo.h"

#include <SDL3/SDL.h>

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <functional>
#include <limits>
#include <map>
#include <memory>
#include <string>
#include <vector>
#if defined(__GLIBC__)
#include <malloc.h> // malloc_trim
#endif

namespace {

constexpr float AMBIENT = 0.25f;     // light where a surface is seen edge-on
constexpr int MAX_PLANES = 6;        // clipping planes
constexpr int MAX_THREADS = 4;       // the band split gains nothing beyond (S15 spike)
constexpr float LINE_BIAS = 2.0e-3f; // NDC depth by which lines come forward of the surfaces they lie on
constexpr double PI = 3.14159265358979323846;
constexpr double DEG = PI / 180.0;

int fail(int status, const std::string &msg) {
   fig_set_last_error(msg.c_str(), static_cast<int>(msg.size()));
   return status;
}

// ---- data --------------------------------------------------------------------------------------------------------

enum kind_t { TRIANGLES = 0, QUADS = 1, SURFACE = 2, LINES = 3 };

struct vtx_t {
   float cx, cy, cz, cw; // clip space
   float r, g, b;        // base colour [0, 255]
   float l;              // light
   float wx, wy, wz;     // world (clipping planes)
   // derived by project (not interpolated): outside which clip-space planes, and inside them the screen position in
   // fixed point (1/SUB pixel), the NDC depth and 1/w
   uint32_t code;
   int32_t  X, Y;
   float    sz, iw;
};

struct mesh_t {
   int              id = 0;
   int              kind = TRIANGLES;
   const double    *xyz = nullptr;
   int64_t          nv = 0;
   const int32_t   *conn = nullptr;
   int64_t          ncell = 0;
   int              ni = 0, nj = 0;
   const double    *scalar = nullptr;
   int64_t          nscalar = 0;
   bool             on_cells = false;
   std::string      colormap = "cividis";
   uint8_t          table[256][3] = {};
   bool             table_ok = false;
   bool             auto_range = true;
   double           vmin = 0.0, vmax = 1.0; // in effect
   float            color[3] = {200.0f, 200.0f, 200.0f};
   bool             edges = false;
   float            edge_color[3] = {20.0f, 20.0f, 20.0f};
   bool             flat = false;
   bool             visible = true;
   // derived, once per change
   std::vector<int32_t> tri;  // 0-based, 3 per triangle
   std::vector<int32_t> seg;  // 0-based, 2 per segment (lines, or edges)
   std::vector<int32_t> seg_cell; // the segment's cell (lines with cell scalars)
   std::vector<float>   nrm;  // vertex normals
   double               lo[3] = {0, 0, 0}, hi[3] = {0, 0, 0}; // bounding box
   double               dmin = 0.0, dmax = 1.0;                // the scalar's range
   // per render
   std::vector<vtx_t>   sv;
   int32_t              base = 0; // first id of its triangles in the id buffer
   int cells_per_tri() const { return kind == TRIANGLES ? 1 : 2; }
};

struct camera_t {
   double target[3] = {0, 0, 0};
   double distance = 1.0, azimuth = -60.0, elevation = 25.0, fov = 30.0;
};

struct plane_t {
   double n[3], c; // n . x >= c kept
};

struct pick_t {
   int     hit = 0, mesh = 0;
   int64_t element = 0;
   double  point[3] = {0, 0, 0};
};

struct view_t {
   int                    threads = 1;
   bool                   fast_moves = true, lighting = true;
   bool                   own_background = false;
   float                  background[3] = {0, 0, 0};
   std::vector<std::unique_ptr<mesh_t>> meshes;
   int                    next_mesh = 1;
   camera_t               cam;
   bool                   camera_set = false; // false: fitted at the first render with a mesh
   std::vector<plane_t>   planes;
   bool                   dirty = true;
   int                    idle_draws = 0;   // draws since the last render (the vertex caches freed at IDLE_RELEASE)
   // the last render
   int                    rw = 0, rh = 0;   // its size [pixels]
   bool                   half = false;
   int                    vw = 0, vh = 0;   // the widget's size [pixels]
   std::vector<uint8_t>   rgba;
   std::vector<float>     depth;
   std::vector<int32_t>   ids;
   double                 mvp[16] = {};
   double                 inv[16] = {};
   std::vector<std::pair<int32_t, int>> bases; // (first id, mesh index) of the meshes drawn
   int                    renders = 0;
   double                 ms = 0.0;
   unsigned long long     tex_full = 0, tex_half = 0;
   int                    tex_full_w = 0, tex_full_h = 0, tex_half_w = 0, tex_half_h = 0;
   pick_t                 hovered, clicked;
   bool                   moving = false;
   unsigned               colormaps = 0;    // fig_colormap_generation at the last table loads
   // the gizmos drawn over the image (fig_view3d_cube, fig_view3d_gizmo)
   ImVec2                 image_pos{0, 0};  // the image's top-left corner [pixels] at the last draw
   int                    image_frame = -1; // ... its Dear ImGui frame
   ImGuiID                image_window = 0; // ... its window
   ImVec2                 cube_min{0, 0}, cube_max{0, 0}; // the view cube's rectangle, from the image's corner
   int                    cube_frame = -10; // the last frame it was drawn
   int                    overlay_frame = -10; // the last frame a gizmo or the cube was hovered or in use
   bool                   cube_moved = false;  // the cube turned the camera (the next draw: a move)
};

std::map<int, std::unique_ptr<view_t>> views;
int next_view = 1;

view_t *find(int handle) {
   const auto it = views.find(handle);
   return it == views.end() ? nullptr : it->second.get();
}

mesh_t *find_mesh(view_t &v, int id) {
   for (auto &m : v.meshes)
      if (m->id == id) return m.get();
   return nullptr;
}

// ---- threads -----------------------------------------------------------------------------------------------------

struct job_t {
   const std::function<void(int)> *fn;
   int                             i;
};

int SDLCALL run_job(void *p) {
   const job_t *j = static_cast<const job_t *>(p);
   (*j->fn)(j->i);
   return 0;
}

// fn(0..n-1), on n threads (the caller's one of them); a part whose thread cannot be made runs on the caller's.
void parallel(int n, const std::function<void(int)> &fn) {
   if (n <= 1) {
      fn(0);
      return;
   }
   std::vector<job_t> jobs(static_cast<size_t>(n));
   std::vector<SDL_Thread *> th(static_cast<size_t>(n), nullptr);
   for (int i = 1; i < n; ++i) {
      jobs[i] = {&fn, i};
      th[i] = SDL_CreateThread(run_job, "figure_view3d", &jobs[i]);
   }
   fn(0);
   for (int i = 1; i < n; ++i) {
      if (th[i])
         SDL_WaitThread(th[i], nullptr);
      else
         fn(i);
   }
}

// ---- matrices ----------------------------------------------------------------------------------------------------

// The camera's basis: forward f (eye to target), right r (horizontal), up u.
void basis(const camera_t &c, double f[3], double r[3], double u[3]) {
   const double ca = std::cos(c.azimuth * DEG), sa = std::sin(c.azimuth * DEG);
   const double ce = std::cos(c.elevation * DEG), se = std::sin(c.elevation * DEG);
   f[0] = -ce * ca, f[1] = -ce * sa, f[2] = -se;
   r[0] = -sa, r[1] = ca, r[2] = 0.0;
   u[0] = r[1] * f[2] - r[2] * f[1], u[1] = r[2] * f[0] - r[0] * f[2], u[2] = r[0] * f[1] - r[1] * f[0];
}

void eye_of(const camera_t &c, double e[3]) {
   double f[3], r[3], u[3];
   basis(c, f, r, u);
   for (int d = 0; d < 3; ++d) e[d] = c.target[d] - c.distance * f[d];
}

// m = a * b, column-major 4x4.
void mul(const double a[16], const double b[16], double m[16]) {
   for (int c = 0; c < 4; ++c)
      for (int r = 0; r < 4; ++r) {
         double s = 0.0;
         for (int k = 0; k < 4; ++k) s += a[k * 4 + r] * b[c * 4 + k];
         m[c * 4 + r] = s;
      }
}

bool invert(const double m[16], double o[16]) { // Gauss-Jordan, partial pivoting
   double a[4][8];
   for (int r = 0; r < 4; ++r)
      for (int c = 0; c < 4; ++c) a[r][c] = m[c * 4 + r], a[r][c + 4] = (r == c) ? 1.0 : 0.0;
   for (int c = 0; c < 4; ++c) {
      int p = c;
      for (int r = c + 1; r < 4; ++r)
         if (std::fabs(a[r][c]) > std::fabs(a[p][c])) p = r;
      if (std::fabs(a[p][c]) < 1e-300) return false;
      if (p != c)
         for (int k = 0; k < 8; ++k) std::swap(a[p][k], a[c][k]);
      const double d = a[c][c];
      for (int k = 0; k < 8; ++k) a[c][k] /= d;
      for (int r = 0; r < 4; ++r)
         if (r != c) {
            const double f = a[r][c];
            for (int k = 0; k < 8; ++k) a[r][k] -= f * a[c][k];
         }
   }
   for (int r = 0; r < 4; ++r)
      for (int c = 0; c < 4; ++c) o[c * 4 + r] = a[r][c + 4];
   return true;
}

// The bounding sphere of the visible meshes; false if none.
bool bounds(const view_t &v, double ctr[3], double &radius) {
   double lo[3] = {1e300, 1e300, 1e300}, hi[3] = {-1e300, -1e300, -1e300};
   bool any = false;
   for (const auto &m : v.meshes) {
      if (!m->visible || m->nv == 0) continue;
      any = true;
      for (int d = 0; d < 3; ++d) lo[d] = std::min(lo[d], m->lo[d]), hi[d] = std::max(hi[d], m->hi[d]);
   }
   if (!any) return false;
   double r2 = 0.0;
   for (int d = 0; d < 3; ++d) ctr[d] = 0.5 * (lo[d] + hi[d]), r2 += 0.25 * (hi[d] - lo[d]) * (hi[d] - lo[d]);
   radius = std::sqrt(r2);
   if (radius <= 0.0) radius = 1.0;
   return true;
}

void fit(view_t &v, double aspect) {
   double ctr[3], radius;
   if (!bounds(v, ctr, radius)) return;
   for (int d = 0; d < 3; ++d) v.cam.target[d] = ctr[d];
   const double half_y = 0.5 * v.cam.fov * DEG;
   const double half_x = std::atan(std::tan(half_y) * (aspect > 0.0 ? aspect : 1.0));
   v.cam.distance = radius / std::sin(std::min(half_x, half_y));
   v.camera_set = true;
}

// The view V and the projection P for a w x h target (column-major, OpenGL's conventions: a right-handed eye space
// looking down -z, clip z in [-w, w]); near and far from the bounding sphere.
void view_projection(const view_t &v, int w, int h, double V[16], double P[16]) {
   double f[3], r[3], u[3], e[3];
   basis(v.cam, f, r, u);
   eye_of(v.cam, e);
   const double Vr[16] = {r[0], u[0], -f[0], 0, r[1], u[1], -f[1], 0, r[2], u[2], -f[2], 0, 0, 0, 0, 1};
   std::memcpy(V, Vr, sizeof Vr);
   V[12] = -(r[0] * e[0] + r[1] * e[1] + r[2] * e[2]);
   V[13] = -(u[0] * e[0] + u[1] * e[1] + u[2] * e[2]);
   V[14] = f[0] * e[0] + f[1] * e[1] + f[2] * e[2];
   double ctr[3] = {0, 0, 0}, radius = 1.0;
   bounds(v, ctr, radius);
   const double dc = (ctr[0] - e[0]) * f[0] + (ctr[1] - e[1]) * f[1] + (ctr[2] - e[2]) * f[2]; // centre's depth
   double zf = dc + radius * 1.01;
   double zn = dc - radius * 1.01;
   if (zf <= 0.0) zf = 1.0;
   zn = std::max(zn, zf * 1.0e-4); // the eye inside the sphere: a near plane close to it
   const double t = 1.0 / std::tan(0.5 * v.cam.fov * DEG), aspect = static_cast<double>(w) / h;
   const double Pr[16] = {t / aspect, 0, 0, 0, 0, t, 0, 0, 0, 0, (zf + zn) / (zn - zf), -1, 0, 0, 2 * zf * zn / (zn - zf), 0};
   std::memcpy(P, Pr, sizeof Pr);
}

// projection * view for a w x h target.
void matrices(const view_t &v, int w, int h, double mvp[16]) {
   double V[16], P[16];
   view_projection(v, w, h, V, P);
   mul(P, V, mvp);
}

// ---- colours -----------------------------------------------------------------------------------------------------

// The 256 colours of the mesh's colormap (ImPlot's registry: fig_colormap registers bundled and user maps).
void load_table(mesh_t &m) {
   int id = -1;
   if (fig_colormap(m.colormap.c_str(), static_cast<int>(m.colormap.size()), 0, &id) != FIG_OK || id < 0) {
      for (int k = 0; k < 256; ++k) m.table[k][0] = m.table[k][1] = m.table[k][2] = static_cast<uint8_t>(k);
   } else {
      for (int k = 0; k < 256; ++k) {
         const ImVec4 c = ImPlot::SampleColormap(static_cast<float>(k) / 255.0f, id);
         m.table[k][0] = static_cast<uint8_t>(std::lround(std::clamp(c.x, 0.0f, 1.0f) * 255.0f));
         m.table[k][1] = static_cast<uint8_t>(std::lround(std::clamp(c.y, 0.0f, 1.0f) * 255.0f));
         m.table[k][2] = static_cast<uint8_t>(std::lround(std::clamp(c.z, 0.0f, 1.0f) * 255.0f));
      }
   }
   m.table_ok = true;
}

inline void scalar_colour(const mesh_t &m, double s, float out[3]) {
   if (!std::isfinite(s)) { // NaN: grey
      out[0] = out[1] = out[2] = 128.0f;
      return;
   }
   const double span = m.vmax > m.vmin ? m.vmax - m.vmin : 1.0;
   double t = (s - m.vmin) / span;
   t = t < 0.0 ? 0.0 : (t > 1.0 ? 1.0 : t);
   const int k = static_cast<int>(t * 255.0 + 0.5);
   out[0] = m.table[k][0], out[1] = m.table[k][1], out[2] = m.table[k][2];
}

// ---- derived data ------------------------------------------------------------------------------------------------

int derive(mesh_t &m) {
   m.tri.clear();
   m.seg.clear();
   m.seg_cell.clear();
   const int64_t nv = m.nv;
   auto bad = [&](int64_t c) {
      return fail(FIG_ERR_ARGUMENT, "view3d: connectivity of cell " + std::to_string(c + 1) + " outside 1.." +
                                        std::to_string(nv));
   };
   if (m.kind == TRIANGLES || m.kind == QUADS) {
      const int per = m.kind == TRIANGLES ? 3 : 4;
      m.tri.reserve(static_cast<size_t>(m.ncell) * (per == 4 ? 6 : 3));
      if (m.edges) m.seg.reserve(static_cast<size_t>(m.ncell) * 2 * per);
      for (int64_t c = 0; c < m.ncell; ++c) {
         int32_t k[4];
         for (int i = 0; i < per; ++i) {
            k[i] = m.conn[per * c + i] - 1;
            if (k[i] < 0 || k[i] >= nv) return bad(c);
         }
         m.tri.insert(m.tri.end(), {k[0], k[1], k[2]});
         if (per == 4) m.tri.insert(m.tri.end(), {k[0], k[2], k[3]});
         if (m.edges)
            for (int i = 0; i < per; ++i) m.seg.insert(m.seg.end(), {k[i], k[(i + 1) % per]});
      }
   } else if (m.kind == SURFACE) {
      const int ni = m.ni, nj = m.nj;
      const size_t cells = static_cast<size_t>(std::max(ni - 1, 0)) * std::max(nj - 1, 0);
      m.tri.reserve(6 * cells);
      if (m.edges)
         m.seg.reserve(2 * (static_cast<size_t>(std::max(ni - 1, 0)) * nj + static_cast<size_t>(ni) * std::max(nj - 1, 0)));
      for (int j = 0; j + 1 < nj; ++j)
         for (int i = 0; i + 1 < ni; ++i) {
            const int32_t a = i + j * ni, b = a + 1, c = a + 1 + ni, d = a + ni;
            m.tri.insert(m.tri.end(), {a, b, c, a, c, d});
         }
      if (m.edges) {
         for (int j = 0; j < nj; ++j)
            for (int i = 0; i + 1 < ni; ++i) m.seg.insert(m.seg.end(), {i + j * ni, i + 1 + j * ni});
         for (int i = 0; i < ni; ++i)
            for (int j = 0; j + 1 < nj; ++j) m.seg.insert(m.seg.end(), {i + j * ni, i + (j + 1) * ni});
      }
   } else { // lines
      const size_t ns = m.conn ? static_cast<size_t>(m.ncell) : static_cast<size_t>(std::max<int64_t>(m.nv - 1, 0));
      m.seg.reserve(2 * ns);
      m.seg_cell.reserve(ns);
      if (m.conn) {
         for (int64_t c = 0; c < m.ncell; ++c) {
            const int32_t a = m.conn[2 * c] - 1, b = m.conn[2 * c + 1] - 1;
            if (a < 0 || a >= nv || b < 0 || b >= nv) return bad(c);
            m.seg.insert(m.seg.end(), {a, b});
            m.seg_cell.push_back(static_cast<int32_t>(c));
         }
      } else {
         for (int64_t i = 0; i + 1 < nv; ++i) {
            m.seg.insert(m.seg.end(), {static_cast<int32_t>(i), static_cast<int32_t>(i + 1)});
            m.seg_cell.push_back(static_cast<int32_t>(i));
         }
      }
   }
   // bounding box
   for (int d = 0; d < 3; ++d) m.lo[d] = 1e300, m.hi[d] = -1e300;
   for (int64_t i = 0; i < nv; ++i)
      for (int d = 0; d < 3; ++d) {
         const double x = m.xyz[3 * i + d];
         if (std::isfinite(x)) m.lo[d] = std::min(m.lo[d], x), m.hi[d] = std::max(m.hi[d], x);
      }
   for (int d = 0; d < 3; ++d)
      if (m.lo[d] > m.hi[d]) m.lo[d] = m.hi[d] = 0.0;
   // vertex normals, area-weighted
   m.nrm.assign(m.kind == LINES ? 0 : 3 * static_cast<size_t>(nv), 0.0f);
   const size_t nt = m.tri.size() / 3;
   for (size_t t = 0; t < nt; ++t) {
      const int32_t *k = &m.tri[3 * t];
      const double *a = m.xyz + 3 * static_cast<int64_t>(k[0]), *b = m.xyz + 3 * static_cast<int64_t>(k[1]);
      const double *c = m.xyz + 3 * static_cast<int64_t>(k[2]);
      const double u[3] = {b[0] - a[0], b[1] - a[1], b[2] - a[2]}, w[3] = {c[0] - a[0], c[1] - a[1], c[2] - a[2]};
      const double n[3] = {u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0]};
      for (int i = 0; i < 3; ++i)
         for (int d = 0; d < 3; ++d) m.nrm[3 * static_cast<size_t>(k[i]) + d] += static_cast<float>(n[d]);
   }
   for (size_t i = 0; i < m.nrm.size(); i += 3) {
      float *n = &m.nrm[i];
      const float s = std::sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]);
      if (s > 0.0f) n[0] /= s, n[1] /= s, n[2] /= s;
   }
   // the scalar's range
   m.dmin = 0.0, m.dmax = 1.0;
   if (m.scalar) {
      double lo = 1e300, hi = -1e300;
      for (int64_t i = 0; i < m.nscalar; ++i)
         if (std::isfinite(m.scalar[i])) lo = std::min(lo, m.scalar[i]), hi = std::max(hi, m.scalar[i]);
      if (lo <= hi) m.dmin = lo, m.dmax = hi;
   }
   if (m.auto_range) m.vmin = m.dmin, m.vmax = m.dmax;
   return FIG_OK;
}

int64_t cells_of(const mesh_t &m) {
   if (m.kind == SURFACE) return static_cast<int64_t>(std::max(m.ni - 1, 0)) * std::max(m.nj - 1, 0);
   if (m.kind == LINES) return m.conn ? m.ncell : std::max<int64_t>(m.nv - 1, 0);
   return m.ncell;
}

// ---- rasterization -----------------------------------------------------------------------------------------------

struct frame_t { // what every band needs
   int                   w, h;
   uint8_t              *rgba;
   float                *depth;
   int32_t              *ids;
   float                 eye_dir[3];
   bool                  lighting;
   std::vector<plane_t>  planes;
};

inline float plane_d(const plane_t &p, const vtx_t &v) {
   return static_cast<float>(p.n[0] * v.wx + p.n[1] * v.wy + p.n[2] * v.wz - p.c);
}

vtx_t lerp(const vtx_t &a, const vtx_t &b, float t) {
   vtx_t o;
   const float *pa = &a.cx, *pb = &b.cx;
   float *po = &o.cx;
   for (int i = 0; i < 11; ++i) po[i] = pa[i] + t * (pb[i] - pa[i]);
   return o;
}

// The clip-space planes a polygon is clipped against: the near plane (z >= -w) and a guard band of GUARD times the
// viewport on each side (|x|, |y| <= GUARD w), which keeps screen coordinates small enough for exact fixed-point edges.
constexpr float GUARD = 2.0f;
constexpr int CLIP_PLANES = 5;
inline float clip_d(const vtx_t &v, int p) {
   switch (p) {
   case 0: return v.cz + v.cw;
   case 1: return GUARD * v.cw + v.cx;
   case 2: return GUARD * v.cw - v.cx;
   case 3: return GUARD * v.cw + v.cy;
   default: return GUARD * v.cw - v.cy;
   }
}

// The point where edge (in, out) crosses a plane, always interpolated from the inside vertex: two triangles sharing
// the edge get the same bits, so no crack opens between them.
inline vtx_t cross_at(const vtx_t &in, float din, const vtx_t &out, float dout) {
   return lerp(in, out, din / (din - dout));
}

constexpr int SUB = 16; // sub-pixel steps of the fixed-point edge functions

// The clip-space planes v is outside of (bits 0..4), and its screen position when inside all of them (or when
// `always`: a vertex made by clipping, inside up to rounding).
inline void project(vtx_t &v, float hw, float hh, bool always) {
   v.code = 0;
   for (int p = 0; p < CLIP_PLANES; ++p)
      if (clip_d(v, p) < 0.0f) v.code |= 1u << p;
   if ((v.code && !always) || !(v.cw > 0.0f)) return;
   v.iw = 1.0f / v.cw;
   v.X = static_cast<int32_t>(std::lrint((v.cx * v.iw + 1.0f) * hw * SUB));
   v.Y = static_cast<int32_t>(std::lrint((1.0f - v.cy * v.iw) * hh * SUB));
   v.sz = v.cz * v.iw;
}

// One triangle inside the guard band, clipped to rows [y0, y1). Edge functions in exact integers (1/SUB pixel): a
// pixel centre on an edge shared by two triangles belongs to exactly one, by the top-left rule.
void raster(const frame_t &F, int y0, int y1, const vtx_t &A, const vtx_t &B, const vtx_t &C, int32_t id,
            unsigned partial) {
   const vtx_t *v[3] = {&A, &B, &C};
   const int64_t X[3] = {A.X, B.X, C.X}, Y[3] = {A.Y, B.Y, C.Y};
   const float sz[3] = {A.sz, B.sz, C.sz}, iw[3] = {A.iw, B.iw, C.iw};
   int64_t area = (X[1] - X[0]) * (Y[2] - Y[0]) - (Y[1] - Y[0]) * (X[2] - X[0]);
   if (area == 0) return;
   int o[3] = {0, 1, 2};
   if (area < 0) std::swap(o[1], o[2]), area = -area; // two-sided: one winding
   const int a = o[0], b = o[1], c = o[2];
   // pixels whose centre (x + 1/2, y + 1/2) may lie inside
   const int64_t minx = std::min({X[0], X[1], X[2]}), maxx = std::max({X[0], X[1], X[2]});
   const int64_t miny = std::min({Y[0], Y[1], Y[2]}), maxy = std::max({Y[0], Y[1], Y[2]});
   const auto floor_div = [](int64_t q) { return q >= 0 ? q / SUB : -((-q + SUB - 1) / SUB); };
   const auto lo_px = [&](int64_t q) { return static_cast<int>(-floor_div(-(q - SUB / 2))); }; // ceil
   const auto hi_px = [&](int64_t q) { return static_cast<int>(floor_div(q - SUB / 2)); };
   const int ix0 = std::max(0, lo_px(minx)), ix1 = std::min(F.w - 1, hi_px(maxx));
   const int iy0 = std::max(y0, lo_px(miny)), iy1 = std::min(y1 - 1, hi_px(maxy));
   if (ix0 > ix1 || iy0 > iy1) return;
   float col[3][3];
   for (int i = 0; i < 3; ++i) col[i][0] = v[i]->r * v[i]->l, col[i][1] = v[i]->g * v[i]->l, col[i][2] = v[i]->b * v[i]->l;
   // per-pixel plane distances, perspective-correct: the sign of sum l_i d_i / w_i (the w_i are positive)
   int np = 0;
   float pd[MAX_PLANES][3];
   for (int p = 0; p < static_cast<int>(F.planes.size()); ++p)
      if (partial & (1u << p)) {
         for (int i = 0; i < 3; ++i) pd[np][i] = plane_d(F.planes[p], *v[i]) * iw[i];
         ++np;
      }
   const float inv = 1.0f / static_cast<float>(area);
   // E_a = (c - b) x (p - b), the weight of a; E_b = (a - c) x (p - c); E_c = (b - a) x (p - a)
   const int64_t ex0 = X[c] - X[b], ey0 = Y[c] - Y[b], ex1 = X[a] - X[c], ey1 = Y[a] - Y[c];
   const int64_t ex2 = X[b] - X[a], ey2 = Y[b] - Y[a];
   const auto owned = [](int64_t ex, int64_t ey) { return ey > 0 || (ey == 0 && ex < 0); };
   const int64_t bias0 = owned(ex0, ey0) ? 0 : 1, bias1 = owned(ex1, ey1) ? 0 : 1, bias2 = owned(ex2, ey2) ? 0 : 1;
   const int64_t px = static_cast<int64_t>(ix0) * SUB + SUB / 2, py = static_cast<int64_t>(iy0) * SUB + SUB / 2;
   int64_t r0 = ex0 * (py - Y[b]) - ey0 * (px - X[b]);
   int64_t r1 = ex1 * (py - Y[c]) - ey1 * (px - X[c]);
   int64_t r2 = ex2 * (py - Y[a]) - ey2 * (px - X[a]);
   for (int y = iy0; y <= iy1; ++y, r0 += ex0 * SUB, r1 += ex1 * SUB, r2 += ex2 * SUB) {
      int64_t e0 = r0, e1 = r1, e2 = r2;
      const size_t row = static_cast<size_t>(y) * F.w;
      for (int x = ix0; x <= ix1; ++x, e0 -= ey0 * SUB, e1 -= ey1 * SUB, e2 -= ey2 * SUB) {
         if (e0 - bias0 < 0 || e1 - bias1 < 0 || e2 - bias2 < 0) continue; // E > 0, or E = 0 on an owned edge
         const float la = static_cast<float>(e0) * inv, lb = static_cast<float>(e1) * inv, lc = 1.0f - la - lb;
         const float z = la * sz[a] + lb * sz[b] + lc * sz[c];
         const size_t p = row + x;
         if (z < -1.0f || z > 1.0f || z >= F.depth[p]) continue;
         if (np) {
            bool out = false;
            for (int k = 0; k < np && !out; ++k) out = (la * pd[k][a] + lb * pd[k][b] + lc * pd[k][c]) < 0.0f;
            if (out) continue;
         }
         F.depth[p] = z;
         F.ids[p] = id;
         uint8_t *px8 = F.rgba + 4 * p;
         px8[0] = static_cast<uint8_t>(std::min(255.0f, la * col[a][0] + lb * col[b][0] + lc * col[c][0] + 0.5f));
         px8[1] = static_cast<uint8_t>(std::min(255.0f, la * col[a][1] + lb * col[b][1] + lc * col[c][1] + 0.5f));
         px8[2] = static_cast<uint8_t>(std::min(255.0f, la * col[a][2] + lb * col[b][2] + lc * col[c][2] + 0.5f));
         px8[3] = 255;
      }
   }
}

// A triangle: rejected when outside one clip-space plane, or outside the band, or outside a clipping plane; clipped
// against the near plane and the guard band when it crosses them (a polygon of up to 8 vertices), then rasterized as
// a fan. The vertices come from transform, projected.
void triangle(const frame_t &F, int y0, int y1, const vtx_t &A, const vtx_t &B, const vtx_t &C, int32_t id) {
   if (A.code & B.code & C.code) return;
   const uint32_t outside = A.code | B.code | C.code;
   if (!outside) { // the band: rows whose centre may be covered
      const int32_t miny = std::min({A.Y, B.Y, C.Y}), maxy = std::max({A.Y, B.Y, C.Y});
      if (maxy < y0 * SUB + SUB / 2 || miny > (y1 - 1) * SUB + SUB / 2) return;
   }
   unsigned partial = 0;
   for (size_t p = 0; p < F.planes.size(); ++p) {
      const float da = plane_d(F.planes[p], A), db = plane_d(F.planes[p], B), dc = plane_d(F.planes[p], C);
      if (da < 0.0f && db < 0.0f && dc < 0.0f) return;
      if (da < 0.0f || db < 0.0f || dc < 0.0f) partial |= 1u << p;
   }
   if (!outside) {
      raster(F, y0, y1, A, B, C, id, partial);
      return;
   }
   vtx_t buf[2][9];
   int n = 3, cur = 0;
   buf[0][0] = A, buf[0][1] = B, buf[0][2] = C;
   for (int p = 0; p < CLIP_PLANES; ++p) {
      if (!(outside & (1u << p))) continue;
      const vtx_t *in = buf[cur];
      vtx_t *out = buf[1 - cur];
      int m = 0;
      for (int i = 0; i < n; ++i) {
         const vtx_t &P = in[i], &Q = in[(i + 1) % n];
         const float dp = clip_d(P, p), dq = clip_d(Q, p);
         if (dp >= 0.0f) out[m++] = P;
         if ((dp >= 0.0f) != (dq >= 0.0f) && m < 9) out[m++] = dp >= 0.0f ? cross_at(P, dp, Q, dq) : cross_at(Q, dq, P, dp);
      }
      n = m;
      cur = 1 - cur;
      if (n < 3) return;
   }
   vtx_t *poly = buf[cur];
   const float hw = 0.5f * F.w, hh = 0.5f * F.h;
   for (int i = 0; i < n; ++i) {
      if (!(poly[i].cw > 0.0f)) return; // degenerate: the eye on the triangle's plane
      project(poly[i], hw, hh, true);
   }
   for (int i = 1; i + 1 < n; ++i) raster(F, y0, y1, poly[0], poly[i], poly[i + 1], id, partial);
}

// A segment, clipped to the clipping planes (world space), the near plane and the guard band (clip space), drawn one
// pixel wide in rows [y0, y1).
void segment(const frame_t &F, int y0, int y1, vtx_t A, vtx_t B) {
   for (const plane_t &p : F.planes) {
      const float da = plane_d(p, A), db = plane_d(p, B);
      if (da < 0.0f && db < 0.0f) return;
      if (da < 0.0f) A = cross_at(B, db, A, da);
      else if (db < 0.0f) B = cross_at(A, da, B, db);
   }
   for (int p = 0; p < CLIP_PLANES; ++p) {
      const float da = clip_d(A, p), db = clip_d(B, p);
      if (da < 0.0f && db < 0.0f) return;
      if (da < 0.0f) A = cross_at(B, db, A, da);
      else if (db < 0.0f) B = cross_at(A, da, B, db);
   }
   if (!(A.cw > 0.0f) || !(B.cw > 0.0f)) return;
   const float hw = 0.5f * F.w, hh = 0.5f * F.h;
   const float ax = (A.cx / A.cw + 1.0f) * hw - 0.5f, ay = (1.0f - A.cy / A.cw) * hh - 0.5f, az = A.cz / A.cw;
   const float bx = (B.cx / B.cw + 1.0f) * hw - 0.5f, by = (1.0f - B.cy / B.cw) * hh - 0.5f, bz = B.cz / B.cw;
   if (std::max(ay, by) < y0 - 1.0f || std::min(ay, by) > y1 + 1.0f) return;
   const int n = static_cast<int>(std::ceil(std::max(std::fabs(bx - ax), std::fabs(by - ay))));
   for (int i = 0; i <= n; ++i) {
      const float t = n ? static_cast<float>(i) / n : 0.0f;
      const int x = static_cast<int>(std::lround(ax + t * (bx - ax))), y = static_cast<int>(std::lround(ay + t * (by - ay)));
      if (x < 0 || x >= F.w || y < y0 || y >= y1) continue;
      const float z = az + t * (bz - az) - LINE_BIAS;
      const size_t p = static_cast<size_t>(y) * F.w + x;
      if (z > 1.0f || z > F.depth[p]) continue;
      uint8_t *px8 = F.rgba + 4 * p;
      px8[0] = static_cast<uint8_t>(A.r + t * (B.r - A.r) + 0.5f);
      px8[1] = static_cast<uint8_t>(A.g + t * (B.g - A.g) + 0.5f);
      px8[2] = static_cast<uint8_t>(A.b + t * (B.b - A.b) + 0.5f);
      px8[3] = 255;
   }
}

void transform(const view_t &v, mesh_t &m, const double mvp[16], const float eye[3], int w, int h, int64_t i0,
               int64_t i1) {
   const float hw = 0.5f * w, hh = 0.5f * h;
   for (int64_t i = i0; i < i1; ++i) {
      const double x = m.xyz[3 * i], y = m.xyz[3 * i + 1], z = m.xyz[3 * i + 2];
      vtx_t &o = m.sv[static_cast<size_t>(i)];
      o.cx = static_cast<float>(mvp[0] * x + mvp[4] * y + mvp[8] * z + mvp[12]);
      o.cy = static_cast<float>(mvp[1] * x + mvp[5] * y + mvp[9] * z + mvp[13]);
      o.cz = static_cast<float>(mvp[2] * x + mvp[6] * y + mvp[10] * z + mvp[14]);
      o.cw = static_cast<float>(mvp[3] * x + mvp[7] * y + mvp[11] * z + mvp[15]);
      o.wx = static_cast<float>(x), o.wy = static_cast<float>(y), o.wz = static_cast<float>(z);
      if (m.scalar && !m.on_cells) {
         float c[3];
         scalar_colour(m, m.scalar[i], c);
         o.r = c[0], o.g = c[1], o.b = c[2];
      } else {
         o.r = m.color[0], o.g = m.color[1], o.b = m.color[2];
      }
      if (v.lighting && !m.nrm.empty()) {
         const float *n = &m.nrm[3 * static_cast<size_t>(i)];
         o.l = AMBIENT + (1.0f - AMBIENT) * std::fabs(n[0] * eye[0] + n[1] * eye[1] + n[2] * eye[2]);
      } else {
         o.l = 1.0f;
      }
      project(o, hw, hh, false);
   }
}

// Rows [y0, y1) of every visible mesh: clear, triangles, then lines.
void band(const view_t &v, const frame_t &F, int y0, int y1) {
   const size_t a = static_cast<size_t>(y0) * F.w, b = static_cast<size_t>(y1) * F.w;
   const uint32_t bg = static_cast<uint32_t>(v.background[0]) | (static_cast<uint32_t>(v.background[1]) << 8) |
                       (static_cast<uint32_t>(v.background[2]) << 16) | 0xff000000u;
   uint8_t *p = F.rgba + 4 * a;
   for (size_t i = a; i < b; ++i, p += 4) std::memcpy(p, &bg, 4); // RGBA bytes in memory order on little-endian
   std::fill(F.depth + a, F.depth + b, std::numeric_limits<float>::infinity());
   std::fill(F.ids + a, F.ids + b, -1);
   for (const auto &mp : v.meshes) {
      const mesh_t &m = *mp;
      if (!m.visible || m.kind == LINES) continue;
      const size_t nt = m.tri.size() / 3;
      const int per = m.cells_per_tri();
      for (size_t t = 0; t < nt; ++t) {
         const int32_t *k = &m.tri[3 * t];
         const vtx_t &a0 = m.sv[k[0]], &b0 = m.sv[k[1]], &c0 = m.sv[k[2]];
         if (a0.code & b0.code & c0.code) continue; // outside a clip-space plane
         if (!(a0.code | b0.code | c0.code)) {      // outside the band
            const int32_t miny = std::min({a0.Y, b0.Y, c0.Y}), maxy = std::max({a0.Y, b0.Y, c0.Y});
            if (maxy < y0 * SUB + SUB / 2 || miny > (y1 - 1) * SUB + SUB / 2) continue;
         }
         vtx_t A = a0, B = b0, C = c0;
         if (m.scalar && m.on_cells) {
            float c[3];
            scalar_colour(m, m.scalar[t / per], c);
            A.r = B.r = C.r = c[0], A.g = B.g = C.g = c[1], A.b = B.b = C.b = c[2];
         }
         if (m.flat && F.lighting) {
            const float u[3] = {B.wx - A.wx, B.wy - A.wy, B.wz - A.wz}, w[3] = {C.wx - A.wx, C.wy - A.wy, C.wz - A.wz};
            const float n[3] = {u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0]};
            const float s = std::sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]);
            const float l = AMBIENT + (1.0f - AMBIENT) *
                                          (s > 0.0f ? std::fabs(n[0] * F.eye_dir[0] + n[1] * F.eye_dir[1] +
                                                                n[2] * F.eye_dir[2]) / s
                                                    : 0.0f);
            A.l = B.l = C.l = l;
         }
         triangle(F, y0, y1, A, B, C, m.base + static_cast<int32_t>(t));
      }
   }
   for (const auto &mp : v.meshes) {
      const mesh_t &m = *mp;
      if (!m.visible || m.seg.empty()) continue;
      const size_t ns = m.seg.size() / 2;
      for (size_t s = 0; s < ns; ++s) {
         vtx_t A = m.sv[m.seg[2 * s]], B = m.sv[m.seg[2 * s + 1]];
         if (m.kind != LINES) {
            A.r = B.r = m.edge_color[0], A.g = B.g = m.edge_color[1], A.b = B.b = m.edge_color[2];
         } else if (m.scalar && m.on_cells) {
            float c[3];
            scalar_colour(m, m.scalar[m.seg_cell[s]], c);
            A.r = B.r = c[0], A.g = B.g = c[1], A.b = B.b = c[2];
         }
         segment(F, y0, y1, A, B);
      }
   }
}

// The per-render vertex caches (64 B a vertex) are needed only while a render runs; they are kept while renders follow
// one another (a drag, a field changed every frame) and freed after IDLE_RELEASE draws without one. Small caches return
// to malloc, not to the system: on glibc, malloc_trim gives the freed pages back.
constexpr int IDLE_RELEASE = 30;

size_t cache_bytes(const view_t &v) {
   size_t b = 0;
   for (const auto &m : v.meshes) b += m->sv.capacity() * sizeof(vtx_t);
   return b;
}

void release_caches(view_t &v) {
   if (cache_bytes(v) == 0) return;
   for (auto &m : v.meshes) std::vector<vtx_t>().swap(m->sv);
#if defined(__GLIBC__)
   malloc_trim(0);
#endif
}

void render(view_t &v, int w, int h, bool half) {
   const auto t0 = std::chrono::steady_clock::now();
   const size_t n = static_cast<size_t>(w) * h;
   v.rgba.resize(4 * n);
   v.depth.resize(n);
   v.ids.resize(n);
   v.rw = w, v.rh = h, v.half = half;
   if (!v.camera_set) fit(v, static_cast<double>(w) / h);
   matrices(v, w, h, v.mvp);
   if (!invert(v.mvp, v.inv)) std::memset(v.inv, 0, sizeof v.inv);
   double f[3], r[3], u[3];
   basis(v.cam, f, r, u);
   frame_t F{w, h, v.rgba.data(), v.depth.data(), v.ids.data(),
             {static_cast<float>(f[0]), static_cast<float>(f[1]), static_cast<float>(f[2])}, v.lighting, v.planes};
   v.bases.clear();
   int32_t base = 0;
   for (size_t i = 0; i < v.meshes.size(); ++i) {
      mesh_t &m = *v.meshes[i];
      if (!m.visible) continue;
      if (!m.table_ok) load_table(m);
      m.sv.resize(static_cast<size_t>(m.nv));
      m.base = base;
      if (m.kind != LINES) {
         v.bases.emplace_back(base, static_cast<int>(i));
         base += static_cast<int32_t>(m.tri.size() / 3);
      }
   }
   const int T = std::max(1, std::min(v.threads, h));
   parallel(T, [&](int i) {
      for (auto &mp : v.meshes)
         if (mp->visible) transform(v, *mp, v.mvp, F.eye_dir, w, h, mp->nv * i / T, mp->nv * (i + 1) / T);
   });
   parallel(T, [&](int i) { band(v, F, h * i / T, h * (i + 1) / T); });
   ++v.renders;
   v.ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t0).count();
}

// The pick at pixel (x, y) of the widget (scaled to the last render).
pick_t pick_at(const view_t &v, double x, double y) {
   pick_t p;
   if (v.rw <= 0 || v.vw <= 0 || v.vh <= 0) return p;
   const double sx = x * v.rw / v.vw, sy = y * v.rh / v.vh;
   const int ix = static_cast<int>(std::floor(sx)), iy = static_cast<int>(std::floor(sy));
   if (ix < 0 || iy < 0 || ix >= v.rw || iy >= v.rh) return p;
   const size_t k = static_cast<size_t>(iy) * v.rw + ix;
   const int32_t id = v.ids[k];
   if (id < 0) return p;
   // the mesh: the last base <= id
   int mi = -1;
   int32_t b0 = 0;
   for (const auto &b : v.bases)
      if (b.first <= id) mi = b.second, b0 = b.first;
   if (mi < 0 || mi >= static_cast<int>(v.meshes.size())) return p;
   const mesh_t &m = *v.meshes[mi];
   p.hit = 1;
   p.mesh = m.id;
   p.element = (id - b0) / m.cells_per_tri() + 1;
   const double ndc[4] = {(ix + 0.5) / v.rw * 2.0 - 1.0, 1.0 - (iy + 0.5) / v.rh * 2.0, v.depth[k], 1.0};
   double q[4] = {0, 0, 0, 0};
   for (int r = 0; r < 4; ++r)
      for (int c = 0; c < 4; ++c) q[r] += v.inv[c * 4 + r] * ndc[c];
   if (q[3] != 0.0)
      for (int d = 0; d < 3; ++d) p.point[d] = q[d] / q[3];
   return p;
}

int ensure_texture(unsigned long long &id, int &tw, int &th, int w, int h, int smooth) {
   if (id != 0 && tw == w && th == h) return FIG_OK;
   if (id != 0) fig_texture_destroy(id);
   id = 0, tw = th = 0;
   const int s = fig_texture_create(w, h, smooth, &id);
   if (s != FIG_OK) return s;
   tw = w, th = h;
   return FIG_OK;
}

void style_background(view_t &v) {
   if (v.own_background) return;
   const ImVec4 c = ImGui::GetStyleColorVec4(ImGuiCol_WindowBg);
   const float bg[3] = {std::round(std::clamp(c.x, 0.0f, 1.0f) * 255.0f), std::round(std::clamp(c.y, 0.0f, 1.0f) * 255.0f),
                        std::round(std::clamp(c.z, 0.0f, 1.0f) * 255.0f)};
   if (bg[0] != v.background[0] || bg[1] != v.background[1] || bg[2] != v.background[2]) {
      std::memcpy(v.background, bg, sizeof bg);
      v.dirty = true;
   }
}


// ---- gizmos (ImGuizmo, third_party/ImGuizmo) ---------------------------------------------------------------------
//
// ImGuizmo works in single precision, on column-major float[16] matrices with OpenGL's conventions, as FIGURE's view
// and projection: FIGURE gives it its own matrices in real64, rounded, with the world moved so that the camera's
// target is at the origin (the gizmo's numbers are then of the scene's size, not of its distance from the origin).
// The view cube's world has y up, FIGURE's z: its camera is turned by C (x' = x, y' = z, z' = -y) on the way in and
// back on the way out, and its faces take FIGURE's axis colours (x red, y green, z blue).

// ImGuizmo's per-frame state, once a frame, without its full-screen window (FIGURE's patch 0001).
void gizmo_frame() {
   static int last = -1;
   static ImGuiContext *context = nullptr;
   const int frame = ImGui::GetFrameCount();
   if (frame == last && context == ImGui::GetCurrentContext()) return;
   last = frame, context = ImGui::GetCurrentContext();
   ImGuizmo::BeginFrameState();
}

// The view's matrices for its widget size, the world moved by -o (o: the camera's target), in single precision. The
// projection's depth range is widened to [distance / 1000, 1000 distance] (x and y unchanged): ImGuizmo casts its
// mouse rays from the point at clip depth 0, which with the view's own near and far planes (around the meshes'
// bounding sphere) lies inside the scene, and a handle nearer the eye than that point drags the wrong way (it takes
// the ray's intersection behind its origin, mirrored); the widened range puts it at about distance / 500.
void gizmo_matrices(view_t &v, float fv[16], float fp[16], double o[3]) {
   if (!v.camera_set) fit(v, v.vw > 0 && v.vh > 0 ? static_cast<double>(v.vw) / v.vh : 1.0);
   double V[16], P[16];
   view_projection(v, std::max(v.vw, 1), std::max(v.vh, 1), V, P);
   const double zn = 1.0e-3 * v.cam.distance, zf = 1.0e3 * v.cam.distance;
   P[10] = (zf + zn) / (zn - zf);
   P[14] = 2.0 * zf * zn / (zn - zf);
   for (int d = 0; d < 3; ++d) o[d] = v.cam.target[d];
   for (int r = 0; r < 3; ++r) V[12 + r] += V[r] * o[0] + V[4 + r] * o[1] + V[8 + r] * o[2]; // V * T(o)
   for (int k = 0; k < 16; ++k) fv[k] = static_cast<float>(V[k]), fp[k] = static_cast<float>(P[k]);
}

// While ImGuizmo runs: Dear ImGui's "no mouse" position (-FLT_MAX, before the first move or after the pointer left)
// replaced by one far outside the view, so that ImGuizmo's ray computations (which read io.MousePos) do not overflow:
// a program built with floating-point traps (gfortran's -ffpe-trap, the debug modes) would stop on it.
struct mouse_guard {
   ImVec2 saved;
   bool   invalid;
   mouse_guard() : saved(ImGui::GetIO().MousePos), invalid(!ImGui::IsMousePosValid()) {
      if (invalid) ImGui::GetIO().MousePos = ImVec2(-1.0e5f, -1.0e5f);
   }
   ~mouse_guard() {
      if (invalid) ImGui::GetIO().MousePos = saved;
   }
};

// Keep Dear ImGui's active id on `id` while a gizmo is dragged with the left button: no item and no window takes
// the press (a press on no item would start moving the window).
void hold_active(ImGuiID id, bool using_it) {
   ImGuiWindow *w = ImGui::GetCurrentWindow();
   if (using_it && ImGui::IsMouseDown(ImGuiMouseButton_Left)) {
      if (ImGui::GetActiveID() == 0) ImGui::SetActiveID(id, w);
      if (ImGui::GetActiveID() == id) ImGui::KeepAliveID(id);
   } else if (ImGui::GetActiveID() == id) {
      ImGui::ClearActiveID();
   }
}

// The azimuth and elevation [degrees] of a camera whose back vector (target to eye) is b and up vector u (FIGURE's
// world); at a pole the azimuth is the one whose up vector is u.
void orientation(const double b[3], const double u[3], double &azimuth, double &elevation) {
   const double n = std::sqrt(b[0] * b[0] + b[1] * b[1] + b[2] * b[2]);
   const double bz = n > 0.0 ? b[2] / n : 0.0;
   if (bz > 1.0 - 1.0e-6) {
      elevation = 90.0, azimuth = std::atan2(-u[1], -u[0]) / DEG; // basis(): u = -(cos az, sin az, 0) looking down
   } else if (bz < -1.0 + 1.0e-6) {
      elevation = -90.0, azimuth = std::atan2(u[1], u[0]) / DEG;
   } else {
      elevation = std::asin(bz) / DEG, azimuth = std::atan2(b[1], b[0]) / DEG;
   }
}

} // namespace

#define V3_TRY try {
#define V3_CATCH                                                                                                       \
   }                                                                                                                   \
   catch (const std::exception &e) {                                                                                   \
      return fail(FIG_ERR_EXCEPTION, std::string("view3d: ") + e.what());                                              \
   }                                                                                                                   \
   catch (...) {                                                                                                       \
      return fail(FIG_ERR_EXCEPTION, "view3d: unknown C++ exception");                                                 \
   }

#define V3_VIEW                                                                                                        \
   view_t *v = find(handle);                                                                                           \
   if (!v) return fail(FIG_ERR_STATE, "view3d: the view is not initialized");

extern "C" {

int fig_view3d_create(int threads, int fast_moves, int lighting, const double *background, int *handle) {
   V3_TRY
   *handle = 0;
   if (threads < 1 || threads > MAX_THREADS)
      return fail(FIG_ERR_ARGUMENT, "view3d: threads must be in [1, " + std::to_string(MAX_THREADS) + "]");
   auto v = std::make_unique<view_t>();
   v->threads = threads;
   v->fast_moves = fast_moves != 0;
   v->lighting = lighting != 0;
   if (background) {
      v->own_background = true;
      for (int d = 0; d < 3; ++d) v->background[d] = std::round(std::clamp(background[d], 0.0, 1.0) * 255.0);
   }
   *handle = next_view++;
   views[*handle] = std::move(v);
   return FIG_OK;
   V3_CATCH
}

void fig_view3d_destroy(int handle) {
   try {
      view_t *v = find(handle);
      if (!v) return;
      if (v->tex_full) fig_texture_destroy(v->tex_full);
      if (v->tex_half) fig_texture_destroy(v->tex_half);
      views.erase(handle);
   } catch (...) {
   }
}

int fig_view3d_mesh(int handle, int kind, const double *xyz, long long nv, const int *conn, long long ncell, int ni,
                    int nj, int *mesh) {
   V3_TRY
   V3_VIEW
   *mesh = 0;
   if (kind < TRIANGLES || kind > LINES) return fail(FIG_ERR_ARGUMENT, "view3d: unknown mesh kind");
   if (!xyz || nv < 0 || ncell < 0 || nv > INT32_MAX) return fail(FIG_ERR_ARGUMENT, "view3d: bad mesh sizes");
   if ((kind == TRIANGLES || kind == QUADS) && !conn && ncell > 0)
      return fail(FIG_ERR_ARGUMENT, "view3d: the connectivity is missing");
   if (kind == SURFACE && (ni < 2 || nj < 2 || static_cast<long long>(ni) * nj != nv))
      return fail(FIG_ERR_ARGUMENT, "view3d: a surface needs xyz(3, ni, nj) with ni, nj >= 2");
   auto m = std::make_unique<mesh_t>();
   m->kind = kind;
   m->xyz = xyz;
   m->nv = nv;
   m->conn = conn;
   m->ncell = ncell;
   m->ni = ni, m->nj = nj;
   if (kind == LINES) m->color[0] = m->color[1] = m->color[2] = 230.0f;
   const int s = derive(*m);
   if (s != FIG_OK) return s;
   m->id = v->next_mesh++;
   *mesh = m->id;
   v->meshes.push_back(std::move(m));
   v->dirty = true;
   return FIG_OK;
   V3_CATCH
}

int fig_view3d_scalar(int handle, int mesh, const double *scalar, long long n, int on_cells) {
   V3_TRY
   V3_VIEW
   mesh_t *m = find_mesh(*v, mesh);
   if (!m) return fail(FIG_ERR_ARGUMENT, "view3d: unknown mesh " + std::to_string(mesh));
   if (scalar) {
      const int64_t want = on_cells ? cells_of(*m) : m->nv;
      if (n != want)
         return fail(FIG_ERR_ARGUMENT, std::string("view3d: the scalar needs ") + std::to_string(want) + " values (one per " +
                                           (on_cells ? "cell" : "vertex") + "), got " + std::to_string(n));
   }
   m->scalar = scalar;
   m->nscalar = scalar ? n : 0;
   m->on_cells = on_cells != 0;
   v->dirty = true;
   return derive(*m);
   V3_CATCH
}

int fig_view3d_style(int handle, int mesh, const char *colormap, int colormap_len, int set_range, double vmin,
                     double vmax, const double *color, int edges, const double *edge_color, int flat, int visible) {
   V3_TRY
   V3_VIEW
   mesh_t *m = find_mesh(*v, mesh);
   if (!m) return fail(FIG_ERR_ARGUMENT, "view3d: unknown mesh " + std::to_string(mesh));
   if (colormap_len > 0) {
      const std::string name(colormap, static_cast<size_t>(colormap_len));
      int id = -1;
      const int s = fig_colormap(name.c_str(), colormap_len, 0, &id);
      if (s != FIG_OK) return s; // its message names the map
      m->colormap = name;
      m->table_ok = false;
   }
   if (set_range == 1) {
      if (!(vmax > vmin)) return fail(FIG_ERR_ARGUMENT, "view3d: the range needs vmax > vmin");
      m->auto_range = false, m->vmin = vmin, m->vmax = vmax;
   } else if (set_range == 2) {
      m->auto_range = true, m->vmin = m->dmin, m->vmax = m->dmax;
   }
   if (color)
      for (int d = 0; d < 3; ++d) m->color[d] = static_cast<float>(std::round(std::clamp(color[d], 0.0, 1.0) * 255.0));
   if (edge_color)
      for (int d = 0; d < 3; ++d)
         m->edge_color[d] = static_cast<float>(std::round(std::clamp(edge_color[d], 0.0, 1.0) * 255.0));
   bool rederive = false;
   if (edges >= 0 && (edges != 0) != m->edges) m->edges = edges != 0, rederive = true;
   if (flat >= 0) m->flat = flat != 0;
   if (visible >= 0) m->visible = visible != 0;
   v->dirty = true;
   return rederive ? derive(*m) : FIG_OK;
   V3_CATCH
}

int fig_view3d_remove(int handle, int mesh) {
   V3_TRY
   V3_VIEW
   if (mesh == 0) {
      v->meshes.clear();
   } else {
      const auto it = std::find_if(v->meshes.begin(), v->meshes.end(), [&](const auto &m) { return m->id == mesh; });
      if (it == v->meshes.end()) return fail(FIG_ERR_ARGUMENT, "view3d: unknown mesh " + std::to_string(mesh));
      v->meshes.erase(it);
   }
   v->hovered = v->clicked = pick_t{};
   v->bases.clear();
   std::fill(v->ids.begin(), v->ids.end(), -1); // no pick into a removed mesh before the next render
   v->dirty = true;
   return FIG_OK;
   V3_CATCH
}

int fig_view3d_changed(int handle, int mesh) {
   V3_TRY
   V3_VIEW
   v->dirty = true;
   for (auto &m : v->meshes)
      if (mesh == 0 || m->id == mesh) {
         const int s = derive(*m);
         if (s != FIG_OK) return s;
         if (mesh != 0) return FIG_OK;
      }
   if (mesh != 0) return fail(FIG_ERR_ARGUMENT, "view3d: unknown mesh " + std::to_string(mesh));
   return FIG_OK;
   V3_CATCH
}

int fig_view3d_camera(int handle, int set, int mask, double *target, double *distance, double *azimuth,
                      double *elevation, double *fov) {
   V3_TRY
   V3_VIEW
   camera_t &c = v->cam;
   if (set) {
      if ((mask & 2) && !(*distance > 0.0)) return fail(FIG_ERR_ARGUMENT, "view3d: the distance must be positive");
      if ((mask & 16) && !(*fov > 0.0 && *fov < 180.0))
         return fail(FIG_ERR_ARGUMENT, "view3d: the field of view must be in (0, 180) degrees");
      if ((mask & 8) && !(std::fabs(*elevation) <= 90.0))
         return fail(FIG_ERR_ARGUMENT, "view3d: the elevation must be in [-90, 90] degrees");
      if (!v->camera_set) fit(*v, v->vw > 0 && v->vh > 0 ? static_cast<double>(v->vw) / v->vh : 1.0);
      if (mask & 1)
         for (int d = 0; d < 3; ++d) c.target[d] = target[d];
      if (mask & 2) c.distance = *distance;
      if (mask & 4) c.azimuth = *azimuth;
      if (mask & 8) c.elevation = *elevation;
      if (mask & 16) c.fov = *fov;
      v->camera_set = true;
      v->dirty = true;
   } else {
      if (!v->camera_set) fit(*v, v->vw > 0 && v->vh > 0 ? static_cast<double>(v->vw) / v->vh : 1.0);
      if (target)
         for (int d = 0; d < 3; ++d) target[d] = c.target[d];
      if (distance) *distance = c.distance;
      if (azimuth) *azimuth = c.azimuth;
      if (elevation) *elevation = c.elevation;
      if (fov) *fov = c.fov;
   }
   return FIG_OK;
   V3_CATCH
}

int fig_view3d_fit(int handle) {
   V3_TRY
   V3_VIEW
   fit(*v, v->vw > 0 && v->vh > 0 ? static_cast<double>(v->vw) / v->vh : 1.0);
   v->dirty = true;
   return FIG_OK;
   V3_CATCH
}

int fig_view3d_standard(int handle, int which) {
   V3_TRY
   V3_VIEW
   static const double AZ[6] = {0.0, 180.0, 90.0, -90.0, -90.0, -90.0}, EL[6] = {0.0, 0.0, 0.0, 0.0, 90.0, -90.0};
   if (which < 0 || which > 5) return fail(FIG_ERR_ARGUMENT, "view3d: unknown standard view");
   v->cam.azimuth = AZ[which];
   v->cam.elevation = EL[which];
   fit(*v, v->vw > 0 && v->vh > 0 ? static_cast<double>(v->vw) / v->vh : 1.0);
   v->dirty = true;
   return FIG_OK;
   V3_CATCH
}

int fig_view3d_move(int handle, double d_azimuth, double d_elevation, double pan_right, double pan_up, double zoom) {
   V3_TRY
   V3_VIEW
   if (!(zoom > 0.0)) return fail(FIG_ERR_ARGUMENT, "view3d: the zoom factor must be positive");
   if (!v->camera_set) fit(*v, v->vw > 0 && v->vh > 0 ? static_cast<double>(v->vw) / v->vh : 1.0);
   camera_t &c = v->cam;
   c.azimuth = std::remainder(c.azimuth + d_azimuth, 360.0);
   c.elevation = std::clamp(c.elevation + d_elevation, -90.0, 90.0);
   double f[3], r[3], u[3];
   basis(c, f, r, u);
   for (int d = 0; d < 3; ++d) c.target[d] += pan_right * r[d] + pan_up * u[d];
   c.distance /= zoom;
   v->camera_set = true;
   v->dirty = true;
   return FIG_OK;
   V3_CATCH
}

int fig_view3d_clip(int handle, const double *normal, const double *point) {
   V3_TRY
   V3_VIEW
   if (static_cast<int>(v->planes.size()) >= MAX_PLANES)
      return fail(FIG_ERR_ARGUMENT, "view3d: at most " + std::to_string(MAX_PLANES) + " clipping planes");
   const double s = std::sqrt(normal[0] * normal[0] + normal[1] * normal[1] + normal[2] * normal[2]);
   if (!(s > 0.0)) return fail(FIG_ERR_ARGUMENT, "view3d: the plane's normal is zero");
   plane_t p;
   for (int d = 0; d < 3; ++d) p.n[d] = normal[d] / s;
   p.c = p.n[0] * point[0] + p.n[1] * point[1] + p.n[2] * point[2];
   v->planes.push_back(p);
   v->dirty = true;
   return FIG_OK;
   V3_CATCH
}

int fig_view3d_unclip(int handle) {
   V3_TRY
   V3_VIEW
   if (!v->planes.empty()) v->dirty = true;
   v->planes.clear();
   return FIG_OK;
   V3_CATCH
}

int fig_view3d_draw(int handle, const char *id, int id_len, double width, double height) {
   V3_TRY
   V3_VIEW
   if (!ImGui::GetCurrentContext()) return fail(FIG_ERR_STATE, "figure is not initialized");
   const std::string label(id, static_cast<size_t>(std::max(id_len, 0)));
   const ImVec2 avail = ImGui::GetContentRegionAvail();
   float w = static_cast<float>(width), h = static_cast<float>(height);
   if (w <= 0.0f) w = std::max(1.0f, avail.x + w);
   if (h <= 0.0f) h = std::max(1.0f, avail.y + h);
   const int iw = std::max(1, static_cast<int>(w)), ih = std::max(1, static_cast<int>(h));
   const ImVec2 p0 = ImGui::GetCursorScreenPos();
   // the mouse over the view cube, or over a gizmo (or using one) in the last frame: the gizmos', not the view's, unless
   // the view is being dragged. The view is then an item without an id, which no press activates and the mouse does
   // not hover: ImGuizmo's gizmos start a drag only while no item is hovered or active (the cube and the gizmo
   // calls take the press themselves, so that the window does not move)
   const int frame = ImGui::GetFrameCount();
   const ImVec2 mouse = ImGui::GetIO().MousePos;
   const bool over_cube = v->cube_frame >= frame - 1 && mouse.x >= p0.x + v->cube_min.x &&
                          mouse.x < p0.x + v->cube_max.x && mouse.y >= p0.y + v->cube_min.y &&
                          mouse.y < p0.y + v->cube_max.y;
   const bool overlay = (over_cube || v->overlay_frame >= frame - 1) && ImGui::GetActiveID() != ImGui::GetID(label.c_str());
   if (overlay) {
      ImGui::Dummy(ImVec2(static_cast<float>(iw), static_cast<float>(ih)));
   } else {
      ImGui::InvisibleButton(label.c_str(), ImVec2(static_cast<float>(iw), static_cast<float>(ih)),
                             ImGuiButtonFlags_MouseButtonLeft | ImGuiButtonFlags_MouseButtonRight |
                                 ImGuiButtonFlags_MouseButtonMiddle);
      // the wheel is the view's while the pointer is over it: claimed for the next frame, so that a scrolling window
      // or child holding the view does not scroll on the same turn of the wheel (Dear ImGui's key ownership)
      ImGui::SetItemKeyOwner(ImGuiKey_MouseWheelY);
      ImGui::SetItemKeyOwner(ImGuiKey_MouseWheelX);
   }
   v->image_pos = p0;
   v->image_frame = frame;
   v->image_window = ImGui::GetCurrentWindow()->ID;
   const ImGuiIO &io = ImGui::GetIO();
   const bool hovered = !overlay && ImGui::IsItemHovered();
   const bool active = !overlay && ImGui::IsItemActive();
   const bool deactivated = !overlay && ImGui::IsItemDeactivated();
   if (iw != v->vw || ih != v->vh) v->vw = iw, v->vh = ih, v->dirty = true;
   style_background(*v);
   if (v->colormaps != fig_colormap_generation()) { // a colormap was edited (ig_gradient_edit): its tables again
      v->colormaps = fig_colormap_generation();
      for (auto &m : v->meshes) m->table_ok = false;
      v->dirty = true;
   }
   // the mouse
   bool moved = v->cube_moved;
   v->cube_moved = false;
   if (!v->camera_set && !v->meshes.empty()) fit(*v, static_cast<double>(iw) / ih);
   if (active && (io.MouseDelta.x != 0.0f || io.MouseDelta.y != 0.0f)) {
      const float dx = io.MouseDelta.x, dy = io.MouseDelta.y;
      const bool pan = ImGui::IsMouseDown(ImGuiMouseButton_Right) || ImGui::IsMouseDown(ImGuiMouseButton_Middle) ||
                       (ImGui::IsMouseDown(ImGuiMouseButton_Left) && io.KeyShift);
      if (pan) {
         const double unit = 2.0 * v->cam.distance * std::tan(0.5 * v->cam.fov * DEG) / ih; // world per pixel
         fig_view3d_move(handle, 0.0, 0.0, -dx * unit, dy * unit, 1.0);
      } else if (ImGui::IsMouseDown(ImGuiMouseButton_Left)) {
         fig_view3d_move(handle, -0.4 * dx, 0.4 * dy, 0.0, 0.0, 1.0);
      }
      moved = true;
   }
   if (hovered && io.MouseWheel != 0.0f) {
      fig_view3d_move(handle, 0.0, 0.0, 0.0, 0.0, std::pow(1.1, static_cast<double>(io.MouseWheel)));
      moved = true;
   }
   if (hovered && ImGui::IsMouseDoubleClicked(ImGuiMouseButton_Left)) {
      fit(*v, static_cast<double>(iw) / ih);
      v->dirty = true;
   }
   // a drag held still for a frame stays at half resolution (no render) until it moves again or is released: a full
   // render per pause would cost a render, and in remote mode an exact image, between two moves
   const bool fast = (moved || (active && v->half)) && v->fast_moves && iw >= 2 && ih >= 2;
   v->moving = fast;
   if (v->dirty || (v->half && !fast)) {
      const int rw = fast ? iw / 2 : iw, rh = fast ? ih / 2 : ih;
      render(*v, rw, rh, fast);
      int s;
      if (fast) {
         s = ensure_texture(v->tex_half, v->tex_half_w, v->tex_half_h, rw, rh, 1);
         if (s == FIG_OK) s = fig_texture_update(v->tex_half, rw, rh, v->rgba.data());
      } else {
         s = ensure_texture(v->tex_full, v->tex_full_w, v->tex_full_h, rw, rh, 0);
         if (s == FIG_OK) s = fig_texture_update(v->tex_full, rw, rh, v->rgba.data());
      }
      if (s != FIG_OK) return s;
      v->dirty = false;
      v->idle_draws = 0;
   } else if (++v->idle_draws == IDLE_RELEASE) {
      release_caches(*v);
   }
   // the image
   const unsigned long long tex = v->half ? v->tex_half : v->tex_full;
   if (tex) {
      ImDrawList *dl = ImGui::GetWindowDrawList();
      fig_texture_sampling(0, 1);
      dl->AddImage(static_cast<ImTextureID>(tex), p0, ImVec2(p0.x + iw, p0.y + ih));
      fig_texture_sampling(0, 0);
   }
   // picking: hovered element, and the one clicked (a release without a drag)
   v->hovered = hovered ? pick_at(*v, io.MousePos.x - p0.x, io.MousePos.y - p0.y) : pick_t{};
   v->clicked = pick_t{};
   if (deactivated && hovered && ImGui::IsMouseReleased(ImGuiMouseButton_Left)) {
      const ImVec2 d = ImVec2(io.MousePos.x - io.MouseClickedPos[0].x, io.MousePos.y - io.MouseClickedPos[0].y);
      if (d.x * d.x + d.y * d.y <= 9.0f) v->clicked = v->hovered;
   }
   return FIG_OK;
   V3_CATCH
}

int fig_view3d_pick(int handle, int what, double x, double y, int *hit, int *mesh, long long *element,
                    double *point) {
   V3_TRY
   V3_VIEW
   const pick_t p = what == 1 ? v->hovered : (what == 2 ? v->clicked : pick_at(*v, x, y));
   *hit = p.hit;
   *mesh = p.mesh;
   *element = p.element;
   for (int d = 0; d < 3; ++d) point[d] = p.point[d];
   return FIG_OK;
   V3_CATCH
}

int fig_view3d_image(int handle, unsigned char *rgba, long long cap, int *width, int *height) {
   V3_TRY
   V3_VIEW
   *width = v->rw;
   *height = v->rh;
   if (rgba) {
      if (cap < static_cast<long long>(v->rgba.size()))
         return fail(FIG_ERR_ARGUMENT, "view3d: the image array is too small");
      std::memcpy(rgba, v->rgba.data(), v->rgba.size());
   }
   return FIG_OK;
   V3_CATCH
}

int fig_view3d_info(int handle, int *renders, double *ms, int *width, int *height, int *half) {
   V3_TRY
   V3_VIEW
   *renders = v->renders;
   *ms = v->ms;
   *width = v->rw;
   *height = v->rh;
   *half = v->half ? 1 : 0;
   return FIG_OK;
   V3_CATCH
}

int fig_view3d_cache(int handle, long long *bytes) {
   V3_TRY
   V3_VIEW
   *bytes = static_cast<long long>(cache_bytes(*v));
   return FIG_OK;
   V3_CATCH
}

int fig_view3d_matrices(int handle, double *view, double *projection) {
   V3_TRY
   V3_VIEW
   if (!v->camera_set) fit(*v, v->vw > 0 && v->vh > 0 ? static_cast<double>(v->vw) / v->vh : 1.0);
   double V[16], P[16];
   view_projection(*v, std::max(v->vw, 1), std::max(v->vh, 1), V, P);
   if (view) std::memcpy(view, V, sizeof V);
   if (projection) std::memcpy(projection, P, sizeof P);
   return FIG_OK;
   V3_CATCH
}

// The gizmos need the view drawn in this frame, in the current window: they are drawn over its image.
#define V3_DRAWN(what)                                                                                                 \
   if (!ImGui::GetCurrentContext()) return fail(FIG_ERR_STATE, "figure is not initialized");                         \
   if (v->image_frame != ImGui::GetFrameCount() || v->image_window != ImGui::GetCurrentWindow()->ID)                 \
      return fail(FIG_ERR_STATE, std::string("view3d_object%") + what +                                              \
                                     ": draw the view first, in this frame and in this window");

int fig_view3d_cube(int handle, double size, int corner, int *changed) {
   V3_TRY
   V3_VIEW
   *changed = 0;
   V3_DRAWN("view_cube")
   if (!(size > 0.0)) return fail(FIG_ERR_ARGUMENT, "view3d_object%view_cube: the size must be positive");
   if (corner < 0 || corner > 3) return fail(FIG_ERR_ARGUMENT, "view3d_object%view_cube: unknown corner");
   const float s = static_cast<float>(std::min({size, static_cast<double>(v->vw), static_cast<double>(v->vh)}));
   const ImVec2 rel((corner == 1 || corner == 3) ? 0.0f : static_cast<float>(v->vw) - s,
                    (corner == 2 || corner == 3) ? static_cast<float>(v->vh) - s : 0.0f);
   const ImVec2 pos(v->image_pos.x + rel.x, v->image_pos.y + rel.y);
   gizmo_frame();
   ImGuizmo::SetDrawlist(ImGui::GetWindowDrawList());
   ImGuizmo::SetOrthographic(false);
   ImGuizmo::SetRect(v->image_pos.x, v->image_pos.y, static_cast<float>(v->vw), static_cast<float>(v->vh));
   float fv[16], fp[16];
   double o[3];
   gizmo_matrices(*v, fv, fp, o);
   // the camera into the cube's y-up world: V' = V C^-1, C^-1 (x', y', z') = (x', -z', y'): columns 1 and 2 of the
   // rotation become column 2 and -column 1
   float cv[16];
   std::memcpy(cv, fv, sizeof cv);
   for (int r = 0; r < 3; ++r) cv[4 + r] = fv[8 + r], cv[8 + r] = -fv[4 + r];
   float before[16];
   std::memcpy(before, cv, sizeof cv);
   static const float identity[16] = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
   float model[16];
   std::memcpy(model, identity, sizeof model);
   ImGuizmo::Style &st = ImGuizmo::GetStyle();
   std::swap(st.Colors[ImGuizmo::DIRECTION_Y], st.Colors[ImGuizmo::DIRECTION_Z]); // y' is FIGURE's z
   const ImGuiID id = ImGui::GetID(("##figure-view-cube-" + std::to_string(handle)).c_str());
   ImGuizmo::PushID(static_cast<int>(id));
   const bool using_before = ImGuizmo::IsUsingViewManipulate();
   {
      const mouse_guard guard;
      ImGuizmo::ViewManipulate(cv, fp, ImGuizmo::TRANSLATE, ImGuizmo::WORLD, model, static_cast<float>(v->cam.distance),
                               pos, ImVec2(s, s), 0);
   }
   const bool using_it = ImGuizmo::IsUsingViewManipulate() && !using_before;
   ImGuizmo::PopID();
   std::swap(st.Colors[ImGuizmo::DIRECTION_Y], st.Colors[ImGuizmo::DIRECTION_Z]);
   const ImVec2 mp = ImGui::GetIO().MousePos;
   const bool inside = mp.x >= pos.x && mp.x < pos.x + s && mp.y >= pos.y && mp.y < pos.y + s &&
                       ImGui::IsWindowHovered(ImGuiHoveredFlags_ChildWindows);
   hold_active(id, using_it || (inside && ImGui::IsMouseClicked(ImGuiMouseButton_Left)));
   v->cube_min = rel;
   v->cube_max = ImVec2(rel.x + s, rel.y + s);
   v->cube_frame = ImGui::GetFrameCount();
   if (using_it) v->overlay_frame = v->cube_frame;
   if (std::memcmp(before, cv, sizeof cv) != 0) { // back to FIGURE's world: rows 1 (up) and 2 (back), by C^-1
      const double u[3] = {cv[1], -cv[9], cv[5]}, b[3] = {cv[2], -cv[10], cv[6]};
      double az, el;
      orientation(b, u, az, el);
      v->cam.azimuth = std::remainder(az, 360.0);
      v->cam.elevation = std::clamp(el, -90.0, 90.0);
      v->camera_set = true;
      v->dirty = true;
      v->cube_moved = true;
      *changed = 1;
   }
   return FIG_OK;
   V3_CATCH
}

int fig_view3d_gizmo(int handle, const char *id, int id_len, double *matrix, int mode, int space, int has_snap,
                     double snap, int *changed) {
   V3_TRY
   V3_VIEW
   *changed = 0;
   V3_DRAWN("gizmo")
   if (mode < 0 || mode > 2) return fail(FIG_ERR_ARGUMENT, "view3d_object%gizmo: unknown mode");
   if (has_snap && !(snap > 0.0 && std::isfinite(snap)))
      return fail(FIG_ERR_ARGUMENT, "view3d_object%gizmo: snap must be positive");
   for (int k = 0; k < 16; ++k)
      if (!std::isfinite(matrix[k])) return fail(FIG_ERR_ARGUMENT, "view3d_object%gizmo: the matrix is not finite");
   if (matrix[3] != 0.0 || matrix[7] != 0.0 || matrix[11] != 0.0 || matrix[15] != 1.0)
      return fail(FIG_ERR_ARGUMENT, "view3d_object%gizmo: the matrix's last row must be (0, 0, 0, 1)");
   const std::string label(id, static_cast<size_t>(std::max(id_len, 0)));
   gizmo_frame();
   ImGuizmo::SetDrawlist(ImGui::GetWindowDrawList());
   ImGuizmo::SetOrthographic(false);
   const float w = static_cast<float>(v->vw), h = static_cast<float>(v->vh);
   ImGuizmo::SetRect(v->image_pos.x, v->image_pos.y, w, h);
   // the axes about a fifth of the view's shorter side, in [40, 120] pixels; ImGuizmo's size is in clip space,
   // measured along the view's longer side
   const float px = std::clamp(0.2f * std::min(w, h), 40.0f, 120.0f);
   ImGuizmo::SetGizmoSizeClipSpace(2.0f * px / std::max(std::max(w, h), 1.0f));
   ImGuizmo::AllowAxisFlip(false); // the arrows point along +x, +y, +z (ImGuizmo's default flips them to the eye)
   float fv[16], fp[16], fm[16];
   double o[3];
   gizmo_matrices(*v, fv, fp, o);
   for (int k = 0; k < 16; ++k) fm[k] = static_cast<float>(matrix[k] - (k >= 12 && k < 15 ? o[k - 12] : 0.0));
   static const ImGuizmo::OPERATION OPS[3] = {ImGuizmo::TRANSLATE, ImGuizmo::ROTATE, ImGuizmo::SCALE};
   float s3[3] = {static_cast<float>(snap), static_cast<float>(snap), static_cast<float>(snap)};
   const ImGuiID gid = ImGui::GetID(label.c_str());
   ImGuizmo::PushID(static_cast<int>(gid));
   bool moved = false;
   {
      const mouse_guard guard;
      moved = ImGuizmo::Manipulate(fv, fp, OPS[mode], space == 1 ? ImGuizmo::LOCAL : ImGuizmo::WORLD, fm, nullptr,
                                   has_snap ? s3 : nullptr);
   }
   const bool using_it = ImGuizmo::IsUsing();
   const bool over = ImGuizmo::GetHoveredHandleType() != ImGuizmo::MT_NONE;
   ImGuizmo::PopID();
   hold_active(gid, using_it);
   if (using_it || over) v->overlay_frame = ImGui::GetFrameCount();
   if (moved) {
      for (int k = 0; k < 16; ++k) matrix[k] = static_cast<double>(fm[k]) + (k >= 12 && k < 15 ? o[k - 12] : 0.0);
      matrix[3] = matrix[7] = matrix[11] = 0.0, matrix[15] = 1.0;
      *changed = 1;
   }
   return FIG_OK;
   V3_CATCH
}

} // extern "C"
