call solver%poll(lines)                           ! the complete lines since the last poll
call output%add(lines)
do k = 1_int32, size(lines, kind=int32)
   if (index(lines(k), 'iteration ') /= 1) cycle
   read(lines(k)(11:), *, iostat=ios) it, word, r ! "iteration    42  residual 1.234E-04"
   if (ios == 0) then
      iters = [iters, it]
      res = [res, r]
   endif
enddo
if (solver%running()) return
started = .false.                                 ! it ended: once
if (solver%killed()) then
   run_status = ICON_SQUARE//' stopped'
   call app%notify('The run was stopped', kind='warning')
elseif (solver%exit_code() == 0_int32) then
   write(run_status, '(A,I0,A,ES8.2)') 'converged in ', nint(iters(size(iters))), ' iterations, residual ', &
                                       res(size(res))
   call app%notify('The solver '//trim(run_status), kind='success', seconds=10.0_real64)
else
   write(run_status, '(A,I0,A)') '[!!] the solver failed, exit code ', solver%exit_code(), ': see the log'
   call app%notify(trim(run_status), kind='error')
endif
