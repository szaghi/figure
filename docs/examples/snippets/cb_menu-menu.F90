if (ig_begin_main_menu_bar()) then
   if (ig_begin_menu('File')) then
      if (ig_menu_item('Save', shortcut='Ctrl+S', enabled=edited)) call save()
      if (ig_menu_item('Autosave', selected=autosave)) continue
      call ig_separator()
      if (ig_menu_item('Quit')) running = .false.
      call ig_end_menu()
   endif
   call ig_end_main_menu_bar()
endif
if (ig_shortcut('ctrl+s') .and. edited) call save()     ! every frame, outside the menu
