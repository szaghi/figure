!< figure_test_plot_marks, reading a plot (pointer, conversions, box selection) and the marks and items of S13, headless.
program figure_test_plot_marks
!< figure_test_plot_marks, reading a plot (pointer, conversions, box selection) and the marks and items of S13, headless.
!<
!< One window shows one plot setup per phase:
!<
!< 1. queries: the pointer moved to the centre of a plot with fixed limits reads the midpoint of the limits within a
!<    pixel, on Y1 and on Y2; `ip_plot_to_pixels` and `ip_pixels_to_plot` agree with the plot area measured by ImPlot's
!<    own position and size; `ip_plot_hovered` is true there and false with the pointer outside;
!< 2. box selection: a right-button drag scripted between two plot points gives that rectangle while held; cancelled,
!<    the release leaves the limits as they were; the same drag not cancelled zooms to it (control);
!< 3. a rectangle dragged by its centre moves by the drag; a corner dragged past the opposite one is put in order when
!<    released;
!< 4. marks: a tag on Y1 is drawn on the left axis at its value, one on Y2 on the right axis at its value (the items on
!<    X1/Y1), one on X1 with a text below the plot at its value, a tag without colour takes the last item's; a vertical
!<    and a horizontal infinite line span the plot area; a text is drawn at its point, moved by its offset;
!< 5. items: a histogram of known data draws its four bars over the bins (counts 1, 2, 3, 4), its variants give known
!<    heights (cumulative, density, one bin, strided, with a NaN, default bins, constant data); a 2-D histogram of known
!<    points, with and without a range; stairs and stems span their points;
!< 6. wrong calls: inside a plot (unknown or not set up axes, bad arguments) and outside any plot (usage errors).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use, intrinsic :: ieee_arithmetic, only : ieee_value, ieee_quiet_nan
use figure, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK, app_object, figure_last_error, ig_begin, ig_end,          &
                   ig_set_next_window, ip_begin_plot, ip_end_plot, ip_line, ip_plot_limits, ip_plot_size,             &
                   ip_setup_axes_limits, ip_setup_axis, ip_setup_axis_limits, ip_spec, ip_push_style_color,           &
                   ip_pop_style_color, ip_plot_hovered, ip_plot_mouse, ip_plot_to_pixels, ip_pixels_to_plot,          &
                   ip_plot_selection, ip_cancel_selection, ip_drag_rect, ip_tag, ip_inf_lines, ip_text, ip_stairs,    &
                   ip_stems, ip_histogram, ip_histogram2d, ip_drag_line_x, ImPlotHistogramFlags_Cumulative,           &
                   ImPlotHistogramFlags_Density, ImPlotBin_Scott
use figure_cimgui, only : im_vec2
use figure_cimplot, only : ImPlot_GetPlotPos
use figure_testing, only : test_drag, test_drawn_extent, test_mouse_button, test_mouse_move, test_next_frame, &
                           test_plot_copies

