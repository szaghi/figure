!< cb_items, cookbook: the plot items, styled with ip_spec.
program cb_items
!< cb_items, cookbook: the plot items, styled with ip_spec.
use, intrinsic :: iso_fortran_env, only : int32, real32, real64
use figure, only : app_object, ig_begin, ig_end, ig_set_next_window, ImPlotMarker_Circle, ImPlotMarker_Square, ip_bars, &
                   ip_begin_plot, ip_end_plot, ip_line, ip_scatter, ip_setup_axes, ip_shaded, ip_spec, plot_spec_object

implicit none
integer(int32), parameter :: N = 50_int32 !< Points.
type(app_object)          :: app          !< Application.
real(real64)              :: x(N)         !< Abscissae.
real(real64)              :: y(N)         !< Signal.
real(real64)              :: s(N)         !< Spread of the signal.
real(real32)              :: counts(N)    !< Single-precision data, plotted without conversion.
type(plot_spec_object)    :: signal       !< Style of the signal.
type(plot_spec_object)    :: samples      !< Style of the samples.
integer(int32)            :: i            !< Counter.

x = [(real(i, real64) / 5.0_real64, i = 1_int32, N)]
y = sin(x)
s = 0.1_real64 + 0.05_real64 * cos(x)
counts = real(abs(y), real32)
!region spec
signal = ip_spec(line_color=[0.85_real64, 0.10_real64, 0.10_real64, 1.0_real64], line_weight=2.0_real64)
samples = ip_spec(marker=ImPlotMarker_Circle, marker_size=3.0_real64)
!endregion spec

call app%init('FIGURE: items', 900_int32, 600_int32)
do while (app%next_frame())
   call ig_set_next_window(20.0_real64, 20.0_real64, 860.0_real64, 560.0_real64)
   if (ig_begin('Items')) then
      if (ip_begin_plot('Signal', height=-1.0_real64)) then
         call ip_setup_axes('x', 'y')
         !region items
         call ip_shaded('spread', x, y - s, y + s)                                ! band between two curves
         call ip_line('signal', x, y, spec=signal)                                ! styled line
         call ip_scatter('samples', x(::5), y(::5), spec=samples)                 ! markers only
         call ip_bars('counts', real(x, real32), counts, 0.15_real64)             ! real32 data, bar width in x units
         call ip_shaded('to zero', x, y, 0.0_real64, spec=ip_spec(fill_alpha=0.25_real64))    ! curve to y = 0
         call ip_scatter('squares', x(1:3), y(1:3), spec=ip_spec(marker=ImPlotMarker_Square))
         !endregion items
         call ip_end_plot()
      endif
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_items
