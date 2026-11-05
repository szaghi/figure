!< figure_style, every colour and variable of the Dear ImGui and ImPlot styles, by name.
module figure_style
!< figure_style, every colour and variable of the Dear ImGui and ImPlot styles, by name.
!<
!< The style is global: a change applies to everything drawn afterwards, until it is changed again (or a new style is
!< chosen with `app%set_style`, which resets every colour and variable). Names are the libraries' own:
!<
!< - colours: Dear ImGui's `ImGuiCol_*` without the prefix (`Text`, `WindowBg`, `Button`, `SliderGrab`, ...), ImPlot's
!<   `ImPlotCol_*` without the prefix (`PlotBg`, `AxisGrid`, `LegendBg`, ...);
!< - variables: the fields of `ImGuiStyle` (`WindowRounding`, `FramePadding`, `ItemSpacing`, ...) and of `ImPlotStyle`
!<   (`PlotBorderSize`, `PlotPadding`, `MajorGridSize`, ...), each a number, a pair of numbers, a logical or an integer.
!<   Line weights and marker sizes are per item in ImPlot 1.2: `ip_spec`.
!<
!< Colours are given as `'#rrggbb'` or `'#rrggbbaa'`, or as `[r, g, b]` / `[r, g, b, a]` in [0, 1]. Variables in
!< pixels hold the values Dear ImGui uses, already multiplied by the display's content scale (`app%content_scale()`).
use, intrinsic :: iso_c_binding, only : c_double, c_float, c_int
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure_base, only : figure_check, figure_fail
use figure_c_native, only : FIG_ERR_ARGUMENT, fig_style_color, fig_style_var

implicit none
private
public :: ig_set_style_color, ig_get_style_color, ig_set_style_var, ig_get_style_var
public :: ip_set_style_color, ip_get_style_color, ip_set_style_var, ip_get_style_var
public :: hex_color

integer(c_int), parameter :: LIB_IMGUI  = 0_c_int !< Dear ImGui.
integer(c_int), parameter :: LIB_IMPLOT = 1_c_int !< ImPlot.

interface ig_set_style_color
   !< Set a Dear ImGui colour, by hex string or by components.
   module procedure ig_set_style_color_hex, ig_set_style_color_rgba
endinterface ig_set_style_color

interface ip_set_style_color
   !< Set an ImPlot colour, by hex string or by components.
   module procedure ip_set_style_color_hex, ip_set_style_color_rgba
endinterface ip_set_style_color

interface ig_set_style_var
   !< Set a Dear ImGui style variable: a number, a pair, a logical or an integer.
   module procedure ig_set_style_var_r64, ig_set_style_var_vec2, ig_set_style_var_logical, ig_set_style_var_i32
endinterface ig_set_style_var

interface ip_set_style_var
   !< Set an ImPlot style variable: a number, a pair or a logical.
   module procedure ip_set_style_var_r64, ip_set_style_var_vec2, ip_set_style_var_logical
endinterface ip_set_style_var

