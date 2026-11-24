!< figure_plot_style, the plot frame's ImPlot style: its variables and colours, set, pushed, or taken from FIGURE's theme.
module figure_plot_style
!< figure_plot_style, the plot frame's ImPlot style: its variables and colours, set, pushed, or taken from FIGURE's theme.
!<
!< szaghi/figure#15 P10 (what P10-P12 left, night 2026-11-23 step 09). The `ImPlotStyle` the frame draws with, its own
!< (as the 3-D frame's figure_plot3d_style), ImPlot's defaults (`ImPlotStyle::ImPlotStyle`, `StyleColorsAuto`) until
!< changed:
!<
!< - the variables (PlotDefaultSize, PlotMinSize, PlotBorderSize, MinorAlpha, MajorTickLen, MinorTickLen,
!<   MajorTickSize, MinorTickSize, MajorGridSize, MinorGridSize, PlotPadding, LabelPadding, LegendPadding,
!<   LegendInnerPadding, LegendSpacing, MousePosPadding, AnnotationPadding, FitPadding, DigitalPadding,
!<   DigitalSpacing), public module variables under the names the frame's parameters had (STYLE_PLOT_PADDING, ...);
!< - the colours (`ImPlotCol_*`, IMPLOT_AUTO_COL for an automatic one), read as ImPlot reads them:
!<   `ps_vec4` (`GetStyleColorVec4`: an automatic colour from Dear ImGui's style, `GetAutoColor`), `ps_u32`
!<   (`GetStyleColorU32`: packed as they are, the style's Alpha not applied), `ps_alpha_u32` (`ImGui::GetColorU32` of
!<   a colour: its alpha times Dear ImGui's style Alpha, as ImPlot packs the grid, the legend's text, the boxes of
!<   tags and annotations);
!< - `ps_set_var`, `ps_set_color`, `ps_push_var`, `ps_push_color`, `ps_pop_var`, `ps_pop_color` (`ip_set_style_*`,
!<   `ip_push_style_*`; stacks of 64, their own: an error stop past them, for an unknown name or a wrong count);
!< - `ps_sync`: the variables and colours as FIGURE's style holds them in ImPlot's context (`fig_style_var`,
!<   `fig_style_color` of the library 1: what a theme's [implot.vars] and [implot.colors] and `ip_set_style_*` set,
!<   the colours as stored: an automatic one stays automatic, resolved when it is read), while FIGURE's style lives
!<   there (the native layer's themes and `ip_*_style_*`); `ps_refresh`, which the Fortran path's `figure_implot` calls
!<   at its entry points, syncs only when that style changed since (`fig_generations`: a new context, a theme, a set,
!<   push or pop of an ImPlot colour or variable, the style editor), so a push inside a plot reaches the next item.
use, intrinsic :: iso_c_binding, only : c_double, c_float, c_int
use, intrinsic :: iso_fortran_env, only : int32, real32, real64
use figure_c_native, only : fig_generations, fig_style_color, fig_style_var
use figure_cimgui_enums, only : ImGuiCol_Border, ImGuiCol_ButtonActive, ImGuiCol_ButtonHovered, ImGuiCol_FrameBg, &
                                ImGuiCol_PopupBg, ImGuiCol_Text, ImGuiCol_WindowBg, ImGuiStyleVar_Alpha
use figure_core, only : core_color, core_style_color_rgba, core_style_vec2

implicit none
private
public :: PLOT_DEFAULT_SIZE, STYLE_PLOT_MIN_SIZE, PLOT_BORDER_SIZE, MINOR_ALPHA, MAJOR_TICK_LEN, MINOR_TICK_LEN
public :: MAJOR_TICK_SIZE, MINOR_TICK_SIZE, MAJOR_GRID_SIZE, MINOR_GRID_SIZE, STYLE_PLOT_PADDING, LABEL_PADDING
public :: LEGEND_PADDING, LEGEND_INNER_PADDING, LEGEND_SPACING, MOUSE_POS_PADDING, ANNOTATION_PADDING, FIT_PADDING
public :: DIGITAL_PADDING, DIGITAL_SPACING
public :: PC_FRAME_BG, PC_PLOT_BG, PC_PLOT_BORDER, PC_LEGEND_BG, PC_LEGEND_BORDER, PC_LEGEND_TEXT, PC_TITLE_TEXT
public :: PC_INLAY_TEXT, PC_AXIS_TEXT, PC_AXIS_GRID, PC_AXIS_TICK, PC_AXIS_BG, PC_AXIS_BG_HOVERED, PC_AXIS_BG_ACTIVE
public :: PC_SELECTION, PC_CROSSHAIRS
public :: ps_vec4, ps_u32, ps_alpha_u32, ps_style_alpha, ps_set_var, ps_set_color, ps_push_var, ps_push_color
public :: ps_pop_var, ps_pop_color, ps_sync, ps_reset, ps_refresh

! ImPlotCol (implot.h)
integer(int32), parameter :: PC_FRAME_BG = 0_int32, PC_PLOT_BG = 1_int32, PC_PLOT_BORDER = 2_int32, &
                             PC_LEGEND_BG = 3_int32, PC_LEGEND_BORDER = 4_int32, PC_LEGEND_TEXT = 5_int32, &
                             PC_TITLE_TEXT = 6_int32, PC_INLAY_TEXT = 7_int32, PC_AXIS_TEXT = 8_int32, &
                             PC_AXIS_GRID = 9_int32, PC_AXIS_TICK = 10_int32, PC_AXIS_BG = 11_int32, &
                             PC_AXIS_BG_HOVERED = 12_int32, PC_AXIS_BG_ACTIVE = 13_int32, PC_SELECTION = 14_int32, &
                             PC_CROSSHAIRS = 15_int32 !< Colours.
integer(int32), parameter :: PC_COUNT = 16_int32 !< ImPlotCol_COUNT.
character(len=13), parameter :: COL_NAMES(0:15) = ['FrameBg      ', 'PlotBg       ', 'PlotBorder   ', &
                                                   'LegendBg     ', 'LegendBorder ', 'LegendText   ', &
                                                   'TitleText    ', 'InlayText    ', 'AxisText     ', &
                                                   'AxisGrid     ', 'AxisTick     ', 'AxisBg       ', &
                                                   'AxisBgHovered', 'AxisBgActive ', 'Selection    ', &
                                                   'Crosshairs   '] !< `GetStyleColorName`.
integer(int32), parameter :: NVAR = 20_int32 !< The variables.
character(len=18), parameter :: VAR_NAMES(NVAR) = ['PlotDefaultSize   ', 'PlotMinSize       ', 'PlotBorderSize    ', &
                                                   'MinorAlpha        ', 'MajorTickLen      ', 'MinorTickLen      ', &
                                                   'MajorTickSize     ', 'MinorTickSize     ', 'MajorGridSize     ', &
                                                   'MinorGridSize     ', 'PlotPadding       ', 'LabelPadding      ', &
                                                   'LegendPadding     ', 'LegendInnerPadding', 'LegendSpacing     ', &
                                                   'MousePosPadding   ', 'AnnotationPadding ', 'FitPadding        ', &
                                                   'DigitalPadding    ', 'DigitalSpacing    '] !< Names.
integer(int32), parameter :: VAR_COUNTS(NVAR) = [2, 2, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1] !< Values.
integer(int32), parameter :: STACK = 64_int32 !< Pushes held at most.
real(real32),   parameter :: AUTO(4) = [0.0_real32, 0.0_real32, 0.0_real32, -1.0_real32] !< IMPLOT_AUTO_COL.

! the variables, ImPlot's defaults
real(real32) :: PLOT_DEFAULT_SIZE(2) = [400.0_real32, 300.0_real32] !< PlotDefaultSize [pixels].
real(real32) :: STYLE_PLOT_MIN_SIZE(2) = [200.0_real32, 150.0_real32] !< PlotMinSize [pixels].
real(real32) :: PLOT_BORDER_SIZE = 1.0_real32                      !< PlotBorderSize [pixels].
real(real32) :: MINOR_ALPHA = 0.25_real32                          !< MinorAlpha.
real(real32) :: MAJOR_TICK_LEN(2) = [10.0_real32, 10.0_real32]     !< MajorTickLen [pixels].
real(real32) :: MINOR_TICK_LEN(2) = [5.0_real32, 5.0_real32]       !< MinorTickLen [pixels].
real(real32) :: MAJOR_TICK_SIZE(2) = [1.0_real32, 1.0_real32]      !< MajorTickSize [pixels].
real(real32) :: MINOR_TICK_SIZE(2) = [1.0_real32, 1.0_real32]      !< MinorTickSize [pixels].
real(real32) :: MAJOR_GRID_SIZE(2) = [1.0_real32, 1.0_real32]      !< MajorGridSize [pixels].
real(real32) :: MINOR_GRID_SIZE(2) = [1.0_real32, 1.0_real32]      !< MinorGridSize [pixels].
real(real32) :: STYLE_PLOT_PADDING(2) = [10.0_real32, 10.0_real32] !< PlotPadding [pixels].
real(real32) :: LABEL_PADDING(2) = [5.0_real32, 5.0_real32]        !< LabelPadding [pixels].
real(real32) :: LEGEND_PADDING(2) = [10.0_real32, 10.0_real32]     !< LegendPadding [pixels].
real(real32) :: LEGEND_INNER_PADDING(2) = [5.0_real32, 5.0_real32] !< LegendInnerPadding [pixels].
real(real32) :: LEGEND_SPACING(2) = [5.0_real32, 0.0_real32]       !< LegendSpacing [pixels].
real(real32) :: MOUSE_POS_PADDING(2) = [10.0_real32, 10.0_real32]  !< MousePosPadding [pixels].
real(real32) :: ANNOTATION_PADDING(2) = [2.0_real32, 2.0_real32]   !< AnnotationPadding [pixels].
real(real32) :: FIT_PADDING(2) = [0.0_real32, 0.0_real32]          !< FitPadding (fraction of the range).
real(real32) :: DIGITAL_PADDING = 20.0_real32                      !< DigitalPadding [pixels].
real(real32) :: DIGITAL_SPACING = 4.0_real32                       !< DigitalSpacing [pixels].

real(real32)   :: colors(4, 0:15) = reshape([0.0_real32, 0.0_real32, 0.0_real32, -1.0_real32, & ! all automatic but
                                             0.0_real32, 0.0_real32, 0.0_real32, -1.0_real32, & ! AxisBg (transparent)
                                             0.0_real32, 0.0_real32, 0.0_real32, -1.0_real32, & ! and Selection
                                             0.0_real32, 0.0_real32, 0.0_real32, -1.0_real32, & ! (yellow), as
                                             0.0_real32, 0.0_real32, 0.0_real32, -1.0_real32, & ! StyleColorsAuto
                                             0.0_real32, 0.0_real32, 0.0_real32, -1.0_real32, &
                                             0.0_real32, 0.0_real32, 0.0_real32, -1.0_real32, &
                                             0.0_real32, 0.0_real32, 0.0_real32, -1.0_real32, &
                                             0.0_real32, 0.0_real32, 0.0_real32, -1.0_real32, &
                                             0.0_real32, 0.0_real32, 0.0_real32, -1.0_real32, &
                                             0.0_real32, 0.0_real32, 0.0_real32, -1.0_real32, &
                                             0.0_real32, 0.0_real32, 0.0_real32, 0.0_real32,  &
                                             0.0_real32, 0.0_real32, 0.0_real32, -1.0_real32, &
                                             0.0_real32, 0.0_real32, 0.0_real32, -1.0_real32, &
                                             1.0_real32, 1.0_real32, 0.0_real32, 1.0_real32,  &
                                             0.0_real32, 0.0_real32, 0.0_real32, -1.0_real32], [4, 16]) !< Colours.
integer(int32) :: var_stack_idx(STACK) = 0_int32       !< A pushed variable.
real(real32)   :: var_stack_val(2, STACK) = 0.0_real32 !< ... its value before.
integer(int32) :: n_var_stack = 0_int32                !< Pushes held.
integer(int32) :: col_stack_idx(STACK) = 0_int32       !< A pushed colour.
real(real32)   :: col_stack_val(4, STACK) = 0.0_real32 !< ... its value before.
integer(int32) :: n_col_stack = 0_int32                !< Pushes held.
logical        :: synced = .false.                     !< `ps_refresh` synced once.
integer(c_int) :: synced_gen(2) = 0_c_int              !< ... at these generations (`fig_generations`).

contains
   ! colours

   recursive function ps_vec4(idx) result(c)
   !< `GetStyleColorVec4`: a colour as set, or the automatic one (`GetAutoColor`) from Dear ImGui's style.
   integer(int32), intent(in) :: idx  !< ImPlotCol.
   real(real64)               :: c(4) !< RGBA.

   if (colors(4, idx) /= -1.0_real32) then
      c = real(colors(:, idx), real64)
      return
   endif
   select case (idx)
   case (PC_FRAME_BG)
      call core_style_color_rgba(ImGuiCol_FrameBg, c)
   case (PC_PLOT_BG)
      call core_style_color_rgba(ImGuiCol_WindowBg, c)
   case (PC_PLOT_BORDER)
      call core_style_color_rgba(ImGuiCol_Border, c)
   case (PC_LEGEND_BG)
      call core_style_color_rgba(ImGuiCol_PopupBg, c)
   case (PC_LEGEND_BORDER, PC_CROSSHAIRS)
      c = ps_vec4(PC_PLOT_BORDER)
   case (PC_LEGEND_TEXT)
      c = ps_vec4(PC_INLAY_TEXT)
   case (PC_AXIS_GRID) ! AxisText * (1, 1, 1, 0.25), in float
      c = ps_vec4(PC_AXIS_TEXT)
      c(4) = real(real(c(4), real32) * 0.25_real32, real64)
   case (PC_AXIS_TICK)
      c = ps_vec4(PC_AXIS_GRID)
   case (PC_AXIS_BG_HOVERED)
      call core_style_color_rgba(ImGuiCol_ButtonHovered, c)
   case (PC_AXIS_BG_ACTIVE)
      call core_style_color_rgba(ImGuiCol_ButtonActive, c)
   case default ! TitleText, InlayText, AxisText
      call core_style_color_rgba(ImGuiCol_Text, c)
   endselect
   endfunction ps_vec4

   function ps_u32(idx) result(col)
   !< `GetStyleColorU32`: a colour packed (`ColorConvertFloat4ToU32`), the style's Alpha not applied.
   integer(int32), intent(in) :: idx !< ImPlotCol.
   integer(int32)             :: col !< Packed.
   real(real64)               :: c(4) !< RGBA.

   c = ps_vec4(idx)
   col = core_color(c(1), c(2), c(3), c(4))
   endfunction ps_u32

   function ps_style_alpha() result(a)
   !< Dear ImGui's style Alpha.
   real(real32) :: a   !< Alpha.
   real(real64) :: x, y !< Alpha and the float after it.

   call core_style_vec2(ImGuiStyleVar_Alpha, x, y)
   a = real(x, real32)
   endfunction ps_style_alpha

   function ps_alpha_u32(c) result(col)
   !< `ImGui::GetColorU32(ImVec4)`: a colour's alpha times Dear ImGui's style Alpha (in float), then packed.
   real(real64), intent(in) :: c(4) !< RGBA.
   integer(int32)           :: col  !< Packed.
   real(real32)             :: a    !< Alpha.

   a = real(c(4), real32) * ps_style_alpha()
   col = core_color(c(1), c(2), c(3), real(a, real64))
   endfunction ps_alpha_u32

   ! set, pushed, popped

   function var_index(name) result(k)
   !< A variable's index by name; error stop if unknown.
   character(len=*), intent(in) :: name !< Name.
   integer(int32)               :: k    !< Index.

   do k = 1_int32, NVAR
      if (trim(VAR_NAMES(k)) == name) return
   enddo
   error stop 'figure_plot_style: an unknown ImPlot style variable'
   endfunction var_index

   function col_index(name) result(k)
   !< A colour's index by name; error stop if unknown.
   character(len=*), intent(in) :: name !< Name.
   integer(int32)               :: k    !< ImPlotCol.

   do k = 0_int32, PC_COUNT - 1_int32
      if (trim(COL_NAMES(k)) == name) return
   enddo
   error stop 'figure_plot_style: an unknown ImPlot style colour'
   endfunction col_index

   subroutine var_get(k, v)
   !< A variable's value(s).
   integer(int32), intent(in)  :: k    !< Index.
   real(real32),   intent(out) :: v(2) !< Value(s) (the second 0 for a scalar).

   v = 0.0_real32
   select case (k)
   case (1_int32)
      v = PLOT_DEFAULT_SIZE
   case (2_int32)
      v = STYLE_PLOT_MIN_SIZE
   case (3_int32)
      v(1) = PLOT_BORDER_SIZE
   case (4_int32)
      v(1) = MINOR_ALPHA
   case (5_int32)
      v = MAJOR_TICK_LEN
   case (6_int32)
      v = MINOR_TICK_LEN
   case (7_int32)
      v = MAJOR_TICK_SIZE
   case (8_int32)
      v = MINOR_TICK_SIZE
   case (9_int32)
      v = MAJOR_GRID_SIZE
   case (10_int32)
      v = MINOR_GRID_SIZE
   case (11_int32)
      v = STYLE_PLOT_PADDING
   case (12_int32)
      v = LABEL_PADDING
   case (13_int32)
      v = LEGEND_PADDING
   case (14_int32)
      v = LEGEND_INNER_PADDING
   case (15_int32)
      v = LEGEND_SPACING
   case (16_int32)
      v = MOUSE_POS_PADDING
   case (17_int32)
      v = ANNOTATION_PADDING
   case (18_int32)
      v = FIT_PADDING
   case (19_int32)
      v(1) = DIGITAL_PADDING
   case default
      v(1) = DIGITAL_SPACING
   endselect
   endsubroutine var_get

   subroutine var_put(k, v)
   !< A variable's value(s) set.
   integer(int32), intent(in) :: k    !< Index.
   real(real32),   intent(in) :: v(2) !< Value(s).

   select case (k)
   case (1_int32)
      PLOT_DEFAULT_SIZE = v
   case (2_int32)
      STYLE_PLOT_MIN_SIZE = v
   case (3_int32)
      PLOT_BORDER_SIZE = v(1)
   case (4_int32)
      MINOR_ALPHA = v(1)
   case (5_int32)
      MAJOR_TICK_LEN = v
   case (6_int32)
      MINOR_TICK_LEN = v
   case (7_int32)
      MAJOR_TICK_SIZE = v
   case (8_int32)
      MINOR_TICK_SIZE = v
   case (9_int32)
      MAJOR_GRID_SIZE = v
   case (10_int32)
      MINOR_GRID_SIZE = v
   case (11_int32)
      STYLE_PLOT_PADDING = v
   case (12_int32)
      LABEL_PADDING = v
   case (13_int32)
      LEGEND_PADDING = v
   case (14_int32)
      LEGEND_INNER_PADDING = v
   case (15_int32)
      LEGEND_SPACING = v
   case (16_int32)
      MOUSE_POS_PADDING = v
   case (17_int32)
      ANNOTATION_PADDING = v
   case (18_int32)
      FIT_PADDING = v
   case (19_int32)
      DIGITAL_PADDING = v(1)
   case default
      DIGITAL_SPACING = v(1)
   endselect
   endsubroutine var_put

   subroutine ps_set_var(name, values)
   !< An ImPlot style variable set (`ip_set_style_var`): `values` of its count (1 or 2).
   character(len=*), intent(in) :: name      !< Name (ImPlotStyle's).
   real(real64),     intent(in) :: values(:) !< Value(s).
   integer(int32)               :: k         !< Index.
   real(real32)                 :: v(2)      !< As floats.

   k = var_index(name)
   if (size(values) /= VAR_COUNTS(k)) error stop 'figure_plot_style: a wrong count of values for the variable'
   v = 0.0_real32
   v(1:VAR_COUNTS(k)) = real(values(1:VAR_COUNTS(k)), real32)
   call var_put(k, v)
   endsubroutine ps_set_var

   subroutine ps_push_var(name, values)
   !< An ImPlot style variable pushed (`ip_push_style_var`), its value before kept for `ps_pop_var`.
   character(len=*), intent(in) :: name      !< Name.
   real(real64),     intent(in) :: values(:) !< Value(s).
   integer(int32)               :: k         !< Index.

   if (n_var_stack == STACK) error stop 'figure_plot_style: more than 64 style variables pushed'
   k = var_index(name)
   n_var_stack = n_var_stack + 1_int32
   var_stack_idx(n_var_stack) = k
   call var_get(k, var_stack_val(:, n_var_stack))
   call ps_set_var(name, values)
   endsubroutine ps_push_var

   subroutine ps_pop_var(count)
   !< The last `count` (default 1) variables pushed restored (`ip_pop_style_var`).
   integer(int32), intent(in), optional :: count !< Pops.
   integer(int32)                       :: n, i  !< Pops, counter.

   n = 1_int32
   if (present(count)) n = count
   if (n > n_var_stack) error stop 'figure_plot_style: more style variables popped than pushed'
   do i = 1_int32, n
      call var_put(var_stack_idx(n_var_stack), var_stack_val(:, n_var_stack))
      n_var_stack = n_var_stack - 1_int32
   enddo
   endsubroutine ps_pop_var

   subroutine ps_set_color(name, rgba)
   !< An ImPlot style colour set (`ip_set_style_color`): RGBA, or (0, 0, 0, -1) for automatic.
   character(len=*), intent(in) :: name    !< Name (`ImPlotCol_*` without its prefix).
   real(real64),     intent(in) :: rgba(4) !< Colour.

   colors(:, col_index(name)) = real(rgba, real32)
   endsubroutine ps_set_color

   subroutine ps_push_color(name, rgba)
   !< An ImPlot style colour pushed (`ip_push_style_color`).
   character(len=*), intent(in) :: name    !< Name.
   real(real64),     intent(in) :: rgba(4) !< Colour.
   integer(int32)               :: k       !< Index.

   if (n_col_stack == STACK) error stop 'figure_plot_style: more than 64 style colours pushed'
   k = col_index(name)
   n_col_stack = n_col_stack + 1_int32
   col_stack_idx(n_col_stack) = k
   col_stack_val(:, n_col_stack) = colors(:, k)
   colors(:, k) = real(rgba, real32)
   endsubroutine ps_push_color

   subroutine ps_pop_color(count)
   !< The last `count` (default 1) colours pushed restored (`ip_pop_style_color`).
   integer(int32), intent(in), optional :: count !< Pops.
   integer(int32)                       :: n, i  !< Pops, counter.

   n = 1_int32
   if (present(count)) n = count
   if (n > n_col_stack) error stop 'figure_plot_style: more style colours popped than pushed'
   do i = 1_int32, n
      colors(:, col_stack_idx(n_col_stack)) = col_stack_val(:, n_col_stack)
      n_col_stack = n_col_stack - 1_int32
   enddo
   endsubroutine ps_pop_color

   subroutine ps_reset()
   !< ImPlot's defaults back (`ImPlotStyle()`), the stacks emptied.
   integer(int32) :: k !< Colour.

   PLOT_DEFAULT_SIZE = [400.0_real32, 300.0_real32]
   STYLE_PLOT_MIN_SIZE = [200.0_real32, 150.0_real32]
   PLOT_BORDER_SIZE = 1.0_real32
   MINOR_ALPHA = 0.25_real32
   MAJOR_TICK_LEN = 10.0_real32
   MINOR_TICK_LEN = 5.0_real32
   MAJOR_TICK_SIZE = 1.0_real32
   MINOR_TICK_SIZE = 1.0_real32
   MAJOR_GRID_SIZE = 1.0_real32
   MINOR_GRID_SIZE = 1.0_real32
   STYLE_PLOT_PADDING = 10.0_real32
   LABEL_PADDING = 5.0_real32
   LEGEND_PADDING = 10.0_real32
   LEGEND_INNER_PADDING = 5.0_real32
   LEGEND_SPACING = [5.0_real32, 0.0_real32]
   MOUSE_POS_PADDING = 10.0_real32
   ANNOTATION_PADDING = 2.0_real32
   FIT_PADDING = 0.0_real32
   DIGITAL_PADDING = 20.0_real32
   DIGITAL_SPACING = 4.0_real32
   do k = 0_int32, PC_COUNT - 1_int32
      colors(:, k) = AUTO
   enddo
   colors(:, PC_AXIS_BG) = 0.0_real32
   colors(:, PC_SELECTION) = [1.0_real32, 1.0_real32, 0.0_real32, 1.0_real32]
   n_var_stack = 0_int32
   n_col_stack = 0_int32
   endsubroutine ps_reset

   subroutine ps_sync()
   !< The variables and colours as FIGURE's style holds them in ImPlot's context (a theme's [implot.vars] and
   !< [implot.colors], `ip_set_style_*`, `ip_push_style_*`): `fig_style_var`, `fig_style_color` of the library 1, the
   !< colours as stored (an automatic one stays automatic). No allocation (the names are passed as substrings).
   integer(int32) :: k   !< Index.
   integer(c_int) :: n, st, l !< Count, status, a name's length.
   real(c_double) :: v(2) !< Value(s).
   real(c_float)  :: c(4) !< Colour.
   real(real32)   :: w(2) !< As floats.

   do k = 1_int32, NVAR
      n = 0_c_int
      v = 0.0_c_double
      l = len_trim(VAR_NAMES(k), c_int)
      st = fig_style_var(1_c_int, VAR_NAMES(k)(1:l), l, 0_c_int, v, n)
      if (st /= 0_c_int) cycle
      w(1) = real(v(1), real32)
      w(2) = real(v(2), real32)
      call var_put(k, w)
   enddo
   do k = 0_int32, PC_COUNT - 1_int32
      c = 0.0_c_float
      l = len_trim(COL_NAMES(k), c_int)
      st = fig_style_color(1_c_int, COL_NAMES(k)(1:l), l, 2_c_int, c)
      if (st /= 0_c_int) cycle
      colors(1, k) = real(c(1), real32)
      colors(2, k) = real(c(2), real32)
      colors(3, k) = real(c(3), real32)
      colors(4, k) = real(c(4), real32)
   enddo
   endsubroutine ps_sync

   subroutine ps_refresh()
   !< `ps_sync` when FIGURE's ImPlot style changed since the last refresh (`fig_generations`: a new context, a theme, a
   !< set, push or pop of an ImPlot colour or variable, the style editor shown); the Fortran path's entry points call
   !< it, so the frame draws with the style in effect at the call, as ImPlot reads its style while it draws.
   integer(c_int) :: gen(2) !< Generations: contexts, ImPlot's style.

   call fig_generations(gen(1), gen(2))
   if (synced .and. gen(1) == synced_gen(1) .and. gen(2) == synced_gen(2)) return
   synced = .true.
   synced_gen = gen
   call ps_sync()
   endsubroutine ps_refresh
endmodule figure_plot_style
