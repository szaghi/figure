if (ig_begin_child('sections', width=160.0_real64, border=.true.)) then
   do k = 1_int32, size(SECTIONS, kind=int32)
      if (ig_selectable(trim(SECTIONS(k)), k == current)) current = k  ! the program keeps the selection
   enddo
endif
call ig_end_child()
call ig_same_line()
if (ig_begin_child('section')) then                ! the rest of the window
   call ig_text(trim(SECTIONS(current)))
   call ig_separator()
   call ig_text('grid file')
   call ig_same_line(offset=160.0_real64)            ! the values in one column
   call ig_text_disabled('CC/cc (default)')
   call ig_text('levels')
   call ig_same_line(offset=160.0_real64)
   call ig_text_colored('[!!] 0: must be at least 1', [0.90_real64, 0.35_real64, 0.30_real64])
   call ig_separator()
   call ig_text_wrapped(trim(HELP(current)))         ! wraps at the region's width
endif
call ig_end_child()
