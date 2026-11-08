---
title: 7. The studio's own window
---

# 7. The studio's own window

Part two of the tutorial builds one application, chapter by chapter: a small **solver studio**, which opens a case,
edits its input, runs a solver, follows its residuals and shows the field it computed. Each chapter's program is the
previous one with something added; the page shows what is new, and links the whole program.

The studio starts with its window. A desktop program's frame (the title bar, its buttons, the edges that resize it)
is normally the system's: GNOME's, KDE's, Windows', macOS', or Weston's under WSLg, each with its own colours and
buttons, and under X forwarding the frame of the machine that shows the window. With `decorations='figure'` FIGURE
draws the frame itself, in the colours of the studio's [palette](/guide/styles#looks-and-palettes), with the menus
inside the title bar: the studio looks the same wherever it runs.

<Media name="tut07_window" video alt="The studio's window, dark, with FIGURE's title bar: on the left a flame icon in vermilion and the File menu, the title FIGURE studio centred, and the minimize, maximize and close buttons on the right; below it a Welcome panel says No case open. The pointer moves along the bar to the title, rests on minimize and maximize, each lighter when hovered, then on close, which turns red; a click on close dims the window and opens the question Quit the studio?, with Quit and Cancel; Cancel closes it. Then File, Quit asks the same question, and Cancel again" caption="docs/examples/src/tut07_window.F90" />

The whole program: [tut07_window.F90](https://github.com/szaghi/figure/blob/main/docs/examples/src/tut07_window.F90).

## The window

<<< @/examples/snippets/tut07_window-window.F90{fortran}

- `decorations='figure'` opens the window without the system's frame (borderless, still resizable) and draws a title
  bar on top of it: the window's icon, the program's menus, the title centred, and the minimize, maximize (restore)
  and close buttons. The system's frame stays the default (`decorations='native'`).
- `buttons=side`: `'right'` or `'left'`. The studio passes its optional argument along, so when `side` is absent the
  buttons are on the platform's side: on the left on macOS, on the right elsewhere.
- `app%set_icon(ICON_FLAME)` is the window's icon in the task bar or the dock, and the bar's, in the palette's accent.
  Any of the bundled [icons](/guide/styles#icons) will do, or an RGBA image of your own.
- `stat=stat` keeps the program going where the system has no window icons (a Wayland compositor without the
  `xdg-toplevel-icon` protocol, SDL's offscreen driver): `set_icon` then returns `FIG_ERR_FAILED` with SDL's reason in
  `figure_last_error()`, and the bar shows the icon all the same. Without `stat` the program would stop there
  ([known issues](/guide/known-issues#the-window-s-frame-drawn-by-figure)). Chapter 15 comes back to `stat`.
- `app%set_confirm_quit(.true.)`: the close button no longer ends the program; it asks the program first (below).

## The menus inside the title bar

<<< @/examples/snippets/tut07_window-menus.F90{fortran}

The program declares its menus as it would for the system's frame, with `ig_begin_main_menu_bar` (Dear ImGui's
`BeginMainMenuBar`); FIGURE puts them into the title bar, after the icon. The title moves right when the menus reach
the centre. Chapter 8 fills the menus.

## A question before the window closes

<<< @/examples/snippets/tut07_window-quit.F90{fortran}

- `app%quit_requested()` is `.true.` once per click on the close button (or Alt+F4, or the dock's Quit).
- The question is a modal popup ([Popups and modals](/guide/menus#popups-and-modals)): `ig_open_popup` once, on the
  event; `ig_begin_popup_modal` every frame, which is `.true.` while it is open.
- `app%quit()` ends the loop below: the next `next_frame` returns `.false.`.
- File > Quit asks the same question, but it does not open the popup from inside the menu: a popup's name is
  scoped by the window it is opened in, and inside the menu it would name another popup than the modal declared at
  the top level. The menu item sets `ask_quit`; the popup is opened next to the modal.

<<< @/examples/snippets/tut07_window-loop.F90{fortran}

## What the frame does

The system still moves and resizes the window; it asks the program, point by point, what the window is there
(`SDL_SetWindowHitTest`), and FIGURE answers from the last frame drawn:

- the empty part of the bar, the title and the icon **drag** the window;
- a **double-click** there maximizes it, and another restores it;
- the **edges** (6 pixels, times the display's content scale) and the **corners** (twice that along each side)
  resize it; a maximized window has none;
- the buttons and the menus are the program's, like everything below the bar.

The buttons can go on the left, as on macOS, with `buttons='left'` (here `tut07_window --left`):

<Media name="tut07_left" alt="The same title bar with the buttons on the left: close, hovered and red, then minimize and maximize, then the flame icon and the File menu; the title stays centred" caption="docs/examples/src/tut07_window.F90, run as tut07_window --left" />

What the system's frame does and this one does not (Windows 11's snap layouts, macOS' full-screen button, the window
menu) is listed in the [known issues](/guide/known-issues#the-window-s-frame-drawn-by-figure).

## The frame without a display

Moving and resizing are the system's, so the recording above cannot show them. A headless run can: it draws the same
frame on a virtual display, without a window, and `figure_testing` asks the frame what each point does. The studio
does this when started as `tut07_window --frame-map`:

<<< @/examples/snippets/tut07_window-map.F90{fortran}

<<< @/examples/output/tut07.txt{text}

- `init_headless(..., decorations='figure')` draws the bar as in a window; the buttons' actions are recorded as state,
  and close is a quit request, as in a window.
- `test_frame_hit(x, y)` gives the hit test's answer at a point: `'drag'`, `'client'` (the program's), or a resize
  edge or corner. The map prints one character per cell of 8 x 6 pixels: the bar drags (`=`), the edges and corners
  resize, the menus (`M`) and the three buttons (`_ # X`) are the program's.
- `test_frame_rect(part, ...)` gives a part of the bar (`'bar'`, `'menus'`, `'close'`, ...) to aim at:
  `test_click` twice on the bar is a double-click, and `test_frame_state` reports the window maximized; the
  top-left corner is then no longer a resize corner. A click on close opens the studio's question.

Chapter 16 tests the whole studio this way. The recordings of this tutorial are made in a capture
([Screenshots and videos](/guide/capture)): the frame is drawn in the window's back buffer with the rest, so it is in
every picture.

::: tip What you learned
A window whose frame FIGURE draws: the icon, the title, the buttons on the platform's side, the menus inside the bar;
what the bar and the edges do; the close button asking first; and the frame checked without a display. Reference:
[The window's frame](/guide/frame-loop#the-window-s-frame), [Ask before quitting](/guide/menus#ask-before-quitting),
[Icons](/guide/styles#icons), [Headless testing](/guide/testing#synthetic-input).
:::

**Next:** [8. The application's shell](./08-shell): menus with shortcuts, docked panels, looks and palettes.
