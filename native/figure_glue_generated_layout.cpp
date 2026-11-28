// FIGURE generated glue (scripts/gen_bindings.py: do not edit).
//
// C wrappers of the cimgui/cimplot/cimplot3d functions that pass structs by value, which Fortran cannot call directly:
// `figure_<name>` takes each such struct by pointer and returns a struct result through `res`. Every wrapper
// is noexcept: Dear ImGui and ImPlot do not throw, and an exception must not unwind through Fortran frames,
// so one would terminate the program. Also: the size of each struct Fortran mirrors (checked by
// src/tests/figure_test_layout.F90) and the C++ defaults of ImPlotSpec. Three files, one per part a program may
// link alone: figure_glue_generated.cpp (Dear ImGui), figure_glue_generated_plot.cpp (ImPlot, ImPlot3D),
// figure_glue_generated_layout.cpp (the plot mirrors' sizes and the spec defaults: no ImPlot function).
// Same includes, in the same order, as cimplot.cpp: cimgui.h's internal section needs the internal headers.
#include "implot.h"
#include "implot_internal.h"
#include "cimplot.h"
// ... and as cimplot3d.cpp
#include "implot3d.h"
#include "implot3d_internal.h"
#include "cimplot3d.h"

#include <cstddef>
#include <cstring>

