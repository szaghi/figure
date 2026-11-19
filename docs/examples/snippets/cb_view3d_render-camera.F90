call view%unclip()
call view%orbit(30.0_real64, elevation=15.0_real64)          ! as a drag with the left button [degrees]
call view%pan(1.0_real64, 0.5_real64)                         ! as a drag with the right button [world units]
call view%zoom(1.5_real64)                                    ! closer; the wheel zooms by 1.1 a step