implicit none
integer(int32), parameter :: NE = 25_int32                                   !< Wrong calls checked.
real(real64),   parameter :: TAG_Y(4) = [0.90_real64, 0.10_real64, 0.10_real64, 1.0_real64] !< Colour of the Y1 tag.
real(real64),   parameter :: TAG_Y2(4) = [0.60_real64, 0.40_real64, 0.10_real64, 1.0_real64] !< ... of the Y2 tag.
real(real64),   parameter :: TAG_X(4) = [0.10_real64, 0.80_real64, 0.20_real64, 1.0_real64] !< ... of the X1 tag.
real(real64),   parameter :: LINE_C(4) = [0.20_real64, 0.30_real64, 0.95_real64, 1.0_real64] !< ... of a line.
real(real64),   parameter :: INF_V(4) = [0.95_real64, 0.60_real64, 0.05_real64, 1.0_real64] !< ... vertical inf line.
real(real64),   parameter :: INF_H(4) = [0.55_real64, 0.05_real64, 0.75_real64, 1.0_real64] !< ... horizontal one.
real(real64),   parameter :: TEXT_C(4) = [0.05_real64, 0.85_real64, 0.85_real64, 1.0_real64] !< ... the text.
real(real64),   parameter :: HIST_F(4) = [0.85_real64, 0.75_real64, 0.15_real64, 1.0_real64] !< ... histogram fill.
real(real64),   parameter :: HIST_L(4) = [0.15_real64, 0.15_real64, 0.15_real64, 1.0_real64] !< ... its outline.
real(real64),   parameter :: STAIR_C(4) = [0.75_real64, 0.25_real64, 0.45_real64, 1.0_real64] !< ... stairs.
real(real64),   parameter :: STEM_C(4) = [0.25_real64, 0.65_real64, 0.45_real64, 1.0_real64] !< ... stems.
real(real64),   parameter :: MARK_C(4) = [0.95_real64, 0.95_real64, 0.55_real64, 1.0_real64] !< ... stem markers.
type(app_object)   :: app             !< Application.
logical            :: ok(17)          !< Per-check outcome.
real(real64)       :: xs(101), ys(101) !< A line.
real(real64)       :: centre(2)       !< Centre of the plot area [pixels], from ImPlot's position and size.
real(real64)       :: qc(2)           !< ... of the queries' plot, when read.
real(real64)       :: area(4)         !< Plot area: left, top, right, bottom [pixels].
real(real64)       :: w, h            !< Plot area size [pixels].
logical            :: hov_in, hov_out !< Hovered with the pointer at the centre; outside.
real(real64)       :: m1(2), m2(2)    !< Pointer in plot units: on X1/Y1; on X1/Y2.
real(real64)       :: c_px(2)         !< The plot point (5, 0) in pixels.
real(real64)       :: c_pl(2)         !< The centre pixel in plot units.
real(real64)       :: trip(2)         !< A round trip of (2.5, 0.5) through pixels.
real(real64)       :: y2_px(2)        !< The plot point (5, 150) on Y2, in pixels.
real(real64)       :: p0(2), p1(2)    !< Box corners [pixels].
real(real64)       :: sel(4)          !< Box while held: xmin, xmax, ymin, ymax.
logical            :: sel_on          !< A box was reported while held.
logical            :: sel_after       !< A box reported after the cancel and release.
real(real64)       :: lim_c(4)        !< Limits after the cancelled box.
real(real64)       :: lim_z(4)        !< Limits after the box not cancelled (control).
real(real64)       :: r(4)            !< The dragged rectangle: xmin, xmax, ymin, ymax.
real(real64)       :: r_moved(4)      !< ... after the move.
real(real64)       :: r_cross(4)      !< ... after the corner crossed.
logical            :: r_flag          !< ip_drag_rect returned true in some frame.
real(real64)       :: q(2, 8)         !< Plot points in pixels: (0,0), (10,10), (4,.), (.,2), (.,7), (3,.), (5,5), (.,1).
real(real64)       :: e(4)            !< An extent.
logical            :: found           !< Found in the extent.
integer(int32)     :: nv              !< Vertices.
logical            :: tag_y_ok, tag_x_ok, tag_auto_ok, inf_ok, text_ok !< Marks.
logical            :: tag_y2_ok       !< A tag on Y2 (not an axis the items use) on the right, at its value.
real(real64)       :: hv(10)          !< Histogram data: one 0.5, two 1.5, three 2.5, four 3.5.
real(real64)       :: hw(20)          !< The same interleaved with other values (a stride of 2).
real(real64)       :: mc(9)           !< Heights of the tallest bars of the histogram variants.
real(real64)       :: hq(4)           !< Histogram extent: left, top, right, bottom [pixels], expected.
logical            :: hist_ok         !< Bars over the bins.
integer(int64)     :: copies(2)       !< Copy counter around the strided histogram.
real(real64)       :: px2(10), py2(10) !< 2-D histogram points.
real(real64)       :: mc2(2)          !< Fullest cells.
logical            :: stairs_ok, stems_ok !< Extents.
integer(int32)     :: st(NE)          !< Statuses of the wrong calls.
integer(int32)     :: want(NE)        !< ... expected.
character(len=256) :: msg(NE)         !< Their messages.
real(real64)       :: nan             !< A NaN.
integer(int32)     :: frame           !< Frame counter.
integer(int32)     :: i               !< Counter.

xs = [(real(i - 1_int32, real64) / 10.0_real64, i = 1_int32, 101_int32)]
ys = 0.5_real64 * sin(xs)
hv = [0.5_real64, 1.5_real64, 1.5_real64, 2.5_real64, 2.5_real64, 2.5_real64, 3.5_real64, 3.5_real64, 3.5_real64, &
      3.5_real64]
hw = 99.0_real64
hw(1::2) = hv
px2 = [0.5_real64, 1.5_real64, 1.5_real64, 0.5_real64, 0.5_real64, 0.5_real64, 1.5_real64, 1.5_real64, 1.5_real64, &
       1.5_real64]
