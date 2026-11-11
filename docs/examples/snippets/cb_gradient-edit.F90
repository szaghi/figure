if (ig_gradient_edit('stops', 'cool-warm', width=-90.0_real64)) text = 'cool-warm changed' ! the field follows
call ig_same_line()
if (ig_button('Save')) then
   call save('cool-warm', 'my-cool-warm.csv')
   text = 'saved to my-cool-warm.csv'
endif
if (ip_begin_plot('pressure', width=480.0_real64, height=440.0_real64, equal=.true.)) then
   call ip_setup_axes('x', 'y')
   call ip_field_image('p', p, -1.0_real64, 1.0_real64, -1.0_real64, 1.0_real64, colormap=ip_colormap('cool-warm'), &
                       vmin=-1.0_real64, vmax=1.0_real64)
   call ip_end_plot()
endif
call ig_same_line()
call ip_colormap_legend('p', ip_colormap('cool-warm'), -1.0_real64, 1.0_real64, height=440.0_real64)
