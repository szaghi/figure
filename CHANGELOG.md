# Changelog

All notable changes to this project are documented here.
Versions follow [Semantic Versioning](https://semver.org/).
Format follows [Keep a Changelog](https://keepachangelog.com/).

## [0.2.0] — 2026-11-06
### Added
- **implot**: Logarithmic axes in ip_setup_axes (xlog, ylog)

- **imgui**: Text fields, integer fields and the next item's width

- **imgui**: Drop-down lists and tooltips

- **imgui**: Collapsing headers, tabs, id scopes and disabled blocks

- **imgui**: Tables

- **testing**: Test_click and test_drag let the pointer rest before pressing (F1)

- **imgui**: Selectable lines, wrapped/disabled/coloured text, child regions (F2)

- **imgui**: Menus and keyboard shortcuts (F3)

- Popups, modals and a confirmation before quitting (F4)

- **app**: The system's file dialogs (F5)

- **implot**: Tick formats, subplots, docking a window that appears later (F6)

- **app**: The window's title after init (set_title, title)

- **app**: Save a rectangle of the window as a PNG (save_image)

- **app**: Save and load the arrangement of the windows (layouts)

- **imgui**: A bar along one side of the window (ig_begin_side_bar)

- **style**: Lucide icons in every font, by name (ICON_*)

- **imgui**: Workspace buttons, window focus, list clipper, text level with fields

- **imgui**: The size of a text in the current font (ig_text_size)


### Changed
- **imgui**: Ig_text_size's result named extent


### Documentation
- Forms in the widgets guide, a cookbook editor, roadmap v0.2.0

- **showcase**: The tools built for Xall with FIGURE (R1)

- **api**: The API pages regenerated for F7 (figure_library, set_title, title)

- **showcase**: The run checker's navigator and comparison

- **showcase**: The run checker saves its plots (image, data)

- The overview pages catch up with v0.2.0 so far

- **showcase**: Xall_gui, a case's input and run in one window

- **showcase**: Xall_gui's case files, checked as the solver reads them

- **api**: The API pages regenerated for the new wrappers

- The pages say v0.2.0, released


### Fixed
- **fpm**: Give the package commit an author on CI

- **native**: Capture scripts accept every key name test_key accepts

- **test**: Select a field's text with keys every platform reads alike

- **testing**: A 'shortcut' key name for the platform's shortcut key

- **build**: Ship figure_testing in the static library

- **app**: Set_font's size reaches the next frame

- **app**: File dialogs start from the program's working directory


## [0.1.0] — 2026-11-05
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

- **features**: List every public procedure; check it with scripts/check_docs.py (S17)

- **media**: Regenerate every recording for v0.1.0 (S17)

- **changelog**: Generate CHANGELOG.md with git-cliff; the docs page includes it (S17)

- **readme**: The mark, an animation, a compiled example, install with FoBiS and fpm (S17)

- Check every page against the code for v0.1.0 (S17)

- **site**: Fixes from a review of the built site (S17)


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

- **test**: The remote test's wrong token always differs from the token


### Performance
- **remote**: Measure redraw and bandwidth, locally and through a tunnel (S11)

- **remote**: Skip frames equal to the last one sent (S12)



