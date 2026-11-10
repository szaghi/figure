call ig_set_next_item_width(width)
if (ig_drag('gravity', g, speed=0.01_real64, vmin=-50.0_real64, vmax=50.0_real64, format='%.2f m/s²')) then
   continue                                     ! g changed: the program reacts here
endif
call ig_item_rect(g_at(1), g_at(2), g_at(3), g_at(4))
call ig_set_next_item_width(width)
if (ig_input('probe', probe, format='%.3f m')) continue
call ig_item_rect(probe_at(1), probe_at(2), probe_at(3), probe_at(4))
call ig_set_next_item_width(width)
if (ig_slider_angle('wind from', wind, 0.0_real64, 360.0_real64)) continue ! radians, shown in degrees
