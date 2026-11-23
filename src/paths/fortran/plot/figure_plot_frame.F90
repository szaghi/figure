!< figure_plot_frame, the Fortran path's plot frame: a plot's layout, axes, ticks, grid, legend and lines, as ImPlot
!< draws them.
module figure_plot_frame
!< figure_plot_frame, the Fortran path's plot frame: a plot's layout, axes, ticks, grid, legend and lines, as ImPlot
!< draws them.
!<
!< szaghi/figure#15 P10. A plot drawn through figure_core only (no ImPlot, no figure_cimplot), to the pixels ImPlot 1.2
!< WIP (FIGURE's copy) draws for the same plot: `pf_begin_plot`, `pf_setup_axes`, `pf_setup_axis`,
!< `pf_setup_axes_limits`, `pf_setup_axis_limits`, `pf_setup_legend`, `pf_set_next_axes_to_fit`,
!< `pf_set_next_axis_to_fit`, `pf_set_axes`, `pf_hide_next_item`, `pf_line` (figure_plot_items), `pf_legend_hovered`,
!< `pf_plot_limits`,
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
!<
!< No allocation per frame once the tables are grown (ADR 0001; P10 step 9, figure_test_plot_frame_alloc counts them):
!< every label is written by figure_plot_format into a fixed slot (the ticks' 31 characters, `mouse_text`) and passed
!< on as a substring, never `trim`med nor concatenated; a format is parsed once per call into a `plot_format`; the
!< popups declared every frame go through figure_core's `core_*_popup`; quads are built in fixed arrays, not array
!< constructors (nvfortran allocates those). An open context menu's widgets (src/lib's `ig_menu_item`, ...) still
!< allocate their NUL-terminated copies while it is open.
use, intrinsic :: ieee_arithmetic, only : ieee_negative_inf, ieee_positive_inf, ieee_value
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use figure_cimgui_enums, only : ImGuiCol_Border, ImGuiCol_BorderShadow, ImGuiCol_ButtonActive, &
                                ImGuiCol_ButtonHovered, ImGuiCol_FrameBg, ImGuiCol_PopupBg, ImGuiCol_Text, &
                                ImGuiCol_TextDisabled, ImGuiCol_WindowBg, ImGuiItemFlags_Disabled, &
                                ImGuiKey_MouseWheelY, ImGuiMod_Alt, ImGuiMod_Ctrl, ImGuiMod_Shift, &
                                ImGuiMouseCursor_None, ImGuiMouseCursor_NotAllowed, ImGuiMouseCursor_ResizeAll, &
                                ImGuiMouseCursor_ResizeEW, ImGuiMouseCursor_ResizeNS, ImGuiStyleVar_Alpha, &
                                ImGuiStyleVar_ItemSpacing
use figure_core, only : core_button_behavior, core_color, core_content_region_avail, core_cursor_screen_pos, &
                        core_draw_begin, core_draw_end, core_draw_line_h, core_draw_line_v, core_draw_quad_uv, &
                        core_draw_rect, core_draw_rect_filled, core_draw_text, core_font_glyph, core_font_size, &
                        core_frame_count, core_get_id, core_item_add, core_item_size, core_keep_alive,         &
                        core_line_texture, core_pop_clip_rect, core_push_clip_rect, core_style_color,           &
                        core_style_var, core_text_size, core_draw_rect_filled_multicolor, core_drag_double,     &
                        core_invisible_button, core_io_input, core_mouse_clicked, core_mouse_double_clicked,    &
                        core_mouse_down, core_mouse_drag_delta, core_mouse_pos, core_mouse_pos_valid,           &
                        core_mouse_released, core_pop_id, core_pop_item_flag, core_pop_style_var,               &
                        core_push_id_int, core_push_item_flag, core_push_item_width, core_push_override_id,     &
                        core_push_style_var, core_radio_button, core_set_key_owner, core_set_mouse_cursor,      &
                        core_text_unformatted, core_window_hovered, core_frame_height, core_open_popup,         &
                        core_begin_popup, core_end_popup
use figure_plot_colormaps, only : cm_colormap, cm_current, cm_is_qual, cm_key, cm_sample, cm_size, cm_style_refresh, &
                                 mix_u32, CM_VIRIDIS
use figure_plot_hash, only : plot_hash, plot_id_offset
use figure_plot_format, only : plot_format, fmt_parse, fmt_text
use figure_plot_transform, only : plot_axis_map, map_pixel
use figure_plot_locators, only : plot_ticks, ticks_reset, locate_default, locate_log10, locate_symlog, locate_time, &
                                transform_log10, transform_symlog, inverse_log10, inverse_symlog, axis_value_text, &
                                time_cursor_label, TIME_MAX, TIME_MIN
use figure_imgui, only : ig_button, ig_checkbox, ig_same_line, ig_separator
use figure_menu, only : ig_begin_menu, ig_end_menu, ig_menu_item

implicit none
private
public :: pf_begin_plot, pf_end_plot, pf_plot_limits
public :: plot_item_ctx, pf_item_begin, pf_item_fit, pf_item_end, pf_item_hidden, pf_item_fit_axis
public :: pf_plot_ctx, pf_item_count, pf_item_shown_at, pf_item_state, pf_item_fit_with, pf_digital_offset
public :: pf_text_vertical
public :: pf_setup_axes, pf_setup_axis, pf_setup_axes_limits, pf_setup_axis_limits, pf_setup_legend
public :: pf_set_next_axes_to_fit, pf_set_next_axis_to_fit, pf_set_axes
public :: pf_hide_next_item, pf_legend_hovered
public :: pf_plot_count, pf_colormap, pf_colormap_scale
public :: pf_plot_hovered, pf_plot_mouse, pf_plot_to_pixels, pf_pixels_to_plot, pf_plot_selection
public :: pf_cancel_selection

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
integer(int32), parameter :: PF_NO_MOUSE_TEXT = 4_int32    !< ImPlotFlags_NoMouseText.
integer(int32), parameter :: PF_NO_INPUTS = 8_int32        !< ImPlotFlags_NoInputs.
integer(int32), parameter :: PF_NO_MENUS = 16_int32        !< ImPlotFlags_NoMenus.
integer(int32), parameter :: PF_NO_BOX_SELECT = 32_int32   !< ImPlotFlags_NoBoxSelect.
integer(int32), parameter :: PF_CROSSHAIRS = 256_int32     !< ImPlotFlags_Crosshairs.
integer(int32), parameter :: AXF_NO_MENUS = 32_int32       !< ImPlotAxisFlags_NoMenus.
integer(int32), parameter :: AXF_NO_SIDE_SWITCH = 64_int32 !< ImPlotAxisFlags_NoSideSwitch.
integer(int32), parameter :: AXF_NO_HIGHLIGHT = 128_int32  !< ImPlotAxisFlags_NoHighlight.
integer(int32), parameter :: AXF_PAN_STRETCH = 8192_int32  !< ImPlotAxisFlags_PanStretch.
integer(int32), parameter :: AXF_TICK_LABELS_INSIDE = 65536_int32 !< ImPlotAxisFlags_TickLabelsInside.
integer(int32), parameter :: LGF_NO_MENUS = 8_int32        !< ImPlotLegendFlags_NoMenus.
! ImPlot's input (MapInputDefault, UpdateInput): buttons (0 left, 1 right), thresholds, the zoom rate
integer(int32), parameter :: BTN_PAN = 0_int32, BTN_FIT = 0_int32, BTN_MENU = 1_int32, BTN_SELECT = 1_int32, &
                             BTN_SELECT_CANCEL = 0_int32 !< Pan, Fit, Menu, Select, SelectCancel.
integer(int32), parameter :: PLOT_BUTTON_FLAGS = 4096_int32 + 16_int32 + 256_int32 + 1_int32 + 2_int32 + 4_int32 !<
                                                 !< AllowOverlap, PressedOnClick, PressedOnDoubleClick, the buttons.
integer(int32), parameter :: AXIS_BUTTON_FLAGS = PLOT_BUTTON_FLAGS + 2048_int32 !< ... and FlattenChildren.
real(real32),   parameter :: DRAG_THRESHOLD = 5.0_real32       !< MOUSE_CURSOR_DRAG_THRESHOLD.
real(real32),   parameter :: BOX_THRESHOLD = 4.0_real32        !< BOX_SELECT_DRAG_THRESHOLD.
real(real32),   parameter :: ZOOM_RATE = 0.1_real32            !< ImPlotInputMap::ZoomRate.
real(real32),   parameter :: MOUSE_POS_PADDING(2) = [10.0_real32, 10.0_real32] !< MousePosPadding [pixels].
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
! the axes' menu names (ShowAxisContextMenu's "X-Axis", "X-Axis 2", ...), by axis
character(len=8), parameter :: AXIS_NAMES(6) = ['X-Axis  ', 'X-Axis 2', 'X-Axis 3', 'Y-Axis  ', 'Y-Axis 2', &
                                                'Y-Axis 3'] !< Names.
integer(int32),   parameter :: AXIS_NAMES_LEN(6) = [6_int32, 8_int32, 8_int32, 6_int32, 8_int32, 8_int32] !< Lengths.
integer(int32),   parameter :: MOUSE_TEXT_LEN = 256_int32 !< The mouse text's room (six values of 31 characters).

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
   logical        :: hovered = .false.                !< Its button hovered (the pointer over its labels).
   logical        :: held = .false.                   !< ... held (dragged).
   real(real32)   :: hover_rect(4) = 0.0_real32       !< Its button's rectangle (HoverRect).
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
   logical                       :: hovered = .false.     !< The plot area's button hovered.
   logical                       :: held = .false.        !< ... held (panned).
   logical                       :: selecting = .false.   !< A box being dragged (Selecting).
   logical                       :: selected = .false.    !< ... and drawn (Selected).
   logical                       :: context_locked = .false. !< A drag ended the right click (no menu).
   real(real32)                  :: select_start(2) = 0.0_real32 !< Where the box started [pixels].
   real(real32)                  :: select_rect(4) = 0.0_real32  !< The box, relative to the plot rectangle.
   type(plot_axis)               :: ax(AXES)              !< Axes: X1, X2, X3, Y1, Y2, Y3.
   integer(int32)                :: cur_x = AX_X1         !< The x axis the items use (CurrentX).
   integer(int32)                :: cur_y = AX_Y1         !< ... the y axis.
   integer(int32)                :: colormap_idx = 0_int32 !< Automatic colours given (ColormapIdx).
   integer(int32)                :: marker_idx = 0_int32  !< Automatic markers given (MarkerIdx).
   integer(int32)                :: n_items = 0_int32     !< Items held.
   integer(int32)                :: item_next = 1_int32   !< Where the search for the next item starts.
   integer(int32), allocatable   :: item_id(:)            !< Item's ID.
   integer(int32), allocatable   :: item_color(:)         !< ... colour (packed).
   integer(int32), allocatable   :: item_frame(:)         !< ... the frame it was last drawn on.
   logical,        allocatable   :: item_show(:)          !< ... shown (Show).
   logical,        allocatable   :: item_hovered(:)       !< ... its legend entry hovered (LegendHovered).
   integer(int32), allocatable   :: item_marker(:)        !< ... its marker (ImPlotMarker; -2 none).
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

