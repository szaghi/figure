call ig_set_next_item_shortcut('f5', scope='global') ! the button owns F5, wherever the focus is; its tooltip says so
if (ig_button(ICON_PLAY//' Run')) call start_run()
