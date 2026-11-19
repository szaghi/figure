if (.not. remote) then                            ! a browser's user is not this machine's: nothing kept
   call app%open_prefs('figure-studio')           ! the platform's folder; the panels, the layouts, the style
   call load_prefs()
endif