py2 = [0.5_real64, 0.5_real64, 0.5_real64, 1.5_real64, 1.5_real64, 1.5_real64, 1.5_real64, 1.5_real64, 1.5_real64, &
       1.5_real64]
nan = ieee_value(1.0_real64, ieee_quiet_nan)
ok = .false.
st = -99_int32
msg = ''
centre = 0.0_real64
r = [2.0_real64, 4.0_real64, 2.0_real64, 4.0_real64]
r_flag = .false.
mc = -1.0_real64
mc2 = -1.0_real64
sel_on = .false.
sel_after = .true.

call app%init_headless(800_int32, 600_int32)
do frame = 1_int32, 100_int32
   if (.not. app%next_frame()) error stop 'figure_test_plot_marks: next_frame returned false in headless mode'
   call ig_set_next_window(10.0_real64, 10.0_real64, 700.0_real64, 560.0_real64, always=.true.)
   if (ig_begin('Marks')) then
      select case (frame)
      case (1_int32:12_int32)
         call queries(frame)
      case (13_int32:60_int32)
         call selection(frame)
      case (61_int32:84_int32)
         call rectangle(frame)
      case (85_int32:87_int32)
         call marks(frame == 87_int32)
      case (88_int32:90_int32)
         call items(frame == 90_int32)
      case (91_int32)
         call wrong_calls()
      case (92_int32)
         call outside_plot()
      endselect
   endif
   call ig_end()
enddo
call app%destroy()

! 1. queries
ok(1) = hov_in .and. .not. hov_out
ok(2) = abs(m1(1) - 5.0_real64) <= 10.0_real64 / w .and. abs(m1(2)) <= 2.0_real64 / h .and. &
        abs(m2(1) - 5.0_real64) <= 10.0_real64 / w .and. abs(m2(2) - 150.0_real64) <= 100.0_real64 / h
ok(3) = abs(c_px(1) - qc(1)) <= 1.0_real64 .and. abs(c_px(2) - qc(2)) <= 1.0_real64 .and.                   &
        abs(c_pl(1) - 5.0_real64) <= 10.0_real64 / w .and. abs(c_pl(2)) <= 2.0_real64 / h .and.                &
        abs(trip(1) - 2.5_real64) <= 10.0_real64 / w .and. abs(trip(2) - 0.5_real64) <= 2.0_real64 / h .and.   &
        abs(y2_px(2) - qc(2)) <= 1.0_real64
! 2. box selection
ok(4) = sel_on .and. abs(sel(1) - 2.0_real64) <= 10.0_real64 / w .and. abs(sel(2) - 6.0_real64) <= 10.0_real64 / w &
        .and. abs(sel(3) + 0.5_real64) <= 2.0_real64 / h .and. abs(sel(4) - 0.5_real64) <= 2.0_real64 / h
ok(5) = .not. sel_after .and. abs(lim_c(1)) < 1.0e-9_real64 .and. abs(lim_c(2) - 10.0_real64) < 1.0e-9_real64 .and. &
        abs(lim_c(3) + 1.0_real64) < 1.0e-9_real64 .and. abs(lim_c(4) - 1.0_real64) < 1.0e-9_real64
ok(6) = abs(lim_z(1) - 2.0_real64) <= 10.0_real64 / w .and. abs(lim_z(2) - 6.0_real64) <= 10.0_real64 / w
! 3. the dragged rectangle
ok(7) = r_flag .and. all(abs(r_moved - [5.0_real64, 7.0_real64, 4.0_real64, 6.0_real64]) <= 2.0_real64 * 10.0_real64 / w)
ok(8) = all(abs(r_cross - [4.0_real64, 5.0_real64, 3.0_real64, 4.0_real64]) <= 2.0_real64 * 10.0_real64 / w)
! 4. marks
ok(9) = tag_y_ok .and. tag_auto_ok .and. tag_y2_ok
ok(10) = tag_x_ok
ok(11) = inf_ok
ok(12) = text_ok
! 5. items
ok(13) = hist_ok .and. abs(mc(1) - 4.0_real64) < 1.0e-12_real64
ok(14) = abs(mc(2) - 10.0_real64) < 1.0e-12_real64 .and. abs(mc(3) - 0.4_real64) < 1.0e-12_real64 .and. &
         abs(mc(4) - 3.0_real64) < 1.0e-12_real64 .and. abs(mc(5) - 4.0_real64) < 1.0e-12_real64 .and. &
         abs(mc(6) - 0.4_real64) < 1.0e-12_real64 .and. abs(mc(7) - 4.0_real64) < 1.0e-12_real64 .and. &
         abs(mc(8) - 3.0_real64) < 1.0e-12_real64 ! mc(5): read at its stride, whoever made the copy
