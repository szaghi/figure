call view%clear()                                 ! the meshes go before their arrays change
deallocate(carpet)
allocate(carpet(3, size(field, 1), size(field, 2)))
dx = flx / (size(field, 1) - 1)
dy = fly / (size(field, 2) - 1)
tmin = minval(field)
h = 0.4_real64 * max(flx, fly) / max(1.0e-12_real64, maxval(field) - tmin) ! the hottest 0.4 plate high
do j = 1_int32, size(field, 2, kind=int32)
   do i = 1_int32, size(field, 1, kind=int32)
      carpet(:, i, j) = [(i - 1) * dx, (j - 1) * dy, h * (field(i, j) - tmin)]
   enddo
enddo
do i = 1_int32, size(body, 2, kind=int32)       ! the cylinder, from the plate up to the body's temperature
   th = 2.0_real64 * acos(-1.0_real64) * (i - 1) / (size(body, 2) - 1)
   body(:, i, 1) = [inp%body_x + inp%body_r * cos(th), inp%body_y + inp%body_r * sin(th), 0.0_real64]
   body(:, i, 2) = [body(1:2, i, 1), h * (inp%body_t - tmin) + 0.15_real64 * max(flx, fly)]
enddo
carpet_mesh = view%surface(carpet, scalar=field, colormap=trim(MAPS(map)), edges=grid3d) ! read in place
body_mesh = view%surface(body, color=[0.75_real64, 0.75_real64, 0.78_real64])
call view%set_camera(azimuth=-60.0_real64, elevation=35.0_real64)
call view%fit()
if (cut) call view%clip([-1.0_real64, 0.0_real64, 0.0_real64], [probe_x, 0.0_real64, 0.0_real64])
