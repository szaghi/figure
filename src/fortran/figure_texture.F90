!< figure_texture, RGBA images on the GPU, drawn by `ig_image` and `ip_image`, and PNG or JPEG files read into pixels.
module figure_texture
!< figure_texture, RGBA images on the GPU, drawn by `ig_image` and `ip_image`, and PNG or JPEG files read into pixels.
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
!<
!< `fig_read_image(path, rgba)` reads a PNG or a JPEG file into such an array (allocated to `rgba(4, width, height)`,
!< row 1 the file's top row); it draws nothing, so a task may call it. `tex%load(path)` reads a file into a texture.
use, intrinsic :: iso_c_binding, only : c_f_pointer, c_int, c_loc, c_long_long, c_null_ptr, c_ptr
use, intrinsic :: iso_fortran_env, only : int8, int32, int64
use figure_base, only : figure_check, figure_fail, figure_last_error, figure_refused
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_ERR_FAILED, FIG_ERR_STATE, FIG_OK, fig_image_free, fig_image_read, &
                            fig_texture_create, fig_texture_destroy, fig_texture_update
use figure_cimgui, only : im_texture_ref

implicit none
private
public :: texture_object, texture_ref, fig_read_image

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
      procedure, pass(self) :: load           !< Create it from a PNG or JPEG file.
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

   recursive subroutine load(self, path, smooth, stat)
   !< Create the texture from a PNG or JPEG file, its size the image's, and upload the pixels (`fig_read_image`, then
   !< `init` and `update`); an existing texture is replaced. On a failure to read the file the texture is left as it
   !< was. Main thread only, as `init`.
   class(texture_object), intent(inout)         :: self        !< Texture.
   character(len=*),      intent(in)            :: path        !< File name (UTF-8).
   logical,               intent(in),  optional :: smooth      !< Linear filtering when scaled (default: nearest).
   integer(int32),        intent(out), optional :: stat        !< Status: as `fig_read_image`, then as `init`.
   integer(int8), allocatable, target           :: rgba(:,:,:) !< The image's pixels.
   integer(int32)                               :: s           !< Status of a step.

   if (figure_refused('texture_object%load', stat)) return ! a task does not draw
   call read_image('texture_object%load', path, rgba, s)
   if (s /= FIG_OK) then
      call figure_check(int(s, c_int), stat)
      return
   endif
   call self%init(int(size(rgba, 2), int32), int(size(rgba, 3), int32), smooth, s)
   if (s == FIG_OK) call self%update(rgba, s)
   call figure_check(int(s, c_int), stat)
   endsubroutine load

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

   recursive subroutine fig_read_image(path, rgba, stat)
   !< Read a PNG or JPEG file into RGBA pixels: `rgba` is allocated to `rgba(4, width, height)`, `rgba(:, i, j)` the
   !< red, green, blue and alpha bytes of the pixel in column `i` (left to right) and row `j` (**top to bottom**, the
   !< file's order), the layout `tex%update` takes. A grey image gives R = G = B; an image without alpha gives A = 255
   !< (-1_int8). Draws nothing: a task may call it. On a failure `rgba` is left unallocated.
   character(len=*),           intent(in)            :: path        !< File name (UTF-8).
   integer(int8), allocatable, intent(out)           :: rgba(:,:,:) !< Pixels: rgba(:, i, j) = R, G, B, A of (i, j).
   integer(int32),             intent(out), optional :: stat        !< Status: `FIG_ERR_FAILED` if the file cannot be
                                                                    !< read, `FIG_ERR_ARGUMENT` if it is not a PNG or a
                                                                    !< JPEG, or cannot be decoded.
   integer(int32)                                    :: s           !< Status.

   call read_image('fig_read_image', path, rgba, s)
   call figure_check(int(s, c_int), stat)
   endsubroutine fig_read_image

   recursive subroutine read_image(name, path, rgba, stat)
   !< `fig_read_image` for the procedure `name`, which starts the message of a failure.
   character(len=*),           intent(in)  :: name        !< The public procedure.
   character(len=*),           intent(in)  :: path        !< File name (UTF-8).
   integer(int8), allocatable, intent(out) :: rgba(:,:,:) !< Pixels.
   integer(int32),             intent(out) :: stat        !< Status.
   type(c_ptr)                             :: p           !< The decoder's pixels.
   integer(int8), pointer                  :: q(:,:,:)    !< The same, as an array.
   integer(c_int)                          :: w           !< Width [pixels].
   integer(c_int)                          :: h           !< Height [pixels].
   integer(c_int)                          :: status      !< Native status.
   integer(int32)                          :: ierr        !< Allocation status.

   status = fig_image_read(path, len(path, c_int), p, w, h)
   if (status /= FIG_OK) then
      call figure_fail(status, name//': '//figure_last_error(), stat)
      return
   endif
   call c_f_pointer(p, q, [4_int64, int(w, int64), int(h, int64)])
   allocate(rgba(4, w, h), stat=ierr)
   if (ierr /= 0) then
      call fig_image_free(p)
      call figure_fail(FIG_ERR_FAILED, name//": '"//path//"': out of memory", stat)
      return
   endif
   rgba(:,:,:) = q
   call fig_image_free(p)
   stat = int(FIG_OK, int32)
   endsubroutine read_image

   pure function texture_ref(tex) result(ref)
   !< The `ImTextureRef` of a texture, for the figure_* modules that draw it (not exported by `figure`).
   type(texture_object), intent(in) :: tex !< Texture.
   type(im_texture_ref)             :: ref !< Reference: user texture, by id.

   ref%TexData = c_null_ptr
   ref%TexID = tex%id
   endfunction texture_ref
endmodule figure_texture
