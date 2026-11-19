centre = [inp%body_x, inp%body_y]
if (ig_drag('centre x, y [m]', centre, speed=0.002_real64, vmin=0.0_real64, vmax=max(inp%lx, inp%ly), &
            format='%.3f')) then                ! one box per component, dragged or typed
   inp%body_x = centre(1)
   inp%body_y = centre(2)
   changing = .true.
endif
