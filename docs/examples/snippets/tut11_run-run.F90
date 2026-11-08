call ig_begin_disabled(.not. can_run())           ! one run at a time
if (ig_button(ICON_PLAY//' Run')) call start_run()
call ig_end_disabled()
call ig_same_line()
call ig_begin_disabled(.not. solver%running())
if (ig_button(ICON_SQUARE//' Stop')) call solver%kill() ! the solver ends; follow_run tells
call ig_end_disabled()
call ig_same_line()
call ig_text(trim(run_status))
if (ig_begin_child('log', width=380.0_real64)) call output%draw('output') ! only the lines in view
call ig_end_child()
call ig_same_line()
if (size(res) == 0) then
   call ig_text_disabled('The residuals, as the solver prints them.')
elseif (ip_begin_plot('Residuals', width=-1.0_real64, height=-1.0_real64)) then
   call ip_setup_axes('iteration', 'residual', auto_fit=.true., ylog=.true.) ! follows the data as it grows
   call ip_line('residual', iters, res)
   call ip_end_plot()
endif
