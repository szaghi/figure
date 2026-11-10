---
title: 1. A first window
---

# 1. A first window

<<< @/examples/snippets/tut01_window.F90{fortran}

<Media name="tut01_window" :width="240" alt="A small window titled Hello, with the text Hello from Fortran" caption="The window of tut01_window" />

- `app_object` is the application: one per program. `init` opens a 640 x 360 window titled "FIGURE: first window"
  and creates the Dear ImGui and ImPlot contexts.
- `next_frame()` renders the previous frame, waits for input, and opens the next frame; it returns `.false.` when the
  user closes the window.
- Between two `next_frame` calls the program declares the interface. Here, one Dear ImGui window named "Hello" with
  one line of text. The window can be moved, resized and collapsed with the mouse: Dear ImGui handles it.
- `ig_begin` returns `.false.` when the window is collapsed: its content is skipped. `ig_end` is called in any case.
- `destroy` closes the window.

The program does nothing while you do not touch it: once the interface has settled, `next_frame` sleeps until the
next input event or for at most 0.5 s ([lazy redraw](/guide/frame-loop#lazy-redraw)).

## Building it

Save the program above as `tut01_window.F90`. With FIGURE installed by the [one-line installer](/guide/install)
(`PKG_CONFIG_PATH` set as the installer printed):

```bash
gfortran tut01_window.F90 $(pkg-config --cflags --libs figure) -o tut01_window
./tut01_window
```

On WSL2, set `GALLIUM_DRIVER=d3d12` before running it ([Installation](/guide/install#wsl2-wslg)).

In a clone of the repository, after `scripts/build_native.sh` and from its root (the chapter's source is
`docs/examples/src/tut01_window.F90`):

```bash
fobis build --mode figure-static-gnu
gfortran -I lib/mod docs/examples/src/tut01_window.F90 lib/libfigure.a -L lib -lfigure_native -lSDL3 -lstdc++ -ldl \
         -lpthread -lm -o tut01_window
```

::: tip What you learned
The application, the frame loop, a window. Reference: [Frame loop and redraw](/guide/frame-loop).
:::

Next: [2. Widgets and state](./02-widgets).
