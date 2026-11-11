if (remote) then                                     ! printed once the case is open: the browser finds it ready
   write(output_unit, '(A)') 'FIGURE: open '//trim(url)//' in a web browser'
   flush(output_unit)
endif
