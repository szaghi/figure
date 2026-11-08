---
title: 13. The field in 3-D
---

# 13. The field in 3-D

A heatmap shows the temperature by colour; a 3-D view shows it by height as well. The studio gets a 3-D panel: the
temperature as a surface over the plate, as high and as coloured as it is hot, with the body standing on it as a
cylinder. The user turns it with the mouse, picks standard views, shows the grid, cuts it along chapter 12's probe
line, and reads the temperature under the pointer; a click moves the Result panel's probe point there.

<Media name="tut13_view3d" video alt="After a run, View > Run hides the Run panel and the 3-D button shows the 3-D panel: the plate seen from above at an angle, a surface rising to a yellow wall along the hot west side and sinking to dark blue around a grey cylinder, the body. A drag with the mouse turns the view; grid draws the surface's cells; cut along the probe line removes everything beyond x = 0.75 m, the body included, and the cut edge is the probe line's profile. The pointer rests on the surface and the panel reads T = 35.246 C at (0.415, 0.248) m; a click there and the Result tab shows the probe point moved to that place, labelled 35.25 C" caption="docs/examples/src/tut13_view3d.F90, run as tut13_view3d --examples /tmp/figure-studio --case /tmp/figure-studio/plate" />

The whole program: [tut13_view3d.F90](https://github.com/szaghi/figure/blob/main/docs/examples/src/tut13_view3d.F90).

## The meshes

<<< @/examples/snippets/tut13_view3d-build.F90{fortran}

- A `view3d_object` is a 3-D view drawn by FIGURE's software rasterizer, the same pixels in a window, in a headless
  test and in the browser ([3-D views](/guide/view3d)). `view%init()` creates it after `app%init`, and
  `view%destroy()` releases it before `app%destroy`.
- `view%surface(xyz, scalar=, colormap=, edges=)` adds a structured surface: node `(i, j)` at `xyz(:, i, j)`,
  joined to its neighbours, coloured by a value per node through a colormap. The cylinder is a surface too, two
  rings of nodes, in one colour.
- **The arrays are read in place,** at every render: `carpet` and `field` are `target` variables of the program, and
  they stay allocated while the meshes exist. So `view%clear()` removes the meshes before the arrays are reallocated
  for a new field ([Meshes](/guide/view3d#meshes)).
- `set_camera` sets the direction (azimuth around z, elevation above the plate) and `fit` the distance that shows
  everything.

## Turning, cutting, picking

<<< @/examples/snippets/tut13_view3d-controls3d.F90{fortran}

- The mouse turns the view (left drag), moves it (right drag), zooms (wheel) and fits it (double click), with no
  code of the studio's. `view%view('+z')` and `view%view('-y')` are standard views, seen from above and from the side
  ([The camera](/guide/view3d#the-camera)).
- `view%set_mesh(mesh, edges=)` changes a mesh's style: here its grid lines; the Result panel's colormap list calls
  it too, with `colormap=`, so the two panels show the same map.
- `view%clip(normal, point)` keeps what lies on the side the normal points to; `view%unclip()` removes the cuts
  ([Clipping planes](/guide/view3d#clipping-planes)). The cut follows the probe line when it is dragged.

<<< @/examples/snippets/tut13_view3d-view.F90{fortran}

- `view%draw('view')` draws the view in the rest of the panel. It renders only when something changed (a mesh, the
  camera, the panel's size), so a still view costs nothing.
- `view%hovered(mesh, element, point)` tells which mesh is under the pointer and the point hit, in the plate's
  metres; `view%clicked` the same on a click. The view keeps which triangle covers each pixel, so picking does not
  search the mesh ([Picking](/guide/view3d#picking)).

What the view does not do (lines one pixel wide, one light, no axes inside the view) is in its
[limits](/guide/view3d#limits).

::: tip What you learned
A 3-D view of meshes read in place from Fortran arrays, coloured through a colormap; the camera, standard views and
the mouse; a clipping plane; picking under the pointer and on a click. Reference: [3-D views](/guide/view3d).
:::

**Next:** [14. Heavy work off the frame](./14-task): a large result read by a task, while the window keeps drawing.
