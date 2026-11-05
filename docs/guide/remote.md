---
title: Remote UI
---

# Remote UI

`app%init_remote` replaces the window with a small web server: the program draws its interface as usual, and a web
browser shows it and sends the input back. The program needs no display, no GPU and no window system, so it can run
where computations run, a cluster node or a workstation without a screen, and keep everything native (OpenMP, MPI,
GPUs); the browser only draws.

```fortran
call app%init_remote(port=8080_int32)   ! prints: FIGURE: open http://localhost:8080/?token=... in a web browser
do while (app%next_frame())
   ! the same widgets and plots as in a window
enddo
call app%destroy()
```

Try it with the example: `exe/figure_hello --remote 8080`, then open the address it prints (with its `?token=...`).

<Media name="remote" alt="The interface of figure_hello drawn by a web browser at localhost:8080" caption="figure_hello --remote, drawn by Chromium: the same pixels as the native window" />

## init_remote

`app%init_remote([port] [, host] [, width, height] [, port_used] [, quiet] [, max_fps] [, compress] [, token] [, url] [, stat])`:

| Argument | Meaning |
|---|---|
| `port` | port to listen on (default 8080); `0` takes any free port, returned in `port_used` |
| `host` | address to listen on (default `127.0.0.1`, this machine only) |
| `width`, `height` | display size until a browser connects and sends its own (default 1280 x 800) |
| `port_used` | the port listened on |
| `quiet` | do not print the address to open |
| `max_fps` | most frames per second (default 60; `0`: no cap): a browser has no vsync to pace the program |
| `token` | the access token the address must carry (default: 32 random hex digits; `''`: none) |
| `url` | the address to open, with the token: `http://localhost:8080/?token=...` |
| `compress` | deflate frames and textures: `'auto'` (default) only while the browser cannot keep up, `'always'`, `'never'` |
| `stat` | `FIG_ERR_FAILED` if the port cannot be opened (in use, not permitted); `FIG_ERR_ARGUMENT` for a bad `port`, size, `compress` or `token`; `FIG_ERR_STATE` if FIGURE is already initialized |

Everything else is unchanged: widgets, plots, heatmaps, textures (sent to the browser when they change), lazy redraw
(the loop sleeps on the network instead of the window's events, and wakes up on the browser's input).

## Access token

The program prints the address to open, with an **access token** in it:

```text
FIGURE: open http://localhost:8080/?token=95f45b3f811f0d5505f5f227eb9be619 in a web browser
```

