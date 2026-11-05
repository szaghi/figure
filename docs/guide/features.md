---
title: Feature map
---

# Feature map

`use figure` exports everything below except the testing procedures (`use figure_testing`). The modules it re-exports
(`figure_app`, `figure_imgui`, `figure_implot`, `figure_dock`, `figure_style`, `figure_texture`, `figure_base`) can
also be used directly; `figure_c_native` and the generated raw modules (`figure_cimgui`,
`figure_cimplot` and their `_enums`) are internal and change without notice ([Raw bindings](raw-bindings)).

All kinds are those of `iso_fortran_env`: `int32`, `real32`, `real64`. Optional arguments are in brackets.

## Application: `app_object`

| Procedure | Purpose | Details |
|---|---|---|
| `app%init(title, width, height [, vsync] [, stat] [, ini_file])` | open the window, create the ImGui and ImPlot contexts | [frame loop](frame-loop#the-application) |
| `app%init_headless(width, height [, stat])` | contexts only, on a virtual display: no window, no GPU | [headless testing](testing) |
| `app%init_remote([port] [, host] ...)` | the interface in a web browser: no window, display or GPU on the program's side | [remote UI](remote) |
| `app%next_frame([stat])` → `logical` | render the open frame, wait for input, open the next; `.false.` on quit | [frame loop](frame-loop#next-frame) |
| `app%set_lazy(enabled [, max_wait])` | lazy redraw on/off, longest sleep (default 0.5 s) | [lazy redraw](frame-loop#lazy-redraw) |
| `app%request_frames(n)` | draw at least `n` more frames without waiting for input | [lazy redraw](frame-loop#lazy-redraw) |
| `app%content_scale()` → `real(real64)` | display content scale | [frame loop](frame-loop#content-scale) |
| `app%set_font(font [, size] [, stat])` | the default font: `'plex-sans'` (default, 15 px), `'proggy'`, or a TTF/OTF file | [styles](styles#fonts) |
| `app%load_style(file [, stat])`, `app%save_style(file [, stat])` | apply a theme file; write the style in effect as one | [styles](styles#load-tune-and-save) |
| `app%set_docking(enabled [, stat])` | docking on (default) or off | [docking](docking) |
| `app%set_style(name [, lines] [, stat])` | colours: `'seal'` (default), `'seal-light'`, `'paper'`, `'high-contrast'`, `'dark'`, `'light'`, `'classic'`; `lines='okabe-ito'` | [styles](styles) |
| `app%destroy()` | close the window, destroy the contexts | [frame loop](frame-loop#the-application) |

## Widgets: `ig_*`

| Procedure | Purpose |
|---|---|
| `ig_begin(name [, open] [, flags])` → `logical` | begin a window (`ImGuiWindowFlags_*`); `.false.` when collapsed or clipped |
| `ig_end()` | end the window (always, whatever `ig_begin` returned) |
| `ig_set_next_window(x, y [, width, height] [, always])` | place (and size) the next window |
| `ig_button(label [, width] [, height])` → `logical` | a button; `.true.` on the frame it is clicked |
| `ig_checkbox(label, value)` → `logical` | a check box bound to a `logical`; `.true.` when toggled |
| `ig_slider(label, value, vmin, vmax)` → `logical` | a slider for `int32`, `real32` or `real64`; `.true.` when changed |
| `ig_input(label, value [, step] [, format])` → `logical` | a numeric field for an `int32` or a `real64` (`format` for reals only); `.true.` when changed |
| `ig_input_text(label, value [, hint] [, flags])` → `logical` | a text field bound to a `character` variable, whose length is the field's capacity; `.true.` when edited |
| `ig_combo(label, current, items)` → `logical` | a drop-down list of the `character` array `items`; `current` is the index chosen; `.true.` when the user picks one |
| `ig_selectable(label, selected)` → `logical` | a line of a list, highlighted when `selected`; `.true.` when clicked |
| `ig_text_wrapped(text)`, `ig_text_disabled(text)`, `ig_text_colored(text, color)` | text wrapped at the region's edge, in the disabled colour, in a given colour |
| `ig_begin_child(id [, width] [, height] [, border])` → `logical`, `ig_end_child()` | a region that scrolls on its own; always paired |
| `ig_begin_main_menu_bar()` → `logical`, `ig_end_main_menu_bar()` | the menu bar along the top of the display; end only after a true begin |
| `ig_begin_menu_bar()` → `logical`, `ig_end_menu_bar()` | a window's own menu bar (`ImGuiWindowFlags_MenuBar`) |
| `ig_begin_menu(label [, enabled])` → `logical`, `ig_end_menu()` | a menu or submenu; `.true.` while open |
| `ig_menu_item(label [, shortcut] [, selected] [, enabled])` → `logical` | a menu item; `.true.` when picked; a check mark with `selected` |
| `ig_shortcut(keys [, stat])` → `logical` | a key chord such as `'ctrl+s'` pressed this frame (cmd on macOS), once per press |
| `ig_tooltip(text)` | a tooltip on the previous widget, shown while the pointer rests on it |
| `ig_collapsing_header(label [, default_open])` → `logical` | a header that shows or hides what follows; `.true.` while open (no end call) |
| `ig_begin_tab_bar(id)` → `logical`, `ig_end_tab_bar()` | a bar of tabs; end it only when the begin returned `.true.` |
| `ig_begin_tab(label [, open])` → `logical`, `ig_end_tab()` | a tab; `.true.` when selected: draw its content, then end it (only then) |
| `ig_begin_table(id, columns [, flags] [, height])` → `logical`, `ig_end_table()` | a table; end it only when the begin returned `.true.` |
| `ig_table_setup_column(label [, width])`, `ig_table_headers_row()` | declare a column (fixed `width`, or a share of the rest); a row of their labels |
| `ig_table_next_row()`, `ig_table_next_column()`, `ig_table_set_column(column)` | start a row; move to the next cell, or to cell `column` (1-based) |
| `ig_push_id(id)`, `ig_pop_id()` | an id scope (`character` or `int32`): the same label in two scopes is two widgets (rows, loops) |
| `ig_begin_disabled([disabled])`, `ig_end_disabled()` | the widgets in between are greyed out and ignore input |
| `ig_set_next_item_width(width)` | width of the next widget's field [pixels]; negative: up to that distance from the right edge |
| `ig_text(text)` | plain text |
| `ig_same_line([offset])` | put the next item on the same line; with `offset`, at that distance from the left edge |
| `ig_separator()` | horizontal separator |
| `ig_show_demo_window([open])` | the Dear ImGui demo window |
| `ig_item_rect(xmin, ymin, xmax, ymax)` | screen rectangle of the last item |

Details: [Widgets](widgets).

## Docking: `ig_dock_*`

| Procedure | Does |
|---|---|
| `ig_dock_id(name)` → `integer(int32)` | the dock id of a name |
| `ig_dock_space(id [, flags] [, stat])` | a dock space over the display, every frame, before its windows |
| `ig_dock_layout_begin(id [, stat])` → `logical` | `.true.` when the dock space needs its layout (first time) |
| `ig_dock_split(id, direction, fraction, id_at_dir, id_other [, stat])` | split a dock node in two |
| `ig_dock_window(name, id [, stat])` | put a window into a dock node of the layout |
| `ig_dock_layout_end(id [, stat])` | finish the layout |
| `ig_window_dock(id, docked)` | inside a window: its dock node and whether it is docked |

Details: [Docking](docking).

## Styles: `ig_/ip_ set_/get_ style_color`, `style_var`

| Procedure | Does |
|---|---|
| `ig_set_style_color(name, color [, stat])`, `ip_set_style_color(...)` | a colour by name (`'#rrggbb[aa]'` or components) |
| `ig_get_style_color(name, rgba [, stat])`, `ip_get_style_color(...)` | a colour by name |
| `ig_set_style_var(name, value [, stat])`, `ip_set_style_var(...)` | a style variable by name (number, pair, logical, integer) |
| `ig_get_style_var(name, values, n [, stat])`, `ip_get_style_var(...)` | a style variable by name |
| `ig_show_style_editor([open] [, stat])` | Dear ImGui's and ImPlot's style editors, in a window |
| `ig_push_font(font [, size] [, stat])`, `ig_pop_font([stat])` | another font or size for a block of widgets |
| `ig_push_style_color(name, color [, stat])`, `ig_pop_style_color([n] [, stat])` | a colour for a block of widgets |
| `ip_push_style_color(name, color [, stat])`, `ip_pop_style_color([n] [, stat])` | a colour for a block of plots |
| `ig_push_style_var(name, value [, stat])`, `ig_pop_style_var([n] [, stat])` | a style variable for a block of widgets |
| `ip_push_style_var(name, value [, stat])`, `ip_pop_style_var([n] [, stat])` | a style variable for a block of plots |

Details: [Styles](styles).

## Plots: `ip_*`

| Procedure | Purpose |
|---|---|
| `ip_begin_plot(title [, width] [, height] [, equal])` → `logical` | begin a plot; `.true.` when visible |
| `ip_setup_axes(xlabel, ylabel [, auto_fit] [, xlog] [, ylog])` | axis labels; the axes fit the data on first use, every frame with `auto_fit=.true.`; `xlog`/`ylog`: logarithmic axes |
| `ip_setup_axes_limits(xmin, xmax, ymin, ymax [, always])` | initial axis ranges |
| `ip_plot_limits(...)`, `ip_plot_size(...)` | the ranges the user panned and zoomed to; the plot's size in pixels |
| `ip_line(label, x, y [, spec] [, stat])` | a line through `(x(i), y(i))` |
| `ip_line(label, y [, xscale, xstart] ...)`, `ip_line(label, y, row ...)` | uniform x; a matrix row read in place |
| `ip_scatter(label, x, y [, spec] [, stat])` | markers at `(x(i), y(i))` |
| `ip_bars(label, x, y, bar_size [, spec] [, stat])` | bars of height `y(i)` at `x(i)` |
| `ip_shaded(label, x, y1, y2 [, spec] [, stat])`, `ip_shaded(label, x, y, yref ...)` | area between two curves, or a curve and `y = yref` |
| `ip_spec(...)` → `plot_spec_object` | item style: colours, line weight, markers, flags (`ImPlotMarker_*`, `ImPlot*Flags_*`) |
| `ip_heatmap(label, f, xmin, xmax, ymin, ymax ...)` | a field `f(i, j)` as coloured cells, read in place, j = 1 at the bottom |
| `ip_colormap_scale(label, scale_min, scale_max ...)` | the colour bar of a heatmap (`ImPlotColormap_*`) |
| `ip_image(label, tex, xmin, xmax, ymin, ymax ...)` | a texture in a plot, pixel row 1 at the bottom |
| `ip_end_plot()` | end the plot (only if `ip_begin_plot` returned `.true.`) |

Items take `real(real32)` or `real(real64)` arrays. Details: [Plots](plots).

## Images: `texture_object`, `ig_image`

| Procedure | Purpose |
|---|---|
| `tex%init(width, height [, smooth] [, stat])`, `tex%update(rgba [, stat])`, `tex%destroy()` | an RGBA texture on the GPU, `integer(int8) :: rgba(4, width, height)` uploaded in place |
| `tex%width()`, `tex%height()` → `integer(int32)`, `tex%is_initialized()` → `logical` | its size (0 before `init`); whether it exists |
| `ig_image(tex [, width, height])` | the texture in a window, pixel row 1 at the top |

Details: [Heatmaps and images](images).

## Testing: `figure_testing`

| Procedure | Does |
|---|---|
| `test_click(x, y [, button])`, `test_drag(x0, y0, x1, y1)` | queue a click, a drag |
| `test_mouse_move`, `test_mouse_button`, `test_wheel` | queue mouse input, one part at a time |
| `test_key(name [, down])`, `test_type(text)` | queue keys and typed text |
| `test_next_frame()` | a frame boundary in the queued input |
| `test_item_center(x, y)`, `test_window_rect(name, ...)` | where a widget or a window is |

Details: [Headless testing](testing#synthetic-input).

## Errors

| Entity | Purpose |
|---|---|
| `FIG_OK`, `FIG_ERR_STATE`, `FIG_ERR_ARGUMENT`, `FIG_ERR_FAILED`, `FIG_ERR_EXCEPTION` | status codes returned in `stat` |
| `figure_last_error()` → `character(len=:), allocatable` | message of the last failure |

Details: [Error handling](errors).

## Environment variables

| Variable | Effect |
|---|---|
| `FIGURE_DEBUG_REDRAW` | any value: once per second, redraw statistics on standard error (window mode) — see [frame loop](frame-loop#redraw-diagnostics) |
| `FIGURE_STYLE` | the style at initialisation: a name of `app%set_style`, or a theme file — see [styles](styles) |
| `FIGURE_CAPTURE`, `FIGURE_CAPTURE_*` | record the frames of a window to image files, with scripted input — see [screenshots and videos](capture) |
| `GALLIUM_DRIVER=d3d12` | not read by FIGURE: on WSL2, makes Mesa render on the GPU — see [installation](install#wsl2-wslg) |
| `SDL_VIDEO_DRIVER` | read by SDL3: `x11` or `wayland` to choose the video driver |
