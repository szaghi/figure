if (ip3_begin_plot('trajectory', height=-30.0_real64)) then
   call ip3_setup_axes('x', 'y', 'z', auto_fit=.true., elevation=15.0_real64, azimuth=-45.0_real64)
   call ip3_scatter('now', path(1, n:n), path(2, n:n), path(3, n:n), &
                    spec=ip3_spec(marker=ImPlot3DMarker_Circle, marker_size=5.0_real64))
   call ip3_line('path', path(1, 1:n), path(2, 1:n), path(3, 1:n), &      ! rows: read in place
                 spec=ip3_spec(line_color=RED, line_weight=1.5_real64))
   call ip3_end_plot()
endif
call ig_text('points: '//itoa(n)//'   (right drag: turn; left drag: pan; wheel: zoom)')
