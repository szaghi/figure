!< cb_process, cookbook: run a tool from a button, show its output in a log view, stop it, read its exit code.
program cb_process
!< cb_process, cookbook: run a tool from a button, show its output in a log view, stop it, read its exit code.
!<
!< The tool is this program itself, started again with `--tool`, so that the example runs on every system; a real
!< program starts its own tool, `['sbatch', 'case.sh']` or `['overset', '-i', 'grid.inp']`.
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object, ICON_PLAY, ICON_SQUARE, ig_begin, ig_begin_disabled, ig_button, ig_end,             &
                   ig_end_disabled, ig_same_line, ig_set_next_window, ig_text, ig_text_disabled, log_view_object, &
                   process_object

implicit none
type(app_object)              :: app      !< Application.
type(process_object)          :: tool     !< The tool's process.
type(log_view_object)         :: output   !< Its output.
character(len=:), allocatable :: lines(:) !< Lines since the last poll.
character(len=512)            :: me       !< This program.
character(len=16)             :: arg      !< Its first argument.
character(len=64)             :: status   !< The status line.
logical                       :: started  !< The tool was started.

call get_command_argument(0, me)
call get_command_argument(1, arg)
if (trim(arg) == '--tool') then
   call run_tool()
   stop
endif
started = .false.
call app%init('FIGURE: run a tool', 720_int32, 420_int32)
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 700.0_real64, 400.0_real64)
   if (ig_begin('Tool')) then
      !region run
      call ig_begin_disabled(tool%running())                   ! one run at a time
      if (ig_button(ICON_PLAY//' Run')) then
         call output%clear()
         call tool%start([character(len=512) :: me, '--tool'])  ! the program and its arguments: no shell
         started = .true.
      endif
      call ig_end_disabled()
      call ig_same_line()
      call ig_begin_disabled(.not. tool%running())
      if (ig_button(ICON_SQUARE//' Stop')) call tool%kill()
      call ig_end_disabled()
      call ig_same_line()
      if (started) then
         call tool%poll(lines)                                 ! the complete lines since the last frame
         call output%add(lines)
         if (tool%running()) then
            write(status, '(A,I0)') 'running, pid ', tool%pid()
         elseif (tool%killed()) then
            status = 'stopped'
         else
            write(status, '(A,I0)') 'ended, exit code ', tool%exit_code()
         endif
         call ig_text(trim(status))
      else
         call ig_text_disabled('not started')
      endif
      call output%draw('output')                               ! only the lines in view; follows the end
      !endregion run
   endif
   call ig_end()
enddo
call app%destroy()                                             ! a tool still running is stopped here

contains
   subroutine run_tool()
   !< The tool: a solver's log, 120 iterations of a residual.
   integer(int32) :: k        !< Iteration.
   real(real64)   :: residual !< Residual.

   write(output_unit, '(A)') 'xall 3.1: case wing-body, 4 blocks, 1572864 cells'
   residual = 1.0_real64
   do k = 1_int32, 120_int32
      residual = residual * 0.89_real64
      write(output_unit, '(A,I4,A,ES10.3)') 'iteration ', k, '   residual ', residual
   enddo
   write(output_unit, '(A)') 'converged: residual below 1.0E-06'
   flush(output_unit)
   endsubroutine run_tool
endprogram cb_process
