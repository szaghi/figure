if (ip_begin_plot('f(x, y)', width=700.0_real64, height=-1.0_real64)) then
   call ip_setup_axes('x', 'y')
   call ip_heatmap('f', f, 0.0_real64, 1.5_real64, 0.0_real64, 1.0_real64, scale_min=0.0_real64, &
                   scale_max=1.0_real64, colormap=ImPlotColormap_Viridis)
   call ip_image('image', tex, 1.2_real64, 1.4_real64, 0.05_real64, 0.25_real64)  ! row 1 at the bottom
   call ip_end_plot()
endif
call ig_same_line()
call ip_colormap_scale('##f scale', 0.0_real64, 1.0_real64, height=-1.0_real64, colormap=ImPlotColormap_Viridis)
