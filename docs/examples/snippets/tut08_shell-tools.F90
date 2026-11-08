if (ig_begin_side_bar('tools', 'left', 76.0_real64)) then ! left out of the dock space
   do k = 1_int32, size(PANELS, kind=int32)
      if (ig_tool_button(trim(PANELS(k)), trim(ICONS(k)), width=60.0_real64, selected=current == k)) then
         current = k
         shown(k) = .true.
         if (ig_focus_window(trim(PANELS(k)))) continue ! a docked panel: its tab comes forward
      endif
      call ig_tooltip('Show the '//trim(PANELS(k))//' panel')
   enddo
endif
call ig_end()
