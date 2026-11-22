!< figure_plot_frame, the Fortran path's plot frame: a plot's layout, axes, ticks, grid and lines, as ImPlot draws them.
module figure_plot_frame
!< figure_plot_frame, the Fortran path's plot frame: a plot's layout, axes, ticks, grid and lines, as ImPlot draws them.
!<
!< szaghi/figure#15 P10, its first skeleton. A plot drawn through figure_core only (no ImPlot, no figure_cimplot), to
!< the pixels ImPlot 1.2 WIP (FIGURE's copy) draws for the same plot: `pf_begin_plot`, `pf_setup_axes_limits`,
!< `pf_line`, `pf_end_plot` draw what `ip_begin_plot`, `ip_setup_axes_limits(..., always=.true.)`, `ip_line`,
!< `ip_end_plot` draw for a plot of two linear axes (X1, Y1) with explicit limits, no title, no axis labels, no legend,
!< one or more lines of the default style, the pointer away from the plot. Reproduced from implot.cpp and
!< implot_items.cpp, their arithmetic kept (single precision where ImPlot's is `float`, double where it is `double`):
!<
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
!<   weight (at least 1 pixel) plus half the texture's fringe on each side, the segments outside the plot culled; its
!<   colour given, or the plot's n-th item's automatic one, the colormap Deep's n-th colour.
!<
!< Not yet (P10's rest, P11, P12): auto-fit, other scales, pan, zoom and selection, hovering, legends, titles, axis
!< labels, more axes, colormaps other than Deep (the line colours of FIGURE's own styles: seal, paper, ...), ImPlot
!< style variables set by a theme. One plot at a time; its state
!< is the module's. The segment's normal is `1/sqrt` where ImPlot takes the SSE estimate `_mm_rsqrt_ss` (12 bits): the
!< line's vertices may differ from ImPlot's below a thousandth of a pixel.
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use figure_cimgui_enums, only : ImGuiCol_Border, ImGuiCol_BorderShadow, ImGuiCol_FrameBg, ImGuiCol_Text, &
                                ImGuiCol_WindowBg
use figure_core, only : core_color, core_content_region_avail, core_cursor_screen_pos, core_draw_begin, core_draw_end, &
                        core_draw_line_h, core_draw_line_v, core_draw_quad_uv, core_draw_rect, core_draw_rect_filled,  &
                        core_draw_text, core_font_size, core_get_id, core_item_add, core_item_size, core_line_texture, &
                        core_pop_clip_rect, core_push_clip_rect, core_style_color, core_style_var, core_text_size
use foresight_format, only : c_real

implicit none
private
public :: pf_begin_plot, pf_setup_axes_limits, pf_line, pf_end_plot

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
real(real32), parameter :: LINE_WEIGHT = 1.0_real32                            !< ImPlotSpec's LineWeight [pixels].
! Locator_Default
real(real32),   parameter :: TICK_FILL_X = 0.8_real32 !< Labels may fill this much of an x axis.
real(real32),   parameter :: TICK_FILL_Y = 1.0_real32 !< ... of a y axis.
integer(int32), parameter :: N_MINOR = 10_int32       !< Minor intervals per major.
integer(int32), parameter :: LABEL_LEN = 32_int32     !< IMPLOT_LABEL_MAX_SIZE.
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
   !< A linear axis (ImPlotAxis).
   real(real64)    :: range_min = 0.0_real64      !< Range's minimum.
   real(real64)    :: range_max = 1.0_real64      !< ... maximum.
   real(real32)    :: pixel_min = 0.0_real32      !< The range's minimum on screen [pixels].
   real(real32)    :: pixel_max = 0.0_real32      !< ... its maximum.
   real(real64)    :: scale_to_pixel = 0.0_real64 !< Pixels per unit.
   real(real32)    :: datum1 = 0.0_real32         !< Where the axis's ticks start [pixels].
   type(tick_list) :: ticks                       !< Ticks.
endtype plot_axis

type :: plot_state
   !< The plot being drawn.
   logical         :: open = .false.          !< Between `pf_begin_plot` (true) and `pf_end_plot`.
   logical         :: locked = .false.        !< Setup finished (layout done, frame drawn).
   real(real32)    :: frame(4) = 0.0_real32   !< Frame rectangle: x min, y min, x max, y max [pixels].
   real(real32)    :: canvas(4) = 0.0_real32  !< Canvas: the frame less the padding.
   real(real32)    :: rect(4) = 0.0_real32    !< Plot rectangle.
   integer(int32)  :: items = 0_int32         !< Items drawn.
   integer(int32)  :: col_maj = 0_int32       !< Major grid lines' colour.
   integer(int32)  :: col_min = 0_int32       !< Minor grid lines' colour.
   integer(int32)  :: col_tick = 0_int32      !< Tick marks' colour.
   integer(int32)  :: col_txt = 0_int32       !< Tick labels' colour.
   integer(int32)  :: col_border = 0_int32    !< Border's colour.
   type(plot_axis) :: x                       !< X axis (X1).
   type(plot_axis) :: y                       !< Y axis (Y1).
endtype plot_state

type(plot_state), target :: plot !< The plot (one at a time).

contains
   function pf_begin_plot(title, width, height) result(visible)
   !< Begin a plot (`BeginPlot`): its frame placed at the cursor, `width` x `height` pixels (default: the full width,
   !< ImPlot's default height; a negative size is the room left less it); when true, declare its content and call
   !< `pf_end_plot`.
   character(len=*), intent(in)           :: title   !< Title (also the plot's ID; '##id' hides it).
   real(real64),     intent(in), optional :: width   !< Width [pixels].
   real(real64),     intent(in), optional :: height  !< Height [pixels].
   logical                                :: visible !< Plot visible.
   real(real32)                           :: req(2)  !< Size asked.
   real(real32)                           :: ext(2)  !< Frame's size.
   real(real64)                           :: cx, cy  !< Cursor.
   real(real64)                           :: aw, ah  !< Room left.
   integer(int32)                         :: id      !< ID.

   visible = .false.
   if (plot%open) error stop 'figure_plot_frame: pf_begin_plot while a plot is open'
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
   plot%frame(1:2) = [real(cx, real32), real(cy, real32)]
   plot%frame(3:4) = plot%frame(1:2) + ext
   id = core_get_id(title)
   call core_item_size(real(plot%frame(3) - plot%frame(1), real64), real(plot%frame(4) - plot%frame(2), real64))
   if (.not. core_item_add(real(plot%frame(1), real64), real(plot%frame(2), real64), real(plot%frame(3), real64), &
                           real(plot%frame(4), real64), id)) return
   plot%open = .true.
   plot%locked = .false.
   plot%items = 0_int32
   visible = .true.
   endfunction pf_begin_plot

   subroutine pf_setup_axes_limits(xmin, xmax, ymin, ymax)
   !< The ranges of the axes (`SetupAxesLimits`, `ImPlotCond_Always`): call after `pf_begin_plot`, before any item.
   real(real64), intent(in) :: xmin, xmax !< X axis's range.
   real(real64), intent(in) :: ymin, ymax !< Y axis's range.

   if (.not. plot%open .or. plot%locked) error stop 'figure_plot_frame: pf_setup_axes_limits outside a plot setup'
   plot%x%range_min = xmin
   plot%x%range_max = xmax
   plot%y%range_min = ymin
   plot%y%range_max = ymax
   endsubroutine pf_setup_axes_limits

   subroutine pf_line(label, x, y, color)
   !< A line through the points (x(i), y(i)) (`PlotLine` of weight 1), clipped to the plot, of the colour `color`
   !< (`ip_spec(line_color=...)`), else of the plot's next automatic colour (ImPlot's colormap Deep: the styles
   !< `'dark'`, `'light'`, `'classic'`). The label is not shown yet (no legend).
   character(len=*), intent(in)           :: label    !< Legend label.
   real(real64),     intent(in)           :: x(:)     !< Abscissae.
   real(real64),     intent(in)           :: y(:)     !< Ordinates.
   real(real64),     intent(in), optional :: color(4) !< Colour, RGBA in [0, 1].
   integer(int32)               :: col     !< Colour.
   real(real32)                 :: hw      !< Half the weight [pixels].
   real(real64)                 :: uv0(2), uv1(2), fringe !< The line's texture.
   real(real32)                 :: p1(2), p2(2) !< A segment's ends [pixels].
   real(real32)                 :: dx, dy, d2, inv !< Its direction.
   integer(int32)               :: k, n    !< Counter, points.

   if (.not. plot%open) error stop 'figure_plot_frame: pf_line outside a plot'
   if (.not. plot%locked) call setup_finish()
   if (present(color)) then
      col = core_color(color(1), color(2), color(3), color(4))
   else
      col = rgb_u32(DEEP(:, modulo(plot%items, 10_int32) + 1_int32)) ! NextColormapColorU32
   endif
   plot%items = plot%items + 1_int32
   n = int(min(size(x), size(y)), int32)
   if (n < 2_int32) return
   call core_push_clip_rect(real(plot%rect(1), real64), real(plot%rect(2), real64), real(plot%rect(3), real64), &
                            real(plot%rect(4), real64))
   hw = max(1.0_real32, LINE_WEIGHT) * 0.5_real32 ! RendererLineStrip, GetLineRenderProps
   call core_line_texture(real(hw * 2.0_real32, real64), uv0, uv1, fringe)
   hw = hw + real(fringe, real32) * 0.5_real32
   p1 = [to_pixels(plot%x, x(1)), to_pixels(plot%y, y(1))]
   do k = 2_int32, n
      p2 = [to_pixels(plot%x, x(k)), to_pixels(plot%y, y(k))]
      if (min(p1(2), p2(2)) < plot%rect(4) .and. max(p1(2), p2(2)) > plot%rect(2) .and. &
          min(p1(1), p2(1)) < plot%rect(3) .and. max(p1(1), p2(1)) > plot%rect(1)) then ! PrimLine
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
   endsubroutine pf_line

   subroutine pf_end_plot()
   !< End the plot (`EndPlot`): the tick marks and the border.
   real(real32)   :: len_, thk !< A tick's length and thickness.
   integer(int32) :: k         !< Counter.

   if (.not. plot%open) error stop 'figure_plot_frame: pf_end_plot without a plot'
   if (.not. plot%locked) call setup_finish()
   call core_push_clip_rect(real(plot%frame(1), real64), real(plot%frame(2), real64), real(plot%frame(3), real64), &
                            real(plot%frame(4), real64))
   associate(t => plot%x%ticks, r => plot%rect) ! x ticks, upwards from the axis
      do k = 1_int32, t%n
         if (t%pix(k) < r(1) .or. t%pix(k) > r(3)) cycle
         len_ = merge(MAJOR_TICK_LEN(1), MINOR_TICK_LEN(1), t%major(k))
         thk = merge(MAJOR_TICK_SIZE(1), MINOR_TICK_SIZE(1), t%major(k))
         call core_draw_line_v(real(t%pix(k), real64), real(plot%x%datum1, real64), &
                               real(plot%x%datum1 + (-1.0_real32) * len_, real64), plot%col_tick, real(thk, real64))
      enddo
      if (.not. border_shown()) call core_draw_line_h(real(r(1), real64), real(r(3), real64), &
                                                      real(plot%x%datum1, real64), plot%col_tick,  &
                                                      real(MINOR_TICK_SIZE(1), real64))
   endassociate
   associate(t => plot%y%ticks, r => plot%rect) ! y ticks, rightwards from the axis
      do k = 1_int32, t%n
         if (t%pix(k) < r(2) .or. t%pix(k) > r(4)) cycle
         len_ = merge(MAJOR_TICK_LEN(2), MINOR_TICK_LEN(2), t%major(k))
         thk = merge(MAJOR_TICK_SIZE(2), MINOR_TICK_SIZE(2), t%major(k))
         call core_draw_line_h(real(plot%y%datum1, real64), real(plot%y%datum1 + 1.0_real32 * len_, real64), &
                               real(t%pix(k), real64), plot%col_tick, real(thk, real64))
      enddo
      if (.not. border_shown()) call core_draw_line_v(real(plot%y%datum1, real64), real(r(2), real64), &
                                                      real(r(4), real64), plot%col_tick, &
                                                      real(MINOR_TICK_SIZE(2), real64))
   endassociate
   call core_pop_clip_rect()
   if (border_shown()) call core_draw_rect(real(plot%rect(1), real64), real(plot%rect(2), real64), &
                                           real(plot%rect(3), real64), real(plot%rect(4), real64), plot%col_border, &
                                           rounding=0.0_real64, thickness=real(PLOT_BORDER_SIZE, real64))
   call core_draw_end()
   plot%open = .false.
   endsubroutine pf_end_plot

   ! private

   subroutine setup_finish()
   !< `SetupFinish`: the layout (ticks, paddings, the plot rectangle), then the frame, the plot's background, the grid
   !< and the tick labels.
   real(real32)   :: t                    !< Text line height [pixels].
   real(real32)   :: pad_top, pad_bot     !< Paddings above and below the plot [pixels].
   real(real32)   :: pad_left, pad_right  !< ... left and right of it.
   real(real32)   :: plot_height, plot_width !< The plot's size.
   real(real32)   :: rounding, border     !< FrameRounding, FrameBorderSize.
   real(real64)   :: v(2)                 !< A style variable.
   integer(int32) :: nv                   !< Its values.

   plot%locked = .true.
   plot%col_maj = core_style_color(ImGuiCol_Text, 0.25_real64)                 ! AxisGrid: Text * (1, 1, 1, 0.25)
   plot%col_min = core_style_color(ImGuiCol_Text, real(0.25_real32 * MINOR_ALPHA, real64))
   plot%col_tick = plot%col_maj                                                ! AxisTick: AxisGrid
   plot%col_txt = core_style_color(ImGuiCol_Text)                              ! AxisText: Text
   plot%col_border = core_style_color(ImGuiCol_Border)                         ! PlotBorder: Border
   t = real(core_font_size(), real32)
   plot%x%ticks%n = 0_int32
   plot%x%ticks%max_size = 0.0_real32
   plot%y%ticks%n = 0_int32
   plot%y%ticks%max_size = 0.0_real32
   plot%canvas(1:2) = plot%frame(1:2) + PLOT_PADDING
   plot%canvas(3:4) = plot%frame(3:4) - PLOT_PADDING
   ! (1) the x axis below the plot, its labels' height not known yet; (2) the y ticks; (3) the y axis left of the plot
   pad_top = 0.0_real32
   pad_bot = 0.0_real32 + ((max(t, plot%x%ticks%max_size(2)) + LABEL_PADDING(2)) + 0.0_real32)
   plot%x%datum1 = plot%canvas(4) - pad_bot
   plot_height = ((plot%canvas(4) - plot%canvas(2)) - pad_top) - pad_bot
   if (plot_height > 0.0_real32) call locate(plot%y%ticks, plot%y%range_min, plot%y%range_max, plot_height, .true.)
   pad_left = 0.0_real32 + (plot%y%ticks%max_size(1) + LABEL_PADDING(1))
   pad_right = 0.0_real32
   plot%y%datum1 = plot%canvas(1) + pad_left
   plot_width = ((plot%canvas(3) - plot%canvas(1)) - pad_left) - pad_right
   ! (4) the x ticks; (4.5) the x axis again, its labels' height known; (5) the plot rectangle
   if (plot_width > 0.0_real32) call locate(plot%x%ticks, plot%x%range_min, plot%x%range_max, plot_width, .false.)
   pad_top = 0.0_real32
   pad_bot = 0.0_real32 + ((max(t, plot%x%ticks%max_size(2)) + LABEL_PADDING(2)) + 0.0_real32)
   plot%x%datum1 = plot%canvas(4) - pad_bot
   plot%rect = [plot%canvas(1) + pad_left, plot%canvas(2) + pad_top, plot%canvas(3) - pad_right, &
                plot%canvas(4) - pad_bot]
   plot%x%pixel_min = plot%rect(1)
   plot%x%pixel_max = plot%rect(3)
   plot%y%pixel_min = plot%rect(4)
   plot%y%pixel_max = plot%rect(2)
   plot%x%scale_to_pixel = real(plot%x%pixel_max - plot%x%pixel_min, real64) / (plot%x%range_max - plot%x%range_min)
   plot%y%scale_to_pixel = real(plot%y%pixel_max - plot%y%pixel_min, real64) / (plot%y%range_max - plot%y%range_min)
   ! render: the frame, the plot's background
   call core_style_var('FrameRounding', v, nv)
   rounding = real(v(1), real32)
   call core_style_var('FrameBorderSize', v, nv)
   border = real(v(1), real32)
   call core_draw_begin()
   call core_draw_rect_filled(real(plot%frame(1), real64), real(plot%frame(2), real64), real(plot%frame(3), real64), &
                              real(plot%frame(4), real64), core_style_color(ImGuiCol_FrameBg), real(rounding, real64))
   if (border > 0.0_real32) then ! RenderFrame's border
      call core_draw_rect(real(plot%frame(1) + 1.0_real32, real64), real(plot%frame(2) + 1.0_real32, real64),    &
                          real(plot%frame(3) + 1.0_real32, real64), real(plot%frame(4) + 1.0_real32, real64),    &
                          core_style_color(ImGuiCol_BorderShadow), real(rounding, real64), real(border, real64))
      call core_draw_rect(real(plot%frame(1), real64), real(plot%frame(2), real64), real(plot%frame(3), real64), &
                          real(plot%frame(4), real64), core_style_color(ImGuiCol_Border), real(rounding, real64),   &
                          real(border, real64))
   endif
   call core_draw_rect_filled(real(plot%rect(1), real64), real(plot%rect(2), real64), real(plot%rect(3), real64), &
                              real(plot%rect(4), real64), core_style_color(ImGuiCol_WindowBg))
   call place_ticks(plot%x)
   call place_ticks(plot%y)
   call grid(plot%x%ticks, .false.)
   call grid(plot%y%ticks, .true.)
   call tick_labels()
   endsubroutine setup_finish

   subroutine place_ticks(ax)
   !< The ticks' pixels, rounded (`IM_ROUND(PlotToPixels)`).
   type(plot_axis), intent(inout) :: ax !< Axis.
   integer(int32)                 :: k  !< Counter.

   do k = 1_int32, ax%ticks%n
      ax%ticks%pix(k) = real(int(to_pixels(ax, ax%ticks%pos(k)) + 0.5_real32, int32), real32)
   enddo
   endsubroutine place_ticks

   subroutine grid(t, vertical)
   !< The grid lines of an axis's ticks (`RenderGridLinesX`, `RenderGridLinesY`): the majors', and the minors' while
   !< the ticks are fewer than one per 5 pixels, faded out from one per 10.
   type(tick_list), intent(in) :: t        !< Ticks.
   logical,         intent(in) :: vertical !< A y axis (horizontal lines).
   real(real32)                :: density  !< Ticks per pixel.
   real(real32)                :: a        !< The minors' alpha.
   integer(int32)              :: col_min  !< The minors' colour.
   integer(int32)              :: i        !< Axis: 1 x, 2 y.
   integer(int32)              :: k        !< Counter.
   real(real32), parameter     :: S = 1.0_real32 / 255.0_real32 !< ColorConvertU32ToFloat4's scale.

   i = merge(2_int32, 1_int32, vertical)
   density = real(t%n, real32) / (plot%rect(i + 2) - plot%rect(i))
   a = real(channel(plot%col_min, 3_int32), real32) * S
   a = a * min(max(1.0_real32 + ((density - 0.1_real32) * (0.0_real32 - 1.0_real32)) / (0.2_real32 - 0.1_real32), &
                   0.0_real32), 1.0_real32)
   col_min = with_alpha(plot%col_min, int(min(max(a, 0.0_real32), 1.0_real32) * 255.0_real32 + 0.5_real32, int32))
   do k = 1_int32, t%n
      if (t%pix(k) < plot%rect(i) .or. t%pix(k) > plot%rect(i + 2)) cycle
      if (t%major(k)) then
         call line(t%pix(k), plot%col_maj, merge(MAJOR_GRID_SIZE(2), MAJOR_GRID_SIZE(1), vertical))
      elseif (density < 0.2_real32) then
         call line(t%pix(k), col_min, merge(MINOR_GRID_SIZE(2), MINOR_GRID_SIZE(1), vertical))
      endif
   enddo
   contains
      subroutine line(p, col, thk)
      !< A grid line at the pixel p.
      real(real32),   intent(in) :: p   !< Pixel.
      integer(int32), intent(in) :: col !< Colour.
      real(real32),   intent(in) :: thk !< Thickness [pixels].

      if (vertical) then
         call core_draw_line_h(real(plot%rect(1), real64), real(plot%rect(3), real64), real(p, real64), col, &
                               real(thk, real64))
      else
         call core_draw_line_v(real(p, real64), real(plot%rect(2), real64), real(plot%rect(4), real64), col, &
                               real(thk, real64))
      endif
      endsubroutine line
   endsubroutine grid

   subroutine tick_labels()
   !< The tick labels: the x axis's centred below its ticks, the y axis's right-aligned left of the plot.
   real(real32)   :: px, py !< A label's top-left corner [pixels].
   real(real32)   :: pad    !< Its distance from the axis.
   integer(int32) :: k      !< Counter.

   associate(t => plot%x%ticks, r => plot%rect)
      do k = 1_int32, t%n
         if (.not. t%show(k) .or. t%pix(k) < r(1) - 1.0_real32 .or. t%pix(k) > r(3) + 1.0_real32) cycle
         pad = LABEL_PADDING(2) ! level 0, below the axis
         px = t%pix(k) - 0.5_real32 * t%label_size(1, k)
         py = plot%x%datum1 + pad * 1.0_real32
         call core_draw_text(real(px, real64), real(py, real64), plot%col_txt, trim(t%label(k)))
      enddo
   endassociate
   associate(t => plot%y%ticks, r => plot%rect)
      do k = 1_int32, t%n
         if (.not. t%show(k) .or. t%pix(k) < r(2) - 1.0_real32 .or. t%pix(k) > r(4) + 1.0_real32) cycle
         pad = LABEL_PADDING(1) + t%label_size(1, k)
         px = plot%y%datum1 + pad * (-1.0_real32)
         py = t%pix(k) - 0.5_real32 * t%label_size(2, k)
         call core_draw_text(real(px, real64), real(py, real64), plot%col_txt, trim(t%label(k)))
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

   pure function to_pixels(ax, v) result(p)
   !< `PlotToPixels` of a linear axis: the pixel of a value, in single precision.
   type(plot_axis), intent(in) :: ax !< Axis.
   real(real64),    intent(in) :: v  !< Value.
   real(real32)                :: p  !< Pixel.

   p = real(real(ax%pixel_min, real64) + ax%scale_to_pixel * (v - ax%range_min), real32)
   endfunction to_pixels

   function border_shown() result(shown)
   !< The plot's border is drawn (`PlotBorderSize` > 0, the colour not transparent).
   logical :: shown !< Drawn.

   shown = PLOT_BORDER_SIZE > 0.0_real32 .and. channel(plot%col_border, 3_int32) > 0_int32
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