The page and its connection are refused (`403`) without the token, so only who has the address controls the
program: on a shared machine, the other users logged into it can reach the port, but not guess 128 random bits. The
token is made anew at each start from the system's cryptographic generator (`/dev/urandom`, `rand_s` on Windows);
`init_remote(token='...')` sets your own (letters, digits, `-._~`, at most 256), `token=''` turns the check off.
Reloading the page keeps the token (it is in the address); `url` returns the address for a program that prints it
elsewhere (a log, a job's output).

The token does not encrypt anything: the traffic is plain HTTP. Keep the default host, `127.0.0.1`, and reach a remote
machine through SSH, which encrypts it.

## A program on a cluster node

Reach the node through an SSH tunnel from your machine, then open the printed address there:

```bash
ssh -L 8080:localhost:8080 user@node        # then open http://localhost:8080/?token=... on your machine
```

Through a login node, chain the hops (`ssh -J login -L 8080:localhost:8080 node`). Do not set `host='0.0.0.0'` on a
shared machine: the token would then travel unencrypted over the network.

## Behaviour

- **One browser at a time.** A new one replaces the previous one; the browser can be closed, reloaded or opened later
  while the program runs: it receives the textures again, then the frames. The page reconnects by itself if the
  connection drops.
- **The program does not wait for a browser.** Without one, frames are drawn and dropped; the computation goes on.
- **Closing the browser does not end the program**: `next_frame` keeps returning `.true.`; the program ends itself.
- **Frames are paced.** At most `max_fps` per second, and a frame is sent only once the previous one has left the
  program: on a slow link the newest frame goes and the ones drawn meanwhile are skipped, so the interface lags by one
  frame at most, never by a growing queue.
- **Input**: mouse (position, buttons, wheel), keyboard (navigation and editing keys, Ctrl/Shift/Alt/Super, typed
  characters), and the size of the browser's window, which becomes the display size.
- **Shortcuts stay in the page**: with the interface focused, ctrl (cmd) combinations go to the program, not to the
  browser (ctrl+s does not open the browser's save dialog), except copy, paste and cut. On a Mac the client sends cmd
  as ctrl, so the program's `ig_shortcut('ctrl+s')` is cmd+s there, as in a window on macOS
  ([Menus and shortcuts](menus#shortcuts)).

## Bandwidth

How the cost of what you draw carries over to the network, and what to do about it:
[Performance](performance#remote-mode).


A frame carries the complete draw lists, in a compact form: 12 bytes per vertex (position to 1/4 pixel, texture
coordinates to 1/65535) instead of Dear ImGui's 20. A window of widgets and a 1000-point line is about **71 KB**; the
font atlas (256 KB) goes once per connection. What keeps the traffic down:

- **A frame equal to the last one sent is not sent again**: the server says "unchanged" at most once per second, so
  the browser knows the program is alive. An idle interface costs nothing.
- **Frames are capped** at `max_fps` (60) per second, and **one frame at most is queued**: a slow link gets the newest
  frame, never a backlog.
- **Deflate**, when the link is the bottleneck (`compress='auto'`): frames shrink 2.5 to 3.5 times more, for about
  7 ms of CPU per MB (0.4 ms for that 71 KB frame). On a fast link it stays off, since it would only cost CPU.
- Textures (`texture_object`) are sent only when `tex%update` changes them.

Measured with `scripts/measure_redraw.py` (the program `figure_bench_redraw`, remote mode on the same machine, 8–10 s
per case), from the first version of remote mode to now:

| what the program does | first version | now | now, deflated |
|---|---|---|---|
| nothing (idle, refreshing twice a second) | 216 KB/s | **1 byte/s** | |
| the user moves the pointer over it | 25.8 MB/s (238 frames/s) | 3.1 MB/s (60 frames/s) | 1.2 MB/s |
| live data, 10 updates per second | 1.07 MB/s | 0.71 MB/s | 0.28 MB/s |
| live data, 60 updates per second | 6.6 MB/s | 4.2 MB/s | 1.7 MB/s |
| a 100 000-point line, 10 updates per second | 9.2 MB per frame | 6.0 MB | 1.7 MB |
| a 256 × 256 heatmap, 10 updates per second | 6.0 MB per frame | 3.9 MB | 1.2 MB |

Through an SSH tunnel from an office to a cluster node (about 9 MB/s on that link), with the defaults: live data at
60 updates per second arrives at 60 frames per second (4.2 MB/s, no deflate needed); interacting, 45 frames per
second; the 100 000-point line at 5 frames per second, deflated (1 frame per second without deflate), always the
newest. Large data stays large on the wire: on a slow link, decimate what you plot, or show a big field as a texture
at the size it is displayed (a 3840 × 2160 texture is 33 MB per update before deflate).

## How it works

The native layer contains a minimal HTTP and WebSocket server (RFC 6455, one client, non-blocking sockets on POSIX and
Winsock). `GET /?token=...` answers the client page, embedded in the library; `GET /ws?token=...` upgrades to a WebSocket;
both answer `403` without the token. After each
frame the server sends, as binary messages, the textures Dear ImGui created or changed (RGBA, with their filtering)
and the draw lists (12-byte vertices, or 20-byte ones for a list reaching beyond ±8191 pixels; 16-bit indices;
commands with clip rectangle, texture, index range and vertex offset, so a window may hold more than 65 536
vertices, as a long plotted line does), unless they equal the last ones sent, deflated when compression is on; on
connection, and when the [style](styles) changes, it also sends the background colour. The page draws
them with WebGL, exactly as the OpenGL backend draws a window, and sends input events back as short text messages. The protocol is described at the top of `native/figure_remote.cpp`.

`src/tests/figure_test_remote.F90` tests it end to end without a browser: it serves on a free port and runs
`scripts/remote_client.py`, a WebSocket client that checks the page and the refusal of a missing or wrong token, the handshake, every message byte by byte (including a draw
list over 65 536 vertices), a resize, that an idle interface sends no frame (only "unchanged"), then clicks a button the program must see clicked once. It needs `python3` (3.11+).
