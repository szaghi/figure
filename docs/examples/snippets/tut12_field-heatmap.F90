if (ip_begin_plot('Temperature [C]', width=420.0_real64, height=-1.0_real64, equal=.true.)) then
   call ip_setup_axes('x [m]', 'y [m]')
   ! the cells' edges: half a spacing beyond the first and last nodes
   call ip_heatmap('##t', field, -0.5_real64 * dx, flx + 0.5_real64 * dx, -0.5_real64 * dy, fly + 0.5_real64 * dy, &
                   scale_min=tmin, scale_max=tmax, colormap=cmap)
   if (contours .and. bands > 0_int32) then      ! the lines at the bands' edges
      call ip_contour('##isotherms', field, 0.0_real64, flx, 0.0_real64, fly, &
                      levels=[(tmin + k * (tmax - tmin) / bands, k = 1_int32, bands - 1_int32)], &
                      color=[0.1_real64, 0.1_real64, 0.1_real64, 1.0_real64], labels=.true.)
   elseif (contours) then                         ! about ten lines at round values
      call ip_contour('##isotherms', field, 0.0_real64, flx, 0.0_real64, fly, nlevels=10_int32, &
                      color=[0.1_real64, 0.1_real64, 0.1_real64, 1.0_real64], labels=.true.)
   endif
   if (ip_drag_line_x(1_int32, probe_x, thickness=2.0_real64)) probe_x = min(flx, max(0.0_real64, probe_x))
   if (ip_drag_point(2_int32, point(1), point(2), radius=6.0_real64)) then
      point = [min(flx, max(0.0_real64, point(1))), min(fly, max(0.0_real64, point(2)))]
   endif
   i = 1_int32 + nint(point(1) / dx, int32)
   j = 1_int32 + nint(point(2) / dy, int32)
   write(text, '(F6.2,A)') field(i, j), ' C'
   call ip_annotation(point(1), point(2), trim(adjustl(text)), color=[1.0_real64, 1.0_real64, 0.9_real64, 0.9_real64], &
                      offset=[14.0_real64, -14.0_real64])
   call ip_end_plot()
endif
call ig_same_line()
if (bands > 0_int32) then                         ! the bands, their edges labelled
   call ip_colormap_legend('legend', cmap, tmin, tmax, levels=bands, height=-1.0_real64, label_format='%.0f')
else
   call ip_colormap_legend('legend', cmap, tmin, tmax, height=-1.0_real64, label_format='%.0f')
endif
