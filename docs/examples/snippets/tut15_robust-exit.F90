select case (solver%exit_code())                ! the solver's own codes (tut11_heat.F90)
case (1_int32)
   run_status = 'the solver cannot read heat.inp: see the log'
case (2_int32)
   write(run_status, '(A,I0,A)') 'not converged in ', inp%max_iter, ' iterations: raise max_iter or omega'
case default
   write(run_status, '(A,I0,A)') 'the solver failed, exit code ', solver%exit_code(), ': see the log'
endselect
call app%notify(trim(run_status), kind='error', seconds=8.0_real64) ! the notification has its own mark
run_status = '[!!] '//trim(run_status)          ! the status bar's: a mark with the words
