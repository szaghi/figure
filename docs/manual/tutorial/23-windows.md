---
title: 23. Windows and layouts
---

# 23. Windows and layouts

The studio's windows, again. Since chapter 8 the studio has drawn its own View menu and kept a flag per panel, and
since chapter 15 it has saved a layout file for *Reset layout*. FIGURE keeps that registry itself: the program names its panels and
the layouts it offers, FIGURE draws their part of the View menu, remembers what the user closed, and tells the
program which layout to build. In a window, the user's settings are kept between runs too.

<Media name="tut23_windows" video alt="The plate case open in the Setup layout: Case on the left, the Input, Result and 3-D tabs above, Run below. The View menu lists the panels with check marks, Messages unchecked, then the two layouts, Setup checked and Analysis, then Reset layout, then the studio's own items: Larger text, Look, Palette. A click on Analysis: the Input tab goes, the Result panel and the 3-D view stand side by side above Run, and Messages is a tab beside Run. View > Input shows the input again, as a tab beside Result; View > Setup gives back the first arrangement" caption="docs/examples/src/tut23_windows.F90, run as tut23_windows --examples /tmp/figure-studio --case /tmp/figure-studio/plate" />

The whole program: [tut23_windows.F90](https://github.com/szaghi/figure/blob/main/docs/examples/src/tut23_windows.F90),
chapter 22's studio with the changes below.

## The panels, registered

<<< @/examples/snippets/tut23_windows-register.F90{fortran}

`app%add_window(name)` registers a window by the name `ig_begin` is given; `app%add_layout(name, windows=...)` declares
a layout and the panels it shows ([Windows and layouts](/guide/docking#windows-and-layouts)). The studio does it once,
after `app%init` (and after `init_headless` in its test).

- **Case is not closable** (`closable=.false.`): the panel that says which case is open stays. The others get a close
  button on their tab.
- **Messages starts hidden** (`visible=.false.`): Help > Messages and the View menu show it.
- **A layout's `windows`** are shown when it becomes current, the other registered windows hidden: Analysis has no
  Input panel, and shows Messages.

A registered window is drawn while `app%window_visible(name)` is true, and `ig_begin` is called **without** `open`:
the close button writes FIGURE's flag, which the next frame reads. The flags of chapters 8 and 15 (`shown(5)`,
`messages_shown`) are gone:

<<< @/examples/snippets/tut23_windows-panels.F90{fortran}

The tools' bar shows a panel the user closed with `app%set_window_visible(name, .true.)`.

## The View menu

<<< @/examples/snippets/tut23_windows-view_menu.F90{fortran}

`app%view_menu()` draws the menu `View`: a check item per registered panel, the layouts with the current one checked,
then *Reset layout*. The studio's own items, *Larger text*, *Look* and *Palette*, follow in the same menu: Dear ImGui
appends the items of a second `ig_begin_menu('View')` to the menu of that name. *Help > Messages* uses the registry
too: `app%window_visible('Messages')` checks it, `app%set_window_visible` follows the click.

## Layouts the program builds

<<< @/examples/snippets/tut23_windows-layouts.F90{fortran}

FIGURE does not call the program to build a layout (no callbacks into Fortran): `ig_dock_layout_begin` is true on the
dock space's first frame and on the frame after a switch or a reset, and the program builds `app%layout()`, the one
the user chose. Chapter 15's *Reset layout*, a layout file saved at the first frame and loaded again, is gone with it:
FIGURE's *Reset layout* forgets the user's changes to the current layout and has the program build it again.

- **The user's changes are kept per layout.** Dragging the 3-D tab out in Analysis, switching to Setup and back: the
  3-D panel is where the user left it, and `ig_dock_layout_begin` is false (nothing to build).
- **Messages** is docked beside Run by both layouts; chapter 15's `ig_set_next_window_dock` for it is not needed.

## Settings kept between runs

<<< @/examples/snippets/tut23_windows-prefs.F90{fortran}

`app%open_prefs('figure-studio')` keeps the studio's preferences in the platform's folder (`~/.local/share/figure-studio/`
on Linux): the panels shown, the current layout and each layout's arrangement, the style chosen in View > Look and
Palette, the window's place and size ([Preferences](/guide/frame-loop#preferences)). The studio adds its own values:

<<< @/examples/snippets/tut23_windows-load_prefs.F90{fortran}

`add_recent` saves the recent cases with `app%save_pref('recent.1', dir)` and so on, *Larger text* its check mark; the
file is written when something changed, every 30 s and at `app%destroy`. The test calls no `open_prefs`: it starts from
the program's defaults, and a recording neither reads nor writes the file ([Capture](/guide/capture)). In remote mode
the studio keeps nothing: the browser's user is not this machine's.

## The test

The test picks the layouts from the View menu as the user does, with `test_menu_click`, and draws the studio until it
is idle with `test_run` ([Finding items by path](/guide/testing#finding-items-by-path)):

<<< @/examples/snippets/tut23_windows-layout_test.F90{fortran}

<<< @/examples/snippets/tut23_windows-settle.F90{fortran}

<<< @/examples/output/tut23.txt{text}

::: tip What you learned
`app%add_window`, `app%window_visible` and `app%set_window_visible`, a registry of the panels; `app%add_layout` and
`app%layout()`, layouts the program builds when `ig_dock_layout_begin` says so; `app%view_menu`, the View menu's part
FIGURE draws; `app%open_prefs`, `app%save_pref` and `app%load_pref`, the user's settings kept. Reference:
[Windows and layouts](/guide/docking#windows-and-layouts), [Preferences](/guide/frame-loop#preferences).
:::
