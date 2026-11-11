// FIGURE remote mode: a minimal HTTP + WebSocket server (RFC 6455) streaming Dear ImGui's draw data to a browser.
//
// One client at a time. GET / answers the client page; GET /ws upgrades to a WebSocket. Server to client: binary
// messages, little-endian (the client is JavaScript on little-endian hardware):
//   1 frame:    u8 1, f32 display_w, display_h, u32 lists; per list: u32 vtx_count, idx_count, cmd_count, flags,
//               the vertices: if flags bit 0, compact, vtx_count x (i16 x, y in 1/4 pixel, u16 u, v in 1/65535,
//               u32 rgba) = 12 bytes, else vtx_count x ImDrawVert (f32 x, y, u, v, u32 rgba) = 20 bytes (a list
//               with a position beyond +-8191 pixels or a uv outside [0, 1]); idx_count x u16 (padded to 4 bytes),
//               cmd_count x (f32 clip x1, y1, x2, y2, u32 texture, idx_offset, elem_count, vtx_offset): each
//               command draws elem_count indices from idx_offset, every index counted from vertex vtx_offset (a
//               list may hold more than 65536 vertices: Dear ImGui then starts a new vertex range, the 16-bit
//               indices are relative to it)
//   2 texture:  u8 2, u32 id, width, height, flags (bit 0: linear filtering, else nearest), then width x height x 4
//               RGBA bytes (created or replaced)
//   3 destroy:  u8 3, u32 id
//   4 background: u8 4, f32 r, g, b (0 to 1): the colour behind the windows (sent on connection and on change)
//   6 deflated: u8 6, then a zlib stream (RFC 1950) holding one message of the kinds above: frames and textures
//               are deflated when compression is on (always, or in auto mode while the client is the bottleneck)
//   5 unchanged: u8 5: the frame equals the last one sent, which is not sent again; at most once per second, so the
//               client knows the program is alive (an idle interface sends nothing else)
//   7 clipboard: u8 7, then UTF-8 text: the program copied it (Dear ImGui's copy, ig_set_clipboard); the page writes it
//               to the browser's clipboard where the browser allows it (a secure context, such as localhost)
//   8 JPEG texture: u8 8, u32 id, width, height, flags (as kind 2), then a baseline JPEG (JFIF) of width x height
//               pixels, alpha 255: a user texture that is changing (updated in two consecutive frames, the 3-D view
//               while the camera moves), sent lossy at quality 75 while it changes; a lossless texture (kind 2)
//               replaces it once it is still (not updated for 150 ms) and drawn, with a frame or on its own. Never
//               deflated
//   9 open URL: u8 9, then the UTF-8 URL of a link the user clicked (ig_text_link_url); the page opens it in a new tab
// Textures go out with the frames, before the frame that draws them: an update kept while frames are skipped for a
// slow client is sent once, its latest pixels, with the next frame that goes.
// Access: unless the token is disabled, GET / and GET /ws need "?token=<token>" in their target, else 403. The token is
// 32 hex digits (128 bits from the system's cryptographic generator) made at start, or the program's own.
// Client to server: text messages, one event each: "m:x,y" mouse position, "b:button,down", "w:dx,dy" wheel,
// "k:down,code" key (KeyboardEvent.code), "c:text" typed characters, "s:width,height" canvas size, "p:text" the
// browser's clipboard (sent on a paste, before the key that pastes).
#ifdef _WIN32
#define _CRT_RAND_S // rand_s: the system's cryptographic generator (RtlGenRandom), for the access token
#endif
#include "figure_native.h"
#include "figure_remote.h"
#include "figure_swrast.h"

#include "imgui.h"
// miniz: deflate and zlib streams only, mz_ names only (CMake passes the same; an fpm build passes nothing)
#ifndef MINIZ_NO_ARCHIVE_APIS
#define MINIZ_NO_ARCHIVE_APIS
#endif
#ifndef MINIZ_NO_STDIO
#define MINIZ_NO_STDIO
#endif
#ifndef MINIZ_NO_TIME
#define MINIZ_NO_TIME
#endif
#ifndef MINIZ_NO_ZLIB_COMPATIBLE_NAMES
#define MINIZ_NO_ZLIB_COMPATIBLE_NAMES
#endif
#include "miniz.h"
#include "figure_image.h" // stb_image_write's JPEG encoder (compiled in figure_image.cpp)

#include <algorithm>
#include <chrono>
#include <cctype>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <mutex>
#include <set>
#include <string>
#include <vector>

