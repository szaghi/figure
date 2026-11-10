write(output_unit, '(A,I6,A,ES9.3,A,F8.3)') 'iteration ', it, '  residual ', residual, '  mean ', mean
flush(output_unit)                                ! the studio reads each line as it is printed
call wait(pace)
