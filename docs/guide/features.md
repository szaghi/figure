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
| `app%next_frame([stat])` → `logical` | render the open frame, wait for input, open the next; `.false.` on quit | [frame loop](frame-loop#next-frame) |
| `app%set_lazy(enabled [, max_wait])` | lazy redraw on/off, longest sleep (default 0.5 s) | [lazy redraw](frame-loop#lazy-redraw) |
| `app%request_frames(n)` | draw at least `n` more frames without waiting for input | [lazy redraw](frame-loop#lazy-redraw) |
| `app%content_scale()` → `real(real64)` | display content scale | [frame loop](frame-loop#content-scale) |
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

## Plots: `ip_*`

| Procedure | Purpose |
|---|---|
| `ip_begin_plot(title [, width] [, height])` → `logical` | begin a plot; `.true.` when visible |
| `ip_setup_axes(xlabel, ylabel)` | axis labels |
| `ip_line(label, x, y [, spec] [, stat])` | a line through `(x(i), y(i))` |
| `ip_line(label, y [, xscale, xstart] ...)`, `ip_line(label, y, row ...)` | uniform x; a matrix row read in place |
| `ip_scatter(label, x, y [, spec] [, stat])` | markers at `(x(i), y(i))` |
| `ip_bars(label, x, y, bar_size [, spec] [, stat])` | bars of height `y(i)` at `x(i)` |
| `ip_shaded(label, x, y1, y2 [, spec] [, stat])`, `ip_shaded(label, x, y, yref ...)` | area between two curves, or a curve and `y = yref` |
| `ip_spec(...)` → `plot_spec_object` | item style: colours, line weight, markers, flags (`ImPlotMarker_*`, `ImPlot*Flags_*`) |
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
| `GALLIUM_DRIVER=d3d12` | not read by FIGURE: on WSL2, makes Mesa render on the GPU — see [installation](install#wsl2-wslg) |
| `SDL_VIDEO_DRIVER` | read by SDL3: `x11` or `wayland` to choose the video driver |
