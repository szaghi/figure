if (source%draw('heat.inp', height=-ig_frame_height())) then ! the user changed the text: check it again
   text_edited = .true.
   call validate()
endif
call source%cursor(line, column)
write(where, '(A,I0,A,I0)') 'line ', line, ', column ', column
call ig_text_disabled(trim(where))
