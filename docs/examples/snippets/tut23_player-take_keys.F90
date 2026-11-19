if (focus_on /= check) return
call ig_focus_here()                              ! the next item takes the keys; applied on the next frame
focus_on = 0_int32
