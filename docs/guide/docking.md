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

## Notes

- Dock ids are Dear ImGui's `ImGuiID` (unsigned 32-bit) carried in `integer(int32)`: pass and compare them, do not
  compute with them.
- Docking works the same in remote mode (the browser draws the result) and in headless mode, where tests can check
  where a window ended (`ig_window_dock`).
- Multi-viewports (windows dragged out of the main window into windows of their own) are not enabled: remote and
  headless modes cannot have them.
- The dock builder is internal to Dear ImGui (it is not part of its stable API); FIGURE's glue wraps the few calls
  above, so a later Dear ImGui release that changes it touches the glue only.
