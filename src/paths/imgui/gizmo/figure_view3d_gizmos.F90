!< figure_view3d_gizmos, the 3-D view's gizmos seam (implementation over ImGuizmo: native/figure_view3d.cpp).
module figure_view3d_gizmos
!< figure_view3d_gizmos, the 3-D view's gizmos seam (implementation over ImGuizmo: native/figure_view3d.cpp).
!<
!< szaghi/figure#15 P14. What `view3d_object%view_cube` and `view3d_object%gizmo` (src/lib/figure_view3d.F90) call:
!< `fig_view3d_cube` and `fig_view3d_gizmo`, here the native layer's (ImGuizmo's `ViewManipulate` and `Manipulate` with
!< FIGURE's glue, native/figure_view3d.cpp), on the Fortran path figure_gizmo's (src/paths/fortran/gizmo/) under the
!< same names, arguments, statuses and messages. Private to the library.
use, intrinsic :: iso_c_binding, only : c_char, c_double, c_int

implicit none
private
public :: fig_view3d_cube, fig_view3d_gizmo

interface
   function fig_view3d_cube(handle, size, corner, changed) result(status) bind(C, name='fig_view3d_cube')
   !< A view cube in a corner of the view drawn in this frame and window: corner 0 top-right, 1 top-left, 2
   !< bottom-right, 3 bottom-left; changed 1 when it turned the camera.
   import :: c_double, c_int
   implicit none
   integer(c_int), value       :: handle  !< View.
   real(c_double), value       :: size    !< Side [pixels].
   integer(c_int), value       :: corner  !< Corner.
   integer(c_int), intent(out) :: changed !< Turned.
   integer(c_int)              :: status  !< Status.
   endfunction fig_view3d_cube

   function fig_view3d_gizmo(handle, id, id_len, matrix, mode, space, has_snap, snap, changed) result(status) &
      bind(C, name='fig_view3d_gizmo')
   !< A gizmo moving `matrix` (column-major 4 x 4) over the view drawn in this frame and window: mode 0 translate, 1
   !< rotate, 2 scale; space 0 world, 1 local; snap (has_snap 1); changed 1 when moved.
   import :: c_char, c_double, c_int
   implicit none
   integer(c_int),         value         :: handle     !< View.
   character(kind=c_char), intent(in)    :: id(*)      !< Gizmo ID.
   integer(c_int),         value         :: id_len     !< Its length.
   real(c_double),         intent(inout) :: matrix(16) !< The matrix moved.
   integer(c_int),         value         :: mode       !< Mode.
   integer(c_int),         value         :: space      !< Space.
   integer(c_int),         value         :: has_snap   !< Snap given.
   real(c_double),         value         :: snap       !< Snap.
   integer(c_int),         intent(out)   :: changed    !< Moved.
   integer(c_int)                        :: status     !< Status.
   endfunction fig_view3d_gizmo
endinterface
endmodule figure_view3d_gizmos
