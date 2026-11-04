call app%init_headless(0_int32, 300_int32, stat=stat)          ! invalid size
if (stat /= FIG_OK) write(output_unit, '(A,I0,A)') 'init_headless: stat = ', stat, ', "'//figure_last_error()//'"'

call app%init_headless(400_int32, 300_int32, stat=stat)        ! succeeds
call app%init_headless(400_int32, 300_int32, stat=stat)        ! already initialized
if (stat == FIG_ERR_STATE) write(output_unit, '(A,I0,A)') 'init_headless: stat = ', stat, ', "'//figure_last_error()//'"'
