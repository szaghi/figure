!< figure_test_plot_frame_style, the Fortran plot frame's ImPlot style (themes, variables, colours, Dear ImGui's Alpha).
program figure_test_plot_frame_style
!< figure_test_plot_frame_style, the Fortran plot frame's ImPlot style (themes, variables, colours, Dear ImGui's
!< Alpha).
!<
!< szaghi/figure#15 P10 (what P10-P12 left, night 2026-11-23 step 09). Each case sets a style with FIGURE's API (a
!< theme, `ip_set_style_var`, `ip_set_style_color`, `ig_set_style_var('Alpha')`), takes it into the frame's style
!< (`ps_sync`: figure_plot_style), then draws the same plot with ImPlot (`ip_*`) and with the frame (`pf_*`), 40
!< frames apart: a title, axis labels, two lines and their legend, a tag, an annotation, a drag line, the pointer on the
!< plot from the second frame (the mouse text), a colour bar beside it. Checked: the ranges of X1, Y1 and the plot
!< area on every frame to the bit, the pictures of the last frame at FIGURE's oracle rule. The cases:
!<
!< 1. the theme 'paper' ([implot.colors]: FrameBg, PlotBg, borders, texts, AxisGrid with its alpha; MinorAlpha 0.5);
!< 2. the look 'adwaita' (PlotPadding 12, no PlotBorder);
!< 3. variables (LabelPadding, MajorTickLen, LegendSpacing, MinorAlpha, FitPadding: the fit padded) and colours
!<    (AxisGrid, LegendBg, PlotBorder, InlayText) set by name;
!< 4. Dear ImGui's style Alpha at 0.6: ImPlot applies it to the grid, the legend's text, the tag's and the annotation's
!<    boxes and the items (`ImGui::GetColorU32`), not to the frame, the backgrounds, the borders, the axes' text or
!<    the drag line (`GetStyleColorU32`, `ColorConvertFloat4ToU32`).
!<
!< The pictures are `figure_test_plot_frame_style.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_same_line, ig_set_next_window, &
                   ig_set_style_var, ip_set_style_color, ip_set_style_var, ImGuiWindowFlags_NoDecoration
use figure_implot_ref, only : ip_annotation, ip_begin_plot, ip_colormap_scale, ip_drag_line_x, ip_end_plot, ip_line, &
                              ip_plot_limits, ip_plot_to_pixels, ip_setup_axes, ip_setup_legend, ip_spec, ip_tag
use figure_plot_frame, only : pf_annotation, pf_begin_plot, pf_colormap_scale, pf_end_plot, pf_plot_limits, &
                              pf_plot_to_pixels, pf_setup_axes, pf_setup_legend, pf_tag
use figure_plot_items, only : pf_line, pf_spec
use figure_plot_style, only : ps_reset, ps_sync
use figure_plot_tools, only : pf_drag_line_x
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 440_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 4_int32    !< Cases.
integer(int32), parameter :: NF = 4_int32       !< Frames per side.
integer(int32), parameter :: NP = 201_int32     !< Points of a line.
real(real64),   parameter :: C1(4) = [0.91_real64, 0.40_real64, 0.30_real64, 1.0_real64] !< A colour.
real(real64),   parameter :: C2(4) = [0.30_real64, 0.62_real64, 0.85_real64, 1.0_real64] !< Another.
real(real64),   parameter :: BOX(4) = [0.2_real64, 0.3_real64, 0.7_real64, 0.9_real64]   !< An annotation's box.
type(app_object)          :: app                !< Application.
real(real64)              :: xs(NP), ys(NP, 2)  !< The lines.
real(real64)              :: state(8, NF, 2)    !< Per frame and side.
real(real64)              :: xl                 !< The drag line.
logical                   :: test_passed(NCASE) !< Per-case outcome.
logical                   :: side_fortran, moved !< Drawing with the Fortran frame, the drag line moved.
integer(int32)            :: c, f, s, sd, i     !< Case, frame, status, side, counter.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do i = 1_int32, NP
   xs(i) = real(i - 1_int32, real64) * 0.05_real64
   ys(i, 1) = sin(xs(i))
   ys(i, 2) = 0.7_real64 * cos(1.3_real64 * xs(i))
enddo
do c = 1_int32, NCASE
   call set_case(c)
   state = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
      side_fortran = sd == 2_int32
      xl = 6.5_real64
      do f = 1_int32, NF
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_style: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame style', flags=ImGuiWindowFlags_NoDecoration)) call draw(state(:, f, sd))
         call ig_end()
         if (f == NF) call test_capture(picture(c, side_fortran), s)
         if (f == 1_int32) call test_mouse_move(260.0_real64, 220.0_real64)
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      do i = 1_int32, 40_int32
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_style: next_frame returned false headless'
      enddo
   enddo
   test_passed(c) = state_equal(c) .and. pictures_equal(c)
enddo
call ig_set_style_var('Alpha', 1.0_real64)
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_style checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine set_case(k)
   !< A case's style, set with FIGURE's API, then taken into the frame's.
   integer(int32), intent(in) :: k !< Case.

   call ps_reset()
   select case (k)
   case (1_int32)
      call app%set_style('paper')
   case (2_int32)
      call app%set_style('seal', look='adwaita')
   case (3_int32)
      call app%set_style('seal')
      call ip_set_style_var('LabelPadding', [8.0_real64, 3.0_real64])
      call ip_set_style_var('MajorTickLen', [6.0_real64, 14.0_real64])
      call ip_set_style_var('LegendSpacing', [8.0_real64, 2.0_real64])
      call ip_set_style_var('MinorAlpha', 0.6_real64)
      call ip_set_style_var('FitPadding', [0.1_real64, 0.2_real64])
      call ip_set_style_color('AxisGrid', [0.2_real64, 0.8_real64, 0.3_real64, 0.5_real64])
      call ip_set_style_color('LegendBg', '#203040')
      call ip_set_style_color('PlotBorder', [0.9_real64, 0.6_real64, 0.1_real64, 1.0_real64])
      call ip_set_style_color('InlayText', '#80ff80')
   case default
      call app%set_style('seal')
      call ig_set_style_var('Alpha', 0.6_real64)
   endselect
   call ps_sync()
   endsubroutine set_case

   subroutine draw(v)
   !< The plot and the colour bar, by the side drawing.
   real(real64), intent(inout) :: v(:) !< State.

   if (side_fortran) then
      if (pf_begin_plot('Styled##st', width=480.0_real64, height=400.0_real64)) then
         call pf_setup_axes('x [m]', 'y [V]')
         call pf_setup_legend('ne')
         call pf_line('sine', xs, ys(:, 1), spec=pf_spec(line_color=C1))
         call pf_line('cosine', xs, ys(:, 2), spec=pf_spec(line_color=C2))
         call pf_tag('y1', 0.5_real64)
         call pf_annotation(3.0_real64, 0.2_real64, 'a note', color=BOX, offset=[20.0_real64, -20.0_real64])
         moved = pf_drag_line_x(1_int32, xl, thickness=2.0_real64)
         call pf_plot_limits(v(1), v(2), v(3), v(4), 'x1', 'y1')
         call pf_plot_to_pixels(v(1), v(4), v(5), v(6), 'x1', 'y1')
         call pf_plot_to_pixels(v(2), v(3), v(7), v(8), 'x1', 'y1')
         call pf_end_plot()
      endif
      call ig_same_line()
      call pf_colormap_scale('scale', -1.0_real64, 1.0_real64, height=400.0_real64)
   else
      if (ip_begin_plot('Styled##st', width=480.0_real64, height=400.0_real64)) then
         call ip_setup_axes('x [m]', 'y [V]')
         call ip_setup_legend('ne')
         call ip_line('sine', xs, ys(:, 1), spec=ip_spec(line_color=C1))
         call ip_line('cosine', xs, ys(:, 2), spec=ip_spec(line_color=C2))
         call ip_tag('y1', 0.5_real64)
         call ip_annotation(3.0_real64, 0.2_real64, 'a note', color=BOX, offset=[20.0_real64, -20.0_real64])
         moved = ip_drag_line_x(1_int32, xl, thickness=2.0_real64)
         call ip_plot_limits(v(1), v(2), v(3), v(4), 'x1', 'y1')
         call ip_plot_to_pixels(v(1), v(4), v(5), v(6), 'x1', 'y1')
         call ip_plot_to_pixels(v(2), v(3), v(7), v(8), 'x1', 'y1')
         call ip_end_plot()
      endif
      call ig_same_line()
      call ip_colormap_scale('scale', -1.0_real64, 1.0_real64, height=400.0_real64)
   endif
   endsubroutine draw

   function state_equal(k) result(ok)
   !< Both sides' state equal on every frame.
   integer(int32), intent(in) :: k  !< Case.
   logical                    :: ok !< Equal.
   integer(int32)             :: fr !< Frame.

   ok = .true.
   do fr = 1_int32, NF
      if (all(state(:, fr, 1) == state(:, fr, 2))) cycle
      ok = .false.
      write(output_unit, '(A,I0,A,I0,A)') 'case ', k, ', frame ', fr, ': ImPlot, frame'
      write(output_unit, '(4ES24.16)') state(:, fr, 1)
      write(output_unit, '(4ES24.16)') state(:, fr, 2)
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
   !< A case's picture: ImPlot's or the Fortran frame's.
   integer(int32), intent(in)    :: k       !< Case.
   logical,        intent(in)    :: fortran !< The Fortran frame's.
   character(len=:), allocatable :: name    !< File name.
   character(len=8)              :: tag     !< The case's number.

   write(tag, '(I0)') k
   if (fortran) then
      name = 'figure_test_plot_frame_style.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_style.'//trim(tag)//'.implot.png.tmp'
   endif
   endfunction picture

   subroutine remove_files()
   !< The pictures (a mismatch's .new.png and .diff.png are left for inspection).
   integer(int32) :: unit, ios, k, m !< Unit, status, counters.

   do k = 1_int32, NCASE
      do m = 1_int32, 2_int32
         open(newunit=unit, file=picture(k, m == 1_int32), status='old', iostat=ios)
         if (ios == 0) close(unit, status='delete')
      enddo
   enddo
   endsubroutine remove_files
endprogram figure_test_plot_frame_style
