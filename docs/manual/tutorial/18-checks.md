---
title: 18. Mistakes reported, keys that respect the focus
---

# 18. Mistakes reported, keys that respect the focus

Part three grows the studio of part two with what FIGURE v0.4.0 added. This chapter starts with two things a user
notices only when they go wrong: a mistake in the program's begin/end pairs, which used to abort the studio inside
Dear ImGui, and keys that fired wherever the user was typing.

<Media name="tut18_checks" video alt="The studio on the plate case. A click on the Result tab brings the field forward; right, pressed four times, moves the white probe line a node to the right each time (the caption reads right) and the profile's title follows, Along x = 0.878 m. A click in the title field of the Case panel and the text B typed: right now moves the field's cursor, and the probe line stays. Escape. The pointer rests on the Run button: its tooltip reads F5. F5, pressed with the pointer over the field, runs the solver: the log fills, the residuals fall, the notification says it converged in 114 iterations" caption="docs/examples/src/tut18_checks.F90, run as tut18_checks --examples /tmp/figure-studio --case /tmp/figure-studio/plate; the key pressed is captioned at the bottom" />

The whole program: [tut18_checks.F90](https://github.com/szaghi/figure/blob/main/docs/examples/src/tut18_checks.F90).
It is chapter 17's studio with the changes below; `tut18_checks --test DIR` tests it, and the documentation's build
runs that test (at the end of the page).

## A mistake reported, not a crash

FIGURE keeps a record of the scopes a frame opens, `ig_begin` to `ig_end`, `ig_tree_node` to `ig_tree_pop`, and
checks every end against it before Dear ImGui sees it ([Pairing and frames](/guide/errors#pairing-and-frames)). A
wrong end is refused, the frame goes on, and the **next** `next_frame` reports it: with `stat`, as a status the
program decides about; without `stat`, by stopping with the message. The studio passes `stat`:

<<< @/examples/snippets/tut18_checks-loop.F90{fortran}

<<< @/examples/snippets/tut18_checks-report.F90{fortran}

- `stat /= FIG_OK` after a frame with a usage error (`FIG_ERR_STATE`); `figure_last_error()` holds one line per
  error, each naming the Fortran call: `ig_end_tab: no ig_begin_tab is open (no scope is open)`.
- A bug in a panel repeats on every frame: the studio shows the report once, as a notification that stays until
  clicked (`seconds=0`). FIGURE keeps the last 100 notifications (`app%notifications`,
  [Notifications](/guide/frame-loop#notifications)), which chapter 15's Messages panel lists: the report is there too,
  with the run's own messages.
- This is mode `'report'`, the default. `app%set_checks('abort')` stops at the faulty call itself, the line to look
  at in a debugger; in `'recover'` a wrong end first closes the scopes opened after its own, then ends its own, and
  FIGURE notifies by itself ([The three modes](/guide/errors#the-three-modes)).

Before v0.4.0 the same mistake ended the program with an assertion inside `imgui.cpp` that named no Fortran call.

## The test fails on any mistake

A usage error does not stop the studio, so a test must look for it. The test's `frames(n)` draws `n` frames as the
main loop does (`ended` once `next_frame` says the studio ends), counts in `usage_errors` every frame that reports a
usage error, and prints the report; the test ends with `check(usage_errors == 0, ...)`:

<<< @/examples/snippets/tut18_checks-frames.F90{fortran}

And it checks that a mistake is reported, with one made on purpose, in the test only:

<<< @/examples/snippets/tut18_checks-mistake.F90{fortran}

## Keys that respect the focus

In part two every `ig_shortcut` fired wherever the user was. From v0.4.0 a chord is **routed**: the default scope,
`'focused'`, fires a call made inside a window only while that window (or a region of it) has the keyboard focus, and
never while a text field is being edited with a key the field uses
([Shortcuts](/guide/menus#shortcuts)). The application's keys of chapter 8, ctrl+o, ctrl+s, ctrl+q, f1, f5 and
shift+f5, are called outside every window: they keep firing wherever the focus is. The panels' keys move into the
panels.

**The Result panel's arrows.** Left and right move the probe line one node; `repeat=.true.` keeps moving it while the
key is held. Inside `draw_result`, they fire only while Result has the focus: in the title field, right moves the
field's cursor, and the probe line stays.

<<< @/examples/snippets/tut18_checks-arrows.F90{fortran}

**Undo in the Input panel.** ctrl+z takes back a form edit while Input has the focus. In the text of `heat.inp`, a
multi-line field, ctrl+z is the field's own undo: a text field keeps the chords it uses itself, whatever the scope.

<<< @/examples/snippets/tut18_checks-undo.F90{fortran}

**A button that owns F5.** `ig_set_next_item_shortcut` gives the next item a chord: F5 presses the Run button as a
click would, and the button's tooltip shows the chord. `scope='global'` keeps it working wherever the focus is; while
the button is disabled (a run going on, a problem in the input) it is not pressed. The application's own F5, outside
every window, stays for when the Run panel is closed or behind another tab: while the button is drawn, its
`'global'` route takes the chord before the `'focused'` call outside the windows, and one press starts one run.

<<< @/examples/snippets/tut18_checks-run_key.F90{fortran}

The calls are made **every frame**, whatever the program expects: Dear ImGui gives a chord, on the frame it arrives,
to the call that best matches where the user is, and a call made only now and then has no route.

**One more fix that the focus asked for.** Part two brought the Result panel forward when a field had been read
(`show_result`). The field is read by a task, and its end can come while the user types in a field: the panel took the
focus, and the edit was lost. Chapter 18 waits until no item is active (`laid_out` is true on the frame the layout
gave the focus to Input itself):

<<< @/examples/snippets/tut18_checks-focus.F90{fortran}

`ig_any_item_active()` is true while some item is held or edited ([What happened to an
item](/guide/widgets#what-happened-to-an-item)); chapter 19 uses the rest of that family.

## The test

<<< @/examples/output/tut18.txt{text}

`right` is pressed with `test_key('right')` after the field's task brought Result forward, then again with the title
field clicked: the probe line moves the first time only. The stray `ig_end_tab` is reported with the message above;
every other frame of the test is clean.

::: tip What you learned
`next_frame(stat)` reports the frame's usage errors by the names of the Fortran calls; a notification shows them
once; a test counts them. Keys are routed: `'focused'` inside a panel, application keys outside every window, a
button that owns its chord with `ig_set_next_item_shortcut`, `'global'` for a key that works everywhere.
Reference: [Pairing and frames](/guide/errors#pairing-and-frames), [Shortcuts](/guide/menus#shortcuts).
:::

**Next:** [19. Fields, lists and sizes](./19-layout): a field that commits when it is left, the keyboard focus sent to
the field a problem names, and sizes in em.
