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
| `ig_focus_window(name)` → `logical` | Brings window `name` forward and gives it the keyboard; a docked window's tab is shown. While a popup or a modal is open it does nothing and returns `.false.` (focusing another window would close the popup): ask again on a later frame. The window must have been drawn (`ig_begin`) this frame or before. |

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
| `ig_tool_button(label, icon [, width] [, height] [, selected] [, accent])` | none | on the frame it is clicked |
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

`ig_tool_button` is a workspace button of a toolbar, as Fusion 360 draws them: `icon` (an `ICON_*`, see
[Icons](styles#icons)) above the label and larger than it, on a framed, rounded button that shades under the pointer.
With `selected`, the button is framed and tinted in the accent colour and the icon drawn in it: `accent` `[r, g, b]`,
default the style's CheckMark colour. The default size fits the label (at least 4.6 font sizes wide) and the icon above
it; the text before `##` is shown, as for any label. Put the buttons in a bar along a side
([`ig_begin_side_bar`](docking#a-bar-along-a-side)), one per workspace, and keep which one is selected yourself.

```fortran
if (ig_tool_button('Input', ICON_FILE_PEN, selected=tool == 1)) tool = 1
call ig_tooltip('the input files')
if (ig_tool_button('Monitor', ICON_ACTIVITY, selected=tool == 2)) tool = 2
```

## Multi-line text

| Procedure | Notes |
|---|---|
| `ig_input_text_multiline(label, buffer [, width] [, height] [, read_only] [, tab_input] [, flags])` → `logical` | A field of several lines (`InputTextMultiline`) over a `text_buffer_object`; `.true.` on the frame the user edited the text. |
| `buf%set(text [, stat])` | Replaces the text of `buf`; CRLF line ends become LF. |
| `buf%text()` → `character(len=:), allocatable` | A copy of the text (`''` before any `set` or edit). |
| `buf%length()` → `integer(int64)` | The length of the text, in bytes (UTF-8). |

A `text_buffer_object` holds text of any length: a file shown or edited as text, notes, a log kept for reading. The
text is kept by FIGURE's native layer, not in a Fortran variable, and grows while the user types or pastes (through
Dear ImGui's resize callback): there is no capacity to choose, as there is for `ig_input_text`, and nothing is copied
per frame. `buf%text()` copies it out when the program needs it (to save it, to parse it). The object releases its
text when it goes out of scope. Do not copy it with `=`: the copy would share the text, and the first of the two to
end would take it away from the other.

- **Keys.** Enter inserts a newline; ctrl+z undoes and ctrl+y or ctrl+shift+z redo (Dear ImGui's undo history, kept
  across a `set`); ctrl+a selects all; ctrl+c, ctrl+x and ctrl+v copy, cut and paste. On macOS cmd takes ctrl's place.
- **Size.** `width` and `height` in pixels; absent or 0, the item width ([`ig_set_next_item_width`](#tooltips-and-widths))
  and 8 lines; negative, up to that distance from the right or bottom edge of the window or region (`-1.0` fills it).
  The field scrolls when the text is longer or wider than it; `flags=ImGuiInputTextFlags_WordWrap` wraps the lines at
  its width instead.
- **`read_only`:** the text can be selected and copied, not changed. A view of a file or of a tool's output.
- **`tab_input`:** Tab inserts a tab character; without it, Tab moves to the next widget.
- **`flags`** add `ImGuiInputTextFlags_*` with `ior` (`WordWrap`, `NoUndoRedo`).
- **Set while edited.** A `set` while the user edits the field shows the new text at once, the cursor kept where it
  was (or at the end, if the text is shorter).
- **Lines end with LF.** `set` turns CRLF into LF; `text()` returns LF line ends whatever the platform: write it to a
  file in stream access to keep them so. A NUL byte ends the text.
- **The font.** Text in columns (input files, tables of numbers) lines up in a monospace font: `ig_push_font('plex-mono')`
  before the field and `ig_pop_font()` after it ([Fonts](styles#fonts)).

**Status:** `buf%set` fails only for a text of 2 GiB or more (`FIG_ERR_ARGUMENT`, Dear ImGui's limit); `stat` is
optional (absent: `error stop` with the message). `buf%set`, `buf%text()` and `buf%length()` may be called before
`init*` and from a [task](processes#tasks); the field itself, from a task, draws nothing and returns `.false.`
(`FIG_ERR_STATE` for the task).

**Modes:** the same in window, headless and remote modes; copy and paste go through the [clipboard](#clipboard) of
each mode.

<<< @/examples/snippets/cb_text-edit.F90{fortran}

<Media name="cb_text" video alt="An input file shown as text in a monospace font: a click at the end of the iterations line, Enter opens a new line, a cfl entry is typed in the same columns and the status reads (!) modified, then Save writes the file and the status reads saved" caption="docs/examples/src/cb_text.F90" />

What it is not: an editor for code. There are no line numbers, no syntax highlighting, no search and replace; for a
large text Dear ImGui goes through all of it on every frame the field is drawn, so a log that grows without end
belongs in a [log view](processes#the-log-view), which draws only the lines in view.

## Clipboard

| Procedure | Notes |
|---|---|
| `ig_set_clipboard(text [, stat])` | Puts `text` on the clipboard, as a copy in a field does: a value, a table, a finding. |
| `ig_get_clipboard()` → `character(len=:), allocatable` | The clipboard's text, as a paste in a field reads it (`''` when empty). |

The text is UTF-8; trailing blanks are part of it (pass `trim` of a padded variable), and lines end with LF. The
fields' own copy and paste (ctrl+c, ctrl+x, ctrl+v; cmd on macOS) use the same clipboard, so a text set by
`ig_set_clipboard` is what ctrl+v pastes into a field, and what the user copies from a field or a
[log view](processes#the-log-view) is what `ig_get_clipboard` returns.

<<< @/examples/snippets/cb_drop-copy.F90{fortran}

**Modes:**
- **window:** the system's clipboard (SDL's): other programs paste what FIGURE copies, and the reverse.
- **headless:** a clipboard of the program's own, the same on every platform: tests set and read it.
- **remote:** the program keeps its own clipboard on the server, joined to the browser's where the browser allows it.
  A copy (a field's, or `ig_set_clipboard`) is sent to the page, which writes it to the browser's clipboard: browsers
  allow it only in a secure context (an `https` page, or `localhost`, as through an
  [SSH tunnel](remote#a-program-on-a-cluster-node)), and some (Safari) only within a click or a key; when the browser
  refuses, the page's status line says so and the copy stays in the program. A page reads the browser's clipboard
  only in the paste event of ctrl+v (cmd+v): the page sends the text to the program before the key, so a field pastes
  what the user copied elsewhere on their computer, and `ig_get_clipboard` returns it from then on. Nothing else
  reads the browser's clipboard: a "paste" button in the program pastes the program's own clipboard.

**Status:** `ig_set_clipboard` is refused with `FIG_ERR_STATE` before `init*` and from a [task](processes#tasks);
`stat` is optional (absent: `error stop` with the message). `ig_get_clipboard` cannot fail: `''` before `init*` and
from a task.

## Text and layout

| Procedure | Notes |
|---|---|
| `ig_text(text)` | Plain text, no formatting: compose numbers with an internal `write`. Trailing blanks are shown: pass `trim(line)`. |
| `ig_same_line([offset])` | The next item goes on the same line as the previous one; with `offset`, at that distance in pixels from the left edge of the window or region (a column of values). |
| `ig_align_text_to_frame_padding()` | The text that follows on the line is lowered to the text of framed widgets: a label before a field, a line number in a table row of fields. Text after a field on the same line is level already. |
| `ig_text_size(text)` → `real(real64)(2)` | Width and height of `text` in the current font, in pixels; for a label, of the part before `##`. Buttons of one width (the widest label), a column as wide as its longest value. |
| `ig_text_wrapped(text)` | Text wrapped at the right edge of the window or region: help, long messages. |
| `ig_text_disabled(text)` | Text in the style's disabled colour: a default, a hint, something that does not apply. |
| `ig_text_colored(text, color)` | Text in `color`, `[r, g, b]` or `[r, g, b, a]` in [0, 1]. Pair the colour with a mark or a word (`[!!]`), so that the meaning does not rest on colour alone. |
| `ig_separator()` | A horizontal line. |
| `ig_item_rect(xmin, ymin, xmax, ymax)` | Screen rectangle of the last item, in pixels: for tests and custom layout. |
| `ig_show_demo_window([open])` | The Dear ImGui demo, a live catalogue of every Dear ImGui widget (most are not bound yet). |

## Progress bars

| Procedure | Notes |
|---|---|
| `ig_progress_bar(fraction [, label] [, width])` | A bar (`ProgressBar`) filled to `fraction`, in [0, 1] (clamped). |

- `label` is written over the bar (default: the percentage); `width` in pixels (default: the width left, negative:
  up to that distance from the right edge); the height is a field's.
- **Indeterminate:** `fraction` < 0 draws a band sliding along the bar, for work whose length is not known (a tool
  that prints no progress, a task before its first report). FIGURE animates it with the frame clock (Dear ImGui's
  `GetTime`), so it moves only while frames are drawn: request frames while it shows (`app%request_frames`), or show it
  while something else keeps the loop busy (a task's reports wake it).
- The fill is in the style's `PlotHistogram` colour, the bar in `FrameBg`.
- The same in window, headless and remote modes; no failure status.

A status bar with a progress bar, along the bottom of the window ([bar along a side](docking#a-bar-along-a-side)):

<<< @/examples/snippets/cb_status-status.F90{fortran}

<Media name="cb_status" alt="A run in progress: the status bar along the bottom reads running, iteration 213 of 240, beside a progress bar filled to 89 percent; above it, a warning notification: levels is 0, it must be at least 1" caption="docs/examples/src/cb_status.F90" />

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

A list of thousands of rows draws only those in view with a `list_clipper_object`, rows of equal height (lines of
text, selectables, a table's rows of fields): `call clip%begin(n)`, then `do while (clip%step())` draws rows
`clip%first` to `clip%last`. The loop ends by itself (a few steps); left early, the clipper is closed by the next
`begin` or when it goes out of scope.

```fortran
type(list_clipper_object) :: clip

if (ig_begin_child('rows', height=300.0_real64)) then
   call clip%begin(size(names))
   do while (clip%step())
      do i = clip%first, clip%last
         if (ig_selectable(names(i), i == current)) current = i
      enddo
   enddo
endif
call ig_end_child()
```

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

## Trees

| Procedure | Notes |
|---|---|
| `ig_tree_node(label [, default_open] [, selected] [, leaf] [, span_full_width] [, clicked])` → `logical` | A node of a tree (`TreeNodeEx`); `.true.` while open: draw its children, then `ig_tree_pop`. |
| `ig_tree_pop()` | Closes the children of a node: only after `ig_tree_node` returned `.true.`. |
| `ig_set_next_item_open(open [, always])` | Opens or closes the next node from the program: the first time it is shown, or with `always` on this frame whatever its state. |

The pairing rule is the tabs' and the tables': `ig_tree_pop` follows only a node that returned `.true.`. A leaf
(`leaf=.true.`) has no arrow and is always open, so it too is popped: `if (ig_tree_node(name, leaf=.true.)) call
ig_tree_pop()`.

**Choosing is not expanding.** The arrow, or a double-click on the label, opens and closes a node; a single click on
the label sets `clicked` (Dear ImGui's `IsItemClicked` without `IsItemToggledOpen`) and leaves the node as it was. The
program keeps what is chosen, as with `ig_selectable`, and shows it with `selected`. `default_open` opens a node the
first time it is shown; `span_full_width` makes the highlight and the click area as wide as the window, or as the
cell in a table. `ig_set_next_item_open` also opens a collapsing header; an "expand all" button calls it with
`always=.true.` before each node, on the frame of the press.

**Values in columns.** A tree goes in a table's first column: each node and each child is a row
(`ig_table_next_row`), the node's values in the next cells, and the children's rows come between the node and its
pop, so the first column keeps their indentation.

<<< @/examples/snippets/cb_tree-tree.F90{fortran}

**Large trees.** A `list_clipper_object` needs rows of equal height in one run, and an open node in the middle of the
list breaks the run: a tree cannot be clipped as a whole. The children of one node can: a node with thousands of
blocks clips them between the node and its pop. A deep tree with many open nodes is flattened by the program: it keeps
the open state of each node, builds the list of the visible rows (node or child, with its depth) when a node opens or
closes, and clips that list.

<<< @/examples/snippets/cb_tree-large.F90{fortran}

<Media name="cb_tree" alt="A table of grids: the wing open with three blocks; block 2 is chosen by a click on its label and highlighted, the fuselage opened by its arrow shows two more blocks, then the background node opens on a region of 20000 blocks that scrolls" caption="docs/examples/src/cb_tree.F90" />

Trees are drawn the same in window, headless and remote modes; they have no failure status.

## Not bound yet

Colour pickers have no wrapper yet; menus are on their own page,
[Menus and shortcuts](menus). Their raw interfaces are generated
([Raw bindings](raw-bindings)); the Fortran wrappers are still to be written ([roadmap](roadmap)).
