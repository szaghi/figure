subroutine cut(view)
!< The body cut by the plane: what lies behind its normal is cut away; the outline follows it.
type(view3d_object), intent(inout) :: view !< The view.
real(real64)                       :: n(3) !< The normal, unit.

n = plane(1:3, 3) / norm2(plane(1:3, 3))         ! a scale gizmo may have stretched it
call view%unclip()
call view%clip(n, plane(1:3, 4))
call outline_of(plane)
call view%changed(outline)                        ! the outline's array changed in place
endsubroutine cut
