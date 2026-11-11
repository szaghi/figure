call frames()
call report('opened')
call ed%goto(2_int32, 21_int32, focus=.true.)  ! after the "-" of -15
call frames()
call test_key('backspace')                     ! as the user would fix it
call frames()
call report('after the fix')
call ed%goto(5_int32, 1_int32, focus=.true.)   ! the empty line
call frames()
call test_type(' mach n')
call frames()
if (ed%completing()) write(output_unit, '(A)') 'completion offers a key'
call test_key('tab')
call frames()
write(output_unit, '(A)') 'line 5: "'//line_of(5_int32)//'"'
