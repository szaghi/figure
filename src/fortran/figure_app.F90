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
use, intrinsic :: iso_c_binding, only : c_double, c_int
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure_base, only : figure_check, figure_fail
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_OK, fig_begin_frame, fig_content_scale, fig_end_frame, fig_init, &
                            fig_init_headless, fig_init_remote, fig_load_style, fig_request_frames, fig_save_style,   &
                            fig_set_docking, fig_set_font, fig_set_ini_file, fig_set_lazy, fig_set_remote_compress,       &
                            fig_set_remote_fps, fig_set_remote_token, fig_remote_token, &
                            fig_set_style, fig_shutdown

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
      procedure, pass(self) :: set_lazy       !< Lazy redraw on/off, longest sleep.
      procedure, pass(self) :: set_style      !< Colours of the interface, the plots and the background.
      procedure, pass(self) :: set_docking    !< Docking on (the default) or off.
      procedure, pass(self) :: set_font       !< The default font and its size.
      procedure, pass(self) :: load_style     !< A theme file.
      procedure, pass(self) :: save_style     !< The style in effect, as a theme file.
      procedure, pass(self) :: request_frames !< Redraw without waiting for input.
      procedure, pass(self) :: content_scale  !< Display content scale.
      procedure, pass(self) :: destroy        !< Close everything.
endtype app_object

