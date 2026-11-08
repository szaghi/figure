!< tut09_case, tutorial chapter 9: the studio opens a case, from FIGURE's file browser or a drop, and asks before it
!< discards changes.
program tut09_case
!< tut09_case, tutorial chapter 9: the studio opens a case, from FIGURE's file browser or a drop, and asks before it
!< discards changes.
!<
!< A case is a folder with an input file, `heat.inp`, a namelist. The studio opens one with FIGURE's file browser (or
!< the system's dialog), from a folder or file dropped on the window, or from the recent cases; it shows the case's
!< title and parameters, lets the title be edited and saved, and asks before an open or a quit discards an edit.
!< `tut09_case --examples DIR` first writes two example cases into DIR (fixed contents and times, for the pictures)
!< and starts the browser there.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, FIG_OK, figure_last_error, ICON_CHART_AREA, ICON_FILE_PEN, ICON_FLAME, ICON_FOLDER, &
                   ICON_FOLDER_OPEN, ICON_HISTORY, ICON_INFO, ICON_LAYOUT, ICON_PALETTE, ICON_PLAY,              &
                   ICON_POWER_SQUARE, ICON_SAVE, ig_begin, ig_begin_disabled, ig_begin_main_menu_bar,           &
                   ig_begin_menu, ig_begin_popup_modal, ig_begin_side_bar, ig_button, ig_close_current_popup,   &
                   ig_dock_id, ig_dock_layout_begin, ig_dock_layout_end, ig_dock_space, ig_dock_split,          &
                   ig_dock_window, ig_end, ig_end_disabled, ig_end_main_menu_bar, ig_end_menu, ig_end_popup,    &
                   ig_focus_window, ig_input_text, ig_menu_item, ig_open_popup, ig_same_line, ig_separator,     &
                   ig_set_next_window, ig_shortcut, ig_text, ig_text_disabled, ig_text_wrapped, ig_tool_button, ig_tooltip

implicit none
character(len=*), parameter :: PANELS(4) = [character(len=6) :: 'Case', 'Input', 'Run', 'Result'] !< The panels.
character(len=*), parameter :: LOOKS(4) = [character(len=7) :: 'seal', 'fusion', 'adwaita', 'fluent'] !< Looks.
character(len=*), parameter :: PALETTES(6) = [character(len=16) :: 'seal', 'seal-light', 'nord', 'gruvbox-dark', &
                                              'solarized-light', 'catppuccin-latte'] !< Some of the palettes.
character(len=*), parameter :: DEFAULT_LAYOUT = 'tut09_case-default.layout' !< The layout as the program sets it.
character(len=*), parameter :: INPUT_FILE = 'heat.inp' !< The input file of a case.
integer(int32),   parameter :: MAX_RECENT = 5_int32    !< Recent cases kept.

type :: case_t
   !< The input of a case: what heat.inp holds.
   character(len=64) :: title = 'Heated plate'                    !< Title.
   integer(int32)    :: nx = 48_int32                             !< Grid points along x.
   integer(int32)    :: ny = 32_int32                             !< Grid points along y.
   real(real64)      :: lx = 1.5_real64                           !< Plate width [m].
   real(real64)      :: ly = 1.0_real64                           !< Plate height [m].
   character(len=12) :: bc_kind(4) = [character(len=12) :: 'fixed', 'insulated', 'fixed', 'fixed'] !< West, east,
                                                                  !< south, north: 'fixed' or 'insulated'.
   real(real64)      :: bc_value(4) = [100.0_real64, 0.0_real64, 20.0_real64, 20.0_real64] !< Their temperatures [C].
   real(real64)      :: body_x = 0.9_real64                       !< The body's centre, x [m].
   real(real64)      :: body_y = 0.5_real64                       !< The body's centre, y [m].
   real(real64)      :: body_r = 0.15_real64                      !< The body's radius [m].
   real(real64)      :: body_t = 0.0_real64                       !< The body's temperature [C].
   real(real64)      :: omega = 1.8_real64                        !< Over-relaxation factor.
   real(real64)      :: tolerance = 1.0e-6_real64                 !< Residual to reach.
   integer(int32)    :: max_iter = 4000_int32                     !< Iterations at most.
endtype case_t

