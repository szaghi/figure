!< cb_workspace, reference example: a bar along a side, a dock space with a layout, a window that appears later in a
!< node of it, and the arrangement saved to a file and loaded back; checked headless.
program cb_workspace
!< cb_workspace, reference example: a bar along a side, a dock space with a layout, a window that appears later in a
!< node of it, and the arrangement saved to a file and loaded back; checked headless.
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object, FIG_OK, ig_begin, ig_begin_main_menu_bar, ig_begin_menu, ig_begin_side_bar, &
                   ig_dock_id, ig_dock_layout_begin, ig_dock_layout_end, ig_dock_space, ig_dock_split, &
                   ig_dock_window, ig_end, ig_end_main_menu_bar, ig_end_menu, ig_menu_item, ig_set_next_window_dock, &
                   ig_text, ig_tool_button, ig_window_dock, ICON_ACTIVITY, ICON_FILE_PEN

implicit none
type(app_object) :: app                  !< Application.
integer(int32)   :: root                 !< The dock space.
integer(int32)   :: left, right          !< Its two nodes.
integer(int32)   :: tool = 1_int32       !< The workspace chosen.
logical          :: show_result = .false. !< The result window exists (it appears on frame 5).
integer(int32)   :: node                 !< The node a window is docked in.
logical          :: docked               !< Whether it is docked.
integer(int32)   :: stat                 !< Status.
integer(int32)   :: frame                !< Frame counter.

call app%init_headless(900_int32, 600_int32)
do frame = 1_int32, 12_int32
   if (.not. app%next_frame()) exit
   if (frame == 5_int32) show_result = .true.                 ! a result computed later
   if (ig_begin_main_menu_bar()) then
      if (ig_begin_menu('File')) then
         if (ig_menu_item('Quit')) call app%quit()
         call ig_end_menu()
      endif
      call ig_end_main_menu_bar()
   endif
   if (ig_begin_side_bar('Tools', 'left', 80.0_real64)) then  ! 'left', 'right', 'top' or 'bottom'
      if (ig_tool_button('Input', ICON_FILE_PEN, selected=tool == 1)) tool = 1
      if (ig_tool_button('Monitor', ICON_ACTIVITY, selected=tool == 2)) tool = 2
   endif
   call ig_end()                                              ! always, as for any window
   root = ig_dock_id('main')
   if (ig_dock_layout_begin(root)) then
      call ig_dock_split(root, 'left', 0.4_real64, left, right)
      call ig_dock_window('Case', left)
      call ig_dock_layout_end(root)
   endif
   call ig_dock_space(root)                                   ! fills what the bars leave
   if (ig_begin('Case')) call ig_text('the case')
   call ig_end()
   if (show_result) then
      call ig_set_next_window_dock(right)                     ! the node from the layout, the first time only
      if (ig_begin('Result')) then
         call ig_window_dock(node, docked)                    ! where it landed
         call ig_text('the result')
      endif
      call ig_end()
   endif
enddo
write(output_unit, '(A,L1,A,L1)') 'Result docked: ', docked, ', in the right node: ', node == right

call app%save_layout('workspace.layout', comment='result = shown', stat=stat)   ! any time
if (stat == FIG_OK) write(output_unit, '(A)') 'layout saved to workspace.layout'
call app%load_layout('workspace.layout', stat=stat)                           ! applied before the next frame
if (stat == FIG_OK) write(output_unit, '(A)') 'layout loaded from workspace.layout'
call app%destroy()
if (.not. (docked .and. node == right)) error stop 'cb_workspace: the result window is not in its node'
endprogram cb_workspace
