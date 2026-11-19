if (app%quit_requested() .or. ask_quit) then      ! the close button was clicked, or File > Quit
   call ig_open_popup('Quit the studio?')        ! here, outside the menu: the popup's id is the modal's
   ask_quit = .false.
endif
if (ig_begin_popup_modal('Quit the studio?')) then
   asking = .true.
   call ig_text('The studio closes.')
   if (ig_button('Quit')) call app%quit()         ! the next next_frame returns .false.
   call ig_same_line()
   if (ig_button('Cancel')) call ig_close_current_popup()
   call ig_end_popup()
endif
