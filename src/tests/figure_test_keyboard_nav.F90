!< figure_test_keyboard_nav, keyboard navigation: the focus moved by the arrows and tab, items used by space and enter,
!< against a golden, headless.
program figure_test_keyboard_nav
!< figure_test_keyboard_nav, keyboard navigation: the focus moved by the arrows and tab, items used by space and enter,
!< against a golden, headless.
!<
!< A window of a check box, a button, a slider and two text fields, focused by the program (`ig_focus_window`), then
!< used with the keys only (FIGURE turns Dear ImGui's keyboard navigation on):
!< 1. the focus puts the navigation cursor on the first item, hidden: up shows it there, space toggles the check box;
!< 2. down moves to the button, enter presses it (once);
!< 3. down to the slider, space makes it active, the right arrow steps it up (the value grows), space again releases it;
!< 4. down to the first field, enter edits it, typed text goes in; tab moves to the second field, typed text goes there;
!< 5. enter leaves the field, its text kept; then the window against the golden
!<    src/tests/data/figure_test_keyboard_nav.golden.png (|d| <= 2): the values the keys set and the navigation cursor
!<    on the second field.
!< The picture is `figure_test_keyboard_nav.shot.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps it).
! oracle: text-typing keyboard-nav:picture
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_button, ig_checkbox, ig_end, ig_focus_window, &
                   ig_input_text, ig_set_next_window, ig_slider, ig_text, ImGuiWindowFlags_NoDecoration, FIG_OK
use figure_testing, only : test_capture, test_compare_image, test_key, test_type

implicit none
character(len=*), parameter :: GOLDEN = 'src/tests/data/figure_test_keyboard_nav.golden.png' !< The committed reference.
character(len=*), parameter :: SHOT = 'figure_test_keyboard_nav.shot.png.tmp'               !< The window.
integer(int32),   parameter :: W = 480_int32                                                 !< Display width.
integer(int32),   parameter :: H = 260_int32                                                 !< Display height.
type(app_object)            :: app            !< Application.
logical                     :: test_passed(6) !< Per-check outcome.
logical                     :: verbose        !< The check box.
integer(int32)              :: presses        !< Times the button was pressed.
real(real64)                :: relax          !< The slider.
real(real64)                :: relax0         !< ... before the arrow.
character(len=32)           :: first, second  !< The fields.
logical                     :: focus          !< Ask the window's focus this frame.
logical                     :: focused        !< ... granted.
integer(int64)              :: nf             !< Pixels that failed.
integer(int32)              :: s              !< Status.
character(len=16)           :: keep           !< FIGURE_TEST_KEEP.

verbose = .false.
presses = 0_int32
relax = 0.5_real64
first = ''
second = ''
focused = .false.
call app%init_headless(W, H)
call run(3_int32)
focus = .true.
call run(1_int32)
focus = .false.
call run(3_int32)
! 1. up shows the navigation cursor where the focus put it, on the first item; space toggles the check box
call key_and_run('up')
call key_and_run('space')
test_passed(1) = focused .and. verbose
! 2. the button pressed by enter
call key_and_run('down')
call key_and_run('enter')
test_passed(2) = presses == 1_int32
! 3. the slider stepped by the right arrow
call key_and_run('down')
relax0 = relax
call key_and_run('space')
call key_and_run('right')
call key_and_run('space')
test_passed(3) = relax > relax0
! 4. the first field edited by enter, the second reached by tab
call key_and_run('down')
call key_and_run('enter')
call test_type('typed by keys')
call run(3_int32)
call key_and_run('tab')
call test_type('after tab')
call run(3_int32)
test_passed(4) = trim(first) == 'typed by keys'
test_passed(5) = trim(second) == 'after tab'
if (.not. all(test_passed(1:5))) write(output_unit, '(A,2L2,I3,2F8.4,4A)') 'navigation: ', focused, verbose, &
   presses, relax0, relax, ' first=', trim(first), ' second=', trim(second)
! 5. enter keeps the second field's text, the picture
call key_and_run('enter')
test_passed(5) = test_passed(5) .and. trim(second) == 'after tab'
s = -1_int32
call run(1_int32, shot=SHOT, stat=s)
call run(1_int32)
test_passed(6) = s == FIG_OK
if (test_passed(6)) test_passed(6) = test_compare_image(SHOT, GOLDEN, failed=nf, stat=s)
if (.not. test_passed(6)) write(output_unit, '(A,I0,A,I0,A,A)') 'golden: status ', s, ', ', nf, ' failed: ', &
                                                               figure_last_error()
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_shot()

write(output_unit, '(A,*(L2))') 'figure_test_keyboard_nav checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine key_and_run(name)
   !< A key pressed and released, then frames for it to act.
   character(len=*), intent(in) :: name !< Key.

   call test_key(name)
   call run(4_int32)
   endsubroutine key_and_run

   subroutine run(n, shot, stat)
   !< `n` frames of the window; the last captured to `shot`.
   integer(int32),   intent(in)            :: n    !< Frames.
   character(len=*), intent(in),  optional :: shot !< Capture of the last.
   integer(int32),   intent(out), optional :: stat !< Status of the capture.
   integer(int32)                          :: f    !< Frame.

   do f = 1_int32, n
      if (.not. app%next_frame()) error stop 'figure_test_keyboard_nav: next_frame returned false in headless mode'
      call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
      if (ig_begin('form', flags=ImGuiWindowFlags_NoDecoration)) then
         call ig_text('Keyboard only')
         if (ig_checkbox('Verbose', verbose)) continue
         if (ig_button('Run')) presses = presses + 1_int32
         if (ig_slider('Relaxation', relax, 0.0_real64, 1.0_real64)) continue
         if (ig_input_text('First', first)) continue
         if (ig_input_text('Second', second)) continue
      endif
      call ig_end()
      if (focus) focused = ig_focus_window('form')
      if (f == n .and. present(shot)) call test_capture(shot, stat)
   enddo
   endsubroutine run

   subroutine remove_shot()
   !< The capture.
   integer(int32) :: unit, ios !< Unit, status.

   open(newunit=unit, file=SHOT, status='old', iostat=ios)
   if (ios == 0) close(unit, status='delete')
   endsubroutine remove_shot
endprogram figure_test_keyboard_nav
