!< figure_test_plot_more, bubbles, error bars along x and pie charts, headless.
program figure_test_plot_more
!< figure_test_plot_more, bubbles, error bars along x and pie charts, headless.
!<
!< 1. Bubbles at (1, 1), (2, 2), (3, 3) of radius 0.5: the auto-fitted y axis reaches 0.5 and 3.5 (each centre plus or
!<    minus its radius), single and double precision alike.
!< 2. Error bars of 0.5 at the same points: vertical, the y axis fits [0.5, 3.5] and x [1, 3]; `horizontal=.true.`, x
!<    fits [0.5, 3.5] and y [1, 3].
!< 3. A pie of one slice worth 0.25, coloured by a colormap of its own (`colormap`; no legend entry): partial, its
!<    fill covers the quarter to the right of the top (the slices go clockwise from 90 degrees), a quarter of the box;
!<    with `normalize=.true.`, the whole circle. Three slices worth 1, 2, 3 in single precision draw with their labels.
!< 4. Wrong calls: labels not one per value, a radius of 0, a negative value, an integer format, bubbles with radii not
!<    one per point: refused with their statuses and messages, nothing drawn.
use, intrinsic :: iso_fortran_env, only : int32, real32, real64, output_unit
use figure, only : FIG_ERR_ARGUMENT, FIG_OK, app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window,    &
                   ip_begin_plot, ip_bubbles, ip_end_plot, ip_error_bars, ip_pie_chart, ip_plot_limits, ip_setup_axes, &
                   ip_spec, ImPlotItemFlags_NoLegend, ig_same_line, ip_colormap, ip_load_colormap
use figure_testing, only : test_drawn_extent

implicit none
real(real64), parameter :: PIE(4) = [0.95_real64, 0.10_real64, 0.85_real64, 1.0_real64]  !< The partial slice's colour.
real(real64), parameter :: PIE2(4) = [0.10_real64, 0.85_real64, 0.95_real64, 1.0_real64] !< The normalized one's.
real(real64), parameter :: TOL = 1.0e-6_real64          !< Tolerance on a fitted limit.
type(app_object)        :: app                          !< Application.
logical                 :: ok(9)                        !< Per-check outcome.
real(real64)            :: x(3), y(3), r(3)             !< Points and radii.
real(real32)            :: x4(3), y4(3), r4(3)          !< The same, single precision.
real(real64)            :: bub(4), bub4(4)              !< Limits of the bubble plots (x, y).
real(real64)            :: vert(4), horz(4)             !< Limits of the error bar plots.
real(real64)            :: quarter(4), whole(4)         !< Drawn extents of the partial and the normalized pie.
logical                 :: q_found, w_found             !< They were drawn.
integer(int32)          :: st(6)                        !< Statuses of the wrong calls (and one right call).
character(len=160)      :: msg(5)                       !< Their messages.
integer(int32)          :: f                            !< Frame.
integer(int32)          :: u                            !< Unit of the colormaps' files.
character(len=*), parameter :: DIR = 'figure_test_plot_more.' !< Prefix of the colormaps' files (working folder).

