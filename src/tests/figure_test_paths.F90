!< figure_test_paths_ui, the interface figure_test_paths drives: a menu bar, a panel with a tree, tabs, a table, a child,
!< a context menu, a combo, fields, an id conflict and icon-only buttons, a second window, and many buttons for the cost.
module figure_test_paths_ui
!< figure_test_paths_ui, the interface figure_test_paths drives: a menu bar, a panel with a tree, tabs, a table, a
!< child, a context menu, a combo, fields, an id conflict and icon-only buttons, a second window, and many buttons for
!< the cost.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : ICON_SAVE, ICON_SAVE_ALL, ig_begin, ig_begin_child, ig_begin_main_menu_bar, ig_begin_menu, &
                   ig_begin_popup_context, ig_begin_tab, ig_begin_tab_bar, ig_begin_table, ig_button, ig_checkbox, &
                   ig_combo, ig_end, ig_end_child, ig_end_main_menu_bar, ig_end_menu, ig_end_popup, ig_end_tab, &
                   ig_end_tab_bar, ig_end_table, ig_input_text, ig_item_rect, ig_menu_item, ig_pop_id, ig_push_id, &
                   ig_set_next_window, ig_slider, ig_table_next_column, ig_table_next_row, ig_text, ig_tooltip, &
                   ig_tree_node, ig_tree_pop

implicit none
private
public :: ui_state, draw_ui, draw_bulk

type :: ui_state
   !< What the interface changed, and where it drew an item.
   logical            :: enable = .false.       !< The checkbox.
   logical            :: autosave = .false.     !< The menu's check-mark item.
   real(real64)       :: speed = 0.5_real64     !< The slider.
   character(len=32)  :: name = ''              !< The text field.
   integer(int32)     :: mode = 1_int32         !< The combo's choice.
   integer(int32)     :: leaf = 0_int32         !< Clicks of Node/Leaf.
   integer(int32)     :: beta = 0_int32         !< Clicks of the button in tab Beta.
   integer(int32)     :: row = 0_int32          !< The table row whose Edit was clicked last.
   integer(int32)     :: deep = 0_int32         !< Clicks of the child's button.
   integer(int32)     :: deleted = 0_int32      !< Picks of the context menu's Delete.
   integer(int32)     :: twins = 0_int32        !< Clicks of either Twin.
   character(len=32)  :: opened = ''            !< The file picked in File/Recent.
   real(real64)       :: enable_rect(4) = 0.0_real64 !< The checkbox's rectangle, from ig_item_rect.
   logical            :: second = .true.        !< Draw the second window.
endtype ui_state

