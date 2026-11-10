root = ig_dock_id('main')
if (ig_dock_layout_begin(root)) then                    ! the first frame, and after a switch or a reset
   builds = builds + 1_int32
   layout = app%layout()                                ! the one to build
   select case (layout)
   case ('Input')
      call ig_dock_split(root, 'left', 0.5_real64, left, right)
      call ig_dock_window('Case', left)
      call ig_dock_window('Log', right)
   case ('Monitor')
      call ig_dock_split(root, 'left', 0.3_real64, left, right)
      call ig_dock_split(right, 'down', 0.3_real64, bottom, top)
      call ig_dock_window('Case', left)
      call ig_dock_window('Residuals', top)
      call ig_dock_window('Log', bottom)
   endselect
   call ig_dock_layout_end(root)
endif
call ig_dock_space(root)
do w = 1_int32, 3_int32
   if (.not. app%window_visible(trim(PANELS(w)))) cycle   ! draw a registered window while it is shown
   if (ig_begin(trim(PANELS(w)))) call ig_text('the '//trim(PANELS(w)))
   call ig_end()
enddo
