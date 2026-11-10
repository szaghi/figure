!< cb_view_menu, reference example: three windows registered with FIGURE, a View menu that shows and hides them, two
!< layouts of the dock space and a reset; checked headless by clicking through the menu.
program cb_view_menu
!< cb_view_menu, reference example: three windows registered with FIGURE, a View menu that shows and hides them, two
!< layouts of the dock space and a reset; checked headless by clicking through the menu.
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object, ig_begin, ig_begin_main_menu_bar, ig_dock_id, ig_dock_layout_begin, &
                   ig_dock_layout_end, ig_dock_space, ig_dock_split, ig_dock_window, ig_end, ig_end_main_menu_bar, &
                   ig_text
use figure_testing, only : test_menu_click, test_run

implicit none
type(app_object)            :: app                    !< Application.
character(len=9), parameter :: PANELS(3) = [character(len=9) :: 'Case', 'Residuals', 'Log'] !< The windows.
integer(int32)              :: root                   !< The dock space.
integer(int32)              :: left, right, top, bottom !< Its nodes.
integer(int32)              :: builds = 0_int32       !< Layouts built.
integer(int32)              :: k                      !< Counter.
!run cb_view_menu ./cb_view_menu

call app%init_headless(900_int32, 600_int32)
!region register
call app%add_window('Case', closable=.false.)              ! always there: no close button
call app%add_window('Residuals')
call app%add_window('Log', visible=.false.)                ! hidden at the first run
call app%add_layout('Input', windows=[character(len=9) :: 'Case', 'Log'])
call app%add_layout('Monitor', windows=[character(len=9) :: 'Case', 'Residuals', 'Log'])
!endregion register
call draw(30_int32)
write(output_unit, '(A,3L2)') 'shown: Case, Residuals, Log:', (app%window_visible(trim(PANELS(k))), k = 1, 3)
call test_menu_click('View/Monitor')                       ! as the user does
call draw(60_int32)
write(output_unit, '(A)') 'layout: '//app%layout()
write(output_unit, '(A,3L2)') 'shown: Case, Residuals, Log:', (app%window_visible(trim(PANELS(k))), k = 1, 3)
call test_menu_click('View/Log')
call draw(60_int32)
write(output_unit, '(A,L2)') 'Log shown after View/Log:', app%window_visible('Log')
call test_menu_click('View/Reset layout')
call draw(60_int32)
write(output_unit, '(A,I0,A,L2)') 'layouts built: ', builds, ', Log shown again:', app%window_visible('Log')
call app%destroy()
if (builds /= 3_int32) error stop 'cb_view_menu: a layout was not built'

contains
   subroutine draw(frames)
   !< Draw until idle, at most `frames` frames.
   integer(int32), intent(in) :: frames !< Frames allowed.

   call app%request_frames(3_int32)
   do while (test_run(frames))
      if (.not. app%next_frame()) exit
      call frame()
   enddo
   endsubroutine draw

   subroutine frame()
   !< One frame of the interface.
   integer(int32)                :: w      !< Window.
   character(len=:), allocatable :: layout !< The current layout.

   !region menu
   if (ig_begin_main_menu_bar()) then
      call app%view_menu()                                 ! the windows, the layouts, Reset layout
      call ig_end_main_menu_bar()
   endif
   !endregion menu
   !region layouts
   root = ig_dock_id('main')
   if (ig_dock_layout_begin(root)) then                    ! the first frame, and after a switch or a reset
      builds = builds + 1_int32
      layout = app%layout()                                ! the one to build
      select case (layout)
      case ('Input')
         call ig_dock_split(root, 'left', 0.5_real64, left, right)
         call ig_dock_window('Case', left)
         call ig_dock_window('Log', right)
      case ('Monitor')
         call ig_dock_split(root, 'left', 0.3_real64, left, right)
         call ig_dock_split(right, 'down', 0.3_real64, bottom, top)
         call ig_dock_window('Case', left)
         call ig_dock_window('Residuals', top)
         call ig_dock_window('Log', bottom)
      endselect
      call ig_dock_layout_end(root)
   endif
   call ig_dock_space(root)
   do w = 1_int32, 3_int32
      if (.not. app%window_visible(trim(PANELS(w)))) cycle   ! draw a registered window while it is shown
      if (ig_begin(trim(PANELS(w)))) call ig_text('the '//trim(PANELS(w)))
      call ig_end()
   enddo
   !endregion layouts
   endsubroutine frame
endprogram cb_view_menu
