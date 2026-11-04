call app%init_headless(400_int32, 300_int32)
do frame = 1_int32, 6_int32
   if (.not. app%next_frame()) exit
   call draw_panel(panel)
   ! the input queued now is seen by the next frame
   select case (frame)
   case (1_int32, 2_int32)
      call fig_input_mouse(real(panel%run_at(1), c_float), real(panel%run_at(2), c_float), 0_c_int) ! hover
   case (3_int32)
      call fig_input_mouse(real(panel%run_at(1), c_float), real(panel%run_at(2), c_float), 1_c_int) ! press
   case (4_int32)
      call fig_input_mouse(real(panel%run_at(1), c_float), real(panel%run_at(2), c_float), 0_c_int) ! release
   endselect
enddo
call app%destroy()
write(output_unit, '(A,I0)') 'runs: ', panel%runs
if (panel%runs /= 1_int32) error stop 'tut05_headless: expected one click'
