!< figure_app, the application: window, frame loop and lazy redraw.
module figure_app
!< figure_app, the application: window, frame loop and lazy redraw.
!<
!< The whole life of a FIGURE program is one loop:
!<
!<```fortran
!< call app%init('My tool', 1280, 720)
!< do while (app%next_frame())
!<    ! declare the UI: widgets return what happened this frame
!< enddo
!< call app%destroy()
!<```
!<
!< `next_frame` renders the previous frame, then waits for input and opens the next one (lazy redraw: once the UI
!< settles it sleeps until input or `max_wait`, so an idle window costs a fraction of a percent of one core); it
!< returns `.false.` when the user closes the window. There are no widget objects, handles or callbacks: the state is
!< the application's own variables.
use, intrinsic :: iso_c_binding, only : c_char, c_double, c_float, c_int, c_loc
use, intrinsic :: ieee_exceptions, only : ieee_all, ieee_get_flag, ieee_set_flag
use, intrinsic :: iso_fortran_env, only : int8, int32, int64, output_unit, real32, real64
use figure_base, only : figure_check, figure_draw_refused, figure_fail, figure_last_error, figure_refused
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK, fig_begin_frame, fig_content_scale, fig_end_frame, fig_init, &
                            fig_init_headless, fig_init_remote, fig_load_style, fig_request_frames, fig_save_style,   &
                            fig_set_docking, fig_set_font, fig_set_ini_file, fig_set_lazy, fig_set_remote_compress,       &
                            fig_add_fallback_font,                                                                      &
                            fig_set_remote_lossy,                                                                       &
                            fig_set_remote_fps, fig_set_remote_token, fig_remote_token, &
                            fig_shutdown, fig_set_confirm_quit, fig_quit_requested, fig_quit, fig_app_wake, &
                            fig_file_dialog, fig_file_dialog_result, fig_set_title, fig_title, fig_save_image, &
                            fig_image_result, fig_save_layout, fig_load_layout, fig_set_style_parts, fig_palette_color, &
                            fig_frame_options, fig_set_icon_rgba, fig_set_icon_glyph, fig_notify,              &
                            fig_notification_count, fig_notification_get, fig_file_browser, fig_dropped, &
                            fig_dropped_path, fig_set_checks, fig_scope_report, fig_window_add, fig_window_visible, &
                            fig_window_set_visible, fig_view_menu, fig_layout_add, fig_layout_switch, fig_layout_reset, &
                            fig_layout_current, fig_prefs_open, fig_prefs_file, fig_pref_set, fig_pref_get,         &
                            fig_message_box, fig_set_size_limits
use figure_icons, only : ICON_CIRCLE_CHECK, ICON_CIRCLE_X, ICON_INFO, ICON_TRIANGLE_ALERT

implicit none
private
public :: app_object

type :: app_object
   !< A FIGURE application (one per program).
   !<
   !< The native layer owns the lifecycle state (initialized, frame open) and rejects out-of-order calls with
   !< `FIG_ERR_STATE`; only `in_frame` is mirrored here, because `next_frame` must know whether to close a frame.
   logical, private :: in_frame = .false. !< A frame is open.
   contains
      procedure, pass(self) :: init           !< Open the window.
      procedure, pass(self) :: init_headless  !< Contexts only, no window (tests).
      procedure, pass(self) :: init_remote    !< The UI in a web browser (no window, display or GPU).
      procedure, pass(self) :: next_frame     !< Close the current frame, open the next; false on quit.
      procedure, pass(self) :: set_checks     !< What a usage error does: 'abort', 'report' (default), 'recover'.
      procedure, pass(self) :: set_lazy       !< Lazy redraw on/off, longest sleep.
      procedure, pass(self) :: set_style      !< The style: a name, or a look and a palette.
      procedure, pass(self) :: palette_color  !< The colour of a palette role in effect.
      procedure, pass(self) :: set_docking    !< Docking on (the default) or off.
      procedure, pass(self) :: set_font       !< The default font and its size.
      procedure, pass(self) :: add_fallback_font !< A font for the glyphs the text fonts lack.
      procedure, pass(self) :: load_style     !< A theme file.
      procedure, pass(self) :: save_style     !< The style in effect, as a theme file.
      procedure, pass(self) :: request_frames !< Redraw without waiting for input.
      procedure, pass(self) :: wake           !< Start the next frame at once (from any thread).
      procedure, pass(self) :: set_confirm_quit !< Report a quit request instead of quitting.
      procedure, pass(self) :: quit_requested !< The user asked to quit (once per request).
      procedure, pass(self) :: dropped        !< The files and folders dropped on the window this frame.
      procedure, pass(self) :: quit           !< End the loop at the next frame.
      procedure, pass(self) :: set_title      !< The window's title, after init.
      procedure, pass(self) :: title          !< The window's title.
      procedure, pass(self) :: open_file_dialog   !< The system's dialog to choose a file to open.
      procedure, pass(self) :: save_file_dialog   !< The system's dialog to choose where to save.
      procedure, pass(self) :: open_folder_dialog !< The system's dialog to choose a folder.
      procedure, pass(self) :: open_file_browser  !< FIGURE's browser to choose a file (or a folder) to open.
      procedure, pass(self) :: save_file_browser  !< FIGURE's browser to choose where to save.
      procedure, pass(self) :: file_dialog_result !< The answer to a dialog or a browser, once given.
      procedure, pass(self) :: save_image     !< A rectangle of the window as a PNG file, after this frame.
      procedure, pass(self) :: image_result   !< The outcome of save_image, once.
      procedure, pass(self) :: save_layout    !< The arrangement of the windows (docking included) to a file.
      procedure, pass(self) :: load_layout    !< An arrangement from a file, applied before the next frame.
      procedure, pass(self) :: notify         !< Tell the user something, in a notification.
      procedure, pass(self) :: notifications  !< The notifications kept (the last 100).
      procedure, pass(self) :: add_window     !< Register a window: the View menu, its close button, kept hidden.
      procedure, pass(self) :: window_visible !< A registered window is shown.
      procedure, pass(self) :: set_window_visible !< Show or hide a registered window.
      procedure, pass(self) :: view_menu      !< The View menu: the windows, the layouts, Reset layout.
      procedure, pass(self) :: add_layout     !< Declare a named layout.
      procedure, pass(self) :: switch_layout  !< Make a layout current: laid out again, or as the user left it.
      procedure, pass(self) :: reset_layout   !< Lay the current layout out again.
      procedure, pass(self) :: layout         !< The current layout's name: the one to build.
      procedure, pass(self) :: open_prefs     !< Read the preferences from the program's file, kept there from now on.
      procedure, pass(self) :: prefs_file     !< The preferences' file.
      procedure, pass(self), private :: save_pref_text, save_pref_int32, save_pref_int64, save_pref_real32, &
                                        save_pref_real64, save_pref_logical
      generic :: save_pref => save_pref_text, save_pref_int32, save_pref_int64 !< Keep a preference.
      generic :: save_pref => save_pref_real32, save_pref_real64, save_pref_logical !< Keep a preference.
      procedure, pass(self), private :: load_pref_text, load_pref_int32, load_pref_int64, load_pref_real32, &
                                        load_pref_real64, load_pref_logical
      generic :: load_pref => load_pref_text, load_pref_int32, load_pref_int64 !< A preference kept, or a default.
      generic :: load_pref => load_pref_real32, load_pref_real64, load_pref_logical !< A preference kept, or a default.
      procedure, pass(self) :: message_box    !< A question in a box: 0 while open, then the button chosen.
      procedure, pass(self) :: set_size_limits !< The window's least and greatest size.
      procedure, pass(self) :: content_scale  !< Display content scale.
      procedure, pass(self) :: destroy        !< Close everything.
      procedure, pass(self), private :: set_icon_image !< The window's icon from an image.
      procedure, pass(self), private :: set_icon_glyph !< The window's icon from an ICON_*.
      generic :: set_icon => set_icon_image, set_icon_glyph !< The window's icon: an image or an ICON_*.
endtype app_object

