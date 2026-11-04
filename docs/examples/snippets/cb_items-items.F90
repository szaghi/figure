call ip_shaded('spread', x, y - s, y + s)                                ! band between two curves
call ip_line('signal', x, y, spec=signal)                                ! styled line
call ip_scatter('samples', x(::5), y(::5), spec=samples)                 ! markers only
call ip_bars('counts', real(x, real32), counts, 0.15_real64)             ! real32 data, bar width in x units
call ip_shaded('to zero', x, y, 0.0_real64, spec=ip_spec(fill_alpha=0.25_real64))    ! curve to y = 0
call ip_scatter('squares', x(1:3), y(1:3), spec=ip_spec(marker=ImPlotMarker_Square))
