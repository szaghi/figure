!< cb_plot3d_style, cookbook: probes in a 3-D plot coloured and sized by their readings, the axes' formats and ticks,
!< and ImPlot3D's style changed for one plot.
program cb_plot3d_style
!< cb_plot3d_style, cookbook: probes in a 3-D plot coloured and sized by their readings, the axes' formats and ticks,
!< and ImPlot3D's style changed for one plot.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_end, ig_set_next_window, ip3_begin_plot, ip3_end_plot,           &
                   ip3_pop_style_color, ip3_pop_style_var, ip3_push_style_color, ip3_push_style_var, ip3_scatter, &
                   ip3_setup_axes, ip3_setup_axis, ip3_setup_axis_ticks, ip3_spec, ImPlot3DItemFlags_NoLegend, &
                   plot3d_spec_object

implicit none
integer(int32), parameter :: N = 60_int32 !< Probes.
type(app_object)          :: app          !< Application.
real(real64)              :: x(N), y(N), z(N), t(N) !< Probe positions [m] and temperatures [K].
real(real64)              :: colors(4, N) !< A colour per probe.
real(real64)              :: sizes(N)     !< A marker radius per probe [pixels].
real(real64)              :: a            !< Angle.
type(plot3d_spec_object)  :: unlisted     !< A style: no legend entry.
integer(int32)            :: i            !< Probe.

do i = 1_int32, N                         ! probes on a helix around a heated core
   a = 0.35_real64 * real(i, real64)
   x(i) = 0.4_real64 * cos(a)
   y(i) = 0.4_real64 * sin(a)
   z(i) = real(i - 1_int32, real64) / real(N - 1_int32, real64)
   t(i) = 300.0_real64 + 90.0_real64 * exp(-((z(i) - 0.5_real64) / 0.25_real64)**2)
enddo

unlisted = ip3_spec(flags=ImPlot3DItemFlags_NoLegend)  ! made once, given to every frame's item
call app%init('FIGURE: probes coloured by their readings', 520_int32, 500_int32)
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 500.0_real64, 480.0_real64)
   if (ig_begin('Probes')) then
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
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_plot3d_style