contains
   subroutine draw_ui(s)
   !< The interface, one frame of it.
   type(ui_state), intent(inout) :: s           !< State.
   character(len=9), parameter   :: MODES(3) = [character(len=9) :: 'Alpha', 'Beta mode', 'Gamma'] !< Combo items.
   integer(int32)                :: r           !< Table row.
   logical                       :: node_clicked !< The tree node's label clicked.

   if (ig_begin_main_menu_bar()) then
      if (ig_begin_menu('File')) then
         if (ig_menu_item('Open')) s%opened = 'open'
         if (ig_begin_menu('Recent')) then
            if (ig_menu_item('notes.txt')) s%opened = 'notes.txt'
            if (ig_menu_item('data.csv')) s%opened = 'data.csv'
            call ig_end_menu()
         endif
         if (ig_menu_item('Autosave', selected=s%autosave)) continue
         call ig_end_menu()
      endif
      call ig_end_main_menu_bar()
   endif
   call ig_set_next_window(10.0_real64, 30.0_real64, 520.0_real64, 560.0_real64, always=.true.)
   if (ig_begin('Panel')) then
      if (ig_checkbox('Enable', s%enable)) continue
      call ig_item_rect(s%enable_rect(1), s%enable_rect(2), s%enable_rect(3), s%enable_rect(4))
      if (ig_slider('Speed', s%speed, 0.0_real64, 1.0_real64)) continue
      if (ig_input_text('Name', s%name)) continue
      if (ig_combo('Mode', s%mode, MODES)) continue
      if (ig_tree_node('Node', clicked=node_clicked)) then
         if (ig_button('Leaf')) s%leaf = s%leaf + 1_int32
         call ig_tree_pop()
      endif
      if (ig_begin_tab_bar('tabs')) then
         if (ig_begin_tab('Alpha')) then
            call ig_text('in alpha')
            call ig_end_tab()
         endif
         if (ig_begin_tab('Beta')) then
            if (ig_button('In beta')) s%beta = s%beta + 1_int32
            call ig_end_tab()
         endif
         call ig_end_tab_bar()
      endif
      if (ig_begin_table('grid', 2_int32)) then
         do r = 1_int32, 3_int32
            call ig_push_id(r)
            call ig_table_next_row()
            call ig_table_next_column()
            call ig_text('row')
            call ig_table_next_column()
            if (ig_button('Edit')) s%row = r
            call ig_pop_id()
         enddo
         call ig_end_table()
      endif
      if (ig_begin_child('list', 0.0_real64, 60.0_real64, border=.true.)) then
         if (ig_button('Deep')) s%deep = s%deep + 1_int32
         do r = 1_int32, 8_int32
            call ig_push_id(r)
            if (ig_button('Row')) continue
            call ig_pop_id()
         enddo
         if (ig_button('Bottom')) continue                  ! below the child's 60 pixels: not visible
      endif
      call ig_end_child()
      if (ig_button('Actions')) continue
      if (ig_begin_popup_context('actions_menu')) then
         if (ig_menu_item('Delete')) s%deleted = s%deleted + 1_int32
         call ig_end_popup()
      endif
      if (ig_button('Twin')) s%twins = s%twins + 1_int32   ! the same label twice: one id, an id conflict
      if (ig_button('Twin')) s%twins = s%twins + 1_int32
      if (ig_button(ICON_SAVE)) continue                    ! an icon alone, no tooltip: unnamed
      if (ig_button(ICON_SAVE_ALL)) continue                ! an icon alone with a tooltip: named by it
      call ig_tooltip('Save all')
      if (ig_button('##hidden')) continue                   ! no visible label: unnamed
   endif
   call ig_end()
   if (s%second) then
      call ig_set_next_window(560.0_real64, 30.0_real64, 220.0_real64, 120.0_real64, always=.true.)
      if (ig_begin('Other')) then
         if (ig_button('Leaf')) continue
      endif
      call ig_end()
   endif
   endsubroutine draw_ui

   subroutine draw_bulk(n)
   !< A window of `n` buttons, for the cost of recording items.
   integer(int32), intent(in) :: n !< Buttons.
   integer(int32)             :: i !< Button.

   call ig_set_next_window(0.0_real64, 0.0_real64, 800.0_real64, 600.0_real64, always=.true.)
   if (ig_begin('Bulk')) then
      do i = 1_int32, n
         call ig_push_id(i)
         if (ig_button('b')) continue
         call ig_pop_id()
      enddo
   endif
   call ig_end()
   endsubroutine draw_bulk
endmodule figure_test_paths_ui

!< figure_test_paths, items found by path, the frame driver, and the id and label checks, headless.
program figure_test_paths
!< figure_test_paths, items found by path, the frame driver, and the id and label checks, headless.
!<
!< Items in a tree, tabs, a table, a child, a context menu and a combo's list found by path and clicked; a field typed
!< into, a slider typed and read back; a missing path naming the nearest match; a path naming several items; a menu path
!< opening its submenus over several frames; test_run idle, past max_frames, reporting a menu level that never
!< appears; an id conflict found without hovering; icon-only and unlabelled buttons found; the cost per frame measured.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, FIG_OK, FIG_ERR_ARGUMENT, FIG_ERR_STATE, figure_last_error, figure_time
use figure_testing, only : test_click, test_id_conflicts, test_item_checked, test_item_click, test_item_exists, &
                           test_item_rect, test_item_type_text, test_item_value, test_menu_click, test_record_items, &
                           test_run, test_unnamed_items
