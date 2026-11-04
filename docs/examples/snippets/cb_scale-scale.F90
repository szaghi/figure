s = app%content_scale()
do while (app%next_frame())
   call ig_set_next_window(10.0_real64 * s, 10.0_real64 * s, 780.0_real64 * s, 580.0_real64 * s)
   if (ig_begin('Scaled')) then
      if (ip_begin_plot('Diagonal', height=400.0_real64 * s)) then
         call ip_line('y = x', x, y)
         call ip_end_plot()
      endif
   endif
   call ig_end()
enddo
