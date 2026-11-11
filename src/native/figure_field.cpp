// A field through a colormap (ip_field_image, src/lib/figure_implot.F90): a real32 or real64 matrix coloured into an
// RGBA texture and drawn as one ImPlot image. The texture is cached by the item's ImGui id and coloured again only
// when the program says the values changed, or the array (address, shape, kind), the range, the colormap (or its
// colours, edited by ig_gradient_edit), the scale or the NaN colour differ from the last colouring; an entry not
// drawn for IDLE_SECONDS is released at the end of a frame. Every argument is checked on the Fortran side; main
// thread only, inside a plot.
//
// Colouring. A value v maps to t = (s(v) - s(lo)) / (s(hi) - s(lo)), s the scale (identity, log10, or ImPlot's symlog
// 2 asinh(v/2)), v clamped to [lo, hi] first, then to the colormap's colour at t as ImPlot samples it
// (ImPlotColormapData::LerpTable, what SampleColormap and the colour-scale legend give). Non-finite values, and
// values <= 0 on a log scale, take the NaN colour.
// - linear: per pixel (exact): one subtraction, one multiplication, a table lookup;
// - log and symlog, fields of at least LUT_MIN_PIXELS: a table indexed by the value's single-precision bits
//   (ImPlotExtra.jl's trick), restricted to the range: the order-preserving 32-bit key of a float is monotonic in
//   the value, so the keys of [lo, hi] are one interval, cut into at most 65536 bins; each bin gets the colour of the
//   value at its centre, so log10 and asinh run 65536 times instead of once per pixel. Measured (1024 x 1024,
//   gcc -O2, x86-64): log 6.8 ms per pixel, 1.4 ms by the table; symlog 10.4 ms, 1.1 ms; the colours differ from
//   the per-pixel ones by at most 1/255 per channel (one step of the colormap's own table). For linear the table
//   gains 1.2-1.6x at the same 1/255: not taken, linear stays exact. Ranges narrower than single precision (lo and
//   hi the same float) and small fields are coloured per pixel.
#include "figure_native.h"

#include "imgui.h"
#include "imgui_internal.h"
#include "implot.h"
#include "implot_internal.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <string>
#include <unordered_map>
#include <vector>

