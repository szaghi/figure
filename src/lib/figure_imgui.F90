!< figure_imgui, Dear ImGui widgets with Fortran arguments.
module figure_imgui
!< figure_imgui, Dear ImGui widgets with Fortran arguments.
!<
!< Immediate mode: call the widgets every frame; each returns what happened this frame (`ig_button` is true on the
!< frame it is clicked, `ig_checkbox`/`ig_slider` are true when they changed the value). Values are ordinary Fortran
!< variables, updated in place: no handles, no callbacks, no `target` requirements (the C `bool*` of a checkbox is a
!< local copy, written back).
use, intrinsic :: iso_c_binding, only : c_bool, c_char, c_double, c_f_pointer, c_float, c_int, c_loc, c_null_char, &
                                        c_null_ptr, c_ptr
use, intrinsic :: iso_fortran_env, only : int32, real32, real64
use figure_base, only : cstr, figure_refused
use figure_c_native, only : fig_begin_side_bar, fig_texture_sampling, fig_tool_button, fig_widget_input_text
use figure_texture, only : texture_object, texture_ref
use figure_cimgui, only : igGetTime, igProgressBar, &
                          im_vec2, igBegin, igBeginCombo, igBeginItemTooltip, igEndCombo, igEndTooltip, igPopID, &
                          igPushID_Int, igSelectable_Bool, igSetItemDefaultFocus, igButton, igCheckbox, igEnd, &
                          igGetItemRectMax, igGetItemRectMin, igImage, igInputDouble, igInputInt, igSameLine, &
                          igSeparator, igSetNextItemWidth, igSetNextWindowPos, igSetNextWindowSize, igShowDemoWindow, &
                          igSliderScalar, igTextUnformatted, im_vec4, igGetStyleColorVec4, igPopStyleColor, &
                          igPopTextWrapPos, igPushStyleColor_Vec4, igPushTextWrapPos, igAlignTextToFramePadding, &
                          igIsPopupOpen_Str, igSetWindowFocus_Str, igCalcTextSize
use figure_cimgui_enums, only : ImGuiCond_Always, ImGuiCond_FirstUseEver, ImGuiDataType_Double, ImGuiDataType_Float, &
                                ImGuiDataType_S32, ImGuiCol_Text, ImGuiCol_TextDisabled, ImGuiPopupFlags_AnyPopup

implicit none
private
public :: ig_begin, ig_begin_side_bar, ig_end, ig_button, ig_checkbox, ig_slider, ig_input, ig_text, ig_same_line, ig_separator
public :: ig_show_demo_window, ig_set_next_window, ig_item_rect, ig_image, ig_input_text, ig_set_next_item_width
public :: ig_combo, ig_tooltip, ig_selectable, ig_text_wrapped, ig_text_disabled, ig_text_colored
public :: ig_tool_button, ig_focus_window, ig_align_text_to_frame_padding, ig_text_size
public :: ig_progress_bar

interface ig_slider
   !< Slider for an integer or a real value.
   module procedure ig_slider_i32, ig_slider_r32, ig_slider_r64
endinterface ig_slider

interface ig_input
   !< Numeric field for an integer or a real value.
   module procedure ig_input_i32, ig_input_r64
endinterface ig_input

