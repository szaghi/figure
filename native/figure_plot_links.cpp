// FIGURE's plots across plots (ip_link_axis, ip_begin_aligned): see figure_native.h, "Plots across plots".
//
// ImPlot links an axis to two doubles the program keeps (SetupAxisLinks): every plot linked to them shows their range,
// and a pan or a zoom in any of them writes it back. FIGURE keeps those doubles here, one pair per group name, so a
// Fortran program names a group instead of keeping variables with a stable address. A linked axis skips ImPlot's
// first fit, so a new group is not linked on its first frame: its first plot fits its data alone, and from the next
// frame the group takes that plot's range and every plot of the group shares it. Main thread only.
#include "figure_native.h"
#include "figure_plot_backend.h"

#include "imgui.h"
#include "implot.h"
#include "implot_internal.h"

#include <map>
#include <string>

namespace {

struct link_t {
   double  min = 0.0, max = 1.0;
   int     state = 0;     // 0 new, 1 waiting for its first plot's fit, 2 linked
   ImGuiID plot = 0;      // its first plot (state 1)
   int     axis = 0;      // ... and axis
   int     frame = -1;    // the frame it was first used in
};

std::map<std::string, link_t> links;

} // namespace

extern "C" {

// Link `axis` (ImAxis) of the plot being set up to the group `name`. 1 linked this frame, 0 not yet (a new group).
int fig_plot_link(int axis, const char *name, int name_len) {
   link_t    &g = links[std::string(name, static_cast<size_t>(name_len))];
   ImPlotPlot &p = *GImPlot->CurrentPlot;
   const int  frame = ImGui::GetFrameCount();
   if (g.state == 0) {
      g.state = 1;
      g.plot = p.ID;
      g.axis = axis;
      g.frame = frame;
      return 0;
   }
   if (g.state == 1) {
      if (frame == g.frame) return 0; // another plot of the group in its first frame: it fits alone too
      const ImPlotPlot *first = GImPlot->Plots.GetByKey(g.plot);
      const ImPlotRange r = first ? first->Axes[g.axis].Range : p.Axes[axis].Range;
      g.min = r.Min;
      g.max = r.Max;
      g.state = 2;
   }
   ImPlot::SetupAxisLinks(axis, &g.min, &g.max);
   return 1;
}

// Forget every group (fig_init: a new context, new plots).
void fig_plot_links_reset(void) { links.clear(); }

// 1 when an aligned group is open (ImPlot allows one at a time).
int fig_aligned_open(void) {
   return ImPlot::GetCurrentContext() && (GImPlot->CurrentAlignmentH || GImPlot->CurrentAlignmentV) ? 1 : 0;
}

} // extern "C"

namespace {
// ImPlot's (ImPlot3D's) contexts: the plot side linked with this file (szaghi/figure#15 G2).
const int anchored = (fig_implot_glue_anchor(), 0);
} // namespace
