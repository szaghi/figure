do i = 1_int32, rows
   call ig_push_id(i)                                ! each row's menu has its own id
   if (ig_selectable(trim(names(i)), .false.)) continue
   if (ig_begin_popup_context('row')) then          ! a right click on the row just drawn
      call ig_text_disabled(trim(names(i)))
      call ig_separator()
      if (ig_menu_item('Insert below', enabled=rows < MAX_ROWS)) call ask('insert', i)
      if (ig_menu_item('Duplicate', enabled=rows < MAX_ROWS)) call ask('duplicate', i)
      if (ig_menu_item('Copy name')) call ig_set_clipboard(trim(names(i)))
      if (ig_menu_item('Delete')) call ask('delete', i)
      call ig_end_popup()
   endif
   call ig_same_line(ig_em(8.0_real64))             ! the condition in a column of its own
   call ig_text_disabled(trim(kinds(i)))
   call ig_pop_id()
enddo
call apply()                                       ! the list changes after it is drawn, not while
