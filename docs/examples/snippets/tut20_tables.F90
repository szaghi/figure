!< tut20_tables, tutorial chapter 20: context menus, a sortable list of runs, numbers and choices.
module tut20_tasks
!< tut20_tasks, tutorial chapter 20: the work the studio runs as tasks (module procedures: they run on worker threads).
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : task_handle_object

implicit none
private
public :: field_t, read_field

integer(int32), parameter, public :: MAX_SHOWN = 200_int32 !< Nodes per side of the copy drawn, at most.

type :: field_t
   !< A field to read: the file, given to the task; the values and a coarser copy, given back.
   character(len=:), allocatable :: file              !< The solver's field.dat.
   real(real64)                  :: lx = 0.0_real64   !< The plate [m].
   real(real64)                  :: ly = 0.0_real64
   real(real64), allocatable     :: values(:,:)       !< The field, every node.
   real(real64), allocatable     :: coarse(:,:)       !< Every stride-th node, to draw.
   integer(int32)                :: stride = 1_int32  !< The coarse copy's stride.
endtype field_t

contains
   recursive subroutine read_field(h, data)
   !< Read a field.dat row by row, reporting the progress, stopping if asked; then make the coarse copy.
   type(task_handle_object), intent(inout) :: h      !< The task's handle.
   class(*),                 intent(inout) :: data   !< A field_t.
   character(len=256)                      :: iomsg  !< The run time's message.
   integer(int32)                          :: nx, ny !< The grid.
   integer(int32)                          :: j      !< Row.
   integer(int32)                          :: u      !< Unit: the task's own.
   integer(int32)                          :: ios    !< Status.

   select type (data)
   type is (field_t)
      open(newunit=u, file=data%file, status='old', action='read', iostat=ios, iomsg=iomsg)
      if (ios /= 0) then
         call h%fail(trim(iomsg))                    ! t%result gives FIG_ERR_FAILED and this message
         return
      endif
      read(u, *, iostat=ios, iomsg=iomsg)            ! the comment line
      if (ios == 0) read(u, *, iostat=ios, iomsg=iomsg) nx, ny, data%lx, data%ly
      if (ios == 0) then
         allocate(data%values(nx, ny))
         do j = 1_int32, ny
            if (h%cancelled()) exit                  ! a safe point, between two rows
            read(u, *, iostat=ios, iomsg=iomsg) data%values(:, j)
            if (ios /= 0) exit
            if (mod(j, 8_int32) == 0_int32) call h%report(real(j, real64) / ny, 'reading field.dat')
         enddo
      endif
      close(u)
      if (ios /= 0) then
         call h%fail(data%file//': '//trim(iomsg))
         return
      endif
      if (h%cancelled()) return
      data%stride = (max(nx, ny) - 1_int32) / MAX_SHOWN + 1_int32
      data%coarse = data%values(1::data%stride, 1::data%stride) ! what is drawn: at most MAX_SHOWN a side
   endselect
   endsubroutine read_field
endmodule tut20_tasks

program tut20_tables
!< tut20_tables, tutorial chapter 20: context menus, a sortable list of runs, numbers and choices.
!<
!< Chapter 19's studio: the Run panel keeps the runs of the session in a table with a frozen header, sorted by the
!< column the user clicks, failed runs shaded and marked, each row with a context menu and a tooltip holding its
!< residuals; the boundaries' table has radio buttons and a context menu per side; the body's centre is one drag box
!< of two numbers and the tolerance a slider on a log scale.
!< `tut20_tables --remote PORT` serves the interface to a web browser; `--examples DIR` writes the example cases into
!< DIR; `--case DIR` opens one; `--test DIR` tests it.
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, ig_begin_item_tooltip, ig_begin_popup_context, ig_drag, ig_end_tooltip, ig_radio, &
                   ig_selectable, ig_table_row_color, ig_table_sort, ImGuiTableFlags_BordersInnerV, &
                   ImGuiTableFlags_RowBg, ig_align_begin, ig_align_end, ig_em, ig_focus_here, ig_font_size, &
                   ig_frame_height, ig_last_item, ig_pop_style_color, ig_push_style_color, ig_scroll_here, &
                   ig_separator_text, ig_text_link, item_status_object, FIG_ERR_ARGUMENT, FIG_ERR_EXCEPTION, &
                   FIG_ERR_FAILED, FIG_ERR_STATE, FIG_OK, figure_last_error, ig_any_item_active, ICON_CHART_AREA, &
                   ICON_CHECK, ICON_COPY, ICON_FILE_PEN, ICON_FLAME, ICON_FOLDER, ICON_FOLDER_OPEN, ICON_HISTORY, &
                   ICON_INFO, ICON_LAYOUT, ICON_MESSAGES_SQUARE, ICON_PALETTE, ICON_PLAY, ICON_POWER_SQUARE, &
                   ICON_ROTATE_3D, ICON_SAVE, ICON_SQUARE, ICON_TRIANGLE_ALERT, ICON_UNDO, ig_begin, ig_begin_child, &
                   ig_begin_disabled, ig_begin_main_menu_bar, ig_begin_menu, ig_begin_popup_modal, ig_begin_side_bar, &
                   ig_begin_tab, ig_begin_tab_bar, ig_begin_table, ig_button, ig_checkbox, ig_close_current_popup, &
                   ig_combo, ig_dock_id, ig_dock_layout_begin, ig_dock_layout_end, ig_dock_space, ig_dock_split, &
                   ig_dock_window, ig_end, ig_end_child, ig_end_disabled, ig_end_main_menu_bar, ig_end_menu, &
                   ig_end_popup, ig_end_tab, ig_end_tab_bar, ig_end_table, ig_focus_window, ig_input, ig_input_text, &
                   ig_input_text_multiline, ig_item_rect, ig_menu_item, ig_open_popup, ig_pop_font, ig_pop_id, &
                   ig_progress_bar, ig_push_font, ig_push_id, ig_same_line, ig_separator, ig_set_clipboard, &
                   ig_set_next_item_shortcut, ig_set_next_item_width, ig_set_next_window, ig_set_next_window_dock, &
                   ig_shortcut, ig_slider, ig_table_headers_row, ig_table_next_column, ig_table_next_row, &
                   ig_table_setup_column, ig_text, ig_text_colored, ig_text_disabled, ig_text_wrapped, &
                   ig_tool_button, ig_tooltip, ig_tree_node, ig_tree_pop, ig_window_dock, ip_annotation, &
                   ip_begin_plot, ip_colormap, ip_colormap_legend, ip_contour, ip_drag_line_x, ip_drag_point, &
                   ip_end_plot, ip_error_bars, ip_heatmap, ip_line, ip_setup_axes, ip_setup_axes_limits, ip_spec, &
                   log_view_object, process_object, task_object, text_buffer_object, view3d_object
use tut20_tasks, only : field_t, read_field
use figure_testing, only : test_click, test_drop, test_file_browser, test_file_browser_rect, test_frame_hit, &
                          test_frame_rect, test_key, test_popup_rect, test_type, test_window_rect

implicit none
character(len=*), parameter :: PANELS(5) = [character(len=6) :: 'Case', 'Input', 'Run', 'Result', '3-D'] !< Panels.
character(len=*), parameter :: LOOKS(4) = [character(len=7) :: 'seal', 'fusion', 'adwaita', 'fluent'] !< Looks.
character(len=*), parameter :: PALETTES(6) = [character(len=16) :: 'seal', 'seal-light', 'nord', 'gruvbox-dark', &
                                              'solarized-light', 'catppuccin-latte'] !< Some of the palettes.
character(len=*), parameter :: DEFAULT_LAYOUT = 'tut20_tables-default.layout' !< The layout as the program sets it.
character(len=*), parameter :: INPUT_FILE = 'heat.inp' !< The input file of a case.
integer(int32),   parameter :: MAX_RECENT = 5_int32    !< Recent cases kept.
integer(int32),   parameter :: MAX_UNDO = 32_int32     !< Edits that Undo can take back.
character(len=*), parameter :: SIDES(4) = [character(len=5) :: 'west', 'east', 'south', 'north'] !< The plate's sides.
character(len=*), parameter :: KINDS(2) = [character(len=9) :: 'fixed', 'insulated'] !< Boundary conditions.
character(len=*), parameter :: MAPS(6) = [character(len=9) :: 'cividis', 'batlow', 'Viridis', 'cool-warm', &
                                          'turbo', 'Jet'] !< Colormaps offered (ImPlot's own capitalized).
integer(int32),   parameter :: SECTION_OF(7) = [1_int32, 1_int32, 3_int32, 2_int32, 4_int32, 4_int32, 4_int32] !< The
                                                                  !< section of each check of `problems`.
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

type :: run_t
   !< A run of the session, as the Runs table lists it.
   integer(int32)            :: number = 0_int32       !< Its number in the session.
   character(len=64)         :: title = ''             !< The case's title then.
   integer(int32)            :: iterations = 0_int32   !< Iterations done.
   real(real64)              :: residual = 0.0_real64  !< The last residual.
   character(len=12)         :: outcome = ''           !< 'converged', 'stopped' or 'failed'.
   real(real64), allocatable :: it(:)                  !< Its residual history: iterations ...
   real(real64), allocatable :: res(:)                 !< ... and residuals.
endtype run_t

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
type(task_object)             :: loader           !< The task reading field.dat.
real(real64), allocatable, target :: coarse(:,:)  !< Every stride-th node of the field: what is drawn.
integer(int32)                :: stride           !< The coarse copy's stride.
logical                       :: load_cancelled   !< The user stopped the reading.
logical                       :: messages_shown   !< The Messages panel is shown.
integer(int32)                :: run_node         !< The dock node of the Run panel (0: not docked).
real(real64)                  :: title_at(2)      !< Where the title field is, for the test [pixels].
real(real64)                  :: discard_at(2)    !< Where Discard is, while asked, for the test [pixels].
logical                       :: ended            !< The test saw next_frame end.
integer(int32)                :: checks           !< The test's checks made.
integer(int32)                :: port             !< Remote mode's port (0: a window).
logical                       :: remote           !< The interface is in a web browser.
logical                       :: run_now          !< --run: start the solver once the case is open.
character(len=512)            :: url              !< Remote mode: the address to open, with its token.
integer(int32)                :: failed           !< ... and failed.
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
integer(int32)                :: stat             !< Status of a frame: a usage error in the last one.
character(len=:), allocatable :: last_report      !< The last usage error reported (not repeated every frame).
integer(int32)                :: usage_errors     !< The test: frames that reported a usage error.
type(run_t), allocatable      :: runs(:)          !< The runs of the session.
integer(int32), allocatable   :: order(:)         !< The order the Runs table shows them in (indices of runs).
integer(int32)                :: sort_key         !< The column the table is sorted by (0: the runs' own order).
logical                       :: sort_down        !< Largest first.
integer(int32)                :: picked_run       !< The run chosen in the table (0: none).
real(real64)                  :: runs_tab_at(2)   !< Where the Runs tab is, for the test [pixels].
real(real64)                  :: header_at(2)     !< Where the iterations' header is, for the test [pixels].
real(real64)                  :: row_at(2)        !< Where the first row is, for the test [pixels].
character(len=64)             :: title_before     !< The title when its field took the keys.
integer(int32)                :: focus_on         !< A problem picked: the check whose field takes the keys (0: none).
integer(int32)                :: reveal           !< ... the section the tree scrolls to (0: none).
real(real64)                  :: problem_at(2)    !< Where the first problem's link is, for the test [pixels].
logical                       :: field_focused    !< The field the last problem named has the keys, for the test.
logical                       :: large_text       !< View > Larger text.
real(real64)                  :: font_px          !< The font's size in the last frame [pixels], for the test.
real(real64)                  :: bar_px           !< The tools' bar width in the last frame [pixels], for the test.

case_dir = ''
start_dir = '.'
allocate(runs(0), order(0))
sort_key = 1_int32
sort_down = .false.
picked_run = 0_int32
runs_tab_at = 0.0_real64
header_at = 0.0_real64
row_at = 0.0_real64
title_before = ''
focus_on = 0_int32
reveal = 0_int32
problem_at = 0.0_real64
field_focused = .false.
large_text = .false.
font_px = 0.0_real64
bar_px = 0.0_real64
remote = .false.                                     ! a window, or a test, until --remote says otherwise
last_report = ''
usage_errors = 0_int32
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
allocate(coarse(0, 0))
stride = 1_int32
load_cancelled = .false.
messages_shown = .false.
run_node = 0_int32
started = .false.
call get_command_argument(0, arg)
solver_path = arg(:index(arg, '/', back=.true.))//'tut11_heat' ! the solver is installed next to the studio
title_at = 0.0_real64
discard_at = 0.0_real64
ended = .false.
inquire(file=DEFAULT_LAYOUT, exist=have_default)
call get_command_argument(1, arg)
if (trim(arg) == '--test') then
   call get_command_argument(2, arg)
   call self_test(trim(arg))
   stop, quiet=.true.                                ! (no note on the floating-point flags of the run)
endif
port = 0_int32                                       ! --remote PORT and --run, before the window
run_now = .false.
do a = 1_int32, command_argument_count()
   call get_command_argument(a, arg)
   if (trim(arg) == '--run') run_now = .true.
   if (trim(arg) == '--remote') then
      call get_command_argument(a + 1_int32, arg)
      read(arg, *) port
   endif
enddo
remote = port > 0_int32
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
if (run_now) then
   if (can_run()) call start_run()
endif
if (remote) then                                     ! printed once the case is open: the browser finds it ready
   write(output_unit, '(A)') 'FIGURE: open '//trim(url)//' in a web browser'
   flush(output_unit)
endif
do while (app%next_frame(stat=stat))                 ! with stat: a usage error is reported, the studio goes on
   if (stat /= FIG_OK) call report_usage()
   call draw_studio()
enddo
call view%destroy()                                  ! before the application
call app%destroy()

contains
   subroutine open_window()
   !< Open the studio's window, its frame drawn by FIGURE, or serve its interface to a browser in remote mode.
   integer(int32) :: stat !< Status.

   if (remote) then                                  ! no window, no display, no GPU: a cluster node will do
      call app%init_remote(port=port, width=1100_int32, height=680_int32, max_fps=30.0_real64, compress='auto', &
                           quiet=.true., url=url, stat=stat) ! the address to open, with its access token
      if (stat /= FIG_OK) then
         write(output_unit, '(A)') 'tut20_tables: '//figure_last_error() ! a port in use, say
         stop 1, quiet=.true.
      endif
      call app%set_title('FIGURE studio')            ! the browser's tab shows it
   else
      call app%init('FIGURE studio', 1100_int32, 680_int32, decorations='figure', ini_file='tut20_tables.ini')
      call app%set_icon(ICON_FLAME, stat=stat)
      if (stat /= FIG_OK) write(output_unit, '(A)') 'no window icon here: '//figure_last_error()
   endif
   call app%set_confirm_quit(.true.)
   call view%init()                                  ! after app%init
   endsubroutine open_window

   subroutine draw_studio()
   !< One frame of the studio.
   font_px = ig_font_size()                          ! one em [pixels], for the test
   call draw_menus()
   call take_answers()
   call follow_run()
   call follow_load()
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
         if (ig_menu_item('Larger text', selected=large_text)) call set_text_size()
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
         if (ig_menu_item('Reset layout', enabled=have_default)) call reset_layout()
         call ig_end_menu()
      endif
      if (ig_begin_menu('Help')) then
         if (ig_menu_item(ICON_MESSAGES_SQUARE//' Messages', selected=messages_shown)) continue
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

   bar_px = ig_em(5)                                 ! 5 em: 75 pixels at 15, 95 at 19
   if (ig_begin_side_bar('tools', 'left', bar_px)) then
      do k = 1_int32, size(PANELS, kind=int32)
         if (ig_tool_button(trim(PANELS(k)), trim(ICONS(k)), width=ig_em(4), selected=current == k)) then
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
   integer(int32) :: stat  !< Status of the layout's save.
   logical        :: laid_out !< The layout's own focus was given on this frame.

   laid_out = save_default
   if (save_default) then
      call app%save_layout(DEFAULT_LAYOUT, comment='the studio as the program lays it out', stat=stat)
      if (ig_focus_window('Input')) continue                 ! of the two tabs, Input in front
      have_default = stat == FIG_OK                          ! a folder that cannot be written: no Reset layout
      save_default = .false.
   endif
   if (show_result .and. .not. laid_out .and. .not. ig_any_item_active()) then ! not while the user types or drags
      show_result = .not. ig_focus_window('Result')          ! a result read comes forward (not while a popup is open)
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
   if (messages_shown) then
      if (run_node /= 0_int32) call ig_set_next_window_dock(run_node) ! the first time: a tab beside Run
      if (ig_begin('Messages', open=messages_shown)) call draw_messages()
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
   !< The Case panel: the folder, the title (editable, committed when its field is left), the parameters.
   character(len=96)        :: line   !< A formatted line.
   type(item_status_object) :: last   !< What happened to the title field.
   type(case_t)             :: before !< The input before the title's edit.

   if (len(case_dir) == 0) then
      call ig_text_disabled('No case open.')
      if (remote) then                               ! a browser gives no paths of the server: no drops
         call ig_text_wrapped('Open one with File > Open case: the browser lists the files of the machine the '// &
                              'studio runs on.')
      else
         call ig_text_wrapped('Open one with File > Open case, or drop its folder (or its heat.inp) on the window.')
      endif
      if (ig_button(ICON_FOLDER_OPEN//' Open case...')) call browse_case()
      return
   endif
   call ig_text(ICON_FOLDER//' '//case_dir)
   call ig_same_line()
   if (ig_button(ICON_COPY//'##copy the path')) then ! to paste it in a terminal: cd, or sbatch
      call ig_set_clipboard(case_dir)                ! remote: the page writes it to the browser's clipboard
      call app%notify('The case''s path is on the clipboard', kind='info', seconds=3.0_real64)
   endif
   call ig_tooltip('Copy the case''s path')
   call ig_separator_text('Parameters')
   if (ig_input_text('title', inp%title)) continue    ! the field edits the variable as the user types
   call centre_of_last(title_at)                     ! for the test: where a user would click
   last = ig_last_item()                             ! what happened to the field, in one snapshot
   if (last%activated) title_before = inp%title       ! it took the keys: the title as it was
   if (last%deactivated_after_edit .and. inp%title /= title_before) then ! left after an edit: commit it
      before = inp
      before%title = title_before
      call push_undo(before)                         ! one undo step for the whole edit, not one per key
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
   if (ig_shortcut('ctrl+z')) then                   ! focused: only while Input, or a region of it, has the focus
      if (form_shown) call undo()                    ! (in the text, ctrl+z is the text field's own undo)
   endif
   call draw_checks()
   if (ig_begin_child('sections', width=ig_em(11.5_real64), border=.true.)) then
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
   if (reveal == n) then                             ! picked from a problem: the node scrolls into view
      call ig_scroll_here()                          ! its line to the centre of the region, on the next frame
      reveal = 0_int32
   endif
   endsubroutine section_node

   subroutine draw_form()
   !< The form of the section chosen in the tree; an edit marks the case edited and can be undone.
   type(case_t)   :: before   !< The input before this frame's edits.
   logical        :: changing !< The form changed the input in this frame.
   integer(int32) :: kind     !< A boundary's condition, as an index of KINDS.
   type(item_status_object) :: status !< What happened to a field.
   real(real64)             :: centre(2) !< The body's centre [m].
   integer(int32) :: k        !< Counter.

   before = inp
   changing = .false.
   select case (section)
   case (1_int32)                                     ! numeric fields: integers with +/- buttons, reals with a format
      call take_keys(1_int32)
      if (ig_input('nx', inp%nx, step=1_int32)) changing = .true.
      if (ig_input('ny', inp%ny, step=1_int32)) changing = .true.
      call take_keys(2_int32)
      if (ig_input('lx [m]', inp%lx, format='%.3f')) changing = .true.
      if (ig_input('ly [m]', inp%ly, format='%.3f')) changing = .true.
      inp%nx = max(inp%nx, 3_int32)                   ! the solver needs an interior
      inp%ny = max(inp%ny, 3_int32)
   case (3_int32)                                     ! sliders: the body stays inside the plate
      centre = [inp%body_x, inp%body_y]
      if (ig_drag('centre x, y [m]', centre, speed=0.002_real64, vmin=0.0_real64, vmax=max(inp%lx, inp%ly), &
                  format='%.3f')) then                ! one box per component, dragged or typed
         inp%body_x = centre(1)
         inp%body_y = centre(2)
         changing = .true.
      endif
      call take_keys(3_int32)
      if (ig_slider('radius [m]', inp%body_r, 0.01_real64, 0.5_real64 * min(inp%lx, inp%ly))) changing = .true.
      status = ig_last_item()
      field_focused = status%focused                 ! for the test
      inp%body_x = 0.001_real64 * nint(1000.0_real64 * inp%body_x) ! a slider gives any real: millimetres here
      inp%body_y = 0.001_real64 * nint(1000.0_real64 * inp%body_y)
      inp%body_r = 0.001_real64 * nint(1000.0_real64 * inp%body_r)
      if (ig_input('temperature [C]', inp%body_t, format='%.1f')) changing = .true.
   case (4_int32)
      call take_keys(5_int32)
      if (ig_slider('omega', inp%omega, 1.0_real64, 1.95_real64)) changing = .true.
      inp%omega = 0.01_real64 * nint(100.0_real64 * inp%omega)       ! two decimals
      call ig_tooltip('Over-relaxation: 1 is Gauss-Seidel, close to 2 converges faster or not at all')
      call take_keys(6_int32)
      if (ig_slider('tolerance', inp%tolerance, 1.0e-10_real64, 1.0e-2_real64, format='%.1e', scale='log')) &
         changing = .true.                            ! a decade per equal stretch of the slider
      call take_keys(7_int32)
      if (ig_input('iterations at most', inp%max_iter, step=100_int32)) changing = .true.
   end select
   if (section == 2_int32) then
      if (ig_begin_table('boundaries', 3_int32)) then
         call ig_table_setup_column('side', width=ig_em(4.5_real64))
         call ig_table_setup_column('condition', width=ig_em(11))
         call ig_table_setup_column('temperature [C]')
         call ig_table_headers_row()
         do k = 1_int32, size(SIDES, kind=int32)
            call ig_push_id(k)                        ! the same widgets in every row: an id scope per row
            call ig_table_next_row()
            call ig_table_next_column()
            if (ig_selectable(trim(SIDES(k)), .false.)) continue
            if (ig_begin_popup_context('side')) then  ! a right click on the side's name
               if (ig_menu_item('Every side as this one')) then
                  inp%bc_kind = inp%bc_kind(k)
                  inp%bc_value = inp%bc_value(k)
                  changing = .true.
               endif
               if (ig_menu_item('Insulated', enabled=inp%bc_kind(k) /= KINDS(2))) then
                  inp%bc_kind(k) = KINDS(2)
                  changing = .true.
               endif
               call ig_end_popup()
            endif
            call ig_table_next_column()
            kind = merge(1_int32, 2_int32, inp%bc_kind(k) == KINDS(1))
            if (k == 1_int32) call take_keys(4_int32)
            if (ig_radio('fixed', kind, 1_int32)) changing = .true. ! a click sets kind to the button's value
            call ig_same_line()
            if (ig_radio('insulated', kind, 2_int32)) changing = .true.
            inp%bc_kind(k) = KINDS(kind)
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
   if (len(case_dir) > 0) can_run = .not. solver%running() .and. size(problems(inp)) == 0
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
   call add_run()
   if (solver%killed()) then
      run_status = ICON_SQUARE//' stopped'
      call app%notify('The run was stopped', kind='warning')
   elseif (solver%exit_code() == 0_int32) then
      write(run_status, '(A,I0,A,ES8.2)') 'converged in ', nint(iters(size(iters))), ' iterations, residual ', &
                                          res(size(res))
      call app%notify('The solver '//trim(run_status), kind='success', seconds=10.0_real64)
      call load_field()
   else
      select case (solver%exit_code())                ! the solver's own codes (tut11_heat.F90)
      case (1_int32)
         run_status = 'the solver cannot read heat.inp: see the log'
      case (2_int32)
         write(run_status, '(A,I0,A)') 'not converged in ', inp%max_iter, ' iterations: raise max_iter or omega'
      case default
         write(run_status, '(A,I0,A)') 'the solver failed, exit code ', solver%exit_code(), ': see the log'
      endselect
      call app%notify(trim(run_status), kind='error', seconds=8.0_real64) ! the notification has its own mark
      run_status = '[!!] '//trim(run_status)          ! the status bar's: a mark with the words
   endif
   endsubroutine follow_run

   subroutine add_run()
   !< The run that just ended, added to the session's runs; the table keeps its order.
   type(run_t) :: r !< The run.

   r%number = size(runs, kind=int32) + 1_int32
   r%title = inp%title
   r%iterations = 0_int32
   if (size(iters) > 0) r%iterations = nint(iters(size(iters)), int32)
   if (size(res) > 0) r%residual = res(size(res))
   if (solver%killed()) then
      r%outcome = 'stopped'
   elseif (solver%exit_code() == 0_int32) then
      r%outcome = 'converged'
   else
      r%outcome = 'failed'
   endif
   r%it = iters
   r%res = res
   runs = [runs, r]
   order = [order, r%number]
   call sort_runs()                                  ! a new row takes its place in the order asked
   endsubroutine add_run

   subroutine sort_runs()
   !< Sort the permutation `order` by column `sort_key` (`sort_down`: largest first): the runs do not move. FIGURE
   !< reports the order the user asks; sorting is the program's.
   integer(int32) :: a, b   !< Positions.
   integer(int32) :: moving !< The index being placed.

   if (sort_key == 0_int32) then
      order = [(a, a = 1_int32, size(runs, kind=int32))]
      return
   endif
   do a = 2_int32, size(order, kind=int32)           ! an insertion sort: stable, and the rows are few
      moving = order(a)
      b = a - 1_int32
      do while (b >= 1_int32)
         if (.not. before(moving, order(b))) exit
         order(b + 1_int32) = order(b)
         b = b - 1_int32
      enddo
      order(b + 1_int32) = moving
   enddo
   endsubroutine sort_runs

   logical function before(p, q)
   !< Run `p` goes before run `q` in the order asked.
   integer(int32), intent(in) :: p !< A run.
   integer(int32), intent(in) :: q !< Another run.

   select case (sort_key)
   case (2_int32)
      before = merge(runs(p)%title > runs(q)%title, runs(p)%title < runs(q)%title, sort_down)
   case (3_int32)
      before = merge(runs(p)%residual > runs(q)%residual, runs(p)%residual < runs(q)%residual, sort_down)
   case (4_int32)
      before = merge(runs(p)%outcome > runs(q)%outcome, runs(p)%outcome < runs(q)%outcome, sort_down)
   case (5_int32)
      before = merge(runs(p)%iterations > runs(q)%iterations, runs(p)%iterations < runs(q)%iterations, sort_down)
   case default
      before = merge(p > q, p < q, sort_down)
   endselect
   endfunction before

   subroutine draw_runs()
   !< The Runs tab: a table of the session's runs, its header frozen, sorted by the column clicked.
   real(real64)      :: red(4)  !< The palette's error colour.
   character(len=24) :: text    !< A number, written.
   integer(int32)    :: remove  !< A run to remove, after the table (0: none).
   integer(int32)    :: r, k    !< Row, run.

   if (size(runs) == 0) then
      call ig_text_disabled('The runs of this session, once one has ended.')
      return
   endif
   call app%palette_color('error', red)
   remove = 0_int32
   if (ig_begin_table('runs', 5_int32, flags=ior(ImGuiTableFlags_RowBg, ImGuiTableFlags_BordersInnerV), &
                      freeze_rows=1_int32, sortable=.true.)) then ! the header stays in view; the rows scroll
      call ig_table_setup_column('run', width=ig_em(3), default_sort=.true.)
      call ig_table_setup_column('case', stretch=1.0_real64)
      call ig_table_setup_column('residual', width=ig_em(6))
      call ig_table_setup_column('outcome', width=ig_em(7))
      call ig_table_setup_column('iterations', width=ig_em(6))
      if (ig_table_sort(sort_key, sort_down)) call sort_runs() ! a header clicked: the program sorts its rows
      call ig_table_headers_row()
      call centre_of_last(header_at)                 ! the last header, iterations: for the test
      do r = 1_int32, size(order, kind=int32)
         k = order(r)
         call ig_push_id(runs(k)%number)             ! each row's menu has its own id
         call ig_table_next_row()
         if (runs(k)%outcome /= 'converged') call ig_table_row_color([red(1:3), 0.25_real64]) ! with a mark below
         call ig_table_next_column()
         write(text, '(I0)') runs(k)%number
         if (ig_selectable(trim(text), k == picked_run)) picked_run = k
         if (r == 1_int32) call centre_of_last(row_at)
         call run_menu(k, remove)
         call ig_table_next_column()
         call ig_text(trim(runs(k)%title))
         call ig_table_next_column()
         write(text, '(ES9.2)') runs(k)%residual
         call ig_text(trim(text))
         call ig_table_next_column()
         call ig_text(trim(merge('     ', '[!!] ', runs(k)%outcome == 'converged'))//trim(runs(k)%outcome))
         call ig_table_next_column()
         write(text, '(I0)') runs(k)%iterations
         call ig_text(trim(text))
         call ig_pop_id()
      enddo
      call ig_end_table()
   endif
   if (remove > 0_int32) call remove_run(remove)     ! the list changes after it is drawn, not while
   endsubroutine draw_runs

   subroutine run_menu(k, remove)
   !< The context menu and the tooltip of run `k`'s row, on the item just drawn.
   integer(int32), intent(in)    :: k      !< The run.
   integer(int32), intent(inout) :: remove !< The run to remove, if asked.
   character(len=24)             :: text   !< The residual, written.

   if (ig_begin_popup_context('run')) then            ! a right click on the row
      write(text, '(ES12.5)') runs(k)%residual
      if (ig_menu_item('Copy the residual')) call ig_set_clipboard(trim(adjustl(text)))
      if (ig_menu_item('Remove from the list')) remove = k
      call ig_end_popup()
   endif
   if (ig_begin_item_tooltip()) then                  ! the pointer rests on the row: its residuals
      if (ip_begin_plot('##history', width=ig_em(18), height=ig_em(10))) then
         call ip_setup_axes('iteration', 'residual', yscale='log')
         call ip_line('residual', runs(k)%it, runs(k)%res)
         call ip_end_plot()
      endif
      call ig_end_tooltip()
   endif
   endsubroutine run_menu

   subroutine remove_run(k)
   !< Remove run `k` from the session's list.
   integer(int32), intent(in) :: k !< The run.
   integer(int32)             :: j !< Counter.

   runs = [runs(:k - 1), runs(k + 1:)]
   do j = 1_int32, size(runs, kind=int32)
      runs(j)%number = j
   enddo
   order = [(j, j = 1_int32, size(runs, kind=int32))]
   call sort_runs()
   picked_run = 0_int32
   endsubroutine remove_run

   subroutine draw_run()
   !< The Run panel: Run and Stop; the log and the residuals of the run, or the table of the session's runs.
   logical :: docked !< The panel is docked.

   call ig_window_dock(run_node, docked)             ! where Run is: the Messages panel joins it
   if (.not. docked) run_node = 0_int32
   if (len(case_dir) == 0) then
      call ig_text_disabled('The solver, its log and its residuals, once a case is open.')
      return
   endif
   call ig_begin_disabled(.not. can_run())           ! one run at a time
   call ig_set_next_item_shortcut('f5', scope='global') ! the button owns F5, wherever the focus is; its tooltip says so
   if (ig_button(ICON_PLAY//' Run')) call start_run()
   call ig_end_disabled()
   if (size(problems(inp)) > 0) call ig_tooltip('The input has problems: see the Input panel')
   call ig_same_line()
   call ig_begin_disabled(.not. solver%running())
   if (ig_button(ICON_SQUARE//' Stop')) call solver%kill() ! the solver ends; follow_run tells
   call ig_end_disabled()
   call ig_same_line()
   call ig_text(trim(run_status))
   if (ig_begin_tab_bar('run views')) then
      if (ig_begin_tab('This run')) then
         if (ig_begin_child('log', width=ig_em(25))) call output%draw('output') ! only the lines in view
         call ig_end_child()
         call ig_same_line()
         if (size(res) == 0) then
            call ig_text_disabled('The residuals, as the solver prints them.')
         elseif (ip_begin_plot('Residuals', width=-1.0_real64, height=-1.0_real64)) then
            call ip_setup_axes('iteration', 'residual', auto_fit=.true., yscale='log') ! follows the data
            call ip_line('residual', iters, res)
            call ip_end_plot()
         endif
         call ig_end_tab()
      endif
      if (ig_begin_tab('Runs')) then
         call draw_runs()
         call ig_end_tab()
      endif
      call centre_of_last(runs_tab_at)                ! the tab, or the last item of the table: for the test
      call ig_end_tab_bar()
   endif
   endsubroutine draw_run

   subroutine draw_status()
   !< The status bar: a bar along the bottom with the run's state and its progress.
   real(real64) :: fraction !< Progress towards the tolerance, on a logarithmic scale.

   if (ig_begin_side_bar('status', 'bottom', ig_frame_height() + ig_em(0.6_real64))) then ! a row of widgets and a margin
      if (solver%running()) then
         fraction = -1.0_real64                      ! indeterminate until two residuals are known
         if (size(res) > 1) fraction = min(1.0_real64, max(0.0_real64, &
                                           log(res(1) / res(size(res))) / log(res(1) / inp%tolerance)))
         call ig_progress_bar(fraction, width=ig_em(13))
         call ig_same_line()
         if (size(res) > 0) write(run_status, '(A,I0,A,ES8.2)') 'running: iteration ', nint(iters(size(iters))), &
                                                                 ', residual ', res(size(res))
      endif
      if (loader%running()) then
         call ig_text('reading field.dat')
      else
         call ig_text(trim(run_status))
      endif
   endif
   call ig_end()
   endsubroutine draw_status

   subroutine load_field()
   !< Start reading the case's field.dat, written by the solver, as a task; no file, no field.
   type(field_t)  :: request !< What the task gets: the file.
   logical        :: there   !< The case has a result.
   integer(int32) :: stat    !< Status of the start.

   call view%clear()                                 ! the meshes go before their arrays do
   deallocate(field, coarse)
   allocate(field(0, 0), coarse(0, 0))
   inquire(file=case_dir//'/field.dat', exist=there)
   if (.not. there) return                           ! not run yet
   if (loader%running()) then
      call app%notify('A field is being read: open the case again when it is done', kind='warning')
      return
   endif
   if (loader%done()) call take_field()              ! a result not taken yet: taken, then replaced
   request%file = case_dir//'/field.dat'
   call loader%start(read_field, request, stat=stat) ! the task gets a copy of request
   if (stat /= FIG_OK) call app%notify(figure_last_error(), kind='error')
   show_result = .true.                              ! the Result panel shows the progress
   endsubroutine load_field

   subroutine follow_load()
   !< Every frame: once the reading task is done, take its field.
   if (loader%done()) call take_field()
   endsubroutine follow_load

   subroutine take_field()
   !< Take the field the task read (no copy), or tell why there is none.
   class(*), allocatable :: data !< The task's data, given back.
   integer(int32)        :: stat !< The task's status.

   call loader%result(data, stat=stat)               ! moved out of the task; the task object is free again
   if (stat /= FIG_OK) then
      call app%notify('field.dat does not read: '//figure_last_error(), kind='error') ! h%fail's message
      return
   endif
   if (load_cancelled) then                          ! what was read is left as it was: not shown
      load_cancelled = .false.
      call app%notify('Reading field.dat was stopped', kind='warning')
      return
   endif
   select type (data)
   type is (field_t)
      call move_alloc(data%values, field)
      call move_alloc(data%coarse, coarse)
      flx = data%lx
      fly = data%ly
      stride = data%stride
   endselect
   probe_x = 0.5_real64 * flx
   point = [0.25_real64 * flx, 0.75_real64 * fly]
   show_result = .true.
   call build_3d()
   endsubroutine take_field

   subroutine build_3d()
   !< The 3-D view of the field: the temperature as a surface over the plate, and the body as a cylinder.
   real(real64)   :: dx, dy, h !< Grid spacing [m]; height of a degree [m].
   real(real64)   :: tmin      !< The coldest temperature, at the plate's level [C].
   real(real64)   :: th        !< An angle around the body.
   integer(int32) :: i, j      !< Counters.

   call view%clear()                                 ! the meshes go before their arrays change
   deallocate(carpet)
   allocate(carpet(3, size(coarse, 1), size(coarse, 2))) ! the coarse copy: at most MAX_SHOWN nodes a side
   dx = stride * flx / (size(field, 1) - 1)
   dy = stride * fly / (size(field, 2) - 1)
   tmin = minval(field)
   h = 0.4_real64 * max(flx, fly) / max(1.0e-12_real64, maxval(field) - tmin) ! the hottest 0.4 plate high
   do j = 1_int32, size(coarse, 2, kind=int32)
      do i = 1_int32, size(coarse, 1, kind=int32)
         carpet(:, i, j) = [(i - 1) * dx, (j - 1) * dy, h * (coarse(i, j) - tmin)]
      enddo
   enddo
   do i = 1_int32, size(body, 2, kind=int32)       ! the cylinder, from the plate up to the body's temperature
      th = 2.0_real64 * acos(-1.0_real64) * (i - 1) / (size(body, 2) - 1)
      body(:, i, 1) = [inp%body_x + inp%body_r * cos(th), inp%body_y + inp%body_r * sin(th), 0.0_real64]
      body(:, i, 2) = [body(1:2, i, 1), h * (inp%body_t - tmin) + 0.15_real64 * max(flx, fly)]
   enddo
   carpet_mesh = view%surface(carpet, scalar=coarse, colormap=trim(MAPS(map)), edges=grid3d) ! read in place
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
   integer(int32)    :: k       !< Counter.
   character(len=48) :: text    !< A label.
   real(real64)      :: fraction !< The reading's progress.
   real(real64)      :: cx, cy   !< The coarse copy's extent [m] (the plate, or a little less).
   character(len=:), allocatable :: msg !< The task's message.

   if (loader%running()) then                        ! every frame while it reads: the window never waits for it
      call loader%progress(fraction, msg)
      call ig_progress_bar(fraction, label=msg, width=ig_em(20))
      call ig_same_line()
      if (ig_button(ICON_SQUARE//' Stop')) then
         load_cancelled = .true.
         call loader%cancel()                        ! the task stops at its next safe point
      endif
      return
   endif
   if (size(field) == 0) then
      call ig_text_disabled('The field the solver computed, once it has run.')
      return
   endif
   if (ig_shortcut('left', repeat=.true.)) probe_x = max(0.0_real64, probe_x - flx / (size(field, 1) - 1)) ! a node
   if (ig_shortcut('right', repeat=.true.)) probe_x = min(flx, probe_x + flx / (size(field, 1) - 1))     ! left, right
   dx = stride * flx / (size(field, 1) - 1)          ! the coarse copy's spacing
   dy = stride * fly / (size(field, 2) - 1)
   cx = (size(coarse, 1) - 1) * dx
   cy = (size(coarse, 2) - 1) * dy
   tmin = minval(field)
   tmax = maxval(field)
   call ig_set_next_item_width(ig_em(9))
   if (ig_combo('colormap', map, MAPS)) call view%set_mesh(carpet_mesh, colormap=trim(MAPS(map))) ! the 3-D view too
   call ig_same_line()
   call ig_set_next_item_width(ig_em(9))
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
   if (ip_begin_plot('Temperature [C]', width=ig_em(28), height=-1.0_real64, equal=.true.)) then
      call ip_setup_axes('x [m]', 'y [m]')
      ! the cells' edges: half a spacing beyond the first and last nodes
      call ip_heatmap('##t', coarse, -0.5_real64 * dx, cx + 0.5_real64 * dx, -0.5_real64 * dy, cy + 0.5_real64 * dy, &
                      scale_min=tmin, scale_max=tmax, colormap=cmap)
      if (contours .and. bands > 0_int32) then      ! the lines at the bands' edges
         call ip_contour('##isotherms', coarse, 0.0_real64, cx, 0.0_real64, cy, &
                         levels=[(tmin + k * (tmax - tmin) / bands, k = 1_int32, bands - 1_int32)], &
                         color=[0.1_real64, 0.1_real64, 0.1_real64, 1.0_real64], labels=.true.)
      elseif (contours) then                         ! about ten lines at round values
         call ip_contour('##isotherms', coarse, 0.0_real64, cx, 0.0_real64, cy, nlevels=10_int32, &
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
      write(text, '(F6.2,A)') temperature(point(1), point(2)), ' C' ! from the field itself, every node
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
   call draw_profile(fly / (size(field, 2) - 1))      ! the profile reads the field itself, every node
   endsubroutine draw_result

   subroutine draw_profile(dy)
   !< The temperature along the probe line, and the spread of the five columns around it at a dozen nodes.
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
   do j = 1_int32, size(field, 2, kind=int32), max(1_int32, size(field, 2, kind=int32) / 12_int32)
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

   function problems(c) result(list)
   !< What is wrong with an input, one line each; none: an empty list. What the solver would refuse or not survive.
   type(case_t), intent(in)       :: c       !< The input.
   character(len=72), allocatable :: list(:) !< The problems.
   character(len=72)              :: what(7) !< Every check's message.
   logical                        :: bad(7)  !< Every check's outcome.

   what(1) = 'the grid needs at least 3 x 3 nodes'
   bad(1) = c%nx < 3_int32 .or. c%ny < 3_int32
   what(2) = 'the plate needs a positive size'
   bad(2) = c%lx <= 0.0_real64 .or. c%ly <= 0.0_real64
   what(3) = 'the body reaches the plate''s edge'
   bad(3) = c%body_x - c%body_r <= 0.0_real64 .or. c%body_x + c%body_r >= c%lx .or. &
            c%body_y - c%body_r <= 0.0_real64 .or. c%body_y + c%body_r >= c%ly
   what(4) = 'every side insulated: the temperature is not determined'
   bad(4) = all(c%bc_kind == 'insulated')
   what(5) = 'omega must be in (0, 2): over-relaxation diverges at 2'
   bad(5) = c%omega <= 0.0_real64 .or. c%omega >= 2.0_real64
   what(6) = 'the tolerance must be positive'
   bad(6) = c%tolerance <= 0.0_real64
   what(7) = 'at least one iteration'
   bad(7) = c%max_iter < 1_int32
   list = pack(what, bad)                            ! the messages of the checks that failed
   endfunction problems

   function problem_ids(c) result(ids)
   !< The checks of `problems` that fail, in the same order: 1 the grid, 2 the plate, 3 the body, 4 the sides, 5 omega,
   !< 6 the tolerance, 7 the iterations.
   type(case_t), intent(in)    :: c      !< The input.
   integer(int32), allocatable :: ids(:) !< The checks that failed.
   logical                     :: bad(7) !< Every check's outcome.

   bad = [c%nx < 3_int32 .or. c%ny < 3_int32, c%lx <= 0.0_real64 .or. c%ly <= 0.0_real64, &
          c%body_x - c%body_r <= 0.0_real64 .or. c%body_x + c%body_r >= c%lx .or. &
          c%body_y - c%body_r <= 0.0_real64 .or. c%body_y + c%body_r >= c%ly, all(c%bc_kind == 'insulated'), &
          c%omega <= 0.0_real64 .or. c%omega >= 2.0_real64, c%tolerance <= 0.0_real64, c%max_iter < 1_int32]
   ids = pack([1_int32, 2_int32, 3_int32, 4_int32, 5_int32, 6_int32, 7_int32], bad)
   endfunction problem_ids

   subroutine take_keys(check)
   !< Before a field: if the problem picked is `check`, the field takes the keyboard focus (edited, as if clicked).
   integer(int32), intent(in) :: check !< The check whose field comes next.

   if (focus_on /= check) return
   call ig_focus_here()                              ! the next item takes the keys; applied on the next frame
   focus_on = 0_int32
   endsubroutine take_keys

   subroutine draw_checks()
   !< The input's problems, above the tree: each marked [!!] in the palette's error colour.
   character(len=72), allocatable :: list(:) !< The problems.
   integer(int32), allocatable    :: ids(:)  !< Their checks.
   real(real64)                   :: red(4)  !< The palette's error colour.
   integer(int32)                 :: k       !< Counter.

   list = problems(inp)
   if (size(list) == 0) return
   ids = problem_ids(inp)
   call app%palette_color('error', red)              ! the palette's: right in a light palette and in a dark one
   call ig_push_style_color('TextLink', red)
   do k = 1_int32, size(list, kind=int32)            ! a mark with the colour: never colour alone
      if (ig_text_link('[!!] '//trim(list(k)))) then ! a click: the section, scrolled to, its field given the keys
         section = SECTION_OF(ids(k))
         reveal = section
         focus_on = ids(k)
      endif
      if (k == 1_int32) call centre_of_last(problem_at)
   enddo
   call ig_pop_style_color()
   endsubroutine draw_checks

   subroutine reset_layout()
   !< Load the layout the program set; the file may have gone since.
   integer(int32) :: stat !< Status of the load.

   call app%load_layout(DEFAULT_LAYOUT, stat=stat)   ! a file of the user's: it can be gone or broken
   if (stat /= FIG_OK) call app%notify(code_name(stat)//': '//figure_last_error(), kind='error')
   endsubroutine reset_layout

   function code_name(stat) result(name)
   !< The name of a status code, for a message.
   integer(int32), intent(in)    :: stat !< Status.
   character(len=:), allocatable :: name !< Its name.

   select case (stat)
   case (FIG_OK)
      name = 'FIG_OK'
   case (FIG_ERR_STATE)
      name = 'FIG_ERR_STATE'
   case (FIG_ERR_ARGUMENT)
      name = 'FIG_ERR_ARGUMENT'
   case (FIG_ERR_FAILED)
      name = 'FIG_ERR_FAILED'
   case (FIG_ERR_EXCEPTION)
      name = 'FIG_ERR_EXCEPTION'
   case default
      name = 'unknown status'
   endselect
   endfunction code_name

   subroutine draw_messages()
   !< Every notification of this session, newest first: what the user may have missed.
   character(len=:), allocatable :: list(:)  !< Their texts.
   character(len=7), allocatable :: kinds(:) !< Their kinds.
   logical, allocatable          :: shown(:) !< Still shown in the corner.
   real(real64)                  :: rgba(4)  !< A role's colour.
   integer(int32)                :: k        !< Counter.

   call app%notifications(list, kinds, shown)        ! the last 100, oldest first
   if (size(list) == 0) call ig_text_disabled('No message yet.')
   do k = size(list, kind=int32), 1_int32, -1_int32
      select case (kinds(k))
      case ('error')
         call app%palette_color('error', rgba)
         call ig_text_colored('[!!] '//trim(list(k)), rgba)
      case ('warning')
         call app%palette_color('warning', rgba)
         call ig_text_colored('(!)  '//trim(list(k)), rgba)
      case ('success')
         call app%palette_color('success', rgba)
         call ig_text_colored('[ok] '//trim(list(k)), rgba)
      case default
         call ig_text('     '//trim(list(k)))
      endselect
   enddo
   endsubroutine draw_messages

   subroutine report_usage()
   !< A usage error of the last frame, as a notification (in the Messages panel too); the same report is not repeated
   !< on every frame of the bug.
   if (figure_last_error() /= last_report) call app%notify(figure_last_error(), kind='error', seconds=0.0_real64)
   last_report = figure_last_error()                 ! one line per error, naming the Fortran calls
   endsubroutine report_usage

   subroutine centre_of_last(at)
   !< The centre of the widget drawn last [pixels]: where a test aims.
   real(real64), intent(out) :: at(2) !< Centre.
   real(real64)              :: r(4)  !< Its rectangle.

   call ig_item_rect(r(1), r(2), r(3), r(4))
   at = [0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4))]
   endsubroutine centre_of_last

   subroutine self_test(dir)
   !< The studio driven headless as a user would; one line per check, an error stop if one fails.
   character(len=*), intent(in)  :: dir        !< Where the example cases are written.
   character(len=:), allocatable :: folder     !< The browser's folder.
   character(len=:), allocatable :: entries(:) !< Its entries.
   character(len=512)            :: drop(1)    !< A path to drop.
   real(real64)                  :: r(4)       !< A rectangle [pixels].
   logical                       :: found      !< A part or a popup is there.
   logical                       :: shown      !< The browser is shown.
   character(len=:), allocatable :: hit        !< The frame's hit test at a point.
   character(len=:), allocatable :: title      !< The window's title.
   real(real64)                  :: x          !< The probe line before a key.
   integer(int32)                :: k          !< Counter.

   failed = 0_int32
   checks = 0_int32
   call write_examples(dir)
   start_dir = dir
   call app%init_headless(1100_int32, 680_int32, decorations='figure') ! no window, no GPU: the title bar still drawn
   call app%set_title('FIGURE studio')               ! headless mode has no title until one is set
   call app%set_confirm_quit(.true.)
   call view%init()
   call frames(3_int32)

   call test_frame_rect('menus', r(1), r(2), r(3), r(4), found)
   call check(found, 'the title bar holds the studio''s menus')
   call test_frame_rect('title', r(1), r(2), r(3), r(4), found)
   hit = test_frame_hit(0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4))) ! what the system is told
   call check(found .and. hit == 'drag', 'the title drags the window')

   call test_key('shortcut', down=.true.)            ! ctrl, cmd on macOS
   call test_key('o')
   call test_key('shortcut', down=.false.)
   call frames(6_int32)
   call test_file_browser(shown, folder=folder, entries=entries)
   call check(shown .and. any(entries == 'plate/'), 'ctrl+o shows the file browser on the example cases')
   call test_file_browser_rect('entry:plate', r(1), r(2), r(3), r(4), found)
   call test_click(0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4)))
   call test_click(0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4)))   ! a double-click enters the folder
   call frames(12_int32)
   call test_file_browser_rect('ok', r(1), r(2), r(3), r(4), found)          ! Choose
   call test_click(0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4)))
   call frames(8_int32)
   title = app%title()
   call check(index(case_dir, '/plate', back=.true.) == len(case_dir) - 5 .and. &
              title == 'Heated plate - FIGURE studio', 'Choose opens the case, the window''s title says which')

   call test_click(title_at(1), title_at(2))         ! the title field, where the user clicks it
   call frames(5_int32)
   call test_type(' X')
   call test_key('escape')                           ! leaves the field as it was
   call frames(6_int32)
   call check(trim(inp%title) == 'Heated plate' .and. .not. edited, 'escape leaves the title as it was, unedited')
   call test_click(title_at(1), title_at(2))
   call frames(5_int32)
   call test_key('shortcut', down=.true.)            ! select what is there
   call test_key('a')
   call test_key('shortcut', down=.false.)
   call test_type('Plate B')                         ! and type over it
   call test_key('enter')
   call frames(8_int32)
   title = app%title()
   call check(trim(inp%title) == 'Plate B' .and. title == '* Plate B - FIGURE studio' .and. nhistory == 1_int32, &
              'enter commits the title, one undo step, and the window''s title marks it unsaved')

   drop(1) = dir//'/channel'
   call test_drop(drop, 600.0_real64, 300.0_real64) ! a folder dropped on the window
   call frames(6_int32)
   call test_popup_rect(r(1), r(2), r(3), r(4), found)
   call check(found .and. trim(inp%title) == 'Plate B', 'a drop asks before discarding the edit')
   call test_click(discard_at(1), discard_at(2))
   call frames(6_int32)
   call check(trim(inp%title) == 'Cooled channel' .and. .not. edited, 'Discard opens the dropped case')

   call test_key('f5')
   call frames(3_int32)
   do k = 1_int32, 1000000_int32                     ! frames until the solver ends (it runs in real time)
      if (.not. started) exit
      call frames(1_int32)
   enddo
   call check(index(run_status, 'converged in') == 1, 'F5 runs the solver to convergence')
   do k = 1_int32, 1000000_int32                     ! and until the task has read its field
      if (size(field) > 0) exit
      call frames(1_int32)
   enddo
   call check(size(field) == inp%nx * inp%ny, 'the task reads the field the solver wrote')


   call test_window_rect('Result', r(1), r(2), r(3), r(4), found) ! Result came forward with the field: it has the focus
   x = probe_x
   call test_key('right')                            ! the Result panel's key: the probe line moves a node right
   call frames(4_int32)
   call check(found .and. probe_x > x, 'right moves the probe line while Result has the focus')
   call test_click(title_at(1), title_at(2))         ! the title field takes the keys
   call frames(5_int32)
   x = probe_x
   call test_key('right')                            ! the field's: its cursor moves, the probe line stays
   call frames(4_int32)
   call check(probe_x == x, 'and not while the title field is edited')
   call test_key('escape')                           ! the field is left; the Case panel keeps the focus
   call frames(3_int32)
   call test_key('right')
   call frames(4_int32)
   call check(probe_x == x, 'nor while another panel has the focus')

   inp%omega = 1.5_real64                            ! a second run, slower to converge (the edit saved by F5)
   edited = .true.
   call test_key('f5')
   call frames(3_int32)
   do k = 1_int32, 1000000_int32
      if (.not. started) exit
      call frames(1_int32)
   enddo
   do k = 1_int32, 1000000_int32                     ! and its field read: the Result panel comes forward with it,
      if (size(field) > 0) exit                      ! at a time of the task's, not of the test's
      call frames(1_int32)
   enddo
   call test_click(runs_tab_at(1), runs_tab_at(2))   ! the Runs tab
   call frames(6_int32)
   call test_click(header_at(1), header_at(2))       ! the iterations' header: fewest first
   call frames(6_int32)
   call check(size(runs) == 2 .and. runs(order(1))%iterations < runs(order(2))%iterations .and. order(1) == 1, &
              'two runs in the table, sorted by iterations on a click of its header')
   call test_click(header_at(1), header_at(2))       ! again: most first
   call frames(6_int32)
   call check(order(1) == 2 .and. sort_down, 'a second click reverses the order')
   call test_click(row_at(1), row_at(2), button='right') ! a right click on the first row
   call frames(6_int32)
   call test_popup_rect(r(1), r(2), r(3), r(4), found)
   call check(found, 'a right click on a run opens its menu')
   call test_key('escape')
   call frames(4_int32)

   inp%body_r = 0.5_real64                           ! the body out of the plate
   call frames(2_int32)
   if (app%next_frame()) then                        ! Input in front, to show the problem
      if (ig_focus_window('Input')) continue
      call draw_studio()
   endif
   call frames(4_int32)
   call test_click(problem_at(1), problem_at(2))     ! the problem's link
   call frames(6_int32)
   call check(section == 3_int32 .and. field_focused, 'a click on a problem shows the Body section, the radius in keys')
   call test_key('escape')
   call frames(3_int32)
   call check(.not. can_run() .and. size(problems(inp)) == 1, 'an input with the body out of the plate is refused')
   inp%body_r = 0.2_real64
   call check(can_run(), 'and accepted once corrected')

   large_text = .true.
   call set_text_size()                              ! View > Larger text
   call frames(3_int32)
   call check(font_px == 19.0_real64 .and. bar_px == 95.0_real64, 'larger text: one em is 19 pixels, the bar 5 em')
   large_text = .false.
   call set_text_size()
   call frames(2_int32)

   if (app%next_frame(stat=stat)) then               ! a frame with a mistake in it
      call draw_studio()
      call ig_end_tab()                              ! a stray end: no tab is open here
   endif
   if (app%next_frame(stat=stat)) call draw_studio() ! the next frame reports it, and the studio goes on
   call check(stat == FIG_ERR_STATE .and. index(figure_last_error(), 'ig_end_tab: no ig_begin_tab is open') > 0, &
              'a stray ig_end_tab is reported by the next frame, naming the call')
   write(output_unit, '(A)') '         '//figure_last_error()
   call check(usage_errors == 0_int32, 'no other frame of the test had a usage error')

   edited = .false.                                  ! nothing to lose: close quits
   call test_frame_rect('close', r(1), r(2), r(3), r(4), found)
   call test_click(0.5_real64 * (r(1) + r(3)), 0.5_real64 * (r(2) + r(4)))
   call frames(8_int32)
   call check(ended, 'the title bar''s close button ends the studio')

   call view%destroy()
   call app%destroy()
   write(output_unit, '(I0,A,I0,A)') checks - failed, ' of ', checks, ' checks passed'
   if (failed > 0_int32) error stop 'tut20_tables: a check failed'
   endsubroutine self_test

   subroutine check(passed, what)
   !< One check: a line saying what was checked, and whether it held.
   logical,          intent(in) :: passed !< It held.
   character(len=*), intent(in) :: what   !< What was checked.

   checks = checks + 1_int32
   if (.not. passed) failed = failed + 1_int32
   write(output_unit, '(A)') merge('[ok]     ', '[FAILED] ', passed)//what
   endsubroutine check

   subroutine frames(n)
   !< Draw `n` frames of the studio, as the main loop does; `ended` once next_frame says the studio ends.
   integer(int32), intent(in) :: n !< Frames.
   integer(int32)             :: k !< Counter.

   do k = 1_int32, n
      if (.not. app%next_frame(stat=stat)) then
         ended = .true.
         return
      endif
      if (stat /= FIG_OK) then                       ! a usage error in the frame before: the test says which
         usage_errors = usage_errors + 1_int32
         write(output_unit, '(A)') figure_last_error()
      endif
      call draw_studio()
   enddo
   endsubroutine frames

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
      call centre_of_last(discard_at)
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
   call ig_set_next_window(ig_em(26), ig_em(15), ig_em(22), ig_em(11)) ! where it opens, and its size: in em
   if (ig_begin_popup_modal('About the studio')) then
      call ig_text(ICON_FLAME//' FIGURE studio')
      call ig_text_wrapped('The solver studio of FIGURE''s tutorial: a case, its input, a run of the solver and '// &
                           'its result, in one window.')
      call ig_text('Look: '//trim(look)//', palette: '//trim(palette))
      call ig_align_begin('close', 'right')          ! the button at the right edge: its width from the last frame
      if (ig_button('Close')) call ig_close_current_popup()
      call ig_align_end()
      call ig_end_popup()
   endif
   endsubroutine draw_dialogs

   subroutine set_text_size()
   !< The default font at 15 pixels, or at 19 with View > Larger text: every size in em follows it.
   call app%set_font('plex-sans', merge(19.0_real64, 15.0_real64, large_text)) ! from the next frame on
   endsubroutine set_text_size

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
   integer(int32)               :: u      !< Unit.

   call execute_command_line('mkdir -p "'//folder//'/plate" "'//folder//'/channel"', exitstat=stat)
   call execute_command_line('rm -f "'//folder//'"/*/field.dat', exitstat=stat)
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
   c = case_t()                                      ! the plate again, on a grid 18 times finer
   c%title = 'Heated plate, fine'
   c%nx = 900_int32
   c%ny = 600_int32
   c%omega = 1.95_real64
   c%tolerance = 1.0e-4_real64
   call execute_command_line('mkdir -p "'//folder//'/fine" "'//folder//'/broken"', exitstat=stat)
   open(newunit=u, file=folder//'/broken/'//INPUT_FILE, status='replace', action='write')
   write(u, '(A)') '&heat', "  title = 'A typo'", '  omgea = 1.8', '/'   ! omgea: a name the namelist has not
   close(u)
   call write_case(folder//'/fine/'//INPUT_FILE, c, stat)
   call execute_command_line('"'//solver_path//'" "'//folder//'/fine" > /dev/null', exitstat=stat) ! its result: 7 MB
   call execute_command_line('"'//solver_path//'" "'//folder//'/plate" > /dev/null', exitstat=stat) ! solved too
   call execute_command_line('touch -t 202610150910 "'//folder//'"/*/'//INPUT_FILE//' "'//folder//'"/*/', exitstat=stat)
   endsubroutine write_examples
endprogram tut20_tables
