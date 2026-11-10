!< figure_test_plot_axes, the six axes of a plot, their scales, ticks, constraints and the legend, headless.
program figure_test_plot_axes
!< figure_test_plot_axes, the six axes of a plot, their scales, ticks, constraints and the legend, headless.
!<
!< One window shows one plot setup per phase:
!<
!< 1. two y axes: a residual near [0, 1] on Y1 and a coefficient near [1000, 5000] on Y2 (`ip_set_axes`); each axis fits
!<    its own line, Y1 is not stretched by Y2's data, and `test_plot_tick('y2', ...)` reads Y2's labels (its format);
!< 2. a symmetric log axis over [-2000, 2000]: its ticks include the decades 10, 100, 1000 of both signs and 0 (a
!<    linear axis has ticks at multiples of 500 there);
!< 3. `ylog=.true.` (deprecated) and `yscale='log'` give the same ticks; fixed ticks show exactly their labels, and
!<    without labels the axis's format;
!< 4. a legend outside the plot area on the east narrows the plot area, one outside on the north in a row lowers it;
!< 5. axes set up and not used (X2, Y3), an axis set up with no item at all, a subplot cell with Y2: no fit of an empty
!<    axis (an FPE under -ffpe-trap in the debug build), the unused axis keeps a finite range;
!< 6. a constrained x axis zoomed out with the wheel stays within its bounds, zoomed in stays wider than its narrowest
!<    width; a locked y axis does not move; the same wheel on an unconstrained plot goes past those bounds (control);
!< 7. wrong calls: unknown axes, scales, locations; 'time' on y; an axis not set up; setup after an item; outside a
!<    plot; labels not one per value; bad constraints: refused with their statuses, nothing aborts.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use, intrinsic :: ieee_arithmetic, only : ieee_is_finite
use figure, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK, app_object, figure_last_error, ig_begin, ig_end,      &
                   ig_set_next_window, ip_begin_plot, ip_begin_subplots, ip_end_plot, ip_end_subplots, ip_line,   &
                   ip_plot_limits, ip_plot_size, ip_set_axes, ip_setup_axes, ip_setup_axes_limits, ip_setup_axis, &
                   ip_setup_axis_constraints, ip_setup_axis_limits, ip_setup_axis_ticks, ip_setup_legend
use figure_cimgui, only : im_vec2
use figure_cimplot, only : ImPlot_GetPlotPos
use figure_testing, only : test_mouse_move, test_plot_tick, test_wheel

implicit none
integer(int32), parameter     :: N = 101_int32          !< Samples per line.
integer(int32), parameter     :: NE = 22_int32          !< Wrong calls checked.
type(app_object)              :: app                    !< Application.
real(real64)                  :: x(N)                   !< Abscissae.
real(real64)                  :: res(N)                 !< A residual in [0, 1].
real(real64)                  :: coef(N)                !< A coefficient in [1000, 5000].
real(real64)                  :: signed(N)              !< A signed quantity in [-1000, 1000].
logical                       :: ok(16)                 !< Per-check outcome.
real(real64)                  :: y1lim(2), y2lim(2)     !< Limits of Y1 and Y2 in phase 1.
real(real64)                  :: ctl(2)                 !< Y1 limits with both lines on Y1 (control).
real(real64)                  :: wide(2), narrow(2)     !< x limits of the constrained plot, zoomed out and in.
real(real64)                  :: ylock(2)               !< y limits of the locked axis, after the wheel.
real(real64)                  :: free_x(2)              !< x limits of the unconstrained plot, zoomed out.
real(real64)                  :: y3lim(2)               !< Limits of an axis set up and not used.
real(real64)                  :: sizes(2, 3)            !< Plot areas of the three legend plots [pixels].
real(real64)                  :: centre(2)              !< Centre of the plot area [pixels].
character(len=32)             :: ticks_log(2, 12)       !< Tick labels of the two log plots.
integer(int32)                :: nlog(2)                !< Their counts.
character(len=:), allocatable :: label                  !< A tick label.
integer(int32)                :: st(NE)                 !< Statuses of the wrong calls.
integer(int32)                :: want(NE)               !< ... expected.
character(len=256)            :: msg(NE)                !< Their messages.
logical                       :: y2_format, y1_plain    !< Y2's labels follow its format; Y1's do not.
logical                       :: neg_decade(3)          !< Symlog ticks at -10, -100, -1000 ...
logical                       :: pos_decade(3)          !< ... at 10, 100, 1000 ...
logical                       :: zero_tick              !< ... and at 0.
logical                       :: fixed_ok, fixed_fmt    !< Fixed ticks, with labels and with the format.
integer(int32)                :: frame                  !< Frame counter.
integer(int32)                :: i                      !< Counter.
real(real64)                  :: v                      !< A tick value.
integer(int32)                :: ios                    !< I/O status.
integer(int32)                :: count                  !< Ticks.

