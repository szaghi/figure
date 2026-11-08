if (ig_begin_menu('Edit')) then
   if (ig_menu_item(ICON_UNDO//' Undo', shortcut='Ctrl+Z', enabled=nhistory > 0_int32)) call undo()
   call ig_end_menu()
endif
