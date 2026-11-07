if (ig_begin_side_bar('status', 'bottom', 30.0_real64)) then ! the status bar: a bar along the bottom
   if (running) then
      write(line, '(A,I0,A,I0)') 'running: iteration ', iteration, ' of ', ITERATIONS
      call ig_text(trim(line))
      call ig_same_line(offset=260.0_real64)
      call ig_progress_bar(real(iteration, real64) / real(ITERATIONS, real64), width=200.0_real64)
   elseif (iteration == ITERATIONS) then
      write(line, '(A,ES8.2)') 'done, residual ', residual
      call ig_text(trim(line))
   else
      call ig_text_disabled('ready')
   endif
endif
call ig_end()
