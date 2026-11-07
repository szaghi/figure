#!/usr/bin/env bash
# install.sh: build FIGURE from source and install it, ready for pkg-config.
#
#   curl -fsSL https://github.com/szaghi/figure/releases/latest/download/install.sh | bash -s -- --gnu
#
# Usage: install.sh (--gnu | --nvidia | --fc FC) [options]
#        install.sh --uninstall [--gnu | --nvidia | --fc FC] [--prefix DIR]
#
#   --gnu             gfortran, with the gcc and g++ beside it (Apple clang on macOS)
#   --nvidia          nvfortran, with gcc and g++ (the C++ runtime is libstdc++)
#   --fc FC           a Fortran compiler by name or path (gfortran or nvfortran, any version)
#   --prefix DIR      where to install (default: ~/.local)
#   --tag TAG         the release to build (default: the latest)
#   --source DIR      build a local FIGURE tree instead of downloading a release
#   --deps            install the missing system packages, after showing the command (sudo on Linux)
#   --dry-run         run the checks, print what --deps would run, build nothing
#   --uninstall       remove what this script installed in --prefix (one compiler's install, or all)
#   --keep            keep the build directory (it is kept anyway when a stage fails)
#   --verbose         show the build output (otherwise it goes to a log, shown when a stage fails)
#   -h, --help        this help
#
# Stages: 1 toolchain; 2 system packages (SDL's X11, Wayland, libdecor and DBus headers on Linux); 3 download and
# build (the native layer with CMake, libfigure.a with FoBiS, installed in a private virtual environment when
# missing); 4 install into the prefix, with a manifest per compiler; 5 a test program compiled with pkg-config and
# run headless. Installed, for a compiler TAG such as gnu-16.2.0:
#   lib/figure/TAG/          libfigure.a, libfigure_native.a, libSDL3.a (static)
#   include/figure/TAG/      the .mod files
#   lib/pkgconfig/figure-TAG.pc, and figure.pc (a copy of the last one installed)
#   share/figure/TAG/        licences, themes, the manifest
# The script never runs sudo unless --deps is given, and shows the command first.
# Bash 3.2 compatible (macOS's /bin/bash).
set -euo pipefail

repo="szaghi/figure"
github="https://github.com/$repo"

# ---- messages ------------------------------------------------------------------------------------------------------
if [[ -t 1 ]]; then bold=$'\033[1m'; red=$'\033[31m'; green=$'\033[32m'; yellow=$'\033[33m'; reset=$'\033[0m'
else bold=''; red=''; green=''; yellow=''; reset=''; fi
stage() { printf '\n%s== %s%s\n' "$bold" "$*" "$reset"; }
info()  { printf '   %s\n' "$*"; }
ok()    { printf '   %sok%s %s\n' "$green" "$reset" "$*"; }
warn()  { printf '   %swarning:%s %s\n' "$yellow" "$reset" "$*" >&2; }
die()   { printf '%serror:%s %s\n' "$red" "$reset" "$*" >&2; exit 1; }

usage() { sed -n '2,/^# Bash 3.2/{s/^# \{0,1\}//;p;}' "$0" 2> /dev/null || echo "see $github/blob/main/scripts/install.sh"; }

# ---- arguments -----------------------------------------------------------------------------------------------------
family=""      # gnu or nvidia
fc_arg=""      # --fc value
prefix="$HOME/.local"
tag="latest"
source_dir=""
deps=0
dry_run=0
uninstall=0
keep=0
verbose=0
while [[ $# -gt 0 ]]; do
   case "$1" in
      --gnu)       family="gnu"; fc_arg=""; shift ;;
      --nvidia)    family="nvidia"; fc_arg=""; shift ;;
      --fc)        [[ $# -ge 2 ]] || die "--fc needs a compiler"; family=""; fc_arg="$2"; shift 2 ;;
      --prefix)    [[ $# -ge 2 ]] || die "--prefix needs a directory"; prefix="$2"; shift 2 ;;
      --tag)       [[ $# -ge 2 ]] || die "--tag needs a tag"; tag="$2"; shift 2 ;;
      --source)    [[ $# -ge 2 ]] || die "--source needs a directory"; source_dir="$2"; shift 2 ;;
      --deps)      deps=1; shift ;;
      --dry-run)   dry_run=1; shift ;;
      --uninstall) uninstall=1; shift ;;
      --keep)      keep=1; shift ;;
      --verbose)   verbose=1; shift ;;
      -h|--help)   usage; exit 0 ;;
      *)           die "unknown option $1 (see --help)" ;;
   esac
