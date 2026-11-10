call ig_set_next_item_shortcut('f5', scope='global')               ! f5 presses Run, wherever the focus is
if (ig_button('Run')) then
   runs = runs + 1_int32
   call did('Run pressed')
endif
