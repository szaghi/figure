if (running) then
   do i = 1_int32, steps
      call jacobi_step()
      if (.not. running) exit
   enddo
   call app%request_frames(1_int32) ! draw the next frame without waiting for input
endif
