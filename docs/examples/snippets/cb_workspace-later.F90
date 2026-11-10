if (show_result) then
   call ig_set_next_window_dock(right)                     ! the node from the layout, the first time only
   if (ig_begin('Result')) then
      call ig_window_dock(node, docked)                    ! where it landed
      call ig_text('the result')
   endif
   call ig_end()
endif
