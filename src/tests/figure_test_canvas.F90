!< figure_test_canvas, the canvas and the drawing primitives driven by synthetic input, headless.
program figure_test_canvas
!< figure_test_canvas, the canvas and the drawing primitives driven by synthetic input, headless.
!<
!< Every primitive drawn on a canvas is found by `test_drawn_extent` in its colour, where it was drawn (the canvas's
!< origin plus the canvas coordinates); a foreground and a background rectangle are found on their layers, not in
!< the window. The canvas starts where `ig_cursor_screen_pos` said. A left drag of (60, 30) pixels inside the canvas
!< gives that drag while held and on its release, and its press is a click; a right click and a left double click
!< are seen per button, shift as a modifier; the pointer is given in the canvas's pixels. The wheel over a canvas in
!< a scrolling child is the canvas's (the child does not scroll); beside it, the child scrolls. A polyline from
!< (0, 0) to (1, 1) in plot units spans the plot area when x goes to 1 and half of it when x goes to 2. An invisible
!< button is clicked. Wrong arguments are refused with their messages; no frame has a usage error.
use, intrinsic :: ieee_arithmetic, only : ieee_quiet_nan, ieee_value
use, intrinsic :: iso_fortran_env, only : int8, int32, real64, output_unit
use figure, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK, app_object, canvas_event_object, figure_last_error, &
                   ig_begin, ig_begin_child, ig_canvas, ig_cursor_screen_pos, ig_draw_circle, ig_draw_image,      &
                   ig_draw_line, ig_draw_polygon, ig_draw_polyline, ig_draw_rect, ig_draw_text, ig_dummy, ig_end,  &
                   ig_end_child, ig_get_scroll, ig_invisible_button, ig_item_rect, ig_set_next_window,             &
                   ip_begin_plot, ip_end_plot, ip_setup_axes_limits, texture_object
use figure_testing, only : test_click, test_drag, test_drawn_extent, test_key, test_mouse_button, test_mouse_move, &
                           test_next_frame, test_wheel

implicit none
integer(int32), parameter :: NP = 13_int32                         !< Primitives measured.
character(len=10), parameter :: NAMES(NP) = [character(len=10) :: 'line', 'rect', 'rect fill', 'circle', 'polyline', &
                                             'polygon', 'text', 'image', 'foreground', 'background', 'thick', &
                                             'closed', 'open'] !< Their names.
real(real64),   parameter :: TOL = 2.0_real64                      !< Tolerance of an extent [pixels].
type(app_object)          :: app                                   !< Application.
type(canvas_event_object) :: ev                                    !< The canvas's event.
type(canvas_event_object) :: ev2                                   !< The canvas in the child.
type(texture_object)      :: tex                                   !< A small texture.
integer(int8)             :: px(4, 2, 2)                           !< Its pixels.
logical                   :: ok(16)                                !< Per-check outcome.
real(real64)              :: col(4, NP)                            !< The primitives' colours.
real(real64)              :: ext(4, NP)                            !< Their drawn extents [pixels].
real(real64)              :: want(4, NP)                           !< ... expected, from the canvas's origin.
logical                   :: found(NP)                             !< Found in their colours.
integer(int32)            :: nv(NP)                                !< Their vertices in their colours.
logical                   :: in_window(2)                          !< Foreground, background found in the window.
real(real64)              :: cursor(2)                             !< ig_cursor_screen_pos before the canvas.
real(real64)              :: origin(2)                             !< The canvas's origin.
real(real64)              :: csize(2)                              !< Its size.
real(real64)              :: drag_held(2)                          !< The drag while the button was held.
real(real64)              :: drag_released(2)                      !< ... on its release.
integer(int32)            :: presses                               !< Frames with a left click.
integer(int32)            :: releases                              !< Frames with a left release.
integer(int32)            :: right_clicks                          !< Frames with a right click.
integer(int32)            :: double_clicks                         !< Frames with a left double click.
logical                   :: shift_seen                            !< Shift held at a click.
real(real64)              :: mouse_at(2)                           !< The pointer, in canvas pixels, while hovered.
real(real64)              :: wheel_sum                             !< Wheel steps seen by the child's canvas.
real(real64)              :: rect2(4)                              !< The child's canvas on the screen.
real(real64)              :: s0, s1, s2                            !< The child's scroll.
real(real64)              :: smax                                  !< Its largest scroll.
real(real64)              :: plot_ext(4, 2)                        !< The plot polyline's extent, x up to 1 and 2.
logical                   :: plot_found(2)                         !< ... found.
real(real64)              :: hot(4)                                !< The invisible button.
integer(int32)            :: hot_clicks                            !< Its clicks.
real(real64)              :: xmax                                  !< The plot's x range's end.
integer(int32)            :: f                                     !< Frame.
integer(int32)            :: i                                     !< Counter.
integer(int32)            :: st                                    !< Status of a frame.
integer(int32)            :: errors                                !< Frames with a usage error.
integer(int32)            :: bad(11)                               !< Statuses of refused calls.
character(len=160)        :: msg(11)                               !< Their messages.

