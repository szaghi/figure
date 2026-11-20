!< figure_test_dock_view, docking driven by the pointer: tabs, a window docked and undocked, layouts switched, against
!< goldens, headless.
program figure_test_dock_view
!< figure_test_dock_view, docking driven by the pointer: tabs, a window docked and undocked, layouts switched, against
!< goldens, headless.
!<
!< A dock space over the display with two layouts (`app%add_layout`): 'Wide' (the left 35% 'Tree', the rest 'Mesh' and
!< 'Log' in one node, as tabs) and 'Stacked' (the top half 'Tree', the bottom 'Mesh' and 'Log'); 'Notes' floats.
!< 1. split and tabs: 'Tree' in one node, 'Mesh' and 'Log' together in the other, one of them shown; a click on the
!<    other's tab shows it and hides the first (`ig_begin` true for the shown one only);
!< 2. docked by the pointer: 'Notes' dragged by its title bar onto the centre of the 'Tree' node docks there, a tab
!<    beside 'Tree' (`ig_window_dock`: the node of 'Tree'); the dock space against the golden
!<    src/tests/data/figure_test_dock_view.tabs.golden.png (|d| <= 2);
!< 3. undocked by the pointer: the tab of 'Notes' dragged down out of the tab bar: 'Notes' floats again, 'Tree' alone
!<    in its node;
!< 4. docking off (`app%set_docking(.false.)`): 'Notes' dragged onto the same place stays floating; on again (the
!<    program does not call `ig_dock_layout_begin` while docking is off: it crashes there today, a finding of #15 P1);
!< 5. layouts: `app%switch_layout('Stacked')` lays the dock space out again: 'Tree' above 'Mesh'; the dock space
!<    against the golden src/tests/data/figure_test_dock_view.stacked.golden.png ('Notes' floating over it, as the
!<    undock left it, moved by the drag of step 4); `app%switch_layout('Wide')` and `app%reset_layout()` give back
!<    the first arrangement: 'Tree' left of 'Mesh'.
!< The pictures are `figure_test_dock_view.*.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
! oracle: click drag dock-split dock-tab:picture dock-in:picture dock-undock:picture dock-layout:picture
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_dock_id, ig_dock_layout_begin, ig_dock_layout_end, &
                   ig_dock_space, ig_dock_split, ig_dock_window, ig_end, ig_set_next_window, ig_text,             &
                   ig_window_dock, FIG_OK
use figure_testing, only : test_capture, test_click, test_compare_image, test_mouse_button, test_mouse_move, &
                           test_next_frame, test_window_rect

implicit none
character(len=*), parameter :: TABS_GOLDEN = 'src/tests/data/figure_test_dock_view.tabs.golden.png'       !< Tabs.
character(len=*), parameter :: STACKED_GOLDEN = 'src/tests/data/figure_test_dock_view.stacked.golden.png' !< Stacked.
character(len=*), parameter :: TABS_SHOT = 'figure_test_dock_view.tabs.png.tmp'                         !< ... captured.
character(len=*), parameter :: STACKED_SHOT = 'figure_test_dock_view.stacked.png.tmp'                   !< ... captured.
character(len=5), parameter :: NAMES(4) = ['Tree ', 'Mesh ', 'Log  ', 'Notes']                          !< The windows.
integer(int32),   parameter :: W = 640_int32                                                            !< Display width.
integer(int32),   parameter :: H = 420_int32                                                            !< Display height.
type(app_object)            :: app             !< Application.
logical                     :: test_passed(9)  !< Per-check outcome.
integer(int32)              :: root            !< The dock space.
integer(int32)              :: node(4)         !< The node each window is in, this frame (0: none).
logical                     :: docked(4)       !< Each window is docked, this frame.
logical                     :: shown(4)        !< `ig_begin` was true, this frame.
real(real64)                :: rect(4, 4)      !< Each window's rectangle, last frame [pixels].
integer(int32)              :: tree_node       !< The node 'Tree' was in, first.
logical                     :: first_shown(2)  !< 'Mesh', 'Log' shown at first.
integer(int32)              :: s(2)            !< Statuses of the captures.
integer(int64)              :: nf              !< Pixels that failed.
real(real64)                :: a(2), b(2)      !< Pointer positions [pixels].
integer(int32)              :: k               !< Counter.
integer(int32)              :: st              !< Status.
logical                     :: docking_on      !< Docking is on (`app%set_docking`).
integer(int32),   parameter :: GLIDE_FRAMES = 30_int32 !< Frames a glide's queued input takes (21), and some.
real(real64),     parameter :: TAB_Y = 10.0_real64     !< A tab's centre below its node's top (the frame height's half).
real(real64),     parameter :: LOG_TAB = 78.0_real64   !< The second tab's centre ('Log') right of its node's left edge,
                                                       !< past the node's menu button and the first tab (Plex Sans).
real(real64),     parameter :: NOTES_TAB = 77.0_real64 !< ... ('Notes', after 'Tree').
character(len=16)           :: keep            !< FIGURE_TEST_KEEP.

s = -1_int32
docking_on = .true.
call app%init_headless(W, H)
call app%add_layout('Wide')
call app%add_layout('Stacked')
call run(4_int32)
! 1. split and tabs: the other tab of the right node clicked
tree_node = node(1)
first_shown = shown(2:3)
test_passed(1) = docked(1) .and. docked(2) .and. shown(2) .and. .not. shown(3) .and. node(1) /= node(2) .and. &
                 .not. docked(4)
call test_click(rect(1, 2) + LOG_TAB, rect(2, 2) + TAB_Y)
call run(8_int32)
test_passed(2) = shown(3) .and. .not. shown(2) .and. docked(3) .and. node(3) /= node(1)
if (.not. all(test_passed(1:2))) call print_state('tabs')
! 2. 'Notes' dragged by its title bar onto the centre of the 'Tree' node
a = [rect(1, 4) + 60.0_real64, rect(2, 4) + TAB_Y]
b = [0.5_real64 * (rect(1, 1) + rect(3, 1)), 0.5_real64 * (rect(2, 1) + rect(4, 1))]
call glide(a, b, .true.)
call run(GLIDE_FRAMES)
test_passed(3) = docked(4) .and. node(4) == tree_node .and. shown(4) .and. .not. shown(1)
if (.not. test_passed(3)) call print_state('docked')
call test_mouse_move(real(W, real64) - 4.0_real64, real(H, real64) - 4.0_real64)
call run(4_int32)
call run(1_int32, TABS_SHOT, s(1))
call run(1_int32)
test_passed(4) = s(1) == FIG_OK
if (test_passed(4)) test_passed(4) = test_compare_image(TABS_SHOT, TABS_GOLDEN, failed=nf, stat=s(1))
if (.not. test_passed(4)) write(output_unit, '(A,I0,A,I0,A,A)') 'tabs golden: status ', s(1), ', ', nf, &
                                                                ' failed: ', figure_last_error()
! 3. the tab of 'Notes' dragged down out of the tab bar
a = [rect(1, 1) + NOTES_TAB, rect(2, 1) + TAB_Y]
call glide(a, [rect(1, 1) + 30.0_real64, rect(4, 1) - 40.0_real64], .true.) ! released far from every drop target
call run(GLIDE_FRAMES)
test_passed(5) = shown(4) .and. .not. docked(4) .and. shown(1) .and. docked(1)
if (.not. test_passed(5)) call print_state('undocked')
! 4. docking off: the same drag leaves 'Notes' floating
call app%set_docking(.false., stat=st)
docking_on = .false.
a = [rect(1, 4) + 60.0_real64, rect(2, 4) + TAB_Y]
call glide(a, b, .true.)
call run(GLIDE_FRAMES)
test_passed(6) = st == FIG_OK .and. shown(4) .and. .not. docked(4)
if (.not. test_passed(6)) call print_state('docking off')
call app%set_docking(.true.)
docking_on = .true.
! 5. layouts
call app%switch_layout('Stacked')
call run(6_int32)
test_passed(7) = rect(4, 1) <= rect(2, 2) + 1.0_real64 .and. rect(3, 1) > 0.9_real64 * W .and. docked(1)
if (.not. test_passed(7)) call print_state('stacked')
call test_mouse_move(real(W, real64) - 4.0_real64, real(H, real64) - 4.0_real64)
call run(2_int32)
call run(1_int32, STACKED_SHOT, s(2))
call run(1_int32)
test_passed(8) = s(2) == FIG_OK
if (test_passed(8)) test_passed(8) = test_compare_image(STACKED_SHOT, STACKED_GOLDEN, failed=nf, stat=s(2))
if (.not. test_passed(8)) write(output_unit, '(A,I0,A,I0,A,A)') 'stacked golden: status ', s(2), ', ', nf, &
                                                                ' failed: ', figure_last_error()
call app%switch_layout('Wide')
call app%reset_layout()
call run(6_int32)
test_passed(9) = rect(3, 1) <= rect(1, 2) + 1.0_real64 .and. rect(4, 1) > 0.9_real64 * H .and. docked(1)
if (.not. test_passed(9)) call print_state('wide again')
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_shots()

write(output_unit, '(A,*(L2))') 'figure_test_dock_view checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine glide(from, to, release)
   !< A press at `from`, the pointer moved to `to` in eight steps of two frames each, rested, and released.
   real(real64), intent(in) :: from(2) !< Start [pixels].
   real(real64), intent(in) :: to(2)   !< End [pixels].
   logical,      intent(in) :: release !< Release the button at the end.
   integer(int32)           :: i       !< Step.

   call test_mouse_move(from(1), from(2))
   call test_next_frame()
   call test_next_frame()
   call test_mouse_button(.true.)
   call test_next_frame()
   do i = 1_int32, 8_int32
      call test_mouse_move(from(1) + (to(1) - from(1)) * i / 8.0_real64, from(2) + (to(2) - from(2)) * i / 8.0_real64)
      call test_next_frame()
      call test_next_frame()
   enddo
   call test_next_frame()
   call test_next_frame()
   if (release) call test_mouse_button(.false.)
   endsubroutine glide

   subroutine remove_shots()
   !< The captures.
   integer(int32) :: unit, ios !< Unit, status.

   open(newunit=unit, file=TABS_SHOT, status='old', iostat=ios)
   if (ios == 0) close(unit, status='delete')
   open(newunit=unit, file=STACKED_SHOT, status='old', iostat=ios)
   if (ios == 0) close(unit, status='delete')
   endsubroutine remove_shots

   subroutine print_state(what)
   !< Diagnostics.
   character(len=*), intent(in) :: what !< When.

   write(output_unit, '(A)') what
   do k = 1_int32, 4_int32
      write(output_unit, '(A6,I12,2L2,4F9.2)') NAMES(k), node(k), docked(k), shown(k), rect(:, k)
   enddo
   endsubroutine print_state

   subroutine run(n, shot, stat)
   !< `n` frames of the dock space; the last captured to `shot`.
   integer(int32),   intent(in)            :: n    !< Frames.
   character(len=*), intent(in),  optional :: shot !< Capture of the last.
   integer(int32),   intent(out), optional :: stat !< Status of the capture.
   integer(int32)                          :: f    !< Frame.
   integer(int32)                          :: j    !< Window.
   integer(int32)                          :: n1, n2 !< Nodes of a split.
   logical                                 :: needed !< The layout is to be built.

   do f = 1_int32, n
      if (.not. app%next_frame()) error stop 'figure_test_dock_view: next_frame returned false in headless mode'
      root = ig_dock_id('main')
      ! not while docking is off: ig_dock_layout_begin crashes then (a finding of #15 P1, left to the owner)
      needed = .false.
      if (docking_on) needed = ig_dock_layout_begin(root)
      if (needed) then
         if (app%layout() == 'Stacked') then
            call ig_dock_split(root, 'up', 0.5_real64, n1, n2)
         else
            call ig_dock_split(root, 'left', 0.35_real64, n1, n2)
         endif
         call ig_dock_window('Tree', n1)
         call ig_dock_window('Mesh', n2)
         call ig_dock_window('Log', n2)
         call ig_dock_layout_end(root)
      endif
      call ig_dock_space(root, stat=j) ! FIG_ERR_STATE while docking is off (phase 4): nothing docks
      node = 0_int32
      docked = .false.
      shown = .false.
      do j = 1_int32, 4_int32
         if (j == 4_int32) call ig_set_next_window(400.0_real64, 280.0_real64, 180.0_real64, 100.0_real64)
         shown(j) = ig_begin(trim(NAMES(j)))
         if (shown(j)) then
            call ig_window_dock(node(j), docked(j))
            call ig_text('The '//trim(NAMES(j))//' window.')
         endif
         call ig_end()
      enddo
      if (f == n .and. present(shot)) call test_capture(shot, stat)
   enddo
   do j = 1_int32, 4_int32
      call test_window_rect(trim(NAMES(j)), rect(1, j), rect(2, j), rect(3, j), rect(4, j))
   enddo
   endsubroutine run
endprogram figure_test_dock_view
