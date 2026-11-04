call app%set_lazy(.true., max_wait=1.0_real64) ! idle: redraw at least once per second
do while (app%next_frame())
   call date_and_time(time=clock)
   if (ig_begin('Clock')) then
      call ig_text(clock(1:2)//':'//clock(3:4)//':'//clock(5:6))
   endif
   call ig_end()
enddo
