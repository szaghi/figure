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
