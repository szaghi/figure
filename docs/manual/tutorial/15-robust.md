---
title: 15. Robustness
---

# 15. Robustness

A tool is trusted when it says what went wrong. This chapter goes through the studio's failures: an input it cannot
read, an input that reads but makes no sense, a solver that does not converge, a file of the user's that is gone. Each
gets a message in words, at the place the user looks, and a Messages panel keeps them all.

<Media name="tut15_robust" video alt="A folder whose heat.inp has a typo is dropped on the studio: a warning in the corner says Not a case: /tmp/figure-studio/broken/heat.inp: Cannot match namelist object name omgea, and the open case stays. In the Solver form the iterations are set to 20 and F5 runs the solver: an error says not converged in 20 iterations: raise max_iter or omega, and the status bar repeats it with a [!!] mark. Help > Messages opens a Messages tab beside Run with the three messages, newest first, each with its mark and colour: [!!], (!), [ok]. In the Body form the radius is dragged to 0.5 m: above the tree a red line says [!!] the body reaches the plate's edge, and the Run button is greyed out" caption="docs/examples/src/tut15_robust.F90, run as tut15_robust --examples /tmp/figure-studio --case /tmp/figure-studio/plate" />

The whole program: [tut15_robust.F90](https://github.com/szaghi/figure/blob/main/docs/examples/src/tut15_robust.F90).

## stat or stop

Every FIGURE procedure that can fail takes an optional `stat` ([Error handling](/guide/errors)). Without it, a
failure prints `FIGURE error: <message>` and stops the program; with it, the program gets the status and
`figure_last_error()` the message. Which to use depends on what failed:

- **A mistake in the program** (an unknown colormap name written in the source, arrays of different sizes, an
  `ig_end_popup` without its begin): stopping is right. It shows at the first run, with a message that names it.
- **Something of the user's or of the system's** (a file gone or unreadable, a program that cannot be started, a
  display without window icons, a folder that cannot be written): it happens to a correct program, so the program
  passes `stat` and tells the user.

The studio passes `stat` since chapter 7 where the second kind can happen: `set_icon`, the process's `start`, the
browser's answer, the task's `result`; and now the layout files:

<<< @/examples/snippets/tut15_robust-reset.F90{fortran}

`figure_last_error()` gives the message of the last failure: read it right after the call. The status code tells the
kind: `FIG_ERR_STATE` (not now), `FIG_ERR_ARGUMENT` (not this), `FIG_ERR_FAILED` (the system said no),
`FIG_ERR_EXCEPTION` ([Status codes](/guide/errors#status-codes)). The layout saved at the first frame passes `stat`
too: in a folder that cannot be written, Reset layout stays greyed out.

## Messages of the run time

A namelist that does not read is reported by Fortran itself: `read(u, nml=heat, iostat=ios, iomsg=msg)` gives the
status and the run time's own message, which names the problem (`Cannot match namelist object name omgea`). Chapter 9
already shows it in a warning and keeps the open case; the case with the typo is among the examples.

## Checking the input

An input can read and still make no sense: a body outside the plate, every side insulated (the temperature is then
not determined), an over-relaxation factor of 2. The solver would run, and fail or loop; the studio checks first.

<<< @/examples/snippets/tut15_robust-checks.F90{fortran}

<<< @/examples/snippets/tut15_robust-draw-checks.F90{fortran}

- `problems` gives one line per failed check (`pack` keeps the messages whose check failed); an empty list means
  the input can run.
- The Input panel shows them above the tree, each marked `[!!]` in the palette's error colour:
  `app%palette_color('error', rgba)` gives the role's colour in the palette in effect, right in a light palette and
  in a dark one ([Palette roles](/guide/styles#palette-roles)). The mark carries the meaning without the colour.
- `can_run` refuses a run while there are problems: the Run button is greyed out, and its tooltip says why.

## The solver's exit codes

<<< @/examples/snippets/tut15_robust-exit.F90{fortran}

The solver ends with a code of its own: 0 converged, 1 the input cannot be read, 2 not converged (it stops with
`stop 2, quiet=.true.`: the code, without a message or a backtrace). The studio turns each into a sentence that says
what to do next, in an error notification and, with a `[!!]` mark, in the status bar.

## A history of the messages

<<< @/examples/snippets/tut15_robust-messages.F90{fortran}

- A notification fades after a few seconds; the user may have looked elsewhere. `app%notifications(list, kinds,
  shown)` gives the last 100, oldest first, with their kinds, and the Messages panel lists them newest first, each
  with its mark and its role's colour ([Notifications](/guide/frame-loop#notifications)).
- The panel opens from Help > Messages, as a tab beside Run the first time: `ig_window_dock(id, docked)`, called in
  the Run panel, gives Run's dock node, and `ig_set_next_window_dock(id)` puts the Messages panel there when it first
  appears ([A window that appears later](/guide/docking#a-window-that-appears-later)). Afterwards the user moves it
  where they like.

## The limits the studio lives with

Some failures are not the program's to fix, and FIGURE lists them in its [known issues](/guide/known-issues). Those the
studio meets:

- **No window icon** on Wayland compositors without the icon protocol and on SDL's offscreen driver: `set_icon`
  returns `FIG_ERR_FAILED`, the bar keeps its icon ([The window's frame](/guide/known-issues#the-window-s-frame-drawn-by-figure)).
- **gfortran 16** gives a wrong section of a deferred-length character array to a procedure, and builds an array
  constructor of deferred-length strings too small (chapter 11): copy into fixed-length arrays first
  ([gfortran](/guide/known-issues#gfortran-a-section-of-a-deferred-length-character-array)).
- **Tasks and nvfortran:** formatted I/O on a worker needs `-mp` ([Tasks](/guide/known-issues#tasks)).
- **The 3-D view** has one light, lines one pixel wide, and no axes ([3-D views](/guide/known-issues#_3-d-views)).
- **Remote mode** has no system dialogs and no drops (chapter 17).

::: tip What you learned
When to pass `stat` and when to let a failure stop the program; `figure_last_error()` and the status codes; the
run time's `iomsg`; checks of the input before a run, marked in the palette's error colour; exit codes turned into
sentences; a history of the notifications, docked where the program chooses the first time. Reference:
[Error handling](/guide/errors), [Notifications](/guide/frame-loop#notifications), [Palette roles](/guide/styles#palette-roles),
[Docking](/guide/docking), [Known issues](/guide/known-issues).
:::

**Next:** [16. The studio tested](./16-tested): the studio driven headless by its users' gestures.
