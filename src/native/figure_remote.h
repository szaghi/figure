// FIGURE remote mode: the UI in a web browser. A minimal HTTP + WebSocket server (one client) serves the client page
// (figure_remote_client.html) and streams the Dear ImGui draw data to it; the browser sends input back. The program
// needs no window, display or GPU: it can run on a cluster node, reached through an SSH tunnel.
#ifndef FIGURE_REMOTE_H
#define FIGURE_REMOTE_H

#include <cstdint>
#include <string>

struct ImDrawData;

namespace figure_remote {

// Listen on host:port (port 0: any free port); `bound_port` receives the port. False on failure, with `err`.
bool start(const std::string &host, int port, int &bound_port, std::string &err);
// Close every socket.
void stop();
// Serve the network for at most `timeout_ms` (0: just poll): accept, answer HTTP, send queued output, read WebSocket
// messages and feed them to Dear ImGui's IO. Returns early, true, when input arrived (or a client connected) or a
// skipped frame can now be sent: the UI must be redrawn.
bool serve(int timeout_ms);
// From any thread: end serve's wait at once (serve returns true), or the next one's if none is under way.
void wake();
// A frame was skipped because the previous one was still queued (a slow client): the program should draw again, so
// that the latest state goes out as soon as the queue drains (serve returns true then).
bool frame_pending();
// The last frame sent is still (partly) in the client's queue.
bool queue_busy();
// Send a rendered frame to the client, if any: the textures Dear ImGui asks for (created, updated, destroyed) and the
// user textures updated since the last frame sent (as JPEG while they change, see set_lossy), then the draw lists.
// Also answers Dear ImGui's texture requests when no client is connected.
void send_frame(ImDrawData *draw_data);
// User textures (texture_object): RGBA pixels, kept to be sent with the next frame that goes out, and again to a
// client that connects later.
void texture_update(std::uint64_t id, int width, int height, const unsigned char *rgba, bool linear);
void texture_destroy(std::uint64_t id);
// The background behind the windows (the style's), sent to the client now and to every client that connects.
void set_background(float r, float g, float b);
// Deflate frames and textures: 0 auto (while the client has been the bottleneck in the last 5 s), 1 always, 2 never.
void set_compression(int mode);
// Send a user texture updated in two consecutive frames (the 3-D view while the camera moves) as JPEG at quality 75
// while it keeps changing, and its exact pixels once it is still (not updated for 150 ms) (true, default); false:
// always exact. Textures with transparent pixels are always sent exact.
void set_lossy(bool on);
// The access token the page and the WebSocket need in their address (?token=...): made at start (32 hex digits from the
// system's cryptographic generator), replaced by the program's own, or disabled (empty).
void set_token(const std::string &token);
const std::string &token();
// The clipboard of remote mode (Dear ImGui's platform clipboard): set keeps the text and sends it to the page (message
// 7), which writes it to the browser's clipboard where the browser allows it; the page sends the browser's clipboard
// on a paste ("p:" event), before the key that pastes. clipboard is the last of the two.
void set_clipboard(const char *text);
const char *clipboard();
// Ask the page to open `url` in the browser (message 9), a link the user clicked (ig_text_link_url).
void open_url(const char *url);
// A new texture id, shared by Dear ImGui's and the user's textures.
std::uint64_t new_texture_id();

} // namespace figure_remote

#endif