extern "C" {


size_t figure_sizeof_ImPlotPoint_c(void) noexcept { return sizeof(ImPlotPoint_c); }
size_t figure_sizeof_ImPlotRange_c(void) noexcept { return sizeof(ImPlotRange_c); }
size_t figure_sizeof_ImPlotRect_c(void) noexcept { return sizeof(ImPlotRect_c); }
size_t figure_sizeof_ImPlotSpec_c(void) noexcept { return sizeof(ImPlotSpec_c); }
size_t figure_sizeof_ImPlot3DPoint_c(void) noexcept { return sizeof(ImPlot3DPoint_c); }
size_t figure_sizeof_ImPlot3DQuat_c(void) noexcept { return sizeof(ImPlot3DQuat_c); }
size_t figure_sizeof_ImPlot3DSpec_c(void) noexcept { return sizeof(ImPlot3DSpec_c); }

// ImPlotSpec's defaults from its C++ constructor (IMPLOT_AUTO, IMPLOT_AUTO_COL, ...), never copied by hand: the
// C++ and C layouts are checked equal field by field, then the bytes are copied.
static_assert(sizeof(ImPlotSpec) == sizeof(ImPlotSpec_c), "ImPlotSpec and ImPlotSpec_c differ in size");
static_assert(offsetof(ImPlotSpec, LineColor) == offsetof(ImPlotSpec_c, LineColor), "ImPlotSpec.LineColor misplaced");
static_assert(offsetof(ImPlotSpec, LineColors) == offsetof(ImPlotSpec_c, LineColors), "ImPlotSpec.LineColors misplaced");
static_assert(offsetof(ImPlotSpec, LineWeight) == offsetof(ImPlotSpec_c, LineWeight), "ImPlotSpec.LineWeight misplaced");
static_assert(offsetof(ImPlotSpec, FillColor) == offsetof(ImPlotSpec_c, FillColor), "ImPlotSpec.FillColor misplaced");
static_assert(offsetof(ImPlotSpec, FillColors) == offsetof(ImPlotSpec_c, FillColors), "ImPlotSpec.FillColors misplaced");
static_assert(offsetof(ImPlotSpec, FillAlpha) == offsetof(ImPlotSpec_c, FillAlpha), "ImPlotSpec.FillAlpha misplaced");
static_assert(offsetof(ImPlotSpec, Marker) == offsetof(ImPlotSpec_c, Marker), "ImPlotSpec.Marker misplaced");
static_assert(offsetof(ImPlotSpec, MarkerSize) == offsetof(ImPlotSpec_c, MarkerSize), "ImPlotSpec.MarkerSize misplaced");
static_assert(offsetof(ImPlotSpec, MarkerSizes) == offsetof(ImPlotSpec_c, MarkerSizes), "ImPlotSpec.MarkerSizes misplaced");
static_assert(offsetof(ImPlotSpec, MarkerLineColor) == offsetof(ImPlotSpec_c, MarkerLineColor), "ImPlotSpec.MarkerLineColor misplaced");
static_assert(offsetof(ImPlotSpec, MarkerLineColors) == offsetof(ImPlotSpec_c, MarkerLineColors), "ImPlotSpec.MarkerLineColors misplaced");
static_assert(offsetof(ImPlotSpec, MarkerFillColor) == offsetof(ImPlotSpec_c, MarkerFillColor), "ImPlotSpec.MarkerFillColor misplaced");
static_assert(offsetof(ImPlotSpec, MarkerFillColors) == offsetof(ImPlotSpec_c, MarkerFillColors), "ImPlotSpec.MarkerFillColors misplaced");
static_assert(offsetof(ImPlotSpec, Size) == offsetof(ImPlotSpec_c, Size), "ImPlotSpec.Size misplaced");
static_assert(offsetof(ImPlotSpec, Offset) == offsetof(ImPlotSpec_c, Offset), "ImPlotSpec.Offset misplaced");
static_assert(offsetof(ImPlotSpec, Stride) == offsetof(ImPlotSpec_c, Stride), "ImPlotSpec.Stride misplaced");
static_assert(offsetof(ImPlotSpec, Flags) == offsetof(ImPlotSpec_c, Flags), "ImPlotSpec.Flags misplaced");
void figure_ImPlotSpec_default(ImPlotSpec_c* res) noexcept {
   const ImPlotSpec spec;
   std::memcpy(res, &spec, sizeof(spec));
}

// ImPlot3DSpec's defaults from its C++ constructor (IMPLOT3D_AUTO, IMPLOT3D_AUTO_COL, ...), never copied by hand: the
// C++ and C layouts are checked equal field by field, then the bytes are copied.
static_assert(sizeof(ImPlot3DSpec) == sizeof(ImPlot3DSpec_c), "ImPlot3DSpec and ImPlot3DSpec_c differ in size");
static_assert(offsetof(ImPlot3DSpec, LineColor) == offsetof(ImPlot3DSpec_c, LineColor), "ImPlot3DSpec.LineColor misplaced");
static_assert(offsetof(ImPlot3DSpec, LineColors) == offsetof(ImPlot3DSpec_c, LineColors), "ImPlot3DSpec.LineColors misplaced");
static_assert(offsetof(ImPlot3DSpec, LineWeight) == offsetof(ImPlot3DSpec_c, LineWeight), "ImPlot3DSpec.LineWeight misplaced");
static_assert(offsetof(ImPlot3DSpec, FillColor) == offsetof(ImPlot3DSpec_c, FillColor), "ImPlot3DSpec.FillColor misplaced");
static_assert(offsetof(ImPlot3DSpec, FillColors) == offsetof(ImPlot3DSpec_c, FillColors), "ImPlot3DSpec.FillColors misplaced");
static_assert(offsetof(ImPlot3DSpec, FillAlpha) == offsetof(ImPlot3DSpec_c, FillAlpha), "ImPlot3DSpec.FillAlpha misplaced");
static_assert(offsetof(ImPlot3DSpec, Marker) == offsetof(ImPlot3DSpec_c, Marker), "ImPlot3DSpec.Marker misplaced");
static_assert(offsetof(ImPlot3DSpec, MarkerSize) == offsetof(ImPlot3DSpec_c, MarkerSize), "ImPlot3DSpec.MarkerSize misplaced");
static_assert(offsetof(ImPlot3DSpec, MarkerSizes) == offsetof(ImPlot3DSpec_c, MarkerSizes), "ImPlot3DSpec.MarkerSizes misplaced");
static_assert(offsetof(ImPlot3DSpec, MarkerLineColor) == offsetof(ImPlot3DSpec_c, MarkerLineColor), "ImPlot3DSpec.MarkerLineColor misplaced");
static_assert(offsetof(ImPlot3DSpec, MarkerLineColors) == offsetof(ImPlot3DSpec_c, MarkerLineColors), "ImPlot3DSpec.MarkerLineColors misplaced");
static_assert(offsetof(ImPlot3DSpec, MarkerFillColor) == offsetof(ImPlot3DSpec_c, MarkerFillColor), "ImPlot3DSpec.MarkerFillColor misplaced");
static_assert(offsetof(ImPlot3DSpec, MarkerFillColors) == offsetof(ImPlot3DSpec_c, MarkerFillColors), "ImPlot3DSpec.MarkerFillColors misplaced");
static_assert(offsetof(ImPlot3DSpec, Offset) == offsetof(ImPlot3DSpec_c, Offset), "ImPlot3DSpec.Offset misplaced");
static_assert(offsetof(ImPlot3DSpec, Stride) == offsetof(ImPlot3DSpec_c, Stride), "ImPlot3DSpec.Stride misplaced");
static_assert(offsetof(ImPlot3DSpec, Flags) == offsetof(ImPlot3DSpec_c, Flags), "ImPlot3DSpec.Flags misplaced");
void figure_ImPlot3DSpec_default(ImPlot3DSpec_c* res) noexcept {
   const ImPlot3DSpec spec;
   std::memcpy(res, &spec, sizeof(spec));
}

} // extern "C"
