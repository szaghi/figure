call app%set_checks('recover')                 ! repaired where it happens, shown in a notification
call grid(pop=.false.)
ok = app%next_frame(stat=stat)
write(output_unit, '(A,L1,A)') 'recover: stat == FIG_OK is ', stat == FIG_OK, ', the message:'// &
                               new_line('a')//figure_last_error()
