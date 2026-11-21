!< figure_test_device, a series that lives on a device, decimated there (#15 P6): `ip_line_device`.

#include "fundal.H"

program figure_test_device
!< figure_test_device, a series that lives on a device, decimated there (#15 P6): `ip_line_device`.
!<
!< Headless. A series of N points is filled on the device (FUNDAL's `dev_alloc` and a kernel: OpenACC with nvfortran
!< `-acc`, the tests-nvf-acc mode, 10**8 points on the GPU; FUNDAL's CPU mode elsewhere, 10**6 points, the device being
!< the host), then plotted by `ip_line_device`, and the same series, copied to the host, by `ip_line`:
!< 1. both decimated, the same number of points kept;
!< 2. the same picture (|d| <= 2, no pixel more), a full view and a zoom (x range 1/50 of the series);
!< 3. a short series (100 points over x 0 to 1: not decimated) copied whole, the same picture as `ip_line`'s;
!< 4. sizes that differ refused (`FIG_ERR_ARGUMENT`), an item outside a plot refused (`FIG_ERR_STATE`);
!< 5. the frame time of the device item (median of 20 frames, the decimation and the copy of the points kept), printed:
!<    on the GPU at 10**8 points it must stay under 50 ms (interactive), where `ip_line` of every point takes more than
!<    a second (the baseline).
!< The pictures are `figure_test_device.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use fundal, only : dev_alloc, dev_free, dev_init, dev_memcpy_from_device
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ip_begin_plot, ip_end_plot, &
                   ip_line, ip_line_device, ip_setup_axes_limits, ImGuiWindowFlags_NoDecoration, FIG_ERR_ARGUMENT, &
                   FIG_ERR_STATE, FIG_OK
use figure_implot, only : plot_kept
use figure_testing, only : test_capture, test_compare_image

implicit none
#if defined DEV_OAC
integer(int64), parameter   :: N = 100000000_int64 !< Points: on the GPU.
#else
integer(int64), parameter   :: N = 1000000_int64   !< Points: the device is the host.
#endif
type(app_object)            :: app                !< Application.
real(real64), pointer       :: xd(:) => null()    !< Abscissae, on the device.
real(real64), pointer       :: yd(:) => null()    !< Ordinates, on the device.
real(real64), pointer       :: xs(:) => null()    !< A short series' abscissae, on the device.
real(real64), pointer       :: ys(:) => null()    !< ... its ordinates.
real(real64), pointer       :: y11(:) => null()   !< Ordinates of another size, on the device.
real(real64), allocatable   :: xh(:), yh(:)       !< Their copies on the host.
real(real64)                :: xsh(100), ysh(100) !< The short series' copy.
logical                     :: test_passed(7)     !< Per-check outcome.
integer(int64)              :: kd, kh             !< Points kept: device, host.
integer(int64)              :: nf                 !< Pixels that failed.
integer(int64)              :: t0, t1, rate       !< Clock.
real(real64)                :: ms(20)             !< Frame times of the device item [ms].
integer(int32)              :: ierr, s1, s2, f    !< Statuses, frame.
character(len=16)           :: keep               !< FIGURE_TEST_KEEP.

test_passed = .false.
call dev_init()
call dev_alloc(fptr_dev=xd, ubounds=[int(N, int32)], ierr=ierr, label='test: x')
if (ierr == 0_int32) call dev_alloc(fptr_dev=yd, ubounds=[int(N, int32)], ierr=ierr, label='test: y')
if (ierr == 0_int32) call dev_alloc(fptr_dev=xs, ubounds=[100_int32], ierr=ierr, label='test: short x')
if (ierr == 0_int32) call dev_alloc(fptr_dev=ys, ubounds=[100_int32], ierr=ierr, label='test: short y')
if (ierr == 0_int32) call dev_alloc(fptr_dev=y11, ubounds=[11_int32], ierr=ierr, label='test: 11')
if (ierr /= 0_int32) error stop 'figure_test_device: dev_alloc failed'
call fill(N, xd, yd)
call fill(100_int64, xs, ys) ! whole arrays: a section of a device array may be copied by the compiler, on the host
allocate(xh(N), yh(N))
call dev_memcpy_from_device(dst=xh, src=xd, ierr=ierr)
if (ierr == 0_int32) call dev_memcpy_from_device(dst=yh, src=yd, ierr=ierr)
if (ierr == 0_int32) call dev_memcpy_from_device(dst=xsh, src=xs, ierr=ierr)
if (ierr == 0_int32) call dev_memcpy_from_device(dst=ysh, src=ys, ierr=ierr)
if (ierr /= 0_int32) error stop 'figure_test_device: dev_memcpy_from_device failed'
call app%init_headless(640_int32, 360_int32)

! 1, 2: full view and a zoom, device against host
call shot('figure_test_device.full.png.tmp', 0.0_real64, 1.0_real64, .true., N, s1)
kd = plot_kept
call shot('figure_test_device.host.png.tmp', 0.0_real64, 1.0_real64, .false., N, s2)
kh = plot_kept
test_passed(1) = kd == kh .and. kd < N / 10_int64
if (.not. test_passed(1)) write(output_unit, '(A,2(1X,I0))') 'kept, device and host: ', kd, kh
test_passed(2) = s1 == FIG_OK .and. s2 == FIG_OK
if (test_passed(2)) test_passed(2) = test_compare_image('figure_test_device.full.png.tmp', &
                                                        'figure_test_device.host.png.tmp', failed=nf)
if (.not. test_passed(2)) write(output_unit, '(A,A)') 'full view: ', figure_last_error()
call shot('figure_test_device.zoom.png.tmp', 0.40_real64, 0.42_real64, .true., N, s1)
call shot('figure_test_device.zoomhost.png.tmp', 0.40_real64, 0.42_real64, .false., N, s2)
test_passed(3) = s1 == FIG_OK .and. s2 == FIG_OK
if (test_passed(3)) test_passed(3) = test_compare_image('figure_test_device.zoom.png.tmp', &
                                                        'figure_test_device.zoomhost.png.tmp', failed=nf)
if (.not. test_passed(3)) write(output_unit, '(A,A)') 'zoom: ', figure_last_error()
! 3: a short series, copied whole
call shot('figure_test_device.short.png.tmp', 0.0_real64, 1.0_real64, .true., 100_int64, s1)
call shot('figure_test_device.shorthost.png.tmp', 0.0_real64, 1.0_real64, .false., 100_int64, s2)
test_passed(4) = s1 == FIG_OK .and. s2 == FIG_OK
if (test_passed(4)) test_passed(4) = test_compare_image('figure_test_device.short.png.tmp', &
                                                        'figure_test_device.shorthost.png.tmp', failed=nf)
if (.not. test_passed(4)) write(output_unit, '(A,A)') 'short: ', figure_last_error()
! 4: refusals
if (.not. app%next_frame()) error stop 'figure_test_device: next_frame returned false in headless mode'
call ip_line_device('outside', xd, yd, stat=s1)
test_passed(5) = s1 == FIG_ERR_STATE
if (ig_begin('device', flags=ImGuiWindowFlags_NoDecoration)) then
   if (ip_begin_plot('##sizes')) then
      call ip_line_device('sizes', xs, y11, stat=s1)
      test_passed(5) = test_passed(5) .and. s1 == FIG_ERR_ARGUMENT
      call ip_end_plot()
   endif
endif
call ig_end()
! 5: the device item's frame time
call system_clock(count_rate=rate)
do f = 1_int32, 20_int32
   call system_clock(t0)
   call frame(0.0_real64, 1.0_real64, .true., N)
   call system_clock(t1)
   ms(f) = 1.0e3_real64 * real(t1 - t0, real64) / real(rate, real64)
enddo
test_passed(6) = .true.
#if defined DEV_OAC
test_passed(6) = median(ms) < 50.0_real64
#endif
write(output_unit, '(A,I0,A,F0.2,A)') 'ip_line_device, ', N, ' points: ', median(ms), ' ms a frame (median of 20)'
test_passed(7) = .true.
call app%destroy()
call dev_free(xd)
call dev_free(yd)
call dev_free(xs)
call dev_free(ys)
call dev_free(y11)
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_device checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine fill(m, x, y)
   !< The series, computed on the device: x from 0 to 1, y two waves.
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

   subroutine frame(x0, x1, device, m)
   !< One frame: the first m points over [x0, x1], from the device or the host.
   real(real64),   intent(in) :: x0, x1 !< View.
   logical,        intent(in) :: device !< From the device.
   integer(int64), intent(in) :: m      !< Points.

   if (.not. app%next_frame()) error stop 'figure_test_device: next_frame returned false in headless mode'
   call ig_set_next_window(0.0_real64, 0.0_real64, 640.0_real64, 360.0_real64, always=.true.)
   if (ig_begin('device', flags=ImGuiWindowFlags_NoDecoration)) then
      if (ip_begin_plot('##device', width=620.0_real64, height=340.0_real64)) then
         call ip_setup_axes_limits(x0, x1, -1.5_real64, 1.5_real64, always=.true.)
         if (device .and. m == N) then
            call ip_line_device('y', xd, yd)
         elseif (device) then
            call ip_line_device('y', xs, ys)
         elseif (m == N) then
            call ip_line('y', xh, yh)
         else
            call ip_line('y', xsh, ysh)
         endif
         call ip_end_plot()
      endif
   endif
   call ig_end()
   endsubroutine frame

   subroutine shot(path, x0, x1, device, m, s)
   !< A frame captured.
   character(len=*), intent(in)  :: path   !< Picture.
   real(real64),     intent(in)  :: x0, x1 !< View.
   logical,          intent(in)  :: device !< From the device.
   integer(int64),   intent(in)  :: m      !< Points.
   integer(int32),   intent(out) :: s      !< Capture status.

   call frame(x0, x1, device, m)
   call test_capture(path, s) ! this frame, written when it is rendered
   if (.not. app%next_frame()) error stop 'figure_test_device: next_frame returned false in headless mode'
   endsubroutine shot

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
   !< The captures.
   integer(int32) :: unit, ios !< Unit, status.
   integer(int32) :: k         !< Counter.
   character(len=*), parameter :: FILES(6) = [character(len=40) :: 'figure_test_device.full.png.tmp', &
      'figure_test_device.host.png.tmp', 'figure_test_device.zoom.png.tmp', 'figure_test_device.zoomhost.png.tmp', &
      'figure_test_device.short.png.tmp', 'figure_test_device.shorthost.png.tmp']

   do k = 1_int32, size(FILES, kind=int32)
      open(newunit=unit, file=trim(FILES(k)), status='old', iostat=ios)
      if (ios == 0) close(unit, status='delete')
   enddo
   endsubroutine remove_files
endprogram figure_test_device
