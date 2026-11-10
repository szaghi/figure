call grid(pop=.false.)                         ! ig_tree_pop forgotten
ok = app%next_frame(stat=stat)                 ! mode 'report' (the default): the errors of the frame
if (stat /= FIG_OK) write(output_unit, '(A)') 'report:'//new_line('a')//figure_last_error()
