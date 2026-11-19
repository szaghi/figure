drop(1) = dir//'/channel'
call test_drop(drop, 600.0_real64, 300.0_real64) ! a folder dropped on the window
call frames(6_int32)
call test_popup_rect(r(1), r(2), r(3), r(4), found)
call check(found .and. trim(inp%title) == 'Plate B', 'a drop asks before discarding the edit')
call test_click(discard_at(1), discard_at(2))
call frames(6_int32)
call check(trim(inp%title) == 'Cooled channel' .and. .not. edited, 'Discard opens the dropped case')
