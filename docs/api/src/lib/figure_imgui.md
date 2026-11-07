---
title: figure_imgui
---

# figure_imgui

> figure_imgui, Dear ImGui widgets with Fortran arguments.

 Immediate mode: call the widgets every frame; each returns what happened this frame (`ig_button` is true on the
 frame it is clicked, `ig_checkbox`/`ig_slider` are true when they changed the value). Values are ordinary Fortran
 variables, updated in place: no handles, no callbacks, no `target` requirements (the C `bool*` of a checkbox is a
 local copy, written back).

**Source**: `src/lib/figure_imgui.F90`

**Dependencies**

```mermaid
graph LR
  figure_imgui["figure_imgui"] --> figure_base["figure_base"]
  figure_imgui["figure_imgui"] --> figure_c_native["figure_c_native"]
  figure_imgui["figure_imgui"] --> figure_cimgui["figure_cimgui"]
  figure_imgui["figure_imgui"] --> figure_cimgui_enums["figure_cimgui_enums"]
  figure_imgui["figure_imgui"] --> figure_texture["figure_texture"]
  figure_imgui["figure_imgui"] --> iso_c_binding["iso_c_binding"]
  figure_imgui["figure_imgui"] --> iso_fortran_env["iso_fortran_env"]
```

## Contents

