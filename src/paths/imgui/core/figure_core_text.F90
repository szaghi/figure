!< figure_core_text, the inner seam's calls for the code editor (implementation over Dear ImGui).
module figure_core_text
!< figure_core_text, the inner seam's calls for the code editor (implementation over Dear ImGui).
!<
!< szaghi/figure#15 P16. The Fortran code editor (src/paths/fortran/editor/, ImGuiColorTextEdit's TextEditor in
!< Fortran) draws as the fork does: in a child window, through the window's draw list (rectangles, lines, circles,
!< text, single glyphs of the current font), with the child's scroll, focus and style; it reads the keys through
!< `Shortcut`, the characters typed, the mouse; it shows tooltips and popups. This module is that part of the seam, in
!< the two-implementation scheme of figure_core (this one a thin layer over Dear ImGui through figure_cimgui, with no
!< behaviour of its own; the Fortran core of block E later, under the same names). Names `ct_*`; sizes and coordinates
!< `real(c_float)` as Dear ImGui's, so that the editor's arithmetic is single precision as the fork's (the pictures to
!< the bit); colours packed `ImU32` in an `integer(c_int)`.
!<
!< Strings go through a buffer of the module (NUL-terminated copies, no allocation; a longer one is copied with an
!< allocation). The reads of Dear ImGui's state that no C API function gives (the window's inner rectangle and
!< scrollbar, the style's DPI scale and caret width, the characters typed, the input method's position, the fork's
!< navigation workaround of a child window) are native/figure_editor.cpp's `fig_core_text_*`.
use, intrinsic :: iso_c_binding, only : c_associated, c_bool, c_char, c_double, c_f_pointer, c_float, c_int, c_null_char, &
                                         c_null_ptr, c_ptr, c_size_t, c_long_long
use, intrinsic :: iso_fortran_env, only : int32
use figure_cimgui, only : im_vec2, im_vec4, igBeginChild_Str, igBeginPopup, igBeginTooltip, igCalcTextSize,             &
                          igColorConvertFloat4ToU32, igEndChild, igEndPopup, igEndTooltip, igGetColorU32_U32,          &
                          igGetCursorScreenPos, igGetFont, igGetFontSize, igGetItemRectMax, igGetItemRectMin,         &
                          igGetScrollX, igGetScrollY, igGetStyleColorVec4, igGetTextLineHeightWithSpacing,            &
                          igGetWindowDrawList, igGetWindowPos, igIsMouseHoveringRect, igIsPopupOpen_Str,               &
                          igIsWindowFocused, igIsWindowHovered, igPopID, igPopStyleColor, igPopStyleVar,              &
                          igPushID_Int, igPushStyleColor_U32, igPushStyleVar_Vec2, igSetCursorScreenPos,              &
                          igSetNextWindowContentSize, igSetNextWindowFocus, igSetScrollX_Float, igSetScrollY_Float,   &
                          igTextUnformatted, igShortcut_Nil, igIsKeyPressed_Bool, igIsKeyDown_Nil,                     &
                          igSetNextFrameWantCaptureKeyboard, igGetMousePos, igIsMouseDown_Nil, igIsMouseClicked_Bool,  &
                          igIsMouseDoubleClicked_Nil, igIsMouseReleased_Nil, igIsMouseDragging, igGetMouseDragDelta,   &
                          igResetMouseDragDelta, igSetMouseCursor, igGetTime, igGetWindowSize, igOpenPopup_Str,        &
                          igSetClipboardText, igGetClipboardText, igGetColorU32_Col, igGetFrameHeight,                 &
                          igGetFrameHeightWithSpacing, igInvisibleButton, igButton, igGetContentRegionAvail,           &
                          igSetNextWindowPos, igSetNextWindowSize, igSetNextWindowBgAlpha, igSetNextItemWidth,         &
                          igSetKeyboardFocusHere, igIsItemDeactivated, igIsItemClicked, igBeginDisabled,               &
                          igEndDisabled, igSameLine, igPushStyleColor_Vec4, igIsKeyChordPressed_Nil,                   &
                          igSetWindowFocus_Nil, igIsWindowAppearing, igCloseCurrentPopup, igSetScrollHereY, igGetID_Str, &
                          igGetFrameCount
use figure_cimgui_core, only : ImDrawList_AddCircleFilled, ImDrawList_AddLine, ImDrawList_AddRect, ImDrawList_AddRectFilled, &
                               ImDrawList_AddText_Vec2, ImDrawList_GetClipRectMax, ImDrawList_GetClipRectMin,          &
                               ImDrawList_PopClipRect, ImDrawList_PushClipRect

