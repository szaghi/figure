!< figure_test_plot_frame_3d_lines, the Fortran 3-D frame's lines and markers (figure_plot3d_items), as ImPlot3D's.
program figure_test_plot_frame_3d_lines
!< figure_test_plot_frame_3d_lines, the Fortran 3-D frame's lines and markers (figure_plot3d_items), as ImPlot3D's.
!<
!< szaghi/figure#15 P13, step 4. Each case is a 3-D plot with lines and markers drawn on a few frames first by ImPlot3D
!< through FIGURE's API (`ip3_*`), then by the Fortran frame (`pf3_*`, figure_plot3d_items), 40 frames apart. Checked on
!< every frame, to the bit: the corners' and two points' pixels (the ranges after the fit), the pointer's ray and
!< whether it is over the plot; the pictures of the first and last frames at FIGURE's oracle rule (|d| <= 2, no pixel
!< failing): the triangles depth-sorted as ImPlot3D sorts them, the legend. The cases:
!<
!< 1. a helix (a line, automatic colour) and markers on it (a scatter, automatic: circles), limits given;
!< 2. lines with flags: segments, a loop, a line skipping NaNs and one not, a line leaving the box (clipped), per-point
!<    colours, a thick line, a line with square markers;
!< 3. every marker shape (a scatter each), a fill alpha of 0.5, per-point colours and sizes;
!< 4. the first frame's fit to the data (no limits), single precision arrays, `equal`;
!< 5. hidden labels ('##'), an item without legend (NoLegend), the legend horizontal at the south-east.
!<
!< The pictures are `figure_test_plot_frame_3d_lines.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64, output_unit
use, intrinsic :: ieee_arithmetic, only : ieee_quiet_nan, ieee_value
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ip3_begin_plot, ip3_end_plot, &
                   ip3_mouse_ray, ip3_plot_to_pixels, ip3_setup_axes, ip3_setup_legend, ip3_line, ip3_scatter,      &
                   ip3_spec, ImGuiWindowFlags_NoDecoration, ImPlot3DLineFlags_Segments, ImPlot3DLineFlags_Loop,     &
                   ImPlot3DLineFlags_SkipNaN, ImPlot3DItemFlags_NoLegend, ImPlot3DMarker_Square
use figure_plot3d_frame, only : pf3_begin_plot, pf3_end_plot, pf3_mouse_ray, pf3_plot_to_pixels, pf3_setup_axes, &
                                pf3_setup_legend
use figure_plot3d_items, only : pf3_line, pf3_scatter, pf3_spec
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

implicit none
integer(int32), parameter :: W = 640_int32     !< Display width [pixels].
integer(int32), parameter :: H = 480_int32     !< Display height [pixels].
integer(int32), parameter :: NCASE = 5_int32   !< Cases.
integer(int32), parameter :: NF = 3_int32      !< Frames per side of a case.
integer(int32), parameter :: NP = 120_int32    !< Points of the helix.
integer(int32), parameter :: NSTATE = 27_int32 !< Values per frame: 8 corners (16), 2 points (4), the ray (6), over.
real(real64),   parameter :: LIM1(6) = [-1.0_real64, 1.0_real64, -2.0_real64, 2.0_real64, 0.0_real64, 5.0_real64] !< Limits.
real(real64),   parameter :: RED(4) = [0.9_real64, 0.2_real64, 0.15_real64, 1.0_real64]  !< A colour.
real(real64),   parameter :: BLUE(4) = [0.2_real64, 0.4_real64, 0.95_real64, 1.0_real64] !< Another.
real(real64)              :: hx(NP), hy(NP), hz(NP) !< The helix.
real(real32)              :: sx(NP), sy(NP), sz(NP) !< The helix, single precision.
real(real64)              :: cols(4, NP)            !< Per-point colours.
real(real64)              :: sizes(NP)              !< Per-point sizes.
real(real64)              :: nx(12), ny(12), nz(12) !< A line with NaNs.
type(app_object)          :: app               !< Application.
real(real64)              :: state(NSTATE, NF, 2) !< Per frame and side.
logical                   :: test_passed(NCASE) !< Per-case outcome.
logical                   :: side_fortran      !< Drawing with the Fortran frame.
integer(int32)            :: c, f, s, sd, i    !< Case, frame, status, side, counter.
character(len=16)         :: keep              !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do i = 1_int32, NP
   hx(i) = 0.8_real64 * cos(real(i, real64) * 0.15_real64)
   hy(i) = 1.6_real64 * sin(real(i, real64) * 0.15_real64)
   hz(i) = real(i, real64) * 0.04_real64
   cols(:, i) = [real(i, real64) / real(NP, real64), 0.5_real64, 1.0_real64 - real(i, real64) / real(NP, real64), &
                 1.0_real64]
   sizes(i) = 2.0_real64 + mod(real(i, real64), 5.0_real64)
enddo
sx = real(hx, real32)
sy = real(hy, real32)
sz = real(hz * 2.0_real64, real32)
do i = 1_int32, 12_int32
   nx(i) = -0.9_real64 + real(i, real64) * 0.15_real64
   ny(i) = 1.5_real64 * sin(real(i, real64))
   nz(i) = 2.5_real64 + cos(real(i, real64))
enddo
nx(5) = ieee_value(1.0_real64, ieee_quiet_nan)
nz(9) = ieee_value(1.0_real64, ieee_quiet_nan)
do c = 1_int32, NCASE
   state = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 ImPlot3D, 2 the Fortran frame
      side_fortran = sd == 2_int32
      do f = 1_int32, NF
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_3d_lines: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame 3d lines', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(c, f)
         call ig_end()
         if (f == NF) call test_capture(picture(c, side_fortran), s)
         if (f == 1_int32) call test_capture(picture(10_int32 + c, side_fortran), s)
      enddo
      do i = 1_int32, 40_int32
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_3d_lines: next_frame returned false headless'
      enddo
   enddo
   test_passed(c) = state_equal(c) .and. pictures_equal(c) .and. pictures_equal(10_int32 + c)
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_3d_lines checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine draw_case(k, fr)
   !< A case's plot on a frame, by the side drawing.
   integer(int32), intent(in) :: k, fr !< Case, frame.
   integer(int32)             :: m, j  !< Side, marker.
   character(len=8)           :: lab   !< A label.

   m = merge(2_int32, 1_int32, side_fortran)
   associate(v => state(:, fr, m))
      if (side_fortran) then
         select case (k)
         case (1_int32)
            if (.not. pf3_begin_plot('Helix', width=600.0_real64, height=440.0_real64)) return
            call pf3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=20.0_real64, azimuth=30.0_real64)
            call pf3_line('helix', hx, hy, hz)
            call pf3_scatter('points', hx(::6), hy(::6), hz(::6))
         case (2_int32)
            if (.not. pf3_begin_plot('Flags', width=600.0_real64, height=440.0_real64)) return
            call pf3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=35.0_real64, azimuth=-40.0_real64)
            call pf3_line('segments', hx(1:40), hy(1:40), hz(1:40), spec=pf3_spec(flags=ImPlot3DLineFlags_Segments))
            call pf3_line('loop', hx(41:60), hy(41:60), hz(41:60) + 1.0_real64, &
                          spec=pf3_spec(flags=ImPlot3DLineFlags_Loop, line_color=RED))
            call pf3_line('skip', nx, ny, nz, spec=pf3_spec(flags=ImPlot3DLineFlags_SkipNaN, line_weight=3.0_real64))
            call pf3_line('nan', nx, ny + 0.3_real64, nz, spec=pf3_spec(line_color=BLUE))
            call pf3_line('out', 1.5_real64 * hx(61:100), hy(61:100), hz(61:100) - 1.5_real64, colors=cols(:, 61:100))
            call pf3_line('squares', hx(101:), hy(101:), hz(101:) - 4.0_real64, &
                          spec=pf3_spec(marker=ImPlot3DMarker_Square, marker_size=5.0_real64))
         case (3_int32)
            if (.not. pf3_begin_plot('Markers', width=600.0_real64, height=440.0_real64)) return
            call pf3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=25.0_real64, azimuth=50.0_real64)
            do j = 0_int32, 9_int32
               write(lab, '(A,I0)') 'm', j
               call pf3_scatter(trim(lab), hx(j * 10 + 1:j * 10 + 3), hy(j * 10 + 1:j * 10 + 3), &
                                hz(j * 10 + 1:j * 10 + 3), spec=pf3_spec(marker=j, marker_size=6.0_real64, &
                                fill_alpha=0.5_real64))
            enddo
            call pf3_scatter('colours', hx(101:), hy(101:), hz(101:) - 4.0_real64, colors=cols(:, 101:), &
                             sizes=sizes(101:))
         case (4_int32)
            if (.not. pf3_begin_plot('Fit', width=600.0_real64, height=440.0_real64, equal=.true.)) return
            call pf3_setup_axes('x', 'y', 'z', elevation=15.0_real64, azimuth=-70.0_real64)
            call pf3_line('single', sx, sy, sz)
         case default
            if (.not. pf3_begin_plot('##legend', width=600.0_real64, height=440.0_real64)) return
            call pf3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=20.0_real64, azimuth=30.0_real64)
            call pf3_setup_legend(location='se', horizontal=.true.)
            call pf3_line('##hidden', hx(1:40), hy(1:40), hz(1:40))
            call pf3_line('shown##1', hx(41:80), hy(41:80), hz(41:80))
            call pf3_line('none', hx(81:), hy(81:), hz(81:), spec=pf3_spec(flags=ImPlot3DItemFlags_NoLegend))
            call pf3_scatter('dots', hx(::10), hy(::10), hz(::10))
         endselect
         call measure(v)
         call pf3_end_plot()
      else
         select case (k)
         case (1_int32)
            if (.not. ip3_begin_plot('Helix', width=600.0_real64, height=440.0_real64)) return
            call ip3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=20.0_real64, azimuth=30.0_real64)
            call ip3_line('helix', hx, hy, hz)
            call ip3_scatter('points', hx(::6), hy(::6), hz(::6))
         case (2_int32)
            if (.not. ip3_begin_plot('Flags', width=600.0_real64, height=440.0_real64)) return
            call ip3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=35.0_real64, azimuth=-40.0_real64)
            call ip3_line('segments', hx(1:40), hy(1:40), hz(1:40), spec=ip3_spec(flags=ImPlot3DLineFlags_Segments))
            call ip3_line('loop', hx(41:60), hy(41:60), hz(41:60) + 1.0_real64, &
                          spec=ip3_spec(flags=ImPlot3DLineFlags_Loop, line_color=RED))
            call ip3_line('skip', nx, ny, nz, spec=ip3_spec(flags=ImPlot3DLineFlags_SkipNaN, line_weight=3.0_real64))
            call ip3_line('nan', nx, ny + 0.3_real64, nz, spec=ip3_spec(line_color=BLUE))
            call ip3_line('out', 1.5_real64 * hx(61:100), hy(61:100), hz(61:100) - 1.5_real64, colors=cols(:, 61:100))
            call ip3_line('squares', hx(101:), hy(101:), hz(101:) - 4.0_real64, &
                          spec=ip3_spec(marker=ImPlot3DMarker_Square, marker_size=5.0_real64))
         case (3_int32)
            if (.not. ip3_begin_plot('Markers', width=600.0_real64, height=440.0_real64)) return
            call ip3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=25.0_real64, azimuth=50.0_real64)
            do j = 0_int32, 9_int32
               write(lab, '(A,I0)') 'm', j
               call ip3_scatter(trim(lab), hx(j * 10 + 1:j * 10 + 3), hy(j * 10 + 1:j * 10 + 3), &
                                hz(j * 10 + 1:j * 10 + 3), spec=ip3_spec(marker=j, marker_size=6.0_real64, &
                                fill_alpha=0.5_real64))
            enddo
            call ip3_scatter('colours', hx(101:), hy(101:), hz(101:) - 4.0_real64, colors=cols(:, 101:), &
                             sizes=sizes(101:))
         case (4_int32)
            if (.not. ip3_begin_plot('Fit', width=600.0_real64, height=440.0_real64, equal=.true.)) return
            call ip3_setup_axes('x', 'y', 'z', elevation=15.0_real64, azimuth=-70.0_real64)
            call ip3_line('single', sx, sy, sz)
         case default
            if (.not. ip3_begin_plot('##legend', width=600.0_real64, height=440.0_real64)) return
            call ip3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=20.0_real64, azimuth=30.0_real64)
            call ip3_setup_legend(location='se', horizontal=.true.)
            call ip3_line('##hidden', hx(1:40), hy(1:40), hz(1:40))
            call ip3_line('shown##1', hx(41:80), hy(41:80), hz(41:80))
            call ip3_line('none', hx(81:), hy(81:), hz(81:), spec=ip3_spec(flags=ImPlot3DItemFlags_NoLegend))
            call ip3_scatter('dots', hx(::10), hy(::10), hz(::10))
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
      name = 'figure_test_plot_frame_3d_lines.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_3d_lines.'//trim(tag)//'.implot3d.png.tmp'
   endif
   endfunction picture

   subroutine remove_files()
   !< The pictures removed (and a mismatch's .new.png and .diff.png, left only on a failure).
   integer(int32) :: k, u, ios, j !< Case, unit, status, side.
   logical        :: there        !< The file exists.

   do k = 1_int32, 10_int32 + NCASE
      do j = 1_int32, 2_int32
         inquire(file=picture(k, j == 2_int32), exist=there)
         if (.not. there) cycle
         open(newunit=u, file=picture(k, j == 2_int32), status='old', iostat=ios)
         if (ios == 0) close(u, status='delete')
      enddo
   enddo
   endsubroutine remove_files
endprogram figure_test_plot_frame_3d_lines