done
if [[ $uninstall -eq 0 ]]; then mkdir -p "$prefix" 2> /dev/null || die "cannot create the prefix $prefix"; fi
[[ -d "$prefix" ]] || die "no prefix $prefix"
prefix="$(cd "$prefix" && pwd)"
os="$(uname -s)"
case "$os" in
   Linux)  platform="linux" ;;
   Darwin) platform="macos" ;;
   *)      die "unsupported system $os: on Windows build FIGURE under MSYS2 UCRT64 (see the installation guide)" ;;
esac

# ---- helpers -------------------------------------------------------------------------------------------------------
have() { command -v "$1" > /dev/null 2>&1; }

# version_ge A B: true when the dotted version A >= B
version_ge() {
   local a b i x y
   IFS=. read -r -a a <<< "$1"
   IFS=. read -r -a b <<< "$2"
   for i in 0 1 2; do
      x="${a[$i]:-0}"; y="${b[$i]:-0}"; x="${x%%[!0-9]*}"; y="${y%%[!0-9]*}"
      [[ ${x:-0} -gt ${y:-0} ]] && return 0
      [[ ${x:-0} -lt ${y:-0} ]] && return 1
   done
   return 0
}

# run a build step, its output to the log (and to the terminal with --verbose); on failure show the log's end
log=""
run_logged() {
   local what="$1"; shift
   info "$what"
   if [[ $verbose -eq 1 ]]; then
      if ! "$@" 2>&1 | tee -a "$log"; then fail_build "$what"; fi
   elif ! "$@" >> "$log" 2>&1; then
      fail_build "$what"
   fi
}
fail_build() {
   keep=1
   tail -n 40 "$log" >&2 || true
   die "$1 failed: the whole log is $log (the build directory $work is kept)"
}

# ---- stage 1: toolchain --------------------------------------------------------------------------------------------
# Sets fc, fc_family (gnu|nvidia), fc_version, cc, cxx, compiler_tag. Missing tools are collected into the
# package lists (pkgs_apt, pkgs_dnf, pkgs_brew) for stage 2.
pkgs_apt=""; pkgs_dnf=""; pkgs_brew=""; missing=""
need_pkg() { # need_pkg WHAT APT DNF BREW
   missing="$missing $1"
   [[ -n "$2" ]] && pkgs_apt="$pkgs_apt $2"
   [[ -n "$3" ]] && pkgs_dnf="$pkgs_dnf $3"
   [[ -n "$4" ]] && pkgs_brew="$pkgs_brew $4"
   return 0
}

find_compiler() {
   local candidate newest
   if [[ -n "$fc_arg" ]]; then
      fc="$(command -v "$fc_arg" 2> /dev/null)" || die "--fc $fc_arg: not found"
   elif [[ "$family" == "nvidia" ]]; then
      fc="$(command -v nvfortran 2> /dev/null)" || fc=""
      if [[ -z "$fc" ]]; then
         newest="$(find /opt/nvidia/hpc_sdk/*/*/compilers/bin -maxdepth 1 -name nvfortran 2> /dev/null | sort -V | tail -n 1 || true)"
         fc="$newest"
      fi
      [[ -n "$fc" ]] || die "nvfortran not found: install the NVIDIA HPC SDK (https://developer.nvidia.com/hpc-sdk) and put its compilers/bin in PATH"
   else
      fc="$(command -v gfortran 2> /dev/null)" || fc=""
      if [[ -z "$fc" ]]; then # gfortran-14 and the like (GitHub's macOS images, Homebrew's gcc@N)
         newest=""
         for candidate in $(compgen -c gfortran- 2> /dev/null | sort -t- -k2 -n -u); do
            [[ "$candidate" =~ ^gfortran-[0-9]+$ ]] && newest="$candidate"
         done
         [[ -n "$newest" ]] && fc="$(command -v "$newest")"
      fi
   fi
   if [[ -z "${fc:-}" ]]; then
      fc=""
      return 0
   fi
   local banner
   banner="$("$fc" --version 2>&1 | head -n 5)" || true
   if [[ "$banner" == *"GNU Fortran"* ]]; then
      fc_family="gnu"
      fc_version="$("$fc" -dumpfullversion 2> /dev/null || "$fc" -dumpversion)"
   elif [[ "$banner" == *nvfortran* ]]; then
      fc_family="nvidia"
      fc_version="$(printf '%s\n' "$banner" | sed -n 's/^nvfortran \([0-9][0-9.]*\).*/\1/p' | head -n 1)"
   else
      die "$fc is neither gfortran nor nvfortran: FIGURE's builds are verified with those two"
   fi
   [[ -n "$fc_version" ]] || die "cannot read the version of $fc"
   [[ -z "$family" || "$family" == "$fc_family" ]] || die "$fc is not a $family compiler"
   compiler_tag="$fc_family-$fc_version"
}

