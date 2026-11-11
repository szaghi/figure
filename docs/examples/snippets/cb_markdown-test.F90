call help%find('pressure')
do k = 1_int32, 3_int32
   if (.not. app%next_frame()) exit
   call draw()
enddo
write(output_unit, '(A,I0,A,I0)') "help: 'pressure' found ", help%matches(), ' times, current ', help%current_match()
call help%find('')
call help%scroll_to('Boundary conditions')
do k = 1_int32, 30_int32
   if (.not. app%next_frame()) exit
   call draw()
enddo
write(output_unit, '(A)') 'help: scrolled to "Boundary conditions", last link: '//last
