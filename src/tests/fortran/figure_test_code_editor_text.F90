!< figure_test_code_editor_text, the Fortran code editor's text, cursors, marks, find, replace and undo, as the C++'s.
program figure_test_code_editor_text
!< figure_test_code_editor_text, the Fortran code editor's text, cursors, marks, find, replace and undo, as the C++'s.
!<
!< szaghi/figure#15 P16, step 10. Two editors driven by the same calls of FIGURE's public API: `code_editor_object` of
!< `figure_editor` (ImGuiColorTextEdit and the native glue) and of `figure_editor_fortran` (the same module over the
!< Fortran editor, written by scripts/gen_editor_path.py). After every call, compared: the status and, on a failure,
!< the last error's message; the text; the line count; the cursor; the selection (its four positions, whether it is
!< one, its text); the word at the cursor; every line's mark (severity, message); whether completion is open. Nothing
!< is drawn (step 10: the text model), so the marks' list is never compressed and `draw` is not called. The cases:
!<
!< 1. the scripted calls of figure_test_editor without its frames: an input file with CR LF and the fallback font's
!<    symbols, marks of three severities and a second one joined, find by case or not and wrapping, replace in one
!<    undo, undo and redo, insert (replacing a selection, several lines, tabs), read-only refusals, the statuses;
!< 2. 1500 random calls (a fixed seed): goto, select, insert, find, replace, undo, redo, mark, clear_marks, set_text,
!<    read-only, tab size; texts of ASCII words, blanks, tabs, LF, CR LF, two- and three-byte UTF-8 (a wide glyph
!<    among them), and bytes cut out of the text (a UTF-8 sequence cut short);
!< 3. `code_diff_lines` of 400 random pairs of texts (a text and its edit), the lines added and removed equal.
use, intrinsic :: iso_fortran_env, only : int32, int64, output_unit, real64
use figure, only : app_object, code_diff_lines, code_editor_object, code_language, figure_last_error, language_object
use figure_editor_fortran, only : f_code_diff_lines => code_diff_lines, f_code_editor_object => code_editor_object, &
                                  f_code_language => code_language, f_language_object => language_object

implicit none
character(len=*), parameter :: LF = achar(10)                             !< Line feed.
character(len=*), parameter :: CR = achar(13)                             !< Carriage return.
character(len=*), parameter :: TAB = achar(9)                             !< Tab.
character(len=*), parameter :: RHO = char(207)//char(129)                 !< U+03C1.
character(len=*), parameter :: INF = char(226)//char(136)//char(158)      !< U+221E.
character(len=*), parameter :: HAN = char(228)//char(184)//char(173)      !< U+4E2D, two columns wide.
character(len=*), parameter :: EACUTE = char(195)//char(169)              !< U+00E9.
character(len=*), parameter :: UPPER_E = char(195)//char(137)             !< U+00C9.
integer(int32),   parameter :: NWORD = 20_int32                           !< Pieces of a random text.
character(len=8), parameter :: WORDS(NWORD) = [character(len=8) :: 'number', 'NUMBER', 'mach', 'a', 'b', ' ', '  ', &
                                               '=', '(', ')', '[x]', 'x_1', '!', '#', '1.5e3', '{', '}', '"s"', 'ab', &
                                               '.'] !< ASCII pieces.
type(app_object)           :: app             !< Application.
type(code_editor_object)   :: c               !< The C++ editor.
type(f_code_editor_object) :: f               !< The Fortran editor.
logical                    :: test_passed(3)  !< Per-case outcome.
integer(int64)             :: seed            !< The random generator's state.
integer(int32)             :: mismatches      !< Calls whose results differ.
character(len=64)          :: where           !< The call being checked.

test_passed = .false.
mismatches = 0_int32
seed = 20261124_int64
call app%init_headless(320_int32, 200_int32)
call c%init(code_language('input'))
call f%init(f_code_language('input'))
call scripted(test_passed(1))
call random_calls(test_passed(2))
call diffs(test_passed(3))
call c%destroy()
call f%destroy()
call app%destroy()

