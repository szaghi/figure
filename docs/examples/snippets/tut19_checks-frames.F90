do k = 1_int32, n
   if (.not. app%next_frame(stat=stat)) then
      ended = .true.
      return
   endif
   if (stat /= FIG_OK) then                       ! a usage error in the frame before: the test says which
      usage_errors = usage_errors + 1_int32
      write(output_unit, '(A)') figure_last_error()
   endif
   call draw_studio()
enddo
