// FIGURE's image files: PNG and JPEG read by stb_image (fig_image_read: fig_read_image and tex%load on the Fortran
// side), PNG and JPEG written by stb_image_write (fig_image_write, and the remote mode's JPEG messages through
// figure_image.h). See figure_native.h, "Image files".
//
// Both are vendored unmodified in third_party/stb and compiled here once, their functions static to this file (a
// program may link its own copies). stb_image is built with its PNG and JPEG decoders only (STBI_ONLY_PNG,
// STBI_ONLY_JPEG) and without stdio: FIGURE reads the file itself with SDL_LoadFile (UTF-8 names on every platform)
// and decodes from memory. Nothing here loads a URL. Thread-safe: no state is shared between calls; stb_image keeps
// its failure reason per thread (thread_local, C++11), and SDL keeps its error per thread, so a task may decode while
// the main thread draws.
#include "figure_native.h"
#include "figure_image.h"

#include <SDL3/SDL.h>

#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_STATIC
#define STBI_ONLY_PNG
#define STBI_ONLY_JPEG
#define STBI_NO_STDIO
#define STBI_NO_LINEAR
#define STBI_NO_HDR
#define STBI_FAILURE_USERMSG
#define STB_IMAGE_WRITE_IMPLEMENTATION
#define STB_IMAGE_WRITE_STATIC
#define STBI_WRITE_NO_STDIO
#if defined(__GNUC__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-function"            // the decoders' and encoders' entry points not called
#pragma GCC diagnostic ignored "-Wmissing-field-initializers" // stb_image_write's "= { 0 }" (with -Wextra)
#if defined(__clang__)
#pragma GCC diagnostic ignored "-Wunknown-warning-option" // an older clang does not know the next one
#endif
#pragma GCC diagnostic ignored "-Wunused-but-set-variable" // stb_image's invalid_chunk, with STBI_FAILURE_USERMSG
#endif
#include "stb_image.h"
#include "stb_image_write.h"
#if defined(__GNUC__)
#pragma GCC diagnostic pop
#endif

#include <climits>
#include <cstring>
#include <exception>
#include <string>

namespace {

int fail(int status, const std::string &msg) {
   fig_set_last_error(msg.c_str(), static_cast<int>(msg.size()));
   return status;
}

void append(void *context, void *data, int size) {
   static_cast<std::string *>(context)->append(static_cast<const char *>(data), static_cast<size_t>(size));
}

// The format a file's first bytes announce: "PNG", "JPEG", or empty (neither).
const char *signature(const unsigned char *b, size_t n) {
   static const unsigned char png[8] = {0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A};
   if (n >= 8 && std::memcmp(b, png, 8) == 0) return "PNG";
   if (n >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return "JPEG";
   return "";
}

} // namespace

namespace figure_image {

bool encode_jpeg(std::string &out, int width, int height, int channels, const unsigned char *pixels, int quality) {
   return stbi_write_jpg_to_func(append, &out, width, height, channels, pixels, quality) != 0;
}

bool encode_png(std::string &out, int width, int height, int channels, const unsigned char *pixels) {
   return stbi_write_png_to_func(append, &out, width, height, channels, pixels, width * channels) != 0;
}

} // namespace figure_image

extern "C" {

int fig_image_read(const char *path, int path_len, unsigned char **rgba, int *width, int *height) {
   *rgba = nullptr;
   *width = 0;
   *height = 0;
   try {
      const std::string p(path, path_len > 0 ? static_cast<size_t>(path_len) : 0);
      if (p.empty()) return fail(FIG_ERR_ARGUMENT, "no file name");
      size_t n = 0;
      void  *data = SDL_LoadFile(p.c_str(), &n);
      if (!data) return fail(FIG_ERR_FAILED, "'" + p + "' cannot be read: " + SDL_GetError());
      const unsigned char *bytes = static_cast<const unsigned char *>(data);
      const std::string    kind = signature(bytes, n);
      if (kind.empty()) {
         SDL_free(data);
         return fail(FIG_ERR_ARGUMENT, "'" + p + "' is not a PNG or JPEG file (the formats FIGURE reads)");
      }
      if (n > static_cast<size_t>(INT_MAX)) {
         SDL_free(data);
         return fail(FIG_ERR_ARGUMENT, "'" + p + "' is 2 GiB or more");
      }
      int            w = 0, h = 0, channels = 0;
      unsigned char *pixels = stbi_load_from_memory(bytes, static_cast<int>(n), &w, &h, &channels, 4);
      SDL_free(data);
      if (!pixels) {
         const char *why = stbi_failure_reason();
         const std::string reason = why ? why : "unknown reason";
         if (reason == "Out of memory") return fail(FIG_ERR_FAILED, "'" + p + "': out of memory");
         return fail(FIG_ERR_ARGUMENT, "'" + p + "' is a " + kind + " file that cannot be decoded: " + reason);
      }
      *rgba = pixels;
      *width = w;
      *height = h;
      return FIG_OK;
   } catch (const std::exception &e) {
      return fail(FIG_ERR_EXCEPTION, std::string("C++ exception: ") + e.what());
   } catch (...) {
      return fail(FIG_ERR_EXCEPTION, "unknown C++ exception");
   }
}

void fig_image_free(unsigned char *rgba) { stbi_image_free(rgba); }

int fig_image_write(const char *path, int path_len, const unsigned char *pixels, int channels, int width, int height,
                    int quality) {
   try {
      const std::string p(path, path_len > 0 ? static_cast<size_t>(path_len) : 0);
      if (p.empty()) return fail(FIG_ERR_ARGUMENT, "no file name");
      if (channels < 1 || channels > 4) return fail(FIG_ERR_ARGUMENT, "1 to 4 channels a pixel");
      if (width <= 0 || height <= 0) return fail(FIG_ERR_ARGUMENT, "an image size must be positive");
      if (quality < 0 || quality > 100) return fail(FIG_ERR_ARGUMENT, "a JPEG quality from 1 to 100 (0: PNG)");
      if (static_cast<long long>(width) * channels > INT_MAX)
         return fail(FIG_ERR_ARGUMENT, "a row of 2 GiB or more");
      std::string out;
      const bool  ok = quality == 0 ? figure_image::encode_png(out, width, height, channels, pixels)
                                    : figure_image::encode_jpeg(out, width, height, channels, pixels, quality);
      if (!ok) return fail(FIG_ERR_FAILED, "'" + p + "': the encoder failed");
      if (!SDL_SaveFile(p.c_str(), out.data(), out.size()))
         return fail(FIG_ERR_FAILED, "'" + p + "' cannot be written: " + SDL_GetError());
      return FIG_OK;
   } catch (const std::exception &e) {
      return fail(FIG_ERR_EXCEPTION, std::string("C++ exception: ") + e.what());
   } catch (...) {
      return fail(FIG_ERR_EXCEPTION, "unknown C++ exception");
   }
}

} // extern "C"
