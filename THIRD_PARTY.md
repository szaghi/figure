# Third-party software

FIGURE is released under the [MIT licence](LICENSE.mit.md). Its native layer (`scripts/build_native.sh`) downloads
and compiles the projects below into `lib/libfigure_native.a` and `lib/libSDL3.a`, and embeds the font kept in
`third_party/fonts/`: a program linked with FIGURE contains them. Their licences are all permissive and compatible with FIGURE's. The native build installs each
licence file under `share/licenses/<project>/`.

| Project | Version (pinned in `native/CMakeLists.txt`) | Licence | Copyright | In FIGURE |
|---|---|---|---|---|
| [Dear ImGui](https://github.com/ocornut/imgui) | 1.93.1 WIP, docking branch, through cimgui `1.93.1WIPdock` | MIT | Omar Cornut | widgets, windows, the OpenGL 3 and SDL3 backends |
| [ImPlot](https://github.com/epezent/implot) | 1.2 WIP, through cimplot `v1.1` | MIT | Evan Pezent | plots, heatmaps, colormaps |
| [cimgui](https://github.com/cimgui/cimgui) | `1.93.1WIPdock` | MIT | Stephan Dilly | the C API of Dear ImGui, and its metadata used by `scripts/gen_bindings.py` |
| [cimplot](https://github.com/cimgui/cimplot) | `v1.1` | MIT | Victor Bombí | the C API of ImPlot, and its metadata used by `scripts/gen_bindings.py` |
| [miniz](https://github.com/richgel999/miniz) | `3.0.2` (release archive, SHA-256 pinned) | MIT | Rich Geldreich, RAD Game Tools, Valve Software | deflate for the remote mode's compressed messages |
| [SDL](https://github.com/libsdl-org/SDL) | `release-3.4.20` | zlib | Sam Lantinga | window, input, OpenGL context, file dialogs |
| [IBM Plex Sans](https://github.com/IBM/plex) | Regular 3.005, `third_party/fonts/IBMPlexSans-Regular.ttf` (unmodified) | OFL-1.1 | IBM Corp. (Reserved Font Name "Plex") | the default font of the interface, embedded |

## Distributing a program built with FIGURE

- **MIT** (FIGURE, Dear ImGui, ImPlot, cimgui, cimplot, miniz): the copyright notice and the permission notice must be
  included in all copies or substantial portions of the software. For a binary, ship the licence files with it (the
  `share/licenses/` tree, or the texts in your documentation or "About" box).
- **OFL-1.1** (IBM Plex Sans): the font may be bundled and embedded with any software; its copyright and licence
  must accompany it (`share/licenses/ibm-plex/`), and it may not be sold by itself. A modified version may not use
  the name "Plex".
- **zlib** (SDL): no notice is required in a binary distribution. Altered source versions must be marked as such, and
  the notice may not be removed from source distributions.

## Not bundled

Tools used only to build, test or document FIGURE (CMake, FoBiS, fpm, Python, VitePress, ffmpeg, ImageMagick,
Chromium) are not part of what a program links, and their licences do not apply to it.
