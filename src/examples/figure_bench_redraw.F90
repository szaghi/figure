!< figure_bench_redraw, benchmark: the cost of redrawing a FIGURE interface, in a window or served to a browser.
program figure_bench_redraw
!< figure_bench_redraw, benchmark: the cost of redrawing a FIGURE interface, in a window or served to a browser.
!<
!< Usage: `figure_bench_redraw CASE [options]`, where CASE is
!<
!< - `idle`: a window of widgets and a 1000-point line; nothing changes, nobody touches it;
!< - `interact`: the same, with the pointer moving over it every frame (scripted with `figure_testing` in a window;
!<   in remote mode the client moves the pointer instead);
!< - `live`: the line changes `--rate` times per second (a computation publishing its state);
!< - `bigplot`: a line of `--points` points (default 100000), changed `--rate` times per second;
!< - `heatmap`: an `--cells` x `--cells` heatmap (default 256), changed `--rate` times per second;
!< - `texture`: a `--width` x `--height` texture (default 3840 x 2160), new pixels `--rate` times per second.
!<
!< Options: `--rate R` updates per second (default 10; 0: never), `--seconds S` measured time (default 10), after
!< `--warmup W` seconds not measured (default 2), `--remote PORT` serve to a browser instead of opening a window.
!< Lazy redraw stays on (the default): the program wakes every 1/R s to publish new data, as a live computation would.
!<
!< When the warm-up ends it prints `bench warm` (the harness starts counting CPU time there); at the end it prints
!< `bench <case> frames=<n> seconds=<s> app_ms=<a> figure_ms=<f> updates=<u>`: frames drawn and wall time since the
!< warm-up, and the time per frame spent in the program's own code (the UI calls and the data update) and inside
!< `next_frame` (rendering or serialising, sending, waiting for input or for the next refresh). The CPU time and the
!< bytes sent are measured from outside by `scripts/measure_redraw.py`.
use, intrinsic :: iso_fortran_env, only : int8, int32, int64, output_unit, real64
use figure, only : app_object, ig_begin, ig_checkbox, ig_end, ig_image, ig_set_next_window, ig_slider, ig_text, &
                   ip_begin_plot, ip_end_plot, ip_heatmap, ip_line, ip_setup_axes, texture_object, ImPlotColormap_Viridis
use figure_testing, only : test_mouse_move

implicit none
real(real64), parameter    :: PI = acos(-1.0_real64) !< Pi.
type(app_object)           :: app                    !< Application.
type(texture_object)       :: tex                    !< Texture (case texture).
character(len=16)          :: bench                  !< The case.
character(len=32)          :: arg                    !< A command argument.
real(real64)               :: rate                   !< Updates per second.
real(real64)               :: seconds                !< Measured time [s].
real(real64)               :: warmup                 !< Time before the measurement [s].
logical                    :: warm                   !< The warm-up is over.
integer(int32)             :: port                   !< Remote port; -1: a window.
integer(int32)             :: points                 !< Points of the line.
integer(int32)             :: cells                  !< Heatmap side.
integer(int32)             :: tw                     !< Texture width.
integer(int32)             :: th                     !< Texture height.
real(real64), allocatable  :: x(:)                   !< Abscissae.
real(real64), allocatable  :: y(:)                   !< Ordinates.
real(real64), allocatable  :: f(:,:)                 !< Heatmap values.
integer(int8), allocatable :: rgba(:,:,:)            !< Texture pixels.
real(real64)               :: amplitude              !< A slider's value.
logical                    :: flag                   !< A checkbox's value.
integer(int64)             :: clock_rate             !< Clock ticks per second.
integer(int64)             :: t_start                !< Clock at the first frame.
integer(int64)             :: t_last_update          !< Clock at the last data update.
integer(int64)             :: t0                     !< Clock at a phase start.
integer(int64)             :: t1                     !< Clock at a phase end.
real(real64)               :: app_s                  !< Time in the program's own code [s].
real(real64)               :: figure_s               !< Time inside next_frame [s].
integer(int32)             :: frames                 !< Frames drawn.
integer(int32)             :: updates                !< Data updates.
integer(int32)             :: i                      !< Counter.
integer(int32)             :: j                      !< Counter.
character(len=64)          :: line                   !< Text buffer.

call parse_arguments()
allocate(x(points), y(points))
x = [(real(i - 1, real64) / real(points - 1, real64), i = 1_int32, points)]
amplitude = 0.8_real64
flag = .true.
updates = 0_int32
call update_data()
if (port >= 0_int32) then
   call app%init_remote(port=port, width=1280_int32, height=800_int32, quiet=.true.)
else
   call app%init('FIGURE: redraw benchmark', 1280_int32, 800_int32)
endif
if (trim(bench) == 'texture') then
   call tex%init(tw, th)
   call tex%update(rgba)
