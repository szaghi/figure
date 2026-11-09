---
title: Processes and tasks
---

# Processes and tasks

A program built with FIGURE draws a frame, waits for input, and draws the next one. Work that lasts longer than a
frame must run beside the frame loop, or the window stops answering: in a window it greys out, in remote mode the
browser stops receiving frames and looks dead. FIGURE runs two kinds of work beside the loop:

- **processes**: other programs (a grid tool, `sbatch` and `squeue`, a local solver run), started from the program,
  with their output shown in a log view;
- **tasks**: Fortran procedures of the program run on a thread of their own (reading a large file, a long
  computation), with their progress and a cancel.

## Processes

| Procedure | Notes |
|---|---|
| `p%start(args [, cwd] [, env] [, merge_stderr] [, detached] [, log_file] [, stat])` | Start the program `args(1)` with the arguments `args(2:)`. |
| `p%poll(lines [, stat])` | The complete lines printed since the last poll, oldest first; no element when there is nothing new. |
| `p%running()` → `logical` | `.true.` while the process runs (captured: until FIGURE has read all its output). |
| `p%exit_code([stat])` → `int32` | The exit code of a captured process that has ended. |
| `p%killed()` → `logical` | `.true.` when the process ended after `p%kill`. |
| `p%pid()` → `int64` | The process id the system gave it (0 before `start`). |
| `p%kill([force] [, stat])` | Ask the process to end; with `force`, at once. |

