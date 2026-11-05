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
// A frame was skipped because the previous one was still queued (a slow client): the program should draw again, so
// that the latest state goes out as soon as the queue drains (serve returns true then).
bool frame_pending();
// The last frame sent is still (partly) in the client's queue.
bool queue_busy();
// Send a rendered frame to the client, if any: the textures Dear ImGui asks for (created, updated, destroyed), then
// the draw lists. Also answers Dear ImGui's texture requests when no client is connected.
void send_frame(ImDrawData *draw_data);
// User textures (texture_object): RGBA pixels, kept to be sent again to a client that connects later.
void texture_update(std::uint64_t id, int width, int height, const unsigned char *rgba, bool linear);
void texture_destroy(std::uint64_t id);
// The background behind the windows (the style's), sent to the client now and to every client that connects.
void set_background(float r, float g, float b);
// A new texture id, shared by Dear ImGui's and the user's textures.
std::uint64_t new_texture_id();

} // namespace figure_remote

#endif