contains
   recursive subroutine init(self, title, width, height, vsync, stat, ini_file, decorations, buttons)
   !< Open the window (`width` x `height` logical pixels) and create the ImGui/ImPlot contexts.
   !<
   !< Window positions and sizes are not saved by default: with `ini_file`, Dear ImGui keeps them in that file, read
   !< at the first frame and written while the program runs (its `imgui.ini`); not while `FIGURE_CAPTURE` records.
   !<
   !< `decorations='figure'` opens the window without the system's frame and draws one: a title bar with the icon
   !< (`set_icon`), the program's main menu bar (`ig_begin_main_menu_bar`) inside it, the title centred, and the
   !< minimize, maximize (restore) and close buttons, in the colours of the palette's roles. The bar drags the window,
   !< its edges resize it, a double-click on it maximizes; close takes the quit path of the system's close button
   !< (`set_confirm_quit`). `buttons` puts them on the `'right'` (the default) or the `'left'` (the default on macOS).
   class(app_object), intent(inout)         :: self        !< Application.
   character(len=*),  intent(in)            :: title       !< Window title.
   integer(int32),    intent(in)            :: width       !< Width [logical pixels].
   integer(int32),    intent(in)            :: height      !< Height [logical pixels].
   logical,           intent(in),  optional :: vsync       !< Synchronize with the display (default true).
   integer(int32),    intent(out), optional :: stat        !< Status: `FIG_ERR_FAILED` without a display or OpenGL 3,
                                                           !< `FIG_ERR_ARGUMENT` for a wrong size or option.
   character(len=*),  intent(in),  optional :: ini_file    !< File keeping the window layout (default: none).
   character(len=*),  intent(in),  optional :: decorations !< The window's frame: `'native'` (default) or `'figure'`.
   character(len=*),  intent(in),  optional :: buttons     !< With `'figure'`: `'right'` or `'left'` (default: the
                                                           !< platform's side, left on macOS).
   integer(c_int)                           :: status      !< Native status.
   integer(c_int)                           :: v           !< vsync flag.

   if (figure_refused('app%init', stat)) return ! a task does not draw
   status = frame_options(decorations, buttons)
   if (status /= FIG_OK) then
      call figure_check(status, stat)
      return
   endif
   v = 1_c_int
   if (present(vsync)) v = merge(1_c_int, 0_c_int, vsync)
   status = fig_init(title, len(title, c_int), int(width, c_int), int(height, c_int), v)
   if (status == FIG_OK .and. present(ini_file)) status = fig_set_ini_file(ini_file, len(ini_file, c_int))
   call figure_check(status, stat)
   endsubroutine init

   recursive subroutine init_headless(self, width, height, stat, decorations, buttons)
   !< Create the contexts on a virtual `width` x `height` display, without window or GPU.
   !<
   !< `decorations='figure'` draws the title bar of `init`'s `decorations='figure'` as in a window, for tests: its
   !< buttons' actions are recorded as state (`test_frame_state`), close takes the quit path.
   class(app_object), intent(inout)         :: self        !< Application.
   integer(int32),    intent(in)            :: width       !< Width [pixels].
   integer(int32),    intent(in)            :: height      !< Height [pixels].
   integer(int32),    intent(out), optional :: stat        !< Status: `FIG_ERR_ARGUMENT` for a wrong size or option.
   character(len=*),  intent(in),  optional :: decorations !< `'native'` (default: no bar) or `'figure'`.
   character(len=*),  intent(in),  optional :: buttons     !< With `'figure'`: `'right'` or `'left'`.
   integer(c_int)                           :: status      !< Native status.

   if (figure_refused('app%init_headless', stat)) return ! a task does not draw
   status = frame_options(decorations, buttons)
   if (status == FIG_OK) status = fig_init_headless(int(width, c_int), int(height, c_int))
   call figure_check(status, stat)
   endsubroutine init_headless

   function frame_options(decorations, buttons) result(status)
   !< Give the frame options to the native layer, before init: `FIG_ERR_ARGUMENT` for an unknown value.
   character(len=*), intent(in), optional :: decorations !< `'native'` or `'figure'`.
   character(len=*), intent(in), optional :: buttons     !< `'right'` or `'left'`.
   integer(c_int)                         :: status      !< Native status.
   integer(c_int)                         :: d           !< Decorations code.
   integer(c_int)                         :: b           !< Buttons code.

   d = 0_c_int
   b = 0_c_int
   if (present(decorations)) then
      select case (decorations)
      case ('native')
         d = 0_c_int
      case ('figure')
         d = 1_c_int
      case default
         d = -1_c_int
      endselect
   endif
   if (present(buttons)) then
      select case (buttons)
      case ('right')
         b = 1_c_int
      case ('left')
         b = 2_c_int
      case default
         b = -1_c_int
      endselect
   endif
   status = fig_frame_options(d, b)
   endfunction frame_options

   recursive subroutine set_icon_image(self, image, stat)
   !< The window's icon (task bar, dock, the title bar of `decorations='figure'`) from an image, `image(4, width,
   !< height)`: `image(:, i, j)` = R, G, B, A of pixel (i, j), j = 1 the top row. Window mode only; 1 to 1024 pixels a
   !< side (64 x 64 or 256 x 256 are usual).
   class(app_object), intent(inout)                     :: self        !< Application.
   integer(int8),     intent(in), contiguous, target    :: image(:,:,:) !< Pixels.
   integer(int32),    intent(out), optional             :: stat        !< Status: `FIG_ERR_STATE` in headless and remote
                                                                       !< modes, `FIG_ERR_ARGUMENT` for a wrong shape,
                                                                       !< `FIG_ERR_FAILED` where the system has no
                                                                       !< window icons (the title bar's is set).

   if (figure_refused('app%set_icon', stat)) return ! a task does not draw
   if (size(image, 1) /= 4) then
      call figure_fail(FIG_ERR_ARGUMENT, 'set_icon: the image is rgba(4, width, height)', stat)
      return
   endif
   call figure_check(fig_set_icon_rgba(c_loc(image), int(size(image, 2), c_int), int(size(image, 3), c_int)), stat)
   endsubroutine set_icon_image

   recursive subroutine set_icon_glyph(self, icon, stat)
   !< The window's icon from one of the bundled icons, `ICON_*`: rendered at 64 x 64 pixels in the palette's text on
   !< accent colour on a rounded square of its accent; the title bar of `decorations='figure'` shows the glyph in the
   !< accent colour. Window mode only.
   class(app_object), intent(inout)         :: self !< Application.
   character(len=*),  intent(in)            :: icon !< One `ICON_*` constant.
   integer(int32),    intent(out), optional :: stat !< Status: `FIG_ERR_STATE` in headless and remote modes,
                                                    !< `FIG_ERR_ARGUMENT` if `icon` is not one icon, `FIG_ERR_FAILED`
                                                    !< where the system has no window icons (the title bar's is set).

   if (figure_refused('app%set_icon', stat)) return ! a task does not draw
   call figure_check(fig_set_icon_glyph(icon, len(icon, c_int)), stat)
   endsubroutine set_icon_glyph

   recursive subroutine init_remote(self, port, host, width, height, port_used, quiet, max_fps, compress, lossy, token, url, stat)
   !< Create the contexts and serve the UI to a web browser on `http://host:port/` instead of opening a window: the
   !< program needs no display or GPU (a cluster node will do). One browser at a time, which can come and go while the
   !< program runs. The page and its connection need an access token in the address (`http://localhost:8080/?token=...`,
   !< printed at start, returned in `url`): 32 random hex digits, or `token` (`token=''` disables it: anyone who reaches
   !< the port then controls the program). Keep the default host (127.0.0.1) and reach a remote machine through an SSH
   !< tunnel (`ssh -L 8080:localhost:8080 node`).
   !<
   !< A browser has no vsync to pace the program, so frames are capped at `max_fps` per second (default 60), and a
   !< frame is sent only once the previous one has left: with a slow client the newest frame goes, the ones in between
   !< are skipped. A frame equal to the last one sent is not sent again. Vertices travel in 12 bytes instead of 20, and
   !< `compress` deflates frames and textures: `'auto'` (default) while the client is the bottleneck (frames are being
   !< skipped), `'always'`, or `'never'`; deflate costs about 7 ms of CPU per MB and shrinks frames 2.5 to 3.5 times.
   !< With `lossy` (default true) an image updated in consecutive frames (a 3-D view while the camera moves) travels as
   !< JPEG at quality 75 while it changes, 30 to 190 times smaller than raw, and exact once it has not changed for
   !< 150 ms; `lossy=.false.` always sends exact pixels. Images with transparent pixels always go exact.
   class(app_object), intent(inout)         :: self      !< Application.
   integer(int32),    intent(in),  optional :: port      !< Port (default 8080; 0: any free port).
   character(len=*),  intent(in),  optional :: host      !< Address to listen on (default 127.0.0.1).
   integer(int32),    intent(in),  optional :: width     !< Display width until the browser's [pixels] (default 1280).
   integer(int32),    intent(in),  optional :: height    !< Display height until the browser's [pixels] (default 800).
   integer(int32),    intent(out), optional :: port_used !< The port listened on (useful with port 0).
   logical,           intent(in),  optional :: quiet     !< Do not print the address to open (default false).
   real(real64),      intent(in),  optional :: max_fps   !< Most frames per second (default 60; 0: no cap).
   character(len=*),  intent(in),  optional :: compress  !< Deflate frames and textures: 'auto', 'always', 'never'.
   logical,           intent(in),  optional :: lossy     !< Changing images as JPEG, exact when still (default true).
   character(len=*),  intent(in),  optional :: token     !< Access token (default: random; '': none).
   character(len=*),  intent(out), optional :: url       !< The address to open, with the token (blank-padded).
   integer(int32),    intent(out), optional :: stat      !< Status.
   integer(c_int)                           :: p         !< Requested port.
   integer(c_int)                           :: bound     !< Port listened on.
   integer(c_int)                           :: w         !< Display width.
   integer(c_int)                           :: h         !< Display height.
   integer(c_int)                           :: status    !< Native status.
   logical                                  :: talk      !< Print the address.
   integer(c_int)                           :: zmode     !< Compression: 0 auto, 1 always, 2 never.
   character(len=256)                       :: tok       !< The token in effect (at most 256 characters).
   character(len=8)                         :: port_text !< The port, as text.
   integer(c_int)                           :: ntok      !< Its length.
   character(len=:), allocatable            :: address   !< The address to open.

   if (present(port_used)) port_used = 0_int32
   if (present(url)) url = ''
   if (figure_refused('app%init_remote', stat)) return ! a task does not draw
   if (present(token)) then
      if (len(token) > len(tok) .or. verify(token, &
          'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~') /= 0) then ! safe in an address as it is
         call figure_fail(FIG_ERR_ARGUMENT, 'init_remote: token is at most 256 letters, digits or -._~', stat)
         return
      endif
   endif
   address = ''
   zmode = 0_c_int
   if (present(compress)) then ! checked before anything starts
      select case (compress)
      case ('auto')
         zmode = 0_c_int
      case ('always')
         zmode = 1_c_int
      case ('never')
         zmode = 2_c_int
      case default
         call figure_fail(FIG_ERR_ARGUMENT, "init_remote: compress is 'auto', 'always' or 'never'", stat)
         return
      endselect
   endif
   p = 8080_c_int
   if (present(port)) p = int(port, c_int)
   w = 1280_c_int
   if (present(width)) w = int(width, c_int)
   h = 800_c_int
   if (present(height)) h = int(height, c_int)
   if (present(host)) then
      status = fig_init_remote(w, h, host, len(host, c_int), p, bound)
   else
      status = fig_init_remote(w, h, '', 0_c_int, p, bound)
   endif
   if (present(port_used)) port_used = int(bound, int32)
   if (status == FIG_OK) then
      if (present(max_fps)) then
         call fig_set_remote_fps(real(max_fps, c_double))
      else
         call fig_set_remote_fps(60.0_c_double)
      endif
      call fig_set_remote_compress(zmode)
      call fig_set_remote_lossy(1_c_int)
      if (present(lossy)) call fig_set_remote_lossy(merge(1_c_int, 0_c_int, lossy))
      if (present(token)) call fig_set_remote_token(token, len(token, c_int))
      ntok = fig_remote_token(tok, len(tok, c_int))
      if (present(host)) then
         address = 'http://'//trim(host)
      else
         address = 'http://localhost'
      endif
      write(port_text, '(I0)') bound
      address = address//':'//trim(port_text)//'/'
      if (ntok > 0_c_int) address = address//'?token='//tok(1:ntok)
      if (present(url)) url = address
   endif
   talk = .true.
   if (present(quiet)) talk = .not. quiet
   if (status == FIG_OK .and. talk) then
      write(output_unit, '(A)') 'FIGURE: open '//address//' in a web browser'
      flush(output_unit)
   endif
   call figure_check(status, stat)
   endsubroutine init_remote

   recursive function next_frame(self, stat) result(running)
   !< Render the open frame (if any), then process input and open the next; `.false.` when the user quits. The usage
   !< errors of the frame just ended (a wrong end, a scope left open, a drawing call with no frame open: `set_checks`)
   !< are reported here: `FIG_ERR_STATE` with every message, one per line, in `figure_last_error`; the scopes left
   !< open have been closed and the next frame is open, so the loop can go on. In mode 'recover' they are shown in a
   !< notification instead and the status is `FIG_OK`. See errors.md, "Pairing and frames".
   class(app_object), intent(inout)        :: self    !< Application.
   integer(int32),    intent(out), optional :: stat   !< Status.
   logical                                 :: running !< Keep looping.
   integer(c_int)                          :: status  !< Native status.
   integer(c_int)                          :: r       !< Running flag.
   integer(c_int)                          :: show    !< 1: notify the usage errors ('recover').

   running = .false.
   if (figure_refused('app%next_frame', stat)) return ! a task does not draw
   running = .false.
   if (self%in_frame) then
      self%in_frame = .false.
      status = fig_end_frame()
      if (status /= FIG_OK) then
         call figure_check(status, stat)
         return
      endif
   endif
   status = fig_begin_frame(r)
   running = status == FIG_OK .and. r /= 0_c_int
   self%in_frame = running
   if (status == FIG_OK) then
      status = fig_scope_report(show) ! the usage errors of the frame ended (and of calls between frames)
      if (show == 1_c_int) call self%notify(figure_last_error(), 'error', 10.0_real64)
   endif
   call figure_check(status, stat)
   endfunction next_frame

   recursive subroutine set_checks(self, mode, stat)
   !< What a usage error does: a wrong end (one that does not close the innermost open scope, or follows a begin that
   !< returned false where the rule is "end only after a true begin"), a scope left open at the end of the frame, a
   !< drawing procedure called with no frame open. FIGURE keeps a record of the scopes open in the frame (every
   !< begin/end and push/pop pair it wraps) and checks each end against it before Dear ImGui sees it; the messages
   !< name the Fortran calls (`ig_end_table: the open scope is ig_tree_node('Blocks') (close it with ig_tree_pop
   !< before ig_end_table)`). `mode`:
   !<
   !< - `'abort'`: the program stops (`error stop`, the message on standard error) at the call that breaks the rule,
   !<   or at `next_frame` for a scope left open; calls outside FIGURE (raw bindings) meet Dear ImGui's own assertions;
   !< - `'report'` (the default): the wrong call is refused (it does nothing), the frame goes on, the scopes left open
   !<   are closed, and the next `next_frame` returns `FIG_ERR_STATE` with every message (without its `stat`: `error
   !<   stop`, as any failure);
   !< - `'recover'`: as `'report'`, but an end whose scope is open further down first closes the scopes opened after
   !<   it, and `next_frame` shows the messages in a notification (`figure_last_error` has them) and returns `FIG_OK`.
   !<
   !< A call with a `stat` of its own (`ig_pop_style_color(stat=s)`) gets its usage error there, in every mode.
   !< Callable before `init*`; `destroy` restores the default. Statuses: `FIG_ERR_ARGUMENT` for another mode,
   !< `FIG_ERR_STATE` from a task. The same in every mode (window, headless, remote).
   class(app_object), intent(inout)         :: self !< Application.
   character(len=*),  intent(in)            :: mode !< 'abort', 'report' or 'recover'.
   integer(int32),    intent(out), optional :: stat !< Status.
   integer(c_int)                           :: m    !< Mode code.

   if (figure_refused('app%set_checks', stat)) return ! the loop's thread only
   select case (mode)
   case ('abort')
      m = 0_c_int
   case ('report')
      m = 1_c_int
   case ('recover')
      m = 2_c_int
   case default
      call figure_fail(FIG_ERR_ARGUMENT, "app%set_checks: mode is 'abort', 'report' or 'recover', not '"//mode//"'", stat)
      return
   endselect
   call figure_check(fig_set_checks(m), stat)
   endsubroutine set_checks

   recursive subroutine set_lazy(self, enabled, max_wait)
   !< Lazy redraw (default on): once the UI settles, sleep until input or `max_wait` seconds (default 0.5). Callable
   !< from any thread (a task included).
   class(app_object), intent(inout)      :: self     !< Application.
   logical,           intent(in)         :: enabled  !< Lazy redraw on.
   real(real64),      intent(in), optional :: max_wait !< Longest sleep [s]: the refresh period of live data.
   real(c_double)                        :: w        !< Longest sleep [s].

   w = 0.5_c_double
   if (present(max_wait)) w = real(max_wait, c_double)
   call fig_set_lazy(merge(1_c_int, 0_c_int, enabled), w)
   endsubroutine set_lazy

   recursive subroutine set_style(self, name, lines, stat, look, palette, auto_dark, auto_light)
   !< The style of the interface, the plots and the window's background, after `init*`: by name, or by its two parts,
   !< a look (the geometry) and a palette (the colours). Changing one part keeps the other.
   !<
   !< Names (each a theme file, `themes/<name>.toml`, embedded):
   !<
   !< - `'seal'` (the default), `'seal-light'`: FIGURE's, from its mark: ink (or paper) and one vermilion, spent on
   !<   what the user touches and on the first plotted line; square corners;
   !< - `'paper'`: for publication, black on white, thin borders, line colours that survive greyscale printing;
   !< - `'high-contrast'`: white on black with yellow accents, text at 7:1 or more (WCAG AAA);
   !< - `'dark'`, `'light'`, `'classic'`: Dear ImGui's own styles, with ImPlot's default line colours.
   !<
   !< Looks: `'seal'`, `'fusion'`, `'adwaita'`, `'fluent'`. Palettes: `'seal'`, `'seal-light'`, `'paper'`,
   !< `'high-contrast'`, `'nord'`, `'solarized-dark'`, `'solarized-light'`, `'gruvbox-dark'`, `'gruvbox-light'`,
   !< `'dracula'`, `'catppuccin-mocha'`, `'catppuccin-latte'`, `'tokyo-night'`, `'one-dark'`, and `'auto'`, which
   !< follows the system's light or dark setting (`auto_dark`, default `'seal'`; `auto_light`, default `'seal-light'`)
   !< and changes with it while the program runs; in headless and remote modes the setting is unknown and counts as
   !< dark. A palette's colours are derived from twelve roles and checked for contrast (docs, Styles, Palettes).
   !<
   !< The parts are applied in order, all or none: `name`, then `look`, then `palette`, then `lines` (`'okabe-ito'`
   !< replaces the line colours with Okabe and Ito's colour-blind-safe set). The environment variable `FIGURE_STYLE`
   !< picks the style at initialisation; this call overrides it. The font and its size are kept; colours and variables
   !< changed by name are reset by the part that sets them.
   class(app_object), intent(inout)         :: self       !< Application.
   character(len=*),  intent(in),  optional :: name       !< Style name.
   character(len=*),  intent(in),  optional :: lines      !< Line palette: `'okabe-ito'` (default: the style's own).
   integer(int32),    intent(out), optional :: stat       !< Status: `FIG_ERR_ARGUMENT` for an unknown name, look or
                                                          !< palette, a palette below the contrast rule, or no argument.
   character(len=*),  intent(in),  optional :: look       !< Look: the geometry (rounding, padding, spacing, borders).
   character(len=*),  intent(in),  optional :: palette    !< Palette: the colours, or `'auto'`.
   character(len=*),  intent(in),  optional :: auto_dark  !< Palette of `'auto'` on a dark system (default `'seal'`).
   character(len=*),  intent(in),  optional :: auto_light !< Palette of `'auto'` on a light system (default
                                                          !< `'seal-light'`).

   if (figure_refused('app%set_style', stat)) return ! a task does not draw
   call figure_check(fig_set_style_parts(opt(name), opt_len(name), opt(look), opt_len(look), opt(palette),      &
                                         opt_len(palette), opt(auto_dark), opt_len(auto_dark), opt(auto_light), &
                                         opt_len(auto_light), opt(lines), opt_len(lines)), stat)
   endsubroutine set_style

   recursive subroutine palette_color(self, role, rgba, stat)
   !< The colour of a palette role in effect, as `[r, g, b, a]` in [0, 1]: `'background'`, `'surface'`,
   !< `'raised_surface'`, `'border'`, `'text'`, `'dimmed_text'`, `'accent'`, `'text_on_accent'`, `'selection'`,
   !< `'success'`, `'warning'`, `'error'`. With a style that has no palette (`'dark'`, `'light'`, `'classic'`, a theme
   !< file without one), the roles are read from Dear ImGui's colours (`WindowBg`, `FrameBg`, `Button`, `Border`,
   !< `Text`, `TextDisabled`, `CheckMark`, `Header`), and success, warning and error are Okabe and Ito's bluish green,
   !< orange and vermilion. After `init*`; the same in every mode.
   class(app_object), intent(inout)         :: self    !< Application.
   character(len=*),  intent(in)            :: role    !< Role name.
   real(real64),      intent(out)           :: rgba(4) !< Colour, components in [0, 1].
   integer(int32),    intent(out), optional :: stat    !< Status: `FIG_ERR_ARGUMENT` for an unknown role.
   real(c_float)                            :: c(4)    !< Native colour.

   rgba = 0.0_real64
   if (figure_refused('app%palette_color', stat)) return ! a task does not draw
   c = 0.0_c_float
   call figure_check(fig_palette_color(role, len_trim(role, c_int), c), stat)
   rgba = real(c, real64)
   endsubroutine palette_color

   recursive subroutine notify(self, text, kind, seconds, stat)
   !< Tell the user something without a dialog: a notification drawn by FIGURE after the program's windows, in the
   !< bottom-right corner (above a bottom side bar), the newest at the bottom, older ones stacked above. `kind`:
   !< `'info'` (default), `'success'`, `'warning'` or `'error'`, drawn with its palette role (accent, success, warning,
   !< error) and its icon (`ICON_INFO`, `ICON_CIRCLE_CHECK`, `ICON_TRIANGLE_ALERT`, `ICON_CIRCLE_X`). It stays
   !< `seconds` (default 5; 0 or less: until clicked), fading out in its last half second, timed by the frame time
   !< (the fixed one in headless mode and in recordings); a click dismisses it. The last 100 are kept
   !< (`notifications`). Statuses: `FIG_ERR_STATE` before `init*` or from a task, `FIG_ERR_ARGUMENT` for an unknown
   !< kind. The same in every mode.
   class(app_object), intent(inout)         :: self    !< Application.
   character(len=*),  intent(in)            :: text    !< What to tell (UTF-8; wrapped).
   character(len=*),  intent(in),  optional :: kind    !< 'info', 'success', 'warning' or 'error'.
   real(real64),      intent(in),  optional :: seconds !< Time shown [s] (default 5; <= 0: until clicked).
   integer(int32),    intent(out), optional :: stat    !< Status.
   integer(c_int)                           :: k       !< Kind code.
   real(c_double)                           :: s       !< Seconds.
   character(len=:), allocatable            :: icon    !< Its icon.

   if (figure_refused('app%notify', stat)) return ! a task does not draw
   k = 0_c_int
   icon = ICON_INFO
   if (present(kind)) then
      select case (kind)
      case ('info')
         k = 0_c_int
      case ('success')
         k = 1_c_int
         icon = ICON_CIRCLE_CHECK
      case ('warning')
         k = 2_c_int
         icon = ICON_TRIANGLE_ALERT
      case ('error')
         k = 3_c_int
         icon = ICON_CIRCLE_X
      case default
         call figure_fail(FIG_ERR_ARGUMENT, "app%notify: kind is 'info', 'success', 'warning' or 'error', not '"// &
                          kind//"'", stat)
         return
      endselect
   endif
   s = 5.0_c_double
   if (present(seconds)) s = real(seconds, c_double)
   call figure_check(fig_notify(text, len(text, c_int), k, icon, len(icon, c_int), s), stat)
   endsubroutine notify

   recursive subroutine notifications(self, list, kinds, shown)
   !< The notifications kept, the last 100, oldest first: their texts (`list`, padded with blanks to the longest),
   !< their kinds (`'info'`, ...) and whether each is still shown (not yet timed out or dismissed). None before
   !< `init*`.
   class(app_object),             intent(in)            :: self     !< Application.
   character(len=:), allocatable, intent(out)           :: list(:)  !< Texts.
   character(len=7), allocatable, intent(out), optional :: kinds(:) !< Kinds.
   logical,          allocatable, intent(out), optional :: shown(:) !< Still shown.
   character(len=7), parameter                          :: NAMES(0:3) = ['info   ', 'success', 'warning', 'error  ']
   character(kind=c_char, len=4096)                     :: buf      !< A text.
   integer(c_int)                                       :: n, i, l, k, sh, longest !< Counters, state.

   if (figure_refused('app%notifications')) then ! a task does not draw: empty lists
      allocate(character(len=0) :: list(0))
      if (present(kinds)) allocate(kinds(0))
      if (present(shown)) allocate(shown(0))
      return
   endif
   if (fig_notification_count(n) /= FIG_OK) n = 0_c_int
   longest = 0_c_int
   do i = 1_c_int, n
      if (fig_notification_get(i, buf, 0_c_int, l, k, sh) == FIG_OK) longest = max(longest, min(l, len(buf, c_int)))
   enddo
   allocate(character(len=longest) :: list(n))
   if (present(kinds)) allocate(kinds(n))
   if (present(shown)) allocate(shown(n))
   do i = 1_c_int, n
      l = 0_c_int
      k = 0_c_int
      sh = 0_c_int
      if (fig_notification_get(i, buf, len(buf, c_int), l, k, sh) /= FIG_OK) cycle
      list(i) = buf(1:min(l, len(buf, c_int)))
      if (present(kinds)) kinds(i) = NAMES(k)
      if (present(shown)) shown(i) = sh == 1_c_int
   enddo
   endsubroutine notifications

   recursive subroutine set_font(self, font, size, stat)
   !< The default font of the interface, after `init*`: `'plex-sans'` (IBM Plex Sans, bundled: the default, at 15
   !< logical pixels), `'plex-mono'` (IBM Plex Mono, bundled: monospace, every character as wide), `'proggy'` (Dear
   !< ImGui's own 13-pixel bitmap font), or the path of a TrueType/OpenType file; `size` in logical pixels (multiplied
   !< by the display's content scale), kept if absent.
   class(app_object), intent(inout)         :: self !< Application.
   character(len=*),  intent(in)            :: font !< Font.
   real(real64),      intent(in),  optional :: size !< Size [logical pixels], in (0, 200].
   integer(int32),    intent(out), optional :: stat !< Status: `FIG_ERR_FAILED` if the file cannot be read,
                                                    !< `FIG_ERR_ARGUMENT` if it is not a font or the size is wrong.
   real(c_double)                           :: s    !< Size; 0: keep.

   if (figure_refused('app%set_font', stat)) return ! a task does not draw
   s = 0.0_c_double
   if (present(size)) then
      if (.not. (size > 0.0_real64)) then
         call figure_fail(FIG_ERR_ARGUMENT, 'set_font: size must be in (0, 200] pixels', stat)
         return
      endif
      s = real(size, c_double)
   endif
   call figure_check(fig_set_font(font, len_trim(font, c_int), s), stat)
   endsubroutine set_font

   recursive subroutine add_fallback_font(self, file, stat)
   !< A fallback font of the program's own, a TrueType/OpenType file: merged into every text font (the bundled ones,
   !< `'proggy'` and the files of `set_font`/`ig_push_font`, loaded already or later) after IBM Plex, the Lucide icons
   !< and the bundled fallback, Noto Sans Math, so it gives only the glyphs they all lack; several are asked in the
   !< order they are added. Its letters are scaled to the text font's em and stand on its baseline. After `init*`,
   !< between frames (not inside one); a file added already is not added again; it lasts until `destroy`. At most 13
   !< (Dear ImGui's 16 sources per font). The same in every mode (in remote mode the browser receives the glyphs).
   class(app_object), intent(inout)         :: self !< Application.
   character(len=*),  intent(in)            :: file !< TrueType/OpenType file.
   integer(int32),    intent(out), optional :: stat !< Status: `FIG_ERR_FAILED` if the file cannot be read,
                                                    !< `FIG_ERR_ARGUMENT` if it is not a font or 13 are added already,
                                                    !< `FIG_ERR_STATE` before `init*` or inside a frame.

   if (figure_refused('app%add_fallback_font', stat)) return ! a task does not draw
   call figure_check(fig_add_fallback_font(file, len_trim(file, c_int)), stat)
   endsubroutine add_fallback_font

   recursive subroutine load_style(self, file, stat)
   !< Apply a theme file (the format of the files in `themes/`: docs, Styles, Theme files), after `init*`. Sizes in the
   !< file are logical pixels; what the file does not set comes from its `base`.
   class(app_object), intent(inout)         :: self !< Application.
   character(len=*),  intent(in)            :: file !< Theme file.
   integer(int32),    intent(out), optional :: stat !< Status: `FIG_ERR_FAILED` if unreadable, `FIG_ERR_ARGUMENT` if
                                                    !< malformed (the message gives the line).

   if (figure_refused('app%load_style', stat)) return ! a task does not draw
   call figure_check(fig_load_style(file, len_trim(file, c_int)), stat)
   endsubroutine load_style

   recursive subroutine save_style(self, file, stat)
   !< Write the style in effect as a theme file: its base, background, line colours, and every colour and variable
   !< that differs from the base (sizes in logical pixels; colours as 8-bit hex, alphas exact). Changes made by name
   !< or in the style editor (`ig_show_style_editor`) are kept; `load_style` reads the file back.
   class(app_object), intent(inout)         :: self !< Application.
   character(len=*),  intent(in)            :: file !< Theme file to write.
   integer(int32),    intent(out), optional :: stat !< Status: `FIG_ERR_FAILED` if it cannot be written.

   if (figure_refused('app%save_style', stat)) return ! a task does not draw
   call figure_check(fig_save_style(file, len_trim(file, c_int)), stat)
   endsubroutine save_style

   recursive subroutine set_docking(self, enabled, stat)
   !< Docking on (the default since `init*`) or off: with docking on, a window dragged by its title bar docks into
   !< another window or into a dock space (`ig_dock_space`). After `init*`.
   class(app_object), intent(inout)         :: self    !< Application.
   logical,           intent(in)            :: enabled !< Docking on.
   integer(int32),    intent(out), optional :: stat    !< Status: `FIG_ERR_STATE` before `init*`.

   if (figure_refused('app%set_docking', stat)) return ! a task does not draw
   call figure_check(fig_set_docking(merge(1_c_int, 0_c_int, enabled)), stat)
   endsubroutine set_docking

   recursive subroutine request_frames(self, n)
   !< Draw at least `n` more frames without waiting for input (e.g. after new data arrived). It raises the count of
   !< frames still to draw, never lowers it: concurrent requests keep the largest. Callable from any thread (a task, an
   !< OpenMP thread): from another thread than the loop's it also wakes a lazy loop that is waiting, so the first of
   !< the frames starts at once.
   class(app_object), intent(inout) :: self !< Application.
   integer(int32),    intent(in)    :: n    !< Frames.

   call fig_request_frames(int(n, c_int))
   endsubroutine request_frames

   recursive subroutine wake(self)
   !< The next frame starts without waiting for input or `max_wait`, from any thread (a FIGURE task, an OpenMP thread,
   !< an MPI progress thread): a lazy loop that is waiting stops waiting, in every mode (window: an event; remote: the
   !< wait on the network ends; headless: the loop never waits). From the loop's own thread, the next `next_frame` does
   !< not wait. Never refused: a task may call it. Before `init*` it does nothing.
   class(app_object), intent(in) :: self !< Application.

   call fig_app_wake()
   endsubroutine wake

   recursive subroutine set_confirm_quit(self, enabled)
   !< With `enabled`, the window's close button (and the system's quit) no longer ends `next_frame`: the request is
   !< reported by `quit_requested`, and the program quits with `quit` (after asking to save, for example). Callable
   !< from any thread (a task included).
   class(app_object), intent(inout) :: self    !< Application.
   logical,           intent(in)    :: enabled !< Ask first.

   call fig_set_confirm_quit(merge(1_c_int, 0_c_int, enabled))
   endsubroutine set_confirm_quit

   recursive function quit_requested(self) result(requested)
   !< The user asked to quit (the window's close button) since the last call: true once per request. Only with
   !< `set_confirm_quit(.true.)`; otherwise the request ends `next_frame` at once. Callable from any thread (a task
   !< included): one caller gets each request.
   class(app_object), intent(inout) :: self      !< Application.
   logical                          :: requested !< Requested.

   requested = fig_quit_requested() == 1_c_int
   endfunction quit_requested

   recursive function dropped(self, paths, x, y, stat) result(any_dropped)
   !< The files and folders dropped on the window since the last frame (SDL's drop events), and where: true on the
   !< frame after the drop only, with `paths` the absolute paths (UTF-8, blank-padded to the longest; folders as
   !< folders, without a trailing separator) and (`x`, `y`) the point of the drop [pixels], the coordinates of
   !< `ig_item_rect` and of the mouse, so that the program can tell which window or region received it. Several files
   !< dropped at once come together, at one point. False, with `paths` empty, on every other frame; also before
   !< `init*` and from a task. Window mode: the system's drag and drop; headless mode: only the drops of `test_drop`;
   !< remote mode: none (a browser gives a page the dropped files' contents, not paths on the server: the page refuses
   !< them), but those of `test_drop`. Status: `FIG_ERR_STATE` before `init*` and from a task (a task does not draw:
   !< the task's status becomes `FIG_ERR_STATE` too); without `stat`, the result is `.false.` and nothing stops.
   class(app_object),             intent(in)            :: self        !< Application.
   character(len=:), allocatable, intent(out)           :: paths(:)    !< Paths dropped.
   real(real64),                  intent(out), optional :: x           !< Abscissa of the drop [pixels].
   real(real64),                  intent(out), optional :: y           !< Ordinate of the drop [pixels].
   integer(int32),                intent(out), optional :: stat        !< Status.
   logical                                              :: any_dropped !< Something was dropped.
   integer(c_int)                                       :: n           !< Paths.
   integer(c_int)                                       :: i           !< Counter.
   integer(c_int)                                       :: longest     !< The longest path [bytes].
   integer(c_int)                                       :: m           !< A path's length [bytes].
   real(c_float)                                        :: px, py      !< Point of the drop.
   character(len=1)                                     :: probe       !< A buffer for a length alone.

   n = 0_c_int
   px = 0.0_c_float
   py = 0.0_c_float
   if (.not. figure_refused('app%dropped', stat)) then
      if (fig_dropped(n, px, py) /= FIG_OK) then
         n = 0_c_int
         if (present(stat)) stat = int(FIG_ERR_STATE, int32)
      elseif (present(stat)) then
         stat = int(FIG_OK, int32)
      endif
   endif
   longest = 0_c_int
   do i = 1_c_int, n
      longest = max(longest, fig_dropped_path(i, probe, 0_c_int))
   enddo
   allocate(character(len=longest) :: paths(n))
   do i = 1_c_int, n
      paths(i) = ''
      m = fig_dropped_path(i, paths(i), longest)
   enddo
   if (present(x)) x = real(px, real64)
   if (present(y)) y = real(py, real64)
   any_dropped = n > 0_c_int
   endfunction dropped

   recursive subroutine quit(self)
   !< End the loop: the next `next_frame` returns `.false.` (in every mode). Callable from any thread (a task
   !< included): from another thread than the loop's it also wakes a lazy loop that is waiting, so the loop ends at
   !< once.
   class(app_object), intent(inout) :: self !< Application.

   call fig_quit()
   endsubroutine quit

   recursive subroutine set_title(self, text, stat)
   !< The window's title, after `init`: the document being edited and a mark when it has changes, for example. Shown in
   !< window mode; in remote and headless modes it is kept (read back by `title`) and nothing shows it.
   class(app_object), intent(inout)         :: self !< Application.
   character(len=*),  intent(in)            :: text !< Title.
   integer(int32),    intent(out), optional :: stat !< Status.

   if (figure_refused('app%set_title', stat)) return ! a task does not draw
   call figure_check(fig_set_title(text, len(text, c_int)), stat)
   endsubroutine set_title

   recursive function title(self) result(text)
   !< The window's title: the one given to `init` or the last `set_title` ('' before `init`, and in headless and remote
   !< modes until `set_title`).
   class(app_object), intent(in) :: self !< Application.
   character(len=:), allocatable :: text !< Title.
   character(kind=c_char)        :: none(1) !< No buffer (the length only).
   integer(c_int)                :: n    !< Length.

   if (figure_refused('app%title')) then ! a task does not draw
      text = ''
      return
   endif
   n = fig_title(none, 0_c_int)
   allocate(character(len=n) :: text)
   if (n > 0_c_int) n = fig_title(text, n)
   endfunction title

   recursive subroutine open_file_dialog(self, id, filters, default_path, stat, prefer)
   !< Show the system's dialog to choose a file to open. It does not block: the interface keeps drawing, and the answer
   !< is read with `file_dialog_result(id, ...)` on the following frames. `filters`: entries `'name|pattern'`, the
   !< pattern being extensions separated by `;` (`'Input files|input;inp'`, `'All files|*'`). Window mode only:
   !< `FIG_ERR_STATE` in remote and headless modes (FIGURE's own browser, `open_file_browser`, works there).
   !< `prefer='figure'` opens FIGURE's browser instead (`open_file_browser`), in every mode, answered the same way;
   !< `'system'` (default) the system's dialog. Statuses: as the dialog or the browser opened; `FIG_ERR_ARGUMENT` for
   !< another `prefer`.
   class(app_object), intent(inout)         :: self         !< Application.
   character(len=*),  intent(in)            :: id           !< Dialog id (any text, used to read the answer).
   character(len=*),  intent(in),  optional :: filters(:)   !< File type filters.
   character(len=*),  intent(in),  optional :: default_path !< Folder or file to start from (relative: to the
                                                                    !< working directory; absent: that directory).
   integer(int32),    intent(out), optional :: stat         !< Status.
   character(len=*),  intent(in),  optional :: prefer       !< `'system'` (default) or `'figure'`: FIGURE's browser.

   call show_dialog(0_c_int, 'app%open_file_dialog', id, filters, default_path, prefer, stat)
   endsubroutine open_file_dialog

   recursive subroutine save_file_dialog(self, id, filters, default_path, stat, prefer)
   !< Show the system's dialog to choose where to save (a new or an existing file); as `open_file_dialog`
   !< (`prefer='figure'`: FIGURE's browser, `save_file_browser`).
   class(app_object), intent(inout)         :: self         !< Application.
   character(len=*),  intent(in)            :: id           !< Dialog id.
   character(len=*),  intent(in),  optional :: filters(:)   !< File type filters.
   character(len=*),  intent(in),  optional :: default_path !< Folder or file to start from (relative: to the
                                                                    !< working directory; absent: that directory).
   integer(int32),    intent(out), optional :: stat         !< Status.
   character(len=*),  intent(in),  optional :: prefer       !< `'system'` (default) or `'figure'`: FIGURE's browser.

   call show_dialog(1_c_int, 'app%save_file_dialog', id, filters, default_path, prefer, stat)
   endsubroutine save_file_dialog

   recursive subroutine open_folder_dialog(self, id, default_path, stat, prefer)
   !< Show the system's dialog to choose a folder; as `open_file_dialog` (`prefer='figure'`: FIGURE's browser,
   !< `open_file_browser` with `folders=.true.`).
   class(app_object), intent(inout)         :: self         !< Application.
   character(len=*),  intent(in)            :: id           !< Dialog id.
   character(len=*),  intent(in),  optional :: default_path !< Folder to start from (relative: to the working
                                                                    !< directory; absent: that directory).
   integer(int32),    intent(out), optional :: stat         !< Status.
   character(len=*),  intent(in),  optional :: prefer       !< `'system'` (default) or `'figure'`: FIGURE's browser.

   call show_dialog(2_c_int, 'app%open_folder_dialog', id, default_path=default_path, prefer=prefer, stat=stat)
   endsubroutine open_folder_dialog

   recursive subroutine open_file_browser(self, id, filters, default_path, folders, stat)
   !< Show FIGURE's file browser to choose a file to open (or, with `folders`, a folder): a modal drawn by FIGURE in
   !< Dear ImGui, in the palette's colours, the same in window, remote and headless modes (in remote mode it lists the
   !< files of the machine the program runs on). It does not block: the answer is read with `file_dialog_result(id,
   !< ...)`, as a system dialog's, so a program switches between the two by changing this call. The browser lists the
   !< folder's entries (folders first, sizes, modification times; sorted by a click on a column's header), filtered by
   !< `filters` (as `open_file_dialog`'s, chosen in a list) with hidden files on request; a path field (Enter goes
   !< there, Tab completes), the parent folder, places (home, the working directory, the file systems' roots, the
   !< recent folders kept between runs in FIGURE's settings file) and a new folder. Escape or Cancel cancels. A folder
   !< that cannot be read is reported in the browser. Statuses: `FIG_ERR_STATE` before `init*`, from a task, or for an
   !< id with a dialog or a browser still open; `FIG_ERR_ARGUMENT` for a malformed filter.
   class(app_object), intent(inout)         :: self         !< Application.
   character(len=*),  intent(in)            :: id           !< Dialog id (any text, used to read the answer).
   character(len=*),  intent(in),  optional :: filters(:)   !< File type filters, `'name|pattern'` (the first in effect).
   character(len=*),  intent(in),  optional :: default_path !< Folder to start in, or a file (its folder; the file
                                                            !< selected); relative: to the working directory (absent:
                                                            !< that directory).
   logical,           intent(in),  optional :: folders      !< Choose a folder instead of a file (default false).
   integer(int32),    intent(out), optional :: stat         !< Status.
   integer(c_int)                           :: kind         !< 0 open a file, 2 choose a folder.

   if (figure_refused('app%open_file_browser', stat)) return ! a task does not draw
   kind = 0_c_int
   if (present(folders)) kind = merge(2_c_int, 0_c_int, folders)
   call show_file_browser(kind, id, filters, default_path, stat)
   endsubroutine open_file_browser

   recursive subroutine save_file_browser(self, id, filters, default_path, stat)
   !< Show FIGURE's file browser to choose where to save: a name typed in the folder shown, or an existing file; a file
   !< that exists is replaced only after the user says so. As `open_file_browser`; `default_path` may name the file
   !< to propose (its folder need exist, the file need not).
   class(app_object), intent(inout)         :: self         !< Application.
   character(len=*),  intent(in)            :: id           !< Dialog id.
   character(len=*),  intent(in),  optional :: filters(:)   !< File type filters, `'name|pattern'`.
   character(len=*),  intent(in),  optional :: default_path !< Folder to start in, or the file to propose.
   integer(int32),    intent(out), optional :: stat         !< Status.

   if (figure_refused('app%save_file_browser', stat)) return ! a task does not draw
   call show_file_browser(1_c_int, id, filters, default_path, stat)
   endsubroutine save_file_browser

   recursive subroutine file_dialog_result(self, id, path, done, cancelled, stat)
   !< The answer to the dialog or the browser `id`: `done` false while it is open; once answered, `done` true and
   !< either `path` (the file or folder chosen, absolute for the browser) or `cancelled` true. The answer is given once;
   !< then the id is free again, and until the next dialog `done` is false: poll it every frame. A dialog that failed
   !< (Linux without a portal or zenity) gives `done` true and `FIG_ERR_FAILED` with the reason.
   class(app_object),             intent(inout)         :: self      !< Application.
   character(len=*),              intent(in)            :: id        !< Dialog id.
   character(len=:), allocatable, intent(out)           :: path      !< Chosen path ('' while open or if cancelled).
   logical,                       intent(out)           :: done      !< The dialog was answered.
   logical,                       intent(out), optional :: cancelled !< The user cancelled it.
   integer(int32),                intent(out), optional :: stat      !< Status.
   character(kind=c_char, len=4096)                     :: buf       !< Path buffer.
   integer(c_int)                                       :: state     !< 0 open, 1 chosen, 2 cancelled, 3 failed.
   integer(c_int)                                       :: n         !< Path length.
   integer(c_int)                                       :: status    !< Status.

   done = .false.
   if (present(cancelled)) cancelled = .false.
   path = ''
   if (figure_refused('app%file_dialog_result', stat)) return ! a task does not draw
   status = fig_file_dialog_result(id, len(id, c_int), buf, len(buf, c_int), state, n)
   done = state /= 0_c_int
   if (present(cancelled)) cancelled = state == 2_c_int
   if (state == 1_c_int) path = buf(1:min(n, len(buf, c_int)))
   call figure_check(status, stat)
   endsubroutine file_dialog_result

   recursive subroutine save_image(self, path, xmin, ymin, xmax, ymax, stat)
   !< Write the rectangle (xmin, ymin)-(xmax, ymax) of the window [logical pixels, as `ig_item_rect` and
   !< `test_window_rect` give them] as a PNG file, at the screen's resolution, when the current frame is rendered.
   !< Ask for it outside the frame in which a menu or popup covers the rectangle (they would be in the picture).
   !< The outcome comes once, from `image_result`. Window mode only: in remote and headless modes there are no
   !< pixels on the program's side, `FIG_ERR_STATE`; an empty rectangle or file name, `FIG_ERR_ARGUMENT`.
   class(app_object), intent(inout)         :: self !< Application.
   character(len=*),  intent(in)            :: path !< PNG file.
   real(real64),      intent(in)            :: xmin !< Left.
   real(real64),      intent(in)            :: ymin !< Top.
   real(real64),      intent(in)            :: xmax !< Right.
   real(real64),      intent(in)            :: ymax !< Bottom.
   integer(int32),    intent(out), optional :: stat !< Status.

   if (figure_refused('app%save_image', stat)) return ! a task does not draw
   call figure_check(fig_save_image(path, len(path, c_int), real(xmin, c_double), real(ymin, c_double), &
                                    real(xmax, c_double), real(ymax, c_double)), stat)
   endsubroutine save_image

   recursive subroutine image_result(self, path, done, stat)
   !< The outcome of `save_image`, once, after the frame that wrote it: `done` true and the file `path`, or
   !< `FIG_ERR_FAILED` with the reason (the file cannot be written). `done` false before and after: poll it every frame.
   class(app_object),             intent(inout)         :: self !< Application.
   character(len=:), allocatable, intent(out)           :: path !< The file ('' until done).
   logical,                       intent(out)           :: done !< Written, or failed.
   integer(int32),                intent(out), optional :: stat !< Status.
   character(kind=c_char, len=4096)                     :: buf  !< Path buffer.
   integer(c_int)                                       :: state !< 0 none, 2 written, 3 failed.
   integer(c_int)                                       :: n    !< Path length.
   integer(c_int)                                       :: status !< Status.

   done = .false.
   path = ''
   if (figure_refused('app%image_result', stat)) return ! a task does not draw
   status = fig_image_result(buf, len(buf, c_int), state, n)
   done = state /= 0_c_int
   if (done) path = buf(1:min(n, len(buf, c_int)))
   call figure_check(status, stat)
   endsubroutine image_result

   recursive subroutine save_layout(self, path, comment, stat)
   !< Write the layout to `path`: the windows' positions, sizes and docking (the dock nodes and which window is in
   !< which), the tables' columns: Dear ImGui's settings, as its ini text, for every window shown in this session and
   !< those read before. `comment` (lines separated by `new_line('a')`) is written first, each line led by '; ', which
   !< `load_layout` skips: the program's own state (the windows it opens on demand, say) for itself to read back.
   !< Any mode. `FIG_ERR_FAILED` if the file cannot be written.
   class(app_object), intent(inout)         :: self    !< Application.
   character(len=*),  intent(in)            :: path    !< File.
   character(len=*),  intent(in),  optional :: comment !< Lines to keep with it.
   integer(int32),    intent(out), optional :: stat    !< Status.

   if (figure_refused('app%save_layout', stat)) return ! a task does not draw
   if (present(comment)) then
      call figure_check(fig_save_layout(path, len(path, c_int), comment, len(comment, c_int)), stat)
   else
      call figure_check(fig_save_layout(path, len(path, c_int), '', 0_c_int), stat)
   endif
   endsubroutine save_layout

   recursive subroutine load_layout(self, path, stat)
   !< Read a layout written by `save_layout` (or an ini file of Dear ImGui), applied before the next frame: the
   !< settings in effect are cleared, the file's are read, the dock nodes are rebuilt and the windows that exist take
   !< their saved position, size and dock; the others take theirs when they appear. A program that lays out its dock
   !< space with `ig_dock_layout_begin` should not lay it out again: the dock space has a layout again (the same id as
   !< when saved). `FIG_ERR_FAILED` if the file cannot be read, `FIG_ERR_ARGUMENT` if it holds no layout.
   class(app_object), intent(inout)         :: self !< Application.
   character(len=*),  intent(in)            :: path !< File.
   integer(int32),    intent(out), optional :: stat !< Status.

   if (figure_refused('app%load_layout', stat)) return ! a task does not draw
   call figure_check(fig_load_layout(path, len(path, c_int)), stat)
   endsubroutine load_layout

   recursive subroutine add_window(self, name, visible, closable, in_view_menu, remember, stat)
   !< Register the window `name` (the name given to `ig_begin`) with FIGURE's window registry: `view_menu` lists it as a
   !< check item that shows and hides it, `ig_begin(name)` (without `open`) gives it a close button that hides it, and
   !< the preferences (`open_prefs`) keep whether it is shown from one run to the next. The program draws it only while
   !< `window_visible(name)` is true. After `init*`, before or after `open_prefs` (a window added after takes its kept
   !< visibility when added). Statuses: `FIG_ERR_ARGUMENT` for an empty name or one added already, `FIG_ERR_STATE`
   !< before `init*` or from a task. The same in every mode.
   class(app_object), intent(inout)         :: self         !< Application.
   character(len=*),  intent(in)            :: name         !< Window name, as given to `ig_begin`.
   logical,           intent(in),  optional :: visible      !< Shown at the first run (default true).
   logical,           intent(in),  optional :: closable     !< A close button (default true).
   logical,           intent(in),  optional :: in_view_menu !< Listed in the View menu (default true).
   logical,           intent(in),  optional :: remember     !< Shown or hidden as at the end of the last run (default true).
   integer(int32),    intent(out), optional :: stat         !< Status.

   if (figure_refused('app%add_window', stat)) return ! a task does not draw
   call figure_check(fig_window_add(name, len(name, c_int), flag(visible, .true.), flag(closable, .true.), &
                                    flag(in_view_menu, .true.), flag(remember, .true.)), stat)
   endsubroutine add_window

   recursive function window_visible(self, name, stat) result(visible)
   !< True while the registered window `name` is shown: draw it (`ig_begin`/`ig_end`) only then. Hidden by its close
   !< button, by the View menu, by a layout that does not show it, or by `set_window_visible`. Statuses:
   !< `FIG_ERR_ARGUMENT` for a name not added (`.false.`), `FIG_ERR_STATE` from a task.
   class(app_object), intent(in)            :: self    !< Application.
   character(len=*),  intent(in)            :: name    !< Window name.
   integer(int32),    intent(out), optional :: stat    !< Status.
   logical                                  :: visible !< Shown.
   integer(c_int)                           :: v       !< 1: shown.

   visible = .false.
   if (figure_refused('app%window_visible', stat)) return ! a task does not draw
   v = 0_c_int
   call figure_check(fig_window_visible(name, len(name, c_int), v), stat)
   visible = v == 1_c_int
   endfunction window_visible

   recursive subroutine set_window_visible(self, name, visible, stat)
   !< Show or hide the registered window `name` from the program (a Log window shown when an error arrives). Statuses:
   !< `FIG_ERR_ARGUMENT` for a name not added, `FIG_ERR_STATE` from a task.
   class(app_object), intent(inout)         :: self    !< Application.
   character(len=*),  intent(in)            :: name    !< Window name.
   logical,           intent(in)            :: visible !< Shown.
   integer(int32),    intent(out), optional :: stat    !< Status.

   if (figure_refused('app%set_window_visible', stat)) return ! a task does not draw
   call figure_check(fig_window_set_visible(name, len(name, c_int), merge(1_c_int, 0_c_int, visible)), stat)
   endsubroutine set_window_visible

   recursive subroutine view_menu(self, label, stat)
   !< The View menu, inside a menu bar (`ig_begin_main_menu_bar` or `ig_begin_menu_bar`): a check item per registered
   !< window listed in it (its name without the `##` part), in the order added; then, with layouts, one item per layout
   !< (the current one checked: a click switches to it); then "Reset layout" (`reset_layout`), shown with layouts or
   !< once a dock space was laid out with `ig_dock_layout_begin`. Each frame, where the menu goes. Statuses:
   !< `FIG_ERR_STATE` with no frame open or from a task. The same in every mode.
   class(app_object), intent(inout)         :: self  !< Application.
   character(len=*),  intent(in),  optional :: label !< The menu's label (default 'View').
   integer(int32),    intent(out), optional :: stat  !< Status.

   if (figure_draw_refused('app%view_menu', stat)) return ! a task does not draw; a frame is open
   call figure_check(fig_view_menu(opt(label), opt_len(label)), stat)
   endsubroutine view_menu

   recursive subroutine add_layout(self, name, windows, stat)
   !< Declare the layout `name`: an arrangement of the dock space the program builds when `ig_dock_layout_begin` returns
   !< true and `layout()` is `name` (FIGURE calls nothing of the program's: the builder is the program's code under
   !< that test). The first added is current, unless the preferences kept another. `windows`, the registered windows
   !< the layout shows (the other registered ones are hidden when it becomes current); absent, switching to it leaves
   !< them as they are. Statuses: `FIG_ERR_ARGUMENT` for an empty name or one added already, `FIG_ERR_STATE` before
   !< `init*` or from a task.
   class(app_object), intent(inout)         :: self       !< Application.
   character(len=*),  intent(in)            :: name       !< Layout name (shown in the View menu).
   character(len=*),  intent(in),  optional :: windows(:) !< The registered windows it shows (blank-padded).
   integer(int32),    intent(out), optional :: stat       !< Status.
   character(len=:), allocatable            :: joined     !< Window names, newline-separated.
   integer(int32)                           :: k          !< Counter.

   if (figure_refused('app%add_layout', stat)) return ! a task does not draw
   joined = ''
   if (present(windows)) then
      do k = 1_int32, size(windows, kind=int32)
         joined = joined//trim(windows(k))//new_line('a')
      enddo
   endif
   call figure_check(fig_layout_add(name, len(name, c_int), joined, len(joined, c_int), &
                                    merge(1_c_int, 0_c_int, present(windows))), stat)
   endsubroutine add_layout

   recursive subroutine switch_layout(self, name, stat)
   !< Make the layout `name` current (the View menu does it on a click). The arrangement the user left the current one
   !< in is kept; then, if `name` was arranged by the user earlier in this run (or in the last, by the preferences),
   !< that arrangement comes back before the next frame; otherwise each dock space laid out with `ig_dock_layout_begin`
   !< is laid out again: `ig_dock_layout_begin` returns true on its next call and the program builds `layout()`. A
   !< layout with `windows` shows those and hides the other registered windows. Statuses: `FIG_ERR_ARGUMENT` for a
   !< layout not added, `FIG_ERR_STATE` from a task. Between frames or inside one; the same in every mode.
   class(app_object), intent(inout)         :: self !< Application.
   character(len=*),  intent(in)            :: name !< Layout name.
   integer(int32),    intent(out), optional :: stat !< Status.

   if (figure_refused('app%switch_layout', stat)) return ! a task does not draw
   call figure_check(fig_layout_switch(name, len(name, c_int)), stat)
   endsubroutine switch_layout

   recursive subroutine reset_layout(self, stat)
   !< Lay the current layout out again (the View menu's "Reset layout"): the user's changes to it are forgotten, each
   !< dock space laid out with `ig_dock_layout_begin` is laid out again on the next frame, and a layout with `windows`
   !< shows those again. Without layouts, the dock spaces are laid out again all the same. Status: `FIG_ERR_STATE`
   !< from a task.
   class(app_object), intent(inout)         :: self !< Application.
   integer(int32),    intent(out), optional :: stat !< Status.

   if (figure_refused('app%reset_layout', stat)) return ! a task does not draw
   call figure_check(fig_layout_reset(), stat)
   endsubroutine reset_layout

   recursive function layout(self) result(name)
   !< The current layout's name ('' before the first `add_layout`): the one to build when `ig_dock_layout_begin`
   !< returns true. '' from a task.
   class(app_object), intent(in) :: self    !< Application.
   character(len=:), allocatable :: name    !< Layout name.
   character(kind=c_char)        :: none(1) !< No buffer (the length only).
   integer(c_int)                :: n       !< Length.

   name = ''
   if (figure_refused('app%layout')) return ! a task does not draw
   n = fig_layout_current(none, 0_c_int)
   deallocate(name)
   allocate(character(len=n) :: name)
   if (n > 0_c_int) n = fig_layout_current(name, n)
   endfunction layout

   recursive subroutine open_prefs(self, name, file, stat)
   !< Keep the program's preferences in a file from now on, and read those of the last run: the values of `save_pref`,
   !< the registered windows' visibility, the current layout and the arrangement of each layout, the style set by
   !< `set_style` and, in window mode, the window's position, size and maximized state. Read now: the style and the
   !< window's geometry are applied at once, the arrangement before the next frame; so call it after `init*` and after
   !< the program's own defaults (`set_style`), before the first frame. Written when something changed, every 30 s of
   !< frame time and at `destroy`, to `<file>.tmp` first and then renamed over the file: a crash leaves the file of
   !< the last save whole. The file: `file`, or `preferences.ini` in the platform's folder for the program `name`
   !< (SDL's `SDL_GetPrefPath`: `~/.local/share/<name>/` on Linux, `%APPDATA%\<name>\` on Windows,
   !< `~/Library/Application Support/<name>/` on macOS); in headless mode without `file` none (kept in memory: tests
   !< name a file), and during a capture (`FIGURE_CAPTURE`) nothing is read or written. A file that does not exist yet
   !< is not an error. Not kept: a theme file (`load_style`), the style editor's changes, the colours and variables
   !< set by name, the fonts. Statuses: `FIG_ERR_ARGUMENT` for a name that is not a folder's name (letters, digits,
   !< blanks, `.`, `_`, `-`), `FIG_ERR_STATE` before `init*`, a second time, or from a task.
   class(app_object), intent(inout)         :: self !< Application.
   character(len=*),  intent(in)            :: name !< The program's name: its folder of preferences.
   character(len=*),  intent(in),  optional :: file !< The file instead (relative: to the working directory).
   integer(int32),    intent(out), optional :: stat !< Status.

   if (figure_refused('app%open_prefs', stat)) return ! a task does not draw
   call figure_check(fig_prefs_open(name, len_trim(name, c_int), opt(file), opt_len(file)), stat)
   endsubroutine open_prefs

   recursive function prefs_file(self) result(path)
   !< The file `open_prefs` keeps the preferences in ('' before it, in memory only, or from a task).
   class(app_object), intent(in) :: self    !< Application.
   character(len=:), allocatable :: path    !< File.
   character(kind=c_char)        :: none(1) !< No buffer (the length only).
   integer(c_int)                :: n       !< Length.

   path = ''
   if (figure_refused('app%prefs_file')) return ! the loop's thread only
   n = fig_prefs_file(none, 0_c_int)
   deallocate(path)
   allocate(character(len=n) :: path)
   if (n > 0_c_int) n = fig_prefs_file(path, n)
   endfunction prefs_file

   recursive subroutine save_pref_text(self, key, value, stat)
   !< Keep the preference `key`: a text (every character kept, trailing blanks too). In memory until the next save
   !< of the file (`open_prefs`); without `open_prefs`, for this run. Statuses: `FIG_ERR_ARGUMENT` for a key that is
   !< empty, has a newline or a blank at an end, or starts with `[`, `#` or `;`; `FIG_ERR_STATE` before `init*` or
   !< from a task.
   class(app_object), intent(inout)         :: self  !< Application.
   character(len=*),  intent(in)            :: key   !< Key.
   character(len=*),  intent(in)            :: value !< Value.
   integer(int32),    intent(out), optional :: stat  !< Status.

   if (figure_refused('app%save_pref', stat)) return ! the loop's thread only
   call figure_check(fig_pref_set(key, len_trim(key, c_int), value, len(value, c_int)), stat)
   endsubroutine save_pref_text

   recursive subroutine save_pref_int32(self, key, value, stat)
   !< Keep the preference `key`: an integer (as save_pref of a text, written in decimal).
   class(app_object), intent(inout)         :: self  !< Application.
   character(len=*),  intent(in)            :: key   !< Key.
   integer(int32),    intent(in)            :: value !< Value.
   integer(int32),    intent(out), optional :: stat  !< Status.
   character(len=24)                        :: t     !< Its text.

   write(t, '(I0)') value
   call self%save_pref_text(key, trim(t), stat)
   endsubroutine save_pref_int32

   recursive subroutine save_pref_int64(self, key, value, stat)
   !< Keep the preference `key`: a 64-bit integer (as save_pref of a text, written in decimal).
   class(app_object), intent(inout)         :: self  !< Application.
   character(len=*),  intent(in)            :: key   !< Key.
   integer(int64),    intent(in)            :: value !< Value.
   integer(int32),    intent(out), optional :: stat  !< Status.
   character(len=24)                        :: t     !< Its text.

   write(t, '(I0)') value
   call self%save_pref_text(key, trim(t), stat)
   endsubroutine save_pref_int64

   recursive subroutine save_pref_real32(self, key, value, stat)
   !< Keep the preference `key`: a real (as save_pref of a text, written with 9 significant digits: read back exactly).
   class(app_object), intent(inout)         :: self  !< Application.
   character(len=*),  intent(in)            :: key   !< Key.
   real(real32),      intent(in)            :: value !< Value.
   integer(int32),    intent(out), optional :: stat  !< Status.

   call self%save_pref_text(key, real_text(real(value, real64), 8_int32, value_32=value), stat)
   endsubroutine save_pref_real32

   recursive subroutine save_pref_real64(self, key, value, stat)
   !< Keep the preference `key`: a real (as save_pref of a text, written with 17 significant digits: read back exactly).
   class(app_object), intent(inout)         :: self  !< Application.
   character(len=*),  intent(in)            :: key   !< Key.
   real(real64),      intent(in)            :: value !< Value.
   integer(int32),    intent(out), optional :: stat  !< Status.

   call self%save_pref_text(key, real_text(value, 16_int32), stat)
   endsubroutine save_pref_real64

   recursive function real_text(value, digits, value_32) result(text)
   !< The shortest text of `value` that reads back to it: scientific notation with 1 to `digits` + 1 significant
   !< digits, its exponent without padding (`7.0E-1`, `1.0000000000000001E-1`); `Infinity`, `NaN` as written. With
   !< `value_32`, read back as a 32-bit real.
   real(real64),     intent(in)           :: value    !< Value.
   integer(int32),   intent(in)           :: digits   !< Most digits after the point.
   real(real32),     intent(in), optional :: value_32 !< The 32-bit value, when it is one.
   character(len=:), allocatable          :: text     !< Its text.
   character(len=48)                      :: buf      !< A trial.
   character(len=16)                      :: fmt      !< Its format.
   real(real64)                           :: back     !< Read back.
   real(real32)                           :: back_32  !< Read back, 32 bits.
   integer(int32)                         :: d, e, ios, ex !< Digits, the exponent's place, I/O status, exponent.
   logical                                :: flags(size(ieee_all)) !< The floating-point flags on entry.

   call ieee_get_flag(ieee_all, flags) ! the trials' flags (an underflow, say) do not reach the caller
   d = 1_int32
   if (present(value_32)) then         ! within 10 % of huge() a shorter trial may round past it: all the digits
      if (.not. (abs(value_32) < 0.9_real32 * huge(value_32))) d = digits
   elseif (.not. (abs(value) < 0.9_real64 * huge(value))) then
      d = digits
   endif
   do d = d, digits
      write(fmt, '(A,I0,A,I0,A)') '(ES', d + 12_int32, '.', d, 'E4)'
      write(buf, fmt) value
      if (present(value_32)) then
         read(buf, '(F48.0)', iostat=ios) back_32
         if (ios == 0 .and. back_32 == value_32) exit
      else
         read(buf, '(F48.0)', iostat=ios) back
         if (ios == 0 .and. back == value) exit
      endif
   enddo
   call ieee_set_flag(ieee_all, flags)
   text = trim(adjustl(buf))
   e = index(text, 'E')
   if (e > 0) then
      read(text(e + 1:), '(I8)', iostat=ios) ex
      if (ios == 0) then
         write(buf, '(I0)') ex
         text = text(1:e)//trim(buf)
      endif
   endif
   endfunction real_text

   recursive subroutine save_pref_logical(self, key, value, stat)
   !< Keep the preference `key`: a logical (as save_pref of a text, written `true` or `false`).
   class(app_object), intent(inout)         :: self  !< Application.
   character(len=*),  intent(in)            :: key   !< Key.
   logical,           intent(in)            :: value !< Value.
   integer(int32),    intent(out), optional :: stat  !< Status.

   if (value) then
      call self%save_pref_text(key, 'true', stat)
   else
      call self%save_pref_text(key, 'false', stat)
   endif
   endsubroutine save_pref_logical

   recursive function pref_text(key, found, stat) result(text)
   !< The text of the preference `key`, and whether it is kept.
   character(len=*), intent(in)            :: key   !< Key.
   logical,          intent(out)           :: found !< Kept.
   integer(int32),   intent(out), optional :: stat  !< Status.
   character(len=:), allocatable           :: text  !< Its text ('' if not kept).
   character(kind=c_char)                  :: none(1) !< No buffer (the length only).
   integer(c_int)                          :: n, m, f !< Length, length copied, found flag.
   integer(c_int)                          :: status !< Native status.

   text = ''
   found = .false.
   n = 0_c_int
   f = 0_c_int
   status = fig_pref_get(key, len_trim(key, c_int), none, 0_c_int, n, f)
   if (status == FIG_OK .and. f == 1_c_int) then
      deallocate(text)
      allocate(character(len=n) :: text)
      if (n > 0_c_int) status = fig_pref_get(key, len_trim(key, c_int), text, n, m, f)
      found = .true.
   endif
   call figure_check(status, stat)
   endfunction pref_text

   recursive function load_pref_text(self, key, value, default, stat) result(found)
   !< The preference `key` into `value`: true when it is kept (`value` takes it, blank-padded or cut to its length);
   !< false when it is not, and `value` takes `default` if present, else stays as it is. Statuses: as `save_pref`'s.
   class(app_object), intent(in)            :: self    !< Application.
   character(len=*),  intent(in)            :: key     !< Key.
   character(len=*),  intent(inout)         :: value   !< Value.
   character(len=*),  intent(in),  optional :: default !< Value when not kept.
   integer(int32),    intent(out), optional :: stat    !< Status.
   logical                                  :: found   !< Kept.
   character(len=:), allocatable            :: t       !< Its text.

   found = .false.
   if (figure_refused('app%load_pref', stat)) return ! the loop's thread only
   t = pref_text(key, found, stat)
   if (found) then
      value = t
   elseif (present(default)) then
      value = default
   endif
   endfunction load_pref_text

   recursive function load_pref_int32(self, key, value, default, stat) result(found)
   !< The preference `key` into `value` as an integer: true when it is kept and is one; otherwise false, and `value`
   !< takes `default` if present, else stays as it is (a text edited into something else counts as not kept).
   class(app_object), intent(in)            :: self    !< Application.
   character(len=*),  intent(in)            :: key     !< Key.
   integer(int32),    intent(inout)         :: value   !< Value.
   integer(int32),    intent(in),  optional :: default !< Value when not kept.
   integer(int32),    intent(out), optional :: stat    !< Status.
   logical                                  :: found   !< Kept.
   character(len=:), allocatable            :: t       !< Its text.
   integer(int32)                           :: v, ios  !< Value read, I/O status.

   found = .false.
   if (figure_refused('app%load_pref', stat)) return ! the loop's thread only
   t = pref_text(key, found, stat)
   if (found) then
      read(t, '(I40)', iostat=ios) v
      found = ios == 0 .and. len_trim(t) > 0
   endif
   if (found) then
      value = v
   elseif (present(default)) then
      value = default
   endif
   endfunction load_pref_int32

   recursive function load_pref_int64(self, key, value, default, stat) result(found)
   !< The preference `key` into `value` as a 64-bit integer: as `load_pref` of an integer.
   class(app_object), intent(in)            :: self    !< Application.
   character(len=*),  intent(in)            :: key     !< Key.
   integer(int64),    intent(inout)         :: value   !< Value.
   integer(int64),    intent(in),  optional :: default !< Value when not kept.
   integer(int32),    intent(out), optional :: stat    !< Status.
   logical                                  :: found   !< Kept.
   character(len=:), allocatable            :: t       !< Its text.
   integer(int64)                           :: v       !< Value read.
   integer(int32)                           :: ios     !< I/O status.

   found = .false.
   if (figure_refused('app%load_pref', stat)) return ! the loop's thread only
   t = pref_text(key, found, stat)
   if (found) then
      read(t, '(I40)', iostat=ios) v
      found = ios == 0 .and. len_trim(t) > 0
   endif
   if (found) then
      value = v
   elseif (present(default)) then
      value = default
   endif
   endfunction load_pref_int64

   recursive function load_pref_real32(self, key, value, default, stat) result(found)
   !< The preference `key` into `value` as a real: as `load_pref` of an integer.
   class(app_object), intent(in)            :: self    !< Application.
   character(len=*),  intent(in)            :: key     !< Key.
   real(real32),      intent(inout)         :: value   !< Value.
   real(real32),      intent(in),  optional :: default !< Value when not kept.
   integer(int32),    intent(out), optional :: stat    !< Status.
   logical                                  :: found   !< Kept.
   character(len=:), allocatable            :: t       !< Its text.
   real(real32)                             :: v       !< Value read.
   integer(int32)                           :: ios     !< I/O status.

   found = .false.
   if (figure_refused('app%load_pref', stat)) return ! the loop's thread only
   t = pref_text(key, found, stat)
   if (found) then
      read(t, '(F40.0)', iostat=ios) v
      found = ios == 0 .and. len_trim(t) > 0
   endif
   if (found) then
      value = v
   elseif (present(default)) then
      value = default
   endif
   endfunction load_pref_real32

   recursive function load_pref_real64(self, key, value, default, stat) result(found)
   !< The preference `key` into `value` as a real: as `load_pref` of an integer.
   class(app_object), intent(in)            :: self    !< Application.
   character(len=*),  intent(in)            :: key     !< Key.
   real(real64),      intent(inout)         :: value   !< Value.
   real(real64),      intent(in),  optional :: default !< Value when not kept.
   integer(int32),    intent(out), optional :: stat    !< Status.
   logical                                  :: found   !< Kept.
   character(len=:), allocatable            :: t       !< Its text.
   real(real64)                             :: v       !< Value read.
   integer(int32)                           :: ios     !< I/O status.

   found = .false.
   if (figure_refused('app%load_pref', stat)) return ! the loop's thread only
   t = pref_text(key, found, stat)
   if (found) then
      read(t, '(F40.0)', iostat=ios) v
      found = ios == 0 .and. len_trim(t) > 0
   endif
   if (found) then
      value = v
   elseif (present(default)) then
      value = default
   endif
   endfunction load_pref_real64

   recursive function load_pref_logical(self, key, value, default, stat) result(found)
   !< The preference `key` into `value` as a logical (`true` or `false`): as `load_pref` of an integer.
   class(app_object), intent(in)            :: self    !< Application.
   character(len=*),  intent(in)            :: key     !< Key.
   logical,           intent(inout)         :: value   !< Value.
   logical,           intent(in),  optional :: default !< Value when not kept.
   integer(int32),    intent(out), optional :: stat    !< Status.
   logical                                  :: found   !< Kept.
   character(len=:), allocatable            :: t       !< Its text.

   found = .false.
   if (figure_refused('app%load_pref', stat)) return ! the loop's thread only
   t = pref_text(key, found, stat)
   if (found) found = trim(adjustl(t)) == 'true' .or. trim(adjustl(t)) == 'false'
   if (found) then
      value = trim(adjustl(t)) == 'true'
   elseif (present(default)) then
      value = default
   endif
   endfunction load_pref_logical

   recursive function message_box(self, id, title, text, buttons, stat) result(answer)
   !< Ask the user in a box: a modal drawn by FIGURE after the program's windows, centred, with `title`, `text`
   !< (wrapped) and a row of `buttons` (default `'OK'`). Polled: call it every frame while waiting (a call opens the
   !< box `id` if it is not open; the texts of later calls replace its own): 0 while the box is open, then once the
   !< number of the button chosen (from 1), after which the box is gone and the id free. The box stays open until
   !< answered, called or not. Enter chooses the first button, Escape the last. Several boxes at once: each opened
   !< over the ones before, the newest on top, answered from the top down. A box waits, not drawn, while a popup of the
   !< program's (a menu, a modal, a file browser) is open: Dear ImGui keeps one popup per level. Statuses:
   !< `FIG_ERR_ARGUMENT` for an empty id or every button label empty, `FIG_ERR_STATE` before `init*` or from a task.
   !< The same in every mode.
   class(app_object), intent(inout)         :: self       !< Application.
   character(len=*),  intent(in)            :: id         !< Id (any text: the box's own).
   character(len=*),  intent(in)            :: title      !< Title.
   character(len=*),  intent(in)            :: text       !< Text (UTF-8).
   character(len=*),  intent(in),  optional :: buttons(:) !< Button labels (blank-padded; default `'OK'`).
   integer(int32),    intent(out), optional :: stat       !< Status.
   integer(int32)                           :: answer     !< 0 while open, then the button chosen (from 1).
   character(len=:), allocatable            :: joined     !< Labels, newline-separated.
   integer(int32)                           :: k          !< Counter.
   integer(c_int)                           :: a          !< Answer.

   answer = 0_int32
   if (figure_refused('app%message_box', stat)) return ! a task does not draw
   a = 0_c_int
   if (present(buttons)) then
      joined = ''
      do k = 1_int32, size(buttons, kind=int32)
         joined = joined//trim(buttons(k))//new_line('a')
      enddo
      call figure_check(fig_message_box(id, len(id, c_int), title, len(title, c_int), text, len(text, c_int), joined, &
                                        len(joined, c_int), a), stat)
   else
      call figure_check(fig_message_box(id, len(id, c_int), title, len(title, c_int), text, len(text, c_int), '', &
                                        -1_c_int, a), stat)
   endif
   answer = int(a, int32)
   endfunction message_box

   recursive subroutine set_size_limits(self, min_width, min_height, max_width, max_height, stat)
   !< The least and the greatest size the user can give the window [logical pixels, as `init`'s]; 0, or an absent
   !< maximum: no limit. Window mode; in headless and remote modes it does nothing (the display is the test's or the
   !< browser's). Statuses: `FIG_ERR_ARGUMENT` for a negative size or a maximum below its minimum, `FIG_ERR_FAILED`
   !< if the system refuses, `FIG_ERR_STATE` before `init*` or from a task.
   class(app_object), intent(inout)         :: self       !< Application.
   integer(int32),    intent(in)            :: min_width  !< Least width [logical pixels].
   integer(int32),    intent(in)            :: min_height !< Least height [logical pixels].
   integer(int32),    intent(in),  optional :: max_width  !< Greatest width [logical pixels] (default: none).
   integer(int32),    intent(in),  optional :: max_height !< Greatest height [logical pixels] (default: none).
   integer(int32),    intent(out), optional :: stat       !< Status.
   integer(c_int)                           :: mw, mh     !< Maxima (0: none).

   if (figure_refused('app%set_size_limits', stat)) return ! a task does not draw
   mw = 0_c_int
   if (present(max_width)) mw = int(max_width, c_int)
   mh = 0_c_int
   if (present(max_height)) mh = int(max_height, c_int)
   call figure_check(fig_set_size_limits(int(min_width, c_int), int(min_height, c_int), mw, mh), stat)
   endsubroutine set_size_limits

   recursive function content_scale(self) result(scale)
   !< Display content scale (1 standard, 2 on most high-DPI displays). Callable from any thread (a task included).
   class(app_object), intent(in) :: self  !< Application.
   real(real64)                  :: scale !< Scale.

   scale = real(fig_content_scale(), real64)
   endfunction content_scale

   recursive subroutine destroy(self)
   !< Close the window and destroy the contexts (safe in any state).
   class(app_object), intent(inout) :: self !< Application.

   if (figure_refused('app%destroy')) return ! a task does not draw
   call fig_shutdown()
   self%in_frame = .false.
   endsubroutine destroy

   recursive subroutine show_dialog(kind, who, id, filters, default_path, prefer, stat)
   !< The system's dialog of `kind` (0 open, 1 save, 2 folder) or, with `prefer='figure'`, FIGURE's browser of that kind.
   integer(c_int),   intent(in)            :: kind         !< Kind.
   character(len=*), intent(in)            :: who          !< The entry point, for messages.
   character(len=*), intent(in)            :: id           !< Dialog id.
   character(len=*), intent(in), optional  :: filters(:)   !< 'name|pattern' entries.
   character(len=*), intent(in), optional  :: default_path !< Where to start.
   character(len=*), intent(in), optional  :: prefer       !< 'system' or 'figure'.
   integer(int32),   intent(out), optional :: stat         !< Status.
   character(len=:), allocatable           :: which        !< The choice, trimmed.

   which = 'system'
   if (present(prefer)) which = trim(prefer)
   select case (which)
   case ('system')
      call show_file_dialog(kind, id, filters, default_path, stat)
   case ('figure')
   if (figure_refused(who, stat)) return ! a task does not draw
      call show_file_browser(kind, id, filters, default_path, stat)
   case default
      call figure_fail(FIG_ERR_ARGUMENT, who//": prefer is 'system' or 'figure', got '"//which//"'", stat)
   endselect
   endsubroutine show_dialog

   subroutine show_file_dialog(kind, id, filters, default_path, stat)
   !< Open a native file dialog of `kind` (0 open, 1 save, 2 folder).
   integer(c_int),   intent(in)            :: kind         !< Kind.
   character(len=*), intent(in)            :: id           !< Dialog id.
   character(len=*), intent(in), optional  :: filters(:)   !< 'name|pattern' entries.
   character(len=*), intent(in), optional  :: default_path !< Where to start.
   integer(int32),   intent(out), optional :: stat         !< Status.
   character(len=:), allocatable           :: joined       !< Filters joined by newlines.
   integer(int32)                          :: k            !< Counter.

   joined = ''
   if (present(filters)) then
      do k = 1_int32, size(filters, kind=int32)
         joined = joined//trim(filters(k))//new_line('a')
      enddo
   endif
   if (present(default_path)) then
      call figure_check(fig_file_dialog(kind, id, len(id, c_int), joined, len(joined, c_int), default_path, &
                                        len_trim(default_path, c_int)), stat)
   else
      call figure_check(fig_file_dialog(kind, id, len(id, c_int), joined, len(joined, c_int), '', 0_c_int), stat)
   endif
   endsubroutine show_file_dialog

   subroutine show_file_browser(kind, id, filters, default_path, stat)
   !< Open FIGURE's file browser of `kind` (0 open, 1 save, 2 folder).
   integer(c_int),   intent(in)            :: kind         !< Kind.
   character(len=*), intent(in)            :: id           !< Dialog id.
   character(len=*), intent(in), optional  :: filters(:)   !< 'name|pattern' entries.
   character(len=*), intent(in), optional  :: default_path !< Where to start.
   integer(int32),   intent(out), optional :: stat         !< Status.
   character(len=:), allocatable           :: joined       !< Filters joined by newlines.
   integer(int32)                          :: k            !< Counter.

   joined = ''
   if (present(filters)) then
      do k = 1_int32, size(filters, kind=int32)
         joined = joined//trim(filters(k))//new_line('a')
      enddo
   endif
   if (present(default_path)) then
      call figure_check(fig_file_browser(kind, id, len(id, c_int), joined, len(joined, c_int), default_path, &
                                         len_trim(default_path, c_int)), stat)
   else
      call figure_check(fig_file_browser(kind, id, len(id, c_int), joined, len(joined, c_int), '', 0_c_int), stat)
   endif
   endsubroutine show_file_browser

   pure function opt(s) result(v)
   !< An optional string, or '' when absent (the native layer takes a length of 0 as not given).
   character(len=*), intent(in), optional :: s !< String.
   character(len=:), allocatable          :: v !< Value.

   v = ''
   if (present(s)) v = s
   endfunction opt

   pure function flag(value, default) result(f)
   !< An optional logical as 0 or 1, `default` when absent.
   logical, intent(in), optional :: value   !< Value.
   logical, intent(in)           :: default !< Value when absent.
   integer(c_int)                :: f       !< 0 or 1.

   f = merge(1_c_int, 0_c_int, default)
   if (present(value)) f = merge(1_c_int, 0_c_int, value)
   endfunction flag

   pure function opt_len(s) result(n)
   !< The length of an optional name without its trailing blanks (a padded array's element), 0 when absent.
   character(len=*), intent(in), optional :: s !< String.
   integer(c_int)                         :: n !< Length [bytes].

   n = 0_c_int
   if (present(s)) n = len_trim(s, c_int)
   endfunction opt_len
endmodule figure_app
