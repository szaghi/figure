!< cb_device_series, cookbook: a solution that lives on the GPU, plotted where it is.
program cb_device_series
!< cb_device_series, cookbook: a solution that lives on the GPU, plotted where it is.
!<
!< A solver keeps its solution on the device, in FUNDAL's memory (`dev_alloc`): two million samples of u(x). The plot
!< reads them there, `ip_line_device`: the decimation runs on the device, and only the points kept, at most 64 a pixel
!< column, are copied to the host each frame. Built without a device backend (as the documentation's build), FUNDAL's
!< CPU mode makes the host the device: the same program. `cb_device_series --check` opens no window: it draws the plot
!< headless, then the same samples copied to the host with `ip_line`, and compares the two pictures.
use, intrinsic :: iso_fortran_env, only : int32, int64, output_unit, real64
use fundal, only : dev_alloc, dev_free, dev_init, dev_memcpy_to_device
use figure, only : app_object, ig_begin, ig_end, ig_set_next_window, ip_begin_plot, ip_end_plot, ip_line, ip_line_device, &
                   ip_setup_axes
use figure_testing, only : test_capture, test_compare_image

implicit none
integer(int32), parameter :: N = 2000000_int32     !< Samples.
type(app_object)          :: app                   !< Application.
real(real64), pointer     :: x_d(:) => null()      !< Abscissae, on the device.
real(real64), pointer     :: u_d(:) => null()      !< Solution, on the device.
real(real64), allocatable :: x(:), u(:)            !< The same, on the host (computed here, copied once).
logical                   :: check                 !< --check: headless, the two pictures compared.
logical                   :: on_host               !< The frames plot the host's copy.
character(len=16)         :: arg                   !< First argument.
integer(int32)            :: frame, ierr, i        !< Frame counter, FUNDAL's status, counter.
!run cb_device_series ./cb_device_series --check

call dev_init()
call dev_alloc(fptr_dev=x_d, ubounds=[N], ierr=ierr, label='x')
if (ierr == 0_int32) call dev_alloc(fptr_dev=u_d, ubounds=[N], ierr=ierr, label='u')
if (ierr /= 0_int32) error stop 'cb_device_series: no device memory'
allocate(x(N), u(N))
do i = 1_int32, N
   x(i) = real(i - 1_int32, real64) / real(N - 1_int32, real64)
enddo
u = exp(-3.0_real64 * x) * sin(80.0_real64 * x) + 0.05_real64 * sin(20000.0_real64 * x)
call dev_memcpy_to_device(dst=x_d, src=x, ierr=ierr) ! a solver computes them on the device instead
call dev_memcpy_to_device(dst=u_d, src=u, ierr=ierr)
call get_command_argument(1, arg)
check = trim(arg) == '--check'
if (check) then
   call app%init_headless(640_int32, 380_int32)
else
   call app%init('FIGURE: a series on the device', 640_int32, 380_int32)
endif
frame = 0_int32
do while (app%next_frame())
   frame = frame + 1_int32
   on_host = check .and. frame > 3_int32
   if (check .and. frame == 3_int32) call test_capture('device.png')
   if (check .and. frame == 6_int32) call test_capture('host.png')
   call ig_set_next_window(0.0_real64, 0.0_real64, 640.0_real64, 380.0_real64, always=.true.)
   if (ig_begin('Solution')) then
      if (ip_begin_plot('u(x)', height=-1.0_real64)) then
         call ip_setup_axes('x', 'u')
         if (on_host) then
            call ip_line('u', x, u)
         else
            !region device
            call ip_line_device('u', x_d, u_d) ! decimated on the device: 64 points a column at most come back
            !endregion device
         endif
         call ip_end_plot()
      endif
   endif
   call ig_end()
   if (check .and. frame == 7_int32) exit
enddo
call app%destroy()
call dev_free(x_d)
call dev_free(u_d)
if (check) write(output_unit, '(A,L1)') 'the same picture as ip_line of the host copy: ', &
                                        test_compare_image('device.png', 'host.png')
endprogram cb_device_series
