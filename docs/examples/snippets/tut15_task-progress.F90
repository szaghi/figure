if (loader%running()) then                        ! every frame while it reads: the window never waits for it
   call loader%progress(fraction, msg)
   call ig_progress_bar(fraction, label=msg, width=300.0_real64)
   call ig_same_line()
   if (ig_button(ICON_SQUARE//' Stop')) then
      load_cancelled = .true.
      call loader%cancel()                        ! the task stops at its next safe point
   endif
   return
endif