x = [(real(i - 1_int32, real64) / real(N - 1_int32, real64) * 100.0_real64, i = 1_int32, N)]
res = 0.5_real64 + 0.5_real64 * cos(x / 7.0_real64)
coef = 3000.0_real64 + 2000.0_real64 * sin(x / 11.0_real64)
signed = 1000.0_real64 * sin(x / 9.0_real64)
ok = .false.
st = -99_int32
msg = ''
y2_format = .true.
y1_plain = .true.
neg_decade = .false.
pos_decade = .false.
zero_tick = .false.
fixed_ok = .false.
fixed_fmt = .false.
nlog = 0_int32
ticks_log = ''
centre = 0.0_real64

call app%init_headless(800_int32, 600_int32)
do frame = 1_int32, 110_int32
   if (.not. app%next_frame()) error stop 'figure_test_plot_axes: next_frame returned false in headless mode'
   call ig_set_next_window(10.0_real64, 10.0_real64, 700.0_real64, 560.0_real64, always=.true.)
   if (ig_begin('Axes')) then
      select case (frame)
      case (1_int32:3_int32)
         call two_axes(frame == 3_int32)
      case (4_int32:6_int32)
         call symlog(frame == 6_int32)
      case (7_int32:9_int32)
         call log_and_ticks(frame == 9_int32)
      case (10_int32:12_int32)
         call legends(frame == 12_int32)
      case (13_int32:15_int32)
         call unused(frame == 15_int32)
      case (16_int32:79_int32)
         call constrained(frame)
      case (80_int32:105_int32)
         call unconstrained(frame)
      case default
         call wrong_calls(frame == 106_int32)
      endselect
   endif
   call ig_end()
   if (frame == 107_int32) call outside_plot()
enddo
call app%destroy()

