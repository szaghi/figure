if (ig_button('Options')) call ig_open_popup('options') ! once, on the click
if (ig_begin_popup('options')) then                     ! every frame; closes on a click outside
   if (ig_checkbox('verbose output', verbose)) continue
   call ig_end_popup()
endif
