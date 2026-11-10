hovered = ip_plot_hovered()
if (hovered) then
   call ip_plot_mouse(x, y)                               ! the pointer in plot units
   k = min(max(nint(x), 1_int32), N)                      ! the nearest iteration
   call ip_inf_lines('##cursor', [k], spec=cursor)        ! a line across the plot, at an integer
   call ip_scatter('##point', it(k:k), residual(k:k), spec=dot)
   write(text, '(ES9.2)') residual(k)
   call ip_tag('x1', it(k), color=AMBER)                  ! the iteration, as the axis labels it
   call ip_annotation(it(k), residual(k), trim(adjustl(text)), color=AMBER, &
                      offset=[40.0_real64, -24.0_real64])         ! the residual beside the dot
   shown = k
endif
