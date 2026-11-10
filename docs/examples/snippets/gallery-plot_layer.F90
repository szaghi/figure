if (ip_begin_plot('##plot layer', 860.0_real64, 170.0_real64)) then
   call ip_setup_axes('x [m]', 'y [m]')
   call ip_setup_axes_limits(0.0_real64, 4.0_real64, -0.2_real64, 1.2_real64)
   call ip_line('u', x * 4.0_real64, 0.5_real64 + 0.4_real64 * sin(6.0_real64 * x))
   call ig_draw_rect(0.0_real64, 0.0_real64, 4.0_real64, 1.0_real64, TEAL, 2.0_real64, layer='plot')
   call ig_draw_circle(1.0_real64, 0.5_real64, 12.0_real64, AMBER, filled=.true., layer='plot')
   call ig_draw_text(1.1_real64, 0.45_real64, 'probe at (1, 0.5) m', AMBER, layer='plot')
   call ip_end_plot()
endif
