---
title: 14. Heavy work off the frame
---

# 14. Heavy work off the frame

Until now the studio read `field.dat` inside a frame: for 48 x 32 nodes nobody notices. The example case `fine` has
900 x 600 nodes and a 7 MB result; a production solver's are gigabytes, often on a network file system. Read inside a
frame, they freeze the window: no redraw, no answer to the mouse, the close button ignored. The studio now reads the
result as a **task**, a Fortran procedure run on a worker thread, and draws its progress meanwhile.

<Media name="tut14_task" video alt="The studio with the plate case open. The folder of the fine case is dropped on the window: the Result panel comes forward with a progress bar, reading field.dat, and a Stop button, and the status bar says reading field.dat; the window keeps drawing. The bar fills, and the field of 900 by 600 nodes appears as a heatmap with its contour lines, legend and profile; the 3-D tab shows the same field as a surface" caption="docs/examples/src/tut14_task.F90, run as tut14_task --examples /tmp/figure-studio --case /tmp/figure-studio/plate" />

The whole program: [tut14_task.F90](https://github.com/szaghi/figure/blob/main/docs/examples/src/tut14_task.F90).
`--examples` now also writes the `fine` case and runs the solver on it once (a few seconds), so that its large result
exists. On this machine its 540 000 values read in a tenth of a second: the recording shows the progress for a few
frames only.

## The work

<<< @/examples/snippets/tut14_task-work.F90{fortran}

- The task's procedure is a **module procedure** with the interface `task_work`, `subroutine work(h, data)`. It
  runs on another thread, so it cannot be an internal procedure of the program: those reach the program's variables
  through the main thread's stack ([Tasks](/guide/processes#tasks)).
- It is **`recursive`**, as is every procedure it calls: two tasks may run the same code at once.
- `data` is the task's own copy of what the program gave it, here a `field_t` holding the file's name; the task
  fills the same object with the values and gives it back.
- `h%report(fraction, message)` posts the progress and wakes the frame loop; `h%cancelled()` is the safe point,
  between two rows, where the task returns if the program asked it to stop; `h%fail(message)` reports a failure.
- The task opens its own unit (`newunit=`): Fortran I/O is safe on a worker as long as no other thread uses the same
  unit ([What code is safe on a worker](/guide/processes#what-code-is-safe-on-a-worker)).
- It also makes the **coarse copy** that is drawn: every `stride`-th node, at most 200 a side. A heatmap of 540 000
  cells, or a surface of a million triangles, would be redrawn in every frame the user moves the mouse; 180 x 120 are
  not. The profile and the probes keep reading the full field.

## Starting it, following it

<<< @/examples/snippets/tut14_task-start.F90{fortran}

`loader%start(read_field, request)` runs `read_field` on a worker, on a copy of `request`, and returns at once. One
`task_object` runs one task at a time: a second open while it reads is refused with a word to the user.

<<< @/examples/snippets/tut14_task-progress.F90{fortran}

Every frame, while the task runs, the Result panel draws its progress (`loader%progress(fraction, message)`) and a
Stop button: `loader%cancel()` asks it to stop at its next safe point. Before its first report the fraction is
negative and the bar slides to and fro.

<<< @/examples/snippets/tut14_task-take.F90{fortran}

- Once `loader%done()`, `loader%result(data)` moves the task's data out, without a copy, and frees the object for
  the next task. `select type` gives it its type again, and `move_alloc` hands the arrays to the program, again
  without a copy.
- A task that called `h%fail` gives `FIG_ERR_FAILED` with its message in `figure_last_error()`.
- A cancelled task is done like a finished one; the studio knows it asked, and drops what was read.

## The rule: only the main thread draws

The task reads and computes; it never calls a drawing procedure (`ig_*`, `ip_*`, `view%draw`). Dear ImGui is not
thread-safe, and FIGURE refuses a drawing call from a task: the call returns at once, the task is asked to stop, and
`loader%result` gives `FIG_ERR_STATE` naming the procedure ([The threading rule](/guide/processes#tasks)). Everything
the user sees is drawn by the main thread, from what the task gave back.

::: tip What you learned
A task: a recursive module procedure working on its own copy of the data, with progress, a safe point to stop and a
failure message; started from the frame loop, followed every frame, its result moved out without a copy; why a task
never draws; and a coarse copy for drawing a fine field. Reference: [Processes and tasks](/guide/processes#tasks),
[Progress bars](/guide/widgets#progress-bars), [Known issues: tasks](/guide/known-issues#tasks).
:::

**Next:** [15. Robustness](./15-robust): checking the input, reporting every failure.
