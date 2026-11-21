!< figure_test_plot_view, a line plot at four zoom levels and a plot driven by the pointer (pan, zoom, box, drag line,
!< legend), each against a golden, headless.
program figure_test_plot_view
!< figure_test_plot_view, a line plot at four zoom levels and a plot driven by the pointer (pan, zoom, box, drag line,
!< legend), each against a golden, headless.
!<
!< 1. Zoom levels (#15 §4): a line of 200001 points (x from 0 to 1000, three triangle waves) in four plots, its x axis
!<    over 1000, 100, 5 and 0.5 units: about 600, 60, 3 and 0.3 points per pixel (the last three below the decimation's
!<    threshold, 64 per pixel); each plot's limits read back as set, and the four, every point drawn
!<    (`ip_set_decimation(.false.)`), against the golden src/tests/data/figure_test_plot_view.levels.golden.png
!<    (|d| <= 2). Then the same four decimated (#15 P4, the default): in the dense plot (600 per pixel) at most 64
!<    points a pixel column kept, in the three others every point in view (20001, 1001 and 101: at most 64 a column)
!<    and a few off the plot; the picture against the same golden at a loosened threshold (|d| <= 96): anti-aliased
!<    strokes of the points kept cover a dense column otherwise than the full series' many, up to 87 levels apart on
!<    2205 pixels of the dense plot (gfortran 16.2, 2026-11-20), the three others equal. The decimated line is cached
!<    (`ip_cache_next_item`, #15 P5): one cache for the four plots of the same arrays, built on the first frame.
!< 2. Interaction, in one plot whose style is pushed around it (a border of 3 pixels, a dark blue background) and with
!<    the minor grid's alpha set: a horizontal drag line dragged 40 pixels down moves by 40 pixels' worth of y; a left
!<    drag of (-100, +50) pixels pans the plot by that much (the ranges' widths kept); the wheel zooms in about the
!<    pointer (the plot point under it kept, the range narrower); a right-button box is read while held as the
!<    rectangle dragged (`ip_plot_selection`), and the release zooms to it; the pointer on the first legend entry
!<    hovers it, a click hides its item (its colour gone); then the plot against the golden
!<    src/tests/data/figure_test_plot_view.view.golden.png (|d| <= 2): the picture of what the pointer did.
!< 3. Style: inside the push the style reads the pushed values, after the pop the defaults again; the set alpha reads
!<    back; a pop with nothing pushed is refused.
!< The pictures are `figure_test_plot_view.*.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
! oracle: drag wheel plot-zoom-levels:picture plot-pan:picture plot-zoom:picture plot-box-select:picture
! oracle: plot-drag-tools:picture plot-legend:picture
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_same_line, ig_set_next_window, ip_begin_plot, &
                   ip_drag_line_y, ip_end_plot, ip_get_style_color, ip_get_style_var, ip_legend_hovered, ip_line,    &
                   ip_pixels_to_plot, ip_plot_limits, ip_plot_selection, ip_plot_to_pixels, ip_pop_style_color,     &
                   ip_pop_style_var, ip_set_decimation, ip_cache_next_item,                                          &
                   ip_push_style_color, ip_push_style_var, ip_set_style_var, ip_setup_axes_limits, ip_spec,         &
                   ImGuiWindowFlags_NoDecoration, FIG_ERR_STATE, FIG_OK
use figure_implot, only : plot_decimated, plot_kept
use figure_testing, only : test_capture, test_click, test_compare_image, test_drag, test_drawn_extent, &
                           test_mouse_button, test_mouse_move, test_next_frame, test_wheel

implicit none
character(len=*), parameter :: LEVELS_GOLDEN = 'src/tests/data/figure_test_plot_view.levels.golden.png' !< Zoom levels.
character(len=*), parameter :: VIEW_GOLDEN = 'src/tests/data/figure_test_plot_view.view.golden.png'     !< Interaction.
character(len=*), parameter :: LEVELS_SHOT = 'figure_test_plot_view.levels.png.tmp' !< The zoom levels' capture.
character(len=*), parameter :: VIEW_SHOT = 'figure_test_plot_view.view.png.tmp'     !< The interaction's capture.
integer(int32),   parameter :: W = 800_int32                     !< Display width [pixels].
integer(int32),   parameter :: H = 600_int32                     !< Display height [pixels].
integer(int64),   parameter :: N = 200001_int64                  !< Points of the line.
real(real64),     parameter :: XSPAN(4) = [1000.0_real64, 100.0_real64, 5.0_real64, 0.5_real64] !< The x ranges.
real(real64),     parameter :: SIGNAL_C(4) = [0.95_real64, 0.75_real64, 0.20_real64, 1.0_real64] !< The line's colour.
real(real64),     parameter :: FIRST_C(4) = [0.20_real64, 0.70_real64, 0.95_real64, 1.0_real64]  !< First item's.
real(real64),     parameter :: SECOND_C(4) = [0.95_real64, 0.35_real64, 0.45_real64, 1.0_real64] !< Second item's.
real(real64),     parameter :: DRAG_C(4) = [0.40_real64, 0.95_real64, 0.40_real64, 1.0_real64]   !< The drag line's.
real(real64),     parameter :: BG(4) = [30.0_real64, 42.0_real64, 56.0_real64, 255.0_real64] / 255.0_real64 !< The pushed
                                                                 !< background, '#1e2a38'.
real(real64),     parameter :: TOL8 = 0.5_real64 / 255.0_real64 + 1.0e-6_real64 !< ImPlot keeps 8-bit colours.
type(app_object)            :: app                               !< Application.
logical                     :: test_passed(14)                   !< Per-check outcome.
real(real64), allocatable   :: x(:), y(:)                        !< The long line.
real(real64)                :: xs(101), ys1(101), ys2(101)       !< The interaction plot's two items.
real(real64)                :: lim(4, 4)                         !< Zoom levels' limits read back.
real(real64)                :: yline                             !< The drag line.
logical                     :: line_moved                        !< ... reported a move.
real(real64)                :: view(4)                           !< Interaction plot's limits, this frame.
real(real64)                :: area(4)                           !< Its plot area: left, top, right, bottom [pixels].
real(real64)                :: under(2)                          !< The plot point under a pixel, this frame.
real(real64)                :: probe(2)                          !< The pixel `under` is read at.
real(real64)                :: px(2)                             !< A plot point's pixel, this frame.
real(real64)                :: px_of(2)                          !< ... of this plot point.
logical                     :: hovered                           !< The first legend entry is hovered, this frame.
logical                     :: first_drawn                       !< The first item's colour is drawn, this frame.
logical                     :: sel_seen                          !< A box selection was drawn, on some frame.
real(real64)                :: sel(4)                            !< ... its extent, on the last such frame.
real(real64)                :: style_in(3), style_out(3)         !< Border size, background's red: in, after the push.
real(real64)                :: minor                             !< The minor grid's alpha read back.
integer(int32)              :: pop_stat                          !< A pop with nothing pushed.
character(len=16)           :: keep                              !< FIGURE_TEST_KEEP.
integer(int64)              :: i                                 !< Counter.

allocate(x(N), y(N))
do i = 1_int64, N
   x(i) = real(i - 1_int64, real64) * 0.005_real64
enddo
y = tri(x / 50.0_real64) + 0.3_real64 * tri(x * 1.37_real64) + 0.08_real64 * tri(x * 23.0_real64)
do i = 1_int64, 101_int64
   xs(i) = real(i - 1_int64, real64) * 0.1_real64
enddo
ys1 = tri(xs / 2.5_real64) - 1.0_real64
ys2 = 0.5_real64 * tri(xs / 1.5_real64 + 0.5_real64)
yline = 1.0_real64
line_moved = .false.
px_of = 0.0_real64 ! read by every frame of the interaction plot before probe_point sets it
probe = 0.0_real64

call app%init_headless(W, H)
call ip_set_style_var('MinorAlpha', 0.5_real64)
call ip_set_decimation(.false.)
call levels(test_passed(1:2), .false.)
call ip_set_decimation(.true.)
call levels(test_passed(13:14), .true.)
call interaction(test_passed(3:9))
call styles(test_passed(10:12))
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_view checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   elemental function tri(t) result(v)
   !< A triangle wave of period 2 between -1 and 1 (exact arithmetic: the same points on every platform).
   real(real64), intent(in) :: t !< Argument.
   real(real64)             :: v !< Value.

   v = 1.0_real64 - 2.0_real64 * abs(modulo(t, 2.0_real64) - 1.0_real64)
   endfunction tri

   subroutine levels(ok, decimated)
   !< Phase 1: the line at four zoom levels, its limits read back, the picture against the golden; decimated: the two
   !< dense plots decimated, the two others not, the picture within the loosened threshold.
   logical, intent(out) :: ok(2)     !< Outcomes: limits (decimated: and which plots were), picture.
   logical, intent(in)  :: decimated !< Decimation on.
   integer(int32)       :: f         !< Frame.
   integer(int32)       :: k         !< Plot.
   integer(int32)       :: s         !< Status.
   integer(int64)       :: nf        !< Pixels that failed.
   integer(int64)       :: before    !< Items decimated before a plot's line.
   logical              :: thinned(4) !< Each plot's line decimated, on the captured frame.
   integer(int64)       :: kept(4)   !< Points it kept.

   s = -1_int32
   thinned = .false.
   kept = 0_int64
   do f = 1_int32, 4_int32
      if (.not. app%next_frame()) error stop 'figure_test_plot_view: next_frame returned false in headless mode'
      call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
      if (ig_begin('levels', flags=ImGuiWindowFlags_NoDecoration)) then
         do k = 1_int32, 4_int32
            if (mod(k, 2_int32) == 0_int32) call ig_same_line()
            if (ip_begin_plot('##level'//achar(48 + k), width=388.0_real64, height=285.0_real64)) then
               call ip_setup_axes_limits(0.0_real64, XSPAN(k), -1.4_real64, 1.4_real64, always=.true.)
               before = plot_decimated
               if (decimated) call ip_cache_next_item(changed=f == 1_int32 .and. k == 1_int32) ! one cache, four views
               call ip_line('signal', x, y, spec=ip_spec(line_color=SIGNAL_C))
               thinned(k) = plot_decimated > before
               if (thinned(k)) kept(k) = plot_kept
               call ip_plot_limits(lim(1, k), lim(2, k), lim(3, k), lim(4, k))
               call ip_end_plot()
            endif
         enddo
      endif
      call ig_end()
      if (f == 3_int32) call test_capture(LEVELS_SHOT, s)
   enddo
   ok(1) = all(abs(lim(1, :)) < 1.0e-12_real64) .and. all(abs(lim(2, :) - XSPAN) < 1.0e-9_real64 * XSPAN) .and. &
           all(abs(lim(3, :) + 1.4_real64) < 1.0e-12_real64) .and. all(abs(lim(4, :) - 1.4_real64) < 1.0e-12_real64)
   if (.not. ok(1)) write(output_unit, '(A,16ES12.4)') 'levels: limits ', lim
   if (decimated) then ! 388 pixels wide, about 340 of plot area: the dense plot at most 64 points a column, the others
                       ! every point in view (x 0 to 100, 5, 0.5) and a few of the 200001 off the plot
      ok(1) = ok(1) .and. all(thinned) .and. kept(1) <= 64_int64 * 400_int64 .and. kept(1) > 4_int64 * 300_int64 .and. &
              kept(2) >= 20001_int64 .and. kept(2) < 20600_int64 .and. kept(3) >= 1001_int64 .and.                   &
              kept(3) < 1100_int64 .and. kept(4) >= 101_int64 .and. kept(4) < 200_int64
      if (.not. ok(1)) write(output_unit, '(A,4L2,4(1X,I0))') 'levels: decimated, kept ', thinned, kept
   else
      ok(1) = ok(1) .and. .not. any(thinned)
   endif
   ok(2) = s == FIG_OK
   if (ok(2)) then
      if (decimated) then ! loosened (#15 §4): the decimated strokes' anti-aliasing, see the header
         ok(2) = test_compare_image(LEVELS_SHOT, LEVELS_GOLDEN, threshold=96_int32, failed=nf, stat=s)
      else
         ok(2) = test_compare_image(LEVELS_SHOT, LEVELS_GOLDEN, failed=nf, stat=s)
      endif
   endif
   if (.not. ok(2)) write(output_unit, '(A,I0,A,I0,A,A)') 'levels: status ', s, ', ', nf, ' failed: ', figure_last_error()
   endsubroutine levels

   subroutine interaction(ok)
   !< Phase 2: the drag line, the pan, the wheel, the box, the legend; the picture against the golden.
   logical, intent(out) :: ok(7)     !< Outcomes: drag line, pan, zoom, box, legend hover, legend hide, picture.
   real(real64)         :: v0(4)     !< Limits before a step.
   real(real64)         :: a0(4)     !< Plot area before a step.
   real(real64)         :: sx, sy    !< Plot units per pixel, before a step.
   real(real64)         :: c(2)      !< A pixel.
   real(real64)         :: keep_pt(2) !< The plot point under the pointer before the wheel.
   real(real64)         :: box(4)    !< The box selected [plot units]: xmin, xmax, ymin, ymax.
   real(real64)         :: y_before  !< The drag line before its drag.
   logical              :: drawn_before !< The first item's colour drawn before the click on its entry.
   logical              :: hover_seen   !< Its entry hovered with the pointer on it.
   integer(int32)       :: s         !< Status.
   integer(int64)       :: nf        !< Pixels that failed.

   ok = .false.
   s = -1_int32
   call run(3_int32)                                               ! the layout settles
   ! the drag line: 40 pixels down
   a0 = area
   sy = (view(4) - view(3)) / (a0(4) - a0(2))
   y_before = yline
   call probe_point(5.0_real64, yline)
   call test_drag(px_of(1), px_of(2), px_of(1), px_of(2) + 40.0_real64)
   call run(10_int32)
   ok(1) = line_moved .and. abs((y_before - yline) - 40.0_real64 * sy) < 0.5_real64 * sy
   if (.not. ok(1)) write(output_unit, '(A,L2,3ES13.5)') 'drag line: ', line_moved, y_before, yline, 40.0_real64 * sy
   ! the pan: a left drag of (-100, +50) pixels from the plot point (7, -1.5), away from the items and the line
   v0 = view
   a0 = area
   sx = (v0(2) - v0(1)) / (a0(3) - a0(1))
   sy = (v0(4) - v0(3)) / (a0(4) - a0(2))
   call probe_point(7.0_real64, -1.5_real64)
   call test_drag(px_of(1), px_of(2), px_of(1) - 100.0_real64, px_of(2) + 50.0_real64)
   call run(10_int32)
   ok(2) = abs((view(1) - v0(1)) - 100.0_real64 * sx) < sx .and. abs((view(3) - v0(3)) - 50.0_real64 * sy) < sy .and. &
           abs((view(2) - view(1)) - (v0(2) - v0(1))) < 1.0e-9_real64 .and.                                       &
           abs((view(4) - view(3)) - (v0(4) - v0(3))) < 1.0e-9_real64
   if (.not. ok(2)) write(output_unit, '(A,8ES12.4)') 'pan: ', v0, view
   ! the wheel: one step in at a third of the plot area, the plot point there kept
   v0 = view
   a0 = area
   sx = (v0(2) - v0(1)) / (a0(3) - a0(1))
   sy = (v0(4) - v0(3)) / (a0(4) - a0(2))
   c = [a0(1) + (a0(3) - a0(1)) / 3.0_real64, a0(2) + (a0(4) - a0(2)) / 3.0_real64]
   probe = c
   call run(1_int32)
   keep_pt = under
   call test_mouse_move(c(1), c(2))
   call test_next_frame()
   call test_next_frame()
   call test_wheel(1.0_real64)
   call run(10_int32)
   ok(3) = view(2) - view(1) < 0.95_real64 * (v0(2) - v0(1)) .and. view(4) - view(3) < 0.95_real64 * (v0(4) - v0(3)) &
           .and. abs(under(1) - keep_pt(1)) < sx .and. abs(under(2) - keep_pt(2)) < sy
   if (.not. ok(3)) write(output_unit, '(A,12ES12.4)') 'zoom: ', v0, view, keep_pt, under
   ! the box: a right-button drag over the middle half of the view, released: the view is the box
   v0 = view
   a0 = area
   sx = (v0(2) - v0(1)) / (a0(3) - a0(1))
   sy = (v0(4) - v0(3)) / (a0(4) - a0(2))
   box = [v0(1) + 0.25_real64 * (v0(2) - v0(1)), v0(1) + 0.75_real64 * (v0(2) - v0(1)), &
          v0(3) + 0.30_real64 * (v0(4) - v0(3)), v0(3) + 0.80_real64 * (v0(4) - v0(3))]
   call probe_point(box(1), box(4))
   c = px_of
   call probe_point(box(2), box(3))
   call test_mouse_move(c(1), c(2))
   call test_next_frame()
   call test_next_frame()
   call test_mouse_button(.true., 'right')
   call test_next_frame()
   call test_mouse_move(0.5_real64 * (c(1) + px_of(1)), 0.5_real64 * (c(2) + px_of(2)))
   call test_next_frame()
   call test_mouse_move(px_of(1), px_of(2))
   call test_next_frame()
   call test_next_frame()
   call test_mouse_button(.false., 'right')
   sel_seen = .false.
   call run(12_int32)
   ok(4) = abs(view(1) - box(1)) < 1.5_real64 * sx .and. abs(view(2) - box(2)) < 1.5_real64 * sx .and. &
           abs(view(3) - box(3)) < 1.5_real64 * sy .and. abs(view(4) - box(4)) < 1.5_real64 * sy .and. sel_seen
   if (ok(4)) ok(4) = all(abs(sel([1, 2]) - box([1, 2])) < 1.5_real64 * sx) .and. &
                      all(abs(sel([3, 4]) - box([3, 4])) < 1.5_real64 * sy)
   if (.not. ok(4)) write(output_unit, '(A,L2,12ES12.4)') 'box: ', sel_seen, box, sel, view
   ! the legend: the pointer on the first entry (below the plot area's north-west corner) hovers it; a click hides it
   drawn_before = first_drawn
   c = [area(1) + 40.0_real64, area(2) + 22.0_real64]
   call test_mouse_move(c(1), c(2))
   hover_seen = .false.
   call run(4_int32, hover_seen)
   call test_click(c(1), c(2))
   call run(8_int32)
   ok(5) = hover_seen
   ok(6) = drawn_before .and. .not. first_drawn
   if (.not. all(ok(5:6))) write(output_unit, '(A,3L2)') 'legend: ', hover_seen, drawn_before, first_drawn
   ! the picture: the pointer moved off the plot, then the frame captured
   call test_mouse_move(real(W, real64) - 5.0_real64, real(H, real64) - 5.0_real64)
   call run(4_int32)
   call run(1_int32, shot=VIEW_SHOT, stat=s)
   call run(1_int32)
   ok(7) = s == FIG_OK
   if (ok(7)) ok(7) = test_compare_image(VIEW_SHOT, VIEW_GOLDEN, failed=nf, stat=s)
   if (.not. ok(7)) write(output_unit, '(A,I0,A,I0,A,A)') 'view: status ', s, ', ', nf, ' failed: ', figure_last_error()
   endsubroutine interaction

   subroutine probe_point(xp, yp)
   !< The pixel of the plot point (xp, yp) in the interaction plot, read on one frame: `px_of`.
   real(real64), intent(in) :: xp, yp !< Plot point.

   px_of = [xp, yp]
   call run(1_int32)
   px_of = px
   endsubroutine probe_point

   subroutine run(n, hover_seen, shot, stat)
   !< `n` frames of the interaction plot; `hover_seen` turns true if the first legend entry is hovered on one; the last
   !< frame captured to `shot`.
   integer(int32),   intent(in)              :: n          !< Frames.
   logical,          intent(inout), optional :: hover_seen !< The first entry hovered on some frame.
   character(len=*), intent(in),    optional :: shot       !< Capture of the last frame.
   integer(int32),   intent(out),   optional :: stat       !< Status of the capture.
   integer(int32)                            :: f          !< Frame.

   do f = 1_int32, n
      if (.not. app%next_frame()) error stop 'figure_test_plot_view: next_frame returned false in headless mode'
      call view_frame()
      if (present(hover_seen)) hover_seen = hover_seen .or. hovered
      if (f == n .and. present(shot)) call test_capture(shot, stat)
   enddo
   endsubroutine run

   subroutine view_frame()
   !< One frame of the interaction plot: its limits, its plot area, the pixel of `px_of` and the plot point under
   !< `probe` read; whether the first entry is hovered and the first item drawn.
   real(real64) :: e(4) !< An extent [pixels].
   real(real64) :: b(3) !< A style read.
   integer(int32) :: nb !< Values of a style variable.

   hovered = .false.
   call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
   if (ig_begin('view', flags=ImGuiWindowFlags_NoDecoration)) then
      call ip_push_style_var('PlotBorderSize', 3.0_real64)
      call ip_push_style_color('PlotBg', '#1e2a38')
      if (ip_begin_plot('##view', width=640.0_real64, height=440.0_real64)) then
         call ip_setup_axes_limits(0.0_real64, 10.0_real64, -2.0_real64, 2.0_real64)
         call ip_line('first', xs, ys1, spec=ip_spec(line_color=FIRST_C))
         hovered = ip_legend_hovered('first')
         call ip_line('second', xs, ys2, spec=ip_spec(line_color=SECOND_C))
         if (ip_drag_line_y(1_int32, yline, color=DRAG_C, thickness=2.0_real64)) line_moved = .true.
         call ip_plot_limits(view(1), view(2), view(3), view(4))
         call ip_plot_to_pixels(view(1), view(4), area(1), area(2))
         call ip_plot_to_pixels(view(2), view(3), area(3), area(4))
         call ip_plot_to_pixels(px_of(1), px_of(2), px(1), px(2))
         call ip_pixels_to_plot(probe(1), probe(2), under(1), under(2))
         if (ip_plot_selection(e(1), e(2), e(3), e(4))) then
            sel_seen = .true.
            sel = e
         endif
         call ip_get_style_var('PlotBorderSize', b(1:2), nb)
         style_in(1) = b(1)
         call ip_get_style_color('PlotBg', e)
         style_in(2:3) = e(1:2)
         call ip_end_plot()
      endif
      call ip_pop_style_color()
      call ip_pop_style_var()
      call test_drawn_extent(FIRST_C, e(1), e(2), e(3), e(4), found=first_drawn)
   endif
   call ig_end()
   endsubroutine view_frame

   subroutine styles(ok)
   !< Phase 3: the style inside the push (read during the plot), after the pop; the set alpha; a pop too many.
   logical, intent(out) :: ok(3)  !< Outcomes: inside, after, set and refused pop.
   real(real64)         :: v(2)   !< A variable's values.
   real(real64)         :: rgba(4) !< A colour.
   integer(int32)       :: nv     !< Values.

   call run(1_int32)
   call ip_get_style_var('PlotBorderSize', v, nv)
   style_out(1) = v(1)
   call ip_get_style_color('PlotBg', rgba)
   style_out(2:3) = rgba(1:2)
   call ip_get_style_var('MinorAlpha', v, nv)
   minor = v(1)
   call ip_pop_style_var(stat=pop_stat)
   ok(1) = abs(style_in(1) - 3.0_real64) < 1.0e-6_real64 .and. all(abs(style_in(2:3) - BG(1:2)) < TOL8)
   ok(2) = abs(style_out(1) - 3.0_real64) > 0.5_real64 .and. any(abs(style_out(2:3) - BG(1:2)) > TOL8)
   ok(3) = abs(minor - 0.5_real64) < 1.0e-6_real64 .and. pop_stat == FIG_ERR_STATE
   if (.not. all(ok)) write(output_unit, '(A,7ES12.4,I3)') 'styles: ', style_in, style_out, minor, pop_stat
   endsubroutine styles

   subroutine remove_files()
   !< The captures (and the .new.png, .diff.png a mismatch writes beside the goldens are left for inspection).
   integer(int32) :: unit, ios !< Unit, status.
   integer(int32) :: k         !< Counter.
   character(len=*), parameter :: FILES(2) = [character(len=40) :: LEVELS_SHOT, VIEW_SHOT] !< The captures.

   do k = 1_int32, size(FILES, kind=int32)
      open(newunit=unit, file=trim(FILES(k)), status='old', iostat=ios)
      if (ios == 0) close(unit, status='delete')
   enddo
   endsubroutine remove_files
endprogram figure_test_plot_view
