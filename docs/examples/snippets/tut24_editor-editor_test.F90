call test_item_click('heat.inp')                  ! the text's tab, in the Input panel
call settle()
call source%goto(line_of(source%text(), 'omega'), 3_int32, focus=.true.) ! the cursor on "omega"
call frames(3_int32)
call check(source%find('omega', whole_word=.true.), 'the editor finds "omega" in the text')
call test_type('omgea')                           ! a typo over the selection, as the user types it
call frames(4_int32)
call check(source%mark_of(line_of(source%text(), 'omgea')) == 'error' .and. text_errors == 1_int32 .and. &
           text_edited, 'a name the namelist has not is marked on its line; Apply waits')
if (source%replace('omgea', 'omega', whole_word=.true.) == 1_int32) call validate() ! find and replace, one undo
call frames(4_int32)
call check(text_errors == 0_int32 .and. index(source%text(), 'omega =') > 0, 'the name corrected, no line is marked')
call test_item_click('Form')                      ! the form in front again
call settle()
call test_key('f1')                               ! the help
call frames(4_int32)
call help%find('omega')
call frames(3_int32)
call check(app%window_visible('Help') .and. help%matches() > 0, 'F1 shows the help; it finds "omega"')
call help%find('')
call app%set_window_visible('Help', .false.)
call frames(2_int32)
