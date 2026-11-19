floor_xyz = reshape([-10.0_real64, -10.0_real64, 0.0_real64, 10.0_real64, -10.0_real64, 0.0_real64, &
                     10.0_real64, 10.0_real64, 0.0_real64, -10.0_real64, 10.0_real64, 0.0_real64], [3, 4])
floor_quad(:, 1) = [1_int32, 2_int32, 3_int32, 4_int32]
mark_xyz = reshape([-1.0_real64, 0.0_real64, 3.0_real64, 1.0_real64, 0.0_real64, 3.0_real64, &
                    0.0_real64, 0.0_real64, 5.0_real64], [3, 3])
mark_tri(:, 1) = [1_int32, 2_int32, 3_int32]
floor = view%quads(floor_xyz, floor_quad, color=[0.6_real64, 0.6_real64, 0.6_real64], edges=.true.)
mark = view%triangles(mark_xyz, mark_tri, color=[0.9_real64, 0.2_real64, 0.2_real64])
call frames(3_int32)
call view%render_info(width=w, height=h)
if (view%pick(0.5_real64 * w, 0.5_real64 * h, mesh, element, point=hit)) then ! the view's centre
   write(output_unit, '(A,I0,A,I0,A,3F7.2)') 'at the centre: mesh ', mesh, ' (the bump is 1), element ', element, &
                                            ', at', hit
endif
call view%remove(mark)                                        ! the program's arrays are not touched
call frames(3_int32)
call view%image(rgba)                                         ! as texture_object%update takes them
write(output_unit, '(A,I0,A,I0,A)') 'read back: ', size(rgba, 2), ' x ', size(rgba, 3), ' pixels'