endif
if (rate > 0.0_real64) call app%set_lazy(.true., max_wait=1.0_real64 / rate)
call system_clock(t_start, clock_rate)
t_last_update = t_start
t1 = t_start
app_s = 0.0_real64
figure_s = 0.0_real64
frames = 0_int32
warm = .false.
do
   call system_clock(t0)
   app_s = app_s + real(t0 - t1, real64) / real(clock_rate, real64)
   if (.not. app%next_frame()) exit
   call system_clock(t1)
   figure_s = figure_s + real(t1 - t0, real64) / real(clock_rate, real64)
   if (.not. warm .and. real(t1 - t_start, real64) / real(clock_rate, real64) >= warmup) then
      warm = .true.                                   ! counting starts now
      write(output_unit, '(A)') 'bench warm'
      flush(output_unit)
      t_start = t1
      app_s = 0.0_real64
      figure_s = 0.0_real64
      frames = 0_int32
   endif
   if (warm .and. real(t1 - t_start, real64) / real(clock_rate, real64) >= seconds) exit
   frames = frames + 1_int32
   if (rate > 0.0_real64) then
      if (real(t1 - t_last_update, real64) / real(clock_rate, real64) >= 0.999_real64 / rate) then
         t_last_update = t1
         updates = updates + 1_int32
         call update_data()
         if (trim(bench) == 'texture') call tex%update(rgba)
      endif
   endif
   if (trim(bench) == 'interact' .and. port < 0_int32) then ! a pointer circling over the widgets and the plot
      call test_mouse_move(640.0_real64 + 400.0_real64 * cos(0.05_real64 * frames), &
                           400.0_real64 + 300.0_real64 * sin(0.07_real64 * frames))
      call app%request_frames(1_int32)
   endif
   call draw()
enddo
call system_clock(t1)
write(output_unit, '(A,A,A,I0,A,F0.3,A,F0.4,A,F0.4,A,I0)') 'bench ', trim(bench), ' frames=', frames, ' seconds=', &
   real(t1 - t_start, real64) / real(clock_rate, real64), ' app_ms=', 1000.0_real64 * app_s / max(frames, 1_int32), &
   ' figure_ms=', 1000.0_real64 * figure_s / max(frames, 1_int32), ' updates=', updates
flush(output_unit)
if (tex%is_initialized()) call tex%destroy()
call app%destroy()

contains
   subroutine parse_arguments()
   !< The case and its options.
   integer(int32) :: k !< Argument index.

   bench = 'idle'
   rate = -1.0_real64
   seconds = 10.0_real64
   warmup = 2.0_real64
   port = -1_int32
   points = 1000_int32
   cells = 256_int32
   tw = 3840_int32
   th = 2160_int32
   if (command_argument_count() > 0) call get_command_argument(1, bench)
   select case (trim(bench))
   case ('idle', 'interact')
      rate = 0.0_real64
   case ('bigplot')
      points = 100000_int32
   case ('live', 'heatmap', 'texture')
   case default
      error stop 'figure_bench_redraw: the case is idle, interact, live, bigplot, heatmap or texture'
   endselect
   if (rate < 0.0_real64) rate = 10.0_real64
   k = 2_int32
   do while (k <= command_argument_count())
      call get_command_argument(k, arg)
      call get_command_argument(k + 1_int32, line)
      select case (trim(arg))
      case ('--rate')
         read(line, *) rate
      case ('--seconds')
         read(line, *) seconds
      case ('--warmup')
         read(line, *) warmup
      case ('--remote')
         read(line, *) port
      case ('--points')
         read(line, *) points
      case ('--cells')
         read(line, *) cells
      case ('--width')
         read(line, *) tw
      case ('--height')
         read(line, *) th
      case default
         error stop 'figure_bench_redraw: unknown option'
      endselect
      k = k + 2_int32
   enddo
   if (trim(bench) == 'heatmap') allocate(f(cells, cells))
   if (trim(bench) == 'texture') allocate(rgba(4, tw, th))
   endsubroutine parse_arguments

   subroutine update_data()
   !< New data: the state of the computation after one more update.
   real(real64) :: phase !< Advances with the updates.

   phase = 0.2_real64 * updates
   y = amplitude * exp(-2.0_real64 * x) * sin(2.0_real64 * PI * (8.0_real64 * x - phase)) + &
       0.05_real64 * sin(2.0_real64 * PI * 200.0_real64 * x + 3.0_real64 * phase)
   if (allocated(f)) then
      do j = 1_int32, cells
         do i = 1_int32, cells
            f(i, j) = sin(6.0_real64 * i / cells + phase) * cos(4.0_real64 * j / cells - 0.5_real64 * phase)
         enddo
      enddo
   endif
   if (allocated(rgba)) then
      do j = 1_int32, th
         do i = 1_int32, tw
            rgba(1, i, j) = int(iand(i + 8_int32 * updates, 127_int32), int8)
            rgba(2, i, j) = int(iand(j + 3_int32 * updates, 127_int32), int8)
            rgba(3, i, j) = int(iand(i + j, 127_int32), int8)
            rgba(4, i, j) = -1_int8
         enddo
      enddo
   endif
   endsubroutine update_data

   subroutine draw()
   !< The interface: a panel of widgets and the case's plot.
   call ig_set_next_window(10.0_real64, 10.0_real64, 300.0_real64, 780.0_real64)
   if (ig_begin('Controls')) then
      if (ig_slider('amplitude', amplitude, 0.0_real64, 1.0_real64)) continue
      if (ig_checkbox('running', flag)) continue
      write(line, '(A,I0)') 'updates: ', updates
      call ig_text(trim(line))
   endif
   call ig_end()
   call ig_set_next_window(320.0_real64, 10.0_real64, 950.0_real64, 780.0_real64)
   if (ig_begin('View')) then
      select case (trim(bench))
      case ('heatmap')
         if (ip_begin_plot('Field', height=-1.0_real64)) then
            call ip_heatmap('f', f, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, scale_min=-1.0_real64, &
                            scale_max=1.0_real64, colormap=ImPlotColormap_Viridis)
            call ip_end_plot()
         endif
      case ('texture')
         call ig_image(tex, 920.0_real64, 920.0_real64 * th / tw)
      case default
         if (ip_begin_plot('Signal', height=-1.0_real64)) then
            call ip_setup_axes('x', 'y')
            call ip_line('y', x, y)
            call ip_end_plot()
         endif
      endselect
   endif
   call ig_end()
   endsubroutine draw
endprogram figure_bench_redraw
