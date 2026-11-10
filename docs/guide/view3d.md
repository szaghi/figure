---
title: 3-D views
---

# 3-D views

A **3-D view** (`view3d_object`) shows meshes in perspective: triangles, quads, structured surfaces (a grid's face, a
body's patch) and lines. Each mesh is coloured by a field through a [colormap](colormaps) or drawn in one colour. The
user turns, moves and zooms the camera with the mouse, and clicks an element to pick it. The view is a widget: it is
drawn inside any window, beside other widgets.

FIGURE renders the view itself, on the CPU: a **software rasterizer** in the native layer draws the triangles into an
image, which is shown as a [texture](images). So the pixels are the same in window, remote and headless modes, and
tests check them one by one.

<Media name="cb_view3d" alt="A window titled Body. A row of buttons (+x, -y, +z, Fit), a ticked check box 'grid', a check box 'cut at z = 0' and a text 'cell (26, 19): Cp = -0.635 at (2.02 -0.37 0.37)'. Below, a slender body drawn with its grid lines, coloured from blue at the middle to red at both ends, with a yellow line through it along its axis. In the video the body turns under a drag, comes closer with the wheel, a click on it fills the text with the cell clicked, then the check box cuts away the half above z = 0." caption="docs/examples/src/cb_view3d.F90" />

## Procedures

| Procedure | Notes |
|---|---|
| `v%init([threads] [, fast_moves] [, lighting] [, background] [, stat])` | create the view, after `app%init*`: `threads` in [1, 4] (default 1), half resolution while the user moves the camera (default `.true.`), shading by a light at the eye (default `.true.`), background `[r, g, b]` (default: the style's window background) |
| `v%destroy()`, `v%is_initialized()` → `logical` | release the view and its textures (any state); whether it exists |
| `v%triangles(xyz, tri [, scalar] [, cell_scalar] [, colormap] [, color] [, edges] [, flat] [, stat])` → `int32` | add triangles: `real(real64) :: xyz(3, nv)`, `integer(int32) :: tri(3, nt)` (from 1); the mesh's id |
| `v%quads(xyz, quad [, ...])` → `int32` | add quadrilaterals, `quad(4, nq)`, each drawn as two triangles |
| `v%surface(xyz [, scalar] [, cell_scalar] [, ...])` → `int32` | add a structured surface, `xyz(3, ni, nj)`; `scalar(ni, nj)` per node, `cell_scalar(ni-1, nj-1)` per cell; `edges` draws its grid lines |
| `v%lines(xyz [, seg] [, scalar] [, cell_scalar] [, colormap] [, color] [, stat])` → `int32` | add lines: the segments `seg(2, ns)`, or the polyline through the points |
| `v%set_mesh(mesh [, scalar] [, cell_scalar] [, no_scalar] [, colormap] [, vmin, vmax] [, auto_range] [, color] [, edges] [, edge_color] [, flat] [, visible] [, stat])` | change a mesh's field, colormap, range, colours, edges, shading or visibility |
| `v%changed([mesh] [, stat])` | the program changed the mesh's arrays in place: derive it again and render |
| `v%remove(mesh [, stat])`, `v%clear([stat])` | remove a mesh, every mesh |
| `v%set_camera([target] [, distance] [, azimuth] [, elevation] [, fov] [, stat])`, `v%get_camera(...)` | the camera: the point looked at, the distance to it, the direction [degrees], the vertical field of view [degrees] |
| `v%fit([stat])`, `v%view(name [, stat])` | fit the meshes in the view; a standard view, `'+x'`, `'-x'`, `'+y'`, `'-y'`, `'+z'`, `'-z'` |
| `v%orbit(azimuth [, elevation] [, stat])`, `v%pan(right, up [, stat])`, `v%zoom(factor [, stat])` | turn the camera [degrees], move it across the screen [world units], bring it closer (`factor` > 1) |
| `v%clip(normal, point [, stat])`, `v%unclip([stat])` | cut away what lies behind a plane (up to 6); remove the planes |
| `v%draw(id [, width] [, height] [, stat])` | draw the view as a widget, `width` x `height` pixels (0: the available region; negative: up to that distance from its edge) |
| `v%pick(x, y, mesh, element [, point] [, stat])` → `logical` | the element under a pixel of the view (from its top-left corner) |
| `v%hovered(mesh, element [, point] [, stat])` → `logical`, `v%clicked(...)` → `logical` | the element under the mouse, the element clicked, in the last `draw` |
| `v%image(rgba [, stat])` | the pixels of the last render, `integer(int8), allocatable :: rgba(:,:,:)`, as `tex%update` takes them |
| `v%render_info([count] [, milliseconds] [, width] [, height] [, half] [, stat])` | the renders so far, the time and size of the last one, whether it was at half resolution |

Every procedure is refused from a [task](processes#tasks) (`FIG_ERR_STATE`), as the other drawing procedures are.

## Meshes

<<< @/examples/snippets/cb_view3d-setup.F90{fortran}

**Data in place.** A mesh keeps the addresses of the program's arrays (coordinates, connectivity, scalars) and reads
them at every render: nothing is copied per frame. So the arrays must:
- have the `target` (or `pointer`) attribute;
- be contiguous (a non-contiguous section is refused with `FIG_ERR_ARGUMENT`);
- stay allocated while the mesh exists: `v%remove` the mesh before deallocating them.

When the program changes their values (a new time step, a moved grid), it calls `v%changed(mesh)`. The view then
derives, once, what it keeps beside them:
- the triangle list, 0-based (the connectivity's indices are checked there);
- the edges;
- the vertex normals;
- the scalar's range.

It renders at the next `draw`. These derived arrays take about 12 bytes per vertex and 24 per triangle.

**Kinds.**
- **Triangles** and **quads** take a connectivity from 1, `tri(3, nt)` or `quad(4, nq)`; a quad's vertices go around
  it in order.
- **A structured surface** `xyz(3, ni, nj)` joins node `(i, j)` to its neighbours: a face of a structured block, an
  OverSet patch. Its cell `(i, j)` lies between nodes `(i, j)` and `(i+1, j+1)`.
- **Lines** are one pixel wide. They are drawn after the surfaces, slightly in front of them so that a line lying on a
  surface shows, and neither hide anything nor are picked.

Coordinates are `real(real64)` in any units; connectivity is `integer(int32)`.

**Edges.** `edges=.true.` draws a surface's grid lines (the cells' sides), in `edge_color` (default near black).

## Fields and colours

A mesh with `scalar` (one value per vertex) is coloured by the colormap at each vertex, and the colours are blended
across the triangles. With `cell_scalar` (one value per cell: triangle, quad, structured cell, segment) each cell has
one colour. The colormap is any name [`ip_colormap`](colormaps) knows (default `'cividis'`; `<name>_r` reversed,
`levels` not taken here). The range mapped onto it is the data's (finite values) unless `vmin`, `vmax` are given;
values outside it take the map's end colours, NaN is grey. Without a scalar the mesh is drawn in `color` (default
light grey).

**Light.** By default a light at the eye shades the surfaces: a face seen straight on has its colour, a face seen
edge-on a quarter of it. Both sides of a surface are lit the same (grid faces are open). Shading is smooth (the light
blended from the vertices' normals) or `flat` (one per triangle, showing the facets). `lighting=.false.` at `init`
gives the colours exactly as mapped: use it when the colours must match a [legend](colormaps#a-colour-scale-legend).

<<< @/examples/snippets/cb_view3d_render-colours.F90{fortran}

## The camera

The camera looks at a **target** from a **distance**, from a direction given by its **azimuth** (around z, from +x
toward +y) and **elevation** (above the x-y plane), with a vertical field of view `fov` (default 30°). z is up. A
view never given a camera is fitted to its meshes at its first draw, from azimuth -60° and elevation 25°.

### Mouse

| The mouse in the view | Moves |
|---|---|
| left drag | orbit: 0.4° per pixel |
| right or middle drag, or shift + left drag | pan |
| wheel | zoom: the distance divided by 1.1 per step |
| double click | fit |

While the pointer is over the view, the wheel zooms the view and nothing else: the view claims the wheel (Dear ImGui's
key ownership, `SetItemKeyOwner` of `ImGuiKey_MouseWheelY` and `ImGuiKey_MouseWheelX`), so a window or child that
holds the view and scrolls does not scroll on the same turn. Beside the view, the wheel scrolls its container as
usual. Before v0.3.1 the container scrolled instead: in a scrolling child, the wheel over the view moved the view
from under the pointer and did not zoom it (`figure_test_view3d`). The same in every mode: **window**, **headless**
(the wheel of `test_wheel`) and **remote** (the browser's wheel).

<<< @/examples/snippets/cb_view3d-controls.F90{fortran}

`v%fit` aims at the centre of the visible meshes' bounding box from the distance at which their bounding sphere fills
the view; the direction is kept. `v%view('+x')` puts the eye on the +x side looking toward -x, with z up; `'+z'` looks
down with x to the right and y up, `'-z'` looks up. The standard views are fitted.

`v%orbit`, `v%pan` and `v%zoom` move the camera as the mouse does, from the program; `v%set_camera` and
`v%get_camera` set and read it. The elevation stays in [-90°, 90°].

## Picking

<<< @/examples/snippets/cb_view3d-draw.F90{fortran}

The view keeps, beside each render's colours, which triangle covers each pixel. So picking costs nothing: `v%pick(x,
y, ...)` reads it at a pixel, `v%hovered` at the mouse, `v%clicked` at a click (the left button released less than 3
pixels from where it was pressed, so that a drag is not a click). Each gives:
- the mesh's id;
- the element, from 1: the triangle, the quad, or the structured cell `i + (j - 1) * (ni - 1)`;
- the point hit, in world units, from the depth of that pixel.

`v%clicked` is true only in the frame of the click.

## Clipping planes

`v%clip(normal, point)` keeps what lies on the side of the plane the normal points to. Up to 6 planes cut together.
Surfaces are cut exactly, per pixel; lines per segment. The cut shows the inside of a surface, lit as its outside.
`v%unclip()` removes every plane.

<<< @/examples/snippets/cb_view3d_render-clip.F90{fortran}

## How a view is rendered

A view is rendered again only when something changed since its last render:
- the camera;
- the size;
- a mesh, its style or its data (`v%changed`);
- the clipping planes;
- the background.

A frame drawn because another widget changed costs only the image's draw. `v%render_info(count)` counts the renders:
three idle frames add none, a clipping plane one, data changed in place and announced with `v%changed` one
(`docs/examples/src/cb_view3d_render.F90`, run headless by the documentation's build):

<<< @/examples/snippets/cb_view3d_render-renders.F90{fortran}

<<< @/examples/output/cb_view3d_render.txt{text}

A render runs in three steps:
1. **Vertices:** the vertices are projected and coloured.
2. **Triangles:** each triangle is clipped against the eye's near plane, then filled with a depth test, pixel by pixel.
3. **Lines:** the lines are drawn last.

The image is uploaded into a texture and drawn by Dear ImGui as any image.

**Fast moves.** While the user drags or turns the wheel, the view is rendered at half its width and height: a quarter
of the pixels to fill, and to send in remote mode. It renders at full size again in the frame where the move ends:
the button released, or a frame without a wheel step. A drag held still keeps the half-size image, without
rendering, until it moves again or ends. `fast_moves=.false.` at `init` keeps full size.

**Threads.** `threads` (at most 4) splits each render over that many threads: bands of rows, each walking every
triangle. It pays for large views and many triangles; beyond 4 it gains nothing with this split (see below).

## Performance

The time of one render, measured on an Intel i9-13900KF under WSL2:
- the faces of the 6 blocks of a real OverSet grid (an H2-air jet) at its three multigrid levels;
- the camera turning around them, the mesh filling about a quarter of the view;
- median of 72 renders, coloured by a scalar per vertex.

| Triangles | 800x600, 1 thread | 800x600, 4 threads | 1600x1000, 1 thread | 1600x1000, 4 threads |
|---|---|---|---|---|
| 9.2 thousand | 2.0 ms | 1.1 ms | 4.7 ms | 2.6 ms |
| 148 thousand | 5.2 ms | 2.8 ms | 9.3 ms | 4.6 ms |
| 590 thousand | 14 ms | 7.1 ms | 19 ms | 9.5 ms |
| 2.4 million | 45 ms | 25 ms | 52 ms | 28 ms |

A view filled by its mesh (zoomed in) costs more: in the spike, about four times as much at 9 thousand triangles, the
time going into the pixels. Fast moves divide that part by four.

**Per mode:**

| Mode | Cost of a render | The image |
|---|---|---|
| window | as the table | uploaded to the GPU: about 1 ms at 1600x1000, at most |
| headless | as the table | not uploaded; `v%image` reads it |
| remote | as the table, plus 2 to 5 ms per 800x600 image to encode it as JPEG while the camera moves | sent to the browser: as JPEG while the camera moves, then exact (`4 * width * height` bytes, 6.4 MB at 1600x1000, or deflated) once it is still |

**Remote mode while the camera moves.** The view's image changes at every frame, and would go as raw RGBA: 1.6 MB
per frame at 1600x1000 with fast moves, 91 MB/s at 59 frames a second, fine on the same machine but not through an
SSH tunnel to a cluster node, which carries a few MB/s. So the [remote UI](remote#changing-images) sends an image
updated in consecutive frames as a JPEG, and the exact image once the camera has been still for 150 ms. Turning
`cb_view3d` for 5 s, measured with `scripts/remote_client.py --measure`:

| The view (the image while moving) | before: raw | deflated (`compress='always'`) | now: JPEG |
|---|---|---|---|
| 964 x 553, fitted (482 x 276) | 520 KB per frame, 30 MB/s | 6.6 KB, 0.38 MB/s | 5.0 KB, 0.29 MB/s |
| 1604 x 1013, fitted (802 x 506) | 1585 KB, 91 MB/s | 29 KB, 1.7 MB/s | 14 KB, 0.81 MB/s |
| 1604 x 1013, zoomed in on the grid (802 x 506) | 1585 KB, 91 MB/s | 267 KB, 15 MB/s | 118 KB, 6.8 MB/s |

KB and MB are of 1024 bytes. The fitted body leaves most of the view background, which deflates well; grid lines
filling the view are JPEG's worst case. On the spike's OverSet grid coloured by a field, JPEG was 6 to 18 times
smaller than deflate, and 30 to 190 times smaller than raw. A still view costs nothing; when a move ends, one exact
image goes. `init_remote(lossy=.false.)` sends every image exact. See [Known issues](known-issues#_3-d-views).

## Statuses and modes

**Statuses.** `stat` is optional; absent, a failure stops the program with its message ([Error handling](errors)).

- **`FIG_ERR_ARGUMENT`:**
  - `threads` outside [1, 4];
  - an array of the wrong shape, or not contiguous;
  - a connectivity index outside [1, nv];
  - a scalar of the wrong size;
  - an unknown colormap;
  - `vmin` without `vmax`, or `vmax <= vmin`;
  - a distance or zoom factor ≤ 0, a field of view outside (0°, 180°), an elevation outside [-90°, 90°];
  - an unknown standard view;
  - a seventh clipping plane or a zero normal;
  - an unknown mesh id.
- **`FIG_ERR_STATE`:**
  - a view not initialized;
  - a call from a task.

A failed `v%triangles` (or the other kinds) adds nothing and returns 0.

**Modes.**
- **window:** drawn as above, the image on the GPU.
- **headless:** the same pixels, read with `v%image`. Synthetic input ([Headless testing](testing)) turns and picks as
  the mouse does.
- **remote:** the same pixels, sent to the browser as a texture at each render: as JPEG while the camera moves,
  exact once it is still (above). The mouse in the browser turns and picks as in a window.

## Limits

- **No transparency, no textures on the surfaces, one light** (at the eye). No axes, labels or colour bar inside the
  view: put a [legend](colormaps#a-colour-scale-legend) beside it.
- **Lines are one pixel wide**, without antialiasing; surfaces are not antialiased either.
- **The image has the view's size in logical pixels.** On a display scaled 2x it is magnified, not rendered at the
  display's resolution.
- **Picking finds surfaces only,** not lines.
- **Large meshes on one thread:** above a million triangles a render takes tens of milliseconds (the table above).
  Read large grids off the frame loop with a [task](processes#tasks), then hand the arrays to the view.

## Why a software renderer

FIGURE's three modes do not all have a GPU: remote mode runs where there is no display, and headless tests have no
OpenGL context. Three designs were weighed ([issue #3](https://github.com/szaghi/figure/issues/3), S15):

| | Design | What it would add |
|---|---|---|
| A | the software rasterizer, in every mode (this page) | one renderer, exact pixels in tests and recordings |
| B | OpenGL into an offscreen buffer in window mode, A elsewhere | renders of about 1 ms up to millions of triangles on a real GPU; a second renderer to keep matching A, and A still used where OpenGL is Mesa's software one (WSL by default, X forwarding) |
| C | OpenGL in a window and WebGL in the browser, the geometry sent once | remote orbiting without sending images; a third renderer, in the browser, and no pixels on the program's side |

The spike measured A's costs (the table above) against B's on this machine: on the GPU, B stays near 1 ms where A
takes 5 to 50; under Mesa's llvmpipe, B is two to four times slower than A. The decision (S15, closed for v0.3.0):

- **A is FIGURE's renderer** in every mode.
- **B only when an application needs it:** when one draws more than about 10⁶ triangles in a window, where A falls
  under 30 renders a second. It would then render on the GPU only behind a check of the OpenGL renderer (not Mesa's
  llvmpipe or softpipe, where A is faster), with A everywhere else.
- **No C.** It would add a third renderer and take the pixels away from tests and captures; JPEG images while the
  camera moves (above) answer its bandwidth argument.
