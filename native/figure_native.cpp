// FIGURE native glue: SDL3 window + OpenGL3 renderer + Dear ImGui/ImPlot contexts, behind the C ABI of figure_native.h.
#include "figure_native.h"

#include "imgui.h"
#include "imgui_impl_opengl3.h"
#include "imgui_impl_sdl3.h"
#include "implot.h"

#include <SDL3/SDL.h>
// The program's main is the Fortran one, not SDL_main: SDL_MAIN_HANDLED keeps SDL_main.h from redefining main, and
// fig_init declares the entry point ready (SDL_SetMainReady) before SDL_Init, as SDL documents for this case.
#define SDL_MAIN_HANDLED
#include <SDL3/SDL_main.h>

#include <cstdio>
#include <cstdlib>
#include <exception>
#include <map>
#include <string>

namespace {

std::string last_error;

int fail(int status, const std::string &msg) {
   last_error = msg;
   return status;
}

#define FIG_TRY try {
#define FIG_CATCH                                                                                                      \
   }                                                                                                                   \
   catch (const std::exception &e) {                                                                                  \
      return fail(FIG_ERR_EXCEPTION, std::string("C++ exception: ") + e.what());                                      \
   }                                                                                                                   \
   catch (...) {                                                                                                       \
      return fail(FIG_ERR_EXCEPTION, "unknown C++ exception");                                                        \
   }

enum class mode { none, window, headless };

struct state_t {
   mode          m = mode::none;
   SDL_Window   *window = nullptr;
   SDL_GLContext gl = nullptr;
   bool          in_frame = false;
   bool          lazy = true;     // wait for events instead of redrawing continuously
   int           max_wait_ms = 500;
   int           frames_left = 3; // frames still to draw after the last event (ImGui settles in a few)
   float         scale = 1.0f;
   std::string   ini_file;        // where Dear ImGui keeps window positions and sizes; empty: nowhere (the default)
   struct texture_t {
      int width = 0, height = 0;
   };
   std::map<unsigned long long, texture_t> textures; // user textures by ImTextureID (the GL name in window mode)
   unsigned long long next_headless_texture = 1;     // headless mode: ids without GL objects
} st;

// Redraw diagnostics, enabled by the environment variable FIGURE_DEBUG_REDRAW (any value): once per second, print to
// stderr the frames drawn, the wakeups by timeout, the events by SDL type, and the time spent waiting, building the
// UI (application code between begin and end), rendering and swapping. Costs nothing when disabled.
struct redraw_stats_t {
   bool                 on = false;
   Uint64               t0 = 0;       // start of the current 1 s window [ns]
   Uint64               t_mark = 0;   // last phase boundary [ns]
   Uint64               wait = 0;     // in SDL_WaitEventTimeout/SDL_PollEvent [ns]
   Uint64               build = 0;    // begin_frame to after ImGui::Render: application + ImGui calls [ns]
   Uint64               render = 0;   // GL draw of the ImGui draw data [ns]
   Uint64               swap = 0;     // SDL_GL_SwapWindow [ns]
   int                  frames = 0;   // frames drawn
   int                  timeouts = 0; // waits that ended without an event
   std::map<Uint32, int> events;      // events by SDL_EventType
} rs;

void redraw_stats_flush(Uint64 now) {
   if (now - rs.t0 < SDL_NS_PER_SECOND) return;
   const double ms = 1.0e-6, span = static_cast<double>(now - rs.t0) * 1.0e-9;
   std::fprintf(stderr, "figure redraw: %.2f s frames=%d timeouts=%d wait=%.1fms build=%.1fms render=%.1fms swap=%.1fms events:",
                span, rs.frames, rs.timeouts, rs.wait * ms, rs.build * ms, rs.render * ms, rs.swap * ms);
   for (const auto &e : rs.events) std::fprintf(stderr, " 0x%x=%d", e.first, e.second);
   std::fprintf(stderr, "\n");
   const bool on = rs.on;
   rs = redraw_stats_t{};
   rs.on = on;
   rs.t0 = now;
   rs.t_mark = now;
}

