!< figure_texture, RGBA images on the GPU, drawn by `ig_image` and `ip_image`.
module figure_texture
!< figure_texture, RGBA images on the GPU, drawn by `ig_image` and `ip_image`.
!<
!< A texture is the one retained resource of FIGURE: the image lives on the GPU between frames, so the program uploads
!< pixels only when they change, not every frame.
!<
!<```fortran
!< type(texture_object) :: tex
!< integer(int8)        :: rgba(4, 640, 480)    ! rgba(:, i, j): pixel (i, j), channels R, G, B, A
!< call tex%init(640, 480)
!< call tex%update(rgba)                       ! one upload, straight from the array: no copy
!< ... call ig_image(tex) or ip_image('field', tex, xmin, xmax, ymin, ymax) every frame
!< call tex%destroy()
!<```
!<
!< Pixels are `integer(int8)` bytes: values 128-255 are stored as their two's-complement bit pattern (-128..-1), so
!< `int(v - merge(256, 0, v > 127), int8)` converts a 0-255 integer `v`. `rgba(:, i, j)` is the pixel in column `i` and
!< row `j`: in Fortran's column-major order that is exactly OpenGL's layout (channels, then a row, then the next row),
!< so the array is uploaded in place.
use, intrinsic :: iso_c_binding, only : c_int, c_loc, c_long_long, c_null_ptr
use, intrinsic :: iso_fortran_env, only : int8, int32, int64
use figure_base, only : figure_check, figure_fail, figure_refused
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK, fig_texture_create, fig_texture_destroy, fig_texture_update
use figure_cimgui, only : im_texture_ref

implicit none
private
public :: texture_object, texture_ref

type :: texture_object
   !< An RGBA texture, 8 bits per channel.
   !<
   !< No finaliser: an intrinsic assignment or a function result would finalise a copy and destroy the texture the
   !< original still uses. Call `destroy` (or let `app%destroy` release the textures left).
   integer(c_long_long), private :: id = 0_c_long_long     !< ImTextureID; 0: no texture.
   integer(int32),       private :: nx = 0_int32           !< Width [pixels].
   integer(int32),       private :: ny = 0_int32           !< Height [pixels].
   contains
      procedure, pass(self) :: init           !< Create the texture.
      procedure, pass(self) :: update         !< Upload all its pixels.
      procedure, pass(self) :: destroy        !< Release it.
      procedure, pass(self) :: width          !< Width [pixels].
      procedure, pass(self) :: height         !< Height [pixels].
      procedure, pass(self) :: is_initialized !< Whether it exists.
endtype texture_object

contains
   recursive subroutine init(self, width, height, smooth, stat)
   !< Create a `width` x `height` texture (contents undefined until `update`); an existing one is destroyed first.
   class(texture_object), intent(inout)         :: self   !< Texture.
   integer(int32),        intent(in)            :: width  !< Width [pixels].
   integer(int32),        intent(in)            :: height !< Height [pixels].
   logical,               intent(in),  optional :: smooth !< Linear filtering when scaled (default: nearest, sharp pixels).
   integer(int32),        intent(out), optional :: stat   !< Status.
   integer(c_int)                               :: s      !< Filtering flag.
   integer(c_int)                               :: status !< Native status.

   if (figure_refused('texture_object%init', stat)) return ! a task does not draw
   call self%destroy()
   s = 0_c_int
   if (present(smooth)) s = merge(1_c_int, 0_c_int, smooth)
   status = fig_texture_create(int(width, c_int), int(height, c_int), s, self%id)
   if (status == FIG_OK) then
      self%nx = width
      self%ny = height
   endif
   call figure_check(status, stat)
   endsubroutine init

   recursive subroutine update(self, rgba, stat)
   !< Upload all the pixels, `rgba(4, width, height)`, in place (no copy); the array may change after the call.
   class(texture_object), intent(in)                     :: self       !< Texture.
   integer(int8),         intent(in), contiguous, target :: rgba(:,:,:) !< Pixels: rgba(:, i, j) = R, G, B, A of (i, j).
   integer(int32),        intent(out), optional          :: stat       !< Status.

   if (figure_refused('texture_object%update', stat)) return ! a task does not draw
   if (self%id == 0_c_long_long) then
      call figure_fail(FIG_ERR_STATE, 'texture%update: the texture is not initialized', stat)
      return
   endif
   if (size(rgba, 1, kind=int64) /= 4_int64 .or. size(rgba, 2, kind=int64) /= int(self%nx, int64) .or. &
       size(rgba, 3, kind=int64) /= int(self%ny, int64)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'texture%update: pixels must be rgba(4, width, height)', stat)
      return
   endif
   call figure_check(fig_texture_update(self%id, int(self%nx, c_int), int(self%ny, c_int), c_loc(rgba)), stat)
   endsubroutine update

   subroutine destroy(self)
   !< Release the texture (safe in any state).
   class(texture_object), intent(inout) :: self !< Texture.

   if (self%id /= 0_c_long_long) call fig_texture_destroy(self%id)
   self%id = 0_c_long_long
   self%nx = 0_int32
   self%ny = 0_int32
   endsubroutine destroy

   pure function width(self) result(w)
   !< Width [pixels] (0 when not initialized).
   class(texture_object), intent(in) :: self !< Texture.
   integer(int32)                    :: w    !< Width.

   w = self%nx
   endfunction width

   pure function height(self) result(h)
   !< Height [pixels] (0 when not initialized).
   class(texture_object), intent(in) :: self !< Texture.
   integer(int32)                    :: h    !< Height.

   h = self%ny
   endfunction height

   pure function is_initialized(self) result(yes)
   !< Whether the texture exists.
   class(texture_object), intent(in) :: self !< Texture.
   logical                           :: yes  !< Initialized.

   yes = self%id /= 0_c_long_long
   endfunction is_initialized

   pure function texture_ref(tex) result(ref)
   !< The `ImTextureRef` of a texture, for the figure_* modules that draw it (not exported by `figure`).
   type(texture_object), intent(in) :: tex !< Texture.
   type(im_texture_ref)             :: ref !< Reference: user texture, by id.

   ref%TexData = c_null_ptr
   ref%TexID = tex%id
   endfunction texture_ref
endmodule figure_texture
