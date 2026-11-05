---
title: Widgets
---

# Widgets

`figure_imgui` binds a first set of [Dear ImGui](https://github.com/ocornut/imgui) widgets (Dear ImGui 1.93.1 WIP, docking branch). Call
them between `next_frame` and the next `next_frame`, inside a window.

## Values are your variables

Widgets that edit a value take it as an `intent(inout)` argument and write the new value back before returning. The
binding copies the value into a local C variable for the call: the actual argument needs no `target` attribute,
nothing keeps a pointer to it after the call, and any variable works (a local, a component of a derived type, an
array element).

Every such widget returns a `logical`: `.true.` in the frame in which the user changed the value. When you only need
the value, discard the result with `continue`:

<<< @/examples/snippets/tut02_widgets-widgets.F90{fortran}

## Windows

| Procedure | Notes |
|---|---|
| `ig_begin(name [, open] [, flags]) → logical` | `name` is the title and the identifier. Returns `.false.` when the window is collapsed or clipped: skip its content. `flags` combine `ImGuiWindowFlags_*` with `ior` (below). |
| `ig_end()` | Call it after every `ig_begin`, whatever `ig_begin` returned. |
| `ig_set_next_window(x, y [, width, height] [, always])` | Position, and size if both `width` and `height` are given, of the next `ig_begin`, in pixels. Applied on first use only (the user can move the window afterwards; with `app%init(..., ini_file=...)` the layout is remembered across runs), or every frame with `always=.true.`. |

Widgets called outside any `ig_begin`/`ig_end` pair go to Dear ImGui's implicit "Debug" window.

**Window flags**, exported by `figure` and combined with `ior`: `ImGuiWindowFlags_NoTitleBar`, `NoResize`, `NoMove`,
`NoScrollbar`, `NoScrollWithMouse`, `NoCollapse`, `AlwaysAutoResize`, `NoBackground`, `NoSavedSettings`,
`NoMouseInputs`, `HorizontalScrollbar`, `NoFocusOnAppearing`, `NoBringToFrontOnFocus`, `AlwaysVerticalScrollbar`,
`AlwaysHorizontalScrollbar`, `NoNav`, `NoDecoration` (no title bar, resize, scrollbars, collapse), `NoInputs`,
`NoDocking`. An overlay, for example:

<<< @/examples/snippets/cb_scoped-overlay.F90{fortran}

With `open`, the window gets a close button in its title bar that sets `open` to `.false.`. Dear ImGui shows a window
as long as `ig_begin` is called for it, so guard the call with the same variable:

<<< @/examples/snippets/tut02_widgets-closable.F90{fortran}

## Controls

| Procedure | Value | Returns `.true.` |
|---|---|---|
| `ig_button(label [, width] [, height])` | none | on the frame it is clicked |
| `ig_checkbox(label, value)` | `logical` | when toggled |
| `ig_slider(label, value, vmin, vmax)` | `integer(int32)`, `real(real32)` or `real(real64)`; `vmin`, `vmax` of the same kind | when changed |
| `ig_input(label, value [, step] [, format])` | `integer(int32)` or `real(real64)` (`format` for reals) | when changed |
| `ig_input_text(label, value [, hint] [, flags])` | `character(len=*)` | when edited |
| `ig_combo(label, current, items)` | `integer(int32)`: index into the `character` array `items` | when an item is picked |

- `ig_button` sizes are in pixels; the default fits the label.
- `ig_slider` is generic: the kind of `value` selects the specific procedure. The user can also ctrl-click it to type
  a value.
- `ig_input` shows `-` and `+` buttons when `step` is given (ctrl-click steps by `10 * step`); `format` is a C
  `printf` format, default `'%.6g'`.
- `ig_input_text` edits a `character` variable in place. **Its length is the field's capacity**: a
  `character(len=64)` holds at most 64 characters, and typing stops there. Trailing blanks are not part of the text
  (Fortran pads with them), so the field starts with `trim(value)`. `hint` is grey text shown while the field is empty
  (it is never the value). `flags` combine `ImGuiInputTextFlags_*` with `ior`: `CharsNoBlank` (names, file paths),
  `CharsDecimal`, `CharsScientific`, `CharsUppercase`, `ReadOnly`, `Password`, `AutoSelectAll`, `EnterReturnsTrue`
  (`.true.` only when enter is pressed).
- `ig_combo` shows `items(current)` and opens the list on a click; `current` outside `1:size(items)` shows nothing
  chosen. Items may repeat a text: they are told apart by their index. Trailing blanks of the items are not shown, so
  an array constructor padded to a common length is fine.

### Tooltips and widths

| Procedure | Notes |
|---|---|
| `ig_tooltip(text)` | On the widget just drawn: `text` shows while the pointer rests on it, after Dear ImGui's tooltip delay. |
| `ig_set_next_item_width(width)` | Width of the next widget's field, in pixels; negative: up to that distance from the window's right edge (`-1.0` fills a table cell). |

## Text and layout

| Procedure | Notes |
|---|---|
| `ig_text(text)` | Plain text, no formatting: compose numbers with an internal `write`. Trailing blanks are shown: pass `trim(line)`. |
| `ig_same_line([offset])` | The next item goes on the same line as the previous one; with `offset`, at that distance in pixels from the left edge of the window or region (a column of values). |
| `ig_text_wrapped(text)` | Text wrapped at the right edge of the window or region: help, long messages. |
| `ig_text_disabled(text)` | Text in the style's disabled colour: a default, a hint, something that does not apply. |
| `ig_text_colored(text, color)` | Text in `color`, `[r, g, b]` or `[r, g, b, a]` in [0, 1]. Pair the colour with a mark or a word (`[!!]`), so that the meaning does not rest on colour alone. |
| `ig_separator()` | A horizontal line. |
| `ig_item_rect(xmin, ymin, xmax, ymax)` | Screen rectangle of the last item, in pixels: for tests and custom layout. |
| `ig_show_demo_window([open])` | The Dear ImGui demo, a live catalogue of every Dear ImGui widget (most are not bound yet). |

## Labels and identifiers

Dear ImGui identifies a widget by a hash of its label within its window. Two widgets with the same label in the same
window are the same widget to Dear ImGui: clicking one activates both, or neither. Make labels unique; when the
visible text must repeat, add `##` and a suffix: the text after `##` is part of the identifier but is not shown.

<<< @/examples/snippets/tut02_widgets-ids.F90{fortran}

A label that starts with `##` is invisible altogether (used by [plots](plots) to hide the title).

Strings are passed verbatim, trailing blanks included: `'Run'` and `'Run   '` are different identifiers.

## Lists and regions

| Procedure | Notes |
|---|---|
| `ig_selectable(label, selected)` → `logical` | A line of a list, highlighted when `selected`; `.true.` on the frame it is clicked. The program keeps the selection: the line does not change `selected`. |
| `ig_begin_child(id [, width] [, height] [, border])` → `logical`, `ig_end_child()` | A region of the window that scrolls on its own. Always paired, like `ig_begin`/`ig_end`. `width` and `height` in pixels: absent or 0 fills what is left, negative leaves that much. |

An input-file editor's layout: a list of sections in a narrow region, the section's values and its help in the region
beside it. Each region scrolls under the wheel on its own; the window does not move.

<<< @/examples/snippets/cb_help-list.F90{fortran}

<Media name="cb_help" alt="A list of three sections on the left; picking one shows its values and its help text on the right" caption="docs/examples/src/cb_help.F90" />

## Groups: headers, tabs, tables

| Procedure | Pairing |
|---|---|
| `ig_collapsing_header(label [, default_open])` | `.true.` while open: draw what it hides inside the `if`. No end call. |
| `ig_begin_tab_bar(id)`, `ig_end_tab_bar()` | End only when the begin returned `.true.`. |
| `ig_begin_tab(label [, open])`, `ig_end_tab()` | `.true.` for the selected tab: draw its content, then end it; end only then. With `open`, a close button. |
| `ig_begin_table(id, columns [, flags] [, height])`, `ig_end_table()` | End only when the begin returned `.true.`. |
| `ig_push_id(id)`, `ig_pop_id()` | Always paired: an id scope, by `character` or `int32`. |
| `ig_begin_disabled([disabled])`, `ig_end_disabled()` | Always paired: the widgets in between are greyed out and ignore input. |

Tabs and tables follow Dear ImGui's rule, which differs from windows: `ig_end` follows every `ig_begin`, whatever it
returned, while `ig_end_tab`, `ig_end_tab_bar` and `ig_end_table` follow only a begin that returned `.true.`.

<<< @/examples/snippets/cb_form-fields.F90{fortran}

A table is filled row by row: `ig_table_next_row`, then `ig_table_next_column` before each cell's widgets (or
`ig_table_set_column(column)`, 1-based). Before the first row, `ig_table_setup_column(label [, width])` declares a
column, fixed `width` in pixels or a share of the width left, and `ig_table_headers_row` draws their labels. The default
`flags` give borders, alternating row colours and resizable columns; `ImGuiTableFlags_*` (`Borders`, `BordersInnerV`,
`RowBg`, `Resizable`, `ScrollY` with `height`, `SizingFixedFit`, `SizingStretchSame`, `None`) replace them.

Widgets repeated on every row repeat their labels: open an id scope per row with `ig_push_id(row)`, so that row 2's
field is not row 1's (see [Labels and identifiers](#labels-and-identifiers)).

<<< @/examples/snippets/cb_form-table.F90{fortran}

<Media name="cb_form" alt="An input-file editor: a field typed over, a scheme picked from a list, a restart option ticked, then a row added to a table of boundary conditions and edited" caption="docs/examples/src/cb_form.F90: the preview on the right follows the variables" />

## Not bound yet

Menus, trees, multi-line text and colour pickers have no wrapper yet. Their raw interfaces are generated
([Raw bindings](raw-bindings)); the Fortran wrappers are still to be written ([roadmap](roadmap)).
