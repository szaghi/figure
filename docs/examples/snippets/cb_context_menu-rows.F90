do i = 1_int32, rows
   call ig_push_id(i)                                ! each row's menu has its own id
   if (ig_selectable(trim(names(i)), .false.)) continue
   if (check) call test_item_center(row_at(1, i), row_at(2, i))
   if (ig_begin_popup_context('row')) then          ! a right click on the row just drawn
      call ig_text_disabled(trim(names(i)))
      call ig_separator()
      if (ig_menu_item('Insert below', enabled=rows < MAX_ROWS)) call ask('insert', i)
      call keep_entry(1)                             ! --check: where the entry is
      if (ig_menu_item('Duplicate', enabled=rows < MAX_ROWS)) call ask('duplicate', i)
      call keep_entry(2)
      if (ig_menu_item('Copy name')) call ig_set_clipboard(trim(names(i)))
      call keep_entry(3)
      if (ig_menu_item('Delete')) call ask('delete', i)
      call keep_entry(4)
      call ig_end_popup()
   endif
   if (ig_begin_item_tooltip()) then                ! the pointer rests on the row
      tooltip = .true.
      if (ig_begin_table('values', 2_int32)) then
         call cell('patch', trim(names(i)))
         call cell('condition', trim(kinds(i)))
         write(label, '(F0.1)') values(i)
         call cell('value', trim(label))
         call ig_end_table()
      endif
      call ig_end_tooltip()
   endif
   call ig_same_line(ig_em(8.0_real64))             ! the condition in a column of its own
   call ig_text_disabled(trim(kinds(i)))
   call ig_pop_id()
enddo
call apply()                                       ! the list changes after it is drawn, not while