ok(15) = abs(mc2(1) - 4.0_real64) < 1.0e-12_real64 .and. abs(mc2(2) - 4.0_real64) < 1.0e-12_real64
ok(16) = stairs_ok .and. stems_ok
! 6. wrong calls
want = [FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, &
        FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, &
        FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK, FIG_ERR_STATE, FIG_ERR_STATE, FIG_ERR_STATE, FIG_ERR_STATE,         &
        FIG_ERR_STATE, FIG_ERR_STATE, FIG_ERR_STATE, FIG_ERR_STATE, FIG_ERR_STATE, FIG_ERR_STATE]
ok(17) = all(st == want) .and.                                                                   &
         index(msg(16), 'ip_plot_hovered: no plot is being declared') == 1 .and.                 &
         index(msg(2), "ip_tag: axis 'y3' is not set up") == 1 .and.                             &
         index(msg(8), 'ip_histogram: bins must be a count above 0') == 1 .and.                  &
         index(msg(10), 'ip_histogram: give both vmin and vmax, or neither') == 1 .and.          &
         index(msg(24), 'ip_drag_line_x: no plot is being declared') == 1

write(output_unit, '(A,2(F9.4))')   'pointer at the centre (x1, y1)  ', m1
write(output_unit, '(A,2(F9.4))')   'pointer at the centre (x1, y2)  ', m2
write(output_unit, '(A,4(F9.2))')   'plot area [pixels]              ', area
write(output_unit, '(A,2(F9.2),A,2(F9.2))') '(5, 0) in pixels                ', c_px, ', centre ', qc
write(output_unit, '(A,2(F9.4))')   'centre in plot units            ', c_pl
write(output_unit, '(A,2(F9.4))')   '(2.5, 0.5) and back             ', trip
write(output_unit, '(A,2(F9.2))')   '(5, 150) on y2 in pixels        ', y2_px
write(output_unit, '(A,4(F9.4))')   'box while held                  ', sel
write(output_unit, '(A,4(F9.4))')   'limits after a cancelled box    ', lim_c
write(output_unit, '(A,4(F9.4))')   'limits after a box (control)    ', lim_z
write(output_unit, '(A,4(F9.4))')   'rectangle moved                 ', r_moved
write(output_unit, '(A,4(F9.4))')   'rectangle, corner crossed       ', r_cross
write(output_unit, '(A,9(F7.3))')   'histogram heights               ', mc
write(output_unit, '(A,2(F7.3))')   '2-D histogram fullest cells     ', mc2
write(output_unit, '(A,I0)')        'copies by FIGURE, strided data  ', copies(2) - copies(1)
do i = 1_int32, NE
   if (st(i) /= want(i)) write(output_unit, '(A,I0,A,I0,A,I0,A)') 'wrong call ', i, ': stat ', st(i), ' (want ', &
                                                                    want(i), ') '//trim(msg(i))
enddo
do i = 1_int32, size(ok, kind=int32)
   write(output_unit, '(A,I2,A,L1)') 'check ', i, ': ', ok(i)
enddo
if (.not. all(ok)) error stop 'figure_test_plot_marks: FAILED'
write(output_unit, '(A)') 'figure_test_plot_marks: all checks passed'

