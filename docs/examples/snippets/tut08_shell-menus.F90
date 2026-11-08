if (ig_begin_main_menu_bar()) then
   if (ig_begin_menu('File')) then
      if (ig_menu_item(ICON_POWER_SQUARE//' Quit', shortcut='Ctrl+Q')) ask_quit = .true.
      call ig_end_menu()
   endif
   if (ig_begin_menu('View')) then
      do k = 1_int32, size(PANELS, kind=int32)
         if (ig_menu_item(trim(PANELS(k)), selected=shown(k))) continue ! a pick toggles the check mark
      enddo
      call ig_separator()
      if (ig_begin_menu(ICON_LAYOUT//' Look')) then
         do k = 1_int32, size(LOOKS, kind=int32)
            on = look == LOOKS(k)
            if (ig_menu_item(trim(LOOKS(k)), selected=on)) call set_look(trim(LOOKS(k)))
         enddo
         call ig_end_menu()
      endif
      if (ig_begin_menu(ICON_PALETTE//' Palette')) then
         do k = 1_int32, size(PALETTES, kind=int32)
            on = palette == PALETTES(k)
            if (ig_menu_item(trim(PALETTES(k)), selected=on)) call set_palette(trim(PALETTES(k)))
         enddo
         call ig_end_menu()
      endif
      call ig_separator()
      if (ig_menu_item('Reset layout', enabled=have_default)) call app%load_layout(DEFAULT_LAYOUT)
      call ig_end_menu()
   endif
   if (ig_begin_menu('Help')) then
      if (ig_menu_item(ICON_INFO//' About', shortcut='F1')) about = .true.
      call ig_end_menu()
   endif
   call ig_end_main_menu_bar()
endif
if (ig_shortcut('ctrl+q')) ask_quit = .true.    ! every frame, outside the menus: cmd+q on macOS
if (ig_shortcut('f1')) about = .true.
