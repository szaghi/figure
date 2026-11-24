# The Fortran path's 3-D plot seam (szaghi/figure#15 P13)

The 3-D seam is `figure_implot3d` as a whole: on the Fortran path a 3-D plot's frame and its items draw together, the
items into the frame's depth-sorted list. The current implementation, over ImPlot3D, is
`src/paths/imgui/plot3d/figure_implot3d.F90`; its path-independent checks are `src/lib/figure_plot3d_series.F90`.

The Fortran frame grows here under its own names (`pf3_*`, modules `figure_plot3d_*`), so `$PATH_FORTRAN` keeps the
current `figure_implot3d` until the Fortran one can replace it (every 3-D golden and recording equal on the Fortran
path, after the 2-D switch). Its tests (`src/tests/fortran/figure_test_plot_frame_3d_*.F90`) draw the same plot with
ImPlot3D and with the Fortran frame, in one program, and compare the two pictures (`test_compare_image`,
threshold 2) and, every frame, the box's corners' pixels and the pointer's ray to the bit.

Progress, and what is left, are tracked on [#15](https://github.com/szaghi/figure/issues/15) (P13), not here.

## Modules

- `figure_plot3d_camera`: the rotation (quaternions: `FromElAz`, `FromTwoVectors`, `Slerp`, `q * v`), the maps between
  plot, NDC and pixels and their inverses (rays, `PixelsToPlotPlane`), the box (active faces, the 2-D plane, the
  corners, the axes' edges) and the hover geometry. VecFor's `vector_R8P` carries the per-frame vector algebra; the
  per-point maps are scalar code in ImPlot3D's operation order.
- `figure_plot3d_locators`: ImPlot3D's ticker and locators (default, log10, symlog: ImPlot3D's own rules, not
  ImPlot's).
- `figure_plot3d_drawlist`: `ImDrawList3D`: the triangles with their depths, 32-bit indices (FIGURE's ImPlot3D patch
  0002: no 65535-vertex cap per plot; a list past 16-bit indices moved as runs of sorted triangles, three vertices
  each), the texture runs, and the move sorted (a NaN depth left out, equal depths by index: FIGURE's ImPlot3D patch
  0004, a total order, so not the C library's choice).
- `figure_plot3d_frame`: the plots kept between frames, begin and end, setup, `SetupLock`, the box, rotated text,
  input (`HandleInput`), the legend, the context menus, the mouse text, the queries, the items' hooks, `pf3_text`.
- `figure_plot3d_style`: `ImPlot3DStyle`: its 14 colours (automatic until pushed, `GetAutoColor`: from Dear ImGui's
  colours of now, so FIGURE's themes, which set no ImPlot3D colour, reach the 3-D plots as on the current path) and
  the 11 variables `ip3_push_style_var` names; `pf3_push_style_color`, `pf3_pop_style_color`, `pf3_push_style_var`,
  `pf3_pop_style_var` (stacks of their own: on the current path figure_style's one stack is shared with ImGui's and
  ImPlot's pushes).
- `figure_plot3d_items`: the items (`pf3_line`, `pf3_scatter`, `pf3_triangles`, `pf3_quads`, `pf3_surface`,
  `pf3_mesh`, `pf3_image`), `pf3_spec`; the user's arrays read in place, any stride, `real32` or `real64`.

They draw through `figure_core` only (no ImPlot3D, no `figure_cimplot3d`). libm's `sin`, `cos`, `acos`, `sinf`,
`cosf`, `atan2f`, `acosf`, `log10`, `pow` are called where ImPlot3D calls them; ImPlot3D's float and double mixing is
kept (IM_PI a float, the view scale a float, ...); the nvfortran `-fortran` modes build without FMA (`-Mnofma`), as
ImPlot3D is built (`-ffp-contract=off`).

## Tests

`src/tests/fortran/figure_test_plot_frame_3d_*.F90`, built by the `-fortran` modes: `_canary` (VecFor's products
unfused, libm's `sincos`), `_box` (the box, axes, camera at several rotations and box scales), `_axes` (log10, symlog,
custom ticks, formats, flags), `_lines` (lines, markers, legend, the depth sort), `_surfaces` (triangles, quads,
surfaces, meshes, images, texts), `_input` (rotation, pan, zoom, fit, animation), `_menus` (the context menus),
`_style` (colours and variables pushed, the themes, Dear ImGui's style alpha), `_alloc` (no heap allocation per
frame), `_big` (a 256 x 256 surface, every cell drawn past 65535 vertices, the
frame times reported).

## The ImPlot3D calls the seam replaces

What `figure_implot3d` calls (through `figure_cimplot3d`) and the native C++ that calls ImPlot3D for it:
`ImPlot3D_BeginPlot`, `fig_plot3d_end`, `fig_plot3d_state`, the scope record's ends (`figure_scope.cpp`);
`ImPlot3D_SetupAxes`, `ImPlot3D_SetupAxis`, `ImPlot3D_SetupAxesLimits`, `ImPlot3D_SetupAxisScale_Plot3DScale`,
`fig_plot3d_axis_format`, `ImPlot3D_SetupAxisTicks_doublePtr`, `ImPlot3D_SetupBoxScale`,
`ImPlot3D_SetupBoxRotation_double`, `ImPlot3D_SetupBoxInitialRotation_double`, `ImPlot3D_SetupLegend`;
`ImPlot3D_PlotLine_*`, `ImPlot3D_PlotScatter_*`, `ImPlot3D_PlotTriangle_*`, `ImPlot3D_PlotQuad_*`,
`ImPlot3D_PlotSurface_*`, `ImPlot3D_PlotMesh_*`, `ImPlot3D_PlotImage_Plot3DPoint`, `ImPlot3D_PlotText`,
`ImPlot3D_PushColormap_Plot3DColormap`, `ImPlot3D_PopColormap`, `fig_plot3d_colormap`;
`ImPlot3D_PlotToPixels_double`, `fig_plot3d_mouse_ray` (`figure_plot3d_pick.cpp`); `fig_push_style_color`,
`fig_push_style_var`, `fig_pop_style` for ImPlot3D (`ip3_push_style_*`, `ip3_pop_style_*`, figure_style).
