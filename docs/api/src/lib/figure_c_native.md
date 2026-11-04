---
title: figure_c_native
---

# figure_c_native

> figure_c_native, the raw C interfaces: FIGURE's native glue and the cimgui/cimplot functions bound directly.

 Private to the library: applications use figure_app, figure_imgui and figure_implot. A C function is bound here
 directly only if all its arguments are scalars, pointers or the two-float `ImVec2_c`; functions taking larger
 structs by value (e.g. `ImPlotSpec_c`) go through the glue (native/figure_native.cpp), which builds them in C++.
 Strings passed to cimgui/cimplot must be NUL-terminated; strings passed to the glue are (pointer, length).

**Source**: `src/lib/figure_c_native.F90`

**Dependencies**

```mermaid
graph LR
  figure_c_native["figure_c_native"] --> iso_c_binding["iso_c_binding"]
```

## Contents

- [im_vec2](#im-vec2)
- [fig_init](#fig-init)
- [fig_init_headless](#fig-init-headless)
- [fig_begin_frame](#fig-begin-frame)
- [fig_end_frame](#fig-end-frame)
- [fig_content_scale](#fig-content-scale)
- [fig_last_error](#fig-last-error)
- [fig_plot_line](#fig-plot-line)
- [igBegin](#igbegin)
- [igButton](#igbutton)
- [igCheckbox](#igcheckbox)
- [igSliderScalar](#igsliderscalar)
- [igInputDouble](#iginputdouble)
- [igGetItemRectMin](#iggetitemrectmin)
- [igGetItemRectMax](#iggetitemrectmax)
- [ImPlot_BeginPlot](#implot-beginplot)
- [fig_shutdown](#fig-shutdown)
- [fig_set_lazy](#fig-set-lazy)
- [fig_request_frames](#fig-request-frames)
- [fig_set_last_error](#fig-set-last-error)
- [fig_input_mouse](#fig-input-mouse)
- [igEnd](#igend)
- [igTextUnformatted](#igtextunformatted)
- [igSameLine](#igsameline)
- [igSeparator](#igseparator)
- [igShowDemoWindow](#igshowdemowindow)
- [igSetNextWindowPos](#igsetnextwindowpos)
- [igSetNextWindowSize](#igsetnextwindowsize)
- [ImPlot_EndPlot](#implot-endplot)
- [ImPlot_SetupAxes](#implot-setupaxes)

## Variables

| Name | Type | Attributes | Description |
|------|------|------------|-------------|
| `FIG_OK` | integer(kind=c_int) | parameter | Success. |
| `FIG_ERR_STATE` | integer(kind=c_int) | parameter | Call not allowed in the current state. |
| `FIG_ERR_ARGUMENT` | integer(kind=c_int) | parameter | Invalid argument. |
| `FIG_ERR_FAILED` | integer(kind=c_int) | parameter | The platform (SDL, OpenGL) reported a failure. |
| `FIG_ERR_EXCEPTION` | integer(kind=c_int) | parameter | A C++ exception was caught at the boundary. |
| `IMGUI_DATATYPE_S32` | integer(kind=c_int) | parameter | ImGuiDataType_S32. |
| `IMGUI_DATATYPE_FLOAT` | integer(kind=c_int) | parameter | ImGuiDataType_Float. |
| `IMGUI_DATATYPE_DOUBLE` | integer(kind=c_int) | parameter | ImGuiDataType_Double. |
| `IMGUI_COND_ALWAYS` | integer(kind=c_int) | parameter | ImGuiCond_Always. |
| `IMGUI_COND_ONCE` | integer(kind=c_int) | parameter | ImGuiCond_Once. |
| `IMGUI_COND_FIRST_USE_EVER` | integer(kind=c_int) | parameter | ImGuiCond_FirstUseEver. |

## Derived Types

### im_vec2

ImVec2_c: a 2D vector of floats, passed by value.

**Attributes**: bind(C)

#### Components

| Name | Type | Attributes | Description |
|------|------|------------|-------------|
| `x` | real(kind=c_float) |  | Abscissa. |
| `y` | real(kind=c_float) |  | Ordinate. |

## Interfaces

### fig_init

### fig_init_headless

### fig_begin_frame

### fig_end_frame

### fig_content_scale

### fig_last_error

### fig_plot_line

### igBegin

### igButton

### igCheckbox

### igSliderScalar

### igInputDouble

### igGetItemRectMin

### igGetItemRectMax

### ImPlot_BeginPlot

### fig_shutdown

### fig_set_lazy

### fig_request_frames

### fig_set_last_error

### fig_input_mouse

### igEnd

### igTextUnformatted

### igSameLine

### igSeparator

### igShowDemoWindow

### igSetNextWindowPos

### igSetNextWindowSize

### ImPlot_EndPlot

### ImPlot_SetupAxes
