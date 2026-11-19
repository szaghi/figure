// FIGURE's CPU renderer of Dear ImGui's draw data (figure_swrast.cpp): the pictures of headless and remote modes
// (app%save_image, FIGURE_CAPTURE, test_capture), with no GPU, no display and no library beyond this one.
#ifndef FIGURE_SWRAST_H
#define FIGURE_SWRAST_H

#include "imgui.h"

#include <vector>

namespace figure_swrast {

// A texture's pixels as the renderer reads them: rows from the top, tightly packed, 8 bits per channel.
struct texture_t {
   int                  width = 0, height = 0;
   int                  channels = 4;     // 4: RGBA; 1: alpha only (white), Dear ImGui's Alpha8 atlas
   const unsigned char *pixels = nullptr; // width * height * channels bytes
   bool                 smooth = true;    // the texture's own filter: linear (true) or nearest
};

// The pixels of a user texture by its id: false when it has none (the renderer draws it magenta). Dear ImGui's own
// textures (the font atlas) are read from their ImTextureData, without a lookup.
typedef bool (*lookup_t)(ImTextureID id, texture_t *tex);

// What a render did (tests, timing).
struct stats_t {
   long long triangles = 0;        // triangles that reached a pixel row
   long long fragments = 0;        // pixels covered (blended or not)
   long long unknown_textures = 0; // draw commands whose texture had no pixels
   long long callbacks = 0;        // draw callbacks met (the sampler's state)
};

// Render `dd` into `rgb` (width * height * 3 bytes, RGB, rows from the top), first cleared to `clear` (RGB in [0, 1]),
// as the OpenGL 3 backend draws it on a GPU (see figure_swrast.cpp). threads <= 0: default_threads(). The picture
// does not depend on the number of threads. Reads Dear ImGui's current context (its platform IO's callbacks).
void render(const ImDrawData *dd, int width, int height, const float clear[3], std::vector<unsigned char> &rgb,
            lookup_t lookup, int threads, stats_t *stats);

// The threads a render uses by default: FIGURE_RENDER_THREADS if set (1-64), else the hardware's, at most 8.
int default_threads();

} // namespace figure_swrast

#endif