find_c_compilers() {
   local dir suffix base
   if [[ -n "${CC:-}" && -n "${CXX:-}" ]]; then
      cc="$CC"; cxx="$CXX"
   elif [[ "$platform" == "macos" ]]; then
      cc="clang"; cxx="clang++" # SDL needs clang on Apple, and the link line uses libc++
      have clang++ || die "Apple clang not found: install the command line tools (xcode-select --install)"
   elif [[ "$fc_family" == "gnu" ]]; then # the gcc and g++ of the same installation as gfortran
      dir="$(dirname "$fc")"; base="$(basename "$fc")"; suffix="${base#gfortran}"
      if [[ -x "$dir/gcc$suffix" && -x "$dir/g++$suffix" ]]; then cc="$dir/gcc$suffix"; cxx="$dir/g++$suffix"
      else cc="gcc"; cxx="g++"; fi
   else
      cc="gcc"; cxx="g++" # nvfortran links libstdc++
   fi
   have "$cc" || need_pkg "$cc" gcc gcc ""
   have "$cxx" || need_pkg "$cxx" g++ gcc-c++ ""
}

check_toolchain() {
   stage "1. Toolchain"
   find_compiler
   if [[ -z "$fc" ]]; then # only gfortran is installable from the system's packages
      need_pkg gfortran gfortran gcc-gfortran gcc
      fc_family="gnu"; fc_version="?"; compiler_tag="gnu"
   fi
   find_c_compilers
   have cmake || need_pkg cmake cmake cmake cmake
   have pkg-config || need_pkg pkg-config pkg-config pkgconf-pkg-config pkg-config
   if [[ -z "$source_dir" ]] && ! have curl && ! have git; then need_pkg curl curl curl curl; fi
   if have python3; then
      python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))' 2> /dev/null \
         || die "python3 is $(python3 -V 2>&1): FIGURE's scripts need Python 3.11 or newer"
   else
      need_pkg python3 python3 python3 python
   fi
   fobis_cmd=""
   if have fobis && version_ge "$(fobis --version 2>&1 | sed -n 's/^FoBiS.py \([0-9.]*\).*/\1/p')" 3.8; then
      fobis_cmd="$(command -v fobis)"
   elif have python3 && ! python3 -c 'import venv, ensurepip' > /dev/null 2>&1; then
      need_pkg python3-venv python3-venv "" "" # FoBiS goes in a private virtual environment
   fi
   if [[ -n "$fc" ]]; then info "Fortran: $fc ($("$fc" --version 2>&1 | sed -n '/[0-9]/{p;q;}'))"; fi
   if have "$cc"; then info "C:       $(command -v "$cc") ($("$cc" --version 2>&1 | head -n 1))"; fi
   if have "$cxx"; then info "C++:     $(command -v "$cxx") ($("$cxx" --version 2>&1 | head -n 1))"; fi
   if have cmake; then
      info "CMake:   $(cmake --version | head -n 1)"
      version_ge "$(cmake --version | sed -n 's/^cmake version \([0-9.]*\).*/\1/p')" 3.24 || die "CMake 3.24 or newer is needed"
   fi
   if have python3; then info "Python:  $(python3 -V 2>&1)"; fi
   if have pkg-config; then info "pkg-config: $(pkg-config --version)"; fi
   if [[ -n "$fobis_cmd" ]]; then info "FoBiS:   $(fobis --version 2>&1 | head -n 1)"
   else info "FoBiS:   missing or older than 3.8: installed in a private virtual environment at stage 3"; fi
   if [[ -z "$source_dir" ]]; then
      if have curl; then info "curl:    $(curl --version | head -n 1 | cut -d" " -f1-2)"; elif have git; then info "git:     $(git --version)"; fi
   fi
   have ninja && info "Ninja:   $(ninja --version)"
   return 0
}

