plane = 0.0_real64                                   ! columns: the plane's two in-plane axes, its normal, its point
plane(1:3, 1) = [0.0_real64, 1.0_real64, 0.0_real64]
plane(1:3, 2) = [0.0_real64, 0.0_real64, 1.0_real64]
plane(1:3, 3) = [1.0_real64, 0.0_real64, 0.0_real64] ! the normal: the part toward +x is kept
plane(1:4, 4) = [2.0_real64, 0.0_real64, 0.0_real64, 1.0_real64]
call outline_of(plane)
outline = view%lines(frame, color=[1.0_real64, 0.85_real64, 0.3_real64])
call cut(view)
