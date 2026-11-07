---
title: Error handling
---

# Error handling

## stat or error stop

Procedures that can fail take an optional `integer(int32), intent(out) :: stat`:

- **with `stat`**, a failure is returned: `stat` receives `FIG_OK` or a `FIG_ERR_*` code, and
  `figure_last_error()` gives the message;
- **without `stat`**, a failure writes `FIGURE error: <message>` to standard error and stops the program with
  `error stop 1`.

Every procedure that can fail takes an optional `stat` (the [feature map](features) shows which); the others cannot
fail in a way FIGURE detects (`destroy` is safe in any state).

<<< @/examples/snippets/cb_stat-stat.F90{fortran}

<<< @/examples/output/cb_stat.txt{text}

Without `stat`:

<<< @/examples/snippets/cb_error_stop-stop.F90{fortran}

<<< @/examples/output/cb_error_stop.txt{text}

## Status codes

| Code | Value | Meaning |
|---|---|---|
| `FIG_OK` | 0 | success |
| `FIG_ERR_STATE` | 1 | call not allowed in the current state: `init` twice, `next_frame` before `init`, a process started again while it runs ([Processes](processes#statuses)), a drawing procedure called from a task ([Tasks](processes#tasks)), a file dialog or browser whose id is still open ([File dialogs](frame-loop#file-dialogs)), `ip_annotation` outside a plot |
| `FIG_ERR_ARGUMENT` | 2 | invalid argument: non-positive window size, `ip_line` arrays of different sizes, a palette below the [contrast rule](styles#the-contrast-rule), a text of 2 GiB or more for a [text buffer](widgets#multi-line-text), an unknown colormap name or a malformed colormap file ([Colormaps](colormaps#statuses-and-modes)), a colour without 4 components or `nlevels` < 1 for the [plot extras and contours](plots#error-bars-annotations-and-drag-tools) |
| `FIG_ERR_FAILED` | 3 | the platform (SDL, OpenGL) reported a failure: no display, no OpenGL 3 context, a program that cannot be started |
| `FIG_ERR_EXCEPTION` | 4 | a C++ exception was caught at the C boundary |

The codes are `integer(c_int)` parameters; compare them with `stat` directly (`stat /= FIG_OK`). C++ exceptions never
cross into Fortran: every glue function catches them and returns `FIG_ERR_EXCEPTION` with the exception's message.

## figure_last_error

`figure_last_error()` returns the message of the last failure detected by the native layer, as an allocatable
character. The message is not cleared by a successful call: read it right after the failing call.

`ip_line` checks `size(x) == size(y)` on the Fortran side, before calling the native layer; a mismatch returns
`FIG_ERR_ARGUMENT` with the message `ip_line: the series have different sizes` (each item names itself).

<<< @/examples/snippets/cb_stat-line.F90{fortran}

## What is not checked

Dear ImGui's own usage rules are not turned into status codes: an `ig_begin` without its `ig_end`, an
`ip_end_plot` after a plot that did not begin, or a widget called with no frame open break Dear ImGui's internal
state. Dear ImGui checks them with its own assertions, which stay active in the default Release build of the native
layer (cimgui's configuration undefines `NDEBUG`): a violation aborts the program with a message such as

```text
imgui.cpp:11325: void ImGui::ErrorRecoveryTryToRecoverState(...): Assertion `(0) && "Missing End()"' failed.
```

(an `ig_begin` whose `ig_end` was never called, detected by the next `next_frame`). The pairing rules are on the
[Widgets](widgets#windows) and [Plots](plots#a-plot) pages.
