// FIGURE native glue: SDL3 window + OpenGL3 renderer + Dear ImGui/ImPlot contexts, behind the C ABI of figure_native.h.
#include "figure_native.h"

#include "imgui.h"
#include "imgui_impl_opengl3.h"
#include "imgui_impl_sdl3.h"
#include "implot.h"

#include <SDL3/SDL.h>

#include <exception>
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
} st;

// The three GL calls the glue makes itself, loaded through SDL: no link-time dependency on libGL/opengl32.
typedef void (*gl_viewport_t)(int, int, int, int);
typedef void (*gl_clear_color_t)(float, float, float, float);
typedef void (*gl_clear_t)(unsigned int);
gl_viewport_t    p_glViewport = nullptr;
gl_clear_color_t p_glClearColor = nullptr;
gl_clear_t       p_glClear = nullptr;
constexpr unsigned int GL_COLOR_BUFFER_BIT_ = 0x00004000;

void create_contexts() {
   IMGUI_CHECKVERSION();
   ImGui::CreateContext();
   ImPlot::CreateContext();
   ImGuiIO &io = ImGui::GetIO();
   // No docking: the pinned cimgui tag (1.93dock) is generated from the non-docking Dear ImGui (see plans/plan.md).
   io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;
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

int fig_init(const char *title, int title_len, int width, int height, int vsync) {
   FIG_TRY
   if (st.m != mode::none) return fail(FIG_ERR_STATE, "figure is already initialized");
   if (width <= 0 || height <= 0) return fail(FIG_ERR_ARGUMENT, "window size must be positive");
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
   return FIG_OK;
   FIG_CATCH
}

int fig_init_headless(int width, int height) {
   FIG_TRY
   if (st.m != mode::none) return fail(FIG_ERR_STATE, "figure is already initialized");
   if (width <= 0 || height <= 0) return fail(FIG_ERR_ARGUMENT, "display size must be positive");
   create_contexts();
   ImGuiIO &io = ImGui::GetIO();
   io.IniFilename = nullptr;
   io.DisplaySize = ImVec2(static_cast<float>(width), static_cast<float>(height));
   io.BackendFlags |= ImGuiBackendFlags_RendererHasTextures;
   st.m = mode::headless;
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
   auto handle = [&](const SDL_Event &e) {
      ImGui_ImplSDL3_ProcessEvent(&e);
      if (e.type == SDL_EVENT_QUIT) *running = 0;
      if (e.type == SDL_EVENT_WINDOW_CLOSE_REQUESTED && e.window.windowID == SDL_GetWindowID(st.window)) *running = 0;
      got = true;
   };
   // Lazy redraw: once ImGui has settled, sleep until an event arrives or max_wait elapses (a periodic refresh that
   // lets live data from the application appear); never spin at the display rate while idle.
   if (st.lazy && st.frames_left <= 0) {
      if (SDL_WaitEventTimeout(&ev, st.max_wait_ms)) handle(ev);
   }
   while (SDL_PollEvent(&ev)) handle(ev);
   if (!*running) return FIG_OK; // quitting: no frame is opened
   if (got) st.frames_left = 3;
   else if (st.frames_left > 0) --st.frames_left;
   if (SDL_GetWindowFlags(st.window) & SDL_WINDOW_MINIMIZED) SDL_Delay(10);
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
   const ImGuiIO &io = ImGui::GetIO();
   p_glViewport(0, 0, static_cast<int>(io.DisplaySize.x * io.DisplayFramebufferScale.x),
                static_cast<int>(io.DisplaySize.y * io.DisplayFramebufferScale.y));
   p_glClearColor(0.10f, 0.10f, 0.11f, 1.0f);
   p_glClear(GL_COLOR_BUFFER_BIT_);
   ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
   SDL_GL_SwapWindow(st.window);
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

void fig_input_mouse(float x, float y, int left_down) {
   if (!ImGui::GetCurrentContext()) return;
   ImGuiIO &io = ImGui::GetIO();
   io.AddMousePosEvent(x, y);
   io.AddMouseButtonEvent(ImGuiMouseButton_Left, left_down != 0);
}

int fig_plot_line(const char *label, int label_len, const double *xs, const double *ys, int n) {
   FIG_TRY
   if (n < 0) return fail(FIG_ERR_ARGUMENT, "plot_line: negative point count");
   const std::string l(label, label_len > 0 ? static_cast<size_t>(label_len) : 0);
   ImPlot::PlotLine(l.c_str(), xs, ys, n);
   return FIG_OK;
   FIG_CATCH
}

} // extern "C"
