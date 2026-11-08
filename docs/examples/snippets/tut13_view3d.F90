!< tut13_view3d, tutorial chapter 13: the studio shows the field in 3-D, a surface coloured by the temperature, with
!< the body, the camera, a cut and picking.
program tut13_view3d
!< tut13_view3d, tutorial chapter 13: the studio shows the field in 3-D, a surface coloured by the temperature, with
!< the body, the camera, a cut and picking.
!<
!< Chapter 12's studio, with a 3-D panel: the temperature as a surface over the plate, its height and its colour the
!< temperature, the body as a cylinder; standard views, the grid, a cut along the probe line, and a click on the surface
!< that moves the Result panel's probe point there. `tut13_view3d --examples DIR` writes the example cases into DIR;
!< `--case DIR` opens the case DIR at the start.
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, FIG_OK, figure_last_error, ICON_CHART_AREA, ICON_CHECK, ICON_FILE_PEN, ICON_FLAME, &
                   ICON_FOLDER, ICON_FOLDER_OPEN, ICON_HISTORY, ICON_INFO, ICON_LAYOUT, ICON_PALETTE, ICON_PLAY, &
                   ICON_POWER_SQUARE, ICON_ROTATE_3D, ICON_SAVE, ICON_SQUARE, ICON_TRIANGLE_ALERT, ICON_UNDO, &
                   ig_begin, ig_begin_child, ig_begin_disabled, ig_begin_main_menu_bar, ig_begin_menu, &
                   ig_begin_popup_modal, ig_begin_side_bar, ig_begin_tab, ig_begin_tab_bar, ig_begin_table, &
                   ig_button, ig_checkbox, ig_close_current_popup, ig_combo, ig_dock_id, ig_dock_layout_begin, &
                   ig_dock_layout_end, ig_dock_space, ig_dock_split, ig_dock_window, ig_end, ig_end_child, &
                   ig_end_disabled, ig_end_main_menu_bar, ig_end_menu, ig_end_popup, ig_end_tab, ig_end_tab_bar, &
                   ig_end_table, ig_focus_window, ig_input, ig_input_text, ig_input_text_multiline, ig_menu_item, &
                   ig_open_popup, ig_pop_font, ig_pop_id, ig_progress_bar, ig_push_font, ig_push_id, ig_same_line, &
                   ig_separator, ig_set_next_item_width, ig_set_next_window, ig_shortcut, ig_slider, &
                   ig_table_headers_row, ig_table_next_column, ig_table_next_row, ig_table_setup_column, ig_text, &
                   ig_text_colored, ig_text_disabled, ig_text_wrapped, ig_tool_button, ig_tooltip, ig_tree_node, &
                   ig_tree_pop, ip_annotation, ip_begin_plot, ip_colormap, ip_colormap_legend, ip_contour, &
                   ip_drag_line_x, ip_drag_point, ip_end_plot, ip_error_bars, ip_heatmap, ip_line, ip_setup_axes, &
                   ip_setup_axes_limits, ip_spec, log_view_object, process_object, text_buffer_object, view3d_object

implicit none
character(len=*), parameter :: PANELS(5) = [character(len=6) :: 'Case', 'Input', 'Run', 'Result', '3-D'] !< Panels.
character(len=*), parameter :: LOOKS(4) = [character(len=7) :: 'seal', 'fusion', 'adwaita', 'fluent'] !< Looks.
character(len=*), parameter :: PALETTES(6) = [character(len=16) :: 'seal', 'seal-light', 'nord', 'gruvbox-dark', &
                                              'solarized-light', 'catppuccin-latte'] !< Some of the palettes.