contains
   pure subroutine hex_color(text, rgba, ok)
   !< Parse `'#rrggbb'` or `'#rrggbbaa'` (the `#` optional, either case) into components in [0, 1].
   character(len=*), intent(in)  :: text    !< Hex colour.
   real(real64),     intent(out) :: rgba(4) !< Components; alpha 1 when not given.
   logical,          intent(out) :: ok      !< The text is a valid colour.
   character(len=:), allocatable :: h       !< Hex digits.
   integer(int32)                :: k       !< Component.
   integer(int32)                :: hi      !< High digit.
   integer(int32)                :: lo      !< Low digit.

   rgba = [0.0_real64, 0.0_real64, 0.0_real64, 1.0_real64]
   h = trim(adjustl(text))
   if (len(h) > 0) then
      if (h(1:1) == '#') h = h(2:)
   endif
   ok = len(h) == 6 .or. len(h) == 8
   if (.not. ok) return
   do k = 1_int32, len(h) / 2
      hi = digit(h(2 * k - 1:2 * k - 1))
      lo = digit(h(2 * k:2 * k))
      if (hi < 0_int32 .or. lo < 0_int32) then
         ok = .false.
         return
      endif
      rgba(k) = real(16_int32 * hi + lo, real64) / 255.0_real64
   enddo
   contains
      pure function digit(c) result(v)
      !< Value of a hex digit, -1 if not one.
      character(len=1), intent(in) :: c !< Character.
      integer(int32)               :: v !< Value.

      v = index('0123456789abcdef', c) - 1_int32
      if (v < 0_int32) v = index('0123456789ABCDEF', c) - 1_int32
      endfunction digit
   endsubroutine hex_color

   ! ---- colours --------------------------------------------------------------------------------------------------------
   subroutine set_color(lib, who, name, rgba, stat)
   !< Write a colour given as components (3 or 4).
   integer(c_int),   intent(in)            :: lib     !< Library.
   character(len=*), intent(in)            :: who     !< Caller, for messages.
   character(len=*), intent(in)            :: name    !< Colour name.
   real(real64),     intent(in)            :: rgba(:) !< Components.
   integer(int32),   intent(out), optional :: stat    !< Status.
   real(c_float)                           :: c(4)    !< C components.

   if (size(rgba) /= 3 .and. size(rgba) /= 4) then
      call figure_fail(FIG_ERR_ARGUMENT, who//': a colour has 3 or 4 components', stat)
      return
   endif
   c = 1.0_c_float
   c(1:size(rgba)) = real(rgba, c_float)
   call figure_check(fig_style_color(lib, name, len(name, c_int), 1_c_int, c), stat)
   endsubroutine set_color

   subroutine set_color_hex(lib, who, name, color, stat)
   !< Write a colour given as a hex string.
   integer(c_int),   intent(in)            :: lib     !< Library.
   character(len=*), intent(in)            :: who     !< Caller, for messages.
   character(len=*), intent(in)            :: name    !< Colour name.
   character(len=*), intent(in)            :: color   !< `'#rrggbb'` or `'#rrggbbaa'`.
   integer(int32),   intent(out), optional :: stat    !< Status.
   real(real64)                            :: rgba(4) !< Components.
   logical                                 :: ok      !< Valid hex colour.

   call hex_color(color, rgba, ok)
   if (.not. ok) then
      call figure_fail(FIG_ERR_ARGUMENT, who//": '"//trim(color)//"' is not '#rrggbb' or '#rrggbbaa'", stat)
      return
   endif
   call set_color(lib, who, name, rgba, stat)
   endsubroutine set_color_hex

   subroutine get_color(lib, name, rgba, stat)
   !< Read a colour.
   integer(c_int),   intent(in)            :: lib     !< Library.
   character(len=*), intent(in)            :: name    !< Colour name.
   real(real64),     intent(out)           :: rgba(4) !< Components in [0, 1].
   integer(int32),   intent(out), optional :: stat    !< Status.
   real(c_float)                           :: c(4)    !< C components.

   c = 0.0_c_float
   call figure_check(fig_style_color(lib, name, len(name, c_int), 0_c_int, c), stat)
   rgba = real(c, real64)
   endsubroutine get_color

   subroutine ig_set_style_color_hex(name, color, stat)
   !< Set the Dear ImGui colour `name` (`Text`, `WindowBg`, `Button`, ...) from `'#rrggbb'` or `'#rrggbbaa'`.
   character(len=*), intent(in)            :: name  !< Colour name (`ImGuiCol_*` without the prefix).
   character(len=*), intent(in)            :: color !< Hex colour.
   integer(int32),   intent(out), optional :: stat  !< Status: `FIG_ERR_ARGUMENT` for an unknown name or a bad colour.

   call set_color_hex(LIB_IMGUI, 'ig_set_style_color', name, color, stat)
   endsubroutine ig_set_style_color_hex

   subroutine ig_set_style_color_rgba(name, rgba, stat)
   !< Set the Dear ImGui colour `name` from `[r, g, b]` or `[r, g, b, a]` in [0, 1].
   character(len=*), intent(in)            :: name    !< Colour name (`ImGuiCol_*` without the prefix).
   real(real64),     intent(in)            :: rgba(:) !< Components.
   integer(int32),   intent(out), optional :: stat    !< Status: `FIG_ERR_ARGUMENT` for an unknown name or a bad colour.

   call set_color(LIB_IMGUI, 'ig_set_style_color', name, rgba, stat)
   endsubroutine ig_set_style_color_rgba

   subroutine ig_get_style_color(name, rgba, stat)
   !< The Dear ImGui colour `name`, as `[r, g, b, a]` in [0, 1].
   character(len=*), intent(in)            :: name    !< Colour name.
   real(real64),     intent(out)           :: rgba(4) !< Components.
   integer(int32),   intent(out), optional :: stat    !< Status: `FIG_ERR_ARGUMENT` for an unknown name.

   call get_color(LIB_IMGUI, name, rgba, stat)
   endsubroutine ig_get_style_color

   subroutine ip_set_style_color_hex(name, color, stat)
   !< Set the ImPlot colour `name` (`PlotBg`, `AxisGrid`, `LegendBg`, ...) from `'#rrggbb'` or `'#rrggbbaa'`.
   character(len=*), intent(in)            :: name  !< Colour name (`ImPlotCol_*` without the prefix).
   character(len=*), intent(in)            :: color !< Hex colour.
   integer(int32),   intent(out), optional :: stat  !< Status: `FIG_ERR_ARGUMENT` for an unknown name or a bad colour.

   call set_color_hex(LIB_IMPLOT, 'ip_set_style_color', name, color, stat)
   endsubroutine ip_set_style_color_hex

   subroutine ip_set_style_color_rgba(name, rgba, stat)
   !< Set the ImPlot colour `name` from `[r, g, b]` or `[r, g, b, a]` in [0, 1].
   character(len=*), intent(in)            :: name    !< Colour name (`ImPlotCol_*` without the prefix).
   real(real64),     intent(in)            :: rgba(:) !< Components.
   integer(int32),   intent(out), optional :: stat    !< Status: `FIG_ERR_ARGUMENT` for an unknown name or a bad colour.

   call set_color(LIB_IMPLOT, 'ip_set_style_color', name, rgba, stat)
   endsubroutine ip_set_style_color_rgba

   subroutine ip_get_style_color(name, rgba, stat)
   !< The ImPlot colour `name`, as `[r, g, b, a]` in [0, 1]; ImPlot's automatic colours (derived from Dear ImGui's)
   !< are returned as ImPlot draws them.
   character(len=*), intent(in)            :: name    !< Colour name.
   real(real64),     intent(out)           :: rgba(4) !< Components.
   integer(int32),   intent(out), optional :: stat    !< Status: `FIG_ERR_ARGUMENT` for an unknown name.

   call get_color(LIB_IMPLOT, name, rgba, stat)
   endsubroutine ip_get_style_color

   ! ---- variables ------------------------------------------------------------------------------------------------------
   subroutine set_var(lib, name, values, n, stat)
   !< Write a style variable of `n` values.
   integer(c_int),   intent(in)            :: lib       !< Library.
   character(len=*), intent(in)            :: name      !< Variable name.
   real(real64),     intent(in)            :: values(2) !< Values.
   integer(c_int),   intent(in)            :: n         !< How many.
   integer(int32),   intent(out), optional :: stat      !< Status.
   real(c_double)                          :: v(2)      !< C values.
   integer(c_int)                          :: count     !< C count.

   v = real(values, c_double)
   count = n
   call figure_check(fig_style_var(lib, name, len(name, c_int), 1_c_int, v, count), stat)
   endsubroutine set_var

   subroutine get_var(lib, name, values, n, stat)
   !< Read a style variable.
   integer(c_int),   intent(in)            :: lib       !< Library.
   character(len=*), intent(in)            :: name      !< Variable name.
   real(real64),     intent(out)           :: values(2) !< Values (the second is 0 for a single value).
   integer(int32),   intent(out)           :: n         !< How many values the variable has: 1 or 2.
   integer(int32),   intent(out), optional :: stat      !< Status.
   real(c_double)                          :: v(2)      !< C values.
   integer(c_int)                          :: count     !< C count.

   v = 0.0_c_double
   count = 0_c_int
   call figure_check(fig_style_var(lib, name, len(name, c_int), 0_c_int, v, count), stat)
   values = real(v, real64)
   n = int(count, int32)
   endsubroutine get_var

   subroutine ig_set_style_var_r64(name, value, stat)
   !< Set a Dear ImGui style variable holding one number (`WindowRounding`, `Alpha`, `IndentSpacing`, ...).
   character(len=*), intent(in)            :: name  !< Variable name (a field of `ImGuiStyle`).
   real(real64),     intent(in)            :: value !< Value.
   integer(int32),   intent(out), optional :: stat  !< Status: `FIG_ERR_ARGUMENT` for an unknown name or arity.

   call set_var(LIB_IMGUI, name, [value, 0.0_real64], 1_c_int, stat)
   endsubroutine ig_set_style_var_r64

   subroutine ig_set_style_var_vec2(name, value, stat)
   !< Set a Dear ImGui style variable holding a pair (`WindowPadding`, `FramePadding`, `ItemSpacing`, ...).
   character(len=*), intent(in)            :: name     !< Variable name (a field of `ImGuiStyle`).
   real(real64),     intent(in)            :: value(2) !< Values (x, y).
   integer(int32),   intent(out), optional :: stat     !< Status: `FIG_ERR_ARGUMENT` for an unknown name or arity.

   call set_var(LIB_IMGUI, name, value, 2_c_int, stat)
   endsubroutine ig_set_style_var_vec2

   subroutine ig_set_style_var_logical(name, value, stat)
   !< Set a Dear ImGui style variable holding a logical (`AntiAliasedLines`, ...).
   character(len=*), intent(in)            :: name  !< Variable name (a field of `ImGuiStyle`).
   logical,          intent(in)            :: value !< Value.
   integer(int32),   intent(out), optional :: stat  !< Status: `FIG_ERR_ARGUMENT` for an unknown name.

   call set_var(LIB_IMGUI, name, [merge(1.0_real64, 0.0_real64, value), 0.0_real64], 1_c_int, stat)
   endsubroutine ig_set_style_var_logical

   subroutine ig_set_style_var_i32(name, value, stat)
   !< Set a Dear ImGui style variable holding an enumeration (`WindowMenuButtonPosition`, ...).
   character(len=*), intent(in)            :: name  !< Variable name (a field of `ImGuiStyle`).
   integer(int32),   intent(in)            :: value !< Value.
   integer(int32),   intent(out), optional :: stat  !< Status: `FIG_ERR_ARGUMENT` for an unknown name.

   call set_var(LIB_IMGUI, name, [real(value, real64), 0.0_real64], 1_c_int, stat)
   endsubroutine ig_set_style_var_i32

   subroutine ig_get_style_var(name, values, n, stat)
   !< A Dear ImGui style variable: its value(s) and how many it has (1, or 2 for a pair); a logical reads 0 or 1.
   character(len=*), intent(in)            :: name      !< Variable name.
   real(real64),     intent(out)           :: values(2) !< Values.
   integer(int32),   intent(out)           :: n         !< 1 or 2.
   integer(int32),   intent(out), optional :: stat      !< Status: `FIG_ERR_ARGUMENT` for an unknown name.

   call get_var(LIB_IMGUI, name, values, n, stat)
   endsubroutine ig_get_style_var

   subroutine ip_set_style_var_r64(name, value, stat)
   !< Set an ImPlot style variable holding one number (`PlotBorderSize`, `MinorAlpha`, ...).
   character(len=*), intent(in)            :: name  !< Variable name (a field of `ImPlotStyle`).
   real(real64),     intent(in)            :: value !< Value.
   integer(int32),   intent(out), optional :: stat  !< Status: `FIG_ERR_ARGUMENT` for an unknown name or arity.

   call set_var(LIB_IMPLOT, name, [value, 0.0_real64], 1_c_int, stat)
   endsubroutine ip_set_style_var_r64

   subroutine ip_set_style_var_vec2(name, value, stat)
   !< Set an ImPlot style variable holding a pair (`PlotPadding`, `MajorGridSize`, `LegendPadding`, ...).
   character(len=*), intent(in)            :: name     !< Variable name (a field of `ImPlotStyle`).
   real(real64),     intent(in)            :: value(2) !< Values (x, y).
   integer(int32),   intent(out), optional :: stat     !< Status: `FIG_ERR_ARGUMENT` for an unknown name or arity.

   call set_var(LIB_IMPLOT, name, value, 2_c_int, stat)
   endsubroutine ip_set_style_var_vec2

   subroutine ip_set_style_var_logical(name, value, stat)
   !< Set an ImPlot style variable holding a logical (`UseLocalTime`, `UseISO8601`, `Use24HourClock`).
   character(len=*), intent(in)            :: name  !< Variable name (a field of `ImPlotStyle`).
   logical,          intent(in)            :: value !< Value.
   integer(int32),   intent(out), optional :: stat  !< Status: `FIG_ERR_ARGUMENT` for an unknown name.

   call set_var(LIB_IMPLOT, name, [merge(1.0_real64, 0.0_real64, value), 0.0_real64], 1_c_int, stat)
   endsubroutine ip_set_style_var_logical

   subroutine ip_get_style_var(name, values, n, stat)
   !< An ImPlot style variable: its value(s) and how many it has (1, or 2 for a pair); a logical reads 0 or 1.
   character(len=*), intent(in)            :: name      !< Variable name.
   real(real64),     intent(out)           :: values(2) !< Values.
   integer(int32),   intent(out)           :: n         !< 1 or 2.
   integer(int32),   intent(out), optional :: stat      !< Status: `FIG_ERR_ARGUMENT` for an unknown name.

   call get_var(LIB_IMPLOT, name, values, n, stat)
   endsubroutine ip_get_style_var
endmodule figure_style
