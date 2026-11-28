!< figure_plot_items, the plot frame's items: lines, markers, stairs, stems, shaded areas, bars, as ImPlot draws.
module figure_plot_items
!< figure_plot_items, the plot frame's items: lines, markers, stairs, stems, shaded areas, bars, as ImPlot draws.
!<
!< szaghi/figure#15 P11, group (a). The items of FIGURE's plot API drawn into the Fortran plot frame
!< (figure_plot_frame): `pf_line`, `pf_scatter`, `pf_stairs`, `pf_stems`, `pf_shaded`, with an item's style
!< (`pf_spec`, the fields of `ip_spec`), reproduced from implot_items.cpp (ImPlot 1.2 WIP, FIGURE's copy):
!<
!< - `BeginItem`'s staging of the style: the line colour the item's (given, or the colormap's when automatic), the
!<   fill colour the line's unless given, times `FillAlpha`; the markers' outline and fill colours the line's unless
!<   given (the fill times `FillAlpha`); a hovered legend entry doubles the line weight and makes the markers 1.25
!<   times larger; what is drawn (a line: its colour not transparent and its weight > 0; ...). `ImPlotMarker_Auto`
!<   takes the plot's next marker (`NextMarker`) when the item is created; a scatter without a marker gets one;
!< - the getters (`GetterXY` of `IndexerIdx`, `IndexerLin`, `IndexerConst`; `GetterLoop`; `GetterOverrideY`): an
!<   item's arrays read in place at any stride (assumed-shape dummies: no copy), `real32` or `real64` values taken as
!<   double; integer abscissae as FIGURE's API converts them (to the ordinates' kind, then double); uniform abscissae
!<   `x0 + i dx` (i from 0); a constant (a reference line);
!< - the fitters (`Fitter1`, `Fitter2`) through the frame (`pf_item_fit`: `ExtendFitWith`), unless
!<   `ImPlotItemFlags_NoFit`;
!< - the renderers and their primitives, vertex for vertex: `RendererLineStrip` (and `...Skip` for `SkipNaN`, the
!<   loop's getter for `Loop`), `RendererLineSegments1` (`Segments`), `RendererShaded` (the `Shaded` flag, against
!<   y = 0; `PlotShaded`: between two series, or a series and a reference), `RendererStairsPre`/`Post` and their
!<   shaded forms, `RendererLineSegments2` (stems), `RendererMarkersFill`/`Line` and the marker shapes of
!<   `MARKER_FILL_*`/`MARKER_LINE_*`; each primitive culled as `RenderPrimitivesEx` culls it (the plot rectangle);
!<   lines with the anti-aliased line texture (`GetLineRenderProps`), fills with the white pixel. The primitives
!<   (szaghi/figure#16 S2) are written as `RenderPrimitivesEx` writes them: runs reserved in the target draw list's own
!<   buffers (`core_run_reserve`, sized by `core_run_vtx_current` as by `_VtxCurrentIdx`; szaghi/figure#16 D2: no
!<   second copy), each primitive's vertices and 16-bit indices written in place (`PrimLine`, `PrimRectFill`,
!<   `PrimRectLine`, the shaded quad of five vertices, the fans of `RendererMarkersFill`, `RendererCircleFill` and
!<   `PrimPieSliceFill`), the culled ones' room given back (`core_run_unreserve`), a `prim_run` holding the run's
!<   state; a pie slice reserves its fan and its border once
!<   each, as `RenderPieSlice`; error bars and digital signals are `AddLine` and `AddRectFilled`, as ImPlot's;
!< - the per-point getter and transform (szaghi/figure#16 S3): the line strips', segments' and markers' renderers map
!<   their points to pixels a block at a time (`pixel_block`): per block and coordinate, the getter's source and the
!<   axis's scale are chosen once, then one loop does `coordinate`'s and `map_pixel`'s arithmetic, in their order and
!<   precision, with the axis's constants hoisted (a log10 or symlog axis calls `map_pixel` per point);
!< - the clip: the plot rectangle (`PushPlotClipRect`), expanded by the marker size for the markers of stairs and
!<   stems, and of lines and scatters with `NoClip`;
!< - the decimation of long line-like series (figure_decimate, as figure_implot's `series_decimate`: M4 per pixel
!<   column above DECIMATE_THRESHOLD points a column; not with markers, `Segments`, `Loop`): the kept points read
!<   through their indices, in place (`pf_set_decimation` turns it off, as `ip_set_decimation`).
!<
!< Group (b): `pf_bars` (`PlotBarsVEx`/`HEx`: `FitterBarV`/`H`, `RendererBarsFill`/`Line`, a bar at least a pixel
!< wide, no outline when it has the fill's colour; `PrimRectLine`'s eight triangles as four quads), `pf_bar_groups`
!< (`PlotBarGroups`: side by side, or stacked with the negative values below, a hidden item's values skipped; the
!< colormap pushed for the call), `pf_error_bars` (`PlotErrorBarsVEx`/`HEx`: Dear ImGui's `AddLine` and
!< `AddLineH`/`V` whiskers, the style's text colour unless a line colour is given, not culled), `pf_inf_lines`
!< (`PlotInfLines`: segments across the current range, `FitterX`/`FitterY`).
!<
!< Group (c): `pf_pie_chart` (`PlotPieChart`: the slices' fans and borders, two halves for half a turn or more, the
!< labels through a printf format, `Normalize`, `IgnoreHidden`, `Exploding`, `NoSliceBorder`, a colormap pushed;
!< libm's `cos`/`sin` bound from C, IM_PI a float as ImPlot's), `pf_bubbles` (`PlotBubbles`: circles of 10 to 64
!< segments, `cosf`/`sinf`), `pf_digital` (`PlotDigital`, FIGURE's patched copy: the bands stacked, no fit),
!< `pf_text` (`PlotText`: centred, vertical, offset, fitted; not an item).
!<
!< Group (d): `pf_heatmap` (`PlotHeatmap` as `ip_heatmap` calls it: rows along y from ymin, the scale from the data
!< when not given, a constant scale one rectangle, `RendererRectC` cells, labels through a printf format),
!< `pf_histogram` and `pf_histogram2d` (`ip_histogram`/`ip_histogram2d`: the finite values, FIGURE's range and bin
!< rules, then `PlotHistogram` (cumulative, density, outliers; the bars' path) and `PlotHistogram2D` (a heatmap of the
!< counts)); `pf_image` (`PlotImage` as `ip_image` calls it: uv (0, 1)-(1, 0), white, the texture's own filter between
!< figure_core's `core_texture_sampling` callbacks) and `pf_field_image` (`ip_field_image`: figure_plot_field colours
!< the field into a cached texture, bit for bit with native/figure_field.cpp; then the image).
!<
!< Not items: P12's drag tools (figure_plot_tools), tags and annotations (figure_plot_frame's `pf_tag`,
!< `pf_annotation`: `ip_annotation`, FIGURE's `fig_plot_annotation` over ImPlot's `Annotation`).
!<
!< No allocation per item per frame (ADR 0001): views of the arrays, fixed quads; the decimation's index buffer and
!< the integer abscissae's conversion (decimated items only) are grown once and kept.
!<
!< The items' array dummies are ASYNCHRONOUS, as figure_implot's (the Fortran path's calls them with its own): nvfortran
!< otherwise copies an asynchronous actual at the call, and the address a view (and a series' cache) keeps is that of a
!< temporary.
use, intrinsic :: iso_c_binding, only : c_double, c_float, c_int16_t, c_intptr_t, c_loc
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use figure_cimgui_enums, only : ImGuiCol_Text
use figure_core, only : core_run_reserve, core_run_unreserve, core_run_vtx_current
use figure_drawlist, only : draw_vert, DL_BATCH_VERTICES
use figure_core, only : core_draw_image, core_draw_line, core_draw_line_h, core_draw_line_v,                        &
                        core_draw_rect_filled, core_draw_text, core_frame_count, core_framebuffer_scale, core_time, &
                        core_line_texture, core_pop_clip_rect, core_push_clip_rect, core_style_color,             &
                        core_style_var, core_text_size, core_texture_sampling, core_white_pixel
use figure_decimate, only : decimate, decimate_axis, decimate_cache, DECIMATE_LINEAR, DECIMATE_LOG10, DECIMATE_SYMLOG, &
                            DECIMATE_THRESHOLD
use figure_decimate_device, only : decimate_device_r32, decimate_device_r64
use fundal, only : dev_memcpy_from_device
use figure_plot_colormaps, only : cm_current, cm_key, cm_lookup, cm_pop, cm_push, cm_sample, CM_VIRIDIS
use figure_plot_field, only : field_colour, field_count, field_sweep, field_uploads, FIELD_LINEAR, FIELD_LOG, &
                              FIELD_SYMLOG
use figure_plot_format, only : plot_format, fmt_parse, fmt_real
use figure_texture, only : texture_object, texture_ref
use figure_plot_style, only : DIGITAL_PADDING, DIGITAL_SPACING, ps_u32, PC_INLAY_TEXT
use figure_plot_frame, only : plot_item_ctx, pf_digital_offset, pf_item_begin, pf_item_count, pf_item_end,      &
                              pf_item_fit, pf_item_fit_axis, pf_item_fit_with, pf_item_hidden, pf_item_shown_at, &
                              pf_item_id, pf_item_recolor, pf_item_state, pf_legend_hovered, pf_pixels_to_plot,    &
                              pf_plot_ctx, pf_text_vertical
use figure_plot_transform, only : map_pixel, plot_axis_map, MAP_LINEAR, MAP_LOG10, MAP_SYMLOG, MAP_TIME

implicit none
private
public :: plot_item_spec, pf_spec
public :: pf_line, pf_scatter, pf_stairs, pf_stems, pf_shaded, pf_set_decimation
public :: pf_cache_next_item, pf_cache_counts, pf_line_device
public :: plot_decimated, plot_kept, plot_cache_builds, plot_cache_hits, pf_last_decimated
public :: pf_bars, pf_bar_groups, pf_error_bars, pf_inf_lines
public :: PF_BARS_HORIZONTAL, PF_ERROR_BARS_HORIZONTAL, PF_INF_LINES_HORIZONTAL
public :: pf_pie_chart, pf_bubbles, pf_digital, pf_text
public :: PF_PIE_NORMALIZE, PF_PIE_IGNORE_HIDDEN, PF_PIE_EXPLODING, PF_PIE_NO_SLICE_BORDER, PF_TEXT_VERT
public :: pf_heatmap, pf_histogram, pf_histogram2d, pf_image, pf_field_image, pf_field_count, pf_field_uploads
public :: PF_HEATMAP_COL_MAJOR, PF_HIST_HORIZONTAL, PF_HIST_CUMULATIVE, PF_HIST_DENSITY, PF_HIST_NO_OUTLIERS
public :: PF_HIST_COL_MAJOR
public :: PF_BIN_SQRT, PF_BIN_STURGES, PF_BIN_RICE, PF_BIN_SCOTT
! ImPlotMarker (implot.h): the same values as FIGURE's ImPlotMarker_*
public :: PF_MARKER_NONE, PF_MARKER_AUTO, PF_MARKER_CIRCLE, PF_MARKER_SQUARE, PF_MARKER_DIAMOND, PF_MARKER_UP
public :: PF_MARKER_DOWN, PF_MARKER_LEFT, PF_MARKER_RIGHT, PF_MARKER_CROSS, PF_MARKER_PLUS, PF_MARKER_ASTERISK
public :: PF_MARKER_VERTICAL, PF_MARKER_HORIZONTAL
! ImPlotItemFlags and the items' own (implot.h): the same values as FIGURE's ImPlot*Flags_*
public :: PF_ITEM_NO_LEGEND, PF_ITEM_NO_FIT, PF_LINE_SEGMENTS, PF_LINE_LOOP, PF_LINE_SKIP_NAN, PF_LINE_NO_CLIP
public :: PF_LINE_SHADED, PF_SCATTER_NO_CLIP, PF_STAIRS_PRE_STEP, PF_STAIRS_SHADED, PF_STEMS_HORIZONTAL

integer(int32), parameter :: PF_MARKER_INVALID = -3_int32   !< ImPlotMarker_Invalid (BeginItem leaves the marker).
integer(int32), parameter :: PF_MARKER_NONE = -2_int32      !< ImPlotMarker_None.
integer(int32), parameter :: PF_MARKER_AUTO = -1_int32      !< ImPlotMarker_Auto.
integer(int32), parameter :: PF_MARKER_CIRCLE = 0_int32     !< ImPlotMarker_Circle.
integer(int32), parameter :: PF_MARKER_SQUARE = 1_int32     !< ImPlotMarker_Square.
integer(int32), parameter :: PF_MARKER_DIAMOND = 2_int32    !< ImPlotMarker_Diamond.
integer(int32), parameter :: PF_MARKER_UP = 3_int32         !< ImPlotMarker_Up.
integer(int32), parameter :: PF_MARKER_DOWN = 4_int32       !< ImPlotMarker_Down.
integer(int32), parameter :: PF_MARKER_LEFT = 5_int32       !< ImPlotMarker_Left.
integer(int32), parameter :: PF_MARKER_RIGHT = 6_int32      !< ImPlotMarker_Right.
integer(int32), parameter :: PF_MARKER_CROSS = 7_int32      !< ImPlotMarker_Cross.
integer(int32), parameter :: PF_MARKER_PLUS = 8_int32       !< ImPlotMarker_Plus.
integer(int32), parameter :: PF_MARKER_ASTERISK = 9_int32   !< ImPlotMarker_Asterisk.
integer(int32), parameter :: PF_MARKER_VERTICAL = 10_int32  !< ImPlotMarker_Vertical.
integer(int32), parameter :: PF_MARKER_HORIZONTAL = 11_int32 !< ImPlotMarker_Horizontal.
integer(int32), parameter :: PF_ITEM_NO_LEGEND = 1_int32    !< ImPlotItemFlags_NoLegend.
integer(int32), parameter :: PF_ITEM_NO_FIT = 2_int32       !< ImPlotItemFlags_NoFit.
integer(int32), parameter :: PF_LINE_SEGMENTS = 1024_int32  !< ImPlotLineFlags_Segments.
integer(int32), parameter :: PF_LINE_LOOP = 2048_int32      !< ImPlotLineFlags_Loop.
integer(int32), parameter :: PF_LINE_SKIP_NAN = 4096_int32  !< ImPlotLineFlags_SkipNaN.
integer(int32), parameter :: PF_LINE_NO_CLIP = 8192_int32   !< ImPlotLineFlags_NoClip.
integer(int32), parameter :: PF_LINE_SHADED = 16384_int32   !< ImPlotLineFlags_Shaded.
integer(int32), parameter :: PF_SCATTER_NO_CLIP = 1024_int32 !< ImPlotScatterFlags_NoClip.
integer(int32), parameter :: PF_STAIRS_PRE_STEP = 1024_int32 !< ImPlotStairsFlags_PreStep.
integer(int32), parameter :: PF_STAIRS_SHADED = 2048_int32  !< ImPlotStairsFlags_Shaded.
integer(int32), parameter :: PF_STEMS_HORIZONTAL = 1024_int32 !< ImPlotStemsFlags_Horizontal.
integer(int32), parameter :: PF_BARS_HORIZONTAL = 1024_int32       !< ImPlotBarsFlags_Horizontal.
integer(int32), parameter :: PF_ERROR_BARS_HORIZONTAL = 1024_int32 !< ImPlotErrorBarsFlags_Horizontal.
integer(int32), parameter :: PF_INF_LINES_HORIZONTAL = 1024_int32  !< ImPlotInfLinesFlags_Horizontal.
integer(int32), parameter :: PF_PIE_NORMALIZE = 1024_int32       !< ImPlotPieChartFlags_Normalize.
integer(int32), parameter :: PF_PIE_IGNORE_HIDDEN = 2048_int32   !< ImPlotPieChartFlags_IgnoreHidden.
integer(int32), parameter :: PF_PIE_EXPLODING = 4096_int32       !< ImPlotPieChartFlags_Exploding.
integer(int32), parameter :: PF_PIE_NO_SLICE_BORDER = 8192_int32 !< ImPlotPieChartFlags_NoSliceBorder.
integer(int32), parameter :: PF_TEXT_VERT = 1024_int32           !< ImPlotTextFlags_Vertical (`pf_text(vertical=)`).
real(real32),   parameter :: IM_PI = 3.14159265358979323846_real32 !< IM_PI (a float).
integer(int32), parameter :: PF_HEATMAP_COL_MAJOR = 1024_int32 !< ImPlotHeatmapFlags_ColMajor.
integer(int32), parameter :: PF_HIST_HORIZONTAL = 1024_int32  !< ImPlotHistogramFlags_Horizontal.
integer(int32), parameter :: PF_HIST_CUMULATIVE = 2048_int32  !< ImPlotHistogramFlags_Cumulative.
integer(int32), parameter :: PF_HIST_DENSITY = 4096_int32     !< ImPlotHistogramFlags_Density.
integer(int32), parameter :: PF_HIST_NO_OUTLIERS = 8192_int32 !< ImPlotHistogramFlags_NoOutliers.
integer(int32), parameter :: PF_HIST_COL_MAJOR = 16384_int32  !< ImPlotHistogramFlags_ColMajor (heatmaps' ColMajor).
integer(int32), parameter :: PF_BIN_SQRT = -1_int32           !< ImPlotBin_Sqrt.
integer(int32), parameter :: PF_BIN_STURGES = -2_int32        !< ImPlotBin_Sturges.
integer(int32), parameter :: PF_BIN_RICE = -3_int32           !< ImPlotBin_Rice.
integer(int32), parameter :: PF_BIN_SCOTT = -4_int32          !< ImPlotBin_Scott.
real(real32),   parameter :: AUTO_ALPHA = -1.0_real32       !< IMPLOT_AUTO_COL's alpha: an automatic colour.
real(real32),   parameter :: HIGHLIGHT_LINE_SCALE = 2.0_real32 !< ITEM_HIGHLIGHT_LINE_SCALE.
real(real32),   parameter :: HIGHLIGHT_MARK_SCALE = 1.25_real32 !< ITEM_HIGHLIGHT_MARK_SCALE.
real(real32),   parameter :: SQRT_1_2 = 0.70710678118_real32 !< SQRT_1_2 (implot_items.cpp).
integer(int64), parameter :: BYTE_UNIT(4) = [1_int64, 256_int64, 65536_int64, 16777216_int64] !< A packed colour's
                                                                                              !< bytes' units (RGBA).
real(real32),   parameter :: SQRT_3_2 = 0.86602540378_real32 !< SQRT_3_2.
! the items' kinds (what decides the decimation and its fill)
integer(int32), parameter :: KIND_LINE = 1_int32, KIND_STAIRS = 2_int32, KIND_SHADED = 3_int32 !< Item kinds.
! a getter's coordinate source
integer(int32), parameter :: SRC_NONE = 0_int32  !< None.
integer(int32), parameter :: SRC_R32 = 1_int32   !< A real32 array.
integer(int32), parameter :: SRC_R64 = 2_int32   !< A real64 array.
integer(int32), parameter :: SRC_I32 = 3_int32   !< An int32 array.
integer(int32), parameter :: SRC_I64 = 4_int32   !< An int64 array.
integer(int32), parameter :: SRC_LIN = 5_int32   !< x0 + i dx (IndexerLin, i from 0).
integer(int32), parameter :: SRC_CONST = 6_int32 !< A constant (IndexerConst).
integer(int32), parameter :: PIX_BLOCK = 512_int32 !< Points a renderer maps to pixels at once (`pixel_block`).
integer(int32), parameter :: IDX16_SIGN = 32768_int32 !< A run's index, vertex v (0 to 65535), is stored in its 16-bit
                                                      !< `ImDrawIdx` as `v - ishft(iand(v, IDX16_SIGN), 1)`: v or
                                                      !< v - 65536, the same 16 bits in `c_int16_t`'s range (an
                                                      !< explicit `int(v, c_int16_t)` would be out of range, and
                                                      !< nvfortran calls `pgf90_int2` for it); a plain 16-bit store
                                                      !< on the three compilers.
integer(int32), parameter :: MARKER_SEGMENTS = 10_int32 !< Segments of the largest outline marker (the circle's).
! the markers' shapes (MARKER_FILL_*, MARKER_LINE_*): x, y pairs
real(real32), parameter :: FILL_CIRCLE(2, 10) = reshape([1.0_real32, 0.0_real32, 0.809017_real32, 0.58778524_real32, &
                           0.30901697_real32, 0.95105654_real32, -0.30901703_real32, 0.9510565_real32,             &
                           -0.80901706_real32, 0.5877852_real32, -1.0_real32, 0.0_real32,                          &
                           -0.80901694_real32, -0.58778536_real32, -0.3090171_real32, -0.9510565_real32,           &
                           0.30901712_real32, -0.9510565_real32, 0.80901694_real32, -0.5877853_real32], [2, 10]) !<
                           !< Circle.
real(real32), parameter :: FILL_SQUARE(2, 4) = reshape([SQRT_1_2, SQRT_1_2, SQRT_1_2, -SQRT_1_2, -SQRT_1_2, &
                                                       -SQRT_1_2, -SQRT_1_2, SQRT_1_2], [2, 4]) !< Square.
real(real32), parameter :: FILL_DIAMOND(2, 4) = reshape([1.0_real32, 0.0_real32, 0.0_real32, -1.0_real32, &
                                                        -1.0_real32, 0.0_real32, 0.0_real32, 1.0_real32], [2, 4]) !<
                                                        !< Diamond.
real(real32), parameter :: FILL_UP(2, 3) = reshape([SQRT_3_2, 0.5_real32, 0.0_real32, -1.0_real32, -SQRT_3_2, &
                                                   0.5_real32], [2, 3]) !< Up.
real(real32), parameter :: FILL_DOWN(2, 3) = reshape([SQRT_3_2, -0.5_real32, 0.0_real32, 1.0_real32, -SQRT_3_2, &
                                                     -0.5_real32], [2, 3]) !< Down.
real(real32), parameter :: FILL_LEFT(2, 3) = reshape([-1.0_real32, 0.0_real32, 0.5_real32, SQRT_3_2, 0.5_real32, &
                                                     -SQRT_3_2], [2, 3]) !< Left.
real(real32), parameter :: FILL_RIGHT(2, 3) = reshape([1.0_real32, 0.0_real32, -0.5_real32, SQRT_3_2, -0.5_real32, &
                                                      -SQRT_3_2], [2, 3]) !< Right.
real(real32), parameter :: LINE_SQUARE(2, 8) = reshape([SQRT_1_2, SQRT_1_2, SQRT_1_2, -SQRT_1_2, SQRT_1_2, -SQRT_1_2, &
                                                       -SQRT_1_2, -SQRT_1_2, -SQRT_1_2, -SQRT_1_2, -SQRT_1_2,       &
                                                       SQRT_1_2, -SQRT_1_2, SQRT_1_2, SQRT_1_2, SQRT_1_2], [2, 8]) !<
                                                       !< Square's outline.
real(real32), parameter :: LINE_DIAMOND(2, 8) = reshape([1.0_real32, 0.0_real32, 0.0_real32, -1.0_real32,      &
                                                        0.0_real32, -1.0_real32, -1.0_real32, 0.0_real32,     &
                                                        -1.0_real32, 0.0_real32, 0.0_real32, 1.0_real32,      &
                                                        0.0_real32, 1.0_real32, 1.0_real32, 0.0_real32], [2, 8]) !<
                                                        !< Diamond's outline.
real(real32), parameter :: LINE_UP(2, 6) = reshape([SQRT_3_2, 0.5_real32, 0.0_real32, -1.0_real32, 0.0_real32,   &
                                                   -1.0_real32, -SQRT_3_2, 0.5_real32, -SQRT_3_2, 0.5_real32, &
                                                   SQRT_3_2, 0.5_real32], [2, 6]) !< Up's outline.
real(real32), parameter :: LINE_DOWN(2, 6) = reshape([SQRT_3_2, -0.5_real32, 0.0_real32, 1.0_real32, 0.0_real32,   &
                                                     1.0_real32, -SQRT_3_2, -0.5_real32, -SQRT_3_2, -0.5_real32, &
                                                     SQRT_3_2, -0.5_real32], [2, 6]) !< Down's outline.
real(real32), parameter :: LINE_LEFT(2, 6) = reshape([-1.0_real32, 0.0_real32, 0.5_real32, SQRT_3_2, 0.5_real32,   &
                                                     SQRT_3_2, 0.5_real32, -SQRT_3_2, 0.5_real32, -SQRT_3_2,     &
                                                     -1.0_real32, 0.0_real32], [2, 6]) !< Left's outline.
real(real32), parameter :: LINE_RIGHT(2, 6) = reshape([1.0_real32, 0.0_real32, -0.5_real32, SQRT_3_2, -0.5_real32, &
                                                      SQRT_3_2, -0.5_real32, -SQRT_3_2, -0.5_real32, -SQRT_3_2,   &
                                                      1.0_real32, 0.0_real32], [2, 6]) !< Right's outline.
real(real32), parameter :: LINE_ASTERISK(2, 6) = reshape([-SQRT_3_2, -0.5_real32, SQRT_3_2, 0.5_real32, -SQRT_3_2, &
                                                         0.5_real32, SQRT_3_2, -0.5_real32, 0.0_real32,          &
                                                         -1.0_real32, 0.0_real32, 1.0_real32], [2, 6]) !< Asterisk.
real(real32), parameter :: LINE_PLUS(2, 4) = reshape([-1.0_real32, 0.0_real32, 1.0_real32, 0.0_real32, 0.0_real32, &
                                                     -1.0_real32, 0.0_real32, 1.0_real32], [2, 4]) !< Plus.
real(real32), parameter :: LINE_CROSS(2, 4) = reshape([-SQRT_1_2, -SQRT_1_2, SQRT_1_2, SQRT_1_2, SQRT_1_2, &
                                                      -SQRT_1_2, -SQRT_1_2, SQRT_1_2], [2, 4]) !< Cross.
real(real32), parameter :: LINE_VERTICAL(2, 2) = reshape([0.0_real32, -1.0_real32, 0.0_real32, 1.0_real32], [2, 2]) !<
                                                         !< Vertical.
real(real32), parameter :: LINE_HORIZONTAL(2, 2) = reshape([-1.0_real32, 0.0_real32, 1.0_real32, 0.0_real32], [2, 2]) !<
                                                           !< Horizontal.

type :: plot_item_spec
   !< An item's style (`ImPlotSpec`, the fields FIGURE's `ip_spec` sets): ImPlot's defaults; colours RGBA as floats, an
   !< automatic one with alpha -1 (`IMPLOT_AUTO_COL`). Build it with `pf_spec`.
   real(real32)   :: line_color(4) = [0.0_real32, 0.0_real32, 0.0_real32, AUTO_ALPHA]        !< LineColor.
   real(real32)   :: line_weight = 1.0_real32                                                 !< LineWeight [pixels].
   real(real32)   :: fill_color(4) = [0.0_real32, 0.0_real32, 0.0_real32, AUTO_ALPHA]        !< FillColor.
   real(real32)   :: fill_alpha = 1.0_real32                                                  !< FillAlpha.
   integer(int32) :: marker = PF_MARKER_NONE                                                  !< Marker.
   real(real32)   :: marker_size = 4.0_real32                                                 !< MarkerSize [pixels].
   real(real32)   :: marker_line_color(4) = [0.0_real32, 0.0_real32, 0.0_real32, AUTO_ALPHA] !< MarkerLineColor.
   real(real32)   :: marker_fill_color(4) = [0.0_real32, 0.0_real32, 0.0_real32, AUTO_ALPHA] !< MarkerFillColor.
   real(real32)   :: size = 4.0_real32                                                        !< Size [pixels].
   integer(int32) :: flags = 0_int32                                                          !< Flags.
endtype plot_item_spec

type :: item_style
   !< `ImPlotNextItemData` after `BeginItem`: the style staged for drawing.
   integer(int32) :: col_line = 0_int32       !< Line colour (packed, `GetColorU32`).
   integer(int32) :: col_fill = 0_int32       !< Fill colour.
   integer(int32) :: col_mline = 0_int32      !< Markers' outline colour.
   integer(int32) :: col_mfill = 0_int32      !< Markers' fill colour.
   real(real32)   :: weight = 1.0_real32      !< Line weight [pixels].
   real(real32)   :: marker_size = 4.0_real32 !< Marker size [pixels].
   real(real32)   :: size = 4.0_real32        !< Size: error bars' whiskers [pixels].
   integer(int32) :: marker = PF_MARKER_NONE  !< Marker.
   integer(int32) :: flags = 0_int32          !< Flags.
   logical        :: line = .false.           !< RenderLine.
   logical        :: fill = .false.           !< RenderFill.
   logical        :: mline = .false.          !< RenderMarkerLine.
   logical        :: mfill = .false.          !< RenderMarkerFill.
   logical        :: markers = .false.        !< RenderMarkers.
endtype item_style

type :: item_series
   !< An item's getter (`GetterXY`): x and y each from an array read in place (any stride), uniform abscissae or a
   !< constant; `n` points (`Count`), read through the decimation's kept indices when `kept`.
   integer(int32)                   :: n = 0_int32      !< Points.
   integer(int32)                   :: src(2) = SRC_NONE !< Sources of x and y.
   logical                          :: via32 = .false.  !< Integer abscissae taken as real32 (single precision data).
   real(real32),            pointer :: a32(:) => null() !< x's real32 array.
   real(real32),            pointer :: b32(:) => null() !< y's real32 array.
   real(real64),            pointer :: a64(:) => null() !< x's real64 array.
   real(real64),            pointer :: b64(:) => null() !< y's real64 array.
   integer(int32),          pointer :: ai32(:) => null() !< x's int32 array.
   integer(int64),          pointer :: ai64(:) => null() !< x's int64 array.
   real(real64)                     :: lin(2, 2) = 0.0_real64 !< (x0, dx) of a uniform coordinate, per coordinate.
   real(real64)                     :: con(2) = 0.0_real64    !< A constant coordinate, per coordinate.
   logical                          :: kept = .false.   !< Read through `keep`.
endtype item_series

logical                     :: decimation_on = .true. !< Long series decimated (`pf_set_decimation`).
logical                     :: skip_decimation = .false. !< The item's points already kept (`pf_line_device`).
real(real64),   allocatable, target :: dev64x(:), dev64y(:) !< A device line's points on the host (kept, grown).
real(real32),   allocatable, target :: dev32x(:), dev32y(:) !< ... single precision.
! the caches of decimated series (figure_implot's, szaghi/figure#15 P5): a fixed table, entries reset field by field
type :: series_cache
   !< A series' cache: its data's identity and what `decimate` keeps.
   logical              :: used = .false.          !< Holds a series.
   integer(c_intptr_t)  :: p(3) = 0_c_intptr_t     !< Addresses of x, y, y2.
   integer(int64)       :: n = 0_int64             !< Points.
   integer(int64)       :: stride = 0_int64        !< y's stride [bytes].
   integer(int32)       :: kind = 0_int32          !< Bytes of a value.
   integer(int32)       :: item = 0_int32          !< KIND_*.
   logical              :: uniform = .false.       !< Abscissae x0 + (i - 1) dx.
   real(real64)         :: x0 = 0.0_real64         !< ... x0.
   real(real64)         :: dx = 0.0_real64         !< ... dx.
   real(real64)         :: last_time = 0.0_real64  !< Time of its last use [s].
   type(decimate_cache) :: dc                      !< What `decimate` keeps.
endtype series_cache
real(real64),   parameter   :: CACHE_IDLE = 10.0_real64 !< A cache not used for this long is released [s].
integer(int32), parameter   :: CACHE_SLOTS = 32_int32   !< Caches at most.
type(series_cache)          :: caches(CACHE_SLOTS)      !< The caches.
logical                     :: next_cached = .false.    !< The next line-like item uses its cache.
logical                     :: next_changed = .false.   !< ... its data changed.
integer(int64)              :: plot_cache_builds = 0_int64 !< Caches built (tests: figure_implot's, as the current path's).
integer(int64)              :: plot_cache_hits = 0_int64   !< Caches reused (tests).
integer(int64)              :: plot_decimated = 0_int64    !< Items decimated so far (tests: figure_implot's, as the
                                                           !< current path's `plot_decimated`).
integer(int64)              :: plot_kept = 0_int64         !< Points the last decimated item kept (tests).
logical                     :: pf_last_decimated = .false. !< The last line-like item was decimated (set by its
                                                           !< decimation; figure_implot clears it before an item: the
                                                           !< stride `test_plot_stride` reports).
integer(int64), allocatable :: keep(:)                !< The decimation's kept indices.
real(real32),   allocatable :: conv32(:)              !< Integer abscissae converted (decimated items).
real(real64),   allocatable :: conv64(:)              !< ...
real(real64)                :: uv_white(2) = 0.0_real64 !< The white pixel's texture coordinates (this item's).
type :: prim_run
   !< A renderer's run of primitives as `RenderPrimitivesEx` reserves it: the room per primitive, the culled ones whose
   !< room is still reserved, and the write cursor in the target's buffers (`core_run_reserve`: written in place,
   !< szaghi/figure#16 D2).
   type(draw_vert),    pointer, contiguous :: vb(:) => null() !< The target's vertices (`core_run_reserve`).
   integer(c_int16_t), pointer, contiguous :: ib(:) => null() !< ... its 16-bit indices (stored as IDX16_SIGN says).
   integer(int32)           :: vtx = 0_int32 !< Vertices a primitive (`VtxConsumed`).
   integer(int32)           :: idx = 0_int32 !< Indices a primitive (`IdxConsumed`).
   integer(int32)           :: culled = 0_int32 !< Primitives culled, their room reserved (`prims_culled`).
   integer(int32)           :: iv = 0_int32  !< Next vertex's place in `vb`.
   integer(int32)           :: ii = 0_int32  !< Next index's place in `ib`.
   integer(int32)           :: b = 0_int32   !< Next vertex's index in the draw command (`_VtxCurrentIdx`), 0 to 65535.
endtype prim_run
type :: point_reader
   !< A getter's points read a block at a time (`read_point`): the last block's values, as `point` gives them.
   integer(int32) :: i0 = 0_int32       !< The block's first point (0: none read).
   integer(int32) :: n = 0_int32        !< Its points.
   real(real64)   :: x(PIX_BLOCK)       !< Their x.
   real(real64)   :: y(PIX_BLOCK)       !< Their y.
endtype point_reader
type :: pixel_reader
   !< A getter's pixels mapped a block at a time (`read_pixel`): the last block's, as `pixel` gives them.
   integer(int32) :: i0 = 0_int32       !< The block's first point (0: none read).
   integer(int32) :: n = 0_int32        !< Its points.
   real(real32)   :: x(PIX_BLOCK)       !< Their pixels' x.
   real(real32)   :: y(PIX_BLOCK)       !< Their pixels' y.
endtype pixel_reader
real(real32), allocatable :: cell_x(:, :), cell_y(:, :) !< A heatmap's cells' edges in pixels, per column and row
                                                          !< (left, right; top, bottom: kept, grown).
real(real64), allocatable, target :: stack_tmp(:)     !< Stacked bar groups' neg, pos, curr_min, curr_max (TempDouble1).
real(real64), allocatable, target :: hist_a(:), hist_b(:) !< Histograms' centres and counts (TempDouble1/2), 2-D counts.
real(real64), allocatable         :: finite_x(:), finite_y(:) !< The finite values of a histogram (kept, grown).

interface pf_line
   !< Line through the points (x(i), y(i)), through y(i) at uniformly spaced x (a vector or a matrix's row): `ip_line`.
   module procedure line_r32, line_r64, line_values_r32, line_values_r64, line_row_r32, line_row_r64
   module procedure line_i32_r32, line_i64_r32, line_i32_r64, line_i64_r64
endinterface pf_line

interface pf_scatter
   !< Markers at the points (x(i), y(i)): `ip_scatter`.
   module procedure scatter_r32, scatter_r64, scatter_i32_r32, scatter_i64_r32, scatter_i32_r64, scatter_i64_r64
endinterface pf_scatter

interface pf_stairs
   !< A staircase through the points (x(i), y(i)): `ip_stairs`.
   module procedure stairs_r32, stairs_r64, stairs_i32_r32, stairs_i64_r32, stairs_i32_r64, stairs_i64_r64
endinterface pf_stairs

interface pf_stems
   !< Stems from y = ref to the points (x(i), y(i)), each with a marker: `ip_stems`.
   module procedure stems_r32, stems_r64, stems_i32_r32, stems_i64_r32, stems_i32_r64, stems_i64_r64
endinterface pf_stems

interface pf_shaded
   !< The area between two curves y1(x), y2(x), or a curve y(x) and the line y = yref: `ip_shaded`.
   module procedure shaded_r32, shaded_r64, shaded_ref_r32, shaded_ref_r64
   module procedure shaded_i32_r32, shaded_i64_r32, shaded_i32_r64, shaded_i64_r64
   module procedure shaded_ref_i32_r32, shaded_ref_i64_r32, shaded_ref_i32_r64, shaded_ref_i64_r64
endinterface pf_shaded

interface pf_bars
   !< Bars of height y(i) centred at x(i), `bar_size` wide: `ip_bars` (`PF_BARS_HORIZONTAL` in the spec: along y).
   module procedure bars_r32, bars_r64, bars_i32_r32, bars_i64_r32, bars_i32_r64, bars_i64_r64
endinterface pf_bars

interface pf_bar_groups
   !< Items in groups of bars, `values(g, i)` item i in group g: `ip_bar_groups`.
   module procedure bar_groups_r32, bar_groups_r64
endinterface pf_bar_groups

interface pf_error_bars
   !< Error bars at (x(i), y(i)): `ip_error_bars`.
   module procedure error_bars_r32, error_bars_r64, error_bars_i32_r32, error_bars_i64_r32, error_bars_i32_r64, &
                    error_bars_i64_r64
endinterface pf_error_bars

interface pf_inf_lines
   !< Lines across the whole plot at x = values(i) (y with `horizontal`): `ip_inf_lines`.
   module procedure inf_lines_r32, inf_lines_r64, inf_lines_i32, inf_lines_i64
endinterface pf_inf_lines

interface
   pure function c_cos(x) result(r) bind(C, name='cos')
   !< C's `cos`.
   import :: c_double
   implicit none
   real(c_double), value :: x !< Angle.
   real(c_double)        :: r !< Cosine.
   endfunction c_cos

   pure function c_sin(x) result(r) bind(C, name='sin')
   !< C's `sin`.
   import :: c_double
   implicit none
   real(c_double), value :: x !< Angle.
   real(c_double)        :: r !< Sine.
   endfunction c_sin

   pure function c_cosf(x) result(r) bind(C, name='cosf')
   !< C's `cosf`.
   import :: c_float
   implicit none
   real(c_float), value :: x !< Angle.
   real(c_float)        :: r !< Cosine.
   endfunction c_cosf

   pure function c_sinf(x) result(r) bind(C, name='sinf')
   !< C's `sinf`.
   import :: c_float
   implicit none
   real(c_float), value :: x !< Angle.
   real(c_float)        :: r !< Sine.
   endfunction c_sinf
endinterface

interface pf_pie_chart
   !< A pie chart, one slice per value, its label in the legend: `ip_pie_chart`.
   module procedure pie_chart_r32, pie_chart_r64
endinterface pf_pie_chart

interface pf_bubbles
   !< Circles at (x(i), y(i)) of radius radii(i) in plot units: `ip_bubbles`.
   module procedure bubbles_r32, bubbles_r64
endinterface pf_bubbles

interface pf_heatmap
   !< The field f(i, j) as coloured cells over [xmin, xmax] x [ymin, ymax]: `ip_heatmap`.
   module procedure heatmap_r32, heatmap_r64
endinterface pf_heatmap

interface pf_histogram
   !< A histogram of values: `ip_histogram`.
   module procedure histogram_r32, histogram_r64
endinterface pf_histogram

interface pf_histogram2d
   !< A 2-D histogram of points: `ip_histogram2d`.
   module procedure histogram2d_r32, histogram2d_r64
endinterface pf_histogram2d

interface pf_field_image
   !< A field through a colormap, kept as a texture: `ip_field_image`.
   module procedure field_image_r32, field_image_r64
endinterface pf_field_image

interface pf_line_device
   !< A line of two contiguous arrays on a device, decimated there: `ip_line_device`.
   module procedure pf_line_device_r32, pf_line_device_r64
endinterface pf_line_device

interface pf_digital
   !< A digital signal in a band at the bottom of the plot: `ip_digital`.
   module procedure digital_r32, digital_r64
endinterface pf_digital

contains
   ! the style

   function pf_spec(line_color, line_weight, fill_color, fill_alpha, marker, marker_size, marker_line_color, &
                    marker_fill_color, size, flags) result(spec)
   !< An item's style (`ip_spec`): ImPlot's defaults, the given properties overridden; colours RGBA in [0, 1] (four
   !< components), an absent colour automatic.
   real(real64),   intent(in), optional :: line_color(4)        !< Line colour.
   real(real64),   intent(in), optional :: line_weight          !< Line weight [pixels] (lines, markers' outlines).
   real(real64),   intent(in), optional :: fill_color(4)        !< Fill colour (shaded areas).
   real(real64),   intent(in), optional :: fill_alpha           !< Alpha multiplier of the fills.
   integer(int32), intent(in), optional :: marker               !< Marker (`PF_MARKER_*`, `ImPlotMarker_*`).
   real(real64),   intent(in), optional :: marker_size          !< Marker radius [pixels].
   real(real64),   intent(in), optional :: marker_line_color(4) !< Markers' outline colour.
   real(real64),   intent(in), optional :: marker_fill_color(4) !< Markers' fill colour.
   real(real64),   intent(in), optional :: size                 !< Error bars' whiskers, digital bars [pixels].
   integer(int32), intent(in), optional :: flags                !< Item flags (`PF_ITEM_*`, the item's own).
   type(plot_item_spec)                 :: spec                 !< Style.

   if (present(line_color)) spec%line_color = real(line_color, real32)
   if (present(line_weight)) spec%line_weight = real(line_weight, real32)
   if (present(fill_color)) spec%fill_color = real(fill_color, real32)
   if (present(fill_alpha)) spec%fill_alpha = real(fill_alpha, real32)
   if (present(marker)) spec%marker = marker
   if (present(marker_size)) spec%marker_size = real(marker_size, real32)
   if (present(marker_line_color)) spec%marker_line_color = real(marker_line_color, real32)
   if (present(marker_fill_color)) spec%marker_fill_color = real(marker_fill_color, real32)
   if (present(size)) spec%size = real(size, real32)
   if (present(flags)) spec%flags = flags
   endfunction pf_spec

   subroutine pf_set_decimation(enabled)
   !< Decimate long line-like series (default) or draw every point (`ip_set_decimation`).
   logical, intent(in) :: enabled !< Decimate.

   decimation_on = enabled
   endsubroutine pf_set_decimation

   ! lines (PlotLine)

   subroutine line_r64(label, x, y, spec)
   !< Line through the points (x(i), y(i)), double precision, read in place.
   character(len=*),     intent(in)           :: label !< Legend label.
   real(real64),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_r64(g, 1_int32, x)
   call view_r64(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call line_item(label, g, spec_or_default(spec))
   endsubroutine line_r64

   subroutine line_r32(label, x, y, spec)
   !< Line through the points (x(i), y(i)), single precision, read in place.
   character(len=*),     intent(in)           :: label !< Legend label.
   real(real32),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_r32(g, 1_int32, x)
   call view_r32(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call line_item(label, g, spec_or_default(spec))
   endsubroutine line_r32

   subroutine line_i32_r64(label, x, y, spec)
   !< Line through the points (x(i), y(i)), double precision, abscissae `int32`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int32),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_i32(g, x, .false.)
   call view_r64(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call line_item(label, g, spec_or_default(spec))
   endsubroutine line_i32_r64

   subroutine line_i64_r64(label, x, y, spec)
   !< Line through the points (x(i), y(i)), double precision, abscissae `int64`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int64),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_i64(g, x, .false.)
   call view_r64(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call line_item(label, g, spec_or_default(spec))
   endsubroutine line_i64_r64

   subroutine line_i32_r32(label, x, y, spec)
   !< Line through the points (x(i), y(i)), single precision, abscissae `int32`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int32),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_i32(g, x, .true.)
   call view_r32(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call line_item(label, g, spec_or_default(spec))
   endsubroutine line_i32_r32

   subroutine line_i64_r32(label, x, y, spec)
   !< Line through the points (x(i), y(i)), single precision, abscissae `int64`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int64),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_i64(g, x, .true.)
   call view_r32(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call line_item(label, g, spec_or_default(spec))
   endsubroutine line_i64_r32

   subroutine line_values_r64(label, y, xscale, xstart, spec)
   !< Line through y(i) at x = xstart + (i - 1) xscale, double precision, read in place.
   character(len=*),     intent(in)           :: label  !< Legend label.
   real(real64),         intent(in), target, asynchronous :: y(:)   !< Ordinates.
   real(real64),         intent(in), optional :: xscale !< Spacing of the abscissae (default 1).
   real(real64),         intent(in), optional :: xstart !< First abscissa (default 0).
   type(plot_item_spec), intent(in), optional :: spec   !< Style.
   type(item_series)                          :: g      !< Getter.

   call view_lin(g, 1_int32, xstart, xscale)
   call view_r64(g, 2_int32, y)
   g%n = int(size(y), int32)
   call line_item(label, g, spec_or_default(spec))
   endsubroutine line_values_r64

   subroutine line_values_r32(label, y, xscale, xstart, spec)
   !< Line through y(i) at x = xstart + (i - 1) xscale, single precision, read in place.
   character(len=*),     intent(in)           :: label  !< Legend label.
   real(real32),         intent(in), target, asynchronous :: y(:)   !< Ordinates.
   real(real64),         intent(in), optional :: xscale !< Spacing of the abscissae (default 1).
   real(real64),         intent(in), optional :: xstart !< First abscissa (default 0).
   type(plot_item_spec), intent(in), optional :: spec   !< Style.
   type(item_series)                          :: g      !< Getter.

   call view_lin(g, 1_int32, xstart, xscale)
   call view_r32(g, 2_int32, y)
   g%n = int(size(y), int32)
   call line_item(label, g, spec_or_default(spec))
   endsubroutine line_values_r32

   subroutine line_row_r64(label, y, row, xscale, xstart, spec)
   !< Line through the row `row` of `y`, y(row, j) at x = xstart + (j - 1) xscale, read in place, double precision.
   character(len=*),     intent(in)                   :: label  !< Legend label.
   real(real64),         intent(in), target           :: y(:,:) !< Matrix.
   integer(int32),       intent(in)                   :: row    !< Row, in 1..size(y, 1).
   real(real64),         intent(in), optional         :: xscale !< Spacing of the abscissae (default 1).
   real(real64),         intent(in), optional         :: xstart !< First abscissa (default 0).
   type(plot_item_spec), intent(in), optional         :: spec   !< Style.
   type(item_series)                                  :: g      !< Getter.

   if (row < 1_int32 .or. row > size(y, 1)) error stop 'figure_plot_items: pf_line: row outside the matrix'
   call view_lin(g, 1_int32, xstart, xscale)
   call view_r64(g, 2_int32, y(row, :))
   g%n = int(size(y, 2), int32)
   call line_item(label, g, spec_or_default(spec))
   endsubroutine line_row_r64

   subroutine line_row_r32(label, y, row, xscale, xstart, spec)
   !< Line through the row `row` of `y`, y(row, j) at x = xstart + (j - 1) xscale, read in place, single precision.
   character(len=*),     intent(in)                   :: label  !< Legend label.
   real(real32),         intent(in), target           :: y(:,:) !< Matrix.
   integer(int32),       intent(in)                   :: row    !< Row, in 1..size(y, 1).
   real(real64),         intent(in), optional         :: xscale !< Spacing of the abscissae (default 1).
   real(real64),         intent(in), optional         :: xstart !< First abscissa (default 0).
   type(plot_item_spec), intent(in), optional         :: spec   !< Style.
   type(item_series)                                  :: g      !< Getter.

   if (row < 1_int32 .or. row > size(y, 1)) error stop 'figure_plot_items: pf_line: row outside the matrix'
   call view_lin(g, 1_int32, xstart, xscale)
   call view_r32(g, 2_int32, y(row, :))
   g%n = int(size(y, 2), int32)
   call line_item(label, g, spec_or_default(spec))
   endsubroutine line_row_r32

   ! scatter (PlotScatter)

   subroutine scatter_r64(label, x, y, spec)
   !< Markers at the points (x(i), y(i)), double precision, read in place.
   character(len=*),     intent(in)           :: label !< Legend label.
   real(real64),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_r64(g, 1_int32, x)
   call view_r64(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call scatter_item(label, g, spec_or_default(spec))
   endsubroutine scatter_r64

   subroutine scatter_r32(label, x, y, spec)
   !< Markers at the points (x(i), y(i)), single precision, read in place.
   character(len=*),     intent(in)           :: label !< Legend label.
   real(real32),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_r32(g, 1_int32, x)
   call view_r32(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call scatter_item(label, g, spec_or_default(spec))
   endsubroutine scatter_r32

   subroutine scatter_i32_r64(label, x, y, spec)
   !< Markers at the points (x(i), y(i)), double precision, abscissae `int32`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int32),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_i32(g, x, .false.)
   call view_r64(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call scatter_item(label, g, spec_or_default(spec))
   endsubroutine scatter_i32_r64

   subroutine scatter_i64_r64(label, x, y, spec)
   !< Markers at the points (x(i), y(i)), double precision, abscissae `int64`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int64),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_i64(g, x, .false.)
   call view_r64(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call scatter_item(label, g, spec_or_default(spec))
   endsubroutine scatter_i64_r64

   subroutine scatter_i32_r32(label, x, y, spec)
   !< Markers at the points (x(i), y(i)), single precision, abscissae `int32`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int32),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_i32(g, x, .true.)
   call view_r32(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call scatter_item(label, g, spec_or_default(spec))
   endsubroutine scatter_i32_r32

   subroutine scatter_i64_r32(label, x, y, spec)
   !< Markers at the points (x(i), y(i)), single precision, abscissae `int64`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int64),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_i64(g, x, .true.)
   call view_r32(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call scatter_item(label, g, spec_or_default(spec))
   endsubroutine scatter_i64_r32

   ! stairs (PlotStairs)

   subroutine stairs_r64(label, x, y, spec)
   !< A staircase through the points (x(i), y(i)), double precision, read in place.
   character(len=*),     intent(in)           :: label !< Legend label.
   real(real64),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_r64(g, 1_int32, x)
   call view_r64(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call stairs_item(label, g, spec_or_default(spec))
   endsubroutine stairs_r64

   subroutine stairs_r32(label, x, y, spec)
   !< A staircase through the points (x(i), y(i)), single precision, read in place.
   character(len=*),     intent(in)           :: label !< Legend label.
   real(real32),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_r32(g, 1_int32, x)
   call view_r32(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call stairs_item(label, g, spec_or_default(spec))
   endsubroutine stairs_r32

   subroutine stairs_i32_r64(label, x, y, spec)
   !< A staircase through the points (x(i), y(i)), double precision, abscissae `int32`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int32),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_i32(g, x, .false.)
   call view_r64(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call stairs_item(label, g, spec_or_default(spec))
   endsubroutine stairs_i32_r64

   subroutine stairs_i64_r64(label, x, y, spec)
   !< A staircase through the points (x(i), y(i)), double precision, abscissae `int64`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int64),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_i64(g, x, .false.)
   call view_r64(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call stairs_item(label, g, spec_or_default(spec))
   endsubroutine stairs_i64_r64

   subroutine stairs_i32_r32(label, x, y, spec)
   !< A staircase through the points (x(i), y(i)), single precision, abscissae `int32`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int32),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_i32(g, x, .true.)
   call view_r32(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call stairs_item(label, g, spec_or_default(spec))
   endsubroutine stairs_i32_r32

   subroutine stairs_i64_r32(label, x, y, spec)
   !< A staircase through the points (x(i), y(i)), single precision, abscissae `int64`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int64),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_i64(g, x, .true.)
   call view_r32(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call stairs_item(label, g, spec_or_default(spec))
   endsubroutine stairs_i64_r32

   ! stems (PlotStems)

   subroutine stems_r64(label, x, y, ref, spec)
   !< Stems from y = ref (x = ref with `PF_STEMS_HORIZONTAL`) to the points (x(i), y(i)), double precision.
   character(len=*),     intent(in)           :: label !< Legend label.
   real(real64),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real64),         intent(in), optional :: ref   !< Base of the stems (default 0).
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_r64(g, 1_int32, x)
   call view_r64(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call stems_item(label, g, ref, spec_or_default(spec))
   endsubroutine stems_r64

   subroutine stems_r32(label, x, y, ref, spec)
   !< Stems from y = ref to the points (x(i), y(i)), single precision.
   character(len=*),     intent(in)           :: label !< Legend label.
   real(real32),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real64),         intent(in), optional :: ref   !< Base of the stems (default 0).
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_r32(g, 1_int32, x)
   call view_r32(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call stems_item(label, g, ref, spec_or_default(spec))
   endsubroutine stems_r32

   subroutine stems_i32_r64(label, x, y, ref, spec)
   !< Stems from y = ref to the points (x(i), y(i)), double precision, abscissae `int32`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int32),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real64),         intent(in), optional :: ref   !< Base of the stems (default 0).
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_i32(g, x, .false.)
   call view_r64(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call stems_item(label, g, ref, spec_or_default(spec))
   endsubroutine stems_i32_r64

   subroutine stems_i64_r64(label, x, y, ref, spec)
   !< Stems from y = ref to the points (x(i), y(i)), double precision, abscissae `int64`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int64),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real64),         intent(in), optional :: ref   !< Base of the stems (default 0).
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_i64(g, x, .false.)
   call view_r64(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call stems_item(label, g, ref, spec_or_default(spec))
   endsubroutine stems_i64_r64

   subroutine stems_i32_r32(label, x, y, ref, spec)
   !< Stems from y = ref to the points (x(i), y(i)), single precision, abscissae `int32`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int32),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real64),         intent(in), optional :: ref   !< Base of the stems (default 0).
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_i32(g, x, .true.)
   call view_r32(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call stems_item(label, g, ref, spec_or_default(spec))
   endsubroutine stems_i32_r32

   subroutine stems_i64_r32(label, x, y, ref, spec)
   !< Stems from y = ref to the points (x(i), y(i)), single precision, abscissae `int64`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int64),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),         intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real64),         intent(in), optional :: ref   !< Base of the stems (default 0).
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g     !< Getter.

   call view_i64(g, x, .true.)
   call view_r32(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call stems_item(label, g, ref, spec_or_default(spec))
   endsubroutine stems_i64_r32

   ! shaded (PlotShaded)

   subroutine shaded_r64(label, x, y1, y2, spec)
   !< The area between y1(x) and y2(x), double precision, read in place.
   character(len=*),     intent(in)           :: label !< Legend label.
   real(real64),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),         intent(in), target, asynchronous :: y1(:) !< First curve.
   real(real64),         intent(in), target, asynchronous :: y2(:) !< Second curve.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g1, g2 !< Getters.

   call view_r64(g1, 1_int32, x)
   call view_r64(g1, 2_int32, y1)
   call view_r64(g2, 1_int32, x)
   call view_r64(g2, 2_int32, y2)
   g1%n = int(min(size(x), size(y1), size(y2)), int32)
   g2%n = g1%n
   call shaded_item(label, g1, g2, spec_or_default(spec))
   endsubroutine shaded_r64

   subroutine shaded_r32(label, x, y1, y2, spec)
   !< The area between y1(x) and y2(x), single precision, read in place.
   character(len=*),     intent(in)           :: label !< Legend label.
   real(real32),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),         intent(in), target, asynchronous :: y1(:) !< First curve.
   real(real32),         intent(in), target, asynchronous :: y2(:) !< Second curve.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g1, g2 !< Getters.

   call view_r32(g1, 1_int32, x)
   call view_r32(g1, 2_int32, y1)
   call view_r32(g2, 1_int32, x)
   call view_r32(g2, 2_int32, y2)
   g1%n = int(min(size(x), size(y1), size(y2)), int32)
   g2%n = g1%n
   call shaded_item(label, g1, g2, spec_or_default(spec))
   endsubroutine shaded_r32

   subroutine shaded_i32_r64(label, x, y1, y2, spec)
   !< The area between y1(x) and y2(x), double precision, abscissae `int32`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int32),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),         intent(in), target, asynchronous :: y1(:) !< First curve.
   real(real64),         intent(in), target, asynchronous :: y2(:) !< Second curve.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g1, g2 !< Getters.

   call view_i32(g1, x, .false.)
   call view_r64(g1, 2_int32, y1)
   call view_i32(g2, x, .false.)
   call view_r64(g2, 2_int32, y2)
   g1%n = int(min(size(x), size(y1), size(y2)), int32)
   g2%n = g1%n
   call shaded_item(label, g1, g2, spec_or_default(spec))
   endsubroutine shaded_i32_r64

   subroutine shaded_i64_r64(label, x, y1, y2, spec)
   !< The area between y1(x) and y2(x), double precision, abscissae `int64`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int64),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),         intent(in), target, asynchronous :: y1(:) !< First curve.
   real(real64),         intent(in), target, asynchronous :: y2(:) !< Second curve.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g1, g2 !< Getters.

   call view_i64(g1, x, .false.)
   call view_r64(g1, 2_int32, y1)
   call view_i64(g2, x, .false.)
   call view_r64(g2, 2_int32, y2)
   g1%n = int(min(size(x), size(y1), size(y2)), int32)
   g2%n = g1%n
   call shaded_item(label, g1, g2, spec_or_default(spec))
   endsubroutine shaded_i64_r64

   subroutine shaded_i32_r32(label, x, y1, y2, spec)
   !< The area between y1(x) and y2(x), single precision, abscissae `int32`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int32),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),         intent(in), target, asynchronous :: y1(:) !< First curve.
   real(real32),         intent(in), target, asynchronous :: y2(:) !< Second curve.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g1, g2 !< Getters.

   call view_i32(g1, x, .true.)
   call view_r32(g1, 2_int32, y1)
   call view_i32(g2, x, .true.)
   call view_r32(g2, 2_int32, y2)
   g1%n = int(min(size(x), size(y1), size(y2)), int32)
   g2%n = g1%n
   call shaded_item(label, g1, g2, spec_or_default(spec))
   endsubroutine shaded_i32_r32

   subroutine shaded_i64_r32(label, x, y1, y2, spec)
   !< The area between y1(x) and y2(x), single precision, abscissae `int64`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int64),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),         intent(in), target, asynchronous :: y1(:) !< First curve.
   real(real32),         intent(in), target, asynchronous :: y2(:) !< Second curve.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g1, g2 !< Getters.

   call view_i64(g1, x, .true.)
   call view_r32(g1, 2_int32, y1)
   call view_i64(g2, x, .true.)
   call view_r32(g2, 2_int32, y2)
   g1%n = int(min(size(x), size(y1), size(y2)), int32)
   g2%n = g1%n
   call shaded_item(label, g1, g2, spec_or_default(spec))
   endsubroutine shaded_i64_r32

   subroutine shaded_ref_r64(label, x, y, yref, spec)
   !< The area between y(x) and the line y = yref (-inf, +inf: the plot's bottom, top), double precision.
   character(len=*),     intent(in)           :: label !< Legend label.
   real(real64),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),         intent(in), target, asynchronous :: y(:)  !< Curve.
   real(real64),         intent(in)           :: yref  !< Reference line.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g1, g2 !< Getters.

   call view_r64(g1, 1_int32, x)
   call view_r64(g1, 2_int32, y)
   call view_r64(g2, 1_int32, x)
   call view_const(g2, 2_int32, yref)
   g1%n = int(min(size(x), size(y)), int32)
   g2%n = g1%n
   call shaded_item(label, g1, g2, spec_or_default(spec), yref)
   endsubroutine shaded_ref_r64

   subroutine shaded_ref_r32(label, x, y, yref, spec)
   !< The area between y(x) and the line y = yref, single precision.
   character(len=*),     intent(in)           :: label !< Legend label.
   real(real32),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),         intent(in), target, asynchronous :: y(:)  !< Curve.
   real(real64),         intent(in)           :: yref  !< Reference line.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g1, g2 !< Getters.

   call view_r32(g1, 1_int32, x)
   call view_r32(g1, 2_int32, y)
   call view_r32(g2, 1_int32, x)
   call view_const(g2, 2_int32, yref)
   g1%n = int(min(size(x), size(y)), int32)
   g2%n = g1%n
   call shaded_item(label, g1, g2, spec_or_default(spec), yref)
   endsubroutine shaded_ref_r32

   subroutine shaded_ref_i32_r64(label, x, y, yref, spec)
   !< The area between y(x) and the line y = yref, double precision, abscissae `int32`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int32),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),         intent(in), target, asynchronous :: y(:)  !< Curve.
   real(real64),         intent(in)           :: yref  !< Reference line.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g1, g2 !< Getters.

   call view_i32(g1, x, .false.)
   call view_r64(g1, 2_int32, y)
   call view_i32(g2, x, .false.)
   call view_const(g2, 2_int32, yref)
   g1%n = int(min(size(x), size(y)), int32)
   g2%n = g1%n
   call shaded_item(label, g1, g2, spec_or_default(spec), yref)
   endsubroutine shaded_ref_i32_r64

   subroutine shaded_ref_i64_r64(label, x, y, yref, spec)
   !< The area between y(x) and the line y = yref, double precision, abscissae `int64`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int64),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),         intent(in), target, asynchronous :: y(:)  !< Curve.
   real(real64),         intent(in)           :: yref  !< Reference line.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g1, g2 !< Getters.

   call view_i64(g1, x, .false.)
   call view_r64(g1, 2_int32, y)
   call view_i64(g2, x, .false.)
   call view_const(g2, 2_int32, yref)
   g1%n = int(min(size(x), size(y)), int32)
   g2%n = g1%n
   call shaded_item(label, g1, g2, spec_or_default(spec), yref)
   endsubroutine shaded_ref_i64_r64

   subroutine shaded_ref_i32_r32(label, x, y, yref, spec)
   !< The area between y(x) and the line y = yref, single precision, abscissae `int32`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int32),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),         intent(in), target, asynchronous :: y(:)  !< Curve.
   real(real64),         intent(in)           :: yref  !< Reference line.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g1, g2 !< Getters.

   call view_i32(g1, x, .true.)
   call view_r32(g1, 2_int32, y)
   call view_i32(g2, x, .true.)
   call view_const(g2, 2_int32, yref)
   g1%n = int(min(size(x), size(y)), int32)
   g2%n = g1%n
   call shaded_item(label, g1, g2, spec_or_default(spec), yref)
   endsubroutine shaded_ref_i32_r32

   subroutine shaded_ref_i64_r32(label, x, y, yref, spec)
   !< The area between y(x) and the line y = yref, single precision, abscissae `int64`.
   character(len=*),     intent(in)           :: label !< Legend label.
   integer(int64),       intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),         intent(in), target, asynchronous :: y(:)  !< Curve.
   real(real64),         intent(in)           :: yref  !< Reference line.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   type(item_series)                          :: g1, g2 !< Getters.

   call view_i64(g1, x, .true.)
   call view_r32(g1, 2_int32, y)
   call view_i64(g2, x, .true.)
   call view_const(g2, 2_int32, yref)
   g1%n = int(min(size(x), size(y)), int32)
   g2%n = g1%n
   call shaded_item(label, g1, g2, spec_or_default(spec), yref)
   endsubroutine shaded_ref_i64_r32

   ! bars, bar groups, error bars, infinite lines (PlotBars, PlotBarGroups, PlotErrorBars, PlotInfLines)

   subroutine bars_r32(label, x, y, bar_size, spec)
   !< Bars of height y(i) centred at x(i), `bar_size` wide, single precision, read in place.
   character(len=*),     intent(in)           :: label    !< Legend label.
   real(real32)        , intent(in), target, asynchronous :: x(:)     !< Bar positions.
   real(real32)        , intent(in), target, asynchronous :: y(:)     !< Bar heights.
   real(real64),         intent(in)           :: bar_size !< Bar width [x units].
   type(plot_item_spec), intent(in), optional :: spec     !< Style.
   type(item_series)                          :: g        !< Getter.

   call view_r32(g, 1_int32, x)
   call view_r32(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call bars_item(label, g, bar_size, spec_or_default(spec))
   endsubroutine bars_r32

   subroutine bars_r64(label, x, y, bar_size, spec)
   !< Bars of height y(i) centred at x(i), `bar_size` wide, double precision, read in place.
   character(len=*),     intent(in)           :: label    !< Legend label.
   real(real64)        , intent(in), target, asynchronous :: x(:)     !< Bar positions.
   real(real64)        , intent(in), target, asynchronous :: y(:)     !< Bar heights.
   real(real64),         intent(in)           :: bar_size !< Bar width [x units].
   type(plot_item_spec), intent(in), optional :: spec     !< Style.
   type(item_series)                          :: g        !< Getter.

   call view_r64(g, 1_int32, x)
   call view_r64(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call bars_item(label, g, bar_size, spec_or_default(spec))
   endsubroutine bars_r64

   subroutine bars_i32_r32(label, x, y, bar_size, spec)
   !< Bars of height y(i) centred at x(i), `bar_size` wide, single precision, abscissae `int32`, read in place.
   character(len=*),     intent(in)           :: label    !< Legend label.
   integer(int32)      , intent(in), target, asynchronous :: x(:)     !< Bar positions.
   real(real32)        , intent(in), target, asynchronous :: y(:)     !< Bar heights.
   real(real64),         intent(in)           :: bar_size !< Bar width [x units].
   type(plot_item_spec), intent(in), optional :: spec     !< Style.
   type(item_series)                          :: g        !< Getter.

   call view_i32(g, x, .true.)
   call view_r32(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call bars_item(label, g, bar_size, spec_or_default(spec))
   endsubroutine bars_i32_r32

   subroutine bars_i64_r32(label, x, y, bar_size, spec)
   !< Bars of height y(i) centred at x(i), `bar_size` wide, single precision, abscissae `int64`, read in place.
   character(len=*),     intent(in)           :: label    !< Legend label.
   integer(int64)      , intent(in), target, asynchronous :: x(:)     !< Bar positions.
   real(real32)        , intent(in), target, asynchronous :: y(:)     !< Bar heights.
   real(real64),         intent(in)           :: bar_size !< Bar width [x units].
   type(plot_item_spec), intent(in), optional :: spec     !< Style.
   type(item_series)                          :: g        !< Getter.

   call view_i64(g, x, .true.)
   call view_r32(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call bars_item(label, g, bar_size, spec_or_default(spec))
   endsubroutine bars_i64_r32

   subroutine bars_i32_r64(label, x, y, bar_size, spec)
   !< Bars of height y(i) centred at x(i), `bar_size` wide, double precision, abscissae `int32`, read in place.
   character(len=*),     intent(in)           :: label    !< Legend label.
   integer(int32)      , intent(in), target, asynchronous :: x(:)     !< Bar positions.
   real(real64)        , intent(in), target, asynchronous :: y(:)     !< Bar heights.
   real(real64),         intent(in)           :: bar_size !< Bar width [x units].
   type(plot_item_spec), intent(in), optional :: spec     !< Style.
   type(item_series)                          :: g        !< Getter.

   call view_i32(g, x, .false.)
   call view_r64(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call bars_item(label, g, bar_size, spec_or_default(spec))
   endsubroutine bars_i32_r64

   subroutine bars_i64_r64(label, x, y, bar_size, spec)
   !< Bars of height y(i) centred at x(i), `bar_size` wide, double precision, abscissae `int64`, read in place.
   character(len=*),     intent(in)           :: label    !< Legend label.
   integer(int64)      , intent(in), target, asynchronous :: x(:)     !< Bar positions.
   real(real64)        , intent(in), target, asynchronous :: y(:)     !< Bar heights.
   real(real64),         intent(in)           :: bar_size !< Bar width [x units].
   type(plot_item_spec), intent(in), optional :: spec     !< Style.
   type(item_series)                          :: g        !< Getter.

   call view_i64(g, x, .false.)
   call view_r64(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call bars_item(label, g, bar_size, spec_or_default(spec))
   endsubroutine bars_i64_r64

   subroutine error_bars_r32(label, x, y, err, err_high, spec, horizontal)
   !< Error bars at (x(i), y(i)) from y(i) - err(i) to y(i) + err(i) (+ err_high(i)), along x with `horizontal`,
   !< single precision, read in place.
   character(len=*),     intent(in)                   :: label       !< Legend label.
   real(real32)        , intent(in), target, asynchronous :: x(:)        !< Abscissae.
   real(real32)        , intent(in), target, asynchronous :: y(:)        !< Ordinates.
   real(real32)        , intent(in), target, asynchronous :: err(:)      !< Error below (and above).
   real(real32)        , intent(in), target, optional, asynchronous :: err_high(:) !< Error above.
   type(plot_item_spec), intent(in), optional         :: spec        !< Style.
   logical,              intent(in), optional         :: horizontal  !< Bars along x.
   type(item_series)                                  :: g, e        !< Getters: the points, the errors.

   call view_r32(g, 1_int32, x)
   call view_r32(g, 2_int32, y)
   call view_r32(e, 1_int32, err)
   if (present(err_high)) then
      call view_r32(e, 2_int32, err_high)
   else
      call view_r32(e, 2_int32, err)
   endif
   g%n = int(min(size(x), size(y), size(err)), int32)
   if (present(err_high)) g%n = min(g%n, int(size(err_high), int32))
   e%n = g%n
   call error_bars_item(label, g, e, spec_or_default(spec), horizontal)
   endsubroutine error_bars_r32

   subroutine error_bars_r64(label, x, y, err, err_high, spec, horizontal)
   !< Error bars at (x(i), y(i)) from y(i) - err(i) to y(i) + err(i) (+ err_high(i)), along x with `horizontal`,
   !< double precision, read in place.
   character(len=*),     intent(in)                   :: label       !< Legend label.
   real(real64)        , intent(in), target, asynchronous :: x(:)        !< Abscissae.
   real(real64)        , intent(in), target, asynchronous :: y(:)        !< Ordinates.
   real(real64)        , intent(in), target, asynchronous :: err(:)      !< Error below (and above).
   real(real64)        , intent(in), target, optional, asynchronous :: err_high(:) !< Error above.
   type(plot_item_spec), intent(in), optional         :: spec        !< Style.
   logical,              intent(in), optional         :: horizontal  !< Bars along x.
   type(item_series)                                  :: g, e        !< Getters: the points, the errors.

   call view_r64(g, 1_int32, x)
   call view_r64(g, 2_int32, y)
   call view_r64(e, 1_int32, err)
   if (present(err_high)) then
      call view_r64(e, 2_int32, err_high)
   else
      call view_r64(e, 2_int32, err)
   endif
   g%n = int(min(size(x), size(y), size(err)), int32)
   if (present(err_high)) g%n = min(g%n, int(size(err_high), int32))
   e%n = g%n
   call error_bars_item(label, g, e, spec_or_default(spec), horizontal)
   endsubroutine error_bars_r64

   subroutine error_bars_i32_r32(label, x, y, err, err_high, spec, horizontal)
   !< Error bars at (x(i), y(i)) from y(i) - err(i) to y(i) + err(i) (+ err_high(i)), along x with `horizontal`,
   !< single precision, abscissae `int32`, read in place.
   character(len=*),     intent(in)                   :: label       !< Legend label.
   integer(int32)      , intent(in), target, asynchronous :: x(:)        !< Abscissae.
   real(real32)        , intent(in), target, asynchronous :: y(:)        !< Ordinates.
   real(real32)        , intent(in), target, asynchronous :: err(:)      !< Error below (and above).
   real(real32)        , intent(in), target, optional, asynchronous :: err_high(:) !< Error above.
   type(plot_item_spec), intent(in), optional         :: spec        !< Style.
   logical,              intent(in), optional         :: horizontal  !< Bars along x.
   type(item_series)                                  :: g, e        !< Getters: the points, the errors.

   call view_i32(g, x, .true.)
   call view_r32(g, 2_int32, y)
   call view_r32(e, 1_int32, err)
   if (present(err_high)) then
      call view_r32(e, 2_int32, err_high)
   else
      call view_r32(e, 2_int32, err)
   endif
   g%n = int(min(size(x), size(y), size(err)), int32)
   if (present(err_high)) g%n = min(g%n, int(size(err_high), int32))
   e%n = g%n
   call error_bars_item(label, g, e, spec_or_default(spec), horizontal)
   endsubroutine error_bars_i32_r32

   subroutine error_bars_i64_r32(label, x, y, err, err_high, spec, horizontal)
   !< Error bars at (x(i), y(i)) from y(i) - err(i) to y(i) + err(i) (+ err_high(i)), along x with `horizontal`,
   !< single precision, abscissae `int64`, read in place.
   character(len=*),     intent(in)                   :: label       !< Legend label.
   integer(int64)      , intent(in), target, asynchronous :: x(:)        !< Abscissae.
   real(real32)        , intent(in), target, asynchronous :: y(:)        !< Ordinates.
   real(real32)        , intent(in), target, asynchronous :: err(:)      !< Error below (and above).
   real(real32)        , intent(in), target, optional, asynchronous :: err_high(:) !< Error above.
   type(plot_item_spec), intent(in), optional         :: spec        !< Style.
   logical,              intent(in), optional         :: horizontal  !< Bars along x.
   type(item_series)                                  :: g, e        !< Getters: the points, the errors.

   call view_i64(g, x, .true.)
   call view_r32(g, 2_int32, y)
   call view_r32(e, 1_int32, err)
   if (present(err_high)) then
      call view_r32(e, 2_int32, err_high)
   else
      call view_r32(e, 2_int32, err)
   endif
   g%n = int(min(size(x), size(y), size(err)), int32)
   if (present(err_high)) g%n = min(g%n, int(size(err_high), int32))
   e%n = g%n
   call error_bars_item(label, g, e, spec_or_default(spec), horizontal)
   endsubroutine error_bars_i64_r32

   subroutine error_bars_i32_r64(label, x, y, err, err_high, spec, horizontal)
   !< Error bars at (x(i), y(i)) from y(i) - err(i) to y(i) + err(i) (+ err_high(i)), along x with `horizontal`,
   !< double precision, abscissae `int32`, read in place.
   character(len=*),     intent(in)                   :: label       !< Legend label.
   integer(int32)      , intent(in), target, asynchronous :: x(:)        !< Abscissae.
   real(real64)        , intent(in), target, asynchronous :: y(:)        !< Ordinates.
   real(real64)        , intent(in), target, asynchronous :: err(:)      !< Error below (and above).
   real(real64)        , intent(in), target, optional, asynchronous :: err_high(:) !< Error above.
   type(plot_item_spec), intent(in), optional         :: spec        !< Style.
   logical,              intent(in), optional         :: horizontal  !< Bars along x.
   type(item_series)                                  :: g, e        !< Getters: the points, the errors.

   call view_i32(g, x, .false.)
   call view_r64(g, 2_int32, y)
   call view_r64(e, 1_int32, err)
   if (present(err_high)) then
      call view_r64(e, 2_int32, err_high)
   else
      call view_r64(e, 2_int32, err)
   endif
   g%n = int(min(size(x), size(y), size(err)), int32)
   if (present(err_high)) g%n = min(g%n, int(size(err_high), int32))
   e%n = g%n
   call error_bars_item(label, g, e, spec_or_default(spec), horizontal)
   endsubroutine error_bars_i32_r64

   subroutine error_bars_i64_r64(label, x, y, err, err_high, spec, horizontal)
   !< Error bars at (x(i), y(i)) from y(i) - err(i) to y(i) + err(i) (+ err_high(i)), along x with `horizontal`,
   !< double precision, abscissae `int64`, read in place.
   character(len=*),     intent(in)                   :: label       !< Legend label.
   integer(int64)      , intent(in), target, asynchronous :: x(:)        !< Abscissae.
   real(real64)        , intent(in), target, asynchronous :: y(:)        !< Ordinates.
   real(real64)        , intent(in), target, asynchronous :: err(:)      !< Error below (and above).
   real(real64)        , intent(in), target, optional, asynchronous :: err_high(:) !< Error above.
   type(plot_item_spec), intent(in), optional         :: spec        !< Style.
   logical,              intent(in), optional         :: horizontal  !< Bars along x.
   type(item_series)                                  :: g, e        !< Getters: the points, the errors.

   call view_i64(g, x, .false.)
   call view_r64(g, 2_int32, y)
   call view_r64(e, 1_int32, err)
   if (present(err_high)) then
      call view_r64(e, 2_int32, err_high)
   else
      call view_r64(e, 2_int32, err)
   endif
   g%n = int(min(size(x), size(y), size(err)), int32)
   if (present(err_high)) g%n = min(g%n, int(size(err_high), int32))
   e%n = g%n
   call error_bars_item(label, g, e, spec_or_default(spec), horizontal)
   endsubroutine error_bars_i64_r64

   subroutine inf_lines_r32(label, values, horizontal, spec)
   !< Lines across the whole plot at x = values(i) (y with `horizontal`), `r32` positions, read in place.
   character(len=*),     intent(in)           :: label      !< Legend label.
   real(real32)        , intent(in), target, asynchronous :: values(:)  !< Positions.
   logical,              intent(in), optional :: horizontal !< Horizontal lines.
   type(plot_item_spec), intent(in), optional :: spec       !< Style.
   type(item_series)                          :: g          !< Getter (the positions, the other coordinate unset).
   integer(int32)                             :: k          !< The positions' coordinate.

   k = 1_int32
   if (present(horizontal)) then
      if (horizontal) k = 2_int32
   endif
   call view_r32(g, k, values)
   g%n = int(size(values), int32)
   call inf_lines_item(label, g, k, spec_or_default(spec))
   endsubroutine inf_lines_r32

   subroutine inf_lines_r64(label, values, horizontal, spec)
   !< Lines across the whole plot at x = values(i) (y with `horizontal`), `r64` positions, read in place.
   character(len=*),     intent(in)           :: label      !< Legend label.
   real(real64)        , intent(in), target, asynchronous :: values(:)  !< Positions.
   logical,              intent(in), optional :: horizontal !< Horizontal lines.
   type(plot_item_spec), intent(in), optional :: spec       !< Style.
   type(item_series)                          :: g          !< Getter (the positions, the other coordinate unset).
   integer(int32)                             :: k          !< The positions' coordinate.

   k = 1_int32
   if (present(horizontal)) then
      if (horizontal) k = 2_int32
   endif
   call view_r64(g, k, values)
   g%n = int(size(values), int32)
   call inf_lines_item(label, g, k, spec_or_default(spec))
   endsubroutine inf_lines_r64

   subroutine inf_lines_i32(label, values, horizontal, spec)
   !< Lines across the whole plot at x = values(i) (y with `horizontal`), `i32` positions, read in place.
   character(len=*),     intent(in)           :: label      !< Legend label.
   integer(int32)      , intent(in), target, asynchronous :: values(:)  !< Positions.
   logical,              intent(in), optional :: horizontal !< Horizontal lines.
   type(plot_item_spec), intent(in), optional :: spec       !< Style.
   type(item_series)                          :: g          !< Getter (the positions, the other coordinate unset).
   integer(int32)                             :: k          !< The positions' coordinate.

   k = 1_int32
   if (present(horizontal)) then
      if (horizontal) k = 2_int32
   endif
   call view_i32(g, values, .false., k)
   g%n = int(size(values), int32)
   call inf_lines_item(label, g, k, spec_or_default(spec))
   endsubroutine inf_lines_i32

   subroutine inf_lines_i64(label, values, horizontal, spec)
   !< Lines across the whole plot at x = values(i) (y with `horizontal`), `i64` positions, read in place.
   character(len=*),     intent(in)           :: label      !< Legend label.
   integer(int64)      , intent(in), target, asynchronous :: values(:)  !< Positions.
   logical,              intent(in), optional :: horizontal !< Horizontal lines.
   type(plot_item_spec), intent(in), optional :: spec       !< Style.
   type(item_series)                          :: g          !< Getter (the positions, the other coordinate unset).
   integer(int32)                             :: k          !< The positions' coordinate.

   k = 1_int32
   if (present(horizontal)) then
      if (horizontal) k = 2_int32
   endif
   call view_i64(g, values, .false., k)
   g%n = int(size(values), int32)
   call inf_lines_item(label, g, k, spec_or_default(spec))
   endsubroutine inf_lines_i64

   subroutine bar_groups_r32(labels, values, group_size, shift, horizontal, stacked, colormap, spec)
   !< Items in groups of bars (`PlotBarGroups`), `values(g, i)` item i in group g, group g at g - 1 (+ `shift`), the
   !< items side by side in `group_size` (default 0.67) or stacked; along y with `horizontal`; the items' colours from
   !< `colormap` (pushed for the call), `r32`.
   character(len=*),     intent(in)                   :: labels(:)    !< One per item (trailing blanks dropped).
   real(real32)        , intent(in), target, contiguous :: values(:, :) !< values(group, item).
   real(real64),         intent(in), optional         :: group_size   !< A group's width (default 0.67).
   real(real64),         intent(in), optional         :: shift        !< Shift of every group (default 0).
   logical,              intent(in), optional         :: horizontal   !< Along y.
   logical,              intent(in), optional         :: stacked      !< Stacked.
   integer(int32),       intent(in), optional         :: colormap     !< The items' colours.
   type(plot_item_spec), intent(in), optional         :: spec         !< Style.
   type(item_series)                                  :: g1, g2       !< Getters.
   type(plot_item_spec)                               :: sb           !< The bars' spec (flags cleared).
   real(real64)                                       :: gs, sh, sub, w, ss !< Group size, shift, a bar's.
   integer(int32)                                     :: i, j, ni, ng, ib, jl !< Item, group, counts, base, length.
   logical                                            :: horz, stack  !< Flags.
   real(real64)                                       :: v            !< A value.

   gs = 0.67_real64
   if (present(group_size)) gs = group_size
   sh = 0.0_real64
   if (present(shift)) sh = shift
   horz = .false.
   if (present(horizontal)) horz = horizontal
   stack = .false.
   if (present(stacked)) stack = stacked
   ni = int(size(values, 2), int32)
   ng = int(size(values, 1), int32)
   sb = spec_or_default(spec)
   sb%flags = 0_int32
   if (present(colormap)) call cm_push(colormap)
   if (stack) then
      call stack_room(ng)
      stack_tmp(1:2_int32 * ng) = 0.0_real64 ! neg, pos
      do i = 1_int32, ni
         jl = len_trim(labels(i), kind=int32)
         if (.not. pf_item_hidden(labels(i)(1:jl))) then
            do j = 1_int32, ng
               v = real(values(j, i), real64)
               if (v > 0.0_real64) then ! curr_min = pos, curr_max = curr_min + v, pos += v
                  stack_tmp(2_int32 * ng + j) = stack_tmp(ng + j)
                  stack_tmp(3_int32 * ng + j) = stack_tmp(2_int32 * ng + j) + v
                  stack_tmp(ng + j) = stack_tmp(ng + j) + v
               else ! curr_max = neg, curr_min = curr_max + v, neg += v
                  stack_tmp(3_int32 * ng + j) = stack_tmp(j)
                  stack_tmp(2_int32 * ng + j) = stack_tmp(3_int32 * ng + j) + v
                  stack_tmp(j) = stack_tmp(j) + v
               endif
            enddo
         endif
         ib = 2_int32 * ng
         call stacked_views(g1, g2, ng, ib, sh, horz)
         if (horz) then
            call bars_ex(labels(i)(1:jl), g1, g2, gs, sb, .true.)
         else
            call bars_ex(labels(i)(1:jl), g1, g2, gs, sb, .false.)
         endif
      enddo
   else
      sub = gs / real(ni, real64)
      do i = 1_int32, ni
         jl = len_trim(labels(i), kind=int32)
         w = (real(i - 1_int32, real64) + 0.5_real64) * sub ! subshift = (i + 0.5) subsize - group_size / 2
         ss = gs / 2.0_real64
         w = w - ss
         w = w + sh
         g1 = item_series()
         g2 = item_series()
         if (horz) then ! (values, lin), (0, lin)
            call view_r32(g1, 1_int32, values(:, i))
            call view_lin(g1, 2_int32, w, 1.0_real64)
            call view_const(g2, 1_int32, 0.0_real64)
            call view_lin(g2, 2_int32, w, 1.0_real64)
         else ! (lin, values), (lin, 0)
            call view_lin(g1, 1_int32, w, 1.0_real64)
            call view_r32(g1, 2_int32, values(:, i))
            call view_lin(g2, 1_int32, w, 1.0_real64)
            call view_const(g2, 2_int32, 0.0_real64)
         endif
         g1%n = ng
         g2%n = ng
         call bars_ex(labels(i)(1:jl), g1, g2, sub, sb, horz)
      enddo
   endif
   if (present(colormap)) call cm_pop()
   endsubroutine bar_groups_r32

   subroutine bar_groups_r64(labels, values, group_size, shift, horizontal, stacked, colormap, spec)
   !< Items in groups of bars (`PlotBarGroups`), `values(g, i)` item i in group g, group g at g - 1 (+ `shift`), the
   !< items side by side in `group_size` (default 0.67) or stacked; along y with `horizontal`; the items' colours from
   !< `colormap` (pushed for the call), `r64`.
   character(len=*),     intent(in)                   :: labels(:)    !< One per item (trailing blanks dropped).
   real(real64)        , intent(in), target, contiguous :: values(:, :) !< values(group, item).
   real(real64),         intent(in), optional         :: group_size   !< A group's width (default 0.67).
   real(real64),         intent(in), optional         :: shift        !< Shift of every group (default 0).
   logical,              intent(in), optional         :: horizontal   !< Along y.
   logical,              intent(in), optional         :: stacked      !< Stacked.
   integer(int32),       intent(in), optional         :: colormap     !< The items' colours.
   type(plot_item_spec), intent(in), optional         :: spec         !< Style.
   type(item_series)                                  :: g1, g2       !< Getters.
   type(plot_item_spec)                               :: sb           !< The bars' spec (flags cleared).
   real(real64)                                       :: gs, sh, sub, w, ss !< Group size, shift, a bar's.
   integer(int32)                                     :: i, j, ni, ng, ib, jl !< Item, group, counts, base, length.
   logical                                            :: horz, stack  !< Flags.
   real(real64)                                       :: v            !< A value.

   gs = 0.67_real64
   if (present(group_size)) gs = group_size
   sh = 0.0_real64
   if (present(shift)) sh = shift
   horz = .false.
   if (present(horizontal)) horz = horizontal
   stack = .false.
   if (present(stacked)) stack = stacked
   ni = int(size(values, 2), int32)
   ng = int(size(values, 1), int32)
   sb = spec_or_default(spec)
   sb%flags = 0_int32
   if (present(colormap)) call cm_push(colormap)
   if (stack) then
      call stack_room(ng)
      stack_tmp(1:2_int32 * ng) = 0.0_real64 ! neg, pos
      do i = 1_int32, ni
         jl = len_trim(labels(i), kind=int32)
         if (.not. pf_item_hidden(labels(i)(1:jl))) then
            do j = 1_int32, ng
               v = real(values(j, i), real64)
               if (v > 0.0_real64) then ! curr_min = pos, curr_max = curr_min + v, pos += v
                  stack_tmp(2_int32 * ng + j) = stack_tmp(ng + j)
                  stack_tmp(3_int32 * ng + j) = stack_tmp(2_int32 * ng + j) + v
                  stack_tmp(ng + j) = stack_tmp(ng + j) + v
               else ! curr_max = neg, curr_min = curr_max + v, neg += v
                  stack_tmp(3_int32 * ng + j) = stack_tmp(j)
                  stack_tmp(2_int32 * ng + j) = stack_tmp(3_int32 * ng + j) + v
                  stack_tmp(j) = stack_tmp(j) + v
               endif
            enddo
         endif
         ib = 2_int32 * ng
         call stacked_views(g1, g2, ng, ib, sh, horz)
         if (horz) then
            call bars_ex(labels(i)(1:jl), g1, g2, gs, sb, .true.)
         else
            call bars_ex(labels(i)(1:jl), g1, g2, gs, sb, .false.)
         endif
      enddo
   else
      sub = gs / real(ni, real64)
      do i = 1_int32, ni
         jl = len_trim(labels(i), kind=int32)
         w = (real(i - 1_int32, real64) + 0.5_real64) * sub ! subshift = (i + 0.5) subsize - group_size / 2
         ss = gs / 2.0_real64
         w = w - ss
         w = w + sh
         g1 = item_series()
         g2 = item_series()
         if (horz) then ! (values, lin), (0, lin)
            call view_r64(g1, 1_int32, values(:, i))
            call view_lin(g1, 2_int32, w, 1.0_real64)
            call view_const(g2, 1_int32, 0.0_real64)
            call view_lin(g2, 2_int32, w, 1.0_real64)
         else ! (lin, values), (lin, 0)
            call view_lin(g1, 1_int32, w, 1.0_real64)
            call view_r64(g1, 2_int32, values(:, i))
            call view_lin(g2, 1_int32, w, 1.0_real64)
            call view_const(g2, 2_int32, 0.0_real64)
         endif
         g1%n = ng
         g2%n = ng
         call bars_ex(labels(i)(1:jl), g1, g2, sub, sb, horz)
      enddo
   endif
   if (present(colormap)) call cm_pop()
   endsubroutine bar_groups_r64

   ! private: bars (PlotBarsVEx, PlotBarsHEx), bar groups' stacks, error bars, infinite lines

   subroutine bars_item(label, g, bar_size, spec)
   !< `PlotBars(xs, ys)`: getter1 (x, y), getter2 (x, 0) (horizontal: (0, y)).
   character(len=*),     intent(in) :: label    !< Label.
   type(item_series),    intent(in) :: g        !< Getter.
   real(real64),         intent(in) :: bar_size !< Bar size.
   type(plot_item_spec), intent(in) :: spec     !< Style.
   type(item_series)                :: g2       !< The bars' bases.
   logical                          :: horz     !< Horizontal.

   horz = iand(spec%flags, PF_BARS_HORIZONTAL) /= 0_int32
   g2 = g
   if (horz) then
      g2%src(1) = SRC_CONST
      g2%con(1) = 0.0_real64
   else
      g2%src(2) = SRC_CONST
      g2%con(2) = 0.0_real64
   endif
   call bars_ex(label, g, g2, bar_size, spec, horz)
   endsubroutine bars_item

   subroutine bars_ex(label, g1, g2, bar_size, spec, horz)
   !< `PlotBarsVEx`/`PlotBarsHEx`: `FitterBarV`/`H`, the fills (`RendererBarsFillV`/`H`), the outlines unless the fill
   !< has their colour (`RendererBarsLineV`/`H`).
   character(len=*),     intent(in) :: label    !< Label.
   type(item_series),    intent(in) :: g1, g2   !< Getters: the bars' ends.
   real(real64),         intent(in) :: bar_size !< Width (height).
   type(plot_item_spec), intent(in) :: spec     !< Style.
   logical,              intent(in) :: horz     !< Horizontal.
   type(plot_item_ctx)              :: ctx      !< The plot.
   type(item_style)                 :: s        !< Staged style.
   real(real64)                     :: half     !< Half the bar size.
   real(real64)                     :: x1, y1, x2, y2 !< Ends.
   integer(int32)                   :: i        !< Bar.
   logical                          :: line     !< Outlines.
   type(point_reader)               :: rd1, rd2 !< The getters' points, a block at a time.

   if (.not. begin(label, spec, spec%fill_color, PF_MARKER_INVALID, ctx, s)) return
   half = bar_size * 0.5_real64
   if (fits(ctx, spec)) then
      do i = 1_int32, min(g1%n, g2%n)
         call read_point(rd1, g1, i, x1, y1)
         call read_point(rd2, g2, i, x2, y2)
         if (horz) then
            y1 = y1 - half
            y2 = y2 + half
         else
            x1 = x1 - half
            x2 = x2 + half
         endif
         call pf_item_fit(x1, y1)
         call pf_item_fit(x2, y2)
      enddo
   endif
   if (g1%n > 0_int32 .and. g2%n > 0_int32) then
      line = s%line
      if (s%fill) then
         call render_bars(ctx, g1, g2, bar_size, horz, s%col_fill, -1.0_real32)
         if (line .and. s%col_fill == s%col_line) line = .false.
      endif
      if (line) call render_bars(ctx, g1, g2, bar_size, horz, s%col_line, s%weight)
   endif
   call finish()
   endsubroutine bars_ex

   subroutine render_bars(ctx, g1, g2, bar_size, horz, col, weight)
   !< `RendererBarsFillV`/`H` (`weight` < 0) or `RendererBarsLineV`/`H`: each bar at least a pixel wide, culled.
   type(plot_item_ctx), intent(in) :: ctx      !< The plot.
   type(item_series),   intent(in) :: g1, g2   !< Getters.
   real(real64),        intent(in) :: bar_size !< Width (height).
   logical,             intent(in) :: horz     !< Horizontal.
   integer(int32),      intent(in) :: col      !< Colour.
   real(real32),        intent(in) :: weight   !< Outline weight (< 0: fill).
   real(real64)                    :: half, x1, y1, x2, y2 !< Half size, ends.
   real(real32)                    :: p1(2), p2(2), pmin(2), pmax(2), wpx !< Pixels, the bar's size.
   real(real32)                    :: uv(2)    !< White pixel.
   type(prim_run)                  :: r        !< The run.
   type(point_reader)              :: rd1, rd2 !< The getters' points, a block at a time.
   integer(int32)                  :: i, a, i0, nprim, cnt !< Bar, the sized coordinate, run's start, bars left, run.

   half = bar_size / 2.0_real64
   a = merge(2_int32, 1_int32, horz)
   uv = real(uv_white, real32)
   nprim = min(g1%n, g2%n)
   if (weight < 0.0_real32) then
      call run_begin(r, 4_int32, 6_int32)
   else
      call run_begin(r, 8_int32, 24_int32)
   endif
   i0 = 0_int32
   do while (nprim > 0_int32)
   call run_next(r, nprim, cnt)
   do i = i0 + 1_int32, i0 + cnt
      call read_point(rd1, g1, i, x1, y1)
      call read_point(rd2, g2, i, x2, y2)
      if (horz) then
         y1 = y1 + half
         y2 = y2 - half
      else
         x1 = x1 + half
         x2 = x2 - half
      endif
      p1(1) = map_pixel(ctx%tx, x1)
      p1(2) = map_pixel(ctx%ty, y1)
      p2(1) = map_pixel(ctx%tx, x2)
      p2(2) = map_pixel(ctx%ty, y2)
      wpx = abs(p1(a) - p2(a))
      if (wpx < 1.0_real32) then ! (P2's test sees P1 moved, as ImPlot's)
         if (p1(a) > p2(a)) then
            p1(a) = p1(a) + (1.0_real32 - wpx) / 2.0_real32
         else
            p1(a) = p1(a) + (wpx - 1.0_real32) / 2.0_real32
         endif
         if (p2(a) > p1(a)) then
            p2(a) = p2(a) + (1.0_real32 - wpx) / 2.0_real32
         else
            p2(a) = p2(a) + (wpx - 1.0_real32) / 2.0_real32
         endif
      endif
      pmin(1) = im_min(p1(1), p2(1))
      pmin(2) = im_min(p1(2), p2(2))
      pmax(1) = im_max(p1(1), p2(1))
      pmax(2) = im_max(p1(2), p2(2))
      if (.not. overlaps(ctx%rect, pmin(1), pmin(2), pmax(1), pmax(2))) then
         r%culled = r%culled + 1_int32
         cycle
      endif
      if (weight < 0.0_real32) then
         call put_rect_fill(r, pmin(1), pmin(2), pmax(1), pmax(2), col, uv)
      else
         call put_rect_line(r, pmin, pmax, weight, col, uv)
      endif
   enddo
   i0 = i0 + cnt
   enddo
   call run_end(r)
   endsubroutine render_bars

   subroutine stack_room(ng)
   !< Room for a stacked bar group's four columns of `ng` (TempDouble1), kept between frames.
   integer(int32), intent(in) :: ng !< Groups.

   if (allocated(stack_tmp)) then
      if (size(stack_tmp) < 4_int32 * ng) deallocate(stack_tmp)
   endif
   if (.not. allocated(stack_tmp)) allocate(stack_tmp(max(4_int32 * ng, 64_int32)))
   endsubroutine stack_room

   subroutine stacked_views(g1, g2, ng, ib, sh, horz)
   !< A stacked item's getters: (lin, curr_min), (lin, curr_max) (horizontal: (curr_min, lin), (curr_max, lin)).
   type(item_series), intent(out) :: g1, g2 !< Getters.
   integer(int32),    intent(in)  :: ng     !< Groups.
   integer(int32),    intent(in)  :: ib     !< curr_min's start - 1 in `stack_tmp` (curr_max follows).
   real(real64),      intent(in)  :: sh     !< Shift.
   logical,           intent(in)  :: horz   !< Horizontal.
   integer(int32)                 :: kv, kl !< The values' coordinate, the positions'.

   kv = merge(1_int32, 2_int32, horz)
   kl = 3_int32 - kv
   call view_r64(g1, kv, stack_tmp(ib + 1_int32:ib + ng))
   call view_r64(g2, kv, stack_tmp(ib + ng + 1_int32:ib + 2_int32 * ng))
   call view_lin(g1, kl, sh, 1.0_real64)
   call view_lin(g2, kl, sh, 1.0_real64)
   g1%n = ng
   g2%n = ng
   endsubroutine stacked_views

   subroutine error_bars_item(label, g, e, spec, horizontal)
   !< `PlotErrorBarsVEx`/`HEx`: `Fitter2` of the bars' ends, each bar `AddLine` from (y - neg) to (y + pos) and its
   !< whiskers (`AddLineH`/`V`, `Size` wide) in the style's text colour unless a line colour is given; not culled.
   character(len=*),     intent(in)           :: label      !< Label.
   type(item_series),    intent(in)           :: g, e       !< Getters: the points, the errors (neg, pos).
   type(plot_item_spec), intent(in)           :: spec       !< Style.
   logical,              intent(in), optional :: horizontal !< Along x.
   type(plot_item_ctx)                        :: ctx        !< The plot.
   type(item_style)                           :: s          !< Staged style.
   real(real64)                               :: ax, ay, bx, by !< The bar's ends.
   real(real32)                               :: p1(2), p2(2), hw !< Pixels, half whisker.
   integer(int32)                             :: i, col, pass !< Bar, colour, fit pass.
   logical                                    :: horz   !< Along x.
   real(real32)                               :: auto_col(4) !< IMPLOT_AUTO_COL.
   type(point_reader)                         :: rg, re !< The points and the errors, a block at a time.

   horz = iand(spec%flags, PF_ERROR_BARS_HORIZONTAL) /= 0_int32
   if (present(horizontal)) horz = horz .or. horizontal
   auto_col = [0.0_real32, 0.0_real32, 0.0_real32, AUTO_ALPHA]
   if (.not. begin(label, spec, auto_col, PF_MARKER_INVALID, ctx, s)) return
   if (fits(ctx, spec)) then ! Fitter2: the positive ends, then the negative ones
      do pass = 1_int32, 2_int32
         do i = 1_int32, g%n
            call error_ends(rg, re, g, e, i, horz, ax, ay, bx, by)
            if (pass == 1_int32) then
               call pf_item_fit(bx, by)
            else
               call pf_item_fit(ax, ay)
            endif
         enddo
      enddo
   endif
   if (g%n > 0_int32) then
      if (is_auto(spec%line_color)) then
         col = core_style_color(ImGuiCol_Text)
      else
         col = s%col_line
      endif
      hw = s%size * 0.5_real32
      do i = 1_int32, g%n
         call error_ends(rg, re, g, e, i, horz, ax, ay, bx, by)
         p1 = [map_pixel(ctx%tx, ax), map_pixel(ctx%ty, ay)]
         p2 = [map_pixel(ctx%tx, bx), map_pixel(ctx%ty, by)]
         call core_draw_line(real(p1(1), real64), real(p1(2), real64), real(p2(1), real64), real(p2(2), real64), &
                             col, real(s%weight, real64))
         if (s%size > 0.0_real32) then
            if (horz) then
               call core_draw_line_v(real(p1(1), real64), real(p1(2) - hw, real64), real(p1(2) + hw, real64), col, &
                                     real(s%weight, real64))
               call core_draw_line_v(real(p2(1), real64), real(p2(2) - hw, real64), real(p2(2) + hw, real64), col, &
                                     real(s%weight, real64))
            else
               call core_draw_line_h(real(p1(1) - hw, real64), real(p1(1) + hw, real64), real(p1(2), real64), col, &
                                     real(s%weight, real64))
               call core_draw_line_h(real(p2(1) - hw, real64), real(p2(1) + hw, real64), real(p2(2), real64), col, &
                                     real(s%weight, real64))
            endif
         endif
      enddo
   endif
   call finish()
   endsubroutine error_bars_item

   subroutine error_ends(rg, re, g, e, i, horz, ax, ay, bx, by)
   !< An error bar's ends: (x, y - neg) and (x, y + pos) (`IndexerAdd`: 1 y + (-1) neg, 1 y + 1 pos); along x the same
   !< on x.
   type(point_reader), intent(inout) :: rg, re !< Their readers.
   type(item_series), intent(in)  :: g, e   !< Getters.
   integer(int32),    intent(in)  :: i      !< Bar.
   logical,           intent(in)  :: horz   !< Along x.
   real(real64),      intent(out) :: ax, ay !< The negative end.
   real(real64),      intent(out) :: bx, by !< The positive end.
   real(real64)                   :: x, y, en, ep !< The point, its errors.

   call read_point(rg, g, i, x, y)
   call read_point(re, e, i, en, ep)
   if (horz) then
      ax = x - en
      bx = x + ep
      ay = y
      by = y
   else
      ax = x
      bx = x
      ay = y - en
      by = y + ep
   endif
   endsubroutine error_ends

   subroutine inf_lines_item(label, g, k, spec)
   !< `PlotInfLines`: `FitterX` (`FitterY`) of the positions, a segment across the current range at each
   !< (`RendererLineSegments2`).
   character(len=*),     intent(in)    :: label !< Label.
   type(item_series),    intent(inout) :: g     !< Getter: the positions in coordinate k.
   integer(int32),       intent(in)    :: k     !< 1 vertical lines (x), 2 horizontal (y).
   type(plot_item_spec), intent(in)    :: spec  !< Style.
   type(plot_item_ctx)                 :: ctx   !< The plot.
   type(item_style)                    :: s     !< Staged style.
   type(item_series)                   :: g2    !< The lines' other ends.
   real(real64)                        :: x, y  !< A point.
   integer(int32)                      :: i     !< Line.

   if (.not. begin(label, spec, spec%line_color, PF_MARKER_INVALID, ctx, s)) return
   g%src(3_int32 - k) = SRC_CONST ! GetPlotLimits: the current axes' ranges
   g2 = g
   if (k == 1_int32) then
      g%con(2) = ctx%y_range(1)
      g2%con(2) = ctx%y_range(2)
   else
      g%con(1) = ctx%x_range(1)
      g2%con(1) = ctx%x_range(2)
   endif
   if (fits(ctx, spec)) then
      do i = 1_int32, g%n
         call point(g, i, x, y)
         if (k == 1_int32) then
            call pf_item_fit_axis(x, .false.)
         else
            call pf_item_fit_axis(y, .true.)
         endif
      enddo
   endif
   if (g%n > 0_int32 .and. s%line) call render_segments2(ctx, g, g2, s%col_line, s%weight)
   call finish()
   endsubroutine inf_lines_item

   ! pie charts, bubbles, digital signals, text (PlotPieChart, PlotBubbles, PlotDigital, PlotText)

   subroutine pie_chart_r64(labels, values, x, y, radius, label_format, angle0, normalize, colormap, spec)
   !< A pie chart (`PlotPieChart`), double precision: `ip_pie_chart`.
   character(len=*),     intent(in)           :: labels(:)    !< One label per slice (trailing blanks dropped).
   real(real64),         intent(in), target, asynchronous :: values(:)    !< Slice values.
   real(real64),         intent(in)           :: x, y         !< Centre [plot units].
   real(real64),         intent(in)           :: radius       !< Radius [plot units].
   character(len=*),     intent(in), optional :: label_format !< printf format of a value (default '%.1f'; '': none).
   real(real64),         intent(in), optional :: angle0       !< The first slice's start [degrees] (default 90).
   logical,              intent(in), optional :: normalize    !< Always a full circle.
   integer(int32),       intent(in), optional :: colormap     !< The slices' colours.
   type(plot_item_spec), intent(in), optional :: spec         !< Style (its flags).
   type(item_series)                          :: g            !< The values (coordinate 2).

   call view_r64(g, 2_int32, values)
   g%n = int(size(values), int32)
   call pie_item(labels, g, x, y, radius, label_format, angle0, normalize, colormap, spec_or_default(spec))
   endsubroutine pie_chart_r64

   subroutine pie_chart_r32(labels, values, x, y, radius, label_format, angle0, normalize, colormap, spec)
   !< A pie chart (`PlotPieChart`), single precision values: `ip_pie_chart`.
   character(len=*),     intent(in)           :: labels(:)    !< One label per slice (trailing blanks dropped).
   real(real32),         intent(in), target, asynchronous :: values(:)    !< Slice values.
   real(real64),         intent(in)           :: x, y         !< Centre [plot units].
   real(real64),         intent(in)           :: radius       !< Radius [plot units].
   character(len=*),     intent(in), optional :: label_format !< printf format of a value (default '%.1f'; '': none).
   real(real64),         intent(in), optional :: angle0       !< The first slice's start [degrees] (default 90).
   logical,              intent(in), optional :: normalize    !< Always a full circle.
   integer(int32),       intent(in), optional :: colormap     !< The slices' colours.
   type(plot_item_spec), intent(in), optional :: spec         !< Style (its flags).
   type(item_series)                          :: g            !< The values (coordinate 2).

   call view_r32(g, 2_int32, values)
   g%n = int(size(values), int32)
   call pie_item(labels, g, x, y, radius, label_format, angle0, normalize, colormap, spec_or_default(spec))
   endsubroutine pie_chart_r32

   subroutine bubbles_r64(label, x, y, radii, spec)
   !< Circles at (x(i), y(i)) of radius radii(i) [plot units] (`PlotBubbles`), double precision, read in place.
   character(len=*),     intent(in)           :: label    !< Legend label.
   real(real64),         intent(in), target, asynchronous :: x(:)     !< Abscissae.
   real(real64),         intent(in), target, asynchronous :: y(:)     !< Ordinates.
   real(real64),         intent(in), target, asynchronous :: radii(:) !< Radii.
   type(plot_item_spec), intent(in), optional :: spec     !< Style.
   type(item_series)                          :: g, r     !< Getters: the centres, the radii (coordinate 2).

   call view_r64(g, 1_int32, x)
   call view_r64(g, 2_int32, y)
   call view_r64(r, 2_int32, radii)
   g%n = int(min(size(x), size(y), size(radii)), int32)
   r%n = g%n
   call bubbles_item(label, g, r, spec_or_default(spec))
   endsubroutine bubbles_r64

   subroutine bubbles_r32(label, x, y, radii, spec)
   !< Circles at (x(i), y(i)) of radius radii(i) [plot units] (`PlotBubbles`), single precision, read in place.
   character(len=*),     intent(in)           :: label    !< Legend label.
   real(real32),         intent(in), target, asynchronous :: x(:)     !< Abscissae.
   real(real32),         intent(in), target, asynchronous :: y(:)     !< Ordinates.
   real(real32),         intent(in), target, asynchronous :: radii(:) !< Radii.
   type(plot_item_spec), intent(in), optional :: spec     !< Style.
   type(item_series)                          :: g, r     !< Getters: the centres, the radii (coordinate 2).

   call view_r32(g, 1_int32, x)
   call view_r32(g, 2_int32, y)
   call view_r32(r, 2_int32, radii)
   g%n = int(min(size(x), size(y), size(radii)), int32)
   r%n = g%n
   call bubbles_item(label, g, r, spec_or_default(spec))
   endsubroutine bubbles_r32

   subroutine digital_r64(label, x, y, spec)
   !< A digital signal (`PlotDigital`), double precision, read in place: `ip_digital`.
   character(len=*),     intent(in)           :: label !< Legend label.
   real(real64),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),         intent(in), target, asynchronous :: y(:)  !< Values.
   type(plot_item_spec), intent(in), optional :: spec  !< Style (`size`: the band's height [pixels]).
   type(item_series)                          :: g     !< Getter.

   call view_r64(g, 1_int32, x)
   call view_r64(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call digital_item(label, g, spec_or_default(spec))
   endsubroutine digital_r64

   subroutine digital_r32(label, x, y, spec)
   !< A digital signal (`PlotDigital`), single precision, read in place: `ip_digital`.
   character(len=*),     intent(in)           :: label !< Legend label.
   real(real32),         intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),         intent(in), target, asynchronous :: y(:)  !< Values.
   type(plot_item_spec), intent(in), optional :: spec  !< Style (`size`: the band's height [pixels]).
   type(item_series)                          :: g     !< Getter.

   call view_r32(g, 1_int32, x)
   call view_r32(g, 2_int32, y)
   g%n = int(min(size(x), size(y)), int32)
   call digital_item(label, g, spec_or_default(spec))
   endsubroutine digital_r32

   subroutine pf_text(text, x, y, offset, vertical)
   !< A text centred on the plot point (x, y) (`PlotText`; `ip_text`): the inlay text colour, clipped to the plot,
   !< `offset` [pixels] (x right, y down), `vertical` written bottom to top; not an item: no legend entry, it fits.
   character(len=*), intent(in)           :: text      !< Text (UTF-8).
   real(real64),     intent(in)           :: x, y      !< Point [plot units].
   real(real64),     intent(in), optional :: offset(2) !< Offset [pixels].
   logical,          intent(in), optional :: vertical  !< Bottom to top.
   type(plot_item_ctx)                    :: ctx       !< The plot.
   real(real32)                           :: off(2), siz(2), ctr(2), pos(2) !< Offset, size, half size, corner.
   real(real64)                           :: w, h, px, py !< Text size, a plot point.
   integer(int32)                         :: col       !< Colour.
   logical                                :: vert      !< Vertical.

   vert = .false.
   if (present(vertical)) vert = vertical
   off = 0.0_real32
   if (present(offset)) off = real(offset, real32)
   call pf_plot_ctx(ctx) ! SetupLock
   call core_push_clip_rect(real(ctx%rect(1), real64), real(ctx%rect(2), real64), real(ctx%rect(3), real64), &
                            real(ctx%rect(4), real64))
   col = ps_u32(PC_INLAY_TEXT) ! GetStyleColorU32(ImPlotCol_InlayText): the style's Alpha not applied
   call core_text_size(text, w, h)
   if (vert) then ! CalcTextSizeVertical(text) * 0.5, the centre half that
      siz = [real(h, real32) * 0.5_real32, real(w, real32) * 0.5_real32]
      ctr = siz * 0.5_real32
      pos(1) = map_pixel(ctx%tx, x) + (-ctr(1))
      pos(2) = map_pixel(ctx%ty, y) + ctr(2)
      pos = pos + off
      if (ctx%fit) then
         call pf_pixels_to_plot(real(pos(1), real64), real(pos(2), real64), px, py)
         call pf_item_fit(px, py)
         call pf_pixels_to_plot(real(pos(1) + siz(1), real64), real(pos(2) - siz(2), real64), px, py)
         call pf_item_fit(px, py)
      endif
      call pf_text_vertical(pos(1), pos(2), col, text)
   else
      siz = [real(w, real32), real(h, real32)]
      ctr = siz * 0.5_real32
      pos(1) = map_pixel(ctx%tx, x) - ctr(1)
      pos(2) = map_pixel(ctx%ty, y) - ctr(2)
      pos = pos + off
      if (ctx%fit) then
         call pf_pixels_to_plot(real(pos(1), real64), real(pos(2), real64), px, py)
         call pf_item_fit(px, py)
         call pf_pixels_to_plot(real(pos(1) + siz(1), real64), real(pos(2) + siz(2), real64), px, py)
         call pf_item_fit(px, py)
      endif
      call core_draw_text(real(pos(1), real64), real(pos(2), real64), col, text)
   endif
   call core_pop_clip_rect()
   endsubroutine pf_text

   subroutine pie_item(labels, g, x, y, radius, label_format, angle0, normalize, colormap, spec)
   !< `PlotPieChart`: the sum (of the shown items with `IgnoreHidden`), the slices (`PlotPieChartEx`: an item each,
   !< `FitterRect` of the pie's square, a fan and its anti-aliased border; two halves for a slice of half or more;
   !< `Exploding`: a hovered entry's slice detached), then the labels (the value through the format, centred at half
   !< the radius, black or white on the slice's colour).
   character(len=*),     intent(in)           :: labels(:)    !< Labels.
   type(item_series),    intent(in)           :: g            !< The values (coordinate 2).
   real(real64),         intent(in)           :: x, y         !< Centre.
   real(real64),         intent(in)           :: radius       !< Radius.
   character(len=*),     intent(in), optional :: label_format !< Format.
   real(real64),         intent(in), optional :: angle0       !< Start [degrees].
   logical,              intent(in), optional :: normalize    !< Full circle.
   integer(int32),       intent(in), optional :: colormap     !< Colours.
   type(plot_item_spec), intent(in)           :: spec         !< Style.
   type(plot_item_spec)                       :: sp           !< The slices' spec (Normalize set).
   type(plot_item_ctx)                        :: ctx          !< The plot.
   type(item_style)                           :: s            !< Staged style.
   type(plot_format)                          :: fm           !< The labels' format.
   character(len=31)                          :: lab          !< A label (ImPlot's 32-byte buffer).
   real(real64)                               :: sum_, percent, a0, a1, ang, off, w, h, v, t, u !< Angles, sizes.
   real(real32)                               :: pos(2), tsz(2), c4(4) !< A label's place, size; a colour.
   integer(int32)                             :: i, jl, nl, col !< Slice, lengths, colour.
   logical                                    :: ignore, norm, skip, hov, found, shown, labelled !< Flags.

   sp = spec
   if (present(normalize)) then
      if (normalize) sp%flags = ior(sp%flags, PF_PIE_NORMALIZE)
   endif
   if (present(colormap)) call cm_push(colormap)
   call pf_plot_ctx(ctx)
   call core_push_clip_rect(real(ctx%rect(1), real64), real(ctx%rect(2), real64), real(ctx%rect(3), real64), &
                            real(ctx%rect(4), real64))
   ignore = iand(sp%flags, PF_PIE_IGNORE_HIDDEN) /= 0_int32
   sum_ = pie_sum(g, ignore)
   norm = iand(sp%flags, PF_PIE_NORMALIZE) /= 0_int32 .or. sum_ > 1.0_real64
   ! PlotPieChartEx
   a0 = start_angle(angle0)
   a1 = a0
   do i = 1_int32, g%n
      jl = len_trim(labels(i), kind=int32)
      call pf_item_state(labels(i)(1:jl), found, shown, col)
      v = coordinate(g, 2_int32, int(i, int64))
      percent = v
      if (norm) percent = v / sum_
      skip = sum_ <= 0.0_real64 .or. (ignore .and. found .and. .not. shown)
      if (.not. skip) then
         t = real(2.0_real32 * IM_PI, real64) * percent ! (2 * IM_PI a float, then times the double)
         a1 = a0 + t
      endif
      if (begin(labels(i)(1:jl), sp, [0.0_real32, 0.0_real32, 0.0_real32, AUTO_ALPHA], PF_MARKER_INVALID, ctx, s)) then
         if (fits(ctx, sp)) then ! FitterRect
            call pf_item_fit(x - radius, y - radius)
            call pf_item_fit(x + radius, y + radius)
         endif
         hov = pf_legend_hovered(labels(i)(1:jl)) .and. iand(sp%flags, PF_PIE_EXPLODING) /= 0_int32
         if (sum_ > 0.0_real64) then
            if (percent < 0.5_real64) then
               call pie_slice(ctx, x, y, radius, a0, a1, ctx%color, sp%flags, hov)
            else
               t = (a1 - a0) * 0.5_real64
               u = a0 + t
               call pie_slice(ctx, x, y, radius, a0, u, ctx%color, sp%flags, hov)
               call pie_slice(ctx, x, y, radius, u, a1, ctx%color, sp%flags, hov)
            endif
         endif
         call finish()
      endif
      if (.not. skip) a0 = a1
   enddo
   ! the labels
   labelled = .true.
   if (present(label_format)) labelled = len(label_format) > 0
   if (labelled) then
      if (present(label_format)) then
         call fmt_parse(label_format, fm)
      else
         call fmt_parse('%.1f', fm)
      endif
      a0 = start_angle(angle0)
      a1 = a0
      do i = 1_int32, g%n
         jl = len_trim(labels(i), kind=int32)
         call pf_item_state(labels(i)(1:jl), found, shown, col)
         v = coordinate(g, 2_int32, int(i, int64))
         percent = v
         if (norm) percent = v / sum_
         skip = ignore .and. found .and. .not. shown
         if (skip) cycle
         t = real(2.0_real32 * IM_PI, real64) * percent
         a1 = a0 + t
         if (shown) then
            nl = 0_int32
            call fmt_real(lab, nl, fm, v)
            call core_text_size(lab(1:nl), w, h)
            tsz = [real(w, real32), real(h, real32)]
            t = (a1 - a0) * 0.5_real64
            ang = a0 + t
            hov = pf_legend_hovered(labels(i)(1:jl)) .and. iand(sp%flags, PF_PIE_EXPLODING) /= 0_int32
            off = merge(0.6_real64, 0.5_real64, hov) * radius
            t = off * c_cos(ang)
            u = off * c_sin(ang)
            pos(1) = map_pixel(ctx%tx, x + t)
            pos(2) = map_pixel(ctx%ty, y + u)
            c4 = unpack_u32(col) ! the item's colour
            col = text_on(c4)
            tsz = tsz * 0.5_real32
            call core_draw_text(real(pos(1) - tsz(1), real64), real(pos(2) - tsz(2), real64), col, lab(1:nl))
         endif
         a0 = a1
      enddo
   endif
   call core_pop_clip_rect()
   if (present(colormap)) call cm_pop()
   endsubroutine pie_item

   pure function start_angle(angle0) result(a)
   !< `angle0 * 2 * IM_PI / 360.0` (IM_PI the float; default 90 degrees).
   real(real64), intent(in), optional :: angle0 !< Degrees.
   real(real64)                       :: a      !< Radians.

   a = 90.0_real64
   if (present(angle0)) a = angle0
   a = a * 2.0_real64
   a = a * real(IM_PI, real64)
   a = a / 360.0_real64
   endfunction start_angle

   function pie_sum(g, ignore_hidden) result(total)
   !< `PieChartSum`: the values' sum; with `IgnoreHidden`, of those whose item (by index in the plot's items, as
   !< ImPlot's `GetItemByIndex`) is shown.
   type(item_series), intent(in) :: g             !< Values.
   logical,           intent(in) :: ignore_hidden !< IgnoreHidden.
   real(real64)                  :: total         !< Sum.
   integer(int32)                :: i             !< Value.

   total = 0.0_real64
   do i = 1_int32, g%n
      if (ignore_hidden) then
         if (i > pf_item_count()) exit
         if (.not. pf_item_shown_at(i - 1_int32)) cycle
      endif
      total = total + coordinate(g, 2_int32, int(i, int64))
   enddo
   endfunction pie_sum

   subroutine pie_slice(ctx, cx, cy, radius, a0, a1, col, flags, detached)
   !< `RenderPieSlice`: the centre and n points of the arc (n from the arc's length, 50 a turn, 3 at least), closed on
   !< the centre; the fan (`PrimPieSliceFill`) and, unless `NoSliceBorder`, its border (`PrimPieSliceLine`, 2 pixels,
   !< anti-aliased); detached: 0.08 away along the middle angle, 0.95 of the width, the radius + 0.04.
   type(plot_item_ctx), intent(in) :: ctx      !< The plot.
   real(real64),        intent(in) :: cx, cy   !< Centre.
   real(real64),        intent(in) :: radius   !< Radius.
   real(real64),        intent(in) :: a0, a1   !< Angles.
   integer(int32),      intent(in) :: col      !< Colour.
   integer(int32),      intent(in) :: flags    !< Flags.
   logical,             intent(in) :: detached !< Exploded.
   real(real32), parameter         :: RESOLUTION = 50.0_real32 / (2.0_real32 * IM_PI) !< Points a radian (a float).
   real(real32)                    :: b(2, 52), hw !< The points [pixels], half weight.
   real(real32)                    :: bx(52), by(52) !< ... the border's (`put_lines`).
   real(real64)                    :: da, a, ox, oy, r, mid, na0, na1, t, u !< Angles, centre, radius.
   real(real32)                    :: uv0(2), uv1(2), uv(2) !< Texture, white pixel.
   type(prim_run)                  :: run       !< The slice's reservations (`PrimReserve`, no culling).
   integer(int32)                  :: n, i, k   !< Points, counters.

   t = (a1 - a0) * real(RESOLUTION, real64)
   n = max(3_int32, int(t, int32))
   ox = cx
   oy = cy
   r = radius
   if (detached) then
      mid = (a0 + a1) / 2.0_real64
      t = (a1 - a0) * 0.95_real64
      t = t / 2.0_real64
      na0 = mid - t
      na1 = mid + t
      t = 0.08_real64 * c_cos(mid)
      ox = cx + t
      t = 0.08_real64 * c_sin(mid)
      oy = cy + t
      r = radius + 0.08_real64 / 2.0_real64
   else
      na0 = a0
      na1 = a1
   endif
   da = (na1 - na0) / real(n - 1_int32, real64)
   b(1, 1) = map_pixel(ctx%tx, ox)
   b(2, 1) = map_pixel(ctx%ty, oy)
   do i = 0_int32, n - 1_int32
      t = real(i, real64) * da
      a = na0 + t
      t = r * c_cos(a)
      u = r * c_sin(a)
      b(1, i + 2_int32) = map_pixel(ctx%tx, ox + t)
      b(2, i + 2_int32) = map_pixel(ctx%ty, oy + u)
   enddo
   b(:, n + 2_int32) = b(:, 1)
   uv = real(uv_white, real32)
   call run_begin(run, n + 2_int32, n * 3_int32) ! RenderPieSliceFill: PrimReserve((count - 2) * 3, count)
   call run_reserve(run)
   call put_fan(run, b, n + 2_int32, col, uv)
   if (iand(flags, PF_PIE_NO_SLICE_BORDER) == 0_int32) then ! RenderPieSliceLine
      call line_props32(2.0_real32, hw, uv0, uv1) ! GetLineRenderProps of half weight 1
      call run_begin(run, (n + 1_int32) * 4_int32, (n + 1_int32) * 6_int32)
      call run_reserve(run)
      do k = 1_int32, n + 2_int32
         bx(k) = b(1, k)
         by(k) = b(2, k)
      enddo
      call put_lines(run, run%vb, run%ib, n + 1_int32, bx, by, bx(2:), by(2:), hw, col, uv0, uv1)
   endif
   endsubroutine pie_slice

   subroutine bubbles_item(label, g, r, spec)
   !< `PlotBubblesEx`: `FitterBubbles1` (each centre +- its radius on both axes), the filled circles
   !< (`RendererCircleFill`), their outlines (`RendererCircleLine`); 10 to 64 segments from the radius in x pixels, the
   !< angles and their sines and cosines in float (`ImCos`, `ImSin`), each circle culled by its box.
   character(len=*),     intent(in) :: label !< Label.
   type(item_series),    intent(in) :: g, r  !< Getters: centres, radii.
   type(plot_item_spec), intent(in) :: spec  !< Style.
   type(plot_item_ctx)              :: ctx   !< The plot.
   type(item_style)                 :: s     !< Staged style.
   real(real64)                     :: x, y, rad, dummy !< A bubble.
   integer(int32)                   :: i     !< Bubble.
   type(point_reader)               :: rd, rr !< Centres and radii, a block at a time.

   if (.not. begin(label, spec, spec%fill_color, spec%marker, ctx, s)) return
   if (fits(ctx, spec)) then
      do i = 1_int32, g%n
         call read_point(rd, g, i, x, y)
         call read_point(rr, r, i, dummy, rad)
         call pf_item_fit_with(x - rad, y, .false.)
         call pf_item_fit_with(x + rad, y, .false.)
         call pf_item_fit_with(y - rad, x, .true.)
         call pf_item_fit_with(y + rad, x, .true.)
      enddo
   endif
   if (g%n > 0_int32) then
      if (s%fill) call render_circles(ctx, g, r, s%col_fill, -1.0_real32)
      if (s%line) call render_circles(ctx, g, r, s%col_line, s%weight)
   endif
   call finish()
   endsubroutine bubbles_item

   subroutine render_circles(ctx, g, r, col, weight)
   !< `RendererCircleFill` (`weight` < 0: a fan of the circle's points) or `RendererCircleLine` (its segments).
   type(plot_item_ctx), intent(in) :: ctx    !< The plot.
   type(item_series),   intent(in) :: g, r   !< Getters.
   integer(int32),      intent(in) :: col    !< Colour.
   real(real32),        intent(in) :: weight !< Line weight (< 0: fill).
   real(real32)                    :: v(2, 64), p1(2), p2(2), pmin(2), pmax(2), rad, ar, a_step, ang, cs, sn, hw !<
                                       !< Points, box, radius, angles.
   real(real32)                    :: vx(65), vy(65) !< The points, the first again at the end (`put_lines`).
   real(real32)                    :: uv0(2), uv1(2), uv(2) !< Texture, white pixel.
   real(real64)                    :: x, y, dummy, t !< A bubble.
   type(prim_run)                  :: run       !< The run.
   type(point_reader)              :: rd, rr    !< Centres and radii, a block at a time.
   integer(int32)                  :: i, k, ns, i0, nprim, cnt !< Bubble, point, segments, run's start, bubbles left,
                                                               !< run.

   uv = real(uv_white, real32)
   if (weight >= 0.0_real32) then
      call line_props32(weight, hw, uv0, uv1)
      call run_begin(run, 64_int32 * 4_int32, 64_int32 * 6_int32) ! RendererCircleLine
   else
      call run_begin(run, 64_int32, 62_int32 * 3_int32) ! RendererCircleFill
   endif
   nprim = g%n
   i0 = 0_int32
   do while (nprim > 0_int32)
   call run_next(run, nprim, cnt)
   do i = i0 + 1_int32, i0 + cnt
      call read_point(rd, g, i, x, y)
      call read_point(rr, r, i, dummy, t)
      rad = real(t, real32)
      ar = real(abs(real(rad, real64) * ctx%tx%m), real32)
      ns = min(max(int(ar, int32), 10_int32), 64_int32)
      p1(1) = map_pixel(ctx%tx, x - real(rad, real64))
      p1(2) = map_pixel(ctx%ty, y - real(rad, real64))
      p2(1) = map_pixel(ctx%tx, x + real(rad, real64))
      p2(2) = map_pixel(ctx%ty, y + real(rad, real64))
      pmin(1) = im_min(p1(1), p2(1))
      pmin(2) = im_min(p1(2), p2(2))
      pmax(1) = im_max(p1(1), p2(1))
      pmax(2) = im_max(p1(2), p2(2))
      if (.not. overlaps(ctx%rect, pmin(1), pmin(2), pmax(1), pmax(2))) then
         run%culled = run%culled + 1_int32
         cycle
      endif
      a_step = (IM_PI * 2.0_real32) / real(ns, real32)
      do k = 0_int32, ns - 1_int32
         ang = a_step * real(k, real32)
         cs = c_cosf(ang) * rad ! (float products, then the double sums: as ImPlot's)
         sn = c_sinf(ang) * rad
         v(1, k + 1_int32) = map_pixel(ctx%tx, x + real(cs, real64))
         v(2, k + 1_int32) = map_pixel(ctx%ty, y + real(sn, real64))
      enddo
      if (weight < 0.0_real32) then
         call put_fan(run, v, ns, col, uv)
         if (ns < 64_int32) call core_run_unreserve(64_int32 - ns, (62_int32 - (ns - 2_int32)) * 3_int32) ! the unused
      else
         do k = 1_int32, ns
            vx(k) = v(1, k)
            vy(k) = v(2, k)
         enddo
         vx(ns + 1_int32) = v(1, 1)
         vy(ns + 1_int32) = v(2, 1)
         call put_lines(run, run%vb, run%ib, ns, vx, vy, vx(2:), vy(2:), hw, col, uv0, uv1)
         if (ns < 64_int32) call core_run_unreserve((64_int32 - ns) * 4_int32, (64_int32 - ns) * 6_int32)
      endif
   enddo
   i0 = i0 + cnt
   enddo
   call run_end(run)
   endsubroutine render_circles

   subroutine digital_item(label, g, spec)
   !< `PlotDigitalEx` (FIGURE's patched copy): in a band at the bottom of the plot (above the bands of the digital items
   !< before it on this plot), a rectangle per run of equal values, its height `Size` times the value (at least
   !< `Size`), clamped to the x axis's pixels; no fit (`BeginItem`, no fitter).
   character(len=*),     intent(in) :: label !< Label.
   type(item_series),    intent(in) :: g     !< Getter.
   type(plot_item_spec), intent(in) :: spec  !< Style.
   type(plot_item_ctx)              :: ctx   !< The plot.
   type(item_style)                 :: s     !< Staged style.
   real(real64)                     :: x1, y1, x2, y2, xn, yn !< Points.
   real(real32)                     :: pmin(2), pmax(2), pix1, y_ref, lo, hi, base !< Pixels.
   integer(int32)                   :: i, pix0, choff, pixmax, poff !< Point, pixel sizes.
   type(point_reader)               :: rd    !< The points, a block at a time.

   if (.not. begin(label, spec, spec%fill_color, PF_MARKER_INVALID, ctx, s)) return
   if (g%n > 1_int32 .and. s%fill) then
      pixmax = 0_int32
      call read_point(rd, g, 1_int32, x1, y1)
      base = real(pf_digital_offset(0_int32), real32)
      i = 1_int32
      do while (i <= g%n)
         call read_point(rd, g, i, x2, y2)
         if (.not. (abs(y1) <= huge(1.0_real64))) then ! ImNanOrInf
            x1 = x2
            y1 = y2
            i = i + 1_int32
            cycle
         endif
         if (.not. (abs(y2) <= huge(1.0_real64))) y2 = constrain_nan_inf(y2)
         pix0 = int(s%weight, int32)
         y1 = max(0.0_real64, y1) ! ImMax(0.0, y1)
         pix1 = s%size * real(y1, real32)
         choff = int(max(s%size, pix1) + DIGITAL_SPACING, int32)
         pixmax = max(pixmax, choff)
         pmin(1) = map_pixel(ctx%tx, x1)
         pmax(1) = map_pixel(ctx%tx, x2)
         poff = int(DIGITAL_PADDING, int32)
         y_ref = merge(ctx%y_pix(2), ctx%y_pix(1), ctx%y_inv)
         pmin(2) = y_ref - (base + real(poff, real32))
         pmax(2) = y_ref - (base + real(pix0 + int(pix1, int32) + poff, real32))
         do while (i + 2_int32 <= g%n .and. y1 == y2) ! one rectangle a run of equal values
            call read_point(rd, g, i + 1_int32, xn, yn)
            x2 = xn
            y2 = yn
            if (.not. (abs(yn) <= huge(1.0_real64))) exit
            pmax(1) = map_pixel(ctx%tx, xn)
            i = i + 1_int32
         enddo
         lo = merge(ctx%x_pix(2), ctx%x_pix(1), ctx%x_inv)
         hi = merge(ctx%x_pix(1) - 1.0_real32, ctx%x_pix(2) - 1.0_real32, ctx%x_inv)
         pmin(1) = min(max(pmin(1), lo), hi) ! ImClamp
         pmax(1) = min(max(pmax(1), lo), hi)
         if (rect_contains(ctx%rect, pmin) .or. rect_contains(ctx%rect, pmax)) & ! (FIGURE's patch: corners ordered)
            call core_draw_rect_filled(real(im_min(pmin(1), pmax(1)), real64), real(im_min(pmin(2), pmax(2)), real64), &
                                       real(im_max(pmin(1), pmax(1)), real64), real(im_max(pmin(2), pmax(2)), real64), &
                                       s%col_fill)
         x1 = x2
         y1 = y2
         i = i + 1_int32
      enddo
      base = real(pf_digital_offset(pixmax), real32)
   endif
   call finish()
   endsubroutine digital_item

   pure function rect_contains(r, p) result(yes)
   !< `ImRect::Contains(ImVec2)`: min <= p < max.
   real(real32), intent(in) :: r(4) !< Rectangle.
   real(real32), intent(in) :: p(2) !< Point.
   logical                  :: yes  !< Inside.

   yes = p(1) >= r(1) .and. p(2) >= r(2) .and. p(1) < r(3) .and. p(2) < r(4)
   endfunction rect_contains

   pure function constrain_nan_inf(v) result(c)
   !< `ImConstrainNan(ImConstrainInf(v))`: +-inf to +-DBL_MAX, NaN to 0.
   real(real64), intent(in) :: v !< Value.
   real(real64)             :: c !< Constrained.

   if (v /= v) then
      c = 0.0_real64
   elseif (v > huge(1.0_real64)) then
      c = huge(1.0_real64)
   elseif (v < -huge(1.0_real64)) then
      c = -huge(1.0_real64)
   else
      c = v
   endif
   endfunction constrain_nan_inf

   pure function text_on(c) result(col)
   !< `CalcTextColor`: black on a light colour (luminance 0.299 r + 0.587 g + 0.114 b > 0.5, float), else white.
   real(real32), intent(in) :: c(4) !< Background.
   integer(int32)           :: col  !< IM_COL32_BLACK or IM_COL32_WHITE.
   real(real32)             :: a, b, d !< Terms.

   a = c(1) * 0.299_real32
   b = c(2) * 0.587_real32
   d = c(3) * 0.114_real32
   if ((a + b) + d > 0.5_real32) then
      col = -16777216_int32 ! 0xFF000000
   else
      col = -1_int32        ! 0xFFFFFFFF
   endif
   endfunction text_on

   ! heatmaps, histograms (PlotHeatmap, PlotHistogram, PlotHistogram2D)

   subroutine heatmap_r64(label, f, xmin, xmax, ymin, ymax, scale_min, scale_max, label_format, colormap, spec)
   !< The field f(i, j) as coloured cells (`PlotHeatmap`, as `ip_heatmap` calls it: rows size(f, 2) along y, columns
   !< size(f, 1) along x, row 1 at ymin), double precision, read in place.
   character(len=*),     intent(in)                     :: label        !< Legend label.
   real(real64),         intent(in), target, contiguous :: f(:,:)       !< Field.
   real(real64),         intent(in)                     :: xmin, xmax   !< Columns' edges.
   real(real64),         intent(in)                     :: ymin, ymax   !< Rows' edges.
   real(real64),         intent(in), optional           :: scale_min    !< Value at the map's bottom.
   real(real64),         intent(in), optional           :: scale_max    !< ... at its top (both or none: data).
   character(len=*),     intent(in), optional           :: label_format !< printf format of each cell's value.
   integer(int32),       intent(in), optional           :: colormap     !< Colormap (default Viridis).
   type(plot_item_spec), intent(in), optional           :: spec         !< Style (its flags).
   type(item_series)                                    :: g            !< The values in memory order (coordinate 2).
   real(real64), pointer                                :: v(:)         !< ... as a vector.

   v(1:size(f)) => f
   call view_r64(g, 2_int32, v)
   g%n = int(size(f), int32)
   call heatmap_item(label, g, int(size(f, 2), int32), int(size(f, 1), int32), xmin, xmax, ymin, ymax, scale_min, &
                     scale_max, label_format, colormap, spec_or_default(spec))
   endsubroutine heatmap_r64

   subroutine heatmap_r32(label, f, xmin, xmax, ymin, ymax, scale_min, scale_max, label_format, colormap, spec)
   !< The field f(i, j) as coloured cells (`PlotHeatmap`), single precision, read in place.
   character(len=*),     intent(in)                     :: label        !< Legend label.
   real(real32),         intent(in), target, contiguous :: f(:,:)       !< Field.
   real(real64),         intent(in)                     :: xmin, xmax   !< Columns' edges.
   real(real64),         intent(in)                     :: ymin, ymax   !< Rows' edges.
   real(real64),         intent(in), optional           :: scale_min    !< Value at the map's bottom.
   real(real64),         intent(in), optional           :: scale_max    !< ... at its top (both or none: data).
   character(len=*),     intent(in), optional           :: label_format !< printf format of each cell's value.
   integer(int32),       intent(in), optional           :: colormap     !< Colormap (default Viridis).
   type(plot_item_spec), intent(in), optional           :: spec         !< Style (its flags).
   type(item_series)                                    :: g            !< The values in memory order.
   real(real32), pointer                                :: v(:)         !< ... as a vector.

   v(1:size(f)) => f
   call view_r32(g, 2_int32, v)
   g%n = int(size(f), int32)
   call heatmap_item(label, g, int(size(f, 2), int32), int(size(f, 1), int32), xmin, xmax, ymin, ymax, scale_min, &
                     scale_max, label_format, colormap, spec_or_default(spec))
   endsubroutine heatmap_r32

   subroutine heatmap_item(label, g, rows, cols, xmin, xmax, ymin, ymax, scale_min, scale_max, label_format, &
                           colormap, spec)
   !< `PlotHeatmap(values, rows, cols, smin, smax, fmt, (xmin, ymax), (xmax, ymin))` as `ip_heatmap` calls it, the
   !< colormap pushed: `FitterRect`, `RenderHeatmap` (reverse_y: row 0 at ymin).
   character(len=*),     intent(in)           :: label        !< Label.
   type(item_series),    intent(in)           :: g            !< Values.
   integer(int32),       intent(in)           :: rows, cols   !< Shape.
   real(real64),         intent(in)           :: xmin, xmax, ymin, ymax !< Bounds.
   real(real64),         intent(in), optional :: scale_min, scale_max   !< Scale.
   character(len=*),     intent(in), optional :: label_format !< Labels.
   integer(int32),       intent(in), optional :: colormap     !< Colormap.
   type(plot_item_spec), intent(in)           :: spec         !< Style.
   type(plot_item_ctx)                        :: ctx          !< The plot.
   type(item_style)                           :: s            !< Staged style.
   type(plot_format)                          :: fm           !< Labels' format.
   real(real64)                               :: smin, smax   !< Scale.
   integer(int32)                             :: cm           !< Colormap.

   cm = CM_VIRIDIS
   if (present(colormap)) cm = colormap
   call cm_push(cm)
   smin = 0.0_real64
   smax = 0.0_real64
   if (present(scale_min)) smin = scale_min
   if (present(scale_max)) smax = scale_max
   if (begin(label, spec, [0.0_real32, 0.0_real32, 0.0_real32, AUTO_ALPHA], PF_MARKER_INVALID, ctx, s)) then
      if (fits(ctx, spec)) then ! FitterRect((xmin, ymax), (xmax, ymin))
         call pf_item_fit(xmin, ymax)
         call pf_item_fit(xmax, ymin)
      endif
      if (rows > 0_int32 .and. cols > 0_int32) then
         if (present(label_format)) then
            call fmt_parse(label_format, fm)
            call render_heatmap(ctx, g, rows, cols, smin, smax, fm, .true., xmin, ymax, xmax, ymin, .true., &
                                iand(spec%flags, PF_HEATMAP_COL_MAJOR) /= 0_int32)
         else
            call render_heatmap(ctx, g, rows, cols, smin, smax, fm, .false., xmin, ymax, xmax, ymin, .true., &
                                iand(spec%flags, PF_HEATMAP_COL_MAJOR) /= 0_int32)
         endif
      endif
      call finish()
   endif
   call cm_pop()
   endsubroutine heatmap_item

   subroutine render_heatmap(ctx, g, rows, cols, smin_, smax_, fm, labelled, bx0, by0, bx1, by1, reverse_y, col_maj)
   !< `RenderHeatmap`: scale from the data when (0, 0); a constant scale one rectangle of the map's first colour; else
   !< a cell per value (`GetterHeatmapRowMaj`/`ColMaj`, `RendererRectC`: culled, transparent skipped), then the labels.
   type(plot_item_ctx), intent(in) :: ctx            !< The plot.
   type(item_series),   intent(in) :: g              !< Values.
   integer(int32),      intent(in) :: rows, cols     !< Shape.
   real(real64),        intent(in) :: smin_, smax_   !< Scale.
   type(plot_format),   intent(in) :: fm             !< Labels' format.
   logical,             intent(in) :: labelled       !< Labels.
   real(real64),        intent(in) :: bx0, by0, bx1, by1 !< bounds_min, bounds_max.
   logical,             intent(in) :: reverse_y      !< Row 0 at bounds_max.y.
   logical,             intent(in) :: col_maj        !< Column major.
   real(real64)                    :: smin, smax, w, h, hx, hy, yref, ydir, px, py, v, t, a, d !< Cells.
   real(real32)                    :: p1(2), p2(2), tsz(2) !< Pixels, a label's size.
   real(real32)                    :: xlo, ylo, xhi, yhi !< The primitive's bounds (`ImMin`, `ImMax` of its ends).
   logical                         :: vis                !< They overlap the plot rectangle (`Overlaps`).
   real(real64)                    :: tw, th          !< Text size.
   real(real32)                    :: uv(2)           !< White pixel.
   real(real32)                    :: tt, xq, fq, fc  !< A cell's place on the map, its table entry unrounded; the
                                                      !< table's size and size - 1.
   real(real64)                    :: vb(PIX_BLOCK)   !< A block's values.
   integer(int32)                  :: idx, r, c, col, nl !< Value, row, column, colour, label length.
   integer(int32)                  :: cm, i0, nprim, cnt, ib, nb, m, siz, e !< Colormap, run's start, cells left,
                                                      !< run, block's first cell, its cells, one of them, table size,
                                                      !< entry.
   integer(int32), pointer, contiguous :: tab(:)      !< The map's table.
   logical                         :: qual            !< ... qualitative.
   type(prim_run)                  :: run             !< The run.
   character(len=31)               :: lab             !< A label.

   smin = smin_
   smax = smax_
   if (smin == 0.0_real64 .and. smax == 0.0_real64) call min_max(g, rows * cols, smin, smax)
   if (smin == smax) then
      p1 = [map_pixel(ctx%tx, bx0), map_pixel(ctx%ty, by0)]
      p2 = [map_pixel(ctx%tx, bx1), map_pixel(ctx%ty, by1)]
      call core_draw_rect_filled(real(p1(1), real64), real(p1(2), real64), real(p2(1), real64), real(p2(2), real64), &
                                 cm_key(cm_current(), 0_int32))
      return
   endif
   yref = merge(by1, by0, reverse_y)
   ydir = merge(-1.0_real64, 1.0_real64, reverse_y)
   w = (bx1 - bx0) / real(cols, real64)
   h = (by1 - by0) / real(rows, real64)
   hx = w * 0.5_real64
   hy = h * 0.5_real64
   cm = cm_current() ! (one lookup an item)
   call cm_lookup(cm, tab, qual) ! cm_sample's table, sampled below as cm_sample samples it
   siz = int(size(tab), int32)
   fq = real(siz, real32)
   fc = real(siz - 1_int32, real32)
   d = smax - smin
   ! the cells' edges in pixels: the same for every cell of a column (row), mapped once a column (row)
   if (allocated(cell_x)) then
      if (size(cell_x, 2) < cols) deallocate(cell_x)
   endif
   if (.not. allocated(cell_x)) allocate(cell_x(2, max(cols, 256_int32)))
   if (allocated(cell_y)) then
      if (size(cell_y, 2) < rows) deallocate(cell_y)
   endif
   if (.not. allocated(cell_y)) allocate(cell_y(2, max(rows, 256_int32)))
   do c = 0_int32, cols - 1_int32
      t = real(c, real64) * w ! XRef + HalfSize.x + c Width
      px = (bx0 + hx) + t
      cell_x(1, c + 1_int32) = map_pixel(ctx%tx, px - hx)
      cell_x(2, c + 1_int32) = map_pixel(ctx%tx, px + hx)
   enddo
   do r = 0_int32, rows - 1_int32
      t = real(r, real64) * h ! YRef + YDir (HalfSize.y + r Height)
      a = hy + t
      t = ydir * a
      py = yref + t
      cell_y(1, r + 1_int32) = map_pixel(ctx%ty, py - hy)
      cell_y(2, r + 1_int32) = map_pixel(ctx%ty, py + hy)
   enddo
   uv = real(uv_white, real32)
   call run_begin(run, 4_int32, 6_int32) ! RendererRectC
   nprim = rows * cols
   i0 = 0_int32
   do while (nprim > 0_int32)
   call run_next(run, nprim, cnt)
   ib = i0
   do while (ib < i0 + cnt)
   nb = min(PIX_BLOCK, i0 + cnt - ib)
   call coordinates(g, 2_int32, ib + 1_int32, nb, vb)
   if (col_maj) then
      r = mod(ib, rows)
      c = ib / rows
   else
      r = ib / cols
      c = mod(ib, cols)
   endif
   do m = 1_int32, nb
      v = vb(m)
      tt = min(max(real((v - smin) / d, real32), 0.0_real32), 1.0_real32) ! cm_sample (LerpTable) inline
      if (qual) then
         xq = fq * tt
         e = min(max(int(xq, int32), 0_int32), siz - 1_int32)
      else
         xq = fc * tt
         xq = xq + 0.5_real32
         e = int(xq, int32)
      endif
      col = tab(e + 1_int32)
      p1(1) = cell_x(1, c + 1_int32)
      p1(2) = cell_y(1, r + 1_int32)
      p2(1) = cell_x(2, c + 1_int32)
      p2(2) = cell_y(2, r + 1_int32)
      if (col_maj) then ! the next cell
         r = r + 1_int32
         if (r == rows) then
            r = 0_int32
            c = c + 1_int32
         endif
      else
         c = c + 1_int32
         if (c == cols) then
            c = 0_int32
            r = r + 1_int32
         endif
      endif
      xlo = merge(p1(1), p2(1), p1(1) < p2(1)) ! ImMin, ImMax and Overlaps written out: nvfortran -O2 -mp
      ylo = merge(p1(2), p2(2), p1(2) < p2(2)) ! inlines no procedure (im_min: the NaN cases)
      xhi = merge(p1(1), p2(1), p1(1) >= p2(1))
      yhi = merge(p1(2), p2(2), p1(2) >= p2(2))
#ifdef __NVCOMPILER
      if (p1(1) /= p1(1) .or. p2(1) /= p2(1)) then
         xlo = p2(1)
         xhi = p2(1)
      endif
      if (p1(2) /= p1(2) .or. p2(2) /= p2(2)) then
         ylo = p2(2)
         yhi = p2(2)
      endif
#endif
      vis = ctx%rect(2) < yhi .and. ctx%rect(4) > ylo .and. ctx%rect(1) < xhi .and. ctx%rect(3) > xlo
#ifdef __NVCOMPILER
      if (vis) vis = .not. (xlo /= xlo .or. ylo /= ylo .or. xhi /= xhi .or. yhi /= yhi)
#endif
      if (iand(ishft(int(col, int64), -24), 255_int64) == 0_int64 .or. .not. vis) then
         run%culled = run%culled + 1_int32
         cycle
      endif
      call put_rect_fill(run, p1(1), p1(2), p2(1), p2(2), col, uv)
   enddo
   ib = ib + nb
   enddo
   i0 = i0 + cnt
   enddo
   call run_end(run)
   if (.not. labelled) return
   idx = 0_int32
   do r = 0_int32, merge(cols, rows, col_maj) - 1_int32 ! (outer loop: columns when column major)
      do c = 0_int32, merge(rows, cols, col_maj) - 1_int32
         if (col_maj) then
            call label_cell(c, r)
         else
            call label_cell(r, c)
         endif
         idx = idx + 1_int32
      enddo
   enddo
   contains
      subroutine label_cell(rr, cc)
      !< A cell's label: its value through the format, centred, black or white on its colour.
      integer(int32), intent(in) :: rr, cc !< Row, column.
      real(real64)               :: qx, qy, q, b !< Centre, terms.

      q = 0.5_real64 * w
      qx = bx0 + q
      q = real(cc, real64) * w
      qx = qx + q
      q = 0.5_real64 * h
      b = real(rr, real64) * h
      q = q + b
      q = ydir * q
      qy = yref + q
      v = coordinate(g, 2_int32, int(idx + 1_int32, int64))
      nl = 0_int32
      call fmt_real(lab, nl, fm, v)
      call core_text_size(lab(1:nl), tw, th)
      tsz = [real(tw, real32), real(th, real32)] * 0.5_real32
      q = min(max((v - smin) / (smax - smin), 0.0_real64), 1.0_real64)
      col = text_on(unpack_u32(cm_sample(cm, real(q, real32)))) ! CalcTextColor(SampleColormap((float)t))
      call core_draw_text(real(map_pixel(ctx%tx, qx) - tsz(1), real64), real(map_pixel(ctx%ty, qy) - tsz(2), real64), &
                          col, lab(1:nl))
      endsubroutine label_cell
   endsubroutine render_heatmap

   subroutine min_max(g, n, lo, hi)
   !< `ImMinMaxIndexer`: the first value, then `<` and `>` (NaN ignored after the first).
   type(item_series), intent(in)  :: g      !< Values.
   integer(int32),    intent(in)  :: n      !< Count.
   real(real64),      intent(out) :: lo, hi !< Range.
   integer(int32)                 :: i, nb, m !< Block's first value, its values, one of them.
   real(real64)                   :: v(PIX_BLOCK) !< A block's values.

   lo = coordinate(g, 2_int32, 1_int64)
   hi = lo
   i = 2_int32
   do while (i <= n)
      nb = min(PIX_BLOCK, n - i + 1_int32)
      call coordinates(g, 2_int32, i, nb, v)
      do m = 1_int32, nb
         if (v(m) < lo) lo = v(m)
         if (v(m) > hi) hi = v(m)
      enddo
      i = i + nb
   enddo
   endsubroutine min_max

   subroutine histogram_r64(label, values, bins, vmin, vmax, bar_scale, max_count, spec)
   !< A histogram (`ip_histogram`), double precision.
   character(len=*),     intent(in)            :: label     !< Legend label.
   real(real64),         intent(in)            :: values(:) !< Values.
   integer(int32),       intent(in),  optional :: bins      !< A count > 0 or a `PF_BIN_*` rule (default Sturges).
   real(real64),         intent(in),  optional :: vmin      !< First bin's left end (with vmax).
   real(real64),         intent(in),  optional :: vmax      !< Last bin's right end.
   real(real64),         intent(in),  optional :: bar_scale !< Bar width over bin width (default 1).
   real(real64),         intent(out), optional :: max_count !< The tallest bar.
   type(plot_item_spec), intent(in),  optional :: spec      !< Style (histogram flags).
   integer(int64)                              :: n, i      !< Finite values, counter.

   call finite_room(size(values, kind=int64))
   n = 0_int64
   do i = 1_int64, size(values, kind=int64)
      if (abs(values(i)) <= huge(1.0_real64)) then
         n = n + 1_int64
         finite_x(n) = values(i)
      endif
   enddo
   call histogram_item(label, n, bins, vmin, vmax, bar_scale, max_count, spec_or_default(spec))
   endsubroutine histogram_r64

   subroutine histogram_r32(label, values, bins, vmin, vmax, bar_scale, max_count, spec)
   !< A histogram (`ip_histogram`), single precision (the values taken as double, as ImPlot's indexer).
   character(len=*),     intent(in)            :: label     !< Legend label.
   real(real32),         intent(in)            :: values(:) !< Values.
   integer(int32),       intent(in),  optional :: bins      !< A count > 0 or a `PF_BIN_*` rule (default Sturges).
   real(real64),         intent(in),  optional :: vmin      !< First bin's left end (with vmax).
   real(real64),         intent(in),  optional :: vmax      !< Last bin's right end.
   real(real64),         intent(in),  optional :: bar_scale !< Bar width over bin width (default 1).
   real(real64),         intent(out), optional :: max_count !< The tallest bar.
   type(plot_item_spec), intent(in),  optional :: spec      !< Style (histogram flags).
   integer(int64)                              :: n, i      !< Finite values, counter.

   call finite_room(size(values, kind=int64))
   n = 0_int64
   do i = 1_int64, size(values, kind=int64)
      if (abs(values(i)) <= huge(1.0_real32)) then
         n = n + 1_int64
         finite_x(n) = real(values(i), real64)
      endif
   enddo
   call histogram_item(label, n, bins, vmin, vmax, bar_scale, max_count, spec_or_default(spec))
   endsubroutine histogram_r32

   subroutine histogram_item(label, n, bins, vmin, vmax, bar_scale, max_count, spec)
   !< `ip_histogram` then `PlotHistogram` on the n finite values (finite_x): the range given or theirs widened, the
   !< bins counted or by FIGURE's rule (`rule_bins`), the counts (cumulative, density, outliers), bars through
   !< `PlotBars(centres, counts)` (horizontal: `PlotBars(counts, centres)`), bar_scale times the bin width.
   character(len=*),     intent(in)            :: label     !< Label.
   integer(int64),       intent(in)            :: n         !< Finite values.
   integer(int32),       intent(in),  optional :: bins      !< Bins.
   real(real64),         intent(in),  optional :: vmin, vmax !< Range.
   real(real64),         intent(in),  optional :: bar_scale !< Bar scale.
   real(real64),         intent(out), optional :: max_count !< Tallest bar.
   type(plot_item_spec), intent(in)            :: spec      !< Style.
   type(plot_item_spec)                        :: sb        !< The bars' spec.
   type(item_series)                           :: g         !< The bars' getter.
   real(real64)                                :: rmin, rmax, width, val, top, scale, t, sd !< Range, bins, counts.
   integer(int32)                              :: nb, b, ib, below, counted !< Bins, a bin, counts.
   logical                                     :: cumulative, density, outliers, horz !< Flags.

   if (present(max_count)) max_count = 0.0_real64
   if (n == 0_int64) return ! nothing to count: no item
   nb = PF_BIN_STURGES
   if (present(bins)) nb = bins
   if (present(vmin) .and. present(vmax)) then
      rmin = vmin
      rmax = vmax
   else
      rmin = minval(finite_x(1:n))
      rmax = maxval(finite_x(1:n))
      if (.not. (rmax > rmin)) then ! widen
         rmin = rmin - 0.5_real64
         rmax = rmax + 0.5_real64
      endif
   endif
   sd = 0.0_real64
   if (nb == PF_BIN_SCOTT) sd = std_dev(finite_x(1:n))
   nb = rule_bins(nb, n, rmin, rmax, sd)
   cumulative = iand(spec%flags, PF_HIST_CUMULATIVE) /= 0_int32
   density = iand(spec%flags, PF_HIST_DENSITY) /= 0_int32
   outliers = iand(spec%flags, PF_HIST_NO_OUTLIERS) == 0_int32
   horz = iand(spec%flags, PF_HIST_HORIZONTAL) /= 0_int32
   width = (rmax - rmin) / real(nb, real64)
   call hist_room(int(nb, int64))
   do b = 0_int32, nb - 1_int32 ! range.Min + b width + width 0.5
      t = real(b, real64) * width
      hist_a(b + 1_int32) = rmin + t
      t = width * 0.5_real64
      hist_a(b + 1_int32) = hist_a(b + 1_int32) + t
      hist_b(b + 1_int32) = 0.0_real64
   enddo
   below = 0_int32
   counted = 0_int32
   top = 0.0_real64
   do b = 1_int32, int(n, int32)
      val = finite_x(b)
      if (val >= rmin .and. val <= rmax) then
         ib = min(max(int((val - rmin) / width, int32), 0_int32), nb - 1_int32) + 1_int32
         hist_b(ib) = hist_b(ib) + 1.0_real64
         if (hist_b(ib) > top) top = hist_b(ib)
         counted = counted + 1_int32
      elseif (val < rmin) then
         below = below + 1_int32
      endif
   enddo
   if (cumulative .and. density) then
      if (outliers) hist_b(1) = hist_b(1) + real(below, real64)
      do b = 2_int32, nb
         hist_b(b) = hist_b(b) + hist_b(b - 1_int32)
      enddo
      scale = 1.0_real64 / real(merge(int(n, int32), counted, outliers), real64)
      hist_b(1:nb) = hist_b(1:nb) * scale
      top = hist_b(nb)
   elseif (cumulative) then
      if (outliers) hist_b(1) = hist_b(1) + real(below, real64)
      do b = 2_int32, nb
         hist_b(b) = hist_b(b) + hist_b(b - 1_int32)
      enddo
      top = hist_b(nb)
   elseif (density) then
      scale = 1.0_real64 / (real(merge(int(n, int32), counted, outliers), real64) * width)
      hist_b(1:nb) = hist_b(1:nb) * scale
      top = top * scale
   endif
   sb = spec
   if (horz) then ! PlotBars(counts, centres, Horizontal)
      sb%flags = PF_BARS_HORIZONTAL
      call view_r64(g, 1_int32, hist_b(1:nb))
      call view_r64(g, 2_int32, hist_a(1:nb))
   else
      sb%flags = 0_int32
      call view_r64(g, 1_int32, hist_a(1:nb))
      call view_r64(g, 2_int32, hist_b(1:nb))
   endif
   g%n = nb
   t = 1.0_real64
   if (present(bar_scale)) t = bar_scale
   t = t * width
   call bars_item(label, g, t, sb)
   if (present(max_count)) max_count = top
   endsubroutine histogram_item

   subroutine histogram2d_r64(label, x, y, xbins, ybins, xmin, xmax, ymin, ymax, colormap, max_count, spec)
   !< A 2-D histogram (`ip_histogram2d`), double precision.
   character(len=*),     intent(in)            :: label      !< Legend label.
   real(real64),         intent(in)            :: x(:), y(:) !< Points.
   integer(int32),       intent(in),  optional :: xbins, ybins !< Bins (counts or rules; default Sturges).
   real(real64),         intent(in),  optional :: xmin, xmax, ymin, ymax !< Range (default: the finite points').
   integer(int32),       intent(in),  optional :: colormap   !< Colormap (default Viridis).
   real(real64),         intent(out), optional :: max_count  !< The fullest cell.
   type(plot_item_spec), intent(in),  optional :: spec       !< Style (Density, NoOutliers, ColMajor).
   integer(int64)                              :: n, i       !< Finite points, counter.

   call finite_room(int(min(size(x), size(y)), int64))
   n = 0_int64
   do i = 1_int64, int(min(size(x), size(y)), int64)
      if (abs(x(i)) <= huge(1.0_real64) .and. abs(y(i)) <= huge(1.0_real64)) then
         n = n + 1_int64
         finite_x(n) = x(i)
         finite_y(n) = y(i)
      endif
   enddo
   call histogram2d_item(label, n, xbins, ybins, xmin, xmax, ymin, ymax, colormap, max_count, spec_or_default(spec))
   endsubroutine histogram2d_r64

   subroutine histogram2d_r32(label, x, y, xbins, ybins, xmin, xmax, ymin, ymax, colormap, max_count, spec)
   !< A 2-D histogram (`ip_histogram2d`), single precision.
   character(len=*),     intent(in)            :: label      !< Legend label.
   real(real32),         intent(in)            :: x(:), y(:) !< Points.
   integer(int32),       intent(in),  optional :: xbins, ybins !< Bins (counts or rules; default Sturges).
   real(real64),         intent(in),  optional :: xmin, xmax, ymin, ymax !< Range (default: the finite points').
   integer(int32),       intent(in),  optional :: colormap   !< Colormap (default Viridis).
   real(real64),         intent(out), optional :: max_count  !< The fullest cell.
   type(plot_item_spec), intent(in),  optional :: spec       !< Style (Density, NoOutliers, ColMajor).
   integer(int64)                              :: n, i       !< Finite points, counter.

   call finite_room(int(min(size(x), size(y)), int64))
   n = 0_int64
   do i = 1_int64, int(min(size(x), size(y)), int64)
      if (abs(x(i)) <= huge(1.0_real32) .and. abs(y(i)) <= huge(1.0_real32)) then
         n = n + 1_int64
         finite_x(n) = real(x(i), real64)
         finite_y(n) = real(y(i), real64)
      endif
   enddo
   call histogram2d_item(label, n, xbins, ybins, xmin, xmax, ymin, ymax, colormap, max_count, spec_or_default(spec))
   endsubroutine histogram2d_r32

   subroutine histogram2d_item(label, n, xbins, ybins, xmin, xmax, ymin, ymax, colormap, max_count, spec)
   !< `ip_histogram2d` then `PlotHistogram2D` on the n finite points (finite_x, finite_y): ranges given or the points'
   !< widened, bins by count or FIGURE's rule, the counts (row y, column x), density; `FitterRect(range)` and
   !< `RenderHeatmap(counts, ybins, xbins, 0, max, no labels, range, reverse_y false)`, the colormap pushed.
   character(len=*),     intent(in)            :: label        !< Label.
   integer(int64),       intent(in)            :: n            !< Finite points.
   integer(int32),       intent(in),  optional :: xbins, ybins !< Bins.
   real(real64),         intent(in),  optional :: xmin, xmax, ymin, ymax !< Range.
   integer(int32),       intent(in),  optional :: colormap     !< Colormap.
   real(real64),         intent(out), optional :: max_count    !< Fullest cell.
   type(plot_item_spec), intent(in)            :: spec         !< Style.
   type(plot_item_ctx)                         :: ctx          !< The plot.
   type(item_style)                            :: s            !< Staged style.
   type(item_series)                           :: g            !< The counts.
   type(plot_format)                           :: fm           !< (no labels)
   real(real64)                                :: x0, x1, y0, y1, w, h, sx, sy, top, scale !< Range, bins.
   integer(int32)                              :: nbx, nby, i, xb, yb, counted, cm !< Bins, counters.
   logical                                     :: density, outliers !< Flags.

   if (present(max_count)) max_count = 0.0_real64
   if (n == 0_int64) return ! nothing to count: no item
   nbx = PF_BIN_STURGES
   if (present(xbins)) nbx = xbins
   nby = PF_BIN_STURGES
   if (present(ybins)) nby = ybins
   if (present(xmin) .and. present(xmax)) then
      x0 = xmin
      x1 = xmax
   else
      x0 = minval(finite_x(1:n))
      x1 = maxval(finite_x(1:n))
      if (.not. (x1 > x0)) then
         x0 = x0 - 0.5_real64
         x1 = x1 + 0.5_real64
      endif
   endif
   if (present(ymin) .and. present(ymax)) then
      y0 = ymin
      y1 = ymax
   else
      y0 = minval(finite_y(1:n))
      y1 = maxval(finite_y(1:n))
      if (.not. (y1 > y0)) then
         y0 = y0 - 0.5_real64
         y1 = y1 + 0.5_real64
      endif
   endif
   sx = 0.0_real64
   sy = 0.0_real64
   if (nbx == PF_BIN_SCOTT) sx = std_dev(finite_x(1:n))
   if (nby == PF_BIN_SCOTT) sy = std_dev(finite_y(1:n))
   nbx = rule_bins(nbx, n, x0, x1, sx)
   nby = rule_bins(nby, n, y0, y1, sy)
   density = iand(spec%flags, PF_HIST_DENSITY) /= 0_int32
   outliers = iand(spec%flags, PF_HIST_NO_OUTLIERS) == 0_int32
   w = (x1 - x0) / real(nbx, real64)
   h = (y1 - y0) / real(nby, real64)
   call hist_room(int(nbx, int64) * int(nby, int64))
   hist_b(1:nbx * nby) = 0.0_real64
   counted = 0_int32
   top = 0.0_real64
   do i = 1_int32, int(n, int32)
      if (finite_x(i) >= x0 .and. finite_x(i) <= x1 .and. finite_y(i) >= y0 .and. finite_y(i) <= y1) then
         xb = min(max(int((finite_x(i) - x0) / w, int32), 0_int32), nbx - 1_int32)
         yb = min(max(int((finite_y(i) - y0) / h, int32), 0_int32), nby - 1_int32)
         hist_b(yb * nbx + xb + 1_int32) = hist_b(yb * nbx + xb + 1_int32) + 1.0_real64
         if (hist_b(yb * nbx + xb + 1_int32) > top) top = hist_b(yb * nbx + xb + 1_int32)
         counted = counted + 1_int32
      endif
   enddo
   if (density) then
      scale = 1.0_real64 / ((real(merge(int(n, int32), counted, outliers), real64) * w) * h)
      hist_b(1:nbx * nby) = hist_b(1:nbx * nby) * scale
      top = top * scale
   endif
   cm = CM_VIRIDIS
   if (present(colormap)) cm = colormap
   call cm_push(cm)
   if (begin(label, spec, [0.0_real32, 0.0_real32, 0.0_real32, AUTO_ALPHA], PF_MARKER_INVALID, ctx, s)) then
      if (fits(ctx, spec)) then ! FitterRect(range)
         call pf_item_fit(x0, y0)
         call pf_item_fit(x1, y1)
      endif
      call view_r64(g, 2_int32, hist_b(1:nbx * nby))
      g%n = nbx * nby
      call render_heatmap(ctx, g, nby, nbx, 0.0_real64, top, fm, .false., x0, y0, x1, y1, .false., &
                          iand(spec%flags, PF_HIST_COL_MAJOR) /= 0_int32)
      call finish()
   endif
   call cm_pop()
   if (present(max_count)) max_count = top
   endsubroutine histogram2d_item

   pure function rule_bins(nb, n, rmin, rmax, sd) result(bins)
   !< FIGURE's `rule_bins` (figure_implot), verbatim: a count, or the rule's over n values in [rmin, rmax].
   integer(int32), intent(in) :: nb         !< A count (> 0) or a `PF_BIN_*` rule.
   integer(int64), intent(in) :: n          !< Values.
   real(real64),   intent(in) :: rmin, rmax !< Range.
   real(real64),   intent(in) :: sd         !< Standard deviation (Scott's rule).
   integer(int32)             :: bins       !< Bins, at least 1.
   real(real64)               :: w, k       !< Width, bins as a real.

   if (nb > 0_int32) then
      bins = nb
      return
   endif
   select case (nb)
   case (PF_BIN_SQRT)
      k = ceiling(sqrt(real(n, real64)))
   case (PF_BIN_RICE)
      k = ceiling(2.0_real64 * real(n, real64)**(1.0_real64 / 3.0_real64))
   case (PF_BIN_SCOTT)
      w = 3.49_real64 * sd / real(n, real64)**(1.0_real64 / 3.0_real64)
      k = 1.0_real64
      if (w > 0.0_real64) k = anint(min(real(rmax - rmin, real64) / w, 1.0e6_real64))
   case default ! Sturges
      k = ceiling(1.0_real64 + log(real(n, real64)) / log(2.0_real64))
   endselect
   bins = int(max(1.0_real64, min(k, 1.0e6_real64)), int32)
   endfunction rule_bins

   pure function std_dev(v) result(s)
   !< FIGURE's `std_dev`, verbatim: population standard deviation (0 for none).
   real(real64), intent(in) :: v(:) !< Values.
   real(real64)             :: s    !< Standard deviation.
   real(real64)             :: m    !< Mean.

   s = 0.0_real64
   if (size(v) == 0) return
   m = sum(v) / real(size(v), real64)
   s = sqrt(sum((v - m)**2) / real(size(v), real64))
   endfunction std_dev

   subroutine finite_room(n)
   !< Room for n finite values (kept, grown).
   integer(int64), intent(in) :: n !< Values.

   if (allocated(finite_x)) then
      if (size(finite_x, kind=int64) < n) deallocate(finite_x, finite_y)
   endif
   if (.not. allocated(finite_x)) allocate(finite_x(max(n, 1024_int64)), finite_y(max(n, 1024_int64)))
   endsubroutine finite_room

   subroutine hist_room(n)
   !< Room for n bins (kept, grown).
   integer(int64), intent(in) :: n !< Bins.

   if (allocated(hist_a)) then
      if (size(hist_a, kind=int64) < n) deallocate(hist_a, hist_b)
   endif
   if (.not. allocated(hist_a)) allocate(hist_a(max(n, 256_int64)), hist_b(max(n, 256_int64)))
   endsubroutine hist_room

   ! images, field images (PlotImage; native/figure_field.cpp's colouring in figure_plot_field)

   subroutine pf_image(label, tex, xmin, xmax, ymin, ymax, spec)
   !< A texture over [xmin, xmax] x [ymin, ymax], pixel row 1 at ymin (`ip_image`: `PlotImage` with uv (0, 1)-(1, 0),
   !< the texture's own filter): `FitterRect`, the item's colour the tint (white), `AddImage` in the plot's clip.
   character(len=*),     intent(in)           :: label      !< Legend label.
   type(texture_object), intent(in)           :: tex        !< Texture.
   real(real64),         intent(in)           :: xmin, xmax !< Edges.
   real(real64),         intent(in)           :: ymin, ymax !< ...
   type(plot_item_spec), intent(in), optional :: spec       !< Style.

   if (.not. tex%is_initialized()) error stop 'figure_plot_items: pf_image: the texture is not initialized'
   associate(r => texture_ref(tex))
      call image_item(label, int(r%TexID, int64), xmin, xmax, ymin, ymax, spec_or_default(spec))
   endassociate
   endsubroutine pf_image

   subroutine image_item(label, tex, x0, x1, y0, y1, spec)
   !< `PlotImage(tex, (x0, y0), (x1, y1), uv0 (0, 1), uv1 (1, 0), white)` between the texture-filter callbacks.
   character(len=*),     intent(in) :: label  !< Label.
   integer(int64),       intent(in) :: tex    !< Texture id.
   real(real64),         intent(in) :: x0, x1, y0, y1 !< Edges.
   type(plot_item_spec), intent(in) :: spec   !< Style.
   type(plot_item_ctx)              :: ctx    !< The plot.
   type(item_style)                 :: s      !< Staged style.
   real(real32)                     :: p1(2), p2(2) !< Corners.

   call core_texture_sampling(.true.) ! fig_texture_sampling(1, 1): the texture's own filter
   if (begin(label, spec, [0.0_real32, 0.0_real32, 0.0_real32, AUTO_ALPHA], PF_MARKER_INVALID, ctx, s)) then
      if (fits(ctx, spec)) then
         call pf_item_fit(x0, y0)
         call pf_item_fit(x1, y1)
      endif
      call pf_item_recolor(-1_int32) ! the tint, IM_COL32_WHITE
      p1 = [map_pixel(ctx%tx, x0), map_pixel(ctx%ty, y1)]
      p2 = [map_pixel(ctx%tx, x1), map_pixel(ctx%ty, y0)]
      call core_draw_image(tex, real(p1(1), real64), real(p1(2), real64), real(p2(1), real64), real(p2(2), real64), &
                           0.0_real64, 1.0_real64, 1.0_real64, 0.0_real64, -1_int32)
      call finish()
   endif
   call core_texture_sampling(.false.)
   endsubroutine image_item

   subroutine field_image_r64(label, f, x0, x1, y0, y1, colormap, vmin, vmax, scale, nan_color, changed, range)
   !< The field f(i, j) through a colormap, kept as a texture (`ip_field_image`), double precision.
   character(len=*), intent(in)                     :: label        !< Legend label (the cache's id).
   real(real64),     intent(in), target, contiguous :: f(:,:)       !< Field.
   real(real64),     intent(in)                     :: x0, x1, y0, y1 !< Edges.
   integer(int32),   intent(in), optional           :: colormap     !< Colormap (default Viridis).
   real(real64),     intent(in), optional           :: vmin, vmax   !< Range (default: the data's).
   character(len=*), intent(in), optional           :: scale        !< 'linear' (default), 'log', 'symlog'.
   real(real64),     intent(in), optional           :: nan_color(4) !< NaN colour (default transparent).
   logical,          intent(in), optional           :: changed      !< The values changed.
   real(real64),     intent(out), optional          :: range(2)     !< The range applied.
   integer(int64)                                   :: tex          !< Texture.
   real(real64)                                     :: lo, hi       !< Range.
   integer(int32)                                   :: st           !< Status.

   if (size(f) == 0) return
   call sweep_once()
   call field_colour(pf_item_id(label), f64=f, nx=size(f, 1, kind=int64), ny=size(f, 2, kind=int64), &
                     cmap=field_cmap(colormap), vmin=vmin, vmax=vmax, scale=field_scale(scale),   &
                     nan_rgba=field_nan(nan_color), changed=field_changed(changed), tex=tex, lo=lo, hi=hi, stat=st, &
                     label=label)
   if (st /= 0_int32) error stop 'figure_plot_items: pf_field_image: the texture failed'
   if (present(range)) range = [lo, hi]
   call image_item(label, tex, x0, x1, y0, y1, plot_item_spec())
   endsubroutine field_image_r64

   subroutine field_image_r32(label, f, x0, x1, y0, y1, colormap, vmin, vmax, scale, nan_color, changed, range)
   !< The field f(i, j) through a colormap, kept as a texture (`ip_field_image`), single precision.
   character(len=*), intent(in)                     :: label        !< Legend label (the cache's id).
   real(real32),     intent(in), target, contiguous :: f(:,:)       !< Field.
   real(real64),     intent(in)                     :: x0, x1, y0, y1 !< Edges.
   integer(int32),   intent(in), optional           :: colormap     !< Colormap (default Viridis).
   real(real64),     intent(in), optional           :: vmin, vmax   !< Range (default: the data's).
   character(len=*), intent(in), optional           :: scale        !< 'linear' (default), 'log', 'symlog'.
   real(real64),     intent(in), optional           :: nan_color(4) !< NaN colour (default transparent).
   logical,          intent(in), optional           :: changed      !< The values changed.
   real(real64),     intent(out), optional          :: range(2)     !< The range applied.
   integer(int64)                                   :: tex          !< Texture.
   real(real64)                                     :: lo, hi       !< Range.
   integer(int32)                                   :: st           !< Status.

   if (size(f) == 0) return
   call sweep_once()
   call field_colour(pf_item_id(label), f32=f, nx=size(f, 1, kind=int64), ny=size(f, 2, kind=int64), &
                     cmap=field_cmap(colormap), vmin=vmin, vmax=vmax, scale=field_scale(scale),   &
                     nan_rgba=field_nan(nan_color), changed=field_changed(changed), tex=tex, lo=lo, hi=hi, stat=st, &
                     label=label)
   if (st /= 0_int32) error stop 'figure_plot_items: pf_field_image: the texture failed'
   if (present(range)) range = [lo, hi]
   call image_item(label, tex, x0, x1, y0, y1, plot_item_spec())
   endsubroutine field_image_r32

   subroutine sweep_once()
   !< The idle field colourings released, once a frame (native: at the frame's end, `fig_field_sweep`).
   integer(int32), save :: last = -1_int32 !< The frame swept last.

   if (core_frame_count() == last) return
   last = core_frame_count()
   call field_sweep()
   endsubroutine sweep_once

   function field_cmap(colormap) result(cm)
   !< The colormap (default Viridis).
   integer(int32), intent(in), optional :: colormap !< Colormap.
   integer(int32)                       :: cm       !< Map.

   cm = CM_VIRIDIS
   if (present(colormap)) cm = colormap
   endfunction field_cmap

   function field_scale(scale) result(code)
   !< 'linear' (default) 0, 'log' 1, 'symlog' 2.
   character(len=*), intent(in), optional :: scale !< Scale.
   integer(int32)                         :: code  !< Code.

   code = FIELD_LINEAR
   if (.not. present(scale)) return
   select case (scale)
   case ('linear')
      code = FIELD_LINEAR
   case ('log')
      code = FIELD_LOG
   case ('symlog')
      code = FIELD_SYMLOG
   case default
      error stop "figure_plot_items: pf_field_image: a scale is 'linear', 'log' or 'symlog'"
   endselect
   endfunction field_scale

   function field_nan(nan_color) result(c)
   !< The NaN colour as floats (default transparent).
   real(real64), intent(in), optional :: nan_color(4) !< RGBA.
   real(real32)                       :: c(4)         !< Colour.

   c = 0.0_real32
   if (present(nan_color)) c = real(nan_color, real32)
   endfunction field_nan

   function field_changed(changed) result(yes)
   !< `changed` (default false).
   logical, intent(in), optional :: changed !< Changed.
   logical                       :: yes     !< Changed.

   yes = .false.
   if (present(changed)) yes = changed
   endfunction field_changed

   function pf_field_count() result(n)
   !< The field colourings cached (tests).
   integer(int32) :: n !< Entries.

   n = field_count()
   endfunction pf_field_count

   function pf_field_uploads() result(n)
   !< The field colourings uploaded since the start (tests).
   integer(int64) :: n !< Uploads.

   n = field_uploads()
   endfunction pf_field_uploads

   ! private: the items (PlotLineEx, PlotScatterEx, PlotStairsEx, PlotStemsEx, PlotShadedEx)

   subroutine line_item(label, g, spec)
   !< `PlotLineEx`: the fill to y = 0 (`Shaded`), the line (strip, segments or loop), the markers.
   character(len=*),     intent(in)    :: label !< Label.
   type(item_series),    intent(inout) :: g     !< Getter.
   type(plot_item_spec), intent(in)    :: spec  !< Style.
   type(plot_item_ctx)                 :: ctx   !< The plot as the item sees it.
   type(item_style)                    :: s     !< Staged style.
   type(item_series)                   :: g0    !< The fill's base (y = 0).

   if (.not. begin(label, spec, spec%line_color, spec%marker, ctx, s)) return
   call decimate_series(g, KIND_LINE, spec, ctx, iand(spec%flags, PF_LINE_SHADED) /= 0_int32)
   if (fits(ctx, spec)) call fit1(g)
   if (g%n <= 0_int32) then
      call finish()
      return
   endif
   if (g%n > 1_int32) then
      if (iand(spec%flags, PF_LINE_SHADED) /= 0_int32 .and. s%fill) then
         g0 = g
         g0%src(2) = SRC_CONST ! GetterOverrideY(getter, 0)
         g0%con(2) = 0.0_real64
         call render_shaded(ctx, g, g0, s%col_fill)
      endif
      if (s%line) then
         if (iand(spec%flags, PF_LINE_SEGMENTS) /= 0_int32) then
            call render_segments1(ctx, g, s%col_line, s%weight)
         else
            call render_strip(ctx, g, s%col_line, s%weight, iand(spec%flags, PF_LINE_LOOP) /= 0_int32, &
                              iand(spec%flags, PF_LINE_SKIP_NAN) /= 0_int32)
         endif
      endif
   endif
   if (s%markers) then
      if (iand(spec%flags, PF_LINE_NO_CLIP) /= 0_int32) call clip_expanded(ctx, s%marker_size)
      call render_markers(ctx, g, s)
   endif
   call finish()
   endsubroutine line_item

   subroutine scatter_item(label, g, spec)
   !< `PlotScatterEx`: the markers (a marker forced: automatic when none).
   character(len=*),     intent(in)    :: label !< Label.
   type(item_series),    intent(inout) :: g     !< Getter.
   type(plot_item_spec), intent(in)    :: spec  !< Style.
   type(plot_item_ctx)                 :: ctx   !< The plot as the item sees it.
   type(item_style)                    :: s     !< Staged style.
   integer(int32)                      :: mk    !< Marker asked.

   mk = spec%marker
   if (mk == PF_MARKER_NONE) mk = PF_MARKER_AUTO
   if (.not. begin(label, spec, spec%marker_line_color, mk, ctx, s)) return
   if (fits(ctx, spec)) call fit1(g)
   if (g%n > 0_int32 .and. s%markers) then
      if (iand(spec%flags, PF_SCATTER_NO_CLIP) /= 0_int32) call clip_expanded(ctx, s%marker_size)
      call render_markers(ctx, g, s)
   endif
   call finish()
   endsubroutine scatter_item

   subroutine stairs_item(label, g, spec)
   !< `PlotStairsEx`: the shaded steps (`Shaded`), the steps (pre or post), the markers (clip expanded).
   character(len=*),     intent(in)    :: label !< Label.
   type(item_series),    intent(inout) :: g     !< Getter.
   type(plot_item_spec), intent(in)    :: spec  !< Style.
   type(plot_item_ctx)                 :: ctx   !< The plot as the item sees it.
   type(item_style)                    :: s     !< Staged style.
   logical                             :: pre   !< PreStep.

   if (.not. begin(label, spec, spec%line_color, spec%marker, ctx, s)) return
   call decimate_series(g, KIND_STAIRS, spec, ctx, iand(spec%flags, PF_STAIRS_SHADED) /= 0_int32)
   if (fits(ctx, spec)) call fit1(g)
   if (g%n <= 0_int32) then
      call finish()
      return
   endif
   pre = iand(spec%flags, PF_STAIRS_PRE_STEP) /= 0_int32
   if (g%n > 1_int32) then
      if (s%fill .and. iand(spec%flags, PF_STAIRS_SHADED) /= 0_int32) call render_stairs_shaded(ctx, g, s%col_fill, pre)
      if (s%line) call render_stairs(ctx, g, s%col_line, s%weight, pre)
   endif
   if (s%markers) then
      call clip_expanded(ctx, s%marker_size)
      call render_markers(ctx, g, s)
   endif
   call finish()
   endsubroutine stairs_item

   subroutine stems_item(label, g, ref, spec)
   !< `PlotStemsEx`: a segment from the base to each point, then the markers (clip expanded).
   character(len=*),     intent(in)           :: label !< Label.
   type(item_series),    intent(inout)        :: g     !< Getter (the marks).
   real(real64),         intent(in), optional :: ref   !< Base (default 0).
   type(plot_item_spec), intent(in)           :: spec  !< Style.
   type(plot_item_ctx)                        :: ctx   !< The plot as the item sees it.
   type(item_style)                           :: s     !< Staged style.
   type(item_series)                          :: b     !< Getter (the bases).
   real(real64)                               :: r     !< Base.

   r = 0.0_real64
   if (present(ref)) r = ref
   b = g
   if (iand(spec%flags, PF_STEMS_HORIZONTAL) /= 0_int32) then ! (ref, y)
      b%src(1) = SRC_CONST
      b%con(1) = r
   else ! (x, ref)
      b%src(2) = SRC_CONST
      b%con(2) = r
   endif
   if (.not. begin(label, spec, spec%line_color, spec%marker, ctx, s)) return
   if (fits(ctx, spec)) then
      call fit1(g)
      call fit1(b)
   endif
   if (g%n > 0_int32) then
      if (s%line) call render_segments2(ctx, g, b, s%col_line, s%weight)
      if (s%markers) then
         call clip_expanded(ctx, s%marker_size)
         call render_markers(ctx, g, s)
      endif
   endif
   call finish()
   endsubroutine stems_item

   subroutine shaded_item(label, g1, g2, spec, yref)
   !< `PlotShadedEx`: the area between two getters (the second's constant y, ±inf, the current y range's end).
   character(len=*),     intent(in)           :: label  !< Label.
   type(item_series),    intent(inout)        :: g1, g2 !< Getters.
   type(plot_item_spec), intent(in)           :: spec   !< Style.
   real(real64),         intent(in), optional :: yref   !< A reference line (g2's y).
   type(plot_item_ctx)                        :: ctx    !< The plot as the item sees it.
   type(item_style)                           :: s      !< Staged style.

   if (.not. begin(label, spec, spec%fill_color, PF_MARKER_INVALID, ctx, s)) return
   if (present(yref)) then ! (PlotShaded's GetPlotLimits: the current axes' range)
      if (yref < -huge(1.0_real64)) g2%con(2) = ctx%y_range(1)
      if (yref > huge(1.0_real64)) g2%con(2) = ctx%y_range(2)
   endif
   call decimate_pair(g1, g2, spec, ctx)
   if (fits(ctx, spec)) then
      call fit1(g1)
      call fit1(g2)
   endif
   if (g1%n > 0_int32 .and. g2%n > 0_int32 .and. s%fill) call render_shaded(ctx, g1, g2, s%col_fill)
   call finish()
   endsubroutine shaded_item

   ! private: BeginItem's style, the fit, EndItem

   function begin(label, spec, item_col, marker, ctx, s) result(shown)
   !< `BeginItem`: the item registered by the frame (its colour, marker, visibility, legend hover), the style staged,
   !< the item's clip pushed (the plot rectangle).
   character(len=*),     intent(in)  :: label       !< Label.
   type(plot_item_spec), intent(in)  :: spec        !< Style.
   real(real32),         intent(in)  :: item_col(4) !< The colour that sets the item's (alpha -1: automatic).
   integer(int32),       intent(in)  :: marker      !< The marker asked (PF_MARKER_INVALID: leave it).
   type(plot_item_ctx),  intent(out) :: ctx         !< The plot as the item sees it.
   type(item_style),     intent(out) :: s           !< Staged style.
   logical                           :: shown       !< Drawn.
   real(real32)                      :: ic(4), lc(4), fc(4), mlc(4), mfc(4) !< Colours.
   real(real64)                      :: v(2)        !< Style alpha.
   integer(int32)                    :: nv          !< Its count.
   real(real32)                      :: alpha       !< Style alpha.

   shown = pf_item_begin(label, item_col, marker, iand(spec%flags, PF_ITEM_NO_LEGEND) /= 0_int32, ctx)
   if (.not. shown) return
   ic = unpack_u32(ctx%color)
   lc = merge(ic, spec%line_color, is_auto(spec%line_color))
   fc = merge(ic, spec%fill_color, is_auto(spec%fill_color))
   fc(4) = fc(4) * spec%fill_alpha
   mlc = merge(lc, spec%marker_line_color, is_auto(spec%marker_line_color))
   mfc = merge(lc, spec%marker_fill_color, is_auto(spec%marker_fill_color))
   mfc(4) = mfc(4) * spec%fill_alpha
   s%weight = spec%line_weight
   s%marker_size = spec%marker_size
   s%size = spec%size
   s%marker = ctx%marker
   s%flags = spec%flags
   if (ctx%hovered) then
      s%weight = s%weight * HIGHLIGHT_LINE_SCALE
      s%marker_size = s%marker_size * HIGHLIGHT_MARK_SCALE
      s%size = s%size * HIGHLIGHT_MARK_SCALE
   endif
   s%line = lc(4) > 0.0_real32 .and. s%weight > 0.0_real32
   s%fill = fc(4) > 0.0_real32
   s%mline = mlc(4) > 0.0_real32 .and. s%weight > 0.0_real32
   s%mfill = mfc(4) > 0.0_real32
   s%markers = s%marker >= 0_int32 .and. (s%mfill .or. s%mline)
   call core_style_var('Alpha', v, nv)
   alpha = 1.0_real32
   if (nv > 0_int32) alpha = real(v(1), real32)
   s%col_line = color_u32(lc, alpha) ! GetColorU32(ImVec4): alpha times the style's
   s%col_fill = color_u32(fc, alpha)
   s%col_mline = color_u32(mlc, alpha)
   s%col_mfill = color_u32(mfc, alpha)
   call core_white_pixel(uv_white(1), uv_white(2))
   call core_push_clip_rect(real(ctx%rect(1), real64), real(ctx%rect(2), real64), real(ctx%rect(3), real64), &
                            real(ctx%rect(4), real64))
   endfunction begin

   subroutine finish()
   !< `EndItem`: the item's clip popped.

   call core_pop_clip_rect()
   call pf_item_end()
   endsubroutine finish

   pure function fits(ctx, spec) result(yes)
   !< `BeginItemEx`'s fit: the plot fits on this frame and the item is not `NoFit`.
   type(plot_item_ctx),  intent(in) :: ctx  !< The plot.
   type(plot_item_spec), intent(in) :: spec !< Style.
   logical                          :: yes  !< Fit.

   yes = ctx%fit .and. iand(spec%flags, PF_ITEM_NO_FIT) == 0_int32
   endfunction fits

   subroutine fit1(g)
   !< `Fitter1`: every point of a getter extends the fit (`ExtendFitWith`).
   type(item_series), intent(in) :: g  !< Getter.
   integer(int32)                :: i  !< Point.
   real(real64)                  :: x, y !< Point.

   do i = 1_int32, g%n
      call point(g, i, x, y)
      call pf_item_fit(x, y)
   enddo
   endsubroutine fit1

   subroutine clip_expanded(ctx, expand)
   !< `PopPlotClipRect(); PushPlotClipRect(expand)`: the plot rectangle grown by `expand` each side.
   type(plot_item_ctx), intent(in) :: ctx    !< The plot.
   real(real32),        intent(in) :: expand !< Growth [pixels].

   call core_pop_clip_rect()
   call core_push_clip_rect(real(ctx%rect(1) - expand, real64), real(ctx%rect(2) - expand, real64), &
                            real(ctx%rect(3) + expand, real64), real(ctx%rect(4) + expand, real64))
   endsubroutine clip_expanded

   function spec_or_default(spec) result(s)
   !< The style given, or ImPlot's defaults.
   type(plot_item_spec), intent(in), optional :: spec !< Style.
   type(plot_item_spec)                       :: s    !< Style.

   if (present(spec)) s = spec
   endfunction spec_or_default

   ! private: the getters

   subroutine view_r64(g, k, a)
   !< Coordinate k (1 x, 2 y) of a getter from a real64 array, in place.
   type(item_series),    intent(inout) :: g    !< Getter.
   integer(int32),       intent(in)    :: k    !< Coordinate.
   real(real64), target, intent(in), asynchronous    :: a(:) !< Array.

   g%src(k) = SRC_R64
   if (k == 1_int32) then
      g%a64 => a
   else
      g%b64 => a
   endif
   endsubroutine view_r64

   subroutine view_r32(g, k, a)
   !< Coordinate k of a getter from a real32 array, in place.
   type(item_series),    intent(inout) :: g    !< Getter.
   integer(int32),       intent(in)    :: k    !< Coordinate.
   real(real32), target, intent(in), asynchronous    :: a(:) !< Array.

   g%src(k) = SRC_R32
   if (k == 1_int32) then
      g%a32 => a
   else
      g%b32 => a
   endif
   endsubroutine view_r32

   subroutine view_i32(g, a, via32, k)
   !< The abscissae of a getter from an int32 array: each converted as FIGURE's API converts them (to the ordinates'
   !< kind), then to double.
   type(item_series),      intent(inout) :: g     !< Getter.
   integer(int32), target, intent(in), asynchronous    :: a(:)  !< Array.
   logical,                intent(in)    :: via32 !< Single precision ordinates.
   integer(int32),         intent(in), optional :: k !< Coordinate (default 1: the abscissae).

   g%src(1) = SRC_I32
   if (present(k)) then
      g%src(1) = SRC_NONE
      g%src(k) = SRC_I32
   endif
   g%ai32 => a
   g%via32 = via32
   endsubroutine view_i32

   subroutine view_i64(g, a, via32, k)
   !< The abscissae of a getter from an int64 array (as `view_i32`).
   type(item_series),      intent(inout) :: g     !< Getter.
   integer(int64), target, intent(in), asynchronous    :: a(:)  !< Array.
   logical,                intent(in)    :: via32 !< Single precision ordinates.
   integer(int32),         intent(in), optional :: k !< Coordinate (default 1: the abscissae).

   g%src(1) = SRC_I64
   if (present(k)) then
      g%src(1) = SRC_NONE
      g%src(k) = SRC_I64
   endif
   g%ai64 => a
   g%via32 = via32
   endsubroutine view_i64

   subroutine view_lin(g, k, x0, dx)
   !< Coordinate k of a getter uniform: x0 + i dx, i from 0 (`IndexerLin(xscale, x0)`).
   type(item_series), intent(inout)        :: g  !< Getter.
   integer(int32),    intent(in)           :: k  !< Coordinate.
   real(real64),      intent(in), optional :: x0 !< Start (default 0).
   real(real64),      intent(in), optional :: dx !< Spacing (default 1).

   g%src(k) = SRC_LIN
   g%lin(:, k) = [0.0_real64, 1.0_real64]
   if (present(x0)) g%lin(1, k) = x0
   if (present(dx)) g%lin(2, k) = dx
   endsubroutine view_lin

   subroutine view_const(g, k, c)
   !< Coordinate k of a getter constant (`IndexerConst`).
   type(item_series), intent(inout) :: g !< Getter.
   integer(int32),    intent(in)    :: k !< Coordinate.
   real(real64),      intent(in)    :: c !< Value.

   g%src(k) = SRC_CONST
   g%con(k) = c
   endsubroutine view_const

   subroutine point(g, i, x, y)
   !< The i-th point of a getter (i from 1; through the kept indices when decimated), as double.
   type(item_series), intent(in)  :: g    !< Getter.
   integer(int32),    intent(in)  :: i    !< Point.
   real(real64),      intent(out) :: x, y !< Coordinates.
   integer(int64)                 :: j    !< Index into the arrays.

   j = int(i, int64)
   if (g%kept) j = keep(i)
   x = coordinate(g, 1_int32, j)
   y = coordinate(g, 2_int32, j)
   endsubroutine point

   function coordinate(g, k, j) result(v)
   !< Coordinate k of the j-th element of a getter's arrays.
   type(item_series), intent(in) :: g !< Getter.
   integer(int32),    intent(in) :: k !< Coordinate.
   integer(int64),    intent(in) :: j !< Element (from 1).
   real(real64)                  :: v !< Value.
   real(real64)                  :: w !< Product.

   select case (g%src(k))
   case (SRC_R64)
      if (k == 1_int32) then
         v = g%a64(j)
      else
         v = g%b64(j)
      endif
   case (SRC_R32)
      if (k == 1_int32) then
         v = real(g%a32(j), real64)
      else
         v = real(g%b32(j), real64)
      endif
   case (SRC_I32)
      if (g%via32) then
         v = real(real(g%ai32(j), real32), real64)
      else
         v = real(g%ai32(j), real64)
      endif
   case (SRC_I64)
      if (g%via32) then
         v = real(real(g%ai64(j), real32), real64)
      else
         v = real(g%ai64(j), real64)
      endif
   case (SRC_LIN) ! M idx + B, idx from 0 (the product apart: no FMA)
      w = g%lin(2, k) * real(j - 1_int64, real64)
      v = w + g%lin(1, k)
   case (SRC_CONST)
      v = g%con(k)
   case default
      v = 0.0_real64
   endselect
   endfunction coordinate

   subroutine pixel(ctx, g, i, p)
   !< The pixel of a getter's i-th point (`Transformer2`).
   type(plot_item_ctx), intent(in)  :: ctx  !< The plot.
   type(item_series),   intent(in)  :: g    !< Getter.
   integer(int32),      intent(in)  :: i    !< Point.
   real(real32),        intent(out) :: p(2) !< Pixel.
   real(real64)                     :: x, y !< Point.

   call point(g, i, x, y)
   p(1) = map_pixel(ctx%tx, x)
   p(2) = map_pixel(ctx%ty, y)
   endsubroutine pixel

   subroutine pixel_block(ctx, g, i0, n, px, py)
   !< The pixels of a getter's points i0 .. i0 + n - 1 (n at most PIX_BLOCK), as `pixel` gives each: per coordinate the
   !< values read (`coordinates`), then mapped (`map_block`), each choosing its source or scale once for the block.
   type(plot_item_ctx), intent(in)  :: ctx    !< The plot.
   type(item_series),   intent(in)  :: g      !< Getter.
   integer(int32),      intent(in)  :: i0     !< First point (from 1).
   integer(int32),      intent(in)  :: n      !< Points.
   real(real32),        intent(out) :: px(n)  !< Pixels' x.
   real(real32),        intent(out) :: py(n)  !< Pixels' y.
   real(real64)                     :: v(PIX_BLOCK) !< A coordinate's values.

   call coordinates(g, 1_int32, i0, n, v)
   call map_block(ctx%tx, v, n, px)
   call coordinates(g, 2_int32, i0, n, v)
   call map_block(ctx%ty, v, n, py)
   endsubroutine pixel_block

   subroutine read_point(rd, g, i, x, y)
   !< The i-th point of a getter, as `point` gives it, from the reader's block: read again (`coordinates`) from point i
   !< when i is outside it, so a loop running forward reads each block once.
   type(point_reader), intent(inout) :: rd   !< Reader.
   type(item_series),  intent(in)    :: g    !< Getter.
   integer(int32),     intent(in)    :: i    !< Point (from 1).
   real(real64),       intent(out)   :: x, y !< Coordinates.

   if (i < rd%i0 .or. i >= rd%i0 + rd%n) then
      rd%i0 = i
      rd%n = max(1_int32, min(PIX_BLOCK, g%n - i + 1_int32))
      call coordinates(g, 1_int32, rd%i0, rd%n, rd%x)
      call coordinates(g, 2_int32, rd%i0, rd%n, rd%y)
   endif
   x = rd%x(i - rd%i0 + 1_int32)
   y = rd%y(i - rd%i0 + 1_int32)
   endsubroutine read_point

   subroutine read_pixel(rd, ctx, g, i, p)
   !< The pixel of a getter's i-th point, as `pixel` gives it, from the reader's block (mapped again by `pixel_block`
   !< from point i when i is outside it).
   type(pixel_reader),  intent(inout) :: rd   !< Reader.
   type(plot_item_ctx), intent(in)    :: ctx  !< The plot.
   type(item_series),   intent(in)    :: g    !< Getter.
   integer(int32),      intent(in)    :: i    !< Point (from 1).
   real(real32),        intent(out)   :: p(2) !< Pixel.

   if (i < rd%i0 .or. i >= rd%i0 + rd%n) then
      rd%i0 = i
      rd%n = max(1_int32, min(PIX_BLOCK, g%n - i + 1_int32))
      call pixel_block(ctx, g, rd%i0, rd%n, rd%x, rd%y)
   endif
   p(1) = rd%x(i - rd%i0 + 1_int32)
   p(2) = rd%y(i - rd%i0 + 1_int32)
   endsubroutine read_pixel

   subroutine coordinates(g, k, i0, n, v)
   !< Coordinate k of a getter's points i0 .. i0 + n - 1 (through the kept indices when decimated), as `coordinate`
   !< gives each: the source chosen once, then a loop of its read (a contiguous array's by `read_r64`, `read_r32`).
   type(item_series), intent(in)  :: g      !< Getter.
   integer(int32),    intent(in)  :: k      !< Coordinate.
   integer(int32),    intent(in)  :: i0     !< First point (from 1).
   integer(int32),    intent(in)  :: n      !< Points.
   real(real64),      intent(out) :: v(n)   !< Values.
   real(real64), pointer          :: a64(:) !< The coordinate's real64 array.
   real(real32), pointer          :: a32(:) !< ... real32 array.
   real(real64), pointer, contiguous :: c64(:) !< ... when contiguous.
   real(real32), pointer, contiguous :: c32(:) !< ...
   real(real64)                   :: x0, dx, w !< A uniform coordinate's start and spacing, a product.
   integer(int64)                 :: j0     !< Element before the first.
   integer(int32)                 :: m      !< Point of the block.

   if (k == 1_int32) then
      a64 => g%a64
      a32 => g%a32
   else
      a64 => g%b64
      a32 => g%b32
   endif
   x0 = g%lin(1, k)
   dx = g%lin(2, k)
   if (g%kept) then
      select case (g%src(k))
      case (SRC_R64)
         do m = 1_int32, n
            v(m) = a64(keep(i0 + m - 1_int32))
         enddo
      case (SRC_R32)
         do m = 1_int32, n
            v(m) = real(a32(keep(i0 + m - 1_int32)), real64)
         enddo
      case (SRC_I32)
         if (g%via32) then
            do m = 1_int32, n
               v(m) = real(real(g%ai32(keep(i0 + m - 1_int32)), real32), real64)
            enddo
         else
            do m = 1_int32, n
               v(m) = real(g%ai32(keep(i0 + m - 1_int32)), real64)
            enddo
         endif
      case (SRC_I64)
         if (g%via32) then
            do m = 1_int32, n
               v(m) = real(real(g%ai64(keep(i0 + m - 1_int32)), real32), real64)
            enddo
         else
            do m = 1_int32, n
               v(m) = real(g%ai64(keep(i0 + m - 1_int32)), real64)
            enddo
         endif
      case (SRC_LIN) ! M idx + B, idx from 0 (the product apart: no FMA)
         do m = 1_int32, n
            w = dx * real(keep(i0 + m - 1_int32) - 1_int64, real64)
            v(m) = w + x0
         enddo
      case (SRC_CONST)
         v(1:n) = g%con(k)
      case default
         v(1:n) = 0.0_real64
      endselect
   else
      j0 = int(i0, int64) - 1_int64
      select case (g%src(k))
      case (SRC_R64)
         if (is_contiguous(a64)) then
            c64 => a64
            call read_r64(c64, j0, n, v)
         else
            do m = 1_int32, n
               v(m) = a64(j0 + m)
            enddo
         endif
      case (SRC_R32)
         if (is_contiguous(a32)) then
            c32 => a32
            call read_r32(c32, j0, n, v)
         else
            do m = 1_int32, n
               v(m) = real(a32(j0 + m), real64)
            enddo
         endif
      case (SRC_I32)
         if (g%via32) then
            do m = 1_int32, n
               v(m) = real(real(g%ai32(j0 + m), real32), real64)
            enddo
         else
            do m = 1_int32, n
               v(m) = real(g%ai32(j0 + m), real64)
            enddo
         endif
      case (SRC_I64)
         if (g%via32) then
            do m = 1_int32, n
               v(m) = real(real(g%ai64(j0 + m), real32), real64)
            enddo
         else
            do m = 1_int32, n
               v(m) = real(g%ai64(j0 + m), real64)
            enddo
         endif
      case (SRC_LIN) ! M idx + B, idx from 0 (the product apart: no FMA)
         do m = 1_int32, n
            w = dx * real(j0 + m - 1_int64, real64)
            v(m) = w + x0
         enddo
      case (SRC_CONST)
         v(1:n) = g%con(k)
      case default
         v(1:n) = 0.0_real64
      endselect
   endif
   endsubroutine coordinates

   subroutine read_r64(a, j0, n, v)
   !< v(m) = a(j0 + m), m = 1 .. n, from a contiguous array: a dummy of unit stride, which gfortran vectorises (a
   !< pointer's elements it reads through the pointer's span, one at a time); the actual a contiguous pointer, so no
   !< copy is made.
   real(real64),   contiguous, intent(in)  :: a(:) !< Array.
   integer(int64),             intent(in)  :: j0   !< Element before the first.
   integer(int32),             intent(in)  :: n    !< Values.
   real(real64),               intent(out) :: v(n) !< Values.
   integer(int32)                          :: m    !< Value.

   do m = 1_int32, n
      v(m) = a(j0 + m)
   enddo
   endsubroutine read_r64

   subroutine read_r32(a, j0, n, v)
   !< v(m) = a(j0 + m) as double, m = 1 .. n, from a contiguous array (as `read_r64`).
   real(real32),   contiguous, intent(in)  :: a(:) !< Array.
   integer(int64),             intent(in)  :: j0   !< Element before the first.
   integer(int32),             intent(in)  :: n    !< Values.
   real(real64),               intent(out) :: v(n) !< Values.
   integer(int32)                          :: m    !< Value.

   do m = 1_int32, n
      v(m) = real(a(j0 + m), real64)
   enddo
   endsubroutine read_r32

   subroutine map_block(a, v, n, px)
   !< The pixels of n values on an axis, as `map_pixel` gives each (`Transformer1`): a linear (or time) axis's constants
   !< hoisted and its arithmetic in a loop, in `map_pixel`'s order (the product in a statement of its own: no FMA); a
   !< log10 or symlog axis through `map_pixel`.
   type(plot_axis_map), intent(in)  :: a     !< Axis.
   integer(int32),      intent(in)  :: n     !< Values.
   real(real64),        intent(in)  :: v(n)  !< Values.
   real(real32),        intent(out) :: px(n) !< Pixels.
   real(real64)                     :: pix_min, plt_min, s, w !< The axis's PixelMin, PltMin, ScaleToPixel; a product.
   integer(int32)                   :: m     !< Value.

   if (a%scale == MAP_LOG10 .or. a%scale == MAP_SYMLOG) then
      do m = 1_int32, n
         px(m) = map_pixel(a, v(m))
      enddo
   else
      pix_min = a%pix_min
      plt_min = a%plt_min
      s = a%m
      do m = 1_int32, n
         w = s * (v(m) - plt_min)
         px(m) = real(pix_min + w, real32)
      enddo
   endif
   endsubroutine map_block

   ! private: the decimation (figure_implot's series_decimate)

   subroutine decimate_series(g, item, spec, ctx, fill)
   !< Decimate a line-like getter (figure_decimate, M4 per pixel column) when it has more than DECIMATE_THRESHOLD points
   !< a column: its kept points read through `keep`. Not decimated: decimation off, few points, markers, `Segments`,
   !< `Loop`, unsorted abscissae. With `pf_cache_next_item`, through the series' cache.
   type(item_series),    intent(inout) :: g     !< Getter.
   integer(int32),       intent(in)    :: item  !< KIND_LINE, KIND_STAIRS, KIND_SHADED.
   type(plot_item_spec), intent(in)    :: spec  !< Style.
   type(plot_item_ctx),  intent(in)    :: ctx   !< The plot.
   logical,              intent(in)    :: fill  !< The item fills an area.
   type(item_series)                   :: none  !< No second ordinates.

   call decimate_getters(g, none, .false., item, spec, ctx, fill)
   endsubroutine decimate_series

   subroutine decimate_pair(g1, g2, spec, ctx)
   !< Decimate a shaded item's two getters together (the second's y as the second ordinates; a reference line: y alone).
   type(item_series),    intent(inout) :: g1, g2 !< Getters.
   type(plot_item_spec), intent(in)    :: spec   !< Style.
   type(plot_item_ctx),  intent(in)    :: ctx    !< The plot.

   call decimate_getters(g1, g2, g2%src(2) /= SRC_CONST, KIND_SHADED, spec, ctx, .true.)
   if (g1%kept) then
      g2%kept = .true.
      g2%n = g1%n
   endif
   endsubroutine decimate_pair

   subroutine decimate_getters(g, g2, two, item, spec, ctx, fill)
   !< `series_decimate`: the cache asked for (`pf_cache_next_item`) found or made for the series' identity, then the
   !< decimation of g (and g2's y as the second ordinates when `two`), its kept points read through `keep`.
   type(item_series),    intent(inout) :: g, g2 !< Getters.
   logical,              intent(in)    :: two   !< g2's y as second ordinates.
   integer(int32),       intent(in)    :: item  !< KIND_*.
   type(plot_item_spec), intent(in)    :: spec  !< Style.
   type(plot_item_ctx),  intent(in)    :: ctx   !< The plot.
   logical,              intent(in)    :: fill  !< Fill.
   type(decimate_axis)                 :: ax    !< The x axis.
   integer(int64)                      :: nk    !< Points kept.
   integer(int32)                      :: c     !< Cache (0: none).
   logical                             :: dec, fresh !< Decimated, the data changed.

   c = 0_int32
   if (next_cached) then
      fresh = next_changed
      next_cached = .false.
      if (wanted(g, item, spec, ctx, ax)) c = cache_slot(g, g2, two, item, fresh)
   endif
   if (c == 0_int32) then
      if (.not. wanted(g, item, spec, ctx, ax)) return
      call decimate_any(ax, g, g2, two, fill, nk, dec)
   else
      call decimate_any(ax, g, g2, two, fill, nk, dec, caches(c)%dc)
   endif
   if (.not. dec) return
   g%kept = .true.
   g%n = int(nk, int32)
   plot_decimated = plot_decimated + 1_int64
   plot_kept = nk
   pf_last_decimated = .true.
   endsubroutine decimate_getters

   subroutine decimate_any(ax, g, g2, two, fill, nk, dec, dc)
   !< `decimate` over a getter's sources (r32/r64 ordinates; r32/r64/integer/uniform abscissae, integer ones converted
   !< into the kept buffer), g2's y as the second ordinates when `two`, through a cache when given.
   type(decimate_axis),  intent(in)              :: ax    !< The x axis.
   type(item_series),    intent(in)              :: g, g2 !< Getters.
   logical,              intent(in)              :: two   !< Second ordinates.
   logical,              intent(in)              :: fill  !< Fill.
   integer(int64),       intent(out)             :: nk    !< Points kept.
   logical,              intent(out)             :: dec   !< Decimated.
   type(decimate_cache), intent(inout), optional :: dc    !< The series' cache.

   dec = .false.
   nk = 0_int64
   select case (g%src(2))
   case (SRC_R64)
      select case (g%src(1))
      case (SRC_R64)
         if (two) then
            dec = decimate(ax, g%a64(1:g%n), g%b64(1:g%n), keep, nk, y2=g2%b64(1:g%n), fill=fill, cache=dc)
         else
            dec = decimate(ax, g%a64(1:g%n), g%b64(1:g%n), keep, nk, fill=fill, cache=dc)
         endif
      case (SRC_LIN)
         if (two) then
            dec = decimate(ax, g%lin(1, 1), g%lin(2, 1), g%b64(1:g%n), keep, nk, y2=g2%b64(1:g%n), fill=fill, &
                           cache=dc)
         else
            dec = decimate(ax, g%lin(1, 1), g%lin(2, 1), g%b64(1:g%n), keep, nk, fill=fill, cache=dc)
         endif
      case default
         call convert64(g)
         if (two) then
            dec = decimate(ax, conv64(1:g%n), g%b64(1:g%n), keep, nk, y2=g2%b64(1:g%n), fill=fill, cache=dc)
         else
            dec = decimate(ax, conv64(1:g%n), g%b64(1:g%n), keep, nk, fill=fill, cache=dc)
         endif
      endselect
   case (SRC_R32)
      select case (g%src(1))
      case (SRC_R32)
         if (two) then
            dec = decimate(ax, g%a32(1:g%n), g%b32(1:g%n), keep, nk, y2=g2%b32(1:g%n), fill=fill, cache=dc)
         else
            dec = decimate(ax, g%a32(1:g%n), g%b32(1:g%n), keep, nk, fill=fill, cache=dc)
         endif
      case (SRC_LIN)
         if (two) then
            dec = decimate(ax, g%lin(1, 1), g%lin(2, 1), g%b32(1:g%n), keep, nk, y2=g2%b32(1:g%n), fill=fill, &
                           cache=dc)
         else
            dec = decimate(ax, g%lin(1, 1), g%lin(2, 1), g%b32(1:g%n), keep, nk, fill=fill, cache=dc)
         endif
      case default
         call convert32(g)
         if (two) then
            dec = decimate(ax, conv32(1:g%n), g%b32(1:g%n), keep, nk, y2=g2%b32(1:g%n), fill=fill, cache=dc)
         else
            dec = decimate(ax, conv32(1:g%n), g%b32(1:g%n), keep, nk, fill=fill, cache=dc)
         endif
      endselect
   case default
   endselect
   endsubroutine decimate_any

   subroutine pf_cache_next_item(changed)
   !< The next `pf_line`, `pf_stairs` or `pf_shaded` keeps what its decimation computes of its data between frames
   !< (`ip_cache_next_item`); `changed`: the program changed the values since that item's last frame.
   logical, intent(in) :: changed !< The values changed.

   next_cached = .true.
   next_changed = changed
   endsubroutine pf_cache_next_item

   function cache_slot(g, g2, two, item, changed) result(c)
   !< figure_implot's `cache_slot`: the cache of a series by its data's identity (the arrays' addresses, points,
   !< stride, kind, item, uniform abscissae), else a free slot or the least recently used; invalidated when changed;
   !< the caches idle CACHE_IDLE seconds released.
   type(item_series), intent(in) :: g, g2   !< Getters.
   logical,           intent(in) :: two     !< g2's y used.
   integer(int32),    intent(in) :: item    !< KIND_*.
   logical,           intent(in) :: changed !< Values changed.
   integer(int32)                :: c       !< Cache.
   integer(c_intptr_t)           :: p(3)    !< Addresses of x, y, y2 (0: none).
   integer(int64)                :: stride  !< y's stride [bytes].
   integer(int32)                :: kind, k !< Bytes of a value, counter.
   real(real64)                  :: now, ux0, udx !< Time, uniform abscissae.
   logical                       :: uniform, same !< Uniform abscissae, the same data.

   now = core_time()
   call identity(g, g2, two, p, stride, kind)
   uniform = g%src(1) == SRC_LIN
   ux0 = 0.0_real64
   udx = 0.0_real64
   if (uniform) then
      ux0 = g%lin(1, 1)
      udx = g%lin(2, 1)
   endif
   c = 0_int32
   do k = 1_int32, CACHE_SLOTS
      if (.not. caches(k)%used) cycle
      if (now - caches(k)%last_time > CACHE_IDLE .or. now < caches(k)%last_time) then
         call cache_release(k)
         cycle
      endif
      if (c == 0_int32) then
         same = all(caches(k)%p == p) .and. caches(k)%n == int(g%n, int64) .and. caches(k)%stride == stride .and. &
                caches(k)%kind == kind .and. caches(k)%item == item .and. (caches(k)%uniform .eqv. uniform) .and. &
                caches(k)%x0 == ux0 .and. caches(k)%dx == udx
         if (same) c = k
      endif
   enddo
   if (c > 0_int32) then
      if (changed) then
         caches(c)%dc%valid = .false.
         plot_cache_builds = plot_cache_builds + 1_int64
      else
         plot_cache_hits = plot_cache_hits + 1_int64
      endif
      caches(c)%last_time = now
      return
   endif
   c = 1_int32
   do k = 1_int32, CACHE_SLOTS
      if (.not. caches(k)%used) then
         c = k
         exit
      endif
      if (caches(k)%last_time < caches(c)%last_time) c = k
   enddo
   if (caches(c)%used) call cache_release(c)
   caches(c)%used = .true.
   caches(c)%p = p
   caches(c)%n = int(g%n, int64)
   caches(c)%stride = stride
   caches(c)%kind = kind
   caches(c)%item = item
   caches(c)%uniform = uniform
   caches(c)%x0 = ux0
   caches(c)%dx = udx
   caches(c)%last_time = now
   caches(c)%dc%valid = .false.
   plot_cache_builds = plot_cache_builds + 1_int64
   endfunction cache_slot

   subroutine identity(g, g2, two, p, stride, kind)
   !< A series' identity: the addresses of its x, y and second y arrays (0 for none: uniform, constant), y's stride and
   !< kind.
   type(item_series),   intent(in)  :: g, g2 !< Getters.
   logical,             intent(in)  :: two   !< Second ordinates.
   integer(c_intptr_t), intent(out) :: p(3)  !< Addresses.
   integer(int64),      intent(out) :: stride !< y's stride [bytes].
   integer(int32),      intent(out) :: kind  !< Bytes of a value.

   p = 0_c_intptr_t
   stride = 0_int64
   kind = 8_int32
   if (g%n < 1_int32) return
   select case (g%src(1))
   case (SRC_R64)
      p(1) = transfer(c_loc(g%a64(1)), p(1))
   case (SRC_R32)
      p(1) = transfer(c_loc(g%a32(1)), p(1))
   case (SRC_I32)
      p(1) = transfer(c_loc(g%ai32(1)), p(1))
   case (SRC_I64)
      p(1) = transfer(c_loc(g%ai64(1)), p(1))
   case default
   endselect
   select case (g%src(2))
   case (SRC_R64)
      p(2) = transfer(c_loc(g%b64(1)), p(2))
      if (g%n > 1_int32) stride = int(transfer(c_loc(g%b64(2)), p(2)) - p(2), int64)
   case (SRC_R32)
      p(2) = transfer(c_loc(g%b32(1)), p(2))
      if (g%n > 1_int32) stride = int(transfer(c_loc(g%b32(2)), p(2)) - p(2), int64)
      kind = 4_int32
   case default
   endselect
   if (two) then
      select case (g2%src(2))
      case (SRC_R64)
         p(3) = transfer(c_loc(g2%b64(1)), p(3))
      case (SRC_R32)
         p(3) = transfer(c_loc(g2%b32(1)), p(3))
      case default
      endselect
   endif
   endsubroutine identity

   subroutine cache_release(k)
   !< A cache's memory and slot freed.
   integer(int32), intent(in) :: k !< Slot.
   integer(int32)             :: o !< Ordinate.

   do o = 1_int32, 2_int32
      if (allocated(caches(k)%dc%py(o)%first)) deallocate(caches(k)%dc%py(o)%first)
      if (allocated(caches(k)%dc%py(o)%imin)) deallocate(caches(k)%dc%py(o)%imin)
      if (allocated(caches(k)%dc%py(o)%imax)) deallocate(caches(k)%dc%py(o)%imax)
      if (allocated(caches(k)%dc%py(o)%gap)) deallocate(caches(k)%dc%py(o)%gap)
      caches(k)%dc%py(o)%n = 0_int64
   enddo
   caches(k)%dc%valid = .false.
   caches(k)%dc%sorted = .false.
   caches(k)%used = .false.
   caches(k)%p = 0_c_intptr_t
   caches(k)%n = 0_int64
   endsubroutine cache_release

   subroutine pf_cache_counts(builds, hits)
   !< The caches built (data new or changed) and reused since the start (tests: figure_implot's plot_cache_builds,
   !< plot_cache_hits).
   integer(int64), intent(out) :: builds, hits !< Counts.

   builds = plot_cache_builds
   hits = plot_cache_hits
   endsubroutine pf_cache_counts

   subroutine pf_line_device_r64(label, x, y, spec, ierr)
   !< A line through (x(i), y(i)) of two contiguous real64 arrays on a device (`ip_line_device`): decimated there
   !< (figure_decimate_device, FUNDAL), only the kept points copied to the host; a series not decimated copied whole.
   !< The array dummies are not ASYNCHRONOUS, unlike the other items': nvfortran 26.9 copies an ASYNCHRONOUS dummy
   !< passed on to a dummy that is not (here figure_decimate_device's and FUNDAL's dev_memcpy_from_device), on the host,
   !< and the device's memory cannot be read there (szaghi/figure#16 S5: tests-nvf-acc-fortran crashed).
   character(len=*),     intent(in)           :: label !< Legend label.
   real(real64),         intent(in), target :: x(:)  !< Abscissae, on the device (not ASYNCHRONOUS: pf_line_device_r64).
   real(real64),         intent(in), target :: y(:)  !< Ordinates, on the device.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   integer(int32),       intent(out), optional :: ierr !< FUNDAL's status of a copy from the device (absent: a failure
                                                       !< stops; present: nothing drawn on a failure).
   type(plot_item_spec)                       :: sp    !< Style.
   type(plot_item_ctx)                        :: ctx   !< The plot (for the decimation's axis).
   type(decimate_axis)                        :: ax    !< The x axis.
   type(item_series)                          :: g     !< A getter of n points (the decimation's test).
   integer(int64)                             :: nk    !< Points drawn.
   integer(int32)                             :: ie    !< FUNDAL's status.
   logical                                    :: done  !< Decimated.

   sp = spec_or_default(spec)
   call pf_plot_ctx(ctx)
   g%n = int(min(size(x), size(y)), int32)
   done = .false.
   ie = 0_int32
   if (wanted(g, KIND_LINE, sp, ctx, ax)) done = decimate_device_r64(ax, x, y, dev64x, dev64y, nk, ie)
   if (.not. done .and. ie == 0_int32) then ! every point, copied
      nk = int(g%n, int64)
      call dev_room64(nk)
      if (nk > 0_int64) call dev_memcpy_from_device(dst=dev64x(1:nk), src=x, ierr=ie)
      if (nk > 0_int64 .and. ie == 0_int32) call dev_memcpy_from_device(dst=dev64y(1:nk), src=y, ierr=ie)
   elseif (done) then
      plot_decimated = plot_decimated + 1_int64
      plot_kept = nk
   endif
   if (present(ierr)) ierr = ie
   if (ie /= 0_int32) then
      if (present(ierr)) return
      error stop 'figure_plot_items: pf_line_device: a copy from the device failed'
   endif
   g = item_series()
   call view_r64(g, 1_int32, dev64x(1:nk))
   call view_r64(g, 2_int32, dev64y(1:nk))
   g%n = int(nk, int32)
   skip_decimation = .true. ! (the points are the kept ones: ImPlot draws them as they are)
   call line_item(label, g, sp)
   skip_decimation = .false.
   endsubroutine pf_line_device_r64

   subroutine pf_line_device_r32(label, x, y, spec, ierr)
   !< A line of two contiguous real32 device arrays (`ip_line_device`), as `pf_line_device_r64`.
   character(len=*),     intent(in)           :: label !< Legend label.
   real(real32),         intent(in), target :: x(:)  !< Abscissae, on the device (not ASYNCHRONOUS: pf_line_device_r64).
   real(real32),         intent(in), target :: y(:)  !< Ordinates, on the device.
   type(plot_item_spec), intent(in), optional :: spec  !< Style.
   integer(int32),       intent(out), optional :: ierr !< FUNDAL's status of a copy from the device (absent: a failure
                                                       !< stops; present: nothing drawn on a failure).
   type(plot_item_spec)                       :: sp    !< Style.
   type(plot_item_ctx)                        :: ctx   !< The plot.
   type(decimate_axis)                        :: ax    !< The x axis.
   type(item_series)                          :: g     !< A getter of n points.
   integer(int64)                             :: nk    !< Points drawn.
   integer(int32)                             :: ie    !< FUNDAL's status.
   logical                                    :: done  !< Decimated.

   sp = spec_or_default(spec)
   call pf_plot_ctx(ctx)
   g%n = int(min(size(x), size(y)), int32)
   done = .false.
   ie = 0_int32
   if (wanted(g, KIND_LINE, sp, ctx, ax)) done = decimate_device_r32(ax, x, y, dev32x, dev32y, nk, ie)
   if (.not. done .and. ie == 0_int32) then
      nk = int(g%n, int64)
      call dev_room32(nk)
      if (nk > 0_int64) call dev_memcpy_from_device(dst=dev32x(1:nk), src=x, ierr=ie)
      if (nk > 0_int64 .and. ie == 0_int32) call dev_memcpy_from_device(dst=dev32y(1:nk), src=y, ierr=ie)
   elseif (done) then
      plot_decimated = plot_decimated + 1_int64
      plot_kept = nk
   endif
   if (present(ierr)) ierr = ie
   if (ie /= 0_int32) then
      if (present(ierr)) return
      error stop 'figure_plot_items: pf_line_device: a copy from the device failed'
   endif
   g = item_series()
   call view_r32(g, 1_int32, dev32x(1:nk))
   call view_r32(g, 2_int32, dev32y(1:nk))
   g%n = int(nk, int32)
   skip_decimation = .true.
   call line_item(label, g, sp)
   skip_decimation = .false.
   endsubroutine pf_line_device_r32

   subroutine dev_room64(n)
   !< Room for n points in the device line's host buffers (kept, grown).
   integer(int64), intent(in) :: n !< Points.

   if (allocated(dev64x)) then
      if (size(dev64x, kind=int64) < n) deallocate(dev64x, dev64y)
   endif
   if (.not. allocated(dev64x)) allocate(dev64x(max(n, 1024_int64)), dev64y(max(n, 1024_int64)))
   endsubroutine dev_room64

   subroutine dev_room32(n)
   !< Room for n points in the device line's host buffers, single precision.
   integer(int64), intent(in) :: n !< Points.

   if (allocated(dev32x)) then
      if (size(dev32x, kind=int64) < n) deallocate(dev32x, dev32y)
   endif
   if (.not. allocated(dev32x)) allocate(dev32x(max(n, 1024_int64)), dev32y(max(n, 1024_int64)))
   endsubroutine dev_room32

   function wanted(g, item, spec, ctx, ax) result(yes)
   !< Whether a getter may be decimated (figure_implot's `decimation_wanted`), and the x axis as its points map to
   !< pixels.
   type(item_series),    intent(in)  :: g    !< Getter.
   integer(int32),       intent(in)  :: item !< KIND_LINE, KIND_STAIRS, KIND_SHADED.
   type(plot_item_spec), intent(in)  :: spec !< Style.
   type(plot_item_ctx),  intent(in)  :: ctx  !< The plot.
   type(decimate_axis),  intent(out) :: ax   !< The x axis.
   logical                           :: yes  !< Decimate.
   real(real64)                      :: sx, sy !< Framebuffer scale.

   yes = .false.
   if (skip_decimation) return
   if (.not. decimation_on .or. int(g%n, int64) <= int(DECIMATE_THRESHOLD, int64)) return
   if (spec%marker /= PF_MARKER_NONE) return
   if (item == KIND_LINE .and. iand(spec%flags, ior(PF_LINE_SEGMENTS, PF_LINE_LOOP)) /= 0_int32) return
   select case (ctx%tx%scale)
   case (MAP_LINEAR, MAP_TIME)
      ax%scale = DECIMATE_LINEAR
   case (MAP_LOG10)
      ax%scale = DECIMATE_LOG10
   case (MAP_SYMLOG)
      ax%scale = DECIMATE_SYMLOG
   case default
      return
   endselect
   call core_framebuffer_scale(sx, sy)
   ax%pix_min = ctx%tx%pix_min
   ax%plt_min = ctx%tx%plt_min
   ax%plt_max = ctx%tx%plt_max
   ax%m = ctx%tx%m
   ax%sca_min = ctx%tx%sca_min
   ax%sca_max = ctx%tx%sca_max
   ax%left = real(ctx%rect(1), real64)
   ax%right = real(ctx%rect(3), real64)
   ax%fb_scale = sx
   ax%reach = 0.5_real64 * max(1.0_real64, real(spec%line_weight, real64)) + 1.5_real64
   yes = .true.
   endfunction wanted

   subroutine convert64(g)
   !< Integer abscissae converted into the kept double buffer (grown when short), for the decimation.
   type(item_series), intent(in) :: g !< Getter.
   integer(int32)                :: i !< Counter.

   if (allocated(conv64)) then
      if (size(conv64) < g%n) deallocate(conv64)
   endif
   if (.not. allocated(conv64)) allocate(conv64(max(g%n, 1024_int32)))
   do i = 1_int32, g%n
      conv64(i) = coordinate(g, 1_int32, int(i, int64))
   enddo
   endsubroutine convert64

   subroutine convert32(g)
   !< Integer abscissae converted into the kept single buffer, for the decimation.
   type(item_series), intent(in) :: g !< Getter.
   integer(int32)                :: i !< Counter.

   if (allocated(conv32)) then
      if (size(conv32) < g%n) deallocate(conv32)
   endif
   if (.not. allocated(conv32)) allocate(conv32(max(g%n, 1024_int32)))
   do i = 1_int32, g%n
      conv32(i) = real(coordinate(g, 1_int32, int(i, int64)), real32)
   enddo
   endsubroutine convert32

   ! private: the renderers (RenderPrimitivesEx: each primitive culled against the plot rectangle)

   subroutine render_strip(ctx, g, col, weight, loop, skip_nan)
   !< `RendererLineStrip` (`...Skip`: a NaN point keeps the last good one), over the loop's getter with `loop`. A block's
   !< primitives go to `put_lines` at once: primitive m from the block's point m - 1 (the previous block's last at 0)
   !< to its point m; with `skip_nan`, from the last point that is not NaN, collected first.
   type(plot_item_ctx), intent(in) :: ctx      !< The plot.
   type(item_series),   intent(in) :: g        !< Getter.
   integer(int32),      intent(in) :: col      !< Colour.
   real(real32),        intent(in) :: weight   !< Line weight.
   logical,             intent(in) :: loop     !< GetterLoop: the first point again at the end.
   logical,             intent(in) :: skip_nan !< SkipNaN.
   real(real32)                    :: p1(2), hw        !< The next primitive's start, half weight.
   real(real32)                    :: uv0(2), uv1(2)   !< Texture.
   real(real32)                    :: bx(0:PIX_BLOCK), by(0:PIX_BLOCK) !< A block's pixels (0: the start).
   real(real32)                    :: sx(PIX_BLOCK), sy(PIX_BLOCK)     !< Its primitives' starts (`skip_nan`).
   type(prim_run)                  :: r                !< The run.
   integer(int32)                  :: k, k0, ke, m, nb, nprim, cnt !< Primitive, run's start, block's last primitive,
                                                                   !< one of them, its primitives, primitives left, run.

   call line_props32(weight, hw, uv0, uv1)
   nprim = g%n - 1_int32
   if (loop) nprim = g%n
   if (nprim <= 0_int32) return
   call pixel_block(ctx, g, 1_int32, 1_int32, bx(1:), by(1:))
   p1(1) = bx(1)
   p1(2) = by(1)
   call run_begin(r, 4_int32, 6_int32)
   k0 = 0_int32
   do while (nprim > 0_int32)
      call run_next(r, nprim, cnt)
      k = k0 + 1_int32
      do while (k <= k0 + cnt)
         if (k < g%n) then ! primitive k ends at point k + 1
            ke = min(k0 + cnt, k + PIX_BLOCK - 1_int32, g%n - 1_int32)
            call pixel_block(ctx, g, k + 1_int32, ke - k + 1_int32, bx(1:), by(1:))
         else ! the loop's last primitive ends at the first point
            ke = k
            call pixel_block(ctx, g, 1_int32, 1_int32, bx(1:), by(1:))
         endif
         nb = ke - k + 1_int32
         if (skip_nan) then
            do m = 1_int32, nb
               sx(m) = p1(1)
               sy(m) = p1(2)
               if (.not. (bx(m) /= bx(m) .or. by(m) /= by(m))) then ! (NaN tests inline: ieee_is_nan is a call on ifx)
                  p1(1) = bx(m)
                  p1(2) = by(m)
               endif
            enddo
            call put_lines(r, r%vb, r%ib, nb, sx, sy, bx(1:), by(1:), hw, col, uv0, uv1, ctx%rect)
         else
            bx(0) = p1(1)
            by(0) = p1(2)
            call put_lines(r, r%vb, r%ib, nb, bx, by, bx(1:), by(1:), hw, col, uv0, uv1, ctx%rect)
            p1(1) = bx(nb)
            p1(2) = by(nb)
         endif
         k = ke + 1_int32
      enddo
      k0 = k0 + cnt
   enddo
   call run_end(r)
   endsubroutine render_strip

   subroutine render_segments1(ctx, g, col, weight)
   !< `RendererLineSegments1`: a segment from every two consecutive points.
   type(plot_item_ctx), intent(in) :: ctx    !< The plot.
   type(item_series),   intent(in) :: g      !< Getter.
   integer(int32),      intent(in) :: col    !< Colour.
   real(real32),        intent(in) :: weight !< Line weight.
   real(real32)                    :: hw     !< Half weight.
   real(real32)                    :: uv0(2), uv1(2)   !< Texture.
   real(real32)                    :: bx(PIX_BLOCK), by(PIX_BLOCK) !< A block's pixels.
   real(real32)                    :: ax(PIX_BLOCK / 2), ay(PIX_BLOCK / 2), cx(PIX_BLOCK / 2), cy(PIX_BLOCK / 2) !< Its
                                                                                       !< segments' first and second ends.
   type(prim_run)                  :: r                !< The run.
   integer(int32)                  :: k, k0, nb, m, nprim, cnt !< Primitive (0-based), run's start, block's primitives,
                                                               !< one of them, primitives left, run.

   call line_props32(weight, hw, uv0, uv1)
   nprim = g%n / 2_int32
   call run_begin(r, 4_int32, 6_int32)
   k0 = 0_int32
   do while (nprim > 0_int32)
      call run_next(r, nprim, cnt)
      k = k0
      do while (k < k0 + cnt)
         nb = min(PIX_BLOCK / 2_int32, k0 + cnt - k)
         call pixel_block(ctx, g, 2_int32 * k + 1_int32, 2_int32 * nb, bx, by) ! points 2 k + 1, 2 k + 2, ...
         do m = 1_int32, nb
            ax(m) = bx(2_int32 * m - 1_int32)
            ay(m) = by(2_int32 * m - 1_int32)
            cx(m) = bx(2_int32 * m)
            cy(m) = by(2_int32 * m)
         enddo
         call put_lines(r, r%vb, r%ib, nb, ax, ay, cx, cy, hw, col, uv0, uv1, ctx%rect)
         k = k + nb
      enddo
      k0 = k0 + cnt
   enddo
   call run_end(r)
   endsubroutine render_segments1

   subroutine render_segments2(ctx, g1, g2, col, weight)
   !< `RendererLineSegments2`: a segment from each point of one getter to the same point of the other.
   type(plot_item_ctx), intent(in) :: ctx    !< The plot.
   type(item_series),   intent(in) :: g1, g2 !< Getters.
   integer(int32),      intent(in) :: col    !< Colour.
   real(real32),        intent(in) :: weight !< Line weight.
   real(real32)                    :: hw     !< Half weight.
   real(real32)                    :: uv0(2), uv1(2)   !< Texture.
   real(real32)                    :: ax(PIX_BLOCK), ay(PIX_BLOCK), bx(PIX_BLOCK), by(PIX_BLOCK) !< A block's pixels of
                                                                                               !< g1 and g2.
   type(prim_run)                  :: r                !< The run.
   integer(int32)                  :: k, k0, nb, nprim, cnt !< Primitive, run's start, block's primitives, primitives
                                                            !< left, run.

   call line_props32(weight, hw, uv0, uv1)
   nprim = min(g1%n, g2%n)
   call run_begin(r, 4_int32, 6_int32)
   k0 = 0_int32
   do while (nprim > 0_int32)
      call run_next(r, nprim, cnt)
      k = k0 + 1_int32
      do while (k <= k0 + cnt)
         nb = min(PIX_BLOCK, k0 + cnt - k + 1_int32)
         call pixel_block(ctx, g1, k, nb, ax, ay)
         call pixel_block(ctx, g2, k, nb, bx, by)
         call put_lines(r, r%vb, r%ib, nb, ax, ay, bx, by, hw, col, uv0, uv1, ctx%rect)
         k = k + nb
      enddo
      k0 = k0 + cnt
   enddo
   call run_end(r)
   endsubroutine render_segments2

   subroutine render_stairs(ctx, g, col, weight, pre)
   !< `RendererStairsPre`/`RendererStairsPost`: two filled rectangles a step, of the line's weight.
   type(plot_item_ctx), intent(in) :: ctx    !< The plot.
   type(item_series),   intent(in) :: g      !< Getter.
   integer(int32),      intent(in) :: col    !< Colour.
   real(real32),        intent(in) :: weight !< Line weight.
   logical,             intent(in) :: pre    !< PreStep.
   real(real32)                    :: p1(2), p2(2), hw !< Ends, half weight.
   real(real32)                    :: xlo, ylo, xhi, yhi !< The primitive's bounds (`ImMin`, `ImMax` of its ends).
   logical                         :: vis                !< They overlap the plot rectangle (`Overlaps`).
   real(real32)                    :: uv(2)            !< White pixel.
   type(prim_run)                  :: r                !< The run.
   type(pixel_reader)              :: rd               !< The pixels, a block at a time.
   integer(int32)                  :: k, k0, nprim, cnt !< Primitive, run's start, primitives left, run.

   hw = max(1.0_real32, weight) * 0.5_real32
   uv = real(uv_white, real32)
   call read_pixel(rd, ctx, g, 1_int32, p1)
   call run_begin(r, 8_int32, 12_int32)
   nprim = g%n - 1_int32
   k0 = 0_int32
   do while (nprim > 0_int32)
      call run_next(r, nprim, cnt)
      do k = k0 + 1_int32, k0 + cnt
         call read_pixel(rd, ctx, g, k + 1_int32, p2)
         xlo = merge(p1(1), p2(1), p1(1) < p2(1)) ! ImMin, ImMax and Overlaps written out: nvfortran -O2 -mp
         ylo = merge(p1(2), p2(2), p1(2) < p2(2)) ! inlines no procedure (im_min: the NaN cases)
         xhi = merge(p1(1), p2(1), p1(1) >= p2(1))
         yhi = merge(p1(2), p2(2), p1(2) >= p2(2))
#ifdef __NVCOMPILER
         if (p1(1) /= p1(1) .or. p2(1) /= p2(1)) then
            xlo = p2(1)
            xhi = p2(1)
         endif
         if (p1(2) /= p1(2) .or. p2(2) /= p2(2)) then
            ylo = p2(2)
            yhi = p2(2)
         endif
#endif
         vis = ctx%rect(2) < yhi .and. ctx%rect(4) > ylo .and. ctx%rect(1) < xhi .and. ctx%rect(3) > xlo
#ifdef __NVCOMPILER
         if (vis) vis = .not. (xlo /= xlo .or. ylo /= ylo .or. xhi /= xhi .or. yhi /= yhi)
#endif
         if (vis) then
            if (pre) then
               call put_rect_fill(r, p1(1) - hw, p1(2), p1(1) + hw, p2(2), col, uv)
               call put_rect_fill(r, p1(1), p2(2) + hw, p2(1), p2(2) - hw, col, uv)
            else
               call put_rect_fill(r, p1(1), p1(2) + hw, p2(1), p1(2) - hw, col, uv)
               call put_rect_fill(r, p2(1) - hw, p2(2), p2(1) + hw, p1(2), col, uv)
            endif
         else
            r%culled = r%culled + 1_int32
         endif
         p1 = p2
      enddo
      k0 = k0 + cnt
   enddo
   call run_end(r)
   endsubroutine render_stairs

   subroutine render_stairs_shaded(ctx, g, col, pre)
   !< `RendererStairsPreShaded`/`PostShaded`: a filled rectangle from each step to y = 0.
   type(plot_item_ctx), intent(in) :: ctx !< The plot.
   type(item_series),   intent(in) :: g   !< Getter.
   integer(int32),      intent(in) :: col !< Colour.
   logical,             intent(in) :: pre !< PreStep.
   real(real32)                    :: p1(2), p2(2), y0, pmin(2), pmax(2) !< Ends, the pixel of y = 0, the rectangle.
   real(real32)                    :: uv(2) !< White pixel.
   type(prim_run)                  :: r   !< The run.
   type(pixel_reader)              :: rd  !< The pixels, a block at a time.
   integer(int32)                  :: k, k0, nprim, cnt !< Primitive, run's start, primitives left, run.

   call read_pixel(rd, ctx, g, 1_int32, p1)
   y0 = map_pixel(ctx%ty, 0.0_real64)
   uv = real(uv_white, real32)
   call run_begin(r, 4_int32, 6_int32)
   nprim = g%n - 1_int32
   k0 = 0_int32
   do while (nprim > 0_int32)
   call run_next(r, nprim, cnt)
   do k = k0 + 1_int32, k0 + cnt
      call read_pixel(rd, ctx, g, k + 1_int32, p2)
      pmin(1) = im_min(p1(1), p2(1))
      pmax(1) = im_max(p1(1), p2(1))
      if (pre) then
         pmin(2) = im_min(y0, p2(2))
         pmax(2) = im_max(y0, p2(2))
      else
         pmin(2) = im_min(p1(2), y0)
         pmax(2) = im_max(p1(2), y0)
      endif
      if (overlaps(ctx%rect, pmin(1), pmin(2), pmax(1), pmax(2))) then
         call put_rect_fill(r, pmin(1), pmin(2), pmax(1), pmax(2), col, uv)
      else
         r%culled = r%culled + 1_int32
      endif
      p1 = p2
   enddo
   k0 = k0 + cnt
   enddo
   call run_end(r)
   endsubroutine render_stairs_shaded

   subroutine render_shaded(ctx, g1, g2, col)
   !< `RendererShaded`: between two getters, a quad per step, two triangles at the crossing when they cross.
   type(plot_item_ctx), intent(in) :: ctx    !< The plot.
   type(item_series),   intent(in) :: g1, g2 !< Getters.
   integer(int32),      intent(in) :: col    !< Colour.
   real(real32)                    :: p11(2), p12(2), p21(2), p22(2), q(2) !< Corners, the crossing.
   real(real32)                    :: rmin(2), rmax(2) !< Their bounds.
   real(real32)                    :: uv(2)            !< White pixel.
   type(prim_run)                  :: r                !< The run.
   type(pixel_reader)              :: rd1, rd2         !< The pixels, a block at a time.
   integer(int32)                  :: k, k0, nprim, cnt, x, iv, ii, b !< Primitive, run's start, primitives left, run,
                                                                      !< crossing (0, 1), cursor.
   logical                         :: cross            !< The curves cross.

   call read_pixel(rd1, ctx, g1, 1_int32, p11)
   call read_pixel(rd2, ctx, g2, 1_int32, p12)
   uv = real(uv_white, real32)
   call run_begin(r, 5_int32, 6_int32)
   nprim = min(g1%n, g2%n) - 1_int32
   k0 = 0_int32
   do while (nprim > 0_int32)
   call run_next(r, nprim, cnt)
   do k = k0 + 1_int32, k0 + cnt
      call read_pixel(rd1, ctx, g1, k + 1_int32, p21)
      call read_pixel(rd2, ctx, g2, k + 1_int32, p22)
      rmin(1) = im_min(im_min(im_min(p11(1), p12(1)), p21(1)), p22(1))
      rmin(2) = im_min(im_min(im_min(p11(2), p12(2)), p21(2)), p22(2))
      rmax(1) = im_max(im_max(im_max(p11(1), p12(1)), p21(1)), p22(1))
      rmax(2) = im_max(im_max(im_max(p11(2), p12(2)), p21(2)), p22(2))
      if (overlaps(ctx%rect, rmin(1), rmin(2), rmax(1), rmax(2))) then
         cross = (p11(2) > p12(2) .and. p22(2) > p21(2)) .or. (p12(2) > p11(2) .and. p21(2) > p22(2))
         x = 0_int32
         q = 0.0_real32
         if (cross) then
            x = 1_int32
            q = intersection(p11, p21, p12, p22)
         endif
         iv = r%iv ! vertices P11, P21, X, P12, P22; triangles (0, 1 + x, 3) and (1, 4, 3 - x)
         ii = r%ii
         b = r%b
         associate(vt => r%vb(iv))
            vt%x = p11(1)
            vt%y = p11(2)
            vt%u = uv(1)
            vt%v = uv(2)
            vt%col = col
         endassociate
         associate(vt => r%vb(iv + 1_int32))
            vt%x = p21(1)
            vt%y = p21(2)
            vt%u = uv(1)
            vt%v = uv(2)
            vt%col = col
         endassociate
         associate(vt => r%vb(iv + 2_int32))
            vt%x = q(1)
            vt%y = q(2)
            vt%u = uv(1)
            vt%v = uv(2)
            vt%col = col
         endassociate
         associate(vt => r%vb(iv + 3_int32))
            vt%x = p12(1)
            vt%y = p12(2)
            vt%u = uv(1)
            vt%v = uv(2)
            vt%col = col
         endassociate
         associate(vt => r%vb(iv + 4_int32))
            vt%x = p22(1)
            vt%y = p22(2)
            vt%u = uv(1)
            vt%v = uv(2)
            vt%col = col
         endassociate
         r%ib(ii) = b - ishft(iand(b, IDX16_SIGN), 1_int32)
         r%ib(ii + 1_int32) = (b + 1_int32 + x) - ishft(iand(b + 1_int32 + x, IDX16_SIGN), 1_int32)
         r%ib(ii + 2_int32) = (b + 3_int32) - ishft(iand(b + 3_int32, IDX16_SIGN), 1_int32)
         r%ib(ii + 3_int32) = (b + 1_int32) - ishft(iand(b + 1_int32, IDX16_SIGN), 1_int32)
         r%ib(ii + 4_int32) = (b + 4_int32) - ishft(iand(b + 4_int32, IDX16_SIGN), 1_int32)
         r%ib(ii + 5_int32) = (b + 3_int32 - x) - ishft(iand(b + 3_int32 - x, IDX16_SIGN), 1_int32)
         r%iv = iv + 5_int32
         r%ii = ii + 6_int32
         r%b = b + 5_int32
      else
         r%culled = r%culled + 1_int32
      endif
      p11 = p21
      p12 = p22
   enddo
   k0 = k0 + cnt
   enddo
   call run_end(r)
   endsubroutine render_shaded

   subroutine render_markers(ctx, g, s)
   !< `RenderMarkers`: each point inside the plot rectangle (`RendererMarkersFill`: the shape's fan; then
   !< `RendererMarkersLine`: its outline's segments).
   type(plot_item_ctx), intent(in) :: ctx !< The plot.
   type(item_series),   intent(in) :: g   !< Getter.
   type(item_style),    intent(in) :: s   !< Staged style.

   if (s%mfill) then
      select case (s%marker)
      case (PF_MARKER_CIRCLE)
         call markers_fill(ctx, g, FILL_CIRCLE, s%col_mfill, s%marker_size)
      case (PF_MARKER_SQUARE)
         call markers_fill(ctx, g, FILL_SQUARE, s%col_mfill, s%marker_size)
      case (PF_MARKER_DIAMOND)
         call markers_fill(ctx, g, FILL_DIAMOND, s%col_mfill, s%marker_size)
      case (PF_MARKER_UP)
         call markers_fill(ctx, g, FILL_UP, s%col_mfill, s%marker_size)
      case (PF_MARKER_DOWN)
         call markers_fill(ctx, g, FILL_DOWN, s%col_mfill, s%marker_size)
      case (PF_MARKER_LEFT)
         call markers_fill(ctx, g, FILL_LEFT, s%col_mfill, s%marker_size)
      case (PF_MARKER_RIGHT)
         call markers_fill(ctx, g, FILL_RIGHT, s%col_mfill, s%marker_size)
      case default
      endselect
   endif
   if (s%mline) then
      select case (s%marker)
      case (PF_MARKER_CIRCLE)
         call markers_line(ctx, g, circle_outline(), s%col_mline, s%marker_size, s%weight)
      case (PF_MARKER_SQUARE)
         call markers_line(ctx, g, LINE_SQUARE, s%col_mline, s%marker_size, s%weight)
      case (PF_MARKER_DIAMOND)
         call markers_line(ctx, g, LINE_DIAMOND, s%col_mline, s%marker_size, s%weight)
      case (PF_MARKER_UP)
         call markers_line(ctx, g, LINE_UP, s%col_mline, s%marker_size, s%weight)
      case (PF_MARKER_DOWN)
         call markers_line(ctx, g, LINE_DOWN, s%col_mline, s%marker_size, s%weight)
      case (PF_MARKER_LEFT)
         call markers_line(ctx, g, LINE_LEFT, s%col_mline, s%marker_size, s%weight)
      case (PF_MARKER_RIGHT)
         call markers_line(ctx, g, LINE_RIGHT, s%col_mline, s%marker_size, s%weight)
      case (PF_MARKER_ASTERISK)
         call markers_line(ctx, g, LINE_ASTERISK, s%col_mline, s%marker_size, s%weight)
      case (PF_MARKER_PLUS)
         call markers_line(ctx, g, LINE_PLUS, s%col_mline, s%marker_size, s%weight)
      case (PF_MARKER_CROSS)
         call markers_line(ctx, g, LINE_CROSS, s%col_mline, s%marker_size, s%weight)
      case (PF_MARKER_VERTICAL)
         call markers_line(ctx, g, LINE_VERTICAL, s%col_mline, s%marker_size, s%weight)
      case (PF_MARKER_HORIZONTAL)
         call markers_line(ctx, g, LINE_HORIZONTAL, s%col_mline, s%marker_size, s%weight)
      case default
      endselect
   endif
   endsubroutine render_markers

   pure function circle_outline() result(m)
   !< `MARKER_LINE_CIRCLE`: the circle's ten segments, each point of `MARKER_FILL_CIRCLE` and the next.
   real(real32) :: m(2, 20) !< Segments' ends.
   integer      :: i        !< Counter.

   do i = 1, 10
      m(:, 2 * i - 1) = FILL_CIRCLE(:, i)
      m(:, 2 * i) = FILL_CIRCLE(:, mod(i, 10) + 1)
   enddo
   endfunction circle_outline

   subroutine markers_fill(ctx, g, shape, col, msize)
   !< `RendererMarkersFill`: the shape's vertices about each point (count of them), a fan from the first: triangles
   !< (0, i - 1, i), i = 2 .. count - 1.
   type(plot_item_ctx), intent(in) :: ctx         !< The plot.
   type(item_series),   intent(in) :: g           !< Getter.
   real(real32),        intent(in) :: shape(:, :) !< The shape (x, y) x count.
   integer(int32),      intent(in) :: col         !< Colour.
   real(real32),        intent(in) :: msize       !< Size [pixels].
   real(real32)                    :: p(2), x, y, w, uv(2) !< Point, a vertex, product, white pixel.
   real(real32)                    :: bx(PIX_BLOCK), by(PIX_BLOCK) !< A block's pixels.
   type(prim_run)                  :: r           !< The run.
   logical                         :: vis         !< Inside the plot rectangle.
   integer(int32)                  :: i, k, nv, i0, nb, m, nprim, cnt !< Point, vertex, count, run's start, block's
                                                                      !< points, one of them, points left, run.

   nv = int(size(shape, 2), int32)
   uv = real(uv_white, real32)
   nprim = g%n
   call run_begin(r, nv, (nv - 2_int32) * 3_int32)
   i0 = 0_int32
   do while (nprim > 0_int32)
      call run_next(r, nprim, cnt)
      i = i0 + 1_int32
      do while (i <= i0 + cnt)
         nb = min(PIX_BLOCK, i0 + cnt - i + 1_int32)
         call pixel_block(ctx, g, i, nb, bx, by)
         do m = 1_int32, nb
            p(1) = bx(m)
            p(2) = by(m)
            vis = p(1) >= ctx%rect(1) .and. p(2) >= ctx%rect(2) .and. p(1) <= ctx%rect(3) .and. &
                  p(2) <= ctx%rect(4)
#ifdef __NVCOMPILER
            if (vis) vis = .not. (p(1) /= p(1) .or. p(2) /= p(2)) ! (a NaN outside; nvfortran: see im_min)
#endif
            if (.not. vis) then
               r%culled = r%culled + 1_int32
               cycle
            endif
            do k = 1_int32, nv
               w = shape(1, k) * msize
               x = p(1) + w
               w = shape(2, k) * msize
               y = p(2) + w
               associate(vt => r%vb(r%iv + k - 1_int32))
                  vt%x = x
                  vt%y = y
                  vt%u = uv(1)
                  vt%v = uv(2)
                  vt%col = col
               endassociate
            enddo
            do k = 2_int32, nv - 1_int32
               r%ib(r%ii) = r%b - ishft(iand(r%b, IDX16_SIGN), 1_int32)
               r%ib(r%ii + 1_int32) = (r%b + k - 1_int32) - ishft(iand(r%b + k - 1_int32, IDX16_SIGN), 1_int32)
               r%ib(r%ii + 2_int32) = (r%b + k) - ishft(iand(r%b + k, IDX16_SIGN), 1_int32)
               r%ii = r%ii + 3_int32
            enddo
            r%iv = r%iv + nv
            r%b = r%b + nv
         enddo
         i = i + nb
      enddo
      i0 = i0 + cnt
   enddo
   call run_end(r)
   endsubroutine markers_fill

   subroutine markers_line(ctx, g, shape, col, msize, weight)
   !< `RendererMarkersLine`: the shape's segments (pairs of vertices) about each point, as anti-aliased lines; the
   !< shape's offsets (vertex times size) once, a point's segments to `put_lines` at once.
   type(plot_item_ctx), intent(in) :: ctx         !< The plot.
   type(item_series),   intent(in) :: g           !< Getter.
   real(real32),        intent(in) :: shape(:, :) !< Segments' ends (x, y) x count (at most 2 MARKER_SEGMENTS).
   integer(int32),      intent(in) :: col         !< Colour.
   real(real32),        intent(in) :: msize       !< Size [pixels].
   real(real32),        intent(in) :: weight      !< Line weight.
   real(real32)                    :: p(2), hw    !< Point, half weight.
   real(real32)                    :: uv0(2), uv1(2) !< Texture.
   real(real32)                    :: bx(PIX_BLOCK), by(PIX_BLOCK) !< A block's pixels.
   real(real32)                    :: ox1(MARKER_SEGMENTS), oy1(MARKER_SEGMENTS), ox2(MARKER_SEGMENTS), &
                                      oy2(MARKER_SEGMENTS) !< The segments' ends' offsets [pixels].
   real(real32)                    :: x1(MARKER_SEGMENTS), y1(MARKER_SEGMENTS), x2(MARKER_SEGMENTS), &
                                      y2(MARKER_SEGMENTS) !< A point's segments' ends [pixels].
   type(prim_run)                  :: r           !< The run.
   logical                         :: vis         !< Inside the plot rectangle.
   integer(int32)                  :: i, k, ns, i0, nb, m, nprim, cnt !< Point, segment, the shape's segments, run's
                                                                      !< start, block's points, one of them, points
                                                                      !< left, run.

   call line_props32(weight, hw, uv0, uv1)
   ns = int(size(shape, 2), int32) / 2_int32
   do k = 1_int32, ns
      ox1(k) = shape(1, 2_int32 * k - 1_int32) * msize
      oy1(k) = shape(2, 2_int32 * k - 1_int32) * msize
      ox2(k) = shape(1, 2_int32 * k) * msize
      oy2(k) = shape(2, 2_int32 * k) * msize
   enddo
   nprim = g%n
   call run_begin(r, ns * 4_int32, ns * 6_int32)
   i0 = 0_int32
   do while (nprim > 0_int32)
      call run_next(r, nprim, cnt)
      i = i0 + 1_int32
      do while (i <= i0 + cnt)
         nb = min(PIX_BLOCK, i0 + cnt - i + 1_int32)
         call pixel_block(ctx, g, i, nb, bx, by)
         do m = 1_int32, nb
            p(1) = bx(m)
            p(2) = by(m)
            vis = p(1) >= ctx%rect(1) .and. p(2) >= ctx%rect(2) .and. p(1) <= ctx%rect(3) .and. &
                  p(2) <= ctx%rect(4)
#ifdef __NVCOMPILER
            if (vis) vis = .not. (p(1) /= p(1) .or. p(2) /= p(2)) ! (a NaN outside; nvfortran: see im_min)
#endif
            if (.not. vis) then
               r%culled = r%culled + 1_int32
               cycle
            endif
            do k = 1_int32, ns
               x1(k) = p(1) + ox1(k)
               y1(k) = p(2) + oy1(k)
               x2(k) = p(1) + ox2(k)
               y2(k) = p(2) + oy2(k)
            enddo
            call put_lines(r, r%vb, r%ib, ns, x1, y1, x2, y2, hw, col, uv0, uv1)
         enddo
         i = i + nb
      enddo
      i0 = i0 + cnt
   enddo
   call run_end(r)
   endsubroutine markers_line

   ! private: the primitives (PrimLine, PrimRectFill, raw triangles), through figure_core's textured quad

   subroutine line_props(weight, hw, uv0, uv1)
   !< `GetLineRenderProps`: half the weight (at least 1 pixel) plus half the line texture's fringe, its texture.
   real(real32), intent(in)  :: weight         !< Line weight.
   real(real32), intent(out) :: hw             !< Half weight [pixels].
   real(real64), intent(out) :: uv0(2), uv1(2) !< Texture coordinates.
   real(real64)              :: fringe         !< Fringe [pixels].

   hw = max(1.0_real32, weight) * 0.5_real32
   call core_line_texture(real(hw * 2.0_real32, real64), uv0, uv1, fringe)
   hw = hw + real(fringe, real32) * 0.5_real32
   endsubroutine line_props

   subroutine line_props32(weight, hw, uv0, uv1)
   !< `GetLineRenderProps` with the texture coordinates in single precision (as `ImVec2`), for the runs.
   real(real32), intent(in)  :: weight         !< Line weight.
   real(real32), intent(out) :: hw             !< Half weight [pixels].
   real(real32), intent(out) :: uv0(2), uv1(2) !< Texture coordinates.
   real(real64)              :: u0(2), u1(2)   !< ... as line_props gives them (single precision values).

   call line_props(weight, hw, u0, u1)
   uv0 = real(u0, real32)
   uv1 = real(u1, real32)
   endsubroutine line_props32

   subroutine run_begin(r, vtx, idx)
   !< A renderer's run starts (`RenderPrimitivesEx`): vtx vertices and idx indices a primitive, nothing culled.
   type(prim_run), intent(out) :: r   !< The run.
   integer(int32), intent(in)  :: vtx !< Vertices a primitive.
   integer(int32), intent(in)  :: idx !< Indices a primitive.

   r%vtx = vtx
   r%idx = idx
   endsubroutine run_begin

   subroutine run_next(r, prims, cnt)
   !< `RenderPrimitivesEx`'s reservation for the next cnt of the prims left (taken from them): up to the draw command's
   !< limit, the culled primitives' room used again first; fewer than 64 fitting (or all the prims left): the culled
   !< room given back and a new command reserved. The write cursor at the reservation when nothing is pending.
   type(prim_run), intent(inout) :: r     !< The run.
   integer(int32), intent(inout) :: prims !< Primitives left.
   integer(int32), intent(out)   :: cnt   !< Primitives of this run.
   integer(int32)                :: iv, ii, b !< A reservation's cursor.

   cnt = min(prims, (DL_BATCH_VERTICES - (core_run_vtx_current() - r%culled * r%vtx)) / r%vtx)
   if (cnt >= min(64_int32, prims)) then
      if (r%culled >= cnt) then
         r%culled = r%culled - cnt ! the previous reservation used again
      else
         call core_run_reserve((cnt - r%culled) * r%vtx, (cnt - r%culled) * r%idx, iv, ii, b, r%vb, r%ib)
         if (r%culled == 0_int32) then
            r%iv = iv
            r%ii = ii
            r%b = b
         endif
         r%culled = 0_int32
      endif
   else
      if (r%culled > 0_int32) call core_run_unreserve(r%culled * r%vtx, r%culled * r%idx)
      r%culled = 0_int32
      cnt = min(prims, DL_BATCH_VERTICES / r%vtx)
      call core_run_reserve(cnt * r%vtx, cnt * r%idx, r%iv, r%ii, r%b, r%vb, r%ib) ! a new draw command
   endif
   prims = prims - cnt
   endsubroutine run_next

   subroutine run_end(r)
   !< The run ends: the culled primitives' room given back.
   type(prim_run), intent(inout) :: r !< The run.

   if (r%culled > 0_int32) call core_run_unreserve(r%culled * r%vtx, r%culled * r%idx)
   r%culled = 0_int32
   endsubroutine run_end

   subroutine put_lines(r, vb, ib, n, x1, y1, x2, y2, hw, col, uv0, uv1, rect)
   !< `PrimLine` for n segments into the run, segment m from (x1(m), y1(m)) to (x2(m), y2(m)): a quad of the line's
   !< texture, `hw` each side, at the cursor. With `rect`, each segment is first culled as `RenderPrimitivesEx` culls it
   !< (`ImMin` and `ImMax` of its ends, `Overlaps` with the plot rectangle), a culled one counted in the run.
   !< One call a block of segments, not one a segment: gfortran -O2 does not inline a writer of several callers and
   !< nvfortran -O2 -mp inlines none, and the call (by-reference ends, the run's cursor and the buffers' descriptors read
   !< again and stored back) cost more than ImPlot's whole `PrimLine` (szaghi/figure#16 S5, S8). So the cursor lives in
   !< locals for the block, and the run's buffers come as `vb` and `ib`, explicit-size dummies (the actuals `r%vb` and
   !< `r%ib`, contiguous: no copy), so a vertex's address needs no pointer descriptor. The vertices are set field by
   !< field: a `draw_vert(...)` constructor makes ifx build it in a temporary and copy it with one 16-byte load over
   !< smaller stores, a store-forwarding stall a vertex (szaghi/figure#16 S2). The arithmetic is `PrimLine`'s, in its
   !< order and precision (szaghi/figure#16 D3).
   type(prim_run),     intent(inout)        :: r       !< The run.
   type(draw_vert),    intent(inout)        :: vb(*)   !< Its vertices, `r%vb`.
   integer(c_int16_t), intent(inout)        :: ib(*)   !< Its indices, `r%ib`.
   integer(int32),     intent(in)           :: n       !< Segments.
   real(real32),       intent(in)           :: x1(*), y1(*), x2(*), y2(*) !< Their ends [pixels].
   real(real32),       intent(in)           :: hw      !< Half width [pixels].
   integer(int32),     intent(in)           :: col     !< Colour.
   real(real32),       intent(in)           :: uv0(2), uv1(2) !< Texture.
   real(real32),       intent(in), optional :: rect(4) !< Plot rectangle: cull against it.
   real(real32)                             :: xa, ya, xb, yb !< A segment's ends.
   real(real32)                             :: dx, dy, d2, inv, a, b !< Direction, products.
   real(real32)                             :: xlo, ylo, xhi, yhi !< Its bounds (`ImMin`, `ImMax` of its ends).
   real(real32)                             :: rx0, ry0, rx1, ry1 !< The plot rectangle.
   real(real32)                             :: u0, v0, u1, v1, w  !< Texture, half width (the dummies' values in
                                                                  !< locals: a store to the buffers could alias them).
   logical                                  :: cull, vis !< Cull, the segment overlaps the rectangle (`Overlaps`).
   integer(int32)                           :: c, iv, ii, k, nc, m !< Colour, cursor, culled, segment.

   cull = present(rect)
   rx0 = 0.0_real32
   ry0 = 0.0_real32
   rx1 = 0.0_real32
   ry1 = 0.0_real32
   if (cull) then
      rx0 = rect(1)
      ry0 = rect(2)
      rx1 = rect(3)
      ry1 = rect(4)
   endif
   u0 = uv0(1)
   v0 = uv0(2)
   u1 = uv1(1)
   v1 = uv1(2)
   w = hw
   c = col
   iv = r%iv
   ii = r%ii
   k = r%b
   nc = 0_int32
   do m = 1_int32, n
      xa = x1(m)
      ya = y1(m)
      xb = x2(m)
      yb = y2(m)
      if (cull) then
         xlo = merge(xa, xb, xa < xb) ! ImMin, ImMax and Overlaps written out: nvfortran -O2 -mp inlines no procedure
         ylo = merge(ya, yb, ya < yb) ! (im_min: the NaN cases)
         xhi = merge(xa, xb, xa >= xb)
         yhi = merge(ya, yb, ya >= yb)
#ifdef __NVCOMPILER
         if (xa /= xa .or. xb /= xb) then
            xlo = xb
            xhi = xb
         endif
         if (ya /= ya .or. yb /= yb) then
            ylo = yb
            yhi = yb
         endif
#endif
         vis = ry0 < yhi .and. ry1 > ylo .and. rx0 < xhi .and. rx1 > xlo
#ifdef __NVCOMPILER
         if (vis) vis = .not. (xlo /= xlo .or. ylo /= ylo .or. xhi /= xhi .or. yhi /= yhi)
#endif
         if (.not. vis) then
            nc = nc + 1_int32
            cycle
         endif
      endif
      dx = xb - xa
      dy = yb - ya
      a = dx * dx ! (IMPLOT_NORMALIZE2F_OVER_ZERO; the products apart)
      b = dy * dy
      d2 = a + b
      if (d2 > 0.0_real32) then
         inv = 1.0_real32 / sqrt(d2)
         dx = dx * inv
         dy = dy * inv
      endif
      dx = dx * w
      dy = dy * w
      vb(iv)%x = xa + dy
      vb(iv)%y = ya - dx
      vb(iv)%u = u0
      vb(iv)%v = v0
      vb(iv)%col = c
      vb(iv + 1_int32)%x = xb + dy
      vb(iv + 1_int32)%y = yb - dx
      vb(iv + 1_int32)%u = u0
      vb(iv + 1_int32)%v = v0
      vb(iv + 1_int32)%col = c
      vb(iv + 2_int32)%x = xb - dy
      vb(iv + 2_int32)%y = yb + dx
      vb(iv + 2_int32)%u = u1
      vb(iv + 2_int32)%v = v1
      vb(iv + 2_int32)%col = c
      vb(iv + 3_int32)%x = xa - dy
      vb(iv + 3_int32)%y = ya + dx
      vb(iv + 3_int32)%u = u1
      vb(iv + 3_int32)%v = v1
      vb(iv + 3_int32)%col = c
      ib(ii) = k - ishft(iand(k, IDX16_SIGN), 1_int32)
      ib(ii + 1_int32) = (k + 1_int32) - ishft(iand(k + 1_int32, IDX16_SIGN), 1_int32)
      ib(ii + 2_int32) = (k + 2_int32) - ishft(iand(k + 2_int32, IDX16_SIGN), 1_int32)
      ib(ii + 3_int32) = k - ishft(iand(k, IDX16_SIGN), 1_int32)
      ib(ii + 4_int32) = (k + 2_int32) - ishft(iand(k + 2_int32, IDX16_SIGN), 1_int32)
      ib(ii + 5_int32) = (k + 3_int32) - ishft(iand(k + 3_int32, IDX16_SIGN), 1_int32)
      iv = iv + 4_int32
      ii = ii + 6_int32
      k = k + 4_int32
   enddo
   r%iv = iv
   r%ii = ii
   r%b = k
   r%culled = r%culled + nc
   endsubroutine put_lines

   subroutine run_reserve(r)
   !< A direct `PrimReserve` of the run's room per primitive, for one primitive (no culling: the pie slices), the cursor
   !< at it.
   type(prim_run), intent(inout) :: r !< The run.

   call core_run_reserve(r%vtx, r%idx, r%iv, r%ii, r%b, r%vb, r%ib)
   endsubroutine run_reserve

   subroutine put_rect_fill(r, ax, ay, bx, by, col, uv)
   !< `PrimRectFill(Pmin, Pmax)` into the run: vertices Pmin = (ax, ay), Pmax = (bx, by), (Pmin.x, Pmax.y),
   !< (Pmax.x, Pmin.y); triangles (0, 1, 2) and (0, 1, 3).
   type(prim_run), intent(inout) :: r      !< The run.
   real(real32),   intent(in)    :: ax, ay !< Pmin [pixels].
   real(real32),   intent(in)    :: bx, by !< Pmax [pixels].
   integer(int32), intent(in)    :: col    !< Colour.
   real(real32),   intent(in)    :: uv(2)  !< White pixel.
   integer(int32)                :: iv, ii, k !< Cursor.

   iv = r%iv
   ii = r%ii
   k = r%b
   associate(vt => r%vb(iv))
      vt%x = ax
      vt%y = ay
      vt%u = uv(1)
      vt%v = uv(2)
      vt%col = col
   endassociate
   associate(vt => r%vb(iv + 1_int32))
      vt%x = bx
      vt%y = by
      vt%u = uv(1)
      vt%v = uv(2)
      vt%col = col
   endassociate
   associate(vt => r%vb(iv + 2_int32))
      vt%x = ax
      vt%y = by
      vt%u = uv(1)
      vt%v = uv(2)
      vt%col = col
   endassociate
   associate(vt => r%vb(iv + 3_int32))
      vt%x = bx
      vt%y = ay
      vt%u = uv(1)
      vt%v = uv(2)
      vt%col = col
   endassociate
   r%ib(ii) = k - ishft(iand(k, IDX16_SIGN), 1_int32)
   r%ib(ii + 1_int32) = (k + 1_int32) - ishft(iand(k + 1_int32, IDX16_SIGN), 1_int32)
   r%ib(ii + 2_int32) = (k + 2_int32) - ishft(iand(k + 2_int32, IDX16_SIGN), 1_int32)
   r%ib(ii + 3_int32) = k - ishft(iand(k, IDX16_SIGN), 1_int32)
   r%ib(ii + 4_int32) = (k + 1_int32) - ishft(iand(k + 1_int32, IDX16_SIGN), 1_int32)
   r%ib(ii + 5_int32) = (k + 3_int32) - ishft(iand(k + 3_int32, IDX16_SIGN), 1_int32)
   r%iv = iv + 4_int32
   r%ii = ii + 6_int32
   r%b = k + 4_int32
   endsubroutine put_rect_fill

   subroutine put_rect_line(r, pmin, pmax, w, col, uv)
   !< `PrimRectLine` into the run: a rectangle's outline `w` pixels inside it, eight vertices (outer 0-3: (min.x, min.y),
   !< (min.x, max.y), (max.x, max.y), (max.x, min.y); inner 4-7 the same `w` inside), triangles (0, 1, 5), (0, 5, 4),
   !< (1, 2, 6), (1, 6, 5), (2, 3, 7), (2, 7, 6), (3, 0, 4), (3, 4, 7).
   type(prim_run), intent(inout) :: r                !< The run.
   real(real32),   intent(in)    :: pmin(2), pmax(2) !< Corners [pixels].
   real(real32),   intent(in)    :: w                !< Weight [pixels].
   integer(int32), intent(in)    :: col              !< Colour.
   real(real32),   intent(in)    :: uv(2)            !< White pixel.
   integer(int32), parameter     :: TRI(24) = [0, 1, 5, 0, 5, 4, 1, 2, 6, 1, 6, 5, 2, 3, 7, 2, 7, 6, 3, 0, 4, 3, 4, 7] !<
                                                                                                   !< The triangles.
   integer(int32)                :: iv, ii, k, j     !< Cursor, counter.

   iv = r%iv
   ii = r%ii
   k = r%b
   associate(vt => r%vb(iv))
      vt%x = pmin(1)
      vt%y = pmin(2)
      vt%u = uv(1)
      vt%v = uv(2)
      vt%col = col
   endassociate
   associate(vt => r%vb(iv + 1_int32))
      vt%x = pmin(1)
      vt%y = pmax(2)
      vt%u = uv(1)
      vt%v = uv(2)
      vt%col = col
   endassociate
   associate(vt => r%vb(iv + 2_int32))
      vt%x = pmax(1)
      vt%y = pmax(2)
      vt%u = uv(1)
      vt%v = uv(2)
      vt%col = col
   endassociate
   associate(vt => r%vb(iv + 3_int32))
      vt%x = pmax(1)
      vt%y = pmin(2)
      vt%u = uv(1)
      vt%v = uv(2)
      vt%col = col
   endassociate
   associate(vt => r%vb(iv + 4_int32))
      vt%x = pmin(1) + w
      vt%y = pmin(2) + w
      vt%u = uv(1)
      vt%v = uv(2)
      vt%col = col
   endassociate
   associate(vt => r%vb(iv + 5_int32))
      vt%x = pmin(1) + w
      vt%y = pmax(2) - w
      vt%u = uv(1)
      vt%v = uv(2)
      vt%col = col
   endassociate
   associate(vt => r%vb(iv + 6_int32))
      vt%x = pmax(1) - w
      vt%y = pmax(2) - w
      vt%u = uv(1)
      vt%v = uv(2)
      vt%col = col
   endassociate
   associate(vt => r%vb(iv + 7_int32))
      vt%x = pmax(1) - w
      vt%y = pmin(2) + w
      vt%u = uv(1)
      vt%v = uv(2)
      vt%col = col
   endassociate
   do j = 1_int32, 24_int32
      r%ib(ii + j - 1_int32) = (k + TRI(j)) - ishft(iand(k + TRI(j), IDX16_SIGN), 1_int32)
   enddo
   r%iv = iv + 8_int32
   r%ii = ii + 24_int32
   r%b = k + 8_int32
   endsubroutine put_rect_line

   subroutine put_fan(r, v, n, col, uv)
   !< A fan into the run (`PrimPieSliceFill`, `RendererCircleFill`): n vertices v(:, 1:n), triangles (0, i - 1, i),
   !< i = 2 .. n - 1.
   type(prim_run), intent(inout) :: r       !< The run.
   real(real32),   intent(in)    :: v(:, :) !< Vertices [pixels].
   integer(int32), intent(in)    :: n       !< Their count.
   integer(int32), intent(in)    :: col     !< Colour.
   real(real32),   intent(in)    :: uv(2)   !< White pixel.
   integer(int32)                :: i       !< Vertex.

   do i = 1_int32, n
      associate(vt => r%vb(r%iv + i - 1_int32))
         vt%x = v(1, i)
         vt%y = v(2, i)
         vt%u = uv(1)
         vt%v = uv(2)
         vt%col = col
      endassociate
   enddo
   do i = 2_int32, n - 1_int32
      r%ib(r%ii) = r%b - ishft(iand(r%b, IDX16_SIGN), 1_int32)
      r%ib(r%ii + 1_int32) = (r%b + i - 1_int32) - ishft(iand(r%b + i - 1_int32, IDX16_SIGN), 1_int32)
      r%ib(r%ii + 2_int32) = (r%b + i) - ishft(iand(r%b + i, IDX16_SIGN), 1_int32)
      r%ii = r%ii + 3_int32
   enddo
   r%iv = r%iv + n
   r%b = r%b + n
   endsubroutine put_fan

   ! private: numerics as ImPlot's

   pure function intersection(a1, a2, b1, b2) result(q)
   !< `Intersection` of the lines a1-a2 and b1-b2 (float; the products apart).
   real(real32), intent(in) :: a1(2), a2(2), b1(2), b2(2) !< Points.
   real(real32)             :: q(2)                       !< Crossing.
   real(real32)             :: v1, v2, v3, s, t           !< Terms.

   s = a1(1) * a2(2)
   t = a1(2) * a2(1)
   v1 = s - t
   s = b1(1) * b2(2)
   t = b1(2) * b2(1)
   v2 = s - t
   s = (a1(1) - a2(1)) * (b1(2) - b2(2))
   t = (a1(2) - a2(2)) * (b1(1) - b2(1))
   v3 = s - t
   s = v1 * (b1(1) - b2(1))
   t = v2 * (a1(1) - a2(1))
   q(1) = (s - t) / v3
   s = v1 * (b1(2) - b2(2))
   t = v2 * (a1(2) - a2(2))
   q(2) = (s - t) / v3
   endfunction intersection

   pure function overlaps(r, x0, y0, x1, y1) result(yes)
   !< `ImRect::Overlaps` of the plot rectangle and (x0, y0)-(x1, y1) (false with a NaN; nvfortran: see `im_min`).
   real(real32), intent(in) :: r(4)           !< Rectangle.
   real(real32), intent(in) :: x0, y0, x1, y1 !< Other.
   logical                  :: yes            !< Overlap.

   yes = r(2) < y1 .and. r(4) > y0 .and. r(1) < x1 .and. r(3) > x0
#ifdef __NVCOMPILER
   if (yes) yes = .not. (x0 /= x0 .or. y0 /= y0 .or. x1 /= x1 .or. y1 /= y1) ! (a NaN; not ieee_is_nan: a library call)
#endif
   endfunction overlaps

   pure function im_min(a, b) result(c)
   !< `ImMin`: a < b ? a : b (the second with a NaN). nvfortran 26.9 (no -Kieee) compiles `a < b` true when one is a
   !< NaN (seen: `im_min(100, NaN)` gave 100; szaghi/figure#16 S2 05, the draw data of a line through a NaN): the NaN
   !< case is tested explicitly there.
   real(real32), intent(in) :: a, b !< Values.
   real(real32)             :: c    !< Minimum.

   if (a < b) then
      c = a
   else
      c = b
   endif
#ifdef __NVCOMPILER
   if (a /= a .or. b /= b) c = b ! (a NaN; nvfortran gets `/=` right, and ieee_is_nan is a library call there)
#endif
   endfunction im_min

   pure function im_max(a, b) result(c)
   !< `ImMax`: a >= b ? a : b (the second with a NaN; nvfortran: see `im_min`).
   real(real32), intent(in) :: a, b !< Values.
   real(real32)             :: c    !< Maximum.

   if (a >= b) then
      c = a
   else
      c = b
   endif
#ifdef __NVCOMPILER
   if (a /= a .or. b /= b) c = b ! (a NaN; nvfortran gets `/=` right, and ieee_is_nan is a library call there)
#endif
   endfunction im_max

   pure function is_auto(c) result(yes)
   !< `IsColorAuto`: alpha -1.
   real(real32), intent(in) :: c(4) !< Colour.
   logical                  :: yes  !< Automatic.

   yes = c(4) == AUTO_ALPHA
   endfunction is_auto

   pure function unpack_u32(col) result(c)
   !< `ColorConvertU32ToFloat4`: each channel times 1/255 (float).
   integer(int32), intent(in) :: col  !< Packed colour.
   real(real32)               :: c(4) !< Colour.
   real(real32), parameter    :: S = 1.0_real32 / 255.0_real32 !< 1/255.
   integer(int32)             :: k    !< Channel.

   integer(int64)             :: u    !< Unsigned value.

   u = iand(int(col, int64), 4294967295_int64) ! (the channels by constant divisors: a variable shift of an int64 is a
   do k = 1_int32, 4_int32                     ! library call on nvfortran, ftn_i_kishft)
      c(k) = real(iand(u / BYTE_UNIT(k), 255_int64), real32) * S
   enddo
   endfunction unpack_u32

   pure function color_u32(c, alpha) result(col)
   !< `GetColorU32(ImVec4)`: alpha times the style's, then `ColorConvertFloat4ToU32` (`IM_F32_TO_INT8_SAT`).
   real(real32),   intent(in) :: c(4)  !< Colour.
   real(real32),   intent(in) :: alpha !< Style's alpha.
   integer(int32)             :: col   !< Packed colour.
   real(real32)               :: v(4)  !< Channels.
   integer(int64)             :: u     !< Unsigned value.
   integer(int32)             :: k     !< Channel.

   v = c
   v(4) = v(4) * alpha
   u = 0_int64
   do k = 1_int32, 4_int32 ! (each channel in 0-255 times its byte's unit: the bits of the shifts, without a variable
                           ! shift of an int64, a library call on nvfortran)
      u = u + int(min(max(v(k), 0.0_real32), 1.0_real32) * 255.0_real32 + 0.5_real32, int64) * BYTE_UNIT(k)
   enddo
   if (u >= 2147483648_int64) u = u - 4294967296_int64
   col = int(u, int32)
   endfunction color_u32
endmodule figure_plot_items
