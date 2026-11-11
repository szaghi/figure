call test_mouse_move(monitor_at(1), monitor_at(2)) ! the pointer over the monitor
call frames(4_int32)
call check(index(readout, 'iteration ') == 1, 'the pointer over the monitor reads '//trim(readout))
call check(abs(window_mean - sum(means) / size(means)) < 1.0e-9_real64, &
           'the averaging window spans the run: its mean is the mean of every iteration')
