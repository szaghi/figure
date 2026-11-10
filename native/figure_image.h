// FIGURE's image codecs (figure_image.cpp), for the other native files: the one copy of stb_image_write's encoders.
#ifndef FIGURE_IMAGE_H
#define FIGURE_IMAGE_H

#include <string>

namespace figure_image {

// Append to `out` the JPEG of `width` x `height` pixels of `channels` bytes (1 grey, 2 grey + alpha, 3 RGB, 4 RGBA:
// the alpha is dropped), rows top to bottom, at `quality` (1-100). False if the encoder fails.
bool encode_jpeg(std::string &out, int width, int height, int channels, const unsigned char *pixels, int quality);
// Append to `out` the PNG of the same pixels (lossless; zlib-compressed, filtered). False if the encoder fails.
bool encode_png(std::string &out, int width, int height, int channels, const unsigned char *pixels);

} // namespace figure_image

#endif
