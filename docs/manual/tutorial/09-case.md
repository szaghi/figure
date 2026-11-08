---
title: 9. The case
---

# 9. The case

The studio works on a **case**: a folder with an input file, `heat.inp`, read by the studio and, from chapter 11, by
the solver. This chapter opens a case, from FIGURE's file browser, from the system's dialog, or from a folder dropped
on the window; it shows the case's title in the window's title, and asks before an open or a quit loses an edit.

The input file is a Fortran namelist, which both programs read with one statement:

```text
&heat
  title = 'Heated plate'
  nx = 48, ny = 32, lx = 1.500, ly = 1.000
  bc_kind = 'fixed', 'insulated', 'fixed', 'fixed'  ! west, east, south, north
  bc_value = 100.000, 0.000, 20.000, 20.000
  body_x = 0.900, body_y = 0.500, body_r = 0.150, body_t = 0.000
  omega = 1.800, tolerance = 1.0E-06, max_iter = 4000
/
```

A plate of `lx` by `ly` metres, held at fixed temperatures or insulated on its four sides, with a round body at
`body_t` inside it; the solver computes the steady temperature on an `nx` by `ny` grid. `tut09_case --examples DIR`
writes two such cases, `plate` and `channel`, into `DIR` and starts the browser there.

<Media name="tut09_case" video alt="File, Open case shows FIGURE's file browser over the studio, titled Choose a folder, on /tmp/figure-studio: the places Home, Working folder and the root on the left, the folders channel and plate on the right with their modification times. A double-click enters plate and Choose opens it: the Case panel shows the folder, the title Heated plate in a field, the grid and the solver's parameters, the window's title becomes Heated plate - FIGURE studio, and a notification says Opened Heated plate. The title is edited to Heated plate (draft): the window's title gets a star. The folder channel is dropped on the window: the window dims and asks Discard changes?, the case having unsaved changes, with Save, Discard and Cancel; Discard opens the channel case" caption="docs/examples/src/tut09_case.F90, run as tut09_case --examples /tmp/figure-studio" />

The whole program: [tut09_case.F90](https://github.com/szaghi/figure/blob/main/docs/examples/src/tut09_case.F90).

## Choosing a folder

<<< @/examples/snippets/tut09_case-file-menu.F90{fortran}

<<< @/examples/snippets/tut09_case-browse.F90{fortran}

Two kinds of dialog choose a file or a folder, and both answer through the same call
([File dialogs](/guide/frame-loop#file-dialogs)):

- **FIGURE's file browser** (`app%open_file_browser`), drawn by FIGURE as a modal over the program: the same in a
  window, in [remote mode](/guide/remote) (chapter 17) and in a headless test (chapter 16). `folders=.true.` chooses
  a folder: files are shown dimmed, and Choose takes the selected folder or the one shown. The places on the left
  include the recent folders, which FIGURE keeps between runs.
- **The system's dialog** (`app%open_folder_dialog`), the desktop's own. It needs a desktop: in remote and headless
  modes it is refused at once with `FIG_ERR_STATE`, and the studio opens the browser instead.

Neither blocks the program: the window keeps drawing, and the answer comes on a later frame.

## Answers and drops

<<< @/examples/snippets/tut09_case-answers.F90{fortran}

- `app%file_dialog_result('case', path, done, cancelled, stat)`, every frame, is `done` once, on the frame the user
  answered, whichever kind of dialog was opened with the id `'case'`. A system dialog that could not be shown
  answers with a failure; the studio shows `figure_last_error()` in a notification.
- `app%dropped(paths)` is `.true.` on the frame after files or folders were dropped on the window, with their
  absolute paths ([Drops](/guide/frame-loop#drops)). The studio takes the first: a case folder, or a `heat.inp`,
  whose folder is the case.
- Both go through `request`, which opens the case only if nothing is lost.

## The case and its title

<<< @/examples/snippets/tut09_case-read.F90{fortran}

`read_case` fills the namelist's variables with the defaults, reads the group `&heat`, and returns the run time's
message (`iomsg`) when the file is missing or wrong: a folder that is not a case is reported in a notification, and
the open case stays. Chapter 15 makes these messages the studio's error handling.

<<< @/examples/snippets/tut09_case-case.F90{fortran}

`ig_input_text('title', inp%title)` edits the character variable in place, up to its length; it is `.true.` on the
frame the text changes, and the studio marks the case as edited. The Save button is greyed out
(`ig_begin_disabled`) while there is nothing to save.

<<< @/examples/snippets/tut09_case-title.F90{fortran}

`app%set_title` changes the window's title: in the bar FIGURE draws, and in the task bar. The star tells the user
there are unsaved changes ([The window's title](/guide/menus#the-window-s-title)).

## Asking before discarding changes

<<< @/examples/snippets/tut09_case-request.F90{fortran}

<<< @/examples/snippets/tut09_case-dialogs.F90{fortran}

- Opening another case and quitting both go through `request`: with no unsaved change it acts at once (the studio
  quits without a question now: there is nothing to lose); with one, it remembers the action and asks.
- The question is a modal with three answers: Save, then go on; Discard, go on; Cancel, nothing happens. The
  close button, File > Quit and ctrl+q all reach it, since `app%set_confirm_quit(.true.)` turns the close button into
  a request ([Ask before quitting](/guide/menus#ask-before-quitting)).
- The recent cases, in File > Recent cases, are the studio's own list, for this session; the browser's recent
  folders are FIGURE's, kept between runs.

::: tip What you learned
A folder chosen with FIGURE's file browser or the system's dialog, the answer read on a later frame; folders and
files dropped on the window; a namelist read with its error message; the window's title marking unsaved changes; and
one question before an open or a quit discards them. Reference: [File dialogs](/guide/frame-loop#file-dialogs),
[FIGURE's file browser](/guide/frame-loop#figure-s-file-browser), [Drops](/guide/frame-loop#drops),
[Ask before quitting](/guide/menus#ask-before-quitting), [Notifications](/guide/frame-loop#notifications).
:::

**Next:** [10. The input editor](./10-input): a tree of the input's sections, forms, a table, the input as text, undo.
