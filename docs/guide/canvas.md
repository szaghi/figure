---
title: Canvas
---

# Canvas

A **canvas** is the way a Fortran program builds a widget FIGURE does not have: a sketch of the domain with its
boundary conditions, a gauge, a timeline. It has two parts. `ig_canvas` places an area of a given size that takes the
mouse and reports, every frame, what happened over it; the **drawing primitives** `ig_draw_*` draw lines, rectangles,
circles, polylines, polygons, text and images, on the canvas or anywhere else in the window, over every window, or
inside a [plot](plots) in the plot's own units. Hit testing is the program's: the canvas says where the pointer is,
the program decides what is under it.

The primitives draw on Dear ImGui's draw lists, which window, headless and remote mode all render, so a canvas works
in every mode, and the headless tests find what it drew by its colours ([Testing a canvas](#testing-a-canvas)).

<Media name="canvas_primitives" alt="A window Canvas primitives with eight cells in two rows, each a framed canvas with its call in grey below: a thick amber line (ig_draw_line(..., thickness=3)); an amber rectangle outline and a teal filled square (ig_draw_rect(..., filled=.true.)); an amber circle outline and a teal filled disc (ig_draw_circle(x, y, radius, ...)); an amber sine polyline (ig_draw_polyline(x(:), y(:), ...)); an amber heptagon outline and a teal filled arrow-head polygon (ig_draw_polygon(..., filled=.true.)); amber text 'inlet, u = 1 m/s' and teal text 'wall' over 'no slip' (ig_draw_text(x, y, text, ...)); a colour-gradient image twice, the second tinted red (ig_draw_image(tex, ..., color)); teal cross-hairs with an amber dot at the centre labelled ev%origin + [cx, cy] (ig_canvas(id, w, h, ev)). Below, under the heading layer='plot': plot units, clipped to the plot, a plot from 0 to 4 m with a red sine line, a teal rectangle from (0, 0) to (4, 1) and an amber disc at (1, 0.5) labelled probe at (1, 0.5) m" caption="docs/examples/src/gallery.F90, run with canvas_primitives" />

## The canvas

| Procedure | Notes |
|---|---|
| `ig_canvas(id, width, height, ev [, texture] [, stat])` | An area that takes the three mouse buttons and the wheel (`InvisibleButton`, `SetItemKeyOwner`); `ev` receives what happened over it on this frame. |
| `ig_invisible_button(id, width, height [, stat])` → `logical` | A button that draws nothing (`InvisibleButton`): `.true.` on the frame it is clicked with the left button. |
| `ig_cursor_screen_pos(x, y)` | Where the next item goes, in screen pixels (`GetCursorScreenPos`). |

`width` and `height` are pixels; a size of 0 or below is the space left in the window plus it (0: all of it, `-10`:
all but 10 pixels), at least 1 pixel. The canvas is one item: `ig_last_item`, `ig_same_line`,
[tooltips](widgets#tooltips) and [context menus](menus#context-menus) apply to it as to a button. With `texture`, the
[texture](images) is drawn over the whole canvas before the program draws on it: a computed image with marks on top.

`ev` is a `canvas_event_object`, a plain value filled on every call:

| Field | Type | Meaning |
|---|---|---|
| `hovered` | `logical` | the pointer is over the canvas, and no other item is held |
| `active` | `logical` | a button pressed over the canvas is held (a drag goes on outside the canvas too) |
| `clicked(3)` | `logical` | a button was pressed over the canvas on this frame (left, right, middle) |
| `double_clicked(3)` | `logical` | a button was double-clicked over the canvas on this frame |
| `down(3)` | `logical` | a button pressed over the canvas is held |
| `released(3)` | `logical` | a button pressed over the canvas was released on this frame |
| `mouse(2)` | `real(real64)` | the pointer from the canvas's top-left [pixels], x right and y down; also outside the canvas (below 0 or beyond its size) |
| `drag(2)` | `real(real64)` | the pointer from where the held button was pressed [pixels]: while held, and on the frame of its release; 0 otherwise |
| `delta(2)` | `real(real64)` | the pointer's motion on this frame while a button is held [pixels] |
| `wheel`, `wheel_h` | `real(real64)` | vertical (positive away from the user) and horizontal wheel steps on this frame, while hovered; 0 otherwise |
| `ctrl`, `shift`, `alt`, `super` | `logical` | the modifiers held (`super`: cmd on macOS, the Windows key) |
| `origin(2)` | `real(real64)` | the canvas's top-left on the screen [pixels] |
| `size(2)` | `real(real64)` | its width and height [pixels] |

**The wheel is the canvas's** while the pointer is over it (Dear ImGui's key ownership, as the
[3-D view](view3d)): a window or a child holding the canvas does not scroll, so a canvas can zoom with the wheel
inside a scrolling form. Beside the canvas the wheel scrolls the window as usual.

The event states (`clicked`, `double_clicked`, `released`) are true on one frame: the frame of the event, the frame
the program reads them. A press is reported on the frame of the press (a drag starts there); for a click that must be
released over the canvas, as a button's, use `ig_invisible_button` or test `released` together with `hovered`.

<<< @/examples/snippets/cb_canvas-canvas.F90{fortran}

- **Pairing and frame rules:** none opens a scope; call them in a window, between `next_frame` and the next one.
  Read `ev` on the frame `ig_canvas` filled it.
- **Status:** `stat` is optional. A size NaN, infinite or beyond single precision, or a texture not initialized, is
  `FIG_ERR_ARGUMENT`: nothing placed, `ev` empty (absent `stat`: `error stop` with the message). With no frame open,
  or from a [task](processes#tasks), each is refused with `FIG_ERR_STATE`, as every drawing call. Messages:
  [Error handling](errors#canvas).
- **Window, headless, remote:** the same; headless, `test_mouse_move`, `test_click`, `test_drag` and `test_wheel`
  drive the canvas ([Testing a canvas](#testing-a-canvas)).
- **Threads:** the frame loop's thread only; a task is refused (`FIG_ERR_STATE`).

## Coordinates

Three systems, and each call says which it takes:

| System | Origin and axes | Used by |
|---|---|---|
| **screen pixels** | the display's top-left, x right, y down | the primitives on the `'window'`, `'foreground'` and `'background'` layers; `ev%origin`; `ig_cursor_screen_pos`; `ig_last_item`'s `rect`; the testing procedures |
| **canvas pixels** | the canvas's top-left, x right, y down | `ev%mouse` |
| **plot units** | the plot's axes, as its data | the primitives on the `'plot'` layer |

A point (`cx`, `cy`) of a canvas is drawn at `ev%origin(1) + cx`, `ev%origin(2) + cy`. A program with its own units
(metres, seconds) maps them to canvas pixels itself, and back for the pointer: the domain sketch above keeps y up by
`py(y) = origin + ... - y * scale`. Lengths (`thickness`, `radius`) are pixels on every layer, also on the plot layer.
`ig_cursor_screen_pos` gives where the next item goes, so a program can draw at that place and then reserve it with
`ig_dummy` or an invisible button.

## Layers

| `layer` | Draws on | Coordinates | Clipped to |
|---|---|---|---|
| `'window'` (default) | the current window's draw list: over what the window drew before, under what it draws after | screen pixels | the window (its scrolling region) |
| `'foreground'` | the display's foreground list: over every window | screen pixels | nothing |
| `'background'` | the display's background list: under every window | screen pixels | nothing |
| `'plot'` | the current plot's draw list, between a true `ip_begin_plot` and `ip_end_plot` | plot units | the plot area |

The window layer is the canvas's: what is drawn there scrolls with the window and hides behind the windows in front.
The foreground layer draws over everything, popups included: a marker that follows the pointer across windows, a
highlight of a window's place in a tour. The background layer is under every window, on the display's background.

**The plot layer** places a shape in the data's units inside a plot (`ImPlot::GetPlotDrawList`, `PlotToPixels`,
`PushPlotClipRect`): a probe's position, the outline of the domain over a field, a band of interest. It moves and
scales with the plot's limits when the user pans and zooms, and it is clipped to the plot area. Call the primitives
after the plot's setup (`ip_setup_axes`, `ip_setup_axes_limits`): the first primitive ends the setup, as the first
item does. Outside a plot it is a usage error, `FIG_ERR_STATE`.

<<< @/examples/snippets/gallery-plot_layer.F90{fortran}

## Primitives

| Procedure | Draws (upstream) |
|---|---|
| `ig_draw_line(x1, y1, x2, y2, color [, thickness] [, layer] [, stat])` | a segment (`ImDrawList::AddLine`) |
| `ig_draw_rect(x1, y1, x2, y2, color [, thickness] [, filled] [, layer] [, stat])` | a rectangle with opposite corners in any order, outline or filled (`AddRect`, `AddRectFilled`) |
| `ig_draw_circle(x, y, radius, color [, thickness] [, filled] [, layer] [, stat])` | a circle, its centre at the point and its radius in pixels, outline or filled (`AddCircle`, `AddCircleFilled`) |
| `ig_draw_polyline(x, y, color [, thickness] [, closed] [, layer] [, stat])` | a polyline through `x(i)`, `y(i)`; `closed` joins the last point to the first (`AddPolyline`) |
| `ig_draw_polygon(x, y, color [, thickness] [, filled] [, layer] [, stat])` | a closed polygon, outline or filled, convex or not (`AddPolyline` closed, `AddConcavePolyFilled`) |
| `ig_draw_text(x, y, text, color [, layer] [, stat])` | `text` in the current font, its top-left at the point; a line per LF (`AddText`) |
| `ig_draw_image(texture, x1, y1, x2, y2 [, color] [, layer] [, stat])` | a [texture](images) stretched over a rectangle, pixel row 1 at the top, multiplied by `color` (default white) (`AddImage`) |

Coordinates are `real(real64)`: screen pixels, or plot units on the plot layer ([Coordinates](#coordinates)).
`thickness` is in pixels, default 1; `filled` defaults to the outline. `x(:)` and `y(:)` of a polyline or a polygon are
arrays of the same size, at least 2 and 3 points: a contiguous array goes to the native layer without a copy (a
strided section is packed by the compiler). A circle's radius is pixels on every layer: a marker. A circle in plot
units is a polygon through its points.

<<< @/examples/snippets/cb_canvas-draw.F90{fortran}

**Colours** are `[r, g, b]` or `[r, g, b, a]` in [0, 1], as the rest of FIGURE (`ig_text_colored`,
`ig_table_row_color`); `a` defaults to 1, and the style's global alpha multiplies it. A colour carries meaning only
together with a mark or a word: the domain sketch writes each boundary's name beside it in its colour. The style's
own colours are given by `ig_get_style_color` and `app%palette_color`, so a drawing can follow the theme.

**Nothing is kept between frames:** a primitive draws on the frame it is called. Draw every frame, as every widget
is declared every frame.

- **Pairing and frame rules:** none opens a scope. Plot layer: between a true `ip_begin_plot` and `ip_end_plot`.
- **Status:** `stat` is optional. A wrong argument is `FIG_ERR_ARGUMENT`, nothing drawn (absent `stat`: `error stop`
  with the message): an unknown layer; a colour not of 3 or 4 components in [0, 1]; `x` and `y` of different sizes
  or too few points; a coordinate NaN, infinite or beyond single precision; a thickness not above 0; a radius below
  0; a texture not initialized. The plot layer outside a plot, no frame open, or a call from a task: `FIG_ERR_STATE`,
  a usage error. Messages: [Error handling](errors#canvas).
- **Window, headless, remote:** the same. Remote mode sends the draw lists to the browser as every widget's; images
  go as textures.
- **Threads:** the frame loop's thread only; a task is refused (`FIG_ERR_STATE`).

## Testing a canvas

A canvas is tested headless as any widget: `test_mouse_move`, `test_click(x, y [, button])`, `test_drag` and
`test_wheel` drive it ([Headless testing](testing#synthetic-input)), at screen pixels computed from `ev%origin`. What
the primitives drew is found by `test_drawn_extent(color, ...)`, the extent of the vertices drawn so far in that
colour: give each primitive a colour of its own. `layer='foreground'` or `'background'` looks on those layers (the
window and plot layers are the window's own list); `vertices` gives how many vertices have the colour, which tells a
filled shape (a vertex per corner) from its outline. `src/tests/figure_test_canvas.F90` checks every primitive this
way, a drag's delta, the wheel kept from a scrolling child, and a polyline in plot units that moves with the limits.

## What it does not do

- **No hit testing of shapes:** the canvas reports the pointer; which shape is under it is the program's computation
  (the domain sketch's `nearest`). An invisible button over a shape gives a rectangular hot zone.
- **No clipping to the canvas:** primitives on the window layer are clipped to the window, not to the canvas; keep
  them inside it, or draw a shape that ends at its border.
- **No retained scene:** nothing is stored; a drawing of thousands of primitives costs that many calls every frame.
  For a field use a [heatmap or an image](images); for many points, a [plot](plots).
- **No transforms, gradients, dashes or rounded corners:** coordinates go as given; a dashed line is segments; a
  transform is the program's mapping. Rounded rectangles, Bézier curves and gradients are in Dear ImGui's draw list,
  which neither the primitives nor the [raw bindings](raw-bindings) reach: cimgui's `ImDrawList_*` C functions need a
  `bind(C)` interface written by the program (`igGetWindowDrawList` gives the list).
- **No font size per call:** text is drawn in the current font ([Fonts](styles#fonts)).
- **Plot layer limits:** the radius and the thickness stay in pixels; a point farther than 10⁷ pixels from the
  display's origin (a strong zoom) is drawn at that distance, which bends a line from a point in view to it; on a
  logarithmic axis a value at or below 0 is taken as the smallest positive `real64` (ImPlot's rule), far below the
  plot.
- **No keyboard input:** the canvas takes the mouse, not the keyboard focus; keys reach the program through
  [shortcuts](menus#shortcuts) of the window holding it.
