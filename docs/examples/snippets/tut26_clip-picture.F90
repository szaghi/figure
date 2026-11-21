do k = 1_int32, 1000000_int32                     ! the plate's field, read by a task: at a time of the task's
   if (field_read()) exit
   call frames(1_int32)
enddo
call frames(360_int32)                            ! the notifications gone (5 s of frame time), nothing moving
call test_capture('tut26_clip.png')               ! the whole window, written when this frame is rendered
call frames(1_int32)
masks(:, 1) = path_rect                           ! the case's path: this machine's folders
masks(:, 2) = 0.0_real64                          ! the title bar: left out where it is the other platform's
call test_frame_rect('close', r(1), r(2), r(3), r(4))
call test_frame_rect('menus', m(1), m(2), m(3), m(4))
if (r(1) < m(1)) call test_frame_rect('bar', masks(1, 2), masks(2, 2), masks(3, 2), masks(4, 2)) ! macOS: buttons left
call check(test_compare_image('tut26_clip.png', golden, masks=masks), &
           'the main window looks as committed (docs/examples/data/tut26_clip.png)')
call check(test_id_conflicts() == 0_int32, 'no two items of the main window share an id')
