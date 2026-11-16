if (ip_begin_aligned('history')) then                 ! the plot areas start at the same pixel
   if (ip_begin_plot('residual', height=160.0_real64)) then
      call ip_setup_axes('', 'residual')
      call ip_link_axis('x1', 'iteration')            ! pan or zoom one: the three follow
      call ip_line('residual', it, res)
      call ip_end_plot()
   endif
   if (ip_begin_plot('cfl', height=160.0_real64)) then
      call ip_setup_axes('', 'CFL')
      call ip_link_axis('x1', 'iteration')
      call ip_line('CFL', it, cfl)
      call ip_end_plot()
   endif
   if (ip_begin_plot('forces', height=-1.0_real64)) then
      call ip_setup_axes('iteration', 'coefficient')
      call ip_link_axis('x1', 'iteration')
      call ip_line('lift', it, cl)
      call ip_hide_next_item(.not. show_cd, always=.true.) ! the program decides, every frame
      call ip_line('drag', it, cd)
      if (ip_begin_legend_popup('drag')) then         ! a right click on the entry
         write(line, '(A,F7.4)') 'last value ', cd(N)
         call ig_text(trim(line))
         if (ig_checkbox('shown', show_cd)) continue
         call ip_end_legend_popup()
      endif
      if (ip_legend_hovered('lift')) then               ! the pointer on the entry
         if (ig_begin_tooltip()) then
            call ig_text('lift: the force normal to the flow, over q S')
            call ig_end_tooltip()
         endif
      endif
      call ip_end_plot()
   endif
   call ip_end_aligned()
endif
