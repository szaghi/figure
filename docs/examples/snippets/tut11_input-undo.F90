if (changing) then
   if (.not. was_changing) call push_undo(before) ! one Undo per edit, not per frame of it
   edited = .true.
   call show_title()
   call source%set(case_text(inp))                ! the text follows the form
   text_edited = .false.
endif
was_changing = changing
