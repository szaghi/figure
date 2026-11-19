if (shown(1)) then
   if (ig_begin('Case', open=shown(1))) call ig_text_disabled('No case open.') ! open: the tab gets a close button
   call ig_end()
endif
