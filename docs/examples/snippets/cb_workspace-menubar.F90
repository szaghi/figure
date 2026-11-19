if (ig_begin('Case', flags=ImGuiWindowFlags_MenuBar)) then     ! the window has a bar of its own
   if (ig_begin_menu_bar()) then
      if (ig_menu_item('Reload')) continue                  ! an item in the bar, or a menu (ig_begin_menu)
      call ig_end_menu_bar()                                ! only after a true ig_begin_menu_bar
   endif
   call ig_text('the case')
endif
call ig_end()
