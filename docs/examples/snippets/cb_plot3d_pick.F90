!< cb_plot3d_pick, cookbook: a body of triangles and quads over a field image on the floor of a 3-D plot; the point of
!< the floor under the pointer, from the pointer's ray.
program cb_plot3d_pick
!< cb_plot3d_pick, cookbook: a body of triangles and quads over a field image on the floor of a 3-D plot; the point of
!< the floor under the pointer, from the pointer's ray.
use, intrinsic :: iso_fortran_env, only : int8, int32, real64
use figure, only : app_object, ig_begin, ig_end, ig_set_next_window, ig_text, ig_text_disabled, ip3_begin_plot,     &
                   ip3_end_plot, ip3_image, ip3_mouse_ray, ip3_quads, ip3_setup_axes, ip3_setup_box,  &
                   ip3_setup_legend, ip3_triangles, texture_object

implicit none
integer(int32), parameter :: M = 64_int32 !< Pixels of the floor's image, per side.
type(app_object)          :: app          !< Application.
type(texture_object)      :: floor        !< The floor's field.
integer(int8)             :: rgba(4, M, M) !< Its pixels.
real(real64)              :: body(3, 6)   !< A wedge: two triangles (6 vertices) ...
real(real64)              :: back(3, 4)   !< ... its back face.
real(real64)              :: corners(3, 4) !< The floor: top-left, top-right, bottom-right, bottom-left.
real(real64)              :: o(3), d(3)   !< The pointer's ray.
real(real64)              :: hit(3)       !< Where it meets the floor.
real(real64)              :: t            !< Its parameter there.
logical                   :: over         !< The pointer is over the plot.
character(len=64)         :: line         !< A formatted readout.
integer(int32)            :: i, j         !< Pixels.

do j = 1_int32, M
   do i = 1_int32, M                                    ! a field: a ring of high values
      t = exp(-((hypot(real(i - M / 2, real64), real(j - M / 2, real64)) - 18.0_real64) / 6.0_real64)**2)
      rgba(:, i, j) = byte([nint(255 * t), nint(80 + 120 * t), nint(255 * (1 - t)), 255])
   enddo
enddo
corners = reshape([-1.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, 1.0_real64, 0.0_real64, &
                   1.0_real64, -1.0_real64, 0.0_real64, -1.0_real64, -1.0_real64, 0.0_real64], [3, 4])
body = reshape([-0.5_real64, -0.3_real64, 0.1_real64, 0.5_real64, 0.0_real64, 0.1_real64,              &
                        -0.5_real64, 0.3_real64, 0.1_real64, -0.5_real64, -0.3_real64, 0.1_real64,             &
                        -0.5_real64, 0.0_real64, 0.5_real64, 0.5_real64, 0.0_real64, 0.1_real64], [3, 6])
back = reshape([-0.5_real64, -0.3_real64, 0.1_real64, -0.5_real64, 0.3_real64, 0.1_real64,                      &
                -0.5_real64, 0.3_real64, 0.5_real64, -0.5_real64, -0.3_real64, 0.5_real64], [3, 4])
hit = 0.0_real64
over = .false.
call app%init('FIGURE: picking in a 3-D plot', 640_int32, 560_int32)
call floor%init(M, M)
call floor%update(rgba)
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 620.0_real64, 540.0_real64)
   if (ig_begin('Body')) then
      if (ip3_begin_plot('body over a field', height=-40.0_real64)) then
         call ip3_setup_axes('x', 'y', 'z', limits=[-1.0_real64, 1.0_real64, -1.0_real64, 1.0_real64, &
                             0.0_real64, 1.0_real64], elevation=30.0_real64, azimuth=-50.0_real64)
         call ip3_setup_box(scale=[1.0_real64, 1.0_real64, 0.6_real64])   ! a flatter box
         call ip3_setup_legend('ne')
         call ip3_image('field', floor, corners)                          ! the floor, z = 0
         call ip3_triangles('wedge', body(1, :), body(2, :), body(3, :))
         call ip3_quads('back', back(1, :), back(2, :), back(3, :))
         over = ip3_mouse_ray(o, d)                                       ! the ray under the pointer
         if (over .and. abs(d(3)) > 1.0e-9_real64) then
            t = -o(3) / d(3)                                              ! ... meets z = 0 there
            hit = o + t * d
         endif
         call ip3_end_plot()
      endif
      if (over .and. all(abs(hit(1:2)) <= 1.0_real64)) then
         write(line, '(A,F6.2,A,F6.2)') 'floor at x = ', hit(1), ', y = ', hit(2)
         call ig_text(trim(line))
      else
         call ig_text_disabled('point at the floor')
      endif
   endif
   call ig_end()
enddo
call floor%destroy()
call app%destroy()
contains
   elemental function byte(v) result(b)
   !< A 0-255 value as the signed byte a texture holds.
   integer, intent(in) :: v !< Value, 0 to 255.
   integer(int8)       :: b !< Byte.

   b = int(v - merge(256, 0, v > 127), int8)
   endfunction byte
endprogram cb_plot3d_pick
