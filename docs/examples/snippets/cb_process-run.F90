call ig_begin_disabled(tool%running())                   ! one run at a time
if (ig_button(ICON_PLAY//' Run')) then
   call output%clear()
   call tool%start([character(len=512) :: me, '--tool'])  ! the program and its arguments: no shell
   started = .true.
endif
call ig_end_disabled()
call ig_same_line()
call ig_begin_disabled(.not. tool%running())
if (ig_button(ICON_SQUARE//' Stop')) call tool%kill()
call ig_end_disabled()
call ig_same_line()
if (started) then
   call tool%poll(lines)                                 ! the complete lines since the last frame
   call output%add(lines)
   if (tool%running()) then
      write(status, '(A,I0)') 'running, pid ', tool%pid()
   elseif (tool%killed()) then
      status = 'stopped'
   else
      write(status, '(A,I0)') 'ended, exit code ', tool%exit_code()
   endif
   call ig_text(trim(status))
else
   call ig_text_disabled('not started')
endif
call output%draw('output')                               ! only the lines in view; follows the end
