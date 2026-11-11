if (ig_begin_table('runs', 5_int32, flags=ior(ImGuiTableFlags_RowBg, ImGuiTableFlags_BordersInnerV), &
                   freeze_rows=1_int32, sortable=.true.)) then ! the header stays in view; the rows scroll
   call ig_table_setup_column('run', width=ig_em(3), default_sort=.true.)
   call ig_table_setup_column('case', stretch=1.0_real64)
   call ig_table_setup_column('residual', width=ig_em(6))
   call ig_table_setup_column('outcome', width=ig_em(7))
   call ig_table_setup_column('iterations', width=ig_em(6))
   if (ig_table_sort(sort_key, sort_down)) call sort_runs() ! a header clicked: the program sorts its rows
   call ig_table_headers_row()
   call centre_of_last(header_at)                 ! the last header, iterations: for the test
   do r = 1_int32, size(order, kind=int32)
      k = order(r)
      call ig_push_id(runs(k)%number)             ! each row's menu has its own id
      call ig_table_next_row()
      if (runs(k)%outcome /= 'converged') call ig_table_row_color([red(1:3), 0.25_real64]) ! with a mark below
      call ig_table_next_column()
      write(text, '(I0)') runs(k)%number
      if (ig_selectable(trim(text), k == picked_run)) picked_run = k
      if (r == 1_int32) call centre_of_last(row_at)
      call run_menu(k, remove)
      call ig_table_next_column()
      call ig_text(trim(runs(k)%title))
      call ig_table_next_column()
      write(text, '(ES9.2)') runs(k)%residual
      call ig_text(trim(text))
      call ig_table_next_column()
      call ig_text(trim(merge('     ', '[!!] ', runs(k)%outcome == 'converged'))//trim(runs(k)%outcome))
      call ig_table_next_column()
      write(text, '(I0)') runs(k)%iterations
      call ig_text(trim(text))
      call ig_pop_id()
   enddo
   call ig_end_table()
endif
