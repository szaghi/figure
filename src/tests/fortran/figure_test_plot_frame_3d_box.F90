!< figure_test_plot_frame_3d_box, the Fortran 3-D frame's box, axes and camera (figure_plot3d_frame), as ImPlot3D's.
program figure_test_plot_frame_3d_box
!< figure_test_plot_frame_3d_box, the Fortran 3-D frame's box, axes and camera (figure_plot3d_frame), as ImPlot3D's.
!<
!< szaghi/figure#15 P13, step 2. Each case is an empty 3-D plot drawn on a few frames first by ImPlot3D through FIGURE's
!< API (`ip3_*`), then by the Fortran frame (`pf3_*`), 40 frames apart. Checked on every frame, to the bit: the eight
!< box corners' pixels and two inner points' (`plot_to_pixels`: the rotation, the ranges, the view scale, the plot
!< rectangle), the pointer's ray in plot coordinates (`mouse_ray`: the inverse maps, in double) and whether it is over
!< the plot; the last frame's pictures at FIGURE's oracle rule (|d| <= 2, no pixel failing). The cases:
!<
!< 1. a title, three labels, limits, elevation 20 and azimuth 30;
!< 2. no title ('##'), a box scaled (1, 2, 0.5), elevation -30 and azimuth -60;
!< 3. a top view (elevation 90): the 2-D plane's branch of the axes' corners;
!< 4. a front view (elevation 0, azimuth 0);
!< 5. `equal` with ranges of different sizes, elevation 45 and azimuth 135;
!< 6. ImPlot3D's initial rotation, no limits (the first frame's fit of nothing), the x axis inverted, no y grid, a title
!<    with a hidden part.
!<
!< The pictures are `figure_test_plot_frame_3d_box.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ImGuiWindowFlags_NoDecoration
use figure_implot3d_ref, only : ip3_begin_plot, ip3_end_plot, ip3_mouse_ray, ip3_plot_to_pixels, ip3_setup_axes, &
                                ip3_setup_axis, ip3_setup_box
use figure_plot3d_frame, only : pf3_begin_plot, pf3_end_plot, pf3_mouse_ray, pf3_plot_to_pixels, pf3_setup_axes, &
                                pf3_setup_axis, pf3_setup_box
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

implicit none
integer(int32), parameter :: W = 640_int32     !< Display width [pixels].
integer(int32), parameter :: H = 480_int32     !< Display height [pixels].
integer(int32), parameter :: NCASE = 6_int32   !< Cases.
integer(int32), parameter :: NF = 3_int32      !< Frames per side of a case.
integer(int32), parameter :: NSTATE = 27_int32 !< Values per frame: 8 corners (16), 2 points (4), the ray (6), over.
real(real64),   parameter :: LIM1(6) = [-1.0_real64, 1.0_real64, -2.0_real64, 2.0_real64, 0.0_real64, 5.0_real64] !< Limits.
real(real64),   parameter :: LIM5(6) = [0.0_real64, 10.0_real64, -1.0_real64, 1.0_real64, 0.0_real64, 3.0_real64] !< ...
real(real64),   parameter :: SCALE2(3) = [1.0_real64, 2.0_real64, 0.5_real64] !< Case 2's box.
type(app_object)          :: app               !< Application.
real(real64)              :: state(NSTATE, NF, 2) !< Per frame and side.
logical                   :: test_passed(NCASE) !< Per-case outcome.
logical                   :: side_fortran      !< Drawing with the Fortran frame.
integer(int32)            :: c, f, s, sd, i    !< Case, frame, status, side, counter.
character(len=16)         :: keep              !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do c = 1_int32, NCASE
   state = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 ImPlot3D, 2 the Fortran frame
      side_fortran = sd == 2_int32
      do f = 1_int32, NF
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_3d_box: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame 3d box', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(c, f)
         call ig_end()
         if (f == NF) call test_capture(picture(c, side_fortran), s)
      enddo
      do i = 1_int32, 40_int32
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_3d_box: next_frame returned false headless'
      enddo
   enddo
   test_passed(c) = state_equal(c) .and. pictures_equal(c)
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_3d_box checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine draw_case(k, fr)
   !< A case's plot on a frame, by the side drawing.
   integer(int32), intent(in) :: k, fr !< Case, frame.
   integer(int32)             :: m     !< Side.

   m = merge(2_int32, 1_int32, side_fortran)
   associate(v => state(:, fr, m))
      if (side_fortran) then
         select case (k)
         case (1_int32)
            if (.not. pf3_begin_plot('Box', width=600.0_real64, height=440.0_real64)) return
            call pf3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=20.0_real64, azimuth=30.0_real64)
         case (2_int32)
            if (.not. pf3_begin_plot('##b2', width=600.0_real64, height=440.0_real64)) return
            call pf3_setup_axes('east', 'north', 'up', limits=LIM1, elevation=-30.0_real64, azimuth=-60.0_real64)
            call pf3_setup_box(scale=SCALE2)
         case (3_int32)
            if (.not. pf3_begin_plot('Top', width=600.0_real64, height=440.0_real64)) return
            call pf3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=90.0_real64, azimuth=0.0_real64)
         case (4_int32)
            if (.not. pf3_begin_plot('Front', width=600.0_real64, height=440.0_real64)) return
            call pf3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=0.0_real64, azimuth=0.0_real64)
         case (5_int32)
            if (.not. pf3_begin_plot('Equal', width=600.0_real64, height=440.0_real64, equal=.true.)) return
            call pf3_setup_axes('x', 'y', 'z', limits=LIM5, elevation=45.0_real64, azimuth=135.0_real64)
         case default
            if (.not. pf3_begin_plot('Initial##six', width=600.0_real64, height=440.0_real64)) return
            call pf3_setup_axes('x', 'y', 'z')
            call pf3_setup_axis('x', label='inverted x', invert=.true.)
            call pf3_setup_axis('y', label='y', no_grid=.true.)
         endselect
         call measure(v)
         call pf3_end_plot()
      else
         select case (k)
         case (1_int32)
            if (.not. ip3_begin_plot('Box', width=600.0_real64, height=440.0_real64)) return
            call ip3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=20.0_real64, azimuth=30.0_real64)
         case (2_int32)
            if (.not. ip3_begin_plot('##b2', width=600.0_real64, height=440.0_real64)) return
            call ip3_setup_axes('east', 'north', 'up', limits=LIM1, elevation=-30.0_real64, azimuth=-60.0_real64)
            call ip3_setup_box(scale=SCALE2)
         case (3_int32)
            if (.not. ip3_begin_plot('Top', width=600.0_real64, height=440.0_real64)) return
            call ip3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=90.0_real64, azimuth=0.0_real64)
         case (4_int32)
            if (.not. ip3_begin_plot('Front', width=600.0_real64, height=440.0_real64)) return
            call ip3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=0.0_real64, azimuth=0.0_real64)
         case (5_int32)
            if (.not. ip3_begin_plot('Equal', width=600.0_real64, height=440.0_real64, equal=.true.)) return
            call ip3_setup_axes('x', 'y', 'z', limits=LIM5, elevation=45.0_real64, azimuth=135.0_real64)
         case default
            if (.not. ip3_begin_plot('Initial##six', width=600.0_real64, height=440.0_real64)) return
            call ip3_setup_axes('x', 'y', 'z')
            call ip3_setup_axis('x', label='inverted x', invert=.true.)
            call ip3_setup_axis('y', label='y', no_grid=.true.)
         endselect
         call measure(v)
         call ip3_end_plot()
      endif
   endassociate
   endsubroutine draw_case

   subroutine measure(v)
   !< The state of the plot being declared, by the side drawing: corners' and points' pixels, the pointer's ray.
   real(real64), intent(out) :: v(NSTATE) !< State.
   real(real64)              :: o(3), d(3) !< Ray.
   real(real64)              :: q(3)      !< A point.
   integer(int32)            :: j         !< Corner.
   logical                   :: over      !< Over the plot.

   do j = 0_int32, 7_int32 ! the box of LIM1 (the ranges of cases 1-4, a point of the others')
      q(1) = LIM1(1)
      if (iand(j, 1_int32) /= 0_int32) q(1) = LIM1(2)
      q(2) = LIM1(3)
      if (iand(j, 2_int32) /= 0_int32) q(2) = LIM1(4)
      q(3) = LIM1(5)
      if (iand(j, 4_int32) /= 0_int32) q(3) = LIM1(6)
      call to_pixels(q, v(2_int32 * j + 1_int32), v(2_int32 * j + 2_int32))
   enddo
   q(1) = 0.3_real64
   q(2) = -0.7_real64
   q(3) = 1.1_real64
   call to_pixels(q, v(17), v(18))
   q(1) = 0.25_real64
   q(2) = 0.5_real64
   q(3) = 0.75_real64
   call to_pixels(q, v(19), v(20))
   if (side_fortran) then
      over = pf3_mouse_ray(o, d)
   else
      over = ip3_mouse_ray(o, d)
   endif
   v(21:23) = o
   v(24:26) = d
   v(27) = merge(1.0_real64, 0.0_real64, over)
   endsubroutine measure

   subroutine to_pixels(q, px, py)
   !< A point's pixel, by the side drawing.
   real(real64), intent(in)  :: q(3)   !< Point.
   real(real64), intent(out) :: px, py !< Pixel.

   if (side_fortran) then
      call pf3_plot_to_pixels(q(1), q(2), q(3), px, py)
   else
      call ip3_plot_to_pixels(q(1), q(2), q(3), px, py)
   endif
   endsubroutine to_pixels

   function state_equal(k) result(ok)
   !< Both sides' state equal on every frame.
   integer(int32), intent(in) :: k  !< Case.
   logical                    :: ok !< Equal.
   integer(int32)             :: fr !< Frame.

   ok = .true.
   do fr = 1_int32, NF
      if (all(state(:, fr, 1) == state(:, fr, 2))) cycle
      ok = .false.
      write(output_unit, '(A,I0,A,I0,A)') 'case ', k, ', frame ', fr, ': ImPlot3D, frame'
      write(output_unit, '(5ES24.16)') state(:, fr, 1)
      write(output_unit, '(5ES24.16)') state(:, fr, 2)
   enddo
   endfunction state_equal

   function pictures_equal(k) result(ok)
   !< A case's pictures of both sides equal at the oracle's rule.
   integer(int32), intent(in) :: k   !< Case.
   logical                    :: ok  !< Equal.
   integer(int64)             :: nf_ !< Pixels that failed.
   integer(int32)             :: st  !< Status.

   ok = test_compare_image(picture(k, .true.), picture(k, .false.), threshold=2_int32, max_failed=0_int32, &
                           failed=nf_, stat=st)
   if (.not. ok) write(output_unit, '(A,I0,A,I0,A,A)') 'case ', k, ': ', nf_, ' pixels failed: ', figure_last_error()
   endfunction pictures_equal

   function picture(k, fortran) result(name)
   !< A case's picture: ImPlot3D's or the Fortran frame's.
   integer(int32), intent(in)    :: k       !< Case.
   logical,        intent(in)    :: fortran !< The Fortran frame's.
   character(len=:), allocatable :: name    !< File name.
   character(len=8)              :: tag     !< The case's number.

   write(tag, '(I0)') k
   if (fortran) then
      name = 'figure_test_plot_frame_3d_box.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_3d_box.'//trim(tag)//'.implot3d.png.tmp'
   endif
   endfunction picture

   subroutine remove_files()
   !< The pictures removed (and a mismatch's .new.png and .diff.png, left only on a failure).
   integer(int32) :: k, u, ios, j !< Case, unit, status, side.
   logical        :: there        !< The file exists.

   do k = 1_int32, NCASE
      do j = 1_int32, 2_int32
         inquire(file=picture(k, j == 2_int32), exist=there)
         if (.not. there) cycle
         open(newunit=u, file=picture(k, j == 2_int32), status='old', iostat=ios)
         if (ios == 0) close(u, status='delete')
      enddo
   enddo
   endsubroutine remove_files
endprogram figure_test_plot_frame_3d_box