// The GL calls the glue makes itself (frame clear, user textures), loaded through SDL: no link-time dependency on
// libGL/opengl32.
typedef void (*gl_viewport_t)(int, int, int, int);
typedef void (*gl_clear_color_t)(float, float, float, float);
typedef void (*gl_clear_t)(unsigned int);
gl_viewport_t    p_glViewport = nullptr;
gl_clear_color_t p_glClearColor = nullptr;
gl_clear_t       p_glClear = nullptr;
constexpr unsigned int GL_COLOR_BUFFER_BIT_ = 0x00004000;
typedef void (*gl_gen_textures_t)(int, unsigned int *);
typedef void (*gl_delete_textures_t)(int, const unsigned int *);
typedef void (*gl_bind_texture_t)(unsigned int, unsigned int);
typedef void (*gl_tex_parameteri_t)(unsigned int, unsigned int, int);
typedef void (*gl_tex_image_2d_t)(unsigned int, int, int, int, int, int, unsigned int, unsigned int, const void *);
typedef void (*gl_tex_sub_image_2d_t)(unsigned int, int, int, int, int, int, unsigned int, unsigned int, const void *);
typedef void (*gl_pixel_storei_t)(unsigned int, int);
gl_gen_textures_t     p_glGenTextures = nullptr;
gl_delete_textures_t  p_glDeleteTextures = nullptr;
gl_bind_texture_t     p_glBindTexture = nullptr;
gl_tex_parameteri_t   p_glTexParameteri = nullptr;
gl_tex_image_2d_t     p_glTexImage2D = nullptr;
gl_tex_sub_image_2d_t p_glTexSubImage2D = nullptr;
gl_pixel_storei_t     p_glPixelStorei = nullptr;
constexpr unsigned int GL_TEXTURE_2D_ = 0x0DE1, GL_TEXTURE_MAG_FILTER_ = 0x2800, GL_TEXTURE_MIN_FILTER_ = 0x2801;
constexpr unsigned int GL_TEXTURE_WRAP_S_ = 0x2802, GL_TEXTURE_WRAP_T_ = 0x2803, GL_CLAMP_TO_EDGE_ = 0x812F;
constexpr unsigned int GL_NEAREST_ = 0x2600, GL_LINEAR_ = 0x2601, GL_RGBA_ = 0x1908, GL_UNSIGNED_BYTE_ = 0x1401;
constexpr unsigned int GL_UNPACK_ROW_LENGTH_ = 0x0CF2, GL_UNPACK_ALIGNMENT_ = 0x0CF5;

void create_contexts() {
   IMGUI_CHECKVERSION();
   ImGui::CreateContext();
   ImPlot::CreateContext();
   ImGuiIO &io = ImGui::GetIO();
   // No docking: the pinned cimgui tag (1.93dock) is generated from the non-docking Dear ImGui (see plans/plan.md).
   io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
   // No imgui.ini by default: a layout restored from whatever directory the program runs in silently overrides the
   // positions and sizes the program sets on first use. fig_set_ini_file opts in.
   io.IniFilename = nullptr;
   ImGui::StyleColorsDark();
}

void destroy_contexts() {
   if (ImPlot::GetCurrentContext()) ImPlot::DestroyContext();
   if (ImGui::GetCurrentContext()) ImGui::DestroyContext();
}

// Headless renderer: acknowledge texture requests (font atlas pages) without a GPU, as a real backend would.
void headless_textures() {
   for (ImTextureData *t : ImGui::GetPlatformIO().Textures) {
      if (t->Status == ImTextureStatus_WantCreate || t->Status == ImTextureStatus_WantUpdates) {
         t->SetTexID(static_cast<ImTextureID>(1));
         t->SetStatus(ImTextureStatus_OK);
      } else if (t->Status == ImTextureStatus_WantDestroy) {
         t->SetTexID(ImTextureID_Invalid);
         t->SetStatus(ImTextureStatus_Destroyed);
      }
   }
}

} // namespace

extern "C" {

const char *fig_last_error(int *len) {
   *len = static_cast<int>(last_error.size());
   return last_error.c_str();
}

void fig_set_last_error(const char *msg, int msg_len) {
   try {
      last_error.assign(msg, msg_len > 0 ? static_cast<size_t>(msg_len) : 0);
   } catch (...) {
   }
}

int fig_init(const char *title, int title_len, int width, int height, int vsync) {
   FIG_TRY
   if (st.m != mode::none) return fail(FIG_ERR_STATE, "figure is already initialized");
   if (width <= 0 || height <= 0) return fail(FIG_ERR_ARGUMENT, "window size must be positive");
   SDL_SetMainReady();
   if (!SDL_Init(SDL_INIT_VIDEO)) return fail(FIG_ERR_FAILED, std::string("SDL_Init: ") + SDL_GetError());
#if defined(__APPLE__)
   const char *glsl = "#version 150";
   SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_FORWARD_COMPATIBLE_FLAG);
   SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
   SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
   SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
#else
   const char *glsl = "#version 130";
   SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, 0);
   SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
   SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
   SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
