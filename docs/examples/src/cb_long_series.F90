!< cb_long_series, cookbook: a million points plotted every frame, decimated per pixel column, or every point drawn.
program cb_long_series
!< cb_long_series, cookbook: a million points plotted every frame, decimated per pixel column, or every point drawn.
!<
!< A probe's pressure sampled a million times: in a plot 600 pixels wide, about 1700 points a pixel column. `ip_line`
!< decimates it (plots.md, "Long series"): at most 64 points a column reach ImPlot, nearly the full picture. The check
!< box draws every point instead (`ip_set_decimation(.false.)`). The samples never change: `ip_cache_next_item` keeps
!< what the decimation computes of them from frame to frame, and a pan or a zoom costs a few operations a column.
!< `cb_long_series --check` opens no window: it draws the plot headless both ways and compares the two pictures.
use, intrinsic :: iso_fortran_env, only : int32, int64, output_unit, real64
use figure, only : app_object, ig_begin, ig_checkbox, ig_end, ig_item_rect, ig_set_next_window, ip_begin_plot, &
                   ip_cache_next_item, ip_end_plot, ip_line, ip_set_decimation, ip_setup_axes
use figure_testing, only : test_capture, test_compare_image

implicit none
integer(int64), parameter :: N = 1000000_int64     !< Samples.
real(real64),   parameter :: PI = acos(-1.0_real64) !< pi.
type(app_object)          :: app                    !< Application.
real(real64), allocatable :: t(:), p(:)             !< Time [s], pressure [Pa].
logical                   :: every                  !< Every point drawn.
logical                   :: check                  !< --check: headless, the two pictures compared.
character(len=16)         :: arg                    !< First argument.
integer(int64)            :: failed                 !< Pixels that differ.
real(real64)              :: box(4, 1)              !< The check box (drawn differently): left out of the comparison.
integer(int32)            :: frame                  !< Frame counter.
integer(int64)            :: i                      !< Counter.
!run cb_long_series ./cb_long_series --check

allocate(t(N), p(N))
do i = 1_int64, N
   t(i) = real(i - 1_int64, real64) * 1.0e-5_real64
enddo
p = 101325.0_real64 + 40.0_real64 * sin(6.0_real64 * PI * t) + 9.0_real64 * sin(1800.0_real64 * PI * t)
call get_command_argument(1, arg)
check = trim(arg) == '--check'
every = .false.
if (check) then
   call app%init_headless(640_int32, 380_int32)
else
   call app%init('FIGURE: a long series', 640_int32, 380_int32)
endif
frame = 0_int32
do while (app%next_frame())
   frame = frame + 1_int32
   if (check) then
      every = frame > 3_int32                            ! frames 1-3 decimated, 4-6 every point
      if (frame == 3_int32) call test_capture('decimated.png')
      if (frame == 6_int32) call test_capture('every.png')
   endif
   call ig_set_next_window(0.0_real64, 0.0_real64, 640.0_real64, 380.0_real64, always=.true.)
   if (ig_begin('Probe')) then
      if (ig_checkbox('every point', every)) continue
      call ig_item_rect(box(1, 1), box(2, 1), box(3, 1), box(4, 1))
      !region plot
      if (ip_begin_plot('Pressure at the probe', height=-1.0_real64)) then
         call ip_setup_axes('t [s]', 'p [Pa]')
         if (every) call ip_set_decimation(.false.) ! every point: the exact picture, at ImPlot's cost per point
         call ip_cache_next_item(changed=.false.)   ! p never changes: its decimation's work kept between frames
         call ip_line('p', t, p)                    ! decimated by default: at most 64 points a pixel column
         if (every) call ip_set_decimation(.true.)
         call ip_end_plot()
      endif
      !endregion plot
   endif
   call ig_end()
   if (check .and. frame == 7_int32) exit
enddo
call app%destroy()
if (check) then
   write(output_unit, '(A,I0,A)') 'a line of ', N, ' points, 600 pixels wide'
   if (test_compare_image('decimated.png', 'every.png', masks=box, failed=failed)) continue
   write(output_unit, '(A,I0)') 'pixels of the plot that differ by more than 2 of 255: ', failed
   if (test_compare_image('decimated.png', 'every.png', threshold=96_int32, masks=box, failed=failed)) continue
   write(output_unit, '(A,I0)') 'pixels of the plot that differ by more than 96 of 255: ', failed
endif
endprogram cb_long_series
