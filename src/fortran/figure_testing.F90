!< figure_testing, synthetic input for testing interfaces without a display (or with one).
module figure_testing
!< figure_testing, synthetic input for testing interfaces without a display (or with one).
!<
!< Input is queued and applied while the program draws its next frames, as real input would be: a test queues a
!< click, draws a few frames (`app%next_frame()` and the program's own UI code), then checks the program's variables.
!< Everything queued reaches Dear ImGui at the next frame, up to a frame boundary (`test_next_frame`); Dear ImGui
!< then applies one change of each kind per frame (input trickling), so a move, a press and a release queued at once
!< become a click over the next frames.
!<
!<```fortran
!< call test_click(x, y)           ! the centre of the button, e.g. from ig_item_rect in an earlier frame
!< do frame = 1, 4
!<    if (.not. app%next_frame()) exit
!<    call draw_panel(panel)       ! the UI under test
!< enddo
!< ! now check what the click did to the program's variables
!<```
!<
!< Coordinates are display pixels, as `ig_item_rect` and `test_window_rect` give them. Works in every mode; with
!< `app%init_headless` no window, display or GPU is needed, so tests run in CI as is.
use, intrinsic :: iso_c_binding, only : c_float, c_int
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure_base, only : figure_check, figure_fail
use figure_c_native, only : FIG_ERR_ARGUMENT, fig_input_key, fig_input_mouse_button, fig_input_mouse_pos, &
                            fig_input_next_frame, fig_input_text, fig_input_wheel, fig_window_rect
use figure_imgui, only : ig_item_rect

implicit none
private
public :: test_mouse_move, test_mouse_button, test_click, test_drag, test_wheel, test_key, test_type
public :: test_window_rect, test_item_center, test_next_frame

contains
   subroutine test_next_frame(stat)
   !< A frame boundary in the queued input: what is queued after it reaches Dear ImGui one frame later than what is
   !< queued before it. For sequences that must not share a frame (a drag: press, move, release).
   integer(int32), intent(out), optional :: stat !< Status.

   call figure_check(fig_input_next_frame(), stat)
   endsubroutine test_next_frame

   subroutine test_mouse_move(x, y, stat)
   !< Queue a move of the mouse to (x, y).
   real(real64),   intent(in)            :: x    !< Abscissa [pixels].
   real(real64),   intent(in)            :: y    !< Ordinate [pixels].
   integer(int32), intent(out), optional :: stat !< Status: `FIG_ERR_STATE` before `init*`.

   call figure_check(fig_input_mouse_pos(real(x, c_float), real(y, c_float)), stat)
   endsubroutine test_mouse_move

   subroutine test_mouse_button(down, button, stat)
   !< Queue a press (`down=.true.`) or a release of a mouse button.
   logical,          intent(in)            :: down   !< Pressed.
   character(len=*), intent(in),  optional :: button !< `'left'` (default), `'right'` or `'middle'`.
   integer(int32),   intent(out), optional :: stat   !< Status: `FIG_ERR_ARGUMENT` for an unknown button.
   integer(c_int)                          :: b      !< Button.

   if (.not. button_index(button, b)) then
      call figure_fail(FIG_ERR_ARGUMENT, "test_mouse_button: button must be 'left', 'right' or 'middle'", stat)
      return
   endif
   call figure_check(fig_input_mouse_button(b, merge(1_c_int, 0_c_int, down)), stat)
   endsubroutine test_mouse_button

   subroutine test_click(x, y, button, stat)
   !< Queue a click at (x, y): a move, a press and a release, applied over the next three frames.
   real(real64),     intent(in)            :: x      !< Abscissa [pixels].
   real(real64),     intent(in)            :: y      !< Ordinate [pixels].
   character(len=*), intent(in),  optional :: button !< `'left'` (default), `'right'` or `'middle'`.
   integer(int32),   intent(out), optional :: stat   !< Status.
   integer(c_int)                          :: b      !< Button.

   if (.not. button_index(button, b)) then
      call figure_fail(FIG_ERR_ARGUMENT, "test_click: button must be 'left', 'right' or 'middle'", stat)
      return
   endif
   call figure_check(fig_input_mouse_pos(real(x, c_float), real(y, c_float)), stat)
   call figure_check(fig_input_mouse_button(b, 1_c_int), stat)
   call figure_check(fig_input_mouse_button(b, 0_c_int), stat)
   endsubroutine test_click

   subroutine test_drag(x0, y0, x1, y1, stat)
   !< Queue a drag with the left button from (x0, y0) to (x1, y1): a slider grab moved, a window dragged by its title.
   real(real64),   intent(in)            :: x0   !< Start abscissa [pixels].
   real(real64),   intent(in)            :: y0   !< Start ordinate [pixels].
   real(real64),   intent(in)            :: x1   !< End abscissa [pixels].
   real(real64),   intent(in)            :: y1   !< End ordinate [pixels].
   integer(int32), intent(out), optional :: stat !< Status.

   call figure_check(fig_input_mouse_pos(real(x0, c_float), real(y0, c_float)), stat)
   call figure_check(fig_input_mouse_button(0_c_int, 1_c_int), stat)
   call figure_check(fig_input_next_frame(), stat) ! the press is seen at the start before the mouse moves
   call figure_check(fig_input_mouse_pos(real(x1, c_float), real(y1, c_float)), stat)
   call figure_check(fig_input_next_frame(), stat) ! the move is seen with the button still down
   call figure_check(fig_input_mouse_button(0_c_int, 0_c_int), stat)
   endsubroutine test_drag

   subroutine test_wheel(dy, dx, stat)
   !< Queue a turn of the wheel: `dy` positive away from the user (zoom in, in a plot), `dx` horizontal.
   real(real64),   intent(in)            :: dy   !< Vertical steps.
   real(real64),   intent(in),  optional :: dx   !< Horizontal steps (default 0).
   integer(int32), intent(out), optional :: stat !< Status.
   real(c_float)                         :: h    !< Horizontal.

   h = 0.0_c_float
   if (present(dx)) h = real(dx, c_float)
   call figure_check(fig_input_wheel(h, real(dy, c_float)), stat)
   endsubroutine test_wheel

   subroutine test_key(name, down, stat)
   !< Queue a key: pressed and released, or only pressed (`down=.true.`) or released (`down=.false.`). Names: `a`-`z`,
   !< `0`-`9`, `enter`, `tab`, `backspace`, `delete`, `escape`, `space`, `left`, `right`, `up`, `down`, `home`, `end`,
   !< `pageup`, `pagedown`, `f1`-`f12`, and the modifiers `ctrl`, `shift`, `alt`, `super` (hold one with `down`).
   character(len=*), intent(in)            :: name !< Key name.
   logical,          intent(in),  optional :: down !< Only press (true) or only release (false).
   integer(int32),   intent(out), optional :: stat !< Status: `FIG_ERR_ARGUMENT` for an unknown name.

   if (present(down)) then
      call figure_check(fig_input_key(name, len(name, c_int), merge(1_c_int, 0_c_int, down)), stat)
   else
      call figure_check(fig_input_key(name, len(name, c_int), 1_c_int), stat)
      call figure_check(fig_input_key(name, len(name, c_int), 0_c_int), stat)
   endif
   endsubroutine test_key

   subroutine test_type(text, stat)
   !< Queue typed characters (UTF-8), into the focused input field.
   character(len=*), intent(in)            :: text !< Characters.
   integer(int32),   intent(out), optional :: stat !< Status.

   call figure_check(fig_input_text(text, len(text, c_int)), stat)
   endsubroutine test_type

   subroutine test_window_rect(name, xmin, ymin, xmax, ymax, found, stat)
   !< The rectangle of the window `name` (as passed to `ig_begin`) as drawn in the last frame [pixels].
   character(len=*), intent(in)            :: name  !< Window name.
   real(real64),     intent(out)           :: xmin  !< Left.
   real(real64),     intent(out)           :: ymin  !< Top.
   real(real64),     intent(out)           :: xmax  !< Right.
   real(real64),     intent(out)           :: ymax  !< Bottom.
   logical,          intent(out), optional :: found !< The window exists (else the rectangle is zero).
   integer(int32),   intent(out), optional :: stat  !< Status.
   real(c_float)                           :: r(4)  !< Rectangle.
   integer(c_int)                          :: f     !< 1: found.

   r = 0.0_c_float
   f = 0_c_int
   call figure_check(fig_window_rect(name, len(name, c_int), r, f), stat)
   if (f /= 1_c_int) r = 0.0_c_float
   xmin = real(r(1), real64)
   ymin = real(r(2), real64)
   xmax = real(r(3), real64)
   ymax = real(r(4), real64)
   if (present(found)) found = f == 1_c_int
   endsubroutine test_window_rect

   subroutine test_item_center(x, y)
   !< The centre of the last item drawn (call it right after the widget): where `test_click` should aim.
   real(real64), intent(out) :: x    !< Abscissa [pixels].
   real(real64), intent(out) :: y    !< Ordinate [pixels].
   real(real64)              :: x0   !< Left.
   real(real64)              :: y0   !< Top.
   real(real64)              :: x1   !< Right.
   real(real64)              :: y1   !< Bottom.

   call ig_item_rect(x0, y0, x1, y1)
   x = 0.5_real64 * (x0 + x1)
   y = 0.5_real64 * (y0 + y1)
   endsubroutine test_item_center

   function button_index(button, b) result(ok)
   !< ImGuiMouseButton of a name (absent: left).
   character(len=*), intent(in), optional :: button !< Button name.
   integer(c_int),   intent(out)          :: b      !< Index.
   logical                                :: ok     !< Known name.

   b = 0_c_int
   ok = .true.
   if (.not. present(button)) return
   select case (trim(button))
   case ('left')
      b = 0_c_int
   case ('right')
      b = 1_c_int
   case ('middle')
      b = 2_c_int
   case default
      ok = .false.
   endselect
   endfunction button_index
endmodule figure_testing
