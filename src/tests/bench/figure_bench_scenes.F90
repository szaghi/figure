!< figure_bench_scenes, the benchmark scenes of #15 P2: the frame time of typical and large FIGURE windows.
program figure_bench_scenes
!< figure_bench_scenes, the benchmark scenes of #15 P2: the frame time of typical and large FIGURE windows.
!<
!< Usage: `figure_bench_scenes [SCENE] [--frames N] [--warmup N] [--window] [--size W H]`.
!<
!< Without a scene (as `scripts/run_tests.sh` and `fpm test` run it) every scene runs a few headless frames at a small
!< size of its data: a check that each one builds, draws and ends. With a scene, `--warmup` frames (default 30) not
!< measured, then `--frames` frames (default 300) measured, headless (no window, no rasterization: the UI's cost) or
!< with `--window` in a window (vsync and lazy redraw off: the GPU's rasterization and the swap included), on a
!< display of 1280 x 800 pixels (`--size`). Each measured frame prints a line `t <frame_ms> <ui_ms>`: the time from
!< one `next_frame` return to the next, and the part of it in the scene's own calls (the UI up to the draw data,
!< ImPlot's included); the rest is `next_frame`'s (Dear ImGui's render, the rasterization, the swap). The first line
!< is `scene <name> <mode> frames=<n>`. `scripts/bench_scenes.py` runs the scenes and computes their statistics.
!<
!< The scenes (#15 P2):
!< - `widgets`: a main menu bar and two docked windows of about 300 widgets (buttons, check boxes, sliders, fields,
!<   a tree, texts) and a small plot;
!< - `table`: a table of 10000 rows and 4 columns through the list clipper, scrolled by 3 rows a frame;
!< - `line100`, `line1e4`, `line1e5`, `line1e6`, `line1e7`, `line1e8`: a line plot of that many points, x sorted,
!<   fitted;
!< - `line1e8c`: `line1e8` drawn after `ip_cache_next_item(changed=.false.)` (#15 P5: the data never change);
!< - `device1e8`: `line1e8`'s points in device memory (FUNDAL's `dev_alloc`), drawn by `ip_line_device` (#15 P6: on
!<   the GPU in the tests-nvf-acc build, FUNDAL's CPU mode elsewhere);
!< - `scatter1e6`: 1e6 markers;
!< - `heatmap256`, `heatmap512`, `heatmap1024`, `heatmap4096`: a field of n x n cells drawn by `ip_heatmap`, its values
!<   changing every frame;
!< - `field512`, `field1024`, `field4096`: the same through `ip_field_image` (a texture coloured again every frame);
!< - `surface256`: a 3-D surface of 256 x 256 points (ImPlot3D), its heights changing every frame;
!< - `editor10k`: the code editor showing a file of 10000 lines.
!<
!< The data the heatmap, field and surface scenes recompute every frame come from `figure_bench_data`
!< (src/tests/bench/), built with the default test mode's flags on both paths (szaghi/figure#16, C7).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit, error_unit
use fundal, only : dev_alloc, dev_free, dev_init, dev_memcpy_to_device
use figure_bench_data, only : field_values
use figure, only : app_object, code_editor_object, ig_begin, ig_begin_main_menu_bar, ig_begin_menu, ig_begin_table, &
                   ig_tree_node, ig_button, ig_checkbox, ig_dock_id, ig_dock_layout_begin,                          &
                   ig_dock_layout_end, ig_dock_space, ig_dock_split, ig_dock_window, ig_end, ig_end_main_menu_bar, &
                   ig_end_menu, ig_end_table, ig_input_text, ig_menu_item, ig_same_line, ig_set_next_window,      &
                   ig_set_scroll, ig_slider, ig_table_next_row, ig_table_set_column, ig_table_setup_column,       &
                   ig_table_headers_row, ig_text, ig_tree_pop, ip3_begin_plot, ip3_end_plot, ip3_surface,          &
                   ip_begin_plot, ip_end_plot, ip_field_image, ip_heatmap, ip_line, ip_scatter, ip_setup_axes,    &
                   ip_cache_next_item, ip_line_device,                                                              &
                   list_clipper_object, ImGuiWindowFlags_NoDecoration

implicit none
integer(int32), parameter     :: NSCENES = 20_int32 !< Scenes.
character(len=11), parameter  :: SCENES(NSCENES) = [character(len=11) :: 'widgets', 'table', 'line100', 'line1e4', &
   'line1e6', 'line1e7', 'line1e8', 'scatter1e6', 'heatmap512', 'heatmap1024', 'heatmap4096', 'field512',          &
   'field1024', 'field4096', 'surface256', 'editor10k', 'line1e5', 'heatmap256', 'line1e8c', 'device1e8'] !< Their names.
integer(int32), parameter     :: SMOKE_FRAMES = 3_int32   !< Frames of each scene without a scene named.
integer(int64), parameter     :: SMOKE_POINTS = 10000_int64 !< Largest data of a scene without a scene named.
type(app_object)              :: app                 !< Application.
type(code_editor_object)      :: ed                  !< The editor (editor10k).
type(list_clipper_object)     :: clip                !< The table's clipper.
character(len=32)             :: scene               !< The scene run.
character(len=32)             :: arg                 !< A command argument.
integer(int32)                :: frames              !< Frames measured.
integer(int32)                :: warmup              !< Frames not measured.
integer(int32)                :: width, height       !< Display [pixels].
logical                       :: window              !< In a window.
logical                       :: smoke               !< Every scene, a few frames.
real(real64), allocatable     :: x(:), y(:)          !< A line's or a scatter's points.
real(real64), pointer         :: xd(:) => null()     !< A line's points in device memory (device1e8).
real(real64), pointer         :: yd(:) => null()     !< ... ordinates.
real(real64), allocatable     :: f(:,:)              !< A field.
real(real64), allocatable     :: gx(:), gy(:)        !< A surface's grid.
real(real64), allocatable     :: t_frame(:), t_ui(:) !< Measured: frame time, UI time [ms].
integer(int64)                :: n                   !< Points of a line, side of a field.
integer(int32)                :: k, i                !< Counters.
integer(int32)                :: frame               !< Frame counter of the current scene.
! the widgets scene's state
logical                       :: flags(100)          !< Check boxes.
real(real64)                  :: values(100)         !< Sliders.
character(len=32)             :: fields(40)          !< Text fields.
real(real64)                  :: rx(100), ry(100)    !< The residuals' plot.

call arguments()
if (smoke) then
   if (window) error stop 'figure_bench_scenes: --window needs a scene'
   call app%init_headless(width, height)
   do k = 1_int32, NSCENES
      scene = SCENES(k)
      call prepare()
      do i = 1_int32, SMOKE_FRAMES
         if (.not. app%next_frame()) error stop 'figure_bench_scenes: next_frame returned false in headless mode'
         call draw()
      enddo
      call release()
   enddo
   call app%destroy()
   write(output_unit, '(A,I0,A)') 'figure_bench_scenes: ', NSCENES, ' scenes drawn (smoke run, small data)'
else
   call measured_run()
endif

contains
   subroutine measured_run()
   !< The scene named, in a window or headless: the warm-up, the measured frames, their times printed.
   if (window) then
      call app%init('figure_bench_scenes', width, height, vsync=.false.)
      call app%set_lazy(.false.)
   else
      call app%init_headless(width, height)
   endif
   call prepare()
   allocate(t_frame(frames), t_ui(frames))
   call measure()
   call release()
   call app%destroy()
   write(output_unit, '(A,1X,A,1X,A,I0)') 'scene', trim(scene), merge('window   ', 'headless ', window)//'frames=', &
                                          frames
   do i = 1_int32, frames
      write(output_unit, '(A,2(1X,F0.4))') 't', t_frame(i), t_ui(i)
   enddo
   endsubroutine measured_run

   subroutine arguments()
   !< The command line.
   integer(int32) :: a, ios !< Argument, status.

   scene = ''
   frames = 300_int32
   warmup = 30_int32
   width = 1280_int32
   height = 800_int32
   window = .false.
   a = 1_int32
   do while (a <= command_argument_count())
      call get_command_argument(a, arg)
      select case (trim(arg))
      case ('--frames')
         a = a + 1_int32
         call get_command_argument(a, arg)
         read(arg, *, iostat=ios) frames
         if (ios /= 0 .or. frames < 1_int32) error stop 'figure_bench_scenes: --frames needs a positive number'
      case ('--warmup')
         a = a + 1_int32
         call get_command_argument(a, arg)
         read(arg, *, iostat=ios) warmup
         if (ios /= 0 .or. warmup < 0_int32) error stop 'figure_bench_scenes: --warmup needs a number >= 0'
      case ('--size')
         call get_command_argument(a + 1_int32, arg)
         read(arg, *, iostat=ios) width
         if (ios == 0) then
            call get_command_argument(a + 2_int32, arg)
            read(arg, *, iostat=ios) height
         endif
         if (ios /= 0 .or. width < 64_int32 .or. height < 64_int32) error stop 'figure_bench_scenes: --size W H'
         a = a + 2_int32
      case ('--window')
         window = .true.
      case default
         if (arg(1:1) == '-' .or. len_trim(scene) > 0) then
            write(error_unit, '(A)') 'figure_bench_scenes: unknown argument '//trim(arg)
            error stop 2
         endif
         scene = arg
         if (.not. any(SCENES == scene)) then
            write(error_unit, '(A)') 'figure_bench_scenes: unknown scene '//trim(scene)
            error stop 2
         endif
      endselect
      a = a + 1_int32
   enddo
   smoke = len_trim(scene) == 0
   endsubroutine arguments

   subroutine measure()
   !< The warm-up, then the measured frames.
   integer(int64) :: rate         !< Clock ticks per second.
   integer(int64) :: t0, t1, t2   !< Clock: frame start, UI end, next frame start.
   integer(int32) :: m            !< Frame.

   call system_clock(count_rate=rate)
   do m = 1_int32, warmup
      if (.not. app%next_frame()) error stop 'figure_bench_scenes: the window closed'
      call draw()
   enddo
   if (.not. app%next_frame()) error stop 'figure_bench_scenes: the window closed'
   call system_clock(t0)
   do m = 1_int32, frames
      call draw()
      call system_clock(t1)
      if (.not. app%next_frame()) error stop 'figure_bench_scenes: the window closed'
      call system_clock(t2)
      t_ui(m) = 1.0e3_real64 * real(t1 - t0, real64) / real(rate, real64)
      t_frame(m) = 1.0e3_real64 * real(t2 - t0, real64) / real(rate, real64)
      t0 = t2
   enddo
   call draw() ! the frame opened by the last next_frame
   endsubroutine measure

   function sized(full) result(m)
   !< A scene's data size: `full`, or at most SMOKE_POINTS in a smoke run.
   integer(int64), intent(in) :: full !< The scene's size.
   integer(int64)             :: m    !< The size used.

   m = full
   if (smoke) m = min(full, SMOKE_POINTS)
   endfunction sized

   subroutine prepare()
   !< The scene's data.
   integer(int64) :: j       !< Counter.
   integer(int64) :: s       !< A pseudo-random state (an LCG: the same points everywhere).
   character(len=:), allocatable :: text !< The editor's text.
   character(len=:), allocatable :: line !< One of its lines.
   integer(int64)    :: pos  !< Its length so far.
   character(len=16) :: num  !< A number, written.
   integer(int32)    :: ierr !< FUNDAL's status.

   frame = 0_int32
   select case (trim(scene))
   case ('widgets')
      flags = .false.
      values = 0.5_real64
      fields = 'value'
      do j = 1_int64, 100_int64
         rx(j) = real(j, real64)
         ry(j) = 1.0_real64 / real(j, real64)
      enddo
   case ('line100', 'line1e4', 'line1e5', 'line1e6', 'line1e7', 'line1e8', 'line1e8c', 'device1e8')
      select case (trim(scene))
      case ('line100')
         n = sized(100_int64)
      case ('line1e4')
         n = sized(10000_int64)
      case ('line1e5')
         n = sized(100000_int64)
      case ('line1e6')
         n = sized(1000000_int64)
      case ('line1e7')
         n = sized(10000000_int64)
      case default ! line1e8, line1e8c, device1e8
         n = sized(100000000_int64)
      endselect
      allocate(x(n), y(n))
      do j = 1_int64, n
         x(j) = real(j - 1_int64, real64)
      enddo
      y = sin(x * (40.0_real64 / real(n, real64))) + 0.2_real64 * sin(x * (1000.0_real64 / real(n, real64)))
      if (trim(scene) == 'device1e8') then
         call dev_init()
         call dev_alloc(fptr_dev=xd, ubounds=[int(n, int32)], ierr=ierr, label='bench: x')
         if (ierr == 0_int32) call dev_alloc(fptr_dev=yd, ubounds=[int(n, int32)], ierr=ierr, label='bench: y')
         if (ierr == 0_int32) call dev_memcpy_to_device(dst=xd, src=x, ierr=ierr)
         if (ierr == 0_int32) call dev_memcpy_to_device(dst=yd, src=y, ierr=ierr)
         if (ierr /= 0_int32) error stop 'figure_bench_scenes: device memory'
      endif
   case ('scatter1e6')
      n = sized(1000000_int64)
      allocate(x(n), y(n))
      s = 12345_int64
      do j = 1_int64, n
         s = modulo(s * 1103515245_int64 + 12345_int64, 2147483648_int64)
         x(j) = real(s, real64) / 2147483648.0_real64
         s = modulo(s * 1103515245_int64 + 12345_int64, 2147483648_int64)
         y(j) = real(s, real64) / 2147483648.0_real64
      enddo
   case ('heatmap256', 'heatmap512', 'heatmap1024', 'heatmap4096', 'field512', 'field1024', 'field4096')
      select case (trim(scene))
      case ('heatmap256')
         n = 256_int64
      case ('heatmap512', 'field512')
         n = 512_int64
      case ('heatmap1024', 'field1024')
         n = 1024_int64
      case default
         n = 4096_int64
      endselect
      if (smoke) n = min(n, 64_int64)
      allocate(f(n, n))
      call field_values(f, 0_int32)
   case ('surface256')
      n = 256_int64
      if (smoke) n = 32_int64
      allocate(f(n, n), gx(n), gy(n))
      do j = 1_int64, n
         gx(j) = real(j - 1_int64, real64) / real(n - 1_int64, real64)
      enddo
      gy = gx
      call field_values(f, 0_int32)
   case ('editor10k')
      n = 10000_int64
      if (smoke) n = 100_int64
      allocate(character(len=100 * n) :: text)
      pos = 0_int64
      do j = 1_int64, n
         write(num, '(I0)') j
         line = '   residual('//trim(num)//') = norm2(u - u_old) / max(norm2(u), tiny(1.0_rk)) ! line '//trim(num)// &
                new_line('a')
         text(pos + 1:pos + len(line)) = line
         pos = pos + len(line, int64)
      enddo
      call ed%init()
      call ed%set_text(text(1:pos))
   endselect
   endsubroutine prepare

   subroutine release()
   !< The scene's data released.
   if (allocated(x)) deallocate(x)
   if (allocated(y)) deallocate(y)
   if (allocated(f)) deallocate(f)
   if (associated(xd)) call dev_free(xd)
   if (associated(yd)) call dev_free(yd)
   if (allocated(gx)) deallocate(gx)
   if (allocated(gy)) deallocate(gy)
   if (ed%is_initialized()) call ed%destroy()
   endsubroutine release

   subroutine draw()
   !< One frame of the scene.
   frame = frame + 1_int32
   select case (trim(scene))
   case ('widgets')
      call draw_widgets()
   case ('table')
      call draw_table()
   case ('editor10k')
      call full_window()
      if (ig_begin('editor', flags=ImGuiWindowFlags_NoDecoration)) then
         if (ed%draw('code')) continue
      endif
      call ig_end()
   case ('surface256')
      call field_values(f, frame)
      call full_window()
      if (ig_begin('surface', flags=ImGuiWindowFlags_NoDecoration)) then
         if (ip3_begin_plot('##surface', height=-1.0_real64)) then
            call ip3_surface('z', gx, gy, f)
            call ip3_end_plot()
         endif
      endif
      call ig_end()
   case default
      call full_window()
      if (ig_begin('plot', flags=ImGuiWindowFlags_NoDecoration)) then
         if (ip_begin_plot('##plot', height=-1.0_real64)) then
            call ip_setup_axes('x', 'y')
            select case (trim(scene))
            case ('scatter1e6')
               call ip_scatter('points', x, y)
            case ('heatmap256', 'heatmap512', 'heatmap1024', 'heatmap4096')
               call field_values(f, frame)
               call ip_heatmap('f', f, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, scale_min=-1.0_real64, &
                               scale_max=1.0_real64)
            case ('field512', 'field1024', 'field4096')
               call field_values(f, frame)
               call ip_field_image('f', f, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, vmin=-1.0_real64, &
                                   vmax=1.0_real64, changed=.true.)
            case ('line1e8c')
               call ip_cache_next_item(changed=.false.) ! the data never change: the cache built on the first frame
               call ip_line('signal', x, y)
            case ('device1e8')
               call ip_line_device('signal', xd, yd)
            case default
               call ip_line('signal', x, y)
            endselect
            call ip_end_plot()
         endif
      endif
      call ig_end()
   endselect
   endsubroutine draw

   subroutine full_window()
   !< The next window over the whole display.
   call ig_set_next_window(0.0_real64, 0.0_real64, real(width, real64), real(height, real64), always=.true.)
   endsubroutine full_window

   subroutine draw_widgets()
   !< A main menu bar and two docked windows of about 300 widgets.
   integer(int32)    :: root, left, right !< Dock nodes.
   integer(int32)    :: j                 !< Counter.
   character(len=24) :: label             !< A widget's label.

   if (ig_begin_main_menu_bar()) then
      if (ig_begin_menu('File')) then
         if (ig_menu_item('Open')) continue
         if (ig_menu_item('Save', shortcut='Ctrl+S')) continue
         call ig_end_menu()
      endif
      if (ig_begin_menu('View')) call ig_end_menu()
      call ig_end_main_menu_bar()
   endif
   root = ig_dock_id('bench')
   if (ig_dock_layout_begin(root)) then
      call ig_dock_split(root, 'left', 0.4_real64, left, right)
      call ig_dock_window('Controls', left)
      call ig_dock_window('Data', right)
      call ig_dock_layout_end(root)
   endif
   call ig_dock_space(root)
   if (ig_begin('Controls')) then
      do j = 1_int32, 100_int32
         write(label, '(A,I0)') 'option ', j
         if (ig_checkbox(trim(label), flags(j))) continue
         if (mod(j, 2_int32) == 1_int32) call ig_same_line()
         write(label, '(A,I0)') 'run ', j
         if (ig_button(trim(label))) continue
         write(label, '(A,I0)') 'relaxation ', j
         if (ig_slider(trim(label), values(j), 0.0_real64, 1.0_real64)) continue
      enddo
   endif
   call ig_end()
   if (ig_begin('Data')) then
      do j = 1_int32, 40_int32
         write(label, '(A,I0)') 'name ', j
         if (ig_input_text(trim(label), fields(j))) continue
      enddo
      if (ig_tree_node('blocks', default_open=.true.)) then
         do j = 1_int32, 40_int32
            write(label, '(A,I0,A)') 'block ', j, ': 4096 cells'
            call ig_text(trim(label))
         enddo
         call ig_tree_pop()
      endif
      if (ip_begin_plot('residuals', height=200.0_real64)) then
         call ip_line('residual', rx, ry)
         call ip_end_plot()
      endif
   endif
   call ig_end()
   endsubroutine draw_widgets

   subroutine draw_table()
   !< A table of 10000 rows through the list clipper, scrolled by 3 rows a frame.
   integer(int32), parameter :: ROWS = 10000_int32 !< Rows.
   real(real64),   parameter :: ROW_H = 21.0_real64 !< About a row's height [pixels].
   integer(int32)            :: r                  !< Row.
   character(len=24)         :: cell               !< A cell's text.

   call full_window()
   if (ig_begin('table', flags=ImGuiWindowFlags_NoDecoration)) then
      if (ig_begin_table('blocks', 4_int32, freeze_rows=1_int32, height=real(height, real64) - 20.0_real64)) then
         call ig_table_setup_column('block')
         call ig_table_setup_column('cells')
         call ig_table_setup_column('residual')
         call ig_table_setup_column('status')
         call ig_table_headers_row()
         call ig_set_scroll(y=modulo(3.0_real64 * ROW_H * frame, ROW_H * (ROWS - 40)))
         call clip%begin(merge(100_int32, ROWS, smoke))
         do while (clip%step())
            do r = clip%first, clip%last
               call ig_table_next_row()
               write(cell, '(I0)') r
               call ig_table_set_column(1_int32)
               call ig_text(trim(cell))
               write(cell, '(I0)') 64 * r
               call ig_table_set_column(2_int32)
               call ig_text(trim(cell))
               write(cell, '(ES10.3)') 1.0_real64 / real(r, real64)
               call ig_table_set_column(3_int32)
               call ig_text(trim(cell))
               call ig_table_set_column(4_int32)
               call ig_text(merge('converged', 'running  ', mod(r, 3_int32) == 0_int32))
            enddo
         enddo
         call ig_end_table()
      endif
   endif
   call ig_end()
   endsubroutine draw_table
endprogram figure_bench_scenes
