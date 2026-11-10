call ig_cursor_screen_pos(at(1), at(2))                 ! where the next item goes [screen pixels]
call ig_draw_rect(at(1), at(2), at(1) + 300.0_real64, at(2) + 24.0_real64, [0.5_real64, 0.5_real64, 0.5_real64])
call ig_draw_rect(at(1), at(2), at(1) + 300.0_real64 * level, at(2) + 24.0_real64, FILL, filled=.true.)
if (ig_invisible_button('gauge', 300.0_real64, 24.0_real64)) level = 1.0_real64 ! reserves the place, takes clicks
