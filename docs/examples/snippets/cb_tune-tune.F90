call ig_show_style_editor()                          ! every colour and size, live
call ig_set_next_window(20.0_real64, 20.0_real64, 520.0_real64, 400.0_real64)
if (ig_begin('Sample')) then
   if (ig_button('Save theme')) then
      call app%save_style('my-theme.toml', stat=stat) ! what differs from the base, as a theme file
      if (stat == 0_int32) then
         saved = 'saved to my-theme.toml'
      else
         saved = 'cannot write my-theme.toml'
      endif
   endif
   call ig_text(trim(saved))
