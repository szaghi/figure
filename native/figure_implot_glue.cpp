// The native layer's ImPlot and ImPlot3D side (szaghi/figure#15 G2): the contexts, ImPlot's and ImPlot3D's styles as a
// store of the plots' styles (figure_plot_backend.h), the canvas's plot layer, the scope record's plot entries, the
// plot queries and items of the current path (fig_plot_*), the drop targets of a plot. Registered by this file's static
// initializer (fig_implot), so present in the programs that link it: those that reference one of its functions (the
// current path's figure_implot; the Fortran path's side-by-side tests, through their reference modules) or a part
// that anchors it (fig_implot_glue_anchor: the colormaps, the fields, the 3-D plots, the plot links). A program of the
// Fortran path that plots with the Fortran frames links none of it, and no ImPlot.
#include "figure_native.h"
#include "figure_plot_backend.h"
#include "figure_style.h"

#include "imgui.h"
#include "imgui_internal.h"
#include "implot.h"
#include "implot_internal.h"
#include "implot3d.h"
#include "implot3d_internal.h"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

// figure_dnd.cpp's checks and delivery, shared with the plot's drop targets below
int figure_dnd_type_ok(const std::string &type, const char *who);
int figure_dnd_accept(const std::string &type, int *len);

namespace {

int fail(int status, const std::string &msg) {
   fig_set_last_error(msg.c_str(), static_cast<int>(msg.size()));
   return status;
}

// ---- the contexts ------------------------------------------------------------------------------------------------

void create() {
   ImPlot::CreateContext();
   ImPlot3D::CreateContext(); // the small 3-D figures (figure_plot3d.cpp)
}

void destroy() {
   if (ImPlot3D::GetCurrentContext()) ImPlot3D::DestroyContext();
   if (ImPlot::GetCurrentContext()) ImPlot::DestroyContext();
   fig_plot_links_reset(); // the link groups belong to the plots
}

// ---- the styles: ImPlot's (lib 1) and ImPlot3D's (lib 2) as a store (fig_pstyle_store_t) ------------------------------

ImVec4 *colors_of(int lib) { return lib == 1 ? ImPlot::GetStyle().Colors : ImPlot3D::GetStyle().Colors; }

int color_index(int lib, const std::string &name) {
   const int n = lib == 1 ? static_cast<int>(ImPlotCol_COUNT) : static_cast<int>(ImPlot3DCol_COUNT);
   for (int i = 0; i < n; ++i)
      if (name == (lib == 1 ? ImPlot::GetStyleColorName(i) : ImPlot3D::GetStyleColorName(i))) return i;
   return -1;
}

const figure_style::field *field_of(int lib, const std::string &name) {
   const figure_style::field *t = lib == 1 ? figure_style::IMPLOT_FIELDS : figure_style::IMPLOT3D_FIELDS;
   const int n = lib == 1 ? figure_style::IMPLOT_FIELDS_COUNT : figure_style::IMPLOT3D_FIELDS_COUNT;
   for (int i = 0; i < n; ++i)
      if (name == t[i].name) return &t[i];
   return nullptr;
}

unsigned char *base_of(int lib) {
   return lib == 1 ? reinterpret_cast<unsigned char *>(&ImPlot::GetStyle())
                   : reinterpret_cast<unsigned char *>(&ImPlot3D::GetStyle());
}

int ncomp_of(const figure_style::field &f) { return f.kind == figure_style::FIG_STYLE_VEC2 ? 2 : 1; }

size_t size_of(const figure_style::field &f) {
   return f.kind == figure_style::FIG_STYLE_VEC2 ? sizeof(ImVec2)
          : f.kind == figure_style::FIG_STYLE_BOOL ? sizeof(bool)
          : f.kind == figure_style::FIG_STYLE_FLOAT ? sizeof(float) : sizeof(int);
}

void write(unsigned char *base, const figure_style::field &f, const double *v) {
   unsigned char *p = base + f.offset;
   switch (f.kind) {
   case figure_style::FIG_STYLE_FLOAT: *reinterpret_cast<float *>(p) = static_cast<float>(v[0]); break;
   case figure_style::FIG_STYLE_VEC2:
      *reinterpret_cast<ImVec2 *>(p) = ImVec2(static_cast<float>(v[0]), static_cast<float>(v[1]));
      break;
   case figure_style::FIG_STYLE_BOOL: *reinterpret_cast<bool *>(p) = v[0] != 0.0; break;
   default: *reinterpret_cast<int *>(p) = static_cast<int>(v[0]); break;
   }
}

void read(const unsigned char *base, const figure_style::field &f, double *v) {
   const unsigned char *p = base + f.offset;
   switch (f.kind) {
   case figure_style::FIG_STYLE_FLOAT: v[0] = *reinterpret_cast<const float *>(p); break;
   case figure_style::FIG_STYLE_VEC2:
      v[0] = reinterpret_cast<const ImVec2 *>(p)->x;
      v[1] = reinterpret_cast<const ImVec2 *>(p)->y;
      break;
   case figure_style::FIG_STYLE_BOOL: v[0] = *reinterpret_cast<const bool *>(p) ? 1.0 : 0.0; break;
   default: v[0] = *reinterpret_cast<const int *>(p); break;
   }
}

int style_color(int lib, const char *name, int name_len, int mode, float *rgba) {
   const int i = color_index(lib, std::string(name, static_cast<size_t>(std::max(name_len, 0))));
   if (i < 0) return 1;
   if (mode == 1) {
      colors_of(lib)[i] = ImVec4(rgba[0], rgba[1], rgba[2], rgba[3]);
      return 0;
   }
   // as stored (an automatic colour unresolved), or ImPlot's automatic colours resolved, as ImPlot draws them
   const ImVec4 c = mode == 0 && lib == 1 ? ImPlot::GetStyleColorVec4(i) : colors_of(lib)[i];
   rgba[0] = c.x, rgba[1] = c.y, rgba[2] = c.z, rgba[3] = c.w;
   return 0;
}

int style_var(int lib, const char *name, int name_len, int set, double *values, int *count) {
   const figure_style::field *f = field_of(lib, std::string(name, static_cast<size_t>(std::max(name_len, 0))));
   if (!f) return 1;
   if (set) {
      if (*count != ncomp_of(*f)) {
         *count = ncomp_of(*f);
         return 2;
      }
      write(base_of(lib), *f, values);
      return 0;
   }
   *count = ncomp_of(*f);
   read(base_of(lib), *f, values);
   return 0;
}

// The pushes of lib 1 and 2, newest last: where a value was and its bytes before (popped by fig_pop_style's order).
struct saved_t {
   unsigned char             *where = nullptr;
   std::vector<unsigned char> was;
};
std::vector<saved_t> pushed_colors, pushed_vars;

void remember(std::vector<saved_t> &stack, unsigned char *where, size_t size) {
   saved_t s;
   s.where = where;
   s.was.assign(where, where + size);
   stack.push_back(std::move(s));
}

int style_push(int lib, int vars, const char *name, int name_len, const double *values, int count) {
   const std::string n(name, static_cast<size_t>(std::max(name_len, 0)));
   if (vars) {
      const figure_style::field *f = field_of(lib, n);
      if (!f) return 1;
      if (count != ncomp_of(*f)) return 2;
      remember(pushed_vars, base_of(lib) + f->offset, size_of(*f));
      write(base_of(lib), *f, values);
      return 0;
   }
   const int i = color_index(lib, n);
   if (i < 0) return 1;
   if (count != 4) return 2;
   ImVec4 &c = colors_of(lib)[i];
   remember(pushed_colors, reinterpret_cast<unsigned char *>(&c), sizeof(ImVec4));
   c = ImVec4(static_cast<float>(values[0]), static_cast<float>(values[1]), static_cast<float>(values[2]),
              static_cast<float>(values[3]));
   return 0;
}

void style_pop(int, int vars) {
   std::vector<saved_t> &stack = vars ? pushed_vars : pushed_colors;
   if (stack.empty()) return;
   const saved_t &s = stack.back();
   std::memcpy(s.where, s.was.data(), s.was.size());
   stack.pop_back();
}

// A style being built (ops 1-6) and save_style's reference (ops 11-16), ImPlot's (themes set no ImPlot3D style).
ImPlotStyle pending, scratch;

int style_theme(int op, const char *name, int name_len, const double *values, int count) {
   ImPlotStyle &p = op > 10 ? scratch : pending;
   const std::string n(name, static_cast<size_t>(std::max(name_len, 0)));
   switch (op > 10 ? op - 10 : op) {
   case 1: p = ImPlotStyle(); break;
   case 2: p = ImPlot::GetStyle(); break;
   case 3:
      for (ImVec4 &c : p.Colors) c = IMPLOT_AUTO_COL; // as ImPlot::StyleColorsAuto, which also resets MinorAlpha
      break;
   case 4: { // the variables to the defaults, the colours and the colormap kept (a look)
      ImPlotStyle d;
      std::memcpy(d.Colors, p.Colors, sizeof(d.Colors));
      d.Colormap = p.Colormap;
      p = d;
      break;
   }
   case 5: {
      const figure_style::field *f = field_of(1, n);
      if (!f) return 1;
      if (count != ncomp_of(*f)) return 2;
      write(reinterpret_cast<unsigned char *>(&p), *f, values);
      break;
   }
   case 6: {
      const int i = color_index(1, n);
      if (i < 0) return 1;
      if (count != 4) return 2;
      p.Colors[i] = ImVec4(static_cast<float>(values[0]), static_cast<float>(values[1]), static_cast<float>(values[2]),
                           static_cast<float>(values[3]));
      break;
   }
   case 7: ImPlot::GetStyle() = pending; break;
   default: break;
   }
   return 0;
}

int style_field(int which, int colour, int index, char *name, int cap, double *values, int *type) {
   const ImPlotStyle &p = which == 1 ? scratch : ImPlot::GetStyle();
   const char *nm = nullptr;
   if (colour) {
      if (index < 0 || index >= ImPlotCol_COUNT) return 0;
      nm = ImPlot::GetStyleColorName(index);
      const ImVec4 &c = p.Colors[index];
      values[0] = c.x, values[1] = c.y, values[2] = c.z, values[3] = c.w;
      *type = 0;
   } else {
      if (index < 0 || index >= figure_style::IMPLOT_FIELDS_COUNT) return 0;
      const figure_style::field &f = figure_style::IMPLOT_FIELDS[index];
      nm = f.name;
      read(reinterpret_cast<const unsigned char *>(&p), f, values);
      *type = f.kind == figure_style::FIG_STYLE_VEC2 ? 1 : f.kind == figure_style::FIG_STYLE_BOOL ? 2 : 0;
   }
   if (cap > 0) {
      std::strncpy(name, nm, static_cast<size_t>(cap - 1));
      name[cap - 1] = '\0';
   }
   return 1;
}

void style_editor() { ImPlot::ShowStyleEditor(); }

void lines(const char *cmap_name, const unsigned int *keys, int n) {
   int cmap = ImPlotColormap_Deep;
   if (n > 0) {
      cmap = ImPlot::GetColormapIndex(cmap_name); // ImPlot keeps colormaps for the context's life
      if (cmap < 0) cmap = ImPlot::AddColormap(cmap_name, keys, n, true);
   }
   ImPlot::GetStyle().Colormap = cmap;
}

int saved_lines(unsigned int *keys, int cap) {
   const ImPlotColormap cmap = ImPlot::GetStyle().Colormap;
   if (cmap == ImPlotColormap_Deep) return -1;
   const int n = ImPlot::GetColormapSize(cmap);
   for (int i = 0; i < n && i < cap; ++i) keys[i] = ImPlot::GetColormapColorU32(i, cmap);
   return n;
}

// ---- the canvas's plot layer -------------------------------------------------------------------------------------

// A pixel coordinate computed in double precision from plot units, kept within 1e7 pixels of the display's origin: a
// point far outside the plot (a strong zoom) would overflow single precision when ImGui stores it (a trap under
// -ffpe-trap=overflow), and 1e7 pixels is still far beyond any display, so the visible part of a line hardly moves.
float to_pixel(double v) {
   constexpr double LIMIT = 1.0e7;
   return static_cast<float>(std::min(std::max(v, -LIMIT), LIMIT));
}

// One plot coordinate to pixels along an ImPlot axis, in double precision (ImPlotAxis::PlotToPixels, before its cast).
double axis_to_pixel(const ImPlotAxis &a, double plt) {
   if (a.TransformForward != nullptr) {
      const double s = a.TransformForward(plt, a.TransformData);
      const double t = (s - a.ScaleMin) / (a.ScaleMax - a.ScaleMin);
      plt = a.Range.Min + a.Range.Size() * t;
   }
   return a.PixelMin + a.ScaleToPixel * (plt - a.Range.Min);
}

ImDrawList *plot_layer(int n, const double *x, const double *y, float *px, float *py) {
   ImPlotContext *gp = ImPlot::GetCurrentContext();
   if (gp == nullptr || gp->CurrentPlot == nullptr) return nullptr;
   ImPlot::SetupLock(); // the axes' ranges and pixels are final from here (ImPlot's own PlotToPixels does the same)
   ImPlotPlot &plot = *gp->CurrentPlot;
   const ImPlotAxis &ax = plot.Axes[plot.CurrentX], &ay = plot.Axes[plot.CurrentY];
   ImDrawList *dl = ImPlot::GetPlotDrawList();
   for (int i = 0; i < n; ++i) px[i] = to_pixel(axis_to_pixel(ax, x[i])), py[i] = to_pixel(axis_to_pixel(ay, y[i]));
   ImPlot::PushPlotClipRect();
   return dl;
}

void plot_layer_end() { ImPlot::PopPlotClipRect(); }

ImDrawList *plot_draw_list() { return ImPlot::GetPlotDrawList(); }

// ---- the scope record --------------------------------------------------------------------------------------------

void snapshot(void **open) {
   open[0] = open[1] = open[2] = nullptr;
   if (ImPlot::GetCurrentContext()) {
      open[0] = GImPlot->CurrentPlot;
      open[1] = GImPlot->CurrentSubplot;
   }
   if (ImPlot3D::GetCurrentContext()) open[2] = ImPlot3D::GImPlot3D->CurrentPlot;
}

void recover(void *const *then) {
   if (ImPlot::GetCurrentContext() && GImPlot->CurrentPlot && !then[0]) fig_plot_end();
   if (ImPlot::GetCurrentContext() && GImPlot->CurrentSubplot && !then[1]) ImPlot::EndSubplots();
   if (ImPlot3D::GetCurrentContext() && ImPlot3D::GImPlot3D->CurrentPlot && !then[2]) fig_plot3d_end();
}

int close(int kind) {
   switch (kind) {
   case FIG_PLOT_KIND_PLOT: fig_plot_end(); return 1;
   case FIG_PLOT_KIND_SUBPLOTS: ImPlot::EndSubplots(); return 1;
   case FIG_PLOT_KIND_PLOT3D: fig_plot3d_end(); return 1;
   case FIG_PLOT_KIND_ALIGNED: ImPlot::EndAlignedPlots(); return 1;
   case FIG_PLOT_KIND_LEGEND_POPUP: ImPlot::EndLegendPopup(); return 1;
   default: return 0;
   }
}

fig_implot_backend_t backend = {
   create,
   destroy,
   {style_color, style_var, style_push, style_pop, style_theme, style_field, style_editor},
   lines,
   saved_lines,
   plot_layer,
   plot_layer_end,
   plot_draw_list,
   snapshot,
   recover,
   close,
};

// Registered at load: the programs that link this file have the plot side.
const int registered = (fig_implot = &backend, 0);

} // namespace

