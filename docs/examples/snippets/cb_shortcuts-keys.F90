if (ig_shortcut('down')) call did('down: next block', sel + 1_int32) ! this window, not while a field is edited
if (ig_shortcut('up')) call did('up: previous block', sel - 1_int32)
if (ig_shortcut('ctrl+s')) call did('ctrl+s: the blocks saved')     ! only when this window has the focus
