!< figure_test_code_editor_draw, the Fortran code editor drawn as the C++ one: pictures and layout to the bit.
program figure_test_code_editor_draw
!< figure_test_code_editor_draw, the Fortran code editor drawn as the C++ one: pictures and layout to the bit.
!<
!< szaghi/figure#15 P16, step 11. Each case sets up two editors by the same calls of FIGURE's public API, the C++ one
!< (`figure_editor`: ImGuiColorTextEdit and the native glue) and the Fortran one (`figure_editor_fortran`, the same
!< module over the Fortran editor), then draws the C++ one for NF frames in a window, the Fortran one for NF frames in
!< another window at the same place, 40 frames apart. Compared, on every frame: `draw`'s result, the cursor, the
!< selection, every line's rectangle (`line_rect`, to the bit); on the last frame of each side, the picture
!< (`test_compare_image`, threshold 2, no pixel failing). No key and no click (the keys and the mouse are a later
!< step); the pointer may rest on the editor (the marks' tooltips). The cases:
!<
!< 1. an input file (key = value), CR LF, the fallback font's symbols, marks of three severities (tinted lines and
!<    numbers, the icons), the editor focused (the caret, the current line), the pointer on a marked line (its tooltip);
!< 2. Fortran, nested brackets and a mismatched one (their colours, the error colour), the cursor inside a pair spanning
!<    lines (the active pair's background, the pairs' lines), a selection over three lines;
!< 3. 120 lines (three digits), white space shown, tab size 8, tabs, wide glyphs, the cursor sent to line 80, column 70
!<    (both scrolls), a mark there;
!< 4. a light theme (the fork's light palette), no line numbers, no current line, read-only, a language of the
!<    program's own (case-insensitive keywords, `#` comments), the pointer on a line number's mark.
!<
!< The pictures are `figure_test_code_editor_draw.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object, code_editor_object, code_language, ig_begin, ig_end, ig_set_next_window, &
                   ImGuiWindowFlags_NoDecoration, language_object
use figure_editor_fortran, only : f_code_editor_object => code_editor_object, f_code_language => code_language, &
                                  f_language_object => language_object
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

implicit none
integer(int32),   parameter :: W = 640_int32                         !< Display width [pixels].
integer(int32),   parameter :: H = 360_int32                         !< Display height [pixels].
integer(int32),   parameter :: NCASE = 4_int32                       !< Cases.
integer(int32),   parameter :: NF = 8_int32                          !< Frames per side.
integer(int32),   parameter :: NL = 12_int32                         !< Lines whose rectangles are compared.
character(len=*), parameter :: LF = achar(10)                        !< Line feed.
character(len=*), parameter :: CR = achar(13)                        !< Carriage return.
character(len=*), parameter :: TAB = achar(9)                        !< Tab.
character(len=*), parameter :: RHO = char(207)//char(129)            !< U+03C1.
character(len=*), parameter :: HAN = char(228)//char(184)//char(173) !< U+4E2D, two columns wide.
type(app_object)            :: app             !< Application.
type(code_editor_object)    :: c               !< The C++ editor.
type(f_code_editor_object)  :: f               !< The Fortran editor.
real(real64)                :: state(4 * NL + 8, NF, 2) !< Per frame and side.
logical                     :: test_passed(NCASE) !< Per-case outcome.
integer(int32)              :: k, side, fr, i  !< Case, side, frame, counter.
character(len=16)           :: keep            !< FIGURE_TEST_KEEP.
character(len=8)            :: id              !< The editor's id.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do k = 1_int32, NCASE
   call setup(k)
   write(id, '(A,I0)') 'code', k
   state = 0.0_real64
   do side = 1_int32, 2_int32
      if (k == 1_int32) call test_mouse_move(300.0_real64, 62.0_real64)
      if (k == 4_int32) call test_mouse_move(14.0_real64, 50.0_real64)
      do fr = 1_int32, NF
         if (.not. app%next_frame()) error stop 'figure_test_code_editor_draw: next_frame returned false headless'
         call ig_set_next_window(10.0_real64, 10.0_real64, 620.0_real64, 340.0_real64, always=.true.)
         if (ig_begin(merge('editor C', 'editor F', side == 1_int32), flags=ImGuiWindowFlags_NoDecoration)) then
            call draw(side, state(:, fr, side))
         endif
         call ig_end()
         if (fr == NF) call test_capture(picture(k, side))
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      do i = 1_int32, 40_int32
         if (.not. app%next_frame()) error stop 'figure_test_code_editor_draw: next_frame returned false headless'
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

write(output_unit, '(A,*(L2))') 'figure_test_code_editor_draw checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   function picture(kk, sd) result(path)
   !< A case's picture by a side.
   integer(int32), intent(in)    :: kk, sd !< Case, side.
   character(len=:), allocatable :: path   !< File.
   character(len=64)             :: s      !< Buffer.

   write(s, '(A,I0,A)') 'figure_test_code_editor_draw.', kk, merge('.cpp.png.tmp    ', '.fortran.png.tmp', sd == 1_int32)
   path = trim(s)
   endfunction picture

   subroutine draw(sd, v)
   !< One frame of a side: the editor, then its state.
   integer(int32), intent(in)    :: sd   !< Side.
   real(real64),   intent(inout) :: v(:) !< State.
   integer(int32)                :: j, l0, c0, l1, c1 !< Line, selection.
   logical                       :: ch, has, vis !< Changed, a selection, visible.

   if (sd == 1_int32) then
      ch = c%draw(trim(id))
      call c%cursor(l0, c0)
      v(1:2) = [real(l0, real64), real(c0, real64)]
      has = c%selection(l0, c0, l1, c1)
      do j = 1_int32, NL
         vis = c%line_rect(j, v(8 + 4 * j - 3), v(8 + 4 * j - 2), v(8 + 4 * j - 1), v(8 + 4 * j))
         if (.not. vis) v(8 + 4 * j - 3:8 + 4 * j) = -1.0_real64
      enddo
   else
      ch = f%draw(trim(id))
      call f%cursor(l0, c0)
      v(1:2) = [real(l0, real64), real(c0, real64)]
      has = f%selection(l0, c0, l1, c1)
      do j = 1_int32, NL
         vis = f%line_rect(j, v(8 + 4 * j - 3), v(8 + 4 * j - 2), v(8 + 4 * j - 1), v(8 + 4 * j))
         if (.not. vis) v(8 + 4 * j - 3:8 + 4 * j) = -1.0_real64
      enddo
   endif
   v(3:7) = [real(l0, real64), real(c0, real64), real(l1, real64), real(c1, real64), merge(1.0_real64, 0.0_real64, has)]
   v(8) = merge(1.0_real64, 0.0_real64, ch)
   endsubroutine draw

   subroutine setup(kk)
   !< The two editors set up for case kk by the same calls.
   integer(int32), intent(in)    :: kk  !< Case.
   type(language_object)         :: lc  !< A language, C++ side.
   type(f_language_object)       :: lf_ !< ... Fortran side.
   character(len=:), allocatable :: t   !< Text.
   integer(int32)                :: j   !< Counter.

   call c%destroy()
   call f%destroy()
   select case (kk)
   case (1_int32)
      call app%set_style('dark')
      call c%init(code_language('input'))
      call f%init(f_code_language('input'))
      t = '[fluid-properties]'//CR//LF//' reynolds number = -15'//LF//' mach number = 0.3 ! subsonic'//LF// &
          ' prandtl number = 0.71'//LF//' '//RHO//' = 1.225'//LF//''//LF//'[output-parameters]'//LF// &
          ' save frequency = 100 # every'
      call c%set_text(t)
      call f%set_text(t)
      call c%mark(2_int32, 'error', 'reynolds number must be positive')
      call f%mark(2_int32, 'error', 'reynolds number must be positive')
      call c%mark(3_int32, 'warning', 'mach number below 0.5')
      call f%mark(3_int32, 'warning', 'mach number below 0.5')
      call c%mark(5_int32, 'info', 'density of air')
      call f%mark(5_int32, 'info', 'density of air')
      call c%goto(2_int32, 5_int32, focus=.true.)
      call f%goto(2_int32, 5_int32, focus=.true.)
   case (2_int32)
      call c%init(code_language('fortran'))
      call f%init(f_code_language('fortran'))
      t = 'module heat'//LF//'implicit none'//LF//'contains'//LF//'   pure subroutine step(u, dt)'//LF// &
          '   real(8), intent(inout) :: u(:)  ! the field'//LF//'   u(2:size(u) - 1) = [(u(i) * (dt + 1.5d0), &'// &
          LF//'      i = 1, size(u))] + "a(b"'//LF//'   x = ((y) + z]'//LF//'   endsubroutine step'//LF// &
          '#ifdef DEBUG'//LF//'endmodule heat'
      call c%set_text(t)
      call f%set_text(t)
      call c%select(2_int32, 3_int32, 7_int32, 9_int32)
      call f%select(2_int32, 3_int32, 7_int32, 9_int32)
   case (3_int32)
      call c%init()
      call f%init()
      t = ''
      do j = 1_int32, 120_int32
         if (mod(j, 7_int32) == 0_int32) then
            t = t//TAB//'tabbed'//TAB//HAN//HAN//' line'//LF
         else
            t = t//'line number '//repeat('x', mod(j * 13_int32, 90_int32))//' end'//LF
         endif
      enddo
      call c%set_text(t)
      call f%set_text(t)
      call c%set_options(whitespace=.true., tab_size=8_int32)
      call f%set_options(whitespace=.true., tab_size=8_int32)
      call c%mark(80_int32, 'warning', 'far down')
      call f%mark(80_int32, 'warning', 'far down')
      call c%goto(80_int32, 70_int32, focus=.true.)
      call f%goto(80_int32, 70_int32, focus=.true.)
   case default
      call app%set_style('light')
      call lc%init('solver log', keywords=['converged', 'diverged '], types=['step'], comment='#', &
                   case_sensitive=.false.)
      call lf_%init('solver log', keywords=['converged', 'diverged '], types=['step'], comment='#', &
                    case_sensitive=.false.)
      call c%init(lc)
      call f%init(lf_)
      t = '# run 7'//LF//'STEP 100 residual 1.2e-3'//LF//'step 200 residual (3.4e-5)'//LF//'Converged after 200'
      call c%set_text(t)
      call f%set_text(t)
      call c%set_options(line_numbers=.false., line_highlight=.false.)
      call f%set_options(line_numbers=.false., line_highlight=.false.)
      call c%read_only(.true.)
      call f%read_only(.true.)
      call c%mark(3_int32, 'error', 'slow')
      call f%mark(3_int32, 'error', 'slow')
      call c%goto(3_int32, 22_int32)
      call f%goto(3_int32, 22_int32)
   endselect
   endsubroutine setup

   subroutine report(kk)
   !< The first frame whose state differs.
   integer(int32), intent(in) :: kk !< Case.
   integer(int32)             :: j, q !< Frame, value.

   do j = 1_int32, NF
      do q = 1_int32, size(state, 1)
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
endprogram figure_test_code_editor_draw
