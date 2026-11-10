---
title: Roadmap
---

# Roadmap

The plan of each release is tracked step by step in an issue: v0.1.0 in
[issue #1](https://github.com/szaghi/figure/issues/1), v0.2.0 in [issue #2](https://github.com/szaghi/figure/issues/2),
v0.3.0 in [issue #3](https://github.com/szaghi/figure/issues/3),
each step with its tasks, its checks, the documentation and the pictures it updates, and a log of the work. This page
summarises them.

## M1: build chain and first widgets — done on Linux

- Native layer: CMake, pinned sources, static `libfigure_native.a` and `libSDL3.a`.
- Fortran: `figure_app` (loop, lazy redraw), `figure_imgui` (windows, button, check box, sliders for `int32`,
  `real32`, `real64`, numeric input, text, same line, separator, demo window, window placement, item rectangle),
  `figure_implot` (plot, axes, line).
- Headless test (button click, check box toggle, plot) passing with gfortran 16.2 (release and `-fcheck=all`),
  nvfortran 26.9 and fpm.
- FoBiS modes (tests, examples, static library; gnu and nvfortran) and `fpm.toml` in sync.
- `figure_hello` running in a window on Linux (WSLg), X11 and Wayland.
- Idle cost of lazy redraw measured and explained ([Frame loop](frame-loop#what-idle-costs)); default `max_wait`
  kept at 0.5 s.

## M2: generated raw layer — done

- `scripts/gen_bindings.py` generates the `bind(C)` interfaces and the enumeration parameters from cimgui's and
  cimplot's metadata (`definitions.json`, `structs_and_enums.json`) and classifies every public function as direct,
  glue or skipped ([Raw bindings](raw-bindings)). Enumeration values are generated, never copied by hand.
- The output is committed; CI checks it for drift and checks that every bound function is defined in the native
  library (`fobis rule --ex makecoverage`).
- The C++ glue for the functions that pass structs by value (above all the ImPlot items, `ImPlotSpec`) is generated
  too, with `bind(C)` mirror types for the structs, size-checked by `figure_test_layout`.

## M3: images and speed — done

- Textures from contiguous `integer(int8)` RGBA arrays, uploaded without intermediate copies: done
  (`texture_object`, `ig_image`, `ip_image`).
- ImPlot heatmaps from Fortran 2D arrays (column-major aware): done (`ip_heatmap`, read in place, j = 1 at the
  bottom; `ip_colormap_scale`).
- Plot items generic over `real32` and `real64`, so `real32` data is never copied into a `real64` temporary: done
  for `ip_line`, `ip_scatter`, `ip_bars` and `ip_shaded`, with item styles (`ip_spec`).
- Strided series (matrix rows) passed as base address and stride, without the compiler's temporary copy: done for
  `ip_line(label, y, row)` with uniform abscissae (ImPlot applies one stride to x and y, so a contiguous x cannot go
  with a strided row).
- A Mandelbrot explorer (`src/examples/figure_mandelbrot.F90`) and a redraw benchmark at 4K
  (`src/examples/figure_bench_texture.F90`): about 100 frames/s with a new 3840 x 2160 image every frame
  ([measurements](images#speed-a-new-4k-image-every-frame)).

## M4: platforms and CI — done

- GitHub Actions: `ci.yml` (Linux, gfortran, coverage, from the FoBiS scaffold) and `platforms.yml`: macOS (gfortran
  and Apple clang), Windows (MSYS2 UCRT64 gfortran), Linux with nvfortran. Each builds the native layer, checks the
  platform's link line against SDL's, builds and runs the headless tests with FoBiS and fpm, and builds the examples.
- Green on all four (2026-11-04): Linux gfortran (with coverage), Linux nvfortran, macOS 14 arm64, Windows MSYS2
  UCRT64; on macOS and Windows the headless and layout tests also pass through fpm, so the generated glue passes and
  returns structs correctly on those ABIs.
- Platform link lines in fobos varsets (`--varset macos|windows`), checked against `lib/pkgconfig/sdl3.pc`; fpm reads
  them through `scripts/fpm.sh` ([Other platforms](install#other-platforms)).

## M5: remote and web — remote done, WebAssembly to try

- Remote UI: done ([Remote UI](remote)). `app%init_remote` serves the interface to a web browser over a built-in
  WebSocket server; the program needs no display or GPU and stays native (OpenMP, MPI, GPU), e.g. on a cluster node
  reached through an SSH tunnel. Tested end to end on every CI platform.
- Experiment, **deferred**: the whole application compiled to WebAssembly with a patched flang and Emscripten SDL3
  (no OpenMP, no MPI there).

## Documentation with real pictures — done

- Frame capture with scripted input (`FIGURE_CAPTURE`, [Screenshots and videos](capture)); every picture of this
  site is a recording of the program it describes, made by `scripts/docs_media.py`.
- Found by the pictures: a growing history ran off its plot; `ip_setup_axes(..., auto_fit)` refits the axes every
  frame.
- The brand: the seal mark (a window and its plot drafted with a brush, signed with a vermilion seal carved with F),
  the site's palette, and `app%set_style` with `seal` as FIGURE's default [style](styles).

## v0.1.0 — released 2026-11-05

The scope of the first release, step by step in [issue #1](https://github.com/szaghi/figure/issues/1):

- **Licence:** MIT; the third-party notices: done.
- **Docking:** the docking branch of Dear ImGui; windows dock into one another as tabs and splits, and programs set
  layouts ([Docking](docking)): done.
- **Themes, fully customisable** ([Styles](styles)): done.
  - every colour and size of Dear ImGui and ImPlot from Fortran;
  - themes as files, embedded, with a curated set (`seal`, `seal-light`, `paper`, `high-contrast`, colour-blind-safe
    line colours);
  - `load_style` and `save_style`;
  - fonts, with a bundled default;
  - window flags and scoped style changes;
  - a recorded theme gallery.
- **Testing:** a public testing module for synthetic input ([Headless testing](testing)): done.
- **Performance:** the cost of continuous redraw measured locally and in remote mode (`scripts/measure_redraw.py`);
  remote frames skipped when unchanged, capped at 60 per second with one frame at most queued, sent with 12-byte
  vertices and deflated when the link is the bottleneck; the [Performance](performance) guide: done.
- **Remote security:** an access token in the URL, random by default ([Remote UI](remote#access-token)): done.
- **fpm:** FIGURE usable as a dependency of other fpm projects: a self-contained package (fpm compiles the native
  layer itself, SDL3 from the system), published for each release as the tag `vX.Y.Z-fpm`
  ([FIGURE as an fpm dependency](install#figure-as-an-fpm-dependency)): done, first published with v0.1.0.
- **Documentation:** every page checked against the code, every recording regenerated, the changelog, the README: done.
- **Release v0.1.0:** the tag, the GitHub release, the `v0.1.0-fpm` package: done.

## v0.2.0 — released 2026-11-06

Driven by a first application outside the repository, tools for a CFD solver: a live checker of its log files and
editors of its input files.

- **Log axes** for residual histories (`ip_setup_axes(..., xlog, ylog)`): done.
- **Form widgets** ([Widgets](widgets#groups-headers-tabs-tables)): text fields bound to `character` variables, integer
  fields, drop-down lists, tooltips, field widths, collapsing headers, tabs, tables, id scopes, disabled blocks: done.
- **Lists and regions** ([Widgets](widgets#lists-and-regions)): selectable lines, wrapped, disabled and coloured text,
  child regions that scroll on their own: done.
- **Menus and shortcuts** ([Menus and shortcuts](menus)): menu bars, menus, items, key chords (cmd on macOS, also in
  the browser): done.
- **Testing:** `test_click` and `test_drag` let the pointer rest on the item before pressing, as a user does: done.
- **Popups and modals, a confirmation before quitting** ([Menus, popups and shortcuts](menus#popups-and-modals)):
  done.
- **File dialogs** ([File dialogs](frame-loop#file-dialogs)): the system's own, asynchronous, window mode: done.
- **Plots for live checks** ([Plots](plots#several-plots-in-one-figure), [Docking](docking#a-window-that-appears-later)):
  tick label formats, subplots with linked axes, docking a window that appears later: done.
- **Found by the tools** ([issue #2](https://github.com/szaghi/figure/issues/2)): `figure_testing` in the static
  library; the window's title after `init` (`app%set_title`); a font size changed at run time reaching the next frame;
  file dialogs starting from the program's working directory: done.
- **Pictures and layouts**: a rectangle of the window saved as a PNG (`app%save_image`,
  [Save an image](capture#save-an-image-from-the-program)); the windows' arrangement saved and loaded at run time
  (`app%save_layout`, `app%load_layout`, [Docking](docking#save-and-load-a-layout)): done.
- **The tools** ([Showcase](showcase)): a run checker following a run's history files (a navigator for hundreds of
  them, comparison, saved plots and layouts), the editors of the solver's and the grid tool's input files: done.
- **Workspaces and long lists**: a bar along a side of the window (`ig_begin_side_bar`,
  [Docking](docking#a-bar-along-a-side)), Lucide icons in every font (`ICON_*`, [Icons](styles#icons)), workspace
  buttons with an icon above the label (`ig_tool_button`), bringing a window forward (`ig_focus_window`), text level
  with fields (`ig_align_text_to_frame_padding`), the size of a text (`ig_text_size`), long lists drawn row by row
  in view only (`list_clipper_object`, [Widgets](widgets#lists-and-regions)): done.
- **Release v0.2.0:** the tag, the GitHub release, the `v0.2.0-fpm` package: done.

## v0.3.0 — in progress

The next application is one GUI for a case of the Xall solver, from the mesh to post-processing; the plan is
[issue #3](https://github.com/szaghi/figure/issues/3).

- **Looks and palettes** ([Styles](styles#looks-and-palettes)): a style split into a look (the geometry: `seal`,
  `fusion`, `adwaita`, `fluent`) and a palette (the colours, derived from twelve roles and checked for contrast:
  FIGURE's four, Nord, Solarized, Gruvbox, Dracula, Catppuccin, Tokyo Night, One Dark), chosen separately with
  `app%set_style(look=, palette=)`; `palette='auto'` following the system's light or dark setting; the roles for the
  program's own messages (`app%palette_color`); theme files with `look`, `palette` and `[palette]`: done.
- **The window's frame drawn by FIGURE; the window's icon** ([Frame loop](frame-loop#the-window-s-frame)):
  `decorations='figure'`, a borderless window with a title bar drawn by FIGURE in the palette's colours, the main menu
  bar inside it, the buttons on the right (left on macOS), the system's hit test answered from the last frame,
  double-click to maximize, close through the quit path; `app%set_icon` from an image or an `ICON_*`: done.
- **Trees** ([Widgets](widgets#trees)): `ig_tree_node` with a click on the label told apart from the arrow
  (`clicked`), leaves, selection, the full width; `ig_tree_pop`; `ig_set_next_item_open`; trees in a table's first
  column with values in the others; the children of a large node clipped: done.
- **Processes and a log view** ([Processes and tasks](processes)): `process_object`, programs started without a
  shell, captured (the output drained by a native thread that wakes the frame loop, the child killed when the
  program ends) or detached (the output to a file, the child outliving the program); `log_view_object`, a ring buffer
  of lines drawn row by row in view, following the end, lines chosen and copied: done.
- **Background tasks** ([Processes and tasks](processes#tasks)): `task_object`, a Fortran module procedure run on a
  native thread with its own copy of the data, progress and its message posted to the frame loop, cooperative
  cancel, failures reported, the result moved back without a copy; the threading rule enforced at FIGURE's drawing
  entry points (`FIG_ERR_STATE`): done.
- **Feedback** ([Progress bars](widgets#progress-bars), [Notifications](frame-loop#notifications)): `ig_progress_bar`,
  determinate or indeterminate; `app%notify`, notifications drawn by FIGURE in the palette's roles with an icon per
  kind, stacked, fading at the end of their time, dismissed by a click, the last 100 kept (`app%notifications`); the
  status bar as a recipe on the bottom side bar: done.
- **A file browser drawn by FIGURE** ([File dialogs](frame-loop#figure-s-file-browser)): `app%open_file_browser`
  and `app%save_file_browser`, answered through `app%file_dialog_result` as the system's dialogs, the same in window,
  remote and headless modes: folders first with sizes and dates, sorting, filters, hidden files on request, a path
  field with Tab completion, the parent, places (home, working directory, roots, recent folders kept between runs in
  FIGURE's settings file), a new folder, a question before a save replaces a file, errors shown in the browser: done.
- **Multi-line text and a monospace font** ([Multi-line text](widgets#multi-line-text), [Fonts](styles#fonts)):
  `text_buffer_object`, text of any length kept by the native layer and grown while the user types or pastes, CRLF
  read as LF; `ig_input_text_multiline`, editable or read-only, Tab as a character on request, Dear ImGui's undo and
  redo kept; IBM Plex Mono bundled as `'plex-mono'`, the Lucide icons merged into it: done.
- **Drag and drop, the clipboard** ([Drops](frame-loop#drops), [Clipboard](widgets#clipboard)): `app%dropped`, the
  files and folders dropped on the window, reported once with the point of the drop, so that a program tells which
  pane received them; `test_drop` for tests; `ig_set_clipboard` and `ig_get_clipboard`, on the system's clipboard in
  a window, the program's own in headless mode, and in remote mode the program's own joined to the browser's (a copy
  written to it where the browser allows it, a paste read from it): done.
- **A one-line installer** ([Installation](install#the-one-line-installer)): `install.sh --gnu|--nvidia|--fc`, the
  missing packages printed (`--deps` runs them), installs per compiler with a pkg-config file and a manifest,
  `--uninstall`: done.
- **The windowed path verified in CI; Intel ifx** ([Installation](install#verified-platforms-and-compilers)): the
  Platforms workflow runs `figure_hello` in a real window on macOS, Windows (Mesa's software OpenGL) and Linux (Xvfb),
  with the system's frame and with `decorations='figure'`, and checks the captured frames (`scripts/window_check.py`:
  the size, not blank, known widgets' pixels; the frames kept as artifacts); FoBiS modes `tests-ifx`,
  `examples-ifx`, `figure-static-ifx` and an ifx job with the fpm test and the fpm dependency: done.
- **A colormap registry and scientific colormaps** ([Colormaps](colormaps)): `ip_colormap` by name, reversed
  (`<name>_r`) and in discrete bands (`levels`); bundled cividis, inferno, magma, turbo, cmocean's thermal, haline,
  deep, balance and curl, ParaView's Cool to Warm, Crameri's batlow, vik, roma and romaO, each after a licence check;
  `ip_load_colormap` from a CSV table or a ParaView JSON preset; Viridis the default of heatmaps: done.
- **ImPlot extras and contour lines** ([Plots](plots#error-bars-annotations-and-drag-tools)): `ip_error_bars`,
  symmetric or not; `ip_annotation`; drag lines and points (`ip_drag_line_x`, `ip_drag_line_y`, `ip_drag_point`)
  updating the program's variables in place; `ip_contour`, contour lines computed in Fortran (marching squares,
  saddles resolved by the cell's centre value, NaNs leaving holes), levels given or at round numbers
  (`ip_contour_levels`), coloured from a colormap or in one colour, labelled on request; `ip_contour_lines` for the
  segments alone: done.
- **Colour editing and a colour-scale legend** ([Colour editing](widgets#colour-editing),
  [Colormaps](colormaps#a-colour-scale-legend)): `ig_color_edit`, a colour editor with a picker bound to
  `real(real64)` RGB or RGBA; `ip_colormap_legend`, a legend of a colormap, vertical or horizontal, continuous or with
  discrete levels as bands, as an item of any window: done.
- **The 3-D view** ([3-D views](view3d)): `view3d_object`, meshes of triangles, quads, structured surfaces and lines
  read in place from the program's arrays, coloured per vertex or per cell through the colormaps, a camera (orbit,
  pan, zoom, fit, the six standard views) driven by the mouse or the program, picking of the element under a pixel,
  hovered or clicked, up to six clipping planes; drawn by a software rasterizer, the same pixels in window, remote and
  headless modes, rendered only when something changed, at half resolution while the camera moves, on up to 4
  threads: done. The design is settled for v0.3.0 ([why](view3d#why-a-software-renderer)): the software rasterizer
  (A) in every mode; GPU rendering in a window (B) only when an application draws more than about 10⁶ triangles in a
  window, behind a check of the OpenGL renderer; no WebGL renderer in the browser (C).
- **Changing images in remote mode** ([Changing images](remote#changing-images)): a texture updated in consecutive
  frames, the 3-D view while the camera moves, goes as JPEG (`stb_image_write`, bundled), then exact once it is still;
  `init_remote(lossy=.false.)` keeps every image exact. A moving 1600x1000 view: from 91 MB/s raw to 0.8 to 7 MB/s:
  done.

## v0.3.1 — in progress

A patch of three defects of v0.3.0, tracked in [issue #5](https://github.com/szaghi/figure/issues/5):

- **`quit` and `request_frames` safe from a task; `app%wake`:** the flags a task may set or read are atomic, a
  request from another thread wakes a lazy loop at once, and `app%wake()` starts the next frame from any thread
  ([Waking the loop](frame-loop#waking-the-loop)): done.
- **printf formats checked against the value's kind:** every format FIGURE passes to Dear ImGui or ImPlot is
  checked first, a bad one refused with `FIG_ERR_ARGUMENT` ([Formats](plots#formats)): done.
- **The 3-D view owns the mouse wheel while hovered:** inside a scrolling window or child, the wheel over the view
  zooms it and no longer scrolls the container ([Mouse](view3d#mouse)): done.

## v0.4.0 — in progress

Widget control, errors a Fortran programmer can act on, and the plots a monitor and a post-processor need; the plan,
step by step, is [issue #6](https://github.com/szaghi/figure/issues/6):

- **Usage errors reported, not aborted:** a record of the frame's scopes checks every begin/end and push/pop pair
  before Dear ImGui sees it; a wrong end, a scope left open and a widget with no frame open are reported by
  `next_frame` with messages naming the Fortran calls, in three modes (`app%set_checks`: `'abort'`, `'report'`, the
  new default, `'recover'`) ([Pairing and frames](errors#pairing-and-frames)): done.
- **Shortcuts routed to the focused window:** `ig_shortcut(keys [, scope] [, repeat])` goes through Dear ImGui's
  routing: `'focused'` (the new default) fires only in the window with the focus and not while a text field holds
  the key, `'global'` wherever the focus is, `'item'` for the item being edited; `ig_set_next_item_shortcut` gives a
  chord to a button ([Shortcuts](menus#shortcuts)): done.
- **What happened to an item:** `ig_last_item()` returns an `item_status_object`, a snapshot of the item drawn
  last (hovered, active, focused, visible, activated, edited, deactivated, `deactivated_after_edit`, toggled open,
  clicked and double-clicked per button, its rectangle), filled by one native call; `ig_item_hovered([delay])`,
  `ig_any_item_hovered`, `ig_any_item_active`; `ig_combo` reports its pick as an edit
  ([What happened to an item](widgets#what-happened-to-an-item)): done.
- **Scrolling and keyboard focus:** `ig_scroll_here([ratio])` after an item, `ig_scroll_to_pos(pos [, ratio])` for a
  row a list clipper does not draw (`clip%item_height`, new, gives the rows' distance), `ig_get_scroll`,
  `ig_set_scroll`; `ig_focus_here([offset])` gives the next field the keys, `ig_default_focus` the item a modal
  starts from; the log view follows its end through `ig_scroll_here` ([Scrolling and focus](widgets#scrolling-and-focus)): done.

## Next

Candidates, to be driven by what applications need.
