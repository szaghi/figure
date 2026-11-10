---
title: Menus, popups and shortcuts
---

# Menus, popups and shortcuts

<Media name="cb_menu" video alt="A title typed, saved from the File menu; edited and saved with ctrl+s; Autosave ticked, then an edit saved at once" caption="docs/examples/src/cb_menu.F90: the File menu, its shortcut and a check-mark item" />

## Menus

<<< @/examples/snippets/cb_menu-menu.F90{fortran}

| Procedure | Notes |
|---|---|
| `ig_begin_main_menu_bar()` → `logical`, `ig_end_main_menu_bar()` | The bar along the top of the display; with `decorations='figure'`, inside the window's title bar ([Frame loop](frame-loop#the-window-s-frame)). |
| `ig_begin_menu_bar()` → `logical`, `ig_end_menu_bar()` | A window's own bar: the window needs `ImGuiWindowFlags_MenuBar` in its `ig_begin`. |
| `ig_begin_menu(label [, enabled])` → `logical`, `ig_end_menu()` | A menu of a bar, or a submenu of a menu; `.true.` while open. |
| `ig_menu_item(label [, shortcut] [, selected] [, enabled])` → `logical` | `.true.` on the frame the item is picked; the menu closes. |

Each end follows only a begin that returned `.true.` (Dear ImGui's rule for menus, as for tabs and tables; windows
differ: `ig_end` follows every `ig_begin`).

- `shortcut` is text shown on the right of the item, nothing more: the keys are read by `ig_shortcut`.
- With `selected`, the item shows a check mark when `.true.`, and picking it toggles the variable.
- A disabled item (`enabled=.false.`) is greyed out and cannot be picked; a disabled menu cannot be opened.

## Shortcuts

<Media name="cb_shortcuts" video alt="Two panels, Blocks and Log. Blocks is clicked: down selects the next block, ctrl+s writes 'the blocks saved'. The name field is clicked and down is pressed: the selection stays, the key belongs to the field (it moves the keyboard navigation to the Run button). Log is clicked: ctrl+s writes 'the log saved', down leaves the block list alone, f5 presses Run in the other panel. f1 in the command field, while it is edited, shows the field's help; f1 after escape shows the general help." caption="docs/examples/src/cb_shortcuts.F90: the same chord in two panels, keys held by a text field, a global key owned by a button" />

| Procedure | Notes |
|---|---|
| `ig_shortcut(keys [, scope] [, repeat] [, stat])` → `logical` | `.true.` on the frame the chord `keys` is pressed and routed to this call. |
| `ig_set_next_item_shortcut(keys [, scope] [, stat])` | The next item owns the chord: the chord presses it, and its tooltip shows the chord. |

(Dear ImGui's `Shortcut` and `SetNextItemShortcut`, with the `ImGuiInputFlags_Route*` flags and
`ImGuiInputFlags_Repeat`.)

<<< @/examples/snippets/cb_shortcuts-keys.F90{fortran}

