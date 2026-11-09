if (ig_begin('Input')) then
   v = 0.5_real64
   edited = ig_input('Value', v, format='%d', stat=stat)    ! '%d' prints an integer: v is a real
   if (stat == FIG_ERR_ARGUMENT) write(output_unit, '(A,I0,A)') 'ig_input: stat = ', stat, &
                                                             ', "'//figure_last_error()//'"'
endif
call ig_end()
