// generated from themes/*.toml by scripts/fpm_package.py
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

base = "dark"
background = "#000000"
lines = "okabe-ito"

[imgui.vars]
WindowRounding = 0
ChildRounding = 0
FrameRounding = 0
PopupRounding = 0
ScrollbarRounding = 0
GrabRounding = 0
TabRounding = 0
WindowBorderSize = 1
FrameBorderSize = 1
PopupBorderSize = 1

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

[implot.vars]
PlotBorderSize = 1

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
   {"light", R"FIGURETHEME(# FIGURE theme "light": Dear ImGui's light style, with ImPlot's default line colours.
# Format: docs/guide/styles.md#theme-files.

base = "light"
background = "#cccccc"
)FIGURETHEME"},
   {"paper", R"FIGURETHEME(# FIGURE theme "paper": for publication, black on white.
# Screenshots that go into papers and slides: white background, black text and thin borders, a light grey grid, and
# lines in the five colours of Okabe and Ito's colour-blind-safe set that keep 3:1 against white (its orange, sky blue
# and yellow do not), in order of greyscale lightness, black first.

base = "light"
background = "#ffffff"
lines = ["#000000", "#0072b2", "#d55e00", "#009e73", "#cc79a7"]

[imgui.vars]
WindowRounding = 0
ChildRounding = 0
FrameRounding = 0
PopupRounding = 0
ScrollbarRounding = 0
GrabRounding = 0
TabRounding = 0
WindowBorderSize = 1
FrameBorderSize = 1

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

[implot.vars]
PlotBorderSize = 1
MinorAlpha = 0.5

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
   {"seal-light", R"FIGURETHEME(# FIGURE theme "seal-light": the seal on paper.
# Paper windows, ink text, the same vermilion accents.
# Format: docs/guide/styles.md#theme-files. Entries not given come from `base`.

base = "light"
background = "#e6e0d4"
lines = ["#b42d1a", "#16130f", "#a57a2a", "#4a6a80", "#5f7a3a", "#7d4a6a", "#c0603a", "#6b645a"]

[imgui.vars]
# the seal's edges are cut straight: no rounding anywhere
WindowRounding = 0
ChildRounding = 0
FrameRounding = 0
PopupRounding = 0
ScrollbarRounding = 0
GrabRounding = 0
TabRounding = 0

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
   {"seal", R"FIGURETHEME(# FIGURE theme "seal": ink windows, paper text, one vermilion (the default).
# Vermilion is spent on what the user touches (slider grabs, check marks, pressed buttons) and on the first line.
# Format: docs/guide/styles.md#theme-files. Entries not given come from `base`.

base = "dark"
background = "#14120f"
lines = ["#e8664c", "#e9e2d4", "#c9a25a", "#7f9cb0", "#8fa06a", "#a77a95", "#d98b6a", "#a3998c"]

[imgui.vars]
# the seal's edges are cut straight: no rounding anywhere
WindowRounding = 0
ChildRounding = 0
FrameRounding = 0
PopupRounding = 0
ScrollbarRounding = 0
GrabRounding = 0
TabRounding = 0

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
};
