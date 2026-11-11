call test_capture('solver.png')             ! the whole frame, written when it is rendered
if (app%next_frame()) call draw(s)          ! ... now
masks(:, 1) = [s%clock(1), s%clock(2), s%clock(1) + 200.0_real64, s%clock(4)] ! the clock's line: not deterministic
same = test_compare_image('solver.png', trim(golden), masks=masks)
write(output_unit, '(A,L1)') 'the window looks as committed: ', same
