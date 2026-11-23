!< figure_plot_frame, the Fortran path's plot frame: a plot's layout, axes, ticks, grid and lines, as ImPlot draws them.
module figure_plot_frame
!< figure_plot_frame, the Fortran path's plot frame: a plot's layout, axes, ticks, grid and lines, as ImPlot draws them.
!<
!< szaghi/figure#15 P10. A plot drawn through figure_core only (no ImPlot, no figure_cimplot), to the pixels ImPlot 1.2
!< WIP (FIGURE's copy) draws for the same plot: `pf_begin_plot`, `pf_setup_axes`, `pf_setup_axis`,
!< `pf_setup_axes_limits`, `pf_setup_axis_limits`, `pf_set_next_axes_to_fit`, `pf_set_next_axis_to_fit`, `pf_line`,
!< `pf_plot_limits`, `pf_end_plot` draw what `ip_begin_plot`, `ip_setup_axes`, `ip_setup_axis`,
!< `ip_setup_axes_limits`, `ip_setup_axis_limits`, ImPlot's `SetNextAxesToFit`/`SetNextAxisToFit`, `ip_line`,
!< `ip_plot_limits`, `ip_end_plot` draw for a plot of two linear axes (X1, Y1), no title, no axis labels, no legend,
!< lines of the default weight, the pointer away from the plot. Reproduced from implot.cpp, implot_items.cpp and
!< implot_internal.h, their arithmetic kept (single precision where ImPlot's is `float`, double where it is `double`):
!<
!< - the plots kept between frames (`ImPlotContext::Plots`, `ImPlotPlot`): a table of plots keyed by the ID of their
!<   title in the window's ID stack (`core_get_id`, ImPlot's `Window->GetID(title_id)`), each with its axes (range,
!<   flags, the limits' condition, the range fit), its items and the frame it was last drawn on; integer handles into a
!<   table that grows (8 plots, doubled up to 256; past that the least recently drawn plot not drawn on this frame makes
!<   room: ImPlot keeps every plot for the context's life); one plot open at a time (ImPlot forbids nesting), several
!<   one after another in a frame;
!< - a plot's items (`ImPlotItemGroup`): keyed by the ID ImPlot gives them, the label hashed with the seed
!<   `plot.ID - 1` (figure_plot_hash), each with its colour, given (`color=`) or assigned once, when the item is
!<   created, from the colormap's next colour (`NextColormapColorU32`: the plot's own counter, `ColormapIdx`), and
!<   kept after; a table per plot, as the plots' (256 items, then the least recently drawn one makes room);
!< - the limits (`SetupAxisLimits`): applied every frame (`ImPlotCond_Always`, which also locks the axis against any
!<   fit), or until the plot has been drawn once (`ImPlotCond_Once`, the default as FIGURE's `ip_setup_*_limits`);
!< - the fit to the data (`SetupFinish`, `BeginItemEx`, `EndPlot`, `ImPlotAxis::ExtendFitWith`, `ApplyFit`): an axis
!<   fits on the plot's first frame if it has no limits (`CanInitFit`), on every frame with `auto_fit`
!<   (`ImPlotAxisFlags_AutoFit`), on the frame after `pf_set_next_axis_to_fit`; the items extend the fit range while
!<   the plot is drawn with its current ranges, and the fit is applied at `pf_end_plot`: the picture shows it on the
!<   next frame (ImPlot's one-frame lag). The fit pads the range by `FitPadding` (0, ImPlot's default), a degenerate
!<   range (`ImAlmostEqual` of its ends, 2 ulp) becomes [v - 0.5, v + 0.5]; ends locked (`lock`, limits `always`) are
!<   kept. An axis with no data does not fit (FIGURE's `fig_plot_end`). x and y follow the same rules; with
!<   `equal=.true.` (`ImPlotFlags_Equal`) both get the same units per pixel, as `SetupFinish` and `EndPlot` constrain
!<   them;
!< - the layout of `BeginPlot` and `SetupFinish`: the frame, `PlotPadding`, the X axis's tick labels below the plot
!<   (their height, `LabelPadding`), the Y axis's left of it (their widest label): the plot rectangle;
!< - the ticks of `Locator_Default`: the major count from the axis length (a major per 400 pixels on x, 300 on y, at
!<   least 2), `NiceNum`, majors accumulated by `major += interval` with the zero snapped, ten labelled minors per
!<   major, the labels thinned (every other one from the first major) when they fill more than 0.8 (x) or 1.0 (y) of
!<   the axis; labels as `Formatter_Default` writes them, C's `%g` (foresight's printf formatter: glibc's output from
!<   the exact binary value);
!< - the drawing of `SetupFinish` and `EndPlot`, in their order: the frame (`RenderFrame`, `FrameBg`), the plot's
!<   background (`WindowBg`), the grid (majors, minors faded by `MinorAlpha` and by the ticks' density), the tick labels
!<   (`Text`), the items clipped to the plot, the tick marks (clipped to the frame), the border (`Border`); ImPlot's
!<   automatic colours (`StyleColorsAuto`, from Dear ImGui's style colours) and its default style variables;
!< - a line (`PlotLine`'s `RendererLineStrip`): each segment a quad of the anti-aliased line's texture, half its
!<   weight (at least 1 pixel) plus half the texture's fringe on each side, the segments outside the plot culled.
!<
!< Not yet (P10's rest, P11, P12): other scales, pan, zoom and selection, hovering, legends, titles, axis labels, more
!< axes, colormaps other than Deep (the line colours of FIGURE's own styles: seal, paper, ...: their automatic colours
!< are ImPlot's colormaps, registered by the native layer), ImPlot style variables set by a theme (`FitPadding`
!< included), limits' constraints, `ImPlotAxisFlags_NoInitialFit` and `RangeFit` from the API (kept in the state).
!< Items are hashed under the plot's seed but the ID stack is not pushed (figure_core has no `PushOverrideID`): a Dear
!< ImGui widget drawn between `pf_begin_plot` and `pf_end_plot` gets another ID than in ImPlot. The segment's normal is
!< `1/sqrt` where ImPlot takes the SSE estimate `_mm_rsqrt_ss` (12 bits): the line's vertices may differ from ImPlot's
!< below a thousandth of a pixel.
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use figure_cimgui_enums, only : ImGuiCol_Border, ImGuiCol_BorderShadow, ImGuiCol_FrameBg, ImGuiCol_Text, &
                                ImGuiCol_WindowBg
use figure_core, only : core_color, core_content_region_avail, core_cursor_screen_pos, core_draw_begin, core_draw_end, &
                        core_draw_line_h, core_draw_line_v, core_draw_quad_uv, core_draw_rect, core_draw_rect_filled,  &
                        core_draw_text, core_font_size, core_frame_count, core_get_id, core_item_add, core_item_size,  &
                        core_line_texture, core_pop_clip_rect, core_push_clip_rect, core_style_color, core_style_var,  &
                        core_text_size
use figure_plot_hash, only : plot_hash, plot_id_offset
use foresight_format, only : c_real

implicit none
private
public :: pf_begin_plot, pf_end_plot, pf_line, pf_plot_limits
public :: pf_setup_axes, pf_setup_axis, pf_setup_axes_limits, pf_setup_axis_limits
public :: pf_set_next_axes_to_fit, pf_set_next_axis_to_fit
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
real(real32), parameter :: FIT_PADDING(2) = [0.0_real32, 0.0_real32]           !< FitPadding (fraction of the range).
real(real32), parameter :: LINE_WEIGHT = 1.0_real32                            !< ImPlotSpec's LineWeight [pixels].
! Locator_Default
real(real32),   parameter :: TICK_FILL_X = 0.8_real32 !< Labels may fill this much of an x axis.
real(real32),   parameter :: TICK_FILL_Y = 1.0_real32 !< ... of a y axis.
integer(int32), parameter :: N_MINOR = 10_int32       !< Minor intervals per major.
integer(int32), parameter :: LABEL_LEN = 32_int32     !< IMPLOT_LABEL_MAX_SIZE.
! the axes (ImAxis, one-based)
integer(int32), parameter :: AX_X1 = 1_int32 !< X1.
integer(int32), parameter :: AX_X3 = 3_int32 !< X3.
integer(int32), parameter :: AX_Y1 = 4_int32 !< Y1.
integer(int32), parameter :: AX_Y3 = 6_int32 !< Y3.
integer(int32), parameter :: AXES = 6_int32  !< ImAxis_COUNT.
! ImPlotAxisFlags, ImPlotFlags, ImPlotCond (implot.h)
integer(int32), parameter :: AXF_NO_INITIAL_FIT = 16_int32 !< ImPlotAxisFlags_NoInitialFit.
integer(int32), parameter :: AXF_AUTO_FIT = 2048_int32     !< ImPlotAxisFlags_AutoFit.
integer(int32), parameter :: AXF_RANGE_FIT = 4096_int32    !< ImPlotAxisFlags_RangeFit.
integer(int32), parameter :: AXF_LOCK_MIN = 16384_int32    !< ImPlotAxisFlags_LockMin.
integer(int32), parameter :: AXF_LOCK_MAX = 32768_int32    !< ImPlotAxisFlags_LockMax.
integer(int32), parameter :: PF_EQUAL = 128_int32          !< ImPlotFlags_Equal.
integer(int32), parameter :: COND_ALWAYS = 1_int32         !< ImPlotCond_Always.
integer(int32), parameter :: COND_ONCE = 2_int32           !< ImPlotCond_Once.
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

type :: tick_list
   !< An axis's ticks (ImPlotTicker): kept from frame to frame, grown when needed (no allocation per frame).
   integer(int32)                        :: n = 0_int32            !< Ticks.
   real(real64),             allocatable :: pos(:)                 !< Value.
   real(real32),             allocatable :: pix(:)                 !< Pixel (rounded).
   real(real32),             allocatable :: label_size(:,:)        !< Label's size (2, n) [pixels].
   logical,                  allocatable :: major(:)               !< A major tick.
   logical,                  allocatable :: show(:)                !< Its label shown.
   character(len=LABEL_LEN), allocatable :: label(:)               !< Label.
   real(real32)                          :: max_size(2) = 0.0_real32 !< The largest label (shown when added).
endtype tick_list

type :: plot_axis
   !< An axis (ImPlotAxis): its state kept between frames, and where its range is on screen this frame.
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
   real(real32)   :: datum1 = 0.0_real32              !< Where the axis's ticks start [pixels].
endtype plot_axis

type :: plot_record
   !< A plot (ImPlotPlot): what is kept between frames, and its layout on the frame it is drawn.
   integer(int32)              :: id = 0_int32          !< ID (its title's in the window's ID stack).
   logical                     :: used = .false.        !< The slot holds a plot.
   integer(int32)              :: last_frame = -1_int32 !< The frame it was last begun on.
   logical                     :: just_created = .false. !< Created on this frame.
   logical                     :: initialized = .false. !< Drawn to its end once.
   logical                     :: locked = .false.      !< Setup finished on this frame (layout done, frame drawn).
   logical                     :: fit = .false.         !< An axis fits at the end of this frame (FitThisFrame).
   integer(int32)              :: flags = 0_int32       !< ImPlotFlags in effect.
   integer(int32)              :: prev_flags = 0_int32  !< ... those last asked.
   real(real32)                :: frame(4) = 0.0_real32 !< Frame rectangle: x min, y min, x max, y max [pixels].
   real(real32)                :: canvas(4) = 0.0_real32 !< Canvas: the frame less the padding.
   real(real32)                :: rect(4) = 0.0_real32  !< Plot rectangle.
   integer(int32)              :: col_maj = 0_int32     !< Major grid lines' colour.
   integer(int32)              :: col_min = 0_int32     !< Minor grid lines' colour.
   integer(int32)              :: col_tick = 0_int32    !< Tick marks' colour.
   integer(int32)              :: col_txt = 0_int32     !< Tick labels' colour.
   integer(int32)              :: col_border = 0_int32  !< Border's colour.
   type(plot_axis)             :: ax(AXES)              !< Axes: X1, X2, X3, Y1, Y2, Y3.
   integer(int32)              :: colormap_idx = 0_int32 !< Automatic colours given (ColormapIdx).
   integer(int32)              :: n_items = 0_int32     !< Items held.
   integer(int32)              :: item_next = 1_int32   !< Where the search for the next item starts.
   integer(int32), allocatable :: item_id(:)            !< Item's ID.
   integer(int32), allocatable :: item_color(:)         !< ... colour (packed).
   integer(int32), allocatable :: item_frame(:)         !< ... the frame it was last drawn on.
endtype plot_record

type(plot_record), allocatable, target :: plots(:)       !< The plots (ImPlotContext::Plots).
integer(int32)                         :: n_plots = 0_int32 !< Slots of `plots` in use.
integer(int32)                         :: cur = 0_int32  !< The plot open (0: none).
logical                                :: next_fit(AXES) = .false. !< Axes to fit on the next plot (NextPlotData.Fit).
type(tick_list), target                :: ticks(2)       !< The open plot's ticks: x (X1), y (Y1).

contains
   function pf_begin_plot(title, width, height, equal) result(visible)
   !< Begin a plot (`BeginPlot`): its frame placed at the cursor, `width` x `height` pixels (default: the full width,
   !< ImPlot's default height; a negative size is the room left less it); `equal`: the same units per pixel on x and
   !< y (`ImPlotFlags_Equal`). When true, declare its content and call `pf_end_plot`. A plot is kept between frames by
   !< its ID (its title's).
   character(len=*), intent(in)           :: title   !< Title (also the plot's ID; '##id' hides it).
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
      enddo
      p%ax(AX_X1)%enabled = .true.
      p%ax(AX_Y1)%enabled = .true.
      p%ax(AX_X1)%has_range = .false. ! ApplyNextPlotData: no SetNextAxisLimits
      p%ax(AX_Y1)%has_range = .false.
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
         next_fit = .false. ! ResetCtxForNextPlot
         return
      endif
   endassociate
   cur = h
   visible = .true.
   endfunction pf_begin_plot

   subroutine pf_setup_axes(xlabel, ylabel, auto_fit)
   !< The axes X1 and Y1 (`SetupAxes`; `ip_setup_axes`): call after `pf_begin_plot`, before any item. `auto_fit`: both
   !< fit the data every frame (`ImPlotAxisFlags_AutoFit`). The flags persist: a plot keeps them on the frames this is
   !< not called. Labels: none yet ('' or '##...').
   character(len=*), intent(in)           :: xlabel   !< X label.
   character(len=*), intent(in)           :: ylabel   !< Y label.
   logical,          intent(in), optional :: auto_fit !< Fit the data every frame.

   call pf_setup_axis('x1', xlabel, auto_fit=auto_fit)
   call pf_setup_axis('y1', ylabel, auto_fit=auto_fit)
   endsubroutine pf_setup_axes

   subroutine pf_setup_axis(axis, label, auto_fit, lock)
   !< One axis (`SetupAxis`; `ip_setup_axis`): `'x1'` or `'y1'` (the others not yet); call after `pf_begin_plot`,
   !< before any item. `auto_fit`: it fits the data every frame; `lock`: its ends stay (`ImPlotAxisFlags_Lock`: no fit
   !< moves them). The flags persist: a plot keeps them on the frames this is not called. Labels: none yet.
   character(len=*), intent(in)           :: axis     !< 'x1', 'y1'.
   character(len=*), intent(in), optional :: label    !< Label ('' or '##...').
   logical,          intent(in), optional :: auto_fit !< Fit the data every frame.
   logical,          intent(in), optional :: lock     !< Ends locked.
   integer(int32)                         :: flags    !< ImPlotAxisFlags.

   if (cur == 0_int32) error stop 'figure_plot_frame: pf_setup_axis outside a plot'
   if (plots(cur)%locked) error stop 'figure_plot_frame: pf_setup_axis after the setup (an item, pf_plot_limits)'
   if (present(label)) then
      if (label_shown(label)) error stop 'figure_plot_frame: pf_setup_axis: axis labels are not drawn yet'
   endif
   flags = 0_int32
   if (present(auto_fit)) then
      if (auto_fit) flags = ior(flags, AXF_AUTO_FIT)
   endif
   if (present(lock)) then
      if (lock) flags = ior(flags, ior(AXF_LOCK_MIN, AXF_LOCK_MAX))
   endif
   call setup_axis(plots(cur), axis_code(axis), flags)
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
   !< The range of one axis (`SetupAxisLimits`; `ip_setup_axis_limits`), `'x1'` or `'y1'`: applied until the plot
   !< has been drawn once, or every frame with `always=.true.`. Call after `pf_begin_plot`, before any item.
   character(len=*), intent(in)           :: axis   !< 'x1', 'y1'.
   real(real64),     intent(in)           :: vmin   !< Lower end.
   real(real64),     intent(in)           :: vmax   !< Upper end.
   logical,          intent(in), optional :: always !< Every frame.
   integer(int32)                         :: i      !< Axis.
   integer(int32)                         :: cond   !< ImPlotCond.

   if (cur == 0_int32) error stop 'figure_plot_frame: pf_setup_axis_limits outside a plot'
   if (plots(cur)%locked) error stop 'figure_plot_frame: pf_setup_axis_limits after the setup'
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

   subroutine pf_set_next_axis_to_fit(axis)
   !< Fit one axis (`'x1'` or `'y1'`) of the next plot begun to its data (`SetNextAxisToFit`): call before
   !< `pf_begin_plot`; the fit is applied at its `pf_end_plot` and shown from the frame after.
   character(len=*), intent(in) :: axis !< 'x1', 'y1'.

   if (cur /= 0_int32) error stop 'figure_plot_frame: pf_set_next_axis_to_fit inside a plot'
   next_fit(axis_code(axis)) = .true.
   endsubroutine pf_set_next_axis_to_fit

   subroutine pf_set_next_axes_to_fit()
   !< Fit every axis of the next plot begun to its data (`SetNextAxesToFit`): call before `pf_begin_plot`.

   if (cur /= 0_int32) error stop 'figure_plot_frame: pf_set_next_axes_to_fit inside a plot'
   next_fit = .true.
   endsubroutine pf_set_next_axes_to_fit

   subroutine pf_plot_limits(xmin, xmax, ymin, ymax)
   !< The ranges of X1 and Y1 the open plot is drawn with on this frame (`GetPlotLimits`; `ip_plot_limits`): ends its
   !< setup.
   real(real64), intent(out) :: xmin, xmax !< X axis's range.
   real(real64), intent(out) :: ymin, ymax !< Y axis's range.

   if (cur == 0_int32) error stop 'figure_plot_frame: pf_plot_limits outside a plot'
   if (.not. plots(cur)%locked) call setup_finish(plots(cur))
   xmin = plots(cur)%ax(AX_X1)%range_min
   xmax = plots(cur)%ax(AX_X1)%range_max
   ymin = plots(cur)%ax(AX_Y1)%range_min
   ymax = plots(cur)%ax(AX_Y1)%range_max
   endsubroutine pf_plot_limits

   subroutine pf_line(label, x, y, color)
   !< A line through the points (x(i), y(i)) (`PlotLine` of weight 1), clipped to the plot, of the colour `color`
   !< (`ip_spec(line_color=...)`), else of the colour its item was given when created: the plot's next automatic
   !< colour (ImPlot's colormap Deep: the styles `'dark'`, `'light'`, `'classic'`). The item is keyed by its label's
   !< ID; the label is not shown yet (no legend). Its points extend the fit of the axes that fit on this frame.
   character(len=*), intent(in)           :: label    !< Legend label (the item's ID).
   real(real64),     intent(in)           :: x(:)     !< Abscissae.
   real(real64),     intent(in)           :: y(:)     !< Ordinates.
   real(real64),     intent(in), optional :: color(4) !< Colour, RGBA in [0, 1].
   integer(int32)               :: col     !< Colour.
   real(real32)                 :: hw      !< Half the weight [pixels].
   real(real64)                 :: uv0(2), uv1(2), fringe !< The line's texture.
   real(real32)                 :: p1(2), p2(2) !< A segment's ends [pixels].
   real(real32)                 :: dx, dy, d2, inv !< Its direction.
   integer(int32)               :: k, n    !< Counter, points.
   integer(int32)               :: it      !< The item's handle.
   logical                      :: created !< The item is new.

   if (cur == 0_int32) error stop 'figure_plot_frame: pf_line outside a plot'
   associate(p => plots(cur))
      if (.not. p%locked) call setup_finish(p)
      it = item_handle(p, plot_hash(label, plot_id_offset(p%id, -1_int32)), core_frame_count(), created)
      if (present(color)) then ! BeginItem: the colour given, else the next automatic one if the item is new
         p%item_color(it) = core_color(color(1), color(2), color(3), color(4))
      elseif (created) then
         p%item_color(it) = rgb_u32(DEEP(:, modulo(p%colormap_idx, 10_int32) + 1_int32)) ! NextColormapColorU32
         p%colormap_idx = p%colormap_idx + 1_int32
      endif
      col = p%item_color(it)
      n = int(min(size(x), size(y)), int32)
      if (p%fit) call fit_points(p%ax(AX_X1), p%ax(AX_Y1), x, y, n) ! BeginItemEx's Fitter1
      if (n < 2_int32) return
      call core_push_clip_rect(real(p%rect(1), real64), real(p%rect(2), real64), real(p%rect(3), real64), &
                               real(p%rect(4), real64))
      hw = max(1.0_real32, LINE_WEIGHT) * 0.5_real32 ! RendererLineStrip, GetLineRenderProps
      call core_line_texture(real(hw * 2.0_real32, real64), uv0, uv1, fringe)
      hw = hw + real(fringe, real32) * 0.5_real32
      p1 = [to_pixels(p%ax(AX_X1), x(1)), to_pixels(p%ax(AX_Y1), y(1))]
      do k = 2_int32, n
         p2 = [to_pixels(p%ax(AX_X1), x(k)), to_pixels(p%ax(AX_Y1), y(k))]
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
   endsubroutine pf_line

   subroutine pf_end_plot()
   !< End the plot (`EndPlot`): the tick marks and the border; then the fit of the axes that fit on this frame, shown
   !< from the next one.
   real(real32)   :: len_, thk !< A tick's length and thickness.
   integer(int32) :: k         !< Counter.

   if (cur == 0_int32) error stop 'figure_plot_frame: pf_end_plot without a plot'
   associate(p => plots(cur))
      if (.not. p%locked) call setup_finish(p)
      call core_push_clip_rect(real(p%frame(1), real64), real(p%frame(2), real64), real(p%frame(3), real64), &
                               real(p%frame(4), real64))
      associate(t => ticks(1), r => p%rect, ax => p%ax(AX_X1)) ! x ticks, upwards from the axis
         do k = 1_int32, t%n
            if (t%pix(k) < r(1) .or. t%pix(k) > r(3)) cycle
            len_ = merge(MAJOR_TICK_LEN(1), MINOR_TICK_LEN(1), t%major(k))
            thk = merge(MAJOR_TICK_SIZE(1), MINOR_TICK_SIZE(1), t%major(k))
            call core_draw_line_v(real(t%pix(k), real64), real(ax%datum1, real64), &
                                  real(ax%datum1 + (-1.0_real32) * len_, real64), p%col_tick, real(thk, real64))
         enddo
         if (.not. border_shown(p)) call core_draw_line_h(real(r(1), real64), real(r(3), real64), &
                                                          real(ax%datum1, real64), p%col_tick,     &
                                                          real(MINOR_TICK_SIZE(1), real64))
      endassociate
      associate(t => ticks(2), r => p%rect, ax => p%ax(AX_Y1)) ! y ticks, rightwards from the axis
         do k = 1_int32, t%n
            if (t%pix(k) < r(2) .or. t%pix(k) > r(4)) cycle
            len_ = merge(MAJOR_TICK_LEN(2), MINOR_TICK_LEN(2), t%major(k))
            thk = merge(MAJOR_TICK_SIZE(2), MINOR_TICK_SIZE(2), t%major(k))
            call core_draw_line_h(real(ax%datum1, real64), real(ax%datum1 + 1.0_real32 * len_, real64), &
                                  real(t%pix(k), real64), p%col_tick, real(thk, real64))
         enddo
         if (.not. border_shown(p)) call core_draw_line_v(real(ax%datum1, real64), real(r(2), real64), &
                                                          real(r(4), real64), p%col_tick,              &
                                                          real(MINOR_TICK_SIZE(2), real64))
      endassociate
      call core_pop_clip_rect()
      if (border_shown(p)) call core_draw_rect(real(p%rect(1), real64), real(p%rect(2), real64),        &
                                               real(p%rect(3), real64), real(p%rect(4), real64), p%col_border, &
                                               rounding=0.0_real64, thickness=real(PLOT_BORDER_SIZE, real64))
      call core_draw_end()
      call fit_axes(p)
      p%initialized = .true.
   endassociate
   next_fit = .false. ! ResetCtxForNextPlot
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
   !< A slot made a new plot of the ID (field by field: the item tables kept allocated).
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
   enddo
   endsubroutine reset_plot

   function item_handle(p, id, frame, created) result(h)
   !< The item of an ID in a plot, added if new (`RegisterOrGetItem`): searched from where the last one was found
   !< (items come in the same order every frame), added in a new slot (the table grown, doubled up to ITEM_CAP) or in
   !< the slot of the least recently drawn item not drawn on this frame.
   type(plot_record), intent(inout) :: p       !< Plot.
   integer(int32),    intent(in)    :: id      !< ID.
   integer(int32),    intent(in)    :: frame   !< This frame.
   logical,           intent(out)   :: created !< The item is new.
   integer(int32)                   :: h       !< Handle.
   integer(int32)                   :: j, k, n !< Counters, items.

   created = .false.
   n = p%n_items
   k = p%item_next
   do j = 1_int32, n
      if (k > n) k = 1_int32
      if (p%item_id(k) == id) then
         h = k
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
   p%item_next = h + 1_int32
   endfunction item_handle

   subroutine grow_items(p, m)
   !< Room for m items in a plot's table, those held kept.
   type(plot_record), intent(inout) :: p                       !< Plot.
   integer(int32),    intent(in)    :: m                       !< Items room.
   integer(int32),    allocatable   :: id(:), color(:), frame(:) !< New columns.
   integer(int32)                   :: n                       !< Items held.

   n = p%n_items
   allocate(id(m), color(m), frame(m))
   if (n > 0_int32) then
      id(1:n) = p%item_id(1:n)
      color(1:n) = p%item_color(1:n)
      frame(1:n) = p%item_frame(1:n)
   endif
   call move_alloc(id, p%item_id)
   call move_alloc(color, p%item_color)
   call move_alloc(frame, p%item_frame)
   endsubroutine grow_items

   ! private: the axes

   subroutine setup_axis(p, i, flags)
   !< `SetupAxis`: the axis enabled on this frame, its flags taken if the plot is new or they changed.
   type(plot_record), intent(inout) :: p     !< Plot.
   integer(int32),    intent(in)    :: i     !< Axis.
   integer(int32),    intent(in)    :: flags !< ImPlotAxisFlags.

   if (p%just_created .or. flags /= p%ax(i)%prev_flags) p%ax(i)%flags = flags
   p%ax(i)%prev_flags = flags
   p%ax(i)%enabled = .true.
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
   !< `ImPlotAxis::Constrain` with the default constraints (any range, a size of at least DBL_MIN): NaN ends made 0,
   !< infinite ones the largest finite value, an empty range given DBL_EPSILON.
   type(plot_axis), intent(inout) :: ax       !< Axis.
   real(real64)                   :: z, delta !< Size, half the growth.

   ax%range_min = constrain_nan(constrain_inf(ax%range_min))
   ax%range_max = constrain_nan(constrain_inf(ax%range_max))
   z = ax%range_max - ax%range_min
   if (z < tiny(1.0_real64)) then
      delta = (tiny(1.0_real64) - z) * 0.5_real64
      ax%range_min = ax%range_min - delta
      ax%range_max = ax%range_max + delta
   endif
   if (ax%range_max <= ax%range_min) ax%range_max = ax%range_min + epsilon(1.0_real64)
   endsubroutine constrain

   subroutine update_scale(ax)
   !< `ImPlotAxis::UpdateTransformCache` of a linear axis: pixels per unit.
   type(plot_axis), intent(inout) :: ax !< Axis.

   ax%scale_to_pixel = real(ax%pixel_max - ax%pixel_min, real64) / (ax%range_max - ax%range_min)
   endsubroutine update_scale

   subroutine fit_points(xa, ya, x, y, n)
   !< `Fitter1` with `ExtendFitWith`: the points' finite coordinates extend the axes' fit ranges (with
   !< `ImPlotAxisFlags_RangeFit`, only those whose other coordinate is in the other axis's range).
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
      if (abs(x(k)) <= huge(1.0_real64)) then
         if (.not. rx .or. (y(k) >= ya%range_min .and. y(k) <= ya%range_max)) then
            if (x(k) < xa%fit_min) xa%fit_min = x(k)
            if (x(k) > xa%fit_max) xa%fit_max = x(k)
         endif
      endif
      if (abs(y(k)) <= huge(1.0_real64)) then
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

   subroutine fit_axes(p)
   !< `EndPlot`'s fit: the axes that fit on this frame and saw data (FIGURE's `fig_plot_end` drops the others), x axes
   !< then y axes; with `ImPlotFlags_Equal` the pair X1-Y1 then shares the larger units per pixel.
   type(plot_record), intent(inout) :: p      !< Plot.
   real(real64)                     :: aspect !< Units per pixel.
   integer(int32)                   :: i      !< Axis.
   logical                          :: equal  !< ImPlotFlags_Equal.

   if (.not. p%fit) return
   do i = 1_int32, AXES
      if (p%ax(i)%fit .and. p%ax(i)%fit_min > p%ax(i)%fit_max) p%ax(i)%fit = .false.
   enddo
   equal = iand(p%flags, PF_EQUAL) == PF_EQUAL
   do i = AX_X1, AX_X3
      if (.not. p%ax(i)%fit) cycle
      call apply_fit(p%ax(i), FIT_PADDING(1))
      if (equal .and. i == AX_X1) then ! OrthoAxis: Y1
         aspect = get_aspect(p%ax(AX_X1))
         if (p%ax(AX_Y1)%fit) then
            call apply_fit(p%ax(AX_Y1), FIT_PADDING(2))
            p%ax(AX_Y1)%fit = .false.
            aspect = merge(aspect, get_aspect(p%ax(AX_Y1)), aspect >= get_aspect(p%ax(AX_Y1)))
         endif
         call set_aspect(p%ax(AX_X1), aspect)
         call set_aspect(p%ax(AX_Y1), aspect)
      endif
   enddo
   do i = AX_Y1, AX_Y3
      if (.not. p%ax(i)%fit) cycle
      call apply_fit(p%ax(i), FIT_PADDING(2))
      if (equal .and. i == AX_Y1) then ! OrthoAxis: X1
         aspect = get_aspect(p%ax(AX_Y1))
         if (p%ax(AX_X1)%fit) then
            call apply_fit(p%ax(AX_X1), FIT_PADDING(1))
            p%ax(AX_X1)%fit = .false.
            aspect = merge(get_aspect(p%ax(AX_X1)), aspect, get_aspect(p%ax(AX_X1)) >= aspect)
         endif
         call set_aspect(p%ax(AX_X1), aspect)
         call set_aspect(p%ax(AX_Y1), aspect)
      endif
   enddo
   p%fit = .false.
   endsubroutine fit_axes

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

   function axis_code(axis) result(i)
   !< The axis of a name ('x1' X1, 'y1' Y1; the others are not drawn yet).
   character(len=*), intent(in) :: axis !< Name.
   integer(int32)               :: i    !< Axis.

   select case (axis)
   case ('x1')
      i = AX_X1
   case ('y1')
      i = AX_Y1
   case default
      i = 0_int32
      error stop "figure_plot_frame: an axis other than 'x1' and 'y1' (not drawn yet)"
   endselect
   endfunction axis_code

   pure function label_shown(label) result(yes)
   !< A label has text to show (`FindRenderedTextEnd(label) != label`: not empty, not starting with '##').
   character(len=*), intent(in) :: label !< Label.
   logical                      :: yes   !< Shown.

   yes = len(label) > 0
   if (len(label) >= 2) yes = label(1:2) /= '##'
   endfunction label_shown

   ! private: the drawing

   subroutine setup_finish(p)
   !< `SetupFinish`: the axes' initial fit decided, the layout (ticks, paddings, the plot rectangle), the axes on
   !< screen (and made equal), the fits asked for, then the frame, the plot's background, the grid and the tick labels.
   type(plot_record), intent(inout) :: p          !< Plot.
   real(real32)   :: t                    !< Text line height [pixels].
   real(real32)   :: pad_top, pad_bot     !< Paddings above and below the plot [pixels].
   real(real32)   :: pad_left, pad_right  !< ... left and right of it.
   real(real32)   :: plot_height, plot_width !< The plot's size.
   real(real32)   :: rounding, border     !< FrameRounding, FrameBorderSize.
   real(real64)   :: v(2)                 !< A style variable.
   real(real64)   :: xar, yar             !< Units per pixel on x, y.
   integer(int32) :: nv                   !< Its values.
   integer(int32) :: i                    !< Axis.

   p%locked = .true.
   do i = 1_int32, AXES ! finalize the axes: an axis with no limits fits on the plot's first frame (CanInitFit)
      if (.not. p%ax(i)%enabled) cycle
      call constrain(p%ax(i))
      if (.not. p%initialized .and. iand(p%ax(i)%flags, AXF_NO_INITIAL_FIT) == 0_int32 .and. &
          .not. p%ax(i)%has_range) then
         p%fit = .true.
         p%ax(i)%fit = .true.
      endif
   enddo
   p%col_maj = core_style_color(ImGuiCol_Text, 0.25_real64)                 ! AxisGrid: Text * (1, 1, 1, 0.25)
   p%col_min = core_style_color(ImGuiCol_Text, real(0.25_real32 * MINOR_ALPHA, real64))
   p%col_tick = p%col_maj                                                   ! AxisTick: AxisGrid
   p%col_txt = core_style_color(ImGuiCol_Text)                              ! AxisText: Text
   p%col_border = core_style_color(ImGuiCol_Border)                         ! PlotBorder: Border
   t = real(core_font_size(), real32)
   ticks(1)%n = 0_int32
   ticks(1)%max_size = 0.0_real32
   ticks(2)%n = 0_int32
   ticks(2)%max_size = 0.0_real32
   p%canvas(1:2) = p%frame(1:2) + PLOT_PADDING
   p%canvas(3:4) = p%frame(3:4) - PLOT_PADDING
   ! (1) the x axis below the plot, its labels' height not known yet; (2) the y ticks; (3) the y axis left of the plot
   pad_top = 0.0_real32
   pad_bot = 0.0_real32 + ((max(t, ticks(1)%max_size(2)) + LABEL_PADDING(2)) + 0.0_real32)
   p%ax(AX_X1)%datum1 = p%canvas(4) - pad_bot
   plot_height = ((p%canvas(4) - p%canvas(2)) - pad_top) - pad_bot
   if (plot_height > 0.0_real32) call locate(ticks(2), p%ax(AX_Y1)%range_min, p%ax(AX_Y1)%range_max, plot_height, &
                                             .true.)
   pad_left = 0.0_real32 + (ticks(2)%max_size(1) + LABEL_PADDING(1))
   pad_right = 0.0_real32
   p%ax(AX_Y1)%datum1 = p%canvas(1) + pad_left
   plot_width = ((p%canvas(3) - p%canvas(1)) - pad_left) - pad_right
   ! (4) the x ticks; (4.5) the x axis again, its labels' height known; (5) the plot rectangle
   if (plot_width > 0.0_real32) call locate(ticks(1), p%ax(AX_X1)%range_min, p%ax(AX_X1)%range_max, plot_width, &
                                            .false.)
   pad_top = 0.0_real32
   pad_bot = 0.0_real32 + ((max(t, ticks(1)%max_size(2)) + LABEL_PADDING(2)) + 0.0_real32)
   p%ax(AX_X1)%datum1 = p%canvas(4) - pad_bot
   p%rect = [p%canvas(1) + pad_left, p%canvas(2) + pad_top, p%canvas(3) - pad_right, p%canvas(4) - pad_bot]
   p%ax(AX_X1)%pixel_min = p%rect(1)
   p%ax(AX_X1)%pixel_max = p%rect(3)
   call update_scale(p%ax(AX_X1))
   p%ax(AX_Y1)%pixel_min = p%rect(4)
   p%ax(AX_Y1)%pixel_max = p%rect(2)
   call update_scale(p%ax(AX_Y1))
   if (iand(p%flags, PF_EQUAL) == PF_EQUAL) then ! x constrained to y, unless x's limits were set on this frame
      xar = get_aspect(p%ax(AX_X1))
      yar = get_aspect(p%ax(AX_Y1))
      if (p%ax(AX_X1)%has_range) then
         call set_aspect(p%ax(AX_Y1), xar)
      elseif (.not. almost_equal(xar, yar) .and. .not. ((locked_min(p%ax(AX_Y1)) .and. locked_max(p%ax(AX_Y1))) &
                                                        .or. auto_fitting(p%ax(AX_Y1)))) then
         call set_aspect(p%ax(AX_X1), yar)
      endif
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
   call place_ticks(ticks(1), p%ax(AX_X1))
   call place_ticks(ticks(2), p%ax(AX_Y1))
   call grid(p, ticks(1), .false.)
   call grid(p, ticks(2), .true.)
   call tick_labels(p)
   endsubroutine setup_finish

   subroutine place_ticks(t, ax)
   !< The ticks' pixels, rounded (`IM_ROUND(PlotToPixels)`).
   type(tick_list), intent(inout) :: t  !< Ticks.
   type(plot_axis), intent(in)    :: ax !< Their axis.
   integer(int32)                 :: k  !< Counter.

   do k = 1_int32, t%n
      t%pix(k) = real(int(to_pixels(ax, t%pos(k)) + 0.5_real32, int32), real32)
   enddo
   endsubroutine place_ticks

   subroutine grid(p, t, vertical)
   !< The grid lines of an axis's ticks (`RenderGridLinesX`, `RenderGridLinesY`): the majors', and the minors' while
   !< the ticks are fewer than one per 5 pixels, faded out from one per 10.
   type(plot_record), intent(in) :: p        !< Plot.
   type(tick_list),   intent(in) :: t        !< Ticks.
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

   subroutine tick_labels(p)
   !< The tick labels: the x axis's centred below its ticks, the y axis's right-aligned left of the plot.
   type(plot_record), intent(in) :: p      !< Plot.
   real(real32)                  :: px, py !< A label's top-left corner [pixels].
   real(real32)                  :: pad    !< Its distance from the axis.
   integer(int32)                :: k      !< Counter.

   associate(t => ticks(1), r => p%rect)
      do k = 1_int32, t%n
         if (.not. t%show(k) .or. t%pix(k) < r(1) - 1.0_real32 .or. t%pix(k) > r(3) + 1.0_real32) cycle
         pad = LABEL_PADDING(2) ! level 0, below the axis
         px = t%pix(k) - 0.5_real32 * t%label_size(1, k)
         py = p%ax(AX_X1)%datum1 + pad * 1.0_real32
         call core_draw_text(real(px, real64), real(py, real64), p%col_txt, trim(t%label(k)))
      enddo
   endassociate
   associate(t => ticks(2), r => p%rect)
      do k = 1_int32, t%n
         if (.not. t%show(k) .or. t%pix(k) < r(2) - 1.0_real32 .or. t%pix(k) > r(4) + 1.0_real32) cycle
         pad = LABEL_PADDING(1) + t%label_size(1, k)
         px = p%ax(AX_Y1)%datum1 + pad * (-1.0_real32)
         py = t%pix(k) - 0.5_real32 * t%label_size(2, k)
         call core_draw_text(real(px, real64), real(py, real64), p%col_txt, trim(t%label(k)))
      enddo
   endassociate
   endsubroutine tick_labels

   subroutine locate(t, rmin, rmax, pixels, vertical)
   !< `Locator_Default`: the ticks of a linear range on an axis `pixels` long.
   type(tick_list), intent(inout) :: t          !< Ticks (appended).
   real(real64),    intent(in)    :: rmin, rmax !< Range.
   real(real32),    intent(in)    :: pixels     !< Axis's length [pixels].
   logical,         intent(in)    :: vertical   !< A y axis.
   integer(int32)                 :: n_major    !< Majors wanted.
   real(real64)                   :: nice_range, interval, magnitude, min_interval !< The step.
   real(real64)                   :: graphmin, graphmax !< The majors' span.
   real(real64)                   :: major, minor !< Tick values.
   real(real32)                   :: total(2)   !< Labels' total size [pixels].
   integer(int32)                 :: first      !< The first major's tick (0: none).
   integer(int32)                 :: idx0       !< Ticks before.
   integer(int32)                 :: i          !< Counter.

   if (rmin == rmax) return
   n_major = max(2_int32, int(real(int(pixels / merge(300.0_real32, 400.0_real32, vertical) + 0.5_real32, int32), &
                                  real32), int32))
   nice_range = nice_num((rmax - rmin) * 0.99_real64, .false.)
   interval = nice_num(nice_range / real(n_major - 1_int32, real64), .true.)
   magnitude = max(abs(rmin), abs(rmax))
   min_interval = nearest(magnitude, 1.0_real64) - magnitude
   if (interval < min_interval) interval = min_interval
   graphmin = c_floor(rmin / interval) * interval
   graphmax = c_ceil(rmax / interval) * interval
   first = 0_int32
   idx0 = t%n
   total = 0.0_real32
   major = graphmin
   do while (major < graphmax + 0.5_real64 * interval)
      if (major - interval < 0.0_real64 .and. major + interval > 0.0_real64) major = 0.0_real64
      if (major >= rmin .and. major <= rmax) then
         if (first == 0_int32) first = t%n + 1_int32
         call add_tick(t, major, .true., total)
      endif
      do i = 1_int32, N_MINOR - 1_int32
         minor = major + real(i, real64) * interval / real(N_MINOR, real64)
         if (minor >= rmin .and. minor <= rmax) call add_tick(t, minor, .false., total)
      enddo
      major = major + interval
   enddo
   if ((.not. vertical .and. total(1) > pixels * TICK_FILL_X) .or. &
       (vertical .and. total(2) > pixels * TICK_FILL_Y)) then
      if (first == 0_int32) first = 1_int32 ! ImPlot's first_major_idx left 0: the first tick
      do i = first - 1_int32, idx0 + 1_int32, -2_int32
         t%show(i) = .false.
      enddo
      do i = first + 1_int32, t%n, 2_int32
         t%show(i) = .false.
      enddo
   endif
   endsubroutine locate

   subroutine add_tick(t, v, major, total)
   !< `ImPlotTicker::AddTick` with `Formatter_Default` (`%g`): a labelled tick, its label's size added to `total`.
   type(tick_list), intent(inout) :: t        !< Ticks.
   real(real64),    intent(in)    :: v        !< Value.
   logical,         intent(in)    :: major    !< A major tick.
   real(real32),    intent(inout) :: total(2) !< Labels' total size [pixels].
   real(real64)                   :: w, h     !< Label's size.
   integer(int32)                 :: k        !< The tick.

   if (.not. allocated(t%pos)) call grow(t, 64_int32)
   if (t%n == size(t%pos, kind=int32)) call grow(t, 2_int32 * t%n)
   k = t%n + 1_int32
   t%n = k
   t%pos(k) = v
   t%pix(k) = 0.0_real32
   t%major(k) = major
   t%show(k) = .true.
   t%label(k) = c_real('', 0_int32, -1_int32, 'g', v)
   call core_text_size(trim(t%label(k)), w, h)
   t%label_size(:, k) = [real(w, real32), real(h, real32)]
   t%max_size(1) = merge(t%label_size(1, k), t%max_size(1), t%label_size(1, k) > t%max_size(1))
   t%max_size(2) = merge(t%label_size(2, k), t%max_size(2), t%label_size(2, k) > t%max_size(2))
   total = total + t%label_size(:, k)
   endsubroutine add_tick

   subroutine grow(t, m)
   !< Room for m ticks, those held kept.
   type(tick_list), intent(inout)        :: t   !< Ticks.
   integer(int32),  intent(in)           :: m   !< Ticks room.
   real(real64),             allocatable :: pos(:)          !< New storage.
   real(real32),             allocatable :: pix(:), ls(:,:) !< ...
   logical,                  allocatable :: major(:), show(:) !< ...
   character(len=LABEL_LEN), allocatable :: label(:)        !< ...
   integer(int32)                        :: n   !< Ticks held.

   n = t%n
   allocate(pos(m), pix(m), ls(2, m), major(m), show(m), label(m))
   if (n > 0_int32) then
      pos(1:n) = t%pos(1:n)
      pix(1:n) = t%pix(1:n)
      ls(:, 1:n) = t%label_size(:, 1:n)
      major(1:n) = t%major(1:n)
      show(1:n) = t%show(1:n)
      label(1:n) = t%label(1:n)
   endif
   call move_alloc(pos, t%pos)
   call move_alloc(pix, t%pix)
   call move_alloc(ls, t%label_size)
   call move_alloc(major, t%major)
   call move_alloc(show, t%show)
   call move_alloc(label, t%label)
   endsubroutine grow

   pure function nice_num(x, round) result(nice)
   !< `NiceNum`: a nice number (1, 2, 5 or 10 times a power of ten) near x, rounded or not below it.
   real(real64), intent(in) :: x     !< Value (> 0).
   logical,      intent(in) :: round !< Round (else the nice number at least x).
   real(real64)             :: nice  !< Nice number.
   real(real64)             :: f, nf !< Fraction, nice fraction.
   integer(int32)           :: e     !< Exponent.

   e = int(c_floor(log10(x)), int32)
   f = x / pow10(e)
   if (round) then
      if (f < 1.5_real64) then
         nf = 1.0_real64
      elseif (f < 3.0_real64) then
         nf = 2.0_real64
      elseif (f < 7.0_real64) then
         nf = 5.0_real64
      else
         nf = 10.0_real64
      endif
   elseif (f <= 1.0_real64) then
      nf = 1.0_real64
   elseif (f <= 2.0_real64) then
      nf = 2.0_real64
   elseif (f <= 5.0_real64) then
      nf = 5.0_real64
   else
      nf = 10.0_real64
   endif
   nice = nf * pow10(e)
   endfunction nice_num

   pure function pow10(e) result(p)
   !< 10**e as C's correctly rounded `pow(10.0, e)`: exact up to 10**22, its reciprocal one rounding below 1.
   integer(int32), intent(in) :: e !< Exponent.
   real(real64)               :: p !< Power.
   integer(int32)             :: k !< Counter.

   if (abs(e) > 22_int32) then
      p = 10.0_real64**real(e, real64)
      return
   endif
   p = 1.0_real64
   do k = 1_int32, abs(e)
      p = p * 10.0_real64
   enddo
   if (e < 0_int32) p = 1.0_real64 / p
   endfunction pow10

   pure function c_floor(x) result(f)
   !< C's `floor` of a real, as a real (no integer overflow).
   real(real64), intent(in) :: x !< Value.
   real(real64)             :: f !< Floor.

   f = aint(x)
   if (f > x) f = f - 1.0_real64
   endfunction c_floor

   pure function c_ceil(x) result(f)
   !< C's `ceil` of a real, as a real.
   real(real64), intent(in) :: x !< Value.
   real(real64)             :: f !< Ceiling.

   f = aint(x)
   if (f < x) f = f + 1.0_real64
   endfunction c_ceil

   pure function to_pixels(ax, v) result(px)
   !< `PlotToPixels` of a linear axis: the pixel of a value, in single precision.
   type(plot_axis), intent(in) :: ax !< Axis.
   real(real64),    intent(in) :: v  !< Value.
   real(real32)                :: px !< Pixel.

   px = real(real(ax%pixel_min, real64) + ax%scale_to_pixel * (v - ax%range_min), real32)
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
