!< figure_test_table_layout, a table's columns resized and reordered by the pointer, against a golden, headless.
program figure_test_table_layout
!< figure_test_table_layout, a table's columns resized and reordered by the pointer, against a golden, headless.
!<
!< A table of four fixed columns of 120 pixels ('alpha', 'beta', 'gamma', 'delta'), resizable and reorderable, with a
!< headers row and six rows; each cell's text placed where its column is (`ig_table_set_column`, by the order the
!< columns were declared), its left edge read every frame:
!< 1. resize: the border between 'alpha' and 'beta' dragged 40 pixels to the right in the body: 'alpha' is 40 pixels
!<    wider (the next column starts 40 pixels further right), the other widths kept;
!< 2. reorder: the header 'alpha' dragged across 'beta' and 'gamma' frame by frame and released: the display order is
!<    'beta', 'gamma', 'alpha', 'delta' (the columns' cells moved, not their content: 'alpha' keeps its width);
!< then the window against the golden src/tests/data/figure_test_table_layout.golden.png (|d| <= 2).
!< The picture is `figure_test_table_layout.shot.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps it).
! oracle: drag table-resize:picture table-reorder:picture
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_begin_table, ig_end, ig_end_table, ig_item_rect, &
                   ig_set_next_window, ig_table_headers_row, ig_table_next_row, ig_table_set_column,             &
                   ig_table_setup_column, ig_text, ImGuiWindowFlags_NoDecoration, FIG_OK
use figure_testing, only : test_capture, test_compare_image, test_drag, test_mouse_button, test_mouse_move, &
                           test_next_frame

implicit none
character(len=*), parameter :: GOLDEN = 'src/tests/data/figure_test_table_layout.golden.png' !< The committed reference.
character(len=*), parameter :: SHOT = 'figure_test_table_layout.shot.png.tmp'               !< The window.
character(len=5), parameter :: NAMES(4) = ['alpha', 'beta ', 'gamma', 'delta']               !< The columns.
integer(int32),   parameter :: W = 640_int32                                                 !< Display width.
integer(int32),   parameter :: H = 300_int32                                                 !< Display height.
real(real64),     parameter :: COL_W = 120.0_real64                                          !< Columns' width.
type(app_object)            :: app             !< Application.
logical                     :: test_passed(3)  !< Per-check outcome.
real(real64)                :: cell(4)         !< Left edge of each column's cell in row 1, this frame [pixels].
real(real64)                :: row_y(2)        !< Centres of rows 1 and 2, this frame [pixels].
real(real64)                :: before(4)       !< `cell` before a drag.
real(real64)                :: resized(4)      !< ... after the resize.
real(real64)                :: header_y        !< Centre of the headers row [pixels].
real(real64)                :: grab(2)         !< A point the pointer presses [pixels].
integer(int64)              :: nf              !< Pixels that failed.
integer(int32)              :: s               !< Status.
integer(int32)              :: k               !< Counter.
character(len=16)           :: keep            !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call run(3_int32)
! 1. resize: the border right of 'alpha', grabbed in row 2, dragged 40 pixels right
before = cell
grab = [cell(2) - 4.0_real64, row_y(2)]
call test_drag(grab(1), grab(2), grab(1) + 40.0_real64, grab(2))
call run(8_int32)
resized = cell
test_passed(1) = abs((resized(2) - resized(1)) - (before(2) - before(1)) - 40.0_real64) < 1.0_real64 .and. &
                 abs((resized(3) - resized(2)) - (before(3) - before(2))) < 0.5_real64 .and.             &
                 abs((resized(4) - resized(3)) - (before(4) - before(3))) < 0.5_real64
if (.not. test_passed(1)) write(output_unit, '(A,8F9.2)') 'resize: ', before, resized
! 2. reorder: the header 'alpha' pressed and moved right in steps past 'gamma', then released
header_y = row_y(1) - (row_y(2) - row_y(1))
grab = [cell(1) + 20.0_real64, header_y]
call test_mouse_move(grab(1), grab(2))
call test_next_frame()
call test_next_frame()
call test_mouse_button(.true.)
call test_next_frame()
do k = 1_int32, 16_int32
   call test_mouse_move(grab(1) + 20.0_real64 * k, grab(2))
   call test_next_frame()
   call test_next_frame()
enddo
call test_mouse_button(.false.)
call run(45_int32)
test_passed(2) = cell(2) < cell(3) .and. cell(3) < cell(1) .and. cell(1) < cell(4)
if (test_passed(2)) test_passed(2) = abs((cell(4) - cell(1)) - (resized(2) - resized(1))) < 1.0_real64
if (.not. test_passed(2)) write(output_unit, '(A,4F9.2)') 'reorder: ', cell
! the picture, the pointer away
call test_mouse_move(real(W, real64) - 4.0_real64, real(H, real64) - 4.0_real64)
call run(4_int32)
s = -1_int32
call run(1_int32, shot=SHOT, stat=s)
call run(1_int32)
test_passed(3) = s == FIG_OK
if (test_passed(3)) test_passed(3) = test_compare_image(SHOT, GOLDEN, failed=nf, stat=s)
if (.not. test_passed(3)) write(output_unit, '(A,I0,A,I0,A,A)') 'golden: status ', s, ', ', nf, ' failed: ', &
                                                               figure_last_error()
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_shot()

write(output_unit, '(A,*(L2))') 'figure_test_table_layout checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine run(n, shot, stat)
   !< `n` frames of the table; the last captured to `shot`.
   integer(int32),   intent(in)            :: n    !< Frames.
   character(len=*), intent(in),  optional :: shot !< Capture of the last.
   integer(int32),   intent(out), optional :: stat !< Status of the capture.
   integer(int32)                          :: f    !< Frame.
   integer(int32)                          :: i, j !< Row, column.
   real(real64)                            :: r(4) !< An item's rectangle.

   do f = 1_int32, n
      if (.not. app%next_frame()) error stop 'figure_test_table_layout: next_frame returned false in headless mode'
      call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
      if (ig_begin('tables', flags=ImGuiWindowFlags_NoDecoration)) then
         if (ig_begin_table('grid', 4_int32, reorderable=.true.)) then
            do j = 1_int32, 4_int32
               call ig_table_setup_column(trim(NAMES(j)), width=COL_W)
            enddo
            call ig_table_headers_row()
            do i = 1_int32, 6_int32
               call ig_table_next_row()
               do j = 1_int32, 4_int32
                  call ig_table_set_column(j)
                  call ig_text(trim(NAMES(j))//' '//achar(48 + i))
                  if (i <= 2_int32) then
                     call ig_item_rect(r(1), r(2), r(3), r(4))
                     if (i == 1_int32) cell(j) = r(1)
                     if (j == 1_int32) row_y(i) = 0.5_real64 * (r(2) + r(4))
                  endif
               enddo
            enddo
            call ig_end_table()
         endif
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
endprogram figure_test_table_layout
