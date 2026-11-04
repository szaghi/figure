if (ip_begin_plot('Rows: read in place, with a stride', height=250.0_real64)) then
   call ip_line('probe 1', history, 1_int32, xscale=0.01_real64)  ! row 1, x = 0.01 (j - 1): no copy
   call ip_line('probe 2', history, 2_int32, xscale=0.01_real64)
   call ip_end_plot()
endif
