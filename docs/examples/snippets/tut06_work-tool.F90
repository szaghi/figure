call ig_begin_disabled(tool%running())
if (ig_button('Check the grid')) then
   call tool%start([character(len=512) :: me, '--tool'])
   started = .true.
endif
call ig_end_disabled()
if (started) then
   call tool%poll(lines)
   call output%add(lines)
endif
call output%draw('output')
