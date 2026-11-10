if (ip_begin_plot('history', height=-1.0_real64)) then
   call ip_setup_axes('t', 'x')
   call ip_line('x', t, x)
   call ip_end_plot()
endif
call ig_item_rect(r(1), r(2), r(3), r(4))               ! the plot just drawn
if (save_now) call app%save_image('history.png', r(1), r(2), r(3), r(4), stat=stat)
call app%image_result(written, done, stat=stat)         ! every frame: done once, after the write
if (done) then
   if (stat == FIG_OK) then
      message = 'saved '//written
   else
      message = figure_last_error()                     ! FIG_ERR_FAILED: the file cannot be written
   endif
endif
