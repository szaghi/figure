if (ig_begin_popup_context('list', on='window')) then ! the window's empty space, not over a row
   if (ig_menu_item('Add a row', enabled=rows < MAX_ROWS)) call ask('add', rows)
   call keep_entry(1)
   call ig_end_popup()
endif
call apply()
