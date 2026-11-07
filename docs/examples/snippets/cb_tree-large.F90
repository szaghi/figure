if (ig_tree_node('background, 20000 blocks')) then
   if (ig_begin_child('background', height=110.0_real64)) then
      call clip%begin(BACKGROUND)                           ! children of equal height: only those in view
      do while (clip%step())
         do k = clip%first, clip%last
            write(line, '(A,I0)') 'block ', k
            if (ig_tree_node(trim(line), leaf=.true.)) call ig_tree_pop()
         enddo
      enddo
   endif
   call ig_end_child()
   call ig_tree_pop()
endif
