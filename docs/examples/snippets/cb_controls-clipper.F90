if (ig_begin_child('rows', height=ig_em(6))) then        ! a region that scrolls on its own
   call clip%begin(size(names, kind=int32))
   do while (clip%step())                               ! only the rows in view are drawn
      do i = clip%first, clip%last
         if (ig_selectable(trim(names(i)), i == current)) current = i
      enddo
   enddo
endif
call ig_end_child()
