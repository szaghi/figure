call test_key('f5')
call frames(3_int32)
do k = 1_int32, 1000000_int32                     ! frames until the solver ends (it runs in real time)
   if (.not. started) exit
   call frames(1_int32)
enddo
call check(index(run_status, 'converged in') == 1, 'F5 runs the solver to convergence')
do k = 1_int32, 1000000_int32                     ! and until the task has read its field
   if (size(field) > 0) exit
   call frames(1_int32)
enddo
call check(size(field) == inp%nx * inp%ny, 'the task reads the field the solver wrote')
