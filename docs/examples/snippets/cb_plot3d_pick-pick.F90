if (ip3_begin_plot('body over a field', height=-40.0_real64)) then
   call ip3_setup_axes('x', 'y', 'z', limits=[-1.0_real64, 1.0_real64, -1.0_real64, 1.0_real64, &
                       0.0_real64, 1.0_real64], elevation=30.0_real64, azimuth=-50.0_real64)
   call ip3_setup_box(scale=[1.0_real64, 1.0_real64, 0.6_real64])   ! a flatter box
   call ip3_setup_legend('ne')
   call ip3_image('field', floor, corners)                          ! the floor, z = 0
   call ip3_triangles('wedge', body(1, :), body(2, :), body(3, :))
   call ip3_quads('back', back(1, :), back(2, :), back(3, :))
   over = ip3_mouse_ray(o, d)                                       ! the ray under the pointer
   if (over .and. abs(d(3)) > 1.0e-9_real64) then
      t = -o(3) / d(3)                                              ! ... meets z = 0 there
      hit = o + t * d
   endif
   call ip3_end_plot()
endif
if (over .and. all(abs(hit(1:2)) <= 1.0_real64)) then
   write(line, '(A,F6.2,A,F6.2)') 'floor at x = ', hit(1), ', y = ', hit(2)
   call ig_text(trim(line))
else
   call ig_text_disabled('point at the floor')
endif
