if (ig_begin_menu('File')) then
   if (ig_menu_item(ICON_FOLDER_OPEN//' Open case...', shortcut='Ctrl+O')) call browse_case()
   if (ig_menu_item('Open case with the system''s dialog...')) then
      call app%open_folder_dialog('case', default_path=start_dir, stat=stat)
      if (stat /= FIG_OK) call browse_case()      ! no desktop (remote mode): FIGURE's browser
   endif
   if (ig_begin_menu(ICON_HISTORY//' Recent cases', enabled=nrecent > 0_int32)) then
      do k = 1_int32, nrecent
         if (ig_menu_item(trim(recent(k)))) call request('open', trim(recent(k)))
      enddo
      call ig_end_menu()
   endif
   if (ig_menu_item(ICON_SAVE//' Save', shortcut='Ctrl+S', enabled=edited)) call save_case()
   call ig_separator()
   if (ig_menu_item(ICON_POWER_SQUARE//' Quit', shortcut='Ctrl+Q')) ask_quit = .true.
   call ig_end_menu()
endif