implicit none
private
public :: ct_state, ct_chars, ct_ime, ct_nav
public :: ct_begin_child, ct_end_child, ct_set_next_window_content_size, ct_set_next_window_focus
public :: ct_push_style_var_vec2, ct_pop_style_var, ct_push_style_color_u32, ct_pop_style_color
public :: ct_scroll, ct_set_scroll_x, ct_set_scroll_y, ct_cursor_screen_pos, ct_set_cursor_screen_pos, ct_window_pos
public :: ct_font_size, ct_line_height_with_spacing, ct_text_width, ct_color_u32, ct_style_color, ct_float4_to_u32
public :: ct_rect_filled, ct_rect, ct_line, ct_circle_filled, ct_text, ct_char, ct_push_clip, ct_pop_clip, ct_clip_rect
public :: ct_hovering_rect, ct_begin_tooltip, ct_end_tooltip, ct_text_unformatted
public :: ct_begin_popup, ct_end_popup, ct_popup_open, ct_window_focused, ct_window_hovered, ct_item_rect
public :: ct_push_id_int, ct_pop_id
public :: ct_shortcut, ct_key_pressed, ct_key_down, ct_want_keyboard, ct_mouse_pos, ct_mouse_down, ct_mouse_clicked
public :: ct_mouse_double_clicked, ct_mouse_released, ct_mouse_dragging, ct_mouse_drag_delta, ct_reset_mouse_drag_delta
public :: ct_set_mouse_cursor, ct_time, ct_window_size, ct_open_popup, ct_set_clipboard, ct_clipboard
public :: ct_style_u32, ct_frame_height, ct_frame_height_with_spacing, ct_invisible_button, ct_button, ct_content_avail
public :: ct_set_next_window_pos, ct_set_next_window_size, ct_set_next_window_bg_alpha, ct_set_next_item_width
public :: ct_set_keyboard_focus_here, ct_item_deactivated, ct_item_clicked, ct_begin_disabled, ct_end_disabled
public :: ct_same_line, ct_push_style_color_vec4, ct_key_chord_pressed, ct_clear_window_focus, ct_window_appearing
public :: ct_close_current_popup, ct_set_scroll_here_y, ct_bring_to_front, ct_input_text
public :: ct_hscroll, ct_vscroll, ct_get_id, ct_frame_count
public :: ct_glyphs

integer(int32), parameter :: BUF_LEN = 4096_int32 !< Strings copied into the module's buffer up to this length.

character(kind=c_char, len=BUF_LEN + 1), target :: buf !< NUL-terminated copy of a string.
integer(int32), parameter :: INPUT_LEN = 1024_int32 !< The find and replace fields' buffer [bytes].
character(kind=c_char, len=INPUT_LEN), target :: input !< The field being edited.

interface
   subroutine ImFont_RenderChar(self, draw_list, size, pos, col, c, cpu_fine_clip) bind(C, name='ImFont_RenderChar')
   !< ImFont::RenderChar(ImDrawList*,float,const ImVec2,ImU32,ImWchar,const ImVec4*), imgui.h.
   import :: c_float, c_int, c_ptr, im_vec2
   implicit none
   type(c_ptr),    value :: self          !< C `ImFont*`.
   type(c_ptr),    value :: draw_list     !< C `ImDrawList*`.
   real(c_float),  value :: size          !< C `float`.
   type(im_vec2),  value :: pos           !< C `const ImVec2`.
   integer(c_int), value :: col           !< C `ImU32`.
   integer(c_int), value :: c             !< C `ImWchar` (16 bits, passed as an int).
   type(c_ptr),    value :: cpu_fine_clip !< C `const ImVec4*`, default `NULL`.
   endsubroutine ImFont_RenderChar

   subroutine fig_core_text_state(f, i) bind(C, name='fig_core_text_state')
   !< The window's, the style's and io's values the editor reads (native/figure_editor.cpp).
   import :: c_float, c_int
   implicit none
   real(c_float),  intent(out) :: f(16) !< Values (see `ct_state`).
   integer(c_int), intent(out) :: i(5)  !< Flags (see `ct_state`).
   endsubroutine fig_core_text_state

   function fig_core_text_chars(out, cap, take) result(n) bind(C, name='fig_core_text_chars')
   !< The characters typed this frame (taken with `take`).
   import :: c_int
   implicit none
   integer(c_int), intent(inout) :: out(*) !< Characters.
   integer(c_int), value         :: cap    !< Room.
   integer(c_int), value         :: take   !< Empty the queue.
   integer(c_int)                :: n      !< Characters typed.
   endfunction fig_core_text_chars

   subroutine fig_core_text_glyphs(n, x, y, col, cp) bind(C, name='fig_core_text_glyphs')
   !< A row's run of glyphs (native/figure_editor.cpp).
   import :: c_float, c_int
   implicit none
   integer(c_int), value      :: n      !< Glyphs.
   real(c_float),  intent(in) :: x(*)   !< Their x.
   real(c_float),  value      :: y      !< The row's y.
   integer(c_int), intent(in) :: col(*) !< Their colours (`ImU32`).
   integer(c_int), intent(in) :: cp(*)  !< Their code points.
   endsubroutine fig_core_text_glyphs

   subroutine fig_core_text_ime(x, y, h) bind(C, name='fig_core_text_ime')
   !< The input method's position.
   import :: c_float
   implicit none
   real(c_float), value :: x, y, h !< Position, line height.
   endsubroutine fig_core_text_ime

   function fig_core_text_input(label, text, cap, flags) result(edited) bind(C, name='fig_core_text_input')
   !< InputText over a buffer (native/figure_editor.cpp).
   import :: c_char, c_int
   implicit none
   character(kind=c_char), intent(in)    :: label(*) !< Label.
   character(kind=c_char), intent(inout) :: text(*)  !< Buffer.
   integer(c_int), value                 :: cap      !< Its size.
   integer(c_int), value                 :: flags    !< `ImGuiInputTextFlags_*`.
   integer(c_int)                        :: edited   !< 1 when edited.
   endfunction fig_core_text_input

   subroutine fig_core_text_front() bind(C, name='fig_core_text_front')
   !< BringWindowToDisplayFront(GetCurrentWindow()).
   endsubroutine fig_core_text_front

   function fig_core_text_hscroll(x0, x1, id, scroll, visible, total) result(held) bind(C, name='fig_core_text_hscroll')
   !< TextDiff's horizontal scroll bar (native/figure_editor.cpp).
   import :: c_char, c_float, c_int, c_long_long
   implicit none
   real(c_float),          value         :: x0, x1  !< Its ends.
   character(kind=c_char), intent(in)    :: id(*)   !< Its id.
   integer(c_long_long),   intent(inout) :: scroll  !< Scroll [pixels].
   real(c_float),          value         :: visible !< Visible width.
   real(c_float),          value         :: total   !< Total width.
   integer(c_int)                        :: held    !< 1 when held.
   endfunction fig_core_text_hscroll

   function fig_core_text_vscroll(r) result(has) bind(C, name='fig_core_text_vscroll')
   !< The window's vertical scroll bar, border, scroll max, horizontal wheel (native/figure_editor.cpp).
   import :: c_float, c_int
   implicit none
   real(c_float), intent(out) :: r(7) !< Rectangle, border, scroll max, wheel.
   integer(c_int)             :: has  !< 1 with a vertical scroll bar.
   endfunction fig_core_text_vscroll

   pure function c_strlen(p) result(n) bind(C, name='strlen')
   !< C's `strlen`.
   import :: c_ptr, c_size_t
   implicit none
   type(c_ptr), value :: p !< C string.
   integer(c_size_t)  :: n !< Length.
   endfunction c_strlen

   subroutine fig_core_text_nav(scale) bind(C, name='fig_core_text_nav')
   !< The fork's navigation-cursor workaround of a child window.
   import :: c_float
   implicit none
   real(c_float), value :: scale !< The style's FontScaleDpi.
   endsubroutine fig_core_text_nav
