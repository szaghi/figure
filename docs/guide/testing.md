---
title: Headless testing
---

# Headless testing

`app%init_headless(width, height [, stat])` creates the Dear ImGui and ImPlot contexts on a virtual display of
`width` x `height` pixels, without a window, without OpenGL and without a GPU. The frame loop is the same: widgets
and plots run their full logic (layout, hit testing, state), only nothing is drawn on screen. A headless program needs
no display server: it runs in CI as is, without Xvfb.

Differences from window mode:

- `next_frame` never returns `.false.`: the program decides how many frames to run;
- every frame advances Dear ImGui's clock by 1/60 s, whatever the wall time;
- no `imgui.ini` is read or written;
- `content_scale()` is 1;
- the input is what the program queues.

## Synthetic input

The module `figure_testing` queues input as a user would produce it; the program draws its next frames as usual, and
the input reaches the widgets there. A test queues, draws a few frames, then checks the program's variables:

<<< @/examples/snippets/tut05_headless-test.F90{fortran}

<<< @/examples/output/tut05.txt{text}

| Procedure | Queues |
|---|---|
| `test_click(x, y [, button] [, stat])` | a click at (x, y): move, a frame resting there, press, release (`button`: `'left'`, default, `'right'`, `'middle'`) |
| `test_drag(x0, y0, x1, y1 [, stat])` | a drag with the left button: a slider grab moved, a window dragged by its title bar |
| `test_mouse_move(x, y [, stat])`, `test_mouse_button(down [, button] [, stat])` | the parts of a click, one by one |
| `test_wheel(dy [, dx] [, stat])` | a turn of the wheel; positive `dy` away from the user (zoom in, in a plot) |
| `test_key(name [, down] [, stat])` | a key, pressed and released (or only pressed or released with `down`): `a`-`z`, `0`-`9`, `enter`, `tab`, `backspace`, `delete`, `escape`, `space`, `left`, `right`, `up`, `down`, `home`, `end`, `pageup`, `pagedown`, `f1`-`f12`, and the modifiers `ctrl`, `shift`, `alt`, `super` |
| `test_type(text [, stat])` | typed characters, into the focused field |
| `test_next_frame([stat])` | a frame boundary: what is queued after it arrives one frame later |

And to aim and to check:

| Procedure | Gives |
|---|---|
| `test_item_center(x, y)` | the centre of the last widget drawn (call it right after the widget) |
| `test_quit([stat])` | a quit request, as the window's close button makes it |
| `test_plot_tick(axis, index, label [, count] [, stat])` | the label of tick `index` on `'x'` or `'y'` of the plot being declared (between `ip_begin_plot` and `ip_end_plot`, after an item), and the number of ticks |
| `test_window_rect(name, xmin, ymin, xmax, ymax [, found] [, stat])` | a window's rectangle, by its name, as drawn in the last frame |

**Timing.** Everything queued reaches Dear ImGui at the next frame, up to a `test_next_frame` boundary; Dear ImGui then
applies one change of each kind per frame (its input trickling), so a click queued at once still takes the frames a
real one takes. Draw a few frames after queuing (four for a click, more for a drag, which `test_drag` spreads with its
own boundaries) before checking. Editing a numeric field, for example:

```fortran
call test_click(x, y)                  ! focus the field (its rectangle from ig_item_rect)
call test_key('shortcut', down=.true.) ! select what is there: ctrl+a (cmd+a on macOS)
call test_key('a')
call test_key('shortcut', down=.false.)
call test_type('2.5')                  ! replace it
call test_key('enter')                 ! confirm: the field's variable becomes 2.5
```

**Aim from the second frame on.** A new window that sizes itself to its content is measured during its first frame
and shown from the second: positions read in the first frame are not where the widgets end up (place windows with
`ig_set_next_window` to have them from the first frame).

Coordinates are display pixels, as `ig_item_rect` gives them. The module works in every mode; headless needs no
display, so tests run in CI as is. It is a separate module: `use figure_testing` where the tests are, `use figure` in
the application. Both are in the library (`lib/libfigure.a` and `lib/mod`, from `fobis build --mode figure-static-gnu`
or `fobis fetch`), so a project that depends on FIGURE tests its own interface the same way.

`test_click` and `test_drag` let the pointer rest one frame on the item before pressing, as a user's hand does:
Dear ImGui's tabs (and other items that may overlap) take a press only once they were hovered in the frame before. A
click therefore lands over the next four frames (move, rest, press, release), a drag over the next five.

To press a shortcut, hold `'shortcut'`: the platform's shortcut key, cmd on macOS and ctrl elsewhere, the one that
select-all (`a`) and `ig_shortcut('ctrl+s')` mean there. `'ctrl'` is the physical ctrl key, which macOS does not use for
shortcuts: Dear ImGui swaps the two as the events arrive.

## Test the interface you ship

Put the interface in a procedure that the application calls every frame, and call the same procedure from the test:
chapter 5 of the [tutorial](/manual/tutorial/05-headless) does this with a module, `draw_panel`, and a state type.

## The repository's tests

`src/tests/figure_test_headless.F90` drives every widget and plot type through `figure_testing` (clicks, a drag, typing
into a field), checks docking, styles, themes and fonts, headless; `src/tests/figure_test_themes.F90` measures the
contrast of every built-in style; `figure_test_layout` checks that the Fortran mirrors of Dear ImGui's structures
match the C++ ones, and `figure_test_remote` drives the remote mode end to end through a WebSocket client
([Remote UI](remote#how-it-works)):

```bash
fobis build --mode tests-gnu && exe/figure_test_headless
fobis build --mode tests-gnu-debug && exe/figure_test_headless   # with -fcheck=all and FPE traps
scripts/fpm.sh test
```

It passes with gfortran 16.2 (release and debug), nvfortran 26.9 and fpm.
