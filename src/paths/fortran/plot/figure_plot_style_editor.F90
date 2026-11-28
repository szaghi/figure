!< figure_plot_style_editor, the style editor's ImPlot section on the Fortran path: the plots' style store edited live.
module figure_plot_style_editor
!< figure_plot_style_editor, the style editor's ImPlot section on the Fortran path: the plots' style store edited live.
!<
!< szaghi/figure#15 G2 (option A: the style editor's ImPlot section, a small Fortran widget). What `ig_show_style_editor`
!< draws under its "ImPlot" header on this path (the native layer calls `pse_draw` through figure_plot_hooks'
!< `fig_plot_style_hooks`), in place of ImPlot's `ShowStyleEditor`: its "Variables" tab, the same sliders (labels,
!< ranges, formats), then its "Colors" tab's list, each colour with its "Auto" button (an automatic colour, derived from
!< Dear ImGui's, is shown resolved and becomes explicit when edited; an explicit one goes back to automatic) and its
!< colour editor. Not ported: ImPlot's reference style (Save Ref, Revert Ref), its style selector, the export, the
!< filter and the alpha preview modes of the colours, and the colormaps tab (the style's line colours are FIGURE's
!< themes'). The edits are made in figure_plot_style's store, as ImPlot's editor makes them in ImPlot's style.
use, intrinsic :: iso_fortran_env, only : int32, real32, real64
use figure_imgui, only : ig_button, ig_color_edit, ig_same_line, ig_separator, ig_text
use figure_numbers, only : ig_slider
use figure_plot_style, only : ps_color_named, ps_var_named, ps_vec4

implicit none
private
public :: pse_draw

integer(int32),    parameter :: NSLIDER = 20_int32 !< Sliders.
character(len=18), parameter :: NAMES(NSLIDER) = ['PlotDefaultSize   ', 'PlotMinSize       ', 'PlotBorderSize    ', &
                                                  'MinorAlpha        ', 'MajorTickLen      ', 'MinorTickLen      ', &
                                                  'MajorTickSize     ', 'MinorTickSize     ', 'MajorGridSize     ', &
                                                  'MinorGridSize     ', 'PlotPadding       ', 'LabelPadding      ', &
                                                  'LegendPadding     ', 'LegendInnerPadding', 'LegendSpacing     ', &
                                                  'MousePosPadding   ', 'AnnotationPadding ', 'FitPadding        ', &
                                                  'DigitalPadding    ', 'DigitalSpacing    '] !< ShowStyleEditor's order.
real(real32),      parameter :: VMAX(NSLIDER) = [1000.0_real32, 300.0_real32, 2.0_real32, 1.0_real32, 20.0_real32, &
                                                 20.0_real32, 2.0_real32, 2.0_real32, 2.0_real32, 2.0_real32, &
                                                 20.0_real32, 20.0_real32, 20.0_real32, 10.0_real32, 5.0_real32, &
                                                 20.0_real32, 5.0_real32, 0.2_real32, 20.0_real32, 10.0_real32] !< Ranges.
character(len=4),  parameter :: FORMATS(NSLIDER) = ['%.0f', '%.0f', '%.0f', '%.2f', '%.0f', '%.0f', '%.1f', '%.1f', &
                                                    '%.1f', '%.1f', '%.0f', '%.0f', '%.0f', '%.0f', '%.0f', '%.0f', &
                                                    '%.0f', '%.2f', '%.1f', '%.1f'] !< Formats.
character(len=13), parameter :: COLOURS(0:15) = ['FrameBg      ', 'PlotBg       ', 'PlotBorder   ', 'LegendBg     ', &
                                                 'LegendBorder ', 'LegendText   ', 'TitleText    ', 'InlayText    ', &
                                                 'AxisText     ', 'AxisGrid     ', 'AxisTick     ', 'AxisBg       ', &
                                                 'AxisBgHovered', 'AxisBgActive ', 'Selection    ', 'Crosshairs   '] !< Names.

contains
   subroutine pse_draw()
   !< The editor's widgets, in the current window (the style editor's, under its "ImPlot" header).
   integer(int32) :: k, n, st     !< Counter, values, status.
   real(real64)   :: v(2)         !< A variable's values.
   real(real32)   :: w(2)         !< ... as the slider edits them.
   real(real32)   :: c(4)         !< A colour, as stored.
   real(real64)   :: e(4)         !< ... as edited.
   logical        :: changed      !< A widget changed its value.

   call ig_text('Plot Styling')
   do k = 1_int32, NSLIDER
      if (k == 11_int32) call ig_text('Plot Padding')
      n = 0_int32
      v = 0.0_real64
      call ps_var_named(trim(NAMES(k)), 0_int32, v, n, st)
      w = real(v, real32)
      if (n == 2_int32) then
         changed = ig_slider(trim(NAMES(k)), w, 0.0_real32, VMAX(k), format=FORMATS(k))
      else
         changed = ig_slider(trim(NAMES(k)), w(1), 0.0_real32, VMAX(k), format=FORMATS(k))
      endif
      if (changed) then
         v = real(w, real64)
         call ps_var_named(trim(NAMES(k)), 1_int32, v, n, st)
      endif
   enddo
   call ig_separator()
   do k = 0_int32, 15_int32
      call ps_color_named(trim(COLOURS(k)), 2_int32, c, st)
      if (ig_button('Auto##'//trim(COLOURS(k)))) then ! automatic: made explicit (its colour now); explicit: automatic
         if (c(4) == -1.0_real32) then
            c = real(ps_vec4(k), real32)
         else
            c = [0.0_real32, 0.0_real32, 0.0_real32, -1.0_real32]
         endif
         call ps_color_named(trim(COLOURS(k)), 1_int32, c, st)
      endif
      call ig_same_line()
      e = ps_vec4(k)
      if (ig_color_edit(trim(COLOURS(k)), e)) then
         c = real(e, real32)
         call ps_color_named(trim(COLOURS(k)), 1_int32, c, st)
      endif
   enddo
   call ig_separator()
   call ig_text('Colors that are set to Auto will be automatically deduced from your ImGui style.')
   endsubroutine pse_draw
endmodule figure_plot_style_editor
