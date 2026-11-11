!< cb_gizmo, cookbook: place a clipping plane by hand with a gizmo, turn the camera with a view cube.
module cb_gizmo_ui
!< cb_gizmo_ui, the view of cb_gizmo: a slender body cut by a plane the user moves and turns.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : ig_begin, ig_button, ig_end, ig_item_rect, ig_same_line, ig_separator, ig_set_next_window, ig_text, &
                   view3d_object

implicit none
private
public :: start, draw, to_pixel, plane, view0, view1

integer(int32), parameter :: NI = 72_int32           !< Nodes around the body.
integer(int32), parameter :: NJ = 37_int32           !< Nodes from nose to tail.
real(real64),   parameter :: PI = acos(-1.0_real64)  !< Pi.
real(real64),   target    :: body(3, NI, NJ)         !< A slender body.
real(real64),   target    :: cp(NI, NJ)              !< Its pressure coefficient.
real(real64),   target    :: frame(3, 5)             !< The plane's outline, a square in it.
real(real64)              :: plane(4, 4)             !< The plane's placement: normal plane(1:3, 3), point plane(1:3, 4).
character(len=9)          :: mode = 'translate'      !< The gizmo's mode.
integer(int32)            :: outline                 !< The outline's mesh.
real(real64)              :: view0(2), view1(2)      !< The view's rectangle on the display [pixels].

contains
   subroutine start(view)
   !< The body, coloured by its Cp, and a plane across it at x = 2, its normal along +x.
   type(view3d_object), intent(inout) :: view !< The view.
   integer(int32)                     :: i, j !< Counters.
   real(real64)                       :: s, r, th !< Abscissa along, radius, angle around.
   integer(int32)                     :: hull !< The body's mesh.

   do j = 1_int32, NJ
      s = real(j - 1, real64) / (NJ - 1)
      r = 0.6_real64 * sin(PI * s)**0.7_real64
      do i = 1_int32, NI
         th = 2.0_real64 * PI * (i - 1) / (NI - 1)
         body(:, i, j) = [4.0_real64 * s, r * cos(th), 0.8_real64 * r * sin(th)]
         cp(i, j) = 1.0_real64 - 2.2_real64 * sin(PI * s)**2 * (0.6_real64 + 0.4_real64 * cos(th)**2)
      enddo
   enddo
   call view%init()
   hull = view%surface(body, scalar=cp, colormap='cool-warm')
   !region start
   plane = 0.0_real64                                   ! columns: the plane's two in-plane axes, its normal, its point
   plane(1:3, 1) = [0.0_real64, 1.0_real64, 0.0_real64]
   plane(1:3, 2) = [0.0_real64, 0.0_real64, 1.0_real64]
   plane(1:3, 3) = [1.0_real64, 0.0_real64, 0.0_real64] ! the normal: the part toward +x is kept
   plane(1:4, 4) = [2.0_real64, 0.0_real64, 0.0_real64, 1.0_real64]
   call outline_of(plane)
   outline = view%lines(frame, color=[1.0_real64, 0.85_real64, 0.3_real64])
   call cut(view)
   !endregion start
   call view%set_camera(azimuth=-50.0_real64, elevation=20.0_real64)
   endsubroutine start

   subroutine outline_of(m)
   !< A square of side 1.6 in the plane `m` places, just on its kept side (a line in the plane itself could be cut).
   real(real64), intent(in) :: m(4, 4) !< Placement.
   real(real64)             :: c(3)    !< Its centre.
   integer(int32)           :: k       !< Corner.
   real(real64), parameter  :: CORNERS(2, 5) = reshape([-1, -1, 1, -1, 1, 1, -1, 1, -1, -1], [2, 5]) * 0.8_real64

   c = m(1:3, 4) + 1.0e-3_real64 * m(1:3, 3)
   do k = 1_int32, 5_int32
      frame(:, k) = c + CORNERS(1, k) * m(1:3, 1) + CORNERS(2, k) * m(1:3, 2)
   enddo
   endsubroutine outline_of

   !region cut
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
   !endregion cut

   !region draw
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
   !endregion draw

   !region pixel
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
   !endregion pixel
endmodule cb_gizmo_ui

program cb_gizmo
!< cb_gizmo, cookbook: place a clipping plane by hand with a gizmo, turn the camera with a view cube. With `--test`,
!< headless: the plane's arrow dragged along its normal, a click on the cube's face, the plane and the camera printed.
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object, view3d_object
use figure_testing, only : test_mouse_button, test_mouse_move, test_next_frame
use cb_gizmo_ui, only : draw, plane, start, to_pixel, view1, view0

implicit none
type(app_object)    :: app  !< Application.
type(view3d_object) :: view !< The 3-D view.
character(len=16)   :: arg  !< `--test`: headless.
!run cb_gizmo ./cb_gizmo --test

call get_command_argument(1, arg)
if (trim(arg) == '--test') then
   call app%init_headless(720_int32, 540_int32)
else
   call app%init('FIGURE: a plane placed by hand', 720_int32, 540_int32)
endif
call start(view)
if (trim(arg) == '--test') then
   call frames(3_int32)
   call test()
else
   do while (app%next_frame())
      call draw(view)
   enddo
endif
call view%destroy()
call app%destroy()

contains
   subroutine frames(n)
   !< Draw `n` frames.
   integer(int32), intent(in) :: n !< Frames.
   integer(int32)             :: k !< Counter.

   do k = 1_int32, n
      if (.not. app%next_frame()) exit
      call draw(view)
   enddo
   endsubroutine frames

   subroutine test()
   !< Drag the gizmo's x arrow (the plane's normal, world +x) 60 pixels further along itself; click the cube's centre.
   real(real64) :: ox, oy, ax, ay, ux, uy, d !< The gizmo's origin and a point of its x arrow; their direction.
   real(real64) :: az, el                    !< The camera.

   !region test
   write(output_unit, '(A,3F7.3)') 'plane point before:', plane(1:3, 4)
   call to_pixel(view, plane(1:3, 4), ox, oy)
   call to_pixel(view, plane(1:3, 4) + [0.1_real64, 0.0_real64, 0.0_real64], ax, ay)
   d = hypot(ax - ox, ay - oy)
   ux = (ax - ox) / d
   uy = (ay - oy) / d                              ! the arrow's direction on the screen
   call drag(ox + 50.0_real64 * ux, oy + 50.0_real64 * uy, ox + 110.0_real64 * ux, oy + 110.0_real64 * uy)
   write(output_unit, '(A,3F7.3)') 'plane point after: ', plane(1:3, 4)
   call drag(view1(1) - 48.0_real64, view0(2) + 48.0_real64, view1(1) - 48.0_real64, view0(2) + 48.0_real64)
   call frames(44_int32)                           ! the cube turns the camera over 40 frames
   call view%get_camera(azimuth=az, elevation=el)
   write(output_unit, '(A,2F8.2)') 'camera after a click on the cube (azimuth, elevation):', az, el
   !endregion test
   endsubroutine test

   subroutine drag(x0, y0, x1, y1)
   !< A drag from (x0, y0) to (x1, y1): rest, press and hold, move, release (a click when both are the same).
   real(real64), intent(in) :: x0, y0, x1, y1 !< Start and end [pixels].

   call test_mouse_move(x0, y0)
   call test_next_frame()
   call test_next_frame()
   call test_mouse_button(.true.)
   call test_next_frame()
   call test_next_frame()
   call test_mouse_move(x1, y1)
   call test_next_frame()
   call test_mouse_button(.false.)
   call frames(8_int32)
   endsubroutine drag
endprogram cb_gizmo
