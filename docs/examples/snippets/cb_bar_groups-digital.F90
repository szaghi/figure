if (ip_begin_plot('residual and output', height=-1.0_real64)) then
   call ip_setup_axes('iteration', 'residual')
   call ip_line('residual', it, res)
   call ip_digital('writing', it, writing)                  ! 0 or 1, drawn in a band of its own
   call ip_end_plot()
endif
