if (ig_tree_node('cases', default_open=.true.)) then
   do c = 1_int32, CASES
      if (ig_tree_node(trim(NAME(c)), leaf=.true., selected=shown(c))) call ig_tree_pop()
      if (ig_drag_source('case', trim(NAME(c)))) continue   ! the node carries its name
   enddo
   call ig_tree_pop()
endif
if (ig_button('Bin')) shown = .false.                        ! a click empties the plot
if (ig_drop_target('case', payload)) call show(payload, .false.) ! a case dropped here leaves it
if (ig_dragging('case')) call ig_text_disabled('drop on the plot')
