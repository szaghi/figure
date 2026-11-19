inp%omega = 1.5_real64                            ! a second run, slower to converge (the edit saved by F5)
edited = .true.
call test_key('f5')
call frames(3_int32)
do k = 1_int32, 1000000_int32
   if (.not. started) exit
   call frames(1_int32)
enddo
do k = 1_int32, 1000000_int32                     ! and its field read: the Result panel comes forward with it,
   if (size(field) > 0) exit                      ! at a time of the task's, not of the test's
   call frames(1_int32)
enddo
call test_click(runs_tab_at(1), runs_tab_at(2))   ! the Runs tab
call frames(6_int32)
call test_click(header_at(1), header_at(2))       ! the iterations' header: fewest first
call frames(6_int32)
call check(size(runs) == 2 .and. runs(order(1))%iterations < runs(order(2))%iterations .and. order(1) == 1, &
           'two runs in the table, sorted by iterations on a click of its header')
call test_click(header_at(1), header_at(2))       ! again: most first
call frames(6_int32)
call check(order(1) == 2 .and. sort_down, 'a second click reverses the order')
call test_click(row_at(1), row_at(2), button='right') ! a right click on the first row
call frames(6_int32)
call test_popup_rect(r(1), r(2), r(3), r(4), found)
call check(found, 'a right click on a run opens its menu')
call test_key('escape')
call frames(4_int32)
