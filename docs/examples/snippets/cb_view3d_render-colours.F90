call view%init(lighting=.false.)                              ! the colours exactly as mapped, for a legend
bump = view%surface(xyz, cell_scalar=f, colormap='batlow')    ! one colour per cell
call view%set_mesh(bump, vmin=0.0_real64, vmax=5.0_real64)    ! a fixed range: 0 to 5, whatever the data
