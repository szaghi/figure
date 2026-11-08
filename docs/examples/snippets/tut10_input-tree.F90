if (ig_begin_child('sections', width=170.0_real64, border=.true.)) then
   if (ig_tree_node(ICON_FILE_PEN//' '//INPUT_FILE, default_open=.true.)) then
      call section_node(1_int32)
      if (ig_tree_node('Boundaries', default_open=.true., selected=section == 2_int32, span_full_width=.true., &
                       clicked=clicked)) then
         do k = 1_int32, size(SIDES, kind=int32)  ! the sides: leaves, each choosing the table
            if (ig_tree_node(trim(SIDES(k)), leaf=.true., span_full_width=.true., clicked=side_clicked)) &
               call ig_tree_pop()
            if (side_clicked) section = 2_int32
         enddo
         call ig_tree_pop()
      endif
      if (clicked) section = 2_int32               ! the label, not the arrow
      call section_node(3_int32)
      call section_node(4_int32)
      call ig_tree_pop()
   endif
endif
call ig_end_child()