contains
   subroutine init(self, title, width, height, vsync, stat, ini_file)
   !< Open the window (`width` x `height` logical pixels) and create the ImGui/ImPlot contexts.
   !<
   !< Window positions and sizes are not saved by default: with `ini_file`, Dear ImGui keeps them in that file, read
   !< at the first frame and written while the program runs (its `imgui.ini`).
   class(app_object), intent(inout)         :: self     !< Application.
   character(len=*),  intent(in)            :: title    !< Window title.
   integer(int32),    intent(in)            :: width    !< Width [logical pixels].
   integer(int32),    intent(in)            :: height   !< Height [logical pixels].
   logical,           intent(in),  optional :: vsync    !< Synchronize with the display (default true).
   integer(int32),    intent(out), optional :: stat     !< Status.
   character(len=*),  intent(in),  optional :: ini_file !< File keeping the window layout (default: none).
   integer(c_int)                           :: status   !< Native status.
   integer(c_int)                           :: v        !< vsync flag.

   v = 1_c_int
   if (present(vsync)) v = merge(1_c_int, 0_c_int, vsync)
   status = fig_init(title, len(title, c_int), int(width, c_int), int(height, c_int), v)
   if (status == FIG_OK .and. present(ini_file)) status = fig_set_ini_file(ini_file, len(ini_file, c_int))
   call figure_check(status, stat)
   endsubroutine init

   subroutine init_headless(self, width, height, stat)
   !< Create the contexts on a virtual `width` x `height` display, without window or GPU.
   class(app_object), intent(inout)        :: self   !< Application.
   integer(int32),    intent(in)           :: width  !< Width [pixels].
   integer(int32),    intent(in)           :: height !< Height [pixels].
   integer(int32),    intent(out), optional :: stat  !< Status.
   integer(c_int)                          :: status !< Native status.

   status = fig_init_headless(int(width, c_int), int(height, c_int))
   call figure_check(status, stat)
   endsubroutine init_headless

   subroutine init_remote(self, port, host, width, height, port_used, quiet, max_fps, compress, token, url, stat)
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
   class(app_object), intent(inout)         :: self      !< Application.
   integer(int32),    intent(in),  optional :: port      !< Port (default 8080; 0: any free port).
   character(len=*),  intent(in),  optional :: host      !< Address to listen on (default 127.0.0.1).
   integer(int32),    intent(in),  optional :: width     !< Display width until the browser's [pixels] (default 1280).
   integer(int32),    intent(in),  optional :: height    !< Display height until the browser's [pixels] (default 800).
   integer(int32),    intent(out), optional :: port_used !< The port listened on (useful with port 0).
   logical,           intent(in),  optional :: quiet     !< Do not print the address to open (default false).
   real(real64),      intent(in),  optional :: max_fps   !< Most frames per second (default 60; 0: no cap).
   character(len=*),  intent(in),  optional :: compress  !< Deflate frames and textures: 'auto', 'always', 'never'.
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

   if (present(token)) then
      if (len(token) > len(tok) .or. verify(token, &
          'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~') /= 0) then ! safe in an address as it is
         call figure_fail(FIG_ERR_ARGUMENT, 'init_remote: token is at most 256 letters, digits or -._~', stat)
         return
      endif
   endif
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

   function next_frame(self, stat) result(running)
   !< Render the open frame (if any), then process input and open the next; `.false.` when the user quits.
   class(app_object), intent(inout)        :: self    !< Application.
   integer(int32),    intent(out), optional :: stat   !< Status.
   logical                                 :: running !< Keep looping.
   integer(c_int)                          :: status  !< Native status.
   integer(c_int)                          :: r       !< Running flag.

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
   call figure_check(status, stat)
   endfunction next_frame

   subroutine set_lazy(self, enabled, max_wait)
   !< Lazy redraw (default on): once the UI settles, sleep until input or `max_wait` seconds (default 0.5).
   class(app_object), intent(inout)      :: self     !< Application.
   logical,           intent(in)         :: enabled  !< Lazy redraw on.
   real(real64),      intent(in), optional :: max_wait !< Longest sleep [s]: the refresh period of live data.
   real(c_double)                        :: w        !< Longest sleep [s].

   w = 0.5_c_double
   if (present(max_wait)) w = real(max_wait, c_double)
   call fig_set_lazy(merge(1_c_int, 0_c_int, enabled), w)
   endsubroutine set_lazy

   subroutine set_style(self, name, lines, stat)
   !< Colours of the interface, the plots and the window background, by name, after `init*`:
   !<
   !< - `'seal'` (the default), `'seal-light'`: FIGURE's, from its mark: ink (or paper) and one vermilion, spent on
   !<   what the user touches and on the first plotted line; square corners;
   !< - `'paper'`: for publication, black on white, thin borders, line colours that survive greyscale printing;
   !< - `'high-contrast'`: white on black with yellow accents, text at 7:1 or more (WCAG AAA);
   !< - `'dark'`, `'light'`, `'classic'`: Dear ImGui's own styles, with ImPlot's default line colours.
   !<
   !< `lines='okabe-ito'` replaces the style's line colours with Okabe and Ito's colour-blind-safe set. Each style is
   !< a theme file (`themes/<name>.toml`, embedded). The environment variable `FIGURE_STYLE` picks the style at
   !< initialisation; this call overrides it. The font and its size are kept; every other colour and variable comes from
   !< the style (base and theme file), so changes made by name are reset.
   class(app_object), intent(inout)         :: self  !< Application.
   character(len=*),  intent(in)            :: name  !< Style name.
   character(len=*),  intent(in),  optional :: lines !< Line palette: `'okabe-ito'` (default: the style's own).
   integer(int32),    intent(out), optional :: stat  !< Status: `FIG_ERR_ARGUMENT` for an unknown name or palette.

   if (present(lines)) then
      call figure_check(fig_set_style(name, len(name, c_int), lines, len(lines, c_int)), stat)
   else
      call figure_check(fig_set_style(name, len(name, c_int), '', 0_c_int), stat)
   endif
   endsubroutine set_style

   subroutine set_font(self, font, size, stat)
   !< The default font of the interface, after `init*`: `'plex-sans'` (IBM Plex Sans, bundled: the default, at 15
   !< logical pixels), `'proggy'` (Dear ImGui's own 13-pixel bitmap font), or the path of a TrueType/OpenType file;
   !< `size` in logical pixels (multiplied by the display's content scale), kept if absent.
   class(app_object), intent(inout)         :: self !< Application.
   character(len=*),  intent(in)            :: font !< Font.
   real(real64),      intent(in),  optional :: size !< Size [logical pixels], in (0, 200].
   integer(int32),    intent(out), optional :: stat !< Status: `FIG_ERR_FAILED` if the file cannot be read,
                                                    !< `FIG_ERR_ARGUMENT` if it is not a font or the size is wrong.
   real(c_double)                           :: s    !< Size; 0: keep.

   s = 0.0_c_double
   if (present(size)) then
      if (.not. (size > 0.0_real64)) then
         call figure_fail(FIG_ERR_ARGUMENT, 'set_font: size must be in (0, 200] pixels', stat)
         return
      endif
      s = real(size, c_double)
   endif
   call figure_check(fig_set_font(font, len(font, c_int), s), stat)
   endsubroutine set_font

   subroutine load_style(self, file, stat)
   !< Apply a theme file (the format of the files in `themes/`: docs, Styles, Theme files), after `init*`. Sizes in the
   !< file are logical pixels; what the file does not set comes from its `base`.
   class(app_object), intent(inout)         :: self !< Application.
   character(len=*),  intent(in)            :: file !< Theme file.
   integer(int32),    intent(out), optional :: stat !< Status: `FIG_ERR_FAILED` if unreadable, `FIG_ERR_ARGUMENT` if
                                                    !< malformed (the message gives the line).

   call figure_check(fig_load_style(file, len(file, c_int)), stat)
   endsubroutine load_style

   subroutine save_style(self, file, stat)
   !< Write the style in effect as a theme file: its base, background, line colours, and every colour and variable
   !< that differs from the base (sizes in logical pixels; colours as 8-bit hex, alphas exact). Changes made by name
   !< or in the style editor (`ig_show_style_editor`) are kept; `load_style` reads the file back.
   class(app_object), intent(inout)         :: self !< Application.
   character(len=*),  intent(in)            :: file !< Theme file to write.
   integer(int32),    intent(out), optional :: stat !< Status: `FIG_ERR_FAILED` if it cannot be written.

   call figure_check(fig_save_style(file, len(file, c_int)), stat)
   endsubroutine save_style

   subroutine set_docking(self, enabled, stat)
   !< Docking on (the default since `init*`) or off: with docking on, a window dragged by its title bar docks into
   !< another window or into a dock space (`ig_dock_space`). After `init*`.
   class(app_object), intent(inout)         :: self    !< Application.
   logical,           intent(in)            :: enabled !< Docking on.
   integer(int32),    intent(out), optional :: stat    !< Status: `FIG_ERR_STATE` before `init*`.

   call figure_check(fig_set_docking(merge(1_c_int, 0_c_int, enabled)), stat)
   endsubroutine set_docking

   subroutine request_frames(self, n)
   !< Draw at least `n` more frames without waiting for input (e.g. after new data arrived).
   class(app_object), intent(inout) :: self !< Application.
   integer(int32),    intent(in)    :: n    !< Frames.

   call fig_request_frames(int(n, c_int))
   endsubroutine request_frames

   function content_scale(self) result(scale)
   !< Display content scale (1 standard, 2 on most high-DPI displays).
   class(app_object), intent(in) :: self  !< Application.
   real(real64)                  :: scale !< Scale.

   scale = real(fig_content_scale(), real64)
   endfunction content_scale

   subroutine destroy(self)
   !< Close the window and destroy the contexts (safe in any state).
   class(app_object), intent(inout) :: self !< Application.

   call fig_shutdown()
   self%in_frame = .false.
   endsubroutine destroy
endmodule figure_app
