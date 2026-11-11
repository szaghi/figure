call app%view_menu()                           ! the panels, the layouts, Reset layout
if (ig_begin_menu('View')) then                ! the same menu again: the studio's items follow FIGURE's
   call ig_separator()
   if (ig_menu_item('Larger text', selected=large_text)) then
      call set_text_size()
      call app%save_pref('larger text', large_text)
   endif
