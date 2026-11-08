if (app%quit_requested() .or. ask_quit) then      ! the close button, File > Quit or ctrl+q
   ask_quit = .false.
   call request('quit')                           ! nothing to lose: quit at once
endif
if (ask_discard) then
   call ig_open_popup('Discard changes?')
   ask_discard = .false.
endif
if (ig_begin_popup_modal('Discard changes?')) then
   call ig_text('"'//trim(inp%title)//'" has unsaved changes.')
   if (ig_button(ICON_SAVE//' Save')) then
      call save_case()
      call ig_close_current_popup()
      call go_on()
   endif
   call ig_same_line()
   if (ig_button('Discard')) then
      call ig_close_current_popup()
      call go_on()
   endif
   call ig_same_line()
   if (ig_button('Cancel')) then
      pending_action = ''
      call ig_close_current_popup()
   endif
   call ig_end_popup()
endif
