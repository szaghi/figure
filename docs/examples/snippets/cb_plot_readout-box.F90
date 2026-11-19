if (ip_plot_selection(box(1), box(2), box(3), box(4))) then ! a box dragged with the right button
   write(span, '(A,I0,A,I0)') 'iterations ', max(nint(box(1)), 1_int32), ' to ', min(nint(box(2)), N)
   call ip_annotation(box(2), box(4), trim(span), color=AMBER, offset=[8.0_real64, 8.0_real64])
   if (ig_shortcut('enter', scope='global')) then        ! enter: the program takes the box ...
      window = [max(nint(box(1)), 1_int32), min(nint(box(2)), N)]
      call ip_cancel_selection()                         ! ... and ImPlot zooms nothing on the release
   endif
endif
