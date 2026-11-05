if (app%quit_requested()) then                     ! the close button was clicked
   if (edited) then
      call ig_open_popup('Discard changes?')
   else
      call app%quit()                              ! nothing to lose
   endif
endif
if (ig_begin_popup_modal('Discard changes?')) then
   call ig_text('The document has unsaved changes.')
   if (ig_button('Save')) then
      edited = .false.                             ! (save here)
      call app%quit()
   endif
   call ig_same_line()
   if (ig_button('Discard')) call app%quit()
   call ig_same_line()
   if (ig_button('Cancel')) call ig_close_current_popup()
   call ig_end_popup()
endif
