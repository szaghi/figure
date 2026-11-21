!< figure_test_render_state, figure_test_render's state shared with its frame hook (a module procedure: no trampoline).
module figure_test_render_state
!< figure_test_render_state, figure_test_render's state shared with its frame hook (a module procedure: no trampoline).
use, intrinsic :: iso_c_binding, only : c_float, c_int, c_loc
use, intrinsic :: iso_fortran_env, only : int8, int32
use figure, only : FIG_OK
use figure_c_native, only : fig_image_write
use figure_render, only : render_frame
use figure_render_cpu, only : cpu_renderer
use figure_render_imgui, only : render_frame_from_imgui

implicit none
private
public :: cpu, want, drawn, shot, hook

type(cpu_renderer)  :: cpu            !< The Fortran CPU renderer.
type(render_frame)  :: frame          !< The frame it draws.
logical             :: want = .false. !< The hook renders this frame.
logical             :: drawn = .false. !< The Fortran picture is not the clear colour only.
character(len=64)   :: shot = ''      !< Where it writes the picture.

contains
   subroutine hook(width, height, clear) bind(C)
   !< After a frame's Render: on the frames the test captures, the same draw data drawn by the Fortran renderer.
   integer(c_int), value      :: width    !< Picture's width [pixels].
   integer(c_int), value      :: height   !< Picture's height [pixels].
   real(c_float),  intent(in) :: clear(3) !< Clear colour.
   integer(int8), allocatable, target :: rgb(:) !< Picture.
   integer(int32)             :: k, st     !< Counter, status.

   if (.not. want) return
   allocate(rgb(3 * int(width, int32) * int(height, int32)))
   call render_frame_from_imgui(frame)
   call cpu%render(frame, int(width, int32), int(height, int32), clear, rgb)
   drawn = .false.
   do k = 1, size(rgb) / 3
      if (any(rgb(3 * k - 2:3 * k) /= rgb(1:3))) then
         drawn = .true.
         exit
      endif
   enddo
   st = fig_image_write(trim(shot), len_trim(shot, c_int), c_loc(rgb), 3_c_int, int(width, c_int), int(height, c_int), &
                        0_c_int)
   if (st /= FIG_OK) drawn = .false.
   endsubroutine hook
endmodule figure_test_render_state

