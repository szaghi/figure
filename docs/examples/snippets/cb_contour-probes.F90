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
