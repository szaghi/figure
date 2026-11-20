!< figure_test_layout_view, layout helpers, a splitter, an image from a file, a log and a Markdown view, against a
!< golden, headless.
program figure_test_layout_view
!< figure_test_layout_view, layout helpers, a splitter, an image from a file, a log and a Markdown view, against a
!< golden, headless.
!<
!< One window, with a program's own fallback font added (`app%add_fallback_font`: it must change no glyph the bundled
!< fonts have, so the picture is the bundled fonts'):
!< 1. a label and a button of 90 pixels right-aligned on the same line (`ig_align_next`): the button ends at the
!<    content's right edge, as far from the window's right edge as the label starts from its left;
!< 2. `ig_new_line` after a text: the next line starts two lines below it, not one;
!< 3. two panes side by side with a splitter between them (`ig_splitter`), the splitter dragged 50 pixels right: the
!<    first pane 50 wider, the sum kept;
!< 4. an image loaded from a PNG file (`tex%load`), drawn at a quarter of its size: its size is the file's;
!< 5. a log view: three lines added, `msgs%clear` leaves none, two added again are kept and drawn;
!< 6. a Markdown view: `md%is_initialized` false before `md%init`, true after, its text drawn;
!< then the window against the golden src/tests/data/figure_test_layout_view.golden.png (|d| <= 2).
!< The picture is `figure_test_layout_view.shot.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps it).
! oracle: drag
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_align_next, ig_begin, ig_begin_child, ig_button, ig_end, &
                   ig_end_child, ig_image, ig_item_rect, ig_new_line, ig_same_line, ig_set_next_window,    &
                   ig_splitter, ig_text, log_view_object, markdown_view_object, texture_object,            &
                   ImGuiWindowFlags_NoDecoration, FIG_OK
use figure_testing, only : test_capture, test_compare_image, test_drag, test_mouse_move

implicit none
character(len=*), parameter :: GOLDEN = 'src/tests/data/figure_test_layout_view.golden.png' !< The committed reference.
character(len=*), parameter :: SHOT = 'figure_test_layout_view.shot.png.tmp'               !< The window.
character(len=*), parameter :: PICTURE = 'src/tests/data/figure_test_pixels.golden.png'     !< An image to load.
character(len=*), parameter :: FONT = 'third_party/fonts/IBMPlexMono-Regular.ttf'          !< A program's fallback.
integer(int32),   parameter :: W = 640_int32                                                 !< Display width.
integer(int32),   parameter :: H = 520_int32                                                 !< Display height.
type(app_object)            :: app             !< Application.
type(texture_object)        :: tex             !< The image.
type(log_view_object)       :: msgs            !< The log.
type(markdown_view_object)  :: md              !< The Markdown view.
logical                     :: test_passed(8)  !< Per-check outcome.
real(real64)                :: sizes(2)        !< The panes' widths [pixels].
real(real64)                :: before(2)       !< ... before the drag.
real(real64)                :: label_r(4)      !< The label's rectangle [pixels].
real(real64)                :: button_r(4)     !< The right-aligned button's.
real(real64)                :: line_y(2)       !< Tops of the text before `ig_new_line` and of the text after it.
real(real64)                :: text_h          !< ... the first one's height.
real(real64)                :: bar(2)          !< The splitter's centre [pixels].
real(real64)                :: r(4)            !< A rectangle.
logical                     :: md_init(2)      !< md%is_initialized: before init, after.
integer(int32)              :: counts(2)       !< Log lines: after clear, after two more.
integer(int32)              :: s(3)            !< Statuses: the font, the image, the capture.
integer(int64)              :: nf              !< Pixels that failed.
character(len=16)           :: keep            !< FIGURE_TEST_KEEP.

sizes = [250.0_real64, 350.0_real64]
s = -1_int32
call app%init_headless(W, H)
call app%add_fallback_font(FONT, stat=s(1))
call tex%load(PICTURE, stat=s(2))
md_init(1) = md%is_initialized()
call md%init(toc=.false., search=.false.)
md_init(2) = md%is_initialized()
call md%set_text('**Case** notes: the plate converges in *300* iterations.')
call msgs%add('first line')
call msgs%add('second line')
call msgs%add('third line')
call msgs%clear()
counts(1) = msgs%count()
call msgs%add('solver started')
call msgs%add('residual 1.0e-6 at iteration 300')
counts(2) = msgs%count()
call run(4_int32)
! the splitter dragged 50 pixels right
before = sizes
call test_drag(bar(1), bar(2), bar(1) + 50.0_real64, bar(2))
call run(10_int32)
test_passed(1) = s(1) == FIG_OK
test_passed(2) = abs(button_r(3) - (real(W, real64) - label_r(1))) < 1.0_real64
test_passed(3) = line_y(2) - line_y(1) > 1.9_real64 * text_h
test_passed(4) = abs(sizes(1) - before(1) - 50.0_real64) < 0.5_real64 .and. abs(sum(sizes) - sum(before)) < 1.0e-9_real64
test_passed(5) = s(2) == FIG_OK .and. tex%width() > 0_int32 .and. tex%height() > 0_int32
test_passed(6) = counts(1) == 0_int32 .and. counts(2) == 2_int32
test_passed(7) = .not. md_init(1) .and. md_init(2)
if (.not. all(test_passed(1:7))) write(output_unit, '(A,2I3,4F9.2,4F9.2,3F8.2,4F9.2,2I4,2L2)') 'layout: ', s(1:2), &
   label_r, button_r, line_y, text_h, before, sizes, counts, md_init
call test_mouse_move(real(W, real64) - 4.0_real64, real(H, real64) - 4.0_real64)
call run(4_int32)
call run(1_int32, shot=SHOT, stat=s(3))
call run(1_int32)
test_passed(8) = s(3) == FIG_OK
if (test_passed(8)) test_passed(8) = test_compare_image(SHOT, GOLDEN, failed=nf, stat=s(3))
if (.not. test_passed(8)) write(output_unit, '(A,I0,A,I0,A,A)') 'golden: status ', s(3), ', ', nf, ' failed: ', &
                                                               figure_last_error()
call md%destroy()
call tex%destroy()
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_shot()

write(output_unit, '(A,*(L2))') 'figure_test_layout_view checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine run(n, shot, stat)
   !< `n` frames of the window; the last captured to `shot`.
   integer(int32),   intent(in)            :: n    !< Frames.
   character(len=*), intent(in),  optional :: shot !< Capture of the last.
   integer(int32),   intent(out), optional :: stat !< Status of the capture.
   integer(int32)                          :: f    !< Frame.

   do f = 1_int32, n
      if (.not. app%next_frame()) error stop 'figure_test_layout_view: next_frame returned false in headless mode'
      call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
      if (ig_begin('layout', flags=ImGuiWindowFlags_NoDecoration)) then
         call ig_text('Solver settings')
         call ig_item_rect(label_r(1), label_r(2), label_r(3), label_r(4))
         call ig_same_line()
         call ig_align_next(90.0_real64, 'right')
         if (ig_button('Apply', width=90.0_real64)) continue
         call ig_item_rect(button_r(1), button_r(2), button_r(3), button_r(4))
         call ig_text('Fonts: Plex, with a fallback of the program''s own: ρ ∞ Ω.')
         call ig_item_rect(r(1), r(2), r(3), r(4))
         line_y(1) = r(2)
         text_h = r(4) - r(2)
         call ig_new_line()
         call ig_text('After an empty line.')
         call ig_item_rect(r(1), r(2), r(3), r(4))
         line_y(2) = r(2)
         if (ig_begin_child('panes', 0.0_real64, 90.0_real64)) then ! the splitter runs to the end of this region
            if (ig_begin_child('left', sizes(1), 0.0_real64, border=.true.)) call ig_text('Blocks')
            call ig_end_child()
            call ig_same_line()
            if (ig_splitter('bar', sizes)) continue
            call ig_item_rect(r(1), r(2), r(3), r(4))
            bar = [0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4))]
            call ig_same_line()
            if (ig_begin_child('right', sizes(2), 0.0_real64, border=.true.)) call ig_text('Fields')
            call ig_end_child()
         endif
         call ig_end_child()
         call ig_image(tex, 0.25_real64 * tex%width(), 0.25_real64 * tex%height())
         call msgs%draw('log', height=60.0_real64)
         if (md%draw('notes', height=40.0_real64)) continue
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
endprogram figure_test_layout_view
