if (ig_begin_menu('Run')) then
   if (ig_menu_item(ICON_PLAY//' Run', shortcut='F5', enabled=can_run())) call start_run()
   if (ig_menu_item(ICON_SQUARE//' Stop', shortcut='Shift+F5', enabled=solver%running())) call solver%kill()
   call ig_end_menu()
endif
