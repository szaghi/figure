---
title: figure_style
---

# figure_style

> figure_style, every colour and variable of the Dear ImGui and ImPlot styles, by name.

 The style is global: a change applies to everything drawn afterwards, until it is changed again (or a new style is
 chosen with `app%set_style`, which resets every colour and variable). Names are the libraries' own:

 - colours: Dear ImGui's `ImGuiCol_*` without the prefix (`Text`, `WindowBg`, `Button`, `SliderGrab`, ...), ImPlot's
   `ImPlotCol_*` without the prefix (`PlotBg`, `AxisGrid`, `LegendBg`, ...);
 - variables: the fields of `ImGuiStyle` (`WindowRounding`, `FramePadding`, `ItemSpacing`, ...) and of `ImPlotStyle`
   (`PlotBorderSize`, `PlotPadding`, `MajorGridSize`, ...), each a number, a pair of numbers, a logical or an integer.
   Line weights and marker sizes are per item in ImPlot 1.2: `ip_spec`.

 Colours are given as `'#rrggbb'` or `'#rrggbbaa'`, or as `[r, g, b]` / `[r, g, b, a]` in [0, 1]. Variables in
 pixels hold the values Dear ImGui uses, already multiplied by the display's content scale (`app%content_scale()`).

**Source**: `src/lib/figure_style.F90`

**Dependencies**

```mermaid
graph LR
  figure_style["figure_style"] --> figure_base["figure_base"]
  figure_style["figure_style"] --> figure_c_native["figure_c_native"]
  figure_style["figure_style"] --> iso_c_binding["iso_c_binding"]
  figure_style["figure_style"] --> iso_fortran_env["iso_fortran_env"]
```

## Contents

