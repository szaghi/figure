---
title: 11. Running the solver
---

# 11. Running the solver

The studio now runs the solver of the case. The solver is a program of its own, `tut11_heat`, which does not use
FIGURE: it reads `heat.inp`, iterates, prints a residual per iteration and writes the field. The studio starts it as
a process, shows what it prints in a log view, plots the residuals as they arrive, shows the progress in a status
bar, tells the user when it ends, and can stop it.

<Media name="tut11_run" video alt="The studio with the plate case open and a Run panel at the bottom: Run and Stop buttons, a log on the left and, on the right, a plot of the residuals on a logarithmic axis. Run greys itself out and enables Stop; the solver's lines, iteration and residual, scroll into the log, the plot grows from 0.02 down to below 1e-6 as they arrive, and the status bar along the bottom of the window shows a progress bar filling and running: iteration 45, residual 2.25E-04. At the end the log reads heat: converged in 114 iterations, residual 9.34E-07, then field written to field.dat; the status bar and a notification in the corner say the solver converged in 114 iterations" caption="docs/examples/src/tut11_run.F90, run as tut11_run --examples /tmp/figure-studio --case /tmp/figure-studio/plate" />

The whole programs: [tut11_run.F90](https://github.com/szaghi/figure/blob/main/docs/examples/src/tut11_run.F90),
the studio, and [tut11_heat.F90](https://github.com/szaghi/figure/blob/main/docs/examples/src/tut11_heat.F90), the
solver: successive over-relaxation of Laplace's equation on the plate, the sides and the body held at their
temperatures or insulated. Its output, one line per iteration, is all the studio knows of it:

<<< @/examples/snippets/tut11_heat-print.F90{fortran}

`flush` sends each line at once: without it the run time keeps the output in a buffer, and the studio would get the
lines in bursts. `--pace 3` slows this small case down (3 ms a line), so that a run can be watched.

## Starting it

<<< @/examples/snippets/tut11_run-start.F90{fortran}

- `solver%start(args)` starts the program `args(1)` with the other elements as its arguments: an array, without a
  shell, so a case folder with blanks in its name needs no quoting ([Arguments: no shell](/guide/processes#arguments-no-shell)).
  The solver is looked for next to the studio's own executable (`get_command_argument(0)`).
- `stat` tells a start that failed (no such program), with `figure_last_error()`'s message.
- The arguments are copied into a fixed-length array first: gfortran 16 writes past the end of an array built by a
  constructor with a type-spec, `[character(len=512) :: path, dir]`, from deferred-length variables.
- The studio saves the case first: the solver reads the file, not the form.

## Following it

<<< @/examples/snippets/tut11_run-follow.F90{fortran}

- `follow_run` runs every frame, whichever panel is shown: FIGURE reads the solver's output on a thread of its own
  and wakes the frame loop, and `solver%poll(lines)` gives the complete lines printed since the last poll.
- `output%add(lines)` appends them to a `log_view_object`, a ring of lines (the last 10000 by default).
- The studio reads each `iteration` line with a list-directed `read` and appends the iteration and the residual to
  two arrays.
- Once `solver%running()` is `.false.`, the run is over: `solver%killed()` after Stop, else `solver%exit_code()`, 0
  when the solver converged. `app%notify(text, kind=)` tells the user in the corner of the window
  ([Notifications](/guide/frame-loop#notifications)), with the kind's colour and icon.

## The Run panel

<<< @/examples/snippets/tut11_run-run.F90{fortran}

- Run is greyed out while the solver runs (one process per `process_object`); Stop while it does not.
  `solver%kill()` asks the solver to end; the next frames see it ended, killed.
- `output%draw('output')` draws the lines in view, in a region of their own, and follows the end while it is
  scrolled to the bottom ([The log view](/guide/processes#the-log-view)). A click chooses a line, ctrl+c copies it.
- The residuals are plotted on a logarithmic axis (`yscale='log'`, [Axes](/guide/plots#axes)), and `auto_fit=.true.` fits the axes to the data
  in every frame, so the plot follows the curve as it grows ([Plots](/guide/plots)).

<<< @/examples/snippets/tut11_run-run-menu.F90{fortran}

The Run menu offers the same actions with F5 and shift+F5.

## A status bar

<<< @/examples/snippets/tut11_run-status.F90{fortran}

- The status bar is a bar along the bottom of the window (`ig_begin_side_bar(..., 'bottom', 30)`), declared before
  the tools' bar so that it spans the whole width; notifications are drawn above it.
- `ig_progress_bar(fraction)` shows how far the residual has come towards the tolerance, on a logarithmic scale;
  a negative `fraction` draws an indeterminate bar, a band sliding to and fro, until two residuals are known
  ([Progress bars](/guide/widgets#progress-bars)).

A solver still running when the studio quits is stopped with it: a process started this way belongs to the program
([The two modes](/guide/processes#the-two-modes); `detached=.true.` starts one that outlives it).

::: tip What you learned
A program of your own run as a process, its arguments as an array; its output read every frame into a log view and
parsed into a plot that follows it; its end told apart (converged, failed, stopped) and announced in a notification;
a status bar with a progress bar. Reference: [Processes and tasks](/guide/processes),
[The log view](/guide/processes#the-log-view), [Notifications](/guide/frame-loop#notifications),
[Progress bars](/guide/widgets#progress-bars), [Plots](/guide/plots).
:::

**Next:** [12. The result field](./12-field): the field as a heatmap, its colormap and legend, contour lines and
probes.
