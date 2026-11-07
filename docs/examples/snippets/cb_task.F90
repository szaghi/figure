!< cb_task_work, the work of cb_task: a field read from a binary file in blocks (a module procedure: it runs on a
!< worker thread).
module cb_task_work
!< cb_task_work, the work of cb_task: a field read from a binary file in blocks (a module procedure: it runs on a
!< worker thread).
use, intrinsic :: iso_fortran_env, only : int64, real64
use figure, only : task_handle_object

implicit none
private
public :: field_stats, read_field

type :: field_stats
   !< What the task is given (the file) and what it gives back (the statistics).
   character(len=256) :: file = ''                 !< The field's file: real64 values, stream access.
   integer(int64)     :: values = 0_int64          !< Values read.
   real(real64)       :: vmin = huge(1.0_real64)   !< Smallest value.
   real(real64)       :: vmax = -huge(1.0_real64)  !< Largest value.
   real(real64)       :: mean = 0.0_real64         !< Mean value.
endtype field_stats

contains
   subroutine read_field(h, data)
   !< Read the field block by block: report the progress after each block, stop at a cancel.
   type(task_handle_object), intent(inout) :: h          !< The task's handle.
   class(*),                 intent(inout) :: data       !< A field_stats.
   integer(int64), parameter               :: BLOCK = 65536_int64 !< Values per block.
   real(real64)                            :: chunk(BLOCK) !< One block.
   integer(int64)                          :: bytes, n, k, blocks, m !< File size, values, block, blocks, values in it.
   integer                                 :: u, ios     !< Unit, I/O status.
   character(len=40)                       :: msg        !< Progress message.
   real(real64)                            :: total      !< Sum of the values.

   select type (data)
   type is (field_stats)
      open(newunit=u, file=trim(data%file), access='stream', form='unformatted', action='read', status='old', &
           iostat=ios)                                     ! a unit of its own: never shared with the main thread
      if (ios /= 0) then
         call h%fail('cannot open '//trim(data%file))
         return
      endif
      inquire(unit=u, size=bytes)
      n = bytes / 8_int64
      blocks = (n + BLOCK - 1_int64) / BLOCK
      total = 0.0_real64
      do k = 1_int64, blocks
         if (h%cancelled()) exit                           ! a safe point: the statistics so far are consistent
         m = min(BLOCK, n - (k - 1_int64) * BLOCK)
         read(u, iostat=ios) chunk(1:m)
         if (ios /= 0) then
            call h%fail('cannot read '//trim(data%file))
            exit
         endif
         data%values = data%values + m
         data%vmin = min(data%vmin, minval(chunk(1:m)))
         data%vmax = max(data%vmax, maxval(chunk(1:m)))
         total = total + sum(chunk(1:m))
         write(msg, '(A,I0,A,I0)') 'block ', k, ' of ', blocks
         call h%report(real(k, real64) / real(blocks, real64), trim(msg))
         call slow_disk()
      enddo
      close(u)
      if (data%values > 0_int64) data%mean = total / real(data%values, real64)
   endselect
   endsubroutine read_field

   subroutine slow_disk()
   !< 5 ms per block: the example's file is small, a real one is not.
   integer(int64) :: t0, t, rate !< Clock.

   call system_clock(t0, rate)
   do
      call system_clock(t)
      if (real(t - t0, real64) >= 0.005_real64 * real(rate, real64)) exit
   enddo
   endsubroutine slow_disk
endmodule cb_task_work

!< cb_task, cookbook: read a large file on a worker thread, with its progress, a cancel button and its result.
program cb_task
!< cb_task, cookbook: read a large file on a worker thread, with its progress, a cancel button and its result.
use, intrinsic :: iso_fortran_env, only : int32, int64, real64
use figure, only : app_object, ICON_FOLDER_OPEN, ICON_X, ig_begin, ig_begin_disabled, ig_button, ig_end,         &
                   ig_end_disabled, ig_same_line, ig_separator, ig_set_next_window, ig_text, ig_text_disabled, &
                   task_object
use cb_task_work, only : field_stats, read_field

implicit none
character(len=*), parameter   :: FILE = 'cb_task.field' !< The field's file, written at start.
type(app_object)              :: app      !< Application.
type(task_object)             :: reader   !< The task.
type(field_stats)             :: stats    !< The last result.
class(*), allocatable         :: data     !< The task's data, given back.
character(len=:), allocatable :: msg      !< Progress message.
character(len=80)             :: line     !< A formatted line.
real(real64)                  :: fraction !< Progress.
logical                       :: have     !< A result is shown.

call write_field()
have = .false.
call app%init('FIGURE: read a large file', 560_int32, 240_int32)
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 540.0_real64, 220.0_real64)
   if (ig_begin('Field')) then
      call ig_begin_disabled(reader%running())
      if (ig_button(ICON_FOLDER_OPEN//' Read')) call reader%start(read_field, field_stats(file=FILE))
      call ig_end_disabled()
      call ig_same_line()
      call ig_begin_disabled(.not. reader%running())
      if (ig_button(ICON_X//' Cancel')) call reader%cancel()  ! the task stops at its next block
      call ig_end_disabled()
      if (reader%running()) then
         call reader%progress(fraction, msg)
         write(line, '(F5.1,A,A)') 100.0_real64 * max(fraction, 0.0_real64), ' %  ', msg
         call ig_text(trim(line))
      elseif (reader%done()) then                           ! ended: take the result once
         call reader%result(data)
         select type (data)
         type is (field_stats)
            stats = data
            have = .true.
         endselect
      endif
      call ig_separator()
      if (have) then
         write(line, '(A,I0,A)') 'values ', stats%values, ' read'
         call ig_text(trim(line))
         write(line, '(A,F8.4,A,F8.4,A,F8.4)') 'min ', stats%vmin, '   max ', stats%vmax, '   mean ', stats%mean
         call ig_text(trim(line))
      else
         call ig_text_disabled('no field read yet')
      endif
   endif
   call ig_end()
enddo
call app%destroy()                                          ! a task still running is asked to stop and waited for
call delete_field()

contains
   subroutine write_field()
   !< The field: 2^21 values of a smooth function (16 MiB), as a solver would write it.
   integer(int64), parameter :: N = 2097152_int64 !< Values.
   real(real64), allocatable :: v(:)              !< Values.
   integer(int64)            :: i                 !< Counter.
   integer                   :: u                 !< Unit.

   allocate(v(N))
   do i = 1_int64, N
      v(i) = sin(real(i, real64) * 1.0e-5_real64) * exp(-real(i, real64) * 5.0e-7_real64)
   enddo
   open(newunit=u, file=FILE, access='stream', form='unformatted', action='write', status='replace')
   write(u) v
   close(u)
   endsubroutine write_field

   subroutine delete_field()
   !< Remove the field's file.
   integer :: u !< Unit.

   open(newunit=u, file=FILE, access='stream')
   close(u, status='delete')
   endsubroutine delete_field
endprogram cb_task
