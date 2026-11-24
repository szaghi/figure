!< figure_test_code_editor_diff, the Fortran text diff drawn as the C++ one: pictures, keys, scrolling.
program figure_test_code_editor_diff
!< figure_test_code_editor_diff, the Fortran text diff drawn as the C++ one: pictures, keys, scrolling.
!<
!< szaghi/figure#15 P16, step 14. Each case draws the same `code_diff` calls of FIGURE's public API with the C++ one
!< (`figure_editor`: TextDiff, dtl and the native glue) for NF frames in a window, then with the Fortran one
!< (`figure_editor_fortran`) in another window at the same place, 40 frames apart, the same scripted input played to
!< each; compared: every call's status, and two pictures per case (threshold 2, no pixel failing). The cases:
!<
!< 1. one column (removed lines before the added ones, both line numbers, `+` and `-`), an input file coloured, a
!<    second diff of the same texts side by side below it;
!< 2. Fortran code side by side and in one column: lines changed, added, removed, tabs, a wide glyph, CR LF;
!< 3. long texts (60 lines, lines wider than the columns): the scroll bars (vertical, with the changes marked on it,
!<    and the horizontal ones under the text), the keys (a click to focus, then the arrows, page down, end, home) and
!<    the horizontal wheel, one column then side by side;
!< 4. the light theme, a byte order mark, an empty text against a text, two equal texts.
!<
!< The pictures are `figure_test_code_editor_diff.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_c_binding, only : c_bool
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object, code_diff, code_language, ig_begin, ig_end, ig_set_next_window, &
                   ImGuiWindowFlags_NoDecoration
use figure_cimgui, only : igSetNavCursorVisible
use figure_editor_fortran, only : f_code_diff => code_diff, f_code_language => code_language
use figure_testing, only : test_capture, test_click, test_compare_image, test_key, test_mouse_move, test_wheel

implicit none
integer(int32),   parameter :: W = 640_int32  !< Display width [pixels].
integer(int32),   parameter :: H = 360_int32  !< Display height [pixels].
integer(int32),   parameter :: NCASE = 4_int32 !< Cases.
integer(int32),   parameter :: NF = 60_int32  !< Frames per side.
integer(int32),   parameter :: MID = 30_int32 !< The frame of the first picture.
character(len=*), parameter :: LF = achar(10) !< Line feed.
character(len=*), parameter :: CR = achar(13) !< Carriage return.
character(len=*), parameter :: TAB = achar(9) !< Tab.
character(len=*), parameter :: HAN = char(228)//char(184)//char(173) !< U+4E2D, two columns wide.
character(len=*), parameter :: BOM = char(239)//char(187)//char(191) !< UTF-8 byte order mark.
type(app_object)            :: app             !< Application.
logical                     :: test_passed(NCASE) !< Per-case outcome.
integer(int32)              :: k, side, fr, i  !< Case, side, frame, counter.
integer(int32)              :: st(NF, 2, 2)    !< Statuses of the calls.
character(len=16)           :: keep            !< FIGURE_TEST_KEEP.
character(len=:), allocatable :: a, b          !< Texts.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do k = 1_int32, NCASE
   st = 0_int32
   call texts(k, a, b)
   if (k == 4_int32) call app%set_style('light')
   do side = 1_int32, 2_int32
      do fr = 1_int32, NF
         call inject(k, fr)
         if (.not. app%next_frame()) error stop 'figure_test_code_editor_diff: next_frame returned false headless'
         if (fr == 1_int32) call igSetNavCursorVisible(.false._c_bool)
         call ig_set_next_window(10.0_real64, 10.0_real64, 620.0_real64, 340.0_real64, always=.true.)
         if (ig_begin(merge('diff C', 'diff F', side == 1_int32), flags=ImGuiWindowFlags_NoDecoration)) then
            call draw(k, side, fr, st(fr, :, side))
         endif
         call ig_end()
         if (fr == MID) call test_capture(picture(10_int32 * k, side))
         if (fr == NF) call test_capture(picture(k, side))
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      do i = 1_int32, 40_int32
         if (.not. app%next_frame()) error stop 'figure_test_code_editor_diff: next_frame returned false headless'
      enddo
   enddo
   test_passed(k) = all(st(:, :, 1) == st(:, :, 2))
   if (.not. test_passed(k)) write(output_unit, '(A,I0)') 'statuses differ, case ', k
   test_passed(k) = test_passed(k) .and. test_compare_image(picture(k, 2), picture(k, 1)) .and. &
                    test_compare_image(picture(10_int32 * k, 2), picture(10_int32 * k, 1))
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_code_editor_diff checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   function picture(kk, sd) result(path)
   !< A case's picture by a side.
   integer(int32), intent(in)    :: kk, sd !< Case, side.
   character(len=:), allocatable :: path   !< File.
   character(len=64)             :: s      !< Buffer.

   write(s, '(A,I0,A)') 'figure_test_code_editor_diff.', kk, merge('.cpp.png.tmp    ', '.fortran.png.tmp', sd == 1_int32)
   path = trim(s)
   endfunction picture

   subroutine texts(kk, x, y)
   !< The texts of case kk.
   integer(int32),                intent(in)  :: kk   !< Case.
   character(len=:), allocatable, intent(out) :: x, y !< Old, new.
   integer(int32)                             :: j    !< Counter.

   select case (kk)
   case (1_int32)
      x = '[fluid]'//LF//' a = 1'//LF//' b = 2 ! two'//LF//' c = 3'
      y = '[fluid]'//LF//' a = 1'//LF//' b = 3 ! three'//LF//' c = 3'//LF//' d = 4'
   case (2_int32)
      x = 'module m'//LF//'implicit none'//LF//'contains'//LF//TAB//'subroutine s(x)'//LF//TAB//'x = x + 1'//LF// &
          TAB//'endsubroutine s'//LF//'endmodule m'
      y = 'module m'//CR//LF//'use iso_fortran_env'//LF//'implicit none'//LF//'contains'//LF//TAB// &
          'subroutine s(x) ! '//HAN//LF//TAB//'x = 2 * x + 1'//LF//'endmodule m'//LF
   case (3_int32)
      x = ''
      y = ''
      do j = 1_int32, 60_int32
         x = x//'line '//int_text(j)//' '//repeat('a', 2_int32 * j)//LF
         if (mod(j, 7_int32) == 0_int32) then
            y = y//'LINE '//int_text(j)//' '//repeat('b', 3_int32 * j)//LF
         elseif (mod(j, 11_int32) /= 0_int32) then
            y = y//'line '//int_text(j)//' '//repeat('a', 2_int32 * j)//LF
         endif
      enddo
   case default
      x = BOM//'same'//LF//'text'
      y = 'same'//LF//'text'//LF//'more'
   endselect
   endsubroutine texts

   pure function int_text(n) result(s)
   !< An integer as text.
   integer(int32), intent(in)    :: n !< Number.
   character(len=:), allocatable :: s !< Text.
   character(len=12)             :: b !< Buffer.

   write(b, '(I0)') n
   s = trim(b)
   endfunction int_text

   subroutine draw(kk, sd, fr, s)
   !< One frame of a side: the case's diffs, their statuses.
   integer(int32), intent(in)  :: kk, sd, fr !< Case, side, frame.
   integer(int32), intent(out) :: s(2)       !< Statuses.
   logical                     :: side_by_side !< Two columns.

   s = 0_int32
   select case (kk)
   case (1_int32)
      if (sd == 1_int32) then
         call code_diff('one', a, b, language=code_language('input'), height=150.0_real64, stat=s(1))
         call code_diff('two', a, b, side_by_side=.true., language=code_language('input'), stat=s(2))
      else
         call f_code_diff('one', a, b, language=f_code_language('input'), height=150.0_real64, stat=s(1))
         call f_code_diff('two', a, b, side_by_side=.true., language=f_code_language('input'), stat=s(2))
      endif
   case (2_int32, 3_int32)
      side_by_side = fr <= MID .eqv. kk == 2_int32
      if (sd == 1_int32) then
         call code_diff('code', a, b, side_by_side=side_by_side, language=code_language('fortran'), stat=s(1))
      else
         call f_code_diff('code', a, b, side_by_side=side_by_side, language=f_code_language('fortran'), stat=s(1))
      endif
   case default
      if (sd == 1_int32) then
         call code_diff('bom', a, b, height=100.0_real64, stat=s(1))
         call code_diff('empty', '', b, height=100.0_real64, stat=s(2))
         call code_diff('equal', b, b, side_by_side=.true., stat=s(2))
      else
         call f_code_diff('bom', a, b, height=100.0_real64, stat=s(1))
         call f_code_diff('empty', '', b, height=100.0_real64, stat=s(2))
         call f_code_diff('equal', b, b, side_by_side=.true., stat=s(2))
      endif
   endselect
   endsubroutine draw

   subroutine inject(kk, fr)
   !< The input of case kk at frame fr (the same on both sides).
   integer(int32), intent(in) :: kk, fr !< Case, frame.

   if (kk /= 3_int32) return
   select case (fr)
   case (4, 34)
      call test_click(300.0_real64, 150.0_real64)
   case (10, 40)
      call test_key('right')
   case (12, 42)
      call test_key('right')
   case (14, 44)
      call test_key('pagedown')
   case (17, 47)
      call test_key('down')
   case (20, 50)
      call test_key('end')
   case (23, 53)
      call test_mouse_move(300.0_real64, 150.0_real64)
      call test_wheel(0.0_real64, 2.0_real64)
   case (26)
      call test_key('home')
   endselect
   endsubroutine inject

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
endprogram figure_test_code_editor_diff
