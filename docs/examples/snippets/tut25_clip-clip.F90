subroutine clip()
!< Clip the 3-D view by the plane: what lies on the side its normal points to is kept.
real(real64) :: n(3) !< The normal, unit.

n = plane(1:3, 3) / norm2(plane(1:3, 3))
call view%unclip()
call view%clip(n, plane(1:3, 4))
endsubroutine clip
