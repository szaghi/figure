!< figure_implot3d, small 3-D figures with Fortran arrays (ImPlot3D).
module figure_implot3d
!< figure_implot3d, small 3-D figures with Fortran arrays (ImPlot3D).
!<
!< ImPlot3D (brenocq/implot3d, MIT) draws plots in a box the user turns with the mouse (right drag: rotate; left drag:
!< pan; wheel or middle drag: zoom; right double click: back to the initial rotation; right click: the plot's menu),
!< through Dear ImGui's draw lists: the same in every mode. It is for figures that are plots, not scenes: probe
!< positions, trajectories, a field as a height surface, up to about 10**4 primitives; meshes of millions of faces
!< belong to `view3d_object` (plots.md, "3-D plots").
!<
!< `ip3_begin_plot` returns true when the plot is visible: then declare its axes (`ip3_setup_axes`) and items, and close
!< it with `ip3_end_plot` (only in that case). Items (`ip3_line`, `ip3_scatter`, `ip3_surface`, `ip3_mesh`) take
!< `real(real32)` or `real(real64)` arrays of any stride, read in place during the call as the 2-D items are
!< (figure_implot: ImPlot3D has one byte stride for all the arrays of an item, an array of another stride is copied at
!< it; the dummies are ASYNCHRONOUS). Every item takes an optional `spec`, built by `ip3_spec` from ImPlot3D's
!< defaults. A surface is coloured by FIGURE's colormaps (`ip_colormap`), copied into ImPlot3D's registry at their
!< first use and followed when `ig_gradient_edit` changes them.
!<
!< Every procedure refuses a call from a task and a call with no frame open (`FIG_ERR_STATE`); an item or `ip3_text`
!< outside a 3-D plot, and `ip3_setup_axes` after the plot's first item, are usage errors (`FIG_ERR_STATE`, as
!< `app%set_checks` says). The begin/end pair registers in the scope record of the frame (errors.md, "Pairing and
!< frames").
use, intrinsic :: iso_c_binding, only : c_bool, c_double, c_float, c_int, c_loc
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use, intrinsic :: ieee_arithmetic, only : ieee_is_finite, ieee_is_nan
use figure_base, only : cstr, figure_check, figure_draw_refused, figure_fail, figure_scope_open, figure_scope_refused, &
                        figure_usage_error, SCOPE_PLOT3D
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_OK, fig_plot3d_colormap, fig_plot3d_end, fig_plot3d_state
use figure_cimgui, only : im_vec2, im_vec4
use figure_cimplot_enums, only : ImPlotColormap_Viridis
use figure_cimplot3d, only : figure_ImPlot3DSpec_default, im_plot3d_spec, ImPlot3D_BeginPlot, ImPlot3D_SetupAxes, &
                             ImPlot3D_SetupAxesLimits, ImPlot3D_SetupBoxRotation_double,                        &
                             ImPlot3D_SetupBoxInitialRotation_double, ImPlot3D_PlotLine_FloatPtr,               &
                             ImPlot3D_PlotLine_doublePtr, ImPlot3D_PlotScatter_FloatPtr,                        &
                             ImPlot3D_PlotScatter_doublePtr, ImPlot3D_PlotSurface_FloatPtr,                     &
                             ImPlot3D_PlotSurface_doublePtr, ImPlot3D_PlotMesh_FloatPtr,                        &
                             ImPlot3D_PlotMesh_doublePtr, ImPlot3D_PlotText, ImPlot3D_PushColormap_Plot3DColormap, &
                             ImPlot3D_PopColormap
use figure_cimplot3d_enums, only : ImPlot3DFlags_None, ImPlot3DFlags_Equal, ImPlot3DAxisFlags_None,             &
                                   ImPlot3DAxisFlags_AutoFit, ImPlot3DCond_Once,                                 &
                                   ImPlot3DMarker_None, ImPlot3DMarker_Auto, ImPlot3DMarker_Circle,              &
                                   ImPlot3DMarker_Square, ImPlot3DMarker_Diamond, ImPlot3DMarker_Up,             &
                                   ImPlot3DMarker_Down, ImPlot3DMarker_Left, ImPlot3DMarker_Right,               &
                                   ImPlot3DMarker_Cross, ImPlot3DMarker_Plus, ImPlot3DMarker_Asterisk,           &
                                   ImPlot3DItemFlags_None, ImPlot3DItemFlags_NoLegend, ImPlot3DItemFlags_NoFit,  &
                                   ImPlot3DLineFlags_Segments, ImPlot3DLineFlags_Loop, ImPlot3DLineFlags_SkipNaN, &
                                   ImPlot3DSurfaceFlags_NoLines, ImPlot3DSurfaceFlags_NoFill,                    &
                                   ImPlot3DSurfaceFlags_NoMarkers, ImPlot3DMeshFlags_NoLines,                    &
                                   ImPlot3DMeshFlags_NoFill, ImPlot3DMeshFlags_NoMarkers
use figure_implot, only : plot_copies, plot_stride, series_gap, series_lead, series_put, series_r32, series_r64, &
                          series_scratch

implicit none
private
public :: ip3_begin_plot, ip3_end_plot, ip3_setup_axes, ip3_line, ip3_scatter, ip3_surface, ip3_mesh, ip3_text
public :: ip3_spec, plot3d_spec_object
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
   !< The C struct is private so that a spec always starts from ImPlot3D's defaults (a zeroed one draws nothing).
   type(im_plot3d_spec), private :: c !< `ImPlot3DSpec`, as passed to ImPlot3D.
endtype plot3d_spec_object

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

interface place_field
   !< Place a rank-2 array of an item (a surface's field or grid) in a slot.
   module procedure place_field_r32, place_field_r64
endinterface place_field

integer(c_int), allocatable, target :: mesh_index(:) !< The triangles of the last mesh, 0-based (kept and grown).

contains
   ! plots

   recursive function ip3_begin_plot(title, width, height, equal) result(visible)
   !< Begin a 3-D plot; if true, declare its content and call `ip3_end_plot`.
   character(len=*), intent(in)           :: title   !< Title (also the plot id; '##id' hides it).
   real(real64),     intent(in), optional :: width   !< Width [pixels] (default: full width).
   real(real64),     intent(in), optional :: height  !< Height [pixels] (default: ImPlot3D's).
   logical,          intent(in), optional :: equal   !< Same scale on the three axes (one unit as many pixels).
   logical                                :: visible !< Plot visible.
   type(im_vec2)                          :: extent  !< Size.
   integer(c_int)                         :: flags   !< ImPlot3DFlags.

   visible = .false.
   if (figure_draw_refused('ip3_begin_plot')) return ! a task does not draw
   extent = im_vec2(-1.0_c_float, 0.0_c_float)
   if (present(width)) extent%x = real(width, c_float)
   if (present(height)) extent%y = real(height, c_float)
   flags = ImPlot3DFlags_None
   if (present(equal)) then
      if (equal) flags = ior(flags, ImPlot3DFlags_Equal)
   endif
   visible = logical(ImPlot3D_BeginPlot(cstr(title), extent, flags))
   call figure_scope_open(SCOPE_PLOT3D, 'ip3_begin_plot', title, visible)
   endfunction ip3_begin_plot

   recursive subroutine ip3_end_plot()
   !< End the 3-D plot (only after `ip3_begin_plot` returned true).
   if (figure_scope_refused(SCOPE_PLOT3D, 'ip3_end_plot')) return ! a task, no frame, or not the innermost scope
   call fig_plot3d_end()
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
   integer(c_int)                          :: flags     !< ImPlot3DAxisFlags of the axes.

   if (figure_draw_refused('ip3_setup_axes', stat)) return ! a task does not draw
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
   select case (fig_plot3d_state())
   case (0_c_int)
      call figure_usage_error('ip3_setup_axes: no 3-D plot is being declared (call it after ip3_begin_plot returned '// &
                              'true)', stat)
      return
   case (2_c_int)
      call figure_usage_error('ip3_setup_axes: the setup of the 3-D plot is over (call it before the first item)', stat)
      return
   endselect
   flags = ImPlot3DAxisFlags_None
   if (present(auto_fit)) then
      if (auto_fit) flags = ImPlot3DAxisFlags_AutoFit
   endif
   call ImPlot3D_SetupAxes(cstr(xlabel), cstr(ylabel), cstr(zlabel), flags, flags, flags)
   if (present(limits)) call ImPlot3D_SetupAxesLimits(real(limits(1), c_double), real(limits(2), c_double),   &
                                                     real(limits(3), c_double), real(limits(4), c_double),   &
                                                     real(limits(5), c_double), real(limits(6), c_double),   &
                                                     ImPlot3DCond_Once)
   if (present(elevation)) then
      call ImPlot3D_SetupBoxRotation_double(real(elevation, c_double), real(azimuth, c_double), .false._c_bool, &
                                            ImPlot3DCond_Once)
      call ImPlot3D_SetupBoxInitialRotation_double(real(elevation, c_double), real(azimuth, c_double))
   endif
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

   call figure_ImPlot3DSpec_default(spec%c)
   if (.not. (rgba_ok(line_color) .and. rgba_ok(fill_color) .and. rgba_ok(marker_line_color) .and. &
              rgba_ok(marker_fill_color))) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ip3_spec: a colour needs 4 components (RGBA)', stat)
      return
   endif
   if (present(line_color)) spec%c%LineColor = rgba(line_color)
   if (present(line_weight)) spec%c%LineWeight = real(line_weight, c_float)
   if (present(fill_color)) spec%c%FillColor = rgba(fill_color)
   if (present(fill_alpha)) spec%c%FillAlpha = real(fill_alpha, c_float)
   if (present(marker)) spec%c%Marker = int(marker, c_int)
   if (present(marker_size)) spec%c%MarkerSize = real(marker_size, c_float)
   if (present(marker_line_color)) spec%c%MarkerLineColor = rgba(marker_line_color)
   if (present(marker_fill_color)) spec%c%MarkerFillColor = rgba(marker_fill_color)
   if (present(flags)) spec%c%Flags = int(flags, c_int)
   call figure_check(FIG_OK, stat)
   endfunction ip3_spec

   ! items, single precision

   recursive subroutine ip3_line_r32(label, x, y, z, spec, stat)
   !< A line through the points (x(i), y(i), z(i)), single precision; read in place with any stride. Statuses:
   !< `FIG_ERR_ARGUMENT` for series of different sizes; `FIG_ERR_STATE` outside a 3-D plot, from a task.
   character(len=*),         intent(in)                       :: label !< Legend label.
   real(real32),             intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),             intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real32),             intent(in), target, asynchronous :: z(:)  !< Heights.
   type(plot3d_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot3D's).
   integer(int32),           intent(out), optional            :: stat  !< Status.
   type(series_r32), target                                   :: d     !< Where ImPlot3D reads the arrays.

   if (item_refused('ip3_line', size(x, kind=int64), size(y, kind=int64), size(z, kind=int64), stat)) return
   call series_lead(d, 1, x)
   call series_put(d, 2, y)
   call series_put(d, 3, z)
   call ImPlot3D_PlotLine_FloatPtr(cstr(label), d%p(1), d%p(2), d%p(3), int(size(x), c_int), spec_at(d%stride, spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_line_r32

   recursive subroutine ip3_scatter_r32(label, x, y, z, spec, stat)
   !< Markers at the points (x(i), y(i), z(i)), single precision; read in place with any stride. Statuses as
   !< `ip3_line`.
   character(len=*),         intent(in)                       :: label !< Legend label.
   real(real32),             intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real32),             intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real32),             intent(in), target, asynchronous :: z(:)  !< Heights.
   type(plot3d_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot3D's).
   integer(int32),           intent(out), optional            :: stat  !< Status.
   type(series_r32), target                                   :: d     !< Where ImPlot3D reads the arrays.

   if (item_refused('ip3_scatter', size(x, kind=int64), size(y, kind=int64), size(z, kind=int64), stat)) return
   call series_lead(d, 1, x)
   call series_put(d, 2, y)
   call series_put(d, 3, z)
   call ImPlot3D_PlotScatter_FloatPtr(cstr(label), d%p(1), d%p(2), d%p(3), int(size(x), c_int), spec_at(d%stride, spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_scatter_r32

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
   type(series_r32), target                                   :: d         !< Where ImPlot3D reads the arrays.
   real(real32), pointer, contiguous                          :: gx(:)     !< The grid's abscissae, at the stride.
   real(real32), pointer, contiguous                          :: gy(:)     !< The grid's ordinates, at the stride.
   real(c_double)                                             :: lo        !< Height at the first colour.
   real(c_double)                                             :: hi        !< Height at the last colour.
   integer(c_int)                                             :: cmap      !< ImPlot3D colormap id.
   integer(int64)                                             :: m         !< The item's stride [elements].
   integer(int64)                                             :: i         !< Grid index along x.
   integer(int64)                                             :: j         !< Grid index along y.
   integer(int64)                                             :: k         !< Vertex, from 0.

   if (.not. surface_ok(size(z, 1, kind=int64), size(z, 2, kind=int64), size(x, kind=int64), &
                        size(y, kind=int64), scale_min, scale_max, stat)) return
   if (.not. colormap3d_ok(colormap, cmap, stat)) return
   call field_range_r32(z, scale_min, scale_max, lo, hi)
   call place_field(d, 3, z)
   m = d%stride / 4_int64
   call series_scratch(1, max(size(z, kind=int64) - 1_int64, 0_int64) * m + 1_int64, gx)
   call series_scratch(2, max(size(z, kind=int64) - 1_int64, 0_int64) * m + 1_int64, gy)
   do j = 1_int64, size(z, 2, kind=int64)
      do i = 1_int64, size(z, 1, kind=int64)
         k = (i - 1_int64) + (j - 1_int64) * size(z, 1, kind=int64)
         gx(1_int64 + k * m) = x(i)
         gy(1_int64 + k * m) = y(j)
      enddo
   enddo
   d%p(1) = c_loc(gx)
   d%p(2) = c_loc(gy)
   call ImPlot3D_PushColormap_Plot3DColormap(cmap)
   call ImPlot3D_PlotSurface_FloatPtr(cstr(label), d%p(1), d%p(2), d%p(3), int(size(z, 1), c_int), &
                                      int(size(z, 2), c_int), lo, hi, spec_at(d%stride, spec))
   call ImPlot3D_PopColormap(1_c_int)
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_surface_r32

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
   type(series_r32), target                                   :: d         !< Where ImPlot3D reads the arrays.
   real(c_double)                                             :: lo        !< Height at the first colour.
   real(c_double)                                             :: hi        !< Height at the last colour.
   integer(c_int)                                             :: cmap      !< ImPlot3D colormap id.

   if (.not. grid_ok(shape(x, kind=int64), shape(y, kind=int64), shape(z, kind=int64), stat)) return
   if (.not. surface_ok(size(z, 1, kind=int64), size(z, 2, kind=int64), size(z, 1, kind=int64), &
                        size(z, 2, kind=int64), scale_min, scale_max, stat)) return
   if (.not. colormap3d_ok(colormap, cmap, stat)) return
   call field_range_r32(z, scale_min, scale_max, lo, hi)
   call place_field(d, 3, z)
   call place_field(d, 1, x, d%stride)
   call place_field(d, 2, y, d%stride)
   call ImPlot3D_PushColormap_Plot3DColormap(cmap)
   call ImPlot3D_PlotSurface_FloatPtr(cstr(label), d%p(1), d%p(2), d%p(3), int(size(z, 1), c_int), &
                                      int(size(z, 2), c_int), lo, hi, spec_at(d%stride, spec))
   call ImPlot3D_PopColormap(1_c_int)
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_surface_grid_r32

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
   type(series_r32), target                                   :: d              !< Where ImPlot3D reads the arrays.

   if (item_refused('ip3_mesh', size(x, kind=int64), size(y, kind=int64), size(z, kind=int64), stat)) return
   if (.not. triangles_ok(triangles, size(x, kind=int64), stat)) return
   call series_lead(d, 1, x)
   call series_put(d, 2, y)
   call series_put(d, 3, z)
   call ImPlot3D_PlotMesh_FloatPtr(cstr(label), d%p(1), d%p(2), d%p(3), c_loc(mesh_index), int(size(x), c_int), &
                                   int(size(triangles), c_int), spec_at(d%stride, spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_mesh_r32

   ! items, double precision

   recursive subroutine ip3_line_r64(label, x, y, z, spec, stat)
   !< A line through the points (x(i), y(i), z(i)), double precision; read in place with any stride. Statuses:
   !< `FIG_ERR_ARGUMENT` for series of different sizes; `FIG_ERR_STATE` outside a 3-D plot, from a task.
   character(len=*),         intent(in)                       :: label !< Legend label.
   real(real64),             intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),             intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real64),             intent(in), target, asynchronous :: z(:)  !< Heights.
   type(plot3d_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot3D's).
   integer(int32),           intent(out), optional            :: stat  !< Status.
   type(series_r64), target                                   :: d     !< Where ImPlot3D reads the arrays.

   if (item_refused('ip3_line', size(x, kind=int64), size(y, kind=int64), size(z, kind=int64), stat)) return
   call series_lead(d, 1, x)
   call series_put(d, 2, y)
   call series_put(d, 3, z)
   call ImPlot3D_PlotLine_doublePtr(cstr(label), d%p(1), d%p(2), d%p(3), int(size(x), c_int), spec_at(d%stride, spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_line_r64

   recursive subroutine ip3_scatter_r64(label, x, y, z, spec, stat)
   !< Markers at the points (x(i), y(i), z(i)), double precision; read in place with any stride. Statuses as
   !< `ip3_line`.
   character(len=*),         intent(in)                       :: label !< Legend label.
   real(real64),             intent(in), target, asynchronous :: x(:)  !< Abscissae.
   real(real64),             intent(in), target, asynchronous :: y(:)  !< Ordinates.
   real(real64),             intent(in), target, asynchronous :: z(:)  !< Heights.
   type(plot3d_spec_object), intent(in), optional             :: spec  !< Style (default: ImPlot3D's).
   integer(int32),           intent(out), optional            :: stat  !< Status.
   type(series_r64), target                                   :: d     !< Where ImPlot3D reads the arrays.

   if (item_refused('ip3_scatter', size(x, kind=int64), size(y, kind=int64), size(z, kind=int64), stat)) return
   call series_lead(d, 1, x)
   call series_put(d, 2, y)
   call series_put(d, 3, z)
   call ImPlot3D_PlotScatter_doublePtr(cstr(label), d%p(1), d%p(2), d%p(3), int(size(x), c_int), spec_at(d%stride, spec))
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_scatter_r64

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
   type(series_r64), target                                   :: d         !< Where ImPlot3D reads the arrays.
   real(real64), pointer, contiguous                          :: gx(:)     !< The grid's abscissae, at the stride.
   real(real64), pointer, contiguous                          :: gy(:)     !< The grid's ordinates, at the stride.
   real(c_double)                                             :: lo        !< Height at the first colour.
   real(c_double)                                             :: hi        !< Height at the last colour.
   integer(c_int)                                             :: cmap      !< ImPlot3D colormap id.
   integer(int64)                                             :: m         !< The item's stride [elements].
   integer(int64)                                             :: i         !< Grid index along x.
   integer(int64)                                             :: j         !< Grid index along y.
   integer(int64)                                             :: k         !< Vertex, from 0.

   if (.not. surface_ok(size(z, 1, kind=int64), size(z, 2, kind=int64), size(x, kind=int64), &
                        size(y, kind=int64), scale_min, scale_max, stat)) return
   if (.not. colormap3d_ok(colormap, cmap, stat)) return
   call field_range_r64(z, scale_min, scale_max, lo, hi)
   call place_field(d, 3, z)
   m = d%stride / 8_int64
   call series_scratch(1, max(size(z, kind=int64) - 1_int64, 0_int64) * m + 1_int64, gx)
   call series_scratch(2, max(size(z, kind=int64) - 1_int64, 0_int64) * m + 1_int64, gy)
   do j = 1_int64, size(z, 2, kind=int64)
      do i = 1_int64, size(z, 1, kind=int64)
         k = (i - 1_int64) + (j - 1_int64) * size(z, 1, kind=int64)
         gx(1_int64 + k * m) = x(i)
         gy(1_int64 + k * m) = y(j)
      enddo
   enddo
   d%p(1) = c_loc(gx)
   d%p(2) = c_loc(gy)
   call ImPlot3D_PushColormap_Plot3DColormap(cmap)
   call ImPlot3D_PlotSurface_doublePtr(cstr(label), d%p(1), d%p(2), d%p(3), int(size(z, 1), c_int), &
                                       int(size(z, 2), c_int), lo, hi, spec_at(d%stride, spec))
   call ImPlot3D_PopColormap(1_c_int)
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_surface_r64

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
   type(series_r64), target                                   :: d         !< Where ImPlot3D reads the arrays.
   real(c_double)                                             :: lo        !< Height at the first colour.
   real(c_double)                                             :: hi        !< Height at the last colour.
   integer(c_int)                                             :: cmap      !< ImPlot3D colormap id.

   if (.not. grid_ok(shape(x, kind=int64), shape(y, kind=int64), shape(z, kind=int64), stat)) return
   if (.not. surface_ok(size(z, 1, kind=int64), size(z, 2, kind=int64), size(z, 1, kind=int64), &
                        size(z, 2, kind=int64), scale_min, scale_max, stat)) return
   if (.not. colormap3d_ok(colormap, cmap, stat)) return
   call field_range_r64(z, scale_min, scale_max, lo, hi)
   call place_field(d, 3, z)
   call place_field(d, 1, x, d%stride)
   call place_field(d, 2, y, d%stride)
   call ImPlot3D_PushColormap_Plot3DColormap(cmap)
   call ImPlot3D_PlotSurface_doublePtr(cstr(label), d%p(1), d%p(2), d%p(3), int(size(z, 1), c_int), &
                                       int(size(z, 2), c_int), lo, hi, spec_at(d%stride, spec))
   call ImPlot3D_PopColormap(1_c_int)
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_surface_grid_r64

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
   type(series_r64), target                                   :: d              !< Where ImPlot3D reads the arrays.

   if (item_refused('ip3_mesh', size(x, kind=int64), size(y, kind=int64), size(z, kind=int64), stat)) return
   if (.not. triangles_ok(triangles, size(x, kind=int64), stat)) return
   call series_lead(d, 1, x)
   call series_put(d, 2, y)
   call series_put(d, 3, z)
   call ImPlot3D_PlotMesh_doublePtr(cstr(label), d%p(1), d%p(2), d%p(3), c_loc(mesh_index), int(size(x), c_int), &
                                    int(size(triangles), c_int), spec_at(d%stride, spec))
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
   type(im_vec2)                           :: o         !< Offset.
   real(c_double)                          :: a         !< Angle.

   if (figure_draw_refused('ip3_text', stat)) return ! a task does not draw
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
   o = im_vec2(0.0_c_float, 0.0_c_float)
   if (present(offset)) o = im_vec2(real(offset(1), c_float), real(offset(2), c_float))
   a = 0.0_c_double
   if (present(angle)) a = real(angle, c_double)
   call ImPlot3D_PlotText(cstr(text), real(x, c_double), real(y, c_double), real(z, c_double), a, o)
   call figure_check(FIG_OK, stat)
   endsubroutine ip3_text

   ! helpers

   recursive function outside_plot(caller, stat) result(refused)
   !< True (a usage error reported) when no 3-D plot is being declared: ImPlot3D asserts there.
   character(len=*), intent(in)            :: caller  !< The procedure.
   integer(int32),   intent(out), optional :: stat    !< Status, on a refusal.
   logical                                 :: refused !< Refused: return.

   refused = fig_plot3d_state() == 0_c_int
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
   if (figure_draw_refused(caller, stat)) return ! a task does not draw
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
   if (figure_draw_refused('ip3_surface', stat)) return ! a task does not draw
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

   recursive function grid_ok(sx, sy, sz, stat) result(ok)
   !< Whether the vertex arrays of a surface over a grid all have z's shape (`FIG_ERR_ARGUMENT` otherwise).
   integer(int64), intent(in)            :: sx(2) !< Shape of x.
   integer(int64), intent(in)            :: sy(2) !< Shape of y.
   integer(int64), intent(in)            :: sz(2) !< Shape of z.
   integer(int32), intent(out), optional :: stat  !< Status, on a refusal.
   logical                               :: ok    !< Same shapes.

   ok = all(sx == sz) .and. all(sy == sz)
   if (.not. ok) call figure_fail(FIG_ERR_ARGUMENT, 'ip3_surface: x, y and z of a grid must have the same shape', stat)
   endfunction grid_ok

   recursive function colormap3d_ok(colormap, cmap, stat) result(ok)
   !< The ImPlot3D id of the colormap to draw with (default Viridis), copied from FIGURE's registry; false, with
   !< `FIG_ERR_ARGUMENT`, if it is not registered.
   integer(int32), intent(in),  optional :: colormap !< Colormap (`ip_colormap`), if given.
   integer(c_int), intent(out)           :: cmap     !< ImPlot3D id.
   integer(int32), intent(out), optional :: stat     !< Status, on a failure.
   logical                               :: ok       !< Usable.
   integer(c_int)                        :: id       !< ImPlot id.
   integer(c_int)                        :: status   !< Native status.

   id = int(ImPlotColormap_Viridis, c_int)
   if (present(colormap)) id = int(colormap, c_int)
   cmap = -1_c_int
   status = fig_plot3d_colormap(id, cmap)
   ok = status == FIG_OK
   if (.not. ok) call figure_check(status, stat)
   endfunction colormap3d_ok

   recursive function triangles_ok(triangles, nv, stat) result(ok)
   !< Whether a mesh's triangles are 3 rows of vertices in [1, nv] and a count a C int holds (`FIG_ERR_ARGUMENT`
   !< otherwise); if so, their 0-based indices are in `mesh_index`.
   integer(int32), intent(in)            :: triangles(:,:) !< Vertices of each triangle.
   integer(int64), intent(in)            :: nv             !< Vertices.
   integer(int32), intent(out), optional :: stat           !< Status, on a refusal.
   logical                               :: ok             !< Drawable.
   integer(int64)                        :: n              !< Indices.
   integer(int64)                        :: k              !< Triangle.

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
   if (allocated(mesh_index)) then
      if (size(mesh_index, kind=int64) < max(n, 1_int64)) deallocate(mesh_index)
   endif
   if (.not. allocated(mesh_index)) allocate(mesh_index(max(n, 1_int64)))
   do k = 1_int64, size(triangles, 2, kind=int64)
      mesh_index(3_int64 * k - 2_int64:3_int64 * k) = int(triangles(:, k) - 1_int32, c_int)
   enddo
   plot_copies = plot_copies + 1_int64
   ok = .true.
   endfunction triangles_ok

   subroutine field_range_r32(z, scale_min, scale_max, lo, hi)
   !< The heights at a surface's first and last colours: the given ones, else z's finite range (widened by one about
   !< its centre when z is flat: ImPlot3D would divide by a zero range, an FPE under traps).
   real(real32),   intent(in), asynchronous :: z(:,:)    !< Heights.
   real(real64),   intent(in), optional     :: scale_min !< Given first height.
   real(real64),   intent(in), optional     :: scale_max !< Given last height.
   real(c_double), intent(out)              :: lo        !< First height.
   real(c_double), intent(out)              :: hi        !< Last height.

   if (present(scale_min)) then
      lo = real(scale_min, c_double)
      hi = real(scale_max, c_double)
      return
   endif
   lo = real(minval(z, mask=ieee_is_finite(z)), c_double)
   hi = real(maxval(z, mask=ieee_is_finite(z)), c_double)
   if (.not. lo < hi) then
      if (.not. (ieee_is_finite(lo) .and. ieee_is_finite(hi))) then
         lo = 0.0_c_double
         hi = 0.0_c_double
      endif
      lo = lo - 0.5_c_double
      hi = hi + 0.5_c_double
   endif
   endsubroutine field_range_r32

   subroutine field_range_r64(z, scale_min, scale_max, lo, hi)
   !< The heights at a surface's first and last colours: the given ones, else z's finite range (widened by one about
   !< its centre when z is flat: ImPlot3D would divide by a zero range, an FPE under traps).
   real(real64),   intent(in), asynchronous :: z(:,:)    !< Heights.
   real(real64),   intent(in), optional     :: scale_min !< Given first height.
   real(real64),   intent(in), optional     :: scale_max !< Given last height.
   real(c_double), intent(out)              :: lo        !< First height.
   real(c_double), intent(out)              :: hi        !< Last height.

   if (present(scale_min)) then
      lo = real(scale_min, c_double)
      hi = real(scale_max, c_double)
      return
   endif
   lo = real(minval(z, mask=ieee_is_finite(z)), c_double)
   hi = real(maxval(z, mask=ieee_is_finite(z)), c_double)
   if (.not. lo < hi) then
      if (.not. (ieee_is_finite(lo) .and. ieee_is_finite(hi))) then
         lo = 0.0_c_double
         hi = 0.0_c_double
      endif
      lo = lo - 0.5_c_double
      hi = hi + 0.5_c_double
   endif
   endsubroutine field_range_r64

   subroutine place_field_r32(d, k, a, stride)
   !< Place a rank-2 array of a surface in slot `k`, single precision: in place when its elements are equally spaced
   !< in memory (column after column) at a positive multiple of the element size within a C int and, when `stride` is
   !< given (the item's, set by the field), at that stride; otherwise copied into the slot's scratch, at `stride` or
   !< contiguous (then the item's stride becomes the element size).
   type(series_r32), intent(inout)                    :: d      !< The item's arrays.
   integer(int32),   intent(in)                       :: k      !< Slot.
   real(real32),     intent(in), target, asynchronous :: a(:,:) !< Array.
   integer(int64),   intent(in), optional             :: stride !< The item's stride [bytes].
   real(real32), pointer, contiguous                  :: v(:)   !< The slot's scratch.
   integer(int64)                                     :: es     !< Element size [bytes].
   integer(int64)                                     :: s      !< Its stride [bytes]; 0: not equally spaced.
   integer(int64)                                     :: m      !< Stride of a copy [elements].
   integer(int64)                                     :: n      !< Elements.

   es = storage_size(a, kind=int64) / 8_int64
   n = size(a, kind=int64)
   if (.not. present(stride)) d%stride = es
   if (n == 0_int64) return
   s = es
   if (size(a, 1) > 1) then
      s = series_gap(c_loc(a(1, 1)), c_loc(a(2, 1)))
      if (size(a, 2) > 1) then
         if (series_gap(c_loc(a(1, 1)), c_loc(a(1, 2))) /= s * size(a, 1, kind=int64)) s = 0_int64
      endif
   elseif (size(a, 2) > 1) then
      s = series_gap(c_loc(a(1, 1)), c_loc(a(1, 2)))
   endif
   if (s <= 0_int64 .or. mod(s, es) /= 0_int64 .or. s > int(huge(0_c_int), int64)) s = 0_int64
   if (present(stride)) then
      if (s /= stride) s = 0_int64
   endif
   if (s > 0_int64) then
      d%p(k) = c_loc(a(1, 1))
      if (.not. present(stride)) d%stride = s
      return
   endif
   m = 1_int64
   if (present(stride)) m = stride / es
   call series_scratch(k, (n - 1_int64) * m + 1_int64, v)
   v(1_int64:(n - 1_int64) * m + 1_int64:m) = reshape(a, [n])
   d%p(k) = c_loc(v)
   endsubroutine place_field_r32

   subroutine place_field_r64(d, k, a, stride)
   !< Place a rank-2 array of a surface in slot `k`, double precision: in place when its elements are equally spaced
   !< in memory (column after column) at a positive multiple of the element size within a C int and, when `stride` is
   !< given (the item's, set by the field), at that stride; otherwise copied into the slot's scratch, at `stride` or
   !< contiguous (then the item's stride becomes the element size).
   type(series_r64), intent(inout)                    :: d      !< The item's arrays.
   integer(int32),   intent(in)                       :: k      !< Slot.
   real(real64),     intent(in), target, asynchronous :: a(:,:) !< Array.
   integer(int64),   intent(in), optional             :: stride !< The item's stride [bytes].
   real(real64), pointer, contiguous                  :: v(:)   !< The slot's scratch.
   integer(int64)                                     :: es     !< Element size [bytes].
   integer(int64)                                     :: s      !< Its stride [bytes]; 0: not equally spaced.
   integer(int64)                                     :: m      !< Stride of a copy [elements].
   integer(int64)                                     :: n      !< Elements.

   es = storage_size(a, kind=int64) / 8_int64
   n = size(a, kind=int64)
   if (.not. present(stride)) d%stride = es
   if (n == 0_int64) return
   s = es
   if (size(a, 1) > 1) then
      s = series_gap(c_loc(a(1, 1)), c_loc(a(2, 1)))
      if (size(a, 2) > 1) then
         if (series_gap(c_loc(a(1, 1)), c_loc(a(1, 2))) /= s * size(a, 1, kind=int64)) s = 0_int64
      endif
   elseif (size(a, 2) > 1) then
      s = series_gap(c_loc(a(1, 1)), c_loc(a(1, 2)))
   endif
   if (s <= 0_int64 .or. mod(s, es) /= 0_int64 .or. s > int(huge(0_c_int), int64)) s = 0_int64
   if (present(stride)) then
      if (s /= stride) s = 0_int64
   endif
   if (s > 0_int64) then
      d%p(k) = c_loc(a(1, 1))
      if (.not. present(stride)) d%stride = s
      return
   endif
   m = 1_int64
   if (present(stride)) m = stride / es
   call series_scratch(k, (n - 1_int64) * m + 1_int64, v)
   v(1_int64:(n - 1_int64) * m + 1_int64:m) = reshape(a, [n])
   d%p(k) = c_loc(v)
   endsubroutine place_field_r64

   function spec_at(stride, spec) result(c)
   !< The C spec to pass: the given one, or ImPlot3D's defaults, with the item's stride (`test_plot_stride` reads it).
   integer(int64),           intent(in)           :: stride !< The item's stride [bytes].
   type(plot3d_spec_object), intent(in), optional :: spec   !< Style.
   type(im_plot3d_spec)                           :: c      !< `ImPlot3DSpec`.

   if (present(spec)) then
      c = spec%c
   else
      call figure_ImPlot3DSpec_default(c)
   endif
   c%Stride = int(stride, c_int)
   plot_stride = stride
   endfunction spec_at

   pure function rgba_ok(color) result(ok)
   !< Whether an optional colour is absent or has 4 components.
   real(real64), intent(in), optional :: color(:) !< Colour, RGBA.
   logical                            :: ok       !< Acceptable.

   ok = .true.
   if (present(color)) ok = size(color) == 4
   endfunction rgba_ok

   pure function rgba(color) result(v)
   !< RGBA colour as an `ImVec4`.
   real(real64), intent(in) :: color(:) !< Colour, RGBA, 4 components.
   type(im_vec4)            :: v        !< Colour.

   v = im_vec4(real(color(1), c_float), real(color(2), c_float), real(color(3), c_float), real(color(4), c_float))
   endfunction rgba
endmodule figure_implot3d
