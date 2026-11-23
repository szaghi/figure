!< figure_plot_items, the plot frame's items: lines, markers, scatter, stairs, stems, shaded areas, as ImPlot draws.
module figure_plot_items
!< figure_plot_items, the plot frame's items: lines, markers, scatter, stairs, stems, shaded areas, as ImPlot draws.
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
!<   `MARKER_FILL_*`/`MARKER_LINE_*`; each primitive culled as `RenderPrimitivesEx` culls it (the plot rectangle),
!<   drawn with figure_core's textured quads (`core_draw_quad_uv`: two triangles sharing a diagonal; ImPlot's raw
!<   triangles are the same triangles, a fan's or a lone one's as quads with a repeated vertex); lines with the
!<   anti-aliased line texture (`GetLineRenderProps`), fills with the white pixel;
!< - the clip: the plot rectangle (`PushPlotClipRect`), expanded by the marker size for the markers of stairs and
!<   stems, and of lines and scatters with `NoClip`;
!< - the decimation of long line-like series (figure_decimate, as figure_implot's `series_decimate`: M4 per pixel
!<   column above DECIMATE_THRESHOLD points a column; not with markers, `Segments`, `Loop`): the kept points read
!<   through their indices, in place (`pf_set_decimation` turns it off, as `ip_set_decimation`).
!<
!< No allocation per item per frame (ADR 0001): views of the arrays, fixed quads; the decimation's index buffer and
!< the integer abscissae's conversion (decimated items only) are grown once and kept.
!<
!< ImPlot normalises a line segment with the SSE estimate `_mm_rsqrt_ss` (12 bits), the frame with `1/sqrt`: an
!< anti-aliased edge pixel may land on the other side of a texel (figure_test_plot_frame_labels' header).
use, intrinsic :: ieee_arithmetic, only : ieee_is_nan
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use figure_core, only : core_draw_quad_uv, core_framebuffer_scale, core_line_texture, core_pop_clip_rect, &
                        core_push_clip_rect, core_style_var, core_white_pixel
use figure_decimate, only : decimate, decimate_axis, DECIMATE_LINEAR, DECIMATE_LOG10, DECIMATE_SYMLOG, &
                            DECIMATE_THRESHOLD
use figure_plot_frame, only : plot_item_ctx, pf_item_begin, pf_item_end, pf_item_fit
use figure_plot_transform, only : map_pixel, MAP_LINEAR, MAP_LOG10, MAP_SYMLOG, MAP_TIME

implicit none
private
public :: plot_item_spec, pf_spec
public :: pf_line, pf_scatter, pf_stairs, pf_stems, pf_shaded, pf_set_decimation
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
real(real32),   parameter :: AUTO_ALPHA = -1.0_real32       !< IMPLOT_AUTO_COL's alpha: an automatic colour.
real(real32),   parameter :: HIGHLIGHT_LINE_SCALE = 2.0_real32 !< ITEM_HIGHLIGHT_LINE_SCALE.
real(real32),   parameter :: HIGHLIGHT_MARK_SCALE = 1.25_real32 !< ITEM_HIGHLIGHT_MARK_SCALE.
real(real32),   parameter :: SQRT_1_2 = 0.70710678118_real32 !< SQRT_1_2 (implot_items.cpp).
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
integer(int64), allocatable :: keep(:)                !< The decimation's kept indices.
real(real32),   allocatable :: conv32(:)              !< Integer abscissae converted (decimated items).
real(real64),   allocatable :: conv64(:)              !< ...
real(real64)                :: uv_white(2) = 0.0_real64 !< The white pixel's texture coordinates (this item's).

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
   real(real64),         intent(in), target   :: x(:)  !< Abscissae.
   real(real64),         intent(in), target   :: y(:)  !< Ordinates.
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
   real(real32),         intent(in), target   :: x(:)  !< Abscissae.
   real(real32),         intent(in), target   :: y(:)  !< Ordinates.
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
   integer(int32),       intent(in), target   :: x(:)  !< Abscissae.
   real(real64),         intent(in), target   :: y(:)  !< Ordinates.
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
   integer(int64),       intent(in), target   :: x(:)  !< Abscissae.
   real(real64),         intent(in), target   :: y(:)  !< Ordinates.
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
   integer(int32),       intent(in), target   :: x(:)  !< Abscissae.
   real(real32),         intent(in), target   :: y(:)  !< Ordinates.
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
   integer(int64),       intent(in), target   :: x(:)  !< Abscissae.
   real(real32),         intent(in), target   :: y(:)  !< Ordinates.
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
   real(real64),         intent(in), target   :: y(:)   !< Ordinates.
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
   real(real32),         intent(in), target   :: y(:)   !< Ordinates.
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
   real(real64),         intent(in), target   :: x(:)  !< Abscissae.
   real(real64),         intent(in), target   :: y(:)  !< Ordinates.
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
   real(real32),         intent(in), target   :: x(:)  !< Abscissae.
   real(real32),         intent(in), target   :: y(:)  !< Ordinates.
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
   integer(int32),       intent(in), target   :: x(:)  !< Abscissae.
   real(real64),         intent(in), target   :: y(:)  !< Ordinates.
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
   integer(int64),       intent(in), target   :: x(:)  !< Abscissae.
   real(real64),         intent(in), target   :: y(:)  !< Ordinates.
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
   integer(int32),       intent(in), target   :: x(:)  !< Abscissae.
   real(real32),         intent(in), target   :: y(:)  !< Ordinates.
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
   integer(int64),       intent(in), target   :: x(:)  !< Abscissae.
   real(real32),         intent(in), target   :: y(:)  !< Ordinates.
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
   real(real64),         intent(in), target   :: x(:)  !< Abscissae.
   real(real64),         intent(in), target   :: y(:)  !< Ordinates.
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
   real(real32),         intent(in), target   :: x(:)  !< Abscissae.
   real(real32),         intent(in), target   :: y(:)  !< Ordinates.
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
   integer(int32),       intent(in), target   :: x(:)  !< Abscissae.
   real(real64),         intent(in), target   :: y(:)  !< Ordinates.
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
   integer(int64),       intent(in), target   :: x(:)  !< Abscissae.
   real(real64),         intent(in), target   :: y(:)  !< Ordinates.
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
   integer(int32),       intent(in), target   :: x(:)  !< Abscissae.
   real(real32),         intent(in), target   :: y(:)  !< Ordinates.
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
   integer(int64),       intent(in), target   :: x(:)  !< Abscissae.
   real(real32),         intent(in), target   :: y(:)  !< Ordinates.
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
   real(real64),         intent(in), target   :: x(:)  !< Abscissae.
   real(real64),         intent(in), target   :: y(:)  !< Ordinates.
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
   real(real32),         intent(in), target   :: x(:)  !< Abscissae.
   real(real32),         intent(in), target   :: y(:)  !< Ordinates.
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
   integer(int32),       intent(in), target   :: x(:)  !< Abscissae.
   real(real64),         intent(in), target   :: y(:)  !< Ordinates.
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
   integer(int64),       intent(in), target   :: x(:)  !< Abscissae.
   real(real64),         intent(in), target   :: y(:)  !< Ordinates.
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
   integer(int32),       intent(in), target   :: x(:)  !< Abscissae.
   real(real32),         intent(in), target   :: y(:)  !< Ordinates.
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
   integer(int64),       intent(in), target   :: x(:)  !< Abscissae.
   real(real32),         intent(in), target   :: y(:)  !< Ordinates.
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
   real(real64),         intent(in), target   :: x(:)  !< Abscissae.
   real(real64),         intent(in), target   :: y1(:) !< First curve.
   real(real64),         intent(in), target   :: y2(:) !< Second curve.
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
   real(real32),         intent(in), target   :: x(:)  !< Abscissae.
   real(real32),         intent(in), target   :: y1(:) !< First curve.
   real(real32),         intent(in), target   :: y2(:) !< Second curve.
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
   integer(int32),       intent(in), target   :: x(:)  !< Abscissae.
   real(real64),         intent(in), target   :: y1(:) !< First curve.
   real(real64),         intent(in), target   :: y2(:) !< Second curve.
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
   integer(int64),       intent(in), target   :: x(:)  !< Abscissae.
   real(real64),         intent(in), target   :: y1(:) !< First curve.
   real(real64),         intent(in), target   :: y2(:) !< Second curve.
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
   integer(int32),       intent(in), target   :: x(:)  !< Abscissae.
   real(real32),         intent(in), target   :: y1(:) !< First curve.
   real(real32),         intent(in), target   :: y2(:) !< Second curve.
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
   integer(int64),       intent(in), target   :: x(:)  !< Abscissae.
   real(real32),         intent(in), target   :: y1(:) !< First curve.
   real(real32),         intent(in), target   :: y2(:) !< Second curve.
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
   real(real64),         intent(in), target   :: x(:)  !< Abscissae.
   real(real64),         intent(in), target   :: y(:)  !< Curve.
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
   real(real32),         intent(in), target   :: x(:)  !< Abscissae.
   real(real32),         intent(in), target   :: y(:)  !< Curve.
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
   integer(int32),       intent(in), target   :: x(:)  !< Abscissae.
   real(real64),         intent(in), target   :: y(:)  !< Curve.
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
   integer(int64),       intent(in), target   :: x(:)  !< Abscissae.
   real(real64),         intent(in), target   :: y(:)  !< Curve.
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
   integer(int32),       intent(in), target   :: x(:)  !< Abscissae.
   real(real32),         intent(in), target   :: y(:)  !< Curve.
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
   integer(int64),       intent(in), target   :: x(:)  !< Abscissae.
   real(real32),         intent(in), target   :: y(:)  !< Curve.
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
   s%marker = ctx%marker
   s%flags = spec%flags
   if (ctx%hovered) then
      s%weight = s%weight * HIGHLIGHT_LINE_SCALE
      s%marker_size = s%marker_size * HIGHLIGHT_MARK_SCALE
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
   real(real64), target, intent(in)    :: a(:) !< Array.

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
   real(real32), target, intent(in)    :: a(:) !< Array.

   g%src(k) = SRC_R32
   if (k == 1_int32) then
      g%a32 => a
   else
      g%b32 => a
   endif
   endsubroutine view_r32

   subroutine view_i32(g, a, via32)
   !< The abscissae of a getter from an int32 array: each converted as FIGURE's API converts them (to the ordinates'
   !< kind), then to double.
   type(item_series),      intent(inout) :: g     !< Getter.
   integer(int32), target, intent(in)    :: a(:)  !< Array.
   logical,                intent(in)    :: via32 !< Single precision ordinates.

   g%src(1) = SRC_I32
   g%ai32 => a
   g%via32 = via32
   endsubroutine view_i32

   subroutine view_i64(g, a, via32)
   !< The abscissae of a getter from an int64 array (as `view_i32`).
   type(item_series),      intent(inout) :: g     !< Getter.
   integer(int64), target, intent(in)    :: a(:)  !< Array.
   logical,                intent(in)    :: via32 !< Single precision ordinates.

   g%src(1) = SRC_I64
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

   ! private: the decimation (figure_implot's series_decimate)

   subroutine decimate_series(g, item, spec, ctx, fill)
   !< Decimate a line-like getter (figure_decimate, M4 per pixel column) when it has more than DECIMATE_THRESHOLD points
   !< a column: its kept points read through `keep`. Not decimated: decimation off, few points, markers, `Segments`,
   !< `Loop`, unsorted abscissae.
   type(item_series),    intent(inout) :: g     !< Getter.
   integer(int32),       intent(in)    :: item  !< KIND_LINE, KIND_STAIRS.
   type(plot_item_spec), intent(in)    :: spec  !< Style.
   type(plot_item_ctx),  intent(in)    :: ctx   !< The plot.
   logical,              intent(in)    :: fill  !< The item fills an area.
   type(decimate_axis)                 :: ax    !< The x axis.
   integer(int64)                      :: nk    !< Points kept.
   logical                             :: dec   !< Decimated.

   if (.not. wanted(g, item, spec, ctx, ax)) return
   select case (g%src(2))
   case (SRC_R64)
      select case (g%src(1))
      case (SRC_R64)
         dec = decimate(ax, g%a64(1:g%n), g%b64(1:g%n), keep, nk, fill=fill)
      case (SRC_LIN)
         dec = decimate(ax, g%lin(1, 1), g%lin(2, 1), g%b64(1:g%n), keep, nk, fill=fill)
      case default
         call convert64(g)
         dec = decimate(ax, conv64(1:g%n), g%b64(1:g%n), keep, nk, fill=fill)
      endselect
   case (SRC_R32)
      select case (g%src(1))
      case (SRC_R32)
         dec = decimate(ax, g%a32(1:g%n), g%b32(1:g%n), keep, nk, fill=fill)
      case (SRC_LIN)
         dec = decimate(ax, g%lin(1, 1), g%lin(2, 1), g%b32(1:g%n), keep, nk, fill=fill)
      case default
         call convert32(g)
         dec = decimate(ax, conv32(1:g%n), g%b32(1:g%n), keep, nk, fill=fill)
      endselect
   case default
      dec = .false.
   endselect
   if (.not. dec) return
   g%kept = .true.
   g%n = int(nk, int32)
   endsubroutine decimate_series

   subroutine decimate_pair(g1, g2, spec, ctx)
   !< Decimate a shaded item's two getters together (the second's y as the second ordinates), as `decimate_series`.
   type(item_series),    intent(inout) :: g1, g2 !< Getters.
   type(plot_item_spec), intent(in)    :: spec   !< Style.
   type(plot_item_ctx),  intent(in)    :: ctx    !< The plot.
   type(decimate_axis)                 :: ax     !< The x axis.
   integer(int64)                      :: nk     !< Points kept.
   logical                             :: dec    !< Decimated.

   if (.not. wanted(g1, KIND_SHADED, spec, ctx, ax)) return
   dec = .false.
   if (g2%src(2) == SRC_CONST) then ! a reference line: y alone
      call decimate_series(g1, KIND_SHADED, spec, ctx, .true.)
      if (g1%kept) then
         g2%kept = .true.
         g2%n = g1%n
      endif
      return
   endif
   select case (g1%src(2))
   case (SRC_R64)
      select case (g1%src(1))
      case (SRC_R64)
         dec = decimate(ax, g1%a64(1:g1%n), g1%b64(1:g1%n), keep, nk, y2=g2%b64(1:g1%n), fill=.true.)
      case default
         call convert64(g1)
         dec = decimate(ax, conv64(1:g1%n), g1%b64(1:g1%n), keep, nk, y2=g2%b64(1:g1%n), fill=.true.)
      endselect
   case (SRC_R32)
      select case (g1%src(1))
      case (SRC_R32)
         dec = decimate(ax, g1%a32(1:g1%n), g1%b32(1:g1%n), keep, nk, y2=g2%b32(1:g1%n), fill=.true.)
      case default
         call convert32(g1)
         dec = decimate(ax, conv32(1:g1%n), g1%b32(1:g1%n), keep, nk, y2=g2%b32(1:g1%n), fill=.true.)
      endselect
   case default
   endselect
   if (.not. dec) return
   g1%kept = .true.
   g1%n = int(nk, int32)
   g2%kept = .true.
   g2%n = g1%n
   endsubroutine decimate_pair

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
   !< `RendererLineStrip` (`...Skip`: a NaN point keeps the last good one), over the loop's getter with `loop`.
   type(plot_item_ctx), intent(in) :: ctx      !< The plot.
   type(item_series),   intent(in) :: g        !< Getter.
   integer(int32),      intent(in) :: col      !< Colour.
   real(real32),        intent(in) :: weight   !< Line weight.
   logical,             intent(in) :: loop     !< GetterLoop: the first point again at the end.
   logical,             intent(in) :: skip_nan !< SkipNaN.
   real(real32)                    :: p1(2), p2(2), hw !< Ends, half weight.
   real(real64)                    :: uv0(2), uv1(2)   !< Texture.
   integer(int32)                  :: k, nprim         !< Primitive, count.

   call line_props(weight, hw, uv0, uv1)
   nprim = g%n - 1_int32
   if (loop) nprim = g%n
   call pixel(ctx, g, 1_int32, p1)
   do k = 1_int32, nprim
      call pixel(ctx, g, mod(k, g%n) + 1_int32, p2) ! (the loop's last point is the first)
      if (overlaps(ctx%rect, im_min(p1(1), p2(1)), im_min(p1(2), p2(2)), im_max(p1(1), p2(1)), &
                   im_max(p1(2), p2(2)))) call prim_line(p1, p2, hw, col, uv0, uv1)
      if (.not. skip_nan .or. .not. (ieee_is_nan(p2(1)) .or. ieee_is_nan(p2(2)))) p1 = p2
   enddo
   endsubroutine render_strip

   subroutine render_segments1(ctx, g, col, weight)
   !< `RendererLineSegments1`: a segment from every two consecutive points.
   type(plot_item_ctx), intent(in) :: ctx    !< The plot.
   type(item_series),   intent(in) :: g      !< Getter.
   integer(int32),      intent(in) :: col    !< Colour.
   real(real32),        intent(in) :: weight !< Line weight.
   real(real32)                    :: p1(2), p2(2), hw !< Ends, half weight.
   real(real64)                    :: uv0(2), uv1(2)   !< Texture.
   integer(int32)                  :: k                !< Primitive.

   call line_props(weight, hw, uv0, uv1)
   do k = 0_int32, g%n / 2_int32 - 1_int32
      call pixel(ctx, g, 2_int32 * k + 1_int32, p1)
      call pixel(ctx, g, 2_int32 * k + 2_int32, p2)
      if (overlaps(ctx%rect, im_min(p1(1), p2(1)), im_min(p1(2), p2(2)), im_max(p1(1), p2(1)), &
                   im_max(p1(2), p2(2)))) call prim_line(p1, p2, hw, col, uv0, uv1)
   enddo
   endsubroutine render_segments1

   subroutine render_segments2(ctx, g1, g2, col, weight)
   !< `RendererLineSegments2`: a segment from each point of one getter to the same point of the other.
   type(plot_item_ctx), intent(in) :: ctx    !< The plot.
   type(item_series),   intent(in) :: g1, g2 !< Getters.
   integer(int32),      intent(in) :: col    !< Colour.
   real(real32),        intent(in) :: weight !< Line weight.
   real(real32)                    :: p1(2), p2(2), hw !< Ends, half weight.
   real(real64)                    :: uv0(2), uv1(2)   !< Texture.
   integer(int32)                  :: k                !< Primitive.

   call line_props(weight, hw, uv0, uv1)
   do k = 1_int32, min(g1%n, g2%n)
      call pixel(ctx, g1, k, p1)
      call pixel(ctx, g2, k, p2)
      if (overlaps(ctx%rect, im_min(p1(1), p2(1)), im_min(p1(2), p2(2)), im_max(p1(1), p2(1)), &
                   im_max(p1(2), p2(2)))) call prim_line(p1, p2, hw, col, uv0, uv1)
   enddo
   endsubroutine render_segments2

   subroutine render_stairs(ctx, g, col, weight, pre)
   !< `RendererStairsPre`/`RendererStairsPost`: two filled rectangles a step, of the line's weight.
   type(plot_item_ctx), intent(in) :: ctx    !< The plot.
   type(item_series),   intent(in) :: g      !< Getter.
   integer(int32),      intent(in) :: col    !< Colour.
   real(real32),        intent(in) :: weight !< Line weight.
   logical,             intent(in) :: pre    !< PreStep.
   real(real32)                    :: p1(2), p2(2), hw !< Ends, half weight.
   integer(int32)                  :: k                !< Primitive.

   hw = max(1.0_real32, weight) * 0.5_real32
   call pixel(ctx, g, 1_int32, p1)
   do k = 1_int32, g%n - 1_int32
      call pixel(ctx, g, k + 1_int32, p2)
      if (overlaps(ctx%rect, im_min(p1(1), p2(1)), im_min(p1(2), p2(2)), im_max(p1(1), p2(1)), &
                   im_max(p1(2), p2(2)))) then
         if (pre) then
            call prim_rect_fill(p1(1) - hw, p1(2), p1(1) + hw, p2(2), col)
            call prim_rect_fill(p1(1), p2(2) + hw, p2(1), p2(2) - hw, col)
         else
            call prim_rect_fill(p1(1), p1(2) + hw, p2(1), p1(2) - hw, col)
            call prim_rect_fill(p2(1) - hw, p2(2), p2(1) + hw, p1(2), col)
         endif
      endif
      p1 = p2
   enddo
   endsubroutine render_stairs

   subroutine render_stairs_shaded(ctx, g, col, pre)
   !< `RendererStairsPreShaded`/`PostShaded`: a filled rectangle from each step to y = 0.
   type(plot_item_ctx), intent(in) :: ctx !< The plot.
   type(item_series),   intent(in) :: g   !< Getter.
   integer(int32),      intent(in) :: col !< Colour.
   logical,             intent(in) :: pre !< PreStep.
   real(real32)                    :: p1(2), p2(2), y0, pmin(2), pmax(2) !< Ends, the pixel of y = 0, the rectangle.
   integer(int32)                  :: k   !< Primitive.

   call pixel(ctx, g, 1_int32, p1)
   y0 = map_pixel(ctx%ty, 0.0_real64)
   do k = 1_int32, g%n - 1_int32
      call pixel(ctx, g, k + 1_int32, p2)
      pmin(1) = im_min(p1(1), p2(1))
      pmax(1) = im_max(p1(1), p2(1))
      if (pre) then
         pmin(2) = im_min(y0, p2(2))
         pmax(2) = im_max(y0, p2(2))
      else
         pmin(2) = im_min(p1(2), y0)
         pmax(2) = im_max(p1(2), y0)
      endif
      if (overlaps(ctx%rect, pmin(1), pmin(2), pmax(1), pmax(2))) &
         call prim_rect_fill(pmin(1), pmin(2), pmax(1), pmax(2), col)
      p1 = p2
   enddo
   endsubroutine render_stairs_shaded

   subroutine render_shaded(ctx, g1, g2, col)
   !< `RendererShaded`: between two getters, a quad per step, two triangles at the crossing when they cross.
   type(plot_item_ctx), intent(in) :: ctx    !< The plot.
   type(item_series),   intent(in) :: g1, g2 !< Getters.
   integer(int32),      intent(in) :: col    !< Colour.
   real(real32)                    :: p11(2), p12(2), p21(2), p22(2), q(2) !< Corners, the crossing.
   real(real32)                    :: rmin(2), rmax(2) !< Their bounds.
   integer(int32)                  :: k                !< Primitive.
   logical                         :: cross            !< The curves cross.

   call pixel(ctx, g1, 1_int32, p11)
   call pixel(ctx, g2, 1_int32, p12)
   do k = 1_int32, min(g1%n, g2%n) - 1_int32
      call pixel(ctx, g1, k + 1_int32, p21)
      call pixel(ctx, g2, k + 1_int32, p22)
      rmin(1) = im_min(im_min(im_min(p11(1), p12(1)), p21(1)), p22(1))
      rmin(2) = im_min(im_min(im_min(p11(2), p12(2)), p21(2)), p22(2))
      rmax(1) = im_max(im_max(im_max(p11(1), p12(1)), p21(1)), p22(1))
      rmax(2) = im_max(im_max(im_max(p11(2), p12(2)), p21(2)), p22(2))
      if (overlaps(ctx%rect, rmin(1), rmin(2), rmax(1), rmax(2))) then
         cross = (p11(2) > p12(2) .and. p22(2) > p21(2)) .or. (p12(2) > p11(2) .and. p21(2) > p22(2))
         if (cross) then ! triangles (P11, X, P12) and (P21, P22, X)
            q = intersection(p11, p21, p12, p22)
            call prim_quad(p11, q, p12, p11, col)
            call prim_quad(p21, p22, q, p21, col)
         else ! triangles (P11, P21, P12) and (P21, P22, P12)
            call prim_quad(p21, p22, p12, p11, col)
         endif
      endif
      p11 = p21
      p12 = p22
   enddo
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
   !< `RendererMarkersFill`: the shape's vertices about each point, a fan from the first (as quads of the fan's
   !< triangles: (0, 1, 2, 3), (0, 3, 4, 5), ...; a lone last triangle with a repeated vertex).
   type(plot_item_ctx), intent(in) :: ctx         !< The plot.
   type(item_series),   intent(in) :: g           !< Getter.
   real(real32),        intent(in) :: shape(:, :) !< The shape (x, y) x count.
   integer(int32),      intent(in) :: col         !< Colour.
   real(real32),        intent(in) :: msize       !< Size [pixels].
   real(real32)                    :: p(2), v(2, 10), w !< Point, vertices, product.
   integer(int32)                  :: i, k, nv    !< Point, vertex, count.

   nv = int(size(shape, 2), int32)
   do i = 1_int32, g%n
      call pixel(ctx, g, i, p)
      if (.not. (p(1) >= ctx%rect(1) .and. p(2) >= ctx%rect(2) .and. p(1) <= ctx%rect(3) .and. &
                 p(2) <= ctx%rect(4))) cycle
      do k = 1_int32, nv
         w = shape(1, k) * msize
         v(1, k) = p(1) + w
         w = shape(2, k) * msize
         v(2, k) = p(2) + w
      enddo
      k = 2_int32 ! the fan's triangles (1, k, k + 1), two a quad
      do while (k < nv)
         if (k + 2_int32 <= nv) then
            call prim_quad(v(:, 1), v(:, k), v(:, k + 1), v(:, k + 2), col)
         else
            call prim_quad(v(:, 1), v(:, k), v(:, k + 1), v(:, 1), col)
         endif
         k = k + 2_int32
      enddo
   enddo
   endsubroutine markers_fill

   subroutine markers_line(ctx, g, shape, col, msize, weight)
   !< `RendererMarkersLine`: the shape's segments (pairs of vertices) about each point, as anti-aliased lines.
   type(plot_item_ctx), intent(in) :: ctx         !< The plot.
   type(item_series),   intent(in) :: g           !< Getter.
   real(real32),        intent(in) :: shape(:, :) !< Segments' ends (x, y) x count.
   integer(int32),      intent(in) :: col         !< Colour.
   real(real32),        intent(in) :: msize       !< Size [pixels].
   real(real32),        intent(in) :: weight      !< Line weight.
   real(real32)                    :: p(2), p1(2), p2(2), hw, w !< Point, ends, half weight, product.
   real(real64)                    :: uv0(2), uv1(2) !< Texture.
   integer(int32)                  :: i, k        !< Point, segment.

   call line_props(weight, hw, uv0, uv1)
   do i = 1_int32, g%n
      call pixel(ctx, g, i, p)
      if (.not. (p(1) >= ctx%rect(1) .and. p(2) >= ctx%rect(2) .and. p(1) <= ctx%rect(3) .and. &
                 p(2) <= ctx%rect(4))) cycle
      do k = 1_int32, int(size(shape, 2), int32) - 1_int32, 2_int32
         w = shape(1, k) * msize
         p1(1) = p(1) + w
         w = shape(2, k) * msize
         p1(2) = p(2) + w
         w = shape(1, k + 1_int32) * msize
         p2(1) = p(1) + w
         w = shape(2, k + 1_int32) * msize
         p2(2) = p(2) + w
         call prim_line(p1, p2, hw, col, uv0, uv1)
      enddo
   enddo
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

   subroutine prim_line(p1, p2, hw, col, uv0, uv1)
   !< `PrimLine`: a segment as a quad of the line's texture, `hw` each side.
   real(real32),   intent(in) :: p1(2), p2(2)   !< Ends [pixels].
   real(real32),   intent(in) :: hw             !< Half width [pixels].
   integer(int32), intent(in) :: col            !< Colour.
   real(real64),   intent(in) :: uv0(2), uv1(2) !< Texture.
   real(real32)               :: dx, dy, d2, inv, a, b !< Direction, products.
   real(real64)               :: qx(4), qy(4), qu(4), qv(4) !< The quad.

   dx = p2(1) - p1(1)
   dy = p2(2) - p1(2)
   a = dx * dx ! (IMPLOT_NORMALIZE2F_OVER_ZERO; the products apart)
   b = dy * dy
   d2 = a + b
   if (d2 > 0.0_real32) then
      inv = 1.0_real32 / sqrt(d2)
      dx = dx * inv
      dy = dy * inv
   endif
   dx = dx * hw
   dy = dy * hw
   qx(1) = real(p1(1) + dy, real64)
   qy(1) = real(p1(2) - dx, real64)
   qx(2) = real(p2(1) + dy, real64)
   qy(2) = real(p2(2) - dx, real64)
   qx(3) = real(p2(1) - dy, real64)
   qy(3) = real(p2(2) + dx, real64)
   qx(4) = real(p1(1) - dy, real64)
   qy(4) = real(p1(2) + dx, real64)
   qu(1) = uv0(1)
   qu(2) = uv0(1)
   qu(3) = uv1(1)
   qu(4) = uv1(1)
   qv(1) = uv0(2)
   qv(2) = uv0(2)
   qv(3) = uv1(2)
   qv(4) = uv1(2)
   call core_draw_quad_uv(qx, qy, qu, qv, col)
   endsubroutine prim_line

   subroutine prim_rect_fill(x0, y0, x1, y1, col)
   !< `PrimRectFill(Pmin, Pmax)`: triangles (Pmin, Pmax, (Pmin.x, Pmax.y)) and (Pmin, Pmax, (Pmax.x, Pmin.y)), the
   !< white pixel; as the quad (Pmin, (Pmin.x, Pmax.y), Pmax, (Pmax.x, Pmin.y)): the same two triangles.
   real(real32),   intent(in) :: x0, y0 !< Pmin [pixels].
   real(real32),   intent(in) :: x1, y1 !< Pmax [pixels].
   integer(int32), intent(in) :: col    !< Colour.

   call prim_quad([x0, y0], [x0, y1], [x1, y1], [x1, y0], col)
   endsubroutine prim_rect_fill

   subroutine prim_quad(a, b, c, d, col)
   !< Triangles (a, b, c) and (a, c, d) of the white pixel (`d = a`: the triangle (a, b, c) alone).
   real(real32),   intent(in) :: a(2), b(2), c(2), d(2) !< Vertices [pixels].
   integer(int32), intent(in) :: col                    !< Colour.
   real(real64)               :: qx(4), qy(4), qu(4), qv(4) !< The quad.

   qx(1) = real(a(1), real64)
   qy(1) = real(a(2), real64)
   qx(2) = real(b(1), real64)
   qy(2) = real(b(2), real64)
   qx(3) = real(c(1), real64)
   qy(3) = real(c(2), real64)
   qx(4) = real(d(1), real64)
   qy(4) = real(d(2), real64)
   qu = uv_white(1)
   qv = uv_white(2)
   call core_draw_quad_uv(qx, qy, qu, qv, col)
   endsubroutine prim_quad

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
   !< `ImRect::Overlaps` of the plot rectangle and (x0, y0)-(x1, y1) (false with a NaN).
   real(real32), intent(in) :: r(4)           !< Rectangle.
   real(real32), intent(in) :: x0, y0, x1, y1 !< Other.
   logical                  :: yes            !< Overlap.

   yes = r(2) < y1 .and. r(4) > y0 .and. r(1) < x1 .and. r(3) > x0
   endfunction overlaps

   pure function im_min(a, b) result(c)
   !< `ImMin`: a < b ? a : b (the second with a NaN).
   real(real32), intent(in) :: a, b !< Values.
   real(real32)             :: c    !< Minimum.

   if (a < b) then
      c = a
   else
      c = b
   endif
   endfunction im_min

   pure function im_max(a, b) result(c)
   !< `ImMax`: a >= b ? a : b.
   real(real32), intent(in) :: a, b !< Values.
   real(real32)             :: c    !< Maximum.

   if (a >= b) then
      c = a
   else
      c = b
   endif
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

   do k = 1_int32, 4_int32
      c(k) = real(iand(ishft(int(col, int64), -8 * int(k - 1_int32, int64)), 255_int64), real32) * S
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
   do k = 1_int32, 4_int32
      u = ior(u, ishft(int(min(max(v(k), 0.0_real32), 1.0_real32) * 255.0_real32 + 0.5_real32, int64), &
                       8 * int(k - 1_int32, int64)))
   enddo
   if (u >= 2147483648_int64) u = u - 4294967296_int64
   col = int(u, int32)
   endfunction color_u32
endmodule figure_plot_items
