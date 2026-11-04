---
title: figure_texture
---

# figure_texture

> figure_texture, RGBA images on the GPU, drawn by `ig_image` and `ip_image`.

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

**Source**: `src/lib/figure_texture.F90`

**Dependencies**

```mermaid
graph LR
  figure_texture["figure_texture"] --> figure_base["figure_base"]
  figure_texture["figure_texture"] --> figure_c_native["figure_c_native"]
  figure_texture["figure_texture"] --> figure_cimgui["figure_cimgui"]
  figure_texture["figure_texture"] --> iso_c_binding["iso_c_binding"]
  figure_texture["figure_texture"] --> iso_fortran_env["iso_fortran_env"]
```

## Contents

- [texture_object](#texture-object)
- [init](#init)
- [update](#update)
- [destroy](#destroy)
- [width](#width)
- [height](#height)
- [is_initialized](#is-initialized)
- [texture_ref](#texture-ref)

## Derived Types

### texture_object

An RGBA texture, 8 bits per channel.

 No finaliser: an intrinsic assignment or a function result would finalise a copy and destroy the texture the
 original still uses. Call `destroy` (or let `app%destroy` release the textures left).

#### Components

| Name | Type | Attributes | Description |
|------|------|------------|-------------|
| `id` | integer(kind=c_long_long) |  | ImTextureID; 0: no texture. |
| `nx` | integer(kind=int32) |  | Width [pixels]. |
| `ny` | integer(kind=int32) |  | Height [pixels]. |

#### Type-Bound Procedures

| Name | Attributes | Description |
|------|------------|-------------|
| `init` | pass(self) | Create the texture. |
| `update` | pass(self) | Upload all its pixels. |
| `destroy` | pass(self) | Release it. |
| `width` | pass(self) | Width [pixels]. |
| `height` | pass(self) | Height [pixels]. |
| `is_initialized` | pass(self) | Whether it exists. |

## Subroutines

### init

Create a `width` x `height` texture (contents undefined until `update`); an existing one is destroyed first.

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
flowchart TD
  init["init"] --> destroy["destroy"]
  init["init"] --> fig_texture_create["fig_texture_create"]
  init["init"] --> figure_check["figure_check"]
  style init fill:#3e63dd,stroke:#99b,stroke-width:2px
```

### update

Upload all the pixels, `rgba(4, width, height)`, in place (no copy); the array may change after the call.

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
flowchart TD
  update["update"] --> fig_texture_update["fig_texture_update"]
  update["update"] --> figure_check["figure_check"]
  update["update"] --> figure_fail["figure_fail"]
  style update fill:#3e63dd,stroke:#99b,stroke-width:2px
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
flowchart TD
  init["init"] --> destroy["destroy"]
  destroy["destroy"] --> fig_texture_destroy["fig_texture_destroy"]
  style destroy fill:#3e63dd,stroke:#99b,stroke-width:2px
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
flowchart TD
  ig_image["ig_image"] --> width["width"]
  style width fill:#3e63dd,stroke:#99b,stroke-width:2px
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
flowchart TD
  ig_image["ig_image"] --> height["height"]
  style height fill:#3e63dd,stroke:#99b,stroke-width:2px
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
flowchart TD
  ip_image["ip_image"] --> is_initialized["is_initialized"]
  style is_initialized fill:#3e63dd,stroke:#99b,stroke-width:2px
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
flowchart TD
  ig_image["ig_image"] --> texture_ref["texture_ref"]
  ip_image["ip_image"] --> texture_ref["texture_ref"]
  style texture_ref fill:#3e63dd,stroke:#99b,stroke-width:2px
```