col(:, 1) = [1.0_real64, 0.0_real64, 0.0_real64, 1.0_real64]
col(:, 2) = [0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64]
col(:, 3) = [0.0_real64, 0.0_real64, 1.0_real64, 1.0_real64]
col(:, 4) = [1.0_real64, 1.0_real64, 0.0_real64, 1.0_real64]
col(:, 5) = [1.0_real64, 0.0_real64, 1.0_real64, 1.0_real64]
col(:, 6) = [0.0_real64, 1.0_real64, 1.0_real64, 1.0_real64]
col(:, 7) = [1.0_real64, 0.5_real64, 0.0_real64, 1.0_real64]
col(:, 8) = [0.5_real64, 0.0_real64, 1.0_real64, 1.0_real64]
col(:, 9) = [0.0_real64, 0.5_real64, 0.25_real64, 1.0_real64]
col(:, 10) = [0.25_real64, 0.0_real64, 0.5_real64, 1.0_real64]
col(:, 11) = [0.5_real64, 0.5_real64, 0.0_real64, 1.0_real64]
col(:, 12) = [0.0_real64, 0.25_real64, 0.5_real64, 1.0_real64]
col(:, 13) = [0.5_real64, 0.25_real64, 0.0_real64, 1.0_real64]
! where each is drawn, from the canvas's origin: xmin, ymin, xmax, ymax [pixels]
want(:, 1) = [10.0_real64, 10.0_real64, 110.0_real64, 60.0_real64]   ! line
want(:, 2) = [120.0_real64, 10.0_real64, 180.0_real64, 50.0_real64]  ! rect outline
want(:, 3) = [190.0_real64, 10.0_real64, 250.0_real64, 50.0_real64]  ! rect filled
want(:, 4) = [20.0_real64, 80.0_real64, 60.0_real64, 120.0_real64]   ! circle, centre (40, 100), radius 20
want(:, 5) = [80.0_real64, 80.0_real64, 160.0_real64, 120.0_real64]  ! polyline
want(:, 6) = [170.0_real64, 80.0_real64, 250.0_real64, 140.0_real64] ! polygon filled
want(:, 7) = [10.0_real64, 150.0_real64, -1.0_real64, -1.0_real64]   ! text: its top-left only
want(:, 8) = [200.0_real64, 150.0_real64, 240.0_real64, 190.0_real64] ! image
want(:, 9) = [260.0_real64, 10.0_real64, 290.0_real64, 40.0_real64]  ! foreground
want(:, 10) = [260.0_real64, 60.0_real64, 290.0_real64, 90.0_real64] ! background
want(:, 11) = [10.0_real64, 185.0_real64, 110.0_real64, 195.0_real64] ! a line 10 pixels thick
want(:, 12) = [320.0_real64, 10.0_real64, 380.0_real64, 70.0_real64] ! a closed polyline 10 thick: its xmin checked
want(:, 13) = [320.0_real64, 90.0_real64, 380.0_real64, 150.0_real64] ! ... the same open
px = 127_int8
ext = 0.0_real64
found = .false.
nv = 0_int32
in_window = .true.
cursor = -1.0_real64
origin = -2.0_real64
csize = 0.0_real64
drag_held = 0.0_real64
drag_released = 0.0_real64
presses = 0_int32
releases = 0_int32
right_clicks = 0_int32
double_clicks = 0_int32
shift_seen = .false.
mouse_at = -1.0_real64
wheel_sum = 0.0_real64
rect2 = 0.0_real64
s0 = -1.0_real64
s1 = -2.0_real64
s2 = -3.0_real64
plot_ext = 0.0_real64
plot_found = .false.
hot = 0.0_real64
hot_clicks = 0_int32
errors = 0_int32
bad = -1_int32
msg = ''
call app%init_headless(1000_int32, 760_int32)
call tex%init(2_int32, 2_int32)
call tex%update(px)
do f = 1_int32, 160_int32
   if (.not. app%next_frame(st)) exit
   if (st /= FIG_OK) errors = errors + 1_int32
   call ig_set_next_window(10.0_real64, 10.0_real64, 600.0_real64, 740.0_real64, always=.true.)
   if (ig_begin('Canvas')) then
      call ig_cursor_screen_pos(cursor(1), cursor(2))
      call ig_canvas('area', 300.0_real64, 200.0_real64, ev)
      origin = ev%origin
      csize = ev%size
      call events()
      call primitives(f == 3_int32)
      if (ig_invisible_button('hot', 80.0_real64, 30.0_real64)) hot_clicks = hot_clicks + 1_int32
      call ig_item_rect(hot(1), hot(2), hot(3), hot(4))
      xmax = merge(1.0_real64, 2.0_real64, f < 40_int32)
      if (ip_begin_plot('##plot', 300.0_real64, 220.0_real64)) then
         call ip_setup_axes_limits(0.0_real64, xmax, 0.0_real64, 1.0_real64, always=.true.)
         call ig_draw_polyline([0.0_real64, 1.0_real64], [0.0_real64, 1.0_real64], col(:, 1) * 0.5_real64 + 0.25_real64, &
                               thickness=1.0_real64, layer='plot')
         call ip_end_plot()
      endif
      if (f == 30_int32 .or. f == 50_int32) then
         i = merge(1_int32, 2_int32, f == 30_int32)
         call test_drawn_extent(col(:, 1) * 0.5_real64 + 0.25_real64, plot_ext(1, i), plot_ext(2, i), plot_ext(3, i), &
                                plot_ext(4, i), found=plot_found(i))
      endif
      if (f == 140_int32) call refused_calls()
   endif
   call ig_end()
   call ig_set_next_window(620.0_real64, 10.0_real64, 300.0_real64, 300.0_real64, always=.true.)
   if (ig_begin('Scroller')) then
      if (ig_begin_child('child', 280.0_real64, 250.0_real64)) then
         call ig_canvas('wheel', 200.0_real64, 100.0_real64, ev2)
         call ig_item_rect(rect2(1), rect2(2), rect2(3), rect2(4))
         wheel_sum = wheel_sum + ev2%wheel
         call ig_dummy(10.0_real64, 800.0_real64)
         call ig_get_scroll(s2, smax)
      endif
      call ig_end_child()
   endif
   call ig_end()
   call script(f)
