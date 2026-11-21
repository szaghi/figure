!< figure_render, the renderer contract: a frame's draw data, the textures, and what a renderer does with them.
module figure_render
!< figure_render, the renderer contract: a frame's draw data, the textures, and what a renderer does with them.
!<
!< szaghi/figure#15 P9 (K3): the renderers of the Fortran path (the CPU renderer, figure_render_cpu; OpenGL 3, later)
!< implement `renderer_object`; the core gives them a `render_frame`. A frame is what Dear ImGui's `ImDrawData` holds,
!< read in place: per list its vertices (`draw_vert`, ImDrawVert's layout) and 16-bit indices, and its commands as a
!< structure of arrays (clip rectangle, texture, vertex and index offsets, index count, and the callbacks a renderer
!< knows: the samplers'). A texture is a `render_texture`: its pixels in place (8 bits a channel, rows from the top,
!< RGBA or alpha only), its size and filter; the frame's `texture_of` finds the pixels of a command's texture.
!< Today figure_render_imgui fills a frame from Dear ImGui's draw data (the core over Dear ImGui, src/paths/imgui/core/);
!< the Fortran core will fill it from its own lists (block E).
!<
!< The contract is kept small enough that a further backend (SDL_GPU, K3, on demand) is one more module: `render`
!< (indexed triangles with scissor rectangles, the samplers' callbacks), and textures created, updated and destroyed
!< (`texture_create`, `texture_update`, `texture_destroy`: no-ops for a renderer that reads the pixels in place).
use, intrinsic :: iso_c_binding, only : c_float, c_int16_t, c_long_long, c_ptr
use, intrinsic :: iso_fortran_env, only : int8, int32, int64
use figure_drawlist, only : draw_vert

implicit none
private
public :: render_texture, render_list, render_frame, renderer_object
public :: RENDER_DRAW, RENDER_RESET, RENDER_SAMPLER_FROM_TEXTURE, RENDER_SAMPLER_LINEAR, RENDER_SAMPLER_NEAREST
public :: RENDER_CALLBACK

integer(int32), parameter :: RENDER_DRAW = 0_int32                 !< A command: indexed triangles.
integer(int32), parameter :: RENDER_RESET = 1_int32                !< The sampler reset (linear, Dear ImGui's state).
integer(int32), parameter :: RENDER_SAMPLER_FROM_TEXTURE = 2_int32 !< The sampler: each texture's own filter.
integer(int32), parameter :: RENDER_SAMPLER_LINEAR = 3_int32       !< The sampler: linear.
integer(int32), parameter :: RENDER_SAMPLER_NEAREST = 4_int32      !< The sampler: nearest.
integer(int32), parameter :: RENDER_CALLBACK = 5_int32             !< A program's own callback (drawn by no renderer
                                                                   !< here).

type :: render_texture
   !< A texture's pixels as a renderer reads them, in place.
   integer(int32)                       :: width = 0_int32    !< Width [pixels].
   integer(int32)                       :: height = 0_int32   !< Height [pixels].
   integer(int32)                       :: channels = 4_int32 !< 4: RGBA; 1: alpha only (white).
   integer(int8), pointer, contiguous   :: pixels(:) => null() !< width * height * channels bytes, rows from the top.
   logical                              :: smooth = .true.    !< Its own filter: linear (true) or nearest.
endtype render_texture

type :: render_list
   !< A draw list: its buffers in place, its commands as a structure of arrays.
   type(draw_vert),    pointer, contiguous :: vtx(:) => null() !< Vertices, 1-based (Dear ImGui's index + 1).
   integer(c_int16_t), pointer, contiguous :: idx(:) => null() !< Indices, 16-bit unsigned in their bits.
   integer(int32)                          :: ncmd = 0_int32   !< Commands.
   real(c_float),        allocatable       :: clip(:,:)        !< (4, ncmd): x0, y0, x1, y1 [display pixels].
   type(c_ptr),          allocatable       :: tex_data(:)      !< Dear ImGui's own texture of each command, or null.
   integer(c_long_long), allocatable       :: tex_id(:)        !< ... else its texture id.
   integer(int32),       allocatable       :: vtx_offset(:)    !< First vertex (0-based) its indices count from.
   integer(int32),       allocatable       :: idx_offset(:)    !< First index (0-based).
   integer(int32),       allocatable       :: count(:)         !< Indices.
   integer(int32),       allocatable       :: kind(:)          !< RENDER_DRAW or a callback (RENDER_RESET, ...).
endtype render_list

type :: render_frame
   !< A frame's draw data: the view and the lists, in drawing order.
   real(c_float)                  :: pos(2) = 0.0_c_float      !< Display position [pixels].
   real(c_float)                  :: size(2) = 0.0_c_float     !< Display size [pixels].
   real(c_float)                  :: fb_scale(2) = 1.0_c_float !< Framebuffer pixels per display pixel.
   integer(int32)                 :: nlists = -1_int32         !< Lists (-1: no valid frame).
   type(render_list), allocatable :: lists(:)                  !< The lists.
   procedure(texture_lookup), pointer, nopass :: texture_of => null() !< The pixels of a command's texture.
endtype render_frame

type, abstract :: renderer_object
   !< A renderer: draws a frame; keeps the textures it needs.
   contains
      procedure(render_interface), deferred :: render  !< Draw a frame.
      procedure                             :: texture_create  !< A texture created (default: nothing kept).
      procedure                             :: texture_update  !< A texture's pixels changed.
      procedure                             :: texture_destroy !< A texture destroyed.
endtype renderer_object

abstract interface
   subroutine render_interface(self, frame, width, height, clear, rgb)
   !< Draw `frame` into an RGB picture of width x height pixels (rows from the top), first cleared to `clear`.
   import :: renderer_object, render_frame, int8, int32, c_float
   class(renderer_object), intent(inout) :: self      !< Renderer.
   type(render_frame),     intent(in)    :: frame     !< Frame.
   integer(int32),         intent(in)    :: width     !< Width [pixels].
   integer(int32),         intent(in)    :: height    !< Height [pixels].
   real(c_float),          intent(in)    :: clear(3)  !< Clear colour, RGB in [0, 1].
   integer(int8),          intent(inout) :: rgb(:)    !< Picture, 3 * width * height bytes.
   endsubroutine render_interface

   function texture_lookup(tex_data, tex_id, tex) result(found)
   !< The pixels of a texture: Dear ImGui's own (`tex_data` not null) or a user texture by its id.
   import :: c_ptr, c_long_long, render_texture
   type(c_ptr),          intent(in)  :: tex_data !< Dear ImGui's texture, or null.
   integer(c_long_long), intent(in)  :: tex_id   !< Else the texture's id.
   type(render_texture), intent(out) :: tex      !< Its pixels.
   logical                           :: found    !< It has pixels.
   endfunction texture_lookup
endinterface

contains
   subroutine texture_create(self, id, tex)
   !< A texture created: a renderer that keeps its own copy (a GPU's) makes it here; the default keeps nothing.
   class(renderer_object), intent(inout) :: self !< Renderer.
   integer(int64),         intent(in)    :: id   !< Texture id.
   type(render_texture),   intent(in)    :: tex  !< Its pixels.

   associate(s => self, i => id, t => tex)
   endassociate
   endsubroutine texture_create

   subroutine texture_update(self, id, tex)
   !< A texture's pixels changed (default: nothing kept, nothing to do).
   class(renderer_object), intent(inout) :: self !< Renderer.
   integer(int64),         intent(in)    :: id   !< Texture id.
   type(render_texture),   intent(in)    :: tex  !< Its pixels.

   associate(s => self, i => id, t => tex)
   endassociate
   endsubroutine texture_update

   subroutine texture_destroy(self, id)
   !< A texture destroyed (default: nothing kept, nothing to do).
   class(renderer_object), intent(inout) :: self !< Renderer.
   integer(int64),         intent(in)    :: id   !< Texture id.

   associate(s => self, i => id)
   endassociate
   endsubroutine texture_destroy
endmodule figure_render
