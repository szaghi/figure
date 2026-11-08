call test_frame_rect('menus', r(1), r(2), r(3), r(4), found)
call check(found, 'the title bar holds the studio''s menus')
call test_frame_rect('title', r(1), r(2), r(3), r(4), found)
hit = test_frame_hit(0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4))) ! what the system is told
call check(found .and. hit == 'drag', 'the title drags the window')
