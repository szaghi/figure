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
