call ip3_push_style_color('PlotBg', [0.10_real64, 0.09_real64, 0.08_real64, 1.0_real64]) ! this plot only
call ip3_push_style_var('PlotPadding', [16.0_real64, 16.0_real64])
if (ip3_begin_plot('core', width=-1.0_real64, height=-1.0_real64)) then
   call ip3_setup_axes('x', 'y', 'height')
   call ip3_setup_axis('x', label='x', format='%.1f m')                ! a printf format of one real
   call ip3_setup_axis('y', label='y', format='%.1f m')
   call ip3_setup_axis_ticks('z', [0.0_real64, 0.5_real64, 1.0_real64], ['base', 'core', 'top '])
   do i = 1_int32, N                     ! cold blue to hot red; the hotter, the larger
      colors(:, i) = [(t(i) - 300.0_real64) / 90.0_real64, 0.25_real64, 1.0_real64 - (t(i) - 300.0_real64) / 90.0_real64, &
                      1.0_real64]
      sizes(i) = 2.0_real64 + 6.0_real64 * (t(i) - 300.0_real64) / 90.0_real64
   enddo
   call ip3_scatter('probes', x, y, z, spec=unlisted, colors=colors, sizes=sizes)
   call ip3_end_plot()
endif
call ip3_pop_style_var()
call ip3_pop_style_color()
