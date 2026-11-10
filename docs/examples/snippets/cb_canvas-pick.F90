function nearest(cx, cy) result(b)
!< The boundary within PICK pixels of the canvas point (`cx`, `cy`), 0 if none.
real(real64), intent(in) :: cx !< Canvas abscissa [pixels].
real(real64), intent(in) :: cy !< Canvas ordinate [pixels].
integer(int32)           :: b  !< Boundary.
real(real64)             :: x  !< The point [m].
real(real64)             :: y  !< ...
real(real64)             :: d(NB) !< Its distance to each boundary [pixels].

x = (cx - 40.0_real64) / scale
y = 0.5_real64 - (cy - 0.5_real64 * ev%size(2)) / scale
d(1) = segment(x, y, 0.0_real64, 0.0_real64, 0.0_real64, 1.0_real64)
d(2) = segment(x, y, 4.0_real64, 0.0_real64, 4.0_real64, 1.0_real64)
d(3) = segment(x, y, 0.0_real64, 0.0_real64, 4.0_real64, 0.0_real64)
d(4) = segment(x, y, 0.0_real64, 1.0_real64, 4.0_real64, 1.0_real64)
d(5) = abs(hypot(x - XC, y - YC) - RC)
b = minloc(d, 1)
if (d(b) * scale > PICK) b = 0_int32
endfunction nearest
