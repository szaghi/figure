call ig_set_next_window(ig_em(1), ig_em(1), ig_em(24), 0.0_real64, always=.true.) ! 24 em wide, as high as its
                                                                                  ! content (height 0)
if (ig_begin('Case')) call form()
call ig_end()
