!< figure_core_layout, the inner seam's layout and widgets for the Markdown renderer (implementation over Dear ImGui).
module figure_core_layout
!< figure_core_layout, the inner seam's layout and widgets for the Markdown renderer (implementation over Dear ImGui).
!<
!< szaghi/figure#15 P15. figure_core (P8) gives the plots what they draw with: items, the draw list, input. The Markdown
!< renderer (src/paths/fortran/markdown/, imgui_rich_md's in Fortran) lays text out as Dear ImGui's items: a text run
!< and its line kept open (`SameLine`), the cursor, indents, groups, tables, child windows, collapsing headers, fonts
!< pushed with their size, style colours, tooltips. This module is that part of the seam, in the same two-implementation
!< scheme (this one a thin layer over Dear ImGui through figure_cimgui, with no behaviour of its own; the Fortran core
!< of block E later, under the same names). Names `cl_*`; sizes and coordinates `real(c_float)` as Dear ImGui's, so
!< that a client's arithmetic is single precision as imgui_rich_md's (the pictures and the state to the bit); colours
!< packed `ImU32` in an `integer(c_int)` or `real(c_float)` RGBA.
!<
!< Texts are given as a pointer and a length in bytes (`cl_text(p, n)`: a run of the client's own buffer, not copied,
!< not NUL-terminated) or as a Fortran string (`cl_text_str`, copied into a buffer of the module). The reads of Dear
!< ImGui's internals that no C API function gives (`DC.IsSameLine`, the window's scroll and decorations, the draw list's
!< vertices, ...) are native/figure_markdown.cpp's `fig_core_*`.
use, intrinsic :: iso_c_binding, only : c_associated, c_bool, c_char, c_double, c_f_pointer, c_float, c_int, c_intptr_t, &
                                         c_loc, &
                                         c_long_long, c_null_char, c_null_ptr, c_ptr, c_size_t
use, intrinsic :: iso_fortran_env, only : int32
use figure_cimgui, only : im_texture_ref, im_vec2, im_vec4, igBeginChild_Str, igBeginGroup, igBeginTable, igBullet,       &
                          igCalcTextSize, igCollapsingHeader_TreeNodeFlags, igColorConvertHSVtoRGB, igColorConvertRGBtoHSV, &
                          igDummy, igEndChild, igEndGroup, igEndTable, igGetColorU32_Col, igGetColorU32_Vec4,             &
                          igGetContentRegionAvail, igGetCursorPos, igGetCursorScreenPos, igGetFont, igGetFontSize,        &
                          igGetItemID, igGetItemRectMax, igGetItemRectMin, igGetItemRectSize, igGetScrollY,               &
                          igGetStateStorage, igGetStyleColorVec4, igGetTextLineHeight, igGetWindowDrawList,               &
                          igGetWindowPos, igImage, igIndent, igIsItemHovered, igIsMouseClicked_Bool, igIsMouseReleased_Nil, &
                          igNewLine, igPopFont, igPopID, igPopStyleColor, igPushFont, igPushID_Int, igPushID_StrStr,        &
                          igPushStyleColor_Vec4, igSameLine, igSeparator, igSetClipboardText, igSetCursorPos,             &
                          igSetCursorPosX, igSetCursorPosY, igSetMouseCursor, igSetNextItemOpen, igSetScrollY_Float,      &
                          igSmallButton, igTableNextColumn, igTableNextRow, igTextUnformatted, igUnindent, igGetID_Str,    &
                          igGetFrameHeight, igGetFrameHeightWithSpacing, igGetMousePos, igIsMouseDown_Nil,                &
                          igIsMousePosValid, igGetMouseClickedCount, igIsWindowHovered, igIsWindowFocused,                &
                          igIsAnyItemHovered, igOpenPopup_Str, igBeginPopup, igEndPopup,         &
                          igMenuItem_Bool, igIsRectVisible_Vec2, igColorConvertFloat4ToU32, igGetFrameCount,              &
                          igSetNextWindowFocus, igButton, igArrowButton, igIsItemActive, igIsItemDeactivated,             &
                          igIsKeyPressed_Bool, igAlignTextToFramePadding, igCheckbox, igSelectable_Bool, igSetScrollHereY, &
                          igIsWindowAppearing, igBeginTooltip, igEndTooltip, igSetNextWindowPos, igIsMouseHoveringRect,   &
                          igCloseCurrentPopup, igBeginTabBar, igEndTabBar, igBeginTabItem, igEndTabItem, igBeginCombo,    &
                          igEndCombo, igSetNextItemWidth, igShortcut_Nil, igInvisibleButton, igGetWindowHeight,           &
                          igSetKeyboardFocusHere, igIsItemVisible, igGetTime, igSetCursorScreenPos
use figure_cimgui_core, only : ImDrawList_AddLine, ImDrawList_AddRect, ImDrawList_AddRectFilled, igClearActiveID, &
                               ImDrawList_AddText_Vec2, ImDrawList_AddCircle, ImDrawList_AddCircleFilled,          &
                               ImDrawList_PushClipRect, ImDrawList_PopClipRect,                                     &
                               igGetActiveID, igGetCurrentWindow, igKeepAliveID, igSetActiveID

implicit none
private
public :: cl_line_open, cl_new_line, cl_same_line, cl_dummy, cl_indent, cl_unindent, cl_separator, cl_bullet
public :: cl_text, cl_text_str, cl_text_width, cl_text_width_str, cl_word_wrap, cl_font_size, cl_text_line_height
public :: cl_frame_height, cl_frame_height_with_spacing
public :: cl_cursor_pos, cl_set_cursor_pos, cl_set_cursor_pos_x, cl_set_cursor_pos_y, cl_cursor_screen_pos
public :: cl_content_avail, cl_item_rect_min, cl_item_rect_max, cl_item_rect_size, cl_item_id
public :: cl_push_font, cl_pop_font, cl_font, cl_font_scale
public :: cl_push_style_color, cl_pop_style_color, cl_style_color, cl_color_u32, cl_color_u32_rgba, cl_style
public :: cl_rgb_to_hsv, cl_hsv_to_rgb
public :: cl_draw_line, cl_draw_rect, cl_draw_rect_filled, cl_channels_split, cl_channels_set, cl_channels_merge
public :: cl_vtx_count, cl_vtx_shift
public :: cl_item_hovered, cl_set_mouse_cursor, cl_tooltip, cl_mouse_clicked, cl_mouse_released, cl_mouse_drag_past
public :: cl_image
public :: cl_begin_table, cl_end_table, cl_table_next_row, cl_table_next_column
public :: cl_push_id_int, cl_push_id, cl_pop_id, cl_get_id
public :: cl_begin_group, cl_end_group
public :: cl_collapsing_header, cl_set_next_item_open, cl_window_pos, cl_scroll_y, cl_set_scroll_y, cl_window_state
public :: cl_storage_get_int, cl_storage_set_int
public :: cl_begin_child, cl_end_child, cl_small_button, cl_set_clipboard
public :: cl_ptr_add, cl_ptr_diff
public :: cl_mouse_pos, cl_mouse_down, cl_mouse_pos_valid, cl_mouse_clicked_count, cl_window_hovered, cl_window_focused
public :: cl_any_item_hovered, cl_active_id, cl_set_active_id, cl_keep_alive, cl_clear_active_id, cl_key_chord_pressed
public :: cl_open_popup, cl_begin_popup, cl_end_popup, cl_menu_item, cl_separator_item, cl_rect_visible, cl_hash_str
public :: cl_splitter_split, cl_splitter_set, cl_splitter_merge, cl_float4_to_u32, cl_io_state
public :: cl_font_text_width, cl_utf8_length, cl_frame_count
public :: cl_set_next_window_focus, cl_button, cl_arrow_button, cl_find_field, cl_item_active, cl_item_deactivated
public :: cl_key_pressed, cl_align_text_to_frame_padding, cl_checkbox, cl_selectable, cl_set_scroll_here_y
public :: cl_window_appearing, cl_draw_text, cl_draw_circle, cl_begin_tooltip, cl_end_tooltip, cl_set_next_window_pos
public :: cl_scrollbar_rect, cl_push_clip_rect, cl_pop_clip_rect, cl_mouse_hovering_rect, cl_close_current_popup
public :: cl_begin_tab_bar, cl_end_tab_bar, cl_begin_tab_item, cl_end_tab_item, cl_begin_combo, cl_end_combo
public :: cl_set_next_item_width, cl_shortcut, cl_invisible_button, cl_window_height, cl_set_keyboard_focus_here
public :: cl_item_visible, cl_time, cl_set_cursor_screen_pos

integer(int32), parameter :: BUF_LEN = 4096_int32 !< A string copied into the module's buffer up to this length.

character(kind=c_char, len=BUF_LEN + 1), target :: buf !< NUL-terminated copy of a string.
type(c_ptr) :: splitter = c_null_ptr !< The client's ImDrawListSplitter (made at its first use, kept).

