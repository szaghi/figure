if (app%next_frame(stat=stat)) then               ! a frame with a mistake in it
   call draw_studio()
   call ig_end_tab()                              ! a stray end: no tab is open here
endif
if (app%next_frame(stat=stat)) call draw_studio() ! the next frame reports it, and the studio goes on
call check(stat == FIG_ERR_STATE .and. index(figure_last_error(), 'ig_end_tab: no ig_begin_tab is open') > 0, &
           'a stray ig_end_tab is reported by the next frame, naming the call')
write(output_unit, '(A)') '         '//figure_last_error()
