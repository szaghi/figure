# Third-party software

FIGURE is released under the [MIT licence](LICENSE.mit.md). Its native layer (`scripts/build_native.sh`) downloads
and compiles the projects below into `lib/libfigure_native.a` and `lib/libSDL3.a` (stb_image_write is kept in
`third_party/stb/`, not downloaded), and embeds the fonts kept in `third_party/fonts/`, the palettes of
`themes/palettes/`, whose colours are those of the projects named below (their licence files in
`third_party/palettes/`), and the colormaps of `third_party/colormaps/` (256 RGB samples each, with their licence
files): a program linked with FIGURE contains them. Their licences are all permissive and compatible with FIGURE's.
The native build installs each licence file under `share/licenses/<project>/`.

| Project | Version (pinned in `native/CMakeLists.txt`) | Licence | Copyright | In FIGURE |
|---|---|---|---|---|
| [Dear ImGui](https://github.com/ocornut/imgui) | 1.93.1 WIP, docking branch, through cimgui `1.93.1WIPdock` | MIT | Omar Cornut | widgets, windows, the OpenGL 3 and SDL3 backends |
| [ImPlot](https://github.com/epezent/implot) | 1.2 WIP, through cimplot `v1.1` | MIT | Evan Pezent | plots, heatmaps, colormaps |
| [cimgui](https://github.com/cimgui/cimgui) | `1.93.1WIPdock` | MIT | Stephan Dilly | the C API of Dear ImGui, and its metadata used by `scripts/gen_bindings.py` |
| [cimplot](https://github.com/cimgui/cimplot) | `v1.1` | MIT | Victor Bombí | the C API of ImPlot, and its metadata used by `scripts/gen_bindings.py` |
| [miniz](https://github.com/richgel999/miniz) | `3.0.2` (release archive, SHA-256 pinned) | MIT | Rich Geldreich, RAD Game Tools, Valve Software | deflate for the remote mode's compressed messages |
| [stb_image_write](https://github.com/nothings/stb) | v1.16, `stb_image_write.h` at commit `4e9b368` (its last change: `1ee679c`), vendored unmodified in `third_party/stb/`, its licence (from the end of the file) in `LICENSE-stb.txt` | MIT or public domain (Unlicense), at the user's choice; FIGURE takes MIT | Sean Barrett | the JPEG encoder of the remote mode's changing images |
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
| [matplotlib](https://github.com/matplotlib/matplotlib) | v3.11.2, `lib/matplotlib/_cm_listed.py` (`_cividis_data`, `_inferno_data`, `_magma_data`, `_turbo_data`) | matplotlib licence (`LICENSE/LICENSE`) | Matplotlib Development Team | the colormaps `cividis` (designed by J. R. Nuñez, C. R. Anderton and R. S. Renslow, PNNL, contributed to matplotlib by its author, PR #9871), `inferno`, `magma` and `turbo`; values unchanged, written as CSV (`third_party/colormaps/<name>.csv`) |
| [mpl-colormaps](https://github.com/BIDS/colormap) | `colormaps.py`, commit `bc54947` | CC0-1.0 | Nathaniel J. Smith, Stéfan van der Walt | `inferno` and `magma`: their tables, equal to matplotlib's (checked by `scripts/gen_colormaps.py`) |
| [Turbo](https://gist.github.com/mikhailov-work/ee72ba4191942acecc03fe6da94fc73f) | `turbo_colormap.py`, gist revision `dccf285` | Apache-2.0 | Google LLC (Anton Mikhailov) | `turbo`: its table, equal to matplotlib's (checked) |
| [cmocean](https://github.com/matplotlib/cmocean) | v4.0.3, `cmocean/rgb/<name>-rgb.txt` | MIT | Kristen M. Thyng | the colormaps `thermal`, `haline`, `deep`, `balance` and `curl` (`curl`: 512 rows resampled linearly to 256, as cmocean does) |
| [Cool to Warm](https://www.kennethmoreland.com/color-advice/) (Kenneth Moreland) | `smooth-cool-warm-table-float-0256.csv`, [kennethmoreland-com.github.io](https://github.com/kennethmoreland-com/kennethmoreland-com.github.io) commit `04f580e`; licence: ParaView's, as that page states, text from ParaView v6.2.0 `Copyright.txt` | BSD-3-Clause | Kitware Inc. | the colormap `cool-warm`, ParaView's "Cool to Warm" |
| [Scientific colour maps](https://www.fabiocrameri.ch/colourmaps/) | 8.0.1, [Zenodo 10.5281/zenodo.8409685](https://doi.org/10.5281/zenodo.8409685), `ScientificColourMaps8.zip`, `<name>/<name>.txt`; licence from its `+LICENCE.pdf` | MIT | Fabio Crameri | the colormaps `batlow`, `vik`, `roma` and `romaO` |
| [Noto Sans Math](https://github.com/notofonts/math) | Regular 3.000, release `NotoSansMath-v3.000` (tag commit `00e9941`), `third_party/fonts/NotoSansMath-Regular.ttf` (unmodified, the unhinted TTF of the release archive `NotoSansMath-v3.000.zip`, SHA-256 `ac351837b41f8a897f020b97fb0f075ad574c1e9669fb5839ada1f92fd748356`), its licence `OFL.txt` as `LICENSE-NotoSansMath.txt` | OFL-1.1 | The Noto Project Authors | the fallback merged into every text font after Plex and Lucide: Greek, `∇`, the mathematical operators; embedded |
| [Lucide](https://lucide.dev) | `lucide-static` 1.61.0 (npm), `third_party/fonts/lucide.ttf` and its code point map `lucide-info.json` (both unmodified, from `font/`) | ISC, and MIT for the icons derived from Feather | Lucide Icons and Contributors; Cole Bemis (Feather) | the icons (`ICON_*`), embedded and merged into every text font |

## Distributing a program built with FIGURE

- **MIT** (FIGURE, Dear ImGui, ImPlot, cimgui, cimplot, miniz, stb_image_write, the Lucide icons derived from
  Feather, the palettes Nord, Solarized, Gruvbox, Dracula, Catppuccin, Tokyo Night and One Dark) and **ISC**
  (Lucide): the copyright notice and the permission notice must be included in all copies or substantial portions of
  the software. For a binary, ship the licence files with it (the `share/licenses/` tree, where the Lucide one is
  `share/licenses/lucide/` and the palettes' are `share/licenses/<palette>/`, or the texts in your documentation or
  "About" box).
- **The colormaps** (`share/licenses/<project>/`, `<project>` one of `matplotlib`, `mpl-colormaps`, `turbo`,
  `cmocean`, `paraview`, `crameri`): MIT (cmocean, Crameri's), as above; **BSD-3-Clause** (ParaView's Cool to Warm):
  reproduce the copyright notice, the conditions and the disclaimer in the documentation of a binary, and do not use
  Kitware's name to promote it; **Apache-2.0** (Turbo): ship the licence and Google's notice with it (`LICENSE-turbo.txt`
  holds both); the **matplotlib licence**: keep its copyright notice, and a derivative work states its changes (here:
  the tables are matplotlib's values written as CSV); **CC0** (mpl-colormaps): no condition.
- **OFL-1.1** (IBM Plex Sans, IBM Plex Mono, Noto Sans Math): the fonts may be bundled and embedded with any
  software; their copyright and licence must accompany them (`share/licenses/ibm-plex/`, one file per font, the same
  text; `share/licenses/noto-sans-math/`), and they may not be sold by themselves. A modified version of Plex may not
  use the name "Plex".
- **zlib** (SDL): no notice is required in a binary distribution. Altered source versions must be marked as such, and
  the notice may not be removed from source distributions.

## Not bundled

Tools used only to build, test or document FIGURE (CMake, FoBiS, fpm, Python, VitePress, ffmpeg, ImageMagick,
Chromium) are not part of what a program links, and their licences do not apply to it.
