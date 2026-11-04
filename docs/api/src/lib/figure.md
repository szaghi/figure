---
title: figure
---

# figure

> FIGURE, Fortran Immediate-mode GUI for User interfaces, Rendering and Exploration.

 Umbrella module: `use figure` gives the application loop (figure_app), the Dear ImGui widgets (figure_imgui) and
 the ImPlot plots (figure_implot).

**Source**: `src/lib/figure.F90`

**Dependencies**

```mermaid
graph LR
  figure["figure"] --> figure_app["figure_app"]
  figure["figure"] --> figure_base["figure_base"]
  figure["figure"] --> figure_c_native["figure_c_native"]
  figure["figure"] --> figure_imgui["figure_imgui"]
  figure["figure"] --> figure_implot["figure_implot"]
```
