uploads = test_field_uploads()
call frames(3_int32)
call check(size(snap_iters) > 1 .and. test_field_uploads() == uploads, &
           'the run''s snapshots are listed; a frame with nothing changed colours nothing')
player%playing = .true.                           ! as the play button does
call frames(20_int32)
player%playing = .false.
call frames(2_int32)
call check(player%index < player%count .and. test_field_uploads() > uploads .and. &
           any(shown_field /= coarse), 'playing steps through the snapshots, each coloured once')
