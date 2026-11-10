if (ip_begin_plot('Coefficients per iteration', height=280.0_real64)) then
   before = test_plot_copies()
   call ip_line('cl', runs%iter, runs%cl) ! integer x: converted; cl read where it is
   copies(1) = test_plot_copies() - before
   stride(1) = test_plot_stride()
   call ip_line('cd', runs%iter, runs%cd)
   call ip_end_plot()
endif