character(len=*), parameter :: DEFAULT_LAYOUT = 'tut13_view3d-default.layout' !< The layout as the program sets it.
character(len=*), parameter :: INPUT_FILE = 'heat.inp' !< The input file of a case.
integer(int32),   parameter :: MAX_RECENT = 5_int32    !< Recent cases kept.
integer(int32),   parameter :: MAX_UNDO = 32_int32     !< Edits that Undo can take back.
character(len=*), parameter :: SIDES(4) = [character(len=5) :: 'west', 'east', 'south', 'north'] !< The plate's sides.
character(len=*), parameter :: KINDS(2) = [character(len=9) :: 'fixed', 'insulated'] !< Boundary conditions.
character(len=*), parameter :: MAPS(6) = [character(len=9) :: 'cividis', 'batlow', 'Viridis', 'cool-warm', &
                                          'turbo', 'Jet'] !< Colormaps offered (ImPlot's own capitalized).
character(len=*), parameter :: SECTIONS(4) = [character(len=10) :: 'Grid', 'Boundaries', 'Body', 'Solver'] !< Of heat.inp.

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
type(case_t)                  :: history(MAX_UNDO) !< The input before each edit, the latest last.
type(text_buffer_object)      :: source           !< The input file as text.
type(process_object)          :: solver           !< The solver's run.
type(log_view_object)         :: output           !< What it prints.
real(real64), allocatable     :: iters(:)         !< The iterations printed so far.
real(real64), allocatable     :: res(:)           !< Their residuals.
character(len=:), allocatable :: solver_path      !< The solver: tut11_heat, next to this program.
character(len=96)             :: run_status       !< The run's state, for the status bar.
logical                       :: started          !< A run was started (its end not reported yet).
real(real64), allocatable, target :: field(:,:)   !< The temperature field(i, j) at x = (i - 1) dx, y = (j - 1) dy [C].
real(real64)                  :: flx, fly         !< The field's plate [m].
real(real64)                  :: probe_x          !< The probe line's abscissa [m].
real(real64)                  :: point(2)         !< The probe point [m].
integer(int32)                :: map              !< The colormap, an index of MAPS.
integer(int32)                :: bands            !< Bands of the colormap (0: continuous).
logical                       :: contours         !< Contour lines over the heatmap.
logical                       :: show_result      !< Bring the Result panel forward at the next frame.
type(view3d_object)           :: view             !< The 3-D view.
real(real64), allocatable, target :: carpet(:,:,:) !< The temperature as a surface: node (i, j) at carpet(:, i, j).
real(real64), target          :: body(3, 49, 2)   !< The body: a cylinder, around and up.
integer(int32)                :: carpet_mesh      !< Mesh ids in the view.
integer(int32)                :: body_mesh
logical                       :: grid3d           !< The surface's grid lines shown.
logical                       :: cut              !< The view cut along the probe line.
character(len=64)             :: picked           !< What the pointer is on, in the 3-D view.
character(len=:), allocatable :: case_dir         !< The case's folder ('' none).
character(len=:), allocatable :: start_dir        !< Where the browser starts.
character(len=:), allocatable :: pending_action   !< What waits for the answer to "Discard changes?": open, quit.
character(len=:), allocatable :: pending_dir      !< The case to open then.
character(len=256)            :: recent(MAX_RECENT) !< Recent cases, newest first.
character(len=512)            :: arg              !< An argument.
character(len=16)             :: look             !< The look in effect.
character(len=16)             :: palette          !< The palette in effect.
logical                       :: shown(5)         !< The panels shown.
logical                       :: edited           !< The input changed since it was read or saved.
logical                       :: ask_quit         !< File > Quit or its shortcut.
logical                       :: ask_discard      !< Open the question "Discard changes?".
logical                       :: about            !< Help > About or its shortcut.
logical                       :: save_default     !< Save the layout set by the program, at the next frame.
logical                       :: have_default     !< The default layout is saved.
integer(int32)                :: current          !< The workspace chosen in the bar.
integer(int32)                :: nrecent          !< Recent cases kept.
integer(int32)                :: nhistory         !< Edits kept for Undo.
integer(int32)                :: section          !< The section of the input shown in the form.
logical                       :: text_edited      !< The text was edited and not applied yet.
logical                       :: was_changing     !< The form changed the input in the last frame.
logical                       :: form_shown       !< The form's tab is in front.
integer(int32)                :: a                !< Argument counter.

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
nhistory = 0_int32
section = 1_int32
text_edited = .false.
was_changing = .false.
form_shown = .true.
allocate(iters(0), res(0))
run_status = 'ready'
allocate(field(0, 0))
probe_x = 0.0_real64
point = 0.0_real64
map = 1_int32
bands = 0_int32
contours = .true.
show_result = .false.
grid3d = .false.
cut = .false.
picked = ''
allocate(carpet(3, 0, 0))
started = .false.
call get_command_argument(0, arg)
solver_path = arg(:index(arg, '/', back=.true.))//'tut11_heat' ! the solver is installed next to the studio
inquire(file=DEFAULT_LAYOUT, exist=have_default)
call open_window()
a = 1_int32
do while (a <= command_argument_count())
   call get_command_argument(a, arg)
   select case (trim(arg))
   case ('--examples')                               ! write the example cases there, start the browser there
      call get_command_argument(a + 1_int32, arg)
      call write_examples(trim(arg))
      start_dir = trim(arg)
      a = a + 1_int32
   case ('--case')                                   ! open this case at the start
      call get_command_argument(a + 1_int32, arg)
      call open_case(trim(arg))
      a = a + 1_int32
   endselect
   a = a + 1_int32
enddo
do while (app%next_frame())
   call draw_studio()
enddo
call view%destroy()                                  ! before the application
call app%destroy()

contains
   subroutine open_window()
   !< Open the studio's window, its frame drawn by FIGURE, its layout kept in a file between runs.
   integer(int32) :: stat !< Status of the icon.

   call app%init('FIGURE studio', 1100_int32, 680_int32, decorations='figure', ini_file='tut13_view3d.ini')
   call app%set_icon(ICON_FLAME, stat=stat)
   if (stat /= FIG_OK) write(output_unit, '(A)') 'no window icon here: '//figure_last_error()
   call app%set_confirm_quit(.true.)
   call view%init()                                  ! after app%init
   endsubroutine open_window

   subroutine draw_studio()
   !< One frame of the studio.
   call draw_menus()
   call take_answers()
   call follow_run()
   call draw_status()                                 ! first: the status bar spans the whole width
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
      if (ig_begin_menu('Edit')) then
         if (ig_menu_item(ICON_UNDO//' Undo', shortcut='Ctrl+Z', enabled=nhistory > 0_int32)) call undo()
         call ig_end_menu()
      endif
      if (ig_begin_menu('Run')) then
         if (ig_menu_item(ICON_PLAY//' Run', shortcut='F5', enabled=can_run())) call start_run()
         if (ig_menu_item(ICON_SQUARE//' Stop', shortcut='Shift+F5', enabled=solver%running())) call solver%kill()
         call ig_end_menu()
      endif
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
   if (ig_shortcut('f5')) then
      if (can_run()) call start_run()
   endif
   if (ig_shortcut('shift+f5')) then
      if (solver%running()) call solver%kill()
   endif
   if (form_shown .and. nhistory > 0_int32) then     ! in the text, ctrl+z is the text field's own undo
      if (ig_shortcut('ctrl+z')) call undo()
   endif
   if (ig_shortcut('f1')) about = .true.
   endsubroutine draw_menus

   subroutine browse_case()
   !< FIGURE's file browser, choosing a folder: the same in a window, in remote mode and in a test.
   call app%open_file_browser('case', default_path=start_dir, folders=.true.) ! answered on a later frame
   endsubroutine browse_case

   subroutine take_answers()
   !< The answers that arrive on this frame: the browser's or the dialog's, and the folders or files dropped.
   character(len=:), allocatable :: chosen    !< Path from the browser.
   character(len=:), allocatable :: paths(:)  !< Paths dropped.
   logical                       :: done      !< The browser was answered.
   logical                       :: cancelled !< ... by Cancel.
   integer(int32)                :: stat      !< Status of the answer.

   call app%file_dialog_result('case', chosen, done, cancelled, stat=stat) ! the browser's or the system's dialog
   if (done .and. .not. cancelled) then
      if (stat == FIG_OK) then
         call request('open', chosen)
      else
         call app%notify(figure_last_error(), kind='error')                 ! the dialog could not be shown
      endif
   endif
   if (app%dropped(paths)) call request('open', case_folder(trim(paths(1)))) ! a case folder, or its heat.inp
   endsubroutine take_answers

   subroutine request(action, dir)
   !< Open a case or quit, after asking whether to discard the changes if there are some.
   character(len=*), intent(in)           :: action !< 'open' or 'quit'.
   character(len=*), intent(in), optional :: dir    !< The case to open.

   pending_action = action
   pending_dir = ''
   if (present(dir)) pending_dir = dir
   if (edited) then
      ask_discard = .true.                           ! the question is opened at the top level, in draw_dialogs
   else
      call go_on()
   endif
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
   nhistory = 0_int32
   call source%set(case_text(inp))                   ! the text of the input, as the file would have it
   call load_field()                                 ! the result of an earlier run, if there is one
   text_edited = .false.
   call add_recent(dir)
   call show_title()
   call app%notify('Opened '//trim(inp%title), kind='success')
   endsubroutine open_case

   subroutine save_case()
   !< Write the input back to the case's file.
   integer(int32) :: stat !< Status of the write.

   if (text_edited) then                             ! the text's edits first, if it reads
      call apply_text()
      if (text_edited) return
   endif
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
   if (edited) then                                  ! in the bar drawn by FIGURE, and the task bar's
      call app%set_title('* '//trim(inp%title)//' - FIGURE studio')
   else
      call app%set_title(trim(inp%title)//' - FIGURE studio')
   endif
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
   character(len=*), parameter :: ICONS(5) = [character(len=4) :: ICON_FOLDER, ICON_FILE_PEN, ICON_PLAY, ICON_CHART_AREA, &
                                              ICON_ROTATE_3D]
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

   if (show_result) show_result = .not. ig_focus_window('Result') ! (not while a popup is open: again later)
   if (save_default) then
      call app%save_layout(DEFAULT_LAYOUT, comment='the studio as the program lays it out')
      if (ig_focus_window('Input')) continue                 ! of the two tabs, Input in front
      have_default = .true.
      save_default = .false.
   endif
   root = ig_dock_id('studio')
   if (ig_dock_layout_begin(root)) then
      call ig_dock_split(root, 'left', 0.25_real64, left, right)
      call ig_dock_split(right, 'down', 0.45_real64, run, work)
      call ig_dock_window('Case', left)
      call ig_dock_window('3-D', work)
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
      if (ig_begin('Input', open=shown(2))) call draw_input()
      call ig_end()
   endif
   if (shown(3)) then
      if (ig_begin('Run', open=shown(3))) call draw_run()
      call ig_end()
   endif
   if (shown(4)) then
      if (ig_begin('Result', open=shown(4))) call draw_result()
      call ig_end()
   endif
   if (shown(5)) then
      if (ig_begin('3-D', open=shown(5))) call draw_3d()
      call ig_end()
   endif
   endsubroutine draw_panels

   subroutine draw_case()
   !< The Case panel: the folder, the title (editable), the parameters.
   character(len=96) :: line !< A formatted line.

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
   endsubroutine draw_case

   subroutine draw_input()
   !< The Input panel: the tree of the input's sections on the left, the form or the text on the right.
   integer(int32) :: k            !< Counter.
   logical        :: clicked      !< A node's label was clicked.
   logical        :: side_clicked !< A side's label was clicked.

   if (len(case_dir) == 0) then
      call ig_text_disabled('The input of the case, once one is open.')
      return
   endif
   if (ig_begin_child('sections', width=170.0_real64, border=.true.)) then
      if (ig_tree_node(ICON_FILE_PEN//' '//INPUT_FILE, default_open=.true.)) then
         call section_node(1_int32)
         if (ig_tree_node('Boundaries', default_open=.true., selected=section == 2_int32, span_full_width=.true., &
                          clicked=clicked)) then
            do k = 1_int32, size(SIDES, kind=int32)  ! the sides: leaves, each choosing the table
               if (ig_tree_node(trim(SIDES(k)), leaf=.true., span_full_width=.true., clicked=side_clicked)) &
                  call ig_tree_pop()
               if (side_clicked) section = 2_int32
            enddo
            call ig_tree_pop()
         endif
         if (clicked) section = 2_int32               ! the label, not the arrow
         call section_node(3_int32)
         call section_node(4_int32)
         call ig_tree_pop()
      endif
   endif
   call ig_end_child()
   call ig_same_line()
   if (ig_begin_child('editor')) then
      if (ig_begin_tab_bar('views')) then
         form_shown = .false.
         if (ig_begin_tab('Form')) then
            form_shown = .true.
            call draw_form()
            call ig_end_tab()
         endif
         if (ig_begin_tab(INPUT_FILE)) then
            call draw_source()
            call ig_end_tab()
         endif
         call ig_end_tab_bar()
      endif
   endif
   call ig_end_child()
   endsubroutine draw_input

   subroutine section_node(n)
   !< A section as a leaf of the tree: a click on its label shows its form.
   integer(int32), intent(in) :: n       !< Section.
   logical                    :: clicked !< The label was clicked.

   if (ig_tree_node(trim(SECTIONS(n)), leaf=.true., selected=section == n, span_full_width=.true., &
                    clicked=clicked)) call ig_tree_pop()
   if (clicked) section = n
   endsubroutine section_node

   subroutine draw_form()
   !< The form of the section chosen in the tree; an edit marks the case edited and can be undone.
   type(case_t)   :: before   !< The input before this frame's edits.
   logical        :: changing !< The form changed the input in this frame.
   integer(int32) :: kind     !< A boundary's condition, as an index of KINDS.
   integer(int32) :: k        !< Counter.

   before = inp
   changing = .false.
   select case (section)
   case (1_int32)                                     ! numeric fields: integers with +/- buttons, reals with a format
      if (ig_input('nx', inp%nx, step=1_int32)) changing = .true.
      if (ig_input('ny', inp%ny, step=1_int32)) changing = .true.
      if (ig_input('lx [m]', inp%lx, format='%.3f')) changing = .true.
      if (ig_input('ly [m]', inp%ly, format='%.3f')) changing = .true.
      inp%nx = max(inp%nx, 3_int32)                   ! the solver needs an interior
      inp%ny = max(inp%ny, 3_int32)
   case (3_int32)                                     ! sliders: the body stays inside the plate
      if (ig_slider('x [m]', inp%body_x, 0.0_real64, inp%lx)) changing = .true.
      if (ig_slider('y [m]', inp%body_y, 0.0_real64, inp%ly)) changing = .true.
      if (ig_slider('radius [m]', inp%body_r, 0.01_real64, 0.5_real64 * min(inp%lx, inp%ly))) changing = .true.
      inp%body_x = 0.001_real64 * nint(1000.0_real64 * inp%body_x) ! a slider gives any real: millimetres here
      inp%body_y = 0.001_real64 * nint(1000.0_real64 * inp%body_y)
      inp%body_r = 0.001_real64 * nint(1000.0_real64 * inp%body_r)
      if (ig_input('temperature [C]', inp%body_t, format='%.1f')) changing = .true.
   case (4_int32)
      if (ig_slider('omega', inp%omega, 1.0_real64, 1.95_real64)) changing = .true.
      inp%omega = 0.01_real64 * nint(100.0_real64 * inp%omega)       ! two decimals
      call ig_tooltip('Over-relaxation: 1 is Gauss-Seidel, close to 2 converges faster or not at all')
      if (ig_input('tolerance', inp%tolerance, format='%.1e')) changing = .true.
      if (ig_input('iterations at most', inp%max_iter, step=100_int32)) changing = .true.
   end select
   if (section == 2_int32) then
      if (ig_begin_table('boundaries', 3_int32)) then
         call ig_table_setup_column('side', width=70.0_real64)
         call ig_table_setup_column('condition', width=140.0_real64)
         call ig_table_setup_column('temperature [C]')
         call ig_table_headers_row()
         do k = 1_int32, size(SIDES, kind=int32)
            call ig_push_id(k)                        ! the same widgets in every row: an id scope per row
            call ig_table_next_row()
            call ig_table_next_column()
            call ig_text(trim(SIDES(k)))
            call ig_table_next_column()
            kind = merge(1_int32, 2_int32, inp%bc_kind(k) == KINDS(1))
            call ig_set_next_item_width(-1.0_real64)
            if (ig_combo('##kind', kind, KINDS)) then
               inp%bc_kind(k) = KINDS(kind)
               changing = .true.
            endif
            call ig_table_next_column()
            call ig_begin_disabled(kind == 2_int32)   ! an insulated side has no temperature
            call ig_set_next_item_width(-1.0_real64)
            if (ig_input('##value', inp%bc_value(k), format='%.1f')) changing = .true.
            call ig_end_disabled()
            call ig_pop_id()
         enddo
         call ig_end_table()
      endif
   endif
   if (changing) then
      if (.not. was_changing) call push_undo(before) ! one Undo per edit, not per frame of it
      edited = .true.
      call show_title()
      call source%set(case_text(inp))                ! the text follows the form
      text_edited = .false.
   endif
   was_changing = changing
   endsubroutine draw_form

   subroutine draw_source()
   !< The input file as text, in the monospace font: edited, then applied to the input (or not, if it does not read).
   call ig_begin_disabled(.not. text_edited)
   if (ig_button(ICON_CHECK//' Apply')) call apply_text()
   call ig_end_disabled()
   call ig_same_line()
   if (text_edited) then
      call ig_text('(!) the text is not applied yet')
   else
      call ig_text_disabled('the input, as heat.inp will hold it')
   endif
   call ig_push_font('plex-mono')                     ! columns line up: every character as wide
   if (ig_input_text_multiline('##source', source, width=-1.0_real64, height=-1.0_real64)) text_edited = .true.
   call ig_pop_font()
   endsubroutine draw_source

   subroutine apply_text()
   !< Read the text as the input; on a mistake, say where, and keep the text for the user to correct.
   type(case_t)                  :: new  !< The input read from the text.
   character(len=:), allocatable :: msg  !< What went wrong.
   integer(int32)                :: stat !< Status of the read.
   integer(int32)                :: u    !< A scratch file.

   integer(int32)                :: first !< A line's first character.
   integer(int32)                :: last  !< Its end of line.
   character(len=:), allocatable :: text  !< The text.

   text = source%text()
   open(newunit=u, status='scratch', action='readwrite') ! a namelist is read from a file: the text into one
   first = 1_int32
   do while (first <= len(text))
      last = index(text(first:), char(10)) + first - 1_int32
      if (last < first) last = len(text) + 1_int32   ! the last line, without a line feed
      write(u, '(A)') text(first:last - 1_int32)
      first = last + 1_int32
   enddo
   rewind(u)
   call read_input(u, new, stat, msg)
   close(u)
   if (stat /= 0) then
      call app%notify(INPUT_FILE//' does not read: '//msg, kind='error') ! the text stays, to be corrected
      return
   endif
   call push_undo(inp)
   inp = new
   edited = .true.
   text_edited = .false.
   call show_title()
   endsubroutine apply_text

   subroutine push_undo(state)
   !< Keep `state` for Undo; the oldest goes when the history is full.
   type(case_t), intent(in) :: state !< The input before an edit.

   if (nhistory == MAX_UNDO) then
      history(1:MAX_UNDO - 1) = history(2:MAX_UNDO)
      nhistory = nhistory - 1_int32
   endif
   nhistory = nhistory + 1_int32
   history(nhistory) = state
   endsubroutine push_undo

   subroutine undo()
   !< Take back the last edit of the form.
   if (nhistory == 0_int32) return
   inp = history(nhistory)
   nhistory = nhistory - 1_int32
   edited = .true.
   call show_title()
   call source%set(case_text(inp))
   text_edited = .false.
   endsubroutine undo

   logical function can_run()
   !< A case is open and the solver is not running.
   can_run = .false.
   if (len(case_dir) > 0) can_run = .not. solver%running()
   endfunction can_run

   subroutine start_run()
   !< Start the solver on the case, saved first.
   character(len=512) :: args(4) !< The solver and its arguments.
   integer(int32)     :: stat    !< Status of the start.

   if (edited) call save_case()                      ! the solver reads the file: save the edits first
   if (edited) return
   call output%clear()
   deallocate(iters, res)
   allocate(iters(0), res(0))
   args(1) = solver_path                             ! no shell: the program and its arguments, an array
   args(2) = case_dir
   args(3) = '--pace'                                ! a small case: slowed down, to be watched
   args(4) = '3'
   call solver%start(args, stat=stat)
   if (stat /= FIG_OK) then
      call app%notify('The solver does not start: '//figure_last_error(), kind='error')
      return
   endif
   started = .true.
   run_status = 'running'
   endsubroutine start_run

   subroutine follow_run()
   !< Every frame, whichever panel is shown: the lines the solver printed since the last frame, and its end.
   character(len=:), allocatable :: lines(:) !< New lines.
   character(len=16)             :: word     !< The word between the numbers.
   real(real64)                  :: it       !< Iteration.
   real(real64)                  :: r        !< Residual.
   integer(int32)                :: k        !< Counter.
   integer(int32)                :: ios      !< Status of a read.

   if (.not. started) return
   call solver%poll(lines)                           ! the complete lines since the last poll
   call output%add(lines)
   do k = 1_int32, size(lines, kind=int32)
      if (index(lines(k), 'iteration ') /= 1) cycle
      read(lines(k)(11:), *, iostat=ios) it, word, r ! "iteration    42  residual 1.234E-04"
      if (ios == 0) then
         iters = [iters, it]
         res = [res, r]
      endif
   enddo
   if (solver%running()) return
   started = .false.                                 ! it ended: once
   if (solver%killed()) then
      run_status = ICON_SQUARE//' stopped'
      call app%notify('The run was stopped', kind='warning')
   elseif (solver%exit_code() == 0_int32) then
      write(run_status, '(A,I0,A,ES8.2)') 'converged in ', nint(iters(size(iters))), ' iterations, residual ', &
                                          res(size(res))
      call app%notify('The solver '//trim(run_status), kind='success', seconds=10.0_real64)
      call load_field()
   else
      write(run_status, '(A,I0,A)') '[!!] the solver failed, exit code ', solver%exit_code(), ': see the log'
      call app%notify(trim(run_status), kind='error')
   endif
   endsubroutine follow_run

   subroutine draw_run()
   !< The Run panel: Run and Stop, the log on the left, the residuals on the right.
   if (len(case_dir) == 0) then
      call ig_text_disabled('The solver, its log and its residuals, once a case is open.')
      return
   endif
   call ig_begin_disabled(.not. can_run())           ! one run at a time
   if (ig_button(ICON_PLAY//' Run')) call start_run()
   call ig_end_disabled()
   call ig_same_line()
   call ig_begin_disabled(.not. solver%running())
   if (ig_button(ICON_SQUARE//' Stop')) call solver%kill() ! the solver ends; follow_run tells
   call ig_end_disabled()
   call ig_same_line()
   call ig_text(trim(run_status))
   if (ig_begin_child('log', width=380.0_real64)) call output%draw('output') ! only the lines in view
   call ig_end_child()
   call ig_same_line()
   if (size(res) == 0) then
      call ig_text_disabled('The residuals, as the solver prints them.')
   elseif (ip_begin_plot('Residuals', width=-1.0_real64, height=-1.0_real64)) then
      call ip_setup_axes('iteration', 'residual', auto_fit=.true., ylog=.true.) ! follows the data as it grows
      call ip_line('residual', iters, res)
      call ip_end_plot()
   endif
   endsubroutine draw_run

   subroutine draw_status()
   !< The status bar: a bar along the bottom with the run's state and its progress.
   real(real64) :: fraction !< Progress towards the tolerance, on a logarithmic scale.

   if (ig_begin_side_bar('status', 'bottom', 30.0_real64)) then ! left out of the dock space, as the tools' bar
      if (solver%running()) then
         fraction = -1.0_real64                      ! indeterminate until two residuals are known
         if (size(res) > 1) fraction = min(1.0_real64, max(0.0_real64, &
                                           log(res(1) / res(size(res))) / log(res(1) / inp%tolerance)))
         call ig_progress_bar(fraction, width=200.0_real64)
         call ig_same_line()
         if (size(res) > 0) write(run_status, '(A,I0,A,ES8.2)') 'running: iteration ', nint(iters(size(iters))), &
                                                                 ', residual ', res(size(res))
      endif
      call ig_text(trim(run_status))
   endif
   call ig_end()
   endsubroutine draw_status

   subroutine load_field()
   !< Read the case's field.dat, written by the solver; no file, no field.
   integer(int32) :: nx, ny !< Its grid.
   integer(int32) :: u      !< Unit.
   integer(int32) :: ios    !< Status.

   deallocate(field)
   allocate(field(0, 0))
   open(newunit=u, file=case_dir//'/field.dat', status='old', action='read', iostat=ios)
   if (ios /= 0) return                              ! not run yet
   read(u, *, iostat=ios)                            ! the comment line
   read(u, *, iostat=ios) nx, ny, flx, fly
   if (ios == 0) then
      deallocate(field)
      allocate(field(nx, ny))
      read(u, *, iostat=ios) field                   ! row after row: field(:, 1), field(:, 2), ...
   endif
   close(u)
   if (ios /= 0) then
      deallocate(field)
      allocate(field(0, 0))
      call app%notify('field.dat does not read', kind='error')
      return
   endif
   probe_x = 0.5_real64 * flx
   point = [0.25_real64 * flx, 0.75_real64 * fly]
   show_result = .true.
   call build_3d()
   endsubroutine load_field

   subroutine build_3d()
   !< The 3-D view of the field: the temperature as a surface over the plate, and the body as a cylinder.
   real(real64)   :: dx, dy, h !< Grid spacing [m]; height of a degree [m].
   real(real64)   :: tmin      !< The coldest temperature, at the plate's level [C].
   real(real64)   :: th        !< An angle around the body.
   integer(int32) :: i, j      !< Counters.

   call view%clear()                                 ! the meshes go before their arrays change
   deallocate(carpet)
   allocate(carpet(3, size(field, 1), size(field, 2)))
   dx = flx / (size(field, 1) - 1)
   dy = fly / (size(field, 2) - 1)
   tmin = minval(field)
   h = 0.4_real64 * max(flx, fly) / max(1.0e-12_real64, maxval(field) - tmin) ! the hottest 0.4 plate high
   do j = 1_int32, size(field, 2, kind=int32)
      do i = 1_int32, size(field, 1, kind=int32)
         carpet(:, i, j) = [(i - 1) * dx, (j - 1) * dy, h * (field(i, j) - tmin)]
      enddo
   enddo
   do i = 1_int32, size(body, 2, kind=int32)       ! the cylinder, from the plate up to the body's temperature
      th = 2.0_real64 * acos(-1.0_real64) * (i - 1) / (size(body, 2) - 1)
      body(:, i, 1) = [inp%body_x + inp%body_r * cos(th), inp%body_y + inp%body_r * sin(th), 0.0_real64]
      body(:, i, 2) = [body(1:2, i, 1), h * (inp%body_t - tmin) + 0.15_real64 * max(flx, fly)]
   enddo
   carpet_mesh = view%surface(carpet, scalar=field, colormap=trim(MAPS(map)), edges=grid3d) ! read in place
   body_mesh = view%surface(body, color=[0.75_real64, 0.75_real64, 0.78_real64])
   call view%set_camera(azimuth=-60.0_real64, elevation=35.0_real64)
   call view%fit()
   if (cut) call view%clip([-1.0_real64, 0.0_real64, 0.0_real64], [probe_x, 0.0_real64, 0.0_real64])
   endsubroutine build_3d

   subroutine draw_3d()
   !< The 3-D panel: views, the grid, the cut, the view itself, and what is under the pointer.
   integer(int32) :: mesh    !< The mesh under the pointer.
   integer(int64) :: element !< Its cell.
   real(real64)   :: p(3)    !< The point under the pointer [m].

   if (size(field) == 0) then
      call ig_text_disabled('The field in 3-D, once the solver has run.')
      return
   endif
   if (ig_button('Top')) call view%view('+z')        ! the standard views are fitted
   call ig_same_line()
   if (ig_button('Side')) call view%view('-y')
   call ig_same_line()
   if (ig_button('Fit')) call view%fit()
   call ig_same_line()
   if (ig_checkbox('grid', grid3d)) call view%set_mesh(carpet_mesh, edges=grid3d)
   call ig_same_line()
   if (ig_checkbox('cut along the probe line', cut)) then
      call view%unclip()
      if (cut) call view%clip([-1.0_real64, 0.0_real64, 0.0_real64], [probe_x, 0.0_real64, 0.0_real64]) ! keeps x < probe
   endif
   call ig_same_line()
   call ig_text(trim(picked))
   call view%draw('view')                            ! the rest of the panel; the mouse orbits, pans, zooms
   picked = ''
   if (view%hovered(mesh, element, p)) then          ! no cost: the view knows what each pixel shows
      if (mesh == carpet_mesh) picked = 'T = '//num(temperature(p(1), p(2)))//' C at ('//num(p(1))//', '// &
                                        num(p(2))//') m'
   endif
   if (view%clicked(mesh, element, p)) then
      if (mesh == carpet_mesh) then
         point = p(1:2)                              ! the Result panel's probe point moves there
         call app%notify('The probe point is now at the point clicked', kind='info', seconds=3.0_real64)
      endif
   endif
   endsubroutine draw_3d

   function temperature(x, y) result(t)
   !< The temperature of the node nearest (x, y).
   real(real64), intent(in) :: x, y !< A point of the plate [m].
   real(real64)             :: t    !< Its temperature [C].
   integer(int32)           :: i, j !< The node.

   i = min(size(field, 1, kind=int32), max(1_int32, 1_int32 + nint(x / flx * (size(field, 1) - 1), int32)))
   j = min(size(field, 2, kind=int32), max(1_int32, 1_int32 + nint(y / fly * (size(field, 2) - 1), int32)))
   t = field(i, j)
   endfunction temperature

   subroutine draw_result()
   !< The Result panel: the field as a heatmap with its legend and contour lines, the probes, the profile.
   real(real64)      :: dx, dy  !< The field's grid spacing [m].
   real(real64)      :: tmin    !< The field's range [C].
   real(real64)      :: tmax    !< ...
   integer(int32)    :: cmap    !< The colormap's id.
   integer(int32)    :: i, j    !< The nodes nearest the probes.
   integer(int32)    :: k       !< Counter.
   character(len=48) :: text    !< A label.

   if (size(field) == 0) then
      call ig_text_disabled('The field the solver computed, once it has run.')
      return
   endif
   dx = flx / (size(field, 1) - 1)
   dy = fly / (size(field, 2) - 1)
   tmin = minval(field)
   tmax = maxval(field)
   call ig_set_next_item_width(140.0_real64)
   if (ig_combo('colormap', map, MAPS)) call view%set_mesh(carpet_mesh, colormap=trim(MAPS(map))) ! the 3-D view too
   call ig_same_line()
   call ig_set_next_item_width(140.0_real64)
   if (ig_slider('bands', bands, 0_int32, 16_int32)) bands = merge(0_int32, bands, bands == 1_int32) ! 0: continuous
   call ig_same_line()
   if (ig_checkbox('contour lines', contours)) continue
   if (MAPS(map) == 'Jet') then                      ! a mark with the colour: never colour alone
      call ig_same_line()
      call ig_text_colored(ICON_TRIANGLE_ALERT//' Jet: not perceptually uniform', &
                           [0.95_real64, 0.75_real64, 0.2_real64, 1.0_real64])
   endif
   if (bands > 0_int32) then
      cmap = ip_colormap(trim(MAPS(map)), levels=bands) ! the same map in discrete bands
   else
      cmap = ip_colormap(trim(MAPS(map)))
   endif
   if (ip_begin_plot('Temperature [C]', width=420.0_real64, height=-1.0_real64, equal=.true.)) then
      call ip_setup_axes('x [m]', 'y [m]')
      ! the cells' edges: half a spacing beyond the first and last nodes
      call ip_heatmap('##t', field, -0.5_real64 * dx, flx + 0.5_real64 * dx, -0.5_real64 * dy, fly + 0.5_real64 * dy, &
                      scale_min=tmin, scale_max=tmax, colormap=cmap)
      if (contours .and. bands > 0_int32) then      ! the lines at the bands' edges
         call ip_contour('##isotherms', field, 0.0_real64, flx, 0.0_real64, fly, &
                         levels=[(tmin + k * (tmax - tmin) / bands, k = 1_int32, bands - 1_int32)], &
                         color=[0.1_real64, 0.1_real64, 0.1_real64, 1.0_real64], labels=.true.)
      elseif (contours) then                         ! about ten lines at round values
         call ip_contour('##isotherms', field, 0.0_real64, flx, 0.0_real64, fly, nlevels=10_int32, &
                         color=[0.1_real64, 0.1_real64, 0.1_real64, 1.0_real64], labels=.true.)
      endif
      if (ip_drag_line_x(1_int32, probe_x, thickness=2.0_real64)) then
         probe_x = min(flx, max(0.0_real64, probe_x))
         if (cut) then                               ! the 3-D cut follows the line
            call view%unclip()
            call view%clip([-1.0_real64, 0.0_real64, 0.0_real64], [probe_x, 0.0_real64, 0.0_real64])
         endif
      endif
      if (ip_drag_point(2_int32, point(1), point(2), radius=6.0_real64)) then
         point = [min(flx, max(0.0_real64, point(1))), min(fly, max(0.0_real64, point(2)))]
      endif
      i = 1_int32 + nint(point(1) / dx, int32)
      j = 1_int32 + nint(point(2) / dy, int32)
      write(text, '(F6.2,A)') field(i, j), ' C'
      call ip_annotation(point(1), point(2), trim(adjustl(text)), color=[1.0_real64, 1.0_real64, 0.9_real64, 0.9_real64], &
                         offset=[14.0_real64, -14.0_real64])
      call ip_end_plot()
   endif
   call ig_same_line()
   if (bands > 0_int32) then                         ! the bands, their edges labelled
      call ip_colormap_legend('legend', cmap, tmin, tmax, levels=bands, height=-1.0_real64, label_format='%.0f')
   else
      call ip_colormap_legend('legend', cmap, tmin, tmax, height=-1.0_real64, label_format='%.0f')
   endif
   call ig_same_line()
   call draw_profile(dy)
   endsubroutine draw_result

   subroutine draw_profile(dy)
   !< The temperature along the probe line, and the spread of the five columns around it at every fourth node.
   real(real64), intent(in)  :: dy        !< The field's spacing along y [m].
   real(real64), allocatable :: y(:)      !< Ordinates of the error bars [m].
   real(real64), allocatable :: mean(:)   !< Mean of the five columns.
   real(real64), allocatable :: below(:)  !< Mean minus the least.
   real(real64), allocatable :: above(:)  !< The greatest minus the mean.
   integer(int32)            :: i         !< The probe's column.
   integer(int32)            :: i0, i1    !< The five columns.
   integer(int32)            :: j, k      !< Counters.
   character(len=48)         :: title     !< The plot's title.

   i = 1_int32 + nint(probe_x / (flx / (size(field, 1) - 1)), int32)
   i0 = max(1_int32, i - 2_int32)
   i1 = min(size(field, 1, kind=int32), i + 2_int32)
   allocate(y(0), mean(0), below(0), above(0))
   do j = 1_int32, size(field, 2, kind=int32), 4_int32
      k = size(y) + 1_int32
      y = [y, (j - 1) * dy]
      mean = [mean, sum(field(i0:i1, j)) / (i1 - i0 + 1)]
      below = [below, mean(k) - minval(field(i0:i1, j))]
      above = [above, maxval(field(i0:i1, j)) - mean(k)]
   enddo
   write(title, '(A,F5.3,A)') 'Along x = ', probe_x, ' m###profile' ! ### : the title changes, the id stays
   if (ip_begin_plot(trim(title), width=-1.0_real64, height=-1.0_real64)) then
      call ip_setup_axes('y [m]', 'T [C]', auto_fit=.true.)
      call ip_line('T', field, i, xscale=dy)        ! the column i of the field, read in place
      call ip_error_bars('5 columns: mean, least, greatest', y, mean, below, above, spec=ip_spec(size=5.0_real64))
      call ip_end_plot()
   endif
   endsubroutine draw_profile

   subroutine draw_dialogs()
   !< The questions and boxes the menus and the frame open, at the top level.
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

   subroutine read_case(file, c, stat, msg)
   !< Read a case's input, the namelist `&heat` of `file`.
   character(len=*),              intent(in)  :: file  !< Input file.
   type(case_t),                  intent(out) :: c     !< Its input (defaults where the file is silent).
   integer(int32),                intent(out) :: stat  !< Status: 0 read.
   character(len=:), allocatable, intent(out) :: msg   !< What went wrong.
   character(len=256)                         :: iomsg !< The run time's message.
   integer(int32)                             :: u     !< Unit.

   open(newunit=u, file=file, status='old', action='read', iostat=stat, iomsg=iomsg)
   if (stat /= 0) then
      msg = 'no '//INPUT_FILE//' in '//file(:max(0, len(file) - len(INPUT_FILE) - 1))
      return
   endif
   call read_input(u, c, stat, msg)
   close(u)
   if (stat /= 0) msg = file//': '//msg
   endsubroutine read_case

   subroutine read_input(u, c, stat, msg)
   !< Read the namelist `&heat` from the open unit `u`.
   integer(int32),                intent(in)  :: u           !< Unit.
   type(case_t),                  intent(out) :: c           !< Its input (defaults where the text is silent).
   integer(int32),                intent(out) :: stat        !< Status: 0 read.
   character(len=:), allocatable, intent(out) :: msg         !< What went wrong.
   character(len=64)                          :: title       !< Namelist copies of the components.
   integer(int32)                             :: nx, ny, max_iter
   real(real64)                               :: lx, ly, bc_value(4), body_x, body_y, body_r, body_t, omega, tolerance
   character(len=12)                          :: bc_kind(4)
   character(len=256)                         :: iomsg       !< The run time's message.
   namelist /heat/ title, nx, ny, lx, ly, bc_kind, bc_value, body_x, body_y, body_r, body_t, omega, tolerance, max_iter

   title = c%title; nx = c%nx; ny = c%ny; lx = c%lx; ly = c%ly; bc_kind = c%bc_kind; bc_value = c%bc_value
   body_x = c%body_x; body_y = c%body_y; body_r = c%body_r; body_t = c%body_t
   omega = c%omega; tolerance = c%tolerance; max_iter = c%max_iter
   msg = ''
   read(u, nml=heat, iostat=stat, iomsg=iomsg)
   if (stat /= 0) then
      msg = trim(iomsg)
      return
   endif
   c = case_t(title, nx, ny, lx, ly, bc_kind, bc_value, body_x, body_y, body_r, body_t, omega, tolerance, max_iter)
   endsubroutine read_input

   subroutine write_case(file, c, stat)
   !< Write a case's input file.
   character(len=*), intent(in)  :: file !< Input file.
   type(case_t),     intent(in)  :: c    !< Its input.
   integer(int32),   intent(out) :: stat !< Status: 0 written.
   integer(int32)                :: u    !< Unit.

   open(newunit=u, file=file, access='stream', form='unformatted', status='replace', action='write', iostat=stat)
   if (stat /= 0) return
   write(u, iostat=stat) case_text(c)
   close(u)
   endsubroutine write_case

   function case_text(c) result(text)
   !< A case's input as the namelist `&heat`, one group of parameters per line: the file's text.
   type(case_t), intent(in)      :: c    !< The input.
   character(len=:), allocatable :: text !< Its text, lines ended by LF.
   character(len=1), parameter   :: LF = char(10) !< Line feed.
   character(len=96)             :: line !< A line.

   text = '&heat'//LF//"  title = '"//trim(c%title)//"'"//LF
   write(line, '(A,I0,A,I0,A,A,A,A)') '  nx = ', c%nx, ', ny = ', c%ny, ', lx = ', num(c%lx), ', ly = ', num(c%ly)
   text = text//trim(line)//LF
   text = text//"  bc_kind = '"//trim(c%bc_kind(1))//"', '"//trim(c%bc_kind(2))//"', '"//trim(c%bc_kind(3))// &
          "', '"//trim(c%bc_kind(4))//"'  ! west, east, south, north"//LF
   text = text//'  bc_value = '//num(c%bc_value(1))//', '//num(c%bc_value(2))//', '//num(c%bc_value(3))//', '// &
          num(c%bc_value(4))//LF
   text = text//'  body_x = '//num(c%body_x)//', body_y = '//num(c%body_y)//', body_r = '//num(c%body_r)// &
          ', body_t = '//num(c%body_t)//LF
   write(line, '(A,A,A,ES7.1,A,I0)') '  omega = ', num(c%omega), ', tolerance = ', c%tolerance, ', max_iter = ', &
                                     c%max_iter
   text = text//trim(line)//LF//'/'//LF
   endfunction case_text

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
   call execute_command_line('rm -f "'//folder//'/plate/field.dat" "'//folder//'/channel/field.dat"', exitstat=stat)
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
endprogram tut13_view3d