enddo
if (app%next_frame(st)) continue
if (st /= FIG_OK) errors = errors + 1_int32
call tex%destroy()
call app%destroy()

ok(1) = all(found) .and. nv(3) == 4_int32 .and. nv(6) == 3_int32 .and. nv(2) > 4_int32 ! filled: a vertex per corner
ok(2) = extents_ok()                                                   ! ... where it was drawn
ok(3) = .not. any(in_window)                                           ! foreground, background: not in the window
ok(4) = all(abs(cursor - origin) < 1.0e-9_real64) .and. all(abs(csize - [300.0_real64, 200.0_real64]) < 1.0e-9_real64)
ok(5) = all(abs(drag_held - [60.0_real64, 30.0_real64]) < 1.0e-6_real64)  ! the drag while held
ok(6) = all(abs(drag_released - [60.0_real64, 30.0_real64]) < 1.0e-6_real64) ! ... and on its release
ok(7) = presses == 3_int32 .and. releases == 3_int32                   ! drag, double click: one press, one release each
ok(8) = right_clicks == 1_int32 .and. double_clicks == 1_int32 .and. shift_seen
ok(9) = all(abs(mouse_at - [150.0_real64, 100.0_real64]) < 1.0e-6_real64) ! the pointer in canvas pixels
ok(10) = abs(wheel_sum + 2.0_real64) < 1.0e-9_real64 .and. s1 == s0 .and. s0 == 0.0_real64 ! over the canvas: not scrolled
ok(11) = s2 > s1 .and. smax > 0.0_real64                               ! ... beside it: scrolled
ok(12) = all(plot_found) .and. abs((plot_ext(3, 2) - plot_ext(1, 2)) / (plot_ext(3, 1) - plot_ext(1, 1)) - &
         0.5_real64) < 0.02_real64 .and. abs(plot_ext(1, 1) - plot_ext(1, 2)) < 1.0_real64 .and.             &
         abs((plot_ext(4, 1) - plot_ext(2, 1)) - (plot_ext(4, 2) - plot_ext(2, 2))) < 1.0_real64 ! moves with the limits
