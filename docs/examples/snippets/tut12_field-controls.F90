call ig_set_next_item_width(140.0_real64)
if (ig_combo('colormap', map, MAPS)) continue
call ig_same_line()
call ig_set_next_item_width(140.0_real64)
if (ig_slider('bands', bands, 0_int32, 16_int32)) bands = merge(0_int32, bands, bands == 1_int32) ! 0: continuous
call ig_same_line()
if (ig_checkbox('contour lines', contours)) continue
if (MAPS(map) == 'Jet') then                      ! a mark with the colour: never colour alone
   call ig_same_line()
   call ig_text_colored(ICON_TRIANGLE_ALERT//' Jet: not perceptually uniform', &
                        [0.95_real64, 0.75_real64, 0.2_real64, 1.0_real64])
endif
if (bands > 0_int32) then
   cmap = ip_colormap(trim(MAPS(map)), levels=bands) ! the same map in discrete bands
else
   cmap = ip_colormap(trim(MAPS(map)))
endif
