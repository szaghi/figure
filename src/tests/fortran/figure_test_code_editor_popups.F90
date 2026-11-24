!< figure_test_code_editor_popups, the Fortran code editor's completion popup and find window, as the C++ one's.
program figure_test_code_editor_popups
!< figure_test_code_editor_popups, the Fortran code editor's completion popup and find window, as the C++ one's.
!<
!< szaghi/figure#15 P16, step 13. As figure_test_code_editor_input (the same scripted input to a C++ and a Fortran
!< editor, every frame's state to the bit, pictures at threshold 2 with no pixel failing), with the completion popup's
!< state too (open, the words offered) and two pictures per case (one mid-way, the popup or the window open). Each side
!< starts with Dear ImGui's navigation cursor hidden (the keys of the side before show it, and it outlives the side, a
!< frame border then drawn by the editor's navigation workaround). The cases:
!<
!< 1. completion (an input file, the program's keys): a term typed opens the popup (the keys that start with it, then
!<    those that contain it), down and up choose, tab inserts; a term of two words ("mach n"), enter inserts; a click
!<    on a suggestion; escape closes it; ctrl+space with no match ("No suggestions"); a term typed in a comment opens
!<    nothing;
!< 2. find and replace: ctrl+f opens the window with the word at the cursor, a text typed in its field selects the
!<    first occurrence, enter gives the keyboard back, ctrl+g finds the next, ctrl+shift+f all of them, the window's
!<    buttons clicked (Find, Aa, [], Replace, Replace All), a replacement typed, escape closes the window.
!<
!< The pictures are `figure_test_code_editor_popups.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_c_binding, only : c_bool
use, intrinsic :: iso_fortran_env, only : int32, int64, output_unit, real64
use figure, only : app_object, code_editor_object, code_language, ig_begin, ig_end, ig_set_next_window, &
                   ImGuiWindowFlags_NoDecoration
use figure_cimgui, only : igSetNavCursorVisible
use figure_editor_fortran, only : f_code_editor_object => code_editor_object, f_code_language => code_language
use figure_testing, only : test_capture, test_click, test_compare_image, test_key, test_mouse_move, test_type

implicit none
integer(int32),   parameter :: W = 640_int32  !< Display width [pixels].
integer(int32),   parameter :: H = 360_int32  !< Display height [pixels].
integer(int32),   parameter :: NCASE = 2_int32 !< Cases.
integer(int32),   parameter :: NF = 120_int32 !< Frames per side.
integer(int32),   parameter :: MID = 60_int32 !< The frame of the first picture.
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
         if (.not. app%next_frame()) error stop 'figure_test_code_editor_popups: next_frame returned false headless'
         if (fr == 1_int32) call igSetNavCursorVisible(.false._c_bool) ! each side from a hidden navigation cursor
         call ig_set_next_window(10.0_real64, 10.0_real64, 620.0_real64, 340.0_real64, always=.true.)
         if (ig_begin(merge('editor C', 'editor F', side == 1_int32), flags=ImGuiWindowFlags_NoDecoration)) then
            call draw(side, state(:, fr, side))
         endif
         call ig_end()
         if (fr == MID) call test_capture(picture(10_int32 * k, side))
         if (fr == NF) call test_capture(picture(k, side))
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      do i = 1_int32, 40_int32
         if (.not. app%next_frame()) error stop 'figure_test_code_editor_popups: next_frame returned false headless'
      enddo
   enddo
   test_passed(k) = all(state(:, :, 1) == state(:, :, 2))
   if (.not. test_passed(k)) call report(k)
   test_passed(k) = test_passed(k) .and. test_compare_image(picture(k, 2), picture(k, 1)) .and. &
                    test_compare_image(picture(10_int32 * k, 2), picture(10_int32 * k, 1))
enddo
call c%destroy()
call f%destroy()
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_code_editor_popups checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   function picture(kk, sd) result(path)
   !< A case's picture by a side.
   integer(int32), intent(in)    :: kk, sd !< Case, side.
   character(len=:), allocatable :: path   !< File.
   character(len=64)             :: s      !< Buffer.

   write(s, '(A,I0,A)') 'figure_test_code_editor_popups.', kk, merge('.cpp.png.tmp    ', '.fortran.png.tmp', sd == 1_int32)
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
   logical                       :: ch, has, vis, open !< Changed, a selection, visible, completing.
   character(len=:), allocatable :: words(:) !< Words offered.
   real(real64)                  :: r(4) !< A rectangle.

   if (sd == 1_int32) then
      ch = c%draw(trim(id))
      open = c%completing(words)
      v(27) = merge(1.0_real64, 0.0_real64, open)
      v(28) = real(size(words), real64)
      if (size(words) > 0) v(29) = checksum(words(1))
      if (size(words) > 0) v(30) = checksum(words(size(words)))
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
      open = f%completing(words)
      v(27) = merge(1.0_real64, 0.0_real64, open)
      v(28) = real(size(words), real64)
      if (size(words) > 0) v(29) = checksum(words(1))
      if (size(words) > 0) v(30) = checksum(words(size(words)))
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
      call c%init(code_language('input'))
      call f%init(f_code_language('input'))
      t = '[fluid]'//LF//' reynolds number = 1'//LF//' mach number = 0.3 ! a comment'//LF//''//LF//' save = 1'
      call c%set_text(t)
      call f%set_text(t)
      call c%set_completions(['reynolds number ', 'mach number     ', 'save frequency  ', 'prandtl number  ', &
                              'number of steps '])
      call f%set_completions(['reynolds number ', 'mach number     ', 'save frequency  ', 'prandtl number  ', &
                              'number of steps '])
      call c%goto(4_int32, 1_int32, focus=.true.)
      call f%goto(4_int32, 1_int32, focus=.true.)
   case default
      call c%init(code_language('fortran'))
      call f%init(f_code_language('fortran'))
      t = ''
      do j = 1_int32, 12_int32
         t = t//'   call step(field, dt)  ! Step '//repeat('x', j)//LF
      enddo
      call c%set_text(t)
      call f%set_text(t)
      call c%goto(3_int32, 10_int32, focus=.true.)
      call f%goto(3_int32, 10_int32, focus=.true.)
   endselect
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
         call test_type(' n')
      case (10)
         call test_type('u')
      case (14)
         call test_key('down')
      case (17)
         call test_key('down')
      case (20)
         call test_key('up')
      case (24)
         call test_key('tab')
      case (30)
         call test_key('enter')
      case (34)
         call test_type('mach n')
      case (42)
         call test_key('enter')
      case (48)
         call test_key('enter')
      case (52)
         call test_type('pr')
      case (64)
         call test_click(160.0_real64, 120.0_real64)
      case (72)
         call test_key('enter')
      case (76)
         call test_type('sa')
      case (82)
         call test_key('escape')
      case (86)
         call chord('ctrl', 'space')
      case (92)
         call test_key('escape')
      case (96)
         call test_key('enter')
      case (100)
         call test_type('zzz')
      case (104)
         call chord('ctrl', 'space')
      case (110)
         call test_type(' ! re')
      endselect
   case default
      select case (fr)
      case (4)
         call chord('ctrl', 'f')
      case (10)
         call test_type('Step x')
      case (16)
         call test_key('enter')
      case (22)
         call chord('ctrl', 'g')
      case (26)
         call chord('ctrl', 'g')
      case (30)
         call chord('ctrl shift', 'f')
      case (34)
         call test_key('escape')
      case (38)
         call chord('ctrl', 'f')
      case (44)
         call test_type('xxx')
      case (50)
         call test_key('tab')
      case (54)
         call test_type('XX')
      case (66)
         call test_click(586.0_real64, 34.0_real64)
      case (72)
         call test_click(586.0_real64, 58.0_real64)
      case (80)
         call test_click(530.0_real64, 34.0_real64)
      case (86)
         call test_click(498.0_real64, 58.0_real64)
      case (94)
         call test_click(562.0_real64, 34.0_real64)
      case (100)
         call test_click(610.0_real64, 34.0_real64)
      case (106)
         call chord('ctrl', 'f')
      case (112)
         call test_key('escape')
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
         open(newunit=u, file=picture(10_int32 * kk, sd), status='old', iostat=ios)
         if (ios == 0_int32) close(u, status='delete')
      enddo
   enddo
   endsubroutine remove_files
endprogram figure_test_code_editor_popups
