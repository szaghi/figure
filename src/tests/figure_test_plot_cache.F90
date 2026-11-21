!< figure_test_plot_cache, the caches of decimated series (#15 P5): a pan reuses the cache, a change rebuilds it.
program figure_test_plot_cache
!< figure_test_plot_cache, the caches of decimated series (#15 P5): a pan reuses the cache, a change rebuilds it.
!<
!< Headless. A line of 2000001 points (x from 0 to 1) in a plot 600 pixels wide, decimated:
!< 1. drawn after `ip_cache_next_item(changed=...)` (true the first frame, false after) over six frames of a pan (x
!<    range 0.3 wide, moved by 0.05 a frame): the cache built once, reused five times;
!< 2. the last frame against the same view drawn without the cache: the same points kept, the same picture (|d| <= 2,
!<    no pixel more);
!< 3. the values changed in place (y = -y) with `changed=.true.`: the cache rebuilt; the picture equal to the same view
!<    drawn without the cache;
!< 4. a new array (another address) with `changed=.false.`: rebuilt all the same;
!< 5. the cache released after ten idle seconds (Dear ImGui's time advances by the frames' time in headless mode).
!< The pictures are `figure_test_plot_cache.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ip_begin_plot, ip_cache_next_item, &
                   ip_end_plot, ip_line, ip_setup_axes_limits, ImGuiWindowFlags_NoDecoration, FIG_OK
use figure_implot, only : plot_cache_builds, plot_cache_hits, plot_decimated, plot_kept
use figure_testing, only : test_capture, test_compare_image

implicit none
integer(int64), parameter   :: N = 2000001_int64 !< Points.
type(app_object)            :: app               !< Application.
real(real64), allocatable   :: x(:), y(:), z(:)  !< The line; another array of ordinates.
logical                     :: test_passed(6)    !< Per-check outcome.
integer(int64)              :: b0, h0, kept_c, kept_u !< Builds and hits before; points kept cached, uncached.
integer(int64)              :: nf                !< Pixels that failed.
integer(int32)              :: f, s1, s2         !< Frame; statuses.
character(len=16)           :: keep              !< FIGURE_TEST_KEEP.
integer(int64)              :: i                 !< Counter.

allocate(x(N), y(N), z(N))
do i = 1_int64, N
   x(i) = real(i - 1_int64, real64) / real(N - 1_int64, real64)
enddo
y = sin(60.0_real64 * x) + 0.3_real64 * sin(9000.0_real64 * x)
z = y
call app%init_headless(640_int32, 360_int32)

! 1: a pan over cached data
b0 = plot_cache_builds
h0 = plot_cache_hits
do f = 1_int32, 6_int32
   call frame(0.05_real64 * f, 'cached', f == 1_int32, y)
enddo
kept_c = plot_kept
test_passed(1) = plot_cache_builds - b0 == 1_int64 .and. plot_cache_hits - h0 == 5_int64
call shot('figure_test_plot_cache.cached.png.tmp', 0.30_real64, 'cached', .false., y, s1)
! 2: the same view without the cache
call frame(0.30_real64, '', .false., y)
kept_u = plot_kept
call shot('figure_test_plot_cache.plain.png.tmp', 0.30_real64, '', .false., y, s2)
test_passed(2) = kept_c == kept_u .and. s1 == FIG_OK .and. s2 == FIG_OK
if (test_passed(2)) test_passed(2) = test_compare_image('figure_test_plot_cache.cached.png.tmp', &
                                                        'figure_test_plot_cache.plain.png.tmp', failed=nf)
if (.not. test_passed(2)) write(output_unit, '(A,2(1X,I0),A,A)') 'pan: kept ', kept_c, kept_u, ': ', figure_last_error()
! 3: values changed in place
y = -y
b0 = plot_cache_builds
call shot('figure_test_plot_cache.changed.png.tmp', 0.30_real64, 'cached', .true., y, s1)
kept_c = plot_kept
test_passed(3) = plot_cache_builds - b0 == 1_int64
call shot('figure_test_plot_cache.plain2.png.tmp', 0.30_real64, '', .false., y, s2)
kept_u = plot_kept
test_passed(4) = kept_c == kept_u .and. s1 == FIG_OK .and. s2 == FIG_OK
if (test_passed(4)) test_passed(4) = test_compare_image('figure_test_plot_cache.changed.png.tmp', &
                                                        'figure_test_plot_cache.plain2.png.tmp', failed=nf)
if (.not. test_passed(4)) write(output_unit, '(A,2(1X,I0),A,A)') 'change: kept ', kept_c, kept_u, ': ', figure_last_error()
! 4: another array, changed=.false.: rebuilt
b0 = plot_cache_builds
call frame(0.30_real64, 'cached', .false., z)
test_passed(5) = plot_cache_builds - b0 == 1_int64
! 5: idle for more than ten seconds (the frames advance Dear ImGui's time), then drawn again: a new cache
do f = 1_int32, 700_int32 ! 60 frames a second in headless mode
   if (.not. app%next_frame()) error stop 'figure_test_plot_cache: next_frame returned false in headless mode'
enddo
b0 = plot_cache_builds
h0 = plot_cache_hits
call frame(0.30_real64, 'cached', .false., z)
test_passed(6) = plot_cache_builds - b0 == 1_int64 .and. plot_cache_hits == h0 .and. plot_decimated > 0_int64
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_cache checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine frame(x0, mode, changed, yy)
   !< One frame: the plot over [x0, x0 + 0.3], the line cached (`mode` 'cached') or not.
   real(real64),     intent(in) :: x0      !< Left of the view.
   character(len=*), intent(in) :: mode    !< 'cached' or ''.
   logical,          intent(in) :: changed !< The values changed (cached only).
   real(real64),     intent(in) :: yy(:)   !< Ordinates.

   if (.not. app%next_frame()) error stop 'figure_test_plot_cache: next_frame returned false in headless mode'
   call ig_set_next_window(0.0_real64, 0.0_real64, 640.0_real64, 360.0_real64, always=.true.)
   if (ig_begin('cache', flags=ImGuiWindowFlags_NoDecoration)) then
      if (ip_begin_plot('##cache', width=620.0_real64, height=340.0_real64)) then
         call ip_setup_axes_limits(x0, x0 + 0.3_real64, -1.5_real64, 1.5_real64, always=.true.)
         if (mode == 'cached') call ip_cache_next_item(changed)
         call ip_line('line', x, yy)
         call ip_end_plot()
      endif
   endif
   call ig_end()
   endsubroutine frame

   subroutine shot(path, x0, mode, changed, yy, s)
   !< A frame captured.
   character(len=*), intent(in)  :: path    !< Picture.
   real(real64),     intent(in)  :: x0      !< Left of the view.
   character(len=*), intent(in)  :: mode    !< 'cached' or ''.
   logical,          intent(in)  :: changed !< The values changed.
   real(real64),     intent(in)  :: yy(:)   !< Ordinates.
   integer(int32),   intent(out) :: s       !< Capture status.

   call frame(x0, mode, changed, yy)
   call test_capture(path, s) ! this frame, written when it is rendered
   if (.not. app%next_frame()) error stop 'figure_test_plot_cache: next_frame returned false in headless mode'
   endsubroutine shot

   subroutine remove_files()
   !< The captures.
   integer(int32) :: unit, ios !< Unit, status.
   integer(int32) :: k         !< Counter.
   character(len=*), parameter :: FILES(4) = [character(len=40) :: 'figure_test_plot_cache.cached.png.tmp', &
      'figure_test_plot_cache.plain.png.tmp', 'figure_test_plot_cache.changed.png.tmp', 'figure_test_plot_cache.plain2.png.tmp']

   do k = 1_int32, size(FILES, kind=int32)
      open(newunit=unit, file=trim(FILES(k)), status='old', iostat=ios)
      if (ios == 0) close(unit, status='delete')
   enddo
   endsubroutine remove_files
endprogram figure_test_plot_cache
