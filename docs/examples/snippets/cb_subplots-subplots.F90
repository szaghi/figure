if (ip_begin_subplots('##forces', 2_int32, 1_int32, height=-1.0_real64, link_x=.true.)) then
   if (ip_begin_plot('drag')) then
      call ip_setup_axes('time', 'Cx', yformat='%.4f')   ! the default would print -3781.31 on every tick
      call ip_line('Cx', t, drag)
      call ip_end_plot()
   endif
   if (ip_begin_plot('pitching moment')) then
      call ip_setup_axes('time', 'CMy')
      call ip_line('CMy', t, moment)
      call ip_end_plot()
   endif
   call ip_end_subplots()
endif
