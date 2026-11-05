---
title: figure
---

# figure

> FIGURE, Fortran Immediate-mode GUI for User interfaces, Rendering and Exploration.

 Umbrella module: `use figure` gives the application loop (figure_app), the Dear ImGui widgets (figure_imgui),
 menus, popups and shortcuts (figure_menu), groups of widgets (figure_group: child regions, collapsing headers, tabs,
 tables, id scopes, disabled blocks), docking (figure_dock), the style colours and variables by name (figure_style),
 the ImPlot plots (figure_implot): items, heatmaps, images, their style (`ip_spec`) and ImPlot's constants, and the
 GPU textures (figure_texture) that `ig_image` and `ip_image` draw.

**Source**: `src/lib/figure.F90`

**Dependencies**

```mermaid
graph LR
  figure["figure"] --> figure_app["figure_app"]
  figure["figure"] --> figure_base["figure_base"]
  figure["figure"] --> figure_c_native["figure_c_native"]
  figure["figure"] --> figure_cimgui_enums["figure_cimgui_enums"]
  figure["figure"] --> figure_dock["figure_dock"]
  figure["figure"] --> figure_group["figure_group"]
  figure["figure"] --> figure_imgui["figure_imgui"]
  figure["figure"] --> figure_implot["figure_implot"]
  figure["figure"] --> figure_menu["figure_menu"]
  figure["figure"] --> figure_style["figure_style"]
  figure["figure"] --> figure_texture["figure_texture"]
```
