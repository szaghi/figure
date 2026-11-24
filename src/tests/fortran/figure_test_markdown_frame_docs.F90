!< figure_test_markdown_frame_docs, the Fortran path's Markdown documents (`md_view_*`) against imgui_rich_md's.
program figure_test_markdown_frame_docs
!< figure_test_markdown_frame_docs, the Fortran path's Markdown documents (`md_view_*`) against imgui_rich_md's.
!<
!< szaghi/figure#15 P15. Each case draws one document on a few frames first with imgui_rich_md (FIGURE's
!< `markdown_view_object` on the current path), then with the Fortran documents (figure_markdown_document's views), 40
!< frames apart, each in a window of its own at the same place (`Help###cpp`, `Help###fortran`). Checked on every frame:
!< the cursor before and after the document, a link clicked and its URL, the matches of the search and the current
!< one, equal to the bit; the first and the last frame's pictures at FIGURE's oracle rule (|d| <= 2, no pixel failing).
!< The program's calls and the scripted input happen on the same frames after each side's start. The cases:
!<
!< 1. a page of four sections in a wide window: the table of contents beside it;
!< 2. the same page narrow: the line above the content (the current section as a menu, the magnifier);
!< 3. `find('pressure')`: three matches highlighted, the first current, the ticks on the scrollbar; then `find('')`;
!< 4. `scroll_to('Last section')` (eased over 0.3 s), then `scroll_to('#help')`, then a heading the text lacks: no
!<    link reported;
!< 5. a click on an entry of the table of contents (the view scrolls there);
!< 6. ctrl+f, `pressure` typed, enter twice (the next matches), escape (the bar closes, the match selected);
!< 7. links: one to a heading of the page (scrolled to, not reported), one to a site (reported);
!< 8. a page with a collapsed section and a code block, searched: their matches at the section's header and in the
!<    code, the section opened by a step to its match;
!< 9. the mouse on a tick of the scrollbar (the matches' tooltip), and a click on it (their list).
!<
!< The pictures are `figure_test_markdown_frame_docs.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_c_binding, only : c_float, c_int
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_cursor_screen_pos, ig_end, ig_set_next_window
use figure_markdown_ref, only : markdown_view_object
use figure_markdown_document, only : md_view_create, md_view_destroy, md_view_draw, md_view_find, md_view_info, &
                                     md_view_scroll_to, md_view_set_text
use figure_markdown_render, only : md_last_link
use figure_testing, only : test_capture, test_click, test_compare_image, test_key, test_mouse_move, test_type

implicit none
integer(int32),   parameter :: W = 800_int32        !< Display width [pixels].
integer(int32),   parameter :: H = 480_int32        !< Display height [pixels].
integer(int32),   parameter :: NCASE = 9_int32      !< Cases.
integer(int32),   parameter :: NFMAX = 120_int32    !< Frames per side of a case at most.
integer(int32),   parameter :: NSTATE = 7_int32     !< Values checked per frame.
character(len=*), parameter :: LF = achar(10)       !< Line feed.
type(app_object)              :: app                 !< Application.
type(markdown_view_object)    :: view                !< The current path's view.
integer(c_int)                :: handle              !< The Fortran view.
real(real64)                  :: state(NSTATE, NFMAX, 2) !< Per frame and side.
character(len=256)            :: urls(2)             !< The URL reported per side.
logical                       :: test_passed(NCASE)  !< Per-case outcome.
real(real64)                  :: x0, y0              !< Where the document starts (the first frame's).
integer(int32)                :: c, f, s, sd, i      !< Case, frame, status, side, counter.
character(len=16)             :: keep                !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do c = 1_int32, NCASE
   state = 0.0_real64
   urls = ''
   do sd = 1_int32, 2_int32 ! 1 imgui_rich_md, 2 the Fortran documents
      call view%init()
      call view%set_text(case_text(c))
      call md_view_create(.true., .true., handle)
      call md_view_set_text(handle, case_text(c))
      do f = 1_int32, nframes(c)
         call program_calls(c, f, sd)
         if (.not. app%next_frame()) error stop 'figure_test_markdown_frame_docs: next_frame returned false headless'
         call draw_case(c, f, sd)
         if (f == nframes(c)) call test_capture(picture(c, 1_int32, sd == 2_int32), s)
         if (f == 1_int32) then
            call test_capture(picture(c, 2_int32, sd == 2_int32), s)
            x0 = state(1, 1, sd)
            y0 = state(2, 1, sd)
         endif
         call act(c, f)
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      do i = 1_int32, 40_int32 ! the sides apart
         if (.not. app%next_frame()) error stop 'figure_test_markdown_frame_docs: next_frame returned false headless'
      enddo
      call view%destroy()
      call md_view_destroy(handle)
   enddo
   test_passed(c) = state_equal(c) .and. pictures_equal(c, 1_int32)
   test_passed(c) = pictures_equal(c, 2_int32) .and. test_passed(c)
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_markdown_frame_docs checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   pure function nframes(k) result(n)
   !< A case's frames per side.
   integer(int32), intent(in) :: k !< Case.
   integer(int32)             :: n !< Frames.

   select case (k)
   case (1_int32, 2_int32)
      n = 6_int32
   case (4_int32)
      n = NFMAX
   case default
      n = 70_int32
   case (9_int32)
      n = 58_int32
   endselect
   endfunction nframes

   function wide(k) result(yes)
   !< A case drawn in the wide window (else the narrow one).
   integer(int32), intent(in) :: k   !< Case.
   logical                    :: yes !< Wide.

   yes = k /= 2_int32
   endfunction wide

   subroutine program_calls(k, fr, side)
   !< The program's calls on the view, before a frame.
   integer(int32), intent(in) :: k, fr, side !< Case, frame, side.

   select case (k)
   case (3_int32)
      if (fr == 4_int32) call find(side, 'pressure')
      if (fr == 50_int32) call find(side, '')
   case (4_int32)
      if (fr == 4_int32) call scroll(side, 'Last section')
      if (fr == 50_int32) call scroll(side, '#help')
      if (fr == 90_int32) call scroll(side, 'No such heading')
   case (8_int32)
      if (fr == 4_int32) call find(side, 'secret')
   case (9_int32)
      if (fr == 4_int32) call find(side, 'pressure')
   endselect
   endsubroutine program_calls

   subroutine find(side, q)
   !< A search, by the side's API.
   integer(int32),   intent(in) :: side !< Side.
   character(len=*), intent(in) :: q    !< Query.

   if (side == 1_int32) then
      call view%find(q)
   else
      call md_view_find(handle, q)
   endif
   endsubroutine find

   subroutine scroll(side, heading)
   !< A scroll to a heading, by the side's API.
   integer(int32),   intent(in) :: side    !< Side.
   character(len=*), intent(in) :: heading !< Heading.

   if (side == 1_int32) then
      call view%scroll_to(heading)
   else
      call md_view_scroll_to(handle, heading)
   endif
   endsubroutine scroll

   subroutine draw_case(k, fr, side)
   !< A case's document on a frame, by the side drawing; the state recorded.
   integer(int32), intent(in)    :: k, fr, side !< Case, frame, side.
   character(len=:), allocatable :: url         !< A link clicked.
   logical                       :: clicked     !< ... this frame.
   real(real64)                  :: x, y, ww    !< Cursor, width.
   integer(c_int)                :: m, cur, st  !< Matches, current, status.

   ww = merge(760.0_real64, 340.0_real64, wide(k))
   call ig_set_next_window(10.0_real64, 10.0_real64, ww, 460.0_real64, always=.true.)
   if (ig_begin(trim(merge('Help###fortran', 'Help###cpp    ', side == 2_int32)))) then
      call ig_cursor_screen_pos(x, y)
      state(1:2, fr, side) = [x, y]
      if (side == 2_int32) then
         st = md_view_draw(handle, 'doc', 0.0_c_float, -30.0_c_float, clicked)
         if (clicked) url = md_last_link()
         call md_view_info(handle, m, cur)
         state(6:7, fr, side) = [real(m, real64), real(cur + 1_c_int, real64)]
      else
         clicked = view%draw('doc', url, height=-30.0_real64)
         state(6:7, fr, side) = [real(view%matches(), real64), real(view%current_match(), real64)]
      endif
      call ig_cursor_screen_pos(x, y)
      state(3:4, fr, side) = [x, y]
      if (clicked) then
         state(5, fr, side) = state(5, fr, side) + 1.0_real64
         urls(side) = url
      endif
   endif
   call ig_end()
   if (fr < 0_int32) continue
   endsubroutine draw_case

   subroutine act(k, fr)
   !< The scripted input of a case, queued at the end of a frame (applied over the next ones).
   integer(int32), intent(in) :: k, fr !< Case, frame.

   select case (k)
   case (5_int32)
      if (fr == 4_int32) call test_click(x0 + 60.0_real64, y0 + 82.0_real64) ! an entry of the table of contents
   case (6_int32)
      if (fr == 4_int32) call test_mouse_move(x0 + 500.0_real64, y0 + 200.0_real64)
      if (fr == 8_int32) then
         call test_click(x0 + 500.0_real64, y0 + 200.0_real64) ! the content focused
      endif
      if (fr == 16_int32) then
         call test_key('ctrl', .true.)
         call test_key('f')
         call test_key('ctrl', .false.)
      endif
      if (fr == 24_int32) call test_type('pressure')
      if (fr == 32_int32) call test_key('enter')
      if (fr == 40_int32) call test_key('enter')
      if (fr == 52_int32) call test_key('escape')
   case (7_int32)
      if (fr == 4_int32) call test_click(x0 + 270.0_real64, y0 + 52.0_real64)  ! [the units](#units)
      if (fr == 40_int32) call test_click(x0 + 270.0_real64, y0 + 74.0_real64) ! [the site](https://example.org)
   case (8_int32)
      if (fr == 30_int32) then
         call test_key('enter')
      endif
   case (9_int32)
      if (fr == 20_int32) call test_mouse_move(x0 + 735.0_real64, y0 + 41.0_real64)
      if (fr == 50_int32) call test_click(x0 + 735.0_real64, y0 + 41.0_real64)
   endselect
   endsubroutine act

   function case_text(k) result(t)
   !< A case's Markdown.
   integer(int32), intent(in)    :: k !< Case.
   character(len=:), allocatable :: t !< Markdown.
   integer(int32)                :: j !< Counter.

   select case (k)
   case (7_int32)
      t = '# Help'//LF//LF//'Read [the units](#units) first; see [the site](https://example.org) for more.'//LF//LF
      do j = 1_int32, 14_int32
         t = t//'A paragraph about the solver, long enough to fill the view of the page.'//LF//LF
      enddo
      t = t//'## Units'//LF//LF//'SI units throughout.'//LF
   case (8_int32)
      t = '# Notes'//LF//LF//'<details>'//LF//'<summary>Hidden part</summary>'//LF//LF// &
          'A secret paragraph.'//LF//LF//'</details>'//LF//LF//'```'//LF//'secret = 1'//LF//'```'//LF//LF// &
          '## More'//LF//LF//'The last secret.'//LF
   case default
      t = '# Help'//LF//LF//'## Introduction'//LF//LF//'The pressure is in pascal.'//LF//LF
      do j = 1_int32, 12_int32
         t = t//'A paragraph of the introduction, long enough to fill the view.'//LF//LF
      enddo
      t = t//'## Boundary conditions'//LF//LF//'An outlet has a pressure, an inlet a velocity.'//LF//LF
      do j = 1_int32, 12_int32
         t = t//'A paragraph about boundaries, long enough to fill the view.'//LF//LF
      enddo
      t = t//'## Last section'//LF//LF//'The reference pressure is 101325 Pa.'//LF
   endselect
   endfunction case_text

   function state_equal(k) result(ok)
   !< A case's state on every frame equal on both sides, to the bit, and the same URL reported.
   integer(int32), intent(in) :: k  !< Case.
   logical                    :: ok !< Equal.
   integer(int32)             :: fr !< Frame.

   ok = .true.
   do fr = 1_int32, nframes(k)
      if (any(state(:, fr, 1) /= state(:, fr, 2))) then
         ok = .false.
         write(output_unit, '(A,I0,A,I0,A,7(1X,G0),A,7(1X,G0))') 'case ', k, ', frame ', fr, ': imgui_rich_md', &
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
   integer(int32), intent(in) :: k, n !< Case, picture.
   logical                    :: ok   !< Equal.
   integer(int64)             :: nf_  !< Pixels that failed.
   integer(int32)             :: st   !< Status.

   ok = test_compare_image(picture(k, n, .true.), picture(k, n, .false.), threshold=2_int32, max_failed=0_int32, &
                           failed=nf_, stat=st)
   if (.not. ok) write(output_unit, '(A,I0,A,I0,A,I0,A,A)') 'case ', k, ', picture ', n, ': ', nf_, ' pixels failed: ', &
                                                            figure_last_error()
   endfunction pictures_equal

   function picture(k, n, fortran) result(name)
   !< A case's n-th picture: imgui_rich_md's or the Fortran documents'.
   integer(int32), intent(in)    :: k, n    !< Case, picture.
   logical,        intent(in)    :: fortran !< The Fortran documents'.
   character(len=:), allocatable :: name    !< File name.
   character(len=16)             :: tag     !< The case's and picture's numbers.

   write(tag, '(I0,A,I0)') k, '.', n
   if (fortran) then
      name = 'figure_test_markdown_frame_docs.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_markdown_frame_docs.'//trim(tag)//'.rich_md.png.tmp'
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
   endsubroutine remove_files
endprogram figure_test_markdown_frame_docs
