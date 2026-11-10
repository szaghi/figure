---
title: Feature map
---

# Feature map

`use figure` exports everything below except the testing procedures (`use figure_testing`). The modules it re-exports
(`figure_app`, `figure_imgui`, `figure_implot`, `figure_dock`, `figure_style`, `figure_texture`, `figure_icons`,
`figure_base`) can also be used directly; `figure_c_native` and the generated raw modules (`figure_cimgui`,
`figure_cimplot` and their `_enums`) are internal and change without notice ([Raw bindings](raw-bindings)).

All kinds are those of `iso_fortran_env`: `int32`, `real32`, `real64`. Optional arguments are in brackets.

## Application: `app_object`

| Procedure | Purpose | Details |
|---|---|---|
| `app%init(title, width, height [, vsync] [, stat] [, ini_file] [, decorations] [, buttons])` | open the window (`decorations='figure'`: its frame drawn by FIGURE, the menus in the title bar), create the ImGui and ImPlot contexts | [frame loop](frame-loop#the-application), [the window's frame](frame-loop#the-window-s-frame) |
| `app%init_headless(width, height [, stat] [, decorations] [, buttons])` | contexts only, on a virtual display: no window, no GPU (`decorations='figure'`: the title bar drawn, for tests) | [headless testing](testing) |
| `app%set_icon(image [, stat])`, `app%set_icon(icon [, stat])` | the window's icon: an RGBA image `integer(int8) :: image(4, width, height)`, or an `ICON_*` (window mode) | [the window's frame](frame-loop#the-window-s-frame) |
| `app%init_remote([port] [, host] ...)` | the interface in a web browser: no window, display or GPU on the program's side | [remote UI](remote) |
| `app%next_frame([stat])` → `logical` | render the open frame, wait for input, open the next; `.false.` on quit | [frame loop](frame-loop#next-frame) |
| `app%set_checks(mode [, stat])` | what a usage error (a wrong end, a scope left open, a drawing call with no frame open) does: `'abort'`, `'report'` (default), `'recover'` | [usage checks](frame-loop#usage-checks) |
| `app%set_lazy(enabled [, max_wait])` | lazy redraw on/off, longest sleep (default 0.5 s) | [lazy redraw](frame-loop#lazy-redraw) |
| `app%request_frames(n)` | draw at least `n` more frames without waiting for input | [lazy redraw](frame-loop#lazy-redraw) |
| `app%wake()` | the next frame starts without waiting for input or `max_wait`, from any thread | [waking the loop](frame-loop#waking-the-loop) |
| `app%set_confirm_quit(enabled)` | the close button reports a request instead of ending the loop | [ask before quitting](menus#ask-before-quitting) |
| `app%quit_requested()` → `logical` | the user asked to quit, once per request | [ask before quitting](menus#ask-before-quitting) |
| `app%dropped(paths [, x] [, y] [, stat])` → `logical` | the files and folders dropped on the window since the last frame, and the point of the drop; `.true.` on that frame only | [drops](frame-loop#drops) |
| `app%quit()` | the next `next_frame` returns `.false.` | [next_frame](frame-loop#next-frame) |
| `app%set_title(text [, stat])`, `app%title()` → `character` | the window's title after `init` (window mode shows it; every mode keeps it) | [the window's title](menus#the-window-s-title) |
| `app%open_file_dialog(id [, filters] [, default_path] [, stat] [, prefer])`, `app%save_file_dialog(...)`, `app%open_folder_dialog(id [, default_path] [, stat] [, prefer])` | the system's file dialogs (window mode), answered on a later frame; `prefer='figure'`: FIGURE's browser instead, in every mode | [file dialogs](frame-loop#file-dialogs) |
| `app%open_file_browser(id [, filters] [, default_path] [, folders])`, `app%save_file_browser(id [, filters] [, default_path])` | FIGURE's file browser, drawn in Dear ImGui, the same in every mode (remote included): a file to open, a folder, where to save | [file browser](frame-loop#figure-s-file-browser) |
| `app%file_dialog_result(id, path, done [, cancelled])` | the answer to a dialog or a browser, once | [file dialogs](frame-loop#file-dialogs) |
| `app%save_image(path, xmin, ymin, xmax, ymax)` | a rectangle of the window as a PNG file (window mode) | [save an image](capture#save-an-image-from-the-program) |
| `app%image_result(path, done)` | the outcome of `save_image`, once | [save an image](capture#save-an-image-from-the-program) |
| `app%save_layout(path [, comment])` | the arrangement of the windows (docking included) to a file | [layouts](docking#save-and-load-a-layout) |
| `app%load_layout(path)` | an arrangement from a file, before the next frame | [layouts](docking#save-and-load-a-layout) |
| `app%notify(text [, kind] [, seconds] [, stat])` | tell the user something in a notification drawn by FIGURE (bottom-right, stacked): `'info'`, `'success'`, `'warning'`, `'error'`; it fades after `seconds` (default 5; 0: until clicked) | [notifications](frame-loop#notifications) |
| `app%notifications(list [, kinds] [, shown])` | the notifications kept (the last 100), oldest first | [notifications](frame-loop#notifications) |
| `app%content_scale()` → `real(real64)` | display content scale | [frame loop](frame-loop#content-scale) |
| `app%set_font(font [, size] [, stat])` | the default font: `'plex-sans'` (default, 15 px), `'plex-mono'` (monospace), `'proggy'`, or a TTF/OTF file | [styles](styles#fonts) |
| `app%load_style(file [, stat])`, `app%save_style(file [, stat])` | apply a theme file; write the style in effect as one | [styles](styles#load-tune-and-save) |
| `app%set_docking(enabled [, stat])` | docking on (default) or off | [docking](docking) |
| `app%set_style([name] [, lines] [, stat] [, look] [, palette] [, auto_dark] [, auto_light])` | the style by name (`'seal'`, default, `'seal-light'`, `'paper'`, `'high-contrast'`, `'dark'`, `'light'`, `'classic'`), or by parts: a look (geometry) and a palette (colours, or `'auto'`: the system's light or dark setting); `lines='okabe-ito'` | [styles](styles#looks-and-palettes) |
| `app%palette_color(role, rgba [, stat])` | the colour of a palette role in effect (`'text'`, `'accent'`, `'error'`, ...) as `[r, g, b, a]` in [0, 1] | [palette roles](styles#palette-roles) |
| `app%destroy()` | close the window, destroy the contexts | [frame loop](frame-loop#the-application) |

## Widgets: `ig_*`

| Procedure | Purpose |
|---|---|
| `ig_begin(name [, open] [, flags])` → `logical` | begin a window (`ImGuiWindowFlags_*`); `.false.` when collapsed or clipped |
| `ig_begin_side_bar(name, side, size)` | a bar along one side of the display (a toolbar), left out of the dock space | [Docking](docking#a-bar-along-a-side) |
| `ig_end()` | end the window (always, whatever `ig_begin` returned) |
| `ig_set_next_window(x, y [, width, height] [, always])` | place (and size) the next window |
| `ig_focus_window(name)` → `logical` | bring a window forward (a docked one: its tab); refused (`.false.`) while a popup is open |
| `ig_button(label [, width] [, height])` → `logical` | a button; `.true.` on the frame it is clicked |
| `ig_tool_button(label, icon [, width] [, height] [, selected] [, accent])` → `logical` | a workspace button: an icon above the label, framed; `selected` tinted in the accent |
| `ig_checkbox(label, value)` → `logical` | a check box bound to a `logical`; `.true.` when toggled |
| `ig_input(label, value [, step] [, format] [, enter_returns] [, read_only] [, stat])` → `logical` | a field for an `int32`, `int64`, `real32` or `real64`, scalar or vector, typed; `-`/`+` buttons with `step`; `.true.` when changed ([Numbers](widgets#numbers)) |
| `ig_drag(label, value [, speed] [, vmin] [, vmax] [, format] [, scale] [, clamp] [, stat])` → `logical` | a drag box for a number or a vector of any of the four kinds: `speed` per pixel, bounds, `'log'` scale ([Numbers](widgets#numbers)) |
| `ig_slider(label, value, vmin, vmax [, format] [, scale] [, clamp] [, stat])` → `logical` | a slider for a number or a vector of any of the four kinds; `'log'` scale, typed values clamped with `clamp` ([Numbers](widgets#numbers)) |
| `ig_slider_angle(label, radians [, deg_min] [, deg_max] [, format] [, stat])` → `logical` | an angle kept in radians, shown and set in degrees ([Numbers](widgets#numbers)) |
| `ig_drag_range(label, lo, hi [, speed] [, vmin] [, vmax] [, format] [, stat])` → `logical` | two drag boxes for the ends of a range, `lo <= hi` kept ([Numbers](widgets#numbers)) |
| `ig_radio(label, current, value [, stat])` → `logical` | a radio button of a group sharing `current`; a click sets `current = value` ([Choices](widgets#choices)) |
| `ig_list_box(label, current, items [, height] [, stat])` → `logical` | a list of the `character` array `items` that stays open and scrolls; `current` the index chosen ([Choices](widgets#choices)) |
| `ig_input_text(label, value [, hint] [, flags])` → `logical` | a text field bound to a `character` variable, whose length is the field's capacity; `.true.` when edited |
| `ig_input_text_multiline(label, buffer [, width] [, height] [, read_only] [, tab_input] [, flags])` → `logical` | a field of several lines over a `text_buffer_object`, of any length; Enter a newline, undo and redo; `.true.` when edited ([Multi-line text](widgets#multi-line-text)) |
| `text_buffer_object`: `buf%set(text [, stat])`, `buf%text()` → `character`, `buf%length()` → `int64` | the text of a multi-line field, kept by the native layer and grown as needed: replace it (CRLF becomes LF), copy it out, its length in bytes |
| `ig_combo(label, current, items)` → `logical` | a drop-down list of the `character` array `items`; `current` is the index chosen; `.true.` when the user picks one |
| `ig_selectable(label, selected)` → `logical` | a line of a list, highlighted when `selected`; `.true.` when clicked |
| `ig_text_wrapped(text)`, `ig_text_disabled(text)`, `ig_text_colored(text, color)` | text wrapped at the region's edge, in the disabled colour, in a given colour |
| `ig_begin_child(id [, width] [, height] [, border])` → `logical`, `ig_end_child()` | a region that scrolls on its own; always paired |
| `list_clipper_object`: `clip%begin(count [, item_height])`, `clip%step()` → `logical`, `clip%first`, `clip%last`, `clip%item_height` | a long list: only the rows in view are drawn; `item_height` the distance between rows [pixels] |
| `ig_begin_main_menu_bar()` → `logical`, `ig_end_main_menu_bar()` | the menu bar along the top of the display; end only after a true begin |
| `ig_begin_menu_bar()` → `logical`, `ig_end_menu_bar()` | a window's own menu bar (`ImGuiWindowFlags_MenuBar`) |
| `ig_begin_menu(label [, enabled])` → `logical`, `ig_end_menu()` | a menu or submenu; `.true.` while open |
| `ig_menu_item(label [, shortcut] [, selected] [, enabled])` → `logical` | a menu item; `.true.` when picked; a check mark with `selected` |
| `ig_open_popup(id)`, `ig_close_current_popup()` | open a popup (once, on an event); close the one being declared |
| `ig_begin_popup(id)` → `logical`, `ig_begin_popup_modal(title [, open])` → `logical`, `ig_end_popup()` | a popup, a modal dialog; end only after a true begin |
| `ig_begin_popup_context(id [, on] [, button] [, stat])` → `logical` | a context menu, opened by a right click on the item just drawn (`on='item'`), a window's empty space (`'window'`) or the background (`'void'`); closed with `ig_end_popup` after a true begin ([Context menus](menus#context-menus)) |
| `ig_shortcut(keys [, scope] [, repeat] [, stat])` → `logical` | a key chord such as `'ctrl+s'` pressed this frame (cmd on macOS), routed: `'focused'` (default) only in the focused window, `'global'`, `'item'` ([Shortcuts](menus#shortcuts)) |
| `ig_set_next_item_shortcut(keys [, scope] [, stat])` | the next item owns a chord: the chord presses it, its tooltip shows it ([Shortcuts](menus#a-button-that-owns-a-key)) |
| `ig_tooltip(text)` | a tooltip on the previous widget, shown while the pointer rests on it |
| `ig_begin_item_tooltip()` → `logical`, `ig_begin_tooltip()` → `logical`, `ig_end_tooltip()` | a tooltip with any content (a table, a plot): on the item just drawn after the hover delay, or now wherever the pointer is; end only after a true begin ([Tooltips](widgets#tooltips)) |
| `ig_text_link(label)` → `logical`, `ig_text_link_url(label, url)` | text drawn as a link, `.true.` when clicked; a link that opens `url` in the browser (remote mode: the page opens it) ([Links](widgets#links)) |
| `ig_set_clipboard(text [, stat])`, `ig_get_clipboard()` → `character` | put a text on the clipboard; read it (window: the system's; headless: the program's own; remote: the program's, joined to the browser's where it allows it) ([Clipboard](widgets#clipboard)) |
| `ig_collapsing_header(label [, default_open])` → `logical` | a header that shows or hides what follows; `.true.` while open (no end call) |
| `ig_begin_tab_bar(id)` → `logical`, `ig_end_tab_bar()` | a bar of tabs; end it only when the begin returned `.true.` |
| `ig_begin_tab(label [, open])` → `logical`, `ig_end_tab()` | a tab; `.true.` when selected: draw its content, then end it (only then) |
| `ig_begin_table(id, columns [, flags] [, height] [, freeze_rows] [, freeze_cols] [, sortable] [, hideable] [, reorderable] [, scroll_x] [, stat])` → `logical`, `ig_end_table()` | a table (every `ImGuiTableFlags_*` exported); rows or columns frozen in view while the rest scrolls; end it only when the begin returned `.true.` ([Tables](widgets#tables)) |
| `ig_table_setup_column(label [, width] [, stretch] [, sort] [, default_sort] [, descending] [, hidden] [, no_hide] [, stat])`, `ig_table_headers_row()` | declare a column (fixed `width`, or a `stretch` weight of the rest; how it sorts and hides); a row of their labels ([Tables](widgets#tables)) |
| `ig_table_sort(column, descending [, stat])` → `logical` | `.true.` on the frame the user asks a new order of a sortable table: its key `column` and direction; the program sorts ([Tables](widgets#tables)) |
| `ig_table_row_color(rgba [, cell] [, stat])` | a colour behind the current row, or one of its cells ([Tables](widgets#tables)) |
| `ig_table_hovered_column([stat])` → `integer(int32)` | the column under the pointer, 0 when none ([Tables](widgets#tables)) |
| `ig_table_column_enabled(column, enabled [, stat])` | show or hide a column of a hideable table from the program ([Tables](widgets#tables)) |
| `ig_table_next_row()`, `ig_table_next_column()`, `ig_table_set_column(column)` | start a row; move to the next cell, or to cell `column` (1-based) |
| `ig_tree_node(label [, default_open] [, selected] [, leaf] [, span_full_width] [, clicked] [, span_all_columns])` → `logical`, `ig_tree_pop()` | a tree node; `.true.` while open: draw its children, then pop (only then); `clicked`: the label, not the arrow; in a table, `span_all_columns`: its whole row ([Trees](widgets#trees)) |
| `ig_set_next_item_open(open [, always])` | open or close the next tree node or header from the program: first time only, or with `always` now |
| `ig_push_id(id)`, `ig_pop_id()` | an id scope (`character` or `int32`): the same label in two scopes is two widgets (rows, loops) |
| `ig_begin_disabled([disabled])`, `ig_end_disabled()` | the widgets in between are greyed out and ignore input |
| `ig_set_next_item_width(width)` | width of the next widget's field [pixels]; negative: up to that distance from the right edge |
| `ig_text(text)` | plain text |
| `ig_progress_bar(fraction [, label] [, width])` | a progress bar, `fraction` in [0, 1]; `fraction` < 0: indeterminate ([Progress bars](widgets#progress-bars)) |
| `ig_color_edit(label, rgba [, alpha] [, stat])` → `logical` | a colour editor with a picker, bound to `real(real64)` RGB or RGBA ([Colour editing](widgets#colour-editing)) |
| `ig_same_line([offset])` | put the next item on the same line; with `offset`, at that distance from the left edge |
| `ig_align_text_to_frame_padding()` | the text that follows on the line is level with the text of fields and buttons |
| `ig_text_size(text)` → `real(real64)(2)` | width and height of a text in the current font [pixels] (a label: the part before `##`) |
| `ig_separator()` | horizontal separator |
| `ig_separator_text(label)` | a separator with a title at its left ([Layout](widgets#layout)) |
| `ig_font_size()` → `real(real64)` | the current font size [pixels]: one em |
| `ig_em(x)` → `real(real64)` | `x` em [pixels] (`x` `real64` or `int32`): a size that follows the font |
| `ig_line_height([spacing])` → `real(real64)`, `ig_frame_height([spacing])` → `real(real64)` | a line of text's height, a framed widget's height [pixels]; with `spacing`, the distance between two lines, two rows of fields |
| `ig_available(w, h)` | the space left in the window or region from where the next item goes [pixels] |
| `ig_spacing()`, `ig_dummy(w, h)`, `ig_new_line()` | a gap of the item spacing; an empty item `w` x `h` [pixels]; end the line |
| `ig_indent([w])`, `ig_unindent([w])` | move the lines that follow right by `w` [pixels] (default: the style's indent), and back |
| `ig_begin_group()`, `ig_end_group()` | always paired: the items in between count as one item, their bounding rectangle |
| `ig_align_begin(id, where [, stat])`, `ig_align_end()` | always paired: a group centred (`'centre'`) or right-aligned (`'right'`) on the line; its width from the previous frame |
| `ig_align_next(width, where [, stat])` | centre or right-align the next item, `width` [pixels] wide |
| `ig_push_item_width(w)`, `ig_pop_item_width()` | always paired: the fields' width [pixels] up to the pop |
| `ig_show_demo_window([open])` | the Dear ImGui demo window |
| `ig_item_rect(xmin, ymin, xmax, ymax)` | screen rectangle of the last item |
| `ig_last_item()` → `item_status_object` | what happened to the item drawn last, in one snapshot: `hovered`, `active`, `focused`, `visible`, `activated`, `edited`, `deactivated`, `deactivated_after_edit`, `toggled_open`, `clicked(3)`, `double_clicked(3)`, `rect(4)` ([What happened to an item](widgets#what-happened-to-an-item)) |
| `ig_item_hovered([delay] [, stat])` → `logical` | the pointer is over the item drawn last; `delay` `'none'`, `'short'` (0.15 s) or `'normal'` (0.40 s) |
| `ig_any_item_hovered()` → `logical`, `ig_any_item_active()` → `logical` | the pointer is over some item; some item is held or edited |
| `ig_scroll_here([ratio] [, axis] [, stat])` | after an item: scroll its line to `ratio` of the visible height (0 top, 0.5 centre, 1 bottom), on the next frame ([Scrolling and focus](widgets#scrolling-and-focus)) |
| `ig_scroll_to_pos(pos [, ratio] [, axis] [, stat])` | scroll the point `pos` [pixels] of the content to `ratio` of the visible height: a row a clipper does not draw |
| `ig_get_scroll(y, ymax [, x] [, xmax])` | the scroll of the current window or region and its largest value [pixels] |
| `ig_set_scroll([y] [, x])` | scroll the current window or region to `y`, `x` [pixels] |
| `ig_focus_here([offset] [, stat])` | the next item takes the keyboard focus (a field is edited, as if clicked) |
| `ig_default_focus()` | the item drawn last has the focus when its window (a modal, a popup) appears |

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
| `ig_set_next_window_dock(id [, always])` | dock the next window into a node the first time it appears (a window created after the layout) |

Details: [Docking](docking).

## Styles: `ig_/ip_ set_/get_ style_color`, `style_var`

| Procedure | Does |
|---|---|
| `ig_set_style_color(name, color [, stat])`, `ip_set_style_color(...)` | a colour by name (`'#rrggbb[aa]'` or components) |
| `ig_get_style_color(name, rgba [, stat])`, `ip_get_style_color(...)` | a colour by name |
| `ig_set_style_var(name, value [, stat])`, `ip_set_style_var(...)` | a style variable by name (number, pair, logical, integer) |
| `ig_get_style_var(name, values, n [, stat])`, `ip_get_style_var(...)` | a style variable by name |
| `ig_show_style_editor([open] [, stat])` | Dear ImGui's and ImPlot's style editors, in a window |
| `ig_push_font(font [, size] [, stat])`, `ig_pop_font([stat])` | another font (`'plex-mono'` for columns that line up) or size for a block of widgets |
| `ig_push_style_color(name, color [, stat])`, `ig_pop_style_color([n] [, stat])` | a colour for a block of widgets |
| `ip_push_style_color(name, color [, stat])`, `ip_pop_style_color([n] [, stat])` | a colour for a block of plots |
| `ig_push_style_var(name, value [, stat])`, `ig_pop_style_var([n] [, stat])` | a style variable for a block of widgets |
| `ip_push_style_var(name, value [, stat])`, `ip_pop_style_var([n] [, stat])` | a style variable for a block of plots |
| `ICON_*` (`ICON_PLAY`, `ICON_FILE_PEN`, ... 2171 Lucide icons) | an icon as a UTF-8 string, for any label: `ICON_PLAY//' Run'` |

Details: [Styles](styles), [Icons](styles#icons).

## Plots: `ip_*`

| Procedure | Purpose |
|---|---|
| `ip_begin_plot(title [, width] [, height] [, equal])` → `logical` | begin a plot; `.true.` when visible |
| `ip_setup_axes(xlabel, ylabel [, auto_fit] [, xlog] [, ylog] [, xformat] [, yformat] [, xscale] [, yscale] [, stat])` | labels of X1 and Y1; the axes fit the data on first use, every frame with `auto_fit=.true.`; `xscale`/`yscale`: `'linear'`, `'log'`, `'symlog'`, `'time'` (`xlog`/`ylog`: deprecated `'log'`); `xformat`/`yformat`: tick label formats ([checked](plots#formats)) |
| `ip_begin_subplots(title, rows, cols [, width] [, height] [, link_x] [, link_y])` → `logical`, `ip_end_subplots()` | a grid of plots, optionally sharing the x or y range |
| `ip_setup_axes_limits(xmin, xmax, ymin, ymax [, always] [, stat])` | initial ranges of X1 and Y1 |
| `ip_setup_axis(axis [, label] [, scale] [, auto_fit] [, format] [, opposite] [, invert] [, lock] [, no_grid] [, stat])` | set up one of the six axes `'x1'`..`'x3'`, `'y1'`..`'y3'`: label, scale (`'linear'`, `'log'`, `'symlog'`, `'time'`), format, side, direction, lock, grid ([plots](plots#axes)) |
| `ip_set_axes(x, y [, stat])` | the axes the next items use (`'x1'`..`'x3'`, `'y1'`..`'y3'`) ([plots](plots#axes)) |
| `ip_setup_axis_limits(axis, vmin, vmax [, always] [, stat])` | initial range of one axis ([plots](plots#axes)) |
| `ip_setup_axis_ticks(axis, values [, labels] [, stat])` | ticks at given values, with given labels or the axis's format ([plots](plots#axes)) |
| `ip_setup_axis_constraints(axis [, vmin] [, vmax] [, zoom_min] [, zoom_max] [, stat])` | bounds the user cannot pan or zoom one axis past ([plots](plots#axes)) |
| `ip_setup_legend([location] [, outside] [, horizontal] [, stat])` | the legend at a compass point, inside or outside the plot area, in a column or a row ([plots](plots#axes)) |
| `ip_plot_limits(xmin, xmax, ymin, ymax [, xaxis] [, yaxis] [, stat])`, `ip_plot_size(...)` | the ranges the user panned and zoomed to, of the current axes or the named ones; the plot's size in pixels |
| `ip_line(label, x, y [, spec] [, stat])` | a line through `(x(i), y(i))`; arrays of any stride read in place, `x` may be `int32`/`int64` ([plots](plots#data-in-place)) |
| `ip_line(label, y [, xscale, xstart] ...)`, `ip_line(label, y, row ...)` | uniform x; a matrix row read in place |
| `ip_scatter(label, x, y [, spec] [, stat])` | markers at `(x(i), y(i))` |
| `ip_bars(label, x, y, bar_size [, spec] [, stat])` | bars of height `y(i)` at `x(i)` |
| `ip_shaded(label, x, y1, y2 [, spec] [, stat])`, `ip_shaded(label, x, y, yref ...)` | area between two curves, or a curve and `y = yref` |
| `ip_spec(...)` → `plot_spec_object` | item style: colours, line weight, markers, flags (`ImPlotMarker_*`, `ImPlot*Flags_*`) |
| `ip_heatmap(label, f, xmin, xmax, ymin, ymax ...)` | a field `f(i, j)` as coloured cells, read in place, j = 1 at the bottom |
| `ip_colormap_scale(label, scale_min, scale_max ... [, colormap] [, stat])` | the colour bar of a heatmap (default colormap: Viridis) |
| `ip_colormap_legend(id, colormap, vmin, vmax [, levels] [, horizontal] [, width] [, height] [, label_format] [, stat])` | a colour-scale legend, vertical or horizontal, continuous or in bands ([legend](colormaps#a-colour-scale-legend)) |
| `ip_colormap(name [, levels] [, stat])` → `integer(int32)` | a colormap's id by name: bundled (`'cividis'`, `'batlow'`, `'cool-warm'`, ...), ImPlot's own or loaded; `<name>_r` reversed, `levels` discrete bands ([colormaps](colormaps)) |
| `ip_load_colormap(name, file [, stat])` | a user colormap from a CSV table of RGB rows or a ParaView JSON preset ([user maps](colormaps#user-maps)) |
| `ip_colormap_names(names)` | the names `ip_colormap` knows ([colormaps](colormaps)) |
| `ip_image(label, tex, xmin, xmax, ymin, ymax ...)` | a texture in a plot, pixel row 1 at the bottom |
| `ip_error_bars(label, x, y, err [, err_high] [, spec] [, stat])` | vertical error bars, symmetric or not ([plots](plots#error-bars-annotations-and-drag-tools)) |
| `ip_annotation(x, y, text [, color] [, offset] [, stat])` | a text at a plot point, in a box of a colour or alone ([plots](plots#error-bars-annotations-and-drag-tools)) |
| `ip_drag_line_x(id, x [, color] [, thickness] [, stat])` → `logical`, `ip_drag_line_y(...)` | a vertical (horizontal) line the user drags; the value updated in place ([plots](plots#error-bars-annotations-and-drag-tools)) |
| `ip_drag_point(id, x, y [, color] [, radius] [, stat])` → `logical` | a point the user drags ([plots](plots#error-bars-annotations-and-drag-tools)) |
| `ip_contour(label, f, x0, x1, y0, y1 [, levels] [, nlevels] [, colormap] [, color] [, labels] [, line_weight] [, stat])` | contour lines of a field, read in place; NaNs leave holes ([plots](plots#contour-lines)) |
| `ip_contour_lines(f, x0, x1, y0, y1, levels, x, y, first)` | the contour segments without drawing them (marching squares, `pure`) ([plots](plots#contour-lines)) |
| `ip_contour_levels(f [, count])` → `real(real64)` array | levels at round numbers inside a field's finite range ([plots](plots#contour-lines)) |
| `ip_end_plot()` | end the plot (only if `ip_begin_plot` returned `.true.`) |

Items take `real(real32)` or `real(real64)` arrays. Details: [Plots](plots), [Colormaps](colormaps).

## Images: `texture_object`, `ig_image`

| Procedure | Purpose |
|---|---|
| `tex%init(width, height [, smooth] [, stat])`, `tex%update(rgba [, stat])`, `tex%destroy()` | an RGBA texture on the GPU, `integer(int8) :: rgba(4, width, height)` uploaded in place |
| `tex%width()`, `tex%height()` → `integer(int32)`, `tex%is_initialized()` → `logical` | its size (0 before `init`); whether it exists |
| `ig_image(tex [, width, height])` | the texture in a window, pixel row 1 at the top |

Details: [Heatmaps and images](images).

## Canvas: `ig_canvas`, `ig_draw_*`

| Procedure | Purpose |
|---|---|
| `ig_canvas(id, width, height, ev [, texture] [, stat])` | an area taking the mouse; `ev` a `canvas_event_object`: hovered, active, clicked, double-clicked, down and released per button, the pointer in canvas pixels, the drag, the wheel (owned while hovered), the modifiers, the canvas's origin and size ([Canvas](canvas#the-canvas)) |
| `ig_draw_line(x1, y1, x2, y2, color [, thickness] [, layer] [, stat])` | a segment ([Primitives](canvas#primitives)) |
| `ig_draw_rect(x1, y1, x2, y2, color [, thickness] [, filled] [, layer] [, stat])` | a rectangle, outline or filled ([Primitives](canvas#primitives)) |
| `ig_draw_circle(x, y, radius, color [, thickness] [, filled] [, layer] [, stat])` | a circle, its radius in pixels ([Primitives](canvas#primitives)) |
| `ig_draw_polyline(x, y, color [, thickness] [, closed] [, layer] [, stat])` | a polyline through the arrays `x(:)`, `y(:)` ([Primitives](canvas#primitives)) |
| `ig_draw_polygon(x, y, color [, thickness] [, filled] [, layer] [, stat])` | a polygon, outline or filled, convex or not ([Primitives](canvas#primitives)) |
| `ig_draw_text(x, y, text, color [, layer] [, stat])` | text, its top-left at the point ([Primitives](canvas#primitives)) |
| `ig_draw_image(texture, x1, y1, x2, y2 [, color] [, layer] [, stat])` | a texture stretched over a rectangle, tinted by `color` ([Primitives](canvas#primitives)) |
| `ig_cursor_screen_pos(x, y)` | where the next item goes, in screen pixels ([Coordinates](canvas#coordinates)) |
| `ig_invisible_button(id, width, height [, stat])` → `logical` | a button that draws nothing: a hot zone over a drawing ([The canvas](canvas#the-canvas)) |

`layer` is `'window'` (default), `'foreground'`, `'background'` or `'plot'` (plot units, inside a plot). Details:
[Canvas](canvas).

## Processes: `process_object`, `log_view_object`

| Procedure | Purpose |
|---|---|
| `p%start(args [, cwd] [, env] [, merge_stderr] [, detached] [, log_file] [, stat])` | start a program, the arguments as an array (no shell): captured (output piped) or detached (output to `log_file`, it outlives the program) |
| `p%poll(lines [, stat])` | the complete lines printed since the last poll (`character(len=:), allocatable :: lines(:)`) |
| `p%running()` → `logical`, `p%exit_code([stat])` → `int32`, `p%killed()` → `logical`, `p%pid()` → `int64` | its state: running, its exit code (captured, ended), ended by `kill`, its process id |
| `p%kill([force] [, stat])` | ask it to end (`force`: at once) |
| `log%add(line \| lines)`, `log%clear()`, `log%set_cap(cap [, stat])` | the lines of a log view, a ring buffer of `cap` lines (default 10000) |
| `log%draw(id [, height])` | the lines in a region of their own, only those in view; follows the end while at the bottom; click, shift+click, ctrl+c to copy |
| `log%count()` → `int32`, `log%line(i)` → `character`, `log%following()` → `logical`, `log%in_view(first, last)`, `log%copy([all])` → `character` | the lines kept, one line, whether the view follows the end, the lines in view, the chosen lines |

Details: [Processes and tasks](processes).

## Tasks: `task_object`, `task_handle_object`

| Procedure | Purpose |
|---|---|
| `t%start(work, data [, stat])` | run `work(h, data)` (a `task_work` module procedure) on a worker thread, on a copy of `data` (`class(*)`) |
| `t%running()` → `logical`, `t%done()` → `logical`, `t%progress(fraction [, message])` | it runs; it has ended (its result waits); its last progress in [0, 1] and message |
| `t%cancel([stat])`, `t%result(data [, stat])` | ask it to stop at its next safe point; once done, its data moved out (`class(*), allocatable`) |
| `h%report(fraction [, message])`, `h%cancelled()` → `logical`, `h%fail(message)` | in the task: post progress (wakes the frame loop), the program asked it to stop, report a failure |

A task never draws: FIGURE's drawing entry points refuse a call from a worker with `FIG_ERR_STATE`.
Details: [Processes and tasks](processes#tasks).

## 3-D views: `view3d_object`

| Procedure | Purpose |
|---|---|
| `v%init([threads] [, fast_moves] [, lighting] [, background] [, stat])`, `v%destroy()`, `v%is_initialized()` → `logical` | create a 3-D view drawn by FIGURE's software rasterizer (the same pixels in every mode); release it; whether it exists |
| `v%triangles(xyz, tri [, scalar] [, cell_scalar] [, colormap] [, color] [, edges] [, flat] [, stat])` → `int32`, `v%quads(xyz, quad [, ...])` → `int32`, `v%surface(xyz [, ...])` → `int32`, `v%lines(xyz [, seg] [, ...])` → `int32` | add a mesh, read in place from the program's `target` arrays: triangles, quads, a structured surface `xyz(3, ni, nj)`, lines; coloured by a scalar per vertex or per cell through a colormap, or in one colour |
| `v%set_mesh(mesh [, scalar] [, cell_scalar] [, no_scalar] [, colormap] [, vmin, vmax] [, auto_range] [, color] [, edges] [, edge_color] [, flat] [, visible] [, stat])`, `v%changed([mesh] [, stat])`, `v%remove(mesh [, stat])`, `v%clear([stat])` | change a mesh's field or style; its arrays changed in place; remove one, all |
| `v%set_camera([target] [, distance] [, azimuth] [, elevation] [, fov] [, stat])`, `v%get_camera(...)`, `v%fit([stat])`, `v%view(name [, stat])`, `v%orbit(azimuth [, elevation] [, stat])`, `v%pan(right, up [, stat])`, `v%zoom(factor [, stat])` | the camera: set, read, fit, the six standard views (`'+x'` ... `'-z'`), turn, move, zoom |
| `v%clip(normal, point [, stat])`, `v%unclip([stat])` | clipping planes (up to 6) |
| `v%draw(id [, width] [, height] [, stat])` | the view as a widget; the mouse orbits, pans, zooms, fits; rendered only when something changed, at half resolution while moving |
| `v%pick(x, y, mesh, element [, point] [, stat])` → `logical`, `v%hovered(mesh, element [, point] [, stat])` → `logical`, `v%clicked(...)` → `logical` | the element under a pixel, under the mouse, clicked |
| `v%image(rgba [, stat])`, `v%render_info([count] [, milliseconds] [, width] [, height] [, half] [, stat])` | the pixels of the last render; renders so far, the last one's time and size |

Details: [3-D views](view3d).

## Testing: `figure_testing`

| Procedure | Does |
|---|---|
| `test_click(x, y [, button])`, `test_drag(x0, y0, x1, y1)` | queue a click, a drag |
| `test_mouse_move`, `test_mouse_button`, `test_wheel` | queue mouse input, one part at a time |
| `test_key(name [, down])`, `test_type(text)` | queue keys and typed text |
| `test_drop(paths, x, y [, stat])` | queue a drop of files or folders at (x, y), reported by `app%dropped` on the next frame |
| `test_next_frame()` | a frame boundary in the queued input |
| `test_item_center(x, y)`, `test_window_rect(name, ...)` | where a widget or a window is |
| `test_popup_rect(xmin, ymin, xmax, ymax [, found] [, stat])` | where the open popup is (a menu, a context menu, a combo's list, a colour picker) |
| `test_opened_url()` → `character` | the URL the last click on an `ig_text_link_url` asked to open (headless mode opens nothing) ([Links](widgets#links)) |
| `test_quit()` | a quit request, as the window's close button makes it |
| `test_plot_tick(axis, index, label [, count] [, stat])` | a tick label of any of the six axes of the plot being declared (`'x1'`..`'y3'`; `'x'`, `'y'`) ([plots](plots#axes)) |
| `test_plot_copies()` → `int64` | the arrays the plot items copied so far (a stride differing from the ordinates', integer abscissae) ([plots](plots#data-in-place)) |
| `test_plot_stride()` → `int64` | the byte stride the last plot item gave ImPlot ([plots](plots#data-in-place)) |
| `test_frame_hit(x, y)` → `character` | what the frame of `decorations='figure'` does at a point: `'client'`, `'drag'`, `'resize-top-left'`, ... ([the window's frame](frame-loop#the-window-s-frame)) |
| `test_frame_rect(part, x0, y0, x1, y1 [, found] [, stat])` | a part of its title bar in the last frame: `'bar'`, `'icon'`, `'menus'`, `'title'`, `'minimize'`, `'maximize'`, `'close'` |
| `test_frame_state(minimized, maximized [, stat])` | the window minimized, maximized (headless: as the bar's buttons recorded it) |
| `test_system_theme(theme [, stat])` | the system's light or dark setting changes (`'light'`, `'dark'`, `'system'`), at the next frame: tests of `palette='auto'` ([styles](styles#follow-the-system-s-light-or-dark-setting)) |
| `test_notification_rect(index, x0, y0, x1, y1 [, found] [, alpha])` | a notification shown in the last frame, 1 the newest, and the alpha it was drawn with ([notifications](frame-loop#notifications)) |
| `test_drawn_extent(color, x0, y0, x1, y1 [, found] [, stat] [, layer] [, vertices])` | the extent drawn so far in the current window in a style colour by name (`'PlotHistogram'`: a progress bar's fill) or an RGBA colour (an item's `ip_spec` colour); with `layer`, the foreground or background layer; `vertices`, how many ([Canvas](canvas#testing-a-canvas)) |
| `test_file_browser(shown [, folder] [, entries] [, error] [, asking] [, path_field] [, name_field] [, recent])` | the file browser in front: its folder, the entries in the order shown, the error shown, the replace question, the fields, the recent folders ([file browser](frame-loop#figure-s-file-browser)) |
| `test_file_browser_rect(part, x0, y0, x1, y1 [, found])` | a part of the file browser in the last frame (`'entry:NAME'`, `'ok'`, `'cancel'`, `'path'`, ...), to click it |
| `test_settings_file(path [, stat])` | the file keeping the browser's recent folders, instead of FIGURE's own (`''`: memory only) |

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