interface
   function ImFont_CalcWordWrapPosition(self, size, text, text_end, wrap_width) result(res) &
      bind(C, name='ImFont_CalcWordWrapPosition')
   !< ImFont::CalcWordWrapPosition(float,const char*,const char*,float), imgui.h.
   import :: c_float, c_ptr
   implicit none
   type(c_ptr),   value :: self       !< C `ImFont*`.
   real(c_float), value :: size       !< C `float`.
   type(c_ptr),   value :: text       !< C `const char*`.
   type(c_ptr),   value :: text_end   !< C `const char*`.
   real(c_float), value :: wrap_width !< C `float`.
   type(c_ptr)          :: res        !< C `const char*`.
   endfunction ImFont_CalcWordWrapPosition

   subroutine ImDrawList_ChannelsSplit(self, count) bind(C, name='ImDrawList_ChannelsSplit')
   !< ImDrawList::ChannelsSplit(int), imgui.h.
   import :: c_int, c_ptr
   implicit none
   type(c_ptr),    value :: self  !< C `ImDrawList*`.
   integer(c_int), value :: count !< C `int`.
   endsubroutine ImDrawList_ChannelsSplit

   subroutine ImDrawList_ChannelsSetCurrent(self, n) bind(C, name='ImDrawList_ChannelsSetCurrent')
   !< ImDrawList::ChannelsSetCurrent(int), imgui.h.
   import :: c_int, c_ptr
   implicit none
   type(c_ptr),    value :: self !< C `ImDrawList*`.
   integer(c_int), value :: n    !< C `int`.
   endsubroutine ImDrawList_ChannelsSetCurrent

   subroutine ImDrawList_ChannelsMerge(self) bind(C, name='ImDrawList_ChannelsMerge')
   !< ImDrawList::ChannelsMerge(), imgui.h.
   import :: c_ptr
   implicit none
   type(c_ptr), value :: self !< C `ImDrawList*`.
   endsubroutine ImDrawList_ChannelsMerge

   function igIsMouseDragPastThreshold(button, lock_threshold) result(res) bind(C, name='igIsMouseDragPastThreshold')
   !< ImGui::IsMouseDragPastThreshold(ImGuiMouseButton,float), imgui_internal.h.
   import :: c_bool, c_float, c_int
   implicit none
   integer(c_int), value :: button         !< C `ImGuiMouseButton`.
   real(c_float),  value :: lock_threshold !< C `float` (-1: io.MouseDragThreshold).
   logical(c_bool)       :: res            !< C `bool`.
   endfunction igIsMouseDragPastThreshold

   function ImGuiStorage_GetInt(self, key, default_val) result(res) bind(C, name='ImGuiStorage_GetInt')
   !< ImGuiStorage::GetInt(ImGuiID,int), imgui.h.
   import :: c_int, c_ptr
   implicit none
   type(c_ptr),    value :: self        !< C `ImGuiStorage*`.
   integer(c_int), value :: key         !< C `ImGuiID`.
   integer(c_int), value :: default_val !< C `int`.
   integer(c_int)        :: res         !< C `int`.
   endfunction ImGuiStorage_GetInt

   subroutine ImGuiStorage_SetInt(self, key, val) bind(C, name='ImGuiStorage_SetInt')
   !< ImGuiStorage::SetInt(ImGuiID,int), imgui.h.
   import :: c_int, c_ptr
   implicit none
   type(c_ptr),    value :: self !< C `ImGuiStorage*`.
   integer(c_int), value :: key  !< C `ImGuiID`.
   integer(c_int), value :: val  !< C `int`.
   endsubroutine ImGuiStorage_SetInt

   function igImHashStr(data, data_size, seed) result(res) bind(C, name='igImHashStr')
   !< ImHashStr(const char*,size_t,ImGuiID), imgui_internal.h.
   import :: c_int, c_ptr, c_size_t
   implicit none
   type(c_ptr),       value :: data      !< C `const char*`.
   integer(c_size_t), value :: data_size !< C `size_t`.
   integer(c_int),    value :: seed      !< C `ImGuiID`.
   integer(c_int)           :: res       !< C `ImGuiID`.
   endfunction igImHashStr

   function ImFont_CalcTextSizeA(self, size, max_width, wrap_width, text_begin, text_end, out_remaining) result(res) &
      bind(C, name='ImFont_CalcTextSizeA')
   !< ImFont::CalcTextSizeA(float,float,float,const char*,const char*,const char**), imgui.h.
   import :: c_float, c_ptr, im_vec2
   implicit none
   type(c_ptr),   value :: self          !< C `ImFont*`.
   real(c_float), value :: size          !< C `float`.
   real(c_float), value :: max_width     !< C `float`.
   real(c_float), value :: wrap_width    !< C `float`.
   type(c_ptr),   value :: text_begin    !< C `const char*`.
   type(c_ptr),   value :: text_end      !< C `const char*`.
   type(c_ptr),   value :: out_remaining !< C `const char**`.
   type(im_vec2)        :: res           !< C `ImVec2`.
   endfunction ImFont_CalcTextSizeA

   function igImTextCharFromUtf8(out_char, in_text, in_text_end) result(res) bind(C, name='igImTextCharFromUtf8')
   !< ImTextCharFromUtf8(unsigned int*,const char*,const char*), imgui_internal.h.
   import :: c_int, c_ptr
   implicit none
   integer(c_int), intent(out) :: out_char    !< C `unsigned int*`.
   type(c_ptr),    value       :: in_text     !< C `const char*`.
   type(c_ptr),    value       :: in_text_end !< C `const char*`.
   integer(c_int)              :: res         !< Bytes read.
   endfunction igImTextCharFromUtf8

   function igIsKeyChordPressed_InputFlags(key_chord, flags, owner_id) result(res) &
      bind(C, name='igIsKeyChordPressed_InputFlags')
   !< ImGui::IsKeyChordPressed(ImGuiKeyChord,ImGuiInputFlags,ImGuiID), imgui_internal.h.
   import :: c_bool, c_int
   implicit none
   integer(c_int), value :: key_chord !< C `ImGuiKeyChord`.
   integer(c_int), value :: flags     !< C `ImGuiInputFlags`.
   integer(c_int), value :: owner_id  !< C `ImGuiID`.
   logical(c_bool)       :: res       !< C `bool`.
   endfunction igIsKeyChordPressed_InputFlags

   subroutine igFocusWindow(window, flags) bind(C, name='igFocusWindow')
   !< ImGui::FocusWindow(ImGuiWindow*,ImGuiFocusRequestFlags), imgui_internal.h.
   import :: c_int, c_ptr
   implicit none
   type(c_ptr),    value :: window !< C `ImGuiWindow*`.
   integer(c_int), value :: flags  !< C `ImGuiFocusRequestFlags`.
   endsubroutine igFocusWindow

   function ImDrawListSplitter_ImDrawListSplitter() result(res) bind(C, name='ImDrawListSplitter_ImDrawListSplitter')
   !< new ImDrawListSplitter(), imgui.h.
   import :: c_ptr
   implicit none
   type(c_ptr) :: res !< C `ImDrawListSplitter*`.
   endfunction ImDrawListSplitter_ImDrawListSplitter

   subroutine ImDrawListSplitter_Split(self, draw_list, count) bind(C, name='ImDrawListSplitter_Split')
   !< ImDrawListSplitter::Split(ImDrawList*,int), imgui.h.
   import :: c_int, c_ptr
   implicit none
   type(c_ptr),    value :: self      !< C `ImDrawListSplitter*`.
   type(c_ptr),    value :: draw_list !< C `ImDrawList*`.
   integer(c_int), value :: count     !< C `int`.
   endsubroutine ImDrawListSplitter_Split

   subroutine ImDrawListSplitter_SetCurrentChannel(self, draw_list, channel_idx) &
      bind(C, name='ImDrawListSplitter_SetCurrentChannel')
   !< ImDrawListSplitter::SetCurrentChannel(ImDrawList*,int), imgui.h.
   import :: c_int, c_ptr
   implicit none
   type(c_ptr),    value :: self        !< C `ImDrawListSplitter*`.
   type(c_ptr),    value :: draw_list   !< C `ImDrawList*`.
   integer(c_int), value :: channel_idx !< C `int`.
   endsubroutine ImDrawListSplitter_SetCurrentChannel

   subroutine ImDrawListSplitter_Merge(self, draw_list) bind(C, name='ImDrawListSplitter_Merge')
   !< ImDrawListSplitter::Merge(ImDrawList*), imgui.h.
   import :: c_ptr
   implicit none
   type(c_ptr), value :: self      !< C `ImDrawListSplitter*`.
   type(c_ptr), value :: draw_list !< C `ImDrawList*`.
   endsubroutine ImDrawListSplitter_Merge

   subroutine fig_core_io_state(f, i) bind(C, name='fig_core_io_state')
   !< The input state no C API function gives (see `cl_io_state`).
   import :: c_float, c_int
   implicit none
   real(c_float),  intent(out) :: f(4) !< Values.
   integer(c_int), intent(out) :: i(6) !< Flags.
   endsubroutine fig_core_io_state

   ! native/figure_markdown.cpp: Dear ImGui's internals (implementation A)
   function fig_core_line_open() result(res) bind(C, name='fig_core_line_open')
   !< Whether the current window's line is open (DC.IsSameLine).
   import :: c_int
   implicit none
   integer(c_int) :: res !< 0 or 1.
   endfunction fig_core_line_open

   function fig_core_font_scale() result(res) bind(C, name='fig_core_font_scale')
   !< The scale of a size pushed with PushFont(NULL, size), relative to the frame's base size.
   import :: c_float
   implicit none
   real(c_float) :: res !< Scale.
   endfunction fig_core_font_scale

   subroutine fig_core_window_state(s) bind(C, name='fig_core_window_state')
   !< The current window's state (see `cl_window_state`).
   import :: c_float
   implicit none
   real(c_float), intent(out) :: s(14) !< State.
   endsubroutine fig_core_window_state

   subroutine fig_core_style(s) bind(C, name='fig_core_style')
   !< The style's values the renderer reads (see `cl_style`).
   import :: c_float
   implicit none
   real(c_float), intent(out) :: s(12) !< Values.
   endsubroutine fig_core_style

   function fig_core_vtx_count() result(res) bind(C, name='fig_core_vtx_count')
   !< The vertices of the current window's draw list.
   import :: c_int
   implicit none
   integer(c_int) :: res !< Vertices.
   endfunction fig_core_vtx_count

   subroutine fig_core_vtx_shift(start, dx) bind(C, name='fig_core_vtx_shift')
   !< The vertices of the current window's draw list from `start` (0-based) moved right by dx.
   import :: c_float, c_int
   implicit none
   integer(c_int), value :: start !< First vertex, 0-based.
   real(c_float),  value :: dx    !< Shift [pixels].
   endsubroutine fig_core_vtx_shift

   subroutine fig_core_scrollbar_rect(r) bind(C, name='fig_core_scrollbar_rect')
   !< The current window's vertical scrollbar's rectangle (`GetWindowScrollbarRect(window, ImGuiAxis_Y)`).
   import :: c_float
   implicit none
   real(c_float), intent(out) :: r(4) !< x0, y0, x1, y1.
   endsubroutine fig_core_scrollbar_rect

   function fig_core_find_field(label, hint, buf, size, step, dropdown, select_query) result(changed) &
      bind(C, name='fig_core_find_field')
   !< imgui_rich_md's find field: `InputTextWithHint` with its callback (the arrows step, the down arrow opens the list,
   !< the text selected at the first callback when asked).
   import :: c_char, c_int, c_ptr
   implicit none
   character(kind=c_char), intent(in) :: label(*)     !< NUL-terminated.
   character(kind=c_char), intent(in) :: hint(*)      !< NUL-terminated.
   type(c_ptr),            value      :: buf          !< The text, NUL-terminated, `size` bytes of room.
   integer(c_int),         value      :: size         !< Room.
   integer(c_int),         intent(inout) :: step      !< -1, 1 by the arrows.
   integer(c_int),         intent(inout) :: dropdown  !< 1 by the down arrow.
   integer(c_int),         intent(inout) :: select_query !< 1: select all at the first callback (then 0).
   integer(c_int)                     :: changed      !< The text changed.
   endfunction fig_core_find_field

   subroutine fig_core_tooltip(text, n) bind(C, name='fig_core_tooltip')
   !< SetTooltip("%s", text) of n bytes.
   import :: c_int, c_ptr
   implicit none
   type(c_ptr),    value :: text !< C `const char*`.
   integer(c_int), value :: n    !< Bytes.
   endsubroutine fig_core_tooltip
