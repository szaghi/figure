!< figure_plot_transform, how a plot's items map a value to a pixel: ImPlot's `Transformer1`, shared by frame and items.
module figure_plot_transform
!< figure_plot_transform, how a plot's items map a value to a pixel: ImPlot's `Transformer1`, shared by frame and items.
!<
!< szaghi/figure#15 P11. An axis as an item sees it on a frame (`plot_axis_map`: the pixel of the range's minimum, the
!< range, pixels per unit, the scale and its transformed range) and the pixel of a value (`map_pixel`): on a log10 or
!< symlog axis the value's place in the transformed range mapped back onto the range first, then
!< `(float)(PixMin + M (p - PltMin))`, the products in statements of their own (nvfortran -O2 fuses `a*b + c` into
!< an FMA; ImPlot's build does not). figure_plot_frame fills the maps of the current axes for its items
!< (figure_plot_items) and computes its own `PlotToPixels` with them.
use, intrinsic :: iso_fortran_env, only : int32, real32, real64
use figure_plot_locators, only : transform_log10, transform_symlog

implicit none
private
public :: plot_axis_map, map_pixel
public :: MAP_LINEAR, MAP_TIME, MAP_LOG10, MAP_SYMLOG

integer(int32), parameter :: MAP_LINEAR = 0_int32 !< ImPlotScale_Linear.
integer(int32), parameter :: MAP_TIME = 1_int32   !< ImPlotScale_Time (no transform).
integer(int32), parameter :: MAP_LOG10 = 2_int32  !< ImPlotScale_Log10.
integer(int32), parameter :: MAP_SYMLOG = 3_int32 !< ImPlotScale_SymLog.

type :: plot_axis_map
   !< An axis as the items map values onto it (`Transformer1`'s fields).
   real(real64)   :: pix_min = 0.0_real64 !< Pixel of the range's minimum (PixelMin, a float).
   real(real64)   :: plt_min = 0.0_real64 !< Range's minimum.
   real(real64)   :: plt_max = 1.0_real64 !< Range's maximum.
   real(real64)   :: m = 1.0_real64       !< Pixels per unit (ScaleToPixel).
   real(real64)   :: sca_min = 0.0_real64 !< The transform of the range's minimum (ScaleMin).
   real(real64)   :: sca_max = 1.0_real64 !< ... of its maximum (ScaleMax).
   integer(int32) :: scale = MAP_LINEAR   !< MAP_LINEAR, MAP_TIME, MAP_LOG10, MAP_SYMLOG.
endtype plot_axis_map

contains
   pure function map_pixel(a, v) result(px)
   !< `Transformer1`: the pixel of a value, single precision.
   type(plot_axis_map), intent(in) :: a  !< Axis.
   real(real64),        intent(in) :: v  !< Value.
   real(real32)                    :: px !< Pixel.
   real(real64)                    :: w, s, t !< Value on the range, transformed, its fraction.

   w = v
   if (a%scale == MAP_LOG10 .or. a%scale == MAP_SYMLOG) then
      if (a%scale == MAP_LOG10) then
         s = transform_log10(v)
      else
         s = transform_symlog(v)
      endif
      t = (s - a%sca_min) / (a%sca_max - a%sca_min)
      w = (a%plt_max - a%plt_min) * t
      w = a%plt_min + w
   endif
   w = a%m * (w - a%plt_min)
   px = real(a%pix_min + w, real32)
   endfunction map_pixel
endmodule figure_plot_transform
