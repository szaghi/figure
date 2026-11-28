!< figure_plot_hooks, what FIGURE's other modules ask of the 2-D plots: the canvas's plot layer, the tests' queries.
module figure_plot_hooks
!< figure_plot_hooks, what FIGURE's other modules ask of the 2-D plots: the canvas's plot layer, the tests' queries.
!<
!< Part of the plot seam (szaghi/figure#15, the seam's switch), here over the Fortran plot frame: what figure_canvas
!< draws on its `'plot'` layer (`plot_layer_draw`: figure_plot_draw's `pf_draw_prim` in the frame's open plot) and what
!< figure_testing reads of the plots (`plot_tick_label`: `pf_tick_label`; the field textures of `ip_field_image`:
!< figure_plot_field's counters and colours). Arguments, results, statuses and messages are the native layer's, as the
!< current path's module of the same name (src/paths/imgui/plot/) gives them from ImPlot.
!<
!< Also: `plot_native_install`, what the path installs in the native layer before the app's contexts are made
!< (figure_app), szaghi/figure#15 G2 (option A): the 3-D views' colormaps (`fig_view3d_colormap_hooks`: a mesh's map
!< checked and its 256 colours taken from FIGURE's registry, figure_plot_colormaps, the only one on this path; its
!< edits counted by `cm_generation`) and the plots' styles (`fig_plot_style_hooks`: the stores of figure_plot_style and
!< figure_plot3d_style, which the native layer's style functions read and change, ImPlot's defaults at each `init`);
!< and the registry as the tests read it (`plot_colormap_count`, `plot_colormap_size`, `plot_colormap_color`,
!< `plot_colormap_sample`, as the current path's from ImPlot's).
use, intrinsic :: iso_c_binding, only : c_associated, c_char, c_double, c_float, c_funloc, c_funptr, c_f_pointer, c_int, &
                                        c_long_long, c_ptr, c_signed_char
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use figure_base, only : figure_fail
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK
use figure_plot_colormaps, only : cm_colormap, cm_count, cm_generation, cm_key, cm_sample, cm_size
use figure_plot_draw, only : pf_draw_prim
use figure_plot_field, only : field_count, field_pixel, field_time, field_uploads
use figure_plot_frame, only : pf_plot_state, pf_tick_label
use figure_plot_style, only : ps_color_named, ps_pop_color, ps_pop_var, ps_push_named, ps_reset, ps_theme, ps_var_named
use figure_plot3d_style, only : pf3_pop_style_color, pf3_pop_style_var, ps3_color_named, ps3_push_named, ps3_reset, &
                                ps3_var_named

implicit none
private
public :: plot_layer_draw, plot_tick_label, plot_field_uploads, plot_field_count, plot_field_time, plot_field_pixel
public :: plot_native_install, plot_colormap_count, plot_colormap_size, plot_colormap_color, plot_colormap_sample

character(len=2), parameter :: AXIS_NAMES(0:5) = ['x1', 'x2', 'x3', 'y1', 'y2', 'y3'] !< ImAxis names.

interface
   subroutine fig_view3d_colormap_hooks(table, generation) bind(C, name='fig_view3d_colormap_hooks')
   !< The 3-D views' colormaps from FIGURE's registry (native/figure_view3d.h): `table(name, name_len, rgb)` checks a
   !< map (and gives its 256 colours, bytes RGB, when `rgb` is not null), `generation()` counts its edits.
   import :: c_funptr
   implicit none
   type(c_funptr), value :: table      !< `int (*)(const char *name, int name_len, unsigned char *rgb)`.
   type(c_funptr), value :: generation !< `unsigned (*)(void)`.
   endsubroutine fig_view3d_colormap_hooks

   subroutine fig_plot_style_hooks(color, var, push, pop, theme) bind(C, name='fig_plot_style_hooks')
   !< The plots' styles in Fortran (native/figure_native.h): the store the native layer's style functions read and
   !< every change reaches.
   import :: c_funptr
   implicit none
   type(c_funptr), value :: color !< `int (*)(int lib, const char *name, int name_len, int mode, float *rgba)`.
   type(c_funptr), value :: var   !< `int (*)(int lib, const char *name, int name_len, int set, double *v, int *n)`.
   type(c_funptr), value :: push  !< `int (*)(int lib, int vars, const char *name, int name_len, const double *v, int n)`.
   type(c_funptr), value :: pop   !< `void (*)(int lib, int vars)`.
   type(c_funptr), value :: theme !< `int (*)(int op, const char *name, int name_len, const double *v, int n)`.
   endsubroutine fig_plot_style_hooks