use figure_test_paths_ui, only : ui_state, draw_ui, draw_bulk

implicit none
integer(int32), parameter     :: NCHECKS = 34_int32 !< Checks.
integer(int32), parameter     :: BULK = 1000_int32  !< Buttons of the cost measurement.
integer(int32), parameter     :: TIMED = 120_int32  !< Frames timed, recording off and on.
type(app_object)              :: app                !< Application.
type(ui_state)                :: s                  !< The interface's state.
logical                       :: ok(NCHECKS)        !< Per-check outcome.
integer(int32)                :: st                 !< A status.
integer(int32)                :: frames             !< Frames of a run.
integer(int32)                :: n                  !< A count.
real(real64)                  :: x, y, w, h         !< A rectangle.
real(real64)                  :: t0, t_off, t_on    !< Times [s].
character(len=:), allocatable :: msg                !< A message.
character(len=:), allocatable :: shown              !< A value shown.
character(len=:), allocatable :: list(:)            !< Paths.
logical                       :: found              !< An item found.

ok = .false.
call app%init_headless(800_int32, 600_int32)
call settle(60_int32)                                            ! the windows sized and placed

! 1-4: windows and items found; the rectangle of a path is the item's
ok(1) = test_item_exists('Panel') .and. test_item_exists('//Panel') .and. test_item_exists('//Panel/Enable') .and. &
        .not. test_item_checked('Panel/Enable')
found = test_item_rect('Panel/Enable', x, y, w, h)
ok(2) = found .and. abs(x - s%enable_rect(1)) < 0.5_real64 .and. abs(y - s%enable_rect(2)) < 0.5_real64 .and. &
        abs(x + w - s%enable_rect(3)) < 0.5_real64 .and. abs(y + h - s%enable_rect(4)) < 0.5_real64
found = test_item_rect('Panel/Nothing', x, y, w, h)               ! apart: an operand's order is the compiler's
ok(3) = .not. found .and. w == 0.0_real64
ok(4) = .not. test_item_exists('Panel/Node/Leaf')                ! a closed node's children are not drawn

! 5-6: a checkbox clicked by path, its state read
call test_item_click('Panel/Enable')
call settle(30_int32)
ok(5) = s%enable
ok(6) = test_item_checked('Panel/Enable') .and. .not. test_item_checked('Panel/Speed', stat=st)
ok(6) = ok(6) .and. st == FIG_ERR_ARGUMENT                       ! a slider is not checkable
ok(6) = ok(6) .and. test_item_value('Panel/Enable', '')            ! a checkbox shows its label only

! 7-8: a missing path names the nearest match; a path that is not one
call test_item_click('Panel/Enabel', stat=st)
msg = figure_last_error()
ok(7) = st == FIG_ERR_ARGUMENT .and. index(msg, "nearest: '//Panel/Enable'") > 0
call test_item_click('Panel//Enable', stat=st)
ok(8) = st == FIG_ERR_ARGUMENT
if (.not. ok(7)) write(output_unit, '(A)') 'nearest: '//msg

! 9-10: a tree: the node opened by path, then its child
call test_item_click('Panel/Node')
call settle(30_int32)
ok(9) = test_item_exists('Panel/Node/Leaf')
call test_item_click('Panel/Node/Leaf')
call settle(30_int32)
ok(10) = s%leaf == 1_int32

! 11: a relative path naming items in two windows: refused, both named
call test_item_click('Leaf', stat=st)
msg = figure_last_error()
ok(11) = st == FIG_ERR_ARGUMENT .and. index(msg, '//Panel/Node/Leaf') > 0 .and. index(msg, '//Other/Leaf') > 0 .and. &
         test_item_exists('Leaf')                                 ! several: it exists

