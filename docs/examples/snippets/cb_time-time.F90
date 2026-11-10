t0 = figure_time()
total = 0.0_real64
do k = 1_int32, 1000000_int32 ! the work
   total = total + real(k, real64)
enddo
step_time = figure_time() - t0 ! seconds, on a clock the system does not step
