!< figure_test_headless, widgets and plots driven by synthetic input, without a window or a GPU.
program figure_test_headless
!< figure_test_headless, widgets and plots driven by synthetic input, without a window or a GPU.
!<
!< A button is clicked by queuing mouse states frame by frame (hover, press, release), exactly as real input arrives;
!< a check box is toggled the same way; a plot is drawn from Fortran arrays. Needs no display, so it runs in CI as is.
use, intrinsic :: iso_c_binding, only : c_float, c_int
use, intrinsic :: iso_fortran_env, only : error_unit, int32, output_unit, real64
use figure, only : app_object, ig_begin, ig_button, ig_checkbox, ig_end, ig_item_rect, ig_set_next_window, ip_begin_plot, &
                   ip_end_plot, ip_line, ip_setup_axes
use figure_c_native, only : fig_input_mouse

implicit none
integer(int32), parameter :: N = 100_int32  !< Plot points.
type(app_object)          :: app            !< Application.
integer(int32)            :: frame          !< Frame counter.
integer(int32)            :: clicks         !< Button clicks seen.
integer(int32)            :: toggles        !< Check box toggles seen.
logical                   :: flag           !< Check box value.
real(real64)              :: bx(2)          !< Button center [pixels].
real(real64)              :: by(2)          !< Check box center [pixels].
real(real64)              :: x0             !< Item rectangle, left [pixels].
real(real64)              :: y0             !< Item rectangle, top [pixels].
real(real64)              :: x1             !< Item rectangle, right [pixels].
real(real64)              :: y1             !< Item rectangle, bottom [pixels].
real(real64)              :: x(N)           !< Plot abscissae.
real(real64)              :: y(N)           !< Plot ordinates.
logical                   :: test_passed(3) !< Per-check outcome.
integer(int32)            :: i              !< Counter.

x = [(real(i, real64) / 10.0_real64, i = 1_int32, N)]
y = sin(x)
clicks = 0_int32
toggles = 0_int32
flag = .false.
bx = 0.0_real64
by = 0.0_real64
test_passed = .false.
call app%init_headless(800_int32, 600_int32)

do frame = 1_int32, 12_int32
   if (.not. app%next_frame()) error stop 'figure_test_headless: next_frame returned false in headless mode'
   call ig_set_next_window(20.0_real64, 20.0_real64, 400.0_real64, 500.0_real64, always=.true.)
   if (ig_begin('Test')) then
      if (ig_button('Hit me')) clicks = clicks + 1_int32
      call ig_item_rect(x0, y0, x1, y1)
      bx = [0.5_real64 * (x0 + x1), 0.5_real64 * (y0 + y1)]
      if (ig_checkbox('Flag', flag)) toggles = toggles + 1_int32
      call ig_item_rect(x0, y0, x1, y1)
      by = [x0 + 8.0_real64, 0.5_real64 * (y0 + y1)]
      if (ip_begin_plot('sine')) then
         call ip_setup_axes('x', 'sin(x)')
         call ip_line('sin', x, y)
         call ip_end_plot()
      endif
   endif
   call ig_end()
   ! input for the next frames: frames 2-4 click the button (hover, press, release), 6-8 the check box
   select case (frame)
   case (1_int32, 2_int32)
      call fig_input_mouse(real(bx(1), c_float), real(bx(2), c_float), 0_c_int)
   case (3_int32)
      call fig_input_mouse(real(bx(1), c_float), real(bx(2), c_float), 1_c_int)
   case (4_int32)
      call fig_input_mouse(real(bx(1), c_float), real(bx(2), c_float), 0_c_int)
   case (5_int32, 6_int32)
      call fig_input_mouse(real(by(1), c_float), real(by(2), c_float), 0_c_int)
   case (7_int32)
      call fig_input_mouse(real(by(1), c_float), real(by(2), c_float), 1_c_int)
   case (8_int32)
      call fig_input_mouse(real(by(1), c_float), real(by(2), c_float), 0_c_int)
   endselect
enddo
call app%destroy()

test_passed(1) = clicks == 1_int32   ! button clicked once
test_passed(2) = toggles == 1_int32  ! check box toggled once
test_passed(3) = flag                ! check box value is true

write(output_unit, '(A,3L2)') 'figure_test_headless checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) then
   write(error_unit, '(A,I0,A,I0,A,L1)') 'clicks: ', clicks, ', toggles: ', toggles, ', flag: ', flag
   error stop 1
endif
endprogram figure_test_headless