! 12-13: tabs: a tab selected by path, then a button in it, by its full path and skipping the tab bar's level
call test_item_click('Panel/tabs/Beta')
call settle(30_int32)
ok(12) = test_item_exists('Panel/tabs/Beta/In beta') .and. test_item_exists('Panel/Beta/In beta')
call test_item_click('Panel/Beta/In beta')
call settle(30_int32)
ok(13) = s%beta == 1_int32

! 14-15: a table: row 2's button by its integer id, and by '*' for the row's level
call test_item_click('Panel/grid/$$2/Edit')
call settle(30_int32)
ok(14) = s%row == 2_int32
call test_item_click('Panel/grid/*/Edit', stat=st)               ! three rows: several
ok(15) = st == FIG_ERR_ARGUMENT .and. test_item_exists('Panel/*/$$3/Edit')

! 16: a child window's button
call test_item_click('Panel/list/Deep')
call settle(30_int32)
ok(16) = s%deep == 1_int32
call test_item_click('Panel/list/Bottom', stat=st)               ! scrolled out of the child: refused
ok(16) = ok(16) .and. st == FIG_ERR_STATE .and. test_item_exists('Panel/list/Bottom')

! 17-18: a context menu opened by a right click, its entry found under the item and picked
call test_item_click('Panel/Actions', button='right')
call settle(30_int32)
ok(17) = test_item_exists('Panel/Actions/Delete') .or. test_item_exists('Panel/actions_menu/Delete')
call test_item_click('Delete', stat=st)
call settle(30_int32)
ok(18) = st == FIG_OK .and. s%deleted == 1_int32

! 19-20: a combo: its list opened, a choice picked under it, the choice shown as its value
call test_item_click('Panel/Mode')
call settle(30_int32)
call test_item_click('Panel/Mode/Beta mode', stat=st)
call settle(30_int32)
ok(19) = st == FIG_OK .and. s%mode == 2_int32
ok(20) = test_item_value('Panel/Mode', 'Beta mode', shown)
if (.not. ok(20)) write(output_unit, '(A)') 'combo shows: "'//shown//'"'

! 21-23: text typed into a slider and into a text field; the slider shows its value
call test_item_type_text('Panel/Speed', '0.25')
call settle(40_int32)
ok(21) = abs(s%speed - 0.25_real64) < 1.0e-9_real64
ok(22) = test_item_value('Panel/Speed', '0.25', shown)   ! '%.6g', ig_slider's format of a real
if (.not. ok(22)) write(output_unit, '(A,F8.4,A)') 'speed ', s%speed, ', slider shows: "'//shown//'"'
call test_item_type_text('Panel/Name', 'hello world')
call settle(40_int32)
ok(23) = trim(s%name) == 'hello world' .and. test_item_value('Panel/Name', 'hello world')
if (.not. ok(23)) write(output_unit, '(A)') 'name: "'//trim(s%name)//'"'

! 24-26: a menu path: File, then Recent, then notes.txt, each level clicked once it appears, over several frames
call test_menu_click('File/Recent/notes.txt')
call settle(60_int32, frames)
ok(24) = trim(s%opened) == 'notes.txt'
ok(25) = frames > 8_int32                                         ! three clicks, two menus opening between them
call test_menu_click('File/Autosave')
call settle(60_int32)
ok(26) = s%autosave
if (.not. ok(24)) write(output_unit, '(A,I0)') 'opened: "'//trim(s%opened)//'", frames ', frames

! 27-28: test_run past max_frames; a menu level that never appears, reported by test_run
call test_click(700.0_real64, 500.0_real64)
st = FIG_OK
n = 0_int32
do while (test_run(2_int32, stat=st))
   n = n + 1_int32
   call frame()
enddo
ok(27) = st == FIG_ERR_STATE .and. n == 2_int32
call settle(30_int32)
call test_menu_click('File/Nope')
st = FIG_OK
do while (test_run(60_int32, stat=st))
   call frame()
