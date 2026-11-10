call log%set_cap(1000_int32)                                  ! keep the last 1000 lines
do i = 1_int32, 1200_int32
   write(line, '(A,I0,A,ES9.2)') 'step ', i, ' residual ', 10.0_real64**(-real(i, real64) / 200.0_real64)
   call log%add(trim(line))                                   ! or log%add(lines), as p%poll gives them
enddo
do i = 1_int32, 3_int32                                       ! every frame
   if (.not. app%next_frame()) exit
   call ig_set_next_window(0.0_real64, 0.0_real64, 500.0_real64, 300.0_real64, always=.true.)
   if (ig_begin('Log')) call log%draw('lines')                ! only the lines in view; follows the end
   call ig_end()
enddo
