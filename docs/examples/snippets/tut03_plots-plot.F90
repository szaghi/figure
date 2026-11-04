if (ip_begin_plot('Vibration modes', height=300.0_real64)) then
   call ip_setup_axes('x', 'amplitude')
   do k = 1_int32, M
      write(label, '(A,I0)') 'mode ', k
      call ip_line(trim(label), x, modes(:, k))
   enddo
   call ip_end_plot()
endif
