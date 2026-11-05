!< figure_test_text, lists, text and child regions (selectables, wrapped and coloured text, scrolling regions), headless.
program figure_test_text
!< figure_test_text, lists, text and child regions (selectables, wrapped and coloured text, scrolling regions), headless.
!<
!< A list of sections picked by a click, help text wrapped at a region's width, coloured and disabled text that leave the
!< style as it was, a region that scrolls under the wheel while its window does not, and a column placed by offset.
use, intrinsic :: iso_c_binding, only : c_f_pointer, c_float
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, ig_begin, ig_begin_child, ig_end, ig_end_child, ig_item_rect, ig_same_line, &
                   ig_selectable, ig_set_next_window, ig_text, ig_text_colored, ig_text_disabled, ig_text_wrapped
use figure_cimgui, only : im_vec4, igGetScrollY, igGetStyleColorVec4, igGetTextLineHeight
use figure_cimgui_enums, only : ImGuiCol_Text
use figure_testing, only : test_click, test_item_center, test_mouse_move, test_wheel

implicit none
integer(int32), parameter :: FRAMES = 60_int32  !< Frames run.
type(app_object)          :: app                !< Application.
logical                   :: test_passed(7)     !< Per-check outcome.
character(len=*), parameter :: SECTIONS(3) = ['files ', 'fluid ', 'output'] !< List lines.
integer(int32)            :: current            !< Line selected.
integer(int32)            :: clicks             !< Frames on which a line reported a click.
real(real64)              :: line_at(2)         !< Centre of line 2.
real(real64)              :: x0, y0, x1, y1     !< An item's rectangle.
real(real64)              :: wrap_rect(4)       !< Rectangle of the wrapped text.
real(real64)              :: help_right         !< Right edge of the help region.
real(real64)              :: line_height        !< Height of one line of text.
real(real64)              :: list_at(2)         !< A point inside the scrolling region.
real(c_float)             :: child_scroll       !< Scroll of the region, last frame.
real(c_float)             :: window_scroll      !< Scroll of its window, last frame.
real(real64)              :: col_x              !< Left of the text placed with ig_same_line(offset).
real(real64)              :: win_x              !< Left of its window.
type(im_vec4), pointer    :: text_color         !< The style's text colour.
type(im_vec4)             :: color_before       !< ... before the coloured texts.
type(im_vec4)             :: color_after        !< ... after them.
integer(int32)            :: frame              !< Frame counter.
integer(int32)            :: k                  !< Counter.

current = 1_int32
clicks = 0_int32
call app%init_headless(800_int32, 600_int32)
do frame = 1_int32, FRAMES
   if (.not. app%next_frame()) error stop 'figure_test_text: next_frame returned false in headless mode'
   call ig_set_next_window(20.0_real64, 20.0_real64, 400.0_real64, 300.0_real64, always=.true.)
   if (ig_begin('Editor')) then
      do k = 1_int32, size(SECTIONS, kind=int32)
         if (ig_selectable(trim(SECTIONS(k)), k == current)) then
            current = k
            clicks = clicks + 1_int32
         endif
         if (k == 2_int32) call test_item_center(line_at(1), line_at(2))
      enddo
      if (ig_begin_child('help', width=150.0_real64, height=120.0_real64, border=.true.)) then
         call ig_text_wrapped('The root name of the grid files, written before the block number and the extension.')
         call ig_item_rect(wrap_rect(1), wrap_rect(2), wrap_rect(3), wrap_rect(4))
      endif
      call ig_end_child()
      call ig_item_rect(x0, y0, help_right, y1)
      line_height = real(igGetTextLineHeight(), real64)
      call c_f_pointer(igGetStyleColorVec4(ImGuiCol_Text), text_color)
      color_before = text_color
      call ig_text_colored('[!!] not a number', [0.9_real64, 0.3_real64, 0.3_real64])
      call ig_text_disabled('default: CC/cc')
      color_after = text_color
      call ig_text('label')
      call ig_same_line(offset=200.0_real64)
      call ig_text('field')
      call ig_item_rect(col_x, y0, x1, y1)
   endif
   call ig_end()
   call test_window_rect_left('Editor', win_x)
   call ig_set_next_window(440.0_real64, 20.0_real64, 300.0_real64, 200.0_real64, always=.true.)
   if (ig_begin('Long list')) then
      call ig_text('above the region')
      if (ig_begin_child('rows', height=100.0_real64)) then
         do k = 1_int32, 40_int32
            call ig_text('row')
         enddo
         child_scroll = igGetScrollY()
      endif
      call ig_end_child()
      call ig_item_rect(x0, y0, x1, y1)
      list_at = [0.5_real64 * (x0 + x1), 0.5_real64 * (y0 + y1)]
      do k = 1_int32, 15_int32                        ! the window is taller than it shows: it could scroll too
         call ig_text('below the region')
      enddo
      window_scroll = igGetScrollY()
   endif
   call ig_end()
   select case (frame)
   case (3_int32)
      call test_click(line_at(1), line_at(2))
   case (15_int32)
      call test_mouse_move(list_at(1), list_at(2))
   case (20_int32)
      call test_wheel(-3.0_real64)                    ! towards the user: the region scrolls down
   endselect
enddo
call app%destroy()

test_passed(1) = current == 2_int32 .and. clicks == 1_int32                       ! a click selects line 2, once
test_passed(2) = wrap_rect(4) - wrap_rect(2) > 1.5_real64 * line_height           ! wrapped: more than one line
test_passed(3) = wrap_rect(3) <= help_right + 0.5_real64                          ! ... inside the region
test_passed(4) = color_after%x == color_before%x .and. color_after%y == color_before%y .and. &
                 color_after%z == color_before%z .and. color_after%w == color_before%w ! colours restored
test_passed(5) = child_scroll > 0.0_c_float                                       ! the region scrolled
test_passed(6) = window_scroll == 0.0_c_float                                     ! its window did not
test_passed(7) = abs(col_x - (win_x + 200.0_real64)) < 1.0_real64                 ! ig_same_line(offset)

write(output_unit, '(A,*(L2))') 'figure_test_text checks:', test_passed
if (.not. all(test_passed)) write(output_unit, '(A,I0,A,I0,A,4F8.1,A,F8.1,A,2F8.1,A,2F8.1)') 'current ', current, &
   ', clicks ', clicks, ', wrapped ', wrap_rect, ', help right ', help_right, ', scrolls ', child_scroll, &
   window_scroll, ', column x ', col_x, win_x
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine test_window_rect_left(name, x)
   !< Left edge of a window as drawn in the last frame.
   use figure_testing, only : test_window_rect
   character(len=*), intent(in)  :: name !< Window name.
   real(real64),     intent(out) :: x    !< Left [pixels].
   real(real64)                  :: r(3) !< The rest of the rectangle.

   call test_window_rect(name, x, r(1), r(2), r(3))
   endsubroutine test_window_rect_left
endprogram figure_test_text
