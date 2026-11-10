!< cb_paths, reference example: a headless test that finds items by their paths, clicks through a menu, types into a
!< field, runs until the interface is idle, and checks the ids and the labels.
module cb_paths_ui
!< cb_paths_ui, the interface cb_paths tests: a File menu and a solver panel.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : ICON_PLAY, ig_begin, ig_begin_main_menu_bar, ig_begin_menu, ig_button, ig_checkbox, ig_end, &
                   ig_end_main_menu_bar, ig_end_menu, ig_input, ig_menu_item, ig_set_next_window, ig_tooltip, &
                   ig_tree_node, ig_tree_pop

implicit none
private
public :: case_state, draw

type :: case_state
   !< What the interface edits.
   character(len=32) :: file = ''          !< The case opened.
   real(real64)      :: cfl = 0.5_real64   !< CFL number.
   logical           :: implicit = .false. !< Implicit time stepping.
   integer(int32)    :: runs = 0_int32     !< Times Run was pressed.
endtype case_state

contains
   !region draw
   subroutine draw(s)
   !< The interface, one frame of it: the same procedure in the application and in its test.
   type(case_state), intent(inout) :: s !< State.

   if (ig_begin_main_menu_bar()) then
      if (ig_begin_menu('File')) then
         if (ig_begin_menu('Recent')) then
            if (ig_menu_item('cavity.toml')) s%file = 'cavity.toml'
            if (ig_menu_item('channel.toml')) s%file = 'channel.toml'
            call ig_end_menu()
         endif
         call ig_end_menu()
      endif
      call ig_end_main_menu_bar()
   endif
   call ig_set_next_window(10.0_real64, 30.0_real64, 400.0_real64, 300.0_real64, always=.true.)
   if (ig_begin('Solver')) then
      if (ig_input('CFL', s%cfl, format='%.2f')) continue          ! path 'Solver/CFL'
      if (ig_tree_node('Options')) then                            ! path 'Solver/Options'
         if (ig_checkbox('Implicit', s%implicit)) continue         ! path 'Solver/Options/Implicit'
         call ig_tree_pop()
      endif
      if (ig_button(ICON_PLAY)) s%runs = s%runs + 1_int32          ! an icon alone: a name for the tooltip
      call ig_tooltip('Run the solver')
   endif
   call ig_end()
   endsubroutine draw
   !endregion draw
endmodule cb_paths_ui

program cb_paths
!< cb_paths, reference example: a headless test that finds items by their paths.
use, intrinsic :: iso_fortran_env, only : int32, output_unit
use figure, only : app_object, FIG_ERR_ARGUMENT, figure_last_error
use figure_testing, only : test_id_conflicts, test_item_checked, test_item_click, test_item_type_text, &
                           test_item_value, test_menu_click, test_run, test_unnamed_items
use cb_paths_ui, only : case_state, draw

implicit none
type(app_object) :: app  !< Application.
type(case_state) :: s    !< The interface's state.
integer(int32)   :: stat !< A status.
!run cb_paths ./cb_paths

call app%init_headless(640_int32, 480_int32)
call settle()                                     ! the first frames: the windows placed
!region act
call test_menu_click('File/Recent/channel.toml')  ! File, then Recent once it opens, then the file
call settle()
call test_item_type_text('Solver/CFL', '0.8')     ! a click with the shortcut key, select all, type, Enter
call settle()
call test_item_click('Solver/Options')            ! a tree node: its arrow opens it
call settle()
call test_item_click('Solver/Options/Implicit')
call settle()
!endregion act
!region check
write(output_unit, '(A)') 'file: '//trim(s%file)
write(output_unit, '(A,L1)') 'Implicit checked: ', test_item_checked('Solver/Options/Implicit')
write(output_unit, '(A,L1)') 'CFL shows 0.80: ', test_item_value('Solver/CFL', '0.80')
write(output_unit, '(A,I0)') 'id conflicts: ', test_id_conflicts()
write(output_unit, '(A,I0)') 'unnamed items: ', test_unnamed_items()
call test_item_click('Solver/Options/Implcit', stat=stat) ! a typo: the message names the nearest item
if (stat == FIG_ERR_ARGUMENT) write(output_unit, '(A)') figure_last_error()
!endregion check
call app%destroy()
if (trim(s%file) /= 'channel.toml' .or. .not. s%implicit .or. abs(s%cfl - 0.8d0) > 1.0d-12) &
   error stop 'cb_paths: the input was lost'

contains
   !region settle
   subroutine settle()
   !< Draw frames until the interface is idle: no input queued, no frame asked for (at most 60).
   do while (test_run(60_int32))
      if (.not. app%next_frame()) exit
      call draw(s)
   enddo
   endsubroutine settle
   !endregion settle
endprogram cb_paths
