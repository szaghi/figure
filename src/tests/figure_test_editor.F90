!< figure_test_editor, the code editor (code_editor_object) and the text diff (code_diff, code_diff_lines), headless.
program figure_test_editor
!< figure_test_editor, the code editor (code_editor_object) and the text diff (code_diff, code_diff_lines), headless.
!<
!< An input file in the editor: its text read back (CR LF as LF), its lines counted; marks of three severities on
!< three lines, a second mark on a line joined, the marks kept on their lines after an edit (FIGURE's patch of the
!< fork); the window against a committed golden (src/tests/data/figure_test_editor.golden.png, |d| <= 2) and a
!< marked line tinted where an unmarked one is not; the fallback font's glyphs (rho, infinity) drawn in the editor,
!< not the missing-glyph box; typing changes the text and `draw` reports it; ctrl+z undoes it, `redo` and `undo`
!< too; find (by case or not, wrapping, not found) and replace in one undo; completion offers the keys that start
!< with the typed text and tab inserts one; a read-only editor refuses an insert and ignores typing; the diff's lines
!< and its drawing; the statuses. The pictures are `figure_test_editor.*.tmp`, removed at the end.
use, intrinsic :: iso_fortran_env, only : int8, int32, int64, output_unit, real64
use figure, only : app_object, code_diff, code_diff_lines, code_editor_object, code_language, FIG_ERR_ARGUMENT, &
                   FIG_ERR_STATE, FIG_OK, fig_read_image, ig_begin, ig_end, ig_set_next_window, language_object
use figure_testing, only : test_capture, test_compare_image, test_glyph, test_key, test_type

implicit none
character(len=*), parameter :: GOLDEN = 'src/tests/data/figure_test_editor.golden.png' !< The committed reference.
character(len=*), parameter :: SHOT = 'figure_test_editor.shot.png.tmp'    !< The window.
character(len=*), parameter :: BOXES = 'figure_test_editor.boxes.png.tmp'  !< The window, symbols no font has.
character(len=*), parameter :: LF = achar(10)                              !< Line feed.
character(len=*), parameter :: CR = achar(13)                              !< Carriage return.
character(len=*), parameter :: RHO = char(207)//char(129)                  !< U+03C1, from Noto Sans Math.
character(len=*), parameter :: INF = char(226)//char(136)//char(158)       !< U+221E, from Noto Sans Math.
character(len=*), parameter :: THAI = char(224)//char(184)//char(129)      !< U+0E01, in no bundled font.
integer(int32),   parameter :: W = 640_int32                               !< Display width [pixels].
integer(int32),   parameter :: H = 320_int32                               !< Display height [pixels].
type(app_object)            :: app             !< Application.
type(code_editor_object)    :: ed              !< The editor.
logical                     :: test_passed(14) !< Per-check outcome.
logical                     :: changed         !< `draw` reported a change, over some frames.
integer(int32)              :: early           !< code_diff's status before the first frame.
logical                     :: early_draw      !< ed%draw's result before the first frame.
integer(int32)              :: early_stat      !< ... its status.
character(len=8)            :: keep            !< FIGURE_TEST_KEEP.

test_passed = .false.
call app%init_headless(W, H)
call ed%init(code_language('input'))
call ed%set_text(input_file(RHO, INF))
call code_diff('early', 'a', 'b', stat=early)            ! no frame open yet: refused
early_draw = ed%draw('early', stat=early_stat)
if (early_draw .or. early_stat /= FIG_ERR_STATE) early = FIG_OK
call text_back(test_passed(1))
call marks(test_passed(2))
call pictures(test_passed(3:5))
call typing(test_passed(6:7))
call marks_after_edit(test_passed(8))
call finding(test_passed(9))
call completion(test_passed(10))
call read_only(test_passed(11))
call diff(test_passed(12))
call statuses(test_passed(13))
call languages(test_passed(14))
call ed%destroy()
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files() ! FIGURE_TEST_KEEP=1 keeps the pictures, to look at them

