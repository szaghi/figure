---
title: Feature map
---

# Feature map

`use figure` exports everything below. The modules it re-exports (`figure_app`, `figure_imgui`, `figure_implot`,
`figure_base`) can also be used directly; `figure_c_native` and the generated raw modules (`figure_cimgui`,
`figure_cimplot` and their `_enums`) are internal and change without notice ([Raw bindings](raw-bindings)).

All kinds are those of `iso_fortran_env`: `int32`, `real32`, `real64`. Optional arguments are in brackets.

## Application: `app_object`

| Procedure | Purpose | Details |
|---|---|---|
| `app%init(title, width, height [, vsync] [, stat])` | open the window, create the ImGui and ImPlot contexts | [frame loop](frame-loop#the-application) |
| `app%init_headless(width, height [, stat])` | contexts only, on a virtual display: no window, no GPU | [headless testing](testing) |
| `app%init_remote([port] [, host] ...)` | the interface in a web browser: no window, display or GPU on the program's side | [remote UI](remote) |
| `app%next_frame([stat])` → `logical` | render the open frame, wait for input, open the next; `.false.` on quit | [frame loop](frame-loop#next-frame) |
| `app%set_lazy(enabled [, max_wait])` | lazy redraw on/off, longest sleep (default 0.5 s) | [lazy redraw](frame-loop#lazy-redraw) |
| `app%request_frames(n)` | draw at least `n` more frames without waiting for input | [lazy redraw](frame-loop#lazy-redraw) |
| `app%content_scale()` → `real(real64)` | display content scale | [frame loop](frame-loop#content-scale) |
| `app%set_docking(enabled [, stat])` | docking on (default) or off | [docking](docking) |
| `app%set_style(name [, lines] [, stat])` | colours: `'seal'` (default), `'seal-light'`, `'paper'`, `'high-contrast'`, `'dark'`, `'light'`, `'classic'`; `lines='okabe-ito'` | [styles](styles) |
| `app%destroy()` | close the window, destroy the contexts | [frame loop](frame-loop#the-application) |

## Widgets: `ig_*`

| Procedure | Purpose |
|---|---|
| `ig_begin(name [, open])` → `logical` | begin a window; `.false.` when collapsed or clipped |
| `ig_end()` | end the window (always, whatever `ig_begin` returned) |
| `ig_set_next_window(x, y [, width, height] [, always])` | place (and size) the next window |
| `ig_button(label [, width] [, height])` → `logical` | a button; `.true.` on the frame it is clicked |
| `ig_checkbox(label, value)` → `logical` | a check box bound to a `logical`; `.true.` when toggled |
| `ig_slider(label, value, vmin, vmax)` → `logical` | a slider for `int32`, `real32` or `real64`; `.true.` when changed |
| `ig_input(label, value [, step] [, format])` → `logical` | a numeric field for a `real64`; `.true.` when changed |
| `ig_text(text)` | plain text |
| `ig_same_line()` | put the next item on the same line |
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

Details: [Styles](styles).

## Plots: `ip_*`

| Procedure | Purpose |
|---|---|
| `ip_begin_plot(title [, width] [, height] [, equal])` → `logical` | begin a plot; `.true.` when visible |
| `ip_setup_axes(xlabel, ylabel [, auto_fit])` | axis labels; axes refit to the data every frame |
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

## Images: `texture_object`, `ig_image`

| Procedure | Purpose |
|---|---|
| `tex%init(width, height [, smooth])`, `tex%update(rgba)`, `tex%destroy()` | an RGBA texture on the GPU, `integer(int8) :: rgba(4, width, height)` uploaded in place |
| `ig_image(tex [, width, height])` | the texture in a window, pixel row 1 at the top |

Details: [Heatmaps and images](images).
| `ip_end_plot()` | end the plot (only if `ip_begin_plot` returned `.true.`) |

Items take `real(real32)` or `real(real64)` arrays. Details: [Plots](plots).

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
| `FIGURE_STYLE` | the style at initialisation: a name of `app%set_style` — see [styles](styles) |
| `FIGURE_CAPTURE`, `FIGURE_CAPTURE_*` | record the frames of a window to image files, with scripted input — see [screenshots and videos](capture) |
| `GALLIUM_DRIVER=d3d12` | not read by FIGURE: on WSL2, makes Mesa render on the GPU — see [installation](install#wsl2-wslg) |
| `SDL_VIDEO_DRIVER` | read by SDL3: `x11` or `wayland` to choose the video driver |