- [ig_set_style_color](#ig-set-style-color)
- [ip_set_style_color](#ip-set-style-color)
- [ig_set_style_var](#ig-set-style-var)
- [ip_set_style_var](#ip-set-style-var)
- [ig_push_style_color](#ig-push-style-color)
- [ip_push_style_color](#ip-push-style-color)
- [ig_push_style_var](#ig-push-style-var)
- [ip_push_style_var](#ip-push-style-var)
- [push_color](#push-color)
- [push_color_hex](#push-color-hex)
- [push_var](#push-var)
- [pop](#pop)
- [ig_push_style_color_hex](#ig-push-style-color-hex)
- [ig_push_style_color_rgba](#ig-push-style-color-rgba)
- [ig_pop_style_color](#ig-pop-style-color)
- [ig_push_style_var_r64](#ig-push-style-var-r64)
- [ig_push_style_var_vec2](#ig-push-style-var-vec2)
- [ig_push_style_var_logical](#ig-push-style-var-logical)
- [ig_push_style_var_i32](#ig-push-style-var-i32)
- [ig_pop_style_var](#ig-pop-style-var)
- [ip_push_style_color_hex](#ip-push-style-color-hex)
- [ip_push_style_color_rgba](#ip-push-style-color-rgba)
- [ip_pop_style_color](#ip-pop-style-color)
- [ip_push_style_var_r64](#ip-push-style-var-r64)
- [ip_push_style_var_vec2](#ip-push-style-var-vec2)
- [ip_push_style_var_logical](#ip-push-style-var-logical)
- [ip_pop_style_var](#ip-pop-style-var)
- [ig_show_style_editor](#ig-show-style-editor)
- [ig_push_font](#ig-push-font)
- [ig_pop_font](#ig-pop-font)
- [hex_color](#hex-color)
- [set_color](#set-color)
- [set_color_hex](#set-color-hex)
- [get_color](#get-color)
- [ig_set_style_color_hex](#ig-set-style-color-hex)
- [ig_set_style_color_rgba](#ig-set-style-color-rgba)
- [ig_get_style_color](#ig-get-style-color)
- [ip_set_style_color_hex](#ip-set-style-color-hex)
- [ip_set_style_color_rgba](#ip-set-style-color-rgba)
- [ip_get_style_color](#ip-get-style-color)
- [set_var](#set-var)
- [get_var](#get-var)
- [ig_set_style_var_r64](#ig-set-style-var-r64)
- [ig_set_style_var_vec2](#ig-set-style-var-vec2)
- [ig_set_style_var_logical](#ig-set-style-var-logical)
- [ig_set_style_var_i32](#ig-set-style-var-i32)
- [ig_get_style_var](#ig-get-style-var)
- [ip_set_style_var_r64](#ip-set-style-var-r64)
- [ip_set_style_var_vec2](#ip-set-style-var-vec2)
- [ip_set_style_var_logical](#ip-set-style-var-logical)
- [ip_get_style_var](#ip-get-style-var)

## Variables

| Name | Type | Attributes | Description |
|------|------|------------|-------------|
| `LIB_IMGUI` | integer(kind=c_int) | parameter | Dear ImGui. |
| `LIB_IMPLOT` | integer(kind=c_int) | parameter | ImPlot. |

## Interfaces

### ig_set_style_color

Set a Dear ImGui colour, by hex string or by components.

**Module procedures**: [`ig_set_style_color_hex`](/api/src/lib/figure_style#ig-set-style-color-hex), [`ig_set_style_color_rgba`](/api/src/lib/figure_style#ig-set-style-color-rgba)

### ip_set_style_color

Set an ImPlot colour, by hex string or by components.

**Module procedures**: [`ip_set_style_color_hex`](/api/src/lib/figure_style#ip-set-style-color-hex), [`ip_set_style_color_rgba`](/api/src/lib/figure_style#ip-set-style-color-rgba)

### ig_set_style_var

Set a Dear ImGui style variable: a number, a pair, a logical or an integer.

**Module procedures**: [`ig_set_style_var_r64`](/api/src/lib/figure_style#ig-set-style-var-r64), [`ig_set_style_var_vec2`](/api/src/lib/figure_style#ig-set-style-var-vec2), [`ig_set_style_var_logical`](/api/src/lib/figure_style#ig-set-style-var-logical), [`ig_set_style_var_i32`](/api/src/lib/figure_style#ig-set-style-var-i32)

### ip_set_style_var

Set an ImPlot style variable: a number, a pair or a logical.

**Module procedures**: [`ip_set_style_var_r64`](/api/src/lib/figure_style#ip-set-style-var-r64), [`ip_set_style_var_vec2`](/api/src/lib/figure_style#ip-set-style-var-vec2), [`ip_set_style_var_logical`](/api/src/lib/figure_style#ip-set-style-var-logical)

### ig_push_style_color

Change a Dear ImGui colour until `ig_pop_style_color`, by hex string or by components.

**Module procedures**: [`ig_push_style_color_hex`](/api/src/lib/figure_style#ig-push-style-color-hex), [`ig_push_style_color_rgba`](/api/src/lib/figure_style#ig-push-style-color-rgba)

### ip_push_style_color

Change an ImPlot colour until `ip_pop_style_color`, by hex string or by components.

**Module procedures**: [`ip_push_style_color_hex`](/api/src/lib/figure_style#ip-push-style-color-hex), [`ip_push_style_color_rgba`](/api/src/lib/figure_style#ip-push-style-color-rgba)

### ig_push_style_var

Change a Dear ImGui style variable until `ig_pop_style_var`: a number, a pair, a logical or an integer.

**Module procedures**: [`ig_push_style_var_r64`](/api/src/lib/figure_style#ig-push-style-var-r64), [`ig_push_style_var_vec2`](/api/src/lib/figure_style#ig-push-style-var-vec2), [`ig_push_style_var_logical`](/api/src/lib/figure_style#ig-push-style-var-logical), [`ig_push_style_var_i32`](/api/src/lib/figure_style#ig-push-style-var-i32)

### ip_push_style_var

Change an ImPlot style variable until `ip_pop_style_var`: a number, a pair or a logical.

**Module procedures**: [`ip_push_style_var_r64`](/api/src/lib/figure_style#ip-push-style-var-r64), [`ip_push_style_var_vec2`](/api/src/lib/figure_style#ip-push-style-var-vec2), [`ip_push_style_var_logical`](/api/src/lib/figure_style#ip-push-style-var-logical)

## Subroutines

### push_color

Push a colour given as components (3 or 4).

```fortran
subroutine push_color(lib, who, name, rgba, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `lib` | integer(kind=c_int) | in |  | Library. |
| `who` | character(len=*) | in |  | Caller, for messages. |
| `name` | character(len=*) | in |  | Colour name. |
| `rgba` | real(kind=real64) | in |  | Components. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ig_push_style_color_rgba["ig_push_style_color_rgba"] --> push_color["push_color"]
  ip_push_style_color_rgba["ip_push_style_color_rgba"] --> push_color["push_color"]
  push_color_hex["push_color_hex"] --> push_color["push_color"]
  push_color["push_color"] --> fig_push_style_color["fig_push_style_color"]
  push_color["push_color"] --> figure_check["figure_check"]
  push_color["push_color"] --> figure_fail["figure_fail"]
  style push_color fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### push_color_hex

Push a colour given as a hex string.

```fortran
subroutine push_color_hex(lib, who, name, color, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `lib` | integer(kind=c_int) | in |  | Library. |
| `who` | character(len=*) | in |  | Caller, for messages. |
| `name` | character(len=*) | in |  | Colour name. |
| `color` | character(len=*) | in |  | `'#rrggbb'` or `'#rrggbbaa'`. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ig_push_style_color_hex["ig_push_style_color_hex"] --> push_color_hex["push_color_hex"]
  ip_push_style_color_hex["ip_push_style_color_hex"] --> push_color_hex["push_color_hex"]
  push_color_hex["push_color_hex"] --> figure_fail["figure_fail"]
  push_color_hex["push_color_hex"] --> hex_color["hex_color"]
  push_color_hex["push_color_hex"] --> push_color["push_color"]
  style push_color_hex fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### push_var

Push a style variable of `n` values.

```fortran
subroutine push_var(lib, name, values, n, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `lib` | integer(kind=c_int) | in |  | Library. |
| `name` | character(len=*) | in |  | Variable name. |
| `values` | real(kind=real64) | in |  | Values. |
| `n` | integer(kind=c_int) | in |  | How many. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ig_push_style_var_i32["ig_push_style_var_i32"] --> push_var["push_var"]
  ig_push_style_var_logical["ig_push_style_var_logical"] --> push_var["push_var"]
  ig_push_style_var_r64["ig_push_style_var_r64"] --> push_var["push_var"]
  ig_push_style_var_vec2["ig_push_style_var_vec2"] --> push_var["push_var"]
  ip_push_style_var_logical["ip_push_style_var_logical"] --> push_var["push_var"]
  ip_push_style_var_r64["ip_push_style_var_r64"] --> push_var["push_var"]
  ip_push_style_var_vec2["ip_push_style_var_vec2"] --> push_var["push_var"]
  push_var["push_var"] --> fig_push_style_var["fig_push_style_var"]
  push_var["push_var"] --> figure_check["figure_check"]
  style push_var fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### pop

Undo the `n` newest pushes (default 1) of colours (vars = 0) or variables (vars = 1).

```fortran
subroutine pop(vars, n, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `vars` | integer(kind=c_int) | in |  | 0: colours, 1: variables. |
| `n` | integer(kind=int32) | in | optional | How many (default 1). |
| `stat` | integer(kind=int32) | out | optional | Status: `FIG_ERR_STATE` for more pops than pushes. |

**Call graph**

```mermaid
flowchart TD
  ig_pop_style_color["ig_pop_style_color"] --> pop["pop"]
  ig_pop_style_var["ig_pop_style_var"] --> pop["pop"]
  ip_pop_style_color["ip_pop_style_color"] --> pop["pop"]
  ip_pop_style_var["ip_pop_style_var"] --> pop["pop"]
  pop["pop"] --> fig_pop_style["fig_pop_style"]
  pop["pop"] --> figure_check["figure_check"]
  style pop fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_push_style_color_hex

Change the Dear ImGui colour `name` (`'#rrggbb'` or `'#rrggbbaa'`) until `ig_pop_style_color`.

```fortran
subroutine ig_push_style_color_hex(name, color, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Colour name (`ImGuiCol_*` without the prefix). |
| `color` | character(len=*) | in |  | Hex colour. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ig_push_style_color_hex["ig_push_style_color_hex"] --> push_color_hex["push_color_hex"]
  style ig_push_style_color_hex fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_push_style_color_rgba

Change the Dear ImGui colour `name` (`[r, g, b(, a)]` in [0, 1]) until `ig_pop_style_color`.

```fortran
subroutine ig_push_style_color_rgba(name, rgba, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Colour name. |
| `rgba` | real(kind=real64) | in |  | Components. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ig_push_style_color_rgba["ig_push_style_color_rgba"] --> push_color["push_color"]
  style ig_push_style_color_rgba fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_pop_style_color

Undo the `n` newest colour pushes (default 1); colours pushed by `ig_push_style_color` and `ip_push_style_color`
 share one stack.

```fortran
subroutine ig_pop_style_color(n, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `n` | integer(kind=int32) | in | optional | How many. |
| `stat` | integer(kind=int32) | out | optional |  |

**Call graph**

```mermaid
flowchart TD
  ig_pop_style_color["ig_pop_style_color"] --> pop["pop"]
  style ig_pop_style_color fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_push_style_var_r64

Change a Dear ImGui style variable holding one number until `ig_pop_style_var`.

```fortran
subroutine ig_push_style_var_r64(name, value, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Variable name (a field of `ImGuiStyle`). |
| `value` | real(kind=real64) | in |  | Value. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ig_push_style_var_r64["ig_push_style_var_r64"] --> push_var["push_var"]
  style ig_push_style_var_r64 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_push_style_var_vec2

Change a Dear ImGui style variable holding a pair until `ig_pop_style_var`.

```fortran
subroutine ig_push_style_var_vec2(name, value, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Variable name (a field of `ImGuiStyle`). |
| `value` | real(kind=real64) | in |  | Values (x, y). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ig_push_style_var_vec2["ig_push_style_var_vec2"] --> push_var["push_var"]
  style ig_push_style_var_vec2 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_push_style_var_logical

Change a Dear ImGui style variable holding a logical until `ig_pop_style_var`.

```fortran
subroutine ig_push_style_var_logical(name, value, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Variable name (a field of `ImGuiStyle`). |
| `value` | logical | in |  | Value. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ig_push_style_var_logical["ig_push_style_var_logical"] --> push_var["push_var"]
  style ig_push_style_var_logical fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_push_style_var_i32

Change a Dear ImGui style variable holding an enumeration until `ig_pop_style_var`.

```fortran
subroutine ig_push_style_var_i32(name, value, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Variable name (a field of `ImGuiStyle`). |
| `value` | integer(kind=int32) | in |  | Value. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ig_push_style_var_i32["ig_push_style_var_i32"] --> push_var["push_var"]
  style ig_push_style_var_i32 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_pop_style_var

Undo the `n` newest variable pushes (default 1); variables pushed by `ig_push_style_var` and
 `ip_push_style_var` share one stack.

```fortran
subroutine ig_pop_style_var(n, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `n` | integer(kind=int32) | in | optional | How many. |
| `stat` | integer(kind=int32) | out | optional |  |

**Call graph**

```mermaid
flowchart TD
  ig_pop_style_var["ig_pop_style_var"] --> pop["pop"]
  style ig_pop_style_var fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_push_style_color_hex

Change the ImPlot colour `name` (`'#rrggbb'` or `'#rrggbbaa'`) until `ip_pop_style_color`.

```fortran
subroutine ip_push_style_color_hex(name, color, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Colour name (`ImPlotCol_*` without the prefix). |
| `color` | character(len=*) | in |  | Hex colour. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_push_style_color_hex["ip_push_style_color_hex"] --> push_color_hex["push_color_hex"]
  style ip_push_style_color_hex fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_push_style_color_rgba

Change the ImPlot colour `name` (`[r, g, b(, a)]` in [0, 1]) until `ip_pop_style_color`.

```fortran
subroutine ip_push_style_color_rgba(name, rgba, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Colour name. |
| `rgba` | real(kind=real64) | in |  | Components. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_push_style_color_rgba["ip_push_style_color_rgba"] --> push_color["push_color"]
  style ip_push_style_color_rgba fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_pop_style_color

Undo the `n` newest colour pushes (default 1): the same stack as `ig_pop_style_color`.

```fortran
subroutine ip_pop_style_color(n, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `n` | integer(kind=int32) | in | optional | How many. |
| `stat` | integer(kind=int32) | out | optional |  |

**Call graph**

```mermaid
flowchart TD
  ip_pop_style_color["ip_pop_style_color"] --> pop["pop"]
  style ip_pop_style_color fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_push_style_var_r64

Change an ImPlot style variable holding one number until `ip_pop_style_var`.

```fortran
subroutine ip_push_style_var_r64(name, value, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Variable name (a field of `ImPlotStyle`). |
| `value` | real(kind=real64) | in |  | Value. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_push_style_var_r64["ip_push_style_var_r64"] --> push_var["push_var"]
  style ip_push_style_var_r64 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_push_style_var_vec2

Change an ImPlot style variable holding a pair until `ip_pop_style_var`.

```fortran
subroutine ip_push_style_var_vec2(name, value, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Variable name (a field of `ImPlotStyle`). |
| `value` | real(kind=real64) | in |  | Values (x, y). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_push_style_var_vec2["ip_push_style_var_vec2"] --> push_var["push_var"]
  style ip_push_style_var_vec2 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_push_style_var_logical

Change an ImPlot style variable holding a logical until `ip_pop_style_var`.

```fortran
subroutine ip_push_style_var_logical(name, value, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Variable name (a field of `ImPlotStyle`). |
| `value` | logical | in |  | Value. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ip_push_style_var_logical["ip_push_style_var_logical"] --> push_var["push_var"]
  style ip_push_style_var_logical fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_pop_style_var

Undo the `n` newest variable pushes (default 1): the same stack as `ig_pop_style_var`.

```fortran
subroutine ip_pop_style_var(n, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `n` | integer(kind=int32) | in | optional | How many. |
| `stat` | integer(kind=int32) | out | optional |  |

**Call graph**

```mermaid
flowchart TD
  ip_pop_style_var["ip_pop_style_var"] --> pop["pop"]
  style ip_pop_style_var fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_show_style_editor

Dear ImGui's and ImPlot's style editors, in a window titled "Style editor": every colour and size, live; with
 `open`, the window has a close button that sets it false. Keep a look with `app%save_style`.

```fortran
subroutine ig_show_style_editor(open, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `open` | logical | inout | optional | Window open. |
| `stat` | integer(kind=int32) | out | optional | Status: `FIG_ERR_STATE` outside a frame. |

**Call graph**

```mermaid
flowchart TD
  ig_show_style_editor["ig_show_style_editor"] --> fig_show_style_editor["fig_show_style_editor"]
  ig_show_style_editor["ig_show_style_editor"] --> figure_check["figure_check"]
  style ig_show_style_editor fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_push_font

Switch the font and/or its size for the widgets that follow, until `ig_pop_font`: `font` as `app%set_font`
 (`''` keeps the current one), `size` in logical pixels (absent: keep). Pair every push with a pop.

```fortran
subroutine ig_push_font(font, size, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `font` | character(len=*) | in |  | Font (`'plex-sans'`, `'proggy'`, a file), or `''`. |
| `size` | real(kind=real64) | in | optional | Size [logical pixels], in (0, 200]. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ig_push_font["ig_push_font"] --> fig_push_font["fig_push_font"]
  ig_push_font["ig_push_font"] --> figure_check["figure_check"]
  ig_push_font["ig_push_font"] --> figure_fail["figure_fail"]
  style ig_push_font fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_pop_font

Back to the font before the last `ig_push_font`.

```fortran
subroutine ig_pop_font(stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ig_pop_font["ig_pop_font"] --> fig_pop_font["fig_pop_font"]
  ig_pop_font["ig_pop_font"] --> figure_check["figure_check"]
  style ig_pop_font fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### hex_color

Parse `'#rrggbb'` or `'#rrggbbaa'` (the `#` optional, either case) into components in [0, 1].

**Attributes**: pure

```fortran
subroutine hex_color(text, rgba, ok)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `text` | character(len=*) | in |  | Hex colour. |
| `rgba` | real(kind=real64) | out |  | Components; alpha 1 when not given. |
| `ok` | logical | out |  | The text is a valid colour. |

**Call graph**

```mermaid
flowchart TD
  push_color_hex["push_color_hex"] --> hex_color["hex_color"]
  set_color_hex["set_color_hex"] --> hex_color["hex_color"]
  hex_color["hex_color"] --> digit["digit"]
  style hex_color fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### set_color

Write a colour given as components (3 or 4).

```fortran
subroutine set_color(lib, who, name, rgba, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `lib` | integer(kind=c_int) | in |  | Library. |
| `who` | character(len=*) | in |  | Caller, for messages. |
| `name` | character(len=*) | in |  | Colour name. |
| `rgba` | real(kind=real64) | in |  | Components. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ig_set_style_color_rgba["ig_set_style_color_rgba"] --> set_color["set_color"]
  ip_set_style_color_rgba["ip_set_style_color_rgba"] --> set_color["set_color"]
  set_color_hex["set_color_hex"] --> set_color["set_color"]
  set_color["set_color"] --> fig_style_color["fig_style_color"]
  set_color["set_color"] --> figure_check["figure_check"]
  set_color["set_color"] --> figure_fail["figure_fail"]
  style set_color fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### set_color_hex

Write a colour given as a hex string.

```fortran
subroutine set_color_hex(lib, who, name, color, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `lib` | integer(kind=c_int) | in |  | Library. |
| `who` | character(len=*) | in |  | Caller, for messages. |
| `name` | character(len=*) | in |  | Colour name. |
| `color` | character(len=*) | in |  | `'#rrggbb'` or `'#rrggbbaa'`. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ig_set_style_color_hex["ig_set_style_color_hex"] --> set_color_hex["set_color_hex"]
  ip_set_style_color_hex["ip_set_style_color_hex"] --> set_color_hex["set_color_hex"]
  set_color_hex["set_color_hex"] --> figure_fail["figure_fail"]
  set_color_hex["set_color_hex"] --> hex_color["hex_color"]
  set_color_hex["set_color_hex"] --> set_color["set_color"]
  style set_color_hex fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### get_color

Read a colour.

```fortran
subroutine get_color(lib, name, rgba, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `lib` | integer(kind=c_int) | in |  | Library. |
| `name` | character(len=*) | in |  | Colour name. |
| `rgba` | real(kind=real64) | out |  | Components in [0, 1]. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ig_get_style_color["ig_get_style_color"] --> get_color["get_color"]
  ip_get_style_color["ip_get_style_color"] --> get_color["get_color"]
  get_color["get_color"] --> fig_style_color["fig_style_color"]
  get_color["get_color"] --> figure_check["figure_check"]
  style get_color fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_set_style_color_hex

Set the Dear ImGui colour `name` (`Text`, `WindowBg`, `Button`, ...) from `'#rrggbb'` or `'#rrggbbaa'`.

```fortran
subroutine ig_set_style_color_hex(name, color, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Colour name (`ImGuiCol_*` without the prefix). |
| `color` | character(len=*) | in |  | Hex colour. |
| `stat` | integer(kind=int32) | out | optional |  |

**Call graph**

```mermaid
flowchart TD
  ig_set_style_color_hex["ig_set_style_color_hex"] --> set_color_hex["set_color_hex"]
  style ig_set_style_color_hex fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_set_style_color_rgba

Set the Dear ImGui colour `name` from `[r, g, b]` or `[r, g, b, a]` in [0, 1].

```fortran
subroutine ig_set_style_color_rgba(name, rgba, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Colour name (`ImGuiCol_*` without the prefix). |
| `rgba` | real(kind=real64) | in |  | Components. |
| `stat` | integer(kind=int32) | out | optional |  |

**Call graph**

```mermaid
flowchart TD
  ig_set_style_color_rgba["ig_set_style_color_rgba"] --> set_color["set_color"]
  style ig_set_style_color_rgba fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_get_style_color

The Dear ImGui colour `name`, as `[r, g, b, a]` in [0, 1].

```fortran
subroutine ig_get_style_color(name, rgba, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Colour name. |
| `rgba` | real(kind=real64) | out |  | Components. |
| `stat` | integer(kind=int32) | out | optional |  |

**Call graph**

```mermaid
flowchart TD
  ig_get_style_color["ig_get_style_color"] --> get_color["get_color"]
  style ig_get_style_color fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_set_style_color_hex

Set the ImPlot colour `name` (`PlotBg`, `AxisGrid`, `LegendBg`, ...) from `'#rrggbb'` or `'#rrggbbaa'`.

```fortran
subroutine ip_set_style_color_hex(name, color, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Colour name (`ImPlotCol_*` without the prefix). |
| `color` | character(len=*) | in |  | Hex colour. |
| `stat` | integer(kind=int32) | out | optional |  |

**Call graph**

```mermaid
flowchart TD
  ip_set_style_color_hex["ip_set_style_color_hex"] --> set_color_hex["set_color_hex"]
  style ip_set_style_color_hex fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_set_style_color_rgba

Set the ImPlot colour `name` from `[r, g, b]` or `[r, g, b, a]` in [0, 1].

```fortran
subroutine ip_set_style_color_rgba(name, rgba, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Colour name (`ImPlotCol_*` without the prefix). |
| `rgba` | real(kind=real64) | in |  | Components. |
| `stat` | integer(kind=int32) | out | optional |  |

**Call graph**

```mermaid
flowchart TD
  ip_set_style_color_rgba["ip_set_style_color_rgba"] --> set_color["set_color"]
  style ip_set_style_color_rgba fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_get_style_color

The ImPlot colour `name`, as `[r, g, b, a]` in [0, 1]; ImPlot's automatic colours (derived from Dear ImGui's)
 are returned as ImPlot draws them.

```fortran
subroutine ip_get_style_color(name, rgba, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Colour name. |
| `rgba` | real(kind=real64) | out |  | Components. |
| `stat` | integer(kind=int32) | out | optional |  |

**Call graph**

```mermaid
flowchart TD
  ip_get_style_color["ip_get_style_color"] --> get_color["get_color"]
  style ip_get_style_color fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### set_var

Write a style variable of `n` values.

```fortran
subroutine set_var(lib, name, values, n, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `lib` | integer(kind=c_int) | in |  | Library. |
| `name` | character(len=*) | in |  | Variable name. |
| `values` | real(kind=real64) | in |  | Values. |
| `n` | integer(kind=c_int) | in |  | How many. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ig_set_style_var_i32["ig_set_style_var_i32"] --> set_var["set_var"]
  ig_set_style_var_logical["ig_set_style_var_logical"] --> set_var["set_var"]
  ig_set_style_var_r64["ig_set_style_var_r64"] --> set_var["set_var"]
  ig_set_style_var_vec2["ig_set_style_var_vec2"] --> set_var["set_var"]
  ip_set_style_var_logical["ip_set_style_var_logical"] --> set_var["set_var"]
  ip_set_style_var_r64["ip_set_style_var_r64"] --> set_var["set_var"]
  ip_set_style_var_vec2["ip_set_style_var_vec2"] --> set_var["set_var"]
  set_var["set_var"] --> fig_style_var["fig_style_var"]
  set_var["set_var"] --> figure_check["figure_check"]
  style set_var fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### get_var

Read a style variable.

```fortran
subroutine get_var(lib, name, values, n, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `lib` | integer(kind=c_int) | in |  | Library. |
| `name` | character(len=*) | in |  | Variable name. |
| `values` | real(kind=real64) | out |  | Values (the second is 0 for a single value). |
| `n` | integer(kind=int32) | out |  | How many values the variable has: 1 or 2. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ig_get_style_var["ig_get_style_var"] --> get_var["get_var"]
  ip_get_style_var["ip_get_style_var"] --> get_var["get_var"]
  get_var["get_var"] --> fig_style_var["fig_style_var"]
  get_var["get_var"] --> figure_check["figure_check"]
  style get_var fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_set_style_var_r64

Set a Dear ImGui style variable holding one number (`WindowRounding`, `Alpha`, `IndentSpacing`, ...).

```fortran
subroutine ig_set_style_var_r64(name, value, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Variable name (a field of `ImGuiStyle`). |
| `value` | real(kind=real64) | in |  | Value. |
| `stat` | integer(kind=int32) | out | optional |  |

**Call graph**

```mermaid
flowchart TD
  ig_set_style_var_r64["ig_set_style_var_r64"] --> set_var["set_var"]
  style ig_set_style_var_r64 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_set_style_var_vec2

Set a Dear ImGui style variable holding a pair (`WindowPadding`, `FramePadding`, `ItemSpacing`, ...).

```fortran
subroutine ig_set_style_var_vec2(name, value, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Variable name (a field of `ImGuiStyle`). |
| `value` | real(kind=real64) | in |  | Values (x, y). |
| `stat` | integer(kind=int32) | out | optional |  |

**Call graph**

```mermaid
flowchart TD
  ig_set_style_var_vec2["ig_set_style_var_vec2"] --> set_var["set_var"]
  style ig_set_style_var_vec2 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_set_style_var_logical

Set a Dear ImGui style variable holding a logical (`AntiAliasedLines`, ...).

```fortran
subroutine ig_set_style_var_logical(name, value, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Variable name (a field of `ImGuiStyle`). |
| `value` | logical | in |  | Value. |
| `stat` | integer(kind=int32) | out | optional |  |

**Call graph**

```mermaid
flowchart TD
  ig_set_style_var_logical["ig_set_style_var_logical"] --> set_var["set_var"]
  style ig_set_style_var_logical fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_set_style_var_i32

Set a Dear ImGui style variable holding an enumeration (`WindowMenuButtonPosition`, ...).

```fortran
subroutine ig_set_style_var_i32(name, value, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Variable name (a field of `ImGuiStyle`). |
| `value` | integer(kind=int32) | in |  | Value. |
| `stat` | integer(kind=int32) | out | optional |  |

**Call graph**

```mermaid
flowchart TD
  ig_set_style_var_i32["ig_set_style_var_i32"] --> set_var["set_var"]
  style ig_set_style_var_i32 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_get_style_var

A Dear ImGui style variable: its value(s) and how many it has (1, or 2 for a pair); a logical reads 0 or 1.

```fortran
subroutine ig_get_style_var(name, values, n, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Variable name. |
| `values` | real(kind=real64) | out |  | Values. |
| `n` | integer(kind=int32) | out |  | 1 or 2. |
| `stat` | integer(kind=int32) | out | optional |  |

**Call graph**

```mermaid
flowchart TD
  ig_get_style_var["ig_get_style_var"] --> get_var["get_var"]
  style ig_get_style_var fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_set_style_var_r64

Set an ImPlot style variable holding one number (`PlotBorderSize`, `MinorAlpha`, ...).

```fortran
subroutine ip_set_style_var_r64(name, value, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Variable name (a field of `ImPlotStyle`). |
| `value` | real(kind=real64) | in |  | Value. |
| `stat` | integer(kind=int32) | out | optional |  |

**Call graph**

```mermaid
flowchart TD
  ip_set_style_var_r64["ip_set_style_var_r64"] --> set_var["set_var"]
  style ip_set_style_var_r64 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_set_style_var_vec2

Set an ImPlot style variable holding a pair (`PlotPadding`, `MajorGridSize`, `LegendPadding`, ...).

```fortran
subroutine ip_set_style_var_vec2(name, value, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Variable name (a field of `ImPlotStyle`). |
| `value` | real(kind=real64) | in |  | Values (x, y). |
| `stat` | integer(kind=int32) | out | optional |  |

**Call graph**

```mermaid
flowchart TD
  ip_set_style_var_vec2["ip_set_style_var_vec2"] --> set_var["set_var"]
  style ip_set_style_var_vec2 fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_set_style_var_logical

Set an ImPlot style variable holding a logical (`UseLocalTime`, `UseISO8601`, `Use24HourClock`).

```fortran
subroutine ip_set_style_var_logical(name, value, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Variable name (a field of `ImPlotStyle`). |
| `value` | logical | in |  | Value. |
| `stat` | integer(kind=int32) | out | optional |  |

**Call graph**

```mermaid
flowchart TD
  ip_set_style_var_logical["ip_set_style_var_logical"] --> set_var["set_var"]
  style ip_set_style_var_logical fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ip_get_style_var

An ImPlot style variable: its value(s) and how many it has (1, or 2 for a pair); a logical reads 0 or 1.

```fortran
subroutine ip_get_style_var(name, values, n, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | Variable name. |
| `values` | real(kind=real64) | out |  | Values. |
| `n` | integer(kind=int32) | out |  | 1 or 2. |
| `stat` | integer(kind=int32) | out | optional |  |

**Call graph**

```mermaid
flowchart TD
  ip_get_style_var["ip_get_style_var"] --> get_var["get_var"]
  style ip_get_style_var fill:#3e63dd,stroke:#99b,stroke-width:2px
```
