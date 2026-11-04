if (app%next_frame(stat=stat)) then
   if (ig_begin('Data')) then
      if (ip_begin_plot('Mismatch')) then
         call ip_line('y', x, y, stat=stat)                    ! size(x) /= size(y): nothing drawn
         if (stat == FIG_ERR_ARGUMENT) write(output_unit, '(A,I0,A)') 'ip_line: stat = ', stat, &
                                                                   ', "'//figure_last_error()//'"'
         call ip_end_plot()
      endif
   endif
   call ig_end()
endif
