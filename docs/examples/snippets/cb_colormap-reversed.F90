if (ip_begin_plot('depth', width=300.0_real64, height=300.0_real64)) then
   call ip_heatmap('d', abs(w), 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, colormap=ip_colormap('ocean_r'))
   call ip_end_plot()
endif
