!< tut04_live, tutorial chapter 4: a computation that advances while the UI stays responsive.
program tut04_live
!< tut04_live, tutorial chapter 4: a computation that advances while the UI stays responsive.
!<
!< Jacobi iterations for -u'' = 0 on (0, 1), u(0) = 0, u(1) = 1: a few iterations per frame, the solution and the
!< residual history plotted as they evolve.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_button, ig_checkbox, ig_end, ig_same_line, ig_set_next_window, &
                   ig_slider, ig_text, ip_begin_plot, ip_end_plot, ip_line, ip_setup_axes

implicit none
integer(int32), parameter :: N = 64_int32          !< Interior points.
integer(int32), parameter :: MAX_ITER = 50000_int32 !< Iterations kept in the history.
real(real64),   parameter :: TOLERANCE = 1.0e-10_real64 !< Convergence threshold on the update.
type(app_object)          :: app                   !< Application.
real(real64)              :: x(0:N+1)              !< Grid.
real(real64)              :: u(0:N+1)              !< Solution.
real(real64)              :: iterations(MAX_ITER)  !< Iteration numbers.
real(real64)              :: residual(MAX_ITER)    !< log10 of the largest update, per iteration.
integer(int32)            :: iter                  !< Iterations done.
integer(int32)            :: steps                 !< Iterations per frame.
logical                   :: running               !< Iterating.
character(len=64)         :: line                  !< Text buffer.
integer(int32)            :: i                     !< Counter.

x = [(real(i, real64) / real(N + 1, real64), i = 0_int32, N + 1_int32)]
call restart()
steps = 20_int32

call app%init('FIGURE: live', 1000_int32, 700_int32)
do while (app%next_frame())
   if (running) then
      do i = 1_int32, steps
         call jacobi_step()
         if (.not. running) exit
      enddo
      call app%request_frames(1_int32) ! draw the next frame without waiting for input
   endif

   call ig_set_next_window(20.0_real64, 20.0_real64, 960.0_real64, 660.0_real64)
   if (ig_begin('Jacobi')) then
      if (ig_checkbox('running', running)) continue
      call ig_same_line()
      if (ig_button('Restart')) call restart()
      if (ig_slider('iterations per frame', steps, 1_int32, 500_int32)) continue
      write(line, '(A,I0)') 'iterations: ', iter
      call ig_text(trim(line))
      if (ip_begin_plot('Solution', height=250.0_real64)) then
         call ip_setup_axes('x', 'u')
         call ip_line('u', x, u)
         call ip_end_plot()
      endif
      if (ip_begin_plot('Convergence', height=250.0_real64)) then
         call ip_setup_axes('iteration', 'log10 max |update|', auto_fit=.true.)
         call ip_line('Jacobi', iterations(1:iter), residual(1:iter))
         call ip_end_plot()
      endif
   endif
   call ig_end()
enddo
call app%destroy()

contains
   subroutine restart()
   !< Initial guess, empty history.
   u = 0.0_real64
   u(N+1) = 1.0_real64
   iter = 0_int32
   running = .false.
   endsubroutine restart

   subroutine jacobi_step()
   !< One Jacobi iteration; stop at convergence or when the history is full.
   real(real64) :: v(1:N) !< New interior values.

   if (iter == MAX_ITER) then
      running = .false.
      return
   endif
   v = 0.5_real64 * (u(0:N-1) + u(2:N+1))
   iter = iter + 1_int32
   iterations(iter) = real(iter, real64)
   residual(iter) = log10(max(maxval(abs(v - u(1:N))), tiny(1.0_real64)))
   u(1:N) = v
   if (residual(iter) < log10(TOLERANCE) .or. iter == MAX_ITER) running = .false.
   endsubroutine jacobi_step
endprogram tut04_live