- [text_buffer_object](#text-buffer-object)
- [ig_slider](#ig-slider)
- [ig_input](#ig-input)
- [ig_end](#ig-end)
- [ig_set_next_window](#ig-set-next-window)
- [ig_align_text_to_frame_padding](#ig-align-text-to-frame-padding)
- [ig_set_clipboard](#ig-set-clipboard)
- [text_buffer_set](#text-buffer-set)
- [text_buffer_final](#text-buffer-final)
- [ig_tooltip](#ig-tooltip)
- [ig_set_next_item_width](#ig-set-next-item-width)
- [ig_text](#ig-text)
- [ig_same_line](#ig-same-line)
- [ig_text_wrapped](#ig-text-wrapped)
- [ig_text_disabled](#ig-text-disabled)
- [ig_text_colored](#ig-text-colored)
- [ig_progress_bar](#ig-progress-bar)
- [ig_separator](#ig-separator)
- [ig_show_demo_window](#ig-show-demo-window)
- [ig_item_rect](#ig-item-rect)
- [ig_image](#ig-image)
- [ig_begin](#ig-begin)
- [ig_begin_side_bar](#ig-begin-side-bar)
- [ig_focus_window](#ig-focus-window)
- [ig_button](#ig-button)
- [ig_tool_button](#ig-tool-button)
- [ig_text_size](#ig-text-size)
- [ig_checkbox](#ig-checkbox)
- [ig_slider_i32](#ig-slider-i32)
- [ig_slider_r32](#ig-slider-r32)
- [ig_slider_r64](#ig-slider-r64)
- [ig_input_r64](#ig-input-r64)
- [ig_input_i32](#ig-input-i32)
- [ig_input_text](#ig-input-text)
- [ig_input_text_multiline](#ig-input-text-multiline)
- [ig_get_clipboard](#ig-get-clipboard)
- [text_buffer_text](#text-buffer-text)
- [text_buffer_length](#text-buffer-length)
- [ig_combo](#ig-combo)
- [ig_selectable](#ig-selectable)

## Derived Types

### text_buffer_object

Text of any length, edited by `ig_input_text_multiline`: a file shown or edited as text, notes, a read-only view.
 The text is kept by FIGURE's native layer, which grows it while the user types or pastes (no capacity to choose,
 no copy per frame); `set` replaces it, `text` returns a copy. Lines end with LF (`set` turns CRLF into LF).
 Usable before `init*` and from a task (it draws nothing). Not to be copied: the copy would share the text, and
 the first of the two to end would take it away from the other.

#### Components

| Name | Type | Attributes | Description |
|------|------|------------|-------------|
| `id` | integer(kind=c_int) |  | Native handle (0: no text yet, an empty one). |

#### Type-Bound Procedures

| Name | Attributes | Description |
|------|------------|-------------|
| `set` | pass(self) | Replace the text. |
| `text` | pass(self) | A copy of the text. |
| `length` | pass(self) | Its length [bytes]. |

## Interfaces

### ig_slider

Slider for an integer or a real value.

**Module procedures**: [`ig_slider_i32`](/api/src/lib/figure_imgui#ig-slider-i32), [`ig_slider_r32`](/api/src/lib/figure_imgui#ig-slider-r32), [`ig_slider_r64`](/api/src/lib/figure_imgui#ig-slider-r64)

### ig_input

Numeric field for an integer or a real value.

**Module procedures**: [`ig_input_i32`](/api/src/lib/figure_imgui#ig-input-i32), [`ig_input_r64`](/api/src/lib/figure_imgui#ig-input-r64)

## Subroutines

### ig_end

End the window opened by `ig_begin` (whatever it returned).

**Attributes**: recursive

```fortran
subroutine ig_end()
```

**Call graph**

```mermaid
flowchart TD
  ig_end["ig_end"] --> figure_refused["figure_refused"]
  ig_end["ig_end"] --> igEnd["igEnd"]
  style ig_end fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_set_next_window

Position (and size) of the next window [pixels]: on first use only, or every frame if `always`.

```fortran
subroutine ig_set_next_window(x, y, width, height, always)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `x` | real(kind=real64) | in |  | Left [pixels]. |
| `y` | real(kind=real64) | in |  | Top [pixels]. |
| `width` | real(kind=real64) | in | optional | Width [pixels]. |
| `height` | real(kind=real64) | in | optional | Height [pixels]. |
| `always` | logical | in | optional | Enforce every frame (default: first use only). |

**Call graph**

```mermaid
flowchart TD
  ig_set_next_window["ig_set_next_window"] --> igSetNextWindowPos["igSetNextWindowPos"]
  ig_set_next_window["ig_set_next_window"] --> igSetNextWindowSize["igSetNextWindowSize"]
  style ig_set_next_window fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_align_text_to_frame_padding

The text that follows on this line is lowered to the text of framed widgets (fields, buttons): a label or a value
 beside fields, in a table row of fields.

```fortran
subroutine ig_align_text_to_frame_padding()
```

**Call graph**

```mermaid
flowchart TD
  ig_align_text_to_frame_padding["ig_align_text_to_frame_padding"] --> igAlignTextToFramePadding["igAlignTextToFramePadding"]
  style ig_align_text_to_frame_padding fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_set_clipboard

Put `text` (UTF-8, trailing blanks included: pass `trim` of a padded variable) on the clipboard, as a copy in a
 field does. Window mode: the system's clipboard (SDL's). Headless mode: a clipboard of the program's own.
 Remote mode: the program's own on the server, also written to the browser's clipboard where the browser allows
 it (a page reached as https or localhost, and in a few browsers only right after a click or a key). Status:
 `FIG_ERR_STATE` before `init*` or from a task (`stat` optional: absent, `error stop` with the message).

**Attributes**: recursive

```fortran
subroutine ig_set_clipboard(text, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `text` | character(len=*) | in |  | Text. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ig_set_clipboard["ig_set_clipboard"] --> fig_set_clipboard["fig_set_clipboard"]
  ig_set_clipboard["ig_set_clipboard"] --> figure_check["figure_check"]
  ig_set_clipboard["ig_set_clipboard"] --> figure_refused["figure_refused"]
  style ig_set_clipboard fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### text_buffer_set

Replace the text with `text` (UTF-8, lines ended by LF or CRLF; trailing blanks are part of it: pass `trim` of a
 padded line). A field being edited shows the new text at once, its undo history kept. A NUL byte ends the text.
 Status: `FIG_ERR_ARGUMENT` for a text of 2 GiB or more (`stat` optional: absent, `error stop` with the message).

**Attributes**: recursive

```fortran
subroutine text_buffer_set(self, text, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([text_buffer_object](/api/src/lib/figure_imgui#text-buffer-object)) | inout |  | Buffer. |
| `text` | character(len=*) | in |  | New text. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  text_buffer_set["text_buffer_set"] --> fig_text_set["fig_text_set"]
  text_buffer_set["text_buffer_set"] --> figure_check["figure_check"]
  style text_buffer_set fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### text_buffer_final

The buffer ends: its text is released.

**Attributes**: recursive

```fortran
subroutine text_buffer_final(self)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | type([text_buffer_object](/api/src/lib/figure_imgui#text-buffer-object)) | inout |  | Buffer. |

**Call graph**

```mermaid
flowchart TD
  text_buffer_final["text_buffer_final"] --> fig_text_release["fig_text_release"]
  style text_buffer_final fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_tooltip

A tooltip on the previous widget: `text` shows while the pointer rests on it (after Dear ImGui's usual delay).

```fortran
subroutine ig_tooltip(text)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `text` | character(len=*) | in |  | Text. |

**Call graph**

```mermaid
flowchart TD
  ig_tooltip["ig_tooltip"] --> cstr["cstr"]
  ig_tooltip["ig_tooltip"] --> igBeginItemTooltip["igBeginItemTooltip"]
  ig_tooltip["ig_tooltip"] --> igEndTooltip["igEndTooltip"]
  ig_tooltip["ig_tooltip"] --> igTextUnformatted["igTextUnformatted"]
  style ig_tooltip fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_set_next_item_width

Width of the next widget's field [pixels]; negative: up to that distance from the window's right edge.

```fortran
subroutine ig_set_next_item_width(width)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `width` | real(kind=real64) | in |  | Width [pixels]. |

**Call graph**

```mermaid
flowchart TD
  ig_set_next_item_width["ig_set_next_item_width"] --> igSetNextItemWidth["igSetNextItemWidth"]
  style ig_set_next_item_width fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_text

Plain text (no formatting: compose it with Fortran internal writes).

```fortran
subroutine ig_text(text)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `text` | character(len=*) | in |  | Text. |

**Call graph**

```mermaid
flowchart TD
  ig_text["ig_text"] --> cstr["cstr"]
  ig_text["ig_text"] --> igTextUnformatted["igTextUnformatted"]
  style ig_text fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_same_line

Put the next item on the same line as the previous one; with `offset`, at that distance [pixels] from the
 window's left edge (aligned columns of labels and fields).

```fortran
subroutine ig_same_line(offset)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `offset` | real(kind=real64) | in | optional | Distance from the window's left edge [pixels]. |

**Call graph**

```mermaid
flowchart TD
  ig_same_line["ig_same_line"] --> igSameLine["igSameLine"]
  style ig_same_line fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_text_wrapped

Text wrapped at the right edge of the window or region (help text, long messages).

```fortran
subroutine ig_text_wrapped(text)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `text` | character(len=*) | in |  | Text. |

**Call graph**

```mermaid
flowchart TD
  ig_text_wrapped["ig_text_wrapped"] --> cstr["cstr"]
  ig_text_wrapped["ig_text_wrapped"] --> igPopTextWrapPos["igPopTextWrapPos"]
  ig_text_wrapped["ig_text_wrapped"] --> igPushTextWrapPos["igPushTextWrapPos"]
  ig_text_wrapped["ig_text_wrapped"] --> igTextUnformatted["igTextUnformatted"]
  style ig_text_wrapped fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_text_disabled

Text in the style's disabled colour (a default value, a hint, something that does not apply).

```fortran
subroutine ig_text_disabled(text)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `text` | character(len=*) | in |  | Text. |

**Call graph**

```mermaid
flowchart TD
  ig_text_disabled["ig_text_disabled"] --> cstr["cstr"]
  ig_text_disabled["ig_text_disabled"] --> igGetStyleColorVec4["igGetStyleColorVec4"]
  ig_text_disabled["ig_text_disabled"] --> igPopStyleColor["igPopStyleColor"]
  ig_text_disabled["ig_text_disabled"] --> igPushStyleColor_Vec4["igPushStyleColor_Vec4"]
  ig_text_disabled["ig_text_disabled"] --> igTextUnformatted["igTextUnformatted"]
  style ig_text_disabled fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_text_colored

Text in `color` ([r, g, b] or [r, g, b, a] in [0, 1]); pair a colour with a mark or a word (an error marker), so
 that it does not rest on colour alone.

```fortran
subroutine ig_text_colored(text, color)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `text` | character(len=*) | in |  | Text. |
| `color` | real(kind=real64) | in |  | [r, g, b] or [r, g, b, a]. |

**Call graph**

```mermaid
flowchart TD
  ig_text_colored["ig_text_colored"] --> cstr["cstr"]
  ig_text_colored["ig_text_colored"] --> igPopStyleColor["igPopStyleColor"]
  ig_text_colored["ig_text_colored"] --> igPushStyleColor_Vec4["igPushStyleColor_Vec4"]
  ig_text_colored["ig_text_colored"] --> igTextUnformatted["igTextUnformatted"]
  style ig_text_colored fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_progress_bar

A progress bar (`ProgressBar`), `fraction` of it filled, in [0, 1] (clamped); `fraction` < 0 gives an
 indeterminate bar, a band sliding along it (animated by FIGURE with the frame clock: draw it every frame).
 `label` is written over it (default: the percentage; none for an indeterminate bar); `width` [pixels] (default:
 the width left; negative: up to that distance from the right edge). The same in every mode.

```fortran
subroutine ig_progress_bar(fraction, label, width)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `fraction` | real(kind=real64) | in |  | Done, in [0, 1]; < 0: indeterminate. |
| `label` | character(len=*) | in | optional | Text over the bar. |
| `width` | real(kind=real64) | in | optional | Width [pixels]. |

**Call graph**

```mermaid
flowchart TD
  ig_progress_bar["ig_progress_bar"] --> cstr["cstr"]
  ig_progress_bar["ig_progress_bar"] --> igGetTime["igGetTime"]
  ig_progress_bar["ig_progress_bar"] --> igProgressBar["igProgressBar"]
  style ig_progress_bar fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_separator

Horizontal separator.

```fortran
subroutine ig_separator()
```

**Call graph**

```mermaid
flowchart TD
  ig_separator["ig_separator"] --> igSeparator["igSeparator"]
  style ig_separator fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_show_demo_window

The Dear ImGui demo window (a live catalogue of every widget).

```fortran
subroutine ig_show_demo_window(open)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `open` | logical | inout | optional | Window open (close button). |

**Call graph**

```mermaid
flowchart TD
  ig_show_demo_window["ig_show_demo_window"] --> igShowDemoWindow["igShowDemoWindow"]
  style ig_show_demo_window fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_item_rect

Screen rectangle of the last item [pixels] (tests, custom layout).

```fortran
subroutine ig_item_rect(xmin, ymin, xmax, ymax)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `xmin` | real(kind=real64) | out |  | Left. |
| `ymin` | real(kind=real64) | out |  | Top. |
| `xmax` | real(kind=real64) | out |  | Right. |
| `ymax` | real(kind=real64) | out |  | Bottom. |

**Call graph**

```mermaid
flowchart TD
  test_item_center["test_item_center"] --> ig_item_rect["ig_item_rect"]
  ig_item_rect["ig_item_rect"] --> igGetItemRectMax["igGetItemRectMax"]
  ig_item_rect["ig_item_rect"] --> igGetItemRectMin["igGetItemRectMin"]
  style ig_item_rect fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_image

A texture, pixel row 1 at the top (screen and image-file convention), `width` x `height` pixels (default: the
 texture's size).

```fortran
subroutine ig_image(tex, width, height)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `tex` | type([texture_object](/api/src/lib/figure_texture#texture-object)) | in |  | Texture. |
| `width` | real(kind=real64) | in | optional | Width [pixels]. |
| `height` | real(kind=real64) | in | optional | Height [pixels]. |

**Call graph**

```mermaid
flowchart TD
  ig_image["ig_image"] --> fig_texture_sampling["fig_texture_sampling"]
  ig_image["ig_image"] --> height["height"]
  ig_image["ig_image"] --> igImage["igImage"]
  ig_image["ig_image"] --> texture_ref["texture_ref"]
  ig_image["ig_image"] --> width["width"]
  style ig_image fill:#3e63dd,stroke:#99b,stroke-width:2px
```

## Functions

### ig_begin

Begin a window; always pair with `ig_end`. With `open`, the window has a close button that sets it false.
 `flags` combine `ImGuiWindowFlags_*` with `ior` (`NoTitleBar`, `NoResize`, `NoMove`, `AlwaysAutoResize`,
 `NoBackground`, `NoDecoration`, `NoDocking`, ...).

**Attributes**: recursive

**Returns**: `logical`

```fortran
function ig_begin(name, open, flags) result(visible)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Window name (unique id and title). |
| `open` | logical | inout | optional | Window open. |
| `flags` | integer(kind=int32) | in | optional | `ImGuiWindowFlags_*` (default none). |

**Call graph**

```mermaid
flowchart TD
  ig_begin["ig_begin"] --> cstr["cstr"]
  ig_begin["ig_begin"] --> figure_refused["figure_refused"]
  ig_begin["ig_begin"] --> igBegin["igBegin"]
  style ig_begin fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_begin_side_bar

Begin a bar along one side of the display: a toolbar, a status bar. `side` is `'left'`, `'right'`, `'top'` or
 `'bottom'`; `size` its width (left, right) or height (top, bottom) [pixels]. It is a window without title bar,
 not movable, not resizable, not dockable, which the work area leaves out: a dock space (`ig_dock_space`) and
 the main menu bar's neighbours fill the rest. Declare it every frame, after the main menu bar and before the dock
 space; always pair with `ig_end`. An unknown side is taken as `'left'`.

**Attributes**: recursive

**Returns**: `logical`

```fortran
function ig_begin_side_bar(name, side, size) result(visible)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Window name (unique id). |
| `side` | character(len=*) | in |  | left, right, top, bottom. |
| `size` | real(kind=real64) | in |  | Width or height [pixels]. |

**Call graph**

```mermaid
flowchart TD
  ig_begin_side_bar["ig_begin_side_bar"] --> fig_begin_side_bar["fig_begin_side_bar"]
  ig_begin_side_bar["ig_begin_side_bar"] --> figure_refused["figure_refused"]
  style ig_begin_side_bar fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_focus_window

Bring window `name` forward and give it the keyboard (a docked window: its tab is shown). Not while a popup or a
 modal is open, since focusing another window would close it: then nothing happens and the result is false; ask
 again on a later frame. A window not drawn yet (this frame or before) is not found: ask after its `ig_begin`.

**Returns**: `logical`

```fortran
function ig_focus_window(name) result(focused)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Window name (as given to `ig_begin`, or its `###id` part). |

**Call graph**

```mermaid
flowchart TD
  ig_focus_window["ig_focus_window"] --> cstr["cstr"]
  ig_focus_window["ig_focus_window"] --> igIsPopupOpen_Str["igIsPopupOpen_Str"]
  ig_focus_window["ig_focus_window"] --> igSetWindowFocus_Str["igSetWindowFocus_Str"]
  style ig_focus_window fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_button

A button; true on the frame it is clicked.

**Returns**: `logical`

```fortran
function ig_button(label, width, height) result(pressed)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Label. |
| `width` | real(kind=real64) | in | optional | Width [pixels] (default: fit the label). |
| `height` | real(kind=real64) | in | optional | Height [pixels] (default: fit the label). |

**Call graph**

```mermaid
flowchart TD
  ig_button["ig_button"] --> cstr["cstr"]
  ig_button["ig_button"] --> igButton["igButton"]
  style ig_button fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_tool_button

A workspace button, as Fusion 360's: `icon` (an `ICON_*`) above `label`, larger than it, on a framed, rounded button
 that shades under the pointer. `selected`: framed and tinted in the accent colour, the icon drawn in it (`accent`
 `[r, g, b]` in [0, 1]; default: the style's CheckMark colour). `width`, `height` [pixels]: default as wide as the
 label (at least 4.6 font sizes) and tall enough for the icon (1.8 font sizes) above the label. The text before
 `##` is shown, all of `label` is the id. True on the frame it is clicked; `ig_tooltip` and `ig_item_rect` apply to
 it as to any widget.

**Returns**: `logical`

```fortran
function ig_tool_button(label, icon, width, height, selected, accent) result(clicked)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Label (also its id). |
| `icon` | character(len=*) | in |  | Icon (UTF-8: an ICON_* constant). |
| `width` | real(kind=real64) | in | optional | Width [pixels]. |
| `height` | real(kind=real64) | in | optional | Height [pixels]. |
| `selected` | logical | in | optional | The one shown (default false). |
| `accent` | real(kind=real64) | in | optional | Accent colour. |

**Call graph**

```mermaid
flowchart TD
  ig_tool_button["ig_tool_button"] --> fig_tool_button["fig_tool_button"]
  style ig_tool_button fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_text_size

The size a text takes in the current font [pixels]: width and height (the text before `##` when it is a label):
 buttons of one width, a column as wide as its longest value.

**Returns**: `real(kind=real64)`

```fortran
function ig_text_size(text) result(extent)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `text` | character(len=*) | in |  | Text (UTF-8). |

**Call graph**

```mermaid
flowchart TD
  ig_text_size["ig_text_size"] --> cstr["cstr"]
  ig_text_size["ig_text_size"] --> igCalcTextSize["igCalcTextSize"]
  style ig_text_size fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_checkbox

A check box bound to `value`; true when the user toggled it.

**Returns**: `logical`

```fortran
function ig_checkbox(label, value) result(changed)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Label. |
| `value` | logical | inout |  | Value. |

**Call graph**

```mermaid
flowchart TD
  ig_checkbox["ig_checkbox"] --> cstr["cstr"]
  ig_checkbox["ig_checkbox"] --> igCheckbox["igCheckbox"]
  style ig_checkbox fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_slider_i32

Integer slider; true when the user changed `value`.

**Returns**: `logical`

```fortran
function ig_slider_i32(label, value, vmin, vmax) result(changed)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Label. |
| `value` | integer(kind=int32) | inout |  | Value. |
| `vmin` | integer(kind=int32) | in |  | Minimum. |
| `vmax` | integer(kind=int32) | in |  | Maximum. |

**Call graph**

```mermaid
flowchart TD
  ig_slider_i32["ig_slider_i32"] --> cstr["cstr"]
  ig_slider_i32["ig_slider_i32"] --> igSliderScalar["igSliderScalar"]
  style ig_slider_i32 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_slider_r32

Single-precision slider; true when the user changed `value`.

**Returns**: `logical`

```fortran
function ig_slider_r32(label, value, vmin, vmax) result(changed)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Label. |
| `value` | real(kind=real32) | inout |  | Value. |
| `vmin` | real(kind=real32) | in |  | Minimum. |
| `vmax` | real(kind=real32) | in |  | Maximum. |

**Call graph**

```mermaid
flowchart TD
  ig_slider_r32["ig_slider_r32"] --> cstr["cstr"]
  ig_slider_r32["ig_slider_r32"] --> igSliderScalar["igSliderScalar"]
  style ig_slider_r32 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_slider_r64

Double-precision slider; true when the user changed `value`.

**Returns**: `logical`

```fortran
function ig_slider_r64(label, value, vmin, vmax) result(changed)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Label. |
| `value` | real(kind=real64) | inout |  | Value. |
| `vmin` | real(kind=real64) | in |  | Minimum. |
| `vmax` | real(kind=real64) | in |  | Maximum. |

**Call graph**

```mermaid
flowchart TD
  ig_slider_r64["ig_slider_r64"] --> cstr["cstr"]
  ig_slider_r64["ig_slider_r64"] --> igSliderScalar["igSliderScalar"]
  style ig_slider_r64 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_input_r64

Numeric input field for a real value; true when the user changed it.

**Returns**: `logical`

```fortran
function ig_input_r64(label, value, step, format) result(changed)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Label. |
| `value` | real(kind=real64) | inout |  | Value. |
| `step` | real(kind=real64) | in | optional | +/- buttons step (default: none). |
| `format` | character(len=*) | in | optional | printf format (default '%.6g'). |

**Call graph**

```mermaid
flowchart TD
  ig_input_r64["ig_input_r64"] --> cstr["cstr"]
  ig_input_r64["ig_input_r64"] --> igInputDouble["igInputDouble"]
  style ig_input_r64 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_input_i32

Numeric input field for an integer value; true when the user changed it.

**Returns**: `logical`

```fortran
function ig_input_i32(label, value, step) result(changed)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Label. |
| `value` | integer(kind=int32) | inout |  | Value. |
| `step` | integer(kind=int32) | in | optional | +/- buttons step (default: none). |

**Call graph**

```mermaid
flowchart TD
  ig_input_i32["ig_input_i32"] --> cstr["cstr"]
  ig_input_i32["ig_input_i32"] --> igInputInt["igInputInt"]
  style ig_input_i32 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_input_text

A text field bound to `value`; true when the user edited it. The text can be as long as `value` (its length is
 the field's capacity); trailing blanks are not part of the text (Fortran pads with them). `hint` is shown while
 the field is empty; `flags` combine `ImGuiInputTextFlags_*` with `ior` (`CharsNoBlank`, `CharsDecimal`,
 `CharsScientific`, `ReadOnly`, `EnterReturnsTrue`, ...).

**Returns**: `logical`

```fortran
function ig_input_text(label, value, hint, flags) result(changed)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Label. |
| `value` | character(len=*) | inout |  | Text. |
| `hint` | character(len=*) | in | optional | Shown while the field is empty. |
| `flags` | integer(kind=int32) | in | optional | `ImGuiInputTextFlags_*` (default none). |

**Call graph**

```mermaid
flowchart TD
  ig_input_text["ig_input_text"] --> fig_widget_input_text["fig_widget_input_text"]
  style ig_input_text fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_input_text_multiline

A multi-line text field (`InputTextMultiline`) over `buffer`; true on the frame the user edited the text.
 Enter inserts a newline; the field scrolls when the text is longer than it. Keys (cmd for ctrl on macOS):
 ctrl+z undoes, ctrl+y or ctrl+shift+z redoes, ctrl+a selects all, ctrl+c, ctrl+x and ctrl+v copy, cut and
 paste. `width`, `height` [pixels]: absent or 0, the item width and 8 lines; negative, up to that distance from
 the region's right or bottom edge. `read_only`: the text can be selected and copied, not changed. `tab_input`:
 Tab inserts a tab character (default: it moves to the next widget). `flags` add `ImGuiInputTextFlags_*` with
 `ior` (`WordWrap`, `NoUndoRedo`, ...). The same in every mode; from a task it draws nothing and returns false
 (the task's status becomes `FIG_ERR_STATE`).

**Attributes**: recursive

**Returns**: `logical`

```fortran
function ig_input_text_multiline(label, buffer, width, height, read_only, tab_input, flags) result(changed)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Label (`'##text'`: none shown). |
| `buffer` | type([text_buffer_object](/api/src/lib/figure_imgui#text-buffer-object)) | inout |  | The text. |
| `width` | real(kind=real64) | in | optional | Width [pixels]. |
| `height` | real(kind=real64) | in | optional | Height [pixels]. |
| `read_only` | logical | in | optional | Selection and copy only (default false). |
| `tab_input` | logical | in | optional | Tab inserts a tab (default false). |
| `flags` | integer(kind=int32) | in | optional | More `ImGuiInputTextFlags_*` (default none). |

**Call graph**

```mermaid
flowchart TD
  ig_input_text_multiline["ig_input_text_multiline"] --> fig_widget_input_text_multiline["fig_widget_input_text_multiline"]
  ig_input_text_multiline["ig_input_text_multiline"] --> figure_refused["figure_refused"]
  style ig_input_text_multiline fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_get_clipboard

The clipboard's text (UTF-8), as a paste in a field reads it: the system's in window mode, the program's own in
 headless mode; in remote mode the program's own, which a paste in the page (ctrl+v, cmd+v) sets from the
 browser's clipboard first. `''` before `init*`, for an empty clipboard, or from a task.

**Attributes**: recursive

**Returns**: `character(len=:)`

```fortran
function ig_get_clipboard() result(text)
```

**Call graph**

```mermaid
flowchart TD
  ig_get_clipboard["ig_get_clipboard"] --> fig_get_clipboard["fig_get_clipboard"]
  ig_get_clipboard["ig_get_clipboard"] --> figure_refused["figure_refused"]
  style ig_get_clipboard fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### text_buffer_text

A copy of the text (`''` before any `set` or edit).

**Attributes**: recursive

**Returns**: `character(len=:)`

```fortran
function text_buffer_text(self) result(text)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([text_buffer_object](/api/src/lib/figure_imgui#text-buffer-object)) | in |  | Buffer. |

**Call graph**

```mermaid
flowchart TD
  text_buffer_text["text_buffer_text"] --> fig_text_get["fig_text_get"]
  text_buffer_text["text_buffer_text"] --> fig_text_length["fig_text_length"]
  style text_buffer_text fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### text_buffer_length

The length of the text [bytes] (UTF-8: a character outside ASCII takes 2 to 4).

**Attributes**: recursive

**Returns**: `integer(kind=int64)`

```fortran
function text_buffer_length(self) result(length)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([text_buffer_object](/api/src/lib/figure_imgui#text-buffer-object)) | in |  | Buffer. |

**Call graph**

```mermaid
flowchart TD
  text_buffer_length["text_buffer_length"] --> fig_text_length["fig_text_length"]
  style text_buffer_length fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_combo

A drop-down list of `items`; `current` is the index of the one chosen (1 to `size(items)`; any other value shows
 none chosen). True on the frame the user picks an item (`current` is then its index).

**Returns**: `logical`

```fortran
function ig_combo(label, current, items) result(changed)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Label. |
| `current` | integer(kind=int32) | inout |  | Index of the chosen item. |
| `items` | character(len=*) | in |  | Items (trailing blanks are not shown). |

**Call graph**

```mermaid
flowchart TD
  ig_combo["ig_combo"] --> cstr["cstr"]
  ig_combo["ig_combo"] --> igBeginCombo["igBeginCombo"]
  ig_combo["ig_combo"] --> igEndCombo["igEndCombo"]
  ig_combo["ig_combo"] --> igPopID["igPopID"]
  ig_combo["ig_combo"] --> igPushID_Int["igPushID_Int"]
  ig_combo["ig_combo"] --> igSelectable_Bool["igSelectable_Bool"]
  ig_combo["ig_combo"] --> igSetItemDefaultFocus["igSetItemDefaultFocus"]
  style ig_combo fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_selectable

A line of a list, highlighted when `selected`; true on the frame it is clicked (the program then updates what is
 selected: the line does not change `selected` itself).

**Returns**: `logical`

```fortran
function ig_selectable(label, selected) result(clicked)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Label (also its id). |
| `selected` | logical | in |  | Highlighted. |

**Call graph**

```mermaid
flowchart TD
  ig_selectable["ig_selectable"] --> cstr["cstr"]
  ig_selectable["ig_selectable"] --> igSelectable_Bool["igSelectable_Bool"]
  style ig_selectable fill:#3e63dd,stroke:#99b,stroke-width:2px
```
