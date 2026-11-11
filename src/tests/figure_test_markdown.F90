!< figure_test_markdown, Markdown in the window (ig_markdown, markdown_view_object), headless.
program figure_test_markdown
!< figure_test_markdown, Markdown in the window (ig_markdown, markdown_view_object), headless.
!<
!< Headings drawn larger than the text (`#` more than `##`, both more than a paragraph); a list's bullet drawn (a dot,
!< not a dash); a click on a link returned with its URL on one frame, a link to a heading of the same text not
!< returned (it scrolls), one to a heading the text lacks returned; code spans in IBM Plex Mono (its glyphs, and a
!< monospaced width where the text is proportional); a table drawn as a table (its borders); the icons and the
!< fallback font merged into the Markdown fonts; an image from a file drawn, one from a URL not; the window against a
!< committed golden (src/tests/data/figure_test_markdown.golden.png, |d| <= 2); a document's search counts its matches
!< and ends, its scroll to a heading moves the view and reports no link, its text loaded from a file; the statuses;
!< a second application draws Markdown again. The pictures are `figure_test_markdown.*.tmp`, removed at the end.
use, intrinsic :: iso_c_binding, only : c_int, c_loc
use, intrinsic :: iso_fortran_env, only : int8, int32, int64, output_unit, real64
use figure, only : app_object, FIG_ERR_ARGUMENT, FIG_ERR_FAILED, FIG_ERR_STATE, FIG_OK, fig_read_image, ICON_PLAY, &
                   ig_begin, ig_cursor_screen_pos, ig_end, ig_markdown, ig_set_next_window, markdown_view_object
use figure_c_native, only : fig_image_write
use figure_testing, only : test_capture, test_click, test_compare_image, test_drawn_extent, test_glyph

implicit none
character(len=*), parameter :: GOLDEN = 'src/tests/data/figure_test_markdown.golden.png' !< The committed reference.
character(len=*), parameter :: SHOT = 'figure_test_markdown.shot.png.tmp'  !< A picture of the window.
character(len=*), parameter :: PAGE = 'figure_test_markdown.page.md.tmp'   !< A Markdown file.
character(len=*), parameter :: IMAGE = 'figure_test_markdown.image.png.tmp' !< A picture in the Markdown.
character(len=*), parameter :: LF = achar(10)                              !< Line feed.
character(len=*), parameter :: RHO = char(207)//char(129)                  !< U+03C1, in IBM Plex Sans.
character(len=*), parameter :: NABLA = char(226)//char(136)//char(135)     !< U+2207, from Noto Sans Math.
integer(int32),   parameter :: W = 640_int32                               !< Display width [pixels].
integer(int32),   parameter :: H = 400_int32                               !< Display height [pixels].
type(app_object)              :: app             !< Application.
type(markdown_view_object)    :: view            !< A document.
character(len=:), allocatable :: snippet         !< The text ig_markdown draws.
logical                       :: in_view         !< The window draws the document, not the snippet.
real(real64)                  :: cx, cy          !< The cursor where the Markdown starts [pixels].
integer(int32)                :: clicks          !< Links reported so far.
character(len=:), allocatable :: last            !< The last link reported.
logical                       :: table_found     !< A table's border was drawn, in the last frame.
real(real64)                  :: table(4)        !< Its extent.
logical                       :: test_passed(13) !< Per-check outcome.
integer(int32)                :: early           !< ig_markdown's status before the first frame.
logical                       :: early_click     !< ... its result.
character(len=8)              :: keep            !< FIGURE_TEST_KEEP.

test_passed = .false.
snippet = ''
in_view = .false.
clicks = 0_int32
last = ''
call app%init_headless(W, H)
early_click = ig_markdown('# early', stat=early)          ! no frame open yet: refused
if (early_click) early = FIG_OK
call view%init()
call headings(test_passed(1))
call lists(test_passed(2))
call links(test_passed(3))
call code_font(test_passed(4))
call tables(test_passed(5))
call fonts_merged(test_passed(6))
call images(test_passed(7))
call whole_window(test_passed(8))
call document_search(test_passed(9))
call document_scroll(test_passed(10))
call document_load(test_passed(11))
call statuses(test_passed(12))
call view%destroy()
call app%destroy()
call again(test_passed(13))
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files() ! FIGURE_TEST_KEEP=1 keeps the pictures, to look at them

