// stb_image for imgui_rich_md (third_party/imgui_rich_md, its patch 0001 includes this file in place of its own copy of
// stb_image.h): rich_md.cpp decodes the images of a Markdown text with the two functions below, here FIGURE's one copy
// of stb_image (figure_image.cpp: PNG and JPEG, its functions static). No second copy of the decoder, and no stbi_*
// symbol exported from libfigure_native.a to meet a program's own stb_image.
#ifndef FIGURE_RICH_MD_STB_H
#define FIGURE_RICH_MD_STB_H

#include "figure_image.h"

#define stbi_load_from_memory(data, size, w, h, channels, desired)                                                     \
   figure_image::decode(data, size, w, h, channels, desired)
#define stbi_image_free(pixels) figure_image::free_pixels(pixels)

#endif
