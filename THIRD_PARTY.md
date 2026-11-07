# Third-party software

FIGURE is released under the [MIT licence](LICENSE.mit.md). Its native layer (`scripts/build_native.sh`) downloads
and compiles the projects below into `lib/libfigure_native.a` and `lib/libSDL3.a`, and embeds the fonts kept in
`third_party/fonts/` and the palettes of `themes/palettes/`, whose colours are those of the projects named below
(their licence files in `third_party/palettes/`): a program linked with FIGURE contains them. Their licences are all permissive and compatible with FIGURE's. The native build installs each
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
| [IBM Plex Mono](https://github.com/IBM/plex) | Regular 2.005, release `@ibm/plex-mono@2.5.0`, `third_party/fonts/IBMPlexMono-Regular.ttf` (unmodified) | OFL-1.1 | IBM Corp. (Reserved Font Name "Plex") | the monospace font (`'plex-mono'`), embedded |
| [Nord](https://github.com/nordtheme/nord) | `src/nord.css`, commit `005e87e` | MIT | Sven Greb | the colours of the palette `nord` (`themes/palettes/nord.toml`), embedded |
| [Solarized](https://github.com/altercation/solarized) | `README.md`, commit `4f90b03` | MIT | Ethan Schoonover | the palettes `solarized-dark` and `solarized-light` |
| [Gruvbox](https://github.com/morhetz/gruvbox) | `colors/gruvbox.vim`, commit `0401386` | MIT (stated in its README and `package.json`; no licence file) | Pavel Pertsev | the palettes `gruvbox-dark` and `gruvbox-light` |
| [Dracula](https://github.com/dracula/dracula-theme) | `README.md`, commit `1e04a4b` | MIT | Dracula Theme | the palette `dracula` |
| [Catppuccin](https://github.com/catppuccin/palette) | `palette.json`, v1.8.0 (commit `07d02aa`) | MIT | Catppuccin | the palettes `catppuccin-mocha` and `catppuccin-latte` |
| [Tokyo Night](https://github.com/enkia/tokyo-night-vscode-theme) | `README.md` and `themes/tokyo-night-color-theme.json`, commit `da5546b` | MIT | Enkia | the palette `tokyo-night` |
| [One Dark](https://github.com/joshdick/onedark.vim) | `autoload/onedark.vim`, commit `ad9610c`; one grey (mono-2) from [Atom's One Dark](https://github.com/atom/atom/tree/master/packages/one-dark-syntax), commit `8ae45ca` | MIT | Joshua Dick; GitHub Inc. | the palette `one-dark` |
| [Lucide](https://lucide.dev) | `lucide-static` 1.61.0 (npm), `third_party/fonts/lucide.ttf` and its code point map `lucide-info.json` (both unmodified, from `font/`) | ISC, and MIT for the icons derived from Feather | Lucide Icons and Contributors; Cole Bemis (Feather) | the icons (`ICON_*`), embedded and merged into every text font |

## Distributing a program built with FIGURE

- **MIT** (FIGURE, Dear ImGui, ImPlot, cimgui, cimplot, miniz, the Lucide icons derived from Feather, the palettes
  Nord, Solarized, Gruvbox, Dracula, Catppuccin, Tokyo Night and One Dark) and **ISC** (Lucide): the copyright notice
  and the permission notice must be included in all copies or substantial portions of the software. For a binary,
  ship the licence files with it (the `share/licenses/` tree, where the Lucide one is `share/licenses/lucide/` and the
  palettes' are `share/licenses/<palette>/`, or the texts in your documentation or "About" box).
- **OFL-1.1** (IBM Plex Sans, IBM Plex Mono): the fonts may be bundled and embedded with any software; their
  copyright and licence must accompany them (`share/licenses/ibm-plex/`, one file per font, the same text), and they
  may not be sold by themselves. A modified version may not use the name "Plex".
- **zlib** (SDL): no notice is required in a binary distribution. Altered source versions must be marked as such, and
  the notice may not be removed from source distributions.

## Not bundled

Tools used only to build, test or document FIGURE (CMake, FoBiS, fpm, Python, VitePress, ffmpeg, ImageMagick,
Chromium) are not part of what a program links, and their licences do not apply to it.