#endif
   SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
   SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 0);
   SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, 8);
   st.scale = SDL_GetDisplayContentScale(SDL_GetPrimaryDisplay());
   if (st.scale <= 0.0f) st.scale = 1.0f;
   const std::string t(title, title_len > 0 ? static_cast<size_t>(title_len) : 0);
   const SDL_WindowFlags flags =
      SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIDDEN | SDL_WINDOW_HIGH_PIXEL_DENSITY;
   st.window = SDL_CreateWindow(t.c_str(), static_cast<int>(width * st.scale), static_cast<int>(height * st.scale), flags);
   if (!st.window) {
      SDL_Quit();
      return fail(FIG_ERR_FAILED, std::string("SDL_CreateWindow: ") + SDL_GetError());
   }
   st.gl = SDL_GL_CreateContext(st.window);
   if (!st.gl) {
      SDL_DestroyWindow(st.window);
      SDL_Quit();
      return fail(FIG_ERR_FAILED, std::string("SDL_GL_CreateContext: ") + SDL_GetError());
   }
   SDL_GL_MakeCurrent(st.window, st.gl);
   SDL_GL_SetSwapInterval(vsync ? 1 : 0);
   p_glViewport = reinterpret_cast<gl_viewport_t>(SDL_GL_GetProcAddress("glViewport"));
   p_glClearColor = reinterpret_cast<gl_clear_color_t>(SDL_GL_GetProcAddress("glClearColor"));
   p_glClear = reinterpret_cast<gl_clear_t>(SDL_GL_GetProcAddress("glClear"));
   p_glGenTextures = reinterpret_cast<gl_gen_textures_t>(SDL_GL_GetProcAddress("glGenTextures"));
   p_glDeleteTextures = reinterpret_cast<gl_delete_textures_t>(SDL_GL_GetProcAddress("glDeleteTextures"));
   p_glBindTexture = reinterpret_cast<gl_bind_texture_t>(SDL_GL_GetProcAddress("glBindTexture"));
   p_glTexParameteri = reinterpret_cast<gl_tex_parameteri_t>(SDL_GL_GetProcAddress("glTexParameteri"));
   p_glTexImage2D = reinterpret_cast<gl_tex_image_2d_t>(SDL_GL_GetProcAddress("glTexImage2D"));
   p_glTexSubImage2D = reinterpret_cast<gl_tex_sub_image_2d_t>(SDL_GL_GetProcAddress("glTexSubImage2D"));
   p_glPixelStorei = reinterpret_cast<gl_pixel_storei_t>(SDL_GL_GetProcAddress("glPixelStorei"));
   SDL_SetWindowPosition(st.window, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED);
   SDL_ShowWindow(st.window);

   create_contexts();
   ImGuiStyle &style = ImGui::GetStyle();
   style.ScaleAllSizes(st.scale);
   style.FontScaleDpi = st.scale;
   ImGui_ImplSDL3_InitForOpenGL(st.window, st.gl);
   ImGui_ImplOpenGL3_Init(glsl);
   st.m = mode::window;
   st.frames_left = 3;
   rs = redraw_stats_t{};
   rs.on = std::getenv("FIGURE_DEBUG_REDRAW") != nullptr;
   rs.t0 = rs.t_mark = SDL_GetTicksNS();
   return FIG_OK;
   FIG_CATCH
}

int fig_init_headless(int width, int height) {
   FIG_TRY
   if (st.m != mode::none) return fail(FIG_ERR_STATE, "figure is already initialized");
   if (width <= 0 || height <= 0) return fail(FIG_ERR_ARGUMENT, "display size must be positive");
   create_contexts();
   ImGuiIO &io = ImGui::GetIO();
   io.DisplaySize = ImVec2(static_cast<float>(width), static_cast<float>(height));
   io.BackendFlags |= ImGuiBackendFlags_RendererHasTextures;
   st.m = mode::headless;
   return FIG_OK;
   FIG_CATCH
}

int fig_set_ini_file(const char *path, int path_len) {
   FIG_TRY
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (ImGui::GetFrameCount() > 0) return fail(FIG_ERR_STATE, "the ini file must be set before the first frame");
   st.ini_file.assign(path, path_len > 0 ? static_cast<size_t>(path_len) : 0);
   ImGui::GetIO().IniFilename = st.ini_file.empty() ? nullptr : st.ini_file.c_str();
   return FIG_OK;
   FIG_CATCH
}

