// FIGURE's glue of ImPlot3D (the ip3_* procedures of src/lib/figure_implot3d.F90): see figure_native.h, "ImPlot3D".
//
// ImPlot3D (brenocq/implot3d, MIT; through cimgui/cimplot3d, MIT) draws its 3-D plots through Dear ImGui's draw lists
// only, so the remote and headless modes show them as every other widget. Its context lives beside ImPlot's (created
// and destroyed with it by figure_native.cpp). FIGURE's colormap registry (figure_colormap.cpp: the bundled maps,
// ImPlot's own, the user's, their variants and the gradient editor's edits) is ImPlot's: a map is copied into
// ImPlot3D's registry, under the same name, when a 3-D item first asks for it, and its keys copied again when they
// changed (an edit by ig_gradient_edit). Main thread only: the Fortran entry points refuse a task first.
#include "figure_native.h"

#include "imgui.h"
#include "implot.h"
#include "implot_internal.h"
#include "implot3d.h"
#include "implot3d_internal.h"

#include <cstring>
#include <string>

namespace {
int fail(int status, const std::string &msg) {
   fig_set_last_error(msg.c_str(), static_cast<int>(msg.size()));
   return status;
}
} // namespace

int fig_plot3d_colormap(int implot_id, int *id) {
   *id = -1;
   if (!ImPlot3D::GetCurrentContext() || !ImPlot::GetCurrentContext())
      return fail(FIG_ERR_STATE, "ip3_surface: figure is not initialized");
   const ImPlotColormapData &src = ImPlot::GetCurrentContext()->ColormapData;
   if (implot_id < 0 || implot_id >= src.Count)
      return fail(FIG_ERR_ARGUMENT, "ip3_surface: the colormap " + std::to_string(implot_id) +
                                        " is not registered (see ip_colormap)");
   ImPlot3DColormapData &dst = ImPlot3D::GetCurrentContext()->ColormapData;
   const char           *name = src.GetName(implot_id);
   const ImU32          *keys = src.GetKeys(implot_id);
   const int             count = src.GetKeyCount(implot_id);
   int                   k = dst.GetIndex(name);
   if (k < 0) {
      k = dst.Append(name, keys, count, src.IsQual(implot_id));
   } else if (dst.GetKeyCount(k) == count &&
              std::memcmp(dst.GetKeys(k), keys, static_cast<size_t>(count) * sizeof(ImU32)) != 0) {
      std::memcpy(&dst.Keys[dst.KeyOffsets[k]], keys, static_cast<size_t>(count) * sizeof(ImU32)); // edited since
      dst.RebuildTables();
   }
   *id = k;
   return FIG_OK;
}

void fig_plot3d_end(void) {
   if (!ImPlot3D::GetCurrentContext() || !ImPlot3D::GImPlot3D->CurrentPlot) return;
   ImPlot3D::EndPlot();
}

int fig_plot3d_state(void) {
   if (!ImPlot3D::GetCurrentContext() || !ImPlot3D::GImPlot3D->CurrentPlot) return 0;
   return ImPlot3D::GImPlot3D->CurrentPlot->SetupLocked ? 2 : 1;
}
