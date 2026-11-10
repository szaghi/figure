if (ig_begin_table('blocks', 5_int32, height=ig_em(18.0_real64), freeze_rows=1_int32, sortable=.true., &
                   hideable=.true.)) then
   call ig_table_setup_column('block', width=ig_em(4.0_real64), default_sort=.true.)
   call ig_table_setup_column('body', stretch=1.0_real64)
   call ig_table_setup_column('cells', width=ig_em(6.0_real64), descending=.true.) ! largest first
   call ig_table_setup_column('residual', width=ig_em(7.0_real64), descending=.true.)
   call ig_table_setup_column('patch', width=ig_em(6.0_real64), hidden=.true.)
   call ig_table_headers_row()                           ! frozen: it stays while the rows scroll
   if (check) call ig_item_rect(header(1), header(2), header(3), header(4))
   if (ig_table_sort(column, descending)) call sort_rows(column, descending) ! a new order asked
   first_shown = 0_int32
   call clip%begin(ROWS)
   do while (clip%step())
      first_shown = max(first_shown, clip%first)
      do i = clip%first, clip%last
         k = order(i)                                    ! the row shown i is block k
         call ig_table_next_row()
         if (residual(k) > TOLERANCE) call ig_table_row_color(WARN)
         call ig_table_next_column()
         write(text, '(I0)') k
         call ig_text(trim(text))
         call ig_table_next_column()
         call ig_text(trim(bodies(k)))
         call ig_table_next_column()
         write(text, '(I0)') cells(k)
         call ig_text(trim(text))
         if (check .and. i == clip%first) call keep_cells_x()
         call ig_table_next_column()
         write(text, '(ES9.2)') residual(k)
         if (residual(k) > TOLERANCE) then
            call ig_text('! '//trim(adjustl(text)))      ! a mark with the colour, not the colour alone
         else
            call ig_text_disabled(trim(adjustl(text)))
         endif
         call ig_table_next_column()
         call ig_text(trim(patches(k)))
      enddo
   enddo
   call ig_end_table()
endif