void fig_set_lazy(int enabled, double max_wait_s) {
   st.lazy = enabled != 0;
   st.max_wait_ms = max_wait_s > 0.0 ? static_cast<int>(max_wait_s * 1000.0) : 0;
}

void fig_request_frames(int n) {
   if (n > st.frames_left) st.frames_left = n;
}

double fig_content_scale(void) { return st.scale; }

int fig_begin_frame(int *running) {
   FIG_TRY
   *running = 0;
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (st.in_frame) return fail(FIG_ERR_STATE, "begin_frame called twice without end_frame");
   *running = 1;
   if (st.m == mode::headless) {
      ImGui::GetIO().DeltaTime = 1.0f / 60.0f;
      ImGui::NewFrame();
      st.in_frame = true;
      return FIG_OK;
   }
   SDL_Event ev;
   bool      got = false;
   if (rs.on) {
      const Uint64 now = SDL_GetTicksNS();
      redraw_stats_flush(now);
      rs.t_mark = now;
   }
   auto handle = [&](const SDL_Event &e) {
      if (rs.on) ++rs.events[e.type];
      ImGui_ImplSDL3_ProcessEvent(&e);
      if (e.type == SDL_EVENT_QUIT) *running = 0;
      if (e.type == SDL_EVENT_WINDOW_CLOSE_REQUESTED && e.window.windowID == SDL_GetWindowID(st.window)) *running = 0;
      got = true;
   };
   // Lazy redraw: once ImGui has settled, sleep until an event arrives or max_wait elapses (a periodic refresh that
   // lets live data from the application appear); never spin at the display rate while idle.
   if (st.lazy && st.frames_left <= 0) {
      if (SDL_WaitEventTimeout(&ev, st.max_wait_ms))
         handle(ev);
      else if (rs.on)
         ++rs.timeouts;
   }
   while (SDL_PollEvent(&ev)) handle(ev);
   if (!*running) return FIG_OK; // quitting: no frame is opened
   if (got) st.frames_left = 3;
   else if (st.frames_left > 0) --st.frames_left;
   if (SDL_GetWindowFlags(st.window) & SDL_WINDOW_MINIMIZED) SDL_Delay(10);
   if (rs.on) {
      const Uint64 now = SDL_GetTicksNS();
      rs.wait += now - rs.t_mark;
      rs.t_mark = now;
   }
   ImGui_ImplOpenGL3_NewFrame();
   ImGui_ImplSDL3_NewFrame();
   ImGui::NewFrame();
   st.in_frame = true;
   return FIG_OK;
   FIG_CATCH
}

int fig_end_frame(void) {
   FIG_TRY
   if (!st.in_frame) return fail(FIG_ERR_STATE, "end_frame without begin_frame");
   st.in_frame = false;
   ImGui::Render();
   if (st.m == mode::headless) {
      headless_textures();
      return FIG_OK;
   }
   Uint64 t_render = 0;
   if (rs.on) {
      t_render = SDL_GetTicksNS();
      rs.build += t_render - rs.t_mark;
   }
   const ImGuiIO &io = ImGui::GetIO();
   p_glViewport(0, 0, static_cast<int>(io.DisplaySize.x * io.DisplayFramebufferScale.x),
                static_cast<int>(io.DisplaySize.y * io.DisplayFramebufferScale.y));
   p_glClearColor(0.10f, 0.10f, 0.11f, 1.0f);
   p_glClear(GL_COLOR_BUFFER_BIT_);
   ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
   Uint64 t_swap = 0;
   if (rs.on) t_swap = SDL_GetTicksNS();
   SDL_GL_SwapWindow(st.window);
   if (rs.on) {
      const Uint64 now = SDL_GetTicksNS();
      rs.render += t_swap - t_render;
      rs.swap += now - t_swap;
      ++rs.frames;
   }
   return FIG_OK;
   FIG_CATCH
}

void fig_shutdown(void) {
   try {
      if (st.in_frame) {
         ImGui::EndFrame();
         st.in_frame = false;
      }
      if (st.m == mode::window) {
         for (const auto &t : st.textures) {
            const unsigned int name = static_cast<unsigned int>(t.first);
            p_glDeleteTextures(1, &name);
         }
         ImGui_ImplOpenGL3_Shutdown();
         ImGui_ImplSDL3_Shutdown();
      }
      destroy_contexts();
      if (st.m == mode::window) {
         SDL_GL_DestroyContext(st.gl);
         SDL_DestroyWindow(st.window);
         SDL_Quit();
      }
   } catch (...) {
   }
   st = state_t{};
}