#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
// Winsock is loaded at run time from ws2_32.dll (part of every Windows), so a program links FIGURE with no Windows-only
// library: an fpm build cannot add one for one platform. Each pointer has the exact type of the function it stands
// for (decltype keeps the calling convention); the names below are redirected to them.
namespace winsock {
#define FIGURE_WINSOCK(X) X(WSAStartup) X(WSAGetLastError) X(socket) X(setsockopt) X(bind) X(listen) X(accept) \
   X(getaddrinfo) X(freeaddrinfo) X(getsockname) X(recv) X(send) X(select) X(closesocket) X(ioctlsocket) X(__WSAFDIsSet) \
   X(connect)
#define FIGURE_WINSOCK_POINTER(f) static decltype(&::f) p_##f = nullptr;
FIGURE_WINSOCK(FIGURE_WINSOCK_POINTER)
static bool load() {
   static HMODULE h = nullptr;
   if (h) return true;
   h = LoadLibraryA("ws2_32.dll");
   if (!h) return false;
#define FIGURE_WINSOCK_LOAD(f) \
   p_##f = reinterpret_cast<decltype(&::f)>(reinterpret_cast<void (*)(void)>(GetProcAddress(h, #f))); \
   if (!p_##f) return false;
   FIGURE_WINSOCK(FIGURE_WINSOCK_LOAD)
   return true;
}
} // namespace winsock
#define WSAStartup winsock::p_WSAStartup
#define WSAGetLastError winsock::p_WSAGetLastError
#define socket winsock::p_socket
#define setsockopt winsock::p_setsockopt
#define bind winsock::p_bind
#define listen winsock::p_listen
#define accept winsock::p_accept
#define getaddrinfo winsock::p_getaddrinfo
#define freeaddrinfo winsock::p_freeaddrinfo
#define getsockname winsock::p_getsockname
#define recv winsock::p_recv
#define send winsock::p_send
#define select winsock::p_select
#define closesocket winsock::p_closesocket
#define ioctlsocket winsock::p_ioctlsocket
#define __WSAFDIsSet winsock::p___WSAFDIsSet
#define connect winsock::p_connect
typedef SOCKET socket_t;
static const socket_t NO_SOCKET = INVALID_SOCKET;
static int close_socket(socket_t s) { return closesocket(s); }
static bool would_block() { return WSAGetLastError() == WSAEWOULDBLOCK; }
static void set_nonblocking(socket_t s) {
   u_long on = 1;
   ioctlsocket(s, FIONBIO, &on);
}
static const int SEND_FLAGS = 0;
#else
#include <arpa/inet.h>
#include <cerrno>
#include <fcntl.h>
#include <netdb.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <unistd.h>
typedef int socket_t;
static const socket_t NO_SOCKET = -1;
static int close_socket(socket_t s) { return close(s); }
#ifdef MSG_NOSIGNAL
static const int SEND_FLAGS = MSG_NOSIGNAL; // a closed peer must not raise SIGPIPE: it would end the program
#else
static const int SEND_FLAGS = 0; // macOS: SO_NOSIGPIPE on each socket instead
#endif
static bool would_block() { return errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR; }
static void set_nonblocking(socket_t s) { fcntl(s, F_SETFL, fcntl(s, F_GETFL, 0) | O_NONBLOCK); }
#endif

namespace {

// The client page, embedded at build time from native/figure_remote_client.html.
#include "figure_remote_client.inc"

// ---- SHA-1 and base64, for the WebSocket handshake only ----------------------------------------------------------

std::string sha1(const std::string &msg) {
   std::uint32_t h[5] = {0x67452301u, 0xEFCDAB89u, 0x98BADCFEu, 0x10325476u, 0xC3D2E1F0u};
   std::string m = msg;
   const std::uint64_t bits = static_cast<std::uint64_t>(msg.size()) * 8u;
   m.push_back(static_cast<char>(0x80));
   while (m.size() % 64 != 56) m.push_back('\0');
   for (int i = 7; i >= 0; --i) m.push_back(static_cast<char>((bits >> (8 * i)) & 0xFFu));
   auto rol = [](std::uint32_t x, int n) { return (x << n) | (x >> (32 - n)); };
   for (size_t chunk = 0; chunk < m.size(); chunk += 64) {
      std::uint32_t w[80];
      for (int i = 0; i < 16; ++i) {
         w[i] = 0;
         for (int b = 0; b < 4; ++b) w[i] = (w[i] << 8) | static_cast<unsigned char>(m[chunk + 4 * i + b]);
      }
      for (int i = 16; i < 80; ++i) w[i] = rol(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
      std::uint32_t a = h[0], b = h[1], c = h[2], d = h[3], e = h[4];
      for (int i = 0; i < 80; ++i) {
         std::uint32_t f, k;
         if (i < 20) { f = (b & c) | (~b & d); k = 0x5A827999u; }
         else if (i < 40) { f = b ^ c ^ d; k = 0x6ED9EBA1u; }
         else if (i < 60) { f = (b & c) | (b & d) | (c & d); k = 0x8F1BBCDCu; }
         else { f = b ^ c ^ d; k = 0xCA62C1D6u; }
         const std::uint32_t t = rol(a, 5) + f + e + k + w[i];
         e = d; d = c; c = rol(b, 30); b = a; a = t;
      }
      h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e;
   }
   std::string out;
   for (std::uint32_t v : h)
      for (int b = 3; b >= 0; --b) out.push_back(static_cast<char>((v >> (8 * b)) & 0xFFu));
   return out;
}

std::string base64(const std::string &in) {
   static const char *tbl = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
   std::string out;
   size_t i = 0;
   for (; i + 2 < in.size(); i += 3) {
      const unsigned v = (static_cast<unsigned char>(in[i]) << 16) | (static_cast<unsigned char>(in[i + 1]) << 8) |
                         static_cast<unsigned char>(in[i + 2]);
      out += tbl[(v >> 18) & 63]; out += tbl[(v >> 12) & 63]; out += tbl[(v >> 6) & 63]; out += tbl[v & 63];
   }
   if (i + 1 == in.size()) {
      const unsigned v = static_cast<unsigned char>(in[i]) << 16;
      out += tbl[(v >> 18) & 63]; out += tbl[(v >> 12) & 63]; out += "==";
   } else if (i + 2 == in.size()) {
      const unsigned v = (static_cast<unsigned char>(in[i]) << 16) | (static_cast<unsigned char>(in[i + 1]) << 8);
      out += tbl[(v >> 18) & 63]; out += tbl[(v >> 12) & 63]; out += tbl[(v >> 6) & 63]; out += '=';
   }
   return out;
}

// ---- state --------------------------------------------------------------------------------------------------------

struct connection_t {
   socket_t    s = NO_SOCKET;
   bool        websocket = false; // handshake done
   bool        close_after = false; // plain HTTP: close once the answer is sent
   std::string in;                // bytes received, not yet parsed
   std::string out;               // bytes to send
};

struct texture_t {
   int                        width = 0, height = 0;
   bool                       linear = false;
   bool                       user = false;    // a program's texture (texture_object, a 3-D view), not Dear ImGui's
   bool                       dirty = false;   // updated since it was last sent
   bool                       moving = false;  // its last two updates came in consecutive frames
   bool                       lossy = false;   // the client holds a JPEG of it, to be replaced by the exact pixels
   std::uint64_t              updated = 0;     // the frame of its last update (server_t::frame)
   std::chrono::steady_clock::time_point changed; // the time of its last update
   std::vector<unsigned char> rgba;
};

struct server_t {
   socket_t                                listener = NO_SOCKET;
   std::vector<connection_t>               conns;    // HTTP connections, and the WebSocket client
   std::map<std::uint64_t, texture_t>      textures; // every live texture, sent again to a new client
   std::uint64_t                           next_id = 1;
   bool                                    resend = false; // a client connected: send all textures
   std::string                             token;          // needed in the page's and the WebSocket's address
   std::string                             last_frame;     // the last frame message sent, to skip repeats
   size_t                                  unsent_frame = 0; // bytes of the last frame still in the client's queue
   bool                                    pending = false;  // a frame was skipped while the queue was busy
   int                                     compress = 0;     // 0 auto, 1 always, 2 never
   bool                                    lossy = true;     // changing user textures as JPEG (kind 8)
   std::uint64_t                           frame = 1;        // the frame being drawn: send_frame calls so far, + 1
   std::set<std::uint64_t>                 drawn;            // the textures the last frame sent draws
   std::chrono::steady_clock::time_point   last_skip;        // when a frame was last skipped for a busy queue
   std::chrono::steady_clock::time_point   last_sent;      // when a message last went to the client
   float                                   background[3] = {0.10f, 0.10f, 0.11f}; // behind the windows
   std::string                             clipboard;      // the program's clipboard: its copies, the browser's pastes
#ifdef _WIN32
   bool                                    wsa = false;
#endif
} sv;

// The wake socket: a UDP socket on the loopback, connected to itself. wake() sends it a byte, from any thread; serve
// waits on it with the others, so that a wake-up ends the wait at once. The mutex keeps a wake from sending to a
// socket that stop closes meanwhile.
std::mutex wake_mutex;
socket_t   wake_socket = NO_SOCKET;

bool open_wake(std::string &err) {
   addrinfo hints{}, *res = nullptr;
   hints.ai_family = AF_INET;
   hints.ai_socktype = SOCK_DGRAM;
   if (getaddrinfo("127.0.0.1", "0", &hints, &res) != 0 || !res) {
      err = "cannot resolve the loopback address for the wake socket";
      return false;
   }
   const socket_t s = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
   bool ok = s != NO_SOCKET && bind(s, res->ai_addr, static_cast<int>(res->ai_addrlen)) == 0;
   freeaddrinfo(res);
   sockaddr_in addr{};
   socklen_t len = sizeof(addr);
   ok = ok && getsockname(s, reinterpret_cast<sockaddr *>(&addr), &len) == 0 &&
        connect(s, reinterpret_cast<sockaddr *>(&addr), static_cast<int>(len)) == 0;
   if (!ok) {
      if (s != NO_SOCKET) close_socket(s);
      err = "cannot open the wake socket on the loopback";
      return false;
   }
   set_nonblocking(s);
   std::lock_guard<std::mutex> lock(wake_mutex);
   wake_socket = s;
   return true;
}

void close_wake() {
   std::lock_guard<std::mutex> lock(wake_mutex);
   if (wake_socket != NO_SOCKET) close_socket(wake_socket);
   wake_socket = NO_SOCKET;
}

connection_t *client() {
   for (auto &c : sv.conns)
      if (c.websocket && c.s != NO_SOCKET) return &c;
   return nullptr;
}

// ---- WebSocket framing --------------------------------------------------------------------------------------------

void ws_append(connection_t &c, int opcode, const std::string &payload) {
   std::string f;
   f.push_back(static_cast<char>(0x80 | opcode)); // FIN
   const std::uint64_t n = payload.size();
   if (n < 126) {
      f.push_back(static_cast<char>(n));
   } else if (n < 65536) {
      f.push_back(126);
      f.push_back(static_cast<char>((n >> 8) & 0xFF));
      f.push_back(static_cast<char>(n & 0xFF));
   } else {
      f.push_back(127);
      for (int i = 7; i >= 0; --i) f.push_back(static_cast<char>((n >> (8 * i)) & 0xFF));
   }
   c.out += f;
   c.out += payload;
}

static_assert(sizeof(ImDrawIdx) == 2, "the client reads 16-bit indices");
static_assert(sizeof(ImDrawVert) == 20, "the client reads 20-byte vertices (pos, uv, col)");

template <typename T> void put(std::string &b, T v) { b.append(reinterpret_cast<const char *>(&v), sizeof(T)); }

std::string texture_message(std::uint64_t id, const texture_t &t) {
   std::string m;
   m.reserve(13 + t.rgba.size());
   put<std::uint8_t>(m, 2);
   put<std::uint32_t>(m, static_cast<std::uint32_t>(id));
   put<std::uint32_t>(m, static_cast<std::uint32_t>(t.width));
   put<std::uint32_t>(m, static_cast<std::uint32_t>(t.height));
   put<std::uint32_t>(m, t.linear ? 1u : 0u);
   m.append(reinterpret_cast<const char *>(t.rgba.data()), t.rgba.size());
   return m;
}

std::string background_message() {
   std::string m;
   put<std::uint8_t>(m, 4);
   for (float v : sv.background) put<float>(m, v);
   return m;
}

// Compression on now: always, never, or (auto) while the client has been the bottleneck in the last 5 s.
bool compressing() {
   if (sv.compress != 0) return sv.compress == 1;
   return sv.last_skip.time_since_epoch().count() != 0 &&
          std::chrono::steady_clock::now() - sv.last_skip < std::chrono::seconds(5);
}

// A message as sent: deflated (kind 6) when compression is on and it pays, else as it is.
std::string wire(const std::string &m) {
   if (m.size() < 1024 || !compressing()) return m;
   mz_ulong n = mz_compressBound(static_cast<mz_ulong>(m.size()));
   std::string z(1 + static_cast<size_t>(n), '\0');
   z[0] = 6;
   if (mz_compress2(reinterpret_cast<unsigned char *>(&z[1]), &n, reinterpret_cast<const unsigned char *>(m.data()),
                    static_cast<mz_ulong>(m.size()), 1) != MZ_OK || 1 + n >= m.size())
      return m;
   z.resize(1 + static_cast<size_t>(n));
   return z;
}

// A list's vertices in 12 bytes each, if every position fits in +-8191.75 pixels at 1/4 pixel and every uv in [0, 1].
bool compact_vertices(const ImDrawList *l, std::string &out) {
   const ImDrawVert *v = l->VtxBuffer.Data;
   const int n = l->VtxBuffer.Size;
   for (int i = 0; i < n; ++i)
      if (!(std::fabs(v[i].pos.x) <= 8191.75f && std::fabs(v[i].pos.y) <= 8191.75f && v[i].uv.x >= 0.0f &&
            v[i].uv.x <= 1.0f && v[i].uv.y >= 0.0f && v[i].uv.y <= 1.0f))
         return false;
   const size_t at = out.size();
   out.resize(at + 12u * static_cast<size_t>(n));
   char *p = &out[at];
   for (int i = 0; i < n; ++i, p += 12) {
      const std::int16_t x = static_cast<std::int16_t>(std::lround(v[i].pos.x * 4.0f));
      const std::int16_t y = static_cast<std::int16_t>(std::lround(v[i].pos.y * 4.0f));
      const std::uint16_t u = static_cast<std::uint16_t>(std::lround(v[i].uv.x * 65535.0f));
      const std::uint16_t w = static_cast<std::uint16_t>(std::lround(v[i].uv.y * 65535.0f));
      std::memcpy(p, &x, 2);
      std::memcpy(p + 2, &y, 2);
      std::memcpy(p + 4, &u, 2);
      std::memcpy(p + 6, &w, 2);
      std::memcpy(p + 8, &v[i].col, 4);
   }
   return true;
}

// A texture as a JPEG message (kind 8), at quality 75; empty if it has transparent pixels (JPEG has no alpha), if the
// encoder fails, or if the JPEG is not smaller than the raw pixels.
std::string jpeg_message(std::uint64_t id, const texture_t &t) {
   const size_t n = static_cast<size_t>(t.width) * static_cast<size_t>(t.height);
   for (size_t i = 0; i < n; ++i)
      if (t.rgba[4 * i + 3] != 255) return "";
   std::string m;
   m.reserve(17 + n / 8);
   put<std::uint8_t>(m, 8);
   put<std::uint32_t>(m, static_cast<std::uint32_t>(id));
   put<std::uint32_t>(m, static_cast<std::uint32_t>(t.width));
   put<std::uint32_t>(m, static_cast<std::uint32_t>(t.height));
   put<std::uint32_t>(m, t.linear ? 1u : 0u);
   if (!figure_image::encode_jpeg(m, t.width, t.height, 4, t.rgba.data(), 75) || m.size() >= 17 + 4 * n) return "";
   return m;
}

// Send a texture: as JPEG while it changes (a user texture updated in this frame and in the previous one, or one the
// client holds as JPEG already), else its exact pixels (kind 2, deflated when compression is on).
void send_texture(connection_t &c, std::uint64_t id, texture_t &t) {
   if (sv.lossy && t.user && t.updated == sv.frame && (t.moving || t.lossy)) {
      const std::string m = jpeg_message(id, t);
      if (!m.empty()) {
         ws_append(c, 2, m);
         t.lossy = true;
         t.dirty = false;
         return;
      }
   }
   ws_append(c, 2, wire(texture_message(id, t)));
   t.lossy = false;
   t.dirty = false;
}

// A texture is still once it has not changed for this long: a drag that misses a frame or two is still moving.
const std::chrono::milliseconds STILL(150);

// The exact pixels of every texture the client holds as JPEG, that `drawn` draws and that is still. Returns the time
// left until the next such texture is still (a negative count: none).
std::chrono::milliseconds send_still(connection_t &c, const std::set<std::uint64_t> &drawn) {
   const auto now = std::chrono::steady_clock::now();
   std::chrono::milliseconds next(-1);
   for (auto &t : sv.textures) {
      if (!t.second.lossy || t.second.updated == sv.frame || !drawn.count(t.first)) continue;
      const auto left = std::chrono::duration_cast<std::chrono::milliseconds>(t.second.changed + STILL - now);
      if (left.count() <= 0) send_texture(c, t.first, t.second);
      else if (next.count() < 0 || left < next) next = left;
   }
   return next;
}

void flush(connection_t &c) {
   while (!c.out.empty()) {
      const int n = static_cast<int>(send(c.s, c.out.data(), static_cast<int>(std::min<size_t>(c.out.size(), 1 << 20)), SEND_FLAGS));
      if (n > 0) {
         c.out.erase(0, static_cast<size_t>(n));
         if (c.websocket) sv.unsent_frame = static_cast<size_t>(n) >= sv.unsent_frame ? 0 : sv.unsent_frame - n;
      } else {
         if (n < 0 && would_block()) return; // the rest at the next serve/send
         close_socket(c.s);
         c.s = NO_SOCKET;
         return;
      }
   }
}

// ---- input from the client ------------------------------------------------------------------------------------------

ImGuiKey key_of(const std::string &code) {
   static const std::map<std::string, ImGuiKey> keys = {
      {"Tab", ImGuiKey_Tab}, {"ArrowLeft", ImGuiKey_LeftArrow}, {"ArrowRight", ImGuiKey_RightArrow},
      {"ArrowUp", ImGuiKey_UpArrow}, {"ArrowDown", ImGuiKey_DownArrow}, {"PageUp", ImGuiKey_PageUp},
      {"PageDown", ImGuiKey_PageDown}, {"Home", ImGuiKey_Home}, {"End", ImGuiKey_End}, {"Insert", ImGuiKey_Insert},
      {"Delete", ImGuiKey_Delete}, {"Backspace", ImGuiKey_Backspace}, {"Space", ImGuiKey_Space},
      {"Enter", ImGuiKey_Enter}, {"NumpadEnter", ImGuiKey_KeypadEnter}, {"Escape", ImGuiKey_Escape},
      {"ControlLeft", ImGuiKey_LeftCtrl}, {"ControlRight", ImGuiKey_RightCtrl}, {"ShiftLeft", ImGuiKey_LeftShift},
      {"ShiftRight", ImGuiKey_RightShift}, {"AltLeft", ImGuiKey_LeftAlt}, {"AltRight", ImGuiKey_RightAlt},
      {"MetaLeft", ImGuiKey_LeftSuper}, {"MetaRight", ImGuiKey_RightSuper},
      {"KeyA", ImGuiKey_A}, {"KeyC", ImGuiKey_C}, {"KeyV", ImGuiKey_V}, {"KeyX", ImGuiKey_X}, {"KeyY", ImGuiKey_Y},
      {"KeyZ", ImGuiKey_Z}};
   const auto k = keys.find(code);
   return k == keys.end() ? ImGuiKey_None : k->second;
}

void handle_event(const std::string &ev) {
   if (ev.size() < 2 || ev[1] != ':') return;
   ImGuiIO &io = ImGui::GetIO();
   const char *p = ev.c_str() + 2;
   float a = 0.0f, b = 0.0f;
   switch (ev[0]) {
   case 'm':
      if (std::sscanf(p, "%f,%f", &a, &b) == 2) io.AddMousePosEvent(a, b);
      break;
   case 'b': {
      int button = 0, down = 0;
      if (std::sscanf(p, "%d,%d", &button, &down) == 2 && button >= 0 && button < ImGuiMouseButton_COUNT)
         io.AddMouseButtonEvent(button, down != 0);
      break;
   }
   case 'w':
      if (std::sscanf(p, "%f,%f", &a, &b) == 2) io.AddMouseWheelEvent(a, b);
      break;
   case 'k': {
      const char *comma = std::strchr(p, ',');
      if (comma) {
         const bool down = *p == '1';
         const std::string code(comma + 1);
         const ImGuiKey key = key_of(code);
         if (key != ImGuiKey_None) io.AddKeyEvent(key, down);
         if (code == "ControlLeft" || code == "ControlRight") io.AddKeyEvent(ImGuiMod_Ctrl, down);
         if (code == "ShiftLeft" || code == "ShiftRight") io.AddKeyEvent(ImGuiMod_Shift, down);
         if (code == "AltLeft" || code == "AltRight") io.AddKeyEvent(ImGuiMod_Alt, down);
         if (code == "MetaLeft" || code == "MetaRight") io.AddKeyEvent(ImGuiMod_Super, down);
      }
      break;
   }
   case 'c':
      io.AddInputCharactersUTF8(p);
      break;
   case 'p': // the browser's clipboard, sent by the page on a paste (ctrl+v), before the key that pastes
      sv.clipboard.assign(ev, 2, std::string::npos);
      break;
   case 's':
      if (std::sscanf(p, "%f,%f", &a, &b) == 2 && a > 0.0f && b > 0.0f) io.DisplaySize = ImVec2(a, b);
      break;
   default:
      break;
   }
}

// Parse the complete WebSocket frames in c.in; true if an event arrived.
bool ws_read(connection_t &c) {
   bool got = false;
   for (;;) {
      if (c.in.size() < 2) return got;
      const unsigned char b0 = static_cast<unsigned char>(c.in[0]), b1 = static_cast<unsigned char>(c.in[1]);
      const int opcode = b0 & 0x0F;
      const bool masked = (b1 & 0x80) != 0;
      std::uint64_t n = b1 & 0x7F;
      size_t pos = 2;
      if (n == 126) {
         if (c.in.size() < 4) return got;
         n = (static_cast<unsigned char>(c.in[2]) << 8) | static_cast<unsigned char>(c.in[3]);
         pos = 4;
      } else if (n == 127) {
         if (c.in.size() < 10) return got;
         n = 0;
         for (int i = 0; i < 8; ++i) n = (n << 8) | static_cast<unsigned char>(c.in[2 + i]);
         pos = 10;
      }
      if (n > (1u << 20)) { // client messages are short events: anything else is not ours
         close_socket(c.s);
         c.s = NO_SOCKET;
         return got;
      }
      const size_t need = pos + (masked ? 4 : 0) + static_cast<size_t>(n);
      if (c.in.size() < need) return got;
      std::string payload = c.in.substr(pos + (masked ? 4 : 0), static_cast<size_t>(n));
      if (masked)
         for (size_t i = 0; i < payload.size(); ++i) payload[i] = static_cast<char>(payload[i] ^ c.in[pos + (i % 4)]);
      c.in.erase(0, need);
      if (opcode == 0x8) { // close
         ws_append(c, 0x8, "");
         flush(c);
         close_socket(c.s);
         c.s = NO_SOCKET;
         return true;
      }
      if (opcode == 0x9) { // ping
         ws_append(c, 0xA, payload);
      } else if (opcode == 0x1) { // text: one event
         handle_event(payload);
         got = true;
      }
   }
}

// 128 random bits as 32 hex digits, from the system's cryptographic generator; empty if it is unavailable.
std::string random_token() {
   unsigned char b[16];
#ifdef _WIN32
   for (int i = 0; i < 4; ++i) {
      unsigned int v;
      if (rand_s(&v) != 0) return "";
      std::memcpy(b + 4 * i, &v, 4);
   }
#else
   FILE *f = std::fopen("/dev/urandom", "rb");
   if (!f) return "";
   const size_t n = std::fread(b, 1, sizeof(b), f);
   std::fclose(f);
   if (n != sizeof(b)) return "";
#endif
   static const char *hex = "0123456789abcdef";
   std::string t;
   for (unsigned char v : b) {
      t += hex[v >> 4];
      t += hex[v & 15];
   }
   return t;
}

// The value of `name` in a query string ("a=1&token=x"), or empty.
std::string query_value(const std::string &query, const std::string &name) {
   size_t at = 0;
   while (at <= query.size()) {
      const size_t end = std::min(query.find('&', at), query.size());
      const std::string pair = query.substr(at, end - at);
      if (pair.compare(0, name.size() + 1, name + "=") == 0) return pair.substr(name.size() + 1);
      at = end + 1;
   }
   return "";
}

// Whether `given` is the token, in a time that does not depend on where they differ.
bool token_ok(const std::string &given) {
   if (sv.token.empty()) return true; // disabled by the program
   if (given.size() != sv.token.size()) return false;
   unsigned char diff = 0;
   for (size_t i = 0; i < given.size(); ++i) diff |= static_cast<unsigned char>(given[i] ^ sv.token[i]);
   return diff == 0;
}

// Answer an HTTP request in c.in, if complete; may turn the connection into the WebSocket client.
bool http_read(connection_t &c) {
   const size_t end = c.in.find("\r\n\r\n");
   if (end == std::string::npos) return false;
   const std::string req = c.in.substr(0, end);
   c.in.erase(0, end + 4);
   auto header = [&](const char *name) -> std::string {
      std::string lower = req;
      std::transform(lower.begin(), lower.end(), lower.begin(), [](unsigned char ch) { return std::tolower(ch); });
      std::string key = std::string("\r\n") + name + ":";
      const size_t at = lower.find(key);
      if (at == std::string::npos) return "";
      size_t from = at + key.size();
      const size_t to = req.find("\r\n", from);
      while (from < req.size() && req[from] == ' ') ++from;
      return req.substr(from, to == std::string::npos ? std::string::npos : to - from);
   };
   // request line: method, target (path and query)
   const size_t sp1 = req.find(' '), sp2 = sp1 == std::string::npos ? sp1 : req.find(' ', sp1 + 1);
   const std::string method = req.substr(0, sp1);
   const std::string target = sp2 == std::string::npos ? "" : req.substr(sp1 + 1, sp2 - sp1 - 1);
   const size_t qm = target.find('?');
   const std::string path = target.substr(0, qm);
   const std::string query = qm == std::string::npos ? "" : target.substr(qm + 1);
   const bool allowed = token_ok(query_value(query, "token"));
   const bool ws = method == "GET" && path == "/ws" && !header("sec-websocket-key").empty();
   const bool page = method == "GET" && (path == "/" || path == "/index.html");
   if ((ws || page) && !allowed) {
      const std::string body = "FIGURE: this address needs the program's access token: open the address the program "
                               "printed, with its ?token=...\n";
      c.out += "HTTP/1.1 403 Forbidden\r\nContent-Type: text/plain; charset=utf-8\r\nCache-Control: no-store\r\n"
               "Connection: close\r\nContent-Length: " + std::to_string(body.size()) + "\r\n\r\n" + body;
      c.close_after = true;
      flush(c);
      return false;
   }
   if (ws) {
      for (auto &o : sv.conns) // one client: the newest replaces the previous one
         if (o.websocket && o.s != NO_SOCKET && &o != &c) {
            close_socket(o.s);
            o.s = NO_SOCKET;
         }
      const std::string accept_key = base64(sha1(header("sec-websocket-key") + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"));
      c.out += "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
               "Sec-WebSocket-Accept: " + accept_key + "\r\n\r\n";
      c.websocket = true;
      sv.resend = true;
      return true;
   }
   const std::string body = page ? std::string(client_html) : std::string("not found\n");
   c.out += std::string(page ? "HTTP/1.1 200 OK\r\n" : "HTTP/1.1 404 Not Found\r\n") +
            (page ? "Content-Type: text/html; charset=utf-8\r\n" : "Content-Type: text/plain\r\n") +
            "Cache-Control: no-store\r\nConnection: close\r\nContent-Length: " + std::to_string(body.size()) +
            "\r\n\r\n" + body;
   c.close_after = true; // one request per connection, closed once the answer is out
   flush(c);
   return false;
}

} // namespace

namespace figure_remote {

bool start(const std::string &host, int port, int &bound_port, std::string &err) {
   sv.token = random_token();
   if (sv.token.empty()) {
      err = "cannot make the access token: the system's random generator is unavailable";
      return false;
   }
#ifdef _WIN32
   if (!winsock::load()) { err = "cannot load Winsock (ws2_32.dll)"; return false; }
   if (!sv.wsa) {
      WSADATA data;
      if (WSAStartup(MAKEWORD(2, 2), &data) != 0) { err = "WSAStartup failed"; return false; }
      sv.wsa = true;
   }
#endif
   addrinfo hints{}, *res = nullptr;
   hints.ai_family = AF_INET;
   hints.ai_socktype = SOCK_STREAM;
   hints.ai_flags = AI_PASSIVE;
   if (getaddrinfo(host.empty() ? nullptr : host.c_str(), std::to_string(port).c_str(), &hints, &res) != 0 || !res) {
      err = "cannot resolve the address " + host;
      return false;
   }
   sv.listener = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
   if (sv.listener == NO_SOCKET) { freeaddrinfo(res); err = "socket() failed"; return false; }
   int yes = 1;
   setsockopt(sv.listener, SOL_SOCKET, SO_REUSEADDR, reinterpret_cast<const char *>(&yes), sizeof(yes));
   const bool ok = bind(sv.listener, res->ai_addr, static_cast<int>(res->ai_addrlen)) == 0 && listen(sv.listener, 8) == 0;
   freeaddrinfo(res);
   if (!ok) {
      close_socket(sv.listener);
      sv.listener = NO_SOCKET;
      err = "cannot listen on " + host + ":" + std::to_string(port) + " (port in use?)";
      return false;
   }
   set_nonblocking(sv.listener);
   if (!open_wake(err)) {
      close_socket(sv.listener);
      sv.listener = NO_SOCKET;
      return false;
   }
   sockaddr_in addr{};
   socklen_t len = sizeof(addr);
   getsockname(sv.listener, reinterpret_cast<sockaddr *>(&addr), &len);
   const unsigned char *pb = reinterpret_cast<const unsigned char *>(&addr.sin_port); // network order: big-endian
   bound_port = (pb[0] << 8) | pb[1];
   return true;
}

void stop() {
   // the client gets what is queued (the last frames) and a close frame, within 2 s, before the sockets close
   if (connection_t *c = client()) ws_append(*c, 0x8, "");
   const auto end = std::chrono::steady_clock::now() + std::chrono::seconds(2);
   for (auto &c : sv.conns) {
      while (c.s != NO_SOCKET && !c.out.empty() && std::chrono::steady_clock::now() < end) {
         fd_set wr;
         FD_ZERO(&wr);
         FD_SET(c.s, &wr);
         timeval tv{0, 100000};
         if (select(static_cast<int>(c.s + 1), nullptr, &wr, nullptr, &tv) > 0) flush(c);
      }
   }
   for (auto &c : sv.conns)
      if (c.s != NO_SOCKET) close_socket(c.s);
   if (sv.listener != NO_SOCKET) close_socket(sv.listener);
   close_wake();
   sv = server_t{};
}

bool serve_once(int timeout_ms) {
   if (sv.listener == NO_SOCKET) return false;
   fd_set rd, wr;
   FD_ZERO(&rd);
   FD_ZERO(&wr);
   FD_SET(sv.listener, &rd);
   socket_t maxfd = sv.listener;
   const socket_t wk = wake_socket; // set and closed by start and stop, on this thread
   if (wk != NO_SOCKET) {
      FD_SET(wk, &rd);
      maxfd = std::max(maxfd, wk);
   }
   for (auto &c : sv.conns) {
      if (c.s == NO_SOCKET) continue;
      FD_SET(c.s, &rd);
      if (!c.out.empty()) FD_SET(c.s, &wr);
      maxfd = std::max(maxfd, c.s);
   }
   timeval tv{timeout_ms / 1000, (timeout_ms % 1000) * 1000};
   if (select(static_cast<int>(maxfd + 1), &rd, &wr, nullptr, &tv) <= 0) return false;
   bool got = false;
   if (wk != NO_SOCKET && FD_ISSET(wk, &rd)) { // woken: drain the datagrams, draw a frame
      char buf[64];
      while (recv(wk, buf, sizeof(buf), 0) > 0) {
      }
      got = true;
   }
   if (FD_ISSET(sv.listener, &rd)) {
      for (;;) {
         const socket_t s = accept(sv.listener, nullptr, nullptr);
         if (s == NO_SOCKET) break;
         set_nonblocking(s);
         int one = 1;
         setsockopt(s, IPPROTO_TCP, TCP_NODELAY, reinterpret_cast<const char *>(&one), sizeof(one));
#ifdef SO_NOSIGPIPE
         setsockopt(s, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));
#endif
         connection_t c;
         c.s = s;
         sv.conns.push_back(c);
      }
   }
   for (auto &c : sv.conns) {
      if (c.s == NO_SOCKET) continue;
      if (FD_ISSET(c.s, &rd)) {
         char buf[16384];
         for (;;) {
            const int n = static_cast<int>(recv(c.s, buf, sizeof(buf), 0));
            if (n > 0) {
               c.in.append(buf, static_cast<size_t>(n));
               continue;
            }
            if (n < 0 && would_block()) break;
            close_socket(c.s); // closed by the peer
            c.s = NO_SOCKET;
            got = true;
            break;
         }
         if (c.s != NO_SOCKET) got = (c.websocket ? ws_read(c) : http_read(c)) || got;
      }
      if (c.s != NO_SOCKET && !c.out.empty()) flush(c);
      if (c.s != NO_SOCKET && c.close_after && c.out.empty()) {
         close_socket(c.s);
         c.s = NO_SOCKET;
      }
   }
   sv.conns.erase(std::remove_if(sv.conns.begin(), sv.conns.end(), [](const connection_t &c) { return c.s == NO_SOCKET; }),
                  sv.conns.end());
   return got;
}

bool serve(int timeout_ms) {
   // one select at a time until input arrives, a skipped frame can go out, or the time is up: a socket that only
   // became writable (queued output draining) must not end the wait early
   const auto end = std::chrono::steady_clock::now() + std::chrono::milliseconds(timeout_ms);
   for (;;) {
      // a texture the client holds as JPEG became still while the program waits (no frame follows its last change):
      // the page gets its exact pixels, and redraws its last frame with them; the wait ends when the next one is still
      int still = -1;
      if (connection_t *c = client(); c && sv.unsent_frame == 0) {
         still = static_cast<int>(send_still(*c, sv.drawn).count());
         flush(*c);
      }
      const int left = static_cast<int>(
         std::chrono::duration_cast<std::chrono::milliseconds>(end - std::chrono::steady_clock::now()).count());
      const bool was_busy = sv.unsent_frame > 0;
      if (serve_once(std::max(still >= 0 ? std::min(left, still + 1) : left, 0))) return true;
      if (sv.pending && was_busy && sv.unsent_frame == 0) return true; // the latest frame can be sent now
      if (left <= 0) return false;
   }
}

void wake() {
   std::lock_guard<std::mutex> lock(wake_mutex);
   if (wake_socket != NO_SOCKET) send(wake_socket, "w", 1, SEND_FLAGS);
}

bool frame_pending() { return sv.pending; }

bool queue_busy() { return sv.unsent_frame > 0; }

void set_compression(int mode) { sv.compress = mode; }

void set_lossy(bool on) { sv.lossy = on; }

void set_token(const std::string &token) { sv.token = token; }

const std::string &token() { return sv.token; }

std::uint64_t new_texture_id() { return sv.next_id++; }

void set_clipboard(const char *text) {
   sv.clipboard = text ? text : "";
   if (connection_t *c = client()) { // the page writes it to the browser's clipboard, where the browser allows it
      std::string m(1, '\x07');
      m += sv.clipboard;
      ws_append(*c, 2, m);
   }
}

const char *clipboard() { return sv.clipboard.c_str(); }

void open_url(const char *url) {
   if (connection_t *c = client()) { // the page opens it in a new tab, where the browser allows it
      std::string m(1, '\x09');
      m += url ? url : "";
      ws_append(*c, 2, m);
   }
}

void set_background(float r, float g, float b) {
   sv.background[0] = r;
   sv.background[1] = g;
   sv.background[2] = b;
   if (connection_t *c = client()) ws_append(*c, 2, background_message());
}

namespace {

// Keep a texture's pixels, to be sent with the next frame that goes out (send_frame).
void keep_texture(std::uint64_t id, int width, int height, const unsigned char *rgba, bool linear, bool user) {
   texture_t &t = sv.textures[id];
   t.moving = !t.rgba.empty() && t.updated + 1 >= sv.frame; // updated in this frame or the previous one too
   t.width = width;
   t.height = height;
   t.linear = linear;
   t.user = user;
   t.dirty = true;
   t.updated = sv.frame;
   t.changed = std::chrono::steady_clock::now();
   t.rgba.assign(rgba, rgba + static_cast<size_t>(width) * static_cast<size_t>(height) * 4u);
}

} // namespace

void texture_update(std::uint64_t id, int width, int height, const unsigned char *rgba, bool linear) {
   keep_texture(id, width, height, rgba, linear, true);
}

bool texture_pixels(std::uint64_t id, figure_swrast::texture_t *t) {
   const auto it = sv.textures.find(id);
   if (it == sv.textures.end() || it->second.rgba.empty()) return false;
   t->width = it->second.width, t->height = it->second.height, t->channels = 4;
   t->pixels = it->second.rgba.data(), t->smooth = it->second.linear;
   return true;
}

void texture_destroy(std::uint64_t id) {
   if (sv.textures.erase(id) == 0) return;
   if (connection_t *c = client()) {
      std::string m;
      put<std::uint8_t>(m, 3);
      put<std::uint32_t>(m, static_cast<std::uint32_t>(id));
      ws_append(*c, 2, m);
   }
}

namespace {

// The frame's textures, then the frame (send_frame without the frame count).
void send_frame_body(ImDrawData *dd) {
   // Dear ImGui's own textures (font atlas): keep RGBA copies, whether or not a client is connected
   for (ImTextureData *t : ImGui::GetPlatformIO().Textures) {
      if (t->Status == ImTextureStatus_WantCreate || t->Status == ImTextureStatus_WantUpdates) {
         if (t->TexID == ImTextureID_Invalid) t->SetTexID(static_cast<ImTextureID>(new_texture_id()));
         const unsigned char *px = static_cast<const unsigned char *>(t->GetPixels());
         std::vector<unsigned char> rgba(static_cast<size_t>(t->Width) * static_cast<size_t>(t->Height) * 4u);
         if (t->Format == ImTextureFormat_Alpha8) {
            for (size_t i = 0; i < static_cast<size_t>(t->Width) * static_cast<size_t>(t->Height); ++i) {
               rgba[4 * i] = rgba[4 * i + 1] = rgba[4 * i + 2] = 255;
               rgba[4 * i + 3] = px[i];
            }
         } else {
            std::memcpy(rgba.data(), px, rgba.size());
         }
         keep_texture(static_cast<std::uint64_t>(t->TexID), t->Width, t->Height, rgba.data(), true, false); // atlas
         t->SetStatus(ImTextureStatus_OK);
      } else if (t->Status == ImTextureStatus_WantDestroy) {
         texture_destroy(static_cast<std::uint64_t>(t->TexID));
         t->SetTexID(ImTextureID_Invalid);
         t->SetStatus(ImTextureStatus_Destroyed);
      }
   }
   connection_t *c = client();
   if (!c) return;
   if (sv.resend) { // a new client: the background and every live texture first, exact
      ws_append(*c, 2, background_message());
      for (auto &t : sv.textures) {
         ws_append(*c, 2, wire(texture_message(t.first, t.second)));
         t.second.dirty = t.second.lossy = false;
      }
      sv.resend = false;
      sv.last_frame.clear(); // the new client has no frame yet
      sv.unsent_frame = 0;
      sv.pending = false;
   }
   if (sv.unsent_frame > 0) { // the previous frame is still queued: skip this one, the next (latest) goes instead
      sv.pending = true;
      sv.last_skip = std::chrono::steady_clock::now();
      flush(*c);
      return;
   }
   // the textures this frame draws; then the ones updated since the last frame sent (their latest pixels), and the
   // exact pixels of those the client holds as JPEG that this frame draws without updating them
   std::set<std::uint64_t> drawn;
   for (const ImDrawList *l : dd->CmdLists)
      for (const ImDrawCmd &cmd : l->CmdBuffer)
         if (cmd.UserCallback == nullptr) drawn.insert(static_cast<std::uint64_t>(cmd.GetTexID()));
   for (auto &t : sv.textures)
      if (t.second.dirty) send_texture(*c, t.first, t.second);
   send_still(*c, drawn);
   sv.drawn = std::move(drawn);
   std::string m;
   put<std::uint8_t>(m, 1);
   put<float>(m, dd->DisplaySize.x);
   put<float>(m, dd->DisplaySize.y);
   put<std::uint32_t>(m, static_cast<std::uint32_t>(dd->CmdLists.Size));
   for (const ImDrawList *l : dd->CmdLists) {
      std::uint32_t ncmd = 0;
      for (const ImDrawCmd &cmd : l->CmdBuffer)
         if (cmd.UserCallback == nullptr) ++ncmd; // callbacks (texture sampling) have no meaning in the browser
      put<std::uint32_t>(m, static_cast<std::uint32_t>(l->VtxBuffer.Size));
      put<std::uint32_t>(m, static_cast<std::uint32_t>(l->IdxBuffer.Size));
      put<std::uint32_t>(m, ncmd);
      const size_t flags_at = m.size();
      put<std::uint32_t>(m, 0u);
      if (compact_vertices(l, m)) {
         const std::uint32_t compact = 1u;
         std::memcpy(&m[flags_at], &compact, 4);
      } else {
         m.append(reinterpret_cast<const char *>(l->VtxBuffer.Data), static_cast<size_t>(l->VtxBuffer.Size) * sizeof(ImDrawVert));
      }
      m.append(reinterpret_cast<const char *>(l->IdxBuffer.Data), static_cast<size_t>(l->IdxBuffer.Size) * sizeof(ImDrawIdx));
      if (l->IdxBuffer.Size % 2) put<std::uint16_t>(m, 0); // keep the commands 4-byte aligned
      for (const ImDrawCmd &cmd : l->CmdBuffer) {
         if (cmd.UserCallback != nullptr) continue;
         put<float>(m, cmd.ClipRect.x - dd->DisplayPos.x);
         put<float>(m, cmd.ClipRect.y - dd->DisplayPos.y);
         put<float>(m, cmd.ClipRect.z - dd->DisplayPos.x);
         put<float>(m, cmd.ClipRect.w - dd->DisplayPos.y);
         put<std::uint32_t>(m, static_cast<std::uint32_t>(cmd.GetTexID()));
         put<std::uint32_t>(m, cmd.IdxOffset);
         put<std::uint32_t>(m, cmd.ElemCount);
         put<std::uint32_t>(m, cmd.VtxOffset);
      }
   }
   const auto now = std::chrono::steady_clock::now();
   if (m == sv.last_frame) { // nothing changed since the last frame sent: skip it, say so once per second
      if (now - sv.last_sent >= std::chrono::seconds(1)) {
         ws_append(*c, 2, std::string(1, '\x05'));
         sv.last_sent = now;
      }
      sv.pending = false;
      flush(*c);
      return;
   }
   ws_append(*c, 2, wire(m));
   sv.unsent_frame = c->out.size(); // the frame ends the queue: sent once the queue empties up to its end
   sv.pending = false;
   sv.last_frame = std::move(m);
   sv.last_sent = now;
   flush(*c);
}

} // namespace

void send_frame(ImDrawData *dd) {
   send_frame_body(dd);
   ++sv.frame; // updates from now on belong to the next frame
}

} // namespace figure_remote

// The C ABI of set_lossy (figure_native.h), beside the server it sets.
extern "C" void fig_set_remote_lossy(int on) { figure_remote::set_lossy(on != 0); }
