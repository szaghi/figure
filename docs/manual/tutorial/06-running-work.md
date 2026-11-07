---
title: 6. Running work
---

# 6. Running work

Chapter 4 advanced a computation a little in every frame. Work that cannot be cut into such slices, or that is
another program altogether, runs beside the frame loop: the window keeps answering while it runs. This chapter starts
a tool from a button and shows what it prints.

<<< @/examples/snippets/tut06_work.F90{fortran}

<Media name="tut06_work" alt="A window with a Check the grid button; after the click, the log view below fills with one line per block and ends with grid check: 24 blocks, no error" caption="docs/examples/src/tut06_work.F90" />

## A tool from a button

<<< @/examples/snippets/tut06_work-tool.F90{fortran}

- `tool%start(args)` starts the program `args(1)` with its arguments: an array, passed as it is, without a shell. The
  tool here is the program itself, started again with `--tool`, so that the chapter runs on every system; yours is
  `['overset', '-i', 'grid.inp']` or `['sbatch', 'case.sh']`.
- `ig_begin_disabled(tool%running())` greys the button out while the tool runs: one object runs one process at a
  time.
- FIGURE reads the tool's output on a thread of its own as the tool writes, and wakes the frame loop: the window does
  not freeze, and the tool never waits for the program.
- `tool%poll(lines)`, every frame, gives the complete lines printed since the last poll; `output%add(lines)` appends
  them to a `log_view_object`, and `output%draw('output')` draws the lines in view, following the end.
- A tool still running when the program ends is stopped with it. A run that must outlive the program is started with
  `detached=.true.` and a `log_file`.

::: tip What you learned
A program started from the program, its output followed in a log view, and why the window does not freeze.
Reference: [Processes and tasks](/guide/processes).
:::
