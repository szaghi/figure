call test_click(title_at(1), title_at(2))         ! the title field, where the user clicks it
call frames(5_int32)
call test_type(' X')
call test_key('escape')                           ! leaves the field as it was
call frames(6_int32)
call check(trim(inp%title) == 'Heated plate' .and. .not. edited, 'escape leaves the title as it was, unedited')
