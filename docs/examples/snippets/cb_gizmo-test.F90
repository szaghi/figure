write(output_unit, '(A,3F7.3)') 'plane point before:', plane(1:3, 4)
call to_pixel(view, plane(1:3, 4), ox, oy)
call to_pixel(view, plane(1:3, 4) + [0.1_real64, 0.0_real64, 0.0_real64], ax, ay)
d = hypot(ax - ox, ay - oy)
ux = (ax - ox) / d
uy = (ay - oy) / d                              ! the arrow's direction on the screen
call drag(ox + 50.0_real64 * ux, oy + 50.0_real64 * uy, ox + 110.0_real64 * ux, oy + 110.0_real64 * uy)
write(output_unit, '(A,3F7.3)') 'plane point after: ', plane(1:3, 4)
call drag(view1(1) - 48.0_real64, view0(2) + 48.0_real64, view1(1) - 48.0_real64, view0(2) + 48.0_real64)
call frames(44_int32)                           ! the cube turns the camera over 40 frames
call view%get_camera(azimuth=az, elevation=el)
write(output_unit, '(A,2F8.2)') 'camera after a click on the cube (azimuth, elevation):', az, el
