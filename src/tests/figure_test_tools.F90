!< figure_test_tools, a workspace button, a list clipper, text level with fields, focusing a window, headless.
program figure_test_tools
!< figure_test_tools, a workspace button, a list clipper, text level with fields, focusing a window, headless.
!<
!< Two workspace buttons (`ig_tool_button`), the first selected: their default size (room for the icon above the
!< label), a given size, a click on the second. A list of 100000 rows in a region 200 pixels high, clipped
!< (`list_clipper_object`): only the rows in view are drawn, from row 1, and the loop ends. A label before a button,
!< lowered to its text by `ig_align_text_to_frame_padding` (and not without it). Two overlapping windows: the one
!< behind brought forward by `ig_focus_window`; with a popup open, the request is refused and the popup stays open.
!< A text's size (`ig_text_size`): twice the text, twice the width; a label measured without its `##` part.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, ICON_ACTIVITY, ICON_HOUSE, ig_align_text_to_frame_padding, ig_begin, ig_begin_child, &
                   ig_begin_popup, ig_button, ig_end, ig_end_child, ig_end_popup, ig_focus_window, ig_item_rect, &
                   ig_open_popup, ig_same_line, ig_selectable, ig_set_next_window, ig_text, ig_tool_button, &
                   ig_text_size, list_clipper_object
use figure_cimgui, only : igIsWindowFocused
use figure_testing, only : test_click

implicit none
integer(int32), parameter :: MAX_FRAMES = 60_int32 !< Frames run.
type(app_object)          :: app                   !< Application (headless).
type(list_clipper_object) :: clip                  !< Clipper.
logical                   :: test_passed(9)        !< Per-check outcome.
real(real64)              :: size1(2), size2(2), size3(2) !< Text sizes.
integer(int32)            :: frame, i, shown       !< Frame, row, the tool shown.
integer(int32)            :: clicks(2)             !< Clicks per tool button.
integer(int32)            :: drawn, steps, first_drawn !< Rows drawn, clipper steps, the first row drawn.
real(real64)              :: r(4), a(4), b(4)      !< Rectangles.
real(real64)              :: tool_rect(4, 3)       !< The tool buttons: default (2), given size.
real(real64)              :: aligned_dy, plain_dy  !< Label below the button's top: aligned, not.
logical                   :: w1_focused, popup_up, refused, accepted !< Focus and popup states.

