call ig_canvas('domain', 0.0_real64, 200.0_real64, ev)  ! the window's width, 200 pixels high
scale = (ev%size(1) - 80.0_real64) / 4.0_real64        ! 4 m across, 40 pixels free each side
hovered = 0_int32
if (ev%hovered) hovered = nearest(ev%mouse(1), ev%mouse(2))
if (ev%clicked(1)) selected = hovered                  ! a click on empty space clears the selection
if (hovered > 0_int32) then
   if (ig_begin_tooltip()) then
      call ig_text(trim(BOUNDARY(hovered))//': '//trim(CONDITION(bc(hovered)))//' (click to change)')
      call ig_end_tooltip()
   endif
endif
