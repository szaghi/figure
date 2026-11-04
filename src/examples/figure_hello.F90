!< figure_hello, the first FIGURE program: widgets bound to Fortran variables and a live ImPlot plot.
program figure_hello
!< figure_hello, the first FIGURE program: widgets bound to Fortran variables and a live ImPlot plot.
!<
!< `figure_hello` opens a window; `figure_hello --remote [port]` serves the same UI to a web browser instead.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_button, ig_checkbox, ig_end, ig_input, ig_same_line, ig_separator,    &
                   ig_set_next_window, ig_show_demo_window, ig_slider, ig_text, ip_begin_plot, ip_end_plot, ip_line, &
                   ip_setup_axes

implicit none
integer(int32), parameter :: N = 1000_int32 !< Plot points.
type(app_object)          :: app            !< Application.
real(real64)              :: x(N)           !< Abscissae.
real(real64)              :: y(N)           !< Ordinates.
real(real64)              :: frequency      !< Wave frequency.
real(real64)              :: amplitude      !< Wave amplitude.
real(real64)              :: phase          !< Wave phase (animated).
integer(int32)            :: clicks         !< Button clicks.
logical                   :: animate        !< Animate the phase.
logical                   :: demo           !< Show the Dear ImGui demo.
character(len=64)         :: line           !< Text buffer.
character(len=16)         :: arg            !< Command-line argument.
integer(int32)            :: port           !< Port of the remote mode.
integer(int32)            :: i              !< Counter.

frequency = 1.0_real64
amplitude = 1.0_real64
phase = 0.0_real64
clicks = 0_int32
animate = .false.
demo = .false.
x = [(10.0_real64 * real(i - 1, real64) / real(N - 1, real64), i = 1, N)]

call get_command_argument(1, arg)
if (trim(arg) == '--remote') then                     ! the UI in a web browser: no window, display or GPU
   port = 8080_int32
   call get_command_argument(2, arg)
   if (len_trim(arg) > 0) read(arg, *) port
   call app%init_remote(port=port)
else
   call app%init('FIGURE: hello', 1100_int32, 700_int32)
endif
do while (app%next_frame())
   if (animate) then
      phase = phase + 0.05_real64
      call app%request_frames(1_int32)   ! keep drawing while animating; idle otherwise
   endif
   y = amplitude * sin(frequency * x + phase)

   call ig_set_next_window(20.0_real64, 20.0_real64, 1040.0_real64, 640.0_real64)
   if (ig_begin('Hello, FIGURE')) then
      if (ig_button('Click me')) clicks = clicks + 1_int32
      call ig_same_line()
      write(line, '(A,I0)') 'clicks: ', clicks
      call ig_text(trim(line))
      if (ig_slider('frequency', frequency, 0.1_real64, 5.0_real64)) continue
      if (ig_input('amplitude', amplitude, step=0.1_real64)) continue
      if (ig_checkbox('animate', animate)) continue
      call ig_same_line()
      if (ig_checkbox('Dear ImGui demo', demo)) continue
      call ig_separator()
      if (ip_begin_plot('Wave', height=-1.0_real64)) then
         call ip_setup_axes('x', 'y')
         call ip_line('a sin(f x + p)', x, y)
         call ip_end_plot()
      endif
   endif
   call ig_end()
   if (demo) call ig_show_demo_window(demo)
enddo
call app%destroy()
endprogram figure_hello