`p` is a `process_object`. One object runs one process at a time: `start` again once the previous one has ended.
Every frame the program polls the lines and adds them to a [log view](#the-log-view):

<<< @/examples/snippets/cb_process-run.F90{fortran}

<Media name="cb_process" alt="A window with Run and Stop buttons, a status line and a log view; Run is clicked, the tool prints a solver's log of 120 iterations, the view follows the end, and the status line reads ended, exit code 0" caption="docs/examples/src/cb_process.F90" />

### The two modes

| | Captured (default) | Detached (`detached=.true.`) |
|---|---|---|
| Output | piped to the program: `p%poll` | written to `log_file`: `p%poll` follows the file |
| Standard error | with the output (`merge_stderr`, default); else the program's own | with the output (`merge_stderr`); else discarded |
| When the program ends | the child is killed | the child goes on |
| Exit code | `p%exit_code()` | not known (the child's own log tells) |
| For | short tools: a grid check, `squeue`, a converter | long runs: a solver run that must outlive the GUI |

A **captured** child is killed when its object ends (a local variable going out of scope, a `start` after its end
releases it), at `app%destroy`, and when the program exits normally (`stop`, `error stop`, the end of the main
program): first politely, then by force after 0.1 s. A program killed by a signal cannot kill its children: they go on
until they end or write to the closed pipe.

A **detached** child is started in a session of its own (POSIX: `setsid`, after a double fork, so the system's
init process reaps it: no zombie is left); its output goes to `log_file`, created or truncated at `start`. The
program follows it with `p%poll` while it runs, and can start a new GUI later that reads the same file.

### Arguments: no shell

The arguments are an array, passed to the program as they are: no shell parses them, so spaces, quotes, `$` and `*`
in a file name need no escaping, and a name typed by the user cannot run a command. Each element is trimmed of its
trailing blanks. When a pipeline or a redirection is wanted, the shell is written explicitly:
`['sh', '-c', 'squeue -u $USER | tail -n +2']` (on Windows `['cmd', '/c', '...']`). The program is searched in
`PATH` when its name has no `/`.

`cwd` sets the working directory of the child (default: the program's). `env` entries are `NAME=value` and are added
to the program's environment, replacing a variable of the same name.

### The drain

A pipe holds 64 KB. A child that fills it stops until someone reads, and a program whose frame loop sleeps
(lazy redraw) or is busy would never read: the child would hang. FIGURE reads every captured pipe on a native thread
of its own, into a buffer, as the child writes, and wakes the frame loop so that the new lines are drawn at once. The
program polls when it likes: a child printing a megabyte while the program does nothing still ends.

Lines are cut at the newline, and a carriage return is dropped (`CRLF` endings, Windows' tools). A last line without a
newline waits until it is completed; once the process has ended, it is given as it is. `lines` is a
`character(len=:), allocatable` array as long as the longest line: `trim` the shorter ones.

### Statuses

| Failure | Status |
|---|---|
| `start` while this object's process still runs | `FIG_ERR_STATE` |
| `start` with an empty `args`, an `env` entry without `=`, `detached` without `log_file` (or `log_file` without `detached`) | `FIG_ERR_ARGUMENT` |
| the program cannot be started (not found, not executable), or `log_file` cannot be written | `FIG_ERR_FAILED` |
| `poll`, `kill` or `exit_code` before `start`; `exit_code` while it runs or of a detached process | `FIG_ERR_STATE` |
| `kill` refused by the system | `FIG_ERR_FAILED` |

`stat` is optional: absent, a failure stops the program (`error stop`) with the message, which `figure_last_error()`
gives otherwise ([Error handling](errors)). `kill` on a process that has ended does nothing.

### Modes

- **Window:** as above; the reader wakes the frame loop with an event.
- **Headless:** the same (the loop does not wait, nothing to wake).
- **Remote:** the same: the processes run on the machine the program runs on (the server, a cluster node), not on the
  browser's. The reader ends the remote loop's wait on the network at once (a datagram to a socket the loop waits
  on), so that new output is sent at once.

### Limits

- `kill` stops the program started, not the programs it started itself: `sh -c 'a; b'` killed leaves `a` running. Write
  `exec` in the script for its last command, or kill the job by its own means (`scancel`).
- On Windows a polite kill is a close request, which a console program may ignore: use `force=.true.`.
- The output of a captured process is kept until polled, without a limit: poll it every frame.
- See also [Known issues](known-issues#processes).

## The log view

| Procedure | Notes |
|---|---|
| `log%add(line)`, `log%add(lines)` | Add one line or an array of lines (as `p%poll` gives them); trailing blanks are removed. |
| `log%clear()` | Remove every line. |
| `log%set_cap(cap [, stat])` | Keep at most `cap` lines (default 10000): the oldest go first. |
| `log%draw(id [, height])` | Draw the lines in a region of their own; `height` in pixels (absent or 0: the rest of the window, negative: leave that much below). |
| `log%count()` → `int32`, `log%line(i)` → `character` | The lines kept, and line `i` (1 is the oldest kept). |
| `log%following()` → `logical` | `.true.` while the view follows the end. |
| `log%in_view(first, last)` | The kept lines drawn by the last `draw`. |
| `log%copy([all])` → `character` | The chosen lines (with `all`, every line), joined by newlines. |

`log` is a `log_view_object`: a ring buffer of lines with a cap, drawn with a
[list clipper](widgets#lists-and-regions), so a view of 10000 lines costs what the 20 in view cost.

- **Following the end:** while the view is scrolled to the bottom, new lines scroll it; scrolled up (wheel,
  scrollbar), it stays where it is, and following starts again when it is scrolled back to the bottom.
- **Choosing and copying:** a click chooses a line, shift+click extends the choice to another; ctrl+c (cmd+c on macOS)
  copies the chosen lines, and the right-click menu has *Copy* and *Copy all*. The clipboard is the system's in a
  window; in headless and remote modes it is Dear ImGui's own, inside the program (the browser's clipboard is not
  reached).
- `set_cap` with fewer lines than kept drops the oldest; `cap` below 1 is refused with `FIG_ERR_ARGUMENT`.
- The same in window, headless and remote modes.

## Tasks

| Procedure | Notes |
|---|---|
| `t%start(work, data [, stat])` | Run `work(h, data)` on a worker thread; `data` (any type) is copied into the task. |
| `t%running()` → `logical`, `t%done()` → `logical` | It runs; it has ended and its result waits for `t%result`. |
| `t%progress(fraction [, message])` | The last progress the task reported: `fraction` in [0, 1] (-1 before its first report). |
| `t%cancel([stat])` | Ask the task to stop at its next safe point. |
| `t%result(data [, stat])` | Once done, the task's data, moved out (no copy); the object is free for another `start`. |
| `h%report(fraction [, message])` | In the task: post its progress, `fraction` in [0, 1]; the frame loop is woken to show it. |
| `h%cancelled()` → `logical` | In the task: `.true.` once the program asked it to stop. |
| `h%fail(message)` | In the task: report a failure (the task then returns). |

`t` is a `task_object`, `h` the `task_handle_object` FIGURE gives to `work`, a subroutine with the interface
`task_work`: `subroutine work(h, data)`, with `type(task_handle_object), intent(inout) :: h` and
`class(*), intent(inout) :: data`. `work` is a **module procedure** (it runs on another thread: an internal procedure reaches its host's variables
through the host's stack frame, which is the main thread's), and it is **`recursive`**, as is every procedure of yours
that it calls: two tasks run the same code at the same time, which a procedure not declared `recursive` does not allow
(gfortran's `-fcheck=recursion`, part of `-fcheck=all`, stops the program with "Recursive call to nonrecursive
procedure"). `data` is the task's own copy of what `start` was given:
a file name, or an extended type holding both the input and the arrays the task fills. `work` selects its type,
works on it, reports its progress, and checks `h%cancelled()` at its safe points; `t%result(data)` hands it back
without a copy:

<<< @/examples/snippets/cb_task-work.F90{fortran}

The program starts the task from a button and, every frame, shows its progress until it is done, then takes its
result once:

<<< @/examples/snippets/cb_task-ui.F90{fortran}

<Media name="cb_task" alt="Read is clicked: the task reads a field of two million values block by block while its progress shows; then the window shows the number of values read, their minimum, maximum and mean" caption="docs/examples/src/cb_task.F90" />

::: warning The threading rule
A task computes and reads its own files; it **never calls FIGURE's drawing procedures**: Dear ImGui is
single-threaded, and only the main thread draws. FIGURE refuses such a call from a worker: the call returns at once
(`.false.` for a begin), the task's status becomes `FIG_ERR_STATE`, given by `t%result` with a message naming the
procedure, and the task is asked to stop (`h%cancelled()` becomes `.true.`).
:::

Every drawing procedure of FIGURE checks: `app%next_frame`, the containers (`ig_begin`, `ig_begin_child`, menus,
popups, tab bars, tables, trees, `ip_begin_plot`, ...), the widgets (`ig_text`, `ig_button`, `ig_slider`,
`ig_input_text`, ...), the plot items (`ip_line`, `ip_heatmap`, `ip_contour`, ...), the layout calls
(`ig_same_line`, `ig_set_next_window`, `ig_push_id`, ...), the style calls (`ig_push_style_color`,
`ig_set_style_var`, `ig_push_font`, ...), the list clipper, the textures, `log%draw`, every procedure of a
`view3d_object`, and the calls that read or change the GUI's state (`app%dropped`, `app%notify`, the file browsers,
the clipboard, the colormaps). A widget called from a task outside any container is refused like a container: it
returns at once (`.false.`, its values unchanged), with `FIG_ERR_STATE` in `stat` where it has one. The check
costs the main thread one call, about 1.5 ns. The application's procedures that change or read the GUI's state
refuse too: `app%init*` and `app%destroy`, the style (`set_style`, `set_font`, `load_style`, `save_style`,
`palette_color`), `set_docking`, `set_icon`, `set_title` and `title`, the layouts, `save_image` and
`image_result`, `file_dialog_result` and `notifications`. A task may call the ones that only set or read a flag:
[below](#calling-the-application-from-a-task). Not checked: the raw bindings (`figure_cimgui`, `figure_cimplot`), Dear
ImGui's and ImPlot's own functions, which a task must not call ([known issues](known-issues#tasks)).

### Calling the application from a task

These calls of the application are thread-safe: a task, an OpenMP thread or an MPI progress thread may make them
while the main thread runs the frame loop. Each sets or reads one flag of the native layer, which is atomic; none is
refused.

| Call | From another thread than the loop's |
|---|---|
| `app%wake()` | the next frame starts without waiting for input or `max_wait` |
| `app%request_frames(n)` | at least `n` more frames, the first at once; concurrent requests keep the largest |
| `app%quit()` | the next `next_frame` returns `.false.`, at once |
| `app%quit_requested()` → `logical` | the user asked to quit; one caller gets each request |
| `app%set_lazy(enabled [, max_wait])` | lazy redraw on or off, from the next frame |
| `app%set_confirm_quit(enabled)` | the window's close button reported instead of ending the loop |
| `app%content_scale()` → `real64` | the display's content scale |

`wake`, `request_frames` and `quit` called from another thread than the loop's wake a [lazy loop](frame-loop#waking-the-loop)
that is waiting: in window mode with an event, in remote mode with a datagram to a socket the loop waits on; headless
mode never waits. Called from the loop's own thread they do not wake anything, there is nothing to wake: the next
`next_frame` does not wait. A task's progress report (`h%report`) and its end wake the loop too: `wake` is for news
that does not go through the report, such as a file the task has written
([cookbook](/manual/cookbook#redraw-when-a-worker-has-news)).

Before v0.3.1 these flags were plain fields: `quit` and `request_frames` from a task raced with the main thread
(undefined behaviour in C++: `scripts/tsan_check.sh` gave 16 ThreadSanitizer reports, at 8 lines of the native layer;
none since), and a request
from a task waited for the loop's next input or `max_wait` (0.5 s by default) before its frame.

### Cancelling

Cancellation is cooperative: `t%cancel()` sets a flag, and the task returns at its next safe point, where `data` is
consistent (between two blocks of a file, two passes of a smoother). Nothing is stopped in the middle of a write. A
cancelled task is done like a finished one: `t%result` gives its data as it was left, with `FIG_OK`. A `task_object`
that ends while its task runs (a local variable, the end of the program's scope) asks it to stop and waits for it, up
to its next safe point: a task with no safe point is waited for until its end.

### What code is safe on a worker

- **Its own data and its own files.** The task works on its copy of `data`; the program does not reach it until
  `t%result`. Variables shared with the main thread (module variables, pointers into the program's arrays) are the
  program's to protect: a data race there is the program's, not FIGURE's.
- **Fortran I/O on units of its own.** Open and close units inside the task (`newunit=`), never read or write a unit
  the main thread also uses. gfortran's I/O is thread-safe per unit; **nvfortran's only when compiled with `-mp`**
  (OpenMP): without it, concurrent formatted I/O, internal `write` to a string included, fails at random
  ([Known issues](known-issues#tasks)).
- **A large stack.** Each worker has 64 MiB of stack (a secondary thread's default is 512 KiB on macOS): automatic
  arrays and temporaries of a few MiB fit.
- **No drawing:** see the rule above.

### Statuses

| Failure | Status |
|---|---|
| `start` while this object's task runs, or from a task | `FIG_ERR_STATE` |
| no thread can be created | `FIG_ERR_FAILED` |
| `cancel` or `result` before `start`; `result` while the task runs | `FIG_ERR_STATE` |
| `result` of a task that called a drawing procedure | `FIG_ERR_STATE` (the message names it) |
| `result` of a task that reported a failure with `h%fail` | `FIG_ERR_FAILED` (the message is the task's) |

`stat` is optional: absent, a failure stops the program (`error stop`) with the message ([Error handling](errors)).

### Modes

- **Window:** the task's reports and its end wake the frame loop with an event: the progress is drawn at once, even
  with lazy redraw.
- **Headless:** the same (the loop does not wait).
- **Remote:** the same: the task runs on the server; its reports and its end end the remote loop's wait on the
  network at once (a datagram to a socket the loop waits on), so that its progress is sent at once. A long read no
  longer stops the streaming, so the browser stays alive.

Several tasks may run at once, each with its own object. Tasks do not start tasks.

## Feedback

The program shows what runs with a [progress bar](widgets#progress-bars) (`ig_progress_bar(fraction)`, indeterminate
for work with no known length, such as a tool that prints no progress), often in a status bar along the bottom
([cookbook](/manual/cookbook#a-status-bar)), and tells the user that something ended with a
[notification](frame-loop#notifications) (`app%notify`): the program notifies when it sees a process no longer running
or a task done, since a task does not draw.
