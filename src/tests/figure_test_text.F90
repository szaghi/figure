!< figure_test_text, lists, text, child regions and multi-line text (selectables, wrapped and coloured text, scrolling
!< regions, text buffers, the monospace font), headless.
program figure_test_text
!< figure_test_text, lists, text, child regions and multi-line text (selectables, wrapped and coloured text, scrolling
!< regions, text buffers, the monospace font), headless.
!<
!< A list of sections picked by a click, help text wrapped at a region's width, coloured and disabled text that leave the
!< style as it was, a region that scrolls under the wheel while its window does not, and a column placed by offset.
!< Then a multi-line field: lines typed (Enter a newline, Tab a tab), undone and redone, 100 KB pasted past the
!< buffer's first capacity, a text set while it is edited; a read-only one that refuses edits but lets its text be
!< selected and copied, CRLF read as LF; and every character of plex-mono as wide as the others.
!< Then the fallback fonts: every Greek letter, the operators CFD writes and the sub- and superscript digits have a
!< glyph with a bitmap in both text fonts, from Plex or from Noto Sans Math; a text with a fallback glyph has a width;
!< Plex's own glyphs ('A', '0') stay Plex's, their bitmaps unchanged by a program's fallback; Noto's letters as tall
!< as Plex's; a program's own fallback gives only what the bundled fonts lack, also in a font loaded after it; the
!< statuses of add_fallback_font.
use, intrinsic :: iso_c_binding, only : c_associated, c_char, c_f_pointer, c_float, c_null_char, c_ptr
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : FIG_ERR_ARGUMENT, FIG_ERR_FAILED, FIG_ERR_STATE, FIG_OK
use figure, only : app_object, ig_begin, ig_begin_child, ig_end, ig_end_child, ig_input_text_multiline, ig_item_rect, &
                   ig_pop_font, ig_push_font, ig_same_line, ig_selectable, ig_set_next_window, ig_text, &
                   ig_text_colored, ig_text_disabled, ig_text_size, ig_text_wrapped, text_buffer_object
use figure_cimgui, only : im_vec4, igGetClipboardText, igGetScrollY, igGetStyleColorVec4, igGetTextLineHeight, &
                          igSetClipboardText
use figure_cimgui_enums, only : ImGuiCol_Text
use figure_testing, only : test_click, test_glyph, test_item_center, test_key, test_mouse_move, test_type, test_wheel

implicit none
integer(int32), parameter :: FRAMES = 60_int32  !< Frames run.
type(app_object)          :: app                !< Application.
logical                   :: test_passed(7)     !< Per-check outcome.
logical                   :: text_passed(11)    !< Per-check outcome of the multi-line text.
logical                   :: font_passed(9)     !< Per-check outcome of the fallback fonts.
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
call check_multiline(text_passed)
write(output_unit, '(A,*(L2))') 'figure_test_text multi-line checks:', text_passed
call check_fallback(font_passed)
write(output_unit, '(A,*(L2))') 'figure_test_text fallback font checks:', font_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed) .and. all(text_passed) .and. all(font_passed)
if (.not. (all(test_passed) .and. all(text_passed) .and. all(font_passed))) error stop 1

