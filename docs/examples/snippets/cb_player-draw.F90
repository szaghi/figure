if (ig_player('snapshots', player, labels=times)) then
   if (check) write(output_unit, '(A,I0,A,I0,A)') 'frame ', frame, ': snapshot ', player%index, &
                                                  ' ('//trim(times(player%index))//')'
endif
call ig_item_rect(at(1), at(2), at(3), at(4))
call ig_text_disabled('right click on the player: speed and mode')
if (ip_begin_plot('u(x)', height=-1.0_real64)) then
   call ip_setup_axes('x [m]', 'u [m/s]')
   call ip_setup_axes_limits(0.0_real64, 1.0_real64, -0.1_real64, 1.1_real64)
   call ip_line('u', x, u(:, player%index))     ! the snapshot the player shows
   call ip_end_plot()
endif