endinterface

contains
   subroutine to_buf(s)
   !< `s` into the buffer, NUL-terminated (the caller checked its length).
   character(len=*), intent(in) :: s !< String.

   buf(1:len(s)) = s
   buf(len(s) + 1:len(s) + 1) = c_null_char
   endsubroutine to_buf

   pure function v2(x, y) result(v)
   !< An ImVec2.
   real(c_float), intent(in) :: x, y !< Components.
   type(im_vec2)             :: v    !< Vector.

   v%x = x
   v%y = y
   endfunction v2

   subroutine ct_state(f, i)
   !< f: the window's InnerRect size (1, 2); the style's FontScaleDpi (3), InputTextCursorSize (4), Alpha (5); io's
   !< DeltaTime (6), MouseDoubleClickTime (7); the style's ScrollbarSize (8), ChildBorderSize (9), WindowPadding (10, 11),
   !< ItemSpacing (12, 13), FramePadding (14, 15); the window's width (16). i: the window's ScrollbarY (1), io's
   !< ConfigInputTextCursorBlink (2), ConfigMacOSXBehaviors (3), ConfigFlags (4); the window has a parent (5).
   real(c_float),  intent(out) :: f(16) !< Values.
   integer(c_int), intent(out) :: i(5)  !< Flags.

   call fig_core_text_state(f, i)
   endsubroutine ct_state

   function ct_chars(out, take) result(n)
   !< The characters typed this frame (`io.InputQueueCharacters`, up to size(out)); with `take`, the queue emptied.
   integer(c_int), intent(inout) :: out(:) !< Characters.
   logical,        intent(in)    :: take   !< Empty the queue.
   integer(c_int)                :: n      !< Characters typed (may exceed size(out)).

   n = fig_core_text_chars(out, size(out, kind=c_int), merge(1_c_int, 0_c_int, take))
   endfunction ct_chars

   subroutine ct_ime(x, y, h)
   !< The input method shown at (x, y), a line of height h (`PlatformImeData`).
   real(c_float), intent(in) :: x, y, h !< Position, line height.

   call fig_core_text_ime(x, y, h)
   endsubroutine ct_ime

   subroutine ct_nav(scale)
   !< The fork's navigation-cursor workaround of the current child window.
   real(c_float), intent(in) :: scale !< The style's FontScaleDpi.

   call fig_core_text_nav(scale)
   endsubroutine ct_nav

   function ct_begin_child(id, w, h, child_flags, window_flags) result(open)
   !< `BeginChild(id, ImVec2(w, h), child_flags, window_flags)`: end it with `ct_end_child`, open or not.
   character(len=*), intent(in) :: id           !< ID.
   real(c_float),    intent(in) :: w, h         !< Size.
   integer(c_int),   intent(in) :: child_flags  !< `ImGuiChildFlags_*`.
   integer(c_int),   intent(in) :: window_flags !< `ImGuiWindowFlags_*`.
   logical                      :: open         !< Open.

   if (len(id) <= BUF_LEN) then
      call to_buf(id)
      open = logical(igBeginChild_Str(buf, v2(w, h), child_flags, window_flags))
   else
      open = logical(igBeginChild_Str(id//c_null_char, v2(w, h), child_flags, window_flags))
   endif
   endfunction ct_begin_child

   subroutine ct_end_child()
   !< `EndChild`.
   call igEndChild()
   endsubroutine ct_end_child

   subroutine ct_set_next_window_content_size(w, h)
   !< `SetNextWindowContentSize`.
   real(c_float), intent(in) :: w, h !< Size.

   call igSetNextWindowContentSize(v2(w, h))
   endsubroutine ct_set_next_window_content_size

   subroutine ct_set_next_window_focus()
   !< `SetNextWindowFocus`.
   call igSetNextWindowFocus()
   endsubroutine ct_set_next_window_focus

   subroutine ct_push_style_var_vec2(idx, x, y)
   !< `PushStyleVar(idx, ImVec2(x, y))`.
   integer(c_int), intent(in) :: idx  !< `ImGuiStyleVar_*`.
   real(c_float),  intent(in) :: x, y !< Value.

   call igPushStyleVar_Vec2(idx, v2(x, y))
   endsubroutine ct_push_style_var_vec2

   subroutine ct_pop_style_var(n)
   !< `PopStyleVar(n)`.
   integer(c_int), intent(in) :: n !< Variables.

   call igPopStyleVar(n)
   endsubroutine ct_pop_style_var

   subroutine ct_push_style_color_u32(idx, col)
   !< `PushStyleColor(idx, col)`.
   integer(c_int), intent(in) :: idx !< `ImGuiCol_*`.
   integer(c_int), intent(in) :: col !< Packed colour.

   call igPushStyleColor_U32(idx, col)
   endsubroutine ct_push_style_color_u32

   subroutine ct_pop_style_color(n)
   !< `PopStyleColor(n)`.
   integer(c_int), intent(in) :: n !< Colours.

   call igPopStyleColor(n)
   endsubroutine ct_pop_style_color

   subroutine ct_scroll(x, y)
   !< `GetScrollX`, `GetScrollY`.
   real(c_float), intent(out) :: x, y !< Scroll.

   x = igGetScrollX()
   y = igGetScrollY()
   endsubroutine ct_scroll

   subroutine ct_set_scroll_x(x)
   !< `SetScrollX`.
   real(c_float), intent(in) :: x !< Scroll.

   call igSetScrollX_Float(x)
   endsubroutine ct_set_scroll_x

   subroutine ct_set_scroll_y(y)
   !< `SetScrollY`.
   real(c_float), intent(in) :: y !< Scroll.

   call igSetScrollY_Float(y)
   endsubroutine ct_set_scroll_y

   subroutine ct_cursor_screen_pos(x, y)
   !< `GetCursorScreenPos`.
   real(c_float), intent(out) :: x, y !< Position.
   type(im_vec2)              :: p    !< Position.

   p = igGetCursorScreenPos()
   x = p%x
   y = p%y
   endsubroutine ct_cursor_screen_pos

   subroutine ct_set_cursor_screen_pos(x, y)
   !< `SetCursorScreenPos`.
   real(c_float), intent(in) :: x, y !< Position.

   call igSetCursorScreenPos(v2(x, y))
   endsubroutine ct_set_cursor_screen_pos

   subroutine ct_window_pos(x, y)
   !< `GetWindowPos`.
   real(c_float), intent(out) :: x, y !< Position.
   type(im_vec2)              :: p    !< Position.

   p = igGetWindowPos()
   x = p%x
   y = p%y
   endsubroutine ct_window_pos

   function ct_font_size() result(s)
   !< `GetFontSize`.
   real(c_float) :: s !< Size.

   s = igGetFontSize()
   endfunction ct_font_size

   function ct_line_height_with_spacing() result(h)
   !< `GetTextLineHeightWithSpacing`.
   real(c_float) :: h !< Height.

   h = igGetTextLineHeightWithSpacing()
   endfunction ct_line_height_with_spacing

   function ct_text_width(text) result(w)
   !< `CalcTextSize(text).x`.
   character(len=*), intent(in) :: text !< Text.
   real(c_float)                :: w    !< Width.
   type(im_vec2)                :: s    !< Size.

   if (len(text) <= BUF_LEN) then
      call to_buf(text)
      s = igCalcTextSize(buf, c_null_ptr, .false._c_bool, -1.0_c_float)
   else
      s = igCalcTextSize(text//c_null_char, c_null_ptr, .false._c_bool, -1.0_c_float)
   endif
   w = s%x
   endfunction ct_text_width

   function ct_color_u32(col) result(c)
   !< `GetColorU32(col)` (the style's Alpha applied).
   integer(c_int), intent(in) :: col !< Packed colour.
   integer(c_int)             :: c   !< Packed colour.

   c = igGetColorU32_U32(col, 1.0_c_float)
   endfunction ct_color_u32

   subroutine ct_style_color(idx, rgba)
   !< `GetStyle().Colors[idx]`.
   integer(c_int), intent(in)  :: idx     !< `ImGuiCol_*`.
   real(c_float),  intent(out) :: rgba(4) !< Colour.
   type(im_vec4), pointer      :: c       !< Colour.

   call c_f_pointer(igGetStyleColorVec4(idx), c)
   rgba = [c%x, c%y, c%z, c%w]
   endsubroutine ct_style_color

   function ct_float4_to_u32(rgba) result(c)
   !< `ColorConvertFloat4ToU32`.
   real(c_float), intent(in) :: rgba(4) !< Colour.
   integer(c_int)            :: c       !< Packed colour.
   type(im_vec4)             :: v       !< Colour.

   v%x = rgba(1)
   v%y = rgba(2)
   v%z = rgba(3)
   v%w = rgba(4)
   c = igColorConvertFloat4ToU32(v)
   endfunction ct_float4_to_u32

   subroutine ct_rect_filled(x0, y0, x1, y1, col)
   !< The window's `AddRectFilled` (no rounding).
   real(c_float),  intent(in) :: x0, y0, x1, y1 !< Corners.
   integer(c_int), intent(in) :: col            !< Colour.

   call ImDrawList_AddRectFilled(igGetWindowDrawList(), v2(x0, y0), v2(x1, y1), col, 0.0_c_float, 0_c_int)
   endsubroutine ct_rect_filled

   subroutine ct_rect(x0, y0, x1, y1, col)
   !< The window's `AddRect` (no rounding, thickness 1).
   real(c_float),  intent(in) :: x0, y0, x1, y1 !< Corners.
   integer(c_int), intent(in) :: col            !< Colour.

   call ImDrawList_AddRect(igGetWindowDrawList(), v2(x0, y0), v2(x1, y1), col, 0.0_c_float, 1.0_c_float, 0_c_int)
   endsubroutine ct_rect

   subroutine ct_line(x1, y1, x2, y2, col)
   !< The window's `AddLine` (thickness 1).
   real(c_float),  intent(in) :: x1, y1, x2, y2 !< Ends.
   integer(c_int), intent(in) :: col            !< Colour.

   call ImDrawList_AddLine(igGetWindowDrawList(), v2(x1, y1), v2(x2, y2), col, 1.0_c_float, 0_c_int)
   endsubroutine ct_line

   subroutine ct_circle_filled(x, y, radius, col, segments)
   !< The window's `AddCircleFilled`.
   real(c_float),  intent(in) :: x, y, radius !< Centre, radius.
   integer(c_int), intent(in) :: col          !< Colour.
   integer(c_int), intent(in) :: segments     !< Segments.

   call ImDrawList_AddCircleFilled(igGetWindowDrawList(), v2(x, y), radius, col, segments)
   endsubroutine ct_circle_filled

   subroutine ct_text(x, y, col, text)
   !< The window's `AddText` (the current font).
   real(c_float),    intent(in) :: x, y !< Position.
   integer(c_int),   intent(in) :: col  !< Colour.
   character(len=*), intent(in) :: text !< Text (UTF-8).

   if (len(text) <= BUF_LEN) then
      call to_buf(text)
      call ImDrawList_AddText_Vec2(igGetWindowDrawList(), v2(x, y), col, buf, c_null_ptr)
   else
      call ImDrawList_AddText_Vec2(igGetWindowDrawList(), v2(x, y), col, text//c_null_char, c_null_ptr)
   endif
   endsubroutine ct_text

   subroutine ct_char(x, y, col, cp)
   !< `GetFont()->RenderChar(GetWindowDrawList(), GetFontSize(), ImVec2(x, y), col, cp)`.
   real(c_float),  intent(in) :: x, y !< Position.
   integer(c_int), intent(in) :: col  !< Colour.
   integer(c_int), intent(in) :: cp   !< Code point.

   call ImFont_RenderChar(igGetFont(), igGetWindowDrawList(), igGetFontSize(), v2(x, y), col, cp, c_null_ptr)
   endsubroutine ct_char

   subroutine ct_glyphs(n, x, y, col, cp)
   !< n glyphs of one row at y, in order, each as `ct_char` draws it (`font->RenderChar(drawList, fontSize, ImVec2(x(k),
   !< y), col(k), cp(k))`), the font, the list and the size taken once (szaghi/figure#16 S10: the fork's `renderText`
   !< keeps them; one call a run).
   integer(c_int), intent(in) :: n      !< Glyphs.
   real(c_float),  intent(in) :: x(*)   !< Their x.
   real(c_float),  intent(in) :: y      !< The row's y.
   integer(c_int), intent(in) :: col(*) !< Their colours.
   integer(c_int), intent(in) :: cp(*)  !< Their code points.

   if (n > 0_c_int) call fig_core_text_glyphs(n, x, y, col, cp)
   endsubroutine ct_glyphs

   subroutine ct_push_clip(x0, y0, x1, y1, intersect)
   !< The window's draw list's `PushClipRect`.
   real(c_float), intent(in) :: x0, y0, x1, y1 !< Corners.
   logical,       intent(in) :: intersect      !< With the current one.

   call ImDrawList_PushClipRect(igGetWindowDrawList(), v2(x0, y0), v2(x1, y1), logical(intersect, c_bool))
   endsubroutine ct_push_clip

   subroutine ct_pop_clip()
   !< The window's draw list's `PopClipRect`.
   call ImDrawList_PopClipRect(igGetWindowDrawList())
   endsubroutine ct_pop_clip

   subroutine ct_clip_rect(x0, y0, x1, y1)
   !< The window's draw list's `GetClipRectMin`, `GetClipRectMax`.
   real(c_float), intent(out) :: x0, y0, x1, y1 !< Corners.
   type(im_vec2)              :: a, b           !< Corners.

   a = ImDrawList_GetClipRectMin(igGetWindowDrawList())
   b = ImDrawList_GetClipRectMax(igGetWindowDrawList())
   x0 = a%x
   y0 = a%y
   x1 = b%x
   y1 = b%y
   endsubroutine ct_clip_rect

   function ct_hovering_rect(x0, y0, x1, y1) result(yes)
   !< `IsMouseHoveringRect` (clipped).
   real(c_float), intent(in) :: x0, y0, x1, y1 !< Corners.
   logical                   :: yes            !< Hovered.

   yes = logical(igIsMouseHoveringRect(v2(x0, y0), v2(x1, y1), .true._c_bool))
   endfunction ct_hovering_rect

   function ct_begin_tooltip() result(open)
   !< `BeginTooltip`.
   logical :: open !< Open (end it with `ct_end_tooltip`).

   open = logical(igBeginTooltip())
   endfunction ct_begin_tooltip

   subroutine ct_end_tooltip()
   !< `EndTooltip`.
   call igEndTooltip()
   endsubroutine ct_end_tooltip

   subroutine ct_text_unformatted(text)
   !< `TextUnformatted`.
   character(len=*), intent(in) :: text !< Text.

   if (len(text) <= BUF_LEN) then
      call to_buf(text)
      call igTextUnformatted(buf, c_null_ptr)
   else
      call igTextUnformatted(text//c_null_char, c_null_ptr)
   endif
   endsubroutine ct_text_unformatted

   function ct_begin_popup(id, flags) result(open)
   !< `BeginPopup(id, flags)`.
   character(len=*), intent(in) :: id    !< Popup.
   integer(c_int),   intent(in) :: flags !< `ImGuiWindowFlags_*`.
   logical                      :: open  !< Open (end it with `ct_end_popup`).

   call to_buf(id(1:min(len(id), BUF_LEN)))
   open = logical(igBeginPopup(buf, flags))
   endfunction ct_begin_popup

   subroutine ct_end_popup()
   !< `EndPopup`.
   call igEndPopup()
   endsubroutine ct_end_popup

   function ct_popup_open(id) result(open)
   !< `IsPopupOpen(id)`.
   character(len=*), intent(in) :: id   !< Popup.
   logical                      :: open !< Open.

   call to_buf(id(1:min(len(id), BUF_LEN)))
   open = logical(igIsPopupOpen_Str(buf, 0_c_int))
   endfunction ct_popup_open

   function ct_window_focused() result(yes)
   !< `IsWindowFocused()`.
   logical :: yes !< Focused.

   yes = logical(igIsWindowFocused(0_c_int))
   endfunction ct_window_focused

   function ct_window_hovered() result(yes)
   !< `IsWindowHovered()`.
   logical :: yes !< Hovered.

   yes = logical(igIsWindowHovered(0_c_int))
   endfunction ct_window_hovered

   subroutine ct_item_rect(x0, y0, x1, y1)
   !< `GetItemRectMin`, `GetItemRectMax`.
   real(c_float), intent(out) :: x0, y0, x1, y1 !< Corners.
   type(im_vec2)              :: a, b           !< Corners.

   a = igGetItemRectMin()
   b = igGetItemRectMax()
   x0 = a%x
   y0 = a%y
   x1 = b%x
   y1 = b%y
   endsubroutine ct_item_rect

   subroutine ct_push_id_int(i)
   !< `PushID(int)`.
   integer(c_int), intent(in) :: i !< ID.

   call igPushID_Int(i)
   endsubroutine ct_push_id_int

   subroutine ct_pop_id()
   !< `PopID`.
   call igPopID()
   endsubroutine ct_pop_id
   ! ---- keys, mouse, clipboard (szaghi/figure#15 P16 step 12) -------------------------------------------------------
   function ct_shortcut(chord, flags) result(yes)
   !< `Shortcut(chord, flags)`.
   integer(c_int), intent(in) :: chord !< `ImGuiKey_*` with `ImGuiMod_*`.
   integer(c_int), intent(in) :: flags !< `ImGuiInputFlags_*`.
   logical                    :: yes   !< Pressed (routed to the window).

   yes = logical(igShortcut_Nil(chord, flags))
   endfunction ct_shortcut

   function ct_key_pressed(key) result(yes)
   !< `IsKeyPressed(key)` (repeating).
   integer(c_int), intent(in) :: key !< `ImGuiKey_*`.
   logical                    :: yes !< Pressed.

   yes = logical(igIsKeyPressed_Bool(key, .true._c_bool))
   endfunction ct_key_pressed

   function ct_key_down(key) result(yes)
   !< `IsKeyDown(key)` (a key or an `ImGuiMod_*`).
   integer(c_int), intent(in) :: key !< Key.
   logical                    :: yes !< Down.

   yes = logical(igIsKeyDown_Nil(key))
   endfunction ct_key_down

   subroutine ct_want_keyboard()
   !< `SetNextFrameWantCaptureKeyboard(true)`.
   call igSetNextFrameWantCaptureKeyboard(.true._c_bool)
   endsubroutine ct_want_keyboard

   subroutine ct_mouse_pos(x, y)
   !< `GetMousePos`.
   real(c_float), intent(out) :: x, y !< Position.
   type(im_vec2)              :: p    !< Position.

   p = igGetMousePos()
   x = p%x
   y = p%y
   endsubroutine ct_mouse_pos

   function ct_mouse_down(button) result(yes)
   !< `IsMouseDown(button)`.
   integer(c_int), intent(in) :: button !< Button.
   logical                    :: yes    !< Down.

   yes = logical(igIsMouseDown_Nil(button))
   endfunction ct_mouse_down

   function ct_mouse_clicked(button) result(yes)
   !< `IsMouseClicked(button)`.
   integer(c_int), intent(in) :: button !< Button.
   logical                    :: yes    !< Clicked.

   yes = logical(igIsMouseClicked_Bool(button, .false._c_bool))
   endfunction ct_mouse_clicked

   function ct_mouse_double_clicked(button) result(yes)
   !< `IsMouseDoubleClicked(button)`.
   integer(c_int), intent(in) :: button !< Button.
   logical                    :: yes    !< Double clicked.

   yes = logical(igIsMouseDoubleClicked_Nil(button))
   endfunction ct_mouse_double_clicked

   function ct_mouse_released(button) result(yes)
   !< `IsMouseReleased(button)`.
   integer(c_int), intent(in) :: button !< Button.
   logical                    :: yes    !< Released.

   yes = logical(igIsMouseReleased_Nil(button))
   endfunction ct_mouse_released

   function ct_mouse_dragging(button) result(yes)
   !< `IsMouseDragging(button)`.
   integer(c_int), intent(in) :: button !< Button.
   logical                    :: yes    !< Dragging.

   yes = logical(igIsMouseDragging(button, -1.0_c_float))
   endfunction ct_mouse_dragging

   subroutine ct_mouse_drag_delta(button, dx, dy)
   !< `GetMouseDragDelta(button)`.
   integer(c_int), intent(in)  :: button !< Button.
   real(c_float),  intent(out) :: dx, dy !< Delta.
   type(im_vec2)               :: d      !< Delta.

   d = igGetMouseDragDelta(button, -1.0_c_float)
   dx = d%x
   dy = d%y
   endsubroutine ct_mouse_drag_delta

   subroutine ct_reset_mouse_drag_delta(button)
   !< `ResetMouseDragDelta(button)`.
   integer(c_int), intent(in) :: button !< Button.

   call igResetMouseDragDelta(button)
   endsubroutine ct_reset_mouse_drag_delta

   subroutine ct_set_mouse_cursor(cursor)
   !< `SetMouseCursor`.
   integer(c_int), intent(in) :: cursor !< `ImGuiMouseCursor_*`.

   call igSetMouseCursor(cursor)
   endsubroutine ct_set_mouse_cursor

   function ct_time() result(t)
   !< `GetTime`.
   real(c_double) :: t !< Time [s].

   t = igGetTime()
   endfunction ct_time

   subroutine ct_window_size(w, h)
   !< `GetWindowSize`.
   real(c_float), intent(out) :: w, h !< Size.
   type(im_vec2)              :: s    !< Size.

   s = igGetWindowSize()
   w = s%x
   h = s%y
   endsubroutine ct_window_size

   subroutine ct_open_popup(id)
   !< `OpenPopup(id)`.
   character(len=*), intent(in) :: id !< Popup.
   logical(c_bool)              :: ok !< Unused.

   call to_buf(id(1:min(len(id), BUF_LEN)))
   ok = igOpenPopup_Str(buf, 0_c_int)
   endsubroutine ct_open_popup

   subroutine ct_set_clipboard(text)
   !< `SetClipboardText`.
   character(len=*), intent(in) :: text !< Text (UTF-8).

   if (len(text) <= BUF_LEN) then
      call to_buf(text)
      call igSetClipboardText(buf)
   else
      call igSetClipboardText(text//c_null_char)
   endif
   endsubroutine ct_set_clipboard

   function ct_clipboard(text) result(got)
   !< `GetClipboardText`: false for no text (NULL).
   character(len=:), allocatable, intent(out) :: text !< Text.
   logical                                    :: got  !< Text there.
   type(c_ptr)                                :: p    !< C string.
   character(kind=c_char), pointer            :: s(:) !< Its bytes.
   integer(int32)                             :: n, k !< Length, counter.

   text = ''
   p = igGetClipboardText()
   got = c_associated(p)
   if (.not. got) return
   n = int(c_strlen(p), int32)
   call c_f_pointer(p, s, [n])
   deallocate(text)
   allocate(character(len=n) :: text)
   do k = 1_int32, n
      text(k:k) = s(k)
   enddo
   endfunction ct_clipboard
   ! ---- popups, widgets of the find and replace window (szaghi/figure#15 P16 step 13) ------------------------------
   function ct_style_u32(idx) result(c)
   !< `GetColorU32(idx)`.
   integer(c_int), intent(in) :: idx !< `ImGuiCol_*`.
   integer(c_int)             :: c   !< Packed colour.

   c = igGetColorU32_Col(idx, 1.0_c_float)
   endfunction ct_style_u32

   function ct_frame_height() result(h)
   !< `GetFrameHeight`.
   real(c_float) :: h !< Height.

   h = igGetFrameHeight()
   endfunction ct_frame_height

   function ct_frame_height_with_spacing() result(h)
   !< `GetFrameHeightWithSpacing`.
   real(c_float) :: h !< Height.

   h = igGetFrameHeightWithSpacing()
   endfunction ct_frame_height_with_spacing

   function ct_invisible_button(id, w, h) result(pressed)
   !< `InvisibleButton(id, ImVec2(w, h))`.
   character(len=*), intent(in) :: id      !< ID.
   real(c_float),    intent(in) :: w, h    !< Size.
   logical                      :: pressed !< Pressed.

   call to_buf(id(1:min(len(id), BUF_LEN)))
   pressed = logical(igInvisibleButton(buf, v2(w, h), 0_c_int))
   endfunction ct_invisible_button

   function ct_button(label, w, h) result(pressed)
   !< `Button(label, ImVec2(w, h))`.
   character(len=*), intent(in) :: label   !< Label.
   real(c_float),    intent(in) :: w, h    !< Size.
   logical                      :: pressed !< Pressed.

   call to_buf(label(1:min(len(label), BUF_LEN)))
   pressed = logical(igButton(buf, v2(w, h)))
   endfunction ct_button

   subroutine ct_content_avail(w, h)
   !< `GetContentRegionAvail`.
   real(c_float), intent(out) :: w, h !< Size.
   type(im_vec2)              :: s    !< Size.

   s = igGetContentRegionAvail()
   w = s%x
   h = s%y
   endsubroutine ct_content_avail

   subroutine ct_set_next_window_pos(x, y)
   !< `SetNextWindowPos(ImVec2(x, y))`.
   real(c_float), intent(in) :: x, y !< Position.

   call igSetNextWindowPos(v2(x, y), 0_c_int, v2(0.0_c_float, 0.0_c_float))
   endsubroutine ct_set_next_window_pos

   subroutine ct_set_next_window_size(w, h)
   !< `SetNextWindowSize(ImVec2(w, h))`.
   real(c_float), intent(in) :: w, h !< Size.

   call igSetNextWindowSize(v2(w, h), 0_c_int)
   endsubroutine ct_set_next_window_size

   subroutine ct_set_next_window_bg_alpha(a)
   !< `SetNextWindowBgAlpha`.
   real(c_float), intent(in) :: a !< Alpha.

   call igSetNextWindowBgAlpha(a)
   endsubroutine ct_set_next_window_bg_alpha

   subroutine ct_set_next_item_width(w)
   !< `SetNextItemWidth`.
   real(c_float), intent(in) :: w !< Width.

   call igSetNextItemWidth(w)
   endsubroutine ct_set_next_item_width

   subroutine ct_set_keyboard_focus_here()
   !< `SetKeyboardFocusHere()`.
   call igSetKeyboardFocusHere(0_c_int)
   endsubroutine ct_set_keyboard_focus_here

   function ct_item_deactivated() result(yes)
   !< `IsItemDeactivated`.
   logical :: yes !< Deactivated.

   yes = logical(igIsItemDeactivated())
   endfunction ct_item_deactivated

   function ct_item_clicked() result(yes)
   !< `IsItemClicked(ImGuiMouseButton_Left)`.
   logical :: yes !< Clicked.

   yes = logical(igIsItemClicked(0_c_int))
   endfunction ct_item_clicked

   subroutine ct_begin_disabled()
   !< `BeginDisabled()`.
   call igBeginDisabled(.true._c_bool)
   endsubroutine ct_begin_disabled

   subroutine ct_end_disabled()
   !< `EndDisabled`.
   call igEndDisabled()
   endsubroutine ct_end_disabled

   subroutine ct_same_line()
   !< `SameLine()`.
   call igSameLine(0.0_c_float, -1.0_c_float)
   endsubroutine ct_same_line

   subroutine ct_push_style_color_vec4(idx, rgba)
   !< `PushStyleColor(idx, ImVec4(rgba))`.
   integer(c_int), intent(in) :: idx     !< `ImGuiCol_*`.
   real(c_float),  intent(in) :: rgba(4) !< Colour.
   type(im_vec4)              :: v       !< Colour.

   v%x = rgba(1)
   v%y = rgba(2)
   v%z = rgba(3)
   v%w = rgba(4)
   call igPushStyleColor_Vec4(idx, v)
   endsubroutine ct_push_style_color_vec4

   function ct_key_chord_pressed(chord) result(yes)
   !< `IsKeyChordPressed(chord)`.
   integer(c_int), intent(in) :: chord !< Key chord.
   logical                    :: yes   !< Pressed.

   yes = logical(igIsKeyChordPressed_Nil(chord))
   endfunction ct_key_chord_pressed

   subroutine ct_clear_window_focus()
   !< `SetWindowFocus(nullptr)`.
   call igSetWindowFocus_Nil()
   endsubroutine ct_clear_window_focus

   function ct_window_appearing() result(yes)
   !< `IsWindowAppearing`.
   logical :: yes !< Appearing.

   yes = logical(igIsWindowAppearing())
   endfunction ct_window_appearing

   subroutine ct_close_current_popup()
   !< `CloseCurrentPopup`.
   call igCloseCurrentPopup()
   endsubroutine ct_close_current_popup

   subroutine ct_set_scroll_here_y(ratio)
   !< `SetScrollHereY`.
   real(c_float), intent(in) :: ratio !< Ratio.

   call igSetScrollHereY(ratio)
   endsubroutine ct_set_scroll_here_y

   subroutine ct_bring_to_front()
   !< `BringWindowToDisplayFront(GetCurrentWindow())`.
   call fig_core_text_front()
   endsubroutine ct_bring_to_front

   function ct_input_text(label, value, flags) result(changed)
   !< `InputText(label, buffer, flags)` on `value` (a buffer of the module: up to 1023 bytes).
   character(len=*),              intent(in)    :: label   !< Label.
   character(len=:), allocatable, intent(inout) :: value   !< Text.
   integer(c_int),                intent(in)    :: flags   !< `ImGuiInputTextFlags_*`.
   logical                                      :: changed !< Edited.
   integer(int32)                               :: n, k    !< Lengths.

   n = min(len(value, int32), INPUT_LEN - 1_int32)
   input(1:n) = value(1:n)
   input(n + 1:n + 1) = c_null_char
   call to_buf(label(1:min(len(label), BUF_LEN)))
   changed = fig_core_text_input(buf, input, INPUT_LEN, flags) /= 0_c_int
   k = index(input, c_null_char) - 1_int32
   if (k < 0_int32) k = INPUT_LEN
   if (k /= len(value, int32)) then
      value = input(1:k)
   elseif (value /= input(1:k)) then
      value = input(1:k)
   endif
   endfunction ct_input_text
   ! ---- the diff view (szaghi/figure#15 P16 step 14) ------------------------------------------------------------
   function ct_hscroll(x0, x1, id, scroll, visible, total) result(held)
   !< TextDiff's horizontal scroll bar over [x0, x1] at the window's bottom (`ScrollbarEx`, by id); `scroll` whole pixels.
   real(c_float),        intent(in)    :: x0, x1  !< Ends.
   character(len=*),     intent(in)    :: id      !< ID.
   integer(c_long_long), intent(inout) :: scroll  !< Scroll [pixels].
   real(c_float),        intent(in)    :: visible !< Visible width.
   real(c_float),        intent(in)    :: total   !< Total width.
   logical                             :: held    !< Held.

   call to_buf(id(1:min(len(id), BUF_LEN)))
   held = fig_core_text_hscroll(x0, x1, buf, scroll, visible, total) /= 0_c_int
   endfunction ct_hscroll

   function ct_vscroll(r) result(has)
   !< The window's vertical scroll bar (`r(1:4)`: `GetWindowScrollbarRect`), its border size (5), `GetScrollMaxY` (6),
   !< io.MouseWheelH (7); true when it has the bar.
   real(c_float), intent(out) :: r(7) !< Values.
   logical                    :: has  !< A vertical scroll bar.

   r = 0.0_c_float
   has = fig_core_text_vscroll(r) /= 0_c_int
   endfunction ct_vscroll

   function ct_get_id(label) result(id)
   !< `GetID(label)`.
   character(len=*), intent(in) :: label !< Label.
   integer(c_int)               :: id    !< ID.

   call to_buf(label(1:min(len(label), BUF_LEN)))
   id = igGetID_Str(buf)
   endfunction ct_get_id

   function ct_frame_count() result(n)
   !< `GetFrameCount`.
   integer(c_int) :: n !< Frame.

   n = igGetFrameCount()
   endfunction ct_frame_count
endmodule figure_core_text
