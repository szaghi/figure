if (ig_begin('Files')) then
   if (ig_begin_child('tree', sizes(1), 0.0_real64, border=.true.)) call ig_text('the tree')
   call ig_end_child()
   call ig_same_line()
   if (ig_splitter('split', sizes)) continue          ! true while dragged: sizes changed
   call ig_same_line()
   if (ig_begin_child('view', sizes(2), 0.0_real64, border=.true.)) call ig_text('the file')
   call ig_end_child()
endif
call ig_end()
