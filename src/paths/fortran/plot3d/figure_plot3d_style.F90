!< figure_plot3d_style, the Fortran 3-D frame's style: ImPlot3D's colours and variables, pushed and popped by name.
module figure_plot3d_style
!< figure_plot3d_style, the Fortran 3-D frame's style: ImPlot3D's colours and variables, pushed and popped by name.
!<
!< szaghi/figure#15 P13, the style. `ImPlot3DStyle` on the Fortran path: its 14 colours (`ImPlot3DCol_*`, automatic until
!< pushed: `GetAutoColor` derives each from Dear ImGui's style at the time it is read, so a theme reaches the 3-D plots
!< through Dear ImGui's colours, as on the current path, where FIGURE's themes set no ImPlot3D colour) and the 11
!< variables FIGURE's `ip3_push_style_var` names (`LineWeight`, `MarkerSize`, `FillAlpha`, `PlotDefaultSize`,
!< `PlotMinSize`, `PlotPadding`, `LabelPadding`, `ViewScaleFactor`, `LegendPadding`, `LegendInnerPadding`,
!< `LegendSpacing`), with ImPlot3D's defaults. `pf3_push_style_color`, `pf3_pop_style_color`, `pf3_push_style_var`,
!< `pf3_pop_style_var` mirror figure_style's `ip3_*` (the names, the 3 or 4 components, a pair or a number), on stacks of
!< their own (figure_style's native stack is one for the three libraries: an `ip3_pop_*` pops the newest push of any of
!< them; here only the 3-D style's).
!<
!< The frame reads a colour as `GetStyleColorVec4` (`style3_vec4`) or `GetStyleColorU32` (`style3_u32`: packed without
!< the style's alpha, as ImPlot3D packs it) and the variables as the module's protected values; where ImPlot3D packs
!< with Dear ImGui's `GetColorU32` (the grid, the legend's text, the items' lines, fills and markers) the alpha is
!< times the style's (`style3_color_u32`, `style3_alpha_u32`).
!<
!< `ps3_sync` takes the colours and variables as FIGURE's style holds them in ImPlot3D's context (`fig_style_color`,
!< `fig_style_var` of the library 2: what `ip3_push_style_*` pushed, the colours as stored); `ps3_refresh`, which the
!< Fortran path's `figure_implot3d` calls at its entry points (szaghi/figure#15, the 3-D seam's switch), syncs when
!< the plots' styles changed (`fig_generations`): `ip3_push_style_*` and `ip3_pop_style_*` stay figure_style's, on
!< its one stack, as on the current path.
use, intrinsic :: iso_c_binding, only : c_double, c_float, c_int
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use figure_c_native, only : fig_generations, fig_style_color, fig_style_var
use figure_cimgui_enums, only : ImGuiCol_Border, ImGuiCol_ButtonActive, ImGuiCol_ButtonHovered, ImGuiCol_FrameBg, &
                                ImGuiCol_PopupBg, ImGuiCol_Text, ImGuiCol_WindowBg
use figure_core, only : core_color, core_style_color_rgba, core_style_var

implicit none
private
public :: style3_vec4, style3_u32, style3_color_u32, style3_alpha_u32
public :: pf3_push_style_color, pf3_pop_style_color, pf3_push_style_var, pf3_pop_style_var
public :: ps3_sync, ps3_refresh
public :: S3_TITLE_TEXT, S3_INLAY_TEXT, S3_FRAME_BG, S3_PLOT_BG, S3_PLOT_BORDER, S3_LEGEND_BG, S3_LEGEND_BORDER, &
          S3_LEGEND_TEXT, S3_AXIS_TEXT, S3_AXIS_GRID, S3_AXIS_TICK, S3_AXIS_BG, S3_AXIS_BG_HOVERED, S3_AXIS_BG_ACTIVE
public :: s3_line_weight, s3_marker_size, s3_fill_alpha, s3_default_size, s3_min_size, s3_plot_padding, &
          s3_label_padding, s3_view_factor, s3_legend_padding, s3_legend_inner, s3_legend_spacing

! ImPlot3DCol (1-based)
integer(int32), parameter :: S3_TITLE_TEXT = 1_int32, S3_INLAY_TEXT = 2_int32, S3_FRAME_BG = 3_int32,          &
                             S3_PLOT_BG = 4_int32, S3_PLOT_BORDER = 5_int32, S3_LEGEND_BG = 6_int32,           &
                             S3_LEGEND_BORDER = 7_int32, S3_LEGEND_TEXT = 8_int32, S3_AXIS_TEXT = 9_int32,     &
                             S3_AXIS_GRID = 10_int32, S3_AXIS_TICK = 11_int32, S3_AXIS_BG = 12_int32,          &
                             S3_AXIS_BG_HOVERED = 13_int32, S3_AXIS_BG_ACTIVE = 14_int32 !< Colours.
integer(int32), parameter :: NCOL = 14_int32  !< ImPlot3DCol_COUNT.
integer(int32), parameter :: NVAR = 11_int32  !< Variables.
integer(int32), parameter :: STACK = 64_int32 !< Pushes held at most.
character(len=*), parameter :: COL_NAMES(NCOL) = ['TitleText    ', 'InlayText    ', 'FrameBg      ', 'PlotBg       ', &
                                                  'PlotBorder   ', 'LegendBg     ', 'LegendBorder ', 'LegendText   ', &
                                                  'AxisText     ', 'AxisGrid     ', 'AxisTick     ', 'AxisBg       ', &
                                                  'AxisBgHovered', 'AxisBgActive '] !< GetStyleColorName.
character(len=*), parameter :: VAR_NAMES(NVAR) = ['LineWeight        ', 'MarkerSize        ', 'FillAlpha         ', &
                                                  'PlotDefaultSize   ', 'PlotMinSize       ', 'PlotPadding       ', &
                                                  'LabelPadding      ', 'ViewScaleFactor   ', 'LegendPadding     ', &
                                                  'LegendInnerPadding', 'LegendSpacing     '] !< FIGURE's field table.
logical, parameter :: VAR_PAIR(NVAR) = [.false., .false., .false., .true., .true., .true., .true., .false., .true., &
                                        .true., .true.] !< A pair (ImVec2), else a float.

real(real32), protected :: s3_line_weight = 1.0_real32                    !< LineWeight.
real(real32), protected :: s3_marker_size = 4.0_real32                    !< MarkerSize.
real(real32), protected :: s3_fill_alpha = 1.0_real32                     !< FillAlpha.
real(real32), protected :: s3_default_size(2) = [400.0_real32, 400.0_real32] !< PlotDefaultSize.
real(real32), protected :: s3_min_size(2) = [200.0_real32, 200.0_real32]  !< PlotMinSize.
real(real32), protected :: s3_plot_padding(2) = [10.0_real32, 10.0_real32] !< PlotPadding.
real(real32), protected :: s3_label_padding(2) = [5.0_real32, 5.0_real32] !< LabelPadding.
real(real32), protected :: s3_view_factor = 1.0_real32                    !< ViewScaleFactor.
real(real32), protected :: s3_legend_padding(2) = [10.0_real32, 10.0_real32] !< LegendPadding.
real(real32), protected :: s3_legend_inner(2) = [5.0_real32, 5.0_real32]  !< LegendInnerPadding.
real(real32), protected :: s3_legend_spacing(2) = [5.0_real32, 0.0_real32] !< LegendSpacing.

real(real32)   :: colors(4, NCOL) = -1.0_real32     !< The colours: alpha -1 automatic (IMPLOT3D_AUTO_COL).
real(real32)   :: col_stack(4, STACK) = 0.0_real32   !< Colours pushed: the old values.
integer(int32) :: col_stack_idx(STACK) = 0_int32     !< ... which colour.
integer(int32) :: n_col = 0_int32                    !< Colour pushes held.
real(real32)   :: var_stack(2, STACK) = 0.0_real32   !< Variables pushed: the old values.
integer(int32) :: var_stack_idx(STACK) = 0_int32     !< ... which variable.
integer(int32) :: n_var = 0_int32                    !< Variable pushes held.
logical        :: synced = .false.                   !< `ps3_refresh` synced once.
integer(c_int) :: synced_gen(2) = 0_c_int            !< ... at these generations (`fig_generations`).

interface pf3_push_style_var
   !< As `ip3_push_style_var`: a variable of one number, or of a pair.
   module procedure push_var_r64, push_var_vec2
endinterface pf3_push_style_var

contains
   ! colours

   subroutine style3_vec4(idx, c)
   !< `GetStyleColorVec4`: the colour pushed, else its automatic value (`GetAutoColor`: Dear ImGui's colour of now).
   integer(int32), intent(in)  :: idx  !< Colour (S3_*).
   real(real32),   intent(out) :: c(4) !< RGBA.
   real(real64)                :: g(4) !< Dear ImGui's.
   integer(int32)              :: k    !< Colour looked up: AxisTick's automatic value is AxisGrid's.

   k = idx
   if (k == S3_AXIS_TICK .and. colors(4, k) == -1.0_real32) k = S3_AXIS_GRID
   if (colors(4, k) /= -1.0_real32) then
      c = colors(:, k)
      return
   endif
   select case (k)
   case (S3_TITLE_TEXT, S3_INLAY_TEXT, S3_LEGEND_TEXT, S3_AXIS_TEXT)
      call core_style_color_rgba(ImGuiCol_Text, g)
   case (S3_FRAME_BG)
      call core_style_color_rgba(ImGuiCol_FrameBg, g)
   case (S3_PLOT_BG)
      call core_style_color_rgba(ImGuiCol_WindowBg, g)
   case (S3_PLOT_BORDER, S3_LEGEND_BORDER)
      call core_style_color_rgba(ImGuiCol_Border, g)
   case (S3_LEGEND_BG)
      call core_style_color_rgba(ImGuiCol_PopupBg, g)
   case (S3_AXIS_GRID)
      call core_style_color_rgba(ImGuiCol_Text, g)
      g(4) = real(real(g(4), real32) * 0.25_real32, real64)
   case (S3_AXIS_BG)
      g = 0.0_real64
   case (S3_AXIS_BG_HOVERED)
      call core_style_color_rgba(ImGuiCol_ButtonHovered, g)
   case default
      call core_style_color_rgba(ImGuiCol_ButtonActive, g)
   endselect
   c = real(g, real32)
   endsubroutine style3_vec4

   function style3_u32(idx) result(col)
   !< `GetStyleColorU32`: `ColorConvertFloat4ToU32` of the colour (no style alpha, as ImPlot3D packs it).
   integer(int32), intent(in) :: idx !< Colour (S3_*).
   integer(int32)             :: col !< Packed.
   real(real32)               :: c(4) !< RGBA.

   call style3_vec4(idx, c)
   col = core_color(real(c(1), real64), real(c(2), real64), real(c(3), real64), real(c(4), real64))
   endfunction style3_u32

   function style3_color_u32(c) result(col)
   !< `ImGui::GetColorU32(ImVec4)`: a colour packed, its alpha times the style's (`style.Alpha`).
   real(real32), intent(in) :: c(4)  !< RGBA.
   integer(int32)           :: col   !< Packed.
   real(real64)             :: sa(2) !< The style's Alpha.
   integer(int32)           :: na    !< Its values.
   real(real32)             :: a     !< Alpha, in float.

   call core_style_var('Alpha', sa, na)
   a = c(4) * real(sa(1), real32)
   col = core_color(real(c(1), real64), real(c(2), real64), real(c(3), real64), real(a, real64))
   endfunction style3_color_u32

   function style3_alpha_u32(col) result(c)
   !< `ImGui::GetColorU32(ImU32)`: a packed colour's alpha byte times the style's alpha (truncated; unchanged at 1).
   integer(int32), intent(in) :: col   !< Packed colour.
   integer(int32)             :: c     !< Colour.
   real(real64)               :: sa(2) !< The style's Alpha.
   integer(int32)             :: na    !< Its values.
   integer(int64)             :: u, a  !< Unsigned, alpha.
   real(real32)               :: m     !< Factor.

   c = col
   call core_style_var('Alpha', sa, na)
   m = real(sa(1), real32)
   if (m >= 1.0_real32) return
   u = iand(int(col, int64), 4294967295_int64)
   a = ishft(u, -24)
   a = int(real(a, real32) * m, int64)
   u = ior(iand(u, 16777215_int64), ishft(a, 24))
   if (u >= 2147483648_int64) u = u - 4294967296_int64
   c = int(u, int32)
   endfunction style3_alpha_u32

   subroutine pf3_push_style_color(name, rgba)
   !< As `ip3_push_style_color` (components): the colour `name` (`ImPlot3DCol_*` without the prefix) until popped.
   character(len=*), intent(in) :: name    !< Colour name.
   real(real64),     intent(in) :: rgba(:) !< 3 or 4 components in [0, 1].
   integer(int32)               :: k       !< Colour.

   if (size(rgba) /= 3 .and. size(rgba) /= 4) error stop 'figure_plot3d_style: a colour has 3 or 4 components'
   k = col_index(name)
   if (k == 0_int32) error stop 'figure_plot3d_style: an unknown ImPlot3D colour name'
   if (n_col == STACK) error stop 'figure_plot3d_style: too many colour pushes'
   n_col = n_col + 1_int32
   col_stack(:, n_col) = colors(:, k)
   col_stack_idx(n_col) = k
   colors(:, k) = 1.0_real32
   colors(1:size(rgba), k) = real(rgba, real32)
   endsubroutine pf3_push_style_color

   subroutine pf3_pop_style_color(n)
   !< As `ip3_pop_style_color`: the `n` newest colour pushes undone (default 1).
   integer(int32), intent(in), optional :: n !< How many.
   integer(int32)                       :: m, j !< Pops, counter.

   m = 1_int32
   if (present(n)) m = n
   if (m > n_col) error stop 'figure_plot3d_style: more colour pops than pushes'
   do j = 1_int32, m
      colors(:, col_stack_idx(n_col)) = col_stack(:, n_col)
      n_col = n_col - 1_int32
   enddo
   endsubroutine pf3_pop_style_color

   ! variables

   subroutine push_var_r64(name, value)
   !< A variable of one number until popped.
   character(len=*), intent(in) :: name  !< Variable name.
   real(real64),     intent(in) :: value !< Value.
   real(real64)                 :: v(2)  !< As a pair.

   v(1) = value
   v(2) = 0.0_real64
   call push_var(name, v, .false.)
   endsubroutine push_var_r64

   subroutine push_var_vec2(name, value)
   !< A variable of a pair until popped.
   character(len=*), intent(in) :: name     !< Variable name.
   real(real64),     intent(in) :: value(2) !< Values.

   call push_var(name, value, .true.)
   endsubroutine push_var_vec2

   subroutine push_var(name, v, pair)
   !< Push a variable (its old value kept), refused when its kind (a number, a pair) differs.
   character(len=*), intent(in) :: name !< Variable name.
   real(real64),     intent(in) :: v(2) !< Values.
   logical,          intent(in) :: pair !< A pair given.
   integer(int32)               :: k    !< Variable.

   k = var_index(name)
   if (k == 0_int32) error stop 'figure_plot3d_style: an unknown ImPlot3D style variable'
   if (VAR_PAIR(k) .neqv. pair) error stop 'figure_plot3d_style: a number for a pair, or a pair for a number'
   if (n_var == STACK) error stop 'figure_plot3d_style: too many variable pushes'
   n_var = n_var + 1_int32
   call get_var(k, var_stack(:, n_var))
   var_stack_idx(n_var) = k
   call set_var(k, real(v, real32))
   endsubroutine push_var

   subroutine pf3_pop_style_var(n)
   !< As `ip3_pop_style_var`: the `n` newest variable pushes undone (default 1).
   integer(int32), intent(in), optional :: n !< How many.
   integer(int32)                       :: m, j !< Pops, counter.

   m = 1_int32
   if (present(n)) m = n
   if (m > n_var) error stop 'figure_plot3d_style: more variable pops than pushes'
   do j = 1_int32, m
      call set_var(var_stack_idx(n_var), var_stack(:, n_var))
      n_var = n_var - 1_int32
   enddo
   endsubroutine pf3_pop_style_var

   ! FIGURE's style

   subroutine ps3_sync()
   !< The colours (as stored: an automatic one stays automatic) and the variables as FIGURE's style holds them in
   !< ImPlot3D's context (`fig_style_color`, `fig_style_var` of the library 2). No allocation (names as substrings).
   integer(int32) :: k        !< Index.
   integer(c_int) :: n, st, l !< Count, status, a name's length.
   real(c_double) :: v(2)     !< Value(s).
   real(c_float)  :: c(4)     !< Colour.
   real(real32)   :: w(2)     !< As floats.

   do k = 1_int32, NCOL
      c = 0.0_c_float
      l = len_trim(COL_NAMES(k), c_int)
      st = fig_style_color(2_c_int, COL_NAMES(k)(1:l), l, 2_c_int, c)
      if (st /= 0_c_int) cycle
      colors(1, k) = real(c(1), real32)
      colors(2, k) = real(c(2), real32)
      colors(3, k) = real(c(3), real32)
      colors(4, k) = real(c(4), real32)
   enddo
   do k = 1_int32, NVAR
      n = 0_c_int
      v = 0.0_c_double
      l = len_trim(VAR_NAMES(k), c_int)
      st = fig_style_var(2_c_int, VAR_NAMES(k)(1:l), l, 0_c_int, v, n)
      if (st /= 0_c_int) cycle
      w(1) = real(v(1), real32)
      w(2) = real(v(2), real32)
      call set_var(k, w)
   enddo
   endsubroutine ps3_sync

   subroutine ps3_refresh()
   !< `ps3_sync` when the plots' styles changed since the last refresh (`fig_generations`).
   integer(c_int) :: gen(2) !< Generations: contexts, the plots' styles.

   call fig_generations(gen(1), gen(2))
   if (synced .and. gen(1) == synced_gen(1) .and. gen(2) == synced_gen(2)) return
   synced = .true.
   synced_gen = gen
   call ps3_sync()
   endsubroutine ps3_refresh

   ! private

   pure function col_index(name) result(k)
   !< A colour's index from its name (0: unknown).
   character(len=*), intent(in) :: name !< Name.
   integer(int32)               :: k    !< Index.

   do k = 1_int32, NCOL
      if (trim(COL_NAMES(k)) == trim(name)) return
   enddo
   k = 0_int32
   endfunction col_index

   pure function var_index(name) result(k)
   !< A variable's index from its name (0: unknown).
   character(len=*), intent(in) :: name !< Name.
   integer(int32)               :: k    !< Index.

   do k = 1_int32, NVAR
      if (trim(VAR_NAMES(k)) == trim(name)) return
   enddo
   k = 0_int32
   endfunction var_index

   subroutine get_var(k, v)
   !< A variable's value(s).
   integer(int32), intent(in)  :: k    !< Variable.
   real(real32),   intent(out) :: v(2) !< Value(s).

   v = 0.0_real32
   select case (k)
   case (1_int32)
      v(1) = s3_line_weight
   case (2_int32)
      v(1) = s3_marker_size
   case (3_int32)
      v(1) = s3_fill_alpha
   case (4_int32)
      v = s3_default_size
   case (5_int32)
      v = s3_min_size
   case (6_int32)
      v = s3_plot_padding
   case (7_int32)
      v = s3_label_padding
   case (8_int32)
      v(1) = s3_view_factor
   case (9_int32)
      v = s3_legend_padding
   case (10_int32)
      v = s3_legend_inner
   case default
      v = s3_legend_spacing
   endselect
   endsubroutine get_var

   subroutine set_var(k, v)
   !< A variable set.
   integer(int32), intent(in) :: k    !< Variable.
   real(real32),   intent(in) :: v(2) !< Value(s).

   select case (k)
   case (1_int32)
      s3_line_weight = v(1)
   case (2_int32)
      s3_marker_size = v(1)
   case (3_int32)
      s3_fill_alpha = v(1)
   case (4_int32)
      s3_default_size = v
   case (5_int32)
      s3_min_size = v
   case (6_int32)
      s3_plot_padding = v
   case (7_int32)
      s3_label_padding = v
   case (8_int32)
      s3_view_factor = v(1)
   case (9_int32)
      s3_legend_padding = v
   case (10_int32)
      s3_legend_inner = v
   case default
      s3_legend_spacing = v
   endselect
   endsubroutine set_var
endmodule figure_plot3d_style
