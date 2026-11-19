text = source%text()
open(newunit=u, status='scratch', action='readwrite') ! a namelist is read from a file: the text into one
first = 1_int32
do while (first <= len(text))
   last = index(text(first:), char(10)) + first - 1_int32
   if (last < first) last = len(text) + 1_int32   ! the last line, without a line feed
   write(u, '(A)') text(first:last - 1_int32)
   first = last + 1_int32
enddo
rewind(u)
call read_input(u, new, stat, msg)
close(u)
if (stat /= 0) then
   call app%notify(INPUT_FILE//' does not read: '//msg, kind='error') ! the text stays, to be corrected
   return
endif
call push_undo(inp)
inp = new
edited = .true.
text_edited = .false.
call show_title()
