!< figure_test_headless, widgets and plots driven by synthetic input, without a window or a GPU.
program figure_test_headless
!< figure_test_headless, widgets and plots driven by synthetic input, without a window or a GPU.
!<
!< A button is clicked by queuing mouse states frame by frame (hover, press, release), exactly as real input arrives;
!< a check box is toggled the same way; a plot is drawn from Fortran arrays. Needs no display, so it runs in CI as is.
use, intrinsic :: iso_c_binding, only : c_float, c_int
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_button, ig_checkbox, ig_end, ig_item_rect, ig_set_next_window, ip_begin_plot, &
                   ip_end_plot, ip_line, ip_setup_axes
use figure_c_native, only : fig_input_mouse

implicit none
type(app_object) :: app            !< Application.
integer(int32)   :: frame          !< Frame counter.
integer(int32)   :: clicks         !< Button clicks seen.
integer(int32)   :: toggles        !< Check box toggles seen.
logical          :: flag           !< Check box value.
real(real64)     :: bx(2), by(2)   !< Button center, check box center [pixels].
real(real64)     :: x0, y0, x1, y1 !< Item rectangle.
real(real64)     :: x(100), y(100) !< Plot data.
integer(int32)   :: i              !< Counter.
logical          :: failed         !< Some check failed.

x = [(real(i, real64) / 10._real64, i = 1, 100)]
y = sin(x)
clicks = 0_int32
toggles = 0_int32
flag = .false.
failed = .false.
call app%init_headless(800_int32, 600_int32)

do frame = 1_int32, 12_int32
   if (.not. app%next_frame()) error stop 'next_frame returned false in headless mode'
   call ig_set_next_window(20._real64, 20._real64, 400._real64, 500._real64, always=.true.)
   if (ig_begin('Test')) then
      if (ig_button('Hit me')) clicks = clicks + 1_int32
      call ig_item_rect(x0, y0, x1, y1)
      bx = [0.5_real64 * (x0 + x1), 0.5_real64 * (y0 + y1)]
      if (ig_checkbox('Flag', flag)) toggles = toggles + 1_int32
      call ig_item_rect(x0, y0, x1, y1)
      by = [x0 + 8._real64, 0.5_real64 * (y0 + y1)]
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

call check(clicks == 1_int32, 'button clicked once', clicks)
call check(toggles == 1_int32, 'check box toggled once', toggles)
call check(flag, 'check box value is true', merge(1_int32, 0_int32, flag))
if (failed) error stop 'figure_test_headless: FAILED'
print '(A)', 'figure_test_headless: PASSED'

contains
   subroutine check(ok, what, got)
   !< Report one check.
   logical,          intent(in) :: ok   !< Check passed.
   character(len=*), intent(in) :: what !< Description.
   integer(int32),   intent(in) :: got  !< Observed value.

   if (ok) then
      print '(A)', '  ok    '//what
   else
      print '(A,I0)', '  FAIL  '//what//', got ', got
      failed = .true.
   endif
   endsubroutine check
endprogram figure_test_headless