write(output_unit, '(A,*(L2))') 'figure_test_code_editor_text checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   function random(n) result(k)
   !< A pseudo-random integer in [1, n] (a 64-bit LCG, the same on every compiler).
   integer(int32), intent(in) :: n !< Range.
   integer(int32)             :: k !< Value.

   seed = seed * 6364136223846793005_int64 + 1442695040888963407_int64
   k = int(modulo(ishft(seed, -33), int(n, int64)), int32) + 1_int32
   endfunction random

   function random_text(pieces) result(t)
   !< A random text of `pieces` pieces.
   integer(int32), intent(in)    :: pieces !< Pieces.
   character(len=:), allocatable :: t      !< Text.
   integer(int32)                :: k      !< Counter.

   t = ''
   do k = 1_int32, pieces
      select case (random(14_int32))
      case (1_int32)
         t = t//LF
      case (2_int32)
         t = t//CR//LF
      case (3_int32)
         t = t//TAB
      case (4_int32)
         t = t//RHO
      case (5_int32)
         t = t//HAN
      case (6_int32)
         t = t//EACUTE//UPPER_E
      case (7_int32)
         t = t//INF
      case default
         t = t//trim(WORDS(random(NWORD)))
      endselect
   enddo
   endfunction random_text

   subroutine check(sc, sf)
   !< Compare the two editors after a call with statuses `sc` and `sf`.
   integer(int32), intent(in)    :: sc, sf     !< Statuses.
   character(len=:), allocatable :: tc, tf     !< Texts.
   character(len=:), allocatable :: mc, mf     !< Marks' messages.
   integer(int32)                :: pc(4), pf(4), lc, cc, lf_, cf, k !< Positions.
   logical                       :: hc, hf, ok !< Selections, outcome.

   ok = sc == sf
   ok = ok .and. c%text() == f%text() .and. len(c%text()) == len(f%text())
   ok = ok .and. c%line_count() == f%line_count()
   call c%cursor(lc, cc)
   call f%cursor(lf_, cf)
   ok = ok .and. lc == lf_ .and. cc == cf
   hc = c%selection(pc(1), pc(2), pc(3), pc(4), tc)
   hf = f%selection(pf(1), pf(2), pf(3), pf(4), tf)
   ok = ok .and. (hc .eqv. hf) .and. all(pc == pf) .and. tc == tf .and. len(tc) == len(tf)
   ok = ok .and. c%word_at_cursor() == f%word_at_cursor() .and. len(c%word_at_cursor()) == len(f%word_at_cursor())
   ok = ok .and. (c%completing() .eqv. f%completing()) .and. (c%is_read_only() .eqv. f%is_read_only())
   do k = 0_int32, c%line_count() + 1_int32
      ok = ok .and. c%mark_of(k, mc) == f%mark_of(k, mf)
      ok = ok .and. mc == mf .and. len(mc) == len(mf)
   enddo
   if (.not. ok) then
      mismatches = mismatches + 1_int32
      if (mismatches <= 5_int32) then
         write(output_unit, '(A,2I3)') 'mismatch after '//trim(where)//', statuses ', sc, sf
         write(output_unit, '(A,4I4,L2,A,2I4)') '  C++    : selection ', pc, hc, ' cursor ', lc, cc
         write(output_unit, '(A,4I4,L2,A,2I4)') '  Fortran: selection ', pf, hf, ' cursor ', lf_, cf
         write(output_unit, '(A)') '  C++ text    : "'//c%text()//'"'
         write(output_unit, '(A)') '  Fortran text: "'//f%text()//'"'
      endif
   endif
   endsubroutine check

   subroutine scripted(ok)
   !< Case 1: figure_test_editor's calls, without frames.
   logical, intent(out)          :: ok        !< Outcome.
   integer(int32)                :: sc, sf    !< Statuses.
   character(len=:), allocatable :: ec        !< The C++'s message.
   logical                       :: bc, bf    !< Results.
   integer(int32)                :: nc, nf    !< Counts.
   type(language_object)         :: lc        !< A language (C++ side).
   type(f_language_object)       :: lf_       !< ... Fortran side.
   type(code_editor_object)      :: none_c    !< Not initialized.
   type(f_code_editor_object)    :: none_f    !< ... Fortran side.

   mismatches = 0_int32
   where = 'set_text'
   call c%set_text(input_file(RHO, INF), stat=sc)
   call f%set_text(input_file(RHO, INF), stat=sf)
   call check(sc, sf)
   where = 'marks'
   call c%mark(2_int32, 'error', 'reynolds number must be positive', stat=sc)
   call f%mark(2_int32, 'error', 'reynolds number must be positive', stat=sf)
   call check(sc, sf)
   call c%mark(3_int32, 'warning', 'mach number below 0.5: incompressible?', stat=sc)
   call f%mark(3_int32, 'warning', 'mach number below 0.5: incompressible?', stat=sf)
   call check(sc, sf)
   call c%mark(4_int32, 'info', 'prandtl number of air', stat=sc)
   call f%mark(4_int32, 'info', 'prandtl number of air', stat=sf)
   call check(sc, sf)
   call c%mark(3_int32, 'error', 'mach number: no compressible solver', stat=sc)
   call f%mark(3_int32, 'error', 'mach number: no compressible solver', stat=sf)
   call check(sc, sf)
   where = 'mark past the end'
   call c%mark(99_int32, 'error', 'past the end', stat=sc)
   ec = figure_last_error()
   call f%mark(99_int32, 'error', 'past the end', stat=sf)
   call check(sc, sf)
   if (ec /= figure_last_error()) mismatches = mismatches + 1_int32
   where = 'mark unknown severity'
   call c%mark(1_int32, 'fatal', 'x', stat=sc)
   ec = figure_last_error()
   call f%mark(1_int32, 'fatal', 'x', stat=sf)
   call check(sc, sf)
   if (ec /= figure_last_error()) mismatches = mismatches + 1_int32
   where = 'goto, insert'
   call c%goto(2_int32, 2_int32, focus=.true., stat=sc)
   call f%goto(2_int32, 2_int32, focus=.true., stat=sf)
   call check(sc, sf)
   call c%insert('x', stat=sc)
   call f%insert('x', stat=sf)
   call check(sc, sf)
   bc = c%undo()
   bf = f%undo()
   call check(merge(1_int32, 0_int32, bc), merge(1_int32, 0_int32, bf))
   bc = c%redo()
   bf = f%redo()
   call check(merge(1_int32, 0_int32, bc), merge(1_int32, 0_int32, bf))
   bc = c%undo()
   bf = f%undo()
   call check(merge(1_int32, 0_int32, bc), merge(1_int32, 0_int32, bf))
   bc = c%undo()
   bf = f%undo()
   call check(merge(1_int32, 0_int32, bc), merge(1_int32, 0_int32, bf))
   where = 'find'
   call c%goto(1_int32)
   call f%goto(1_int32)
   bc = c%find('number')
   bf = f%find('number')
   call check(merge(1_int32, 0_int32, bc), merge(1_int32, 0_int32, bf))
   bc = c%find('number')
   bf = f%find('number')
   call check(merge(1_int32, 0_int32, bc), merge(1_int32, 0_int32, bf))
   bc = c%find('NUMBER', case_sensitive=.false.)
   bf = f%find('NUMBER', case_sensitive=.false.)
   call check(merge(1_int32, 0_int32, bc), merge(1_int32, 0_int32, bf))
   bc = c%find('NUMBER')
   bf = f%find('NUMBER')
   call check(merge(1_int32, 0_int32, bc), merge(1_int32, 0_int32, bf))
   bc = c%find('reynolds')
   bf = f%find('reynolds')
   call check(merge(1_int32, 0_int32, bc), merge(1_int32, 0_int32, bf))
   bc = c%find('number', whole_word=.true.)
   bf = f%find('number', whole_word=.true.)
   call check(merge(1_int32, 0_int32, bc), merge(1_int32, 0_int32, bf))
   bc = c%find(EACUTE, case_sensitive=.false.)
   bf = f%find(EACUTE, case_sensitive=.false.)
   call check(merge(1_int32, 0_int32, bc), merge(1_int32, 0_int32, bf))
   bc = c%find('viscosity')
   bf = f%find('viscosity')
   call check(merge(1_int32, 0_int32, bc), merge(1_int32, 0_int32, bf))
   bc = c%find('', stat=sc)
   ec = figure_last_error()
   bf = f%find('', stat=sf)
   call check(sc, sf)
   if (ec /= figure_last_error()) mismatches = mismatches + 1_int32
   where = 'replace'
   nc = c%replace('number', 'value')
   nf = f%replace('number', 'value')
   call check(nc, nf)
   bc = c%undo()
   bf = f%undo()
   call check(merge(1_int32, 0_int32, bc), merge(1_int32, 0_int32, bf))
   nc = c%replace('NUMBER', 'Zahl', case_sensitive=.false., whole_word=.true.)
   nf = f%replace('NUMBER', 'Zahl', case_sensitive=.false., whole_word=.true.)
   call check(nc, nf)
   nc = c%replace('absent', 'x')
   nf = f%replace('absent', 'x')
   call check(nc, nf)
   bc = c%redo()
   bf = f%redo()
   call check(merge(1_int32, 0_int32, bc), merge(1_int32, 0_int32, bf))
   where = 'select, insert'
   call c%select(2_int32, 2_int32, 3_int32, 5_int32)
   call f%select(2_int32, 2_int32, 3_int32, 5_int32)
   call check(0_int32, 0_int32)
   call c%insert('one'//LF//TAB//'two'//CR//LF//'three '//HAN)
   call f%insert('one'//LF//TAB//'two'//CR//LF//'three '//HAN)
   call check(0_int32, 0_int32)
   call c%select(9_int32, 40_int32, 1_int32, 3_int32)
   call f%select(9_int32, 40_int32, 1_int32, 3_int32)
   call check(0_int32, 0_int32)
   call c%select(0_int32, 1_int32, 1_int32, 1_int32, stat=sc)
   ec = figure_last_error()
   call f%select(0_int32, 1_int32, 1_int32, 1_int32, stat=sf)
   call check(sc, sf)
   if (ec /= figure_last_error()) mismatches = mismatches + 1_int32
   call c%insert('')
   call f%insert('')
   call check(0_int32, 0_int32)
   where = 'read only'
   call c%read_only(.true.)
   call f%read_only(.true.)
   call c%insert('q', stat=sc)
   ec = figure_last_error()
   call f%insert('q', stat=sf)
   call check(sc, sf)
   if (ec /= figure_last_error()) mismatches = mismatches + 1_int32
   nc = c%replace('one', 'x', stat=sc)
   ec = figure_last_error()
   nf = f%replace('one', 'x', stat=sf)
   call check(sc, sf)
   if (ec /= figure_last_error()) mismatches = mismatches + 1_int32
   bc = c%undo()
   bf = f%undo()
   call check(merge(1_int32, 0_int32, bc), merge(1_int32, 0_int32, bf))
   call c%read_only(.false.)
   call f%read_only(.false.)
   call check(0_int32, 0_int32)
   where = 'options, completions, languages'
   call c%set_options(tab_size=0_int32, stat=sc)
   ec = figure_last_error()
   call f%set_options(tab_size=0_int32, stat=sf)
   call check(sc, sf)
   if (ec /= figure_last_error()) mismatches = mismatches + 1_int32
   call c%set_options(tab_size=8_int32, line_numbers=.false., whitespace=.true., line_highlight=.false., stat=sc)
   call f%set_options(tab_size=8_int32, line_numbers=.false., whitespace=.true., line_highlight=.false., stat=sf)
   call check(sc, sf)
   call c%set_completions(['reynolds number ', 'mach number     '], stat=sc)
   call f%set_completions(['reynolds number ', 'mach number     '], stat=sf)
   call check(sc, sf)
   call c%set_language(code_language('fortran'), stat=sc)
   call f%set_language(f_code_language('fortran'), stat=sf)
   call check(sc, sf)
   call c%set_language(code_language('python'), stat=sc)
   call f%set_language(f_code_language('python'), stat=sf)
   call check(sc, sf)
   call lc%init('solver log', keywords=['converged', 'diverged '], comment='#', case_sensitive=.false.)
   call lf_%init('solver log', keywords=['converged', 'diverged '], comment='#', case_sensitive=.false.)
   call c%set_language(lc, stat=sc)
   call f%set_language(lf_, stat=sf)
   call check(sc, sf)
   call c%set_language(code_language('input'), stat=sc)
   call f%set_language(f_code_language('input'), stat=sf)
   call check(sc, sf)
   call c%set_completions([character(len=1) :: ])
   call f%set_completions([character(len=1) :: ])
   call check(0_int32, 0_int32)
   where = 'not initialized'
   call none_c%set_text('x', stat=sc)
   ec = figure_last_error()
   call none_f%set_text('x', stat=sf)
   call check(sc, sf)
   if (ec /= figure_last_error()) mismatches = mismatches + 1_int32
   ok = mismatches == 0_int32 .and. none_c%text() == none_f%text() .and. none_c%line_count() == none_f%line_count()
   if (.not. ok) write(output_unit, '(A,I0)') 'scripted: mismatches ', mismatches
   endsubroutine scripted

   pure function input_file(a, b) result(t)
   !< figure_test_editor's input file, with `a` and `b` as the symbols of lines 5 and 6, CR LF on line 1.
   character(len=*), intent(in)  :: a, b !< Symbols.
   character(len=:), allocatable :: t    !< Text.

   t = '[fluid-properties]'//CR//LF//' reynolds number = -15'//LF//' mach number = 0.3 ! subsonic'//LF// &
       ' prandtl number = 0.71'//LF//' '//a//' = 1.225'//LF//' '//b//' = 0'//LF//''//LF// &
       '[output-parameters]'//LF//' save frequency = 100 '//EACUTE
   endfunction input_file

   subroutine random_calls(ok)
   !< Case 2: random calls, the editors compared after each.
   logical, intent(out)          :: ok          !< Outcome.
   integer(int32)                :: k, op, sc, sf, l0, c0, l1, c1, nl, a, b !< Counters, call, statuses, positions.
   character(len=:), allocatable :: t, w, ec    !< Texts, the C++'s message.
   logical                       :: bc, bf, cs, ww !< Results, flags.
   integer(int32)                :: seen(4)     !< Finds found, occurrences replaced, undos done, marks made.
   character(len=7), parameter   :: SEV(4) = [character(len=7) :: 'error', 'warning', 'info', 'bad'] !< Severities.

   mismatches = 0_int32
   seen = 0_int32
   t = random_text(40_int32)
   call c%set_text(t)
   call f%set_text(t)
   call check(0_int32, 0_int32)
   do k = 1_int32, 1500_int32
      nl = c%line_count()
      op = random(16_int32)
      write(where, '(A,I0,A,I0)') 'random call ', k, ', kind ', op
      sc = 0_int32
      sf = 0_int32
      select case (op)
      case (1_int32)
         l0 = random(nl + 2_int32)
         c0 = random(30_int32)
         call c%goto(l0, c0, stat=sc)
         call f%goto(l0, c0, stat=sf)
      case (2_int32, 3_int32)
         l0 = random(nl + 1_int32)
         c0 = random(25_int32)
         l1 = random(nl + 1_int32)
         c1 = random(25_int32)
         call c%select(l0, c0, l1, c1, stat=sc)
         call f%select(l0, c0, l1, c1, stat=sf)
      case (4_int32, 5_int32, 6_int32)
         t = random_text(random(6_int32))
         call c%insert(t, stat=sc)
         ec = figure_last_error()
         call f%insert(t, stat=sf)
         if (sc /= 0_int32 .and. ec /= figure_last_error()) mismatches = mismatches + 1_int32
      case (7_int32, 8_int32)
         t = c%text()
         if (len(t) > 0 .and. random(4_int32) > 1_int32) then
            a = random(len(t, int32))
            b = min(len(t, int32), a + random(8_int32) - 1_int32)
            w = t(a:b)
         else
            w = trim(WORDS(random(NWORD)))
         endif
         cs = random(2_int32) == 1_int32
         ww = random(3_int32) == 1_int32
         bc = c%find(w, case_sensitive=cs, whole_word=ww, stat=sc)
         bf = f%find(w, case_sensitive=cs, whole_word=ww, stat=sf)
         if (bc .neqv. bf) mismatches = mismatches + 1_int32
         if (bc) seen(1) = seen(1) + 1_int32
      case (9_int32)
         w = trim(WORDS(random(NWORD)))
         t = random_text(random(3_int32) - 1_int32)
         cs = random(2_int32) == 1_int32
         ww = random(3_int32) == 1_int32
         a = c%replace(w, t, case_sensitive=cs, whole_word=ww, stat=sc)
         ec = figure_last_error()
         b = f%replace(w, t, case_sensitive=cs, whole_word=ww, stat=sf)
         if (a /= b) mismatches = mismatches + 1_int32
         seen(2) = seen(2) + a
         if (sc /= 0_int32 .and. ec /= figure_last_error()) mismatches = mismatches + 1_int32
      case (10_int32, 11_int32)
         bc = c%undo()
         bf = f%undo()
         if (bc .neqv. bf) mismatches = mismatches + 1_int32
         if (bc) seen(3) = seen(3) + 1_int32
      case (12_int32)
         bc = c%redo()
         bf = f%redo()
         if (bc .neqv. bf) mismatches = mismatches + 1_int32
      case (13_int32)
         l0 = random(nl + 1_int32)
         a = random(4_int32)
         t = random_text(random(3_int32))
         call c%mark(l0, trim(SEV(a)), t, stat=sc)
         ec = figure_last_error()
         call f%mark(l0, trim(SEV(a)), t, stat=sf)
         if (sc /= 0_int32 .and. ec /= figure_last_error()) mismatches = mismatches + 1_int32
         if (sc == 0_int32) seen(4) = seen(4) + 1_int32
      case (14_int32)
         if (random(4_int32) == 1_int32) then
            call c%clear_marks()
            call f%clear_marks()
         else
            bc = random(5_int32) == 1_int32
            call c%read_only(bc)
            call f%read_only(bc)
         endif
      case (15_int32)
         if (random(10_int32) == 1_int32) then
            t = random_text(random(30_int32))
            call c%set_text(t)
            call f%set_text(t)
         else
            a = random(8_int32)
            call c%set_options(tab_size=a)
            call f%set_options(tab_size=a)
         endif
      case default
         ! a text cut out of the editor's, inserted at the start: bytes of a UTF-8 sequence may be lost
         t = c%text()
         if (len(t) > 2) then
            a = random(len(t, int32))
            b = min(len(t, int32), a + random(5_int32))
            call c%goto(1_int32, 1_int32)
            call f%goto(1_int32, 1_int32)
            call c%insert(t(a:b), stat=sc)
            call f%insert(t(a:b), stat=sf)
         endif
      endselect
      call check(sc, sf)
      if (mismatches > 5_int32) exit
   enddo
   ok = mismatches == 0_int32 .and. all(seen > 10_int32)
   write(output_unit, '(A,4(1X,I0),A,I0,A)') 'random calls: finds found, occurrences replaced, undos, marks:', seen, &
                                             ' (', c%line_count(), ' lines at the end)'
   if (.not. ok) write(output_unit, '(A,I0)') 'random calls: mismatches ', mismatches
   endsubroutine random_calls

   subroutine diffs(ok)
   !< Case 3: `code_diff_lines` of random pairs.
   logical, intent(out)          :: ok          !< Outcome.
   integer(int32), allocatable   :: ac(:), rc(:), af(:), rf(:) !< Lines added and removed.
   character(len=:), allocatable :: x, y        !< Texts.
   integer(int32)                :: k, j, bad   !< Counters, mismatches.
   integer(int32)                :: sc, sf      !< Statuses.

   bad = 0_int32
   do k = 1_int32, 400_int32
      x = random_lines(random(30_int32))
      y = ''
      do j = 1_int32, random(6_int32)
         call c%set_text(x)
         call c%goto(random(c%line_count()), random(6_int32))
         call c%insert(random_lines(random(3_int32) - 1_int32))
         if (random(2_int32) == 1_int32) then
            call c%select(random(c%line_count()), 1_int32, random(c%line_count()), 1_int32)
            call c%insert('')
         endif
         y = c%text()
      enddo
      if (random(5_int32) == 1_int32) y = random_lines(random(30_int32))
      call code_diff_lines(x, y, ac, rc, stat=sc)
      call f_code_diff_lines(x, y, af, rf, stat=sf)
      if (sc /= sf .or. size(ac) /= size(af) .or. size(rc) /= size(rf)) then
         bad = bad + 1_int32
      elseif (any(ac /= af) .or. any(rc /= rf)) then
         bad = bad + 1_int32
      endif
   enddo
   ok = bad == 0_int32
   if (.not. ok) write(output_unit, '(A,I0)') 'code_diff_lines: pairs differing ', bad
   endsubroutine diffs

   function random_lines(n) result(t)
   !< `n` random short lines (a small alphabet, so that lines repeat), LF or CR LF between them.
   integer(int32), intent(in)    :: n !< Lines.
   character(len=:), allocatable :: t !< Text.
   integer(int32)                :: k !< Counter.
   character(len=6), parameter   :: L(6) = [character(len=6) :: 'a', 'b = 1', 'c', '', '  x', 'end'] !< Lines.

   t = ''
   do k = 1_int32, n
      t = t//trim(L(random(6_int32)))
      if (k < n) then
         if (random(8_int32) == 1_int32) then
            t = t//CR//LF
         else
            t = t//LF
         endif
      endif
   enddo
   endfunction random_lines
endprogram figure_test_code_editor_text
