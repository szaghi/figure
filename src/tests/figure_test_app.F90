!< figure_test_app_ui, the interface figure_test_app drives: a View menu, three registered windows in a dock space with
!< two layouts, message boxes and a splitter.
module figure_test_app_ui
!< figure_test_app_ui, the interface figure_test_app drives: a View menu, three registered windows in a dock space
!< with two layouts, message boxes and a splitter.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_begin_child, ig_begin_main_menu_bar, ig_begin_popup, ig_button, &
                   ig_dock_id, ig_dock_layout_begin, ig_dock_layout_end, ig_dock_space, ig_dock_split, &
                   ig_dock_window, ig_end, ig_end_child, ig_end_main_menu_bar, ig_end_popup, ig_open_popup, &
                   ig_same_line, ig_set_next_window, ig_splitter, ig_text, ig_window_dock

implicit none
private
public :: ui_state, draw_ui

type :: ui_state
   !< What the interface asked, built and drew.
   integer(int32)    :: built_default = 0_int32 !< Times the layout 'Default' was built.
   integer(int32)    :: built_plots = 0_int32   !< Times the layout 'Plots only' was built.
   integer(int32)    :: root = 0_int32          !< The dock space's id.
   integer(int32)    :: node(3) = 0_int32       !< The dock node of Controls, Plots, Log in the last frame.
   logical           :: drawn(3) = .false.      !< Controls, Plots, Log drawn in the last frame.
   logical           :: ask(3) = .false.        !< Message boxes A, B, C asked this frame.
   integer(int32)    :: answer(3) = 0_int32     !< Their answers (the last nonzero one).
   logical           :: split = .false.         !< Draw the splitter's window.
   real(real64)      :: sizes(2) = [200.0_real64, 300.0_real64] !< The splitter's panes [pixels].
   logical           :: split_changed = .false. !< The splitter reported a change.
   logical           :: open_popup = .false.    !< Open the program's own popup on the next frame.
endtype ui_state

character(len=8), parameter :: NAMES(3) = [character(len=8) :: 'Controls', 'Plots', 'Log'] !< Registered windows.

