!< figure_test_plot_frame_3d_input, the Fortran 3-D frame's input: rotation, pan, zoom, fit, animation, hover, as ImPlot3D's.
program figure_test_plot_frame_3d_input
!< figure_test_plot_frame_3d_input, the Fortran 3-D frame's input: rotation, pan, zoom, fit, animation, hover, as ImPlot3D's.
!<
!< szaghi/figure#15 P13, step 6. Each case is a 3-D plot with a helix, driven by the same synthetic input at the same
!< frames, first through FIGURE's API (`ip3_*`, ImPlot3D), then through the Fortran frame (`pf3_*`), 40 frames apart.
!< Checked on every frame, to the bit: the corners' and two points' pixels (rotation, ranges), the pointer's ray and
!< whether it is over the plot; pictures of a middle and the last frame at FIGURE's oracle rule (|d| <= 2, no pixel
!< failing). The cases:
!<
!< 1. a right drag on the box: the rotation (about z, then x), the drag axis kept for the drag;
!< 2. a left drag off the box: the whole box panned through the inverse rotation;
!< 3. a left drag on a face: the face's two axes panned through its plane; the face lit while hovered and held;
!< 4. the wheel on a face and off the box, then a middle drag: zoom about the pointer and about the centre;
!< 5. a zoom, then a left double click (the hovered axes fitted to the helix), then a right double click (the animated
!<    turn back to the initial rotation, frame by frame);
!< 6. `equal`, the wheel and a pan: the other axes kept at the same aspect.
!<
!< The pictures are `figure_test_plot_frame_3d_input.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64, output_unit
use, intrinsic :: ieee_arithmetic, only : ieee_quiet_nan, ieee_value
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ImGuiWindowFlags_NoDecoration
use figure_implot3d_ref, only : ip3_begin_plot, ip3_end_plot, ip3_mouse_ray, ip3_plot_to_pixels, ip3_setup_axes, &
                                ip3_line
use figure_plot3d_frame, only : pf3_begin_plot, pf3_end_plot, pf3_mouse_ray, pf3_plot_to_pixels, pf3_setup_axes
use figure_plot3d_items, only : pf3_line
use figure_testing, only : test_capture, test_compare_image, test_mouse_move, test_mouse_button, test_wheel, &
                           test_next_frame

implicit none
integer(int32), parameter :: W = 640_int32     !< Display width [pixels].
integer(int32), parameter :: H = 480_int32     !< Display height [pixels].
integer(int32), parameter :: NCASE = 6_int32   !< Cases.
integer(int32), parameter :: NF = 30_int32     !< Frames per side of a case.
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
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_3d_input: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame 3d input', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(c, f)
         call ig_end()
         if (f == NF) call test_capture(picture(c, side_fortran), s)
         if (f == 12_int32) call test_capture(picture(10_int32 + c, side_fortran), s)
         call pointer(c, f)
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      do i = 1_int32, 40_int32
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_3d_input: next_frame returned false headless'
      enddo
   enddo
   test_passed(c) = state_equal(c) .and. pictures_equal(c) .and. pictures_equal(10_int32 + c)
   if (all(state(1:20, NF, 1) == state(1:20, 1, 1))) then ! the input moved the box (no test for nothing)
      write(output_unit, '(A,I0,A)') 'case ', c, ': the input changed nothing'
      test_passed(c) = .false.
   endif
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_3d_input checks:', test_passed
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
         if (.not. pf3_begin_plot('Input', width=600.0_real64, height=440.0_real64, equal=k == 6_int32)) return
         call pf3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=20.0_real64, azimuth=30.0_real64)
         call pf3_line('helix', hx, hy, hz)
         call measure(v)
         call pf3_end_plot()
      else
         if (.not. ip3_begin_plot('Input', width=600.0_real64, height=440.0_real64, equal=k == 6_int32)) return
         call ip3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=20.0_real64, azimuth=30.0_real64)
         call ip3_line('helix', hx, hy, hz)
         call measure(v)
         call ip3_end_plot()
      endif
   endassociate
   endsubroutine draw_case

   subroutine pointer(k, fr)
   !< A case's input after frame fr, the same on both sides (fixed pixels: the plots are the same).
   integer(int32), intent(in) :: k, fr !< Case, frame.
   real(real64), parameter    :: BX = 300.0_real64, BY = 240.0_real64 !< On the box's back faces.
   real(real64), parameter    :: OX = 40.0_real64, OY = 80.0_real64   !< In the plot, off the box.
   integer(int32)             :: j     !< Counter.

   select case (k)
   case (1_int32) ! rotate
      if (fr == 1_int32) call test_mouse_move(BX, BY)
      if (fr == 2_int32) call test_mouse_button(.true., 'right')
      if (fr >= 3_int32 .and. fr <= 9_int32) call test_mouse_move(BX + 7.0_real64 * real(fr - 2, real64), &
                                                                  BY + 3.0_real64 * real(fr - 2, real64))
      if (fr == 10_int32) call test_mouse_button(.false., 'right')
   case (2_int32, 3_int32) ! pan off the box, on a face
      if (fr == 1_int32) then
         if (k == 2_int32) then
            call test_mouse_move(OX, OY)
         else
            call test_mouse_move(BX, BY)
         endif
      endif
      if (fr == 2_int32) call test_mouse_button(.true.)
      if (fr >= 3_int32 .and. fr <= 8_int32) then
         if (k == 2_int32) then
            call test_mouse_move(OX + 6.0_real64 * real(fr - 2, real64), OY + 4.0_real64 * real(fr - 2, real64))
         else
            call test_mouse_move(BX + 6.0_real64 * real(fr - 2, real64), BY - 4.0_real64 * real(fr - 2, real64))
         endif
      endif
      if (fr == 14_int32) call test_mouse_button(.false.)
   case (4_int32) ! zoom
      if (fr == 1_int32) call test_mouse_move(BX, BY)
      if (fr == 3_int32) call test_wheel(1.0_real64)
      if (fr == 5_int32) call test_wheel(-2.0_real64)
      if (fr == 7_int32) call test_mouse_move(OX, OY)
      if (fr == 9_int32) call test_wheel(1.0_real64)
      if (fr == 15_int32) call test_mouse_button(.true., 'middle')
      if (fr >= 16_int32 .and. fr <= 19_int32) call test_mouse_move(OX, OY + 5.0_real64 * real(fr - 15, real64))
      if (fr == 20_int32) call test_mouse_button(.false., 'middle')
   case (5_int32) ! zoom, fit, animated turn
      if (fr == 1_int32) call test_mouse_move(BX, BY)
      if (fr == 2_int32) call test_wheel(2.0_real64)
      if (fr == 4_int32) call test_mouse_move(OX, OY)
      if (fr == 5_int32) then
         do j = 1_int32, 2_int32
            call test_mouse_button(.true.)
            call test_next_frame()
            call test_mouse_button(.false.)
            if (j == 1_int32) call test_next_frame()
         enddo
      endif
      if (fr == 9_int32) call test_mouse_move(BX + 100.0_real64, BY)
      if (fr == 10_int32) call test_mouse_button(.true., 'right')
      if (fr >= 11_int32 .and. fr <= 13_int32) call test_mouse_move(BX + 100.0_real64 + 8.0_real64 * real(fr - 10, real64), BY)
      if (fr == 14_int32) call test_mouse_button(.false., 'right')
      if (fr == 16_int32) call test_mouse_move(OX, OY)
      if (fr == 17_int32) then
         do j = 1_int32, 2_int32
            call test_mouse_button(.true., 'right')
            call test_next_frame()
            call test_mouse_button(.false., 'right')
            if (j == 1_int32) call test_next_frame()
         enddo
      endif
   case default ! equal: wheel, pan
      if (fr == 1_int32) call test_mouse_move(BX, BY)
      if (fr == 3_int32) call test_wheel(1.0_real64)
      if (fr == 5_int32) call test_mouse_button(.true.)
      if (fr >= 6_int32 .and. fr <= 9_int32) call test_mouse_move(BX - 5.0_real64 * real(fr - 5, real64), BY)
      if (fr == 10_int32) call test_mouse_button(.false.)
   endselect
   endsubroutine pointer

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
      name = 'figure_test_plot_frame_3d_input.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_3d_input.'//trim(tag)//'.implot3d.png.tmp'
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
endprogram figure_test_plot_frame_3d_input
