!< figure_test_plot_frame_draw, drawing in a plot of the Fortran frame (`pf_draw_*`), as `ig_draw_*` on the plot layer.
program figure_test_plot_frame_draw
!< figure_test_plot_frame_draw, drawing in a plot of the Fortran frame (`pf_draw_*`), as `ig_draw_*` on the plot layer.
!<
!< szaghi/figure#15, figure_plot_draw. Each case is a plot drawn on NF frames, first by ImPlot through FIGURE's API with
!< the primitives of figure_canvas on the `'plot'` layer (`ig_draw_*(..., layer='plot')`: native/figure_canvas.cpp),
!< then by the Fortran frame with `pf_draw_*`, in one headless window at the same place, 40 frames apart. Checked: the
!< last pictures at FIGURE's oracle rule (|d| <= 2 on every channel, no pixel failing), the statuses equal:
!<
!< 1. every primitive (a segment, rectangles, circles, polylines, polygons convex and not, outlined and filled, a text,
!<    an image tinted), over a line item and partly outside the plot's area (clipped), on linear axes;
!< 2. the same on a log x axis and a symlog y axis (the axes' transforms);
!< 3. a strong zoom: points millions of pixels outside the plot (kept within 1e7 pixels of the origin);
!< 4. the refusals, on both sides: outside a plot (`FIG_ERR_STATE`), a colour out of [0, 1], too few points, a NaN
!<    coordinate, a negative radius, a zero thickness, sizes that differ (`FIG_ERR_ARGUMENT`); a text drawn (`FIG_OK`).
!<
!< Not here: Dear ImGui's style alpha below 1 (the primitives pack their colour times it, as `ImGui::GetColorU32`), as
!< the frame itself does not follow it yet (its backgrounds and labels differ from ImPlot's then).
!<
!< The pictures are `figure_test_plot_frame_draw.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: ieee_arithmetic, only : ieee_quiet_nan, ieee_value
use, intrinsic :: iso_fortran_env, only : int8, int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ip_begin_plot, ip_end_plot, &
                   ip_line, ip_setup_axes, ip_setup_axes_limits,                                                  &
                   ig_draw_line, ig_draw_rect, ig_draw_circle, ig_draw_polyline, ig_draw_polygon, ig_draw_text,   &
                   ig_draw_image, texture_object, ImGuiWindowFlags_NoDecoration, FIG_OK, FIG_ERR_STATE,           &
                   FIG_ERR_ARGUMENT
use figure_plot_frame, only : pf_begin_plot, pf_end_plot, pf_setup_axes, pf_setup_axes_limits
use figure_plot_items, only : pf_line
use figure_plot_draw, only : pf_draw_line, pf_draw_rect, pf_draw_circle, pf_draw_polyline, pf_draw_polygon, &
                             pf_draw_text, pf_draw_image
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

implicit none
integer(int32), parameter :: W = 640_int32     !< Display width [pixels].
integer(int32), parameter :: H = 480_int32     !< Display height [pixels].
integer(int32), parameter :: NCASE = 3_int32   !< Cases with a picture.
integer(int32), parameter :: NF = 3_int32      !< Frames per side of a case.
integer(int32), parameter :: NREF = 8_int32    !< Refusals.
real(real64),   parameter :: RED(4) = [0.90_real64, 0.25_real64, 0.20_real64, 1.0_real64]   !< A colour.
real(real64),   parameter :: BLUE(4) = [0.20_real64, 0.45_real64, 0.95_real64, 0.6_real64]  !< Another, translucent.
real(real64),   parameter :: GREEN(3) = [0.30_real64, 0.80_real64, 0.35_real64]             !< A third, 3 components.
real(real64),   parameter :: TINT(4) = [1.0_real64, 0.8_real64, 0.6_real64, 0.9_real64]     !< An image's tint.
type(app_object)          :: app               !< Application.
type(texture_object)      :: tex               !< An image.
integer(int8)             :: pixels(4, 4, 3)   !< Its pixels.
real(real64)              :: lx(50), ly(50)    !< A line item.
real(real64)              :: ax(7), ay(7)      !< An arrow (a concave polygon).
real(real64)              :: zx(3), zy(3)      !< A polyline through far points.
real(real64)              :: qx(10), qy(10)    !< A polyline (named arrays: nvfortran, see the report of P11 (a)).
real(real64)              :: bx(7), by(7)      !< The arrow moved.
integer(int32)            :: st(NREF, 2)       !< The refusals' statuses per side.
logical                   :: test_passed(NCASE + 1) !< Per-case outcome, the refusals.
logical                   :: side_fortran      !< Drawing with the Fortran frame.
integer(int32)            :: c, f, s, sd, i, j !< Case, frame, status, side, counters.
character(len=16)         :: keep              !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do j = 1_int32, 3_int32
   do i = 1_int32, 4_int32
      pixels(1, i, j) = byte(mod(60 * i, 256))
      pixels(2, i, j) = byte(mod(80 * j, 256))
      pixels(3, i, j) = byte(mod(40 * (i + j), 256))
      pixels(4, i, j) = byte(255)
   enddo
enddo
call tex%init(4_int32, 3_int32)
call tex%update(pixels)
do i = 1_int32, 50_int32
   lx(i) = 0.5_real64 + real(i - 1_int32, real64) * 0.2_real64
   ly(i) = 5.0_real64 + 3.0_real64 * sin(real(i, real64) * 0.3_real64)
enddo
ax = [1.0_real64, 4.0_real64, 4.0_real64, 6.0_real64, 4.0_real64, 4.0_real64, 1.0_real64]
ay = [1.5_real64, 1.5_real64, 0.8_real64, 2.5_real64, 4.2_real64, 3.5_real64, 3.5_real64]
qx = lx(1:30:3)
qy = ly(1:30:3) - 2.0_real64
bx = ax + 4.5_real64
by = ay + 4.0_real64
zx = [4.999_real64, 5.0005_real64, 1.0e6_real64]
zy = [5.0_real64, 5.0003_real64, -1.0e6_real64]
do c = 1_int32, NCASE
   do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
      side_fortran = sd == 2_int32
      do f = 1_int32, NF
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_draw: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame draw', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(c)
         call ig_end()
         if (f == NF) call test_capture(picture(c, side_fortran), s)
      enddo
      do i = 1_int32, 40_int32 ! the sides apart
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_draw: next_frame returned false headless'
      enddo
   enddo
   test_passed(c) = pictures_equal(c)
enddo
! 5: the refusals
st = -1_int32
do sd = 1_int32, 2_int32
   side_fortran = sd == 2_int32
   if (.not. app%next_frame()) error stop 'figure_test_plot_frame_draw: next_frame returned false headless'
   call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
   if (ig_begin('plot frame draw', flags=ImGuiWindowFlags_NoDecoration)) call refusals(st(:, sd))
   call ig_end()
enddo
if (.not. app%next_frame()) error stop 'figure_test_plot_frame_draw: next_frame returned false headless'
test_passed(NCASE + 1) = all(st(:, 1) == st(:, 2)) .and. st(1, 1) == FIG_ERR_STATE .and. &
                         all(st(2:NREF - 1, 1) == FIG_ERR_ARGUMENT) .and. st(NREF, 1) == FIG_OK
if (.not. test_passed(NCASE + 1)) then
   write(output_unit, '(A,*(1X,I0))') 'refusals, ImPlot:', st(:, 1)
   write(output_unit, '(A,*(1X,I0))') 'refusals, frame: ', st(:, 2)
endif
call tex%destroy()
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_draw checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine draw_case(k)
   !< A case's plot, by the side drawing.
   integer(int32), intent(in) :: k !< Case.

   if (.not. begin()) return
   select case (k)
   case (2_int32)
      call axes(0.3_real64, 12.0_real64, -2.0_real64, 9.0_real64, 'log', 'symlog')
   case (3_int32)
      call axes(4.998_real64, 5.002_real64, 4.999_real64, 5.001_real64, 'linear', 'linear')
   case default
      call axes(0.0_real64, 10.0_real64, 0.0_real64, 10.0_real64, 'linear', 'linear')
   endselect
   if (k == 3_int32) then
      call segment(4.9985_real64, 4.9995_real64, 1.0e7_real64, 1.0e7_real64, RED, 2.0_real64)
      call polyline(zx, zy, BLUE, 3.0_real64, .false.)
      call rect(4.9990_real64, 4.9998_real64, 1.0e9_real64, 5.0002_real64, GREEN, filled=.true.)
   else
      if (side_fortran) then
         call pf_line('line', lx, ly)
      else
         call ip_line('line', lx, ly)
      endif
      call segment(0.5_real64, 9.5_real64, 9.5_real64, 0.6_real64, RED, 2.0_real64)
      call segment(1.0_real64, 6.0_real64, 3.0_real64, 6.5_real64, BLUE)
      call rect(6.0_real64, 6.0_real64, 8.5_real64, 8.0_real64, BLUE, filled=.true.)
      call rect(8.5_real64, 1.0_real64, 6.5_real64, 2.5_real64, RED, thickness=3.0_real64)
      call rect(9.0_real64, 9.0_real64, 12.0_real64, 11.0_real64, GREEN, filled=.true.) ! clipped
      call circle(2.0_real64, 8.0_real64, 18.0_real64, RED, filled=.true.)
      call circle(3.5_real64, 8.5_real64, 25.0_real64, BLUE, thickness=2.5_real64)
      call circle(9.8_real64, 5.0_real64, 30.0_real64, GREEN) ! clipped
      call polyline(qx, qy, GREEN, 2.0_real64, .false.)
      call polyline([5.0_real64, 7.0_real64, 6.0_real64], [3.0_real64, 3.0_real64, 4.5_real64], RED, 1.5_real64, &
                    .true.)
      call polygon(ax, ay, BLUE, filled=.true.)
      call polygon(bx, by, RED, thickness=2.0_real64) ! partly clipped
      call text(1.0_real64, 9.6_real64, 'in the plot: 1.5e+03', RED)
      call image(6.5_real64, 4.0_real64, 9.0_real64, 5.5_real64)
   endif
   call finish()
   endsubroutine draw_case

   logical function begin()
   !< The plot begun, by the side drawing.
   if (side_fortran) then
      begin = pf_begin_plot('Draw', width=600.0_real64, height=440.0_real64)
   else
      begin = ip_begin_plot('Draw', width=600.0_real64, height=440.0_real64)
   endif
   endfunction begin

   subroutine axes(x0, x1, y0, y1, xs, ys)
   !< The axes, their scales and limits, by the side drawing.
   real(real64),     intent(in) :: x0, x1, y0, y1 !< Limits.
   character(len=*), intent(in) :: xs, ys         !< Scales.

   if (side_fortran) then
      call pf_setup_axes('x', 'y', xscale=xs, yscale=ys)
      call pf_setup_axes_limits(x0, x1, y0, y1, always=.true.)
   else
      call ip_setup_axes('x', 'y', xscale=xs, yscale=ys)
      call ip_setup_axes_limits(x0, x1, y0, y1, always=.true.)
   endif
   endsubroutine axes

   subroutine finish()
   !< The plot ended, by the side drawing.
   if (side_fortran) then
      call pf_end_plot()
   else
      call ip_end_plot()
   endif
   endsubroutine finish

   subroutine segment(x1, y1, x2, y2, col, t)
   !< A segment, by the side drawing.
   real(real64), intent(in)           :: x1, y1, x2, y2, col(:) !< Ends, colour.
   real(real64), intent(in), optional :: t                      !< Thickness.

   if (side_fortran) then
      call pf_draw_line(x1, y1, x2, y2, col, thickness=t)
   else
      call ig_draw_line(x1, y1, x2, y2, col, thickness=t, layer='plot')
   endif
   endsubroutine segment

   subroutine rect(x1, y1, x2, y2, col, thickness, filled)
   !< A rectangle, by the side drawing.
   real(real64), intent(in)           :: x1, y1, x2, y2, col(:) !< Corners, colour.
   real(real64), intent(in), optional :: thickness              !< Thickness.
   logical,      intent(in), optional :: filled                 !< Filled.

   if (side_fortran) then
      call pf_draw_rect(x1, y1, x2, y2, col, thickness=thickness, filled=filled)
   else
      call ig_draw_rect(x1, y1, x2, y2, col, thickness=thickness, filled=filled, layer='plot')
   endif
   endsubroutine rect

   subroutine circle(x, y, r, col, thickness, filled)
   !< A circle, by the side drawing.
   real(real64), intent(in)           :: x, y, r, col(:) !< Centre, radius, colour.
   real(real64), intent(in), optional :: thickness       !< Thickness.
   logical,      intent(in), optional :: filled          !< Filled.

   if (side_fortran) then
      call pf_draw_circle(x, y, r, col, thickness=thickness, filled=filled)
   else
      call ig_draw_circle(x, y, r, col, thickness=thickness, filled=filled, layer='plot')
   endif
   endsubroutine circle

   subroutine polyline(x, y, col, t, closed)
   !< A polyline, by the side drawing.
   real(real64), intent(in) :: x(:), y(:), col(:), t !< Points, colour, thickness.
   logical,      intent(in) :: closed                !< Closed.

   if (side_fortran) then
      call pf_draw_polyline(x, y, col, thickness=t, closed=closed)
   else
      call ig_draw_polyline(x, y, col, thickness=t, closed=closed, layer='plot')
   endif
   endsubroutine polyline

   subroutine polygon(x, y, col, thickness, filled)
   !< A polygon, by the side drawing.
   real(real64), intent(in)           :: x(:), y(:), col(:) !< Points, colour.
   real(real64), intent(in), optional :: thickness          !< Thickness.
   logical,      intent(in), optional :: filled             !< Filled.

   if (side_fortran) then
      call pf_draw_polygon(x, y, col, thickness=thickness, filled=filled)
   else
      call ig_draw_polygon(x, y, col, thickness=thickness, filled=filled, layer='plot')
   endif
   endsubroutine polygon

   subroutine text(x, y, t, col)
   !< A text, by the side drawing.
   real(real64),     intent(in) :: x, y, col(:) !< Position, colour.
   character(len=*), intent(in) :: t            !< Text.

   if (side_fortran) then
      call pf_draw_text(x, y, t, col)
   else
      call ig_draw_text(x, y, t, col, layer='plot')
   endif
   endsubroutine text

   subroutine image(x1, y1, x2, y2)
   !< The image, tinted, by the side drawing.
   real(real64), intent(in) :: x1, y1, x2, y2 !< Corners.

   if (side_fortran) then
      call pf_draw_image(tex, x1, y1, x2, y2, color=TINT)
   else
      call ig_draw_image(tex, x1, y1, x2, y2, color=TINT, layer='plot')
   endif
   endsubroutine image

   subroutine refusals(r)
   !< The refusals' statuses, by the side drawing: outside a plot first, then inside one.
   integer(int32), intent(out) :: r(NREF) !< Statuses.
   real(real64)                :: nan     !< A NaN.

   nan = ieee_value(1.0_real64, ieee_quiet_nan)
   if (side_fortran) then
      call pf_draw_line(1.0_real64, 1.0_real64, 2.0_real64, 2.0_real64, RED, stat=r(1))
   else
      call ig_draw_line(1.0_real64, 1.0_real64, 2.0_real64, 2.0_real64, RED, layer='plot', stat=r(1))
   endif
   if (.not. begin()) return
   call axes(0.0_real64, 10.0_real64, 0.0_real64, 10.0_real64, 'linear', 'linear')
   if (side_fortran) then
      call pf_draw_line(1.0_real64, 1.0_real64, 2.0_real64, 2.0_real64, [1.0_real64, 2.0_real64, 0.0_real64], stat=r(2))
      call pf_draw_polygon([1.0_real64, 2.0_real64], [1.0_real64, 2.0_real64], RED, stat=r(3))
      call pf_draw_polyline([1.0_real64, nan], [1.0_real64, 2.0_real64], RED, stat=r(4))
      call pf_draw_circle(1.0_real64, 1.0_real64, -1.0_real64, RED, stat=r(5))
      call pf_draw_rect(1.0_real64, 1.0_real64, 2.0_real64, 2.0_real64, RED, thickness=0.0_real64, stat=r(6))
      call pf_draw_polyline([1.0_real64, 2.0_real64, 3.0_real64], [1.0_real64, 2.0_real64], RED, stat=r(7))
      call pf_draw_text(1.0_real64, 1.0_real64, 'ok', GREEN, stat=r(8))
   else
      call ig_draw_line(1.0_real64, 1.0_real64, 2.0_real64, 2.0_real64, [1.0_real64, 2.0_real64, 0.0_real64], &
                        layer='plot', stat=r(2))
      call ig_draw_polygon([1.0_real64, 2.0_real64], [1.0_real64, 2.0_real64], RED, layer='plot', stat=r(3))
      call ig_draw_polyline([1.0_real64, nan], [1.0_real64, 2.0_real64], RED, layer='plot', stat=r(4))
      call ig_draw_circle(1.0_real64, 1.0_real64, -1.0_real64, RED, layer='plot', stat=r(5))
      call ig_draw_rect(1.0_real64, 1.0_real64, 2.0_real64, 2.0_real64, RED, thickness=0.0_real64, layer='plot', &
                        stat=r(6))
      call ig_draw_polyline([1.0_real64, 2.0_real64, 3.0_real64], [1.0_real64, 2.0_real64], RED, layer='plot', &
                            stat=r(7))
      call ig_draw_text(1.0_real64, 1.0_real64, 'ok', GREEN, layer='plot', stat=r(8))
   endif
   call finish()
   endsubroutine refusals

   function pictures_equal(k) result(ok)
   !< A case's pictures of both sides equal at the oracle's rule.
   integer(int32), intent(in) :: k   !< Case.
   logical                    :: ok  !< Equal.
   integer(int64)             :: nf_ !< Pixels that failed.
   integer(int32)             :: s_  !< Status.

   ok = test_compare_image(picture(k, .true.), picture(k, .false.), threshold=2_int32, max_failed=0_int32, &
                           failed=nf_, stat=s_)
   if (.not. ok) write(output_unit, '(A,I0,A,I0,A,A)') 'case ', k, ': ', nf_, ' pixels failed: ', figure_last_error()
   endfunction pictures_equal

   function picture(k, fortran) result(name)
   !< A case's picture: ImPlot's or the Fortran frame's.
   integer(int32), intent(in)    :: k       !< Case.
   logical,        intent(in)    :: fortran !< The Fortran frame's.
   character(len=:), allocatable :: name    !< File name.
   character(len=8)              :: tag     !< The case's number.

   write(tag, '(I0)') k
   if (fortran) then
      name = 'figure_test_plot_frame_draw.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_draw.'//trim(tag)//'.implot.png.tmp'
   endif
   endfunction picture

   pure function byte(v) result(b)
   !< 0-255 as a signed byte.
   integer, intent(in) :: v !< Value.
   integer(int8)       :: b !< Byte.

   b = int(merge(v - 256, v, v > 127), int8)
   endfunction byte

   subroutine remove_files()
   !< The pictures removed.
   integer(int32) :: k, m, u, ios !< Case, side, unit, status.
   logical        :: there        !< The file exists.

   do k = 1_int32, NCASE
      do m = 1_int32, 2_int32
         inquire(file=picture(k, m == 2_int32), exist=there)
         if (.not. there) cycle
         open(newunit=u, file=picture(k, m == 2_int32), status='old', iostat=ios)
         if (ios == 0) close(u, status='delete')
      enddo
   enddo
   endsubroutine remove_files
endprogram figure_test_plot_frame_draw
