write(output_unit, '(A,I0,A,L1)') 'points: ', n, ', path drawn: ', drawn
write(output_unit, '(A,I0,A,I0,A)') 'rows read in place: stride ', test_plot_stride(), ' bytes, ', &
                                    test_plot_copies() - c0, ' copies'
before = pixel
call test_mouse_move(360.0_real64, 280.0_real64)   ! a right drag across the plot turns the box
call test_next_frame()
call test_next_frame()
call test_mouse_button(.true., 'right')
call test_next_frame()
do k = 1_int32, 4_int32
   call test_mouse_move(360.0_real64 + 30.0_real64 * k, 280.0_real64)
   call test_next_frame()
enddo
call test_mouse_button(.false., 'right')
call frames(12_int32)
write(output_unit, '(A,L1)') 'turned by a right drag: ', norm2(pixel - before) > 10.0_real64
