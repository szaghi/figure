---
title: Widgets
---

# Widgets

`figure_imgui` binds a first set of [Dear ImGui](https://github.com/ocornut/imgui) widgets (Dear ImGui v1.93.0). Call
them between `next_frame` and the next `next_frame`, inside a window.

## Values are your variables

Widgets that edit a value take it as an `intent(inout)` argument and write the new value back before returning. The
binding copies the value into a local C variable for the call: the actual argument needs no `target` attribute,
nothing keeps a pointer to it after the call, and any variable works (a local, a component of a derived type, an
array element).

Every such widget returns a `logical`: `.true.` in the frame in which the user changed the value. When you only need
the value, discard the result with `continue`:

<<< @/examples/snippets/tut02_widgets-widgets.F90{fortran}

## Windows

| Procedure | Notes |
|---|---|
| `ig_begin(name [, open]) → logical` | `name` is the title and the identifier. Returns `.false.` when the window is collapsed or clipped: skip its content. |
| `ig_end()` | Call it after every `ig_begin`, whatever `ig_begin` returned. |
| `ig_set_next_window(x, y [, width, height] [, always])` | Position, and size if both `width` and `height` are given, of the next `ig_begin`, in pixels. Applied on first use only (the user can move the window afterwards, and `imgui.ini` remembers it), or every frame with `always=.true.`. |

Widgets called outside any `ig_begin`/`ig_end` pair go to Dear ImGui's implicit "Debug" window.

With `open`, the window gets a close button in its title bar that sets `open` to `.false.`. Dear ImGui shows a window
as long as `ig_begin` is called for it, so guard the call with the same variable:

<<< @/examples/snippets/tut02_widgets-closable.F90{fortran}

## Controls

| Procedure | Value | Returns `.true.` |
|---|---|---|
| `ig_button(label [, width] [, height])` | none | on the frame it is clicked |
| `ig_checkbox(label, value)` | `logical` | when toggled |
| `ig_slider(label, value, vmin, vmax)` | `integer(int32)`, `real(real32)` or `real(real64)`; `vmin`, `vmax` of the same kind | when changed |
| `ig_input(label, value [, step] [, format])` | `real(real64)` | when changed |

- `ig_button` sizes are in pixels; the default fits the label.
- `ig_slider` is generic: the kind of `value` selects the specific procedure. The user can also ctrl-click it to type
  a value.
- `ig_input` shows `-` and `+` buttons when `step` is given (ctrl-click steps by `10 * step`); `format` is a C
  `printf` format, default `'%.6g'`.

## Text and layout

| Procedure | Notes |
|---|---|
| `ig_text(text)` | Plain text, no formatting: compose numbers with an internal `write`. Trailing blanks are shown: pass `trim(line)`. |
| `ig_same_line()` | The next item goes on the same line as the previous one. |
| `ig_separator()` | A horizontal line. |
| `ig_item_rect(xmin, ymin, xmax, ymax)` | Screen rectangle of the last item, in pixels: for tests and custom layout. |
| `ig_show_demo_window([open])` | The Dear ImGui demo, a live catalogue of every Dear ImGui widget (most are not bound yet). |

## Labels and identifiers

Dear ImGui identifies a widget by a hash of its label within its window. Two widgets with the same label in the same
window are the same widget to Dear ImGui: clicking one activates both, or neither. Make labels unique; when the
visible text must repeat, add `##` and a suffix: the text after `##` is part of the identifier but is not shown.

<<< @/examples/snippets/tut02_widgets-ids.F90{fortran}

A label that starts with `##` is invisible altogether (used by [plots](plots) to hide the title).

Strings are passed verbatim, trailing blanks included: `'Run'` and `'Run   '` are different identifiers.

## Not bound yet

Text input needs a C buffer and a resize callback and is not bound yet; nor are combo boxes, tables, menus, trees,
tooltips, colours and styles. Their raw interfaces are generated ([Raw bindings](raw-bindings)); the Fortran wrappers
are still to be written ([roadmap](roadmap)).
