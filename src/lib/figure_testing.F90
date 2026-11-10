!< figure_testing, synthetic input for testing interfaces without a display (or with one).
module figure_testing
!< figure_testing, synthetic input for testing interfaces without a display (or with one).
!<
!< Input is queued and applied while the program draws its next frames, as real input would be: a test queues a
!< click, draws a few frames (`app%next_frame()` and the program's own UI code), then checks the program's variables.
!< Everything queued reaches Dear ImGui at the next frame, up to a frame boundary (`test_next_frame`); Dear ImGui
!< then applies one change of each kind per frame (input trickling), so a move, a press and a release queued at once
!< become a click over the next frames.
!<
!<```fortran
!< call test_click(x, y)           ! the centre of the button, e.g. from ig_item_rect in an earlier frame
!< do frame = 1, 4
!<    if (.not. app%next_frame()) exit
!<    call draw_panel(panel)       ! the UI under test
!< enddo
!< ! now check what the click did to the program's variables
!<```
!<
!< Coordinates are display pixels, as `ig_item_rect` and `test_window_rect` give them. Works in every mode; with
!< `app%init_headless` no window, display or GPU is needed, so tests run in CI as is.
use, intrinsic :: iso_c_binding, only : c_char, c_float, c_int, c_long_long
use, intrinsic :: iso_fortran_env, only : int32, int64, real64
use figure_base, only : figure_check, figure_fail
use figure_c_native, only : FIG_ERR_ARGUMENT, fig_input_key, fig_input_mouse_button, fig_input_mouse_pos, &
                            fig_input_next_frame, fig_input_quit, fig_input_system_theme, fig_input_text, &
                            fig_input_wheel, fig_window_rect, fig_plot_tick_label, fig_frame_hit, fig_frame_rect, &
                            fig_frame_state, fig_notification_rect, fig_notification_alpha, fig_drawn_extent, &
                            fig_file_browser_get, fig_file_browser_rect, fig_file_browser_settings, fig_input_drop, &
                            fig_popup_rect, fig_opened_url, fig_drawn_extent_layer, fig_field_uploads, &
                            fig_field_count, fig_field_time, fig_field_pixel
use figure_imgui, only : ig_item_rect
use figure_implot, only : plot_copies, plot_stride

implicit none
private
public :: test_mouse_move, test_mouse_button, test_click, test_drag, test_wheel, test_key, test_type
public :: test_window_rect, test_item_center, test_next_frame, test_quit, test_plot_tick, test_system_theme
public :: test_frame_hit, test_frame_rect, test_frame_state, test_notification_rect, test_drawn_extent
public :: test_file_browser, test_file_browser_rect, test_settings_file, test_drop
public :: test_popup_rect, test_opened_url, test_plot_copies, test_plot_stride
public :: test_field_uploads, test_field_textures, test_field_time, test_field_pixel

interface test_drawn_extent
   !< The extent [pixels] of what was drawn so far in the current window in a colour: Dear ImGui's style colour by its
   !< name, or an RGBA colour (an item's `ip_spec` colour).
   module procedure test_drawn_extent_name, test_drawn_extent_rgba
endinterface test_drawn_extent

contains
   subroutine test_next_frame(stat)
   !< A frame boundary in the queued input: what is queued after it reaches Dear ImGui one frame later than what is
   !< queued before it. For sequences that must not share a frame (a drag: press, move, release).
   integer(int32), intent(out), optional :: stat !< Status.

   call figure_check(fig_input_next_frame(), stat)
   endsubroutine test_next_frame

   subroutine test_plot_tick(axis, index, label, count, stat)
   !< The label of tick `index` (from 1) on `axis` of the plot being declared, and the number of ticks: call it between
   !< `ip_begin_plot` and `ip_end_plot`, after the setup (`ip_setup_axes`, `ip_setup_axis`) and an item (it ends the
   !< setup). `axis` is `'x1'`, `'x2'`, `'x3'`, `'y1'`, `'y2'` or `'y3'` (`'x'` and `'y'`: x1 and y1). `label` is ''
   !< for an index out of range.
   character(len=*),              intent(in)            :: axis   !< `'x1'`..`'x3'`, `'y1'`..`'y3'`, `'x'`, `'y'`.
   integer(int32),                intent(in)            :: index  !< Tick, from 1.
   character(len=:), allocatable, intent(out)           :: label  !< Its label.
   integer(int32),                intent(out), optional :: count  !< Ticks on the axis.
   integer(int32),                intent(out), optional :: stat   !< Status: `FIG_ERR_STATE` outside a plot or for an
                                                                  !< axis not set up, `FIG_ERR_ARGUMENT` for an
                                                                  !< unknown axis.
   character(kind=c_char, len=128)                      :: buf    !< Label buffer.
   integer(c_int)                                       :: n      !< Ticks.
   integer(c_int)                                       :: l      !< Label length.
   integer(c_int)                                       :: a      !< Axis code (ImAxis).

   label = ''
   select case (trim(axis))
   case ('x', 'x1')
      a = 0_c_int
   case ('x2')
      a = 1_c_int
   case ('x3')
      a = 2_c_int
   case ('y', 'y1')
      a = 3_c_int
   case ('y2')
      a = 4_c_int
   case ('y3')
      a = 5_c_int
   case default
      a = -1_c_int
   endselect
   n = 0_c_int
   l = 0_c_int
   call figure_check(fig_plot_tick_label(a, int(index, c_int), buf, len(buf, c_int), n, l), stat)
   if (present(count)) count = int(n, int32)
   if (l > 0_c_int) label = buf(1:min(l, len(buf, c_int)))
   endsubroutine test_plot_tick

   subroutine test_quit(stat)
   !< A quit request, as the window's close button makes it: `next_frame` returns `.false.`, or, after
   !< `app%set_confirm_quit(.true.)`, `app%quit_requested()` returns `.true.`.
   integer(int32), intent(out), optional :: stat !< Status: `FIG_ERR_STATE` before `init*`.

   call figure_check(fig_input_quit(), stat)
   endsubroutine test_quit

   subroutine test_system_theme(theme, stat)
   !< The system's light or dark setting changes, as SDL's theme-changed event reports it, at the next frame:
   !< `palette='auto'` (`app%set_style`) is chosen again. `theme` is `'light'`, `'dark'`, or `'system'` (the real
   !< setting again, read from SDL in window mode; unknown, so dark, in headless and remote modes). Works in every mode.
   character(len=*), intent(in)            :: theme !< `'light'`, `'dark'` or `'system'`.
   integer(int32),   intent(out), optional :: stat  !< Status: `FIG_ERR_ARGUMENT` for another value, `FIG_ERR_STATE`
                                                    !< before `init*`.

   select case (theme)
   case ('system')
      call figure_check(fig_input_system_theme(0_c_int), stat)
   case ('light')
      call figure_check(fig_input_system_theme(1_c_int), stat)
   case ('dark')
      call figure_check(fig_input_system_theme(2_c_int), stat)
   case default
      call figure_fail(FIG_ERR_ARGUMENT, "test_system_theme: theme is 'light', 'dark' or 'system'", stat)
   endselect
   endsubroutine test_system_theme

   function test_frame_hit(x, y) result(hit)
   !< What the window's frame (`decorations='figure'`) does with the point (x, y), as its hit test answers the system,
   !< from the last frame drawn: `'client'` (the program's: the buttons, the menus, everything below the bar),
   !< `'drag'` (the bar's empty space, the icon, the title), or a resize edge or corner, `'resize-top-left'`,
   !< `'resize-top'`, `'resize-top-right'`, `'resize-right'`, `'resize-bottom-right'`, `'resize-bottom'`,
   !< `'resize-bottom-left'`, `'resize-left'` (none when maximized). `'client'` everywhere without the frame.
   real(real64), intent(in)      :: x   !< Abscissa [pixels].
   real(real64), intent(in)      :: y   !< Ordinate [pixels].
   character(len=:), allocatable :: hit !< Class.
   character(len=19), parameter  :: NAMES(0:9) = [character(len=19) :: 'client', 'drag', 'resize-top-left', &
      'resize-top', 'resize-top-right', 'resize-right', 'resize-bottom-right', 'resize-bottom', 'resize-bottom-left', &
      'resize-left'] !< Class names, by SDL_HitTestResult.
   integer(c_int)                :: h   !< Native class.

   call figure_check(fig_frame_hit(real(x, c_float), real(y, c_float), h))
   hit = trim(NAMES(max(0_c_int, min(9_c_int, h))))
   endfunction test_frame_hit

   subroutine test_frame_rect(part, x0, y0, x1, y1, found, stat)
   !< A part of the title bar of `decorations='figure'` in the last frame: `'bar'`, `'icon'`, `'menus'` (the program's
   !< main menu bar inside it), `'title'`, `'minimize'`, `'maximize'`, `'close'`; `found` is false when not drawn.
   character(len=*), intent(in)            :: part  !< Part.
   real(real64),     intent(out)           :: x0    !< Left [pixels].
   real(real64),     intent(out)           :: y0    !< Top [pixels].
   real(real64),     intent(out)           :: x1    !< Right [pixels].
   real(real64),     intent(out)           :: y1    !< Bottom [pixels].
   logical,          intent(out), optional :: found !< Drawn in the last frame.
   integer(int32),   intent(out), optional :: stat  !< Status: `FIG_ERR_ARGUMENT` for an unknown part.
   real(c_float)                           :: r(4)  !< Rectangle.
   integer(c_int)                          :: f     !< Found.
   integer(c_int)                          :: p     !< Part code.

   r = 0.0_c_float
   f = 0_c_int
   select case (part)
   case ('bar')
      p = 0_c_int
   case ('icon')
      p = 1_c_int
   case ('menus')
      p = 2_c_int
   case ('title')
      p = 3_c_int
   case ('minimize')
      p = 4_c_int
   case ('maximize')
      p = 5_c_int
   case ('close')
      p = 6_c_int
   case default
      p = -1_c_int
   endselect
   call figure_check(fig_frame_rect(p, r, f), stat)
   x0 = real(r(1), real64)
   y0 = real(r(2), real64)
   x1 = real(r(3), real64)
   y1 = real(r(4), real64)
   if (present(found)) found = f /= 0_c_int
   endsubroutine test_frame_rect

   subroutine test_frame_state(minimized, maximized, stat)
   !< The window minimized, maximized: the system's in window mode; in headless mode, as the buttons of
   !< `decorations='figure'` recorded them.
   logical,        intent(out)           :: minimized !< Minimized.
   logical,        intent(out)           :: maximized !< Maximized.
   integer(int32), intent(out), optional :: stat      !< Status: `FIG_ERR_STATE` before `init*`.
   integer(c_int)                        :: mn        !< Minimized flag.
   integer(c_int)                        :: mx        !< Maximized flag.

   mn = 0_c_int
   mx = 0_c_int
   call figure_check(fig_frame_state(mn, mx), stat)
   minimized = mn /= 0_c_int
   maximized = mx /= 0_c_int
   endsubroutine test_frame_state

   subroutine test_notification_rect(index, xmin, ymin, xmax, ymax, found, alpha)
   !< The rectangle [pixels] of a notification shown in the last frame (`app%notify`): `index` 1 is the newest, at the
   !< bottom, 2 the one above it, ...; `found` is false past the last shown. `alpha`: the largest alpha of the
   !< vertices it was drawn with (the draw data), in [0, 1]: 1 while it is shown in full, falling to 0 as it fades
   !< out in the last half second of its time; 0 past the last shown.
   integer(int32), intent(in)            :: index !< 1: the newest shown.
   real(real64),   intent(out)           :: xmin  !< Left.
   real(real64),   intent(out)           :: ymin  !< Top.
   real(real64),   intent(out)           :: xmax  !< Right.
   real(real64),   intent(out)           :: ymax  !< Bottom.
   logical,        intent(out), optional :: found !< It was shown.
   real(real64),   intent(out), optional :: alpha !< Largest alpha drawn, in [0, 1].
   real(c_float)                         :: r(4)  !< Native rectangle.
   real(c_float)                         :: a     !< Native alpha.
   integer(c_int)                        :: f     !< Found flag.

   r = 0.0_c_float
   if (fig_notification_rect(int(index, c_int), r, f) /= 0_c_int) f = 0_c_int
   if (present(alpha)) then
      a = 0.0_c_float
      if (fig_notification_alpha(int(index, c_int), a) /= 0_c_int) a = 0.0_c_float
      alpha = real(a, real64)
   endif
   xmin = real(r(1), real64)
   ymin = real(r(2), real64)
   xmax = real(r(3), real64)
   ymax = real(r(4), real64)
   if (present(found)) found = f == 1_c_int
   endsubroutine test_notification_rect

   subroutine test_drawn_extent_name(color, xmin, ymin, xmax, ymax, found, stat)
   !< The extent [pixels] of what was drawn so far in the current window in Dear ImGui's style colour `color`, by
   !< its name (`'PlotHistogram'`: the fill of a progress bar): call it inside the window, after the widget.
   character(len=*), intent(in)            :: color !< Dear ImGui's colour name.
   real(real64),     intent(out)           :: xmin  !< Left.
   real(real64),     intent(out)           :: ymin  !< Top.
   real(real64),     intent(out)           :: xmax  !< Right.
   real(real64),     intent(out)           :: ymax  !< Bottom.
   logical,          intent(out), optional :: found !< Something was drawn in it.
   integer(int32),   intent(out), optional :: stat  !< Status: `FIG_ERR_ARGUMENT` for an unknown colour,
                                                    !< `FIG_ERR_STATE` outside a window.
   real(c_float)                           :: r(4)  !< Native rectangle.
   integer(c_int)                          :: f     !< Found flag.

   r = 0.0_c_float
   f = 0_c_int
   call figure_check(fig_drawn_extent(color, len(color, c_int), r, f), stat)
   xmin = real(r(1), real64)
   ymin = real(r(2), real64)
   xmax = real(r(3), real64)
   ymax = real(r(4), real64)
   if (present(found)) found = f == 1_c_int
   endsubroutine test_drawn_extent_name

   subroutine test_drawn_extent_rgba(color, xmin, ymin, xmax, ymax, found, stat, layer, vertices)
   !< The extent [pixels] of what was drawn so far in the current window in the RGBA colour `color` (as an item drawn
   !< with `ip_spec(line_color=color)`): call it inside the window, after the item (after `ip_end_plot` for what a plot
   !< draws at its end: annotations). Antialiased edges are drawn in other colours: the extent is that of the lines' cores.
   !< With `layer` `'foreground'` or `'background'`, what was drawn so far on that layer of the window's viewport (the
   !< `ig_draw_*` primitives' layers; `'window'`, the default, and `'plot'` are the window's own draw list).
   !< `vertices`: how many vertices have the colour (a filled shape has fewer than its outline: one per corner).
   real(real64),   intent(in)            :: color(4) !< Colour, RGBA in [0, 1].
   real(real64),   intent(out)           :: xmin     !< Left.
   real(real64),   intent(out)           :: ymin     !< Top.
   real(real64),   intent(out)           :: xmax     !< Right.
   real(real64),   intent(out)           :: ymax     !< Bottom.
   logical,        intent(out), optional :: found    !< Something was drawn in it.
   integer(int32), intent(out), optional :: stat     !< Status: `FIG_ERR_STATE` outside a window.
   character(len=*), intent(in), optional :: layer   !< `'window'` (default), `'plot'`, `'foreground'`, `'background'`.
   integer(int32), intent(out), optional :: vertices !< Vertices drawn in the colour.
   integer(c_int)                        :: nv       !< Native count.
   real(c_float)                         :: r(4)     !< Native rectangle.
   integer(c_int)                        :: f        !< Found flag.
   integer(c_int)                        :: l        !< Layer code.

   r = 0.0_c_float
   f = 0_c_int
   l = 1_c_int
   if (present(layer)) then
      if (layer == 'foreground') l = 2_c_int
      if (layer == 'background') l = 3_c_int
   endif
   call figure_check(fig_drawn_extent_layer(real(color, c_float), l, r, f, nv), stat)
   if (present(vertices)) vertices = int(nv, int32)
   xmin = real(r(1), real64)
   ymin = real(r(2), real64)
   xmax = real(r(3), real64)
   ymax = real(r(4), real64)
   if (present(found)) found = f == 1_c_int
   endsubroutine test_drawn_extent_rgba

   subroutine test_file_browser(shown, folder, entries, error, asking, path_field, name_field, recent)
   !< The file browser in front (`app%open_file_browser`, `app%save_file_browser`), as it stands after the last frame:
   !< `shown` false without one (then the texts are '' and the lists empty, but `recent`). `folder`: the folder listed
   !< (absolute); `entries`: the entries shown, in the order shown, folders ending in `/` (blank-padded to the longest);
   !< `error`: the error shown ('' none); `asking`: a save over an existing file is being asked; `path_field`,
   !< `name_field`: the texts of the path and name fields; `recent`: the recent folders, newest first (also without a
   !< browser). Texts are UTF-8.
   logical,                       intent(out)           :: shown      !< A browser is open.
   character(len=:), allocatable, intent(out), optional :: folder     !< Folder listed.
   character(len=:), allocatable, intent(out), optional :: entries(:) !< Entries shown.
   character(len=:), allocatable, intent(out), optional :: error      !< Error shown.
   logical,                       intent(out), optional :: asking     !< Replacing a file is asked.
   character(len=:), allocatable, intent(out), optional :: path_field !< Path field.
   character(len=:), allocatable, intent(out), optional :: name_field !< Name field.
   character(len=:), allocatable, intent(out), optional :: recent(:)  !< Recent folders.
   character(len=:), allocatable                        :: text       !< A text.
   integer(c_int)                                       :: n          !< Count.

   text = browser_text(0_c_int, 1_c_int, n)
   shown = n > 0_c_int
   if (present(folder)) folder = text
   if (present(entries)) call browser_list(1_c_int, entries)
   if (present(error)) error = browser_text(2_c_int, 1_c_int, n)
   if (present(asking)) asking = browser_text(3_c_int, 1_c_int, n) == '1'
   if (present(path_field)) path_field = browser_text(4_c_int, 1_c_int, n)
   if (present(name_field)) name_field = browser_text(6_c_int, 1_c_int, n)
   if (present(recent)) call browser_list(5_c_int, recent)
   endsubroutine test_file_browser

   subroutine test_file_browser_rect(part, xmin, ymin, xmax, ymax, found)
   !< The rectangle [pixels] of a part of the file browser in front, as drawn in the last frame: `'entry:NAME'` (an
   !< entry's row, by its name; rows out of view are not drawn), `'parent'`, `'refresh'`, `'path'`, `'new folder'`,
   !< `'new folder name'`, `'create'`, `'sort:name'`, `'sort:size'`, `'sort:modified'` (the columns' headers),
   !< `'place:home'`, `'place:cwd'`, `'place:root:N'`, `'place:recent:N'`, `'name'`, `'filter'` and, while its list is
   !< open, `'filter:N'`, `'hidden'`, `'cancel'`, `'ok'` (Open, Save or Choose), and, while a replace is asked,
   !< `'replace'` and `'keep'`. `found` is false for a part not drawn.
   character(len=*), intent(in)            :: part  !< Part.
   real(real64),     intent(out)           :: xmin  !< Left.
   real(real64),     intent(out)           :: ymin  !< Top.
   real(real64),     intent(out)           :: xmax  !< Right.
   real(real64),     intent(out)           :: ymax  !< Bottom.
   logical,          intent(out), optional :: found !< It was drawn.
   real(c_float)                           :: r(4)  !< Native rectangle.
   integer(c_int)                          :: f     !< Found flag.

   r = 0.0_c_float
   if (fig_file_browser_rect(part, len(part, c_int), r, f) /= 0_c_int) f = 0_c_int
   xmin = real(r(1), real64)
   ymin = real(r(2), real64)
   xmax = real(r(3), real64)
   ymax = real(r(4), real64)
   if (present(found)) found = f == 1_c_int
   endsubroutine test_file_browser_rect

   subroutine test_settings_file(path, stat)
   !< The settings file that keeps the file browser's recent folders, instead of FIGURE's own, until the program ends:
   !< read when a browser opens, written when one is answered. `''`: none, the recent folders are kept in memory only
   !< (the default in headless mode). Before or after `init*`.
   character(len=*), intent(in)            :: path !< File.
   integer(int32),   intent(out), optional :: stat !< Status.

   call figure_check(fig_file_browser_settings(path, len(path, c_int)), stat)
   endsubroutine test_settings_file

   function browser_text(what, index, count) result(text)
   !< A text of the browser in front (fig_file_browser_get).
   integer(c_int), intent(in)       :: what  !< Query.
   integer(c_int), intent(in)       :: index !< Index, from 1.
   integer(c_int), intent(out)      :: count !< The list's length (0: no browser).
   character(len=:), allocatable    :: text  !< Text.
   character(kind=c_char, len=4096) :: buf   !< Buffer.
   integer(c_int)                   :: l     !< Length.

   text = ''
   if (fig_file_browser_get(what, index, buf, len(buf, c_int), l, count) /= 0_c_int) count = 0_c_int
   if (l > 0_c_int) text = buf(1:min(l, len(buf, c_int)))
   endfunction browser_text

   subroutine browser_list(what, list)
   !< A list of the browser in front (fig_file_browser_get), blank-padded to the longest.
   integer(c_int),                intent(in)  :: what    !< Query.
   character(len=:), allocatable, intent(out) :: list(:) !< Texts.
   character(len=:), allocatable              :: text    !< A text.
   integer(c_int)                             :: n, i, longest, m !< Counts.

   text = browser_text(what, 1_c_int, n)
   longest = 0_c_int
   do i = 1_c_int, n
      text = browser_text(what, i, m)
      longest = max(longest, len(text, c_int))
   enddo
   allocate(character(len=longest) :: list(n))
   do i = 1_c_int, n
      list(i) = browser_text(what, i, m)
   enddo
   endsubroutine browser_list

   subroutine test_mouse_move(x, y, stat)
   !< Queue a move of the mouse to (x, y).
   real(real64),   intent(in)            :: x    !< Abscissa [pixels].
   real(real64),   intent(in)            :: y    !< Ordinate [pixels].
   integer(int32), intent(out), optional :: stat !< Status: `FIG_ERR_STATE` before `init*`.

   call figure_check(fig_input_mouse_pos(real(x, c_float), real(y, c_float)), stat)
   endsubroutine test_mouse_move

   subroutine test_mouse_button(down, button, stat)
   !< Queue a press (`down=.true.`) or a release of a mouse button.
   logical,          intent(in)            :: down   !< Pressed.
   character(len=*), intent(in),  optional :: button !< `'left'` (default), `'right'` or `'middle'`.
   integer(int32),   intent(out), optional :: stat   !< Status: `FIG_ERR_ARGUMENT` for an unknown button.
   integer(c_int)                          :: b      !< Button.

   if (.not. button_index(button, b)) then
      call figure_fail(FIG_ERR_ARGUMENT, "test_mouse_button: button must be 'left', 'right' or 'middle'", stat)
      return
   endif
   call figure_check(fig_input_mouse_button(b, merge(1_c_int, 0_c_int, down)), stat)
   endsubroutine test_mouse_button

   subroutine test_click(x, y, button, stat)
   !< Queue a click at (x, y): a move, a frame with the pointer resting there (as a user's hand does: Dear ImGui's
   !< tabs take a press only once hovered), a press and a release, applied over the next four frames.
   real(real64),     intent(in)            :: x      !< Abscissa [pixels].
   real(real64),     intent(in)            :: y      !< Ordinate [pixels].
   character(len=*), intent(in),  optional :: button !< `'left'` (default), `'right'` or `'middle'`.
   integer(int32),   intent(out), optional :: stat   !< Status.
   integer(c_int)                          :: b      !< Button.

   if (.not. button_index(button, b)) then
      call figure_fail(FIG_ERR_ARGUMENT, "test_click: button must be 'left', 'right' or 'middle'", stat)
      return
   endif
   call figure_check(fig_input_mouse_pos(real(x, c_float), real(y, c_float)), stat)
   call figure_check(fig_input_next_frame(), stat) ! the pointer rests one frame on the item: items that may overlap
   call figure_check(fig_input_next_frame(), stat) ! (tabs) take a press only once hovered in the frame before
   call figure_check(fig_input_mouse_button(b, 1_c_int), stat)
   call figure_check(fig_input_mouse_button(b, 0_c_int), stat)
   endsubroutine test_click

   subroutine test_drag(x0, y0, x1, y1, stat)
   !< Queue a drag with the left button from (x0, y0) to (x1, y1): a slider grab moved, a window dragged by its title.
   real(real64),   intent(in)            :: x0   !< Start abscissa [pixels].
   real(real64),   intent(in)            :: y0   !< Start ordinate [pixels].
   real(real64),   intent(in)            :: x1   !< End abscissa [pixels].
   real(real64),   intent(in)            :: y1   !< End ordinate [pixels].
   integer(int32), intent(out), optional :: stat !< Status.

   call figure_check(fig_input_mouse_pos(real(x0, c_float), real(y0, c_float)), stat)
   call figure_check(fig_input_next_frame(), stat) ! the pointer rests one frame on the item before the press, as in
   call figure_check(fig_input_next_frame(), stat) ! test_click
   call figure_check(fig_input_mouse_button(0_c_int, 1_c_int), stat)
   call figure_check(fig_input_next_frame(), stat) ! the press is seen at the start before the mouse moves
   call figure_check(fig_input_mouse_pos(real(x1, c_float), real(y1, c_float)), stat)
   call figure_check(fig_input_next_frame(), stat) ! the move is seen with the button still down
   call figure_check(fig_input_mouse_button(0_c_int, 0_c_int), stat)
   endsubroutine test_drag

   subroutine test_wheel(dy, dx, stat)
   !< Queue a turn of the wheel: `dy` positive away from the user (zoom in, in a plot), `dx` horizontal.
   real(real64),   intent(in)            :: dy   !< Vertical steps.
   real(real64),   intent(in),  optional :: dx   !< Horizontal steps (default 0).
   integer(int32), intent(out), optional :: stat !< Status.
   real(c_float)                         :: h    !< Horizontal.

   h = 0.0_c_float
   if (present(dx)) h = real(dx, c_float)
   call figure_check(fig_input_wheel(h, real(dy, c_float)), stat)
   endsubroutine test_wheel

   subroutine test_key(name, down, stat)
   !< Queue a key: pressed and released, or only pressed (`down=.true.`) or released (`down=.false.`). Names: `a`-`z`,
   !< `0`-`9`, `enter`, `tab`, `backspace`, `delete`, `escape`, `space`, `left`, `right`, `up`, `down`, `home`, `end`,
   !< `pageup`, `pagedown`, `f1`-`f12`, and the modifiers `ctrl`, `shift`, `alt`, `super` (hold one with `down`).
   !< `shortcut` is the platform's shortcut key, the one `ig_shortcut('ctrl+...')` and select-all mean: cmd on macOS,
   !< ctrl elsewhere (`ctrl` itself is the physical ctrl key, which macOS does not use for shortcuts).
   character(len=*), intent(in)            :: name !< Key name.
   logical,          intent(in),  optional :: down !< Only press (true) or only release (false).
   integer(int32),   intent(out), optional :: stat !< Status: `FIG_ERR_ARGUMENT` for an unknown name.

   if (present(down)) then
      call figure_check(fig_input_key(name, len(name, c_int), merge(1_c_int, 0_c_int, down)), stat)
   else
      call figure_check(fig_input_key(name, len(name, c_int), 1_c_int), stat)
      call figure_check(fig_input_key(name, len(name, c_int), 0_c_int), stat)
   endif
   endsubroutine test_key

   subroutine test_type(text, stat)
   !< Queue typed characters (UTF-8), into the focused input field.
   character(len=*), intent(in)            :: text !< Characters.
   integer(int32),   intent(out), optional :: stat !< Status.

   call figure_check(fig_input_text(text, len(text, c_int)), stat)
   endsubroutine test_type

   subroutine test_drop(paths, x, y, stat)
   !< Queue a drop of `paths` (each trimmed of trailing blanks) at (x, y), as dropping files from a file manager makes
   !< it: `app%dropped` reports them together on the next frame, and only on that one. Works in every mode.
   character(len=*), intent(in)            :: paths(:) !< Files or folders.
   real(real64),     intent(in)            :: x        !< Abscissa [pixels].
   real(real64),     intent(in)            :: y        !< Ordinate [pixels].
   integer(int32),   intent(out), optional :: stat     !< Status: `FIG_ERR_ARGUMENT` for no path or an empty one,
                                                       !< `FIG_ERR_STATE` before `init*`.
   integer(int32)                          :: k        !< Counter.

   if (size(paths) == 0) then
      call figure_fail(FIG_ERR_ARGUMENT, 'test_drop: no path to drop', stat)
      return
   endif
   do k = 1_int32, size(paths, kind=int32)
      call figure_check(fig_input_drop(paths(k), len_trim(paths(k), c_int), real(x, c_float), real(y, c_float)), stat)
      if (present(stat)) then
         if (stat /= 0_int32) return
      endif
   enddo
   endsubroutine test_drop

   subroutine test_window_rect(name, xmin, ymin, xmax, ymax, found, stat)
   !< The rectangle of the window `name` (as passed to `ig_begin`) as drawn in the last frame [pixels].
   character(len=*), intent(in)            :: name  !< Window name.
   real(real64),     intent(out)           :: xmin  !< Left.
   real(real64),     intent(out)           :: ymin  !< Top.
   real(real64),     intent(out)           :: xmax  !< Right.
   real(real64),     intent(out)           :: ymax  !< Bottom.
   logical,          intent(out), optional :: found !< The window exists (else the rectangle is zero).
   integer(int32),   intent(out), optional :: stat  !< Status.
   real(c_float)                           :: r(4)  !< Rectangle.
   integer(c_int)                          :: f     !< 1: found.

   r = 0.0_c_float
   f = 0_c_int
   call figure_check(fig_window_rect(name, len(name, c_int), r, f), stat)
   if (f /= 1_c_int) r = 0.0_c_float
   xmin = real(r(1), real64)
   ymin = real(r(2), real64)
   xmax = real(r(3), real64)
   ymax = real(r(4), real64)
   if (present(found)) found = f == 1_c_int
   endsubroutine test_window_rect

   subroutine test_popup_rect(xmin, ymin, xmax, ymax, found, stat)
   !< The rectangle of the innermost open popup (a menu, a combo's list, `ig_color_edit`'s picker) as drawn in the last
   !< frame [pixels]; zero, with `found` false, when no popup is open.
   real(real64),   intent(out)           :: xmin  !< Left.
   real(real64),   intent(out)           :: ymin  !< Top.
   real(real64),   intent(out)           :: xmax  !< Right.
   real(real64),   intent(out)           :: ymax  !< Bottom.
   logical,        intent(out), optional :: found !< A popup is open.
   integer(int32), intent(out), optional :: stat  !< Status: `FIG_ERR_STATE` before `init*`.
   real(c_float)                         :: r(4)  !< Rectangle.
   integer(c_int)                        :: f     !< 1: found.

   r = 0.0_c_float
   f = 0_c_int
   call figure_check(fig_popup_rect(r, f), stat)
   if (f /= 1_c_int) r = 0.0_c_float
   xmin = real(r(1), real64)
   ymin = real(r(2), real64)
   xmax = real(r(3), real64)
   ymax = real(r(4), real64)
   if (present(found)) found = f == 1_c_int
   endsubroutine test_popup_rect

   function test_opened_url() result(url)
   !< The URL the last click on a link (`ig_text_link_url`) asked to open, in any mode: headless mode opens nothing, so
   !< a test reads here what a window would have opened; `''` before any such click (and after each `init*`).
   character(len=:), allocatable :: url   !< The URL.
   integer(c_long_long)          :: n     !< Its length [bytes].
   character(len=1)              :: probe !< A buffer for the length alone.

   n = fig_opened_url(probe, 0_c_long_long)
   allocate(character(len=n) :: url)
   if (n > 0_c_long_long) n = fig_opened_url(url, n)
   endfunction test_opened_url

   function test_plot_copies() result(copies)
   !< How many arrays the plot items copied since the program started, because ImPlot could not read them in place: an
   !< array whose stride differs from the ordinates' (or is negative), and integer abscissae (converted). A test reads
   !< it before and after an item to check that the item read its data in place (plots.md, "Data in place").
   integer(int64) :: copies !< Arrays copied.

   copies = plot_copies
   endfunction test_plot_copies

   function test_plot_stride() result(bytes)
   !< The byte stride the last plot item (`ip_line`, `ip_scatter`, `ip_bars`, `ip_shaded`, `ip_error_bars`) gave ImPlot
   !< for its arrays: the element size for contiguous data, larger for data read in place from a strided section; 0
   !< before any item. What the item received depends on the compiler: some copy a strided actual argument into a
   !< contiguous temporary before the call (plots.md, "Data in place").
   integer(int64) :: bytes !< Stride [bytes].

   bytes = plot_stride
   endfunction test_plot_stride

   function test_field_uploads() result(uploads)
   !< How many times `ip_field_image` coloured a field and uploaded it since the program started: a test reads it
   !< before and after frames to check that a field is not coloured again when nothing changed (plots.md, "Fields").
   integer(int64) :: uploads !< Colourings uploaded.

   uploads = int(fig_field_uploads(), int64)
   endfunction test_field_uploads

   function test_field_textures() result(count)
   !< How many field textures `ip_field_image` keeps: one per field drawn in the last 10 s (plots.md, "Fields").
   integer(int32) :: count !< Textures kept.

   count = int(fig_field_count(), int32)
   endfunction test_field_textures

   function test_field_time() result(ms)
   !< The time the last colouring of `ip_field_image` took, range, colours and upload [ms] (plots.md, "Fields").
   real(real64) :: ms !< Time [ms].

   ms = real(fig_field_time(), real64)
   endfunction test_field_time

   subroutine test_field_pixel(label, i, j, rgba, stat)
   !< The colour `ip_field_image` gave the value (i, j) of the field `label` in its last colouring, RGBA in [0, 1] (in
   !< steps of 1/255). Status `FIG_ERR_ARGUMENT` for a label not drawn in the last 10 s or (i, j) outside the field.
   character(len=*), intent(in)            :: label   !< The field's label.
   integer(int32),   intent(in)            :: i       !< Index along x.
   integer(int32),   intent(in)            :: j       !< Index along y.
   real(real64),     intent(out)           :: rgba(4) !< Colour, RGBA in [0, 1].
   integer(int32),   intent(out), optional :: stat    !< Status.
   real(c_float)                           :: c(4)    !< C copy.

   c = 0.0_c_float
   call figure_check(fig_field_pixel(label, len(label, c_int), int(i, c_int), int(j, c_int), c), stat)
   rgba = real(c, real64)
   endsubroutine test_field_pixel

   subroutine test_item_center(x, y)
   !< The centre of the last item drawn (call it right after the widget): where `test_click` should aim.
   real(real64), intent(out) :: x    !< Abscissa [pixels].
   real(real64), intent(out) :: y    !< Ordinate [pixels].
   real(real64)              :: x0   !< Left.
   real(real64)              :: y0   !< Top.
   real(real64)              :: x1   !< Right.
   real(real64)              :: y1   !< Bottom.

   call ig_item_rect(x0, y0, x1, y1)
   x = 0.5_real64 * (x0 + x1)
   y = 0.5_real64 * (y0 + y1)
   endsubroutine test_item_center

   function button_index(button, b) result(ok)
   !< ImGuiMouseButton of a name (absent: left).
   character(len=*), intent(in), optional :: button !< Button name.
   integer(c_int),   intent(out)          :: b      !< Index.
   logical                                :: ok     !< Known name.

   b = 0_c_int
   ok = .true.
   if (.not. present(button)) return
   select case (trim(button))
   case ('left')
      b = 0_c_int
   case ('right')
      b = 1_c_int
   case ('middle')
      b = 2_c_int
   case default
      ok = .false.
   endselect
   endfunction button_index
endmodule figure_testing
