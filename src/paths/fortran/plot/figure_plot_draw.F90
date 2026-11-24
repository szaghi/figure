!< figure_plot_draw, drawing in a plot of the Fortran frame: figure_canvas's `'plot'` layer, in plot units.
module figure_plot_draw
!< figure_plot_draw, drawing in a plot of the Fortran frame: figure_canvas's `'plot'` layer, in plot units.
!<
!< szaghi/figure#15: what native/figure_canvas.cpp's `fig_draw` does on the `'plot'` layer (`ig_draw_*(...,
!< layer='plot')` between a true `ip_begin_plot` and `ip_end_plot`), for a plot of the Fortran frame (between a true
!< `pf_begin_plot` and `pf_end_plot`): `pf_draw_line`, `pf_draw_rect`, `pf_draw_circle`, `pf_draw_polyline`,
!< `pf_draw_polygon`, `pf_draw_text`, `pf_draw_image`, with `ig_draw_*`'s arguments (no layer) and refusals. Through the
!< frame's public hooks only: the setup ended (`SetupLock`) and the points mapped on the current axes
!< (`pf_plot_to_pixels`: `PlotToPixels`, double precision then single, here kept within 1e7 pixels of the origin as
!< the native layer keeps them), the plot's area (`pf_plot_rect`: `PushPlotClipRect`), whether a plot is open
!< (`pf_plot_state`). The colour is packed as `ImGui::GetColorU32(ImVec4)`: its alpha times the style's. Drawn on the
!< window's list (`GetPlotDrawList`) through figure_core, after what the frame has pending.
use, intrinsic :: iso_c_binding, only : c_int
use, intrinsic :: ieee_arithmetic, only : ieee_is_nan
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use figure_base, only : figure_draw_refused, figure_fail, figure_usage_error
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_OK
use figure_core, only : core_color, core_draw_begin, core_draw_circle, core_draw_concave_poly_filled, core_draw_end, &
                        core_draw_image, core_draw_line, core_draw_polyline, core_draw_rect, core_draw_rect_filled,  &
                        core_draw_text, core_pop_clip_rect, core_push_clip_rect, core_style_var,                    &
                        core_texture_sampling
use figure_cimgui, only : im_texture_ref
use figure_texture, only : texture_object, texture_ref
use figure_plot_frame, only : pf_plot_rect, pf_plot_state, pf_plot_to_pixels

implicit none
private
public :: pf_draw_line, pf_draw_rect, pf_draw_circle, pf_draw_polyline, pf_draw_polygon, pf_draw_text, pf_draw_image
public :: pf_draw_prim

! Primitives (native/figure_canvas.cpp's kind_t).
integer(c_int), parameter :: DRAW_LINE = 1_c_int     !< A segment.
integer(c_int), parameter :: DRAW_RECT = 2_c_int     !< A rectangle.
integer(c_int), parameter :: DRAW_CIRCLE = 3_c_int   !< A circle.
integer(c_int), parameter :: DRAW_POLYLINE = 4_c_int !< A polyline.
integer(c_int), parameter :: DRAW_POLYGON = 5_c_int  !< A polygon.
integer(c_int), parameter :: DRAW_TEXT = 6_c_int     !< Text.
integer(c_int), parameter :: DRAW_IMAGE = 7_c_int    !< A texture.
real(real64),   parameter :: COORD_MAX = real(huge(1.0_real32), real64) !< The largest coordinate or length.
real(real64),   parameter :: PIXEL_LIMIT = 1.0e7_real64 !< A pixel kept within this of the display's origin.
integer(int32), parameter :: NFIX = 64_int32         !< Points mapped without a heap allocation.

contains
   subroutine pf_draw_line(x1, y1, x2, y2, color, thickness, stat)
   !< A segment from (`x1`, `y1`) to (`x2`, `y2`) in plot units (`ig_draw_line(..., layer='plot')`). Refusals: see
   !< `pf_draw_polyline`.
   real(real64),   intent(in)            :: x1, y1    !< Start [plot units].
   real(real64),   intent(in)            :: x2, y2    !< End [plot units].
   real(real64),   intent(in)            :: color(:)  !< Colour, `[r, g, b(, a)]` in [0, 1].
   real(real64),   intent(in), optional  :: thickness !< Line thickness [pixels] (default 1).
   integer(int32), intent(out), optional :: stat      !< Status.

   call draw('pf_draw_line', DRAW_LINE, [x1, x2], [y1, y2], color, thickness, stat=stat)
   endsubroutine pf_draw_line

   subroutine pf_draw_rect(x1, y1, x2, y2, color, thickness, filled, stat)
   !< A rectangle with opposite corners (`x1`, `y1`) and (`x2`, `y2`) in plot units, in any order: its outline, or
   !< filled (`ig_draw_rect(..., layer='plot')`). Refusals: see `pf_draw_polyline`.
   real(real64),   intent(in)            :: x1, y1    !< A corner [plot units].
   real(real64),   intent(in)            :: x2, y2    !< The opposite corner [plot units].
   real(real64),   intent(in)            :: color(:)  !< Colour, `[r, g, b(, a)]` in [0, 1].
   real(real64),   intent(in), optional  :: thickness !< Outline thickness [pixels] (default 1).
   logical,        intent(in), optional  :: filled    !< Filled (default: the outline).
   integer(int32), intent(out), optional :: stat      !< Status.

   call draw('pf_draw_rect', DRAW_RECT, [x1, x2], [y1, y2], color, thickness, filled=filled, stat=stat)
   endsubroutine pf_draw_rect

   subroutine pf_draw_circle(x, y, radius, color, thickness, filled, stat)
   !< A circle centred at (`x`, `y`) in plot units, its radius in pixels: its outline, or filled
   !< (`ig_draw_circle(..., layer='plot')`). Refusals: see `pf_draw_polyline`, and a radius below 0 or not finite.
   real(real64),   intent(in)            :: x, y      !< Centre [plot units].
   real(real64),   intent(in)            :: radius    !< Radius [pixels].
   real(real64),   intent(in)            :: color(:)  !< Colour, `[r, g, b(, a)]` in [0, 1].
   real(real64),   intent(in), optional  :: thickness !< Outline thickness [pixels] (default 1).
   logical,        intent(in), optional  :: filled    !< Filled (default: the outline).
   integer(int32), intent(out), optional :: stat      !< Status.

   if (figure_draw_refused('pf_draw_circle', stat)) return ! a task does not draw
   if (.not. length_ok(radius, .true.)) then ! NaN tested apart: an ordered comparison of NaN traps (FPE invalid)
      call figure_fail(FIG_ERR_ARGUMENT, 'pf_draw_circle: radius is not a finite length >= 0', stat)
      return
   endif
   call draw('pf_draw_circle', DRAW_CIRCLE, [x], [y], color, thickness, radius=radius, filled=filled, stat=stat)
   endsubroutine pf_draw_circle

   subroutine pf_draw_polyline(x, y, color, thickness, closed, stat)
   !< A polyline through the points (`x(i)`, `y(i)`) in plot units; `closed` joins the last point to the first
   !< (`ig_draw_polyline(..., layer='plot')`). Refused with `FIG_ERR_ARGUMENT` in `stat` (or `error stop` without it),
   !< nothing drawn, for every primitive: `x` and `y` of different sizes or fewer points than the primitive needs (2
   !< here), a coordinate NaN, infinite or beyond single precision, a colour not of 3 or 4 components in [0, 1], a
   !< thickness not above 0. Outside a plot (between a true `pf_begin_plot` and `pf_end_plot`), no frame open or a
   !< task: `FIG_ERR_STATE`, a usage error.
   real(real64),   intent(in)            :: x(:)      !< Abscissae [plot units].
   real(real64),   intent(in)            :: y(:)      !< Ordinates [plot units].
   real(real64),   intent(in)            :: color(:)  !< Colour, `[r, g, b(, a)]` in [0, 1].
   real(real64),   intent(in), optional  :: thickness !< Line thickness [pixels] (default 1).
   logical,        intent(in), optional  :: closed    !< Join the last point to the first (default false).
   integer(int32), intent(out), optional :: stat      !< Status.

   call draw('pf_draw_polyline', DRAW_POLYLINE, x, y, color, thickness, filled=closed, stat=stat)
   endsubroutine pf_draw_polyline

   subroutine pf_draw_polygon(x, y, color, thickness, filled, stat)
   !< A closed polygon through the points (`x(i)`, `y(i)`) in plot units: its outline, or filled (convex or not; not
   !< self-intersecting) (`ig_draw_polygon(..., layer='plot')`). At least 3 points. Refusals: see `pf_draw_polyline`.
   real(real64),   intent(in)            :: x(:)      !< Abscissae [plot units].
   real(real64),   intent(in)            :: y(:)      !< Ordinates [plot units].
   real(real64),   intent(in)            :: color(:)  !< Colour, `[r, g, b(, a)]` in [0, 1].
   real(real64),   intent(in), optional  :: thickness !< Outline thickness [pixels] (default 1).
   logical,        intent(in), optional  :: filled    !< Filled (default: the outline).
   integer(int32), intent(out), optional :: stat      !< Status.

   call draw('pf_draw_polygon', DRAW_POLYGON, x, y, color, thickness, filled=filled, stat=stat)
   endsubroutine pf_draw_polygon

   subroutine pf_draw_text(x, y, text, color, stat)
   !< `text` with its top-left at (`x`, `y`) in plot units, in the current font (`ig_draw_text(..., layer='plot')`).
   !< Refusals: see `pf_draw_polyline`.
   real(real64),     intent(in)            :: x, y     !< Top-left [plot units].
   character(len=*), intent(in)            :: text     !< Text (UTF-8).
   real(real64),     intent(in)            :: color(:) !< Colour, `[r, g, b(, a)]` in [0, 1].
   integer(int32),   intent(out), optional :: stat     !< Status.

   call draw('pf_draw_text', DRAW_TEXT, [x], [y], color, text=text, stat=stat)
   endsubroutine pf_draw_text

   subroutine pf_draw_image(texture, x1, y1, x2, y2, color, stat)
   !< A texture stretched over the rectangle with opposite corners (`x1`, `y1`) and (`x2`, `y2`) in plot units, in any
   !< order, its pixel row 1 at the top; `color` multiplies its pixels (default white) (`ig_draw_image(...,
   !< layer='plot')`). Refusals: see `pf_draw_polyline`, and a texture not initialized.
   type(texture_object), intent(in)            :: texture  !< The texture.
   real(real64),         intent(in)            :: x1, y1   !< A corner [plot units].
   real(real64),         intent(in)            :: x2, y2   !< The opposite corner [plot units].
   real(real64),         intent(in), optional  :: color(:) !< Tint, `[r, g, b(, a)]` in [0, 1] (default white).
   integer(int32),       intent(out), optional :: stat     !< Status.
   type(im_texture_ref)                        :: ref      !< Its reference.

   if (figure_draw_refused('pf_draw_image', stat)) return ! a task does not draw
   if (.not. texture%is_initialized()) then
      call figure_fail(FIG_ERR_ARGUMENT, 'pf_draw_image: the texture is not initialized', stat)
      return
   endif
   ref = texture_ref(texture)
   if (present(color)) then
      call draw('pf_draw_image', DRAW_IMAGE, [x1, x2], [y1, y2], color, texture=ref%TexID, stat=stat)
   else
      call draw('pf_draw_image', DRAW_IMAGE, [x1, x2], [y1, y2], [1.0_real64, 1.0_real64, 1.0_real64], &
                texture=ref%TexID, stat=stat)
   endif
   endsubroutine pf_draw_image

   function pf_draw_prim(kind, x, y, rgba, thickness, radius, filled, text, texture) result(status)
   !< One primitive of figure_canvas's `'plot'` layer, its arguments checked there (`fig_draw` on layer 4, through
   !< figure_plot_hooks: szaghi/figure#15, the seam's switch): 0, or -1 outside a plot (nothing drawn, nothing reported).
   integer(c_int),   intent(in) :: kind      !< DRAW_*.
   real(real64),     intent(in) :: x(:)      !< Abscissae [plot units].
   real(real64),     intent(in) :: y(:)      !< Ordinates [plot units].
   real(real64),     intent(in) :: rgba(4)   !< Colour, RGBA in [0, 1].
   real(real64),     intent(in) :: thickness !< Line thickness [pixels].
   real(real64),     intent(in) :: radius    !< A circle's radius [pixels].
   logical,          intent(in) :: filled    !< Filled (a polyline: closed).
   character(len=*), intent(in) :: text      !< Text (DRAW_TEXT).
   integer(int64),   intent(in) :: texture   !< ImTextureID (DRAW_IMAGE).
   integer(c_int)               :: status    !< Status.
   integer(int32)               :: en(6), sc(6) !< The plot's axes (pf_plot_state).

   status = -1_c_int
   if (pf_plot_state(en, sc) == 0_int32) return
   select case (kind)
   case (DRAW_TEXT)
      call draw('ig_draw_text', kind, x, y, rgba, thickness, radius, filled, text=text)
   case (DRAW_IMAGE)
      call draw('ig_draw_image', kind, x, y, rgba, thickness, radius, filled, texture=texture)
   case default
      call draw('ig_draw', kind, x, y, rgba, thickness, radius, filled)
   endselect
   status = 0_c_int
   endfunction pf_draw_prim

   ! ---- private ------------------------------------------------------------------------------------------------------
   subroutine draw(who, kind, x, y, color, thickness, radius, filled, text, texture, stat)
   !< Check the arguments of a primitive (figure_canvas's checks) and draw it in the open plot (`fig_draw` on the
   !< plot layer).
   character(len=*), intent(in)            :: who       !< The procedure.
   integer(c_int),   intent(in)            :: kind      !< DRAW_*.
   real(real64),     intent(in)            :: x(:)      !< Abscissae [plot units].
   real(real64),     intent(in)            :: y(:)      !< Ordinates [plot units].
   real(real64),     intent(in)            :: color(:)  !< Colour, `[r, g, b(, a)]` in [0, 1].
   real(real64),     intent(in), optional  :: thickness !< Line thickness [pixels].
   real(real64),     intent(in), optional  :: radius    !< A circle's radius [pixels].
   logical,          intent(in), optional  :: filled    !< Filled (a polyline: closed).
   character(len=*), intent(in), optional  :: text      !< Text.
   integer(int64),   intent(in), optional  :: texture   !< ImTextureID.
   integer(int32),   intent(out), optional :: stat      !< Status.
   real(real64)                            :: rgba(4)   !< Colour, RGBA.
   real(real64)                            :: t         !< Thickness.
   real(real64)                            :: r         !< Radius.
   logical                                 :: f         !< Filled.
   integer(int32)                          :: need      !< Points needed.
   integer(int32)                          :: i, n      !< Component, points.
   integer(int32)                          :: en(6), sc(6) !< The plot's axes (pf_plot_state).
   character(len=12)                       :: a, b      !< Numbers, written.

   if (figure_draw_refused(who, stat)) return ! a task does not draw
   if (size(color) /= 3 .and. size(color) /= 4) then
      call figure_fail(FIG_ERR_ARGUMENT, who//': color has 3 or 4 components', stat)
      return
   endif
   do i = 1_int32, int(size(color), int32)
      if (ieee_is_nan(color(i))) then ! apart: an ordered comparison of NaN traps under -ffpe-trap=invalid
         call figure_fail(FIG_ERR_ARGUMENT, who//': color components are in [0, 1]', stat)
         return
      endif
      if (color(i) < 0.0_real64 .or. color(i) > 1.0_real64) then
         call figure_fail(FIG_ERR_ARGUMENT, who//': color components are in [0, 1]', stat)
         return
      endif
   enddo
   if (size(x) /= size(y)) then
      write(a, '(I0)') size(x)
      write(b, '(I0)') size(y)
      call figure_fail(FIG_ERR_ARGUMENT, who//': x has '//trim(a)//' points, y '//trim(b), stat)
      return
   endif
   need = 1_int32
   if (kind == DRAW_LINE .or. kind == DRAW_RECT .or. kind == DRAW_POLYLINE .or. kind == DRAW_IMAGE) need = 2_int32
   if (kind == DRAW_POLYGON) need = 3_int32
   if (size(x) < need) then
      write(a, '(I0)') size(x)
      write(b, '(I0)') need
      call figure_fail(FIG_ERR_ARGUMENT, who//': '//trim(a)//' points, at least '//trim(b)//' needed', stat)
      return
   endif
   if (.not. coordinates_ok(who, x, 'x', stat)) return
   if (.not. coordinates_ok(who, y, 'y', stat)) return
   t = 1.0_real64
   if (present(thickness)) then
      if (.not. length_ok(thickness, .false.)) then
         call figure_fail(FIG_ERR_ARGUMENT, who//': thickness is not a finite length above 0', stat)
         return
      endif
      t = thickness
   endif
   if (pf_plot_state(en, sc) == 0_int32) then
      call figure_usage_error(who//': outside a plot (call it between a true pf_begin_plot and pf_end_plot)', stat)
      return
   endif
   r = 0.0_real64
   if (present(radius)) r = radius
   f = .false.
   if (present(filled)) f = filled
   rgba = 1.0_real64
   rgba(1:size(color)) = color
   n = size(x, kind=int32)
   if (n <= NFIX) then
      block
         real(real64) :: px(NFIX), py(NFIX) !< Pixels.
         call to_pixels(x, y, px(1:n), py(1:n))
         call render(px(1:n), py(1:n))
      endblock
   else
      block
         real(real64), allocatable :: px(:), py(:) !< Pixels.
         allocate(px(n), py(n))
         call to_pixels(x, y, px, py)
         call render(px, py)
      endblock
   endif
   if (present(stat)) stat = FIG_OK
   contains
      subroutine render(px, py)
      !< The primitive on the window's list, clipped to the plot's area (`PushPlotClipRect`, `PopPlotClipRect`).
      real(real64), intent(in) :: px(:), py(:) !< Pixels.
      real(real64)             :: c0, c1, d0, d1 !< The plot's area; a rectangle's corners.
      integer(int32)           :: col          !< Packed colour.

      col = packed(rgba)
      call pf_plot_rect(c0, d0, c1, d1)
      call core_draw_begin() ! what the frame has pending appended first
      call core_push_clip_rect(c0, d0, c1, d1)
      select case (kind)
      case (DRAW_LINE)
         call core_draw_line(px(1), py(1), px(2), py(2), col, t)
      case (DRAW_RECT)
         if (f) then
            call core_draw_rect_filled(min(px(1), px(2)), min(py(1), py(2)), max(px(1), px(2)), max(py(1), py(2)), col)
         else
            call core_draw_rect(min(px(1), px(2)), min(py(1), py(2)), max(px(1), px(2)), max(py(1), py(2)), col, &
                                thickness=t)
         endif
      case (DRAW_CIRCLE)
         call core_draw_circle(px(1), py(1), r, col, filled=f, thickness=t)
      case (DRAW_POLYLINE)
         call core_draw_polyline(px, py, col, thickness=t, closed=f)
      case (DRAW_POLYGON)
         if (f) then
            call core_draw_concave_poly_filled(px, py, col)
         else
            call core_draw_polyline(px, py, col, thickness=t, closed=.true.)
         endif
      case (DRAW_TEXT)
         call core_draw_text(px(1), py(1), col, text)
      case default ! DRAW_IMAGE: the texture's own filter around it (fig_draw's sampler callbacks)
         call core_texture_sampling(.true.)
         call core_draw_image(texture, min(px(1), px(2)), min(py(1), py(2)), max(px(1), px(2)), max(py(1), py(2)), &
                              col=col)
         call core_texture_sampling(.false.)
      endselect
      call core_pop_clip_rect()
      call core_draw_end()
      endsubroutine render
   endsubroutine draw

   subroutine to_pixels(x, y, px, py)
   !< Points in plot units to pixels on the current axes (`axis_to_pixel`, `to_pixel` of native/figure_canvas.cpp):
   !< `pf_plot_to_pixels`, kept within PIXEL_LIMIT of the display's origin.
   real(real64), intent(in)  :: x(:), y(:)   !< Points [plot units].
   real(real64), intent(out) :: px(:), py(:) !< Pixels.
   integer(int32)            :: k            !< Point.

   do k = 1_int32, size(x, kind=int32)
      call pf_plot_to_pixels(x(k), y(k), px(k), py(k))
      px(k) = min(max(px(k), -PIXEL_LIMIT), PIXEL_LIMIT)
      py(k) = min(max(py(k), -PIXEL_LIMIT), PIXEL_LIMIT)
   enddo
   endsubroutine to_pixels

   function packed(c) result(col)
   !< `ImGui::GetColorU32(ImVec4)`: the colour in single precision, its alpha times the style's.
   real(real64), intent(in) :: c(4)  !< RGBA.
   integer(int32)           :: col   !< Packed.
   real(real64)             :: sa(2) !< The style's Alpha.
   integer(int32)           :: na    !< Its values.
   real(real32)             :: a     !< Alpha, in float.

   call core_style_var('Alpha', sa, na)
   a = real(c(4), real32) * real(sa(1), real32)
   col = core_color(real(real(c(1), real32), real64), real(real(c(2), real32), real64), &
                    real(real(c(3), real32), real64), real(a, real64))
   endfunction packed

   function coordinates_ok(who, v, what, stat) result(ok)
   !< True when every value of `v` is finite and within single precision; else `FIG_ERR_ARGUMENT`, the message
   !< naming `what`.
   character(len=*), intent(in)            :: who  !< The procedure.
   real(real64),     intent(in)            :: v(:) !< Values.
   character(len=*), intent(in)            :: what !< Their name.
   integer(int32),   intent(out), optional :: stat !< Status, when refused.
   logical                                 :: ok   !< All usable.
   integer(int32)                          :: i    !< Counter.

   ok = .true.
   do i = 1_int32, int(size(v), int32)
      if (ieee_is_nan(v(i))) then
         ok = .false.
      elseif (abs(v(i)) > COORD_MAX) then
         ok = .false.
      endif
      if (.not. ok) exit
   enddo
   if (.not. ok) call figure_fail(FIG_ERR_ARGUMENT, who//': '//what//' must be finite and within single precision', &
                                  stat)
   endfunction coordinates_ok

   pure function length_ok(v, zero) result(ok)
   !< True when `v` is a finite length within single precision, above 0 (or, with `zero`, at least 0).
   real(real64), intent(in) :: v    !< Length [pixels].
   logical,      intent(in) :: zero !< 0 accepted.
   logical                  :: ok   !< Usable.

   ok = .false.
   if (ieee_is_nan(v)) return ! apart: an ordered comparison of NaN traps under -ffpe-trap=invalid
   if (v > COORD_MAX) return
   if (zero) then
      ok = v >= 0.0_real64
   else
      ok = v > 0.0_real64
   endif
   endfunction length_ok
endmodule figure_plot_draw