# ---- stage 2: system packages --------------------------------------------------------------------------------------
# SDL3 enables X11, Wayland (with libdecor) and DBus only when their headers are there when CMake configures it:
# checked through pkg-config, by module name, on every distribution. On macOS SDL needs only the system frameworks.
sdl_modules="x11 xext xrandr xcursor xi xfixes xscrnsaver xtst wayland-client wayland-scanner xkbcommon egl dbus-1 libdecor-0"
sdl_apt() {
   case "$1" in
      x11) echo libx11-dev ;; xext) echo libxext-dev ;; xrandr) echo libxrandr-dev ;; xcursor) echo libxcursor-dev ;;
      xi) echo libxi-dev ;; xfixes) echo libxfixes-dev ;; xscrnsaver) echo libxss-dev ;; xtst) echo libxtst-dev ;;
      wayland-client|wayland-scanner) echo libwayland-dev ;; xkbcommon) echo libxkbcommon-dev ;; egl) echo libegl-dev ;;
      dbus-1) echo libdbus-1-dev ;; libdecor-0) echo libdecor-0-dev ;;
   esac
}
sdl_dnf() {
   case "$1" in
      x11) echo libX11-devel ;; xext) echo libXext-devel ;; xrandr) echo libXrandr-devel ;; xcursor) echo libXcursor-devel ;;
      xi) echo libXi-devel ;; xfixes) echo libXfixes-devel ;; xscrnsaver) echo libXScrnSaver-devel ;; xtst) echo libXtst-devel ;;
      wayland-client|wayland-scanner) echo wayland-devel ;; xkbcommon) echo libxkbcommon-devel ;; egl) echo mesa-libEGL-devel ;;
      dbus-1) echo dbus-devel ;; libdecor-0) echo libdecor-devel ;;
   esac
}

# unique words, in order of first appearance
uniq_words() { local w out=" "; for w in $1; do [[ "$out" == *" $w "* ]] || out="$out$w "; done; out="${out# }"; echo "${out% }"; }

check_packages() {
   stage "2. System packages"
   local m sudo="" cmd="" manager=""
   if [[ "$platform" == "linux" ]]; then
      if have pkg-config; then
         for m in $sdl_modules; do
            if ! pkg-config --exists "$m"; then
               need_pkg "$m" "$(sdl_apt "$m")" "$(sdl_dnf "$m")" ""
            fi
         done
      else # cannot tell what is there: ask for all of them (installing them again changes nothing)
         for m in $sdl_modules; do need_pkg "" "$(sdl_apt "$m")" "$(sdl_dnf "$m")" ""; done
      fi
      [[ "$(id -u)" -eq 0 ]] || sudo="sudo "
      if have apt-get; then
         manager="apt"
         [[ -n "$pkgs_apt" ]] && cmd="${sudo}apt-get update && ${sudo}apt-get install -y $(uniq_words "$pkgs_apt")"
      elif have dnf; then
         manager="dnf"
         [[ -n "$pkgs_dnf" ]] && cmd="${sudo}dnf install -y $(uniq_words "$pkgs_dnf")"
      fi
   else
      if [[ -n "$pkgs_brew" ]]; then
         have brew || die "missing:$missing; install Homebrew (https://brew.sh) or the tools by hand"
         manager="brew"; cmd="brew install $(uniq_words "$pkgs_brew")"
      fi
   fi
   if [[ -z "$missing" ]]; then
      ok "everything needed is installed"
      return 0
   fi
   info "missing:$missing"
   if [[ -z "$cmd" ]]; then
      die "no apt-get or dnf here: install the development packages of these pkg-config modules and tools by hand:$missing"
   fi
   info "the command that installs them ($manager):"
   printf '\n   %s\n\n' "$cmd"
   if [[ $dry_run -eq 1 ]]; then
      info "--dry-run: not run"
      return 0
   fi
   if [[ $deps -eq 0 ]]; then
      info "run it yourself, or run this script again with --deps to have it run that command"
      exit 3
   fi
   info "--deps: running it"
   bash -c "$cmd" || die "the package installation failed"
   # the toolchain may have just been installed: look again
   missing=""; pkgs_apt=""; pkgs_dnf=""; pkgs_brew=""
   check_toolchain
   [[ -z "$missing" ]] || die "still missing after the installation:$missing"
   return 0
}

