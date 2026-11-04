---
title: API Reference
---

# API Reference

The [API section](/api/) documents every module, type and procedure, generated from the source comments by
[formal](https://github.com/szaghi/formal):

```bash
cd docs
npm run docs:api      # formal generate --mirror-sources --diagrams --project ford.md --output api
```

`npm run docs:dev` and `npm run docs:build` regenerate it first.

## Public entry point

`use figure` exports:

| Entity | Module | Purpose |
|---|---|---|
| `app_object` | `figure_app` | the application: window, frame loop, lazy redraw — see [Frame loop](frame-loop) |
| `ig_*` | `figure_imgui` | Dear ImGui widgets — see [Widgets](widgets) |
| `ip_*` | `figure_implot` | ImPlot plots — see [Plots](plots) |
| `plot_spec_object`, `ImPlotMarker_*`, `ImPlot*Flags_*` | `figure_implot` | item style (`ip_spec`) and its constants — see [Plots](plots#item-style) |
| `figure_last_error` | `figure_base` | message of the last failure — see [Error handling](errors) |
| `FIG_OK`, `FIG_ERR_*` | `figure_c_native` | status codes |

`figure_c_native` (the glue interfaces) and the generated raw modules `figure_cimgui`, `figure_cimplot`,
`figure_cimgui_enums` and `figure_cimplot_enums` ([Raw bindings](raw-bindings)) are internal and may change without
notice.
