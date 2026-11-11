!< cb_golden, cookbook: test what a window looks like, headless, against a committed picture (a golden).
module cb_golden_ui
!< cb_golden_ui, the window cb_golden tests: a few settings and a clock.
use, intrinsic :: iso_fortran_env, only : real64
use figure, only : figure_time, ig_begin, ig_button, ig_checkbox, ig_end, ig_item_rect, ig_set_next_window, ig_slider, &
                   ig_text

implicit none
private
public :: settings, draw

type :: settings
   !< What the window edits.
   real(real64) :: omega = 1.8_real64  !< Relaxation factor.
   logical      :: implicit = .true.   !< Implicit time stepping.
   real(real64) :: clock(4) = 0.0_real64 !< The clock's rectangle [pixels]: drawn from the wall time.
endtype settings

contains
   subroutine draw(s)
   !< The window, one frame of it: the same procedure in the application and in its test.
   type(settings), intent(inout) :: s !< State.
   character(len=32)             :: t !< The clock's text.

   call ig_set_next_window(10.0_real64, 10.0_real64, 300.0_real64, 140.0_real64, always=.true.)
   if (ig_begin('Solver')) then
      if (ig_slider('omega', s%omega, 1.0_real64, 2.0_real64)) continue
      if (ig_checkbox('implicit', s%implicit)) continue
      if (ig_button('Run')) continue
      write(t, '(A,I0,A)') 'up ', nint(1000.0_real64 * figure_time()), ' ms'
      call ig_text(trim(t))                                ! not the same in two runs
      call ig_item_rect(s%clock(1), s%clock(2), s%clock(3), s%clock(4))
   endif
   call ig_end()
   endsubroutine draw
endmodule cb_golden_ui

program cb_golden
!< cb_golden, cookbook: test what a window looks like, headless, against a committed picture (a golden).
use, intrinsic :: iso_fortran_env, only : int32, int64, output_unit, real64
use figure, only : app_object, figure_last_error
use figure_testing, only : test_capture, test_compare_image, test_run
use cb_golden_ui, only : draw, settings

implicit none
type(app_object)   :: app    !< Application.
type(settings)     :: s      !< The window's state.
character(len=256) :: golden !< The committed picture.
real(real64)       :: masks(4, 1) !< What the comparison leaves out [pixels].
integer(int64)     :: failed !< Pixels that failed.
logical            :: same   !< The picture matches.

call get_command_argument(1, golden)
call app%init_headless(320_int32, 160_int32)
call settle()
call test_capture('solver.png')             ! the whole frame, written when it is rendered
if (app%next_frame()) call draw(s)          ! ... now
masks(:, 1) = [s%clock(1), s%clock(2), s%clock(1) + 200.0_real64, s%clock(4)] ! the clock's line: not deterministic
same = test_compare_image('solver.png', trim(golden), masks=masks)
write(output_unit, '(A,L1)') 'the window looks as committed: ', same
s%omega = 1.2_real64                        ! a change that shows: the slider's grab moves
call settle()
call test_capture('changed.png')
if (app%next_frame()) call draw(s)
same = test_compare_image('changed.png', 'solver.png', masks=masks, failed=failed)
write(output_unit, '(A,L1,A,I0,A)') 'after the change: ', same, ' (', failed, ' pixels)'
write(output_unit, '(A)') figure_last_error()
call app%destroy()

contains
   subroutine settle()
   !< Draw frames until the interface is idle (at most 60).
   do while (test_run(60_int32))
      if (.not. app%next_frame()) exit
      call draw(s)
   enddo
   endsubroutine settle
endprogram cb_golden
