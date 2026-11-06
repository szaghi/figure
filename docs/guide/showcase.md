---
title: Showcase
---

# Showcase: tools for a CFD solver

<!-- docs/public/media/showcase_*.{png,mp4} are copies of the recordings of xall_figure (its docs/media, made by its
scripts/media.sh): copy them again when they are redone. -->

FIGURE's first application outside this repository is a set of tools for **Xall**, a CFD solver, and for
**OverSet**, the code that prepares its overset (chimera) grids. Each tool is a FIGURE program that opens a window on
a workstation or, with `--remote`, serves its interface to a web browser from a cluster node, through an SSH tunnel
([Remote UI](remote)). The tools live in a private repository; this page shows what they look like and which parts of
FIGURE they are built from.

## The Xall input editor

`xall_edit` edits the solver's input file, `data.input`: 14 sections, about 220 parameters, blocks of parameters that
repeat as many times as a counter says (one per level-set file), parameters that take as many values as another
parameter says (one per multigrid level, per actuator disk, per species). It replaces a Tkinter editor and writes
byte for byte what that editor writes; a search field finds a parameter among all the sections.

<Media name="showcase_xall_edit" video alt="The Xall input editor: a search for cfl lists the CFL number, which is set to 0.7; in the level-set section the number of files is set to 1 and the new block is filled; ctrl+s saves" caption="xall_edit: a search, a value set from its results, a level-set file added and filled, ctrl+s" />

Built from: a laid-out dock space ([Docking](docking)); the main menu bar with ctrl+s and ctrl+o
([Menus and popups](menus)); tables of check boxes, text fields with the default as a hint, combos and tooltips
([Widgets](widgets#groups-headers-tabs-tables)); modals for unsaved changes and for the problems found before saving,
and the question asked when the window is closed with unsaved changes ([Menus and popups](menus#ask-before-quitting));
the system's file dialogs, with a path field in remote mode ([File dialogs](frame-loop#file-dialogs)); the window's
title showing the file and a mark while it is edited (`app%set_title`).

## The OverSet input editor

`overset_edit` edits `overset.input`, the pre-processor's input: scalar sections like the solver's, and two list
sections, the boundary-condition patches and boxes, edited as tables with a row per line of the file.

<Media name="showcase_overset_edit" video alt="The OverSet input editor: a value changed, a boundary patch added and its block set, ctrl+s lists the entries with problems before saving the rest" caption="overset_edit: a value changed, a boundary patch added, ctrl+s" />

Built from the same parts, plus tables whose rows are added, copied, moved and deleted with buttons.

## The run checker

`xall_evol` follows the history files a run writes (residuals, forces and moments, time step, timings) while the run
goes on, and checks them for what goes wrong (NaN, residuals that grow, a time step that collapses), every file's
findings in one table with the errors first. How many files a run writes is not known in advance (one per force group:
hundreds with many groups), so the files are a navigator, grouped by kind, filtered by name, the worst first, and the
plots show one file, or several ticked to compare, overlaid; what they show is saved as a PNG image or as CSV data. It
reads only the lines appended since the last look: a refresh of a 10⁶-line residual file takes 0.02 s instead of the 6.4
s of reading it again.

<Media name="showcase_xall_evol" video alt="The run checker: residuals of six variables on a logarithmic axis keep descending as the synthetic run appends lines; the summary table updates" caption="xall_evol on synthetic files that keep growing while it records" />

<Media name="showcase_xall_evol_compare" alt="The run checker's navigator lists 24 force groups, one marked with an error; three are ticked and their coefficients are overlaid in a grid of six plots" caption="xall_evol: three of 24 force groups compared (synthetic files)" />

Built from: plots on logarithmic axes ([Plots](plots)), subplots sharing the abscissa with formatted tick labels for the
forces and moments ([Several plots in one figure](plots#several-plots-in-one-figure)), a navigator of collapsing headers
and tables of selectable rows with check boxes, a filter field ([Widgets](widgets#groups-headers-tabs-tables)), a
laid-out dock space and a window per file popped out on demand ([Docking](docking)), the plots saved with
`app%save_image` ([Save an image](capture#save-an-image-from-the-program)), the system's folder dialog ([File
dialogs](frame-loop#file-dialogs)), and lazy redraw: the checker sleeps between looks at the files ([Frame loop and
redraw](frame-loop#lazy-redraw)).

## Shared by the three tools

Each tool has a menu bar (File, Edit, Help; `xall_evol` also View) and the same **Edit > Preferences** window: the font
(the bundled IBM Plex Sans, Proggy, or any TrueType/OpenType file), its size and the theme, applied at once with
`app%set_font` and `app%set_style` ([Fonts](styles#fonts), [Named styles](styles#named-styles)) and kept in one
preferences file for the three tools.

## How they are tested

The editors are modules whose `frame` procedure draws one frame: the program calls it in its loop, and a headless
test calls the same procedure ([Headless testing](testing)). The test drives the editor as a user does, with the
synthetic input of `figure_testing` (clicks, keys, typed text, the platform's shortcut key): it opens a file through
the path field, searches, types values, adds rows and blocks, saves with ctrl+s, and compares the file saved with the
one the Python editor writes after the same edits. The pictures on this page are recorded by FIGURE's capture with a
scripted input ([Screenshots and videos](capture)), so they are redone when the interface changes.

## What the tools asked of FIGURE

Writing them found what FIGURE lacked, and each gap was filled in FIGURE first, as a wrapper with a headless check
and its documentation, never with a raw binding in the tool: selectables, wrapped text and child regions; menus and
shortcuts; popups, modals and the question before quitting; the system's file dialogs; plot tick formats, subplots
and docking a window that appears later; the testing module in the static library and the window's title after
`app%init`.
