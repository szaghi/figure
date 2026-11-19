call test_item_click('tools/3-D')                 ! the 3-D panel in front, by its button in the tools' bar
call settle()
call test_item_click('3-D/clip')                  ! the checkbox, found by its path
call settle()
call check(cut .and. test_item_checked('3-D/clip'), 'the clip box, clicked by its path, is checked')
x0 = plane(1, 4)
call to_pixel(plane(1:3, 4), p0(1), p0(2))
call to_pixel(plane(1:3, 4) + [0.1_real64, 0.0_real64, 0.0_real64], p1(1), p1(2))
u = (p1 - p0) / norm2(p1 - p0)                    ! the x arrow's direction on the display
call test_mouse_move(p0(1) + 50.0_real64 * u(1), p0(2) + 50.0_real64 * u(2)) ! on the arrow, as the user grabs it
call frames(2_int32)
call test_mouse_button(.true.)
call frames(2_int32)
call test_mouse_move(p0(1) + 110.0_real64 * u(1), p0(2) + 110.0_real64 * u(2))
call frames(1_int32)
call test_mouse_button(.false.)
call frames(6_int32)
call check(plane(1, 4) > x0 + 0.05_real64, 'the gizmo''s arrow, dragged, moves the plane along x')
call test_item_click('3-D/clip')                  ! off again
call settle()
call test_mouse_move(10.0_real64, 300.0_real64)
call frames(2_int32)
