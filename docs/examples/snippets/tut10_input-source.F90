call ig_begin_disabled(.not. text_edited)
if (ig_button(ICON_CHECK//' Apply')) call apply_text()
call ig_end_disabled()
call ig_same_line()
if (text_edited) then
   call ig_text('(!) the text is not applied yet')
else
   call ig_text_disabled('the input, as heat.inp will hold it')
endif
call ig_push_font('plex-mono')                     ! columns line up: every character as wide
if (ig_input_text_multiline('##source', source, width=-1.0_real64, height=-1.0_real64)) text_edited = .true.
call ig_pop_font()