type(app_object)              :: app              !< Application.
type(case_t)                  :: inp              !< The case's input.
character(len=:), allocatable :: case_dir         !< The case's folder ('' none).
character(len=:), allocatable :: start_dir        !< Where the browser starts.
character(len=:), allocatable :: pending_action   !< What waits for the answer to "Discard changes?": open, quit.
character(len=:), allocatable :: pending_dir      !< The case to open then.
character(len=256)            :: recent(MAX_RECENT) !< Recent cases, newest first.
character(len=512)            :: arg              !< An argument.
character(len=16)             :: look             !< The look in effect.
character(len=16)             :: palette          !< The palette in effect.
logical                       :: shown(4)         !< The panels shown.
logical                       :: edited           !< The input changed since it was read or saved.
logical                       :: ask_quit         !< File > Quit or its shortcut.
logical                       :: ask_discard      !< Open the question "Discard changes?".
logical                       :: about            !< Help > About or its shortcut.
logical                       :: save_default     !< Save the layout set by the program, at the next frame.
logical                       :: have_default     !< The default layout is saved.
integer(int32)                :: current          !< The workspace chosen in the bar.
integer(int32)                :: nrecent          !< Recent cases kept.

case_dir = ''
start_dir = '.'
pending_action = ''
pending_dir = ''
nrecent = 0_int32
edited = .false.
ask_quit = .false.
ask_discard = .false.
about = .false.
shown = .true.
current = 1_int32
look = 'seal'
palette = 'seal'
save_default = .false.
inquire(file=DEFAULT_LAYOUT, exist=have_default)
call get_command_argument(1, arg)
if (trim(arg) == '--examples') then
   call get_command_argument(2, arg)
   call write_examples(trim(arg))
   start_dir = trim(arg)
endif
call open_window()
do while (app%next_frame())
   call draw_studio()
enddo
call app%destroy()

