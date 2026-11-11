// FIGURE (scripts/fpm_package.py): miniz with the options native/CMakeLists.txt sets (deflate and zlib streams only,
// mz_ names only), for builds without flags. The library itself is miniz.c.inc, unmodified.
#define MINIZ_NO_ARCHIVE_APIS
#define MINIZ_NO_STDIO
#define MINIZ_NO_TIME
#define MINIZ_NO_ZLIB_COMPATIBLE_NAMES
#include "miniz.c.inc"
