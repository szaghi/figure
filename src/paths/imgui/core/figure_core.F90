!< figure_core, the inner seam: what the layers above the core need from it (implementation over Dear ImGui).
module figure_core
!< figure_core, the inner seam: what the layers above the core need from it (implementation over Dear ImGui).
!<
!< szaghi/figure#15 P8. The layers above the core (plots, 3-D plots, gizmos, Markdown, the code editor: block D) are to
!< talk to this interface only; it has two implementations under the same module name, chosen by a build mode's `src`
!< (#15 §2): this one, `src/paths/imgui/core/`, a thin layer over Dear ImGui through the generated bindings
!< (figure_cimgui, figure_cimgui_core), with no behaviour of its own; and the Fortran core of block E, later, in
!< `src/paths/fortran/core/`. The groups, from what ImPlot, ImPlot3D, ImGuizmo, imgui_rich_md and ImGuiColorTextEdit call
!< (the inventory of P8's log):
!<
!< - IDs and the ID stack: `core_get_id`, `core_push_id`, `core_pop_id`;
!< - items and their behaviour: `core_item_size`, `core_item_add`, `core_button_behavior`, `core_keep_alive`,
!<   `core_item_hovered`, `core_item_active`, `core_active_id`, `core_hovered_id`;
!< - the window and the frame: `core_cursor_screen_pos`, `core_set_cursor_screen_pos`, `core_content_region_avail`,
!<   `core_window_pos`, `core_window_size`, `core_frame_count`, `core_time`, `core_font_size`, `core_frame_height`,
!<   `core_text_size`;
!< - style: `core_style_color` (a style colour as a packed colour), `core_style_var` (a style variable by its
!<   `ImGuiStyle` name), `core_color` (a colour packed as Dear ImGui packs it);
!< - input: `core_mouse_pos`, `core_mouse_down`, `core_mouse_clicked`, `core_mouse_released`,
!<   `core_mouse_hovering_rect`, `core_key_down`, `core_key_pressed`;
!< - the draw list: `core_draw_begin` (the current window's), then lines, rectangles, triangles, convex polygons,
!<   polylines, circles, text, images, clip rectangles and callbacks, and `core_draw_end`; for the plot frame
!<   (src/paths/fortran/plot/), Dear ImGui 1.93's axis-aligned lines (`core_draw_line_h`, `core_draw_line_v`), a
!<   line's texture (`core_line_texture`) and a textured quad (`core_draw_quad_uv`), thin wrappers of the list's calls.
!<
!< The draw list is built in Fortran (figure_drawlist, the first piece of block E) and appended to the window's Dear
!< ImGui list by `core_draw_end`: the primitives figure_drawlist tessellates (filled rectangles without rounding,
!< lines, filled triangles and convex polygons) are kept there; the others (rounded rectangles, outlines, polylines,
!< circles, text, images, clip rectangles, callbacks) are drawn by Dear ImGui's list after what is pending was appended,
!< so the order of the primitives is the order of the calls. Coordinates are screen pixels (`real(real64)`, as the
!< public API's); colours are packed `ImU32` in an `integer(int32)`, red in the low byte (`core_color`).
!<
!< No allocation per item: text and IDs go through a buffer of the module (NUL-terminated copies; a longer text gets
!< an allocated copy).
use, intrinsic :: iso_c_binding, only : c_associated, c_bool, c_char, c_float, c_funptr, c_int, c_int32_t, c_loc, &
                                         c_null_char, c_null_ptr, c_ptr, c_size_t
use, intrinsic :: iso_fortran_env, only : int32, int64, real64
use figure_cimgui, only : im_rect, im_texture_ref, im_vec2, im_vec4, igCalcTextSize, igGetColorU32_Col,             &
                          igGetContentRegionAvail, igGetCursorScreenPos, igGetFontSize, igGetFrameCount, igGetFrameHeight, &
                          igGetID_Str, igGetMousePos, igGetTime, igGetWindowDrawList, igGetWindowPos, igGetWindowSize,     &
                          igIsItemActive, igIsItemHovered, igIsKeyDown_Nil, igIsKeyPressed_Bool, igIsMouseClicked_Bool,    &
                          igIsMouseDown_Nil, igIsMouseHoveringRect, igIsMouseReleased_Nil, igPopID, igPushID_Str,          &
                          igSetCursorScreenPos
use figure_cimgui_enums, only : ImDrawFlags_Closed
use figure_cimgui_core, only : figure_ImDrawList_append, figure_ImDrawList_shared, igButtonBehavior, igGetActiveID,         &
                               igGetHoveredID, igItemAdd, igItemSize_Vec2, igKeepAliveID, ImDrawList_AddCallback,          &
                               ImDrawList_AddCircle, ImDrawList_AddCircleFilled, ImDrawList_AddImage, ImDrawList_AddPolyline, &
                               ImDrawList_AddRect, ImDrawList_AddRectFilled, ImDrawList_AddText_Vec2, ImDrawList_PopClipRect, &
                               ImDrawList_PrimReserve, ImDrawList_PushClipRect
use figure_style, only : ig_get_style_var
use figure_drawlist, only : draw_list, dl_batch, dl_convex_poly_filled, dl_line, dl_rect_filled, dl_reset, dl_set_state, &
                            dl_triangle_filled, DL_LINE_TEXTURES

implicit none
private
public :: core_get_id, core_push_id, core_pop_id
public :: core_item_size, core_item_add, core_button_behavior, core_keep_alive, core_item_hovered, core_item_active
public :: core_active_id, core_hovered_id
public :: core_cursor_screen_pos, core_set_cursor_screen_pos, core_content_region_avail, core_window_pos, core_window_size
public :: core_frame_count, core_time, core_font_size, core_frame_height, core_text_size
public :: core_style_color, core_style_var, core_color
public :: core_mouse_pos, core_mouse_down, core_mouse_clicked, core_mouse_released, core_mouse_hovering_rect
public :: core_key_down, core_key_pressed
public :: core_draw_begin, core_draw_end, core_draw_line, core_draw_rect_filled, core_draw_rect, core_draw_triangle_filled
public :: core_draw_convex_poly_filled, core_draw_polyline, core_draw_circle, core_draw_text, core_draw_image
public :: core_push_clip_rect, core_pop_clip_rect, core_draw_callback
public :: core_draw_line_h, core_draw_line_v, core_line_texture, core_draw_quad_uv
public :: core_draw_list

integer(int32), parameter :: BUF_LEN = 4096_int32 !< Text copied into the module's buffer up to this length.

character(kind=c_char, len=BUF_LEN + 1), target :: buf  !< NUL-terminated copy of a text or an ID.
type(draw_list), target                         :: list !< The Fortran draw list (`core_draw_begin` .. `core_draw_end`).
type(c_ptr)                                     :: target_list = c_null_ptr !< The Dear ImGui list it goes to.

interface
   ! cimgui's functions of the plot frame's calls (imgui.h, Dear ImGui 1.93), not in the generated layer
   subroutine ImDrawList_AddLineH(self, min_x, max_x, y, col, thickness, flags) bind(C, name='ImDrawList_AddLineH')
   !< ImDrawList::AddLineH(float,float,float,ImU32,float,ImDrawFlags), imgui.h.
   import :: c_float, c_int, c_ptr
   implicit none
   type(c_ptr),    value :: self         !< C `ImDrawList*`.
   real(c_float),  value :: min_x, max_x !< C `float`.
   real(c_float),  value :: y            !< C `float`.
   integer(c_int), value :: col          !< C `ImU32`.
   real(c_float),  value :: thickness    !< C `float`.
   integer(c_int), value :: flags        !< C `ImDrawFlags`.
   endsubroutine ImDrawList_AddLineH

   subroutine ImDrawList_AddLineV(self, x, min_y, max_y, col, thickness, flags) bind(C, name='ImDrawList_AddLineV')
   !< ImDrawList::AddLineV(float,float,float,ImU32,float,ImDrawFlags), imgui.h.
   import :: c_float, c_int, c_ptr
   implicit none
   type(c_ptr),    value :: self         !< C `ImDrawList*`.
   real(c_float),  value :: x            !< C `float`.
   real(c_float),  value :: min_y, max_y !< C `float`.
   integer(c_int), value :: col          !< C `ImU32`.
   real(c_float),  value :: thickness    !< C `float`.
   integer(c_int), value :: flags        !< C `ImDrawFlags`.
   endsubroutine ImDrawList_AddLineV

   subroutine ImDrawList_PrimQuadUV(self, a, b, c, d, uv_a, uv_b, uv_c, uv_d, col) bind(C, name='ImDrawList_PrimQuadUV')
   !< ImDrawList::PrimQuadUV(ImVec2 x4, ImVec2 x4, ImU32), imgui.h.
   import :: c_int, c_ptr, im_vec2
   implicit none
   type(c_ptr),    value :: self                   !< C `ImDrawList*`.
   type(im_vec2),  value :: a, b, c, d             !< C `const ImVec2_c`.
   type(im_vec2),  value :: uv_a, uv_b, uv_c, uv_d !< C `const ImVec2_c`.
   integer(c_int), value :: col                    !< C `ImU32`.
   endsubroutine ImDrawList_PrimQuadUV

   subroutine ImDrawList__SelectLineTexture(self, screen_thickness, out_uv0, out_uv1, out_fringe, flags) &
      bind(C, name='ImDrawList__SelectLineTexture')
   !< ImDrawList::_SelectLineTexture(float,ImVec2*,ImVec2*,float*,ImDrawFlags), imgui.h.
   import :: c_float, c_int, c_ptr, im_vec2
   implicit none
   type(c_ptr),    value         :: self             !< C `ImDrawList*`.
   real(c_float),  value         :: screen_thickness !< C `float`.
   type(im_vec2),  intent(out)   :: out_uv0          !< C `ImVec2_c*`.
   type(im_vec2),  intent(out)   :: out_uv1          !< C `ImVec2_c*`.
   real(c_float),  intent(out)   :: out_fringe       !< C `float*`.
   integer(c_int), value         :: flags            !< C `ImDrawFlags`.
   endsubroutine ImDrawList__SelectLineTexture
endinterface

contains
   ! IDs

   function core_get_id(label) result(id)
   !< The ID of a label in the current ID stack (`##` and `###` as Dear ImGui reads them).
   character(len=*), intent(in) :: label !< Label.
   integer(int32)               :: id    !< ID (`ImGuiID`, an unsigned 32-bit value in its bits).
   character(kind=c_char, len=:), allocatable :: long !< A label longer than the buffer.

   if (len(label) <= BUF_LEN) then
      buf(1:len(label) + 1) = label//c_null_char
      id = int(igGetID_Str(buf), int32)
   else
      long = label//c_null_char
      id = int(igGetID_Str(long), int32)
   endif
   endfunction core_get_id

   subroutine core_push_id(label)
   !< Push a label on the ID stack.
   character(len=*), intent(in) :: label !< Label.
   character(kind=c_char, len=:), allocatable :: long !< A label longer than the buffer.

   if (len(label) <= BUF_LEN) then
      buf(1:len(label) + 1) = label//c_null_char
      call igPushID_Str(buf)
   else
      long = label//c_null_char
      call igPushID_Str(long)
   endif
   endsubroutine core_push_id

   subroutine core_pop_id()
   !< Pop the ID stack.

   call igPopID()
   endsubroutine core_pop_id

   ! items

   subroutine core_item_size(w, h, baseline)
   !< Reserve an item's room in the layout (`ItemSize`), its text baseline `baseline` pixels from its top (default:
   !< none, -1).
   real(real64), intent(in)           :: w, h     !< Size [pixels].
   real(real64), intent(in), optional :: baseline !< Text baseline [pixels].

   if (present(baseline)) then
      call igItemSize_Vec2(im_vec2(real(w, c_float), real(h, c_float)), real(baseline, c_float))
   else
      call igItemSize_Vec2(im_vec2(real(w, c_float), real(h, c_float)), -1.0_c_float)
   endif
   endsubroutine core_item_size

   function core_item_add(x0, y0, x1, y1, id) result(visible)
   !< Register an item of ID `id` on the rectangle (x0, y0)-(x1, y1) (`ItemAdd`): false when clipped (draw nothing).
   real(real64),   intent(in) :: x0, y0, x1, y1 !< Rectangle [pixels].
   integer(int32), intent(in) :: id             !< ID (0: an item without one).
   logical                    :: visible        !< Not clipped.

   visible = logical(igItemAdd(rect(x0, y0, x1, y1), int(id, c_int), c_null_ptr, 0_c_int))
   endfunction core_item_add

   function core_button_behavior(x0, y0, x1, y1, id, hovered, held, flags) result(pressed)
   !< A button's behaviour on the rectangle (`ButtonBehavior`): pressed this frame, and whether it is hovered and held.
   real(real64),   intent(in)            :: x0, y0, x1, y1 !< Rectangle [pixels].
   integer(int32), intent(in)            :: id             !< The item's ID.
   logical,        intent(out)           :: hovered        !< Hovered.
   logical,        intent(out)           :: held           !< Held.
   integer(int32), intent(in), optional  :: flags          !< `ImGuiButtonFlags` (default 0).
   logical                               :: pressed        !< Pressed.
   logical(c_bool), target               :: h, d           !< C copies.
   integer(c_int)                        :: f              !< Flags.

   f = 0_c_int
   if (present(flags)) f = int(flags, c_int)
   pressed = logical(igButtonBehavior(rect(x0, y0, x1, y1), int(id, c_int), c_loc(h), c_loc(d), f))
   hovered = logical(h)
   held = logical(d)
   endfunction core_button_behavior

   subroutine core_keep_alive(id)
   !< Keep an ID alive this frame without an item (`KeepAliveID`).
   integer(int32), intent(in) :: id !< ID.

   call igKeepAliveID(int(id, c_int))
   endsubroutine core_keep_alive

   function core_item_hovered() result(yes)
   !< The last item is hovered.
   logical :: yes !< Hovered.

   yes = logical(igIsItemHovered(0_c_int))
   endfunction core_item_hovered

   function core_item_active() result(yes)
   !< The last item is active.
   logical :: yes !< Active.

   yes = logical(igIsItemActive())
   endfunction core_item_active

   function core_active_id() result(id)
   !< The active item's ID (0: none).
   integer(int32) :: id !< ID.

   id = int(igGetActiveID(), int32)
   endfunction core_active_id

   function core_hovered_id() result(id)
   !< The hovered item's ID (0: none).
   integer(int32) :: id !< ID.

   id = int(igGetHoveredID(), int32)
   endfunction core_hovered_id

   ! the window and the frame

   subroutine core_cursor_screen_pos(x, y)
   !< The layout cursor [screen pixels].
   real(real64), intent(out) :: x, y !< Position.
   type(im_vec2)             :: p    !< C value.

   p = igGetCursorScreenPos()
   x = real(p%x, real64)
   y = real(p%y, real64)
   endsubroutine core_cursor_screen_pos

   subroutine core_set_cursor_screen_pos(x, y)
   !< Move the layout cursor [screen pixels].
   real(real64), intent(in) :: x, y !< Position.

   call igSetCursorScreenPos(im_vec2(real(x, c_float), real(y, c_float)))
   endsubroutine core_set_cursor_screen_pos

   subroutine core_content_region_avail(w, h)
   !< The room left in the window from the cursor [pixels].
   real(real64), intent(out) :: w, h !< Size.
   type(im_vec2)             :: p    !< C value.

   p = igGetContentRegionAvail()
   w = real(p%x, real64)
   h = real(p%y, real64)
   endsubroutine core_content_region_avail

   subroutine core_window_pos(x, y)
   !< The current window's position [screen pixels].
   real(real64), intent(out) :: x, y !< Position.
   type(im_vec2)             :: p    !< C value.

   p = igGetWindowPos()
   x = real(p%x, real64)
   y = real(p%y, real64)
   endsubroutine core_window_pos

   subroutine core_window_size(w, h)
   !< The current window's size [pixels].
   real(real64), intent(out) :: w, h !< Size.
   type(im_vec2)             :: p    !< C value.

   p = igGetWindowSize()
   w = real(p%x, real64)
   h = real(p%y, real64)
   endsubroutine core_window_size

   function core_frame_count() result(n)
   !< Frames since the start.
   integer(int32) :: n !< Frames.

   n = int(igGetFrameCount(), int32)
   endfunction core_frame_count

   function core_time() result(t)
   !< Time since the start [s].
   real(real64) :: t !< Time.

   t = real(igGetTime(), real64)
   endfunction core_time

   function core_font_size() result(s)
   !< The current font's size [pixels].
   real(real64) :: s !< Size.

   s = real(igGetFontSize(), real64)
   endfunction core_font_size

   function core_frame_height() result(h)
   !< The height of a framed item (font size and frame padding) [pixels].
   real(real64) :: h !< Height.

   h = real(igGetFrameHeight(), real64)
   endfunction core_frame_height

   subroutine core_text_size(text, w, h, hide_after_hash)
   !< The size of a text in the current font [pixels] (`hide_after_hash`: the part before `##` only, default false).
   character(len=*), intent(in)           :: text            !< Text (UTF-8).
   real(real64),     intent(out)          :: w, h            !< Size.
   logical,          intent(in), optional :: hide_after_hash !< Measure the part before `##`.
   type(im_vec2)                          :: p               !< C value.
   logical(c_bool)                        :: hide            !< C copy.
   character(kind=c_char, len=:), allocatable :: long        !< A text longer than the buffer.

   hide = .false.
   if (present(hide_after_hash)) hide = logical(hide_after_hash, c_bool)
   if (len(text) <= BUF_LEN) then
      buf(1:len(text) + 1) = text//c_null_char
      p = igCalcTextSize(buf, c_null_ptr, hide, -1.0_c_float)
   else
      long = text//c_null_char
      p = igCalcTextSize(long, c_null_ptr, hide, -1.0_c_float)
   endif
   w = real(p%x, real64)
   h = real(p%y, real64)
   endsubroutine core_text_size

   ! style colours

   function core_style_color(idx, alpha_mul) result(col)
   !< A style colour (`ImGuiCol_*`) as a packed colour, its alpha times the style's and `alpha_mul` (default 1).
   integer(int32), intent(in)           :: idx       !< Colour (`ImGuiCol_*`).
   real(real64),   intent(in), optional :: alpha_mul !< Alpha factor.
   integer(int32)                       :: col       !< Packed colour.
   real(c_float)                        :: a         !< C copy.

   a = 1.0_c_float
   if (present(alpha_mul)) a = real(alpha_mul, c_float)
   col = int(igGetColorU32_Col(int(idx, c_int), a), int32)
   endfunction core_style_color

   subroutine core_style_var(name, values, n)
   !< A style variable by its `ImGuiStyle` name (`'FramePadding'`, `'FrameRounding'`, ...): its value(s) and how many
   !< (1, or 2 for a pair; 0 for an unknown name).
   character(len=*), intent(in)  :: name      !< Name.
   real(real64),     intent(out) :: values(2) !< Values.
   integer(int32),   intent(out) :: n         !< 1 or 2 (0: unknown).
   integer(int32)                :: s         !< Status (an unknown name: n = 0).

   call ig_get_style_var(name, values, n, s)
   endsubroutine core_style_var

   pure function core_color(r, g, b, a) result(col)
   !< A colour [0, 1] packed as Dear ImGui packs it (`ColorConvertFloat4ToU32`: each channel saturated, times 255,
   !< rounded half up; red in the low byte, alpha in the high one).
   real(real64), intent(in) :: r, g, b, a !< Channels.
   integer(int32)           :: col        !< Packed colour.
   integer(int64)           :: u          !< Unsigned value.

   u = ior(ior(byte(r), ishft(byte(g), 8)), ior(ishft(byte(b), 16), ishft(byte(a), 24)))
   if (u >= 2147483648_int64) u = u - 4294967296_int64
   col = int(u, int32)
   contains
      pure function byte(x) result(v)
      !< A channel as a byte (`IM_F32_TO_INT8_SAT`, in C float).
      real(real64), intent(in) :: x !< Channel.
      integer(int64)           :: v !< Byte.

      v = int(min(max(real(x, c_float), 0.0_c_float), 1.0_c_float) * 255.0_c_float + 0.5_c_float, int64)
      endfunction byte
   endfunction core_color

   ! input

   subroutine core_mouse_pos(x, y)
   !< The pointer [screen pixels].
   real(real64), intent(out) :: x, y !< Position.
   type(im_vec2)             :: p    !< C value.

   p = igGetMousePos()
   x = real(p%x, real64)
   y = real(p%y, real64)
   endsubroutine core_mouse_pos

   function core_mouse_down(button) result(yes)
   !< A mouse button (0 left, 1 right, 2 middle) is down.
   integer(int32), intent(in) :: button !< Button.
   logical                    :: yes    !< Down.

   yes = logical(igIsMouseDown_Nil(int(button, c_int)))
   endfunction core_mouse_down

   function core_mouse_clicked(button) result(yes)
   !< A mouse button was clicked this frame.
   integer(int32), intent(in) :: button !< Button.
   logical                    :: yes    !< Clicked.

   yes = logical(igIsMouseClicked_Bool(int(button, c_int), .false._c_bool))
   endfunction core_mouse_clicked

   function core_mouse_released(button) result(yes)
   !< A mouse button was released this frame.
   integer(int32), intent(in) :: button !< Button.
   logical                    :: yes    !< Released.

   yes = logical(igIsMouseReleased_Nil(int(button, c_int)))
   endfunction core_mouse_released

   function core_mouse_hovering_rect(x0, y0, x1, y1, clip) result(yes)
   !< The pointer is in the rectangle (and in the current clip rectangle, `clip` default true).
   real(real64), intent(in)           :: x0, y0, x1, y1 !< Rectangle [pixels].
   logical,      intent(in), optional :: clip           !< Clipped by the clip rectangle.
   logical                            :: yes            !< Hovering.
   logical(c_bool)                    :: c              !< C copy.

   c = .true.
   if (present(clip)) c = logical(clip, c_bool)
   yes = logical(igIsMouseHoveringRect(im_vec2(real(x0, c_float), real(y0, c_float)), &
                                       im_vec2(real(x1, c_float), real(y1, c_float)), c))
   endfunction core_mouse_hovering_rect

   function core_key_down(key) result(yes)
   !< A key (`ImGuiKey_*`) is down.
   integer(int32), intent(in) :: key !< Key.
   logical                    :: yes !< Down.

   yes = logical(igIsKeyDown_Nil(int(key, c_int)))
   endfunction core_key_down

   function core_key_pressed(key, repeat) result(yes)
   !< A key was pressed this frame (`repeat`: the key's repeats too, default true).
   integer(int32), intent(in)           :: key    !< Key.
   logical,        intent(in), optional :: repeat !< Count repeats.
   logical                              :: yes    !< Pressed.
   logical(c_bool)                      :: r      !< C copy.

   r = .true.
   if (present(repeat)) r = logical(repeat, c_bool)
   yes = logical(igIsKeyPressed_Bool(int(key, c_int), r))
   endfunction core_key_pressed

   ! the draw list

   subroutine core_draw_begin()
   !< Start drawing into the current window's list: the Fortran list emptied, its state read from Dear ImGui's.
   real(c_float)  :: fringe                         !< Fringe scale.
   type(im_vec2)  :: white                          !< White pixel's UV.
   type(im_vec4)  :: lines(DL_LINE_TEXTURES)        !< Lines' textures.
   real(c_float)  :: uv(4, DL_LINE_TEXTURES)        !< ... as an array.
   integer(c_int) :: n, flags                       !< Textures, flags.
   integer(int32) :: k                              !< Counter.

   if (list%nvtx > 0_int32) call core_draw_end()
   target_list = igGetWindowDrawList()
   call dl_reset(list)
   n = figure_ImDrawList_shared(target_list, fringe, white, lines, int(DL_LINE_TEXTURES, c_int), flags)
   do k = 1_int32, int(n, int32)
      uv(:, k) = [lines(k)%x, lines(k)%y, lines(k)%z, lines(k)%w]
   enddo
   call dl_set_state(list, fringe, [white%x, white%y], uv, int(n, int32), flags)
   endsubroutine core_draw_begin

   subroutine core_draw_end()
   !< Append what is pending to Dear ImGui's list (one primitive per batch) and empty the Fortran list.
   integer(int32) :: k, v0, nv, i0, ni !< Batch, its extent.

   if (.not. c_associated(target_list)) return
   do k = 1_int32, list%nbatch
      call dl_batch(list, k, v0, nv, i0, ni)
      if (nv > 0_int32 .and. ni > 0_int32) &
         call figure_ImDrawList_append(target_list, c_loc(list%vtx(v0)), int(nv, c_int), list%idx(i0:), int(ni, c_int))
   enddo
   call dl_reset(list)
   endsubroutine core_draw_end

   function core_draw_list() result(p)
   !< The Dear ImGui list the drawing goes to (for a layer that hands it to Dear ImGui itself).
   type(c_ptr) :: p !< `ImDrawList*`.

   p = target_list
   endfunction core_draw_list

   subroutine core_draw_line(x1, y1, x2, y2, col, thickness)
   !< A segment (Dear ImGui's `AddLine`), `thickness` pixels wide (default 1).
   real(real64),   intent(in)           :: x1, y1, x2, y2 !< Ends [pixels].
   integer(int32), intent(in)           :: col            !< Packed colour.
   real(real64),   intent(in), optional :: thickness      !< Thickness [pixels].
   real(c_float)                        :: t              !< C copy.

   t = 1.0_c_float
   if (present(thickness)) t = real(thickness, c_float)
   call dl_line(list, real(x1, c_float), real(y1, c_float), real(x2, c_float), real(y2, c_float), int(col, c_int32_t), t, &
                0_c_int)
   endsubroutine core_draw_line

   subroutine core_draw_rect_filled(x0, y0, x1, y1, col, rounding)
   !< A filled rectangle (`AddRectFilled`), its corners rounded by `rounding` pixels (default 0).
   real(real64),   intent(in)           :: x0, y0, x1, y1 !< Corners [pixels].
   integer(int32), intent(in)           :: col            !< Packed colour.
   real(real64),   intent(in), optional :: rounding       !< Rounding [pixels].

   if (present(rounding)) then
      if (rounding >= 0.5_real64) then
         call core_draw_end_pending()
         call ImDrawList_AddRectFilled(target_list, v2(x0, y0), v2(x1, y1), int(col, c_int), real(rounding, c_float), 0_c_int)
         return
      endif
   endif
   call dl_rect_filled(list, real(x0, c_float), real(y0, c_float), real(x1, c_float), real(y1, c_float), int(col, c_int32_t))
   endsubroutine core_draw_rect_filled

   subroutine core_draw_rect(x0, y0, x1, y1, col, rounding, thickness)
   !< A rectangle's outline (`AddRect`).
   real(real64),   intent(in)           :: x0, y0, x1, y1 !< Corners [pixels].
   integer(int32), intent(in)           :: col            !< Packed colour.
   real(real64),   intent(in), optional :: rounding       !< Rounding [pixels] (default 0).
   real(real64),   intent(in), optional :: thickness      !< Thickness [pixels] (default 1).

   call core_draw_end_pending()
   call ImDrawList_AddRect(target_list, v2(x0, y0), v2(x1, y1), int(col, c_int), opt(rounding, 0.0_real64), &
                           opt(thickness, 1.0_real64), 0_c_int)
   endsubroutine core_draw_rect

   subroutine core_draw_triangle_filled(x1, y1, x2, y2, x3, y3, col)
   !< A filled triangle (`AddTriangleFilled`).
   real(real64),   intent(in) :: x1, y1, x2, y2, x3, y3 !< Vertices [pixels].
   integer(int32), intent(in) :: col                    !< Packed colour.

   call dl_triangle_filled(list, real(x1, c_float), real(y1, c_float), real(x2, c_float), real(y2, c_float), &
                           real(x3, c_float), real(y3, c_float), int(col, c_int32_t))
   endsubroutine core_draw_triangle_filled

   subroutine core_draw_convex_poly_filled(x, y, col)
   !< A filled convex polygon, its points clockwise (`AddConvexPolyFilled`).
   real(real64),   intent(in) :: x(:), y(:) !< Points [pixels].
   integer(int32), intent(in) :: col        !< Packed colour.

   call dl_convex_poly_filled(list, real(x, c_float), real(y, c_float), int(col, c_int32_t), 0_c_int)
   endsubroutine core_draw_convex_poly_filled

   subroutine core_draw_polyline(x, y, col, thickness, closed)
   !< A polyline (`AddPolyline`), closed or not (default not).
   real(real64),   intent(in)           :: x(:), y(:) !< Points [pixels].
   integer(int32), intent(in)           :: col        !< Packed colour.
   real(real64),   intent(in), optional :: thickness  !< Thickness [pixels] (default 1).
   logical,        intent(in), optional :: closed     !< Closed.
   type(im_vec2), allocatable, target   :: p(:)       !< Points, C layout.
   integer(c_int)                       :: f          !< Flags.
   integer(int32)                       :: k          !< Counter.

   call core_draw_end_pending()
   allocate(p(size(x)))
   do k = 1_int32, size(x, kind=int32)
      p(k) = im_vec2(real(x(k), c_float), real(y(k), c_float))
   enddo
   f = 0_c_int
   if (present(closed)) then
      if (closed) f = ImDrawFlags_Closed
   endif
   call ImDrawList_AddPolyline(target_list, c_loc(p), int(size(p), c_int), int(col, c_int), opt(thickness, 1.0_real64), f)
   endsubroutine core_draw_polyline

   subroutine core_draw_circle(x, y, radius, col, filled, thickness, segments)
   !< A circle (`AddCircle`, `AddCircleFilled`), `segments` 0 for Dear ImGui's automatic count (default).
   real(real64),   intent(in)           :: x, y, radius !< Centre, radius [pixels].
   integer(int32), intent(in)           :: col          !< Packed colour.
   logical,        intent(in), optional :: filled       !< Filled (default false).
   real(real64),   intent(in), optional :: thickness    !< Outline thickness [pixels] (default 1).
   integer(int32), intent(in), optional :: segments     !< Segments.
   integer(c_int)                       :: s            !< C copy.
   logical                              :: fill         !< Filled.

   call core_draw_end_pending()
   s = 0_c_int
   if (present(segments)) s = int(segments, c_int)
   fill = .false.
   if (present(filled)) fill = filled
   if (fill) then
      call ImDrawList_AddCircleFilled(target_list, v2(x, y), real(radius, c_float), int(col, c_int), s)
   else
      call ImDrawList_AddCircle(target_list, v2(x, y), real(radius, c_float), int(col, c_int), s, opt(thickness, 1.0_real64), &
                                0_c_int)
   endif
   endsubroutine core_draw_circle

   subroutine core_draw_text(x, y, col, text)
   !< A text in the current font, its top-left corner at (x, y) (`AddText`).
   real(real64),     intent(in) :: x, y !< Position [pixels].
   integer(int32),   intent(in) :: col  !< Packed colour.
   character(len=*), intent(in) :: text !< Text (UTF-8).
   character(kind=c_char, len=:), allocatable :: long !< A text longer than the buffer.

   call core_draw_end_pending()
   if (len(text) <= BUF_LEN) then
      buf(1:len(text) + 1) = text//c_null_char
      call ImDrawList_AddText_Vec2(target_list, v2(x, y), int(col, c_int), buf, c_null_ptr)
   else
      long = text//c_null_char
      call ImDrawList_AddText_Vec2(target_list, v2(x, y), int(col, c_int), long, c_null_ptr)
   endif
   endsubroutine core_draw_text

   subroutine core_draw_image(texture, x0, y0, x1, y1, u0, v0, u1, v1, col)
   !< A texture on a rectangle (`AddImage`), texture coordinates (u0, v0)-(u1, v1) (default 0-1), tinted by `col`
   !< (default opaque white).
   integer(int64), intent(in)           :: texture        !< Texture (`ImTextureID`).
   real(real64),   intent(in)           :: x0, y0, x1, y1 !< Rectangle [pixels].
   real(real64),   intent(in), optional :: u0, v0, u1, v1 !< Texture coordinates.
   integer(int32), intent(in), optional :: col            !< Packed colour.
   type(im_texture_ref)                 :: t              !< Texture reference.
   integer(c_int)                       :: c              !< Colour.

   call core_draw_end_pending()
   t%texid = texture
   c = -1_c_int ! 0xFFFFFFFF, opaque white
   if (present(col)) c = int(col, c_int)
   call ImDrawList_AddImage(target_list, t, v2(x0, y0), v2(x1, y1), v2(opt64(u0, 0.0_real64), opt64(v0, 0.0_real64)), &
                            v2(opt64(u1, 1.0_real64), opt64(v1, 1.0_real64)), c)
   endsubroutine core_draw_image

   subroutine core_push_clip_rect(x0, y0, x1, y1, intersect)
   !< Clip what follows to a rectangle (`PushClipRect`), intersected with the current one (default true).
   real(real64), intent(in)           :: x0, y0, x1, y1 !< Rectangle [pixels].
   logical,      intent(in), optional :: intersect      !< Intersect with the current clip rectangle.
   logical(c_bool)                    :: i              !< C copy.

   call core_draw_end_pending()
   i = .true.
   if (present(intersect)) i = logical(intersect, c_bool)
   call ImDrawList_PushClipRect(target_list, v2(x0, y0), v2(x1, y1), i)
   endsubroutine core_push_clip_rect

   subroutine core_pop_clip_rect()
   !< Restore the clip rectangle (`PopClipRect`).

   call core_draw_end_pending()
   call ImDrawList_PopClipRect(target_list)
   endsubroutine core_pop_clip_rect

   subroutine core_draw_callback(callback, data)
   !< A callback the renderer calls at this point of the list (`AddCallback`, no copied data).
   type(c_funptr), intent(in) :: callback !< `void (*)(const ImDrawList*, const ImDrawCmd*)`.
   type(c_ptr),    intent(in) :: data     !< Its user data.

   call core_draw_end_pending()
   call ImDrawList_AddCallback(target_list, callback, data, 0_c_size_t)
   endsubroutine core_draw_callback

   subroutine core_draw_line_h(x0, x1, y, col, thickness)
   !< A horizontal line from x0 to x1 (Dear ImGui 1.93's `AddLineH`, flags 0): the stroke below `y` (inside), drawn as
   !< a rectangle when pixel-aligned, `thickness` pixels wide (default 1).
   real(real64),   intent(in)           :: x0, x1, y !< Ends and ordinate [pixels].
   integer(int32), intent(in)           :: col       !< Packed colour.
   real(real64),   intent(in), optional :: thickness !< Thickness [pixels].

   call core_draw_end_pending()
   call ImDrawList_AddLineH(target_list, real(x0, c_float), real(x1, c_float), real(y, c_float), int(col, c_int), &
                            opt(thickness, 1.0_real64), 0_c_int)
   endsubroutine core_draw_line_h

   subroutine core_draw_line_v(x, y0, y1, col, thickness)
   !< A vertical line from y0 to y1 (Dear ImGui 1.93's `AddLineV`, flags 0): the stroke right of `x` (inside), drawn as
   !< a rectangle when pixel-aligned, `thickness` pixels wide (default 1).
   real(real64),   intent(in)           :: x, y0, y1 !< Abscissa and ends [pixels].
   integer(int32), intent(in)           :: col       !< Packed colour.
   real(real64),   intent(in), optional :: thickness !< Thickness [pixels].

   call core_draw_end_pending()
   call ImDrawList_AddLineV(target_list, real(x, c_float), real(y0, c_float), real(y1, c_float), int(col, c_int), &
                            opt(thickness, 1.0_real64), 0_c_int)
   endsubroutine core_draw_line_v

   subroutine core_line_texture(thickness, uv0, uv1, fringe)
   !< The texture coordinates of the two sides of an anti-aliased line `thickness` screen pixels wide (at least 1), and
   !< its fringe [pixels] (`_SelectLineTexture` with the list's flags; without anti-aliased lines: the white pixel, 0).
   real(real64), intent(in)  :: thickness !< Thickness [screen pixels].
   real(real64), intent(out) :: uv0(2)    !< One side's (u, v).
   real(real64), intent(out) :: uv1(2)    !< The other's.
   real(real64), intent(out) :: fringe    !< Fringe [pixels].
   type(im_vec2)             :: a, b      !< C values.
   real(c_float)             :: f         !< C value.

   call core_draw_end_pending()
   call ImDrawList__SelectLineTexture(target_list, real(thickness, c_float), a, b, f, list%flags)
   uv0 = [real(a%x, real64), real(a%y, real64)]
   uv1 = [real(b%x, real64), real(b%y, real64)]
   fringe = real(f, real64)
   endsubroutine core_line_texture

   subroutine core_draw_quad_uv(x, y, u, v, col)
   !< A quad of four textured vertices, triangles (1, 2, 3) and (1, 3, 4) (`PrimReserve(6, 4)` and `PrimQuadUV`): the
   !< texture is the list's current one (the font atlas: its white pixel, a line's texture).
   real(real64),   intent(in) :: x(4), y(4) !< Vertices [pixels].
   real(real64),   intent(in) :: u(4), v(4) !< Their texture coordinates.
   integer(int32), intent(in) :: col        !< Packed colour.

   call core_draw_end_pending()
   call ImDrawList_PrimReserve(target_list, 6_c_int, 4_c_int)
   call ImDrawList_PrimQuadUV(target_list, v2(x(1), y(1)), v2(x(2), y(2)), v2(x(3), y(3)), v2(x(4), y(4)), &
                              v2(u(1), v(1)), v2(u(2), v(2)), v2(u(3), v(3)), v2(u(4), v(4)), int(col, c_int))
   endsubroutine core_draw_quad_uv

   ! private

   subroutine core_draw_end_pending()
   !< Append what is pending before Dear ImGui's list draws (the order of the calls kept); the list stays bound.
   type(c_ptr) :: keep !< The bound list.

   if (.not. c_associated(target_list)) target_list = igGetWindowDrawList()
   if (list%nvtx == 0_int32) return
   keep = target_list
   call core_draw_end()
   target_list = keep
   endsubroutine core_draw_end_pending

   pure function rect(x0, y0, x1, y1) result(r)
   !< An `ImRect`.
   real(real64), intent(in) :: x0, y0, x1, y1 !< Corners [pixels].
   type(im_rect)            :: r              !< Rectangle.

   r%min = im_vec2(real(x0, c_float), real(y0, c_float))
   r%max = im_vec2(real(x1, c_float), real(y1, c_float))
   endfunction rect

   pure function v2(x, y) result(v)
   !< An `ImVec2`.
   real(real64), intent(in) :: x, y !< Components.
   type(im_vec2)            :: v    !< Vector.

   v = im_vec2(real(x, c_float), real(y, c_float))
   endfunction v2

   pure function opt(x, default) result(v)
   !< An optional value as a C float.
   real(real64), intent(in), optional :: x       !< Value.
   real(real64), intent(in)           :: default !< Default.
   real(c_float)                      :: v       !< C value.

   v = real(default, c_float)
   if (present(x)) v = real(x, c_float)
   endfunction opt

   pure function opt64(x, default) result(v)
   !< An optional value.
   real(real64), intent(in), optional :: x       !< Value.
   real(real64), intent(in)           :: default !< Default.
   real(real64)                       :: v       !< Value.

   v = default
   if (present(x)) v = x
   endfunction opt64
endmodule figure_core