! 1. each y axis fits its own line, Y1 is not stretched by Y2's data
ok(1) = abs(y2lim(1) - minval(coef)) < 1.0e-6_real64 * 5000.0_real64 .and. &
        abs(y2lim(2) - maxval(coef)) < 1.0e-6_real64 * 5000.0_real64        ! fitted (no padding: ImPlot's default)
ok(2) = abs(y1lim(1) - minval(res)) < 1.0e-6_real64 .and. abs(y1lim(2) - maxval(res)) < 1.0e-6_real64 .and. &
        abs(ctl(2) - maxval(coef)) < 1.0e-6_real64 * 5000.0_real64          ! control: both on Y1 stretch it
ok(3) = y2_format .and. y1_plain
! 2. symlog
ok(4) = all(neg_decade) .and. all(pos_decade) .and. zero_tick
! 3. log synonym, fixed ticks
ok(5) = nlog(1) > 1_int32 .and. nlog(1) == nlog(2) .and. all(ticks_log(1, :) == ticks_log(2, :))
ok(6) = fixed_ok
ok(7) = fixed_fmt
! 4. legend outside
ok(8) = sizes(1, 2) < sizes(1, 1) - 20.0_real64 .and. abs(sizes(2, 2) - sizes(2, 1)) < 1.0_real64
ok(9) = sizes(2, 3) < sizes(2, 1) - 10.0_real64 .and. abs(sizes(1, 3) - sizes(1, 1)) < 1.0_real64
! 5. unused axes: reaching here under -ffpe-trap is the check; the unused axis keeps a finite range
ok(10) = all(ieee_is_finite(y3lim)) .and. y3lim(1) < y3lim(2)
! 6. constraints
ok(11) = wide(1) >= 0.0_real64 .and. wide(2) <= 10.0_real64 .and. wide(2) - wide(1) > 9.0_real64
ok(12) = narrow(2) - narrow(1) >= 1.0_real64 - 1.0e-9_real64 .and. narrow(2) - narrow(1) < 3.0_real64
ok(13) = abs(ylock(1) - 0.0_real64) < 1.0e-12_real64 .and. abs(ylock(2) - 1.0_real64) < 1.0e-12_real64
ok(14) = free_x(1) < -1.0_real64 .and. free_x(2) > 11.0_real64
! 7. wrong calls
want = [FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_ERR_ARGUMENT, &
        FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, &
        FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_ERR_STATE, FIG_ERR_STATE, FIG_ERR_STATE, FIG_ERR_STATE, FIG_ERR_STATE, &
        FIG_ERR_STATE, FIG_OK, FIG_ERR_STATE]
ok(15) = all(st == want)
ok(16) = index(msg(5), "ip_setup_axis_limits: axis 'y2' is not set up") == 1 .and.                          &
         index(msg(14), 'ip_setup_axis: the setup of the plot is over') == 1 .and.                          &
         index(msg(17), 'ip_setup_axis: no plot is being declared') == 1 .and.                              &
         index(msg(3), "ip_setup_axis: scale 'time' on axis 'y1' is refused") == 1 .and.                    &
         index(msg(15), "test_plot_tick: axis 'y3' is not set up") == 1

write(output_unit, '(A,2(ES12.4))') 'Y1 limits                 ', y1lim
write(output_unit, '(A,2(ES12.4))') 'Y2 limits                 ', y2lim
write(output_unit, '(A,2(ES12.4))') 'Y1 limits, both on Y1     ', ctl
write(output_unit, '(A,2(ES12.4))') 'constrained x, zoomed out ', wide
write(output_unit, '(A,2(ES12.4))') 'constrained x, zoomed in  ', narrow
write(output_unit, '(A,2(ES12.4))') 'free x, zoomed out        ', free_x
write(output_unit, '(A,6(F8.1))')   'legend plot areas (w, h)  ', sizes
do i = 1_int32, NE
   if (st(i) /= want(i)) write(output_unit, '(A,I0,A,I0,A,I0,A)') 'wrong call ', i, ': stat ', st(i), ' (want ', &
                                                                    want(i), ') '//trim(msg(i))
enddo
do i = 1_int32, size(ok, kind=int32)
   write(output_unit, '(A,I2,A,L1)') 'check ', i, ': ', ok(i)
enddo
if (.not. all(ok)) error stop 'figure_test_plot_axes: FAILED'
write(output_unit, '(A)') 'figure_test_plot_axes: all checks passed'

contains
   subroutine two_axes(measure)
   !< Phase 1: a residual on Y1, a coefficient on Y2; then the same two lines on Y1 alone (control).
   logical, intent(in) :: measure !< Read the limits and ticks.
   real(real64)        :: d1, d2  !< Unused x limits.

   if (ip_begin_plot('two axes', width=640.0_real64, height=240.0_real64)) then
      call ip_setup_axes('iteration', 'residual')
      call ip_setup_axis('y2', label='C', format='C=%.0f')
      call ip_line('residual', x, res)
      call ip_set_axes('x1', 'y2')
      call ip_line('coefficient', x, coef)
      if (measure) then
         call ip_plot_limits(d1, d2, y1lim(1), y1lim(2), yaxis='y1')
         call ip_plot_limits(d1, d2, y2lim(1), y2lim(2), yaxis='y2')
         call test_plot_tick('y2', 1_int32, label, count)
         y2_format = count > 1_int32
         do i = 1_int32, count
            call test_plot_tick('y2', i, label)
            y2_format = y2_format .and. index(label, 'C=') == 1
         enddo
         call test_plot_tick('y1', 1_int32, label, count)
         y1_plain = count > 1_int32
         do i = 1_int32, count
            call test_plot_tick('y', i, label)
            y1_plain = y1_plain .and. index(label, 'C=') == 0
         enddo
      endif
      call ip_end_plot()
   endif
   if (ip_begin_plot('one axis', width=640.0_real64, height=240.0_real64)) then
      call ip_setup_axes('iteration', 'both')
      call ip_line('residual', x, res)
      call ip_line('coefficient', x, coef)
      if (measure) call ip_plot_limits(d1, d2, ctl(1), ctl(2))
      call ip_end_plot()
   endif
   endsubroutine two_axes

   subroutine symlog(measure)
   !< Phase 2: a signed quantity on a symmetric log axis.
   logical, intent(in) :: measure !< Read the ticks.
   integer(int32)      :: k       !< Decade.

   if (ip_begin_plot('symlog', width=640.0_real64, height=460.0_real64)) then
      call ip_setup_axis('y1', label='signed', scale='symlog')
      call ip_setup_axis_limits('y1', -2000.0_real64, 2000.0_real64, always=.true.)
      call ip_line('signed', x, signed)
      if (measure) then
         call test_plot_tick('y1', 1_int32, label, count)
         do i = 1_int32, count
            call test_plot_tick('y1', i, label)
            read(label, *, iostat=ios) v
            if (ios /= 0_int32) cycle
            do k = 1_int32, 3_int32                                    ! the decades 10, 100, 1000 of both signs
               if (abs(v + 10.0_real64**k) < 1.0e-9_real64) neg_decade(k) = .true.
               if (abs(v - 10.0_real64**k) < 1.0e-9_real64) pos_decade(k) = .true.
            enddo
            if (v == 0.0_real64) zero_tick = .true.
         enddo
      endif
      call ip_end_plot()
   endif
   endsubroutine symlog

   subroutine log_and_ticks(measure)
   !< Phase 3: `ylog` and `yscale='log'`; fixed ticks with labels and with the axis's format.
   logical, intent(in) :: measure !< Read the ticks.
   integer(int32)      :: k       !< Plot.

   do k = 1_int32, 2_int32
      if (ip_begin_plot('log '//achar(48 + k), width=640.0_real64, height=150.0_real64)) then
         if (k == 1_int32) then
            call ip_setup_axes('x', 'y', ylog=.true.)
         else
            call ip_setup_axes('x', 'y', yscale='log')
         endif
         call ip_setup_axes_limits(0.0_real64, 100.0_real64, 1.0e-3_real64, 1.0e3_real64, always=.true.)
         call ip_line('r', x, res + 1.0e-3_real64)
         if (measure) then
            call test_plot_tick('y', 1_int32, label, nlog(k))
            do i = 1_int32, min(nlog(k), 12_int32)
               call test_plot_tick('y', i, label)
               ticks_log(k, i) = label
            enddo
         endif
         call ip_end_plot()
      endif
   enddo
   if (ip_begin_plot('fixed ticks', width=640.0_real64, height=150.0_real64)) then
      call ip_setup_axis('x1', label='level')
      call ip_setup_axis('y1', format='%.1f')
      call ip_setup_axis_ticks('x1', [0.0_real64, 50.0_real64, 100.0_real64], [character(len=6) :: 'low', 'mid', &
                               'high'])
      call ip_setup_axis_ticks('y1', [0.0_real64, 0.5_real64, 1.0_real64])
      call ip_line('r', x, res)
      if (measure) then
         call test_plot_tick('x1', 1_int32, label, count)
         fixed_ok = count == 3_int32 .and. label == 'low'
         call test_plot_tick('x1', 2_int32, label)
         fixed_ok = fixed_ok .and. label == 'mid'
         call test_plot_tick('x1', 3_int32, label)
         fixed_ok = fixed_ok .and. label == 'high'
         call test_plot_tick('y1', 1_int32, label, count)
         fixed_fmt = count == 3_int32 .and. label == '0.0'
         call test_plot_tick('y1', 3_int32, label)
         fixed_fmt = fixed_fmt .and. label == '1.0'
      endif
      call ip_end_plot()
   endif
   endsubroutine log_and_ticks

   subroutine legends(measure)
   !< Phase 4: the legend inside, outside on the east, outside on the north in a row; the plot areas measured.
   logical, intent(in) :: measure !< Read the plot areas.
   integer(int32)      :: k       !< Plot.

   do k = 1_int32, 3_int32
      if (ip_begin_plot('legend '//achar(48 + k), width=640.0_real64, height=160.0_real64)) then
         select case (k)
         case (2_int32)
            call ip_setup_legend('e', outside=.true.)
         case (3_int32)
            call ip_setup_legend('n', outside=.true., horizontal=.true.)
         endselect
         call ip_line('residual history', x, res)
         call ip_line('coefficient history', x, coef / 5000.0_real64)
         if (measure) call ip_plot_size(sizes(1, k), sizes(2, k))
         call ip_end_plot()
      endif
   enddo
   endsubroutine legends

   subroutine unused(measure)
   !< Phase 5: axes set up and not used; an axis set up in a plot with no item; a subplot cell with Y2.
   logical, intent(in) :: measure !< Read the unused axis's range.
   real(real64)        :: d1, d2  !< Unused x limits.

   if (ip_begin_plot('unused axes', width=640.0_real64, height=160.0_real64)) then
      call ip_setup_axis('x2', label='unused x2')
      call ip_setup_axis('y3', label='unused y3')
      call ip_line('residual', x, res)
      if (measure) call ip_plot_limits(d1, d2, y3lim(1), y3lim(2), xaxis='x2', yaxis='y3')
      call ip_end_plot()
   endif
   if (ip_begin_plot('empty', width=640.0_real64, height=120.0_real64)) then
      call ip_setup_axis('y2', label='nothing on it')
      call ip_end_plot()
   endif
   if (ip_begin_subplots('##cells', 1_int32, 2_int32, width=640.0_real64, height=180.0_real64, link_x=.true.)) then
      if (ip_begin_plot('cell 1')) then
         call ip_setup_axis('y2')
         call ip_line('residual', x, res)
         call ip_set_axes('x1', 'y2')
         call ip_line('coefficient', x, coef)
         call ip_end_plot()
      endif
      if (ip_begin_plot('cell 2')) then
         call ip_setup_axis('x2')
         call ip_line('residual', x, res)
         call ip_end_plot()
      endif
      call ip_end_subplots()
   endif
   endsubroutine unused

   subroutine constrained(frame)
   !< Phase 6: x constrained to [0, 10] with a narrowest width of 1, y locked; zoomed out, then in, with the wheel.
   integer(int32), intent(in) :: frame !< Frame.
   real(real64)               :: w, h  !< Plot area [pixels].
   type(im_vec2)              :: pos   !< Its top-left corner [pixels].

   if (ip_begin_plot('constrained', width=640.0_real64, height=460.0_real64)) then
      call ip_setup_axis('x1', label='x')
      call ip_setup_axis('y1', label='y', lock=.true.)
      call ip_setup_axis_limits('x1', 2.0_real64, 8.0_real64)
      call ip_setup_axis_limits('y1', 0.0_real64, 1.0_real64)
      call ip_setup_axis_constraints('x1', vmin=0.0_real64, vmax=10.0_real64, zoom_min=1.0_real64)
      call ip_line('residual', x / 10.0_real64, res)
      call ip_plot_size(w, h)
      pos = ImPlot_GetPlotPos()
      centre = [real(pos%x, real64) + 0.5_real64 * w, real(pos%y, real64) + 0.5_real64 * h]
      if (frame == 48_int32) call ip_plot_limits(wide(1), wide(2), ylock(1), ylock(2))
      if (frame == 79_int32) call ip_plot_limits(narrow(1), narrow(2), ylock(1), ylock(2))
      call ip_end_plot()
   endif
   if (frame == 17_int32) call test_mouse_move(centre(1), centre(2))
   if (frame >= 18_int32 .and. frame < 46_int32) call test_wheel(-1.0_real64)
   if (frame >= 49_int32 .and. frame < 77_int32) call test_wheel(1.0_real64)
   endsubroutine constrained

   subroutine unconstrained(frame)
   !< Phase 6, control: the same plot without constraints, zoomed out by the same wheel.
   integer(int32), intent(in) :: frame  !< Frame.
   real(real64)               :: d1, d2 !< Unused y limits.

   if (ip_begin_plot('free', width=640.0_real64, height=460.0_real64)) then
      call ip_setup_axis_limits('x1', 2.0_real64, 8.0_real64)
      call ip_line('residual', x / 10.0_real64, res)
      if (frame == 105_int32) call ip_plot_limits(free_x(1), free_x(2), d1, d2)
      call ip_end_plot()
   endif
   if (frame == 81_int32) call test_mouse_move(centre(1), centre(2))
   if (frame >= 82_int32 .and. frame < 104_int32) call test_wheel(-1.0_real64)
   endsubroutine unconstrained

   subroutine wrong_calls(now)
   !< Phase 7: wrong calls in a plot, each refused with its status.
   logical, intent(in) :: now !< Make them on this frame.
   real(real64)        :: d(4) !< Unused limits.

   if (ip_begin_plot('wrong', width=640.0_real64, height=300.0_real64)) then
      if (now) then
         call ip_setup_axis('z1', stat=st(1))
         msg(1) = figure_last_error()
         call ip_setup_axis('x2', scale='cubic', stat=st(2))
         msg(2) = figure_last_error()
         call ip_setup_axis('y1', scale='time', stat=st(3))
         msg(3) = figure_last_error()
         call ip_setup_axis('y1', format='%d', stat=st(4))
         msg(4) = figure_last_error()
         call ip_setup_axis_limits('y2', 0.0_real64, 1.0_real64, stat=st(5))
         msg(5) = figure_last_error()
         call ip_setup_axis_limits('y1', 1.0_real64, 1.0_real64, stat=st(6))
         msg(6) = figure_last_error()
         call ip_setup_axis_ticks('x1', [1.0_real64, 2.0_real64], [character(len=2) :: 'a'], stat=st(7))
         msg(7) = figure_last_error()
         call ip_setup_axis_constraints('x1', vmin=2.0_real64, vmax=1.0_real64, stat=st(8))
         msg(8) = figure_last_error()
         call ip_setup_axis_constraints('x1', zoom_min=2.0_real64, zoom_max=1.0_real64, stat=st(9))
         msg(9) = figure_last_error()
         call ip_setup_legend('top', stat=st(10))
         msg(10) = figure_last_error()
         call ip_setup_axes('x', 'y', ylog=.true., yscale='linear', stat=st(11))
         msg(11) = figure_last_error()
         call ip_setup_axes('x', 'y', yscale='time', stat=st(12))
         msg(12) = figure_last_error()
         call ip_setup_axis('y1', scale='log')
         call ip_setup_axis_constraints('y1', vmin=0.0_real64, stat=st(13))
         msg(13) = figure_last_error()
         call ip_line('r', x, res + 0.1_real64)
         call ip_setup_axis('x2', stat=st(14))                       ! after an item: the setup is over
         msg(14) = figure_last_error()
         call test_plot_tick('y3', 1_int32, label, stat=st(15))
         msg(15) = figure_last_error()
         call ip_set_axes('x1', 'y2', stat=st(16))                   ! y2 not set up
         msg(16) = figure_last_error()
         call ip_setup_legend('ne', stat=st(18))                     ! after an item
         msg(18) = figure_last_error()
         call ip_plot_limits(d(1), d(2), d(3), d(4), yaxis='y3', stat=st(19))
         msg(19) = figure_last_error()
         call ip_setup_axes_limits(0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, stat=st(20))
         msg(20) = figure_last_error()
         call ip_set_axes('x1', 'y1', stat=st(21))                   ! fine
         msg(21) = figure_last_error()
      endif
      call ip_end_plot()
   endif
   if (now) then
      call ip_setup_axis('y2', stat=st(17))                          ! outside a plot
      msg(17) = figure_last_error()
   endif
   endsubroutine wrong_calls

   subroutine outside_plot()
   !< Phase 7: calls of a plot made outside any plot.
   real(real64) :: d(4) !< Unused limits.

   call ip_plot_limits(d(1), d(2), d(3), d(4), stat=st(22))
   msg(22) = figure_last_error()
   endsubroutine outside_plot
endprogram figure_test_plot_axes