# ---- stage 3: download and build -----------------------------------------------------------------------------------
fetch_source() {
   local url assets_url archive
   tree="$work/figure"
   if [[ -n "$source_dir" ]]; then
      [[ -f "$source_dir/fobos" && -d "$source_dir/native" ]] || die "--source $source_dir is not a FIGURE tree"
      source_dir="$(cd "$source_dir" && pwd)"
      info "copying $source_dir (its build products left out)"
      mkdir -p "$tree"
      if [[ -d "$source_dir/.git" ]] && have git; then # tracked and untracked files, not the ignored ones
         git -C "$source_dir" ls-files -z -co --exclude-standard -- . ':(exclude)docs' \
            | while IFS= read -r -d '' f; do [[ -e "$source_dir/$f" ]] && printf '%s\0' "$f"; done \
            | (cd "$source_dir" && tar -cf - --null -T -) | (cd "$tree" && tar -xf -)
      else
         (cd "$source_dir" && tar --exclude=./.git --exclude=./build --exclude=./exe --exclude=./mod --exclude=./obj \
            --exclude=./lib --exclude=./include --exclude=./share --exclude=./docs -cf - .) | (cd "$tree" && tar -xf -)
      fi
      return 0
   fi
   if [[ "$tag" == "latest" ]]; then
      if have curl; then # the redirect of releases/latest names the tag, with no API call
         url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$github/releases/latest")" || die "cannot reach $github"
         tag="${url##*/}"
      else
         tag="$(git ls-remote --tags --refs --sort=-v:refname "$github" 'v*' | sed -n 's|.*refs/tags/||p' \
            | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1 || true)"
      fi
      [[ "$tag" =~ ^v[0-9] ]] || die "cannot find the latest release of $repo"
   fi
   info "release $tag"
   if have curl; then
      assets_url="$github/releases/download/$tag/figure-$tag.tar.gz"
      archive="$work/figure-$tag.tar.gz"
      curl -fsSL -o "$archive" "$assets_url" || die "cannot download $assets_url"
      tar -xzf "$archive" -C "$work"
      mv "$work/figure-$tag" "$tree"
      rm -f "$archive"
   else
      git clone --quiet --depth 1 --branch "$tag" "$github" "$tree" || die "cannot clone $github at $tag"
   fi
}

setup_fobis() {
   [[ -n "$fobis_cmd" ]] && return 0
   run_logged "FoBiS: a private virtual environment" python3 -m venv "$work/venv"
   run_logged "FoBiS: pip install FoBiS.py" "$work/venv/bin/python" -m pip install --quiet FoBiS.py
   fobis_cmd="$work/venv/bin/fobis"
   info "FoBiS:   $("$fobis_cmd" --version 2>&1 | head -n 1)"
}

build() {
   stage "3. Download and build"
   fetch_source
   version="$(tr -d ' \n' < "$tree/VERSION")"
   info "FIGURE $version in $tree"
   setup_fobis
   local mode="figure-static-gnu" varset=()
   [[ "$fc_family" == "nvidia" ]] && mode="figure-static-nvf"
   [[ "$platform" == "macos" ]] && varset=(--varset macos)
   # not in a subshell: a failure must reach this shell, which keeps the build directory
   cd "$tree"
   export CC="$cc" CXX="$cxx"
   run_logged "native layer (CMake: Dear ImGui, ImPlot, cimgui, cimplot, SDL3; the first build downloads them)" \
      bash scripts/build_native.sh
   run_logged "libfigure.a (FoBiS, $mode)" \
      "$fobis_cmd" build --mode "$mode" --fc "$fc" ${varset[@]+"${varset[@]}"}
   cd "$work"
   [[ -f "$tree/lib/libfigure.a" && -f "$tree/lib/libfigure_native.a" && -f "$tree/lib/libSDL3.a" ]] \
      || die "the build gave no lib/libfigure.a, libfigure_native.a or libSDL3.a (log: $log)"
   ok "built"
}

# ---- stage 4: install ----------------------------------------------------------------------------------------------
# The manifest lists, relative to the prefix, every file installed ("f PATH") and every directory created
# ("d PATH"), so that --uninstall removes exactly those.
manifest_rel() { echo "share/figure/$1/manifest"; }

