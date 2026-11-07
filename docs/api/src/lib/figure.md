---
title: figure
---

# figure

> FIGURE, Fortran Immediate-mode GUI for User interfaces, Rendering and Exploration.

 Umbrella module: `use figure` gives the application loop (figure_app), the Dear ImGui widgets (figure_imgui),
 menus, popups and shortcuts (figure_menu), groups of widgets (figure_group: child regions, collapsing headers, tabs,
 tables, trees, id scopes, disabled blocks), docking (figure_dock), the style colours and variables by name (figure_style),
 the ImPlot plots (figure_implot): items, heatmaps, images, their style (`ip_spec`) and ImPlot's constants, and the
 GPU textures (figure_texture) that `ig_image` and `ip_image` draw, and the Lucide icons by name, `ICON_*`
 (figure_icons), UTF-8 strings for any label: `ig_button(ICON_PLAY//' Run')`; programs started from the program and
 a view of their output (figure_process: `process_object`, `log_view_object`); Fortran procedures run on a worker
 thread (figure_task: `task_object`, `task_handle_object`); 3-D views of meshes (figure_view3d: `view3d_object`).

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
  figure["figure"] --> figure_icons["figure_icons"]
  figure["figure"] --> figure_imgui["figure_imgui"]
  figure["figure"] --> figure_implot["figure_implot"]
  figure["figure"] --> figure_menu["figure_menu"]
  figure["figure"] --> figure_process["figure_process"]
  figure["figure"] --> figure_style["figure_style"]
  figure["figure"] --> figure_task["figure_task"]
  figure["figure"] --> figure_texture["figure_texture"]
  figure["figure"] --> figure_view3d["figure_view3d"]
```
