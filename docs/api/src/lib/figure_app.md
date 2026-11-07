---
title: figure_app
---

# figure_app

> figure_app, the application: window, frame loop and lazy redraw.

 The whole life of a FIGURE program is one loop:

```fortran
 call app%init('My tool', 1280, 720)
 do while (app%next_frame())
    ! declare the UI: widgets return what happened this frame
 enddo
 call app%destroy()
```

 `next_frame` renders the previous frame, then waits for input and opens the next one (lazy redraw: once the UI
 settles it sleeps until input or `max_wait`, so an idle window costs a fraction of a percent of one core); it
 returns `.false.` when the user closes the window. There are no widget objects, handles or callbacks: the state is
 the application's own variables.

**Source**: `src/lib/figure_app.F90`

**Dependencies**

```mermaid
graph LR
  figure_app["figure_app"] --> figure_base["figure_base"]
  figure_app["figure_app"] --> figure_c_native["figure_c_native"]
  figure_app["figure_app"] --> figure_icons["figure_icons"]
  figure_app["figure_app"] --> iso_c_binding["iso_c_binding"]
  figure_app["figure_app"] --> iso_fortran_env["iso_fortran_env"]
```

## Contents

- [app_object](#app-object)
- [init](#init)
- [init_headless](#init-headless)
- [set_icon_image](#set-icon-image)
- [set_icon_glyph](#set-icon-glyph)
- [init_remote](#init-remote)
- [set_lazy](#set-lazy)
- [set_style](#set-style)
- [palette_color](#palette-color)
- [notify](#notify)
- [notifications](#notifications)
- [set_font](#set-font)
- [load_style](#load-style)
- [save_style](#save-style)
- [set_docking](#set-docking)
- [request_frames](#request-frames)
- [set_confirm_quit](#set-confirm-quit)
- [quit](#quit)
- [set_title](#set-title)
- [open_file_dialog](#open-file-dialog)
- [save_file_dialog](#save-file-dialog)
- [open_folder_dialog](#open-folder-dialog)
- [open_file_browser](#open-file-browser)
- [save_file_browser](#save-file-browser)
- [file_dialog_result](#file-dialog-result)
- [save_image](#save-image)
- [image_result](#image-result)
- [save_layout](#save-layout)
- [load_layout](#load-layout)
- [destroy](#destroy)
- [show_file_dialog](#show-file-dialog)
- [show_file_browser](#show-file-browser)
- [frame_options](#frame-options)
- [next_frame](#next-frame)
- [quit_requested](#quit-requested)
- [dropped](#dropped)
- [title](#title)
- [content_scale](#content-scale)
- [opt](#opt)
- [opt_len](#opt-len)

## Derived Types

### app_object

A FIGURE application (one per program).

 The native layer owns the lifecycle state (initialized, frame open) and rejects out-of-order calls with
 `FIG_ERR_STATE`; only `in_frame` is mirrored here, because `next_frame` must know whether to close a frame.

#### Components

| Name | Type | Attributes | Description |
|------|------|------------|-------------|
| `in_frame` | logical |  | A frame is open. |

#### Type-Bound Procedures

| Name | Attributes | Description |
|------|------------|-------------|
| `init` | pass(self) | Open the window. |
| `init_headless` | pass(self) | Contexts only, no window (tests). |
| `init_remote` | pass(self) | The UI in a web browser (no window, display or GPU). |
| `next_frame` | pass(self) | Close the current frame, open the next; false on quit. |
| `set_lazy` | pass(self) | Lazy redraw on/off, longest sleep. |
| `set_style` | pass(self) | The style: a name, or a look and a palette. |
| `palette_color` | pass(self) | The colour of a palette role in effect. |
| `set_docking` | pass(self) | Docking on (the default) or off. |
| `set_font` | pass(self) | The default font and its size. |
| `load_style` | pass(self) | A theme file. |
| `save_style` | pass(self) | The style in effect, as a theme file. |
| `request_frames` | pass(self) | Redraw without waiting for input. |
| `set_confirm_quit` | pass(self) | Report a quit request instead of quitting. |
| `quit_requested` | pass(self) | The user asked to quit (once per request). |
| `dropped` | pass(self) | The files and folders dropped on the window this frame. |
| `quit` | pass(self) | End the loop at the next frame. |
| `set_title` | pass(self) | The window's title, after init. |
| `title` | pass(self) | The window's title. |
| `open_file_dialog` | pass(self) | The system's dialog to choose a file to open. |
| `save_file_dialog` | pass(self) | The system's dialog to choose where to save. |
| `open_folder_dialog` | pass(self) | The system's dialog to choose a folder. |
| `open_file_browser` | pass(self) | FIGURE's browser to choose a file (or a folder) to open. |
| `save_file_browser` | pass(self) | FIGURE's browser to choose where to save. |
| `file_dialog_result` | pass(self) | The answer to a dialog or a browser, once given. |
| `save_image` | pass(self) | A rectangle of the window as a PNG file, after this frame. |
| `image_result` | pass(self) | The outcome of save_image, once. |
| `save_layout` | pass(self) | The arrangement of the windows (docking included) to a file. |
| `load_layout` | pass(self) | An arrangement from a file, applied before the next frame. |
| `notify` | pass(self) | Tell the user something, in a notification. |
| `notifications` | pass(self) | The notifications kept (the last 100). |
| `content_scale` | pass(self) | Display content scale. |
| `destroy` | pass(self) | Close everything. |
| `set_icon_image` | pass(self) | The window's icon from an image. |
| `set_icon_glyph` | pass(self) | The window's icon from an ICON_*. |
| `set_icon` |  | The window's icon: an image or an ICON_*. |

## Subroutines

### init

Open the window (`width` x `height` logical pixels) and create the ImGui/ImPlot contexts.

 Window positions and sizes are not saved by default: with `ini_file`, Dear ImGui keeps them in that file, read
 at the first frame and written while the program runs (its `imgui.ini`).

 `decorations='figure'` opens the window without the system's frame and draws one: a title bar with the icon
 (`set_icon`), the program's main menu bar (`ig_begin_main_menu_bar`) inside it, the title centred, and the
 minimize, maximize (restore) and close buttons, in the colours of the palette's roles. The bar drags the window,
 its edges resize it, a double-click on it maximizes; close takes the quit path of the system's close button
 (`set_confirm_quit`). `buttons` puts them on the `'right'` (the default) or the `'left'` (the default on macOS).

```fortran
subroutine init(self, title, width, height, vsync, stat, ini_file, decorations, buttons)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `title` | character(len=*) | in |  | Window title. |
| `width` | integer(kind=int32) | in |  | Width [logical pixels]. |
| `height` | integer(kind=int32) | in |  | Height [logical pixels]. |
| `vsync` | logical | in | optional | Synchronize with the display (default true). |
| `stat` | integer(kind=int32) | out | optional | `FIG_ERR_ARGUMENT` for a wrong size or option. |
| `ini_file` | character(len=*) | in | optional | File keeping the window layout (default: none). |
| `decorations` | character(len=*) | in | optional | The window's frame: `'native'` (default) or `'figure'`. |
| `buttons` | character(len=*) | in | optional | With `'figure'`: `'right'` or `'left'` (default: the |

**Call graph**

```mermaid
flowchart TD
  init["init"] --> fig_init["fig_init"]
  init["init"] --> fig_set_ini_file["fig_set_ini_file"]
  init["init"] --> figure_check["figure_check"]
  init["init"] --> frame_options["frame_options"]
  style init fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### init_headless

Create the contexts on a virtual `width` x `height` display, without window or GPU.

 `decorations='figure'` draws the title bar of `init`'s `decorations='figure'` as in a window, for tests: its
 buttons' actions are recorded as state (`test_frame_state`), close takes the quit path.

```fortran
subroutine init_headless(self, width, height, stat, decorations, buttons)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `width` | integer(kind=int32) | in |  | Width [pixels]. |
| `height` | integer(kind=int32) | in |  | Height [pixels]. |
| `stat` | integer(kind=int32) | out | optional | Status: `FIG_ERR_ARGUMENT` for a wrong size or option. |
| `decorations` | character(len=*) | in | optional | `'native'` (default: no bar) or `'figure'`. |
| `buttons` | character(len=*) | in | optional | With `'figure'`: `'right'` or `'left'`. |

**Call graph**

```mermaid
flowchart TD
  init_headless["init_headless"] --> fig_init_headless["fig_init_headless"]
  init_headless["init_headless"] --> figure_check["figure_check"]
  init_headless["init_headless"] --> frame_options["frame_options"]
  style init_headless fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### set_icon_image

The window's icon (task bar, dock, the title bar of `decorations='figure'`) from an image, `image(4, width,
 height)`: `image(:, i, j)` = R, G, B, A of pixel (i, j), j = 1 the top row. Window mode only; 1 to 1024 pixels a
 side (64 x 64 or 256 x 256 are usual).

```fortran
subroutine set_icon_image(self, image, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `image` | integer(kind=int8) | in | contiguous, target | Pixels. |
| `stat` | integer(kind=int32) | out | optional | modes, `FIG_ERR_ARGUMENT` for a wrong shape. |

**Call graph**

```mermaid
flowchart TD
  set_icon_image["set_icon_image"] --> fig_set_icon_rgba["fig_set_icon_rgba"]
  set_icon_image["set_icon_image"] --> figure_check["figure_check"]
  set_icon_image["set_icon_image"] --> figure_fail["figure_fail"]
  style set_icon_image fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### set_icon_glyph

The window's icon from one of the bundled icons, `ICON_*`: rendered at 64 x 64 pixels in the palette's text on
 accent colour on a rounded square of its accent; the title bar of `decorations='figure'` shows the glyph in the
 accent colour. Window mode only.

```fortran
subroutine set_icon_glyph(self, icon, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `icon` | character(len=*) | in |  | One `ICON_*` constant. |
| `stat` | integer(kind=int32) | out | optional | `FIG_ERR_ARGUMENT` if `icon` is not one icon. |

**Call graph**

```mermaid
flowchart TD
  set_icon_glyph["set_icon_glyph"] --> fig_set_icon_glyph["fig_set_icon_glyph"]
  set_icon_glyph["set_icon_glyph"] --> figure_check["figure_check"]
  style set_icon_glyph fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### init_remote

Create the contexts and serve the UI to a web browser on `http://host:port/` instead of opening a window: the
 program needs no display or GPU (a cluster node will do). One browser at a time, which can come and go while the
 program runs. The page and its connection need an access token in the address (`http://localhost:8080/?token=...`,
 printed at start, returned in `url`): 32 random hex digits, or `token` (`token=''` disables it: anyone who reaches
 the port then controls the program). Keep the default host (127.0.0.1) and reach a remote machine through an SSH
 tunnel (`ssh -L 8080:localhost:8080 node`).

 A browser has no vsync to pace the program, so frames are capped at `max_fps` per second (default 60), and a
 frame is sent only once the previous one has left: with a slow client the newest frame goes, the ones in between
 are skipped. A frame equal to the last one sent is not sent again. Vertices travel in 12 bytes instead of 20, and
 `compress` deflates frames and textures: `'auto'` (default) while the client is the bottleneck (frames are being
 skipped), `'always'`, or `'never'`; deflate costs about 7 ms of CPU per MB and shrinks frames 2.5 to 3.5 times.

```fortran
subroutine init_remote(self, port, host, width, height, port_used, quiet, max_fps, compress, token, url, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `port` | integer(kind=int32) | in | optional | Port (default 8080; 0: any free port). |
| `host` | character(len=*) | in | optional | Address to listen on (default 127.0.0.1). |
| `width` | integer(kind=int32) | in | optional | Display width until the browser's [pixels] (default 1280). |
| `height` | integer(kind=int32) | in | optional | Display height until the browser's [pixels] (default 800). |
| `port_used` | integer(kind=int32) | out | optional | The port listened on (useful with port 0). |
| `quiet` | logical | in | optional | Do not print the address to open (default false). |
| `max_fps` | real(kind=real64) | in | optional | Most frames per second (default 60; 0: no cap). |
| `compress` | character(len=*) | in | optional | Deflate frames and textures: 'auto', 'always', 'never'. |
| `token` | character(len=*) | in | optional | Access token (default: random; '': none). |
| `url` | character(len=*) | out | optional | The address to open, with the token (blank-padded). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  init_remote["init_remote"] --> fig_init_remote["fig_init_remote"]
  init_remote["init_remote"] --> fig_remote_token["fig_remote_token"]
  init_remote["init_remote"] --> fig_set_remote_compress["fig_set_remote_compress"]
  init_remote["init_remote"] --> fig_set_remote_fps["fig_set_remote_fps"]
  init_remote["init_remote"] --> fig_set_remote_token["fig_set_remote_token"]
  init_remote["init_remote"] --> figure_check["figure_check"]
  init_remote["init_remote"] --> figure_fail["figure_fail"]
  style init_remote fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### set_lazy

Lazy redraw (default on): once the UI settles, sleep until input or `max_wait` seconds (default 0.5).

```fortran
subroutine set_lazy(self, enabled, max_wait)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `enabled` | logical | in |  | Lazy redraw on. |
| `max_wait` | real(kind=real64) | in | optional | Longest sleep [s]: the refresh period of live data. |

**Call graph**

```mermaid
flowchart TD
  set_lazy["set_lazy"] --> fig_set_lazy["fig_set_lazy"]
  style set_lazy fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### set_style

The style of the interface, the plots and the window's background, after `init*`: by name, or by its two parts,
 a look (the geometry) and a palette (the colours). Changing one part keeps the other.

 Names (each a theme file, `themes/<name>.toml`, embedded):

 - `'seal'` (the default), `'seal-light'`: FIGURE's, from its mark: ink (or paper) and one vermilion, spent on
   what the user touches and on the first plotted line; square corners;
 - `'paper'`: for publication, black on white, thin borders, line colours that survive greyscale printing;
 - `'high-contrast'`: white on black with yellow accents, text at 7:1 or more (WCAG AAA);
 - `'dark'`, `'light'`, `'classic'`: Dear ImGui's own styles, with ImPlot's default line colours.

 Looks: `'seal'`, `'fusion'`, `'adwaita'`, `'fluent'`. Palettes: `'seal'`, `'seal-light'`, `'paper'`,
 `'high-contrast'`, `'nord'`, `'solarized-dark'`, `'solarized-light'`, `'gruvbox-dark'`, `'gruvbox-light'`,
 `'dracula'`, `'catppuccin-mocha'`, `'catppuccin-latte'`, `'tokyo-night'`, `'one-dark'`, and `'auto'`, which
 follows the system's light or dark setting (`auto_dark`, default `'seal'`; `auto_light`, default `'seal-light'`)
 and changes with it while the program runs; in headless and remote modes the setting is unknown and counts as
 dark. A palette's colours are derived from twelve roles and checked for contrast (docs, Styles, Palettes).

 The parts are applied in order, all or none: `name`, then `look`, then `palette`, then `lines` (`'okabe-ito'`
 replaces the line colours with Okabe and Ito's colour-blind-safe set). The environment variable `FIGURE_STYLE`
 picks the style at initialisation; this call overrides it. The font and its size are kept; colours and variables
 changed by name are reset by the part that sets them.

```fortran
subroutine set_style(self, name, lines, stat, look, palette, auto_dark, auto_light)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `name` | character(len=*) | in | optional | Style name. |
| `lines` | character(len=*) | in | optional | Line palette: `'okabe-ito'` (default: the style's own). |
| `stat` | integer(kind=int32) | out | optional | palette, a palette below the contrast rule, or no argument. |
| `look` | character(len=*) | in | optional | Look: the geometry (rounding, padding, spacing, borders). |
| `palette` | character(len=*) | in | optional | Palette: the colours, or `'auto'`. |
| `auto_dark` | character(len=*) | in | optional | Palette of `'auto'` on a dark system (default `'seal'`). |
| `auto_light` | character(len=*) | in | optional | Palette of `'auto'` on a light system (default |

**Call graph**

```mermaid
flowchart TD
  set_style["set_style"] --> fig_set_style_parts["fig_set_style_parts"]
  set_style["set_style"] --> figure_check["figure_check"]
  set_style["set_style"] --> opt["opt"]
  set_style["set_style"] --> opt_len["opt_len"]
  style set_style fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### palette_color

The colour of a palette role in effect, as `[r, g, b, a]` in [0, 1]: `'background'`, `'surface'`,
 `'raised_surface'`, `'border'`, `'text'`, `'dimmed_text'`, `'accent'`, `'text_on_accent'`, `'selection'`,
 `'success'`, `'warning'`, `'error'`. With a style that has no palette (`'dark'`, `'light'`, `'classic'`, a theme
 file without one), the roles are read from Dear ImGui's colours (`WindowBg`, `FrameBg`, `Button`, `Border`,
 `Text`, `TextDisabled`, `CheckMark`, `Header`), and success, warning and error are Okabe and Ito's bluish green,
 orange and vermilion. After `init*`; the same in every mode.

```fortran
subroutine palette_color(self, role, rgba, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `role` | character(len=*) | in |  | Role name. |
| `rgba` | real(kind=real64) | out |  | Colour, components in [0, 1]. |
| `stat` | integer(kind=int32) | out | optional | Status: `FIG_ERR_ARGUMENT` for an unknown role. |

**Call graph**

```mermaid
flowchart TD
  palette_color["palette_color"] --> fig_palette_color["fig_palette_color"]
  palette_color["palette_color"] --> figure_check["figure_check"]
  style palette_color fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### notify

Tell the user something without a dialog: a notification drawn by FIGURE after the program's windows, in the
 bottom-right corner (above a bottom side bar), the newest at the bottom, older ones stacked above. `kind`:
 `'info'` (default), `'success'`, `'warning'` or `'error'`, drawn with its palette role (accent, success, warning,
 error) and its icon (`ICON_INFO`, `ICON_CIRCLE_CHECK`, `ICON_TRIANGLE_ALERT`, `ICON_CIRCLE_X`). It stays
 `seconds` (default 5; 0 or less: until clicked), fading out in its last half second, timed by the frame time
 (the fixed one in headless mode and in recordings); a click dismisses it. The last 100 are kept
 (`notifications`). Statuses: `FIG_ERR_STATE` before `init*` or from a task, `FIG_ERR_ARGUMENT` for an unknown
 kind. The same in every mode.

**Attributes**: recursive

```fortran
subroutine notify(self, text, kind, seconds, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `text` | character(len=*) | in |  | What to tell (UTF-8; wrapped). |
| `kind` | character(len=*) | in | optional | 'info', 'success', 'warning' or 'error'. |
| `seconds` | real(kind=real64) | in | optional | Time shown [s] (default 5; <= 0: until clicked). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  notify["notify"] --> fig_notify["fig_notify"]
  notify["notify"] --> figure_check["figure_check"]
  notify["notify"] --> figure_fail["figure_fail"]
  notify["notify"] --> figure_refused["figure_refused"]
  style notify fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### notifications

The notifications kept, the last 100, oldest first: their texts (`list`, padded with blanks to the longest),
 their kinds (`'info'`, ...) and whether each is still shown (not yet timed out or dismissed). None before
 `init*`.

```fortran
subroutine notifications(self, list, kinds, shown)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | in |  | Application. |
| `list` | character(len=:) | out | allocatable | Texts. |
| `kinds` | character(len=7) | out | allocatable, optional | Kinds. |
| `shown` | logical | out | allocatable, optional | Still shown. |

**Call graph**

```mermaid
flowchart TD
  notifications["notifications"] --> fig_notification_count["fig_notification_count"]
  notifications["notifications"] --> fig_notification_get["fig_notification_get"]
  style notifications fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### set_font

The default font of the interface, after `init*`: `'plex-sans'` (IBM Plex Sans, bundled: the default, at 15
 logical pixels), `'plex-mono'` (IBM Plex Mono, bundled: monospace, every character as wide), `'proggy'` (Dear
 ImGui's own 13-pixel bitmap font), or the path of a TrueType/OpenType file; `size` in logical pixels (multiplied
 by the display's content scale), kept if absent.

```fortran
subroutine set_font(self, font, size, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `font` | character(len=*) | in |  | Font. |
| `size` | real(kind=real64) | in | optional | Size [logical pixels], in (0, 200]. |
| `stat` | integer(kind=int32) | out | optional | `FIG_ERR_ARGUMENT` if it is not a font or the size is wrong. |

**Call graph**

```mermaid
flowchart TD
  set_font["set_font"] --> fig_set_font["fig_set_font"]
  set_font["set_font"] --> figure_check["figure_check"]
  set_font["set_font"] --> figure_fail["figure_fail"]
  style set_font fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### load_style

Apply a theme file (the format of the files in `themes/`: docs, Styles, Theme files), after `init*`. Sizes in the
 file are logical pixels; what the file does not set comes from its `base`.

```fortran
subroutine load_style(self, file, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `file` | character(len=*) | in |  | Theme file. |
| `stat` | integer(kind=int32) | out | optional | malformed (the message gives the line). |

**Call graph**

```mermaid
flowchart TD
  load_style["load_style"] --> fig_load_style["fig_load_style"]
  load_style["load_style"] --> figure_check["figure_check"]
  style load_style fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### save_style

Write the style in effect as a theme file: its base, background, line colours, and every colour and variable
 that differs from the base (sizes in logical pixels; colours as 8-bit hex, alphas exact). Changes made by name
 or in the style editor (`ig_show_style_editor`) are kept; `load_style` reads the file back.

```fortran
subroutine save_style(self, file, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `file` | character(len=*) | in |  | Theme file to write. |
| `stat` | integer(kind=int32) | out | optional |  |

**Call graph**

```mermaid
flowchart TD
  save_style["save_style"] --> fig_save_style["fig_save_style"]
  save_style["save_style"] --> figure_check["figure_check"]
  style save_style fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### set_docking

Docking on (the default since `init*`) or off: with docking on, a window dragged by its title bar docks into
 another window or into a dock space (`ig_dock_space`). After `init*`.

```fortran
subroutine set_docking(self, enabled, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `enabled` | logical | in |  | Docking on. |
| `stat` | integer(kind=int32) | out | optional |  |

**Call graph**

```mermaid
flowchart TD
  set_docking["set_docking"] --> fig_set_docking["fig_set_docking"]
  set_docking["set_docking"] --> figure_check["figure_check"]
  style set_docking fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### request_frames

Draw at least `n` more frames without waiting for input (e.g. after new data arrived).

```fortran
subroutine request_frames(self, n)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `n` | integer(kind=int32) | in |  | Frames. |

**Call graph**

```mermaid
flowchart TD
  request_frames["request_frames"] --> fig_request_frames["fig_request_frames"]
  style request_frames fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### set_confirm_quit

With `enabled`, the window's close button (and the system's quit) no longer ends `next_frame`: the request is
 reported by `quit_requested`, and the program quits with `quit` (after asking to save, for example).

```fortran
subroutine set_confirm_quit(self, enabled)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `enabled` | logical | in |  | Ask first. |

**Call graph**

```mermaid
flowchart TD
  set_confirm_quit["set_confirm_quit"] --> fig_set_confirm_quit["fig_set_confirm_quit"]
  style set_confirm_quit fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### quit

End the loop: the next `next_frame` returns `.false.` (in every mode).

```fortran
subroutine quit(self)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |

**Call graph**

```mermaid
flowchart TD
  quit["quit"] --> fig_quit["fig_quit"]
  style quit fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### set_title

The window's title, after `init`: the document being edited and a mark when it has changes, for example. Shown in
 window mode; in remote and headless modes it is kept (read back by `title`) and nothing shows it.

```fortran
subroutine set_title(self, text, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `text` | character(len=*) | in |  | Title. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  set_title["set_title"] --> fig_set_title["fig_set_title"]
  set_title["set_title"] --> figure_check["figure_check"]
  style set_title fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### open_file_dialog

Show the system's dialog to choose a file to open. It does not block: the interface keeps drawing, and the answer
 is read with `file_dialog_result(id, ...)` on the following frames. `filters`: entries `'name|pattern'`, the
 pattern being extensions separated by `;` (`'Input files|input;inp'`, `'All files|*'`). Window mode only:
 `FIG_ERR_STATE` in remote and headless modes (FIGURE's own browser, `open_file_browser`, works there).

```fortran
subroutine open_file_dialog(self, id, filters, default_path, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `id` | character(len=*) | in |  | Dialog id (any text, used to read the answer). |
| `filters` | character(len=*) | in | optional | File type filters. |
| `default_path` | character(len=*) | in | optional | Folder or file to start from (relative: to the |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  open_file_dialog["open_file_dialog"] --> show_file_dialog["show_file_dialog"]
  style open_file_dialog fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### save_file_dialog

Show the system's dialog to choose where to save (a new or an existing file); as `open_file_dialog`.

```fortran
subroutine save_file_dialog(self, id, filters, default_path, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `id` | character(len=*) | in |  | Dialog id. |
| `filters` | character(len=*) | in | optional | File type filters. |
| `default_path` | character(len=*) | in | optional | Folder or file to start from (relative: to the |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  save_file_dialog["save_file_dialog"] --> show_file_dialog["show_file_dialog"]
  style save_file_dialog fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### open_folder_dialog

Show the system's dialog to choose a folder; as `open_file_dialog`.

```fortran
subroutine open_folder_dialog(self, id, default_path, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `id` | character(len=*) | in |  | Dialog id. |
| `default_path` | character(len=*) | in | optional | Folder to start from (relative: to the working |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  open_folder_dialog["open_folder_dialog"] --> show_file_dialog["show_file_dialog"]
  style open_folder_dialog fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### open_file_browser

Show FIGURE's file browser to choose a file to open (or, with `folders`, a folder): a modal drawn by FIGURE in
 Dear ImGui, in the palette's colours, the same in window, remote and headless modes (in remote mode it lists the
 files of the machine the program runs on). It does not block: the answer is read with `file_dialog_result(id,
 ...)`, as a system dialog's, so a program switches between the two by changing this call. The browser lists the
 folder's entries (folders first, sizes, modification times; sorted by a click on a column's header), filtered by
 `filters` (as `open_file_dialog`'s, chosen in a list) with hidden files on request; a path field (Enter goes
 there, Tab completes), the parent folder, places (home, the working directory, the file systems' roots, the
 recent folders kept between runs in FIGURE's settings file) and a new folder. Escape or Cancel cancels. A folder
 that cannot be read is reported in the browser. Statuses: `FIG_ERR_STATE` before `init*`, from a task, or for an
 id with a dialog or a browser still open; `FIG_ERR_ARGUMENT` for a malformed filter.

**Attributes**: recursive

```fortran
subroutine open_file_browser(self, id, filters, default_path, folders, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `id` | character(len=*) | in |  | Dialog id (any text, used to read the answer). |
| `filters` | character(len=*) | in | optional | File type filters, `'name\|pattern'` (the first in effect). |
| `default_path` | character(len=*) | in | optional | Folder to start in, or a file (its folder; the file |
| `folders` | logical | in | optional | Choose a folder instead of a file (default false). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  open_file_browser["open_file_browser"] --> figure_refused["figure_refused"]
  open_file_browser["open_file_browser"] --> show_file_browser["show_file_browser"]
  style open_file_browser fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### save_file_browser

Show FIGURE's file browser to choose where to save: a name typed in the folder shown, or an existing file; a file
 that exists is replaced only after the user says so. As `open_file_browser`; `default_path` may name the file
 to propose (its folder need exist, the file need not).

**Attributes**: recursive

```fortran
subroutine save_file_browser(self, id, filters, default_path, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `id` | character(len=*) | in |  | Dialog id. |
| `filters` | character(len=*) | in | optional | File type filters, `'name\|pattern'`. |
| `default_path` | character(len=*) | in | optional | Folder to start in, or the file to propose. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  save_file_browser["save_file_browser"] --> figure_refused["figure_refused"]
  save_file_browser["save_file_browser"] --> show_file_browser["show_file_browser"]
  style save_file_browser fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### file_dialog_result

The answer to the dialog or the browser `id`: `done` false while it is open; once answered, `done` true and
 either `path` (the file or folder chosen, absolute for the browser) or `cancelled` true. The answer is given once;
 then the id is free again, and until the next dialog `done` is false: poll it every frame. A dialog that failed
 (Linux without a portal or zenity) gives `done` true and `FIG_ERR_FAILED` with the reason.

```fortran
subroutine file_dialog_result(self, id, path, done, cancelled, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `id` | character(len=*) | in |  | Dialog id. |
| `path` | character(len=:) | out | allocatable | Chosen path ('' while open or if cancelled). |
| `done` | logical | out |  | The dialog was answered. |
| `cancelled` | logical | out | optional | The user cancelled it. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  file_dialog_result["file_dialog_result"] --> fig_file_dialog_result["fig_file_dialog_result"]
  file_dialog_result["file_dialog_result"] --> figure_check["figure_check"]
  style file_dialog_result fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### save_image

Write the rectangle (xmin, ymin)-(xmax, ymax) of the window [logical pixels, as `ig_item_rect` and
 `test_window_rect` give them] as a PNG file, at the screen's resolution, when the current frame is rendered.
 Ask for it outside the frame in which a menu or popup covers the rectangle (they would be in the picture).
 The outcome comes once, from `image_result`. Window mode only: in remote and headless modes there are no
 pixels on the program's side, `FIG_ERR_STATE`; an empty rectangle or file name, `FIG_ERR_ARGUMENT`.

```fortran
subroutine save_image(self, path, xmin, ymin, xmax, ymax, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `path` | character(len=*) | in |  | PNG file. |
| `xmin` | real(kind=real64) | in |  | Left. |
| `ymin` | real(kind=real64) | in |  | Top. |
| `xmax` | real(kind=real64) | in |  | Right. |
| `ymax` | real(kind=real64) | in |  | Bottom. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  save_image["save_image"] --> fig_save_image["fig_save_image"]
  save_image["save_image"] --> figure_check["figure_check"]
  style save_image fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### image_result

The outcome of `save_image`, once, after the frame that wrote it: `done` true and the file `path`, or
 `FIG_ERR_FAILED` with the reason (the file cannot be written). `done` false before and after: poll it every frame.

```fortran
subroutine image_result(self, path, done, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `path` | character(len=:) | out | allocatable | The file ('' until done). |
| `done` | logical | out |  | Written, or failed. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  image_result["image_result"] --> fig_image_result["fig_image_result"]
  image_result["image_result"] --> figure_check["figure_check"]
  style image_result fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### save_layout

Write the layout to `path`: the windows' positions, sizes and docking (the dock nodes and which window is in
 which), the tables' columns: Dear ImGui's settings, as its ini text, for every window shown in this session and
 those read before. `comment` (lines separated by `new_line('a')`) is written first, each line led by '; ', which
 `load_layout` skips: the program's own state (the windows it opens on demand, say) for itself to read back.
 Any mode. `FIG_ERR_FAILED` if the file cannot be written.

```fortran
subroutine save_layout(self, path, comment, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `path` | character(len=*) | in |  | File. |
| `comment` | character(len=*) | in | optional | Lines to keep with it. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  save_layout["save_layout"] --> fig_save_layout["fig_save_layout"]
  save_layout["save_layout"] --> figure_check["figure_check"]
  style save_layout fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### load_layout

Read a layout written by `save_layout` (or an ini file of Dear ImGui), applied before the next frame: the
 settings in effect are cleared, the file's are read, the dock nodes are rebuilt and the windows that exist take
 their saved position, size and dock; the others take theirs when they appear. A program that lays out its dock
 space with `ig_dock_layout_begin` should not lay it out again: the dock space has a layout again (the same id as
 when saved). `FIG_ERR_FAILED` if the file cannot be read, `FIG_ERR_ARGUMENT` if it holds no layout.

```fortran
subroutine load_layout(self, path, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `path` | character(len=*) | in |  | File. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  load_layout["load_layout"] --> fig_load_layout["fig_load_layout"]
  load_layout["load_layout"] --> figure_check["figure_check"]
  style load_layout fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### destroy

Close the window and destroy the contexts (safe in any state).

```fortran
subroutine destroy(self)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |

**Call graph**

```mermaid
flowchart TD
  init["init"] --> destroy["destroy"]
  init["init"] --> destroy["destroy"]
  destroy["destroy"] --> fig_shutdown["fig_shutdown"]
  style destroy fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### show_file_dialog

Open a native file dialog of `kind` (0 open, 1 save, 2 folder).

```fortran
subroutine show_file_dialog(kind, id, filters, default_path, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `kind` | integer(kind=c_int) | in |  | Kind. |
| `id` | character(len=*) | in |  | Dialog id. |
| `filters` | character(len=*) | in | optional | 'name\|pattern' entries. |
| `default_path` | character(len=*) | in | optional | Where to start. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  open_file_dialog["open_file_dialog"] --> show_file_dialog["show_file_dialog"]
  open_folder_dialog["open_folder_dialog"] --> show_file_dialog["show_file_dialog"]
  save_file_dialog["save_file_dialog"] --> show_file_dialog["show_file_dialog"]
  show_file_dialog["show_file_dialog"] --> fig_file_dialog["fig_file_dialog"]
  show_file_dialog["show_file_dialog"] --> figure_check["figure_check"]
  style show_file_dialog fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### show_file_browser

Open FIGURE's file browser of `kind` (0 open, 1 save, 2 folder).

```fortran
subroutine show_file_browser(kind, id, filters, default_path, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `kind` | integer(kind=c_int) | in |  | Kind. |
| `id` | character(len=*) | in |  | Dialog id. |
| `filters` | character(len=*) | in | optional | 'name\|pattern' entries. |
| `default_path` | character(len=*) | in | optional | Where to start. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  open_file_browser["open_file_browser"] --> show_file_browser["show_file_browser"]
  save_file_browser["save_file_browser"] --> show_file_browser["show_file_browser"]
  show_file_browser["show_file_browser"] --> fig_file_browser["fig_file_browser"]
  show_file_browser["show_file_browser"] --> figure_check["figure_check"]
  style show_file_browser fill:#3e63dd,stroke:#99b,stroke-width:2px
```

## Functions

### frame_options

Give the frame options to the native layer, before init: `FIG_ERR_ARGUMENT` for an unknown value.

**Returns**: `integer(kind=c_int)`

```fortran
function frame_options(decorations, buttons) result(status)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `decorations` | character(len=*) | in | optional | `'native'` or `'figure'`. |
| `buttons` | character(len=*) | in | optional | `'right'` or `'left'`. |

**Call graph**

```mermaid
flowchart TD
  init["init"] --> frame_options["frame_options"]
  init_headless["init_headless"] --> frame_options["frame_options"]
  frame_options["frame_options"] --> fig_frame_options["fig_frame_options"]
  style frame_options fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### next_frame

Render the open frame (if any), then process input and open the next; `.false.` when the user quits.

**Attributes**: recursive

**Returns**: `logical`

```fortran
function next_frame(self, stat) result(running)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  next_frame["next_frame"] --> fig_begin_frame["fig_begin_frame"]
  next_frame["next_frame"] --> fig_end_frame["fig_end_frame"]
  next_frame["next_frame"] --> figure_check["figure_check"]
  next_frame["next_frame"] --> figure_refused["figure_refused"]
  style next_frame fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### quit_requested

The user asked to quit (the window's close button) since the last call: true once per request. Only with
 `set_confirm_quit(.true.)`; otherwise the request ends `next_frame` at once.

**Returns**: `logical`

```fortran
function quit_requested(self) result(requested)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | inout |  | Application. |

**Call graph**

```mermaid
flowchart TD
  quit_requested["quit_requested"] --> fig_quit_requested["fig_quit_requested"]
  style quit_requested fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### dropped

The files and folders dropped on the window since the last frame (SDL's drop events), and where: true on the
 frame after the drop only, with `paths` the absolute paths (UTF-8, blank-padded to the longest; folders as
 folders, without a trailing separator) and (`x`, `y`) the point of the drop [pixels], the coordinates of
 `ig_item_rect` and of the mouse, so that the program can tell which window or region received it. Several files
 dropped at once come together, at one point. False, with `paths` empty, on every other frame; also before
 `init*` and from a task. Window mode: the system's drag and drop; headless mode: only the drops of `test_drop`;
 remote mode: none (a browser gives a page the dropped files' contents, not paths on the server: the page refuses
 them), but those of `test_drop`.

**Attributes**: recursive

**Returns**: `logical`

```fortran
function dropped(self, paths, x, y) result(any_dropped)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | in |  | Application. |
| `paths` | character(len=:) | out | allocatable | Paths dropped. |
| `x` | real(kind=real64) | out | optional | Abscissa of the drop [pixels]. |
| `y` | real(kind=real64) | out | optional | Ordinate of the drop [pixels]. |

**Call graph**

```mermaid
flowchart TD
  dropped["dropped"] --> fig_dropped["fig_dropped"]
  dropped["dropped"] --> fig_dropped_path["fig_dropped_path"]
  dropped["dropped"] --> figure_refused["figure_refused"]
  style dropped fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### title

The window's title: the one given to `init` or the last `set_title` ('' before `init`, and in headless and remote
 modes until `set_title`).

**Returns**: `character(len=:)`

```fortran
function title(self) result(text)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | in |  | Application. |

**Call graph**

```mermaid
flowchart TD
  title["title"] --> fig_title["fig_title"]
  style title fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### content_scale

Display content scale (1 standard, 2 on most high-DPI displays).

**Returns**: `real(kind=real64)`

```fortran
function content_scale(self) result(scale)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([app_object](/api/src/lib/figure_app#app-object)) | in |  | Application. |

**Call graph**

```mermaid
flowchart TD
  content_scale["content_scale"] --> fig_content_scale["fig_content_scale"]
  style content_scale fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### opt

An optional string, or '' when absent (the native layer takes a length of 0 as not given).

**Attributes**: pure

**Returns**: `character(len=:)`

```fortran
function opt(s) result(v)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `s` | character(len=*) | in | optional | String. |

**Call graph**

```mermaid
flowchart TD
  set_style["set_style"] --> opt["opt"]
  style opt fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### opt_len

The length of an optional string, 0 when absent.

**Attributes**: pure

**Returns**: `integer(kind=c_int)`

```fortran
function opt_len(s) result(n)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `s` | character(len=*) | in | optional | String. |

**Call graph**

```mermaid
flowchart TD
  set_style["set_style"] --> opt_len["opt_len"]
  style opt_len fill:#3e63dd,stroke:#99b,stroke-width:2px
```
