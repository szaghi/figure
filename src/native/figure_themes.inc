// generated from themes/*.toml, themes/looks/*.toml and themes/palettes/*.toml by scripts/fpm_package.py
struct theme_source { const char *name; const char *text; };
const theme_source THEMES[] = {
   {"classic", R"FIGURETHEME(# FIGURE theme "classic": Dear ImGui's classic style, with ImPlot's default line colours.
# Format: docs/guide/styles.md#theme-files.

base = "classic"
)FIGURETHEME"},
   {"dark", R"FIGURETHEME(# FIGURE theme "dark": Dear ImGui's dark style, with ImPlot's default line colours.
# Format: docs/guide/styles.md#theme-files.

base = "dark"
)FIGURETHEME"},
   {"high-contrast", R"FIGURETHEME(# FIGURE theme "high-contrast": white on black, yellow accents.
# For low vision and bright rooms: text at 7:1 or more against every background it sits on (WCAG AAA), borders on
# every frame, a yellow that reads on black for what the user touches, and colour-blind-safe lines.
# The look "seal" (square corners) and the palette of the same name.
# Format: docs/guide/styles.md#theme-files. Entries not given come from the look and the palette.

look = "seal"
palette = "high-contrast"

[imgui.vars]
WindowBorderSize = 1
FrameBorderSize = 1
PopupBorderSize = 1

[implot.vars]
PlotBorderSize = 1
)FIGURETHEME"},
   {"light", R"FIGURETHEME(# FIGURE theme "light": Dear ImGui's light style, with ImPlot's default line colours.
# Format: docs/guide/styles.md#theme-files.

base = "light"
background = "#cccccc"
)FIGURETHEME"},
   {"paper", R"FIGURETHEME(# FIGURE theme "paper": for publication, black on white.
# Screenshots that go into papers and slides: white background, black text and thin borders, a light grey grid, and
# lines in the five colours of Okabe and Ito's colour-blind-safe set that keep 3:1 against white (its orange, sky blue
# and yellow do not), in order of greyscale lightness, black first.
# The look "seal" (square corners) and the palette of the same name.
# Format: docs/guide/styles.md#theme-files. Entries not given come from the look and the palette.

look = "seal"
palette = "paper"

[imgui.vars]
WindowBorderSize = 1
FrameBorderSize = 1

[implot.vars]
PlotBorderSize = 1
MinorAlpha = 0.5                               # the minor grid lines at half the major ones' alpha (ImPlot: 0.25)
)FIGURETHEME"},
   {"seal-light", R"FIGURETHEME(# FIGURE theme "seal-light": the seal on paper.
# Paper windows, ink text, the same vermilion accents.
# The look "seal" (square corners) and the palette of the same name.
# Format: docs/guide/styles.md#theme-files. Entries not given come from the look and the palette.

look = "seal"
palette = "seal-light"
)FIGURETHEME"},
   {"seal", R"FIGURETHEME(# FIGURE theme "seal": ink windows, paper text, one vermilion (the default).
# Vermilion is spent on what the user touches (slider grabs, check marks, pressed buttons) and on the first line.
# The look "seal" (square corners) and the palette of the same name.
# Format: docs/guide/styles.md#theme-files. Entries not given come from the look and the palette.

look = "seal"
palette = "seal"
)FIGURETHEME"},
};
const theme_source LOOKS[] = {
   {"adwaita", R"FIGURETHEME(# FIGURE look "adwaita": close to GNOME's Adwaita (GTK 4).
# Rounder corners, roomier padding and spacing, flat fields without borders; popups keep a thin border.
# Proportions only, not a copy (Dear ImGui draws no gradients or shadows).
# Format: docs/guide/styles.md#looks. A look holds geometry only: [imgui.vars] and [implot.vars], logical pixels.

[imgui.vars]
WindowPadding = [12, 12]
WindowRounding = 10
WindowBorderSize = 0
ChildRounding = 8
PopupRounding = 8
PopupBorderSize = 1
FramePadding = [10, 6]
FrameRounding = 6
FrameBorderSize = 0
ItemSpacing = [8, 8]
ItemInnerSpacing = [6, 6]
CellPadding = [6, 4]
IndentSpacing = 24
ScrollbarSize = 12
ScrollbarRounding = 12
GrabMinSize = 14
GrabRounding = 12
TabRounding = 6
TabBarBorderSize = 0
SeparatorTextPadding = [20, 6]

[implot.vars]
PlotBorderSize = 0
PlotPadding = [12, 12]
)FIGURETHEME"},
   {"fluent", R"FIGURETHEME(# FIGURE look "fluent": close to Windows 11 (Fluent 2).
# Medium rounding (4 on controls, 8 on windows and popups), framed fields, round slider grabs, moderate spacing.
# Proportions only, not a copy (Dear ImGui draws no acrylic, gradients or shadows).
# Format: docs/guide/styles.md#looks. A look holds geometry only: [imgui.vars] and [implot.vars], logical pixels.

[imgui.vars]
WindowPadding = [10, 10]
WindowRounding = 8
WindowBorderSize = 1
ChildRounding = 4
PopupRounding = 8
PopupBorderSize = 1
FramePadding = [8, 5]
FrameRounding = 4
FrameBorderSize = 1
ItemSpacing = [8, 6]
ItemInnerSpacing = [6, 4]
CellPadding = [6, 3]
IndentSpacing = 20
ScrollbarSize = 10
ScrollbarRounding = 6
GrabMinSize = 12
GrabRounding = 6
TabRounding = 4

[implot.vars]
PlotBorderSize = 1
)FIGURETHEME"},
   {"fusion", R"FIGURETHEME(# FIGURE look "fusion": close to Qt's Fusion style.
# Small rounding, framed fields and windows, dense spacing: a desktop tool that packs many controls.
# Proportions only, not a copy (Dear ImGui draws no gradients or shadows).
# Format: docs/guide/styles.md#looks. A look holds geometry only: [imgui.vars] and [implot.vars], logical pixels.

[imgui.vars]
WindowPadding = [6, 6]
WindowRounding = 2
WindowBorderSize = 1
ChildRounding = 2
ChildBorderSize = 1
PopupRounding = 2
PopupBorderSize = 1
FramePadding = [6, 3]
FrameRounding = 2
FrameBorderSize = 1
ItemSpacing = [6, 4]
ItemInnerSpacing = [4, 4]
CellPadding = [4, 2]
IndentSpacing = 18
ScrollbarSize = 12
ScrollbarRounding = 2
GrabMinSize = 10
GrabRounding = 2
TabRounding = 2
TabBorderSize = 1

[implot.vars]
PlotBorderSize = 1
)FIGURETHEME"},
   {"seal", R"FIGURETHEME(# FIGURE look "seal": square and compact, FIGURE's own (the default).
# Dear ImGui's proportions with every corner cut straight, as the seal's edges are.
# Format: docs/guide/styles.md#looks. A look holds geometry only: [imgui.vars] and [implot.vars], logical pixels.

[imgui.vars]
WindowRounding = 0
ChildRounding = 0
FrameRounding = 0
PopupRounding = 0
ScrollbarRounding = 0
GrabRounding = 0
TabRounding = 0
)FIGURETHEME"},
};
const theme_source PALETTES[] = {
   {"catppuccin-latte", R"FIGURETHEME(# FIGURE palette "catppuccin-latte": Catppuccin Latte, the light Catppuccin flavour.
# Source: https://github.com/catppuccin/palette (palette.json, v1.8.0, commit 07d02aa).
# MIT licence, Copyright (c) 2021 Catppuccin.
# Licence: third_party/palettes/LICENSE-catppuccin.txt, installed in share/licenses/catppuccin/.
# The hex values are the upstream ones, by their upstream names (after each role).
# Surface is mantle: surface0 under text is the raised surface, so frames and buttons differ.
# Lines are the five colours of Latte that keep 3:1 on base: blue, red, mauve, teal, maroon.
# Format: docs/guide/styles.md#palettes. The Dear ImGui colours are derived from the roles.

background = "#dce0e8"   # crust, behind the windows
lines = ["#1e66f5", "#d20f39", "#8839ef", "#179299", "#e64553"]

[palette]
background     = "#eff1f5"   # base
surface        = "#e6e9ef"   # mantle
raised_surface = "#ccd0da"   # surface0
border         = "#acb0be"   # surface2
text           = "#4c4f69"   # text
dimmed_text    = "#6c6f85"   # subtext0
accent         = "#8839ef"   # mauve
text_on_accent = "#eff1f5"   # base
selection      = "#ccd0da"   # surface0
success        = "#40a02b"   # green
warning        = "#df8e1d"   # yellow
error          = "#d20f39"   # red
)FIGURETHEME"},
   {"catppuccin-mocha", R"FIGURETHEME(# FIGURE palette "catppuccin-mocha": Catppuccin Mocha, the darkest of the four Catppuccin flavours.
# Source: https://github.com/catppuccin/palette (palette.json, v1.8.0, commit 07d02aa).
# MIT licence, Copyright (c) 2021 Catppuccin.
# Licence: third_party/palettes/LICENSE-catppuccin.txt, installed in share/licenses/catppuccin/.
# The hex values are the upstream ones, by their upstream names (after each role).
# Format: docs/guide/styles.md#palettes. The Dear ImGui colours are derived from the roles.

background = "#11111b"   # crust, behind the windows
lines = ["#89b4fa", "#a6e3a1", "#fab387", "#f38ba8", "#cba6f7", "#94e2d5", "#f9e2af", "#f5c2e7"]

[palette]
background     = "#1e1e2e"   # base
surface        = "#313244"   # surface0
raised_surface = "#45475a"   # surface1
border         = "#585b70"   # surface2
text           = "#cdd6f4"   # text
dimmed_text    = "#a6adc8"   # subtext0
accent         = "#cba6f7"   # mauve
text_on_accent = "#1e1e2e"   # base
selection      = "#45475a"   # surface1
success        = "#a6e3a1"   # green
warning        = "#f9e2af"   # yellow
error          = "#f38ba8"   # red
)FIGURETHEME"},
   {"dracula", R"FIGURETHEME(# FIGURE palette "dracula": Dracula, a dark palette.
# Source: https://github.com/dracula/dracula-theme (README.md, commit 1e04a4b).
# MIT licence, Copyright (c) 2023 Dracula Theme.
# Licence: third_party/palettes/LICENSE-dracula.txt, installed in share/licenses/dracula/.
# The hex values are the upstream ones, by their upstream names (after each role).
# Dracula has one neutral besides the background: surface and raised surface are both Current Line.
# Format: docs/guide/styles.md#palettes. The Dear ImGui colours are derived from the roles.

lines = ["#bd93f9", "#50fa7b", "#ffb86c", "#ff79c6", "#8be9fd", "#f1fa8c", "#ff5555", "#6272a4"]

[palette]
background     = "#282a36"   # Background
surface        = "#44475a"   # Current Line
raised_surface = "#44475a"   # Current Line
border         = "#6272a4"   # Comment
text           = "#f8f8f2"   # Foreground
dimmed_text    = "#6272a4"   # Comment
accent         = "#bd93f9"   # Purple
text_on_accent = "#282a36"   # Background
selection      = "#44475a"   # Selection
success        = "#50fa7b"   # Green
warning        = "#ffb86c"   # Orange
error          = "#ff5555"   # Red
)FIGURETHEME"},
   {"gruvbox-dark", R"FIGURETHEME(# FIGURE palette "gruvbox-dark": Gruvbox, dark: retro groove colours.
# Source: https://github.com/morhetz/gruvbox (colors/gruvbox.vim, commit 0401386).
# MIT licence, Copyright (c) Pavel Pertsev (morhetz).
# Licence: third_party/palettes/LICENSE-gruvbox.txt, installed in share/licenses/gruvbox/.
# The hex values are the upstream ones, by their upstream names (after each role).
# Format: docs/guide/styles.md#palettes. The Dear ImGui colours are derived from the roles.

lines = ["#83a598", "#fabd2f", "#b8bb26", "#fb4934", "#d3869b", "#8ec07c", "#fe8019", "#a89984"]

[palette]
background     = "#282828"   # dark0
surface        = "#3c3836"   # dark1
raised_surface = "#504945"   # dark2
border         = "#665c54"   # dark3
text           = "#ebdbb2"   # light1
dimmed_text    = "#a89984"   # light4
accent         = "#fabd2f"   # bright_yellow
text_on_accent = "#282828"   # dark0
selection      = "#504945"   # dark2
success        = "#b8bb26"   # bright_green
warning        = "#fe8019"   # bright_orange
error          = "#fb4934"   # bright_red
)FIGURETHEME"},
   {"gruvbox-light", R"FIGURETHEME(# FIGURE palette "gruvbox-light": Gruvbox, light: retro groove colours.
# Source: https://github.com/morhetz/gruvbox (colors/gruvbox.vim, commit 0401386).
# MIT licence, Copyright (c) Pavel Pertsev (morhetz).
# Licence: third_party/palettes/LICENSE-gruvbox.txt, installed in share/licenses/gruvbox/.
# The hex values are the upstream ones, by their upstream names (after each role).
# The accent is faded_blue: gruvbox light mode uses the faded colours, which keep their contrast on light0.
# Format: docs/guide/styles.md#palettes. The Dear ImGui colours are derived from the roles.

lines = ["#076678", "#9d0006", "#79740e", "#b57614", "#8f3f71", "#427b58", "#af3a03", "#7c6f64"]

[palette]
background     = "#fbf1c7"   # light0
surface        = "#ebdbb2"   # light1
raised_surface = "#d5c4a1"   # light2
border         = "#bdae93"   # light3
text           = "#3c3836"   # dark1
dimmed_text    = "#7c6f64"   # dark4
accent         = "#076678"   # faded_blue
text_on_accent = "#fbf1c7"   # light0
selection      = "#d5c4a1"   # light2
success        = "#79740e"   # faded_green
warning        = "#af3a03"   # faded_orange
error          = "#9d0006"   # faded_red
)FIGURETHEME"},
   {"high-contrast", R"FIGURETHEME(# FIGURE palette "high-contrast": white on black, yellow accents.
# For low vision and bright rooms: text at 7:1 or more against every background it sits on (WCAG AAA), borders on
# every frame, a yellow that reads on black for what the user touches, and colour-blind-safe lines.
# The roles are what FIGURE draws its own widgets with and what the contrast rule checks. The Dear ImGui colours
# given below are hand-tuned (the theme "high-contrast" before looks and palettes); the others are derived from the roles
# (until v0.3.0 they were Dear ImGui's own style's, which the theme had never set).
# Format: docs/guide/styles.md#palettes.

background = "#000000"
lines = "okabe-ito"

[palette]
background = "#000000"
surface = "#000000"
raised_surface = "#000000"
border = "#ffffff"
text = "#ffffff"
dimmed_text = "#bfbfbf"
accent = "#ffd400"
text_on_accent = "#000000"
selection = "#262626"
success = "#009e73"
warning = "#f0e442"
error = "#d55e00"

[imgui.colors]
Text = "#ffffff"
TextDisabled = "#bfbfbf"
WindowBg = "#000000"
ChildBg = ["#000000", 0.0]
PopupBg = "#000000"
Border = "#ffffff"
BorderShadow = ["#000000", 0.0]
FrameBg = "#000000"
FrameBgHovered = "#262626"
FrameBgActive = "#3d3d3d"
TitleBg = "#000000"
TitleBgActive = "#1f1f1f"
TitleBgCollapsed = "#000000"
MenuBarBg = "#000000"
ScrollbarBg = "#000000"
ScrollbarGrab = "#a6a6a6"
ScrollbarGrabHovered = "#d9d9d9"
ScrollbarGrabActive = "#ffffff"
CheckMark = "#ffd400"
SliderGrab = "#ffd400"
SliderGrabActive = "#ffe866"
Button = "#000000"
ButtonHovered = "#333333"
ButtonActive = "#4d4d4d"
Header = "#262626"
HeaderHovered = "#333333"
HeaderActive = "#4d4d4d"
Separator = "#ffffff"
SeparatorHovered = "#ffd400"
SeparatorActive = "#ffd400"
ResizeGrip = ["#ffd400", 0.4]
ResizeGripHovered = ["#ffd400", 0.7]
ResizeGripActive = "#ffd400"
Tab = "#000000"
TabHovered = "#333333"
TabSelected = "#262626"
TabSelectedOverline = "#ffd400"
TabDimmed = "#000000"
TabDimmedSelected = "#1f1f1f"
TabDimmedSelectedOverline = "#ffffff"
PlotLines = "#ffffff"
PlotHistogram = "#ffd400"
TableHeaderBg = "#1f1f1f"
TableBorderStrong = "#ffffff"
TableBorderLight = "#808080"
TextLink = "#ffd400"
TextSelectedBg = ["#ffd400", 0.35]
NavCursor = "#ffd400"
DockingPreview = ["#ffd400", 0.45]
DockingEmptyBg = "#000000"

[implot.colors]
FrameBg = "#000000"
PlotBg = "#000000"
PlotBorder = "#ffffff"
LegendBg = "#000000"
LegendBorder = "#ffffff"
LegendText = "#ffffff"
TitleText = "#ffffff"
InlayText = "#ffffff"
AxisText = "#ffffff"
AxisGrid = ["#ffffff", 0.35]
AxisTick = "#ffffff"
)FIGURETHEME"},
   {"nord", R"FIGURETHEME(# FIGURE palette "nord": Nord, an arctic, north-bluish palette.
# Source: https://github.com/nordtheme/nord (src/nord.css, commit 005e87e).
# MIT licence, Copyright (c) 2016-present Sven Greb.
# Licence: third_party/palettes/LICENSE-nord.txt, installed in share/licenses/nord/.
# The hex values are the upstream ones, by their upstream names (after each role).
# Dimmed text is nord4: nord3, the comment colour, is 1.9:1 on nord0 (the rule asks 3:1).
# Format: docs/guide/styles.md#palettes. The Dear ImGui colours are derived from the roles.

lines = ["#88c0d0", "#a3be8c", "#ebcb8b", "#d08770", "#b48ead", "#bf616a", "#8fbcbb", "#81a1c1"]

[palette]
background     = "#2e3440"   # nord0
surface        = "#3b4252"   # nord1
raised_surface = "#434c5e"   # nord2
border         = "#4c566a"   # nord3
text           = "#eceff4"   # nord6
dimmed_text    = "#d8dee9"   # nord4
accent         = "#88c0d0"   # nord8
text_on_accent = "#2e3440"   # nord0
selection      = "#434c5e"   # nord2
success        = "#a3be8c"   # nord14
warning        = "#ebcb8b"   # nord13
error          = "#bf616a"   # nord11
)FIGURETHEME"},
   {"one-dark", R"FIGURETHEME(# FIGURE palette "one-dark": One Dark, Atom's dark palette.
# Source: https://github.com/joshdick/onedark.vim (autoload/onedark.vim, commit ad9610c).
# MIT licence, Copyright (c) 2015 Joshua Dick, and (c) 2011-2022 GitHub Inc. for mono-2.
# Licence: third_party/palettes/LICENSE-one-dark.txt, installed in share/licenses/one-dark/.
# The hex values are the upstream ones, by their upstream names (after each role).
# Dimmed text is mono-2 of the original One Dark (atom/atom, packages/one-dark-syntax/styles/colors.less, commit
# 8ae45ca, hsl(220, 9%, 55%)): onedark.vim has no grey between its comment grey (2.3:1 on the background) and the text.
# Lines leave out dark_red, below 3:1 on the background.
# Format: docs/guide/styles.md#palettes. The Dear ImGui colours are derived from the roles.

lines = ["#61afef", "#98c379", "#e5c07b", "#e06c75", "#c678dd", "#56b6c2", "#d19a66"]

[palette]
background     = "#282c34"   # background
surface        = "#2c323c"   # cursor_grey
raised_surface = "#3e4452"   # visual_grey
border         = "#4b5263"   # gutter_fg_grey
text           = "#abb2bf"   # foreground
dimmed_text    = "#828997"   # mono-2 of Atom One Dark
accent         = "#61afef"   # blue
text_on_accent = "#282c34"   # background
selection      = "#3e4452"   # visual_grey
success        = "#98c379"   # green
warning        = "#e5c07b"   # yellow
error          = "#e06c75"   # red
)FIGURETHEME"},
   {"paper", R"FIGURETHEME(# FIGURE palette "paper": black on white, for publication.
# Screenshots that go into papers and slides: white background, black text and thin borders, a light grey grid, and
# lines in the five colours of Okabe and Ito's colour-blind-safe set that keep 3:1 against white (its orange, sky blue
# and yellow do not), in order of greyscale lightness, black first.
# The roles are what FIGURE draws its own widgets with and what the contrast rule checks. The Dear ImGui colours
# given below are hand-tuned (the theme "paper" before looks and palettes); the others are derived from the roles
# (until v0.3.0 they were Dear ImGui's own style's, which the theme had never set).
# Format: docs/guide/styles.md#palettes.

background = "#ffffff"
lines = ["#000000", "#0072b2", "#d55e00", "#009e73", "#cc79a7"]

[palette]
background = "#ffffff"
surface = "#f2f2f2"
raised_surface = "#f2f2f2"
border = "#9a9a9a"
text = "#000000"
dimmed_text = "#6b6b6b"
accent = "#000000"
text_on_accent = "#ffffff"
selection = "#ececec"
success = "#009e73"
warning = "#d55e00"
error = "#d55e00"

[imgui.colors]
Text = "#000000"
TextDisabled = "#6b6b6b"
WindowBg = "#ffffff"
ChildBg = ["#ffffff", 0.0]
PopupBg = "#ffffff"
Border = "#9a9a9a"
BorderShadow = ["#000000", 0.0]
FrameBg = "#f2f2f2"
FrameBgHovered = "#e6e6e6"
FrameBgActive = "#d9d9d9"
TitleBg = "#f2f2f2"
TitleBgActive = "#e6e6e6"
TitleBgCollapsed = "#f2f2f2"
MenuBarBg = "#f2f2f2"
ScrollbarBg = "#ffffff"
ScrollbarGrab = "#c8c8c8"
ScrollbarGrabHovered = "#b0b0b0"
ScrollbarGrabActive = "#989898"
CheckMark = "#000000"
SliderGrab = "#000000"
SliderGrabActive = "#444444"
Button = "#f2f2f2"
ButtonHovered = "#e0e0e0"
ButtonActive = "#cccccc"
Header = "#ececec"
HeaderHovered = "#e0e0e0"
HeaderActive = "#d0d0d0"
Separator = "#bdbdbd"
SeparatorHovered = "#6b6b6b"
SeparatorActive = "#000000"
ResizeGrip = ["#000000", 0.15]
ResizeGripHovered = ["#000000", 0.35]
ResizeGripActive = ["#000000", 0.6]
Tab = "#f2f2f2"
TabHovered = "#e0e0e0"
TabSelected = "#ffffff"
TabSelectedOverline = "#000000"
TabDimmed = "#f2f2f2"
TabDimmedSelected = "#ffffff"
TabDimmedSelectedOverline = "#9a9a9a"
PlotLines = "#000000"
PlotHistogram = "#555555"
TableHeaderBg = "#f2f2f2"
TableBorderStrong = "#9a9a9a"
TableBorderLight = "#d9d9d9"
TextLink = "#0072b2"
TextSelectedBg = ["#0072b2", 0.25]
NavCursor = "#000000"
DockingPreview = ["#000000", 0.25]
DockingEmptyBg = "#ffffff"

[implot.colors]
FrameBg = "#ffffff"
PlotBg = "#ffffff"
PlotBorder = "#000000"
LegendBg = ["#ffffff", 0.92]
LegendBorder = "#9a9a9a"
LegendText = "#000000"
TitleText = "#000000"
InlayText = "#000000"
AxisText = "#000000"
AxisGrid = ["#000000", 0.15]
AxisTick = "#000000"
)FIGURETHEME"},
   {"seal-light", R"FIGURETHEME(# FIGURE palette "seal-light": the seal on paper: paper windows, ink text, the same vermilion.
# Paper windows, ink text, the same vermilion accents.
# The roles are what FIGURE draws its own widgets with and what the contrast rule checks. The Dear ImGui colours
# given below are hand-tuned (the theme "seal-light" before looks and palettes); the others are derived from the roles
# (until v0.3.0 they were Dear ImGui's own style's, which the theme had never set).
# Format: docs/guide/styles.md#palettes.

background = "#e6e0d4"
lines = ["#b42d1a", "#16130f", "#a57a2a", "#4a6a80", "#5f7a3a", "#7d4a6a", "#c0603a", "#6b645a"]

[palette]
background = "#fbf9f4"
surface = "#ece6da"
raised_surface = "#e6e0d4"
border = "#d8d0c2"
text = "#16130f"
dimmed_text = "#8a8278"
accent = "#b42d1a"
text_on_accent = "#fbf9f4"
selection = "#e6e0d4"
success = "#5f7a3a"
warning = "#a57a2a"
error = "#b42d1a"

[imgui.colors]
Text = "#16130f"
TextDisabled = "#8a8278"
WindowBg = "#fbf9f4"
ChildBg = ["#fbf9f4", 0.0]
PopupBg = ["#ffffff", 0.97]
Border = "#d8d0c2"
BorderShadow = ["#000000", 0.0]
FrameBg = "#ece6da"
FrameBgHovered = "#e2dacb"
FrameBgActive = "#d8cfbf"
TitleBg = "#ece6da"
TitleBgActive = "#e0d7c6"
TitleBgCollapsed = "#ece6da"
MenuBarBg = "#ece6da"
ScrollbarBg = "#fbf9f4"
ScrollbarGrab = "#d8d0c2"
ScrollbarGrabHovered = "#c8bfae"
ScrollbarGrabActive = "#b8ae9b"
CheckMark = "#b42d1a"
SliderGrab = "#c8321e"
SliderGrabActive = "#952414"
Button = "#e6e0d4"
ButtonHovered = "#f4c3b4"
ButtonActive = "#f08a72"
Header = "#e6e0d4"
HeaderHovered = "#e2dacb"
HeaderActive = "#d8cfbf"
Separator = "#d8d0c2"
SeparatorHovered = ["#c8321e", 0.78]
SeparatorActive = "#c8321e"
ResizeGrip = ["#c8321e", 0.20]
ResizeGripHovered = ["#c8321e", 0.67]
ResizeGripActive = ["#c8321e", 0.95]
InputTextCursor = "#16130f"
Tab = "#ece6da"
TabHovered = "#e2dacb"
TabSelected = "#d8cfbf"
TabSelectedOverline = "#c8321e"
TabDimmed = "#ece6da"
TabDimmedSelected = "#ece6da"
TabDimmedSelectedOverline = "#d8d0c2"
PlotLines = "#16130f"
PlotLinesHovered = "#952414"
PlotHistogram = "#a57a2a"
PlotHistogramHovered = "#952414"
TableHeaderBg = "#ece6da"
TableBorderStrong = "#d8d0c2"
TableBorderLight = "#ece6da"
TextLink = "#b42d1a"
TextSelectedBg = ["#c8321e", 0.35]
TreeLines = "#d8d0c2"
DragDropTarget = "#952414"
DragDropTargetBg = ["#c8321e", 0.10]
UnsavedMarker = "#16130f"
NavCursor = "#b42d1a"
DockingPreview = ["#c8321e", 0.55]
DockingEmptyBg = "#e6e0d4"

)FIGURETHEME"},
   {"seal", R"FIGURETHEME(# FIGURE palette "seal": ink windows, paper text, one vermilion.
# Vermilion is spent on what the user touches (slider grabs, check marks, pressed buttons) and on the first line.
# The roles are what FIGURE draws its own widgets with and what the contrast rule checks. The Dear ImGui colours
# given below are hand-tuned (the theme "seal" before looks and palettes); the others are derived from the roles
# (until v0.3.0 they were Dear ImGui's own style's, which the theme had never set).
# Format: docs/guide/styles.md#palettes.

background = "#14120f"
lines = ["#e8664c", "#e9e2d4", "#c9a25a", "#7f9cb0", "#8fa06a", "#a77a95", "#d98b6a", "#a3998c"]

[palette]
background = "#1c1915"
surface = "#2a2520"
raised_surface = "#3a322b"
border = "#3a332c"
text = "#f6f2ea"
dimmed_text = "#8a8278"
accent = "#c8321e"
text_on_accent = "#f6f2ea"
selection = "#3a322b"
success = "#8fa06a"
warning = "#c9a25a"
error = "#e8664c"

[imgui.colors]
Text = "#f6f2ea"
TextDisabled = "#8a8278"
WindowBg = "#1c1915"
ChildBg = ["#1c1915", 0.0]
PopupBg = ["#1c1915", 0.97]
Border = "#3a332c"
BorderShadow = ["#000000", 0.0]
FrameBg = "#2a2520"
FrameBgHovered = "#3a322b"
FrameBgActive = "#4a4038"
TitleBg = "#14120f"
TitleBgActive = "#2a2520"
TitleBgCollapsed = "#14120f"
MenuBarBg = "#14120f"
ScrollbarBg = "#1c1915"
ScrollbarGrab = "#3a332c"
ScrollbarGrabHovered = "#4a4038"
ScrollbarGrabActive = "#5a4e44"
CheckMark = "#f08a72"
SliderGrab = "#d9442c"
SliderGrabActive = "#f08a72"
Button = "#3a322b"
ButtonHovered = "#952414"
ButtonActive = "#c8321e"
Header = "#3a322b"
HeaderHovered = "#3a322b"
HeaderActive = "#4a4038"
Separator = "#3a332c"
SeparatorHovered = ["#d9442c", 0.78]
SeparatorActive = "#d9442c"
ResizeGrip = ["#d9442c", 0.20]
ResizeGripHovered = ["#d9442c", 0.67]
ResizeGripActive = ["#d9442c", 0.95]
InputTextCursor = "#f6f2ea"
Tab = "#2a2520"
TabHovered = "#3a322b"
TabSelected = "#4a4038"
TabSelectedOverline = "#d9442c"
TabDimmed = "#14120f"
TabDimmedSelected = "#2a2520"
TabDimmedSelectedOverline = "#3a332c"
PlotLines = "#e9e2d4"
PlotLinesHovered = "#f08a72"
PlotHistogram = "#c9a25a"
PlotHistogramHovered = "#f08a72"
TableHeaderBg = "#2a2520"
TableBorderStrong = "#3a332c"
TableBorderLight = "#2a2520"
TextLink = "#f08a72"
TextSelectedBg = ["#d9442c", 0.35]
TreeLines = "#3a332c"
DragDropTarget = "#f08a72"
DragDropTargetBg = ["#d9442c", 0.10]
UnsavedMarker = "#f6f2ea"
NavCursor = "#f08a72"
DockingPreview = ["#d9442c", 0.55]
DockingEmptyBg = "#14120f"

)FIGURETHEME"},
   {"solarized-dark", R"FIGURETHEME(# FIGURE palette "solarized-dark": Solarized, dark: Ethan Schoonover's precision colours.
# Source: https://github.com/altercation/solarized (README.md, commit 4f90b03).
# MIT licence, Copyright (c) 2011 Ethan Schoonover.
# Licence: third_party/palettes/LICENSE-solarized.txt, installed in share/licenses/solarized/.
# The hex values are the upstream ones, by their upstream names (after each role).
# Text is base2, dimmed text base1: base0 and base1, the body text of the dark mode, are below 4.5:1 on base02
# (the surfaces). Solarized has two dark backgrounds only, so surface and raised surface are both base02.
# The accent is cyan: blue, the usual one, keeps 4.1:1 with base03 and 3.4:1 with base3 (the rule asks 4.5:1).
# Format: docs/guide/styles.md#palettes. The Dear ImGui colours are derived from the roles.

lines = ["#268bd2", "#859900", "#b58900", "#cb4b16", "#d33682", "#2aa198", "#6c71c4", "#dc322f"]

[palette]
background     = "#002b36"   # base03
surface        = "#073642"   # base02
raised_surface = "#073642"   # base02
border         = "#586e75"   # base01
text           = "#eee8d5"   # base2
dimmed_text    = "#93a1a1"   # base1
accent         = "#2aa198"   # cyan
text_on_accent = "#002b36"   # base03
selection      = "#073642"   # base02
success        = "#859900"   # green
warning        = "#b58900"   # yellow
error          = "#dc322f"   # red
)FIGURETHEME"},
   {"solarized-light", R"FIGURETHEME(# FIGURE palette "solarized-light": Solarized, light: Ethan Schoonover's precision colours.
# Source: https://github.com/altercation/solarized (README.md, commit 4f90b03).
# MIT licence, Copyright (c) 2011 Ethan Schoonover.
# Licence: third_party/palettes/LICENSE-solarized.txt, installed in share/licenses/solarized/.
# The hex values are the upstream ones, by their upstream names (after each role).
# Text is base02 and dimmed text base00: base00 and base01, the body text of the light mode, are below 4.5:1 on
# base2 (the surfaces). Solarized has two light backgrounds only, so surface and raised surface are both base2.
# The accent is cyan, with base03 on it: blue keeps 4.1:1 with base03 and 3.4:1 with base3.
# Lines leave out yellow, green and cyan, below 3:1 on base3.
# Format: docs/guide/styles.md#palettes. The Dear ImGui colours are derived from the roles.

lines = ["#268bd2", "#cb4b16", "#d33682", "#6c71c4", "#dc322f", "#586e75"]

[palette]
background     = "#fdf6e3"   # base3
surface        = "#eee8d5"   # base2
raised_surface = "#eee8d5"   # base2
border         = "#93a1a1"   # base1
text           = "#073642"   # base02
dimmed_text    = "#657b83"   # base00
accent         = "#2aa198"   # cyan
text_on_accent = "#002b36"   # base03
selection      = "#eee8d5"   # base2
success        = "#859900"   # green
warning        = "#b58900"   # yellow
error          = "#dc322f"   # red
)FIGURETHEME"},
   {"tokyo-night", R"FIGURETHEME(# FIGURE palette "tokyo-night": Tokyo Night, the lights of Downtown Tokyo at night.
# Source: https://github.com/enkia/tokyo-night-vscode-theme (README.md and themes/tokyo-night-color-theme.json, commit da5546b).
# MIT licence, Copyright (c) 2018-present Enkia.
# Licence: third_party/palettes/LICENSE-tokyo-night.txt, installed in share/licenses/tokyo-night/.
# The hex values are the upstream ones, by their upstream names (after each role).
# Selection is #363b54: the theme's own selection colours are translucent (#515c7e4d), and roles are opaque.
# Format: docs/guide/styles.md#palettes. The Dear ImGui colours are derived from the roles.

background = "#16161e"   # side bar, behind the windows
lines = ["#7aa2f7", "#9ece6a", "#e0af68", "#f7768e", "#bb9af7", "#7dcfff", "#ff9e64", "#73daca"]

[palette]
background     = "#1a1b26"   # editor background
surface        = "#16161e"   # side bar and widgets
raised_surface = "#24283b"   # Storm background
border         = "#414868"   # terminal black
text           = "#c0caf5"   # variables, terminal white
dimmed_text    = "#787c99"   # interface foreground
accent         = "#7aa2f7"   # function names, terminal blue
text_on_accent = "#1a1b26"   # editor background
selection      = "#363b54"   # indent guides, terminal black
success        = "#9ece6a"   # strings
warning        = "#e0af68"   # parameters, terminal yellow
error          = "#f7768e"   # keywords, terminal red
)FIGURETHEME"},
};
