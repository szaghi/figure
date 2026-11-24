!< figure_view3d_gizmos, the 3-D view's gizmos seam (implementation in Fortran: figure_gizmo).
module figure_view3d_gizmos
!< figure_view3d_gizmos, the 3-D view's gizmos seam (implementation in Fortran: figure_gizmo).
!<
!< szaghi/figure#15 P14. What `view3d_object%view_cube` and `view3d_object%gizmo` (src/lib/figure_view3d.F90) call,
!< under the names, arguments, statuses and messages of the current path's (src/paths/imgui/gizmo/: the native
!< layer's `fig_view3d_cube` and `fig_view3d_gizmo` over ImGuizmo): figure_gizmo's `gz_view_cube` and `gz_view_gizmo`,
!< ImGuizmo's `ViewManipulate` and `Manipulate` and FIGURE's glue in Fortran on figure_core. Private to the library.
use, intrinsic :: iso_c_binding, only : c_double, c_int
use figure_gizmo, only : gz_view_cube, gz_view_gizmo

implicit none
private
public :: fig_view3d_cube, fig_view3d_gizmo

contains
   function fig_view3d_cube(handle, size, corner, changed) result(status)
   !< A view cube in a corner of the view drawn in this frame and window: corner 0 top-right, 1 top-left, 2
   !< bottom-right, 3 bottom-left; changed 1 when it turned the camera.
   integer(c_int), intent(in)  :: handle  !< View.
   real(c_double), intent(in)  :: size    !< Side [pixels].
   integer(c_int), intent(in)  :: corner  !< Corner.
   integer(c_int), intent(out) :: changed !< Turned.
   integer(c_int)              :: status  !< Status.

   status = gz_view_cube(handle, size, corner, changed)
   endfunction fig_view3d_cube

   function fig_view3d_gizmo(handle, id, id_len, matrix, mode, space, has_snap, snap, changed) result(status)
   !< A gizmo moving `matrix` (column-major 4 x 4) over the view drawn in this frame and window: mode 0 translate, 1
   !< rotate, 2 scale; space 0 world, 1 local; snap (has_snap 1); changed 1 when moved.
   integer(c_int),   intent(in)    :: handle     !< View.
   character(len=*), intent(in)    :: id         !< Gizmo ID.
   integer(c_int),   intent(in)    :: id_len     !< Its length.
   real(c_double),   intent(inout) :: matrix(16) !< The matrix moved.
   integer(c_int),   intent(in)    :: mode       !< Mode.
   integer(c_int),   intent(in)    :: space      !< Space.
   integer(c_int),   intent(in)    :: has_snap   !< Snap given.
   real(c_double),   intent(in)    :: snap       !< Snap.
   integer(c_int),   intent(out)   :: changed    !< Moved.
   integer(c_int)                  :: status     !< Status.

   status = gz_view_gizmo(handle, id(1:max(id_len, 0_c_int)), matrix, mode, space, has_snap, snap, changed)
   endfunction fig_view3d_gizmo
endmodule figure_view3d_gizmos