int fig_texture_create(int width, int height, int smooth, unsigned long long *id) {
   FIG_TRY
   *id = 0;
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   if (width <= 0 || height <= 0) return fail(FIG_ERR_ARGUMENT, "texture size must be positive");
   if (st.m == mode::headless) {
      *id = st.next_headless_texture++;
   } else {
      unsigned int name = 0;
      p_glGenTextures(1, &name);
      if (name == 0) return fail(FIG_ERR_FAILED, "glGenTextures returned no texture");
      p_glBindTexture(GL_TEXTURE_2D_, name);
      const int filter = static_cast<int>(smooth ? GL_LINEAR_ : GL_NEAREST_);
      p_glTexParameteri(GL_TEXTURE_2D_, GL_TEXTURE_MIN_FILTER_, filter);
      p_glTexParameteri(GL_TEXTURE_2D_, GL_TEXTURE_MAG_FILTER_, filter);
      p_glTexParameteri(GL_TEXTURE_2D_, GL_TEXTURE_WRAP_S_, static_cast<int>(GL_CLAMP_TO_EDGE_));
      p_glTexParameteri(GL_TEXTURE_2D_, GL_TEXTURE_WRAP_T_, static_cast<int>(GL_CLAMP_TO_EDGE_));
      p_glTexImage2D(GL_TEXTURE_2D_, 0, static_cast<int>(GL_RGBA_), width, height, 0, GL_RGBA_, GL_UNSIGNED_BYTE_,
                     nullptr);
      *id = name;
   }
   st.textures[*id] = {width, height};
   return FIG_OK;
   FIG_CATCH
}

int fig_texture_update(unsigned long long id, int width, int height, const unsigned char *rgba) {
   FIG_TRY
   if (st.m == mode::none) return fail(FIG_ERR_STATE, "figure is not initialized");
   const auto t = st.textures.find(id);
   if (t == st.textures.end()) return fail(FIG_ERR_ARGUMENT, "unknown texture (destroyed, or never created)");
   if (width != t->second.width || height != t->second.height)
      return fail(FIG_ERR_ARGUMENT, "pixel array size differs from the texture size");
   if (st.m == mode::window) {
      // tightly packed RGBA rows straight from the caller's array: one upload, no staging copy
      p_glBindTexture(GL_TEXTURE_2D_, static_cast<unsigned int>(id));
      p_glPixelStorei(GL_UNPACK_ROW_LENGTH_, 0);
      p_glPixelStorei(GL_UNPACK_ALIGNMENT_, 1);
      p_glTexSubImage2D(GL_TEXTURE_2D_, 0, 0, 0, width, height, GL_RGBA_, GL_UNSIGNED_BYTE_, rgba);
   }
   return FIG_OK;
   FIG_CATCH
}

void fig_texture_sampling(int plot, int from_texture) {
   // The OpenGL3 backend samples every texture through its own (linear) sampler object, which overrides the
   // glTexParameteri filter of user textures: around a user image, ask it to use the texture's own filter, then
   // restore its render state. No-op without a renderer backend (headless).
   try {
      if (!ImGui::GetCurrentContext()) return;
      const ImGuiPlatformIO &pio = ImGui::GetPlatformIO();
      const ImDrawCallback cb = from_texture ? pio.DrawCallback_SetSamplerFromTex : pio.DrawCallback_ResetRenderState;
      if (cb == nullptr) return;
      ImDrawList *dl = plot ? ImPlot::GetPlotDrawList() : ImGui::GetWindowDrawList();
      dl->AddCallback(cb, nullptr);
   } catch (...) {
   }
}

void fig_texture_destroy(unsigned long long id) {
   try {
      const auto t = st.textures.find(id);
      if (t == st.textures.end()) return;
      if (st.m == mode::window) {
         const unsigned int name = static_cast<unsigned int>(id);
         p_glDeleteTextures(1, &name);
      }
      st.textures.erase(t);
   } catch (...) {
   }
}

void fig_input_mouse(float x, float y, int left_down) {
   if (!ImGui::GetCurrentContext()) return;
   ImGuiIO &io = ImGui::GetIO();
   io.AddMousePosEvent(x, y);
   io.AddMouseButtonEvent(ImGuiMouseButton_Left, left_down != 0);
}

} // extern "C"
