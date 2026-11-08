pending_action = action
pending_dir = ''
if (present(dir)) pending_dir = dir
if (edited) then
   ask_discard = .true.                           ! the question is opened at the top level, in draw_dialogs
else
   call go_on()
endif
