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
- [figure_refused](#figure-refused)
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
  add_mesh["add_mesh"] --> figure_check["figure_check"]
  changed["changed"] --> figure_check["figure_check"]
  clear["clear"] --> figure_check["figure_check"]
  clip["clip"] --> figure_check["figure_check"]
  contour_draw["contour_draw"] --> figure_check["figure_check"]
  draw["draw"] --> figure_check["figure_check"]
  figure_fail["figure_fail"] --> figure_check["figure_check"]
  file_dialog_result["file_dialog_result"] --> figure_check["figure_check"]
  fit["fit"] --> figure_check["figure_check"]
  get_camera["get_camera"] --> figure_check["figure_check"]
  get_color["get_color"] --> figure_check["figure_check"]
  get_var["get_var"] --> figure_check["figure_check"]
  ig_color_edit["ig_color_edit"] --> figure_check["figure_check"]
  ig_dock_layout_begin["ig_dock_layout_begin"] --> figure_check["figure_check"]
  ig_dock_layout_end["ig_dock_layout_end"] --> figure_check["figure_check"]
  ig_dock_space["ig_dock_space"] --> figure_check["figure_check"]
  ig_dock_split["ig_dock_split"] --> figure_check["figure_check"]
  ig_dock_window["ig_dock_window"] --> figure_check["figure_check"]
  ig_pop_font["ig_pop_font"] --> figure_check["figure_check"]
  ig_push_font["ig_push_font"] --> figure_check["figure_check"]
  ig_set_clipboard["ig_set_clipboard"] --> figure_check["figure_check"]
  ig_shortcut["ig_shortcut"] --> figure_check["figure_check"]
  ig_show_style_editor["ig_show_style_editor"] --> figure_check["figure_check"]
  image["image"] --> figure_check["figure_check"]
  image_result["image_result"] --> figure_check["figure_check"]
  init["init"] --> figure_check["figure_check"]
  init["init"] --> figure_check["figure_check"]
  init["init"] --> figure_check["figure_check"]
  init_headless["init_headless"] --> figure_check["figure_check"]
  init_remote["init_remote"] --> figure_check["figure_check"]
  ip_annotation["ip_annotation"] --> figure_check["figure_check"]
  ip_bars_r32["ip_bars_r32"] --> figure_check["figure_check"]
  ip_bars_r64["ip_bars_r64"] --> figure_check["figure_check"]
  ip_colormap["ip_colormap"] --> figure_check["figure_check"]
  ip_colormap_legend["ip_colormap_legend"] --> figure_check["figure_check"]
  ip_colormap_scale["ip_colormap_scale"] --> figure_check["figure_check"]
  ip_drag_line_x["ip_drag_line_x"] --> figure_check["figure_check"]
  ip_drag_line_y["ip_drag_line_y"] --> figure_check["figure_check"]
  ip_drag_point["ip_drag_point"] --> figure_check["figure_check"]
  ip_error_bars_r32["ip_error_bars_r32"] --> figure_check["figure_check"]
  ip_error_bars_r64["ip_error_bars_r64"] --> figure_check["figure_check"]
  ip_heatmap_r32["ip_heatmap_r32"] --> figure_check["figure_check"]
  ip_heatmap_r64["ip_heatmap_r64"] --> figure_check["figure_check"]
  ip_image["ip_image"] --> figure_check["figure_check"]
  ip_line_r32["ip_line_r32"] --> figure_check["figure_check"]
  ip_line_r64["ip_line_r64"] --> figure_check["figure_check"]
  ip_line_row_r32["ip_line_row_r32"] --> figure_check["figure_check"]
  ip_line_row_r64["ip_line_row_r64"] --> figure_check["figure_check"]
  ip_line_values_r32["ip_line_values_r32"] --> figure_check["figure_check"]
  ip_line_values_r64["ip_line_values_r64"] --> figure_check["figure_check"]
  ip_load_colormap["ip_load_colormap"] --> figure_check["figure_check"]
  ip_scatter_r32["ip_scatter_r32"] --> figure_check["figure_check"]
  ip_scatter_r64["ip_scatter_r64"] --> figure_check["figure_check"]
  ip_shaded_r32["ip_shaded_r32"] --> figure_check["figure_check"]
  ip_shaded_r64["ip_shaded_r64"] --> figure_check["figure_check"]
  ip_shaded_ref_r32["ip_shaded_ref_r32"] --> figure_check["figure_check"]
  ip_shaded_ref_r64["ip_shaded_ref_r64"] --> figure_check["figure_check"]
  ip_spec["ip_spec"] --> figure_check["figure_check"]
  load_layout["load_layout"] --> figure_check["figure_check"]
  load_style["load_style"] --> figure_check["figure_check"]
  next_frame["next_frame"] --> figure_check["figure_check"]
  notify["notify"] --> figure_check["figure_check"]
  orbit["orbit"] --> figure_check["figure_check"]
  palette_color["palette_color"] --> figure_check["figure_check"]
  pan["pan"] --> figure_check["figure_check"]
  pop["pop"] --> figure_check["figure_check"]
  process_exit_code["process_exit_code"] --> figure_check["figure_check"]
  process_kill["process_kill"] --> figure_check["figure_check"]
  process_poll["process_poll"] --> figure_check["figure_check"]
  process_start["process_start"] --> figure_check["figure_check"]
  push_color["push_color"] --> figure_check["figure_check"]
  push_var["push_var"] --> figure_check["figure_check"]
  query["query"] --> figure_check["figure_check"]
  remove["remove"] --> figure_check["figure_check"]
  render_info["render_info"] --> figure_check["figure_check"]
  save_image["save_image"] --> figure_check["figure_check"]
  save_layout["save_layout"] --> figure_check["figure_check"]
  save_style["save_style"] --> figure_check["figure_check"]
  scalar_set["scalar_set"] --> figure_check["figure_check"]
  set_camera["set_camera"] --> figure_check["figure_check"]
  set_color["set_color"] --> figure_check["figure_check"]
  set_docking["set_docking"] --> figure_check["figure_check"]
  set_font["set_font"] --> figure_check["figure_check"]
  set_icon_glyph["set_icon_glyph"] --> figure_check["figure_check"]
  set_icon_image["set_icon_image"] --> figure_check["figure_check"]
  set_mesh["set_mesh"] --> figure_check["figure_check"]
  set_style["set_style"] --> figure_check["figure_check"]
  set_title["set_title"] --> figure_check["figure_check"]
  set_var["set_var"] --> figure_check["figure_check"]
  show_file_browser["show_file_browser"] --> figure_check["figure_check"]
  show_file_dialog["show_file_dialog"] --> figure_check["figure_check"]
  style_new["style_new"] --> figure_check["figure_check"]
  task_cancel["task_cancel"] --> figure_check["figure_check"]
  task_result["task_result"] --> figure_check["figure_check"]
  task_start["task_start"] --> figure_check["figure_check"]
  test_click["test_click"] --> figure_check["figure_check"]
  test_drag["test_drag"] --> figure_check["figure_check"]
  test_drawn_extent_name["test_drawn_extent_name"] --> figure_check["figure_check"]
  test_drawn_extent_rgba["test_drawn_extent_rgba"] --> figure_check["figure_check"]
  test_drop["test_drop"] --> figure_check["figure_check"]
  test_frame_hit["test_frame_hit"] --> figure_check["figure_check"]
  test_frame_rect["test_frame_rect"] --> figure_check["figure_check"]
  test_frame_state["test_frame_state"] --> figure_check["figure_check"]
  test_key["test_key"] --> figure_check["figure_check"]
  test_mouse_button["test_mouse_button"] --> figure_check["figure_check"]
  test_mouse_move["test_mouse_move"] --> figure_check["figure_check"]
  test_next_frame["test_next_frame"] --> figure_check["figure_check"]
  test_plot_tick["test_plot_tick"] --> figure_check["figure_check"]
  test_popup_rect["test_popup_rect"] --> figure_check["figure_check"]
  test_quit["test_quit"] --> figure_check["figure_check"]
  test_settings_file["test_settings_file"] --> figure_check["figure_check"]
  test_system_theme["test_system_theme"] --> figure_check["figure_check"]
  test_type["test_type"] --> figure_check["figure_check"]
  test_wheel["test_wheel"] --> figure_check["figure_check"]
  test_window_rect["test_window_rect"] --> figure_check["figure_check"]
  text_buffer_set["text_buffer_set"] --> figure_check["figure_check"]
  unclip["unclip"] --> figure_check["figure_check"]
  update["update"] --> figure_check["figure_check"]
  view["view"] --> figure_check["figure_check"]
  zoom["zoom"] --> figure_check["figure_check"]
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
  alive["alive"] --> figure_fail["figure_fail"]
  colormap_ok["colormap_ok"] --> figure_fail["figure_fail"]
  connectivity_ok["connectivity_ok"] --> figure_fail["figure_fail"]
  contour_draw["contour_draw"] --> figure_fail["figure_fail"]
  contour_ok["contour_ok"] --> figure_fail["figure_fail"]
  drag_ok["drag_ok"] --> figure_fail["figure_fail"]
  field_ok["field_ok"] --> figure_fail["figure_fail"]
  ig_color_edit["ig_color_edit"] --> figure_fail["figure_fail"]
  ig_dock_split["ig_dock_split"] --> figure_fail["figure_fail"]
  ig_push_font["ig_push_font"] --> figure_fail["figure_fail"]
  init_remote["init_remote"] --> figure_fail["figure_fail"]
  ip_annotation["ip_annotation"] --> figure_fail["figure_fail"]
  ip_colormap["ip_colormap"] --> figure_fail["figure_fail"]
  ip_colormap_legend["ip_colormap_legend"] --> figure_fail["figure_fail"]
  ip_image["ip_image"] --> figure_fail["figure_fail"]
  ip_spec["ip_spec"] --> figure_fail["figure_fail"]
  log_set_cap["log_set_cap"] --> figure_fail["figure_fail"]
  notify["notify"] --> figure_fail["figure_fail"]
  points_ok["points_ok"] --> figure_fail["figure_fail"]
  process_exit_code["process_exit_code"] --> figure_fail["figure_fail"]
  process_kill["process_kill"] --> figure_fail["figure_fail"]
  process_poll["process_poll"] --> figure_fail["figure_fail"]
  process_start["process_start"] --> figure_fail["figure_fail"]
  push_color["push_color"] --> figure_fail["figure_fail"]
  push_color_hex["push_color_hex"] --> figure_fail["figure_fail"]
  remove["remove"] --> figure_fail["figure_fail"]
  row_ok["row_ok"] --> figure_fail["figure_fail"]
  series_ok["series_ok"] --> figure_fail["figure_fail"]
  set_color["set_color"] --> figure_fail["figure_fail"]
  set_color_hex["set_color_hex"] --> figure_fail["figure_fail"]
  set_font["set_font"] --> figure_fail["figure_fail"]
  set_icon_image["set_icon_image"] --> figure_fail["figure_fail"]
  set_mesh["set_mesh"] --> figure_fail["figure_fail"]
  show_dialog["show_dialog"] --> figure_fail["figure_fail"]
  style_new["style_new"] --> figure_fail["figure_fail"]
  surface["surface"] --> figure_fail["figure_fail"]
  task_cancel["task_cancel"] --> figure_fail["figure_fail"]
  task_result["task_result"] --> figure_fail["figure_fail"]
  task_start["task_start"] --> figure_fail["figure_fail"]
  test_click["test_click"] --> figure_fail["figure_fail"]
  test_drop["test_drop"] --> figure_fail["figure_fail"]
  test_mouse_button["test_mouse_button"] --> figure_fail["figure_fail"]
  test_system_theme["test_system_theme"] --> figure_fail["figure_fail"]
  update["update"] --> figure_fail["figure_fail"]
  view["view"] --> figure_fail["figure_fail"]
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

### figure_refused

True when called from a task's worker thread: the drawing entry point `name` must return at once. The task's
 status becomes `FIG_ERR_STATE` with a message naming `name` (given by `t%result`), the task is asked to stop, and
 `stat`, if present, is `FIG_ERR_STATE`. False on the main thread (nothing changes).

**Attributes**: recursive

**Returns**: `logical`

```fortran
function figure_refused(name, stat) result(refused)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | The entry point. |
| `stat` | integer(kind=int32) | out | optional | Status, on a refusal. |

**Call graph**

```mermaid
flowchart TD
  changed["changed"] --> figure_refused["figure_refused"]
  clear["clear"] --> figure_refused["figure_refused"]
  clip["clip"] --> figure_refused["figure_refused"]
  clipper_begin["clipper_begin"] --> figure_refused["figure_refused"]
  clipper_step["clipper_step"] --> figure_refused["figure_refused"]
  destroy["destroy"] --> figure_refused["figure_refused"]
  drag_ok["drag_ok"] --> figure_refused["figure_refused"]
  draw["draw"] --> figure_refused["figure_refused"]
  dropped["dropped"] --> figure_refused["figure_refused"]
  file_dialog_result["file_dialog_result"] --> figure_refused["figure_refused"]
  fit["fit"] --> figure_refused["figure_refused"]
  get_camera["get_camera"] --> figure_refused["figure_refused"]
  ig_align_text_to_frame_padding["ig_align_text_to_frame_padding"] --> figure_refused["figure_refused"]
  ig_begin["ig_begin"] --> figure_refused["figure_refused"]
  ig_begin_child["ig_begin_child"] --> figure_refused["figure_refused"]
  ig_begin_disabled["ig_begin_disabled"] --> figure_refused["figure_refused"]
  ig_begin_main_menu_bar["ig_begin_main_menu_bar"] --> figure_refused["figure_refused"]
  ig_begin_menu["ig_begin_menu"] --> figure_refused["figure_refused"]
  ig_begin_menu_bar["ig_begin_menu_bar"] --> figure_refused["figure_refused"]
  ig_begin_popup["ig_begin_popup"] --> figure_refused["figure_refused"]
  ig_begin_popup_modal["ig_begin_popup_modal"] --> figure_refused["figure_refused"]
  ig_begin_side_bar["ig_begin_side_bar"] --> figure_refused["figure_refused"]
  ig_begin_tab["ig_begin_tab"] --> figure_refused["figure_refused"]
  ig_begin_tab_bar["ig_begin_tab_bar"] --> figure_refused["figure_refused"]
  ig_begin_table["ig_begin_table"] --> figure_refused["figure_refused"]
  ig_button["ig_button"] --> figure_refused["figure_refused"]
  ig_checkbox["ig_checkbox"] --> figure_refused["figure_refused"]
  ig_close_current_popup["ig_close_current_popup"] --> figure_refused["figure_refused"]
  ig_collapsing_header["ig_collapsing_header"] --> figure_refused["figure_refused"]
  ig_color_edit["ig_color_edit"] --> figure_refused["figure_refused"]
  ig_combo["ig_combo"] --> figure_refused["figure_refused"]
  ig_dock_layout_begin["ig_dock_layout_begin"] --> figure_refused["figure_refused"]
  ig_dock_layout_end["ig_dock_layout_end"] --> figure_refused["figure_refused"]
  ig_dock_space["ig_dock_space"] --> figure_refused["figure_refused"]
  ig_dock_split["ig_dock_split"] --> figure_refused["figure_refused"]
  ig_dock_window["ig_dock_window"] --> figure_refused["figure_refused"]
  ig_end["ig_end"] --> figure_refused["figure_refused"]
  ig_end_child["ig_end_child"] --> figure_refused["figure_refused"]
  ig_end_disabled["ig_end_disabled"] --> figure_refused["figure_refused"]
  ig_end_main_menu_bar["ig_end_main_menu_bar"] --> figure_refused["figure_refused"]
  ig_end_menu["ig_end_menu"] --> figure_refused["figure_refused"]
  ig_end_menu_bar["ig_end_menu_bar"] --> figure_refused["figure_refused"]
  ig_end_popup["ig_end_popup"] --> figure_refused["figure_refused"]
  ig_end_tab["ig_end_tab"] --> figure_refused["figure_refused"]
  ig_end_tab_bar["ig_end_tab_bar"] --> figure_refused["figure_refused"]
  ig_end_table["ig_end_table"] --> figure_refused["figure_refused"]
  ig_focus_window["ig_focus_window"] --> figure_refused["figure_refused"]
  ig_get_clipboard["ig_get_clipboard"] --> figure_refused["figure_refused"]
  ig_get_style_color["ig_get_style_color"] --> figure_refused["figure_refused"]
  ig_get_style_var["ig_get_style_var"] --> figure_refused["figure_refused"]
  ig_image["ig_image"] --> figure_refused["figure_refused"]
  ig_input_i32["ig_input_i32"] --> figure_refused["figure_refused"]
  ig_input_r64["ig_input_r64"] --> figure_refused["figure_refused"]
  ig_input_text["ig_input_text"] --> figure_refused["figure_refused"]
  ig_input_text_multiline["ig_input_text_multiline"] --> figure_refused["figure_refused"]
  ig_item_rect["ig_item_rect"] --> figure_refused["figure_refused"]
  ig_menu_item["ig_menu_item"] --> figure_refused["figure_refused"]
  ig_open_popup["ig_open_popup"] --> figure_refused["figure_refused"]
  ig_pop_font["ig_pop_font"] --> figure_refused["figure_refused"]
  ig_pop_id["ig_pop_id"] --> figure_refused["figure_refused"]
  ig_pop_style_color["ig_pop_style_color"] --> figure_refused["figure_refused"]
  ig_pop_style_var["ig_pop_style_var"] --> figure_refused["figure_refused"]
  ig_progress_bar["ig_progress_bar"] --> figure_refused["figure_refused"]
  ig_push_font["ig_push_font"] --> figure_refused["figure_refused"]
  ig_push_id_i32["ig_push_id_i32"] --> figure_refused["figure_refused"]
  ig_push_id_str["ig_push_id_str"] --> figure_refused["figure_refused"]
  ig_push_style_color_hex["ig_push_style_color_hex"] --> figure_refused["figure_refused"]
  ig_push_style_color_rgba["ig_push_style_color_rgba"] --> figure_refused["figure_refused"]
  ig_push_style_var_i32["ig_push_style_var_i32"] --> figure_refused["figure_refused"]
  ig_push_style_var_logical["ig_push_style_var_logical"] --> figure_refused["figure_refused"]
  ig_push_style_var_r64["ig_push_style_var_r64"] --> figure_refused["figure_refused"]
  ig_push_style_var_vec2["ig_push_style_var_vec2"] --> figure_refused["figure_refused"]
  ig_same_line["ig_same_line"] --> figure_refused["figure_refused"]
  ig_selectable["ig_selectable"] --> figure_refused["figure_refused"]
  ig_separator["ig_separator"] --> figure_refused["figure_refused"]
  ig_set_clipboard["ig_set_clipboard"] --> figure_refused["figure_refused"]
  ig_set_next_item_open["ig_set_next_item_open"] --> figure_refused["figure_refused"]
  ig_set_next_item_width["ig_set_next_item_width"] --> figure_refused["figure_refused"]
  ig_set_next_window["ig_set_next_window"] --> figure_refused["figure_refused"]
  ig_set_next_window_dock["ig_set_next_window_dock"] --> figure_refused["figure_refused"]
  ig_set_style_color_hex["ig_set_style_color_hex"] --> figure_refused["figure_refused"]
  ig_set_style_color_rgba["ig_set_style_color_rgba"] --> figure_refused["figure_refused"]
  ig_set_style_var_i32["ig_set_style_var_i32"] --> figure_refused["figure_refused"]
  ig_set_style_var_logical["ig_set_style_var_logical"] --> figure_refused["figure_refused"]
  ig_set_style_var_r64["ig_set_style_var_r64"] --> figure_refused["figure_refused"]
  ig_set_style_var_vec2["ig_set_style_var_vec2"] --> figure_refused["figure_refused"]
  ig_shortcut["ig_shortcut"] --> figure_refused["figure_refused"]
  ig_show_demo_window["ig_show_demo_window"] --> figure_refused["figure_refused"]
  ig_show_style_editor["ig_show_style_editor"] --> figure_refused["figure_refused"]
  ig_slider_i32["ig_slider_i32"] --> figure_refused["figure_refused"]
  ig_slider_r32["ig_slider_r32"] --> figure_refused["figure_refused"]
  ig_slider_r64["ig_slider_r64"] --> figure_refused["figure_refused"]
  ig_table_headers_row["ig_table_headers_row"] --> figure_refused["figure_refused"]
  ig_table_next_column["ig_table_next_column"] --> figure_refused["figure_refused"]
  ig_table_next_row["ig_table_next_row"] --> figure_refused["figure_refused"]
  ig_table_set_column["ig_table_set_column"] --> figure_refused["figure_refused"]
  ig_table_setup_column["ig_table_setup_column"] --> figure_refused["figure_refused"]
  ig_text["ig_text"] --> figure_refused["figure_refused"]
  ig_text_colored["ig_text_colored"] --> figure_refused["figure_refused"]
  ig_text_disabled["ig_text_disabled"] --> figure_refused["figure_refused"]
  ig_text_size["ig_text_size"] --> figure_refused["figure_refused"]
  ig_text_wrapped["ig_text_wrapped"] --> figure_refused["figure_refused"]
  ig_tool_button["ig_tool_button"] --> figure_refused["figure_refused"]
  ig_tooltip["ig_tooltip"] --> figure_refused["figure_refused"]
  ig_tree_node["ig_tree_node"] --> figure_refused["figure_refused"]
  ig_tree_pop["ig_tree_pop"] --> figure_refused["figure_refused"]
  ig_window_dock["ig_window_dock"] --> figure_refused["figure_refused"]
  image["image"] --> figure_refused["figure_refused"]
  image_result["image_result"] --> figure_refused["figure_refused"]
  init["init"] --> figure_refused["figure_refused"]
  init["init"] --> figure_refused["figure_refused"]
  init["init"] --> figure_refused["figure_refused"]
  init_headless["init_headless"] --> figure_refused["figure_refused"]
  init_remote["init_remote"] --> figure_refused["figure_refused"]
  ip_annotation["ip_annotation"] --> figure_refused["figure_refused"]
  ip_bars_r32["ip_bars_r32"] --> figure_refused["figure_refused"]
  ip_bars_r64["ip_bars_r64"] --> figure_refused["figure_refused"]
  ip_begin_plot["ip_begin_plot"] --> figure_refused["figure_refused"]
  ip_begin_subplots["ip_begin_subplots"] --> figure_refused["figure_refused"]
  ip_colormap["ip_colormap"] --> figure_refused["figure_refused"]
  ip_colormap_legend["ip_colormap_legend"] --> figure_refused["figure_refused"]
  ip_colormap_names["ip_colormap_names"] --> figure_refused["figure_refused"]
  ip_colormap_scale["ip_colormap_scale"] --> figure_refused["figure_refused"]
  ip_contour_r32["ip_contour_r32"] --> figure_refused["figure_refused"]
  ip_contour_r64["ip_contour_r64"] --> figure_refused["figure_refused"]
  ip_drag_line_x["ip_drag_line_x"] --> figure_refused["figure_refused"]
  ip_drag_line_y["ip_drag_line_y"] --> figure_refused["figure_refused"]
  ip_drag_point["ip_drag_point"] --> figure_refused["figure_refused"]
  ip_end_plot["ip_end_plot"] --> figure_refused["figure_refused"]
  ip_end_subplots["ip_end_subplots"] --> figure_refused["figure_refused"]
  ip_error_bars_r32["ip_error_bars_r32"] --> figure_refused["figure_refused"]
  ip_error_bars_r64["ip_error_bars_r64"] --> figure_refused["figure_refused"]
  ip_get_style_color["ip_get_style_color"] --> figure_refused["figure_refused"]
  ip_get_style_var["ip_get_style_var"] --> figure_refused["figure_refused"]
  ip_heatmap_r32["ip_heatmap_r32"] --> figure_refused["figure_refused"]
  ip_heatmap_r64["ip_heatmap_r64"] --> figure_refused["figure_refused"]
  ip_image["ip_image"] --> figure_refused["figure_refused"]
  ip_line_r32["ip_line_r32"] --> figure_refused["figure_refused"]
  ip_line_r64["ip_line_r64"] --> figure_refused["figure_refused"]
  ip_line_row_r32["ip_line_row_r32"] --> figure_refused["figure_refused"]
  ip_line_row_r64["ip_line_row_r64"] --> figure_refused["figure_refused"]
  ip_line_values_r32["ip_line_values_r32"] --> figure_refused["figure_refused"]
  ip_line_values_r64["ip_line_values_r64"] --> figure_refused["figure_refused"]
  ip_load_colormap["ip_load_colormap"] --> figure_refused["figure_refused"]
  ip_plot_limits["ip_plot_limits"] --> figure_refused["figure_refused"]
  ip_plot_size["ip_plot_size"] --> figure_refused["figure_refused"]
  ip_pop_style_color["ip_pop_style_color"] --> figure_refused["figure_refused"]
  ip_pop_style_var["ip_pop_style_var"] --> figure_refused["figure_refused"]
  ip_push_style_color_hex["ip_push_style_color_hex"] --> figure_refused["figure_refused"]
  ip_push_style_color_rgba["ip_push_style_color_rgba"] --> figure_refused["figure_refused"]
  ip_push_style_var_logical["ip_push_style_var_logical"] --> figure_refused["figure_refused"]
  ip_push_style_var_r64["ip_push_style_var_r64"] --> figure_refused["figure_refused"]
  ip_push_style_var_vec2["ip_push_style_var_vec2"] --> figure_refused["figure_refused"]
  ip_scatter_r32["ip_scatter_r32"] --> figure_refused["figure_refused"]
  ip_scatter_r64["ip_scatter_r64"] --> figure_refused["figure_refused"]
  ip_set_style_color_hex["ip_set_style_color_hex"] --> figure_refused["figure_refused"]
  ip_set_style_color_rgba["ip_set_style_color_rgba"] --> figure_refused["figure_refused"]
  ip_set_style_var_logical["ip_set_style_var_logical"] --> figure_refused["figure_refused"]
  ip_set_style_var_r64["ip_set_style_var_r64"] --> figure_refused["figure_refused"]
  ip_set_style_var_vec2["ip_set_style_var_vec2"] --> figure_refused["figure_refused"]
  ip_setup_axes["ip_setup_axes"] --> figure_refused["figure_refused"]
  ip_setup_axes_limits["ip_setup_axes_limits"] --> figure_refused["figure_refused"]
  ip_shaded_r32["ip_shaded_r32"] --> figure_refused["figure_refused"]
  ip_shaded_r64["ip_shaded_r64"] --> figure_refused["figure_refused"]
  ip_shaded_ref_r32["ip_shaded_ref_r32"] --> figure_refused["figure_refused"]
  ip_shaded_ref_r64["ip_shaded_ref_r64"] --> figure_refused["figure_refused"]
  lines["lines"] --> figure_refused["figure_refused"]
  load_layout["load_layout"] --> figure_refused["figure_refused"]
  load_style["load_style"] --> figure_refused["figure_refused"]
  log_draw["log_draw"] --> figure_refused["figure_refused"]
  next_frame["next_frame"] --> figure_refused["figure_refused"]
  notifications["notifications"] --> figure_refused["figure_refused"]
  notify["notify"] --> figure_refused["figure_refused"]
  open_file_browser["open_file_browser"] --> figure_refused["figure_refused"]
  orbit["orbit"] --> figure_refused["figure_refused"]
  palette_color["palette_color"] --> figure_refused["figure_refused"]
  pan["pan"] --> figure_refused["figure_refused"]
  quads["quads"] --> figure_refused["figure_refused"]
  query["query"] --> figure_refused["figure_refused"]
  remove["remove"] --> figure_refused["figure_refused"]
  render_info["render_info"] --> figure_refused["figure_refused"]
  save_file_browser["save_file_browser"] --> figure_refused["figure_refused"]
  save_image["save_image"] --> figure_refused["figure_refused"]
  save_layout["save_layout"] --> figure_refused["figure_refused"]
  save_style["save_style"] --> figure_refused["figure_refused"]
  set_camera["set_camera"] --> figure_refused["figure_refused"]
  set_docking["set_docking"] --> figure_refused["figure_refused"]
  set_font["set_font"] --> figure_refused["figure_refused"]
  set_icon_glyph["set_icon_glyph"] --> figure_refused["figure_refused"]
  set_icon_image["set_icon_image"] --> figure_refused["figure_refused"]
  set_mesh["set_mesh"] --> figure_refused["figure_refused"]
  set_style["set_style"] --> figure_refused["figure_refused"]
  set_title["set_title"] --> figure_refused["figure_refused"]
  show_dialog["show_dialog"] --> figure_refused["figure_refused"]
  surface["surface"] --> figure_refused["figure_refused"]
  title["title"] --> figure_refused["figure_refused"]
  triangles["triangles"] --> figure_refused["figure_refused"]
  unclip["unclip"] --> figure_refused["figure_refused"]
  update["update"] --> figure_refused["figure_refused"]
  view["view"] --> figure_refused["figure_refused"]
  zoom["zoom"] --> figure_refused["figure_refused"]
  figure_refused["figure_refused"] --> fig_task_refuse["fig_task_refuse"]
  style figure_refused fill:#3e63dd,stroke:#99b,stroke-width:2px
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
  contour_draw["contour_draw"] --> cstr["cstr"]
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
  ig_color_edit["ig_color_edit"] --> cstr["cstr"]
  ig_combo["ig_combo"] --> cstr["cstr"]
  ig_focus_window["ig_focus_window"] --> cstr["cstr"]
  ig_input_i32["ig_input_i32"] --> cstr["cstr"]
  ig_input_r64["ig_input_r64"] --> cstr["cstr"]
  ig_menu_item["ig_menu_item"] --> cstr["cstr"]
  ig_open_popup["ig_open_popup"] --> cstr["cstr"]
  ig_progress_bar["ig_progress_bar"] --> cstr["cstr"]
  ig_push_id_str["ig_push_id_str"] --> cstr["cstr"]
  ig_selectable["ig_selectable"] --> cstr["cstr"]
  ig_slider_i32["ig_slider_i32"] --> cstr["cstr"]
  ig_slider_r32["ig_slider_r32"] --> cstr["cstr"]
  ig_slider_r64["ig_slider_r64"] --> cstr["cstr"]
  ig_table_setup_column["ig_table_setup_column"] --> cstr["cstr"]
  ig_text["ig_text"] --> cstr["cstr"]
  ig_text_colored["ig_text_colored"] --> cstr["cstr"]
  ig_text_disabled["ig_text_disabled"] --> cstr["cstr"]
  ig_text_size["ig_text_size"] --> cstr["cstr"]
  ig_text_wrapped["ig_text_wrapped"] --> cstr["cstr"]
  ig_tooltip["ig_tooltip"] --> cstr["cstr"]
  ig_tree_node["ig_tree_node"] --> cstr["cstr"]
  ip_bars_r32["ip_bars_r32"] --> cstr["cstr"]
  ip_bars_r64["ip_bars_r64"] --> cstr["cstr"]
  ip_begin_plot["ip_begin_plot"] --> cstr["cstr"]
  ip_begin_subplots["ip_begin_subplots"] --> cstr["cstr"]
  ip_colormap_scale["ip_colormap_scale"] --> cstr["cstr"]
  ip_error_bars_r32["ip_error_bars_r32"] --> cstr["cstr"]
  ip_error_bars_r64["ip_error_bars_r64"] --> cstr["cstr"]
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
  log_draw["log_draw"] --> cstr["cstr"]
  style cstr fill:#3e63dd,stroke:#99b,stroke-width:2px
```
