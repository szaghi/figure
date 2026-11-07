call ig_begin_disabled(reader%running())
if (ig_button(ICON_FOLDER_OPEN//' Read')) call reader%start(read_field, field_stats(file=FILE))
call ig_end_disabled()
call ig_same_line()
call ig_begin_disabled(.not. reader%running())
if (ig_button(ICON_X//' Cancel')) call reader%cancel()  ! the task stops at its next block
call ig_end_disabled()
if (reader%running()) then
   call reader%progress(fraction, msg)
   write(line, '(F5.1,A,A)') 100.0_real64 * max(fraction, 0.0_real64), ' %  ', msg
   call ig_text(trim(line))
elseif (reader%done()) then                           ! ended: take the result once
   call reader%result(data)
   select type (data)
   type is (field_stats)
      stats = data
      have = .true.
   endselect
endif
call ig_separator()
if (have) then
   write(line, '(A,I0,A)') 'values ', stats%values, ' read'
   call ig_text(trim(line))
   write(line, '(A,F8.4,A,F8.4,A,F8.4)') 'min ', stats%vmin, '   max ', stats%vmax, '   mean ', stats%mean
   call ig_text(trim(line))
else
   call ig_text_disabled('no field read yet')
endif
