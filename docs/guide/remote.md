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

Each frame sends the complete draw lists. Measured for `figure_hello` (a window of widgets and a 1000-point line):
**110 KB per frame**, plus **256 KB once** per connection for the font atlas. With lazy redraw an idle interface draws
2 frames per second (about 220 KB/s); while the user interacts it draws at up to 60 frames per second (about 6.6 MB/s).
That is comfortable on a local network and through a fast tunnel; on a slow link, raise `max_wait` with
`app%set_lazy` to refresh less often when idle. Textures (`texture_object`) are sent only when `tex%update` changes
them.

## How it works

The native layer contains a minimal HTTP and WebSocket server (RFC 6455, one client, non-blocking sockets on POSIX and
Winsock). `GET /` answers the client page, embedded in the library; `GET /ws` upgrades to a WebSocket. After each
frame the server sends, as binary messages, the textures Dear ImGui created or changed (RGBA, with their filtering)
and the draw lists (20-byte vertices, 16-bit indices, commands with clip rectangle, texture and index range). The page
draws them with WebGL, exactly as the OpenGL backend draws a window, and sends input events back as short text
messages. The protocol is described at the top of `native/figure_remote.cpp`.

`src/tests/figure_test_remote.F90` tests it end to end without a browser: it serves on a free port and runs
`scripts/remote_client.py`, a WebSocket client that checks the page, the handshake, every message byte by byte and a
resize, then clicks a button the program must see clicked once. It needs `python3` (3.11+).
