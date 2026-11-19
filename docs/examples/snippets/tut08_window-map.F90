call app%init_headless(int(W, int32), int(H, int32), decorations='figure', buttons='right') ! the bar, no window
call app%set_confirm_quit(.true.)
call frames(3_int32)
call print_map()
call test_frame_rect('bar', r(1), r(2), r(3), r(4))
call test_click(0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4)))   ! a double-click on the bar
call test_click(0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4)))
call frames(10_int32)
call test_frame_state(minimized, maximized)
write(output_unit, '(A,L1,A,A)') 'double-click on the bar: maximized ', maximized, &
                                 ', the top-left corner: ', test_frame_hit(1.0_real64, 1.0_real64)
call test_frame_rect('close', r(1), r(2), r(3), r(4))
call test_click(0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4)))   ! the close button
call frames(6_int32)
write(output_unit, '(A,L1)') 'close: the question is shown ', asking
call app%destroy()
