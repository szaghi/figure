---
title: Changelog
---

# Changelog

Every release, and what is done since the last one (Unreleased). The state of the work is in the [roadmap](roadmap).
The list is generated from the commit messages by git-cliff (`git cliff -o CHANGELOG.md`; `scripts/release.sh`
regenerates it for each release).

## Migration to v0.4.0

What a program written for v0.3.1 meets in v0.4.0. Each line links to the "Changed in v0.4.0" box of the section
that has the details: the old behaviour, the new one, and why.

| Change | What to do |
|---|---|
| [Usage errors reported](errors#pairing-and-frames): a wrong end, a scope left open or a drawing call with no frame open no longer abort inside Dear ImGui; `next_frame(stat)` reports them (mode `'report'`, the default) | pass `stat` to `next_frame` and act on `FIG_ERR_STATE`, or `app%set_checks('abort')` to stop at the faulty call; a loop without `stat` stops with FIGURE's message |
| [Shortcuts routed](menus#shortcuts): `ig_shortcut`'s default scope is `'focused'`; a call inside a window fires only while that window has the focus, and no longer while a text field uses the key | calls outside every window behave as before; a key inside a window that must work everywhere takes `scope='global'` |
| [Numbers](widgets#numbers): `ig_input` and `ig_slider` take every kind, vectors, formats, `scale`, `clamp`; they moved from `figure_imgui` to `figure_numbers`; a slider with ends beyond half the kind's range is refused | nothing for `use figure`; a `use figure_imgui, only: ig_input` names `figure_numbers` or `figure` instead |
| [Tables](errors#tables): `ig_begin_table` with `columns` outside 1 to 511 is refused with `FIG_ERR_ARGUMENT` | pass a valid count (it aborted before) |
| [Plot axes](plots#axes): `ip_setup_axes` takes `xscale`/`yscale`; `xlog`/`ylog` are deprecated synonyms; new arguments come before `stat`; setup calls out of place are [usage errors](errors#plot-axes) | name `stat` if it was passed by position; prefer `yscale='log'` to `ylog=.true.` |
| [Data in place](plots#data-in-place): the plot items take arrays of any stride and integer abscissae; the dummies are no longer `contiguous` | nothing: every v0.3.1 call compiles and draws as before |
| [Drag tools](plots#error-bars-annotations-and-drag-tools): `ip_drag_line_x`, `ip_drag_line_y`, `ip_drag_point` outside a plot are usage errors | call them between `ip_begin_plot` and `ip_end_plot` (it aborted before) |

The tutorial's [part three](/manual/tutorial/18-checks) shows the new calls in the solver studio of part two.

<!--@include: ../../CHANGELOG.md{3,}-->
