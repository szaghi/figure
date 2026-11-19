select case (section)
case (1_int32)                                     ! numeric fields: integers with +/- buttons, reals with a format
   if (ig_input('nx', inp%nx, step=1_int32)) changing = .true.
   if (ig_input('ny', inp%ny, step=1_int32)) changing = .true.
   if (ig_input('lx [m]', inp%lx, format='%.3f')) changing = .true.
   if (ig_input('ly [m]', inp%ly, format='%.3f')) changing = .true.
   inp%nx = max(inp%nx, 3_int32)                   ! the solver needs an interior
   inp%ny = max(inp%ny, 3_int32)
case (3_int32)                                     ! sliders: the body stays inside the plate
   if (ig_slider('x [m]', inp%body_x, 0.0_real64, inp%lx)) changing = .true.
   if (ig_slider('y [m]', inp%body_y, 0.0_real64, inp%ly)) changing = .true.
   if (ig_slider('radius [m]', inp%body_r, 0.01_real64, 0.5_real64 * min(inp%lx, inp%ly))) changing = .true.
   inp%body_x = 0.001_real64 * nint(1000.0_real64 * inp%body_x) ! a slider gives any real: millimetres here
   inp%body_y = 0.001_real64 * nint(1000.0_real64 * inp%body_y)
   inp%body_r = 0.001_real64 * nint(1000.0_real64 * inp%body_r)
   if (ig_input('temperature [C]', inp%body_t, format='%.1f')) changing = .true.
case (4_int32)
   if (ig_slider('omega', inp%omega, 1.0_real64, 1.95_real64)) changing = .true.
   inp%omega = 0.01_real64 * nint(100.0_real64 * inp%omega)       ! two decimals
   call ig_tooltip('Over-relaxation: 1 is Gauss-Seidel, close to 2 converges faster or not at all')
   if (ig_input('tolerance', inp%tolerance, format='%.1e')) changing = .true.
   if (ig_input('iterations at most', inp%max_iter, step=100_int32)) changing = .true.
end select
