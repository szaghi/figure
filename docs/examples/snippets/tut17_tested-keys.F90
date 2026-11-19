call test_click(title_at(1), title_at(2))         ! the title field, where the user clicks it
call frames(5_int32)
call test_key('shortcut', down=.true.)            ! select what is there
call test_key('a')
call test_key('shortcut', down=.false.)
call test_type('Plate B')                         ! and type over it
call test_key('enter')
call frames(8_int32)
title = app%title()
call check(trim(inp%title) == 'Plate B' .and. title == '* Plate B - FIGURE studio', &
           'typing edits the title, and the window''s title marks it unsaved')
