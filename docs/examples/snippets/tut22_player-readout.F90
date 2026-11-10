readout = ''
if (ip_plot_hovered()) then                     ! the pointer over the plot area
   call ip_plot_mouse(x, y, xaxis='x1', yaxis='y1') ! where it is, in iterations and residual
   k = minloc(abs(steps - x), dim=1)            ! the nearest iteration printed
   write(readout, '(A,I0,A,ES9.2,A,A,A)') 'iteration ', steps(k), ': residual ', res(k), ', mean ', &
                                         num(means(k)), ' C'
   call ip_tag('x1', real(steps(k), real64), text=trim(readout(11:index(readout, ':') - 1))) ! on the x axis
   call ip_set_axes('x1', 'y1')                 ! the text at the pointer, in the axes it was read in
   call ip_text(trim(readout), x, y, offset=[12.0_real64, -12.0_real64])
endif