namespace {

constexpr double IDLE_SECONDS = 10.0;            // an entry not drawn for this long is released
constexpr std::size_t LUT_MIN_PIXELS = 1u << 17;  // the bit table above this many pixels (log, symlog)
constexpr std::uint32_t LUT_BINS = 65536u;        // at most this many bins

enum scale_t { LINEAR = 0, LOG = 1, SYMLOG = 2 };

struct entry_t {
   std::string label;                  // for the tests' lookups
   unsigned long long tex = 0;         // texture id (0: none)
   int nx = 0, ny = 0, kind = 0;       // shape and kind (4, 8) of the array coloured last
   const void *data = nullptr;         // its address
   int has_vmin = 0, has_vmax = 0;     // range given
   double vmin = 0.0, vmax = 0.0;      // ... its ends
   double lo = 0.0, hi = 1.0;          // the range applied
   int cmap = -1, scale = LINEAR;      // colormap, scale
   unsigned colormaps = 0;             // fig_colormap_generation (a colormap edited: coloured again)
   ImU32 nan = 0;                      // NaN colour
   double last_time = 0.0;             // ImGui::GetTime() of the last drawing
   int last_frame = -1;                // ImGui::GetFrameCount() of the last drawing
   std::vector<ImU32> rgba;            // the colours uploaded last
};

std::unordered_map<ImGuiID, entry_t> cache;
long long uploads = 0;                 // colourings uploaded since the start (test_field_uploads)
double last_ms = 0.0;                  // the last colouring's time [ms] (test_field_time)

int fail(int status, const std::string &msg) {
   fig_set_last_error(msg.c_str(), static_cast<int>(msg.size()));
   return status;
}

inline double forward(int scale, double v) {
   return scale == LINEAR ? v : scale == LOG ? std::log10(v) : 2.0 * std::asinh(v / 2.0); // ImPlot's symlog
}

inline std::uint32_t key(float x) { // order-preserving: a < b <=> key(a) < key(b), for non-NaN floats
   std::uint32_t u;
   std::memcpy(&u, &x, 4);
   return u ^ ((u & 0x80000000u) ? 0xffffffffu : 0x80000000u);
}

inline float unkey(std::uint32_t k) {
   const std::uint32_t u = k ^ ((k & 0x80000000u) ? 0x80000000u : 0xffffffffu);
   float x;
   std::memcpy(&x, &u, 4);
   return x;
}

inline bool masked(int scale, double v) { return !std::isfinite(v) || (scale == LOG && v <= 0.0); }

// the range of the finite values (positive ones on a log scale); false when there is none
template <class T> bool data_range(const T *f, std::size_t n, int scale, double &lo, double &hi) {
   bool any = false;
   for (std::size_t k = 0; k < n; ++k) {
      const double v = f[k];
      if (masked(scale, v)) continue;
      if (!any) {
         lo = hi = v;
         any = true;
      } else {
         lo = std::min(lo, v);
         hi = std::max(hi, v);
      }
   }
   return any;
}

template <class T> void colour(const T *f, std::size_t n, entry_t &e) {
   const ImPlotColormapData &cd = ImPlot::GetCurrentContext()->ColormapData;
   ImU32 *out = e.rgba.data();
   const int scale = e.scale;
   const ImU32 nanc = e.nan;
   const double lo = std::min(e.lo, e.hi), hi = std::max(e.lo, e.hi);
   if (e.lo == e.hi) { // a constant field: the colormap's middle
      const ImU32 mid = cd.LerpTable(e.cmap, 0.5f);
      for (std::size_t k = 0; k < n; ++k) out[k] = masked(scale, f[k]) ? nanc : mid;
      return;
   }
   const double s0 = forward(scale, e.lo), inv = 1.0 / (forward(scale, e.hi) - s0);
   auto at = [&](double v) { // the colour of a value in [lo, hi]
      const double t = (forward(scale, v) - s0) * inv;
      return cd.LerpTable(e.cmap, static_cast<float>(std::clamp(t, 0.0, 1.0)));
   };
   const float flo = static_cast<float>(lo), fhi = static_cast<float>(hi);
   const bool table = scale != LINEAR && n >= LUT_MIN_PIXELS && flo < fhi && std::isfinite(flo) && std::isfinite(fhi);
   if (!table) {
      for (std::size_t k = 0; k < n; ++k) {
         const double v = f[k];
         out[k] = masked(scale, v) ? nanc : at(std::clamp(v, lo, hi));
      }
      return;
   }
   const std::uint32_t k0 = key(flo), span = key(fhi) - k0;
   int shift = 0;
   while ((span >> shift) >= LUT_BINS - 1u) ++shift;
   const std::uint32_t bins = (span >> shift) + 1u;
   std::vector<ImU32> lut(bins);
   for (std::uint32_t i = 0; i < bins; ++i) {
      std::uint32_t kc = k0 + (i << shift) + ((1u << shift) >> 1); // the bin's centre
      if (kc - k0 > span) kc = k0 + span;
      lut[i] = at(std::clamp(static_cast<double>(unkey(kc)), lo, hi));
   }
   for (std::size_t k = 0; k < n; ++k) {
      const double v = f[k];
      if (masked(scale, v)) {
         out[k] = nanc;
         continue;
      }
      out[k] = lut[(key(std::clamp(static_cast<float>(v), flo, fhi)) - k0) >> shift];
   }
}

ImU32 to_u32(const float *c) {
   auto b = [](float x) { return static_cast<ImU32>(std::lround(std::clamp(x, 0.0f, 1.0f) * 255.0f)); };
   return b(c[0]) | (b(c[1]) << 8) | (b(c[2]) << 16) | (b(c[3]) << 24);
}

} // namespace