`keys` is a chord: modifiers (`ctrl`, `shift`, `alt`, `super`) and one key, by the names of
[`test_key`](testing#synthetic-input), joined by `+`: `'ctrl+s'`, `'ctrl+shift+z'`, `'f5'`, `'escape'`, `'down'`.

**Routing.** A chord goes to one place. Every call asks for the chord with a scope; Dear ImGui gives the chord, on the
next frame, to the window (or the item) whose call matches best where the user is, and only the calls made there
return `.true.`. So the calls are made **every frame**, whether or not the program expects the key: a call made only
now and then has no route on the frame the key arrives. The order of the calls in a frame does not matter, except
between two `'global'` calls (below).

| `scope` | Fires when |
|---|---|
| `'focused'` (default) | The window the call is made in has the keyboard focus, or a window inside it (a child region) does and does not take the chord itself. Of two windows that ask for one chord, the focused one fires; the other does not. **Outside every window** (after the last `ig_end`, the place of an application's own keys), the call fires whatever window has the focus, unless the focused window asks for the same chord: a panel overrides the application's key while it has the focus. |
| `'global'` | Wherever the focus is, and before the `'focused'` calls of the same chord. Of two `'global'` calls of one chord in different windows, the first of the frame fires. |
| `'item'` | While the item drawn just before the call is active: a text field being edited, a button held down. Keys for one field: f1 for the field's own help while it is edited, before every other call of f1. |

- **Text fields keep their keys.** While a text field is edited, a `'focused'` chord of one key alone or with shift,
  such as `'down'`, `'enter'`, `'escape'`, `'home'` or `'shift+left'`, does not fire: the field uses them (left,
  right, home and end move its cursor, enter and escape end the edit; in a one-line field, up and down move Dear
  ImGui's keyboard navigation to the widget above or below, ending the edit). Chords with ctrl, alt or super, and the function keys f1 to f24, still fire. Keys that type a
  character (`'a'`, `'space'`, `'shift+1'`) do not fire for `'global'` calls either (Dear ImGui's own rule). The
  chords a field routes itself (enter, ctrl+enter, shift+enter, ctrl+a, ctrl+c, ctrl+v, ctrl+x, ctrl+z, ctrl+y)
  stay the field's, for every scope. Keys for the field being edited go to an `'item'` call after it.
- **`repeat=.true.`** fires again while the chord is held, at the keyboard's repeat rate (Dear ImGui's
  `KeyRepeatDelay`, 0.275 s, then every `KeyRepeatRate`, 0.05 s); releasing or changing a modifier stops it. Without
  it, once per press.
- **macOS:** `ctrl` is the cmd key there, as for every shortcut in Dear ImGui, so `'ctrl+s'` is cmd+s for a macOS user,
  with no change to the program. In [remote mode](remote) the browser on a Mac sends cmd as ctrl for the same reason.
- **Menus:** call it outside the menus. A menu is closed most of the time, and a menu item's `shortcut` text does
  nothing by itself.
- **In a test**, press the platform's shortcut key with `test_key('shortcut', down=.true.)`: cmd on macOS, ctrl
  elsewhere. `test_key('ctrl')` is the physical ctrl key, which on macOS is not the shortcut key. A window gets the
  focus from a click on it (its title bar, to touch no widget).

::: warning Changed in v0.4.0
Until v0.3.1 `ig_shortcut` fired on every call, whatever had the focus (it called Dear ImGui's `IsKeyChordPressed`,
which does no routing): xall_figure's up and down keys moved its list while the user typed in a text field, and two
panels binding ctrl+s both saved. From v0.4.0 the default scope is `'focused'`. A call outside every window, the usual
place of an application's ctrl+s, ctrl+q or f1, keeps firing whatever has the focus. A call inside a window now fires
only while that window has the focus: for a key that must work everywhere, pass `scope='global'`, the old behaviour
for a chord asked for once (two `'global'` calls of one chord in different windows no longer both fire).
:::

### A button that owns a key

<<< @/examples/snippets/cb_shortcuts-button.F90{fortran}

`ig_set_next_item_shortcut` is called right before the item, every frame. The chord presses the item as a click
would (a button returns `.true.`, a checkbox toggles, a text field takes the keyboard), with the same scopes as
`ig_shortcut`, except `'item'`: the item owns the chord already. The item's tooltip shows the chord when the pointer
rests on it. While a text field is edited, a `'focused'` item does not take a chord of one key alone or with shift,
as above.

### A key for one field

<<< @/examples/snippets/cb_shortcuts-field.F90{fortran}

<<< @/examples/snippets/cb_shortcuts-help.F90{fortran}

`'item'` routes the chord to the item drawn just before the call, while it is active, before every other call of the
chord: f1 in the command field gives the field's help, f1 anywhere else the general one. The program runs headless
with `--check` and presses the keys itself:

<<< @/examples/output/cb_shortcuts.txt{text}

On frame 29 (not shown) down was pressed in the name field: the block list did not move (the keyboard navigation
went from the field to the Run button below it). On frame 53 the Log panel had the focus: the block list's down did not fire.

### Status, modes and threads

- **Status:** an unknown key or scope is `FIG_ERR_ARGUMENT` in `stat`: `ig_shortcut: unknown key "nosuchkey" in
  "ctrl+nosuchkey"`, `ig_shortcut: unknown scope "window" ('focused', 'global' or 'item')`,
  `ig_set_next_item_shortcut: unknown scope "item" ('focused' or 'global')`; also `more than one key in "..."` and
  `no key besides the modifiers in "..."`. `ig_shortcut` then returns `.false.`, and the next item has no chord.
  Without `stat`, the program stops with the message ([Error handling](errors)). With no frame open, or from a task:
  `FIG_ERR_STATE` ([Pairing and frames](errors#pairing-and-frames)). Neither procedure opens a scope.
- **Window:** the keyboard of the window. **Headless:** the keys of [`test_key`](testing#synthetic-input). **Remote:**
  the browser's keys; a browser keeps some chords for itself ([Known issues](known-issues#shortcuts-in-a-browser)).
- **Threads:** the frame loop's thread only; a task is refused (`FIG_ERR_STATE`), as every drawing call.
- **Disabled:** inside `ig_begin_disabled`/`ig_end_disabled`, `ig_shortcut` does not fire and a disabled item is not
  pressed by its chord.
- **What it does not do:** no key sequences (ctrl+k then ctrl+c), no chords of two keys besides the modifiers, no
  mouse buttons; the routing is Dear ImGui's, by window and item, not by the program's own areas inside a window
  (use a [child region](widgets#lists-and-regions) to give an area its own focus). FIGURE does not show a key's binding anywhere by
  itself: a menu item's `shortcut` text, and an item's tooltip with `ig_set_next_item_shortcut`, are the only places.

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
id is scoped like a widget's label). A wrong end (after a false begin, or with another scope innermost) is refused
and reported: [Pairing and frames](errors#pairing-and-frames).

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

### The window's title

An editor shows the document in the window's title, with a mark while it has unsaved changes. Set it whenever it
changes (the call is cheap; doing it every frame is fine):

```fortran
call app%set_title(merge('* ', '  ', edited)//trim(path)//' - My editor')
```

| Procedure | Notes |
|---|---|
| `app%set_title(text [, stat])` | The window's title after `init`. Shown in window mode; kept in remote and headless modes. |
| `app%title()` → `character(len=:), allocatable` | The title: `init`'s, or the last `set_title` (`''` headless until set). |
