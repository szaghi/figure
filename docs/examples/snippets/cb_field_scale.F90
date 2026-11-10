!< cb_field_scale, cookbook: show a 2-D field with its colour scale, a density over three decades on a log scale, its
!< range dragged by the user on the legend.
program cb_field_scale
!< cb_field_scale, cookbook: show a 2-D field with its colour scale, a density over three decades on a log scale, its
!< range dragged by the user on the legend.
!<
!< A 400 x 300 density field, from 0.1 to 100, is drawn through a colormap on a log scale by `ip_field_image`: one
!< texture, coloured when the range changes, not every frame. Beside it the legend on the same scale: the user drags
!< it to move the range, turns the wheel over it to zoom the range; a button sets the range back. A time step changes
!< the field in place, so the program says so (`changed=.true.`). `cb_field_scale --check` opens no window: it drags
!< the legend 60 pixels up with FIGURE's scripted input and prints the range and the colourings before and after.
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, ig_begin, ig_button, ig_end, ig_item_rect, ig_same_line, ig_set_next_window, &
                   ip_begin_plot, ip_colormap, ip_colormap_legend_edit, ip_end_plot, ip_field_image, ip_setup_axes
use figure_testing, only : test_drag, test_field_uploads
implicit none
integer(int32), parameter :: NX = 400_int32  !< Values along x.
integer(int32), parameter :: NY = 300_int32  !< Values along y.
type(app_object)          :: app             !< Application.
real(real64)              :: rho(NX, NY)     !< Density.
real(real64)              :: vmin, vmax      !< The range shown.
real(real64)              :: x0, y0, x1, y1  !< The legend's rectangle [pixels].
logical                   :: step            !< The field changed on this frame.
character(len=16)         :: arg             !< First argument.
logical                   :: check           !< --check: headless, scripted drag.
integer(int64)            :: uploads         !< Colourings at the start of --check.
integer(int32)            :: frame           !< Frame counter.
call density(0.0_real64)
vmin = 0.1_real64
vmax = 100.0_real64
call get_command_argument(1, arg)
check = trim(arg) == '--check'
if (check) then
   call app%init_headless(900_int32, 560_int32)
else
   call app%init('FIGURE: a field and its colour scale', 900_int32, 560_int32)
endif
frame = 0_int32
do while (app%next_frame())
   frame = frame + 1_int32
   step = .false.
   if (.not. check .and. mod(frame, 600_int32) == 0_int32) then ! a new time step every 600 frames
      call density(real(frame / 600_int32, real64))
      step = .true.
   endif
   call ig_set_next_window(10.0_real64, 10.0_real64, 880.0_real64, 540.0_real64)
   if (ig_begin('Density')) then
      if (ip_begin_plot('density', 700.0_real64, 440.0_real64, equal=.true.)) then
         call ip_setup_axes('x [m]', 'y [m]')
         call ip_field_image('rho', rho, 0.0_real64, 4.0_real64, 0.0_real64, 3.0_real64, colormap=ip_colormap('inferno'), &
                             vmin=vmin, vmax=vmax, scale='log', changed=step)
         call ip_end_plot()
      endif
      call ig_same_line()
      if (ip_colormap_legend_edit('rho legend', ip_colormap('inferno'), vmin, vmax, height=440.0_real64, &
                                  scale='log', label_format='%g kg/m3')) then
         ! vmin and vmax changed: the next ip_field_image colours the field again
      endif
      call ig_item_rect(x0, y0, x1, y1)
      if (ig_button('reset range')) then
         vmin = 0.1_real64
         vmax = 100.0_real64
      endif
   endif
   call ig_end()
   if (check) then
      select case (frame)
      case (3_int32)
         uploads = test_field_uploads()
         call report('before')
         call test_drag(x0 + 6.0_real64, 0.5_real64 * (y0 + y1), x0 + 6.0_real64, 0.5_real64 * (y0 + y1) - 60.0_real64)
      case (12_int32)
         call report('after')
         exit
      endselect
   endif
enddo
call app%destroy()

contains
   subroutine density(t)
   !< The density at time t: a blob over three decades, drifting to the right.
   real(real64), intent(in) :: t    !< Time step.
   real(real64)             :: x, y !< A point [m].
   integer(int32)           :: i, j !< Counters.

   do j = 1_int32, NY
      do i = 1_int32, NX
         x = 4.0_real64 * (real(i, real64) - 0.5_real64) / real(NX, real64)
         y = 3.0_real64 * (real(j, real64) - 0.5_real64) / real(NY, real64)
         rho(i, j) = 0.1_real64 * 10.0_real64**(3.0_real64 * exp(-((x - 1.5_real64 - 0.2_real64 * t)**2 + &
                                                                    (y - 1.5_real64)**2) / 0.5_real64))
      enddo
   enddo
   endsubroutine density

   subroutine report(when)
   !< The range and the colourings so far, for --check.
   character(len=*), intent(in) :: when !< 'before' or 'after' the drag.

   write(output_unit, '(A,A,ES10.3,A,ES10.3,A,I0)') when, ' the drag: range ', vmin, ' to ', vmax, &
                                                   ', colourings since the start of the check ', &
                                                   test_field_uploads() - uploads
   endsubroutine report
endprogram cb_field_scale
