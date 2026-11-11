---
title: Headless testing
---

# Headless testing

`app%init_headless(width, height [, stat])` creates the Dear ImGui and ImPlot contexts on a virtual display of
`width` x `height` pixels, without a window, without OpenGL and without a GPU. The frame loop is the same: widgets
and plots run their full logic (layout, hit testing, state), only nothing is drawn on screen. A headless program needs
no display server: it runs in CI as is, without Xvfb.

Differences from window mode:

- `next_frame` never returns `.false.`: the program decides how many frames to run;
- every frame advances Dear ImGui's clock by 1/60 s, whatever the wall time;
- no `imgui.ini` is read or written;
- `content_scale()` is 1;
- the input is what the program queues.

## Synthetic input

The module `figure_testing` queues input as a user would produce it; the program draws its next frames as usual, and
the input reaches the widgets there. A test queues, draws a few frames, then checks the program's variables:

<<< @/examples/snippets/tut05_headless-test.F90{fortran}

<<< @/examples/output/tut05.txt{text}

| Procedure | Queues |
|---|---|
| `test_click(x, y [, button] [, stat])` | a click at (x, y): move, a frame resting there, press, release (`button`: `'left'`, default, `'right'`, `'middle'`) |
| `test_drag(x0, y0, x1, y1 [, stat])` | a drag with the left button: a slider grab moved, a window dragged by its title bar |
| `test_mouse_move(x, y [, stat])`, `test_mouse_button(down [, button] [, stat])` | the parts of a click, one by one |
| `test_wheel(dy [, dx] [, stat])` | a turn of the wheel; positive `dy` away from the user (zoom in, in a plot) |
| `test_key(name [, down] [, stat])` | a key, pressed and released (or only pressed or released with `down`): `a`-`z`, `0`-`9`, `enter`, `tab`, `backspace`, `delete`, `escape`, `space`, `left`, `right`, `up`, `down`, `home`, `end`, `pageup`, `pagedown`, `f1`-`f12`, and the modifiers `ctrl`, `shift`, `alt`, `super` |
| `test_type(text [, stat])` | typed characters, into the focused field |
| `test_next_frame([stat])` | a frame boundary: what is queued after it arrives one frame later |
| `test_drop(paths, x, y [, stat])` | files or folders dropped at (x, y): `app%dropped` reports them together on the next frame ([Drops](frame-loop#drops)); no path is `FIG_ERR_ARGUMENT` |

A plot's box selection is a drag with the right button, which `test_drag` does not do: queue its parts with
`test_mouse_move`, `test_mouse_button(.true., 'right')`, `test_next_frame` and, after the frames that read it,
`test_mouse_button(.false., 'right')`. To aim inside a plot, take the pixel of a plot point with
[`ip_plot_to_pixels`](plots#reading-a-plot) on an earlier frame.

And to aim and to check:

| Procedure | Gives |
|---|---|
| `test_item_center(x, y)` | the centre of the last widget drawn (call it right after the widget) |
| `test_quit([stat])` | a quit request, as the window's close button makes it |
| `test_plot_tick(axis, index, label [, count] [, stat])` | the label of tick `index` on an axis of the plot being declared, `'x1'`, `'x2'`, `'x3'`, `'y1'`, `'y2'` or `'y3'` (`'x'`, `'y'`: X1, Y1; an axis not set up is `FIG_ERR_STATE`; [Axes](plots#axes)) (between `ip_begin_plot` and `ip_end_plot`, after an item), and the number of ticks |
| `test_plot_copies()` → `int64` | how many arrays the plot items copied since the program started because ImPlot could not read them in place: an array whose stride differs from the ordinates' (or is negative), integer abscissae (converted); read it before and after an item ([Data in place](plots#data-in-place)) |
| `test_plot_stride()` → `int64` | the byte stride the last plot item gave ImPlot: the element size for contiguous data, more for data read in place from a strided section, 0 before any item. It reports what the item received: a compiler that copies a strided actual argument into a temporary gives a contiguous one ([Data in place](plots#data-in-place)) |
| `test_field_uploads()` → `int64` | how many times [`ip_field_image`](plots#fields) coloured a field and uploaded it since the program started: read it before and after frames to check that a field is not coloured again when nothing changed |
| `test_field_textures()` → `int32` | how many field textures `ip_field_image` keeps: one per field drawn in the last 10 s |
| `test_field_time()` → `real64` | the time the last colouring took, range, colours and upload [ms] |
| `test_field_pixel(label, i, j, rgba [, stat])` | the colour, RGBA in [0, 1], the last colouring gave the value (i, j) of the field `label`; `FIG_ERR_ARGUMENT` for a label not drawn in the last 10 s or (i, j) outside the field |
| `test_frame_hit(x, y)` → `character` | the hit test of the window's frame (`decorations='figure'`) at (x, y), from the last frame: `'client'`, `'drag'`, or a resize edge or corner (`'resize-top-left'`, `'resize-top'`, ..., `'resize-left'`) |
| `test_frame_rect(part, x0, y0, x1, y1 [, found] [, stat])` | a part of the title bar in the last frame (`'bar'`, `'icon'`, `'menus'`, `'title'`, `'minimize'`, `'maximize'`, `'close'`), to click its buttons |
| `test_frame_state(minimized, maximized [, stat])` | minimized and maximized: the window's, or in headless mode what the bar's buttons recorded |
| `test_system_theme(theme [, stat])` | the system's light or dark setting changes at the next frame, as SDL's event reports it: `'light'`, `'dark'`, or `'system'` (the real setting again); for [`palette='auto'`](styles#follow-the-system-s-light-or-dark-setting) |
| `test_notification_rect(index, x0, y0, x1, y1 [, found] [, alpha])` | the rectangle of a [notification](frame-loop#notifications) shown in the last frame: 1 the newest (at the bottom), 2 the one above; `found` false past the last; `alpha` the largest alpha of its vertices in the draw data, in [0, 1]: 1 while shown in full, falling to 0 as it fades out |
| `test_drawn_extent(color, x0, y0, x1, y1 [, found] [, stat] [, layer] [, vertices])` | the extent of what was drawn so far in the current window in Dear ImGui's style colour `color`, by name, or in an RGBA colour (`real(real64)`, 4 values: an item drawn with `ip_spec(line_color=...)`): call it right after a widget, or after `ip_end_plot` for what a plot draws at its end (annotations) (`'PlotHistogram'` measures a progress bar's fill). Antialiased edges have other colours: the extent is that of the lines' cores. For an RGBA colour, `layer='foreground'` or `'background'` looks on those layers of the [canvas primitives](canvas#layers), and `vertices` counts the vertices in the colour (a filled shape has one per corner) ([Testing a canvas](canvas#testing-a-canvas)) |
| `test_file_browser(shown [, folder] [, entries] [, error] [, asking] [, path_field] [, name_field] [, recent])` | the [file browser](frame-loop#figure-s-file-browser) in front, after the last frame: the folder listed, the entries in the order shown (folders ending in `/`), the error shown (`''` none), whether a replace is asked, the texts of the path and name fields, the recent folders (newest first; also without a browser) |
| `test_file_browser_rect(part, x0, y0, x1, y1 [, found])` | a part of the file browser as drawn in the last frame, to click it: `'entry:NAME'` (a row in view), `'parent'`, `'refresh'`, `'path'`, `'new folder'`, `'new folder name'`, `'create'`, `'sort:name'`, `'sort:size'`, `'sort:modified'`, `'place:home'`, `'place:cwd'`, `'place:root:N'`, `'place:recent:N'`, `'name'`, `'filter'`, `'filter:N'` (its list open), `'hidden'`, `'cancel'`, `'ok'`, and while a replace is asked `'replace'`, `'keep'` |
| `test_settings_file(path [, stat])` | the file that keeps the browser's recent folders, until the program ends: a test reads and writes its own (`''`: memory only, the default in headless mode) |
| `test_window_rect(name, xmin, ymin, xmax, ymax [, found] [, stat])` | a window's rectangle, by its name, as drawn in the last frame |
| `test_popup_rect(xmin, ymin, xmax, ymax [, found] [, stat])` | the rectangle of the innermost open popup (a menu, a [context menu](menus#context-menus), a combo's list, `ig_color_edit`'s picker), as drawn in the last frame; `found` false when none is open |
| `test_opened_url()` → `character` | the URL the last click on an [`ig_text_link_url`](widgets#links) asked to open, in any mode (headless opens nothing); `''` before one |
| `test_glyph(text, font, source, pixels [, width] [, height] [, checksum] [, stat])` | one character of a text font at the current size, as Dear ImGui draws it: the font that gives it, `source` (`'IBM Plex Mono'`, `'Noto Sans Math'`, a fallback file's name; `''` when none has it), the pixels of its bitmap that are not empty, its advance and height [pixels], a checksum of the bitmap ([Glyphs](#glyphs)) |

**Timing.** Everything queued reaches Dear ImGui at the next frame, up to a `test_next_frame` boundary; Dear ImGui then
applies one change of each kind per frame (its input trickling), so a click queued at once still takes the frames a
real one takes. Draw a few frames after queuing (four for a click, more for a drag, which `test_drag` spreads with its
own boundaries) before checking, or draw until the interface is idle with [`test_run`](#running-until-idle). Editing a
numeric field, for example:

<<< @/examples/snippets/cb_controls-edit_field.F90{fortran}

`cfl_at` and `monitor_at` are the centres of the field and of a button, from `ig_item_rect` where the program drew
them (`docs/examples/src/cb_controls.F90`); the run prints what the clicks and the keys changed:

<<< @/examples/output/cb_controls.txt{text}

**Aim from the second frame on.** A new window that sizes itself to its content is measured during its first frame
and shown from the second: positions read in the first frame are not where the widgets end up (place windows with
`ig_set_next_window` to have them from the first frame).

Coordinates are display pixels, as `ig_item_rect` gives them. The module works in every mode; headless needs no
display, so tests run in CI as is. It is a separate module: `use figure_testing` where the tests are, `use figure` in
the application. Both are in the library (`lib/libfigure.a` and `lib/mod`, from `fobis build --mode figure-static-gnu`
or `fobis fetch`), so a project that depends on FIGURE tests its own interface the same way.

`test_click` and `test_drag` let the pointer rest one frame on the item before pressing, as a user's hand does:
Dear ImGui's tabs (and other items that may overlap) take a press only once they were hovered in the frame before. A
click therefore lands over the next four frames (move, rest, press, release), a drag over the next five.

To press a shortcut, hold `'shortcut'`: the platform's shortcut key, cmd on macOS and ctrl elsewhere, the one that
select-all (`a`) and `ig_shortcut('ctrl+s')` mean there. `'ctrl'` is the physical ctrl key, which macOS does not use for
shortcuts: Dear ImGui swaps the two as the events arrive.

### Glyphs

`test_glyph` tells which font of a text font's stack ([the fallback fonts](styles#symbols-the-fallback-fonts)) draws a
character, and what it draws: a test that a label's symbols are not missing-glyph boxes checks that `source` is not
empty and `pixels` is positive. `font` is a name of `app%set_font` (`'plex-sans'`, `'plex-mono'`, `'proggy'`) or a
file; the glyph is rasterised at the current font size if it was not yet. In a frame (`FIG_ERR_STATE` otherwise);
`text` must be one character of the Basic Multilingual Plane in UTF-8, and `font` a font (`FIG_ERR_ARGUMENT`); a file
that cannot be read is `FIG_ERR_FAILED`. The same in every mode, on the frame loop's thread.

<<< @/examples/snippets/cb_fallback_font-report.F90{fortran}

## Finding items by path

A test names an item by where it is, not by the frame it was drawn in or the pixels it covers: `'Solver/CFL'` is the
item labelled `CFL` in the window `Solver`. FIGURE records the items of every frame with Dear ImGui's own item hooks
(`ImGuiTestEngineHook_ItemAdd` and `ImGuiTestEngineHook_ItemInfo`, which Dear ImGui calls for every item it registers
when built with `IMGUI_ENABLE_TEST_ENGINE`; FIGURE implements them, no code of Dear ImGui's test engine is used): each
item's role, label, id, window, rectangle, state (checkable and checked, openable and opened, takes typed text) and the
text it shows. The procedures read the last frame drawn.

<<< @/examples/snippets/cb_paths-act.F90{fortran}

| Procedure | Does |
|---|---|
| `test_item_exists(path [, stat])` → `logical` | true when `path` names an item or a window of the last frame (several items: true too) |
| `test_item_rect(path, x, y, w, h [, stat])` → `logical` | the item's top-left corner and size [pixels]; false, and zeros, when no item matches |
| `test_item_click(path [, button] [, stat])` | queues a click at the centre of the item's visible part, as `test_click` does (`button`: `'left'`, default, `'right'`, `'middle'`); a tree node is clicked on its arrow, which opens and closes it |
| `test_item_type_text(path, text [, stat])` | queues a click with the shortcut key held (a slider or a drag takes typed text then, a field is focused), select all (shortcut+a), `text`, Enter |
| `test_item_checked(path [, stat])` → `logical` | a checkbox, a menu item with a check mark, a selectable in a menu: checked in the last frame |
| `test_item_value(path, text [, shown] [, stat])` → `logical` | true when the item showed `text` as its value: the text drawn inside its rectangle, its label taken out (a field's text, a slider's number as its format writes it, a combo's choice), blanks collapsed; `shown` gives what it showed |
| `test_menu_click(path [, stat])` | queues a click through a menu path: the first menu now, each following level once its menu has opened, over the next frames; a menu already open is pointed at, not clicked again |
| `test_record_items(on [, stat])` | records the items of each frame from the next frame on, or stops |

(Dear ImGui's test engine has the like as `ItemExists`, `ItemClick`, `ItemInputValue` and `MenuClick`, run from a
test coroutine; FIGURE's queue input that the program's own frame loop then draws, as every `test_*` procedure.)

**Paths** follow the references of Dear ImGui's test engine where they are defined:

| Path | Names |
|---|---|
| `Window/Label` | the item labelled `Label` in the window `Window` (its title, as passed to `ig_begin`) |
| `//Window/Label` | the same, `Window` a window by its full name, never an item elsewhere |
| `Label` | a relative path: the first segment is a window, or else an item anywhere |
| `Window/Node/Leaf` | an item inside a tree node, a tab, a menu, a combo's list, a child region (`ig_begin_child`'s id) or an id scope (`ig_push_id`, a table's id, a tab bar's id) |
| `Window/Leaf` | the same item: a level with no label of its own (an id scope, a table, a tab bar, a menu bar) may be left out |
| `Save##file`, `##file` | a label with its id part, or the id part alone (a label with no visible text) |
| `*` | any one level: `'Panel/grid/*/Edit'` |
| `$$3` | an integer id: the scope of `ig_push_id(3)` |
| `a\/b` | a slash inside a label |

A segment matches a label in full (`Save##file`), its visible part (`Save`), its id part (`##file`), or the name a
widget that draws its own label gives (`ig_tool_button`'s label). A context menu is found under the scope it was
declared in, by its id (`'Panel/actions_menu/Delete'`), or relative (`'Delete'`); a menu's and a combo's items under
the menu or the combo (`'File/Recent/notes.txt'`, `'Panel/Mode/Beta mode'`). Trailing blanks are not part of a path.

**Frames.** The procedures read the last frame drawn: call them between frames or inside one, after the frame that
drew the item. A window that sizes itself is placed from its second frame: its items are not visible before
(`test_item_click` refuses them). An action is queued input: it lands over the next frames, as `test_click` does (four
for a click); draw them with [`test_run`](#running-until-idle). A menu path takes the frames its menus need to open; a
level that does not appear within 20 frames ends the queued input, and the next `test_run` reports it.

**Status.** `stat` is optional; absent, a failure stops the program with the message.

| Failure | Status | Message |
|---|---|---|
| no item matches | `FIG_ERR_ARGUMENT` | `<procedure>: no item '<path>' in the last frame: nothing named '<segment>' in '<where>'; nearest: '<path of the nearest item>'` (or `no window or item '<segment>'`) |
| several items match | `FIG_ERR_ARGUMENT` | `<procedure>: '<path>' names <n> items: '<path>' '<path>' ... (a longer path tells them apart)` |
| two items share the id | `FIG_ERR_ARGUMENT` | `<procedure>: '<path>' names <n> items with the same id (an id conflict, test_id_conflicts): '<path>'` |
| an empty segment (`'a//b'`, `''`) | `FIG_ERR_ARGUMENT` | `<procedure>: '<path>' is not a path: an empty segment ('Window/Label', '//Window/Label', '##id', '*')` |
| a level of ids only | `FIG_ERR_ARGUMENT` | `... '<path>' is a level of ids with no item of its own` |
| not checkable (`test_item_checked`) | `FIG_ERR_ARGUMENT` | `test_item_checked: '<path>' is not checkable` |
| takes no text (`test_item_type_text`) | `FIG_ERR_ARGUMENT` | `test_item_type_text: '<path>' takes no typed text (not a text field, a number field, a slider or a drag)` |
| disabled, or not visible (clipped, scrolled out, a window not shown yet) | `FIG_ERR_STATE` | `<procedure>: '<path>' is disabled`, `... is not visible in the last frame (...)` |
| a menu path names a window only | `FIG_ERR_ARGUMENT` | `test_menu_click: '<path>' names a window, no menu` |
| no frame yet | `FIG_ERR_STATE` | `figure is not initialized` |

`test_item_exists` fails only for a malformed path; `test_item_rect` returns `.false.` for a missing path and fails for
several items.

**Recording.** On from `app%init_headless`. In window and remote modes it starts with the first call of a path
procedure, which finds nothing yet (the frame it reads was not recorded), or with `test_record_items(.true.)` before
the frames. Recording costs about 0.02 µs per item and frame (1000 buttons, headless, gfortran -O2: 92 µs a frame
without, 113 µs with; `figure_test_paths` measures it); a program that never records pays one test of a boolean per
item, the hooks being off (measured against a native layer built without the hooks: 1 to 2 µs a frame for the same
1000 buttons, within the run-to-run spread). Dear ImGui's behaviour does not change with recording: the hooks only read.

**Modes.** The same in window, headless and remote modes. **Threads:** the frame loop's thread only (Dear ImGui's
items); a task does not call them.

**What a path cannot address:** an item drawn without an id: text (`ig_text`), a separator, a progress bar, an image,
a plot item (a plot itself, by its title's id: `'Window/My plot'`); a path finds them only through a widget with a
label. Glyphs cut by a clip rectangle are not read into a value. Several items with the same label in one scope are
an id conflict, which no path can tell apart: give them `##` ids. Values are read from what was drawn: a field scrolled
past its width shows part of its text.

## Running until idle

`test_run(max_frames [, stat])` → `logical` is the loop of a test: true while the interface is not idle, so the
program draws one more frame; false once no input is queued (neither FIGURE's nor Dear ImGui's trickled events), no
action waits (a menu level) and no frame is asked for (the three frames an input gives, as an event does in a window,
and `app%request_frames`). Call it once per frame:

<<< @/examples/snippets/cb_paths-settle.F90{fortran}

Past `max_frames` frames of one run it returns `.false.` and fails with `FIG_ERR_STATE`, `test_run: the interface is
not idle after <n> frames: <why>` (`<n> input events still queued`, `an action waits for '<path>'`, `frames are still
asked for (...)`): an animation, a running process or a task that asks for frames keeps a program busy. A menu level
that never appeared is reported here, `test_menu_click: no item ...`, with `FIG_ERR_STATE`. `max_frames` below 1 is
`FIG_ERR_ARGUMENT`. The count restarts after each `.false.`. The same in every mode; in window mode a lazy loop does
not wait for events while input is queued.

## Checks

| Procedure | Gives |
|---|---|
| `test_id_conflicts([list])` → `int32` | how many ids two items with different rectangles shared in the last frame; `list`, their paths |
| `test_unnamed_items([list])` → `int32` | how many interactive items had no visible name and no tooltip; `list`, their paths |

Dear ImGui reports an id conflict (two buttons `'OK'` in one scope: a click on the second acts on the first) only
while the pointer is over one of them; `test_id_conflicts` finds every one in the frame. An item is unnamed when its
label has no visible text (`'##save'`) or only icons (Lucide's private-use characters), and it has no tooltip
(`ig_tooltip`, `ig_begin_item_tooltip`, a shortcut's tooltip): an icon-only button a screen reader, or a reader of
the interface, cannot name. Interactive items only: text and separators are not items. `list` is blank-padded to the
longest path.

<<< @/examples/snippets/cb_paths-check.F90{fortran}

<<< @/examples/output/cb_paths.txt{text}

The same in every mode; recording must be on (the call turns it on, from the next frame).

## Pictures as tests

A test can check what a window looks like, pixel by pixel, against a committed picture (a golden): FIGURE's CPU
renderer draws headless mode's frames the same way on every machine ([Screenshots and videos](capture#determinism)),
so no GPU, display or tolerance for a driver is needed.

| Procedure | Does |
|---|---|
| `test_capture(path [, stat])` | the whole frame as a PNG file `path`, written when the current frame is rendered (the next `app%next_frame`) |
| `test_compare_image(path, golden [, threshold] [, max_failed] [, masks] [, failed] [, stat])` → `logical` | the picture `path` matches `golden` |

<<< @/examples/snippets/cb_golden-capture.F90{fortran}

- **The rule:** the same size, and at most `max_failed` pixels (default 0) with a channel (R, G, B or A, 0-255) that
  differs by more than `threshold` (default 2: what the CPU renderer may differ by where floating point rounds
  differently, as the GPU from it). Not a perceptual distance: a heatmap's row moved by one pixel differs by 17 levels
  on 900 pixels, which a perceptual threshold of 0.1 lets through, and this rule does not.
- **Masks:** `masks(4, n)`, rectangles `xmin, ymin, xmax, ymax` [pixels from the picture's top-left corner, as
  `ig_item_rect` gives them] whose pixels are left out (a pixel whose centre is inside one): a clock, the age of a
  notification, anything drawn from the wall time, which headless mode's fixed frame time does not make
  deterministic.
- **On a mismatch** it writes `<stem>.new.png` (the picture) and `<stem>.diff.png` beside the golden, `<stem>` the
  golden's name without `.png`, and `figure_last_error` says how many pixels failed, the largest difference and
  where; `failed` gives the count (`-1` when the sizes differ). In the diff the failed pixels are red, those that differ
  within `threshold` dark red, the masked ones blue and the rest the golden, faded. On a match it removes such files
  left by an earlier run. To accept a new picture, copy the `.new.png` over the golden, in the commit that changes
  what the window shows, and say why in its message.
- `test_capture` needs an open frame (`FIG_ERR_STATE` otherwise) and removes a file `path` of an earlier run at once,
  so a picture that cannot be written (its reason on standard error) leaves nothing to compare. In a window it reads
  the GPU's pixels instead, which depend on the driver: goldens belong to headless tests.
- `test_compare_image` fails with `FIG_ERR_FAILED` when a file cannot be read or written, and with `FIG_ERR_ARGUMENT`
  for a file that is not a PNG or JPEG, `threshold` outside 0-255, a negative `max_failed`, `masks` without 4 rows or
  a rectangle upside down ([Errors](errors)).

<<< @/examples/output/cb_golden.txt{text}

The whole example: `docs/examples/src/cb_golden.F90`. `src/tests/figure_test_pixels.F90` checks the renderer itself:
the same frame twice and on 1 and 7 threads, a committed golden, textures filtered as the GPU filters them (nearest,
linear, a field through a colormap), a glyph of the bitmap font pixel for pixel, `save_image` in headless and remote
modes.

## Test the interface you ship

Put the interface in a procedure that the application calls every frame, and call the same procedure from the test:
chapter 5 of the [tutorial](/manual/tutorial/05-headless) does this with a module, `draw_panel`, and a state type.

Call `app%set_checks('abort')` after `init_headless`: a misplaced end in the interface then stops the test at the
faulty call, with a message naming it, even where the test passes a `stat` to `next_frame`
([Usage checks](frame-loop#usage-checks)).

## The repository's tests

`src/tests/figure_test_headless.F90` drives every widget and plot type through `figure_testing` (clicks, a drag, typing
into a field), checks docking, styles, themes and fonts, headless; `src/tests/figure_test_themes.F90` measures the
contrast of every built-in style; `figure_test_layout` checks that the Fortran mirrors of Dear ImGui's structures
match the C++ ones, `figure_test_remote` drives the remote mode end to end through a WebSocket client
([Remote UI](remote#how-it-works)), and `figure_test_files` drives the file browser on a folder it writes (clicks,
double-clicks, typed names and paths, Tab, Escape); `figure_test_tables` scrolls a table with a frozen header by the
wheel, sorts it by clicks on its headers, and checks hidden columns, row colours and tree rows spanning the table;
`figure_test_paths` finds items by path in a tree, tabs, a table, a child region, a context menu and a combo's list,
clicks through a menu, types into fields, checks `test_run`, the id conflicts and the unnamed items, and measures what
recording costs per frame:

```bash
fobis build --mode tests-gnu && exe/figure_test_headless
fobis build --mode tests-gnu-debug && exe/figure_test_headless   # with -fcheck=all and FPE traps
scripts/fpm.sh test
```

It passes with gfortran 16.2 (release and debug), nvfortran 26.9 and fpm.