write(output_unit, '(A,*(L2))') 'figure_test_editor checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   pure function input_file(a, b) result(t)
   !< The input file the editor shows, with `a` and `b` as the symbols of lines 5 and 6, CR LF on line 1.
   character(len=*), intent(in)  :: a, b !< Symbols.
   character(len=:), allocatable :: t    !< Text.

   t = '[fluid-properties]'//CR//LF// &
       ' reynolds number = -15'//LF// &
       ' mach number = 0.3 ! subsonic'//LF// &
       ' prandtl number = 0.71'//LF// &
       ' '//a//' = 1.225'//LF// &
       ' '//b//' = 0'//LF// &
       ''//LF// &
       '[output-parameters]'//LF// &
       ' save frequency = 100'
   endfunction input_file

   subroutine ui()
   !< One frame of the window: the editor filling it.
   call ig_set_next_window(10.0_real64, 10.0_real64, 620.0_real64, 300.0_real64, always=.true.)
   if (ig_begin('Input file')) then
      if (ed%draw('editor')) changed = .true.
   endif
   call ig_end()
   endsubroutine ui

   subroutine frames(n)
   !< `n` frames of the window.
   integer(int32), intent(in) :: n !< Frames.
   integer(int32)             :: k !< Frame.

   do k = 1_int32, n
      if (.not. app%next_frame()) error stop 'figure_test_editor: next_frame returned false in headless mode'
      call ui()
   enddo
   endsubroutine frames

   function line(n) result(t)
   !< Line `n` of the editor's text ('' past the last).
   integer(int32), intent(in)    :: n    !< Line, from 1.
   character(len=:), allocatable :: t    !< Its text.
   character(len=:), allocatable :: all  !< The whole text.
   integer(int32)                :: k, a, i !< Counters.

   all = ed%text()//LF
   t = ''
   k = 1_int32
   a = 1_int32
   do i = 1_int32, len(all, int32)
      if (all(i:i) /= LF) cycle
      if (k == n) then
         t = all(a:i - 1_int32)
         return
      endif
      k = k + 1_int32
      a = i + 1_int32
   enddo
   endfunction line

   subroutine text_back(ok)
   !< The text read back (CR LF read as LF, every line ended by LF), nine lines.
   logical, intent(out)          :: ok   !< Outcome.
   character(len=:), allocatable :: full !< The text set.

   full = input_file(RHO, INF)
   ok = ed%text() == '[fluid-properties]'//LF//full(21:)//LF .and. ed%line_count() == 9_int32 .and. &
        line(9) == ' save frequency = 100'
   if (.not. ok) write(output_unit, '(A)') 'text: '//ed%text()
   endsubroutine text_back

   subroutine marks(ok)
   !< Three severities on three lines, a second mark on line 3 joined (the gravest kept), messages as tooltips show them.
   logical, intent(out)          :: ok  !< Outcome.
   character(len=:), allocatable :: msg !< A mark's message.
   character(len=:), allocatable :: sev !< Its severity.

   call ed%mark(2_int32, 'error', 'reynolds number must be positive')
   call ed%mark(3_int32, 'warning', 'mach number below 0.5: incompressible?')
   call ed%mark(4_int32, 'info', 'prandtl number of air')
   call ed%mark(3_int32, 'error', 'mach number: no compressible solver')
   sev = ed%mark_of(2_int32, msg)
   ok = sev == 'error' .and. msg == 'error: reynolds number must be positive'
   sev = ed%mark_of(3_int32, msg)
   ok = ok .and. sev == 'error' .and. &
        msg == 'warning: mach number below 0.5: incompressible?'//LF//'error: mach number: no compressible solver'
   ok = ok .and. ed%mark_of(4_int32) == 'info' .and. ed%mark_of(1_int32) == '' .and. ed%mark_of(99_int32) == ''
   endsubroutine marks

   subroutine pictures(ok)
   !< The window against the golden; line 2 (marked) tinted where line 1 is not; the fallback's rho and infinity
   !< drawn, not boxes: their lines differ from the same lines with a symbol no font has.
   logical, intent(out)       :: ok(3)        !< Outcomes: golden; tint; fallback glyphs.
   integer(int8), allocatable :: a(:,:,:)     !< The window.
   integer(int8), allocatable :: b(:,:,:)     !< The window with boxes.
   real(real64)               :: r(4, 9)      !< Rectangles of the lines.
   logical                    :: seen(9)      !< Lines in view.
   integer(int32)             :: k, x, y      !< Counters, a pixel.
   character(len=:), allocatable :: source    !< The font of a glyph.
   integer(int64)             :: pixels       !< Its pixels.

   call frames(4_int32)
   do k = 1_int32, 9_int32
      seen(k) = ed%line_rect(k, r(1, k), r(2, k), r(3, k), r(4, k))
   enddo
   call test_capture(SHOT)
   call frames(2_int32)
   ok(1) = all(seen) .and. test_compare_image(SHOT, GOLDEN)
   call fig_read_image(SHOT, a)
   ! a pixel past the text of lines 1 and 2: the background on line 1, the error's tint on line 2
   x = nint(r(3, 1)) - 30_int32
   ok(2) = allocated(a)
   if (ok(2)) then
      y = nint(0.5_real64 * (r(2, 1) + r(4, 1)))
      k = nint(0.5_real64 * (r(2, 2) + r(4, 2)))
      ok(2) = red_minus_blue(a, x, k) > red_minus_blue(a, x, y) + 20_int32
   endif
   ! the same window with a symbol in no font for rho and infinity: their lines differ
   call test_glyph(THAI, 'plex-mono', source, pixels) ! (in a frame: one is open)
   call ed%set_text(input_file(THAI, THAI))
   call frames(3_int32)
   call test_capture(BOXES)
   call frames(2_int32)
   call fig_read_image(BOXES, b)
   ok(3) = len(source) == 0 .and. allocated(a) .and. allocated(b)
   if (ok(3)) ok(3) = differ(a, b, r(:, 5)) .and. differ(a, b, r(:, 6)) .and. .not. differ(a, b, r(:, 9))
   call ed%set_text(input_file(RHO, INF))
   call ed%mark(2_int32, 'error', 'reynolds number must be positive')
   call ed%mark(3_int32, 'warning', 'mach number below 0.5: incompressible?')
   call ed%mark(4_int32, 'info', 'prandtl number of air')
   endsubroutine pictures

   pure function red_minus_blue(p, x, y) result(d)
   !< Red minus blue of pixel (x, y) of a picture (from 0).
   integer(int8),  intent(in) :: p(:,:,:) !< Picture.
   integer(int32), intent(in) :: x, y     !< Pixel.
   integer(int32)             :: d        !< Difference.

   d = iand(int(p(1, x + 1, y + 1), int32), 255_int32) - iand(int(p(3, x + 1, y + 1), int32), 255_int32)
   endfunction red_minus_blue

   pure function differ(a, b, r) result(yes)
   !< Two pictures differ inside the rectangle r [pixels].
   integer(int8), intent(in) :: a(:,:,:), b(:,:,:) !< Pictures.
   real(real64),  intent(in) :: r(4)               !< xmin, ymin, xmax, ymax.
   logical                   :: yes                !< They differ there.
   integer(int32)            :: x0, y0, x1, y1     !< Pixels.

   x0 = max(1_int32, nint(r(1)) + 1_int32)
   y0 = max(1_int32, nint(r(2)) + 1_int32)
   x1 = min(size(a, 2, int32), nint(r(3)))
   y1 = min(size(a, 3, int32), nint(r(4)))
   yes = any(a(:, x0:x1, y0:y1) /= b(:, x0:x1, y0:y1))
   endfunction differ

   subroutine typing(ok)
   !< Typing at the start of line 2's key changes the text and `draw` says so; ctrl+z undoes it; redo, undo again.
   logical, intent(out) :: ok(2)   !< Outcomes: typed; undone.
   logical              :: redone  !< `redo` redid it.
   logical              :: undone  !< `undo` undid it.

   call ed%goto(2_int32, 2_int32, focus=.true.)
   call frames(3_int32)
   changed = .false.
   call test_type('x')
   call frames(3_int32)
   ok(1) = changed .and. line(2) == ' xreynolds number = -15'
   if (.not. ok(1)) write(output_unit, '(A)') 'typed: '//line(2)
   call test_key('shortcut', down=.true.)
   call test_key('z')
   call test_key('shortcut', down=.false.)
   call frames(4_int32)
   ok(2) = line(2) == ' reynolds number = -15'
   redone = ed%redo()
   ok(2) = ok(2) .and. redone .and. line(2) == ' xreynolds number = -15'
   undone = ed%undo()
   ok(2) = ok(2) .and. undone .and. line(2) == ' reynolds number = -15'
   endsubroutine typing

   subroutine marks_after_edit(ok)
   !< A character deleted on an unmarked line (the fork then renumbers its markers): the three marks stay on their
   !< lines; one deleted on a marked line: its mark goes.
   logical, intent(out) :: ok !< Outcome.

   call ed%clear_marks()
   call ed%mark(2_int32, 'error', 'reynolds number must be positive')
   call ed%mark(3_int32, 'warning', 'mach number below 0.5: incompressible?')
   call ed%mark(4_int32, 'info', 'prandtl number of air')
   call ed%goto(9_int32, 22_int32, focus=.true.)
   call frames(3_int32)
   call test_key('backspace')
   call frames(3_int32)
   ok = line(9) == ' save frequency = 10' .and. ed%mark_of(2_int32) == 'error' .and. &
        ed%mark_of(3_int32) == 'warning' .and. ed%mark_of(4_int32) == 'info'
   if (.not. ok) write(output_unit, '(A)') 'after the edit: '//line(9)//' '//ed%mark_of(2_int32)//' '// &
                                           ed%mark_of(3_int32)//' '//ed%mark_of(4_int32)
   call ed%goto(3_int32, 30_int32, focus=.true.)
   call frames(3_int32)
   call test_key('backspace')
   call frames(3_int32)
   ok = ok .and. line(3) == ' mach number = 0.3 ! subsoni' .and. ed%mark_of(3_int32) == '' .and. &
        ed%mark_of(2_int32) == 'error' .and. ed%mark_of(4_int32) == 'info'
   call test_type('c')
   call frames(3_int32)
   endsubroutine marks_after_edit

   subroutine finding(ok)
   !< find: the next occurrence selected, then the one after, by case or not, wrapping to the start, none; replace:
   !< both occurrences in one undo.
   logical, intent(out)          :: ok        !< Outcome.
   character(len=:), allocatable :: sel       !< The selected text.
   integer(int32)                :: l0, c0, l1, c1 !< The selection.
   logical                       :: undone    !< `undo` undid it.
   logical                       :: found     !< find's result.
   logical                       :: has       !< selection's result.
   integer(int32)                :: n         !< Occurrences replaced.

   call ed%goto(1_int32)
   ok = ed%find('number')
   has = ed%selection(l0, c0, l1, c1, sel)
   ok = ok .and. has .and. sel == 'number' .and. all([l0, c0, l1, c1] == [2_int32, 11_int32, 2_int32, 17_int32])
   found = ed%find('number')
   has = ed%selection(l0, c0, l1, c1)
   ok = ok .and. found .and. has .and. l0 == 3_int32
   found = ed%find('NUMBER', case_sensitive=.false.)
   has = ed%selection(l0, c0, l1, c1)
   ok = ok .and. found .and. has .and. l0 == 4_int32
   found = ed%find('NUMBER')
   ok = ok .and. .not. found
   found = ed%find('reynolds')
   has = ed%selection(l0, c0, l1, c1)
   ok = ok .and. found .and. has .and. l0 == 2_int32 ! wrapped to the start
   found = ed%find('viscosity')
   ok = ok .and. .not. found
   n = ed%replace('number', 'value')
   ok = ok .and. n == 3_int32 .and. line(2) == ' reynolds value = -15' .and. line(4) == ' prandtl value = 0.71'
   undone = ed%undo()
   ok = ok .and. undone .and. line(2) == ' reynolds number = -15' .and. line(4) == ' prandtl number = 0.71'
   endsubroutine finding

   subroutine completion(ok)
   !< On the empty line 7, typing "rey" opens the popup with the only key that starts with it; tab inserts it; the
   !< word at the cursor is its last word. On a new line, "mach n" (a term of two words) offers "mach number" alone.
   logical, intent(out)          :: ok       !< Outcome.
   character(len=:), allocatable :: words(:) !< Words offered.
   logical                       :: open     !< The popup is open.

   call ed%set_completions(['reynolds number ', 'mach number     ', 'save frequency  ', 'prandtl number  '])
   ok = .not. ed%completing()
   call ed%goto(7_int32, 1_int32, focus=.true.)
   call frames(3_int32)
   call test_type(' rey')
   call frames(4_int32)
   open = ed%completing(words)
   ok = ok .and. open
   if (ok) ok = size(words) == 1 .and. words(1) == 'reynolds number'
   if (.not. ok .and. open) write(output_unit, '(A,I0,A)') 'offered: ', size(words), ' '//words(1)
   call test_key('tab')
   call frames(4_int32)
   ok = ok .and. line(7) == ' reynolds number' .and. .not. ed%completing() .and. ed%word_at_cursor() == 'number'
   if (.not. ok) write(output_unit, '(A)') 'completed: "'//line(7)//'" '//ed%word_at_cursor()
   ! a key of several words: "mach n" (a blank inside the term) offers "mach number" alone
   call test_type(' = 1e5')
   call frames(2_int32)
   call test_key('enter')
   call frames(3_int32)
   call test_type('mach n')                    ! after the line's indentation, kept by enter
   call frames(4_int32)
   open = ed%completing(words)
   ok = ok .and. open
   if (open) ok = ok .and. size(words) == 1 .and. words(1) == 'mach number'
   call test_key('tab')
   call frames(4_int32)
   ok = ok .and. line(8) == ' mach number'
   if (.not. ok) write(output_unit, '(A)') 'completed: "'//line(8)//'"'
   call ed%set_completions([character(len=1) :: ])
   endsubroutine completion

   subroutine read_only(ok)
   !< A read-only editor: insert refused, typing ignored; editable again: insert at the cursor.
   logical, intent(out)          :: ok   !< Outcome.
   character(len=:), allocatable :: before !< The text before.
   integer(int32)                :: s    !< Status.

   before = ed%text()
   call ed%read_only(.true.)
   call ed%insert('q', stat=s)
   ok = s == FIG_ERR_STATE .and. ed%is_read_only()
   call ed%focus()
   call frames(2_int32)
   call test_type('q')
   call frames(3_int32)
   ok = ok .and. ed%text() == before
   call ed%read_only(.false.)
   call ed%goto(1_int32, 1_int32)
   call ed%insert('# input'//LF)
   ok = ok .and. .not. ed%is_read_only() .and. line(1) == '# input' .and. line(2) == '[fluid-properties]'
   endsubroutine read_only

   subroutine diff(ok)
   !< The changed lines of two texts (a line changed, one added at the end, CR LF as LF); the diff drawn in both
   !< layouts; refused with no frame open.
   logical, intent(out)        :: ok          !< Outcome.
   integer(int32), allocatable :: added(:)    !< Lines added.
   integer(int32), allocatable :: removed(:)  !< Lines removed.
   integer(int32)              :: s1, s2      !< Statuses.
   type(language_object)       :: lang        !< The input language.

   call code_diff_lines('a'//LF//'b'//LF//'c', 'a'//CR//LF//'B'//LF//'c'//LF//'d', added, removed)
   ok = size(added) == 2 .and. size(removed) == 1
   if (ok) ok = all(added == [2_int32, 4_int32]) .and. removed(1) == 2_int32
   call code_diff_lines('same', 'same', added, removed)
   ok = ok .and. size(added) == 0 .and. size(removed) == 0
   lang = code_language('input')
   if (.not. app%next_frame()) error stop 'figure_test_editor: next_frame returned false in headless mode'
   call ig_set_next_window(10.0_real64, 10.0_real64, 620.0_real64, 300.0_real64, always=.true.)
   if (ig_begin('Diff')) then
      call code_diff('one', ' a = 1'//LF//' b = 2', ' a = 1'//LF//' b = 3', language=lang, height=120.0_real64, stat=s1)
      call code_diff('two', ' a = 1'//LF//' b = 2', ' a = 1'//LF//' b = 3', side_by_side=.true., stat=s2)
   endif
   call ig_end()
   call frames(1_int32)
   ok = ok .and. s1 == FIG_OK .and. s2 == FIG_OK
   ok = ok .and. early == FIG_ERR_STATE
   endsubroutine diff

   subroutine statuses(ok)
   !< The failures: a line out of range, an unknown severity, an editor not initialized, an unknown language, a keyword
   !< with a blank, a tab size out of range.
   logical, intent(out)     :: ok     !< Outcome.
   type(code_editor_object) :: none   !< Not initialized.
   type(language_object)    :: lang   !< A language.
   integer(int32)           :: s(7)   !< Statuses.
   logical                  :: found  !< find's result.

   call ed%mark(99_int32, 'error', 'past the end', stat=s(1))
   call ed%mark(1_int32, 'fatal', 'unknown severity', stat=s(2))
   call none%set_text('x', stat=s(3))
   lang = code_language('cobol', stat=s(4))
   call lang%init('mine', keywords=['two words'], stat=s(5))
   call ed%set_options(tab_size=0_int32, stat=s(6))
   found = ed%find('', stat=s(7))
   ok = all(s == [FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, &
                  FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT]) .and. .not. found .and. none%text() == '' .and. &
        none%line_count() == 0_int32 .and. .not. none%is_initialized()
   if (.not. ok) write(output_unit, '(A,7I3)') 'statuses: ', s
   endsubroutine statuses

   subroutine languages(ok)
   !< The shipped languages by name, in any case; one of the fork's; a language of the program's own.
   logical, intent(out)     :: ok   !< Outcome.
   type(code_editor_object) :: py   !< An editor of Python.
   type(language_object)    :: lang !< A language.
   integer(int32)           :: s(3) !< Statuses.
   type(language_object)    :: f, i, t !< Shipped languages.

   f = code_language('FORTRAN')
   i = code_language('input')
   t = code_language('text')
   ok = f%name() == 'Fortran' .and. i%name() == 'Input' .and. t%name() == ''
   call py%init(code_language('Python'), stat=s(1))
   call lang%init('solver log', keywords=['converged', 'diverged '], comment='#', case_sensitive=.false., stat=s(2))
   call py%set_language(lang, stat=s(3))
   call py%set_text('# step 1'//LF//'converged')
   ok = ok .and. all(s == FIG_OK) .and. lang%name() == 'solver log' .and. py%line_count() == 2_int32
   call py%destroy()
   endsubroutine languages

   subroutine remove_files()
   !< Remove the pictures of the test.
   character(len=*), parameter :: FILES(2) = [character(len=64) :: SHOT, BOXES] !< Files.
   integer(int32)              :: k, u, ios !< Counter, unit, status.

   do k = 1_int32, size(FILES, kind=int32)
      open(newunit=u, file=trim(FILES(k)), status='old', iostat=ios)
      if (ios == 0_int32) close(u, status='delete')
   enddo
   endsubroutine remove_files
endprogram figure_test_editor
