recolour = .true.                                 ! ip_field_image does not see a change in place: the program says
if (player%index > size(snap_iters)) then
   shown_field = coarse
   return
endif
