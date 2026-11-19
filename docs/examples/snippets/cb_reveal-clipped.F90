if (ig_begin_child('blocks')) then
   call clip%begin(BLOCKS)
   do while (clip%step())                                ! the rows in view, not the selected one
      do i = clip%first, clip%last
         write(label, '(A,I0,A,I0)') 'block ', i, '   body ', body_of(i)
         if (ig_selectable(trim(label), i == block)) call select(i)
      enddo
   enddo
   if (reveal .and. block > 0_int32) &                 ! row `block` starts (block - 1) rows down
      call ig_scroll_to_pos((real(block, real64) - 0.5_real64) * clip%item_height, 0.5_real64)
   if (ig_shortcut('ctrl+home', scope='global')) call ig_set_scroll(y=0.0_real64) ! the top, on the next frame
   call ig_get_scroll(scroll, scroll_max)               ! where the list is: 0 (top) to scroll_max (bottom)
endif
call ig_end_child()