type :: plot_item_ctx
   !< The open plot as an item sees it after `pf_item_begin` (figure_plot_items): the item's colour and marker, its
   !< legend entry hovered (the items' highlight), whether the plot fits on this frame, the plot rectangle, the current
   !< axes' maps and ranges.
   integer(int32)      :: color = 0_int32         !< The item's colour (packed).
   integer(int32)      :: marker = -2_int32       !< Its marker (ImPlotMarker).
   logical             :: hovered = .false.       !< Its legend entry hovered, items highlighted (not NoHighlightItem).
   logical             :: fit = .false.           !< The plot fits on this frame (FitThisFrame).
   real(real32)        :: rect(4) = 0.0_real32    !< Plot rectangle [pixels].
   type(plot_axis_map) :: tx                      !< The current x axis's map.
   type(plot_axis_map) :: ty                      !< The current y axis's map.
   real(real64)        :: x_range(2) = 0.0_real64 !< The current x axis's range.
   real(real64)        :: y_range(2) = 0.0_real64 !< The current y axis's range.
   real(real32)        :: x_pix(2) = 0.0_real32   !< The current x axis's PixelMin, PixelMax.
   real(real32)        :: y_pix(2) = 0.0_real32   !< The current y axis's PixelMin, PixelMax.
   logical             :: x_inv = .false.         !< The current x axis inverted.
   logical             :: y_inv = .false.         !< The current y axis inverted.
endtype plot_item_ctx

type(plot_record), allocatable, target :: plots(:)       !< The plots (ImPlotContext::Plots).
integer(int32)                         :: n_plots = 0_int32 !< Slots of `plots` in use.
integer(int32)                         :: cur = 0_int32  !< The plot open (0: none).
logical                                :: next_fit(AXES) = .false. !< Axes to fit on the next plot (NextPlotData.Fit).
logical                                :: next_hidden_set = .false. !< The next item's visibility set (HasHidden).
logical                                :: next_hidden = .false. !< ... hidden.
integer(int32)                         :: next_hidden_cond = 0_int32 !< ... its condition.
type(plot_ticks), target               :: ticks(AXES)    !< The open plot's ticks, per axis.
type(plot_ticks)                       :: cticks         !< A colour bar's ticks (CTicker).
character(len=:), allocatable          :: text           !< The open plot's title and axis labels (TextBuffer).
integer(int32)                         :: n_text = 0_int32 !< Characters of `text` in use.
logical                                :: open_context = .false. !< A context menu opens (OpenContextThisFrame).
character(len=MOUSE_TEXT_LEN)          :: mouse_text     !< The mouse text (MousePosStringBuilder).
integer(int32)                         :: digital_offset = 0_int32 !< The digital items' bands (DigitalPlotOffset).

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
   call cm_style_refresh() ! the style's line colours, if they changed (set_style)
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
   if (present(location)) loc = location_code(location) ! (select case ignores trailing blanks)
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

   subroutine pf_end_plot()
   !< End the plot (`EndPlot`): the title, the tick marks, the selection, the crosshairs, the mouse text, the legend and
   !< the border; then the fit of the axes that fit on this frame (shown from the next one) and the context menus.

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
      call overlays(p)
      call side_switch(p)
      call legend(p)
      if (border_shown(p)) call core_draw_rect(real(p%rect(1), real64), real(p%rect(2), real64),        &
                                               real(p%rect(3), real64), real(p%rect(4), real64), p%col_border, &
                                               rounding=0.0_real64, thickness=real(PLOT_BORDER_SIZE, real64))
      call core_draw_end()
      call fit_axes(p)
      call context_menus(p)
      p%initialized = .true.
      call core_pop_id() ! the items' IDs (PushOverrideID of SetupFinish)
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

   function pf_colormap(name, levels) result(id)
   !< A colormap's id by name (`ip_colormap`): ImPlot's maps, FIGURE's bundled ones, `<name>_r` reversed, cut into
   !< `levels` bands (2-256); -1 for an unknown name (figure_plot_colormaps).
   character(len=*), intent(in)           :: name   !< Name.
   integer(int32),   intent(in), optional :: levels !< Bands (0: continuous).
   integer(int32)                         :: id     !< Id.

   id = cm_colormap(trim(name), levels)
   endfunction pf_colormap

   subroutine pf_colormap_scale(label, scale_min, scale_max, width, height, label_format, colormap)
   !< A colour bar for [scale_min, scale_max] (`ColormapScale`; `ip_colormap_scale`), outside a plot: `width` x
   !< `height` pixels (0 or absent: ImPlot's, the bar 20 pixels wide and the default plot height; negative: the room
   !< left less it), the colormap `colormap` (default Viridis), its ticks by the linear locator labelled by
   !< `label_format` (default "%g") right of the bar, `label` rotated beyond them ('##...': none). The bar's top is
   !< `scale_max` (`scale_min` > `scale_max` turns it over).
   character(len=*), intent(in)           :: label        !< Label (also the item's ID).
   real(real64),     intent(in)           :: scale_min    !< Value at the bottom.
   real(real64),     intent(in)           :: scale_max    !< Value at the top.
   real(real64),     intent(in), optional :: width        !< Width [pixels].
   real(real64),     intent(in), optional :: height       !< Height [pixels].
   character(len=*), intent(in), optional :: label_format !< printf format of the tick labels.
   integer(int32),   intent(in), optional :: colormap     !< Colormap (`pf_colormap`).
   integer(int32)                         :: cm           !< The map.
   integer(int32)                         :: id, k        !< The item's ID, counter.
   real(real32)                           :: req(2), fs(2) !< Size asked, the frame's size.
   real(real32)                           :: lw, lh       !< The label's size.
   real(real32)                           :: pad, bar_w, txt_off !< Paddings, the bar's width.
   real(real32)                           :: fr(4), gr(4) !< The frame, the bar.
   real(real32)                           :: y_min, y_max, y_pos, tick_w, tick_k, txt_x, txt_y !< Ticks.
   real(real32)                           :: tick_t       !< A tick's place in the map.
   real(real64)                           :: cx, cy, aw, ah, w, h, rmin, rmax !< Cursor, room, sizes, range.
   logical                                :: rend_label, reversed !< A label shown, the range turned over.
   integer(int32)                         :: col_text     !< Text colour.
   type(plot_format)                      :: fmt          !< The labels' format, parsed ("%g" unless given).

   cm = CM_VIRIDIS
   if (present(colormap)) cm = colormap
   id = core_get_id(label)
   call core_text_size(label, w, h, hide_after_hash=.true.)
   lw = real(w, real32)
   lh = real(h, real32)
   req = 0.0_real32
   if (present(width)) req(1) = real(width, real32)
   if (present(height)) req(2) = real(height, real32)
   fs = req ! CalcItemSize(size, 0, PlotDefaultSize.y)
   aw = 0.0_real64
   ah = 0.0_real64
   if (req(1) < 0.0_real32 .or. req(2) < 0.0_real32) call core_content_region_avail(aw, ah)
   if (req(1) < 0.0_real32) fs(1) = max(4.0_real32, real(aw, real32) + req(1))
   if (req(2) == 0.0_real32) then
      fs(2) = PLOT_DEFAULT_SIZE(2)
   elseif (req(2) < 0.0_real32) then
      fs(2) = max(4.0_real32, real(ah, real32) + req(2))
   endif
   if (fs(2) < PLOT_MIN_SIZE(2) .and. req(2) < 0.0_real32) fs(2) = PLOT_MIN_SIZE(2)
   rmin = merge(scale_min, scale_max, scale_min < scale_max)
   rmax = merge(scale_min, scale_max, scale_min >= scale_max)
   call ticks_reset(cticks)
   if (present(label_format)) call fmt_parse(label_format, fmt)
   call locate_default(cticks, rmin, rmax, fs(2), .true., measure_text, fmt)
   rend_label = lw > 0.0_real32
   txt_off = LABEL_PADDING(1)
   pad = (txt_off + cticks%max_size(1)) + merge(txt_off + lh, 0.0_real32, rend_label)
   bar_w = 20.0_real32
   if (fs(1) == 0.0_real32) then
      fs(1) = (bar_w + pad) + 2.0_real32 * PLOT_PADDING(1)
   else
      bar_w = fs(1) - (pad + 2.0_real32 * PLOT_PADDING(1))
      if (bar_w < MAJOR_TICK_LEN(2)) bar_w = MAJOR_TICK_LEN(2)
   endif
   call core_cursor_screen_pos(cx, cy)
   fr = [real(cx, real32), real(cy, real32), real(cx, real32) + fs(1), real(cy, real32) + fs(2)]
   call core_item_size(real(fs(1), real64), real(fs(2), real64))
   if (.not. core_item_add(real(fr(1), real64), real(fr(2), real64), real(fr(3), real64), real(fr(4), real64), id)) &
      return
   call core_draw_begin()
   call render_frame(fr)
   reversed = scale_min > scale_max
   gr = [(fr(1) + PLOT_PADDING(1)) + 0.0_real32, (fr(2) + PLOT_PADDING(2)) + 0.0_real32, &
         fr(1) + ((bar_w + PLOT_PADDING(1)) + 0.0_real32), fr(2) + (fs(2) - PLOT_PADDING(2))]
   call core_push_clip_rect(real(fr(1), real64), real(fr(2), real64), real(fr(3), real64), real(fr(4), real64))
   col_text = core_style_color(ImGuiCol_Text)
   y_min = merge(gr(4), gr(2), reversed)
   y_max = merge(gr(2), gr(4), reversed)
   call color_bar(cm, gr)
   do k = 1_int32, cticks%n
      y_pos = y_min + ((real(cticks%pos(k), real32) - real(rmax, real32)) * (y_max - y_min)) / &
                      (real(rmin, real32) - real(rmax, real32)) ! ImRemap
      tick_w = merge(MAJOR_TICK_LEN(2), MINOR_TICK_LEN(2), cticks%major(k))
      tick_k = merge(MAJOR_TICK_SIZE(2), MINOR_TICK_SIZE(2), cticks%major(k))
      tick_t = real((cticks%pos(k) - scale_min) / (scale_max - scale_min), real32)
      if (y_pos < gr(4) - 2.0_real32 .and. y_pos > gr(2) + 2.0_real32) &
         call core_draw_line_h(real(gr(3) - 1.0_real32, real64), real(gr(3) - tick_w, real64), real(y_pos, real64), &
                               text_color(cm_sample(cm, tick_t)), real(tick_k, real64))
      txt_x = gr(3) + txt_off
      txt_y = y_pos - cticks%label_size(2, k) * 0.5_real32
      call core_draw_text(real(txt_x, real64), real(txt_y, real64), col_text, cticks%label(k)(1:cticks%label_len(k)))
   enddo
   if (rend_label) call text_vertical((gr(3) + 2.0_real32 * txt_off) + cticks%max_size(1), &
                                      (gr(2) + gr(4)) * 0.5_real32 + lw * 0.5_real32, col_text, &
                                      label(1:rendered_len(label)))
   call core_draw_rect(real(gr(1), real64), real(gr(2), real64), real(gr(3), real64), real(gr(4), real64), &
                       core_style_color(ImGuiCol_Border))
   call core_pop_clip_rect()
   call core_draw_end()
   endsubroutine pf_colormap_scale

   ! the queries (ip_plot_hovered, ip_plot_mouse, ip_plot_to_pixels, ip_pixels_to_plot, ip_plot_selection)

   function pf_plot_hovered() result(hovered)
   !< The pointer is over the plot area on this frame (`IsPlotHovered`; `ip_plot_hovered`). It ends the setup.
   logical :: hovered !< Hovered.

   if (cur == 0_int32) error stop 'figure_plot_frame: pf_plot_hovered outside a plot'
   if (.not. plots(cur)%locked) call setup_finish(plots(cur))
   hovered = plots(cur)%hovered
   endfunction pf_plot_hovered

   subroutine pf_plot_mouse(x, y, xaxis, yaxis)
   !< The pointer's position in plot units (`GetPlotMousePos`; `ip_plot_mouse`) on the current axes or on
   !< `xaxis`/`yaxis`; -huge for both without a pointer. It ends the setup.
   real(real64),     intent(out)          :: x, y         !< Position.
   character(len=*), intent(in), optional :: xaxis, yaxis !< Axes.
   integer(int32)                         :: ix, iy       !< Axes.
   real(real64)                           :: mx, my       !< The pointer [pixels].

   call query_axes('pf_plot_mouse', xaxis, yaxis, ix, iy)
   if (.not. core_mouse_pos_valid()) then
      x = -huge(1.0_real64)
      y = -huge(1.0_real64)
      return
   endif
   call core_mouse_pos(mx, my)
   x = pixels_to_plot(plots(cur)%ax(ix), real(mx, real32))
   y = pixels_to_plot(plots(cur)%ax(iy), real(my, real32))
   endsubroutine pf_plot_mouse

   subroutine pf_plot_to_pixels(x, y, px, py, xaxis, yaxis)
   !< The display pixel of the plot point (x, y) (`PlotToPixels`; `ip_plot_to_pixels`). It ends the setup.
   real(real64),     intent(in)           :: x, y         !< Point.
   real(real64),     intent(out)          :: px, py       !< Pixel.
   character(len=*), intent(in), optional :: xaxis, yaxis !< Axes.
   integer(int32)                         :: ix, iy       !< Axes.

   call query_axes('pf_plot_to_pixels', xaxis, yaxis, ix, iy)
   px = real(to_pixels(plots(cur)%ax(ix), x), real64)
   py = real(to_pixels(plots(cur)%ax(iy), y), real64)
   endsubroutine pf_plot_to_pixels

   subroutine pf_pixels_to_plot(px, py, x, y, xaxis, yaxis)
   !< The plot point at the display pixel (px, py) (`PixelsToPlot`, float pixels; `ip_pixels_to_plot`). It ends the
   !< setup.
   real(real64),     intent(in)           :: px, py       !< Pixel.
   real(real64),     intent(out)          :: x, y         !< Point.
   character(len=*), intent(in), optional :: xaxis, yaxis !< Axes.
   integer(int32)                         :: ix, iy       !< Axes.

   call query_axes('pf_pixels_to_plot', xaxis, yaxis, ix, iy)
   x = pixels_to_plot(plots(cur)%ax(ix), real(px, real32))
   y = pixels_to_plot(plots(cur)%ax(iy), real(py, real32))
   endsubroutine pf_pixels_to_plot

   function pf_plot_selection(xmin, xmax, ymin, ymax, xaxis, yaxis) result(selected)
   !< The box the user is dragging with the right button (`IsPlotSelected`, `GetPlotSelection`; `ip_plot_selection`):
   !< true while it is drawn, its extent in plot units (0 otherwise). It ends the setup.
   real(real64),     intent(out)          :: xmin, xmax, ymin, ymax !< Extent.
   character(len=*), intent(in), optional :: xaxis, yaxis !< Axes.
   logical                                :: selected     !< A box.
   integer(int32)                         :: ix, iy       !< Axes.
   real(real64)                           :: x1, x2, y1, y2 !< Its corners.

   call query_axes('pf_plot_selection', xaxis, yaxis, ix, iy)
   xmin = 0.0_real64
   xmax = 0.0_real64
   ymin = 0.0_real64
   ymax = 0.0_real64
   associate(p => plots(cur))
      selected = p%selected
      if (.not. selected) return
      x1 = pixels_to_plot(p%ax(ix), p%select_rect(1) + p%rect(1))
      y1 = pixels_to_plot(p%ax(iy), p%select_rect(2) + p%rect(2))
      x2 = pixels_to_plot(p%ax(ix), p%select_rect(3) + p%rect(1))
      y2 = pixels_to_plot(p%ax(iy), p%select_rect(4) + p%rect(2))
      xmin = merge(x1, x2, x1 < x2)
      xmax = merge(x1, x2, x1 >= x2)
      ymin = merge(y1, y2, y1 < y2)
      ymax = merge(y1, y2, y1 >= y2)
   endassociate
   endfunction pf_plot_selection

   subroutine pf_cancel_selection()
   !< End the box the user is dragging without the zoom of its release (`CancelPlotSelection`; `ip_cancel_selection`).
   !< It ends the setup.

   if (cur == 0_int32) error stop 'figure_plot_frame: pf_cancel_selection outside a plot'
   associate(p => plots(cur))
      if (.not. p%locked) call setup_finish(p)
      if (p%selected) then
         p%selected = .false.
         p%selecting = .false.
      endif
   endassociate
   endsubroutine pf_cancel_selection

   subroutine query_axes(name, xaxis, yaxis, ix, iy)
   !< A query's axes (the current ones or those named, enabled), the setup ended.
   character(len=*), intent(in)           :: name         !< The procedure called.
   character(len=*), intent(in), optional :: xaxis, yaxis !< Axes.
   integer(int32),   intent(out)          :: ix, iy       !< Axes.

   if (cur == 0_int32) then
      write(*, '(A)') 'figure_plot_frame: '//name//' outside a plot'
      error stop 1
   endif
   associate(p => plots(cur))
      if (.not. p%locked) call setup_finish(p)
      ix = p%cur_x
      iy = p%cur_y
      if (present(xaxis)) ix = axis_code(xaxis)
      if (present(yaxis)) iy = axis_code(yaxis)
   endassociate
   endsubroutine query_axes

   ! private: the input (UpdateInput)

   subroutine update_input(p)
   !< `UpdateInput`: the plot's and the axes' buttons; a box started by a right click, a fit by a double click; the
   !< context menu's latch; the pan of the held axes by the mouse's delta; the wheel's zoom about the pointer on the
   !< hovered axes; the box: confirmed (the zoom), cancelled, or drawn.
   type(plot_record), intent(inout) :: p          !< Plot.
   real(real64)   :: dx, dy, wheel, wheel_h, dmax(5), mx, my, sdx, sdy, pdx, pdy !< Input.
   integer(int32) :: mods                         !< Key mods.
   logical        :: dnd                          !< A drag and drop.
   logical        :: clicked, can_pan, any_x_hov, any_y_hov, any_x_held, any_y_held, any_hov, any_held !< State.
   logical        :: selecting, panning, equal, increasing, full_w, full_h, x_can, y_can !< ...
   logical        :: x_hov(AXES), x_held(AXES)    !< Each axis hovered or held (with the plot's).
   real(real32)   :: delta(2), mouse(2), rate, tx, ty, size_(2), w, sel_sq, pan_sq, d(2), a, b !< Pixels.
   real(real64)   :: lo, hi                       !< Plot units.
   integer(int32) :: i, o, dir, eq_ref            !< Axis, its pair, drag direction, equal's reference axis.

   equal = has_flag(p%flags, PF_EQUAL)
   call core_io_input(dx, dy, wheel, wheel_h, dmax, mods, dnd)
   call core_mouse_pos(mx, my)
   delta = [real(dx, real32), real(dy, real32)]
   mouse = [real(mx, real32), real(my, real32)]
   clicked = core_button_behavior(real(p%rect(1), real64), real(p%rect(2), real64), real(p%rect(3), real64), &
                                  real(p%rect(4), real64), p%id, p%hovered, p%held, flags=PLOT_BUTTON_FLAGS)
   if (clicked) then
      if (.not. has_flag(p%flags, PF_NO_BOX_SELECT) .and. core_mouse_clicked(BTN_SELECT)) then
         p%selecting = .true.
         p%select_start = mouse
         p%select_rect = 0.0_real32
      endif
      if (core_mouse_double_clicked(BTN_FIT)) then
         p%fit = .true.
         p%ax(:)%fit = .true.
      endif
   endif
   can_pan = core_mouse_down(BTN_PAN)
   p%held = p%held .and. can_pan
   x_hov = .false.
   x_held = .false.
   do i = 1_int32, AXES
      if (.not. p%ax(i)%enabled) cycle
      associate(ax => p%ax(i))
         call core_keep_alive(plot_id_offset(p%id, i))
         clicked = core_button_behavior(real(ax%hover_rect(1), real64), real(ax%hover_rect(2), real64), &
                                        real(ax%hover_rect(3), real64), real(ax%hover_rect(4), real64), &
                                        plot_id_offset(p%id, i), ax%hovered, ax%held, flags=AXIS_BUTTON_FLAGS)
         if (clicked .and. core_mouse_double_clicked(BTN_FIT)) then
            p%fit = .true.
            ax%fit = .true.
         endif
         ax%held = ax%held .and. can_pan
         x_hov(i) = ax%hovered .or. p%hovered
         x_held(i) = ax%held .or. p%held
      endassociate
   enddo
   if (dnd .or. mods == ImGuiMod_Ctrl) return ! OverrideMod: no input
   any_x_hov = p%hovered .or. any(p%ax(AX_X1:AX_X3)%enabled .and. p%ax(AX_X1:AX_X3)%hovered)
   any_y_hov = p%hovered .or. any(p%ax(AX_Y1:AX_Y3)%enabled .and. p%ax(AX_Y1:AX_Y3)%hovered)
   any_x_held = p%held .or. any(p%ax(AX_X1:AX_X3)%enabled .and. p%ax(AX_X1:AX_X3)%held)
   any_y_held = p%held .or. any(p%ax(AX_Y1:AX_Y3)%enabled .and. p%ax(AX_Y1:AX_Y3)%held)
   any_hov = any_x_hov .or. any_y_hov
   any_held = any_x_held .or. any_y_held
   call core_mouse_drag_delta(BTN_SELECT, sdx, sdy)
   call core_mouse_drag_delta(BTN_PAN, pdx, pdy)
   a = real(sdx, real32) * real(sdx, real32)
   b = real(sdy, real32) * real(sdy, real32)
   sel_sq = a + b
   a = real(pdx, real32) * real(pdx, real32)
   b = real(pdy, real32) * real(pdy, real32)
   pan_sq = a + b
   selecting = p%selecting .and. sel_sq > DRAG_THRESHOLD
   panning = any_held .and. pan_sq > DRAG_THRESHOLD
   ! the context menu
   if (core_mouse_released(BTN_MENU) .and. .not. p%context_locked) open_context = .true.
   if (selecting .or. panning) then
      p%context_locked = .true.
   elseif (.not. (core_mouse_down(BTN_MENU) .or. core_mouse_released(BTN_MENU))) then
      p%context_locked = .false.
   endif
   ! the pan
   if (any_held .and. .not. p%selecting) then
      dir = 0_int32
      do i = AX_X1, AX_X3
         associate(ax => p%ax(i))
            if (.not. (x_held(i) .and. .not. input_locked(ax))) cycle
            dir = ior(dir, 2_int32)
            increasing = merge(delta(1) > 0.0_real32, delta(1) < 0.0_real32, has_flag(ax%flags, AXF_INVERT))
            if (delta(1) /= 0.0_real32 .and. .not. pan_locked(ax, increasing)) then
               lo = pixels_to_plot(ax, p%rect(1) - delta(1))
               hi = pixels_to_plot(ax, p%rect(3) - delta(1))
               call pan_to(ax, lo, hi)
               o = ax%ortho
               if (equal .and. o /= 0_int32) call set_aspect(p%ax(o), get_aspect(ax))
            endif
         endassociate
      enddo
      do i = AX_Y1, AX_Y3
         associate(ax => p%ax(i))
            if (.not. (x_held(i) .and. .not. input_locked(ax))) cycle
            dir = ior(dir, 4_int32)
            increasing = merge(delta(2) < 0.0_real32, delta(2) > 0.0_real32, has_flag(ax%flags, AXF_INVERT))
            if (delta(2) /= 0.0_real32 .and. .not. pan_locked(ax, increasing)) then
               lo = pixels_to_plot(ax, p%rect(4) - delta(2)) ! bottom
               hi = pixels_to_plot(ax, p%rect(2) - delta(2)) ! top
               call pan_to(ax, lo, hi)
               o = ax%ortho
               if (equal .and. o /= 0_int32) call set_aspect(p%ax(o), get_aspect(ax))
            endif
         endassociate
      enddo
      if (dmax(BTN_PAN + 1_int32) > real(DRAG_THRESHOLD, real64)) then
         select case (dir)
         case (0_int32)
            call core_set_mouse_cursor(ImGuiMouseCursor_NotAllowed)
         case (2_int32)
            call core_set_mouse_cursor(ImGuiMouseCursor_ResizeEW)
         case (4_int32)
            call core_set_mouse_cursor(ImGuiMouseCursor_ResizeNS)
         case default
            call core_set_mouse_cursor(ImGuiMouseCursor_ResizeAll)
         endselect
      endif
   endif
   ! the wheel's zoom (ZoomMod: none)
   if (any_hov) then
      rate = ZOOM_RATE
      if (wheel == 0.0_real64) then
         rate = 0.0_real32
      elseif (wheel > 0.0_real64) then
         rate = (-ZOOM_RATE) / (1.0_real32 + (2.0_real32 * ZOOM_RATE))
      endif
      size_ = [p%rect(3) - p%rect(1), p%rect(4) - p%rect(2)]
      tx = ((mouse(1) - p%rect(1)) * (1.0_real32 - 0.0_real32)) / (p%rect(3) - p%rect(1)) + 0.0_real32 ! ImRemap
      ty = ((mouse(2) - p%rect(2)) * (1.0_real32 - 0.0_real32)) / (p%rect(4) - p%rect(2)) + 0.0_real32
      eq_ref = 0_int32
      do i = AX_X1, AX_X3
         associate(ax => p%ax(i))
            o = ax%ortho
            if (.not. x_hov(i) .or. input_locked(ax)) cycle
            if (equal .and. o /= 0_int32) then
               if (input_locked(p%ax(o))) cycle
            endif
            call core_set_key_owner(ImGuiKey_MouseWheelY, p%id)
            if (rate /= 0.0_real32) then
               w = size_(1) * tx
               w = w * rate
               lo = pixels_to_plot(ax, p%rect(1) - w)
               w = size_(1) * (1.0_real32 - tx)
               w = w * rate
               hi = pixels_to_plot(ax, p%rect(3) + w)
               call pan_to(ax, lo, hi)
               if (equal .and. o /= 0_int32) eq_ref = i
            endif
         endassociate
      enddo
      do i = AX_Y1, AX_Y3
         associate(ax => p%ax(i))
            o = ax%ortho
            if (.not. x_hov(i) .or. input_locked(ax)) cycle
            if (equal .and. o /= 0_int32) then
               if (input_locked(p%ax(o))) cycle
            endif
            call core_set_key_owner(ImGuiKey_MouseWheelY, p%id)
            if (rate /= 0.0_real32) then
               w = size_(2) * ty
               w = w * rate
               hi = pixels_to_plot(ax, p%rect(2) - w) ! top
               w = size_(2) * (1.0_real32 - ty)
               w = w * rate
               lo = pixels_to_plot(ax, p%rect(4) + w) ! bottom
               call pan_to(ax, lo, hi)
               if (equal .and. o /= 0_int32) eq_ref = i
            endif
         endassociate
      enddo
      if (eq_ref /= 0_int32) then
         o = p%ax(eq_ref)%ortho
         if (o /= 0_int32) call set_aspect(p%ax(o), get_aspect(p%ax(eq_ref)))
      endif
   endif
   ! the box
   if (p%selecting) then
      d = p%select_start - mouse
      x_can = .not. has_flag(mods, ImGuiMod_Alt) .and. abs(d(1)) > 2.0_real32
      y_can = .not. has_flag(mods, ImGuiMod_Shift) .and. abs(d(2)) > 2.0_real32
      if (core_mouse_released(BTN_SELECT)) then ! confirmed: the zoom
         do i = AX_X1, AX_X3
            if (input_locked(p%ax(i)) .or. .not. x_can) cycle
            lo = pixels_to_plot(p%ax(i), p%select_start(1))
            hi = pixels_to_plot(p%ax(i), mouse(1))
            call box_to(p%ax(i), lo, hi)
         enddo
         do i = AX_Y1, AX_Y3
            if (input_locked(p%ax(i)) .or. .not. y_can) cycle
            lo = pixels_to_plot(p%ax(i), p%select_start(2))
            hi = pixels_to_plot(p%ax(i), mouse(2))
            call box_to(p%ax(i), lo, hi)
         enddo
         if (x_can .or. y_can .or. (has_flag(mods, ImGuiMod_Alt) .and. has_flag(mods, ImGuiMod_Shift))) &
            open_context = .false.
         p%selected = .false.
         p%selecting = .false.
      elseif (core_mouse_released(BTN_SELECT_CANCEL)) then
         p%selected = .false.
         p%selecting = .false.
         open_context = .false.
      else
         a = d(1) * d(1)
         b = d(2) * d(2)
         if (a + b > BOX_THRESHOLD) then
            if (all_locked(p, AX_X1, AX_Y3)) then ! a bad selection
               call core_set_mouse_cursor(ImGuiMouseCursor_NotAllowed)
               open_context = .false.
               p%selected = .false.
            else
               full_w = has_flag(mods, ImGuiMod_Alt) .or. all_locked(p, AX_X1, AX_X3)
               full_h = has_flag(mods, ImGuiMod_Shift) .or. all_locked(p, AX_Y1, AX_Y3)
               p%select_rect(1) = merge(p%rect(1), min(p%select_start(1), mouse(1)), full_w)
               p%select_rect(3) = merge(p%rect(3), max(p%select_start(1), mouse(1)), full_w)
               p%select_rect(2) = merge(p%rect(2), min(p%select_start(2), mouse(2)), full_h)
               p%select_rect(4) = merge(p%rect(4), max(p%select_start(2), mouse(2)), full_h)
               p%select_rect(1:3:2) = p%select_rect(1:3:2) - p%rect(1)
               p%select_rect(2:4:2) = p%select_rect(2:4:2) - p%rect(2)
               p%selected = .true.
            endif
         else
            p%selected = .false.
         endif
      endif
   endif
   endsubroutine update_input

   subroutine pan_to(ax, v_min, v_max)
   !< A pan's or a zoom's new ends (`SetMin`, `SetMax`, an inverted axis's swapped).
   type(plot_axis), intent(inout) :: ax           !< Axis.
   real(real64),    intent(in)    :: v_min, v_max !< The ends at the pixel minimum and maximum.
   logical                        :: done         !< Set.

   if (has_flag(ax%flags, AXF_INVERT)) then
      done = set_min(ax, v_max, .false.)
      done = set_max(ax, v_min, .false.)
   else
      done = set_min(ax, v_min, .false.)
      done = set_max(ax, v_max, .false.)
   endif
   endsubroutine pan_to

   subroutine box_to(ax, p1, p2)
   !< A box's zoom on an axis: `SetMin(ImMin(p1, p2))`, `SetMax(ImMax(p1, p2))`.
   type(plot_axis), intent(inout) :: ax     !< Axis.
   real(real64),    intent(in)    :: p1, p2 !< The box's ends.
   logical                        :: done   !< Set.

   done = set_min(ax, merge(p1, p2, p1 < p2), .false.)
   done = set_max(ax, merge(p1, p2, p1 >= p2), .false.)
   endsubroutine box_to

   function set_min(ax, v, force) result(done)
   !< `ImPlotAxis::SetMin`: the minimum, unless locked (not forced), constrained; refused if not below the maximum.
   type(plot_axis), intent(inout) :: ax    !< Axis.
   real(real64),    intent(in)    :: v     !< New minimum.
   logical,         intent(in)    :: force !< Even locked.
   logical                        :: done  !< Set.
   real(real64)                   :: m, z  !< The minimum, the range.

   done = .false.
   if (.not. force .and. locked_min(ax)) return
   m = constrain_nan(constrain_inf(v))
   if (m < ax%con_min) m = ax%con_min
   z = ax%range_max - m
   if (z < tiny(1.0_real64)) m = ax%range_max - tiny(1.0_real64)
   if (m >= ax%range_max) return
   ax%range_min = m
   call update_scale(ax)
   done = .true.
   endfunction set_min

   function set_max(ax, v, force) result(done)
   !< `ImPlotAxis::SetMax`: the maximum, unless locked (not forced), constrained; refused if not above the minimum.
   type(plot_axis), intent(inout) :: ax    !< Axis.
   real(real64),    intent(in)    :: v     !< New maximum.
   logical,         intent(in)    :: force !< Even locked.
   logical                        :: done  !< Set.
   real(real64)                   :: m, z  !< The maximum, the range.

   done = .false.
   if (.not. force .and. locked_max(ax)) return
   m = constrain_nan(constrain_inf(v))
   if (m > ax%con_max) m = ax%con_max
   z = m - ax%range_min
   if (z < tiny(1.0_real64)) m = ax%range_min + tiny(1.0_real64)
   if (m <= ax%range_min) return
   ax%range_max = m
   call update_scale(ax)
   done = .true.
   endfunction set_max

   pure function input_locked(ax) result(yes)
   !< `IsInputLocked`: both ends locked, or fit every frame.
   type(plot_axis), intent(in) :: ax  !< Axis.
   logical                     :: yes !< Locked.

   yes = (locked_min(ax) .and. locked_max(ax)) .or. auto_fitting(ax)
   endfunction input_locked

   pure function pan_locked(ax, increasing) result(yes)
   !< `IsPanLocked`: a pan towards the constraint's end, the axis at it.
   type(plot_axis), intent(in) :: ax         !< Axis.
   logical,         intent(in) :: increasing !< Towards larger values.
   logical                     :: yes        !< Locked.

   if (has_flag(ax%flags, AXF_PAN_STRETCH)) then
      yes = input_locked(ax)
   elseif (locked_min(ax) .or. locked_max(ax) .or. auto_fitting(ax)) then
      yes = .false.
   elseif (increasing) then
      yes = ax%range_max == ax%con_max
   else
      yes = ax%range_min == ax%con_min
   endif
   endfunction pan_locked

   pure function all_locked(p, i0, i1) result(yes)
   !< The enabled axes i0 .. i1 all input-locked (`AllAxesInputLocked`; all six: `ImPlotPlot::IsInputLocked`, a
   !< disabled axis counting as locked).
   type(plot_record), intent(in) :: p      !< Plot.
   integer(int32),    intent(in) :: i0, i1 !< Axes.
   logical                       :: yes    !< Locked.
   integer(int32)                :: i      !< Axis.

   yes = .true.
   do i = i0, i1
      if (p%ax(i)%enabled .and. .not. input_locked(p%ax(i))) yes = .false.
   enddo
   endfunction all_locked

   function pixels_to_plot(ax, pix) result(v)
   !< `ImPlotAxis::PixelsToPlot`: the value at a pixel (float), through the inverse transform on a log10 or symlog axis.
   type(plot_axis), intent(in) :: ax  !< Axis.
   real(real32),    intent(in) :: pix !< Pixel.
   real(real64)                :: v   !< Value.
   real(real64)                :: t, s !< Fraction, transformed value.

   v = real(pix - ax%pixel_min, real64) / ax%scale_to_pixel + ax%range_min
   if (ax%scale == SCALE_LOG10 .or. ax%scale == SCALE_SYMLOG) then
      t = (v - ax%range_min) / (ax%range_max - ax%range_min)
      s = t * (ax%scale_max - ax%scale_min)
      s = s + ax%scale_min
      if (ax%scale == SCALE_LOG10) then
         v = inverse_log10(s)
      else
         v = inverse_symlog(s)
      endif
   endif
   endfunction pixels_to_plot

   ! private: the overlays of EndPlot

   subroutine overlays(p)
   !< `EndPlot` under the plot's clip: the selection (`RenderSelectionRect`), the crosshairs, the mouse text.
   type(plot_record), intent(inout) :: p           !< Plot.
   real(real64)                     :: mx, my, w, h !< The pointer, a text's size.
   real(real32)                     :: m(2), pos(2), sz(2), sr(4) !< ..., the box on screen.
   integer(int32)                   :: col, i      !< Colour, axis.
   logical                          :: any_held    !< An axis or the plot held.
   integer(int32)                   :: n           !< The mouse text's length.

   call core_push_clip_rect(real(p%rect(1), real64), real(p%rect(2), real64), real(p%rect(3), real64), &
                            real(p%rect(4), real64))
   call core_mouse_pos(mx, my)
   m = [real(mx, real32), real(my, real32)]
   if (p%selected) then ! Selection: (1, 1, 0), its fill at 1/4 alpha
      sr = [p%select_rect(1) + p%rect(1), p%select_rect(2) + p%rect(2), p%select_rect(3) + p%rect(1), &
            p%select_rect(4) + p%rect(2)]
      call core_draw_rect_filled(real(sr(1), real64), real(sr(2), real64), real(sr(3), real64), real(sr(4), real64), &
                                 core_color(1.0_real64, 1.0_real64, 0.0_real64, 0.25_real64))
      call core_draw_rect(real(sr(1), real64), real(sr(2), real64), real(sr(3), real64), real(sr(4), real64), &
                          core_color(1.0_real64, 1.0_real64, 0.0_real64, 1.0_real64))
   endif
   any_held = p%held .or. any(p%ax(:)%enabled .and. p%ax(:)%held)
   if (has_flag(p%flags, PF_CROSSHAIRS) .and. p%hovered .and. .not. any_held .and. .not. p%selecting .and. &
       .not. p%leg_hovered) then
      call core_set_mouse_cursor(ImGuiMouseCursor_None)
      col = p%col_border ! Crosshairs: PlotBorder
      call core_draw_line_h(real(p%rect(1), real64), real(m(1) - 5.0_real32, real64), real(m(2), real64), col)
      call core_draw_line_h(real(m(1) + 5.0_real32, real64), real(p%rect(3), real64), real(m(2), real64), col)
      call core_draw_line_v(real(m(1), real64), real(p%rect(2), real64), real(m(2) - 5.0_real32, real64), col)
      call core_draw_line_v(real(m(1), real64), real(m(2) + 5.0_real32, real64), real(p%rect(4), real64), col)
   endif
   if (.not. has_flag(p%flags, PF_NO_MOUSE_TEXT) .and. (p%hovered .or. p%held .or. p%selecting)) then
      n = 0_int32
      do i = AX_X1, AX_X3
         if (.not. p%ax(i)%enabled) cycle
         if (i > AX_X1) call fmt_text(mouse_text, n, ', (')
         call axis_value_label(p, i, pixels_to_plot(p%ax(i), m(1)), mouse_text, n)
         if (i > AX_X1) call fmt_text(mouse_text, n, ')')
      enddo
      call fmt_text(mouse_text, n, ', ')
      do i = AX_Y1, AX_Y3
         if (.not. p%ax(i)%enabled) cycle
         if (i > AX_Y1) call fmt_text(mouse_text, n, ', (')
         call axis_value_label(p, i, pixels_to_plot(p%ax(i), m(2)), mouse_text, n)
         if (i > AX_Y1) call fmt_text(mouse_text, n, ')')
      enddo
      call core_text_size(mouse_text(1:n), w, h)
      sz = [real(w, real32), real(h, real32)]
      pos = location_pos(p%rect, sz, LOC_SOUTH + LOC_EAST, MOUSE_POS_PADDING)
      call core_draw_text(real(pos(1), real64), real(pos(2), real64), core_style_color(ImGuiCol_Text), &
                          mouse_text(1:n))
   endif
   call core_pop_clip_rect()
   endsubroutine overlays

   subroutine axis_value_label(p, i, v, s, n)
   !< `LabelAxisValue(axis, v, round=true)`: a time axis's `TimeFormatMouseCursor`; else v rounded to the ticks'
   !< spacing's precision, "%g"; appended to s(1:n).
   type(plot_record), intent(in)    :: p !< Plot.
   integer(int32),    intent(in)    :: i !< Axis.
   real(real64),      intent(in)    :: v !< Value.
   character(len=*),  intent(inout) :: s !< Text.
   integer(int32),    intent(inout) :: n !< Its length.
   real(real64)                     :: spacing !< The first two ticks' distance, or the range.

   if (p%ax(i)%scale == SCALE_TIME) then
      call time_cursor_label(v, p%ax(i)%range_max - p%ax(i)%range_min, p%rect(3) - p%rect(1), s, n)
      return
   endif
   if (ticks(i)%n > 1_int32) then
      spacing = ticks(i)%pos(2) - ticks(i)%pos(1)
   else
      spacing = p%ax(i)%range_max - p%ax(i)%range_min
   endif
   call axis_value_text(v, spacing, s, n)
   endsubroutine axis_value_label

   subroutine side_switch(p)
   !< `EndPlot`'s axis side switch: an axis held over the plot, dragged onto its far edge, changes side.
   type(plot_record), intent(inout) :: p      !< Plot.
   real(real64)                     :: mx, my !< The pointer.
   real(real32)                     :: m(2), r(4) !< ..., the switch's strip.
   integer(int32)                   :: i      !< Axis.
   logical                          :: opp, inside !< On the opposite side, the pointer over the plot.

   if (p%held) return
   call core_mouse_pos(mx, my)
   m = [real(mx, real32), real(my, real32)]
   inside = m(1) >= p%rect(1) .and. m(2) >= p%rect(2) .and. m(1) < p%rect(3) .and. m(2) < p%rect(4)
   if (.not. inside) return
   do i = 1_int32, AXES
      associate(ax => p%ax(i))
         if (has_flag(ax%flags, AXF_NO_SIDE_SWITCH) .or. .not. ax%held) cycle
         opp = has_flag(ax%flags, AXF_OPPOSITE)
         if (i <= AX_X3) then
            if (.not. opp) then
               r = [p%rect(1) - 5.0_real32, p%rect(2) - 5.0_real32, p%rect(3) + 5.0_real32, p%rect(2) + 5.0_real32]
               if (m(2) < p%rect(4) - 10.0_real32) call strip(r)
            else
               r = [p%rect(1) - 5.0_real32, p%rect(4) - 5.0_real32, p%rect(3) + 5.0_real32, p%rect(4) + 5.0_real32]
               if (m(2) > p%rect(2) + 10.0_real32) call strip(r)
            endif
         else
            if (.not. opp) then
               r = [p%rect(3) - 5.0_real32, p%rect(2) - 5.0_real32, p%rect(3) + 5.0_real32, p%rect(4) + 5.0_real32]
               if (m(1) > p%rect(1) + 10.0_real32) call strip(r)
            else
               r = [p%rect(1) - 5.0_real32, p%rect(2) - 5.0_real32, p%rect(1) + 5.0_real32, p%rect(4) + 5.0_real32]
               if (m(1) < p%rect(3) - 10.0_real32) call strip(r)
            endif
         endif
         if (m(1) >= r(1) .and. m(2) >= r(2) .and. m(1) < r(3) .and. m(2) < r(4)) then
            if (opp) then
               ax%flags = iand(ax%flags, not(AXF_OPPOSITE))
            else
               ax%flags = ior(ax%flags, AXF_OPPOSITE)
            endif
         endif
      endassociate
   enddo
   contains
      subroutine strip(q)
      !< The switch's strip (AxisBgHovered).
      real(real32), intent(in) :: q(4) !< Rectangle.

      call core_draw_rect_filled(real(q(1), real64), real(q(2), real64), real(q(3), real64), real(q(4), real64), &
                                 core_style_color(ImGuiCol_ButtonHovered))
      endsubroutine strip
   endsubroutine side_switch

   ! private: the context menus (EndPlot, ShowPlotContextMenu, ShowAxisContextMenu, ShowLegendContextMenu)

   subroutine context_menus(p)
   !< The plot's and the axes' context menus: opened by a right click (without a drag) over the plot or an axis, under
   !< the plot's ID ("##PlotContext", and "##XContext"/"##YContext" under the axis's index).
   type(plot_record), intent(inout) :: p       !< Plot.
   logical                          :: can_ctx !< A menu may open.
   integer(int32)                   :: i, k    !< Axis, index on its direction.

   call core_push_override_id(p%id)
   can_ctx = open_context .and. .not. has_flag(p%flags, PF_NO_MENUS) .and. .not. p%leg_hovered
   if (can_ctx .and. p%hovered) call core_open_popup('##PlotContext')
   if (core_begin_popup('##PlotContext')) then
      call plot_context_menu(p)
      call core_end_popup()
   endif
   do i = 1_int32, AXES
      k = merge(i - AX_X1, i - AX_Y1, i <= AX_X3)
      call core_push_id_int(k)
      if (can_ctx .and. p%ax(i)%hovered .and. .not. has_flag(p%ax(i)%flags, AXF_NO_MENUS)) &
         call core_open_popup(merge('##XContext', '##YContext', i <= AX_X3))
      if (core_begin_popup(merge('##XContext', '##YContext', i <= AX_X3))) then
         if (has_label(p%ax(i))) then
            call core_text_unformatted(text(p%ax(i)%label_off:p%ax(i)%label_off + p%ax(i)%label_len - 1_int32))
         else
            call core_text_unformatted(AXIS_NAMES(i)(1:AXIS_NAMES_LEN(i)))
         endif
         call ig_separator()
         call axis_context_menu(p, i, merge(p%ax(i)%ortho, 0_int32, has_flag(p%flags, PF_EQUAL)))
         call core_end_popup()
      endif
      call core_pop_id()
   enddo
   call core_pop_id()
   endsubroutine context_menus

   subroutine plot_context_menu(p)
   !< `ShowPlotContextMenu`: a menu per enabled axis, the legend's, the settings (Equal, Box Select, Title, Mouse
   !< Position, Crosshairs).
   type(plot_record), intent(inout) :: p     !< Plot.
   integer(int32)                   :: i     !< Axis.
   logical                          :: v     !< A setting.

   do i = 1_int32, AXES
      if (.not. p%ax(i)%enabled .or. has_flag(p%ax(i)%flags, AXF_NO_MENUS)) cycle
      call core_push_id_int(merge(i - AX_X1, i - AX_Y1, i <= AX_X3))
      if (has_label(p%ax(i))) then
         if (ig_begin_menu(text(p%ax(i)%label_off:p%ax(i)%label_off + p%ax(i)%label_len - 1_int32))) then
            call axis_context_menu(p, i, merge(p%ax(i)%ortho, 0_int32, has_flag(p%flags, PF_EQUAL)))
            call ig_end_menu()
         endif
      elseif (ig_begin_menu(AXIS_NAMES(i)(1:AXIS_NAMES_LEN(i)))) then
         call axis_context_menu(p, i, merge(p%ax(i)%ortho, 0_int32, has_flag(p%flags, PF_EQUAL)))
         call ig_end_menu()
      endif
      call core_pop_id()
   enddo
   call ig_separator()
   if (.not. has_flag(p%leg_flags, LGF_NO_MENUS)) then
      if (ig_begin_menu('Legend')) then
         if (legend_context_menu(p, .not. has_flag(p%flags, PF_NO_LEGEND))) call flip(p%flags, PF_NO_LEGEND)
         call ig_end_menu()
      endif
   endif
   if (ig_begin_menu('Settings')) then
      v = has_flag(p%flags, PF_EQUAL)
      if (ig_menu_item('Equal', selected=v)) call flip(p%flags, PF_EQUAL)
      v = .not. has_flag(p%flags, PF_NO_BOX_SELECT)
      if (ig_menu_item('Box Select', selected=v)) call flip(p%flags, PF_NO_BOX_SELECT)
      call begin_disabled(p%title_len == 0_int32)
      v = p%title_len > 0_int32 .and. .not. has_flag(p%flags, PF_NO_TITLE)
      if (ig_menu_item('Title', selected=v)) call flip(p%flags, PF_NO_TITLE)
      call end_disabled(p%title_len == 0_int32)
      v = .not. has_flag(p%flags, PF_NO_MOUSE_TEXT)
      if (ig_menu_item('Mouse Position', selected=v)) call flip(p%flags, PF_NO_MOUSE_TEXT)
      v = has_flag(p%flags, PF_CROSSHAIRS)
      if (ig_menu_item('Crosshairs', selected=v)) call flip(p%flags, PF_CROSSHAIRS)
      call ig_end_menu()
   endif
   endsubroutine plot_context_menu

   subroutine axis_context_menu(p, i, eq)
   !< `ShowAxisContextMenu` of a linear, log or symlog axis: its ends (locks and drags), Auto-Fit, Invert, Opposite,
   !< Label, Grid Lines, Tick Marks, Tick Labels, Tick Labels Inside. (A time axis's date and time pickers: not yet;
   !< its menu shows the drags of a linear axis.)
   type(plot_record), intent(inout) :: p      !< Plot.
   integer(int32),    intent(in)    :: i      !< Axis.
   integer(int32),    intent(in)    :: eq     !< The axis made equal with it (0: none).
   logical                          :: always_locked, label, grid, marks, labels, inside, v, done !< State.
   real(real64)                     :: speed, tmp !< The drags' speed, a value.

   call core_push_item_width(75.0_real64)
   associate(ax => p%ax(i))
      always_locked = (ax%has_range .and. ax%range_cond == COND_ALWAYS) .or. auto_fitting(ax)
      label = has_label(ax)
      grid = .not. has_flag(ax%flags, AXF_NO_GRID_LINES)
      marks = .not. has_flag(ax%flags, AXF_NO_TICK_MARKS)
      labels = .not. has_flag(ax%flags, AXF_NO_TICK_LABELS)
      inside = has_flag(ax%flags, AXF_TICK_LABELS_INSIDE)
      if (ax%range_max - ax%range_min <= epsilon(1.0_real64)) then
         speed = epsilon(1.0_real64) * 1.0e13_real64
      else
         speed = 0.01_real64 * (ax%range_max - ax%range_min)
      endif
      speed = real(real(speed, real32), real64) ! (float)drag_speed
      call begin_disabled(always_locked)
      call flag_box('##LockMin', ax%flags, AXF_LOCK_MIN)
      call end_disabled(always_locked)
      call ig_same_line()
      v = locked_min(ax) .or. always_locked
      call begin_disabled(v)
      tmp = ax%range_min
      if (core_drag_double('Min', tmp, speed, ieee_value(tmp, ieee_negative_inf), ax%range_max - epsilon(1.0_real64), &
                           '%.3g', 1_int32)) then
         done = set_min(ax, tmp, .true.)
         if (eq /= 0_int32) call set_aspect(p%ax(eq), get_aspect(ax))
      endif
      call end_disabled(v)
      call begin_disabled(always_locked)
      call flag_box('##LockMax', ax%flags, AXF_LOCK_MAX)
      call end_disabled(always_locked)
      call ig_same_line()
      v = locked_max(ax) .or. always_locked
      call begin_disabled(v)
      tmp = ax%range_max
      if (core_drag_double('Max', tmp, speed, ax%range_min + epsilon(1.0_real64), ieee_value(tmp, ieee_positive_inf), &
                           '%.3g', 1_int32)) then
         done = set_max(ax, tmp, .true.)
         if (eq /= 0_int32) call set_aspect(p%ax(eq), get_aspect(ax))
      endif
      call end_disabled(v)
      call ig_separator()
      call flag_box('Auto-Fit', ax%flags, AXF_AUTO_FIT)
      call ig_separator()
      call flag_box('Invert', ax%flags, AXF_INVERT)
      call flag_box('Opposite', ax%flags, AXF_OPPOSITE)
      call ig_separator()
      call begin_disabled(ax%label_len == 0_int32)
      if (ig_checkbox('Label', label)) call flip(ax%flags, AXF_NO_LABEL)
      call end_disabled(ax%label_len == 0_int32)
      if (ig_checkbox('Grid Lines', grid)) call flip(ax%flags, AXF_NO_GRID_LINES)
      if (ig_checkbox('Tick Marks', marks)) call flip(ax%flags, AXF_NO_TICK_MARKS)
      if (ig_checkbox('Tick Labels', labels)) call flip(ax%flags, AXF_NO_TICK_LABELS)
      if (ig_checkbox('Tick Labels Inside', inside)) call flip(ax%flags, AXF_TICK_LABELS_INSIDE)
   endassociate
   endsubroutine axis_context_menu

   function legend_context_menu(p, visible) result(changed)
   !< `ShowLegendContextMenu`: Show, Outside, horizontal or vertical, the location's nine buttons.
   type(plot_record), intent(inout) :: p       !< Plot.
   logical,           intent(in)    :: visible !< The legend shown.
   logical                          :: changed !< Show toggled.
   logical                          :: v       !< A box.
   real(real64)                     :: s       !< Frame height.
   real(real64)                     :: bw      !< A button's width.

   s = real(real(core_frame_height(), real32), real64)
   bw = real(1.5_real32 * real(s, real32), real64)
   v = visible
   changed = ig_checkbox('Show', v)
   call flag_box('Outside', p%leg_flags, LGF_OUTSIDE)
   if (core_radio_button('H', has_flag(p%leg_flags, LGF_HORIZONTAL))) p%leg_flags = ior(p%leg_flags, LGF_HORIZONTAL)
   call ig_same_line()
   if (core_radio_button('V', .not. has_flag(p%leg_flags, LGF_HORIZONTAL))) &
      p%leg_flags = iand(p%leg_flags, not(LGF_HORIZONTAL))
   call core_push_style_var(ImGuiStyleVar_ItemSpacing, 2.0_real64, 2.0_real64)
   if (ig_button('NW', bw, s)) p%leg_loc = LOC_NORTH + LOC_WEST
   call ig_same_line()
   if (ig_button('N', bw, s)) p%leg_loc = LOC_NORTH
   call ig_same_line()
   if (ig_button('NE', bw, s)) p%leg_loc = LOC_NORTH + LOC_EAST
   if (ig_button('W', bw, s)) p%leg_loc = LOC_WEST
   call ig_same_line()
   if (core_invisible_button('C', bw, s)) continue
   call ig_same_line()
   if (ig_button('E', bw, s)) p%leg_loc = LOC_EAST
   if (ig_button('SW', bw, s)) p%leg_loc = LOC_SOUTH + LOC_WEST
   call ig_same_line()
   if (ig_button('S', bw, s)) p%leg_loc = LOC_SOUTH
   call ig_same_line()
   if (ig_button('SE', bw, s)) p%leg_loc = LOC_SOUTH + LOC_EAST
   call core_pop_style_var()
   endfunction legend_context_menu

   subroutine flag_box(label, flags, flag)
   !< `CheckboxFlags` of one bit: a checkbox, the bit set or cleared when clicked.
   character(len=*), intent(in)    :: label !< Label.
   integer(int32),   intent(inout) :: flags !< Flags.
   integer(int32),   intent(in)    :: flag  !< The bit.
   logical                         :: v     !< Its state.

   v = has_flag(flags, flag)
   if (ig_checkbox(label, v)) then
      if (v) then
         flags = ior(flags, flag)
      else
         flags = iand(flags, not(flag))
      endif
   endif
   endsubroutine flag_box

   subroutine flip(flags, flag)
   !< `ImFlipFlag`.
   integer(int32), intent(inout) :: flags !< Flags.
   integer(int32), intent(in)    :: flag  !< The bit.

   if (has_flag(flags, flag)) then
      flags = iand(flags, not(flag))
   else
      flags = ior(flags, flag)
   endif
   endsubroutine flip

   subroutine begin_disabled(cond)
   !< `BeginDisabledControls`: the items disabled and faded (Alpha x 0.25) while `cond`.
   logical, intent(in) :: cond !< Disabled.
   real(real64)        :: v(2) !< The style's Alpha.
   integer(int32)      :: n    !< Its values.

   if (.not. cond) return
   call core_push_item_flag(ImGuiItemFlags_Disabled, .true.)
   call core_style_var('Alpha', v, n)
   call core_push_style_var(ImGuiStyleVar_Alpha, real(real(v(1), real32) * 0.25_real32, real64))
   endsubroutine begin_disabled

   subroutine end_disabled(cond)
   !< `EndDisabledControls`.
   logical, intent(in) :: cond !< Disabled.

   if (.not. cond) return
   call core_pop_item_flag()
   call core_pop_style_var()
   endsubroutine end_disabled

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
   open_context = .false.
   digital_offset = 0_int32
   endsubroutine reset_next

   ! private: the items

   function begin_item(p, label, color, it, created, no_legend) result(shown)
   !< `BeginItem`: the setup finished, the item registered (`RegisterOrGetItem`: its legend entry the first time it is
   !< drawn on this frame, if its label has text), its colour (given, or the next automatic one when it is created),
   !< its visibility (`pf_hide_next_item`); shown, or not (then nothing else is done).
   type(plot_record), intent(inout)        :: p        !< Plot.
   character(len=*),  intent(in)           :: label    !< Label.
   real(real64),      intent(in), optional :: color(4) !< Colour given.
   integer(int32),    intent(out)          :: it       !< The item's handle.
   logical,           intent(out)          :: created  !< The item is new.
   logical,           intent(in)           :: no_legend !< ImPlotItemFlags_NoLegend.
   logical                                 :: shown    !< Shown.
   logical                                 :: seen     !< Drawn already on this frame.

   if (.not. p%locked) call setup_finish(p)
   it = item_handle(p, plot_hash(label, plot_id_offset(p%id, -1_int32)), core_frame_count(), created, seen)
   if (.not. seen) then
      if (.not. no_legend .and. label_shown(label)) then
         call legend_append(p, it, label)
      else
         p%item_show(it) = .true.
      endif
   endif
   if (present(color)) then
      p%item_color(it) = core_color(color(1), color(2), color(3), color(4))
   elseif (created) then
      p%item_color(it) = cm_key(cm_current(), p%colormap_idx) ! NextColormapColorU32: the style's map
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

   function pf_item_begin(label, color, marker, no_legend, ctx) result(shown)
   !< `BeginItem` for figure_plot_items: the item registered (its legend entry, unless `no_legend`), its colour (given:
   !< `color`'s alpha /= -1; else the colormap's next when created), its marker (`marker` -3, ImPlotMarker_Invalid:
   !< left; -1, Auto: the plot's next when created or when it has none; else that one), its visibility, the highlight
   !< of a hovered entry's axes; and the plot as the item sees it. False: hidden (nothing else to do).
   character(len=*),    intent(in)  :: label     !< Label.
   real(real32),        intent(in)  :: color(4)  !< The colour that sets the item's (alpha -1: automatic).
   integer(int32),      intent(in)  :: marker    !< Marker asked.
   logical,             intent(in)  :: no_legend !< ImPlotItemFlags_NoLegend.
   type(plot_item_ctx), intent(out) :: ctx       !< The plot.
   logical                          :: shown     !< Shown.
   integer(int32)                   :: it        !< The item.
   logical                          :: created   !< New.
   real(real32)                     :: w         !< A weight (unused: the items scale their own).
   real(real64)                     :: c64(4)    !< The colour given.

   if (cur == 0_int32) error stop 'figure_plot_frame: an item outside a plot'
   associate(p => plots(cur))
      if (color(4) == -1.0_real32) then
         shown = begin_item(p, label, it=it, created=created, no_legend=no_legend)
      else
         c64(1) = real(color(1), real64) ! (a fixed array, not an expression: nvfortran allocates its temporary)
         c64(2) = real(color(2), real64)
         c64(3) = real(color(3), real64)
         c64(4) = real(color(4), real64)
         shown = begin_item(p, label, c64, it, created, no_legend)
      endif
      if (marker /= -3_int32) then
         if (marker /= -1_int32) then
            p%item_marker(it) = marker
         elseif (created .or. p%item_marker(it) == -2_int32) then ! NextMarker: ImPlotMarker_COUNT 12
            p%item_marker(it) = mod(p%marker_idx, 12_int32)
            p%marker_idx = p%marker_idx + 1_int32
         endif
      endif
      if (.not. shown) return
      ctx%color = p%item_color(it)
      ctx%marker = p%item_marker(it)
      ctx%hovered = .false.
      if (p%item_hovered(it)) then
         w = 1.0_real32
         call highlight(p, it, w) ! the axes' highlight
         ctx%hovered = iand(p%leg_flags, LGF_NO_HIGHLIGHT_ITEM) == 0_int32
      endif
      call fill_ctx(p, ctx)
   endassociate
   endfunction pf_item_begin

   subroutine pf_item_fit(x, y)
   !< `ExtendFitWith` of a point on the current axes (figure_plot_items' fitters, on the frames the plot fits).
   real(real64), intent(in) :: x, y !< Point.

   associate(p => plots(cur))
      call fit_point(p%ax(p%cur_x), p%ax(p%cur_y), x, y)
   endassociate
   endsubroutine pf_item_fit

   function pf_item_hidden(label) result(hidden)
   !< `IsItemHidden` (figure_plot_items' stacked bar groups): the item of `label` exists in the open plot and is hidden.
   character(len=*), intent(in) :: label  !< Label.
   logical                      :: hidden !< Hidden.
   integer(int32)               :: id, k  !< The item's ID, counter.

   hidden = .false.
   if (cur == 0_int32) error stop 'figure_plot_frame: an item outside a plot'
   associate(p => plots(cur))
      id = plot_hash(label, plot_id_offset(p%id, -1_int32))
      do k = 1_int32, p%n_items
         if (p%item_id(k) == id) then
            hidden = .not. p%item_show(k)
            return
         endif
      enddo
   endassociate
   endfunction pf_item_hidden

   subroutine pf_item_fit_axis(v, y_axis)
   !< `ImPlotAxis::ExtendFit` of the current x axis (or y axis) alone (figure_plot_items' `FitterX`, `FitterY`): a
   !< finite value within the axis's constraint.
   real(real64), intent(in) :: v      !< Value.
   logical,      intent(in) :: y_axis !< The y axis.
   integer(int32)           :: i      !< Axis.

   i = plots(cur)%cur_x
   if (y_axis) i = plots(cur)%cur_y
   associate(ax => plots(cur)%ax(i))
      if (abs(v) <= huge(1.0_real64) .and. v >= ax%con_min .and. v <= ax%con_max) then
         if (v < ax%fit_min) ax%fit_min = v
         if (v > ax%fit_max) ax%fit_max = v
      endif
   endassociate
   endsubroutine pf_item_fit_axis

   subroutine pf_plot_ctx(ctx)
   !< The open plot as a non-item sees it (`PlotText`, `PlotPieChart`'s labels: `SetupLock`): rectangle, current axes.
   type(plot_item_ctx), intent(out) :: ctx !< The plot.

   if (cur == 0_int32) error stop 'figure_plot_frame: an item outside a plot'
   associate(p => plots(cur))
      if (.not. p%locked) call setup_finish(p)
      call fill_ctx(p, ctx)
   endassociate
   endsubroutine pf_plot_ctx

   subroutine fill_ctx(p, ctx)
   !< The plot's part of an item's context: fit, rectangle, the current axes' maps, ranges, pixels, inversions.
   type(plot_record),   intent(in)    :: p   !< Plot.
   type(plot_item_ctx), intent(inout) :: ctx !< Context.

   ctx%fit = p%fit
   ctx%rect = p%rect
   ctx%tx = axis_map(p%ax(p%cur_x))
   ctx%ty = axis_map(p%ax(p%cur_y))
   ctx%x_range = [p%ax(p%cur_x)%range_min, p%ax(p%cur_x)%range_max]
   ctx%y_range = [p%ax(p%cur_y)%range_min, p%ax(p%cur_y)%range_max]
   ctx%x_pix = [p%ax(p%cur_x)%pixel_min, p%ax(p%cur_x)%pixel_max]
   ctx%y_pix = [p%ax(p%cur_y)%pixel_min, p%ax(p%cur_y)%pixel_max]
   ctx%x_inv = has_flag(p%ax(p%cur_x)%flags, AXF_INVERT)
   ctx%y_inv = has_flag(p%ax(p%cur_y)%flags, AXF_INVERT)
   endsubroutine fill_ctx

   function pf_item_count() result(n)
   !< `ItemGroup::GetItemCount` of the open plot.
   integer(int32) :: n !< Items.

   n = plots(cur)%n_items
   endfunction pf_item_count

   function pf_item_shown_at(i) result(shown)
   !< `GetItemByIndex(i)->Show`, i from 0 (the items in the order they were created).
   integer(int32), intent(in) :: i     !< Index.
   logical                    :: shown !< Shown.

   shown = plots(cur)%item_show(i + 1_int32)
   endfunction pf_item_shown_at

   subroutine pf_item_state(label, found, shown, color)
   !< `GetItem(label)`: whether the item exists in the open plot, shown, its colour.
   character(len=*), intent(in)  :: label !< Label.
   logical,          intent(out) :: found !< Exists.
   logical,          intent(out) :: shown !< Shown.
   integer(int32),   intent(out) :: color !< Colour (packed; 0 when not found).
   integer(int32)                :: id, k !< ID, counter.

   found = .false.
   shown = .false.
   color = 0_int32
   associate(p => plots(cur))
      id = plot_hash(label, plot_id_offset(p%id, -1_int32))
      do k = 1_int32, p%n_items
         if (p%item_id(k) == id) then
            found = .true.
            shown = p%item_show(k)
            color = p%item_color(k)
            return
         endif
      enddo
   endassociate
   endsubroutine pf_item_state

   subroutine pf_item_fit_with(v, alt, y_axis)
   !< `ExtendFitWith` of one current axis (x, or y): v within its constraint, alt (the other axis's value) within the
   !< other's range when RangeFit.
   real(real64), intent(in) :: v, alt !< Value, the other coordinate.
   logical,      intent(in) :: y_axis !< The y axis.
   integer(int32)           :: i, j   !< The axis, the other.

   associate(p => plots(cur))
      i = merge(p%cur_y, p%cur_x, y_axis)
      j = merge(p%cur_x, p%cur_y, y_axis)
      associate(a => p%ax(i), o => p%ax(j))
         if (has_flag(a%flags, AXF_RANGE_FIT)) then
            if (.not. (alt >= o%range_min .and. alt <= o%range_max)) return
         endif
         if (abs(v) <= huge(1.0_real64) .and. v >= a%con_min .and. v <= a%con_max) then
            if (v < a%fit_min) a%fit_min = v
            if (v > a%fit_max) a%fit_max = v
         endif
      endassociate
   endassociate
   endsubroutine pf_item_fit_with

   function pf_digital_offset(add) result(old)
   !< `gp.DigitalPlotOffset` of the open plot (0 at each plot's begin): its value, then `add` added.
   integer(int32), intent(in) :: add !< Pixels to add.
   integer(int32)             :: old !< The offset before.

   old = digital_offset
   digital_offset = digital_offset + add
   endfunction pf_digital_offset

   subroutine pf_text_vertical(x, y, col, text)
   !< `AddTextVertical` (figure_plot_items' vertical `pf_text`): the frame's `text_vertical`.
   real(real32),     intent(in) :: x, y !< Bottom-left corner [pixels].
   integer(int32),   intent(in) :: col  !< Colour.
   character(len=*), intent(in) :: text !< Text.

   call text_vertical(x, y, col, text)
   endsubroutine pf_text_vertical

   subroutine pf_item_end()
   !< `EndItem` (figure_plot_items): the next item's data reset.

   next_hidden_set = .false.
   endsubroutine pf_item_end

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
   p%marker_idx = 0_int32
   p%n_items = 0_int32
   p%item_next = 1_int32
   p%leg_flags = 0_int32
   p%leg_prev_flags = 0_int32
   p%leg_loc = LOC_NORTH + LOC_WEST
   p%leg_prev_loc = LOC_NORTH + LOC_WEST
   p%leg_hovered = .false.
   p%n_leg = 0_int32
   p%leg_n = 0_int32
   p%hovered = .false.
   p%held = .false.
   p%selecting = .false.
   p%selected = .false.
   p%context_locked = .false.
   p%select_start = 0.0_real32
   p%select_rect = 0.0_real32
   do i = 1_int32, AXES
      p%ax(i)%hovered = .false.
      p%ax(i)%held = .false.
      p%ax(i)%hover_rect = 0.0_real32
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
   p%item_marker(h) = -2_int32 ! ImPlotMarker_None
   p%item_next = h + 1_int32
   endfunction item_handle

   subroutine grow_items(p, m)
   !< Room for m items in a plot's table, those held kept.
   type(plot_record), intent(inout) :: p                       !< Plot.
   integer(int32),    intent(in)    :: m                       !< Items room.
   integer(int32),    allocatable   :: id(:), color(:), frame(:) !< New columns.
   logical,           allocatable   :: show(:), hovered(:)     !< ...
   integer(int32),    allocatable   :: marker(:)               !< ...
   integer(int32)                   :: n                       !< Items held.

   n = p%n_items
   allocate(id(m), color(m), frame(m), show(m), hovered(m), marker(m))
   if (n > 0_int32) then
      id(1:n) = p%item_id(1:n)
      color(1:n) = p%item_color(1:n)
      frame(1:n) = p%item_frame(1:n)
      show(1:n) = p%item_show(1:n)
      hovered(1:n) = p%item_hovered(1:n)
      marker(1:n) = p%item_marker(1:n)
   endif
   call move_alloc(id, p%item_id)
   call move_alloc(color, p%item_color)
   call move_alloc(frame, p%item_frame)
   call move_alloc(show, p%item_show)
   call move_alloc(hovered, p%item_hovered)
   call move_alloc(marker, p%item_marker)
   endsubroutine grow_items

   ! private: the axes

   subroutine setup_scale(ax, scale, vertical)
   !< `SetupAxisScale`: the scale of an axis on this frame and its constraint (log10: from DBL_MIN; time: 0 to
   !< IMPLOT_MAX_TIME, two label levels).
   type(plot_axis),  intent(inout) :: ax       !< Axis.
   character(len=*), intent(in)    :: scale    !< 'linear', 'log', 'symlog', 'time'.
   logical,          intent(in)    :: vertical !< A y axis.

   select case (scale) ! (trailing blanks ignored)
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

   subroutine fit_point(xa, ya, x, y)
   !< `ExtendFitWith` on both axes: a point's finite coordinates within the axes' constraints (a log axis's positive
   !< ones) extend the axes' fit ranges (with `ImPlotAxisFlags_RangeFit`, only those whose other coordinate is in the
   !< other axis's range).
   type(plot_axis), intent(inout) :: xa   !< X axis.
   type(plot_axis), intent(inout) :: ya   !< Y axis.
   real(real64),    intent(in)    :: x, y !< Point.
   logical                        :: rx, ry !< RangeFit on x, on y.

   rx = iand(xa%flags, AXF_RANGE_FIT) == AXF_RANGE_FIT
   ry = iand(ya%flags, AXF_RANGE_FIT) == AXF_RANGE_FIT
   if (abs(x) <= huge(1.0_real64) .and. x >= xa%con_min .and. x <= xa%con_max) then
      if (.not. rx .or. (y >= ya%range_min .and. y <= ya%range_max)) then
         if (x < xa%fit_min) xa%fit_min = x
         if (x > xa%fit_max) xa%fit_max = x
      endif
   endif
   if (abs(y) <= huge(1.0_real64) .and. y >= ya%con_min .and. y <= ya%con_max) then
      if (.not. ry .or. (x >= xa%range_min .and. x <= xa%range_max)) then
         if (y < ya%fit_min) ya%fit_min = y
         if (y > ya%fit_max) ya%fit_max = y
      endif
   endif
   endsubroutine fit_point

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
   real(real64)   :: w, h                 !< A text's size.
   real(real64)   :: xar, yar             !< Units per pixel on x, y.
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
   do i = AX_X1, AX_X3 ! the axes on screen, their buttons' rectangles (HoverRect)
      associate(ax => p%ax(i))
         ax%hover_rect = [p%rect(1), min(ax%datum1, ax%datum2), p%rect(3), max(ax%datum1, ax%datum2)]
         ax%pixel_min = merge(p%rect(3), p%rect(1), has_flag(ax%flags, AXF_INVERT))
         ax%pixel_max = merge(p%rect(1), p%rect(3), has_flag(ax%flags, AXF_INVERT))
         call update_scale(ax)
      endassociate
   enddo
   do i = AX_Y1, AX_Y3
      associate(ax => p%ax(i))
         ax%hover_rect = [min(ax%datum1, ax%datum2), p%rect(2), max(ax%datum1, ax%datum2), p%rect(4)]
         ax%pixel_min = merge(p%rect(2), p%rect(4), has_flag(ax%flags, AXF_INVERT))
         ax%pixel_max = merge(p%rect(4), p%rect(2), has_flag(ax%flags, AXF_INVERT))
         call update_scale(ax)
      endassociate
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
   if (.not. has_flag(p%flags, PF_NO_INPUTS)) call update_input(p)
   do i = 1_int32, AXES ! the fits asked for: SetNextAxisToFit, ImPlotAxisFlags_AutoFit
      if (next_fit(i) .or. auto_fitting(p%ax(i))) then
         p%fit = .true.
         p%ax(i)%fit = .true.
      endif
   enddo
   ! render: the frame, the plot's background
   call core_draw_begin()
   call render_frame(p%frame)
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
   call core_push_override_id(plot_id_offset(p%id, -1_int32)) ! the items' IDs: PushOverrideID(Items.ID)
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
      if ((ax%hovered .or. ax%held) .and. .not. p%held .and. .not. has_flag(ax%flags, AXF_NO_HIGHLIGHT)) then
         call core_draw_rect_filled(real(ax%hover_rect(1), real64), real(ax%hover_rect(2), real64),       &
                                    real(ax%hover_rect(3), real64), real(ax%hover_rect(4), real64),       &
                                    core_style_color(merge(ImGuiCol_ButtonActive, ImGuiCol_ButtonHovered, &
                                                           ax%held)))
      elseif (ax%hili /= 0_int32) then ! (the axis's background, AxisBg, is transparent)
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
               call core_draw_text(real(px, real64), real(datum, real64), p%col_txt, t%label(k)(1:t%label_len(k)))
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
               call core_draw_text(real(datum, real64), real(py, real64), p%col_txt, t%label(k)(1:t%label_len(k)))
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

   subroutine render_frame(fr)
   !< `RenderFrame` with ImPlot's `FrameBg` (Dear ImGui's): the filled frame and, with `FrameBorderSize`, its shadow
   !< and border.
   real(real32), intent(in) :: fr(4)   !< Rectangle [pixels].
   real(real32)             :: rounding, border !< FrameRounding, FrameBorderSize.
   real(real64)             :: v(2)    !< A style variable.
   integer(int32)           :: nv      !< Its values.

   call core_style_var('FrameRounding', v, nv)
   rounding = real(v(1), real32)
   call core_style_var('FrameBorderSize', v, nv)
   border = real(v(1), real32)
   call core_draw_rect_filled(real(fr(1), real64), real(fr(2), real64), real(fr(3), real64), real(fr(4), real64), &
                              core_style_color(ImGuiCol_FrameBg), real(rounding, real64))
   if (border > 0.0_real32) then
      call core_draw_rect(real(fr(1) + 1.0_real32, real64), real(fr(2) + 1.0_real32, real64),    &
                          real(fr(3) + 1.0_real32, real64), real(fr(4) + 1.0_real32, real64),    &
                          core_style_color(ImGuiCol_BorderShadow), real(rounding, real64), real(border, real64))
      call core_draw_rect(real(fr(1), real64), real(fr(2), real64), real(fr(3), real64), real(fr(4), real64), &
                          core_style_color(ImGuiCol_Border), real(rounding, real64), real(border, real64))
   endif
   endsubroutine render_frame

   subroutine color_bar(cm, b)
   !< `RenderColorBar` of a map's keys, vertical, from its last key at the top (`reversed`): a strip per key (between
   !< two keys, blended, for a continuous map), `AddRectFilledMultiColor`.
   integer(int32), intent(in) :: cm   !< Map.
   real(real32),   intent(in) :: b(4) !< Bounds [pixels].
   real(real32)               :: step, y0, y1 !< A strip's height and edges.
   integer(int32)             :: n, nk, i, c1, c2 !< Strips, keys, counter, colours.
   logical                    :: continuous !< Not qualitative.

   nk = cm_size(cm)
   continuous = .not. cm_is_qual(cm)
   n = merge(nk - 1_int32, nk, continuous)
   step = (b(4) - b(2)) / real(n, real32)
   y0 = b(2)
   y1 = b(2) + step
   do i = 0_int32, n - 1_int32
      c1 = cm_key(cm, nk - i - 1_int32)
      c2 = c1
      if (continuous) c2 = cm_key(cm, nk - i - 2_int32)
      call core_draw_rect_filled_multicolor(real(b(1), real64), real(y0, real64), real(b(3), real64), &
                                            real(y1, real64), c1, c1, c2, c2)
      y0 = y0 + step
      y1 = y1 + step
   enddo
   endsubroutine color_bar

   pure function text_color(bg) result(col)
   !< `CalcTextColor`: black on a light colour (luminance 0.299 r + 0.587 g + 0.114 b above 0.5), else white.
   integer(int32), intent(in) :: bg  !< Background (packed).
   integer(int32)             :: col !< IM_COL32_BLACK or IM_COL32_WHITE.
   real(real32), parameter    :: S = 1.0_real32 / 255.0_real32 !< ColorConvertU32ToFloat4's scale.
   real(real32)               :: lum, t !< Luminance, a term.

   lum = (real(channel(bg, 0_int32), real32) * S) * 0.299_real32
   t = (real(channel(bg, 1_int32), real32) * S) * 0.587_real32
   lum = lum + t
   t = (real(channel(bg, 2_int32), real32) * S) * 0.114_real32
   lum = lum + t
   col = merge(-16777216_int32, -1_int32, lum > 0.5_real32) ! 0xFF000000, 0xFFFFFFFF
   endfunction text_color

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
   logical                          :: any_item   !< An entry hovered.
   logical                          :: contextable !< The legend's menu may open.
   real(real64)                     :: mx, my     !< The pointer.

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
   call core_mouse_pos(mx, my)
   p%leg_hovered = p%leg_hovered .or. (core_window_hovered() .and. real(mx, real32) >= cl(1) .and. &
                                       real(my, real32) >= cl(2) .and. real(mx, real32) < cl(3) .and. &
                                       real(my, real32) < cl(4))
   call core_push_clip_rect(real(cl(1), real64), real(cl(2), real64), real(cl(3), real64), real(cl(4), real64))
   call core_draw_rect_filled(real(cl(1), real64), real(cl(2), real64), real(cl(3), real64), real(cl(4), real64), &
                              core_style_color(ImGuiCol_PopupBg))
   call legend_entries(p, lr, .not. horz, any_item)
   contextable = p%leg_hovered .and. .not. any_item .and. .not. has_flag(p%leg_flags, LGF_NO_MENUS)
   call core_draw_rect(real(cl(1), real64), real(cl(2), real64), real(cl(3), real64), real(cl(4), real64), &
                       core_style_color(ImGuiCol_Border))
   call core_pop_clip_rect()
   if (open_context .and. contextable .and. .not. has_flag(p%flags, PF_NO_MENUS)) &
      call core_open_popup('##LegendContext')
   if (core_begin_popup('##LegendContext')) then
      call core_text_unformatted('Legend')
      call ig_separator()
      if (legend_context_menu(p, .not. has_flag(p%flags, PF_NO_LEGEND))) call flip(p%flags, PF_NO_LEGEND)
      call core_end_popup()
   endif
   endsubroutine legend

   subroutine legend_entries(p, lr, vertical, any_item)
   !< `ShowLegendEntries`: each entry its button (a click shows or hides the item), its icon and its label.
   type(plot_record), intent(inout) :: p        !< Plot.
   real(real32),      intent(in)    :: lr(4)    !< Legend's rectangle.
   logical,           intent(in)    :: vertical !< In a column.
   logical,           intent(out)   :: any_item !< An entry hovered.
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
   any_item = .false.
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
         any_item = .true.
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
   real(real32)                 :: a0, a1, b0, b1 !< A glyph's corners from the pen [pixels].
   real(real64)                 :: scale, adv, x0, y0, x1, y1, u0, v0, u1, v1 !< A glyph.
   real(real64)                 :: qx(4), qy(4), qu(4), qv(4) !< Its quad.
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
      a0 = real(y0, real32) * sc ! the products apart (nvfortran's FMA), the quad in fixed arrays (no constructor)
      a1 = real(y1, real32) * sc
      b0 = (-real(x0, real32)) * sc
      b1 = (-real(x1, real32)) * sc
      qx(1) = real(px + a0, real64)
      qx(2) = real(px + a0, real64)
      qx(3) = real(px + a1, real64)
      qx(4) = real(px + a1, real64)
      qy(1) = real(py + b0, real64)
      qy(2) = real(py + b1, real64)
      qy(3) = real(py + b1, real64)
      qy(4) = real(py + b0, real64)
      qu(1) = u0
      qu(2) = u1
      qu(3) = u1
      qu(4) = u0
      qv(1) = v0
      qv(2) = v0
      qv(3) = v1
      qv(4) = v1
      call core_draw_quad_uv(qx, qy, qu, qv, col)
      a0 = real(adv, real32) * sc
      py = py - a0
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
   !< `PlotToPixels` (and the items' `Transformer1`): the pixel of a value, in single precision (figure_plot_transform).
   type(plot_axis), intent(in) :: ax !< Axis.
   real(real64),    intent(in) :: v  !< Value.
   real(real32)                :: px !< Pixel.

   px = map_pixel(axis_map(ax), v)
   endfunction to_pixels

   pure function axis_map(ax) result(m)
   !< An axis as the items map values onto it (`Transformer1`'s fields).
   type(plot_axis), intent(in) :: ax !< Axis.
   type(plot_axis_map)         :: m  !< Map.

   m%pix_min = real(ax%pixel_min, real64)
   m%plt_min = ax%range_min
   m%plt_max = ax%range_max
   m%m = ax%scale_to_pixel
   m%sca_min = ax%scale_min
   m%sca_max = ax%scale_max
   m%scale = ax%scale
   endfunction axis_map

   pure function border_shown(p) result(shown)
   !< The plot's border is drawn (`PlotBorderSize` > 0, the colour not transparent).
   type(plot_record), intent(in) :: p     !< Plot.
   logical                       :: shown !< Drawn.

   shown = PLOT_BORDER_SIZE > 0.0_real32 .and. channel(p%col_border, 3_int32) > 0_int32
   endfunction border_shown

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
