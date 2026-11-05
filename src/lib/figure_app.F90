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
use figure_base, only : figure_check
use figure_c_native, only : FIG_OK, fig_begin_frame, fig_content_scale, fig_end_frame, fig_init, fig_init_headless, &
                            fig_init_remote, fig_request_frames, fig_set_docking, fig_set_ini_file, fig_set_lazy, &
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

   subroutine init_remote(self, port, host, width, height, port_used, quiet, stat)
   !< Create the contexts and serve the UI to a web browser on `http://host:port/` instead of opening a window: the
   !< program needs no display or GPU (a cluster node will do). One browser at a time, which can come and go while the
   !< program runs. There is no authentication: whoever reaches the port controls the program, so keep the default
   !< host (127.0.0.1) and reach a remote machine through an SSH tunnel (`ssh -L 8080:localhost:8080 node`).
   class(app_object), intent(inout)         :: self      !< Application.
   integer(int32),    intent(in),  optional :: port      !< Port (default 8080; 0: any free port).
   character(len=*),  intent(in),  optional :: host      !< Address to listen on (default 127.0.0.1).
   integer(int32),    intent(in),  optional :: width     !< Display width until the browser's [pixels] (default 1280).
   integer(int32),    intent(in),  optional :: height    !< Display height until the browser's [pixels] (default 800).
   integer(int32),    intent(out), optional :: port_used !< The port listened on (useful with port 0).
   logical,           intent(in),  optional :: quiet     !< Do not print the address to open (default false).
   integer(int32),    intent(out), optional :: stat      !< Status.
   integer(c_int)                           :: p         !< Requested port.
   integer(c_int)                           :: bound     !< Port listened on.
   integer(c_int)                           :: w         !< Display width.
   integer(c_int)                           :: h         !< Display height.
   integer(c_int)                           :: status    !< Native status.
   logical                                  :: talk      !< Print the address.

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
   talk = .true.
   if (present(quiet)) talk = .not. quiet
   if (status == FIG_OK .and. talk) then
      if (present(host)) then
         write(output_unit, '(A,A,A,I0,A)') 'FIGURE: open http://', trim(host), ':', bound, '/ in a web browser'
      else
         write(output_unit, '(A,I0,A)') 'FIGURE: open http://localhost:', bound, '/ in a web browser'
      endif
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

   subroutine set_style(self, name, stat)
   !< Colours of the interface, the plots and the window background, by name, after `init*`:
   !<
   !< - `'seal'` (the default), `'seal-light'`: FIGURE's, from its mark: ink (or paper) and one vermilion, spent on
   !<   what the user touches and on the first plotted line; square corners;
   !< - `'dark'`, `'light'`, `'classic'`: Dear ImGui's own styles, with ImPlot's default line colours.
   !<
   !< The environment variable `FIGURE_STYLE` picks the style at initialisation; this call overrides it. Sizes and
   !< fonts are kept; colours changed through the raw bindings are reset.
   class(app_object), intent(inout)         :: self   !< Application.
   character(len=*),  intent(in)            :: name   !< Style name.
   integer(int32),    intent(out), optional :: stat   !< Status: `FIG_ERR_ARGUMENT` for an unknown name.

   call figure_check(fig_set_style(name, len(name, c_int)), stat)
   endsubroutine set_style

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
