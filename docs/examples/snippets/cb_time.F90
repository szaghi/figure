!< cb_time, cookbook: time a piece of work and animate by the clock (figure_time, a monotonic clock).
program cb_time
!< cb_time, cookbook: time a piece of work and animate by the clock (figure_time, a monotonic clock).
!<
!< A step of work timed with figure_time, and a marker that sweeps the window once per second whatever the frame
!< rate: its position comes from the clock, not from a count of frames. `cb_time --check` opens no window: it runs
!< the frames headless and prints facts about the times, not the times themselves (they change with every run).
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, figure_time, ig_begin, ig_end, ig_progress_bar, ig_set_next_window, ig_text

implicit none
type(app_object)  :: app         !< Application.
real(real64)      :: started     !< When the program started [s].
real(real64)      :: step_time   !< The last step's duration [s].
real(real64)      :: phase       !< Where the marker is, in [0, 1).
real(real64)      :: earlier     !< The clock on the frame before [s].
real(real64)      :: total       !< The sum the step computes.
logical           :: ordered     !< The clock never went back from one frame to the next.
character(len=16) :: arg         !< First argument.
character(len=32) :: line        !< A line of text.
logical           :: check       !< --check: headless.
integer(int32)    :: frame       !< Frame counter.

call get_command_argument(1, arg)
check = trim(arg) == '--check'
started = figure_time() ! callable before init: its first call is its origin
if (check) then
   call app%init_headless(420_int32, 140_int32)
else
   call app%init('FIGURE: time', 420_int32, 140_int32)
endif
call app%set_lazy(.false.) ! a frame after another: the marker moves without input
earlier = started
ordered = .true.
frame = 0_int32
do while (app%next_frame())
   frame = frame + 1_int32
   call step(total)
   phase = modulo(figure_time() - started, 1.0_real64) ! once per second, at any frame rate
   if (figure_time() < earlier) ordered = .false.
   earlier = figure_time()
   call ig_set_next_window(10.0_real64, 10.0_real64, 400.0_real64, 120.0_real64)
   if (ig_begin('Clock')) then
      write(line, '(A,F0.3,A)') 'the step took ', 1.0e3_real64 * step_time, ' ms'
      call ig_text(trim(line))
      call ig_progress_bar(phase, label=' ')
   endif
   call ig_end()
   if (check .and. frame == 30_int32) exit
enddo
call app%destroy()
if (check) then
   write(output_unit, '(A,L2)') 'the clock never went back over 30 frames:', ordered
   write(output_unit, '(A,L2)') 'a step takes more than 0 s:', step_time > 0.0_real64
   write(output_unit, '(A,L2)') 'the marker is in [0, 1):', phase >= 0.0_real64 .and. phase < 1.0_real64
   write(output_unit, '(A,L2)') 'the sum is right:', abs(total - 500000500000.0_real64) < 1.0_real64
endif

contains
   subroutine step(total)
   !< A step of work, timed.
   real(real64), intent(out) :: total !< The sum of 1 to 10^6.
   real(real64)              :: t0    !< Before the step [s].
   integer(int32)            :: k     !< Counter.

   t0 = figure_time()
   total = 0.0_real64
   do k = 1_int32, 1000000_int32 ! the work
      total = total + real(k, real64)
   enddo
   step_time = figure_time() - t0 ! seconds, on a clock the system does not step
   endsubroutine step
endprogram cb_time
