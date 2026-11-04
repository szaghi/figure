---
title: 2. Widgets and state
---

# 2. Widgets and state

The setup panel of a solver: its parameters are ordinary Fortran variables, and the widgets edit them in place.

<<< @/examples/snippets/tut02_widgets.F90{fortran}

<Media name="tut02_widgets" video alt="Dragging the cells slider, toggling viscous, pressing Run twice and closing the Tools window" caption="tut02_widgets: every change is in the program's variables at once, as the status line shows" />

## Widgets edit your variables

<<< @/examples/snippets/tut02_widgets-widgets.F90{fortran}

- `ig_slider` is generic: `cells` is `int32`, `relax` is `real32`, `cfl` is `real64`; bounds have the same kind.
- `ig_input` edits a `real64` with `-`/`+` buttons (`step`) and a C `printf` `format`.
- Each widget returns `.true.` in the frame the user changed the value. `if (...) continue` discards it; the
  `ig_input` line uses it to clamp the value as soon as it is edited.
- `ig_button` returns `.true.` on the frame it is clicked: the counter grows by one per click.
- `ig_text` shows plain text: numbers are composed with an internal `write`, and `trim` drops the trailing blanks of
  the buffer.
- `ig_same_line` puts the next item on the same line; `ig_separator` draws a line.

None of these variables needs `target`, and nothing is registered: the next frame, the widgets read the variables
again. Change `cfl` in the program, and the slider moves.

## Same text, different widgets

<<< @/examples/snippets/tut02_widgets-ids.F90{fortran}

Two buttons labelled "Reset" would be one widget to Dear ImGui, which identifies widgets by label. The text after
`##` is part of the identifier but is not shown.

## A window the user can close

<<< @/examples/snippets/tut02_widgets-closable.F90{fortran}

With the `open` argument, the window gets a close button that sets `show_tools` to `.false.`; guarding the window with
the same variable makes it disappear, and the check box in "Setup" brings it back. `ig_show_demo_window` is the Dear
ImGui demo, with the same convention.

`ig_set_next_window` places a window the first time it appears; afterwards the user moves it. The place is not
remembered across runs unless the program names a layout file (`app%init(..., ini_file='hello.ini')`, see
[Frame loop](/guide/frame-loop#the-application)).

::: tip What you learned
Widgets bound to variables, their return values, identifiers, closable windows. Reference: [Widgets](/guide/widgets).
:::

Next: [3. Plots](./03-plots).
