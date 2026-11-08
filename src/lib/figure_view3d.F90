!< figure_view3d, a 3-D view of meshes (view3d_object), drawn by FIGURE's software rasterizer in every mode.
module figure_view3d
!< figure_view3d, a 3-D view of meshes (view3d_object), drawn by FIGURE's software rasterizer in every mode.
!<
!< A view holds meshes (triangles, quads, structured surfaces, lines), each optionally coloured by a scalar per vertex
!< or per cell through a colormap (`ip_colormap`'s names), a camera (orbit, pan, zoom, fit, six standard views) and
!< clipping planes; `v%draw(id, width, height)` draws it as a widget inside any window. The image is rendered on the
!< CPU (native/figure_view3d.cpp) into a texture, so window, remote and headless modes show the same pixels; it is
!< rendered again only when something changed.
!<
!<```fortran
!< type(view3d_object)       :: v
!< real(real64), target      :: xyz(3, 40, 20), p(40, 20)
!< integer(int32)            :: wing
!< call v%init()
!< wing = v%surface(xyz, scalar=p, colormap='cool-warm')   ! the arrays are read in place, at every render
!< ... every frame, inside a window:
!< call v%draw('view', 0.0_real64, 0.0_real64)               ! the available region
!< if (v%clicked(mesh, element)) ...                        ! the element clicked
!<```
!<
!< **Data in place.** The view keeps the addresses of the program's arrays (coordinates, connectivity, scalars): they
!< must have the `target` (or `pointer`) attribute, be contiguous, and stay allocated while the mesh exists. After
!< changing their values, call `v%changed(mesh)`: the normals, the scalar's range and the connectivity's checks are
!< derived again and the view is rendered at the next draw.
use, intrinsic :: iso_c_binding, only : c_char, c_double, c_int, c_long_long, c_loc, c_null_ptr, c_ptr
use, intrinsic :: iso_fortran_env, only : int8, int32, int64, real64
use figure_base, only : figure_check, figure_fail, figure_refused
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK

implicit none
private
public :: view3d_object

type :: view3d_object
   !< A 3-D view: `v%init`, meshes added, then `v%draw` every frame. Not to be copied (the copy would share the view).
   integer(c_int), private :: handle = 0_c_int !< Native handle (0: none).
   contains
      procedure, pass(self) :: init            !< Create the view.
      procedure, pass(self) :: destroy         !< Release it.
      procedure, pass(self) :: is_initialized  !< Whether it exists.
      procedure, pass(self) :: triangles       !< Add a triangle mesh.
      procedure, pass(self) :: quads           !< Add a quad mesh.
      procedure, pass(self) :: surface         !< Add a structured surface.
      procedure, pass(self) :: lines           !< Add lines.
      procedure, pass(self) :: set_mesh        !< Change a mesh's scalar or style.
      procedure, pass(self) :: remove          !< Remove a mesh.
      procedure, pass(self) :: clear           !< Remove every mesh.
      procedure, pass(self) :: changed         !< The data of a mesh changed in place.
      procedure, pass(self) :: set_camera      !< Set the camera.
      procedure, pass(self) :: get_camera      !< Read the camera.
      procedure, pass(self) :: fit             !< Fit the meshes in the view.
      procedure, pass(self) :: view            !< One of the six standard views.
      procedure, pass(self) :: orbit           !< Turn the camera around its target.
      procedure, pass(self) :: pan             !< Move the camera and its target across the screen.
      procedure, pass(self) :: zoom            !< Move the camera toward its target.
      procedure, pass(self) :: clip            !< Add a clipping plane.
      procedure, pass(self) :: unclip          !< Remove the clipping planes.
      procedure, pass(self) :: draw            !< Draw the view as a widget.
      procedure, pass(self) :: pick            !< The element under a pixel.
      procedure, pass(self) :: hovered         !< The element under the mouse.
      procedure, pass(self) :: clicked         !< The element clicked.
      procedure, pass(self) :: image           !< The pixels of the last render.
      procedure, pass(self) :: render_info     !< Renders so far, the last one's time and size.
endtype view3d_object

integer(c_int), parameter :: K_TRIANGLES = 0_c_int !< Mesh kinds of the native layer.
integer(c_int), parameter :: K_QUADS     = 1_c_int !< Quads.
integer(c_int), parameter :: K_SURFACE   = 2_c_int !< Structured surface.
integer(c_int), parameter :: K_LINES     = 3_c_int !< Lines.

interface
   function fig_view3d_create(threads, fast_moves, lighting, background, handle) result(status) &
      bind(C, name='fig_view3d_create')
   import :: c_int, c_ptr
   implicit none
   integer(c_int), value       :: threads, fast_moves, lighting
   type(c_ptr),    value       :: background
   integer(c_int), intent(out) :: handle
   integer(c_int)              :: status
   endfunction fig_view3d_create

   subroutine fig_view3d_destroy(handle) bind(C, name='fig_view3d_destroy')
   import :: c_int
   implicit none
   integer(c_int), value :: handle
   endsubroutine fig_view3d_destroy

   function fig_view3d_mesh(handle, kind, xyz, nv, conn, ncell, ni, nj, mesh) result(status) &
      bind(C, name='fig_view3d_mesh')
   import :: c_int, c_long_long, c_ptr
   implicit none
   integer(c_int),       value       :: handle, kind
   type(c_ptr),          value       :: xyz
   integer(c_long_long), value       :: nv
   type(c_ptr),          value       :: conn
   integer(c_long_long), value       :: ncell
   integer(c_int),       value       :: ni, nj
   integer(c_int),       intent(out) :: mesh
   integer(c_int)                    :: status
   endfunction fig_view3d_mesh

   function fig_view3d_scalar(handle, mesh, scalar, n, on_cells) result(status) bind(C, name='fig_view3d_scalar')
   import :: c_int, c_long_long, c_ptr
   implicit none
   integer(c_int),       value :: handle, mesh
   type(c_ptr),          value :: scalar
   integer(c_long_long), value :: n
   integer(c_int),       value :: on_cells
   integer(c_int)              :: status
   endfunction fig_view3d_scalar

   function fig_view3d_style(handle, mesh, colormap, colormap_len, set_range, vmin, vmax, color, edges, edge_color, &
                             flat, visible) result(status) bind(C, name='fig_view3d_style')
   import :: c_char, c_double, c_int, c_ptr
   implicit none
   integer(c_int),         value      :: handle, mesh
   character(kind=c_char), intent(in) :: colormap(*)
   integer(c_int),         value      :: colormap_len, set_range
   real(c_double),         value      :: vmin, vmax
   type(c_ptr),            value      :: color
   integer(c_int),         value      :: edges
   type(c_ptr),            value      :: edge_color
   integer(c_int),         value      :: flat, visible
   integer(c_int)                     :: status
   endfunction fig_view3d_style

   function fig_view3d_remove(handle, mesh) result(status) bind(C, name='fig_view3d_remove')
   import :: c_int
   implicit none
   integer(c_int), value :: handle, mesh
   integer(c_int)        :: status
   endfunction fig_view3d_remove

   function fig_view3d_changed(handle, mesh) result(status) bind(C, name='fig_view3d_changed')
   import :: c_int
   implicit none
   integer(c_int), value :: handle, mesh
   integer(c_int)        :: status
   endfunction fig_view3d_changed

   function fig_view3d_camera(handle, set, mask, target, distance, azimuth, elevation, fov) result(status) &
      bind(C, name='fig_view3d_camera')
   import :: c_double, c_int
   implicit none
   integer(c_int), value         :: handle, set, mask
   real(c_double), intent(inout) :: target(3), distance, azimuth, elevation, fov
   integer(c_int)                :: status
   endfunction fig_view3d_camera

   function fig_view3d_fit(handle) result(status) bind(C, name='fig_view3d_fit')
   import :: c_int
   implicit none
   integer(c_int), value :: handle
   integer(c_int)        :: status
   endfunction fig_view3d_fit

   function fig_view3d_standard(handle, which) result(status) bind(C, name='fig_view3d_standard')
   import :: c_int
   implicit none
   integer(c_int), value :: handle, which
   integer(c_int)        :: status
   endfunction fig_view3d_standard

   function fig_view3d_move(handle, d_azimuth, d_elevation, pan_right, pan_up, zoom) result(status) &
      bind(C, name='fig_view3d_move')
   import :: c_double, c_int
   implicit none
   integer(c_int), value :: handle
   real(c_double), value :: d_azimuth, d_elevation, pan_right, pan_up, zoom
   integer(c_int)        :: status
   endfunction fig_view3d_move

   function fig_view3d_clip(handle, normal, point) result(status) bind(C, name='fig_view3d_clip')
   import :: c_double, c_int
   implicit none
   integer(c_int), value      :: handle
   real(c_double), intent(in) :: normal(3), point(3)
   integer(c_int)             :: status
   endfunction fig_view3d_clip

   function fig_view3d_unclip(handle) result(status) bind(C, name='fig_view3d_unclip')
   import :: c_int
   implicit none
   integer(c_int), value :: handle
   integer(c_int)        :: status
   endfunction fig_view3d_unclip

   function fig_view3d_draw(handle, id, id_len, width, height) result(status) bind(C, name='fig_view3d_draw')
   import :: c_char, c_double, c_int
   implicit none
   integer(c_int),         value      :: handle
   character(kind=c_char), intent(in) :: id(*)
   integer(c_int),         value      :: id_len
   real(c_double),         value      :: width, height
   integer(c_int)                     :: status
   endfunction fig_view3d_draw

   function fig_view3d_pick(handle, what, x, y, hit, mesh, element, point) result(status) bind(C, name='fig_view3d_pick')
   import :: c_double, c_int, c_long_long
   implicit none
   integer(c_int),       value       :: handle, what
   real(c_double),       value       :: x, y
   integer(c_int),       intent(out) :: hit, mesh
   integer(c_long_long), intent(out) :: element
   real(c_double),       intent(out) :: point(3)
   integer(c_int)                    :: status
   endfunction fig_view3d_pick

   function fig_view3d_image(handle, rgba, cap, width, height) result(status) bind(C, name='fig_view3d_image')
   import :: c_int, c_long_long, c_ptr
   implicit none
   integer(c_int),       value       :: handle
   type(c_ptr),          value       :: rgba
   integer(c_long_long), value       :: cap
   integer(c_int),       intent(out) :: width, height
   integer(c_int)                    :: status
   endfunction fig_view3d_image

   function fig_view3d_info(handle, renders, ms, width, height, half) result(status) bind(C, name='fig_view3d_info')
   import :: c_double, c_int
   implicit none
   integer(c_int), value       :: handle
   integer(c_int), intent(out) :: renders
   real(c_double), intent(out) :: ms
   integer(c_int), intent(out) :: width, height, half
   integer(c_int)              :: status
   endfunction fig_view3d_info
endinterface

contains
   recursive subroutine init(self, threads, fast_moves, lighting, background, stat)
   !< Create the view (an existing one is destroyed first). After `app%init*`. Statuses: `FIG_ERR_ARGUMENT` for
   !< `threads` outside [1, 4]; `FIG_ERR_STATE` from a task. The same in every mode.
   class(view3d_object), intent(inout)         :: self          !< View.
   integer(int32),       intent(in),  optional :: threads       !< Threads rendering bands of rows, in [1, 4] (default 1).
   logical,              intent(in),  optional :: fast_moves    !< Half resolution while the user moves the camera
                                                                 !< (default true).
   logical,              intent(in),  optional :: lighting      !< Shade by a light at the eye (default true); off: the
                                                                 !< colours as given.
   real(real64),         intent(in),  optional, target :: background(3) !< Background `[r, g, b]` in [0, 1] (default:
                                                                 !< the style's window background).
   integer(int32),       intent(out), optional :: stat          !< Status.
   integer(c_int)                              :: t, f, l       !< Native flags.
   real(c_double), target                      :: bg(3)         !< Background.
   type(c_ptr)                                 :: pbg           !< ... or none.

   if (figure_refused('view3d_object%init', stat)) return ! a task does not draw
   call self%destroy()
   t = 1_c_int
   if (present(threads)) t = int(threads, c_int)
   f = 1_c_int
   if (present(fast_moves)) f = merge(1_c_int, 0_c_int, fast_moves)
   l = 1_c_int
   if (present(lighting)) l = merge(1_c_int, 0_c_int, lighting)
   pbg = c_null_ptr
   if (present(background)) then
      bg = real(background, c_double)
      pbg = c_loc(bg)
   endif
   call figure_check(fig_view3d_create(t, f, l, pbg, self%handle), stat)
   endsubroutine init

   subroutine destroy(self)
   !< Release the view and its textures (safe in any state; the program's arrays are not touched).
   class(view3d_object), intent(inout) :: self !< View.

   if (self%handle /= 0_c_int) call fig_view3d_destroy(self%handle)
   self%handle = 0_c_int
   endsubroutine destroy

   pure function is_initialized(self) result(yes)
   !< Whether the view exists.
   class(view3d_object), intent(in) :: self !< View.
   logical                          :: yes  !< Initialized.

   yes = self%handle /= 0_c_int
   endfunction is_initialized

   recursive function triangles(self, xyz, tri, scalar, cell_scalar, colormap, color, edges, flat, stat) result(mesh)
   !< Add a mesh of triangles: vertex `k` at `xyz(:, k)`, triangle `t` joining the vertices `tri(:, t)` (from 1).
   !< Returns the mesh's id (from 1; 0 on a failure). The arrays are kept by address (see the module's notes on data in
   !< place). Statuses: `FIG_ERR_ARGUMENT` for a non-contiguous array, an index outside [1, size(xyz, 2)] or a scalar
   !< of the wrong size; `FIG_ERR_STATE` before `init` and from a task.
   class(view3d_object),   intent(in)                   :: self           !< View.
   real(real64),           intent(in),         target   :: xyz(:,:)       !< Vertices, `xyz(3, nv)`.
   integer(int32),         intent(in),         target   :: tri(:,:)       !< Triangles, `tri(3, nt)`.
   real(real64),           intent(in), optional, target :: scalar(:)      !< A value per vertex, by the colormap.
   real(real64),           intent(in), optional, target :: cell_scalar(:) !< A value per triangle (one colour each).
   character(len=*),       intent(in), optional         :: colormap       !< Colormap name (default `'cividis'`).
   real(real64),           intent(in), optional         :: color(3)       !< Colour without a scalar `[r, g, b]`.
   logical,                intent(in), optional         :: edges          !< Draw the triangles' edges (default false).
   logical,                intent(in), optional         :: flat           !< Flat shading (default false: smooth).
   integer(int32),         intent(out), optional        :: stat           !< Status.
   integer(int32)                                       :: mesh           !< Mesh id.

   mesh = 0_int32
   if (figure_refused('view3d_object%triangles', stat)) return
   if (.not. connectivity_ok('triangles', xyz, tri, 3, stat)) return
   mesh = add_mesh(self, K_TRIANGLES, c_loc(xyz(1, 1)), size(xyz, 2, int64), c_loc(tri(1, 1)), size(tri, 2, int64), &
                   0, 0, stat)
   if (mesh > 0_int32) call style_new(self, mesh, scalar, cell_scalar, colormap, color, edges, flat, stat)
   endfunction triangles

   recursive function quads(self, xyz, quad, scalar, cell_scalar, colormap, color, edges, flat, stat) result(mesh)
   !< Add a mesh of quadrilaterals `quad(4, nq)` (vertices from 1, in order around each), each drawn as two triangles;
   !< as `triangles` otherwise. A picked element is a quad.
   class(view3d_object),   intent(in)                   :: self           !< View.
   real(real64),           intent(in),         target   :: xyz(:,:)       !< Vertices, `xyz(3, nv)`.
   integer(int32),         intent(in),         target   :: quad(:,:)      !< Quads, `quad(4, nq)`.
   real(real64),           intent(in), optional, target :: scalar(:)      !< A value per vertex.
   real(real64),           intent(in), optional, target :: cell_scalar(:) !< A value per quad.
   character(len=*),       intent(in), optional         :: colormap       !< Colormap name (default `'cividis'`).
   real(real64),           intent(in), optional         :: color(3)       !< Colour without a scalar `[r, g, b]`.
   logical,                intent(in), optional         :: edges          !< Draw the quads' edges (default false).
   logical,                intent(in), optional         :: flat           !< Flat shading (default false).
   integer(int32),         intent(out), optional        :: stat           !< Status.
   integer(int32)                                       :: mesh           !< Mesh id.

   mesh = 0_int32
   if (figure_refused('view3d_object%quads', stat)) return
   if (.not. connectivity_ok('quads', xyz, quad, 4, stat)) return
   mesh = add_mesh(self, K_QUADS, c_loc(xyz(1, 1)), size(xyz, 2, int64), c_loc(quad(1, 1)), size(quad, 2, int64), &
                   0, 0, stat)
   if (mesh > 0_int32) call style_new(self, mesh, scalar, cell_scalar, colormap, color, edges, flat, stat)
   endfunction quads

   recursive function surface(self, xyz, scalar, cell_scalar, colormap, color, edges, flat, stat) result(mesh)
   !< Add a structured surface: node `(i, j)` at `xyz(:, i, j)`, cells between neighbouring nodes (a grid's face, a
   !< body's patch). `scalar(ni, nj)` per node, or `cell_scalar(ni-1, nj-1)` per cell; `edges` draws the grid lines. A
   !< picked element is the cell `i + (j - 1) * (ni - 1)`. As `triangles` otherwise.
   class(view3d_object),   intent(in)                   :: self             !< View.
   real(real64),           intent(in),         target   :: xyz(:,:,:)       !< Nodes, `xyz(3, ni, nj)`.
   real(real64),           intent(in), optional, target :: scalar(:,:)      !< A value per node, `(ni, nj)`.
   real(real64),           intent(in), optional, target :: cell_scalar(:,:) !< A value per cell, `(ni-1, nj-1)`.
   character(len=*),       intent(in), optional         :: colormap         !< Colormap name (default `'cividis'`).
   real(real64),           intent(in), optional         :: color(3)         !< Colour without a scalar.
   logical,                intent(in), optional         :: edges            !< Draw the grid lines (default false).
   logical,                intent(in), optional         :: flat             !< Flat shading (default false).
   integer(int32),         intent(out), optional        :: stat             !< Status.
   integer(int32)                                       :: mesh             !< Mesh id.

   mesh = 0_int32
   if (figure_refused('view3d_object%surface', stat)) return
   if (size(xyz, 1) /= 3 .or. size(xyz, 2) < 2 .or. size(xyz, 3) < 2) then
      call figure_fail(FIG_ERR_ARGUMENT, 'view3d_object%surface: xyz must be (3, ni, nj) with ni, nj >= 2', stat)
      return
   endif
   if (.not. is_contiguous(xyz)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'view3d_object%surface: xyz must be contiguous (it is kept by address)', stat)
      return
   endif
   if (present(scalar)) then
      if (.not. is_contiguous(scalar)) then
         call figure_fail(FIG_ERR_ARGUMENT, 'view3d_object%surface: scalar must be contiguous', stat)
         return
      endif
   endif
   if (present(cell_scalar)) then
      if (.not. is_contiguous(cell_scalar)) then
         call figure_fail(FIG_ERR_ARGUMENT, 'view3d_object%surface: cell_scalar must be contiguous', stat)
         return
      endif
   endif
   mesh = add_mesh(self, K_SURFACE, c_loc(xyz(1, 1, 1)), size(xyz, 2, int64) * size(xyz, 3, int64), c_null_ptr, &
                   0_int64, size(xyz, 2), size(xyz, 3), stat)
   if (mesh <= 0_int32) return
   if (present(scalar)) then
      if (.not. scalar_set(self, mesh, c_loc(scalar(1, 1)), size(scalar, kind=int64), .false., stat)) return
   endif
   if (present(cell_scalar)) then
      if (.not. scalar_set(self, mesh, c_loc(cell_scalar(1, 1)), size(cell_scalar, kind=int64), .true., stat)) return
   endif
   call style_new(self, mesh, colormap=colormap, color=color, edges=edges, flat=flat, stat=stat)
   endfunction surface

   recursive function lines(self, xyz, seg, scalar, cell_scalar, colormap, color, stat) result(mesh)
   !< Add lines, one pixel wide: the segments `seg(2, ns)` (vertices from 1), or without `seg` the polyline through the
   !< points in order. Coloured by `scalar` per point, `cell_scalar` per segment, or `color` (default light grey).
   !< Lines are not picked and do not hide what is behind them. As `triangles` otherwise.
   class(view3d_object),   intent(in)                   :: self           !< View.
   real(real64),           intent(in),         target   :: xyz(:,:)       !< Points, `xyz(3, np)`.
   integer(int32),         intent(in), optional, target :: seg(:,:)       !< Segments, `seg(2, ns)`.
   real(real64),           intent(in), optional, target :: scalar(:)      !< A value per point.
   real(real64),           intent(in), optional, target :: cell_scalar(:) !< A value per segment.
   character(len=*),       intent(in), optional         :: colormap       !< Colormap name (default `'cividis'`).
   real(real64),           intent(in), optional         :: color(3)       !< Colour without a scalar `[r, g, b]`.
   integer(int32),         intent(out), optional        :: stat           !< Status.
   integer(int32)                                       :: mesh           !< Mesh id.

   mesh = 0_int32
   if (figure_refused('view3d_object%lines', stat)) return
   if (present(seg)) then
      if (.not. connectivity_ok('lines', xyz, seg, 2, stat)) return
      mesh = add_mesh(self, K_LINES, c_loc(xyz(1, 1)), size(xyz, 2, int64), c_loc(seg(1, 1)), size(seg, 2, int64), &
                      0, 0, stat)
   else
      if (.not. points_ok('lines', xyz, stat)) return
      mesh = add_mesh(self, K_LINES, c_loc(xyz(1, 1)), size(xyz, 2, int64), c_null_ptr, 0_int64, 0, 0, stat)
   endif
   if (mesh > 0_int32) call style_new(self, mesh, scalar, cell_scalar, colormap, color, stat=stat)
   endfunction lines

   recursive subroutine set_mesh(self, mesh, scalar, cell_scalar, no_scalar, colormap, vmin, vmax, auto_range, color, &
                                 edges, edge_color, flat, visible, stat)
   !< Change a mesh: its scalar (per vertex, per cell, or none), colormap, range (`vmin`, `vmax` together, or
   !< `auto_range`: the data's), colour, edges and their colour, shading, visibility. Arguments absent: unchanged. For
   !< a structured surface, pass its scalar as a contiguous array of `ni*nj` (or `(ni-1)*(nj-1)`) values. Statuses:
   !< `FIG_ERR_ARGUMENT` for an unknown mesh, a colormap name or a scalar size, `vmax <= vmin` or one of them alone.
   class(view3d_object), intent(in)                   :: self           !< View.
   integer(int32),       intent(in)                   :: mesh           !< Mesh id.
   real(real64),         intent(in), optional, target :: scalar(:)      !< A value per vertex (node).
   real(real64),         intent(in), optional, target :: cell_scalar(:) !< A value per cell.
   logical,              intent(in), optional         :: no_scalar      !< True: no scalar (the mesh's colour).
   character(len=*),     intent(in), optional         :: colormap       !< Colormap name.
   real(real64),         intent(in), optional         :: vmin           !< The scalar mapped to the map's start.
   real(real64),         intent(in), optional         :: vmax           !< ... to its end.
   logical,              intent(in), optional         :: auto_range     !< True: the data's range (the default).
   real(real64),         intent(in), optional, target :: color(3)       !< Colour `[r, g, b]` in [0, 1].
   logical,              intent(in), optional         :: edges          !< Draw the edges.
   real(real64),         intent(in), optional, target :: edge_color(3)  !< Edges' colour (default near black).
   logical,              intent(in), optional         :: flat           !< Flat shading.
   logical,              intent(in), optional         :: visible        !< Drawn (default true).
   integer(int32),       intent(out), optional        :: stat           !< Status.
   integer(c_int)                                     :: set_range      !< 0 keep, 1 given, 2 the data's.
   real(c_double)                                     :: lo, hi         !< Range.
   integer(c_int)                                     :: e, f, vis      !< Flags (-1 keep).
   real(c_double), target                             :: c(3), ec(3)    !< Colours.
   type(c_ptr)                                        :: pc, pec        !< ... or none.

   if (figure_refused('view3d_object%set_mesh', stat)) return
   if (.not. alive(self, 'set_mesh', stat)) return
   if (present(no_scalar)) then
      if (no_scalar) then
         if (.not. scalar_set(self, mesh, c_null_ptr, 0_int64, .false., stat)) return
      endif
   endif
   if (present(scalar)) then
      if (.not. scalar_set(self, mesh, c_loc(scalar(1)), size(scalar, kind=int64), .false., stat)) return
   endif
   if (present(cell_scalar)) then
      if (.not. scalar_set(self, mesh, c_loc(cell_scalar(1)), size(cell_scalar, kind=int64), .true., stat)) return
   endif
   set_range = 0_c_int
   lo = 0.0_c_double
   hi = 1.0_c_double
   if (present(vmin) .neqv. present(vmax)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'view3d_object%set_mesh: give vmin and vmax together', stat)
      return
   endif
   if (present(vmin)) then
      set_range = 1_c_int
      lo = real(vmin, c_double)
      hi = real(vmax, c_double)
   endif
   if (present(auto_range)) then
      if (auto_range) set_range = 2_c_int
   endif
   pc = c_null_ptr
   if (present(color)) then
      c = real(color, c_double)
      pc = c_loc(c)
   endif
   pec = c_null_ptr
   if (present(edge_color)) then
      ec = real(edge_color, c_double)
      pec = c_loc(ec)
   endif
   e = flag(edges)
   f = flag(flat)
   vis = flag(visible)
   if (present(colormap)) then
      call figure_check(fig_view3d_style(self%handle, int(mesh, c_int), colormap, len(colormap, c_int), set_range, lo, &
                                         hi, pc, e, pec, f, vis), stat)
   else
      call figure_check(fig_view3d_style(self%handle, int(mesh, c_int), '', 0_c_int, set_range, lo, hi, pc, e, pec, &
                                         f, vis), stat)
   endif
   endsubroutine set_mesh

   recursive subroutine remove(self, mesh, stat)
   !< Remove a mesh (the program's arrays are not touched). Status: `FIG_ERR_ARGUMENT` for an unknown mesh.
   class(view3d_object), intent(in)            :: self !< View.
   integer(int32),       intent(in)            :: mesh !< Mesh id.
   integer(int32),       intent(out), optional :: stat !< Status.

   if (figure_refused('view3d_object%remove', stat)) return
   if (.not. alive(self, 'remove', stat)) return
   if (mesh <= 0_int32) then
      call figure_fail(FIG_ERR_ARGUMENT, 'view3d_object%remove: mesh ids start from 1', stat)
      return
   endif
   call figure_check(fig_view3d_remove(self%handle, int(mesh, c_int)), stat)
   endsubroutine remove

   recursive subroutine clear(self, stat)
   !< Remove every mesh.
   class(view3d_object), intent(in)            :: self !< View.
   integer(int32),       intent(out), optional :: stat !< Status.

   if (figure_refused('view3d_object%clear', stat)) return
   if (.not. alive(self, 'clear', stat)) return
   call figure_check(fig_view3d_remove(self%handle, 0_c_int), stat)
   endsubroutine clear

   recursive subroutine changed(self, mesh, stat)
   !< The data of `mesh` (absent: of every mesh) changed in place: its normals, range and connectivity checks are
   !< derived again, and the view is rendered at the next draw. Status: `FIG_ERR_ARGUMENT` for an unknown mesh or a
   !< connectivity index now out of range.
   class(view3d_object), intent(in)            :: self !< View.
   integer(int32),       intent(in),  optional :: mesh !< Mesh id.
   integer(int32),       intent(out), optional :: stat !< Status.
   integer(c_int)                              :: m    !< Mesh (0: all).

   if (figure_refused('view3d_object%changed', stat)) return
   if (.not. alive(self, 'changed', stat)) return
   m = 0_c_int
   if (present(mesh)) m = int(mesh, c_int)
   call figure_check(fig_view3d_changed(self%handle, m), stat)
   endsubroutine changed

   recursive subroutine set_camera(self, target, distance, azimuth, elevation, fov, stat)
   !< Set the camera: it looks at `target` from `distance` away, from the direction given by `azimuth` (around z, from
   !< +x toward +y) and `elevation` (above the x-y plane, in [-90, 90]), with a vertical field of view `fov`; z is up.
   !< Absent arguments are unchanged (a camera never set is first fitted to the meshes). Statuses: `FIG_ERR_ARGUMENT`
   !< for `distance <= 0`, `fov` outside (0, 180) or `elevation` outside [-90, 90].
   class(view3d_object), intent(in)            :: self      !< View.
   real(real64),         intent(in),  optional :: target(3) !< The point looked at [world units].
   real(real64),         intent(in),  optional :: distance  !< From the target [world units].
   real(real64),         intent(in),  optional :: azimuth   !< [degrees].
   real(real64),         intent(in),  optional :: elevation !< [degrees].
   real(real64),         intent(in),  optional :: fov       !< Vertical field of view [degrees] (default 30).
   integer(int32),       intent(out), optional :: stat      !< Status.
   real(c_double)                              :: t(3), d, a, e, f !< Values.
   integer(c_int)                              :: mask      !< What is set.

   if (figure_refused('view3d_object%set_camera', stat)) return
   if (.not. alive(self, 'set_camera', stat)) return
   mask = 0_c_int
   t = 0.0_c_double
   d = 1.0_c_double
   a = 0.0_c_double
   e = 0.0_c_double
   f = 30.0_c_double
   if (present(target)) then
      t = real(target, c_double)
      mask = ior(mask, 1_c_int)
   endif
   if (present(distance)) then
      d = real(distance, c_double)
      mask = ior(mask, 2_c_int)
   endif
   if (present(azimuth)) then
      a = real(azimuth, c_double)
      mask = ior(mask, 4_c_int)
   endif
   if (present(elevation)) then
      e = real(elevation, c_double)
      mask = ior(mask, 8_c_int)
   endif
   if (present(fov)) then
      f = real(fov, c_double)
      mask = ior(mask, 16_c_int)
   endif
   call figure_check(fig_view3d_camera(self%handle, 1_c_int, mask, t, d, a, e, f), stat)
   endsubroutine set_camera

   recursive subroutine get_camera(self, target, distance, azimuth, elevation, fov, stat)
   !< Read the camera (as `set_camera` describes it; a camera never set is first fitted to the meshes).
   class(view3d_object), intent(in)            :: self      !< View.
   real(real64),         intent(out), optional :: target(3) !< The point looked at.
   real(real64),         intent(out), optional :: distance  !< From the target.
   real(real64),         intent(out), optional :: azimuth   !< [degrees], in [-180, 180].
   real(real64),         intent(out), optional :: elevation !< [degrees].
   real(real64),         intent(out), optional :: fov       !< [degrees].
   integer(int32),       intent(out), optional :: stat      !< Status.
   real(c_double)                              :: t(3), d, a, e, f !< Values.

   if (figure_refused('view3d_object%get_camera', stat)) return
   if (.not. alive(self, 'get_camera', stat)) return
   call figure_check(fig_view3d_camera(self%handle, 0_c_int, 0_c_int, t, d, a, e, f), stat)
   if (present(target)) target = real(t, real64)
   if (present(distance)) distance = real(d, real64)
   if (present(azimuth)) azimuth = real(a, real64)
   if (present(elevation)) elevation = real(e, real64)
   if (present(fov)) fov = real(f, real64)
   endsubroutine get_camera

   recursive subroutine fit(self, stat)
   !< Aim at the centre of the visible meshes' bounding box, from the distance at which their bounding sphere fills the
   !< view (the direction is kept). Also on a double click in the view.
   class(view3d_object), intent(in)            :: self !< View.
   integer(int32),       intent(out), optional :: stat !< Status.

   if (figure_refused('view3d_object%fit', stat)) return
   if (.not. alive(self, 'fit', stat)) return
   call figure_check(fig_view3d_fit(self%handle), stat)
   endsubroutine fit

   recursive subroutine view(self, name, stat)
   !< A standard view, fitted: `'+x'` puts the eye on the +x side looking toward -x (z up), likewise `'-x'`, `'+y'`,
   !< `'-y'`; `'+z'` looks down with x right and y up, `'-z'` looks up with x right. Status: `FIG_ERR_ARGUMENT` for
   !< another name.
   class(view3d_object), intent(in)            :: self !< View.
   character(len=*),     intent(in)            :: name !< `'+x'`, `'-x'`, `'+y'`, `'-y'`, `'+z'` or `'-z'`.
   integer(int32),       intent(out), optional :: stat !< Status.
   integer(c_int)                              :: w    !< Which.

   if (figure_refused('view3d_object%view', stat)) return
   if (.not. alive(self, 'view', stat)) return
   select case (trim(adjustl(name)))
   case ('+x'); w = 0_c_int
   case ('-x'); w = 1_c_int
   case ('+y'); w = 2_c_int
   case ('-y'); w = 3_c_int
   case ('+z'); w = 4_c_int
   case ('-z'); w = 5_c_int
   case default
      call figure_fail(FIG_ERR_ARGUMENT, "view3d_object%view: name must be '+x', '-x', '+y', '-y', '+z' or '-z', got '" &
                       //trim(name)//"'", stat)
      return
   endselect
   call figure_check(fig_view3d_standard(self%handle, w), stat)
   endsubroutine view

   recursive subroutine orbit(self, azimuth, elevation, stat)
   !< Turn the camera around its target by `azimuth` and `elevation` [degrees] (the elevation is kept in [-90, 90]); as
   !< a drag with the left button in the view.
   class(view3d_object), intent(in)            :: self      !< View.
   real(real64),         intent(in)            :: azimuth   !< Change of azimuth [degrees].
   real(real64),         intent(in),  optional :: elevation !< Change of elevation [degrees] (default 0).
   integer(int32),       intent(out), optional :: stat      !< Status.
   real(c_double)                              :: e         !< Elevation.

   if (figure_refused('view3d_object%orbit', stat)) return
   if (.not. alive(self, 'orbit', stat)) return
   e = 0.0_c_double
   if (present(elevation)) e = real(elevation, c_double)
   call figure_check(fig_view3d_move(self%handle, real(azimuth, c_double), e, 0.0_c_double, 0.0_c_double, &
                                     1.0_c_double), stat)
   endsubroutine orbit

   recursive subroutine pan(self, right, up, stat)
   !< Move the camera and its target along the screen's right and up directions [world units]; as a drag with the
   !< right or middle button (or shift and the left one) in the view.
   class(view3d_object), intent(in)            :: self  !< View.
   real(real64),         intent(in)            :: right !< Along the screen's right [world units].
   real(real64),         intent(in)            :: up    !< Along the screen's up [world units].
   integer(int32),       intent(out), optional :: stat  !< Status.

   if (figure_refused('view3d_object%pan', stat)) return
   if (.not. alive(self, 'pan', stat)) return
   call figure_check(fig_view3d_move(self%handle, 0.0_c_double, 0.0_c_double, real(right, c_double), &
                                     real(up, c_double), 1.0_c_double), stat)
   endsubroutine pan

   recursive subroutine zoom(self, factor, stat)
   !< Divide the camera's distance by `factor` (> 1 closer); the wheel in the view zooms by 1.1 per step. Status:
   !< `FIG_ERR_ARGUMENT` for `factor <= 0`.
   class(view3d_object), intent(in)            :: self   !< View.
   real(real64),         intent(in)            :: factor !< Zoom factor.
   integer(int32),       intent(out), optional :: stat   !< Status.

   if (figure_refused('view3d_object%zoom', stat)) return
   if (.not. alive(self, 'zoom', stat)) return
   call figure_check(fig_view3d_move(self%handle, 0.0_c_double, 0.0_c_double, 0.0_c_double, 0.0_c_double, &
                                     real(factor, c_double)), stat)
   endsubroutine zoom

   recursive subroutine clip(self, normal, point, stat)
   !< Add a clipping plane through `point`: what lies where `(x - point) . normal >= 0` is kept, the rest is cut away
   !< (surfaces cut exactly per pixel, lines per segment). At most 6 planes. Status: `FIG_ERR_ARGUMENT` for a seventh
   !< plane or a zero normal.
   class(view3d_object), intent(in)            :: self      !< View.
   real(real64),         intent(in)            :: normal(3) !< Towards the part kept.
   real(real64),         intent(in)            :: point(3)  !< A point of the plane [world units].
   integer(int32),       intent(out), optional :: stat      !< Status.

   if (figure_refused('view3d_object%clip', stat)) return
   if (.not. alive(self, 'clip', stat)) return
   call figure_check(fig_view3d_clip(self%handle, real(normal, c_double), real(point, c_double)), stat)
   endsubroutine clip

   recursive subroutine unclip(self, stat)
   !< Remove every clipping plane.
   class(view3d_object), intent(in)            :: self !< View.
   integer(int32),       intent(out), optional :: stat !< Status.

   if (figure_refused('view3d_object%unclip', stat)) return
   if (.not. alive(self, 'unclip', stat)) return
   call figure_check(fig_view3d_unclip(self%handle), stat)
   endsubroutine unclip

   recursive subroutine draw(self, id, width, height, stat)
   !< Draw the view as a widget at the cursor, inside a window: `width` x `height` pixels (0: the available region;
   !< negative: up to that distance from its edge). It is rendered only when something changed since the last draw.
   !< The mouse in the view: left drag orbits, right or middle drag (or shift and left) pans, the wheel zooms, a double
   !< click fits. While the user moves the camera, the view is rendered at half resolution (unless `init`'s
   !< `fast_moves=.false.`), until the button is released or a frame has no wheel step. Modes: the same pixels in every
   !< mode; in remote mode each render is sent to the browser as a texture: JPEG while the camera moves, exact once it
   !< is still (`init_remote`'s `lossy`). Statuses: `FIG_ERR_STATE` before `init` and from a task.
   class(view3d_object), intent(in)            :: self   !< View.
   character(len=*),     intent(in)            :: id     !< Widget id (unique in the window).
   real(real64),         intent(in),  optional :: width  !< Width [pixels] (default 0: the available width).
   real(real64),         intent(in),  optional :: height !< Height [pixels] (default 0: the available height).
   integer(int32),       intent(out), optional :: stat   !< Status.
   real(c_double)                              :: w, h   !< Size.

   if (figure_refused('view3d_object%draw', stat)) return
   if (.not. alive(self, 'draw', stat)) return
   w = 0.0_c_double
   if (present(width)) w = real(width, c_double)
   h = 0.0_c_double
   if (present(height)) h = real(height, c_double)
   call figure_check(fig_view3d_draw(self%handle, id, len(id, c_int), w, h), stat)
   endsubroutine draw

   recursive function pick(self, x, y, mesh, element, point, stat) result(hit)
   !< The element under the pixel `(x, y)` of the view (from its top-left corner) in the last render: true if a
   !< surface is there, with its mesh id, its element (triangle, quad or cell, from 1) and the point hit [world units].
   class(view3d_object), intent(in)            :: self     !< View.
   real(real64),         intent(in)            :: x        !< Abscissa from the view's left [pixels].
   real(real64),         intent(in)            :: y        !< Ordinate from the view's top [pixels].
   integer(int32),       intent(out)           :: mesh     !< Mesh id (0: none).
   integer(int64),       intent(out)           :: element  !< Element (0: none).
   real(real64),         intent(out), optional :: point(3) !< The point hit.
   integer(int32),       intent(out), optional :: stat     !< Status.
   logical                                     :: hit      !< A surface is there.

   hit = query(self, 'pick', 0_c_int, x, y, mesh, element, point, stat)
   endfunction pick

   recursive function hovered(self, mesh, element, point, stat) result(hit)
   !< The element under the mouse in the last `draw` (false when the mouse is not over a surface of the view).
   class(view3d_object), intent(in)            :: self     !< View.
   integer(int32),       intent(out)           :: mesh     !< Mesh id (0: none).
   integer(int64),       intent(out)           :: element  !< Element (0: none).
   real(real64),         intent(out), optional :: point(3) !< The point under the mouse.
   integer(int32),       intent(out), optional :: stat     !< Status.
   logical                                     :: hit      !< An element is hovered.

   hit = query(self, 'hovered', 1_c_int, 0.0_real64, 0.0_real64, mesh, element, point, stat)
   endfunction hovered

   recursive function clicked(self, mesh, element, point, stat) result(hit)
   !< The element clicked (left button pressed and released without dragging) in the last `draw`: true in that frame.
   class(view3d_object), intent(in)            :: self     !< View.
   integer(int32),       intent(out)           :: mesh     !< Mesh id (0: none).
   integer(int64),       intent(out)           :: element  !< Element (0: none).
   real(real64),         intent(out), optional :: point(3) !< The point clicked.
   integer(int32),       intent(out), optional :: stat     !< Status.
   logical                                     :: hit      !< An element was clicked.

   hit = query(self, 'clicked', 2_c_int, 0.0_real64, 0.0_real64, mesh, element, point, stat)
   endfunction clicked

   recursive subroutine image(self, rgba, stat)
   !< The pixels of the last render, `rgba(4, width, height)` (as `texture_object%update` takes them; half the view's
   !< size if it was rendered while moving), unallocated before the first render.
   class(view3d_object),       intent(in)            :: self        !< View.
   integer(int8), allocatable, intent(out), target   :: rgba(:,:,:) !< Pixels.
   integer(int32),             intent(out), optional :: stat        !< Status.
   integer(c_int)                                    :: w, h        !< Size.
   integer(c_int)                                    :: s           !< Status.

   if (figure_refused('view3d_object%image', stat)) return
   if (.not. alive(self, 'image', stat)) return
   s = fig_view3d_image(self%handle, c_null_ptr, 0_c_long_long, w, h)
   if (s == FIG_OK .and. w > 0_c_int .and. h > 0_c_int) then
      allocate(rgba(4, w, h))
      s = fig_view3d_image(self%handle, c_loc(rgba), size(rgba, kind=c_long_long), w, h)
   endif
   call figure_check(s, stat)
   endsubroutine image

   recursive subroutine render_info(self, count, milliseconds, width, height, half, stat)
   !< The renders so far, the last one's time [ms] and size [pixels], and whether it was at half resolution.
   class(view3d_object), intent(in)            :: self         !< View.
   integer(int32),       intent(out), optional :: count        !< Renders since `init`.
   real(real64),         intent(out), optional :: milliseconds !< The last render's time [ms].
   integer(int32),       intent(out), optional :: width        !< Its width [pixels].
   integer(int32),       intent(out), optional :: height       !< Its height [pixels].
   logical,              intent(out), optional :: half         !< At half resolution (the camera was moving).
   integer(int32),       intent(out), optional :: stat         !< Status.
   integer(c_int)                              :: n, w, h, hf  !< Values.
   real(c_double)                              :: ms           !< Time.

   if (figure_refused('view3d_object%render_info', stat)) return
   if (.not. alive(self, 'render_info', stat)) return
   call figure_check(fig_view3d_info(self%handle, n, ms, w, h, hf), stat)
   if (present(count)) count = int(n, int32)
   if (present(milliseconds)) milliseconds = real(ms, real64)
   if (present(width)) width = int(w, int32)
   if (present(height)) height = int(h, int32)
   if (present(half)) half = hf /= 0_c_int
   endsubroutine render_info

   ! ---- private -------------------------------------------------------------------------------------------------------

   function alive(self, name, stat) result(ok)
   !< The view exists; else `FIG_ERR_STATE`.
   class(view3d_object), intent(in)            :: self !< View.
   character(len=*),     intent(in)            :: name !< Procedure.
   integer(int32),       intent(out), optional :: stat !< Status.
   logical                                     :: ok   !< Exists.

   ok = self%handle /= 0_c_int
   if (.not. ok) call figure_fail(FIG_ERR_STATE, 'view3d_object%'//name//': the view is not initialized', stat)
   endfunction alive

   function points_ok(name, xyz, stat) result(ok)
   !< `xyz(3, n)`, n >= 1, contiguous.
   character(len=*), intent(in)            :: name     !< Procedure.
   real(real64),     intent(in)            :: xyz(:,:) !< Points.
   integer(int32),   intent(out), optional :: stat     !< Status.
   logical                                 :: ok       !< Valid.

   ok = size(xyz, 1) == 3 .and. size(xyz, 2) >= 1
   if (.not. ok) then
      call figure_fail(FIG_ERR_ARGUMENT, 'view3d_object%'//name//': xyz must be (3, n) with n >= 1', stat)
      return
   endif
   ok = is_contiguous(xyz)
   if (.not. ok) call figure_fail(FIG_ERR_ARGUMENT, 'view3d_object%'//name// &
                                  ': xyz must be contiguous (it is kept by address)', stat)
   endfunction points_ok

   function connectivity_ok(name, xyz, conn, per, stat) result(ok)
   !< `xyz(3, n)` and `conn(per, m)`, m >= 1, both contiguous (the indices are checked by the native layer).
   character(len=*), intent(in)            :: name      !< Procedure.
   real(real64),     intent(in)            :: xyz(:,:)  !< Points.
   integer(int32),   intent(in)            :: conn(:,:) !< Connectivity.
   integer,          intent(in)            :: per       !< Vertices per cell.
   integer(int32),   intent(out), optional :: stat      !< Status.
   logical                                 :: ok        !< Valid.
   character(len=12)                       :: text      !< A number.

   ok = points_ok(name, xyz, stat)
   if (.not. ok) return
   write(text, '(I0)') per
   ok = size(conn, 1) == per .and. size(conn, 2) >= 1
   if (.not. ok) then
      call figure_fail(FIG_ERR_ARGUMENT, 'view3d_object%'//name//': the connectivity must be ('//trim(text)// &
                       ', n) with n >= 1', stat)
      return
   endif
   ok = is_contiguous(conn)
   if (.not. ok) call figure_fail(FIG_ERR_ARGUMENT, 'view3d_object%'//name// &
                                  ': the connectivity must be contiguous (it is kept by address)', stat)
   endfunction connectivity_ok

   function add_mesh(self, kind, xyz, nv, conn, ncell, ni, nj, stat) result(mesh)
   !< A mesh added by the native layer; 0 on a failure.
   class(view3d_object), intent(in)            :: self   !< View.
   integer(c_int),       intent(in)            :: kind   !< Kind.
   type(c_ptr),          intent(in)            :: xyz    !< Coordinates.
   integer(int64),       intent(in)            :: nv     !< Vertices.
   type(c_ptr),          intent(in)            :: conn   !< Connectivity (or null).
   integer(int64),       intent(in)            :: ncell  !< Cells.
   integer,              intent(in)            :: ni, nj !< Surface's nodes.
   integer(int32),       intent(out), optional :: stat   !< Status.
   integer(int32)                              :: mesh   !< Mesh id.
   integer(c_int)                              :: m      !< Native id.

   mesh = 0_int32
   if (.not. alive(self, 'add', stat)) return
   m = 0_c_int
   call figure_check(fig_view3d_mesh(self%handle, kind, xyz, int(nv, c_long_long), conn, int(ncell, c_long_long), &
                                     int(ni, c_int), int(nj, c_int), m), stat)
   mesh = int(m, int32)
   endfunction add_mesh

   function scalar_set(self, mesh, values, n, on_cells, stat) result(ok)
   !< The native scalar of a mesh set (values null: removed); false on a failure.
   class(view3d_object), intent(in)            :: self     !< View.
   integer(int32),       intent(in)            :: mesh     !< Mesh id.
   type(c_ptr),          intent(in)            :: values   !< The values.
   integer(int64),       intent(in)            :: n        !< Their number.
   logical,              intent(in)            :: on_cells !< Per cell.
   integer(int32),       intent(out), optional :: stat     !< Status.
   logical                                     :: ok       !< Done.
   integer(c_int)                              :: s        !< Status.

   s = fig_view3d_scalar(self%handle, int(mesh, c_int), values, int(n, c_long_long), merge(1_c_int, 0_c_int, on_cells))
   call figure_check(s, stat)
   ok = s == FIG_OK
   endfunction scalar_set

   subroutine style_new(self, mesh, scalar, cell_scalar, colormap, color, edges, flat, stat)
   !< The scalars and style given at a mesh's creation; the mesh is removed again on a failure.
   class(view3d_object), intent(in)                   :: self           !< View.
   integer(int32),       intent(inout)                :: mesh           !< Mesh id (0 after a failure).
   real(real64),         intent(in), optional, target :: scalar(:)      !< A value per vertex.
   real(real64),         intent(in), optional, target :: cell_scalar(:) !< A value per cell.
   character(len=*),     intent(in), optional         :: colormap       !< Colormap.
   real(real64),         intent(in), optional         :: color(3)       !< Colour.
   logical,              intent(in), optional         :: edges          !< Edges.
   logical,              intent(in), optional         :: flat           !< Flat shading.
   integer(int32),       intent(out), optional        :: stat           !< Status.
   integer(int32)                                     :: s              !< Status.

   s = FIG_OK
   if (present(scalar)) then
      if (.not. is_contiguous(scalar)) then
         call figure_fail(FIG_ERR_ARGUMENT, 'view3d_object: scalar must be contiguous', s)
      elseif (.not. scalar_set(self, mesh, c_loc(scalar(1)), size(scalar, kind=int64), .false., s)) then
         continue
      endif
   endif
   if (s == FIG_OK .and. present(cell_scalar)) then
      if (.not. is_contiguous(cell_scalar)) then
         call figure_fail(FIG_ERR_ARGUMENT, 'view3d_object: cell_scalar must be contiguous', s)
      elseif (.not. scalar_set(self, mesh, c_loc(cell_scalar(1)), size(cell_scalar, kind=int64), .true., s)) then
         continue
      endif
   endif
   if (s == FIG_OK .and. (present(colormap) .or. present(color) .or. present(edges) .or. present(flat))) &
      call self%set_mesh(mesh, colormap=colormap, color=color, edges=edges, flat=flat, stat=s)
   if (s /= FIG_OK) then
      if (fig_view3d_remove(self%handle, int(mesh, c_int)) /= FIG_OK) continue ! a failure leaves no half-made mesh
      mesh = 0_int32
   endif
   call figure_check(int(s, c_int), stat)
   endsubroutine style_new

   function flag(value) result(f)
   !< -1 for absent, else 0 or 1.
   logical, intent(in), optional :: value !< Value.
   integer(c_int)                :: f     !< Flag.

   f = -1_c_int
   if (present(value)) f = merge(1_c_int, 0_c_int, value)
   endfunction flag

   recursive function query(self, name, what, x, y, mesh, element, point, stat) result(hit)
   !< pick (0), hovered (1), clicked (2).
   class(view3d_object), intent(in)            :: self     !< View.
   character(len=*),     intent(in)            :: name     !< Procedure.
   integer(c_int),       intent(in)            :: what     !< Which.
   real(real64),         intent(in)            :: x, y     !< Pixel.
   integer(int32),       intent(out)           :: mesh     !< Mesh id.
   integer(int64),       intent(out)           :: element  !< Element.
   real(real64),         intent(out), optional :: point(3) !< Point.
   integer(int32),       intent(out), optional :: stat     !< Status.
   logical                                     :: hit      !< Found.
   integer(c_int)                              :: h, m     !< Native.
   integer(c_long_long)                        :: e        !< Element.
   real(c_double)                              :: p(3)     !< Point.

   hit = .false.
   mesh = 0_int32
   element = 0_int64
   if (present(point)) point = 0.0_real64
   if (figure_refused('view3d_object%'//name, stat)) return
   if (.not. alive(self, name, stat)) return
   call figure_check(fig_view3d_pick(self%handle, what, real(x, c_double), real(y, c_double), h, m, e, p), stat)
   hit = h /= 0_c_int
   if (.not. hit) return
   mesh = int(m, int32)
   element = int(e, int64)
   if (present(point)) point = real(p, real64)
   endfunction query
endmodule figure_view3d
