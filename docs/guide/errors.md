---
title: Error handling
---

# Error handling

## stat or error stop

Procedures that can fail take an optional `integer(int32), intent(out) :: stat`:

- **with `stat`**, a failure is returned: `stat` receives `FIG_OK` or a `FIG_ERR_*` code, and
  `figure_last_error()` gives the message;
- **without `stat`**, a failure writes `FIGURE error: <message>` to standard error and stops the program with
  `error stop 1`.

Every procedure that can fail takes an optional `stat` (the [feature map](features) shows which); the others cannot
fail in a way FIGURE detects (`destroy` is safe in any state).

<<< @/examples/snippets/cb_stat-stat.F90{fortran}

<<< @/examples/output/cb_stat.txt{text}

Without `stat`:

<<< @/examples/snippets/cb_error_stop-stop.F90{fortran}

<<< @/examples/output/cb_error_stop.txt{text}

## Status codes

| Code | Value | Meaning |
|---|---|---|
| `FIG_OK` | 0 | success |
| `FIG_ERR_STATE` | 1 | call not allowed in the current state: `init` twice, `next_frame` before `init`, a process started again while it runs ([Processes](processes#statuses)), a drawing procedure called from a task ([Tasks](processes#tasks)), a file dialog or browser whose id is still open ([File dialogs](frame-loop#file-dialogs)), `ip_annotation` outside a plot, a usage error: a wrong end, a scope left open, a drawing call with no frame open ([Pairing and frames](#pairing-and-frames)) |
| `FIG_ERR_ARGUMENT` | 2 | invalid argument: non-positive window size, `ip_line` arrays of different sizes, a palette below the [contrast rule](styles#the-contrast-rule), a text of 2 GiB or more for a [text buffer](widgets#multi-line-text), an unknown colormap name or a malformed colormap file ([Colormaps](colormaps#statuses-and-modes)), a colour without 4 components or `nlevels` < 1 for the [plot extras and contours](plots#error-bars-annotations-and-drag-tools), a mesh array not contiguous or a connectivity index out of range for a [3-D view](view3d#statuses-and-modes), a `printf` format that is not a format of one real for `ig_input`, `ip_setup_axes`, `ip_heatmap`, `ip_colormap_scale` or `ip_colormap_legend` ([Formats](plots#formats)) |
| `FIG_ERR_FAILED` | 3 | the platform (SDL, OpenGL) reported a failure: no display, no OpenGL 3 context, a program that cannot be started |
| `FIG_ERR_EXCEPTION` | 4 | a C++ exception was caught at the C boundary |

The codes are `integer(c_int)` parameters; compare them with `stat` directly (`stat /= FIG_OK`). C++ exceptions never
cross into Fortran: every glue function catches them and returns `FIG_ERR_EXCEPTION` with the exception's message.

## figure_last_error

`figure_last_error()` returns the message of the last failure detected by the native layer, as an allocatable
character. The message is not cleared by a successful call: read it right after the failing call.

`ip_line` checks `size(x) == size(y)` on the Fortran side, before calling the native layer; a mismatch returns
`FIG_ERR_ARGUMENT` with the message `ip_line: the series have different sizes` (each item names itself).

<<< @/examples/snippets/cb_stat-line.F90{fortran}

A `printf` format is checked the same way, on the Fortran side, before Dear ImGui or ImPlot formats a value with it
([Formats](plots#formats)): a format that is not one of a real gives `FIG_ERR_ARGUMENT` with a message naming the
procedure, the argument and the format, and nothing is drawn. The full program checks `ig_input`; its output is above:

<<< @/examples/snippets/cb_stat-format.F90{fortran}

| Procedure and argument | Message |
|---|---|
| `ig_input`, `format` | `ig_input: format '<format>' is not a format of a real: one conversion %f, %e, %g or %a (or %F, %E, %G, %A) expected, with optional flags, width and precision` |
| `ip_setup_axes`, `xformat` / `yformat` | the same, starting `ip_setup_axes: xformat` (or `yformat`) |
| `ip_heatmap`, `ip_colormap_scale`, `ip_colormap_legend`, `label_format` | the same, starting `<procedure>: label_format` (`ip_colormap_legend` refuses only a format with a conversion: one without is text) |

## Pairing and frames

Dear ImGui's begin/end pairs are the likeliest bug of a FIGURE program: an `ig_end_table` where an `ig_tree_pop`
belongs, an `ip_end_plot` after a plot that did not begin. FIGURE keeps a **scope record** of the frame, in its native
layer: every begin/end and push/pop pair it wraps registers there (its kind, its label, what the begin returned, the
Fortran procedure), and every end is checked against the record **before** Dear ImGui sees it. A wrong end never
reaches Dear ImGui, so the error is a message naming the Fortran calls, not an assertion inside `imgui.cpp`.

::: warning Changed in v0.4.0
Until v0.3.1 a broken pairing aborted the program inside Dear ImGui, with an assertion that named no Fortran call
(`imgui.cpp:11325: ... Assertion '(0) && "Missing End()"' failed`), and a widget called with no frame open could crash.
From v0.4.0 FIGURE checks the pairs itself, by default in mode `'report'`: the wrong call does nothing, the frame goes
on, and the next `app%next_frame(stat)` returns `FIG_ERR_STATE` with the messages. A loop that passes no `stat` to
`next_frame` still stops (`error stop`), now with FIGURE's message; one that passes a `stat` and ignores it no longer
stops. `app%set_checks('abort')` stops at the faulty call itself.
:::

### The rules checked

| Rule | Pairs |
|---|---|
| **Always paired:** the end follows every begin, whatever it returned | `ig_begin`, `ig_begin_side_bar` / `ig_end`; `ig_begin_child` / `ig_end_child`; `ig_push_id` / `ig_pop_id`; `ig_begin_disabled` / `ig_end_disabled`; `ig_push_font` / `ig_pop_font`; `ig_push_style_color`, `ip_push_style_color` / `ig_pop_style_color`, `ip_pop_style_color`; `ig_push_style_var`, `ip_push_style_var` / `ig_pop_style_var`, `ip_pop_style_var` |
| **End only after a true begin** | `ig_begin_tab_bar` / `ig_end_tab_bar`; `ig_begin_tab` / `ig_end_tab`; `ig_begin_table` / `ig_end_table`; `ig_tree_node` / `ig_tree_pop`; `ig_begin_main_menu_bar` / `ig_end_main_menu_bar`; `ig_begin_menu_bar` / `ig_end_menu_bar`; `ig_begin_menu` / `ig_end_menu`; `ig_begin_popup`, `ig_begin_popup_modal` / `ig_end_popup`; `ip_begin_plot` / `ip_end_plot`; `ip_begin_subplots` / `ip_end_subplots`; `ig_dock_layout_begin` / `ig_dock_layout_end` |

- **Scopes nest.** Windows, child regions, tab bars, tabs, tables, tree nodes, menu bars, menus, popups, plots,
  subplot figures, dock layouts and id scopes are closed innermost first: an end that is not the end of the innermost
  open one is wrong.
- **Pushes do not nest.** A style colour, a style variable, a font and a disabled block are undone by the newest push
  of their own kind, wherever it was made (a colour pushed before `ig_begin` and popped right after it is right, as
  in Dear ImGui). A font or a disabled block opened inside a window (a window, a child region, a popup, a menu, the
  main menu bar) is closed before that window's end, as Dear ImGui's `End` requires.
- **Everything is closed by the end of the frame**: what is still open when `next_frame` is called is an error.
- **Drawing needs a frame.** A drawing procedure (a widget, a begin or an end, a plot item, a style push) called with
  no frame open, before the first `next_frame` or after the loop, is refused: "`ig_button: no frame open`". Calls
  that draw nothing (`app%set_style`, `ig_set_style_color`, `ip_colormap`, `ig_text_size`, a texture's `init`, a 3-D
  view's mesh) work outside a frame as before. A task is refused first, as always ([Tasks](processes#tasks)).
- **Raw calls are compared too.** At every end, and at the end of the frame, the sizes of Dear ImGui's stacks
  (windows, ids, tree depth, colours, style variables, fonts, focus scopes, groups, item flags, popups, disabled
  blocks) and the current table, tab bar and plot are compared with what the scope's begin left: a call made through
  the [raw bindings](raw-bindings) that opened something and did not close it is reported, and Dear ImGui's error
  recovery closes it.

### The three modes

`app%set_checks(mode [, stat])` chooses what a usage error does. It can be called before `init*`; `destroy` restores
the default.

| | `'abort'` | `'report'` (default) | `'recover'` |
|---|---|---|---|
| A wrong end, a drawing call with no frame open | `error stop` at the call, the message on standard error | refused (it does nothing); the frame goes on | as `'report'`; but an end whose scope is open further down first closes the scopes opened after it, then ends its own |
| A scope still open at `next_frame` | `error stop` at `next_frame` | closed by FIGURE, in reverse order | closed by FIGURE |
| `next_frame(stat)` after a frame with errors | (stopped before) | `FIG_ERR_STATE`; `figure_last_error()` gives every message, one per line; the next frame is open and the loop goes on. Without `stat`: `error stop` with the messages | `FIG_OK`; the messages in `figure_last_error()` and in a [notification](frame-loop#notifications) (one per distinct set of messages, not one per frame) |
| A call with a `stat` of its own (`ig_pop_style_color(stat=s)`, `ig_dock_layout_end(id, stat=s)`, a drawing call with `stat`) | `stat = FIG_ERR_STATE` there | the same | the same |
| Dear ImGui's own checks (raw calls) | its assertions, as before | its error recovery, the message (`Dear ImGui: Missing PopID()`) among the frame's | the same |

`'abort'` gives the earliest stop, at the line of the faulty call: the mode for tests ([Usage checks](frame-loop#usage-checks)).
`'report'` turns the errors into a status, as every other FIGURE failure: the program decides. `'recover'` keeps an
interactive program running through an error in a rarely used panel, the way NASA's Mirage.jl uses Dear ImGui's
error recovery; the panel may draw wrongly until the code is fixed.

<<< @/examples/snippets/cb_scope_error-grid.F90{fortran}

<<< @/examples/snippets/cb_scope_error-wrong.F90{fortran}

<<< @/examples/output/cb_scope_error.txt{text}

The first line is the bug: the table's end found the tree node open. The lines after it follow from it: in mode
`'report'` the wrong `ig_end_table` was refused, so the window's `ig_end` found the tree open too, and the scopes were
still open when the frame ended. The full program is in the [cookbook](/manual/cookbook#find-a-misplaced-end).

### Messages

`<call>` is the procedure that was called; a scope is shown as the program opened it: `ig_tree_node('Blocks')`,
`ig_push_id(7)`, `ig_begin_main_menu_bar()`; an always-paired begin that returned `.false.` is marked `(it returned
false)`.

| Error | Message |
|---|---|
| An end while another scope is the innermost, and its own is open below it | `<call>: the open scope is <scope> (close it with <its end> before <call>)` |
| An end of a kind not open, while another scope is | `<call>: no <begin> is open; the open scope is <scope> (closed by <its end>)` |
| An end with nothing open | `<call>: no <begin> is open (no scope is open)` |
| An end after a begin that returned `.false.` (end only after a true begin) | `<call>: <scope> returned false (end only after a true begin)` |
| A pop with no push of its kind open; more pops than pushes | `<call>: no <push> is open`; `<call>: <n> pops for <m> open <push>` |
| A font or a disabled block left open inside a window | `<call>: <scope> is still open inside <window> (close it with <its end> before <call>)` |
| A scope still open at the end of the frame | `app%next_frame: <scope> is still open (close it with <its end>)` |
| A drawing call with no frame open | `<call>: no frame open` |
| A raw call left a stack open inside a scope | `<call>: Dear ImGui holds <stack> <n> (<m> expected) inside <scope>: a call outside FIGURE (a raw binding) did not close what it opened` |
| ... at the end of the frame | `app%next_frame: Dear ImGui holds <stack> <n> (<m> expected) at the end of the frame: a call outside FIGURE (a raw binding) did not close what it opened` |
| An error Dear ImGui detected itself (`'report'`, `'recover'`) | `Dear ImGui: <its message>` |
| An unknown mode | `app%set_checks: mode is 'abort', 'report' or 'recover', not '<mode>'` (`FIG_ERR_ARGUMENT`) |

A report keeps the first 20 messages of a frame and counts the others (`(and 12 more)`).

### What the checks cost

One record entry per begin and one comparison per end: 50 ns per `ig_push_id`/`ig_pop_id` pair more than the raw
calls (54 ns against 3 ns, gfortran 16 -O2, an Intel i9-13900KF under WSL2, `src/tests/figure_test_errors.F90` prints
both). A widget
pays one test of the frame flag, beside what its wrapper already did (`ig_text`: 30 ns, the raw
`igTextUnformatted`: 13 ns, the difference mostly the copy of the text to a C string). The checks cannot be turned
off.

### What is not checked, and what recovery cannot repair

- **Calls that are not pairs** are not checked against the record: an `ig_table_next_column` outside a table, an
  `ip_line` outside a plot (`ip_annotation` alone refuses it, with `FIG_ERR_STATE`).
- **Raw calls** are caught when they leave something open, and only when a FIGURE end or the frame's end compares the
  stacks, not at the raw call. A raw call that closes what FIGURE opened (a raw `igEnd` for an `ig_begin`) is not
  caught by the record, which compares what is left open; Dear ImGui's own checks see it or not (in mode `'abort'`
  its assertion stops the program, as before).
- **What a refused end leaves.** In `'report'` the widgets after a refused end are drawn in the scope that stayed open
  (inside the tree node, in the example above) until the frame ends: the frame looks wrong, the next one is right
  once the code is.
- **Dear ImGui's error recovery** (what `'recover'` and the raw-call checks rely on) is, in its authors' words, "not
  perfect nor guaranteed" (`imgui.h`, `ConfigErrorRecovery`): it cannot recover from inside a tab item
  (`BeginTabItem`/`EndTabItem`), and state a program changed through raw calls (a cursor position, a clip rectangle)
  is not restored. FIGURE closes its own scopes from the record, ImPlot's plots included, which Dear ImGui's recovery
  does not know; recovery covers only what raw calls left.
- **Usage errors of a frame that never ends** (the program stops between frames, or the loop is left with scopes
  open) are not reported: `destroy` closes what is open without a message.

The pairing rules of each family are on the [Widgets](widgets#windows), [Plots](plots#a-plot), [Menus](menus) and
[Docking](docking) pages.
