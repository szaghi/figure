if (section == 2_int32) then
   if (ig_begin_table('boundaries', 3_int32)) then
      call ig_table_setup_column('side', width=70.0_real64)
      call ig_table_setup_column('condition', width=140.0_real64)
      call ig_table_setup_column('temperature [C]')
      call ig_table_headers_row()
      do k = 1_int32, size(SIDES, kind=int32)
         call ig_push_id(k)                        ! the same widgets in every row: an id scope per row
         call ig_table_next_row()
         call ig_table_next_column()
         call ig_text(trim(SIDES(k)))
         call ig_table_next_column()
         kind = merge(1_int32, 2_int32, inp%bc_kind(k) == KINDS(1))
         call ig_set_next_item_width(-1.0_real64)
         if (ig_combo('##kind', kind, KINDS)) then
            inp%bc_kind(k) = KINDS(kind)
            changing = .true.
         endif
         call ig_table_next_column()
         call ig_begin_disabled(kind == 2_int32)   ! an insulated side has no temperature
         call ig_set_next_item_width(-1.0_real64)
         if (ig_input('##value', inp%bc_value(k), format='%.1f')) changing = .true.
         call ig_end_disabled()
         call ig_pop_id()
      enddo
      call ig_end_table()
   endif
endif
