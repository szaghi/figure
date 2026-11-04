!< cb_field, cookbook: a 2D field as a heatmap with its colour scale, and an RGBA image as a texture.
program cb_field
!< cb_field, cookbook: a 2D field as a heatmap with its colour scale, and an RGBA image as a texture.
use, intrinsic :: iso_fortran_env, only : int8, int32, real64
use figure, only : app_object, ig_begin, ig_end, ig_image, ig_same_line, ig_set_next_window, ig_text, ip_begin_plot, &
                   ip_colormap_scale, ip_end_plot, ip_heatmap, ip_image, ip_setup_axes, ImPlotColormap_Viridis,   &
                   texture_object

implicit none
integer(int32), parameter :: NX = 120_int32 !< Cells along x.
integer(int32), parameter :: NY = 80_int32  !< Cells along y.
type(app_object)          :: app            !< Application.
real(real64)              :: f(NX, NY)      !< Field: f(i, j) at x(i), y(j).
real(real64)              :: x(NX)          !< Cell centres along x, in [0, 1.5].
real(real64)              :: y(NY)          !< Cell centres along y, in [0, 1].
integer(int8)             :: rgba(4, 4, 4)  !< A 4 x 4 image: row 1 red, row 4 blue.
type(texture_object)      :: tex            !< The image on the GPU.
integer(int32)            :: i              !< Counter.
integer(int32)            :: j              !< Counter.

x = [((real(i, real64) - 0.5_real64) * 1.5_real64 / real(NX, real64), i = 1_int32, NX)]
y = [((real(j, real64) - 0.5_real64) / real(NY, real64), j = 1_int32, NY)]
do j = 1_int32, NY
   do i = 1_int32, NX
      f(i, j) = exp(-((x(i) - 0.25_real64)**2 + (y(j) - 0.75_real64)**2) / 0.02_real64) ! peak at top left
   enddo
enddo

call app%init('FIGURE: field and image', 1000_int32, 640_int32)
rgba = 0_int8
rgba(4,:,:) = -1_int8                       ! alpha 255 (int8 bit pattern of 255)
rgba(1,:,1) = -1_int8                       ! row 1: red
rgba(3,:,4) = -1_int8                       ! row 4: blue
call tex%init(4_int32, 4_int32)             ! after app%init: textures live on the GPU of the window
call tex%update(rgba)                       ! one upload; redo it only when the pixels change
do while (app%next_frame())
   call ig_set_next_window(20.0_real64, 20.0_real64, 960.0_real64, 600.0_real64)
   if (ig_begin('Field')) then
      if (ip_begin_plot('f(x, y)', width=700.0_real64, height=-1.0_real64)) then
         call ip_setup_axes('x', 'y')
         call ip_heatmap('f', f, 0.0_real64, 1.5_real64, 0.0_real64, 1.0_real64, scale_min=0.0_real64, &
                         scale_max=1.0_real64, colormap=ImPlotColormap_Viridis)
         call ip_image('image', tex, 1.2_real64, 1.4_real64, 0.05_real64, 0.25_real64)  ! row 1 at the bottom
         call ip_end_plot()
      endif
      call ig_same_line()
      call ip_colormap_scale('##f scale', 0.0_real64, 1.0_real64, height=-1.0_real64, colormap=ImPlotColormap_Viridis)
      call ig_same_line()
      call ig_text('ig_image:')
      call ig_same_line()
      call ig_image(tex, 64.0_real64, 64.0_real64)                                   ! row 1 at the top
   endif
   call ig_end()
enddo
call tex%destroy()
call app%destroy()
endprogram cb_field
