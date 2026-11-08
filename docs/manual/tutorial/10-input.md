---
title: 10. The input editor
---

# 10. The input editor

Chapter 9 opened a case; its Input panel now edits the case's input. A tree lists the input's sections; a form edits
the section chosen, with numeric fields, sliders, drop-down lists and a table; the same input is shown as the text of
`heat.inp`, in the monospace font, where it can be edited too. Edit > Undo takes back the form's edits.

<Media name="tut10_input" video alt="The studio with the plate case open. In the Input panel a tree lists heat.inp with its sections Grid, Boundaries (with the four sides west, east, south, north), Body and Solver; on the right a form. A click on east shows the table of the boundary conditions, one row per side with a drop-down list of the condition and a field of the temperature, greyed out for the insulated east side; east becomes fixed and its temperature 40, and the window's title gets a star. Solver shows a slider for omega, dragged from 1.80 to 1.59, a field for the tolerance and one for the iterations. The heat.inp tab shows the input as the file holds it, in a monospace font, with the new values; max_iter is changed to 3000 in the text, Apply, and the form shows 3000; ctrl+z takes it back to 4000" caption="docs/examples/src/tut10_input.F90, run as tut10_input --examples /tmp/figure-studio --case /tmp/figure-studio/plate" />

The whole program: [tut10_input.F90](https://github.com/szaghi/figure/blob/main/docs/examples/src/tut10_input.F90).
From this chapter on, `--case DIR` opens a case at the start.

## A tree of the sections

<<< @/examples/snippets/tut10_input-tree.F90{fortran}

- The tree is in a child region of its own (`ig_begin_child`, 170 pixels wide, framed); the form goes beside it.
- `ig_tree_node(label, default_open=, selected=, leaf=, span_full_width=, clicked=)` is `.true.` while the node is
  open: its children are drawn, then `ig_tree_pop()` closes it, only after a `.true.`. A `leaf` has no arrow and no
  children ([Trees](/guide/widgets#trees)).
- `clicked` tells a click on the label from a click on the arrow: the arrow opens and closes, the label chooses the
  section. The sides are leaves of Boundaries; a click on any of them shows the table.

## Forms and a table

<<< @/examples/snippets/tut10_input-form.F90{fortran}

Each widget is bound to a component of `inp`, the case's input, and edits it in place; it returns `.true.` on the
frame it changes it ([Widgets](/guide/widgets)):

- `ig_input(label, value, step=)` for an integer, with + and - buttons; `ig_input(label, value, format=)` for a
  real, shown with a C format (`'%.3f'`, `'%.1e'`).
- `ig_slider(label, value, vmin, vmax)` for a value in a range: the body stays inside the plate. A slider gives any
  real, so the studio rounds the value to the input file's precision.
- `ig_tooltip` explains the widget under the pointer.

<<< @/examples/snippets/tut10_input-table.F90{fortran}

- `ig_begin_table(id, columns)` and `ig_end_table()`, paired; `ig_table_setup_column` names each column, with a
  fixed width or a share of the rest, and `ig_table_headers_row` draws the names.
- Every row repeats the same widgets with the same labels: `ig_push_id(k)` and `ig_pop_id()` give each row its own
  id scope, and the labels start with `##`, so that nothing is shown beside the field.
- `ig_combo(label, current, items)` is a drop-down list of `KINDS`; `current` is the index chosen.
- `ig_begin_disabled(kind == 2)` greys the temperature out on an insulated side: it does not apply there.
- `ig_set_next_item_width(-1)` makes the next widget fill its cell.

## Undo

<<< @/examples/snippets/tut10_input-undo.F90{fortran}

<<< @/examples/snippets/tut10_input-edit-menu.F90{fortran}

The form keeps the input as it was before each edit. An edit lasts several frames (a slider dragged, a number
typed), so the studio keeps the state only on the first frame of a change: one Undo per edit. Edit > Undo and ctrl+z
bring the last one back. In the text (below), ctrl+z is the text field's own undo: the studio reads ctrl+z only
while the form is shown.

## The input as text

<<< @/examples/snippets/tut10_input-source.F90{fortran}

- `ig_input_text_multiline(label, buffer)` edits a text of any length, kept in a `text_buffer_object`
  ([Multi-line text](/guide/widgets#multi-line-text)): Enter starts a new line, ctrl+z and ctrl+y undo and redo,
  ctrl+c and ctrl+v copy and paste. `width=-1` and `height=-1` fill the space left.
- `ig_push_font('plex-mono')` and `ig_pop_font()` draw it in IBM Plex Mono, the bundled monospace font, so that the
  input's columns line up ([Fonts](/guide/styles#fonts)).
- `source%set(case_text(inp))` replaces the text whenever the form changes the input: the form and the text show
  the same input.

<<< @/examples/snippets/tut10_input-apply.F90{fortran}

Apply reads the text as the namelist: Fortran reads a namelist from a file, so the text goes to a scratch file,
line by line, and `read_input` reads it back from there. A text that does not read leaves the input as it was, and a
notification gives the run time's message; the text stays, to be corrected.

::: tip What you learned
A tree with leaves and clickable labels; numeric fields, sliders, drop-down lists and tooltips bound to Fortran
variables; a table with a row per item and an id scope per row; greyed-out widgets; an undo of the form's edits; a
multi-line text field in the monospace font, read back as a namelist. Reference: [Widgets](/guide/widgets),
[Trees](/guide/widgets#trees), [Multi-line text](/guide/widgets#multi-line-text), [Fonts](/guide/styles#fonts).
:::

**Next:** [11. Running the solver](./11-run): the solver as a process, its log, a live plot of its residuals.
