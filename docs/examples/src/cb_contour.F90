!< cb_contour, cookbook: contour lines over a field, a hole where the field is undefined, and probes the user drags.
program cb_contour
!< cb_contour, cookbook: contour lines over a field, a hole where the field is undefined, and probes the user drags.
use, intrinsic :: ieee_arithmetic, only : ieee_is_nan, ieee_quiet_nan, ieee_value
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_end, ig_same_line, ig_set_next_window, ip_annotation, ip_begin_plot, &
                   ip_colormap, ip_contour, ip_drag_line_x, ip_drag_point, ip_end_plot, ip_error_bars, ip_heatmap, &
                   ip_line, ip_setup_axes, ip_setup_axes_limits, ip_spec

implicit none
integer(int32), parameter :: NX = 161_int32    !< Samples along x, over [0, 2].
integer(int32), parameter :: NY = 81_int32     !< Samples along y, over [0, 1].
real(real64),   parameter :: DX = 2.0_real64 / (NX - 1) !< Spacing along x.
real(real64),   parameter :: DY = 1.0_real64 / (NY - 1) !< Spacing along y.
type(app_object)          :: app               !< Application.
real(real64)              :: f(NX, NY)         !< Two vortices: f(i, j) at x = (i - 1) DX, y = (j - 1) DY.
real(real64)              :: g(NX, NY)         !< The same around a body: NaN inside it.
real(real64)              :: y(NY)             !< Ordinates of the samples.
real(real64)              :: probe_x = 1.3_real64 !< The profile's abscissa, dragged by the user.
real(real64)              :: px = 0.55_real64  !< The point probe, dragged by the user.
real(real64)              :: py = 0.7_real64   !< ...
real(real64)              :: ey(9)             !< Ordinates of the profile's samples with error bars.
real(real64)              :: eg(9)             !< Their values.
real(real64)              :: ee(9)             !< Their uncertainty.
integer(int32)            :: cmap              !< The diverging colormap.
integer(int32)            :: i, j              !< Counters.
character(len=32)         :: text              !< The probe's value.

do j = 1_int32, NY
   y(j) = (j - 1) * DY
   do i = 1_int32, NX
      f(i, j) = vortex((i - 1) * DX - 0.6_real64, y(j) - 0.5_real64) - vortex((i - 1) * DX - 1.4_real64, y(j) - 0.5_real64)
      g(i, j) = f(i, j)
      if (((i - 1) * DX - 1.0_real64)**2 + (y(j) - 0.5_real64)**2 < 0.12_real64**2) &
         g(i, j) = ieee_value(1.0_real64, ieee_quiet_nan)                            ! inside the body: undefined
   enddo
enddo
ee = 0.05_real64

call app%init('FIGURE: contour lines', 1100_int32, 760_int32)
cmap = ip_colormap('vik')
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 1080.0_real64, 740.0_real64)
   if (ig_begin('Contours')) then
      !region contour
      if (ip_begin_plot('over a heatmap', width=520.0_real64, height=330.0_real64, equal=.true.)) then
         call ip_setup_axes('x', 'y')
         ! the heatmap's bounds are the cells' outer edges: half a spacing beyond the first and last samples
         call ip_heatmap('##f', f, -0.5_real64 * DX, 2.0_real64 + 0.5_real64 * DX, -0.5_real64 * DY, &
                         1.0_real64 + 0.5_real64 * DY, scale_min=-1.0_real64, scale_max=1.0_real64, colormap=cmap)
         call ip_contour('f', f, 0.0_real64, 2.0_real64, 0.0_real64, 1.0_real64, nlevels=8_int32, &
                         color=[0.1_real64, 0.1_real64, 0.1_real64, 1.0_real64], labels=.true.)
         call ip_end_plot()
      endif
      !endregion contour
      call ig_same_line()
      !region probes
      if (ip_begin_plot('around a body', width=520.0_real64, height=330.0_real64, equal=.true.)) then
         call ip_setup_axes('x', 'y')
         call ip_setup_axes_limits(0.0_real64, 2.0_real64, 0.0_real64, 1.0_real64)
         call ip_contour('g', g, 0.0_real64, 2.0_real64, 0.0_real64, 1.0_real64, &         ! NaNs: a hole, no lines
                         levels=[-0.8_real64, -0.6_real64, -0.4_real64, -0.2_real64, 0.2_real64, 0.4_real64, &
                                 0.6_real64, 0.8_real64], colormap=cmap, line_weight=2.0_real64)
         if (ip_drag_line_x(1_int32, probe_x)) probe_x = min(2.0_real64, max(0.0_real64, probe_x)) ! moved: clamp it
         if (ip_drag_point(2_int32, px, py, radius=6.0_real64)) then
            px = min(2.0_real64, max(0.0_real64, px))
            py = min(1.0_real64, max(0.0_real64, py))
         endif
         i = 1_int32 + nint(px / DX, int32)
         j = 1_int32 + nint(py / DY, int32)
         if (ieee_is_nan(g(i, j))) then
            text = 'inside the body'
         else
            write(text, '(A,F6.3)') 'g = ', g(i, j)
         endif
         call ip_annotation(px, py, trim(text), color=[1.0_real64, 1.0_real64, 0.9_real64, 0.9_real64], &
                            offset=[12.0_real64, -12.0_real64])
         call ip_annotation(1.0_real64, 0.5_real64, 'NaN')
         call ip_end_plot()
      endif
      !endregion probes
      !region profile
      i = 1_int32 + nint(probe_x / DX, int32)
      ey = y(1::10)
      eg = g(i, 1::10)
      write(text, '(A,F5.3)') 'g along x = ', (i - 1) * DX
      if (ip_begin_plot(trim(text)//'###profile', width=1060.0_real64, height=-1.0_real64)) then
         call ip_setup_axes('y', 'g')
         call ip_setup_axes_limits(0.0_real64, 1.0_real64, -1.1_real64, 1.1_real64)
         call ip_line('g', g, i, xscale=DY)                             ! row i, in place; NaNs: a gap
         call ip_error_bars('samples, +/- 0.05', ey, eg, ee, spec=ip_spec(size=6.0_real64))
         call ip_end_plot()
      endif
      !endregion profile
   endif
   call ig_end()
enddo
call app%destroy()

contains
   elemental function vortex(x, y) result(v)
   !< A Gaussian vortex's stream function, centred at the origin.
   real(real64), intent(in) :: x !< Abscissa from the centre.
   real(real64), intent(in) :: y !< Ordinate from the centre.
   real(real64)             :: v !< Value, in (0, 1].

   v = exp(-(x**2 + y**2) / 0.05_real64)
   endfunction vortex
endprogram cb_contour
