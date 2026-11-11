!< figure_numbers, numbers and choices: fields, drag boxes and sliders for integers and reals, scalar or vector; angles;
!< ranges; radio buttons and list boxes.
module figure_numbers
!< figure_numbers, numbers and choices: fields, drag boxes and sliders for integers and reals, scalar or vector; angles;
!< ranges; radio buttons and list boxes.
!<
!< The number widgets are generic over the kind of the value, `int32`, `int64`, `real32` or `real64`, scalar or rank 1
!< (a vector: one field, drag box or slider per component, side by side, sharing the bounds). Bounds and steps have the
!< kind of the value; `speed` is `real64` whatever the kind. Each returns `.true.` on the frame the user changed the
!< value, which it writes back in place. A `format` is a C printf format of one value of the kind's family (integer:
!< `%d`, `%i`, `%u`; real: `%f`, `%e`, `%g`, `%a`), checked by `format_ok` before Dear ImGui sees it (`FIG_ERR_ARGUMENT`
!< otherwise); an `int64`'s format is given as an `int32`'s (`'%d'`) and FIGURE adds the length modifier C needs.
!<
!< Every procedure refuses a call from a task or with no frame open (`FIG_ERR_STATE`, as every drawing call), and
!< arguments Dear ImGui would assert on (`FIG_ERR_ARGUMENT`); `stat` is optional: absent, a failure stops with
!< `error stop` and the message (usage errors: reported by the next `app%next_frame`). None opens a scope: the list
!< box's begin and end are inside `ig_list_box`. widgets.md, "Numbers" and "Choices".
use, intrinsic :: iso_c_binding, only : c_bool, c_char, c_double, c_float, c_int, c_long_long, c_loc, c_null_char, &
                                        c_null_ptr, c_ptr
use, intrinsic :: ieee_arithmetic, only : ieee_is_nan
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use figure_base, only : cstr, figure_check, figure_draw_refused, figure_fail, format_refused, FORMAT_INTEGER, &
                        FORMAT_REAL
use figure_c_native, only : fig_drag_range, fig_list_box, FIG_ERR_ARGUMENT, FIG_OK
use figure_cimgui, only : igDragScalar, igDragScalarN, igInputScalar, igInputScalarN, igRadioButton_Bool, igSliderAngle, &
                          igSliderScalar, igSliderScalarN
use figure_cimgui_enums, only : ImGuiDataType_Double, ImGuiDataType_Float, ImGuiDataType_S32, ImGuiDataType_S64,    &
                                ImGuiInputTextFlags_EnterReturnsTrue, ImGuiInputTextFlags_ReadOnly,                &
                                ImGuiSliderFlags_AlwaysClamp, ImGuiSliderFlags_ClampZeroRange, ImGuiSliderFlags_Logarithmic

implicit none
private
public :: ig_input, ig_drag, ig_slider, ig_slider_angle, ig_drag_range, ig_radio, ig_list_box

type :: number_kind
   !< What a widget needs to know of a kind: Dear ImGui's data type, the format family, the C length modifier.
   integer(c_int) :: dtype = 0_c_int     !< ImGuiDataType_*.
   integer(int32) :: family = 0_int32    !< FORMAT_INTEGER or FORMAT_REAL.
   logical        :: wide = .false.      !< 64-bit integer: 'll' before the conversion of a format.
endtype number_kind

