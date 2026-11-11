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
| `ig_slider(label, value, vmin, vmax [, format] [, scale] [, clamp] [, stat])` | `int32`, `int64`, `real32` or `real64`, scalar or vector ([Numbers](#numbers)) | when changed |
| `ig_input(label, value [, step] [, format] [, enter_returns] [, read_only] [, stat])` | `int32`, `int64`, `real32` or `real64`, scalar or vector ([Numbers](#numbers)) | when changed |
| `ig_input_text(label, value [, hint] [, flags])` | `character(len=*)` | when edited |
| `ig_combo(label, current, items)` | `integer(int32)`: index into the `character` array `items` | when an item is picked |

- `ig_button` sizes are in pixels; the default fits the label.
- `ig_slider` and `ig_input`, with the drag boxes, angles, ranges and vectors, are in [Numbers](#numbers); radio
  buttons and list boxes, the other ways to choose, in [Choices](#choices).
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
| `ig_tooltip(text)` | On the widget just drawn: `text` shows while the pointer rests on it, after Dear ImGui's tooltip delay. A tooltip with more than one line of text: [Tooltips](#tooltips). |
| `ig_set_next_item_width(width)` | Width of the next widget's field, in pixels; negative: up to that distance from the window's right edge (`-1.0` fills a table cell). |

`ig_tool_button` is a workspace button of a toolbar, as Fusion 360 draws them: `icon` (an `ICON_*`, see
[Icons](styles#icons)) above the label and larger than it, on a framed, rounded button that shades under the pointer.
With `selected`, the button is framed and tinted in the accent colour and the icon drawn in it: `accent` `[r, g, b]`,
default the style's CheckMark colour. The default size fits the label (at least 4.6 font sizes wide) and the icon above
it; the text before `##` is shown, as for any label. Put the buttons in a bar along a side
([`ig_begin_side_bar`](docking#a-bar-along-a-side)), one per workspace, and keep which one is selected yourself.

<<< @/examples/snippets/cb_controls-tools.F90{fortran}

`docs/examples/src/cb_controls.F90` is a headless program: it clicks the Monitor button and edits a field as a user
does ([Headless testing](testing#synthetic-input)), and the documentation's build runs it:

<<< @/examples/output/cb_controls.txt{text}

## Numbers

<Media name="numbers_and_choices" alt="Two windows. Numbers: fields for an int32 with - and + buttons, an int64 shown as 6000000000 cells, a real32 as 1.500e-04 and a vector of three reals; drag boxes for a real, a gravity vector shown as 0.00 m/s², 0.00 m/s², -9.81 m/s² and two integers; a linear slider, a CFL slider on a log scale at 0.1, an angle slider at 45 deg, and a range of two drag boxes 0.20 and 0.70; each with its call in grey beside it. Choices: three radio buttons WENO5, WENO7 (chosen), TVD; a combo showing superbee; a list box of blocks with block 3 highlighted, seven rows in view" caption="docs/examples/src/gallery.F90, run with numbers_and_choices" />

| Procedure | Notes |
|---|---|
| `ig_input(label, value [, step] [, format] [, enter_returns] [, read_only] [, stat])` → `logical` | A field, typed (`InputScalar`, `InputScalarN`); `step` adds `-` and `+` buttons. |
| `ig_drag(label, value [, speed] [, vmin] [, vmax] [, format] [, scale] [, clamp] [, stat])` → `logical` | A drag box: dragged sideways, or typed after a double click (`DragScalar`, `DragScalarN`). |
| `ig_slider(label, value, vmin, vmax [, format] [, scale] [, clamp] [, stat])` → `logical` | A slider from `vmin` to `vmax`; ctrl-click types a value (`SliderScalar`, `SliderScalarN`). |
| `ig_slider_angle(label, radians [, deg_min] [, deg_max] [, format] [, stat])` → `logical` | An angle kept in radians, shown and set in degrees (`SliderAngle`). |
| `ig_drag_range(label, lo, hi [, speed] [, vmin] [, vmax] [, format] [, stat])` → `logical` | Two drag boxes for the ends of a range, `lo <= hi` kept (`DragFloatRange2`, `DragIntRange2`, for every kind). |

Each returns `.true.` on the frame the user changed the value, and writes the value back in place
([Values are your variables](#values-are-your-variables)).

**Kinds.** `value` is `integer(int32)`, `integer(int64)`, `real(real32)` or `real(real64)`: the kind selects the
specific procedure, and Dear ImGui edits the value in that kind (no conversion through another one: an `int64` holds
6000000000, a `real64` keeps its 15 digits). `step`, `vmin`, `vmax`, `lo` and `hi` have the kind of `value`
(`vmin=0.0_real32` for a `real32`); `speed` is `real(real64)` for every kind. `ig_slider_angle` takes `real32` or
`real64`, its ends of the same kind.

**Vectors.** A `value` of rank 1 is one widget of `size(value)` boxes side by side, sharing the item width
([Tooltips and widths](#tooltips-and-widths)) and one label: a direction, a point, the cells of a grid. The bounds
and the step are the same for every component; the call is `.true.` when any component changed, and a component
typed into changes only itself. A vector of no components is refused.

<<< @/examples/snippets/cb_vector-vector.F90{fortran}

<Media name="cb_vector" video alt="A window Case with three widgets. The pointer drags the third box of gravity, -9.81 m/s², to the left: it goes down to -10.81 m/s² and the norm |g| below follows; the pointer drags the first box to the right, 0.00 to 1.50; it clicks the second field of probe, types 0.25 and presses enter; it drags the wind slider from 45 deg to 120 deg" caption="docs/examples/src/cb_vector.F90: a vector parameter with units" />

**Formats.** `format` is a C `printf` format of one value of the kind's family, checked before Dear ImGui sees it:
for a real, one conversion `f`, `e`, `g` or `a` (or `F`, `E`, `G`, `A`); for an integer, one conversion `d`, `i` or
`u`; flags, width and precision as digits, and any other text around it, which is printed as it is: `'%.2f m/s²'`
shows a unit in every box. An `int64` takes the formats of an `int32` (`'%d'`): FIGURE adds the length modifier C needs
(`'%lld'`), and refuses one written by the program (length modifiers are refused for every kind). A format of the
other family (`'%f'` for an integer, `'%d'` for a real), with no conversion, with more than one, or with a conversion
longer than 24 characters is refused with `FIG_ERR_ARGUMENT`: nothing is drawn and the value is left alone. The full
rule: [Formats](plots#formats).

| Format | Shows 42, 1234.5678 | Resembles Fortran's |
|---|---|---|
| `'%d'` | `42` | `I0` |
| `'%5d'`, `'%05d'` | `   42`, `00042` | `I5`, `I5.5` |
| `'%+d'` | `+42` | `SP, I0` |
| `'%d cells'` | `42 cells` | `I0, ' cells'` |
| `'%.3f'` | `1234.568` | `F0.3` |
| `'%10.3f'` | `  1234.568` | `F10.3` |
| `'%.2e'` | `1.23e+03` | `ES9.2` (C writes the exponent with a lower-case `e` and at least two digits) |
| `'%.4g'` | `1235` | `G0.4`, roughly (C drops trailing zeros) |
| `'%.0f%%'` | `1235%` | `F0.0, '%'` |

Default formats: `ig_input` `'%d'` for integers and `'%.6g'` for reals; the drags and sliders Dear ImGui's, `'%d'`
for integers, `'%.3f'` for `real32` and `'%f'` (6 decimals) for `real64`. **Drags and sliders round a real to the
precision the format shows** (`'%.2f'`: to hundredths): the value set is the value shown. A field does not round what
is typed into it.

**Speed, bounds, scale, clamp.** A drag changes `value` by `speed` per pixel [value units / pixel] (default 1: pass the
step the value needs, `speed=0.01` for a value of order 1); shift multiplies it by 10, alt divides it by 100. `vmin`
and `vmax` stop a drag (`vmin <= vmax`); without them a drag runs to half the range of the kind. A slider goes from
`vmin` at its left end to `vmax` at its right one; `vmin > vmax` reverses it. `scale='log'` spaces the values
logarithmically: equal distances multiply the value by equal factors, and the middle of a slider from `1e-3` to `10`
is `0.1`, the geometric mean of its ends (a CFL number, a tolerance); a drag needs `vmin` and `vmax` for it. Ends of
opposite signs go through a small band around zero, whose width follows the format's precision (Dear ImGui's
logarithmic zero). A drag or a slider stops at its ends, but a value typed into it (a double click on a drag box, a
ctrl-click on a slider) is kept as typed unless `clamp=.true.` (Dear ImGui's `ImGuiSliderFlags_AlwaysClamp`). The
ends of a slider are within half the range of the kind (Dear ImGui's limit: ±1073741823 for an `int32`).

**Fields.** `step` (> 0) adds `-` and `+` buttons; ctrl with a button steps by `10 * step`. A typed value is applied
when the field is left (enter, tab, a click elsewhere), and the call is `.true.` on that frame or when a button is
pressed. With `enter_returns=.true.` it is `.true.` only on the frame enter is pressed; a field left otherwise still
changes its value, so read the value, or take `ig_last_item()`'s `deactivated_after_edit` to act on it
([What happened to an item](#what-happened-to-an-item)). `read_only=.true.` shows the value, which the user can
select and copy, not edit; the buttons are disabled.

**Angles.** `ig_slider_angle` keeps the angle in radians in the program and shows it in degrees, `'%.0f deg'` by
default (`format` is a format of the degrees); `deg_min` and `deg_max` are in degrees, default -360 and 360. Dear
ImGui edits it in single precision: a `real64` angle is written only on the frames the user changes it, so an angle
the user does not touch keeps all its digits.

**Ranges.** `ig_drag_range` draws two drag boxes, `lo` and `hi`, then the label: `lo` stays between `vmin` and `hi`,
`hi` between `lo` and `vmax`, values typed into the boxes too. Given with `lo > hi`, it is refused.

- **Pairing and frame rules:** none opens a scope; call them in a window, between `next_frame` and the next one.
  `ig_last_item()` after one describes it (a vector or a range: the whole group of boxes).
- **Status:** the `stat` of each call is optional. A wrong argument gives `FIG_ERR_ARGUMENT`, nothing drawn, the value
  untouched (absent `stat`: `error stop` with the message): a format refused as above, an unknown `scale`, a `'log'`
  drag without both bounds, a bound NaN or beyond half the range of the kind, `vmin > vmax` for a drag, `lo > hi`, a
  speed not above 0 or beyond single precision, an angle or an end in degrees beyond single precision, a vector of no
  components. The messages are in [Error handling](errors#numbers-and-choices). With no frame open, or from a
  [task](processes#tasks), each call is refused with `FIG_ERR_STATE`, as every drawing call.
- **Window, headless, remote:** the same; headless, `test_drag` drags a box or a slider, `test_click` and `test_type`
  type into a field ([Testing](testing#synthetic-input)).
- **Threads:** the frame loop's thread only; a task is refused (`FIG_ERR_STATE`).
- **What they do not do:** no bounds per component (one `vmin` and `vmax` for the whole vector); no unit conversion
  (the format shows a unit; the value is in the unit the program keeps); no unsigned or 8- and 16-bit integers, no
  vertical sliders, no wrap-around drags, no colour markers on the components (raw `igDragScalar`, `igVSliderScalar`
  with the `ImGuiDataType_*` and `ImGuiSliderFlags_*` constants, [Raw bindings](raw-bindings)); `ig_input` does not
  round what is typed; `ig_slider_angle` is single precision while it is dragged.

::: warning Changed in v0.4.0
`ig_input` and `ig_slider` were `int32` and `real64` fields and `int32`, `real32` and `real64` sliders with no format;
the old calls compile and behave as before. New: every kind, vectors, `format` (checked) and `stat` for every kind,
`scale` and `clamp`. A slider whose ends are beyond half the range of the kind was passed to Dear ImGui, whose check is
an assertion: the program aborted inside `imgui_widgets.cpp`. From v0.4.0 it is refused first, `FIG_ERR_ARGUMENT`. The
procedures moved from `figure_imgui` to `figure_numbers`: a program that names `figure_imgui` in a `use` for them
takes them from `figure` instead.
:::

## Choices

| Procedure | Notes |
|---|---|
| `ig_radio(label, current, value [, stat])` → `logical` | One option of a group sharing `current`: drawn chosen when `current == value`; a click sets `current = value` (`RadioButton`). |
| `ig_combo(label, current, items)` → `logical` | The chosen item of `items`, in a list that opens on a click ([Controls](#controls)). |
| `ig_list_box(label, current, items [, height] [, stat])` → `logical` | `items` in a box that stays open and scrolls; `current` the index chosen (`BeginListBox`, `ListBox`). |

**Radio buttons, a combo or a list box.** Radio buttons show every option at once and take one click: a few options
(two to five), each worth seeing, as the reconstruction scheme of a solver. A combo takes one line whatever the number
of options, and two clicks: many options, or a form short of space, as a limiter among seven. A list box keeps several
options in view and scrolls through the rest: a long list the user picks from again and again, as the blocks of a
grid or the cases of a study.

<<< @/examples/snippets/cb_scheme-radio.F90{fortran}

<Media name="cb_scheme" video alt="A window Numerics: under scheme, the radio buttons WENO5 (chosen), WENO7 and TVD; under applied to, a list box of 64 blocks. The pointer clicks TVD: TVD is chosen and a limiter combo appears; it opens the combo and picks superbee; it scrolls the list box with the wheel and clicks block 17, which is highlighted; the line below reads TVD on block 17" caption="docs/examples/src/cb_scheme.F90: choose a scheme" />

**Radio buttons.** One call per option, all with the same `current` and each with its own `value`; `ig_same_line`
puts them on one row. A click sets `current = value` and returns `.true.` on that frame, also when the option was
chosen already (as Dear ImGui's `RadioButton`); the click is reported as an edit by `ig_last_item`. `current` equal to
no `value` shows none chosen.

**List boxes.** `current` is the index of the chosen item, 1 to `size(items)`; any other value shows none chosen. A
pick sets it and returns `.true.` on that frame, reported as an edit by `ig_last_item`. `height` [pixels] sets the
box's height; 0 (default) fits up to 7 items (a list of 3 items gets 3 rows and a quarter); a negative height fills
the window's height left but `-height` pixels. Only the rows in view are drawn, so a list of thousands costs what the
rows on screen cost; the chosen item is always submitted, so that keyboard navigation starts from it. Trailing blanks
of the items are not shown, and items may repeat a text (they are told apart by their index), as in `ig_combo`.

<<< @/examples/snippets/cb_scheme-list.F90{fortran}

The program checks itself headless (a click on TVD, the wheel over the list, a click on its top row):

<<< @/examples/output/cb_scheme.txt{text}

- **Pairing and frame rules:** none opens a scope (the list box's begin and end are inside `ig_list_box`).
- **Status:** `stat` is optional. `ig_list_box` with a NaN `height`, or one beyond single precision, gives
  `FIG_ERR_ARGUMENT` (absent `stat`: `error stop`); `ig_radio` cannot fail. With no frame open, or from a task, each is
  refused with `FIG_ERR_STATE`.
- **Window, headless, remote:** the same; headless, `test_click` clicks an option and `test_wheel` scrolls a list box.
- **Threads:** the frame loop's thread only; a task is refused (`FIG_ERR_STATE`).
- **What they do not do:** one choice only (no multiple selection: a list of `ig_selectable`, [Lists and
  regions](#lists-and-regions)); no filter or search over the items; one line per item. Pass `items` as a whole array
  or as a section of a fixed-length one: a section of a deferred-length array arrives wrong with gfortran and
  nvfortran ([Known issues](known-issues#gfortran-a-section-of-a-deferred-length-character-array)).

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

## Tooltips

<Media name="cb_context_menu_tooltip" alt="A list of patches; the pointer rests on the row wall, and a tooltip beside it holds a table of two columns: patch wall, condition no-slip, value 0.0" caption="docs/examples/src/cb_context_menu.F90: a tooltip with a table in it" />

| Procedure | Notes |
|---|---|
| `ig_begin_item_tooltip()` → `logical` | On the item drawn just before: `.true.` while the pointer rests on it, after the tooltip delay; declare the content, then `ig_end_tooltip()`. |
| `ig_begin_tooltip()` → `logical` | A tooltip now, at the pointer, whatever it is over: `.true.`; declare the content, then `ig_end_tooltip()`. |
| `ig_end_tooltip()` | End the tooltip, only after a true begin. |

(Dear ImGui's `BeginItemTooltip`, `BeginTooltip`, `EndTooltip`.) A tooltip is a small window that follows the pointer:
anything a window holds goes in it, a table, a plot, an image, coloured text. `ig_tooltip(text)` is the one-line case.

<<< @/examples/snippets/cb_context_menu-tooltip.F90{fortran}

- **The delay.** `ig_begin_item_tooltip` is `.true.` once the pointer has been still for 0.15 s and over the item for
  0.15 s (Dear ImGui's `HoverStationaryDelay` and `HoverDelayShort`, style fields): a pointer passing over a list
  does not flash a tooltip on every row. At 60 frames a second that is about 18 frames after the pointer stops.
- **`ig_begin_tooltip`** has no delay and no item: call it on the frames the tooltip must show, for instance when
  `ig_last_item()` says the item is hovered with the delay of your choice
  ([`ig_item_hovered(delay)`](#what-happened-to-an-item)), or over a plot while the program shows a value. Dear
  ImGui's begin is `.true.` in every frame today, but the rule stays: end only after a true begin.
- **Two tooltips in one frame** add to the same window, one below the other (Dear ImGui appends them).
- **Pairing:** a wrong end, or a scope left open inside the tooltip, is refused and reported, naming
  `ig_begin_item_tooltip()` ([Pairing and frames](errors#pairing-and-frames)). A font or a disabled block opened in
  a tooltip is closed before `ig_end_tooltip`.
- **Status:** no `stat`: with no frame open, or from a task, the begin returns `.false.` and the error is reported by
  the next `app%next_frame` (`FIG_ERR_STATE`, `ig_begin_tooltip: no frame open`).
- **Window, headless, remote:** the same; headless, `test_mouse_move` puts the pointer on the item and the frames
  that follow give the delay.
- **Threads:** the frame loop's thread only; a task is refused (`FIG_ERR_STATE`).
- **What it does not do:** a tooltip takes no input (no button in it can be clicked: the pointer moves it away); no
  tooltip of its own position (it follows the pointer); no delay per tooltip (the delay is the style's).

## Links

| Procedure | Notes |
|---|---|
| `ig_text_link(label)` → `logical` | Text drawn as a link (the style's `TextLink` colour, underlined, a hand pointer over it): `.true.` on the frame it is clicked. |
| `ig_text_link_url(label, url)` | A link that opens `url` when clicked; the pointer resting on it shows the URL, a right click offers "Copy Link". |

(Dear ImGui's `TextLink`, `TextLinkOpenURL`.) The text before `##` is shown; all of `label` is the id.

<<< @/examples/snippets/cb_context_menu-links.F90{fortran}

`ig_text_link` is a button that looks like a link: it shows a help line, opens a panel, jumps to a row.
`ig_text_link_url` hands the URL to the platform:

- **Window:** the system's handler opens it (SDL's `SDL_OpenURL`: the default browser for `https://`, the program a
  file's type is given to for a `file://` path).
- **Remote:** the page opens it in a new tab of the browser (the program sends it to the page as message 9). A browser
  may block the tab as a pop-up: the page then says so, and the user allows pop-ups for the page
  ([Known issues](known-issues#links-in-a-browser)). The browser is the user's: a `file://` URL names a file of the
  user's machine, not of the machine the program runs on.
- **Headless:** nothing is opened. `test_opened_url()` returns the URL the last click asked to open, in every mode, so
  a test checks the link without a browser. The documentation's recordings open nothing either.

`url` is passed as it is: give links the program owns, not text a user typed (`xdg-open` and the browser decide what
a URL does). **Status:** no `stat`: with no frame open, or from a task, nothing is drawn and the error is reported by
the next `app%next_frame`. **Threads:** the frame loop's thread only. **What it does not do:** no link inside a wrapped
paragraph (a link is an item of its own: put text before it with `ig_same_line`); no visited state.

## Markdown

| Procedure | Notes |
|---|---|
| `ig_markdown(text [, link] [, stat])` → `logical` | Draws `text`, Markdown, at the cursor, as wide as the window: `.true.` on the frame one of its links is clicked, its URL in `link`. |
| `md%init([toc] [, search] [, stat])`, `md%destroy()`, `md%is_initialized()` → `logical` | A document (`markdown_view_object`): its text kept by FIGURE, drawn in a scroll area of its own, with a table of contents (`toc`, default on) and a find bar (`search`, default on). |
| `md%set_text(text [, stat])`, `md%load(path [, stat])`, `md%text()` → `character` | Its text, given or read from a file (UTF-8); a copy of it. |
| `md%draw(id [, link] [, width] [, height] [, stat])` → `logical` | Draws the document as a widget; `.true.` on the frame one of its links is clicked, its URL in `link`. |
| `md%find(text [, stat])`, `md%matches()` → `int32`, `md%current_match()` → `int32` | Searches `text` as the find bar does (`''` ends the search); the matches, and the current one (from 1), at the last draw. |
| `md%scroll_to(heading [, stat])` | Scrolls to a heading, by its text or by its anchor after `#`. |

The renderer is [imgui_rich_md](https://github.com/pthom/imgui_rich_md) (MIT, with [md4c](https://github.com/mity/md4c),
its parser), vendored ([Third-party software](https://github.com/szaghi/figure/blob/main/THIRD_PARTY.md)). It draws
through Dear ImGui only: a help page looks the same in a window, headless and in a browser (remote mode).

<<< @/examples/snippets/cb_markdown-draw.F90{fortran}

<Media name="cb_markdown" video alt="A help page from a Markdown file beside a solver's window: a table of contents, headings, a table of keys, a list, a code block and a tip; a click in the contents scrolls to a section, ctrl+f highlights the matches of pressure, a click on a link shows its URL on the window's last line" caption="docs/examples/src/cb_markdown.F90" />

- **What a text may hold.** Headings (`#` to `######`, larger as they rise), paragraphs, `**bold**`, `*italic*`
  (`_text_` is underlined, not italic), `~~strikethrough~~`, `` `code spans` ``, links and bare URLs, lists (`-`, `*` with a bullet, `1.`), task lists (`- [x]`),
  quotes, GitHub's admonitions (`> [!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, `[!CAUTION]`), tables (columns
  sized by their content, aligned by `:---:`, resizable), fenced and indented code blocks with a Copy button, horizontal
  rules, collapsible sections (`<details><summary>`), and the HTML tags `<u>`, `<mark>`, `<kbd>`, `<sub>`, `<sup>`,
  `<br>`. Lines end with LF or CR LF.
- **Fonts.** The text in IBM Plex Sans (regular, bold, italic, bold italic: the four styles are bundled), headings
  larger by 5 % (`######`) to 42 % (`#`); code spans and blocks in IBM Plex Mono. The [icons](styles#icons) and the
  [fallback fonts](styles#fonts) (Noto Sans Math, the program's own) are merged into all of them, as into every
  FIGURE font: `∇·u`, `ρ` and an `ICON_*` show in a page. The body text is 15 pixels, the interface's default size.
- **Links are reported, never opened.** A click on a link returns `.true.` from the call that drew it, on that frame,
  with its URL in `link` (`''` on the other frames): the program decides what it means (another page, a section, a
  file, a browser through [`ig_text_link_url`](#links)'s platform handler or its own). A link to a heading of the same
  text (`[units](#units)`) scrolls there instead and is not reported; one to a heading the text lacks is, as
  `'#units'`. The pointer resting on a link shows its URL; a right click offers Copy, Copy as Markdown, Select All and
  Copy Link.
- **Anchors.** A heading's anchor is GitHub's: lower case, blanks as `-`, punctuation dropped
  (`Boundary conditions` → `#boundary-conditions`; a repeated title's second is `-1`).
- **Selection.** The text is selected with the mouse (a double click a word, a triple click a paragraph) and copied
  with ctrl+c (cmd+c on macOS).
- **Images** from files: `![alt](path)`, a PNG or a JPEG, read relative to the working directory (not to a file
  `md%load` read), at its size in pixels (`<img src="path" width="200">` for another). Not from a URL.
- **Documents.** `md%draw` draws its text in a child region `width` × `height` pixels (0: the available region;
  negative: up to that distance from its edge), which scrolls on its own. The table of contents appears from three
  headings: a panel beside the text whose edge the reader drags, or a line above a narrow document (under 40 em); it
  shows the current section, and a click scrolls to one. The find bar (ctrl+f, cmd+f on macOS, or `/` while the
  document has the focus) highlights the matches in the text, the code blocks and the collapsed sections, counts them
  per section, ticks them on the scrollbar; enter goes to the next one, shift+enter to the previous one, escape closes
  it. `md%find` and `md%scroll_to` do the same from the program; they act at the next `md%draw`.
- **`ig_markdown` or a document.** `ig_markdown` is a few lines inside a window (a description above a form, an About
  box): the text is passed, and converted, at every frame, and the window scrolls it with the rest. A document keeps
  its text (no copy per frame), and has its own scroll, its contents and its search: a help page, release notes.

<<< @/examples/snippets/cb_markdown-inline.F90{fortran}

**Status:** `ig_markdown` and `md%draw` return `FIG_ERR_STATE` with no frame open and from a task, `md%*` before
`md%init`; `FIG_ERR_ARGUMENT` for an empty id (`md%draw`), a search longer than 255 bytes or of two lines (`md%find`),
an empty heading (`md%scroll_to`), an empty file name (`md%load`); `FIG_ERR_FAILED` for a file that cannot be read
(`md%load`, the text kept). Absent `stat`: `error stop` with the message ([Errors](errors)). **Threads:** the frame
loop's thread only; `md%set_text`, `md%load`, `md%find` and `md%scroll_to` may be called before `init*` (they draw
nothing). **Modes:** the same in window, headless and remote modes. **What it does not do:** no LaTeX formulas
(`$...$` is text), no images from URLs, no Mermaid diagrams (a ` ```mermaid ` block is code), no syntax highlighting
in code blocks, no file included into a page (`![[file]]`), no footnotes; nothing is opened by a click
([Known issues](known-issues#markdown)).

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

A label level with its field, a field at a fixed distance from the left edge, a hint, a warning that carries a mark
besides its colour, two buttons of one width (the widest label's), and a paragraph of help:

<<< @/examples/snippets/cb_controls-text.F90{fortran}

Gaps, groups, alignment, widths and sizes that follow the font: [Layout](#layout).

## Layout

<Media name="layout_metrics" alt="A window with two lines of text, two labelled fields, two buttons, an indented text and two right-aligned buttons. Dimension lines drawn over it, each with its call: ig_font_size() = 1 em = 15 px is the height of a line of text; ig_line_height(spacing=.true.) = 19 px goes from one line's top to the next one's; ig_frame_height() = 21 px is a field's height and ig_frame_height(spacing=.true.) = 25 px the distance between two rows of fields; ig_same_line(ig_em(5)) runs from the window's edge to where the fields start; ig_push_item_width(ig_em(12)) = 180 px is a field's width; WindowPadding goes from the window's edge to the content; ItemSpacing is the gap between Apply and Cancel; ig_indent() moves the indented text right; ig_available(w, h) spans the content's width, 644 px; ig_align_begin('buttons', 'right') marks the two buttons at the right edge." caption="docs/examples/src/gallery.F90, run with layout_metrics: the lengths of the layout calls at the default font, 15 px" />

| Procedure | Notes |
|---|---|
| `ig_font_size()` → `real(real64)` | The current font's size [pixels]: the size set by `app%set_font` (or pushed by `ig_push_font`) times the display's content scale. One **em**. |
| `ig_em(x)` → `real(real64)` | `x` em [pixels], `x` `real64` or `int32`: `x * ig_font_size()`. |
| `ig_line_height([spacing])` → `real(real64)` | A line of text's height [pixels] (the font size); with `spacing=.true.`, plus the vertical item spacing: from one line's top to the next one's. |
| `ig_frame_height([spacing])` → `real(real64)` | A framed widget's height [pixels] (a button, a field: the font size and the frame padding above and below); with `spacing=.true.`, the distance between two rows of fields. |
| `ig_available(w, h)` | The space left [pixels] from where the next item goes to the right edge (`w`) and the bottom (`h`) of the window or region's content; in a table cell, to the cell's edge. |
| `ig_spacing()` | A gap of the vertical item spacing. |
| `ig_dummy(w, h)` | An empty item `w` x `h` [pixels]: a gap of a given size, a place kept. |
| `ig_new_line()` | End the line after `ig_same_line`, or an empty line. |
| `ig_indent([w])`, `ig_unindent([w])` | Move the left edge of the lines that follow by `w` [pixels] (default, or 0: the style's `IndentSpacing`), and back. |
| `ig_begin_group()`, `ig_end_group()` | Always paired: the items in between count as one item, their bounding rectangle. |
| `ig_align_begin(id, where [, stat])`, `ig_align_end()` | Always paired: a group centred (`where='centre'`) or right-aligned (`'right'`) in the space left on the line. `id` names it in its window. |
| `ig_align_next(width, where [, stat])` | Centre or right-align the next item, `width` [pixels] wide. |
| `ig_separator_text(label)` | A separator with a title at its left. |
| `ig_push_item_width(w)`, `ig_pop_item_width()` | Always paired: the fields' width [pixels] for every widget up to the pop (negative: up to that distance from the right edge; 0: the window's default). `ig_set_next_item_width` sets the next one's alone ([Tooltips and widths](#tooltips-and-widths)). |

(Dear ImGui's `GetFontSize`, `GetTextLineHeight`/`GetTextLineHeightWithSpacing`, `GetFrameHeight`/`GetFrameHeightWithSpacing`,
`GetContentRegionAvail`, `Spacing`, `Dummy`, `NewLine`, `Indent`/`Unindent`, `BeginGroup`/`EndGroup`, `SeparatorText`,
`PushItemWidth`/`PopItemWidth`; `ig_em` and the alignment calls are FIGURE's, built on `BeginGroup` and Dear ImGui's
storage of the window.)

**Sizes in em.** A length written in pixels stays the same when the user picks a larger font, and the form's labels
outgrow their column. A length written in em, `ig_em(12)`, is twelve times the current font size: it follows
`app%set_font`, `ig_push_font` and the display's content scale. A form sized in em keeps its proportions at any font
size: the column where the fields start (`ig_same_line(ig_em(7))`), the fields' width (`ig_push_item_width(ig_em(12))`),
the window's width (`ig_set_next_window(..., ig_em(24), ...)`). The rule: lengths that hold text in em, gaps in the
style's own spacing (`ig_spacing`, `ig_same_line()`), the window's height left to its content (0 to
`ig_set_next_window`). The style's paddings and spacings are pixels scaled by the display's content scale, not by the
font: a window whose height is given in em gets too small for its content at small fonts.

<<< @/examples/snippets/cb_layout-label.F90{fortran}

<<< @/examples/snippets/cb_layout-form.F90{fortran}

<<< @/examples/output/cb_layout.txt{text}

**Groups.** `ig_begin_group` ... `ig_end_group` lays its items out as usual and then makes them one item: `ig_same_line`
after the end puts the next item beside the whole group (a column of labels, then a column of fields), and
[`ig_last_item`](#what-happened-to-an-item) reports the group's rectangle, `rect`. A group may hold any items,
groups included; it does not scroll or clip (that is a [region](#lists-and-regions)).

**Alignment and its first frame.** A group's width is known only once it is drawn, and its place depends on it.
`ig_align_begin` places the group with the width it had on the previous frame, kept in Dear ImGui's storage of the
window under `id`: on the first frame the group appears at the left, where a group starts, and FIGURE asks for one more
frame (with the [lazy redraw](frame-loop#lazy-redraw) too), which draws it in place. The same happens on the frame its
width changes (a font size, a longer label): one frame drawn with the old width, corrected on the next. A program that
draws only when asked sees the correct frame, since the correction is drawn at once; a [test](testing) that measures
the group measures it from the second frame. `ig_align_next(width, where)` places one item of a width the program knows
(a button given a width, a text measured with `ig_text_size`): right on the first frame. A group or an item wider than
the space left is not moved.

**Pairing.** `ig_begin_group`/`ig_end_group`, `ig_align_begin`/`ig_align_end` and
`ig_push_item_width`/`ig_pop_item_width` are always paired, in the same window, and close innermost first, as
`ig_push_id`/`ig_pop_id`: an end that is not the end of the innermost open scope is refused and reported, and one left
open is closed by FIGURE at the end of the frame ([Pairing and frames](errors#pairing-and-frames)). `ig_indent` and
`ig_unindent` are not a scope: the program keeps them balanced (each window's indent starts at 0 when it is begun).

**Status:** an unknown `where` (`'center'`, `'left'`): `FIG_ERR_ARGUMENT`, `ig_align_begin: where is 'centre' or
'right', not 'center' (the group is begun, not moved)`: the group is begun all the same, so `ig_align_end` still
follows; for `ig_align_next`, a negative or NaN width too (`ig_align_next: width <w> is negative`,
`ig_align_next: width NaN is not a width`), and nothing is done. `stat` is optional (absent: `error stop` with the message, [Error handling](errors)). With no frame open or from
a [task](processes#tasks), every call is refused with `FIG_ERR_STATE` (`ig_em: no frame open`; the metrics give 0): a
size computed before the first `next_frame` is 0, so compute sizes inside the loop.

- **Window:** as described. **Headless:** the same, content scale 1. **Remote:** the same; the browser shows the
  frames as drawn, content scale 1.
- **Threads:** the frame loop's thread only; a task is refused (`FIG_ERR_STATE`), as every drawing call.
- **What it does not do:** no layout engine: no columns or grids that share space by weight (a
  [table](#groups-headers-tabs-tables) does that), no vertical alignment, no automatic wrapping of items onto the next
  line. The style's paddings and spacings do not follow the font. An aligned group's first frame is drawn at the left
  (see above). `ig_align_begin` aligns within the space left on the current line, not in the window: after
  `ig_same_line` it aligns in what is left of that line.

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

## Players

| Procedure | Notes |
|---|---|
| `ig_player(id, player [, labels] [, stat])` → `logical` | A player for `player%count` snapshots on one line: previous, play/pause, next and a slider over the snapshots; a right click opens its menu (speed and mode). `.true.` on the frame it changed `player%index`. |
| `player_object` | The player's state, a plain value the program keeps: `%index`, `%count`, `%playing`, `%speed`, `%mode`. |

A player steps through saved solutions: the snapshots of a run written every so many iterations, the frames of an
animation, the cases of a parameter sweep. The program keeps the snapshots (in memory or as files) and a
`player_object`; `ig_player` draws the player and says which snapshot to show. It is built from Dear ImGui's
`Button`, `SliderInt`, `BeginPopupContextItem`, `InputScalar` and `RadioButton` inside a group (`BeginGroup`); Dear
ImGui has no player of its own (the idea is ImGuiExtra.jl's scrubber).

<<< @/examples/snippets/cb_player-player.F90{fortran}

<<< @/examples/snippets/cb_player-draw.F90{fortran}

<Media name="cb_player" video alt="A window Solutions: a player on one line, a step-back button, a play button, a step-forward button and a slider that reads t = 0.00 s, above a plot of u against x with a pulse at the left. The pointer clicks play: the button turns into pause, the slider runs through t = 0.05, 0.10 s and on, and the pulse moves to the right; at t = 1.95 s it turns back. The pointer clicks pause, then step-forward and step-back: the slider moves by one snapshot each time. A right click on the slider opens the menu: a field for the snapshots per second and the radio buttons once, loop and bounce (chosen)." caption="docs/examples/src/cb_player.F90: step through saved solutions" />

**The state.** The components are public: the program sets them when it likes (a new run loaded: `count`; a jump to
a snapshot picked elsewhere: `index`; a key that plays: `playing`), and the player sets them when the user acts on
it.

| Component | Meaning | Default |
|---|---|---|
| `index` | the snapshot shown, 1 to `count` (outside: moved to the nearest end, and `.true.` returned) | 1 |
| `count` | snapshots, at least 1 | 1 |
| `playing` | advancing by itself | `.false.` |
| `speed` | snapshots per second while playing, > 0 [1/s] | 10 |
| `mode` | at the last snapshot: `'once'` stops (and `playing` becomes `.false.`), `'loop'` goes on from the first, `'bounce'` turns back, and again at the first | `'loop'` |

**The controls.** Previous and next step one snapshot and stop the playing; in mode `'loop'` they wrap around (previous
at the first shows the last), in the others they stop at the ends. Play starts from the snapshot shown (in mode
`'once'` at the last snapshot, from the first) and turns into pause. A click or a drag on the slider shows that
snapshot and stops the playing. The slider shows `labels(index)` (a time, a file name; `%` is shown as it is) or, without
`labels`, `index / count`. A right click anywhere on the player opens its menu: the speed, typed (a value <= 0 is not
taken), and the mode, three radio buttons; a click outside closes it.

**Time.** While `playing`, the player advances `speed` snapshots per second of the frame clock (Dear ImGui's time,
`GetTime`): the time between the frames in a window, 1/60 s per frame headless (so a test knows how many snapshots
60 frames step), the time between frames in remote mode, the fixed frame time of a recording. A frame that takes
longer steps more snapshots at once, so the player keeps time when frames are slow. The clock runs on the frames the
player is drawn: hidden (a collapsed header, a tab not shown) it pauses, and goes on from there when shown again.
While playing, `ig_player` asks for one more frame on every frame ([`app%request_frames(1)`](frame-loop#lazy-redraw)),
so a lazy loop keeps drawing and the program needs no `set_lazy(.false.)`; paused, it asks for nothing and the loop
sleeps again.

**Layout.** The player is as wide as the current item width: `ig_set_next_item_width` before it, or
`ig_push_item_width` ([Layout](#layout)); the buttons are square, a field's height; the slider takes the rest. The
player is one group: `ig_same_line`, `ig_item_rect` and `ig_last_item` after it refer to the whole player, and its
id scope (`id`) keeps its buttons apart from the window's other items; two players in one window need two ids.

The program checks itself headless (play, at 8 snapshots per second a step every 7.5 frames of 1/60 s; pause 60
frames later; next; previous):

<<< @/examples/output/cb_player.txt{text}

- **Pairing and frame rules:** call it every frame, inside a window; it opens no scope the program closes (its group,
  id scope and menu are begun and ended inside, and the scope record of the frame sees them balanced). Valid on the
  frame it returns `.true.`: draw `player%index` then.
- **Units:** `speed` in snapshots per second; `index` and `count` are counts (1-based).
- **Status:** `stat` is optional (absent: `error stop` with the message). Refused with `FIG_ERR_ARGUMENT`, nothing
  drawn and `.false.` returned: `count` < 1 (`ig_player: count must be at least 1 (got 0)`), `speed` <= 0, NaN or
  infinite (`ig_player: speed must be > 0 snapshots per second`), an unknown `mode` (`ig_player: unknown mode "ping"
  ('once', 'loop' or 'bounce')`), `labels` not of `count` entries (`ig_player: labels has 2 entries, not count`). No
  frame open or from a task: `FIG_ERR_STATE` ([Errors](errors#players)).
- **Window, headless, remote:** the same. Headless, `test_click` presses its buttons and the slider (the buttons are
  squares of side `ig_frame_height()`, `ItemSpacing` apart, from the left of `ig_item_rect`), `test_click(...,
  button='right')` opens its menu, and every frame advances the clock by 1/60 s. In remote mode the frames come at
  the rate the page draws them, and the player keeps time by the clock between them.
- **Threads:** the frame loop's thread only; a task is refused (`FIG_ERR_STATE`). A `player_object` itself may be
  set from anywhere the program owns it.
- **What it does not do:** it does not load or keep the snapshots (the program draws `player%index`); it does not
  skip a snapshot that takes long to load or draw (a slow frame steps more at once, it does not wait); no keyboard
  shortcuts of its own (bind keys with `ig_shortcut` and set `playing` or `index`); no reverse play other than mode
  `'bounce'`; speeds and modes are not saved between runs.

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

<<< @/examples/snippets/cb_controls-clipper.F90{fortran}

An input-file editor's layout: a list of sections in a narrow region, the section's values and its help in the region
beside it. Each region scrolls under the wheel on its own; the window does not move.

<<< @/examples/snippets/cb_help-list.F90{fortran}

<Media name="cb_help" alt="A list of three sections on the left; picking one shows its values and its help text on the right" caption="docs/examples/src/cb_help.F90" />

### Splitters

Two regions side by side (a tree and a file, a list and its plot) or one above the other share the space through a
bar between them that the user drags:

<<< @/examples/snippets/cb_splitter-panes.F90{fortran}

| Procedure | Notes |
|---|---|
| `ig_splitter(id, sizes [, vertical] [, min_size] [, stat])` → `logical` | A bar between two panes; `.true.` on the frames a drag changes `sizes`. |

- `sizes(2)`, `real(real64)` [pixels]: the panes' widths (side by side, the default) or heights (`vertical=.true.`:
  one above the other), the program's variables, which the drag changes: their sum is kept and neither goes below
  `min_size` (default: the frame height, `ig_frame_height()`). The program sizes the panes with them
  (`ig_begin_child(id, sizes(1), 0.0_real64)`).
- **Where.** At the cursor, between the panes: side by side, after the first pane and `ig_same_line()`, then
  `ig_same_line()` again before the second; one above the other, between the two. The bar is the style's item spacing
  thick and runs to the end of the region in the other direction (give the panes the region's other extent: 0 for a
  child fills it). It is drawn in the separator's colours; the pointer becomes a resize arrow over it.
- **Three panes or more:** a splitter between each pair, each with its two sizes (`sizes(1:2)`, `sizes(2:3)`).
- `id` names the bar in its window: a [path](testing#finding-items-by-path) finds it (`'Files/split'`), so a test
  drags it with `test_drag` from the centre of `test_item_rect`'s rectangle.

(Dear ImGui's `SplitterBehavior`, internal to Dear ImGui: FIGURE's glue calls it.)

`docs/examples/src/cb_splitter.F90` drags its bar 60 pixels, headless:

<<< @/examples/output/cb_splitter.txt{text}

**Status.** `stat` is optional (absent: `error stop` with the message). `FIG_ERR_ARGUMENT`: `ig_splitter: sizes has
two values, the panes on either side`; with no frame open, a usage error (`FIG_ERR_STATE`, `ig_splitter: no frame
open`); from a task, refused (`FIG_ERR_STATE`). **Modes:** the same in window, headless and remote modes. **Threads:**
the frame loop's thread.

**What it does not do.** The window's size is not followed: when the window shrinks, the second pane is what gets
narrower (the program rescales `sizes` if it wants proportions kept). The panes' sizes are not kept between runs (save
them with [`app%save_pref`](frame-loop#preferences)).

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
| `ig_begin_table(id, columns [, ...])`, `ig_end_table()` | End only when the begin returned `.true.`; the rest in [Tables](#tables). |
| `ig_push_id(id)`, `ig_pop_id()` | Always paired: an id scope, by `character` or `int32`. |
| `ig_begin_disabled([disabled])`, `ig_end_disabled()` | Always paired: the widgets in between are greyed out and ignore input. |

Tabs and tables follow Dear ImGui's rule, which differs from windows: `ig_end` follows every `ig_begin`, whatever it
returned, while `ig_end_tab`, `ig_end_tab_bar` and `ig_end_table` follow only a begin that returned `.true.`. FIGURE
checks both rules, and the nesting of the scopes, at every end: [Pairing and frames](errors#pairing-and-frames).

<<< @/examples/snippets/cb_form-fields.F90{fortran}

## Tables

<Media name="cb_table_sort" video alt="A table of 200 grid blocks with columns block, body, cells and residual. A click on the header cells sorts the rows by cells, largest first, and a second click smallest first; a click on residual puts the largest residuals on top, their rows coloured and their values marked with an exclamation mark; the wheel scrolls the rows while the header stays in place" caption="docs/examples/src/cb_table_sort.F90: a sortable table with a fixed header" />

| Procedure | Notes |
|---|---|
| `ig_begin_table(id, columns [, flags] [, height] [, freeze_rows] [, freeze_cols] [, sortable] [, hideable] [, reorderable] [, scroll_x] [, stat])` → `logical` | A table of `columns` columns (1 to 511); `.true.`: fill it, then `ig_end_table()`. |
| `ig_table_setup_column(label [, width] [, stretch] [, sort] [, default_sort] [, descending] [, hidden] [, no_hide] [, stat])` | Declares the next column, before the first row: its header label, a fixed `width` [pixels] or a `stretch` weight, how it sorts and hides. |
| `ig_table_headers_row()` | A row with the labels of the declared columns: a click sorts, a drag reorders, a right click opens the columns' menu. |
| `ig_table_next_row()`, `ig_table_next_column()`, `ig_table_set_column(column)` | Starts a row; moves to the next cell, or to cell `column` (1-based); the widgets that follow go in it. |
| `ig_table_sort(column, descending [, stat])` → `logical` | `.true.` on the frame the user asks a new order; `column` (1-based) and `descending` give it, on every frame. The program sorts. |
| `ig_table_row_color(rgba [, cell] [, stat])` | A colour behind the current row, or behind its cell `cell`, on this frame. |
| `ig_table_hovered_column([stat])` → `integer(int32)` | The column under the pointer, headers included; 0 when none. |
| `ig_table_column_enabled(column, enabled [, stat])` | Shows or hides a column of a hideable table from the program, from the next frame. |
| `ig_tree_node(... [, span_all_columns])` | A tree node whose row is its hit area across every column ([Trees](#trees)). |

(Dear ImGui's `BeginTable`, `TableSetupColumn`, `TableSetupScrollFreeze`, `TableHeadersRow`, `TableGetSortSpecs`,
`TableSetBgColor`, `TableGetHoveredColumn`, `TableSetColumnEnabled`; `freeze_rows` and `freeze_cols` are
`TableSetupScrollFreeze`'s rows and columns.)

**Filling a table.** Row by row: `ig_table_next_row`, then `ig_table_next_column` before each cell's widgets (or
`ig_table_set_column(column)`, 1-based). Before the first row, one `ig_table_setup_column` per column, in order, then
`ig_table_headers_row` for their labels. A column is fixed (`width` [pixels]) or stretched (`stretch`, a weight
[relative, > 0]: the stretched columns share the width left in proportion; default weight 1). Widgets repeated on
every row repeat their labels: open an id scope per row with `ig_push_id(row)`, so that row 2's field is not row 1's
(see [Labels and identifiers](#labels-and-identifiers)).

<<< @/examples/snippets/cb_form-table.F90{fortran}

<Media name="cb_form" alt="An input-file editor: a field typed over, a scheme picked from a list, a restart option ticked, then a row added to a table of boundary conditions and edited" caption="docs/examples/src/cb_form.F90: the preview on the right follows the variables" />

**Flags.** The default `flags` give borders, alternating row colours and resizable columns. `flags` replaces them with
`ImGuiTableFlags_*` combined by `ior` (every one of Dear ImGui's is exported: `Borders`, `BordersInnerV`, `RowBg`,
`Resizable`, `ScrollY`, `ScrollX`, `Sortable`, `SortMulti`, `SortTristate`, `Hideable`, `Reorderable`,
`HighlightHoveredColumn`, `NoSavedSettings`, the `Sizing*` policies, ...); the logical arguments then set (`.true.`)
or clear (`.false.`) one flag each, over the default or over `flags`: `sortable`, `hideable`, `reorderable`,
`scroll_x`.

**A fixed header.** `freeze_rows=1` keeps the headers row in view while the rows scroll; `freeze_cols=n` keeps the
first `n` columns in view while the table scrolls sideways. A frozen row turns `ImGuiTableFlags_ScrollY` on and a
frozen column `ImGuiTableFlags_ScrollX` (Dear ImGui freezes only what scrolls). A table that scrolls is a region of
its own: `height` [pixels] sets its height; without it, it fills the height left in the window. Long tables draw
only the rows in view with a [`list_clipper_object`](#lists-and-regions) between the headers row and
`ig_end_table`: the clipper counts the rows below the frozen header, so row 1 is the first row of data.

<<< @/examples/snippets/cb_table_sort-table.F90{fortran}

**Sorting is the program's job.** A click on a header asks an order; `ig_table_sort` reports it and FIGURE moves
nothing. It returns `.true.` on the frame the order is asked: on the first frame (the default order: the column
declared `default_sort`, or the first one), and after each click on a header (the same header again: the other
direction; `descending` on a column makes its first click largest first). `column` is the column's place in the
declaration, whatever order the user dragged the columns into. On a `.true.` frame the program sorts, then draws the
rows in the new order. Sort a **permutation of the row indices**, not the data: the arrays stay where they are (other
code indexes them, the selection is a block number, not a row), only `order(:)` moves, and the rows are drawn as
`k = order(i)`. A stable sort (rows equal in the key keep their order) makes the column sorted before a second key.

<<< @/examples/snippets/cb_table_sort-sort.F90{fortran}

The program checks itself headless (clicks on the header, then the wheel):

<<< @/examples/output/cb_table_sort.txt{text}

**Row colours.** `ig_table_row_color(rgba)` in a row colours it on this frame, over the alternating background;
`cell=c` colours only its cell in column `c`. `rgba` is `[r, g, b]` or `[r, g, b, a]` in [0, 1]. Pair the colour with
a mark or a word (the residual's `!` above): a colour alone does not reach every reader.

**Hidden columns.** In a hideable table, a right click on the headers row opens Dear ImGui's menu of the columns,
where the user shows and hides them. `hidden=.true.` hides a column the first time the table is shown, `no_hide`
keeps one shown, and `ig_table_column_enabled(column, enabled)` shows or hides one from the program (from the next
frame). A hidden column draws nothing: the widgets in its cells are skipped. Dear ImGui keeps the widths, the order,
the sort and the hidden columns from frame to frame, by the table's `id`, and across runs in the settings file when
the program keeps one (`app%init(..., ini_file=...)`; none by default): `default_sort` and `hidden` act only on a table
it has not seen. `ImGuiTableFlags_NoSavedSettings` keeps a table out of the file.

**The column under the pointer.** `ig_table_hovered_column()` inside the table: 1 to `columns` over a column (its
header included; the column's place in the declaration, as `ig_table_sort`'s), 0 elsewhere. With `ig_begin_popup_context` after a cell's widget it tells which column a right
click was on ([Context menus](menus#context-menus)).

- **Pairing:** `ig_end_table` only after a true `ig_begin_table`; the scope record checks it, and the trees, popups
  and id scopes inside it close first ([Pairing and frames](errors#pairing-and-frames)). `ig_table_setup_column`
  before the first row; `ig_table_sort` after the last `ig_table_setup_column` (before or after the headers row);
  `ig_table_row_color` after `ig_table_next_row`, in the row it colours.
- **Status:** the `stat` of each call is optional. An argument out of range (`columns` outside 1 to 511,
  `freeze_rows` outside 0 to 127, `freeze_cols` outside 0 to `columns`, `width` and `stretch` together, a negative
  width, a weight not above 0, a colour of the wrong size or outside [0, 1], a `cell` or `column` outside 1 to the
  columns) gives `FIG_ERR_ARGUMENT`, nothing done (a begin returns `.false.`): absent `stat`, `error stop` with the
  message. A call out of its place (`ig_table_sort`, `ig_table_row_color`, `ig_table_hovered_column`,
  `ig_table_column_enabled` with no table open; `ig_table_sort` in a table not `sortable` or before every column is
  declared; `ig_table_column_enabled` in a table not `hideable`; `ig_table_row_color` before the first row) is a usage
  error, `FIG_ERR_STATE`: absent `stat`, reported by the next `app%next_frame` as the pairing errors are. The messages
  are in [Error handling](errors#tables).
- **Window, headless, remote:** the same; headless, `test_click` on a header sorts and `test_wheel` over the rows
  scrolls them.
- **Threads:** the frame loop's thread only; a task is refused (`FIG_ERR_STATE`).
- **What it does not do:** no sorting of the program's rows (FIGURE reports the order; the program sorts); with
  `ImGuiTableFlags_SortMulti` only the first key is reported (the others: raw `igTableGetSortSpecs`); no row selection
  (an `ig_selectable` in the first cell, as in [Lists and regions](#lists-and-regions)); no editing of a cell in place
  (put a field in it); the clipper needs rows of equal height.

## Trees

| Procedure | Notes |
|---|---|
| `ig_tree_node(label [, default_open] [, selected] [, leaf] [, span_full_width] [, clicked] [, span_all_columns])` → `logical` | A node of a tree (`TreeNodeEx`); `.true.` while open: draw its children, then `ig_tree_pop`. |
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
pop, so the first column keeps their indentation. `span_all_columns=.true.` (Dear ImGui's
`ImGuiTreeNodeFlags_SpanAllColumns`) makes the node's whole row its hit area and its highlight: a click on a value
chooses the node, and `selected` colours the row across every column, as in a file manager's tree view. Text in the
other cells leaves the click to the node; the node covers the row, so a row whose cells hold widgets (a field, a
button) keeps the node to its own cell (`span_full_width`, or no span).

<<< @/examples/snippets/cb_tree-tree.F90{fortran}

**Large trees.** A `list_clipper_object` needs rows of equal height in one run, and an open node in the middle of the
list breaks the run: a tree cannot be clipped as a whole. The children of one node can: a node with thousands of
blocks clips them between the node and its pop. A deep tree with many open nodes is flattened by the program: it keeps
the open state of each node, builds the list of the visible rows (node or child, with its depth) when a node opens or
closes, and clips that list.

<<< @/examples/snippets/cb_tree-large.F90{fortran}

<Media name="cb_tree" alt="A table of grids: the wing open with three blocks; block 2 is chosen by a click on its cells and highlighted across its row, the fuselage opened by its arrow shows two more blocks, then the background node opens on a region of 20000 blocks that scrolls" caption="docs/examples/src/cb_tree.F90" />

Trees are drawn the same in window, headless and remote modes; they have no failure status.

## Not bound yet

Colour pickers have no wrapper yet; menus are on their own page,
[Menus and shortcuts](menus). Their raw interfaces are generated
([Raw bindings](raw-bindings)); the Fortran wrappers are still to be written ([roadmap](roadmap)).
