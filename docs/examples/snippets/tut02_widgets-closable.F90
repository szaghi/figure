if (show_tools) then
   call ig_set_next_window(460.0_real64, 20.0_real64, 300.0_real64, 120.0_real64)
   if (ig_begin('Tools', show_tools)) then
      call ig_text('Close me with the x in the title bar.')
   endif
   call ig_end()
endif
if (show_demo) call ig_show_demo_window(show_demo)
