---
title: Styles
---

# Styles

Every colour and size of the interface and of the plots can be chosen: a whole style by name, or any single colour
or variable of Dear ImGui and ImPlot by its own name.

## Named styles

`app%set_style(name [, lines] [, stat])`, after `init` (or `init_headless`, `init_remote`), sets the colours of the
interface, of the plots and of the window's background:

| Name | Look | Text contrast (lowest) |
|---|---|---|
| `'seal'` | the default: FIGURE's style, from the palette of its mark: ink windows, paper text, vermilion spent only on what the user touches (slider grabs, check marks, pressed buttons) and on the first plotted line; square corners | 7.4:1 |
| `'seal-light'` | the same on paper | 11.7:1 |
| `'paper'` | for publication: black on white, thin borders, a light grid, line colours that keep 3:1 on white and stay apart in greyscale | 15.9:1 |
| `'high-contrast'` | white on black with yellow accents, a border on every frame, colour-blind-safe lines | 12.6:1 |
| `'dark'` | Dear ImGui's dark style, with ImPlot's default line colours | 3.0:1 |
| `'light'`, `'classic'` | Dear ImGui's other two styles | 7.0:1, 4.9:1 |

`lines='okabe-ito'` replaces the style's line colours with Okabe and Ito's colour-blind-safe set (orange, sky blue,
bluish green, yellow, blue, vermilion, reddish purple), whatever the style:

```fortran
call app%init('FIGURE: paper', 900_int32, 600_int32)
call app%set_style('paper')                     ! or: call app%set_style('seal', lines='okabe-ito')
```

The contrast column is measured by `src/tests/figure_test_themes.F90` on the colours in effect, as WCAG 2 defines
it: `Text` against every surface it is drawn on (window, popup, frames, buttons, title bar, header), the lowest
reported. FIGURE's styles are held to a target in the test: 4.5:1 (WCAG AA) for `seal` and `seal-light`, 7:1 (AAA)
for `paper` and `high-contrast`, and 3:1 for every line colour against the plot background (WCAG 1.4.11, graphics).
Dear ImGui's own styles are measured, not held to one: `dark` reaches only 3:1 on a hovered button.

The environment variable `FIGURE_STYLE` picks the style at initialisation, without changing the program
(`FIGURE_STYLE=paper exe/figure_hello`); a `set_style` call in the program comes later and wins. An unknown name or
palette is `FIG_ERR_ARGUMENT` (or a stop, without `stat`). Sizes, spacing and fonts are kept; colours and variables
changed by name (below) or through the raw bindings are reset. Heatmaps are unaffected: their colormap is the one
passed to `ip_heatmap` (the line colours of a style are a qualitative colormap, not meant for fields). In remote mode
the browser takes the style's background too. Every picture of this documentation is recorded in the default style,
`'seal'`.

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

## Changes for a block

A colour or a variable can also change for a few widgets only: push it before them, pop it after. Pushes and pops
pair like `ig_begin` and `ig_end`; one stack holds the colours of both libraries, another the variables.

<<< @/examples/snippets/cb_scoped-red.F90{fortran}

<Media name="cb_scoped" :width="520" alt="A Start button in the theme's colour, a red Stop button, a value shown large, and an undecorated overlay" caption="docs/examples/src/cb_scoped.F90" />

| Procedure | Does |
|---|---|
| `ig_push_style_color(name, color [, stat])` | change a Dear ImGui colour (`'#rrggbb[aa]'` or components) until its pop |
| `ig_pop_style_color([n] [, stat])` | undo the `n` newest colour pushes (default 1) |
| `ig_push_style_var(name, value [, stat])` | change a Dear ImGui style variable until its pop |
| `ig_pop_style_var([n] [, stat])` | undo the `n` newest variable pushes (default 1) |
| `ip_push_style_color`, `ip_pop_style_color`, `ip_push_style_var`, `ip_pop_style_var` | the same for ImPlot |

