call source%clear_marks()
text_errors = 0_int32
text = source%text()
call mark_names(text)                             ! a mark per unknown name, on its line
if (text_errors > 0_int32) return
call read_text(text, new, stat, msg)
if (stat /= 0) then                               ! a value that does not read: the run time says which
   call source%mark(max(1_int32, line_of(text, '&heat')), 'error', msg)
   text_errors = 1_int32
   return
endif
list = problems(new)
ids = problem_ids(new)
do k = 1_int32, size(list, kind=int32)            ! the input reads: what the solver would refuse
   call source%mark(max(1_int32, line_of(text, trim(NAME_OF(ids(k))))), 'error', trim(list(k)))
   text_errors = text_errors + 1_int32
enddo
