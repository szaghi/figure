---
title: 8. The application's shell
---

# 8. The application's shell

Chapter 7 gave the studio a window. This chapter gives it the shell the next chapters fill: menus in the title bar
with their keyboard shortcuts, a bar of workspace buttons, four panels docked side by side in a layout that is kept
between runs, and a look and a palette chosen from the View menu.

<Media name="tut08_shell" video alt="The studio with a bar of four workspace buttons on the left, Case, Input, Run and Result, each an icon above its label, and four docked panels: Case on the left, Input and Result as two tabs on the right, Run below them. View, Look, fluent rounds the corners and enlarges the padding; View, Palette, seal-light turns the whole window light, title bar included. The Result button brings the Result tab forward; F1 opens the About box, which says Look fluent, palette seal-light; ctrl+q opens the quit question, and Cancel closes it" caption="docs/examples/src/tut08_shell.F90" />

The whole program: [tut08_shell.F90](https://github.com/szaghi/figure/blob/main/docs/examples/src/tut08_shell.F90).

## Menus and shortcuts

<<< @/examples/snippets/tut08_shell-menus.F90{fortran}

- `ig_begin_menu(label)` and `ig_end_menu()` are a menu, or a submenu inside one (Look, Palette); `ig_end_menu`
  follows only a begin that returned `.true.`.
- `ig_menu_item(label, shortcut=, selected=, enabled=)` is `.true.` on the frame it is picked. With `selected` it
  shows a check mark, and a pick toggles the variable: the panels' items show and hide the panels directly. For a
  choice of one among several (the look) the program passes a copy, `on`, and changes the choice itself.
- `enabled=.false.` greys an item out: Reset layout until there is a layout to go back to.
- `shortcut='Ctrl+Q'` is only the text on the right of the item. The keys are read by `ig_shortcut('ctrl+q')`,
  every frame and outside the menus, since the menu is closed most of the time. On macOS `ctrl` is the cmd key, as
  for every shortcut of Dear ImGui ([Shortcuts](/guide/menus#shortcuts)).
- The labels carry [icons](/guide/styles#icons): an `ICON_*` constant is a UTF-8 string, joined to the text with
  `//`.

## A bar of workspace buttons

<<< @/examples/snippets/tut08_shell-tools.F90{fortran}

- `ig_begin_side_bar('tools', 'left', 76)` is a bar along the left side of the window, below the title bar: a window
  without title, not movable, which the dock space leaves free ([A bar along a side](/guide/docking#a-bar-along-a-side)).
  It is always ended with `ig_end`.
- `ig_tool_button(label, icon, selected=)` is a workspace button, an icon above its label; the selected one is framed
  in the accent colour. `ig_tooltip` explains the button under the pointer.
- `ig_focus_window(name)` brings a panel forward; for a docked panel, its tab.

## Docked panels, kept between runs

<<< @/examples/snippets/tut08_shell-layout.F90{fortran}

<<< @/examples/snippets/tut08_shell-panels.F90{fortran}

- `ig_dock_space(root)` fills what the title bar and the side bar leave with a dock space, every frame and before
  the panels. The user drags panels by their tabs to dock them elsewhere, side by side or as tabs, or out to float.
- `ig_dock_layout_begin(root)` is `.true.` when the dock space has no layout yet: the program then splits it
  (`ig_dock_split`: a fraction of the node on one side) and puts each panel into a node (`ig_dock_window`); Input and
  Result share a node, as two tabs.
- `ini_file='tut08_shell.ini'` in `app%init` (below) makes Dear ImGui keep the layout in that file:
  the user's arrangement comes back at the next run, and `ig_dock_layout_begin` is then `.false.`.
- `app%save_layout` writes the layout the program set, on the frame after it was set, and View > Reset layout loads
  it back with `app%load_layout`: the user's arrangement is undone, the program's restored
  ([Save and load a layout](/guide/docking#save-and-load-a-layout)).
- `ig_begin('Case', open=shown(1))` gives the panel's tab a close button, which sets `shown(1)` to `.false.`: the
  program stops drawing the panel, and View > Case or the Case button bring it back.

<<< @/examples/snippets/tut08_shell-window.F90{fortran}

## Looks and palettes

<<< @/examples/snippets/tut08_shell-style.F90{fortran}

A style has two parts, chosen separately ([Looks and palettes](/guide/styles#looks-and-palettes)): the **look**, the
geometry (rounding, padding, spacing), and the **palette**, the colours. `app%set_style(look=name)` changes the first
and keeps the colours; `app%set_style(palette=name)` the second and keeps the geometry. The title bar drawn by FIGURE
takes the palette's colours with the rest. The names are passed trimmed: `'fluent '`, with the blank of the
array's padding, is not a look.

## About

<<< @/examples/snippets/tut08_shell-about.F90{fortran}

The About box is a modal opened at the top level, as chapter 7's question; `ig_set_next_window` places it and sizes
it the first time it appears, and `ig_text_wrapped` wraps its text at the box's edge.

::: tip What you learned
Menus and submenus with check marks, disabled items and icons; shortcuts read every frame; a side bar of workspace
buttons; panels docked in a layout the program sets, the user changes, Dear ImGui keeps between runs and the program
restores; looks and palettes. Reference: [Menus, popups and shortcuts](/guide/menus), [Docking](/guide/docking),
[Styles](/guide/styles), [Widgets](/guide/widgets).
:::

**Next:** [9. The case](./09-case): opening a case from FIGURE's file browser or by a drop, and asking before
changes are lost.
