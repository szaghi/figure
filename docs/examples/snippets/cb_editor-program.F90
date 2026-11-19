call ed%set_options(whitespace=.true., tab_size=3_int32) ! blanks shown as dots, a tab 3 columns
call ed%select(3_int32, 2_int32, 3_int32, 13_int32)      ! line 3, columns 2 to 12
if (ed%selection(l0, c0, l1, c1, text=chosen)) write(output_unit, '(A)') 'selected: "'//chosen//'"'
call ed%goto(ed%line_count(), 1_int32)                   ! the last line, empty
call ed%insert(' grid file = naca0012.grd')              ! one change: one undo
call validate(ed)
write(output_unit, '(I0,A,A)') ed%line_count(), ' lines, the word at the cursor: ', ed%word_at_cursor()
if (ed%undo()) write(output_unit, '(A,I0,A)') 'undone: ', ed%line_count(), ' lines'
if (ed%redo()) write(output_unit, '(A)') 'redone: "'//line_of(ed%line_count())//'"'
call ed%set_language(code_language('fortran'))          ! the text, its marks and its undo history kept
call ed%set_language(code_language('input'))
call ed%focus()                                          ! the keyboard to the editor at the next draw
call frames()
if (ed%line_rect(2_int32, x0, y0, x1, y1)) write(output_unit, '(A,L1)') 'line 2 in view, below line 1: ', y0 > 0.0_real64
write(output_unit, '(A,L1)') 'read-only: ', ed%is_read_only()
