if (ig_begin_table('grids', 3_int32)) then
   call ig_table_setup_column('grid')
   call ig_table_setup_column('cells', width=90.0_real64)
   call ig_table_setup_column('first patch', width=110.0_real64)
   call ig_table_headers_row()
   do b = 1_int32, BODIES
      call ig_table_next_row()
      call ig_table_next_column()
      open = ig_tree_node(trim(BODY(b)), default_open=(b == 1_int32), span_all_columns=.true.)
      call ig_table_next_column()
      write(line, '(I0)') sum(CELLS(FIRST(b):LAST(b)))     ! the body's values, open or not
      call ig_text(trim(line))
      if (open) then
         do k = FIRST(b), LAST(b)                          ! the children: one row each
            call ig_push_id(k)
            call ig_table_next_row()
            call ig_table_next_column()
            write(line, '(A,I0)') 'block ', k
            if (ig_tree_node(trim(line), leaf=.true., selected=(k == chosen), span_all_columns=.true., &
                             clicked=clicked)) call ig_tree_pop()
            if (clicked) chosen = k                         ! a click on the row chooses, the arrow expands
            call ig_table_next_column()
            write(line, '(I0)') CELLS(k)
            call ig_text(trim(line))
            call ig_table_next_column()
            call ig_text(trim(PATCH(k)))
            call ig_pop_id()
         enddo
         call ig_tree_pop()                                ! only after a true node
      endif
   enddo
   call ig_end_table()
endif
if (chosen > 0_int32) then
   write(line, '(A,I0,A,I0,A)') 'block ', chosen, ' chosen: ', CELLS(chosen), ' cells'
   call ig_text(trim(line))
else
   call ig_text_disabled('click a block to choose it')
endif
