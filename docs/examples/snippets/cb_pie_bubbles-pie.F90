if (ip_begin_plot('one run', width=280.0_real64, height=280.0_real64, equal=.true.)) then
   call ip_setup_axes('##x', '##y')
   call ip_pie_chart(['solver  ', 'I/O     ', 'overset ', 'boundary'], seconds, 0.5_real64, 0.5_real64, 0.45_real64, &
                     label_format='%.0f s', normalize=.true.)  ! the slices are fractions of the sum
   call ip_end_plot()
endif
