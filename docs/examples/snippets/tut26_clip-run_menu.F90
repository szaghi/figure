if (ig_begin_popup_context('run')) then            ! a right click on the row
   write(text, '(ES12.5)') runs(k)%residual
   if (ig_menu_item('Copy the residual')) call ig_set_clipboard(trim(adjustl(text)))
   if (ig_menu_item('Remove from the list')) remove = k
   call ig_end_popup()
endif
if (ig_begin_item_tooltip()) then                  ! the pointer rests on the row: its residuals
   if (ip_begin_plot('##history', width=ig_em(18), height=ig_em(10))) then
      call ip_setup_axes('iteration', 'residual', yscale='log')
      call ip_line('residual', runs(k)%it, runs(k)%res)
      call ip_end_plot()
   endif
   call ig_end_tooltip()
endif
