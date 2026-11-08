what(1) = 'the grid needs at least 3 x 3 nodes'
bad(1) = c%nx < 3_int32 .or. c%ny < 3_int32
what(2) = 'the plate needs a positive size'
bad(2) = c%lx <= 0.0_real64 .or. c%ly <= 0.0_real64
what(3) = 'the body reaches the plate''s edge'
bad(3) = c%body_x - c%body_r <= 0.0_real64 .or. c%body_x + c%body_r >= c%lx .or. &
         c%body_y - c%body_r <= 0.0_real64 .or. c%body_y + c%body_r >= c%ly
what(4) = 'every side insulated: the temperature is not determined'
bad(4) = all(c%bc_kind == 'insulated')
what(5) = 'omega must be in (0, 2): over-relaxation diverges at 2'
bad(5) = c%omega <= 0.0_real64 .or. c%omega >= 2.0_real64
what(6) = 'the tolerance must be positive'
bad(6) = c%tolerance <= 0.0_real64
what(7) = 'at least one iteration'
bad(7) = c%max_iter < 1_int32
list = pack(what, bad)                            ! the messages of the checks that failed
