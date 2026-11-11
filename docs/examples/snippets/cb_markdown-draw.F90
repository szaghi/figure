if (ig_begin('Help', open=shown)) then
   if (help%draw('page', url, height=-30.0_real64)) last = url ! nothing is opened: the program decides
   call ig_text('Last link: '//last)
endif
call ig_end()