x = [1.0_real64, 2.0_real64, 3.0_real64]
y = x
r = 0.5_real64
x4 = real(x, real32)
y4 = real(y, real32)
r4 = real(r, real32)
ok = .false.
st = -1_int32
msg = ''
open(newunit=u, file=DIR//'pie1.csv.tmp', status='replace', action='write')
write(u, '(3(F5.2,:,","))') PIE(1:3)
write(u, '(3(F5.2,:,","))') PIE2(1:3)
close(u)
open(newunit=u, file=DIR//'pie2.csv.tmp', status='replace', action='write')
write(u, '(3(F5.2,:,","))') PIE2(1:3)
write(u, '(3(F5.2,:,","))') PIE(1:3)
close(u)
call ip_load_colormap('figure-test-pie1', DIR//'pie1.csv.tmp')
call ip_load_colormap('figure-test-pie2', DIR//'pie2.csv.tmp')
open(newunit=u, file=DIR//'pie1.csv.tmp', status='old')
close(u, status='delete')
open(newunit=u, file=DIR//'pie2.csv.tmp', status='old')
close(u, status='delete')
call app%init_headless(900_int32, 900_int32)
do f = 1_int32, 6_int32
   if (.not. app%next_frame()) exit
   call ig_set_next_window(0.0_real64, 0.0_real64, 900.0_real64, 900.0_real64, always=.true.)
   if (ig_begin('More')) then
      if (ip_begin_plot('bubbles', width=280.0_real64, height=270.0_real64)) then
         call ip_setup_axes('x', 'y', auto_fit=.true.)
         call ip_bubbles('b', x, y, r)
         call ip_plot_limits(bub(1), bub(2), bub(3), bub(4))
         call ip_end_plot()
      endif
      call ig_same_line()
      if (ip_begin_plot('bubbles single', width=280.0_real64, height=270.0_real64)) then
         call ip_setup_axes('x', 'y', auto_fit=.true.)
         call ip_bubbles('b', x4, y4, r4)
         call ip_plot_limits(bub4(1), bub4(2), bub4(3), bub4(4))
         call ip_end_plot()
      endif
      call ig_same_line()
      if (ip_begin_plot('vertical', width=280.0_real64, height=270.0_real64)) then
         call ip_setup_axes('x', 'y', auto_fit=.true.)
         call ip_error_bars('e', x, y, r)
         call ip_plot_limits(vert(1), vert(2), vert(3), vert(4))
         call ip_end_plot()
      endif
      if (ip_begin_plot('horizontal', width=280.0_real64, height=270.0_real64)) then
         call ip_setup_axes('x', 'y', auto_fit=.true.)
         call ip_error_bars('e', x, y, r, horizontal=.true.)
         call ip_plot_limits(horz(1), horz(2), horz(3), horz(4))
         call ip_end_plot()
      endif
      call ig_same_line()
      if (ip_begin_plot('partial', width=280.0_real64, height=270.0_real64, equal=.true.)) then
         call ip_pie_chart(['quarter'], [0.25_real64], 0.5_real64, 0.5_real64, 0.4_real64, label_format='', &
                           colormap=ip_colormap('figure-test-pie1'), spec=ip_spec(flags=ImPlotItemFlags_NoLegend))
         call ip_end_plot()
      endif
      call test_drawn_extent(PIE, quarter(1), quarter(2), quarter(3), quarter(4), found=q_found)
      call ig_same_line()
      if (ip_begin_plot('normalized', width=280.0_real64, height=270.0_real64, equal=.true.)) then
         call ip_pie_chart(['quarter'], [0.25_real64], 0.5_real64, 0.5_real64, 0.4_real64, label_format='', &
                           normalize=.true., colormap=ip_colormap('figure-test-pie2'),                    &
                           spec=ip_spec(flags=ImPlotItemFlags_NoLegend))
         call ip_end_plot()
      endif
      call test_drawn_extent(PIE2, whole(1), whole(2), whole(3), whole(4), found=w_found)
      if (ip_begin_plot('three', width=280.0_real64, height=270.0_real64, equal=.true.)) then
         call ip_pie_chart(['one  ', 'two  ', 'three'], [1.0_real32, 2.0_real32, 3.0_real32], 0.5_real64, 0.5_real64, &
                           0.4_real64, angle0=0.0_real64, stat=st(6))
         if (f == 6_int32) then
            call ip_pie_chart(['a', 'b'], [1.0_real64], 0.5_real64, 0.5_real64, 0.4_real64, stat=st(1))
            msg(1) = figure_last_error()
            call ip_pie_chart(['a'], [1.0_real64], 0.5_real64, 0.5_real64, 0.0_real64, stat=st(2))
            msg(2) = figure_last_error()
            call ip_pie_chart(['a', 'b'], [1.0_real64, -1.0_real64], 0.5_real64, 0.5_real64, 0.4_real64, stat=st(3))
            msg(3) = figure_last_error()
            call ip_pie_chart(['a'], [1.0_real64], 0.5_real64, 0.5_real64, 0.4_real64, label_format='%d', stat=st(4))
            msg(4) = figure_last_error()
            call ip_bubbles('b', x, y, r(1:2), stat=st(5))
            msg(5) = figure_last_error()
         endif
         call ip_end_plot()
      endif
   endif
   call ig_end()
enddo
call app%destroy()

ok(1) = abs(bub(3) - 0.5_real64) < TOL .and. abs(bub(4) - 3.5_real64) < TOL               ! centre +- radius on y
ok(2) = all(abs(bub4 - bub) < 1.0e-5_real64)                                                ! single precision alike
ok(3) = abs(vert(1) - 1.0_real64) < TOL .and. abs(vert(2) - 3.0_real64) < TOL .and. &
        abs(vert(3) - 0.5_real64) < TOL .and. abs(vert(4) - 3.5_real64) < TOL               ! vertical
ok(4) = abs(horz(1) - 0.5_real64) < TOL .and. abs(horz(2) - 3.5_real64) < TOL .and. &
        abs(horz(3) - 1.0_real64) < TOL .and. abs(horz(4) - 3.0_real64) < TOL               ! horizontal
! the partial pie: the quarter right of the top, about as wide as high; the normalized one about twice as wide and high
ok(5) = q_found .and. abs((quarter(3) - quarter(1)) - (quarter(4) - quarter(2))) < 4.0_real64
ok(6) = w_found .and. whole(3) - whole(1) > 1.8_real64 * (quarter(3) - quarter(1)) .and. &
        whole(4) - whole(2) > 1.8_real64 * (quarter(4) - quarter(2))
ok(7) = all(st(1:5) == FIG_ERR_ARGUMENT) .and. st(6) == FIG_OK
ok(8) = msg(1) == 'ip_pie_chart: labels must be one per value' .and.                     &
        msg(2) == 'ip_pie_chart: the radius must be above 0' .and.                       &
        msg(3) == 'ip_pie_chart: a value is below 0 or not finite' .and.                 &
        index(msg(4), 'ip_pie_chart:') == 1 .and. index(msg(5), 'ip_bubbles:') == 1
ok(9) = abs(bub(1) - 1.0_real64) < 0.6_real64 .and. abs(bub(2) - 3.0_real64) < 0.6_real64 ! x: the centres, at most a radius

write(output_unit, '(A,4F9.4)') 'bubbles        ', bub
write(output_unit, '(A,4F9.4)') 'vertical bars  ', vert
write(output_unit, '(A,4F9.4)') 'horizontal bars', horz
write(output_unit, '(A,4F9.1,L2)') 'partial pie    ', quarter, q_found
write(output_unit, '(A,4F9.1,L2)') 'normalized pie ', whole, w_found
write(output_unit, '(A,6I3)') 'statuses ', st
write(output_unit, '(A)') (trim(msg(f)), f = 1_int32, 5_int32)
write(output_unit, '(A,*(L2))') 'figure_test_plot_more checks:', ok
if (.not. all(ok)) error stop 'figure_test_plot_more: FAILED'
write(output_unit, '(A)') 'figure_test_plot_more: all checks passed'

endprogram figure_test_plot_more
