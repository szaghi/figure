---
title: Docking
---

# Docking

Docking is on by default. The user drags a window by its title bar onto another window, or onto a dock space, and
drops it on one of the targets that appear. Dropped in the centre, it becomes a tab of that window; dropped on an
edge, it splits the area. A docked window is dragged out again by its tab. Nothing in the program changes: a docked
window is declared with `ig_begin` and `ig_end` as before.

<Media name="cb_dock" video alt="A window dragged by its title bar onto the centre of the Log area docks there as a tab; then the frequency slider changes the plot" caption="docs/examples/src/cb_dock.F90: a laid-out dock space, and a floating window docked by the user" />

## A dock space

`ig_dock_space(id)`, called every frame **before** the windows that dock into it, covers the display with a dock
space. Where nothing is docked it is transparent, and floating windows stay above it. `ig_dock_id(name)` gives the
id of a name, the same in every frame and every run.

## A layout set by the program

The first time a dock space appears it is empty. A program that wants an initial arrangement builds it once,
while `ig_dock_layout_begin` returns `.true.`: it splits the space into areas and assigns windows to them by name.

<<< @/examples/snippets/cb_dock-layout.F90{fortran}

| Procedure | Does |
|---|---|
| `ig_dock_id(name)` → `integer(int32)` | the dock id of a name |
| `ig_dock_layout_begin(id [, stat])` → `logical` | `.true.` when the dock space has no layout yet, or after `app%switch_layout` and `app%reset_layout` ([Windows and layouts](#windows-and-layouts)): build it now |
| `ig_dock_split(id, direction, fraction, id_at_dir, id_other [, stat])` | split a node: `id_at_dir` takes `fraction` of it on the side `direction` (`'left'`, `'right'`, `'up'`, `'down'`), `id_other` the rest |
| `ig_dock_window(name, id [, stat])` | put the window `name` into the node `id` |
| `ig_dock_layout_end(id [, stat])` | finish the layout |
| `ig_dock_space(id [, flags] [, stat])` | the dock space, every frame, before its windows |
| `ig_window_dock(id, docked)` | inside a window: its dock node (0 if none) and whether it is docked |
| `app%set_docking(enabled [, stat])` | docking on (the default) or off |

`flags` are `ImGuiDockNodeFlags_*`, exported by `figure`: `NoDockingSplit`, `NoResize`, `AutoHideTabBar`,
`NoUndocking`, `NoDockingOverCentralNode`.

The layout is the starting point: the user then rearranges it freely. With `app%init(..., ini_file=...)` Dear ImGui
keeps the user's arrangement across runs, and `ig_dock_layout_begin` returns `.false.` when a saved layout exists.
Without an ini file (the default) every run starts from the program's layout.

**Which tab is in front.** When a layout puts several windows into one node, as tabs, the tab in front is Dear
ImGui's choice: it depends on how the windows took the focus as they first appeared, and follows neither the order of
the `ig_dock_window` calls nor that of the `ig_begin` calls. To choose it, call `ig_focus_window(name)` on the frame
after the layout was built (the window must have been drawn once, with `ig_begin`): its tab comes to the front. The
[tutorial's shell](/manual/tutorial/08-shell#docked-panels-kept-between-runs) does so for its Input tab
(`docs/examples/src/tut08_shell.F90`, region `layout`).

## A window that appears later

A layout is built once, on the first frame. A window that appears afterwards (a file found while the program runs,
a result computed later) is placed in a node with `ig_set_next_window_dock(node)`, right before its `ig_begin`: it
lands there the first time it appears, then stays where the user moves it (`always=.true.`: every frame).

<<< @/examples/snippets/cb_workspace-later.F90{fortran}

`docs/examples/src/cb_workspace.F90` builds the layout below, shows its Result window on the fifth frame and checks,
headless, that it landed in the right node:

<<< @/examples/output/cb_workspace.txt{text}

## A bar along a side

A toolbar, an activity bar or a status bar is a bar along one side of the display that the dock space leaves free:

<<< @/examples/snippets/cb_workspace-bars.F90{fortran}

The bar is a window without title bar, not movable, resizable or dockable, at the side given and as wide (left,
right) or as high (top, bottom) as `size`; the work area loses that strip, so the dock space and the windows placed in
the work area do not cover it. Declare it every frame after the main menu bar and before the dock space, and always
end it with `ig_end`. Several bars stack (a toolbar and a status bar).

## Save and load a layout

How the user arranged the windows (where each is docked, the splits' sizes, the floating windows' places, the tables'
columns) is saved to a file, and loaded back while the program runs:

<<< @/examples/snippets/cb_workspace-layout.F90{fortran}

- The file is Dear ImGui's settings text (`[Window][...]`, `[Docking][Data]`, ...). `comment` lines come first, led
  by `; `: Dear ImGui skips them, the program reads them back itself (which windows it opens on demand, which panels
  are shown: what it, not Dear ImGui, decides).
- A load clears the settings in effect, then reads the file: the dock nodes are rebuilt and the windows that exist
  take their saved place; a window that appears later takes its own when it does. The dock space keeps its layout:
  `ig_dock_layout_begin` is false for it, as on a start with an ini file. The dock space's id must be the one saved
  (the same `ig_dock_id` name).
- With `ini_file` in `app%init` Dear ImGui also keeps the layout by itself, between runs; `save_layout` and
  `load_layout` are for named layouts the user picks.
- Any mode; a file that cannot be read is `FIG_ERR_FAILED`, one with no `[Window]` or `[Docking]` section
  `FIG_ERR_ARGUMENT`.

## Windows and layouts

A tool's windows are the same from one run to the next: a case, its residuals, a log. FIGURE keeps a registry of them,
and of the layouts of the dock space the program offers, so that the program does not write a View menu, a layout
switch, a "reset layout" and the code that remembers what the user closed.

<<< @/examples/snippets/cb_view_menu-register.F90{fortran}

| Procedure | Notes |
|---|---|
| `app%add_window(name [, visible] [, closable] [, in_view_menu] [, remember] [, stat])` | Register the window `name`, the name given to `ig_begin`. |
| `app%window_visible(name [, stat])` → `logical` | `.true.` while it is shown: draw it only then. |
| `app%set_window_visible(name, visible [, stat])` | Show or hide it from the program. |
| `app%view_menu([label] [, stat])` | The View menu, inside a menu bar. |
| `app%add_layout(name [, windows] [, stat])` | Declare a layout; the first added is current. |
| `app%layout()` → `character(len=:), allocatable` | The current layout's name: the one to build (`''` before `add_layout`). |
| `app%switch_layout(name [, stat])` | Make a layout current. |
| `app%reset_layout([stat])` | Lay the current layout out again. |

**The registry.** A registered window is drawn by the program, as any other, while `window_visible(name)` is
`.true.`:

<<< @/examples/snippets/cb_view_menu-layouts.F90{fortran}

- `visible` (default `.true.`): shown at the first run; then as the user left it, when the program keeps its
  [preferences](frame-loop#preferences) and `remember` is `.true.` (the default).
- `closable` (default `.true.`): `ig_begin(name)` without `open` gets a close button, which hides the window
  (`window_visible` turns `.false.`; Dear ImGui writes FIGURE's flag, nothing is called back). With `open` given, the
  program's own flag is used instead.
- `in_view_menu` (default `.true.`): listed in the View menu.

**The View menu.** `app%view_menu()` draws a menu `View` (or `label`) where it is called, in the main menu bar or a
window's: a check item per window listed, in the order added, by the visible part of its name (without `##...`);
then, with layouts, one item per layout, the current one checked; then `Reset layout`, shown when there are layouts
or a dock space was laid out with `ig_dock_layout_begin`.

<<< @/examples/snippets/cb_view_menu-menu.F90{fortran}

**Layouts.** A layout is a name, and the arrangement the program builds for it. FIGURE does not call the program to
build it (no callbacks into Fortran: results are polled): the program builds `app%layout()` when
`ig_dock_layout_begin` returns `.true.`, which it does on the dock space's first frame and, after `switch_layout` or
`reset_layout`, on its next call, for every dock space the program laid out that way (the region `layouts` above).

- `windows`: the registered windows the layout shows; when it becomes current (switched to, or reset), these are
  shown and the other registered windows hidden. Without it, a switch leaves them as they are.
- **The user's changes are kept by layout.** Switching away keeps the arrangement the user left the layout in (Dear
  ImGui's settings, as `save_layout` writes them); switching back gives it back before the next frame, and
  `ig_dock_layout_begin` is `.false.`: the program builds nothing. `reset_layout` forgets the changes of the current
  layout and has it built again. With the preferences, the current layout and each layout's arrangement are kept
  between runs too.
- Without layouts, `reset_layout` (and the View menu's `Reset layout`) lays the dock spaces out again all the same:
  the program's one builder runs again.

`docs/examples/src/cb_view_menu.F90` clicks through its own View menu, headless:

<<< @/examples/output/cb_view_menu.txt{text}

**Rules.** After `init*`; `view_menu` inside a frame and a menu bar (with no frame open: `FIG_ERR_STATE`, a usage
error). A switch or a reset made inside a frame takes effect on the next. A layout's name is shown in the menu as
given.

**Status.** `stat` is optional (absent: `error stop` with the message).

| Failure | Status | Message |
|---|---|---|
| a name added twice | `FIG_ERR_ARGUMENT` | `app%add_window: '<name>' is added already` (`app%add_layout: ...`) |
| an empty name | `FIG_ERR_ARGUMENT` | `app%add_window: the name is empty` (`app%add_layout: ...`) |
| a window not added | `FIG_ERR_ARGUMENT` | `app%window_visible: no window '<name>' was added` (`app%set_window_visible: ...`) |
| a layout not added | `FIG_ERR_ARGUMENT` | `app%switch_layout: no layout '<name>' was added` |
| before `init*`, from a task | `FIG_ERR_STATE` | `app%add_window: figure is not initialized`; a task: as every drawing call |

**Modes.** The same in window, headless and remote modes. **Threads:** the frame loop's thread; a task's call is
refused (`FIG_ERR_STATE`).

**What it does not do.** The menu's labels (`View`, `Reset layout`) are English: give `label` for the menu's own. A
window hidden while docked leaves its tab's place to the others and comes back to its node. A layout does not keep
which registered windows the user showed or hid in it: `windows` is applied each time it becomes current. Floating
windows that are not docked by the builder keep their place across a reset.

## Notes

- Dock ids are Dear ImGui's `ImGuiID` (unsigned 32-bit) carried in `integer(int32)`: pass and compare them, do not
  compute with them.
- Docking works the same in remote mode (the browser draws the result) and in headless mode, where tests can check
  where a window ended (`ig_window_dock`).
- Multi-viewports (windows dragged out of the main window into windows of their own) are not enabled: remote and
  headless modes cannot have them.
- The dock builder is internal to Dear ImGui (it is not part of its stable API); FIGURE's glue wraps the few calls
  above, so a later Dear ImGui release that changes it touches the glue only.
