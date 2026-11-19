if (ip_drag_line_x(1_int32, window(1), thickness=2.0_real64)) window_moved = .true. ! the window's two ends,
if (ip_drag_line_x(2_int32, window(2), thickness=2.0_real64)) window_moved = .true. ! updated in place
window = [minval(window), maxval(window)]
inside = any(steps >= window(1) .and. steps <= window(2))
if (inside) then
   window_mean = sum(means, mask=steps >= window(1) .and. steps <= window(2)) / &
                 count(steps >= window(1) .and. steps <= window(2))
   call ip_tag('y2', window_mean, text='mean '//num(window_mean)) ! on the axis, in the last item's colour
endif
