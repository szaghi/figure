!< figure_test_plot_frame_labels, the Fortran plot frame's titles, axis labels, extra axes and legend, as ImPlot's.
program figure_test_plot_frame_labels
!< figure_test_plot_frame_labels, the Fortran plot frame's titles, axis labels, extra axes and legend, as ImPlot's.
!<
!< szaghi/figure#15 P10, steps 3 (title, axis labels, the axes X2, X3, Y2, Y3) and 4 (the legend). Each case is a few
!< frames of a plot drawn twice in one headless window, at the same place: first by ImPlot through FIGURE's API
!< (`ip_begin_plot`, `ip_setup_axes`, `ip_setup_axis`, `ip_setup_axes_limits`, `ip_setup_axis_limits`,
!< `ip_setup_legend`, `ip_set_axes`, `ip_hide_next_item`, `ip_line`, `ip_legend_hovered`, `ip_plot_limits`,
!< `ip_end_plot`), then by the Fortran frame (`pf_*`) on as many frames, with the same synthetic pointer moves and
!< clicks (figure_testing); the same plot IDs on both sides, one per case. Checked: the ranges of two axis pairs on
!< every frame (equal to the bit), `ip_legend_hovered` against `pf_legend_hovered` on every frame, and the picture of
!< the last frame (at FIGURE's oracle rule: |d| <= 2 on every channel, no pixel failing). The lines have given
!< colours (FIGURE's style seal: its automatic colours are its own colormap, not the frame's yet). The cases:
!<
!< 1. a title; 2. a title with a hidden part (`##`); 3. x and y labels (the y label with a non-ASCII character, drawn
!< glyph by glyph); 4. a y label longer than the plot is tall; 5. a second y axis (right) with its label, its own line
!< (`ip_set_axes`) and range fit to it; 6. a second x axis (top, inverted) and a third y axis on the left, labelled,
!< each with a line; 7. the legend of three lines, one without a legend entry (`##`), at its default place (north-west,
!< inside); 8. the legend south-east, horizontal; 9. outside, east (the plot area shrinks from the second frame, as in
!< ImPlot); 10. outside, north, horizontal; 11. clicks on legend entries (north-east, inside): an item hidden by
!< `hide_next_item` on its first frame, a click hides another and a click shows it again; 12. the pointer resting on
!< the legend entry (outside, east) of a line on the second y axis: the entry highlighted, the line twice as thick, the
!< axis highlighted in its colour, `legend_hovered` true.
!<
!< The pictures are `figure_test_plot_frame_labels.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them; a
!< mismatch's .new.png and .diff.png are left for inspection).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ImGuiWindowFlags_NoDecoration
use figure_implot_ref, only : ip_begin_plot, ip_end_plot, ip_hide_next_item, ip_legend_hovered, ip_line, &
                              ip_plot_limits, ip_set_axes, ip_setup_axes, ip_setup_axes_limits, ip_setup_axis, &
                              ip_setup_axis_limits, ip_setup_legend, ip_spec
use figure_core, only : core_cursor_screen_pos, core_font_size, core_text_size
use figure_plot_frame, only : pf_begin_plot, pf_end_plot, pf_hide_next_item, pf_legend_hovered,       &
                              pf_plot_limits, pf_set_axes, pf_setup_axes, pf_setup_axes_limits, pf_setup_axis, &
                              pf_setup_axis_limits, pf_setup_legend
use figure_plot_items, only : pf_line, pf_spec
use figure_testing, only : test_capture, test_click, test_compare_image, test_mouse_move

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 440_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 12_int32   !< Cases.
integer(int32), parameter :: NFMAX = 16_int32   !< Frames per side of a case at most.
integer(int32), parameter :: NP = 101_int32     !< Points of a line.
real(real64),   parameter :: C1(4) = [0.91_real64, 0.40_real64, 0.30_real64, 1.0_real64] !< A colour.
real(real64),   parameter :: C2(4) = [0.30_real64, 0.62_real64, 0.85_real64, 1.0_real64] !< Another.
real(real64),   parameter :: C3(4) = [0.55_real64, 0.75_real64, 0.35_real64, 1.0_real64] !< A third.
type(app_object)          :: app                !< Application.
real(real64)              :: xs(NP), ys(NP, 4)  !< The lines: abscissae, ordinates.
real(real64)              :: lims(4, 2, NFMAX, 2) !< Ranges drawn: (xmin, xmax, ymin, ymax), pair, frame, side.
logical                   :: hov(NFMAX, 2)      !< `legend_hovered` of the case's item, per frame and side.
real(real64)              :: origin(2)          !< The plot frame's top-left corner [pixels].
logical                   :: test_passed(NCASE) !< Per-case outcome.
logical                   :: side_fortran       !< Drawing with the Fortran frame.
integer(int32)            :: c, f, s, sd, i     !< Case, frame, status, side, counter.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do i = 1_int32, NP
   xs(i) = real(i - 1_int32, real64) * 0.1_real64
   ys(i, 1) = sin(xs(i))
   ys(i, 2) = 0.8_real64 * cos(xs(i))
   ys(i, 3) = 0.5_real64 * sin(2.0_real64 * xs(i))
   ys(i, 4) = 50.0_real64 + 30.0_real64 * sin(0.5_real64 * xs(i))
enddo
do c = 1_int32, NCASE
   lims = 0.0_real64
   hov = .false.
   do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
      side_fortran = sd == 2_int32
      do f = 1_int32, nframes(c)
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_labels: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame labels', flags=ImGuiWindowFlags_NoDecoration)) then
            call core_cursor_screen_pos(origin(1), origin(2))
            call draw_case(c, f)
            call pointer(c, f)
         endif
         call ig_end()
         if (f == nframes(c)) call test_capture(picture(c, side_fortran), s)
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      if (.not. app%next_frame()) error stop 'figure_test_plot_frame_labels: next_frame returned false headless'
   enddo
   test_passed(c) = state_equal(c) .and. pictures_equal(c)
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_labels checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   pure function nframes(k) result(n)
   !< A case's frames per side.
   integer(int32), intent(in) :: k !< Case.
   integer(int32)             :: n !< Frames.

   select case (k)
   case (11_int32)
      n = 16_int32
   case (12_int32)
      n = 9_int32
   case default
      n = 3_int32
   endselect
   endfunction nframes

   subroutine draw_case(k, fr)
   !< A case's plot on a frame, by the side drawing.
   integer(int32), intent(in) :: k  !< Case.
   integer(int32), intent(in) :: fr !< Frame.

   select case (k)
   case (1_int32, 2_int32)
      if (begin(merge('Pressure (kPa)         ', 'Shown part##hidden part', k == 1_int32))) then
         call limits(.true.)
         call line('##sine', 1_int32, C1)
         call finish(fr)
      endif
   case (3_int32, 4_int32)
      if (begin(plot_id(k))) then
         if (k == 3_int32) then
            call axes('time [s]', 'temperature (°C)')
         else
            call axes('x', 'a deliberately long label for the vertical axis, longer than the plot is tall')
         endif
         call limits(.true.)
         call line('##sine', 1_int32, C1)
         call finish(fr)
      endif
   case (5_int32)
      if (begin(plot_id(k))) then
         call axis('y2', 'speed [m/s]')
         call limits(.true.)
         call line('##sine', 1_int32, C1)
         call set_axes('x1', 'y2')
         call line('##speed', 4_int32, C2)
         call finish(fr)
      endif
   case (6_int32)
      if (begin(plot_id(k))) then
         call axis('x2', 'x2 (inverted)', invert=.true.)
         call axis('y3', 'y3 left', opposite=.false.)
         call limits(.true.)
         call axis_limits('x2', 0.0_real64, 5.0_real64)
         call axis_limits('y3', -2.0_real64, 2.0_real64)
         call line('##sine', 1_int32, C1)
         call set_axes('x2', 'y3')
         call line('##cosine', 2_int32, C2)
         call finish(fr)
      endif
   case (7_int32, 8_int32, 9_int32, 10_int32)
      if (begin(plot_id(k))) then
         select case (k)
         case (8_int32)
            call legend_at('se', .false., .true.)
         case (9_int32)
            call legend_at('e', .true., .false.)
         case (10_int32)
            call legend_at('n', .true., .true.)
         case default
         endselect
         call limits(.true.)
         call line('sine', 1_int32, C1)
         call line('cosine##c', 2_int32, C2)
         call line('##no entry', 3_int32, C3)
         call finish(fr)
      endif
   case (11_int32)
      if (begin(plot_id(k))) then
         call legend_at('ne', .false., .false.)
         call limits(.true.)
         call line('a', 1_int32, C1)
         call line('b', 2_int32, C2)
         call hide_next()
         call line('c', 3_int32, C3)
         call finish(fr)
      endif
   case default
      if (begin(plot_id(k))) then
         call legend_at('e', .true., .false.)
         call axis('y2', 'speed')
         call limits(.true.)
         call axis_limits('y2', 0.0_real64, 100.0_real64)
         call line('sine', 1_int32, C1)
         call set_axes('x1', 'y2')
         call line('speed', 4_int32, C2)
         hov(fr, merge(2_int32, 1_int32, side_fortran)) = legend_hovered('speed')
         call finish(fr)
      endif
   endselect
   endsubroutine draw_case

   subroutine pointer(k, fr)
   !< A case's pointer moves and clicks on a frame (the same on both sides).
   integer(int32), intent(in) :: k  !< Case.
   integer(int32), intent(in) :: fr !< Frame.

   select case (k)
   case (11_int32) ! legend north-east inside: click b (hide it), then c (show it)
      if (fr == 3_int32) call entry_click(2_int32)
      if (fr == 8_int32) call entry_click(3_int32)
      if (fr == 13_int32) call test_mouse_move(-100.0_real64, -100.0_real64)
   case (12_int32) ! legend outside east: rest on the second entry
      if (fr == 3_int32) call test_mouse_move(entry_x_outside(), entry_y_outside(2_int32))
   case default
   endselect
   endsubroutine pointer

   subroutine entry_click(e)
   !< Click the e-th entry of case 11's legend (north-east inside the plot area, no title, no right axis).
   integer(int32), intent(in) :: e   !< Entry.
   real(real64)                :: t   !< Text height.
   real(real64)                :: lw  !< The legend's width.
   real(real64)                :: lx, ly !< Its top-left corner.
   real(real64)                :: ww, hh !< A label's size.

   t = core_font_size()
   call core_text_size('a', ww, hh)
   lw = ww
   call core_text_size('b', ww, hh)
   lw = max(lw, ww)
   call core_text_size('c', ww, hh)
   lw = max(lw, ww)
   lw = 10.0_real64 + t + lw
   lx = real(nint(origin(1) + 600.0_real64 - 10.0_real64 - 10.0_real64 - lw), real64)
   ly = origin(2) + 10.0_real64 + 10.0_real64
   call test_click(lx + 5.0_real64 + 0.5_real64 * t, ly + 5.0_real64 + (real(e, real64) - 0.5_real64) * t)
   endsubroutine entry_click

   function entry_x_outside() result(x)
   !< The middle of an entry's icon in case 12's legend (outside, east, labels 'sine' and 'speed').
   real(real64) :: x      !< Abscissa [pixels].
   real(real64) :: t, lw  !< Text height, the legend's width.
   real(real64) :: ww, hh !< A label's size.

   t = core_font_size()
   call core_text_size('sine', ww, hh)
   lw = ww
   call core_text_size('speed', ww, hh)
   lw = 10.0_real64 + t + max(lw, ww)
   x = real(nint(origin(1) + 600.0_real64 - 10.0_real64 - lw), real64) + 5.0_real64 + 0.5_real64 * t
   endfunction entry_x_outside

   function entry_y_outside(e) result(y)
   !< The middle of the e-th entry of case 12's legend.
   integer(int32), intent(in) :: e !< Entry.
   real(real64)               :: y !< Ordinate [pixels].
   real(real64)               :: t, lh !< Text height, the legend's height.

   t = core_font_size()
   lh = 10.0_real64 + 2.0_real64 * t
   y = real(nint(origin(2) + 200.0_real64 - 0.5_real64 * lh), real64) + 5.0_real64 + (real(e, real64) - 0.5_real64) * t
   endfunction entry_y_outside

   function begin(id) result(visible)
   !< `ip_begin_plot` or `pf_begin_plot`, 600 x 400.
   character(len=*), intent(in) :: id      !< Plot's title and ID.
   logical                      :: visible !< Plot visible.

   if (side_fortran) then
      visible = pf_begin_plot(trim(id), width=600.0_real64, height=400.0_real64)
   else
      visible = ip_begin_plot(trim(id), width=600.0_real64, height=400.0_real64)
   endif
   endfunction begin

   subroutine axes(xlabel, ylabel)
   !< `ip_setup_axes` or `pf_setup_axes`.
   character(len=*), intent(in) :: xlabel, ylabel !< Labels.

   if (side_fortran) then
      call pf_setup_axes(xlabel, ylabel)
   else
      call ip_setup_axes(xlabel, ylabel)
   endif
   endsubroutine axes

   subroutine axis(name, label, opposite, invert)
   !< `ip_setup_axis` or `pf_setup_axis`.
   character(len=*), intent(in)           :: name     !< Axis.
   character(len=*), intent(in)           :: label    !< Label.
   logical,          intent(in), optional :: opposite !< Opposite side.
   logical,          intent(in), optional :: invert   !< Inverted.

   if (side_fortran) then
      call pf_setup_axis(name, label=label, opposite=opposite, invert=invert)
   else
      call ip_setup_axis(name, label=label, opposite=opposite, invert=invert)
   endif
   endsubroutine axis

   subroutine limits(always)
   !< X1 and Y1 on [0, 10] x [-1.2, 1.2] (`ip_setup_axes_limits` or `pf_setup_axes_limits`).
   logical, intent(in) :: always !< Every frame.

   if (side_fortran) then
      call pf_setup_axes_limits(0.0_real64, 10.0_real64, -1.2_real64, 1.2_real64, always=always)
   else
      call ip_setup_axes_limits(0.0_real64, 10.0_real64, -1.2_real64, 1.2_real64, always=always)
   endif
   endsubroutine limits

   subroutine axis_limits(name, vmin, vmax)
   !< An axis's range, every frame (`ip_setup_axis_limits` or `pf_setup_axis_limits`).
   character(len=*), intent(in) :: name       !< Axis.
   real(real64),     intent(in) :: vmin, vmax !< Range.

   if (side_fortran) then
      call pf_setup_axis_limits(name, vmin, vmax, always=.true.)
   else
      call ip_setup_axis_limits(name, vmin, vmax, always=.true.)
   endif
   endsubroutine axis_limits

   subroutine legend_at(location, outside, horizontal)
   !< `ip_setup_legend` or `pf_setup_legend`.
   character(len=*), intent(in) :: location           !< Compass point.
   logical,          intent(in) :: outside, horizontal !< Outside, in a row.

   if (side_fortran) then
      call pf_setup_legend(location, outside=outside, horizontal=horizontal)
   else
      call ip_setup_legend(location, outside=outside, horizontal=horizontal)
   endif
   endsubroutine legend_at

   subroutine set_axes(x, y)
   !< `ip_set_axes` or `pf_set_axes`.
   character(len=*), intent(in) :: x, y !< Axes.

   if (side_fortran) then
      call pf_set_axes(x, y)
   else
      call ip_set_axes(x, y)
   endif
   endsubroutine set_axes

   subroutine hide_next()
   !< `ip_hide_next_item` or `pf_hide_next_item` (hidden, its first frame only).

   if (side_fortran) then
      call pf_hide_next_item()
   else
      call ip_hide_next_item()
   endif
   endsubroutine hide_next

   function legend_hovered(label) result(yes)
   !< `ip_legend_hovered` or `pf_legend_hovered`.
   character(len=*), intent(in) :: label !< Item's label.
   logical                      :: yes   !< Hovered.

   if (side_fortran) then
      yes = pf_legend_hovered(label)
   else
      yes = ip_legend_hovered(label)
   endif
   endfunction legend_hovered

   subroutine line(label, j, col)
   !< `ip_line` or `pf_line` of the j-th line, of the colour `col`.
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
   !< The ranges of the pairs X1-Y1 and the current axes on the frame fr kept, and the plot ended.
   integer(int32), intent(in) :: fr !< Frame.
   integer(int32)             :: m  !< Side.

   m = merge(2_int32, 1_int32, side_fortran)
   if (side_fortran) then
      call pf_plot_limits(lims(1, 1, fr, m), lims(2, 1, fr, m), lims(3, 1, fr, m), lims(4, 1, fr, m), 'x1', 'y1')
      call pf_plot_limits(lims(1, 2, fr, m), lims(2, 2, fr, m), lims(3, 2, fr, m), lims(4, 2, fr, m))
      call pf_end_plot()
   else
      call ip_plot_limits(lims(1, 1, fr, m), lims(2, 1, fr, m), lims(3, 1, fr, m), lims(4, 1, fr, m), 'x1', 'y1')
      call ip_plot_limits(lims(1, 2, fr, m), lims(2, 2, fr, m), lims(3, 2, fr, m), lims(4, 2, fr, m))
      call ip_end_plot()
   endif
   endsubroutine finish

   function state_equal(k) result(ok)
   !< The ranges and `legend_hovered` of both sides equal on every frame.
   integer(int32), intent(in) :: k     !< Case.
   logical                    :: ok    !< Equal.
   integer(int32)             :: j, fr !< Pair, frame.

   ok = .true.
   do fr = 1_int32, nframes(k)
      do j = 1_int32, 2_int32
         if (all(lims(:, j, fr, 1) == lims(:, j, fr, 2))) cycle
         ok = .false.
         write(output_unit, '(A,I0,A,I0,A,I0,A,4ES24.16)') 'case ', k, ', pair ', j, ', frame ', fr, ': ImPlot ', &
                                                           lims(:, j, fr, 1)
         write(output_unit, '(A,4ES24.16)') '                        frame  ', lims(:, j, fr, 2)
      enddo
      if (hov(fr, 1) .neqv. hov(fr, 2)) then
         ok = .false.
         write(output_unit, '(A,I0,A,I0,A,2L2)') 'case ', k, ', frame ', fr, ': legend_hovered ImPlot, frame', &
                                                 hov(fr, :)
      endif
   enddo
   if (k == 12_int32 .and. .not. hov(nframes(k), 1)) then
      ok = .false.
      write(output_unit, '(A)') 'case 12: the entry is not hovered on the last frame (the pointer missed it)'
   endif
   endfunction state_equal

   function pictures_equal(k) result(ok)
   !< The last pictures of both sides equal at the oracle's rule.
   integer(int32), intent(in) :: k   !< Case.
   logical                    :: ok  !< Equal.
   integer(int64)             :: nf_ !< Pixels that failed.
   integer(int32)             :: st  !< Status.

   ok = test_compare_image(picture(k, .true.), picture(k, .false.), threshold=2_int32, max_failed=0_int32, &
                           failed=nf_, stat=st)
   if (.not. ok) write(output_unit, '(A,I0,A,I0,A,A)') 'case ', k, ': ', nf_, ' pixels failed: ', figure_last_error()
   endfunction pictures_equal

   function plot_id(k) result(id)
   !< A case's plot ID.
   integer(int32), intent(in)    :: k   !< Case.
   character(len=:), allocatable :: id  !< ID.
   character(len=8)              :: tag !< The case's number.

   write(tag, '(I0)') k
   id = '##l'//trim(tag)
   endfunction plot_id

   function picture(k, fortran) result(name)
   !< A case's picture: ImPlot's or the Fortran frame's.
   integer(int32), intent(in)    :: k       !< Case.
   logical,        intent(in)    :: fortran !< The Fortran frame's.
   character(len=:), allocatable :: name    !< File name.
   character(len=8)              :: tag     !< The case's number.

   write(tag, '(I0)') k
   if (fortran) then
      name = 'figure_test_plot_frame_labels.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_labels.'//trim(tag)//'.implot.png.tmp'
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
endprogram figure_test_plot_frame_labels
