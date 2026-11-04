if (ip_begin_plot('Rows with any x: copied', height=250.0_real64)) then
   call ip_line('probe 1', t, history(1, :))   ! strided section: the compiler copies it into a temporary
   row = history(2, :)                         ! or copy it yourself, into a buffer you reuse
   call ip_line('probe 2', t, row)
   call ip_end_plot()
endif
