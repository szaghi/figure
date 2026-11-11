subroutine draw(view)
!< The window: the mode buttons, the plane's point and normal, the view with its cube and the gizmo.
type(view3d_object), intent(inout) :: view !< The view.
character(len=96)                  :: text !< The plane, as text.

call ig_set_next_window(10.0_real64, 10.0_real64, 700.0_real64, 520.0_real64)
if (ig_begin('Cut')) then
   if (ig_button('Move')) mode = 'translate'
   call ig_same_line()
   if (ig_button('Turn')) mode = 'rotate'
   call ig_same_line()
   write(text, '(A,3F6.2,A,3F6.2)') 'point', plane(1:3, 4), '   normal', plane(1:3, 3) / norm2(plane(1:3, 3))
   call ig_text(trim(text))
   call ig_separator()
   call view%draw('view')                         ! the rest of the window
   call ig_item_rect(view0(1), view0(2), view1(1), view1(2))
   call view%view_cube()                          ! top-right: a click on a face looks at it
   if (view%gizmo('plane', plane, mode=trim(mode))) call cut(view) ! the user moved the plane
endif
call ig_end()
endsubroutine draw