ok(13) = hot_clicks == 1_int32                                         ! the invisible button
ok(14) = all(bad([1, 2, 3, 4, 5, 6, 7, 8, 9, 11]) == int(FIG_ERR_ARGUMENT, int32)) .and. bad(10) == int(FIG_ERR_STATE, int32)
ok(15) = msg(1) == "ig_draw_line: unknown layer 'top' ('window', 'foreground', 'background' or 'plot')" .and. &
         msg(2) == 'ig_draw_rect: color has 3 or 4 components' .and.                                       &
         msg(3) == 'ig_draw_polyline: x has 3 points, y 2' .and.                                           &
         msg(4) == 'ig_draw_polygon: 2 points, at least 3 needed' .and.                                    &
         msg(5) == 'ig_draw_line: x must be finite and within single precision' .and.                      &
         msg(6) == 'ig_draw_line: thickness is not a finite length above 0' .and.                          &
         msg(7) == 'ig_draw_circle: radius is not a finite length >= 0' .and.                              &
         msg(8) == 'ig_draw_image: the texture is not initialized' .and.                                   &
         msg(9) == 'ig_canvas: width and height must be finite and within single precision' .and.          &
         msg(10) == "ig_draw_text: layer 'plot' outside a plot (call it between a true ip_begin_plot and ip_end_plot)" .and. &
         msg(11) == 'ig_draw_circle: color components are in [0, 1]'
ok(16) = errors == 0_int32                                             ! no usage error kept for a frame

write(output_unit, '(A,*(L2))') 'figure_test_canvas checks:', ok
if (.not. all(ok)) then
   do i = 1_int32, NP
      write(output_unit, '(A10,L2,I5,4F9.1,A,4F9.1)') NAMES(i), found(i), nv(i), ext(:, i) - [origin, origin], ' want ', &
                                                     want(:, i)
   enddo
   write(output_unit, '(A,2L2,A,4F9.1)') 'in window ', in_window, ' cursor, origin ', cursor, origin
   write(output_unit, '(A,4F9.2)') 'drag held, released ', drag_held, drag_released
   write(output_unit, '(A,4I4,L2,2F9.1)') 'presses releases right double shift mouse ', presses, releases, &
      right_clicks, double_clicks, shift_seen, mouse_at
   write(output_unit, '(A,F8.2,4F9.1)') 'wheel, scroll ', wheel_sum, s0, s1, s2, smax
   write(output_unit, '(A,2L2,8F9.1)') 'plot ', plot_found, plot_ext
   write(output_unit, '(A,I3,A,11I3,A,I0)') 'hot ', hot_clicks, ' statuses ', bad, ' errors ', errors
   do i = 1_int32, 11_int32
      write(output_unit, '(A)') trim(msg(i))
   enddo