test_passed = .false.
clicks = 0_int32
shown = 1_int32
w1_focused = .false.
popup_up = .false.
refused = .false.
accepted = .false.
call app%init_headless(900_int32, 700_int32)
frame = 0_int32
do while (app%next_frame())
   frame = frame + 1_int32
   if (frame > MAX_FRAMES) exit
   call ig_set_next_window(10.0_real64, 10.0_real64, 400.0_real64, 650.0_real64, always=.true.)
   if (ig_begin('Tools')) then
      if (ig_tool_button('Input##t1', ICON_HOUSE, selected=shown == 1_int32)) then
         shown = 1_int32
         clicks(1) = clicks(1) + 1_int32
      endif
      call ig_item_rect(tool_rect(1, 1), tool_rect(2, 1), tool_rect(3, 1), tool_rect(4, 1))
      call ig_same_line()
      if (ig_tool_button('Monitor##t2', ICON_ACTIVITY, selected=shown == 2_int32, accent=[0.85_real64, 0.3_real64, &
                         0.22_real64])) then
         shown = 2_int32
         clicks(2) = clicks(2) + 1_int32
      endif
      call ig_item_rect(tool_rect(1, 2), tool_rect(2, 2), tool_rect(3, 2), tool_rect(4, 2))
      if (ig_tool_button('Sized', ICON_HOUSE, width=90.0_real64, height=70.0_real64)) continue
      call ig_item_rect(tool_rect(1, 3), tool_rect(2, 3), tool_rect(3, 3), tool_rect(4, 3))
      size1 = ig_text_size('abc')
      size2 = ig_text_size('abcabc')
      size3 = ig_text_size('abc##hidden')
      call ig_align_text_to_frame_padding()                     ! a label level with the button beside it
      call ig_text('label')
      call ig_item_rect(a(1), a(2), a(3), a(4))
      call ig_same_line()
      if (ig_button('field')) continue
      call ig_item_rect(b(1), b(2), b(3), b(4))
      aligned_dy = a(2) - b(2)
      call ig_text('plain')                                     ! the same without
      call ig_item_rect(a(1), a(2), a(3), a(4))
      call ig_same_line()
      if (ig_button('field2')) continue
      call ig_item_rect(b(1), b(2), b(3), b(4))
      plain_dy = a(2) - b(2)
      drawn = 0_int32
      steps = 0_int32
      first_drawn = 0_int32
      if (ig_begin_child('list', height=200.0_real64)) then
         call clip%begin(100000_int32)
         do while (clip%step())
            steps = steps + 1_int32
            if (steps > 10_int32) exit                          ! guard: a clipper takes a few steps
            if (first_drawn == 0_int32) first_drawn = clip%first
            do i = clip%first, clip%last
               if (ig_selectable('row '//itoa(i), .false.)) continue
               drawn = drawn + 1_int32
            enddo
         enddo
      endif
      call ig_end_child()
   endif
   call ig_end()
   ! two windows, overlapping: W2 drawn last is in front; W1 brought forward on frame 20; a popup in W2 from frame 30
   call ig_set_next_window(450.0_real64, 10.0_real64, 300.0_real64, 200.0_real64)
   if (ig_begin('W1')) call ig_text('one')
   w1_focused = igIsWindowFocused(0_int32)
   call ig_end()
   call ig_set_next_window(470.0_real64, 30.0_real64, 300.0_real64, 200.0_real64)
   if (ig_begin('W2')) then
      call ig_text('two')
      if (frame == 30_int32) call ig_open_popup('pop')
      popup_up = .false.
      if (ig_begin_popup('pop')) then
         popup_up = .true.
         call ig_text('a popup')
         call ig_end_popup()
      endif
   endif
   call ig_end()
   if (frame == 15_int32) test_passed(7) = .not. w1_focused             ! W2, in front, has the focus
   if (frame == 20_int32) accepted = ig_focus_window('W1')
   if (frame == 25_int32) test_passed(7) = test_passed(7) .and. accepted .and. w1_focused
   if (frame == 34_int32) refused = .not. ig_focus_window('W2')
   if (frame == 38_int32) test_passed(8) = refused .and. popup_up
   if (frame == 5_int32) call test_click(0.5_real64 * (tool_rect(1, 2) + tool_rect(3, 2)), &
                                         0.5_real64 * (tool_rect(2, 2) + tool_rect(4, 2)))
enddo

r = tool_rect(:, 1)
test_passed(1) = r(3) - r(1) >= 4.6_real64 * 13.0_real64 .and. r(4) - r(2) > 3.0_real64 * 13.0_real64 ! default size
test_passed(2) = abs(tool_rect(3, 3) - tool_rect(1, 3) - 90.0_real64) < 0.5_real64 .and. &
                 abs(tool_rect(4, 3) - tool_rect(2, 3) - 70.0_real64) < 0.5_real64              ! given size
test_passed(3) = clicks(2) == 1_int32 .and. clicks(1) == 0_int32 .and. shown == 2_int32       ! the second clicked
test_passed(4) = first_drawn == 1_int32 .and. drawn > 0_int32 .and. drawn < 40_int32          ! rows in view only
test_passed(5) = steps <= 10_int32                                                              ! the loop ended
test_passed(6) = aligned_dy > 0.5_real64 .and. abs(plain_dy) < 0.5_real64                      ! level with the field
test_passed(9) = size1(1) > 0.0_real64 .and. abs(size2(1) - 2.0_real64 * size1(1)) < 1.0_real64 .and. &
                 size1(2) > 0.0_real64 .and. abs(size3(1) - size1(1)) < 1.0e-6_real64    ! a text's size, a label's
if (.not. all(test_passed)) then
   write(output_unit, '(A,4F8.1)') 'tool button: ', tool_rect(:, 1)
   write(output_unit, '(A,4I8)') 'clicks, shown, drawn: ', clicks, shown, drawn
   write(output_unit, '(A,2I8)') 'first drawn, steps: ', first_drawn, steps
   write(output_unit, '(A,2F8.2)') 'dy aligned, plain: ', aligned_dy, plain_dy
endif
do i = 1_int32, size(test_passed, kind=int32)
   if (.not. test_passed(i)) write(output_unit, '(A,I0,A)') 'figure_test_tools: check ', i, ' FAILED'
enddo
write(output_unit, '(A,*(L2))') 'figure_test_tools checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
call app%destroy()
if (.not. all(test_passed)) error stop 1

contains
   pure function itoa(n) result(s)
   !< An integer as text.
   integer(int32), intent(in)    :: n   !< Integer.
   character(len=:), allocatable :: s   !< Text.
   character(len=12)             :: buf !< Buffer.

   write(buf, '(I0)') n
   s = trim(buf)
   endfunction itoa
endprogram figure_test_tools
