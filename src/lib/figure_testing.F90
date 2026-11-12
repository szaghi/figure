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
use, intrinsic :: iso_c_binding, only : c_char, c_double, c_float, c_int, c_loc, c_long_long
use, intrinsic :: iso_fortran_env, only : int8, int32, int64, real64
use figure_base, only : figure_check, figure_fail, figure_last_error
use figure_c_native, only : FIG_OK, FIG_ERR_ARGUMENT, fig_input_key, fig_input_mouse_button, fig_input_mouse_pos, &
                            fig_input_next_frame, fig_input_quit, fig_input_system_theme, fig_input_text, &
                            fig_input_wheel, fig_window_rect, fig_plot_tick_label, fig_frame_hit, fig_frame_rect, &
                            fig_frame_state, fig_notification_rect, fig_notification_alpha, fig_drawn_extent, &
                            fig_file_browser_get, fig_file_browser_rect, fig_file_browser_settings, fig_input_drop, &
                            fig_popup_rect, fig_opened_url, fig_drawn_extent_layer, fig_field_uploads, &
                            fig_field_count, fig_field_time, fig_field_pixel, fig_test_glyph, fig_items_record, &
                            fig_item_find, fig_item_value, fig_items_list, fig_item_click, fig_item_type, &
                            fig_menu_click, fig_test_run, fig_test_capture, fig_image_write, fig_set_last_error
use figure_imgui, only : ig_item_rect
use figure_implot, only : plot_copies, plot_stride
use figure_texture, only : fig_read_image

implicit none
private
public :: test_mouse_move, test_mouse_button, test_click, test_drag, test_wheel, test_key, test_type
public :: test_window_rect, test_item_center, test_next_frame, test_quit, test_plot_tick, test_system_theme
public :: test_frame_hit, test_frame_rect, test_frame_state, test_notification_rect, test_drawn_extent
public :: test_file_browser, test_file_browser_rect, test_settings_file, test_drop
public :: test_popup_rect, test_opened_url, test_plot_copies, test_plot_stride
public :: test_field_uploads, test_field_textures, test_field_time, test_field_pixel, test_glyph
public :: test_record_items, test_item_exists, test_item_rect, test_item_click, test_item_type_text, test_item_checked
public :: test_item_value, test_menu_click, test_run, test_id_conflicts, test_unnamed_items
public :: test_capture, test_compare_image

