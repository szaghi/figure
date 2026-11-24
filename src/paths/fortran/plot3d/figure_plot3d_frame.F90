!< figure_plot3d_frame, the Fortran path's 3-D plot frame: a plot's begin and end, its setup, box and axes (ImPlot3D's).
module figure_plot3d_frame
!< figure_plot3d_frame, the Fortran path's 3-D plot frame: a plot's begin and end, its setup, box and axes (ImPlot3D's).
!<
!< szaghi/figure#15 P13. The frame of FIGURE's 3-D plots on the Fortran path, reproduced from implot3d.cpp (ImPlot3D 0.6
!< WIP, FIGURE's copy, patched for no mouse position) through figure_core only: `pf3_begin_plot` (`BeginPlot`: the
!< plot kept between frames by its title's ID, created with ImPlot3D's initial rotation and every axis to fit; the
!< frame's size by `CalcItemSize` with `PlotDefaultSize` 400 x 400 and `PlotMinSize` 200 x 200; `ItemSize`, `ItemAdd`;
!< the frame clip), the setup (`pf3_setup_axes`, `pf3_setup_axis`, `pf3_setup_box`, `pf3_setup_legend`, as
!< figure_implot3d's `ip3_setup_*` call ImPlot3D's `SetupAxes`, `SetupAxesLimits` and `SetupBoxRotation` once,
!< `SetupBoxInitialRotation`, `SetupAxis`, `SetupBoxScale`, `SetupLegend`), `setup_lock` (`SetupLock`: the frame's
!< background, canvas and plot rectangles, `Equal`'s aspect, the ticks, the title, the input, the plot clip, the box),
!< the box (`RenderPlotBox`: the three faces drawn, the axis rectangles, the border, the grid, the tick marks, the tick
!< labels and the axis labels, text rotated glyph by glyph as `AddTextRotated`), `pf3_end_plot` (`EndPlot`: the fit,
!< the mouse position's text), and the queries `pf3_plot_to_pixels`, `pf3_mouse_ray` (as FIGURE's
!< `fig_plot3d_mouse_ray`: the ray normalised again, the pointer over the plot rectangle), `pf3_plot_limits`,
!< `pf3_plot_rotation`. The camera and the box's geometry are figure_plot3d_camera's, the ticks
!< figure_plot3d_locators'.
!<
!< Colours and style variables are figure_plot3d_style's (`ImPlot3DStyle`: the colours pushed, else automatic,
!< `GetAutoColor` from Dear ImGui's style of now; packed without the style's alpha as `GetStyleColorU32`, or with it where
!< ImPlot3D calls `GetColorU32`).
!<
!< Axes (step 3): log10 and symlog scales (`SetupAxisScale`: ImPlot3D's transforms, constraints and locators; the range
!< constrained and the scaled range cached when the scale is set, as FIGURE's ImPlot3D patch 0003, so a scale set
!< after the limits maps against its own scaled range from the first frame on), custom ticks (`SetupAxisTicks`: minor ticks,
!< labelled, the default ones off), a printf format of the tick labels (`SetupAxisFormat` with FIGURE's formatter:
!< figure_plot_format's glibc printf), lock, no grid, auto-fit.
!<
!< Items (step 4): `pf3_item_begin` (`BeginItem`, `RegisterOrGetItem`: the items kept per plot by their label's ID,
!< the colormap's next colour for a new one, the style staged), the fit (`ExtendFit`, `ApplyFit`; `Equal`'s
!< reference axis), the 3-D list moved, depth-sorted, at the plot's end (figure_plot3d_drawlist), the legend
!< (`RenderLegend`, `ShowLegendEntries`: its box, button, scrolling, entries that hide or highlight their items).
!<
!< Input (step 6): `HandleInput` whole (the hover of planes, axes and edges; pan, rotation, zoom, double-click fit, the
!< animated rotation to the initial one or to a face, `SetupBoxRotation`'s animation; the context click opening its
!< popup); io.MouseClickedTime[1] is the time of the frame a 3-D plot saw the right click (`core_time()`, g.Time as
!< ImGui sets it; a click on a frame without a 3-D plot is missed), MouseDoubleClickTime 0.30 (FIGURE never changes it).
!<
!< Context menus (step 7): the legend's, each axis's, each plane's and the plot's, as ImPlot3D's (`ShowAxisContextMenu`,
!< `ShowPlaneContextMenu`, `ShowPlotContextMenu`, `ShowLegendContextMenu`), through src/lib's widgets (`ig_checkbox`,
!< `ig_begin_menu`, ...: they allocate their NUL-terminated copies while a menu is open, as the 2-D frame's) and
!< figure_core's popups and drags; the Box menu's scales are double drags of the float values (ImPlot3D's DragFloat:
!< the same text, the same values unless dragged).
!<
!< No allocation per frame once the tables are grown (ADR 0001): fixed slots for titles and labels, the ticks' arrays
!< kept, fixed arrays for quads.
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use, intrinsic :: ieee_arithmetic, only : ieee_is_finite, ieee_is_nan, ieee_negative_inf, ieee_positive_inf, &
                                          ieee_value
use figure_cimgui_enums, only : ImGuiCol_Border, ImGuiCol_ButtonActive, ImGuiCol_ButtonHovered, ImGuiCol_FrameBg, &
                                ImGuiCol_PopupBg, ImGuiCol_Text, ImGuiCol_TextDisabled, ImGuiCol_WindowBg,      &
                                ImGuiKey_MouseWheelY, ImGuiStyleVar_ItemSpacing
use figure_core, only : core_button_behavior, core_content_region_avail, core_cursor_screen_pos, core_draw_begin, &
                        core_draw_convex_poly_filled, core_draw_end, core_draw_line, core_draw_quad_uv,          &
                        core_draw_rect_filled, core_draw_text, core_font_glyph, core_font_size, core_frame_count, &
                        core_get_id, core_item_add, core_item_size, core_mouse_pos, core_mouse_pos_valid,        &
                        core_pop_clip_rect, core_push_clip_rect, core_style_color, core_text_size, core_color,  &
                        core_draw_rect, core_keep_alive, core_io_input, core_set_key_owner, core_delta_time,  &
                        core_style_color_rgba, core_mouse_down, core_mouse_clicked, core_mouse_double_clicked, &
                        core_mouse_released,                                                                   &
                        core_mouse_drag_delta, core_time, core_open_popup, core_begin_popup, core_end_popup,  &
                        core_text_unformatted, core_push_id_int, core_pop_id, core_push_item_width,           &
                        core_radio_button, core_invisible_button, core_push_style_var, core_pop_style_var,    &
                        core_drag_double, core_frame_height
use figure_plot_format, only : plot_format, fmt_parse, fmt_real, fmt_text
use figure_plot_locators, only : transform_log10, transform_symlog
use figure_plot3d_camera, only : plot3d_quat, view3d, quat_from_el_az, quat_rotate, view_scale, rect_center, &
                                 quat_axis_angle, quat_mul, quat_inverse, quat_normalize, quat_dot, quat_slerp,   &
                                 quat_from_two_vectors, quat_rotate_v, ndc_to_plot, c_acosf,                     &
                                 plot_to_ndc, ndc_to_pixels, plot_to_pixels, pixels_to_ndc_ray, ndc_ray_to_plot_ray, &
                                 pixels_to_plot_plane, axes_parameters, mouse_over_plane, edge_outward_dir,          &
                                 in_edge_region, c_atan2f, c_cosf, c_sinf, IM_PI_F, FACES, EDGES, FACE_EDGES,        &
                                 SCALE3_LINEAR, SCALE3_LOG10, SCALE3_SYMLOG
use figure_plot_colormaps, only : cm_key, cm_size, mix_u32, CM_DEEP
use figure_plot3d_drawlist, only : d3_flush, d3_reset
use figure_imgui, only : ig_button, ig_checkbox, ig_same_line, ig_separator, ig_push_item_width, ig_pop_item_width
use figure_menu, only : ig_begin_menu, ig_end_menu, ig_menu_item
use figure_group, only : ig_begin_disabled, ig_end_disabled
use figure_plot3d_style, only : style3_vec4, style3_u32, style3_color_u32, style3_alpha_u32,                  &
                                S3_TITLE_TEXT, S3_INLAY_TEXT, S3_FRAME_BG, S3_PLOT_BG,                         &
                                S3_PLOT_BORDER, S3_LEGEND_BG, S3_LEGEND_BORDER, S3_LEGEND_TEXT, S3_AXIS_TEXT,  &
                                S3_AXIS_GRID, S3_AXIS_TICK, S3_AXIS_BG, S3_AXIS_BG_HOVERED, S3_AXIS_BG_ACTIVE, &
                                s3_line_weight, s3_marker_size, s3_fill_alpha, s3_view_factor,                 &
                                PLOT_DEFAULT_SIZE => s3_default_size, PLOT_MIN_SIZE => s3_min_size,            &
                                PLOT_PADDING => s3_plot_padding, LABEL_PADDING => s3_label_padding,            &
                                LEGEND_PADDING => s3_legend_padding, LEGEND_INNER_PADDING => s3_legend_inner,  &
                                LEGEND_SPACING => s3_legend_spacing
use figure_plot3d_locators, only : ticks3d, ticks3_add, ticks3_reset, locate3_default, locate3_log10, locate3_symlog
use vecfor_R8P, only : vector_R8P

implicit none
private
public :: pf3_begin_plot, pf3_end_plot, pf3_setup_axes, pf3_setup_axis, pf3_setup_axis_ticks, pf3_setup_box
public :: pf3_setup_legend
public :: pf3_plot_to_pixels, pf3_mouse_ray, pf3_plot_limits, pf3_plot_rotation
public :: plot3d_spec, item3d_style, pf3_item_begin, pf3_item_fit, pf3_item_fitting, pf3_item_view, pf3_item_end
public :: pf3_colormap
public :: F3_NO_CLIP, pf3_push_colormap, pf3_pop_colormap, pf3_item_recolor, pf3_text
public :: pf3_plot_state, pf3_open_id

! ImPlot3DFlags
integer(int32), parameter :: F3_NO_TITLE = 1_int32       !< NoTitle.
integer(int32), parameter :: F3_NO_LEGEND = 2_int32      !< NoLegend.
integer(int32), parameter :: F3_NO_MOUSE_TEXT = 4_int32  !< NoMouseText.
integer(int32), parameter :: F3_NO_CLIP = 8_int32        !< NoClip.
integer(int32), parameter :: F3_EQUAL = 32_int32         !< Equal.
integer(int32), parameter :: F3_NO_MENUS = 16_int32      !< NoMenus.
integer(int32), parameter :: F3_NO_ROTATE = 64_int32     !< NoRotate.
integer(int32), parameter :: F3_NO_PAN = 128_int32       !< NoPan.
integer(int32), parameter :: F3_NO_ZOOM = 256_int32      !< NoZoom.
integer(int32), parameter :: F3_NO_INPUTS = 512_int32    !< NoInputs.
integer(int32), parameter :: A3_PAN_STRETCH = 256_int32  !< ImPlot3DAxisFlags_PanStretch.
real(real32),   parameter :: ANIMATION_ANGULAR_VELOCITY = 2.0_real32 * 3.1415_real32 !< ImPlot3D's (a float).
character(len=*), parameter :: AXIS_LABELS(0:2) = ['X-Axis', 'Y-Axis', 'Z-Axis'] !< Axes' default names.
character(len=*), parameter :: PLANE_LABELS(0:2) = ['YZ-Plane', 'XZ-Plane', 'XY-Plane'] !< Planes' names.
character(len=*), parameter :: AXIS_CONTEXTS(0:2) = ['##XAxisContext', '##YAxisContext', '##ZAxisContext'] !< Popups.
character(len=*), parameter :: PLANE_CONTEXTS(0:2) = ['##YZPlaneContext', '##XZPlaneContext', '##XYPlaneContext'] !<
                                                       !< Popups.
! edge_to_faces of HandleInput: per edge, two (face, plane) pairs
integer(int32), parameter :: EDGE_TO_FACES(0:1, 0:1, 0:11) = reshape([1, 1, 2, 2, 2, 2, 3, 0, 2, 2, 4, 1, 0, 0, 2, 2, &
                                                                       1, 1, 5, 2, 3, 0, 5, 2, 4, 1, 5, 2, 0, 0, 5, 2, &
                                                                       0, 0, 1, 1, 1, 1, 3, 0, 3, 0, 4, 1, 0, 0, 4, 1], &
                                                                      [2, 2, 12]) !< (face/plane, pair, edge).
! ImPlot3DAxisFlags
integer(int32), parameter :: A3_NO_LABEL = 1_int32       !< NoLabel.
integer(int32), parameter :: A3_NO_GRID = 2_int32        !< NoGridLines.
integer(int32), parameter :: A3_NO_TICK_MARKS = 4_int32  !< NoTickMarks.
integer(int32), parameter :: A3_NO_TICK_LABELS = 8_int32 !< NoTickLabels.
integer(int32), parameter :: A3_LOCK_MIN = 16_int32      !< LockMin.
integer(int32), parameter :: A3_LOCK_MAX = 32_int32      !< LockMax.
integer(int32), parameter :: A3_AUTO_FIT = 64_int32      !< AutoFit.
integer(int32), parameter :: A3_INVERT = 128_int32       !< Invert.
! ImPlot3DCond
integer(int32), parameter :: COND_NONE = 0_int32   !< None.
integer(int32), parameter :: COND_ALWAYS = 1_int32 !< Always.
integer(int32), parameter :: COND_ONCE = 2_int32   !< Once.
! ImPlot3DLocation
integer(int32), parameter :: LOC_NORTH = 1_int32, LOC_SOUTH = 2_int32, LOC_WEST = 4_int32, LOC_EAST = 8_int32 !< Bits.
! the plot's button (ImGuiButtonFlags): AllowOverlap, PressedOnClick, PressedOnDoubleClick, the three mouse buttons
integer(int32), parameter :: PLOT_BUTTON_FLAGS = 4096_int32 + 16_int32 + 256_int32 + 1_int32 + 2_int32 + 4_int32 !< Flags.
integer(int32), parameter :: LEGEND_BUTTON_FLAGS = PLOT_BUTTON_FLAGS + 2048_int32 !< ... and FlattenChildren.
! ImPlot3DLegendFlags
integer(int32), parameter :: L3_NO_BUTTONS = 1_int32    !< NoButtons.
integer(int32), parameter :: L3_NO_HIGHLIGHT = 2_int32  !< NoHighlightItem.
integer(int32), parameter :: L3_HORIZONTAL = 4_int32    !< Horizontal.
! ImPlot3DItemFlags, markers
integer(int32), parameter :: I3_NO_LEGEND = 1_int32     !< NoLegend.
integer(int32), parameter :: I3_NO_FIT = 2_int32        !< NoFit.
integer(int32), parameter :: M3_NONE = -2_int32         !< ImPlot3DMarker_None.
! the style (ImPlot3DStyle's defaults)
real(real32),   parameter :: AXIS_TICK_INNER_PAD = 5.0_real32  !< Between an axis's edge and its tick labels.
real(real32),   parameter :: AXIS_LABEL_PAD = 10.0_real32      !< Between the tick labels and the axis label.
real(real32),   parameter :: AXIS_RECT_MIN_WIDTH = 40.0_real32 !< An axis's hover rectangle at least.
integer(int32), parameter :: PLOT_CAP = 64_int32    !< Plots kept at most (the least recently begun then replaced).
integer(int32), parameter :: TEXT_LEN = 256_int32   !< A title's or label's slot.
type(plot3d_quat), parameter :: INITIAL_ROTATION = plot3d_quat(-0.513269_real64, -0.212596_real64, &
                                                               -0.318184_real64, 0.76819_real64) !< ImPlot3D's.

type :: axis3d
   !< An axis's state (`ImPlot3DAxis`, but for what `view3d` holds: range, scale, inversion, NDC scale).
   integer(int32)          :: flags = 0_int32        !< ImPlot3DAxisFlags.
   integer(int32)          :: prev_flags = 0_int32   !< PreviousFlags.
   integer(int32)          :: range_cond = COND_NONE !< RangeCond.
   logical                 :: fit = .true.           !< FitThisFrame.
   real(real64)            :: fit_min = 0.0_real64   !< FitExtents.
   real(real64)            :: fit_max = 0.0_real64   !< ...
   real(real64)            :: con_min = 0.0_real64   !< ConstraintRange.
   real(real64)            :: con_max = 0.0_real64   !< ...
   real(real64)            :: zoom_min = 0.0_real64  !< ConstraintZoom.
   real(real64)            :: zoom_max = 0.0_real64  !< ...
   logical                 :: hovered = .false.      !< Hovered.
   logical                 :: held = .false.         !< Held.
   logical                 :: show_default = .true.  !< ShowDefaultTicks.
   character(len=TEXT_LEN) :: label = ''             !< Label.
   integer(int32)          :: label_len = 0_int32    !< Its length (0: none).
   type(plot_format)       :: fmt                    !< Tick labels' format ("%g").
   type(ticks3d)           :: ticks                  !< Ticker.
   integer(int32)          :: col_bg = 0_int32       !< ColorBg.
   integer(int32)          :: col_hov = 0_int32      !< ColorHov.
   integer(int32)          :: col_act = 0_int32      !< ColorAct.
endtype axis3d

type :: plot3d_spec
   !< An item's style as given (`ImPlot3DSpec` without its per-point arrays): a colour's alpha -1 is automatic, a
   !< negative weight, size or alpha the style's, the marker `ImPlot3DMarker_Auto` (-1) the style's.
   real(real32)   :: line_color(4) = [0.0_real32, 0.0_real32, 0.0_real32, -1.0_real32]        !< LineColor.
   real(real32)   :: line_weight = 1.0_real32                                                 !< LineWeight.
   real(real32)   :: fill_color(4) = [0.0_real32, 0.0_real32, 0.0_real32, -1.0_real32]        !< FillColor.
   real(real32)   :: fill_alpha = -1.0_real32                                                 !< FillAlpha.
   integer(int32) :: marker = -1_int32                                                        !< Marker.
   real(real32)   :: marker_size = -1.0_real32                                                !< MarkerSize.
   real(real32)   :: marker_line_color(4) = [0.0_real32, 0.0_real32, 0.0_real32, -1.0_real32] !< MarkerLineColor.
   real(real32)   :: marker_fill_color(4) = [0.0_real32, 0.0_real32, 0.0_real32, -1.0_real32] !< MarkerFillColor.
   integer(int32) :: flags = 0_int32                                                          !< Flags.
endtype plot3d_spec

type :: item3d_style
   !< An item's style as `BeginItem` stages it (`ImPlot3DNextItemData`).
   real(real32)   :: line_color(4) = 0.0_real32  !< LineColor.
   real(real32)   :: fill_color(4) = 0.0_real32  !< FillColor (times FillAlpha).
   real(real32)   :: mline_color(4) = 0.0_real32 !< MarkerLineColor.
   real(real32)   :: mfill_color(4) = 0.0_real32 !< MarkerFillColor (times FillAlpha).
   real(real32)   :: line_weight = 1.0_real32    !< LineWeight.
   real(real32)   :: marker_size = 4.0_real32    !< MarkerSize.
   real(real32)   :: fill_alpha = 1.0_real32     !< FillAlpha.
   integer(int32) :: marker = M3_NONE            !< Marker.
   logical        :: auto_line = .false.         !< IsAutoLine.
   logical        :: auto_fill = .false.         !< IsAutoFill.
   logical        :: render_line = .false.       !< RenderLine.
   logical        :: render_fill = .false.       !< RenderFill.
   logical        :: render_mline = .false.      !< RenderMarkerLine.
   logical        :: render_mfill = .false.      !< RenderMarkerFill.
   integer(int32) :: color = 0_int32             !< The item's colour (packed).
endtype item3d_style

type :: item3d
   !< An item kept between frames (`ImPlot3DItem`).
   integer(int32)          :: id = 0_int32          !< ID.
   integer(int32)          :: color = 0_int32       !< Colour (packed).
   logical                 :: show = .true.         !< Shown.
   logical                 :: legend_hovered = .false. !< Its legend entry hovered.
   logical                 :: seen = .false.        !< SeenThisFrame.
   character(len=TEXT_LEN) :: name = ''             !< Legend label (its first name_len characters).
   integer(int32)          :: name_len = 0_int32    !< Its length.
endtype item3d

type :: plot3d_record
   !< A 3-D plot kept between frames (`ImPlot3DPlot`).
   logical                 :: used = .false.          !< Slot in use.
   integer(int32)          :: id = 0_int32            !< ID.
   integer(int32)          :: last_frame = -1_int32   !< Last frame begun.
   integer(int32)          :: flags = 0_int32         !< ImPlot3DFlags.
   integer(int32)          :: prev_flags = 0_int32    !< PreviousFlags.
   character(len=TEXT_LEN) :: title = ''              !< Title (its shown part).
   integer(int32)          :: title_len = 0_int32     !< Its length (0: none).
   logical                 :: just_created = .true.   !< JustCreated.
   logical                 :: initialized = .false.   !< Initialized.
   logical                 :: setup_locked = .false.  !< SetupLocked.
   logical                 :: fit = .true.            !< FitThisFrame.
   logical                 :: hovered = .false.       !< Hovered.
   logical                 :: held = .false.          !< Held.
   integer(int32)          :: held_edge = -1_int32    !< HeldEdgeIdx.
   integer(int32)          :: held_plane = -1_int32   !< HeldPlaneIdx.
   integer(int32)          :: rotation_cond = COND_NONE !< RotationCond.
   real(real32)            :: frame(4) = 0.0_real32   !< FrameRect.
   real(real32)            :: canvas(4) = 0.0_real32  !< CanvasRect.
   type(view3d)            :: v                       !< Rotation, PlotRect, the axes' ranges and scales.
   type(plot3d_quat)       :: initial_rotation        !< InitialRotation (INITIAL_ROTATION, set by plot_handle).
   type(plot3d_quat)       :: anim_end                !< RotationAnimationEnd.
   real(real32)            :: anim_time = 0.0_real32  !< AnimationTime.
   real(real64)            :: drag_axis(3) = 0.0_real64 !< DragRotationAxis.
   logical                 :: context_click = .false. !< ContextClick.
   logical                 :: open_context = .false.  !< OpenContextThisFrame.
   type(axis3d)            :: ax(3)                   !< Axes.
   integer(int32)          :: legend_loc = LOC_NORTH + LOC_WEST !< Legend.Location.
   integer(int32)          :: legend_prev_loc = LOC_NORTH + LOC_WEST !< Legend.PreviousLocation.
   integer(int32)          :: legend_flags = 0_int32  !< Legend.Flags.
   integer(int32)          :: legend_prev_flags = 0_int32 !< Legend.PreviousFlags.
   type(item3d), allocatable :: it(:)                 !< Items (ImPlot3DItemGroup::ItemPool).
   integer(int32)          :: n_items = 0_int32       !< Items in the pool.
   integer(int32), allocatable :: leg(:)              !< Legend entries of this frame (items' indices).
   integer(int32)          :: n_leg = 0_int32         !< Entries.
   integer(int32)          :: colormap_idx = 0_int32  !< ColormapIdx.
   real(real32)            :: leg_rect(4) = 0.0_real32 !< Legend.Rect.
   real(real32)            :: leg_clamped(4) = 0.0_real32 !< Legend.RectClamped.
   real(real32)            :: leg_scroll(2) = 0.0_real32 !< Legend.Scroll.
   logical                 :: leg_hovered = .false.   !< Legend.Hovered.
   logical                 :: leg_held = .false.      !< Legend.Held.
endtype plot3d_record

type(plot3d_record), allocatable, target :: plots(:) !< The plots (ImPlot3DContext::Plots).
integer(int32)                           :: n_plots = 0_int32 !< Slots in use or freed.
integer(int32)                           :: cur = 0_int32     !< The plot begun, 0 none (handle, never a pointer).
character(len=128)                       :: mouse_text = ''   !< The mouse position's text.
real(real64)                             :: right_click_time = -huge(1.0_real64) !< io.MouseClickedTime[1], as seen by
                                                              !< the 3-D plots (the time of the frame of a right click).
integer(int32)                           :: cur_item = 0_int32 !< The item begun (handle in the plot's pool), 0 none.
integer(int32)                           :: cmap3 = CM_DEEP   !< ImPlot3DStyle::Colormap in effect (FIGURE's ids).
integer(int32)                           :: cmap3_saved = CM_DEEP !< The one before a push.

contains
   ! begin and end

   function pf3_begin_plot(title, width, height, equal) result(visible)
   !< Begin a 3-D plot (`BeginPlot`), as `ip3_begin_plot`: its frame at the cursor, `width` x `height` pixels (default:
   !< the full width, ImPlot3D's default height); `equal`: the same units per NDC unit on the three axes. When true,
   !< declare its content and call `pf3_end_plot`.
   character(len=*), intent(in)           :: title   !< Title (also the plot's ID).
   real(real64),     intent(in), optional :: width   !< Width [pixels].
   real(real64),     intent(in), optional :: height  !< Height [pixels].
   logical,          intent(in), optional :: equal   !< Same scale on the three axes.
   logical                                :: visible !< Plot visible.
   real(real32)                           :: req(2), ext(2) !< Size asked, frame's size.
   real(real64)                           :: cx, cy, aw, ah !< Cursor, room left.
   integer(int32)                         :: id, h, flags, i, n !< ID, handle, ImPlot3DFlags, axis, title's length.
   logical                                :: created !< The plot is new.

   visible = .false.
   if (cur /= 0_int32) error stop 'figure_plot3d_frame: pf3_begin_plot while a 3-D plot is open'
   flags = 0_int32
   if (present(equal)) then
      if (equal) flags = F3_EQUAL
   endif
   id = core_get_id(title)
   h = plot_handle(id, core_frame_count(), created)
   associate(p => plots(h))
      p%last_frame = core_frame_count()
      p%just_created = created
      if (created) then
         p%v%rot = p%initial_rotation
         p%fit = .true.
         do i = 1_int32, 3_int32
            call axis_defaults(p, i)
         enddo
      endif
      if (p%prev_flags /= flags) p%flags = flags
      p%prev_flags = flags
      p%setup_locked = .false.
      p%open_context = .false.
      p%rotation_cond = COND_NONE
      n = rendered_len(title) ! SetTitle: kept when something shows before '##'
      p%title_len = 0_int32
      if (n > 0_int32) then
         p%title_len = min(len(title, kind=int32), TEXT_LEN)
         p%title(1:p%title_len) = title(1:p%title_len)
      endif
      req(1) = -1.0_real32
      req(2) = 0.0_real32
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
      p%frame(1) = real(cx, real32)
      p%frame(2) = real(cy, real32)
      p%frame(3) = p%frame(1) + ext(1)
      p%frame(4) = p%frame(2) + ext(2)
      call core_item_size(real(p%frame(3) - p%frame(1), real64), real(p%frame(4) - p%frame(2), real64))
      if (.not. core_item_add(real(p%frame(1), real64), real(p%frame(2), real64), real(p%frame(3), real64), &
                              real(p%frame(4), real64), id)) return
      p%n_leg = 0_int32 ! Legend.Reset
      do i = 1_int32, 3_int32 ! ImPlot3DAxis::Reset
         call axis_reset(p, i)
      enddo
      call d3_reset()
      call core_draw_begin() ! the window's draw list (`PushClipRect` on it): the list figure_core draws on now, not
                             ! the last window's (a 3-D plot first in its window pushed there: its end popped this one)
      call core_push_clip_rect(real(p%frame(1), real64), real(p%frame(2), real64), real(p%frame(3), real64), &
                               real(p%frame(4), real64), intersect=.true.)
      call core_draw_end()
   endassociate
   cur = h
   visible = .true.
   endfunction pf3_begin_plot

   subroutine pf3_end_plot()
   !< End the 3-D plot (`EndPlot`): the fit (each axis to fit on its own, or, `Equal`, the others to the widest), the
   !< setup locked if no item did it, the clips popped, the mouse position's text.
   integer(int32) :: i, ref       !< Axis, the reference axis.
   real(real64)   :: asp, max_asp !< An axis's aspect, the largest.

   if (cur == 0_int32) error stop 'figure_plot3d_frame: pf3_end_plot without a 3-D plot'
   associate(p => plots(cur))
      call core_draw_begin() ! SortedMoveToImGuiDrawList
      call d3_flush()
      call core_draw_end()
      if (p%fit) then
         p%fit = .false.
         if (.not. has_flag(p%flags, F3_EQUAL)) then
            do i = 1_int32, 3_int32
               if (p%ax(i)%fit) then
                  p%ax(i)%fit = .false.
                  call apply_fit(p, i)
               endif
            enddo
         else
            ref = 1_int32
            max_asp = 0.0_real64
            do i = 1_int32, 3_int32
               if (p%ax(i)%fit) then
                  p%ax(i)%fit = .false.
                  call apply_fit(p, i)
                  asp = get_aspect(p, i)
                  if (asp > max_asp) then
                     max_asp = asp
                     ref = i
                  endif
               endif
            enddo
            call apply_equal_aspect(p, ref)
         endif
      endif
      call setup_lock(p)
      call core_pop_clip_rect() ! the plot rectangle
      p%leg_hovered = .false.
      call render_legend(p)
      call mouse_position(p)
      call context_menus(p)
      call core_pop_clip_rect() ! the frame
      do i = 1_int32, p%n_items
         p%it(i)%seen = .false.
      enddo
   endassociate
   cur = 0_int32
   cur_item = 0_int32
   endsubroutine pf3_end_plot

   ! setup

   subroutine pf3_setup_axes(xlabel, ylabel, zlabel, auto_fit, limits, elevation, azimuth)
   !< As `ip3_setup_axes`: `SetupAxes` (the labels, AutoFit on the three or none), then `SetupAxesLimits` once and
   !< `SetupBoxRotation` once with `SetupBoxInitialRotation` (elevation and azimuth in degrees).
   character(len=*), intent(in)           :: xlabel, ylabel, zlabel !< Labels.
   logical,          intent(in), optional :: auto_fit  !< Fit the data every frame.
   real(real64),     intent(in), optional :: limits(:) !< [xmin, xmax, ymin, ymax, zmin, zmax].
   real(real64),     intent(in), optional :: elevation !< Elevation [degrees].
   real(real64),     intent(in), optional :: azimuth   !< Azimuth [degrees].
   integer(int32)                         :: flags, i  !< ImPlot3DAxisFlags, axis.

   call setup_refused('pf3_setup_axes')
   if (present(elevation) .neqv. present(azimuth)) error stop 'figure_plot3d_frame: pf3_setup_axes: both angles or neither'
   flags = 0_int32
   if (present(auto_fit)) then
      if (auto_fit) flags = A3_AUTO_FIT
   endif
   associate(p => plots(cur))
      call setup_axis(p, 1_int32, xlabel, flags)
      call setup_axis(p, 2_int32, ylabel, flags)
      call setup_axis(p, 3_int32, zlabel, flags)
      if (present(limits)) then
         if (size(limits) /= 6) error stop 'figure_plot3d_frame: pf3_setup_axes: limits needs 6 values'
         do i = 1_int32, 3_int32
            call setup_axis_limits(p, i, limits(2_int32 * i - 1_int32), limits(2_int32 * i), COND_ONCE)
         enddo
         p%fit = .false. ! SetupAxesLimits with ImPlot3DCond_Once
      endif
      if (present(elevation)) then
         call setup_box_rotation(p, quat_el_az_degrees(elevation, azimuth), .false., COND_ONCE)
         p%initial_rotation = quat_el_az_degrees(elevation, azimuth)
      endif
   endassociate
   endsubroutine pf3_setup_axes

   subroutine pf3_setup_axis(axis, label, scale, auto_fit, invert, lock, no_grid, format)
   !< As `ip3_setup_axis` (`SetupAxis`, `SetupAxisScale`, `SetupAxisFormat`): one axis's label, scale ('linear',
   !< 'log', 'symlog'), flags and tick labels' printf format ('x', 'y' or 'z').
   character(len=*), intent(in)           :: axis     !< 'x', 'y' or 'z'.
   character(len=*), intent(in), optional :: label    !< Label (default: none).
   character(len=*), intent(in), optional :: scale    !< 'linear' (default), 'log', 'symlog'.
   logical,          intent(in), optional :: auto_fit !< Fit the data every frame.
   logical,          intent(in), optional :: invert   !< Values grow the other way.
   logical,          intent(in), optional :: lock     !< No pan or zoom by the user.
   logical,          intent(in), optional :: no_grid  !< No grid lines.
   character(len=*), intent(in), optional :: format   !< printf format of the tick labels (one real).
   integer(int32)                         :: i, flags !< Axis, ImPlot3DAxisFlags.

   call setup_refused('pf3_setup_axis')
   i = axis_index(axis)
   flags = 0_int32
   if (opt(auto_fit)) flags = ior(flags, A3_AUTO_FIT)
   if (opt(invert)) flags = ior(flags, A3_INVERT)
   if (opt(lock)) flags = ior(flags, ior(A3_LOCK_MIN, A3_LOCK_MAX))
   if (opt(no_grid)) flags = ior(flags, A3_NO_GRID)
   associate(p => plots(cur))
      if (present(label)) then
         call setup_axis(p, i, label, flags)
      else
         call setup_axis(p, i, '', flags)
      endif
      if (present(scale)) then
         select case (scale)
         case ('linear')
         case ('log') ! SetupAxisScale(ImPlot3DScale_Log10)
            p%v%scale(i) = SCALE3_LOG10
            p%ax(i)%con_min = real(tiny(1.0_real32), real64)
            p%ax(i)%con_max = ieee_value(1.0_real64, ieee_positive_inf)
         case ('symlog')
            p%v%scale(i) = SCALE3_SYMLOG
            p%ax(i)%con_min = ieee_value(1.0_real64, ieee_negative_inf)
            p%ax(i)%con_max = ieee_value(1.0_real64, ieee_positive_inf)
         case default
            error stop "figure_plot3d_frame: pf3_setup_axis: a scale is 'linear', 'log' or 'symlog'"
         endselect
         if (scale /= 'linear') then ! SetupAxisScale's end (FIGURE's ImPlot3D patch 0003): Constrain,
            call constrain(p, i)     ! UpdateTransformCache
            call update_scaled(p, i)
         endif
      endif
      if (present(format)) call fmt_parse(format, p%ax(i)%fmt)
   endassociate
   endsubroutine pf3_setup_axis

   subroutine pf3_setup_axis_ticks(axis, values, labels)
   !< As `ip3_setup_axis_ticks` (`SetupAxisTicks`, the default ticks off): ticks at the given values (minor ticks,
   !< labelled), labelled `labels` (trailing blanks not shown) or through the axis's format.
   character(len=*), intent(in)           :: axis      !< 'x', 'y' or 'z'.
   real(real64),     intent(in)           :: values(:) !< Tick positions.
   character(len=*), intent(in), optional :: labels(:) !< One label per value.
   integer(int32)                         :: i, k      !< Axis, tick.

   call setup_refused('pf3_setup_axis_ticks')
   i = axis_index(axis)
   if (present(labels)) then
      if (size(labels) /= size(values)) error stop 'figure_plot3d_frame: pf3_setup_axis_ticks: one label per value'
   endif
   associate(ax => plots(cur)%ax(i))
      ax%show_default = .false.
      do k = 1_int32, size(values, kind=int32)
         if (present(labels)) then
            call ticks3_add(ax%ticks, values(k), .false., .true., ax%fmt, label=labels(k)(1:len_trim(labels(k))))
         else
            call ticks3_add(ax%ticks, values(k), .false., .true., ax%fmt)
         endif
      enddo
   endassociate
   endsubroutine pf3_setup_axis_ticks

   subroutine pf3_setup_box(scale, elevation, azimuth, animate)
   !< As `ip3_setup_box`: `SetupBoxScale` and `SetupBoxRotation` always (degrees), at once or animated.
   real(real64), intent(in), optional :: scale(:)  !< Relative sides [x, y, z].
   real(real64), intent(in), optional :: elevation !< Elevation [degrees].
   real(real64), intent(in), optional :: azimuth   !< Azimuth [degrees].
   logical,      intent(in), optional :: animate   !< Turn there smoothly.

   call setup_refused('pf3_setup_box')
   if (present(elevation) .neqv. present(azimuth)) error stop 'figure_plot3d_frame: pf3_setup_box: both angles or neither'
   associate(p => plots(cur))
      if (present(scale)) then
         if (size(scale) /= 3 .or. .not. all(scale > 0.0_real64)) &
            error stop 'figure_plot3d_frame: pf3_setup_box: scale needs 3 values above 0'
         p%v%ndc(1) = scale(1)
         p%v%ndc(2) = scale(2)
         p%v%ndc(3) = scale(3)
      endif
      if (present(elevation)) call setup_box_rotation(p, quat_el_az_degrees(elevation, azimuth), opt(animate), COND_ALWAYS)
   endassociate
   endsubroutine pf3_setup_box

   subroutine pf3_setup_legend(location, horizontal, no_buttons)
   !< As `ip3_setup_legend` (`SetupLegend`): a compass point ('n', 'ne', ..., 'nw' default, 'c'), entries in a row,
   !< entries that do not hide their items.
   character(len=*), intent(in), optional :: location   !< Compass point.
   logical,          intent(in), optional :: horizontal !< Entries in a row.
   logical,          intent(in), optional :: no_buttons !< Entries do not hide their items.
   integer(int32)                         :: loc, flags !< ImPlot3DLocation, ImPlot3DLegendFlags.

   call setup_refused('pf3_setup_legend')
   loc = LOC_NORTH + LOC_WEST
   if (present(location)) then
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
         error stop 'figure_plot3d_frame: pf3_setup_legend: an unknown location'
      endselect
   endif
   flags = 0_int32
   if (opt(no_buttons)) flags = ior(flags, 1_int32)
   if (opt(horizontal)) flags = ior(flags, 4_int32)
   associate(p => plots(cur))
      if (p%legend_prev_loc /= loc) p%legend_loc = loc
      p%legend_prev_loc = loc
      if (p%legend_prev_flags /= flags) p%legend_flags = flags
      p%legend_prev_flags = flags
   endassociate
   endsubroutine pf3_setup_legend

   ! queries

   subroutine pf3_plot_to_pixels(x, y, z, px, py)
   !< As `ip3_plot_to_pixels` (`PlotToPixels`, which locks the setup): the pixel of a plot point as the box turns now.
   real(real64), intent(in)  :: x, y, z !< Plot point.
   real(real64), intent(out) :: px, py  !< Pixel.
   real(real64)              :: p(3)    !< The point.
   real(real32)              :: qx, qy  !< Its pixel.

   if (cur == 0_int32) error stop 'figure_plot3d_frame: pf3_plot_to_pixels outside a 3-D plot'
   call setup_lock(plots(cur))
   p(1) = x
   p(2) = y
   p(3) = z
   call plot_to_pixels(plots(cur)%v, p, qx, qy)
   px = real(qx, real64)
   py = real(qy, real64)
   endsubroutine pf3_plot_to_pixels

   function pf3_mouse_ray(origin, direction) result(over)
   !< As `ip3_mouse_ray` (FIGURE's `fig_plot3d_mouse_ray`: `PixelsToPlotRay` of the pointer, its direction normalised
   !< again): true when the pointer is over the plot rectangle; zeros without a pointer.
   real(real64), intent(out) :: origin(3)    !< A point of the ray.
   real(real64), intent(out) :: direction(3) !< Its direction (unit).
   logical                   :: over         !< Over the plot.
   type(vector_R8P)          :: o, d, po, pd !< NDC and plot rays.
   real(real64)              :: mx, my, n    !< Pointer, length.
   real(real32)              :: fx, fy       !< Pointer (floats).

   if (cur == 0_int32) error stop 'figure_plot3d_frame: pf3_mouse_ray outside a 3-D plot'
   origin = 0.0_real64
   direction = 0.0_real64
   over = .false.
   if (.not. core_mouse_pos_valid()) return
   call core_mouse_pos(mx, my)
   fx = real(mx, real32)
   fy = real(my, real32)
   associate(p => plots(cur))
      call setup_lock(p)
      call pixels_to_ndc_ray(p%v, fx, fy, o, d)
      call ndc_ray_to_plot_ray(p%v, o, d, po, pd)
      n = sqrt(pd%sq_norm())
      if (n > 0.0_real64) then
         pd%x = pd%x / n
         pd%y = pd%y / n
         pd%z = pd%z / n
      endif
      origin(1) = po%x
      origin(2) = po%y
      origin(3) = po%z
      direction(1) = pd%x
      direction(2) = pd%y
      direction(3) = pd%z
      over = fx >= p%v%rect(1) .and. fy >= p%v%rect(2) .and. fx < p%v%rect(1) + (p%v%rect(3) - p%v%rect(1)) .and. &
             fy < p%v%rect(2) + (p%v%rect(4) - p%v%rect(2))
   endassociate
   endfunction pf3_mouse_ray

   function pf3_plot_state() result(state)
   !< The open 3-D plot's state, as FIGURE's `fig_plot3d_state` gives ImPlot3D's (the Fortran path's refusals read it):
   !< 0 no plot, 1 its setup open, 2 its setup over (`SetupLocked`).
   integer(int32) :: state !< 0, 1, 2.

   state = 0_int32
   if (cur == 0_int32) return
   state = merge(2_int32, 1_int32, plots(cur)%setup_locked)
   endfunction pf3_plot_state

   function pf3_open_id() result(id)
   !< The open 3-D plot's slot, 0 none (the scope record's snapshot, as ImPlot3D's CurrentPlot).
   integer(int32) :: id !< Slot.

   id = cur
   endfunction pf3_open_id

   subroutine pf3_plot_limits(lims)
   !< The three ranges of the open 3-D plot: [xmin, xmax, ymin, ymax, zmin, zmax].
   real(real64), intent(out) :: lims(6) !< Ranges.
   integer(int32)            :: i       !< Axis.

   if (cur == 0_int32) error stop 'figure_plot3d_frame: pf3_plot_limits outside a 3-D plot'
   do i = 1_int32, 3_int32
      lims(2_int32 * i - 1_int32) = plots(cur)%v%rmin(i)
      lims(2_int32 * i) = plots(cur)%v%rmax(i)
   enddo
   endsubroutine pf3_plot_limits

   subroutine pf3_plot_rotation(q)
   !< The open 3-D plot's rotation [x, y, z, w].
   real(real64), intent(out) :: q(4) !< Quaternion.

   if (cur == 0_int32) error stop 'figure_plot3d_frame: pf3_plot_rotation outside a 3-D plot'
   q(1) = plots(cur)%v%rot%x
   q(2) = plots(cur)%v%rot%y
   q(3) = plots(cur)%v%rot%z
   q(4) = plots(cur)%v%rot%w
   endsubroutine pf3_plot_rotation

   ! items

   function pf3_item_begin(label, spec, item_col, item_mkr, st) result(shown)
   !< `BeginItem`: the setup locked, the item registered (its legend entry this frame when its label shows), its colour
   !< (the given one, else the colormap's next when created), the style staged into `st` (automatic colours from the
   !< item's, the style's weight 1, marker none, size 4, alpha 1; `FillAlpha` on the fills; what is drawn; a hovered
   !< legend entry doubles the weight and makes the markers 1.25 times larger). False for a hidden item.
   character(len=*),   intent(in)  :: label       !< Label (its ID in the window's ID stack).
   type(plot3d_spec),  intent(in)  :: spec        !< Style given.
   real(real32),       intent(in)  :: item_col(4) !< The colour that names the item (alpha -1: automatic).
   integer(int32),     intent(in)  :: item_mkr    !< The marker that names it (unused: ImPlot3D keeps it, draws the spec's).
   type(item3d_style), intent(out) :: st          !< Staged style.
   logical                         :: shown       !< Drawn.
   integer(int32)                  :: h           !< The item.
   logical                         :: created     !< New.
   real(real32)                    :: ic(4)       !< The item's colour, unpacked.

   if (cur == 0_int32) error stop 'figure_plot3d_frame: a 3-D item outside a 3-D plot'
   shown = .false.
   associate(p => plots(cur))
      call setup_lock(p)
      h = register_item(p, label, spec%flags, created)
      cur_item = h
      if (item_col(4) /= -1.0_real32) then
         p%it(h)%color = core_color(real(item_col(1), real64), real(item_col(2), real64), real(item_col(3), real64), &
                                    real(item_col(4), real64))
      elseif (created) then
         p%it(h)%color = cm_key(cmap3, mod(p%colormap_idx, cm_size(cmap3)))
         p%colormap_idx = p%colormap_idx + 1_int32
      endif
      if (item_mkr < -2_int32) error stop 'figure_plot3d_frame: an invalid marker'
      call unpack_u32(p%it(h)%color, ic)
      st%color = p%it(h)%color
      st%auto_line = spec%line_color(4) == -1.0_real32
      st%auto_fill = spec%fill_color(4) == -1.0_real32
      st%line_color = spec%line_color
      if (st%auto_line) st%line_color = ic
      st%fill_color = spec%fill_color
      if (st%auto_fill) st%fill_color = ic
      st%mline_color = spec%marker_line_color
      if (spec%marker_line_color(4) == -1.0_real32) st%mline_color = st%line_color
      st%mfill_color = spec%marker_fill_color
      if (spec%marker_fill_color(4) == -1.0_real32) st%mfill_color = st%line_color
      st%line_weight = spec%line_weight
      if (st%line_weight < 0.0_real32) st%line_weight = s3_line_weight
      st%marker = spec%marker
      if (st%marker < 0_int32) st%marker = M3_NONE
      st%marker_size = spec%marker_size
      if (st%marker_size < 0.0_real32) st%marker_size = s3_marker_size
      st%fill_alpha = spec%fill_alpha
      if (st%fill_alpha < 0.0_real32) st%fill_alpha = s3_fill_alpha
      st%fill_color(4) = st%fill_color(4) * st%fill_alpha
      st%mfill_color(4) = st%mfill_color(4) * st%fill_alpha
      st%render_line = st%line_color(4) > 0.0_real32 .and. st%line_weight > 0.0_real32
      st%render_fill = st%fill_color(4) > 0.0_real32
      st%render_mline = st%line_color(4) > 0.0_real32 .and. st%line_weight > 0.0_real32
      st%render_mfill = st%fill_color(4) > 0.0_real32
      if (.not. p%it(h)%show) then
         cur_item = 0_int32
         return
      endif
      if (p%it(h)%legend_hovered .and. .not. has_flag(p%legend_flags, L3_NO_HIGHLIGHT)) then
         st%line_weight = st%line_weight * 2.0_real32
         st%marker_size = st%marker_size * 1.25_real32
      endif
   endassociate
   shown = .true.
   endfunction pf3_item_begin

   subroutine pf3_push_colormap(id)
   !< `PushColormap` (one deep, as figure_implot3d's surfaces push one): the colormap of the next items' colours.
   integer(int32), intent(in) :: id !< Colormap (FIGURE's id).

   cmap3_saved = cmap3
   cmap3 = id
   endsubroutine pf3_push_colormap

   subroutine pf3_pop_colormap()
   !< `PopColormap`.

   cmap3 = cmap3_saved
   endsubroutine pf3_pop_colormap

   function pf3_colormap() result(id)
   !< The colormap in effect.
   integer(int32) :: id !< Colormap.

   id = cmap3
   endfunction pf3_colormap

   subroutine pf3_item_recolor(col)
   !< `GetCurrentItem()->Color = col` (an image's tint).
   integer(int32), intent(in) :: col !< Packed colour.

   if (cur_item /= 0_int32) plots(cur)%it(cur_item)%color = col
   endsubroutine pf3_item_recolor

   subroutine pf3_text(text, x, y, z, angle, offset)
   !< As `ip3_text` (`PlotText`): a text centred on a plot point (hidden outside the cull box), turned by `angle`
   !< [radians], moved by `offset` [pixels], in InlayText; not an item.
   character(len=*), intent(in)           :: text      !< Text.
   real(real64),     intent(in)           :: x, y, z   !< Point.
   real(real64),     intent(in), optional :: angle     !< Angle [radians].
   real(real64),     intent(in), optional :: offset(2) !< Offset [pixels].
   real(real64)                           :: q(3)      !< The point.
   real(real32)                           :: px, py, a !< Its pixel, the angle.

   if (cur == 0_int32) error stop 'figure_plot3d_frame: pf3_text outside a 3-D plot'
   associate(p => plots(cur))
      call setup_lock(p)
      q(1) = x
      q(2) = y
      q(3) = z
      if (.not. has_flag(p%flags, F3_NO_CLIP)) then
         if (.not. ((x >= p%v%rmin(1) .and. x <= p%v%rmax(1)) .and. (y >= p%v%rmin(2) .and. y <= p%v%rmax(2)) .and. &
                    (z >= p%v%rmin(3) .and. z <= p%v%rmax(3)))) return
      endif
      call plot_to_pixels(p%v, q, px, py)
      if (present(offset)) then
         px = px + real(offset(1), real32)
         py = py + real(offset(2), real32)
      endif
      a = 0.0_real32
      if (present(angle)) a = real(angle, real32)
      call core_draw_begin()
      call text_rotated(px, py, a, style3_u32(S3_INLAY_TEXT), text)
      call core_draw_end()
   endassociate
   endsubroutine pf3_text

   function pf3_item_fitting(flags) result(yes)
   !< Whether the item's points extend the fit this frame (`FitThisFrame`, not `NoFit`).
   integer(int32), intent(in) :: flags !< The item's flags.
   logical                    :: yes   !< Fitting.

   yes = plots(cur)%fit .and. .not. has_flag(flags, I3_NO_FIT)
   endfunction pf3_item_fitting

   subroutine pf3_item_fit(x, y, z)
   !< `ImPlot3DPlot::ExtendFit`: each finite coordinate of an axis to fit, within its constraints.
   real(real64), intent(in) :: x, y, z !< Point.

   associate(p => plots(cur))
      call extend_fit(p, 1_int32, x)
      call extend_fit(p, 2_int32, y)
      call extend_fit(p, 3_int32, z)
   endassociate
   endsubroutine pf3_item_fit

   subroutine pf3_item_view(v, cmin, cmax, flags)
   !< What an item's renderers read: the plot's view, the cull box (its ranges, unbounded with `NoClip`), its flags.
   type(view3d),   intent(out) :: v       !< View.
   real(real64),   intent(out) :: cmin(3) !< Cull box's minima.
   real(real64),   intent(out) :: cmax(3) !< ... maxima.
   integer(int32), intent(out) :: flags   !< ImPlot3DFlags.

   v = plots(cur)%v
   flags = plots(cur)%flags
   if (has_flag(flags, F3_NO_CLIP)) then
      cmin = ieee_value(1.0_real64, ieee_negative_inf)
      cmax = ieee_value(1.0_real64, ieee_positive_inf)
   else
      cmin = v%rmin
      cmax = v%rmax
   endif
   endsubroutine pf3_item_view

   subroutine pf3_item_end()
   !< `EndItem`.

   cur_item = 0_int32
   endsubroutine pf3_item_end

   ! private: setup

   subroutine setup_refused(name)
   !< Error stop unless a 3-D plot is open and its setup not locked.
   character(len=*), intent(in) :: name !< The procedure.

   if (cur == 0_int32) error stop 'figure_plot3d_frame: a setup call outside a 3-D plot'
   if (plots(cur)%setup_locked) then
      write(*, '(A)') 'figure_plot3d_frame: '//name//' after the setup is over'
      error stop 1
   endif
   endsubroutine setup_refused

   subroutine setup_axis(p, i, label, flags)
   !< `SetupAxis`: the flags (taken when they change), the label (kept when something shows before '##').
   type(plot3d_record), intent(inout) :: p     !< Plot.
   integer(int32),      intent(in)    :: i     !< Axis.
   character(len=*),    intent(in)    :: label !< Label.
   integer(int32),      intent(in)    :: flags !< ImPlot3DAxisFlags.

   if (p%ax(i)%prev_flags /= flags) p%ax(i)%flags = flags
   p%ax(i)%prev_flags = flags
   p%v%invert(i) = has_flag(p%ax(i)%flags, A3_INVERT)
   p%ax(i)%label_len = 0_int32
   if (rendered_len(label) > 0_int32) then
      p%ax(i)%label_len = min(len(label, kind=int32), TEXT_LEN)
      p%ax(i)%label(1:p%ax(i)%label_len) = label(1:p%ax(i)%label_len)
   endif
   endsubroutine setup_axis

   subroutine setup_axis_limits(p, i, vmin, vmax, cond)
   !< `SetupAxisLimits`: the range set, its condition kept, no fit, on the first frame or always.
   type(plot3d_record), intent(inout) :: p          !< Plot.
   integer(int32),      intent(in)    :: i          !< Axis.
   real(real64),        intent(in)    :: vmin, vmax !< Range.
   integer(int32),      intent(in)    :: cond       !< ImPlot3DCond.

   if (.not. p%initialized .or. cond == COND_ALWAYS) then
      call set_range(p, i, vmin, vmax)
      p%ax(i)%range_cond = cond
      p%ax(i)%fit = .false.
      if (has_flag(p%flags, F3_EQUAL)) call apply_equal_aspect(p, i)
   endif
   endsubroutine setup_axis_limits

   subroutine setup_box_rotation(p, q, animate, cond)
   !< `SetupBoxRotation` (no animation yet): the rotation, on the first frame or always.
   type(plot3d_record), intent(inout) :: p       !< Plot.
   type(plot3d_quat),   intent(in)    :: q       !< Rotation.
   logical,             intent(in)    :: animate !< Turn there smoothly.
   integer(int32),      intent(in)    :: cond    !< ImPlot3DCond.

   if (.not. p%initialized .or. cond == COND_ALWAYS) then
      if (.not. animate) then
         p%v%rot = q
         p%anim_time = 0.0_real32
      else
         p%anim_end = q
         p%anim_time = animation_time(p%v%rot, p%anim_end)
      endif
      p%rotation_cond = cond
   endif
   endsubroutine setup_box_rotation

   function quat_el_az_degrees(elevation, azimuth) result(q)
   !< `SetupBoxRotation(elevation, azimuth)`'s conversion: degrees times IM_PI (a float) over 180, then `FromElAz`.
   real(real64), intent(in) :: elevation, azimuth !< Angles [degrees].
   type(plot3d_quat)        :: q                  !< Rotation.

   q = quat_from_el_az(elevation * real(IM_PI_F, real64) / 180.0_real64, azimuth * real(IM_PI_F, real64) / 180.0_real64)
   endfunction quat_el_az_degrees

   subroutine setup_lock(p)
   !< `SetupLock`: once per frame, before the first item (or at the end): the frame's background, the canvas and plot
   !< rectangles, `Equal`'s aspect, the ticks, the axes' colours, the title, the input, the plot clip and the box.
   type(plot3d_record), intent(inout) :: p   !< Plot.
   real(real64)                       :: xar, yar, zar, asp, w, h !< Aspects, text size.
   real(real32)                       :: pixels, cx !< An axis's length, the frame's centre.
   real(real32)                       :: dtf, tf    !< Animation's step, fraction.
   integer(int32)                     :: i   !< Axis.

   if (p%setup_locked) return
   p%setup_locked = .true.
   call core_draw_begin()
   call core_draw_rect_filled(real(p%frame(1), real64), real(p%frame(2), real64), real(p%frame(3), real64), &
                              real(p%frame(4), real64), style3_u32(S3_FRAME_BG))
   p%v%factor = s3_view_factor ! GetViewScale reads the style's factor
   p%canvas(1:2) = p%frame(1:2) + PLOT_PADDING
   p%canvas(3:4) = p%frame(3:4) - PLOT_PADDING
   p%v%rect = p%canvas
   if (has_flag(p%flags, F3_EQUAL)) then
      xar = get_aspect(p, 1_int32)
      yar = get_aspect(p, 2_int32)
      zar = get_aspect(p, 3_int32)
      if (.not. almost_equal(xar, yar) .or. .not. almost_equal(xar, zar)) then
         asp = (xar + yar + zar) / 3.0_real64
         call set_aspect(p, 1_int32, asp)
         call set_aspect(p, 2_int32, asp)
         call set_aspect(p, 3_int32, asp)
      endif
   endif
   do i = 1_int32, 3_int32
      p%v%invert(i) = has_flag(p%ax(i)%flags, A3_INVERT) ! (the axis menu flips the flag)
      if (p%ax(i)%show_default) then
         pixels = real(real(view_scale(p%v), real64) * p%v%ndc(i), real32)
         select case (p%v%scale(i))
         case (SCALE3_LOG10)
            call locate3_log10(p%ax(i)%ticks, p%v%rmin(i), p%v%rmax(i), pixels, p%ax(i)%fmt)
         case (SCALE3_SYMLOG)
            call locate3_symlog(p%ax(i)%ticks, p%v%rmin(i), p%v%rmax(i), pixels, p%ax(i)%fmt)
         case default
            call locate3_default(p%ax(i)%ticks, p%v%rmin(i), p%v%rmax(i), pixels, p%ax(i)%fmt)
         endselect
      endif
      p%ax(i)%col_bg = style3_u32(S3_AXIS_BG)
      p%ax(i)%col_hov = style3_u32(S3_AXIS_BG_HOVERED)
      p%ax(i)%col_act = style3_u32(S3_AXIS_BG_ACTIVE)
   enddo
   if (p%title_len > 0_int32 .and. .not. has_flag(p%flags, F3_NO_TITLE)) then ! AddTextCentered
      cx = (p%frame(1) + p%frame(3)) * 0.5_real32
      call core_text_size(p%title(1:p%title_len), w, h, hide_after_hash=.true.)
      call core_draw_text(real(cx - real(w, real32) * 0.5_real32, real64), real(p%canvas(2), real64), &
                          style3_u32(S3_TITLE_TEXT), p%title(1:rendered_len(p%title(1:p%title_len))))
      p%v%rect(2) = p%v%rect(2) + (real(core_font_size(), real32) + LABEL_PADDING(2))
   endif
   if (p%anim_time > 0.0_real32) then ! the animation
      dtf = real(core_delta_time(), real32)
      tf = dtf / p%anim_time
      tf = min(max(tf, 0.0_real32), 1.0_real32)
      p%anim_time = p%anim_time - dtf
      if (p%anim_time < 0.0_real32) p%anim_time = 0.0_real32
      p%v%rot = quat_slerp(p%v%rot, p%anim_end, real(tf, real64))
   endif
   p%initialized = .true.
   call handle_input(p)
   call core_draw_end()
   call core_push_clip_rect(real(p%v%rect(1), real64), real(p%v%rect(2), real64), real(p%v%rect(3), real64), &
                            real(p%v%rect(4), real64), intersect=.true.)
   call core_draw_begin()
   call render_box(p)
   call core_draw_end()
   endsubroutine setup_lock

   subroutine handle_input(p)
   !< `HandleInput`: the plot's button; the plane, axis and edge under the pointer and the axes hovered or held; the
   !< plane the pointer's position is read on; a double click fits the hovered axes; pan (the whole box through the
   !< inverse rotation, or the hovered axes through the plane), a right double click animates to the initial rotation
   !< or to the hovered face, a right drag turns the box (about z or -z, then x), the wheel or a middle drag zooms
   !< (about the pointer on a plane or an axis, else about the centre); `Equal` kept; the context click and the popup
   !< it opens.
   type(plot3d_record), intent(inout) :: p !< Plot.
   integer(int32)                     :: i, hp, hpi, ha, he, plane_2d, mplane, cur_edge, f0, f1, ref, best !< Work.
   integer(int32)                     :: ac(0:1, 0:2) !< Axis corners.
   logical                            :: af(3), clicked, rotating, axis_equal, allow_rotate, allow_pan, allow_zoom !< Work.
   logical                            :: any_held, all_hov, increasing, f0_active, f1_active, found, zoom_mouse, valid !<
                                                                                                                    !< ...
   real(real32)                       :: cp(2, 0:7), mx, my, rdx, rdy, zoom, ax_, ay_, delta, dmin, dmax !< Work.
   real(real32)                       :: pmin(2), pmax(2), mpix(2), cand(4) !< Pixels, candidates' dots.
   real(real64)                       :: c(3, 0:7), dx, dy, wheel, wheel_h, drag(5), mpos(3), q(3), q2(3), nmin(3), &
                                         nmax(3), half, v1, v2, nlo, nhi, ang_x, ang_y, ndc_limit, zf !< Work.
   integer(int32)                     :: mods !< io.KeyMods.
   logical                            :: dd   !< io.
   type(vector_R8P)                   :: dpix, dndc, an, up, xa, ya, nxa, nya, ez, bestv !< Vectors.
   type(plot3d_quat)                  :: qa, qb !< Rotations.

   if (has_flag(p%flags, F3_NO_INPUTS)) return
   clicked = core_button_behavior(real(p%v%rect(1), real64), real(p%v%rect(2), real64), real(p%v%rect(3), real64), &
                                  real(p%v%rect(4), real64), p%id, p%hovered, p%held, flags=PLOT_BUTTON_FLAGS)
   if (core_mouse_clicked(1_int32)) right_click_time = core_time()
   call core_mouse_drag_delta(1_int32, dx, dy)
   rdx = real(dx, real32)
   rdy = real(dy, real32)
   rotating = rdx * rdx + rdy * rdy > 5.0_real32
   axis_equal = has_flag(p%flags, F3_EQUAL)
   allow_rotate = .not. has_flag(p%flags, F3_NO_ROTATE)
   allow_pan = .not. has_flag(p%flags, F3_NO_PAN)
   allow_zoom = .not. has_flag(p%flags, F3_NO_ZOOM)
   call axes_parameters(p%v, af, cp, c, plane_2d, ac)
   valid = pointer(mx, my)
   hp = -1_int32
   he = -1_int32
   ha = -1_int32
   if (valid) then
      hp = mouse_over_plane(af, cp, mx, my)
      ha = over_axis(p, cp, plane_2d, ac, mx, my, he)
   endif
   hpi = hp
   if (ha /= -1_int32) then
      hpi = -1_int32
      hp = -1_int32
   endif
   if (.not. core_mouse_down(0_int32) .and. .not. core_mouse_down(2_int32)) then
      do i = 1_int32, 3_int32
         p%ax(i)%held = .false.
      enddo
   endif
   if (.not. p%held) then
      p%held_edge = -1_int32
      p%held_plane = -1_int32
   endif
   any_held = p%ax(1)%held .or. p%ax(2)%held .or. p%ax(3)%held
   if (.not. any_held) then
      do i = 1_int32, 3_int32
         p%ax(i)%hovered = .false.
      enddo
      if (ha /= -1_int32) then
         p%ax(ha + 1_int32)%hovered = .true.
      elseif (hp /= -1_int32) then
         p%ax(mod(hp + 1_int32, 3_int32) + 1_int32)%hovered = .true.
         p%ax(mod(hp + 2_int32, 3_int32) + 1_int32)%hovered = .true.
      else
         do i = 1_int32, 3_int32
            p%ax(i)%hovered = .true.
         enddo
      endif
   endif
   mplane = 2_int32
   if (plane_2d /= -1_int32) then
      mplane = plane_2d
   elseif (p%ax(2)%hovered .and. p%ax(3)%hovered) then
      mplane = 0_int32
   elseif (p%ax(1)%hovered .and. p%ax(3)%hovered) then
      mplane = 1_int32
   elseif (p%ax(1)%hovered .and. p%ax(2)%hovered) then
      mplane = 2_int32
   elseif (p%held_edge /= -1_int32 .or. he /= -1_int32) then
      cur_edge = he
      if (p%held_edge /= -1_int32) cur_edge = p%held_edge
      f0 = EDGE_TO_FACES(0, 0, cur_edge)
      f1 = EDGE_TO_FACES(0, 1, cur_edge)
      if (f0 < 3_int32) then
         f0_active = .not. af(f0 + 1_int32)
      else
         f0_active = af(f0 - 2_int32)
      endif
      if (f1 < 3_int32) then
         f1_active = .not. af(f1 + 1_int32)
      else
         f1_active = af(f1 - 2_int32)
      endif
      if (f0_active) then
         mplane = EDGE_TO_FACES(1, 0, cur_edge)
      elseif (f1_active) then
         mplane = EDGE_TO_FACES(1, 1, cur_edge)
      else
         mplane = EDGE_TO_FACES(1, 0, cur_edge)
      endif
   endif
   mpos = 0.0_real64
   if (valid) call pixels_to_plot_plane(p%v, mx, my, mplane, .false., mpos, found)
   if (clicked .and. (core_mouse_double_clicked(0_int32) .or. core_mouse_double_clicked(2_int32)) .and. &
       (allow_pan .and. allow_zoom)) then
      p%fit = .true.
      do i = 1_int32, 3_int32
         p%ax(i)%fit = p%ax(i)%hovered
      enddo
   endif
   do i = 1_int32, 3_int32
      if (has_flag(p%ax(i)%flags, A3_AUTO_FIT)) then
         p%fit = .true.
         p%ax(i)%fit = .true.
      endif
   enddo
   call core_io_input(dx, dy, wheel, wheel_h, drag, mods, dd)
   if (p%held .and. core_mouse_down(0_int32) .and. allow_pan) then
      all_hov = p%ax(1)%hovered .and. p%ax(2)%hovered .and. p%ax(3)%hovered
      if (all_hov) then
         zoom = view_scale(p%v)
         dpix%x = real(real(dx, real32), real64) / real(zoom, real64)
         dpix%y = real(-real(dy, real32), real64) / real(zoom, real64)
         dpix%z = 0.0_real64 / real(zoom, real64)
         dndc = quat_rotate_v(quat_inverse(p%v%rot), dpix)
         nmin(1) = -(0.5_real64 * p%v%ndc(1)) - dndc%x
         nmax(1) = 0.5_real64 * p%v%ndc(1) - dndc%x
         nmin(2) = -(0.5_real64 * p%v%ndc(2)) - dndc%y
         nmax(2) = 0.5_real64 * p%v%ndc(2) - dndc%y
         nmin(3) = -(0.5_real64 * p%v%ndc(3)) - dndc%z
         nmax(3) = 0.5_real64 * p%v%ndc(3) - dndc%z
         call ndc_to_plot(p%v, nmin, q)
         call ndc_to_plot(p%v, nmax, q2)
         do i = 1_int32, 3_int32
            if (p%ax(i)%hovered) then
               v1 = q(i)
               v2 = q2(i)
               nlo = min(v1, v2)
               nhi = max(v1, v2)
               increasing = nlo > p%v%rmin(i)
               if ((nlo /= p%v%rmin(i) .or. nhi /= p%v%rmax(i)) .and. .not. pan_locked(p, i, increasing)) then
                  call set_range(p, i, nlo, nhi)
                  if (axis_equal) call apply_equal_aspect(p, i)
               endif
               p%ax(i)%held = .true.
            endif
            if (.not. any_held) then
               p%held_edge = he
               p%held_plane = hpi
            endif
         enddo
      elseif (p%ax(1)%hovered .or. p%ax(2)%hovered .or. p%ax(3)%hovered) then
         do i = 1_int32, 3_int32
            if (p%ax(i)%hovered) then
               q = mpos
               q2 = mpos
               q(i) = p%v%rmin(i)
               q2(i) = p%v%rmax(i)
               call plot_to_pixels(p%v, q, pmin(1), pmin(2))
               call plot_to_pixels(p%v, q2, pmax(1), pmax(2))
               pmin(1) = pmin(1) - real(dx, real32)
               pmin(2) = pmin(2) - real(dy, real32)
               pmax(1) = pmax(1) - real(dx, real32)
               pmax(2) = pmax(2) - real(dy, real32)
               call pixels_to_plot_plane(p%v, pmin(1), pmin(2), mplane, .false., nmin, found)
               call pixels_to_plot_plane(p%v, pmax(1), pmax(2), mplane, .false., nmax, found)
               nlo = nmin(i)
               nhi = nmax(i)
               increasing = nlo < p%v%rmin(i)
               if ((nlo /= p%v%rmin(i) .or. nhi /= p%v%rmax(i)) .and. .not. pan_locked(p, i, increasing)) then
                  call set_range(p, i, nlo, nhi)
                  if (axis_equal) call apply_equal_aspect(p, i)
               endif
               p%ax(i)%held = .true.
            endif
            if (.not. any_held) then
               p%held_edge = he
               p%held_plane = hpi
            endif
         enddo
      endif
   endif
   if (p%held .and. core_mouse_double_clicked(1_int32) .and. p%rotation_cond /= COND_ALWAYS .and. allow_rotate) then
      p%anim_end = p%v%rot
      if (hp == -1_int32) then
         p%anim_end = p%initial_rotation
      else
         an%x = 0.0_real64
         an%y = 0.0_real64
         an%z = 0.0_real64
         v1 = 1.0_real64
         if (af(hp + 1_int32)) v1 = -1.0_real64
         if (has_flag(p%ax(hp + 1_int32)%flags, A3_INVERT)) v1 = v1 * (-1.0_real64)
         select case (hp)
         case (0_int32)
            an%x = v1
         case (1_int32)
            an%y = v1
         case default
            an%z = v1
         endselect
         ez%x = 0.0_real64
         ez%y = 0.0_real64
         ez%z = 1.0_real64
         qa = quat_from_two_vectors(quat_rotate_v(p%anim_end, an), ez)
         p%anim_end = quat_mul(qa, p%anim_end)
         up%x = 0.0_real64
         up%y = 1.0_real64
         up%z = 0.0_real64
         if (hp /= 2_int32) then
            qb = quat_from_two_vectors(quat_rotate_v(p%anim_end, ez), up)
            p%anim_end = quat_mul(qb, p%anim_end)
         else
            an%x = 1.0_real64
            an%y = 0.0_real64
            an%z = 0.0_real64
            xa = quat_rotate_v(p%anim_end, an)
            an%x = 0.0_real64
            an%y = 1.0_real64
            ya = quat_rotate_v(p%anim_end, an)
            an%x = -1.0_real64
            an%y = 0.0_real64
            nxa = quat_rotate_v(p%anim_end, an)
            an%x = 0.0_real64
            an%y = -1.0_real64
            nya = quat_rotate_v(p%anim_end, an)
            cand(1) = real(xa .dot. up, real32)
            cand(2) = real(ya .dot. up, real32)
            cand(3) = real(nxa .dot. up, real32)
            cand(4) = real(nya .dot. up, real32)
            best = 1_int32
            do i = 2_int32, 4_int32
               if (cand(i) > cand(best)) best = i
            enddo
            select case (best)
            case (1_int32)
               bestv = xa
            case (2_int32)
               bestv = ya
            case (3_int32)
               bestv = nxa
            case default
               bestv = nya
            endselect
            qb = quat_from_two_vectors(bestv, up)
            p%anim_end = quat_mul(qb, p%anim_end)
         endif
      endif
      p%anim_time = animation_time(p%v%rot, p%anim_end)
   endif
   if (p%held .and. core_mouse_down(1_int32) .and. p%rotation_cond /= COND_ALWAYS .and. allow_rotate) then
      ang_x = real(real(dx, real32) * (3.1415_real32 / 180.0_real32), real64)
      ang_y = real(real(dy, real32) * (3.1415_real32 / 180.0_real32), real64)
      if (p%drag_axis(1) == 0.0_real64 .and. p%drag_axis(2) == 0.0_real64 .and. p%drag_axis(3) == 0.0_real64) then
         call quat_rotate(p%v%rot, 0.0_real64, 0.0_real64, 1.0_real64, q(1), q(2), q(3))
         p%drag_axis = 0.0_real64
         p%drag_axis(3) = 1.0_real64
         if (q(3) < 0.0_real64) p%drag_axis(3) = -1.0_real64
      endif
      q(1) = 1.0_real64
      q(2) = 0.0_real64
      q(3) = 0.0_real64
      qa = quat_axis_angle(ang_y, q)
      qb = quat_axis_angle(ang_x, p%drag_axis)
      p%v%rot = quat_normalize(quat_mul(quat_mul(qa, p%v%rot), qb))
   else
      p%drag_axis = 0.0_real64
   endif
   if (p%hovered .and. allow_zoom) then
      call core_set_key_owner(ImGuiKey_MouseWheelY, p%id)
      if (core_mouse_down(2_int32) .or. wheel /= 0.0_real64) then
         if (core_mouse_down(2_int32)) then
            delta = -0.01_real32 * real(dy, real32)
         else
            delta = -0.1_real32 * real(wheel, real32)
         endif
         zoom_mouse = ha /= -1_int32 .or. hp /= -1_int32
         ref = 1_int32
         do i = 1_int32, 3_int32
            if (.not. p%ax(i)%hovered .or. input_locked(p, i)) cycle
            q = mpos
            q2 = mpos
            q(i) = p%v%rmin(i)
            q2(i) = p%v%rmax(i)
            call plot_to_pixels(p%v, q, pmin(1), pmin(2))
            call plot_to_pixels(p%v, q2, pmax(1), pmax(2))
            call plot_to_pixels(p%v, mpos, mpix(1), mpix(2))
            dmin = sqrt((pmin(1) - mpix(1)) * (pmin(1) - mpix(1)) + (pmin(2) - mpix(2)) * (pmin(2) - mpix(2)))
            dmax = sqrt((pmax(1) - mpix(1)) * (pmax(1) - mpix(1)) + (pmax(2) - mpix(2)) * (pmax(2) - mpix(2)))
            if (zoom_mouse .and. (dmin > 0.0_real32 .or. dmax > 0.0_real32)) then
               ax_ = pmin(1) - mpix(1)
               ay_ = pmin(2) - mpix(2)
               pmin(1) = mpix(1) + ax_ * (1.0_real32 + delta)
               pmin(2) = mpix(2) + ay_ * (1.0_real32 + delta)
               ax_ = pmax(1) - mpix(1)
               ay_ = pmax(2) - mpix(2)
               pmax(1) = mpix(1) + ax_ * (1.0_real32 + delta)
               pmax(2) = mpix(2) + ay_ * (1.0_real32 + delta)
               call pixels_to_plot_plane(p%v, pmin(1), pmin(2), mplane, .false., nmin, found)
               call pixels_to_plot_plane(p%v, pmax(1), pmax(2), mplane, .false., nmax, found)
               call set_range(p, i, nmin(i), nmax(i))
            else
               ndc_limit = 0.5_real64 * p%v%ndc(i)
               zf = real(1.0_real32 + delta, real64)
               nmin = 0.0_real64
               nmax = 0.0_real64
               nmin(i) = -ndc_limit * zf
               nmax(i) = ndc_limit * zf
               call ndc_to_plot(p%v, nmin, q)
               call ndc_to_plot(p%v, nmax, q2)
               call set_range(p, i, q(i), q2(i))
            endif
            p%ax(i)%held = .true.
            ref = i
         enddo
         if (axis_equal) call apply_equal_aspect(p, ref)
         if (.not. any_held) then
            p%held_edge = he
            p%held_plane = hpi
         endif
      endif
   endif
   if (p%held .and. core_mouse_clicked(1_int32) .and. .not. has_flag(p%flags, F3_NO_MENUS)) p%context_click = .true.
   if (rotating .or. (core_mouse_double_clicked(1_int32) .and. allow_rotate)) p%context_click = .false.
   valid = .true.
   if (allow_rotate) valid = real(core_time() - right_click_time, real32) > 0.30_real32
   if (p%hovered .and. p%context_click .and. valid .and. .not. core_mouse_down(1_int32)) then
      p%context_click = .false.
      p%open_context = .true.
   endif
   ! a right click released on the legend: its menu (FIGURE's ImPlot3D patch 0005, as ImPlot)
   if (p%leg_hovered .and. core_mouse_released(1_int32) .and. .not. rotating .and. &
       .not. has_flag(p%flags, F3_NO_MENUS)) p%open_context = .true.
   if (p%open_context) then
      if (p%leg_hovered) then
         call core_open_popup('##LegendContext')
      elseif (ha /= -1_int32) then
         call core_open_popup(AXIS_CONTEXTS(ha))
      elseif (hp /= -1_int32) then
         call core_open_popup(PLANE_CONTEXTS(hp))
      elseif (p%hovered) then
         call core_open_popup('##PlotContext')
      endif
   endif
   endsubroutine handle_input

   function animation_time(q0, q1) result(t)
   !< `CalcAnimationTime`: the angle between two rotations (2 acosf of the dot's magnitude) over 2 * 3.1415.
   type(plot3d_quat), intent(in) :: q0, q1 !< Rotations.
   real(real32)                  :: t      !< Time [s].
   real(real64)                  :: d      !< Dot.
   real(real32)                  :: ang    !< Angle.

   d = min(max(quat_dot(q0, q1), -1.0_real64), 1.0_real64)
   ang = 2.0_real32 * c_acosf(abs(real(d, real32)))
   t = ang / ANIMATION_ANGULAR_VELOCITY
   endfunction animation_time

   pure function pan_locked(p, i, increasing) result(yes)
   !< `IsPanLocked`: with PanStretch, input-locked; else not when locked or auto-fitting, and at the constraint's end.
   type(plot3d_record), intent(in) :: p          !< Plot.
   integer(int32),      intent(in) :: i          !< Axis.
   logical,             intent(in) :: increasing !< Panning up.
   logical                         :: yes        !< Locked.

   if (has_flag(p%ax(i)%flags, A3_PAN_STRETCH)) then
      yes = input_locked(p, i)
      return
   endif
   yes = .false.
   if (locked_min(p, i) .or. locked_max(p, i) .or. has_flag(p%ax(i)%flags, A3_AUTO_FIT)) return
   if (increasing) then
      yes = p%v%rmax(i) == p%ax(i)%con_max
   else
      yes = p%v%rmin(i) == p%ax(i)%con_min
   endif
   endfunction pan_locked

   ! private: the box

   subroutine render_box(p)
   !< `RenderPlotBox`: the axes' parameters, then background, axis rectangles, border, grid, tick marks, tick labels,
   !< axis labels.
   type(plot3d_record), intent(inout) :: p          !< Plot.
   logical                            :: af(3)      !< Active faces.
   real(real32)                       :: cp(2, 0:7) !< Corners' pixels.
   real(real64)                       :: c(3, 0:7)  !< Corners.
   integer(int32)                     :: plane_2d   !< 2-D plane.
   integer(int32)                     :: ac(0:1, 0:2) !< Axis corners.

   call axes_parameters(p%v, af, cp, c, plane_2d, ac)
   call render_background(p, af, cp, plane_2d, ac)
   call render_axis_rects(p, cp, plane_2d, ac)
   call render_border(cp, af, plane_2d)
   call render_grid(p, c, af, plane_2d)
   call render_tick_marks(p, c, cp, ac, plane_2d)
   call render_tick_labels(p, c, cp, ac)
   call render_axis_labels(p, cp, ac)
   endsubroutine render_box

   subroutine render_background(p, af, cp, plane_2d, ac)
   !< `RenderPlotBackground`: the three active faces in PlotBg (the hovered or held plane lighter).
   type(plot3d_record), intent(in) :: p             !< Plot.
   logical,             intent(in) :: af(3)         !< Active faces.
   real(real32),        intent(in) :: cp(2, 0:7)    !< Corners' pixels.
   integer(int32),      intent(in) :: plane_2d      !< 2-D plane.
   integer(int32),      intent(in) :: ac(0:1, 0:2)  !< Axis corners.
   integer(int32)                  :: hovered, a, f, k, col, col_bg, col_hov !< Plane, axis, face, corner, colours.
   real(real64)                    :: qx(4), qy(4)  !< A quad.
   real(real32)                    :: mx, my        !< Pointer.
   real(real32)                    :: bgf(4)        !< PlotBg, floats.

   hovered = -1_int32
   if (.not. p%held) then
      if (pointer(mx, my)) then
         hovered = mouse_over_plane(af, cp, mx, my)
         if (over_axis(p, cp, plane_2d, ac, mx, my) /= -1_int32) hovered = -1_int32
      endif
   else
      hovered = p%held_plane
   endif
   call style3_vec4(S3_PLOT_BG, bgf)
   col_bg = core_color(real(bgf(1), real64), real(bgf(2), real64), real(bgf(3), real64), real(bgf(4), real64))
   bgf(1:3) = bgf(1:3) + 0.03_real32 ! col_bg + ImVec4(0.03, 0.03, 0.03, 0), in float
   col_hov = core_color(real(bgf(1), real64), real(bgf(2), real64), real(bgf(3), real64), real(bgf(4), real64))
   do a = 0_int32, 2_int32
      f = a + 3_int32 * merge(1_int32, 0_int32, af(a + 1_int32))
      do k = 0_int32, 3_int32
         qx(k + 1_int32) = real(cp(1, FACES(k, f)), real64)
         qy(k + 1_int32) = real(cp(2, FACES(k, f)), real64)
      enddo
      col = col_bg
      if (hovered == a) col = col_hov
      call core_draw_convex_poly_filled(qx, qy, col)
   enddo
   endsubroutine render_background

   subroutine render_axis_rects(p, cp, plane_2d, ac)
   !< `RenderAxisRects`: each axis's hover rectangle outward from its edge, in AxisBg (transparent: not drawn),
   !< AxisBgHovered when hovered, AxisBgActive while dragged from it.
   type(plot3d_record), intent(in) :: p            !< Plot.
   real(real32),        intent(in) :: cp(2, 0:7)   !< Corners' pixels.
   integer(int32),      intent(in) :: plane_2d     !< 2-D plane.
   integer(int32),      intent(in) :: ac(0:1, 0:2) !< Axis corners.
   integer(int32)                  :: hov, a, col  !< Hovered axis, axis, colour.
   real(real32)                    :: bc(2), o(2), w, mx, my !< Box centre, outward direction, width, pointer.
   real(real64)                    :: qx(4), qy(4) !< The rectangle.

   hov = -1_int32
   if (pointer(mx, my)) hov = over_axis(p, cp, plane_2d, ac, mx, my)
   call box_center(cp, bc)
   do a = 0_int32, 2_int32
      if (plane_2d /= -1_int32 .and. a == plane_2d) cycle
      if (ac(0, a) == -1_int32 .or. ac(1, a) == -1_int32) cycle
      call edge_outward_dir(cp(:, ac(0, a)), cp(:, ac(1, a)), bc, o)
      w = hover_width(p%ax(a + 1_int32))
      if (p%ax(a + 1_int32)%held .and. p%held_edge /= -1_int32) then
         col = p%ax(a + 1_int32)%col_act
      elseif (a == hov .and. .not. p%held) then
         col = p%ax(a + 1_int32)%col_hov
      else
         col = p%ax(a + 1_int32)%col_bg
      endif
      if (col == 0_int32) cycle
      qx(1) = real(cp(1, ac(0, a)), real64)
      qy(1) = real(cp(2, ac(0, a)), real64)
      qx(2) = real(cp(1, ac(0, a)) + o(1) * w, real64)
      qy(2) = real(cp(2, ac(0, a)) + o(2) * w, real64)
      qx(3) = real(cp(1, ac(1, a)) + o(1) * w, real64)
      qy(3) = real(cp(2, ac(1, a)) + o(2) * w, real64)
      qx(4) = real(cp(1, ac(1, a)), real64)
      qy(4) = real(cp(2, ac(1, a)), real64)
      call core_draw_convex_poly_filled(qx, qy, col)
   enddo
   endsubroutine render_axis_rects

   subroutine render_border(cp, af, plane_2d)
   !< `RenderPlotBorder`: the edges of the active faces (of the 2-D face only, in a 2-D view), in PlotBorder.
   real(real32),   intent(in) :: cp(2, 0:7) !< Corners' pixels.
   logical,        intent(in) :: af(3)      !< Active faces.
   integer(int32), intent(in) :: plane_2d   !< 2-D plane.
   logical                    :: draw(0:11) !< Edges drawn.
   integer(int32)             :: a, f, k, col !< Axis, face, counter, colour.

   draw = .false.
   do a = 0_int32, 2_int32
      f = a + 3_int32 * merge(1_int32, 0_int32, af(a + 1_int32))
      if (plane_2d /= -1_int32 .and. a /= plane_2d) cycle
      do k = 0_int32, 3_int32
         draw(FACE_EDGES(k, f)) = .true.
      enddo
   enddo
   col = style3_u32(S3_PLOT_BORDER)
   do k = 0_int32, 11_int32
      if (.not. draw(k)) cycle
      call core_draw_line(real(cp(1, EDGES(0, k)), real64), real(cp(2, EDGES(0, k)), real64), &
                          real(cp(1, EDGES(1, k)), real64), real(cp(2, EDGES(1, k)), real64), col, 1.0_real64)
   enddo
   endsubroutine render_border

   subroutine render_grid(p, c, af, plane_2d)
   !< `RenderGrid`: on each active face (the 2-D one only, in a 2-D view) the lines of its two axes' ticks within
   !< range, majors at 0.6 of AxisGrid's alpha, minors at 0.3.
   type(plot3d_record), intent(in) :: p          !< Plot.
   real(real64),        intent(in) :: c(3, 0:7)  !< Corners.
   logical,             intent(in) :: af(3)      !< Active faces.
   integer(int32),      intent(in) :: plane_2d   !< 2-D plane.
   integer(int32)                  :: face, f, au, av, t, col_minor, col_major !< Face, axes, tick, colours.
   real(real64)                    :: p0(3), p1(3), p3(3), u(3), w(3), tt, a(3), b(3) !< Corners, edges, points.
   real(real32)                    :: ax_, ay_, bx_, by_ !< Pixels.
   real(real32)                    :: cg(4), ch(4) !< AxisGrid, its minor and major.

   call style3_vec4(S3_AXIS_GRID, cg) ! GetColorU32(col_grid * ImVec4(1, 1, 1, 0.3)): times the style's alpha
   ch = cg
   ch(4) = cg(4) * 0.3_real32
   col_minor = style3_color_u32(ch)
   ch(4) = cg(4) * 0.6_real32
   col_major = style3_color_u32(ch)
   do face = 0_int32, 2_int32
      if (plane_2d /= -1_int32 .and. face /= plane_2d) cycle
      f = face + 3_int32 * merge(1_int32, 0_int32, af(face + 1_int32))
      au = mod(face + 1_int32, 3_int32) + 1_int32
      av = mod(face + 2_int32, 3_int32) + 1_int32
      p0 = c(:, FACES(0, f))
      p1 = c(:, FACES(1, f))
      p3 = c(:, FACES(3, f))
      u = p1 - p0
      w = p3 - p0
      if (.not. has_flag(p%ax(au)%flags, A3_NO_GRID)) then
         do t = 1_int32, p%ax(au)%ticks%n
            tt = (p%ax(au)%ticks%pos(t) - p%v%rmin(au)) / (p%v%rmax(au) - p%v%rmin(au))
            if (tt < 0.0_real64 .or. tt > 1.0_real64) cycle
            a = p0 + u * tt
            b = p3 + u * tt
            call plot_to_pixels(p%v, a, ax_, ay_)
            call plot_to_pixels(p%v, b, bx_, by_)
            call core_draw_line(real(ax_, real64), real(ay_, real64), real(bx_, real64), real(by_, real64), &
                                merge(col_major, col_minor, p%ax(au)%ticks%major(t)), 1.0_real64)
         enddo
      endif
      if (.not. has_flag(p%ax(av)%flags, A3_NO_GRID)) then
         do t = 1_int32, p%ax(av)%ticks%n
            tt = (p%ax(av)%ticks%pos(t) - p%v%rmin(av)) / (p%v%rmax(av) - p%v%rmin(av))
            if (tt < 0.0_real64 .or. tt > 1.0_real64) cycle
            a = p0 + w * tt
            b = p1 + w * tt
            call plot_to_pixels(p%v, a, ax_, ay_)
            call plot_to_pixels(p%v, b, bx_, by_)
            call core_draw_line(real(ax_, real64), real(ay_, real64), real(bx_, real64), real(by_, real64), &
                                merge(col_major, col_minor, p%ax(av)%ticks%major(t)), 1.0_real64)
         enddo
      endif
   enddo
   endsubroutine render_grid

   subroutine render_tick_marks(p, c, cp, ac, plane_2d)
   !< `RenderTickMarks`: each axis's line and its ticks, half on each side, across the axis in the plane chosen (the
   !< 2-D one, else XY for x and y, XZ for z), 0.06 NDC long for majors, 0.03 for minors, in AxisTick.
   type(plot3d_record), intent(in) :: p             !< Plot.
   real(real64),        intent(in) :: c(3, 0:7)     !< Corners.
   real(real32),        intent(in) :: cp(2, 0:7)    !< Corners' pixels.
   integer(int32),      intent(in) :: ac(0:1, 0:2)  !< Axis corners.
   integer(int32),      intent(in) :: plane_2d      !< 2-D plane.
   integer(int32)                  :: a, i0, i1, cpl, t, col !< Axis, corners, plane, tick, colour.
   type(vector_R8P)                :: s, dir, pd, td !< Axis start, direction, projected, tick direction.
   real(real64)                    :: alen, plen, vv, tp(3), n(3), half(3), sz, t1(3), t2(3) !< Work.
   real(real32)                    :: x1, y1, x2, y2 !< Pixels.

   col = style3_u32(S3_AXIS_TICK)
   do a = 0_int32, 2_int32
      if (has_flag(p%ax(a + 1_int32)%flags, A3_NO_TICK_MARKS)) cycle
      i0 = ac(0, a)
      i1 = ac(1, a)
      if (i0 == i1) cycle
      s%x = c(1, i0)
      s%y = c(2, i0)
      s%z = c(3, i0)
      dir%x = c(1, i1) - s%x
      dir%y = c(2, i1) - s%y
      dir%z = c(3, i1) - s%z
      alen = sqrt(dir%sq_norm())
      if (alen < 1.0e-12_real64) cycle
      dir%x = dir%x / alen
      dir%y = dir%y / alen
      dir%z = dir%z / alen
      call core_draw_line(real(cp(1, i0), real64), real(cp(2, i0), real64), real(cp(1, i1), real64), &
                          real(cp(2, i1), real64), col, 1.0_real64)
      if (plane_2d /= -1_int32) then
         cpl = plane_2d
      elseif (a == 2_int32) then
         cpl = 1_int32
      else
         cpl = 2_int32
      endif
      pd = dir
      select case (cpl)
      case (0_int32)
         pd%x = 0.0_real64
      case (1_int32)
         pd%y = 0.0_real64
      case default
         pd%z = 0.0_real64
      endselect
      plen = sqrt(pd%sq_norm())
      if (plen < 1.0e-12_real64) cycle
      pd%x = pd%x / plen
      pd%y = pd%y / plen
      pd%z = pd%z / plen
      select case (cpl)
      case (0_int32)
         td%x = 0.0_real64
         td%y = -pd%z
         td%z = pd%y
      case (1_int32)
         td%x = -pd%z
         td%y = 0.0_real64
         td%z = pd%x
      case default
         td%x = -pd%y
         td%y = pd%x
         td%z = 0.0_real64
      endselect
      plen = sqrt(td%sq_norm())
      td%x = td%x / plen
      td%y = td%y / plen
      td%z = td%z / plen
      do t = 1_int32, p%ax(a + 1_int32)%ticks%n
         vv = (p%ax(a + 1_int32)%ticks%pos(t) - p%v%rmin(a + 1_int32)) / &
              (p%v%rmax(a + 1_int32) - p%v%rmin(a + 1_int32))
         if (vv < 0.0_real64 .or. vv > 1.0_real64) cycle
         sz = vv * alen
         tp(1) = s%x + dir%x * sz
         tp(2) = s%y + dir%y * sz
         tp(3) = s%z + dir%z * sz
         call plot_to_ndc(p%v, tp, n)
         if (p%ax(a + 1_int32)%ticks%major(t)) then
            sz = 0.06_real64 * 0.5_real64
         else
            sz = 0.03_real64 * 0.5_real64
         endif
         half(1) = td%x * sz
         half(2) = td%y * sz
         half(3) = td%z * sz
         t1 = n - half
         t2 = n + half
         call ndc_to_pixels(p%v, t1, x1, y1)
         call ndc_to_pixels(p%v, t2, x2, y2)
         call core_draw_line(real(x1, real64), real(y1, real64), real(x2, real64), real(y2, real64), col, 1.0_real64)
      enddo
   enddo
   endsubroutine render_tick_marks

   subroutine render_tick_labels(p, c, cp, ac)
   !< `RenderTickLabels`: each shown label at its tick, moved outward by the widest label's half plus 5 pixels,
   !< rotated across the axis and kept upright, in AxisText.
   type(plot3d_record), intent(in) :: p            !< Plot.
   real(real64),        intent(in) :: c(3, 0:7)    !< Corners.
   real(real32),        intent(in) :: cp(2, 0:7)   !< Corners' pixels.
   integer(int32),      intent(in) :: ac(0:1, 0:2) !< Axis corners.
   integer(int32)                  :: a, i0, i1, t, col !< Axis, corners, tick, colour.
   real(real32)                    :: d(2), l, o(2), off(2), ang, rc(2), x, y, ext !< Work.
   real(real64)                    :: s(3), dir(3), tt, tp(3), ctr(3) !< Axis start, direction, a tick's point.

   col = style3_u32(S3_AXIS_TEXT)
   do a = 0_int32, 2_int32
      if (has_flag(p%ax(a + 1_int32)%flags, A3_NO_TICK_LABELS)) cycle
      i0 = ac(0, a)
      i1 = ac(1, a)
      if (i0 == i1) cycle
      s = c(:, i0)
      dir = c(:, i1) - s
      d = cp(:, i1) - cp(:, i0)
      l = sqrt(d(1) * d(1) + d(2) * d(2))
      if (l > 0.0_real32) then
         d = d / l
      else
         d(1) = 1.0_real32
         d(2) = 0.0_real32
      endif
      call range_center(p, ctr)
      call plot_to_pixels(p%v, ctr, rc(1), rc(2))
      call edge_outward_dir(cp(:, i0), cp(:, i1), rc, o)
      ext = max_tick_extent(p%ax(a + 1_int32))
      off = o * (ext + AXIS_TICK_INNER_PAD)
      ang = c_atan2f(-d(2), d(1)) + IM_PI_F * 0.5_real32
      if (ang > IM_PI_F) ang = ang - 2.0_real32 * IM_PI_F
      if (ang < -IM_PI_F) ang = ang + 2.0_real32 * IM_PI_F
      if (ang > IM_PI_F * 0.5_real32) ang = ang - IM_PI_F
      if (ang < -IM_PI_F * 0.5_real32) ang = ang + IM_PI_F
      associate(tk => p%ax(a + 1_int32)%ticks)
         do t = 1_int32, tk%n
            if (.not. tk%show(t)) cycle
            tt = (tk%pos(t) - p%v%rmin(a + 1_int32)) / (p%v%rmax(a + 1_int32) - p%v%rmin(a + 1_int32))
            if (tt < 0.0_real64 .or. tt > 1.0_real64) cycle
            tp = s + dir * tt
            call plot_to_pixels(p%v, tp, x, y)
            call text_rotated(x + off(1), y + off(2), ang, col, tk%label(t)(1:tk%label_len(t)))
         enddo
      endassociate
   enddo
   endsubroutine render_tick_labels

   subroutine render_axis_labels(p, cp, ac)
   !< `RenderAxisLabels`: each label at its edge's middle, beyond the tick labels by 10 pixels, along the axis and
   !< kept upright, in AxisText.
   type(plot3d_record), intent(in) :: p            !< Plot.
   real(real32),        intent(in) :: cp(2, 0:7)   !< Corners' pixels.
   integer(int32),      intent(in) :: ac(0:1, 0:2) !< Axis corners.
   integer(int32)                  :: a, i0, i1, col !< Axis, corners, colour.
   real(real32)                    :: d(2), l, o(2), ang, rc(2), ext, tot, mid(2) !< Work.
   real(real64)                    :: ctr(3) !< The ranges' centre.

   col = style3_u32(S3_AXIS_TEXT)
   do a = 0_int32, 2_int32
      if (.not. has_label(p%ax(a + 1_int32))) cycle
      i0 = ac(0, a)
      i1 = ac(1, a)
      if (i0 == i1) cycle
      d = cp(:, i1) - cp(:, i0)
      l = sqrt(d(1) * d(1) + d(2) * d(2))
      if (l > 0.0_real32) then
         d = d / l
      else
         d(1) = 1.0_real32
         d(2) = 0.0_real32
      endif
      call range_center(p, ctr)
      call plot_to_pixels(p%v, ctr, rc(1), rc(2))
      call edge_outward_dir(cp(:, i0), cp(:, i1), rc, o)
      ext = max_tick_extent(p%ax(a + 1_int32))
      tot = ((ext + AXIS_TICK_INNER_PAD) + ext) + AXIS_LABEL_PAD
      mid = (cp(:, i0) + cp(:, i1)) * 0.5_real32
      ang = c_atan2f(-d(2), d(1))
      if (ang > IM_PI_F * 0.5_real32) ang = ang - IM_PI_F
      if (ang < -IM_PI_F * 0.5_real32) ang = ang + IM_PI_F
      call text_rotated(mid(1) + o(1) * tot, mid(2) + o(2) * tot, ang, col, &
                        p%ax(a + 1_int32)%label(1:p%ax(a + 1_int32)%label_len))
   enddo
   endsubroutine render_axis_labels

   subroutine text_rotated(x, y, angle, col, s)
   !< `AddTextRotated`: a text centred on (x, y) (floored), turned by `angle` [radians] (screen y down: -angle's cosine
   !< and sine), glyph by glyph from the current font's baked glyphs, each a textured quad.
   real(real32),     intent(in) :: x, y  !< Centre [pixels].
   real(real32),     intent(in) :: angle !< Angle [radians].
   integer(int32),   intent(in) :: col   !< Colour.
   character(len=*), intent(in) :: s     !< Text (UTF-8).
   real(real32)                 :: px, py, ca, sa, pen(2), sc, go(2), gs(2), cx(4), cy(4), cxr, cyr !< Work.
   real(real64)                 :: w, h, scale, adv, x0, y0, x1, y1, u0, v0, u1, v1 !< Text size, a glyph.
   real(real64)                 :: qx(4), qy(4), qu(4), qv(4) !< Its quad.
   integer(int32)               :: k, cc, nb, j !< Byte, code point, its bytes, corner.
   logical                      :: found !< A glyph.

   px = im_floor(x)
   py = im_floor(y)
   call text_size_a(s, w, h)
   ca = c_cosf(-angle)
   sa = c_sinf(-angle)
   pen(1) = -real(w, real32) * 0.5_real32
   pen(2) = -real(h, real32) * 0.5_real32
   k = 1_int32
   do while (k <= len(s, kind=int32))
      call utf8_char(s, k, cc, nb)
      k = k + nb
      call core_font_glyph(cc, found, scale, adv, x0, y0, x1, y1, u0, v0, u1, v1)
      if (.not. found) cycle
      sc = real(scale, real32)
      go(1) = real(x0, real32) * sc
      go(2) = real(y0, real32) * sc
      gs(1) = (real(x1, real32) - real(x0, real32)) * sc
      gs(2) = (real(y1, real32) - real(y0, real32)) * sc
      cx(1) = pen(1) + go(1)
      cy(1) = pen(2) + go(2)
      cx(2) = cx(1) + gs(1)
      cy(2) = cy(1) + 0.0_real32
      cx(3) = cx(1) + gs(1)
      cy(3) = cy(1) + gs(2)
      cx(4) = cx(1) + 0.0_real32
      cy(4) = cy(1) + gs(2)
      do j = 1_int32, 4_int32
         cxr = (cx(j) * ca - cy(j) * sa) + px
         cyr = (cx(j) * sa + cy(j) * ca) + py
         qx(j) = real(cxr, real64)
         qy(j) = real(cyr, real64)
      enddo
      qu(1) = u0
      qv(1) = v0
      qu(2) = u1
      qv(2) = v0
      qu(3) = u1
      qv(3) = v1
      qu(4) = u0
      qv(4) = v1
      call core_draw_quad_uv(qx, qy, qu, qv, col)
      pen(1) = pen(1) + real(adv, real32) * sc
   enddo
   endsubroutine text_rotated

   subroutine text_size_a(s, w, h)
   !< `ImFont::CalcTextSizeA` of one line (what `AddTextRotated` measures; `CalcTextSize` rounds the width up): the
   !< glyphs' advances times the scale summed in float, the font size high.
   character(len=*), intent(in)  :: s    !< Text (UTF-8).
   real(real64),     intent(out) :: w, h !< Size [pixels].
   real(real32)                  :: lw   !< Line's width.
   real(real64)                  :: scale, adv, x0, y0, x1, y1, u0, v0, u1, v1 !< A glyph.
   integer(int32)                :: k, cc, nb !< Byte, code point, its bytes.
   logical                       :: found !< A glyph.

   lw = 0.0_real32
   k = 1_int32
   do while (k <= len(s, kind=int32))
      call utf8_char(s, k, cc, nb)
      k = k + nb
      call core_font_glyph(cc, found, scale, adv, x0, y0, x1, y1, u0, v0, u1, v1)
      if (.not. found) cycle
      lw = lw + real(adv, real32) * real(scale, real32)
   enddo
   w = real(lw, real64)
   h = core_font_size()
   endsubroutine text_size_a

   subroutine mouse_position(p)
   !< `RenderMousePos`: where the pointer meets the box's YZ, else XZ, else XY face, as "(x, y, z)" through the axes'
   !< formats, at the plot rectangle's south-east corner (10 pixels in), in InlayText.
   type(plot3d_record), intent(in) :: p      !< Plot.
   real(real64)                    :: q(3), w, h !< The point, the text's size.
   real(real32)                    :: mx, my, pos(2) !< Pointer, the text's corner.
   integer(int32)                  :: n, i, pl !< Characters, axis, plane.
   logical                         :: found !< A point.

   if (has_flag(p%flags, F3_NO_MOUSE_TEXT)) return
   if (.not. pointer(mx, my)) return
   found = .false.
   do pl = 0_int32, 2_int32
      call pixels_to_plot_plane(p%v, mx, my, pl, .true., q, found)
      if (found) exit
   enddo
   if (.not. found) return
   n = 0_int32
   call fmt_text(mouse_text, n, '(')
   do i = 1_int32, 3_int32
      if (i > 1_int32) call fmt_text(mouse_text, n, ', ')
      call fmt_real(mouse_text, n, p%ax(i)%fmt, q(i))
   enddo
   call fmt_text(mouse_text, n, ')')
   call core_text_size(mouse_text(1:n), w, h)
   call location_pos(p%v%rect, real(w, real32), real(h, real32), LOC_SOUTH + LOC_EAST, 10.0_real32, 10.0_real32, pos)
   call core_draw_begin()
   call core_draw_text(real(pos(1), real64), real(pos(2), real64), style3_u32(S3_INLAY_TEXT), mouse_text(1:n))
   call core_draw_end()
   endsubroutine mouse_position

   ! private: axes

   subroutine axis_defaults(p, i)
   !< `ImPlot3DAxis()`: a new axis (range 0 to 1, NDC scale 1, linear, to fit).
   type(plot3d_record), intent(inout) :: p !< Plot.
   integer(int32),      intent(in)    :: i !< Axis.

   p%ax(i)%flags = 0_int32
   p%ax(i)%prev_flags = 0_int32
   p%ax(i)%range_cond = COND_NONE
   p%ax(i)%fit = .true.
   p%ax(i)%hovered = .false.
   p%ax(i)%held = .false.
   p%ax(i)%label_len = 0_int32
   p%v%rmin(i) = 0.0_real64
   p%v%rmax(i) = 1.0_real64
   p%v%smin(i) = 0.0_real64 ! ScaledRange: ImPlot3DRange(), (0, 0)
   p%v%smax(i) = 0.0_real64
   p%v%ndc(i) = 1.0_real64
   p%v%scale(i) = SCALE3_LINEAR
   p%v%invert(i) = .false.
   call axis_reset(p, i)
   endsubroutine axis_defaults

   subroutine axis_reset(p, i)
   !< `ImPlot3DAxis::Reset`: per frame, the condition, scale, ticks, format, default ticks, fit extents and
   !< constraints back to their defaults.
   type(plot3d_record), intent(inout) :: p !< Plot.
   integer(int32),      intent(in)    :: i !< Axis.

   p%ax(i)%range_cond = COND_NONE
   p%v%scale(i) = SCALE3_LINEAR
   call ticks3_reset(p%ax(i)%ticks)
   p%ax(i)%fmt = plot_format()
   p%ax(i)%show_default = .true.
   p%ax(i)%fit_min = ieee_value(1.0_real64, ieee_positive_inf)
   p%ax(i)%fit_max = ieee_value(1.0_real64, ieee_negative_inf)
   p%ax(i)%con_min = ieee_value(1.0_real64, ieee_negative_inf)
   p%ax(i)%con_max = ieee_value(1.0_real64, ieee_positive_inf)
   p%ax(i)%zoom_min = tiny(1.0_real64)
   p%ax(i)%zoom_max = ieee_value(1.0_real64, ieee_positive_inf)
   endsubroutine axis_reset

   subroutine set_range(p, i, v1, v2)
   !< `SetRange`: the ends (NaN to 0, infinities to half the largest double) in order, constrained.
   type(plot3d_record), intent(inout) :: p      !< Plot.
   integer(int32),      intent(in)    :: i      !< Axis.
   real(real64),        intent(in)    :: v1, v2 !< Ends.
   real(real64)                       :: a, b   !< Constrained ends.

   a = constrain_nan(constrain_inf(v1))
   b = constrain_nan(constrain_inf(v2))
   p%v%rmin(i) = min(a, b)
   p%v%rmax(i) = max(a, b)
   call constrain(p, i)
   call update_scaled(p, i)
   endsubroutine set_range

   subroutine constrain(p, i)
   !< `Constrain`: the range within its constraints, its size within the zoom's.
   type(plot3d_record), intent(inout) :: p     !< Plot.
   integer(int32),      intent(in)    :: i     !< Axis.
   real(real64)                       :: zoom, delta !< Size, correction.

   p%v%rmin(i) = constrain_nan(constrain_inf(p%v%rmin(i)))
   p%v%rmax(i) = constrain_nan(constrain_inf(p%v%rmax(i)))
   if (p%v%rmin(i) < p%ax(i)%con_min) p%v%rmin(i) = p%ax(i)%con_min
   if (p%v%rmax(i) > p%ax(i)%con_max) p%v%rmax(i) = p%ax(i)%con_max
   zoom = p%v%rmax(i) - p%v%rmin(i)
   if (zoom < p%ax(i)%zoom_min) then
      delta = (p%ax(i)%zoom_min - zoom) * 0.5_real64
      p%v%rmin(i) = p%v%rmin(i) - delta
      p%v%rmax(i) = p%v%rmax(i) + delta
   endif
   if (zoom > p%ax(i)%zoom_max) then
      delta = (zoom - p%ax(i)%zoom_max) * 0.5_real64
      p%v%rmin(i) = p%v%rmin(i) + delta
      p%v%rmax(i) = p%v%rmax(i) - delta
   endif
   if (p%v%rmax(i) <= p%v%rmin(i)) p%v%rmax(i) = p%v%rmin(i) + epsilon(1.0_real64)
   endsubroutine constrain

   subroutine update_scaled(p, i)
   !< `UpdateTransformCache`: the scaled range through the axis's transform of now (linear axes: the range).
   type(plot3d_record), intent(inout) :: p !< Plot.
   integer(int32),      intent(in)    :: i !< Axis.

   select case (p%v%scale(i))
   case (SCALE3_LOG10)
      p%v%smin(i) = transform_log10(p%v%rmin(i))
      p%v%smax(i) = transform_log10(p%v%rmax(i))
   case (SCALE3_SYMLOG)
      p%v%smin(i) = transform_symlog(p%v%rmin(i))
      p%v%smax(i) = transform_symlog(p%v%rmax(i))
   case default
      p%v%smin(i) = p%v%rmin(i)
      p%v%smax(i) = p%v%rmax(i)
   endselect
   endsubroutine update_scaled

   subroutine apply_fit(p, i)
   !< `ApplyFit`: the range to the fit extents (finite ends, unlocked), widened by one about a null size, constrained.
   type(plot3d_record), intent(inout) :: p !< Plot.
   integer(int32),      intent(in)    :: i !< Axis.

   if (.not. locked_min(p, i) .and. ieee_is_finite(p%ax(i)%fit_min)) p%v%rmin(i) = p%ax(i)%fit_min
   if (.not. locked_max(p, i) .and. ieee_is_finite(p%ax(i)%fit_max)) p%v%rmax(i) = p%ax(i)%fit_max
   if (almost_equal(p%v%rmin(i), p%v%rmax(i))) then
      p%v%rmax(i) = p%v%rmax(i) + 0.5_real64
      p%v%rmin(i) = p%v%rmin(i) - 0.5_real64
   endif
   call constrain(p, i)
   call update_scaled(p, i)
   p%ax(i)%fit_min = ieee_value(1.0_real64, ieee_positive_inf)
   p%ax(i)%fit_max = ieee_value(1.0_real64, ieee_negative_inf)
   endsubroutine apply_fit

   function get_aspect(p, i) result(a)
   !< `GetAspect`: units per NDC unit.
   type(plot3d_record), intent(in) :: p !< Plot.
   integer(int32),      intent(in) :: i !< Axis.
   real(real64)                    :: a !< Aspect.

   a = (p%v%rmax(i) - p%v%rmin(i)) / p%v%ndc(i)
   endfunction get_aspect

   subroutine set_aspect(p, i, units)
   !< `SetAspect`: the range resized to `units` per NDC unit about its centre (from the unlocked end).
   type(plot3d_record), intent(inout) :: p     !< Plot.
   integer(int32),      intent(in)    :: i     !< Axis.
   real(real64),        intent(in)    :: units !< Units per NDC unit.
   real(real64)                       :: new_size, delta !< Size, half the change.

   new_size = units * p%v%ndc(i)
   delta = (new_size - (p%v%rmax(i) - p%v%rmin(i))) * 0.5_real64
   if (locked_min(p, i) .and. locked_max(p, i)) then
      return
   elseif (locked_min(p, i)) then
      call set_range(p, i, p%v%rmin(i), p%v%rmax(i) + 2.0_real64 * delta)
   elseif (locked_max(p, i)) then
      call set_range(p, i, p%v%rmin(i) - 2.0_real64 * delta, p%v%rmax(i))
   else
      call set_range(p, i, p%v%rmin(i) - delta, p%v%rmax(i) + delta)
   endif
   endsubroutine set_aspect

   subroutine apply_equal_aspect(p, ref)
   !< `ApplyEqualAspect`: every other axis not input-locked to the reference axis's aspect.
   type(plot3d_record), intent(inout) :: p   !< Plot.
   integer(int32),      intent(in)    :: ref !< Reference axis.
   real(real64)                       :: a   !< Aspect.
   integer(int32)                     :: i   !< Axis.

   a = get_aspect(p, ref)
   do i = 1_int32, 3_int32
      if (i /= ref .and. .not. input_locked(p, i)) call set_aspect(p, i, a)
   enddo
   endsubroutine apply_equal_aspect

   pure function locked_min(p, i) result(yes)
   !< `IsLockedMin`.
   type(plot3d_record), intent(in) :: p   !< Plot.
   integer(int32),      intent(in) :: i   !< Axis.
   logical                         :: yes !< Locked.

   yes = p%ax(i)%range_cond == COND_ALWAYS .or. has_flag(p%ax(i)%flags, A3_LOCK_MIN)
   endfunction locked_min

   pure function locked_max(p, i) result(yes)
   !< `IsLockedMax`.
   type(plot3d_record), intent(in) :: p   !< Plot.
   integer(int32),      intent(in) :: i   !< Axis.
   logical                         :: yes !< Locked.

   yes = p%ax(i)%range_cond == COND_ALWAYS .or. has_flag(p%ax(i)%flags, A3_LOCK_MAX)
   endfunction locked_max

   pure function input_locked(p, i) result(yes)
   !< `IsInputLocked`: locked at both ends, or auto-fitting.
   type(plot3d_record), intent(in) :: p   !< Plot.
   integer(int32),      intent(in) :: i   !< Axis.
   logical                         :: yes !< Locked.

   yes = (locked_min(p, i) .and. locked_max(p, i)) .or. has_flag(p%ax(i)%flags, A3_AUTO_FIT)
   endfunction input_locked

   pure function has_label(ax) result(yes)
   !< `HasLabel`: a label, not hidden.
   type(axis3d), intent(in) :: ax  !< Axis.
   logical                  :: yes !< Shown.

   yes = ax%label_len > 0_int32 .and. .not. has_flag(ax%flags, A3_NO_LABEL)
   endfunction has_label

   pure function max_tick_extent(ax) result(e)
   !< `ComputeMaxTickLabelExtent`: half the widest shown label (0 without tick labels).
   type(axis3d), intent(in) :: ax !< Axis.
   real(real32)             :: e  !< Extent [pixels].
   integer(int32)           :: t  !< Tick.

   e = 0.0_real32
   if (has_flag(ax%flags, A3_NO_TICK_LABELS)) return
   do t = 1_int32, ax%ticks%n
      if (.not. ax%ticks%show(t)) cycle
      e = max(e, ax%ticks%label_size(1, t) * 0.5_real32)
   enddo
   endfunction max_tick_extent

   function hover_width(ax) result(w)
   !< `ComputeAxisHoverWidth`: twice the widest label's half plus 5 pixels, plus 10 and half the label's height when
   !< labelled; at least 40.
   type(axis3d), intent(in) :: ax !< Axis.
   real(real32)             :: w  !< Width [pixels].
   real(real64)             :: lw, lh !< The label's size.

   w = 2.0_real32 * max_tick_extent(ax) + AXIS_TICK_INNER_PAD
   if (has_label(ax)) then
      call core_text_size(ax%label(1:ax%label_len), lw, lh, hide_after_hash=.true.)
      w = w + (AXIS_LABEL_PAD + real(lh, real32) * 0.5_real32)
   endif
   w = max(w, AXIS_RECT_MIN_WIDTH)
   endfunction hover_width

   function over_axis(p, cp, plane_2d, ac, mx, my, edge_out) result(axis)
   !< `GetMouseOverAxis`: the axis whose hover rectangle holds the pointer, or -1.
   type(plot3d_record), intent(in) :: p            !< Plot.
   real(real32),        intent(in) :: cp(2, 0:7)   !< Corners' pixels.
   integer(int32),      intent(in) :: plane_2d     !< 2-D plane.
   integer(int32),      intent(in) :: ac(0:1, 0:2) !< Axis corners.
   real(real32),        intent(in) :: mx, my       !< Pointer.
   integer(int32),      intent(out), optional :: edge_out !< The axis's edge (0-11), or -1.
   integer(int32)                  :: axis         !< Axis (0-2), or -1.
   real(real32)                    :: bc(2), o(2), pt(2) !< Box centre, outward direction, pointer.
   integer(int32)                  :: a, e         !< Axis, edge.
   logical                         :: found        !< The edge found.

   axis = -1_int32
   if (present(edge_out)) edge_out = -1_int32
   call box_center(cp, bc)
   pt(1) = mx
   pt(2) = my
   do a = 0_int32, 2_int32
      if (plane_2d /= -1_int32 .and. a == plane_2d) cycle
      if (ac(0, a) == -1_int32 .or. ac(1, a) == -1_int32) cycle
      found = .false.
      do e = 0_int32, 11_int32
         if ((EDGES(0, e) == ac(0, a) .and. EDGES(1, e) == ac(1, a)) .or. &
             (EDGES(0, e) == ac(1, a) .and. EDGES(1, e) == ac(0, a))) then
            found = .true.
            exit
         endif
      enddo
      if (.not. found) cycle
      call edge_outward_dir(cp(:, ac(0, a)), cp(:, ac(1, a)), bc, o)
      if (in_edge_region(pt, cp(:, ac(0, a)), cp(:, ac(1, a)), o, hover_width(p%ax(a + 1_int32)))) then
         axis = a
         if (present(edge_out)) edge_out = e
         return
      endif
   enddo
   endfunction over_axis

   pure subroutine box_center(cp, bc)
   !< The box's centre on screen: the corners' pixels summed in order, times 1/8.
   real(real32), intent(in)  :: cp(2, 0:7) !< Corners' pixels.
   real(real32), intent(out) :: bc(2)      !< Centre.
   integer(int32)            :: i          !< Corner.

   bc = 0.0_real32
   do i = 0_int32, 7_int32
      bc = bc + cp(:, i)
   enddo
   bc = bc * (1.0_real32 / 8.0_real32)
   endsubroutine box_center

   pure subroutine range_center(p, ctr)
   !< `RangeCenter`: the ranges' middles.
   type(plot3d_record), intent(in)  :: p      !< Plot.
   real(real64),        intent(out) :: ctr(3) !< Centre.
   integer(int32)                   :: i      !< Axis.

   do i = 1_int32, 3_int32
      ctr(i) = (p%v%rmin(i) + p%v%rmax(i)) * real(0.5_real32, real64)
   enddo
   endsubroutine range_center

   ! private: context menus

   subroutine context_menus(p)
   !< `EndPlot`'s popups: the legend's, each axis's, each plane's and the plot's, their contents as ImPlot3D's.
   type(plot3d_record), intent(inout) :: p !< Plot.
   integer(int32)                     :: i !< Axis, plane.

   if (core_begin_popup('##LegendContext')) then
      call core_text_unformatted('Legend')
      call ig_separator()
      if (legend_menu(p, .not. has_flag(p%flags, F3_NO_LEGEND))) call flip(p%flags, F3_NO_LEGEND)
      call core_end_popup()
   endif
   do i = 0_int32, 2_int32
      if (core_begin_popup(AXIS_CONTEXTS(i))) then
         if (has_label(p%ax(i + 1_int32))) then
            call core_text_unformatted(p%ax(i + 1_int32)%label(1:p%ax(i + 1_int32)%label_len))
         else
            call core_text_unformatted(AXIS_LABELS(i))
         endif
         call ig_separator()
         call axis_menu(p, i + 1_int32)
         call core_end_popup()
      endif
   enddo
   do i = 0_int32, 2_int32
      if (core_begin_popup(PLANE_CONTEXTS(i))) then
         call core_text_unformatted(PLANE_LABELS(i))
         call ig_separator()
         call plane_menu(p, i)
         call core_end_popup()
      endif
   enddo
   if (core_begin_popup('##PlotContext')) then
      call plot_menu(p)
      call core_end_popup()
   endif
   endsubroutine context_menus

   subroutine axis_menu(p, i)
   !< `ShowAxisContextMenu`: the ends (locks and drags), Auto-Fit, Invert, Label, Grid Lines, Tick Marks, Tick Labels
   !< (the item width pushed and, as ImPlot3D, not popped).
   type(plot3d_record), intent(inout) :: p !< Plot.
   integer(int32),      intent(in)    :: i !< Axis (1-3).
   logical                            :: always_locked, label, grid, ticks, labels, eq, inverted, dis !< State.
   real(real64)                       :: speed, tmp, sz !< Drag speed, a value, the range's size.

   call core_push_item_width(75.0_real64)
   always_locked = p%ax(i)%range_cond == COND_ALWAYS .or. has_flag(p%ax(i)%flags, A3_AUTO_FIT)
   label = has_label(p%ax(i))
   grid = .not. has_flag(p%ax(i)%flags, A3_NO_GRID)
   ticks = .not. has_flag(p%ax(i)%flags, A3_NO_TICK_MARKS)
   labels = .not. has_flag(p%ax(i)%flags, A3_NO_TICK_LABELS)
   sz = p%v%rmax(i) - p%v%rmin(i)
   if (sz <= epsilon(1.0_real64)) then
      speed = epsilon(1.0_real64) * 1.0e13_real64
   else
      speed = 0.01_real64 * sz
   endif
   speed = real(real(speed, real32), real64) ! (float)drag_speed
   eq = has_flag(p%flags, F3_EQUAL)
   call ig_begin_disabled(always_locked)
   call flag_box('##LockMin', p%ax(i)%flags, A3_LOCK_MIN)
   call ig_end_disabled()
   call ig_same_line()
   dis = locked_min(p, i) .or. always_locked
   call ig_begin_disabled(dis)
   tmp = p%v%rmin(i)
   if (core_drag_double('Min', tmp, speed, p%ax(i)%con_min, p%v%rmax(i), '%f', 0_int32)) then ! (a null format: %f)
      if (set_min(p, i, tmp)) continue
      if (eq) call apply_equal_aspect(p, i)
   endif
   call ig_end_disabled()
   call ig_begin_disabled(always_locked)
   call flag_box('##LockMax', p%ax(i)%flags, A3_LOCK_MAX)
   call ig_end_disabled()
   call ig_same_line()
   dis = locked_max(p, i) .or. always_locked
   call ig_begin_disabled(dis)
   tmp = p%v%rmax(i)
   if (core_drag_double('Max', tmp, speed, p%v%rmin(i), p%ax(i)%con_max, '%f', 0_int32)) then
      if (set_max(p, i, tmp)) continue
      if (eq) call apply_equal_aspect(p, i)
   endif
   call ig_end_disabled()
   call ig_separator()
   call flag_box('Auto-Fit', p%ax(i)%flags, A3_AUTO_FIT)
   call ig_separator()
   inverted = has_flag(p%ax(i)%flags, A3_INVERT)
   if (ig_checkbox('Invert', inverted)) call flip(p%ax(i)%flags, A3_INVERT)
   call ig_separator()
   call ig_begin_disabled(p%ax(i)%label_len == 0_int32)
   if (ig_checkbox('Label', label)) call flip(p%ax(i)%flags, A3_NO_LABEL)
   call ig_end_disabled()
   if (ig_checkbox('Grid Lines', grid)) call flip(p%ax(i)%flags, A3_NO_GRID)
   if (ig_checkbox('Tick Marks', ticks)) call flip(p%ax(i)%flags, A3_NO_TICK_MARKS)
   if (ig_checkbox('Tick Labels', labels)) call flip(p%ax(i)%flags, A3_NO_TICK_LABELS)
   endsubroutine axis_menu

   subroutine plane_menu(p, plane)
   !< `ShowPlaneContextMenu`: a submenu per axis of the plane.
   type(plot3d_record), intent(inout) :: p     !< Plot.
   integer(int32),      intent(in)    :: plane !< Plane (0-2).
   integer(int32)                     :: i     !< Axis.

   do i = 0_int32, 2_int32
      if (i == plane) cycle
      call core_push_id_int(i)
      if (axis_submenu(p, i)) then
         call axis_menu(p, i + 1_int32)
         call ig_end_menu()
      endif
      call core_pop_id()
   enddo
   endsubroutine plane_menu

   subroutine plot_menu(p)
   !< `ShowPlotContextMenu`: the axes' submenus, Box (the scales), Legend, Settings (Equal, Title, Clip, Mouse
   !< Position).
   type(plot3d_record), intent(inout) :: p  !< Plot.
   integer(int32)                     :: i  !< Axis.
   real(real64)                       :: sc !< A scale.
   logical                            :: v  !< A menu item's tick.
   character(len=7), parameter        :: SCALE_LABELS(3) = ['Scale X', 'Scale Y', 'Scale Z'] !< Box's drags.

   do i = 0_int32, 2_int32
      call core_push_id_int(i)
      if (axis_submenu(p, i)) then
         call axis_menu(p, i + 1_int32)
         call ig_end_menu()
      endif
      call core_pop_id()
   enddo
   call ig_separator()
   if (ig_begin_menu('Box')) then
      call ig_push_item_width(75.0_real64)
      do i = 1_int32, 3_int32
         sc = real(real(p%v%ndc(i), real32), real64)
         if (core_drag_double(SCALE_LABELS(i), sc, real(0.01_real32, real64), real(0.1_real32, real64), 3.0_real64, &
                              '%.3f', 0_int32)) p%v%ndc(i) = real(max(real(sc, real32), 0.01_real32), real64)
      enddo
      call ig_pop_item_width()
      call ig_end_menu()
   endif
   call ig_separator()
   if (ig_begin_menu('Legend')) then
      if (legend_menu(p, .not. has_flag(p%flags, F3_NO_LEGEND))) call flip(p%flags, F3_NO_LEGEND)
      call ig_end_menu()
   endif
   if (ig_begin_menu('Settings')) then
      v = has_flag(p%flags, F3_EQUAL)
      if (ig_menu_item('Equal', selected=v)) call flip(p%flags, F3_EQUAL)
      call ig_begin_disabled(p%title_len == 0_int32)
      v = p%title_len > 0_int32 .and. .not. has_flag(p%flags, F3_NO_TITLE)
      if (ig_menu_item('Title', selected=v)) call flip(p%flags, F3_NO_TITLE)
      call ig_end_disabled()
      v = .not. has_flag(p%flags, F3_NO_CLIP)
      if (ig_menu_item('Clip', selected=v)) call flip(p%flags, F3_NO_CLIP)
      v = .not. has_flag(p%flags, F3_NO_MOUSE_TEXT)
      if (ig_menu_item('Mouse Position', selected=v)) call flip(p%flags, F3_NO_MOUSE_TEXT)
      call ig_end_menu()
   endif
   endsubroutine plot_menu

   function axis_submenu(p, i) result(open)
   !< `BeginMenu` of an axis: its label, or its default name.
   type(plot3d_record), intent(in) :: p    !< Plot.
   integer(int32),      intent(in) :: i    !< Axis (0-2).
   logical                         :: open !< Open.

   if (has_label(p%ax(i + 1_int32))) then
      open = ig_begin_menu(p%ax(i + 1_int32)%label(1:p%ax(i + 1_int32)%label_len))
   else
      open = ig_begin_menu(AXIS_LABELS(i))
   endif
   endfunction axis_submenu

   function legend_menu(p, visible) result(changed)
   !< `ShowLegendContextMenu`: Show, horizontal or vertical, the location's buttons (the centre's invisible).
   type(plot3d_record), intent(inout) :: p       !< Plot.
   logical,             intent(in)    :: visible !< The legend shown.
   logical                            :: changed !< Show toggled.
   logical                            :: v       !< A box.
   real(real64)                       :: s, bw   !< Frame height, a button's width.

   s = real(real(core_frame_height(), real32), real64)
   bw = real(1.5_real32 * real(s, real32), real64)
   v = visible
   changed = ig_checkbox('Show', v)
   if (core_radio_button('H', has_flag(p%legend_flags, L3_HORIZONTAL))) &
      p%legend_flags = ior(p%legend_flags, L3_HORIZONTAL)
   call ig_same_line()
   if (core_radio_button('V', .not. has_flag(p%legend_flags, L3_HORIZONTAL))) &
      p%legend_flags = iand(p%legend_flags, not(L3_HORIZONTAL))
   call core_push_style_var(ImGuiStyleVar_ItemSpacing, 2.0_real64, 2.0_real64)
   if (ig_button('NW', bw, s)) p%legend_loc = LOC_NORTH + LOC_WEST
   call ig_same_line()
   if (ig_button('N', bw, s)) p%legend_loc = LOC_NORTH
   call ig_same_line()
   if (ig_button('NE', bw, s)) p%legend_loc = LOC_NORTH + LOC_EAST
   if (ig_button('W', bw, s)) p%legend_loc = LOC_WEST
   call ig_same_line()
   if (core_invisible_button('C', bw, s)) continue
   call ig_same_line()
   if (ig_button('E', bw, s)) p%legend_loc = LOC_EAST
   if (ig_button('SW', bw, s)) p%legend_loc = LOC_SOUTH + LOC_WEST
   call ig_same_line()
   if (ig_button('S', bw, s)) p%legend_loc = LOC_SOUTH
   call ig_same_line()
   if (ig_button('SE', bw, s)) p%legend_loc = LOC_SOUTH + LOC_EAST
   call core_pop_style_var()
   endfunction legend_menu

   subroutine flag_box(label, flags, flag)
   !< `CheckboxFlags` of one bit.
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

   pure subroutine flip(flags, flag)
   !< `ImFlipFlag`.
   integer(int32), intent(inout) :: flags !< Flags.
   integer(int32), intent(in)    :: flag  !< The bit.

   if (has_flag(flags, flag)) then
      flags = iand(flags, not(flag))
   else
      flags = ior(flags, flag)
   endif
   endsubroutine flip

   function set_min(p, i, v) result(done)
   !< `SetMin(v, force=true)`: the minimum within the constraints and below the maximum.
   type(plot3d_record), intent(inout) :: p    !< Plot.
   integer(int32),      intent(in)    :: i    !< Axis.
   real(real64),        intent(in)    :: v    !< Minimum.
   logical                            :: done !< Set.
   real(real64)                       :: m, zoom !< Value, size.

   done = .false.
   m = constrain_nan(constrain_inf(v))
   if (m < p%ax(i)%con_min) m = p%ax(i)%con_min
   zoom = p%v%rmax(i) - m
   if (zoom < p%ax(i)%zoom_min) m = p%v%rmax(i) - p%ax(i)%zoom_min
   if (zoom > p%ax(i)%zoom_max) m = p%v%rmax(i) - p%ax(i)%zoom_max
   if (m >= p%v%rmax(i)) return
   p%v%rmin(i) = m
   call update_scaled(p, i)
   done = .true.
   endfunction set_min

   function set_max(p, i, v) result(done)
   !< `SetMax(v, force=true)`: the maximum within the constraints and above the minimum.
   type(plot3d_record), intent(inout) :: p    !< Plot.
   integer(int32),      intent(in)    :: i    !< Axis.
   real(real64),        intent(in)    :: v    !< Maximum.
   logical                            :: done !< Set.
   real(real64)                       :: m, zoom !< Value, size.

   done = .false.
   m = constrain_nan(constrain_inf(v))
   if (m > p%ax(i)%con_max) m = p%ax(i)%con_max
   zoom = m - p%v%rmin(i)
   if (zoom < p%ax(i)%zoom_min) m = p%v%rmin(i) + p%ax(i)%zoom_min
   if (zoom > p%ax(i)%zoom_max) m = p%v%rmin(i) + p%ax(i)%zoom_max
   if (m <= p%v%rmin(i)) return
   p%v%rmax(i) = m
   call update_scaled(p, i)
   done = .true.
   endfunction set_max

   ! private: items and legend

   function register_item(p, label, flags, created) result(h)
   !< `RegisterOrGetItem`: the item of the label's ID (added when new); the first time this frame, a legend entry
   !< when the label shows something and the item has one.
   type(plot3d_record), intent(inout) :: p       !< Plot.
   character(len=*),    intent(in)    :: label   !< Label.
   integer(int32),      intent(in)    :: flags   !< Item flags.
   logical,             intent(out)   :: created !< New.
   integer(int32)                     :: h       !< The item.
   integer(int32)                     :: id, k   !< ID, counter.

   id = core_get_id(label)
   h = 0_int32
   do k = 1_int32, p%n_items
      if (p%it(k)%id == id) then
         h = k
         exit
      endif
   enddo
   created = h == 0_int32
   if (created) then
      if (.not. allocated(p%it)) allocate(p%it(8))
      if (p%n_items == size(p%it, kind=int32)) call grow_items(p)
      p%n_items = p%n_items + 1_int32
      h = p%n_items
      p%it(h)%id = id
      p%it(h)%color = 0_int32
      p%it(h)%show = .true.
      p%it(h)%legend_hovered = .false.
      p%it(h)%seen = .false.
      p%it(h)%name_len = 0_int32
   endif
   if (p%it(h)%seen) return
   p%it(h)%seen = .true.
   if (.not. has_flag(flags, I3_NO_LEGEND) .and. rendered_len(label) > 0_int32) then
      if (.not. allocated(p%leg)) allocate(p%leg(8))
      if (p%n_leg == size(p%leg, kind=int32)) call grow_leg(p)
      p%n_leg = p%n_leg + 1_int32
      p%leg(p%n_leg) = h
      p%it(h)%name_len = min(len(label, kind=int32), TEXT_LEN)
      p%it(h)%name(1:p%it(h)%name_len) = label(1:p%it(h)%name_len)
   endif
   endfunction register_item

   subroutine grow_items(p)
   !< Room for twice the items, those held kept (element by element).
   type(plot3d_record), intent(inout) :: p       !< Plot.
   type(item3d), allocatable          :: more(:) !< New pool.
   integer(int32)                     :: k       !< Counter.

   allocate(more(2_int32 * size(p%it, kind=int32)))
   do k = 1_int32, p%n_items
      more(k) = p%it(k)
   enddo
   call move_alloc(more, p%it)
   endsubroutine grow_items

   subroutine grow_leg(p)
   !< Room for twice the legend entries.
   type(plot3d_record), intent(inout) :: p       !< Plot.
   integer(int32), allocatable        :: more(:) !< New list.

   allocate(more(2_int32 * size(p%leg, kind=int32)))
   more(1:p%n_leg) = p%leg(1:p%n_leg)
   call move_alloc(more, p%leg)
   endsubroutine grow_leg

   subroutine extend_fit(p, i, v)
   !< `ImPlot3DAxis::ExtendFit` for an axis to fit: a finite value within the constraints widens the fit extents.
   type(plot3d_record), intent(inout) :: p !< Plot.
   integer(int32),      intent(in)    :: i !< Axis.
   real(real64),        intent(in)    :: v !< Value.

   if (.not. p%ax(i)%fit) return
   if (.not. ieee_is_finite(v)) return
   if (v >= p%ax(i)%con_min .and. v <= p%ax(i)%con_max) then
      p%ax(i)%fit_min = min(p%ax(i)%fit_min, v)
      p%ax(i)%fit_max = max(p%ax(i)%fit_max, v)
   endif
   endsubroutine extend_fit

   pure subroutine unpack_u32(col, c)
   !< `ColorConvertU32ToFloat4`: each byte times 1/255 (floats).
   integer(int32), intent(in)  :: col  !< Packed colour.
   real(real32),   intent(out) :: c(4) !< RGBA.
   integer(int64)              :: u    !< Unsigned.
   integer(int32)              :: k    !< Channel.

   u = iand(int(col, int64), 4294967295_int64)
   do k = 1_int32, 4_int32
      c(k) = real(iand(ishft(u, -8 * (k - 1_int32)), 255_int64), real32) * (1.0_real32 / 255.0_real32)
   enddo
   endsubroutine unpack_u32

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

   subroutine render_legend(p)
   !< `RenderLegend`: the entries' box at its location in the plot rectangle (clamped, scrolled by the wheel when it
   !< overflows), its button, background, entries and border.
   type(plot3d_record), intent(inout) :: p     !< Plot.
   real(real32)                       :: sz(2), pos(2), step, mins(2), off(2), mx, my !< Work.
   real(real64)                       :: dx, dy, wheel, wheel_h, drag(5) !< io.
   integer(int32)                     :: mods  !< io.KeyMods.
   logical                            :: horz, scrollable, dd, clicked !< Work.

   if (has_flag(p%flags, F3_NO_LEGEND) .or. p%n_leg == 0_int32) return
   horz = has_flag(p%legend_flags, L3_HORIZONTAL)
   call legend_size(p, .not. horz, sz)
   call location_pos(p%v%rect, sz(1), sz(2), p%legend_loc, LEGEND_PADDING(1), LEGEND_PADDING(2), pos)
   p%leg_rect(1:2) = pos
   p%leg_rect(3:4) = pos + sz
   p%leg_clamped = p%leg_rect
   scrollable = .false.
   if (p%leg_clamped(1) < p%v%rect(1) + LEGEND_PADDING(1)) then
      p%leg_clamped(1) = p%v%rect(1) + LEGEND_PADDING(1)
      scrollable = .true.
   endif
   if (p%leg_clamped(2) < p%v%rect(2) + LEGEND_PADDING(2)) then
      p%leg_clamped(2) = p%v%rect(2) + LEGEND_PADDING(2)
      scrollable = .true.
   endif
   if (p%leg_clamped(3) > p%v%rect(3) - LEGEND_PADDING(1)) then
      p%leg_clamped(3) = p%v%rect(3) - LEGEND_PADDING(1)
      scrollable = .true.
   endif
   if (p%leg_clamped(4) > p%v%rect(4) - LEGEND_PADDING(2)) then
      p%leg_clamped(4) = p%v%rect(4) - LEGEND_PADDING(2)
      scrollable = .true.
   endif
   call core_keep_alive(p%id - 1_int32)
   clicked = core_button_behavior(real(p%leg_clamped(1), real64), real(p%leg_clamped(2), real64),         &
                                  real(p%leg_clamped(3), real64), real(p%leg_clamped(4), real64), p%id - 1_int32, &
                                  p%leg_hovered, p%leg_held, flags=LEGEND_BUTTON_FLAGS)
   if (pointer(mx, my)) p%leg_hovered = p%leg_hovered .or. (mx >= p%leg_clamped(1) .and. my >= p%leg_clamped(2) .and. &
                                                            mx < p%leg_clamped(3) .and. my < p%leg_clamped(4))
   if (scrollable) then
      if (p%leg_hovered) then
         call core_set_key_owner(ImGuiKey_MouseWheelY, p%id - 1_int32)
         call core_io_input(dx, dy, wheel, wheel_h, drag, mods, dd)
         if (wheel /= 0.0_real64) then
            step = im_floor(min(2.0_real32 * real(core_font_size(), real32), (p%leg_rect(3) - p%leg_rect(1)) * 0.67_real32))
            p%leg_scroll(1) = p%leg_scroll(1) + step * real(wheel, real32)
            p%leg_scroll(2) = p%leg_scroll(2) + step * real(wheel, real32)
         endif
      endif
      mins(1) = (p%leg_clamped(3) - p%leg_clamped(1)) - (p%leg_rect(3) - p%leg_rect(1))
      mins(2) = (p%leg_clamped(4) - p%leg_clamped(2)) - (p%leg_rect(4) - p%leg_rect(2))
      p%leg_scroll(1) = min(max(p%leg_scroll(1), mins(1)), 0.0_real32)
      p%leg_scroll(2) = min(max(p%leg_scroll(2), mins(2)), 0.0_real32)
      off = p%leg_clamped(1:2) - p%leg_rect(1:2)
      if (horz) then
         off(1) = off(1) + p%leg_scroll(1)
      else
         off(2) = off(2) + p%leg_scroll(2)
      endif
      p%leg_rect(1:2) = p%leg_rect(1:2) + off
      p%leg_rect(3:4) = p%leg_rect(3:4) + off
   else
      p%leg_scroll = 0.0_real32
   endif
   call core_push_clip_rect(real(p%leg_clamped(1), real64), real(p%leg_clamped(2), real64), &
                            real(p%leg_clamped(3), real64), real(p%leg_clamped(4), real64), intersect=.true.)
   call core_draw_begin()
   call core_draw_rect_filled(real(p%leg_clamped(1), real64), real(p%leg_clamped(2), real64), &
                              real(p%leg_clamped(3), real64), real(p%leg_clamped(4), real64), &
                              style3_u32(S3_LEGEND_BG))
   call legend_entries(p, .not. horz)
   call core_draw_rect(real(p%leg_clamped(1), real64), real(p%leg_clamped(2), real64), &
                       real(p%leg_clamped(3), real64), real(p%leg_clamped(4), real64), style3_u32(S3_LEGEND_BORDER))
   call core_draw_end()
   call core_pop_clip_rect()
   endsubroutine render_legend

   subroutine legend_size(p, vertical, sz)
   !< `CalcLegendSize`: the padding, an icon a line high per entry, the widest label (or the labels' sum in a row).
   type(plot3d_record), intent(in)  :: p        !< Plot.
   logical,             intent(in)  :: vertical !< A column.
   real(real32),        intent(out) :: sz(2)    !< Size.
   real(real32)                     :: ht, mx_w, sum_w, lw !< Line height, widths.
   real(real64)                     :: w, h     !< A label's size.
   integer(int32)                   :: i, n     !< Entry, entries.

   ht = real(core_font_size(), real32)
   n = p%n_leg
   mx_w = 0.0_real32
   sum_w = 0.0_real32
   do i = 1_int32, n
      call core_text_size(p%it(p%leg(i))%name(1:p%it(p%leg(i))%name_len), w, h, hide_after_hash=.true.)
      lw = real(w, real32)
      if (lw > mx_w) mx_w = lw
      sum_w = sum_w + lw
   enddo
   if (vertical) then
      sz(1) = LEGEND_INNER_PADDING(1) * 2.0_real32 + ht + mx_w
      sz(2) = LEGEND_INNER_PADDING(2) * 2.0_real32 + real(n, real32) * ht + real(n - 1_int32, real32) * LEGEND_SPACING(2)
   else
      sz(1) = LEGEND_INNER_PADDING(1) * 2.0_real32 + ht * real(n, real32) + sum_w + &
              real(n - 1_int32, real32) * LEGEND_SPACING(1)
      sz(2) = LEGEND_INNER_PADDING(2) * 2.0_real32 + ht
   endif
   endsubroutine legend_size

   subroutine legend_entries(p, vertical)
   !< `ShowLegendEntries`: per entry, its button (a click hides or shows the item), its icon (the item's colour; lighter
   !< hovered or held, the disabled text's when hidden) and its label (mixed with the item's colour when hovered).
   type(plot3d_record), intent(inout) :: p        !< Plot.
   logical,             intent(in)    :: vertical !< A column.
   real(real32)                       :: ht, sum_w, lw, tl(2), ib(4), lb(4) !< Work.
   real(real64)                       :: w, h     !< A label's size.
   integer(int32)                     :: i, k, col_txt, col_dis, col_hl, col_item, col_icon !< Entry, item, colours.
   logical                            :: hov, hld, clk !< Its button.

   ht = real(core_font_size(), real32)
   col_txt = style3_u32(S3_LEGEND_TEXT)
   col_dis = alpha_u32(col_txt, 0.25_real32)
   sum_w = 0.0_real32
   do i = 1_int32, p%n_leg
      k = p%leg(i)
      call core_text_size(p%it(k)%name(1:p%it(k)%name_len), w, h, hide_after_hash=.true.)
      lw = real(w, real32)
      if (vertical) then
         tl(1) = p%leg_rect(1) + LEGEND_INNER_PADDING(1) + 0.0_real32
         tl(2) = p%leg_rect(2) + LEGEND_INNER_PADDING(2) + real(i - 1_int32, real32) * (ht + LEGEND_SPACING(2))
      else
         tl(1) = p%leg_rect(1) + LEGEND_INNER_PADDING(1) + &
                 (real(i - 1_int32, real32) * (ht + LEGEND_SPACING(1)) + sum_w)
         tl(2) = p%leg_rect(2) + LEGEND_INNER_PADDING(2) + 0.0_real32
      endif
      sum_w = sum_w + lw
      ib(1) = tl(1) + 2.0_real32
      ib(2) = tl(2) + 2.0_real32
      ib(3) = tl(1) + (ht - 2.0_real32)
      ib(4) = tl(2) + (ht - 2.0_real32)
      lb(1:2) = tl
      lb(3) = tl(1) + (lw + ht)
      lb(4) = tl(2) + ht
      col_item = alpha_u32(p%it(k)%color, 1.0_real32)
      call core_keep_alive(p%it(k)%id)
      hov = .false.
      hld = .false.
      clk = .false.
      if (.not. has_flag(p%legend_flags, L3_NO_BUTTONS)) &
         clk = core_button_behavior(real(ib(1), real64), real(ib(2), real64), real(lb(3), real64), real(lb(4), real64), &
                                    p%it(k)%id, hov, hld)
      if (clk) p%it(k)%show = .not. p%it(k)%show
      if (hov .and. .not. has_flag(p%legend_flags, L3_NO_HIGHLIGHT)) then
         p%it(k)%legend_hovered = .true.
         col_hl = mix_u32(col_txt, col_item, 64_int32)
      else
         p%it(k)%legend_hovered = .false.
         col_hl = style3_alpha_u32(col_txt) ! ImGui::GetColorU32(col_txt)
      endif
      if (hld) then
         if (p%it(k)%show) then
            col_icon = alpha_u32(col_item, 0.5_real32)
         else
            col_icon = core_style_color(ImGuiCol_TextDisabled, 0.5_real64)
         endif
      elseif (hov) then
         if (p%it(k)%show) then
            col_icon = alpha_u32(col_item, 0.75_real32)
         else
            col_icon = core_style_color(ImGuiCol_TextDisabled, 0.75_real64)
         endif
      else
         col_icon = col_item
         if (.not. p%it(k)%show) col_icon = col_dis
      endif
      call core_draw_rect_filled(real(ib(1), real64), real(ib(2), real64), real(ib(3), real64), real(ib(4), real64), &
                                 col_icon)
      if (rendered_len(p%it(k)%name(1:p%it(k)%name_len)) > 0_int32) &
         call core_draw_text(real(tl(1) + ht, real64), real(tl(2) + 0.0_real32, real64), merge(col_hl, col_dis, p%it(k)%show), &
                             p%it(k)%name(1:rendered_len(p%it(k)%name(1:p%it(k)%name_len))))
   enddo
   endsubroutine legend_entries

   ! private: tables

   function plot_handle(id, frame, created) result(h)
   !< The plot of an ID, added if new: in a free slot, the table grown (doubled up to PLOT_CAP), or in the slot of the
   !< least recently begun plot not begun on this frame (ImPlot3D never evicts).
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
   if (.not. allocated(plots)) allocate(plots(4))
   if (n_plots == size(plots, kind=int32) .and. n_plots >= PLOT_CAP) then
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
      if (n_plots == size(plots, kind=int32)) call grow_plots(2_int32 * n_plots)
      n_plots = n_plots + 1_int32
      h = n_plots
   endif
   call reset_plot(plots(h), id)
   endfunction plot_handle

   subroutine reset_plot(p, id)
   !< A slot made a new plot (`ImPlot3DPlot()`), field by field: nvfortran 26.9 assigns the structure constructor of a
   !< type with a component whose own type has an allocatable component (`plot3d_record%ax(3)`, whose ticks hold
   !< allocatable arrays) wrongly: an array element (`plots(h) = plot3d_record()`) segfaults in `pgf90_poly_asn_i8`, a
   !< scalar keeps the subcomponent allocated (an allocatable component directly in the type is right); and it emits
   !< invalid IR for a component default-initialised with a named constant of a derived type
   !< (https://github.com/szaghi/figure/issues/4#issuecomment-7110453868). The axes' tick arrays are kept.
   type(plot3d_record), intent(inout) :: p  !< Slot.
   integer(int32),      intent(in)    :: id !< ID.
   integer(int32)                     :: i  !< Axis.

   p%used = .true.
   p%id = id
   p%last_frame = -1_int32
   p%flags = 0_int32
   p%prev_flags = 0_int32
   p%title_len = 0_int32
   p%just_created = .true.
   p%initialized = .false.
   p%setup_locked = .false.
   p%fit = .true.
   p%hovered = .false.
   p%held = .false.
   p%held_edge = -1_int32
   p%held_plane = -1_int32
   p%rotation_cond = COND_NONE
   p%frame = 0.0_real32
   p%canvas = 0.0_real32
   p%v%rot = plot3d_quat(0.0_real64, 0.0_real64, 0.0_real64, 1.0_real64)
   p%v%rect = 0.0_real32
   p%v%factor = 1.0_real32
   p%initial_rotation = INITIAL_ROTATION
   p%anim_end = p%v%rot
   p%anim_time = 0.0_real32
   p%drag_axis = 0.0_real64
   p%context_click = .false.
   p%open_context = .false.
   p%legend_loc = LOC_NORTH + LOC_WEST
   p%legend_prev_loc = LOC_NORTH + LOC_WEST
   p%legend_flags = 0_int32
   p%legend_prev_flags = 0_int32
   p%n_items = 0_int32
   p%n_leg = 0_int32
   p%colormap_idx = 0_int32
   p%leg_rect = 0.0_real32
   p%leg_clamped = 0.0_real32
   p%leg_scroll = 0.0_real32
   p%leg_hovered = .false.
   p%leg_held = .false.
   do i = 1_int32, 3_int32
      call axis_defaults(p, i)
   enddo
   endsubroutine reset_plot

   subroutine grow_plots(m)
   !< Room for m plots, those held kept (element by element: ADR 0001).
   integer(int32), intent(in)       :: m       !< Room.
   type(plot3d_record), allocatable :: more(:) !< New table.
   integer(int32)                   :: k       !< Counter.

   allocate(more(m))
   do k = 1_int32, n_plots
      more(k) = plots(k)
   enddo
   call move_alloc(more, plots)
   endsubroutine grow_plots

   ! private: helpers

   function axis_index(axis) result(i)
   !< An axis's index from its name.
   character(len=*), intent(in) :: axis !< 'x', 'y' or 'z'.
   integer(int32)               :: i    !< 1-3.

   select case (axis)
   case ('x')
      i = 1_int32
   case ('y')
      i = 2_int32
   case ('z')
      i = 3_int32
   case default
      error stop "figure_plot3d_frame: an axis is 'x', 'y' or 'z'"
   endselect
   endfunction axis_index

   function pointer(mx, my) result(valid)
   !< The pointer's position (floats), when valid (FIGURE's patch: no hover without one).
   real(real32), intent(out) :: mx, my !< Pointer.
   logical                   :: valid  !< Valid.
   real(real64)              :: x, y   !< Position.

   mx = 0.0_real32
   my = 0.0_real32
   valid = core_mouse_pos_valid()
   if (.not. valid) return
   call core_mouse_pos(x, y)
   mx = real(x, real32)
   my = real(y, real32)
   endfunction pointer

   pure subroutine location_pos(r, w, h, loc, padx, pady, pos)
   !< `GetLocationPos`: a box of w x h placed in the rectangle at a compass point, `pad` in, rounded.
   real(real32),   intent(in)  :: r(4)       !< Rectangle.
   real(real32),   intent(in)  :: w, h       !< Box's size.
   integer(int32), intent(in)  :: loc        !< ImPlot3DLocation.
   real(real32),   intent(in)  :: padx, pady !< Padding.
   real(real32),   intent(out) :: pos(2)     !< Box's corner.

   if (has_flag(loc, LOC_WEST) .and. .not. has_flag(loc, LOC_EAST)) then
      pos(1) = r(1) + padx
   elseif (.not. has_flag(loc, LOC_WEST) .and. has_flag(loc, LOC_EAST)) then
      pos(1) = r(3) - padx - w
   else
      pos(1) = (r(1) + r(3)) * 0.5_real32 - w * 0.5_real32
   endif
   if (has_flag(loc, LOC_NORTH) .and. .not. has_flag(loc, LOC_SOUTH)) then
      pos(2) = r(2) + pady
   elseif (.not. has_flag(loc, LOC_NORTH) .and. has_flag(loc, LOC_SOUTH)) then
      pos(2) = r(4) - pady - h
   else
      pos(2) = (r(2) + r(4)) * 0.5_real32 - h * 0.5_real32
   endif
   pos(1) = real(int(pos(1) + 0.5_real32, int32), real32)
   pos(2) = real(int(pos(2) + 0.5_real32, int32), real32)
   endsubroutine location_pos

   pure function lighter(col) result(c)
   !< PlotBg plus 0.03 on each colour channel (`col_bg + ImVec4(0.03, 0.03, 0.03, 0)`), from the packed colour.
   integer(int32), intent(in) :: col !< Packed colour.
   integer(int32)             :: c   !< Lighter.
   integer(int64)             :: u, ch, r !< Unsigned, a channel, the result.
   integer(int32)             :: k   !< Channel.
   real(real32)               :: f   !< A channel in [0, 1].

   u = iand(int(col, int64), 4294967295_int64)
   r = iand(u, ishft(255_int64, 24))
   do k = 0_int32, 2_int32
      ch = iand(ishft(u, -8 * k), 255_int64)
      f = real(ch, real32) * (1.0_real32 / 255.0_real32) + 0.03_real32
      f = min(max(f, 0.0_real32), 1.0_real32)
      r = ior(r, ishft(int(f * 255.0_real32 + 0.5_real32, int64), 8 * k))
   enddo
   if (r >= 2147483648_int64) r = r - 4294967296_int64
   c = int(r, int32)
   endfunction lighter

   pure function has_flag(flags, flag) result(yes)
   !< Whether all of `flag`'s bits are set.
   integer(int32), intent(in) :: flags, flag !< Flags, the flag.
   logical                    :: yes         !< Set.

   yes = iand(flags, flag) == flag
   endfunction has_flag

   pure function opt(x) result(on)
   !< An optional flag, false when absent.
   logical, intent(in), optional :: x  !< Flag.
   logical                       :: on !< Its value.

   on = .false.
   if (present(x)) on = x
   endfunction opt

   pure function almost_equal(v1, v2) result(yes)
   !< `ImAlmostEqual` (2 ulps).
   real(real64), intent(in) :: v1, v2 !< Values.
   logical                  :: yes    !< Almost equal.

   yes = abs(v1 - v2) < epsilon(1.0_real64) * abs(v1 + v2) * 2.0_real64 .or. abs(v1 - v2) < tiny(1.0_real64)
   endfunction almost_equal

   pure function constrain_nan(v) result(c)
   !< `ImConstrainNan`: NaN to 0.
   real(real64), intent(in) :: v !< Value.
   real(real64)             :: c !< Constrained.

   c = v
   if (ieee_is_nan(v)) c = 0.0_real64
   endfunction constrain_nan

   pure function constrain_inf(v) result(c)
   !< `ImConstrainInf`: within half the largest double.
   real(real64), intent(in) :: v !< Value.
   real(real64)             :: c !< Constrained.

   c = v
   if (v >= huge(1.0_real64) * 0.5_real64) then
      c = huge(1.0_real64) * 0.5_real64
   elseif (v <= -huge(1.0_real64) * 0.5_real64) then
      c = -huge(1.0_real64) * 0.5_real64
   endif
   endfunction constrain_inf

   pure function rendered_len(label) result(n)
   !< The shown part of a label: up to its first '##'.
   character(len=*), intent(in) :: label !< Label.
   integer(int32)               :: n     !< Characters shown.

   n = int(index(label, '##'), int32) - 1_int32
   if (n < 0_int32) n = len(label, kind=int32)
   endfunction rendered_len

   pure function im_floor(f) result(r)
   !< `ImFloor` of a float.
   real(real32), intent(in) :: f !< Value.
   real(real32)             :: r !< Floor.

   r = real(int(f, int32), real32)
   if (f < 0.0_real32 .and. r /= f) r = r - 1.0_real32
   endfunction im_floor

   pure subroutine utf8_char(s, k, c, nb)
   !< The character at byte k of a UTF-8 text (`ImTextCharFromUtf8`): its code point and bytes (malformed: U+FFFD).
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
endmodule figure_plot3d_frame
