subroutine to_pixel(view, p, x, y)
!< The pixel of the display where the view shows the world point `p`: projection * view, then the view's rectangle.
type(view3d_object), intent(in)  :: view    !< The view.
real(real64),        intent(in)  :: p(3)    !< World point.
real(real64),        intent(out) :: x, y    !< Pixel [pixels].
real(real64)                     :: v(4, 4) !< View matrix.
real(real64)                     :: q(4, 4) !< Projection matrix.
real(real64)                     :: c(4)    !< Clip coordinates.

call view%view_matrix(v)
call view%projection_matrix(q)
c = matmul(q, matmul(v, [p, 1.0_real64]))
x = view0(1) + (0.5_real64 + 0.5_real64 * c(1) / c(4)) * (view1(1) - view0(1))
y = view0(2) + (0.5_real64 - 0.5_real64 * c(2) / c(4)) * (view1(2) - view0(2))
endsubroutine to_pixel
