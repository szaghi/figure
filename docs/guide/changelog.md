---
title: Changelog
---

# Changelog

Every release, and what is done since the last one (Unreleased). The state of the work is in the [roadmap](roadmap).
The list is generated from the commit messages by git-cliff (`git cliff -o CHANGELOG.md`; `scripts/release.sh`
regenerates it for each release).

## Migration to v0.8.0

What a program written for v0.7.0 meets in v0.8.0, with a link to the section that has the details. Nothing a v0.7.0
program calls changed its meaning; the entries below are new optional arguments, new procedures, and pages that moved.

| Change | What to do |
|---|---|
| [Error bars](plots#error-bars-annotations-and-drag-tools): `ip_error_bars` takes `horizontal` before `stat` | nothing; a call passing `stat` by position (none in FIGURE's examples) must name it |
| [3-D plots](plots#_3-d-plots): `ip3_line` takes `colors`, `ip3_scatter` `colors` and `sizes`, `ip3_setup_axis` `format`, each before `stat` | as above |
| New public names of `use figure`: [`ig_color_picker`](widgets#colour-editing), [`ip_pie_chart` and `ip_bubbles`](plots#pies-and-bubbles), [`ip3_setup_axis_ticks`](plots#_3-d-plots), [`ip3_push_style_color`, `ip3_pop_style_color`, `ip3_push_style_var`, `ip3_pop_style_var`](styles#changes-for-a-block) | nothing: a program with a name of its own that clashes renames it, or uses `figure` with `only` |
| [Data in place](plots#data-in-place): a 2-D item, a drag tool or a plot query outside a plot is a usage error (`FIG_ERR_STATE`, `<p>: no plot is being declared (...)`), in every checks mode; in `'report'` and `'recover'` it crashed in ImPlot | nothing for a correct program; one that drew an item outside a plot now gets the status, or the message at the next `app%next_frame` |
| The [tutorial](/manual/) has a new chapter 7, [Building and running the studio](/manual/tutorial/07-building); chapters 7 to 25 are now 8 to 26, and their programs `tut07_*` to `tut25_*` are `tut08_*` to `tut26_*` | a bookmark to a chapter, or a copy of a program, takes the new number |
| The documentation's own tooling: `scripts/check_docs.py` also checks tables, links, generated pages, and that every public name is in a sentence of its page and called by a compiled program | nothing for a program; a contribution keeps them green ([Contributing](contributing)) |

## Migration to v0.7.0

What a program written for v0.6.0 meets in v0.7.0, with a link to the section that has the details. Nothing a v0.6.0
program calls changed its meaning; the entries below are new optional arguments and what the build installs.

| Change | What to do |
|---|---|
| [Lists and trees](widgets#selecting-many-items): `ig_selectable` and `ig_tree_node` take two more optional arguments at the end, `index` and `stat`; `list_clipper_object%begin` takes `keep` | nothing; a call by position keeps its meaning |
| [Frame checks](errors#the-rules-checked): three more pairs are checked, `ip_begin_aligned` / `ip_end_aligned`, `ip_begin_legend_popup` / `ip_end_legend_popup` (end only after a true begin) and `ig_begin_multi_select` / `ig_end_multi_select` (always paired) | nothing; a program that drives these through the raw layer (`ImPlot_BeginAlignedPlots`, `igBeginMultiSelect`) is not checked, as before |
| [Plots](plots#grouped-bars-and-digital-signals): FIGURE patches one line of ImPlot (`native/patches/implot-0001-digital-rect-order.patch`): its digital bars drew nothing with Dear ImGui 1.93 | nothing; a program that called `ImPlot_PlotDigital_*` through the raw layer now sees its bars |
| [Installation](install#from-cmake): the installer also writes a CMake package (`lib/cmake/figure-<tag>/`), and builds with Intel ifx (`--intel`); each release has a sources archive for machines without network ([Building without network](install#building-without-network)) | nothing; a CMake project that wrote its own `pkg_check_modules` recipe can use `find_package(figure CONFIG)` and `figure::figure` instead |
| New public names of `use figure`: the [file API](frame-loop#files-and-folders) (`figure_make_folder`, `figure_remove`, `figure_set_file_time`, `figure_file_time`, `figure_file_exists`), [drag and drop](widgets#drag-and-drop) (`ig_drag_source`, `ig_drop_target`, `ig_dragging`, `ip_drop_target`), [plots across plots](plots#plots-across-plots) (`ip_link_axis`, `ip_begin_aligned`, ...), [multi-selection](widgets#selecting-many-items) (`selection_object`, `ig_begin_multi_select`, ...) and [3-D plots](plots#_3-d-plots) (`ip3_triangles`, `ip3_image`, `ip3_mouse_ray`, ...) | a program with its own procedure of one of these names imports `figure` with `only:` (as it would for any new name) |

## Migration to v0.6.0

What a program written for v0.5.0 meets in v0.6.0, with a link to the section that has the details.

| Change | What to do |
|---|---|
| [Tables](widgets#tables): FIGURE patches Dear ImGui's 0 / 0 in a `SizingStretchProp` table's first frame (ocornut/imgui#8718); the columns start equal there. A program built with `-ffpe-trap=invalid` no longer stops at its own such table, and Markdown is drawn with the traps as the program set them (v0.5.0 held them) | nothing to change; a program that held the traps itself around such a table can stop doing so |
| [Finding items by path](testing#finding-items-by-path): the items are recorded in every mode from the first frame; v0.5.0 recorded window and remote programs only from their first path call, which found nothing | nothing; a program that called `test_record_items(.true.)` for that first call can drop it. A window program that never finds items by path pays about 0.02 µs per item and frame; `test_record_items(.false.)` before `app%init` gives it back |
| Dear ImGui at the docking branch's head (1.93.1 WIP, cf53467; v0.5.0 had 1.93.0): every arrow (tree nodes, combos, collapsing headers) is a stroked chevron, and the dark style's window, popup and child backgrounds are darker. The style has two more variables, `SymbolArrowSizeFactor` and `SymbolArrowThicknessFactor` ([Styles](styles)) | a program's own golden pictures (`test_compare_image`) of its windows are recorded again, once |
| [Raw bindings](raw-bindings): `igTreeNodeGetOpen` takes a second argument, `flags` (cimgui's generated API at the new Dear ImGui); FIGURE's own procedures are unchanged | a program calling `igTreeNodeGetOpen(id)` from `figure_cimgui` passes `flags` too (`0_c_int` for none) |
| [3-D views](view3d#how-a-view-is-rendered): while the user drags or turns the wheel (`fast_moves`), the half-size renders leave out the meshes' grid lines (`edges`); the render at the end of the move draws them. `threads` takes up to 16 (was 4); the vertex caches are freed once the view rests (`render_info(cache_bytes=)`) | nothing; a program that wants more speed on a fine grid can pass more threads |

## Migration to v0.5.0

What a program written for v0.4.0 meets in v0.5.0, with a link to the section that has the details.

| Change | What to do |
|---|---|
| [Plot data in place](plots#data-in-place): the 1-D items' array dummies are `asynchronous`, so nvfortran passes rows, strided and reversed sections in place instead of copying them; the plot is the same | nothing to change in a program; a test that checks `test_plot_stride()` or `test_plot_copies()` under nvfortran now sees the section's own stride, and FIGURE's copy of a reversed section counted |
| [`figure_last_error`](errors#figure-last-error): the message is kept per thread; a failure in a task no longer overwrites the main thread's message | nothing; a program that read, on the main thread, a message set by a failure inside a task reads it from the task (`t%result` gives the task's own failure, as before) |
| [Synthetic input](testing#synthetic-input): queued input gives the frames an event gives (three more, then idle), and in window mode a lazy loop no longer waits for events while input is queued; Dear ImGui is built with its item hooks (`IMGUI_ENABLE_TEST_ENGINE`), off unless items are recorded | nothing; a window-mode test runs its queued input without the `max_wait` pauses; a program built on the raw cimgui layer that tests `ImGuiItemStatusFlags` sees five more bits defined, which Dear ImGui passes to the hooks only, never to `LastItemData` |
| [Windows and layouts](docking#windows-and-layouts): `ig_begin(name)` without `open` gives a window registered with `app%add_window` a close button, which hides it; `ig_dock_layout_begin` returns `.true.` again after `app%switch_layout` or `app%reset_layout` | nothing: without `add_window`, `switch_layout` and `reset_layout` both behave as in v0.4.0; a program that registers a window it closes with its own flag passes `open` as before, or `closable=.false.` |
| [`app%save_image`](capture#save-an-image-from-the-program) works in every mode: headless and remote modes draw the frame with FIGURE's CPU renderer, where v0.4.0 refused them with `FIG_ERR_STATE`; its failure message is `save_image: '<path>' cannot be written: <reason>` (was `save_image: cannot write <path>: <reason>`) | nothing; a test that expected `FIG_ERR_STATE` headless now gets the file; a program that matched the old message matches the new one |
| [`FIGURE_CAPTURE`](capture#variables) records headless and remote programs too (the CPU renderer's frames), where v0.4.0 ignored it outside a window; `FIGURE_CAPTURE_HEADLESS=1` records a window program without a window | nothing; a headless test run with `FIGURE_CAPTURE` set in its environment now writes frames and ends after `FIGURE_CAPTURE_FRAMES` |
| [Headless mode](capture#three-modes-two-renderers): Dear ImGui's font atlas gets ids with the top bit set (v0.4.0 gave every page id 1, which the first user texture also had), and the sampler callbacks are registered, so an image drawn headless uses its texture's own filter | nothing, unless a program read `ImTextureID`s through the raw layer: the atlas's are no longer 1 |
| [The native layer](capture#determinism) is compiled with `-ffp-contract=off`: no fused multiply-add in Dear ImGui's, ImPlot's and FIGURE's C++ | nothing on x86-64 built for any processor (no FMA without `-march`); on aarch64, or with `-march=native`, a layout rounding at a tie may move by one pixel, now the same as everywhere |
| [Shortcuts](menus#shortcuts): a fourth scope, `'always'`, not routed: every call of the chord fires, whatever has the focus, a text field being edited included. v0.4.0's migration note said `'global'` gives v0.3's behaviour; it does not when two calls bind one chord (only the first `'global'` call of the frame fires) | for v0.3's behaviour exactly, `scope='always'`; a single key that must work everywhere keeps `scope='global'`; `ig_set_next_item_shortcut` refuses `'always'` (`FIG_ERR_ARGUMENT`) |
| [Input scripts](capture#input-scripts): a capture script's `<frame> wait` holds the recording until the program's tasks and processes are done; the documentation's pictures are all the CPU renderer's, checked in CI | nothing in a program; a contributor whose change alters a picture of the site records it again (`python3 scripts/docs_media.py --headless NAME`, or `--check` then `--update`) and commits it with the change |
| [Markdown](widgets#markdown): the native layer compiles imgui_rich_md and md4c (MIT) and embeds IBM Plex Sans Bold, Italic and Bold Italic (OFL-1.1): a program linked with FIGURE grows by about 1 MB | nothing in the code; a binary distributed with its licences ships the two new ones too (`share/licenses/imgui_rich_md/`, `share/licenses/md4c/`; [Third-party software](https://github.com/szaghi/figure/blob/main/THIRD_PARTY.md)) |

## Migration to v0.4.0

What a program written for v0.3.1 meets in v0.4.0. Each line links to the "Changed in v0.4.0" box of the section
that has the details: the old behaviour, the new one, and why.

| Change | What to do |
|---|---|
| [Usage errors reported](errors#pairing-and-frames): a wrong end, a scope left open or a drawing call with no frame open no longer abort inside Dear ImGui; `next_frame(stat)` reports them (mode `'report'`, the default) | pass `stat` to `next_frame` and act on `FIG_ERR_STATE`, or `app%set_checks('abort')` to stop at the faulty call; a loop without `stat` stops with FIGURE's message |
| [Shortcuts routed](menus#shortcuts): `ig_shortcut`'s default scope is `'focused'`; a call inside a window fires only while that window has the focus, and no longer while a text field uses the key | calls outside every window behave as before; a key inside a window that must work everywhere takes `scope='global'`; two calls of one chord that must both fire, as in v0.3, take `scope='always'` (from v0.5.0) |
| [Numbers](widgets#numbers): `ig_input` and `ig_slider` take every kind, vectors, formats, `scale`, `clamp`; they moved from `figure_imgui` to `figure_numbers`; a slider with ends beyond half the kind's range is refused | nothing for `use figure`; a `use figure_imgui, only: ig_input` names `figure_numbers` or `figure` instead |
| [Tables](errors#tables): `ig_begin_table` with `columns` outside 1 to 511 is refused with `FIG_ERR_ARGUMENT` | pass a valid count (it aborted before) |
| [Plot axes](plots#axes): `ip_setup_axes` takes `xscale`/`yscale`; `xlog`/`ylog` are deprecated synonyms; new arguments come before `stat`; setup calls out of place are [usage errors](errors#plot-axes) | name `stat` if it was passed by position; prefer `yscale='log'` to `ylog=.true.` |
| [Data in place](plots#data-in-place): the plot items take arrays of any stride and integer abscissae; the dummies are no longer `contiguous` | nothing: every v0.3.1 call compiles and draws as before |
| [Drag tools](plots#error-bars-annotations-and-drag-tools): `ip_drag_line_x`, `ip_drag_line_y`, `ip_drag_point` outside a plot are usage errors | call them between `ip_begin_plot` and `ip_end_plot` (it aborted before) |

The tutorial's [part three](/manual/tutorial/19-checks) shows the new calls in the solver studio of part two.

<!--@include: ../../CHANGELOG.md{3,}-->
