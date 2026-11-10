do frame = 1_int32, 24_int32
   if (.not. app%next_frame()) exit
   call draw()
   if (frame == 2_int32) call test_click(monitor_at(1), monitor_at(2)) ! the Monitor workspace
   if (frame == 8_int32) then
      call test_click(cfl_at(1), cfl_at(2))                   ! focus the field
      call test_key('shortcut', down=.true.)                  ! select what is there: ctrl+a (cmd+a on macOS)
      call test_key('a')
      call test_key('shortcut', down=.false.)
      call test_type('0.8')                                   ! replace it
      call test_key('enter')                                  ! confirm: cfl becomes 0.8
   endif
enddo
