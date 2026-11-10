if (ip_begin_plot('Convergence', height=-1.0_real64)) then
   call ip_setup_axis('x1', label='iteration')
   call ip_setup_axis('y1', label='residual', scale='log')
   call ip_setup_axis('y2', label='coefficient', format='%.2f') ! on the right, no grid lines
   call ip_setup_legend('e', outside=.true.)
   call ip_line('residual', it, residual)                       ! on X1, Y1
   call ip_set_axes('x1', 'y2')                                 ! the next items on Y2
   call ip_line('cl', it, cl)
   call ip_line('cd', it, cd)
   if (check .and. frame == 3_int32) call measure()             ! --check: what the axes show
   call ip_end_plot()
endif
