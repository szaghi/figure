!< cb_menu, cookbook: a File menu in the main menu bar, and its shortcut (ctrl+s, cmd+s on macOS).
program cb_menu
!< cb_menu, cookbook: a File menu in the main menu bar, and its shortcut (ctrl+s, cmd+s on macOS).
!<
!< `cb_menu --remote PORT` serves the same interface to a web browser.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_begin_main_menu_bar, ig_begin_menu, ig_end, ig_end_main_menu_bar, &
                   ig_end_menu, ig_input_text, ig_menu_item, ig_separator, ig_set_next_window, ig_shortcut, ig_text

implicit none
type(app_object)   :: app       !< Application.
character(len=64)  :: title     !< The document: one field.
logical            :: autosave  !< A check-mark item.
logical            :: edited    !< Changed since the last save.
logical            :: running   !< False once Quit is picked.
integer(int32)     :: saves     !< Saves so far.
character(len=64)  :: status    !< The status line.
character(len=16)  :: arg       !< Command-line argument.
integer(int32)     :: port      !< Port of remote mode.

title = 'untitled'
autosave = .false.
edited = .false.
running = .true.
saves = 0_int32
status = 'not saved yet'
call get_command_argument(1, arg)
if (trim(arg) == '--remote') then
   call get_command_argument(2, arg)
   read(arg, *) port
   call app%init_remote(port=port, width=720_int32, height=300_int32)
else
   call app%init('FIGURE: menus', 720_int32, 300_int32)
endif
do while (running)
   if (.not. app%next_frame()) exit
   if (ig_begin_main_menu_bar()) then
      if (ig_begin_menu('File')) then
         if (ig_menu_item('Save', shortcut='Ctrl+S', enabled=edited)) call save()
         if (ig_menu_item('Autosave', selected=autosave)) continue
         call ig_separator()
         if (ig_menu_item('Quit')) running = .false.
         call ig_end_menu()
      endif
      call ig_end_main_menu_bar()
   endif
   if (ig_shortcut('ctrl+s') .and. edited) call save()     ! every frame, outside the menu
   call ig_set_next_window(10.0_real64, 30.0_real64, 700.0_real64, 260.0_real64)
   if (ig_begin('Document')) then
      if (ig_input_text('title', title)) then
         edited = .true.
         if (autosave) call save()
      endif
      call ig_text(trim(status)//merge(' (edited)', '         ', edited))
   endif
   call ig_end()
enddo
call app%destroy()

contains
   subroutine save()
   !< What Save would do: here, count and say so.
   saves = saves + 1_int32
   edited = .false.
   write(status, '(A,I0,A)') 'saved ', saves, ' time(s): "'//trim(title)//'"'
   endsubroutine save
endprogram cb_menu
