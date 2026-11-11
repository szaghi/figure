if (ig_checkbox('clip', cut)) then
   if (cut) then                                  ! a plane across the plate at the probe line, keeping x < probe
      plane = 0.0_real64                          ! columns: the plane's two axes, its normal, its point
      plane(1:3, 1) = [0.0_real64, 0.0_real64, 1.0_real64]
      plane(1:3, 2) = [0.0_real64, 1.0_real64, 0.0_real64]
      plane(1:3, 3) = [-1.0_real64, 0.0_real64, 0.0_real64]
      plane(1:4, 4) = [probe_x, 0.5_real64 * fly, 0.0_real64, 1.0_real64]
      call clip()
   else
      call view%unclip()
   endif
endif
