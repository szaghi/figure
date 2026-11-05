---
title: Menus, popups and shortcuts
---

# Menus, popups and shortcuts

<Media name="cb_menu" video alt="A title typed, saved from the File menu; edited and saved with ctrl+s; Autosave ticked, then an edit saved at once" caption="docs/examples/src/cb_menu.F90: the File menu, its shortcut and a check-mark item" />

## Menus

<<< @/examples/snippets/cb_menu-menu.F90{fortran}

| Procedure | Notes |
|---|---|
| `ig_begin_main_menu_bar()` → `logical`, `ig_end_main_menu_bar()` | The bar along the top of the display. |
| `ig_begin_menu_bar()` → `logical`, `ig_end_menu_bar()` | A window's own bar: the window needs `ImGuiWindowFlags_MenuBar` in its `ig_begin`. |
| `ig_begin_menu(label [, enabled])` → `logical`, `ig_end_menu()` | A menu of a bar, or a submenu of a menu; `.true.` while open. |
| `ig_menu_item(label [, shortcut] [, selected] [, enabled])` → `logical` | `.true.` on the frame the item is picked; the menu closes. |

Each end follows only a begin that returned `.true.` (Dear ImGui's rule for menus, as for tabs and tables; windows
differ: `ig_end` follows every `ig_begin`).

- `shortcut` is text shown on the right of the item, nothing more: the keys are read by `ig_shortcut`.
- With `selected`, the item shows a check mark when `.true.`, and picking it toggles the variable.
- A disabled item (`enabled=.false.`) is greyed out and cannot be picked; a disabled menu cannot be opened.

## Shortcuts

`ig_shortcut(keys [, stat])` is `.true.` on the frame the key chord `keys` is pressed: modifiers (`ctrl`, `shift`,
`alt`, `super`) and one key, by the names of [`test_key`](testing#synthetic-input), joined by `+`: `'ctrl+s'`,
`'ctrl+shift+z'`, `'f5'`, `'escape'`.

- Once per press: holding the keys does not repeat it.
- Call it every frame, outside the menus: a menu is closed most of the time, and its items' `shortcut` text does
  nothing by itself.
- **macOS:** `ctrl` is the cmd key there, as for every shortcut in Dear ImGui, so `'ctrl+s'` is cmd+s for a macOS user,
  with no change to the program. In [remote mode](remote) the browser on a Mac sends cmd as ctrl for the same reason.
- An unknown name returns `.false.` and `FIG_ERR_ARGUMENT` in `stat` (without `stat`, the program stops with the
  message).

## Popups and modals

A popup is opened once, by an event, and declared every frame:

<<< @/examples/snippets/cb_quit-popup.F90{fortran}

| Procedure | Notes |
|---|---|
| `ig_open_popup(id)` | Open the popup `id`: once, on the event (a click, a quit request), not every frame. |
| `ig_begin_popup(id)` → `logical`, `ig_end_popup()` | A popup without a title bar; `.true.` while open. It closes on a click outside it. |
| `ig_begin_popup_modal(title [, open])` → `logical`, `ig_end_popup()` | A modal dialog: the rest of the interface is greyed out and ignores input while it is open. Its size fits its content; with `open`, a close button. |
| `ig_close_current_popup()` | Close the popup or modal being declared: call it inside, on its OK or Cancel. |

`ig_end_popup` follows only a begin that returned `.true.`. Open and begin use the same id, in the same window (the
id is scoped like a widget's label).

## Ask before quitting

<Media name="cb_quit" video alt="A title edited and an option ticked in a popup; the window closed: a modal asks Save, Discard or Cancel; Cancel; closed again" caption="docs/examples/src/cb_quit.F90" />

<<< @/examples/snippets/cb_quit-quit.F90{fortran}

| Procedure | Notes |
|---|---|
| `app%set_confirm_quit(enabled)` | With `.true.`, the window's close button (and the system's quit) no longer ends `next_frame`. |
| `app%quit_requested()` → `logical` | `.true.` once per request: open the dialog then. |
| `app%quit()` | The next `next_frame` returns `.false.` (every mode). |

A test makes the request with `test_quit()` ([Headless testing](testing#synthetic-input)); a capture script with
`<frame> close` ([Frame capture](capture)).