! The state bits of an item found by a path: must match native/figure_items.h's state_t.
integer(c_int), parameter :: ITEM_CHECKABLE = 2_c_int  !< A checkbox, a menu item, a selectable in a menu.
integer(c_int), parameter :: ITEM_CHECKED   = 4_c_int  !< Checked.

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

   subroutine test_glyph(text, font, source, pixels, width, height, checksum, stat)
   !< One glyph of a text font at the current font size, as Dear ImGui draws it: `source`, the name of the font that
   !< gives it (`'IBM Plex Sans'`, `'IBM Plex Mono'`, `'Lucide'`, `'Noto Sans Math'`, a file's name; `''` when none
   !< has it and the missing-glyph box is drawn), the pixels of its bitmap that are not empty (0 for a space), its
   !< advance and height, and a checksum of its bitmap (equal for an equal bitmap). `font` is a name of `set_font`
   !< (`'plex-sans'`, `'plex-mono'`, `'proggy'`) or a file. In a frame; the glyph is rasterized if it was not yet.
   character(len=*),              intent(in)            :: text     !< One character, UTF-8.
   character(len=*),              intent(in)            :: font     !< Font name or file.
   character(len=:), allocatable, intent(out)           :: source   !< The font that gives it; '' when none.
   integer(int64),                intent(out)           :: pixels   !< Pixels of its bitmap that are not empty.
   real(real64),                  intent(out), optional :: width    !< Advance [pixels].
   real(real64),                  intent(out), optional :: height   !< Height of the bitmap [pixels].
   integer(int64),                intent(out), optional :: checksum !< Checksum of the bitmap.
   integer(int32),                intent(out), optional :: stat     !< Status: `FIG_ERR_STATE` with no frame open,
                                                                    !< `FIG_ERR_ARGUMENT` for not one character or
                                                                    !< not a font, `FIG_ERR_FAILED` for a file that
                                                                    !< cannot be read.
   character(kind=c_char, len=64)                       :: buf      !< Source name.
   integer(c_int)                                       :: n        !< Its length.
   integer(c_long_long)                                 :: px       !< Pixels.
   integer(c_long_long)                                 :: sum      !< Checksum.
   real(c_double)                                       :: w        !< Advance.
   real(c_double)                                       :: h        !< Height.

   n = 0_c_int
   px = 0_c_long_long
   sum = 0_c_long_long
   w = 0.0_c_double
   h = 0.0_c_double
   call figure_check(fig_test_glyph(text, len(text, c_int), font, len_trim(font, c_int), buf, len(buf, c_int), n, px, &
                                    w, h, sum), stat)
   source = buf(1:max(0_c_int, min(n, len(buf, c_int))))
   pixels = int(px, int64)
   if (present(width)) width = real(w, real64)
   if (present(height)) height = real(h, real64)
   if (present(checksum)) checksum = int(sum, int64)
   endsubroutine test_glyph

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

   subroutine test_record_items(on, stat)
   !< Record the items of each frame, for the procedures that find an item by its path, from the next frame on (or
   !< stop). On by default in every mode, from the first frame; called before `app%init*`, its choice holds from the
   !< first frame. Recording costs a little per item and frame (testing.md, "Finding items by path"); stopping it gives
   !< that back.
   logical,        intent(in)            :: on   !< Record.
   integer(int32), intent(out), optional :: stat !< Status.

   call figure_check(fig_items_record(merge(1_c_int, 0_c_int, on)), stat)
   endsubroutine test_record_items

   function test_item_exists(path, stat) result(exists)
   !< True when `path` names an item, or a window, in the last frame drawn (several items: true too). Paths:
   !< `Window/Label`, `//Window/Label` (the window by its full name), a label's `##id`, `*` for any one level, `$$n` for
   !< an integer id (testing.md, "Finding items by path"). Trailing blanks are not part of the path.
   character(len=*), intent(in)            :: path   !< Path.
   integer(int32),   intent(out), optional :: stat   !< Status: `FIG_ERR_ARGUMENT` for a malformed path.
   logical                                 :: exists !< It exists.
   integer(c_int)                          :: found  !< Found flag.
   integer(c_int)                          :: state  !< State bits.
   real(c_float)                           :: r(6)   !< Rectangle.
   character(len=:), allocatable           :: full   !< Its full path.
   integer(c_int)                          :: s      !< Native status.

   s = item_query(path, 0_c_int, found, r, state, full)
   call item_check(s, 'test_item_exists', stat)
   exists = s == FIG_OK .and. found >= 1_c_int ! 2: several
   endfunction test_item_exists

   function test_item_rect(path, x, y, w, h, stat) result(found)
   !< The rectangle of the item `path` names, as drawn in the last frame [pixels]: its top-left corner and its size
   !< (zero when not found). False when no item matches.
   character(len=*), intent(in)            :: path  !< Path.
   real(real64),     intent(out)           :: x     !< Left.
   real(real64),     intent(out)           :: y     !< Top.
   real(real64),     intent(out)           :: w     !< Width.
   real(real64),     intent(out)           :: h     !< Height.
   integer(int32),   intent(out), optional :: stat  !< Status: `FIG_ERR_ARGUMENT` for a malformed path or several
                                                    !< items.
   logical                                 :: found !< An item matches.
   integer(c_int)                          :: f     !< Found flag.
   integer(c_int)                          :: state !< State bits.
   real(c_float)                           :: r(6)  !< Rectangle.
   character(len=:), allocatable           :: full  !< Its full path.

   call item_check(item_query(path, 0_c_int, f, r, state, full), 'test_item_rect', stat)
   if (f == 2_c_int) call figure_fail(FIG_ERR_ARGUMENT, 'test_item_rect: '//figure_last_error(), stat) ! several
   found = f == 1_c_int
   if (.not. found) r = 0.0_c_float
   x = real(r(1), real64)
   y = real(r(2), real64)
   w = real(r(3) - r(1), real64)
   h = real(r(4) - r(2), real64)
   endfunction test_item_rect

   subroutine test_item_click(path, button, stat)
   !< Queue a click on the item `path` names in the last frame, at the centre of its visible part, as `test_click` does.
   character(len=*), intent(in)            :: path   !< Path.
   character(len=*), intent(in),  optional :: button !< `'left'` (default), `'right'` or `'middle'`.
   integer(int32),   intent(out), optional :: stat   !< Status: `FIG_ERR_ARGUMENT` for no item (the message names
                                                     !< the nearest match), several, a malformed path or an unknown
                                                     !< button; `FIG_ERR_STATE` for an item disabled or not visible.
   integer(c_int)                          :: b      !< Button.

   if (.not. button_index(button, b)) then
      call figure_fail(FIG_ERR_ARGUMENT, "test_item_click: button must be 'left', 'right' or 'middle'", stat)
      return
   endif
   call figure_check(fig_item_click(path, len_trim(path, c_int), b), stat)
   endsubroutine test_item_click

   subroutine test_item_type_text(path, text, stat)
   !< Queue typing `text` into the field `path` names: a click on it with the shortcut key held (a slider or a drag takes
   !< typed text then, a text field is focused), all its text selected, `text` typed, Enter.
   character(len=*), intent(in)            :: path !< Path.
   character(len=*), intent(in)            :: text !< Text (UTF-8).
   integer(int32),   intent(out), optional :: stat !< Status: as `test_item_click`'s, and `FIG_ERR_ARGUMENT` for an
                                                   !< item that takes no typed text.

   call figure_check(fig_item_type(path, len_trim(path, c_int), text, len(text, c_int)), stat)
   endsubroutine test_item_type_text

   function test_item_checked(path, stat) result(checked)
   !< True when the item `path` names was checked in the last frame: a checkbox, a menu item with a check mark, a
   !< selectable in a menu.
   character(len=*), intent(in)            :: path    !< Path.
   integer(int32),   intent(out), optional :: stat    !< Status: `FIG_ERR_ARGUMENT` for no item (the nearest match
                                                      !< named), several, a malformed path, an item not checkable.
   logical                                 :: checked !< Checked.
   integer(c_int)                          :: f       !< Found flag.
   integer(c_int)                          :: state   !< State bits.
   real(c_float)                           :: r(6)    !< Rectangle.
   character(len=:), allocatable           :: full    !< Its full path.
   integer(c_int)                          :: s       !< Native status.

   checked = .false.
   s = item_query(path, 1_c_int, f, r, state, full)
   call item_check(s, 'test_item_checked', stat)
   if (s /= FIG_OK) return
   if (iand(state, ITEM_CHECKABLE) == 0_c_int) then
      call figure_fail(FIG_ERR_ARGUMENT, "test_item_checked: '"//full//"' is not checkable", stat)
      return
   endif
   checked = iand(state, ITEM_CHECKED) /= 0_c_int
   endfunction test_item_checked

   function test_item_value(path, text, shown, stat) result(equal)
   !< True when the item `path` names showed `text` as its value in the last frame: the text drawn inside its rectangle,
   !< its label taken out (a field's text, a slider's number, a combo's choice), blanks collapsed. `shown` gives it.
   character(len=*),              intent(in)            :: path  !< Path.
   character(len=*),              intent(in)            :: text  !< The value expected (UTF-8).
   character(len=:), allocatable, intent(out), optional :: shown !< The value shown.
   integer(int32),                intent(out), optional :: stat  !< Status: `FIG_ERR_ARGUMENT` for no item (the
                                                                 !< nearest match named), several, a malformed path.
   logical                                              :: equal !< `text` is shown.
   character(kind=c_char, len=4096)                     :: buf   !< Text shown.
   integer(c_int)                                       :: n     !< Its length.
   integer(c_int)                                       :: e     !< Equal flag.

   n = 0_c_int
   e = 0_c_int
   call figure_check(fig_item_value(path, len_trim(path, c_int), text, len(text, c_int), e, buf, len(buf, c_int), n), &
                     stat)
   equal = e == 1_c_int
   if (present(shown)) shown = buf(1:max(0_c_int, min(n, len(buf, c_int))))
   endfunction test_item_value

   subroutine test_menu_click(path, stat)
   !< Queue a click through a menu path: `'File/Recent/notes.txt'` (or `'//Window/File/...'`) clicks the first menu now
   !< and each following level once its menu has appeared, over the next frames; a menu already open is pointed at,
   !< not clicked again. A level that does not appear within 20 frames ends the queued input: `test_run` reports it.
   character(len=*), intent(in)            :: path !< Path.
   integer(int32),   intent(out), optional :: stat !< Status: as `test_item_click`'s for the first menu.

   call figure_check(fig_menu_click(path, len_trim(path, c_int)), stat)
   endsubroutine test_menu_click

   function test_run(max_frames, stat) result(more)
   !< The frame driver of a test: true while the interface is not idle, so the program draws one more frame; false once
   !< no input is queued (nor in Dear ImGui's queue), no action waits and no frame is asked for (the frames an event
   !< gives, `app%request_frames`). Call it once per frame: `do while (test_run(60))`, a frame, `enddo`. After
   !< `max_frames` frames of one run: false, and a failure.
   integer(int32), intent(in)            :: max_frames !< Frames allowed.
   integer(int32), intent(out), optional :: stat       !< Status: `FIG_ERR_STATE` past `max_frames`, or for a queued
                                                       !< `test_menu_click` level that never appeared;
                                                       !< `FIG_ERR_ARGUMENT` for `max_frames` < 1.
   logical                               :: more       !< Draw one more frame.
   integer(c_int)                        :: m          !< More flag.

   m = 0_c_int
   call figure_check(fig_test_run(int(max_frames, c_int), m), stat)
   more = m == 1_c_int
   endfunction test_run

   function test_id_conflicts(list) result(count)
   !< How many ids were shared by items with different rectangles in the last frame (Dear ImGui reports an id conflict
   !< only under the mouse): `list`, their paths.
   character(len=:), allocatable, intent(out), optional :: list(:) !< Paths.
   integer(int32)                                       :: count   !< Conflicting ids.

   call items_list(1_c_int, count, list)
   endfunction test_id_conflicts

   function test_unnamed_items(list) result(count)
   !< How many interactive items had no name in the last frame: an empty visible label (`'##save'`) or icons only, and
   !< no tooltip (an icon-only button without `ig_tooltip`): `list`, their paths.
   character(len=:), allocatable, intent(out), optional :: list(:) !< Paths.
   integer(int32)                                       :: count   !< Unnamed items.

   call items_list(2_c_int, count, list)
   endfunction test_unnamed_items

   subroutine test_capture(path, stat)
   !< The whole frame as a PNG file `path`, written when the current frame is rendered (at the next `app%next_frame`):
   !< in headless and remote modes drawn by FIGURE's CPU renderer, the same pixels on every machine (capture.md); in a
   !< window, read back from the GPU. A file `path` of an earlier run is removed at once, so a capture that cannot be
   !< written (its reason on standard error) leaves no picture to compare. Then `test_compare_image(path, golden)`.
   character(len=*), intent(in)            :: path !< PNG file.
   integer(int32),   intent(out), optional :: stat !< Status: `FIG_ERR_STATE` with no frame open, `FIG_ERR_ARGUMENT`
                                                   !< for an empty name.

   call figure_check(fig_test_capture(path, len_trim(path, c_int)), stat)
   endsubroutine test_capture

   function test_compare_image(path, golden, threshold, max_failed, masks, failed, stat) result(equal)
   !< Whether the picture `path` (a `test_capture`, a `save_image`) matches the reference `golden`: the same size, and
   !< at most `max_failed` pixels (default 0) with a channel (R, G, B or A) that differs by more than `threshold`
   !< (default 2, on 0-255: what the CPU renderer may differ by across platforms, capture.md), the pixels whose
   !< centre lies in a rectangle of `masks` left out (a clock, an animation: what is not deterministic).
   !<
   !< On a mismatch it writes `<stem>.new.png` (the picture) and `<stem>.diff.png` beside the golden, `<stem>` the
   !< golden's name without `.png`: in the diff the pixels that fail are red, those that differ within `threshold`
   !< dark red, the masked ones blue and the others the golden's, faded; `figure_last_error` says how many failed, by
   !< how much at most and where. On a match it removes such files left by an earlier run. Pixels are counted from the
   !< picture's top-left corner, as `ig_item_rect` gives them (logical pixels are picture pixels at a content scale of
   !< 1, as headless mode's).
   character(len=*), intent(in)            :: path         !< The picture (PNG or JPEG).
   character(len=*), intent(in)            :: golden       !< The reference (PNG).
   integer(int32),   intent(in),  optional :: threshold    !< Largest difference of a channel that passes [0-255].
   integer(int32),   intent(in),  optional :: max_failed   !< Pixels allowed to fail.
   real(real64),     intent(in),  optional :: masks(:,:)   !< Rectangles left out, masks(:, k) = xmin, ymin, xmax,
                                                           !< ymax [pixels].
   integer(int64),   intent(out), optional :: failed       !< Pixels that failed (-1: the sizes differ).
   integer(int32),   intent(out), optional :: stat         !< Status: `FIG_ERR_FAILED` when a file cannot be read or
                                                           !< written, `FIG_ERR_ARGUMENT` for a file that is not an
                                                           !< image, a `threshold` outside 0-255, a negative
                                                           !< `max_failed`, `masks` not of 4 rows or a rectangle whose
                                                           !< maximum is below its minimum.
   logical                                 :: equal        !< The picture matches.
   integer(int8), allocatable              :: got(:,:,:)   !< The picture, rgba(4, width, height).
   integer(int8), allocatable              :: ref(:,:,:)   !< The golden.
   integer(int8), allocatable              :: diff(:,:,:)  !< The diff picture, RGB.
   integer(int8), allocatable              :: rgb(:,:,:)   !< The picture, RGB (.new.png).
   logical,       allocatable              :: masked(:,:)  !< Pixels left out.
   integer(int32)                          :: t            !< Threshold.
   integer(int32)                          :: m            !< Pixels allowed to fail.
   integer(int32)                          :: s            !< Status.
   integer(int32)                          :: i, j, k      !< Column, row, rectangle.
   integer(int32)                          :: d            !< A pixel's largest channel difference.
   integer(int32)                          :: worst        !< The largest difference of a failed pixel.
   integer(int32)                          :: at(2)        !< Where it is (column, row, from 0).
   integer(int32)                          :: lum          !< The golden's luminance at a pixel.
   integer(int64)                          :: n            !< Pixels that failed.
   logical                                 :: ok           !< Outcome.
   character(len=:), allocatable           :: stem         !< The golden's name without .png.
   character(len=:), allocatable           :: msg          !< Message.

   equal = .false.
   if (present(failed)) failed = 0_int64
   t = 2_int32
   if (present(threshold)) t = threshold
   m = 0_int32
   if (present(max_failed)) m = max_failed
   if (t < 0_int32 .or. t > 255_int32) then
      call figure_fail(FIG_ERR_ARGUMENT, 'test_compare_image: threshold '//itoa(t)//' is out of 0 to 255', stat)
      return
   endif
   if (m < 0_int32) then
      call figure_fail(FIG_ERR_ARGUMENT, 'test_compare_image: max_failed '//itoa(m)//' is negative', stat)
      return
   endif
   if (present(masks)) then
      if (size(masks, 1) /= 4) then
         call figure_fail(FIG_ERR_ARGUMENT, 'test_compare_image: masks must have 4 rows (xmin, ymin, xmax, ymax)', &
                          stat)
         return
      endif
      if (any(masks(3,:) < masks(1,:)) .or. any(masks(4,:) < masks(2,:))) then
         call figure_fail(FIG_ERR_ARGUMENT, 'test_compare_image: a mask whose maximum is below its minimum', stat)
         return
      endif
   endif
   call read_picture(path, got, s)
   if (s /= FIG_OK) then
      call figure_fail(s, figure_last_error(), stat)
      return
   endif
   call read_picture(golden, ref, s)
   if (s /= FIG_OK) then
      call figure_fail(s, figure_last_error(), stat)
      return
   endif
   stem = trim(golden)
   if (len(stem) > 4) then
      if (stem(len(stem) - 3:) == '.png') stem = stem(1:len(stem) - 4)
   endif
   rgb = got(1:3,:,:)
   if (any(shape(got) /= shape(ref))) then
      if (present(failed)) failed = -1_int64
      call write_picture(stem//'.new.png', rgb, s)
      if (s /= FIG_OK) then
         call figure_fail(s, figure_last_error(), stat)
         return
      endif
      call remove_file(stem//'.diff.png')
      msg = 'test_compare_image: '//trim(path)//' is '//itoa(size(got, 2, int32))//'x'//itoa(size(got, 3, int32))// &
            ' pixels, '//trim(golden)//' '//itoa(size(ref, 2, int32))//'x'//itoa(size(ref, 3, int32))//': see '// &
            stem//'.new.png'
      call fig_set_last_error(msg, len(msg, c_int))
      if (present(stat)) stat = int(FIG_OK, int32)
      return
   endif
   allocate(masked(size(got, 2), size(got, 3)))
   masked = .false.
   if (present(masks)) then
      do k = 1_int32, size(masks, 2, int32)
         do j = 1_int32, size(got, 3, int32)
            if (real(j, real64) - 0.5_real64 < masks(2, k) .or. real(j, real64) - 0.5_real64 > masks(4, k)) cycle
            do i = 1_int32, size(got, 2, int32)
               if (real(i, real64) - 0.5_real64 >= masks(1, k) .and. real(i, real64) - 0.5_real64 <= masks(3, k)) &
                  masked(i, j) = .true.
            enddo
         enddo
      enddo
   endif
   allocate(diff(3, size(got, 2), size(got, 3)))
   n = 0_int64
   worst = 0_int32
   at = 0_int32
   do j = 1_int32, size(got, 3, int32)
      do i = 1_int32, size(got, 2, int32)
         d = maxval(abs(ubyte(got(:, i, j)) - ubyte(ref(:, i, j))))
         lum = (ubyte(ref(1, i, j)) * 3_int32 + ubyte(ref(2, i, j)) * 6_int32 + ubyte(ref(3, i, j))) / 10_int32
         if (masked(i, j)) then
            diff(:, i, j) = sbyte([lum / 4_int32, lum / 4_int32, 96_int32 + lum / 3_int32])
         elseif (d > t) then
            n = n + 1_int64
            diff(:, i, j) = sbyte([255_int32, 0_int32, 0_int32])
            if (d > worst) then
               worst = d
               at = [i - 1_int32, j - 1_int32]
            endif
         elseif (d > 0_int32) then
            diff(:, i, j) = sbyte([140_int32, 30_int32, 30_int32])
         else
            diff(:, i, j) = sbyte([lum / 3_int32, lum / 3_int32, lum / 3_int32])
         endif
      enddo
   enddo
   if (present(failed)) failed = n
   ok = n <= int(m, int64)
   if (ok) then
      call remove_file(stem//'.new.png')
      call remove_file(stem//'.diff.png')
   else
      call write_picture(stem//'.new.png', rgb, s)
      if (s == FIG_OK) call write_picture(stem//'.diff.png', diff, s)
      if (s /= FIG_OK) then
         call figure_fail(s, figure_last_error(), stat)
         return
      endif
      msg = 'test_compare_image: '//ltoa(n)//' pixels of '//trim(path)//' differ from '//trim(golden)// &
            ' by more than '//itoa(t)//' ('//itoa(m)//' allowed), the most by '//itoa(worst)//' at ('// &
            itoa(at(1))//', '//itoa(at(2))//'): see '//stem//'.diff.png'
      call fig_set_last_error(msg, len(msg, c_int))
   endif
   if (present(stat)) stat = int(FIG_OK, int32)
   equal = ok
   endfunction test_compare_image

   subroutine read_picture(path, rgba, stat)
   !< fig_read_image for test_compare_image: its message under that name.
   character(len=*),           intent(in)  :: path        !< File.
   integer(int8), allocatable, intent(out) :: rgba(:,:,:) !< Pixels.
   integer(int32),             intent(out) :: stat        !< Status.
   character(len=:), allocatable           :: msg         !< Message.
   character(len=*), parameter             :: FROM = 'fig_read_image: ' !< The prefix replaced.

   call fig_read_image(trim(path), rgba, stat)
   if (stat == FIG_OK) return
   msg = figure_last_error()
   if (index(msg, FROM) == 1) msg = msg(len(FROM) + 1:)
   msg = 'test_compare_image: '//msg
   call fig_set_last_error(msg, len(msg, c_int))
   endsubroutine read_picture

   subroutine write_picture(path, pixels, stat)
   !< A PNG of pixels(channels, width, height), rows from the top (FIGURE's encoder).
   character(len=*), intent(in)                     :: path          !< File.
   integer(int8),    intent(in), target, contiguous :: pixels(:,:,:) !< Pixels.
   integer(int32),   intent(out)                    :: stat          !< Status.
   character(len=:), allocatable                    :: msg           !< Message.

   stat = int(fig_image_write(path, len(path, c_int), c_loc(pixels), int(size(pixels, 1), c_int), &
                              int(size(pixels, 2), c_int), int(size(pixels, 3), c_int), 0_c_int), int32)
   if (stat == FIG_OK) return
   msg = 'test_compare_image: '//figure_last_error()
   call fig_set_last_error(msg, len(msg, c_int))
   endsubroutine write_picture

   subroutine remove_file(path)
   !< Remove the file `path` if it exists.
   character(len=*), intent(in) :: path   !< File.
   logical                      :: exists !< It exists.
   integer(int32)               :: u      !< Unit.
   integer(int32)               :: ios    !< I/O status.

   inquire(file=path, exist=exists)
   if (.not. exists) return
   open(newunit=u, file=path, status='old', iostat=ios)
   if (ios == 0_int32) close(u, status='delete', iostat=ios)
   endsubroutine remove_file

   elemental function ubyte(b) result(v)
   !< The value 0-255 of a byte.
   integer(int8), intent(in) :: b !< Byte.
   integer(int32)            :: v !< Value.

   v = modulo(int(b, int32), 256_int32)
   endfunction ubyte

   elemental function sbyte(v) result(b)
   !< The byte of a value 0-255.
   integer(int32), intent(in) :: v !< Value.
   integer(int8)             :: b !< Byte.

   b = int(merge(v - 256_int32, v, v > 127_int32), int8)
   endfunction sbyte

   pure function itoa(i) result(text)
   !< An integer, written.
   integer(int32), intent(in)    :: i    !< Integer.
   character(len=:), allocatable :: text !< Its text.
   character(len=12)             :: buf  !< Buffer.

   write(buf, '(I0)') i
   text = trim(buf)
   endfunction itoa

   pure function ltoa(i) result(text)
   !< A 64-bit integer, written.
   integer(int64), intent(in)    :: i    !< Integer.
   character(len=:), allocatable :: text !< Its text.
   character(len=21)             :: buf  !< Buffer.

   write(buf, '(I0)') i
   text = trim(buf)
   endfunction ltoa

   function item_query(path, must, found, rect, state, full) result(status)
   !< fig_item_find of a path (trailing blanks dropped).
   character(len=*),              intent(in)  :: path    !< Path.
   integer(c_int),                intent(in)  :: must    !< 1: no item is a failure.
   integer(c_int),                intent(out) :: found   !< 1: found.
   real(c_float),                 intent(out) :: rect(6) !< Rectangle and the point to click.
   integer(c_int),                intent(out) :: state   !< State bits.
   character(len=:), allocatable, intent(out) :: full    !< Its full path.
   integer(c_int)                             :: status  !< Status.
   character(kind=c_char, len=1024)           :: buf     !< Full path.
   integer(c_int)                             :: n       !< Its length.

   found = 0_c_int
   state = 0_c_int
   rect = 0.0_c_float
   n = 0_c_int
   status = fig_item_find(path, len_trim(path, c_int), must, found, rect, state, buf, len(buf, c_int), n)
   full = buf(1:max(0_c_int, min(n, len(buf, c_int))))
   endfunction item_query

   subroutine item_check(status, who, stat)
   !< A failure of fig_item_find reported under the caller's name.
   integer(c_int),   intent(in)            :: status !< Native status.
   character(len=*), intent(in)            :: who    !< Caller.
   integer(int32),   intent(out), optional :: stat   !< Status.

   if (status == FIG_OK) then
      if (present(stat)) stat = int(FIG_OK, int32)
   else
      call figure_fail(status, who//': '//figure_last_error(), stat)
   endif
   endsubroutine item_check

   subroutine items_list(what, count, list)
   !< A list of fig_items_list, blank-padded to the longest.
   integer(c_int),                intent(in)            :: what    !< 1 conflicts, 2 unnamed.
   integer(int32),                intent(out)           :: count   !< How many.
   character(len=:), allocatable, intent(out), optional :: list(:) !< Paths.
   character(kind=c_char, len=1024)                     :: buf     !< A path.
   integer(c_int)                                       :: n       !< Its length.
   integer(c_int)                                       :: c       !< Count.
   integer(c_int)                                       :: i       !< Counter.
   integer(c_int)                                       :: longest !< Longest path.

   c = 0_c_int
   n = 0_c_int
   call figure_check(fig_items_list(what, 0_c_int, buf, len(buf, c_int), n, c))
   count = int(c, int32)
   if (.not. present(list)) return
   longest = 0_c_int
   do i = 1_c_int, c
      call figure_check(fig_items_list(what, i, buf, len(buf, c_int), n, c))
      longest = max(longest, min(n, len(buf, c_int)))
   enddo
   allocate(character(len=longest) :: list(c))
   do i = 1_c_int, c
      call figure_check(fig_items_list(what, i, buf, len(buf, c_int), n, c))
      list(i) = buf(1:max(0_c_int, min(n, len(buf, c_int))))
   enddo
   endsubroutine items_list

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
