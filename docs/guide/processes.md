---
title: Processes and tasks
---

# Processes and tasks

A program built with FIGURE draws a frame, waits for input, and draws the next one. Work that lasts longer than a
frame must run beside the frame loop, or the window stops answering: in a window it greys out, in remote mode the
browser stops receiving frames and looks dead. FIGURE runs two kinds of work beside the loop:

- **processes**: other programs (a grid tool, `sbatch` and `squeue`, a local solver run), started from the program,
  with their output shown in a log view;
- **tasks**: Fortran procedures of the program run on a thread of their own (to come with v0.3.0).

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
  browser's. While a reader is alive the remote loop waits on the network in slices of 10 ms, so that new output is
  sent at once.

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
