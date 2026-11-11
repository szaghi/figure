call view%view_cube()                             ! top-right: a click on a face looks at it, a drag turns
if (cut) then
   if (view%gizmo('clip plane', plane, mode=trim(GIZMO_MODES(gizmo_mode)))) call clip() ! the user moved the plane
endif
