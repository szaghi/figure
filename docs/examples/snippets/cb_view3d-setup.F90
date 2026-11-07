call view%init()                                                   ! after app%init
hull = view%surface(body, scalar=cp, colormap='cool-warm', edges=.true.) ! the arrays are read in place
wake = view%lines(axis, color=[0.9_real64, 0.75_real64, 0.2_real64])
call view%set_camera(azimuth=-55.0_real64, elevation=25.0_real64)
