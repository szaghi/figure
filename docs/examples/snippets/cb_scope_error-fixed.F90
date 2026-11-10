call grid(pop=.true.)
ok = app%next_frame(stat=stat)
if (stat == FIG_OK) write(output_unit, '(A)') 'fixed: no usage error'
