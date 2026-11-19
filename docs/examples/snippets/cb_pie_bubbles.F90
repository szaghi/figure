!< cb_pie_bubbles, cookbook: where a run's time went as a pie, the blocks of a grid as bubbles sized by their cells,
!< and timings with error bars along x.
program cb_pie_bubbles
!< cb_pie_bubbles, cookbook: where a run's time went as a pie, the blocks of a grid as bubbles sized by their cells,
!< and timings with error bars along x.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_end, ig_same_line, ig_set_next_window, ip_begin_plot, ip_bubbles, &
                   ip_end_plot, ip_error_bars, ip_pie_chart, ip_scatter, ip_setup_axes, ip_setup_axes_limits,  &
                   ip_setup_legend, ip_spec

implicit none
type(app_object) :: app                                                    !< Application.
real(real64)     :: seconds(4) = [61.0_real64, 18.0_real64, 9.0_real64, 12.0_real64] !< A run's time per phase.
real(real64)     :: cx(5) = [1.0_real64, 3.2_real64, 4.6_real64, 2.2_real64, 5.6_real64]      !< Blocks' centres, x [m].
real(real64)     :: cy(5) = [1.2_real64, 0.9_real64, 2.4_real64, 3.0_real64, 0.8_real64]      !< ... y [m].
real(real64)     :: cells(5) = [2.1_real64, 0.6_real64, 1.4_real64, 3.2_real64, 0.9_real64] !< Cells of each block [M].
real(real64)     :: step(4) = [0.82_real64, 0.47_real64, 0.29_real64, 0.21_real64]  !< Time of a step [s], mean.
real(real64)     :: spread(4) = [0.06_real64, 0.05_real64, 0.04_real64, 0.05_real64] !< Its standard deviation [s].
real(real64)     :: nodes(4) = [1.0_real64, 2.0_real64, 4.0_real64, 8.0_real64]     !< Nodes of each timing.

call app%init('FIGURE: pies, bubbles and error bars along x', 940_int32, 340_int32)
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 920.0_real64, 320.0_real64)
   if (ig_begin('Where the time went')) then
      if (ip_begin_plot('one run', width=280.0_real64, height=280.0_real64, equal=.true.)) then
         call ip_setup_axes('##x', '##y')
         call ip_pie_chart(['solver  ', 'I/O     ', 'overset ', 'boundary'], seconds, 0.5_real64, 0.5_real64, 0.45_real64, &
                           label_format='%.0f s', normalize=.true.)  ! the slices are fractions of the sum
         call ip_end_plot()
      endif
      call ig_same_line()
      if (ip_begin_plot('blocks', width=300.0_real64, height=280.0_real64, equal=.true.)) then ! round on equal axes
         call ip_setup_axes('x [m]', 'y [m]')
         call ip_bubbles('cells', cx, cy, 0.5_real64 * sqrt(cells), &  ! a radius in metres: an area as the cells
                         spec=ip_spec(fill_alpha=0.5_real64))
         call ip_end_plot()
      endif
      call ig_same_line()
      if (ip_begin_plot('a step', width=300.0_real64, height=280.0_real64)) then
         call ip_setup_axes('time [s]', 'nodes')
         call ip_setup_axes_limits(0.0_real64, 1.0_real64, 0.0_real64, 9.0_real64)
         call ip_setup_legend('ne')                                           ! the fastest timing is top left
         call ip_error_bars('spread', step, nodes, spread, horizontal=.true.) ! spread is in x units: seconds
         call ip_scatter('mean', step, nodes)
         call ip_end_plot()
      endif
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_pie_bubbles
