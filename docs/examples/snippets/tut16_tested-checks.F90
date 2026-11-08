inp%body_r = 0.5_real64                           ! the body out of the plate
call frames(2_int32)
call check(.not. can_run() .and. size(problems(inp)) == 1, 'an input with the body out of the plate is refused')
inp%body_r = 0.2_real64
call check(can_run(), 'and accepted once corrected')
