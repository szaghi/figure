!< cb_shortcuts, cookbook: keys that act only where the user is (shortcuts routed to the focused window).
program cb_shortcuts
!< cb_shortcuts, cookbook: keys that act only where the user is (shortcuts routed to the focused window).
!<
!< Two panels bind ctrl+s (cmd+s on macOS): each saves its own content, and only the one with the focus fires. In the
!< block list, up and down move the selection, but not while the name field is edited: there they are the field's
!< (Dear ImGui's keyboard navigation moves out of the field). f5 presses the Run button wherever the focus is. f1 shows the general help, but the command field's own
!< help while that field is edited.
!< `cb_shortcuts --check` opens no window: it presses the keys headless and prints what each did.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, ig_begin, ig_button, ig_end, ig_input_text, ig_selectable, ig_set_next_item_shortcut, &
                   ig_set_next_window, ig_shortcut, ig_text, ig_text_disabled
use figure_testing, only : test_click, test_item_center, test_key, test_type

implicit none
type(app_object)  :: app         !< Application.
character(len=16) :: blocks(4)   !< The block list.
integer(int32)    :: sel         !< Selected block.
character(len=32) :: command     !< The command field.
integer(int32)    :: runs        !< Presses of Run.
character(len=48) :: said        !< What the last key did.
character(len=16) :: arg         !< First argument.
logical           :: check       !< --check: headless, scripted keys.
real(real64)      :: name_at(2)  !< Centre of the name field.
real(real64)      :: cmd_at(2)   !< Centre of the command field.
integer(int32)    :: frame       !< Frame counter.

blocks = ['wing     ', 'fuselage ', 'tail     ', 'nacelle  ']
sel = 1_int32
command = ''
runs = 0_int32
said = ''
call get_command_argument(1, arg)
check = trim(arg) == '--check'
if (check) then
   call app%init_headless(720_int32, 320_int32)
else
   call app%init('FIGURE: shortcuts', 720_int32, 320_int32)
endif
frame = 0_int32
do while (app%next_frame())
   frame = frame + 1_int32
   call draw_blocks()
   call draw_log()
   if (ig_shortcut('f1')) call did('f1: the general help') ! outside every window: unless a window takes f1
   if (check) then
      call press(frame)
      if (frame == 90_int32) exit
   endif
enddo
call app%destroy()

contains
   subroutine draw_blocks()
   !< The block list: up and down move the selection, the field renames the selected block, ctrl+s saves the list,
   !< Run (f5 anywhere) runs the case.
   integer(int32) :: k !< Block.

   call ig_set_next_window(10.0_real64, 10.0_real64, 340.0_real64, 300.0_real64)
   if (ig_begin('Blocks')) then
      do k = 1_int32, size(blocks, kind=int32)
         if (ig_selectable(trim(blocks(k)), k == sel)) sel = k
      enddo
      if (ig_input_text('name', blocks(sel))) continue
      call test_item_center(name_at(1), name_at(2))
      if (ig_shortcut('down')) call did('down: next block', sel + 1_int32) ! this window, not while a field is edited
      if (ig_shortcut('up')) call did('up: previous block', sel - 1_int32)
      if (ig_shortcut('ctrl+s')) call did('ctrl+s: the blocks saved')     ! only when this window has the focus
      call ig_set_next_item_shortcut('f5', scope='global')               ! f5 presses Run, wherever the focus is
      if (ig_button('Run')) then
         runs = runs + 1_int32
         call did('Run pressed')
      endif
      call ig_text_disabled('up/down: select; ctrl+s: save; f5: run')
   endif
   call ig_end()
   endsubroutine draw_blocks

   subroutine draw_log()
   !< The log panel: its own ctrl+s, and a command field with its own f1.
   call ig_set_next_window(370.0_real64, 10.0_real64, 340.0_real64, 300.0_real64)
   if (ig_begin('Log')) then
      call ig_text('runs: '//itoa(runs))
      call ig_text('last key: '//trim(said))
      if (ig_input_text('command', command)) continue
      if (ig_shortcut('f1', scope='item')) call did('f1: help on the command field') ! while it is edited
      call test_item_center(cmd_at(1), cmd_at(2))
      if (ig_shortcut('ctrl+s')) call did('ctrl+s: the log saved')        ! the same chord, this window's own
   endif
   call ig_end()
   endsubroutine draw_log

   subroutine did(what, to)
   !< Record what a key did (and print it in --check); with `to`, select that block (kept in the list).
   character(len=*), intent(in)           :: what !< What happened.
   integer(int32),   intent(in), optional :: to   !< Block to select.

   if (present(to)) sel = max(1_int32, min(size(blocks, kind=int32), to))
   said = what
   if (.not. check) return
   if (present(to)) then
      write(output_unit, '(A,I0,A)') 'frame ', frame, ': '//trim(what)//', selected: '//trim(blocks(sel))
   else
      write(output_unit, '(A,I0,A)') 'frame ', frame, ': '//trim(what)
   endif
   endsubroutine did

   subroutine press(f)
   !< The keys of --check, by frame: each panel focused by a click, then its keys.
   integer(int32), intent(in) :: f !< Frame.

   select case (f)
   case (5_int32)                       ! focus Blocks by its title bar
      call test_click(180.0_real64, 18.0_real64)
   case (10_int32)
      call test_key('down')
   case (16_int32)
      call shortcut('s')
   case (22_int32)                      ! edit the name: down is the field's now
      call test_click(name_at(1), name_at(2))
   case (28_int32)
      call test_key('down')
   case (34_int32)
      call test_key('escape')
   case (40_int32)                      ! focus Log by its title bar
      call test_click(540.0_real64, 18.0_real64)
   case (46_int32)
      call shortcut('s')
   case (52_int32)                      ! Blocks has no focus: its up and down stay still
      call test_key('down')
   case (58_int32)                      ! f5 presses Run from here too
      call test_key('f5')
   case (64_int32)                      ! f1 while the command field is edited: its own help
      call test_click(cmd_at(1), cmd_at(2))
   case (70_int32)
      call test_key('f1')
   case (76_int32)                      ! the field no longer edited: the general help
      call test_key('escape')
   case (82_int32)
      call test_key('f1')
   endselect
   endsubroutine press

   subroutine shortcut(key)
   !< Press the platform's shortcut key with `key` (ctrl; cmd on macOS).
   character(len=*), intent(in) :: key !< Key name.

   call test_key('shortcut', down=.true.)
   call test_key(key)
   call test_key('shortcut', down=.false.)
   endsubroutine shortcut

   function itoa(i) result(s)
   !< An integer as text.
   integer(int32), intent(in)    :: i !< Value.
   character(len=:), allocatable :: s !< Text.
   character(len=12)             :: buf !< Buffer.

   write(buf, '(I0)') i
   s = trim(buf)
   endfunction itoa
endprogram cb_shortcuts
