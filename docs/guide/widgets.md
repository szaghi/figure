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

Widgets called outside any `ig_begin`/`ig_end` pair go to Dear ImGui's implicit "Debug" window; called with no frame
open (before the first `app%next_frame`, after the loop), they are refused. A broken pairing (an `ig_end` while a
table or a tree node is still open, a window left open at the end of the frame) is reported by the next
`app%next_frame`, naming the calls: [Pairing and frames](errors#pairing-and-frames).

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
| `ig_input(label, value [, step] [, format] [, stat])` | `integer(int32)` or `real(real64)` (`format` and `stat` for reals) | when changed |
| `ig_input_text(label, value [, hint] [, flags])` | `character(len=*)` | when edited |
| `ig_combo(label, current, items)` | `integer(int32)`: index into the `character` array `items` | when an item is picked |

- `ig_button` sizes are in pixels; the default fits the label.
- `ig_slider` is generic: the kind of `value` selects the specific procedure. The user can also ctrl-click it to type
  a value.
- `ig_input` shows `-` and `+` buttons when `step` is given (ctrl-click steps by `10 * step`); `format` is a C
  `printf` format of one real, default `'%.6g'`: `'%.3f'` (as Fortran's `F0.3`), `'%8.2e'` (`ES8.2`),
  `'x = %.4g m'`. It is checked: one conversion `f`, `e`, `g` or `a` (or `F`, `E`, `G`, `A`), with optional flags,
  width and precision, and any `%%`; another (`'%d'`, `'%s'`, `'%f %f'`, `'%lf'`) is refused with
  `FIG_ERR_ARGUMENT`, the field not drawn and the value unchanged (`stat` absent: `error stop`). The full rule:
  [Formats](plots#formats).
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

## What happened to an item

<Media name="cb_commit_on_leave" video alt="Two panels, Cases and Case. In Cases, a click on tail selects it; a double click on fuselage opens it in Case, whose fields show CFL 1.20 and fuselage.grd. The CFL field is clicked and abc typed over it: nothing is checked while typing. A click on the mesh field leaves the CFL field: the message reads CFL: abc is not a positive number, and the field shows 1.20 again. 1.5 is typed and enter pressed: CFL of fuselage set, the field shows 1.50. fuse.dat is typed in the mesh field and tab pressed: the message refuses it and the field shows fuselage.grd again." caption="docs/examples/src/cb_commit_on_leave.F90: a value checked once, when the user leaves the field; a row opened by a double click" />

| Procedure | Notes |
|---|---|
| `ig_last_item()` → `item_status_object` | What happened to the item drawn last, all its states at once: a snapshot. |
| `ig_item_hovered([delay] [, stat])` → `logical` | The pointer is over the item drawn last; with `delay`, only after it has been there `'short'` (0.15 s) or `'normal'` (0.40 s). |
| `ig_any_item_hovered()` → `logical` | The pointer is over some item (a click there goes to a widget, not to the window). |
| `ig_any_item_active()` → `logical` | Some item is active: a text field edited, a slider dragged, a button held. |

(Dear ImGui's `IsItemHovered`, `IsItemActive`, `IsItemFocused`, `IsItemVisible`, `IsItemActivated`, `IsItemEdited`,
`IsItemDeactivated`, `IsItemDeactivatedAfterEdit`, `IsItemToggledOpen`, `IsItemClicked`, `IsMouseDoubleClicked`,
`GetItemRectMin`/`GetItemRectSize`, `IsAnyItemHovered`, `IsAnyItemActive`.)

A widget's return value says one thing (a button was clicked, a field's text changed); `ig_last_item` says the rest:
the user left the field, double-clicked a row, holds the pointer over a button. Its components:

| Component | True |
|---|---|
| `hovered` | while the pointer is over the item, and no other item is held (a slider being dragged keeps the others from being hovered) |
| `active` | while the item is held (a button pressed, a slider dragged) or edited (a text field with the cursor in it) |
| `focused` | while the item has the keyboard focus (the cursor of keyboard navigation) |
| `visible` | while the item is not clipped: inside the visible part of its window or [region](#lists-and-regions) |
| `activated` | on the frame the item becomes active |
| `edited` | on each frame the item changes its value |
| `deactivated` | on the frame the item stops being active |
| `deactivated_after_edit` | on the frame the item stops being active, if its value changed while it was: **the user left the field** (a click elsewhere, tab, enter) |
| `toggled_open` | on the frame a tree node or a header opens or closes |
| `clicked(b)` | on the frame mouse button `b` (1 left, 2 right, 3 middle) goes down over the item |
| `double_clicked(b)` | on the frame of the second press of a double click of button `b` over the item |
| `rect` | `[x, y, w, h]`: top-left corner, width and height, in pixels (the coordinates of `ig_item_rect` and of the mouse) |

<<< @/examples/snippets/cb_commit_on_leave-leave.F90{fortran}

<<< @/examples/snippets/cb_commit_on_leave-commit.F90{fortran}

- **The snapshot rule.** Call `ig_last_item` right after the item: the next item drawn (a text, a tooltip's content,
  any widget) becomes "the last item", and a later call answers about that one. The `item_status_object` the call
  returns is a plain value: it keeps the states of the item it was taken after, whatever is drawn next, so take it
  once and test its components where the program needs them. `ig_item_hovered` has no snapshot: it answers at once,
  about the item drawn last.
- **The one-frame rule.** `activated`, `edited`, `deactivated`, `deactivated_after_edit`, `toggled_open`, `clicked`
  and `double_clicked` are events: true on the one frame the event happens, false on the next. Test them on every
  frame, as a button's result. `hovered`, `active`, `focused` and `visible` are states: true on every frame while
  they hold.
- **Leaving a field.** `deactivated_after_edit` is true once per edit, on the frame the user leaves the field, and
  only when the value changed: a field clicked and left as it was reports `deactivated` without it. It is the place
  to check a value, convert it, or save it: the field's result (and `edited`) are true on every keystroke, when the
  value is still half-typed. Escape ends an edit too, after putting the text back as it was: on that frame the field
  reports `edited` and `deactivated_after_edit` with the old text in the variable, so the check sees the old value.
- **A field the user is editing keeps its text.** While a text field is active, Dear ImGui keeps the text the user is
  typing and writes it into the Fortran variable on every key: an assignment to the variable from the program is
  overwritten on the next frame. Correct the text once the field is left, as the example does on
  `deactivated_after_edit` (the field then shows the program's value).
- **`clicked` is the press**, as Dear ImGui's `IsItemClicked`: a button's own result is the release over it (a press
  dragged off the button is not a click of the button), so `ig_button` and `clicked(1)` can differ by a frame or two.
  `clicked(2)` (the right button) is the usual way to open a [context menu](menus#popups-and-modals) on an item.
- **`ig_item_hovered` with a delay** counts the time on the frames that call it with a delay: call it every frame,
  as a tooltip is declared. The time is shared between items (moving to a neighbour keeps it) and cleared about
  0.25 s after the last such call over an item.

**Which widgets report which states**, measured with FIGURE's widgets (hovered, visible, `rect`, `clicked` and
`double_clicked` are reported by every one):

| Widget | `active`, `activated`, `deactivated`, `focused` | `edited` | `deactivated_after_edit` | `toggled_open` |
|---|---|---|---|---|
| `ig_text`, `ig_text_wrapped`, `ig_text_disabled`, `ig_text_colored` | never: text has no id | no | no | no |
| `ig_button`, `ig_tool_button` | yes | no | no | no |
| `ig_checkbox`, `ig_selectable` | yes | on the click | on the release of the click | no |
| `ig_slider`, `ig_input`, `ig_input_text`, `ig_input_text_multiline`, `ig_color_edit` | yes (`ig_color_edit`: any of its fields) | on each frame the value changes | when left after a change | no |
| `ig_combo` | yes, while pressed | on the pick | no: the combo is left when its list opens, before the pick | no |
| `ig_tree_node`, `ig_collapsing_header` | yes | no | no | on the arrow, or a double click on the label |

A combo's list takes the second click of a double click, so `ig_combo` reports no `double_clicked`. Ending a window
or a region changes the last item (after `ig_end_child` it is the region itself): take the status of an item inside
before the end.

<<< @/examples/snippets/cb_commit_on_leave-double.F90{fortran}

The program checks itself headless (`cb_commit_on_leave --check` clicks and types):

<<< @/examples/output/cb_commit_on_leave.txt{text}

Before frame 17 a single click on tail selected it without opening it; after frame 80 the CFL field was clicked and
left with enter, unchanged: nothing was checked, nothing printed.

**Status:** `ig_item_hovered` with an unknown `delay` returns `.false.` with `FIG_ERR_ARGUMENT` in `stat`:
`ig_item_hovered: unknown delay "later" ('none', 'short' or 'normal')`; `stat` is optional (absent: `error stop` with
the message, [Error handling](errors)). With no frame open, or from a [task](processes#tasks), each procedure is
refused with `FIG_ERR_STATE` (`ig_last_item: no frame open`): `ig_last_item` returns a status with every component
false and `rect` zero, the others `.false.`; without `stat` the error is reported by the next `app%next_frame`
([Pairing and frames](errors#pairing-and-frames)). None of them opens a scope.

- **Window:** the user's mouse and keyboard. **Headless:** the input of [`test_click`, `test_mouse_move`,
  `test_type`](testing#synthetic-input). **Remote:** the browser's mouse and keyboard; a double click is two clicks
  of the browser within Dear ImGui's 0.30 s.
- **Threads:** the frame loop's thread only; a task is refused (`FIG_ERR_STATE`), as every drawing call.
- **What it does not do:** no callbacks: the program asks after each item it cares about. No state of an item drawn
  earlier in the frame (take its snapshot then) or of an item by its label. `ig_item_rect` remains for the corners
  `(xmin, ymin, xmax, ymax)`; `rect` gives the same rectangle as corner and size.

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

## Colour editing

| Procedure | Notes |
|---|---|
| `ig_color_edit(label, rgba [, alpha] [, stat])` → `logical` | A colour editor (`ColorEdit4`) bound to `rgba`, `real(real64)`, components in [0, 1]: one field per component and a swatch that opens a picker when clicked. `.true.` on the frames the user changes the colour. |

<<< @/examples/snippets/cb_legend-color.F90{fortran}

<Media name="cb_legend" video alt="A colour editor above a plot: four fields at 255 and a white swatch. A click on the swatch opens the picker: a saturation-value square, a hue bar and an alpha bar. A click on the hue bar at yellow, then a drag in the square to its top right corner: the fields read 239, 242, 13, 255, the swatch turns yellow, and the contour lines in the plot below turn yellow too. A click outside closes the picker." caption="docs/examples/src/cb_legend.F90: the contour lines' colour chosen with ig_color_edit" />

- `rgba` has 3 components (RGB, no alpha) or 4 (RGBA). With 4, the alpha has a field and a bar in the picker;
  `alpha=.false.` hides them and leaves `rgba(4)` alone.
- The fields show 0-255 and are dragged, or typed after a double-click; right-click on the swatch offers Dear ImGui's
  options (RGB, HSV or hexadecimal fields, copy the colour as text).
- Dear ImGui edits single-precision values: `rgba` is written only on the frames the user changes it, so an untouched
  colour keeps its double-precision bits; a changed one has single precision.
- Statuses: `FIG_ERR_ARGUMENT` for a size other than 3 or 4, `FIG_ERR_STATE` from a [task](processes#tasks); `stat` is
  optional (absent: `error stop` with the message).
- Modes: the same in **window**, **headless** and **remote** mode (the picker is a popup drawn by Dear ImGui).

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
`begin` or when it goes out of scope. `clip%item_height` is the distance between rows [pixels], given to `begin` or
measured on the first row: [Scrolling and focus](#scrolling-and-focus) reaches a row not drawn with it.

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

## Scrolling and focus

<Media name="cb_reveal" video alt="Three windows: a bar of pick buttons standing for a 3-D view, a list of 30 bodies and a list of 2000 blocks. A click on pick block 1240 selects block 1240: on the next frame the Blocks list has scrolled so that block 1240 is highlighted in its middle, and the Bodies list shows body 19 highlighted in its middle. pick block 1873 does the same further down. Go to... opens a dialog whose field already has the text cursor; 333 is typed and enter pressed without a click: the dialog closes and both lists scroll to block 333 and body 5." caption="docs/examples/src/cb_reveal.F90: the lists scroll to a block picked elsewhere; the dialog's field takes the keys at once" />

| Procedure | Notes |
|---|---|
| `ig_scroll_here([ratio] [, axis] [, stat])` | After an item: scroll its window or region so that the item's line is at `ratio` of the visible height (0 top, 0.5 centre, the default, 1 bottom). |
| `ig_scroll_to_pos(pos [, ratio] [, axis] [, stat])` | Scroll so that the point `pos` [pixels] of the content, measured from where its first item starts, is at `ratio` of the visible height: reaches a row that is not drawn. |
| `ig_get_scroll(y, ymax [, x] [, xmax])` | The scroll [pixels]: `y` from 0 (top) to `ymax` (bottom; 0 when nothing scrolls), `x` from 0 to `xmax`. |
| `ig_set_scroll([y] [, x])` | Scroll to `y` and/or `x` [pixels], clamped to [0, the largest scroll]. |
| `ig_focus_here([offset] [, stat])` | Before an item: give it the keyboard focus; a field is then edited as if clicked. `offset` 1 is the item after the next, -1 the item drawn last. |
| `ig_default_focus()` | After an item: the item that has the focus when its window (a modal, a popup) appears. |

(Dear ImGui's `SetScrollHereY`/`SetScrollHereX`, `SetScrollFromPosY`/`SetScrollFromPosX`, `GetScrollY`,
`GetScrollMaxY`, `GetScrollX`, `GetScrollMaxX`, `SetScrollY`/`SetScrollX`, `SetKeyboardFocusHere`,
`SetItemDefaultFocus`.) `axis` is `'y'` (the default) or `'x'`: with `'x'`, ratios are of the visible width and
`pos` is measured from the content's left edge.

Every one acts on the **current window or region**: call it between `ig_begin` and `ig_end`, or inside the
[region](#lists-and-regions) (`ig_begin_child` ... `ig_end_child`) whose content scrolls, not after its end.

**One frame late.** A scroll asked for is applied when its window or region is begun on the next frame, when its
size is known: on the frame of the call nothing moves, `ig_get_scroll` still gives the old values, and an item's
`visible` and `rect` ([What happened to an item](#what-happened-to-an-item)) are the old ones. One frame later the
item is in place. `ig_focus_here` is one frame late too: typed keys go into the field from the next frame. Ask once,
on the frame something happens (a pick, a button, a dialog that opens), not on every frame: a scroll asked on every
frame holds the list still against the user's wheel.

<<< @/examples/snippets/cb_reveal-here.F90{fortran}

**A list clipper** draws only the rows in view (see [Lists and regions](#lists-and-regions)), so the row to reveal
may not be drawn at all, and `ig_scroll_here` has no item to follow. `ig_scroll_to_pos` scrolls to a place of the
content instead: rows of a clipper are `clip%item_height` pixels apart (the height of a row and the spacing below it,
measured by the clipper on its first row; 0 before the first `step`), so row `i` starts at
`(i - 1) * clip%item_height` and its middle is near `(i - 0.5) * clip%item_height`. Call it after the clipper's
loop, inside the region; on the next frame the clipper draws the rows around it.

<<< @/examples/snippets/cb_reveal-clipped.F90{fortran}

**Focus and dialogs.** `ig_focus_here` before a field makes it the field being edited, as a click would, and scrolls
its window to show it: the user types at once. Call it on one frame (a dialog's first frame, or the frame a button
asks for it). `ig_default_focus` after an item marks the item a modal or a popup starts from: on the frame the
window appears it gets the keyboard focus (on other frames the call does nothing, so it may be made on every frame).
It is focused, not activated: enter or space presses a button (Dear ImGui's keyboard navigation, on in FIGURE), and a
field is edited after enter. Put it on the safe choice of a dialog that destroys something ("Keep", not "Delete");
without it, the first item of the window has the focus. A modal ignores the input of the windows behind it, so a
field outside the modal cannot be focused while it is open. Shortcuts follow the focus: a chord with the default
`'focused'` scope fires in the window that has it ([Shortcuts](menus#shortcuts)).

<<< @/examples/snippets/cb_reveal-dialog.F90{fortran}

The program checks itself headless (`cb_reveal --check` picks and types):

<<< @/examples/output/cb_reveal.txt{text}

Frame 9 is the frame of the pick: the selection is set and the scroll asked for, and block 1240 is not drawn; on
frame 10 the clipper draws it in the middle of the list.

**Status:** a `ratio` outside [0, 1] (NaN included), an unknown `axis`, or an `offset` below -1: nothing is done,
`FIG_ERR_ARGUMENT` in `stat`, with the messages `ig_scroll_here: ratio 1.5 is not in [0, 1]`,
`ig_scroll_to_pos: unknown axis "z" ('y' or 'x')`, `ig_focus_here: offset -2 is below -1`; `stat` is optional
(absent: `error stop` with the message, [Error handling](errors)). With no frame open, or from a
[task](processes#tasks), each is refused with `FIG_ERR_STATE` (`ig_scroll_here: no frame open`): `ig_get_scroll`
gives zeros; without `stat` the error is reported by the next `app%next_frame`
([Pairing and frames](errors#pairing-and-frames)). None of them opens a scope.

- **Window:** as described. **Headless:** the same; the focus takes the keys of [`test_type`, `test_key`](testing#synthetic-input).
  **Remote:** the same, the browser's keyboard.
- **Threads:** the frame loop's thread only; a task is refused (`FIG_ERR_STATE`), as every drawing call.
- **What it does not do:** no scroll to an item by its label, or to a row of a clipper by its index (the program
  computes the place); no smooth scrolling (the list jumps); no scroll of a window other than the current one; no
  focus of a window (that is `ig_focus_window`). `ig_scroll_here` follows the last line, not the last item: after
  `ig_same_line`, the line of both. A table with `ImGuiTableFlags_ScrollY` scrolls inside itself: call these between
  `ig_begin_table` and `ig_end_table` to scroll it.

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
returned, while `ig_end_tab`, `ig_end_tab_bar` and `ig_end_table` follow only a begin that returned `.true.`. FIGURE
checks both rules, and the nesting of the scopes, at every end: [Pairing and frames](errors#pairing-and-frames).

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
