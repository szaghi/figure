do k = 1_int32, 1000000_int32                     ! the plate's field, read by a task: at a time of the task's
   if (size(field) > 0) exit
   call frames(1_int32)
enddo
call frames(360_int32)                            ! the notifications gone (5 s of frame time), nothing moving
call test_capture('tut25_clip.png')               ! the whole window, written when this frame is rendered
call frames(1_int32)
masks(:, 1) = path_rect                           ! the case's path: this machine's folders
call check(test_compare_image('tut25_clip.png', golden, masks=masks), &
           'the main window looks as committed (docs/examples/data/tut25_clip.png)')
call check(test_id_conflicts() == 0_int32, 'no two items of the main window share an id')
