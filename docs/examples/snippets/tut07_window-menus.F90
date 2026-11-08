if (ig_begin_main_menu_bar()) then                ! inside the title bar, after the icon
   if (ig_begin_menu('File')) then
      if (ig_menu_item('Quit')) ask_quit = .true.  ! the same question as the close button, asked below
      call ig_end_menu()
   endif
   call ig_end_main_menu_bar()
endif
