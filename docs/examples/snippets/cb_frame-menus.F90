if (ig_begin_main_menu_bar()) then                    ! inside the title bar, after the icon
   if (ig_begin_menu('File')) then
      if (ig_menu_item('Open...', shortcut='Ctrl+O')) continue
      if (ig_menu_item('Save', shortcut='Ctrl+S')) continue
      call ig_separator()
      if (ig_menu_item('Quit')) running = .false.
      call ig_end_menu()
   endif
   if (ig_begin_menu('View')) then
      if (ig_menu_item('Residuals', selected=viscous)) continue
      call ig_end_menu()
   endif
   call ig_end_main_menu_bar()
endif
