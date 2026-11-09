call app%set_lazy(.true., max_wait=60.0_real64)            ! idle: one frame a minute, unless woken
call solver%start(solve, 0_int32)
seen = 0_int32
running = .true.
do while (running)
   running = app%next_frame()
   do                                                      ! every complete snapshot not shown yet
      inquire(file=snapshot_name(seen + 1_int32, .true.), exist=ready)
      if (.not. ready) exit
      seen = seen + 1_int32
      open(newunit=u, file=snapshot_name(seen, .false.), action='read', status='old')
      read(u, *) step, residual
      close(u, status='delete')
      open(newunit=u, file=snapshot_name(seen, .true.), status='old')
      close(u, status='delete')
      write(output_unit, '(A,I0,A,ES10.3)') 'step ', step, ': residual ', residual
   enddo
   if (solver%done() .and. seen == 5_int32) running = .false.
enddo
