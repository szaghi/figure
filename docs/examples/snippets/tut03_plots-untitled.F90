if (ip_begin_plot('##first mode', height=200.0_real64)) then
   call ip_line('mode 1', x, modes(:, 1))
   call ip_end_plot()
endif
