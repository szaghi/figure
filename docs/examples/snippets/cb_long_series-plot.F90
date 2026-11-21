if (ip_begin_plot('Pressure at the probe', height=-1.0_real64)) then
   call ip_setup_axes('t [s]', 'p [Pa]')
   if (every) call ip_set_decimation(.false.) ! every point: the exact picture, at ImPlot's cost per point
   call ip_line('p', t, p)                    ! decimated by default: at most 64 points a pixel column
   if (every) call ip_set_decimation(.true.)
   call ip_end_plot()
endif