extern "C" {

void fig_implot_glue_anchor(void) {}

// ImPlot's EndPlot fits the axes asked to fit this frame (every axis of a plot on its first frame, an auto-fitting
// axis, a double click): an axis that received no data has empty extents (+inf, -inf), and ImPlotAxis::ApplyFit
// computes (-inf) * padding, NaN with the default padding 0: an invalid operation, which stops a program built with
// -ffpe-trap=invalid (gfortran's debug flags) at a plot that has no data yet. Without traps ImPlot then ignores the
// NaN and keeps the axis's range, so not fitting such an axis draws the same plot.
void fig_plot_end(void) {
   if (!ImPlot::GetCurrentContext() || !GImPlot->CurrentPlot) return;
   ImPlot::SetupLock(); // as EndPlot would: a plot without items finishes its setup there, which asks for the fits
   ImPlotPlot &p = *GImPlot->CurrentPlot;
   for (int i = 0; i < ImAxis_COUNT; ++i) {
      ImPlotAxis &a = p.Axes[i];
      if (a.FitThisFrame && a.FitExtents.Min > a.FitExtents.Max) a.FitThisFrame = false; // no data: nothing to fit
   }
   ImPlot::EndPlot();
}

int fig_plot_state(int *enabled, int *scale) {
   for (int i = 0; i < ImAxis_COUNT; ++i) {
      enabled[i] = 0;
      scale[i] = ImPlotScale_Linear;
   }
   if (!ImPlot::GetCurrentContext() || !GImPlot->CurrentPlot) return 0;
   const ImPlotPlot &p = *GImPlot->CurrentPlot;
   for (int i = 0; i < ImAxis_COUNT; ++i) {
      enabled[i] = p.Axes[i].Enabled ? 1 : 0;
      scale[i] = p.Axes[i].Scale;
   }
   return p.SetupLocked ? 2 : 1;
}

int fig_plot_x_transform(double *v, int *scale) {
   // name map: implot_items.cpp Transformer1 (the pixel of an abscissa, as the items compute it)
   for (int i = 0; i < 9; ++i) v[i] = 0.0;
   *scale = ImPlotScale_Linear;
   if (!ImPlot::GetCurrentContext() || !GImPlot->CurrentPlot) return 0;
   ImPlot::SetupLock(); // as an item would: the ranges, the plot area and the transforms final for this frame
   const ImPlotPlot &p = *GImPlot->CurrentPlot;
   const ImPlotAxis &a = p.Axes[p.CurrentX];
   v[0] = a.PixelMin;
   v[1] = a.Range.Min;
   v[2] = a.Range.Max;
   v[3] = a.ScaleToPixel;
   v[4] = a.ScaleMin;
   v[5] = a.ScaleMax;
   v[6] = p.PlotRect.Min.x;
   v[7] = p.PlotRect.Max.x;
   v[8] = ImGui::GetIO().DisplayFramebufferScale.x;
   *scale = a.Scale;
   if (a.TransformForward != nullptr && a.Scale != ImPlotScale_Log10 && a.Scale != ImPlotScale_SymLog) *scale = -1;
   return 1;
}

void fig_plot_axis_constraints(int axis, int given, const double *v) {
   if (!ImPlot::GetCurrentContext() || !GImPlot->CurrentPlot || axis < 0 || axis >= ImAxis_COUNT) return;
   // name map: ImPlot::SetupAxisLimitsConstraints, ImPlot::SetupAxisZoomConstraints (each sets both ends at once)
   ImPlotAxis &a = GImPlot->CurrentPlot->Axes[axis];
   if (given & 1) a.ConstraintRange.Min = v[0];
   if (given & 2) a.ConstraintRange.Max = v[1];
   if (given & 4) a.ConstraintZoom.Min = v[2];
   if (given & 8) a.ConstraintZoom.Max = v[3];
}

// A tick label of the plot being declared (between BeginPlot and EndPlot, after its setup): axis 0 x, 1 y; index from 1;
// count is the number of ticks. For tests of axis formats.
int fig_plot_tick_label(int axis, int index, char *buf, int buf_len, int *count, int *len) {
   *count = 0;
   *len = 0;
   ImPlotPlot *plot = ImPlot::GetCurrentContext() ? ImPlot::GetCurrentPlot() : nullptr;
   if (!plot)
      return fail(FIG_ERR_STATE, "test_plot_tick: no plot is being declared (between ip_begin_plot and ip_end_plot)");
   static const char *names[ImAxis_COUNT] = {"x1", "x2", "x3", "y1", "y2", "y3"};
   if (axis < 0 || axis >= ImAxis_COUNT)
      return fail(FIG_ERR_ARGUMENT, "test_plot_tick: unknown axis ('x1', 'x2', 'x3', 'y1', 'y2', 'y3', 'x' or 'y')");
   if (!plot->Axes[axis].Enabled)
      return fail(FIG_ERR_STATE, std::string("test_plot_tick: axis '") + names[axis] +
                                 "' is not set up (ip_setup_axis('" + names[axis] + "'))");
   ImPlot::SetupLock(); // the ticks exist once the setup is locked (the first item locks it)
   const ImPlotTicker &ticker = plot->Axes[axis].Ticker;
   *count = ticker.TickCount();
   if (index < 1 || index > *count) return FIG_OK;
   const char *text = ticker.GetText(index - 1);
   *len = static_cast<int>(std::strlen(text));
   const int n = std::min(*len, buf_len);
   if (n > 0) std::memcpy(buf, text, static_cast<size_t>(n));
   return FIG_OK;
}

// An annotation of the plot being declared: text in a box at (x, y) [plot units], offset [pixels] (0: centred), drawn at
// EndPlot; rgba[3] = 0: no box, the plot's inlay text colour. Refused outside a plot (ImPlot would assert).
int fig_plot_annotation(double x, double y, const float *rgba, float dx, float dy, int clamp, const char *text,
                        int text_len) {
   if (!ImPlot::GetCurrentContext() || !ImPlot::GetCurrentPlot())
      return fail(FIG_ERR_STATE, "ip_annotation: no plot is being declared (between ip_begin_plot and ip_end_plot)");
   const std::string t(text, text_len > 0 ? static_cast<size_t>(text_len) : 0);
   ImPlot::Annotation(x, y, ImVec4(rgba[0], rgba[1], rgba[2], rgba[3]), ImVec2(dx, dy), clamp != 0, "%s", t.c_str());
   return FIG_OK;
}

// A tag of the plot being declared on the axis `axis` (an ImAxis set up on this frame) at `value` [axis units], drawn at
// EndPlot over the axis: a box of colour rgba (rgba[3] < 0: the colour of the last item drawn; alpha 0: no box, the
// axis's text colour) holding `text` (has_text 1) or the value labelled as the axis labels its ticks (has_text 0).
// Refused outside a plot and for an axis not set up (ImPlot would assert, or draw on a hidden axis).
int fig_plot_tag(int axis, double value, const float *rgba, const char *text, int text_len, int has_text) {
   if (!ImPlot::GetCurrentContext() || !ImPlot::GetCurrentPlot())
      return fail(FIG_ERR_STATE, "ip_tag: no plot is being declared (call it between a true ip_begin_plot and ip_end_plot)");
   if (axis < 0 || axis >= ImAxis_COUNT || !GImPlot->CurrentPlot->Axes[axis].Enabled)
      return fail(FIG_ERR_STATE, "ip_tag: the axis is not set up");
   const ImVec4 c = rgba[3] < 0.0f ? ImPlot::GetLastItemColor() : ImVec4(rgba[0], rgba[1], rgba[2], rgba[3]);
   const std::string t(text, text_len > 0 ? static_cast<size_t>(text_len) : 0);
   // ImPlot's public TagX/TagY tag the current axes (its Tag(ImAxis, ...) is not in a header): the axis is made current
   // for the call, then the program's current axes are restored
   ImPlotPlot &plot = *GImPlot->CurrentPlot;
   const ImAxis cx = plot.CurrentX, cy = plot.CurrentY;
   if (axis < ImAxis_Y1) {
      plot.CurrentX = axis;
      if (has_text != 0) ImPlot::TagX(value, c, "%s", t.c_str());
      else ImPlot::TagX(value, c, false);
   } else {
      plot.CurrentY = axis;
      if (has_text != 0) ImPlot::TagY(value, c, "%s", t.c_str());
      else ImPlot::TagY(value, c, false);
   }
   plot.CurrentX = cx;
   plot.CurrentY = cy;
   return FIG_OK;
}

// where: 1 the plot, 2 an axis (ImAxis `axis`), 3 the legend. (x, y): the pointer in plot units (where 1 and 2).
int fig_dnd_plot_target(int where, int axis, const char *type, int type_len, int *len, double *x, double *y) {
   *len = -1;
   const std::string t(type, static_cast<size_t>(type_len));
   if (const int s = figure_dnd_type_ok(t, "ip_drop_target"); s != FIG_OK) return s;
   bool open = false;
   switch (where) {
   case 1: open = ImPlot::BeginDragDropTargetPlot(); break;
   case 2: open = ImPlot::BeginDragDropTargetAxis(axis); break;
   case 3: open = ImPlot::BeginDragDropTargetLegend(); break;
   default: return fail(FIG_ERR_ARGUMENT, "ip_drop_target: unknown target");
   }
   if (open && figure_dnd_accept(t, len) && where != 3) {
      const ImPlotPoint m = ImPlot::GetPlotMousePos(IMPLOT_AUTO, IMPLOT_AUTO);
      *x = m.x;
      *y = m.y;
   }
   return FIG_OK;
}

} // extern "C"
