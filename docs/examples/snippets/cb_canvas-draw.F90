do b = 1_int32, NB
   w(b) = merge(4.0_real64, 2.0_real64, b == hovered .or. b == selected)
enddo
call ig_draw_rect(px(0.0_real64), py(0.0_real64), px(4.0_real64), py(1.0_real64), &
                  [0.5_real64, 0.5_real64, 0.5_real64, 0.25_real64], filled=.true.)
call ig_draw_line(px(0.0_real64), py(0.0_real64), px(0.0_real64), py(1.0_real64), HUE(:, bc(1)), w(1))
call ig_draw_line(px(4.0_real64), py(0.0_real64), px(4.0_real64), py(1.0_real64), HUE(:, bc(2)), w(2))
call ig_draw_line(px(0.0_real64), py(0.0_real64), px(4.0_real64), py(0.0_real64), HUE(:, bc(3)), w(3))
call ig_draw_line(px(0.0_real64), py(1.0_real64), px(4.0_real64), py(1.0_real64), HUE(:, bc(4)), w(4))
call ig_draw_circle(px(XC), py(YC), RC * scale, [0.1_real64, 0.1_real64, 0.1_real64], filled=.true.)
call ig_draw_circle(px(XC), py(YC), RC * scale, HUE(:, bc(5)), w(5))
call ig_draw_text(px(0.0_real64) - 36.0_real64, py(0.5_real64) - 8.0_real64, 'inlet', HUE(:, bc(1)))
call ig_draw_text(px(4.0_real64) + 4.0_real64, py(0.5_real64) - 8.0_real64, 'outlet', HUE(:, bc(2)))
call ig_draw_text(px(2.0_real64), py(0.0_real64) + 4.0_real64, 'bottom', HUE(:, bc(3)))
call ig_draw_text(px(2.0_real64), py(1.0_real64) - 20.0_real64, 'top', HUE(:, bc(4)))
call ig_draw_text(px(XC) + RC * scale + 6.0_real64, py(YC) - 8.0_real64, 'cylinder', HUE(:, bc(5)))
