if (ig_begin_main_menu_bar()) then
   if (ig_begin_menu('File')) then
      if (ig_menu_item('Quit')) call app%quit()
      call ig_end_menu()
   endif
   call ig_end_main_menu_bar()
endif
if (ig_begin_side_bar('Tools', 'left', 80.0_real64)) then  ! 'left', 'right', 'top' or 'bottom'
   if (ig_tool_button('Input', ICON_FILE_PEN, selected=tool == 1)) tool = 1
   if (ig_tool_button('Monitor', ICON_ACTIVITY, selected=tool == 2)) tool = 2
endif
call ig_end()                                              ! always, as for any window
root = ig_dock_id('main')
if (ig_dock_layout_begin(root)) then
   call ig_dock_split(root, 'left', 0.4_real64, left, right)
   call ig_dock_window('Case', left)
   call ig_dock_layout_end(root)
endif
call ig_dock_space(root)                                   ! fills what the bars leave