contains
   subroutine draw_ui(app, s)
   !< The interface, one frame of it.
   type(app_object), intent(inout) :: app        !< Application.
   type(ui_state),   intent(inout) :: s          !< State.
   integer(int32)                  :: left, right, top, bottom !< Dock nodes.
   integer(int32)                  :: k          !< Window.
   integer(int32)                  :: a          !< An answer.
   logical                         :: docked     !< Docked.
   character(len=:), allocatable   :: name       !< The layout to build.

   if (ig_begin_main_menu_bar()) then
      call app%view_menu()
      call ig_end_main_menu_bar()
   endif
   s%root = ig_dock_id('main')
   if (ig_dock_layout_begin(s%root)) then
      name = app%layout()                                  ! nvfortran 26.9 -O2: select case on the call itself
      select case (name)                                   ! took 'Plots only' for the default case here
      case ('Plots only')
         s%built_plots = s%built_plots + 1_int32
         call ig_dock_window('Plots', s%root)
      case default
         s%built_default = s%built_default + 1_int32
         call ig_dock_split(s%root, 'left', 0.3_real64, left, right)
         call ig_dock_split(right, 'down', 0.3_real64, bottom, top)
         call ig_dock_window('Controls', left)
         call ig_dock_window('Plots', top)
         call ig_dock_window('Log', bottom)
      endselect
      call ig_dock_layout_end(s%root)
   endif
   call ig_dock_space(s%root)
   s%drawn = .false.
   s%node = 0_int32
   do k = 1_int32, 3_int32
      if (.not. app%window_visible(trim(NAMES(k)))) cycle
      if (ig_begin(trim(NAMES(k)))) then
         call ig_text('in '//trim(NAMES(k)))
         call ig_window_dock(s%node(k), docked)
         s%drawn(k) = .true.
      endif
      call ig_end()
   enddo
   if (s%split) then
      call ig_set_next_window(300.0_real64, 100.0_real64, 600.0_real64, 300.0_real64, always=.true.)
      if (ig_begin('Split')) then
         if (ig_begin_child('left', s%sizes(1), 0.0_real64, border=.true.)) call ig_text('left')
         call ig_end_child()
         call ig_same_line()
         if (ig_splitter('bar', s%sizes)) s%split_changed = .true.
         call ig_same_line()
         if (ig_begin_child('right', s%sizes(2), 0.0_real64, border=.true.)) call ig_text('right')
         call ig_end_child()
      endif
      call ig_end()
   endif
   if (s%open_popup) call ig_open_popup('own')
   s%open_popup = .false.
   if (ig_begin_popup('own')) then                          ! a popup of the program's, at the root
      if (ig_button('Inside')) continue
      call ig_end_popup()
   endif
   if (s%ask(1)) then
      a = app%message_box('a', 'Delete?', 'Delete the case?', [character(len=3) :: 'Yes', 'No'])
      if (a /= 0_int32) s%answer(1) = a
      if (a /= 0_int32) s%ask(1) = .false.
   endif
   if (s%ask(2)) then
      a = app%message_box('b', 'Overwrite?', 'The file exists.', [character(len=6) :: 'OK', 'Cancel'])
      if (a /= 0_int32) s%answer(2) = a
      if (a /= 0_int32) s%ask(2) = .false.
   endif
   if (s%ask(3)) then
      a = app%message_box('c', 'Note', 'Done.')
      if (a /= 0_int32) s%answer(3) = a
      if (a /= 0_int32) s%ask(3) = .false.
   endif
   endsubroutine draw_ui
endmodule figure_test_app_ui

!< figure_test_app, the application layer, headless: the window registry and its View menu, layouts, preferences
!< across a restart and a crash, message boxes, a splitter, size limits.
program figure_test_app
!< figure_test_app, the application layer, headless: the window registry and its View menu, layouts, preferences
!< across a restart and a crash, message boxes, a splitter, size limits.
!<
!< A restart is `destroy` then `init_headless` with the same preferences' file; a crash is this program run again by
!< itself with the argument `crash`: it saves a preference, draws past the 30 s of frame time of the periodic save,
!< saves another and stops with `error stop`, without `destroy`.
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64, output_unit
use figure, only : app_object, FIG_OK, FIG_ERR_ARGUMENT, FIG_ERR_STATE, figure_last_error
use figure_testing, only : test_item_click, test_item_exists, test_item_rect, test_drag, test_key, test_menu_click, &
                           test_item_checked, test_run
use figure_test_app_ui, only : ui_state, draw_ui

implicit none
integer(int32), parameter     :: NCHECKS = 25_int32      !< Checks.
character(len=*), parameter   :: PREFS = 'figure_test_app.prefs'       !< The preferences' file of the restarts.
character(len=*), parameter   :: CRASHED = 'figure_test_app.crash.prefs' !< ... of the crash.
character(len=8), parameter   :: WINDOWS(3) = [character(len=8) :: 'Controls', 'Plots', 'Log'] !< Registered windows.
type(app_object)              :: app                     !< Application.
type(ui_state)                :: s                       !< The interface's state.
logical                       :: ok(NCHECKS)             !< Per-check outcome.
integer(int32)                :: st, st2, st3            !< Statuses.
integer(int32)                :: es                      !< The crashed run's exit status.
integer(int32)                :: i32                     !< A preference.
integer(int64)                :: i64                     !< A preference.
real(real32)                  :: r32                     !< A preference.
real(real64)                  :: r64, r64b               !< Preferences.
logical                       :: l, found                !< A preference, a result.
character(len=40)             :: text                    !< A preference.
character(len=512)            :: me                      !< This program.
real(real64)                  :: x, y, w, h              !< A rectangle.
real(real64)                  :: nord(4), seal(4), now(4) !< Background colours.
real(real64)                  :: before(2)               !< The splitter's sizes before the drag.
integer(int32)                :: k                       !< Counter.

call get_command_argument(1, text)
if (trim(text) == 'crash') call crash_run()
call get_command_argument(0, me)
call forget(PREFS)
call forget(CRASHED)
ok = .false.

! 1-3: the registry: windows added, a name added twice and an unknown name refused; layouts and the file
call app%init_headless(1000_int32, 700_int32)
call app%open_prefs('figure test app', file=PREFS)
call app%open_prefs('figure test app', file=PREFS, stat=st)
ok(1) = st == FIG_ERR_STATE .and. app%prefs_file() == PREFS .and. app%layout() == ''
call app%add_window('Controls')
call app%add_window('Plots', closable=.false.)
call app%add_window('Log')
call app%add_window('Log', stat=st)
found = app%window_visible('Nowhere', stat=st2)
ok(2) = st == FIG_ERR_ARGUMENT .and. st2 == FIG_ERR_ARGUMENT .and. .not. found .and. app%window_visible('Log')
call app%add_layout('Default', windows=[character(len=8) :: 'Controls', 'Plots', 'Log'])
call app%add_layout('Plots only', windows=[character(len=8) :: 'Plots'])
call app%add_layout('Default', stat=st)
ok(3) = st == FIG_ERR_ARGUMENT .and. app%layout() == 'Default'
call settle(60_int32)

! 4: the layout built once, the three windows docked in three nodes
ok(4) = s%built_default == 1_int32 .and. s%built_plots == 0_int32 .and. all(s%drawn) .and. all(s%node /= 0_int32) .and. &
        s%node(1) /= s%node(2) .and. s%node(2) /= s%node(3)
if (.not. ok(4)) write(output_unit, '(A,3I12,3L2)') 'nodes, drawn: ', s%node, s%drawn

! 5-6: Log hidden from the View menu: not drawn, unchecked in the menu
call test_menu_click('View/Log')
call settle(60_int32)
ok(5) = .not. app%window_visible('Log') .and. .not. s%drawn(3) .and. s%drawn(1)
call test_menu_click('View')
call settle(30_int32)
ok(6) = .not. test_item_checked('View/Log') .and. test_item_checked('View/Controls') .and. &
        test_item_checked('View/Default') .and. .not. test_item_checked('View/Plots only')
call test_menu_click('View')                                       ! closed again
call settle(30_int32)

! 7-9: layouts: 'Plots only' from the View menu built, its windows only; 'Default' back as the user left it (not built
! again, Log still where it was docked); reset_layout builds it again
call test_menu_click('View/Plots only')
call settle(60_int32)
ok(7) = app%layout() == 'Plots only' .and. s%built_plots == 1_int32 .and. s%drawn(2) .and. .not. s%drawn(1) .and. &
        s%node(2) /= 0_int32
call app%switch_layout('Default')
call settle(60_int32)
ok(8) = s%built_default == 1_int32 .and. s%built_plots == 1_int32 .and. all(s%drawn) .and. s%node(1) /= s%node(2)
call app%switch_layout('Nowhere', stat=st)
call app%reset_layout()
call settle(60_int32)
ok(9) = st == FIG_ERR_ARGUMENT .and. s%built_default == 2_int32 .and. all(s%drawn)

! 10: the close button of a registered window hides it (Controls: floating, its title bar's right end)
call app%set_style(palette='nord')                                 ! kept by the preferences (check 16)
call app%palette_color('background', nord)
call app%set_window_visible('Log', .false.)                        ! hidden again for the restart (check 15)
call settle(30_int32)
call close_button('Controls')
call settle(60_int32)
ok(10) = .not. app%window_visible('Controls') .and. .not. s%drawn(1)
call app%set_window_visible('Controls', .true.)
call settle(30_int32)
ok(10) = ok(10) .and. app%window_visible('Controls') .and. s%drawn(1)

! 11-13: preferences round-trip in the run, of every kind; a missing key gives the default; a text is not an integer;
! a bad key is refused
call app%save_pref('case', 'naca 0012  ')                          ! trailing blanks kept
call app%save_pref('mesh.n', 64_int32)
call app%save_pref('steps', 12345678901_int64)
call app%save_pref('cfl', 0.7_real32)
call app%save_pref('tol', 0.1_real64)
call app%save_pref('huge', huge(1.0_real64))
call app%save_pref('grid', .true.)
call app%save_pref('multi', 'a = b'//new_line('a')//'c'//achar(92)//'d') ! '=', a newline, a backslash (achar(92):
                                                                       ! a backslash in a literal is nvfortran's escape)
ok(11) = all_kept()
found = app%load_pref('nothing', i32, default=7_int32)
ok(12) = .not. found .and. i32 == 7_int32
found = app%load_pref('case', i32, default=3_int32)                ! a text is not an integer: the default
ok(12) = ok(12) .and. .not. found .and. i32 == 3_int32
call app%save_pref('', 1_int32, stat=st)
call app%save_pref(' lead', 1_int32, stat=st2)
ok(13) = st == FIG_ERR_ARGUMENT .and. st2 == FIG_ERR_ARGUMENT

! 14-17: a restart with the same file: the preferences, the hidden window, the current layout, the style kept
call app%switch_layout('Plots only')
call settle(60_int32)
call app%destroy()
inquire(file=PREFS//'.tmp', exist=found)
ok(14) = .not. found                                               ! written to the temporary file, renamed
inquire(file=PREFS, exist=found)
ok(14) = ok(14) .and. found
s = ui_state()
call app%init_headless(1000_int32, 700_int32)
call app%palette_color('background', seal)
call app%add_window('Controls')
call app%add_window('Plots', closable=.false.)
call app%open_prefs('figure test app', file=PREFS)                 ! after add_window: applied to them
call app%add_window('Log')                                         ! after open_prefs: applied when added
call app%add_layout('Default', windows=[character(len=8) :: 'Controls', 'Plots', 'Log'])
call app%add_layout('Plots only', windows=[character(len=8) :: 'Plots'])
ok(15) = .not. app%window_visible('Log') .and. app%window_visible('Plots') .and. all_kept()
call app%palette_color('background', now)
ok(16) = all(abs(now - nord) < 1.0e-6_real64) .and. any(abs(seal - nord) > 1.0e-3_real64)
call settle(60_int32)
ok(17) = app%layout() == 'Plots only' .and. s%built_plots == 0_int32 .and. s%built_default == 0_int32 .and. &
         s%drawn(2) .and. s%node(2) /= 0_int32                     ! the arrangement kept: nothing built again

! 18: a crash after a save: the crashed run's saved preference is kept, the one after its save is not, and the file is
! whole (no temporary file left)
call execute_command_line(trim(me)//' crash', exitstat=es)
call app%destroy()
call app%init_headless(1000_int32, 700_int32)
call app%open_prefs('a/b', stat=st3)                               ! not a folder's name
call app%open_prefs('figure test app', file=CRASHED)
do k = 1_int32, 3_int32
   call app%add_window(trim(WINDOWS(k)))
enddo
text = ''
found = app%load_pref('saved', text)
ok(18) = es /= 0_int32 .and. found .and. trim(text) == 'before the crash'
found = app%load_pref('lost', text, stat=st)
ok(18) = ok(18) .and. .not. found .and. st == FIG_OK
inquire(file=CRASHED//'.tmp', exist=l)
ok(18) = ok(18) .and. .not. l .and. st3 == FIG_ERR_ARGUMENT
if (.not. ok(18)) write(output_unit, '(A,I0,A)') 'crash: exit ', es, ' "'//trim(text)//'"'

! 19-21: two message boxes at once, each answering its own button: the newer on top takes the clicks
s = ui_state()
s%ask(1:2) = [.true., .false.]
call settle(30_int32)
s%ask(2) = .true.
call settle(30_int32)
ok(19) = test_item_exists('Delete?/Yes') .and. test_item_exists('Overwrite?/Cancel') .and. all(s%answer == 0_int32)
call test_item_click('Delete?/Yes')                                ! under the newer box: not answered
call settle(30_int32)
ok(20) = s%answer(1) == 0_int32 .and. s%ask(1)
call test_item_click('Overwrite?/Cancel')
call settle(30_int32)
ok(21) = s%answer(2) == 2_int32 .and. s%answer(1) == 0_int32 .and. .not. test_item_exists('Overwrite?/Cancel')
call test_item_click('Delete?/Yes')
call settle(30_int32)
ok(21) = ok(21) .and. s%answer(1) == 1_int32 .and. .not. s%ask(1)

! 22: a box with its default button, answered by Escape; an empty id refused
s%ask(3) = .true.
call settle(30_int32)
call test_key('escape')
call settle(30_int32)
k = app%message_box('', 'x', 'y', stat=st)
ok(22) = s%answer(3) == 1_int32 .and. st == FIG_ERR_ARGUMENT .and. k == 0_int32

! 23: a splitter dragged 40 pixels: the first pane 40 wider, the second 40 narrower; three sizes refused
s%split = .true.
call settle(30_int32)
before = s%sizes
found = test_item_rect('Split/bar', x, y, w, h)
call test_drag(x + 0.5_real64 * w, y + 20.0_real64, x + 0.5_real64 * w + 40.0_real64, y + 20.0_real64)
call settle(30_int32)
ok(23) = found .and. s%split_changed .and. abs(s%sizes(1) - before(1) - 40.0_real64) < 0.5_real64 .and. &
         abs(sum(s%sizes) - sum(before)) < 1.0e-6_real64
if (.not. ok(23)) write(output_unit, '(A,L2,4F9.2)') 'splitter: ', found, before, s%sizes

! 24: size limits: nothing to do headless, wrong limits refused
call app%set_size_limits(320_int32, 200_int32, stat=st)
call app%set_size_limits(320_int32, 200_int32, 100_int32, 0_int32, stat=st2)
call app%set_size_limits(-1_int32, 200_int32, stat=st3)
ok(24) = st == FIG_OK .and. st2 == FIG_ERR_ARGUMENT .and. st3 == FIG_ERR_ARGUMENT

! 25: a box asked while a popup of the program's is open waits for it to close (the popup is not closed by it)
s%split = .false.
s%open_popup = .true.
call settle(30_int32)
s%ask(3) = .true.
call settle(30_int32)
ok(25) = test_item_exists('Inside') .and. .not. test_item_exists('Note/OK')
call test_key('escape')                                            ! the popup closed by the user
call settle(30_int32)
ok(25) = ok(25) .and. .not. test_item_exists('Inside') .and. test_item_exists('Note/OK')
call test_item_click('Note/OK')
call settle(30_int32)
ok(25) = ok(25) .and. s%answer(3) == 1_int32 .and. .not. s%ask(3)

call app%destroy()
call forget(PREFS)
call forget(CRASHED)
write(output_unit, '(A,*(L2))') 'figure_test_app checks:', ok
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(ok)
if (.not. all(ok)) then
   write(output_unit, '(A)') 'last error: '//figure_last_error()
   error stop 1
endif

contains
   subroutine settle(max_frames)
   !< Draw until the interface is idle, at most `max_frames` frames.
   integer(int32), intent(in) :: max_frames !< Frames allowed.

   call app%request_frames(3_int32)                                ! the state changed between frames: drawn, settled
   do while (test_run(max_frames))
      if (.not. app%next_frame()) exit
      call draw_ui(app, s)
   enddo
   endsubroutine settle

   logical function all_kept() result(kept)
   !< Every preference of check 11 reads back exactly.
   character(len=40) :: t !< A text.

   ! one call a statement: a function that defines t (or i32, ...) must not meet t elsewhere in its statement
   ! (F2018 10.1.4); gfortran evaluates left to right, nvfortran does not
   t = ''
   kept = .false.
   if (.not. app%load_pref('case', t)) return
   if (t /= 'naca 0012') return
   if (.not. app%load_pref('mesh.n', i32)) return
   if (i32 /= 64_int32) return
   if (.not. app%load_pref('steps', i64)) return
   if (i64 /= 12345678901_int64) return
   if (.not. app%load_pref('cfl', r32)) return
   if (r32 /= 0.7_real32) return
   if (.not. app%load_pref('tol', r64)) return
   if (r64 /= 0.1_real64) return
   if (.not. app%load_pref('huge', r64b)) return
   if (r64b /= huge(1.0_real64)) return
   if (.not. app%load_pref('grid', l)) return
   if (.not. l) return
   if (.not. app%load_pref('multi', t)) return
   kept = t == 'a = b'//new_line('a')//'c'//achar(92)//'d'
   endfunction all_kept

   subroutine close_button(name)
   !< Click the close button of the floating window `name`: at the right end of its title bar.
   character(len=*), intent(in) :: name !< Window.
   real(real64)                 :: x, y, w, h !< Its rectangle.

   if (.not. test_item_rect('//'//name, x, y, w, h)) return
   call test_item_click('//'//name//'/'//'#CLOSE', stat=st) ! by path, if the button is recorded with a label
   endsubroutine close_button

   subroutine crash_run()
   !< The crashed run: a preference saved by the periodic save, another after it, then a stop without destroy.
   type(app_object) :: a !< Application.
   integer(int32)   :: f !< Frame.

   call a%init_headless(400_int32, 300_int32)
   call a%open_prefs('figure test app', file=CRASHED)
   call a%save_pref('saved', 'before the crash')
   do f = 1_int32, 1900_int32                                      ! 31.7 s of frame time (1/60 s a frame)
      if (.not. a%next_frame()) exit
   enddo
   call a%save_pref('lost', 'after the save')
   do f = 1_int32, 60_int32                                        ! one more second: no save before 30 s
      if (.not. a%next_frame()) exit
   enddo
   error stop 3                                                    ! a crash: no destroy, nothing saved at the end
   endsubroutine crash_run

   subroutine forget(path)
   !< Delete a file and its temporary file, if they exist.
   character(len=*), intent(in) :: path !< File.
   integer(int32)               :: u, ios !< Unit, I/O status.
   logical                      :: there !< It exists.

   inquire(file=path, exist=there)
   if (there) then
      open(newunit=u, file=path, iostat=ios)
      if (ios == 0) close(u, status='delete')
   endif
   inquire(file=path//'.tmp', exist=there)
   if (there) then
      open(newunit=u, file=path//'.tmp', iostat=ios)
      if (ios == 0) close(u, status='delete')
   endif
   endsubroutine forget
endprogram figure_test_app
