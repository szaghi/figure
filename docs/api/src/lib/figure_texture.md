---
title: figure_texture
outline: [2, 4]
---

# figure_texture

> figure_texture, RGBA images on the GPU, drawn by `ig_image` and `ip_image`, and PNG or JPEG files read into pixels.

 A texture is the one retained resource of FIGURE: the image lives on the GPU between frames, so the program uploads
 pixels only when they change, not every frame.

```fortran
 type(texture_object) :: tex
 integer(int8)        :: rgba(4, 640, 480)    ! rgba(:, i, j): pixel (i, j), channels R, G, B, A
 call tex%init(640, 480)
 call tex%update(rgba)                       ! one upload, straight from the array: no copy
 ... call ig_image(tex) or ip_image('field', tex, xmin, xmax, ymin, ymax) every frame
 call tex%destroy()
```

 Pixels are `integer(int8)` bytes: values 128-255 are stored as their two's-complement bit pattern (-128..-1), so
 `int(v - merge(256, 0, v > 127), int8)` converts a 0-255 integer `v`. `rgba(:, i, j)` is the pixel in column `i` and
 row `j`: in Fortran's column-major order that is exactly OpenGL's layout (channels, then a row, then the next row),
 so the array is uploaded in place.

 `fig_read_image(path, rgba)` reads a PNG or a JPEG file into such an array (allocated to `rgba(4, width, height)`,
 row 1 the file's top row); it draws nothing, so a task may call it. `tex%load(path)` reads a file into a texture.

**Source**: `src/lib/figure_texture.F90`

**Dependencies**

```mermaid
graph LR
  figure_texture["figure_texture"] --> figure_base["figure_base"]
  figure_texture["figure_texture"] --> figure_c_native["figure_c_native"]
  figure_texture["figure_texture"] --> figure_cimgui["figure_cimgui"]
  figure_texture["figure_texture"] --> iso_c_binding["iso_c_binding"]
  figure_texture["figure_texture"] --> iso_fortran_env["iso_fortran_env"]
  click figure_base href "figure_base.html" "figure_base"
  click figure_c_native href "figure_c_native.html" "figure_c_native"
  click figure_cimgui href "figure_cimgui.html" "figure_cimgui"
```

## Contents

- [texture_object](#texture-object)
- [init](#init)
- [update](#update)
- [load](#load)
- [destroy](#destroy)
- [fig_read_image](#fig-read-image)
- [read_image](#read-image)
- [width](#width)
- [height](#height)
- [is_initialized](#is-initialized)
- [texture_ref](#texture-ref)

## Derived Types

### texture_object

An RGBA texture, 8 bits per channel.

 No finaliser: an intrinsic assignment or a function result would finalise a copy and destroy the texture the
 original still uses. Call `destroy` (or let `app%destroy` release the textures left).

**Components**

| Name | Type | Attributes | Description |
|------|------|------------|-------------|
| `id` | integer(kind=c_long_long) |  | ImTextureID; 0: no texture. |
| `nx` | integer(kind=int32) |  | Width [pixels]. |
| `ny` | integer(kind=int32) |  | Height [pixels]. |

**Type-Bound Procedures**

| Name | Attributes | Description |
|------|------------|-------------|
| [`init`](/api/src/lib/figure_texture#init) | pass(self) | Create the texture. |
| [`update`](/api/src/lib/figure_texture#update) | pass(self) | Upload all its pixels. |
| [`load`](/api/src/lib/figure_texture#load) | pass(self) | Create it from a PNG or JPEG file. |
| [`destroy`](/api/src/lib/figure_texture#destroy) | pass(self) | Release it. |
| [`width`](/api/src/lib/figure_texture#width) | pass(self) | Width [pixels]. |
| [`height`](/api/src/lib/figure_texture#height) | pass(self) | Height [pixels]. |
| [`is_initialized`](/api/src/lib/figure_texture#is-initialized) | pass(self) | Whether it exists. |

## Subroutines

### init

Create a `width` x `height` texture (contents undefined until `update`); an existing one is destroyed first.

**Attributes**: recursive

```fortran
subroutine init(self, width, height, smooth, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([texture_object](/api/src/lib/figure_texture#texture-object)) | inout |  | Texture. |
| `width` | integer(kind=int32) | in |  | Width [pixels]. |
| `height` | integer(kind=int32) | in |  | Height [pixels]. |
| `smooth` | logical | in | optional | Linear filtering when scaled (default: nearest, sharp pixels). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart LR
  code_language["code_language"] --> init["init"]
  load["load"] --> init["init"]
  init["init"] --> destroy["destroy"]
  init["init"] --> fig_texture_create["fig_texture_create"]
  init["init"] --> figure_check["figure_check"]
  init["init"] --> figure_refused["figure_refused"]
  classDef focus stroke-width:3px,font-weight:bold
  class init focus
  click code_language href "figure_editor.html#code-language" "code_language"
  click load href "#load" "load"
  click figure_refused href "figure_base.html#figure-refused" "figure_refused"
  click destroy href "#destroy" "destroy"
  click fig_texture_create href "figure_c_native.html#fig-texture-create" "fig_texture_create"
  click figure_check href "figure_base.html#figure-check" "figure_check"
```

### update

Upload all the pixels, `rgba(4, width, height)`, in place (no copy); the array may change after the call.

**Attributes**: recursive

```fortran
subroutine update(self, rgba, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([texture_object](/api/src/lib/figure_texture#texture-object)) | in |  | Texture. |
| `rgba` | integer(kind=int8) | in | contiguous, target | Pixels: rgba(:, i, j) = R, G, B, A of (i, j). |
| `stat` | integer(kind=int32) | out | optional | Status. |

**Call graph**

```mermaid
flowchart LR
  load["load"] --> update["update"]
  update["update"] --> fig_texture_update["fig_texture_update"]
  update["update"] --> figure_check["figure_check"]
  update["update"] --> figure_fail["figure_fail"]
  update["update"] --> figure_refused["figure_refused"]
  classDef focus stroke-width:3px,font-weight:bold
  class update focus
  click load href "#load" "load"
  click figure_refused href "figure_base.html#figure-refused" "figure_refused"
  click figure_fail href "figure_base.html#figure-fail" "figure_fail"
  click figure_check href "figure_base.html#figure-check" "figure_check"
  click fig_texture_update href "figure_c_native.html#fig-texture-update" "fig_texture_update"
```

### load

Create the texture from a PNG or JPEG file, its size the image's, and upload the pixels (`fig_read_image`, then
 `init` and `update`); an existing texture is replaced. On a failure to read the file the texture is left as it
 was. Main thread only, as `init`.

**Attributes**: recursive

```fortran
subroutine load(self, path, smooth, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([texture_object](/api/src/lib/figure_texture#texture-object)) | inout |  | Texture. |
| `path` | character(len=*) | in |  | File name (UTF-8). |
| `smooth` | logical | in | optional | Linear filtering when scaled (default: nearest). |
| `stat` | integer(kind=int32) | out | optional | Status: as `fig_read_image`, then as `init`. |

**Call graph**

```mermaid
flowchart LR
  load["load"] --> figure_check["figure_check"]
  load["load"] --> figure_refused["figure_refused"]
  load["load"] --> init["init"]
  load["load"] --> read_image["read_image"]
  load["load"] --> update["update"]
  classDef focus stroke-width:3px,font-weight:bold
  class load focus
  click figure_refused href "figure_base.html#figure-refused" "figure_refused"
  click read_image href "#read-image" "read_image"
  click figure_check href "figure_base.html#figure-check" "figure_check"
  click init href "#init" "init"
  click update href "#update" "update"
```

### destroy

Release the texture (safe in any state).

```fortran
subroutine destroy(self)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([texture_object](/api/src/lib/figure_texture#texture-object)) | inout |  | Texture. |

**Call graph**

```mermaid
flowchart LR
  editor_init["editor_init"] --> destroy["destroy"]
  init["init"] --> destroy["destroy"]
  init["init"] --> destroy["destroy"]
  view_init["view_init"] --> destroy["destroy"]
  destroy["destroy"] --> fig_texture_destroy["fig_texture_destroy"]
  classDef focus stroke-width:3px,font-weight:bold
  class destroy focus
  click editor_init href "figure_editor.html#editor-init" "editor_init"
  click init href "#init" "init"
  click view_init href "figure_markdown.html#view-init" "view_init"
  click fig_texture_destroy href "figure_c_native.html#fig-texture-destroy" "fig_texture_destroy"
```

### fig_read_image

Read a PNG or JPEG file into RGBA pixels: `rgba` is allocated to `rgba(4, width, height)`, `rgba(:, i, j)` the
 red, green, blue and alpha bytes of the pixel in column `i` (left to right) and row `j` (**top to bottom**, the
 file's order), the layout `tex%update` takes. A grey image gives R = G = B; an image without alpha gives A = 255
 (-1_int8). Draws nothing: a task may call it. On a failure `rgba` is left unallocated.

**Attributes**: recursive

```fortran
subroutine fig_read_image(path, rgba, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `path` | character(len=*) | in |  | File name (UTF-8). |
| `rgba` | integer(kind=int8) | out | allocatable | Pixels: rgba(:, i, j) = R, G, B, A of (i, j). |
| `stat` | integer(kind=int32) | out | optional | read, `FIG_ERR_ARGUMENT` if it is not a PNG or a JPEG, or cannot be decoded. |

**Call graph**

```mermaid
flowchart LR
  read_picture["read_picture"] --> fig_read_image["fig_read_image"]
  fig_read_image["fig_read_image"] --> figure_check["figure_check"]
  fig_read_image["fig_read_image"] --> read_image["read_image"]
  classDef focus stroke-width:3px,font-weight:bold
  class fig_read_image focus
  click read_picture href "figure_testing.html#read-picture" "read_picture"
  click read_image href "#read-image" "read_image"
  click figure_check href "figure_base.html#figure-check" "figure_check"
```

### read_image

`fig_read_image` for the procedure `name`, which starts the message of a failure.

**Attributes**: recursive

```fortran
subroutine read_image(name, path, rgba, stat)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `name` | character(len=*) | in |  | The public procedure. |
| `path` | character(len=*) | in |  | File name (UTF-8). |
| `rgba` | integer(kind=int8) | out | allocatable | Pixels. |
| `stat` | integer(kind=int32) | out |  | Status. |

**Call graph**

```mermaid
flowchart LR
  fig_read_image["fig_read_image"] --> read_image["read_image"]
  load["load"] --> read_image["read_image"]
  read_image["read_image"] --> fig_image_free["fig_image_free"]
  read_image["read_image"] --> fig_image_read["fig_image_read"]
  read_image["read_image"] --> figure_fail["figure_fail"]
  read_image["read_image"] --> figure_last_error["figure_last_error"]
  classDef focus stroke-width:3px,font-weight:bold
  class read_image focus
  click fig_read_image href "#fig-read-image" "fig_read_image"
  click load href "#load" "load"
  click fig_image_read href "figure_c_native.html#fig-image-read" "fig_image_read"
  click figure_fail href "figure_base.html#figure-fail" "figure_fail"
  click figure_last_error href "figure_base.html#figure-last-error" "figure_last_error"
  click fig_image_free href "figure_c_native.html#fig-image-free" "fig_image_free"
```

## Functions

### width

Width [pixels] (0 when not initialized).

**Attributes**: pure

**Returns**: `integer(kind=int32)`

```fortran
function width(self) result(w)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([texture_object](/api/src/lib/figure_texture#texture-object)) | in |  | Texture. |

**Call graph**

```mermaid
flowchart LR
  ig_image["ig_image"] --> width["width"]
  classDef focus stroke-width:3px,font-weight:bold
  class width focus
  click ig_image href "figure_imgui.html#ig-image" "ig_image"
```

### height

Height [pixels] (0 when not initialized).

**Attributes**: pure

**Returns**: `integer(kind=int32)`

```fortran
function height(self) result(h)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([texture_object](/api/src/lib/figure_texture#texture-object)) | in |  | Texture. |

**Call graph**

```mermaid
flowchart LR
  ig_image["ig_image"] --> height["height"]
  classDef focus stroke-width:3px,font-weight:bold
  class height focus
  click ig_image href "figure_imgui.html#ig-image" "ig_image"
```

### is_initialized

Whether the texture exists.

**Attributes**: pure

**Returns**: `logical`

```fortran
function is_initialized(self) result(yes)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `self` | class([texture_object](/api/src/lib/figure_texture#texture-object)) | in |  | Texture. |

**Call graph**

```mermaid
flowchart LR
  ig_canvas["ig_canvas"] --> is_initialized["is_initialized"]
  ig_draw_image["ig_draw_image"] --> is_initialized["is_initialized"]
  ip3_image["ip3_image"] --> is_initialized["is_initialized"]
  ip_image["ip_image"] --> is_initialized["is_initialized"]
  classDef focus stroke-width:3px,font-weight:bold
  class is_initialized focus
  click ig_canvas href "figure_canvas.html#ig-canvas" "ig_canvas"
  click ig_draw_image href "figure_canvas.html#ig-draw-image" "ig_draw_image"
  click ip3_image href "figure_implot3d.html#ip3-image" "ip3_image"
  click ip_image href "figure_implot.html#ip-image" "ip_image"
```

### texture_ref

The `ImTextureRef` of a texture, for the figure_* modules that draw it (not exported by `figure`).

**Attributes**: pure

**Returns**: type([im_texture_ref](/api/src/lib/figure_cimgui#im-texture-ref))

```fortran
function texture_ref(tex) result(ref)
```

**Arguments**

| Name | Type | Intent | Attributes | Description |
|------|------|--------|------------|-------------|
| `tex` | type([texture_object](/api/src/lib/figure_texture#texture-object)) | in |  | Texture. |

**Call graph**

```mermaid
flowchart LR
  ig_canvas["ig_canvas"] --> texture_ref["texture_ref"]
  ig_draw_image["ig_draw_image"] --> texture_ref["texture_ref"]
  ig_image["ig_image"] --> texture_ref["texture_ref"]
  ip3_image["ip3_image"] --> texture_ref["texture_ref"]
  ip_image["ip_image"] --> texture_ref["texture_ref"]
  classDef focus stroke-width:3px,font-weight:bold
  class texture_ref focus
  click ig_canvas href "figure_canvas.html#ig-canvas" "ig_canvas"
  click ig_draw_image href "figure_canvas.html#ig-draw-image" "ig_draw_image"
  click ig_image href "figure_imgui.html#ig-image" "ig_image"
  click ip3_image href "figure_implot3d.html#ip3-image" "ip3_image"
  click ip_image href "figure_implot.html#ip-image" "ip_image"
```
