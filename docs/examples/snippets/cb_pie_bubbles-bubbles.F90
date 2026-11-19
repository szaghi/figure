if (ip_begin_plot('blocks', width=300.0_real64, height=280.0_real64, equal=.true.)) then ! round on equal axes
   call ip_setup_axes('x [m]', 'y [m]')
   call ip_bubbles('cells', cx, cy, 0.5_real64 * sqrt(cells), &  ! a radius in metres: an area as the cells
                   spec=ip_spec(fill_alpha=0.5_real64))
   call ip_end_plot()
endif
