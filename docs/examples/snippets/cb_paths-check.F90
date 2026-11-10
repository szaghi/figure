write(output_unit, '(A)') 'file: '//trim(s%file)
write(output_unit, '(A,L1)') 'Implicit checked: ', test_item_checked('Solver/Options/Implicit')
write(output_unit, '(A,L1)') 'CFL shows 0.80: ', test_item_value('Solver/CFL', '0.80')
write(output_unit, '(A,I0)') 'id conflicts: ', test_id_conflicts()
write(output_unit, '(A,I0)') 'unnamed items: ', test_unnamed_items()
call test_item_click('Solver/Options/Implcit', stat=stat) ! a typo: the message names the nearest item
if (stat == FIG_ERR_ARGUMENT) write(output_unit, '(A)') figure_last_error()