endinterface

contains
   ! ---- pointers into a client's buffer ------------------------------------------------------------------------------
   function cl_ptr_add(p, n) result(q)
   !< The pointer `n` bytes after `p`.
   type(c_ptr),     intent(in) :: p !< Pointer.
   integer(c_int),  intent(in) :: n !< Bytes.
   type(c_ptr)                  :: q !< `p + n`.
   integer(c_intptr_t)          :: a !< Address.

   a = transfer(p, a)
   q = transfer(a + int(n, c_intptr_t), q)
   endfunction cl_ptr_add

   function cl_ptr_diff(p, base) result(n)
   !< The bytes from `base` to `p`.
   type(c_ptr), intent(in) :: p, base !< Pointers.
   integer(c_int)          :: n       !< `p - base`.

   n = int(transfer(p, 0_c_intptr_t) - transfer(base, 0_c_intptr_t), c_int)
   endfunction cl_ptr_diff

   ! ---- the line and the cursor --------------------------------------------------------------------------------------
   function cl_line_open() result(yes)
   !< Whether the line is open: the last item ended with `SameLine` (imgui_rich_md's `line_is_open`).
   logical :: yes !< Open.

   yes = fig_core_line_open() /= 0_c_int
   endfunction cl_line_open

   subroutine cl_new_line()
   !< `NewLine`.
   call igNewLine()
   endsubroutine cl_new_line

   subroutine cl_same_line(offset, spacing)
   !< `SameLine(offset, spacing)` (defaults 0 and -1).
   real(c_float), intent(in), optional :: offset  !< Offset from the start.
   real(c_float), intent(in), optional :: spacing !< Spacing (-1: the style's).
   real(c_float)                       :: o, s    !< Values.

   o = 0.0_c_float
   s = -1.0_c_float
   if (present(offset)) o = offset
   if (present(spacing)) s = spacing
   call igSameLine(o, s)
   endsubroutine cl_same_line

   subroutine cl_dummy(w, h)
   !< `Dummy(ImVec2(w, h))`.
   real(c_float), intent(in) :: w, h !< Size.

   call igDummy(im_vec2(w, h))
   endsubroutine cl_dummy

   subroutine cl_indent(w)
   !< `Indent(w)` (default 0: the style's IndentSpacing).
   real(c_float), intent(in), optional :: w !< Width.

   if (present(w)) then
      call igIndent(w)
   else
      call igIndent(0.0_c_float)
   endif
   endsubroutine cl_indent

   subroutine cl_unindent(w)
   !< `Unindent(w)` (default 0: the style's IndentSpacing).
   real(c_float), intent(in), optional :: w !< Width.

   if (present(w)) then
      call igUnindent(w)
   else
      call igUnindent(0.0_c_float)
   endif
   endsubroutine cl_unindent

   subroutine cl_separator()
   !< `Separator`.
   call igSeparator()
   endsubroutine cl_separator

   subroutine cl_bullet()
   !< `Bullet`.
   call igBullet()
   endsubroutine cl_bullet

   subroutine cl_cursor_pos(x, y)
   !< `GetCursorPos`.
   real(c_float), intent(out) :: x, y !< Position, in the window.
   type(im_vec2)              :: v    !< Value.

   v = igGetCursorPos()
   x = v%x
   y = v%y
   endsubroutine cl_cursor_pos

   subroutine cl_set_cursor_pos(x, y)
   !< `SetCursorPos`.
   real(c_float), intent(in) :: x, y !< Position, in the window.

   call igSetCursorPos(im_vec2(x, y))
   endsubroutine cl_set_cursor_pos

   subroutine cl_set_cursor_pos_x(x)
   !< `SetCursorPosX`.
   real(c_float), intent(in) :: x !< Abscissa, in the window.

   call igSetCursorPosX(x)
   endsubroutine cl_set_cursor_pos_x

   subroutine cl_set_cursor_pos_y(y)
   !< `SetCursorPosY`.
   real(c_float), intent(in) :: y !< Ordinate, in the window.

   call igSetCursorPosY(y)
   endsubroutine cl_set_cursor_pos_y

   subroutine cl_cursor_screen_pos(x, y)
   !< `GetCursorScreenPos`.
   real(c_float), intent(out) :: x, y !< Position, on the screen.
   type(im_vec2)              :: v    !< Value.

   v = igGetCursorScreenPos()
   x = v%x
   y = v%y
   endsubroutine cl_cursor_screen_pos

   subroutine cl_content_avail(x, y)
   !< `GetContentRegionAvail`.
   real(c_float), intent(out) :: x, y !< Room.
   type(im_vec2)              :: v    !< Value.

   v = igGetContentRegionAvail()
   x = v%x
   y = v%y
   endsubroutine cl_content_avail

   subroutine cl_item_rect_min(x, y)
   !< `GetItemRectMin`.
   real(c_float), intent(out) :: x, y !< Corner.
   type(im_vec2)              :: v    !< Value.

   v = igGetItemRectMin()
   x = v%x
   y = v%y
   endsubroutine cl_item_rect_min

   subroutine cl_item_rect_max(x, y)
   !< `GetItemRectMax`.
   real(c_float), intent(out) :: x, y !< Corner.
   type(im_vec2)              :: v    !< Value.

   v = igGetItemRectMax()
   x = v%x
   y = v%y
   endsubroutine cl_item_rect_max

   subroutine cl_item_rect_size(x, y)
   !< `GetItemRectSize`.
   real(c_float), intent(out) :: x, y !< Size.
   type(im_vec2)              :: v    !< Value.

   v = igGetItemRectSize()
   x = v%x
   y = v%y
   endsubroutine cl_item_rect_size

   function cl_item_id() result(id)
   !< `GetItemID`.
   integer(c_int) :: id !< ID.

   id = igGetItemID()
   endfunction cl_item_id

   ! ---- text ---------------------------------------------------------------------------------------------------------
   subroutine cl_text(p, n)
   !< `TextUnformatted(p, p + n)`.
   type(c_ptr),    intent(in) :: p !< Text.
   integer(c_int), intent(in) :: n !< Bytes.
   character(kind=c_char), pointer :: s(:) !< The text.

   if (n <= 0_c_int) then
      call cl_text_str('')
      return
   endif
   call c_f_pointer(p, s, [n])
   call igTextUnformatted(s, cl_ptr_add(p, n))
   endsubroutine cl_text

   subroutine cl_text_str(text)
   !< `TextUnformatted(text)`.
   character(len=*), intent(in) :: text !< Text.

   if (len(text) <= BUF_LEN) then
      buf(1:len(text)) = text
      buf(len(text) + 1:len(text) + 1) = c_null_char
      call igTextUnformatted(buf, c_null_ptr)
   else
      call igTextUnformatted(text//c_null_char, c_null_ptr)
   endif
   endsubroutine cl_text_str

   function cl_text_width(p, n) result(w)
   !< `CalcTextSize(p, p + n).x`.
   type(c_ptr),    intent(in) :: p !< Text.
   integer(c_int), intent(in) :: n !< Bytes.
   real(c_float)              :: w !< Width.
   character(kind=c_char), pointer :: s(:) !< The text.
   type(im_vec2)                   :: v    !< Size.

   w = 0.0_c_float
   if (n <= 0_c_int) return
   call c_f_pointer(p, s, [n])
   v = igCalcTextSize(s, cl_ptr_add(p, n), .false._c_bool, -1.0_c_float)
   w = v%x
   endfunction cl_text_width

   function cl_text_width_str(text) result(w)
   !< `CalcTextSize(text).x`.
   character(len=*), intent(in) :: text !< Text.
   real(c_float)                :: w    !< Width.
   type(im_vec2)                :: v    !< Size.

   w = 0.0_c_float
   if (len(text) == 0) return
   if (len(text) <= BUF_LEN) then
      buf(1:len(text)) = text
      buf(len(text) + 1:len(text) + 1) = c_null_char
      v = igCalcTextSize(buf, c_null_ptr, .false._c_bool, -1.0_c_float)
   else
      v = igCalcTextSize(text//c_null_char, c_null_ptr, .false._c_bool, -1.0_c_float)
   endif
   w = v%x
   endfunction cl_text_width_str

   function cl_word_wrap(size, p, n, width) result(k)
   !< `GetFont()->CalcWordWrapPosition(size, p, p + n, width)`: the bytes from `p` of the first line.
   real(c_float),  intent(in) :: size  !< Font size.
   type(c_ptr),    intent(in) :: p     !< Text.
   integer(c_int), intent(in) :: n     !< Bytes.
   real(c_float),  intent(in) :: width !< Wrap width.
   integer(c_int)             :: k     !< Bytes of the line.

   k = cl_ptr_diff(ImFont_CalcWordWrapPosition(igGetFont(), size, p, cl_ptr_add(p, n), width), p)
   endfunction cl_word_wrap

   function cl_font_size() result(s)
   !< `GetFontSize`.
   real(c_float) :: s !< Size.

   s = igGetFontSize()
   endfunction cl_font_size

   function cl_text_line_height() result(h)
   !< `GetTextLineHeight`.
   real(c_float) :: h !< Height.

   h = igGetTextLineHeight()
   endfunction cl_text_line_height

   function cl_frame_height() result(h)
   !< `GetFrameHeight`.
   real(c_float) :: h !< Height.

   h = igGetFrameHeight()
   endfunction cl_frame_height

   function cl_frame_height_with_spacing() result(h)
   !< `GetFrameHeightWithSpacing`.
   real(c_float) :: h !< Height.

   h = igGetFrameHeightWithSpacing()
   endfunction cl_frame_height_with_spacing

   ! ---- fonts and style ------------------------------------------------------------------------------------------------
   subroutine cl_push_font(font, size)
   !< `PushFont(font, size)`.
   type(c_ptr),   intent(in) :: font !< C `ImFont*` (null: the current one).
   real(c_float), intent(in) :: size !< Size (0: the current one).

   call igPushFont(font, size)
   endsubroutine cl_push_font

   subroutine cl_pop_font()
   !< `PopFont`.
   call igPopFont()
   endsubroutine cl_pop_font

   function cl_font() result(font)
   !< `GetFont`.
   type(c_ptr) :: font !< C `ImFont*`.

   font = igGetFont()
   endfunction cl_font

   function cl_font_scale() result(s)
   !< The scale of a size pushed with `PushFont(NULL, size)`, relative to the frame's base size (imgui_rich_md's
   !< `_FontScale`, outside a render).
   real(c_float) :: s !< Scale.

   s = fig_core_font_scale()
   endfunction cl_font_scale

   subroutine cl_push_style_color(idx, rgba)
   !< `PushStyleColor(idx, ImVec4(rgba))`.
   integer(c_int), intent(in) :: idx     !< `ImGuiCol_*`.
   real(c_float),  intent(in) :: rgba(4) !< Colour.

   call igPushStyleColor_Vec4(idx, im_vec4(rgba(1), rgba(2), rgba(3), rgba(4)))
   endsubroutine cl_push_style_color

   subroutine cl_pop_style_color(count)
   !< `PopStyleColor(count)` (default 1).
   integer(c_int), intent(in), optional :: count !< Colours.

   if (present(count)) then
      call igPopStyleColor(count)
   else
      call igPopStyleColor(1_c_int)
   endif
   endsubroutine cl_pop_style_color

   subroutine cl_style_color(idx, rgba)
   !< `GetStyle().Colors[idx]`, as stored.
   integer(c_int), intent(in)  :: idx     !< `ImGuiCol_*`.
   real(c_float),  intent(out) :: rgba(4) !< Colour.
   type(im_vec4), pointer      :: c       !< The style's.

   call c_f_pointer(igGetStyleColorVec4(idx), c)
   rgba = [c%x, c%y, c%z, c%w]
   endsubroutine cl_style_color

   function cl_color_u32(idx, alpha_mul) result(col)
   !< `GetColorU32(idx, alpha_mul)` (default 1).
   integer(c_int), intent(in)           :: idx       !< `ImGuiCol_*`.
   real(c_float),  intent(in), optional :: alpha_mul !< Alpha factor.
   integer(c_int)                       :: col       !< Packed colour.

   if (present(alpha_mul)) then
      col = igGetColorU32_Col(idx, alpha_mul)
   else
      col = igGetColorU32_Col(idx, 1.0_c_float)
   endif
   endfunction cl_color_u32

   function cl_color_u32_rgba(rgba) result(col)
   !< `GetColorU32(ImVec4(rgba))` (the style's Alpha applied).
   real(c_float), intent(in) :: rgba(4) !< Colour.
   integer(c_int)            :: col     !< Packed colour.

   col = igGetColorU32_Vec4(im_vec4(rgba(1), rgba(2), rgba(3), rgba(4)))
   endfunction cl_color_u32_rgba

   subroutine cl_style(s)
   !< The style's values: FramePadding (1, 2), IndentSpacing (3), ItemSpacing (4, 5), WindowPadding (6, 7),
   !< ItemInnerSpacing (8, 9), ScrollbarSize (10), FontScaleMain (11), FontScaleDpi (12).
   real(c_float), intent(out) :: s(12) !< Values.

   call fig_core_style(s)
   endsubroutine cl_style

   subroutine cl_rgb_to_hsv(r, g, b, h, s, v)
   !< `ColorConvertRGBtoHSV`.
   real(c_float), intent(in)          :: r, g, b !< RGB.
   real(c_float), intent(out), target :: h, s, v !< HSV.

   call igColorConvertRGBtoHSV(r, g, b, c_loc(h), c_loc(s), c_loc(v))
   endsubroutine cl_rgb_to_hsv

   subroutine cl_hsv_to_rgb(h, s, v, r, g, b)
   !< `ColorConvertHSVtoRGB`.
   real(c_float), intent(in)          :: h, s, v !< HSV.
   real(c_float), intent(out), target :: r, g, b !< RGB.

   call igColorConvertHSVtoRGB(h, s, v, c_loc(r), c_loc(g), c_loc(b))
   endsubroutine cl_hsv_to_rgb

   ! ---- the window's draw list ---------------------------------------------------------------------------------------
   subroutine cl_draw_line(x1, y1, x2, y2, col, thickness)
   !< `GetWindowDrawList()->AddLine`.
   real(c_float),  intent(in) :: x1, y1, x2, y2 !< Ends.
   integer(c_int), intent(in) :: col            !< Colour.
   real(c_float),  intent(in) :: thickness      !< Thickness.

   call ImDrawList_AddLine(igGetWindowDrawList(), im_vec2(x1, y1), im_vec2(x2, y2), col, thickness, 0_c_int)
   endsubroutine cl_draw_line

   subroutine cl_draw_rect(x0, y0, x1, y1, col, rounding, thickness)
   !< `GetWindowDrawList()->AddRect` (no corner flags).
   real(c_float),  intent(in) :: x0, y0, x1, y1 !< Corners.
   integer(c_int), intent(in) :: col            !< Colour.
   real(c_float),  intent(in) :: rounding       !< Rounding.
   real(c_float),  intent(in) :: thickness      !< Thickness.

   call ImDrawList_AddRect(igGetWindowDrawList(), im_vec2(x0, y0), im_vec2(x1, y1), col, rounding, thickness, 0_c_int)
   endsubroutine cl_draw_rect

   subroutine cl_draw_rect_filled(x0, y0, x1, y1, col, rounding)
   !< `GetWindowDrawList()->AddRectFilled` (no corner flags).
   real(c_float),  intent(in) :: x0, y0, x1, y1 !< Corners.
   integer(c_int), intent(in) :: col            !< Colour.
   real(c_float),  intent(in) :: rounding       !< Rounding.

   call ImDrawList_AddRectFilled(igGetWindowDrawList(), im_vec2(x0, y0), im_vec2(x1, y1), col, rounding, 0_c_int)
   endsubroutine cl_draw_rect_filled

   subroutine cl_channels_split(n)
   !< `GetWindowDrawList()->ChannelsSplit(n)`.
   integer(c_int), intent(in) :: n !< Channels.

   call ImDrawList_ChannelsSplit(igGetWindowDrawList(), n)
   endsubroutine cl_channels_split

   subroutine cl_channels_set(k)
   !< `GetWindowDrawList()->ChannelsSetCurrent(k)`.
   integer(c_int), intent(in) :: k !< Channel, 0-based.

   call ImDrawList_ChannelsSetCurrent(igGetWindowDrawList(), k)
   endsubroutine cl_channels_set

   subroutine cl_channels_merge()
   !< `GetWindowDrawList()->ChannelsMerge()`.
   call ImDrawList_ChannelsMerge(igGetWindowDrawList())
   endsubroutine cl_channels_merge

   function cl_vtx_count() result(n)
   !< The vertices of the window's draw list (`VtxBuffer.Size`).
   integer(c_int) :: n !< Vertices.

   n = fig_core_vtx_count()
   endfunction cl_vtx_count

   subroutine cl_vtx_shift(start, dx)
   !< The vertices of the window's draw list from `start` (0-based) moved right by dx.
   integer(c_int), intent(in) :: start !< First vertex.
   real(c_float),  intent(in) :: dx    !< Shift.

   call fig_core_vtx_shift(start, dx)
   endsubroutine cl_vtx_shift

   ! ---- items and input ----------------------------------------------------------------------------------------------
   function cl_item_hovered(flags) result(yes)
   !< `IsItemHovered(flags)` (default 0).
   integer(c_int), intent(in), optional :: flags !< `ImGuiHoveredFlags_*`.
   logical                              :: yes   !< Hovered.

   if (present(flags)) then
      yes = logical(igIsItemHovered(flags))
   else
      yes = logical(igIsItemHovered(0_c_int))
   endif
   endfunction cl_item_hovered

   subroutine cl_set_mouse_cursor(cursor)
   !< `SetMouseCursor`.
   integer(c_int), intent(in) :: cursor !< `ImGuiMouseCursor_*`.

   call igSetMouseCursor(cursor)
   endsubroutine cl_set_mouse_cursor

   subroutine cl_tooltip(p, n)
   !< `SetTooltip("%s", text)`, the text of n bytes at p.
   type(c_ptr),    intent(in) :: p !< Text.
   integer(c_int), intent(in) :: n !< Bytes.

   call fig_core_tooltip(p, n)
   endsubroutine cl_tooltip

   function cl_mouse_clicked(button) result(yes)
   !< `IsMouseClicked(button)`.
   integer(c_int), intent(in) :: button !< Button.
   logical                    :: yes    !< Clicked.

   yes = logical(igIsMouseClicked_Bool(button, .false._c_bool))
   endfunction cl_mouse_clicked

   function cl_mouse_released(button) result(yes)
   !< `IsMouseReleased(button)`.
   integer(c_int), intent(in) :: button !< Button.
   logical                    :: yes    !< Released.

   yes = logical(igIsMouseReleased_Nil(button))
   endfunction cl_mouse_released

   function cl_mouse_drag_past(button) result(yes)
   !< `IsMouseDragPastThreshold(button)`.
   integer(c_int), intent(in) :: button !< Button.
   logical                    :: yes    !< Dragged past the threshold.

   yes = logical(igIsMouseDragPastThreshold(button, -1.0_c_float))
   endfunction cl_mouse_drag_past

   subroutine cl_image(tex_id, w, h, u0, v0, u1, v1)
   !< `Image(ImTextureRef(tex_id), ImVec2(w, h), ImVec2(u0, v0), ImVec2(u1, v1))`.
   integer(c_long_long), intent(in) :: tex_id         !< A texture's id.
   real(c_float),        intent(in) :: w, h           !< Size.
   real(c_float),        intent(in) :: u0, v0, u1, v1 !< Texture coordinates.

   call igImage(im_texture_ref(c_null_ptr, tex_id), im_vec2(w, h), im_vec2(u0, v0), im_vec2(u1, v1))
   endsubroutine cl_image

   ! ---- tables, IDs, groups ------------------------------------------------------------------------------------------
   function cl_begin_table(id, columns, flags) result(open)
   !< `BeginTable(id, columns, flags)`.
   character(len=*), intent(in) :: id      !< ID.
   integer(c_int),   intent(in) :: columns !< Columns.
   integer(c_int),   intent(in) :: flags   !< `ImGuiTableFlags_*`.
   logical                      :: open    !< Open (then `cl_end_table`).

   open = logical(igBeginTable(id//c_null_char, columns, flags, im_vec2(0.0_c_float, 0.0_c_float), 0.0_c_float))
   endfunction cl_begin_table

   subroutine cl_end_table()
   !< `EndTable`.
   call igEndTable()
   endsubroutine cl_end_table

   subroutine cl_table_next_row()
   !< `TableNextRow`.
   call igTableNextRow(0_c_int, 0.0_c_float)
   endsubroutine cl_table_next_row

   subroutine cl_table_next_column()
   !< `TableNextColumn`.
   if (igTableNextColumn()) continue
   endsubroutine cl_table_next_column

   subroutine cl_push_id_int(i)
   !< `PushID(int)`.
   integer(c_int), intent(in) :: i !< ID.

   call igPushID_Int(i)
   endsubroutine cl_push_id_int

   subroutine cl_push_id(p, n)
   !< `PushID(p, p + n)`.
   type(c_ptr),    intent(in) :: p !< Text.
   integer(c_int), intent(in) :: n !< Bytes.
   character(kind=c_char), pointer :: s(:), e(:) !< The text, its end.

   call c_f_pointer(p, s, [max(n, 1_c_int)])
   call c_f_pointer(cl_ptr_add(p, n), e, [1])
   call igPushID_StrStr(s, e)
   endsubroutine cl_push_id

   subroutine cl_pop_id()
   !< `PopID`.
   call igPopID()
   endsubroutine cl_pop_id

   function cl_get_id(label) result(id)
   !< `GetID(label)`.
   character(len=*), intent(in) :: label !< Label.
   integer(c_int)               :: id    !< ID.

   id = igGetID_Str(label//c_null_char)
   endfunction cl_get_id

   subroutine cl_begin_group()
   !< `BeginGroup`.
   call igBeginGroup()
   endsubroutine cl_begin_group

   subroutine cl_end_group()
   !< `EndGroup`.
   call igEndGroup()
   endsubroutine cl_end_group

   ! ---- collapsing headers, the window, its storage --------------------------------------------------------------------
   function cl_collapsing_header(label) result(open)
   !< `CollapsingHeader(label)`.
   character(len=*), intent(in) :: label !< Label.
   logical                      :: open  !< Open.

   open = logical(igCollapsingHeader_TreeNodeFlags(label//c_null_char, 0_c_int))
   endfunction cl_collapsing_header

   subroutine cl_set_next_item_open(open, cond)
   !< `SetNextItemOpen(open, cond)`.
   logical,        intent(in) :: open !< Open.
   integer(c_int), intent(in) :: cond !< `ImGuiCond_*`.

   call igSetNextItemOpen(logical(open, c_bool), cond)
   endsubroutine cl_set_next_item_open

   subroutine cl_window_pos(x, y)
   !< `GetWindowPos`.
   real(c_float), intent(out) :: x, y !< Position.
   type(im_vec2)              :: v    !< Value.

   v = igGetWindowPos()
   x = v%x
   y = v%y
   endsubroutine cl_window_pos

   function cl_scroll_y() result(y)
   !< `GetScrollY`.
   real(c_float) :: y !< Scroll.

   y = igGetScrollY()
   endfunction cl_scroll_y

   subroutine cl_set_scroll_y(y)
   !< `SetScrollY(y)`.
   real(c_float), intent(in) :: y !< Scroll.

   call igSetScrollY_Float(y)
   endsubroutine cl_set_scroll_y

   subroutine cl_window_state(s)
   !< The current window's state: position (1, 2), scroll (3, 4), largest scroll (5, 6), the decorations above its
   !< content (7: DecoOuterSizeY1, 8: DecoInnerSizeY1), its work rectangle's right edge (9), size (10, 11), a vertical
   !< scrollbar (12: 0 or 1), its content's start in the window (13, 14).
   real(c_float), intent(out) :: s(14) !< State.

   call fig_core_window_state(s)
   endsubroutine cl_window_state

   function cl_storage_get_int(id, default) result(v)
   !< `GetStateStorage()->GetInt(id, default)`.
   integer(c_int), intent(in) :: id      !< Key.
   integer(c_int), intent(in) :: default !< Default.
   integer(c_int)             :: v       !< Value.

   v = ImGuiStorage_GetInt(igGetStateStorage(), id, default)
   endfunction cl_storage_get_int

   subroutine cl_storage_set_int(id, v)
   !< `GetStateStorage()->SetInt(id, v)`.
   integer(c_int), intent(in) :: id !< Key.
   integer(c_int), intent(in) :: v  !< Value.

   call ImGuiStorage_SetInt(igGetStateStorage(), id, v)
   endsubroutine cl_storage_set_int

   ! ---- child windows and buttons ------------------------------------------------------------------------------------
   function cl_begin_child(id, w, h, child_flags, window_flags) result(open)
   !< `BeginChild(id, ImVec2(w, h), child_flags, window_flags)`: end it with `cl_end_child`, open or not.
   character(len=*), intent(in) :: id           !< ID.
   real(c_float),    intent(in) :: w, h         !< Size.
   integer(c_int),   intent(in) :: child_flags  !< `ImGuiChildFlags_*`.
   integer(c_int),   intent(in) :: window_flags !< `ImGuiWindowFlags_*`.
   logical                      :: open         !< Open.

   open = logical(igBeginChild_Str(id//c_null_char, im_vec2(w, h), child_flags, window_flags))
   endfunction cl_begin_child

   subroutine cl_end_child()
   !< `EndChild`.
   call igEndChild()
   endsubroutine cl_end_child

   function cl_small_button(label) result(pressed)
   !< `SmallButton(label)`.
   character(len=*), intent(in) :: label   !< Label.
   logical                      :: pressed !< Pressed.

   pressed = logical(igSmallButton(label//c_null_char))
   endfunction cl_small_button

   subroutine cl_set_clipboard(p, n)
   !< `SetClipboardText`, the text of n bytes at p.
   type(c_ptr),    intent(in) :: p !< Text.
   integer(c_int), intent(in) :: n !< Bytes.
   character(kind=c_char), pointer :: s(:)   !< The text.
   character(kind=c_char), allocatable :: z(:) !< ... NUL-terminated.

   allocate(z(n + 1_c_int))
   if (n > 0_c_int) then
      call c_f_pointer(p, s, [n])
      z(1:n) = s
   endif
   z(n + 1_c_int) = c_null_char
   call igSetClipboardText(z)
   endsubroutine cl_set_clipboard
   ! ---- the mouse, the keys, the active item (a text selection) -------------------------------------------------------
   subroutine cl_mouse_pos(x, y)
   !< `GetMousePos`.
   real(c_float), intent(out) :: x, y !< Position.
   type(im_vec2)              :: v    !< Value.

   v = igGetMousePos()
   x = v%x
   y = v%y
   endsubroutine cl_mouse_pos

   function cl_mouse_down(button) result(yes)
   !< `IsMouseDown(button)`.
   integer(c_int), intent(in) :: button !< Button.
   logical                    :: yes    !< Down.

   yes = logical(igIsMouseDown_Nil(button))
   endfunction cl_mouse_down

   function cl_mouse_pos_valid() result(yes)
   !< `IsMousePosValid()`.
   logical :: yes !< Valid.

   yes = logical(igIsMousePosValid(c_null_ptr))
   endfunction cl_mouse_pos_valid

   function cl_mouse_clicked_count(button) result(n)
   !< `GetMouseClickedCount(button)`.
   integer(c_int), intent(in) :: button !< Button.
   integer(c_int)             :: n      !< Clicks.

   n = igGetMouseClickedCount(button)
   endfunction cl_mouse_clicked_count

   function cl_window_hovered(flags) result(yes)
   !< `IsWindowHovered(flags)`.
   integer(c_int), intent(in) :: flags !< `ImGuiHoveredFlags_*`.
   logical                    :: yes   !< Hovered.

   yes = logical(igIsWindowHovered(flags))
   endfunction cl_window_hovered

   function cl_window_focused(flags) result(yes)
   !< `IsWindowFocused(flags)`.
   integer(c_int), intent(in) :: flags !< `ImGuiFocusedFlags_*`.
   logical                    :: yes   !< Focused.

   yes = logical(igIsWindowFocused(flags))
   endfunction cl_window_focused

   function cl_any_item_hovered() result(yes)
   !< `IsAnyItemHovered`.
   logical :: yes !< Hovered.

   yes = logical(igIsAnyItemHovered())
   endfunction cl_any_item_hovered

   function cl_active_id() result(id)
   !< `GImGui->ActiveId`.
   integer(c_int) :: id !< ID.

   id = igGetActiveID()
   endfunction cl_active_id

   subroutine cl_set_active_id(id, focus)
   !< `SetActiveID(id, GImGui->CurrentWindow)`, and with `focus` `FocusWindow(GImGui->CurrentWindow)`.
   integer(c_int), intent(in) :: id    !< ID.
   logical,        intent(in) :: focus !< Focus the window too.

   call igSetActiveID(id, igGetCurrentWindow())
   if (focus) call igFocusWindow(igGetCurrentWindow(), 0_c_int)
   endsubroutine cl_set_active_id

   subroutine cl_keep_alive(id)
   !< `KeepAliveID`.
   integer(c_int), intent(in) :: id !< ID.

   call igKeepAliveID(id)
   endsubroutine cl_keep_alive

   subroutine cl_clear_active_id()
   !< `ClearActiveID`.
   call igClearActiveID()
   endsubroutine cl_clear_active_id

   function cl_key_chord_pressed(chord) result(yes)
   !< `IsKeyChordPressed(chord, ImGuiInputFlags_None)` (imgui_internal.h's, owner 0).
   integer(c_int), intent(in) :: chord !< `ImGuiKey_*` with `ImGuiMod_*`.
   logical                    :: yes   !< Pressed.

   yes = logical(igIsKeyChordPressed_InputFlags(chord, 0_c_int, 0_c_int))
   endfunction cl_key_chord_pressed

   subroutine cl_io_state(clicked_x, clicked_y, wheel, delta_x, mac, want_text, touch, shift, chars, slash)
   !< The input state no C API function gives: where the last left click was (`io.MouseClickedPos[0]`), the wheel, the
   !< mouse's move in x, macOS behaviours, a text field wanting the keys (`io.WantTextInput`), a touch screen, shift
   !< held, the characters typed this frame and a slash among them.
   real(c_float),  intent(out) :: clicked_x, clicked_y, wheel, delta_x !< Values.
   logical,        intent(out) :: mac, want_text, touch, shift, slash  !< Flags.
   integer(c_int), intent(out) :: chars                                 !< Characters typed.
   real(c_float)               :: f(4) !< Values.
   integer(c_int)              :: i(6) !< Flags.

   call fig_core_io_state(f, i)
   clicked_x = f(1)
   clicked_y = f(2)
   wheel = f(3)
   delta_x = f(4)
   mac = i(1) /= 0_c_int
   want_text = i(2) /= 0_c_int
   touch = i(3) /= 0_c_int
   shift = i(4) /= 0_c_int
   chars = i(5)
   slash = i(6) /= 0_c_int
   endsubroutine cl_io_state

   ! ---- popups and menus ---------------------------------------------------------------------------------------------
   subroutine cl_open_popup(id)
   !< `OpenPopup(id)`.
   character(len=*), intent(in) :: id !< Popup.

   if (igOpenPopup_Str(id//c_null_char, 0_c_int)) continue
   endsubroutine cl_open_popup

   function cl_begin_popup(id) result(open)
   !< `BeginPopup(id)`: `cl_end_popup` when true.
   character(len=*), intent(in) :: id   !< Popup.
   logical                      :: open !< Open.

   open = logical(igBeginPopup(id//c_null_char, 0_c_int))
   endfunction cl_begin_popup

   subroutine cl_end_popup()
   !< `EndPopup`.
   call igEndPopup()
   endsubroutine cl_end_popup

   function cl_menu_item(label, shortcut, selected, enabled) result(pressed)
   !< `MenuItem(label, shortcut, selected, enabled)` (`shortcut` '': none).
   character(len=*), intent(in) :: label    !< Label.
   character(len=*), intent(in) :: shortcut !< Shortcut shown.
   logical,          intent(in) :: selected !< Checked.
   logical,          intent(in) :: enabled  !< Enabled.
   logical                      :: pressed  !< Chosen.
   character(kind=c_char, len=len(shortcut) + 1), target :: sc !< NUL-terminated shortcut.

   if (len(shortcut) == 0) then
      pressed = logical(igMenuItem_Bool(label//c_null_char, c_null_ptr, logical(selected, c_bool), logical(enabled, c_bool)))
   else
      sc = shortcut//c_null_char
      pressed = logical(igMenuItem_Bool(label//c_null_char, c_loc(sc), logical(selected, c_bool), logical(enabled, c_bool)))
   endif
   endfunction cl_menu_item

   subroutine cl_separator_item()
   !< `Separator`, in a menu.
   call igSeparator()
   endsubroutine cl_separator_item

   function cl_rect_visible(x0, y0, x1, y1) result(yes)
   !< `IsRectVisible(ImVec2(x0, y0), ImVec2(x1, y1))`.
   real(c_float), intent(in) :: x0, y0, x1, y1 !< Rectangle.
   logical                   :: yes            !< Visible.

   yes = logical(igIsRectVisible_Vec2(im_vec2(x0, y0), im_vec2(x1, y1)))
   endfunction cl_rect_visible

   function cl_hash_str(p, n) result(h)
   !< `ImHashStr(p, n)`.
   type(c_ptr),    intent(in) :: p !< Text.
   integer(c_int), intent(in) :: n !< Bytes.
   integer(c_int)             :: h !< Hash.

   h = igImHashStr(p, int(n, c_size_t), 0_c_int)
   endfunction cl_hash_str

   function cl_float4_to_u32(rgba) result(col)
   !< `ColorConvertFloat4ToU32` (an `ImColor` drawn: no style Alpha).
   real(c_float), intent(in) :: rgba(4) !< Colour.
   integer(c_int)            :: col     !< Packed.

   col = igColorConvertFloat4ToU32(im_vec4(rgba(1), rgba(2), rgba(3), rgba(4)))
   endfunction cl_float4_to_u32

   function cl_font_text_width(font, size, p, n) result(w)
   !< `font->CalcTextSizeA(size, FLT_MAX, 0, p, p + n).x`.
   type(c_ptr),    intent(in) :: font !< C `ImFont*`.
   real(c_float),  intent(in) :: size !< Size.
   type(c_ptr),    intent(in) :: p    !< Text.
   integer(c_int), intent(in) :: n    !< Bytes.
   real(c_float)              :: w    !< Width.
   type(im_vec2)              :: v    !< Size.

   v = ImFont_CalcTextSizeA(font, size, huge(1.0_c_float), 0.0_c_float, p, cl_ptr_add(p, n), c_null_ptr)
   w = v%x
   endfunction cl_font_text_width

   function cl_utf8_length(p, n) result(k)
   !< The bytes of the character at p (`ImTextCharFromUtf8`, at most n).
   type(c_ptr),    intent(in) :: p !< Text.
   integer(c_int), intent(in) :: n !< Bytes left.
   integer(c_int)             :: k !< Bytes of the character.
   integer(c_int)             :: c !< The character.

   k = igImTextCharFromUtf8(c, p, cl_ptr_add(p, n))
   endfunction cl_utf8_length

   function cl_frame_count() result(n)
   !< `GetFrameCount`.
   integer(c_int) :: n !< Frames.

   n = igGetFrameCount()
   endfunction cl_frame_count

   ! ---- a splitter of the window's draw list -------------------------------------------------------------------------
   subroutine cl_splitter_split(n)
   !< The client's splitter: `Split(GetWindowDrawList(), n)`.
   integer(c_int), intent(in) :: n !< Channels.

   if (.not. c_associated(splitter)) splitter = ImDrawListSplitter_ImDrawListSplitter()
   call ImDrawListSplitter_Split(splitter, igGetWindowDrawList(), n)
   endsubroutine cl_splitter_split

   subroutine cl_splitter_set(k)
   !< The client's splitter: `SetCurrentChannel(GetWindowDrawList(), k)`.
   integer(c_int), intent(in) :: k !< Channel, 0-based.

   call ImDrawListSplitter_SetCurrentChannel(splitter, igGetWindowDrawList(), k)
   endsubroutine cl_splitter_set

   subroutine cl_splitter_merge()
   !< The client's splitter: `Merge(GetWindowDrawList())`.
   call ImDrawListSplitter_Merge(splitter, igGetWindowDrawList())
   endsubroutine cl_splitter_merge
   ! ---- the documents' widgets (#15 P15, step 71) ------------------------------------------------------------------------
   subroutine cl_set_next_window_focus()
   !< `SetNextWindowFocus`.
   call igSetNextWindowFocus()
   endsubroutine cl_set_next_window_focus

   function cl_button(label, w, h) result(pressed)
   !< `Button(label, ImVec2(w, h))`.
   character(len=*), intent(in) :: label   !< Label.
   real(c_float),    intent(in) :: w, h    !< Size.
   logical                      :: pressed !< Pressed.

   pressed = logical(igButton(label//c_null_char, im_vec2(w, h)))
   endfunction cl_button

   function cl_arrow_button(id, dir) result(pressed)
   !< `ArrowButton(id, dir)`.
   character(len=*), intent(in) :: id      !< ID.
   integer(c_int),   intent(in) :: dir     !< `ImGuiDir_*`.
   logical                      :: pressed !< Pressed.

   pressed = logical(igArrowButton(id//c_null_char, dir))
   endfunction cl_arrow_button

   function cl_find_field(label, hint, buf, step, dropdown, select_query) result(changed)
   !< imgui_rich_md's find field: `InputTextWithHint(label, hint, buf, size(buf), CallbackHistory | CallbackAlways)`
   !< with its callback: the up and down arrows set `step` (-1, 1), the down arrow opens the list (`dropdown`), the
   !< text is selected at the first callback while `select_query`.
   character(len=*),               intent(in)            :: label        !< Label.
   character(len=*),               intent(in)            :: hint         !< Hint.
   character(kind=c_char), target, intent(inout)         :: buf(:)       !< The text, NUL-terminated.
   integer(c_int),                 intent(inout)         :: step         !< Step.
   logical,                        intent(inout)         :: dropdown     !< The list asked.
   logical,                        intent(inout)         :: select_query !< Select the text.
   logical                                               :: changed      !< The text changed.
   integer(c_int)                                        :: d, q         !< Flags (C).

   d = merge(1_c_int, 0_c_int, dropdown)
   q = merge(1_c_int, 0_c_int, select_query)
   changed = fig_core_find_field(label//c_null_char, hint//c_null_char, c_loc(buf), size(buf, kind=c_int), step, d, q) &
             /= 0_c_int
   dropdown = d /= 0_c_int
   select_query = q /= 0_c_int
   endfunction cl_find_field

   function cl_item_active() result(yes)
   !< `IsItemActive`.
   logical :: yes !< Active.

   yes = logical(igIsItemActive())
   endfunction cl_item_active

   function cl_item_deactivated() result(yes)
   !< `IsItemDeactivated`.
   logical :: yes !< Deactivated.

   yes = logical(igIsItemDeactivated())
   endfunction cl_item_deactivated

   function cl_key_pressed(key) result(yes)
   !< `IsKeyPressed(key)` (repeating).
   integer(c_int), intent(in) :: key !< `ImGuiKey_*`.
   logical                    :: yes !< Pressed.

   yes = logical(igIsKeyPressed_Bool(key, .true._c_bool))
   endfunction cl_key_pressed

   subroutine cl_align_text_to_frame_padding()
   !< `AlignTextToFramePadding`.
   call igAlignTextToFramePadding()
   endsubroutine cl_align_text_to_frame_padding

   function cl_checkbox(label, v) result(changed)
   !< `Checkbox(label, &v)`.
   character(len=*), intent(in)    :: label   !< Label.
   logical,          intent(inout) :: v       !< Value.
   logical                         :: changed !< Changed.
   logical(c_bool), target         :: b       !< Value (C).

   b = logical(v, c_bool)
   changed = logical(igCheckbox(label//c_null_char, c_loc(b)))
   v = logical(b)
   endfunction cl_checkbox

   function cl_selectable(label, selected, flags, w, h) result(pressed)
   !< `Selectable(label, selected, flags, ImVec2(w, h))`.
   character(len=*), intent(in) :: label    !< Label.
   logical,          intent(in) :: selected !< Selected.
   integer(c_int),   intent(in) :: flags    !< `ImGuiSelectableFlags_*`.
   real(c_float),    intent(in) :: w, h     !< Size.
   logical                      :: pressed  !< Pressed.

   pressed = logical(igSelectable_Bool(label//c_null_char, logical(selected, c_bool), flags, im_vec2(w, h)))
   endfunction cl_selectable

   subroutine cl_set_scroll_here_y(ratio)
   !< `SetScrollHereY(ratio)`.
   real(c_float), intent(in) :: ratio !< Where.

   call igSetScrollHereY(ratio)
   endsubroutine cl_set_scroll_here_y

   function cl_window_appearing() result(yes)
   !< `IsWindowAppearing`.
   logical :: yes !< Appearing.

   yes = logical(igIsWindowAppearing())
   endfunction cl_window_appearing

   subroutine cl_draw_text(x, y, col, text)
   !< `GetWindowDrawList()->AddText(ImVec2(x, y), col, text)`.
   real(c_float),    intent(in) :: x, y !< Position.
   integer(c_int),   intent(in) :: col  !< Colour.
   character(len=*), intent(in) :: text !< Text.

   if (len(text) == 0) return
   call ImDrawList_AddText_Vec2(igGetWindowDrawList(), im_vec2(x, y), col, text//c_null_char, c_null_ptr)
   endsubroutine cl_draw_text

   subroutine cl_draw_circle(x, y, radius, col, filled, thickness)
   !< `GetWindowDrawList()->AddCircle(ImVec2(x, y), radius, col, 0, thickness)` or `AddCircleFilled`.
   real(c_float),  intent(in) :: x, y, radius !< Circle.
   integer(c_int), intent(in) :: col          !< Colour.
   logical,        intent(in) :: filled       !< Filled.
   real(c_float),  intent(in) :: thickness    !< Thickness (outline).

   if (filled) then
      call ImDrawList_AddCircleFilled(igGetWindowDrawList(), im_vec2(x, y), radius, col, 0_c_int)
   else
      call ImDrawList_AddCircle(igGetWindowDrawList(), im_vec2(x, y), radius, col, 0_c_int, thickness, 0_c_int)
   endif
   endsubroutine cl_draw_circle

   function cl_begin_tooltip() result(open)
   !< `BeginTooltip`: `cl_end_tooltip` when true.
   logical :: open !< Open.

   open = logical(igBeginTooltip())
   endfunction cl_begin_tooltip

   subroutine cl_end_tooltip()
   !< `EndTooltip`.
   call igEndTooltip()
   endsubroutine cl_end_tooltip

   subroutine cl_set_next_window_pos(x, y, cond, px, py)
   !< `SetNextWindowPos(ImVec2(x, y), cond, ImVec2(px, py))`.
   real(c_float),  intent(in) :: x, y   !< Position.
   integer(c_int), intent(in) :: cond   !< `ImGuiCond_*`.
   real(c_float),  intent(in) :: px, py !< Pivot.

   call igSetNextWindowPos(im_vec2(x, y), cond, im_vec2(px, py))
   endsubroutine cl_set_next_window_pos

   subroutine cl_scrollbar_rect(x0, y0, x1, y1)
   !< The current window's vertical scrollbar (`GetWindowScrollbarRect(window, ImGuiAxis_Y)`).
   real(c_float), intent(out) :: x0, y0, x1, y1 !< Rectangle.
   real(c_float)              :: r(4)           !< Values.

   call fig_core_scrollbar_rect(r)
   x0 = r(1)
   y0 = r(2)
   x1 = r(3)
   y1 = r(4)
   endsubroutine cl_scrollbar_rect

   subroutine cl_push_clip_rect(x0, y0, x1, y1)
   !< `GetWindowDrawList()->PushClipRect(ImVec2(x0, y0), ImVec2(x1, y1))` (not intersected).
   real(c_float), intent(in) :: x0, y0, x1, y1 !< Rectangle.

   call ImDrawList_PushClipRect(igGetWindowDrawList(), im_vec2(x0, y0), im_vec2(x1, y1), .false._c_bool)
   endsubroutine cl_push_clip_rect

   subroutine cl_pop_clip_rect()
   !< `GetWindowDrawList()->PopClipRect()`.
   call ImDrawList_PopClipRect(igGetWindowDrawList())
   endsubroutine cl_pop_clip_rect

   function cl_mouse_hovering_rect(x0, y0, x1, y1, clip) result(yes)
   !< `IsMouseHoveringRect(ImVec2(x0, y0), ImVec2(x1, y1), clip)`.
   real(c_float), intent(in) :: x0, y0, x1, y1 !< Rectangle.
   logical,       intent(in) :: clip           !< Clipped by the window.
   logical                   :: yes            !< Hovered.

   yes = logical(igIsMouseHoveringRect(im_vec2(x0, y0), im_vec2(x1, y1), logical(clip, c_bool)))
   endfunction cl_mouse_hovering_rect

   subroutine cl_close_current_popup()
   !< `CloseCurrentPopup`.
   call igCloseCurrentPopup()
   endsubroutine cl_close_current_popup

   function cl_begin_tab_bar(id) result(open)
   !< `BeginTabBar(id)`: `cl_end_tab_bar` when true.
   character(len=*), intent(in) :: id   !< ID.
   logical                      :: open !< Open.

   open = logical(igBeginTabBar(id//c_null_char, 0_c_int))
   endfunction cl_begin_tab_bar

   subroutine cl_end_tab_bar()
   !< `EndTabBar`.
   call igEndTabBar()
   endsubroutine cl_end_tab_bar

   function cl_begin_tab_item(label) result(open)
   !< `BeginTabItem(label)`: `cl_end_tab_item` when true.
   character(len=*), intent(in) :: label !< Label.
   logical                      :: open  !< Selected.

   open = logical(igBeginTabItem(label//c_null_char, c_null_ptr, 0_c_int))
   endfunction cl_begin_tab_item

   subroutine cl_end_tab_item()
   !< `EndTabItem`.
   call igEndTabItem()
   endsubroutine cl_end_tab_item

   function cl_begin_combo(label, preview, flags) result(open)
   !< `BeginCombo(label, preview, flags)`: `cl_end_combo` when true.
   character(len=*), intent(in) :: label   !< Label.
   character(len=*), intent(in) :: preview !< Preview.
   integer(c_int),   intent(in) :: flags   !< `ImGuiComboFlags_*`.
   logical                      :: open    !< Open.

   open = logical(igBeginCombo(label//c_null_char, preview//c_null_char, flags))
   endfunction cl_begin_combo

   subroutine cl_end_combo()
   !< `EndCombo`.
   call igEndCombo()
   endsubroutine cl_end_combo

   subroutine cl_set_next_item_width(w)
   !< `SetNextItemWidth(w)`.
   real(c_float), intent(in) :: w !< Width.

   call igSetNextItemWidth(w)
   endsubroutine cl_set_next_item_width

   function cl_shortcut(chord) result(yes)
   !< `Shortcut(chord)`: routed to the focused window and its parents.
   integer(c_int), intent(in) :: chord !< Key chord.
   logical                    :: yes   !< Pressed.

   yes = logical(igShortcut_Nil(chord, 0_c_int))
   endfunction cl_shortcut

   function cl_invisible_button(id, w, h) result(pressed)
   !< `InvisibleButton(id, ImVec2(w, h))`.
   character(len=*), intent(in) :: id      !< ID.
   real(c_float),    intent(in) :: w, h    !< Size.
   logical                      :: pressed !< Pressed.

   pressed = logical(igInvisibleButton(id//c_null_char, im_vec2(w, h), 0_c_int))
   endfunction cl_invisible_button

   function cl_window_height() result(h)
   !< `GetWindowHeight`.
   real(c_float) :: h !< Height.

   h = igGetWindowHeight()
   endfunction cl_window_height

   subroutine cl_set_keyboard_focus_here()
   !< `SetKeyboardFocusHere()`.
   call igSetKeyboardFocusHere(0_c_int)
   endsubroutine cl_set_keyboard_focus_here

   function cl_item_visible() result(yes)
   !< `IsItemVisible`.
   logical :: yes !< Visible.

   yes = logical(igIsItemVisible())
   endfunction cl_item_visible

   subroutine cl_set_cursor_screen_pos(x, y)
   !< `SetCursorScreenPos`.
   real(c_float), intent(in) :: x, y !< Position, on the screen.

   call igSetCursorScreenPos(im_vec2(x, y))
   endsubroutine cl_set_cursor_screen_pos

   function cl_time() result(t)
   !< `GetTime`.
   real(c_double) :: t !< Seconds.

   t = igGetTime()
   endfunction cl_time
endmodule figure_core_layout