!< figure_test_render, the Fortran CPU renderer draws the frames the C++ one draws, to the bit, headless.
program figure_test_render
!< figure_test_render, the Fortran CPU renderer draws the frames the C++ one draws, to the bit, headless.
!<
!< szaghi/figure#15 P9's gate on the CPU renderer. Frames of several kinds, each captured by the native layer's CPU
!< renderer (figure_swrast.cpp, `test_capture`) and drawn from the same draw data by the Fortran path's
!< (figure_render_cpu through figure_render_imgui, called by the native layer's frame hook after the frame's Render);
!< the two pictures compared at the defaults (|d| <= 2, no pixel failing; the same bytes expected): widgets and text;
!< a line plot and a heatmap; a field image (`ip_field_image`: a texture and the samplers' callbacks); a user texture
!< drawn nearest (scaled up 8 times) and linear; a drawing with a vertex far beyond the picture (the clipped path); a
!< frame rendered with 1 and with 3 threads. Pixels of each scene are checked to be drawn (not the clear colour only).
!< The pictures are `figure_test_render.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_c_binding, only : c_funloc, c_null_funptr
use, intrinsic :: iso_fortran_env, only : int8, int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_button, ig_checkbox, ig_draw_line, ig_draw_polygon, &
                   ig_end, ig_image, ig_set_next_window, ig_text, ip_begin_plot, ip_end_plot, ip_field_image,       &
                   ip_heatmap, ip_line, texture_object, ImGuiWindowFlags_NoDecoration
use figure_c_native, only : fig_set_frame_hook
use figure_test_render_state, only : cpu, drawn, hook, shot, want
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

implicit none
integer(int32),   parameter :: W = 480_int32     !< Display width [pixels].
integer(int32),   parameter :: H = 360_int32     !< Display height [pixels].
integer(int32),   parameter :: NSCENE = 6_int32  !< Scenes.
character(len=8), parameter :: SCENES(NSCENE) = [character(len=8) :: 'widgets', 'plot', 'field', 'texture', 'far', &
                                                 'threads'] !< Their names.
type(app_object)            :: app               !< Application.
type(texture_object)        :: tex               !< A user texture, nearest.
type(texture_object)        :: tex_smooth        !< ... linear.
integer(int8), allocatable  :: rgba(:,:,:)       !< Its pixels.
real(real64)                :: x(200), y(200)    !< A line.
real(real64)                :: f(40, 30)         !< A field.
logical                     :: test_passed(NSCENE) !< Per-scene outcome.
integer(int32)              :: scene, fr, s, i, j !< Counters, status.
integer(int64)              :: nf                !< Pixels that failed.
logical                     :: check             !< A check box.
character(len=16)           :: keep              !< FIGURE_TEST_KEEP.

do i = 1, 200
   x(i) = real(i - 1, real64) * 0.05_real64
   y(i) = sin(x(i)) + 0.2_real64 * sin(7.0_real64 * x(i))
enddo
do j = 1, 30
   do i = 1, 40
      f(i, j) = sin(0.2_real64 * real(i, real64)) * cos(0.25_real64 * real(j, real64))
   enddo
enddo
allocate(rgba(4, 8, 6))
do j = 1, 6
   do i = 1, 8
      rgba(:, i, j) = int([mod(37 * i, 256) - 128, mod(53 * j, 256) - 128, mod(17 * (i + j), 256) - 128, 127], int8)
   enddo
enddo
check = .true.

call app%init_headless(W, H)
call tex%init(8_int32, 6_int32, smooth=.false.)
call tex%update(rgba)
call tex_smooth%init(8_int32, 6_int32, smooth=.true.)
call tex_smooth%update(rgba)
call test_mouse_move(-100.0_real64, -100.0_real64)
s = fig_set_frame_hook(c_funloc(hook))
do scene = 1_int32, NSCENE
   cpu%threads = merge(3_int32, 1_int32, SCENES(scene) == 'threads')
   do fr = 1_int32, 3_int32
      if (.not. app%next_frame()) error stop 'figure_test_render: next_frame returned false in headless mode'
      want = fr == 3_int32
      shot = 'figure_test_render.'//trim(SCENES(scene))//'.f.png.tmp'
      call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
      if (ig_begin('render', flags=ImGuiWindowFlags_NoDecoration)) call draw(SCENES(scene))
      call ig_end()
      if (want) call test_capture('figure_test_render.'//trim(SCENES(scene))//'.cpp.png.tmp', s)
   enddo
   if (.not. app%next_frame()) error stop 'figure_test_render: next_frame returned false in headless mode' ! renders
   want = .false.
   test_passed(scene) = test_compare_image('figure_test_render.'//trim(SCENES(scene))//'.f.png.tmp',     &
                                           'figure_test_render.'//trim(SCENES(scene))//'.cpp.png.tmp', &
                                           failed=nf, stat=s) .and. drawn
   if (.not. test_passed(scene)) write(output_unit, '(A,A,A,I0,A,L1,A,A)') 'scene ', trim(SCENES(scene)), ': ', nf, &
                                                                         ' failed, drawn ', drawn, ': ', figure_last_error()
enddo
s = fig_set_frame_hook(c_null_funptr)
call tex%destroy()
call tex_smooth%destroy()
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_render checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine draw(what)
   !< One scene's content.
   character(len=*), intent(in) :: what !< Scene.
   logical                      :: clicked !< A button (never clicked).

   select case (what)
   case ('widgets', 'threads')
      call ig_text('Widgets and text: the quick brown fox jumps over the lazy dog 0123456789')
      clicked = ig_button('A button')
      if (ig_checkbox('A check box', check)) continue
   case ('plot')
      if (ip_begin_plot('line', width=460.0_real64, height=160.0_real64)) then
         call ip_line('sin', x, y)
         call ip_end_plot()
      endif
      if (ip_begin_plot('heat', width=460.0_real64, height=160.0_real64)) then
         call ip_heatmap('f', f, 0.0_real64, 4.0_real64, 0.0_real64, 3.0_real64, label_format='%.1f')
         call ip_end_plot()
      endif
   case ('field')
      if (ip_begin_plot('field', width=460.0_real64, height=320.0_real64)) then
         call ip_field_image('f', f, 0.0_real64, 4.0_real64, 0.0_real64, 3.0_real64)
         call ip_end_plot()
      endif
   case ('texture')
      call ig_image(tex, width=64.0_real64, height=48.0_real64)
      call ig_image(tex_smooth, width=200.0_real64, height=150.0_real64)
   case ('far')
      call ig_draw_line(10.0_real64, 300.0_real64, 9.0e6_real64, 4.0e6_real64, [1.0_real64, 0.8_real64, 0.2_real64])
      call ig_draw_polygon([20.0_real64, 400.0_real64, -3.0e6_real64], [20.0_real64, 60.0_real64, 5.0e6_real64], &
                           [0.3_real64, 0.6_real64, 1.0_real64, 0.7_real64], filled=.true.)
   endselect
   endsubroutine draw

   subroutine remove_files()
   !< The pictures (a mismatch's .diff.png is left for inspection).
   integer(int32) :: unit, ios, k, m !< Unit, status, counters.
   character(len=64) :: name        !< A picture.

   do k = 1_int32, NSCENE
      do m = 1, 2
         name = 'figure_test_render.'//trim(SCENES(k))//merge('.f.png.tmp  ', '.cpp.png.tmp', m == 1)
         open(newunit=unit, file=trim(name), status='old', iostat=ios)
         if (ios == 0) close(unit, status='delete')
      enddo
   enddo
   endsubroutine remove_files
endprogram figure_test_render
