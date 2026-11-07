!< tut06_work, tutorial chapter 6: running work without freezing the window.
program tut06_work
!< tut06_work, tutorial chapter 6: running work without freezing the window.
!<
!< A tool started from a button, its output in a log view. The tool is this program itself, started again with
!< `--tool`, so that the tutorial runs on every system.
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object, ig_begin, ig_begin_disabled, ig_button, ig_end, ig_end_disabled, ig_set_next_window, &
                   log_view_object, process_object

implicit none
type(app_object)              :: app      !< Application.
type(process_object)          :: tool     !< The tool.
type(log_view_object)         :: output   !< What it prints.
character(len=:), allocatable :: lines(:) !< New lines.
character(len=512)            :: me       !< This program.
character(len=16)             :: arg      !< Its first argument.
logical                       :: started  !< The tool was started.

call get_command_argument(0, me)
call get_command_argument(1, arg)
if (trim(arg) == '--tool') then
   call grid_check()
   stop
endif
started = .false.
call app%init('FIGURE: running work', 640_int32, 360_int32)
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 620.0_real64, 340.0_real64)
   if (ig_begin('Work')) then
      call ig_begin_disabled(tool%running())
      if (ig_button('Check the grid')) then
         call tool%start([character(len=512) :: me, '--tool'])
         started = .true.
      endif
      call ig_end_disabled()
      if (started) then
         call tool%poll(lines)
         call output%add(lines)
      endif
      call output%draw('output')
   endif
   call ig_end()
enddo
call app%destroy()

contains
   subroutine grid_check()
   !< The tool: a check of the blocks of a grid.
   integer(int32) :: b !< Block.

   do b = 1_int32, 24_int32
      write(output_unit, '(A,I0,A,I0,A)') 'block ', b, ': ', 32768_int32 * (1_int32 + mod(b, 3_int32)), &
                                          ' cells, Jacobian positive'
   enddo
   write(output_unit, '(A)') 'grid check: 24 blocks, no error'
   flush(output_unit)
   endsubroutine grid_check
endprogram tut06_work
