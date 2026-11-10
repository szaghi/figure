subroutine settle()
!< Draw frames until the interface is idle: no input queued, no frame asked for (at most 60).
do while (test_run(60_int32))
   if (.not. app%next_frame()) exit
   call draw(s)
enddo
endsubroutine settle