endinterface

integer(int32), parameter :: NAME_MAX = 64_int32 !< A style name's length at most (the longest is 18).

contains
   subroutine plot_native_install()
   !< Install the path's plot hooks in the native layer, before the app's contexts are made: the 3-D views' colormaps,
   !< the plots' styles (ImPlot's and ImPlot3D's defaults, as a new context has them).
   call fig_view3d_colormap_hooks(c_funloc(view3d_table), c_funloc(view3d_generation))
   call ps_reset()
   call ps3_reset()
   call fig_plot_style_hooks(c_funloc(style_color), c_funloc(style_var), c_funloc(style_push), c_funloc(style_pop), &
                             c_funloc(style_theme))
   endsubroutine plot_native_install

   function style_color(lib, name, name_len, mode, rgba) result(status) bind(C)
   !< A colour of the plots' styles by name (`fig_style_color`): mode 0 resolved, 1 set, 2 as stored; 0, or 1 for an
   !< unknown name.
   integer(c_int),         value         :: lib      !< 1 ImPlot's, 2 ImPlot3D's.
   character(kind=c_char), intent(in)    :: name(*)  !< Name (not NUL-terminated).
   integer(c_int),         value         :: name_len !< Its length [bytes].
   integer(c_int),         value         :: mode     !< 0 resolved, 1 set, 2 as stored.
   real(c_float),          intent(inout) :: rgba(4)  !< Colour.
   integer(c_int)                        :: status   !< Status.
   character(len=NAME_MAX)               :: n        !< The name.
   integer(int32)                        :: l, st    !< Its length, status.

   call name_of(name, name_len, n, l)
   if (lib == 1_c_int) then
      call ps_color_named(n(1:l), int(mode, int32), rgba, st)
   else
      call ps3_color_named(n(1:l), int(mode, int32), rgba, st)
   endif
   status = int(st, c_int)
   endfunction style_color

   function style_var(lib, name, name_len, set, values, count) result(status) bind(C)
   !< A variable of the plots' styles by name (`fig_style_var`; ImPlot3D's read only): 0, 1 for an unknown name, 2 for
   !< a wrong count (`count` the right one).
   integer(c_int),         value         :: lib       !< 1 ImPlot's, 2 ImPlot3D's.
   character(kind=c_char), intent(in)    :: name(*)   !< Name (not NUL-terminated).
   integer(c_int),         value         :: name_len  !< Its length [bytes].
   integer(c_int),         value         :: set       !< 0 get, 1 set.
   real(c_double),         intent(inout) :: values(2) !< Values.
   integer(c_int),         intent(inout) :: count     !< Values given or taken.
   integer(c_int)                        :: status    !< Status.
   character(len=NAME_MAX)               :: n         !< The name.
   integer(int32)                        :: l, st, c  !< Its length, status, count.

   call name_of(name, name_len, n, l)
   c = int(count, int32)
   if (lib == 1_c_int) then
      call ps_var_named(n(1:l), int(set, int32), values, c, st)
   else
      call ps3_var_named(n(1:l), values, c, st)
   endif
   count = int(c, c_int)
   status = int(st, c_int)
   endfunction style_var

   function style_push(lib, vars, name, name_len, values, count) result(status) bind(C)
   !< A push of the plots' styles by name (`fig_push_style_color`, vars 0, rgba; `fig_push_style_var`, vars 1): 0, 1
   !< for an unknown name, 2 for a wrong count.
   integer(c_int),         value      :: lib       !< 1 ImPlot's, 2 ImPlot3D's.
   integer(c_int),         value      :: vars      !< 1 a variable, 0 a colour.
   character(kind=c_char), intent(in) :: name(*)   !< Name (not NUL-terminated).
   integer(c_int),         value      :: name_len  !< Its length [bytes].
   real(c_double),         intent(in) :: values(*) !< Values (`count`).
   integer(c_int),         value      :: count     !< Their number.
   integer(c_int)                     :: status    !< Status.
   character(len=NAME_MAX)            :: n         !< The name.
   integer(int32)                     :: l, st     !< Its length, status.

   call name_of(name, name_len, n, l)
   if (count < 1_c_int .or. count > 4_c_int) then
      status = 2_c_int
      return
   endif
   if (lib == 1_c_int) then
      call ps_push_named(vars /= 0_c_int, n(1:l), values(1:count), int(count, int32), st)
   else
      call ps3_push_named(vars /= 0_c_int, n(1:l), values(1:count), int(count, int32), st)
   endif
   status = int(st, c_int)
   endfunction style_push

   subroutine style_pop(lib, vars) bind(C)
   !< The newest push of a plot style's colours (vars 0) or variables (vars 1) undone (`fig_pop_style`).
   integer(c_int), value :: lib  !< 1 ImPlot's, 2 ImPlot3D's.
   integer(c_int), value :: vars !< 1 a variable, 0 a colour.

   if (lib == 1_c_int) then
      if (vars /= 0_c_int) then
         call ps_pop_var(1_int32)
      else
         call ps_pop_color(1_int32)
      endif
   else
      if (vars /= 0_c_int) then
         call pf3_pop_style_var(1_int32)
      else
         call pf3_pop_style_color(1_int32)
      endif
   endif
   endsubroutine style_pop

   function style_theme(op, name, name_len, values, count) result(status) bind(C)
   !< One step of a style's ImPlot part at its commit (`commit_style`; figure_plot_style's `ps_theme`): 0, 1 for an
   !< unknown name, 2 for a wrong count.
   integer(c_int),         value      :: op        !< Step (1-7).
   character(kind=c_char), intent(in) :: name(*)   !< Name (not NUL-terminated; ops 5, 6).
   integer(c_int),         value      :: name_len  !< Its length [bytes].
   real(c_double),         intent(in) :: values(*) !< Values (`count`; ops 5, 6).
   integer(c_int),         value      :: count     !< Their number.
   integer(c_int)                     :: status    !< Status.
   character(len=NAME_MAX)            :: n         !< The name.
   integer(int32)                     :: l, st     !< Its length, status.
   real(real64)                       :: none(0)   !< No values.

   call name_of(name, name_len, n, l)
   if (count > 0_c_int) then
      call ps_theme(int(op, int32), n(1:l), values(1:count), st)
   else
      call ps_theme(int(op, int32), n(1:l), none, st)
   endif
   status = int(st, c_int)
   endfunction style_theme

   subroutine name_of(name, name_len, n, l)
   !< A C name into a buffer (no allocation); a name longer than the buffer is cut (no style name is).
   character(kind=c_char), intent(in)  :: name(*)  !< Name (not NUL-terminated).
   integer(c_int),         intent(in)  :: name_len !< Its length [bytes].
   character(len=NAME_MAX), intent(out) :: n       !< Buffer.
   integer(int32),         intent(out) :: l        !< Length used.
   integer(int32)                      :: k        !< Counter.

   l = min(max(int(name_len, int32), 0_int32), NAME_MAX)
   do k = 1_int32, l
      n(k:k) = name(k)
   enddo
   endsubroutine name_of

   function view3d_table(name, name_len, rgb) result(status) bind(C)
   !< A 3-D view's colormap by name (`fig_view3d_style`, `load_table`): registered as `ip_colormap` registers it,
   !< FIG_OK; its 256 colours into `rgb` (when not null) as the native layer samples them (`SampleColormap` at k / 255,
   !< in float: the packed colour's bytes); `FIG_ERR_ARGUMENT` for an unknown name, `fig_colormap`'s message set.
   character(kind=c_char), intent(in) :: name(*)  !< Name (not NUL-terminated).
   integer(c_int),         value      :: name_len !< Its length [bytes].
   type(c_ptr),            value      :: rgb      !< 768 bytes, RGB per colour, or null.
   integer(c_int)                     :: status   !< Status.
   character(len=max(name_len, 0_c_int)) :: n     !< The name.
   integer(c_signed_char), pointer    :: px(:)    !< The colours.
   integer(int32)                     :: id, k, c, v !< Map, colour, channel, byte.
   integer(int32)                     :: col      !< Packed colour.
   integer(int32)                     :: st       !< `figure_fail`'s status (the message set).

   do k = 1_int32, len(n, int32)
      n(k:k) = name(k)
   enddo
   id = cm_colormap(n)
   if (id < 0_int32) then
      call figure_fail(FIG_ERR_ARGUMENT, "ip_colormap: unknown colormap '"//n//"' (ip_colormap_names lists them)", st)
      status = FIG_ERR_ARGUMENT
      return
   endif
   status = FIG_OK
   if (.not. c_associated(rgb)) return
   call c_f_pointer(rgb, px, [768])
   do k = 0_int32, 255_int32
      col = cm_sample(id, real(k, real32) / 255.0_real32)
      do c = 0_int32, 2_int32
         v = int(iand(ishft(int(col, int64), -8_int64 * int(c, int64)), 255_int64), int32)
         if (v > 127_int32) v = v - 256_int32
         px(3_int32 * k + c + 1_int32) = int(v, c_signed_char)
      enddo
   enddo
   endfunction view3d_table

   function view3d_generation() result(g) bind(C)
   !< The registry's edits so far (`fig_colormap_generation`'s): a view colours its meshes again when it changes.
   integer(c_int) :: g !< Edits.

   g = int(cm_generation(), c_int)
   endfunction view3d_generation

   function plot_colormap_count() result(n)
   !< The colormaps registered (`cm_count`, as `ImPlot::GetColormapCount`).
   integer(int32) :: n !< Maps.

   n = cm_count()
   endfunction plot_colormap_count

   function plot_colormap_size(id) result(n)
   !< A colormap's keys (`cm_size`, as `ImPlot::GetColormapSize`).
   integer(int32), intent(in) :: id !< Colormap id (`ip_colormap`).
   integer(int32)             :: n  !< Keys.

   n = cm_size(id)
   endfunction plot_colormap_size

   subroutine plot_colormap_color(id, idx, rgba)
   !< A colormap's key `idx` (0-based, modulo the keys; `cm_key` unpacked as `ImPlot::GetColormapColor`).
   integer(int32), intent(in)  :: id      !< Colormap id (`ip_colormap`).
   integer(int32), intent(in)  :: idx     !< Key.
   real(real32),   intent(out) :: rgba(4) !< Colour.

   call unpack(cm_key(id, idx), rgba)
   endsubroutine plot_colormap_color

   subroutine plot_colormap_sample(id, t, rgba)
   !< A colormap's colour at `t` in [0, 1] (`cm_sample` unpacked, as `ImPlot::SampleColormap`).
   integer(int32), intent(in)  :: id      !< Colormap id (`ip_colormap`).
   real(real32),   intent(in)  :: t       !< Position.
   real(real32),   intent(out) :: rgba(4) !< Colour.

   call unpack(cm_sample(id, t), rgba)
   endsubroutine plot_colormap_sample

   subroutine unpack(col, rgba)
   !< A packed colour as floats (`ColorConvertU32ToFloat4`: each byte times 1/255, in float).
   integer(int32), intent(in)  :: col     !< Packed colour.
   real(real32),   intent(out) :: rgba(4) !< Colour.
   integer(int32)              :: c       !< Channel.

   do c = 0_int32, 3_int32
      rgba(c + 1_int32) = real(iand(ishft(int(col, int64), -8_int64 * int(c, int64)), 255_int64), real32) * &
                          (1.0_real32 / 255.0_real32)
   enddo
   endsubroutine unpack

   function plot_layer_draw(kind, x, y, n, rgba, thickness, radius, filled, text, text_len, texture) result(status)
   !< One drawing primitive in the plot being declared, in plot units (`fig_draw` on the plot layer): FIG_OK, -1
   !< outside a plot.
   integer(c_int),         intent(in) :: kind      !< 1 line, 2 rect, 3 circle, 4 polyline, 5 polygon, 6 text, 7 image.
   real(c_double),         intent(in) :: x(*)      !< Abscissae [plot units].
   real(c_double),         intent(in) :: y(*)      !< Ordinates [plot units].
   integer(c_int),         intent(in) :: n         !< Points.
   real(c_double),         intent(in) :: rgba(4)   !< Colour, RGBA in [0, 1].
   real(c_double),         intent(in) :: thickness !< Line thickness [pixels].
   real(c_double),         intent(in) :: radius    !< A circle's radius [pixels].
   integer(c_int),         intent(in) :: filled    !< 1: filled (a polyline: closed).
   character(kind=c_char, len=*), intent(in) :: text !< Text (its first `text_len` characters).
   integer(c_int),         intent(in) :: text_len  !< Its length [bytes].
   integer(c_long_long),   intent(in) :: texture   !< ImTextureID (an image).
   integer(c_int)                     :: status    !< Status.

   status = pf_draw_prim(kind, x(1:n), y(1:n), rgba, thickness, radius, filled /= 0_c_int, text(1:text_len), &
                         int(texture, int64))
   endfunction plot_layer_draw

   function plot_tick_label(axis, index, buf, buf_len, count, label_len) result(status)
   !< A tick label of the plot being declared (`test_plot_tick`, as `fig_plot_tick_label`): the axis (ImAxis, -1
   !< unknown), the tick (from 1); the label into `buf`, the ticks on the axis.
   integer(c_int),                intent(in)  :: axis      !< An ImAxis: 0-2 X1-X3, 3-5 Y1-Y3.
   integer(c_int),                intent(in)  :: index     !< Tick, from 1.
   character(kind=c_char, len=*), intent(out) :: buf       !< Label.
   integer(c_int),                intent(in)  :: buf_len   !< Buffer length.
   integer(c_int),                intent(out) :: count     !< Ticks on the axis.
   integer(c_int),                intent(out) :: label_len !< Length of the label.
   integer(c_int)                             :: status    !< Status.
   integer(int32)                             :: en(6), sc(6) !< The plot's axes.
   integer(int32)                             :: c, l      !< Count, length.
   integer(int32)                             :: st        !< `figure_fail`'s status (the message set; the
                                                           !< caller acts on the status returned, as on the native
                                                           !< layer's).

   count = 0_c_int
   label_len = 0_c_int
   if (pf_plot_state(en, sc) == 0_int32) then
      call figure_fail(FIG_ERR_STATE, 'test_plot_tick: no plot is being declared (between ip_begin_plot and '// &
                       'ip_end_plot)', st)
      status = FIG_ERR_STATE
      return
   endif
   if (axis < 0_c_int .or. axis > 5_c_int) then
      call figure_fail(FIG_ERR_ARGUMENT, "test_plot_tick: unknown axis ('x1', 'x2', 'x3', 'y1', 'y2', 'y3', 'x' or "// &
                       "'y')", st)
      status = FIG_ERR_ARGUMENT
      return
   endif
   if (en(axis + 1_c_int) == 0_int32) then
      call figure_fail(FIG_ERR_STATE, "test_plot_tick: axis '"//AXIS_NAMES(axis)//"' is not set up (ip_setup_axis('"// &
                       AXIS_NAMES(axis)//"'))", st)
      status = FIG_ERR_STATE
      return
   endif
   call pf_tick_label(int(axis, int32) + 1_int32, int(index, int32), buf(1:max(buf_len, 0_c_int)), c, l)
   count = int(c, c_int)
   label_len = int(l, c_int)
   status = FIG_OK
   endfunction plot_tick_label

   function plot_field_uploads() result(n)
   !< Field colourings uploaded since the start (`test_field_uploads`).
   integer(c_long_long) :: n !< Uploads.

   n = int(field_uploads(), c_long_long)
   endfunction plot_field_uploads

   function plot_field_count() result(n)
   !< Field textures cached (`test_field_textures`).
   integer(c_int) :: n !< Entries.

   n = int(field_count(), c_int)
   endfunction plot_field_count

   function plot_field_time() result(ms)
   !< The last field colouring's time, upload included [ms] (`test_field_time`).
   real(c_double) :: ms !< Time [ms].

   ms = real(field_time(), c_double)
   endfunction plot_field_time

   function plot_field_pixel(label, label_len, i, j, rgba) result(status)
   !< The colour of the field `label`'s value (i, j), as coloured last (`test_field_pixel`, as `fig_field_pixel`).
   character(kind=c_char, len=*), intent(in)  :: label     !< Label (its first `label_len` characters).
   integer(c_int),                intent(in)  :: label_len !< Its length [bytes].
   integer(c_int),                intent(in)  :: i         !< Index along x (1-based).
   integer(c_int),                intent(in)  :: j         !< Index along y (1-based).
   real(c_float),                 intent(out) :: rgba(4)   !< Colour, RGBA in [0, 1].
   integer(c_int)                             :: status    !< Status.
   real(real32)                               :: c(4)      !< Colour.
   integer(int32)                             :: s         !< The field's status.
   integer(int32)                             :: st        !< `figure_fail`'s status (the message set).

   s = field_pixel(label(1:max(label_len, 0_c_int)), int(i, int32), int(j, int32), c)
   rgba = real(c, c_float)
   select case (s)
   case (0_int32)
      status = FIG_OK
   case (1_int32)
      call figure_fail(FIG_ERR_ARGUMENT, 'test_field_pixel: pixel out of the field', st)
      status = FIG_ERR_ARGUMENT
   case default
      call figure_fail(FIG_ERR_ARGUMENT, "test_field_pixel: no field '"//label(1:max(label_len, 0_c_int))// &
                       "' is cached", st)
      status = FIG_ERR_ARGUMENT
   endselect
   endfunction plot_field_pixel
endmodule figure_plot_hooks
