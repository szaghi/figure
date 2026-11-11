---
title: 25. A clip plane by hand, the studio as a picture
---

# 25. A clip plane by hand, the studio as a picture

The 3-D panel's cut, a plane fixed at the probe line since chapter 13, becomes a plane the user places: a **gizmo**
drawn over the view moves it along its arrows and turns it on its rings, and a **view cube** in the corner turns the
camera. Then the studio's test grows two ways: it finds its items by their **paths**, and it compares the studio's main
window, rendered headless, with a **committed picture**.

<Media name="tut25_clip" video alt="F5 runs the plate case; the 3-D panel shows the temperature as a surface over the plate and the body as a grey cylinder, a view cube in the top-right corner. The clip box is checked: the surface is cut at the probe line, and a gizmo stands on the cut, red, green and blue arrows along x, y and z. The red arrow is dragged right: the cut follows, more of the surface shows. With turn chosen, rings replace the arrows; the blue ring is dragged and the cut turns about the vertical, slanting across the plate. A click on the cube's top face turns the camera to look down on the plate" caption="docs/examples/src/tut25_clip.F90, run as tut25_clip --examples /tmp/figure-studio --case /tmp/figure-studio/plate" />

The whole program: [tut25_clip.F90](https://github.com/szaghi/figure/blob/main/docs/examples/src/tut25_clip.F90),
chapter 24's studio with the changes below.

## A plane the user places

Checking *clip* places a plane across the plate at the probe line; its placement is a 4 x 4 matrix, in columns: the
plane's two in-plane axes, its normal, its point ([Gizmos](/guide/view3d#gizmos)):

<<< @/examples/snippets/tut25_clip-clip_box.F90{fortran}

After `view%draw`, two calls draw over the view:

<<< @/examples/snippets/tut25_clip-gizmo.F90{fortran}

- `view%view_cube()` draws the cube in the view's top-right corner: a click on a face turns the camera to look at it,
  a drag on the cube orbits.
- `view%gizmo(id, plane, mode=...)` draws the gizmo at the plane's point and is true on the frames the user drags it,
  with `plane` changed in place; `'translate'` shows three arrows, `'rotate'` three rings (`'scale'`, the third mode,
  would stretch the axes: the studio offers move and turn). Nothing is called back: the studio polls the result and
  clips the view again.

<<< @/examples/snippets/tut25_clip-clip.F90{fortran}

`view%clip(normal, point)` keeps what lies on the side the normal points to; the normal is made unit first, since a
turned matrix carries rounding. The view keeps the clip across frames; `unclip` removes it.

## The test, by paths

Since chapter 16 the test has found its targets by their pixels: the centre of the last item drawn, kept in a
variable for the purpose (`title_at`, `east_at`, ...). The new checks name the items instead, by the path of labels
that leads to them ([Finding items by path](/guide/testing#finding-items-by-path)):

<<< @/examples/snippets/tut25_clip-gizmo_test.F90{fortran}

- `test_item_click('tools/3-D')`: the tool button labelled *3-D* in the window `tools` (the bar's own name);
  `test_item_click('3-D/clip')`: the checkbox *clip* in the panel *3-D*. A click on an item that is not there, or
  disabled, or hidden behind another tab, stops the test with a message naming the nearest item.
- `test_item_checked('3-D/clip')` reads the check mark as it was drawn.
- The gizmo has no label: the test aims at its arrow from the view's own matrices (`to_pixel`, with
  `view%view_matrix` and `view%projection_matrix`), as `cb_gizmo` does.

## The studio as a picture

Every check so far reads a value. One more compares what the studio **looks** like: the main window, once the plate
is open and its field read, with a picture committed beside the example, `docs/examples/data/tut25_clip.png`:

<<< @/examples/snippets/tut25_clip-picture.F90{fortran}

- `test_capture(file)` writes the whole frame as a PNG when it is rendered, at the next `app%next_frame`. Headless,
  FIGURE's own renderer draws it, the same on any machine, without a GPU ([Capture](/guide/capture)).
- `test_compare_image(file, golden, masks=...)` is true when no pixel differs by more than 2 levels per channel,
  outside the masks ([Pictures as tests](/guide/testing#pictures-as-tests)); on a mismatch it writes
  `tut25_clip.new.png` and `tut25_clip.diff.png` beside the committed picture, to look at. The mask is the case's path in the Case panel: the
  folder the test runs in is this machine's.
- **Wait for what the picture shows.** The field is read by a task, at a time of the task's; the test draws until it
  is there, then 360 frames, for the notifications to fade (5 s of frame time each). Then nothing on the screen
  depends on the clock.
- `test_id_conflicts()`: no two items of the window share an id, which a path could not tell apart.

A change to the studio that shows, a label renamed, a colour, a margin, fails the check: the picture is then taken
again, looked at, and committed with the change.

<<< @/examples/output/tut25.txt{text}

::: tip What you learned
`view%gizmo` and `view%view_cube`, a plane placed and the camera turned by hand, `view%clip`; `test_item_click` and
`test_item_checked`, items found by their paths; `test_capture` and `test_compare_image`, the window tested as a
picture, with masks for what is not the program's. Reference: [Gizmos](/guide/view3d#gizmos),
[Finding items by path](/guide/testing#finding-items-by-path), [Pictures as tests](/guide/testing#pictures-as-tests).
:::

This is the end of part three. The [Cookbook](../cookbook) answers one task per recipe, the
[Reference](/guide/features) lists every procedure, and the [name map](/guide/imgui-names) gives the FIGURE call of a
Dear ImGui, ImPlot or ImPlot3D function, and of the extensions'.
