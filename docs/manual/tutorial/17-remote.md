---
title: 17. The studio on a cluster
---

# 17. The studio on a cluster

A real case lives on a cluster: its input, its multi-gigabyte results, the solver and the queue are there, and
copying the results to a laptop to look at them is the slowest part of the day. In remote mode the studio runs on the
cluster's node, next to its files, and draws its interface in a web browser on your machine: no display, no GPU and
no X server on the node; only the frames travel.

<Media name="tut17_remote" alt="A browser window at localhost:8080 with an access token in the address, showing the whole studio as in a window: the menus File, Edit, Run, View, Help along the top of the page (in remote mode there is no title bar: the browser's window is the frame), the workspace buttons, the Case panel with the plate case and a copy button next to its path, the Result panel with the heatmap of the plate's temperature, its contour lines, legend and profile, and the Run panel below; the status bar reads ready" caption="docs/examples/src/tut17_remote.F90, run as tut17_remote --examples /tmp/figure-studio --case /tmp/figure-studio/plate --remote 18765, drawn by a headless Chromium" />

The whole program: [tut17_remote.F90](https://github.com/szaghi/figure/blob/main/docs/examples/src/tut17_remote.F90).

## One option

<<< @/examples/snippets/tut17_remote-open.F90{fortran}

- `app%init_remote(port=)` creates the contexts and serves the interface on `http://127.0.0.1:PORT/` instead of
  opening a window ([Remote UI](/guide/remote)). Everything after it is the studio as it was: the same
  `draw_studio`, the same loop; widgets, plots, the 3-D view and the file browser are drawn the same way, and the
  browser's mouse and keyboard reach them.
- `set_icon` is not called: there is no window; the browser's tab shows the title.
- The address carries an **access token**, 128 random bits made at each start: without it the page and its
  connection are refused, so the other users of a shared node cannot take the studio over
  ([Access token](/guide/remote#access-token)).

<<< @/examples/snippets/tut17_remote-address.F90{fortran}

`quiet=.true.` keeps `init_remote` from printing the address, and `url=` returns it: the studio prints it once the
case is open, so the browser finds it ready. A program started by a batch job writes it to the job's output.

## Reaching the node

Start the studio on the node, then open a tunnel from your machine and the printed address in your browser:

```bash
tut17_remote --case ~/cases/plate --remote 8080          # on the node: prints FIGURE: open http://localhost:8080/?token=...
ssh -L 8080:localhost:8080 user@node                     # on your machine; through a login node: ssh -J login -L ...
```

The studio listens on `127.0.0.1` only, the node itself; SSH carries and encrypts the traffic. Closing the browser
does not end the studio: open the address again later, and it is where you left it
([A program on a cluster node](/guide/remote#a-program-on-a-cluster-node)).

## What a browser allows

The studio is the same program; the browser is not a desktop, and a few of the studio's habits change:

- **Files:** the system's dialog does not exist (`open_folder_dialog` is refused with `FIG_ERR_STATE`), and the studio
  already opens FIGURE's file browser then (chapter 9). It lists the node's files, which is what the studio works on
  ([Opening and saving files](/guide/remote#opening-and-saving-files)).
- **Drops:** a browser gives a page the contents of the files dropped on it, never a path on the node, so the page
  refuses them. The Case panel says so:

<<< @/examples/snippets/tut17_remote-hint.F90{fortran}

- **The clipboard:** the copy button puts the case's path on the clipboard, to paste it in a terminal
  (`cd`, `sbatch`). In remote mode the page writes it to the browser's clipboard, which browsers allow at
  `http://localhost` (the tunnel) or over HTTPS; elsewhere the text stays in the program, and a paste inside the
  studio still gets it ([The clipboard and drops](/guide/remote#the-clipboard-and-drops)).

<<< @/examples/snippets/tut17_remote-copy.F90{fortran}

- **Shortcuts:** ctrl combinations go to the studio, not to the browser: ctrl+s does not save the page, ctrl+o opens
  the studio's browser. On a Mac, cmd is sent as ctrl.
- **No frame:** the browser's window is the window; the menus are drawn along the top of the page.

## Bandwidth

A frame carries the interface's draw lists, not pixels, and only when it changed: an idle studio sends nothing, the
pointer moving over it a few MB/s, and a frame waits for the previous one to leave, so a slow link gets the newest
frame and never a backlog ([Bandwidth](/guide/remote#bandwidth)). The studio asks for at most 30 frames per second
(`max_fps`), and `compress='auto'` deflates the frames while the link cannot keep up. What it draws decides the rest:

- the heatmap and the 3-D surface draw chapter 14's **coarse copy**, at most 200 nodes a side, whatever the grid;
- the 3-D view sends its image only when it renders again (the camera moved, a mesh changed);
- the log draws only the lines in view, however long the run.

A field of millions of cells sent as a heatmap would be megabytes per frame; the coarse copy keeps it to what the
browser's pixels can show.

::: tip What you learned
The same program in a window and in a browser, by one call; the access token and an SSH tunnel to a cluster node;
what a browser allows of files, drops, the clipboard and shortcuts; and what keeps the traffic down. Reference:
[Remote UI](/guide/remote), [Performance: remote mode](/guide/performance#remote-mode).
:::

This is the end of part two. The [Cookbook](../cookbook) answers one task per recipe, and the
[Reference](/guide/features) lists every procedure.
