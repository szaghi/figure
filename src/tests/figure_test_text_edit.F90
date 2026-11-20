!< figure_test_text_edit, text editing by the keyboard: UTF-8, selection, the clipboard, undo, against a golden, headless.
program figure_test_text_edit
!< figure_test_text_edit, text editing by the keyboard: UTF-8, selection, the clipboard, undo, against a golden, headless.
!<
!< Three fields and a code editor in one window, edited by scripted keys only (one click gives each field the keyboard):
!< 1. UTF-8: 'ρ = 1.2 kg/m³' typed (characters of two bytes) reads back byte for byte; backspace takes '³' away whole
!<    (two bytes); '³' typed again; home, then shift+right selects 'ρ' alone (one character, two bytes), and 'ϱ' typed
!<    replaces it: 'ϱ = 1.2 kg/m³';
!< 2. the clipboard: a text the program puts there (`ig_set_clipboard`) pasted by ctrl+v; select all and ctrl+x cut it:
!<    the field empty and the clipboard holding it (`ig_get_clipboard`); ctrl+v puts it back;
!< 3. undo: two lines typed in a multi-line field, ctrl+z takes the last typing back (what remains is a prefix of the
!<    text typed, shorter);
!< 4. the code editor: `ed%select` a range read back by `ed%selection` (positions and text); `ed%goto` a position read
!<    back by `ed%cursor`; a range past the text clamped;
!< then the window against the golden src/tests/data/figure_test_text_edit.golden.png (|d| <= 2): the fields as the
!< keys left them, the multi-line field still edited (its undone text), the editor's selection.
!< The picture is `figure_test_text_edit.shot.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps it).
! oracle: click text-typing:picture text-utf8:picture text-selection:picture text-clipboard:picture
! oracle: text-undo:picture
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, code_editor_object, figure_last_error, ig_begin, ig_end, ig_get_clipboard, &
                   ig_input_text, ig_input_text_multiline, ig_item_rect, ig_set_clipboard, ig_set_next_window,   &
                   text_buffer_object, ImGuiWindowFlags_NoDecoration, FIG_OK
use figure_testing, only : test_capture, test_click, test_compare_image, test_key, test_type

implicit none
character(len=*), parameter :: GOLDEN = 'src/tests/data/figure_test_text_edit.golden.png' !< The committed reference.
character(len=*), parameter :: SHOT = 'figure_test_text_edit.shot.png.tmp'               !< The window.
character(len=*), parameter :: LF = new_line('a')                                         !< Line feed.
character(len=*), parameter :: TYPED = 'ρ = 1.2 kg/m³'                                   !< Typed (UTF-8).
character(len=*), parameter :: CUT = 'ρ = 1.2 kg/m'                                      !< ... after a backspace.
character(len=*), parameter :: SWAPPED = 'ϱ = 1.2 kg/m³'                                 !< ... 'ρ' replaced.
character(len=*), parameter :: CLIP = 'pasted from the clipboard'                         !< The clipboard's text.
character(len=*), parameter :: CODE = 'program demo'//LF//'   x = 1.5'//LF//'endprogram demo' !< The editor's text.
integer(int32),   parameter :: W = 640_int32                                              !< Display width [pixels].
integer(int32),   parameter :: H = 420_int32                                              !< Display height [pixels].
type(app_object)            :: app             !< Application.
type(text_buffer_object)    :: notes           !< The multi-line field.
type(code_editor_object)    :: ed              !< The code editor.
character(len=64)           :: units           !< The UTF-8 field.
character(len=64)           :: paste           !< The clipboard's field.
real(real64)                :: at(2, 3)        !< Centres of the three fields [pixels].
logical                     :: test_passed(10) !< Per-check outcome.
character(len=:), allocatable :: got(:)        !< The UTF-8 field after each step.
character(len=:), allocatable :: typed_notes   !< The multi-line text before ctrl+z.
character(len=:), allocatable :: clip_after    !< The clipboard after the cut.
character(len=:), allocatable :: sel_text      !< The editor's selection.
character(len=:), allocatable :: paste_steps(:) !< The clipboard's field: pasted, cut, pasted again.
integer(int32)              :: pos(4)          !< The editor's selection read back.
integer(int32)              :: clamp(4)        !< ... of a range past the text.
integer(int32)              :: cur(2)          !< The editor's cursor read back.
logical                     :: has_sel         !< The editor has a selection.
integer(int64)              :: nf              !< Pixels that failed.
integer(int32)              :: s               !< Status.
character(len=16)           :: keep            !< FIGURE_TEST_KEEP.

units = ''
paste = ''
allocate(character(len=64) :: got(4), paste_steps(3))
call app%init_headless(W, H)
call ed%init()
call ed%set_text(CODE)
call run(3_int32)
! 1. UTF-8
call test_click(at(1, 1), at(2, 1))
call run(6_int32)
call test_type(TYPED)
call run(3_int32)
got(1) = units
call test_key('backspace')
call run(3_int32)
got(2) = units
call test_type('³')
call run(3_int32)
got(3) = units
call test_key('home')
call test_key('shift', down=.true.)
call test_key('right')
call test_key('shift', down=.false.)
call run(2_int32)
call test_type('ϱ')
call run(3_int32)
got(4) = units
call test_key('enter')
call run(2_int32)
test_passed(1) = trim(got(1)) == TYPED
test_passed(2) = trim(got(2)) == CUT .and. len_trim(got(1)) - len_trim(got(2)) == 2
test_passed(3) = trim(got(3)) == TYPED .and. trim(got(4)) == SWAPPED
if (.not. all(test_passed(1:3))) write(output_unit, '(A,4(A,"|"))') 'utf-8: ', (trim(got(s)), s = 1, 4)
! 2. the clipboard
call ig_set_clipboard(CLIP)
call test_click(at(1, 2), at(2, 2))
call run(6_int32)
call chord('v')
call run(3_int32)
paste_steps(1) = paste
call chord('a')
call chord('x')
call run(3_int32)
paste_steps(2) = paste
clip_after = ig_get_clipboard()
call chord('v')
call run(3_int32)
paste_steps(3) = paste
call test_key('enter')
call run(2_int32)
test_passed(4) = trim(paste_steps(1)) == CLIP .and. len_trim(paste_steps(2)) == 0 .and. clip_after == CLIP
test_passed(5) = trim(paste_steps(3)) == CLIP
if (.not. all(test_passed(4:5))) write(output_unit, '(A,3(A,"|"),A)') 'clipboard: ', &
   (trim(paste_steps(s)), s = 1, 3), clip_after
! 3. undo
call test_click(at(1, 3), at(2, 3))
call run(6_int32)
call test_type('first line')
call run(3_int32)
call test_key('enter')
call run(3_int32)
call test_type('second line')
call run(3_int32)
typed_notes = notes%text()
call chord('z')
call run(4_int32)
test_passed(6) = typed_notes == 'first line'//LF//'second line' .and. len(notes%text()) < len(typed_notes)
if (test_passed(6)) test_passed(6) = typed_notes(1:len(notes%text())) == notes%text()
if (.not. test_passed(6)) write(output_unit, '(A,A,"|",A)') 'undo: ', typed_notes, notes%text()
! 4. the editor: a selection, the cursor
call ed%goto(3_int32, 4_int32)
call ed%cursor(cur(1), cur(2))
call ed%select(2_int32, 4_int32, 2_int32, 11_int32)
has_sel = ed%selection(pos(1), pos(2), pos(3), pos(4), sel_text)
test_passed(7) = all(cur == [3_int32, 4_int32])
test_passed(8) = has_sel .and. all(pos == [2_int32, 4_int32, 2_int32, 11_int32]) .and. sel_text == 'x = 1.5'
call ed%select(3_int32, 1_int32, 9_int32, 99_int32)
if (ed%selection(clamp(1), clamp(2), clamp(3), clamp(4))) continue
call ed%select(2_int32, 4_int32, 2_int32, 11_int32)
test_passed(9) = all(clamp == [3_int32, 1_int32, 3_int32, 16_int32])
if (.not. all(test_passed(7:9))) write(output_unit, '(A,2I3,L2,4I3,1X,A,4I4)') 'editor: ', cur, has_sel, pos, &
   sel_text, clamp
! the picture
call run(3_int32)
s = -1_int32
call run(1_int32, shot=SHOT, stat=s)
call run(1_int32)
test_passed(10) = s == FIG_OK
if (test_passed(10)) test_passed(10) = test_compare_image(SHOT, GOLDEN, failed=nf, stat=s)
if (.not. test_passed(10)) write(output_unit, '(A,I0,A,I0,A,A)') 'golden: status ', s, ', ', nf, ' failed: ', &
                                                                figure_last_error()
call ed%destroy()
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_shot()

write(output_unit, '(A,*(L2))') 'figure_test_text_edit checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine chord(key)
   !< The platform's shortcut key held while `key` is pressed (ctrl, cmd on macOS).
   character(len=*), intent(in) :: key !< Key.

   call test_key('shortcut', down=.true.)
   call test_key(key)
   call test_key('shortcut', down=.false.)
   endsubroutine chord

   subroutine run(n, shot, stat)
   !< `n` frames of the window; the last captured to `shot`.
   integer(int32),   intent(in)            :: n    !< Frames.
   character(len=*), intent(in),  optional :: shot !< Capture of the last.
   integer(int32),   intent(out), optional :: stat !< Status of the capture.
   integer(int32)                          :: f    !< Frame.
   real(real64)                            :: r(4) !< An item's rectangle.

   do f = 1_int32, n
      if (.not. app%next_frame()) error stop 'figure_test_text_edit: next_frame returned false in headless mode'
      call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
      if (ig_begin('edit', flags=ImGuiWindowFlags_NoDecoration)) then
         if (ig_input_text('density', units)) continue
         call ig_item_rect(r(1), r(2), r(3), r(4))
         at(:, 1) = [r(1) + 40.0_real64, 0.5_real64 * (r(2) + r(4))]
         if (ig_input_text('clipboard', paste)) continue
         call ig_item_rect(r(1), r(2), r(3), r(4))
         at(:, 2) = [r(1) + 40.0_real64, 0.5_real64 * (r(2) + r(4))]
         if (ig_input_text_multiline('##notes', notes, width=600.0_real64, height=110.0_real64)) continue
         call ig_item_rect(r(1), r(2), r(3), r(4))
         at(:, 3) = [r(1) + 300.0_real64, r(2) + 90.0_real64]
         if (ed%draw('code', 600.0_real64, 120.0_real64)) continue
      endif
      call ig_end()
      if (f == n .and. present(shot)) call test_capture(shot, stat)
   enddo
   endsubroutine run

   subroutine remove_shot()
   !< The capture.
   integer(int32) :: unit, ios !< Unit, status.

   open(newunit=unit, file=SHOT, status='old', iostat=ios)
   if (ios == 0) close(unit, status='delete')
   endsubroutine remove_shot
endprogram figure_test_text_edit
