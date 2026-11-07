if (app%dropped(paths, x, y)) then              ! this frame only; the panes' rectangles are the last frame's
   if (inside(case_rect, x, y)) then
      case_dir = trim(paths(1))                 ! the case: the first path dropped on its pane
      copied = .false.
   elseif (inside(files_rect, x, y)) then
      do k = 1_int32, size(paths, kind=int32)   ! the files: every path dropped on theirs
         if (nfiles == MAX_FILES) exit
         nfiles = nfiles + 1_int32
         files(nfiles) = paths(k)
      enddo
   endif
endif
if (ig_begin_child('case', width=340.0_real64, height=-40.0_real64, border=.true.)) then
   call ig_text(ICON_FOLDER//' Case')
   if (len(case_dir) == 0) then
      call ig_text_disabled('drop a case folder here')
   else
      call ig_text(case_dir)
   endif
endif
call ig_end_child()
call ig_item_rect(case_rect(1), case_rect(2), case_rect(3), case_rect(4))
call ig_same_line()
if (ig_begin_child('files', height=-40.0_real64, border=.true.)) then
   call ig_text(ICON_FILE//' Files')
   if (nfiles == 0_int32) call ig_text_disabled('drop files here')
   do k = 1_int32, nfiles
      call ig_text(trim(files(k)))
   enddo
endif
call ig_end_child()
call ig_item_rect(files_rect(1), files_rect(2), files_rect(3), files_rect(4))
