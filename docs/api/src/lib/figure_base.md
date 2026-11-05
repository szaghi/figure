---
title: figure_base
---

# figure_base

> figure_base, error handling and string conversion shared by the FIGURE modules.

 Procedures that can fail take an optional `stat`: if present it receives `FIG_OK` or a `FIG_ERR_*` code and
 `figure_last_error()` gives the message; if absent, a failure prints the message and stops (`error stop`).

**Source**: `src/lib/figure_base.F90`

**Dependencies**

```mermaid
graph LR
  figure_base["figure_base"] --> figure_c_native["figure_c_native"]
  figure_base["figure_base"] --> iso_c_binding["iso_c_binding"]
  figure_base["figure_base"] --> iso_fortran_env["iso_fortran_env"]
```

## Contents

- [figure_check](#figure-check)
- [figure_fail](#figure-fail)
- [figure_last_error](#figure-last-error)
- [cstr](#cstr)

## Subroutines

### figure_check

Store `status` in `stat` if present, else stop on failure with the last error message.

```fortran
subroutine figure_check(status, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `status` | integer(kind=c_int) | in |  | Status from the native layer. |
| `stat` | integer(kind=int32) | out | optional | Status for the caller. |

**Call graph**

```mermaid
flowchart TD
  figure_fail["figure_fail"] --> figure_check["figure_check"]
  file_dialog_result["file_dialog_result"] --> figure_check["figure_check"]
  get_color["get_color"] --> figure_check["figure_check"]
  get_var["get_var"] --> figure_check["figure_check"]
  ig_dock_layout_begin["ig_dock_layout_begin"] --> figure_check["figure_check"]
  ig_dock_layout_end["ig_dock_layout_end"] --> figure_check["figure_check"]
  ig_dock_space["ig_dock_space"] --> figure_check["figure_check"]
  ig_dock_split["ig_dock_split"] --> figure_check["figure_check"]
  ig_dock_window["ig_dock_window"] --> figure_check["figure_check"]
  ig_pop_font["ig_pop_font"] --> figure_check["figure_check"]
  ig_push_font["ig_push_font"] --> figure_check["figure_check"]
  ig_shortcut["ig_shortcut"] --> figure_check["figure_check"]
  ig_show_style_editor["ig_show_style_editor"] --> figure_check["figure_check"]
  init["init"] --> figure_check["figure_check"]
  init["init"] --> figure_check["figure_check"]
  init_headless["init_headless"] --> figure_check["figure_check"]
  init_remote["init_remote"] --> figure_check["figure_check"]
  ip_bars_r32["ip_bars_r32"] --> figure_check["figure_check"]
  ip_bars_r64["ip_bars_r64"] --> figure_check["figure_check"]
  ip_heatmap_r32["ip_heatmap_r32"] --> figure_check["figure_check"]
  ip_heatmap_r64["ip_heatmap_r64"] --> figure_check["figure_check"]
  ip_image["ip_image"] --> figure_check["figure_check"]
  ip_line_r32["ip_line_r32"] --> figure_check["figure_check"]
  ip_line_r64["ip_line_r64"] --> figure_check["figure_check"]
  ip_line_row_r32["ip_line_row_r32"] --> figure_check["figure_check"]
  ip_line_row_r64["ip_line_row_r64"] --> figure_check["figure_check"]
  ip_line_values_r32["ip_line_values_r32"] --> figure_check["figure_check"]
  ip_line_values_r64["ip_line_values_r64"] --> figure_check["figure_check"]
  ip_scatter_r32["ip_scatter_r32"] --> figure_check["figure_check"]
  ip_scatter_r64["ip_scatter_r64"] --> figure_check["figure_check"]
  ip_shaded_r32["ip_shaded_r32"] --> figure_check["figure_check"]
  ip_shaded_r64["ip_shaded_r64"] --> figure_check["figure_check"]
  ip_shaded_ref_r32["ip_shaded_ref_r32"] --> figure_check["figure_check"]
  ip_shaded_ref_r64["ip_shaded_ref_r64"] --> figure_check["figure_check"]
  ip_spec["ip_spec"] --> figure_check["figure_check"]
  load_style["load_style"] --> figure_check["figure_check"]
  next_frame["next_frame"] --> figure_check["figure_check"]
  pop["pop"] --> figure_check["figure_check"]
  push_color["push_color"] --> figure_check["figure_check"]
  push_var["push_var"] --> figure_check["figure_check"]
  save_style["save_style"] --> figure_check["figure_check"]
  set_color["set_color"] --> figure_check["figure_check"]
  set_docking["set_docking"] --> figure_check["figure_check"]
  set_font["set_font"] --> figure_check["figure_check"]
  set_style["set_style"] --> figure_check["figure_check"]
  set_var["set_var"] --> figure_check["figure_check"]
  show_file_dialog["show_file_dialog"] --> figure_check["figure_check"]
  test_click["test_click"] --> figure_check["figure_check"]
  test_drag["test_drag"] --> figure_check["figure_check"]
  test_key["test_key"] --> figure_check["figure_check"]
  test_mouse_button["test_mouse_button"] --> figure_check["figure_check"]
  test_mouse_move["test_mouse_move"] --> figure_check["figure_check"]
  test_next_frame["test_next_frame"] --> figure_check["figure_check"]
  test_plot_tick["test_plot_tick"] --> figure_check["figure_check"]
  test_quit["test_quit"] --> figure_check["figure_check"]
  test_type["test_type"] --> figure_check["figure_check"]
  test_wheel["test_wheel"] --> figure_check["figure_check"]
  test_window_rect["test_window_rect"] --> figure_check["figure_check"]
  update["update"] --> figure_check["figure_check"]
  figure_check["figure_check"] --> figure_last_error["figure_last_error"]
  style figure_check fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### figure_fail

Report a failure detected on the Fortran side: set the last error message, then act as `figure_check`.

```fortran
subroutine figure_fail(status, message, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `status` | integer(kind=c_int) | in |  | Failure status (a `FIG_ERR_*` code). |
| `message` | character(len=*) | in |  | Message for `figure_last_error`. |
| `stat` | integer(kind=int32) | out | optional | Status for the caller. |

**Call graph**

```mermaid
flowchart TD
  field_ok["field_ok"] --> figure_fail["figure_fail"]
  ig_dock_split["ig_dock_split"] --> figure_fail["figure_fail"]
  ig_push_font["ig_push_font"] --> figure_fail["figure_fail"]
  init_remote["init_remote"] --> figure_fail["figure_fail"]
  ip_image["ip_image"] --> figure_fail["figure_fail"]
  ip_spec["ip_spec"] --> figure_fail["figure_fail"]
  push_color["push_color"] --> figure_fail["figure_fail"]
  push_color_hex["push_color_hex"] --> figure_fail["figure_fail"]
  row_ok["row_ok"] --> figure_fail["figure_fail"]
  series_ok["series_ok"] --> figure_fail["figure_fail"]
  set_color["set_color"] --> figure_fail["figure_fail"]
  set_color_hex["set_color_hex"] --> figure_fail["figure_fail"]
  set_font["set_font"] --> figure_fail["figure_fail"]
  test_click["test_click"] --> figure_fail["figure_fail"]
  test_mouse_button["test_mouse_button"] --> figure_fail["figure_fail"]
  update["update"] --> figure_fail["figure_fail"]
  figure_fail["figure_fail"] --> fig_set_last_error["fig_set_last_error"]
  figure_fail["figure_fail"] --> figure_check["figure_check"]
  style figure_fail fill:#3e63dd,stroke:#99b,stroke-width:2px
```

## Functions

### figure_last_error

Message of the last failed call.

**Returns**: `character(len=:)`

```fortran
function figure_last_error() result(msg)
```

**Call graph**

```mermaid
flowchart TD
  figure_check["figure_check"] --> figure_last_error["figure_last_error"]
  figure_last_error["figure_last_error"] --> fig_last_error["fig_last_error"]
  style figure_last_error fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### cstr

`s` NUL-terminated, for cimgui/cimplot (trailing blanks kept: labels are taken verbatim).

**Attributes**: pure

**Returns**: `character(kind=c_char, len=:)`

```fortran
function cstr(s) result(c)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `s` | character(len=*) | in |  | Fortran string. |

**Call graph**

```mermaid
flowchart TD
  ig_begin["ig_begin"] --> cstr["cstr"]
  ig_begin_child["ig_begin_child"] --> cstr["cstr"]
  ig_begin_menu["ig_begin_menu"] --> cstr["cstr"]
  ig_begin_popup["ig_begin_popup"] --> cstr["cstr"]
  ig_begin_popup_modal["ig_begin_popup_modal"] --> cstr["cstr"]
  ig_begin_tab["ig_begin_tab"] --> cstr["cstr"]
  ig_begin_tab_bar["ig_begin_tab_bar"] --> cstr["cstr"]
  ig_begin_table["ig_begin_table"] --> cstr["cstr"]
  ig_button["ig_button"] --> cstr["cstr"]
  ig_checkbox["ig_checkbox"] --> cstr["cstr"]
  ig_collapsing_header["ig_collapsing_header"] --> cstr["cstr"]
  ig_combo["ig_combo"] --> cstr["cstr"]
  ig_input_i32["ig_input_i32"] --> cstr["cstr"]
  ig_input_r64["ig_input_r64"] --> cstr["cstr"]
  ig_menu_item["ig_menu_item"] --> cstr["cstr"]
  ig_open_popup["ig_open_popup"] --> cstr["cstr"]
  ig_push_id_str["ig_push_id_str"] --> cstr["cstr"]
  ig_selectable["ig_selectable"] --> cstr["cstr"]
  ig_slider_i32["ig_slider_i32"] --> cstr["cstr"]
  ig_slider_r32["ig_slider_r32"] --> cstr["cstr"]
  ig_slider_r64["ig_slider_r64"] --> cstr["cstr"]
  ig_table_setup_column["ig_table_setup_column"] --> cstr["cstr"]
  ig_text["ig_text"] --> cstr["cstr"]
  ig_text_colored["ig_text_colored"] --> cstr["cstr"]
  ig_text_disabled["ig_text_disabled"] --> cstr["cstr"]
  ig_text_wrapped["ig_text_wrapped"] --> cstr["cstr"]
  ig_tooltip["ig_tooltip"] --> cstr["cstr"]
  ip_bars_r32["ip_bars_r32"] --> cstr["cstr"]
  ip_bars_r64["ip_bars_r64"] --> cstr["cstr"]
  ip_begin_plot["ip_begin_plot"] --> cstr["cstr"]
  ip_begin_subplots["ip_begin_subplots"] --> cstr["cstr"]
  ip_colormap_scale["ip_colormap_scale"] --> cstr["cstr"]
  ip_heatmap_r32["ip_heatmap_r32"] --> cstr["cstr"]
  ip_heatmap_r64["ip_heatmap_r64"] --> cstr["cstr"]
  ip_image["ip_image"] --> cstr["cstr"]
  ip_line_r32["ip_line_r32"] --> cstr["cstr"]
  ip_line_r64["ip_line_r64"] --> cstr["cstr"]
  ip_line_row_r32["ip_line_row_r32"] --> cstr["cstr"]
  ip_line_row_r64["ip_line_row_r64"] --> cstr["cstr"]
  ip_line_values_r32["ip_line_values_r32"] --> cstr["cstr"]
  ip_line_values_r64["ip_line_values_r64"] --> cstr["cstr"]
  ip_scatter_r32["ip_scatter_r32"] --> cstr["cstr"]
  ip_scatter_r64["ip_scatter_r64"] --> cstr["cstr"]
  ip_setup_axes["ip_setup_axes"] --> cstr["cstr"]
  ip_shaded_r32["ip_shaded_r32"] --> cstr["cstr"]
  ip_shaded_r64["ip_shaded_r64"] --> cstr["cstr"]
  ip_shaded_ref_r32["ip_shaded_ref_r32"] --> cstr["cstr"]
  ip_shaded_ref_r64["ip_shaded_ref_r64"] --> cstr["cstr"]
  style cstr fill:#3e63dd,stroke:#99b,stroke-width:2px
```
