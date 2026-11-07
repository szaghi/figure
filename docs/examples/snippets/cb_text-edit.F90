if (ig_button(ICON_SAVE//' Save')) then
   call write_text(trim(file), buffer%text())
   modified = .false.
endif
call ig_same_line()
if (modified) then
   call ig_text('(!) modified: '//trim(file))
else
   call ig_text('saved: '//trim(file))
endif
call ig_push_font('plex-mono')         ! columns line up: every character as wide
if (ig_input_text_multiline('##text', buffer, width=-1.0_real64, height=-1.0_real64, tab_input=.true.)) &
   modified = .true.
call ig_pop_font()
