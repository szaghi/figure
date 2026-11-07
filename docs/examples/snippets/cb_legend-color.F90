if (ig_color_edit('contour lines', line_color)) then ! true on the frames the user changes it
   write(text, '(A,4F6.2)') 'changed to', line_color  ! line_color is updated: the lines below use it
endif
call ig_text(trim(text))
