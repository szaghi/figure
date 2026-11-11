if (ig_markdown('**Case** cylinder, *Re* = 100'//new_line('a')//new_line('a')//'Keys and units: [help](help)', &
                url)) then
   if (url == 'help') shown = .true.                           ! the program's own link
endif
