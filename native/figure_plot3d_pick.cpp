// FIGURE's picking in a 3-D plot (ip3_mouse_ray): see figure_native.h, "3-D plots".
//
// ImPlot3D turns a pixel into a ray in plot coordinates (PixelsToPlotRay), returned by value as a struct the
// generated layer cannot pass (ImPlot3DRay has no C mirror): FIGURE takes the pointer's ray here and hands the
// Fortran side six doubles. Main thread only, inside a 3-D plot (the Fortran wrapper checks the place).
#include "figure_native.h"

#include "imgui.h"
#include "implot3d.h"

extern "C" {

// The ray under the pointer, in plot coordinates: origin[3], direction[3] (normalized). 1 when the pointer is over
// the plot's rectangle, 0 otherwise (the ray is still the pointer's, or zeros when the pointer is not known).
int fig_plot3d_mouse_ray(double *origin, double *direction) {
   for (int i = 0; i < 3; ++i) origin[i] = direction[i] = 0.0;
   if (!ImGui::IsMousePosValid()) return 0;
   const ImVec2      m = ImGui::GetMousePos();
   const ImPlot3DRay r = ImPlot3D::PixelsToPlotRay(m);
   ImPlot3DPoint     d = r.Direction;
   const double      n = d.Length();
   if (n > 0.0) d = d / n;
   origin[0] = r.Origin.x;
   origin[1] = r.Origin.y;
   origin[2] = r.Origin.z;
   direction[0] = d.x;
   direction[1] = d.y;
   direction[2] = d.z;
   const ImVec2 p = ImPlot3D::GetPlotRectPos(), s = ImPlot3D::GetPlotRectSize();
   return m.x >= p.x && m.y >= p.y && m.x < p.x + s.x && m.y < p.y + s.y ? 1 : 0;
}

} // extern "C"
