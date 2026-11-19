if (ig_begin('Help')) then
   if (help%draw('page', link)) then              ! a link clicked: the program decides what it opens
      if (index(link, 'form:') == 1) then          ! the studio's own: form:N, a section of the input, chosen in its tree
         read(link(6:), *) n
         section = n
         call app%set_window_visible('Input', .true.)
         if (ig_focus_window('Input')) continue
      endif
   endif
endif
call ig_end()
