!< figure_test_code_editor_input, the Fortran code editor's keys and mouse, as the C++ one's: state and pictures.
program figure_test_code_editor_input
!< figure_test_code_editor_input, the Fortran code editor's keys and mouse, as the C++ one's: state and pictures.
!<
!< szaghi/figure#15 P16, step 12. Each case sets up two editors by the same calls of FIGURE's public API, the C++ one
!< (`figure_editor_ref`) and the Fortran one (`figure_editor`), then plays the same scripted input (figure_testing's
!< keys, characters, clicks, drags, wheel) to the C++ one for NF frames in a window, then to the Fortran one in another
!< window at the same place, 40 frames apart. Compared on every frame: `draw`'s result, the text (its length and a
!< checksum), the cursor, the selection, four lines' rectangles; on the last frame, the picture (threshold 2, no pixel
!< failing). The cases:
!<
!< 1. keys: typing, enter (auto-indent after an indented line and after `(`), tab, backspace and delete by characters and
!<    by words, the arrows with and without shift and ctrl, home, end, ctrl+home, ctrl+end, page up and down, undo and
!<    redo, select all and type over it, grow and shrink the selection (alt+shift+arrows), ctrl+d (the next occurrence,
!<    two cursors typed into), escape, ctrl+shift+k, ctrl+enter, shift+enter, alt+up and down, tab and shift+tab on a
!<    selection (indent, deindent);
!< 2. the mouse: a click in the text, shift+click, ctrl+click (two cursors), a double click on a word and on a bracket,
!<    a triple click, a click and a drag on the line numbers, a drag over the text, the middle button's panning, the
!<    wheel;
!< 3. the clipboard: copy and paste a selection, cut, a line copied with no selection, a read-only editor (keys move,
!<    nothing typed changes the text).
!<
!< The pictures are `figure_test_code_editor_input.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_fortran_env, only : int32, int64, output_unit, real64
use figure, only : app_object, ig_begin, ig_end, ig_set_next_window, ImGuiWindowFlags_NoDecoration
use figure_editor_ref, only : code_editor_object, code_language
use figure_editor, only : f_code_editor_object => code_editor_object, f_code_language => code_language
use figure_testing, only : test_capture, test_click, test_compare_image, test_drag, test_key, test_mouse_button, &
                           test_mouse_move, test_type, test_wheel

implicit none
integer(int32),   parameter :: W = 640_int32  !< Display width [pixels].
integer(int32),   parameter :: H = 360_int32  !< Display height [pixels].
integer(int32),   parameter :: NCASE = 3_int32 !< Cases.
integer(int32),   parameter :: NF = 140_int32 !< Frames per side.
integer(int32),   parameter :: NV = 30_int32  !< Values compared per frame.
character(len=*), parameter :: LF = achar(10) !< Line feed.
type(app_object)            :: app             !< Application.
type(code_editor_object)    :: c               !< The C++ editor.
type(f_code_editor_object)  :: f               !< The Fortran editor.
real(real64)                :: state(NV, NF, 2) !< Per frame and side.
logical                     :: test_passed(NCASE) !< Per-case outcome.
integer(int32)              :: k, side, fr, i  !< Case, side, frame, counter.
character(len=16)           :: keep            !< FIGURE_TEST_KEEP.
character(len=8)            :: id              !< The editor's id.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do k = 1_int32, NCASE
   write(id, '(A,I0)') 'input', k
   state = 0.0_real64
   do side = 1_int32, 2_int32
      call setup(k)
      do fr = 1_int32, NF
         call inject(k, fr)
         if (.not. app%next_frame()) error stop 'figure_test_code_editor_input: next_frame returned false headless'
         call ig_set_next_window(10.0_real64, 10.0_real64, 620.0_real64, 340.0_real64, always=.true.)
         if (ig_begin(merge('editor C', 'editor F', side == 1_int32), flags=ImGuiWindowFlags_NoDecoration)) then
            call draw(side, state(:, fr, side))
         endif
         call ig_end()
         if (fr == NF) call test_capture(picture(k, side))
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      do i = 1_int32, 40_int32
         if (.not. app%next_frame()) error stop 'figure_test_code_editor_input: next_frame returned false headless'
      enddo
   enddo
   test_passed(k) = all(state(:, :, 1) == state(:, :, 2))
   if (.not. test_passed(k)) call report(k)
   test_passed(k) = test_passed(k) .and. test_compare_image(picture(k, 2), picture(k, 1))
enddo
call c%destroy()
call f%destroy()
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_code_editor_input checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   function picture(kk, sd) result(path)
   !< A case's picture by a side.
   integer(int32), intent(in)    :: kk, sd !< Case, side.
   character(len=:), allocatable :: path   !< File.
   character(len=64)             :: s      !< Buffer.

   write(s, '(A,I0,A)') 'figure_test_code_editor_input.', kk, merge('.cpp.png.tmp    ', '.fortran.png.tmp', sd == 1_int32)
   path = trim(s)
   endfunction picture

   pure function checksum(t) result(s)
   !< A checksum of a text.
   character(len=*), intent(in) :: t !< Text.
   real(real64)                 :: s !< Checksum.
   integer(int64)               :: h, j !< Hash, counter.

   h = 0_int64
   do j = 1_int64, len(t, int64)
      h = modulo(h * 131_int64 + int(iachar(t(j:j)), int64), 2147483647_int64)
   enddo
   s = real(h, real64)
   endfunction checksum

   subroutine draw(sd, v)
   !< One frame of a side: the editor, then its state.
   integer(int32), intent(in)    :: sd   !< Side.
   real(real64),   intent(inout) :: v(:) !< State.
   integer(int32)                :: j, l0, c0, l1, c1, n !< Line, selection, length.
   logical                       :: ch, has, vis !< Changed, a selection, visible.
   real(real64)                  :: r(4) !< A rectangle.

   if (sd == 1_int32) then
      ch = c%draw(trim(id))
      n = len(c%text())
      v(2) = checksum(c%text())
      call c%cursor(l0, c0)
      v(3:4) = [real(l0, real64), real(c0, real64)]
      has = c%selection(l0, c0, l1, c1)
      do j = 1_int32, 4_int32
         vis = c%line_rect(j, r(1), r(2), r(3), r(4))
         if (.not. vis) r = -1.0_real64
         v(10 + 4 * j - 3:10 + 4 * j) = r
      enddo
   else
      ch = f%draw(trim(id))
      n = len(f%text())
      v(2) = checksum(f%text())
      call f%cursor(l0, c0)
      v(3:4) = [real(l0, real64), real(c0, real64)]
      has = f%selection(l0, c0, l1, c1)
      do j = 1_int32, 4_int32
         vis = f%line_rect(j, r(1), r(2), r(3), r(4))
         if (.not. vis) r = -1.0_real64
         v(10 + 4 * j - 3:10 + 4 * j) = r
      enddo
   endif
   v(1) = real(n, real64)
   v(5:9) = [real(l0, real64), real(c0, real64), real(l1, real64), real(c1, real64), merge(1.0_real64, 0.0_real64, has)]
   v(10) = merge(1.0_real64, 0.0_real64, ch)
   endsubroutine draw

   subroutine setup(kk)
   !< The two editors set up for case kk by the same calls.
   integer(int32), intent(in)    :: kk !< Case.
   character(len=:), allocatable :: t  !< Text.
   integer(int32)                :: j  !< Counter.

   call c%destroy()
   call f%destroy()
   select case (kk)
   case (1_int32)
      call c%init(code_language('fortran'))
      call f%init(f_code_language('fortran'))
      t = 'alpha beta gamma'//LF//'  delta (epsilon, zeta)'//LF//'omega beta'//LF//'  x = [1, 2]'//LF//'end'
   case (2_int32)
      call c%init(code_language('fortran'))
      call f%init(f_code_language('fortran'))
      t = ''
      do j = 1_int32, 40_int32
         t = t//'line '//repeat('w', j * 3_int32)//' call f(a, (b + c)) word'//LF
      enddo
   case default
      call c%init(code_language('input'))
      call f%init(f_code_language('input'))
      t = '[section]'//LF//' key one = 1'//LF//' key two = 2'//LF//''//LF//' last = 3'
   endselect
   call c%set_text(t)
   call f%set_text(t)
   call c%goto(2_int32, 5_int32, focus=.true.)
   call f%goto(2_int32, 5_int32, focus=.true.)
   endsubroutine setup

   subroutine chord(mods, key)
   !< A key with modifiers held (space-separated modifier names).
   character(len=*), intent(in) :: mods !< Modifiers.
   character(len=*), intent(in) :: key  !< Key.
   integer(int32)               :: a, b !< A modifier's span.

   a = 1_int32
   do while (a <= len(mods, int32))
      b = index(mods(a:), ' ')
      if (b == 0) then
         b = len(mods, int32) + 1_int32
      else
         b = a + b - 1_int32
      endif
      if (b > a) call test_key(mods(a:b - 1_int32), down=.true.)
      a = b + 1_int32
   enddo
   call test_key(key)
   a = 1_int32
   do while (a <= len(mods, int32))
      b = index(mods(a:), ' ')
      if (b == 0) then
         b = len(mods, int32) + 1_int32
      else
         b = a + b - 1_int32
      endif
      if (b > a) call test_key(mods(a:b - 1_int32), down=.false.)
      a = b + 1_int32
   enddo
   endsubroutine chord

   subroutine inject(kk, fr)
   !< The input of case kk at frame fr (the same on both sides).
   integer(int32), intent(in) :: kk, fr !< Case, frame.

   select case (kk)
   case (1_int32)
      select case (fr)
      case (4)
         call test_type('xy')
      case (8)
         call test_key('enter')
      case (12)
         call test_type('q(')
      case (15)
         call test_key('enter')
      case (19)
         call test_key('tab')
      case (22)
         call test_key('backspace')
      case (25)
         call chord('ctrl', 'backspace')
      case (29)
         call test_key('left')
      case (32)
         call chord('shift', 'left')
      case (35)
         call test_key('delete')
      case (38)
         call test_key('up')
      case (41)
         call chord('shift', 'down')
      case (44)
         call test_key('end')
      case (47)
         call chord('ctrl', 'home')
      case (50)
         call chord('ctrl', 'right')
      case (53)
         call chord('ctrl shift', 'right')
      case (56)
         call chord('ctrl', 'end')
      case (59)
         call test_key('home')
      case (62)
         call chord('shortcut', 'z')
      case (66)
         call chord('shortcut', 'y')
      case (70)
         call chord('ctrl', 'home')
      case (73)
         call test_key('down')
      case (76)
         call chord('alt shift', 'right')
      case (79)
         call chord('alt shift', 'right')
      case (82)
         call chord('alt shift', 'left')
      case (85)
         call chord('ctrl', 'up')
      case (88)
         call chord('alt shift', 'right')
      case (91)
         call chord('ctrl', 'd')
      case (94)
         call test_type('B')
      case (97)
         call test_key('escape')
      case (100)
         call chord('ctrl shift', 'k')
      case (103)
         call chord('ctrl', 'enter')
      case (106)
         call chord('shift', 'enter')
      case (109)
         call chord('alt', 'down')
      case (112)
         call chord('alt', 'up')
      case (115)
         call chord('shift', 'down')
      case (118)
         call test_key('tab')
      case (121)
         call chord('shift', 'tab')
      case (124)
         call test_key('pagedown')
      case (127)
         call test_key('pageup')
      case (130)
         call chord('shortcut', 'a')
      case (133)
         call test_type('new')
      endselect
   case (2_int32)
      select case (fr)
      case (4)
         call test_click(150.0_real64, 56.0_real64)
      case (10)
         call test_key('shift', down=.true.)
         call test_click(220.0_real64, 86.0_real64)
      case (16)
         call test_key('shift', down=.false.)
         call test_key('ctrl', down=.true.)
         call test_click(130.0_real64, 116.0_real64)
      case (22)
         call test_key('ctrl', down=.false.)
         call test_type('Z')
      case (26)
         call test_click(200.0_real64, 146.0_real64)
         call test_click(200.0_real64, 146.0_real64)
      case (40)
         call test_click(320.0_real64, 161.0_real64)
         call test_click(320.0_real64, 161.0_real64)
      case (54)
         call test_click(250.0_real64, 176.0_real64)
         call test_click(250.0_real64, 176.0_real64)
         call test_click(250.0_real64, 176.0_real64)
      case (72)
         call test_click(30.0_real64, 206.0_real64)
      case (80)
         call test_drag(30.0_real64, 221.0_real64, 30.0_real64, 266.0_real64)
      case (90)
         call test_drag(120.0_real64, 41.0_real64, 260.0_real64, 101.0_real64)
      case (100)
         call test_mouse_move(300.0_real64, 200.0_real64)
         call test_mouse_button(.true., 'middle')
      case (102)
         call test_mouse_move(250.0_real64, 150.0_real64)
      case (106)
         call test_mouse_button(.false., 'middle')
      case (112)
         call test_mouse_move(300.0_real64, 200.0_real64)
         call test_wheel(-3.0_real64)
      case (118)
         call test_wheel(2.0_real64)
      case (124)
         call test_click(180.0_real64, 120.0_real64)
      endselect
   case default
      select case (fr)
      case (4)
         call chord('shift', 'end')
      case (7)
         call chord('ctrl', 'c')
      case (10)
         call test_key('down')
      case (13)
         call chord('ctrl', 'v')
      case (17)
         call chord('shift', 'up')
      case (20)
         call chord('ctrl', 'x')
      case (24)
         call test_key('down')
      case (27)
         call chord('ctrl', 'v')
      case (31)
         call chord('ctrl', 'c')
      case (34)
         call test_key('down')
      case (37)
         call chord('ctrl', 'v')
      case (41)
         call test_type('abc')
      case (45)
         call test_key('enter')
      case (49)
         call chord('shortcut', 'z')
      case (53)
         call test_click(200.0_real64, 71.0_real64)
      case (60)
         call test_drag(100.0_real64, 41.0_real64, 180.0_real64, 56.0_real64)
      case (66)
         call c%read_only(.true.)
         call f%read_only(.true.)
      case (70)
         call test_type('zz')
      case (74)
         call test_key('backspace')
      case (78)
         call test_key('down')
      case (82)
         call chord('ctrl', 'x')
      endselect
   endselect
   endsubroutine inject

   subroutine report(kk)
   !< The first frame whose state differs.
   integer(int32), intent(in) :: kk !< Case.
   integer(int32)             :: j, q !< Frame, value.

   do j = 1_int32, NF
      do q = 1_int32, NV
         if (state(q, j, 1) /= state(q, j, 2)) then
            write(output_unit, '(A,I0,A,I0,A,I0,2(1X,G0))') 'case ', kk, ', frame ', j, ', value ', q, &
                                                             state(q, j, 1), state(q, j, 2)
            return
         endif
      enddo
   enddo
   endsubroutine report

   subroutine remove_files()
   !< Remove the pictures.
   integer(int32) :: kk, sd, u, ios !< Case, side, unit, status.

   do kk = 1_int32, NCASE
      do sd = 1_int32, 2_int32
         open(newunit=u, file=picture(kk, sd), status='old', iostat=ios)
         if (ios == 0_int32) close(u, status='delete')
      enddo
   enddo
   endsubroutine remove_files
endprogram figure_test_code_editor_input
