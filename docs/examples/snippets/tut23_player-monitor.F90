if (ip_begin_plot('Monitor', width=-1.0_real64, height=-1.0_real64)) then
   call ip_setup_axis('x1', label='iteration', auto_fit=solver%running())  ! follows the run while it runs
   call ip_setup_axis('y1', label='residual', scale='log', auto_fit=.true.) ! each y axis fits its own items
   call ip_setup_axis('y2', label='mean T [C]', auto_fit=.true.) ! on the right: the second axis
   call ip_setup_legend(location='n', horizontal=.true.)
   call ip_set_axes('x1', 'y1')
   call ip_line('residual', steps, res)          ! integer abscissae: converted by FIGURE, the ordinates in place
   call ip_set_axes('x1', 'y2')                    ! the next items on the second y axis
   call ip_line('mean T', steps, means)