contains
   subroutine measure_area()
   !< The plot area of the plot being declared, from ImPlot's position and size (independent of the conversions).
   type(im_vec2) :: pos !< Top-left corner [pixels].

   call ip_plot_size(w, h)
   pos = ImPlot_GetPlotPos()
   area = [real(pos%x, real64), real(pos%y, real64), real(pos%x, real64) + w, real(pos%y, real64) + h]
   centre = [area(1) + 0.5_real64 * w, area(2) + 0.5_real64 * h]
   endsubroutine measure_area

   subroutine queries(frame)
   !< Phase 1: the pointer at the centre of a plot with fixed limits, then outside the window.
   integer(int32), intent(in) :: frame !< Frame.

   if (ip_begin_plot('queries', width=640.0_real64, height=400.0_real64)) then
      call ip_setup_axis('y2', label='y2')
      call ip_setup_axes_limits(0.0_real64, 10.0_real64, -1.0_real64, 1.0_real64, always=.true.)
      call ip_setup_axis_limits('y2', 100.0_real64, 200.0_real64, always=.true.)
      call ip_line('line', xs, ys)
      call measure_area()
      if (frame == 9_int32) then
         qc = centre
         hov_in = ip_plot_hovered()
         call ip_plot_mouse(m1(1), m1(2))
         call ip_plot_mouse(m2(1), m2(2), yaxis='y2')
         call ip_plot_to_pixels(5.0_real64, 0.0_real64, c_px(1), c_px(2))
         call ip_pixels_to_plot(centre(1), centre(2), c_pl(1), c_pl(2))
         call ip_plot_to_pixels(2.5_real64, 0.5_real64, p0(1), p0(2))
         call ip_pixels_to_plot(p0(1), p0(2), trip(1), trip(2))
         call ip_plot_to_pixels(5.0_real64, 150.0_real64, y2_px(1), y2_px(2), xaxis='x1', yaxis='y2')
      endif
      if (frame == 12_int32) hov_out = ip_plot_hovered()
      call ip_end_plot()
   endif
   if (frame == 3_int32) call test_mouse_move(centre(1), centre(2))
   if (frame == 10_int32) call test_mouse_move(4.0_real64, 4.0_real64) ! outside the window
   endsubroutine queries

   subroutine selection(frame)
   !< Phase 2: a box dragged with the right button, cancelled; then the same box, not cancelled (control).
   integer(int32), intent(in) :: frame !< Frame.
   real(real64)               :: d(4)  !< Unused extent.

   if (ip_begin_plot('selection', width=640.0_real64, height=400.0_real64)) then
      call ip_setup_axes_limits(0.0_real64, 10.0_real64, -1.0_real64, 1.0_real64)
      call ip_line('line', xs, ys)
      if (frame == 14_int32) then
         call ip_plot_to_pixels(2.0_real64, -0.5_real64, p0(1), p0(2))
         call ip_plot_to_pixels(6.0_real64, 0.5_real64, p1(1), p1(2))
      endif
      if (frame == 25_int32) sel_on = ip_plot_selection(sel(1), sel(2), sel(3), sel(4))
      if (frame == 26_int32) call ip_cancel_selection()
      if (frame == 32_int32) then
         call ip_plot_limits(lim_c(1), lim_c(2), lim_c(3), lim_c(4))
         sel_after = ip_plot_selection(d(1), d(2), d(3), d(4))
      endif
      if (frame == 58_int32) call ip_plot_limits(lim_z(1), lim_z(2), lim_z(3), lim_z(4))
      call ip_end_plot()
   endif
   if (frame == 15_int32 .or. frame == 40_int32) then ! press the right button at p0, move to p1, hold
      call test_mouse_move(p0(1), p0(2))
      call test_next_frame()
      call test_next_frame()
      call test_mouse_button(.true., 'right')
      call test_next_frame()
      call test_mouse_move(p1(1), p1(2))
      call test_next_frame()
   endif
   if (frame == 26_int32 .or. frame == 50_int32) call test_mouse_button(.false., 'right')
   endsubroutine selection

   subroutine rectangle(frame)
   !< Phase 3: a rectangle moved by its centre, then resized by a corner past the opposite one.
   integer(int32), intent(in) :: frame !< Frame.
   real(real64)               :: a(2)  !< Drag start [pixels].
   real(real64)               :: b(2)  !< Drag end [pixels].

   if (ip_begin_plot('rectangle', width=640.0_real64, height=400.0_real64)) then
      call ip_setup_axes_limits(0.0_real64, 10.0_real64, 0.0_real64, 10.0_real64, always=.true.)
      call ip_line('line', xs, ys + 5.0_real64)
      if (ip_drag_rect(1_int32, r(1), r(2), r(3), r(4))) r_flag = .true.
      if (frame == 62_int32) then
         call ip_plot_to_pixels(3.0_real64, 3.0_real64, a(1), a(2))
         call ip_plot_to_pixels(6.0_real64, 5.0_real64, b(1), b(2))
         call test_drag(a(1), a(2), b(1), b(2))
      endif
      if (frame == 72_int32) then
         r_moved = r
         call ip_plot_to_pixels(r(2), r(4), a(1), a(2))                    ! the corner (xmax, ymax) ...
         call ip_plot_to_pixels(4.0_real64, 3.0_real64, b(1), b(2))        ! ... past (xmin, ymin)
         call test_drag(a(1), a(2), b(1), b(2))
      endif
      if (frame == 84_int32) r_cross = r
      call ip_end_plot()
   endif
   endsubroutine rectangle

   subroutine marks(measure)
   !< Phase 4: tags, infinite lines and a text in a plot with fixed limits.
   logical, intent(in) :: measure !< Read the extents.

   if (ip_begin_plot('marks', width=640.0_real64, height=400.0_real64)) then
      call ip_setup_axis('y2')
      call ip_setup_axes_limits(0.0_real64, 10.0_real64, 0.0_real64, 10.0_real64, always=.true.)
      call ip_setup_axis_limits('y2', 0.0_real64, 100.0_real64, always=.true.)
      call ip_line('line', xs, ys + 8.0_real64, spec=ip_spec(line_color=LINE_C))
      call ip_tag('y2', 70.0_real64, color=TAG_Y2)                       ! level with y1 = 7, on the right
      call ip_tag('y1', 1.0_real64)                                       ! the last item's colour
      call ip_tag('y1', 7.0_real64, color=TAG_Y)
      call ip_tag('x1', 3.0_real64, color=TAG_X, text='x = 3')
      call ip_inf_lines('vertical', [4.0_real64], spec=ip_spec(line_color=INF_V))
      call ip_inf_lines('horizontal', [2_int32], horizontal=.true., spec=ip_spec(line_color=INF_H))
      call ip_push_style_color('InlayText', TEXT_C)
      call ip_text('note', 5.0_real64, 5.0_real64, offset=[20.0_real64, 0.0_real64])
      call ip_pop_style_color()
      call measure_area()
      call ip_plot_to_pixels(0.0_real64, 0.0_real64, q(1, 1), q(2, 1))
      call ip_plot_to_pixels(10.0_real64, 10.0_real64, q(1, 2), q(2, 2))
      call ip_plot_to_pixels(4.0_real64, 2.0_real64, q(1, 3), q(2, 3))
      call ip_plot_to_pixels(3.0_real64, 7.0_real64, q(1, 4), q(2, 4))
      call ip_plot_to_pixels(5.0_real64, 5.0_real64, q(1, 5), q(2, 5))
      call ip_plot_to_pixels(5.0_real64, 1.0_real64, q(1, 6), q(2, 6))
      if (measure) then
         call test_drawn_extent(INF_V, e(1), e(2), e(3), e(4), found)
         inf_ok = found .and. abs(0.5_real64 * (e(1) + e(3)) - q(1, 3)) <= 1.5_real64 .and. &
                  abs(e(2) - area(2)) <= 1.5_real64 .and. abs(e(4) - area(4)) <= 1.5_real64
         call test_drawn_extent(INF_H, e(1), e(2), e(3), e(4), found)
         inf_ok = inf_ok .and. found .and. abs(0.5_real64 * (e(2) + e(4)) - q(2, 3)) <= 1.5_real64 .and. &
                  abs(e(1) - area(1)) <= 1.5_real64 .and. abs(e(3) - area(3)) <= 1.5_real64
         call test_drawn_extent(TEXT_C, e(1), e(2), e(3), e(4), found)
         text_ok = found .and. abs(0.5_real64 * (e(1) + e(3)) - (q(1, 5) + 20.0_real64)) <= 2.0_real64 .and. &
                   abs(0.5_real64 * (e(2) + e(4)) - q(2, 5)) <= 3.0_real64
      endif
      call ip_end_plot()
   endif
   if (measure) then ! the tags are drawn when the plot ends
      call test_drawn_extent(TAG_Y, e(1), e(2), e(3), e(4), found)
      tag_y_ok = found .and. abs(0.5_real64 * (e(2) + e(4)) - q(2, 4)) <= 2.0_real64 .and. e(3) <= area(1) + 1.0_real64
      call test_drawn_extent(TAG_Y2, e(1), e(2), e(3), e(4), found)
      tag_y2_ok = found .and. abs(0.5_real64 * (e(2) + e(4)) - q(2, 4)) <= 2.0_real64 .and. e(1) >= area(3) - 1.0_real64
      call test_drawn_extent(TAG_X, e(1), e(2), e(3), e(4), found)
      tag_x_ok = found .and. abs(0.5_real64 * (e(1) + e(3)) - q(1, 4)) <= 2.0_real64 .and. e(2) >= area(4) - 1.0_real64
      call test_drawn_extent(LINE_C, e(1), e(2), e(3), e(4), found)
      tag_auto_ok = found .and. e(1) < area(1) - 5.0_real64 .and. e(4) >= q(2, 6) - 1.0_real64 ! the line and its tag
   endif
   endsubroutine marks

   subroutine items(measure)
   !< Phase 5: a histogram and its variants, a 2-D histogram, stairs and stems.
   logical, intent(in) :: measure !< Read the extents.
   real(real64)        :: t(4)    !< Stairs and stems pixels.
   real(real64)        :: u(4)    !< More pixels.

   if (ip_begin_plot('histogram', width=640.0_real64, height=170.0_real64)) then
      call ip_setup_axes_limits(-1.0_real64, 5.0_real64, -1.0_real64, 11.0_real64, always=.true.)
      call ip_histogram('counts', hv, bins=4_int32, vmin=0.0_real64, vmax=4.0_real64, max_count=mc(1), &
                        spec=ip_spec(fill_color=HIST_F, line_color=HIST_L))
      call ip_histogram('cumulative', hv, bins=4_int32, vmin=0.0_real64, vmax=4.0_real64, max_count=mc(2), &
                        spec=ip_spec(flags=ImPlotHistogramFlags_Cumulative))
      call ip_histogram('density', hv, bins=4_int32, vmin=0.0_real64, vmax=4.0_real64, max_count=mc(3), &
                        spec=ip_spec(flags=ImPlotHistogramFlags_Density))
      call ip_histogram('one bin', hv, bins=1_int32, vmin=2.0_real64, vmax=3.0_real64, max_count=mc(4))
      copies(1) = test_plot_copies()
      call ip_histogram('strided', hw(1::2), bins=4_int32, vmin=0.0_real64, vmax=4.0_real64, max_count=mc(5))
      copies(2) = test_plot_copies()
      call ip_histogram('with a NaN', [hv, nan], bins=4_int32, vmin=0.0_real64, vmax=4.0_real64, max_count=mc(6), &
                        spec=ip_spec(flags=ImPlotHistogramFlags_Density))
      call ip_histogram('default bins', hv, max_count=mc(7))
      call ip_histogram('constant', [2.0_real64, 2.0_real64, 2.0_real64], bins=ImPlotBin_Scott, max_count=mc(8))
      if (measure) then
         call ip_plot_to_pixels(0.0_real64, 4.0_real64, hq(1), hq(2))
         call ip_plot_to_pixels(4.0_real64, 0.0_real64, hq(3), hq(4))
         call test_drawn_extent(HIST_F, e(1), e(2), e(3), e(4), found, vertices=nv)
         hist_ok = found .and. all(abs(e - hq) <= 1.5_real64) .and. nv == 16_int32 ! four bars, four corners each
         write(output_unit, '(A,4F8.1,A,I0)') 'histogram fill extent ', e, '; vertices ', nv
      endif
      call ip_end_plot()
   endif
   if (ip_begin_plot('histogram2d', width=640.0_real64, height=170.0_real64)) then
      call ip_histogram2d('in a range', px2, py2, xbins=2_int32, ybins=2_int32, xmin=0.0_real64, xmax=2.0_real64, &
                          ymin=0.0_real64, ymax=2.0_real64, max_count=mc2(1))
      call ip_histogram2d('own range', px2, py2, xbins=2_int32, ybins=2_int32, max_count=mc2(2))
      call ip_end_plot()
   endif
   if (ip_begin_plot('stairs and stems', width=640.0_real64, height=170.0_real64)) then
      call ip_setup_axes_limits(-1.0_real64, 5.0_real64, -1.0_real64, 5.0_real64, always=.true.)
      call ip_stairs('stairs', [0.0_real64, 1.0_real64, 2.0_real64, 3.0_real64], &
                     [1.0_real64, 3.0_real64, 2.0_real64, 2.0_real64], spec=ip_spec(line_color=STAIR_C))
      call ip_stems('stems', [1_int32, 2_int32, 3_int32], [2.0_real64, 4.0_real64, 1.0_real64], ref=0.5_real64, &
                    spec=ip_spec(line_color=STEM_C, marker_line_color=MARK_C, marker_fill_color=MARK_C))
      if (measure) then
         call ip_plot_to_pixels(0.0_real64, 3.0_real64, t(1), t(2))
         call ip_plot_to_pixels(3.0_real64, 1.0_real64, t(3), t(4))
         call test_drawn_extent(STAIR_C, e(1), e(2), e(3), e(4), found)
         stairs_ok = found .and. all(abs(e - t) <= 1.5_real64)
         call ip_plot_to_pixels(1.0_real64, 4.0_real64, u(1), u(2))
         call ip_plot_to_pixels(3.0_real64, 0.5_real64, u(3), u(4))
         call test_drawn_extent(STEM_C, e(1), e(2), e(3), e(4), found)
         stems_ok = found .and. all(abs(e - u) <= 1.5_real64)
         write(output_unit, '(A,4F8.1,A,4F8.1)') 'stems extent ', e, ' expected ', u
      endif
      call ip_end_plot()
   endif
   endsubroutine items

   subroutine wrong_calls()
   !< Phase 6: wrong calls in a plot, each refused with its status.
   real(real64) :: d(4) !< Unused values.
   logical      :: l    !< Unused result.

   d = [1.0_real64, 2.0_real64, 1.0_real64, 2.0_real64]
   if (ip_begin_plot('wrong', width=640.0_real64, height=300.0_real64)) then
      call ip_line('line', xs, ys)
      call ip_tag('z1', 1.0_real64, stat=st(1))
      msg(1) = figure_last_error()
      call ip_tag('y3', 1.0_real64, stat=st(2))
      msg(2) = figure_last_error()
      call ip_tag('y1', 1.0_real64, color=[1.0_real64, 0.0_real64, 0.0_real64], stat=st(3))
      msg(3) = figure_last_error()
      call ip_plot_mouse(d(1), d(2), xaxis='y1', stat=st(4))
      msg(4) = figure_last_error()
      call ip_plot_to_pixels(nan, 0.0_real64, d(1), d(2), stat=st(5))
      msg(5) = figure_last_error()
      call ip_text('t', 1.0_real64, 1.0_real64, offset=[1.0_real64, 2.0_real64, 3.0_real64], stat=st(6))
      msg(6) = figure_last_error()
      d = [1.0_real64, 2.0_real64, nan, 2.0_real64]
      l = ip_drag_rect(1_int32, d(1), d(2), d(3), d(4), stat=st(7))
      msg(7) = figure_last_error()
      call ip_histogram('h', hv, bins=0_int32, stat=st(8))
      msg(8) = figure_last_error()
      call ip_histogram('h', hv, bins=-5_int32, stat=st(9))
      msg(9) = figure_last_error()
      call ip_histogram('h', hv, vmin=1.0_real64, stat=st(10))
      msg(10) = figure_last_error()
      call ip_histogram('h', hv, vmin=2.0_real64, vmax=1.0_real64, stat=st(11))
      msg(11) = figure_last_error()
      call ip_histogram2d('h', px2(1:3), py2(1:2), stat=st(12))
      msg(12) = figure_last_error()
      call ip_stairs('s', xs(1:3), ys(1:2), stat=st(13))
      msg(13) = figure_last_error()
      l = ip_plot_selection(d(1), d(2), d(3), d(4), yaxis='y2', stat=st(14))
      msg(14) = figure_last_error()
      call ip_inf_lines('i', [1.0_real64], stat=st(15))
      msg(15) = figure_last_error()
      call ip_end_plot()
   endif
   endsubroutine wrong_calls

   subroutine outside_plot()
   !< Phase 6: the calls of a plot made in a window, outside any plot.
   real(real64) :: d(4) !< Unused values.
   logical      :: l    !< Unused result.

   d = [1.0_real64, 2.0_real64, 1.0_real64, 2.0_real64]
   l = ip_plot_hovered(stat=st(16))
   msg(16) = figure_last_error()
   call ip_plot_mouse(d(1), d(2), stat=st(17))
   msg(17) = figure_last_error()
   call ip_cancel_selection(stat=st(18))
   msg(18) = figure_last_error()
   call ip_tag('y1', 1.0_real64, stat=st(19))
   msg(19) = figure_last_error()
   call ip_inf_lines('i', [1.0_real64], stat=st(20))
   msg(20) = figure_last_error()
   call ip_text('t', 1.0_real64, 1.0_real64, stat=st(21))
   msg(21) = figure_last_error()
   l = ip_drag_rect(1_int32, d(1), d(2), d(3), d(4), stat=st(22))
   msg(22) = figure_last_error()
   call ip_histogram('h', hv, stat=st(23))
   msg(23) = figure_last_error()
   l = ip_drag_line_x(1_int32, d(1), stat=st(24))
   msg(24) = figure_last_error()
   call ip_stems('s', xs(1:2), ys(1:2), stat=st(25))
   msg(25) = figure_last_error()
   endsubroutine outside_plot
endprogram figure_test_plot_marks
