---
title: Remote UI
---

# Remote UI

`app%init_remote` replaces the window with a small web server: the program draws its interface as usual, and a web
browser shows it and sends the input back. The program needs no display, no GPU and no window system, so it can run
where computations run, a cluster node or a workstation without a screen, and keep everything native (OpenMP, MPI,
GPUs); the browser only draws.

```fortran
call app%init_remote(port=8080_int32)   ! prints: FIGURE: open http://localhost:8080/ in a web browser
do while (app%next_frame())
   ! the same widgets and plots as in a window
enddo
call app%destroy()
```

Try it with the example: `exe/figure_hello --remote 8080`, then open `http://localhost:8080/`.

<Media name="remote" alt="The interface of figure_hello drawn by a web browser at localhost:8080" caption="figure_hello --remote, drawn by Chromium: the same pixels as the native window" />

## init_remote

`app%init_remote([port] [, host] [, width, height] [, port_used] [, quiet] [, stat])`:

| Argument | Meaning |
|---|---|
| `port` | port to listen on (default 8080); `0` takes any free port, returned in `port_used` |
| `host` | address to listen on (default `127.0.0.1`, this machine only) |
| `width`, `height` | display size until a browser connects and sends its own (default 1280 x 800) |
| `port_used` | the port listened on |
| `quiet` | do not print the address to open |
| `stat` | `FIG_ERR_FAILED` if the port cannot be opened (in use, not permitted) |

Everything else is unchanged: widgets, plots, heatmaps, textures (sent to the browser when they change), lazy redraw
(the loop sleeps on the network instead of the window's events, and wakes up on the browser's input).

## A program on a cluster node

The server has **no authentication**: whoever reaches the port controls the program. Keep the default host,
`127.0.0.1`, and reach the node through an SSH tunnel from your machine:

```bash
ssh -L 8080:localhost:8080 user@node        # then open http://localhost:8080/ on your machine
```

Through a login node, chain the hops (`ssh -J login -L 8080:localhost:8080 node`). Do not set `host='0.0.0.0'` on a
shared machine.

## Behaviour

- **One browser at a time.** A new one replaces the previous one; the browser can be closed, reloaded or opened later
  while the program runs: it receives the textures again, then the frames. The page reconnects by itself if the
  connection drops.
- **The program does not wait for a browser.** Without one, frames are drawn and dropped; the computation goes on.
- **Closing the browser does not end the program**: `next_frame` keeps returning `.true.`; the program ends itself.
- **Input**: mouse (position, buttons, wheel), keyboard (navigation and editing keys, Ctrl/Shift/Alt/Super, typed
  characters), and the size of the browser's window, which becomes the display size.

## Bandwidth

A frame carries the complete draw lists: about **110 KB** for a window of widgets and a 1000-point line, of which 86 %
are vertices; the font atlas (**256 KB**) goes once per connection. **A frame equal to the last one sent is not sent
again**: the server says "unchanged" at most once per second instead, so the browser knows the program is alive.
Textures (`texture_object`) are sent only when `tex%update` changes them.

Measured with `scripts/measure_redraw.py` (the program `figure_bench_redraw`, 10 s per case):

| what the program does | sent before skipping | sent now |
|---|---|---|
| nothing (idle, refreshing twice a second) | 216 KB/s | **1 byte/s** |
| the user moves the pointer over it | 25.8 MB/s | 4.8 MB/s |
| live data, 1 update per second | 107 KB/s | 107 KB/s |
| live data, 10 updates per second | 1.07 MB/s | 1.07 MB/s |
| live data, 60 updates per second | 6.6 MB/s | 3.3 MB/s |

So an idle interface costs nothing, and live data costs what it changes: one frame per update. Large data is large
on the wire too: a 100 000-point line is about 9 MB per frame, a 256 × 256 heatmap 6 MB, a 3840 × 2160 texture 33 MB
per update; on a slow link, decimate what you plot, or show a field as a texture at the size it is displayed.

## How it works

The native layer contains a minimal HTTP and WebSocket server (RFC 6455, one client, non-blocking sockets on POSIX and
Winsock). `GET /` answers the client page, embedded in the library; `GET /ws` upgrades to a WebSocket. After each
frame the server sends, as binary messages, the textures Dear ImGui created or changed (RGBA, with their filtering)
and the draw lists (20-byte vertices, 16-bit indices, commands with clip rectangle, texture, index range and vertex offset, so a
window may hold more than 65 536 vertices, as a long plotted line does), unless they equal the last ones sent; on
connection, and when the [style](styles) changes, it also sends the background colour. The page draws
them with WebGL, exactly as the OpenGL backend draws a window, and sends input events back as short text messages. The protocol is described at the top of `native/figure_remote.cpp`.

`src/tests/figure_test_remote.F90` tests it end to end without a browser: it serves on a free port and runs
`scripts/remote_client.py`, a WebSocket client that checks the page, the handshake, every message byte by byte (including a draw
list over 65 536 vertices), a resize, that an idle interface sends no frame (only "unchanged"), then clicks a button the program must see clicked once. It needs `python3` (3.11+).
