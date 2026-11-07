!< cb_status, cookbook: a status bar with a progress bar, and notifications when a run ends or a check fails.
program cb_status
!< cb_status, cookbook: a status bar with a progress bar, and notifications when a run ends or a check fails.
!<
!< The run is advanced one iteration per frame, as chapter 4 of the tutorial does: a real program polls a process or
!< a task (Processes and tasks).
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ICON_PLAY, ICON_LIST_CHECKS, ig_begin, ig_begin_disabled, ig_begin_side_bar,     &
                   ig_button, ig_end, ig_end_disabled, ig_progress_bar, ig_same_line, ig_set_next_window, ig_text, &
                   ig_text_disabled

implicit none
integer(int32), parameter :: ITERATIONS = 240_int32 !< Iterations of the run.
type(app_object)          :: app       !< Application.
integer(int32)            :: iteration !< Iterations done.
logical                   :: running   !< The run is going.
real(real64)              :: residual  !< The run's residual.
character(len=64)         :: line      !< A formatted line.

iteration = 0_int32
running = .false.
residual = 1.0_real64
call app%init('FIGURE: a status bar and notifications', 720_int32, 400_int32)
do while (app%next_frame())
   if (running) then                                    ! one iteration per frame
      iteration = iteration + 1_int32
      residual = residual * 0.935_real64
      call app%request_frames(1_int32)                   ! keep drawing while it runs (lazy redraw)
      if (iteration == ITERATIONS) then
         running = .false.
         write(line, '(A,I0,A,ES8.2)') 'Run finished: ', ITERATIONS, ' iterations, residual ', residual
         call app%notify(trim(line), kind='success')     ! the user may be looking elsewhere
      endif
   endif
   if (ig_begin_side_bar('status', 'bottom', 30.0_real64)) then ! the status bar: a bar along the bottom
      if (running) then
         write(line, '(A,I0,A,I0)') 'running: iteration ', iteration, ' of ', ITERATIONS
         call ig_text(trim(line))
         call ig_same_line(offset=260.0_real64)
         call ig_progress_bar(real(iteration, real64) / real(ITERATIONS, real64), width=200.0_real64)
      elseif (iteration == ITERATIONS) then
         write(line, '(A,ES8.2)') 'done, residual ', residual
         call ig_text(trim(line))
      else
         call ig_text_disabled('ready')
      endif
   endif
   call ig_end()
   call ig_set_next_window(10.0_real64, 10.0_real64, 300.0_real64, 120.0_real64)
   if (ig_begin('Case')) then
      call ig_begin_disabled(running)
      if (ig_button(ICON_PLAY//' Run')) then
         iteration = 0_int32
         residual = 1.0_real64
         running = .true.
      endif
      call ig_end_disabled()
      call ig_same_line()
      if (ig_button(ICON_LIST_CHECKS//' Check input')) &
         call app%notify('levels is 0: it must be at least 1', kind='warning', seconds=8.0_real64)
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_status
