subroutine start(ed)
!< The editor of an input file: its language, its text, the keys to complete, its first check.
type(code_editor_object), intent(inout) :: ed !< Editor.

call ed%init(code_language('input'))   ! [sections], keys, values, ! and # comments
call ed%set_text(CASE_FILE)
call ed%set_completions(KEYS)          ! typing "rey" offers "reynolds number"
call validate(ed)
endsubroutine start
