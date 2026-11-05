---
title: figure_menu
---

# figure_menu

> figure_menu, menus and keyboard shortcuts.

 Pairing (Dear ImGui's): each `ig_end_*` only after its `ig_begin_*` returned true. A window's own menu bar needs the
 window flag `ImGuiWindowFlags_MenuBar` in its `ig_begin`. A menu item's shortcut text is only shown: the program
 reacts to the keys with `ig_shortcut`, every frame, outside the menu (the menu is closed most of the time).

**Source**: `src/lib/figure_menu.F90`

**Dependencies**

```mermaid
graph LR
  figure_menu["figure_menu"] --> figure_base["figure_base"]
  figure_menu["figure_menu"] --> figure_c_native["figure_c_native"]
  figure_menu["figure_menu"] --> figure_cimgui["figure_cimgui"]
  figure_menu["figure_menu"] --> iso_c_binding["iso_c_binding"]
  figure_menu["figure_menu"] --> iso_fortran_env["iso_fortran_env"]
```

## Contents

- [ig_end_main_menu_bar](#ig-end-main-menu-bar)
- [ig_end_menu_bar](#ig-end-menu-bar)
- [ig_end_menu](#ig-end-menu)
- [ig_begin_main_menu_bar](#ig-begin-main-menu-bar)
- [ig_begin_menu_bar](#ig-begin-menu-bar)
- [ig_begin_menu](#ig-begin-menu)
- [ig_menu_item](#ig-menu-item)
- [ig_shortcut](#ig-shortcut)

## Subroutines

### ig_end_main_menu_bar

End the main menu bar (only after `ig_begin_main_menu_bar` returned true).

```fortran
subroutine ig_end_main_menu_bar()
```

**Call graph**

```mermaid
flowchart TD
  ig_end_main_menu_bar["ig_end_main_menu_bar"] --> igEndMainMenuBar["igEndMainMenuBar"]
  style ig_end_main_menu_bar fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_end_menu_bar

End the window's menu bar (only after `ig_begin_menu_bar` returned true).

```fortran
subroutine ig_end_menu_bar()
```

**Call graph**

```mermaid
flowchart TD
  ig_end_menu_bar["ig_end_menu_bar"] --> igEndMenuBar["igEndMenuBar"]
  style ig_end_menu_bar fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_end_menu

End a menu (only after `ig_begin_menu` returned true).

```fortran
subroutine ig_end_menu()
```

**Call graph**

```mermaid
flowchart TD
  ig_end_menu["ig_end_menu"] --> igEndMenu["igEndMenu"]
  style ig_end_menu fill:#3e63dd,stroke:#99b,stroke-width:2px
```

## Functions

### ig_begin_main_menu_bar

Begin the menu bar along the top of the display; when true, declare menus, then `ig_end_main_menu_bar`.

**Returns**: `logical`

```fortran
function ig_begin_main_menu_bar() result(visible)
```

**Call graph**

```mermaid
flowchart TD
  ig_begin_main_menu_bar["ig_begin_main_menu_bar"] --> igBeginMainMenuBar["igBeginMainMenuBar"]
  style ig_begin_main_menu_bar fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_begin_menu_bar

Begin the current window's menu bar (the window needs `ImGuiWindowFlags_MenuBar`); then `ig_end_menu_bar`.

**Returns**: `logical`

```fortran
function ig_begin_menu_bar() result(visible)
```

**Call graph**

```mermaid
flowchart TD
  ig_begin_menu_bar["ig_begin_menu_bar"] --> igBeginMenuBar["igBeginMenuBar"]
  style ig_begin_menu_bar fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_begin_menu

A menu of a menu bar (or a submenu of a menu); true while it is open: declare its items, then `ig_end_menu`.

**Returns**: `logical`

```fortran
function ig_begin_menu(label, enabled) result(open)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Label (also its id). |
| `enabled` | logical | in | optional | The menu can be opened (default true). |

**Call graph**

```mermaid
flowchart TD
  ig_begin_menu["ig_begin_menu"] --> cstr["cstr"]
  ig_begin_menu["ig_begin_menu"] --> igBeginMenu["igBeginMenu"]
  style ig_begin_menu fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_menu_item

An item of an open menu; true on the frame it is picked (the menu then closes). `shortcut` is shown on the right
 (the keys themselves are read with `ig_shortcut`); with `selected`, the item shows a check mark and a pick toggles
 it; a disabled item (`enabled=.false.`) is greyed out and cannot be picked.

**Returns**: `logical`

```fortran
function ig_menu_item(label, shortcut, selected, enabled) result(picked)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `label` | character(len=*) | in |  | Label (also its id). |
| `shortcut` | character(len=*) | in | optional | Shortcut text, e.g. `'Ctrl+S'`. |
| `selected` | logical | inout | optional | Check mark, toggled by a pick. |
| `enabled` | logical | in | optional | The item can be picked (default true). |

**Call graph**

```mermaid
flowchart TD
  ig_menu_item["ig_menu_item"] --> cstr["cstr"]
  ig_menu_item["ig_menu_item"] --> igMenuItem_BoolPtr["igMenuItem_BoolPtr"]
  style ig_menu_item fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### ig_shortcut

True on the frame the key chord `keys` is pressed, e.g. `'ctrl+s'`, `'ctrl+shift+z'`, `'f5'`, `'escape'`:
 modifiers (`ctrl`, `shift`, `alt`, `super`) and one key, by the names of `test_key`, joined by `+`. Once per
 press, not repeated while held. On macOS `ctrl` is the cmd key (Dear ImGui follows the platform), so `'ctrl+s'`
 is cmd+s there. Call it every frame, outside menus. An unknown name: false, and `FIG_ERR_ARGUMENT` in `stat` (or
 `error stop` without it).

**Returns**: `logical`

```fortran
function ig_shortcut(keys, stat) result(pressed)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `keys` | character(len=*) | in |  | Key chord. |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart TD
  ig_shortcut["ig_shortcut"] --> fig_key_chord["fig_key_chord"]
  ig_shortcut["ig_shortcut"] --> figure_check["figure_check"]
  ig_shortcut["ig_shortcut"] --> igIsKeyChordPressed_Nil["igIsKeyChordPressed_Nil"]
  style ig_shortcut fill:#3e63dd,stroke:#99b,stroke-width:2px
```
