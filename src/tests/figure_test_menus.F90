!< figure_test_menus, menus and keyboard shortcuts driven by synthetic input, headless.
program figure_test_menus
!< figure_test_menus, menus and keyboard shortcuts driven by synthetic input, headless.
!<
!< A File menu in the main menu bar: opened by a click, an item picked, a check-mark item toggled, a disabled item that
!< cannot be picked; a window's own menu bar; ctrl+s read once per press, not while held, not without ctrl; a bad name.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, FIG_ERR_ARGUMENT, ig_begin, ig_begin_main_menu_bar, ig_begin_menu, ig_begin_menu_bar, &
                   ig_end, ig_end_main_menu_bar, ig_end_menu, ig_end_menu_bar, ig_menu_item, ig_set_next_window,   &
                   ig_shortcut, ig_text, ImGuiWindowFlags_MenuBar
use figure_testing, only : test_click, test_item_center, test_key

implicit none
integer(int32), parameter :: FRAMES = 140_int32 !< Frames run.
type(app_object)          :: app                !< Application.
logical                   :: test_passed(8)     !< Per-check outcome.
real(real64)              :: file_at(2)         !< Centre of the File menu's title.
real(real64)              :: save_at(2)         !< Centre of the Save item (while the menu is open).
real(real64)              :: auto_at(2)         !< Centre of the Autosave item.
real(real64)              :: recent_at(2)       !< Centre of the disabled Recent item.
integer(int32)            :: saves              !< Picks of Save.
integer(int32)            :: recents            !< Picks of the disabled item.
logical                   :: autosave           !< Toggled by its item.
logical                   :: menu_bar_shown     !< The window's own menu bar was drawn.
logical                   :: file_open_seen     !< The File menu was open on some frame.
integer(int32)            :: shortcuts          !< Frames on which ctrl+s was reported.
integer(int32)            :: stat_bad           !< Status of a shortcut with an unknown key name.
logical                   :: bad_pressed        !< ... and its result.
integer(int32)            :: frame              !< Frame counter.

saves = 0_int32
recents = 0_int32
autosave = .false.
menu_bar_shown = .false.
file_open_seen = .false.
shortcuts = 0_int32
call app%init_headless(800_int32, 600_int32)
do frame = 1_int32, FRAMES
   if (.not. app%next_frame()) error stop 'figure_test_menus: next_frame returned false in headless mode'
   if (ig_begin_main_menu_bar()) then
      if (ig_begin_menu('File')) then
         file_open_seen = .true.
         if (ig_menu_item('Save', shortcut='Ctrl+S')) saves = saves + 1_int32
         call test_item_center(save_at(1), save_at(2))
         if (ig_menu_item('Autosave', selected=autosave)) continue
         call test_item_center(auto_at(1), auto_at(2))
         if (ig_menu_item('Recent', enabled=.false.)) recents = recents + 1_int32
         call test_item_center(recent_at(1), recent_at(2))
         call ig_end_menu()
      endif
      call test_item_center(file_at(1), file_at(2))   ! the menu's title in the bar
      call ig_end_main_menu_bar()
   endif
   call ig_set_next_window(20.0_real64, 60.0_real64, 300.0_real64, 150.0_real64, always=.true.)
   if (ig_begin('Document', flags=ImGuiWindowFlags_MenuBar)) then
      if (ig_begin_menu_bar()) then
         menu_bar_shown = .true.
         if (ig_begin_menu('Edit')) call ig_end_menu()
         call ig_end_menu_bar()
      endif
      call ig_text('text')
   endif
   call ig_end()
   if (ig_shortcut('ctrl+s')) shortcuts = shortcuts + 1_int32
   select case (frame)
   case (3_int32)
      call test_click(file_at(1), file_at(2))          ! open File, pick Save
   case (12_int32)
      call test_click(save_at(1), save_at(2))
   case (25_int32)
      call test_click(file_at(1), file_at(2))          ! open File, toggle Autosave
   case (34_int32)
      call test_click(auto_at(1), auto_at(2))
   case (47_int32)
      call test_click(file_at(1), file_at(2))          ! open File, try the disabled item
   case (56_int32)
      call test_click(recent_at(1), recent_at(2))
   case (70_int32)
      call test_key('escape')                          ! close the menu
   case (76_int32)
      call test_key('ctrl', down=.true.)               ! ctrl+s once
      call test_key('s')
      call test_key('ctrl', down=.false.)
   case (84_int32)
      call test_key('ctrl', down=.true.)               ! ctrl+s held for 40 frames: still one press
      call test_key('s', down=.true.)
   case (124_int32)
      call test_key('s', down=.false.)
      call test_key('ctrl', down=.false.)
   case (130_int32)
      call test_key('s')                               ! s alone: not the shortcut
   endselect
enddo
bad_pressed = ig_shortcut('ctrl+nosuchkey', stat=stat_bad)
call app%destroy()

test_passed(1) = file_open_seen                                            ! the menu opened on a click
test_passed(2) = saves == 1_int32                                          ! Save picked once
test_passed(3) = autosave                                                  ! the check-mark item toggled
test_passed(4) = recents == 0_int32                                        ! a disabled item cannot be picked
test_passed(5) = menu_bar_shown                                            ! a window's own menu bar
test_passed(6) = shortcuts == 2_int32                                      ! ctrl+s: once, then once while held
test_passed(7) = stat_bad == int(FIG_ERR_ARGUMENT, int32) .and. .not. bad_pressed ! an unknown key name
test_passed(8) = file_at(2) < 30.0_real64                                  ! the main menu bar is along the top

write(output_unit, '(A,*(L2))') 'figure_test_menus checks:', test_passed
if (.not. all(test_passed)) write(output_unit, '(A,I0,A,L2,A,I0,A,I0,A,I0,A,2F8.1)') 'saves ', saves, ', autosave', &
   autosave, ', recents ', recents, ', shortcuts ', shortcuts, ', stat_bad ', stat_bad, ', file at', file_at
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1
endprogram figure_test_menus
