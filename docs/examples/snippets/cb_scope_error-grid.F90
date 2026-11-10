subroutine grid(pop)
!< A table of blocks, a tree in its first cell; `pop` false: the tree's end forgotten.
logical, intent(in) :: pop !< Close the tree (the right code).

if (ig_begin('Grid')) then
   if (ig_begin_table('blocks', 2_int32)) then
      call ig_table_next_row()
      call ig_table_next_column()
      if (ig_tree_node('Blocks', default_open=.true.)) then
         call ig_text('inlet')
         call ig_text('outlet')
         if (pop) call ig_tree_pop()        ! only after a true ig_tree_node
      endif
      call ig_table_next_column()
      call ig_text('2 blocks')
      call ig_end_table()
   endif
endif
call ig_end()
endsubroutine grid
