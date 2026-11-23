!< figure_test_plot_frame_3d_big, a 256 x 256 surface on the Fortran 3-D frame: ImPlot3D's 65535-vertex cap, the time.
program figure_test_plot_frame_3d_big
!< figure_test_plot_frame_3d_big, a 256 x 256 surface on the Fortran 3-D frame: ImPlot3D's 65535-vertex cap, the time.
!<
!< szaghi/figure#15 P13, step 8. The bench scene `surface256` (figure_bench_scenes: 256 x 256 heights changing every
!< frame) drawn by ImPlot3D through FIGURE's API (`ip3_surface`) and by the Fortran frame (`pf3_surface`), NF frames
!< each. ImPlot3D's list has 16-bit indices and `RenderPrimitivesEx` draws, of each call, only the primitives the 65535
!< vertices left hold: a surface spends 4 vertices per cell, so of the 255 x 255 = 65025 cells 16383 are drawn (the
!< first 64 rows and a quarter), on both paths (the frame mirrors the cap). Checks:
!<
!< 1. the last frame's pictures equal at FIGURE's oracle rule (|d| <= 2, no pixel failing): the cap and the colours;
!< 2. the box's corners' pixels equal to the bit on the last frame.
!<
!< Reported, not checked: each side's median frame time over the NF frames (the headless CPU renderer's included).
!< The pictures are `figure_test_plot_frame_3d_big.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ip3_begin_plot, ip3_end_plot, &
                   ip3_plot_to_pixels, ip3_setup_axes, ip3_surface, ImGuiWindowFlags_NoDecoration
use figure_plot3d_frame, only : pf3_begin_plot, pf3_end_plot, pf3_plot_to_pixels, pf3_setup_axes
use figure_plot3d_items, only : pf3_surface
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

implicit none
integer(int32), parameter :: W = 640_int32  !< Display width [pixels].
integer(int32), parameter :: H = 480_int32  !< Display height [pixels].
integer(int32), parameter :: N = 256_int32  !< Grid points per side.
integer(int32), parameter :: NF = 20_int32  !< Frames per side.
real(real64)              :: x(N), y(N), z(N, N) !< The surface.
real(real64)              :: corners(16, 2) !< The last frame's corners' pixels per side.
real(real64)              :: times(NF, 2)   !< Frame times [ms] per side.
type(app_object)          :: app            !< Application.
logical                   :: test_passed(2) !< Per-check outcome.
logical                   :: side_fortran   !< Drawing with the Fortran frame.
integer(int32)            :: f, s, sd, i, j !< Frame, status, side, counters.
integer(int64)            :: t0, t1, rate   !< Clock.
character(len=16)         :: keep           !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do i = 1_int32, N
   x(i) = -1.0_real64 + 2.0_real64 * real(i - 1_int32, real64) / real(N - 1_int32, real64)
   y(i) = x(i)
enddo
do sd = 1_int32, 2_int32
   side_fortran = sd == 2_int32
   do f = 1_int32, NF
      do j = 1_int32, N
         do i = 1_int32, N
            z(i, j) = sin(3.0_real64 * x(i) + 0.1_real64 * real(f, real64)) * cos(2.0_real64 * y(j))
         enddo
      enddo
      call system_clock(t0, rate)
      if (.not. app%next_frame()) error stop 'figure_test_plot_frame_3d_big: next_frame returned false headless'
      call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
      if (ig_begin('plot frame 3d big', flags=ImGuiWindowFlags_NoDecoration)) call draw(corners(:, sd))
      call ig_end()
      call system_clock(t1)
      times(f, sd) = 1000.0_real64 * real(t1 - t0, real64) / real(rate, real64)
      if (f == NF) call test_capture(picture(side_fortran), s)
   enddo
   do i = 1_int32, 40_int32
      if (.not. app%next_frame()) error stop 'figure_test_plot_frame_3d_big: next_frame returned false headless'
   enddo
enddo
call app%destroy()
test_passed(1) = pictures_equal()
test_passed(2) = all(corners(:, 1) == corners(:, 2))
write(output_unit, '(A,F8.2,A,F8.2,A)') 'figure_test_plot_frame_3d_big: median frame time ImPlot3D ', &
   median(times(:, 1)), ' ms, Fortran frame ', median(times(:, 2)), ' ms (reported, not checked)'
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_3d_big checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine draw(c)
   !< The surface, by the side drawing; the box's corners' pixels.
   real(real64), intent(out) :: c(16) !< Corners' pixels.
   integer(int32)            :: k     !< Corner.
   real(real64)              :: q(3)  !< A corner.

   if (side_fortran) then
      if (.not. pf3_begin_plot('Big', width=600.0_real64, height=440.0_real64)) return
      call pf3_setup_axes('x', 'y', 'z', limits=[-1.0_real64, 1.0_real64, -1.0_real64, 1.0_real64, -1.0_real64, &
                          1.0_real64], elevation=30.0_real64, azimuth=40.0_real64)
      call pf3_surface('surface', x, y, z)
   else
      if (.not. ip3_begin_plot('Big', width=600.0_real64, height=440.0_real64)) return
      call ip3_setup_axes('x', 'y', 'z', limits=[-1.0_real64, 1.0_real64, -1.0_real64, 1.0_real64, -1.0_real64, &
                          1.0_real64], elevation=30.0_real64, azimuth=40.0_real64)
      call ip3_surface('surface', x, y, z)
   endif
   do k = 0_int32, 7_int32
      q(1) = merge(1.0_real64, -1.0_real64, iand(k, 1_int32) /= 0_int32)
      q(2) = merge(1.0_real64, -1.0_real64, iand(k, 2_int32) /= 0_int32)
      q(3) = merge(1.0_real64, -1.0_real64, iand(k, 4_int32) /= 0_int32)
      if (side_fortran) then
         call pf3_plot_to_pixels(q(1), q(2), q(3), c(2_int32 * k + 1_int32), c(2_int32 * k + 2_int32))
      else
         call ip3_plot_to_pixels(q(1), q(2), q(3), c(2_int32 * k + 1_int32), c(2_int32 * k + 2_int32))
      endif
   enddo
   if (side_fortran) then
      call pf3_end_plot()
   else
      call ip3_end_plot()
   endif
   endsubroutine draw

   function median(t) result(m)
   !< The median of a few values (insertion sort of a copy).
   real(real64), intent(in) :: t(:) !< Values.
   real(real64)             :: m    !< Median.
   real(real64)             :: a(size(t)), v !< Sorted copy, a value.
   integer(int32)           :: i, j !< Counters.

   a = t
   do i = 2_int32, size(a, kind=int32)
      v = a(i)
      j = i - 1_int32
      do while (j >= 1_int32)
         if (a(j) <= v) exit
         a(j + 1_int32) = a(j)
         j = j - 1_int32
      enddo
      a(j + 1_int32) = v
   enddo
   m = a((size(a) + 1) / 2)
   endfunction median

   function pictures_equal() result(ok)
   !< Both sides' pictures equal at the oracle's rule.
   logical        :: ok  !< Equal.
   integer(int64) :: nf_ !< Pixels that failed.
   integer(int32) :: st  !< Status.

   ok = test_compare_image(picture(.true.), picture(.false.), threshold=2_int32, max_failed=0_int32, failed=nf_, &
                           stat=st)
   if (.not. ok) write(output_unit, '(A,I0,A,A)') 'pictures: ', nf_, ' pixels failed: ', figure_last_error()
   endfunction pictures_equal

   function picture(fortran) result(name)
   !< The picture of ImPlot3D's side or the Fortran frame's.
   logical,          intent(in)  :: fortran !< The Fortran frame's.
   character(len=:), allocatable :: name    !< File name.

   if (fortran) then
      name = 'figure_test_plot_frame_3d_big.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_3d_big.implot3d.png.tmp'
   endif
   endfunction picture

   subroutine remove_files()
   !< The pictures.
   integer(int32) :: unit, ios, m !< Unit, status, side.

   do m = 1_int32, 2_int32
      open(newunit=unit, file=picture(m == 1_int32), status='old', iostat=ios)
      if (ios == 0) close(unit, status='delete')
   enddo
   endsubroutine remove_files
endprogram figure_test_plot_frame_3d_big
