if (ig_begin_child('blocks', height=-60.0_real64, border=.true.)) then
   call ig_begin_multi_select(sel, box_select=.true., clear_on_escape=.true.)
   call clip%begin(BLOCKS, keep=sel%keep)           ! a shift+click extends from a line out of view
   do while (clip%step())
      do i = clip%first, clip%last
         write(line, '(A,I5,A,I7,A)') 'block ', i, ': ', cells(i), merge(' cells, frozen', ' cells        ', &
                                                                        frozen(i))
         if (ig_selectable(trim(line), sel%is_selected(i), index=i)) continue
      enddo
   enddo
   call ig_end_multi_select(sel)                    ! the clicks, keys and box are in sel
endif
call ig_end_child()
write(line, '(I0,A,I0,A)') sel%selected_count(), ' blocks selected, ', sum(cells, mask=sel%flags()), ' cells'
call ig_text(trim(line))
if (ig_button('Freeze')) frozen(sel%indices()) = .true.  ! act on what is selected
call ig_same_line()
if (ig_button('Clear')) call sel%clear()
call ig_same_line()
call ig_text_disabled('shift, ctrl, ctrl+a, a drag in the void')
