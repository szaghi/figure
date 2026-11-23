!< figure_plot_frame, the Fortran path's plot frame: a plot's layout, axes, ticks, grid, legend and lines, as ImPlot
!< draws them.
module figure_plot_frame
!< figure_plot_frame, the Fortran path's plot frame: a plot's layout, axes, ticks, grid, legend and lines, as ImPlot
!< draws them.
!<
!< szaghi/figure#15 P10. A plot drawn through figure_core only (no ImPlot, no figure_cimplot), to the pixels ImPlot 1.2
!< WIP (FIGURE's copy) draws for the same plot: `pf_begin_plot`, `pf_setup_axes`, `pf_setup_axis`,
!< `pf_setup_axes_limits`, `pf_setup_axis_limits`, `pf_setup_legend`, `pf_set_next_axes_to_fit`,
!< `pf_set_next_axis_to_fit`, `pf_set_axes`, `pf_hide_next_item`, `pf_line`, `pf_legend_hovered`, `pf_plot_limits`,
!< `pf_end_plot` draw what `ip_begin_plot`, `ip_setup_axes`, `ip_setup_axis`, `ip_setup_axes_limits`,
!< `ip_setup_axis_limits`, `ip_setup_legend`, ImPlot's `SetNextAxesToFit`/`SetNextAxisToFit`, `ip_set_axes`,
!< `ip_hide_next_item`, `ip_line`, `ip_legend_hovered`, `ip_plot_limits`, `ip_end_plot` draw for a plot of linear
!< axes, lines of the default weight, the pointer away from the plot area (no mouse text, no pan or zoom). Reproduced
!< from implot.cpp, implot_items.cpp and implot_internal.h, their arithmetic kept (single precision where ImPlot's is
!< `float`, double where it is `double`):
!<
!< - the plots kept between frames (`ImPlotContext::Plots`, `ImPlotPlot`): a table of plots keyed by the ID of their
!<   title in the window's ID stack (`core_get_id`, ImPlot's `Window->GetID(title_id)`), each with its axes (range,
!<   flags, the limits' condition, the range fit), its items, its legend and the frame it was last drawn on; integer
!<   handles into a table that grows (8 plots, doubled up to 256; past that the least recently drawn plot not drawn on
!<   this frame makes room: ImPlot keeps every plot for the context's life); one plot open at a time (ImPlot forbids
!<   nesting), several one after another in a frame;
!< - a plot's items (`ImPlotItemGroup`): keyed by the ID ImPlot gives them, the label hashed with the seed
!<   `plot.ID - 1` (figure_plot_hash), each with its colour, given (`color=`) or assigned once, when the item is
!<   created, from the colormap's next colour (`NextColormapColorU32`: the plot's own counter, `ColormapIdx`), whether
!<   it is shown (`HideNextItem`, a click on its legend entry) and whether its legend entry is hovered; a table per
!<   plot, as the plots' (256 items, then the least recently drawn one makes room);
!< - the limits (`SetupAxisLimits`): applied every frame (`ImPlotCond_Always`, which also locks the axis against any
!<   fit), or until the plot has been drawn once (`ImPlotCond_Once`, the default as FIGURE's `ip_setup_*_limits`);
!< - the fit to the data (`SetupFinish`, `BeginItemEx`, `EndPlot`, `ImPlotAxis::ExtendFitWith`, `ApplyFit`): an axis
!<   fits on the plot's first frame if it has no limits (`CanInitFit`), on every frame with `auto_fit`
!<   (`ImPlotAxisFlags_AutoFit`), on the frame after `pf_set_next_axis_to_fit`; the items shown extend the fit range of
!<   the axes they use (`pf_set_axes`) while the plot is drawn with its current ranges, and the fit is applied at
!<   `pf_end_plot`: the picture shows it on the next frame (ImPlot's one-frame lag). The fit pads the range by
!<   `FitPadding` (0, ImPlot's default), a degenerate range (`ImAlmostEqual` of its ends, 2 ulp) becomes
!<   [v - 0.5, v + 0.5]; ends locked (`lock`, limits `always`) are kept. An axis with no data does not fit (FIGURE's
!<   `fig_plot_end`). x and y follow the same rules; with `equal=.true.` (`ImPlotFlags_Equal`) each pair X1-Y1, X2-Y2,
!<   X3-Y3 gets the same units per pixel, as `SetupFinish` and `EndPlot` constrain them;
!< - the axes X1, X2, X3, Y1, Y2, Y3 (`SetupAxis`): X1 and Y1 always, the others on the frames they are set up, their
!<   flags as FIGURE's `ip_setup_axis` makes them (the secondary axes on the opposite side, without grid lines, unless
!<   asked), inverted axes;
!< - the layout of `BeginPlot` and `SetupFinish`: the frame, `PlotPadding`, an outside legend's room (from the legend
!<   of the frame before, as ImPlot), the title above the plot (`LabelPadding`), the x axes below or above it and the y
!<   axes left or right of it, outwards in order (`PadAndDatumAxesX`, `PadAndDatumAxesY`: their labels, their tick
!<   labels, `MinorTickLen` and `LabelPadding` between two axes on a side), the plot rectangle;
!< - the scales (`SetupAxisScale`; `pf_setup_axis(scale=)`, `pf_setup_axes(xscale=, yscale=)`): linear, log10,
!<   symlog, time (x only), set up every frame; a log10 or symlog axis maps a value through its transform onto the
!<   range (`PlotToPixels`, the items' `Transformer1`), its range constrained (log10 from DBL_MIN, time from 0 to
!<   IMPLOT_MAX_TIME: the fit takes only the values within, on the raw values, as ImPlot's `ExtendFit`);
!< - the ticks (figure_plot_locators): `Locator_Default`, `Locator_Log10`, `Locator_SymLog`, `Locator_Time` with their
!<   labels (`%g`; dates and times on two levels: the second level's room below the first, its labels lower, its ticks
!<   without grid lines or tick marks);
!< - the drawing of `SetupFinish` and `EndPlot`, in their order: the frame (`RenderFrame`, `FrameBg`), the plot's
!<   background (`WindowBg`), the grid (majors, minors faded by `MinorAlpha` and by the ticks' density), each axis's
!<   highlight (an item's colour while its legend entry is hovered, with more than one axis on its direction), label
!<   (x: centred, `AddText`; y: rotated, `AddTextVertical` glyph by glyph from the font's baked glyphs, figure_core's
!<   `core_font_glyph`) and tick labels (`Text`), the items clipped to the plot, the title (`AddTextCentered`), the
!<   tick marks (clipped to the frame; minor length on a side's second and third axes), the legend, the border
!<   (`Border`); ImPlot's automatic colours (`StyleColorsAuto`, from Dear ImGui's style colours) and its default style
!<   variables;
!< - the legend (`ShowLegendEntries`, `CalcLegendSize`, `GetLocationPos`, `ClampLegendRect`): the labelled items in
!<   the order they were first drawn on the frame, an entry an icon (a square of the item's colour, the text height
!<   less 2 pixels each side) and the label, in a column or a row, inside the plot (`LegendPadding`) or outside it
!<   (`PlotPadding`), at a compass point, on `LegendBg` (`PopupBg`) with a `LegendBorder` (`Border`), inner padding and
!<   spacing ImPlot's; an entry is a button (`ButtonBehavior` on the item's ID, after the legend's own, as ImPlot):
!<   clicked, it hides or shows its item; hovered, its text takes a quarter of the item's colour, its icon 3/4 alpha,
!<   and on the next frame the item's line is twice as thick (and its axis highlighted); a hidden item's entry is
!<   greyed (`Text` at 1/4 alpha);
!< - a line (`PlotLine`'s `RendererLineStrip`): each segment a quad of the anti-aliased line's texture, half its
!<   weight (at least 1 pixel) plus half the texture's fringe on each side, the segments outside the plot culled.
!<
!< Not yet (P10's rest, P11, P12): tick formats, local time and ImPlot's time style options (12-hour clock, US dates:
!< ImPlot's defaults), pan, zoom and selection, the mouse text and the axes'
!< hover (the pointer over the plot area), the legend's scrolling and context menus, colormaps other than Deep (the
!< line colours of FIGURE's own styles: seal, paper, ...: their automatic colours are ImPlot's colormaps, registered by
!< the native layer), ImPlot style variables set by a theme (`FitPadding` included), limits' constraints, the axis
!< flags FIGURE's API does not set (`NoInitialFit`, `RangeFit`, `Foreground`, `TickLabelsInside`: kept in the state or
!< not drawn), legend sorting. Items are hashed under the plot's seed but the ID stack is not pushed (figure_core has
!< no `PushOverrideID`): a Dear ImGui widget drawn between `pf_begin_plot` and `pf_end_plot` gets another ID than in
!< ImPlot. The segment's normal is `1/sqrt` where ImPlot takes the SSE estimate `_mm_rsqrt_ss` (12 bits): the line's
!< vertices may differ from ImPlot's below a thousandth of a pixel.
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use figure_cimgui_enums, only : ImGuiCol_Border, ImGuiCol_BorderShadow, ImGuiCol_FrameBg, ImGuiCol_PopupBg, &
                                ImGuiCol_Text, ImGuiCol_TextDisabled, ImGuiCol_WindowBg
use figure_core, only : core_button_behavior, core_color, core_content_region_avail, core_cursor_screen_pos, &
                        core_draw_begin, core_draw_end, core_draw_line_h, core_draw_line_v, core_draw_quad_uv, &
                        core_draw_rect, core_draw_rect_filled, core_draw_text, core_font_glyph, core_font_size, &
                        core_frame_count, core_get_id, core_item_add, core_item_size, core_keep_alive,         &
                        core_line_texture, core_pop_clip_rect, core_push_clip_rect, core_style_color,           &
                        core_style_var, core_text_size
use figure_plot_hash, only : plot_hash, plot_id_offset
use figure_plot_locators, only : plot_ticks, ticks_reset, locate_default, locate_log10, locate_symlog, locate_time, &
                                transform_log10, transform_symlog, TIME_MAX, TIME_MIN

implicit none
private
public :: pf_begin_plot, pf_end_plot, pf_line, pf_plot_limits
public :: pf_setup_axes, pf_setup_axis, pf_setup_axes_limits, pf_setup_axis_limits, pf_setup_legend
public :: pf_set_next_axes_to_fit, pf_set_next_axis_to_fit, pf_set_axes
public :: pf_hide_next_item, pf_legend_hovered
public :: pf_plot_count

! ImPlot's style defaults (ImPlotStyle::ImPlotStyle, StyleColorsAuto)
real(real32), parameter :: PLOT_DEFAULT_SIZE(2) = [400.0_real32, 300.0_real32] !< PlotDefaultSize [pixels].
real(real32), parameter :: PLOT_MIN_SIZE(2) = [200.0_real32, 150.0_real32]     !< PlotMinSize [pixels].
real(real32), parameter :: PLOT_BORDER_SIZE = 1.0_real32                       !< PlotBorderSize [pixels].
real(real32), parameter :: MINOR_ALPHA = 0.25_real32                           !< MinorAlpha.
real(real32), parameter :: MAJOR_TICK_LEN(2) = [10.0_real32, 10.0_real32]      !< MajorTickLen [pixels].
real(real32), parameter :: MINOR_TICK_LEN(2) = [5.0_real32, 5.0_real32]        !< MinorTickLen [pixels].
real(real32), parameter :: MAJOR_TICK_SIZE(2) = [1.0_real32, 1.0_real32]       !< MajorTickSize [pixels].
real(real32), parameter :: MINOR_TICK_SIZE(2) = [1.0_real32, 1.0_real32]       !< MinorTickSize [pixels].
real(real32), parameter :: MAJOR_GRID_SIZE(2) = [1.0_real32, 1.0_real32]       !< MajorGridSize [pixels].
real(real32), parameter :: MINOR_GRID_SIZE(2) = [1.0_real32, 1.0_real32]       !< MinorGridSize [pixels].
real(real32), parameter :: PLOT_PADDING(2) = [10.0_real32, 10.0_real32]        !< PlotPadding [pixels].
real(real32), parameter :: LABEL_PADDING(2) = [5.0_real32, 5.0_real32]         !< LabelPadding [pixels].
real(real32), parameter :: LEGEND_PADDING(2) = [10.0_real32, 10.0_real32]      !< LegendPadding [pixels].
real(real32), parameter :: LEGEND_INNER_PADDING(2) = [5.0_real32, 5.0_real32]  !< LegendInnerPadding [pixels].
real(real32), parameter :: LEGEND_SPACING(2) = [5.0_real32, 0.0_real32]        !< LegendSpacing [pixels].
real(real32), parameter :: FIT_PADDING(2) = [0.0_real32, 0.0_real32]           !< FitPadding (fraction of the range).
real(real32), parameter :: LINE_WEIGHT = 1.0_real32                            !< ImPlotSpec's LineWeight [pixels].
real(real32), parameter :: HIGHLIGHT_LINE_SCALE = 2.0_real32                   !< ITEM_HIGHLIGHT_LINE_SCALE.
! ImPlotScale (implot.h)
integer(int32), parameter :: SCALE_LINEAR = 0_int32 !< ImPlotScale_Linear.
integer(int32), parameter :: SCALE_TIME = 1_int32   !< ImPlotScale_Time.
integer(int32), parameter :: SCALE_LOG10 = 2_int32  !< ImPlotScale_Log10.
integer(int32), parameter :: SCALE_SYMLOG = 3_int32 !< ImPlotScale_SymLog.
! the axes (ImAxis, one-based)
integer(int32), parameter :: AX_X1 = 1_int32 !< X1.
integer(int32), parameter :: AX_X3 = 3_int32 !< X3.
integer(int32), parameter :: AX_Y1 = 4_int32 !< Y1.
integer(int32), parameter :: AX_Y3 = 6_int32 !< Y3.
integer(int32), parameter :: AXES = 6_int32  !< ImAxis_COUNT.
! ImPlotAxisFlags, ImPlotFlags, ImPlotCond, ImPlotLegendFlags, ImPlotLocation (implot.h)
integer(int32), parameter :: AXF_NO_LABEL = 1_int32        !< ImPlotAxisFlags_NoLabel.
integer(int32), parameter :: AXF_NO_GRID_LINES = 2_int32   !< ImPlotAxisFlags_NoGridLines.
integer(int32), parameter :: AXF_NO_TICK_MARKS = 4_int32   !< ImPlotAxisFlags_NoTickMarks.
integer(int32), parameter :: AXF_NO_TICK_LABELS = 8_int32  !< ImPlotAxisFlags_NoTickLabels.
integer(int32), parameter :: AXF_NO_INITIAL_FIT = 16_int32 !< ImPlotAxisFlags_NoInitialFit.
integer(int32), parameter :: AXF_OPPOSITE = 256_int32      !< ImPlotAxisFlags_Opposite.
integer(int32), parameter :: AXF_FOREGROUND = 512_int32    !< ImPlotAxisFlags_Foreground.
integer(int32), parameter :: AXF_INVERT = 1024_int32       !< ImPlotAxisFlags_Invert.
integer(int32), parameter :: AXF_AUTO_FIT = 2048_int32     !< ImPlotAxisFlags_AutoFit.
integer(int32), parameter :: AXF_RANGE_FIT = 4096_int32    !< ImPlotAxisFlags_RangeFit.
integer(int32), parameter :: AXF_LOCK_MIN = 16384_int32    !< ImPlotAxisFlags_LockMin.
integer(int32), parameter :: AXF_LOCK_MAX = 32768_int32    !< ImPlotAxisFlags_LockMax.
integer(int32), parameter :: PF_NO_TITLE = 1_int32         !< ImPlotFlags_NoTitle.
integer(int32), parameter :: PF_NO_LEGEND = 2_int32        !< ImPlotFlags_NoLegend.
integer(int32), parameter :: PF_EQUAL = 128_int32          !< ImPlotFlags_Equal.
integer(int32), parameter :: COND_ALWAYS = 1_int32         !< ImPlotCond_Always.
integer(int32), parameter :: COND_ONCE = 2_int32           !< ImPlotCond_Once.
integer(int32), parameter :: LGF_NO_BUTTONS = 1_int32      !< ImPlotLegendFlags_NoButtons.
integer(int32), parameter :: LGF_NO_HIGHLIGHT_ITEM = 2_int32 !< ImPlotLegendFlags_NoHighlightItem.
integer(int32), parameter :: LGF_NO_HIGHLIGHT_AXIS = 4_int32 !< ImPlotLegendFlags_NoHighlightAxis.
integer(int32), parameter :: LGF_OUTSIDE = 16_int32        !< ImPlotLegendFlags_Outside.
integer(int32), parameter :: LGF_HORIZONTAL = 32_int32     !< ImPlotLegendFlags_Horizontal.
integer(int32), parameter :: LOC_NORTH = 1_int32           !< ImPlotLocation_North.
integer(int32), parameter :: LOC_SOUTH = 2_int32           !< ImPlotLocation_South.
integer(int32), parameter :: LOC_WEST = 4_int32            !< ImPlotLocation_West.
integer(int32), parameter :: LOC_EAST = 8_int32            !< ImPlotLocation_East.
! ImGuiButtonFlags of the legend's rectangle (imgui.h, imgui_internal.h): AllowOverlap, PressedOnClick,
! PressedOnDoubleClick, the three mouse buttons, FlattenChildren
integer(int32), parameter :: LEGEND_BUTTON_FLAGS = 4096_int32 + 16_int32 + 256_int32 + 1_int32 + 2_int32 + 4_int32 + &
                                                   2048_int32 !< ImPlot's `legend_button_flags`.
! the tables
integer(int32), parameter :: PLOT_CAP = 256_int32 !< Plots kept before the least recently drawn one makes room.
integer(int32), parameter :: ITEM_CAP = 256_int32 !< A plot's items kept before the least recently drawn makes room.
! the colormap Deep (implot.cpp), IM_RGB(r, g, b): red in the low byte, opaque
integer(int32), parameter :: DEEP(3, 10) = reshape([76_int32, 114_int32, 176_int32, 221_int32, 132_int32, 82_int32,  &
                                                    85_int32, 168_int32, 104_int32, 196_int32, 78_int32, 82_int32,  &
                                                    129_int32, 114_int32, 179_int32, 147_int32, 120_int32, 96_int32, &
                                                    218_int32, 139_int32, 195_int32, 140_int32, 140_int32, 140_int32, &
                                                    204_int32, 185_int32, 116_int32, 100_int32, 181_int32, 205_int32], &
                                                   [3, 10]) !< Its colours, RGB 0-255.

type :: plot_axis
   !< An axis (ImPlotAxis): its state kept between frames, and where it is on screen this frame.
   integer(int32) :: flags = 0_int32                  !< ImPlotAxisFlags in effect.
   integer(int32) :: prev_flags = 0_int32             !< ... those last set up.
   logical        :: enabled = .false.                !< In use on this frame.
   logical        :: has_range = .false.              !< Limits set up on this frame.
   integer(int32) :: range_cond = 0_int32             !< Their condition (COND_ALWAYS, COND_ONCE).
   real(real64)   :: range_min = 0.0_real64           !< Range's minimum.
   real(real64)   :: range_max = 1.0_real64           !< ... maximum.
   logical        :: fit = .false.                    !< Fit at the plot's end (FitThisFrame).
   real(real64)   :: fit_min = huge(1.0_real64)       !< The data's extent on this frame (FitExtents): minimum.
   real(real64)   :: fit_max = -huge(1.0_real64)      !< ... maximum.
   real(real32)   :: pixel_min = 0.0_real32           !< The range's minimum on screen [pixels].
   real(real32)   :: pixel_max = 0.0_real32           !< ... its maximum.
   real(real64)   :: scale_to_pixel = 0.0_real64      !< Pixels per unit.
   integer(int32) :: scale = 0_int32                  !< ImPlotScale (this frame's: set up every frame).
   real(real64)   :: scale_min = 0.0_real64           !< The range's minimum transformed (ScaleMin).
   real(real64)   :: scale_max = 1.0_real64           !< ... its maximum (ScaleMax).
   real(real64)   :: con_min = -huge(1.0_real64)      !< The range's constraint (ConstraintRange): minimum.
   real(real64)   :: con_max = huge(1.0_real64)       !< ... maximum.
   real(real32)   :: datum1 = 0.0_real32              !< Where the axis's ticks start [pixels].
   real(real32)   :: datum2 = 0.0_real32              !< Where its room ends, away from the plot [pixels].
   integer(int32) :: hili = 0_int32                   !< Highlight's colour (ColorHiLi; 0: none).
   integer(int32) :: ortho = 0_int32                  !< The axis of the other direction it pairs with (0: none).
   integer(int32) :: label_off = 0_int32              !< Its label in the text of the frame (0: no label).
   integer(int32) :: label_len = 0_int32              !< ... its length.
endtype plot_axis

type :: plot_record
   !< A plot (ImPlotPlot): what is kept between frames, and its layout on the frame it is drawn.
   integer(int32)                :: id = 0_int32          !< ID (its title's in the window's ID stack).
   logical                       :: used = .false.        !< The slot holds a plot.
   integer(int32)                :: last_frame = -1_int32 !< The frame it was last begun on.
   logical                       :: just_created = .false. !< Created on this frame.
   logical                       :: initialized = .false. !< Drawn to its end once.
   logical                       :: locked = .false.      !< Setup finished on this frame (layout done, frame drawn).
   logical                       :: fit = .false.         !< An axis fits at the end of this frame (FitThisFrame).
   integer(int32)                :: flags = 0_int32       !< ImPlotFlags in effect.
   integer(int32)                :: prev_flags = 0_int32  !< ... those last asked.
   integer(int32)                :: title_off = 0_int32   !< Its title in the text of the frame (0: none).
   integer(int32)                :: title_len = 0_int32   !< ... its length.
   real(real32)                  :: frame(4) = 0.0_real32 !< Frame rectangle: x min, y min, x max, y max [pixels].
   real(real32)                  :: canvas(4) = 0.0_real32 !< Canvas: the frame less the padding (and the legend).
   real(real32)                  :: axes_rect(4) = 0.0_real32 !< Axes' room (AxesRect).
   real(real32)                  :: rect(4) = 0.0_real32  !< Plot rectangle.
   integer(int32)                :: col_maj = 0_int32     !< Major grid lines' colour.
   integer(int32)                :: col_min = 0_int32     !< Minor grid lines' colour.
   integer(int32)                :: col_tick = 0_int32    !< Tick marks' colour.
   integer(int32)                :: col_txt = 0_int32     !< Tick labels' and axis labels' colour.
   integer(int32)                :: col_border = 0_int32  !< Border's colour.
   type(plot_axis)               :: ax(AXES)              !< Axes: X1, X2, X3, Y1, Y2, Y3.
   integer(int32)                :: cur_x = AX_X1         !< The x axis the items use (CurrentX).
   integer(int32)                :: cur_y = AX_Y1         !< ... the y axis.
   integer(int32)                :: colormap_idx = 0_int32 !< Automatic colours given (ColormapIdx).
   integer(int32)                :: n_items = 0_int32     !< Items held.
   integer(int32)                :: item_next = 1_int32   !< Where the search for the next item starts.
   integer(int32), allocatable   :: item_id(:)            !< Item's ID.
   integer(int32), allocatable   :: item_color(:)         !< ... colour (packed).
   integer(int32), allocatable   :: item_frame(:)         !< ... the frame it was last drawn on.
   logical,        allocatable   :: item_show(:)          !< ... shown (Show).
   logical,        allocatable   :: item_hovered(:)       !< ... its legend entry hovered (LegendHovered).
   integer(int32)                :: leg_flags = 0_int32   !< Legend's ImPlotLegendFlags in effect.
   integer(int32)                :: leg_prev_flags = 0_int32 !< ... those last asked.
   integer(int32)                :: leg_loc = LOC_NORTH + LOC_WEST !< Legend's ImPlotLocation in effect.
   integer(int32)                :: leg_prev_loc = LOC_NORTH + LOC_WEST !< ... that last asked.
   logical                       :: leg_hovered = .false. !< Legend hovered.
   integer(int32)                :: n_leg = 0_int32       !< Legend's entries.
   integer(int32), allocatable   :: leg_item(:)           !< Entry's item.
   integer(int32), allocatable   :: leg_off(:)            !< ... label's start in `leg_text`.
   integer(int32), allocatable   :: leg_len(:)            !< ... label's length.
   integer(int32)                :: leg_n = 0_int32       !< Characters of `leg_text` in use.
   character(len=:), allocatable :: leg_text              !< Legend's labels.
endtype plot_record

type(plot_record), allocatable, target :: plots(:)       !< The plots (ImPlotContext::Plots).
integer(int32)                         :: n_plots = 0_int32 !< Slots of `plots` in use.
integer(int32)                         :: cur = 0_int32  !< The plot open (0: none).
logical                                :: next_fit(AXES) = .false. !< Axes to fit on the next plot (NextPlotData.Fit).
logical                                :: next_hidden_set = .false. !< The next item's visibility set (HasHidden).
logical                                :: next_hidden = .false. !< ... hidden.
integer(int32)                         :: next_hidden_cond = 0_int32 !< ... its condition.
type(plot_ticks), target               :: ticks(AXES)    !< The open plot's ticks, per axis.
character(len=:), allocatable          :: text           !< The open plot's title and axis labels (TextBuffer).
integer(int32)                         :: n_text = 0_int32 !< Characters of `text` in use.

contains
   function pf_begin_plot(title, width, height, equal) result(visible)
   !< Begin a plot (`BeginPlot`): its frame placed at the cursor, `width` x `height` pixels (default: the full width,
   !< ImPlot's default height; a negative size is the room left less it); `equal`: the same units per pixel on x and
   !< y (`ImPlotFlags_Equal`). When true, declare its content and call `pf_end_plot`. A plot is kept between frames by
   !< its ID (its title's: `##` hides what follows, `###` makes the ID of what follows only).
   character(len=*), intent(in)           :: title   !< Title (also the plot's ID).
   real(real64),     intent(in), optional :: width   !< Width [pixels].
   real(real64),     intent(in), optional :: height  !< Height [pixels].
   logical,          intent(in), optional :: equal   !< Same units per pixel on both axes.
   logical                                :: visible !< Plot visible.
   real(real32)                           :: req(2)  !< Size asked.
   real(real32)                           :: ext(2)  !< Frame's size.
   real(real64)                           :: cx, cy  !< Cursor.
   real(real64)                           :: aw, ah  !< Room left.
   integer(int32)                         :: id      !< ID.
   integer(int32)                         :: h       !< The plot's handle.
   integer(int32)                         :: flags   !< ImPlotFlags.
   integer(int32)                         :: i       !< Axis.
   logical                                :: created !< The plot is new.

   visible = .false.
   if (cur /= 0_int32) error stop 'figure_plot_frame: pf_begin_plot while a plot is open'
   flags = 0_int32
   if (present(equal)) then
      if (equal) flags = PF_EQUAL
   endif
   id = core_get_id(title)
   h = plot_handle(id, core_frame_count(), created)
   associate(p => plots(h))
      p%last_frame = core_frame_count()
      p%just_created = created
      p%locked = .false.
      p%fit = .false.
      if (created .or. flags /= p%prev_flags) p%flags = flags
      p%prev_flags = flags
      if (created) then ! SetupAxis(ImAxis_X1), SetupAxis(ImAxis_Y1)
         call setup_axis(p, AX_X1, 0_int32)
         call setup_axis(p, AX_Y1, 0_int32)
      endif
      do i = 1_int32, AXES ! ImPlotAxis::Reset
         p%ax(i)%enabled = .false.
         p%ax(i)%fit = .false.
         p%ax(i)%fit_min = huge(1.0_real64)
         p%ax(i)%fit_max = -huge(1.0_real64)
         p%ax(i)%ortho = 0_int32
         p%ax(i)%label_off = 0_int32
         p%ax(i)%label_len = 0_int32
         p%ax(i)%scale = SCALE_LINEAR
         p%ax(i)%con_min = -huge(1.0_real64)
         p%ax(i)%con_max = huge(1.0_real64)
      enddo
      p%ax(AX_X1)%enabled = .true.
      p%ax(AX_Y1)%enabled = .true.
      p%cur_x = AX_X1
      p%cur_y = AX_Y1
      p%ax(AX_X1)%has_range = .false. ! ApplyNextPlotData: no SetNextAxisLimits
      p%ax(AX_Y1)%has_range = .false.
      n_text = 0_int32 ! ClearTextBuffer, SetTitle
      p%title_off = 0_int32
      p%title_len = 0_int32
      if (label_shown(title)) call append_text(title, p%title_off, p%title_len)
      req = [-1.0_real32, 0.0_real32]
      if (present(width)) req(1) = real(width, real32)
      if (present(height)) req(2) = real(height, real32)
      ext = req ! CalcItemSize(size, PlotDefaultSize)
      aw = 0.0_real64
      ah = 0.0_real64
      if (req(1) < 0.0_real32 .or. req(2) < 0.0_real32) call core_content_region_avail(aw, ah)
      if (req(1) == 0.0_real32) then
         ext(1) = PLOT_DEFAULT_SIZE(1)
      elseif (req(1) < 0.0_real32) then
         ext(1) = max(4.0_real32, real(aw, real32) + req(1))
      endif
      if (req(2) == 0.0_real32) then
         ext(2) = PLOT_DEFAULT_SIZE(2)
      elseif (req(2) < 0.0_real32) then
         ext(2) = max(4.0_real32, real(ah, real32) + req(2))
      endif
      if (ext(1) < PLOT_MIN_SIZE(1) .and. req(1) < 0.0_real32) ext(1) = PLOT_MIN_SIZE(1)
      if (ext(2) < PLOT_MIN_SIZE(2) .and. req(2) < 0.0_real32) ext(2) = PLOT_MIN_SIZE(2)
      call core_cursor_screen_pos(cx, cy)
      p%frame(1:2) = [real(cx, real32), real(cy, real32)]
      p%frame(3:4) = p%frame(1:2) + ext
      call core_item_size(real(p%frame(3) - p%frame(1), real64), real(p%frame(4) - p%frame(2), real64))
      if (.not. core_item_add(real(p%frame(1), real64), real(p%frame(2), real64), real(p%frame(3), real64), &
                              real(p%frame(4), real64), id)) then
         call reset_next() ! ResetCtxForNextPlot
         return
      endif
   endassociate
   cur = h
   visible = .true.
   endfunction pf_begin_plot

   subroutine pf_setup_axes(xlabel, ylabel, auto_fit, xscale, yscale)
   !< The axes X1 and Y1 (`SetupAxes`; `ip_setup_axes`): their labels ('' or '##...': none) and, with `auto_fit`, both
   !< fit the data every frame (`ImPlotAxisFlags_AutoFit`); `xscale`/`yscale`: 'linear' (default), 'log', 'symlog',
   !< 'time' (x only), as `ip_setup_axes`. Call after `pf_begin_plot`, before any item, every frame (the scales are
   !< this frame's). The flags persist: a plot keeps them on the frames this is not called.
   character(len=*), intent(in)           :: xlabel   !< X label.
   character(len=*), intent(in)           :: ylabel   !< Y label.
   logical,          intent(in), optional :: auto_fit !< Fit the data every frame.
   character(len=*), intent(in), optional :: xscale   !< Scale of x.
   character(len=*), intent(in), optional :: yscale   !< Scale of y.
   integer(int32)                         :: flags    !< ImPlotAxisFlags.

   call setup_refused('pf_setup_axes')
   flags = 0_int32
   if (present(auto_fit)) then
      if (auto_fit) flags = AXF_AUTO_FIT
   endif
   call setup_axis(plots(cur), AX_X1, flags, xlabel)
   call setup_axis(plots(cur), AX_Y1, flags, ylabel)
   if (present(xscale)) call setup_scale(plots(cur)%ax(AX_X1), xscale, .false.)
   if (present(yscale)) call setup_scale(plots(cur)%ax(AX_Y1), yscale, .true.)
   endsubroutine pf_setup_axes

   subroutine pf_setup_axis(axis, label, scale, auto_fit, opposite, invert, lock, no_grid)
   !< One axis (`SetupAxis`; `ip_setup_axis`): `'x1'`, `'x2'`, `'x3'`, `'y1'`, `'y2'`, `'y3'`; call after
   !< `pf_begin_plot`, before any item, every frame for the axes 2 and 3 (they exist on the frames they are set up).
   !< The secondary axes go on the opposite side (top, right) without grid lines unless `opposite`/`no_grid` say
   !< otherwise; `auto_fit`: the axis fits the data every frame; `invert`: values grow leftwards or downwards; `lock`:
   !< its ends stay (no fit moves them); `scale`: 'linear' (default), 'log', 'symlog', 'time' (x axes only), this
   !< frame's (`SetupAxisScale`). The flags persist: a plot keeps them on the frames this is not called.
   character(len=*), intent(in)           :: axis     !< 'x1', 'x2', 'x3', 'y1', 'y2', 'y3'.
   character(len=*), intent(in), optional :: label    !< Label (default, '' or '##...': none).
   character(len=*), intent(in), optional :: scale    !< 'linear', 'log', 'symlog', 'time'.
   logical,          intent(in), optional :: auto_fit !< Fit the data every frame.
   logical,          intent(in), optional :: opposite !< On the opposite side (default: the axes 2 and 3).
   logical,          intent(in), optional :: invert   !< Inverted.
   logical,          intent(in), optional :: lock     !< Ends locked.
   logical,          intent(in), optional :: no_grid  !< No grid lines (default: the axes 2 and 3).
   integer(int32)                         :: i        !< Axis.
   integer(int32)                         :: flags    !< ImPlotAxisFlags.

   call setup_refused('pf_setup_axis')
   i = axis_code(axis)
   flags = 0_int32
   if (i /= AX_X1 .and. i /= AX_Y1) flags = ior(AXF_OPPOSITE, AXF_NO_GRID_LINES) ! ImPlotAxisFlags_AuxDefault
   call set_flag(flags, AXF_OPPOSITE, opposite)
   call set_flag(flags, AXF_NO_GRID_LINES, no_grid)
   call set_flag(flags, AXF_AUTO_FIT, auto_fit)
   call set_flag(flags, AXF_INVERT, invert)
   call set_flag(flags, ior(AXF_LOCK_MIN, AXF_LOCK_MAX), lock)
   if (present(label)) then
      call setup_axis(plots(cur), i, flags, label)
   else
      call setup_axis(plots(cur), i, flags)
   endif
   if (present(scale)) call setup_scale(plots(cur)%ax(i), scale, i >= AX_Y1)
   endsubroutine pf_setup_axis

   subroutine pf_setup_axes_limits(xmin, xmax, ymin, ymax, always)
   !< The ranges of X1 and Y1 (`SetupAxesLimits`; `ip_setup_axes_limits`): applied until the plot has been drawn
   !< once (`ImPlotCond_Once`), or every frame with `always=.true.` (`ImPlotCond_Always`: the axes then never fit).
   !< Call after `pf_begin_plot`, before any item.
   real(real64), intent(in)           :: xmin, xmax !< X axis's range.
   real(real64), intent(in)           :: ymin, ymax !< Y axis's range.
   logical,      intent(in), optional :: always     !< Every frame.

   call pf_setup_axis_limits('x1', xmin, xmax, always)
   call pf_setup_axis_limits('y1', ymin, ymax, always)
   endsubroutine pf_setup_axes_limits

   subroutine pf_setup_axis_limits(axis, vmin, vmax, always)
   !< The range of one axis (`SetupAxisLimits`; `ip_setup_axis_limits`), set up on this frame: applied until the plot
   !< has been drawn once, or every frame with `always=.true.`. Call after `pf_begin_plot`, before any item.
   character(len=*), intent(in)           :: axis   !< 'x1', 'x2', 'x3', 'y1', 'y2', 'y3'.
   real(real64),     intent(in)           :: vmin   !< Lower end.
   real(real64),     intent(in)           :: vmax   !< Upper end.
   logical,          intent(in), optional :: always !< Every frame.
   integer(int32)                         :: i      !< Axis.
   integer(int32)                         :: cond   !< ImPlotCond.

   call setup_refused('pf_setup_axis_limits')
   i = axis_code(axis)
   cond = COND_ONCE
   if (present(always)) then
      if (always) cond = COND_ALWAYS
   endif
   associate(p => plots(cur))
      if (.not. p%ax(i)%enabled) error stop 'figure_plot_frame: pf_setup_axis_limits of an axis not set up'
      if (.not. p%initialized .or. cond == COND_ALWAYS) call set_range(p%ax(i), vmin, vmax)
      p%ax(i)%has_range = .true.
      p%ax(i)%range_cond = cond
   endassociate
   endsubroutine pf_setup_axis_limits

   subroutine pf_setup_legend(location, outside, horizontal)
   !< Where the plot's legend goes (`SetupLegend`; `ip_setup_legend`): `location` a compass point, `'n'`, `'ne'`,
   !< `'e'`, `'se'`, `'s'`, `'sw'`, `'w'`, `'nw'` (default) or `'c'`; `outside`: outside the plot area, which shrinks
   !< to make room (from the frame after the legend has entries, as ImPlot); `horizontal`: the entries in a row. Call
   !< after `pf_begin_plot`, before any item; the choice persists.
   character(len=*), intent(in), optional :: location   !< Compass point.
   logical,          intent(in), optional :: outside    !< Outside the plot area.
   logical,          intent(in), optional :: horizontal !< Entries in a row.
   integer(int32)                         :: loc        !< ImPlotLocation.
   integer(int32)                         :: flags      !< ImPlotLegendFlags.

   call setup_refused('pf_setup_legend')
   loc = LOC_NORTH + LOC_WEST
   if (present(location)) loc = location_code(trim(location))
   flags = 0_int32
   call set_flag(flags, LGF_OUTSIDE, outside)
   call set_flag(flags, LGF_HORIZONTAL, horizontal)
   associate(p => plots(cur))
      if (loc /= p%leg_prev_loc) p%leg_loc = loc
      p%leg_prev_loc = loc
      if (flags /= p%leg_prev_flags) p%leg_flags = flags
      p%leg_prev_flags = flags
   endassociate
   endsubroutine pf_setup_legend

   subroutine pf_set_next_axis_to_fit(axis)
   !< Fit one axis of the next plot begun to its data (`SetNextAxisToFit`): call before `pf_begin_plot`; the fit is
   !< applied at its `pf_end_plot` and shown from the frame after.
   character(len=*), intent(in) :: axis !< 'x1', 'x2', 'x3', 'y1', 'y2', 'y3'.

   if (cur /= 0_int32) error stop 'figure_plot_frame: pf_set_next_axis_to_fit inside a plot'
   next_fit(axis_code(axis)) = .true.
   endsubroutine pf_set_next_axis_to_fit

   subroutine pf_set_next_axes_to_fit()
   !< Fit every axis of the next plot begun to its data (`SetNextAxesToFit`): call before `pf_begin_plot`.

   if (cur /= 0_int32) error stop 'figure_plot_frame: pf_set_next_axes_to_fit inside a plot'
   next_fit = .true.
   endsubroutine pf_set_next_axes_to_fit

   subroutine pf_set_axes(x, y)
   !< The axes the next items use (`SetAxes`; `ip_set_axes`), until the next call or the plot's end (each plot starts
   !< on X1 and Y1), each set up on this frame. It ends the setup.
   character(len=*), intent(in) :: x  !< 'x1', 'x2' or 'x3'.
   character(len=*), intent(in) :: y  !< 'y1', 'y2' or 'y3'.
   integer(int32)               :: ix, iy !< Axes.

   if (cur == 0_int32) error stop 'figure_plot_frame: pf_set_axes outside a plot'
   ix = axis_code(x)
   iy = axis_code(y)
   if (ix > AX_X3 .or. iy < AX_Y1) error stop 'figure_plot_frame: pf_set_axes: an x axis and a y axis'
   associate(p => plots(cur))
      if (.not. (p%ax(ix)%enabled .and. p%ax(iy)%enabled)) error stop 'figure_plot_frame: pf_set_axes: axis not set up'
      if (.not. p%locked) call setup_finish(p)
      p%cur_x = ix
      p%cur_y = iy
   endassociate
   endsubroutine pf_set_axes

   subroutine pf_hide_next_item(hidden, always)
   !< Hide (default) or show the next item (`HideNextItem`; `ip_hide_next_item`): the first time it is drawn only,
   !< unless `always=.true.` (on this frame, whatever its legend entry's clicks did). Its legend entry stays, greyed
   !< while hidden.
   logical, intent(in), optional :: hidden !< Hidden (default) or shown.
   logical, intent(in), optional :: always !< On this frame.

   if (cur == 0_int32) error stop 'figure_plot_frame: pf_hide_next_item outside a plot'
   next_hidden_set = .true.
   next_hidden = .true.
   if (present(hidden)) next_hidden = hidden
   next_hidden_cond = COND_ONCE
   if (present(always)) then
      if (always) next_hidden_cond = COND_ALWAYS
   endif
   endsubroutine pf_hide_next_item

   function pf_legend_hovered(label) result(hovered)
   !< The legend entry of the item `label` is hovered (`IsLegendEntryHovered`; `ip_legend_hovered`): as the last
   !< legend drawn found it. It ends the setup.
   character(len=*), intent(in) :: label   !< The item's label.
   logical                      :: hovered !< Hovered.
   integer(int32)               :: id, k   !< The item's ID, counter.

   hovered = .false.
   if (cur == 0_int32) error stop 'figure_plot_frame: pf_legend_hovered outside a plot'
   associate(p => plots(cur))
      if (.not. p%locked) call setup_finish(p)
      id = plot_hash(label, plot_id_offset(p%id, -1_int32))
      do k = 1_int32, p%n_items
         if (p%item_id(k) == id) then
            hovered = p%item_hovered(k)
            exit
         endif
      enddo
   endassociate
   endfunction pf_legend_hovered

   subroutine pf_plot_limits(xmin, xmax, ymin, ymax, xaxis, yaxis)
   !< The ranges the open plot is drawn with on this frame (`GetPlotLimits`; `ip_plot_limits`): of the axes the items
   !< use now (X1 and Y1, or those of the last `pf_set_axes`), or of `xaxis` and `yaxis`. It ends the setup.
   real(real64),     intent(out)          :: xmin, xmax !< X axis's range.
   real(real64),     intent(out)          :: ymin, ymax !< Y axis's range.
   character(len=*), intent(in), optional :: xaxis      !< 'x1', 'x2', 'x3' (default: the current one).
   character(len=*), intent(in), optional :: yaxis      !< 'y1', 'y2', 'y3' (default: the current one).
   integer(int32)                         :: ix, iy     !< Axes.

   if (cur == 0_int32) error stop 'figure_plot_frame: pf_plot_limits outside a plot'
   associate(p => plots(cur))
      if (.not. p%locked) call setup_finish(p)
      ix = p%cur_x
      iy = p%cur_y
      if (present(xaxis)) ix = axis_code(xaxis)
      if (present(yaxis)) iy = axis_code(yaxis)
      xmin = p%ax(ix)%range_min
      xmax = p%ax(ix)%range_max
      ymin = p%ax(iy)%range_min
      ymax = p%ax(iy)%range_max
   endassociate
   endsubroutine pf_plot_limits

   subroutine pf_line(label, x, y, color)
   !< A line through the points (x(i), y(i)) (`PlotLine` of weight 1), clipped to the plot, on the current axes, of
   !< the colour `color` (`ip_spec(line_color=...)`), else of the colour its item was given when created: the plot's
   !< next automatic colour (ImPlot's colormap Deep: the styles `'dark'`, `'light'`, `'classic'`). The item is keyed
   !< by its label's ID; a label with text before any `##` gets a legend entry. A hidden item is neither drawn nor fit;
   !< a shown one extends the fit of its axes that fit on this frame.
   character(len=*), intent(in)           :: label    !< Legend label (the item's ID).
   real(real64),     intent(in)           :: x(:)     !< Abscissae.
   real(real64),     intent(in)           :: y(:)     !< Ordinates.
   real(real64),     intent(in), optional :: color(4) !< Colour, RGBA in [0, 1].
   integer(int32)               :: col     !< Colour.
   real(real32)                 :: weight  !< Line weight [pixels].
   real(real32)                 :: hw      !< Half the weight [pixels].
   real(real64)                 :: uv0(2), uv1(2), fringe !< The line's texture.
   real(real32)                 :: p1(2), p2(2) !< A segment's ends [pixels].
   real(real32)                 :: dx, dy, d2, inv !< Its direction.
   integer(int32)               :: k, n    !< Counter, points.
   integer(int32)               :: it      !< The item's handle.

   if (cur == 0_int32) error stop 'figure_plot_frame: pf_line outside a plot'
   associate(p => plots(cur))
      if (.not. begin_item(p, label, color, it)) return
      col = p%item_color(it)
      weight = LINE_WEIGHT
      if (p%item_hovered(it)) call highlight(p, it, weight)
      n = int(min(size(x), size(y)), int32)
      associate(ax => p%ax(p%cur_x), ay => p%ax(p%cur_y))
         if (p%fit) call fit_points(ax, ay, x, y, n) ! BeginItemEx's Fitter1
         if (n < 2_int32) return
         call core_push_clip_rect(real(p%rect(1), real64), real(p%rect(2), real64), real(p%rect(3), real64), &
                                  real(p%rect(4), real64))
         hw = max(1.0_real32, weight) * 0.5_real32 ! RendererLineStrip, GetLineRenderProps
         call core_line_texture(real(hw * 2.0_real32, real64), uv0, uv1, fringe)
         hw = hw + real(fringe, real32) * 0.5_real32
         p1 = [to_pixels(ax, x(1)), to_pixels(ay, y(1))]
         do k = 2_int32, n
            p2 = [to_pixels(ax, x(k)), to_pixels(ay, y(k))]
            if (min(p1(2), p2(2)) < p%rect(4) .and. max(p1(2), p2(2)) > p%rect(2) .and. &
                min(p1(1), p2(1)) < p%rect(3) .and. max(p1(1), p2(1)) > p%rect(1)) then ! PrimLine
               dx = p2(1) - p1(1)
               dy = p2(2) - p1(2)
               d2 = dx * dx + dy * dy
               if (d2 > 0.0_real32) then
                  inv = 1.0_real32 / sqrt(d2)
                  dx = dx * inv
                  dy = dy * inv
               endif
               dx = dx * hw
               dy = dy * hw
               call core_draw_quad_uv(real([p1(1) + dy, p2(1) + dy, p2(1) - dy, p1(1) - dy], real64),   &
                                      real([p1(2) - dx, p2(2) - dx, p2(2) + dx, p1(2) + dx], real64),   &
                                      [uv0(1), uv0(1), uv1(1), uv1(1)], [uv0(2), uv0(2), uv1(2), uv1(2)], col)
            endif
            p1 = p2
         enddo
         call core_pop_clip_rect()
      endassociate
   endassociate
   endsubroutine pf_line

   subroutine pf_end_plot()
   !< End the plot (`EndPlot`): the title, the tick marks, the legend and the border; then the fit of the axes that
   !< fit on this frame, shown from the next one.

   if (cur == 0_int32) error stop 'figure_plot_frame: pf_end_plot without a plot'
   associate(p => plots(cur))
      if (.not. p%locked) call setup_finish(p)
      call core_push_clip_rect(real(p%frame(1), real64), real(p%frame(2), real64), real(p%frame(3), real64), &
                               real(p%frame(4), real64))
      if (p%title_len > 0_int32 .and. iand(p%flags, PF_NO_TITLE) == 0_int32) &
         call text_centered(0.5_real32 * (p%rect(1) + p%rect(3)), p%canvas(2), core_style_color(ImGuiCol_Text), &
                            text(p%title_off:p%title_off + p%title_len - 1_int32))
      call tick_marks(p)
      call core_pop_clip_rect()
      call legend(p)
      if (border_shown(p)) call core_draw_rect(real(p%rect(1), real64), real(p%rect(2), real64),        &
                                               real(p%rect(3), real64), real(p%rect(4), real64), p%col_border, &
                                               rounding=0.0_real64, thickness=real(PLOT_BORDER_SIZE, real64))
      call core_draw_end()
      call fit_axes(p)
      p%initialized = .true.
   endassociate
   call reset_next() ! ResetCtxForNextPlot
   cur = 0_int32
   endsubroutine pf_end_plot

   function pf_plot_count() result(n)
   !< Plots held (tests).
   integer(int32) :: n !< Plots.
   integer(int32) :: k !< Counter.

   n = 0_int32
   do k = 1_int32, n_plots
      if (plots(k)%used) n = n + 1_int32
   enddo
   endfunction pf_plot_count

   ! private: the API's helpers

   subroutine setup_refused(name)
   !< Stop unless a plot is open and its setup not over.
   character(len=*), intent(in) :: name !< The procedure called.

   if (cur == 0_int32) error stop 'figure_plot_frame: a setup call outside a plot'
   if (plots(cur)%locked) then
      write(*, '(A)') 'figure_plot_frame: '//name//' after the setup (an item, pf_set_axes, pf_plot_limits)'
      error stop 1
   endif
   endsubroutine setup_refused

   subroutine set_flag(flags, flag, value)
   !< A flag set or cleared, if `value` is given.
   integer(int32), intent(inout)        :: flags !< Flags.
   integer(int32), intent(in)           :: flag  !< The flag's bits.
   logical,        intent(in), optional :: value !< Set (true) or cleared.

   if (.not. present(value)) return
   if (value) then
      flags = ior(flags, flag)
   else
      flags = iand(flags, not(flag))
   endif
   endsubroutine set_flag

   function axis_code(axis) result(i)
   !< The axis of a name ('x1' .. 'x3' X1 .. X3, 'y1' .. 'y3' Y1 .. Y3).
   character(len=*), intent(in) :: axis !< Name.
   integer(int32)               :: i    !< Axis.

   select case (axis)
   case ('x1')
      i = AX_X1
   case ('x2')
      i = AX_X1 + 1_int32
   case ('x3')
      i = AX_X3
   case ('y1')
      i = AX_Y1
   case ('y2')
      i = AX_Y1 + 1_int32
   case ('y3')
      i = AX_Y3
   case default
      i = 0_int32
      write(*, '(A)') "figure_plot_frame: unknown axis '"//axis//"' ('x1', 'x2', 'x3', 'y1', 'y2' or 'y3')"
      error stop 1
   endselect
   endfunction axis_code

   function location_code(location) result(loc)
   !< The ImPlotLocation of a compass point.
   character(len=*), intent(in) :: location !< 'n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw', 'c'.
   integer(int32)               :: loc      !< ImPlotLocation.

   select case (location)
   case ('n')
      loc = LOC_NORTH
   case ('ne')
      loc = LOC_NORTH + LOC_EAST
   case ('e')
      loc = LOC_EAST
   case ('se')
      loc = LOC_SOUTH + LOC_EAST
   case ('s')
      loc = LOC_SOUTH
   case ('sw')
      loc = LOC_SOUTH + LOC_WEST
   case ('w')
      loc = LOC_WEST
   case ('nw')
      loc = LOC_NORTH + LOC_WEST
   case ('c')
      loc = 0_int32
   case default
      loc = 0_int32
      error stop "figure_plot_frame: a legend location is 'n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw' or 'c'"
   endselect
   endfunction location_code

   pure function label_shown(label) result(yes)
   !< A label has text to show (`FindRenderedTextEnd(label) != label`: not empty, not starting with '##').
   character(len=*), intent(in) :: label !< Label.
   logical                      :: yes   !< Shown.

   yes = rendered_len(label) > 0
   endfunction label_shown

   pure function rendered_len(label) result(n)
   !< The length of a label's shown part (`FindRenderedTextEnd`: up to its first `##`).
   character(len=*), intent(in) :: label !< Label.
   integer(int32)               :: n     !< Characters shown.

   n = int(index(label, '##'), int32) - 1_int32
   if (n < 0_int32) n = len(label, kind=int32)
   endfunction rendered_len

   subroutine append_text(s, off, n)
   !< A text appended to the open plot's text (`TextBuffer`): where it starts and its length.
   character(len=*), intent(in)  :: s   !< Text.
   integer(int32),   intent(out) :: off !< Its start.
   integer(int32),   intent(out) :: n   !< Its length.
   character(len=:), allocatable :: more !< Grown text.

   n = len(s, kind=int32)
   if (.not. allocated(text)) allocate(character(len=max(256_int32, n)) :: text)
   if (n_text + n > len(text, kind=int32)) then
      allocate(character(len=max(2_int32 * len(text, kind=int32), n_text + n)) :: more)
      more(1:n_text) = text(1:n_text)
      call move_alloc(more, text)
   endif
   off = n_text + 1_int32
   text(off:off + n - 1_int32) = s
   n_text = n_text + n
   endsubroutine append_text

   subroutine reset_next()
   !< `ResetCtxForNextPlot`: the next plot's and the next item's data cleared.

   next_fit = .false.
   next_hidden_set = .false.
   endsubroutine reset_next

   ! private: the items

   function begin_item(p, label, color, it) result(shown)
   !< `BeginItem`: the setup finished, the item registered (`RegisterOrGetItem`: its legend entry the first time it is
   !< drawn on this frame, if its label has text), its colour (given, or the next automatic one when it is created),
   !< its visibility (`pf_hide_next_item`); shown, or not (then nothing else is done).
   type(plot_record), intent(inout)        :: p        !< Plot.
   character(len=*),  intent(in)           :: label    !< Label.
   real(real64),      intent(in), optional :: color(4) !< Colour given.
   integer(int32),    intent(out)          :: it       !< The item's handle.
   logical                                 :: shown    !< Shown.
   logical                                 :: created  !< The item is new.
   logical                                 :: seen     !< Drawn already on this frame.

   if (.not. p%locked) call setup_finish(p)
   it = item_handle(p, plot_hash(label, plot_id_offset(p%id, -1_int32)), core_frame_count(), created, seen)
   if (.not. seen) then
      if (label_shown(label)) then
         call legend_append(p, it, label)
      else
         p%item_show(it) = .true.
      endif
   endif
   if (present(color)) then
      p%item_color(it) = core_color(color(1), color(2), color(3), color(4))
   elseif (created) then
      p%item_color(it) = rgb_u32(DEEP(:, modulo(p%colormap_idx, 10_int32) + 1_int32)) ! NextColormapColorU32
      p%colormap_idx = p%colormap_idx + 1_int32
   endif
   if (next_hidden_set) then
      if (created .or. next_hidden_cond == COND_ALWAYS) p%item_show(it) = .not. next_hidden
   endif
   next_hidden_set = .false. ! NextItemData.Reset (in BeginItem when hidden, in EndItem when drawn)
   shown = p%item_show(it)
   endfunction begin_item

   subroutine highlight(p, it, weight)
   !< `BeginItem`'s highlight of an item whose legend entry is hovered: its line twice as thick, its axes highlighted
   !< in its colour where more than one axis of their direction is in use.
   type(plot_record), intent(inout) :: p      !< Plot.
   integer(int32),    intent(in)    :: it     !< Item.
   real(real32),      intent(inout) :: weight !< Line weight [pixels].
   integer(int32)                   :: i, nx, ny !< Counter, axes in use.

   if (iand(p%leg_flags, LGF_NO_HIGHLIGHT_ITEM) == 0_int32) weight = weight * HIGHLIGHT_LINE_SCALE
   if (iand(p%leg_flags, LGF_NO_HIGHLIGHT_AXIS) == 0_int32) then
      nx = 0_int32
      ny = 0_int32
      do i = 1_int32, AXES
         if (.not. p%ax(i)%enabled) cycle
         if (i <= AX_X3) then
            nx = nx + 1_int32
         else
            ny = ny + 1_int32
         endif
      enddo
      if (nx > 1_int32) p%ax(p%cur_x)%hili = p%item_color(it)
      if (ny > 1_int32) p%ax(p%cur_y)%hili = p%item_color(it)
   endif
   endsubroutine highlight

   subroutine legend_append(p, it, label)
   !< An entry appended to the plot's legend (`Legend.Indices`, `Legend.Labels`).
   type(plot_record), intent(inout) :: p     !< Plot.
   integer(int32),    intent(in)    :: it    !< Item.
   character(len=*),  intent(in)    :: label !< Its label.
   integer(int32),    allocatable   :: item(:), off(:), ln(:) !< Grown columns.
   character(len=:),  allocatable   :: more  !< Grown text.
   integer(int32)                   :: n, m  !< Entries, characters.

   n = p%n_leg
   if (.not. allocated(p%leg_item)) then
      allocate(p%leg_item(8), p%leg_off(8), p%leg_len(8))
   elseif (n == size(p%leg_item, kind=int32)) then
      allocate(item(2_int32 * n), off(2_int32 * n), ln(2_int32 * n))
      item(1:n) = p%leg_item(1:n)
      off(1:n) = p%leg_off(1:n)
      ln(1:n) = p%leg_len(1:n)
      call move_alloc(item, p%leg_item)
      call move_alloc(off, p%leg_off)
      call move_alloc(ln, p%leg_len)
   endif
   m = len(label, kind=int32)
   if (.not. allocated(p%leg_text)) allocate(character(len=max(256_int32, m)) :: p%leg_text)
   if (p%leg_n + m > len(p%leg_text, kind=int32)) then
      allocate(character(len=max(2_int32 * len(p%leg_text, kind=int32), p%leg_n + m)) :: more)
      more(1:p%leg_n) = p%leg_text(1:p%leg_n)
      call move_alloc(more, p%leg_text)
   endif
   n = n + 1_int32
   p%n_leg = n
   p%leg_item(n) = it
   p%leg_off(n) = p%leg_n + 1_int32
   p%leg_len(n) = m
   p%leg_text(p%leg_n + 1_int32:p%leg_n + m) = label
   p%leg_n = p%leg_n + m
   endsubroutine legend_append

   ! private: the tables

   function plot_handle(id, frame, created) result(h)
   !< The plot of an ID, added if new (`Plots.GetOrAddByKey`): in a free slot, the table grown (doubled up to
   !< PLOT_CAP), or in the slot of the least recently begun plot not begun on this frame.
   integer(int32), intent(in)  :: id      !< ID.
   integer(int32), intent(in)  :: frame   !< This frame.
   logical,        intent(out) :: created !< The plot is new.
   integer(int32)              :: h       !< Handle.
   integer(int32)              :: k       !< Counter.

   created = .false.
   do k = 1_int32, n_plots
      if (plots(k)%used .and. plots(k)%id == id) then
         h = k
         return
      endif
   enddo
   created = .true.
   h = 0_int32
   do k = 1_int32, n_plots
      if (.not. plots(k)%used) then
         h = k
         exit
      endif
   enddo
   if (h == 0_int32) then
      if (.not. allocated(plots)) allocate(plots(8))
      if (n_plots == size(plots, kind=int32) .and. n_plots >= PLOT_CAP) then ! the least recently begun makes room
         do k = 1_int32, n_plots
            if (plots(k)%last_frame >= frame) cycle
            if (h == 0_int32) then
               h = k
            elseif (plots(k)%last_frame < plots(h)%last_frame) then
               h = k
            endif
         enddo
      endif
      if (h == 0_int32) then
         if (n_plots == size(plots, kind=int32)) call grow_plots(max(2_int32 * n_plots, 8_int32))
         n_plots = n_plots + 1_int32
         h = n_plots
      endif
   endif
   call reset_plot(plots(h), id)
   endfunction plot_handle

   subroutine grow_plots(m)
   !< Room for m plots in the table, those held kept (element by element: ADR 0001).
   integer(int32), intent(in)     :: m       !< Plots room.
   type(plot_record), allocatable :: more(:) !< New table.
   integer(int32)                 :: k       !< Counter.

   allocate(more(m))
   do k = 1_int32, n_plots
      more(k) = plots(k)
   enddo
   call move_alloc(more, plots)
   endsubroutine grow_plots

   subroutine reset_plot(p, id)
   !< A slot made a new plot of the ID (field by field: the item and legend tables kept allocated).
   type(plot_record), intent(inout) :: p  !< Plot.
   integer(int32),    intent(in)    :: id !< ID.
   integer(int32)                   :: i  !< Axis.

   p%id = id
   p%used = .true.
   p%last_frame = -1_int32
   p%just_created = .true.
   p%initialized = .false.
   p%locked = .false.
   p%fit = .false.
   p%flags = 0_int32
   p%prev_flags = 0_int32
   p%colormap_idx = 0_int32
   p%n_items = 0_int32
   p%item_next = 1_int32
   p%leg_flags = 0_int32
   p%leg_prev_flags = 0_int32
   p%leg_loc = LOC_NORTH + LOC_WEST
   p%leg_prev_loc = LOC_NORTH + LOC_WEST
   p%leg_hovered = .false.
   p%n_leg = 0_int32
   p%leg_n = 0_int32
   do i = 1_int32, AXES
      p%ax(i)%flags = 0_int32
      p%ax(i)%prev_flags = 0_int32
      p%ax(i)%enabled = .false.
      p%ax(i)%has_range = .false.
      p%ax(i)%range_cond = 0_int32
      p%ax(i)%range_min = 0.0_real64
      p%ax(i)%range_max = 1.0_real64
      p%ax(i)%fit = .false.
      p%ax(i)%fit_min = huge(1.0_real64)
      p%ax(i)%fit_max = -huge(1.0_real64)
      p%ax(i)%pixel_min = 0.0_real32
      p%ax(i)%pixel_max = 0.0_real32
      p%ax(i)%scale_to_pixel = 0.0_real64
      p%ax(i)%datum1 = 0.0_real32
      p%ax(i)%datum2 = 0.0_real32
      p%ax(i)%hili = 0_int32
      p%ax(i)%ortho = 0_int32
      p%ax(i)%label_off = 0_int32
      p%ax(i)%label_len = 0_int32
      p%ax(i)%scale = SCALE_LINEAR
      p%ax(i)%scale_min = 0.0_real64
      p%ax(i)%scale_max = 1.0_real64
      p%ax(i)%con_min = -huge(1.0_real64)
      p%ax(i)%con_max = huge(1.0_real64)
   enddo
   endsubroutine reset_plot

   function item_handle(p, id, frame, created, seen) result(h)
   !< The item of an ID in a plot, added if new (`RegisterOrGetItem`): searched from where the last one was found
   !< (items come in the same order every frame), added in a new slot (the table grown, doubled up to ITEM_CAP) or in
   !< the slot of the least recently drawn item not drawn on this frame. `seen`: drawn already on this frame.
   type(plot_record), intent(inout) :: p       !< Plot.
   integer(int32),    intent(in)    :: id      !< ID.
   integer(int32),    intent(in)    :: frame   !< This frame.
   logical,           intent(out)   :: created !< The item is new.
   logical,           intent(out)   :: seen    !< Drawn already on this frame (SeenThisFrame).
   integer(int32)                   :: h       !< Handle.
   integer(int32)                   :: j, k, n !< Counters, items.

   created = .false.
   seen = .false.
   n = p%n_items
   k = p%item_next
   do j = 1_int32, n
      if (k > n) k = 1_int32
      if (p%item_id(k) == id) then
         h = k
         seen = p%item_frame(h) == frame
         p%item_frame(h) = frame
         p%item_next = h + 1_int32
         return
      endif
      k = k + 1_int32
   enddo
   created = .true.
   h = 0_int32
   if (.not. allocated(p%item_id)) call grow_items(p, 8_int32)
   if (n == size(p%item_id, kind=int32) .and. n >= ITEM_CAP) then ! the least recently drawn makes room
      do k = 1_int32, n
         if (p%item_frame(k) >= frame) cycle
         if (h == 0_int32) then
            h = k
         elseif (p%item_frame(k) < p%item_frame(h)) then
            h = k
         endif
      enddo
   endif
   if (h == 0_int32) then
      if (n == size(p%item_id, kind=int32)) call grow_items(p, 2_int32 * n)
      p%n_items = n + 1_int32
      h = p%n_items
   endif
   p%item_id(h) = id
   p%item_color(h) = -1_int32 ! IM_COL32_WHITE
   p%item_frame(h) = frame
   p%item_show(h) = .true.
   p%item_hovered(h) = .false.
   p%item_next = h + 1_int32
   endfunction item_handle

   subroutine grow_items(p, m)
   !< Room for m items in a plot's table, those held kept.
   type(plot_record), intent(inout) :: p                       !< Plot.
   integer(int32),    intent(in)    :: m                       !< Items room.
   integer(int32),    allocatable   :: id(:), color(:), frame(:) !< New columns.
   logical,           allocatable   :: show(:), hovered(:)     !< ...
   integer(int32)                   :: n                       !< Items held.

   n = p%n_items
   allocate(id(m), color(m), frame(m), show(m), hovered(m))
   if (n > 0_int32) then
      id(1:n) = p%item_id(1:n)
      color(1:n) = p%item_color(1:n)
      frame(1:n) = p%item_frame(1:n)
      show(1:n) = p%item_show(1:n)
      hovered(1:n) = p%item_hovered(1:n)
   endif
   call move_alloc(id, p%item_id)
   call move_alloc(color, p%item_color)
   call move_alloc(frame, p%item_frame)
   call move_alloc(show, p%item_show)
   call move_alloc(hovered, p%item_hovered)
   endsubroutine grow_items

   ! private: the axes

   subroutine setup_scale(ax, scale, vertical)
   !< `SetupAxisScale`: the scale of an axis on this frame and its constraint (log10: from DBL_MIN; time: 0 to
   !< IMPLOT_MAX_TIME, two label levels).
   type(plot_axis),  intent(inout) :: ax       !< Axis.
   character(len=*), intent(in)    :: scale    !< 'linear', 'log', 'symlog', 'time'.
   logical,          intent(in)    :: vertical !< A y axis.

   select case (trim(scale))
   case ('linear')
      ax%scale = SCALE_LINEAR
      ax%con_min = -huge(1.0_real64)
      ax%con_max = huge(1.0_real64)
   case ('log')
      ax%scale = SCALE_LOG10
      ax%con_min = tiny(1.0_real64)
      ax%con_max = huge(1.0_real64)
   case ('symlog')
      ax%scale = SCALE_SYMLOG
      ax%con_min = -huge(1.0_real64)
      ax%con_max = huge(1.0_real64)
   case ('time')
      if (vertical) error stop "figure_plot_frame: scale 'time' on a y axis (ImPlot labels time on x axes only)"
      ax%scale = SCALE_TIME
      ax%con_min = TIME_MIN
      ax%con_max = TIME_MAX
   case default
      error stop "figure_plot_frame: a scale is 'linear', 'log', 'symlog' or 'time'"
   endselect
   endsubroutine setup_scale

   subroutine measure_text(s, w, h)
   !< A text's size in the current font (`CalcTextSize`), for the locators.
   character(len=*), intent(in)  :: s    !< Text.
   real(real32),     intent(out) :: w, h !< Size [pixels].
   real(real64)                  :: cw, ch !< C values.

   call core_text_size(s, cw, ch)
   w = real(cw, real32)
   h = real(ch, real32)
   endsubroutine measure_text

   pure function forward(ax, v) result(s)
   !< The axis's forward transform (`TransformForward`): log10 or symlog; the value itself otherwise.
   type(plot_axis), intent(in) :: ax !< Axis.
   real(real64),    intent(in) :: v  !< Value.
   real(real64)                :: s  !< Transformed.

   select case (ax%scale)
   case (SCALE_LOG10)
      s = transform_log10(v)
   case (SCALE_SYMLOG)
      s = transform_symlog(v)
   case default
      s = v
   endselect
   endfunction forward

   subroutine setup_axis(p, i, flags, label)
   !< `SetupAxis`: the axis enabled on this frame, its flags taken if the plot is new or they changed, its label (none:
   !< absent, empty or starting with '##').
   type(plot_record), intent(inout)        :: p     !< Plot.
   integer(int32),    intent(in)           :: i     !< Axis.
   integer(int32),    intent(in)           :: flags !< ImPlotAxisFlags.
   character(len=*),  intent(in), optional :: label !< Label.

   if (p%just_created .or. flags /= p%ax(i)%prev_flags) p%ax(i)%flags = flags
   p%ax(i)%prev_flags = flags
   p%ax(i)%enabled = .true.
   p%ax(i)%label_off = 0_int32
   p%ax(i)%label_len = 0_int32
   if (present(label)) then
      if (label_shown(label)) call append_text(label, p%ax(i)%label_off, p%ax(i)%label_len)
   endif
   endsubroutine setup_axis

   subroutine set_range(ax, v1, v2)
   !< `ImPlotAxis::SetRange`: the range from two ends in any order, constrained.
   type(plot_axis), intent(inout) :: ax     !< Axis.
   real(real64),    intent(in)    :: v1, v2 !< Ends.

   ax%range_min = merge(v1, v2, v1 < v2)  ! ImMin
   ax%range_max = merge(v1, v2, v1 >= v2) ! ImMax
   call constrain(ax)
   call update_scale(ax)
   endsubroutine set_range

   subroutine constrain(ax)
   !< `ImPlotAxis::Constrain`: NaN ends made 0, infinite ones the largest finite value, the ends within the scale's
   !< constraint (`ConstraintRange`), a size of at least DBL_MIN (`ConstraintZoom`), an empty range given DBL_EPSILON.
   type(plot_axis), intent(inout) :: ax       !< Axis.
   real(real64)                   :: z, delta !< Size, half the growth.

   ax%range_min = constrain_nan(constrain_inf(ax%range_min))
   ax%range_max = constrain_nan(constrain_inf(ax%range_max))
   if (ax%range_min < ax%con_min) ax%range_min = ax%con_min
   if (ax%range_max > ax%con_max) ax%range_max = ax%con_max
   z = ax%range_max - ax%range_min
   if (z < tiny(1.0_real64)) then
      delta = (tiny(1.0_real64) - z) * 0.5_real64
      ax%range_min = ax%range_min - delta
      ax%range_max = ax%range_max + delta
   endif
   if (ax%range_max <= ax%range_min) ax%range_max = ax%range_min + epsilon(1.0_real64)
   endsubroutine constrain

   subroutine update_scale(ax)
   !< `ImPlotAxis::UpdateTransformCache`: pixels per unit, the range's ends transformed.
   type(plot_axis), intent(inout) :: ax !< Axis.

   ax%scale_to_pixel = real(ax%pixel_max - ax%pixel_min, real64) / (ax%range_max - ax%range_min)
   ax%scale_min = forward(ax, ax%range_min)
   ax%scale_max = forward(ax, ax%range_max)
   endsubroutine update_scale

   subroutine fit_points(xa, ya, x, y, n)
   !< `Fitter1` with `ExtendFitWith`: the points' finite coordinates within the axes' constraints (a log axis's
   !< positive ones) extend the axes' fit ranges (with `ImPlotAxisFlags_RangeFit`, only those whose other coordinate is
   !< in the other axis's range).
   type(plot_axis), intent(inout) :: xa   !< X axis.
   type(plot_axis), intent(inout) :: ya   !< Y axis.
   real(real64),    intent(in)    :: x(:) !< Abscissae.
   real(real64),    intent(in)    :: y(:) !< Ordinates.
   integer(int32),  intent(in)    :: n    !< Points.
   logical                        :: rx, ry !< RangeFit on x, on y.
   integer(int32)                 :: k    !< Counter.

   rx = iand(xa%flags, AXF_RANGE_FIT) == AXF_RANGE_FIT
   ry = iand(ya%flags, AXF_RANGE_FIT) == AXF_RANGE_FIT
   do k = 1_int32, n
      if (abs(x(k)) <= huge(1.0_real64) .and. x(k) >= xa%con_min .and. x(k) <= xa%con_max) then
         if (.not. rx .or. (y(k) >= ya%range_min .and. y(k) <= ya%range_max)) then
            if (x(k) < xa%fit_min) xa%fit_min = x(k)
            if (x(k) > xa%fit_max) xa%fit_max = x(k)
         endif
      endif
      if (abs(y(k)) <= huge(1.0_real64) .and. y(k) >= ya%con_min .and. y(k) <= ya%con_max) then
         if (.not. ry .or. (x(k) >= xa%range_min .and. x(k) <= xa%range_max)) then
            if (y(k) < ya%fit_min) ya%fit_min = y(k)
            if (y(k) > ya%fit_max) ya%fit_max = y(k)
         endif
      endif
   enddo
   endsubroutine fit_points

   subroutine apply_fit(ax, padding)
   !< `ImPlotAxis::ApplyFit`: the range made the data's, padded, its unlocked ends only; a degenerate range widened
   !< to +-0.5.
   type(plot_axis), intent(inout) :: ax       !< Axis.
   real(real32),    intent(in)    :: padding  !< FitPadding (fraction of the range).
   real(real64)                   :: ext_size !< Half the data's extent.

   ext_size = (ax%fit_max - ax%fit_min) * 0.5_real64
   ax%fit_min = ax%fit_min - ext_size * real(padding, real64)
   ax%fit_max = ax%fit_max + ext_size * real(padding, real64)
   if (.not. locked_min(ax) .and. abs(ax%fit_min) <= huge(1.0_real64)) ax%range_min = ax%fit_min
   if (.not. locked_max(ax) .and. abs(ax%fit_max) <= huge(1.0_real64)) ax%range_max = ax%fit_max
   if (almost_equal(ax%range_min, ax%range_max)) then
      ax%range_max = ax%range_max + 0.5_real64
      ax%range_min = ax%range_min - 0.5_real64
   endif
   call constrain(ax)
   call update_scale(ax)
   endsubroutine apply_fit

   function get_aspect(ax) result(a)
   !< `ImPlotAxis::GetAspect`: units per pixel.
   type(plot_axis), intent(in) :: ax !< Axis.
   real(real64)                :: a  !< Units per pixel.

   a = (ax%range_max - ax%range_min) / real(abs(ax%pixel_max - ax%pixel_min), real64)
   endfunction get_aspect

   subroutine set_aspect(ax, unit_per_pix)
   !< `ImPlotAxis::SetAspect`: the range resized to `unit_per_pix` units per pixel about its centre, or from its locked
   !< end.
   type(plot_axis), intent(inout) :: ax            !< Axis.
   real(real64),    intent(in)    :: unit_per_pix  !< Units per pixel.
   real(real64)                   :: new_size, delta !< The range's new size, half the change.

   new_size = unit_per_pix * real(abs(ax%pixel_max - ax%pixel_min), real64)
   delta = (new_size - (ax%range_max - ax%range_min)) * 0.5_real64
   if (locked_min(ax) .and. locked_max(ax)) then
      return
   elseif (locked_min(ax) .and. .not. locked_max(ax)) then
      call set_range(ax, ax%range_min, ax%range_max + 2.0_real64 * delta)
   elseif (.not. locked_min(ax) .and. locked_max(ax)) then
      call set_range(ax, ax%range_min - 2.0_real64 * delta, ax%range_max)
   else
      call set_range(ax, ax%range_min - delta, ax%range_max + delta)
   endif
   endsubroutine set_aspect

   pure function locked_min(ax) result(yes)
   !< `IsLockedMin`: the minimum is not moved by a fit (disabled axis, limits `always`, `ImPlotAxisFlags_LockMin`).
   type(plot_axis), intent(in) :: ax  !< Axis.
   logical                     :: yes !< Locked.

   yes = .not. ax%enabled .or. (ax%has_range .and. ax%range_cond == COND_ALWAYS) .or. &
         iand(ax%flags, AXF_LOCK_MIN) == AXF_LOCK_MIN
   endfunction locked_min

   pure function locked_max(ax) result(yes)
   !< `IsLockedMax`: the maximum is not moved by a fit.
   type(plot_axis), intent(in) :: ax  !< Axis.
   logical                     :: yes !< Locked.

   yes = .not. ax%enabled .or. (ax%has_range .and. ax%range_cond == COND_ALWAYS) .or. &
         iand(ax%flags, AXF_LOCK_MAX) == AXF_LOCK_MAX
   endfunction locked_max

   pure function auto_fitting(ax) result(yes)
   !< `IsAutoFitting`.
   type(plot_axis), intent(in) :: ax  !< Axis.
   logical                     :: yes !< ImPlotAxisFlags_AutoFit.

   yes = iand(ax%flags, AXF_AUTO_FIT) == AXF_AUTO_FIT
   endfunction auto_fitting

   pure function almost_equal(v1, v2) result(yes)
   !< `ImAlmostEqual(v1, v2, 2)`: within 2 ulp of their sum, or closer than DBL_MIN.
   real(real64), intent(in) :: v1, v2 !< Values.
   logical                  :: yes    !< Almost equal.

   yes = abs(v1 - v2) < epsilon(1.0_real64) * abs(v1 + v2) * 2.0_real64 .or. abs(v1 - v2) < tiny(1.0_real64)
   endfunction almost_equal

   pure function constrain_nan(v) result(c)
   !< `ImConstrainNan`: NaN made 0.
   real(real64), intent(in) :: v !< Value.
   real(real64)             :: c !< Constrained.

   c = v
   if (v /= v) c = 0.0_real64
   endfunction constrain_nan

   pure function constrain_inf(v) result(c)
   !< `ImConstrainInf`: beyond the largest finite value made it.
   real(real64), intent(in) :: v !< Value.
   real(real64)             :: c !< Constrained.

   c = v
   if (v >= huge(1.0_real64)) then
      c = huge(1.0_real64)
   elseif (v <= -huge(1.0_real64)) then
      c = -huge(1.0_real64)
   endif
   endfunction constrain_inf

   subroutine fit_axes(p)
   !< `EndPlot`'s fit: the axes that fit on this frame and saw data (FIGURE's `fig_plot_end` drops the others), x axes
   !< then y axes; with `ImPlotFlags_Equal` an axis and its pair then share the larger units per pixel.
   type(plot_record), intent(inout) :: p      !< Plot.
   real(real64)                     :: aspect !< Units per pixel.
   integer(int32)                   :: i, o   !< Axis, its pair.
   logical                          :: equal  !< ImPlotFlags_Equal.

   if (.not. p%fit) return
   do i = 1_int32, AXES
      if (p%ax(i)%fit .and. p%ax(i)%fit_min > p%ax(i)%fit_max) p%ax(i)%fit = .false.
   enddo
   equal = iand(p%flags, PF_EQUAL) == PF_EQUAL
   do i = AX_X1, AX_X3
      if (.not. p%ax(i)%fit) cycle
      call apply_fit(p%ax(i), FIT_PADDING(1))
      o = p%ax(i)%ortho
      if (equal .and. o /= 0_int32) then
         aspect = get_aspect(p%ax(i))
         if (p%ax(o)%fit) then
            call apply_fit(p%ax(o), FIT_PADDING(2))
            p%ax(o)%fit = .false.
            aspect = merge(aspect, get_aspect(p%ax(o)), aspect >= get_aspect(p%ax(o)))
         endif
         call set_aspect(p%ax(i), aspect)
         call set_aspect(p%ax(o), aspect)
      endif
   enddo
   do i = AX_Y1, AX_Y3
      if (.not. p%ax(i)%fit) cycle
      call apply_fit(p%ax(i), FIT_PADDING(2))
      o = p%ax(i)%ortho
      if (equal .and. o /= 0_int32) then
         aspect = get_aspect(p%ax(i))
         if (p%ax(o)%fit) then
            call apply_fit(p%ax(o), FIT_PADDING(1))
            p%ax(o)%fit = .false.
            aspect = merge(get_aspect(p%ax(o)), aspect, get_aspect(p%ax(o)) >= aspect)
         endif
         call set_aspect(p%ax(o), aspect)
         call set_aspect(p%ax(i), aspect)
      endif
   enddo
   p%fit = .false.
   endsubroutine fit_axes

   pure function has_flag(flags, flag) result(yes)
   !< `ImHasFlag`: all the flag's bits set.
   integer(int32), intent(in) :: flags !< Flags.
   integer(int32), intent(in) :: flag  !< The flag's bits.
   logical                    :: yes   !< Set.

   yes = iand(flags, flag) == flag
   endfunction has_flag

   pure function will_render(ax) result(yes)
   !< `ImPlotAxis::WillRender`: enabled, with grid lines, tick labels or tick marks.
   type(plot_axis), intent(in) :: ax  !< Axis.
   logical                     :: yes !< Drawn.

   yes = ax%enabled .and. (.not. has_flag(ax%flags, AXF_NO_GRID_LINES) .or.  &
                           .not. has_flag(ax%flags, AXF_NO_TICK_LABELS) .or. &
                           .not. has_flag(ax%flags, AXF_NO_TICK_MARKS))
   endfunction will_render

   ! private: the drawing

   subroutine setup_finish(p)
   !< `SetupFinish`: the axes' initial fit decided, their pairs, the layout (an outside legend, the title, the axes'
   !< ticks and paddings, the plot rectangle), the axes on screen (and made equal), the fits asked for, then the frame,
   !< the plot's background, the grid, the axes' highlights, labels and tick labels; the legend emptied for the items.
   type(plot_record), intent(inout) :: p          !< Plot.
   real(real32)   :: pad_top, pad_bot     !< Paddings above and below the plot [pixels].
   real(real32)   :: pad_left, pad_right  !< ... left and right of it.
   real(real32)   :: plot_height, plot_width !< The plot's size.
   real(real32)   :: title_w, title_h     !< The title's size.
   real(real32)   :: title_pad            !< Its room.
   real(real32)   :: lsize(2)             !< An outside legend's size.
   real(real32)   :: rounding, border     !< FrameRounding, FrameBorderSize.
   real(real64)   :: v(2)                 !< A style variable.
   real(real64)   :: w, h                 !< A text's size.
   real(real64)   :: xar, yar             !< Units per pixel on x, y.
   integer(int32) :: nv                   !< Its values.
   integer(int32) :: i, j                 !< Axes.
   logical        :: equal, horz          !< ImPlotFlags_Equal, a horizontal legend.
   logical        :: west, east, north, south !< The legend's side.

   p%locked = .true.
   do i = 1_int32, AXES ! finalize the axes: an axis with no limits fits on the plot's first frame (CanInitFit)
      if (.not. p%ax(i)%enabled) cycle
      call constrain(p%ax(i))
      if (.not. p%initialized .and. .not. has_flag(p%ax(i)%flags, AXF_NO_INITIAL_FIT) .and. &
          .not. p%ax(i)%has_range) then
         p%fit = .true.
         p%ax(i)%fit = .true.
      endif
   enddo
   equal = has_flag(p%flags, PF_EQUAL)
   do i = AX_X1, AX_X3 ! the pairs (OrthoAxis): an x and a y axis of the same rank, or the first of the other
      j = i + AX_Y1 - AX_X1
      if (p%ax(i)%enabled .and. p%ax(j)%enabled) then
         p%ax(i)%ortho = j
         p%ax(j)%ortho = i
      elseif (p%ax(i)%enabled .and. .not. equal) then
         p%ax(i)%ortho = AX_Y1
      elseif (p%ax(j)%enabled .and. .not. equal) then
         p%ax(j)%ortho = AX_X1
      endif
   enddo
   p%col_maj = core_style_color(ImGuiCol_Text, 0.25_real64)                 ! AxisGrid: Text * (1, 1, 1, 0.25)
   p%col_min = core_style_color(ImGuiCol_Text, real(0.25_real32 * MINOR_ALPHA, real64))
   p%col_tick = p%col_maj                                                   ! AxisTick: AxisGrid
   p%col_txt = core_style_color(ImGuiCol_Text)                              ! AxisText: Text
   p%col_border = core_style_color(ImGuiCol_Border)                         ! PlotBorder: Border
   do i = 1_int32, AXES
      call ticks_reset(ticks(i))
      if (p%ax(i)%scale == SCALE_TIME) ticks(i)%levels = 2_int32 ! SetupAxisScale: Ticker.Levels = 2
   enddo
   p%canvas(1:2) = p%frame(1:2) + PLOT_PADDING
   p%canvas(3:4) = p%frame(3:4) - PLOT_PADDING
   p%axes_rect = p%frame
   ! an outside legend's room, from the legend of the frame before
   if (.not. has_flag(p%flags, PF_NO_LEGEND) .and. p%n_leg > 0_int32 .and. has_flag(p%leg_flags, LGF_OUTSIDE)) then
      horz = has_flag(p%leg_flags, LGF_HORIZONTAL)
      lsize = legend_size(p, .not. horz)
      west = has_flag(p%leg_loc, LOC_WEST) .and. .not. has_flag(p%leg_loc, LOC_EAST)
      east = has_flag(p%leg_loc, LOC_EAST) .and. .not. has_flag(p%leg_loc, LOC_WEST)
      north = has_flag(p%leg_loc, LOC_NORTH) .and. .not. has_flag(p%leg_loc, LOC_SOUTH)
      south = has_flag(p%leg_loc, LOC_SOUTH) .and. .not. has_flag(p%leg_loc, LOC_NORTH)
      if ((west .and. .not. horz) .or. (west .and. horz .and. .not. north .and. .not. south)) then
         p%canvas(1) = p%canvas(1) + (lsize(1) + LEGEND_PADDING(1))
         p%axes_rect(1) = p%axes_rect(1) + (lsize(1) + PLOT_PADDING(1))
      endif
      if ((east .and. .not. horz) .or. (east .and. horz .and. .not. north .and. .not. south)) then
         p%canvas(3) = p%canvas(3) - (lsize(1) + LEGEND_PADDING(1))
         p%axes_rect(3) = p%axes_rect(3) - (lsize(1) + PLOT_PADDING(1))
      endif
      if ((north .and. horz) .or. (north .and. .not. horz .and. .not. west .and. .not. east)) then
         p%canvas(2) = p%canvas(2) + (lsize(2) + LEGEND_PADDING(2))
         p%axes_rect(2) = p%axes_rect(2) + (lsize(2) + PLOT_PADDING(2))
      endif
      if ((south .and. horz) .or. (south .and. .not. horz .and. .not. west .and. .not. east)) then
         p%canvas(4) = p%canvas(4) - (lsize(2) + LEGEND_PADDING(2))
         p%axes_rect(4) = p%axes_rect(4) - (lsize(2) + PLOT_PADDING(2))
      endif
   endif
   ! (0) the title's room
   pad_top = 0.0_real32
   pad_bot = 0.0_real32
   pad_left = 0.0_real32
   pad_right = 0.0_real32
   title_w = 0.0_real32
   title_h = 0.0_real32
   if (p%title_len > 0_int32 .and. .not. has_flag(p%flags, PF_NO_TITLE)) then
      call core_text_size(text(p%title_off:p%title_off + p%title_len - 1_int32), w, h, hide_after_hash=.true.)
      title_w = real(w, real32)
      title_h = real(h, real32)
   endif
   if (title_w > 0.0_real32) then
      pad_top = pad_top + (title_h + LABEL_PADDING(2))
      p%axes_rect(2) = p%axes_rect(2) + (PLOT_PADDING(2) + pad_top)
   endif
   ! (1) the x axes, their tick labels' height not known yet; (2) the y ticks; (3) the y axes
   call pad_and_datum_x(p, pad_top, pad_bot)
   plot_height = ((p%canvas(4) - p%canvas(2)) - pad_top) - pad_bot
   do i = AX_Y1, AX_Y3
      if (will_render(p%ax(i)) .and. plot_height > 0.0_real32) &
         call locate(p%ax(i), ticks(i), plot_height, .true.)
   enddo
   call pad_and_datum_y(p, pad_left, pad_right)
   plot_width = ((p%canvas(3) - p%canvas(1)) - pad_left) - pad_right
   ! (4) the x ticks; (4.5) the x axes again, their labels' height known; (5) the plot rectangle
   do i = AX_X1, AX_X3
      if (will_render(p%ax(i)) .and. plot_width > 0.0_real32) &
         call locate(p%ax(i), ticks(i), plot_width, .false.)
   enddo
   title_pad = 0.0_real32
   if (title_w > 0.0_real32) title_pad = title_h + LABEL_PADDING(2)
   pad_top = title_pad
   pad_bot = 0.0_real32
   call pad_and_datum_x(p, pad_top, pad_bot)
   if (title_w > 0.0_real32) p%axes_rect(2) = (p%frame(2) + PLOT_PADDING(2)) + title_pad
   p%rect = [p%canvas(1) + pad_left, p%canvas(2) + pad_top, p%canvas(3) - pad_right, p%canvas(4) - pad_bot]
   do i = AX_X1, AX_X3 ! the axes on screen
      p%ax(i)%pixel_min = merge(p%rect(3), p%rect(1), has_flag(p%ax(i)%flags, AXF_INVERT))
      p%ax(i)%pixel_max = merge(p%rect(1), p%rect(3), has_flag(p%ax(i)%flags, AXF_INVERT))
      call update_scale(p%ax(i))
   enddo
   do i = AX_Y1, AX_Y3
      p%ax(i)%pixel_min = merge(p%rect(2), p%rect(4), has_flag(p%ax(i)%flags, AXF_INVERT))
      p%ax(i)%pixel_max = merge(p%rect(4), p%rect(2), has_flag(p%ax(i)%flags, AXF_INVERT))
      call update_scale(p%ax(i))
   enddo
   if (equal) then ! x constrained to y, unless x's limits were set on this frame
      do i = AX_X1, AX_X3
         j = p%ax(i)%ortho
         if (j == 0_int32) cycle
         xar = get_aspect(p%ax(i))
         yar = get_aspect(p%ax(j))
         if (p%ax(i)%has_range) then
            call set_aspect(p%ax(j), xar)
         elseif (.not. almost_equal(xar, yar) .and. .not. ((locked_min(p%ax(j)) .and. locked_max(p%ax(j))) &
                                                           .or. auto_fitting(p%ax(j)))) then
            call set_aspect(p%ax(i), yar)
         endif
      enddo
   endif
   do i = 1_int32, AXES ! the fits asked for: SetNextAxisToFit, ImPlotAxisFlags_AutoFit
      if (next_fit(i) .or. auto_fitting(p%ax(i))) then
         p%fit = .true.
         p%ax(i)%fit = .true.
      endif
   enddo
   ! render: the frame, the plot's background
   call core_style_var('FrameRounding', v, nv)
   rounding = real(v(1), real32)
   call core_style_var('FrameBorderSize', v, nv)
   border = real(v(1), real32)
   call core_draw_begin()
   call core_draw_rect_filled(real(p%frame(1), real64), real(p%frame(2), real64), real(p%frame(3), real64), &
                              real(p%frame(4), real64), core_style_color(ImGuiCol_FrameBg), real(rounding, real64))
   if (border > 0.0_real32) then ! RenderFrame's border
      call core_draw_rect(real(p%frame(1) + 1.0_real32, real64), real(p%frame(2) + 1.0_real32, real64),    &
                          real(p%frame(3) + 1.0_real32, real64), real(p%frame(4) + 1.0_real32, real64),    &
                          core_style_color(ImGuiCol_BorderShadow), real(rounding, real64), real(border, real64))
      call core_draw_rect(real(p%frame(1), real64), real(p%frame(2), real64), real(p%frame(3), real64), &
                          real(p%frame(4), real64), core_style_color(ImGuiCol_Border), real(rounding, real64), &
                          real(border, real64))
   endif
   call core_draw_rect_filled(real(p%rect(1), real64), real(p%rect(2), real64), real(p%rect(3), real64), &
                              real(p%rect(4), real64), core_style_color(ImGuiCol_WindowBg))
   do i = 1_int32, AXES
      if (will_render(p%ax(i))) call place_ticks(ticks(i), p%ax(i))
   enddo
   do i = 1_int32, AXES
      if (p%ax(i)%enabled .and. .not. has_flag(p%ax(i)%flags, AXF_NO_GRID_LINES) .and. &
          .not. has_flag(p%ax(i)%flags, AXF_FOREGROUND)) call grid(p, ticks(i), i >= AX_Y1)
   enddo
   do i = AX_X1, AX_X3
      if (p%ax(i)%enabled) call axis_texts(p, i)
   enddo
   do i = AX_Y1, AX_Y3
      if (p%ax(i)%enabled) call axis_texts(p, i)
   enddo
   p%n_leg = 0_int32 ! Legend.Reset: the entries of this frame's items follow
   p%leg_n = 0_int32
   endsubroutine setup_finish

   subroutine pad_and_datum_x(p, pad_t, pad_b)
   !< `PadAndDatumAxesX`: the x axes placed outwards from the plot, X3 to X1 (each its label's height, its tick labels'
   !< and `LabelPadding`, `MinorTickLen` between two on a side), their paddings added.
   type(plot_record), intent(inout) :: p            !< Plot.
   real(real32),      intent(inout) :: pad_t, pad_b !< Paddings above and below [pixels].
   real(real32)                     :: t, pp, k     !< Text height, LabelPadding, MinorTickLen.
   real(real32)                     :: last_t, last_b !< The previous axes' datums.
   real(real64)                     :: w, h         !< A label's size.
   integer(int32)                   :: count_t, count_b, i !< Axes on a side, axis.

   t = real(core_font_size(), real32)
   pp = LABEL_PADDING(2)
   k = MINOR_TICK_LEN(1)
   count_t = 0_int32
   count_b = 0_int32
   last_t = p%axes_rect(2)
   last_b = p%axes_rect(4)
   do i = AX_X3, AX_X1, -1_int32
      if (.not. p%ax(i)%enabled) cycle
      associate(ax => p%ax(i))
         if (has_flag(ax%flags, AXF_OPPOSITE)) then
            if (count_t > 0_int32) pad_t = pad_t + (k + pp)
            count_t = count_t + 1_int32
            if (has_label(ax)) then
               call core_text_size(text(ax%label_off:ax%label_off + ax%label_len - 1_int32), w, h)
               pad_t = pad_t + (real(h, real32) + pp)
            endif
            if (.not. has_flag(ax%flags, AXF_NO_TICK_LABELS)) &
               pad_t = pad_t + ((max(t, ticks(i)%max_size(2)) + pp) + merge(t + pp, 0.0_real32, &
                                                                            ax%scale == SCALE_TIME))
            ax%datum1 = p%canvas(2) + pad_t
            ax%datum2 = last_t
            last_t = ax%datum1
         else
            if (count_b > 0_int32) pad_b = pad_b + (k + pp)
            count_b = count_b + 1_int32
            if (has_label(ax)) then
               call core_text_size(text(ax%label_off:ax%label_off + ax%label_len - 1_int32), w, h)
               pad_b = pad_b + (real(h, real32) + pp)
            endif
            if (.not. has_flag(ax%flags, AXF_NO_TICK_LABELS)) &
               pad_b = pad_b + ((max(t, ticks(i)%max_size(2)) + pp) + merge(t + pp, 0.0_real32, &
                                                                            ax%scale == SCALE_TIME))
            ax%datum1 = p%canvas(4) - pad_b
            ax%datum2 = last_b
            last_b = ax%datum1
         endif
      endassociate
   enddo
   endsubroutine pad_and_datum_x

   subroutine pad_and_datum_y(p, pad_l, pad_r)
   !< `PadAndDatumAxesY`: the y axes placed outwards from the plot, Y3 to Y1 (each the text height for its label, its
   !< widest tick label and `LabelPadding`, `MinorTickLen` between two on a side), their paddings added.
   type(plot_record), intent(inout) :: p            !< Plot.
   real(real32),      intent(inout) :: pad_l, pad_r !< Paddings left and right [pixels].
   real(real32)                     :: t, pp, k     !< Text height, LabelPadding, MinorTickLen.
   real(real32)                     :: last_l, last_r !< The previous axes' datums.
   integer(int32)                   :: count_l, count_r, i !< Axes on a side, axis.

   t = real(core_font_size(), real32)
   pp = LABEL_PADDING(1)
   k = MINOR_TICK_LEN(2)
   count_l = 0_int32
   count_r = 0_int32
   last_l = p%axes_rect(1)
   last_r = p%axes_rect(3)
   do i = AX_Y3, AX_Y1, -1_int32
      if (.not. p%ax(i)%enabled) cycle
      associate(ax => p%ax(i))
         if (has_flag(ax%flags, AXF_OPPOSITE)) then
            if (count_r > 0_int32) pad_r = pad_r + (k + pp)
            count_r = count_r + 1_int32
            if (has_label(ax)) pad_r = pad_r + (t + pp)
            if (.not. has_flag(ax%flags, AXF_NO_TICK_LABELS)) pad_r = pad_r + (ticks(i)%max_size(1) + pp)
            ax%datum1 = p%canvas(3) - pad_r
            ax%datum2 = last_r
            last_r = ax%datum1
         else
            if (count_l > 0_int32) pad_l = pad_l + (k + pp)
            count_l = count_l + 1_int32
            if (has_label(ax)) pad_l = pad_l + (t + pp)
            if (.not. has_flag(ax%flags, AXF_NO_TICK_LABELS)) pad_l = pad_l + (ticks(i)%max_size(1) + pp)
            ax%datum1 = p%canvas(1) + pad_l
            ax%datum2 = last_l
            last_l = ax%datum1
         endif
      endassociate
   enddo
   endsubroutine pad_and_datum_y

   pure function has_label(ax) result(yes)
   !< `ImPlotAxis::HasLabel`.
   type(plot_axis), intent(in) :: ax  !< Axis.
   logical                     :: yes !< A label shown.

   yes = ax%label_len > 0_int32 .and. .not. has_flag(ax%flags, AXF_NO_LABEL)
   endfunction has_label

   subroutine place_ticks(t, ax)
   !< The ticks' pixels, rounded (`IM_ROUND(PlotToPixels)`).
   type(plot_ticks), intent(inout) :: t  !< Ticks.
   type(plot_axis),  intent(in)    :: ax !< Their axis.
   integer(int32)                 :: k  !< Counter.

   do k = 1_int32, t%n
      t%pix(k) = real(int(to_pixels(ax, t%pos(k)) + 0.5_real32, int32), real32)
   enddo
   endsubroutine place_ticks

   subroutine grid(p, t, vertical)
   !< The grid lines of an axis's ticks (`RenderGridLinesX`, `RenderGridLinesY`): the majors', and the minors' while
   !< the ticks are fewer than one per 5 pixels, faded out from one per 10.
   type(plot_record), intent(in) :: p        !< Plot.
   type(plot_ticks),  intent(in) :: t        !< Ticks.
   logical,           intent(in) :: vertical !< A y axis (horizontal lines).
   real(real32)                  :: density  !< Ticks per pixel.
   real(real32)                  :: a        !< The minors' alpha.
   integer(int32)                :: col_min  !< The minors' colour.
   integer(int32)                :: i        !< Axis: 1 x, 2 y.
   integer(int32)                :: k        !< Counter.
   real(real32), parameter       :: S = 1.0_real32 / 255.0_real32 !< ColorConvertU32ToFloat4's scale.

   i = merge(2_int32, 1_int32, vertical)
   density = real(t%n, real32) / (p%rect(i + 2) - p%rect(i))
   a = real(channel(p%col_min, 3_int32), real32) * S
   a = a * min(max(1.0_real32 + ((density - 0.1_real32) * (0.0_real32 - 1.0_real32)) / (0.2_real32 - 0.1_real32), &
                   0.0_real32), 1.0_real32)
   col_min = with_alpha(p%col_min, int(min(max(a, 0.0_real32), 1.0_real32) * 255.0_real32 + 0.5_real32, int32))
   do k = 1_int32, t%n
      if (t%pix(k) < p%rect(i) .or. t%pix(k) > p%rect(i + 2)) cycle
      if (.not. vertical .and. t%level(k) /= 0_int32) cycle ! RenderGridLinesX: level 0 only
      if (t%major(k)) then
         call line(t%pix(k), p%col_maj, merge(MAJOR_GRID_SIZE(2), MAJOR_GRID_SIZE(1), vertical))
      elseif (density < 0.2_real32) then
         call line(t%pix(k), col_min, merge(MINOR_GRID_SIZE(2), MINOR_GRID_SIZE(1), vertical))
      endif
   enddo
   contains
      subroutine line(px, col, thk)
      !< A grid line at the pixel px.
      real(real32),   intent(in) :: px  !< Pixel.
      integer(int32), intent(in) :: col !< Colour.
      real(real32),   intent(in) :: thk !< Thickness [pixels].

      if (vertical) then
         call core_draw_line_h(real(p%rect(1), real64), real(p%rect(3), real64), real(px, real64), col, &
                               real(thk, real64))
      else
         call core_draw_line_v(real(px, real64), real(p%rect(2), real64), real(p%rect(4), real64), col, &
                               real(thk, real64))
      endif
      endsubroutine line
   endsubroutine grid

   subroutine axis_texts(p, i)
   !< An axis's highlight (`ColorHiLi`, once), label and tick labels (`SetupFinish`): an x axis's label centred
   !< beyond its tick labels, its tick labels centred on their ticks; a y axis's label rotated, its tick labels aligned
   !< on the plot's side.
   type(plot_record), intent(inout) :: p       !< Plot.
   integer(int32),    intent(in)    :: i       !< Axis.
   real(real32)                     :: px, py  !< A label's corner [pixels].
   real(real32)                     :: pad, datum, off !< Distances from the axis.
   real(real32)                     :: lw, lh  !< The label's size.
   real(real64)                     :: w, h    !< A text's size.
   integer(int32)                   :: k       !< Counter.
   logical                          :: opp     !< On the opposite side.

   associate(ax => p%ax(i), t => ticks(i), r => p%rect)
      opp = has_flag(ax%flags, AXF_OPPOSITE)
      if (ax%hili /= 0_int32) then ! (no hover: the axis's background, AxisBg, is transparent)
         if (i <= AX_X3) then
            call core_draw_rect_filled(real(r(1), real64), real(min(ax%datum1, ax%datum2), real64), &
                                       real(r(3), real64), real(max(ax%datum1, ax%datum2), real64), ax%hili)
         else
            call core_draw_rect_filled(real(min(ax%datum1, ax%datum2), real64), real(r(2), real64), &
                                       real(max(ax%datum1, ax%datum2), real64), real(r(4), real64), ax%hili)
         endif
         ax%hili = 0_int32
      endif
      if (i <= AX_X3) then
         if (has_label(ax)) then
            call core_text_size(text(ax%label_off:ax%label_off + ax%label_len - 1_int32), w, h)
            lw = real(w, real32)
            lh = real(h, real32)
            off = 0.0_real32
            if (.not. has_flag(ax%flags, AXF_NO_TICK_LABELS)) off = (t%max_size(2) + LABEL_PADDING(2)) + &
                                                                    real(t%levels - 1_int32, real32) *      &
                                                                    (real(core_font_size(), real32) +       &
                                                                     LABEL_PADDING(2))
            off = off + LABEL_PADDING(2)
            px = (r(1) + r(3)) * 0.5_real32 - lw * 0.5_real32
            py = merge((ax%datum1 - off) - lh, ax%datum1 + off, opp)
            call core_draw_text(real(px, real64), real(py, real64), p%col_txt, &
                                text(ax%label_off:ax%label_off + ax%label_len - 1_int32))
         endif
         if (.not. has_flag(ax%flags, AXF_NO_TICK_LABELS)) then
            do k = 1_int32, t%n
               pad = (LABEL_PADDING(2) + merge(t%label_size(2, k), 0.0_real32, opp)) + &
                     real(t%level(k), real32) * (real(core_font_size(), real32) + LABEL_PADDING(2))
               datum = ax%datum1 + pad * merge(-1.0_real32, 1.0_real32, opp)
               if (.not. t%show(k) .or. t%pix(k) < r(1) - 1.0_real32 .or. t%pix(k) > r(3) + 1.0_real32) cycle
               px = t%pix(k) - 0.5_real32 * t%label_size(1, k)
               call core_draw_text(real(px, real64), real(datum, real64), p%col_txt, trim(t%label(k)))
            enddo
         endif
      else
         if (has_label(ax)) then
            call core_text_size(text(ax%label_off:ax%label_off + ax%label_len - 1_int32), w, h)
            lw = real(h, real32) ! CalcTextSizeVertical
            lh = real(w, real32)
            off = 0.0_real32
            if (.not. has_flag(ax%flags, AXF_NO_TICK_LABELS)) off = t%max_size(1) + LABEL_PADDING(1)
            off = off + LABEL_PADDING(1)
            px = merge(ax%datum1 + off, (ax%datum1 - off) - lw, opp)
            py = (r(2) + r(4)) * 0.5_real32 + lh * 0.5_real32
            call text_vertical(px, py, p%col_txt, text(ax%label_off:ax%label_off + ax%label_len - 1_int32))
         endif
         if (.not. has_flag(ax%flags, AXF_NO_TICK_LABELS)) then
            do k = 1_int32, t%n
               pad = LABEL_PADDING(1) + merge(0.0_real32, t%label_size(1, k), opp)
               datum = ax%datum1 + pad * merge(1.0_real32, -1.0_real32, opp)
               if (.not. t%show(k) .or. t%pix(k) < r(2) - 1.0_real32 .or. t%pix(k) > r(4) + 1.0_real32) cycle
               py = t%pix(k) - 0.5_real32 * t%label_size(2, k)
               call core_draw_text(real(datum, real64), real(py, real64), p%col_txt, trim(t%label(k)))
            enddo
         endif
      endif
   endassociate
   endsubroutine axis_texts

   subroutine tick_marks(p)
   !< `EndPlot`'s tick marks: each axis's, outwards from it (minor length and size on a side's second and third axes),
   !< and its line where the border does not draw it (a side's second and third axes, or no border).
   type(plot_record), intent(in) :: p          !< Plot.
   real(real32)                  :: len_, thk  !< A tick's length and thickness.
   real(real32)                  :: dir        !< Its direction.
   integer(int32)                :: i, k       !< Axis, counter.
   integer(int32)                :: count_a, count_b !< Axes drawn on the near side, on the opposite side.
   logical                       :: opp, aux   !< On the opposite side, not the first on its side.

   count_a = 0_int32
   count_b = 0_int32
   do i = AX_X1, AX_X3
      if (.not. p%ax(i)%enabled) cycle
      associate(ax => p%ax(i), t => ticks(i), r => p%rect)
         opp = has_flag(ax%flags, AXF_OPPOSITE)
         aux = (opp .and. count_b > 0_int32) .or. (.not. opp .and. count_a > 0_int32)
         if (.not. has_flag(ax%flags, AXF_NO_TICK_MARKS)) then
            dir = merge(1.0_real32, -1.0_real32, opp)
            do k = 1_int32, t%n
               if (t%level(k) /= 0_int32 .or. t%pix(k) < r(1) .or. t%pix(k) > r(3)) cycle
               len_ = merge(MAJOR_TICK_LEN(1), MINOR_TICK_LEN(1), .not. aux .and. t%major(k))
               thk = merge(MAJOR_TICK_SIZE(1), MINOR_TICK_SIZE(1), .not. aux .and. t%major(k))
               call core_draw_line_v(real(t%pix(k), real64), real(ax%datum1, real64), &
                                     real(ax%datum1 + dir * len_, real64), p%col_tick, real(thk, real64))
            enddo
            if (aux .or. .not. border_shown(p)) call core_draw_line_h(real(r(1), real64), real(r(3), real64), &
                                                                     real(ax%datum1, real64), p%col_tick,     &
                                                                     real(MINOR_TICK_SIZE(1), real64))
         endif
         if (opp) then
            count_b = count_b + 1_int32
         else
            count_a = count_a + 1_int32
         endif
      endassociate
   enddo
   count_a = 0_int32
   count_b = 0_int32
   do i = AX_Y1, AX_Y3
      if (.not. p%ax(i)%enabled) cycle
      associate(ax => p%ax(i), t => ticks(i), r => p%rect)
         opp = has_flag(ax%flags, AXF_OPPOSITE)
         aux = (opp .and. count_b > 0_int32) .or. (.not. opp .and. count_a > 0_int32)
         if (.not. has_flag(ax%flags, AXF_NO_TICK_MARKS)) then
            dir = merge(-1.0_real32, 1.0_real32, opp)
            do k = 1_int32, t%n
               if (t%level(k) /= 0_int32 .or. t%pix(k) < r(2) .or. t%pix(k) > r(4)) cycle
               len_ = merge(MAJOR_TICK_LEN(2), MINOR_TICK_LEN(2), .not. aux .and. t%major(k))
               thk = merge(MAJOR_TICK_SIZE(2), MINOR_TICK_SIZE(2), .not. aux .and. t%major(k))
               call core_draw_line_h(real(ax%datum1, real64), real(ax%datum1 + dir * len_, real64), &
                                     real(t%pix(k), real64), p%col_tick, real(thk, real64))
            enddo
            if (aux .or. .not. border_shown(p)) call core_draw_line_v(real(ax%datum1, real64), real(r(2), real64), &
                                                                     real(r(4), real64), p%col_tick,              &
                                                                     real(MINOR_TICK_SIZE(2), real64))
         endif
         if (opp) then
            count_b = count_b + 1_int32
         else
            count_a = count_a + 1_int32
         endif
      endassociate
   enddo
   endsubroutine tick_marks

   ! private: the legend

   function legend_size(p, vertical) result(sz)
   !< `CalcLegendSize`: the legend's size, its entries in a column or a row.
   type(plot_record), intent(in) :: p        !< Plot.
   logical,           intent(in) :: vertical !< In a column.
   real(real32)                  :: sz(2)    !< Size [pixels].
   real(real32)                  :: txt_ht, icon, max_w, sum_w, lw !< Text height, icon, widths.
   real(real64)                  :: w, h     !< A label's size.
   integer(int32)                :: k, n     !< Counter, entries.

   n = p%n_leg
   txt_ht = real(core_font_size(), real32)
   icon = txt_ht
   max_w = 0.0_real32
   sum_w = 0.0_real32
   do k = 1_int32, n
      call core_text_size(p%leg_text(p%leg_off(k):p%leg_off(k) + p%leg_len(k) - 1_int32), w, h, hide_after_hash=.true.)
      lw = real(w, real32)
      if (lw > max_w) max_w = lw
      sum_w = sum_w + lw
   enddo
   if (vertical) then
      sz(1) = (LEGEND_INNER_PADDING(1) * 2.0_real32 + icon) + max_w
      sz(2) = (LEGEND_INNER_PADDING(2) * 2.0_real32 + real(n, real32) * txt_ht) + &
              real(n - 1_int32, real32) * LEGEND_SPACING(2)
   else
      sz(1) = ((LEGEND_INNER_PADDING(1) * 2.0_real32 + icon * real(n, real32)) + sum_w) + &
              real(n - 1_int32, real32) * LEGEND_SPACING(1)
      sz(2) = LEGEND_INNER_PADDING(2) * 2.0_real32 + txt_ht
   endif
   endfunction legend_size

   function location_pos(outer, sz, loc, pad) result(pos)
   !< `GetLocationPos`: where a box of size `sz` goes in `outer` at a compass point, `pad` from its sides, rounded.
   real(real32),   intent(in) :: outer(4) !< Outer rectangle.
   real(real32),   intent(in) :: sz(2)    !< Box's size.
   integer(int32), intent(in) :: loc      !< ImPlotLocation.
   real(real32),   intent(in) :: pad(2)   !< Padding.
   real(real32)               :: pos(2)   !< Top-left corner.

   if (has_flag(loc, LOC_WEST) .and. .not. has_flag(loc, LOC_EAST)) then
      pos(1) = outer(1) + pad(1)
   elseif (.not. has_flag(loc, LOC_WEST) .and. has_flag(loc, LOC_EAST)) then
      pos(1) = (outer(3) - pad(1)) - sz(1)
   else
      pos(1) = (outer(1) + outer(3)) * 0.5_real32 - sz(1) * 0.5_real32
   endif
   if (has_flag(loc, LOC_NORTH) .and. .not. has_flag(loc, LOC_SOUTH)) then
      pos(2) = outer(2) + pad(2)
   elseif (.not. has_flag(loc, LOC_NORTH) .and. has_flag(loc, LOC_SOUTH)) then
      pos(2) = (outer(4) - pad(2)) - sz(2)
   else
      pos(2) = (outer(2) + outer(4)) * 0.5_real32 - sz(2) * 0.5_real32
   endif
   pos = real(int(pos + 0.5_real32, int32), real32) ! IM_ROUND
   endfunction location_pos

   subroutine legend(p)
   !< `EndPlot`'s legend: the items' hover reset, then the legend placed (`GetLocationPos`, `ClampLegendRect`), its
   !< button (the legend's ID, `plot.ID - 1`), its background, entries (`ShowLegendEntries`) and border.
   type(plot_record), intent(inout) :: p          !< Plot.
   real(real32)                     :: sz(2)      !< Its size.
   real(real32)                     :: outer(4)   !< Where it goes.
   real(real32)                     :: pad(2)     !< Its padding there.
   real(real32)                     :: lr(4)      !< Its rectangle.
   real(real32)                     :: cl(4)      !< ... clamped.
   logical                          :: out, horz, held !< Outside, horizontal; the button held.
   integer(int32)                   :: items_id   !< The legend's ID.
   logical                          :: dummy      !< Pressed.

   p%leg_hovered = .false.
   if (p%n_items > 0_int32) p%item_hovered(1:p%n_items) = .false.
   if (has_flag(p%flags, PF_NO_LEGEND) .or. p%n_leg < 1_int32) return
   out = has_flag(p%leg_flags, LGF_OUTSIDE)
   horz = has_flag(p%leg_flags, LGF_HORIZONTAL)
   sz = legend_size(p, .not. horz)
   if (out) then
      outer = p%frame
      pad = PLOT_PADDING
   else
      outer = p%rect
      pad = LEGEND_PADDING
   endif
   lr(1:2) = location_pos(outer, sz, p%leg_loc, pad)
   lr(3:4) = lr(1:2) + sz
   cl = lr ! ClampLegendRect
   cl(1) = max(cl(1), outer(1) + pad(1))
   cl(2) = max(cl(2), outer(2) + pad(2))
   cl(3) = min(cl(3), outer(3) - pad(1))
   cl(4) = min(cl(4), outer(4) - pad(2))
   if (any(cl /= lr)) then ! clamped: the entries from the clamped corner (no scrolling yet)
      lr(3:4) = lr(3:4) + (cl(1:2) - lr(1:2))
      lr(1:2) = cl(1:2)
   endif
   items_id = plot_id_offset(p%id, -1_int32)
   call core_keep_alive(items_id)
   dummy = core_button_behavior(real(cl(1), real64), real(cl(2), real64), real(cl(3), real64), real(cl(4), real64), &
                                items_id, p%leg_hovered, held, flags=LEGEND_BUTTON_FLAGS)
   call core_push_clip_rect(real(cl(1), real64), real(cl(2), real64), real(cl(3), real64), real(cl(4), real64))
   call core_draw_rect_filled(real(cl(1), real64), real(cl(2), real64), real(cl(3), real64), real(cl(4), real64), &
                              core_style_color(ImGuiCol_PopupBg))
   call legend_entries(p, lr, .not. horz)
   call core_draw_rect(real(cl(1), real64), real(cl(2), real64), real(cl(3), real64), real(cl(4), real64), &
                       core_style_color(ImGuiCol_Border))
   call core_pop_clip_rect()
   endsubroutine legend

   subroutine legend_entries(p, lr, vertical)
   !< `ShowLegendEntries`: each entry its button (a click shows or hides the item), its icon and its label.
   type(plot_record), intent(inout) :: p        !< Plot.
   real(real32),      intent(in)    :: lr(4)    !< Legend's rectangle.
   logical,           intent(in)    :: vertical !< In a column.
   real(real32)                     :: txt_ht, icon, lw, sum_w !< Text height, icon, label widths.
   real(real32)                     :: tl(2)    !< An entry's top-left corner.
   real(real32)                     :: ib(4)    !< Its icon.
   real(real64)                     :: w, h     !< A label's size.
   integer(int32)                   :: col_txt, col_dis, col_hl, col_item, col_icon !< Colours.
   integer(int32)                   :: k, it, a, n !< Entry, item, label's start and shown length.
   logical                          :: hov, held, clicked !< The entry's button.
   real(real32), parameter          :: SHRINK = 2.0_real32 !< icon_shrink.

   txt_ht = real(core_font_size(), real32)
   icon = txt_ht
   col_txt = core_style_color(ImGuiCol_Text) ! LegendText: InlayText: Text
   col_dis = alpha_u32(col_txt, 0.25_real32)
   sum_w = 0.0_real32
   do k = 1_int32, p%n_leg
      it = p%leg_item(k)
      a = p%leg_off(k)
      n = rendered_len(p%leg_text(a:a + p%leg_len(k) - 1_int32))
      call core_text_size(p%leg_text(a:a + p%leg_len(k) - 1_int32), w, h, hide_after_hash=.true.)
      lw = real(w, real32)
      if (vertical) then
         tl(1) = (lr(1) + LEGEND_INNER_PADDING(1)) + 0.0_real32
         tl(2) = (lr(2) + LEGEND_INNER_PADDING(2)) + real(k - 1_int32, real32) * (txt_ht + LEGEND_SPACING(2))
      else
         tl(1) = (lr(1) + LEGEND_INNER_PADDING(1)) + (real(k - 1_int32, real32) * (icon + LEGEND_SPACING(1)) + sum_w)
         tl(2) = (lr(2) + LEGEND_INNER_PADDING(2)) + 0.0_real32
      endif
      sum_w = sum_w + lw
      ib = [tl(1) + SHRINK, tl(2) + SHRINK, tl(1) + (icon - SHRINK), tl(2) + (icon - SHRINK)]
      col_item = p%item_color(it)
      call core_keep_alive(p%item_id(it))
      hov = .false.
      held = .false.
      clicked = .false.
      if (.not. has_flag(p%leg_flags, LGF_NO_BUTTONS)) &
         clicked = core_button_behavior(real(ib(1), real64), real(ib(2), real64), real(tl(1) + (lw + icon), real64), &
                                        real(tl(2) + icon, real64), p%item_id(it), hov, held)
      if (clicked) p%item_show(it) = .not. p%item_show(it)
      if (hov .and. (.not. has_flag(p%leg_flags, LGF_NO_HIGHLIGHT_ITEM) .or. &
                     .not. has_flag(p%leg_flags, LGF_NO_HIGHLIGHT_AXIS))) then
         p%item_hovered(it) = .true.
         col_hl = mix_u32(col_txt, col_item, 64_int32)
      else
         col_hl = col_txt
      endif
      if (held) then
         if (p%item_show(it)) then
            col_icon = alpha_u32(col_item, 0.5_real32)
         else
            col_icon = core_style_color(ImGuiCol_TextDisabled, 0.5_real64)
         endif
      elseif (hov) then
         if (p%item_show(it)) then
            col_icon = alpha_u32(col_item, 0.75_real32)
         else
            col_icon = core_style_color(ImGuiCol_TextDisabled, 0.75_real64)
         endif
      else
         col_icon = merge(col_item, col_dis, p%item_show(it))
      endif
      call core_draw_rect_filled(real(ib(1), real64), real(ib(2), real64), real(ib(3), real64), real(ib(4), real64), &
                                 col_icon)
      if (n > 0_int32) call core_draw_text(real(tl(1) + icon, real64), real(tl(2) + 0.0_real32, real64), &
                                           merge(col_hl, col_dis, p%item_show(it)), p%leg_text(a:a + n - 1_int32))
   enddo
   endsubroutine legend_entries

   ! private: text

   subroutine text_centered(cx, top, col, s)
   !< `AddTextCentered`: a text's shown part (up to `##`), each line centred on `cx`, from `top` down.
   real(real32),     intent(in) :: cx  !< Centre's abscissa [pixels].
   real(real32),     intent(in) :: top !< Top [pixels].
   integer(int32),   intent(in) :: col !< Colour.
   character(len=*), intent(in) :: s   !< Text.
   real(real32)                 :: y, txt_ht !< Line's offset, text height.
   real(real64)                 :: w, h      !< A line's size.
   integer(int32)               :: a, e, nl  !< A line's start, the shown end, a newline.

   txt_ht = real(core_font_size(), real32)
   e = rendered_len(s)
   a = 1_int32
   y = 0.0_real32
   do
      nl = int(index(s(a:e), achar(10)), int32)
      if (nl == 0_int32) exit
      call core_text_size(s(a:a + nl - 2_int32), w, h, hide_after_hash=.true.)
      call core_draw_text(real(cx - real(w, real32) * 0.5_real32, real64), real(top + y, real64), col, &
                          s(a:a + nl - 2_int32))
      a = a + nl
      y = y + txt_ht
   enddo
   call core_text_size(s(a:e), w, h, hide_after_hash=.true.)
   call core_draw_text(real(cx - real(w, real32) * 0.5_real32, real64), real(top + y, real64), col, s(a:e))
   endsubroutine text_centered

   subroutine text_vertical(x, y, col, s)
   !< `AddTextVertical`: a text rotated a quarter turn anticlockwise, (x, y) its bottom-left corner (floored), glyph by
   !< glyph from the current font's baked glyphs (`core_font_glyph`), each a textured quad, the pen moving up by its
   !< advance; characters decoded from UTF-8, those without a glyph skipped.
   real(real32),     intent(in) :: x, y !< Bottom-left corner [pixels].
   integer(int32),   intent(in) :: col  !< Colour.
   character(len=*), intent(in) :: s    !< Text (UTF-8).
   real(real32)                 :: px, py, sc !< Pen, scale.
   real(real64)                 :: scale, adv, x0, y0, x1, y1, u0, v0, u1, v1 !< A glyph.
   integer(int32)               :: k, c, nb !< Byte, code point, its bytes.
   logical                      :: found !< A glyph.

   px = im_floor(x)
   py = im_floor(y)
   k = 1_int32
   do while (k <= len(s, kind=int32))
      call utf8_char(s, k, c, nb)
      k = k + nb
      call core_font_glyph(c, found, scale, adv, x0, y0, x1, y1, u0, v0, u1, v1)
      if (.not. found) cycle
      sc = real(scale, real32)
      call core_draw_quad_uv(real([px + real(y0, real32) * sc, px + real(y0, real32) * sc,                    &
                                   px + real(y1, real32) * sc, px + real(y1, real32) * sc], real64),          &
                             real([py + (-real(x0, real32)) * sc, py + (-real(x1, real32)) * sc,             &
                                   py + (-real(x1, real32)) * sc, py + (-real(x0, real32)) * sc], real64),    &
                             [u0, u1, u1, u0], [v0, v0, v1, v1], col)
      py = py - real(adv, real32) * sc
   enddo
   endsubroutine text_vertical

   pure subroutine utf8_char(s, k, c, nb)
   !< The character at byte k of a UTF-8 text (`ImTextCharFromUtf8`): its code point and bytes (a malformed sequence:
   !< U+FFFD, one byte).
   character(len=*), intent(in)  :: s  !< Text.
   integer(int32),   intent(in)  :: k  !< Byte.
   integer(int32),   intent(out) :: c  !< Code point.
   integer(int32),   intent(out) :: nb !< Bytes.
   integer(int32)                :: b(4), j, n !< Bytes, counter, bytes left.

   n = len(s, kind=int32) - k + 1_int32
   b = 0_int32
   do j = 1_int32, min(4_int32, n)
      b(j) = iand(ichar(s(k + j - 1_int32:k + j - 1_int32), kind=int32), 255_int32)
   enddo
   c = 65533_int32
   nb = 1_int32
   if (b(1) < 128_int32) then
      c = b(1)
   elseif (iand(b(1), 224_int32) == 192_int32 .and. n >= 2_int32) then
      if (iand(b(2), 192_int32) == 128_int32) then
         c = ior(ishft(iand(b(1), 31_int32), 6), iand(b(2), 63_int32))
         nb = 2_int32
      endif
   elseif (iand(b(1), 240_int32) == 224_int32 .and. n >= 3_int32) then
      if (iand(b(2), 192_int32) == 128_int32 .and. iand(b(3), 192_int32) == 128_int32) then
         c = ior(ior(ishft(iand(b(1), 15_int32), 12), ishft(iand(b(2), 63_int32), 6)), iand(b(3), 63_int32))
         nb = 3_int32
      endif
   elseif (iand(b(1), 248_int32) == 240_int32 .and. n >= 4_int32) then
      if (iand(b(2), 192_int32) == 128_int32 .and. iand(b(3), 192_int32) == 128_int32 .and. &
          iand(b(4), 192_int32) == 128_int32) then
         c = ior(ior(ior(ishft(iand(b(1), 7_int32), 18), ishft(iand(b(2), 63_int32), 12)), &
                     ishft(iand(b(3), 63_int32), 6)), iand(b(4), 63_int32))
         nb = 4_int32
      endif
   endif
   endsubroutine utf8_char

   pure function im_floor(f) result(r)
   !< `ImFloor` of a float.
   real(real32), intent(in) :: f !< Value.
   real(real32)             :: r !< Floor.

   r = real(int(f, int32), real32)
   if (f < 0.0_real32 .and. r /= f) r = r - 1.0_real32
   endfunction im_floor

   ! private: colours

   pure function alpha_u32(col, alpha) result(c)
   !< `ImAlphaU32`: the alpha bits of `(1 - alpha) * 255` cleared.
   integer(int32), intent(in) :: col   !< Packed colour.
   real(real32),   intent(in) :: alpha !< Alpha in [0, 1].
   integer(int32)             :: c     !< Colour.
   integer(int64)             :: u     !< Unsigned value.

   u = iand(iand(int(col, int64), 4294967295_int64), &
            not(ishft(int(int((1.0_real32 - alpha) * 255.0_real32, int32), int64), 24)))
   if (u >= 2147483648_int64) u = u - 4294967296_int64
   c = int(u, int32)
   endfunction alpha_u32

   pure function mix_u32(a, b, s) result(c)
   !< `ImMixU32` (32-bit form): a + (b - a) * s / 256 on each channel.
   integer(int32), intent(in) :: a, b !< Packed colours.
   integer(int32), intent(in) :: s    !< Weight of b, 0-256.
   integer(int32)             :: c    !< Mix.
   integer(int64)             :: ua, ub, al, ah, bl, bh, ml, mh, u !< Unsigned values.
   integer(int64), parameter  :: M32 = 4294967295_int64 !< 32 bits.

   ua = iand(int(a, int64), M32)
   ub = iand(int(b, int64), M32)
   al = iand(ua, 16711935_int64)                 ! 0x00ff00ff
   ah = ishft(iand(ua, 4278255360_int64), -8)    ! 0xff00ff00
   bl = iand(ub, 16711935_int64)
   bh = ishft(iand(ub, 4278255360_int64), -8)
   ml = iand(al * int(256_int32 - s, int64) + bl * int(s, int64), M32)
   mh = iand(ah * int(256_int32 - s, int64) + bh * int(s, int64), M32)
   u = ior(iand(mh, 4278255360_int64), ishft(iand(ml, 4278255360_int64), -8))
   if (u >= 2147483648_int64) u = u - 4294967296_int64
   c = int(u, int32)
   endfunction mix_u32

   subroutine locate(ax, t, pixels, vertical)
   !< The axis's locator (`axis.Locator`): `Locator_Default`, `Locator_Log10`, `Locator_SymLog` or `Locator_Time` of
   !< figure_plot_locators, on its range, the axis `pixels` long.
   type(plot_axis),  intent(in)    :: ax       !< Axis.
   type(plot_ticks), intent(inout) :: t        !< Ticks (appended).
   real(real32),     intent(in)    :: pixels   !< Axis's length [pixels].
   logical,          intent(in)    :: vertical !< A y axis.

   select case (ax%scale)
   case (SCALE_LOG10)
      call locate_log10(t, ax%range_min, ax%range_max, pixels, vertical, measure_text)
   case (SCALE_SYMLOG)
      call locate_symlog(t, ax%range_min, ax%range_max, pixels, vertical, measure_text)
   case (SCALE_TIME)
      call locate_time(t, ax%range_min, ax%range_max, pixels, measure_text)
   case default
      call locate_default(t, ax%range_min, ax%range_max, pixels, vertical, measure_text)
   endselect
   endsubroutine locate

   pure function to_pixels(ax, v) result(px)
   !< `PlotToPixels` (and the items' `Transformer1`): the pixel of a value, in single precision; on a log10 or symlog
   !< axis the value's place in the transformed range mapped back onto the range first. The products added to
   !< another term in statements of their own (no FMA, as ImPlot's build).
   type(plot_axis), intent(in) :: ax !< Axis.
   real(real64),    intent(in) :: v  !< Value.
   real(real32)                :: px !< Pixel.
   real(real64)                :: w, tt !< Value on the range, its fraction.

   w = v
   if (ax%scale == SCALE_LOG10 .or. ax%scale == SCALE_SYMLOG) then
      tt = (forward(ax, v) - ax%scale_min) / (ax%scale_max - ax%scale_min)
      w = (ax%range_max - ax%range_min) * tt
      w = ax%range_min + w
   endif
   w = ax%scale_to_pixel * (w - ax%range_min)
   px = real(real(ax%pixel_min, real64) + w, real32)
   endfunction to_pixels

   pure function border_shown(p) result(shown)
   !< The plot's border is drawn (`PlotBorderSize` > 0, the colour not transparent).
   type(plot_record), intent(in) :: p     !< Plot.
   logical                       :: shown !< Drawn.

   shown = PLOT_BORDER_SIZE > 0.0_real32 .and. channel(p%col_border, 3_int32) > 0_int32
   endfunction border_shown

   pure function rgb_u32(rgb) result(col)
   !< An opaque colour packed as `IM_RGB` packs it (red in the low byte).
   integer(int32), intent(in) :: rgb(3) !< Channels 0-255.
   integer(int32)             :: col    !< Packed colour.

   col = with_alpha(ior(ior(rgb(1), ishft(rgb(2), 8)), ishft(rgb(3), 16)), 255_int32)
   endfunction rgb_u32

   pure function channel(col, c) result(v)
   !< A channel of a packed colour (0 red, 1 green, 2 blue, 3 alpha), 0-255.
   integer(int32), intent(in) :: col !< Packed colour.
   integer(int32), intent(in) :: c   !< Channel.
   integer(int32)             :: v   !< Value.

   v = int(iand(ishft(int(col, int64), -8 * int(c, int64)), 255_int64), int32)
   endfunction channel

   pure function with_alpha(col, a) result(c)
   !< A packed colour with the alpha a (0-255).
   integer(int32), intent(in) :: col !< Packed colour.
   integer(int32), intent(in) :: a   !< Alpha.
   integer(int32)             :: c   !< Colour.
   integer(int64)             :: u   !< Unsigned value.

   u = ior(iand(int(col, int64), 16777215_int64), ishft(int(a, int64), 24))
   if (u >= 2147483648_int64) u = u - 4294967296_int64
   c = int(u, int32)
   endfunction with_alpha
endmodule figure_plot_frame