endif
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(ok)
if (.not. all(ok)) error stop 1
contains
   subroutine events()
   !< Count what the canvas reports.
   if (ev%clicked(1)) presses = presses + 1_int32
   if (ev%released(1)) then
      releases = releases + 1_int32
      if (releases == 1_int32) drag_released = ev%drag
   endif
   if (ev%down(1) .and. releases == 0_int32) drag_held = ev%drag
   if (ev%clicked(2)) then
      right_clicks = right_clicks + 1_int32
      shift_seen = ev%shift
   endif
   if (ev%double_clicked(1)) double_clicks = double_clicks + 1_int32
   if (f == 8_int32 .and. ev%hovered) mouse_at = ev%mouse ! the pointer rests at the centre since frame 5
   endsubroutine events

   subroutine primitives(measure)
   !< Draw one primitive of each kind on the canvas, at `want` from its origin; with `measure`, find them.
   logical, intent(in) :: measure !< Measure the extents.
   real(real64)        :: x0      !< The canvas's origin.
   real(real64)        :: y0      !< ...
   real(real64)        :: dummy(4) !< An extent not used.

   x0 = ev%origin(1)
   y0 = ev%origin(2)
   call ig_draw_line(x0 + 10.0_real64, y0 + 10.0_real64, x0 + 110.0_real64, y0 + 60.0_real64, col(:, 1), thickness=1.0_real64)
   call ig_draw_rect(x0 + 180.0_real64, y0 + 50.0_real64, x0 + 120.0_real64, y0 + 10.0_real64, col(:, 2))
   call ig_draw_rect(x0 + 190.0_real64, y0 + 10.0_real64, x0 + 250.0_real64, y0 + 50.0_real64, col(:, 3), filled=.true.)
   call ig_draw_circle(x0 + 40.0_real64, y0 + 100.0_real64, 20.0_real64, col(:, 4), filled=.true.)
   call ig_draw_polyline(x0 + [80.0_real64, 120.0_real64, 160.0_real64], y0 + [120.0_real64, 80.0_real64, 120.0_real64], &
                         col(:, 5))
   call ig_draw_polygon(x0 + [170.0_real64, 250.0_real64, 210.0_real64], y0 + [80.0_real64, 80.0_real64, 140.0_real64], &
                        col(:, 6), filled=.true.)
   call ig_draw_text(x0 + 10.0_real64, y0 + 150.0_real64, 'inlet', col(:, 7))
   call ig_draw_image(tex, x0 + 240.0_real64, y0 + 190.0_real64, x0 + 200.0_real64, y0 + 150.0_real64, color=col(:, 8))
   call ig_draw_rect(x0 + 260.0_real64, y0 + 10.0_real64, x0 + 290.0_real64, y0 + 40.0_real64, col(:, 9), filled=.true., &
                     layer='foreground')
   call ig_draw_rect(x0 + 260.0_real64, y0 + 60.0_real64, x0 + 290.0_real64, y0 + 90.0_real64, col(:, 10), filled=.true., &
                     layer='background')
   call ig_draw_line(x0 + 10.0_real64, y0 + 190.0_real64, x0 + 110.0_real64, y0 + 190.0_real64, col(:, 11), &
                     thickness=10.0_real64)
   call ig_draw_polyline(x0 + [320.0_real64, 380.0_real64, 380.0_real64], y0 + [10.0_real64, 10.0_real64, 70.0_real64], &
                         col(:, 12), thickness=10.0_real64, closed=.true.)
   call ig_draw_polyline(x0 + [320.0_real64, 380.0_real64, 380.0_real64], y0 + [90.0_real64, 90.0_real64, 150.0_real64], &
                         col(:, 13), thickness=10.0_real64)
   if (.not. measure) return
   do i = 1_int32, NP
      if (i == 9_int32 .or. i == 10_int32) cycle
      call test_drawn_extent(col(:, i), ext(1, i), ext(2, i), ext(3, i), ext(4, i), found=found(i), vertices=nv(i))
   enddo
   call test_drawn_extent(col(:, 9), ext(1, 9), ext(2, 9), ext(3, 9), ext(4, 9), found=found(9), layer='foreground')
   call test_drawn_extent(col(:, 10), ext(1, 10), ext(2, 10), ext(3, 10), ext(4, 10), found=found(10), layer='background')
   call test_drawn_extent(col(:, 9), dummy(1), dummy(2), dummy(3), dummy(4), found=in_window(1))
   call test_drawn_extent(col(:, 10), dummy(1), dummy(2), dummy(3), dummy(4), found=in_window(2))
   endsubroutine primitives

   logical function extents_ok()
   !< Each primitive's extent within TOL of where it was drawn (the text: its top-left, within a line's height).
   real(real64) :: e(4) !< The extent from the canvas's origin.
   integer(int32) :: k  !< Primitive.

   extents_ok = .true.
   do k = 1_int32, NP
      e = ext(:, k) - [origin, origin]
      if (k >= 12_int32) then ! the corner at the first point: a miter beyond it when closed, a flat end when open
         if (k == 12_int32) extents_ok = extents_ok .and. e(1) < want(1, k) - 1.0_real64
         if (k == 13_int32) extents_ok = extents_ok .and. e(1) > want(1, k) - 1.0_real64
      elseif (k == 7_int32) then
         extents_ok = extents_ok .and. e(1) >= want(1, k) - TOL .and. e(1) < want(1, k) + 10.0_real64 .and. &
                      e(2) >= want(2, k) - TOL .and. e(2) < want(2, k) + 10.0_real64 .and. e(3) > e(1) + 10.0_real64
      else
         extents_ok = extents_ok .and. all(abs(e - want(:, k)) <= TOL)
      endif
   enddo
   endfunction extents_ok

   subroutine refused_calls()
   !< Wrong arguments, each refused with its status and message.
   type(texture_object) :: none !< A texture not initialized.
   real(real64)         :: nan  !< NaN.

   nan = ieee_value(nan, ieee_quiet_nan)
   call ig_draw_line(0.0_real64, 0.0_real64, 1.0_real64, 1.0_real64, [1.0_real64, 1.0_real64, 1.0_real64], &
                     layer='top', stat=bad(1))
   msg(1) = figure_last_error()
   call ig_draw_rect(0.0_real64, 0.0_real64, 1.0_real64, 1.0_real64, [1.0_real64, 1.0_real64], stat=bad(2))
   msg(2) = figure_last_error()
   call ig_draw_polyline([0.0_real64, 1.0_real64, 2.0_real64], [0.0_real64, 1.0_real64], [1.0_real64, 1.0_real64, &
                         1.0_real64], stat=bad(3))
   msg(3) = figure_last_error()
   call ig_draw_polygon([0.0_real64, 1.0_real64], [0.0_real64, 1.0_real64], [1.0_real64, 1.0_real64, 1.0_real64], &
                        filled=.true., stat=bad(4))
   msg(4) = figure_last_error()
   call ig_draw_line(nan, 0.0_real64, 1.0_real64, 1.0_real64, [1.0_real64, 1.0_real64, 1.0_real64], stat=bad(5))
   msg(5) = figure_last_error()
   call ig_draw_line(0.0_real64, 0.0_real64, 1.0_real64, 1.0_real64, [1.0_real64, 1.0_real64, 1.0_real64], &
                     thickness=0.0_real64, stat=bad(6))
   msg(6) = figure_last_error()
   call ig_draw_circle(0.0_real64, 0.0_real64, -1.0_real64, [1.0_real64, 1.0_real64, 1.0_real64], stat=bad(7))
   msg(7) = figure_last_error()
   call ig_draw_image(none, 0.0_real64, 0.0_real64, 1.0_real64, 1.0_real64, stat=bad(8))
   msg(8) = figure_last_error()
   call ig_canvas('bad', nan, 10.0_real64, ev2, stat=bad(9))
   msg(9) = figure_last_error()
   call ig_draw_text(0.0_real64, 0.0_real64, 'x', [1.0_real64, 1.0_real64, 1.0_real64], layer='plot', stat=bad(10))
   msg(10) = figure_last_error()
   call ig_draw_circle(0.0_real64, 0.0_real64, 1.0_real64, [1.0_real64, 1.5_real64, 1.0_real64], stat=bad(11))
   msg(11) = figure_last_error()
   endsubroutine refused_calls

   subroutine script(frame)
   !< The input, by frame.
   integer(int32), intent(in) :: frame !< Frame.

   select case (frame)
   case (5_int32)                                 ! over the canvas's centre
      call test_mouse_move(origin(1) + 150.0_real64, origin(2) + 100.0_real64)
   case (10_int32)                                ! a drag of (60, 30) inside it
      call test_drag(origin(1) + 50.0_real64, origin(2) + 50.0_real64, origin(1) + 110.0_real64, origin(2) + 80.0_real64)
   case (20_int32)                                ! a right click with shift
      call test_key('shift', down=.true.)
      call test_click(origin(1) + 100.0_real64, origin(2) + 100.0_real64, button='right')
      call test_next_frame()
      call test_key('shift', down=.false.)
   case (32_int32)                                ! a double click
      call test_mouse_move(origin(1) + 120.0_real64, origin(2) + 120.0_real64)
      call test_next_frame()
      call test_mouse_button(.true.)
      call test_next_frame()
      call test_mouse_button(.false.)
      call test_next_frame()
      call test_mouse_button(.true.)
      call test_next_frame()
      call test_mouse_button(.false.)
   case (60_int32)                                ! the invisible button
      call test_click(0.5_real64 * (hot(1) + hot(3)), 0.5_real64 * (hot(2) + hot(4)))
   case (75_int32)                                ! over the child's canvas
      call test_mouse_move(0.5_real64 * (rect2(1) + rect2(3)), 0.5_real64 * (rect2(2) + rect2(4)))
   case (78_int32)
      s0 = s2
      call test_wheel(-2.0_real64)
   case (84_int32)
      s1 = s2
      call test_mouse_move(0.5_real64 * (rect2(1) + rect2(3)), rect2(4) + 40.0_real64) ! beside it
   case (87_int32)
      call test_wheel(-2.0_real64)
   endselect
   endsubroutine script
endprogram figure_test_canvas
