if (ip_begin_plot('residuals', height=-1.0_real64)) then
   call ip_setup_axes('iteration', 'residual')
   do c = 1_int32, CASES
      if (.not. shown(c)) cycle
      res = exp(-RATE(c) * it)
      call ip_line(trim(NAME(c)), it, res)
   enddo
   if (ip_drop_target('case', payload)) call show(payload, .true.) ! a case dropped here is plotted
   call ip_end_plot()
endif
