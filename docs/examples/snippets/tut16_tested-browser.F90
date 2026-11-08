call test_key('shortcut', down=.true.)            ! ctrl, cmd on macOS
call test_key('o')
call test_key('shortcut', down=.false.)
call frames(6_int32)
call test_file_browser(shown, folder=folder, entries=entries)
call check(shown .and. any(entries == 'plate/'), 'ctrl+o shows the file browser on the example cases')
call test_file_browser_rect('entry:plate', r(1), r(2), r(3), r(4), found)
call test_click(0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4)))
call test_click(0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4)))   ! a double-click enters the folder
call frames(12_int32)
call test_file_browser_rect('ok', r(1), r(2), r(3), r(4), found)          ! Choose
call test_click(0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4)))
call frames(8_int32)
title = app%title()
call check(index(case_dir, '/plate', back=.true.) == len(case_dir) - 5 .and. &
           title == 'Heated plate - FIGURE studio', 'Choose opens the case, the window''s title says which')
