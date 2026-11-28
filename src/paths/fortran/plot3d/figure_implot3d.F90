!< figure_implot3d, small 3-D figures with Fortran arrays, on the Fortran path: drawn by the Fortran 3-D plot frame.
module figure_implot3d
!< figure_implot3d, small 3-D figures with Fortran arrays, on the Fortran path: drawn by the Fortran 3-D plot frame.
!<
!< The Fortran path's implementation of the 3-D plot seam (szaghi/figure#15, the 3-D seam's switch): the same module
!< name, public API (`ip3_*`, `plot3d_spec_object`, ImPlot3D's constants), statuses and messages as the current path's
!< (src/paths/imgui/plot3d/figure_implot3d.F90, over ImPlot3D), each procedure checking its arguments as there, in the
!< same order, then drawing with the Fortran 3-D plot frame (src/paths/fortran/plot3d/: figure_plot3d_frame,
!< figure_plot3d_items, figure_plot3d_style), which reproduces ImPlot3D's pictures and behaviour (README there). What
!< the current path asks of the native layer is here the frame's: the scope record's 3-D plot (figure_plot_scope's
!< hooks), `fig_plot3d_state`, `fig_plot3d_axis_format`, `fig_plot3d_mouse_ray` (`pf3_*`); the colormaps
!< (`fig_plot3d_colormap`: the ids of `ip_colormap` are FIGURE's registry's, figure_plot_colormaps, the frame's own,
!< szaghi/figure#15 G2); FIGURE's ImPlot3D style
!< (`ip3_push_style_*`, figure_style's, on its one native stack), the frame's own store (figure_plot3d_style), which
!< the native layer's hooks keep current. `test_plot_copies` and `test_plot_stride` count what the current path copies
!< and the stride it gives ImPlot3D (the frame reads every array in place).
!<
!< `ip3_begin_plot` returns true when the plot is visible: then declare its axes (`ip3_setup_axes`) and items, and close
!< it with `ip3_end_plot` (only in that case). Items (`ip3_line`, `ip3_scatter`, `ip3_surface`, `ip3_mesh`) take
!< `real(real32)` or `real(real64)` arrays of any stride, read in place during the call (the dummies are ASYNCHRONOUS).
!< Every item takes an optional `spec`, built by `ip3_spec` from ImPlot3D's defaults. A surface is coloured by FIGURE's
!< colormaps (`ip_colormap`), followed when `ig_gradient_edit` changes them.
!<
!< Every procedure refuses a call from a task and a call with no frame open (`FIG_ERR_STATE`); an item or `ip3_text`
!< outside a 3-D plot, and `ip3_setup_axes` after the plot's first item, are usage errors (`FIG_ERR_STATE`, as
!< `app%set_checks` says). The begin/end pair registers in the scope record of the frame (errors.md, "Pairing and
!< frames").
use, intrinsic :: iso_c_binding, only : c_int, c_loc
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use, intrinsic :: ieee_arithmetic, only : ieee_is_finite, ieee_is_nan
use figure_base, only : figure_check, figure_draw_refused, figure_fail, figure_scope_open, figure_scope_refused, &
                        figure_usage_error, SCOPE_PLOT3D, FORMAT_REAL, format_refused
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_OK
use figure_texture, only : texture_object
use figure_cimplot_enums, only : ImPlotColormap_Viridis
use figure_cimplot3d_enums, only : ImPlot3DMarker_None, ImPlot3DMarker_Auto, ImPlot3DMarker_Circle,              &
                                   ImPlot3DMarker_Square, ImPlot3DMarker_Diamond, ImPlot3DMarker_Up,             &
                                   ImPlot3DMarker_Down, ImPlot3DMarker_Left, ImPlot3DMarker_Right,               &
                                   ImPlot3DMarker_Cross, ImPlot3DMarker_Plus, ImPlot3DMarker_Asterisk,           &
                                   ImPlot3DItemFlags_None, ImPlot3DItemFlags_NoLegend, ImPlot3DItemFlags_NoFit,  &
                                   ImPlot3DLineFlags_Segments, ImPlot3DLineFlags_Loop, ImPlot3DLineFlags_SkipNaN, &
                                   ImPlot3DSurfaceFlags_NoLines, ImPlot3DSurfaceFlags_NoFill,                    &
                                   ImPlot3DSurfaceFlags_NoMarkers, ImPlot3DMeshFlags_NoLines,                    &
                                   ImPlot3DMeshFlags_NoFill, ImPlot3DMeshFlags_NoMarkers
use figure_plot_series, only : plot_copies, plot_stride, series_gap
use figure_plot3d_series, only : grid_ok, per_point_ok, rgba_ok
use figure_plot_colormaps, only : cm_count, cm_style_refresh
use figure_plot_scope, only : plot_path_ready
use figure_plot3d_frame, only : pf3_begin_plot, pf3_end_plot, pf3_mouse_ray, pf3_plot_state, pf3_plot_to_pixels, &
                                pf3_setup_axes, pf3_setup_axis, pf3_setup_axis_ticks, pf3_setup_box, pf3_setup_legend, &
                                pf3_text
use figure_plot3d_items, only : plot3d_spec, pf3_spec, pf3_image, pf3_line, pf3_mesh, pf3_quads, pf3_scatter, &
                                pf3_surface, pf3_triangles

implicit none
private
public :: ip3_begin_plot, ip3_end_plot, ip3_setup_axes, ip3_line, ip3_scatter, ip3_surface, ip3_mesh, ip3_text
public :: ip3_spec, plot3d_spec_object
public :: ip3_triangles, ip3_quads, ip3_image, ip3_setup_axis, ip3_setup_box, ip3_setup_legend, ip3_mouse_ray
public :: ip3_setup_axis_ticks
public :: ip3_plot_to_pixels
! ImPlot3D's marker and item-flag constants (values generated from the cimplot3d metadata), for `ip3_spec`
public :: ImPlot3DMarker_None, ImPlot3DMarker_Auto, ImPlot3DMarker_Circle, ImPlot3DMarker_Square
public :: ImPlot3DMarker_Diamond, ImPlot3DMarker_Up, ImPlot3DMarker_Down, ImPlot3DMarker_Left, ImPlot3DMarker_Right
public :: ImPlot3DMarker_Cross, ImPlot3DMarker_Plus, ImPlot3DMarker_Asterisk
public :: ImPlot3DItemFlags_None, ImPlot3DItemFlags_NoLegend, ImPlot3DItemFlags_NoFit
public :: ImPlot3DLineFlags_Segments, ImPlot3DLineFlags_Loop, ImPlot3DLineFlags_SkipNaN
public :: ImPlot3DSurfaceFlags_NoLines, ImPlot3DSurfaceFlags_NoFill, ImPlot3DSurfaceFlags_NoMarkers
public :: ImPlot3DMeshFlags_NoLines, ImPlot3DMeshFlags_NoFill, ImPlot3DMeshFlags_NoMarkers

type :: plot3d_spec_object
   !< Style of a 3-D plot item: colours, line weight, markers, flags. Build it with `ip3_spec`.
   !<
   !< The style is private so that a spec always starts from ImPlot3D's defaults (a zeroed one draws nothing).
   type(plot3d_spec), private :: s !< The frame's item style (figure_plot3d_items).
endtype plot3d_spec_object

interface ip3_triangles
   !< Triangles: each three points (x(i), y(i), z(i)) in a row are one.
   module procedure ip3_triangles_r32, ip3_triangles_r64
endinterface ip3_triangles

interface ip3_quads
   !< Quadrilaterals: each four points in a row are one.
   module procedure ip3_quads_r32, ip3_quads_r64
endinterface ip3_quads

interface ip3_line
   !< A line through the points (x(i), y(i), z(i)).
   module procedure ip3_line_r32, ip3_line_r64
endinterface ip3_line

interface ip3_scatter
   !< Markers at the points (x(i), y(i), z(i)).
   module procedure ip3_scatter_r32, ip3_scatter_r64
endinterface ip3_scatter

interface ip3_surface
   !< A surface z(i, j) over a grid: x(i), y(j) (a rectilinear grid) or x(i, j), y(i, j) (any grid of quadrilaterals).
   module procedure ip3_surface_r32, ip3_surface_r64, ip3_surface_grid_r32, ip3_surface_grid_r64
endinterface ip3_surface

interface ip3_mesh
   !< A mesh of triangles: vertices (x(i), y(i), z(i)), triangles(:, k) the vertices of the k-th (from 1).
   module procedure ip3_mesh_r32, ip3_mesh_r64
endinterface ip3_mesh

contains
   ! plots

   recursive function ip3_begin_plot(title, width, height, equal) result(visible)
   !< Begin a 3-D plot; if true, declare its content and call `ip3_end_plot`.
   character(len=*), intent(in)           :: title   !< Title (also the plot id; '##id' hides it).
   real(real64),     intent(in), optional :: width   !< Width [pixels] (default: full width).
   real(real64),     intent(in), optional :: height  !< Height [pixels] (default: ImPlot3D's).
   logical,          intent(in), optional :: equal   !< Same scale on the three axes (one unit as many pixels).
   logical                                :: visible !< Plot visible.

   visible = .false.
   if (entry_refused('ip3_begin_plot')) return ! a task does not draw
   visible = pf3_begin_plot(title, width, height, equal)
   call figure_scope_open(SCOPE_PLOT3D, 'ip3_begin_plot', title, visible)
   endfunction ip3_begin_plot

   recursive subroutine ip3_end_plot()
   !< End the 3-D plot (only after `ip3_begin_plot` returned true).

   if (figure_scope_refused(SCOPE_PLOT3D, 'ip3_end_plot')) return ! a task, no frame, or not the innermost scope
   call plot_path_ready()
   call pf3_end_plot()
   endsubroutine ip3_end_plot

   recursive subroutine ip3_setup_axes(xlabel, ylabel, zlabel, auto_fit, limits, elevation, azimuth, stat)
   !< Labels of the three axes (call right after `ip3_begin_plot`, before any item); with `auto_fit=.true.` the axes
   !< fit the data every frame, instead of once on first use. `limits` = [xmin, xmax, ymin, ymax, zmin, zmax]: the
   !< initial ranges (set once; the user zooms and pans from them). `elevation` and `azimuth` [degrees], both or
   !< neither: the initial rotation of the box (set once; a right double click goes back to it). Statuses:
   !< `FIG_ERR_ARGUMENT` for `limits` of size /= 6 or with a minimum not below its maximum, or one angle without the
   !< other (nothing is set up); `FIG_ERR_STATE` outside a 3-D plot, after its first item, or from a task.
   character(len=*), intent(in)            :: xlabel    !< X label.
   character(len=*), intent(in)            :: ylabel    !< Y label.
   character(len=*), intent(in)            :: zlabel    !< Z label.
   logical,          intent(in),  optional :: auto_fit  !< Fit the axes to the data every frame (default: first use).
   real(real64),     intent(in),  optional :: limits(:) !< Initial ranges [xmin, xmax, ymin, ymax, zmin, zmax].
   real(real64),     intent(in),  optional :: elevation !< Initial elevation [degrees].
   real(real64),     intent(in),  optional :: azimuth   !< Initial azimuth [degrees].
   integer(int32),   intent(out), optional :: stat      !< Status.

   if (entry_refused('ip3_setup_axes', stat)) return ! a task does not draw
   if (present(limits)) then
      if (size(limits) /= 6) then
         call figure_fail(FIG_ERR_ARGUMENT, 'ip3_setup_axes: limits needs 6 values (xmin, xmax, ymin, ymax, zmin, zmax)', &
                          stat)
         return
      endif
      if (.not. (limits(1) < limits(2) .and. limits(3) < limits(4) .and. limits(5) < limits(6))) then
         call figure_fail(FIG_ERR_ARGUMENT, 'ip3_setup_axes: each minimum of limits must be below its maximum', stat)
         return
      endif
   endif
   if (present(elevation) .neqv. present(azimuth)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip3_setup_axes: give both elevation and azimuth, or neither', stat)
      return
   endif
   select case (pf3_plot_state())
   case (0_int32)
      call figure_usage_error('ip3_setup_axes: no 3-D plot is being declared (call it after ip3_begin_plot returned '// &
                              'true)', stat)
      return
   case (2_int32)
      call figure_usage_error('ip3_setup_axes: the setup of the 3-D plot is over (call it before the first item)', stat)
      return
   endselect
   call pf3_setup_axes(xlabel, ylabel, zlabel, auto_fit, limits, elevation, azimuth)
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_setup_axes

   function ip3_spec(line_color, line_weight, fill_color, fill_alpha, marker, marker_size, marker_line_color, &
                     marker_fill_color, flags, stat) result(spec)
   !< 3-D item style: ImPlot3D's defaults, with the given properties overridden. Colours are RGBA in [0, 1]; an absent
   !< colour stays automatic (the next colour of the colormap; a surface's fill: its colormap).
   real(real64),   intent(in), optional  :: line_color(:)        !< Line colour, RGBA.
   real(real64),   intent(in), optional  :: line_weight          !< Line weight [pixels] (lines, edges, markers).
   real(real64),   intent(in), optional  :: fill_color(:)        !< Fill colour, RGBA (surfaces, meshes: one colour).
   real(real64),   intent(in), optional  :: fill_alpha           !< Alpha multiplier of the fill colours.
   integer(int32), intent(in), optional  :: marker               !< Marker shape (`ImPlot3DMarker_*`).
   real(real64),   intent(in), optional  :: marker_size          !< Marker radius [pixels].
   real(real64),   intent(in), optional  :: marker_line_color(:) !< Marker outline colour, RGBA.
   real(real64),   intent(in), optional  :: marker_fill_color(:) !< Marker fill colour, RGBA.
   integer(int32), intent(in), optional  :: flags                !< Item flags (`ImPlot3DItemFlags_*`, the item's own).
   integer(int32), intent(out), optional :: stat                 !< Status: `FIG_ERR_ARGUMENT` for a colour of size /= 4.
   type(plot3d_spec_object)              :: spec                 !< Item style.

   if (.not. (rgba_ok(line_color) .and. rgba_ok(fill_color) .and. rgba_ok(marker_line_color) .and. &
              rgba_ok(marker_fill_color))) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip3_spec: a colour needs 4 components (RGBA)', stat)
      return
   endif
   spec%s = pf3_spec(line_color, line_weight, fill_color, fill_alpha, marker, marker_size, marker_line_color, &
                     marker_fill_color, flags)
   call figure_check(FIG_OK, stat)
   endfunction ip3_spec

   ! items

   recursive subroutine ip3_line_r32(label, x, y, z, spec, colors, stat)
   !< A line through the points (x(i), y(i), z(i)), single precision; read in place with any stride. `colors`: the
   !< segment from point i in `colors(:, i)` (RGBA in [0, 1]). Statuses: `FIG_ERR_ARGUMENT` for series of different
   !< sizes, colours not (4, size(x)) or out of [0, 1]; `FIG_ERR_STATE` outside a 3-D plot, from a task.
   character(len=*),         intent(in)                       :: label !< Legend label.
   real(real32),             intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),             intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real32),             intent(in), target, asynchronous :: z(:)  !< Heights.
   type(plot3d_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot3D's).
   real(real64),             intent(in), optional             :: colors(:,:) !< Per-point RGBA, (4, size(x)).
   integer(int32),           intent(out), optional            :: stat  !< Status.
   integer(int64)                                             :: s     !< The stride ImPlot3D would read [bytes].

   if (item_refused('ip3_line', size(x, kind=int64), size(y, kind=int64), size(z, kind=int64), stat)) return
   if (.not. per_point_ok('ip3_line', size(x, kind=int64), colors, stat=stat)) return
   call acct_lead_r32(s, x)
   call acct_put_r32(s, y)
   call acct_put_r32(s, z)
   plot_stride = s
   call pf3_line(label, x, y, z, spec=item_spec(spec), colors=colors)
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_line_r32

   recursive subroutine ip3_line_r64(label, x, y, z, spec, colors, stat)
   !< A line through the points (x(i), y(i), z(i)), double precision; read in place with any stride. `colors`: the
   !< segment from point i in `colors(:, i)` (RGBA in [0, 1]). Statuses: `FIG_ERR_ARGUMENT` for series of different
   !< sizes, colours not (4, size(x)) or out of [0, 1]; `FIG_ERR_STATE` outside a 3-D plot, from a task.
   character(len=*),         intent(in)                       :: label !< Legend label.
   real(real64),             intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),             intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real64),             intent(in), target, asynchronous :: z(:)  !< Heights.
   type(plot3d_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot3D's).
   real(real64),             intent(in), optional             :: colors(:,:) !< Per-point RGBA, (4, size(x)).
   integer(int32),           intent(out), optional            :: stat  !< Status.
   integer(int64)                                             :: s     !< The stride ImPlot3D would read [bytes].

   if (item_refused('ip3_line', size(x, kind=int64), size(y, kind=int64), size(z, kind=int64), stat)) return
   if (.not. per_point_ok('ip3_line', size(x, kind=int64), colors, stat=stat)) return
   call acct_lead_r64(s, x)
   call acct_put_r64(s, y)
   call acct_put_r64(s, z)
   plot_stride = s
   call pf3_line(label, x, y, z, spec=item_spec(spec), colors=colors)
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_line_r64

   recursive subroutine ip3_scatter_r32(label, x, y, z, spec, colors, sizes, stat)
   !< Markers at the points (x(i), y(i), z(i)), single precision; read in place with any stride. `colors`: each marker
   !< filled and outlined in its own colour, `colors(:, i)` RGBA in [0, 1]; `sizes`: each its own radius [pixels].
   !< Statuses as `ip3_line`, and `FIG_ERR_ARGUMENT` for colours not (4, size(x)) or out of [0, 1], sizes not one per
   !< point or below 0.
   character(len=*),         intent(in)                       :: label !< Legend label.
   real(real32),             intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),             intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real32),             intent(in), target, asynchronous :: z(:)  !< Heights.
   type(plot3d_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot3D's).
   real(real64),             intent(in), optional             :: colors(:,:) !< Per-point RGBA, (4, size(x)).
   real(real64),             intent(in), optional             :: sizes(:)    !< Per-point marker radii [pixels].
   integer(int32),           intent(out), optional            :: stat  !< Status.
   integer(int64)                                             :: s     !< The stride ImPlot3D would read [bytes].

   if (item_refused('ip3_scatter', size(x, kind=int64), size(y, kind=int64), size(z, kind=int64), stat)) return
   if (.not. per_point_ok('ip3_scatter', size(x, kind=int64), colors, sizes, stat)) return
   call acct_lead_r32(s, x)
   call acct_put_r32(s, y)
   call acct_put_r32(s, z)
   plot_stride = s
   call pf3_scatter(label, x, y, z, spec=item_spec(spec), colors=colors, sizes=sizes)
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_scatter_r32

   recursive subroutine ip3_scatter_r64(label, x, y, z, spec, colors, sizes, stat)
   !< Markers at the points (x(i), y(i), z(i)), double precision; read in place with any stride. `colors`: each marker
   !< filled and outlined in its own colour, `colors(:, i)` RGBA in [0, 1]; `sizes`: each its own radius [pixels].
   !< Statuses as `ip3_line`, and `FIG_ERR_ARGUMENT` for colours not (4, size(x)) or out of [0, 1], sizes not one per
   !< point or below 0.
   character(len=*),         intent(in)                       :: label !< Legend label.
   real(real64),             intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),             intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real64),             intent(in), target, asynchronous :: z(:)  !< Heights.
   type(plot3d_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot3D's).
   real(real64),             intent(in), optional             :: colors(:,:) !< Per-point RGBA, (4, size(x)).
   real(real64),             intent(in), optional             :: sizes(:)    !< Per-point marker radii [pixels].
   integer(int32),           intent(out), optional            :: stat  !< Status.
   integer(int64)                                             :: s     !< The stride ImPlot3D would read [bytes].

   if (item_refused('ip3_scatter', size(x, kind=int64), size(y, kind=int64), size(z, kind=int64), stat)) return
   if (.not. per_point_ok('ip3_scatter', size(x, kind=int64), colors, sizes, stat)) return
   call acct_lead_r64(s, x)
   call acct_put_r64(s, y)
   call acct_put_r64(s, z)
   plot_stride = s
   call pf3_scatter(label, x, y, z, spec=item_spec(spec), colors=colors, sizes=sizes)
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_scatter_r64

   recursive subroutine ip3_surface_r32(label, x, y, z, colormap, scale_min, scale_max, spec, stat)
   !< A surface of heights z(i, j) over the rectilinear grid x(i), y(j), single precision, coloured by `colormap` from
   !< `scale_min` to `scale_max` (default: z's finite range). z is read in place when its elements are equally spaced in
   !< memory (a whole array, `z(:, j1:j2)`, `a(k, :, :)`), else copied; x and y are expanded into the grid's two
   !< coordinate arrays (two copies: ImPlot3D reads one value per vertex). Statuses: `FIG_ERR_ARGUMENT` for x, y that do
   !< not match z's shape, one scale end without the other or a minimum not below the maximum, more vertices than a
   !< C int counts, a colormap not registered; `FIG_ERR_STATE` outside a 3-D plot, from a task.
   character(len=*),         intent(in)                       :: label     !< Legend label.
   real(real32),             intent(in), target, asynchronous :: x(:)      !< Abscissae of the grid, size(z, 1).
   real(real32),             intent(in), target, asynchronous :: y(:)      !< Ordinates of the grid, size(z, 2).
   real(real32),             intent(in), target, asynchronous :: z(:,:)    !< Heights.
   integer(int32),           intent(in), optional             :: colormap  !< Colormap (`ip_colormap`; default Viridis).
   real(real64),             intent(in), optional             :: scale_min !< Height at the colormap's first colour.
   real(real64),             intent(in), optional             :: scale_max !< Height at its last colour.
   type(plot3d_spec_object), intent(in), optional             :: spec      !< Style (default: ImPlot3D's).
   integer(int32),           intent(out), optional            :: stat      !< Status.
   integer(int64)                                             :: s         !< The stride ImPlot3D would read [bytes].
   integer(c_int)                                             :: cmap      !< Colormap id.

   if (.not. surface_ok(size(z, 1, kind=int64), size(z, 2, kind=int64), size(x, kind=int64), &
                        size(y, kind=int64), scale_min, scale_max, stat)) return
   if (.not. colormap3d_ok(colormap, cmap, stat)) return
   call acct_field_r32(s, z)
   plot_copies = plot_copies + 2_int64 ! the grid's two coordinate arrays, laid out at the stride
   plot_stride = s
   call pf3_surface(label, x, y, z, int(cmap, int32), scale_min, scale_max, spec=item_spec(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_surface_r32

   recursive subroutine ip3_surface_r64(label, x, y, z, colormap, scale_min, scale_max, spec, stat)
   !< A surface of heights z(i, j) over the rectilinear grid x(i), y(j), double precision, coloured by `colormap` from
   !< `scale_min` to `scale_max` (default: z's finite range). z is read in place when its elements are equally spaced in
   !< memory (a whole array, `z(:, j1:j2)`, `a(k, :, :)`), else copied; x and y are expanded into the grid's two
   !< coordinate arrays (two copies: ImPlot3D reads one value per vertex). Statuses: `FIG_ERR_ARGUMENT` for x, y that do
   !< not match z's shape, one scale end without the other or a minimum not below the maximum, more vertices than a
   !< C int counts, a colormap not registered; `FIG_ERR_STATE` outside a 3-D plot, from a task.
   character(len=*),         intent(in)                       :: label     !< Legend label.
   real(real64),             intent(in), target, asynchronous :: x(:)      !< Abscissae of the grid, size(z, 1).
   real(real64),             intent(in), target, asynchronous :: y(:)      !< Ordinates of the grid, size(z, 2).
   real(real64),             intent(in), target, asynchronous :: z(:,:)    !< Heights.
   integer(int32),           intent(in), optional             :: colormap  !< Colormap (`ip_colormap`; default Viridis).
   real(real64),             intent(in), optional             :: scale_min !< Height at the colormap's first colour.
   real(real64),             intent(in), optional             :: scale_max !< Height at its last colour.
   type(plot3d_spec_object), intent(in), optional             :: spec      !< Style (default: ImPlot3D's).
   integer(int32),           intent(out), optional            :: stat      !< Status.
   integer(int64)                                             :: s         !< The stride ImPlot3D would read [bytes].
   integer(c_int)                                             :: cmap      !< Colormap id.

   if (.not. surface_ok(size(z, 1, kind=int64), size(z, 2, kind=int64), size(x, kind=int64), &
                        size(y, kind=int64), scale_min, scale_max, stat)) return
   if (.not. colormap3d_ok(colormap, cmap, stat)) return
   call acct_field_r64(s, z)
   plot_copies = plot_copies + 2_int64 ! the grid's two coordinate arrays, laid out at the stride
   plot_stride = s
   call pf3_surface(label, x, y, z, int(cmap, int32), scale_min, scale_max, spec=item_spec(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_surface_r64

   recursive subroutine ip3_surface_grid_r32(label, x, y, z, colormap, scale_min, scale_max, spec, stat)
   !< A surface over any grid of quadrilaterals: the vertex (i, j) at (x(i, j), y(i, j), z(i, j)), single precision,
   !< coloured as `ip3_surface`. The three arrays are read in place when their elements are equally spaced in memory
   !< with one stride, else copied at the stride of z. Statuses as `ip3_surface` (x and y of z's shape).
   character(len=*),         intent(in)                       :: label     !< Legend label.
   real(real32),             intent(in), target, asynchronous :: x(:,:)    !< Abscissae of the vertices.
   real(real32),             intent(in), target, asynchronous :: y(:,:)    !< Ordinates of the vertices.
   real(real32),             intent(in), target, asynchronous :: z(:,:)    !< Heights of the vertices.
   integer(int32),           intent(in), optional             :: colormap  !< Colormap (`ip_colormap`; default Viridis).
   real(real64),             intent(in), optional             :: scale_min !< Height at the colormap's first colour.
   real(real64),             intent(in), optional             :: scale_max !< Height at its last colour.
   type(plot3d_spec_object), intent(in), optional             :: spec      !< Style (default: ImPlot3D's).
   integer(int32),           intent(out), optional            :: stat      !< Status.
   integer(int64)                                             :: s         !< The stride ImPlot3D would read [bytes].
   integer(c_int)                                             :: cmap      !< Colormap id.

   if (.not. grid_ok(shape(x, kind=int64), shape(y, kind=int64), shape(z, kind=int64), stat)) return
   if (.not. surface_ok(size(z, 1, kind=int64), size(z, 2, kind=int64), size(z, 1, kind=int64), &
                        size(z, 2, kind=int64), scale_min, scale_max, stat)) return
   if (.not. colormap3d_ok(colormap, cmap, stat)) return
   call acct_field_r32(s, z)
   call acct_field_r32(s, x, s)
   call acct_field_r32(s, y, s)
   plot_stride = s
   call pf3_surface(label, x, y, z, int(cmap, int32), scale_min, scale_max, spec=item_spec(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_surface_grid_r32

   recursive subroutine ip3_surface_grid_r64(label, x, y, z, colormap, scale_min, scale_max, spec, stat)
   !< A surface over any grid of quadrilaterals: the vertex (i, j) at (x(i, j), y(i, j), z(i, j)), double precision,
   !< coloured as `ip3_surface`. The three arrays are read in place when their elements are equally spaced in memory
   !< with one stride, else copied at the stride of z. Statuses as `ip3_surface` (x and y of z's shape).
   character(len=*),         intent(in)                       :: label     !< Legend label.
   real(real64),             intent(in), target, asynchronous :: x(:,:)    !< Abscissae of the vertices.
   real(real64),             intent(in), target, asynchronous :: y(:,:)    !< Ordinates of the vertices.
   real(real64),             intent(in), target, asynchronous :: z(:,:)    !< Heights of the vertices.
   integer(int32),           intent(in), optional             :: colormap  !< Colormap (`ip_colormap`; default Viridis).
   real(real64),             intent(in), optional             :: scale_min !< Height at the colormap's first colour.
   real(real64),             intent(in), optional             :: scale_max !< Height at its last colour.
   type(plot3d_spec_object), intent(in), optional             :: spec      !< Style (default: ImPlot3D's).
   integer(int32),           intent(out), optional            :: stat      !< Status.
   integer(int64)                                             :: s         !< The stride ImPlot3D would read [bytes].
   integer(c_int)                                             :: cmap      !< Colormap id.

   if (.not. grid_ok(shape(x, kind=int64), shape(y, kind=int64), shape(z, kind=int64), stat)) return
   if (.not. surface_ok(size(z, 1, kind=int64), size(z, 2, kind=int64), size(z, 1, kind=int64), &
                        size(z, 2, kind=int64), scale_min, scale_max, stat)) return
   if (.not. colormap3d_ok(colormap, cmap, stat)) return
   call acct_field_r64(s, z)
   call acct_field_r64(s, x, s)
   call acct_field_r64(s, y, s)
   plot_stride = s
   call pf3_surface(label, x, y, z, int(cmap, int32), scale_min, scale_max, spec=item_spec(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_surface_grid_r64

   recursive subroutine ip3_mesh_r32(label, x, y, z, triangles, spec, stat)
   !< A mesh of triangles, single precision: vertices (x(i), y(i), z(i)) read in place with any stride,
   !< `triangles(1:3, k)` the vertices of the k-th triangle (from 1; converted to ImPlot3D's 0-based indices: one copy).
   !< Statuses: `FIG_ERR_ARGUMENT` for series of different sizes, `triangles` without 3 rows or with a vertex outside
   !< [1, size(x)]; `FIG_ERR_STATE` outside a 3-D plot, from a task.
   character(len=*),         intent(in)                       :: label          !< Legend label.
   real(real32),             intent(in), target, asynchronous :: x(:)           !< Abscissae of the vertices.
   real(real32),             intent(in), target, asynchronous :: y(:)           !< Ordinates of the vertices.
   real(real32),             intent(in), target, asynchronous :: z(:)           !< Heights of the vertices.
   integer(int32),           intent(in)                       :: triangles(:,:) !< Vertices of each triangle.
   type(plot3d_spec_object), intent(in), optional             :: spec           !< Style (default: ImPlot3D's).
   integer(int32),           intent(out), optional            :: stat           !< Status.
   integer(int64)                                             :: s              !< The stride ImPlot3D would read [bytes].

   if (item_refused('ip3_mesh', size(x, kind=int64), size(y, kind=int64), size(z, kind=int64), stat)) return
   if (.not. triangles_ok(triangles, size(x, kind=int64), stat)) return
   call acct_lead_r32(s, x)
   call acct_put_r32(s, y)
   call acct_put_r32(s, z)
   plot_stride = s
   call pf3_mesh(label, x, y, z, triangles, spec=item_spec(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_mesh_r32

   recursive subroutine ip3_mesh_r64(label, x, y, z, triangles, spec, stat)
   !< A mesh of triangles, double precision: vertices (x(i), y(i), z(i)) read in place with any stride,
   !< `triangles(1:3, k)` the vertices of the k-th triangle (from 1; converted to ImPlot3D's 0-based indices: one copy).
   !< Statuses: `FIG_ERR_ARGUMENT` for series of different sizes, `triangles` without 3 rows or with a vertex outside
   !< [1, size(x)]; `FIG_ERR_STATE` outside a 3-D plot, from a task.
   character(len=*),         intent(in)                       :: label          !< Legend label.
   real(real64),             intent(in), target, asynchronous :: x(:)           !< Abscissae of the vertices.
   real(real64),             intent(in), target, asynchronous :: y(:)           !< Ordinates of the vertices.
   real(real64),             intent(in), target, asynchronous :: z(:)           !< Heights of the vertices.
   integer(int32),           intent(in)                       :: triangles(:,:) !< Vertices of each triangle.
   type(plot3d_spec_object), intent(in), optional             :: spec           !< Style (default: ImPlot3D's).
   integer(int32),           intent(out), optional            :: stat           !< Status.
   integer(int64)                                             :: s              !< The stride ImPlot3D would read [bytes].

   if (item_refused('ip3_mesh', size(x, kind=int64), size(y, kind=int64), size(z, kind=int64), stat)) return
   if (.not. triangles_ok(triangles, size(x, kind=int64), stat)) return
   call acct_lead_r64(s, x)
   call acct_put_r64(s, y)
   call acct_put_r64(s, z)
   plot_stride = s
   call pf3_mesh(label, x, y, z, triangles, spec=item_spec(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_mesh_r64

   recursive subroutine ip3_text(text, x, y, z, angle, offset, stat)
   !< A text centred on the point (x, y, z) of the current 3-D plot (`PlotText`), in the plot's inlay text colour,
   !< hidden when the point is outside the box; `angle` turns it [radians, counter-clockwise], `offset` moves it
   !< [pixels] (x right, y down). Not an item: no legend entry, no part in fitting the axes. Statuses:
   !< `FIG_ERR_ARGUMENT` for a NaN coordinate or an offset of size /= 2; `FIG_ERR_STATE` outside a 3-D plot, from a
   !< task.
   character(len=*), intent(in)            :: text      !< Text (UTF-8).
   real(real64),     intent(in)            :: x         !< Abscissa [plot units].
   real(real64),     intent(in)            :: y         !< Ordinate [plot units].
   real(real64),     intent(in)            :: z         !< Height [plot units].
   real(real64),     intent(in), optional  :: angle     !< Angle [radians] (default: 0, horizontal).
   real(real64),     intent(in), optional  :: offset(:) !< Offset [pixels], (x right, y down) (default: none).
   integer(int32),   intent(out), optional :: stat      !< Status.

   if (entry_refused('ip3_text', stat)) return ! a task does not draw
   if (present(offset)) then
      if (size(offset) /= 2) then
         call figure_fail(FIG_ERR_ARGUMENT, 'ip3_text: the offset needs 2 components (x, y)', stat)
         return
      endif
   endif
   if (ieee_is_nan(x) .or. ieee_is_nan(y) .or. ieee_is_nan(z)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip3_text: x, y and z must not be NaN', stat)
      return
   endif
   if (outside_plot('ip3_text', stat)) return
   if (present(offset)) then ! (the offset as floats, as ImPlot3D takes it: the frame's)
      call pf3_text(text, x, y, z, angle, offset)
   else
      call pf3_text(text, x, y, z, angle)
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_text

   recursive subroutine ip3_image(label, texture, corners, tint, stat)
   !< An image on a quadrilateral of the box (`PlotImage`): `corners(:, k)` the x, y, z of its four corners, in the
   !< image's top-left, top-right, bottom-right, bottom-left order (a rectangle on a plane: a field on a cut, a
   !< picture on the floor); `tint` multiplies its colours (RGBA, default white). An item: a legend entry, part of the
   !< fit. Drawn as two triangles, sorted with the other items. Statuses: `FIG_ERR_ARGUMENT` for `corners` not 3 x 4, a
   !< tint without 4 components, a texture not initialized; `FIG_ERR_STATE` outside a 3-D plot, from a task.
   character(len=*),     intent(in)            :: label        !< Legend label.
   type(texture_object), intent(in)            :: texture      !< The image.
   real(real64),         intent(in)            :: corners(:, :) !< x, y, z of the four corners (3 x 4).
   real(real64),         intent(in),  optional :: tint(:)      !< RGBA multiplier (default 1, 1, 1, 1).
   integer(int32),       intent(out), optional :: stat         !< Status.

   if (entry_refused('ip3_image', stat)) return ! a task does not draw
   if (size(corners, 1) /= 3 .or. size(corners, 2) /= 4) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip3_image: corners must be 3 x 4 (x, y, z of four corners)', stat)
      return
   endif
   if (present(tint)) then
      if (size(tint) /= 4) then
         call figure_fail(FIG_ERR_ARGUMENT, 'ip3_image: a colour needs 4 components (RGBA)', stat)
         return
      endif
   endif
   if (.not. texture%is_initialized()) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip3_image: the texture is not initialized (texture%init)', stat)
      return
   endif
   if (outside_plot('ip3_image', stat)) return
   plot_stride = 0_int64 ! (spec_at(0): the stride given to ImPlot3D)
   call pf3_image(label, texture, corners, tint)
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_image

   recursive subroutine ip3_setup_axis(axis, label, scale, auto_fit, invert, lock, no_grid, format, stat)
   !< Set up one axis of the 3-D plot being declared (`SetupAxis`, `SetupAxisScale`): `axis` `'x'`, `'y'` or `'z'`;
   !< `scale` `'linear'` (default), `'log'` (base 10: values <= 0 are not shown) or `'symlog'`; `auto_fit` fits the data
   !< every frame; `invert` grows the axis the other way; `lock` fixes its range against the mouse; `no_grid`: no grid
   !< lines; `format` a C printf format of one real for the tick labels (`'%.1f m'`, `'%.0e'`). After `ip3_begin_plot` (and
   !< `ip3_setup_axes`, which it overrides for that axis), before any item. Statuses: `FIG_ERR_ARGUMENT` for an unknown
   !< axis or scale, a format refused; `FIG_ERR_STATE` outside a 3-D plot, after its first item, from a task.
   character(len=*), intent(in)            :: axis     !< 'x', 'y' or 'z'.
   character(len=*), intent(in),  optional :: label    !< Label (default: none).
   character(len=*), intent(in),  optional :: scale    !< 'linear' (default), 'log', 'symlog'.
   logical,          intent(in),  optional :: auto_fit !< Fit the data every frame.
   logical,          intent(in),  optional :: invert   !< Values grow the other way.
   logical,          intent(in),  optional :: lock     !< No pan or zoom by the user.
   logical,          intent(in),  optional :: no_grid  !< No grid lines.
   character(len=*), intent(in),  optional :: format   !< printf format of the tick labels (one real).
   integer(int32),   intent(out), optional :: stat     !< Status.

   if (entry_refused('ip3_setup_axis', stat)) return ! a task does not draw
   select case (axis)
   case ('x', 'y', 'z')
   case default
      call figure_fail(FIG_ERR_ARGUMENT, "ip3_setup_axis: unknown axis '"//axis//"' ('x', 'y' or 'z')", stat)
      return
   endselect
   if (present(scale)) then
      select case (scale)
      case ('linear', 'log', 'symlog')
      case default
         call figure_fail(FIG_ERR_ARGUMENT, "ip3_setup_axis: unknown scale '"//scale//"' ('linear', 'log' or "// &
                          "'symlog')", stat)
         return
      endselect
   endif
   if (present(format)) then
      if (format_refused('ip3_setup_axis', 'format', format, FORMAT_REAL, stat)) return
   endif
   if (setup3d_refused('ip3_setup_axis', stat)) return
   call pf3_setup_axis(axis, label, scale, auto_fit, invert, lock, no_grid, format)
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_setup_axis

   recursive subroutine ip3_setup_axis_ticks(axis, values, labels, stat)
   !< Ticks of one axis of the 3-D plot being declared at the given values instead of the automatic ones
   !< (`SetupAxisTicks`), labelled `labels` (one per value; trailing blanks are not shown) or, without them, by the
   !< axis's format. Before any item. Statuses: `FIG_ERR_ARGUMENT` for an unknown axis, values not finite, labels not
   !< one per value, more values than a C `int` counts; `FIG_ERR_STATE` outside a 3-D plot, after its first item, from
   !< a task.
   character(len=*), intent(in)            :: axis      !< 'x', 'y' or 'z'.
   real(real64),     intent(in)            :: values(:) !< Tick positions.
   character(len=*), intent(in),  optional :: labels(:) !< One label per value.
   integer(int32),   intent(out), optional :: stat      !< Status.
   integer(int64)                          :: n         !< Values.

   if (entry_refused('ip3_setup_axis_ticks', stat)) return ! a task does not draw
   select case (axis)
   case ('x', 'y', 'z')
   case default
      call figure_fail(FIG_ERR_ARGUMENT, "ip3_setup_axis_ticks: unknown axis '"//axis//"' ('x', 'y' or 'z')", stat)
      return
   endselect
   n = size(values, kind=int64)
   if (n > int(huge(1_c_int), int64)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip3_setup_axis_ticks: more values than a C int counts', stat)
      return
   endif
   if (.not. all(ieee_is_finite(values))) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip3_setup_axis_ticks: values must be finite', stat)
      return
   endif
   if (present(labels)) then
      if (size(labels, kind=int64) /= n) then
         call figure_fail(FIG_ERR_ARGUMENT, 'ip3_setup_axis_ticks: labels must be one per value', stat)
         return
      endif
   endif
   if (setup3d_refused('ip3_setup_axis_ticks', stat)) return
   call pf3_setup_axis_ticks(axis, values, labels)
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_setup_axis_ticks

   recursive subroutine ip3_setup_box(scale, elevation, azimuth, animate, stat)
   !< The box of the 3-D plot being declared: `scale` its x, y, z sides relative to each other (`SetupBoxScale`,
   !< default 1, 1, 1: a cube); `elevation` and `azimuth` [degrees], both or neither, turn it to that view on this
   !< frame (`SetupBoxRotation`: a "top view" button calls it once; called every frame, the user cannot turn it),
   !< `animate=.true.` turning it there smoothly. Before any item. Statuses: `FIG_ERR_ARGUMENT` for a scale without 3
   !< positive values, one angle without the other; `FIG_ERR_STATE` outside a 3-D plot, after its first item, from a
   !< task.
   real(real64),   intent(in),  optional :: scale(:)  !< Relative sides [x, y, z].
   real(real64),   intent(in),  optional :: elevation !< Elevation [degrees].
   real(real64),   intent(in),  optional :: azimuth   !< Azimuth [degrees].
   logical,        intent(in),  optional :: animate   !< Turn there smoothly (default: at once).
   integer(int32), intent(out), optional :: stat      !< Status.

   if (entry_refused('ip3_setup_box', stat)) return ! a task does not draw
   if (present(scale)) then
      if (size(scale) /= 3) then
         call figure_fail(FIG_ERR_ARGUMENT, 'ip3_setup_box: scale needs 3 values (x, y, z)', stat)
         return
      endif
      if (.not. all(scale > 0.0_real64)) then
         call figure_fail(FIG_ERR_ARGUMENT, 'ip3_setup_box: each value of scale must be above 0', stat)
         return
      endif
   endif
   if (present(elevation) .neqv. present(azimuth)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip3_setup_box: give both elevation and azimuth, or neither', stat)
      return
   endif
   if (setup3d_refused('ip3_setup_box', stat)) return
   call pf3_setup_box(scale, elevation, azimuth, animate)
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_setup_box

   recursive subroutine ip3_setup_legend(location, horizontal, no_buttons, stat)
   !< Where the 3-D plot's legend goes (`SetupLegend`): `location` a compass point, `'n'`, `'ne'`, `'e'`, `'se'`,
   !< `'s'`, `'sw'`, `'w'`, `'nw'` (default, ImPlot3D's) or `'c'`; `horizontal=.true.`: entries in a row;
   !< `no_buttons=.true.`: a click on an entry does not hide its item. Before any item. Statuses: `FIG_ERR_ARGUMENT`
   !< for an unknown location; `FIG_ERR_STATE` outside a 3-D plot, after its first item, from a task.
   character(len=*), intent(in),  optional :: location   !< Compass point (default 'nw').
   logical,          intent(in),  optional :: horizontal !< Entries in a row (default: a column).
   logical,          intent(in),  optional :: no_buttons !< Entries do not hide their items.
   integer(int32),   intent(out), optional :: stat       !< Status.

   if (entry_refused('ip3_setup_legend', stat)) return ! a task does not draw
   if (present(location)) then
      select case (trim(location))
      case ('n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw', 'c')
      case default
         call figure_fail(FIG_ERR_ARGUMENT, "ip3_setup_legend: unknown location '"//trim(location)//"' ('n', 'ne', "// &
                          "'e', 'se', 's', 'sw', 'w', 'nw' or 'c')", stat)
         return
      endselect
   endif
   if (setup3d_refused('ip3_setup_legend', stat)) return
   if (present(location)) then
      call pf3_setup_legend(trim(location), horizontal, no_buttons)
   else
      call pf3_setup_legend(horizontal=horizontal, no_buttons=no_buttons)
   endif
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_setup_legend

   recursive function ip3_mouse_ray(origin, direction, stat) result(over)
   !< The ray under the pointer, in the 3-D plot's coordinates (`PixelsToPlotRay`): every point of the box drawn under
   !< the pointer is `origin + t direction` for some `t` (`direction` of length 1). True when the pointer is over the
   !< plot. A program picks with it: where the ray meets a plane (the floor: `t = -origin(3) / direction(3)`), the
   !< nearest of its points. Linear axes: on a log axis the ray is in the transformed space. Statuses:
   !< `FIG_ERR_STATE` outside a 3-D plot, from a task.
   real(real64),   intent(out)           :: origin(3)    !< A point of the ray.
   real(real64),   intent(out)           :: direction(3) !< Its direction (unit).
   integer(int32), intent(out), optional :: stat         !< Status.
   logical                               :: over         !< The pointer is over the plot.

   over = .false.
   origin = 0.0_real64
   direction = 0.0_real64
   if (entry_refused('ip3_mouse_ray', stat)) return ! a task does not draw
   if (outside_plot('ip3_mouse_ray', stat)) return
   over = pf3_mouse_ray(origin, direction)
   call figure_check(FIG_OK, stat)
   endfunction ip3_mouse_ray

   recursive subroutine ip3_plot_to_pixels(x, y, z, px, py, stat)
   !< The pixel (px, py) where the point (x, y, z) of the 3-D plot being declared is drawn (`PlotToPixels`), as the
   !< box is turned now: a label beside a point, a test's click. Statuses: `FIG_ERR_STATE` outside a 3-D plot, from a
   !< task.
   real(real64),   intent(in)            :: x    !< Abscissa.
   real(real64),   intent(in)            :: y    !< Ordinate.
   real(real64),   intent(in)            :: z    !< Height.
   real(real64),   intent(out)           :: px   !< Pixel abscissa.
   real(real64),   intent(out)           :: py   !< Pixel ordinate.
   integer(int32), intent(out), optional :: stat !< Status.

   px = 0.0_real64
   py = 0.0_real64
   if (entry_refused('ip3_plot_to_pixels', stat)) return ! a task does not draw
   if (outside_plot('ip3_plot_to_pixels', stat)) return
   call pf3_plot_to_pixels(x, y, z, px, py)
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_plot_to_pixels

   recursive function setup3d_refused(caller, stat) result(refused)
   !< True (a usage error reported) outside a 3-D plot or after its first item.
   character(len=*), intent(in)            :: caller  !< The procedure.
   integer(int32),   intent(out), optional :: stat    !< Status, on a refusal.
   logical                                 :: refused !< Refused: return.

   refused = .true.
   select case (pf3_plot_state())
   case (0_int32)
      call figure_usage_error(caller//': no 3-D plot is being declared (call it after ip3_begin_plot returned '// &
                              'true)', stat)
      return
   case (2_int32)
      call figure_usage_error(caller//': the setup of the 3-D plot is over (call it before the first item)', stat)
      return
   endselect
   refused = .false.
   endfunction setup3d_refused

   recursive subroutine ip3_triangles_r64(label, x, y, z, spec, stat)
   !< Triangles: points 1-3, 4-6, ... each one (`PlotTriangle`), double precision; read in place with any stride.
   !< Filled with the spec's `fill_color` (default: the item's colour), edged with its `line_color`. Statuses:
   !< `FIG_ERR_ARGUMENT` for series of different sizes or a size not a multiple of 3; `FIG_ERR_STATE` outside a 3-D
   !< plot, from a task.
   character(len=*),         intent(in)                       :: label !< Legend label.
   real(real64),                 intent(in), target, asynchronous :: x(:)  !< Abscissae of the vertices.
   real(real64),                 intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real64),                 intent(in), target, asynchronous :: z(:)  !< Heights.
   type(plot3d_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot3D's).
   integer(int32),           intent(out), optional            :: stat  !< Status.
   integer(int64)                                             :: s     !< The stride ImPlot3D would read [bytes].
   character(len=24)                                          :: t     !< The size, printed.

   if (item_refused('ip3_triangles', size(x, kind=int64), size(y, kind=int64), size(z, kind=int64), stat)) return
   if (mod(size(x), 3) /= 0) then
      write(t, '(I0)') size(x)
      call figure_fail(FIG_ERR_ARGUMENT, 'ip3_triangles: '//trim(t)//' vertices are not a whole number of triangles (3 '// &
                       'each)', stat)
      return
   endif
   call acct_lead_r64(s, x)
   call acct_put_r64(s, y)
   call acct_put_r64(s, z)
   plot_stride = s
   call pf3_triangles(label, x, y, z, spec=item_spec(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_triangles_r64

   recursive subroutine ip3_quads_r64(label, x, y, z, spec, stat)
   !< Quadrilaterals: points 1-4, 5-8, ... each one (`PlotQuad`), double precision; read in place with any stride.
   !< Filled with the spec's `fill_color` (default: the item's colour), edged with its `line_color`. Statuses:
   !< `FIG_ERR_ARGUMENT` for series of different sizes or a size not a multiple of 4; `FIG_ERR_STATE` outside a 3-D
   !< plot, from a task.
   character(len=*),         intent(in)                       :: label !< Legend label.
   real(real64),                 intent(in), target, asynchronous :: x(:)  !< Abscissae of the vertices.
   real(real64),                 intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real64),                 intent(in), target, asynchronous :: z(:)  !< Heights.
   type(plot3d_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot3D's).
   integer(int32),           intent(out), optional            :: stat  !< Status.
   integer(int64)                                             :: s     !< The stride ImPlot3D would read [bytes].
   character(len=24)                                          :: t     !< The size, printed.

   if (item_refused('ip3_quads', size(x, kind=int64), size(y, kind=int64), size(z, kind=int64), stat)) return
   if (mod(size(x), 4) /= 0) then
      write(t, '(I0)') size(x)
      call figure_fail(FIG_ERR_ARGUMENT, 'ip3_quads: '//trim(t)//' vertices are not a whole number of quads (4 '// &
                       'each)', stat)
      return
   endif
   call acct_lead_r64(s, x)
   call acct_put_r64(s, y)
   call acct_put_r64(s, z)
   plot_stride = s
   call pf3_quads(label, x, y, z, spec=item_spec(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_quads_r64

   recursive subroutine ip3_triangles_r32(label, x, y, z, spec, stat)
   !< Triangles: points 1-3, 4-6, ... each one (`PlotTriangle`), single precision; read in place with any stride.
   !< Filled with the spec's `fill_color` (default: the item's colour), edged with its `line_color`. Statuses:
   !< `FIG_ERR_ARGUMENT` for series of different sizes or a size not a multiple of 3; `FIG_ERR_STATE` outside a 3-D
   !< plot, from a task.
   character(len=*),         intent(in)                       :: label !< Legend label.
   real(real32),                 intent(in), target, asynchronous :: x(:)  !< Abscissae of the vertices.
   real(real32),                 intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real32),                 intent(in), target, asynchronous :: z(:)  !< Heights.
   type(plot3d_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot3D's).
   integer(int32),           intent(out), optional            :: stat  !< Status.
   integer(int64)                                             :: s     !< The stride ImPlot3D would read [bytes].
   character(len=24)                                          :: t     !< The size, printed.

   if (item_refused('ip3_triangles', size(x, kind=int64), size(y, kind=int64), size(z, kind=int64), stat)) return
   if (mod(size(x), 3) /= 0) then
      write(t, '(I0)') size(x)
      call figure_fail(FIG_ERR_ARGUMENT, 'ip3_triangles: '//trim(t)//' vertices are not a whole number of triangles (3 '// &
                       'each)', stat)
      return
   endif
   call acct_lead_r32(s, x)
   call acct_put_r32(s, y)
   call acct_put_r32(s, z)
   plot_stride = s
   call pf3_triangles(label, x, y, z, spec=item_spec(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_triangles_r32

   recursive subroutine ip3_quads_r32(label, x, y, z, spec, stat)
   !< Quadrilaterals: points 1-4, 5-8, ... each one (`PlotQuad`), single precision; read in place with any stride.
   !< Filled with the spec's `fill_color` (default: the item's colour), edged with its `line_color`. Statuses:
   !< `FIG_ERR_ARGUMENT` for series of different sizes or a size not a multiple of 4; `FIG_ERR_STATE` outside a 3-D
   !< plot, from a task.
   character(len=*),         intent(in)                       :: label !< Legend label.
   real(real32),                 intent(in), target, asynchronous :: x(:)  !< Abscissae of the vertices.
   real(real32),                 intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real32),                 intent(in), target, asynchronous :: z(:)  !< Heights.
   type(plot3d_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot3D's).
   integer(int32),           intent(out), optional            :: stat  !< Status.
   integer(int64)                                             :: s     !< The stride ImPlot3D would read [bytes].
   character(len=24)                                          :: t     !< The size, printed.

   if (item_refused('ip3_quads', size(x, kind=int64), size(y, kind=int64), size(z, kind=int64), stat)) return
   if (mod(size(x), 4) /= 0) then
      write(t, '(I0)') size(x)
      call figure_fail(FIG_ERR_ARGUMENT, 'ip3_quads: '//trim(t)//' vertices are not a whole number of quads (4 '// &
                       'each)', stat)
      return
   endif
   call acct_lead_r32(s, x)
   call acct_put_r32(s, y)
   call acct_put_r32(s, z)
   plot_stride = s
   call pf3_quads(label, x, y, z, spec=item_spec(spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_quads_r32

   recursive function outside_plot(caller, stat) result(refused)
   !< True (a usage error reported) when no 3-D plot is being declared: ImPlot3D asserts there.
   character(len=*), intent(in)            :: caller  !< The procedure.
   integer(int32),   intent(out), optional :: stat    !< Status, on a refusal.
   logical                                 :: refused !< Refused: return.

   refused = pf3_plot_state() == 0_int32
   if (refused) call figure_usage_error(caller//': no 3-D plot is being declared (call it between ip3_begin_plot '// &
                                        'and ip3_end_plot)', stat)
   endfunction outside_plot

   recursive function item_refused(caller, nx, ny, nz, stat) result(refused)
   !< True (reported) when an item cannot be drawn: from a task, no frame, no 3-D plot (`FIG_ERR_STATE`), series of
   !< different sizes or more points than a C int counts (`FIG_ERR_ARGUMENT`).
   character(len=*), intent(in)            :: caller  !< The procedure.
   integer(int64),   intent(in)            :: nx      !< Size of x.
   integer(int64),   intent(in)            :: ny      !< Size of y.
   integer(int64),   intent(in)            :: nz      !< Size of z.
   integer(int32),   intent(out), optional :: stat    !< Status, on a refusal.
   logical                                 :: refused !< Refused: return.

   refused = .true.
   if (entry_refused(caller, stat)) return ! a task does not draw
   if (nx /= ny .or. nx /= nz) then
      call figure_fail(FIG_ERR_ARGUMENT, caller//': the series have different sizes', stat)
      return
   endif
   if (nx > int(huge(0_c_int), int64)) then
      call figure_fail(FIG_ERR_ARGUMENT, caller//': more points than a C int can count', stat)
      return
   endif
   if (outside_plot(caller, stat)) return
   refused = .false.
   endfunction item_refused

   recursive function surface_ok(nx, ny, sx, sy, scale_min, scale_max, stat) result(ok)
   !< Whether a surface can be drawn (reported otherwise): from the main thread in a frame and a 3-D plot, x and y
   !< matching z's shape, the scale ends both given or neither and in order, a vertex count a C int holds.
   integer(int64), intent(in)            :: nx        !< size(z, 1).
   integer(int64), intent(in)            :: ny        !< size(z, 2).
   integer(int64), intent(in)            :: sx        !< Abscissae given (size(z, 1) expected).
   integer(int64), intent(in)            :: sy        !< Ordinates given (size(z, 2) expected).
   real(real64),   intent(in), optional  :: scale_min !< Height at the first colour.
   real(real64),   intent(in), optional  :: scale_max !< Height at the last colour.
   integer(int32), intent(out), optional :: stat      !< Status, on a refusal.
   logical                               :: ok        !< Drawable.

   ok = .false.
   if (entry_refused('ip3_surface', stat)) return ! a task does not draw
   if (sx /= nx .or. sy /= ny) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip3_surface: x and y must match z: size(x) = size(z, 1), size(y) = '// &
                       'size(z, 2) (or x and y of the shape of z)', stat)
      return
   endif
   if (present(scale_min) .neqv. present(scale_max)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip3_surface: give both scale_min and scale_max, or neither', stat)
      return
   endif
   if (present(scale_min)) then
      if (.not. (scale_min < scale_max)) then
         call figure_fail(FIG_ERR_ARGUMENT, 'ip3_surface: scale_min must be below scale_max', stat)
         return
      endif
   endif
   if (nx * ny > int(huge(0_c_int), int64)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip3_surface: more vertices than a C int can count', stat)
      return
   endif
   if (outside_plot('ip3_surface', stat)) return
   ok = .true.
   endfunction surface_ok

   recursive function colormap3d_ok(colormap, cmap, stat) result(ok)
   !< The ImPlot3D id of the colormap to draw with (default Viridis), copied from FIGURE's registry; false, with
   !< `FIG_ERR_ARGUMENT`, if it is not registered.
   integer(int32), intent(in),  optional :: colormap !< Colormap (`ip_colormap`), if given.
   integer(c_int), intent(out)           :: cmap     !< Colormap id (FIGURE's registry's).
   integer(int32), intent(out), optional :: stat     !< Status, on a failure.
   logical                               :: ok       !< Usable.
   character(len=12)                     :: text     !< The id, printed.

   cmap = int(ImPlotColormap_Viridis, c_int)
   if (present(colormap)) cmap = int(colormap, c_int)
   call cm_style_refresh() ! the style's line colours registered first, as the theme registers them at its commit
   ok = cmap >= 0_c_int .and. cmap < int(cm_count(), c_int) ! fig_plot3d_colormap's refusal (FIGURE's registry's ids)
   if (.not. ok) then
      write(text, '(I0)') cmap
      call figure_fail(FIG_ERR_ARGUMENT, 'ip3_surface: the colormap '//trim(text)//' is not registered (see ip_colormap)', &
                       stat)
   endif
   endfunction colormap3d_ok

   recursive function triangles_ok(triangles, nv, stat) result(ok)
   !< Whether a mesh's triangles are 3 rows of vertices in [1, nv] and a count a C int holds (`FIG_ERR_ARGUMENT`
   !< otherwise); the current path's copy of their 0-based indices counted (`test_plot_copies`).
   integer(int32), intent(in)            :: triangles(:,:) !< Vertices of each triangle.
   integer(int64), intent(in)            :: nv             !< Vertices.
   integer(int32), intent(out), optional :: stat           !< Status, on a refusal.
   logical                               :: ok             !< Drawable.
   integer(int64)                        :: n              !< Indices.

   ok = .false.
   if (size(triangles, 1) /= 3) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip3_mesh: triangles needs 3 rows (the vertices of each triangle)', stat)
      return
   endif
   n = size(triangles, kind=int64)
   if (n > int(huge(0_c_int), int64)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip3_mesh: more triangle corners than a C int can count', stat)
      return
   endif
   if (n > 0_int64) then
      if (minval(triangles) < 1_int32 .or. int(maxval(triangles), int64) > nv) then
         call figure_fail(FIG_ERR_ARGUMENT, 'ip3_mesh: a triangle has a vertex outside [1, size(x)]', stat)
         return
      endif
   endif
   plot_copies = plot_copies + 1_int64 ! (the 0-based indices the current path gives ImPlot3D)
   ok = .true.
   endfunction triangles_ok

   ! the Fortran path's own

   recursive function entry_refused(caller, stat) result(r)
   !< `figure_draw_refused` (a task, no frame open); when not refused, the path made ready (`plot_path_ready`).
   character(len=*), intent(in)            :: caller !< The entry point.
   integer(int32),   intent(out), optional :: stat   !< Status, on a refusal.
   logical                                 :: r      !< Refused: return.

   r = figure_draw_refused(caller, stat)
   if (.not. r) call plot_path_ready()
   endfunction entry_refused

   function item_spec(spec) result(s)
   !< The frame's style of an item: the given one, or ImPlot3D's defaults.
   type(plot3d_spec_object), intent(in), optional :: spec !< Style.
   type(plot3d_spec)                              :: s    !< The frame's.

   if (present(spec)) then
      s = spec%s
   else
      s = pf3_spec()
   endif
   endfunction item_spec

   ! test_plot_copies and test_plot_stride: what the current path copies (figure_plot_series' series_lead, series_put,
   ! its place_field) and the stride it gives ImPlot3D, counted without copying

   subroutine acct_lead_r32(s, a)
   !< `series_lead`: the item's stride from an array (a positive multiple of the element size within a C int, else a
   !< copy, contiguous).
   integer(int64), intent(out)                        :: s    !< The item's stride [bytes].
   real(real32),   intent(in), target, asynchronous   :: a(:) !< Array.
   integer(int64)                                     :: g    !< Its stride [bytes].

   s = storage_size(a, kind=int64) / 8_int64
   if (size(a) == 0) return
   g = s
   if (size(a) > 1) g = series_gap(c_loc(a(1)), c_loc(a(2)))
   if (g > 0_int64 .and. mod(g, s) == 0_int64 .and. g <= int(huge(0_c_int), int64)) then
      s = g
   else
      plot_copies = plot_copies + 1_int64
   endif
   endsubroutine acct_lead_r32

   subroutine acct_lead_r64(s, a)
   !< `series_lead`, double precision.
   integer(int64), intent(out)                        :: s    !< The item's stride [bytes].
   real(real64),   intent(in), target, asynchronous   :: a(:) !< Array.
   integer(int64)                                     :: g    !< Its stride [bytes].

   s = storage_size(a, kind=int64) / 8_int64
   if (size(a) == 0) return
   g = s
   if (size(a) > 1) g = series_gap(c_loc(a(1)), c_loc(a(2)))
   if (g > 0_int64 .and. mod(g, s) == 0_int64 .and. g <= int(huge(0_c_int), int64)) then
      s = g
   else
      plot_copies = plot_copies + 1_int64
   endif
   endsubroutine acct_lead_r64

   subroutine acct_put_r32(s, a)
   !< `series_put`: another array read in place at the item's stride, else copied.
   integer(int64), intent(in)                         :: s    !< The item's stride [bytes].
   real(real32),   intent(in), target, asynchronous   :: a(:) !< Array.

   if (size(a) <= 1) return
   if (series_gap(c_loc(a(1)), c_loc(a(2))) == s) return
   plot_copies = plot_copies + 1_int64
   endsubroutine acct_put_r32

   subroutine acct_put_r64(s, a)
   !< `series_put`, double precision.
   integer(int64), intent(in)                         :: s    !< The item's stride [bytes].
   real(real64),   intent(in), target, asynchronous   :: a(:) !< Array.

   if (size(a) <= 1) return
   if (series_gap(c_loc(a(1)), c_loc(a(2))) == s) return
   plot_copies = plot_copies + 1_int64
   endsubroutine acct_put_r64

   subroutine acct_field_r32(s, a, stride)
   !< `place_field`: a rank-2 array in place when its elements are equally spaced in memory (column after column) at a
   !< positive multiple of the element size within a C int and, when `stride` is given, at that stride; else copied
   !< (at `stride`, or contiguous: the item's stride the element size).
   integer(int64), intent(inout)                      :: s      !< The item's stride [bytes] (set without `stride`).
   real(real32),   intent(in), target, asynchronous   :: a(:,:) !< Array.
   integer(int64), intent(in), optional               :: stride !< The item's stride [bytes].
   integer(int64)                                     :: e      !< Element size [bytes].
   integer(int64)                                     :: g      !< Its stride [bytes]; 0: not equally spaced.

   e = storage_size(a, kind=int64) / 8_int64
   if (.not. present(stride)) s = e
   if (size(a) == 0) return
   g = e
   if (size(a, 1) > 1) then
      g = series_gap(c_loc(a(1, 1)), c_loc(a(2, 1)))
      if (size(a, 2) > 1) then
         if (series_gap(c_loc(a(1, 1)), c_loc(a(1, 2))) /= g * size(a, 1, kind=int64)) g = 0_int64
      endif
   elseif (size(a, 2) > 1) then
      g = series_gap(c_loc(a(1, 1)), c_loc(a(1, 2)))
   endif
   if (g <= 0_int64 .or. mod(g, e) /= 0_int64 .or. g > int(huge(0_c_int), int64)) g = 0_int64
   if (present(stride)) then
      if (g /= stride) g = 0_int64
   endif
   if (g > 0_int64) then
      if (.not. present(stride)) s = g
      return
   endif
   plot_copies = plot_copies + 1_int64
   endsubroutine acct_field_r32

   subroutine acct_field_r64(s, a, stride)
   !< `place_field`: a rank-2 array in place when its elements are equally spaced in memory (column after column) at a
   !< positive multiple of the element size within a C int and, when `stride` is given, at that stride; else copied
   !< (at `stride`, or contiguous: the item's stride the element size).
   integer(int64), intent(inout)                      :: s      !< The item's stride [bytes] (set without `stride`).
   real(real64),   intent(in), target, asynchronous   :: a(:,:) !< Array.
   integer(int64), intent(in), optional               :: stride !< The item's stride [bytes].
   integer(int64)                                     :: e      !< Element size [bytes].
   integer(int64)                                     :: g      !< Its stride [bytes]; 0: not equally spaced.

   e = storage_size(a, kind=int64) / 8_int64
   if (.not. present(stride)) s = e
   if (size(a) == 0) return
   g = e
   if (size(a, 1) > 1) then
      g = series_gap(c_loc(a(1, 1)), c_loc(a(2, 1)))
      if (size(a, 2) > 1) then
         if (series_gap(c_loc(a(1, 1)), c_loc(a(1, 2))) /= g * size(a, 1, kind=int64)) g = 0_int64
      endif
   elseif (size(a, 2) > 1) then
      g = series_gap(c_loc(a(1, 1)), c_loc(a(1, 2)))
   endif
   if (g <= 0_int64 .or. mod(g, e) /= 0_int64 .or. g > int(huge(0_c_int), int64)) g = 0_int64
   if (present(stride)) then
      if (g /= stride) g = 0_int64
   endif
   if (g > 0_int64) then
      if (.not. present(stride)) s = g
      return
   endif
   plot_copies = plot_copies + 1_int64
   endsubroutine acct_field_r64
endmodule figure_implot3d