type(number_kind), parameter :: K_I32 = number_kind(ImGuiDataType_S32, FORMAT_INTEGER, .false.) !< int32.
type(number_kind), parameter :: K_I64 = number_kind(ImGuiDataType_S64, FORMAT_INTEGER, .true.)  !< int64.
type(number_kind), parameter :: K_R32 = number_kind(ImGuiDataType_Float, FORMAT_REAL, .false.)  !< real32.
type(number_kind), parameter :: K_R64 = number_kind(ImGuiDataType_Double, FORMAT_REAL, .false.) !< real64.
! Half the range of each kind: the bounds Dear ImGui's sliders accept (it asserts beyond), and the bounds of a drag
! given none (so that Dear ImGui's vmax - vmin neither overflows nor traps).
integer(c_int),       parameter :: HALF_I32 = ishft(huge(0_c_int), -1)               !< int32.
integer(c_long_long), parameter :: HALF_I64 = ishft(huge(0_c_long_long), -1)         !< int64.
real(c_float),        parameter :: HALF_R32 = huge(0.0_c_float) / 2.0_c_float       !< real32.
real(c_double),       parameter :: HALF_R64 = huge(0.0_c_double) / 2.0_c_double     !< real64.
integer(int32),       parameter :: CONVERSION_MAX = 24_int32 !< Longest conversion of a format (Dear ImGui copies it
                                                              !< into 32 bytes, 'll' included, and asserts beyond).
real(real64),         parameter :: PI = acos(-1.0_real64)    !< pi.
integer(int32),       parameter :: FAST_I32 = 214748364_int32            !< Largest int32 step whose 10 steps fit.
integer(int64),       parameter :: FAST_I64 = 922337203685477580_int64   !< Largest int64 step whose 10 steps fit.

interface ig_input
   !< A field for a number or a vector of numbers, typed: `ig_input(label, value [, step] [, format] [,
   !< enter_returns] [, read_only] [, stat]) → logical`. `value` `int32`, `int64`, `real32` or `real64`, scalar or
   !< rank 1 (one field per component). `step` (> 0, the kind of `value`) adds - and + buttons (ctrl: 10 steps).
   !< `format` default: `'%d'` for integers, `'%.6g'` for reals. True on the frame the user changes the value: when
   !< the field is left (enter, tab, a click elsewhere) after an edit, or a button is pressed; with
   !< `enter_returns=.true.`, only on the frame enter is pressed. `read_only=.true.`: shown, selectable, not editable.
   module procedure ig_input_i32, ig_input_i64, ig_input_r32, ig_input_r64
   module procedure ig_input_i32_v, ig_input_i64_v, ig_input_r32_v, ig_input_r64_v
endinterface ig_input

interface ig_drag
   !< A drag box for a number or a vector: `ig_drag(label, value [, speed] [, vmin] [, vmax] [, format] [, scale] [,
   !< clamp] [, stat]) → logical`. Dragged sideways, `value` changes by `speed` per pixel (default 1; shift: 10 times,
   !< alt: a hundredth); a double click or ctrl-click types a value. `vmin`, `vmax` (the kind of `value`) stop the
   !< drag; `clamp=.true.` clamps a typed value too. `scale='log'` (with `vmin` and `vmax`): equal drags multiply the
   !< value by equal factors. Reals are rounded to the precision `format` shows.
   module procedure ig_drag_i32, ig_drag_i64, ig_drag_r32, ig_drag_r64
   module procedure ig_drag_i32_v, ig_drag_i64_v, ig_drag_r32_v, ig_drag_r64_v
endinterface ig_drag

interface ig_slider
   !< A slider for a number or a vector: `ig_slider(label, value, vmin, vmax [, format] [, scale] [, clamp] [, stat])
   !< → logical`. A click or a drag sets `value` in [vmin, vmax] (vmin > vmax: a reversed slider); ctrl-click types
   !< one (`clamp=.true.`: clamped too). `scale='log'`: the middle of the slider is the geometric mean of positive
   !< ends. `vmin`, `vmax` within half the range of the kind. Reals are rounded to the precision `format` shows.
   module procedure ig_slider_i32, ig_slider_i64, ig_slider_r32, ig_slider_r64
   module procedure ig_slider_i32_v, ig_slider_i64_v, ig_slider_r32_v, ig_slider_r64_v
endinterface ig_slider

interface ig_slider_angle
   !< A slider for an angle kept in radians and shown in degrees: `ig_slider_angle(label, radians [, deg_min] [,
   !< deg_max] [, format] [, stat]) → logical` (`SliderAngle`), `real32` or `real64`; bounds in degrees (default -360
   !< and 360), `format` of the degrees (default `'%.0f deg'`). Edited in single precision: `radians` is written only
   !< on the frames it changes.
   module procedure ig_slider_angle_r32, ig_slider_angle_r64
endinterface ig_slider_angle

interface ig_drag_range
   !< Two drag boxes for the ends of a range [lo, hi] and one label: `ig_drag_range(label, lo, hi [, speed] [, vmin]
   !< [, vmax] [, format] [, stat]) → logical` (`DragFloatRange2`, `DragIntRange2` for any kind). `lo` stays in
   !< [vmin, hi] and `hi` in [lo, vmax], typed values too.
   module procedure ig_drag_range_i32, ig_drag_range_i64, ig_drag_range_r32, ig_drag_range_r64
endinterface ig_drag_range

contains
   ! ---- choices -------------------------------------------------------------------------------------------------------
   recursive function ig_radio(label, current, value, stat) result(clicked)
   !< A radio button of a group sharing `current`: drawn chosen when `current == value`; a click sets `current =
   !< value` and returns true (on that frame; also when it was chosen already). One call per option, each with its own
   !< `value` (`RadioButton`).
   character(len=*), intent(in)            :: label   !< Label (also the id; '##id' hides it).
   integer(int32),   intent(inout)         :: current !< The option chosen in the group.
   integer(int32),   intent(in)            :: value   !< This button's option.
   integer(int32),   intent(out), optional :: stat    !< Status.
   logical                                 :: clicked !< Clicked this frame.

   clicked = .false.
   if (figure_draw_refused('ig_radio', stat)) return ! a task does not draw
   clicked = logical(igRadioButton_Bool(cstr(label), logical(current == value, c_bool)))
   if (clicked) current = value
   call figure_check(FIG_OK, stat)
   endfunction ig_radio

   recursive function ig_list_box(label, current, items, height, stat) result(changed)
   !< A list of `items` shown at once, in a box that scrolls; `current` is the index of the one chosen (1 to
   !< `size(items)`; any other value shows none chosen). True on the frame the user picks an item (`current` is then
   !< its index); a pick is reported as an edit by `ig_last_item`. Only the rows in view are drawn. Trailing blanks of
   !< the items are not shown; items may repeat a text (they are told apart by their index).
   character(len=*), intent(in)            :: label    !< Label (also the id; '##id' hides it).
   integer(int32),   intent(inout)         :: current  !< Index of the chosen item.
   character(len=*), intent(in)            :: items(:) !< Items.
   real(real64),     intent(in),  optional :: height   !< Height [pixels]; 0 (default): up to 7 items; < 0: the
                                                        !< height left in the window minus |height|.
   integer(int32),   intent(out), optional :: stat     !< Status.
   logical                                 :: changed  !< An item was picked this frame.
   integer(c_int)                          :: c        !< 0-based index of the chosen item, -1 none.
   real(c_double)                          :: h        !< Height [pixels].

   changed = .false.
   if (figure_draw_refused('ig_list_box', stat)) return ! a task does not draw
   h = 0.0_c_double
   if (present(height)) then
      if (.not. real_range('ig_list_box', height, 0.0_real64, .true., .false., real(HALF_R32, real64), .false., stat, &
          'height')) return
      h = real(height, c_double)
   endif
   c = -1_c_int
   if (current >= 1_int32 .and. current <= size(items, kind=int32)) c = int(current - 1_int32, c_int)
   changed = fig_list_box(cstr(label), c, items, len(items, kind=c_int), size(items, kind=c_int), h) == 1_c_int
   if (changed) current = int(c, int32) + 1_int32
   call figure_check(FIG_OK, stat)
   endfunction ig_list_box

   ! ---- angles --------------------------------------------------------------------------------------------------------
   recursive function ig_slider_angle_r32(label, radians, deg_min, deg_max, format, stat) result(changed)
   !< A slider for a `real32` angle in radians, shown in degrees: see `ig_slider_angle`.
   character(len=*), intent(in)            :: label   !< Label (also the id; '##id' hides it).
   real(real32),     intent(inout)         :: radians !< Angle [radians].
   real(real32),     intent(in),  optional :: deg_min !< Left end [degrees] (default -360).
   real(real32),     intent(in),  optional :: deg_max !< Right end [degrees] (default 360).
   character(len=*), intent(in),  optional :: format  !< printf format of the degrees, a real (default '%.0f deg').
   integer(int32),   intent(out), optional :: stat    !< Status.
   logical                                 :: changed !< Changed this frame.
   real(c_float), target                   :: v       !< C copy of `radians`.
   real(real64)                            :: d(2)    !< The ends [degrees].

   changed = .false.
   if (figure_draw_refused('ig_slider_angle', stat)) return ! a task does not draw
   d = [-360.0_real64, 360.0_real64]
   if (present(deg_min)) d(1) = real(deg_min, real64)
   if (present(deg_max)) d(2) = real(deg_max, real64)
   v = real(radians, c_float)
   if (angle_core(label, real(radians, real64), v, d, format, stat)) then
      radians = real(v, real32)
      changed = .true.
   endif
   endfunction ig_slider_angle_r32

   recursive function ig_slider_angle_r64(label, radians, deg_min, deg_max, format, stat) result(changed)
   !< A slider for a `real64` angle in radians, shown in degrees: see `ig_slider_angle`.
   character(len=*), intent(in)            :: label   !< Label (also the id; '##id' hides it).
   real(real64),     intent(inout)         :: radians !< Angle [radians].
   real(real64),     intent(in),  optional :: deg_min !< Left end [degrees] (default -360).
   real(real64),     intent(in),  optional :: deg_max !< Right end [degrees] (default 360).
   character(len=*), intent(in),  optional :: format  !< printf format of the degrees, a real (default '%.0f deg').
   integer(int32),   intent(out), optional :: stat    !< Status.
   logical                                 :: changed !< Changed this frame.
   real(c_float), target                   :: v       !< C copy of `radians`.
   real(real64)                            :: d(2)    !< The ends [degrees].

   changed = .false.
   if (figure_draw_refused('ig_slider_angle', stat)) return ! a task does not draw
   d = [-360.0_real64, 360.0_real64]
   if (present(deg_min)) d(1) = deg_min
   if (present(deg_max)) d(2) = deg_max
   v = 0.0_c_float
   if (.not. ieee_is_nan(radians)) then
      if (abs(radians) <= real(huge(v), real64)) v = real(radians, c_float) ! else refused by angle_core
   endif
   if (angle_core(label, radians, v, d, format, stat)) then
      radians = real(v, real64)
      changed = .true.
   endif
   endfunction ig_slider_angle_r64

   ! ---- numbers -------------------------------------------------------------------------------------------------------
   recursive function ig_input_i32(label, value, step, format, enter_returns, read_only, stat) result(changed)
   !< A field for an `int32` value (`InputScalar`); true when the user changed the value: see `ig_input`.
   character(len=*), intent(in)            :: label         !< Label (also the id; '##id' hides it).
   integer(int32),   intent(inout)         :: value         !< Value.
   integer(int32),   intent(in), optional  :: step          !< Step of the - and + buttons, > 0 (default: no buttons).
   character(len=*), intent(in), optional  :: format        !< printf format of an integer (checked; default '%d').
   logical,          intent(in), optional  :: enter_returns !< True only on the frame enter is pressed.
   logical,          intent(in), optional  :: read_only     !< Shown, not editable (default false).
   integer(int32),   intent(out), optional :: stat          !< Status.
   logical                                 :: changed       !< Changed this frame.
   integer(c_int),   target                :: v(1)          !< C copy of `value`.
   integer(c_int),   target                :: s(2)          !< Step and fast step (10 steps).
   logical                                 :: stepped       !< Buttons shown.

   changed = .false.
   if (figure_draw_refused('ig_input', stat)) return ! a task does not draw
   v(1) = value
   stepped = .false.
   s = 0
   if (present(step)) stepped = step > 0
   if (stepped) s = [int(step, c_int), int(min(step, FAST_I32) * 10, c_int)]
   if (stepped) then
      changed = input_core(label, K_I32, c_loc(v), size(v, kind=int32), .true., c_loc(s(1)), c_loc(s(2)), format, &
                           enter_returns, read_only, stat)
   else
      changed = input_core(label, K_I32, c_loc(v), size(v, kind=int32), .true., c_null_ptr, c_null_ptr, format, &
                           enter_returns, read_only, stat)
   endif
   value = v(1)
   endfunction ig_input_i32

   recursive function ig_drag_i32(label, value, speed, vmin, vmax, format, scale, clamp, stat) result(changed)
   !< A drag box for an `int32` value (`DragScalar`); true when the user changed the value: see `ig_drag`.
   character(len=*), intent(in)            :: label   !< Label (also the id; '##id' hides it).
   integer(int32),   intent(inout)         :: value   !< Value.
   real(real64),     intent(in), optional  :: speed   !< Change per pixel dragged [value/pixel], > 0 (default 1).
   integer(int32),   intent(in), optional  :: vmin    !< Lowest value a drag reaches (default: none).
   integer(int32),   intent(in), optional  :: vmax    !< Highest value a drag reaches (default: none).
   character(len=*), intent(in), optional  :: format  !< printf format of an integer (checked).
   character(len=*), intent(in), optional  :: scale   !< 'linear' (default) or 'log' (with vmin and vmax).
   logical,          intent(in), optional  :: clamp   !< Typed values clamped too (default false).
   integer(int32),   intent(out), optional :: stat    !< Status.
   logical                                 :: changed !< Changed this frame.
   integer(c_int),   target                :: v(1)    !< C copy of `value`.
   integer(c_int),   target                :: lo      !< Lower bound.
   integer(c_int),   target                :: hi      !< Upper bound.

   changed = .false.
   if (figure_draw_refused('ig_drag', stat)) return ! a task does not draw
   lo = -HALF_I32
   hi = HALF_I32
   if (present(vmin)) lo = vmin
   if (present(vmax)) hi = vmax
   if (.not. int_range('ig_drag', int(lo, int64), int(hi, int64), present(vmin), present(vmax), int(HALF_I32, int64), &
       .true., stat)) return
   v(1) = value
   changed = drag_core(label, K_I32, c_loc(v), size(v, kind=int32), .true., speed, c_loc(lo), c_loc(hi), &
                       present(vmin) .and. present(vmax), format, scale, clamp, stat)
   value = v(1)
   endfunction ig_drag_i32

   recursive function ig_slider_i32(label, value, vmin, vmax, format, scale, clamp, stat) result(changed)
   !< A slider for an `int32` value (`SliderScalar`); true when the user changed the value: see `ig_slider`.
   character(len=*), intent(in)            :: label   !< Label (also the id; '##id' hides it).
   integer(int32),   intent(inout)         :: value   !< Value.
   integer(int32),   intent(in)            :: vmin    !< Value at the left end.
   integer(int32),   intent(in)            :: vmax    !< Value at the right end.
   character(len=*), intent(in), optional  :: format  !< printf format of an integer (checked).
   character(len=*), intent(in), optional  :: scale   !< 'linear' (default) or 'log'.
   logical,          intent(in), optional  :: clamp   !< Typed values clamped too (default false).
   integer(int32),   intent(out), optional :: stat    !< Status.
   logical                                 :: changed !< Changed this frame.
   integer(c_int),   target                :: v(1)    !< C copy of `value`.
   integer(c_int),   target                :: lo      !< C copy of `vmin`.
   integer(c_int),   target                :: hi      !< C copy of `vmax`.

   changed = .false.
   if (figure_draw_refused('ig_slider', stat)) return ! a task does not draw
   if (.not. int_range('ig_slider', int(vmin, int64), int(vmax, int64), .true., .true., int(HALF_I32, int64), .false., &
       stat)) return
   lo = vmin
   hi = vmax
   v(1) = value
   changed = slider_core(label, K_I32, c_loc(v), size(v, kind=int32), .true., c_loc(lo), c_loc(hi), format, scale, &
                         clamp, stat)
   value = v(1)
   endfunction ig_slider_i32

   recursive function ig_input_i32_v(label, value, step, format, enter_returns, read_only, stat) result(changed)
   !< A field for a vector of `int32` values, one field per component (`InputScalarN`); true when the user changed the
   !< value: see `ig_input`.
   character(len=*), intent(in)            :: label         !< Label (also the id; '##id' hides it).
   integer(int32),   intent(inout)         :: value(:)      !< Value.
   integer(int32),   intent(in), optional  :: step          !< Step of the - and + buttons, > 0 (default: no buttons).
   character(len=*), intent(in), optional  :: format        !< printf format of an integer (checked; default '%d').
   logical,          intent(in), optional  :: enter_returns !< True only on the frame enter is pressed.
   logical,          intent(in), optional  :: read_only     !< Shown, not editable (default false).
   integer(int32),   intent(out), optional :: stat          !< Status.
   logical                                 :: changed       !< Changed this frame.
   integer(c_int),   allocatable, target   :: v(:)          !< C copy of `value`.
   integer(c_int),   target                :: s(2)          !< Step and fast step (10 steps).
   logical                                 :: stepped       !< Buttons shown.

   changed = .false.
   if (figure_draw_refused('ig_input', stat)) return ! a task does not draw
   if (no_components('ig_input', size(value, kind=int32), stat)) return
   v = value
   stepped = .false.
   s = 0
   if (present(step)) stepped = step > 0
   if (stepped) s = [int(step, c_int), int(min(step, FAST_I32) * 10, c_int)]
   if (stepped) then
      changed = input_core(label, K_I32, c_loc(v), size(v, kind=int32), .false., c_loc(s(1)), c_loc(s(2)), format, &
                           enter_returns, read_only, stat)
   else
      changed = input_core(label, K_I32, c_loc(v), size(v, kind=int32), .false., c_null_ptr, c_null_ptr, format, &
                           enter_returns, read_only, stat)
   endif
   value = v
   endfunction ig_input_i32_v

   recursive function ig_drag_i32_v(label, value, speed, vmin, vmax, format, scale, clamp, stat) result(changed)
   !< A drag box for a vector of `int32` values, one field per component (`DragScalarN`); true when the user changed the
   !< value: see `ig_drag`.
   character(len=*), intent(in)            :: label    !< Label (also the id; '##id' hides it).
   integer(int32),   intent(inout)         :: value(:) !< Value.
   real(real64),     intent(in), optional  :: speed    !< Change per pixel dragged [value/pixel], > 0 (default 1).
   integer(int32),   intent(in), optional  :: vmin     !< Lowest value a drag reaches (default: none).
   integer(int32),   intent(in), optional  :: vmax     !< Highest value a drag reaches (default: none).
   character(len=*), intent(in), optional  :: format   !< printf format of an integer (checked).
   character(len=*), intent(in), optional  :: scale    !< 'linear' (default) or 'log' (with vmin and vmax).
   logical,          intent(in), optional  :: clamp    !< Typed values clamped too (default false).
   integer(int32),   intent(out), optional :: stat     !< Status.
   logical                                 :: changed  !< Changed this frame.
   integer(c_int),   allocatable, target   :: v(:)     !< C copy of `value`.
   integer(c_int),   target                :: lo       !< Lower bound.
   integer(c_int),   target                :: hi       !< Upper bound.

   changed = .false.
   if (figure_draw_refused('ig_drag', stat)) return ! a task does not draw
      if (no_components('ig_drag', size(value, kind=int32), stat)) return
   lo = -HALF_I32
   hi = HALF_I32
   if (present(vmin)) lo = vmin
   if (present(vmax)) hi = vmax
   if (.not. int_range('ig_drag', int(lo, int64), int(hi, int64), present(vmin), present(vmax), int(HALF_I32, int64), &
       .true., stat)) return
   v = value
   changed = drag_core(label, K_I32, c_loc(v), size(v, kind=int32), .false., speed, c_loc(lo), c_loc(hi), &
                       present(vmin) .and. present(vmax), format, scale, clamp, stat)
   value = v
   endfunction ig_drag_i32_v

   recursive function ig_slider_i32_v(label, value, vmin, vmax, format, scale, clamp, stat) result(changed)
   !< A slider for a vector of `int32` values, one field per component (`SliderScalarN`); true when the user changed the
   !< value: see `ig_slider`.
   character(len=*), intent(in)            :: label    !< Label (also the id; '##id' hides it).
   integer(int32),   intent(inout)         :: value(:) !< Value.
   integer(int32),   intent(in)            :: vmin     !< Value at the left end.
   integer(int32),   intent(in)            :: vmax     !< Value at the right end.
   character(len=*), intent(in), optional  :: format   !< printf format of an integer (checked).
   character(len=*), intent(in), optional  :: scale    !< 'linear' (default) or 'log'.
   logical,          intent(in), optional  :: clamp    !< Typed values clamped too (default false).
   integer(int32),   intent(out), optional :: stat     !< Status.
   logical                                 :: changed  !< Changed this frame.
   integer(c_int),   allocatable, target   :: v(:)     !< C copy of `value`.
   integer(c_int),   target                :: lo       !< C copy of `vmin`.
   integer(c_int),   target                :: hi       !< C copy of `vmax`.

   changed = .false.
   if (figure_draw_refused('ig_slider', stat)) return ! a task does not draw
      if (no_components('ig_slider', size(value, kind=int32), stat)) return
   if (.not. int_range('ig_slider', int(vmin, int64), int(vmax, int64), .true., .true., int(HALF_I32, int64), .false., &
       stat)) return
   lo = vmin
   hi = vmax
   v = value
   changed = slider_core(label, K_I32, c_loc(v), size(v, kind=int32), .false., c_loc(lo), c_loc(hi), format, scale, &
                         clamp, stat)
   value = v
   endfunction ig_slider_i32_v

   recursive function ig_drag_range_i32(label, lo, hi, speed, vmin, vmax, format, stat) result(changed)
   !< Two drag boxes for the ends of a range of `int32` values; true when the user changed either: see `ig_drag_range`.
   character(len=*), intent(in)            :: label   !< Label (also the id; '##id' hides it).
   integer(int32),   intent(inout)         :: lo      !< Lower end of the range.
   integer(int32),   intent(inout)         :: hi      !< Upper end of the range.
   real(real64),     intent(in), optional  :: speed   !< Change per pixel dragged [value/pixel], > 0 (default 1).
   integer(int32),   intent(in), optional  :: vmin    !< Lowest value of `lo` (default: none).
   integer(int32),   intent(in), optional  :: vmax    !< Highest value of `hi` (default: none).
   character(len=*), intent(in), optional  :: format  !< printf format of an integer (checked).
   integer(int32),   intent(out), optional :: stat    !< Status.
   logical                                 :: changed !< Changed this frame.
   integer(c_int),   target                :: v(2)    !< C copies of `lo` and `hi`.
   integer(c_int),   target                :: b(2)    !< Outer bounds.

   changed = .false.
   if (figure_draw_refused('ig_drag_range', stat)) return ! a task does not draw
   b = [-HALF_I32, HALF_I32]
   if (present(vmin)) b(1) = vmin
   if (present(vmax)) b(2) = vmax
   if (.not. int_range('ig_drag_range', int(b(1), int64), int(b(2), int64), present(vmin), present(vmax), int(HALF_I32, &
       int64), .true., stat)) return
   if (.not. int_range('ig_drag_range', int(lo, int64), int(hi, int64), .true., .true., int(huge(lo), int64), .true., &
       stat, 'lo', 'hi')) return
   v = [int(lo, c_int), int(hi, c_int)]
   changed = range_core(label, K_I32, c_loc(v(1)), c_loc(v(2)), speed, c_loc(b(1)), c_loc(b(2)), format, stat)
   lo = v(1)
   hi = v(2)
   endfunction ig_drag_range_i32

   recursive function ig_input_i64(label, value, step, format, enter_returns, read_only, stat) result(changed)
   !< A field for an `int64` value (`InputScalar`); true when the user changed the value: see `ig_input`.
   character(len=*),     intent(in)            :: label         !< Label (also the id; '##id' hides it).
   integer(int64),       intent(inout)         :: value         !< Value.
   integer(int64),       intent(in), optional  :: step          !< Step of the - and + buttons, > 0 (default: no buttons).
   character(len=*),     intent(in), optional  :: format        !< printf format of an integer (checked; default '%d').
   logical,              intent(in), optional  :: enter_returns !< True only on the frame enter is pressed.
   logical,              intent(in), optional  :: read_only     !< Shown, not editable (default false).
   integer(int32),       intent(out), optional :: stat          !< Status.
   logical                                     :: changed       !< Changed this frame.
   integer(c_long_long), target                :: v(1)          !< C copy of `value`.
   integer(c_long_long), target                :: s(2)          !< Step and fast step (10 steps).
   logical                                     :: stepped       !< Buttons shown.

   changed = .false.
   if (figure_draw_refused('ig_input', stat)) return ! a task does not draw
   v(1) = value
   stepped = .false.
   s = 0
   if (present(step)) stepped = step > 0
   if (stepped) s = [int(step, c_long_long), int(min(step, FAST_I64) * 10, c_long_long)]
   if (stepped) then
      changed = input_core(label, K_I64, c_loc(v), size(v, kind=int32), .true., c_loc(s(1)), c_loc(s(2)), format, &
                           enter_returns, read_only, stat)
   else
      changed = input_core(label, K_I64, c_loc(v), size(v, kind=int32), .true., c_null_ptr, c_null_ptr, format, &
                           enter_returns, read_only, stat)
   endif
   value = v(1)
   endfunction ig_input_i64

   recursive function ig_drag_i64(label, value, speed, vmin, vmax, format, scale, clamp, stat) result(changed)
   !< A drag box for an `int64` value (`DragScalar`); true when the user changed the value: see `ig_drag`.
   character(len=*),     intent(in)            :: label   !< Label (also the id; '##id' hides it).
   integer(int64),       intent(inout)         :: value   !< Value.
   real(real64),         intent(in), optional  :: speed   !< Change per pixel dragged [value/pixel], > 0 (default 1).
   integer(int64),       intent(in), optional  :: vmin    !< Lowest value a drag reaches (default: none).
   integer(int64),       intent(in), optional  :: vmax    !< Highest value a drag reaches (default: none).
   character(len=*),     intent(in), optional  :: format  !< printf format of an integer (checked).
   character(len=*),     intent(in), optional  :: scale   !< 'linear' (default) or 'log' (with vmin and vmax).
   logical,              intent(in), optional  :: clamp   !< Typed values clamped too (default false).
   integer(int32),       intent(out), optional :: stat    !< Status.
   logical                                     :: changed !< Changed this frame.
   integer(c_long_long), target                :: v(1)    !< C copy of `value`.
   integer(c_long_long), target                :: lo      !< Lower bound.
   integer(c_long_long), target                :: hi      !< Upper bound.

   changed = .false.
   if (figure_draw_refused('ig_drag', stat)) return ! a task does not draw
   lo = -HALF_I64
   hi = HALF_I64
   if (present(vmin)) lo = vmin
   if (present(vmax)) hi = vmax
   if (.not. int_range('ig_drag', int(lo, int64), int(hi, int64), present(vmin), present(vmax), int(HALF_I64, int64), &
       .true., stat)) return
   v(1) = value
   changed = drag_core(label, K_I64, c_loc(v), size(v, kind=int32), .true., speed, c_loc(lo), c_loc(hi), &
                       present(vmin) .and. present(vmax), format, scale, clamp, stat)
   value = v(1)
   endfunction ig_drag_i64

   recursive function ig_slider_i64(label, value, vmin, vmax, format, scale, clamp, stat) result(changed)
   !< A slider for an `int64` value (`SliderScalar`); true when the user changed the value: see `ig_slider`.
   character(len=*),     intent(in)            :: label   !< Label (also the id; '##id' hides it).
   integer(int64),       intent(inout)         :: value   !< Value.
   integer(int64),       intent(in)            :: vmin    !< Value at the left end.
   integer(int64),       intent(in)            :: vmax    !< Value at the right end.
   character(len=*),     intent(in), optional  :: format  !< printf format of an integer (checked).
   character(len=*),     intent(in), optional  :: scale   !< 'linear' (default) or 'log'.
   logical,              intent(in), optional  :: clamp   !< Typed values clamped too (default false).
   integer(int32),       intent(out), optional :: stat    !< Status.
   logical                                     :: changed !< Changed this frame.
   integer(c_long_long), target                :: v(1)    !< C copy of `value`.
   integer(c_long_long), target                :: lo      !< C copy of `vmin`.
   integer(c_long_long), target                :: hi      !< C copy of `vmax`.

   changed = .false.
   if (figure_draw_refused('ig_slider', stat)) return ! a task does not draw
   if (.not. int_range('ig_slider', int(vmin, int64), int(vmax, int64), .true., .true., int(HALF_I64, int64), .false., &
       stat)) return
   lo = vmin
   hi = vmax
   v(1) = value
   changed = slider_core(label, K_I64, c_loc(v), size(v, kind=int32), .true., c_loc(lo), c_loc(hi), format, scale, &
                         clamp, stat)
   value = v(1)
   endfunction ig_slider_i64

   recursive function ig_input_i64_v(label, value, step, format, enter_returns, read_only, stat) result(changed)
   !< A field for a vector of `int64` values, one field per component (`InputScalarN`); true when the user changed the
   !< value: see `ig_input`.
   character(len=*),     intent(in)            :: label         !< Label (also the id; '##id' hides it).
   integer(int64),       intent(inout)         :: value(:)      !< Value.
   integer(int64),       intent(in), optional  :: step          !< Step of the - and + buttons, > 0 (default: no buttons).
   character(len=*),     intent(in), optional  :: format        !< printf format of an integer (checked; default '%d').
   logical,              intent(in), optional  :: enter_returns !< True only on the frame enter is pressed.
   logical,              intent(in), optional  :: read_only     !< Shown, not editable (default false).
   integer(int32),       intent(out), optional :: stat          !< Status.
   logical                                     :: changed       !< Changed this frame.
   integer(c_long_long), allocatable, target   :: v(:)          !< C copy of `value`.
   integer(c_long_long), target                :: s(2)          !< Step and fast step (10 steps).
   logical                                     :: stepped       !< Buttons shown.

   changed = .false.
   if (figure_draw_refused('ig_input', stat)) return ! a task does not draw
   if (no_components('ig_input', size(value, kind=int32), stat)) return
   v = value
   stepped = .false.
   s = 0
   if (present(step)) stepped = step > 0
   if (stepped) s = [int(step, c_long_long), int(min(step, FAST_I64) * 10, c_long_long)]
   if (stepped) then
      changed = input_core(label, K_I64, c_loc(v), size(v, kind=int32), .false., c_loc(s(1)), c_loc(s(2)), format, &
                           enter_returns, read_only, stat)
   else
      changed = input_core(label, K_I64, c_loc(v), size(v, kind=int32), .false., c_null_ptr, c_null_ptr, format, &
                           enter_returns, read_only, stat)
   endif
   value = v
   endfunction ig_input_i64_v

   recursive function ig_drag_i64_v(label, value, speed, vmin, vmax, format, scale, clamp, stat) result(changed)
   !< A drag box for a vector of `int64` values, one field per component (`DragScalarN`); true when the user changed the
   !< value: see `ig_drag`.
   character(len=*),     intent(in)            :: label    !< Label (also the id; '##id' hides it).
   integer(int64),       intent(inout)         :: value(:) !< Value.
   real(real64),         intent(in), optional  :: speed    !< Change per pixel dragged [value/pixel], > 0 (default 1).
   integer(int64),       intent(in), optional  :: vmin     !< Lowest value a drag reaches (default: none).
   integer(int64),       intent(in), optional  :: vmax     !< Highest value a drag reaches (default: none).
   character(len=*),     intent(in), optional  :: format   !< printf format of an integer (checked).
   character(len=*),     intent(in), optional  :: scale    !< 'linear' (default) or 'log' (with vmin and vmax).
   logical,              intent(in), optional  :: clamp    !< Typed values clamped too (default false).
   integer(int32),       intent(out), optional :: stat     !< Status.
   logical                                     :: changed  !< Changed this frame.
   integer(c_long_long), allocatable, target   :: v(:)     !< C copy of `value`.
   integer(c_long_long), target                :: lo       !< Lower bound.
   integer(c_long_long), target                :: hi       !< Upper bound.

   changed = .false.
   if (figure_draw_refused('ig_drag', stat)) return ! a task does not draw
      if (no_components('ig_drag', size(value, kind=int32), stat)) return
   lo = -HALF_I64
   hi = HALF_I64
   if (present(vmin)) lo = vmin
   if (present(vmax)) hi = vmax
   if (.not. int_range('ig_drag', int(lo, int64), int(hi, int64), present(vmin), present(vmax), int(HALF_I64, int64), &
       .true., stat)) return
   v = value
   changed = drag_core(label, K_I64, c_loc(v), size(v, kind=int32), .false., speed, c_loc(lo), c_loc(hi), &
                       present(vmin) .and. present(vmax), format, scale, clamp, stat)
   value = v
   endfunction ig_drag_i64_v

   recursive function ig_slider_i64_v(label, value, vmin, vmax, format, scale, clamp, stat) result(changed)
   !< A slider for a vector of `int64` values, one field per component (`SliderScalarN`); true when the user changed the
   !< value: see `ig_slider`.
   character(len=*),     intent(in)            :: label    !< Label (also the id; '##id' hides it).
   integer(int64),       intent(inout)         :: value(:) !< Value.
   integer(int64),       intent(in)            :: vmin     !< Value at the left end.
   integer(int64),       intent(in)            :: vmax     !< Value at the right end.
   character(len=*),     intent(in), optional  :: format   !< printf format of an integer (checked).
   character(len=*),     intent(in), optional  :: scale    !< 'linear' (default) or 'log'.
   logical,              intent(in), optional  :: clamp    !< Typed values clamped too (default false).
   integer(int32),       intent(out), optional :: stat     !< Status.
   logical                                     :: changed  !< Changed this frame.
   integer(c_long_long), allocatable, target   :: v(:)     !< C copy of `value`.
   integer(c_long_long), target                :: lo       !< C copy of `vmin`.
   integer(c_long_long), target                :: hi       !< C copy of `vmax`.

   changed = .false.
   if (figure_draw_refused('ig_slider', stat)) return ! a task does not draw
      if (no_components('ig_slider', size(value, kind=int32), stat)) return
   if (.not. int_range('ig_slider', int(vmin, int64), int(vmax, int64), .true., .true., int(HALF_I64, int64), .false., &
       stat)) return
   lo = vmin
   hi = vmax
   v = value
   changed = slider_core(label, K_I64, c_loc(v), size(v, kind=int32), .false., c_loc(lo), c_loc(hi), format, scale, &
                         clamp, stat)
   value = v
   endfunction ig_slider_i64_v

   recursive function ig_drag_range_i64(label, lo, hi, speed, vmin, vmax, format, stat) result(changed)
   !< Two drag boxes for the ends of a range of `int64` values; true when the user changed either: see `ig_drag_range`.
   character(len=*),     intent(in)            :: label   !< Label (also the id; '##id' hides it).
   integer(int64),       intent(inout)         :: lo      !< Lower end of the range.
   integer(int64),       intent(inout)         :: hi      !< Upper end of the range.
   real(real64),         intent(in), optional  :: speed   !< Change per pixel dragged [value/pixel], > 0 (default 1).
   integer(int64),       intent(in), optional  :: vmin    !< Lowest value of `lo` (default: none).
   integer(int64),       intent(in), optional  :: vmax    !< Highest value of `hi` (default: none).
   character(len=*),     intent(in), optional  :: format  !< printf format of an integer (checked).
   integer(int32),       intent(out), optional :: stat    !< Status.
   logical                                     :: changed !< Changed this frame.
   integer(c_long_long), target                :: v(2)    !< C copies of `lo` and `hi`.
   integer(c_long_long), target                :: b(2)    !< Outer bounds.

   changed = .false.
   if (figure_draw_refused('ig_drag_range', stat)) return ! a task does not draw
   b = [-HALF_I64, HALF_I64]
   if (present(vmin)) b(1) = vmin
   if (present(vmax)) b(2) = vmax
   if (.not. int_range('ig_drag_range', int(b(1), int64), int(b(2), int64), present(vmin), present(vmax), int(HALF_I64, &
       int64), .true., stat)) return
   if (.not. int_range('ig_drag_range', int(lo, int64), int(hi, int64), .true., .true., int(huge(lo), int64), .true., &
       stat, 'lo', 'hi')) return
   v = [int(lo, c_long_long), int(hi, c_long_long)]
   changed = range_core(label, K_I64, c_loc(v(1)), c_loc(v(2)), speed, c_loc(b(1)), c_loc(b(2)), format, stat)
   lo = v(1)
   hi = v(2)
   endfunction ig_drag_range_i64

   recursive function ig_input_r32(label, value, step, format, enter_returns, read_only, stat) result(changed)
   !< A field for a `real32` value (`InputScalar`); true when the user changed the value: see `ig_input`.
   character(len=*), intent(in)            :: label         !< Label (also the id; '##id' hides it).
   real(real32),     intent(inout)         :: value         !< Value.
   real(real32),     intent(in), optional  :: step          !< Step of the - and + buttons, > 0 (default: no buttons).
   character(len=*), intent(in), optional  :: format        !< printf format of a real (checked; default '%.6g').
   logical,          intent(in), optional  :: enter_returns !< True only on the frame enter is pressed.
   logical,          intent(in), optional  :: read_only     !< Shown, not editable (default false).
   integer(int32),   intent(out), optional :: stat          !< Status.
   logical                                 :: changed       !< Changed this frame.
   real(c_float),    target                :: v(1)          !< C copy of `value`.
   real(c_float),    target                :: s(2)          !< Step and fast step (10 steps).
   logical                                 :: stepped       !< Buttons shown.

   changed = .false.
   if (figure_draw_refused('ig_input', stat)) return ! a task does not draw
   v(1) = value
   stepped = .false.
   s = 0.0
   if (present(step)) then
      if (.not. ieee_is_nan(step)) stepped = step > 0.0
   endif
   if (stepped) s = [real(step, c_float), real(min(step, huge(step) / 10.0) * 10.0, c_float)]
   if (stepped) then
      changed = input_core(label, K_R32, c_loc(v), size(v, kind=int32), .true., c_loc(s(1)), c_loc(s(2)), format, &
                           enter_returns, read_only, stat)
   else
      changed = input_core(label, K_R32, c_loc(v), size(v, kind=int32), .true., c_null_ptr, c_null_ptr, format, &
                           enter_returns, read_only, stat)
   endif
   value = v(1)
   endfunction ig_input_r32

   recursive function ig_drag_r32(label, value, speed, vmin, vmax, format, scale, clamp, stat) result(changed)
   !< A drag box for a `real32` value (`DragScalar`); true when the user changed the value: see `ig_drag`.
   character(len=*), intent(in)            :: label   !< Label (also the id; '##id' hides it).
   real(real32),     intent(inout)         :: value   !< Value.
   real(real64),     intent(in), optional  :: speed   !< Change per pixel dragged [value/pixel], > 0 (default 1).
   real(real32),     intent(in), optional  :: vmin    !< Lowest value a drag reaches (default: none).
   real(real32),     intent(in), optional  :: vmax    !< Highest value a drag reaches (default: none).
   character(len=*), intent(in), optional  :: format  !< printf format of a real (checked).
   character(len=*), intent(in), optional  :: scale   !< 'linear' (default) or 'log' (with vmin and vmax).
   logical,          intent(in), optional  :: clamp   !< Typed values clamped too (default false).
   integer(int32),   intent(out), optional :: stat    !< Status.
   logical                                 :: changed !< Changed this frame.
   real(c_float),    target                :: v(1)    !< C copy of `value`.
   real(c_float),    target                :: lo      !< Lower bound.
   real(c_float),    target                :: hi      !< Upper bound.

   changed = .false.
   if (figure_draw_refused('ig_drag', stat)) return ! a task does not draw
   lo = -HALF_R32
   hi = HALF_R32
   if (present(vmin)) lo = vmin
   if (present(vmax)) hi = vmax
   if (.not. real_range('ig_drag', real(lo, real64), real(hi, real64), present(vmin), present(vmax), real(HALF_R32, &
       real64), .true., stat)) return
   v(1) = value
   changed = drag_core(label, K_R32, c_loc(v), size(v, kind=int32), .true., speed, c_loc(lo), c_loc(hi), &
                       present(vmin) .and. present(vmax), format, scale, clamp, stat)
   value = v(1)
   endfunction ig_drag_r32

   recursive function ig_slider_r32(label, value, vmin, vmax, format, scale, clamp, stat) result(changed)
   !< A slider for a `real32` value (`SliderScalar`); true when the user changed the value: see `ig_slider`.
   character(len=*), intent(in)            :: label   !< Label (also the id; '##id' hides it).
   real(real32),     intent(inout)         :: value   !< Value.
   real(real32),     intent(in)            :: vmin    !< Value at the left end.
   real(real32),     intent(in)            :: vmax    !< Value at the right end.
   character(len=*), intent(in), optional  :: format  !< printf format of a real (checked).
   character(len=*), intent(in), optional  :: scale   !< 'linear' (default) or 'log'.
   logical,          intent(in), optional  :: clamp   !< Typed values clamped too (default false).
   integer(int32),   intent(out), optional :: stat    !< Status.
   logical                                 :: changed !< Changed this frame.
   real(c_float),    target                :: v(1)    !< C copy of `value`.
   real(c_float),    target                :: lo      !< C copy of `vmin`.
   real(c_float),    target                :: hi      !< C copy of `vmax`.

   changed = .false.
   if (figure_draw_refused('ig_slider', stat)) return ! a task does not draw
   if (.not. real_range('ig_slider', real(vmin, real64), real(vmax, real64), .true., .true., real(HALF_R32, real64), &
       .false., stat)) return
   lo = vmin
   hi = vmax
   v(1) = value
   changed = slider_core(label, K_R32, c_loc(v), size(v, kind=int32), .true., c_loc(lo), c_loc(hi), format, scale, &
                         clamp, stat)
   value = v(1)
   endfunction ig_slider_r32

   recursive function ig_input_r32_v(label, value, step, format, enter_returns, read_only, stat) result(changed)
   !< A field for a vector of `real32` values, one field per component (`InputScalarN`); true when the user changed the
   !< value: see `ig_input`.
   character(len=*), intent(in)            :: label         !< Label (also the id; '##id' hides it).
   real(real32),     intent(inout)         :: value(:)      !< Value.
   real(real32),     intent(in), optional  :: step          !< Step of the - and + buttons, > 0 (default: no buttons).
   character(len=*), intent(in), optional  :: format        !< printf format of a real (checked; default '%.6g').
   logical,          intent(in), optional  :: enter_returns !< True only on the frame enter is pressed.
   logical,          intent(in), optional  :: read_only     !< Shown, not editable (default false).
   integer(int32),   intent(out), optional :: stat          !< Status.
   logical                                 :: changed       !< Changed this frame.
   real(c_float),    allocatable, target   :: v(:)          !< C copy of `value`.
   real(c_float),    target                :: s(2)          !< Step and fast step (10 steps).
   logical                                 :: stepped       !< Buttons shown.

   changed = .false.
   if (figure_draw_refused('ig_input', stat)) return ! a task does not draw
   if (no_components('ig_input', size(value, kind=int32), stat)) return
   v = value
   stepped = .false.
   s = 0.0
   if (present(step)) then
      if (.not. ieee_is_nan(step)) stepped = step > 0.0
   endif
   if (stepped) s = [real(step, c_float), real(min(step, huge(step) / 10.0) * 10.0, c_float)]
   if (stepped) then
      changed = input_core(label, K_R32, c_loc(v), size(v, kind=int32), .false., c_loc(s(1)), c_loc(s(2)), format, &
                           enter_returns, read_only, stat)
   else
      changed = input_core(label, K_R32, c_loc(v), size(v, kind=int32), .false., c_null_ptr, c_null_ptr, format, &
                           enter_returns, read_only, stat)
   endif
   value = v
   endfunction ig_input_r32_v

   recursive function ig_drag_r32_v(label, value, speed, vmin, vmax, format, scale, clamp, stat) result(changed)
   !< A drag box for a vector of `real32` values, one field per component (`DragScalarN`); true when the user changed
   !< the value: see `ig_drag`.
   character(len=*), intent(in)            :: label    !< Label (also the id; '##id' hides it).
   real(real32),     intent(inout)         :: value(:) !< Value.
   real(real64),     intent(in), optional  :: speed    !< Change per pixel dragged [value/pixel], > 0 (default 1).
   real(real32),     intent(in), optional  :: vmin     !< Lowest value a drag reaches (default: none).
   real(real32),     intent(in), optional  :: vmax     !< Highest value a drag reaches (default: none).
   character(len=*), intent(in), optional  :: format   !< printf format of a real (checked).
   character(len=*), intent(in), optional  :: scale    !< 'linear' (default) or 'log' (with vmin and vmax).
   logical,          intent(in), optional  :: clamp    !< Typed values clamped too (default false).
   integer(int32),   intent(out), optional :: stat     !< Status.
   logical                                 :: changed  !< Changed this frame.
   real(c_float),    allocatable, target   :: v(:)     !< C copy of `value`.
   real(c_float),    target                :: lo       !< Lower bound.
   real(c_float),    target                :: hi       !< Upper bound.

   changed = .false.
   if (figure_draw_refused('ig_drag', stat)) return ! a task does not draw
      if (no_components('ig_drag', size(value, kind=int32), stat)) return
   lo = -HALF_R32
   hi = HALF_R32
   if (present(vmin)) lo = vmin
   if (present(vmax)) hi = vmax
   if (.not. real_range('ig_drag', real(lo, real64), real(hi, real64), present(vmin), present(vmax), real(HALF_R32, &
       real64), .true., stat)) return
   v = value
   changed = drag_core(label, K_R32, c_loc(v), size(v, kind=int32), .false., speed, c_loc(lo), c_loc(hi), &
                       present(vmin) .and. present(vmax), format, scale, clamp, stat)
   value = v
   endfunction ig_drag_r32_v

   recursive function ig_slider_r32_v(label, value, vmin, vmax, format, scale, clamp, stat) result(changed)
   !< A slider for a vector of `real32` values, one field per component (`SliderScalarN`); true when the user changed
   !< the value: see `ig_slider`.
   character(len=*), intent(in)            :: label    !< Label (also the id; '##id' hides it).
   real(real32),     intent(inout)         :: value(:) !< Value.
   real(real32),     intent(in)            :: vmin     !< Value at the left end.
   real(real32),     intent(in)            :: vmax     !< Value at the right end.
   character(len=*), intent(in), optional  :: format   !< printf format of a real (checked).
   character(len=*), intent(in), optional  :: scale    !< 'linear' (default) or 'log'.
   logical,          intent(in), optional  :: clamp    !< Typed values clamped too (default false).
   integer(int32),   intent(out), optional :: stat     !< Status.
   logical                                 :: changed  !< Changed this frame.
   real(c_float),    allocatable, target   :: v(:)     !< C copy of `value`.
   real(c_float),    target                :: lo       !< C copy of `vmin`.
   real(c_float),    target                :: hi       !< C copy of `vmax`.

   changed = .false.
   if (figure_draw_refused('ig_slider', stat)) return ! a task does not draw
      if (no_components('ig_slider', size(value, kind=int32), stat)) return
   if (.not. real_range('ig_slider', real(vmin, real64), real(vmax, real64), .true., .true., real(HALF_R32, real64), &
       .false., stat)) return
   lo = vmin
   hi = vmax
   v = value
   changed = slider_core(label, K_R32, c_loc(v), size(v, kind=int32), .false., c_loc(lo), c_loc(hi), format, scale, &
                         clamp, stat)
   value = v
   endfunction ig_slider_r32_v

   recursive function ig_drag_range_r32(label, lo, hi, speed, vmin, vmax, format, stat) result(changed)
   !< Two drag boxes for the ends of a range of `real32` values; true when the user changed either: see `ig_drag_range`.
   character(len=*), intent(in)            :: label   !< Label (also the id; '##id' hides it).
   real(real32),     intent(inout)         :: lo      !< Lower end of the range.
   real(real32),     intent(inout)         :: hi      !< Upper end of the range.
   real(real64),     intent(in), optional  :: speed   !< Change per pixel dragged [value/pixel], > 0 (default 1).
   real(real32),     intent(in), optional  :: vmin    !< Lowest value of `lo` (default: none).
   real(real32),     intent(in), optional  :: vmax    !< Highest value of `hi` (default: none).
   character(len=*), intent(in), optional  :: format  !< printf format of a real (checked).
   integer(int32),   intent(out), optional :: stat    !< Status.
   logical                                 :: changed !< Changed this frame.
   real(c_float),    target                :: v(2)    !< C copies of `lo` and `hi`.
   real(c_float),    target                :: b(2)    !< Outer bounds.

   changed = .false.
   if (figure_draw_refused('ig_drag_range', stat)) return ! a task does not draw
   b = [-HALF_R32, HALF_R32]
   if (present(vmin)) b(1) = vmin
   if (present(vmax)) b(2) = vmax
   if (.not. real_range('ig_drag_range', real(b(1), real64), real(b(2), real64), present(vmin), present(vmax), &
       real(HALF_R32, real64), .true., stat)) return
   if (.not. real_range('ig_drag_range', real(lo, real64), real(hi, real64), .true., .true., real(huge(lo), real64), &
       .true., stat, 'lo', 'hi')) return
   v = [real(lo, c_float), real(hi, c_float)]
   changed = range_core(label, K_R32, c_loc(v(1)), c_loc(v(2)), speed, c_loc(b(1)), c_loc(b(2)), format, stat)
   lo = v(1)
   hi = v(2)
   endfunction ig_drag_range_r32

   recursive function ig_input_r64(label, value, step, format, enter_returns, read_only, stat) result(changed)
   !< A field for a `real64` value (`InputScalar`); true when the user changed the value: see `ig_input`.
   character(len=*), intent(in)            :: label         !< Label (also the id; '##id' hides it).
   real(real64),     intent(inout)         :: value         !< Value.
   real(real64),     intent(in), optional  :: step          !< Step of the - and + buttons, > 0 (default: no buttons).
   character(len=*), intent(in), optional  :: format        !< printf format of a real (checked; default '%.6g').
   logical,          intent(in), optional  :: enter_returns !< True only on the frame enter is pressed.
   logical,          intent(in), optional  :: read_only     !< Shown, not editable (default false).
   integer(int32),   intent(out), optional :: stat          !< Status.
   logical                                 :: changed       !< Changed this frame.
   real(c_double),   target                :: v(1)          !< C copy of `value`.
   real(c_double),   target                :: s(2)          !< Step and fast step (10 steps).
   logical                                 :: stepped       !< Buttons shown.

   changed = .false.
   if (figure_draw_refused('ig_input', stat)) return ! a task does not draw
   v(1) = value
   stepped = .false.
   s = 0.0
   if (present(step)) then
      if (.not. ieee_is_nan(step)) stepped = step > 0.0
   endif
   if (stepped) s = [real(step, c_double), real(min(step, huge(step) / 10.0) * 10.0, c_double)]
   if (stepped) then
      changed = input_core(label, K_R64, c_loc(v), size(v, kind=int32), .true., c_loc(s(1)), c_loc(s(2)), format, &
                           enter_returns, read_only, stat)
   else
      changed = input_core(label, K_R64, c_loc(v), size(v, kind=int32), .true., c_null_ptr, c_null_ptr, format, &
                           enter_returns, read_only, stat)
   endif
   value = v(1)
   endfunction ig_input_r64

   recursive function ig_drag_r64(label, value, speed, vmin, vmax, format, scale, clamp, stat) result(changed)
   !< A drag box for a `real64` value (`DragScalar`); true when the user changed the value: see `ig_drag`.
   character(len=*), intent(in)            :: label   !< Label (also the id; '##id' hides it).
   real(real64),     intent(inout)         :: value   !< Value.
   real(real64),     intent(in), optional  :: speed   !< Change per pixel dragged [value/pixel], > 0 (default 1).
   real(real64),     intent(in), optional  :: vmin    !< Lowest value a drag reaches (default: none).
   real(real64),     intent(in), optional  :: vmax    !< Highest value a drag reaches (default: none).
   character(len=*), intent(in), optional  :: format  !< printf format of a real (checked).
   character(len=*), intent(in), optional  :: scale   !< 'linear' (default) or 'log' (with vmin and vmax).
   logical,          intent(in), optional  :: clamp   !< Typed values clamped too (default false).
   integer(int32),   intent(out), optional :: stat    !< Status.
   logical                                 :: changed !< Changed this frame.
   real(c_double),   target                :: v(1)    !< C copy of `value`.
   real(c_double),   target                :: lo      !< Lower bound.
   real(c_double),   target                :: hi      !< Upper bound.

   changed = .false.
   if (figure_draw_refused('ig_drag', stat)) return ! a task does not draw
   lo = -HALF_R64
   hi = HALF_R64
   if (present(vmin)) lo = vmin
   if (present(vmax)) hi = vmax
   if (.not. real_range('ig_drag', real(lo, real64), real(hi, real64), present(vmin), present(vmax), real(HALF_R64, &
       real64), .true., stat)) return
   v(1) = value
   changed = drag_core(label, K_R64, c_loc(v), size(v, kind=int32), .true., speed, c_loc(lo), c_loc(hi), &
                       present(vmin) .and. present(vmax), format, scale, clamp, stat)
   value = v(1)
   endfunction ig_drag_r64

   recursive function ig_slider_r64(label, value, vmin, vmax, format, scale, clamp, stat) result(changed)
   !< A slider for a `real64` value (`SliderScalar`); true when the user changed the value: see `ig_slider`.
   character(len=*), intent(in)            :: label   !< Label (also the id; '##id' hides it).
   real(real64),     intent(inout)         :: value   !< Value.
   real(real64),     intent(in)            :: vmin    !< Value at the left end.
   real(real64),     intent(in)            :: vmax    !< Value at the right end.
   character(len=*), intent(in), optional  :: format  !< printf format of a real (checked).
   character(len=*), intent(in), optional  :: scale   !< 'linear' (default) or 'log'.
   logical,          intent(in), optional  :: clamp   !< Typed values clamped too (default false).
   integer(int32),   intent(out), optional :: stat    !< Status.
   logical                                 :: changed !< Changed this frame.
   real(c_double),   target                :: v(1)    !< C copy of `value`.
   real(c_double),   target                :: lo      !< C copy of `vmin`.
   real(c_double),   target                :: hi      !< C copy of `vmax`.

   changed = .false.
   if (figure_draw_refused('ig_slider', stat)) return ! a task does not draw
   if (.not. real_range('ig_slider', real(vmin, real64), real(vmax, real64), .true., .true., real(HALF_R64, real64), &
       .false., stat)) return
   lo = vmin
   hi = vmax
   v(1) = value
   changed = slider_core(label, K_R64, c_loc(v), size(v, kind=int32), .true., c_loc(lo), c_loc(hi), format, scale, &
                         clamp, stat)
   value = v(1)
   endfunction ig_slider_r64

   recursive function ig_input_r64_v(label, value, step, format, enter_returns, read_only, stat) result(changed)
   !< A field for a vector of `real64` values, one field per component (`InputScalarN`); true when the user changed the
   !< value: see `ig_input`.
   character(len=*), intent(in)            :: label         !< Label (also the id; '##id' hides it).
   real(real64),     intent(inout)         :: value(:)      !< Value.
   real(real64),     intent(in), optional  :: step          !< Step of the - and + buttons, > 0 (default: no buttons).
   character(len=*), intent(in), optional  :: format        !< printf format of a real (checked; default '%.6g').
   logical,          intent(in), optional  :: enter_returns !< True only on the frame enter is pressed.
   logical,          intent(in), optional  :: read_only     !< Shown, not editable (default false).
   integer(int32),   intent(out), optional :: stat          !< Status.
   logical                                 :: changed       !< Changed this frame.
   real(c_double),   allocatable, target   :: v(:)          !< C copy of `value`.
   real(c_double),   target                :: s(2)          !< Step and fast step (10 steps).
   logical                                 :: stepped       !< Buttons shown.

   changed = .false.
   if (figure_draw_refused('ig_input', stat)) return ! a task does not draw
   if (no_components('ig_input', size(value, kind=int32), stat)) return
   v = value
   stepped = .false.
   s = 0.0
   if (present(step)) then
      if (.not. ieee_is_nan(step)) stepped = step > 0.0
   endif
   if (stepped) s = [real(step, c_double), real(min(step, huge(step) / 10.0) * 10.0, c_double)]
   if (stepped) then
      changed = input_core(label, K_R64, c_loc(v), size(v, kind=int32), .false., c_loc(s(1)), c_loc(s(2)), format, &
                           enter_returns, read_only, stat)
   else
      changed = input_core(label, K_R64, c_loc(v), size(v, kind=int32), .false., c_null_ptr, c_null_ptr, format, &
                           enter_returns, read_only, stat)
   endif
   value = v
   endfunction ig_input_r64_v

   recursive function ig_drag_r64_v(label, value, speed, vmin, vmax, format, scale, clamp, stat) result(changed)
   !< A drag box for a vector of `real64` values, one field per component (`DragScalarN`); true when the user changed
   !< the value: see `ig_drag`.
   character(len=*), intent(in)            :: label    !< Label (also the id; '##id' hides it).
   real(real64),     intent(inout)         :: value(:) !< Value.
   real(real64),     intent(in), optional  :: speed    !< Change per pixel dragged [value/pixel], > 0 (default 1).
   real(real64),     intent(in), optional  :: vmin     !< Lowest value a drag reaches (default: none).
   real(real64),     intent(in), optional  :: vmax     !< Highest value a drag reaches (default: none).
   character(len=*), intent(in), optional  :: format   !< printf format of a real (checked).
   character(len=*), intent(in), optional  :: scale    !< 'linear' (default) or 'log' (with vmin and vmax).
   logical,          intent(in), optional  :: clamp    !< Typed values clamped too (default false).
   integer(int32),   intent(out), optional :: stat     !< Status.
   logical                                 :: changed  !< Changed this frame.
   real(c_double),   allocatable, target   :: v(:)     !< C copy of `value`.
   real(c_double),   target                :: lo       !< Lower bound.
   real(c_double),   target                :: hi       !< Upper bound.

   changed = .false.
   if (figure_draw_refused('ig_drag', stat)) return ! a task does not draw
      if (no_components('ig_drag', size(value, kind=int32), stat)) return
   lo = -HALF_R64
   hi = HALF_R64
   if (present(vmin)) lo = vmin
   if (present(vmax)) hi = vmax
   if (.not. real_range('ig_drag', real(lo, real64), real(hi, real64), present(vmin), present(vmax), real(HALF_R64, &
       real64), .true., stat)) return
   v = value
   changed = drag_core(label, K_R64, c_loc(v), size(v, kind=int32), .false., speed, c_loc(lo), c_loc(hi), &
                       present(vmin) .and. present(vmax), format, scale, clamp, stat)
   value = v
   endfunction ig_drag_r64_v

   recursive function ig_slider_r64_v(label, value, vmin, vmax, format, scale, clamp, stat) result(changed)
   !< A slider for a vector of `real64` values, one field per component (`SliderScalarN`); true when the user changed
   !< the value: see `ig_slider`.
   character(len=*), intent(in)            :: label    !< Label (also the id; '##id' hides it).
   real(real64),     intent(inout)         :: value(:) !< Value.
   real(real64),     intent(in)            :: vmin     !< Value at the left end.
   real(real64),     intent(in)            :: vmax     !< Value at the right end.
   character(len=*), intent(in), optional  :: format   !< printf format of a real (checked).
   character(len=*), intent(in), optional  :: scale    !< 'linear' (default) or 'log'.
   logical,          intent(in), optional  :: clamp    !< Typed values clamped too (default false).
   integer(int32),   intent(out), optional :: stat     !< Status.
   logical                                 :: changed  !< Changed this frame.
   real(c_double),   allocatable, target   :: v(:)     !< C copy of `value`.
   real(c_double),   target                :: lo       !< C copy of `vmin`.
   real(c_double),   target                :: hi       !< C copy of `vmax`.

   changed = .false.
   if (figure_draw_refused('ig_slider', stat)) return ! a task does not draw
      if (no_components('ig_slider', size(value, kind=int32), stat)) return
   if (.not. real_range('ig_slider', real(vmin, real64), real(vmax, real64), .true., .true., real(HALF_R64, real64), &
       .false., stat)) return
   lo = vmin
   hi = vmax
   v = value
   changed = slider_core(label, K_R64, c_loc(v), size(v, kind=int32), .false., c_loc(lo), c_loc(hi), format, scale, &
                         clamp, stat)
   value = v
   endfunction ig_slider_r64_v

   recursive function ig_drag_range_r64(label, lo, hi, speed, vmin, vmax, format, stat) result(changed)
   !< Two drag boxes for the ends of a range of `real64` values; true when the user changed either: see `ig_drag_range`.
   character(len=*), intent(in)            :: label   !< Label (also the id; '##id' hides it).
   real(real64),     intent(inout)         :: lo      !< Lower end of the range.
   real(real64),     intent(inout)         :: hi      !< Upper end of the range.
   real(real64),     intent(in), optional  :: speed   !< Change per pixel dragged [value/pixel], > 0 (default 1).
   real(real64),     intent(in), optional  :: vmin    !< Lowest value of `lo` (default: none).
   real(real64),     intent(in), optional  :: vmax    !< Highest value of `hi` (default: none).
   character(len=*), intent(in), optional  :: format  !< printf format of a real (checked).
   integer(int32),   intent(out), optional :: stat    !< Status.
   logical                                 :: changed !< Changed this frame.
   real(c_double),   target                :: v(2)    !< C copies of `lo` and `hi`.
   real(c_double),   target                :: b(2)    !< Outer bounds.

   changed = .false.
   if (figure_draw_refused('ig_drag_range', stat)) return ! a task does not draw
   b = [-HALF_R64, HALF_R64]
   if (present(vmin)) b(1) = vmin
   if (present(vmax)) b(2) = vmax
   if (.not. real_range('ig_drag_range', real(b(1), real64), real(b(2), real64), present(vmin), present(vmax), &
       real(HALF_R64, real64), .true., stat)) return
   if (.not. real_range('ig_drag_range', real(lo, real64), real(hi, real64), .true., .true., real(huge(lo), real64), &
       .true., stat, 'lo', 'hi')) return
   v = [real(lo, c_double), real(hi, c_double)]
   changed = range_core(label, K_R64, c_loc(v(1)), c_loc(v(2)), speed, c_loc(b(1)), c_loc(b(2)), format, stat)
   lo = v(1)
   hi = v(2)
   endfunction ig_drag_range_r64


   ! ---- private -------------------------------------------------------------------------------------------------------
   recursive function input_core(label, k, p, n, scalar, pstep, pfast, format, enter_returns, read_only, stat) &
      result(changed)
   !< A field of `n` values of kind `k` at `p` (`InputScalar`, or `InputScalarN` unless `scalar`), after its checks.
   character(len=*),  intent(in)            :: label         !< Label.
   type(number_kind), intent(in)            :: k             !< Kind of the values.
   type(c_ptr),       intent(in)            :: p             !< The values.
   integer(int32),    intent(in)            :: n             !< How many.
   logical,           intent(in)            :: scalar        !< One value: InputScalar.
   type(c_ptr),       intent(in)            :: pstep         !< Step (null: no buttons).
   type(c_ptr),       intent(in)            :: pfast         !< Fast step (ctrl).
   character(len=*),  intent(in),  optional :: format        !< printf format.
   logical,           intent(in),  optional :: enter_returns !< True only when enter is pressed.
   logical,           intent(in),  optional :: read_only     !< Not editable.
   integer(int32),    intent(out), optional :: stat          !< Status.
   logical                                  :: changed       !< Changed this frame.
   character(kind=c_char, len=:), allocatable, target :: fmt !< C format.
   type(c_ptr)                              :: pfmt          !< The format, or null: Dear ImGui's default.
   integer(c_int)                           :: flags         !< ImGuiInputTextFlags.

   changed = .false.
   if (.not. c_format('ig_input', k, format, fmt, stat)) return
   if (.not. allocated(fmt) .and. k%family == FORMAT_REAL) fmt = cstr('%.6g')
   pfmt = c_null_ptr
   if (allocated(fmt)) pfmt = c_loc(fmt)
   flags = 0_c_int
   if (present(enter_returns)) then
      if (enter_returns) flags = ior(flags, ImGuiInputTextFlags_EnterReturnsTrue)
   endif
   if (present(read_only)) then
      if (read_only) flags = ior(flags, ImGuiInputTextFlags_ReadOnly)
   endif
   if (scalar) then
      changed = logical(igInputScalar(cstr(label), k%dtype, p, pstep, pfast, pfmt, flags))
   else
      changed = logical(igInputScalarN(cstr(label), k%dtype, p, int(n, c_int), pstep, pfast, pfmt, flags))
   endif
   call figure_check(FIG_OK, stat)
   endfunction input_core

   recursive function drag_core(label, k, p, n, scalar, speed, plo, phi, bounded, format, scale, clamp, stat) &
      result(changed)
   !< A drag box of `n` values of kind `k` at `p` (`DragScalar`, or `DragScalarN` unless `scalar`), after its checks.
   character(len=*),  intent(in)            :: label   !< Label.
   type(number_kind), intent(in)            :: k       !< Kind of the values.
   type(c_ptr),       intent(in)            :: p       !< The values.
   integer(int32),    intent(in)            :: n       !< How many.
   logical,           intent(in)            :: scalar  !< One value: DragScalar.
   real(real64),      intent(in),  optional :: speed   !< Change per pixel.
   type(c_ptr),       intent(in)            :: plo     !< Lower bound.
   type(c_ptr),       intent(in)            :: phi     !< Upper bound.
   logical,           intent(in)            :: bounded !< Both bounds given by the program.
   character(len=*),  intent(in),  optional :: format  !< printf format.
   character(len=*),  intent(in),  optional :: scale   !< 'linear' or 'log'.
   logical,           intent(in),  optional :: clamp   !< Typed values clamped.
   integer(int32),    intent(out), optional :: stat    !< Status.
   logical                                  :: changed !< Changed this frame.
   character(kind=c_char, len=:), allocatable, target :: fmt !< C format.
   type(c_ptr)                              :: pfmt    !< The format, or null: Dear ImGui's default.
   integer(c_int)                           :: flags   !< ImGuiSliderFlags.
   real(c_float)                            :: s       !< Speed.

   changed = .false.
   if (.not. speed_ok('ig_drag', speed, s, stat)) return
   if (.not. scale_flags('ig_drag', scale, clamp, flags, stat)) return
   if (iand(flags, ImGuiSliderFlags_Logarithmic) /= 0_c_int .and. .not. bounded) then
      call figure_fail(FIG_ERR_ARGUMENT, "ig_drag: scale 'log' needs vmin and vmax", stat)
      return
   endif
   if (.not. c_format('ig_drag', k, format, fmt, stat)) return
   pfmt = c_null_ptr
   if (allocated(fmt)) pfmt = c_loc(fmt)
   flags = ior(flags, ImGuiSliderFlags_ClampZeroRange) ! vmin = vmax given: the value is held there
   if (scalar) then
      changed = logical(igDragScalar(cstr(label), k%dtype, p, s, plo, phi, pfmt, flags))
   else
      changed = logical(igDragScalarN(cstr(label), k%dtype, p, int(n, c_int), s, plo, phi, pfmt, flags))
   endif
   call figure_check(FIG_OK, stat)
   endfunction drag_core

   recursive function slider_core(label, k, p, n, scalar, plo, phi, format, scale, clamp, stat) result(changed)
   !< A slider of `n` values of kind `k` at `p` (`SliderScalar`, or `SliderScalarN` unless `scalar`), after its checks.
   character(len=*),  intent(in)            :: label   !< Label.
   type(number_kind), intent(in)            :: k       !< Kind of the values.
   type(c_ptr),       intent(in)            :: p       !< The values.
   integer(int32),    intent(in)            :: n       !< How many.
   logical,           intent(in)            :: scalar  !< One value: SliderScalar.
   type(c_ptr),       intent(in)            :: plo     !< Left end.
   type(c_ptr),       intent(in)            :: phi     !< Right end.
   character(len=*),  intent(in),  optional :: format  !< printf format.
   character(len=*),  intent(in),  optional :: scale   !< 'linear' or 'log'.
   logical,           intent(in),  optional :: clamp   !< Typed values clamped.
   integer(int32),    intent(out), optional :: stat    !< Status.
   logical                                  :: changed !< Changed this frame.
   character(kind=c_char, len=:), allocatable, target :: fmt !< C format.
   type(c_ptr)                              :: pfmt    !< The format, or null: Dear ImGui's default.
   integer(c_int)                           :: flags   !< ImGuiSliderFlags.

   changed = .false.
   if (.not. scale_flags('ig_slider', scale, clamp, flags, stat)) return
   if (.not. c_format('ig_slider', k, format, fmt, stat)) return
   pfmt = c_null_ptr
   if (allocated(fmt)) pfmt = c_loc(fmt)
   if (scalar) then
      changed = logical(igSliderScalar(cstr(label), k%dtype, p, plo, phi, pfmt, flags))
   else
      changed = logical(igSliderScalarN(cstr(label), k%dtype, p, int(n, c_int), plo, phi, pfmt, flags))
   endif
   call figure_check(FIG_OK, stat)
   endfunction slider_core

   recursive function range_core(label, k, plo, phi, speed, pvmin, pvmax, format, stat) result(changed)
   !< The two drag boxes of a range of kind `k` (native `fig_drag_range`), after its checks.
   character(len=*),  intent(in)            :: label   !< Label.
   type(number_kind), intent(in)            :: k       !< Kind of the values.
   type(c_ptr),       intent(in)            :: plo     !< Lower end.
   type(c_ptr),       intent(in)            :: phi     !< Upper end.
   real(real64),      intent(in),  optional :: speed   !< Change per pixel.
   type(c_ptr),       intent(in)            :: pvmin   !< Lowest value of the lower end.
   type(c_ptr),       intent(in)            :: pvmax   !< Highest value of the upper end.
   character(len=*),  intent(in),  optional :: format  !< printf format.
   integer(int32),    intent(out), optional :: stat    !< Status.
   logical                                  :: changed !< Changed this frame.
   character(kind=c_char, len=:), allocatable, target :: fmt !< C format.
   type(c_ptr)                              :: pfmt    !< The format, or null: Dear ImGui's default.
   real(c_float)                            :: s       !< Speed.

   changed = .false.
   if (.not. speed_ok('ig_drag_range', speed, s, stat)) return
   if (.not. c_format('ig_drag_range', k, format, fmt, stat)) return
   pfmt = c_null_ptr
   if (allocated(fmt)) pfmt = c_loc(fmt)
   changed = fig_drag_range(cstr(label), k%dtype, plo, phi, s, pvmin, pvmax, pfmt, &
                            ior(ImGuiSliderFlags_AlwaysClamp, ImGuiSliderFlags_ClampZeroRange)) == 1_c_int
   call figure_check(FIG_OK, stat)
   endfunction range_core

   recursive function angle_core(label, radians, v, d, format, stat) result(changed)
   !< The slider of an angle (`SliderAngle`), after the checks of the angle, its ends and its format.
   character(len=*),      intent(in)            :: label   !< Label.
   real(real64),          intent(in)            :: radians !< The angle as the program has it [radians].
   real(c_float), target, intent(inout)         :: v       !< Its single-precision copy [radians].
   real(real64),          intent(in)            :: d(2)    !< The ends [degrees].
   character(len=*),      intent(in),  optional :: format  !< printf format of the degrees.
   integer(int32),        intent(out), optional :: stat    !< Status.
   logical                                      :: changed !< Changed this frame.
   real(real64)                                 :: limit   !< Largest angle [radians].

   changed = .false.
   limit = real(HALF_R32, real64) * PI / 180.0_real64 ! its degrees must stay in the slider's range
   if (.not. real_range('ig_slider_angle', radians, 0.0_real64, .true., .false., limit, .false., stat, 'radians')) return
   if (.not. real_range('ig_slider_angle', d(1), d(2), .true., .true., real(HALF_R32, real64), .false., stat, &
       'deg_min', 'deg_max')) return
   if (present(format)) then
      if (format_refused('ig_slider_angle', 'format', format, FORMAT_REAL, stat)) return
      changed = logical(igSliderAngle(cstr(label), c_loc(v), real(d(1), c_float), real(d(2), c_float), cstr(format), &
                                      0_c_int))
   else
      changed = logical(igSliderAngle(cstr(label), c_loc(v), real(d(1), c_float), real(d(2), c_float), &
                                      cstr('%.0f deg'), 0_c_int))
   endif
   call figure_check(FIG_OK, stat)
   endfunction angle_core

   recursive function c_format(name, k, format, fmt, stat) result(ok)
   !< `format` checked (`format_refused`, and a conversion of at most CONVERSION_MAX characters) and turned into a C
   !< string, with 'll' before the conversion of a 64-bit integer; not allocated when `format` is absent.
   character(len=*),  intent(in)                           :: name   !< The procedure.
   type(number_kind), intent(in)                           :: k      !< Kind of the value.
   character(len=*),  intent(in),  optional                :: format !< The format.
   character(kind=c_char, len=:), allocatable, intent(out) :: fmt    !< The C format.
   integer(int32),    intent(out), optional                :: stat   !< Status, on a refusal.
   logical                                                 :: ok     !< Accepted.
   integer(int32)                                          :: i      !< The conversion's '%'.
   integer(int32)                                          :: j      !< Its letter.

   ok = .true.
   if (.not. present(format)) return
   ok = .false.
   if (format_refused(name, 'format', format, k%family, stat)) return
   i = 1_int32
   do ! format_ok found exactly one conversion, and no '%' at the end
      if (format(i:i) == '%') then
         if (format(i + 1:i + 1) /= '%') exit
         i = i + 2_int32
      else
         i = i + 1_int32
      endif
   enddo
   j = i + int(verify(format(i + 1:), '-+ #0123456789.'), int32)
   if (j - i + 1_int32 > CONVERSION_MAX) then
      call figure_fail(FIG_ERR_ARGUMENT, name//": format '"//format//"' has a conversion longer than 24 characters", &
                       stat)
      return
   endif
   if (k%wide) then
      fmt = format(:j - 1_int32)//'ll'//format(j:)//c_null_char
   else
      fmt = format//c_null_char
   endif
   ok = .true.
   endfunction c_format

   recursive function speed_ok(name, speed, s, stat) result(ok)
   !< The speed of a drag, checked: above 0 and within single precision (default 1).
   character(len=*), intent(in)            :: name  !< The procedure.
   real(real64),     intent(in),  optional :: speed !< Speed [value/pixel].
   real(c_float),    intent(out)           :: s     !< Its single-precision copy.
   integer(int32),   intent(out), optional :: stat  !< Status, on a refusal.
   logical                                 :: ok    !< Accepted.

   s = 1.0_c_float
   ok = .true.
   if (.not. present(speed)) return
   ok = .not. ieee_is_nan(speed)                                ! tested apart: a comparison with NaN would signal
   if (ok) ok = speed > 0.0_real64 .and. speed <= real(huge(s), real64)
   if (.not. ok) then
      call figure_fail(FIG_ERR_ARGUMENT, name//': speed '//real_text(speed)//' is not above 0 and within single '// &
                       'precision', stat)
      return
   endif
   s = real(speed, c_float)
   endfunction speed_ok

   recursive function scale_flags(name, scale, clamp, flags, stat) result(ok)
   !< The slider flags of `scale` and `clamp`, or false with `FIG_ERR_ARGUMENT` for an unknown scale.
   character(len=*), intent(in)            :: name  !< The procedure.
   character(len=*), intent(in),  optional :: scale !< 'linear' or 'log'.
   logical,          intent(in),  optional :: clamp !< Typed values clamped.
   integer(c_int),   intent(out)           :: flags !< ImGuiSliderFlags.
   integer(int32),   intent(out), optional :: stat  !< Status, on a refusal.
   logical                                 :: ok    !< Accepted.

   flags = 0_c_int
   ok = .false.
   if (present(scale)) then
      select case (scale)
      case ('linear')
      case ('log')
         flags = ior(flags, ImGuiSliderFlags_Logarithmic)
      case default
         call figure_fail(FIG_ERR_ARGUMENT, name//": unknown scale '"//scale//"' ('linear' or 'log')", stat)
         return
      endselect
   endif
   if (present(clamp)) then
      if (clamp) flags = ior(flags, ImGuiSliderFlags_AlwaysClamp)
   endif
   ok = .true.
   endfunction scale_flags

   recursive function no_components(name, n, stat) result(refused)
   !< True, with `FIG_ERR_ARGUMENT`, for a vector of no components.
   character(len=*), intent(in)            :: name    !< The procedure.
   integer(int32),   intent(in)            :: n       !< Components.
   integer(int32),   intent(out), optional :: stat    !< Status, on a refusal.
   logical                                 :: refused !< Refused: return.

   refused = n < 1_int32
   if (refused) call figure_fail(FIG_ERR_ARGUMENT, name//': value has no components', stat)
   endfunction no_components

   recursive function int_range(name, lo, hi, has_lo, has_hi, half, ordered, stat, lo_name, hi_name) result(ok)
   !< Integer bounds checked: each one given within [-half, half]; with `ordered`, `lo <= hi` when both are given.
   character(len=*), intent(in)            :: name    !< The procedure.
   integer(int64),   intent(in)            :: lo      !< Lower bound.
   integer(int64),   intent(in)            :: hi      !< Upper bound.
   logical,          intent(in)            :: has_lo  !< `lo` given by the program.
   logical,          intent(in)            :: has_hi  !< `hi` given by the program.
   integer(int64),   intent(in)            :: half    !< Largest magnitude.
   logical,          intent(in)            :: ordered !< lo <= hi required.
   integer(int32),   intent(out), optional :: stat    !< Status, on a refusal.
   character(len=*), intent(in),  optional :: lo_name !< Name of `lo` (default 'vmin').
   character(len=*), intent(in),  optional :: hi_name !< Name of `hi` (default 'vmax').
   logical                                 :: ok      !< Accepted.
   character(len=:), allocatable           :: nl      !< Name of `lo`.
   character(len=:), allocatable           :: nh      !< Name of `hi`.

   nl = 'vmin'
   nh = 'vmax'
   if (present(lo_name)) nl = lo_name
   if (present(hi_name)) nh = hi_name
   ok = .false.
   if (has_lo .and. (lo < -half .or. lo > half)) then
      call figure_fail(FIG_ERR_ARGUMENT, name//': '//nl//' '//int_text(lo)//' is out of '//int_text(-half)//' to '// &
                       int_text(half), stat)
      return
   endif
   if (has_hi .and. (hi < -half .or. hi > half)) then
      call figure_fail(FIG_ERR_ARGUMENT, name//': '//nh//' '//int_text(hi)//' is out of '//int_text(-half)//' to '// &
                       int_text(half), stat)
      return
   endif
   if (ordered .and. has_lo .and. has_hi .and. lo > hi) then
      call figure_fail(FIG_ERR_ARGUMENT, name//': '//nl//' '//int_text(lo)//' is above '//nh//' '//int_text(hi), stat)
      return
   endif
   ok = .true.
   endfunction int_range

   recursive function real_range(name, lo, hi, has_lo, has_hi, half, ordered, stat, lo_name, hi_name) result(ok)
   !< Real bounds checked: each one given not NaN and within [-half, half]; with `ordered`, `lo <= hi` when both are
   !< given.
   character(len=*), intent(in)            :: name    !< The procedure.
   real(real64),     intent(in)            :: lo      !< Lower bound.
   real(real64),     intent(in)            :: hi      !< Upper bound.
   logical,          intent(in)            :: has_lo  !< `lo` given by the program.
   logical,          intent(in)            :: has_hi  !< `hi` given by the program.
   real(real64),     intent(in)            :: half    !< Largest magnitude.
   logical,          intent(in)            :: ordered !< lo <= hi required.
   integer(int32),   intent(out), optional :: stat    !< Status, on a refusal.
   character(len=*), intent(in),  optional :: lo_name !< Name of `lo` (default 'vmin').
   character(len=*), intent(in),  optional :: hi_name !< Name of `hi` (default 'vmax').
   logical                                 :: ok      !< Accepted.
   character(len=:), allocatable           :: nl      !< Name of `lo`.
   character(len=:), allocatable           :: nh      !< Name of `hi`.

   nl = 'vmin'
   nh = 'vmax'
   if (present(lo_name)) nl = lo_name
   if (present(hi_name)) nh = hi_name
   ok = .false.
   if (has_lo) then
      if (.not. real_ok(lo, nl)) return
   endif
   if (has_hi) then
      if (.not. real_ok(hi, nh)) return
   endif
   if (ordered .and. has_lo .and. has_hi) then
      if (lo > hi) then
         call figure_fail(FIG_ERR_ARGUMENT, name//': '//nl//' '//real_text(lo)//' is above '//nh//' '// &
                          real_text(hi), stat)
         return
      endif
   endif
   ok = .true.
   contains
      recursive function real_ok(x, what) result(good)
      !< One bound: not NaN, within [-half, half].
      real(real64),     intent(in) :: x    !< The bound.
      character(len=*), intent(in) :: what !< Its name.
      logical                      :: good !< Accepted.

      good = .false.
      if (ieee_is_nan(x)) then
         call figure_fail(FIG_ERR_ARGUMENT, name//': '//what//' is NaN', stat)
         return
      endif
      if (abs(x) > half) then
         call figure_fail(FIG_ERR_ARGUMENT, name//': '//what//' '//real_text(x)//' is out of '//real_text(-half)// &
                          ' to '//real_text(half), stat)
         return
      endif
      good = .true.
      endfunction real_ok
   endfunction real_range

   pure function int_text(i) result(text)
   !< An integer, written.
   integer(int64), intent(in)    :: i    !< The integer.
   character(len=:), allocatable :: text !< Its text.
   character(len=24)             :: buf  !< Buffer.

   write(buf, '(I0)') i
   text = trim(buf)
   endfunction int_text

   pure function real_text(x) result(text)
   !< A real, written with 6 significant digits ('NaN' for a NaN).
   real(real64), intent(in)      :: x    !< The real.
   character(len=:), allocatable :: text !< Its text.
   character(len=24)             :: buf  !< Buffer.

   if (ieee_is_nan(x)) then
      text = 'NaN'
      return
   endif
   write(buf, '(ES13.5E3)') x ! W >= D + E + 5: room for the sign (ES12.5E3 wrote asterisks for a negative)
   text = trim(adjustl(buf))
   endfunction real_text
endmodule figure_numbers
