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
| `FIG_ERR_STATE` | 1 | call not allowed in the current state: `init` twice, `next_frame` before `init`, a process started again while it runs ([Processes](processes#statuses)), a drawing procedure called from a task ([Tasks](processes#tasks)), a file dialog or browser whose id is still open ([File dialogs](frame-loop#file-dialogs)), `ip_annotation` outside a plot, a usage error: a wrong end, a scope left open, a drawing call with no frame open ([Pairing and frames](#pairing-and-frames)), an item named by a path that is disabled or not visible, a test not idle after `test_run`'s `max_frames` or a menu level that never appeared ([Finding items by path](testing#finding-items-by-path), [Running until idle](testing#running-until-idle)), `app%open_prefs` a second time ([Preferences](frame-loop#preferences)), `test_capture` with no frame open ([Pictures as tests](testing#pictures-as-tests)) |
| `FIG_ERR_ARGUMENT` | 2 | invalid argument: non-positive window size, a file that is not a font or a fourteenth fallback for [`app%add_fallback_font`](styles#symbols-the-fallback-fonts), `ip_line` arrays of different sizes, a palette below the [contrast rule](styles#the-contrast-rule), a text of 2 GiB or more for a [text buffer](widgets#multi-line-text), an unknown colormap name or a malformed colormap file ([Colormaps](colormaps#statuses-and-modes)), a colour without 4 components or `nlevels` < 1 for the [plot extras and contours](plots#error-bars-annotations-and-drag-tools), a file that is not a PNG or a JPEG, or one that cannot be decoded, for [`fig_read_image` and `tex%load`](images#statuses), a mesh array not contiguous or a connectivity index out of range for a [3-D view](view3d#statuses-and-modes), an unknown key or scope of a [shortcut](menus#status-modes-and-threads), an unknown delay of [`ig_item_hovered`](widgets#what-happened-to-an-item), a ratio outside [0, 1], an unknown axis or an offset below -1 for [scrolling and focus](widgets#scrolling-and-focus), an unknown `where` or a negative width for the [alignment calls](widgets#layout), a `printf` format that is not a format of one real for `ip_setup_axes`, `ip_heatmap`, `ip_colormap_scale` or `ip_colormap_legend`, or not one of the value's family for a number widget ([Formats](plots#formats)), an argument of a number widget Dear ImGui would assert on: a bound NaN or beyond half the range of the kind, a speed not above 0, an unknown scale, a vector of no components ([Numbers and choices](#numbers-and-choices)), a path that names no item (the message names the nearest), several, or is malformed, an item not checkable for `test_item_checked` or taking no text for `test_item_type_text` ([Finding items by path](testing#finding-items-by-path)), a window or a layout added twice or not added, a preference's key that is empty, has a newline or a blank at an end ([Application layer](#application-layer)), a message box without an id or a label, `ig_splitter` without two sizes, size limits below 0 or a maximum below its minimum, `save_image` of an empty rectangle or without a file name, `test_capture` without a file name, `test_compare_image` with a `threshold` outside 0-255, a negative `max_failed`, `masks` without 4 rows or a rectangle whose maximum is below its minimum, or a file that is not a PNG or a JPEG ([Pictures as tests](testing#pictures-as-tests)), a line out of range, an unknown severity, an empty text to find, an unknown language for the [code editor](#code-editor), an unknown corner or mode, a snap not above 0, a matrix whose last row is not (0, 0, 0, 1) for the [gizmos](#gizmos-and-the-gradient-editor), a reversed or qualitative map for the [gradient editor](#gizmos-and-the-gradient-editor), an empty id, a search too long or of two lines, an empty heading or file name for [Markdown](#markdown) |
| `FIG_ERR_FAILED` | 3 | the platform (SDL, OpenGL) reported a failure: no display, no OpenGL 3 context, a program that cannot be started, a font file that cannot be read ([Fonts](styles#fonts)), an image file that cannot be read ([Reading images](images#statuses)), window size limits the system refuses ([Preferences](frame-loop#preferences)), a picture of `test_compare_image` that cannot be read or written ([Pictures as tests](testing#pictures-as-tests)), a Markdown file that cannot be read ([Markdown](#markdown)) |
| `FIG_ERR_EXCEPTION` | 4 | a C++ exception was caught at the C boundary |

The codes are `integer(c_int)` parameters; compare them with `stat` directly (`stat /= FIG_OK`). C++ exceptions never
cross into Fortran: every glue function catches them and returns `FIG_ERR_EXCEPTION` with the exception's message.

## figure_last_error

`figure_last_error()` returns the message of the last failure detected by the native layer, as an allocatable
character. The message is not cleared by a successful call: read it right after the failing call. Each thread has its own
message: a [task](processes#tasks) that fails (`fig_read_image` with a `stat`) reads its own, and leaves the main
thread's alone.

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
| `ig_input`, `ig_drag`, `ig_slider`, `ig_drag_range` of an integer, `format` | `<procedure>: format '<format>' is not a format of an integer: one conversion %d, %i or %u expected, with optional flags, width and precision` |
| the same of a real, and `ig_slider_angle` | as `ig_input`'s above, starting with the procedure's name |
| `ip_setup_axes`, `xformat` / `yformat` | the same, starting `ip_setup_axes: xformat` (or `yformat`) |
| `ip_setup_axis`, `format` | the same, starting `ip_setup_axis: format` |
| `ip_heatmap`, `ip_colormap_scale`, `ip_colormap_legend`, `label_format` | the same, starting `<procedure>: label_format` (`ip_colormap_legend` refuses only a format with a conversion: one without is text) |

### Numbers and choices

The number widgets and the list box ([Numbers](widgets#numbers), [Choices](widgets#choices)) check their arguments
on the Fortran side, before Dear ImGui sees them. A wrong argument is `FIG_ERR_ARGUMENT`: nothing is drawn, the value
is left alone, the call returns `.false.` (absent `stat`, `error stop` with the message). `<p>` is the procedure,
`<half>` half the largest value of the kind (1073741823 for an `int32`; reals are written as `1.70141E+038`).

| Failure | Message |
|---|---|
| a format of the other family, with no conversion or more than one | as in the table above: `<p>: format '<format>' is not a format of an integer: ...` (or `of a real`) |
| a conversion longer than 24 characters | `<p>: format '<format>' has a conversion longer than 24 characters` |
| an unknown `scale` | `<p>: unknown scale '<scale>' ('linear' or 'log')` |
| `scale='log'` for a drag without both bounds | `ig_drag: scale 'log' needs vmin and vmax` |
| a bound NaN | `<p>: vmin is NaN` (`vmax`, `deg_min`, `deg_max`, `radians`, `height`, `lo`, `hi`) |
| a bound beyond half the range of the kind | `<p>: vmax <value> is out of -<half> to <half>` |
| `vmin > vmax` for a drag or a range; `lo > hi` | `<p>: vmin <value> is above vmax <value>`; `ig_drag_range: lo <value> is above hi <value>` |
| a `speed` not above 0, NaN or beyond single precision | `<p>: speed <value> is not above 0 and within single precision` |
| an angle or an end in degrees beyond single precision | `ig_slider_angle: radians <value> is out of ...`; `deg_min <value> is out of ...` |
| a vector of no components | `<p>: value has no components` |

### Tables

The table calls ([Tables](widgets#tables)) check their arguments on the Fortran side and their place in the native
layer. An argument out of range is `FIG_ERR_ARGUMENT` (nothing done; absent `stat`, `error stop`); a call out of its
place is a usage error, `FIG_ERR_STATE` (absent `stat`, reported by the next `app%next_frame` as the
[pairing errors](#pairing-and-frames) are, or stopping at once in mode `'abort'`).

| Failure | Status | Message |
|---|---|---|
| `columns` outside 1 to 511 | `FIG_ERR_ARGUMENT` | `ig_begin_table: columns <n> is out of 1 to 511` |
| `freeze_rows` outside 0 to 127 | `FIG_ERR_ARGUMENT` | `ig_begin_table: freeze_rows <n> is out of 0 to 127` |
| `freeze_cols` outside 0 to `columns` | `FIG_ERR_ARGUMENT` | `ig_begin_table: freeze_cols <n> is out of 0 to the columns` |
| `width` and `stretch` together | `FIG_ERR_ARGUMENT` | `ig_table_setup_column: give width or stretch, not both` |
| a negative or NaN `width` | `FIG_ERR_ARGUMENT` | `ig_table_setup_column: width <w> is negative` (`width NaN is not a width`) |
| `stretch` not above 0, or NaN | `FIG_ERR_ARGUMENT` | `ig_table_setup_column: stretch <w> is not above 0` (`stretch NaN is not a weight`) |
| `rgba` not of 3 or 4 components; one outside [0, 1] or NaN | `FIG_ERR_ARGUMENT` | `ig_table_row_color: rgba has 3 or 4 components`; `rgba components are in [0, 1]`; `rgba has a NaN component` |
| `cell` or `column` outside 1 to the columns | `FIG_ERR_ARGUMENT` | `<call>: column <n> is out of 1 to <columns>` |
| no table open | `FIG_ERR_STATE` | `<call>: no table is open (call it between ig_begin_table and ig_end_table)` |
| `ig_table_sort` in a table not sortable | `FIG_ERR_STATE` | `ig_table_sort: the table is not sortable (ig_begin_table(..., sortable=.true.))` |
| `ig_table_sort` before every column is declared | `FIG_ERR_STATE` | `ig_table_sort: call it after every column is declared (ig_table_setup_column)` |
| `ig_table_column_enabled` in a table not hideable | `FIG_ERR_STATE` | `ig_table_column_enabled: the table is not hideable (ig_begin_table(..., hideable=.true.))` |
| `ig_table_row_color` before the first row | `FIG_ERR_STATE` | `ig_table_row_color: no row is begun (call it after ig_table_next_row)` |

::: warning Changed in v0.4.0
Until v0.3.1 `ig_begin_table` passed any `columns` to Dear ImGui, whose check of a count out of 1 to 511 is an
assertion: the program aborted inside `imgui_tables.cpp`, naming no Fortran call. From v0.4.0
FIGURE refuses it first: `.false.`, `FIG_ERR_ARGUMENT`, and `error stop` when the call has no `stat`.
:::

### Canvas

The canvas and its primitives ([Canvas](canvas)) check their arguments on the Fortran side, before Dear ImGui sees
them: a wrong one is `FIG_ERR_ARGUMENT`, nothing drawn (absent `stat`, `error stop` with the message). `<p>` is the
procedure. The plot layer outside a plot is a usage error, `FIG_ERR_STATE` (absent `stat`, reported by the next
`app%next_frame`, or stopping at once in mode `'abort'`).

| Failure | Status | Message |
|---|---|---|
| an unknown `layer` | `FIG_ERR_ARGUMENT` | `<p>: unknown layer '<layer>' ('window', 'foreground', 'background' or 'plot')` |
| `color` not of 3 or 4 components | `FIG_ERR_ARGUMENT` | `<p>: color has 3 or 4 components` |
| a component of `color` outside [0, 1] or NaN | `FIG_ERR_ARGUMENT` | `<p>: color components are in [0, 1]` |
| `x` and `y` of different sizes | `FIG_ERR_ARGUMENT` | `<p>: x has <n> points, y <m>` |
| too few points (2 for a polyline, 3 for a polygon) | `FIG_ERR_ARGUMENT` | `<p>: <n> points, at least <m> needed` |
| a coordinate NaN, infinite or beyond single precision | `FIG_ERR_ARGUMENT` | `<p>: x must be finite and within single precision` (`y`) |
| `thickness` not above 0, NaN or infinite | `FIG_ERR_ARGUMENT` | `<p>: thickness is not a finite length above 0` |
| `radius` below 0, NaN or infinite | `FIG_ERR_ARGUMENT` | `ig_draw_circle: radius is not a finite length >= 0` |
| a texture not initialized | `FIG_ERR_ARGUMENT` | `ig_draw_image: the texture is not initialized` (`ig_canvas: ...`) |
| a canvas or invisible button size NaN or infinite | `FIG_ERR_ARGUMENT` | `<p>: width and height must be finite and within single precision` |
| `layer='plot'` outside a plot | `FIG_ERR_STATE` | `<p>: layer 'plot' outside a plot (call it between a true ip_begin_plot and ip_end_plot)` |

### Plot axes

The axis calls ([Axes](plots#axes)) check their arguments on the Fortran side and their place against the plot being
declared, before ImPlot sees them (ImPlot's own checks are assertions: the program aborted). A wrong argument is
`FIG_ERR_ARGUMENT`, nothing set up (absent `stat`, `error stop` with the message); a call out of its place is a usage
error, `FIG_ERR_STATE` (absent `stat`, reported by the next `app%next_frame`, or stopping at once in mode `'abort'`).
`<p>` is the procedure.

| Failure | Status | Message |
|---|---|---|
| an unknown axis name | `FIG_ERR_ARGUMENT` | `<p>: unknown axis '<axis>' ('x1', 'x2', 'x3', 'y1', 'y2' or 'y3')` |
| a y axis where an x axis is expected, or the reverse | `FIG_ERR_ARGUMENT` | `<p>: x '<axis>' is not an x axis ('x1', 'x2' or 'x3')` (`y`, `xaxis`, `yaxis`) |
| an unknown scale | `FIG_ERR_ARGUMENT` | `<p>: unknown scale '<scale>' ('linear', 'log', 'symlog' or 'time')` (`xscale`, `yscale`) |
| `'time'` on a y axis | `FIG_ERR_ARGUMENT` | `ip_setup_axis: scale 'time' on axis '<axis>' is refused: ImPlot labels time on x axes only` |
| `xlog` and an `xscale` other than `'log'` | `FIG_ERR_ARGUMENT` | `ip_setup_axes: xlog and xscale '<scale>' disagree (give xscale only: xlog is deprecated)` |
| a limit NaN, or `vmin >= vmax` | `FIG_ERR_ARGUMENT` | `ip_setup_axis_limits: vmin and vmax must not be NaN`; `vmin must be below vmax` |
| tick values not finite; labels not one per value | `FIG_ERR_ARGUMENT` | `ip_setup_axis_ticks: values must be finite`; `labels must be one per value` |
| a constraint NaN; `vmin >= vmax`; `zoom_min > zoom_max`; a negative width | `FIG_ERR_ARGUMENT` | `ip_setup_axis_constraints: vmin is NaN`; `vmin must be below vmax`; `zoom_min must not be above zoom_max`; `a zoom width must not be negative` |
| `vmin <= 0` on a log axis | `FIG_ERR_ARGUMENT` | `ip_setup_axis_constraints: vmin must be above 0 on the log axis '<axis>'` |
| an unknown legend location | `FIG_ERR_ARGUMENT` | `ip_setup_legend: unknown location '<location>' ('n', 'ne', 'e', 'se', 's', 'sw', 'w', 'nw' or 'c')` |
| no plot being declared | `FIG_ERR_STATE` | `<p>: no plot is being declared (call it between a true ip_begin_plot and ip_end_plot)` |
| a setup call after an item, `ip_set_axes` or `ip_plot_limits` | `FIG_ERR_STATE` | `<p>: the setup of the plot is over (call the ip_setup_* procedures before the first item, ip_set_axes and ip_plot_limits)` |
| an axis not set up on this frame | `FIG_ERR_STATE` | `<p>: axis '<axis>' is not set up (call ip_setup_axis('<axis>') first, on every frame)` |
| `test_plot_tick` of an axis not set up | `FIG_ERR_STATE` | `test_plot_tick: axis '<axis>' is not set up (ip_setup_axis('<axis>'))` |

::: warning Changed in v0.4.0
Until v0.3.1 `ip_setup_axes`, `ip_setup_axes_limits` and `ip_plot_limits` outside a plot, or a setup call after an
item, reached ImPlot's assertions: the program aborted inside `implot.cpp`, naming no Fortran call. From v0.4.0 they
are usage errors with the messages above.
:::

### Plot queries and marks

The calls that read a plot ([Reading a plot](plots#reading-a-plot)), its marks ([Marks in a plot](plots#marks-in-a-plot)),
the drag tools and the items of v0.4.0 (`ip_stairs`, `ip_stems`, `ip_inf_lines`, [histograms](plots#histograms))
check their arguments and their place as the axis calls do ([Plot axes](#plot-axes): the axis names, an axis not set
up, no plot being declared give the messages there). `<p>` is the procedure.

| Failure | Status | Message |
|---|---|---|
| no plot being declared (also `ip_drag_line_x`, `ip_drag_line_y`, `ip_drag_point`, from v0.4.0) | `FIG_ERR_STATE` | `<p>: no plot is being declared (call it between a true ip_begin_plot and ip_end_plot)` |
| `ip_tag` on an axis not set up | `FIG_ERR_STATE` | `ip_tag: axis '<axis>' is not set up (call ip_setup_axis('<axis>') first, on every frame)` |
| a NaN coordinate or pixel | `FIG_ERR_ARGUMENT` | `ip_plot_to_pixels: x and y must not be NaN`; `ip_pixels_to_plot: px and py must not be NaN`; `ip_text: x and y must not be NaN`; `ip_tag: the value is NaN`; `ip_drag_rect: an edge is NaN` |
| a colour without 4 components | `FIG_ERR_ARGUMENT` | `<p>: a colour needs 4 components (RGBA)` |
| an offset without 2 components | `FIG_ERR_ARGUMENT` | `ip_text: the offset needs 2 components (x, y)` |
| bins 0, or below `ImPlotBin_Scott` | `FIG_ERR_ARGUMENT` | `ip_histogram: bins must be a count above 0 or an ImPlotBin_* rule` (`xbins`, `ybins`) |
| one end of a histogram's range without the other; a NaN end; `vmin >= vmax` | `FIG_ERR_ARGUMENT` | `ip_histogram: give both vmin and vmax, or neither`; `vmin and vmax must not be NaN`; `vmin must be below vmax` (`xmin`/`xmax`, `ymin`/`ymax`) |
| series of different sizes | `FIG_ERR_ARGUMENT` | `<p>: the series have different sizes` |
| a colormap not registered | `FIG_ERR_ARGUMENT` | `ip_histogram2d: the colormap <id> is not registered (see ip_colormap)` |

### Fields

`ip_field_image`, `ip_colormap_legend` and `ip_colormap_legend_edit` ([Fields](plots#fields)) check their arguments
on the Fortran side; a field outside a plot is a usage error, as the [plot queries](#plot-queries-and-marks). `<p>` is
the procedure.

| Failure | Status | Message |
|---|---|---|
| no plot being declared (`ip_field_image`) | `FIG_ERR_STATE` | `ip_field_image: no plot is being declared (call it between a true ip_begin_plot and ip_end_plot)` |
| an unknown scale (`'time'` included) | `FIG_ERR_ARGUMENT` | `<p>: unknown scale '<scale>' ('linear', 'log' or 'symlog')` |
| `vmin` or `vmax` not finite; equal | `FIG_ERR_ARGUMENT` | `ip_field_image: vmin must be finite` (`vmax`); `vmin and vmax must differ` |
| `vmin` or `vmax` <= 0 on `'log'` | `FIG_ERR_ARGUMENT` | `ip_field_image: a log scale needs vmin above 0` (`vmax`); `<p>: a log scale needs vmin and vmax above 0` (legends) |
| edges not finite, or `x0 == x1`, `y0 == y1` | `FIG_ERR_ARGUMENT` | `ip_field_image: the edges must be finite, x0 /= x1 and y0 /= y1` |
| `nan_color` without 4 components; outside [0, 1] | `FIG_ERR_ARGUMENT` | `ip_field_image: nan_color needs 4 components (RGBA)`; `nan_color components must be in [0, 1]` |
| more than 16 384 values a side | `FIG_ERR_ARGUMENT` | `ip_field_image: a field of at most 16384 values a side (a texture)` |
| a colormap not registered | `FIG_ERR_ARGUMENT` | `<p>: the colormap <id> is not registered (see ip_colormap)` |

The legends' other failures (`levels`, formats, equal ends) are those of
[`ip_colormap_legend`](colormaps#a-colour-scale-legend).

### Players

`ig_player` ([Players](widgets#players)) checks the `player_object` and `labels` on the Fortran side, before it draws:
a wrong one is `FIG_ERR_ARGUMENT`, nothing drawn and `.false.` returned (absent `stat`, `error stop` with the message).
No frame open, or a task, is `FIG_ERR_STATE`, as for every widget.

| Failure | Status | Message |
|---|---|---|
| `count` < 1 | `FIG_ERR_ARGUMENT` | `ig_player: count must be at least 1 (got <count>)` |
| `speed` <= 0, NaN or infinite | `FIG_ERR_ARGUMENT` | `ig_player: speed must be > 0 snapshots per second` |
| an unknown `mode` | `FIG_ERR_ARGUMENT` | `ig_player: unknown mode "<mode>" ('once', 'loop' or 'bounce')` |
| `labels` not of `count` entries | `FIG_ERR_ARGUMENT` | `ig_player: labels has <n> entries, not count` |

An `index` outside 1 to `count` is not an error: the player moves it to the nearest end and returns `.true.`.

### Application layer

The window registry, the layouts, the preferences, the message boxes, the splitter and the size limits check their
arguments in the native layer; each section has its table of messages: [Windows and
layouts](docking#windows-and-layouts), [Preferences](frame-loop#preferences), [Message boxes](menus#message-boxes),
[Splitters](widgets#splitters). In short:

| Failure | Status | Message |
|---|---|---|
| a window or a layout added twice, or with an empty name | `FIG_ERR_ARGUMENT` | `app%add_window: '<name>' is added already`, `app%add_layout: the name is empty` |
| a window or a layout not added | `FIG_ERR_ARGUMENT` | `app%window_visible: no window '<name>' was added`, `app%switch_layout: no layout '<name>' was added` |
| a preferences' name that is not a folder's | `FIG_ERR_ARGUMENT` | `app%open_prefs: the name '<name>' is a folder's name: letters, digits, blanks and . _ - (not first a .)` |
| `open_prefs` a second time | `FIG_ERR_STATE` | `app%open_prefs: the preferences are open already (<file>)` |
| a malformed key | `FIG_ERR_ARGUMENT` | `app%save_pref: the key '<key>' is empty, has a newline, a blank at an end, or starts with [ # ;` |
| a message box without an id, or with every label empty | `FIG_ERR_ARGUMENT` | `app%message_box: the id is empty`, `app%message_box: every button label is empty` |
| `ig_splitter` without two sizes | `FIG_ERR_ARGUMENT` | `ig_splitter: sizes has two values, the panes on either side` |
| size limits below 0, a maximum below its minimum | `FIG_ERR_ARGUMENT` | `app%set_size_limits: a negative size`, `app%set_size_limits: a maximum below its minimum` |
| before `init*` | `FIG_ERR_STATE` | `<procedure>: figure is not initialized` |

A preference that is not of the kind asked is not an error: `load_pref` returns `.false.` and gives the default. A
save of the file that fails is printed once on standard error; the program goes on.

### Code editor

The [code editor](editor) and the diff check their arguments in the native layer, `language_object%init` and
`code_language` on the Fortran side:

| Failure | Status | Message |
|---|---|---|
| an editor procedure before `init` | `FIG_ERR_STATE` | `code_editor_object%<procedure>: the editor is not initialized` |
| `insert` or `replace` in a read-only editor | `FIG_ERR_STATE` | `code_editor_object%insert: the editor is read-only` |
| `draw` with an empty id, `code_diff` with one | `FIG_ERR_ARGUMENT` | `code_editor_object%draw: the id is empty`, `code_diff: the id is empty` |
| a line past the last for `mark`, below 1 for any | `FIG_ERR_ARGUMENT` | `code_editor_object%mark: line <n> is past the last, <count>`, `code_editor_object%goto: lines and columns are numbered from 1` |
| an unknown severity | `FIG_ERR_ARGUMENT` | `code_editor_object%mark: severity must be 'error', 'warning' or 'info'` |
| an empty text to find or replace | `FIG_ERR_ARGUMENT` | `code_editor_object%find: the text is empty` |
| a tab size outside [1, 16] | `FIG_ERR_ARGUMENT` | `code_editor_object%set_options: tab_size must be in [1, 16]` |
| an unknown language name | `FIG_ERR_ARGUMENT` | `code_language: unknown language "<name>"` |
| an empty language name, a keyword or type with a blank, a longer preprocessor | `FIG_ERR_ARGUMENT` | `language_object%init: the name is empty`, `language_object%init: a keyword is empty or holds a blank`, `language_object%init: the preprocessor is one character` |

The queries (`text`, `line_count`, `mark_of`, `cursor`, `selection`, `word_at_cursor`, `completing`, `is_read_only`,
`line_rect`) fail on nothing: before `init` they return their empty value. A task calling an editor procedure is
refused as any drawing procedure is.

### Markdown

[Markdown](widgets#markdown) (`ig_markdown`, `markdown_view_object`) checks its arguments in the native layer:

| Failure | Status | Message |
|---|---|---|
| `ig_markdown` or `md%draw` with no frame open | `FIG_ERR_STATE` | `ig_markdown: no frame open`, `markdown_view_object%draw: no frame open` |
| a document procedure before `md%init` | `FIG_ERR_STATE` | `markdown_view_object%<procedure>: the view is not initialized` |
| `md%draw` with an empty id | `FIG_ERR_ARGUMENT` | `markdown_view_object%draw: the id is empty` |
| `md%find` with a text over 255 bytes, or of more than one line | `FIG_ERR_ARGUMENT` | `markdown_view_object%find: the text is longer than 255 bytes`, `markdown_view_object%find: the text is more than one line` |
| `md%scroll_to` with an empty heading | `FIG_ERR_ARGUMENT` | `markdown_view_object%scroll_to: the heading is empty` |
| `md%load` with an empty name | `FIG_ERR_ARGUMENT` | `markdown_view_object%load: no file name` |
| `md%load` of a file that cannot be read (the text kept) | `FIG_ERR_FAILED` | `markdown_view_object%load: '<path>' cannot be read: <SDL's reason>` |
| the bundled fonts not loaded into the atlas | `FIG_ERR_FAILED` | `markdown: cannot load the font <name>` (or `cannot merge ...`) |

The queries (`md%text`, `md%matches`, `md%current_match`) fail on nothing: before `init` they return their empty
value. A task calling a Markdown procedure is refused as any drawing procedure is. A heading `md%scroll_to` names
that the text lacks is not an error: nothing happens.

### Gizmos and the gradient editor

The [view cube and the gizmos](view3d#gizmos) and the [gradient editor](colormaps#editing-a-colormap) check their
arguments on the Fortran side (names) and in the native layer (values):

| Failure | Status | Message |
|---|---|---|
| `view_cube` or `gizmo` before `draw` in this frame and window | `FIG_ERR_STATE` | `view3d_object%view_cube: draw the view first, in this frame and in this window` |
| a cube's size not above 0, an unknown corner | `FIG_ERR_ARGUMENT` | `view3d_object%view_cube: the size must be positive`, `view3d_object%view_cube: corner must be 'top-right', 'top-left', 'bottom-right' or 'bottom-left', got '<corner>'` |
| an unknown mode or space | `FIG_ERR_ARGUMENT` | `view3d_object%gizmo: mode must be 'translate', 'rotate' or 'scale', got '<mode>'`, `view3d_object%gizmo: space must be 'world' or 'local', got '<space>'` |
| a snap not above 0 | `FIG_ERR_ARGUMENT` | `view3d_object%gizmo: snap must be positive` |
| a matrix not finite, or whose last row is not (0, 0, 0, 1) | `FIG_ERR_ARGUMENT` | `view3d_object%gizmo: the matrix is not finite`, `view3d_object%gizmo: the matrix's last row must be (0, 0, 0, 1)` |
| an unknown map (a discrete name, `<name>\|<levels>`, included) | `FIG_ERR_ARGUMENT` | `ig_gradient_edit: unknown colormap '<name>' (ip_colormap_names lists them)` |
| a reversed map | `FIG_ERR_ARGUMENT` | `ig_gradient_edit: '<name>_r' is a reversed map: edit '<name>'` |
| a qualitative map | `FIG_ERR_ARGUMENT` | `ig_gradient_edit: 'Deep' is qualitative (a list of colours, not a scale): it has no gradient` |

`ip_colormap_stops` refuses the same maps, its messages starting `ip_colormap_stops:`. On a failure a gizmo leaves its
matrix and the camera as they were and returns `.false.`; `view_matrix` and `projection_matrix` fail only on a view
not initialized (`FIG_ERR_STATE`), their matrix then zero.

### ImPlot3D

The [3-D plots](plots#_3-d-plots) check their arguments on the Fortran side, before ImPlot3D sees them (ImPlot3D
asserts on an item outside a plot and on a setup after the first item):

| Failure | Status | Message |
|---|---|---|
| an item, a text or `ip3_setup_axes` outside a 3-D plot | `FIG_ERR_STATE` | `ip3_line: no 3-D plot is being declared (call it between ip3_begin_plot and ip3_end_plot)`, `ip3_setup_axes: no 3-D plot is being declared (call it after ip3_begin_plot returned true)` |
| `ip3_setup_axes` after an item | `FIG_ERR_STATE` | `ip3_setup_axes: the setup of the 3-D plot is over (call it before the first item)` |
| series of different sizes, more points than a C `int` counts | `FIG_ERR_ARGUMENT` | `ip3_line: the series have different sizes`, `ip3_line: more points than a C int can count` (and the same for `ip3_scatter`, `ip3_mesh`) |
| `x`, `y` that do not match `z` | `FIG_ERR_ARGUMENT` | `ip3_surface: x and y must match z: size(x) = size(z, 1), size(y) = size(z, 2) (or x and y of the shape of z)`, `ip3_surface: x, y and z of a grid must have the same shape` |
| one scale end, a minimum not below the maximum | `FIG_ERR_ARGUMENT` | `ip3_surface: give both scale_min and scale_max, or neither`, `ip3_surface: scale_min must be below scale_max` |
| a colormap not registered | `FIG_ERR_ARGUMENT` | `ip3_surface: the colormap <id> is not registered (see ip_colormap)` |
| triangles without 3 rows, a vertex outside `[1, size(x)]` | `FIG_ERR_ARGUMENT` | `ip3_mesh: triangles needs 3 rows (the vertices of each triangle)`, `ip3_mesh: a triangle has a vertex outside [1, size(x)]` |
| `limits` without 6 values, or a minimum not below its maximum; one angle | `FIG_ERR_ARGUMENT` | `ip3_setup_axes: limits needs 6 values (xmin, xmax, ymin, ymax, zmin, zmax)`, `ip3_setup_axes: each minimum of limits must be below its maximum`, `ip3_setup_axes: give both elevation and azimuth, or neither` |
| a NaN position, an offset without 2 values | `FIG_ERR_ARGUMENT` | `ip3_text: x, y and z must not be NaN`, `ip3_text: the offset needs 2 components (x, y)` |
| a colour without 4 values | `FIG_ERR_ARGUMENT` | `ip3_spec: a colour needs 4 components (RGBA)` |

A refused item draws nothing; the plot goes on. An `ip3_end_plot` without a true `ip3_begin_plot` is a pairing error
([below](#pairing-and-frames)).

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
| **Always paired:** the end follows every begin, whatever it returned | `ig_begin`, `ig_begin_side_bar` / `ig_end`; `ig_begin_child` / `ig_end_child`; `ig_push_id` / `ig_pop_id`; `ig_begin_disabled` / `ig_end_disabled`; `ig_push_font` / `ig_pop_font`; `ig_push_style_color`, `ip_push_style_color` / `ig_pop_style_color`, `ip_pop_style_color`; `ig_push_style_var`, `ip_push_style_var` / `ig_pop_style_var`, `ip_pop_style_var`; `ig_begin_group` / `ig_end_group`; `ig_align_begin` / `ig_align_end`; `ig_push_item_width` / `ig_pop_item_width` |
| **End only after a true begin** | `ig_begin_tab_bar` / `ig_end_tab_bar`; `ig_begin_tab` / `ig_end_tab`; `ig_begin_table` / `ig_end_table`; `ig_tree_node` / `ig_tree_pop`; `ig_begin_main_menu_bar` / `ig_end_main_menu_bar`; `ig_begin_menu_bar` / `ig_end_menu_bar`; `ig_begin_menu` / `ig_end_menu`; `ig_begin_popup`, `ig_begin_popup_context`, `ig_begin_popup_modal` / `ig_end_popup`; `ig_begin_tooltip`, `ig_begin_item_tooltip` / `ig_end_tooltip`; `ip_begin_plot` / `ip_end_plot`; `ip_begin_subplots` / `ip_end_subplots`; `ip3_begin_plot` / `ip3_end_plot`; `ig_dock_layout_begin` / `ig_dock_layout_end` |

- **Scopes nest.** Windows, child regions, tab bars, tabs, tables, tree nodes, menu bars, menus, popups (context
  menus included), tooltips, plots, subplot figures, 3-D plots, dock layouts, id scopes, groups, aligned groups and pushed item
  widths are closed innermost first:
  an end that is not the end of the innermost open one is wrong.
- **Pushes do not nest.** A style colour, a style variable, a font and a disabled block are undone by the newest push
  of their own kind, wherever it was made (a colour pushed before `ig_begin` and popped right after it is right, as
  in Dear ImGui). A font or a disabled block opened inside a window (a window, a child region, a popup, a menu, a
  tooltip, the main menu bar) is closed before that window's end, as Dear ImGui's `End` requires.
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
