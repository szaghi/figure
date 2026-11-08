if (save_default) then                                    ! the frame after the layout was set
   call app%save_layout(DEFAULT_LAYOUT, comment='the studio as the program lays it out')
   if (ig_focus_window('Input')) continue                 ! of the two tabs, Input in front
   have_default = .true.
   save_default = .false.
endif
root = ig_dock_id('studio')
if (ig_dock_layout_begin(root)) then                      ! no layout yet: the first run, or no ini file
   call ig_dock_split(root, 'left', 0.25_real64, left, right)
   call ig_dock_split(right, 'down', 0.35_real64, run, work)
   call ig_dock_window('Case', left)
   call ig_dock_window('Result', work)
   call ig_dock_window('Input', work)                     ! the same node: Result and Input are tabs
   call ig_dock_window('Run', run)
   call ig_dock_layout_end(root)
   save_default = .true.
endif
call ig_dock_space(root)                                  ! every frame, after the bars, before the panels
