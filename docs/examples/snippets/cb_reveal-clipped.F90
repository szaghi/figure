if (ig_begin_child('blocks')) then
   call clip%begin(BLOCKS)
   do while (clip%step())                                ! the rows in view, not the selected one
      do i = clip%first, clip%last
         write(label, '(A,I0,A,I0)') 'block ', i, '   body ', body_of(i)
         if (ig_selectable(trim(label), i == block)) call select(i)
         if (i == block) call keep_row()
      enddo
   enddo
   if (reveal .and. block > 0_int32) &                 ! row `block` starts (block - 1) rows down
      call ig_scroll_to_pos((real(block, real64) - 0.5_real64) * clip%item_height, 0.5_real64)
endif
call ig_end_child()
