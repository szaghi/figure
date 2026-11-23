!< figure_test_plot_frame_device, the Fortran plot frame's lines of device series (`pf_line_device`), as ImPlot's.

#include "fundal.H"

program figure_test_plot_frame_device
!< figure_test_plot_frame_device, the Fortran plot frame's lines of device series (`pf_line_device`), as ImPlot's.
!<
!< szaghi/figure#15, the Fortran path with OpenACC (the tests-nvf-acc-fortran mode), as figure_test_device for the
!< current path. Headless. Series filled on the device (FUNDAL's `dev_alloc` and a kernel: OpenACC with nvfortran
!< `-acc`, 10**8 points on the GPU; FUNDAL's CPU mode in the other -fortran modes, 10**6 points, the device being the
!< host), plotted by ImPlot through FIGURE's API (`ip_line_device`) and by the Fortran frame (`pf_line_device`), both
!< decimated on the device (figure_decimate_device), only the kept points copied back. Checked:
!<
!< 1. a full view: ImPlot's side decimated (fewer than a tenth of the series kept), the same picture (FIGURE's
!<    oracle rule: |d| <= 2, no pixel failing);
!< 2. a zoom (x range 1/50 of the series): the same picture;
!< 3. a short series (100 points: not decimated) copied whole: the same picture;
!< 4. a single precision series (a quarter of the points): the same picture;
!< 5. the frame time of the frame's device item (median of 20 frames, the decimation and the copy of the points kept),
!<    printed with ImPlot's; on the GPU at 10**8 points it must stay under 50 ms, as figure_test_device's (copying the
!<    series whole, 1.6 GB, would not).
!<
!< The pictures are `figure_test_plot_frame_device.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64, output_unit
use fundal, only : dev_alloc, dev_free, dev_init
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ip_begin_plot, ip_end_plot, &
                   ip_line_device, ip_setup_axes_limits, ImGuiWindowFlags_NoDecoration
use figure_implot, only : ip_kept => plot_kept
use figure_plot_frame, only : pf_begin_plot, pf_end_plot, pf_setup_axes_limits
use figure_plot_items, only : pf_line_device
use figure_testing, only : test_capture, test_compare_image

implicit none
#if defined DEV_OAC
integer(int64), parameter   :: N = 100000000_int64 !< Points: on the GPU.
#else
integer(int64), parameter   :: N = 1000000_int64   !< Points: the device is the host.
#endif
integer(int64), parameter   :: N32 = N / 4_int64   !< Points of the single precision series.
integer(int32), parameter   :: W = 640_int32       !< Display width [pixels].
integer(int32), parameter   :: H = 360_int32       !< Display height [pixels].
integer(int32), parameter   :: S_FULL = 1_int32, S_SHORT = 2_int32, S_R32 = 3_int32 !< Series.
type(app_object)            :: app                 !< Application.
real(real64), pointer       :: xd(:) => null()     !< Abscissae, on the device.
real(real64), pointer       :: yd(:) => null()     !< Ordinates, on the device.
real(real64), pointer       :: xs(:) => null()     !< A short series' abscissae, on the device.
real(real64), pointer       :: ys(:) => null()     !< ... its ordinates.
real(real32), pointer       :: xf(:) => null()     !< Single precision abscissae, on the device.
real(real32), pointer       :: yf(:) => null()     !< ... ordinates.
logical                     :: test_passed(5)      !< Per-check outcome.
integer(int64)              :: ki                  !< Points ImPlot kept.
integer(int64)              :: t0, t1, rate        !< Clock.
real(real64)                :: ms(20, 2)           !< Frame times of the device item [ms]: ImPlot, the frame.
integer(int32)              :: ierr, f, sd         !< Status, frame, side.
character(len=16)           :: keep                !< FIGURE_TEST_KEEP.

test_passed = .false.
call dev_init()
call dev_alloc(fptr_dev=xd, ubounds=[int(N, int32)], ierr=ierr, label='test: x')
if (ierr == 0_int32) call dev_alloc(fptr_dev=yd, ubounds=[int(N, int32)], ierr=ierr, label='test: y')
if (ierr == 0_int32) call dev_alloc(fptr_dev=xs, ubounds=[100_int32], ierr=ierr, label='test: short x')
if (ierr == 0_int32) call dev_alloc(fptr_dev=ys, ubounds=[100_int32], ierr=ierr, label='test: short y')
if (ierr == 0_int32) call dev_alloc(fptr_dev=xf, ubounds=[int(N32, int32)], ierr=ierr, label='test: x r32')
if (ierr == 0_int32) call dev_alloc(fptr_dev=yf, ubounds=[int(N32, int32)], ierr=ierr, label='test: y r32')
if (ierr /= 0_int32) error stop 'figure_test_plot_frame_device: dev_alloc failed'
call fill(N, xd, yd)
call fill(100_int64, xs, ys) ! whole arrays: a section of a device array may be copied by the compiler, on the host
call fill32(N32, xf, yf)
call app%init_headless(W, H)

! 1: the full view
call shot(1_int32, S_FULL, 0.0_real64, 1.0_real64, .false.)
ki = ip_kept
call shot(1_int32, S_FULL, 0.0_real64, 1.0_real64, .true.)
test_passed(1) = ki < N / 10_int64 .and. same(1_int32)
if (ki >= N / 10_int64) write(output_unit, '(A,I0)') 'kept by ImPlot: ', ki
! 2: a zoom
call shot(2_int32, S_FULL, 0.40_real64, 0.42_real64, .false.)
call shot(2_int32, S_FULL, 0.40_real64, 0.42_real64, .true.)
test_passed(2) = same(2_int32)
! 3: a short series, copied whole
call shot(3_int32, S_SHORT, 0.0_real64, 1.0_real64, .false.)
call shot(3_int32, S_SHORT, 0.0_real64, 1.0_real64, .true.)
test_passed(3) = same(3_int32)
! 4: single precision
call shot(4_int32, S_R32, 0.0_real64, 1.0_real64, .false.)
call shot(4_int32, S_R32, 0.0_real64, 1.0_real64, .true.)
test_passed(4) = same(4_int32)
! 5: the device item's frame time
call system_clock(count_rate=rate)
do sd = 1_int32, 2_int32
   do f = 1_int32, 20_int32
      call system_clock(t0)
      call frame(S_FULL, 0.0_real64, 1.0_real64, sd == 2_int32)
      call system_clock(t1)
      ms(f, sd) = 1.0e3_real64 * real(t1 - t0, real64) / real(rate, real64)
   enddo
enddo
test_passed(5) = .true.
#if defined DEV_OAC
test_passed(5) = median(ms(:, 2)) < 50.0_real64
#endif
write(output_unit, '(A,I0,A,F0.2,A,F0.2,A)') 'line of a device series, ', N, ' points: ImPlot ', median(ms(:, 1)), &
   ' ms, the Fortran frame ', median(ms(:, 2)), ' ms a frame (median of 20)'
call app%destroy()
call dev_free(xd)
call dev_free(yd)
call dev_free(xs)
call dev_free(ys)
call dev_free(xf)
call dev_free(yf)
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_device checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine fill(m, x, y)
   !< A series, computed on the device: x from 0 to 1, y two waves.
   integer(int64), intent(in)            :: m    !< Points.
   real(real64),   intent(inout), target :: x(:) !< Abscissae, on the device.
   real(real64),   intent(inout), target :: y(:) !< Ordinates, on the device.
   integer(int64)                        :: i    !< Counter.
   real(real64)                          :: t    !< Abscissa.

   !$acc parallel loop gang vector private(t) DEVICEVAR(x, y)
   !$omp OMPLOOP private(t) DEVICEPTR(x, y)
   do i = 1_int64, m
      t = real(i - 1_int64, real64) / real(m - 1_int64, real64)
      x(i) = t
      y(i) = sin(40.0_real64 * t) + 0.2_real64 * sin(31415.9_real64 * t)
   enddo
   endsubroutine fill

   subroutine fill32(m, x, y)
   !< A single precision series, computed on the device: x from 0 to 1, y two waves.
   integer(int64), intent(in)            :: m    !< Points.
   real(real32),   intent(inout), target :: x(:) !< Abscissae, on the device.
   real(real32),   intent(inout), target :: y(:) !< Ordinates, on the device.
   integer(int64)                        :: i    !< Counter.
   real(real64)                          :: t    !< Abscissa.

   !$acc parallel loop gang vector private(t) DEVICEVAR(x, y)
   !$omp OMPLOOP private(t) DEVICEPTR(x, y)
   do i = 1_int64, m
      t = real(i - 1_int64, real64) / real(m - 1_int64, real64)
      x(i) = real(t, real32)
      y(i) = real(0.8_real64 * cos(25.0_real64 * t) + 0.15_real64 * sin(27182.8_real64 * t), real32)
   enddo
   endsubroutine fill32

   subroutine frame(series, x0, x1, fortran)
   !< One frame: a series over [x0, x1], by ImPlot or by the Fortran frame.
   integer(int32), intent(in) :: series  !< S_FULL, S_SHORT, S_R32.
   real(real64),   intent(in) :: x0, x1  !< View.
   logical,        intent(in) :: fortran !< The Fortran frame draws.

   if (.not. app%next_frame()) error stop 'figure_test_plot_frame_device: next_frame returned false headless'
   call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
   if (ig_begin('device', flags=ImGuiWindowFlags_NoDecoration)) then
      if (fortran) then
         if (pf_begin_plot('##device', width=620.0_real64, height=340.0_real64)) then
            call pf_setup_axes_limits(x0, x1, -1.5_real64, 1.5_real64, always=.true.)
            select case (series)
            case (S_FULL)
               call pf_line_device('y', xd, yd)
            case (S_SHORT)
               call pf_line_device('y', xs, ys)
            case default
               call pf_line_device('y', xf, yf)
            endselect
            call pf_end_plot()
         endif
      else
         if (ip_begin_plot('##device', width=620.0_real64, height=340.0_real64)) then
            call ip_setup_axes_limits(x0, x1, -1.5_real64, 1.5_real64, always=.true.)
            select case (series)
            case (S_FULL)
               call ip_line_device('y', xd, yd)
            case (S_SHORT)
               call ip_line_device('y', xs, ys)
            case default
               call ip_line_device('y', xf, yf)
            endselect
            call ip_end_plot()
         endif
      endif
   endif
   call ig_end()
   endsubroutine frame

   subroutine shot(k, series, x0, x1, fortran)
   !< A case's frame captured, by one side.
   integer(int32), intent(in) :: k       !< Case.
   integer(int32), intent(in) :: series  !< Series.
   real(real64),   intent(in) :: x0, x1  !< View.
   logical,        intent(in) :: fortran !< The Fortran frame draws.
   integer(int32)             :: s       !< Capture status.

   call frame(series, x0, x1, fortran)
   call test_capture(picture(k, fortran), s) ! this frame, written when it is rendered
   if (s /= 0_int32) write(output_unit, '(A,A)') 'capture: ', figure_last_error()
   if (.not. app%next_frame()) error stop 'figure_test_plot_frame_device: next_frame returned false headless'
   endsubroutine shot

   function same(k) result(ok)
   !< A case's pictures of both sides equal at the oracle's rule.
   integer(int32), intent(in) :: k   !< Case.
   logical                    :: ok  !< Equal.
   integer(int64)             :: nf_ !< Pixels that failed.
   integer(int32)             :: st  !< Status.

   ok = test_compare_image(picture(k, .true.), picture(k, .false.), threshold=2_int32, max_failed=0_int32, &
                           failed=nf_, stat=st)
   if (.not. ok) write(output_unit, '(A,I0,A,I0,A,A)') 'case ', k, ': ', nf_, ' pixels failed: ', figure_last_error()
   endfunction same

   function picture(k, fortran) result(name)
   !< A case's picture: ImPlot's or the Fortran frame's.
   integer(int32), intent(in)    :: k       !< Case.
   logical,        intent(in)    :: fortran !< The Fortran frame's.
   character(len=:), allocatable :: name    !< File name.
   character(len=8)              :: tag     !< The case's number.

   write(tag, '(I0)') k
   if (fortran) then
      name = 'figure_test_plot_frame_device.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_device.'//trim(tag)//'.implot.png.tmp'
   endif
   endfunction picture

   function median(v) result(m)
   !< Median of 20 values.
   real(real64), intent(in) :: v(20) !< Values.
   real(real64)             :: m     !< Median.
   real(real64)             :: w(20) !< Sorted.
   integer(int32)           :: i, j  !< Counters.
   real(real64)             :: t     !< Swap.

   w = v
   do i = 2_int32, 20_int32
      t = w(i)
      j = i - 1_int32
      do while (j >= 1_int32)
         if (w(j) <= t) exit
         w(j + 1_int32) = w(j)
         j = j - 1_int32
      enddo
      w(j + 1_int32) = t
   enddo
   m = 0.5_real64 * (w(10) + w(11))
   endfunction median

   subroutine remove_files()
   !< The pictures removed.
   integer(int32) :: k, j, u, ios !< Case, side, unit, status.
   logical        :: there        !< The file exists.

   do k = 1_int32, 4_int32
      do j = 1_int32, 2_int32
         inquire(file=picture(k, j == 2_int32), exist=there)
         if (.not. there) cycle
         open(newunit=u, file=picture(k, j == 2_int32), status='old', iostat=ios)
         if (ios == 0) close(u, status='delete')
      enddo
   enddo
   endsubroutine remove_files
endprogram figure_test_plot_frame_device
