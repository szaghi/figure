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

- [ig_slider](#ig-slider)
- [ig_end](#ig-end)
- [ig_set_next_window](#ig-set-next-window)
- [ig_text](#ig-text)
- [ig_same_line](#ig-same-line)
- [ig_separator](#ig-separator)
- [ig_show_demo_window](#ig-show-demo-window)
- [ig_item_rect](#ig-item-rect)
- [ig_image](#ig-image)
- [ig_begin](#ig-begin)
- [ig_button](#ig-button)
- [ig_checkbox](#ig-checkbox)
- [ig_slider_i32](#ig-slider-i32)
- [ig_slider_r32](#ig-slider-r32)
- [ig_slider_r64](#ig-slider-r64)
- [ig_input](#ig-input)

## Interfaces

### ig_slider

Slider for an integer or a real value.

**Module procedures**: [`ig_slider_i32`](/api/src/lib/figure_imgui#ig-slider-i32), [`ig_slider_r32`](/api/src/lib/figure_imgui#ig-slider-r32), [`ig_slider_r64`](/api/src/lib/figure_imgui#ig-slider-r64)

## Subroutines

### ig_end

End the window opened by `ig_begin` (whatever it returned).

```fortran
subroutine ig_end()
```

**Call graph**

```mermaid
flowchart TD
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

Put the next item on the same line as the previous one.

```fortran
subroutine ig_same_line()
```

**Call graph**

```mermaid
flowchart TD
  ig_same_line["ig_same_line"] --> igSameLine["igSameLine"]
  style ig_same_line fill:#3e63dd,stroke:#99b,stroke-width:2px
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
  ig_begin["ig_begin"] --> igBegin["igBegin"]
  style ig_begin fill:#3e63dd,stroke:#99b,stroke-width:2px
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

### ig_input

Numeric input field for a real value; true when the user changed it.

**Returns**: `logical`

```fortran
function ig_input(label, value, step, format) result(changed)
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
  ig_input["ig_input"] --> cstr["cstr"]
  ig_input["ig_input"] --> igInputDouble["igInputDouble"]
  style ig_input fill:#3e63dd,stroke:#99b,stroke-width:2px
```
