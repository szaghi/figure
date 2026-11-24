!< figure_test_plot_frame_3d_style, the Fortran 3-D frame's style: ImPlot3D's colours and variables pushed, the themes.
program figure_test_plot_frame_3d_style
!< figure_test_plot_frame_3d_style, the Fortran 3-D frame's style: ImPlot3D's colours and variables pushed, the themes.
!<
!< szaghi/figure#15 P13, the style. Each case is a 3-D plot with a helix, markers and a surface, drawn on a few frames
!< first by ImPlot3D through FIGURE's API (`ip3_*`, the style pushed with `ip3_push_style_*`), then by the Fortran frame
!< (`pf3_*`, the style pushed with `pf3_push_style_*`), 40 frames apart. Checked on every frame, to the bit: the
!< corners' and two points' pixels, the pointer's ray and whether it is over the plot; the pictures of the first and
!< last frames at FIGURE's oracle rule (|d| <= 2, no pixel failing). The cases:
!<
!< 1. twelve of ImPlot3D's fourteen colours pushed (hex and components, 3 and 4 of them; the axes' hovered and active
!<    backgrounds want the pointer on an axis) and every style variable FIGURE can name (the plot's default and least
!<    sizes, paddings, the view's scale factor, the items' weight, marker size and fill alpha, the legend's paddings
!<    and spacing), popped after the plot, on FIGURE's default theme 'seal';
!< 2.-5. FIGURE's themes 'light', 'paper', 'high-contrast', 'seal-light', nothing pushed (the themes set no ImPlot3D
!<    colour: the 3-D plots follow Dear ImGui's colours, ImPlot3D's `GetAutoColor`);
!< 6. Dear ImGui's style alpha at 0.6 (the grid's and the legend's text, ImPlot3D's `ImGui::GetColorU32`, take it; the
!<    other colours, `GetStyleColorU32`, do not).
!<
!< The pictures are `figure_test_plot_frame_3d_style.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ip3_push_style_color, &
                   ip3_pop_style_color, ip3_push_style_var, ip3_pop_style_var, ig_push_style_var, ig_pop_style_var, &
                   ImGuiWindowFlags_NoDecoration
use figure_implot3d_ref, only : ip3_begin_plot, ip3_end_plot, ip3_mouse_ray, ip3_plot_to_pixels, ip3_setup_axes, &
                                ip3_line, ip3_scatter, ip3_surface, ip3_spec, ImPlot3DMarker_Square
use figure_plot3d_frame, only : pf3_begin_plot, pf3_end_plot, pf3_mouse_ray, pf3_plot_to_pixels, pf3_setup_axes
use figure_plot3d_items, only : pf3_line, pf3_scatter, pf3_surface, pf3_spec
use figure_style, only : hex_color
use figure_plot3d_style, only : pf3_push_style_color, pf3_pop_style_color, pf3_push_style_var, pf3_pop_style_var
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

implicit none
integer(int32), parameter :: W = 640_int32     !< Display width [pixels].
integer(int32), parameter :: H = 480_int32     !< Display height [pixels].
integer(int32), parameter :: NCASE = 6_int32   !< Cases.
integer(int32), parameter :: NF = 3_int32      !< Frames per side of a case.
integer(int32), parameter :: NP = 120_int32    !< Points of the helix.
integer(int32), parameter :: NSTATE = 27_int32 !< Values per frame: 8 corners (16), 2 points (4), the ray (6), over.
real(real64),   parameter :: LIM1(6) = [-1.0_real64, 1.0_real64, -2.0_real64, 2.0_real64, 0.0_real64, 5.0_real64] !< Limits.
real(real64)              :: hx(NP), hy(NP), hz(NP)     !< The helix.
real(real64)              :: gx(16), gy(12), gz(16, 12) !< A surface.
real(real64)              :: plot_bg(4)                 !< A hex colour's components.
logical                   :: ok                         !< Parsed.
type(app_object)          :: app                        !< Application.
real(real64)              :: state(NSTATE, NF, 2)       !< Per frame and side.
logical                   :: test_passed(NCASE)         !< Per-case outcome.
logical                   :: side_fortran               !< Drawing with the Fortran frame.
integer(int32)            :: c, f, s, sd, i, ii, jj     !< Case, frame, status, side, counters.
character(len=16)         :: keep                       !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do i = 1_int32, NP
   hx(i) = 0.8_real64 * cos(real(i, real64) * 0.15_real64)
   hy(i) = 1.6_real64 * sin(real(i, real64) * 0.15_real64)
   hz(i) = real(i, real64) * 0.04_real64
enddo
do ii = 1_int32, 16_int32
   gx(ii) = -1.0_real64 + real(ii - 1_int32, real64) * (2.0_real64 / 15.0_real64)
enddo
do jj = 1_int32, 12_int32
   gy(jj) = -2.0_real64 + real(jj - 1_int32, real64) * (4.0_real64 / 11.0_real64)
   do ii = 1_int32, 16_int32
      gz(ii, jj) = 1.0_real64 + 0.6_real64 * sin(2.0_real64 * gx(ii)) * cos(gy(jj))
   enddo
enddo
call hex_color('#203040', plot_bg, ok) ! ImPlot3D's side is given the hex text
if (.not. ok) error stop 'figure_test_plot_frame_3d_style: hex_color refused #203040'
do c = 1_int32, NCASE
   state = 0.0_real64
   select case (c)
   case (2_int32)
      call app%set_style('light')
   case (3_int32)
      call app%set_style('paper')
   case (4_int32)
      call app%set_style('high-contrast')
   case (5_int32)
      call app%set_style('seal-light')
   case default
      call app%set_style('seal')
   endselect
   do sd = 1_int32, 2_int32 ! 1 ImPlot3D, 2 the Fortran frame
      side_fortran = sd == 2_int32
      do f = 1_int32, NF
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_3d_style: next_frame returned false headless'
         if (c == 6_int32) call ig_push_style_var('Alpha', 0.6_real64)
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame 3d style', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(c, f)
         call ig_end()
         if (c == 6_int32) call ig_pop_style_var()
         if (f == NF) call test_capture(picture(c, side_fortran), s)
         if (f == 1_int32) call test_capture(picture(10_int32 + c, side_fortran), s)
      enddo
      do i = 1_int32, 40_int32
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_3d_style: next_frame returned false headless'
      enddo
   enddo
   test_passed(c) = state_equal(c) .and. pictures_equal(c) .and. pictures_equal(10_int32 + c)
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_3d_style checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine draw_case(k, fr)
   !< A case's plot on a frame, by the side drawing (case 1 with the style pushed, popped after the plot).
   integer(int32), intent(in) :: k, fr !< Case, frame.
   integer(int32)             :: m     !< Side.

   m = merge(2_int32, 1_int32, side_fortran)
   associate(v => state(:, fr, m))
      if (k == 1_int32) call push_style()
      if (side_fortran) then
         if (pf3_begin_plot('Style', width=600.0_real64)) then
            call pf3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=25.0_real64, azimuth=40.0_real64)
            call pf3_line('helix', hx, hy, hz)
            call pf3_scatter('points', hx(::8), hy(::8), hz(::8), spec=pf3_spec(marker=ImPlot3DMarker_Square))
            call pf3_surface('surface', gx, gy, gz)
            call measure(v)
            call pf3_end_plot()
         endif
      else
         if (ip3_begin_plot('Style', width=600.0_real64)) then
            call ip3_setup_axes('x', 'y', 'z', limits=LIM1, elevation=25.0_real64, azimuth=40.0_real64)
            call ip3_line('helix', hx, hy, hz)
            call ip3_scatter('points', hx(::8), hy(::8), hz(::8), spec=ip3_spec(marker=ImPlot3DMarker_Square))
            call ip3_surface('surface', gx, gy, gz)
            call measure(v)
            call ip3_end_plot()
         endif
      endif
      if (k == 1_int32) call pop_style()
   endassociate
   endsubroutine draw_case

   subroutine push_style()
   !< Every colour and variable of the 3-D style pushed, by the side drawing.

   if (side_fortran) then
      call pf3_push_style_color('PlotBg', plot_bg)
      call pf3_push_style_color('FrameBg', [0.1_real64, 0.12_real64, 0.1_real64])
      call pf3_push_style_color('TitleText', [1.0_real64, 0.8_real64, 0.2_real64, 1.0_real64])
      call pf3_push_style_color('InlayText', [0.6_real64, 1.0_real64, 0.6_real64, 1.0_real64])
      call pf3_push_style_color('PlotBorder', [0.9_real64, 0.3_real64, 0.3_real64, 1.0_real64])
      call pf3_push_style_color('LegendBg', [0.2_real64, 0.2_real64, 0.35_real64, 0.9_real64])
      call pf3_push_style_color('LegendBorder', [0.8_real64, 0.8_real64, 0.2_real64, 1.0_real64])
      call pf3_push_style_color('LegendText', [0.7_real64, 0.9_real64, 1.0_real64, 1.0_real64])
      call pf3_push_style_color('AxisText', [1.0_real64, 0.6_real64, 0.8_real64, 1.0_real64])
      call pf3_push_style_color('AxisGrid', [0.3_real64, 0.9_real64, 0.9_real64, 0.5_real64])
      call pf3_push_style_color('AxisTick', [1.0_real64, 1.0_real64, 0.0_real64, 1.0_real64])
      call pf3_push_style_color('AxisBg', [0.3_real64, 0.3_real64, 0.6_real64, 0.3_real64])
      call pf3_push_style_var('PlotDefaultSize', [500.0_real64, 380.0_real64])
      call pf3_push_style_var('PlotMinSize', [300.0_real64, 300.0_real64])
      call pf3_push_style_var('PlotPadding', [20.0_real64, 15.0_real64])
      call pf3_push_style_var('LabelPadding', [2.0_real64, 9.0_real64])
      call pf3_push_style_var('ViewScaleFactor', 0.8_real64)
      call pf3_push_style_var('LineWeight', 2.5_real64)
      call pf3_push_style_var('MarkerSize', 6.0_real64)
      call pf3_push_style_var('FillAlpha', 0.5_real64)
      call pf3_push_style_var('LegendPadding', [4.0_real64, 6.0_real64])
      call pf3_push_style_var('LegendInnerPadding', [8.0_real64, 3.0_real64])
      call pf3_push_style_var('LegendSpacing', [2.0_real64, 4.0_real64])
   else
      call ip3_push_style_color('PlotBg', '#203040')
      call ip3_push_style_color('FrameBg', [0.1_real64, 0.12_real64, 0.1_real64])
      call ip3_push_style_color('TitleText', [1.0_real64, 0.8_real64, 0.2_real64, 1.0_real64])
      call ip3_push_style_color('InlayText', [0.6_real64, 1.0_real64, 0.6_real64, 1.0_real64])
      call ip3_push_style_color('PlotBorder', [0.9_real64, 0.3_real64, 0.3_real64, 1.0_real64])
      call ip3_push_style_color('LegendBg', [0.2_real64, 0.2_real64, 0.35_real64, 0.9_real64])
      call ip3_push_style_color('LegendBorder', [0.8_real64, 0.8_real64, 0.2_real64, 1.0_real64])
      call ip3_push_style_color('LegendText', [0.7_real64, 0.9_real64, 1.0_real64, 1.0_real64])
      call ip3_push_style_color('AxisText', [1.0_real64, 0.6_real64, 0.8_real64, 1.0_real64])
      call ip3_push_style_color('AxisGrid', [0.3_real64, 0.9_real64, 0.9_real64, 0.5_real64])
      call ip3_push_style_color('AxisTick', [1.0_real64, 1.0_real64, 0.0_real64, 1.0_real64])
      call ip3_push_style_color('AxisBg', [0.3_real64, 0.3_real64, 0.6_real64, 0.3_real64])
      call ip3_push_style_var('PlotDefaultSize', [500.0_real64, 380.0_real64])
      call ip3_push_style_var('PlotMinSize', [300.0_real64, 300.0_real64])
      call ip3_push_style_var('PlotPadding', [20.0_real64, 15.0_real64])
      call ip3_push_style_var('LabelPadding', [2.0_real64, 9.0_real64])
      call ip3_push_style_var('ViewScaleFactor', 0.8_real64)
      call ip3_push_style_var('LineWeight', 2.5_real64)
      call ip3_push_style_var('MarkerSize', 6.0_real64)
      call ip3_push_style_var('FillAlpha', 0.5_real64)
      call ip3_push_style_var('LegendPadding', [4.0_real64, 6.0_real64])
      call ip3_push_style_var('LegendInnerPadding', [8.0_real64, 3.0_real64])
      call ip3_push_style_var('LegendSpacing', [2.0_real64, 4.0_real64])
   endif
   endsubroutine push_style

   subroutine pop_style()
   !< The pushes undone, by the side drawing.

   if (side_fortran) then
      call pf3_pop_style_color(12_int32)
      call pf3_pop_style_var(11_int32)
   else
      call ip3_pop_style_color(12_int32)
      call ip3_pop_style_var(11_int32)
   endif
   endsubroutine pop_style

   subroutine measure(v)
   !< The state of the plot being declared, by the side drawing: corners' and points' pixels, the pointer's ray.
   real(real64), intent(out) :: v(NSTATE) !< State.
   real(real64)              :: o(3), d(3) !< Ray.
   real(real64)              :: q(3)      !< A point.
   integer(int32)            :: j         !< Corner.
   logical                   :: over      !< Over the plot.

   do j = 0_int32, 7_int32 ! the box of LIM1
      q(1) = LIM1(1)
      if (iand(j, 1_int32) /= 0_int32) q(1) = LIM1(2)
      q(2) = LIM1(3)
      if (iand(j, 2_int32) /= 0_int32) q(2) = LIM1(4)
      q(3) = LIM1(5)
      if (iand(j, 4_int32) /= 0_int32) q(3) = LIM1(6)
      call to_pixels(q, v(2_int32 * j + 1_int32), v(2_int32 * j + 2_int32))
   enddo
   q(1) = 0.3_real64
   q(2) = -0.7_real64
   q(3) = 1.1_real64
   call to_pixels(q, v(17), v(18))
   q(1) = 0.25_real64
   q(2) = 0.5_real64
   q(3) = 0.75_real64
   call to_pixels(q, v(19), v(20))
   if (side_fortran) then
      over = pf3_mouse_ray(o, d)
   else
      over = ip3_mouse_ray(o, d)
   endif
   v(21:23) = o
   v(24:26) = d
   v(27) = merge(1.0_real64, 0.0_real64, over)
   endsubroutine measure

   subroutine to_pixels(q, px, py)
   !< A point's pixel, by the side drawing.
   real(real64), intent(in)  :: q(3)   !< Point.
   real(real64), intent(out) :: px, py !< Pixel.

   if (side_fortran) then
      call pf3_plot_to_pixels(q(1), q(2), q(3), px, py)
   else
      call ip3_plot_to_pixels(q(1), q(2), q(3), px, py)
   endif
   endsubroutine to_pixels

   function state_equal(k) result(ok)
   !< Both sides' state equal on every frame.
   integer(int32), intent(in) :: k  !< Case.
   logical                    :: ok !< Equal.
   integer(int32)             :: fr !< Frame.

   ok = .true.
   do fr = 1_int32, NF
      if (all(state(:, fr, 1) == state(:, fr, 2))) cycle
      ok = .false.
      write(output_unit, '(A,I0,A,I0,A)') 'case ', k, ', frame ', fr, ': ImPlot3D, frame'
      write(output_unit, '(5ES24.16)') state(:, fr, 1)
      write(output_unit, '(5ES24.16)') state(:, fr, 2)
   enddo
   endfunction state_equal

   function pictures_equal(k) result(ok)
   !< A case's pictures of both sides equal at the oracle's rule.
   integer(int32), intent(in) :: k   !< Case.
   logical                    :: ok  !< Equal.
   integer(int64)             :: nf_ !< Pixels that failed.
   integer(int32)             :: st  !< Status.

   ok = test_compare_image(picture(k, .true.), picture(k, .false.), threshold=2_int32, max_failed=0_int32, &
                           failed=nf_, stat=st)
   if (.not. ok) write(output_unit, '(A,I0,A,I0,A,A)') 'case ', k, ': ', nf_, ' pixels failed: ', figure_last_error()
   endfunction pictures_equal

   function picture(k, fortran) result(name)
   !< A case's picture: ImPlot3D's or the Fortran frame's.
   integer(int32), intent(in)    :: k       !< Case.
   logical,        intent(in)    :: fortran !< The Fortran frame's.
   character(len=:), allocatable :: name    !< File name.
   character(len=8)              :: tag     !< The case's number.

   write(tag, '(I0)') k
   if (fortran) then
      name = 'figure_test_plot_frame_3d_style.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_3d_style.'//trim(tag)//'.implot3d.png.tmp'
   endif
   endfunction picture

   subroutine remove_files()
   !< The pictures removed (and a mismatch's .new.png and .diff.png, left only on a failure).
   integer(int32) :: k, u, ios, j !< Case, unit, status, side.
   logical        :: there        !< The file exists.

   do k = 1_int32, 10_int32 + NCASE
      do j = 1_int32, 2_int32
         inquire(file=picture(k, j == 2_int32), exist=there)
         if (.not. there) cycle
         open(newunit=u, file=picture(k, j == 2_int32), status='old', iostat=ios)
         if (ios == 0) close(u, status='delete')
      enddo
   enddo
   endsubroutine remove_files
endprogram figure_test_plot_frame_3d_style
