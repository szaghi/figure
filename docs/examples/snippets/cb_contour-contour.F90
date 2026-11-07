if (ip_begin_plot('over a heatmap', width=520.0_real64, height=330.0_real64, equal=.true.)) then
   call ip_setup_axes('x', 'y')
   ! the heatmap's bounds are the cells' outer edges: half a spacing beyond the first and last samples
   call ip_heatmap('##f', f, -0.5_real64 * DX, 2.0_real64 + 0.5_real64 * DX, -0.5_real64 * DY, &
                   1.0_real64 + 0.5_real64 * DY, scale_min=-1.0_real64, scale_max=1.0_real64, colormap=cmap)
   call ip_contour('f', f, 0.0_real64, 2.0_real64, 0.0_real64, 1.0_real64, nlevels=8_int32, &
                   color=[0.1_real64, 0.1_real64, 0.1_real64, 1.0_real64], labels=.true.)
   call ip_end_plot()
endif
