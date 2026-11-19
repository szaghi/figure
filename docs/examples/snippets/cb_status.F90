!< cb_status, cookbook: a status bar with a progress bar, and notifications when a run ends or a check fails.
program cb_status
!< cb_status, cookbook: a status bar with a progress bar, and notifications when a run ends or a check fails.
!<
!< The run is advanced one iteration per frame, as chapter 4 of the tutorial does: a real program polls a process or
!< a task (Processes and tasks). `cb_status --check` opens no window: the run starts at once, and at its end the
!< program prints where the notification is shown.
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object, ICON_PLAY, ICON_LIST_CHECKS, ig_begin, ig_begin_disabled, ig_begin_side_bar,     &
                   ig_button, ig_end, ig_end_disabled, ig_progress_bar, ig_same_line, ig_set_next_window, ig_text, &
                   ig_text_disabled
use figure_testing, only : test_notification_rect

implicit none
integer(int32), parameter :: ITERATIONS = 240_int32 !< Iterations of the run.
type(app_object)          :: app       !< Application.
integer(int32)            :: iteration !< Iterations done.
logical                   :: running   !< The run is going.
real(real64)              :: residual  !< The run's residual.
character(len=64)         :: line      !< A formatted line.
character(len=16)         :: arg       !< First argument.
logical                   :: check     !< --check: headless, the run started at once.
logical                   :: shown     !< A notification is shown (--check).
real(real64)              :: r(4)      !< Its rectangle [pixels].
real(real64)              :: alpha     !< Its largest alpha, 1 while shown in full.
integer(int32)            :: after     !< Frames after the run's end (--check).

iteration = 0_int32
running = .false.
residual = 1.0_real64
after = 0_int32
call get_command_argument(1, arg)
check = trim(arg) == '--check'
if (check) then
   call app%init_headless(720_int32, 400_int32)
   running = .true.
else
   call app%init('FIGURE: a status bar and notifications', 720_int32, 400_int32)
endif
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
   if (check .and. iteration == ITERATIONS) then
      after = after + 1_int32
      if (after == 10_int32) then
         call test_notification_rect(1_int32, r(1), r(2), r(3), r(4), found=shown, alpha=alpha) ! the newest
         write(output_unit, '(A,L1,A,F3.1,A,L1)') 'notification shown: ', shown, ', alpha ', alpha, &
                                                  ', in the bottom right quarter: ', r(1) > 360.0_real64 .and. r(2) > 200.0_real64
         exit
      endif
   endif
enddo
call app%destroy()
endprogram cb_status
