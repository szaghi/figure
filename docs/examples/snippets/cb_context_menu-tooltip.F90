if (ig_begin_item_tooltip()) then                ! the pointer rests on the row
   tooltip = .true.
   if (ig_begin_table('values', 2_int32)) then
      call cell('patch', trim(names(i)))
      call cell('condition', trim(kinds(i)))
      write(label, '(F0.1)') values(i)
      call cell('value', trim(label))
      call ig_end_table()
   endif
   call ig_end_tooltip()
endif
