---
title: Styles
---

# Styles

Every colour and size of the interface and of the plots can be chosen: a whole style by name, or any single colour
or variable of Dear ImGui and ImPlot by its own name.

## Named styles

`app%set_style(name [, stat])`, after `init` (or `init_headless`, `init_remote`), sets the colours of the interface,
of the plots and of the window's background:

| Name | Look |
|---|---|
| `'seal'` | the default: FIGURE's style, from the palette of its mark: ink windows, paper text, vermilion spent only on what the user touches (slider grabs, check marks, pressed buttons) and on the first plotted line; square corners |
| `'seal-light'` | the same on paper |
| `'dark'` | Dear ImGui's dark style, with ImPlot's default line colours |
| `'light'`, `'classic'` | Dear ImGui's other two styles |

```fortran
call app%init('FIGURE: light', 900_int32, 600_int32)
call app%set_style('seal-light')
```

The environment variable `FIGURE_STYLE` picks the style at initialisation, without changing the program
(`FIGURE_STYLE=seal exe/figure_hello`); a `set_style` call in the program comes later and wins. An unknown name is
`FIG_ERR_ARGUMENT` (or a stop, without `stat`). Sizes, spacing and fonts are kept; colours and variables changed by
name (below) or through the raw bindings are reset. Heatmaps are unaffected: their colormap is the one passed to `ip_heatmap` (the line colours of a
style are a qualitative colormap, not meant for fields). In remote mode the browser takes the style's background too.
Every picture of this documentation is recorded in the default style, `'seal'`.

## Colours and variables by name

<Media name="cb_style" alt="A window with a green Run button, an amber check mark and slider grab, rounded frames and a dark-blue plot background" caption="docs/examples/src/cb_style.F90: the default style with seven changes" />

<<< @/examples/snippets/cb_style-style.F90{fortran}

The same program without those lines (`cb_style plain`), in the default style:

<Media name="cb_style_plain" alt="The same window in the default seal style" caption="docs/examples/src/cb_style.F90, run as cb_style plain" />

| Procedure | Does |
|---|---|
| `ig_set_style_color(name, color [, stat])` | a Dear ImGui colour; `color` is `'#rrggbb'`, `'#rrggbbaa'`, or `[r, g, b]` / `[r, g, b, a]` in [0, 1] |
| `ig_get_style_color(name, rgba [, stat])` | a Dear ImGui colour, as `rgba(4)` in [0, 1] |
| `ig_set_style_var(name, value [, stat])` | a Dear ImGui style variable: a `real(real64)`, a pair `real(real64) :: v(2)`, a `logical` or an `integer(int32)`, as the variable holds |
| `ig_get_style_var(name, values, n [, stat])` | a Dear ImGui style variable: `values(2)`, and `n`, how many it holds (1 or 2) |
| `ip_set_style_color`, `ip_get_style_color`, `ip_set_style_var`, `ip_get_style_var` | the same for ImPlot |

**Names** are the libraries' own:

- **colours:** Dear ImGui's `ImGuiCol_*` without the prefix (`Text`, `TextDisabled`, `WindowBg`, `FrameBg`,
  `FrameBgHovered`, `TitleBgActive`, `Button`, `ButtonHovered`, `ButtonActive`, `SliderGrab`, `CheckMark`, `Header`,
  `Separator`, `Tab`, `DockingPreview`, ...), ImPlot's `ImPlotCol_*` without the prefix (`FrameBg`, `PlotBg`,
  `PlotBorder`, `LegendBg`, `LegendText`, `TitleText`, `AxisText`, `AxisGrid`, `Selection`, `Crosshairs`, ...);
- **variables:** the fields of Dear ImGui's `ImGuiStyle` (`Alpha`, `WindowPadding`, `WindowRounding`,
  `WindowBorderSize`, `FramePadding`, `FrameRounding`, `ItemSpacing`, `ItemInnerSpacing`, `IndentSpacing`,
  `ScrollbarSize`, `GrabMinSize`, `GrabRounding`, `TabRounding`, `ButtonTextAlign`, `AntiAliasedLines`, ...) and of
  ImPlot's `ImPlotStyle` (`PlotBorderSize`, `MinorAlpha`, `MajorTickLen`, `MajorGridSize`, `PlotPadding`,
  `LabelPadding`, `LegendPadding`, `FitPadding`, `PlotDefaultSize`, ...). The list is generated from the bound
  libraries' metadata, so every field of the bound version is there (fonts are set through the font API; the colour
  arrays through the colour names). Line weights and marker sizes are per item in ImPlot: [`ip_spec`](plots#item-style).

An unknown name, a malformed colour, a component outside [0, 1] or a pair given to a single-value variable are
`FIG_ERR_ARGUMENT` (or a stop, without `stat`). Variables in pixels hold the values Dear ImGui uses, already
multiplied by the display's content scale ([Content scale](frame-loop#content-scale)).

A change applies to everything drawn afterwards, globally, until it is changed again; `app%set_style` resets them
all to the named style.
