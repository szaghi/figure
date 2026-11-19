root = ig_dock_id('studio')
if (ig_dock_layout_begin(root)) then              ! the first frame, after a switch of layout and after a reset
   call ig_dock_split(root, 'left', 0.25_real64, left, right)
   call ig_dock_window('Case', left)
   select case (app%layout())                     ! the one the user chose
   case ('Setup')                                 ! the input in front, the run below
      call ig_dock_split(right, 'down', 0.45_real64, run, work)
      call ig_dock_window('3-D', work)
      call ig_dock_window('Result', work)
      call ig_dock_window('Input', work)
      call ig_dock_window('Run', run)
      call ig_dock_window('Messages', run)
   case ('Analysis')                              ! the result and the 3-D view side by side
      call ig_dock_split(right, 'down', 0.35_real64, run, work)
      call ig_dock_split(work, 'right', 0.45_real64, view3, left)
      call ig_dock_window('Input', left)          ! hidden here: a tab beside Result once shown
      call ig_dock_window('Result', left)
      call ig_dock_window('3-D', view3)
      call ig_dock_window('Run', run)
      call ig_dock_window('Messages', run)
   endselect
   call ig_dock_layout_end(root)
   laid_out = .true.
endif
call ig_dock_space(root)
