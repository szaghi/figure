call app%init('FIGURE: continuous', 400_int32, 200_int32, vsync=.false.) ! do not wait for the display refresh
call app%set_lazy(.false.)                                              ! never sleep waiting for input
