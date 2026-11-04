if (ip_begin_plot('Solution', height=250.0_real64)) then
   call ip_setup_axes('x', 'u')
   call ip_line('u', x, u)
   call ip_end_plot()
endif
if (ip_begin_plot('Convergence', height=250.0_real64)) then
   call ip_setup_axes('iteration', 'log10 max |update|', auto_fit=.true.)
   call ip_line('Jacobi', iterations(1:iter), residual(1:iter))
   call ip_end_plot()
endif
