if (ip_begin_plot('Columns: read in place', height=250.0_real64)) then
   call ip_line('probe 1', t, probes(:, 1))    ! contiguous section: no copy
   call ip_line('probe 2', t, probes(:, 2))
   call ip_end_plot()
endif
