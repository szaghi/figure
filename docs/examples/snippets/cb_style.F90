!< cb_style, cookbook: change a few colours and variables of the whole interface (run with "plain" to skip them).
program cb_style
!< cb_style, cookbook: change a few colours and variables of the whole interface (run with "plain" to skip them).
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_button, ig_checkbox, ig_end, ig_set_next_window, ig_set_style_color, &
                   ig_set_style_var, ig_slider, ip_begin_plot, ip_end_plot, ip_line, ip_set_style_color

implicit none
integer(int32), parameter :: N = 200_int32 !< Points.
type(app_object)          :: app           !< Application.
real(real64)              :: x(N)          !< Abscissae.
real(real64)              :: level         !< A value.
logical                   :: on            !< A flag.
integer(int32)            :: i             !< Counter.
character(len=8)          :: arg           !< Command argument.

x = [(real(i - 1, real64) / real(N - 1, real64), i = 1_int32, N)]
level = 0.6_real64
on = .true.
call get_command_argument(1, arg)

call app%init('FIGURE: style', 720_int32, 420_int32)
if (trim(arg) /= 'plain') then
   call ig_set_style_color('Button', '#2f5d50')            ! colours: hex or [r, g, b(, a)] in [0, 1]
   call ig_set_style_color('ButtonHovered', '#3d7a69')
   call ig_set_style_color('SliderGrab', '#e0b04c')
   call ig_set_style_color('CheckMark', '#e0b04c')
   call ig_set_style_var('FrameRounding', 6.0_real64)      ! a number
   call ig_set_style_var('ItemSpacing', [10.0_real64, 8.0_real64]) ! a pair
   call ip_set_style_color('PlotBg', '#101820')            ! ImPlot's colours, the same way
endif
do while (app%next_frame())
   call ig_set_next_window(20.0_real64, 20.0_real64, 680.0_real64, 380.0_real64)
   if (ig_begin('Style')) then
      if (ig_button('Run')) continue
      if (ig_checkbox('enabled', on)) continue
      if (ig_slider('level', level, 0.0_real64, 1.0_real64)) continue
      if (ip_begin_plot('Response', height=-1.0_real64)) then
         call ip_line('level', x, level * sin(6.0_real64 * x))
         call ip_end_plot()
      endif
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_style
