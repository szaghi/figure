---
title: 6. Running work
---

# 6. Running work

Chapter 4 advanced a computation a little in every frame. Work that cannot be cut into such slices, or that is
another program altogether, runs beside the frame loop: the window keeps answering while it runs. This chapter starts
a tool from a button and shows what it prints, then runs a computation of the program as a task.

<<< @/examples/snippets/tut06_work.F90{fortran}

<Media name="tut06_work" alt="A window with two buttons: Smooth the field, then Check the grid; a progress bar beside the first fills while the task runs and gives way to the smoothed value, and a notification in the corner says the field is smoothed; the tool's lines fill the log view and end with grid check: 24 blocks, no error" caption="docs/examples/src/tut06_work.F90" />

## A tool from a button

<<< @/examples/snippets/tut06_work-tool.F90{fortran}

- `tool%start(args)` starts the program `args(1)` with its arguments: an array, passed as it is, without a shell. The
  tool here is the program itself, started again with `--tool`, so that the chapter runs on every system: `me` is the
  program's own path, from `get_command_argument(0, me)`, and the program runs its tool part when its first argument
  is `--tool` (the whole program: [tut06_work.F90](https://github.com/szaghi/figure/blob/main/docs/examples/src/tut06_work.F90)). Yours is `['overset', '-i', 'grid.inp']` or
  `['sbatch', 'case.sh']`.
- `ig_begin_disabled(tool%running())` greys the button out while the tool runs: one object runs one process at a
  time.
- FIGURE reads the tool's output on a thread of its own as the tool writes, and wakes the frame loop: the window does
  not freeze, and the tool never waits for the program.
- `tool%poll(lines)`, every frame, gives the complete lines printed since the last poll; `output%add(lines)` appends
  them to a `log_view_object`, and `output%draw('output')` draws the lines in view, following the end.
- A tool still running when the program ends is stopped with it. A run that must outlive the program is started with
  `detached=.true.` and a `log_file`.

## A computation as a task

The program's own long computations run as tasks: a Fortran procedure on a thread of its own. The work is a
module procedure with a fixed interface; its data is any type, here a field to smooth:

<<< @/examples/snippets/tut06_work-work.F90{fortran}

<<< @/examples/snippets/tut06_work-task.F90{fortran}

- `smoother%start(smooth_field, field)` runs `smooth_field` on a worker thread, on a copy of `field`: the program's
  own `field` is not touched while the task runs.
- Inside the task, `h%report(fraction, message)` posts the progress and wakes the frame loop; `h%cancelled()` is the
  safe point where the task returns if the program asked it to stop (`smoother%cancel()`).
- Every frame the program reads the progress (`smoother%progress`) and draws it with `ig_progress_bar(fraction,
  label=msg)`: before the task's first report `fraction` is negative, and the bar is indeterminate (a sliding band).
- Once `smoother%done()`, it takes the field back with `smoother%result(data)`, without a copy, and `select type`
  gives it its type again; `app%notify('The field is smoothed', kind='success')` tells the user, in the corner of the
  window, even if they were looking at the log.
- **A task never draws:** no `ig_*` or `ip_*` call inside `smooth_field`. Only the main thread draws; FIGURE refuses a
  drawing call from a task ([the threading rule](/guide/processes#tasks)).
- **nvfortran:** compile a program with tasks with `-mp`, which makes nvfortran's Fortran I/O thread-safe
  ([Known issues](/guide/known-issues#tasks)); gfortran and ifx need nothing.

::: tip What you learned
A program started from the program, its output followed in a log view; a computation run as a task, its progress
in a progress bar and its end in a notification; and why the window does not freeze. Reference:
[Processes and tasks](/guide/processes), [Progress bars](/guide/widgets#progress-bars),
[Notifications](/guide/frame-loop#notifications).
:::

**Next:** part two, [7. The studio's own window](./07-window): one application, a solver studio, grown chapter by chapter.
