if (ig_button(ICON_PLAY//' Run')) runs = runs + 1_int32
call ig_same_line()
call ig_text(ICON_TRIANGLE_ALERT//' 3 warnings')
call ig_push_font('', 32.0_real64)                      ! a big icon, alone: the current font, larger
call ig_text(ICON_CHART_LINE)
call ig_pop_font()
