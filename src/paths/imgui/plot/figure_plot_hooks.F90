!< figure_plot_hooks, what FIGURE's other modules ask of the 2-D plots: the canvas's plot layer, the tests' queries.
module figure_plot_hooks
!< figure_plot_hooks, what FIGURE's other modules ask of the 2-D plots: the canvas's plot layer, the tests' queries.
!<
!< Part of the plot seam (szaghi/figure#15, the seam's switch), here over ImPlot through the native layer: what
!< figure_canvas draws on its `'plot'` layer (`plot_layer_draw`: `fig_draw` on layer 4, the current ImPlot plot) and
!< what figure_testing reads of the plots (`plot_tick_label`: a tick label of the plot being declared; the field
!< textures of `ip_field_image`: `plot_field_uploads`, `plot_field_count`, `plot_field_time`, `plot_field_pixel`).
!< The Fortran path's module of the same name answers them from the Fortran plot frame (src/paths/fortran/plot/).
!< Arguments and results are the native layer's, as figure_canvas and figure_testing called it before.
use, intrinsic :: iso_c_binding, only : c_char, c_double, c_float, c_int, c_long_long
use figure_c_native, only : fig_draw, fig_field_count, fig_field_pixel, fig_field_time, fig_field_uploads, &
                            fig_plot_tick_label

implicit none
private
public :: plot_layer_draw, plot_tick_label, plot_field_uploads, plot_field_count, plot_field_time, plot_field_pixel

contains
   function plot_layer_draw(kind, x, y, n, rgba, thickness, radius, filled, text, text_len, texture) result(status)
   !< One drawing primitive in the plot being declared, in plot units (`fig_draw` on the plot layer): FIG_OK, -1
   !< outside a plot.
   integer(c_int),         intent(in) :: kind      !< 1 line, 2 rect, 3 circle, 4 polyline, 5 polygon, 6 text, 7 image.
   real(c_double),         intent(in) :: x(*)      !< Abscissae [plot units].
   real(c_double),         intent(in) :: y(*)      !< Ordinates [plot units].
   integer(c_int),         intent(in) :: n         !< Points.
   real(c_double),         intent(in) :: rgba(4)   !< Colour, RGBA in [0, 1].
   real(c_double),         intent(in) :: thickness !< Line thickness [pixels].
   real(c_double),         intent(in) :: radius    !< A circle's radius [pixels].
   integer(c_int),         intent(in) :: filled    !< 1: filled (a polyline: closed).
   character(kind=c_char), intent(in) :: text(*)   !< Text (not NUL-terminated).
   integer(c_int),         intent(in) :: text_len  !< Its length [bytes].
   integer(c_long_long),   intent(in) :: texture   !< ImTextureID (an image).
   integer(c_int)                     :: status    !< Status.

   status = fig_draw(kind, 4_c_int, x, y, n, rgba, thickness, radius, filled, text, text_len, texture)
   endfunction plot_layer_draw

   function plot_tick_label(axis, index, buf, buf_len, count, label_len) result(status)
   !< A tick label of the plot being declared (`test_plot_tick`): the axis (ImAxis, -1 unknown), the tick (from 1); the
   !< label into `buf`, the ticks on the axis.
   integer(c_int),         intent(in)  :: axis      !< An ImAxis: 0-2 X1-X3, 3-5 Y1-Y3.
   integer(c_int),         intent(in)  :: index     !< Tick, from 1.
   character(kind=c_char), intent(out) :: buf(*)    !< Label.
   integer(c_int),         intent(in)  :: buf_len   !< Buffer length.
   integer(c_int),         intent(out) :: count     !< Ticks on the axis.
   integer(c_int),         intent(out) :: label_len !< Length of the label.
   integer(c_int)                      :: status    !< Status.

   status = fig_plot_tick_label(axis, index, buf, buf_len, count, label_len)
   endfunction plot_tick_label

   function plot_field_uploads() result(n)
   !< Field colourings uploaded since the start (`test_field_uploads`).
   integer(c_long_long) :: n !< Uploads.

   n = fig_field_uploads()
   endfunction plot_field_uploads

   function plot_field_count() result(n)
   !< Field textures cached (`test_field_textures`).
   integer(c_int) :: n !< Entries.

   n = fig_field_count()
   endfunction plot_field_count

   function plot_field_time() result(ms)
   !< The last field colouring's time, upload included [ms] (`test_field_time`).
   real(c_double) :: ms !< Time [ms].

   ms = fig_field_time()
   endfunction plot_field_time

   function plot_field_pixel(label, label_len, i, j, rgba) result(status)
   !< The colour of the field `label`'s value (i, j), as uploaded last (`test_field_pixel`).
   character(kind=c_char), intent(in)  :: label(*)  !< Label (not NUL-terminated).
   integer(c_int),         intent(in)  :: label_len !< Its length [bytes].
   integer(c_int),         intent(in)  :: i         !< Index along x (1-based).
   integer(c_int),         intent(in)  :: j         !< Index along y (1-based).
   real(c_float),          intent(out) :: rgba(4)   !< Colour, RGBA in [0, 1].
   integer(c_int)                      :: status    !< Status.

   status = fig_field_pixel(label, label_len, i, j, rgba)
   endfunction plot_field_pixel
endmodule figure_plot_hooks