write(output_unit, '(A,*(L2))') 'figure_test_markdown checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine ui()
   !< One frame of the window: the snippet, or the document, filling it.
   character(len=:), allocatable :: url !< A link clicked.

   call ig_set_next_window(10.0_real64, 10.0_real64, 620.0_real64, 380.0_real64, always=.true.)
   if (ig_begin('Markdown')) then
      call ig_cursor_screen_pos(cx, cy)
      if (in_view) then
         if (view%draw('doc', url)) then
            clicks = clicks + 1_int32
            last = url
         endif
      else
         if (ig_markdown(snippet, url)) then
            clicks = clicks + 1_int32
            last = url
         endif
         call test_drawn_extent('TableBorderStrong', table(1), table(2), table(3), table(4), table_found)
      endif
   endif
   call ig_end()
   endsubroutine ui

   subroutine frames(n)
   !< `n` frames of the window.
   integer(int32), intent(in) :: n !< Frames.
   integer(int32)             :: k !< Frame.

   do k = 1_int32, n
      if (.not. app%next_frame()) error stop 'figure_test_markdown: next_frame returned false in headless mode'
      call ui()
   enddo
   endsubroutine frames

   subroutine picture(text, p)
   !< The window drawing `text`, as a picture.
   character(len=*),           intent(in)  :: text     !< Markdown.
   integer(int8), allocatable, intent(out) :: p(:,:,:) !< The picture.

   snippet = text
   in_view = .false.
   call frames(3_int32)
   call test_capture(SHOT)
   call frames(2_int32)
   call fig_read_image(SHOT, p)
   endsubroutine picture

   pure function ink_at(p, x, y, x0, y0) result(yes)
   !< Pixel (x, y) (from 0) differs from the background, pixel (x0, y0), by more than 40 in a channel.
   integer(int8),  intent(in) :: p(:,:,:) !< Picture.
   integer(int32), intent(in) :: x, y     !< Pixel.
   integer(int32), intent(in) :: x0, y0   !< The background's pixel.
   logical                    :: yes      !< Ink.
   integer(int32)             :: c        !< Channel.

   yes = .false.
   do c = 1_int32, 3_int32
      if (abs(iand(int(p(c, x + 1, y + 1), int32), 255_int32) - iand(int(p(c, x0 + 1, y0 + 1), int32), 255_int32)) &
          > 40_int32) yes = .true.
   enddo
   endfunction ink_at

   subroutine ink_box(p, height, box, found)
   !< The box of the ink below the cursor, `height` pixels down (the background: left of the cursor, in the padding).
   integer(int8),  intent(in), allocatable :: p(:,:,:) !< Picture.
   integer(int32), intent(in)  :: height   !< Rows looked at [pixels].
   integer(int32), intent(out) :: box(4)   !< xmin, ymin, xmax, ymax [pixels, from 0].
   logical,        intent(out) :: found    !< Some ink.
   integer(int32)              :: x, y, bx, by !< Pixels.

   bx = nint(cx) - 4_int32
   by = nint(cy)
   box = [huge(1_int32), huge(1_int32), -1_int32, -1_int32]
   found = .false.
   if (.not. allocated(p)) return
   do y = nint(cy), min(nint(cy) + height, size(p, 3, int32) - 1_int32)
      do x = nint(cx), size(p, 2, int32) - 21_int32
         if (.not. ink_at(p, x, y, bx, by)) cycle
         found = .true.
         box = [min(box(1), x), min(box(2), y), max(box(3), x), max(box(4), y)]
      enddo
   enddo
   endsubroutine ink_box

   integer(int32) function ink_height(text, rows)
   !< The height of the ink of `text` drawn alone, in its first `rows` (default 60) [pixels] (0: none).
   character(len=*), intent(in)           :: text     !< Markdown.
   integer(int32),   intent(in), optional :: rows     !< Rows looked at [pixels].
   integer(int8), allocatable   :: p(:,:,:) !< Picture.
   integer(int32)               :: box(4)   !< Its ink.
   logical                      :: found    !< Some ink.

   call picture(text, p)
   if (present(rows)) then
      call ink_box(p, rows, box, found)
   else
      call ink_box(p, 60_int32, box, found)
   endif
   ink_height = 0_int32
   if (found) ink_height = box(4) - box(2) + 1_int32
   endfunction ink_height

   integer(int32) function ink_width(text)
   !< The width of the ink of `text` drawn alone [pixels] (0: none).
   character(len=*), intent(in) :: text     !< Markdown.
   integer(int8), allocatable   :: p(:,:,:) !< Picture.
   integer(int32)               :: box(4)   !< Its ink.
   logical                      :: found    !< Some ink.

   call picture(text, p)
   call ink_box(p, 30_int32, box, found)
   ink_width = 0_int32
   if (found) ink_width = box(3) - box(1) + 1_int32
   endfunction ink_width

   subroutine headings(ok)
   !< `#` and `##` draw larger than a paragraph's text, `#` at least as large as `##`.
   logical, intent(out) :: ok         !< Outcome.
   integer(int32)       :: hb, h1, h2 !< Ink heights of the same capitals.

   hb = ink_height('MHM')
   h1 = ink_height('# MHM')
   h2 = ink_height('## MHM')
   ok = hb > 0_int32 .and. h1 >= h2 .and. real(h2, real64) > 1.2_real64 * hb .and. real(h1, real64) > 1.3_real64 * hb
   if (.not. ok) write(output_unit, '(A,3(1X,I0))') 'headings: ink heights of text, #, ##:', hb, h1, h2
   endsubroutine headings

   subroutine lists(ok)
   !< `* MHM` draws a bullet (a round dot, as tall as wide, lower than the capitals), then a gap, then the text.
   logical, intent(out)       :: ok         !< Outcome.
   integer(int8), allocatable :: p(:,:,:)   !< Picture.
   integer(int32)             :: box(4)     !< The ink.
   integer(int32)             :: a, b, x, y, top, bottom !< The bullet's columns and rows.
   logical                    :: found      !< Some ink.
   logical                    :: col        !< A column with ink.

   call picture('* MHM', p)
   call ink_box(p, 30_int32, box, found)
   ok = found
   if (.not. ok) return
   a = box(1)
   b = a
   do x = a, box(3)
      col = .false.
      do y = box(2), box(4)
         if (ink_at(p, x, y, nint(cx) - 4_int32, nint(cy))) col = .true.
      enddo
      if (.not. col) exit
      b = x
   enddo
   top = huge(1_int32)
   bottom = -1_int32
   do y = box(2), box(4)
      do x = a, b
         if (ink_at(p, x, y, nint(cx) - 4_int32, nint(cy))) then
            top = min(top, y)
            bottom = max(bottom, y)
         endif
      enddo
   enddo
   ok = bottom - top + 1_int32 >= 3_int32 .and. abs((b - a) - (bottom - top)) <= 2_int32 .and. &
        bottom - top + 1_int32 < box(4) - box(2) + 1_int32 .and. b < box(3) - 10_int32
   if (.not. ok) write(output_unit, '(A,6(1X,I0))') 'lists: bullet columns, rows; ink box:', a, b, top, bottom, &
                       box(2), box(4)
   endsubroutine lists

   subroutine links(ok)
   !< A click on a link: reported once, with its URL. A link to a heading of the text: not reported. A link to a
   !< heading the text lacks: reported as `#` and its anchor.
   logical, intent(out) :: ok    !< Outcome.
   logical              :: first !< The first case.
   logical              :: inner !< The second.

   snippet = '[the manual](https://example.org/manual) of the solver'
   in_view = .false.
   call frames(3_int32)
   clicks = 0_int32
   last = ''
   call test_click(cx + 20.0_real64, cy + 8.0_real64)
   call frames(8_int32)
   first = clicks == 1_int32 .and. last == 'https://example.org/manual'
   if (.not. first) write(output_unit, '(A,I0,A)') 'links: ', clicks, ' clicks, last '//last
   snippet = '[below](#the-end)'//LF//LF//'text'//LF//LF//'## The end'//LF//LF//'last'
   call frames(3_int32)
   clicks = 0_int32
   call test_click(cx + 10.0_real64, cy + 8.0_real64)
   call frames(8_int32)
   inner = clicks == 0_int32
   if (.not. inner) write(output_unit, '(A,I0,A)') 'links (anchor): ', clicks, ' clicks, last '//last
   snippet = '[nowhere](#no-such-heading)'
   call frames(3_int32)
   clicks = 0_int32
   call test_click(cx + 10.0_real64, cy + 8.0_real64)
   call frames(8_int32)
   ok = first .and. inner .and. clicks == 1_int32 .and. last == '#no-such-heading'
   if (.not. ok) write(output_unit, '(A,I0,A)') 'links (missing anchor): ', clicks, ' clicks, last '//last
   endsubroutine links

   subroutine code_font(ok)
   !< Code spans in IBM Plex Mono: the Markdown code font's glyphs are Plex Mono's (the same bitmap), and ten i's are
   !< nearly as wide as ten M's in a code span, where the text's are not.
   logical, intent(out)          :: ok         !< Outcome.
   character(len=:), allocatable :: source     !< The font giving a glyph.
   integer(int64)                :: px, sum_md !< Its pixels, checksum.
   integer(int64)                :: sum_mono   !< Plex Mono's checksum.
   integer(int32)                :: ci, cm     !< Code widths.
   integer(int32)                :: ti, tm     !< Text widths.

   ci = ink_width('`iiiiiiiiii`')
   cm = ink_width('`MMMMMMMMMM`')
   ti = ink_width('iiiiiiiiii')
   tm = ink_width('MMMMMMMMMM')
   call test_glyph('M', '<markdown code>', source, px, checksum=sum_md)
   ok = source == 'IBM Plex Mono (Markdown)' .and. px > 0_int64
   call test_glyph('M', 'plex-mono', source, px, checksum=sum_mono)
   ok = ok .and. sum_md == sum_mono .and. cm > 0_int32 .and. tm > 0_int32
   if (ok) ok = real(ci, real64) > 0.85_real64 * cm .and. real(ti, real64) < 0.6_real64 * tm
   if (.not. ok) write(output_unit, '(A,4(1X,I0),2(1X,I0))') 'code: widths i, M (code), i, M (text); checksums:', &
                       ci, cm, ti, tm, sum_md, sum_mono
   endsubroutine code_font

   subroutine tables(ok)
   !< A table: drawn with its borders, two rows and a header (taller than two lines), as wide as the window.
   logical, intent(out) :: ok !< Outcome.

   snippet = '| quantity | value |'//LF//'|---|---|'//LF//'| Mach number | 0.3 |'//LF//'| Reynolds number | 1e6 |'
   in_view = .false.
   call frames(3_int32)
   ok = table_found
   if (ok) ok = table(4) - table(2) > 50.0_real64 .and. table(3) - table(1) > 400.0_real64
   if (.not. ok) write(output_unit, '(A,L2,4(1X,F0.1))') 'tables:', table_found, table
   endsubroutine tables

   subroutine fonts_merged(ok)
   !< The Markdown fonts have FIGURE's icons and fallback: nabla from Noto Sans Math, an icon from Lucide.
   logical, intent(out)          :: ok     !< Outcome.
   character(len=:), allocatable :: s1, s2 !< The fonts giving the glyphs.
   integer(int64)                :: px     !< Pixels.

   snippet = 'text'
   call frames(2_int32)
   call test_glyph(NABLA, '<markdown>', s1, px)
   call test_glyph(ICON_PLAY, '<markdown bold>', s2, px)
   ok = s1 == 'Noto Sans Math' .and. s2 == 'Lucide'
   if (.not. ok) write(output_unit, '(A)') 'fonts: nabla from '//s1//', the icon from '//s2
   endsubroutine fonts_merged

   subroutine images(ok)
   !< An image from a file drawn (a white PNG of 160 x 120 pixels: 120 pixels of ink); one from a URL not.
   logical, intent(out)               :: ok                   !< Outcome.
   integer(int8), allocatable, target :: pixels(:,:,:)        !< The image.
   integer(c_int)                     :: s                    !< Its writing's status.
   integer(int32)                     :: hf, hu               !< Ink heights.

   allocate(pixels(4, 160, 120))

   pixels = -1_int8 ! white, opaque
   s = fig_image_write(IMAGE, len(IMAGE, c_int), c_loc(pixels), 4_c_int, 160_c_int, 120_c_int, 0_c_int)
   hf = ink_height('![white]('//IMAGE//')', 320_int32)
   hu = ink_height('![web](https://example.org/figure.png)')
   ok = s == FIG_OK .and. hf == 120_int32 .and. hu < 30_int32
   if (.not. ok) write(output_unit, '(A,2(1X,I0))') 'images: ink heights of a file, a URL:', hf, hu
   endsubroutine images

   subroutine whole_window(ok)
   !< The window drawing every kind of block, against the golden.
   logical, intent(out) :: ok !< Outcome.

   snippet = '# Solver help'//LF//LF// &
             'The solver reads an **input file** of *key = value* lines; see [the manual](https://example.org).'// &
             LF//LF//'## Keys'//LF//LF// &
             '* `reynolds number`: positive'//LF// &
             '* `mach number`: below 0.3 for '//RHO//' constant, '//NABLA//'p small'//LF//LF// &
             '| key | default |'//LF//'|---|---|'//LF//'| save frequency | 100 |'//LF//'| cfl | 0.8 |'//LF//LF// &
             '> [!NOTE]'//LF//'> Keys are case-insensitive.'//LF//LF// &
             '```'//LF//'reynolds number = 1e6'//LF//'```'
   in_view = .false.
   call frames(4_int32)
   call test_capture(SHOT)
   call frames(2_int32)
   ok = test_compare_image(SHOT, GOLDEN)
   endsubroutine whole_window

   function document() result(t)
   !< A help page of four sections, "pressure" three times.
   character(len=:), allocatable :: t !< Markdown.
   integer(int32)                :: k !< Paragraph.

   t = '# Help'//LF//LF//'## Introduction'//LF//LF//'The pressure is in pascal.'//LF//LF
   do k = 1_int32, 12_int32
      t = t//'A paragraph of the introduction, long enough to fill the view.'//LF//LF
   enddo
   t = t//'## Boundary conditions'//LF//LF//'An outlet has a pressure, an inlet a velocity.'//LF//LF
   do k = 1_int32, 12_int32
      t = t//'A paragraph about boundaries, long enough to fill the view.'//LF//LF
   enddo
   t = t//'## Last section'//LF//LF//'The reference pressure is 101325 Pa.'//LF
   endfunction document

   subroutine document_search(ok)
   !< `find` highlights three matches, the first current; `find('')` ends the search.
   logical, intent(out) :: ok    !< Outcome.
   integer(int32)       :: m, c  !< Matches, current.

   call view%set_text(document())
   in_view = .true.
   call frames(4_int32)
   call view%find('pressure')
   call frames(3_int32)
   m = view%matches()
   c = view%current_match()
   call view%find('')
   call frames(3_int32)
   ok = m == 3_int32 .and. c == 1_int32 .and. view%matches() == 0_int32 .and. view%current_match() == 0_int32
   if (.not. ok) write(output_unit, '(A,3(1X,I0))') 'search: matches, current, then matches:', m, c, view%matches()
   endsubroutine document_search

   subroutine document_scroll(ok)
   !< `scroll_to` a heading by its text moves the view (the picture changes) and reports no link; by its anchor, back;
   !< to a heading the text lacks, nothing (no link reported either).
   logical, intent(out)       :: ok       !< Outcome.
   integer(int8), allocatable :: a(:,:,:) !< The view at its start.
   integer(int8), allocatable :: b(:,:,:) !< ... at the last section.
   integer(int8), allocatable :: c(:,:,:) !< ... back at the first heading.
   real(real64)               :: r(4)     !< The view's rectangle.

   in_view = .true.
   call frames(3_int32)
   call test_capture(SHOT)
   call frames(2_int32)
   call fig_read_image(SHOT, a)
   clicks = 0_int32
   call view%scroll_to('Last section')
   call frames(40_int32)
   call test_capture(SHOT)
   call frames(2_int32)
   call fig_read_image(SHOT, b)
   call view%scroll_to('#help')
   call frames(40_int32)
   call test_capture(SHOT)
   call frames(2_int32)
   call fig_read_image(SHOT, c)
   call view%scroll_to('No such heading')
   call frames(10_int32)
   r = [cx, cy, 620.0_real64, 380.0_real64]
   ok = allocated(a) .and. allocated(b) .and. allocated(c) .and. clicks == 0_int32
   if (ok) ok = differ(a, b, r) .and. differ(b, c, r)
   if (.not. ok) write(output_unit, '(A,I0)') 'scroll: links reported ', clicks
   endsubroutine document_scroll

   subroutine document_load(ok)
   !< `load` reads a file (the text equal); a file that does not exist is refused, the text kept.
   logical, intent(out) :: ok !< Outcome.
   integer(int32)       :: u  !< Unit.
   integer(int32)       :: s  !< Status.

   open(newunit=u, file=PAGE, access='stream', form='unformatted', status='replace', action='write')
   write(u) '# Page'//LF//LF//'From a file.'//LF
   close(u)
   call view%load(PAGE, stat=s)
   ok = s == FIG_OK .and. view%text() == '# Page'//LF//LF//'From a file.'//LF
   call view%load('figure_test_markdown.missing.md', stat=s)
   ok = ok .and. s == FIG_ERR_FAILED .and. view%text() == '# Page'//LF//LF//'From a file.'//LF
   endsubroutine document_load

   subroutine statuses(ok)
   !< Refusals: before the first frame; a view before init; an empty id; a search too long or of two lines; an empty
   !< heading.
   logical, intent(out)       :: ok    !< Outcome.
   type(markdown_view_object) :: fresh !< Not initialized.
   integer(int32)             :: s(6)  !< Statuses.
   logical                    :: c     !< A result.

   s = FIG_OK
   in_view = .false.
   call frames(1_int32)
   c = fresh%draw('fresh', stat=s(1))
   c = view%draw('', stat=s(2))
   call view%find(repeat('a', 300), stat=s(3))
   call view%find('a'//LF//'b', stat=s(4))
   call view%scroll_to('', stat=s(5))
   call fresh%set_text('x', stat=s(6))
   ok = early == FIG_ERR_STATE .and. all(s == [FIG_ERR_STATE, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, &
                                               FIG_ERR_ARGUMENT, FIG_ERR_STATE])
   if (.not. ok) write(output_unit, '(A,7(1X,I0))') 'statuses:', early, s
   endsubroutine statuses

   subroutine again(ok)
   !< A second application: Markdown with an image drawn again (the first one's context and textures released), its
   !< fonts made again in the new atlas.
   logical, intent(out)          :: ok     !< Outcome.

   character(len=:), allocatable :: source !< The font giving nabla.
   integer(int64)                :: px     !< Its pixels.
   integer(int32)                :: s      !< Status.

   call app%init_headless(W, H)
   ok = ink_height('![white]('//IMAGE//')', 320_int32) == 120_int32
   call test_glyph(NABLA, '<markdown>', source, px, stat=s) ! the fonts made again, in this application's atlas
   ok = ok .and. s == FIG_OK .and. source == 'Noto Sans Math'
   call app%destroy()
   endsubroutine again

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

   subroutine remove_files()
   !< Remove the pictures and the file this test wrote.
   integer(int32) :: u, k !< Unit, counter.
   character(len=*), parameter :: FILES(3) = [character(len=40) :: SHOT, PAGE, IMAGE]

   do k = 1_int32, size(FILES, kind=int32)
      open(newunit=u, file=trim(FILES(k)), status='old', action='read', err=1)
      close(u, status='delete')
1     continue
   enddo
   endsubroutine remove_files
endprogram figure_test_markdown
