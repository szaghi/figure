!< figure_plot_tools, the Fortran plot frame's drag tools: lines, points and rectangles the user drags, as ImPlot's.
module figure_plot_tools
!< figure_plot_tools, the Fortran plot frame's drag tools: lines, points and rectangles the user drags, as ImPlot's.
!<
!< szaghi/figure#15 P12, step 3. `pf_drag_line_x`, `pf_drag_line_y`, `pf_drag_point`, `pf_drag_rect` draw and move
!< what `ip_drag_line_x`, `ip_drag_line_y`, `ip_drag_point`, `ip_drag_rect` do through ImPlot's `DragLineX`,
!< `DragLineY`, `DragPoint`, `DragRect` (implot.cpp, flags 0: inputs, cursors, fit, no delay, moves and resizes), in
!< the plot open in figure_plot_frame, between its items:
!<
!< - the setup ended (`SetupLock`); on a frame the plot fits, the tool's values extend the current axes' fit
!<   (`FitPointX`, `FitPointY`, `FitPoint`; the rectangle's two corners);
!< - its ID, Dear ImGui's under the items' override ID (`plot.ID - 1`): `GetID(n_id)` for a vertical line, under
!<   `PushID("#IMPLOT_DRAG_LINE_Y")`, `"#IMPLOT_DRAG_POINT"`, `"#IMPLOT_DRAG_RECT"` for the others (hashed here,
!<   figure_plot_hash, not pushed: nothing between uses the stack), a rectangle's corners and edges the next eight IDs;
!< - its buttons (`KeepAliveID`, `ButtonBehavior` with flags 0) on its grab rectangles clipped to the plot area
!<   (`ClipWithFull`), at the call: after the plot's and axes' buttons, before the legend's, so Dear ImGui hands the
!<   hover from the plot (its button allows overlap) to the tool and a press on a tool does not pan;
!< - a held button moved past io's drag threshold (`IsMouseDragging(0)`: 6 pixels, FIGURE's) moves the values to the
!<   pointer on the current axes (`GetPlotMousePos`), a rectangle by the mouse's delta or by a corner or an edge; a
!<   double click on an edge takes it to the plot's limit; the cursors ImPlot sets;
!< - drawn at once, clipped to the plot area (`PushPlotClipRect`): a line at its rounded pixel, `thickness` wide, with
!<   two end marks `MajorTickLen` long and three times as thick; a point a filled circle; a rectangle filled at a
!<   quarter of its colour's alpha, outlined, and with its five grab circles while the pointer is in it or it moved.
!<
!< The colour: given (RGBA in [0, 1]), or Dear ImGui's text colour (ImPlot's automatic colour, alpha -1; packed with
!< the style's alpha, which FIGURE's themes keep at 1). Kept from the current path (the owner's decision on #15): as
!< `ip_drag_rect`, a rectangle's values are put in order once it is no longer held, and it is held while the pointer
!< is in it with the left button down even off its handles (ImPlot's `out_held`). Usage errors (outside a plot, a
!< colour of size /= 4, a NaN edge) stop the program, as the frame's.
!<
!< No allocation per frame: the values are scalars, the grab rectangles fixed arrays.
use, intrinsic :: iso_fortran_env, only : int32, real32, real64
use figure_cimgui_enums, only : ImGuiCol_Text, ImGuiMouseCursor_Hand, ImGuiMouseCursor_ResizeAll, &
                                ImGuiMouseCursor_ResizeEW, ImGuiMouseCursor_ResizeNESW, ImGuiMouseCursor_ResizeNS, &
                                ImGuiMouseCursor_ResizeNWSE
use figure_plot_style, only : MAJOR_TICK_LEN
use figure_core, only : core_button_behavior, core_color, core_draw_circle, core_draw_line_h, core_draw_line_v, &
                        core_draw_rect, core_draw_rect_filled, core_io_input, core_keep_alive,                 &
                        core_mouse_double_clicked, core_mouse_down, core_mouse_pos, core_pop_clip_rect,        &
                        core_push_clip_rect, core_set_mouse_cursor, core_style_color_rgba
use figure_plot_frame, only : plot_item_ctx, pf_item_fit, pf_item_fit_axis, pf_pixels_to_plot, pf_plot_ctx, &
                              pf_plot_id, pf_plot_limits, pf_plot_to_pixels
use figure_plot_hash, only : plot_hash, plot_hash_int, plot_id_offset

implicit none
private
public :: pf_drag_line_x, pf_drag_line_y, pf_drag_point, pf_drag_rect

real(real32), parameter :: GRAB_HALF = 4.0_real32                     !< DRAG_GRAB_HALF_SIZE [pixels].
real(real64), parameter :: DRAG_THRESHOLD_SQ = 36.0_real64            !< io.MouseDragThreshold (6) squared.

contains
   function pf_drag_line_x(id, x, color, thickness) result(moved)
   !< A vertical line at `x` in the open plot that the user drags along x (`DragLineX`; `ip_drag_line_x`): `x` is
   !< updated in place, the result true on the frames it moves. `id` tells the plot's drag tools apart.
   integer(int32), intent(in)           :: id        !< Id, unique among the plot's drag tools.
   real(real64),   intent(inout)        :: x         !< Position [plot units].
   real(real64),   intent(in), optional :: color(:)  !< Colour, RGBA in [0, 1] (default: the text colour).
   real(real64),   intent(in), optional :: thickness !< Line thickness [pixels] (default 1).
   logical                              :: moved     !< Moved by the user on this frame.
   type(plot_item_ctx)                  :: ctx       !< The plot.
   real(real32)                         :: th, half, yt, yb, xp, len_ !< Thickness, grab half size, line.
   real(real64)                         :: px, py, vx, vy !< A pixel, a point.
   integer(int32)                       :: tid, col  !< ID, colour.
   logical                              :: hov, held, clicked !< The button.

   moved = .false.
   call pf_plot_ctx(ctx) ! SetupLock
   if (ctx%fit) call pf_item_fit_axis(x, .false.) ! FitPointX
   th = 1.0_real32
   if (present(thickness)) th = real(thickness, real32)
   half = max(GRAB_HALF, th / 2.0_real32)
   yt = ctx%rect(2)
   yb = ctx%rect(4)
   call pf_plot_to_pixels(x, ctx%y_range(1), px, py) ! (ImPlot maps (x, 0): only x is used)
   xp = im_round(real(px, real32))
   tid = plot_hash_int(id, plot_id_offset(pf_plot_id(), -1_int32))
   call core_keep_alive(tid)
   clicked = button(ctx%rect, xp - half, yt, xp + half, yb, tid, hov, held)
   if (hov .or. held) call core_set_mouse_cursor(ImGuiMouseCursor_ResizeEW)
   len_ = MAJOR_TICK_LEN(1)
   col = tool_color(color, 1.0_real32)
   if (held .and. dragging()) then
      call mouse_plot(vx, vy)
      x = vx
      moved = .true.
   endif
   call push_plot_clip(ctx)
   if (moved) then
      call pf_plot_to_pixels(x, ctx%y_range(1), px, py)
      xp = im_round(real(px, real32))
   endif
   call core_draw_line_v(real(xp, real64), real(yt, real64), real(yb, real64), col, real(th, real64))
   call core_draw_line_v(real(xp, real64), real(yt, real64), real(yt + len_, real64), col, &
                         real(3.0_real32 * th, real64))
   call core_draw_line_v(real(xp, real64), real(yb, real64), real(yb - len_, real64), col, &
                         real(3.0_real32 * th, real64))
   call core_pop_clip_rect()
   endfunction pf_drag_line_x

   function pf_drag_line_y(id, y, color, thickness) result(moved)
   !< A horizontal line at `y` in the open plot that the user drags along y (`DragLineY`; `ip_drag_line_y`): as
   !< `pf_drag_line_x`.
   integer(int32), intent(in)           :: id        !< Id, unique among the plot's drag tools.
   real(real64),   intent(inout)        :: y         !< Position [plot units].
   real(real64),   intent(in), optional :: color(:)  !< Colour, RGBA in [0, 1] (default: the text colour).
   real(real64),   intent(in), optional :: thickness !< Line thickness [pixels] (default 1).
   logical                              :: moved     !< Moved by the user on this frame.
   type(plot_item_ctx)                  :: ctx       !< The plot.
   real(real32)                         :: th, half, xl, xr, yp, len_ !< Thickness, grab half size, line.
   real(real64)                         :: px, py, vx, vy !< A pixel, a point.
   integer(int32)                       :: tid, col  !< ID, colour.
   logical                              :: hov, held, clicked !< The button.

   moved = .false.
   call pf_plot_ctx(ctx)
   if (ctx%fit) call pf_item_fit_axis(y, .true.) ! FitPointY
   th = 1.0_real32
   if (present(thickness)) th = real(thickness, real32)
   half = max(GRAB_HALF, th / 2.0_real32)
   xl = ctx%rect(1)
   xr = ctx%rect(3)
   call pf_plot_to_pixels(ctx%x_range(1), y, px, py) ! (ImPlot maps (0, y): only y is used)
   yp = im_round(real(py, real32))
   tid = plot_hash_int(id, plot_hash('#IMPLOT_DRAG_LINE_Y', plot_id_offset(pf_plot_id(), -1_int32)))
   call core_keep_alive(tid)
   clicked = button(ctx%rect, xl, yp - half, xr, yp + half, tid, hov, held)
   if (hov .or. held) call core_set_mouse_cursor(ImGuiMouseCursor_ResizeNS)
   len_ = MAJOR_TICK_LEN(2)
   col = tool_color(color, 1.0_real32)
   if (held .and. dragging()) then
      call mouse_plot(vx, vy)
      y = vy
      moved = .true.
   endif
   call push_plot_clip(ctx)
   if (moved) then
      call pf_plot_to_pixels(ctx%x_range(1), y, px, py)
      yp = im_round(real(py, real32))
   endif
   call core_draw_line_h(real(xl, real64), real(xr, real64), real(yp, real64), col, real(th, real64))
   call core_draw_line_h(real(xl, real64), real(xl + len_, real64), real(yp, real64), col, &
                         real(3.0_real32 * th, real64))
   call core_draw_line_h(real(xr, real64), real(xr - len_, real64), real(yp, real64), col, &
                         real(3.0_real32 * th, real64))
   call core_pop_clip_rect()
   endfunction pf_drag_line_y

   function pf_drag_point(id, x, y, color, radius) result(moved)
   !< A point at (x, y) in the open plot that the user drags (`DragPoint`; `ip_drag_point`): as `pf_drag_line_x`, both
   !< coordinates updated.
   integer(int32), intent(in)           :: id       !< Id, unique among the plot's drag tools.
   real(real64),   intent(inout)        :: x        !< Abscissa [plot units].
   real(real64),   intent(inout)        :: y        !< Ordinate [plot units].
   real(real64),   intent(in), optional :: color(:) !< Colour, RGBA in [0, 1] (default: the text colour).
   real(real64),   intent(in), optional :: radius   !< Radius [pixels] (default 4).
   logical                              :: moved    !< Moved by the user on this frame.
   type(plot_item_ctx)                  :: ctx      !< The plot.
   real(real32)                         :: r, half, pos(2) !< Radius, grab half size, the point [pixels].
   real(real64)                         :: px, py, vx, vy !< A pixel, a point.
   integer(int32)                       :: tid, col !< ID, colour.
   logical                              :: hov, held, clicked !< The button.

   moved = .false.
   call pf_plot_ctx(ctx)
   if (ctx%fit) call pf_item_fit(x, y) ! FitPoint
   r = 4.0_real32
   if (present(radius)) r = real(radius, real32)
   half = max(GRAB_HALF, r)
   col = tool_color(color, 1.0_real32)
   call pf_plot_to_pixels(x, y, px, py)
   call pix2(px, py, pos)
   tid = plot_hash_int(id, plot_hash('#IMPLOT_DRAG_POINT', plot_id_offset(pf_plot_id(), -1_int32)))
   call core_keep_alive(tid)
   clicked = button(ctx%rect, pos(1) - half, pos(2) - half, pos(1) + half, pos(2) + half, tid, hov, held)
   if (held .and. dragging()) then
      call mouse_plot(vx, vy)
      x = vx
      y = vy
      moved = .true.
   endif
   call push_plot_clip(ctx)
   if (hov .or. held) call core_set_mouse_cursor(ImGuiMouseCursor_Hand)
   if (moved) then
      call pf_plot_to_pixels(x, y, px, py)
      call pix2(px, py, pos)
   endif
   call core_draw_circle(real(pos(1), real64), real(pos(2), real64), real(r, real64), col, filled=.true.)
   call core_pop_clip_rect()
   endfunction pf_drag_point

   function pf_drag_rect(id, xmin, xmax, ymin, ymax, color) result(moved)
   !< A rectangle [xmin, xmax] x [ymin, ymax] in the open plot that the user drags (`DragRect`; `ip_drag_rect`): by
   !< its centre to move it, by a corner or an edge to resize it (a double click on an edge takes it to the plot's
   !< limit); the four values are updated in place, the result true on the frames it changes. An edge dragged past the
   !< opposite one crosses it while held; the values are put in order once no part of it is held (FIGURE's
   !< `ip_drag_rect`). A rectangle of no width and no height cannot be moved.
   integer(int32), intent(in)           :: id       !< Id, unique among the plot's drag tools.
   real(real64),   intent(inout)        :: xmin     !< Left edge [plot units].
   real(real64),   intent(inout)        :: xmax     !< Right edge [plot units].
   real(real64),   intent(inout)        :: ymin     !< Bottom edge [plot units].
   real(real64),   intent(inout)        :: ymax     !< Top edge [plot units].
   real(real64),   intent(in), optional :: color(:) !< Colour, RGBA in [0, 1] (default: the text colour).
   logical                              :: moved    !< Moved or resized by the user on this frame.
   integer(int32), parameter :: XI(4) = [1_int32, 2_int32, 2_int32, 1_int32] !< A corner's x: xmin, xmax, xmax, xmin.
   integer(int32), parameter :: YI(4) = [1_int32, 1_int32, 2_int32, 2_int32] !< ... its y: ymin, ymin, ymax, ymax.
   logical,        parameter :: HOR(4) = [.true., .false., .true., .false.]  !< The edge from a corner is horizontal.
   type(plot_item_ctx)       :: ctx      !< The plot.
   real(real64)              :: xv(2), yv(2) !< The values (x min, x max; y min, y max), as the user moves them.
   real(real32)              :: p(2, 4), pc(2), rc(4), rg(4), b(4), e_min(2), e_max(2) !< Corners, centre, the
                                                                                       !< rectangle, its grab, a button.
   real(real64)              :: px, py, vx, vy, mx, my, dx, dy, wh, wh_h, dmax(5) !< Pixels, points, io's input.
   real(real64)              :: lx0, lx1, ly0, ly1 !< The plot's limits.
   real(real64)              :: t        !< Swap.
   integer(int32)            :: cur(4), rid, k, j, col, col_a, mods !< Cursors, ID, counters, colours, key mods.
   logical                   :: hov, held, clicked, out_held, drag, inside, dnd !< Buttons, input.

   moved = .false.
   if (xmin /= xmin .or. xmax /= xmax .or. ymin /= ymin .or. ymax /= ymax) &
      error stop 'figure_plot_tools: pf_drag_rect: an edge is NaN'
   call pf_plot_ctx(ctx)
   if (ctx%fit) then ! FitPoint of two corners
      call pf_item_fit(xmin, ymin)
      call pf_item_fit(xmax, ymax)
   endif
   xv(1) = xmin
   xv(2) = xmax
   yv(1) = ymin
   yv(2) = ymax
   do k = 1_int32, 4_int32
      call pf_plot_to_pixels(xv(XI(k)), yv(YI(k)), px, py)
      call pix2(px, py, p(:, k))
   enddo
   call pf_plot_to_pixels((xv(1) + xv(2)) / 2.0_real64, (yv(1) + yv(2)) / 2.0_real64, px, py)
   call pix2(px, py, pc)
   call corners_rect(p, rc)
   call box(rc(1), rc(2), rc(3), rc(4), GRAB_HALF, rg) ! Expand, ClipWithFull
   call clip_full(rg, ctx%rect)
   if ((rc(1) == p(1, 1) .and. rc(2) == p(2, 1)) .or. (rc(3) == p(1, 1) .and. rc(4) == p(2, 1))) then
      cur(1) = ImGuiMouseCursor_ResizeNWSE
   else
      cur(1) = ImGuiMouseCursor_ResizeNESW
   endif
   do k = 2_int32, 4_int32
      cur(k) = merge(ImGuiMouseCursor_ResizeNESW, ImGuiMouseCursor_ResizeNWSE, &
                     cur(k - 1_int32) == ImGuiMouseCursor_ResizeNWSE)
   enddo
   col = tool_color(color, 1.0_real32)
   col_a = tool_color(color, 0.25_real32)
   rid = plot_hash_int(id, plot_hash('#IMPLOT_DRAG_RECT', plot_id_offset(pf_plot_id(), -1_int32)))
   call core_io_input(dx, dy, wh, wh_h, dmax, mods, dnd)
   drag = core_mouse_down(0_int32) .and. dmax(1) >= DRAG_THRESHOLD_SQ
   out_held = .false.
   hov = .false.
   held = .false.
   if (xv(1) /= xv(2) .or. yv(1) /= yv(2)) then ! movable: by its centre
      call core_keep_alive(rid)
      clicked = button(ctx%rect, pc(1) - GRAB_HALF, pc(2) - GRAB_HALF, pc(1) + GRAB_HALF, pc(2) + GRAB_HALF, rid, hov, &
                       held)
      out_held = held
      if (hov .or. held) call core_set_mouse_cursor(ImGuiMouseCursor_ResizeAll)
      if (held .and. drag) then
         do k = 1_int32, 4_int32
            call pf_pixels_to_plot(real(p(1, k) + real(dx, real32), real64), real(p(2, k) + real(dy, real32), real64), &
                                   vx, vy)
            yv(YI(k)) = vy
            xv(XI(k)) = vx
         enddo
         moved = .true.
      endif
   endif
   do k = 1_int32, 4_int32
      ! the corner
      call box(p(1, k), p(2, k), p(1, k), p(2, k), GRAB_HALF, b)
      call core_keep_alive(plot_id_offset(rid, k))
      clicked = button(ctx%rect, b(1), b(2), b(3), b(4), plot_id_offset(rid, k), hov, held)
      out_held = out_held .or. held
      if (hov .or. held) call core_set_mouse_cursor(cur(k))
      if (held .and. drag) then
         call mouse_plot(vx, vy)
         xv(XI(k)) = vx
         yv(YI(k)) = vy
         moved = .true.
      endif
      ! the edge to the next corner
      j = mod(k, 4_int32) + 1_int32
      e_min(1) = min(p(1, k), p(1, j))
      e_min(2) = min(p(2, k), p(2, j))
      e_max(1) = max(p(1, k), p(1, j))
      e_max(2) = max(p(2, k), p(2, j))
      if (HOR(k)) then
         b(1) = e_min(1) + GRAB_HALF
         b(2) = e_min(2) - GRAB_HALF
         b(3) = e_max(1) - GRAB_HALF
         b(4) = e_max(2) + GRAB_HALF
      else
         b(1) = e_min(1) - GRAB_HALF
         b(2) = e_min(2) + GRAB_HALF
         b(3) = e_max(1) + GRAB_HALF
         b(4) = e_max(2) - GRAB_HALF
      endif
      call core_keep_alive(plot_id_offset(rid, k + 4_int32))
      clicked = button(ctx%rect, b(1), b(2), b(3), b(4), plot_id_offset(rid, k + 4_int32), hov, held)
      out_held = out_held .or. held
      if (hov .or. held) call core_set_mouse_cursor(merge(ImGuiMouseCursor_ResizeNS, ImGuiMouseCursor_ResizeEW, HOR(k)))
      if (held .and. drag) then
         call mouse_plot(vx, vy)
         if (HOR(k)) then
            yv(YI(k)) = vy
         else
            xv(XI(k)) = vx
         endif
         moved = .true.
      endif
      if (hov .and. core_mouse_double_clicked(0_int32)) then ! to the plot's limit
         call pf_plot_limits(lx0, lx1, ly0, ly1)
         if (HOR(k)) then
            if ((YI(k) == 1_int32 .and. yv(1) < yv(2)) .or. (YI(k) == 2_int32 .and. yv(2) < yv(1))) then
               yv(YI(k)) = ly0
            else
               yv(YI(k)) = ly1
            endif
         else
            if ((XI(k) == 1_int32 .and. xv(1) < xv(2)) .or. (XI(k) == 2_int32 .and. xv(2) < xv(1))) then
               xv(XI(k)) = lx0
            else
               xv(XI(k)) = lx1
            endif
         endif
         moved = .true.
      endif
   enddo
   call core_mouse_pos(mx, my)
   inside = real(mx, real32) >= rg(1) .and. real(my, real32) >= rg(2) .and. real(mx, real32) < rg(3) .and. &
            real(my, real32) < rg(4)
   if (inside) out_held = out_held .or. core_mouse_down(0_int32)
   call push_plot_clip(ctx)
   if (moved) then
      do k = 1_int32, 4_int32
         call pf_plot_to_pixels(xv(XI(k)), yv(YI(k)), px, py)
         call pix2(px, py, p(:, k))
      enddo
      call pf_plot_to_pixels((xv(1) + xv(2)) / 2.0_real64, (yv(1) + yv(2)) / 2.0_real64, px, py)
      call pix2(px, py, pc)
      call corners_rect(p, rc)
   endif
   call core_draw_rect_filled(real(rc(1), real64), real(rc(2), real64), real(rc(3), real64), real(rc(4), real64), col_a)
   call core_draw_rect(real(rc(1), real64), real(rc(2), real64), real(rc(3), real64), real(rc(4), real64), col)
   if (moved .or. inside) then
      call core_draw_circle(real(pc(1), real64), real(pc(2), real64), real(GRAB_HALF, real64), col, filled=.true.)
      do k = 1_int32, 4_int32
         call core_draw_circle(real(p(1, k), real64), real(p(2, k), real64), real(GRAB_HALF, real64), col, &
                               filled=.true.)
      enddo
   endif
   call core_pop_clip_rect()
   xmin = xv(1)
   xmax = xv(2)
   ymin = yv(1)
   ymax = yv(2)
   if (.not. out_held) then ! released: in order (ImPlot moves each edge on its own)
      if (xmin > xmax) then
         t = xmin
         xmin = xmax
         xmax = t
      endif
      if (ymin > ymax) then
         t = ymin
         ymin = ymax
         ymax = t
      endif
   endif
   endfunction pf_drag_rect

   ! private

   function button(plot_rect, x0, y0, x1, y1, tid, hov, held) result(clicked)
   !< A tool's button (`ButtonBehavior`, flags 0) on its grab rectangle clipped to the plot area (`ClipWithFull`).
   real(real32),   intent(in)  :: plot_rect(4)   !< The plot area [pixels].
   real(real32),   intent(in)  :: x0, y0, x1, y1 !< The grab rectangle [pixels].
   integer(int32), intent(in)  :: tid            !< Its ID.
   logical,        intent(out) :: hov, held      !< Hovered, held.
   logical                     :: clicked        !< Pressed.
   real(real32)                :: r(4)           !< The rectangle clipped.

   r(1) = x0
   r(2) = y0
   r(3) = x1
   r(4) = y1
   call clip_full(r, plot_rect)
   clicked = core_button_behavior(real(r(1), real64), real(r(2), real64), real(r(3), real64), real(r(4), real64), tid, &
                                  hov, held)
   endfunction button

   pure subroutine pix2(px, py, v)
   !< A pixel as floats (no array constructor: nvfortran allocates those).
   real(real64), intent(in)  :: px, py !< Pixel.
   real(real32), intent(out) :: v(2)   !< As floats.

   v(1) = real(px, real32)
   v(2) = real(py, real32)
   endsubroutine pix2

   pure subroutine box(x0, y0, x1, y1, h, r)
   !< The rectangle (x0, y0)-(x1, y1) grown by h on each side.
   real(real32), intent(in)  :: x0, y0, x1, y1 !< Rectangle.
   real(real32), intent(in)  :: h              !< Growth.
   real(real32), intent(out) :: r(4)           !< Grown.

   r(1) = x0 - h
   r(2) = y0 - h
   r(3) = x1 + h
   r(4) = y1 + h
   endsubroutine box

   pure subroutine corners_rect(p, r)
   !< The rectangle of the first and third corners (`ImRect(ImMin(p[0], p[2]), ImMax(p[0], p[2]))`).
   real(real32), intent(in)  :: p(2, 4) !< Corners.
   real(real32), intent(out) :: r(4)    !< Rectangle.

   r(1) = min(p(1, 1), p(1, 3))
   r(2) = min(p(2, 1), p(2, 3))
   r(3) = max(p(1, 1), p(1, 3))
   r(4) = max(p(2, 1), p(2, 3))
   endsubroutine corners_rect

   pure subroutine clip_full(r, c)
   !< `ImRect::ClipWithFull`: each corner clamped into `c`.
   real(real32), intent(inout) :: r(4) !< Rectangle.
   real(real32), intent(in)    :: c(4) !< Clip.

   r(1) = min(max(r(1), c(1)), c(3))
   r(2) = min(max(r(2), c(2)), c(4))
   r(3) = min(max(r(3), c(1)), c(3))
   r(4) = min(max(r(4), c(2)), c(4))
   endsubroutine clip_full

   function dragging() result(yes)
   !< `IsMouseDragging(0)`: the left button down and moved past io's drag threshold since its press.
   logical        :: yes                    !< Dragging.
   real(real64)   :: dx, dy, wh, wh_h, dmax(5) !< io's input.
   integer(int32) :: mods                   !< Key mods.
   logical        :: dnd                    !< A drag and drop.

   call core_io_input(dx, dy, wh, wh_h, dmax, mods, dnd)
   yes = core_mouse_down(0_int32) .and. dmax(1) >= DRAG_THRESHOLD_SQ
   endfunction dragging

   subroutine mouse_plot(x, y)
   !< `GetPlotMousePos(IMPLOT_AUTO, IMPLOT_AUTO)`: the pointer on the current axes.
   real(real64), intent(out) :: x, y   !< Point.
   real(real64)              :: mx, my !< The pointer.

   call core_mouse_pos(mx, my)
   call pf_pixels_to_plot(mx, my, x, y)
   endsubroutine mouse_plot

   subroutine push_plot_clip(ctx)
   !< `PushPlotClipRect`: the plot area.
   type(plot_item_ctx), intent(in) :: ctx !< The plot.

   call core_push_clip_rect(real(ctx%rect(1), real64), real(ctx%rect(2), real64), real(ctx%rect(3), real64), &
                            real(ctx%rect(4), real64))
   endsubroutine push_plot_clip

   function tool_color(color, alpha_mul) result(col)
   !< A tool's colour packed (`ColorConvertFloat4ToU32`), its alpha times `alpha_mul` (in C float): given, or Dear
   !< ImGui's text colour when absent or of alpha -1 (`IsColorAuto`).
   real(real64), intent(in), optional :: color(:)  !< Colour, RGBA.
   real(real32), intent(in)           :: alpha_mul !< Alpha factor.
   integer(int32)                     :: col       !< Packed colour.
   real(real32)                       :: a         !< Alpha.
   real(real64)                       :: t(4)      !< The text colour.

   if (present(color)) then
      if (size(color) /= 4) error stop "figure_plot_tools: a drag tool's colour needs 4 components (RGBA)"
      if (real(color(4), real32) /= -1.0_real32) then
         a = real(color(4), real32) * alpha_mul
         col = core_color(color(1), color(2), color(3), real(a, real64))
         return
      endif
   endif
   call core_style_color_rgba(ImGuiCol_Text, t) ! GetStyleColorVec4(ImGuiCol_Text): Dear ImGui's style Alpha not applied
   a = real(t(4), real32) * alpha_mul
   col = core_color(t(1), t(2), t(3), real(a, real64))
   endfunction tool_color

   pure function im_round(f) result(r)
   !< `IM_ROUND` of a (positive) float: `(float)(int)(f + 0.5f)`.
   real(real32), intent(in) :: f !< Value.
   real(real32)             :: r !< Rounded.

   r = real(int(f + 0.5_real32, int32), real32)
   endfunction im_round
endmodule figure_plot_tools
