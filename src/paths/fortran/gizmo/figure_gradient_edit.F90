!< figure_gradient_edit, the gradient editor of a colormap (`ig_gradient_edit`) on figure_core: ImGuizmo's ImGradient.
module figure_gradient_edit
!< figure_gradient_edit, the gradient editor of a colormap (`ig_gradient_edit`) on figure_core: ImGuizmo's ImGradient.
!<
!< szaghi/figure#15 P14. What `native/figure_colormap.cpp`'s `fig_gradient_edit` draws and does, with ImGuizmo's
!< `ImGradient::Edit` (third_party/ImGuizmo/ImGradient.cpp, FIGURE's patch 0003: the selection and the stop moved kept
!< per editor in the window's storage, the child's ID from the ID stack, an invisible button under the stops taking the
!< press), in Fortran: the map's strip (its sorted stops sampled between the centres of the stops at 0 and 1), the
!< stops' row in a child window (a square per stop, of its colour; dragged, a double click adds one, a click selects
!< one), on the right the selected stop's colour (Dear ImGui's `ColorEdit3`) and a Remove button. The stops are the
!< Fortran plot frame's registry's (figure_plot_colormaps: `cm_gradient_slot`, in the editor's order); an edit
!< resamples the map there (`cm_edit_stops`). ImGradient's single-precision arithmetic is kept (`real32`), the
!< strip's colours computed in double precision as `stops_at`.
!<
!< No heap allocation on a frame without an edit, once the work arrays hold the map's stops.
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use figure_c_native, only : FIG_OK
use figure_cimgui_enums, only : ImGuiChildFlags_FrameStyle, ImGuiColorEditFlags_NoInputs, ImGuiColorEditFlags_NoLabel, &
                                ImGuiStyleVar_FramePadding, ImGuiStyleVar_ItemSpacing
use figure_core, only : core_begin_child, core_begin_disabled, core_begin_group, core_button, core_color,              &
                        core_color_edit3, core_content_region_avail, core_cursor_screen_pos, core_draw_begin,         &
                        core_draw_end, core_draw_rect, core_draw_rect_filled, core_draw_rect_filled_multicolor,       &
                        core_dummy, core_end_child, core_end_disabled, core_end_group, core_frame_height, core_get_id, &
                        core_invisible_button, core_io_input, core_mouse_clicked, core_mouse_double_clicked,          &
                        core_mouse_down, core_mouse_pos, core_pop_id, core_pop_style_var, core_push_id,               &
                        core_push_style_var, core_same_line, core_set_cursor_screen_pos, core_set_storage_int,        &
                        core_storage_int, core_style_vec2, core_text_size
use figure_plot_colormaps, only : cm_edit_stops, cm_gradient_get, cm_gradient_size, cm_gradient_slot, cm_stops_at

implicit none
private
public :: gz_gradient_edit

real(real32), allocatable :: stops(:,:)  !< The map's stops as edited on this frame (4, n): r, g, b, position.
real(real32), allocatable :: before(:,:) !< ... as they were (4, n0).
real(real32), allocatable :: sorted(:,:) !< ... sorted by position (4, n).
integer(int32)            :: n = 0_int32 !< Stops in `stops`.

contains
   subroutine gz_gradient_edit(id, name, width, height, changed, status, err)
   !< The gradient editor of the map `name` (trimmed), as `fig_gradient_edit`: `width` positive given, else the space
   !< left plus it; `height` positive given, else two rows of a frame. `changed` true when the stops changed (the map
   !< resampled). `status` FIG_OK, else FIG_ERR_ARGUMENT for a map the editor refuses (`err` the message, as the
   !< native one's).
   character(len=*),              intent(in)  :: id      !< Widget ID (pushed on the ID stack).
   character(len=*),              intent(in)  :: name    !< Map (trimmed).
   real(real32),                  intent(in)  :: width   !< Width [pixels].
   real(real32),                  intent(in)  :: height  !< Height [pixels].
   logical,                       intent(out) :: changed !< The stops changed.
   integer(int32),                intent(out) :: status  !< Status.
   character(len=:), allocatable, intent(out) :: err     !< Message.
   real(real32)   :: row, controls, w, h, bar, strip      !< Layout [pixels].
   real(real32)   :: isx, isy, fpx, fpy, tw, th           !< Item spacing, frame padding, a text's size.
   real(real32)   :: ax, ay, p0x, p0y, x0, x1             !< Space left, the group's corner, the strip's ends.
   real(real64)   :: dx, dy, ta, tb                       !< Scratch, the strip's segment.
   real(real32)   :: rgb(3)                               !< The selected stop's colour.
   integer(int32) :: g, n0, k, segments, selected, ca, cb !< Slot, stops before, counter, segments, selection, colours.
   logical        :: same                                 !< The stops as they were.

   changed = .false.
   g = cm_gradient_slot(name, status, err)
   if (status /= FIG_OK) return
   n0 = cm_gradient_size(g)
   call room(n0 + 1_int32)
   call cm_gradient_get(g, stops)
   n = n0
   before(:, 1:n0) = stops(:, 1:n0)
   ! the widget: the map's strip over the stops (ImGradient's row), and on the stops' right the selected stop's colour
   ! and a button removing it (room kept for them when none is selected)
   row = real(core_frame_height(), real32)
   call core_style_vec2(ImGuiStyleVar_ItemSpacing, dx, dy)
   isx = real(dx, real32)
   isy = real(dy, real32)
   call core_style_vec2(ImGuiStyleVar_FramePadding, dx, dy)
   fpx = real(dx, real32)
   fpy = real(dy, real32)
   call core_text_size('Remove', dx, dy)
   tw = real(dx, real32)
   th = real(dy, real32)
   controls = row + isx
   controls = controls + tw
   controls = controls + 2.0_real32 * fpx
   call core_content_region_avail(dx, dy)
   ax = real(dx, real32)
   ay = real(dy, real32)
   if (width > 0.0_real32) then
      w = width
   else
      w = ax + width
   endif
   w = max(4.0_real32 * row + controls + isx, w)
   if (height > 0.0_real32) then
      h = height
   else
      h = 2.0_real32 * row + isy
   endif
   h = max(2.0_real32 * row + isy, h)
   bar = w - controls - isx
   strip = h - row - isy
   call core_push_id(id)
   call core_begin_group()
   ! the map, between the centres of the stops at 0 and 1 (ImGradient puts a stop at t from t (w - row) + row / 2)
   call core_cursor_screen_pos(dx, dy)
   p0x = real(dx, real32)
   p0y = real(dy, real32)
   call core_dummy(real(bar, real64), real(strip, real64))
   call core_draw_begin()
   call sort_stops()
   x0 = p0x + 0.5_real32 * row
   x1 = p0x + bar - 0.5_real32 * row
   segments = max(1_int32, int(x1 - x0, int32) / 2_int32)
   do k = 0_int32, segments - 1_int32
      ta = real(k, real64) / real(segments, real64)
      tb = real(k + 1_int32, real64) / real(segments, real64)
      ca = u32(cm_stops_at(sorted(:, 1:n), ta))
      cb = u32(cm_stops_at(sorted(:, 1:n), tb))
      call core_draw_rect_filled_multicolor(real(ffloor(x0 + (x1 - x0) * real(ta, real32)), real64), real(p0y, real64), &
                                            real(ffloor(x0 + (x1 - x0) * real(tb, real32)), real64),                   &
                                            real(p0y + strip, real64), ca, cb, cb, ca)
   enddo
   call core_draw_end()
   ! the stops: dragged, a double click adds one, a click selects one
   call edit(bar, row, selected)
   call core_set_cursor_screen_pos(real(p0x + bar + isx, real64), real(p0y + strip + isy, real64))
   if (selected >= 0_int32 .and. selected < n) then
      rgb = stops(1:3, selected + 1_int32)
      if (core_color_edit3('##stop', rgb, ior(ImGuiColorEditFlags_NoInputs, ImGuiColorEditFlags_NoLabel))) &
         stops(1:3, selected + 1_int32) = rgb
      call core_same_line()
      call core_begin_disabled(n <= 2_int32)
      if (core_button('Remove')) then
         stops(:, selected + 1_int32:n - 1_int32) = stops(:, selected + 2_int32:n)
         n = n - 1_int32
      endif
      call core_end_disabled()
   else
      call core_dummy(real(controls, real64), real(row, real64))
   endif
   call core_end_group()
   call core_pop_id()
   same = n == n0
   if (same) same = all(stops(:, 1:n) == before(:, 1:n))
   if (.not. same) then
      call cm_edit_stops(name, real(stops(4, 1:n), real64), real(stops(1:3, 1:n), real64), status, err)
      changed = status == FIG_OK
   endif
   endsubroutine gz_gradient_edit

   subroutine edit(size_x, size_y, selection)
   !< `ImGradient::Edit(delegate, ImVec2(size_x, size_y), selection)` on `stops` (FIGURE's patch 0003).
   real(real32),   intent(in)  :: size_x, size_y !< Size [pixels].
   integer(int32), intent(out) :: selection      !< The stop selected (from 0), -1 none.
   integer(int32) :: child_id, selection_id, moving_id !< IDs.
   integer(int32) :: current, moving, i, sel           !< Selection, the stop moved, counter, a stop's state.
   real(real32)   :: ox, oy, mx, my, mdx, t            !< The child's corner, the pointer, its motion, a position.
   real(real64)   :: dx, dy, wheel, wheel_h, drag(5)   !< Scratch, io.
   real(real64)   :: c(3)                              !< A colour.
   integer(int32) :: mods                              !< Key mods.
   logical        :: dnd, pressed, down, visible       !< Drag and drop, a press, the left button down, the child shown.

   call core_push_style_var(ImGuiStyleVar_FramePadding, 0.0_real64, 0.0_real64)
   child_id = core_get_id('##ImGradient')
   selection_id = core_get_id('##ImGradient.selection')
   moving_id = core_get_id('##ImGradient.moving')
   current = core_storage_int(selection_id, -1_int32)
   moving = core_storage_int(moving_id, -1_int32)
   visible = core_begin_child(child_id, real(size_x, real64), real(size_y, real64), int(ImGuiChildFlags_FrameStyle, int32))
   call core_draw_begin()
   call core_cursor_screen_pos(dx, dy)
   ox = real(dx, real32)
   oy = real(dy, real32)
   call core_content_region_avail(dx, dy) ! an item under the points takes the press, which would move the window
   pressed = core_invisible_button('##points', max(dx, 1.0_real64), max(dy, 1.0_real64))
   call core_mouse_pos(dx, dy)
   mx = real(dx, real32)
   my = real(dy, real32)
   call core_io_input(dx, dy, wheel, wheel_h, drag, mods, dnd)
   mdx = real(dx, real32)
   down = core_mouse_down(0_int32)
   if (current >= n) current = -1_int32
   if (moving /= -1_int32) then
      t = stops(4, moving + 1_int32) + mdx / size_x
      if (t < 0.0_real32) then
         t = 0.0_real32
      elseif (t > 1.0_real32) then
         t = 1.0_real32
      endif
      stops(4, moving + 1_int32) = t
      if (.not. down) moving = -1_int32
   endif
   do i = 0_int32, n - 1_int32
      sel = draw_point(stops(:, i + 1_int32), size_x, size_y, i == current, ox, oy, mx, my)
      if (sel == 2_int32) current = i
      if (sel == 1_int32 .and. down .and. moving == -1_int32) moving = i
   enddo
   if (mx >= ox .and. my >= oy .and. mx < ox + size_x .and. my < oy + size_y .and. core_mouse_double_clicked(0_int32)) &
      then
      t = (mx - ox) / size_x
      call sort_stops()
      c = cm_stops_at(sorted(:, 1:n), real(t, real64))
      call room(n + 1_int32)
      n = n + 1_int32
      stops(:, n) = [real(c(1), real32), real(c(2), real32), real(c(3), real32), t]
   endif
   call core_draw_end()
   call core_end_child()
   call core_pop_style_var()
   call core_set_storage_int(selection_id, current)
   call core_set_storage_int(moving_id, moving)
   selection = current
   endsubroutine edit

   function draw_point(s, size_x, size_y, editing, px, py, mx, my) result(state)
   !< ImGradient's `DrawPoint`: a stop's square, of its colour, outlined; 1 the pointer over it, 2 clicked, else 0.
   real(real32),   intent(in) :: s(4)           !< Stop.
   real(real32),   intent(in) :: size_x, size_y !< The row's size [pixels].
   logical,        intent(in) :: editing        !< Selected.
   real(real32),   intent(in) :: px, py         !< The row's corner [pixels].
   real(real32),   intent(in) :: mx, my         !< The pointer [pixels].
   integer(int32)             :: state          !< State.
   real(real32)               :: x1, y1, x2, y2 !< The square's corners.
   integer(int32), parameter  :: WHITE = -1_int32            !< 0xFFFFFFFF.
   integer(int32), parameter  :: WHITE_HALF = -2130706433_int32 !< 0x80FFFFFF.

   x1 = px + (px + (size_x - size_y) - px) * s(4) ! ImLerp(pos, pos + (size.x - size.y, 0), w) + (3, 3)
   y1 = py + (py - py) * s(4)
   x1 = x1 + 3.0_real32
   y1 = y1 + 3.0_real32
   x2 = (px + size_y) + ((px + size_x) - (px + size_y)) * s(4) ! ImLerp(pos + (size.y, size.y), pos + size, w) - (3, 3)
   y2 = (py + size_y) + ((py + size_y) - (py + size_y)) * s(4)
   x2 = x2 - 3.0_real32
   y2 = y2 - 3.0_real32
   call core_draw_rect_filled(real(x1, real64), real(y1, real64), real(x2, real64), real(y2, real64), &
                              core_color(real(s(1), real64), real(s(2), real64), real(s(3), real64), 1.0_real64))
   if (editing) then
      call core_draw_rect(real(x1, real64), real(y1, real64), real(x2, real64), real(y2, real64), WHITE, &
                          rounding=2.0_real64, thickness=2.5_real64)
   else
      call core_draw_rect(real(x1, real64), real(y1, real64), real(x2, real64), real(y2, real64), WHITE_HALF, &
                          rounding=2.0_real64, thickness=1.25_real64)
   endif
   state = 0_int32
   if (mx >= x1 .and. my >= y1 .and. mx < x2 .and. my < y2) then
      state = 1_int32
      if (core_mouse_clicked(0_int32)) state = 2_int32
   endif
   endfunction draw_point

   subroutine sort_stops()
   !< `sorted_stops`: `stops(:, 1:n)` by position into `sorted`, a stable sort.
   real(real32)   :: t(4) !< A stop moved.
   integer(int32) :: i, j !< Counters.

   sorted(:, 1:n) = stops(:, 1:n)
   do i = 2_int32, n
      t = sorted(:, i)
      j = i - 1_int32
      do while (j >= 1_int32)
         if (.not. sorted(4, j) > t(4)) exit
         sorted(:, j + 1_int32) = sorted(:, j)
         j = j - 1_int32
      enddo
      sorted(:, j + 1_int32) = t
   enddo
   endsubroutine sort_stops

   subroutine room(m)
   !< The work arrays grown to hold `m` stops, `stops` keeping its first `n`.
   integer(int32), intent(in) :: m          !< Stops.
   real(real32), allocatable  :: more(:,:)  !< Grown.
   integer(int32)             :: cap, old   !< New capacity, the old one.

   old = 0_int32
   if (allocated(stops)) old = size(stops, 2, kind=int32)
   if (old >= m) return
   cap = max(16_int32, 2_int32 * m)
   allocate(more(4, cap))
   if (old > 0_int32) more(:, 1:old) = stops
   call move_alloc(more, stops)
   allocate(more(4, cap))
   if (old > 0_int32) more(:, 1:old) = before
   call move_alloc(more, before)
   if (allocated(sorted)) deallocate(sorted)
   allocate(sorted(4, cap))
   endsubroutine room

   pure function ffloor(x) result(r)
   !< `std::floor` of a float.
   real(real32), intent(in) :: x !< Value.
   real(real32)             :: r !< Floor.

   r = real(floor(x, int64), real32)
   endfunction ffloor

   pure function u32(c) result(col)
   !< A colour as `ImGui::ColorConvertFloat4ToU32(ImVec4(float(r), float(g), float(b), 1))` packs it.
   real(real64), intent(in) :: c(3) !< Colour.
   integer(int32)           :: col  !< Packed.

   col = core_color(real(real(c(1), real32), real64), real(real(c(2), real32), real64), real(real(c(3), real32), real64), &
                    1.0_real64)
   endfunction u32
endmodule figure_gradient_edit
