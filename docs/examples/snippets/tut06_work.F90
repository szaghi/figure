!< tut06_work_task, tutorial chapter 6: the work run as a task (a module procedure: it runs on a worker thread).
module tut06_work_task
!< tut06_work_task, tutorial chapter 6: the work run as a task (a module procedure: it runs on a worker thread).
use, intrinsic :: iso_fortran_env, only : real64
use figure, only : task_handle_object

implicit none
private
public :: field_t, smooth_field

type :: field_t
   !< A field of values, given to the task and given back smoothed.
   real(real64), allocatable :: v(:) !< Values.
endtype field_t

contains
   recursive subroutine smooth_field(h, data)
   !< Smooth the field 200 times, reporting each pass.
   type(task_handle_object), intent(inout) :: h    !< The task's handle.
   class(*),                 intent(inout) :: data !< A field_t.
   integer                                 :: pass !< Pass.
   integer                                 :: n    !< Values.

   select type (data)
   type is (field_t)
      n = size(data%v)
      do pass = 1, 200
         if (h%cancelled()) return                         ! a safe point, between two passes
         data%v(2:n - 1) = 0.25_real64 * (data%v(1:n - 2) + 2.0_real64 * data%v(2:n - 1) + data%v(3:n))
         call h%report(real(pass, real64) / 200.0_real64, 'smoothing')
      enddo
   endselect
   endsubroutine smooth_field
endmodule tut06_work_task

!< tut06_work, tutorial chapter 6: running work without freezing the window.
program tut06_work
!< tut06_work, tutorial chapter 6: running work without freezing the window.
!<
!< A tool started from a button, its output in a log view; a computation of the program run as a task, with its
!< progress in a progress bar and its end in a notification. The tool is this program itself, started again with
!< `--tool`, so that the tutorial runs on every system.
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object, ig_begin, ig_begin_disabled, ig_button, ig_end, ig_end_disabled, ig_same_line, &
                   ig_progress_bar, ig_set_next_window, ig_text, log_view_object, process_object, task_object
use tut06_work_task, only : field_t, smooth_field

implicit none
type(app_object)              :: app      !< Application.
type(process_object)          :: tool     !< The tool.
type(log_view_object)         :: output   !< What it prints.
type(task_object)             :: smoother !< The computation.
type(field_t)                 :: field    !< Its field.
class(*), allocatable         :: data     !< The field given back.
character(len=:), allocatable :: lines(:) !< New lines.
character(len=:), allocatable :: msg      !< Progress message.
character(len=512)            :: me       !< This program.
character(len=16)             :: arg      !< Its first argument.
character(len=48)             :: status   !< The task's status line.
real(real64)                  :: fraction !< Progress.
integer                       :: i        !< Counter.
logical                       :: started  !< The tool was started.

call get_command_argument(0, me)
call get_command_argument(1, arg)
if (trim(arg) == '--tool') then
   call grid_check()
   stop
endif
started = .false.
status = 'not smoothed yet'
field%v = [(merge(1.0_real64, 0.0_real64, mod(i, 1000) < 500), i = 1, 200000)] ! a square wave
call app%init('FIGURE: running work', 640_int32, 400_int32)
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 620.0_real64, 380.0_real64)
   if (ig_begin('Work')) then
      call ig_begin_disabled(smoother%running())
      if (ig_button('Smooth the field')) call smoother%start(smooth_field, field) ! a copy of field goes to the task
      call ig_end_disabled()
      call ig_same_line()
      if (smoother%running()) then
         call smoother%progress(fraction, msg)
         call ig_progress_bar(fraction, label=msg, width=300.0_real64) ! fraction < 0 before the first report
      else
         if (smoother%done()) then
            call smoother%result(data)                     ! given back without a copy
            select type (data)
            type is (field_t)
               call move_alloc(data%v, field%v)
            endselect
            write(status, '(A,F6.4)') 'smoothed: value 500 is ', field%v(500)
            call app%notify('The field is smoothed', kind='success') ! seen even if the user looks elsewhere
         endif
         call ig_text(trim(status))
      endif
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
