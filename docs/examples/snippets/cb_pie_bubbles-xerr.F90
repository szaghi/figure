if (ip_begin_plot('a step', width=300.0_real64, height=280.0_real64)) then
   call ip_setup_axes('time [s]', 'nodes')
   call ip_setup_axes_limits(0.0_real64, 1.0_real64, 0.0_real64, 9.0_real64)
   call ip_setup_legend('ne')                                           ! the fastest timing is top left
   call ip_error_bars('spread', step, nodes, spread, horizontal=.true.) ! spread is in x units: seconds
   call ip_scatter('mean', step, nodes)
   call ip_end_plot()
endif
