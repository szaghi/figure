if (ip_begin_plot('density', 700.0_real64, 440.0_real64, equal=.true.)) then
   call ip_setup_axes('x [m]', 'y [m]')
   call ip_field_image('rho', rho, 0.0_real64, 4.0_real64, 0.0_real64, 3.0_real64, colormap=ip_colormap('inferno'), &
                       vmin=vmin, vmax=vmax, scale='log', changed=step)
   call ip_end_plot()
endif
call ig_same_line()
if (ip_colormap_legend_edit('rho legend', ip_colormap('inferno'), vmin, vmax, height=440.0_real64, &
                            scale='log', label_format='%g kg/m3')) then
   ! vmin and vmax changed: the next ip_field_image colours the field again
endif
call ig_item_rect(x0, y0, x1, y1)
if (ig_button('reset range')) then
   vmin = 0.1_real64
   vmax = 100.0_real64
endif
