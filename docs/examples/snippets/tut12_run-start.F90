call output%clear()
deallocate(iters, res)
allocate(iters(0), res(0))
args(1) = solver_path                             ! no shell: the program and its arguments, an array
args(2) = case_dir
args(3) = '--pace'                                ! a small case: slowed down, to be watched
args(4) = '3'
call solver%start(args, stat=stat)
if (stat /= FIG_OK) then
   call app%notify('The solver does not start: '//figure_last_error(), kind='error')
   return
endif
started = .true.
run_status = 'running'
