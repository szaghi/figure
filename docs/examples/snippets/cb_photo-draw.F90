h = 280.0_real64
if (photo%is_initialized()) then         ! the photograph at the plot's height, its own proportions
   call ig_image(photo, h * photo%width() / photo%height(), h)
else
   call ig_text(status)
endif
call ig_same_line()
if (ip_begin_plot('simulation', width=-1.0_real64, height=h)) then
   call ip_setup_axes('x / D', 'y / D')
   call ip_field_image('d rho / dx', f, -3.4_real64, 1.9_real64, -1.76_real64, 1.76_real64, &
                       colormap=ImPlotColormap_Greys, vmin=-1.0_real64, vmax=1.0_real64)
   call ip_end_plot()
endif
