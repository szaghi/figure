---
title: Menus and shortcuts
---

# Menus and shortcuts

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
