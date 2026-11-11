s%omega = 1.2_real64                        ! a change that shows: the slider's grab moves
call settle()
call test_capture('changed.png')
if (app%next_frame()) call draw(s)
same = test_compare_image('changed.png', 'solver.png', masks=masks, failed=failed)
write(output_unit, '(A,L1,A,I0,A)') 'after the change: ', same, ' (', failed, ' pixels)'
write(output_unit, '(A)') figure_last_error()
