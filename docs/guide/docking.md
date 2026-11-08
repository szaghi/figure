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
| `ig_dock_layout_begin(id [, stat])` → `logical` | `.true.` when the dock space has no layout yet: build it now |
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

```fortran
call ig_set_next_window_dock(right)      ! the node from the layout
if (ig_begin(trim(file_name))) then
   ! ...
endif
call ig_end()
```

## A bar along a side

A toolbar, an activity bar or a status bar is a bar along one side of the display that the dock space leaves free:

```fortran
if (ig_begin_main_menu_bar()) then
   ! menus
   call ig_end_main_menu_bar()
endif
if (ig_begin_side_bar('Tools', 'left', 64.0_real64)) then     ! 'left', 'right', 'top' or 'bottom'
   if (ig_button('Input')) tool = 1
   if (ig_button('Run')) tool = 2
endif
call ig_end()
call ig_dock_space(root)                                      ! fills what the bars leave
```

The bar is a window without title bar, not movable, resizable or dockable, at the side given and as wide (left,
right) or as high (top, bottom) as `size`; the work area loses that strip, so the dock space and the windows placed in
the work area do not cover it. Declare it every frame after the main menu bar and before the dock space, and always
end it with `ig_end`. Several bars stack (a toolbar and a status bar).

## Save and load a layout

How the user arranged the windows (where each is docked, the splits' sizes, the floating windows' places, the tables'
columns) is saved to a file, and loaded back while the program runs:

```fortran
call app%save_layout('analysis.layout', comment='popped = ufor_03.dat ufor_07.dat')   ! any time
call app%load_layout('analysis.layout', stat=stat)                                   ! applied before the next frame
```

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

## Notes

- Dock ids are Dear ImGui's `ImGuiID` (unsigned 32-bit) carried in `integer(int32)`: pass and compare them, do not
  compute with them.
- Docking works the same in remote mode (the browser draws the result) and in headless mode, where tests can check
  where a window ended (`ig_window_dock`).
- Multi-viewports (windows dragged out of the main window into windows of their own) are not enabled: remote and
  headless modes cannot have them.
- The dock builder is internal to Dear ImGui (it is not part of its stable API); FIGURE's glue wraps the few calls
  above, so a later Dear ImGui release that changes it touches the glue only.