enddo
msg = figure_last_error()
ok(28) = st == FIG_ERR_STATE .and. index(msg, 'Nope') > 0
call test_menu_click('File/Nope/Deeper', stat=st)                ! no File menu open now: File clicked, then waits
do while (test_run(60_int32, stat=st))
   call frame()
enddo
call test_click(700.0_real64, 500.0_real64)                     ! close what is left open
call settle(30_int32)

! 29-30: the id conflict, found with the pointer elsewhere; its path names it, and refuses a click
n = test_id_conflicts(list)
ok(29) = n == 1_int32
if (ok(29)) ok(29) = index(list(1), '//Panel/Twin') > 0
call test_item_click('Panel/Twin', stat=st)
ok(30) = st == FIG_ERR_ARGUMENT .and. index(figure_last_error(), 'id conflict') > 0

! 31-32: the unnamed items: the icon alone and the hidden label, not the icon with a tooltip
n = test_unnamed_items(list)
ok(31) = n == 2_int32
if (ok(31)) ok(31) = index(list(1)//list(2), '##hidden') > 0
ok(32) = test_unnamed_items() == 2_int32
if (.not. ok(31)) then
   write(output_unit, '(A,I0)') 'unnamed: ', n
   if (allocated(list)) write(output_unit, '(A)') list
endif

! 33: recording stopped: nothing found from the next frame on, found again after it restarts
call test_record_items(.false.)
call frame()
call frame()
ok(33) = .not. test_item_exists('Panel/Enable')
call test_record_items(.true.)
call frame()
call frame()
ok(33) = ok(33) .and. test_item_exists('Panel/Enable')

! 34: the cost of recording, per frame and per item: BULK buttons drawn TIMED frames with recording off, then on
call test_record_items(.false.)
call bulk_frames(10_int32)
t0 = figure_time()
call bulk_frames(TIMED)
t_off = (figure_time() - t0) / TIMED
call test_record_items(.true.)
call bulk_frames(10_int32)
t0 = figure_time()
call bulk_frames(TIMED)
t_on = (figure_time() - t0) / TIMED
write(output_unit, '(A,I0,A,F9.1,A,F9.1,A,F7.3,A)') 'recording items, ', BULK, ' buttons: ', 1.0e6_real64 * t_off, &
   ' us per frame off, ', 1.0e6_real64 * t_on, ' us on, ', 1.0e6_real64 * (t_on - t_off) / BULK, ' us per item'
ok(34) = test_item_exists('Bulk/$$500/b') .and. (t_on - t_off) / BULK < 5.0e-6_real64

call app%destroy()
write(output_unit, '(A,*(L2))') 'figure_test_paths checks:', ok
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(ok)
if (.not. all(ok)) error stop 1

contains
   subroutine frame()
   !< One frame of the interface.
   if (.not. app%next_frame()) error stop 'figure_test_paths: next_frame returned false in headless mode'
   call draw_ui(s)
   endsubroutine frame

   subroutine settle(max_frames, count)
   !< Frames until the interface is idle (test_run), at least one; how many in `count`.
   integer(int32), intent(in)            :: max_frames !< Frames allowed.
   integer(int32), intent(out), optional :: count      !< Frames drawn.
   integer(int32)                        :: k          !< Frames drawn.

   k = 0_int32
   do while (test_run(max_frames) .or. k == 0_int32)
      k = k + 1_int32
      call frame()
   enddo
   if (present(count)) count = k
   endsubroutine settle

   subroutine bulk_frames(n)
   !< `n` frames of the bulk window alone.
   integer(int32), intent(in) :: n !< Frames.
   integer(int32)             :: k !< Frame.

   do k = 1_int32, n
      if (.not. app%next_frame()) error stop 'figure_test_paths: next_frame returned false in headless mode'
      call draw_bulk(BULK)
   enddo
   endsubroutine bulk_frames
endprogram figure_test_paths
