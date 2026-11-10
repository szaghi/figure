---
title: Feature map
---

# Feature map

`use figure` exports everything below except the testing procedures (`use figure_testing`). The modules it re-exports
(`figure_app`, `figure_imgui`, `figure_implot`, `figure_dock`, `figure_style`, `figure_texture`, `figure_icons`,
`figure_base`) can also be used directly; `figure_c_native` and the generated raw modules (`figure_cimgui`,
`figure_cimplot` and their `_enums`) are internal and change without notice ([Raw bindings](raw-bindings)).

All kinds are those of `iso_fortran_env`: `int32`, `real32`, `real64`. Optional arguments are in brackets.
A name of Dear ImGui's or ImPlot's documentation (`SetScrollHereY`, `PlotLine`) is found in the
[name map](imgui-names), with the FIGURE call that exposes it.

## Application: `app_object`

| Procedure | Purpose | Details |
|---|---|---|
| `app%init(title, width, height [, vsync] [, stat] [, ini_file] [, decorations] [, buttons])` | open the window (`decorations='figure'`: its frame drawn by FIGURE, the menus in the title bar), create the ImGui and ImPlot contexts | [frame loop](frame-loop#the-application), [the window's frame](frame-loop#the-window-s-frame) |
| `app%init_headless(width, height [, stat] [, decorations] [, buttons])` | contexts only, on a virtual display: no window, no GPU (`decorations='figure'`: the title bar drawn, for tests) | [headless testing](testing) |
| `app%set_icon(image [, stat])`, `app%set_icon(icon [, stat])` | the window's icon: an RGBA image `integer(int8) :: image(4, width, height)`, or an `ICON_*` (window mode) | [the window's frame](frame-loop#the-window-s-frame) <!-- visual --> |
| `app%init_remote([port] [, host] ...)` | the interface in a web browser: no window, display or GPU on the program's side | [remote UI](remote) <!-- visual --> |
| `app%next_frame([stat])` → `logical` | render the open frame, wait for input, open the next; `.false.` on quit | [frame loop](frame-loop#next-frame) |
| `app%set_checks(mode [, stat])` | what a usage error (a wrong end, a scope left open, a drawing call with no frame open) does: `'abort'`, `'report'` (default), `'recover'` | [usage checks](frame-loop#usage-checks) |
| `app%set_lazy(enabled [, max_wait])` | lazy redraw on/off, longest sleep (default 0.5 s) | [lazy redraw](frame-loop#lazy-redraw) |
| `app%request_frames(n)` | draw at least `n` more frames without waiting for input | [lazy redraw](frame-loop#lazy-redraw) |
| `app%wake()` | the next frame starts without waiting for input or `max_wait`, from any thread | [waking the loop](frame-loop#waking-the-loop) |
| `app%set_confirm_quit(enabled)` | the close button reports a request instead of ending the loop | [ask before quitting](menus#ask-before-quitting) <!-- visual --> |
| `app%quit_requested()` → `logical` | the user asked to quit, once per request | [ask before quitting](menus#ask-before-quitting) <!-- visual --> |
| `app%dropped(paths [, x] [, y] [, stat])` → `logical` | the files and folders dropped on the window since the last frame, and the point of the drop; `.true.` on that frame only | [drops](frame-loop#drops) <!-- visual --> |
| `app%quit()` | the next `next_frame` returns `.false.` | [next_frame](frame-loop#next-frame) |
| `app%set_title(text [, stat])`, `app%title()` → `character` | the window's title after `init` (window mode shows it; every mode keeps it) | [the window's title](menus#the-window-s-title) |
| `app%open_file_dialog(id [, filters] [, default_path] [, stat] [, prefer])`, `app%save_file_dialog(...)`, `app%open_folder_dialog(id [, default_path] [, stat] [, prefer])` | the system's file dialogs (window mode), answered on a later frame; `prefer='figure'`: FIGURE's browser instead, in every mode | [file dialogs](frame-loop#file-dialogs) <!-- visual --> |
| `app%open_file_browser(id [, filters] [, default_path] [, folders])`, `app%save_file_browser(id [, filters] [, default_path])` | FIGURE's file browser, drawn in Dear ImGui, the same in every mode (remote included): a file to open, a folder, where to save | [file browser](frame-loop#figure-s-file-browser) <!-- visual --> |
| `app%file_dialog_result(id, path, done [, cancelled])` | the answer to a dialog or a browser, once | [file dialogs](frame-loop#file-dialogs) <!-- visual --> |
| `app%save_image(path, xmin, ymin, xmax, ymax)` | a rectangle of the window as a PNG file (window mode) | [save an image](capture#save-an-image-from-the-program) |
| `app%image_result(path, done)` | the outcome of `save_image`, once | [save an image](capture#save-an-image-from-the-program) |
| `app%save_layout(path [, comment])` | the arrangement of the windows (docking included) to a file | [layouts](docking#save-and-load-a-layout) |
| `app%load_layout(path)` | an arrangement from a file, before the next frame | [layouts](docking#save-and-load-a-layout) |
| `app%notify(text [, kind] [, seconds] [, stat])` | tell the user something in a notification drawn by FIGURE (bottom-right, stacked): `'info'`, `'success'`, `'warning'`, `'error'`; it fades after `seconds` (default 5; 0: until clicked) | [notifications](frame-loop#notifications) <!-- visual --> |
| `app%notifications(list [, kinds] [, shown])` | the notifications kept (the last 100), oldest first | [notifications](frame-loop#notifications) <!-- visual --> |
| `app%content_scale()` → `real(real64)` | display content scale | [frame loop](frame-loop#content-scale) |
| `app%set_font(font [, size] [, stat])` | the default font: `'plex-sans'` (default, 15 px), `'plex-mono'` (monospace), `'proggy'`, or a TTF/OTF file | [styles](styles#fonts) |
| `app%load_style(file [, stat])`, `app%save_style(file [, stat])` | apply a theme file; write the style in effect as one | [styles](styles#load-tune-and-save) <!-- visual --> |
| `app%set_docking(enabled [, stat])` | docking on (default) or off | [docking](docking) <!-- visual --> |
| `app%set_style([name] [, lines] [, stat] [, look] [, palette] [, auto_dark] [, auto_light])` | the style by name (`'seal'`, default, `'seal-light'`, `'paper'`, `'high-contrast'`, `'dark'`, `'light'`, `'classic'`), or by parts: a look (geometry) and a palette (colours, or `'auto'`: the system's light or dark setting); `lines='okabe-ito'` | [styles](styles#looks-and-palettes) <!-- visual --> |
| `app%palette_color(role, rgba [, stat])` | the colour of a palette role in effect (`'text'`, `'accent'`, `'error'`, ...) as `[r, g, b, a]` in [0, 1] | [palette roles](styles#palette-roles) |
| `app%destroy()` | close the window, destroy the contexts | [frame loop](frame-loop#the-application) |

## Widgets: `ig_*`

| Procedure | Purpose |
|---|---|
| `ig_begin(name [, open] [, flags])` → `logical` | begin a window (`ImGuiWindowFlags_*`); `.false.` when collapsed or clipped ([Windows](widgets#windows)) |
| `ig_begin_side_bar(name, side, size)` | a bar along one side of the display (a toolbar), left out of the dock space | [Docking](docking#a-bar-along-a-side) |
| `ig_end()` | end the window (always, whatever `ig_begin` returned) ([Windows](widgets#windows)) |
| `ig_set_next_window(x, y [, width, height] [, always])` | place (and size) the next window ([Windows](widgets#windows)) |
| `ig_focus_window(name)` → `logical` | bring a window forward (a docked one: its tab); refused (`.false.`) while a popup is open ([Windows](widgets#windows)) |
| `ig_button(label [, width] [, height])` → `logical` | a button; `.true.` on the frame it is clicked ([Controls](widgets#controls)) |
| `ig_tool_button(label, icon [, width] [, height] [, selected] [, accent])` → `logical` | a workspace button: an icon above the label, framed; `selected` tinted in the accent ([Controls](widgets#controls)) |
| `ig_checkbox(label, value)` → `logical` | a check box bound to a `logical`; `.true.` when toggled ([Controls](widgets#controls)) |
| `ig_input(label, value [, step] [, format] [, enter_returns] [, read_only] [, stat])` → `logical` | a field for an `int32`, `int64`, `real32` or `real64`, scalar or vector, typed; `-`/`+` buttons with `step`; `.true.` when changed ([Numbers](widgets#numbers)) <!-- visual --> |
| `ig_drag(label, value [, speed] [, vmin] [, vmax] [, format] [, scale] [, clamp] [, stat])` → `logical` | a drag box for a number or a vector of any of the four kinds: `speed` per pixel, bounds, `'log'` scale ([Numbers](widgets#numbers)) <!-- visual --> |
| `ig_slider(label, value, vmin, vmax [, format] [, scale] [, clamp] [, stat])` → `logical` | a slider for a number or a vector of any of the four kinds; `'log'` scale, typed values clamped with `clamp` ([Numbers](widgets#numbers)) <!-- visual --> |
| `ig_slider_angle(label, radians [, deg_min] [, deg_max] [, format] [, stat])` → `logical` | an angle kept in radians, shown and set in degrees ([Numbers](widgets#numbers)) <!-- visual --> |
| `ig_drag_range(label, lo, hi [, speed] [, vmin] [, vmax] [, format] [, stat])` → `logical` | two drag boxes for the ends of a range, `lo <= hi` kept ([Numbers](widgets#numbers)) <!-- visual --> |
| `ig_radio(label, current, value [, stat])` → `logical` | a radio button of a group sharing `current`; a click sets `current = value` ([Choices](widgets#choices)) <!-- visual --> |
| `ig_list_box(label, current, items [, height] [, stat])` → `logical` | a list of the `character` array `items` that stays open and scrolls; `current` the index chosen ([Choices](widgets#choices)) <!-- visual --> |
| `ig_player(id, player [, labels] [, stat])` → `logical` | a player for snapshots: previous, play/pause, next, a slider (showing `labels(index)`), a right-click menu for the speed and the mode; plays on the frame clock and asks for frames while playing; `.true.` when `player%index` changed ([Players](widgets#players)) <!-- visual --> |
| `player_object`: `%index`, `%count`, `%playing`, `%speed`, `%mode` | the state of a player: the snapshot shown (1 to `count`), playing or not, snapshots per second, `'once'`, `'loop'` or `'bounce'` ([Players](widgets#players)) <!-- visual --> |
| `ig_input_text(label, value [, hint] [, flags])` → `logical` | a text field bound to a `character` variable, whose length is the field's capacity; `.true.` when edited ([Controls](widgets#controls)) |
| `ig_input_text_multiline(label, buffer [, width] [, height] [, read_only] [, tab_input] [, flags])` → `logical` | a field of several lines over a `text_buffer_object`, of any length; Enter a newline, undo and redo; `.true.` when edited ([Multi-line text](widgets#multi-line-text)) <!-- visual --> |
| `text_buffer_object`: `buf%set(text [, stat])`, `buf%text()` → `character`, `buf%length()` → `int64` | the text of a multi-line field, kept by the native layer and grown as needed: replace it (CRLF becomes LF), copy it out, its length in bytes ([Multi-line text](widgets#multi-line-text)) <!-- visual --> |
| `ig_combo(label, current, items)` → `logical` | a drop-down list of the `character` array `items`; `current` is the index chosen; `.true.` when the user picks one ([Choices](widgets#choices)) <!-- visual --> |
| `ig_selectable(label, selected)` → `logical` | a line of a list, highlighted when `selected`; `.true.` when clicked ([Lists and regions](widgets#lists-and-regions)) <!-- visual --> |
| `ig_text_wrapped(text)`, `ig_text_disabled(text)`, `ig_text_colored(text, color)` | text wrapped at the region's edge, in the disabled colour, in a given colour ([Text and layout](widgets#text-and-layout)) |
| `ig_begin_child(id [, width] [, height] [, border])` → `logical`, `ig_end_child()` | a region that scrolls on its own; always paired ([Lists and regions](widgets#lists-and-regions)) <!-- visual --> |
| `list_clipper_object`: `clip%begin(count [, item_height])`, `clip%step()` → `logical`, `clip%first`, `clip%last`, `clip%item_height` | a long list: only the rows in view are drawn; `item_height` the distance between rows [pixels] ([Lists and regions](widgets#lists-and-regions)) <!-- visual --> |
| `ig_begin_main_menu_bar()` → `logical`, `ig_end_main_menu_bar()` | the menu bar along the top of the display; end only after a true begin ([Menus](menus#menus)) |
| `ig_begin_menu_bar()` → `logical`, `ig_end_menu_bar()` | a window's own menu bar (`ImGuiWindowFlags_MenuBar`) ([Menus](menus#menus)) |
| `ig_begin_menu(label [, enabled])` → `logical`, `ig_end_menu()` | a menu or submenu; `.true.` while open ([Menus](menus#menus)) |
| `ig_menu_item(label [, shortcut] [, selected] [, enabled])` → `logical` | a menu item; `.true.` when picked; a check mark with `selected` ([Menus](menus#menus)) |
| `ig_open_popup(id)`, `ig_close_current_popup()` | open a popup (once, on an event); close the one being declared ([Popups](menus#popups-and-modals)) |
| `ig_begin_popup(id)` → `logical`, `ig_begin_popup_modal(title [, open])` → `logical`, `ig_end_popup()` | a popup, a modal dialog; end only after a true begin ([Popups](menus#popups-and-modals)) |
| `ig_begin_popup_context(id [, on] [, button] [, stat])` → `logical` | a context menu, opened by a right click on the item just drawn (`on='item'`), a window's empty space (`'window'`) or the background (`'void'`); closed with `ig_end_popup` after a true begin ([Context menus](menus#context-menus)) <!-- visual --> |
| `ig_shortcut(keys [, scope] [, repeat] [, stat])` → `logical` | a key chord such as `'ctrl+s'` pressed this frame (cmd on macOS), routed: `'focused'` (default) only in the focused window, `'global'`, `'item'` ([Shortcuts](menus#shortcuts)) <!-- visual --> |
| `ig_set_next_item_shortcut(keys [, scope] [, stat])` | the next item owns a chord: the chord presses it, its tooltip shows it ([Shortcuts](menus#a-button-that-owns-a-key)) |
| `ig_tooltip(text)` | a tooltip on the previous widget, shown while the pointer rests on it ([Tooltips](widgets#tooltips)) <!-- visual --> |
| `ig_begin_item_tooltip()` → `logical`, `ig_begin_tooltip()` → `logical`, `ig_end_tooltip()` | a tooltip with any content (a table, a plot): on the item just drawn after the hover delay, or now wherever the pointer is; end only after a true begin ([Tooltips](widgets#tooltips)) <!-- visual --> |
| `ig_text_link(label)` → `logical`, `ig_text_link_url(label, url)` | text drawn as a link, `.true.` when clicked; a link that opens `url` in the browser (remote mode: the page opens it) ([Links](widgets#links)) |
| `ig_set_clipboard(text [, stat])`, `ig_get_clipboard()` → `character` | put a text on the clipboard; read it (window: the system's; headless: the program's own; remote: the program's, joined to the browser's where it allows it) ([Clipboard](widgets#clipboard)) |
| `ig_collapsing_header(label [, default_open])` → `logical` | a header that shows or hides what follows; `.true.` while open (no end call) ([Groups](widgets#groups-headers-tabs-tables)) |
| `ig_begin_tab_bar(id)` → `logical`, `ig_end_tab_bar()` | a bar of tabs; end it only when the begin returned `.true.` ([Groups](widgets#groups-headers-tabs-tables)) |
| `ig_begin_tab(label [, open])` → `logical`, `ig_end_tab()` | a tab; `.true.` when selected: draw its content, then end it (only then) ([Groups](widgets#groups-headers-tabs-tables)) |
| `ig_begin_table(id, columns [, flags] [, height] [, freeze_rows] [, freeze_cols] [, sortable] [, hideable] [, reorderable] [, scroll_x] [, stat])` → `logical`, `ig_end_table()` | a table (every `ImGuiTableFlags_*` exported); rows or columns frozen in view while the rest scrolls; end it only when the begin returned `.true.` ([Tables](widgets#tables)) <!-- visual --> |
| `ig_table_setup_column(label [, width] [, stretch] [, sort] [, default_sort] [, descending] [, hidden] [, no_hide] [, stat])`, `ig_table_headers_row()` | declare a column (fixed `width`, or a `stretch` weight of the rest; how it sorts and hides); a row of their labels ([Tables](widgets#tables)) <!-- visual --> |
| `ig_table_sort(column, descending [, stat])` → `logical` | `.true.` on the frame the user asks a new order of a sortable table: its key `column` and direction; the program sorts ([Tables](widgets#tables)) <!-- visual --> |
| `ig_table_row_color(rgba [, cell] [, stat])` | a colour behind the current row, or one of its cells ([Tables](widgets#tables)) <!-- visual --> |
| `ig_table_hovered_column([stat])` → `integer(int32)` | the column under the pointer, 0 when none ([Tables](widgets#tables)) <!-- visual --> |
| `ig_table_column_enabled(column, enabled [, stat])` | show or hide a column of a hideable table from the program ([Tables](widgets#tables)) <!-- visual --> |
| `ig_table_next_row()`, `ig_table_next_column()`, `ig_table_set_column(column)` | start a row; move to the next cell, or to cell `column` (1-based) ([Tables](widgets#tables)) <!-- visual --> |
| `ig_tree_node(label [, default_open] [, selected] [, leaf] [, span_full_width] [, clicked] [, span_all_columns])` → `logical`, `ig_tree_pop()` | a tree node; `.true.` while open: draw its children, then pop (only then); `clicked`: the label, not the arrow; in a table, `span_all_columns`: its whole row ([Trees](widgets#trees)) <!-- visual --> |
| `ig_set_next_item_open(open [, always])` | open or close the next tree node or header from the program: first time only, or with `always` now ([Trees](widgets#trees)) <!-- visual --> |
| `ig_push_id(id)`, `ig_pop_id()` | an id scope (`character` or `int32`): the same label in two scopes is two widgets (rows, loops) ([Groups](widgets#groups-headers-tabs-tables)) |
| `ig_begin_disabled([disabled])`, `ig_end_disabled()` | the widgets in between are greyed out and ignore input ([Groups](widgets#groups-headers-tabs-tables)) |
| `ig_set_next_item_width(width)` | width of the next widget's field [pixels]; negative: up to that distance from the right edge ([Controls](widgets#controls)) |
| `ig_text(text)` | plain text ([Text and layout](widgets#text-and-layout)) |
| `ig_progress_bar(fraction [, label] [, width])` | a progress bar, `fraction` in [0, 1]; `fraction` < 0: indeterminate ([Progress bars](widgets#progress-bars)) <!-- visual --> |
| `ig_color_edit(label, rgba [, alpha] [, stat])` → `logical` | a colour editor with a picker, bound to `real(real64)` RGB or RGBA ([Colour editing](widgets#colour-editing)) <!-- visual --> |
| `ig_same_line([offset])` | put the next item on the same line; with `offset`, at that distance from the left edge ([Text and layout](widgets#text-and-layout)) |
| `ig_align_text_to_frame_padding()` | the text that follows on the line is level with the text of fields and buttons ([Text and layout](widgets#text-and-layout)) |
| `ig_text_size(text)` → `real(real64)(2)` | width and height of a text in the current font [pixels] (a label: the part before `##`) ([Text and layout](widgets#text-and-layout)) |
| `ig_separator()` | horizontal separator ([Text and layout](widgets#text-and-layout)) |
| `ig_separator_text(label)` | a separator with a title at its left ([Layout](widgets#layout)) <!-- visual --> |
| `ig_font_size()` → `real(real64)` | the current font size [pixels]: one em ([Layout](widgets#layout)) <!-- visual --> |
| `ig_em(x)` → `real(real64)` | `x` em [pixels] (`x` `real64` or `int32`): a size that follows the font ([Layout](widgets#layout)) <!-- visual --> |
| `ig_line_height([spacing])` → `real(real64)`, `ig_frame_height([spacing])` → `real(real64)` | a line of text's height, a framed widget's height [pixels]; with `spacing`, the distance between two lines, two rows of fields ([Layout](widgets#layout)) <!-- visual --> |
| `ig_available(w, h)` | the space left in the window or region from where the next item goes [pixels] ([Layout](widgets#layout)) <!-- visual --> |
| `ig_spacing()`, `ig_dummy(w, h)`, `ig_new_line()` | a gap of the item spacing; an empty item `w` x `h` [pixels]; end the line ([Layout](widgets#layout)) <!-- visual --> |
| `ig_indent([w])`, `ig_unindent([w])` | move the lines that follow right by `w` [pixels] (default: the style's indent), and back ([Layout](widgets#layout)) <!-- visual --> |
| `ig_begin_group()`, `ig_end_group()` | always paired: the items in between count as one item, their bounding rectangle ([Layout](widgets#layout)) <!-- visual --> |
| `ig_align_begin(id, where [, stat])`, `ig_align_end()` | always paired: a group centred (`'centre'`) or right-aligned (`'right'`) on the line; its width from the previous frame ([Layout](widgets#layout)) <!-- visual --> |
| `ig_align_next(width, where [, stat])` | centre or right-align the next item, `width` [pixels] wide ([Layout](widgets#layout)) <!-- visual --> |
| `ig_push_item_width(w)`, `ig_pop_item_width()` | always paired: the fields' width [pixels] up to the pop ([Layout](widgets#layout)) <!-- visual --> |
| `ig_show_demo_window([open])` | the Dear ImGui demo window ([Text and layout](widgets#text-and-layout)) |
| `ig_item_rect(xmin, ymin, xmax, ymax)` | screen rectangle of the last item ([What happened to an item](widgets#what-happened-to-an-item)) <!-- visual --> |
| `ig_last_item()` → `item_status_object` | what happened to the item drawn last, in one snapshot: `hovered`, `active`, `focused`, `visible`, `activated`, `edited`, `deactivated`, `deactivated_after_edit`, `toggled_open`, `clicked(3)`, `double_clicked(3)`, `rect(4)` ([What happened to an item](widgets#what-happened-to-an-item)) <!-- visual --> |
| `ig_item_hovered([delay] [, stat])` → `logical` | the pointer is over the item drawn last; `delay` `'none'`, `'short'` (0.15 s) or `'normal'` (0.40 s) ([What happened to an item](widgets#what-happened-to-an-item)) <!-- visual --> |
| `ig_any_item_hovered()` → `logical`, `ig_any_item_active()` → `logical` | the pointer is over some item; some item is held or edited ([What happened to an item](widgets#what-happened-to-an-item)) <!-- visual --> |
| `ig_scroll_here([ratio] [, axis] [, stat])` | after an item: scroll its line to `ratio` of the visible height (0 top, 0.5 centre, 1 bottom), on the next frame ([Scrolling and focus](widgets#scrolling-and-focus)) <!-- visual --> |
| `ig_scroll_to_pos(pos [, ratio] [, axis] [, stat])` | scroll the point `pos` [pixels] of the content to `ratio` of the visible height: a row a clipper does not draw ([Scrolling and focus](widgets#scrolling-and-focus)) <!-- visual --> |
| `ig_get_scroll(y, ymax [, x] [, xmax])` | the scroll of the current window or region and its largest value [pixels] ([Scrolling and focus](widgets#scrolling-and-focus)) <!-- visual --> |
| `ig_set_scroll([y] [, x])` | scroll the current window or region to `y`, `x` [pixels] ([Scrolling and focus](widgets#scrolling-and-focus)) <!-- visual --> |
| `ig_focus_here([offset] [, stat])` | the next item takes the keyboard focus (a field is edited, as if clicked) ([Scrolling and focus](widgets#scrolling-and-focus)) <!-- visual --> |
| `ig_default_focus()` | the item drawn last has the focus when its window (a modal, a popup) appears ([Scrolling and focus](widgets#scrolling-and-focus)) <!-- visual --> |

Details: [Widgets](widgets).

## Docking: `ig_dock_*`

| Procedure | Does |
|---|---|
| `ig_dock_id(name)` → `integer(int32)` | the dock id of a name ([Docking](docking#a-layout-set-by-the-program)) |
| `ig_dock_space(id [, flags] [, stat])` | a dock space over the display, every frame, before its windows ([Docking](docking#a-layout-set-by-the-program)) |
| `ig_dock_layout_begin(id [, stat])` → `logical` | `.true.` when the dock space needs its layout (first time) ([Docking](docking#a-layout-set-by-the-program)) |
| `ig_dock_split(id, direction, fraction, id_at_dir, id_other [, stat])` | split a dock node in two ([Docking](docking#a-layout-set-by-the-program)) |
| `ig_dock_window(name, id [, stat])` | put a window into a dock node of the layout ([Docking](docking#a-layout-set-by-the-program)) |
| `ig_dock_layout_end(id [, stat])` | finish the layout ([Docking](docking#a-layout-set-by-the-program)) |
| `ig_window_dock(id, docked)` | inside a window: its dock node and whether it is docked ([Docking](docking#a-layout-set-by-the-program)) |
| `ig_set_next_window_dock(id [, always])` | dock the next window into a node the first time it appears (a window created after the layout) ([Docking](docking#a-window-that-appears-later)) |

Details: [Docking](docking).

## Styles: `ig_/ip_ set_/get_ style_color`, `style_var`

| Procedure | Does |
|---|---|
| `ig_set_style_color(name, color [, stat])`, `ip_set_style_color(...)` | a colour by name (`'#rrggbb[aa]'` or components) ([Styles](styles#colours-and-variables-by-name)) <!-- visual --> |
| `ig_get_style_color(name, rgba [, stat])`, `ip_get_style_color(...)` | a colour by name ([Styles](styles#colours-and-variables-by-name)) <!-- visual --> |
| `ig_set_style_var(name, value [, stat])`, `ip_set_style_var(...)` | a style variable by name (number, pair, logical, integer) ([Styles](styles#colours-and-variables-by-name)) <!-- visual --> |
| `ig_get_style_var(name, values, n [, stat])`, `ip_get_style_var(...)` | a style variable by name ([Styles](styles#colours-and-variables-by-name)) <!-- visual --> |
| `ig_show_style_editor([open] [, stat])` | Dear ImGui's and ImPlot's style editors, in a window ([Styles](styles#load-tune-and-save)) <!-- visual --> |
| `ig_push_font(font [, size] [, stat])`, `ig_pop_font([stat])` | another font (`'plex-mono'` for columns that line up) or size for a block of widgets ([Fonts](styles#fonts)) |
| `ig_push_style_color(name, color [, stat])`, `ig_pop_style_color([n] [, stat])` | a colour for a block of widgets ([Styles](styles#changes-for-a-block)) <!-- visual --> |
| `ip_push_style_color(name, color [, stat])`, `ip_pop_style_color([n] [, stat])` | a colour for a block of plots ([Styles](styles#changes-for-a-block)) <!-- visual --> |
| `ig_push_style_var(name, value [, stat])`, `ig_pop_style_var([n] [, stat])` | a style variable for a block of widgets ([Styles](styles#changes-for-a-block)) <!-- visual --> |
| `ip_push_style_var(name, value [, stat])`, `ip_pop_style_var([n] [, stat])` | a style variable for a block of plots ([Styles](styles#changes-for-a-block)) <!-- visual --> |
| `ICON_*` (`ICON_PLAY`, `ICON_FILE_PEN`, ... 2171 Lucide icons) | an icon as a UTF-8 string, for any label: `ICON_PLAY//' Run'` ([Icons](styles#icons)) |

Details: [Styles](styles), [Icons](styles#icons).

## Plots: `ip_*`

| Procedure | Purpose |
|---|---|
| `ip_begin_plot(title [, width] [, height] [, equal])` → `logical` | begin a plot; `.true.` when visible ([plots](plots#a-plot)) |
| `ip_setup_axes(xlabel, ylabel [, auto_fit] [, xlog] [, ylog] [, xformat] [, yformat] [, xscale] [, yscale] [, stat])` | labels of X1 and Y1; the axes fit the data on first use, every frame with `auto_fit=.true.`; `xscale`/`yscale`: `'linear'`, `'log'`, `'symlog'`, `'time'` (`xlog`/`ylog`: deprecated `'log'`); `xformat`/`yformat`: tick label formats ([checked](plots#formats)) |
| `ip_begin_subplots(title, rows, cols [, width] [, height] [, link_x] [, link_y])` → `logical`, `ip_end_subplots()` | a grid of plots, optionally sharing the x or y range ([plots](plots#several-plots-in-one-figure)) <!-- visual --> |
| `ip_setup_axes_limits(xmin, xmax, ymin, ymax [, always] [, stat])` | initial ranges of X1 and Y1 ([plots](plots#axes)) <!-- visual --> |
| `ip_setup_axis(axis [, label] [, scale] [, auto_fit] [, format] [, opposite] [, invert] [, lock] [, no_grid] [, stat])` | set up one of the six axes `'x1'`..`'x3'`, `'y1'`..`'y3'`: label, scale (`'linear'`, `'log'`, `'symlog'`, `'time'`), format, side, direction, lock, grid ([plots](plots#axes)) <!-- visual --> |
| `ip_set_axes(x, y [, stat])` | the axes the next items use (`'x1'`..`'x3'`, `'y1'`..`'y3'`) ([plots](plots#axes)) <!-- visual --> |
| `ip_setup_axis_limits(axis, vmin, vmax [, always] [, stat])` | initial range of one axis ([plots](plots#axes)) <!-- visual --> |
| `ip_setup_axis_ticks(axis, values [, labels] [, stat])` | ticks at given values, with given labels or the axis's format ([plots](plots#axes)) <!-- visual --> |
| `ip_setup_axis_constraints(axis [, vmin] [, vmax] [, zoom_min] [, zoom_max] [, stat])` | bounds the user cannot pan or zoom one axis past ([plots](plots#axes)) <!-- visual --> |
| `ip_setup_legend([location] [, outside] [, horizontal] [, stat])` | the legend at a compass point, inside or outside the plot area, in a column or a row ([plots](plots#axes)) <!-- visual --> |
| `ip_plot_limits(xmin, xmax, ymin, ymax [, xaxis] [, yaxis] [, stat])`, `ip_plot_size(...)` | the ranges the user panned and zoomed to, of the current axes or the named ones; the plot's size in pixels ([plots](plots#reading-a-plot)) <!-- visual --> |
| `ip_line(label, x, y [, spec] [, stat])` | a line through `(x(i), y(i))`; arrays of any stride read in place, `x` may be `int32`/`int64` ([plots](plots#data-in-place)) |
| `ip_line(label, y [, xscale, xstart] ...)`, `ip_line(label, y, row ...)` | uniform x; a matrix row read in place ([plots](plots#items)) <!-- visual --> |
| `ip_scatter(label, x, y [, spec] [, stat])` | markers at `(x(i), y(i))` ([plots](plots#items)) <!-- visual --> |
| `ip_bars(label, x, y, bar_size [, spec] [, stat])` | bars of height `y(i)` at `x(i)` ([plots](plots#items)) <!-- visual --> |
| `ip_shaded(label, x, y1, y2 [, spec] [, stat])`, `ip_shaded(label, x, y, yref ...)` | area between two curves, or a curve and `y = yref` ([plots](plots#items)) <!-- visual --> |
| `ip_spec(...)` → `plot_spec_object` | item style: colours, line weight, markers, flags (`ImPlotMarker_*`, `ImPlot*Flags_*`) ([plots](plots#item-style)) |
| `ip_heatmap(label, f, xmin, xmax, ymin, ymax ...)` | a field `f(i, j)` as coloured cells, read in place, j = 1 at the bottom ([heatmaps](images#heatmaps)) <!-- visual --> |
| `ip_colormap_scale(label, scale_min, scale_max ... [, colormap] [, stat])` | the colour bar of a heatmap (default colormap: Viridis) ([heatmaps](images#heatmaps)) <!-- visual --> |
| `ip_colormap_legend(id, colormap, vmin, vmax [, levels] [, horizontal] [, width] [, height] [, label_format] [, scale] [, stat])` | a colour-scale legend, vertical or horizontal, continuous or in bands, ticks on a linear, log or symlog scale ([legend](colormaps#a-colour-scale-legend)) <!-- visual --> |
| `ip_colormap_legend_edit(id, colormap, vmin, vmax [, levels] [, horizontal] [, width] [, height] [, label_format] [, scale] [, stat])` → `logical` | the same legend whose range the user drags and zooms with the wheel; `vmin`, `vmax` updated in place ([fields](plots#fields)) <!-- visual --> |
| `ip_field_image(label, f, x0, x1, y0, y1 [, colormap] [, vmin] [, vmax] [, scale] [, nan_color] [, changed] [, range] [, stat])` | a field through a colormap in one call: a texture coloured when it changes, linear, log or symlog, NaN colour ([fields](plots#fields)) <!-- visual --> |
| `ip_colormap(name [, levels] [, stat])` → `integer(int32)` | a colormap's id by name: bundled (`'cividis'`, `'batlow'`, `'cool-warm'`, ...), ImPlot's own or loaded; `<name>_r` reversed, `levels` discrete bands ([colormaps](colormaps)) <!-- visual --> |
| `ip_load_colormap(name, file [, stat])` | a user colormap from a CSV table of RGB rows or a ParaView JSON preset ([user maps](colormaps#user-maps)) |
| `ip_colormap_names(names)` | the names `ip_colormap` knows ([colormaps](colormaps)) <!-- visual --> |
| `ip_image(label, tex, xmin, xmax, ymin, ymax ...)` | a texture in a plot, pixel row 1 at the bottom ([textures](images#textures)) |
| `ip_error_bars(label, x, y, err [, err_high] [, spec] [, stat])` | vertical error bars, symmetric or not ([plots](plots#error-bars-annotations-and-drag-tools)) <!-- visual --> |
| `ip_annotation(x, y, text [, color] [, offset] [, stat])` | a text at a plot point, in a box of a colour or alone ([plots](plots#error-bars-annotations-and-drag-tools)) <!-- visual --> |
| `ip_drag_line_x(id, x [, color] [, thickness] [, stat])` → `logical`, `ip_drag_line_y(...)` | a vertical (horizontal) line the user drags; the value updated in place ([plots](plots#error-bars-annotations-and-drag-tools)) <!-- visual --> |
| `ip_drag_point(id, x, y [, color] [, radius] [, stat])` → `logical` | a point the user drags ([plots](plots#error-bars-annotations-and-drag-tools)) <!-- visual --> |
| `ip_contour(label, f, x0, x1, y0, y1 [, levels] [, nlevels] [, colormap] [, color] [, labels] [, line_weight] [, stat])` | contour lines of a field, read in place; NaNs leave holes ([plots](plots#contour-lines)) |
| `ip_contour_lines(f, x0, x1, y0, y1, levels, x, y, first)` | the contour segments without drawing them (marching squares, `pure`) ([plots](plots#contour-lines)) |
| `ip_contour_levels(f [, count])` → `real(real64)` array | levels at round numbers inside a field's finite range ([plots](plots#contour-lines)) |
| `ip_stairs(label, x, y [, spec] [, stat])` | a staircase through the points; pre-step or shaded by flags ([plots](plots#items)) <!-- visual --> |
| `ip_stems(label, x, y [, ref] [, spec] [, stat])` | stems from `y = ref` to the points, with markers ([plots](plots#items)) <!-- visual --> |
| `ip_inf_lines(label, values [, horizontal] [, spec] [, stat])` | lines across the whole plot at x (or y) values, real or integer ([plots](plots#marks-in-a-plot)) <!-- visual --> |
| `ip_histogram(label, values [, bins] [, vmin] [, vmax] [, bar_scale] [, max_count] [, spec] [, stat])` | a histogram: a bin count or a rule (`ImPlotBin_*`), NaNs left out ([plots](plots#histograms)) |
| `ip_histogram2d(label, x, y [, xbins] [, ybins] [, xmin] [, xmax] [, ymin] [, ymax] [, colormap] [, max_count] [, spec] [, stat])` | a 2-D histogram, cells coloured by count ([plots](plots#histograms)) |
| `ip_plot_hovered([stat])` → `logical` | the pointer is over the plot area ([plots](plots#reading-a-plot)) <!-- visual --> |
| `ip_plot_mouse(x, y [, xaxis] [, yaxis] [, stat])` | the pointer in plot units ([plots](plots#reading-a-plot)) <!-- visual --> |
| `ip_plot_to_pixels(x, y, px, py [, xaxis] [, yaxis] [, stat])`, `ip_pixels_to_plot(px, py, x, y ...)` | plot units to display pixels and back ([plots](plots#reading-a-plot)) <!-- visual --> |
| `ip_plot_selection(xmin, xmax, ymin, ymax [, xaxis] [, yaxis] [, stat])` → `logical`, `ip_cancel_selection([stat])` | the box the user drags with the right button; ended without the zoom ([plots](plots#reading-a-plot)) <!-- visual --> |
| `ip_drag_rect(id, xmin, xmax, ymin, ymax [, color] [, stat])` → `logical` | a rectangle the user moves and resizes; the values updated in place ([plots](plots#marks-in-a-plot)) <!-- visual --> |
| `ip_tag(axis, value [, color] [, text] [, stat])` | a box on an axis at a value, with a text or the axis's label ([plots](plots#marks-in-a-plot)) <!-- visual --> |
| `ip_text(text, x, y [, offset] [, vertical] [, stat])` | a text at a plot point ([plots](plots#marks-in-a-plot)) <!-- visual --> |
| `ip_end_plot()` | end the plot (only if `ip_begin_plot` returned `.true.`) ([plots](plots#a-plot)) |

Items take `real(real32)` or `real(real64)` arrays. Details: [Plots](plots), [Colormaps](colormaps).

## Images: `texture_object`, `ig_image`

| Procedure | Purpose |
|---|---|
| `tex%init(width, height [, smooth] [, stat])`, `tex%update(rgba [, stat])`, `tex%destroy()` | an RGBA texture on the GPU, `integer(int8) :: rgba(4, width, height)` uploaded in place ([textures](images#textures)) |
| `tex%width()`, `tex%height()` → `integer(int32)`, `tex%is_initialized()` → `logical` | its size (0 before `init`); whether it exists ([textures](images#textures)) |
| `ig_image(tex [, width, height])` | the texture in a window, pixel row 1 at the top ([textures](images#textures)) |

Details: [Heatmaps and images](images).

## Canvas: `ig_canvas`, `ig_draw_*`

| Procedure | Purpose |
|---|---|
| `ig_canvas(id, width, height, ev [, texture] [, stat])` | an area taking the mouse; `ev` a `canvas_event_object`: hovered, active, clicked, double-clicked, down and released per button, the pointer in canvas pixels, the drag, the wheel (owned while hovered), the modifiers, the canvas's origin and size ([Canvas](canvas#the-canvas)) <!-- visual --> |
| `ig_draw_line(x1, y1, x2, y2, color [, thickness] [, layer] [, stat])` | a segment ([Primitives](canvas#primitives)) <!-- visual --> |
| `ig_draw_rect(x1, y1, x2, y2, color [, thickness] [, filled] [, layer] [, stat])` | a rectangle, outline or filled ([Primitives](canvas#primitives)) <!-- visual --> |
| `ig_draw_circle(x, y, radius, color [, thickness] [, filled] [, layer] [, stat])` | a circle, its radius in pixels ([Primitives](canvas#primitives)) <!-- visual --> |
| `ig_draw_polyline(x, y, color [, thickness] [, closed] [, layer] [, stat])` | a polyline through the arrays `x(:)`, `y(:)` ([Primitives](canvas#primitives)) <!-- visual --> |
| `ig_draw_polygon(x, y, color [, thickness] [, filled] [, layer] [, stat])` | a polygon, outline or filled, convex or not ([Primitives](canvas#primitives)) <!-- visual --> |
| `ig_draw_text(x, y, text, color [, layer] [, stat])` | text, its top-left at the point ([Primitives](canvas#primitives)) <!-- visual --> |
| `ig_draw_image(texture, x1, y1, x2, y2 [, color] [, layer] [, stat])` | a texture stretched over a rectangle, tinted by `color` ([Primitives](canvas#primitives)) <!-- visual --> |
| `ig_cursor_screen_pos(x, y)` | where the next item goes, in screen pixels ([Coordinates](canvas#coordinates)) |
| `ig_invisible_button(id, width, height [, stat])` → `logical` | a button that draws nothing: a hot zone over a drawing ([The canvas](canvas#the-canvas)) <!-- visual --> |

`layer` is `'window'` (default), `'foreground'`, `'background'` or `'plot'` (plot units, inside a plot). Details:
[Canvas](canvas).

## Processes: `process_object`, `log_view_object`

| Procedure | Purpose |
|---|---|
| `p%start(args [, cwd] [, env] [, merge_stderr] [, detached] [, log_file] [, stat])` | start a program, the arguments as an array (no shell): captured (output piped) or detached (output to `log_file`, it outlives the program) ([processes](processes#processes)) <!-- visual --> |
| `p%poll(lines [, stat])` | the complete lines printed since the last poll (`character(len=:), allocatable :: lines(:)`) ([processes](processes#processes)) <!-- visual --> |
| `p%running()` → `logical`, `p%exit_code([stat])` → `int32`, `p%killed()` → `logical`, `p%pid()` → `int64` | its state: running, its exit code (captured, ended), ended by `kill`, its process id ([processes](processes#processes)) <!-- visual --> |
| `p%kill([force] [, stat])` | ask it to end (`force`: at once) ([processes](processes#processes)) <!-- visual --> |
| `log%add(line \| lines)`, `log%clear()`, `log%set_cap(cap [, stat])` | the lines of a log view, a ring buffer of `cap` lines (default 10000) ([log view](processes#the-log-view)) |
| `log%draw(id [, height])` | the lines in a region of their own, only those in view; follows the end while at the bottom; click, shift+click, ctrl+c to copy ([log view](processes#the-log-view)) |
| `log%count()` → `int32`, `log%line(i)` → `character`, `log%following()` → `logical`, `log%in_view(first, last)`, `log%copy([all])` → `character` | the lines kept, one line, whether the view follows the end, the lines in view, the chosen lines ([log view](processes#the-log-view)) |

Details: [Processes and tasks](processes).

## Tasks: `task_object`, `task_handle_object`

| Procedure | Purpose |
|---|---|
| `t%start(work, data [, stat])` | run `work(h, data)` (a `task_work` module procedure) on a worker thread, on a copy of `data` (`class(*)`) ([tasks](processes#tasks)) <!-- visual --> |
| `t%running()` → `logical`, `t%done()` → `logical`, `t%progress(fraction [, message])` | it runs; it has ended (its result waits); its last progress in [0, 1] and message ([tasks](processes#tasks)) <!-- visual --> |
| `t%cancel([stat])`, `t%result(data [, stat])` | ask it to stop at its next safe point; once done, its data moved out (`class(*), allocatable`) ([tasks](processes#tasks)) <!-- visual --> |
| `h%report(fraction [, message])`, `h%cancelled()` → `logical`, `h%fail(message)` | in the task: post progress (wakes the frame loop), the program asked it to stop, report a failure ([tasks](processes#tasks)) <!-- visual --> |

A task never draws: FIGURE's drawing entry points refuse a call from a worker with `FIG_ERR_STATE`.
Details: [Processes and tasks](processes#tasks).

## 3-D views: `view3d_object`

| Procedure | Purpose |
|---|---|
| `v%init([threads] [, fast_moves] [, lighting] [, background] [, stat])`, `v%destroy()`, `v%is_initialized()` → `logical` | create a 3-D view drawn by FIGURE's software rasterizer (the same pixels in every mode); release it; whether it exists ([meshes](view3d#meshes)) |
| `v%triangles(xyz, tri [, scalar] [, cell_scalar] [, colormap] [, color] [, edges] [, flat] [, stat])` → `int32`, `v%quads(xyz, quad [, ...])` → `int32`, `v%surface(xyz [, ...])` → `int32`, `v%lines(xyz [, seg] [, ...])` → `int32` | add a mesh, read in place from the program's `target` arrays: triangles, quads, a structured surface `xyz(3, ni, nj)`, lines; coloured by a scalar per vertex or per cell through a colormap, or in one colour ([meshes](view3d#meshes)) |
| `v%set_mesh(mesh [, scalar] [, cell_scalar] [, no_scalar] [, colormap] [, vmin, vmax] [, auto_range] [, color] [, edges] [, edge_color] [, flat] [, visible] [, stat])`, `v%changed([mesh] [, stat])`, `v%remove(mesh [, stat])`, `v%clear([stat])` | change a mesh's field or style; its arrays changed in place; remove one, all ([fields and colours](view3d#fields-and-colours)) |
| `v%set_camera([target] [, distance] [, azimuth] [, elevation] [, fov] [, stat])`, `v%get_camera(...)`, `v%fit([stat])`, `v%view(name [, stat])`, `v%orbit(azimuth [, elevation] [, stat])`, `v%pan(right, up [, stat])`, `v%zoom(factor [, stat])` | the camera: set, read, fit, the six standard views (`'+x'` ... `'-z'`), turn, move, zoom ([the camera](view3d#the-camera)) |
| `v%clip(normal, point [, stat])`, `v%unclip([stat])` | clipping planes (up to 6) ([clipping planes](view3d#clipping-planes)) |
| `v%draw(id [, width] [, height] [, stat])` | the view as a widget; the mouse orbits, pans, zooms, fits; rendered only when something changed, at half resolution while moving ([meshes](view3d#meshes)) |
| `v%pick(x, y, mesh, element [, point] [, stat])` → `logical`, `v%hovered(mesh, element [, point] [, stat])` → `logical`, `v%clicked(...)` → `logical` | the element under a pixel, under the mouse, clicked ([picking](view3d#picking)) |
| `v%image(rgba [, stat])`, `v%render_info([count] [, milliseconds] [, width] [, height] [, half] [, stat])` | the pixels of the last render; renders so far, the last one's time and size ([rendering](view3d#how-a-view-is-rendered)) |

Details: [3-D views](view3d).

## Testing: `figure_testing`

| Procedure | Does |
|---|---|
| `test_click(x, y [, button])`, `test_drag(x0, y0, x1, y1)` | queue a click, a drag ([synthetic input](testing#synthetic-input)) |
| `test_mouse_move`, `test_mouse_button`, `test_wheel` | queue mouse input, one part at a time ([synthetic input](testing#synthetic-input)) |
| `test_key(name [, down])`, `test_type(text)` | queue keys and typed text ([synthetic input](testing#synthetic-input)) |
| `test_drop(paths, x, y [, stat])` | queue a drop of files or folders at (x, y), reported by `app%dropped` on the next frame ([synthetic input](testing#synthetic-input)) |
| `test_next_frame()` | a frame boundary in the queued input ([synthetic input](testing#synthetic-input)) |
| `test_item_center(x, y)`, `test_window_rect(name, ...)` | where a widget or a window is ([synthetic input](testing#synthetic-input)) |
| `test_popup_rect(xmin, ymin, xmax, ymax [, found] [, stat])` | where the open popup is (a menu, a context menu, a combo's list, a colour picker) ([synthetic input](testing#synthetic-input)) |
| `test_opened_url()` → `character` | the URL the last click on an `ig_text_link_url` asked to open (headless mode opens nothing) ([Links](widgets#links)) |
| `test_quit()` | a quit request, as the window's close button makes it ([synthetic input](testing#synthetic-input)) |
| `test_plot_tick(axis, index, label [, count] [, stat])` | a tick label of any of the six axes of the plot being declared (`'x1'`..`'y3'`; `'x'`, `'y'`) ([plots](plots#axes)) <!-- visual --> |
| `test_plot_copies()` → `int64` | the arrays the plot items copied so far (a stride differing from the ordinates', integer abscissae) ([plots](plots#data-in-place)) |
| `test_plot_stride()` → `int64` | the byte stride the last plot item gave ImPlot ([plots](plots#data-in-place)) |
| `test_field_uploads()` → `int64` | the colourings `ip_field_image` uploaded so far ([fields](plots#fields)) <!-- visual --> |
| `test_field_textures()` → `int32` | the field textures kept ([fields](plots#fields)) <!-- visual --> |
| `test_field_time()` → `real64` | the last colouring's time [ms] ([fields](plots#fields)) <!-- visual --> |
| `test_field_pixel(label, i, j, rgba [, stat])` | the colour a field's value got ([fields](plots#fields)) <!-- visual --> |
| `test_frame_hit(x, y)` → `character` | what the frame of `decorations='figure'` does at a point: `'client'`, `'drag'`, `'resize-top-left'`, ... ([the window's frame](frame-loop#the-window-s-frame)) <!-- visual --> |
| `test_frame_rect(part, x0, y0, x1, y1 [, found] [, stat])` | a part of its title bar in the last frame: `'bar'`, `'icon'`, `'menus'`, `'title'`, `'minimize'`, `'maximize'`, `'close'` ([synthetic input](testing#synthetic-input)) |
| `test_frame_state(minimized, maximized [, stat])` | the window minimized, maximized (headless: as the bar's buttons recorded it) ([synthetic input](testing#synthetic-input)) |
| `test_system_theme(theme [, stat])` | the system's light or dark setting changes (`'light'`, `'dark'`, `'system'`), at the next frame: tests of `palette='auto'` ([styles](styles#follow-the-system-s-light-or-dark-setting)) |
| `test_notification_rect(index, x0, y0, x1, y1 [, found] [, alpha])` | a notification shown in the last frame, 1 the newest, and the alpha it was drawn with ([notifications](frame-loop#notifications)) <!-- visual --> |
| `test_drawn_extent(color, x0, y0, x1, y1 [, found] [, stat] [, layer] [, vertices])` | the extent drawn so far in the current window in a style colour by name (`'PlotHistogram'`: a progress bar's fill) or an RGBA colour (an item's `ip_spec` colour); with `layer`, the foreground or background layer; `vertices`, how many ([Canvas](canvas#testing-a-canvas)) |
| `test_file_browser(shown [, folder] [, entries] [, error] [, asking] [, path_field] [, name_field] [, recent])` | the file browser in front: its folder, the entries in the order shown, the error shown, the replace question, the fields, the recent folders ([file browser](frame-loop#figure-s-file-browser)) <!-- visual --> |
| `test_file_browser_rect(part, x0, y0, x1, y1 [, found])` | a part of the file browser in the last frame (`'entry:NAME'`, `'ok'`, `'cancel'`, `'path'`, ...), to click it ([synthetic input](testing#synthetic-input)) |
| `test_settings_file(path [, stat])` | the file keeping the browser's recent folders, instead of FIGURE's own (`''`: memory only) ([synthetic input](testing#synthetic-input)) |

Details: [Headless testing](testing#synthetic-input).

## Errors

| Entity | Purpose |
|---|---|
| `FIG_OK`, `FIG_ERR_STATE`, `FIG_ERR_ARGUMENT`, `FIG_ERR_FAILED`, `FIG_ERR_EXCEPTION` | status codes returned in `stat` ([stat or error stop](errors#stat-or-error-stop)) |
| `figure_last_error()` → `character(len=:), allocatable` | message of the last failure ([figure_last_error](errors#figure-last-error)) |

Details: [Error handling](errors).

## Environment variables

| Variable | Effect |
|---|---|
| `FIGURE_DEBUG_REDRAW` | any value: once per second, redraw statistics on standard error (window mode) — see [frame loop](frame-loop#redraw-diagnostics) |
| `FIGURE_STYLE` | the style at initialisation: a name of `app%set_style`, or a theme file — see [styles](styles) |
| `FIGURE_CAPTURE`, `FIGURE_CAPTURE_*` | record the frames of a window to image files, with scripted input — see [screenshots and videos](capture) |
| `GALLIUM_DRIVER=d3d12` | not read by FIGURE: on WSL2, makes Mesa render on the GPU — see [installation](install#wsl2-wslg) |
| `SDL_VIDEO_DRIVER` | read by SDL3: `x11` or `wayland` to choose the video driver |