contains
   subroutine open_window()
   !< Open the studio's window, its frame drawn by FIGURE, its layout kept in a file between runs.
   integer(int32) :: stat !< Status of the icon.

   call app%init('FIGURE studio', 1100_int32, 680_int32, decorations='figure', ini_file='tut09_case.ini')
   call app%set_icon(ICON_FLAME, stat=stat)
   if (stat /= FIG_OK) write(output_unit, '(A)') 'no window icon here: '//figure_last_error()
   call app%set_confirm_quit(.true.)
   endsubroutine open_window

   subroutine draw_studio()
   !< One frame of the studio.
   call draw_menus()
   call take_answers()
   call draw_tools()
   call draw_panels()
   call draw_dialogs()
   endsubroutine draw_studio

   subroutine draw_menus()
   !< The menus, in the title bar, and their shortcuts.
   integer(int32) :: k    !< Counter.
   logical        :: on   !< A check mark.
   integer(int32) :: stat !< Status of the system's dialog.

   if (ig_begin_main_menu_bar()) then
      !region file-menu
      if (ig_begin_menu('File')) then
         if (ig_menu_item(ICON_FOLDER_OPEN//' Open case...', shortcut='Ctrl+O')) call browse_case()
         if (ig_menu_item('Open case with the system''s dialog...')) then
            call app%open_folder_dialog('case', default_path=start_dir, stat=stat)
            if (stat /= FIG_OK) call browse_case()      ! no desktop (remote mode): FIGURE's browser
         endif
         if (ig_begin_menu(ICON_HISTORY//' Recent cases', enabled=nrecent > 0_int32)) then
            do k = 1_int32, nrecent
               if (ig_menu_item(trim(recent(k)))) call request('open', trim(recent(k)))
            enddo
            call ig_end_menu()
         endif
         if (ig_menu_item(ICON_SAVE//' Save', shortcut='Ctrl+S', enabled=edited)) call save_case()
         call ig_separator()
         if (ig_menu_item(ICON_POWER_SQUARE//' Quit', shortcut='Ctrl+Q')) ask_quit = .true.
         call ig_end_menu()
      endif
      !endregion file-menu
      if (ig_begin_menu('View')) then
         do k = 1_int32, size(PANELS, kind=int32)
            if (ig_menu_item(trim(PANELS(k)), selected=shown(k))) continue
         enddo
         call ig_separator()
         if (ig_begin_menu(ICON_LAYOUT//' Look')) then
            do k = 1_int32, size(LOOKS, kind=int32)
               on = look == LOOKS(k)
               if (ig_menu_item(trim(LOOKS(k)), selected=on)) call set_look(trim(LOOKS(k)))
            enddo
            call ig_end_menu()
         endif
         if (ig_begin_menu(ICON_PALETTE//' Palette')) then
            do k = 1_int32, size(PALETTES, kind=int32)
               on = palette == PALETTES(k)
               if (ig_menu_item(trim(PALETTES(k)), selected=on)) call set_palette(trim(PALETTES(k)))
            enddo
            call ig_end_menu()
         endif
         call ig_separator()
         if (ig_menu_item('Reset layout', enabled=have_default)) call app%load_layout(DEFAULT_LAYOUT)
         call ig_end_menu()
      endif
      if (ig_begin_menu('Help')) then
         if (ig_menu_item(ICON_INFO//' About', shortcut='F1')) about = .true.
         call ig_end_menu()
      endif
      call ig_end_main_menu_bar()
   endif
   if (ig_shortcut('ctrl+o')) call browse_case()
   if (ig_shortcut('ctrl+s') .and. edited) call save_case()
   if (ig_shortcut('ctrl+q')) ask_quit = .true.
   if (ig_shortcut('f1')) about = .true.
   endsubroutine draw_menus

   subroutine browse_case()
   !< FIGURE's file browser, choosing a folder: the same in a window, in remote mode and in a test.
   !region browse
   call app%open_file_browser('case', default_path=start_dir, folders=.true.) ! answered on a later frame
   !endregion browse
   endsubroutine browse_case

   subroutine take_answers()
   !< The answers that arrive on this frame: the browser's or the dialog's, and the folders or files dropped.
   character(len=:), allocatable :: chosen    !< Path from the browser.
   character(len=:), allocatable :: paths(:)  !< Paths dropped.
   logical                       :: done      !< The browser was answered.
   logical                       :: cancelled !< ... by Cancel.
   integer(int32)                :: stat      !< Status of the answer.

   !region answers
   call app%file_dialog_result('case', chosen, done, cancelled, stat=stat) ! the browser's or the system's dialog
   if (done .and. .not. cancelled) then
      if (stat == FIG_OK) then
         call request('open', chosen)
      else
         call app%notify(figure_last_error(), kind='error')                 ! the dialog could not be shown
      endif
   endif
   if (app%dropped(paths)) call request('open', case_folder(trim(paths(1)))) ! a case folder, or its heat.inp
   !endregion answers
   endsubroutine take_answers

   subroutine request(action, dir)
   !< Open a case or quit, after asking whether to discard the changes if there are some.
   character(len=*), intent(in)           :: action !< 'open' or 'quit'.
   character(len=*), intent(in), optional :: dir    !< The case to open.

   !region request
   pending_action = action
   pending_dir = ''
   if (present(dir)) pending_dir = dir
   if (edited) then
      ask_discard = .true.                           ! the question is opened at the top level, in draw_dialogs
   else
      call go_on()
   endif
   !endregion request
   endsubroutine request

   subroutine go_on()
   !< Do what was requested.
   select case (pending_action)
   case ('open')
      call open_case(pending_dir)
   case ('quit')
      call app%quit()
   endselect
   pending_action = ''
   endsubroutine go_on

   subroutine open_case(dir)
   !< Read the case of folder `dir`; a folder without an input file is not a case.
   character(len=*), intent(in)  :: dir  !< The case's folder.
   type(case_t)                  :: new  !< Its input.
   character(len=:), allocatable :: msg  !< What went wrong.
   integer(int32)                :: stat !< Status of the read.

   call read_case(dir//'/'//INPUT_FILE, new, stat, msg)
   if (stat /= 0) then
      call app%notify('Not a case: '//msg, kind='warning')
      return
   endif
   inp = new
   case_dir = dir
   edited = .false.
   call add_recent(dir)
   call show_title()
   call app%notify('Opened '//trim(inp%title), kind='success')
   endsubroutine open_case

   subroutine save_case()
   !< Write the input back to the case's file.
   integer(int32) :: stat !< Status of the write.

   call write_case(case_dir//'/'//INPUT_FILE, inp, stat)
   if (stat /= 0) then
      call app%notify('Cannot write '//case_dir//'/'//INPUT_FILE, kind='error')
      return
   endif
   edited = .false.
   call show_title()
   endsubroutine save_case

   subroutine show_title()
   !< The window's title: the case, marked while it has unsaved changes.
   !region title
   if (edited) then                                  ! in the bar drawn by FIGURE, and the task bar's
      call app%set_title('* '//trim(inp%title)//' - FIGURE studio')
   else
      call app%set_title(trim(inp%title)//' - FIGURE studio')
   endif
   !endregion title
   endsubroutine show_title

   subroutine add_recent(dir)
   !< Put `dir` first in the recent cases.
   character(len=*), intent(in) :: dir !< The case's folder.
   integer(int32)               :: k   !< Counter.

   do k = 1_int32, nrecent
      if (recent(k) == dir) exit
   enddo
   if (k > nrecent) nrecent = min(nrecent + 1_int32, MAX_RECENT)
   recent(2:min(k, MAX_RECENT)) = recent(1:min(k, MAX_RECENT) - 1)
   recent(1) = dir
   endsubroutine add_recent

   subroutine draw_tools()
   !< The workspace buttons, in a bar along the left side: a click brings the panel forward.
   character(len=*), parameter :: ICONS(4) = [character(len=4) :: ICON_FOLDER, ICON_FILE_PEN, ICON_PLAY, ICON_CHART_AREA]
   integer(int32)              :: k !< Counter.

   if (ig_begin_side_bar('tools', 'left', 76.0_real64)) then
      do k = 1_int32, size(PANELS, kind=int32)
         if (ig_tool_button(trim(PANELS(k)), trim(ICONS(k)), width=60.0_real64, selected=current == k)) then
            current = k
            shown(k) = .true.
            if (ig_focus_window(trim(PANELS(k)))) continue
         endif
         call ig_tooltip('Show the '//trim(PANELS(k))//' panel')
      enddo
   endif
   call ig_end()
   endsubroutine draw_tools

   subroutine draw_panels()
   !< The dock space and the four panels.
   integer(int32) :: root  !< The dock space.
   integer(int32) :: left  !< The case's column.
   integer(int32) :: right !< The rest.
   integer(int32) :: work  !< Input and Result, tabs of one node.
   integer(int32) :: run   !< Run, below them.

   if (save_default) then
      call app%save_layout(DEFAULT_LAYOUT, comment='the studio as the program lays it out')
      if (ig_focus_window('Input')) continue                 ! of the two tabs, Input in front
      have_default = .true.
      save_default = .false.
   endif
   root = ig_dock_id('studio')
   if (ig_dock_layout_begin(root)) then
      call ig_dock_split(root, 'left', 0.25_real64, left, right)
      call ig_dock_split(right, 'down', 0.35_real64, run, work)
      call ig_dock_window('Case', left)
      call ig_dock_window('Result', work)
      call ig_dock_window('Input', work)
      call ig_dock_window('Run', run)
      call ig_dock_layout_end(root)
      save_default = .true.
   endif
   call ig_dock_space(root)
   if (shown(1)) then
      if (ig_begin('Case', open=shown(1))) call draw_case()
      call ig_end()
   endif
   if (shown(2)) then
      if (ig_begin('Input', open=shown(2))) call ig_text_disabled('The input of the case, once one is open.')
      call ig_end()
   endif
   if (shown(3)) then
      if (ig_begin('Run', open=shown(3))) call ig_text_disabled('The solver, its log and its residuals.')
      call ig_end()
   endif
   if (shown(4)) then
      if (ig_begin('Result', open=shown(4))) call ig_text_disabled('The field the solver computed.')
      call ig_end()
   endif
   endsubroutine draw_panels

   subroutine draw_case()
   !< The Case panel: the folder, the title (editable), the parameters.
   character(len=96) :: line !< A formatted line.

   !region case
   if (len(case_dir) == 0) then
      call ig_text_disabled('No case open.')
      call ig_text_wrapped('Open one with File > Open case, or drop its folder (or its heat.inp) on the window.')
      if (ig_button(ICON_FOLDER_OPEN//' Open case...')) call browse_case()
      return
   endif
   call ig_text(ICON_FOLDER//' '//case_dir)
   if (ig_input_text('title', inp%title)) then        ! the field edits the variable in place
      edited = .true.
      call show_title()
   endif
   write(line, '(A,I0,A,I0,5A)') 'grid ', inp%nx, ' x ', inp%ny, ', plate ', num(inp%lx), ' m x ', num(inp%ly), ' m'
   call ig_text(trim(line))
   write(line, '(A,F0.2,A,ES7.1,A,I0)') 'omega ', inp%omega, ', tolerance ', inp%tolerance, ', at most ', inp%max_iter
   call ig_text(trim(line))
   call ig_begin_disabled(.not. edited)
   if (ig_button(ICON_SAVE//' Save')) call save_case()
   call ig_end_disabled()
   !endregion case
   endsubroutine draw_case

   subroutine draw_dialogs()
   !< The questions and boxes the menus and the frame open, at the top level.
   !region dialogs
   if (app%quit_requested() .or. ask_quit) then      ! the close button, File > Quit or ctrl+q
      ask_quit = .false.
      call request('quit')                           ! nothing to lose: quit at once
   endif
   if (ask_discard) then
      call ig_open_popup('Discard changes?')
      ask_discard = .false.
   endif
   if (ig_begin_popup_modal('Discard changes?')) then
      call ig_text('"'//trim(inp%title)//'" has unsaved changes.')
      if (ig_button(ICON_SAVE//' Save')) then
         call save_case()
         call ig_close_current_popup()
         call go_on()
      endif
      call ig_same_line()
      if (ig_button('Discard')) then
         call ig_close_current_popup()
         call go_on()
      endif
      call ig_same_line()
      if (ig_button('Cancel')) then
         pending_action = ''
         call ig_close_current_popup()
      endif
      call ig_end_popup()
   endif
   !endregion dialogs
   if (about) then
      call ig_open_popup('About the studio')
      about = .false.
   endif
   call ig_set_next_window(400.0_real64, 230.0_real64, 320.0_real64, 160.0_real64) ! where it opens, and its size
   if (ig_begin_popup_modal('About the studio')) then
      call ig_text(ICON_FLAME//' FIGURE studio')
      call ig_text_wrapped('The solver studio of FIGURE''s tutorial: a case, its input, a run of the solver and '// &
                           'its result, in one window.')
      call ig_text('Look: '//trim(look)//', palette: '//trim(palette))
      if (ig_button('Close')) call ig_close_current_popup()
      call ig_end_popup()
   endif
   endsubroutine draw_dialogs

   subroutine set_look(name)
   !< The look (the geometry) changes; the palette stays.
   character(len=*), intent(in) :: name !< Look.

   call app%set_style(look=name)
   look = name
   endsubroutine set_look

   subroutine set_palette(name)
   !< The palette (the colours) changes; the look stays.
   character(len=*), intent(in) :: name !< Palette.

   call app%set_style(palette=name)
   palette = name
   endsubroutine set_palette

   function case_folder(path) result(dir)
   !< The case folder of a dropped path: the path itself, or the folder of a dropped input file.
   character(len=*), intent(in)  :: path !< Path dropped.
   character(len=:), allocatable :: dir  !< The case's folder.
   integer(int32)                :: n    !< Length of the input file's name.

   n = len(INPUT_FILE)
   dir = path
   if (len(path) > n) then
      if (path(len(path) - n + 1:) == INPUT_FILE) dir = path(:len(path) - n - 1)
   endif
   endfunction case_folder

   !region read
   subroutine read_case(file, c, stat, msg)
   !< Read a case's input, the namelist `&heat` of `file`.
   character(len=*),              intent(in)  :: file        !< Input file.
   type(case_t),                  intent(out) :: c           !< Its input (defaults where the file is silent).
   integer(int32),                intent(out) :: stat        !< Status: 0 read.
   character(len=:), allocatable, intent(out) :: msg         !< What went wrong.
   character(len=64)                          :: title       !< Namelist copies of the components.
   integer(int32)                             :: nx, ny, max_iter
   real(real64)                               :: lx, ly, bc_value(4), body_x, body_y, body_r, body_t, omega, tolerance
   character(len=12)                          :: bc_kind(4)
   character(len=256)                         :: iomsg       !< The run time's message.
   integer(int32)                             :: u           !< Unit.
   namelist /heat/ title, nx, ny, lx, ly, bc_kind, bc_value, body_x, body_y, body_r, body_t, omega, tolerance, max_iter

   title = c%title; nx = c%nx; ny = c%ny; lx = c%lx; ly = c%ly; bc_kind = c%bc_kind; bc_value = c%bc_value
   body_x = c%body_x; body_y = c%body_y; body_r = c%body_r; body_t = c%body_t
   omega = c%omega; tolerance = c%tolerance; max_iter = c%max_iter
   msg = ''
   open(newunit=u, file=file, status='old', action='read', iostat=stat, iomsg=iomsg)
   if (stat /= 0) then
      msg = 'no '//INPUT_FILE//' in '//file(:max(0, len(file) - len(INPUT_FILE) - 1))
      return
   endif
   read(u, nml=heat, iostat=stat, iomsg=iomsg)
   close(u)
   if (stat /= 0) then
      msg = file//': '//trim(iomsg)
      return
   endif
   c = case_t(title, nx, ny, lx, ly, bc_kind, bc_value, body_x, body_y, body_r, body_t, omega, tolerance, max_iter)
   endsubroutine read_case
   !endregion read

   subroutine write_case(file, c, stat)
   !< Write a case's input as the namelist `&heat`, one group of parameters per line.
   character(len=*), intent(in)  :: file !< Input file.
   type(case_t),     intent(in)  :: c    !< Its input.
   integer(int32),   intent(out) :: stat !< Status: 0 written.
   integer(int32)                :: u    !< Unit.

   open(newunit=u, file=file, status='replace', action='write', iostat=stat)
   if (stat /= 0) return
   write(u, '(A)') '&heat'
   write(u, '(A)') "  title = '"//trim(c%title)//"'"
   write(u, '(A,I0,A,I0,A,A,A,A)') '  nx = ', c%nx, ', ny = ', c%ny, ', lx = ', num(c%lx), ', ly = ', num(c%ly)
   write(u, '(A)') "  bc_kind = '"//trim(c%bc_kind(1))//"', '"//trim(c%bc_kind(2))//"', '"//trim(c%bc_kind(3))// &
                   "', '"//trim(c%bc_kind(4))//"'  ! west, east, south, north"
   write(u, '(8A)') '  bc_value = ', num(c%bc_value(1)), ', ', num(c%bc_value(2)), ', ', num(c%bc_value(3)), ', ', &
                    num(c%bc_value(4))
   write(u, '(8A)') '  body_x = ', num(c%body_x), ', body_y = ', num(c%body_y), ', body_r = ', num(c%body_r), &
                    ', body_t = ', num(c%body_t)
   write(u, '(A,A,A,ES7.1,A,I0)') '  omega = ', num(c%omega), ', tolerance = ', c%tolerance, ', max_iter = ', c%max_iter
   write(u, '(A)') '/'
   close(u)
   endsubroutine write_case

   function num(x) result(s)
   !< A number as the input file shows it: three decimals, no leading blanks.
   real(real64), intent(in)      :: x   !< Number.
   character(len=:), allocatable :: s   !< Text.
   character(len=24)             :: buf !< Buffer.

   write(buf, '(F12.3)') x
   s = trim(adjustl(buf))
   endfunction num

   subroutine write_examples(folder)
   !< Two example cases in `folder`, all modified on 2026-10-15 at fixed times (`touch -t`, POSIX), for the pictures.
   character(len=*), intent(in) :: folder !< Folder.
   type(case_t)                 :: c      !< An input.
   integer(int32)               :: stat   !< Status.

   call execute_command_line('mkdir -p "'//folder//'/plate" "'//folder//'/channel"', exitstat=stat)
   call write_case(folder//'/plate/'//INPUT_FILE, c, stat)
   c%title = 'Cooled channel'
   c%nx = 64_int32
   c%ny = 24_int32
   c%lx = 2.0_real64
   c%ly = 0.75_real64
   c%bc_kind = [character(len=12) :: 'fixed', 'fixed', 'insulated', 'insulated']
   c%bc_value = [80.0_real64, 10.0_real64, 0.0_real64, 0.0_real64]
   c%body_x = 1.0_real64
   c%body_y = 0.375_real64
   c%body_r = 0.2_real64
   call write_case(folder//'/channel/'//INPUT_FILE, c, stat)
   call execute_command_line('touch -t 202610150910 "'//folder//'"/*/'//INPUT_FILE//' "'//folder//'"/*/', exitstat=stat)
   endsubroutine write_examples
endprogram tut09_case