int fig_field_image(const char *label, int label_len, const void *data, int kind, int nx, int ny, double x0,
                    double x1, double y0, double y1, int cmap, int has_vmin, double vmin, int has_vmax, double vmax,
                    int scale, const float *nan_rgba, int changed, double *range) {
   try {
      if (!ImPlot::GetCurrentContext() || !ImPlot::GetCurrentPlot())
         return fail(FIG_ERR_STATE, "ip_field_image: no plot is being declared");
      const std::string name(label, static_cast<std::size_t>(std::max(label_len, 0)));
      const ImGuiID id = ImHashStr(name.c_str(), 0, ImPlot::GetCurrentPlot()->ID); // the label in its plot
      const ImU32 nanc = to_u32(nan_rgba);
      entry_t &e = cache[id];
      const bool again = e.tex == 0 || changed || e.data != data || e.kind != kind || e.nx != nx || e.ny != ny ||
                         e.cmap != cmap || e.colormaps != fig_colormap_generation() || e.scale != scale ||
                         e.nan != nanc || e.has_vmin != has_vmin ||
                         e.has_vmax != has_vmax || (has_vmin && e.vmin != vmin) || (has_vmax && e.vmax != vmax);
      e.label = name;
      e.last_time = ImGui::GetTime();
      e.last_frame = ImGui::GetFrameCount();
      if (again) {
         const auto t0 = std::chrono::steady_clock::now();
         const std::size_t n = static_cast<std::size_t>(nx) * static_cast<std::size_t>(ny);
         if (e.tex == 0 || e.nx != nx || e.ny != ny) {
            if (e.tex != 0) fig_texture_destroy(e.tex);
            e.tex = 0;
            unsigned long long tex = 0;
            const int status = fig_texture_create(nx, ny, 0, &tex);
            if (status != FIG_OK) {
               cache.erase(id);
               return status;
            }
            e.tex = tex;
         }
         e.data = data;
         e.kind = kind;
         e.nx = nx;
         e.ny = ny;
         e.cmap = cmap;
         e.colormaps = fig_colormap_generation();
         e.scale = scale;
         e.nan = nanc;
         e.has_vmin = has_vmin;
         e.has_vmax = has_vmax;
         e.vmin = vmin;
         e.vmax = vmax;
         double lo = 0.0, hi = 1.0;
         bool any = has_vmin && has_vmax; // the data's range only when needed
         if (!any)
            any = kind == 4 ? data_range(static_cast<const float *>(data), n, scale, lo, hi)
                            : data_range(static_cast<const double *>(data), n, scale, lo, hi);
         if (!any) { // nothing to measure: [0, 1], or [1, 10] on a log scale
            lo = scale == LOG ? 1.0 : 0.0;
            hi = scale == LOG ? 10.0 : 1.0;
         }
         e.lo = has_vmin ? vmin : lo;
         e.hi = has_vmax ? vmax : hi;
         if (scale == LOG && (e.lo <= 0.0 || e.hi <= 0.0)) { // one end given, the other from data on its wrong side
            e.lo = e.lo > 0.0 ? e.lo : e.hi / 10.0;
            e.hi = e.hi > 0.0 ? e.hi : e.lo * 10.0;
         }
         e.rgba.resize(n);
         if (kind == 4) colour(static_cast<const float *>(data), n, e);
         else colour(static_cast<const double *>(data), n, e);
         const int status = fig_texture_update(e.tex, nx, ny, reinterpret_cast<const unsigned char *>(e.rgba.data()));
         if (status != FIG_OK) return status;
         ++uploads;
         last_ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t0).count();
      }
      range[0] = e.lo;
      range[1] = e.hi;
      // the texture's pixel (i, j) is f(i, j): row 1 at y0 (v = 1 at the top, as ip_image)
      fig_texture_sampling(1, 1);
      ImPlot::PlotImage(name.c_str(), ImTextureRef(static_cast<ImTextureID>(e.tex)), ImPlotPoint(x0, y0),
                        ImPlotPoint(x1, y1), ImVec2(0.0f, 1.0f), ImVec2(1.0f, 0.0f));
      fig_texture_sampling(1, 0);
      return FIG_OK;
   } catch (const std::exception &e) {
      return fail(FIG_ERR_EXCEPTION, std::string("ip_field_image: C++ exception: ") + e.what());
   } catch (...) {
      return fail(FIG_ERR_EXCEPTION, "ip_field_image: unknown C++ exception");
   }
}

void fig_field_sweep(void) {
   try {
      if (!ImGui::GetCurrentContext()) return;
      const double now = ImGui::GetTime();
      const int frame = ImGui::GetFrameCount();
      for (auto it = cache.begin(); it != cache.end();) {
         if (it->second.last_frame != frame && now - it->second.last_time > IDLE_SECONDS) {
            if (it->second.tex != 0) fig_texture_destroy(it->second.tex);
            it = cache.erase(it);
         } else {
            ++it;
         }
      }
   } catch (...) {
   }
}

void fig_field_reset(void) { cache.clear(); } // fig_shutdown releases the textures themselves

long long fig_field_uploads(void) { return uploads; }

int fig_field_count(void) { return static_cast<int>(cache.size()); }

double fig_field_time(void) { return last_ms; }

int fig_field_pixel(const char *label, int label_len, int i, int j, float *rgba) {
   const std::string name(label, static_cast<std::size_t>(std::max(label_len, 0)));
   for (const auto &kv : cache) {
      const entry_t &e = kv.second;
      if (e.label != name) continue;
      if (i < 1 || i > e.nx || j < 1 || j > e.ny || e.rgba.empty())
         return fail(FIG_ERR_ARGUMENT, "test_field_pixel: pixel out of the field");
      const ImU32 c = e.rgba[static_cast<std::size_t>(j - 1) * static_cast<std::size_t>(e.nx) + (i - 1)];
      for (int k = 0; k < 4; ++k) rgba[k] = static_cast<float>((c >> (8 * k)) & 0xffu) / 255.0f;
      return FIG_OK;
   }
   return fail(FIG_ERR_ARGUMENT, "test_field_pixel: no field '" + name + "' is cached");
}
