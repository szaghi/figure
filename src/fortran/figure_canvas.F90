!< figure_canvas, an area that takes the mouse and drawing primitives: the way to build a widget FIGURE does not have.
module figure_canvas
!< figure_canvas, an area that takes the mouse and drawing primitives: the way to build a widget FIGURE does not have.
!<
!< `ig_canvas` places an item of a given size that takes the three mouse buttons and the wheel, and fills a
!< `canvas_event_object` with what happened over it on the frame; the `ig_draw_*` primitives draw lines, rectangles,
!< circles, polylines, polygons, text and images on one of four layers:
!< - `'window'` (default): the current window's draw list, in screen pixels, clipped to the window, drawn over what the
!<   window drew before and under what it draws after;
!< - `'foreground'` / `'background'`: over / under every window of the display, in screen pixels, not clipped;
!< - `'plot'`: the current ImPlot plot, in plot units (the plot's axes), clipped to the plot area.
!<
!< Coordinates: screen pixels from the display's top-left, x right and y down (as `ig_cursor_screen_pos`,
!< `ig_last_item`'s rectangle and the canvas's `origin`); the canvas's own pixels (the event's `mouse`) are measured
!< from its top-left, so a point (cx, cy) of the canvas is drawn at `ev%origin + [cx, cy]`. Lengths (thickness,
!< radius) are pixels on every layer. Colours are `[r, g, b(, a)]` in [0, 1]. Nothing is kept between frames: draw
!< every frame, as every widget is declared every frame. Main thread only (a task's call is refused); the same in
!< window, headless and remote mode (draw lists are what all three render).
use, intrinsic :: iso_c_binding, only : c_double, c_int, c_long_long
use, intrinsic :: ieee_arithmetic, only : ieee_is_nan
use, intrinsic :: iso_fortran_env, only : int32, real32, real64
use figure_base, only : figure_check, figure_draw_refused, figure_fail, figure_usage_error
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_OK, fig_canvas, fig_canvas_event, fig_cursor_screen_pos, fig_draw, &
                            fig_invisible_button
use figure_cimgui, only : im_texture_ref
use figure_texture, only : texture_object, texture_ref

implicit none
private
public :: canvas_event_object, ig_canvas, ig_cursor_screen_pos, ig_invisible_button
public :: ig_draw_line, ig_draw_rect, ig_draw_circle, ig_draw_polyline, ig_draw_polygon, ig_draw_text, ig_draw_image

! Layers and primitives: must match native/figure_canvas.cpp's layer_t and kind_t.
integer(c_int), parameter :: LAYER_WINDOW = 1_c_int     !< The current window's draw list.
integer(c_int), parameter :: LAYER_FOREGROUND = 2_c_int !< Over every window.
integer(c_int), parameter :: LAYER_BACKGROUND = 3_c_int !< Under every window.
integer(c_int), parameter :: LAYER_PLOT = 4_c_int       !< The current plot, in plot units.
integer(c_int), parameter :: DRAW_LINE = 1_c_int        !< A segment.
integer(c_int), parameter :: DRAW_RECT = 2_c_int        !< A rectangle.
integer(c_int), parameter :: DRAW_CIRCLE = 3_c_int      !< A circle.
integer(c_int), parameter :: DRAW_POLYLINE = 4_c_int    !< A polyline.
integer(c_int), parameter :: DRAW_POLYGON = 5_c_int     !< A polygon.
integer(c_int), parameter :: DRAW_TEXT = 6_c_int        !< Text.
integer(c_int), parameter :: DRAW_IMAGE = 7_c_int       !< A texture.
real(real64),   parameter :: COORD_MAX = real(huge(1.0_real32), real64) !< The largest coordinate or length.

type :: canvas_event_object
   !< What happened over a canvas on a frame, as `ig_canvas` found it: a plain value. Per button the arrays are
   !< (left, right, middle). The event states (`clicked`, `double_clicked`, `released`) are true on one frame;
   !< `drag` and `delta` are zero unless a button pressed over the canvas is held (and `drag` also on its release);
   !< the wheel is zero unless the pointer is over the canvas. Positions: `mouse` in the canvas's pixels (from its
   !< top-left, x right, y down; outside the canvas too, then below 0 or beyond its size); `origin` on the screen.
   logical      :: hovered = .false.           !< The pointer is over the canvas (and no other item is held).
   logical      :: active = .false.            !< A button pressed over the canvas is held (a drag).
   logical      :: clicked(3) = .false.        !< A button was pressed over the canvas on this frame.
   logical      :: double_clicked(3) = .false. !< A button was double-clicked over the canvas on this frame.
   logical      :: down(3) = .false.           !< A button pressed over the canvas is held.
   logical      :: released(3) = .false.       !< A button pressed over the canvas was released on this frame.
   real(real64) :: mouse(2) = 0.0_real64       !< The pointer, from the canvas's top-left [pixels].
   real(real64) :: drag(2) = 0.0_real64        !< The pointer from where the held button was pressed [pixels].
   real(real64) :: delta(2) = 0.0_real64       !< The pointer's motion on this frame, while a button is held [pixels].
   real(real64) :: wheel = 0.0_real64          !< Vertical wheel steps on this frame (positive: away from the user).
   real(real64) :: wheel_h = 0.0_real64        !< Horizontal wheel steps on this frame.
   logical      :: ctrl = .false.              !< Ctrl held.
   logical      :: shift = .false.             !< Shift held.
   logical      :: alt = .false.               !< Alt held.
   logical      :: super = .false.             !< Super (cmd on macOS, the Windows key) held.
   real(real64) :: origin(2) = 0.0_real64      !< The canvas's top-left on the screen [pixels].
   real(real64) :: size(2) = 0.0_real64        !< Its width and height [pixels].
