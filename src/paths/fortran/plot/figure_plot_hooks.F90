!< figure_plot_hooks, what FIGURE's other modules ask of the 2-D plots: the canvas's plot layer, the tests' queries.
module figure_plot_hooks
!< figure_plot_hooks, what FIGURE's other modules ask of the 2-D plots: the canvas's plot layer, the tests' queries.
!<
!< Part of the plot seam (szaghi/figure#15, the seam's switch), here over the Fortran plot frame: what figure_canvas
!< draws on its `'plot'` layer (`plot_layer_draw`: figure_plot_draw's `pf_draw_prim` in the frame's open plot) and what
!< figure_testing reads of the plots (`plot_tick_label`: `pf_tick_label`; the field textures of `ip_field_image`:
!< figure_plot_field's counters and colours). Arguments, results, statuses and messages are the native layer's, as the
!< current path's module of the same name (src/paths/imgui/plot/) gives them from ImPlot.
use, intrinsic :: iso_c_binding, only : c_char, c_double, c_float, c_int, c_long_long
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use figure_base, only : figure_fail
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK
use figure_plot_draw, only : pf_draw_prim
use figure_plot_field, only : field_count, field_pixel, field_time, field_uploads
use figure_plot_frame, only : pf_plot_state, pf_tick_label

implicit none
private
public :: plot_layer_draw, plot_tick_label, plot_field_uploads, plot_field_count, plot_field_time, plot_field_pixel

character(len=2), parameter :: AXIS_NAMES(0:5) = ['x1', 'x2', 'x3', 'y1', 'y2', 'y3'] !< ImAxis names.

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
   character(kind=c_char, len=*), intent(in) :: text !< Text (its first `text_len` characters).
   integer(c_int),         intent(in) :: text_len  !< Its length [bytes].
   integer(c_long_long),   intent(in) :: texture   !< ImTextureID (an image).
   integer(c_int)                     :: status    !< Status.

   status = pf_draw_prim(kind, x(1:n), y(1:n), rgba, thickness, radius, filled /= 0_c_int, text(1:text_len), &
                         int(texture, int64))
   endfunction plot_layer_draw

   function plot_tick_label(axis, index, buf, buf_len, count, label_len) result(status)
   !< A tick label of the plot being declared (`test_plot_tick`, as `fig_plot_tick_label`): the axis (ImAxis, -1
   !< unknown), the tick (from 1); the label into `buf`, the ticks on the axis.
   integer(c_int),                intent(in)  :: axis      !< An ImAxis: 0-2 X1-X3, 3-5 Y1-Y3.
   integer(c_int),                intent(in)  :: index     !< Tick, from 1.
   character(kind=c_char, len=*), intent(out) :: buf       !< Label.
   integer(c_int),                intent(in)  :: buf_len   !< Buffer length.
   integer(c_int),                intent(out) :: count     !< Ticks on the axis.
   integer(c_int),                intent(out) :: label_len !< Length of the label.
   integer(c_int)                             :: status    !< Status.
   integer(int32)                             :: en(6), sc(6) !< The plot's axes.
   integer(int32)                             :: c, l      !< Count, length.
   integer(int32)                             :: st        !< `figure_fail`'s status (the message set; the
                                                           !< caller acts on the status returned, as on the native
                                                           !< layer's).

   count = 0_c_int
   label_len = 0_c_int
   if (pf_plot_state(en, sc) == 0_int32) then
      call figure_fail(FIG_ERR_STATE, 'test_plot_tick: no plot is being declared (between ip_begin_plot and '// &
                       'ip_end_plot)', st)
      status = FIG_ERR_STATE
      return
   endif
   if (axis < 0_c_int .or. axis > 5_c_int) then
      call figure_fail(FIG_ERR_ARGUMENT, "test_plot_tick: unknown axis ('x1', 'x2', 'x3', 'y1', 'y2', 'y3', 'x' or "// &
                       "'y')", st)
      status = FIG_ERR_ARGUMENT
      return
   endif
   if (en(axis + 1_c_int) == 0_int32) then
      call figure_fail(FIG_ERR_STATE, "test_plot_tick: axis '"//AXIS_NAMES(axis)//"' is not set up (ip_setup_axis('"// &
                       AXIS_NAMES(axis)//"'))", st)
      status = FIG_ERR_STATE
      return
   endif
   call pf_tick_label(int(axis, int32) + 1_int32, int(index, int32), buf(1:max(buf_len, 0_c_int)), c, l)
   count = int(c, c_int)
   label_len = int(l, c_int)
   status = FIG_OK
   endfunction plot_tick_label

   function plot_field_uploads() result(n)
   !< Field colourings uploaded since the start (`test_field_uploads`).
   integer(c_long_long) :: n !< Uploads.

   n = int(field_uploads(), c_long_long)
   endfunction plot_field_uploads

   function plot_field_count() result(n)
   !< Field textures cached (`test_field_textures`).
   integer(c_int) :: n !< Entries.

   n = int(field_count(), c_int)
   endfunction plot_field_count

   function plot_field_time() result(ms)
   !< The last field colouring's time, upload included [ms] (`test_field_time`).
   real(c_double) :: ms !< Time [ms].

   ms = real(field_time(), c_double)
   endfunction plot_field_time

   function plot_field_pixel(label, label_len, i, j, rgba) result(status)
   !< The colour of the field `label`'s value (i, j), as coloured last (`test_field_pixel`, as `fig_field_pixel`).
   character(kind=c_char, len=*), intent(in)  :: label     !< Label (its first `label_len` characters).
   integer(c_int),                intent(in)  :: label_len !< Its length [bytes].
   integer(c_int),                intent(in)  :: i         !< Index along x (1-based).
   integer(c_int),                intent(in)  :: j         !< Index along y (1-based).
   real(c_float),                 intent(out) :: rgba(4)   !< Colour, RGBA in [0, 1].
   integer(c_int)                             :: status    !< Status.
   real(real32)                               :: c(4)      !< Colour.
   integer(int32)                             :: s         !< The field's status.
   integer(int32)                             :: st        !< `figure_fail`'s status (the message set).

   s = field_pixel(label(1:max(label_len, 0_c_int)), int(i, int32), int(j, int32), c)
   rgba = real(c, c_float)
   select case (s)
   case (0_int32)
      status = FIG_OK
   case (1_int32)
      call figure_fail(FIG_ERR_ARGUMENT, 'test_field_pixel: pixel out of the field', st)
      status = FIG_ERR_ARGUMENT
   case default
      call figure_fail(FIG_ERR_ARGUMENT, "test_field_pixel: no field '"//label(1:max(label_len, 0_c_int))// &
                       "' is cached", st)
      status = FIG_ERR_ARGUMENT
   endselect
   endfunction plot_field_pixel
endmodule figure_plot_hooks
