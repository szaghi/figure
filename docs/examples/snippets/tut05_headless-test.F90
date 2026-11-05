call app%init_headless(400_int32, 300_int32)
do frame = 1_int32, 8_int32                                         ! a click needs four frames after it is queued
   if (.not. app%next_frame()) exit
   call draw_panel(panel)                                          ! the interface under test
   if (frame == 2_int32) call test_click(panel%run_at(1), panel%run_at(2)) ! "Run", once the window has its size
enddo
call app%destroy()
write(output_unit, '(A,I0)') 'runs: ', panel%runs
if (panel%runs /= 1_int32) error stop 'tut05_headless: expected one click'
