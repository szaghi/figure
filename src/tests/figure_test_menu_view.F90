!< figure_test_menu_view, a window's menu bar and a message box driven by the pointer and the keys, against goldens,
!< headless.
program figure_test_menu_view
!< figure_test_menu_view, a window's menu bar and a message box driven by the pointer and the keys, against goldens,
!< headless.
!<
!< 1. A window with its own menu bar (`ig_begin_menu_bar`): a click on 'File' opens the menu (`ig_begin_menu` true on
!<    the next frames, not before); the pointer resting on 'Save' highlights it; the window with the open menu against
!<    the golden src/tests/data/figure_test_menu_view.menu.golden.png (|d| <= 2); a click on the check item 'Autosave'
!<    toggles it and closes the menu; the disabled item 'Quit' cannot be picked.
!< 2. A message box of three buttons (`app%message_box`), asked every frame: 0 while open; the window with the box
!<    over it against the golden src/tests/data/figure_test_menu_view.box.golden.png; escape answers the last button,
!<    and asked again, enter the first.
!< The pictures are `figure_test_menu_view.*.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
! oracle: click keys menus:picture modals:picture
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_begin_menu, ig_begin_menu_bar, ig_end, ig_end_menu, &
                   ig_end_menu_bar, ig_item_rect, ig_menu_item, ig_set_next_window, ig_text,                      &
                   ImGuiWindowFlags_MenuBar, ImGuiWindowFlags_NoDecoration, FIG_OK
use figure_testing, only : test_capture, test_click, test_compare_image, test_key, test_mouse_move

implicit none
character(len=*), parameter :: MENU_GOLDEN = 'src/tests/data/figure_test_menu_view.menu.golden.png' !< The open menu.
character(len=*), parameter :: BOX_GOLDEN = 'src/tests/data/figure_test_menu_view.box.golden.png'   !< The box.
character(len=*), parameter :: MENU_SHOT = 'figure_test_menu_view.menu.png.tmp'                     !< ... captured.
character(len=*), parameter :: BOX_SHOT = 'figure_test_menu_view.box.png.tmp'                       !< ... captured.
integer(int32),   parameter :: W = 520_int32                                                        !< Display width.
integer(int32),   parameter :: H = 340_int32                                                        !< Display height.
type(app_object)            :: app            !< Application.
logical                     :: test_passed(7) !< Per-check outcome.
logical                     :: file_open      !< 'File' is open, this frame.
logical                     :: autosave       !< The check item.
logical                     :: quit_picked    !< The disabled item was picked (it must not be).
logical                     :: opened_early   !< 'File' was open before the click.
real(real64)                :: file_at(2)     !< Centre of 'File' in the menu bar [pixels].
real(real64)                :: item_at(2, 4)  !< Centres of the menu's items, while open [pixels].
logical                     :: ask            !< The box is asked this frame.
integer(int32)              :: answer         !< The box's answer, this frame.
integer(int32)              :: answers(3)     !< While open; after escape; after enter.
integer(int32)              :: s(2)           !< Statuses of the captures.
integer(int64)              :: nf             !< Pixels that failed.
character(len=16)           :: keep           !< FIGURE_TEST_KEEP.

autosave = .false.
quit_picked = .false.
ask = .false.
answers = -1_int32
s = -1_int32
call app%init_headless(W, H)
call run(3_int32)
opened_early = file_open
! 1. the menu
call test_click(file_at(1), file_at(2))
call run(8_int32)
test_passed(1) = file_open .and. .not. opened_early
call test_mouse_move(item_at(1, 2), item_at(2, 2))                ! rest on 'Save'
call run(4_int32)
call run(1_int32, MENU_SHOT, s(1))
call run(1_int32)
test_passed(2) = s(1) == FIG_OK
if (test_passed(2)) test_passed(2) = test_compare_image(MENU_SHOT, MENU_GOLDEN, failed=nf, stat=s(1))
if (.not. test_passed(2)) write(output_unit, '(A,I0,A,I0,A,A)') 'menu golden: status ', s(1), ', ', nf, &
                                                                ' failed: ', figure_last_error()
call test_click(item_at(1, 4), item_at(2, 4))                     ! 'Quit', disabled: nothing
call run(8_int32)
call test_click(item_at(1, 3), item_at(2, 3))                     ! 'Autosave'
call run(8_int32)
test_passed(3) = autosave .and. .not. file_open .and. .not. quit_picked
if (.not. all(test_passed(1:3))) write(output_unit, '(A,5L2)') 'menu: ', opened_early, test_passed(1), autosave, &
                                                               file_open, quit_picked
! 2. the message box
ask = .true.
call run(6_int32)
answers(1) = answer
call test_mouse_move(real(W, real64) - 4.0_real64, real(H, real64) - 4.0_real64)
call run(3_int32)
call run(1_int32, BOX_SHOT, s(2))
call run(1_int32)
test_passed(4) = s(2) == FIG_OK
if (test_passed(4)) test_passed(4) = test_compare_image(BOX_SHOT, BOX_GOLDEN, failed=nf, stat=s(2))
if (.not. test_passed(4)) write(output_unit, '(A,I0,A,I0,A,A)') 'box golden: status ', s(2), ', ', nf, &
                                                                ' failed: ', figure_last_error()
call test_key('escape')
call run_until_answer(answers(2))
ask = .true.
call run(4_int32)
call test_key('enter')
call run_until_answer(answers(3))
test_passed(5) = answers(1) == 0_int32
test_passed(6) = answers(2) == 3_int32
test_passed(7) = answers(3) == 1_int32
if (.not. all(test_passed(5:7))) write(output_unit, '(A,3I3)') 'box: ', answers
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_shots()

write(output_unit, '(A,*(L2))') 'figure_test_menu_view checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine run(n, shot, stat)
   !< `n` frames of the window (and of the box while asked); the last captured to `shot`.
   integer(int32),   intent(in)            :: n    !< Frames.
   character(len=*), intent(in),  optional :: shot !< Capture of the last.
   integer(int32),   intent(out), optional :: stat !< Status of the capture.
   integer(int32)                          :: f    !< Frame.

   do f = 1_int32, n
      call frame()
      if (f == n .and. present(shot)) call test_capture(shot, stat)
   enddo
   endsubroutine run

   subroutine run_until_answer(got)
   !< Frames until the box answers (at most 20): its answer, 0 if none.
   integer(int32), intent(out) :: got !< Answer.
   integer(int32)              :: f   !< Frame.

   got = 0_int32
   do f = 1_int32, 20_int32
      call frame()
      if (answer /= 0_int32) then
         got = answer
         ask = .false.
         exit
      endif
   enddo
   call run(2_int32)
   endsubroutine run_until_answer

   subroutine frame()
   !< One frame: the window, its menu bar and the open menu; the box while asked.
   real(real64) :: r(4) !< An item's rectangle.

   if (.not. app%next_frame()) error stop 'figure_test_menu_view: next_frame returned false in headless mode'
   file_open = .false.
   answer = -1_int32
   call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
   if (ig_begin('editor', flags=ior(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_MenuBar))) then
      if (ig_begin_menu_bar()) then
         if (ig_begin_menu('File')) then
            file_open = .true.
            call item(ig_menu_item('Open'), 1_int32)
            call item(ig_menu_item('Save', shortcut='Ctrl+S'), 2_int32)
            call item(ig_menu_item('Autosave', selected=autosave), 3_int32)
            call item(ig_menu_item('Quit', enabled=.false.), 4_int32)
            call ig_end_menu()
         endif
         call ig_item_rect(r(1), r(2), r(3), r(4))
         if (.not. file_open) file_at = [0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4))]
         if (ig_begin_menu('Edit')) call ig_end_menu()
         call ig_end_menu_bar()
      endif
      call ig_text('The case: a plate, 40 x 40 cells.')
      call ig_text('Autosave: '//merge('on ', 'off', autosave))
   endif
   call ig_end()
   if (ask) answer = app%message_box('ask', 'Save changes?', 'The case has unsaved changes.', &
                                     [character(len=7) :: 'Save', 'Discard', 'Cancel'])
   endsubroutine frame

   subroutine item(picked, k)
   !< The rectangle of the menu item just drawn, `k`; a pick of 'Quit' recorded.
   logical,        intent(in) :: picked !< The item was picked.
   integer(int32), intent(in) :: k      !< Item.
   real(real64)               :: r(4)   !< Its rectangle.

   call ig_item_rect(r(1), r(2), r(3), r(4))
   item_at(:, k) = [r(1) + 30.0_real64, 0.5_real64 * (r(2) + r(4))]
   if (picked .and. k == 4_int32) quit_picked = .true.
   endsubroutine item

   subroutine remove_shots()
   !< The captures.
   integer(int32) :: unit, ios !< Unit, status.

   open(newunit=unit, file=MENU_SHOT, status='old', iostat=ios)
   if (ios == 0) close(unit, status='delete')
   open(newunit=unit, file=BOX_SHOT, status='old', iostat=ios)
   if (ios == 0) close(unit, status='delete')
   endsubroutine remove_shots
endprogram figure_test_menu_view
