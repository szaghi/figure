---
title: Styles
---

# Styles

Every colour and size of the interface and of the plots can be chosen: a whole style by name; its two parts, a
**look** (the geometry: rounding, padding, spacing, borders) and a **palette** (the colours), each by name; or any
single colour or variable of Dear ImGui and ImPlot by its own name.

## Named styles

`app%set_style(name [, lines] [, stat])`, after `init` (or `init_headless`, `init_remote`), sets the geometry and
the colours of the interface, of the plots and of the window's background:

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

<<< @/examples/snippets/cb_controls-style.F90{fortran}

The contrast column is measured by `src/tests/figure_test_themes.F90` on the colours in effect, as WCAG 2 defines
it: `Text` against every surface it is drawn on (window, popup, frames, buttons, title bar, header), the lowest
reported. FIGURE's styles are held to a target in the test: 4.5:1 (WCAG AA) for `seal` and `seal-light`, 7:1 (AAA)
for `paper` and `high-contrast`, and 3:1 for every line colour against the plot background (WCAG 1.4.11, graphics).
Dear ImGui's own styles are measured, not held to one: `dark` reaches only 3:1 on a hovered button.

Each of FIGURE's four styles is a look and a palette: the look `seal` with the palette of the same name (`paper` and
`high-contrast` add borders to it). Dear ImGui's three are its own geometry with its own colours, no palette. The
same test holds every built-in style to recorded colours and sizes, bit for bit: those it had before styles were split
into looks and palettes, but for the two changes of v0.3.0 below ([palettes](#palettes)), recorded again with them.

The environment variable `FIGURE_STYLE` picks the style at initialisation, without changing the program
(`FIGURE_STYLE=paper exe/examples/figure_hello`); a `set_style` call in the program comes later and wins. An unknown
name or palette is `FIG_ERR_ARGUMENT` (or a stop, without `stat`). The font and its size are kept; every other colour
and variable comes from the style (its base and its theme file), so changes made by name (below) or through the raw
bindings are reset. Heatmaps are unaffected: their colormap is the one
passed to `ip_heatmap` (the line colours of a style are a qualitative colormap, not meant for fields). In remote mode
the browser takes the style's background too. Every picture of this documentation is recorded in the default style,
`'seal'`; the [gallery](#gallery) shows the others.

## Gallery

One program, [`docs/examples/src/gallery.F90`](https://github.com/szaghi/figure/blob/main/docs/examples/src/gallery.F90)
(a docked layout: controls, five plotted lines, a heatmap with its colour bar), in every built-in style. The heatmap
keeps its own colormap (Viridis) in all of them; the lines take the style's.

<Media name="gallery-cycle" video alt="The gallery program switching through the seven built-in styles, one and a half seconds each" caption="The seven styles in turn: seal, seal-light, paper, high-contrast, dark, light, classic" />

<div class="fig-gallery">
<Media name="gallery-seal" alt="The gallery in the seal style: ink windows, vermilion accents" caption="seal: the default" />
<Media name="gallery-seal-light" alt="The gallery in the seal-light style: paper windows, ink text" caption="seal-light" />
<Media name="gallery-paper" alt="The gallery in the paper style: black on white, thin borders" caption="paper: for publication" />
<Media name="gallery-high-contrast" alt="The gallery in the high-contrast style: white on black, yellow accents" caption="high-contrast" />
<Media name="gallery-dark" alt="The gallery in Dear ImGui's dark style" caption="dark: Dear ImGui's" />
<Media name="gallery-light" alt="The gallery in Dear ImGui's light style" caption="light: Dear ImGui's" />
<Media name="gallery-classic" alt="The gallery in Dear ImGui's classic style" caption="classic: Dear ImGui's" />
</div>

## Looks and palettes

A style has two parts, chosen separately:

- a **look**: the geometry, the variables of Dear ImGui (`ImGuiStyle`) and ImPlot (`ImPlotStyle`) that size and shape
  the widgets: rounding, padding, spacing, border widths, the scroll bar;
- a **palette**: the colours, twelve [roles](#palette-roles) from which every colour of Dear ImGui and ImPlot is
  [derived](#how-the-colours-are-derived), plus the window's background and the line colours of the plots.

| Procedure | Does |
|---|---|
| `app%set_style([name] [, lines] [, stat] [, look] [, palette] [, auto_dark] [, auto_light])` | a named style, then a look, then a palette, then line colours: each argument optional, what is not given is kept |
| `app%palette_color(role, rgba [, stat])` | the colour of a role of the palette in effect, `rgba(4)` in [0, 1] |
| `test_system_theme(theme [, stat])` | (`figure_testing`) the system's light or dark setting changes at the next frame: `'light'`, `'dark'`, `'system'` |

<<< @/examples/snippets/cb_palette-pair.F90{fortran}

<Media name="cb_palette" :width="560" alt="A window in the fluent look and the Nord palette: rounded buttons and fields on blue-grey, a light-blue check mark and slider grab, three status lines marked [ok] in green, (!) in yellow and [!!] in red, and a plot of three residuals in blue, green and yellow" caption="docs/examples/src/cb_palette.F90: look fluent, palette nord" />

- **Changing one part keeps the other:** `look=` replaces every variable and keeps the colours; `palette=` replaces
  every colour, the window's background and the line colours, and keeps the variables. A `name` sets both, then
  `look` and `palette` replace their part of it.
- **All or none:** the arguments are checked before anything changes; an unknown name, look or palette, or a palette
  below the [contrast rule](#the-contrast-rule), is `FIG_ERR_ARGUMENT` (or a stop, without `stat`) and leaves the
  style in effect as it was. A call with no argument is `FIG_ERR_ARGUMENT` too.
- **Names without their trailing blanks:** a name, look, palette or line palette is taken without its trailing blanks,
  so an element of a blank-padded array (`looks(k)`) needs no `trim`. The same holds for every name FIGURE takes: a
  font or its file (`set_font`, `ig_push_font`), a theme file (`load_style`, `save_style`), a palette role
  (`palette_color`), a colour or variable [by name](#colours-and-variables-by-name), a colormap and its file
  (`ip_colormap`, `ip_load_colormap`).
- Colours and variables changed [by name](#colours-and-variables-by-name) are reset by the part that sets them: a
  new palette resets the colours, a new look the variables. The font and its size are never changed.
- **Modes:** the same in window, headless and remote mode (in remote mode the browser takes the palette's
  background); only `palette='auto'` [differs](#follow-the-system-s-light-or-dark-setting).

### Looks

<Media name="looks" alt="The same small window four times, side by side, in the palette seal: in the look seal with square corners and compact spacing; in fusion with corners rounded by 2 pixels, framed fields and dense rows; in adwaita with rounder corners, round slider grabs, more padding and no window border; in fluent with medium rounding, framed fields and round grabs" caption="docs/examples/src/gallery.F90, run as gallery looks: seal, fusion, adwaita, fluent" />

| Look | Close to | Geometry |
|---|---|---|
| `'seal'` | FIGURE's own (the default) | square corners, Dear ImGui's compact spacing |
| `'fusion'` | Qt's Fusion style | corners of 2 pixels, a border on fields and windows, dense rows |
| `'adwaita'` | GNOME's Adwaita (GTK 4) | corners of 6 to 10 pixels, round slider grabs and scroll bars, roomy padding, no borders on fields and windows |
| `'fluent'` | Windows 11 (Fluent 2) | corners of 4 pixels on controls and 8 on windows, framed fields, round slider grabs |

Dear ImGui draws no gradients, shadows or translucency effects: a look reproduces the proportions of its model, not
its rendering. Each look is a file, `themes/looks/<name>.toml`, with `[imgui.vars]`, `[implot.vars]` and
`[figure.vars]` only (sizes in logical pixels), embedded in the library; a style without a look (`'dark'`, `'light'`,
`'classic'`) has Dear ImGui's own geometry.

**FIGURE's own variables** (`[figure.vars]` of a look or a theme file): `TitleBarHeight`, the height of the title bar
FIGURE draws with `decorations='figure'` ([the window's frame](frame-loop#the-window-s-frame)), in logical pixels in
[0, 200]; 0, or absent, is the default: the menu bar's height (Dear ImGui's frame height, the font plus twice
`FramePadding`'s height). A height below the menu bar's is the menu bar's. The bundled looks set none. A new look
sets it again (to the look's, or the default), as it does every other variable; `app%save_style` writes it when it
differs from the look's.

### Palettes

<Media name="palettes" alt="Fourteen small windows in a grid, one per bundled palette, each with its name in the title bar: text and dimmed text, a button, a check box, a selected line, a slider, a status line marked [ok], (!) and [!!] in the palette's success, warning and error colours, and a plot of four lines in the palette's line colours. Row one: seal, seal-light, paper, high-contrast. Row two: nord, solarized-dark, solarized-light, gruvbox-dark. Row three: gruvbox-light, dracula, catppuccin-mocha, catppuccin-latte. Row four: tokyo-night, one-dark" caption="docs/examples/src/gallery.F90, run as gallery palettes: every bundled palette, in the look seal" />

| Palette | Light or dark | Source |
|---|---|---|
| `'seal'`, `'seal-light'` | dark, light | FIGURE's: ink, paper, one vermilion |
| `'paper'` | light | FIGURE's: black on white, for publication |
| `'high-contrast'` | dark | FIGURE's: white on black, yellow accents |
| `'nord'` | dark | [Nord](https://github.com/nordtheme/nord), MIT |
| `'solarized-dark'`, `'solarized-light'` | dark, light | [Solarized](https://github.com/altercation/solarized), MIT |
| `'gruvbox-dark'`, `'gruvbox-light'` | dark, light | [Gruvbox](https://github.com/morhetz/gruvbox), MIT |
| `'dracula'` | dark | [Dracula](https://github.com/dracula/dracula-theme), MIT |
| `'catppuccin-mocha'`, `'catppuccin-latte'` | dark, light | [Catppuccin](https://github.com/catppuccin/palette), MIT |
| `'tokyo-night'` | dark | [Tokyo Night](https://github.com/enkia/tokyo-night-vscode-theme), MIT |
| `'one-dark'` | dark | [One Dark](https://github.com/joshdick/onedark.vim), MIT |
| `'auto'` | the system's | `auto_dark` or `auto_light`, [below](#follow-the-system-s-light-or-dark-setting) |

Each palette is a file, `themes/palettes/<name>.toml`, embedded in the library. The hex values are the upstream
projects' own, named after each role in the file; where an upstream colour fails the [contrast
rule](#the-contrast-rule) in its role, another colour of the same palette takes its place, and the file's comment
says which (Nord's comment grey is too dark for dimmed text, so its `nord4` is used; Solarized's blue is too weak
under text, so its cyan is the accent). Their licences are in
[THIRD_PARTY.md](https://github.com/szaghi/figure/blob/main/THIRD_PARTY.md). FIGURE's four palettes give most Dear
ImGui colours by hand (the colours of the styles of the same name); the others are derived from their roles, as every
colour of the other palettes is.

**Changed in v0.3.0.** Until v0.3.0 the colours FIGURE's four styles did not set were Dear ImGui's dark or light
style's: a bluish `CheckboxSelectedBg` in `seal`, a blue `DragDropTarget` in `paper`, a grey dimming behind modals.
They are now derived from the palette's roles:

| Colour | seal, seal-light | paper | high-contrast |
|---|---|---|---|
| `CheckboxSelectedBg` | surface | surface | surface |
| `TableRowBg`, `TableRowBgAlt` | background (transparent); text at 4 % | the same | the same |
| `NavWindowingHighlight` | text at 70 % | text at 70 % | (unchanged) |
| `NavWindowingDimBg`, `ModalWindowDimBg` | black at 30 % and 45 % | the same | the same |
| `PlotLinesHovered`, `PlotHistogramHovered` | (unchanged) | accent, accent toward text | the same |
| `TreeLines` | (unchanged) | border | border |
| `DragDropTarget`, `DragDropTargetBg` | (unchanged) | accent, accent at 10 % | the same |

`paper` also has `MinorAlpha = 0.5` in effect (ImPlot's default is 0.25): the minor grid lines are drawn at half the
alpha of the major ones, so they show on white, under the major ones. The line was in the theme before but never took
effect.

### Palette roles

| Role | Colours |
|---|---|
| `background` | window backgrounds (`WindowBg`), title bars, the plot background |
| `surface` | fields, popups, menu bars, tabs, the plot frame (`FrameBg`, `PopupBg`, `MenuBarBg`, `Tab`) |
| `raised_surface` | buttons and the selected tab (`Button`, `TabSelected`) |
| `border` | borders, separators, scroll bar grabs, table and tree lines |
| `text` | text, the input cursor, the plot's text and grid |
| `dimmed_text` | disabled text (`TextDisabled`), ImGui's own small line plots |
| `accent` | what the user touches: check marks, slider grabs, the selected tab's line, links, resize grips, the docking preview |
| `text_on_accent` | text drawn on an accent fill, by FIGURE's own widgets |
| `selection` | selected lines and headers (`Header`), selected text (`TextSelectedBg`) |
| `success`, `warning`, `error` | not used by Dear ImGui: for the program's own messages, through `app%palette_color` |

The roles are opaque colours. `app%palette_color(role, rgba)` gives the program the roles in effect, so its own
messages follow the palette; with a style that has no palette (`'dark'`, `'light'`, `'classic'`, a theme file without
one) the roles are read from Dear ImGui's colours (`WindowBg`, `FrameBg`, `Button`, `Border`, `Text`,
`TextDisabled`, `CheckMark`, `Header`), and `success`, `warning` and `error` are Okabe and Ito's bluish green, orange
and vermilion. An unknown role is `FIG_ERR_ARGUMENT`. Colour is never the only carrier of meaning: a mark or a word
goes with it.

<<< @/examples/snippets/cb_palette-roles.F90{fortran}

<<< @/examples/snippets/cb_palette-status.F90{fortran}

### How the colours are derived

One function of the native layer maps the twelve roles to every colour of Dear ImGui (`ImGuiCol_*`); ImPlot's
colours (`ImPlotCol_*`) are left automatic, so ImPlot derives them from Dear ImGui's: the plot frame from `FrameBg`,
the plot background from `WindowBg`, the axis text, grid and ticks from `Text`, the legend from `PopupBg`.

- **Fills** are the roles: `WindowBg` the background, `FrameBg` the surface, `Button` the raised surface, `Header`
  the selection.
- **Hovered and active fills** are mixes toward the text colour (8 % and 16 % for fields and headers, 10 % and 20 %
  for buttons), or away from it where the mix would bring the text below 4.5:1 on them.
- **Disabled text** is the dimmed text; scroll bar grabs are the border mixed toward the text.
- **Accents:** check marks, slider grabs, links, the selected tab's line and the navigation cursor are the accent;
  separators, resize grips and the docking preview are the accent with transparency.
- **The window's background**, behind the windows, is the background darkened (by 25 % for a dark palette, 8 % for a
  light one), unless the palette file gives one.
- **Line colours** are the palette file's `lines`, or ImPlot's default (Deep) if it has none.

Explicit colours still override: a palette file's or a theme file's `[imgui.colors]` and `[implot.colors]` are
applied after the derivation.

### The contrast rule

A palette is checked when it is applied, with the WCAG 2 contrast ratio:

| Pair | At least |
|---|---|
| `text` on `background`, `surface`, `raised_surface` and `selection` | 4.5:1 |
| `dimmed_text` on `background` | 3:1 |
| `text_on_accent` on `accent` | 4.5:1 |

A palette that fails is refused with `FIG_ERR_ARGUMENT`, and the message names the first failing pair, its ratio and
its colours. A theme file `my-theme.toml` with `palette = "nord"` and, in its `[palette]` table,
`text = "#4c566a"` (Nord's comment grey) gives
`load_style: my-theme.toml: [palette]: text on background is 1.69:1, below 4.5:1 (#4c566a on #2e3440)`. `src/tests/figure_test_themes.F90` holds every bundled palette to
the rule, and further to text at 4.5:1 on every fill it is drawn on (hovered and active included) and to line
colours at 3:1 on the plot background.

### Follow the system's light or dark setting

<<< @/examples/snippets/cb_palette-auto.F90{fortran}

`palette='auto'` takes `auto_dark` (default `'seal'`) when the system is set to dark and `auto_light` (default
`'seal-light'`) when it is set to light, and changes palette when the setting changes while the program runs. The
geometry and the line colours given with `lines=` are kept through the change; colours changed by name are not.
`auto_dark` and `auto_light` given alone change the pair of an `'auto'` in effect.

**Modes:** in **window** mode the setting is SDL's (`SDL_GetSystemTheme`), read again on its theme-changed event; an
unknown setting counts as dark. In **headless** and **remote** mode the setting is unknown, so `'auto'` is
`auto_dark` (in remote mode the browser's own setting is not read). In every mode `test_system_theme` (from
`figure_testing`) changes the setting at the next frame, as the event would, for tests; `'system'` gives it back.

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
  `ScrollbarSize`, `GrabMinSize`, `GrabRounding`, `TabRounding`, `ButtonTextAlign`, `AntiAliasedLines`, the arrows'
  `SymbolArrowSizeFactor` and `SymbolArrowThicknessFactor`, ...) and of
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
library: programs need no font file. Its monospace sibling, IBM Plex Mono, is bundled the same way, for text whose
columns must line up: input files, tables of numbers, the output of a tool. The symbols either lacks (Greek in Plex
Mono, `∇` in both) come from a bundled fallback, Noto Sans Math ([below](#symbols-the-fallback-fonts)).

| Procedure | Does |
|---|---|
| `app%set_font(font [, size] [, stat])` | the default font: `'plex-sans'` (the default), `'plex-mono'` (IBM Plex Mono, monospace), `'proggy'` (Dear ImGui's own 13-pixel bitmap font) or the path of a TrueType/OpenType file; `size` in logical pixels |
| `ig_push_font(font [, size] [, stat])`, `ig_pop_font([stat])` | another font and/or size for the widgets in between (`font=''` keeps the current one): a title, a value shown large |

<<< @/examples/snippets/cb_controls-font.F90{fortran}

<<< @/examples/snippets/cb_controls-fonts.F90{fortran}

`app%set_font('proggy')` gives Dear ImGui's classic look; a file is given by its path,
`app%set_font('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 16.0_real64)`.

`'plex-mono'` gives every character the same advance, so the columns of a text line up; it is the font for a
[multi-line field](widgets#multi-line-text) showing a file, pushed around it:

<<< @/examples/snippets/cb_text-edit.F90{fortran}

Fonts are rasterised on demand at every size used (Dear ImGui's dynamic font atlas): any size stays sharp, and the
display's content scale applies on top. A file that cannot be read is `FIG_ERR_FAILED`; one that is not a font, or a
size outside (0, 200], is `FIG_ERR_ARGUMENT`. A theme file can name the font and its size (`font`, `font_size`).

### Symbols: the fallback fonts

| Procedure | Does |
|---|---|
| `app%add_fallback_font(file [, stat])` | a TrueType/OpenType file of the program's own, asked for the glyphs every other font of a text font lacks |

(Dear ImGui's merged fonts: `ImFontConfig::MergeMode`, the sources of a font asked in order for each glyph.)

A text font is a stack of fonts asked in order for each character; the first that has a glyph draws it:

| Order | Font | Gives |
|---|---|---|
| 1 | the text font: IBM Plex Sans, IBM Plex Mono, Proggy or the file of `set_font`/`ig_push_font` | its own glyphs: Plex Sans has Latin, Greek and most operators; Plex Mono has Latin and the operators but no Greek, nor `∇`; both have the super- and subscript digits |
| 2 | [Lucide](#icons) (bundled) | the icons, `ICON_*`, in the Private Use Area |
| 3 | Noto Sans Math (bundled, OFL-1.1) | what the two before lack: the Greek letters and `∇` in Plex Mono, `∇` in Plex Sans, the mathematical operators and arrows |
| 4, 5, ... | the program's own, in the order added | what all of the above lack |

The symbols CFD writes were checked glyph by glyph (fontTools, on the bundled files) and have a glyph in both text
fonts: the Greek letters, upper and lower case; `∇ ∂ Δ ∞ ≈ ≤ ≥ ± × · √ ∑ ∫`; the superscript and subscript digits
`⁰ ¹ ² ³ ⁴ ⁵ ⁶ ⁷ ⁸ ⁹`, `₀ ₁ ₂ ₃ ₄ ₅ ₆ ₇ ₈ ₉`. Noto Sans Math has every one of them except `·` and the super- and
subscript digits, which both Plex fonts have. `figure_test_text` checks each one's bitmap in both fonts.

<Media name="glyphs" alt="A window titled Glyphs with two groups, plex-sans (IBM Plex Sans) and plex-mono (IBM Plex Mono), each with five rows: the upper-case Greek letters, the lower-case Greek letters, the operators nabla, partial, Delta, infinity, approximately equal, less or equal, greater or equal, plus-minus, times, middle dot, square root, sum and integral, then the superscript and the subscript digits 0 to 9. Every glyph is drawn, none as a box" caption="docs/examples/src/gallery.F90, run as gallery glyphs: the symbols CFD writes, in the two text fonts" />

<<< @/examples/snippets/cb_fallback_font-table.F90{fortran}

A program's own fallback, for a script Plex and Noto Sans Math lack (a CJK font, a font of its own symbols):

<<< @/examples/snippets/cb_fallback_font-own.F90{fortran}

The program prints, headless, which font gives each symbol (`test_glyph`, [Headless testing](testing#glyphs)): Plex
Mono's own `A` and `²`, Noto Sans Math's `ρ` and `∇`, and the file's `ά` (alpha with tonos, in Plex Sans but in
neither Plex Mono nor Noto Sans Math):

<<< @/examples/output/cb_fallback_font.txt{text}

- **Sizes:** a fallback's letters are scaled to the text font's em (Dear ImGui sizes a font by its height from ascent
  to descent, which differs between fonts: Noto Sans Math's at the size of Plex would be 13 % smaller), and stand on
  its baseline: Noto Sans Math's capitals are 2 % taller than Plex's (cap heights 714 and 698 per 1000 of the em).
- **When:** after `init*`. Called between frames, it applies at once; inside a frame, from the next frame (a font
  is changed between frames). It reaches every text font, those loaded already and those loaded later. A file added
  already is not added again; the fallbacks last until `destroy`.
- **Status:** a file that cannot be read is `FIG_ERR_FAILED`; one that is not a TrueType/OpenType font, or a
  fourteenth fallback, `FIG_ERR_ARGUMENT` (Dear ImGui keeps 16 fonts in one: the text font, Lucide, Noto Sans Math
  and 13 of the program's); before `init*`, `FIG_ERR_STATE`. Messages: `app%add_fallback_font: cannot read the font
  FILE`, `app%add_fallback_font: FILE is not a TrueType or OpenType font`, `app%add_fallback_font: 13 fallback
  fonts already (Dear ImGui's 16 per font)`, `app%add_fallback_font: figure is not initialized`. Without `stat`, the
  program stops with the message ([Error handling](errors)).
- **Modes:** the same in window, headless and remote mode.
- **Threads:** the frame loop's thread; a task is refused (`FIG_ERR_STATE`).
- **What it does not do:** a fallback's glyphs keep their own advance: inside a monospace text (Plex Mono) a Greek
  letter or `∇` from Noto Sans Math is proportional, so a column after it can shift by a fraction of a character.
  Code points beyond the Basic Multilingual Plane (U+10000 and up: the mathematical alphanumerics `𝑥 𝛼`, emoji) are
  not drawn: FIGURE builds Dear ImGui with 16-bit characters. No font is looked up on the system: a program names its
  files.

## Icons

The [Lucide](https://lucide.dev/icons/) icons (ISC licence, bundled and embedded like the font) are merged into every
text font FIGURE loads: the two bundled ones, Proggy, and any font file given to `app%set_font` or `ig_push_font`. An icon
is a UTF-8 string, `ICON_<NAME>`, exported by `use figure`: it goes in any label, before or after the text, and takes
the size and colour of the text around it.

<<< @/examples/snippets/cb_controls-icons.F90{fortran}

The names are those of the [Lucide gallery](https://lucide.dev/icons/), upper-cased, with `-` turned into `_`, after
`ICON_`: `file-pen` is `ICON_FILE_PEN`, `chart-line` is `ICON_CHART_LINE`. All 2171 names of the bundled Lucide
1.61.0 are there, the older names of renamed icons included (`ICON_ALERT_CIRCLE` and `ICON_CIRCLE_ALERT` are one
glyph); `src/lib/figure_icons.F90` lists them with their code points. Icons are as wide as the font is high, and
centred on the capitals of the text. The constants are generated from the font's code point map by
`scripts/gen_icons.py`.

## Theme files

Every named style is a small text file in the repository, `themes/<name>.toml`, embedded in the library when the
native layer is built: adding a file there adds a style. The format is a subset of TOML:

```toml
# A theme file, every kind of entry (themes/seal.toml, the default style, sets two: look and palette).
look = "fluent"                                # a look: its geometry first (default: Dear ImGui's)
palette = "nord"                               # a palette, or "auto" (default: none, the colours of base)
auto_dark = "nord"                             # the palettes of "auto" (defaults: seal, seal-light)
auto_light = "solarized-light"
base = "dark"                                  # dark | light | classic: the colours without a palette
font = "plex-sans"                             # plex-sans | plex-mono | proggy | a font file (default: the font in effect)
font_size = 15                                 # logical pixels (default: the size in effect)
background = "#14120f"                         # behind the windows (default: the palette's, or the base's)
lines = ["#e8664c", "#e9e2d4", "#c9a25a"]      # ImPlot's line colours, in order, or "okabe-ito" (default: the
                                               # palette's, or ImPlot's Deep)

[palette]                                      # roles: all twelve, or some over the named palette
accent = "#d08770"

[imgui.vars]                                   # ImGuiStyle fields: a number, [x, y], true or false
WindowRounding = 0
FramePadding = [4, 3]

[imgui.colors]                                 # ImGuiCol_* names: "#rrggbb", "#rrggbbaa", ["#rrggbb", alpha]
Text = "#f6f2ea"                               # or [r, g, b, a] in [0, 1]
PopupBg = ["#1c1915", 0.97]

[implot.vars]                                  # ImPlotStyle fields
[implot.colors]                                # ImPlotCol_* names

[figure.vars]                                  # FIGURE's own variables
TitleBarHeight = 40                            # the title bar of decorations='figure' (0: the menu bar's)
```

- Names are those of [colours and variables by name](#colours-and-variables-by-name); `#` starts a comment.
- **The order:** the colours come from the palette (derived from its roles) or, without one, from `base`; the
  variables from the look or, without one, from Dear ImGui's defaults; then the file's own `[imgui.vars]`,
  `[imgui.colors]`, `[implot.vars]` and `[implot.colors]` override them. With a palette, `base` gives no colour.
- **A `[palette]` table** gives roles: with `palette = "name"` it overrides single roles of that palette; without, it
  must give all twelve. Either way the [contrast rule](#the-contrast-rule) applies to the result.
- Everything not given comes from the look, the palette or `base`: a theme lists only what it changes, and a newer
  Dear ImGui adding style colours never leaves a theme incomplete.
- Sizes are in logical pixels, multiplied by the display's content scale when the theme is applied.
- ImPlot's colours not given are derived from Dear ImGui's (ImPlot's automatic colours), so a theme that sets only
  Dear ImGui colours gives matching plots.
- A malformed file is reported with its line: `themes/x.toml:12: unknown Dear ImGui colour "Buton"`.

A look file (`themes/looks/`) holds `[imgui.vars]`, `[implot.vars]` and `[figure.vars]` only; a palette file (`themes/palettes/`) holds
a complete `[palette]` table and, optionally, `background`, `lines`, `[imgui.colors]` and `[implot.colors]`. Adding a
file there and rebuilding the native layer adds a look or a palette.

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
| `app%save_style(file [, stat])` | write the style in effect as a theme file: its look and palette (or its base), background and line colours, and every colour and variable that differs from what they give, including the changes made by name or in the style editor |
| `ig_show_style_editor([open] [, stat])` | Dear ImGui's and ImPlot's own style editors in a window, "Style editor": every colour and size, live |

`FIGURE_STYLE` also takes a file: a value with a `/` or ending in `.toml` is loaded as a theme
(`FIGURE_STYLE=./my-theme.toml exe/examples/figure_hello`).

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
their alpha exact; `load_style` reads the file back to the same style. A look and a palette are written by name
(`look = "fluent"`, `palette = "nord"`, and for `'auto'` its pair), a palette given as a `[palette]` table as its twelve
roles; what follows is only what differs from them. Edit the file freely: everything not in it comes from the look,
the palette or `base`.
