subroutine goto_dialog()
!< The "Go to block" dialog: its field has the focus when it opens; enter goes to the block typed.
integer(int32) :: k !< The block typed.
if (ig_begin_popup_modal('Go to block')) then
   call ig_text_disabled('a block from 1 to 2000, then enter')
   if (focus_field) call ig_focus_here()                ! once: the next item takes the keys
   focus_field = .false.
   if (ig_input_text('block', goto_text)) continue
   s = ig_last_item()
   if (s%deactivated_after_edit) then                   ! enter (or a click elsewhere)
      read(goto_text, *, iostat=ios) k
      if (ios == 0 .and. k >= 1_int32 .and. k <= BLOCKS) call select(k)
      call ig_close_current_popup()
   endif
   if (ig_button('Cancel')) call ig_close_current_popup()
   call ig_end_popup()
endif
endsubroutine goto_dialog
