if (ed%find('numbr')) then                     ! selected, scrolled to at the next draw
   fixed = ed%replace('mach numbr', 'mach number') ! every occurrence, in one undo
   call validate(ed)
   write(output_unit, '(I0,A)') fixed, ' key renamed'
endif
