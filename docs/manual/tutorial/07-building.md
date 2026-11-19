---
title: 7. Building and running the studio
---

# 7. Building and running the studio

Part two builds one application, a small **solver studio**, over eleven chapters (8 to 18), and part three goes on
with it (19 to 26). This chapter is how to build and run any of them; the later pages show what each adds.

## One program per chapter

Each chapter's program is a single file in
[`docs/examples/src`](https://github.com/szaghi/figure/tree/main/docs/examples/src), named after its chapter:
`tut08_window.F90` for chapter 8, `tut13_field.F90` for chapter 13. It is the previous chapter's program with what
the page lists added, so any one of them is a complete studio up to that point: start from the chapter you are
reading, not from the first. Each page opens with what the chapter adds and links the whole program.

## Building one

The same line as chapter 1's, with the chapter's file (FIGURE installed by the [one-line installer](/guide/install),
`PKG_CONFIG_PATH` set as it printed):

```bash
gfortran tut13_field.F90 $(pkg-config --cflags --libs figure) -o tut13_field
```

The studio runs a solver from chapter 12 on: `tut12_heat.F90`, a small heat-equation program, replaced in chapter 22
by `tut22_heat.F90`, which also prints the plate's mean temperature. Build it the same way and keep it **in the same
folder as the studio**: the studio looks for it there, beside its own executable, not in `PATH`.

```bash
gfortran tut12_heat.F90 $(pkg-config --cflags --libs figure) -o tut12_heat
```

From a FIGURE checkout, `bash docs/examples/build.sh` builds every program of the tutorial and the cookbook, the
solvers beside the studios, into `build/docs-examples/bin` ([Contributing](/guide/contributing#documentation)).

## Running one

```bash
./tut13_field --examples /tmp/studio      # write two example cases into /tmp/studio, then open the studio there
./tut13_field --case /tmp/studio/plate    # open that case at the start
./tut13_field                             # an empty studio: File > Open
```

`--examples DIR` writes two small cases, a plate and a channel, and starts the file browser in `DIR` (from chapter
10, which opens cases); `--case DIR` opens a case at once (from chapter 11). From chapter 17, `--test` runs the
studio headless against its own checks, and from chapter 18, `--remote PORT` serves it to a browser (with `--run`,
it starts the solver at once); each page describes its own.

## When a call fails

FIGURE reports a failure the same way everywhere: a procedure with an optional `stat` sets it, and
`figure_last_error()` says what went wrong; without `stat`, the program stops with the message. The studio uses
the first form where a failure is expected, as chapter 8's window does with its icon, which some platforms cannot
show:

<<< @/examples/snippets/tut08_window-window.F90{fortran}

Chapter 16 makes this the studio's rule; [Errors](/guide/errors) lists every status and message.

::: tip What you learned
A chapter's program is one file, the previous chapter's plus that chapter's additions; it builds with chapter 1's
line, the solver beside it; `--examples` and `--case` start it on a case; `stat` and `figure_last_error` report a
failure instead of stopping. Reference: [Installation](/guide/install), [Errors](/guide/errors).
:::

**Next:** [8. The studio's own window](./08-window): the studio's first program, its window drawn by FIGURE.
