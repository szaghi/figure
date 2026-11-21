!< figure_test_core, an item and primitives drawn through figure_core match the same drawn through Dear ImGui, headless.
program figure_test_core
!< figure_test_core, an item and primitives drawn through figure_core match the same drawn through Dear ImGui, headless.
!<
!< szaghi/figure#15 P8's gate. One scene, drawn twice on alternate frames into the same window: through Dear ImGui (a
!< button by `ig_button`, the primitives by Dear ImGui's ImDrawList) and through figure_core (the button rebuilt from
!< its items' calls, `core_item_size`, `core_item_add`, `core_button_behavior`, the style read through the core, its
!< frame and label drawn by `core_draw_*`; the primitives by `core_draw_*`, kept in the Fortran draw list,
!< figure_drawlist, and appended to Dear ImGui's at the end). The primitives cover each path of figure_drawlist:
!< filled rectangles on whole pixels and between them, one thinner than a pixel, lines 1, 2.5 and 6 pixels thick at
!< several angles, filled triangles (a sharp corner beveled) and a convex polygon; and the primitives figure_core
!< hands to Dear ImGui: a rounded rectangle, an outline, a circle, a polyline, a text. The two captures compared
!< at the defaults (|d| <= 2, no pixel failing).
!<
!< Then behaviour: the core button under a click is hovered, held on the press, pressed once on the release; its ID is
!< Dear ImGui's for the same label; a colour packed by `core_color` equals Dear ImGui's `ColorConvertFloat4ToU32`.
!< The captures are `figure_test_core.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
! oracle: click
use, intrinsic :: iso_c_binding, only : c_float, c_int, c_loc, c_ptr
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_button, ig_end, ig_set_next_window, &
                   ImGuiWindowFlags_NoDecoration, FIG_OK
use figure_cimgui, only : im_vec2, im_vec4, igColorConvertFloat4ToU32, igGetID_Str, igGetWindowDrawList
use figure_cimgui_core, only : ImDrawList_AddCircle, ImDrawList_AddConvexPolyFilled, ImDrawList_AddLine,               &
                               ImDrawList_AddPolyline, ImDrawList_AddRect, ImDrawList_AddRectFilled,                    &
                               ImDrawList_AddText_Vec2, ImDrawList_AddTriangleFilled
use figure_cimgui_enums, only : ImGuiCol_Button, ImGuiCol_ButtonActive, ImGuiCol_ButtonHovered, ImGuiCol_Text
use figure_core, only : core_button_behavior, core_color, core_cursor_screen_pos, core_draw_begin, core_draw_circle,     &
                        core_draw_convex_poly_filled, core_draw_end, core_draw_line, core_draw_polyline, core_draw_rect, &
                        core_draw_rect_filled, core_draw_text, core_draw_triangle_filled, core_get_id, core_item_add,     &
                        core_item_size, core_style_color, core_style_var, core_text_size
use figure_testing, only : test_capture, test_click, test_compare_image, test_mouse_move

implicit none
character(len=*), parameter :: REF_SHOT = 'figure_test_core.imgui.png.tmp' !< The scene through Dear ImGui.
character(len=*), parameter :: NEW_SHOT = 'figure_test_core.core.png.tmp'  !< ... through figure_core.
character(len=*), parameter :: LABEL = 'Press me##core'                    !< The button's label.
integer(int32),   parameter :: W = 400_int32                               !< Display width [pixels].
integer(int32),   parameter :: H = 300_int32                               !< Display height [pixels].
type(app_object)            :: app                                         !< Application.
logical                     :: test_passed(5)                              !< Per-check outcome.
integer(int32)              :: s1, s2, s                                   !< Statuses.
integer(int64)              :: nf                                          !< Pixels that failed.
integer(int32)              :: f                                           !< Frame.
logical                     :: pressed, hovered, held                      !< The core button, this frame.
integer(int32)              :: n_pressed                                   !< Frames it was pressed.
logical                     :: seen_hovered, seen_held                     !< ... hovered, held, on some frame.
real(real64)                :: bx0, by0, bx1, by1                          !< Its rectangle.
integer(int32)              :: id_core, id_imgui                           !< Its ID, both ways.
character(len=16)           :: keep                                        !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
s1 = -1_int32
s2 = -1_int32
call test_mouse_move(-100.0_real64, -100.0_real64) ! nothing hovered
do f = 1_int32, 6_int32
   if (.not. app%next_frame()) error stop 'figure_test_core: next_frame returned false in headless mode'
   call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
   if (ig_begin('core', flags=ImGuiWindowFlags_NoDecoration)) then
      if (f <= 3_int32) then
         call scene_imgui()
      else
         call scene_core(pressed, hovered, held)
      endif
   endif
   call ig_end()
   if (f == 3_int32) call test_capture(REF_SHOT, s1)
   if (f == 6_int32) call test_capture(NEW_SHOT, s2)
enddo
if (.not. app%next_frame()) error stop 'figure_test_core: next_frame returned false in headless mode' ! writes the capture
test_passed(1) = s1 == FIG_OK .and. s2 == FIG_OK
if (test_passed(1)) test_passed(1) = test_compare_image(NEW_SHOT, REF_SHOT, failed=nf, stat=s)
if (.not. test_passed(1)) write(output_unit, '(A,I0,A,I0,A,I0,A,A)') 'pictures: status ', s1, ' ', s2, ', ', nf, &
                                                                      ' failed: ', figure_last_error()

! behaviour: the core button clicked
n_pressed = 0_int32
seen_hovered = .false.
seen_held = .false.
call test_click(0.5_real64 * (bx0 + bx1), 0.5_real64 * (by0 + by1))
do f = 1_int32, 6_int32
   if (.not. app%next_frame()) error stop 'figure_test_core: next_frame returned false in headless mode'
   call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
   if (ig_begin('core', flags=ImGuiWindowFlags_NoDecoration)) then
      call scene_core(pressed, hovered, held)
      id_core = core_get_id(LABEL)
      id_imgui = int(igGetID_Str(LABEL//char(0)), int32)
      if (pressed) n_pressed = n_pressed + 1_int32
      seen_hovered = seen_hovered .or. hovered
      seen_held = seen_held .or. (held .and. hovered)
   endif
   call ig_end()
enddo
test_passed(2) = n_pressed == 1_int32
test_passed(3) = seen_hovered .and. seen_held
test_passed(4) = id_core == id_imgui .and. id_core /= 0_int32
test_passed(5) = core_color(0.2_real64, 0.4_real64, 0.6_real64, 0.8_real64) == &
                 int(igColorConvertFloat4ToU32(im_vec4(0.2_c_float, 0.4_c_float, 0.6_c_float, 0.8_c_float)), int32) .and. &
                 core_color(1.5_real64, -0.5_real64, 0.5_real64, 1.0_real64) == &
                 int(igColorConvertFloat4ToU32(im_vec4(1.5_c_float, -0.5_c_float, 0.5_c_float, 1.0_c_float)), int32)
if (.not. all(test_passed(2:5))) write(output_unit, '(A,I0,2L2,2(1X,I0))') 'behaviour: pressed ', n_pressed, &
                                                                         seen_hovered, seen_held, id_core, id_imgui
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_core checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine scene_imgui()
   !< The scene through Dear ImGui: the button, then the primitives on the window's ImDrawList.
   type(c_ptr)                 :: dl     !< Window's list.
   type(im_vec2), target       :: pts(5) !< A polygon, a polyline.
   logical                     :: clicked !< The button (never clicked here).

   clicked = ig_button(LABEL)
   dl = igGetWindowDrawList()
   call ImDrawList_AddRectFilled(dl, v2(20, 60), v2(120, 100), core_color(0.9d0, 0.3d0, 0.2d0, 1.0d0), 0.0_c_float, 0_c_int)
   call ImDrawList_AddRectFilled(dl, im_vec2(130.3_c_float, 60.6_c_float), im_vec2(200.7_c_float, 99.2_c_float), &
                                 core_color(0.2d0, 0.8d0, 0.3d0, 0.8d0), 0.0_c_float, 0_c_int)
   call ImDrawList_AddRectFilled(dl, im_vec2(210.0_c_float, 60.0_c_float), im_vec2(210.4_c_float, 100.0_c_float), &
                                 core_color(1.0d0, 1.0d0, 0.2d0, 1.0d0), 0.0_c_float, 0_c_int)
   call ImDrawList_AddRectFilled(dl, v2(300, 60), v2(380, 100), core_color(0.3d0, 0.5d0, 0.9d0, 1.0d0), 8.0_c_float, 0_c_int)
   call ImDrawList_AddRect(dl, v2(220, 60), v2(290, 100), core_color(0.9d0, 0.9d0, 0.9d0, 1.0d0), 0.0_c_float, &
                           1.0_c_float, 0_c_int)
   call ImDrawList_AddLine(dl, v2(20, 120), v2(180, 170), core_color(1.0d0, 1.0d0, 1.0d0, 1.0d0), 1.0_c_float, 0_c_int)
   call ImDrawList_AddLine(dl, v2(20, 180), v2(180, 150), core_color(0.9d0, 0.6d0, 0.1d0, 1.0d0), 2.5_c_float, 0_c_int)
   call ImDrawList_AddLine(dl, v2(200, 120), v2(380, 200), core_color(0.5d0, 0.9d0, 0.9d0, 0.7d0), 6.0_c_float, 0_c_int)
   call ImDrawList_AddLine(dl, v2(20, 205), v2(380, 205), core_color(0.8d0, 0.8d0, 0.8d0, 1.0d0), 1.0_c_float, 0_c_int)
   call ImDrawList_AddLine(dl, im_vec2(190.5_c_float, 110.0_c_float), im_vec2(190.5_c_float, 200.0_c_float), &
                           core_color(0.8d0, 0.2d0, 0.8d0, 1.0d0), 0.6_c_float, 0_c_int)
   call ImDrawList_AddTriangleFilled(dl, v2(220, 215), v2(380, 235), v2(240, 290), core_color(0.6d0, 0.2d0, 0.9d0, 1.0d0))
   call ImDrawList_AddTriangleFilled(dl, v2(20, 220), v2(200, 232), v2(20, 228), core_color(0.9d0, 0.9d0, 0.3d0, 1.0d0))
   pts = [v2(60, 240), v2(100, 250), v2(110, 280), v2(70, 295), v2(40, 270)]
   call ImDrawList_AddConvexPolyFilled(dl, c_loc(pts), 5_c_int, core_color(0.3d0, 0.9d0, 0.5d0, 0.9d0), 0_c_int)
   call ImDrawList_AddCircle(dl, v2(160, 260), 25.0_c_float, core_color(1.0d0, 0.5d0, 0.5d0, 1.0d0), 0_c_int, &
                             2.0_c_float, 0_c_int)
   pts = [v2(300, 140), v2(330, 120), v2(360, 160), v2(390, 130), v2(395, 190)]
   call ImDrawList_AddPolyline(dl, c_loc(pts), 5_c_int, core_color(0.9d0, 0.9d0, 0.5d0, 1.0d0), 1.5_c_float, 0_c_int)
   call ImDrawList_AddText_Vec2(dl, v2(250, 15), core_color(1.0d0, 1.0d0, 1.0d0, 1.0d0), 'core text'//char(0), &
                                c_null())
   endsubroutine scene_imgui

   subroutine scene_core(pressed, hovered, held)
   !< The scene through figure_core: the button from its items' calls, then the primitives.
   logical, intent(out) :: pressed, hovered, held !< The button.
   real(real64)         :: pad(2), rounding(2), align(2), border(2) !< Style.
   integer(int32)       :: n                       !< Values read.
   integer(int32)       :: id                      !< Button's ID.
   integer(int32)       :: col                     !< Its colour.
   real(real64)         :: tw, th                  !< Label's size.
   real(c_float)        :: px, py, sx, sy, x, y    !< Position, size, the label's position: in C float, as ButtonEx.

   ! the button, as Dear ImGui's ButtonEx builds it
   pressed = .false.
   hovered = .false.
   held = .false.
   call core_style_var('FramePadding', pad, n)
   call core_style_var('FrameRounding', rounding, n)
   call core_style_var('ButtonTextAlign', align, n)
   call core_style_var('FrameBorderSize', border, n)
   id = core_get_id(LABEL)
   call core_text_size(LABEL, tw, th, hide_after_hash=.true.)
   call core_cursor_screen_pos(bx0, by0)
   px = real(bx0, c_float)
   py = real(by0, c_float)
   sx = real(tw, c_float) + real(pad(1), c_float) * 2.0_c_float
   sy = real(th, c_float) + real(pad(2), c_float) * 2.0_c_float
   bx1 = real(px + sx, real64)
   by1 = real(py + sy, real64)
   call core_item_size(bx1 - bx0, by1 - by0, pad(2))
   call core_draw_begin()
   if (core_item_add(bx0, by0, bx1, by1, id)) then
      pressed = core_button_behavior(bx0, by0, bx1, by1, id, hovered, held)
      if (held .and. hovered) then
         col = core_style_color(ImGuiCol_ButtonActive)
      elseif (hovered) then
         col = core_style_color(ImGuiCol_ButtonHovered)
      else
         col = core_style_color(ImGuiCol_Button)
      endif
      call core_draw_rect_filled(bx0, by0, bx1, by1, col, rounding(1))
      if (border(1) > 0.0_real64) error stop 'figure_test_core: a frame border is not drawn by this test'
      x = px + real(pad(1), c_float) ! RenderTextClippedEx: the text's block aligned in the frame less its padding
      y = py + real(pad(2), c_float)
      x = max(x, x + ((real(bx1, c_float) - real(pad(1), c_float)) - x - real(tw, c_float)) * real(align(1), c_float))
      y = max(y, y + ((real(by1, c_float) - real(pad(2), c_float)) - y - real(th, c_float)) * real(align(2), c_float))
      call core_draw_text(real(x, real64), real(y, real64), core_style_color(ImGuiCol_Text), LABEL(1:index(LABEL, '##') - 1))
   endif
   ! the primitives
   call core_draw_rect_filled(20d0, 60d0, 120d0, 100d0, core_color(0.9d0, 0.3d0, 0.2d0, 1.0d0))
   call core_draw_rect_filled(f4(130.3), f4(60.6), f4(200.7), f4(99.2), core_color(0.2d0, 0.8d0, 0.3d0, 0.8d0))
   call core_draw_rect_filled(210d0, 60d0, f4(210.4), 100d0, core_color(1.0d0, 1.0d0, 0.2d0, 1.0d0))
   call core_draw_rect_filled(300d0, 60d0, 380d0, 100d0, core_color(0.3d0, 0.5d0, 0.9d0, 1.0d0), rounding=8.0_real64)
   call core_draw_rect(220d0, 60d0, 290d0, 100d0, core_color(0.9d0, 0.9d0, 0.9d0, 1.0d0))
   call core_draw_line(20d0, 120d0, 180d0, 170d0, core_color(1.0d0, 1.0d0, 1.0d0, 1.0d0))
   call core_draw_line(20d0, 180d0, 180d0, 150d0, core_color(0.9d0, 0.6d0, 0.1d0, 1.0d0), thickness=2.5_real64)
   call core_draw_line(200d0, 120d0, 380d0, 200d0, core_color(0.5d0, 0.9d0, 0.9d0, 0.7d0), thickness=6.0_real64)
   call core_draw_line(20d0, 205d0, 380d0, 205d0, core_color(0.8d0, 0.8d0, 0.8d0, 1.0d0))
   call core_draw_line(190.5d0, 110d0, 190.5d0, 200d0, core_color(0.8d0, 0.2d0, 0.8d0, 1.0d0), thickness=f4(0.6))
   call core_draw_triangle_filled(220d0, 215d0, 380d0, 235d0, 240d0, 290d0, core_color(0.6d0, 0.2d0, 0.9d0, 1.0d0))
   call core_draw_triangle_filled(20d0, 220d0, 200d0, 232d0, 20d0, 228d0, core_color(0.9d0, 0.9d0, 0.3d0, 1.0d0))
   call core_draw_convex_poly_filled([60d0, 100d0, 110d0, 70d0, 40d0], [240d0, 250d0, 280d0, 295d0, 270d0], &
                                     core_color(0.3d0, 0.9d0, 0.5d0, 0.9d0))
   call core_draw_circle(160d0, 260d0, 25d0, core_color(1.0d0, 0.5d0, 0.5d0, 1.0d0), thickness=2.0_real64)
   call core_draw_polyline([300d0, 330d0, 360d0, 390d0, 395d0], [140d0, 120d0, 160d0, 130d0, 190d0], &
                           core_color(0.9d0, 0.9d0, 0.5d0, 1.0d0), thickness=1.5_real64)
   call core_draw_text(250d0, 15d0, core_color(1.0d0, 1.0d0, 1.0d0, 1.0d0), 'core text')
   call core_draw_end()
   endsubroutine scene_core

   pure function v2(x, y) result(v)
   !< An ImVec2 of whole pixels.
   integer, intent(in) :: x, y !< Components.
   type(im_vec2)       :: v    !< Vector.

   v = im_vec2(real(x, c_float), real(y, c_float))
   endfunction v2

   pure function f4(x) result(v)
   !< A default real as the C float the Dear ImGui scene passes, widened (the same coordinate both ways).
   real, intent(in) :: x !< Value.
   real(real64)     :: v !< Value.

   v = real(real(x, c_float), real64)
   endfunction f4

   function c_null() result(p)
   !< NULL.
   use, intrinsic :: iso_c_binding, only : c_null_ptr
   type(c_ptr) :: p !< Pointer.

   p = c_null_ptr
   endfunction c_null

   subroutine remove_files()
   !< The captures (and the .new.png, .diff.png a mismatch writes are left for inspection).
   integer(int32) :: unit, ios !< Unit, status.
   integer(int32) :: k         !< Counter.
   character(len=*), parameter :: FILES(2) = [character(len=40) :: REF_SHOT, NEW_SHOT] !< The captures.

   do k = 1_int32, size(FILES, kind=int32)
      open(newunit=unit, file=trim(FILES(k)), status='old', iostat=ios)
      if (ios == 0) close(unit, status='delete')
   enddo
   endsubroutine remove_files
endprogram figure_test_core
