if (ip_begin_plot('cost per case', height=170.0_real64)) then  ! group g: case g; item i: phase i
   call ip_setup_axes('case', 'seconds')
   call ip_bar_groups(PHASE, COST, group_size=0.7_real64)
   call ip_end_plot()
endif
if (ip_begin_plot('cost per case, stacked', height=170.0_real64)) then
   call ip_setup_axes('case', 'seconds')
   call ip_bar_groups(PHASE, COST, stacked=.true.)
   call ip_end_plot()
endif
