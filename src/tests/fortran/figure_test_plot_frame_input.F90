!< figure_test_plot_frame_input, the Fortran plot frame's pan, zoom, box select, fit, mouse text and menus, as ImPlot's.
program figure_test_plot_frame_input
!< figure_test_plot_frame_input, the Fortran plot frame's pan, zoom, box select, fit, mouse text and menus, as ImPlot's.
!<
!< szaghi/figure#15 P10, step 8. Each case is a plot drawn on a few frames, first by ImPlot through FIGURE's API, then
!< by the Fortran frame (`pf_*`), with the same synthetic input queued at the same frames (figure_testing: pointer
!< moves, drags, button presses, the wheel, a click on a menu item found by its label); the pointer's targets are
!< taken from ImPlot's plot on the first frame of each case (`ip_plot_to_pixels` of its limits' corners) and used on
!< both sides. Checked on every frame: the ranges of X1-Y1 and of the current axes, `plot_hovered`, `plot_mouse`,
!< `plot_selection` (flag and extent), equal to the bit; and pictures at FIGURE's oracle rule (|d| <= 2 on every
!< channel, no pixel failing). The cases:
!<
!< 1. a pan (a left drag across the plot); 2. the wheel's zoom in, in, out at a point off the centre; 3. a box
!< (right drag: drawn while held, with the mouse text; released: the zoom), then a second box cancelled by the program
!< (`cancel_selection`) before its release; 4. a pan, then a double click: the fit; 5. a drag over the x axis's
!< labels (only x pans) and the wheel over the y axis's (only y zooms); 6. the mouse text over a log y axis and a
!< second y axis; 7. the pointer over the y axis's labels (its highlight); 8. a right click: the plot's context menu
!< (pictured open), its Settings > Crosshairs clicked, the crosshairs drawn.
!<
!< The two sides are 40 frames apart (past Dear ImGui's double-click time: a click of the frame's side at the place of
!< one of ImPlot's side 0.2 s before made a double click, the fit).
!<
!< The pictures are `figure_test_plot_frame_input.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them; a
!< mismatch's .new.png and .diff.png are left for inspection).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ImGuiWindowFlags_NoDecoration
use figure_implot_ref, only : ip_begin_plot, ip_end_plot, ip_cancel_selection, ip_line, ip_plot_hovered, &
                              ip_plot_limits, ip_plot_mouse, ip_plot_selection, ip_plot_to_pixels, ip_set_axes, &
                              ip_setup_axes, ip_setup_axes_limits, ip_setup_axis, ip_spec
use figure_plot_frame, only : pf_begin_plot, pf_cancel_selection, pf_end_plot, pf_plot_hovered,     &
                              pf_plot_limits, pf_plot_mouse, pf_plot_selection, pf_set_axes, pf_setup_axes, &
                              pf_setup_axes_limits, pf_setup_axis
use figure_plot_items, only : pf_line, pf_spec
use figure_testing, only : test_capture, test_compare_image, test_drag, test_item_click, test_mouse_button, &
                           test_mouse_move, test_next_frame, test_wheel

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 440_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 8_int32    !< Cases.
integer(int32), parameter :: NFMAX = 20_int32   !< Frames per side of a case at most.
integer(int32), parameter :: NP = 201_int32     !< Points of a line.
integer(int32), parameter :: NSTATE = 15_int32  !< Values checked per frame.
real(real64),   parameter :: C1(4) = [0.91_real64, 0.40_real64, 0.30_real64, 1.0_real64] !< A colour.
real(real64),   parameter :: C2(4) = [0.30_real64, 0.62_real64, 0.85_real64, 1.0_real64] !< Another.
type(app_object)          :: app                !< Application.
real(real64)              :: xs(NP), ys(NP, 3)  !< The lines.
real(real64)              :: state(NSTATE, NFMAX, 2) !< Per frame and side: ranges (8), hovered, mouse (2),
                                                     !< selected, selection's extent (x min, y max: 2) and x max.
real(real64)              :: rx0, rx1, ry0, ry1 !< The plot area's corners on the first frame [pixels].
logical                   :: test_passed(NCASE) !< Per-case outcome.
logical                   :: side_fortran       !< Drawing with the Fortran frame.
integer(int32)            :: c, f, s, sd, i     !< Case, frame, status, side, counter.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do i = 1_int32, NP
   xs(i) = real(i - 1_int32, real64) * 0.05_real64
   ys(i, 1) = sin(xs(i))
   ys(i, 2) = 10.0_real64**(xs(i) / 3.0_real64)
   ys(i, 3) = 0.6_real64 * cos(1.3_real64 * xs(i))
enddo
do c = 1_int32, NCASE
   state = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
      side_fortran = sd == 2_int32
      do f = 1_int32, nframes(c)
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_input: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame input', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(c, f)
         call ig_end()
         if (captured(c, f) > 0_int32) call test_capture(picture(c, captured(c, f), side_fortran), s)
         call pointer(c, f)
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      do i = 1_int32, 40_int32 ! past Dear ImGui's double-click time (0.3 s): the other side's clicks are not a pair
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_input: next_frame returned false headless'
      enddo
   enddo
   test_passed(c) = state_equal(c)
   do i = 1_int32, 2_int32
      if (any(captured_frames(c) == i)) test_passed(c) = pictures_equal(c, i) .and. test_passed(c)
   enddo
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_input checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   pure function nframes(k) result(n)
   !< A case's frames per side.
   integer(int32), intent(in) :: k !< Case.
   integer(int32)             :: n !< Frames.

   select case (k)
   case (1_int32)
      n = 10_int32
   case (2_int32, 4_int32)
      n = 12_int32
   case (3_int32, 8_int32)
      n = 18_int32
   case (5_int32)
      n = 14_int32
   case default
      n = 4_int32
   endselect
   endfunction nframes

   pure function captured(k, fr) result(n)
   !< The picture taken on a frame (0: none, 1: the first, 2: the second).
   integer(int32), intent(in) :: k, fr !< Case, frame.
   integer(int32)             :: n     !< Picture.

   n = 0_int32
   if (fr == nframes(k)) n = 1_int32
   if ((k == 3_int32 .and. fr == 7_int32) .or. (k == 8_int32 .and. fr == 6_int32)) n = 2_int32
   endfunction captured

   pure function captured_frames(k) result(n)
   !< The pictures a case takes.
   integer(int32), intent(in) :: k    !< Case.
   integer(int32)             :: n(2) !< Pictures (0: none).

   n = [1_int32, 0_int32]
   if (k == 3_int32 .or. k == 8_int32) n(2) = 2_int32
   endfunction captured_frames

   function px(t) result(v)
   !< The pixel at the fraction t of the plot area's width.
   real(real64), intent(in) :: t !< Fraction.
   real(real64)             :: v !< Pixel.

   v = real(nint(rx0 + t * (rx1 - rx0)), real64)
   endfunction px

   function py(t) result(v)
   !< The pixel at the fraction t of the plot area's height, from its top.
   real(real64), intent(in) :: t !< Fraction.
   real(real64)             :: v !< Pixel.

   v = real(nint(ry0 + t * (ry1 - ry0)), real64)
   endfunction py

   subroutine pointer(k, fr)
   !< A case's input on a frame, the same on both sides.
   integer(int32), intent(in) :: k, fr !< Case, frame.

   select case (k)
   case (1_int32) ! a pan
      if (fr == 2_int32) call test_drag(px(0.5_real64), py(0.5_real64), px(0.5_real64) - 120.0_real64, &
                                        py(0.5_real64) + 60.0_real64)
      if (fr == 8_int32) call away()
   case (2_int32) ! the wheel
      if (fr == 2_int32) call test_mouse_move(px(0.3_real64), py(0.7_real64))
      if (fr == 4_int32 .or. fr == 6_int32) call test_wheel(1.0_real64)
      if (fr == 8_int32) call test_wheel(-1.0_real64)
      if (fr == 10_int32) call away()
   case (3_int32) ! a box, then a box cancelled
      if (fr == 2_int32 .or. fr == 11_int32) call test_mouse_move(px(0.25_real64), py(0.3_real64))
      if (fr == 3_int32 .or. fr == 12_int32) call test_mouse_button(.true., 'right')
      if (fr == 4_int32 .or. fr == 13_int32) call test_mouse_move(px(0.6_real64), py(0.75_real64))
      if (fr == 5_int32) call test_mouse_move(px(0.65_real64), py(0.8_real64))
      if (fr == 8_int32 .or. fr == 15_int32) call test_mouse_button(.false., 'right')
      if (fr == 10_int32 .or. fr == 16_int32) call away()
   case (4_int32) ! a pan, then a double click
      if (fr == 2_int32) call test_drag(px(0.5_real64), py(0.5_real64), px(0.5_real64) + 90.0_real64, &
                                        py(0.5_real64) - 50.0_real64)
      if (fr == 7_int32) then
         call test_mouse_move(px(0.4_real64), py(0.4_real64))
         call test_next_frame()
         call test_mouse_button(.true.)
         call test_next_frame()
         call test_mouse_button(.false.)
         call test_next_frame()
         call test_mouse_button(.true.)
         call test_next_frame()
         call test_mouse_button(.false.)
      endif
      if (fr == 10_int32) call away()
   case (5_int32) ! over the axes
      if (fr == 2_int32) call test_drag(px(0.5_real64), ry1 + 8.0_real64, px(0.5_real64) + 100.0_real64, &
                                        ry1 + 8.0_real64)
      if (fr == 8_int32) call test_mouse_move(rx0 - 15.0_real64, py(0.5_real64))
      if (fr == 9_int32) call test_wheel(1.0_real64)
      if (fr == 11_int32) call away()
   case (6_int32) ! the mouse text
      if (fr == 1_int32) call test_mouse_move(px(0.4_real64), py(0.6_real64))
   case (7_int32) ! an axis hovered
      if (fr == 1_int32) call test_mouse_move(rx0 - 15.0_real64, py(0.5_real64))
   case default ! the context menu
      if (fr == 2_int32) call test_mouse_move(px(0.5_real64), py(0.5_real64))
      if (fr == 3_int32) call test_mouse_button(.true., 'right')
      if (fr == 4_int32) call test_mouse_button(.false., 'right')
      if (fr == 7_int32) call test_item_click('Settings')
      if (fr == 11_int32) call test_item_click('Crosshairs')
      if (fr == 15_int32) call test_mouse_move(px(0.3_real64), py(0.4_real64))
   endselect
   endsubroutine pointer

   subroutine away()
   !< The pointer away from the window.

   call test_mouse_move(-100.0_real64, -100.0_real64)
   endsubroutine away

   subroutine draw_case(k, fr)
   !< A case's plot on a frame, by the side drawing.
   integer(int32), intent(in) :: k, fr !< Case, frame.
   real(real64)               :: x0, x1, y0, y1 !< The limits' corners.

   if (.not. begin(plot_id(k))) return
   if (k == 6_int32) then
      call axes(yscale='log')
      call axis('y2')
      call limits(0.0_real64, 10.0_real64, 1.0_real64, 1.0e4_real64)
      call line('##exp', 2_int32, C1)
      call set_axes('x1', 'y2')
      call line('##cos', 3_int32, C2)
   else
      call limits(0.0_real64, 10.0_real64, -1.5_real64, 1.5_real64)
      call line('##sine', 1_int32, C1)
   endif
   if (k == 3_int32 .and. fr == 14_int32) call cancel()
   if (fr == 1_int32 .and. .not. side_fortran) then ! the plot area's corners, for the pointer's targets
      if (k == 6_int32) then
         call ip_plot_to_pixels(0.0_real64, 1.0e4_real64, x0, y0, 'x1', 'y1')
         call ip_plot_to_pixels(10.0_real64, 1.0_real64, x1, y1, 'x1', 'y1')
      else
         call ip_plot_to_pixels(0.0_real64, 1.5_real64, x0, y0, 'x1', 'y1')
         call ip_plot_to_pixels(10.0_real64, -1.5_real64, x1, y1, 'x1', 'y1')
      endif
      rx0 = x0
      rx1 = x1
      ry0 = y0
      ry1 = y1
   endif
   call finish(fr)
   endsubroutine draw_case

   function begin(id) result(visible)
   !< `ip_begin_plot` or `pf_begin_plot`, 600 x 400.
   character(len=*), intent(in) :: id      !< Plot's ID.
   logical                      :: visible !< Plot visible.

   if (side_fortran) then
      visible = pf_begin_plot(id, width=600.0_real64, height=400.0_real64)
   else
      visible = ip_begin_plot(id, width=600.0_real64, height=400.0_real64)
   endif
   endfunction begin

   subroutine axes(yscale)
   !< `ip_setup_axes` or `pf_setup_axes`, no labels.
   character(len=*), intent(in) :: yscale !< Scale of y.

   if (side_fortran) then
      call pf_setup_axes('', '', yscale=yscale)
   else
      call ip_setup_axes('', '', yscale=yscale)
   endif
   endsubroutine axes

   subroutine axis(name)
   !< `ip_setup_axis` or `pf_setup_axis`.
   character(len=*), intent(in) :: name !< Axis.

   if (side_fortran) then
      call pf_setup_axis(name)
   else
      call ip_setup_axis(name)
   endif
   endsubroutine axis

   subroutine limits(xmin, xmax, ymin, ymax)
   !< X1 and Y1's ranges on the first frame (`once`).
   real(real64), intent(in) :: xmin, xmax, ymin, ymax !< Ranges.

   if (side_fortran) then
      call pf_setup_axes_limits(xmin, xmax, ymin, ymax)
   else
      call ip_setup_axes_limits(xmin, xmax, ymin, ymax)
   endif
   endsubroutine limits

   subroutine set_axes(x, y)
   !< `ip_set_axes` or `pf_set_axes`.
   character(len=*), intent(in) :: x, y !< Axes.

   if (side_fortran) then
      call pf_set_axes(x, y)
   else
      call ip_set_axes(x, y)
   endif
   endsubroutine set_axes

   subroutine cancel()
   !< `ip_cancel_selection` or `pf_cancel_selection`.

   if (side_fortran) then
      call pf_cancel_selection()
   else
      call ip_cancel_selection()
   endif
   endsubroutine cancel

   subroutine line(label, j, col)
   !< `ip_line` or `pf_line` of the j-th line.
   character(len=*), intent(in) :: label  !< Label.
   integer(int32),   intent(in) :: j      !< Line.
   real(real64),     intent(in) :: col(4) !< Colour.

   if (side_fortran) then
      call pf_line(label, xs, ys(:, j), spec=pf_spec(line_color=col))
   else
      call ip_line(label, xs, ys(:, j), spec=ip_spec(line_color=col))
   endif
   endsubroutine line

   subroutine finish(fr)
   !< The frame's state kept (ranges, hover, pointer, selection) and the plot ended.
   integer(int32), intent(in) :: fr !< Frame.
   integer(int32)             :: m  !< Side.
   logical                    :: sel, hov !< Selected, hovered.

   m = merge(2_int32, 1_int32, side_fortran)
   associate(v => state(:, fr, m))
      if (side_fortran) then
         call pf_plot_limits(v(1), v(2), v(3), v(4), 'x1', 'y1')
         call pf_plot_limits(v(5), v(6), v(7), v(8))
         hov = pf_plot_hovered()
         call pf_plot_mouse(v(10), v(11))
         sel = pf_plot_selection(v(13), v(15), v(14), v(12))
         call pf_end_plot()
      else
         call ip_plot_limits(v(1), v(2), v(3), v(4), 'x1', 'y1')
         call ip_plot_limits(v(5), v(6), v(7), v(8))
         hov = ip_plot_hovered()
         call ip_plot_mouse(v(10), v(11))
         sel = ip_plot_selection(v(13), v(15), v(14), v(12))
         call ip_end_plot()
      endif
      v(9) = merge(1.0_real64, 0.0_real64, hov)
      v(12) = v(12) + merge(1.0e6_real64, 0.0_real64, sel) ! the flag beside the extent's top (distinct when set)
   endassociate
   endsubroutine finish

   function state_equal(k) result(ok)
   !< Both sides' state equal on every frame.
   integer(int32), intent(in) :: k  !< Case.
   logical                    :: ok !< Equal.
   integer(int32)             :: fr !< Frame.

   ok = .true.
   do fr = 1_int32, nframes(k)
      if (all(state(:, fr, 1) == state(:, fr, 2))) cycle
      ok = .false.
      write(output_unit, '(A,I0,A,I0,A)') 'case ', k, ', frame ', fr, ': ImPlot, frame'
      write(output_unit, '(5ES24.16)') state(:, fr, 1)
      write(output_unit, '(5ES24.16)') state(:, fr, 2)
   enddo
   endfunction state_equal

   function pictures_equal(k, n) result(ok)
   !< A case's n-th pictures of both sides equal at the oracle's rule.
   integer(int32), intent(in) :: k, n !< Case, picture.
   logical                    :: ok   !< Equal.
   integer(int64)             :: nf_  !< Pixels that failed.
   integer(int32)             :: st   !< Status.

   ok = test_compare_image(picture(k, n, .true.), picture(k, n, .false.), threshold=2_int32, max_failed=0_int32, &
                           failed=nf_, stat=st)
   if (.not. ok) write(output_unit, '(A,I0,A,I0,A,I0,A,A)') 'case ', k, ', picture ', n, ': ', nf_, &
                                                            ' pixels failed: ', figure_last_error()
   endfunction pictures_equal

   function plot_id(k) result(id)
   !< A case's plot ID.
   integer(int32), intent(in)    :: k   !< Case.
   character(len=:), allocatable :: id  !< ID.
   character(len=8)              :: tag !< The case's number.

   write(tag, '(I0)') k
   id = '##in'//trim(tag)
   endfunction plot_id

   function picture(k, n, fortran) result(name)
   !< A case's n-th picture: ImPlot's or the Fortran frame's.
   integer(int32), intent(in)    :: k, n    !< Case, picture.
   logical,        intent(in)    :: fortran !< The Fortran frame's.
   character(len=:), allocatable :: name    !< File name.
   character(len=16)             :: tag     !< The case's and picture's numbers.

   write(tag, '(I0,A,I0)') k, '.', n
   if (fortran) then
      name = 'figure_test_plot_frame_input.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_input.'//trim(tag)//'.implot.png.tmp'
   endif
   endfunction picture

   subroutine remove_files()
   !< The pictures (a mismatch's .new.png and .diff.png are left for inspection).
   integer(int32) :: unit, ios, k, n, m !< Unit, status, counters.

   do k = 1_int32, NCASE
      do n = 1_int32, 2_int32
         do m = 1_int32, 2_int32
            open(newunit=unit, file=picture(k, n, m == 1_int32), status='old', iostat=ios)
            if (ios == 0) close(unit, status='delete')
         enddo
      enddo
   enddo
   endsubroutine remove_files
endprogram figure_test_plot_frame_input
