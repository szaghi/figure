!< figure_test_markdown_frame, the Fortran path's Markdown renderer (`md_markdown`) against imgui_rich_md's (`ig_markdown`).
program figure_test_markdown_frame
!< figure_test_markdown_frame, the Fortran path's Markdown renderer (`md_markdown`) against imgui_rich_md's (`ig_markdown`).
!<
!< szaghi/figure#15 P15. Each case draws one Markdown text on a few frames first with imgui_rich_md (FIGURE's
!< `ig_markdown`), then with the Fortran renderer (figure_markdown_render's `md_markdown`), 40 frames apart, each in a
!< window of its own at the same place (`Markdown###cpp`, `Markdown###fortran`: the same title, other IDs, so each side
!< starts from a fresh window). Checked on every frame: the cursor where the text starts and where it ends, whether a
!< link was clicked and its URL, equal to the bit; the first and the last frame's pictures at FIGURE's oracle rule
!< (|d| <= 2, no pixel failing). Scripted input, the same frames after each side's start: a click on a link (reported), on a link to a
!< heading (scrolled to, not reported) and to a missing one (reported as `#` and its anchor), a mouse resting on a link
!< (its tooltip), a double click (a word selected), a drag (a range selected), a right click (the menu). The cases:
!<
!< 1. headings `#` to `######`, paragraphs wrapped, emphasis, strong, both, code spans, strikethrough, underline, words
!<    glued across the markup, soft and hard breaks;
!< 2. lists: `*`, `-`, `+` bullets, ordered (`1.`, `3)`), nested, loose, tasks done and not;
!< 3. a code block (and one in a list), quotes nested, the five admonitions, thematic breaks;
!< 4. tables: header, left, centred and right-aligned cells, emphasis and code in cells, a wide one wrapped;
!< 5. imgui_rich_md's HTML: `<br>`, `<hr>`, `<u>`, `<sub>`, `<sup>`, `<kbd>`, `<mark>`, `<md-error>`, `<details>` (closed
!<    and open), `<pre>`, `<center>`, `<div>`, comments, `&nbsp;`, entities;
!< 6. images: a file at its size, one wider than the window (scaled down), `<img>` with a width, a URL (not drawn), a
!<    missing file (broken), an image in a link;
!< 7. figure_test_markdown's golden text;
!< 8. a click on a link; 9. a click on a link to a heading below (the window scrolls); 10. a link to a missing heading;
!< 11. the mouse resting on a link (the tooltip); 12. a double click on a word, then a drag (a selection); 13. a right
!< click on the text (the menu).
!<
!< The pictures are `figure_test_markdown_frame.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them; a
!< mismatch's .new.png and .diff.png are left for inspection).
use, intrinsic :: iso_c_binding, only : c_int, c_loc
use, intrinsic :: iso_fortran_env, only : int8, int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, FIG_OK, ig_begin, ig_cursor_screen_pos, ig_end, ig_markdown, &
                   ig_set_next_window
use figure_c_native, only : fig_image_write
use figure_markdown_render, only : md_markdown
use figure_testing, only : test_capture, test_click, test_compare_image, test_drag, test_mouse_move

implicit none
integer(int32),   parameter :: W = 640_int32        !< Display width [pixels].
integer(int32),   parameter :: H = 400_int32        !< Display height [pixels].
integer(int32),   parameter :: NCASE = 13_int32     !< Cases.
integer(int32),   parameter :: NFMAX = 48_int32     !< Frames per side of a case at most.
integer(int32),   parameter :: NSTATE = 5_int32     !< Values checked per frame.
character(len=*), parameter :: LF = achar(10)       !< Line feed.
character(len=*), parameter :: IMAGE = 'figure_test_markdown_frame.image.png.tmp' !< A picture.
character(len=*), parameter :: WIDE = 'figure_test_markdown_frame.wide.png.tmp'   !< A picture wider than the window.
character(len=*), parameter :: RHO = char(207)//char(129)              !< U+03C1.
character(len=*), parameter :: NABLA = char(226)//char(136)//char(135) !< U+2207.
type(app_object)              :: app                 !< Application.
real(real64)                  :: state(NSTATE, NFMAX, 2) !< Per frame and side: start x, y, end x, y, clicked.
character(len=:), allocatable :: urls(:)             !< The URL reported per side.
logical                       :: test_passed(NCASE)  !< Per-case outcome.
logical                       :: side_fortran        !< Drawing with the Fortran renderer.
character(len=:), allocatable :: text                !< The case's Markdown.
real(real64)                  :: x0, y0              !< Where the text starts (the first frame's).
integer(int32)                :: c, f, s, sd, i      !< Case, frame, status, side, counter.
character(len=16)             :: keep                !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
call write_images()
allocate(character(len=256) :: urls(2))
do c = 1_int32, NCASE
   text = case_text(c)
   state = 0.0_real64
   urls = ''
   do sd = 1_int32, 2_int32 ! 1 imgui_rich_md, 2 the Fortran renderer
      side_fortran = sd == 2_int32
      do f = 1_int32, nframes(c)
         if (.not. app%next_frame()) error stop 'figure_test_markdown_frame: next_frame returned false headless'
         call draw_case(c, f, sd)
         if (f == nframes(c)) call test_capture(picture(c, 1_int32, side_fortran), s)
         if (f == 1_int32) call test_capture(picture(c, 2_int32, side_fortran), s)
         if (f == 1_int32) then
            x0 = state(1, 1, sd)
            y0 = state(2, 1, sd)
         endif
         call act(c, f)
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      do i = 1_int32, 40_int32 ! as the other side-by-side tests: the sides apart
         if (.not. app%next_frame()) error stop 'figure_test_markdown_frame: next_frame returned false headless'
      enddo
   enddo
   test_passed(c) = state_equal(c) .and. pictures_equal(c, 1_int32)
   test_passed(c) = pictures_equal(c, 2_int32) .and. test_passed(c)
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_markdown_frame checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   pure function nframes(k) result(n)
   !< A case's frames per side.
   integer(int32), intent(in) :: k !< Case.
   integer(int32)             :: n !< Frames.

   select case (k)
   case (8_int32:10_int32)
      n = 24_int32
   case (11_int32)
      n = 40_int32
   case (12_int32, 13_int32)
      n = NFMAX
   case default
      n = 4_int32
   endselect
   endfunction nframes

   subroutine draw_case(k, fr, side)
   !< A case's text on a frame, by the side drawing; the state recorded.
   integer(int32), intent(in)    :: k, fr, side !< Case, frame, side.
   character(len=:), allocatable :: url         !< A link clicked.
   logical                       :: clicked     !< ... this frame.
   real(real64)                  :: x, y        !< Cursor.

   call ig_set_next_window(10.0_real64, 10.0_real64, 620.0_real64, 380.0_real64, always=.true.)
   if (ig_begin(trim(merge('Markdown###fortran', 'Markdown###cpp    ', side == 2_int32)))) then
      call ig_cursor_screen_pos(x, y)
      state(1:2, fr, side) = [x, y]
      if (side == 2_int32) then
         clicked = md_markdown(text, url)
      else
         clicked = ig_markdown(text, url)
      endif
      call ig_cursor_screen_pos(x, y)
      state(3:4, fr, side) = [x, y]
      if (clicked) then
         state(5, fr, side) = state(5, fr, side) + 1.0_real64
         urls(side) = url
      endif
   endif
   call ig_end()
   if (k < 0_int32) continue
   endsubroutine draw_case

   subroutine act(k, fr)
   !< The scripted input of a case, queued at the end of a frame (applied over the next ones).
   integer(int32), intent(in) :: k, fr !< Case, frame.

   select case (k)
   case (8_int32, 9_int32, 10_int32)
      if (fr == 2_int32) call test_click(x0 + 20.0_real64, y0 + 8.0_real64)
   case (11_int32)
      if (fr == 2_int32) call test_mouse_move(x0 + 30.0_real64, y0 + 8.0_real64)
   case (12_int32)
      if (fr == 2_int32) then
         call test_click(x0 + 60.0_real64, y0 + 30.0_real64)
         call test_click(x0 + 60.0_real64, y0 + 30.0_real64)
      endif
      if (fr == 20_int32) call test_drag(x0 + 30.0_real64, y0 + 8.0_real64, x0 + 200.0_real64, y0 + 50.0_real64)
   case (13_int32)
      if (fr == 2_int32) call test_drag(x0 + 10.0_real64, y0 + 8.0_real64, x0 + 150.0_real64, y0 + 30.0_real64)
      if (fr == 20_int32) call test_click(x0 + 100.0_real64, y0 + 30.0_real64, button='right')
   endselect
   endsubroutine act

   function case_text(k) result(t)
   !< A case's Markdown.
   integer(int32), intent(in)    :: k !< Case.
   character(len=:), allocatable :: t !< Markdown.
   integer(int32)                :: j !< Counter.

   select case (k)
   case (1_int32)
      t = '# Heading one'//LF//LF//'Text below the first heading, long enough to wrap: the solver reads an *input file* '// &
          'of **key = value** lines, ***both*** at once, with `code spans`, ~~struck~~ and _underlined_ words, and '// &
          'a word glued across the markup (**alignment**), which goes whole to the next line.'//LF//LF// &
          '## Heading two'//LF//'A soft'//LF//'break, then a hard one  '//LF//'here.'//LF//LF// &
          '### Three'//LF//LF//'#### Four'//LF//LF//'##### Five'//LF//LF//'###### Six'//LF//LF//'Last line.'
   case (2_int32)
      t = '* star one'//LF//'* star two'//LF//'  * nested star'//LF//'    1. nested number'//LF//LF// &
          '- dash'//LF//'- dash two'//LF//LF//'+ plus'//LF//LF//'1. first'//LF//'2. second'//LF//LF// &
          '3) three'//LF//'4) four'//LF//LF//'- [x] done task'//LF//'- [ ] open task'//LF//LF// &
          '* loose item'//LF//LF//'  its second paragraph'//LF//LF//'* another'
   case (3_int32)
      t = 'Before the code:'//LF//LF//'```fortran'//LF//'program p'//LF//'  print *, 1'//LF//'end program'//LF// &
          '```'//LF//LF//'* in a list:'//LF//LF//'  ```'//LF//'  x = 1'//LF//'  ```'//LF//LF// &
          '> a quote'//LF//'> > nested'//LF//LF//'---'//LF//LF//'> [!NOTE]'//LF//'> A note.'//LF//LF// &
          '> [!TIP] on the line'//LF//LF//'> [!IMPORTANT]'//LF//'> Important.'//LF//LF// &
          '> [!WARNING]'//LF//'> Careful.'//LF//LF//'> [!caution]'//LF//'> Danger.'//LF//LF//'***'
   case (4_int32)
      t = '| left | centre | right |'//LF//'|:---|:---:|---:|'//LF//'| a | b | c |'//LF// &
          '| **bold** | `code` | *it* |'//LF//'| longer text | x | 12345 |'//LF//LF// &
          '| quantity | value |'//LF//'|---|---|'//LF//'| Mach number | 0.3 |'//LF// &
          '| a cell long enough to wrap inside its column of the table | 1 |'
   case (5_int32)
      t = 'line<br>broken, <u>under</u>, H<sub>2</sub>O, x<sup>2</sup>, <kbd>Ctrl</kbd>, <mark>marked</mark>, '// &
          '<md-error title="why">error</md-error> &amp; &lt;tag&gt; a&nbsp;b'//LF//LF//'<hr>'//LF//LF// &
          '<details>'//LF//'<summary>Closed &amp; hidden</summary>'//LF//LF//'Hidden text.'//LF//LF// &
          '## Hidden heading'//LF//LF//'</details>'//LF//LF//'<details open>'//LF//'<summary>Open</summary>'//LF//LF// &
          'Shown text.'//LF//LF//'</details>'//LF//LF//'<pre>'//LF//'pre line 1'//LF//'  pre line 2'//LF//'</pre>'// &
          LF//LF//'<!-- a comment -->'//LF//LF//'<center>centred</center>'//LF//LF//'<div class="x">in a div</div>'// &
          LF//LF//'after <!-- inline comment --> it'
   case (6_int32)
      t = 'An image: ![file]('//IMAGE//') then text.'//LF//LF//'![wide]('//WIDE//')'//LF//LF// &
          '<img src="'//IMAGE//'" width="32">'//LF//LF//'![url](https://example.org/figure.png) after the URL.'// &
          LF//LF//'![missing](figure_test_markdown_frame.missing.png) after the missing one.'//LF//LF// &
          '[![linked]('//IMAGE//')](https://example.org/image)'
   case (7_int32)
      t = '# Solver help'//LF//LF// &
          'The solver reads an **input file** of *key = value* lines; see [the manual](https://example.org).'// &
          LF//LF//'## Keys'//LF//LF// &
          '* `reynolds number`: positive'//LF// &
          '* `mach number`: below 0.3 for '//RHO//' constant, '//NABLA//'p small'//LF//LF// &
          '| key | default |'//LF//'|---|---|'//LF//'| save frequency | 100 |'//LF//'| cfl | 0.8 |'//LF//LF// &
          '> [!NOTE]'//LF//'> Keys are case-insensitive.'//LF//LF// &
          '```'//LF//'reynolds number = 1e6'//LF//'```'
   case (8_int32)
      t = '[the manual](https://example.org/manual) of the solver'
   case (9_int32)
      t = '[below](#the-end)'//LF//LF
      do j = 1_int32, 20_int32
         t = t//'A paragraph to fill the window, long enough to be seen.'//LF//LF
      enddo
      t = t//'## The end'//LF//LF//'last'
   case (10_int32)
      t = '[nowhere](#no-such-heading)'
   case (11_int32)
      t = 'See [the manual](https://example.org/manual) for more.'
   case default
      t = 'Select a word in this text: the solver reads an input file, line by line, and reports.'//LF//LF// &
          'A second paragraph, with [a link](https://example.org) in it.'
   endselect
   endfunction case_text

   subroutine write_images()
   !< The pictures of case 6: a gradient of 64 x 40 pixels, one of 900 x 30.
   integer(int8), allocatable, target :: p(:,:,:) !< Pixels.
   integer(c_int)                     :: st       !< Status.
   integer(int32)                     :: i, j     !< Pixel.

   allocate(p(4, 64, 40))
   do j = 1_int32, 40_int32
      do i = 1_int32, 64_int32
         p(:, i, j) = [int(mod(i * 4, 256) - merge(256, 0, mod(i * 4, 256) > 127), int8), &
                       int(mod(j * 6, 256) - merge(256, 0, mod(j * 6, 256) > 127), int8), 64_int8, -1_int8]
      enddo
   enddo
   st = fig_image_write(IMAGE, len(IMAGE, c_int), c_loc(p), 4_c_int, 64_c_int, 40_c_int, 0_c_int)
   if (st /= FIG_OK) error stop 'figure_test_markdown_frame: cannot write the image'
   deallocate(p)
   allocate(p(4, 900, 30))
   do j = 1_int32, 30_int32
      do i = 1_int32, 900_int32
         p(:, i, j) = [int(mod(i, 128), int8), int(mod(j * 8, 128), int8), int(mod(i + j, 128), int8), -1_int8]
      enddo
   enddo
   st = fig_image_write(WIDE, len(WIDE, c_int), c_loc(p), 4_c_int, 900_c_int, 30_c_int, 0_c_int)
   if (st /= FIG_OK) error stop 'figure_test_markdown_frame: cannot write the wide image'
   endsubroutine write_images

   function state_equal(k) result(ok)
   !< A case's state on every frame equal on both sides, to the bit, and the same URL reported.
   integer(int32), intent(in) :: k  !< Case.
   logical                    :: ok !< Equal.
   integer(int32)             :: fr !< Frame.

   ok = .true.
   do fr = 1_int32, nframes(k)
      if (any(state(:, fr, 1) /= state(:, fr, 2))) then
         ok = .false.
         write(output_unit, '(A,I0,A,I0,A,5(1X,G0),A,5(1X,G0))') 'case ', k, ', frame ', fr, ': imgui_rich_md', &
                                                                 state(:, fr, 1), '; Fortran', state(:, fr, 2)
         exit
      endif
   enddo
   if (trim(urls(1)) /= trim(urls(2))) then
      ok = .false.
      write(output_unit, '(A,I0,A)') 'case ', k, ': URLs "'//trim(urls(1))//'" and "'//trim(urls(2))//'"'
   endif
   endfunction state_equal

   function pictures_equal(k, n) result(ok)
   !< A case's n-th pictures (1: the last frame's, 2: the first's) of both sides equal at the oracle's rule.
   integer(int32), intent(in) :: k   !< Case.
   integer(int32), intent(in) :: n   !< Picture.
   logical                    :: ok  !< Equal.
   integer(int64)             :: nf_ !< Pixels that failed.
   integer(int32)             :: st  !< Status.

   ok = test_compare_image(picture(k, n, .true.), picture(k, n, .false.), threshold=2_int32, max_failed=0_int32, &
                           failed=nf_, stat=st)
   if (.not. ok) write(output_unit, '(A,I0,A,I0,A,I0,A,A)') 'case ', k, ', picture ', n, ': ', nf_, ' pixels failed: ', &
                                                            figure_last_error()
   endfunction pictures_equal

   function picture(k, n, fortran) result(name)
   !< A case's n-th picture: imgui_rich_md's or the Fortran renderer's.
   integer(int32), intent(in)    :: k, n    !< Case, picture.
   logical,        intent(in)    :: fortran !< The Fortran renderer's.
   character(len=:), allocatable :: name    !< File name.
   character(len=16)             :: tag     !< The case's and picture's numbers.

   write(tag, '(I0,A,I0)') k, '.', n
   if (fortran) then
      name = 'figure_test_markdown_frame.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_markdown_frame.'//trim(tag)//'.rich_md.png.tmp'
   endif
   endfunction picture

   subroutine remove_files()
   !< The pictures (a mismatch's .new.png and .diff.png are left for inspection).
   integer(int32) :: unit, ios, k, n, m !< Unit, status, counters.

   do k = 1_int32, NCASE
      do n = 1_int32, 2_int32
         do m = 1_int32, 2_int32
            open(newunit=unit, file=picture(k, n, m == 1_int32), status='old', iostat=ios)
            if (ios == 0) close(unit, status='delete')
         enddo
      enddo
   enddo
   open(newunit=unit, file=IMAGE, status='old', iostat=ios)
   if (ios == 0) close(unit, status='delete')
   open(newunit=unit, file=WIDE, status='old', iostat=ios)
   if (ios == 0) close(unit, status='delete')
   endsubroutine remove_files
endprogram figure_test_markdown_frame
