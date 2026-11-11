call test_menu_click('View/Analysis')             ! the layout of a finished run, as the user picks it
call settle()
call check(app%layout() == 'Analysis' .and. .not. app%window_visible('Input') .and. &
           app%window_visible('Messages'), 'View > Analysis: Input hidden, Messages shown beside Run')
call test_window_rect('3-D', r(1), r(2), r(3), r(4), found)
call check(found .and. r(1) > 0.6_real64 * 1100.0_real64, 'the 3-D view docked on the right of the result')
call test_menu_click('View/Input')                ! a panel shown again from the menu
call settle()
call check(app%window_visible('Input'), 'View > Input shows the panel the layout hid')
call test_menu_click('View/Setup')                ! back: the arrangement the user left Setup in
call settle()
call check(app%layout() == 'Setup' .and. .not. app%window_visible('Messages'), &
           'View > Setup gives back the input''s layout')
