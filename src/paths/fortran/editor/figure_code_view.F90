!< figure_code_view, the code editor drawn: ImGuiColorTextEdit's render, its overlays' updates, and the glue's draw.
module figure_code_view
!< figure_code_view, the code editor drawn: ImGuiColorTextEdit's render, its overlays' updates, and the glue's draw.
!<
!< szaghi/figure#15 P16. `fig_editor_draw` is the glue's (`native/figure_editor.cpp`): the style's palette (the fork's
!< dark or light one by the window background's lightness, with the style's text, background, selection and line-number
!< colours), IBM Plex Mono pushed, the fork's `render` in a bordered child window, the child's rectangle kept for
!< `fig_editor_line_rect`. `render` is the fork's, in its order: the state updated (`updateState`: colours, bracket
!< pairs, cursors, the layout, the markers' list compressed after deletions, the content size), the scroll requests
!< applied, the keys and the mouse, then the current line, the active bracket pair, selections, marked lines, bracket
!< pairs' lines, text and carets (clipped to the text area), the line numbers' marks, the line numbers, the marks'
!< icons (the glue's decorator), the popups. Every coordinate is single precision in the fork's operation order; the C
!< library's `log10f`, `log10` and `fmodf` are called where the fork calls them. Drawing and Dear ImGui's state go
!< through figure_core_text (`ct_*`).
!<
!< The type setter is the fork's without word wrap and folding: a row is a line, a glyph's columns its width (a tab to
!< the next stop); the bracketeer is the fork's, its pairs' colours in the glyphs, an unmatched bracket the error colour
!< (a closer of the wrong kind drops the last pair recorded, as the fork's `pop_back` does).
use, intrinsic :: iso_c_binding, only : c_char, c_double, c_float, c_int, c_long_long
use, intrinsic :: iso_fortran_env, only : int8, int32, int64
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_OK, fig_pop_font, fig_push_font
use figure_cimgui_enums, only : ImGuiChildFlags_Borders, ImGuiCol_ChildBg, ImGuiCol_FrameBg, ImGuiCol_PopupBg, &
                                ImGuiCol_Text, ImGuiCol_TextDisabled, ImGuiCol_TextSelectedBg, ImGuiCol_WindowBg, &
                                ImGuiStyleVar_ItemSpacing, ImGuiWindowFlags_HorizontalScrollbar, ImGuiWindowFlags_NoMove
use figure_code_document, only : code_pos, cursor_has_selection, cursor_selection_end, cursor_selection_start,         &
                                 cursors_any_selection, cursors_update, pos, pos_le, pos_lt, COLOR_BACKGROUND,         &
                                 COLOR_BRACKET_ACTIVE, COLOR_BRACKET_BACKGROUND, COLOR_BRACKET_ERROR,                  &
                                 COLOR_BRACKET_LEVEL1, COLOR_BRACKET_LEVEL2, COLOR_BRACKET_LEVEL3, COLOR_CURSOR,       &
                                 COLOR_CURRENT_LINE, COLOR_CURRENT_LINE_BORDER, COLOR_CURRENT_LINE_NUMBER,              &
                                 COLOR_LINE_NUMBER, COLOR_PUNCTUATION, COLOR_SELECTION, COLOR_TEXT, COLOR_WHITESPACE
use figure_code_editor, only : code_editor, editor_get, fail, line_severity, marker_tooltip, not_found, str, &
                               INVALID, N_SEVERITY, SEVERITY_RGB
use figure_code_language, only : colorize, lang_indentation_blocks
use figure_code_unicode, only : cp_glyph_width, cp_is_bracket_closer, cp_is_bracket_opener, cp_to_pair_opener
use figure_core_text, only : ct_begin_child, ct_begin_popup, ct_begin_tooltip, ct_char, ct_circle_filled, ct_clip_rect, &
                             ct_color_u32, ct_cursor_screen_pos, ct_end_child, ct_end_popup, ct_end_tooltip,            &
                             ct_float4_to_u32, ct_font_size, ct_hovering_rect, ct_item_rect, ct_line,                   &
                             ct_line_height_with_spacing, ct_nav, ct_pop_clip, ct_pop_id, ct_pop_style_color,          &
                             ct_pop_style_var, ct_popup_open, ct_push_clip, ct_push_id_int, ct_push_style_color_u32,    &
                             ct_push_style_var_vec2, ct_rect, ct_rect_filled, ct_scroll, ct_set_cursor_screen_pos,      &
                             ct_set_next_window_content_size, ct_set_next_window_focus, ct_set_scroll_x,                &
                             ct_set_scroll_y, ct_state, ct_style_color, ct_text, ct_text_unformatted, ct_text_width,    &
                             ct_window_focused, ct_window_pos

implicit none
private
public :: fig_editor_draw, fig_editor_line_rect
public :: vis_pos, doc_pos_of, normalize_vis, update_state, handle_scrolling, enclosing_brackets, palette_color

!< The marks' icons (circle-x, triangle-alert, info: FIGURE's icon font), by severity.
character(len=3), parameter :: SEVERITY_ICON(N_SEVERITY) = [achar(238)//achar(130)//achar(132), &
                                                            achar(238)//achar(134)//achar(147), &
                                                            achar(238)//achar(131)//achar(185)]
integer(int32), parameter :: DECORATOR_WIDTH = 2_int32 !< The glue's decoration column [glyphs].

interface
   pure function c_log10f(x) result(r) bind(C, name='log10f')
   !< C's `log10f`.
   import :: c_float
   implicit none
   real(c_float), value :: x !< Argument.
   real(c_float)        :: r !< Result.
   endfunction c_log10f

   pure function c_log10(x) result(r) bind(C, name='log10')
   !< C's `log10`.
   import :: c_double
   implicit none
   real(c_double), value :: x !< Argument.
   real(c_double)        :: r !< Result.
   endfunction c_log10

   pure function c_fmodf(x, y) result(r) bind(C, name='fmodf')
   !< C's `fmodf`.
   import :: c_float
   implicit none
   real(c_float), value :: x, y !< Arguments.
   real(c_float)        :: r    !< Result.
   endfunction c_fmodf
endinterface

contains
   ! ---- colours ------------------------------------------------------------------------------------------------------
   pure function col32(r, g, b, a) result(c)
   !< `IM_COL32(r, g, b, a)` as a signed 32-bit integer.
   integer(int32), intent(in) :: r, g, b, a !< Channels.
   integer(c_int)             :: c          !< Packed.

   c = u32(ior(ior(int(r, int64), ishft(int(g, int64), 8)), ior(ishft(int(b, int64), 16), ishft(int(a, int64), 24))))
   endfunction col32

   pure function u32(v) result(c)
   !< An unsigned 32-bit value as a signed 32-bit integer (the same bits).
   integer(int64), intent(in) :: v !< Value in [0, 2^32).
   integer(c_int)             :: c !< Same bits.

   if (v >= 2147483648_int64) then
      c = int(v - 4294967296_int64, c_int)
   else
      c = int(v, c_int)
   endif
   endfunction u32

   pure function alpha_of(c) result(a)
   !< The alpha byte of a packed colour.
   integer(c_int), intent(in) :: c !< Colour.
   integer(int32)             :: a !< Alpha.

   a = iand(ishft(c, -24), 255_c_int)
   endfunction alpha_of

   pure subroutine dark_palette(p)
   !< `TextEditor::GetDarkPalette`.
   integer(c_int), intent(out) :: p(0:32) !< Palette.

   p = [col32(224, 224, 224, 255), col32(197, 134, 192, 255), col32(90, 179, 155, 255), col32(181, 206, 168, 255), &
        col32(206, 145, 120, 255), col32(255, 255, 153, 255), col32(64, 192, 128, 255), col32(156, 220, 254, 255), &
        col32(79, 193, 255, 255), col32(106, 153, 85, 255), col32(30, 30, 30, 255), col32(224, 224, 224, 255),     &
        col32(32, 96, 160, 255), col32(80, 80, 80, 255), col32(70, 70, 70, 255), col32(140, 140, 140, 255),        &
        col32(246, 222, 36, 255), col32(66, 120, 198, 255), col32(213, 96, 213, 255), col32(198, 8, 32, 255),      &
        col32(128, 128, 144, 255), col32(224, 224, 240, 255), col32(255, 255, 255, 8), col32(255, 255, 255, 16),  &
        col32(255, 0, 0, 255), col32(245, 140, 0, 255), col32(255, 255, 40, 255), col32(0, 255, 0, 255),          &
        col32(63, 255, 205, 255), col32(70, 240, 240, 255), col32(0, 0, 255, 255), col32(145, 0, 224, 255),        &
        col32(240, 50, 230, 255)]
   endsubroutine dark_palette

   pure subroutine light_palette(p)
   !< `TextEditor::GetLightPalette`.
   integer(c_int), intent(out) :: p(0:32) !< Palette.

   p = [col32(64, 64, 64, 255), col32(170, 0, 220, 255), col32(65, 0, 255, 255), col32(40, 140, 90, 255),        &
        col32(160, 32, 32, 255), col32(0, 0, 0, 255), col32(96, 96, 64, 255), col32(64, 64, 64, 255),             &
        col32(16, 96, 96, 255), col32(35, 135, 5, 255), col32(255, 255, 255, 255), col32(0, 0, 0, 255),           &
        col32(0, 0, 96, 64), col32(144, 144, 144, 144), col32(180, 180, 180, 144), col32(72, 72, 72, 255),        &
        col32(70, 0, 250, 255), col32(80, 160, 70, 255), col32(120, 60, 25, 255), col32(198, 8, 32, 255),         &
        col32(0, 80, 80, 255), col32(0, 0, 0, 255), col32(0, 0, 0, 8), col32(0, 0, 0, 16),                       &
        col32(255, 0, 0, 255), col32(245, 140, 0, 255), col32(255, 255, 40, 255), col32(0, 255, 0, 255),          &
        col32(63, 255, 205, 255), col32(70, 240, 240, 255), col32(0, 0, 255, 255), col32(145, 0, 224, 255),        &
        col32(240, 50, 230, 255)]
   endsubroutine light_palette

   subroutine style_palette(p)
   !< The glue's `style_palette`: the fork's dark or light palette (by the window background's lightness) with the
   !< style's text, background, selection and line-number colours.
   integer(c_int), intent(out) :: p(0:32) !< Palette.
   real(c_float)               :: bg(4), top(4), c(4), t1, t2, t3, lum, a !< Colours, lightness, alpha.
   integer(int32)              :: k  !< Channel.

   call ct_style_color(ImGuiCol_WindowBg, bg)
   t1 = 0.2126_c_float * bg(1)
   t2 = 0.7152_c_float * bg(2)
   t3 = 0.0722_c_float * bg(3)
   lum = (t1 + t2) + t3
   if (lum > 0.5_c_float) then
      call light_palette(p)
   else
      call dark_palette(p)
   endif
   call ct_style_color(ImGuiCol_FrameBg, top)
   a = top(4)
   do k = 1_int32, 3_int32
      t1 = top(k) * a
      t2 = bg(k) * (1.0_c_float - a)
      c(k) = t1 + t2
   enddo
   c(4) = 1.0_c_float
   p(COLOR_BACKGROUND) = ct_float4_to_u32(c)
   call ct_style_color(ImGuiCol_Text, c)
   p(COLOR_TEXT) = ct_float4_to_u32(c)
   p(COLOR_CURSOR) = ct_float4_to_u32(c)
   p(COLOR_CURRENT_LINE_NUMBER) = ct_float4_to_u32(c)
   call ct_style_color(ImGuiCol_TextSelectedBg, c)
   p(COLOR_SELECTION) = ct_float4_to_u32(c)
   call ct_style_color(ImGuiCol_TextDisabled, c)
   p(COLOR_LINE_NUMBER) = ct_float4_to_u32(c)
   endsubroutine style_palette

   pure function palette_color(e, k) result(c)
   !< `palette.get(k)`.
   type(code_editor), intent(in) :: e !< Editor.
   integer(int8),     intent(in) :: k !< Colour.
   integer(c_int)                :: c !< Packed.

   c = e%palette(k)
   endfunction palette_color

   ! ---- the type setter ----------------------------------------------------------------------------------------------
   subroutine typeset_line(e, k)
   !< `TypeSetter::updateLine` (no wrap): the glyphs' columns, the line's columns, one row.
   type(code_editor), intent(inout) :: e !< Editor.
   integer(int32),    intent(in)    :: k !< Line, from 1.
   integer(int32)                   :: j, c, w !< Glyph, columns, width.

   c = 0_int32
   associate(line => e%doc%lines(k))
      do j = 1_int32, line%n
         if (line%cp(j) == 9_int32) then
            w = e%ts_tab - mod(c, e%ts_tab)
         else
            w = cp_glyph_width(line%cp(j))
         endif
         line%cols(j) = int(w, int8)
         c = c + w
      enddo
      line%rows = 1_int32
      line%columns = c
      line%needs_typesetting = .false.
   endassociate
   endsubroutine typeset_line

   subroutine typeset(e, updated)
   !< `TypeSetter::update`.
   type(code_editor), intent(inout) :: e       !< Editor.
   logical,           intent(out)   :: updated !< The layout changed.
   integer(int32), allocatable      :: more(:) !< Grown row array.
   logical                          :: changed !< The tab size changed.
   integer(int32)                   :: k       !< Line.

   changed = e%ts_tab /= e%tab_size
   if (changed) then
      e%ts_tab = e%tab_size
      do k = 1_int32, e%doc%n
         call typeset_line(e, k)
      enddo
   elseif (e%doc%updated) then
      do k = 1_int32, e%doc%n
         if (e%doc%lines(k)%needs_typesetting) call typeset_line(e, k)
      enddo
   endif
   updated = changed .or. e%doc%updated
   if (.not. updated) return
   if (.not. allocated(e%ts_cols)) allocate(e%ts_cols(max(16_int32, e%doc%n)))
   if (size(e%ts_cols, kind=int32) < e%doc%n) then
      allocate(more(2_int32 * e%doc%n))
      call move_alloc(more, e%ts_cols)
   endif
   e%ts_rows = e%doc%n
   e%ts_columns = 0_int32
   do k = 1_int32, e%doc%n
      e%doc%lines(k)%row = k - 1_int32
      e%ts_columns = max(e%ts_columns, e%doc%lines(k)%columns)
      e%ts_cols(k) = e%doc%lines(k)%columns
   enddo
   endsubroutine typeset

   pure subroutine vis_pos(e, p, row, col)
   !< `docPos2VisPos`.
   type(code_editor), intent(in)  :: e        !< Editor.
   type(code_pos),    intent(in)  :: p        !< Position.
   integer(int32),    intent(out) :: row, col !< Visual position.
   integer(int32)                 :: j        !< Glyph.

   row = 0_int32
   col = 0_int32
   if (e%ts_rows == 0_int32) return
   row = e%doc%lines(p%l + 1)%row
   do j = 1_int32, p%i
      col = col + e%doc%lines(p%l + 1)%cols(j)
   enddo
   endsubroutine vis_pos

   pure function doc_pos_of(e, row, col) result(p)
   !< `visPos2DocPos`.
   type(code_editor), intent(in) :: e        !< Editor.
   integer(int32),    intent(in) :: row, col !< Visual position.
   type(code_pos)                :: p        !< Position.
   integer(int32)                :: idx, left, right, j !< Glyph index, columns.

   p = pos(0_int32, 0_int32)
   if (row >= e%ts_rows .or. row < 0_int32) return
   p%l = row
   idx = 0_int32
   left = 0_int32
   right = 0_int32
   j = 1_int32
   associate(line => e%doc%lines(row + 1))
      do while (right < col .and. j <= line%n)
         left = right
         right = right + line%cols(j)
         idx = idx + 1_int32
         j = j + 1_int32
      enddo
   endassociate
   if (right - left <= 1_int32) then
      p%i = idx
   elseif (col - left <= right - col) then
      p%i = idx - 1_int32
   else
      p%i = idx
   endif
   endfunction doc_pos_of

   pure subroutine normalize_vis(e, row, col)
   !< `TypeSetter::normalizePos`.
   type(code_editor), intent(in)    :: e        !< Editor.
   integer(int32),    intent(inout) :: row, col !< Visual position.

   if (e%ts_rows == 0_int32) then
      row = 0_int32
      col = 0_int32
   elseif (row >= e%ts_rows) then
      row = e%ts_rows - 1_int32
      col = e%ts_cols(row + 1)
   elseif (col > e%ts_cols(row + 1)) then
      col = e%ts_cols(row + 1)
   endif
   endsubroutine normalize_vis

   ! ---- the bracketeer -----------------------------------------------------------------------------------------------
   pure function candidate(c) result(yes)
   !< `isBracketCandidate`: punctuation or a bracket's colour (not in a comment, a string, a preprocessor line).
   integer(int8), intent(in) :: c   !< Glyph colour.
   logical                   :: yes !< A candidate.

   yes = c == COLOR_PUNCTUATION .or. c == COLOR_BRACKET_LEVEL1 .or. c == COLOR_BRACKET_LEVEL2 .or. &
         c == COLOR_BRACKET_LEVEL3 .or. c == COLOR_BRACKET_ERROR
   endfunction candidate

   subroutine bracket_reserve(e, n)
   !< Room for n pairs.
   type(code_editor), intent(inout) :: e !< Editor.
   integer(int32),    intent(in)    :: n !< Pairs.
   type(code_pos), allocatable      :: s(:), t(:) !< Positions.
   integer(int32), allocatable      :: a(:), b(:), c(:) !< Characters, levels.
   logical, allocatable             :: v(:) !< Visible.
   integer(int32)                   :: m    !< Capacity.

   if (allocated(e%br_start)) then
      if (size(e%br_start, kind=int32) >= n) return
      m = max(n, 2_int32 * size(e%br_start, kind=int32))
   else
      m = max(n, 16_int32)
   endif
   allocate(s(m), t(m), a(m), b(m), c(m), v(m))
   if (allocated(e%br_start)) then
      s(1:e%nb) = e%br_start(1:e%nb)
      t(1:e%nb) = e%br_end(1:e%nb)
      a(1:e%nb) = e%br_open(1:e%nb)
      b(1:e%nb) = e%br_close(1:e%nb)
      c(1:e%nb) = e%br_level(1:e%nb)
      v(1:e%nb) = e%br_visible(1:e%nb)
   endif
   call move_alloc(s, e%br_start)
   call move_alloc(t, e%br_end)
   call move_alloc(a, e%br_open)
   call move_alloc(b, e%br_close)
   call move_alloc(c, e%br_level)
   call move_alloc(v, e%br_visible)
   endsubroutine bracket_reserve

   subroutine bracket_add(e, open, a, close, b, level, visible)
   !< A pair appended.
   type(code_editor), intent(inout) :: e           !< Editor.
   integer(int32),    intent(in)    :: open, close !< Characters.
   type(code_pos),    intent(in)    :: a, b        !< Positions.
   integer(int32),    intent(in)    :: level       !< Level.
   logical,           intent(in)    :: visible     !< Visible.

   call bracket_reserve(e, e%nb + 1_int32)
   e%nb = e%nb + 1_int32
   e%br_start(e%nb) = a
   e%br_end(e%nb) = b
   e%br_open(e%nb) = open
   e%br_close(e%nb) = close
   e%br_level(e%nb) = level
   e%br_visible(e%nb) = visible
   endsubroutine bracket_add

   subroutine bracket_erase(e, k)
   !< Pair k (from 1) erased.
   type(code_editor), intent(inout) :: e !< Editor.
   integer(int32),    intent(in)    :: k !< Pair.
   integer(int32)                   :: j !< Counter.

   do j = k, e%nb - 1_int32
      e%br_start(j) = e%br_start(j + 1)
      e%br_end(j) = e%br_end(j + 1)
      e%br_open(j) = e%br_open(j + 1)
      e%br_close(j) = e%br_close(j + 1)
      e%br_level(j) = e%br_level(j + 1)
      e%br_visible(j) = e%br_visible(j + 1)
   enddo
   e%nb = e%nb - 1_int32
   endsubroutine bracket_erase

   subroutine bracketeer(e)
   !< `Bracketeer::update`.
   type(code_editor), intent(inout) :: e      !< Editor.
   integer(int8), parameter         :: LEVELS(0:2) = [COLOR_BRACKET_LEVEL1, COLOR_BRACKET_LEVEL2, &
                                                      COLOR_BRACKET_LEVEL3] !< Pairs' colours by level.
   integer(int32), allocatable      :: stack(:) !< Open pairs (indices, from 1).
   integer(int32)                   :: ns, level, l, i, j, cur, last, k !< Counters.
   logical                          :: changed, done !< Configuration changed, a block ended.
   type(code_pos)                   :: t      !< Swap.

   changed = (e%bk_show .neqv. e%matching_brackets) .or. e%bk_language /= e%language
   e%bk_show = e%matching_brackets
   e%bk_language = e%language
   if (changed .and. .not. e%bk_show) then
      e%nb = 0_int32
      do l = 1_int32, e%doc%n
         do i = 1_int32, e%doc%lines(l)%n
            associate(c => e%doc%lines(l)%color(i))
               if (c == COLOR_BRACKET_LEVEL1 .or. c == COLOR_BRACKET_LEVEL2 .or. c == COLOR_BRACKET_LEVEL3 .or. &
                   c == COLOR_BRACKET_ERROR) c = COLOR_PUNCTUATION
            endassociate
         enddo
      enddo
      return
   endif
   if (.not. (e%bk_show .and. (changed .or. e%doc%updated))) return
   e%nb = 0_int32
   allocate(stack(16))
   ns = 0_int32
   level = 0_int32
   do l = 1_int32, e%doc%n
      do i = 1_int32, e%doc%lines(l)%n
         associate(cp => e%doc%lines(l)%cp(i), c => e%doc%lines(l)%color(i))
            if (candidate(c) .and. cp_is_bracket_opener(cp)) then
               if (ns == size(stack, kind=int32)) stack = [stack, stack]
               ns = ns + 1_int32
               stack(ns) = e%nb + 1_int32
               call bracket_add(e, cp, pos(l - 1_int32, i - 1_int32), 0_int32, pos(0_int32, 0_int32), level, .true.)
               c = LEVELS(mod(level, 3_int32))
               level = level + 1_int32
            elseif (candidate(c) .and. cp_is_bracket_closer(cp)) then
               if (ns > 0_int32) then
                  k = stack(ns)
                  ns = ns - 1_int32
                  level = level - 1_int32
                  if (e%br_open(k) == cp_to_pair_opener(cp)) then
                     c = LEVELS(mod(level, 3_int32))
                     e%br_close(k) = cp
                     e%br_end(k) = pos(l - 1_int32, i - 1_int32)
                  else
                     c = COLOR_BRACKET_ERROR
                     e%doc%lines(e%br_start(k)%l + 1)%color(e%br_start(k)%i + 1) = COLOR_BRACKET_ERROR
                     e%nb = e%nb - 1_int32 ! the fork's pop_back: the last pair recorded
                  endif
               else
                  c = COLOR_BRACKET_ERROR
               endif
            endif
         endassociate
      enddo
   enddo
   do j = ns, 1_int32, -1_int32
      k = stack(j)
      e%doc%lines(e%br_start(k)%l + 1)%color(e%br_start(k)%i + 1) = COLOR_BRACKET_ERROR
      call bracket_erase(e, k)
   enddo
   if (lang_indentation_blocks(e%language)) then
      do i = 1_int32, e%doc%n
         if (e%doc%lines(i)%n == 0_int32) cycle
         last = i
         done = .false.
         j = i + 1_int32
         do while (j <= e%doc%n .and. .not. done)
            if (e%doc%lines(j)%n > 0_int32) then
               if (e%doc%lines(j)%indent > e%doc%lines(i)%indent) then
                  last = j
               else
                  done = .true.
               endif
            endif
            j = j + 1_int32
         enddo
         if (last > i) call bracket_add(e, 0_int32, pos(i - 1_int32, 0_int32), 0_int32, &
                                         pos(last - 1_int32, e%doc%lines(last)%n), 0_int32, .false.)
      enddo
      ! sorted by start (stable)
      do k = 2_int32, e%nb
         cur = k
         do while (cur > 1_int32)
            if (.not. pos_lt(e%br_start(cur), e%br_start(cur - 1))) exit
            t = e%br_start(cur); e%br_start(cur) = e%br_start(cur - 1); e%br_start(cur - 1) = t
            t = e%br_end(cur); e%br_end(cur) = e%br_end(cur - 1); e%br_end(cur - 1) = t
            call swap_i(e%br_open(cur), e%br_open(cur - 1))
            call swap_i(e%br_close(cur), e%br_close(cur - 1))
            call swap_i(e%br_level(cur), e%br_level(cur - 1))
            call swap_l(e%br_visible(cur), e%br_visible(cur - 1))
            cur = cur - 1_int32
         enddo
      enddo
   endif
   endsubroutine bracketeer

   pure subroutine swap_i(a, b)
   !< Swap two integers.
   integer(int32), intent(inout) :: a, b !< Values.
   integer(int32)                :: t    !< Swap.

   t = a
   a = b
   b = t
   endsubroutine swap_i

   pure subroutine swap_l(a, b)
   !< Swap two logicals.
   logical, intent(inout) :: a, b !< Values.
   logical                :: t    !< Swap.

   t = a
   a = b
   b = t
   endsubroutine swap_l

   pure function enclosing_brackets(e, p) result(k)
   !< `getEnclosingBrackets(location)`: the last pair around `p` (from 1; 0 none).
   type(code_editor), intent(in) :: e !< Editor.
   type(code_pos),    intent(in) :: p !< Location.
   integer(int32)                :: k !< Pair.
   integer(int32)                :: j !< Counter.

   k = 0_int32
   do j = 1_int32, e%nb
      if (pos_lt(p, e%br_start(j))) exit
      if (pos_lt(e%br_start(j), p) .and. pos_le(p, e%br_end(j))) k = j
   enddo
   endfunction enclosing_brackets

   ! ---- the state ----------------------------------------------------------------------------------------------------
   subroutine compress_markers(e)
   !< `compressMarkers` (with FIGURE's patch 0001: the new indices kept whole).
   type(code_editor), intent(inout) :: e    !< Editor.
   logical,        allocatable      :: used(:) !< Markers in use.
   integer(int32), allocatable      :: index(:) !< Their new indices.
   character(len=:), allocatable    :: pool !< Kept tooltips.
   integer(int32)                   :: k, n !< Counters.
   integer(int64)                   :: used_bytes !< Pool used.

   if (e%nm == 0_int32) return
   allocate(used(e%nm), index(e%nm))
   used = .false.
   index = 0_int32
   do k = 1_int32, e%doc%n
      if (e%doc%lines(k)%marker > 0_int32) used(e%doc%lines(k)%marker) = .true.
   enddo
   n = 0_int32
   do k = 1_int32, e%nm
      if (used(k)) then
         index(k) = n
         n = n + 1_int32
      endif
   enddo
   do k = 1_int32, e%doc%n
      if (e%doc%lines(k)%marker > 0_int32) e%doc%lines(k)%marker = index(e%doc%lines(k)%marker) + 1_int32
   enddo
   allocate(character(len=len(e%mk_pool)) :: pool)
   used_bytes = 0_int64
   n = 0_int32
   do k = 1_int32, e%nm
      if (.not. used(k)) cycle
      n = n + 1_int32
      e%mk_number(n) = e%mk_number(k)
      e%mk_text(n) = e%mk_text(k)
      pool(used_bytes + 1_int64:used_bytes + e%mk_len(k)) = e%mk_pool(e%mk_off(k) + 1_int64:e%mk_off(k) + e%mk_len(k))
      e%mk_off(n) = used_bytes
      e%mk_len(n) = e%mk_len(k)
      used_bytes = used_bytes + e%mk_len(k)
   enddo
   e%nm = n
   e%mk_used = used_bytes
   call move_alloc(pool, e%mk_pool)
   endsubroutine compress_markers

   subroutine update_state(e, changed)
   !< `updateState`: the overlays brought up to date; whether the document changed (since the last call).
   type(code_editor), intent(inout) :: e        !< Editor.
   logical,           intent(out)   :: changed  !< The document changed.
   logical                          :: lang_changed, laid_out !< The language, the layout changed.
   real(c_float)                    :: sx, sy, f !< Scroll, first line's fraction.
   integer(int32)                   :: previous !< The first visible line before.

   call colorize(e%doc, e%language, e%colored, lang_changed)
   call bracketeer(e)
   call cursors_update(e%cursors)
   call ct_scroll(sx, sy)
   f = sy / e%glyph_h
   f = f - aint(f)
   previous = 0_int32
   if (e%first_row < e%ts_rows) previous = e%first_row
   call typeset(e, laid_out)
   if (laid_out) then
      if (e%scroll_to_line == INVALID .and. e%scroll_to%l == INVALID) then
         e%scroll_to = pos(INVALID, 0_int32)
         e%scroll_to_line = min(previous, e%doc%n - 1_int32)
         e%scroll_align = 0_int32
         e%scroll_fraction = f
      endif
   endif
   if (e%deletes_happened) then
      if (e%nm > 0_int32) call compress_markers(e)
      e%deletes_happened = .false.
   endif
   changed = e%doc%updated
   e%doc%updated = .false.
   e%total_w = e%text_left + real(e%ts_columns, c_float) * e%glyph_w + e%cursor_width
   e%total_h = real(e%ts_rows, c_float) * e%glyph_h
   endsubroutine update_state

   subroutine handle_scrolling(e)
   !< `handlePossibleScrolling` (no smooth scrolling).
   type(code_editor), intent(inout) :: e        !< Editor.
   real(c_float)                    :: sx, sy, row, visible_rows !< Scroll asked, a row, rows in view.
   integer(int32)                   :: r, c     !< A visual position.
   type(code_pos)                   :: p        !< Position.

   sx = -1.0_c_float
   sy = -1.0_c_float
   if (e%scroll_to%l /= INVALID) then
      if (e%last_row == 0_int32 .and. e%last_column == 0_int32) then
         e%last_row = min(int(ceiling(e%text_h / e%glyph_h), int32), e%ts_rows - 1_int32)
         e%last_column = int(ceiling(e%text_w / e%glyph_w), int32)
      endif
      p = normalize_doc(e, e%scroll_to)
      call vis_pos(e, p, r, c)
      if (r <= e%first_row + 1_int32) then
         sy = max(0.0_c_float, (real(r, c_float) - 2.0_c_float) * e%glyph_h)
      elseif (e%last_row >= 1_int32 .and. r >= e%last_row - 1_int32) then
         sy = max(0.0_c_float, (real(r, c_float) + 2.0_c_float) * e%glyph_h - e%text_h)
      endif
      if (c <= e%first_column + 1_int32) then
         sx = max(0.0_c_float, (real(c, c_float) - 2.0_c_float) * e%glyph_w)
      elseif (e%last_column >= 1_int32 .and. c >= e%last_column - 1_int32) then
         sx = max(0.0_c_float, (real(c, c_float) + 2.0_c_float) * e%glyph_w - e%text_w)
      endif
      e%scroll_to%l = INVALID
   endif
   if (e%scroll_to_line /= INVALID) then
      call vis_pos(e, pos(min(e%scroll_to_line, e%doc%n - 1_int32), 0_int32), r, c)
      row = real(r, c_float)
      visible_rows = e%text_h / e%glyph_h
      sx = 0.0_c_float
      select case (e%scroll_align)
      case (0_int32)
         sy = (row + e%scroll_fraction) * e%glyph_h
      case (1_int32)
         sy = max(0.0_c_float, (row - visible_rows / 2.0_c_float) * e%glyph_h)
      case default
         sy = max(0.0_c_float, (row - (visible_rows - 1.0_c_float)) * e%glyph_h)
      endselect
      e%scroll_to_line = INVALID
   endif
   if (sx >= 0.0_c_float) call ct_set_scroll_x(sx)
   if (sy >= 0.0_c_float) call ct_set_scroll_y(sy)
   endsubroutine handle_scrolling

   pure function normalize_doc(e, p) result(q)
   !< `Document::normalizePos`.
   type(code_editor), intent(in) :: e !< Editor.
   type(code_pos),    intent(in) :: p !< Position.
   type(code_pos)                :: q !< Clamped.

   if (p%l >= e%doc%n .or. p%l < 0_int32) then
      q = pos(e%doc%n - 1_int32, e%doc%lines(e%doc%n)%n)
   elseif (p%i > e%doc%lines(p%l + 1)%n) then
      q = pos(p%l, e%doc%lines(p%l + 1)%n)
   else
      q = p
   endif
   endfunction normalize_doc

   ! ---- the render ---------------------------------------------------------------------------------------------------
   subroutine render(e, title, w, h, changed)
   !< `TextEditor::render` (a bordered child window, NoMove and HorizontalScrollbar).
   type(code_editor), intent(inout) :: e       !< Editor.
   character(len=*),  intent(in)    :: title   !< Child id.
   real(c_float),     intent(in)    :: w, h    !< Size.
   logical,           intent(out)   :: changed !< The document changed this frame.
   real(c_float)                    :: f(16), sx, sy, wx, wy, cx0, cy0, cx1, cy1 !< State, scroll, window, clip.
   integer(c_int)                   :: fi(5)   !< Flags.
   integer(int32)                   :: digits, k !< Line number digits, counter.
   logical                          :: unused  !< A change before the keys.

   changed = .false.
   if (.not. e%first_frame) then
      if (e%focus_on_editor) then
         call ct_set_next_window_focus()
         e%focus_on_editor = .false.
      endif
   else
      e%first_frame = .false.
   endif
   call ct_set_next_window_content_size(e%total_w, e%total_h)
   call ct_push_style_var_vec2(ImGuiStyleVar_ItemSpacing, 0.0_c_float, 0.0_c_float)
   call ct_push_style_color_u32(ImGuiCol_ChildBg, e%palette(COLOR_BACKGROUND))
   if (ct_begin_child(title, w, h, ImGuiChildFlags_Borders, &
                      ior(ImGuiWindowFlags_NoMove, ImGuiWindowFlags_HorizontalScrollbar))) then
      if (e%reset_scrolling) then
         call ct_set_scroll_x(0.0_c_float)
         call ct_set_scroll_y(0.0_c_float)
         e%reset_scrolling = .false.
      endif
      call ct_state(f, fi)
      e%font_size = ct_font_size()
      e%font_scale = f(3)
      e%glyph_w = ct_text_width('#')
      e%glyph_h = ct_line_height_with_spacing() * 1.0_c_float
      call ct_cursor_screen_pos(e%screen_x, e%screen_y)
      e%visible_w = f(1)
      e%visible_h = f(2)
      e%number_left = 1.0_c_float * e%glyph_w
      if (e%line_numbers) then
         digits = int(c_log10f(real(e%doc%n + 1_int32, c_float)) + 1.0_c_float, int32)
         e%number_right = e%number_left + real(digits, c_float) * e%glyph_w
      else
         e%number_right = e%number_left
      endif
      e%decoration_offset = e%number_right + 1.0_c_float * e%glyph_w
      e%text_left = e%decoration_offset + real(DECORATOR_WIDTH + 2_int32, c_float) * e%glyph_w
      e%text_right = e%visible_w
      e%text_w = e%text_right - e%text_left
      e%text_h = e%visible_h
      call update_state(e, unused)
      call handle_scrolling(e)
      ! the keys (a later step)
      call update_state(e, changed)
      ! the mouse (a later step)
      call ct_scroll(sx, sy)
      e%first_row = int(floor(sy / e%glyph_h), int32)
      e%last_row = min(int(ceiling((sy + e%text_h) / e%glyph_h), int32), e%ts_rows - 1_int32)
      e%first_column = int(floor(sx / e%glyph_w), int32)
      e%last_column = int(ceiling((sx + e%text_w) / e%glyph_w), int32)
      if (e%palette_alpha /= f(5)) then
         do k = 0_int32, 32_int32
            e%palette(k) = ct_color_u32(e%palette_base(k))
         enddo
      endif
      e%cursor_width = f(4)
      call ct_window_pos(wx, wy)
      call ct_clip_rect(cx0, cy0, cx1, cy1)
      call ct_push_clip(wx + e%text_left - e%cursor_width, cy0, wx + e%text_right + e%cursor_width, cy1, .true.)
      call render_current_line(e)
      call render_active_brackets(e)
      call render_selections(e)
      call render_text_markers(e)
      call render_bracket_lines(e)
      call render_text(e)
      call render_carets(e, f(6), fi(2) /= 0_c_int)
      call ct_pop_clip()
      call render_number_markers(e)
      call render_numbers(e, wx)
      call render_decorations(e, wx)
      call render_popups(e)
      call handle_scrolling(e)
      call ct_nav(e%font_scale)
   endif
   call ct_end_child()
   call ct_pop_style_color(1_c_int)
   call ct_pop_style_var(1_c_int)
   endsubroutine render

   subroutine render_current_line(e)
   !< `renderCurrentLineHighlight` (the fork's x: the text's left offset, not added to the screen position).
   type(code_editor), intent(inout) :: e    !< Editor.
   integer(int32)                   :: k, j, l, row, rows !< Cursors, a line, its rows.
   logical                          :: seen !< Line already drawn.
   real(c_float)                    :: x0, y0, x1, y1 !< Rectangle.

   if (.not. e%line_highlight .or. cursors_any_selection(e%cursors)) return
   do k = 1_int32, e%cursors%n
      l = e%cursors%c(k)%end%l
      seen = .false.
      do j = 1_int32, k - 1_int32
         if (e%cursors%c(j)%end%l == l) seen = .true.
      enddo
      if (seen) cycle
      row = e%doc%lines(l + 1)%row
      rows = e%doc%lines(l + 1)%rows
      x0 = e%text_left
      y0 = e%screen_y + real(row, c_float) * e%glyph_h
      x1 = x0 + e%text_right
      y1 = y0 + real(rows, c_float) * e%glyph_h
      call ct_rect_filled(x0, y0, x1, y1, e%palette(COLOR_CURRENT_LINE))
      call ct_rect(x0, y0, x1, y1, e%palette(COLOR_CURRENT_LINE_BORDER))
   enddo
   endsubroutine render_current_line

   subroutine render_active_brackets(e)
   !< `renderActiveBracketBackground`.
   type(code_editor), intent(inout) :: e      !< Editor.
   integer(int32)                   :: k, r, c !< Pair, visual position.
   real(c_float)                    :: x, y   !< Corner.

   if (.not. e%matching_brackets .or. e%nb == 0_int32) return
   k = enclosing_brackets(e, e%cursors%c(e%cursors%main + 1)%end)
   if (k == 0_int32) return
   if (.not. e%br_visible(k)) return
   call vis_pos(e, e%br_start(k), r, c)
   if (r >= e%first_row .and. r <= e%last_row) then
      x = e%screen_x + e%text_left + real(c, c_float) * e%glyph_w
      y = e%screen_y + real(r, c_float) * e%glyph_h
      call ct_rect_filled(x, y, x + e%glyph_w, y + e%glyph_h, e%palette(COLOR_BRACKET_BACKGROUND))
   endif
   call vis_pos(e, e%br_end(k), r, c)
   if (r >= e%first_row .and. r <= e%last_row) then
      x = e%screen_x + e%text_left + real(c, c_float) * e%glyph_w
      y = e%screen_y + real(r, c_float) * e%glyph_h
      call ct_rect_filled(x, y, x + e%glyph_w, y + e%glyph_h, e%palette(COLOR_BRACKET_BACKGROUND))
   endif
   endsubroutine render_active_brackets

   subroutine render_selections(e)
   !< `renderSelections` (one row per line).
   type(code_editor), intent(inout) :: e   !< Editor.
   type(code_pos)                   :: a, b, left, right !< Selection, its part on a line.
   integer(int32)                   :: k, i, r0, c0, r1, c1 !< Cursor, line, visual positions.
   real(c_float)                    :: x, y !< Corner.

   do k = 1_int32, e%cursors%n
      if (.not. cursor_has_selection(e%cursors%c(k))) cycle
      a = cursor_selection_start(e%cursors%c(k))
      b = cursor_selection_end(e%cursors%c(k))
      do i = a%l, b%l
         associate(line => e%doc%lines(i + 1))
            if (line%row >= e%first_row .and. line%row <= e%last_row) then
               left = pos(i, 0_int32)
               right = pos(i, line%n)
               if (pos_le(a, left)) then
                  left = left
               else
                  left = a
               endif
               if (pos_lt(right, b)) then
                  right = right
               else
                  right = b
               endif
               call vis_pos(e, left, r0, c0)
               call vis_pos(e, right, r1, c1)
               x = e%screen_x + e%text_left
               y = e%screen_y + real(line%row, c_float) * e%glyph_h
               call ct_rect_filled(x + real(c0, c_float) * e%glyph_w, y, x + real(c1, c_float) * e%glyph_w, &
                                   y + e%glyph_h, e%palette(COLOR_SELECTION))
            endif
         endassociate
      enddo
   enddo
   endsubroutine render_selections

   subroutine render_text_markers(e)
   !< `renderTextMarkers`: a marked line tinted, its tooltip under the pointer.
   type(code_editor), intent(inout) :: e    !< Editor.
   integer(int32)                   :: row, m !< Row, marker.
   integer(c_int)                   :: col  !< Colour.
   real(c_float)                    :: x0, y0, x1 !< Rectangle.

   if (e%nm == 0_int32) return
   do row = e%first_row, e%last_row
      m = e%doc%lines(row + 1)%marker
      if (m == 0_int32) cycle
      col = u32(e%mk_text(m))
      if (alpha_of(col) == 0_int32) cycle
      y0 = e%screen_y + real(row, c_float) * e%glyph_h
      x0 = e%screen_x + e%text_left
      x1 = x0 + real(e%last_column, c_float) * e%glyph_w
      call ct_rect_filled(x0, y0, x1, y0 + e%glyph_h, col)
      if (e%mk_len(m) > 0_int64) then
         if (ct_hovering_rect(x0, y0, x1, y0 + e%glyph_h)) call tooltip(col, marker_tooltip(e, m))
      endif
   enddo
   endsubroutine render_text_markers

   subroutine tooltip(col, text)
   !< A tooltip of `text` on a background `col` (the fork's markers').
   integer(c_int),   intent(in) :: col  !< Background.
   character(len=*), intent(in) :: text !< Text.

   if (ct_begin_tooltip()) then
      call ct_push_style_color_u32(ImGuiCol_PopupBg, col)
      call ct_text_unformatted(text)
      call ct_pop_style_color(1_c_int)
      call ct_end_tooltip()
   endif
   endsubroutine tooltip

   subroutine render_bracket_lines(e)
   !< `renderMatchingBracketLines`.
   type(code_editor), intent(inout) :: e        !< Editor.
   integer(int32)                   :: k, active, r0, c0, r1, c1 !< Pairs, visual positions.
   real(c_float)                    :: x, y0, y1 !< The line.
   integer(int8)                    :: which    !< Its colour.

   if (.not. e%matching_brackets .or. e%nb == 0_int32) return
   active = enclosing_brackets(e, e%cursors%c(e%cursors%main + 1)%end)
   do k = 1_int32, e%nb
      if (.not. e%br_visible(k)) cycle
      call vis_pos(e, e%br_start(k), r0, c0)
      call vis_pos(e, e%br_end(k), r1, c1)
      if (r0 <= e%last_row .and. r1 >= e%first_row .and. (r1 - r0 > 1_int32 .or. r1 < r0)) then
         x = e%screen_x + e%text_left + real(min(c0, c1), c_float) * e%glyph_w
         y0 = e%screen_y + real(max(r0 + 1_int32, e%first_row), c_float) * e%glyph_h
         y1 = e%screen_y + real(min(r1, e%last_row), c_float) * e%glyph_h
         which = COLOR_WHITESPACE
         if (k == active) which = COLOR_BRACKET_ACTIVE
         call ct_line(x, y0, x, y1, e%palette(which))
      endif
   enddo
   endsubroutine render_bracket_lines

   subroutine render_text(e)
   !< `renderText`.
   type(code_editor), intent(inout) :: e        !< Editor.
   integer(int32)                   :: i, j, column, first_col !< Row, glyph, columns.
   real(c_float)                    :: rx, ry, gx, gy, x1, x2, y, d !< Positions.
   integer(int32)                   :: cp       !< Code point.

   rx = e%screen_x + e%text_left
   ry = e%screen_y + real(e%first_row, c_float) * e%glyph_h
   first_col = (e%first_column / e%tab_size) * e%tab_size
   do i = e%first_row, e%last_row
      associate(line => e%doc%lines(i + 1))
         j = 0_int32
         column = 0_int32
         do while (column < line%columns .and. column <= e%last_column)
            j = j + 1_int32
            cp = line%cp(j)
            gx = rx + real(column, c_float) * e%glyph_w
            gy = ry
            if (cp == 9_int32) then
               if (e%show_tabs .and. column >= first_col) then
                  x1 = gx + e%glyph_w * 0.3_c_float
                  if (e%short_tabs) then
                     x2 = gx + e%glyph_w
                  else
                     x2 = gx + (e%glyph_w * real(line%cols(j), c_float) - 1.0_c_float)
                  endif
                  y = gy + e%font_size * 0.5_c_float
                  d = e%font_size * 0.16_c_float
                  call ct_line(x1, y, x2, y, e%palette(COLOR_WHITESPACE))
                  call ct_line(x2, y, x2 - d, y - d, e%palette(COLOR_WHITESPACE))
                  call ct_line(x2, y, x2 - d, y + d, e%palette(COLOR_WHITESPACE))
               endif
            elseif (cp == 32_int32) then
               if (e%show_spaces .and. column >= first_col) then
                  call ct_circle_filled(gx + e%glyph_w * 0.5_c_float, gy + e%font_size * 0.5_c_float, 1.5_c_float, &
                                        e%palette(COLOR_WHITESPACE), 4_c_int)
               endif
            elseif (column >= first_col) then
               call ct_char(gx, gy, e%palette(line%color(j)), cp)
            endif
            column = column + line%cols(j)
         enddo
      endassociate
      ry = ry + e%glyph_h
   enddo
   endsubroutine render_text

   subroutine render_carets(e, dt, blink)
   !< `renderCursorCarets`.
   type(code_editor), intent(inout) :: e     !< Editor.
   real(c_float),     intent(in)    :: dt    !< io.DeltaTime.
   logical,           intent(in)    :: blink !< io.ConfigInputTextCursorBlink.
   integer(int32)                   :: k, r, c !< Cursor, visual position.
   logical                          :: shown !< The caret is on.
   real(c_float)                    :: x, y  !< Position.

   if (.not. e%carets_visible .or. .not. ct_window_focused()) return
   e%caret_timer = e%caret_timer + dt
   do k = 1_int32, e%cursors%n
      call vis_pos(e, e%cursors%c(k)%end, r, c)
      if (r >= e%first_row .and. r <= e%last_row .and. c >= e%first_column .and. c <= e%last_column) then
         shown = .not. blink .or. e%caret_timer <= 0.0_c_float
         if (.not. shown) shown = c_fmodf(e%caret_timer, 1.2_c_float) <= 0.8_c_float
         x = e%screen_x + e%text_left + real(c, c_float) * e%glyph_w
         y = e%screen_y + real(r, c_float) * e%glyph_h
         if (shown) call ct_rect_filled(x - e%cursor_width, y, x, y + e%glyph_h, e%palette(COLOR_CURSOR))
      endif
   enddo
   endsubroutine render_carets

   subroutine render_number_markers(e)
   !< `renderLineNumberMarkers`.
   type(code_editor), intent(inout) :: e    !< Editor.
   integer(int32)                   :: row, m !< Row, marker.
   integer(c_int)                   :: col  !< Colour.
   real(c_float)                    :: x0, x1, y0 !< Rectangle.

   if (e%nm == 0_int32) return
   do row = e%first_row, e%last_row
      m = e%doc%lines(row + 1)%marker
      if (m == 0_int32) cycle
      col = u32(e%mk_number(m))
      if (alpha_of(col) == 0_int32) cycle
      y0 = e%screen_y + real(row, c_float) * e%glyph_h
      x0 = e%screen_x + e%number_left
      x1 = e%screen_x + e%number_right
      call ct_rect_filled(x0, y0, x1, y0 + e%glyph_h, col)
      if (e%mk_len(m) > 0_int64) then
         if (ct_hovering_rect(x0, y0, x1, y0 + e%glyph_h)) call tooltip(col, marker_tooltip(e, m))
      endif
   enddo
   endsubroutine render_number_markers

   subroutine render_numbers(e, wx)
   !< `renderLineNumbers`.
   type(code_editor), intent(inout) :: e  !< Editor.
   real(c_float),     intent(in)    :: wx !< The window's x.
   integer(int32)                   :: i, current, digits !< Row, the cursor's line, digits.
   real(c_float)                    :: x, width !< Right end, the number's width.
   character(len=12)                :: number   !< The number.
   integer(int8)                    :: which    !< Colour.

   if (.not. e%line_numbers) return
   current = e%cursors%c(e%cursors%current + 1)%end%l
   x = wx + e%number_right
   do i = e%first_row, e%last_row
      digits = int(c_log10(real(i + 1_int32, c_double)) + 1.0_c_double, int32)
      width = real(digits, c_float) * e%glyph_w
      which = COLOR_LINE_NUMBER
      if (i == current) which = COLOR_CURRENT_LINE_NUMBER
      write(number, '(I0)') i + 1_int32
      call ct_text(x + (-width), e%screen_y + real(i, c_float) * e%glyph_h, e%palette(which), trim(number))
   enddo
   endsubroutine render_numbers

   subroutine render_decorations(e, wx)
   !< `renderDecorations` with the glue's decorator: a marked line's severity icon.
   type(code_editor), intent(inout) :: e  !< Editor.
   real(c_float),     intent(in)    :: wx !< The window's x.
   integer(int32)                   :: i, sev !< Row, severity.
   real(c_float)                    :: x, y, px, py !< Position, the cursor.

   x = wx + e%decoration_offset
   y = e%screen_y + e%glyph_h * real(e%first_row, c_float)
   do i = e%first_row, e%last_row
      call ct_set_cursor_screen_pos(x, y)
      call ct_push_id_int(int(i, c_int))
      sev = line_severity(e, i)
      if (sev > 0_int32) then
         call ct_cursor_screen_pos(px, py)
         call ct_text(px, py, u32(SEVERITY_RGB(sev)), SEVERITY_ICON(sev))
      endif
      call ct_pop_id()
      y = y + e%glyph_h
   enddo
   call ct_set_cursor_screen_pos(e%screen_x, e%screen_y)
   endsubroutine render_decorations

   subroutine render_popups(e)
   !< `renderPopups`: the context menus' and the hover popup's (FIGURE sets no callback: never open), then the
   !< autocomplete's (a later step).
   type(code_editor), intent(inout) :: e !< Editor.

   if (ct_begin_popup('LineNumberContextMenu', 0_c_int)) call ct_end_popup()
   if (ct_begin_popup('TextContextMenu', 0_c_int)) call ct_end_popup()
   if (ct_popup_open('TextHoverPopup')) continue
   if (e%ac_active) continue
   endsubroutine render_popups

   ! ---- the glue's entry points ---------------------------------------------------------------------------------------
   function fig_editor_draw(handle, id, id_len, width, height, changed) result(status)
   !< Draw the editor as a widget (the glue's `fig_editor_draw`): the style's palette, IBM Plex Mono, the fork's render
   !< in a bordered child window.
   integer(c_int),         intent(in)  :: handle  !< Handle.
   character(kind=c_char), intent(in)  :: id(*)   !< Widget id.
   integer(c_int),         intent(in)  :: id_len  !< Its length.
   real(c_double),         intent(in)  :: width   !< Width.
   real(c_double),         intent(in)  :: height  !< Height.
   integer(c_int),         intent(out) :: changed !< The user changed the text.
   integer(c_int)                      :: status  !< Status.
   type(code_editor), pointer          :: e       !< Editor.
   integer(c_int)                      :: p(0:32) !< The style's palette.
   logical                             :: ch      !< Changed.
   character(len=*), parameter         :: FONT = 'plex-mono' !< The editor's font.

   changed = 0_c_int
   e => editor_get(handle)
   if (.not. associated(e)) then
      status = not_found('draw')
      return
   endif
   if (id_len <= 0_c_int) then
      status = fail(FIG_ERR_ARGUMENT, 'code_editor_object%draw: the id is empty')
      return
   endif
   call style_palette(p)
   if (any(p /= e%palette_base)) then
      e%palette_base = p
      e%palette_alpha = -1.0_c_float
   endif
   status = fig_push_font(FONT, len(FONT, c_int), 0.0_c_double)
   if (status /= FIG_OK) return
   call render(e, str(id, int(id_len, int64)), real(width, c_float), real(height, c_float), ch)
   status = fig_pop_font()
   call ct_item_rect(e%rect(1), e%rect(2), e%rect(3), e%rect(4))
   e%drawn = .true.
   if (ch) changed = 1_c_int
   status = FIG_OK
   endfunction fig_editor_draw

   function fig_editor_line_rect(handle, line, rect, visible) result(status)
   !< The screen rectangle of a line's text on the last draw (the glue's `line_rect`); `visible` when it was in view.
   integer(c_int), intent(in)  :: handle  !< Handle.
   integer(c_int), intent(in)  :: line    !< Line, from 1.
   real(c_float),  intent(out) :: rect(4) !< Left, top, right, bottom [pixels].
   integer(c_int), intent(out) :: visible !< In view.
   integer(c_int)              :: status  !< Status.
   type(code_editor), pointer  :: e       !< Editor.
   integer(int32)              :: r, c    !< Visual position.
   real(c_float)               :: y       !< Top.

   visible = 0_c_int
   e => editor_get(handle)
   if (.not. associated(e)) then
      status = not_found('line_rect')
      return
   endif
   if (line < 1_c_int) then
      status = fail(FIG_ERR_ARGUMENT, 'code_editor_object%line_rect: lines are numbered from 1')
      return
   endif
   status = FIG_OK
   if (.not. e%drawn .or. line - 1_c_int >= e%doc%n) return
   call vis_pos(e, pos(line - 1_int32, 0_int32), r, c)
   if (r < e%first_row .or. r > e%last_row) return
   y = e%screen_y + real(r, c_float) * e%glyph_h
   rect(1) = e%rect(1) + e%text_left
   rect(2) = y
   rect(3) = max(rect(1), e%rect(1) + e%text_right)
   rect(4) = y + e%glyph_h
   visible = 1_c_int
   endfunction fig_editor_line_rect
endmodule figure_code_view
