!< cb_quit, cookbook: ask before discarding changes when the window is closed; a popup of options.
program cb_quit
!< cb_quit, cookbook: ask before discarding changes when the window is closed; a popup of options.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_begin_popup, ig_begin_popup_modal, ig_button, ig_checkbox, &
                   ig_close_current_popup, ig_end, ig_end_popup, ig_input_text, ig_open_popup, ig_same_line, &
                   ig_set_next_window, ig_text

implicit none
type(app_object)  :: app      !< Application.
character(len=64) :: title    !< The document: one field.
logical           :: edited   !< Changed since the last save.
logical           :: verbose  !< An option, in the popup.

title = 'untitled'
edited = .false.
verbose = .false.
call app%init('FIGURE: ask before quitting', 640_int32, 260_int32)
call app%set_confirm_quit(.true.)                       ! the close button asks the program first
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 620.0_real64, 240.0_real64)
   if (ig_begin('Document')) then
      if (ig_input_text('title', title)) edited = .true.
      !region popup
      if (ig_button('Options')) call ig_open_popup('options') ! once, on the click
      if (ig_begin_popup('options')) then                     ! every frame; closes on a click outside
         if (ig_checkbox('verbose output', verbose)) continue
         call ig_end_popup()
      endif
      !endregion popup
      call ig_text(merge('edited ', 'saved  ', edited))
      !region quit
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
      !endregion quit
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_quit
