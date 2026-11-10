bar_px = ig_em(5)                                 ! 5 em: 75 pixels at 15, 95 at 19
if (ig_begin_side_bar('tools', 'left', bar_px)) then
   do k = 1_int32, size(PANELS, kind=int32)
      if (ig_tool_button(trim(PANELS(k)), trim(ICONS(k)), width=ig_em(4), selected=current == k)) then
         current = k
         shown(k) = .true.
         if (ig_focus_window(trim(PANELS(k)))) continue
      endif
      call ig_tooltip('Show the '//trim(PANELS(k))//' panel')
   enddo
endif
call ig_end()