contains
   subroutine check_fallback(passed)
   !< The fallback fonts, in a headless application of their own.
   logical, intent(out)          :: passed(:)        !< Per-check outcome.
   character(len=*), parameter   :: FONTS(2) = ['plex-sans', 'plex-mono'] !< The text fonts.
   character(len=*), parameter   :: OWN = 'third_party/fonts/IBMPlexSans-Regular.ttf' !< A program's fallback.
   character(len=*), parameter   :: OWN_NAME = 'IBMPlexSans-Regular.ttf' !< Its source name.
   integer(int32),   parameter   :: SET(82) = [                                      & !< The glyphs CFD writes:
      (913 + [(k, k = 0, 16)]), (931 + [(k, k = 0, 6)]),                            & ! Greek upper (no U+03A2),
      (945 + [(k, k = 0, 24)]),                                                     & ! lower with final sigma,
      8711, 8706, 916, 8734, 8776, 8804, 8805, 177, 215, 183, 8730, 8721, 8747,     & ! the operators,
      8304, 185, 178, 179, (8308 + [(k, k = 0, 5)]), (8320 + [(k, k = 0, 9)])]      ! super- and subscript digits
   character(len=:), allocatable :: source           !< The font giving a glyph.
   character(len=:), allocatable :: glyph            !< A glyph as UTF-8.
   character(len=:), allocatable :: missing          !< Glyphs failing check 1.
   integer(int64)                :: pixels           !< Pixels of its bitmap.
   real(real64)                  :: width            !< Its advance [pixels].
   real(real64)                  :: height(2)        !< Heights of capital alpha: plex-sans, plex-mono [pixels].
   real(real64)                  :: extent(2)        !< A text's size [pixels].
   real(real64)                  :: text_w(2)        !< Widths of 'rho' and 'rho infinity' in plex-mono [pixels].
   integer(int64)                :: sums(2, 2, 2)    !< Checksums of 'A', '0' x fonts x before/after the own fallback.
   character(len=32)             :: sources(2, 2, 2) !< Sources of 'A', '0' x fonts x before/after.
   character(len=32)             :: alpha(4)         !< Sources of alpha: plex-sans, plex-mono, plex-mono after,
                                                     !< proggy (loaded after).
   character(len=32)             :: accented(4)      !< Sources of alpha with tonos: mono before, mono after,
                                                     !< sans after, proggy (loaded after).
   character(len=32)             :: nabla            !< Source of nabla in plex-sans.
   integer(int32)                :: stats(5)         !< add_fallback_font: before init, no file, not a font, the
                                                     !< program's (inside a frame: from the next), the same again.
   integer(int32)                :: f, j, k          !< Counters.

   passed = .false.
   missing = ''
   sums = 0_int64
   sources = ''
   call app%add_fallback_font(OWN, stat=stats(1)) ! before init: refused
   call app%init_headless(400_int32, 300_int32)
   do f = 1_int32, 2_int32 ! 1: the bundled fallback only (the program's added in it); 2: with the program's own
      if (.not. app%next_frame()) error stop 'figure_test_text: next_frame returned false in headless mode'
      if (ig_begin('Glyphs')) then
         if (f == 1_int32) then
            do j = 1_int32, size(FONTS, kind=int32)
               do k = 1_int32, size(SET, kind=int32)
                  glyph = utf8(SET(k))
                  call test_glyph(glyph, FONTS(j), source, pixels, width=width)
                  if (source == '' .or. pixels <= 0_int64 .or. width <= 0.0_real64) &
                     missing = missing//' '//trim(FONTS(j))//':'//glyph
               enddo
            enddo
            call test_glyph(utf8(945), 'plex-sans', source, pixels)
            alpha(1) = source
            call test_glyph(utf8(945), 'plex-mono', source, pixels)
            alpha(2) = source
            call test_glyph(utf8(8711), 'plex-sans', source, pixels)
            nabla = source
            call app%add_fallback_font('no/such/font.ttf', stat=stats(2))
            call app%add_fallback_font('fpm.toml', stat=stats(3))
            call app%add_fallback_font(OWN, stat=stats(4)) ! inside a frame: merged before the next
            call app%add_fallback_font(OWN, stat=stats(5)) ! added already: nothing to do
            call test_glyph(utf8(940), 'plex-mono', source, pixels)
            accented(1) = source                           ! not yet
            call test_glyph(utf8(913), 'plex-sans', source, pixels, height=height(1))
            call test_glyph(utf8(913), 'plex-mono', source, pixels, height=height(2))
            call ig_push_font('plex-mono')
            extent = ig_text_size(utf8(961))
            text_w(1) = extent(1)
            extent = ig_text_size(utf8(961)//utf8(8734))
            text_w(2) = extent(1)
            call ig_pop_font()
         else
            call test_glyph(utf8(945), 'plex-mono', source, pixels)
            alpha(3) = source
            call test_glyph(utf8(940), 'plex-mono', source, pixels)
            accented(2) = source
            call test_glyph(utf8(940), 'plex-sans', source, pixels)
            accented(3) = source
            call test_glyph(utf8(940), 'proggy', source, pixels)
            accented(4) = source
            call test_glyph(utf8(945), 'proggy', source, pixels)
            alpha(4) = source
         endif
         do j = 1_int32, size(FONTS, kind=int32)
            call test_glyph('A', FONTS(j), source, pixels, checksum=sums(1, j, f))
            sources(1, j, f) = source
            call test_glyph('0', FONTS(j), source, pixels, checksum=sums(2, j, f))
            sources(2, j, f) = source
         enddo
      endif
      call ig_end()
   enddo
   call app%destroy()

   passed(1) = missing == ''                                                           ! every glyph, both fonts
   passed(2) = trim(alpha(1)) == 'IBM Plex Sans' .and. trim(alpha(2)) == 'Noto Sans Math' .and. &
               trim(nabla) == 'Noto Sans Math'                                         ! Plex first, Noto after
   passed(3) = text_w(1) > 0.0_real64 .and. text_w(2) > text_w(1)                      ! a width, the fallback's too
   passed(4) = all(sources(:, 1, :) == 'IBM Plex Sans') .and. all(sources(:, 2, :) == 'IBM Plex Mono') ! Plex's own
   passed(5) = all(sums(:, :, 1) == sums(:, :, 2)) .and. all(sums /= 0_int64)          ! ... bitmaps unchanged
   passed(6) = abs(height(2) / max(height(1), 1.0_real64) - 1.0_real64) < 0.08_real64 ! Noto's capitals as tall
   passed(7) = trim(accented(1)) == '' .and. trim(accented(2)) == OWN_NAME .and. &     ! the program's fallback:
               trim(alpha(3)) == 'Noto Sans Math' .and. trim(accented(3)) == 'IBM Plex Sans' ! after the bundled
   passed(8) = trim(accented(4)) == OWN_NAME .and. trim(alpha(4)) == 'Noto Sans Math' ! a font loaded after it
   passed(9) = stats(1) == FIG_ERR_STATE .and. stats(2) == FIG_ERR_FAILED .and. stats(3) == FIG_ERR_ARGUMENT .and. &
               stats(4) == FIG_OK .and. stats(5) == FIG_OK
   if (.not. all(passed)) then
      write(output_unit, '(A)') 'fallback: missing'//missing
      write(output_unit, '(A)') 'fallback: alpha "'//trim(alpha(1))//'" "'//trim(alpha(2))//'" "'//trim(alpha(3))// &
                                '" "'//trim(alpha(4))// &
                                '", nabla "'//trim(nabla)//'", accented "'//trim(accented(1))//'" "'// &
                                trim(accented(2))//'" "'//trim(accented(3))//'" "'//trim(accented(4))//'"'
      write(output_unit, '(A,2F8.2,A,2F8.2,A,5(I0,1X))') 'fallback: alpha heights', height, ', widths', text_w, &
                                                        ', statuses ', stats
      write(output_unit, '(A,8(1X,A),A,8(1X,I0))') 'fallback: A/0 sources', &
            (((trim(sources(k, j, f)), k = 1, 2), j = 1, 2), f = 1, 2), ', sums', sums
   endif
   endsubroutine check_fallback

   pure function utf8(cp) result(s)
   !< A code point of the Basic Multilingual Plane as UTF-8. The bytes go through a fixed-length buffer: nvfortran
   !< 26.9 gives `char(n)` of a non-constant `n` the length n when it is assigned to a deferred-length variable.
   integer(int32), intent(in)    :: cp !< Code point.
   character(len=:), allocatable :: s  !< Its UTF-8 bytes.
   character(len=3)              :: b  !< The bytes.
   integer(int32)                :: n  !< How many.

   if (cp < 128_int32) then
      b(1:1) = achar(cp)
      n = 1_int32
   elseif (cp < 2048_int32) then
      b(1:1) = char(192 + cp / 64)
      b(2:2) = char(128 + mod(cp, 64))
      n = 2_int32
   else
      b(1:1) = char(224 + cp / 4096)
      b(2:2) = char(128 + mod(cp / 64, 64))
      b(3:3) = char(128 + mod(cp, 64))
      n = 3_int32
   endif
   s = b(1:n)
   endfunction utf8

   subroutine check_multiline(passed)
   !< The multi-line field, the text buffer and the monospace font, in a headless application of their own.
   logical, intent(out)          :: passed(:)          !< Per-check outcome.
   character(len=1), parameter   :: LF = char(10)      !< Line feed.
   character(len=1), parameter   :: CR = char(13)      !< Carriage return.
   character(len=1), parameter   :: TAB = char(9)      !< Tab.
   character(len=*), parameter   :: TYPED = 'first line'//LF//'second line'//LF//'third'//TAB//'line' !< Typed text.
   character(len=*), parameter   :: GLYPHS(6) = ['i', 'W', 'm', '.', '0', ' '] !< Characters measured.
   integer(int32),   parameter   :: PASTE_LINES = 1000_int32 !< Lines pasted, 100 bytes each.
   type(app_object)              :: app                !< Application.
   type(text_buffer_object)      :: notes              !< The editable text.
   type(text_buffer_object)      :: view               !< The read-only text.
   type(text_buffer_object)      :: unused             !< Never set nor drawn.
   character(len=:), allocatable :: big                !< 100 KB pasted.
   character(len=:), allocatable :: typed_text         !< The editable text once typed.
   character(len=:), allocatable :: undone             !< ... after ctrl+z.
   character(len=:), allocatable :: redone             !< ... after ctrl+y.
   character(len=:), allocatable :: copied             !< The clipboard after the read-only field's copy.
   integer(int64)                :: before_paste       !< Length before the paste [bytes].
   integer(int64)                :: after_paste        !< Length after it [bytes].
   logical                       :: pasted_ok          !< The pasted text ends the editable one.
   logical                       :: view_edited        !< The read-only field reported an edit.
   real(real64)                  :: notes_at(2)        !< Centre of the editable field.
   real(real64)                  :: view_at(2)         !< Centre of the read-only field.
   real(real64)                  :: mono(size(GLYPHS)) !< Widths in plex-mono [pixels].
   real(real64)                  :: sans(size(GLYPHS)) !< Widths in plex-sans [pixels].
   real(real64)                  :: extent(2)          !< A text's size [pixels].
   integer(int32)                :: frame              !< Frame counter.
   integer(int32)                :: k                  !< Counter.

   typed_text = ''
   undone = ''
   redone = ''
   copied = ''
   before_paste = 0_int64
   after_paste = -1_int64
   pasted_ok = .false.
   big = ''
   do k = 1_int32, PASTE_LINES
      big = big//repeat(achar(48 + mod(k, 10_int32)), 99)//LF
   enddo
   passed(1) = notes%length() == 0_int64 .and. notes%text() == '' .and. unused%text() == '' ! empty before any set
   call notes%set('first line')
   call view%set('alpha'//LF//'beta'//CR//LF//'gamma'//CR//LF)
   view_edited = .false.
   call app%init_headless(800_int32, 600_int32)
   do frame = 1_int32, 140_int32
      if (.not. app%next_frame()) error stop 'figure_test_text: next_frame returned false in headless mode'
      call ig_set_next_window(20.0_real64, 20.0_real64, 700.0_real64, 520.0_real64, always=.true.)
      if (ig_begin('Notes')) then
         if (ig_input_text_multiline('##notes', notes, width=640.0_real64, height=200.0_real64, tab_input=.true.)) continue
         call test_item_center(notes_at(1), notes_at(2))
         if (ig_input_text_multiline('##view', view, height=100.0_real64, read_only=.true.)) view_edited = .true.
         call test_item_center(view_at(1), view_at(2))
         call ig_push_font('plex-mono')
         do k = 1_int32, size(GLYPHS, kind=int32)
            extent = ig_text_size(GLYPHS(k))
            mono(k) = extent(1)
         enddo
         call ig_pop_font()
         do k = 1_int32, size(GLYPHS, kind=int32)
            extent = ig_text_size(GLYPHS(k))
            sans(k) = extent(1)
         enddo
      endif
      call ig_end()
      select case (frame)
      case (3_int32)
         call test_click(notes_at(1), notes_at(2) + 60.0_real64) ! below the line: the cursor at the end
      case (10_int32)
         call test_key('enter')
      case (13_int32)
         call test_type('second line')
      case (16_int32)
         call test_key('enter')
      case (19_int32)
         call test_type('third')
      case (22_int32)
         call test_key('tab')
      case (25_int32)
         call test_type('line')
      case (30_int32)
         typed_text = notes%text()
         call test_key('shortcut', down=.true.)                 ! ctrl+z (cmd+z on macOS)
         call test_key('z')
         call test_key('shortcut', down=.false.)
      case (36_int32)
         undone = notes%text()
         call test_key('shortcut', down=.true.)                 ! ctrl+y: redo
         call test_key('y')
         call test_key('shortcut', down=.false.)
      case (42_int32)
         redone = notes%text()
         before_paste = notes%length()
         call igSetClipboardText(big//c_null_char)
         call test_key('shortcut', down=.true.)                 ! ctrl+v
         call test_key('v')
         call test_key('shortcut', down=.false.)
      case (50_int32)
         after_paste = notes%length()
         block
            character(len=:), allocatable :: all_text !< The text after the paste.
            all_text = notes%text()
            pasted_ok = len(all_text, int64) == after_paste
            if (pasted_ok) pasted_ok = all_text(len(all_text) - len(big) + 1:) == big
         endblock
         call test_click(view_at(1), view_at(2))                ! the read-only field: edits refused
      case (56_int32)
         call test_type('X')
         call test_key('backspace')
         call test_key('enter')
      case (62_int32)
         call igSetClipboardText(c_null_char)
         call test_key('shortcut', down=.true.)                 ! select all and copy: allowed
         call test_key('a')
         call test_key('c')
         call test_key('shortcut', down=.false.)
      case (70_int32)
         copied = clipboard()
         call test_click(notes_at(1), notes_at(2))              ! the editable field again
      case (80_int32)
         call notes%set('replaced'//CR//LF)                     ! while it is edited
      case (86_int32)
         call test_type('!')
      endselect
   enddo
   call app%destroy()

   passed(2) = typed_text == TYPED                                       ! lines typed, Enter a newline, Tab a tab
   passed(3) = len(undone) < len(typed_text)                             ! ctrl+z took the last typing back
   if (passed(3)) passed(3) = typed_text(1:len(undone)) == undone
   passed(4) = redone == typed_text                                      ! ctrl+y put it back
   passed(5) = after_paste == before_paste + len(big, int64)             ! 100 KB pasted: the buffer grew
   passed(6) = pasted_ok                                                 ! ... with the pasted text
   passed(7) = view%text() == 'alpha'//LF//'beta'//LF//'gamma'//LF .and. .not. view_edited ! read-only; CRLF is LF
   passed(8) = copied == 'alpha'//LF//'beta'//LF//'gamma'//LF            ! ... yet selected and copied
   passed(9) = notes%text() == 'replaced'//LF//'!'                       ! a set shows in the field being edited
   passed(10) = maxval(mono) - minval(mono) < 0.01_real64 .and. minval(mono) > 1.0_real64 ! monospace: equal advances
   passed(11) = maxval(sans) - minval(sans) > 1.0_real64                 ! ... which plex-sans does not have
   if (.not. all(passed)) then
      write(output_unit, '(A)') 'typed:  "'//typed_text//'"'
      write(output_unit, '(A)') 'undone: "'//undone//'"'
      write(output_unit, '(A)') 'redone: "'//redone//'"'
      write(output_unit, '(A,2I8)') 'paste lengths ', before_paste, after_paste
      write(output_unit, '(A)') 'view: "'//view%text()//'", copied: "'//copied//'"'
      write(output_unit, '(A)') 'notes now: "'//notes%text()//'"'
      write(output_unit, '(A,*(F7.2))') 'mono ', mono
      write(output_unit, '(A,*(F7.2))') 'sans ', sans
   endif
   endsubroutine check_multiline

   function clipboard() result(text)
   !< The clipboard's text.
   character(len=:), allocatable   :: text   !< Text.
   type(c_ptr)                     :: p      !< C string.
   character(kind=c_char), pointer :: c(:)   !< Its bytes.
   integer(int32)                  :: n      !< Its length.

   p = igGetClipboardText()
   if (.not. c_associated(p)) then
      text = ''
      return
   endif
   call c_f_pointer(p, c, [huge(0_int32)])
   n = 0_int32
   do while (c(n + 1) /= c_null_char)
      n = n + 1_int32
   enddo
   allocate(character(len=n) :: text)
   do n = 1_int32, len(text, int32)
      text(n:n) = c(n)
   enddo
   endfunction clipboard

   subroutine test_window_rect_left(name, x)
   !< Left edge of a window as drawn in the last frame.
   use figure_testing, only : test_window_rect
   character(len=*), intent(in)  :: name !< Window name.
   real(real64),     intent(out) :: x    !< Left [pixels].
   real(real64)                  :: r(3) !< The rest of the rectangle.

   call test_window_rect(name, x, r(1), r(2), r(3))
   endsubroutine test_window_rect_left
endprogram figure_test_text
