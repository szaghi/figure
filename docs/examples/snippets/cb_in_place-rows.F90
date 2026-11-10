if (ip_begin_plot('Probes', height=280.0_real64)) then
   before = test_plot_copies()
   call ip_line('probe 1', time, probes(1, :))  ! a row: time is copied at the row's stride
   copies(2) = test_plot_copies() - before
   stride(2) = test_plot_stride()
   before = test_plot_copies()
   call ip_line('probe 2', probes(2, :), xscale=1.0e-3_real64, xstart=1.0e-3_real64) ! uniform x: no copy
   copies(3) = test_plot_copies() - before
   stride(3) = test_plot_stride()
   before = test_plot_copies()
   call ip_line('probe 3, every 10th', probes(3, ::10), xscale=1.0e-2_real64, xstart=1.0e-3_real64)
   copies(4) = test_plot_copies() - before
   stride(4) = test_plot_stride()
   call ip_end_plot()
endif
