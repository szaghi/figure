write(line, '(A,I0,A,ES8.2)') 'Run finished: ', ITERATIONS, ' iterations, residual ', residual
call app%notify(trim(line), kind='success')     ! the user may be looking elsewhere
