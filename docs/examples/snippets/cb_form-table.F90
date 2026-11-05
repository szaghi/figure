if (ig_begin_tab('Boundary conditions')) then
   if (ig_begin_table('patches', 3_int32)) then
      call ig_table_setup_column('face', width=90.0_real64)
      call ig_table_setup_column('condition')
      call ig_table_setup_column('block', width=70.0_real64)
      call ig_table_headers_row()
      do r = 1_int32, nrows
         call ig_push_id(r)                     ! every row repeats the same widgets
         call ig_table_next_row()
         call ig_table_next_column()
         call ig_set_next_item_width(-1.0_real64)
         if (ig_combo('##face', face(r), FACES)) continue
         call ig_table_next_column()
         call ig_set_next_item_width(-1.0_real64)
         if (ig_combo('##kind', cond(r), KINDS)) continue
         call ig_table_next_column()
         call ig_set_next_item_width(-1.0_real64)
         if (ig_input_text('##block', block_id(r))) continue
         call ig_pop_id()
      enddo
      call ig_end_table()
   endif
   if (ig_button('add a row') .and. nrows < MAX_ROWS) nrows = nrows + 1_int32
   call ig_end_tab()
endif