Every colour and every variable of the [name tables](#colours-and-variables-by-name) can be pushed, not only those
Dear ImGui's own `PushStyleVar` covers. More pops than pushes are `FIG_ERR_STATE`.

## Fonts

The interface is drawn in IBM Plex Sans at 15 logical pixels, a font made for technical interfaces, bundled with
FIGURE (OFL-1.1, [THIRD_PARTY.md](https://github.com/szaghi/figure/blob/main/THIRD_PARTY.md)) and embedded in the
library: programs need no font file.

| Procedure | Does |
|---|---|
| `app%set_font(font [, size] [, stat])` | the default font: `'plex-sans'` (the default), `'proggy'` (Dear ImGui's own 13-pixel bitmap font) or the path of a TrueType/OpenType file; `size` in logical pixels |
| `ig_push_font(font [, size] [, stat])`, `ig_pop_font([stat])` | another font and/or size for the widgets in between (`font=''` keeps the current one): a title, a value shown large |

```fortran
call app%set_font('proggy')                       ! Dear ImGui's classic look
call app%set_font('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 16.0_real64)
call ig_push_font('', 28.0_real64)                ! a big value, in the current font
call ig_text('3.1416')
call ig_pop_font()
```

Fonts are rasterised on demand at every size used (Dear ImGui's dynamic font atlas): any size stays sharp, and the
display's content scale applies on top. A file that cannot be read is `FIG_ERR_FAILED`; one that is not a font, or a
size outside (0, 200], is `FIG_ERR_ARGUMENT`. A theme file can name the font and its size (`font`, `font_size`).

## Theme files

Every named style is a small text file in the repository, `themes/<name>.toml`, embedded in the library when the
native layer is built: adding a file there adds a style. The format is a subset of TOML:

```toml
# FIGURE theme "seal": ink windows, paper text, one vermilion (the default).
base = "dark"                                  # dark | light | classic: the Dear ImGui style it starts from
font = "plex-sans"                             # plex-sans | proggy | a font file (default: the font in effect)
font_size = 15                                 # logical pixels (default: the size in effect)
background = "#14120f"                         # behind the windows (default: the base's)
lines = ["#e8664c", "#e9e2d4", "#c9a25a"]      # ImPlot's line colours, in order, or "okabe-ito" (default: Deep)

[imgui.vars]                                   # ImGuiStyle fields: a number, [x, y], true or false
WindowRounding = 0
FramePadding = [4, 3]

[imgui.colors]                                 # ImGuiCol_* names: "#rrggbb", "#rrggbbaa" or ["#rrggbb", alpha]
Text = "#f6f2ea"
PopupBg = ["#1c1915", 0.97]

[implot.vars]                                  # ImPlotStyle fields
[implot.colors]                                # ImPlotCol_* names
```

- Names are those of [colours and variables by name](#colours-and-variables-by-name); `#` starts a comment.
- Everything not given comes from `base`: a theme lists only what it changes, and a newer Dear ImGui adding style
  colours never leaves a theme incomplete.
- Sizes are in logical pixels, multiplied by the display's content scale when the theme is applied.
- ImPlot's colours not given are derived from Dear ImGui's (ImPlot's automatic colours), so a theme that sets only
  Dear ImGui colours gives matching plots.
- A malformed file is reported with its line: `themes/x.toml:12: unknown Dear ImGui colour "Buton"`.

The built-in themes: [`seal`](https://github.com/szaghi/figure/blob/main/themes/seal.toml),
[`seal-light`](https://github.com/szaghi/figure/blob/main/themes/seal-light.toml),
[`dark`](https://github.com/szaghi/figure/blob/main/themes/dark.toml),
[`light`](https://github.com/szaghi/figure/blob/main/themes/light.toml),
[`classic`](https://github.com/szaghi/figure/blob/main/themes/classic.toml),
[`paper`](https://github.com/szaghi/figure/blob/main/themes/paper.toml),
[`high-contrast`](https://github.com/szaghi/figure/blob/main/themes/high-contrast.toml).

## Load, tune and save

| Procedure | Does |
|---|---|
| `app%load_style(file [, stat])` | apply a theme file; `FIG_ERR_FAILED` if it cannot be read, `FIG_ERR_ARGUMENT` if it is malformed (the message gives file and line) |
| `app%save_style(file [, stat])` | write the style in effect as a theme file: its base, background and line colours, and every colour and variable that differs from the base, including the changes made by name or in the style editor |
| `ig_show_style_editor([open] [, stat])` | Dear ImGui's and ImPlot's own style editors in a window, "Style editor": every colour and size, live |

`FIGURE_STYLE` also takes a file: a value with a `/` or ending in `.toml` is loaded as a theme
(`FIGURE_STYLE=./my-theme.toml exe/figure_hello`).

<Media name="cb_tune" video alt="In the style editor, the frame rounding is dragged up, frame borders ticked, the frame padding widened, then Save theme is pressed" caption="docs/examples/src/cb_tune.F90: the sample window follows the editor live; Save theme writes my-theme.toml" />

<<< @/examples/snippets/cb_tune-tune.F90{fortran}

The file written in the recording above begins:

```toml
# FIGURE theme, written by app%save_style

base = "dark"
background = "#14120f"
lines = ["#e8664c", "#e9e2d4", "#c9a25a", "#7f9cb0", "#8fa06a", "#a77a95", "#d98b6a", "#a3998c"]

[imgui.vars]
FramePadding = [12, 3]
FrameRounding = 6
FrameBorderSize = 1
ScrollbarRounding = 0
GrabRounding = 6
TabRounding = 0
...
```

`save_style` writes sizes in logical pixels (whatever the display's content scale) and colours as 8-bit hex, with
their alpha exact; `load_style` reads the file back to the same style. Edit the file freely: everything not in it
comes from `base`.
