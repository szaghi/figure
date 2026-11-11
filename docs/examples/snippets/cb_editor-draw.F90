subroutine draw(ed)
!< The window: the editor, then where the cursor is.
type(code_editor_object), intent(inout) :: ed           !< Editor.
integer(int32)                          :: line, column !< The cursor.
character(len=48)                       :: where        !< ... as text.

call ig_set_next_window(10.0_real64, 10.0_real64, 560.0_real64, 280.0_real64, always=.true.)
if (ig_begin('case.input')) then
   if (ed%draw('editor', height=-30.0_real64)) call validate(ed) ! the user changed it: check it again
   call ed%cursor(line, column)
   write(where, '(A,I0,A,I0)') 'line ', line, ', column ', column
   call ig_text(trim(where))
endif
call ig_end()
endsubroutine draw
