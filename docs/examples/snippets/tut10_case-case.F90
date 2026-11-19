if (len(case_dir) == 0) then
   call ig_text_disabled('No case open.')
   call ig_text_wrapped('Open one with File > Open case, or drop its folder (or its heat.inp) on the window.')
   if (ig_button(ICON_FOLDER_OPEN//' Open case...')) call browse_case()
   return
endif
call ig_text(ICON_FOLDER//' '//case_dir)
if (ig_input_text('title', inp%title)) then        ! the field edits the variable in place
   edited = .true.
   call show_title()
endif
write(line, '(A,I0,A,I0,5A)') 'grid ', inp%nx, ' x ', inp%ny, ', plate ', num(inp%lx), ' m x ', num(inp%ly), ' m'
call ig_text(trim(line))
write(line, '(A,F0.2,A,ES7.1,A,I0)') 'omega ', inp%omega, ', tolerance ', inp%tolerance, ', at most ', inp%max_iter
call ig_text(trim(line))
call ig_begin_disabled(.not. edited)
if (ig_button(ICON_SAVE//' Save')) call save_case()
call ig_end_disabled()
