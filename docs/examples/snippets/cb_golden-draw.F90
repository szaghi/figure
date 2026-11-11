subroutine draw(s)
!< The window, one frame of it: the same procedure in the application and in its test.
type(settings), intent(inout) :: s !< State.
character(len=32)             :: t !< The clock's text.

call ig_set_next_window(10.0_real64, 10.0_real64, 300.0_real64, 140.0_real64, always=.true.)
if (ig_begin('Solver')) then
   if (ig_slider('omega', s%omega, 1.0_real64, 2.0_real64)) continue
   if (ig_checkbox('implicit', s%implicit)) continue
   if (ig_button('Run')) continue
   write(t, '(A,I0,A)') 'up ', nint(1000.0_real64 * figure_time()), ' ms'
   call ig_text(trim(t))                                ! not the same in two runs
   call ig_item_rect(s%clock(1), s%clock(2), s%clock(3), s%clock(4))
endif
call ig_end()
endsubroutine draw