contains
   recursive function ig_begin(name, open, flags) result(visible)
   !< Begin a window; always pair with `ig_end`. With `open`, the window has a close button that sets it false.
   !< `flags` combine `ImGuiWindowFlags_*` with `ior` (`NoTitleBar`, `NoResize`, `NoMove`, `AlwaysAutoResize`,
   !< `NoBackground`, `NoDecoration`, `NoDocking`, ...).
   character(len=*), intent(in)              :: name    !< Window name (unique id and title).
   logical,          intent(inout), optional :: open    !< Window open.
   integer(int32),   intent(in),    optional :: flags   !< `ImGuiWindowFlags_*` (default none).
   logical                                   :: visible !< False when collapsed or clipped: skip its content.
   integer(c_int)                            :: f       !< Flags.
   logical(c_bool), target                   :: o       !< C copy of `open`.
   type(c_ptr)                               :: p       !< bool* or null.

   visible = .false.
   if (figure_refused('ig_begin')) return ! a task does not draw
   p = c_null_ptr
   if (present(open)) then
      o = logical(open, c_bool)
      p = c_loc(o)
   endif
   f = 0_c_int
   if (present(flags)) f = int(flags, c_int)
   visible = logical(igBegin(cstr(name), p, f))
   if (present(open)) open = logical(o)
   endfunction ig_begin

   recursive function ig_begin_side_bar(name, side, size) result(visible)
   !< Begin a bar along one side of the display: a toolbar, a status bar. `side` is `'left'`, `'right'`, `'top'` or
   !< `'bottom'`; `size` its width (left, right) or height (top, bottom) [pixels]. It is a window without title bar,
   !< not movable, not resizable, not dockable, which the work area leaves out: a dock space (`ig_dock_space`) and
   !< the main menu bar's neighbours fill the rest. Declare it every frame, after the main menu bar and before the dock
   !< space; always pair with `ig_end`. An unknown side is taken as `'left'`.
   character(len=*), intent(in) :: name    !< Window name (unique id).
   character(len=*), intent(in) :: side    !< left, right, top, bottom.
   real(real64),     intent(in) :: size    !< Width or height [pixels].
   logical                      :: visible !< Its content is drawn.
   integer(c_int)               :: s       !< Side code.

   visible = .false.
   if (figure_refused('ig_begin_side_bar')) return ! a task does not draw
   select case (side)
   case ('right')
      s = 1_c_int
   case ('top')
      s = 2_c_int
   case ('bottom')
      s = 3_c_int
   case default
      s = 0_c_int
   endselect
   visible = fig_begin_side_bar(name, len(name, c_int), s, real(size, c_double)) == 1_c_int
   endfunction ig_begin_side_bar

   function ig_focus_window(name) result(focused)
   !< Bring window `name` forward and give it the keyboard (a docked window: its tab is shown). Not while a popup or a
   !< modal is open, since focusing another window would close it: then nothing happens and the result is false; ask
   !< again on a later frame. A window not drawn yet (this frame or before) is not found: ask after its `ig_begin`.
   character(len=*), intent(in) :: name    !< Window name (as given to `ig_begin`, or its `###id` part).
   logical                      :: focused !< Focused (false: a popup is open, ask again later).

   focused = .not. logical(igIsPopupOpen_Str(c_null_char, ImGuiPopupFlags_AnyPopup))
   if (focused) call igSetWindowFocus_Str(cstr(name))
   endfunction ig_focus_window

   recursive subroutine ig_end()
   !< End the window opened by `ig_begin` (whatever it returned).
   if (figure_refused('ig_end')) return ! a task does not draw
   call igEnd()
   endsubroutine ig_end

   subroutine ig_set_next_window(x, y, width, height, always)
   !< Position (and size) of the next window [pixels]: on first use only, or every frame if `always`.
   real(real64), intent(in)           :: x      !< Left [pixels].
   real(real64), intent(in)           :: y      !< Top [pixels].
   real(real64), intent(in), optional :: width  !< Width [pixels].
   real(real64), intent(in), optional :: height !< Height [pixels].
   logical,      intent(in), optional :: always !< Enforce every frame (default: first use only).
   integer(c_int)                     :: cond   !< ImGuiCond.

   cond = ImGuiCond_FirstUseEver
   if (present(always)) then
      if (always) cond = ImGuiCond_Always
   endif
   call igSetNextWindowPos(im_vec2(real(x, c_float), real(y, c_float)), cond, im_vec2(0.0_c_float, 0.0_c_float))
   if (present(width) .and. present(height)) &
      call igSetNextWindowSize(im_vec2(real(width, c_float), real(height, c_float)), cond)
   endsubroutine ig_set_next_window

   function ig_button(label, width, height) result(pressed)
   !< A button; true on the frame it is clicked.
   character(len=*), intent(in)           :: label   !< Label.
   real(real64),     intent(in), optional :: width   !< Width [pixels] (default: fit the label).
   real(real64),     intent(in), optional :: height  !< Height [pixels] (default: fit the label).
   logical                                :: pressed !< Clicked this frame.
   type(im_vec2)                          :: extent   !< Size (not `size`: see docs/guide/known-issues.md).

   extent = im_vec2(0.0_c_float, 0.0_c_float)
   if (present(width)) extent%x = real(width, c_float)
   if (present(height)) extent%y = real(height, c_float)
   pressed = logical(igButton(cstr(label), extent))
   endfunction ig_button

   function ig_tool_button(label, icon, width, height, selected, accent) result(clicked)
   !< A workspace button, as Fusion 360's: `icon` (an `ICON_*`) above `label`, larger than it, on a framed, rounded button
   !< that shades under the pointer. `selected`: framed and tinted in the accent colour, the icon drawn in it (`accent`
   !< `[r, g, b]` in [0, 1]; default: the style's CheckMark colour). `width`, `height` [pixels]: default as wide as the
   !< label (at least 4.6 font sizes) and tall enough for the icon (1.8 font sizes) above the label. The text before
   !< `##` is shown, all of `label` is the id. True on the frame it is clicked; `ig_tooltip` and `ig_item_rect` apply to
   !< it as to any widget.
   character(len=*), intent(in)           :: label    !< Label (also its id).
   character(len=*), intent(in)           :: icon     !< Icon (UTF-8: an ICON_* constant).
   real(real64),     intent(in), optional :: width    !< Width [pixels].
   real(real64),     intent(in), optional :: height   !< Height [pixels].
   logical,          intent(in), optional :: selected !< The one shown (default false).
   real(real64),     intent(in), optional :: accent(3) !< Accent colour.
   logical                                :: clicked  !< Clicked this frame.
   real(c_double)                         :: w, h, acc(4) !< C copies.
   integer(c_int)                         :: sel      !< C copy of `selected`.

   w = 0.0_c_double
   h = 0.0_c_double
   if (present(width)) w = real(width, c_double)
   if (present(height)) h = real(height, c_double)
   sel = 0_c_int
   if (present(selected)) sel = merge(1_c_int, 0_c_int, selected)
   acc = [0.0_c_double, 0.0_c_double, 0.0_c_double, -1.0_c_double]
   if (present(accent)) acc = [real(accent, c_double), 1.0_c_double]
   clicked = fig_tool_button(label, len(label, c_int), icon, len(icon, c_int), w, h, sel, acc) == 1_c_int
   endfunction ig_tool_button

   function ig_text_size(text) result(extent)
   !< The size a text takes in the current font [pixels]: width and height (the text before `##` when it is a label):
   !< buttons of one width, a column as wide as its longest value.
   character(len=*), intent(in) :: text    !< Text (UTF-8).
   real(real64)                 :: extent(2) !< Width, height.
   type(im_vec2)                :: ext     !< Its extent.

   ext = igCalcTextSize(cstr(text), c_null_ptr, .true._c_bool, -1.0_c_float)
   extent = [real(ext%x, real64), real(ext%y, real64)]
   endfunction ig_text_size

   subroutine ig_align_text_to_frame_padding()
   !< The text that follows on this line is lowered to the text of framed widgets (fields, buttons): a label or a value
   !< beside fields, in a table row of fields.
   call igAlignTextToFramePadding()
   endsubroutine ig_align_text_to_frame_padding

   function ig_checkbox(label, value) result(changed)
   !< A check box bound to `value`; true when the user toggled it.
   character(len=*), intent(in)    :: label   !< Label.
   logical,          intent(inout) :: value   !< Value.
   logical                         :: changed !< Toggled this frame.
   logical(c_bool), target         :: v       !< C copy of `value`.

   v = logical(value, c_bool)
   changed = logical(igCheckbox(cstr(label), c_loc(v)))
   value = logical(v)
   endfunction ig_checkbox

   function ig_slider_i32(label, value, vmin, vmax) result(changed)
   !< Integer slider; true when the user changed `value`.
   character(len=*), intent(in)    :: label   !< Label.
   integer(int32),   intent(inout) :: value   !< Value.
   integer(int32),   intent(in)    :: vmin    !< Minimum.
   integer(int32),   intent(in)    :: vmax    !< Maximum.
   logical                         :: changed !< Changed this frame.
   integer(c_int), target          :: v       !< C copy of `value`.
   integer(c_int), target          :: lo      !< C copy of `vmin`.
   integer(c_int), target          :: hi      !< C copy of `vmax`.

   v = int(value, c_int)
   lo = int(vmin, c_int)
   hi = int(vmax, c_int)
   changed = logical(igSliderScalar(cstr(label), ImGuiDataType_S32, c_loc(v), c_loc(lo), c_loc(hi), c_null_ptr, 0_c_int))
   value = int(v, int32)
   endfunction ig_slider_i32

   function ig_slider_r32(label, value, vmin, vmax) result(changed)
   !< Single-precision slider; true when the user changed `value`.
   character(len=*), intent(in)    :: label   !< Label.
   real(real32),     intent(inout) :: value   !< Value.
   real(real32),     intent(in)    :: vmin    !< Minimum.
   real(real32),     intent(in)    :: vmax    !< Maximum.
   logical                         :: changed !< Changed this frame.
   real(c_float), target           :: v       !< C copy of `value`.
   real(c_float), target           :: lo      !< C copy of `vmin`.
   real(c_float), target           :: hi      !< C copy of `vmax`.

   v = real(value, c_float)
   lo = real(vmin, c_float)
   hi = real(vmax, c_float)
   changed = logical(igSliderScalar(cstr(label), ImGuiDataType_Float, c_loc(v), c_loc(lo), c_loc(hi), c_null_ptr, &
                                    0_c_int))
   value = real(v, real32)
   endfunction ig_slider_r32

   function ig_slider_r64(label, value, vmin, vmax) result(changed)
   !< Double-precision slider; true when the user changed `value`.
   character(len=*), intent(in)    :: label   !< Label.
   real(real64),     intent(inout) :: value   !< Value.
   real(real64),     intent(in)    :: vmin    !< Minimum.
   real(real64),     intent(in)    :: vmax    !< Maximum.
   logical                         :: changed !< Changed this frame.
   real(c_double), target          :: v       !< C copy of `value`.
   real(c_double), target          :: lo      !< C copy of `vmin`.
   real(c_double), target          :: hi      !< C copy of `vmax`.

   v = real(value, c_double)
   lo = real(vmin, c_double)
   hi = real(vmax, c_double)
   changed = logical(igSliderScalar(cstr(label), ImGuiDataType_Double, c_loc(v), c_loc(lo), c_loc(hi), c_null_ptr, &
                                    0_c_int))
   value = real(v, real64)
   endfunction ig_slider_r64

   function ig_input_r64(label, value, step, format) result(changed)
   !< Numeric input field for a real value; true when the user changed it.
   character(len=*), intent(in)           :: label   !< Label.
   real(real64),     intent(inout)        :: value   !< Value.
   real(real64),     intent(in), optional :: step    !< +/- buttons step (default: none).
   character(len=*), intent(in), optional :: format  !< printf format (default '%.6g').
   logical                                :: changed !< Changed this frame.
   real(c_double), target                 :: v       !< C copy of `value`.
   real(c_double)                         :: s       !< Step.

   v = real(value, c_double)
   s = 0.0_c_double
   if (present(step)) s = real(step, c_double)
   if (present(format)) then
      changed = logical(igInputDouble(cstr(label), c_loc(v), s, 10.0_c_double * s, cstr(format), 0_c_int))
   else
      changed = logical(igInputDouble(cstr(label), c_loc(v), s, 10.0_c_double * s, cstr('%.6g'), 0_c_int))
   endif
   value = real(v, real64)
   endfunction ig_input_r64

   function ig_input_i32(label, value, step) result(changed)
   !< Numeric input field for an integer value; true when the user changed it.
   character(len=*), intent(in)           :: label   !< Label.
   integer(int32),   intent(inout)        :: value   !< Value.
   integer(int32),   intent(in), optional :: step    !< +/- buttons step (default: none).
   logical                                :: changed !< Changed this frame.
   integer(c_int), target                 :: v       !< C copy of `value`.
   integer(c_int)                         :: s       !< Step.

   v = int(value, c_int)
   s = 0_c_int
   if (present(step)) s = int(step, c_int)
   changed = logical(igInputInt(cstr(label), c_loc(v), s, 10_c_int * s, 0_c_int))
   value = int(v, int32)
   endfunction ig_input_i32

   function ig_input_text(label, value, hint, flags) result(changed)
   !< A text field bound to `value`; true when the user edited it. The text can be as long as `value` (its length is
   !< the field's capacity); trailing blanks are not part of the text (Fortran pads with them). `hint` is shown while
   !< the field is empty; `flags` combine `ImGuiInputTextFlags_*` with `ior` (`CharsNoBlank`, `CharsDecimal`,
   !< `CharsScientific`, `ReadOnly`, `EnterReturnsTrue`, ...).
   character(len=*), intent(in)               :: label   !< Label.
   character(len=*), intent(inout)            :: value   !< Text.
   character(len=*), intent(in),    optional  :: hint    !< Shown while the field is empty.
   integer(int32),   intent(in),    optional  :: flags   !< `ImGuiInputTextFlags_*` (default none).
   logical                                    :: changed !< Edited this frame.
   character(kind=c_char)                     :: buf(len(value) + 1) !< C copy of the text, NUL-terminated.
   integer(c_int)                             :: f       !< Flags.
   integer(int32)                             :: n       !< Length of the text.
   integer(int32)                             :: i       !< Counter.

   n = len_trim(value)
   do i = 1_int32, n
      buf(i) = value(i:i)
   enddo
   buf(n + 1:) = c_null_char
   f = 0_c_int
   if (present(flags)) f = int(flags, c_int)
   if (present(hint)) then
      changed = fig_widget_input_text(label, len(label, c_int), hint, len(hint, c_int), buf, size(buf, kind=c_int), &
                                      f) == 1_c_int
   else
      changed = fig_widget_input_text(label, len(label, c_int), '', 0_c_int, buf, size(buf, kind=c_int), f) == 1_c_int
   endif
   if (.not. changed) return
   value = ''
   do i = 1_int32, len(value, kind=int32)
      if (buf(i) == c_null_char) exit
      value(i:i) = buf(i)
   enddo
   endfunction ig_input_text

   function ig_combo(label, current, items) result(changed)
   !< A drop-down list of `items`; `current` is the index of the one chosen (1 to `size(items)`; any other value shows
   !< none chosen). True on the frame the user picks an item (`current` is then its index).
   character(len=*), intent(in)    :: label    !< Label.
   integer(int32),   intent(inout) :: current  !< Index of the chosen item.
   character(len=*), intent(in)    :: items(:) !< Items (trailing blanks are not shown).
   logical                         :: changed  !< An item was picked this frame.
   integer(int32)                  :: i        !< Item.
   logical                         :: chosen   !< Item i is the current one.

   changed = .false.
   if (current >= 1_int32 .and. current <= size(items, kind=int32)) then
      if (.not. logical(igBeginCombo(cstr(label), cstr(trim(items(current))), 0_c_int))) return
   else
      if (.not. logical(igBeginCombo(cstr(label), cstr(''), 0_c_int))) return
   endif
   do i = 1_int32, size(items, kind=int32)
      chosen = i == current
      call igPushID_Int(int(i, c_int))                ! items may repeat a text: the index tells them apart
      if (logical(igSelectable_Bool(cstr(trim(items(i))), logical(chosen, c_bool), 0_c_int, &
                                    im_vec2(0.0_c_float, 0.0_c_float)))) then
         current = i
         changed = .true.
      endif
      if (chosen) call igSetItemDefaultFocus()        ! keyboard navigation starts from the current item
      call igPopID()
   enddo
   call igEndCombo()
   endfunction ig_combo

   subroutine ig_tooltip(text)
   !< A tooltip on the previous widget: `text` shows while the pointer rests on it (after Dear ImGui's usual delay).
   character(len=*), intent(in) :: text !< Text.

   if (.not. logical(igBeginItemTooltip())) return
   call igTextUnformatted(cstr(text), c_null_ptr)
   call igEndTooltip()
   endsubroutine ig_tooltip

   subroutine ig_set_next_item_width(width)
   !< Width of the next widget's field [pixels]; negative: up to that distance from the window's right edge.
   real(real64), intent(in) :: width !< Width [pixels].

   call igSetNextItemWidth(real(width, c_float))
   endsubroutine ig_set_next_item_width

   subroutine ig_text(text)
   !< Plain text (no formatting: compose it with Fortran internal writes).
   character(len=*), intent(in) :: text !< Text.

   call igTextUnformatted(cstr(text), c_null_ptr)
   endsubroutine ig_text

   subroutine ig_same_line(offset)
   !< Put the next item on the same line as the previous one; with `offset`, at that distance [pixels] from the
   !< window's left edge (aligned columns of labels and fields).
   real(real64), intent(in), optional :: offset !< Distance from the window's left edge [pixels].

   if (present(offset)) then
      call igSameLine(real(offset, c_float), -1.0_c_float)
   else
      call igSameLine(0.0_c_float, -1.0_c_float)
   endif
   endsubroutine ig_same_line

   function ig_selectable(label, selected) result(clicked)
   !< A line of a list, highlighted when `selected`; true on the frame it is clicked (the program then updates what is
   !< selected: the line does not change `selected` itself).
   character(len=*), intent(in) :: label    !< Label (also its id).
   logical,          intent(in) :: selected !< Highlighted.
   logical                      :: clicked  !< Clicked this frame.

   clicked = logical(igSelectable_Bool(cstr(label), logical(selected, c_bool), 0_c_int, &
                                       im_vec2(0.0_c_float, 0.0_c_float)))
   endfunction ig_selectable

   subroutine ig_text_wrapped(text)
   !< Text wrapped at the right edge of the window or region (help text, long messages).
   character(len=*), intent(in) :: text !< Text.

   call igPushTextWrapPos(0.0_c_float)
   call igTextUnformatted(cstr(text), c_null_ptr)
   call igPopTextWrapPos()
   endsubroutine ig_text_wrapped

   subroutine ig_text_disabled(text)
   !< Text in the style's disabled colour (a default value, a hint, something that does not apply).
   character(len=*), intent(in) :: text  !< Text.
   type(im_vec4), pointer       :: muted !< The style's TextDisabled colour.

   call c_f_pointer(igGetStyleColorVec4(ImGuiCol_TextDisabled), muted)
   call igPushStyleColor_Vec4(ImGuiCol_Text, muted)
   call igTextUnformatted(cstr(text), c_null_ptr)
   call igPopStyleColor(1_c_int)
   endsubroutine ig_text_disabled

   subroutine ig_text_colored(text, color)
   !< Text in `color` ([r, g, b] or [r, g, b, a] in [0, 1]); pair a colour with a mark or a word (an error marker), so
   !< that it does not rest on colour alone.
   character(len=*), intent(in) :: text     !< Text.
   real(real64),     intent(in) :: color(:) !< [r, g, b] or [r, g, b, a].
   type(im_vec4)                :: c        !< Colour.

   c = im_vec4(1.0_c_float, 1.0_c_float, 1.0_c_float, 1.0_c_float)
   if (size(color) >= 3) then
      c%x = real(color(1), c_float)
      c%y = real(color(2), c_float)
      c%z = real(color(3), c_float)
   endif
   if (size(color) >= 4) c%w = real(color(4), c_float)
   call igPushStyleColor_Vec4(ImGuiCol_Text, c)
   call igTextUnformatted(cstr(text), c_null_ptr)
   call igPopStyleColor(1_c_int)
   endsubroutine ig_text_colored

   subroutine ig_progress_bar(fraction, label, width)
   !< A progress bar (`ProgressBar`), `fraction` of it filled, in [0, 1] (clamped); `fraction` < 0 gives an
   !< indeterminate bar, a band sliding along it (animated by FIGURE with the frame clock: draw it every frame).
   !< `label` is written over it (default: the percentage; none for an indeterminate bar); `width` [pixels] (default:
   !< the width left; negative: up to that distance from the right edge). The same in every mode.
   real(real64),     intent(in)           :: fraction !< Done, in [0, 1]; < 0: indeterminate.
   character(len=*), intent(in), optional :: label    !< Text over the bar.
   real(real64),     intent(in), optional :: width    !< Width [pixels].
   character(kind=c_char, len=:), allocatable, target :: text !< C copy of `label`.
   real(c_float)                          :: f        !< Fraction.
   real(c_float)                          :: w        !< Width.
   type(c_ptr)                            :: overlay  !< Label or null.

   f = real(fraction, c_float)
   if (fraction < 0.0_real64) f = -real(igGetTime(), c_float) ! Dear ImGui's indeterminate form: a moving negative
   w = -tiny(1.0_c_float)                                      ! -FLT_MIN: the width left
   if (present(width)) w = real(width, c_float)
   overlay = c_null_ptr
   if (present(label)) then
      text = cstr(label)
      overlay = c_loc(text)
   endif
   call igProgressBar(f, im_vec2(w, 0.0_c_float), overlay)
   endsubroutine ig_progress_bar

   subroutine ig_separator()
   !< Horizontal separator.
   call igSeparator()
   endsubroutine ig_separator

   subroutine ig_show_demo_window(open)
   !< The Dear ImGui demo window (a live catalogue of every widget).
   logical, intent(inout), optional :: open !< Window open (close button).
   logical(c_bool), target          :: o    !< C copy of `open`.

   if (present(open)) then
      o = logical(open, c_bool)
      call igShowDemoWindow(c_loc(o))
      open = logical(o)
   else
      call igShowDemoWindow(c_null_ptr)
   endif
   endsubroutine ig_show_demo_window

   subroutine ig_item_rect(xmin, ymin, xmax, ymax)
   !< Screen rectangle of the last item [pixels] (tests, custom layout).
   real(real64), intent(out) :: xmin !< Left.
   real(real64), intent(out) :: ymin !< Top.
   real(real64), intent(out) :: xmax !< Right.
   real(real64), intent(out) :: ymax !< Bottom.
   type(im_vec2)             :: v    !< Corner.

   v = igGetItemRectMin()
   xmin = real(v%x, real64)
   ymin = real(v%y, real64)
   v = igGetItemRectMax()
   xmax = real(v%x, real64)
   ymax = real(v%y, real64)
   endsubroutine ig_item_rect

   subroutine ig_image(tex, width, height)
   !< A texture, pixel row 1 at the top (screen and image-file convention), `width` x `height` pixels (default: the
   !< texture's size).
   type(texture_object), intent(in)           :: tex    !< Texture.
   real(real64),         intent(in), optional :: width  !< Width [pixels].
   real(real64),         intent(in), optional :: height !< Height [pixels].
   type(im_vec2)                              :: extent !< Size (named so: a local `size` crashes nvfortran 26.9).

   extent = im_vec2(real(tex%width(), c_float), real(tex%height(), c_float))
   if (present(width)) extent%x = real(width, c_float)
   if (present(height)) extent%y = real(height, c_float)
   call fig_texture_sampling(0_c_int, 1_c_int) ! the texture's own filter (nearest unless created smooth)
   call igImage(texture_ref(tex), extent, im_vec2(0.0_c_float, 0.0_c_float), im_vec2(1.0_c_float, 1.0_c_float))
   call fig_texture_sampling(0_c_int, 0_c_int)
   endsubroutine ig_image
endmodule figure_imgui
