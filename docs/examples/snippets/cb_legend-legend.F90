if (ip_begin_plot('pressure', width=560.0_real64, height=420.0_real64, equal=.true.)) then
   call ip_setup_axes('x', 'y')
   call ip_heatmap('##p', p, -1.0_real64 - 0.5_real64 * h, 1.0_real64 + 0.5_real64 * h, -1.0_real64 - 0.5_real64 * h, &
                   1.0_real64 + 0.5_real64 * h, scale_min=-1.0_real64, scale_max=1.0_real64,                          &
                   colormap=ip_colormap('balance', levels=8_int32))
   call ip_contour('p', p, -1.0_real64, 1.0_real64, -1.0_real64, 1.0_real64, levels=[-0.5_real64, 0.0_real64, &
                   0.5_real64], color=line_color)
   call ip_end_plot()
endif
call ig_same_line()
call ip_colormap_legend('p levels', ip_colormap('balance'), -1.0_real64, 1.0_real64, levels=8_int32, &
                        height=420.0_real64)                    ! the bands of the heatmap, their edges labelled
call ig_text('the same map, continuous, horizontal:')
call ip_colormap_legend('p continuous', ip_colormap('balance'), -1.0_real64, 1.0_real64, horizontal=.true., &
                        width=560.0_real64, label_format='%.1f')
