call test_menu_click('File/Recent/channel.toml')  ! File, then Recent once it opens, then the file
call settle()
call test_item_type_text('Solver/CFL', '0.8')     ! a click with the shortcut key, select all, type, Enter
call settle()
call test_item_click('Solver/Options')            ! a tree node: its arrow opens it
call settle()
call test_item_click('Solver/Options/Implicit')
call settle()
