edited = .false.                                  ! nothing to lose: close quits
call test_frame_rect('close', r(1), r(2), r(3), r(4), found)
call test_click(0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4)))
call frames(8_int32)
call check(ended, 'the title bar''s close button ends the studio')
