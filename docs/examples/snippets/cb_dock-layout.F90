root = ig_dock_id('main')
if (ig_dock_layout_begin(root)) then                       ! the first frame only: no layout yet
   call ig_dock_split(root, 'left', 0.3_real64, left, right) ! controls | the rest
   call ig_dock_split(right, 'down', 0.25_real64, log, plot) ! the rest: plot above, log below
   call ig_dock_window('Controls', left)
   call ig_dock_window('Plot', plot)
   call ig_dock_window('Log', log)
   call ig_dock_layout_end(root)
endif
call ig_dock_space(root)                                   ! every frame, before the windows
