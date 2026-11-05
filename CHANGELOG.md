# Changelog

All notable changes to this project are documented here.
Versions follow [Semantic Versioning](https://semver.org/).
Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]
### Added
- **native**: Add FIGURE_DEBUG_REDRAW diagnostics and an idle-CPU probe

- **bindings**: Generate the raw cimgui/cimplot layer from their metadata (M2)

- **bindings**: Generate the C++ glue for struct-by-value functions

- **implot**: Add scatter, bars and shaded items and item styles (ip_spec)

- **implot**: Plot matrix rows in place; no imgui.ini unless asked

- Add GPU textures, heatmaps and colour scales

- Add a Mandelbrot explorer and a 4K redraw benchmark (M3 done)

- **remote**: Serve the UI to a web browser (M5, remote)

- Brand the docs, add styles and frame capture (v0.1.0 docs gate)

- **dock**: Turn docking on; dock spaces and program-defined layouts (S2)

- **style**: Every Dear ImGui and ImPlot style colour and variable by name (S3)

- **style**: Themes as files, embedded and parsed natively (S4)

- **style**: Paper and high-contrast themes, Okabe-Ito lines, contrast test (S5)

- **style**: Load and save theme files; the style editor in a window (S6)

- **style**: IBM Plex Sans by default; fonts by name or file, scoped (S7)

- **style**: Window flags and scoped style changes for both libraries (S8)

- **testing**: Public synthetic-input module figure_testing (S10)

- **remote**: Pace frames for the browser: a cap, backpressure, a real wait (S13)

- **remote**: 12-byte vertices, and deflate when the link is the bottleneck (S13)

- **remote**: An access token in the address, random by default (S14)


### Changed
- **implot**: Take real64 arrays in ip_line, keep C kinds in figure_c_native


### Documentation
- **plan**: Record the native layer rebuilt with Wayland and DBus

- Document GALLIUM_DRIVER=d3d12 for WSLg and record the driver check

- Add the VitePress documentation site

- **manual**: Point the example links at the main branch

- **plan**: Record the name collision check

- Record M4 as done, all platforms green

- Retire plans/plan.md; issue #1 is the plan, the docs the reference

- **style**: A theme gallery, recorded from one program in every style (S9)

- **performance**: A performance guide built on the measurements (S15)


### Fixed
- **build**: Anchor build-product paths in .gitignore

- **base**: Give Fortran-side failures their own error message

- **ci**: Build SDL with clang on macOS, run rules through bash, free disk for nvhpc

- **build**: Order the fpm link line; link clang's runtime on macOS

- **build**: Add the platform libraries after fpm's objects (figure_platform)

- **native**: Bound the glyph advance clamp so fonts above 15 px do not overflow

- **remote**: Draw lists over 65536 vertices in remote and headless modes

- **ci**: Retry the remote test's verdict open; Apple clang for the macOS fpm dependency

- **ci**: C++17 for the macOS fpm dependency (Apple clang defaults to C++98)


### Performance
- **remote**: Measure redraw and bandwidth, locally and through a tunnel (S11)

- **remote**: Skip frames equal to the last one sent (S12)



