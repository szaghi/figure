call ip_plot_limits(xa, xb, ylo, yhi)                    ! the window spans the plot's height
if (ip_drag_rect(1_int32, x0, x1, ylo, yhi, color=AMBER)) then
   x0 = max(x0, 1.0_real64)                               ! kept on the data
   x1 = min(x1, real(N, real64))
endif
first = max(1_int32, ceiling(x0))
last = min(N, floor(x1))
if (last >= first) then
   mean = sum(cl(first:last)) / real(last - first + 1_int32, real64)
   call ip_line('mean', [x0, x1], [mean, mean], spec=ip_spec(line_color=AMBER, line_weight=2.0_real64))
   write(text, '(A,F6.4)') 'mean ', mean
   call ip_tag('y1', mean, color=AMBER, text=trim(text))
endif
