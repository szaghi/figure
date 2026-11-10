if (ig_selectable(trim(SIDES(k)), .false.)) continue
if (ig_begin_popup_context('side')) then  ! a right click on the side's name
   if (ig_menu_item('Every side as this one')) then
      inp%bc_kind = inp%bc_kind(k)
      inp%bc_value = inp%bc_value(k)
      changing = .true.
   endif
   if (ig_menu_item('Insulated', enabled=inp%bc_kind(k) /= KINDS(2))) then
      inp%bc_kind(k) = KINDS(2)
      changing = .true.
   endif
   call ig_end_popup()
endif
