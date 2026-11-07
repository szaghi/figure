!< cb_palette, cookbook: a look and a palette, the system's light or dark setting, a status in the palette's colours.
program cb_palette
!< cb_palette, cookbook: a look and a palette, the system's light or dark setting, a status in the palette's colours.
!<
!< Run with "auto" to follow the system's light or dark setting instead of a fixed palette.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_button, ig_checkbox, ig_end, ig_same_line, ig_separator, &
                   ig_set_next_window, ig_slider, ig_text, ig_text_colored, ip_begin_plot, ip_end_plot, ip_line

implicit none
integer(int32), parameter :: N = 200_int32 !< Points.
type(app_object)          :: app           !< Application.
real(real64)              :: x(N)          !< Abscissae.
real(real64)              :: level         !< A value.
real(real64)              :: ok(4)         !< The palette's success colour.
real(real64)              :: warn(4)       !< Its warning colour.
real(real64)              :: bad(4)        !< Its error colour.
logical                   :: on            !< A flag.
integer(int32)            :: i             !< Counter.
character(len=8)          :: arg           !< Command argument.

x = [(real(i - 1, real64) / real(N - 1, real64), i = 1_int32, N)]
level = 0.6_real64
on = .true.
call get_command_argument(1, arg)

call app%init('FIGURE: palette', 720_int32, 440_int32)
if (trim(arg) == 'auto') then
   call app%set_style(palette='auto', auto_dark='nord', auto_light='solarized-light') ! follows the system
else
   call app%set_style(look='fluent', palette='nord')    ! the geometry of Windows 11, the colours of Nord
endif
do while (app%next_frame())
   call app%palette_color('success', ok)               ! the roles of the palette in effect
   call app%palette_color('warning', warn)
   call app%palette_color('error', bad)
   call ig_set_next_window(20.0_real64, 20.0_real64, 680.0_real64, 400.0_real64)
   if (ig_begin('Run')) then
      if (ig_button('Start')) continue
      call ig_same_line()
      if (ig_button('Stop')) continue
      if (ig_checkbox('viscous', on)) continue
      if (ig_slider('CFL', level, 0.0_real64, 1.0_real64)) continue
      call ig_separator()
      call ig_text_colored('[ok] mesh read', ok)          ! a mark with the colour: never colour alone
      call ig_text_colored('(!) 3 cells skewed', warn)
      call ig_text_colored('[!!] residual diverged at step 412', bad)
      call ig_text('step 412 of 1000')
      if (ip_begin_plot('Residual', height=-1.0_real64)) then
         call ip_line('rho', x, exp(-3.0_real64 * x) + 0.05_real64 * sin(40.0_real64 * x))
         call ip_line('energy', x, 0.8_real64 * exp(-2.0_real64 * x))
         call ip_line('momentum', x, 0.6_real64 * exp(-4.0_real64 * x) + 0.1_real64 * x)
         call ip_end_plot()
      endif
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_palette
