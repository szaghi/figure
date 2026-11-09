!< cb_wake_work, the work of cb_wake: a solver that leaves a snapshot file after each block of steps (a module
!< procedure: it runs on a worker thread).
module cb_wake_work
!< cb_wake_work, the work of cb_wake: a solver that leaves a snapshot file after each block of steps (a module
!< procedure: it runs on a worker thread).
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, task_handle_object

implicit none
private
public :: solve, snapshot_name

contains
   pure function snapshot_name(k, ready) result(name)
   !< The file of snapshot `k`, or (`ready`) the mark written once it is complete.
   integer(int32), intent(in)    :: k     !< Snapshot.
   logical,        intent(in)    :: ready !< The mark, not the snapshot.
   character(len=:), allocatable :: name  !< File name.
   character(len=8)              :: num   !< k as text.

   write(num, '(I0)') k
   name = 'cb_wake_'//trim(num)//merge('.ready', '.dat  ', ready)
   name = trim(name)
   endfunction snapshot_name

   recursive subroutine solve(h, data)
   !< Five blocks of steps; after each, the residual in a snapshot file, a mark that it is complete, and a wake-up.
   type(task_handle_object), intent(inout) :: h        !< The task's handle.
   class(*),                 intent(inout) :: data     !< Nothing: the news goes out in files.
   type(app_object)                        :: app      !< The application: its wake acts on the one frame loop.
   integer(int32)                          :: k, u     !< Block, unit.
   real(real64)                            :: residual !< The solver's residual.

   residual = 1.0_real64
   do k = 1_int32, 5_int32
      if (h%cancelled()) exit
      residual = residual / 10.0_real64                    ! the block's work
      open(newunit=u, file=snapshot_name(k, .false.), action='write', status='replace')
      write(u, '(I0,1X,ES10.3)') 100_int32 * k, residual
      close(u)
      open(newunit=u, file=snapshot_name(k, .true.), action='write', status='replace')
      close(u)                                             ! the snapshot is complete
      call app%wake()                                      ! news: the loop draws now, not after max_wait
   enddo
   endsubroutine solve
endmodule cb_wake_work

!< cb_wake, cookbook: redraw when a worker has news (app%wake from a task).
program cb_wake
!< cb_wake, cookbook: redraw when a worker has news (app%wake from a task).
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object, task_object
use cb_wake_work, only : solve, snapshot_name

implicit none
type(app_object)  :: app       !< Application.
type(task_object) :: solver    !< The solver's task.
integer(int32)    :: seen      !< Snapshots shown.
integer(int32)    :: step, u   !< A snapshot's step, unit.
real(real64)      :: residual  !< A snapshot's residual.
logical           :: ready     !< The next snapshot is complete.
logical           :: running   !< The loop goes on.

call app%init_headless(400_int32, 300_int32)
call app%set_lazy(.true., max_wait=60.0_real64)            ! idle: one frame a minute, unless woken
call solver%start(solve, 0_int32)
seen = 0_int32
running = .true.
do while (running)
   running = app%next_frame()
   do                                                      ! every complete snapshot not shown yet
      inquire(file=snapshot_name(seen + 1_int32, .true.), exist=ready)
      if (.not. ready) exit
      seen = seen + 1_int32
      open(newunit=u, file=snapshot_name(seen, .false.), action='read', status='old')
      read(u, *) step, residual
      close(u, status='delete')
      open(newunit=u, file=snapshot_name(seen, .true.), status='old')
      close(u, status='delete')
      write(output_unit, '(A,I0,A,ES10.3)') 'step ', step, ': residual ', residual
   enddo
   if (solver%done() .and. seen == 5_int32) running = .false.
enddo
call app%destroy()
endprogram cb_wake