record_dirs() { # record_dirs REL_DIR: create it, recording the directories that did not exist
   local rel="$1" acc="" part
   local IFS=/
   for part in $rel; do
      acc="${acc:+$acc/}$part"
      if [[ ! -d "$prefix/$acc" ]]; then
         mkdir "$prefix/$acc"
         echo "d $acc" >> "$manifest_tmp"
      fi
   done
}

put() { # put SRC REL_DEST
   record_dirs "$(dirname "$2")"
   cp "$1" "$prefix/$2"
   echo "f $2" >> "$manifest_tmp"
}

put_tree() { # put_tree SRC_DIR REL_DEST_DIR
   local f
   while IFS= read -r f; do
      put "$1/$f" "$2/$f"
   done < <(cd "$1" && find . -type f | sed 's|^\./||' | sort)
}

uninstall_tag() { # uninstall_tag TAG
   local t="$1" manifest kind rel i other
   local dirs=()
   manifest="$prefix/$(manifest_rel "$t")"
   [[ -f "$manifest" ]] || return 0
   while IFS=' ' read -r kind rel; do
      case "$rel" in /*|..|../*|*/../*|*/..) die "unsafe path in $manifest: $rel" ;; esac
      case "$kind" in
         f) rm -f "$prefix/$rel" ;;
         d) dirs+=("$rel") ;;
      esac
   done < "$manifest"
   rm -f "$manifest"
   # figure.pc is the copy of the last install: drop it with its install, give it to another one if any
   if [[ -f "$prefix/lib/pkgconfig/figure.pc" ]] && grep -q "^compiler=$t\$" "$prefix/lib/pkgconfig/figure.pc"; then
      rm -f "$prefix/lib/pkgconfig/figure.pc"
      other="$(find "$prefix/lib/pkgconfig" -maxdepth 1 -name 'figure-*.pc' 2> /dev/null | sort | tail -n 1 || true)"
      [[ -n "$other" ]] && cp "$other" "$prefix/lib/pkgconfig/figure.pc"
   fi
   for (( i=${#dirs[@]}-1; i>=0; i-- )); do # deepest first; only the empty ones
      rmdir "$prefix/${dirs[$i]}" 2> /dev/null || true
   done
   ok "removed $t from $prefix"
}

install_files() {
   stage "4. Install into $prefix"
   local t="$compiler_tag" libs pc_rel lib_rel inc_rel share_rel f
   lib_rel="lib/figure/$t"; inc_rel="include/figure/$t"; share_rel="share/figure/$t"; pc_rel="lib/pkgconfig/figure-$t.pc"
   if [[ -f "$prefix/$(manifest_rel "$t")" ]]; then
      info "replacing the previous $t install"
      uninstall_tag "$t"
   fi
   manifest_tmp="$work/manifest"
   : > "$manifest_tmp"
   for f in libfigure.a libfigure_native.a libSDL3.a libfigure_clang_rt.a; do
      [[ -f "$tree/lib/$f" ]] && put "$tree/lib/$f" "$lib_rel/$f"
   done
   put_tree "$tree/lib/mod" "$inc_rel"
   [[ -d "$tree/share/licenses" ]] && put_tree "$tree/share/licenses" "$share_rel/licenses"
   for f in LICENSE.mit.md THIRD_PARTY.md; do
      [[ -f "$tree/$f" ]] && put "$tree/$f" "$share_rel/$f"
   done
   [[ -d "$tree/themes" ]] && put_tree "$tree/themes" "$share_rel/themes"
   # the native link line of the platform, with the fobos varset as the one source (figure_native SDL3 first)
   libs="$(cd "$tree" && python3 scripts/check_sync.py --link-flags "$platform")" || die "cannot read the link line"
   libs="$(printf '%s\n' "$libs" | sed 's/-framework \([A-Za-z]*\)/-Wl,-framework,\1/g')" # pkg-config merges repeated words
   record_dirs "lib/pkgconfig"
   cat > "$prefix/$pc_rel" << EOF
prefix=$prefix
libdir=\${prefix}/$lib_rel
includedir=\${prefix}/$inc_rel
compiler=$t

Name: figure
Description: FIGURE, Fortran Immediate-mode GUI (Dear ImGui, ImPlot, SDL3/OpenGL); modules of $t: $fc
URL: $github
Version: ${version#v}
Cflags: -I\${includedir}
Libs: -L\${libdir} -lfigure $libs
EOF
   echo "f $pc_rel" >> "$manifest_tmp"
   cp "$prefix/$pc_rel" "$prefix/lib/pkgconfig/figure.pc"
   record_dirs "$share_rel"
   echo "f $(manifest_rel "$t")" >> "$manifest_tmp"
   cp "$manifest_tmp" "$prefix/$(manifest_rel "$t")"
   ok "$(grep -c '^f ' "$manifest_tmp") files; manifest: $prefix/$(manifest_rel "$t")"
}

# ---- stage 5: proof ------------------------------------------------------------------------------------------------
proof() {
   stage "5. Proof: a program compiled with pkg-config, run headless"
   local dir="$work/proof" flags
   mkdir -p "$dir"
   cat > "$dir/figure_proof.F90" << 'EOF'
program figure_proof
use figure, only : app_object, ig_begin, ig_end, ig_text
type(app_object) :: app
integer          :: frame
call app%init_headless(320, 240)
do frame = 1, 3
   if (.not. app%next_frame()) exit
   if (ig_begin('Proof')) call ig_text('FIGURE is installed')
   call ig_end()
enddo
call app%destroy()
print '(a)', 'FIGURE works: three frames drawn headless'
endprogram figure_proof
EOF
   flags="$(PKG_CONFIG_PATH="$prefix/lib/pkgconfig" pkg-config --cflags --libs "figure-$compiler_tag")" \
      || die "pkg-config cannot read $prefix/lib/pkgconfig/figure-$compiler_tag.pc"
   # shellcheck disable=SC2086 # the flags are words
   (cd "$dir" && "$fc" figure_proof.F90 $flags -o figure_proof) >> "$log" 2>&1 || fail_build "compiling the proof program"
   "$dir/figure_proof" || fail_build "running the proof program"
   ok "compiled and run"
   printf '\n%sFIGURE %s is installed for %s in %s.%s Compile a program with:\n\n' "$bold" "$version" "$compiler_tag" "$prefix" "$reset"
   # shellcheck disable=SC2016 # printed for the user to run, not expanded here
   if ! pkg-config --exists figure 2> /dev/null || [[ "$(pkg-config --variable=prefix figure 2> /dev/null)" != "$prefix" ]]; then
      printf '   export PKG_CONFIG_PATH=%s/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}\n' "$prefix"
   fi
   # shellcheck disable=SC2016 # printed for the user to run
   printf '   %s my_program.F90 $(pkg-config --cflags --libs figure) -o my_program\n\n' "$(basename "$fc")"
   info "figure.pc is the last install; figure-$compiler_tag.pc names this one. Remove it with: install.sh --uninstall --prefix $prefix"
}

# ---- main ----------------------------------------------------------------------------------------------------------
if [[ $uninstall -eq 1 ]]; then
   stage "Uninstall from $prefix"
   if [[ -n "$family" || -n "$fc_arg" ]]; then
      find_compiler
      [[ -n "$fc" ]] || die "the compiler is not found: run --uninstall without a compiler to remove every install"
      [[ -f "$prefix/$(manifest_rel "$compiler_tag")" ]] || die "no $compiler_tag install in $prefix"
      uninstall_tag "$compiler_tag"
   else
      found=0
      for m in "$prefix"/share/figure/*/manifest; do
         [[ -f "$m" ]] || continue
         found=1
         uninstall_tag "$(basename "$(dirname "$m")")"
      done
      [[ $found -eq 1 ]] || die "nothing installed by this script in $prefix"
   fi
   exit 0
fi

[[ -n "$family" || -n "$fc_arg" ]] || die "choose the compiler: --gnu, --nvidia or --fc FC (see --help)"
check_toolchain
check_packages
if [[ $dry_run -eq 1 ]]; then
   stage "Dry run: stopping before the build"
   exit 0
fi
work="$(mktemp -d "${TMPDIR:-/tmp}/figure-install.XXXXXX")"
log="$work/build.log"
: > "$log"
cleanup() { if [[ $keep -eq 0 ]]; then rm -rf "$work"; else info "build directory kept: $work"; fi; }
trap cleanup EXIT
build
install_files
proof
