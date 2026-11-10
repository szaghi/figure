xyz(3, :, :) = 0.5_real64 * xyz(3, :, :)                      ! the program changes the data in place ...
call view%changed(bump)                                       ! ... and says so: the next draw renders
call frames(3_int32)
call view%render_info(count=renders(4), width=w, height=h)