endtype canvas_event_object

contains
   recursive subroutine ig_canvas(id, width, height, ev, texture, stat)
   !< An area of `width` x `height` pixels that takes the mouse (Dear ImGui's `InvisibleButton` with the three buttons):
   !< `ev` receives what happened over it on this frame (`canvas_event_object`). While the pointer is over it the
   !< canvas owns the wheel (`SetItemKeyOwner`): a scrolling window or child holding it does not scroll. With
   !< `texture`, the texture is drawn over the whole canvas first, so that primitives drawn after it are on top. A
   !< size <= 0 is the space left plus it (0: all of it, -10: all but 10 pixels), at least 1 pixel. The canvas is one
   !< item: `ig_last_item`, `ig_same_line` and the context menus apply to it. Draw on it with the `ig_draw_*`
   !< primitives at `ev%origin + [cx, cy]`. A NaN or infinite size, or a texture not initialized: nothing placed,
   !< `ev` empty, `FIG_ERR_ARGUMENT` in `stat` (or `error stop` without it). No frame open or a task: `FIG_ERR_STATE`.
   !< The same in window, headless and remote mode.
   character(len=*),          intent(in)            :: id      !< Its id (unique in the window, not shown).
   real(real64),              intent(in)            :: width   !< Width [pixels] (<= 0: the space left plus it).
   real(real64),              intent(in)            :: height  !< Height [pixels] (<= 0: the space left plus it).
   type(canvas_event_object), intent(out)           :: ev      !< What happened over it on this frame.
   type(texture_object),      intent(in), optional  :: texture !< A texture drawn over the whole canvas.
   integer(int32),            intent(out), optional :: stat    !< Status.
   type(fig_canvas_event)                           :: c       !< C copy of the event.
   type(im_texture_ref)                             :: ref     !< The texture's reference.
   integer(c_long_long)                             :: tex     !< ImTextureID (0: none).
   integer(c_int)                                   :: status  !< Native status.

   if (figure_draw_refused('ig_canvas', stat)) return ! a task does not draw
   if (.not. coordinates_ok('ig_canvas', [width, height], 'width and height', stat)) return
   tex = 0_c_long_long
   if (present(texture)) then
      if (.not. texture%is_initialized()) then
         call figure_fail(FIG_ERR_ARGUMENT, 'ig_canvas: the texture is not initialized', stat)
         return
      endif
      ref = texture_ref(texture)
      tex = ref%TexID
   endif
   status = fig_canvas(id, len(id, c_int), real(width, c_double), real(height, c_double), tex, c)
   call figure_check(status, stat)
   if (status /= FIG_OK) return
   ev%hovered = c%hovered /= 0_c_int
   ev%active = c%active /= 0_c_int
   ev%clicked = c%clicked /= 0_c_int
   ev%double_clicked = c%double_clicked /= 0_c_int
   ev%down = c%down /= 0_c_int
   ev%released = c%released /= 0_c_int
   ev%mouse = real(c%mouse, real64)
   ev%drag = real(c%drag, real64)
   ev%delta = real(c%delta, real64)
   ev%wheel = real(c%wheel, real64)
   ev%wheel_h = real(c%wheel_h, real64)
   ev%ctrl = c%ctrl /= 0_c_int
   ev%shift = c%shift /= 0_c_int
   ev%alt = c%alt /= 0_c_int
   ev%super = c%super /= 0_c_int
   ev%origin = real(c%origin, real64)
   ev%size = real(c%size, real64)
   endsubroutine ig_canvas

   recursive function ig_invisible_button(id, width, height, stat) result(clicked)
   !< A button that draws nothing (Dear ImGui's `InvisibleButton`): true on the frame it is clicked with the left
   !< button (pressed and released over it). It is an item like any other (`ig_last_item` gives its hovered and active
   !< states and its rectangle): a hot zone over something drawn with the `ig_draw_*` primitives. A size <= 0 is the
   !< space left plus it, at least 1 pixel. A NaN or infinite size: false, `FIG_ERR_ARGUMENT` in `stat` (or
   !< `error stop` without it); no frame open or a task: `FIG_ERR_STATE`. The same in window, headless and remote mode.
   character(len=*), intent(in)            :: id      !< Its id (unique in the window, not shown).
   real(real64),     intent(in)            :: width   !< Width [pixels] (<= 0: the space left plus it).
   real(real64),     intent(in)            :: height  !< Height [pixels] (<= 0: the space left plus it).
   integer(int32),   intent(out), optional :: stat    !< Status.
   logical                                 :: clicked !< Clicked on this frame.
   integer(c_int)                          :: pressed !< 1: clicked.
   integer(c_int)                          :: status  !< Native status.

   clicked = .false.
   if (figure_draw_refused('ig_invisible_button', stat)) return ! a task does not draw
   if (.not. coordinates_ok('ig_invisible_button', [width, height], 'width and height', stat)) return
   status = fig_invisible_button(id, len(id, c_int), real(width, c_double), real(height, c_double), pressed)
   call figure_check(status, stat)
   clicked = status == FIG_OK .and. pressed /= 0_c_int
   endfunction ig_invisible_button

   recursive subroutine ig_cursor_screen_pos(x, y)
   !< Where the next item goes, on the screen [pixels] (Dear ImGui's `GetCursorScreenPos`): the top-left of the next
   !< widget or canvas, the origin to draw from with the `ig_draw_*` primitives before placing an item there. No frame
   !< open or a task: zeros (a usage error, reported by `app%next_frame`).
   real(real64), intent(out) :: x !< Abscissa [pixels from the display's left].
   real(real64), intent(out) :: y !< Ordinate [pixels from the display's top].
   real(c_double)            :: cx !< C copy.
   real(c_double)            :: cy !< C copy.

   x = 0.0_real64
   y = 0.0_real64
   if (figure_draw_refused('ig_cursor_screen_pos')) return ! a task does not draw
   call fig_cursor_screen_pos(cx, cy)
   x = real(cx, real64)
   y = real(cy, real64)
   endsubroutine ig_cursor_screen_pos

   recursive subroutine ig_draw_line(x1, y1, x2, y2, color, thickness, layer, stat)
   !< A segment from (`x1`, `y1`) to (`x2`, `y2`) (`ImDrawList::AddLine`): screen pixels, or plot units on the
   !< `'plot'` layer. Refusals: see `ig_draw_polyline`.
   real(real64),     intent(in)            :: x1        !< Start, abscissa [pixels or plot units].
   real(real64),     intent(in)            :: y1        !< Start, ordinate [pixels or plot units].
   real(real64),     intent(in)            :: x2        !< End, abscissa [pixels or plot units].
   real(real64),     intent(in)            :: y2        !< End, ordinate [pixels or plot units].
   real(real64),     intent(in)            :: color(:)  !< Colour, `[r, g, b(, a)]` in [0, 1].
   real(real64),     intent(in), optional  :: thickness !< Line thickness [pixels] (default 1).
   character(len=*), intent(in), optional  :: layer     !< `'window'` (default), `'foreground'`, `'background'`, `'plot'`.
   integer(int32),   intent(out), optional :: stat      !< Status.

   call draw('ig_draw_line', DRAW_LINE, [x1, x2], [y1, y2], color, thickness, layer=layer, stat=stat)
   endsubroutine ig_draw_line

   recursive subroutine ig_draw_rect(x1, y1, x2, y2, color, thickness, filled, layer, stat)
   !< A rectangle with opposite corners (`x1`, `y1`) and (`x2`, `y2`), in any order (`ImDrawList::AddRect`,
   !< `AddRectFilled`): its outline, or filled. Screen pixels, or plot units on the `'plot'` layer. Refusals: see
   !< `ig_draw_polyline`.
   real(real64),     intent(in)            :: x1        !< A corner, abscissa [pixels or plot units].
   real(real64),     intent(in)            :: y1        !< A corner, ordinate [pixels or plot units].
   real(real64),     intent(in)            :: x2        !< The opposite corner, abscissa [pixels or plot units].
   real(real64),     intent(in)            :: y2        !< The opposite corner, ordinate [pixels or plot units].
   real(real64),     intent(in)            :: color(:)  !< Colour, `[r, g, b(, a)]` in [0, 1].
   real(real64),     intent(in), optional  :: thickness !< Outline thickness [pixels] (default 1).
   logical,          intent(in), optional  :: filled    !< Filled (default: the outline).
   character(len=*), intent(in), optional  :: layer     !< `'window'` (default), `'foreground'`, `'background'`, `'plot'`.
   integer(int32),   intent(out), optional :: stat      !< Status.

   call draw('ig_draw_rect', DRAW_RECT, [x1, x2], [y1, y2], color, thickness, filled=filled, layer=layer, stat=stat)
   endsubroutine ig_draw_rect

   recursive subroutine ig_draw_circle(x, y, radius, color, thickness, filled, layer, stat)
   !< A circle centred at (`x`, `y`) (`ImDrawList::AddCircle`, `AddCircleFilled`): its outline, or filled. The centre
   !< in screen pixels, or plot units on the `'plot'` layer; the radius always in pixels (a marker, not a shape in plot
   !< units: a circle in plot units is a polygon of its points). Refusals: see `ig_draw_polyline`, and a radius below
   !< 0 or not finite.
   real(real64),     intent(in)            :: x         !< Centre, abscissa [pixels or plot units].
   real(real64),     intent(in)            :: y         !< Centre, ordinate [pixels or plot units].
   real(real64),     intent(in)            :: radius    !< Radius [pixels].
   real(real64),     intent(in)            :: color(:)  !< Colour, `[r, g, b(, a)]` in [0, 1].
   real(real64),     intent(in), optional  :: thickness !< Outline thickness [pixels] (default 1).
   logical,          intent(in), optional  :: filled    !< Filled (default: the outline).
   character(len=*), intent(in), optional  :: layer     !< `'window'` (default), `'foreground'`, `'background'`, `'plot'`.
   integer(int32),   intent(out), optional :: stat      !< Status.

   if (figure_draw_refused('ig_draw_circle', stat)) return ! a task does not draw
   if (.not. length_ok(radius, .true.)) then ! NaN tested apart: an ordered comparison of NaN traps (FPE invalid)
      call figure_fail(FIG_ERR_ARGUMENT, 'ig_draw_circle: radius is not a finite length >= 0', stat)
      return
   endif
   call draw('ig_draw_circle', DRAW_CIRCLE, [x], [y], color, thickness, radius=radius, filled=filled, layer=layer, &
             stat=stat)
   endsubroutine ig_draw_circle

   recursive subroutine ig_draw_polyline(x, y, color, thickness, closed, layer, stat)
   !< A polyline through the points (`x(i)`, `y(i)`) (`ImDrawList::AddPolyline`); `closed` joins the last point to the
   !< first. Screen pixels, or plot units on the `'plot'` layer. `x` and `y` are passed to the native layer without a
   !< copy when contiguous (a strided section is packed by the compiler). Refused with `FIG_ERR_ARGUMENT` in `stat` (or
   !< `error stop` without it), nothing drawn, for every primitive: `x` and `y` of different sizes or fewer points than
   !< the primitive needs (2 here), a coordinate NaN, infinite or beyond single precision, a colour not of 3 or 4
   !< components in [0, 1], a thickness not above 0, an unknown layer. A `'plot'` layer outside a plot (between a true
   !< `ip_begin_plot` and `ip_end_plot`), no frame open or a task: `FIG_ERR_STATE`, a usage error. The same in
   !< window, headless and remote mode.
   real(real64),     intent(in)            :: x(:)      !< Abscissae [pixels or plot units].
   real(real64),     intent(in)            :: y(:)      !< Ordinates [pixels or plot units].
   real(real64),     intent(in)            :: color(:)  !< Colour, `[r, g, b(, a)]` in [0, 1].
   real(real64),     intent(in), optional  :: thickness !< Line thickness [pixels] (default 1).
   logical,          intent(in), optional  :: closed    !< Join the last point to the first (default false).
   character(len=*), intent(in), optional  :: layer     !< `'window'` (default), `'foreground'`, `'background'`, `'plot'`.
   integer(int32),   intent(out), optional :: stat      !< Status.

   call draw('ig_draw_polyline', DRAW_POLYLINE, x, y, color, thickness, filled=closed, layer=layer, stat=stat)
   endsubroutine ig_draw_polyline

   recursive subroutine ig_draw_polygon(x, y, color, thickness, filled, layer, stat)
   !< A closed polygon through the points (`x(i)`, `y(i)`) (`ImDrawList::AddPolyline` closed, or
   !< `AddConcavePolyFilled`): its outline, or filled (convex or not; not self-intersecting). Screen pixels, or plot
   !< units on the `'plot'` layer. At least 3 points. Refusals: see `ig_draw_polyline`.
   real(real64),     intent(in)            :: x(:)      !< Abscissae [pixels or plot units].
   real(real64),     intent(in)            :: y(:)      !< Ordinates [pixels or plot units].
   real(real64),     intent(in)            :: color(:)  !< Colour, `[r, g, b(, a)]` in [0, 1].
   real(real64),     intent(in), optional  :: thickness !< Outline thickness [pixels] (default 1).
   logical,          intent(in), optional  :: filled    !< Filled (default: the outline).
   character(len=*), intent(in), optional  :: layer     !< `'window'` (default), `'foreground'`, `'background'`, `'plot'`.
   integer(int32),   intent(out), optional :: stat      !< Status.

   call draw('ig_draw_polygon', DRAW_POLYGON, x, y, color, thickness, filled=filled, layer=layer, stat=stat)
   endsubroutine ig_draw_polygon

   recursive subroutine ig_draw_text(x, y, text, color, layer, stat)
   !< `text` with its top-left at (`x`, `y`) (`ImDrawList::AddText`), in the current font: screen pixels, or plot
   !< units on the `'plot'` layer. One line per LF. Refusals: see `ig_draw_polyline`.
   real(real64),     intent(in)            :: x        !< Top-left, abscissa [pixels or plot units].
   real(real64),     intent(in)            :: y        !< Top-left, ordinate [pixels or plot units].
   character(len=*), intent(in)            :: text     !< Text (UTF-8).
   real(real64),     intent(in)            :: color(:) !< Colour, `[r, g, b(, a)]` in [0, 1].
   character(len=*), intent(in), optional  :: layer    !< `'window'` (default), `'foreground'`, `'background'`, `'plot'`.
   integer(int32),   intent(out), optional :: stat     !< Status.

   call draw('ig_draw_text', DRAW_TEXT, [x], [y], color, text=text, layer=layer, stat=stat)
   endsubroutine ig_draw_text

   recursive subroutine ig_draw_image(texture, x1, y1, x2, y2, color, layer, stat)
   !< A texture stretched over the rectangle with opposite corners (`x1`, `y1`) and (`x2`, `y2`), in any order
   !< (`ImDrawList::AddImage`), its pixel row 1 at the top; `color` multiplies its pixels (default white: as they
   !< are). Screen pixels, or plot units on the `'plot'` layer. Refusals: see `ig_draw_polyline`, and a texture not
   !< initialized.
   type(texture_object), intent(in)            :: texture  !< The texture.
   real(real64),         intent(in)            :: x1       !< A corner, abscissa [pixels or plot units].
   real(real64),         intent(in)            :: y1       !< A corner, ordinate [pixels or plot units].
   real(real64),         intent(in)            :: x2       !< The opposite corner, abscissa [pixels or plot units].
   real(real64),         intent(in)            :: y2       !< The opposite corner, ordinate [pixels or plot units].
   real(real64),         intent(in), optional  :: color(:) !< Tint, `[r, g, b(, a)]` in [0, 1] (default white).
   character(len=*),     intent(in), optional  :: layer    !< `'window'` (default), `'foreground'`, `'background'`,
                                                           !< `'plot'`.
   integer(int32),       intent(out), optional :: stat     !< Status.
   type(im_texture_ref)                        :: ref      !< Its reference.

   if (figure_draw_refused('ig_draw_image', stat)) return ! a task does not draw
   if (.not. texture%is_initialized()) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ig_draw_image: the texture is not initialized', stat)
      return
   endif
   ref = texture_ref(texture)
   if (present(color)) then
      call draw('ig_draw_image', DRAW_IMAGE, [x1, x2], [y1, y2], color, layer=layer, texture=ref%TexID, stat=stat)
   else
      call draw('ig_draw_image', DRAW_IMAGE, [x1, x2], [y1, y2], [1.0_real64, 1.0_real64, 1.0_real64], layer=layer, &
                texture=ref%TexID, stat=stat)
   endif
   endsubroutine ig_draw_image

   ! ---- private ------------------------------------------------------------------------------------------------------
   recursive subroutine draw(who, kind, x, y, color, thickness, radius, filled, text, layer, texture, stat)
   !< Check the arguments of a primitive and draw it: `FIG_ERR_ARGUMENT` for a wrong one, `FIG_ERR_STATE` (a usage
   !< error) for the plot layer outside a plot, no frame or a task.
   character(len=*),     intent(in)            :: who       !< The procedure.
   integer(c_int),       intent(in)            :: kind      !< DRAW_*.
   real(real64),         intent(in)            :: x(:)      !< Abscissae.
   real(real64),         intent(in)            :: y(:)      !< Ordinates.
   real(real64),         intent(in)            :: color(:)  !< Colour, `[r, g, b(, a)]` in [0, 1].
   real(real64),         intent(in), optional  :: thickness !< Line thickness [pixels].
   real(real64),         intent(in), optional  :: radius    !< A circle's radius [pixels].
   logical,              intent(in), optional  :: filled    !< Filled (a polyline: closed).
   character(len=*),     intent(in), optional  :: text      !< Text.
   character(len=*),     intent(in), optional  :: layer     !< Layer name.
   integer(c_long_long), intent(in), optional  :: texture   !< ImTextureID.
   integer(int32),       intent(out), optional :: stat      !< Status.
   real(c_double)                              :: rgba(4)   !< Colour, RGBA.
   real(c_double)                              :: t         !< Thickness.
   real(c_double)                              :: r         !< Radius.
   integer(c_int)                              :: f         !< Filled flag.
   integer(c_int)                              :: l         !< Layer code.
   integer(c_int)                              :: status    !< Native status.
   integer(int32)                              :: need      !< Points needed.
   integer(int32)                              :: i         !< Component.
   character(len=12)                           :: a         !< A number, written.
   character(len=12)                           :: b         !< Another.

   if (figure_draw_refused(who, stat)) return ! a task does not draw
   l = LAYER_WINDOW
   if (present(layer)) then
      select case (layer)
      case ('window')
         l = LAYER_WINDOW
      case ('foreground')
         l = LAYER_FOREGROUND
      case ('background')
         l = LAYER_BACKGROUND
      case ('plot')
         l = LAYER_PLOT
      case default
         call figure_fail(FIG_ERR_ARGUMENT, who//": unknown layer '"//layer// &
                          "' ('window', 'foreground', 'background' or 'plot')", stat)
         return
      endselect
   endif
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
   t = 1.0_c_double
   if (present(thickness)) then
      if (.not. length_ok(thickness, .false.)) then
         call figure_fail(FIG_ERR_ARGUMENT, who//': thickness is not a finite length above 0', stat)
         return
      endif
      t = real(thickness, c_double)
   endif
   r = 0.0_c_double
   if (present(radius)) r = real(radius, c_double)
   f = 0_c_int
   if (present(filled)) f = merge(1_c_int, 0_c_int, filled)
   rgba = 1.0_c_double
   rgba(1:size(color)) = real(color, c_double)
   if (present(text)) then
      status = fig_draw(kind, l, x, y, int(size(x), c_int), rgba, t, r, f, text, len(text, c_int), 0_c_long_long)
   elseif (present(texture)) then
      status = fig_draw(kind, l, x, y, int(size(x), c_int), rgba, t, r, f, '', 0_c_int, texture)
   else
      status = fig_draw(kind, l, x, y, int(size(x), c_int), rgba, t, r, f, '', 0_c_int, 0_c_long_long)
   endif
   if (status == -1_c_int) then
      call figure_usage_error(who//": layer 'plot' outside a plot (call it between a true ip_begin_plot and "// &
                              "ip_end_plot)", stat)
      return
   endif
   call figure_check(status, stat)
   endsubroutine draw

   recursive function coordinates_ok(who, v, what, stat) result(ok)
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
endmodule figure_canvas
