---
title: 20. Tables that act
---

# 20. Tables that act

A table of part two showed values; in this chapter the studio's tables answer the user. The Run panel keeps the
session's runs in a table that sorts by the column clicked, with a menu and a picture of each run's residuals on its
row; the boundaries' table gets radio buttons and a menu per side; the body's centre and the tolerance get the number
widgets made for them.

<Media name="tut20_tables" video alt="F5 runs the plate case. In Input, Solver, the omega slider is dragged from 1.8 to 1.5; F5 runs the case again, 287 iterations this time. The Run panel's Runs tab shows a table: run, case, residual, outcome, iterations. The pointer rests on run 1: a tooltip holds a small plot of its residuals falling on a log axis. A click on the iterations header sorts the rows by iterations, fewest first, its arrow pointing up; a second click, most first. A right click on a row opens a menu: Copy the residual, Remove from the list; escape closes it. In Input, Boundaries: each side has two radio buttons, fixed and insulated; a right click on west opens its menu, Every side as this one, Insulated, and the first is picked. In Body, the centre's x box is dragged from 0.9 to 1.02" caption="docs/examples/src/tut20_tables.F90, run as tut20_tables --examples /tmp/figure-studio --case /tmp/figure-studio/plate" />

The whole program: [tut20_tables.F90](https://github.com/szaghi/figure/blob/main/docs/examples/src/tut20_tables.F90),
chapter 19's studio with the changes below.

## The session's runs

When a run ends, `follow_run` adds it to `runs`, an array of `run_t`: its number, the case's title, the iterations,
the last residual, the outcome and its residual history. The Run panel has two tabs now: *This run* (the log and the
live plot of chapter 11) and *Runs*:

<<< @/examples/snippets/tut20_tables-runs.F90{fortran}

- **A frozen header.** `freeze_rows=1` keeps the header row in view while the rows scroll: a table with a frozen row
  scrolls by itself, in the height left in the tab ([Tables](/guide/widgets#tables)).
- **Sorting is the program's.** `sortable=.true.` makes the headers clickable; `ig_table_sort(key, descending)` is
  true on the frame the user asks a new order (and on the first frame, with the `default_sort` column), and gives the
  column and the direction. FIGURE does not move the rows: the studio sorts a permutation, `order`, and draws the rows
  in that order. A run added later takes its place by the same sort.
- **Colour with a mark.** A run that did not converge has its row shaded in the palette's error colour, and its
  outcome reads `[!!] stopped` or `[!!] failed`: the colour is never the only sign.
- Each row's widgets are in an id scope of the run's number (`ig_push_id`), so that the rows' menus and selectables
  are told apart.

## A menu and a picture on each row

<<< @/examples/snippets/tut20_tables-run_menu.F90{fortran}

`ig_begin_popup_context(id)` opens a menu on a right click over the item drawn just before it, here the row's
selectable; it is a popup, closed with `ig_end_popup` after a true begin ([Context menus](/guide/menus#context-menus)).
The row is removed after the table is drawn, not while: the loop draws the list as it was at the start of the frame.
`ig_begin_item_tooltip()` opens a tooltip when the pointer rests on the same item, and a tooltip can hold anything: a
plot of the run's residuals ([Tooltips](/guide/widgets#tooltips)).

## Choices in the boundaries' table

<<< @/examples/snippets/tut20_tables-radio.F90{fortran}

`ig_radio(label, current, value)` is a button of a group sharing `current`: a click sets `current = value`, and the
button whose value equals `current` is drawn chosen ([Choices](/guide/widgets#choices)). Two radio buttons show both
conditions at once, where chapter 10's drop-down list hid one. The side's name has a menu of its own:

<<< @/examples/snippets/tut20_tables-side_menu.F90{fortran}

## Numbers

The body's centre is one widget of two numbers, a drag box per component: drag a box (0.002 m per pixel), or
double-click it and type ([Numbers](/guide/widgets#numbers)):

<<< @/examples/snippets/tut20_tables-centre.F90{fortran}

The tolerance goes from 10⁻¹⁰ to 10⁻², eight decades: on a linear slider every value below 10⁻³ would be in its first
pixel. `scale='log'` gives each decade the same length:

<<< @/examples/snippets/tut20_tables-tolerance.F90{fortran}

The formats are checked against the value's kind before Dear ImGui uses them: `'%d'` for a real is refused with
`FIG_ERR_ARGUMENT` ([Formats](/guide/plots#formats)).

## The test

Two runs, the second with a smaller omega; the Runs tab clicked, the iterations' header clicked twice, a right click
on a row:

<<< @/examples/snippets/tut20_tables-runs_test.F90{fortran}

<<< @/examples/output/tut20.txt{text}

(The `ig_end_tab` line is the report of [chapter 18](./18-checks#the-test-fails-on-any-mistake)'s deliberate mistake.)

::: tip What you learned
A table with a frozen header that the user sorts and the program orders; a row coloured with a mark; a context menu
and a tooltip holding a plot on a row; radio buttons; a drag box of two numbers; a slider on a log scale.
Reference: [Tables](/guide/widgets#tables), [Context menus](/guide/menus#context-menus),
[Tooltips](/guide/widgets#tooltips), [Numbers](/guide/widgets#numbers), [Choices](/guide/widgets#choices).
:::

**Next:** [21. A sketch and a monitor](./21-monitor): the plate drawn on a canvas, and the residuals with the solver's
mean temperature on a second axis, a readout and an averaging window.
