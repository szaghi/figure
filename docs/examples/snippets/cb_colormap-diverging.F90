cmap = ip_colormap('vik', levels=10_int32)      ! diverging, ten bands: zero sits between two of them
if (ip_begin_plot('vorticity', width=300.0_real64, height=300.0_real64)) then
   call ip_heatmap('w', w, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, scale_min=-1.0_real64, &
                   scale_max=1.0_real64, colormap=cmap)
   call ip_end_plot()
endif
call ig_same_line()
call ip_colormap_scale('##w', -1.0_real64, 1.0_real64, height=300.0_real64, colormap=cmap)
