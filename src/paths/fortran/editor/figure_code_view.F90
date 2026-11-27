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
                                ImGuiStyleVar_ItemSpacing, ImGuiWindowFlags_HorizontalScrollbar, ImGuiWindowFlags_NoMove, &
                                ImGuiInputFlags_Repeat, ImGuiMod_Alt, ImGuiMod_Ctrl, ImGuiMod_Shift, ImGuiMod_Super,      &
                                ImGuiKey_A, ImGuiKey_Backspace, ImGuiKey_C, ImGuiKey_D, ImGuiKey_Delete,                  &
                                ImGuiKey_DownArrow, ImGuiKey_End, ImGuiKey_Enter, ImGuiKey_Escape, ImGuiKey_F,            &
                                ImGuiKey_G, ImGuiKey_Home, ImGuiKey_Insert, ImGuiKey_K, ImGuiKey_KeypadEnter, ImGuiKey_L,  &
                                ImGuiKey_LeftArrow, ImGuiKey_LeftBracket, ImGuiKey_PageDown, ImGuiKey_PageUp,             &
                                ImGuiKey_RightArrow, ImGuiKey_RightBracket, ImGuiKey_Slash, ImGuiKey_Space, ImGuiKey_Tab, &
                                ImGuiKey_UpArrow, ImGuiKey_V, ImGuiKey_X, ImGuiKey_Y, ImGuiKey_Z,                         &
                                ImGuiMouseCursor_TextInput, ImGuiCol_Header, ImGuiCol_TextLink, ImGuiCol_Button,          &
                                ImGuiCol_ButtonActive, ImGuiCol_ButtonHovered, ImGuiCol_TableBorderLight,                 &
                                ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav,                              &
                                ImGuiInputTextFlags_AutoSelectAll, ImGuiInputTextFlags_NoUndoRedo
use figure_code_document, only : code_cursor, code_pos, cursor_has_selection, cursor_selection_end, &
                                 cursor_selection_start, &
                                 cursors_any_selection, cursors_update, pos, pos_le, pos_lt, pos_eq, cursor_update,    &
                                 cursor_update_keep, cursor_reset_to_start, cursor_reset_to_end, cursor_grow,          &
                                 cursors_add, cursors_set, cursors_clear_additional, cursors_adjust_insert,            &
                                 cursors_adjust_delete, doc_left, doc_right, doc_cp, doc_bottom, doc_end_of_line,      &
                                 doc_next_line, doc_normalize, doc_section_text, doc_find_text, doc_whole_word,        &
                                 doc_find_word_start, doc_find_word_end, cursors_clear_all, COLOR_BACKGROUND,         &
                                 COLOR_BRACKET_ACTIVE, COLOR_BRACKET_BACKGROUND, COLOR_BRACKET_ERROR,                  &
                                 COLOR_BRACKET_LEVEL1, COLOR_BRACKET_LEVEL2, COLOR_BRACKET_LEVEL3, COLOR_CURSOR,       &
                                 COLOR_CURRENT_LINE, COLOR_CURRENT_LINE_BORDER, COLOR_CURRENT_LINE_NUMBER,              &
                                 COLOR_LINE_NUMBER, COLOR_PUNCTUATION, COLOR_COMMENT, COLOR_STRING, COLOR_SELECTION, &
                                 COLOR_TEXT, COLOR_WHITESPACE
use figure_code_editor, only : code_editor, editor_get, fail, line_severity, marker_tooltip, not_found, str, &
                               INVALID, N_SEVERITY, SEVERITY_RGB, make_cursor_visible, start_transaction,     &
                               end_transaction, insert_text, delete_text, delete_from_all_cursors,             &
                               insert_into_all_cursors, editor_undo_, editor_redo_, ac_cancel,                 &
                               select_next_occurrence, select_all_occurrences, replace_in_current_cursor
use figure_code_language, only : colorize, lang_comment_single, lang_indentation_blocks
use figure_code_unicode, only : cp_glyph_width, cp_is_bracket_closer, cp_is_bracket_opener, cp_is_white_space, &
                                cp_is_word, cp_to_pair_closer, cp_to_pair_opener, cp_write, cp_read, &
                                cp_to_lower
use figure_core_text, only : ct_glyphs
use figure_core_text, only : ct_begin_child, ct_begin_popup, ct_begin_tooltip, ct_char, ct_circle_filled, ct_clip_rect, &
                             ct_color_u32, ct_cursor_screen_pos, ct_end_child, ct_end_popup, ct_end_tooltip,            &
                             ct_float4_to_u32, ct_font_size, ct_hovering_rect, ct_item_rect, ct_line,                   &
                             ct_line_height_with_spacing, ct_nav, ct_pop_clip, ct_pop_id, ct_pop_style_color,          &
                             ct_pop_style_var, ct_popup_open, ct_push_clip, ct_push_id_int, ct_push_style_color_u32,    &
                             ct_push_style_var_vec2, ct_rect, ct_rect_filled, ct_scroll, ct_set_cursor_screen_pos,      &
                             ct_set_next_window_content_size, ct_set_next_window_focus, ct_set_scroll_x,                &
                             ct_set_scroll_y, ct_state, ct_style_color, ct_text, ct_text_unformatted, ct_text_width,    &
                             ct_window_focused, ct_window_pos, ct_shortcut, ct_key_pressed, ct_key_down,             &
                             ct_want_keyboard, ct_mouse_pos, ct_mouse_down, ct_mouse_clicked,                        &
                             ct_mouse_double_clicked, ct_mouse_released, ct_mouse_dragging, ct_mouse_drag_delta,     &
                             ct_reset_mouse_drag_delta, ct_set_mouse_cursor, ct_time, ct_window_size, ct_set_clipboard, &
                             ct_clipboard, ct_chars, ct_ime, ct_window_hovered, ct_style_u32, ct_frame_height,        &
                             ct_frame_height_with_spacing, ct_invisible_button, ct_button, ct_content_avail,         &
                             ct_set_next_window_pos, ct_set_next_window_size, ct_set_next_window_bg_alpha,          &
                             ct_set_next_item_width, ct_set_keyboard_focus_here, ct_item_deactivated,               &
                             ct_item_clicked, ct_begin_disabled, ct_end_disabled, ct_same_line,                     &
                             ct_push_style_color_vec4, ct_key_chord_pressed, ct_clear_window_focus,                 &
                             ct_window_appearing, ct_close_current_popup, ct_set_scroll_here_y, ct_bring_to_front,   &
                             ct_input_text, ct_open_popup

implicit none
private
public :: fig_editor_draw, fig_editor_line_rect
public :: style_palette, col32, u32, FONT_NAME
public :: vis_pos, doc_pos_of, normalize_vis, update_state, handle_scrolling, enclosing_brackets, palette_color

!< The marks' icons (circle-x, triangle-alert, info: FIGURE's icon font), by severity.
character(len=3), parameter :: SEVERITY_ICON(N_SEVERITY) = [achar(238)//achar(130)//achar(132), &
                                                            achar(238)//achar(134)//achar(147), &
                                                            achar(238)//achar(131)//achar(185)]
integer(int32), parameter :: DECORATOR_WIDTH = 2_int32 !< The glue's decoration column [glyphs].
character(len=*), parameter :: FONT_NAME = 'plex-mono' !< The editor's and the diff's font.

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
      call handle_keys(e)
      call update_state(e, changed)
      call handle_mouse(e)
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
      call render_find_replace(e)
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
   integer(int32),  parameter       :: GLYPHS = 256_int32 !< A run's glyphs at most.
   real(c_float)                    :: run_x(GLYPHS) !< The row's run of glyphs (`ct_glyphs`, one call a run): x.
   integer(c_int)                   :: run_col(GLYPHS), run_cp(GLYPHS) !< ... colours, code points.
   integer(c_int)                   :: nrun     !< ... glyphs in it.
   real(c_float)                    :: gw       !< Glyph width (the loop's constants as locals: no reload per glyph).
   integer(int32)                   :: last_col, ncol !< The last visible column, the line's columns.
   integer(c_int)                   :: pal(0:32) !< The palette.

   rx = e%screen_x + e%text_left
   ry = e%screen_y + real(e%first_row, c_float) * e%glyph_h
   first_col = (e%first_column / e%tab_size) * e%tab_size
   nrun = 0_c_int ! glyphs go in runs (`ct_glyphs`), drawn in order: a run is drawn before any other primitive
   gw = e%glyph_w
   last_col = e%last_column
   pal = e%palette
   do i = e%first_row, e%last_row
      associate(line => e%doc%lines(i + 1))
         j = 0_int32
         column = 0_int32
         ncol = line%columns
         do while (column < ncol .and. column <= last_col)
            j = j + 1_int32
            cp = line%cp(j)
            gx = rx + real(column, c_float) * gw
            gy = ry
            if (cp == 9_int32) then
               if (e%show_tabs .and. column >= first_col) then
                  call ct_glyphs(nrun, run_x, ry, run_col, run_cp)
                  nrun = 0_c_int
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
                  call ct_glyphs(nrun, run_x, ry, run_col, run_cp)
                  nrun = 0_c_int
                  call ct_circle_filled(gx + e%glyph_w * 0.5_c_float, gy + e%font_size * 0.5_c_float, 1.5_c_float, &
                                        e%palette(COLOR_WHITESPACE), 4_c_int)
               endif
            elseif (column >= first_col) then
               if (nrun == GLYPHS) then
                  call ct_glyphs(nrun, run_x, ry, run_col, run_cp)
                  nrun = 0_c_int
               endif
               nrun = nrun + 1_c_int
               run_x(nrun) = gx
               run_col(nrun) = pal(line%color(j))
               run_cp(nrun) = cp
            endif
            column = column + line%cols(j)
         enddo
      endassociate
      call ct_glyphs(nrun, run_x, ry, run_col, run_cp)
      nrun = 0_c_int
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
   integer(int32)                   :: n, m, k  !< The number, its rest, its length.

   if (.not. e%line_numbers) return
   current = e%cursors%c(e%cursors%current + 1)%end%l
   x = wx + e%number_right
   do i = e%first_row, e%last_row
      digits = int(c_log10(real(i + 1_int32, c_double)) + 1.0_c_double, int32)
      width = real(digits, c_float) * e%glyph_w
      which = COLOR_LINE_NUMBER
      if (i == current) which = COLOR_CURRENT_LINE_NUMBER
      n = i + 1_int32 ! its decimal digits from the right of `number` (no internal write: it allocates per call)
      k = len(number) + 1
      do
         m = n / 10_int32
         k = k - 1
         number(k:k) = achar(iachar('0') + (n - 10_int32 * m))
         n = m
         if (n == 0_int32) exit
      enddo
      call ct_text(x + (-width), e%screen_y + real(i, c_float) * e%glyph_h, e%palette(which), number(k:))
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
   !< autocomplete's, a picked suggestion replacing its section.
   type(code_editor), intent(inout) :: e      !< Editor.
   logical                          :: picked !< A suggestion picked.

   if (ct_begin_popup('LineNumberContextMenu', 0_c_int)) then
      call ct_close_current_popup()
      call ct_end_popup()
   endif
   if (ct_begin_popup('TextContextMenu', 0_c_int)) then
      call ct_close_current_popup()
      call ct_end_popup()
   endif
   if (ct_popup_open('TextHoverPopup')) continue
   call render_autocomplete(e, picked)
   if (picked) call replace_section(e, ac_replacement_start(e), ac_replacement_end(e), offered_word(e, e%ac_selection))
   endsubroutine render_popups

   ! ---- moves and edits the keys and the mouse make (szaghi/figure#15 P16 step 12) ------------------------------------
   subroutine move_up(e, rows, sel)
   !< `moveUp` (rows < 0: the fork's size_t wrapped, the top).
   type(code_editor), intent(inout) :: e    !< Editor.
   integer(int32),    intent(in)    :: rows !< Rows.
   logical,           intent(in)    :: sel  !< Extend the selection.
   integer(int32)                   :: k, r, c !< Cursor, visual position.

   do k = 1_int32, e%cursors%n
      call vis_pos(e, e%cursors%c(k)%end, r, c)
      if (e%navigating_vertically) then
         c = e%cursors%c(k)%preferred
      else
         e%cursors%c(k)%preferred = c
      endif
      if (rows < 0_int32 .or. rows > r) then
         r = 0_int32
      else
         r = r - rows
      endif
      call normalize_vis(e, r, c)
      call cursor_update_keep(e%cursors%c(k), doc_pos_of(e, r, c), sel)
   enddo
   call make_cursor_visible(e)
   e%navigating_vertically = .true.
   endsubroutine move_up

   subroutine move_down(e, rows, sel)
   !< `moveDown` (a row past the end, or wrapped below 0 as the fork's size_t, is the last).
   type(code_editor), intent(inout) :: e    !< Editor.
   integer(int32),    intent(in)    :: rows !< Rows.
   logical,           intent(in)    :: sel  !< Extend the selection.
   integer(int32)                   :: k, r, c !< Cursor, visual position.

   do k = 1_int32, e%cursors%n
      call vis_pos(e, e%cursors%c(k)%end, r, c)
      if (e%navigating_vertically) then
         c = e%cursors%c(k)%preferred
      else
         e%cursors%c(k)%preferred = c
      endif
      r = r + rows
      if (r < 0_int32) r = huge(r)
      call normalize_vis(e, r, c)
      call cursor_update_keep(e%cursors%c(k), doc_pos_of(e, r, c), sel)
   enddo
   call make_cursor_visible(e)
   e%navigating_vertically = .true.
   endsubroutine move_down

   subroutine move_left(e, sel, word)
   !< `moveLeft`.
   type(code_editor), intent(inout) :: e         !< Editor.
   logical,           intent(in)    :: sel, word !< Extend the selection, by words.
   integer(int32)                   :: k         !< Cursor.

   do k = 1_int32, e%cursors%n
      if (cursor_has_selection(e%cursors%c(k)) .and. .not. sel .and. .not. word) then
         call cursor_reset_to_start(e%cursors%c(k))
      else
         call cursor_update_keep(e%cursors%c(k), doc_left(e%doc, e%cursors%c(k)%end, word), sel)
      endif
   enddo
   call make_cursor_visible(e)
   e%navigating_vertically = .false.
   endsubroutine move_left

   subroutine move_right(e, sel, word)
   !< `moveRight`.
   type(code_editor), intent(inout) :: e         !< Editor.
   logical,           intent(in)    :: sel, word !< Extend the selection, by words.
   integer(int32)                   :: k         !< Cursor.

   do k = 1_int32, e%cursors%n
      if (cursor_has_selection(e%cursors%c(k)) .and. .not. sel .and. .not. word) then
         call cursor_reset_to_end(e%cursors%c(k))
      else
         call cursor_update_keep(e%cursors%c(k), doc_right(e%doc, e%cursors%c(k)%end, word), sel)
      endif
   enddo
   call make_cursor_visible(e)
   e%navigating_vertically = .false.
   endsubroutine move_right

   subroutine move_to(e, p, sel)
   !< `moveTo`.
   type(code_editor), intent(inout) :: e   !< Editor.
   type(code_pos),    intent(in)    :: p   !< Position.
   logical,           intent(in)    :: sel !< Extend the selection.

   call cursors_clear_additional(e%cursors, .false.)
   call cursor_update_keep(e%cursors%c(e%cursors%current + 1), p, sel)
   call make_cursor_visible(e)
   e%navigating_vertically = .false.
   endsubroutine move_to

   subroutine add_next_occurrence(e, whole)
   !< `addNextOccurrence`.
   type(code_editor), intent(inout) :: e     !< Editor.
   logical,           intent(in)    :: whole !< Whole words.
   type(code_pos)                   :: a, b, s, t !< The current selection, the occurrence.
   logical                          :: found !< Found.

   a = cursor_selection_start(e%cursors%c(e%cursors%current + 1))
   b = cursor_selection_end(e%cursors%c(e%cursors%current + 1))
   call doc_find_text(e%doc, b, doc_section_text(e%doc, a, b), .true., whole, found, s, t)
   if (found) call cursors_add(e%cursors, s, t)
   endsubroutine add_next_occurrence

   subroutine select_all_of_current(e, whole)
   !< `selectAllOccurrences`: the current selection's text, everywhere.
   type(code_editor), intent(inout) :: e     !< Editor.
   logical,           intent(in)    :: whole !< Whole words.
   type(code_pos)                   :: a, b  !< The current selection.

   a = cursor_selection_start(e%cursors%c(e%cursors%current + 1))
   b = cursor_selection_end(e%cursors%c(e%cursors%current + 1))
   call select_all_occurrences(e, doc_section_text(e%doc, a, b), .true., whole)
   endsubroutine select_all_of_current

   pure function enclosing_both(e, a, b) result(k)
   !< `getEnclosingBrackets(first, last)`.
   type(code_editor), intent(in) :: e    !< Editor.
   type(code_pos),    intent(in) :: a, b !< First, last.
   integer(int32)                :: k    !< Pair (0 none).
   integer(int32)                :: j    !< Counter.

   k = 0_int32
   do j = 1_int32, e%nb
      if (pos_lt(a, e%br_start(j))) exit
      if (pos_lt(e%br_start(j), a) .and. pos_le(a, e%br_end(j)) .and. pos_lt(e%br_start(j), b) .and. &
          pos_le(b, e%br_end(j))) k = j
   enddo
   endfunction enclosing_both

   pure function inner_brackets(e, a, b) result(k)
   !< `getInnerBrackets(first, last)`.
   type(code_editor), intent(in) :: e     !< Editor.
   type(code_pos),    intent(in) :: a, b  !< First, last.
   integer(int32)                :: k     !< Pair (0 none).
   integer(int32)                :: outer, j !< Enclosing pair, counter.

   k = 0_int32
   outer = enclosing_both(e, a, b)
   if (outer == 0_int32) return
   do j = outer + 1_int32, e%nb
      if (e%br_level(j) <= e%br_level(outer)) exit
      if (e%br_level(j) == e%br_level(outer) + 1_int32 .and. pos_lt(a, e%br_start(j)) .and. &
          pos_lt(e%br_end(j), b)) then
         k = j
         exit
      endif
   enddo
   endfunction inner_brackets

   subroutine grow_selections(e)
   !< `growSelections`.
   type(code_editor), intent(inout) :: e     !< Editor.
   type(code_pos)                   :: a, b  !< A selection.
   integer(int32)                   :: k, j, sc, ec !< Cursor, pair, code points.

   do k = 1_int32, e%cursors%n
      if (cursor_has_selection(e%cursors%c(k))) then
         a = cursor_selection_start(e%cursors%c(k))
         b = cursor_selection_end(e%cursors%c(k))
         sc = doc_cp(e%doc, doc_left(e%doc, a, .false.))
         ec = doc_cp(e%doc, b)
         if (cp_is_bracket_opener(sc) .and. ec == cp_to_pair_closer(sc)) then
            call cursor_update(e%cursors%c(k), doc_left(e%doc, a, .false.), doc_right(e%doc, b, .false.))
         else
            j = enclosing_both(e, a, b)
            if (j > 0_int32) call cursor_update(e%cursors%c(k), doc_right(e%doc, e%br_start(j), .false.), e%br_end(j))
         endif
      else
         b = cursor_selection_end(e%cursors%c(k))
         call cursor_update(e%cursors%c(k), doc_find_word_start(e%doc, b, .false.), doc_find_word_end(e%doc, b, .false.))
      endif
   enddo
   endsubroutine grow_selections

   subroutine shrink_selections(e)
   !< `shrinkSelections`.
   type(code_editor), intent(inout) :: e     !< Editor.
   type(code_pos)                   :: a, b  !< A selection.
   integer(int32)                   :: k, j, sc, ec !< Cursor, pair, code points.

   do k = 1_int32, e%cursors%n
      if (.not. cursor_has_selection(e%cursors%c(k))) cycle
      a = cursor_selection_start(e%cursors%c(k))
      b = cursor_selection_end(e%cursors%c(k))
      sc = doc_cp(e%doc, a)
      ec = doc_cp(e%doc, doc_left(e%doc, b, .false.))
      if (cp_is_bracket_opener(sc) .and. ec == cp_to_pair_closer(sc)) then
         call cursor_update(e%cursors%c(k), doc_right(e%doc, a, .false.), doc_left(e%doc, b, .false.))
      else
         j = inner_brackets(e, a, b)
         if (j > 0_int32) call cursor_update(e%cursors%c(k), e%br_start(j), doc_right(e%doc, e%br_end(j), .false.))
      endif
   enddo
   endsubroutine shrink_selections

   function line_text(e, l) result(t)
   !< `getLineText`.
   type(code_editor), intent(in) :: e !< Editor.
   integer(int32),    intent(in) :: l !< Line, from 0.
   character(len=:), allocatable :: t !< Text.

   t = doc_section_text(e%doc, pos(l, 0_int32), pos(l, e%doc%lines(l + 1)%n))
   endfunction line_text

   subroutine copy(e)
   !< `copy`: the selections (or the cursors' lines) to the clipboard.
   type(code_editor), intent(inout) :: e !< Editor.
   character(len=:), allocatable    :: t !< Text.
   integer(int32)                   :: k !< Cursor.

   t = ''
   if (cursors_any_selection(e%cursors)) then
      do k = 1_int32, e%cursors%n
         if (len(t) > 0) t = t//achar(10)
         if (cursor_has_selection(e%cursors%c(k))) then
            t = t//doc_section_text(e%doc, cursor_selection_start(e%cursors%c(k)), cursor_selection_end(e%cursors%c(k)))
         else
            t = t//line_text(e, start_line(e%cursors%c(k)))
         endif
      enddo
   else
      do k = 1_int32, e%cursors%n
         t = t//line_text(e, start_line(e%cursors%c(k)))//achar(10)
      enddo
   endif
   call ct_set_clipboard(t)
   endsubroutine copy

   subroutine cut(e)
   !< `cut`.
   type(code_editor), intent(inout) :: e !< Editor.

   call copy(e)
   call start_transaction(e, .true.)
   call delete_from_all_cursors(e)
   call cursor_reset_to_start(e%cursors%c(e%cursors%current + 1))
   call end_transaction(e)
   endsubroutine cut

   subroutine paste(e)
   !< `paste`.
   type(code_editor), intent(inout) :: e !< Editor.
   character(len=:), allocatable    :: t !< Clipboard.

   if (.not. ct_clipboard(t)) return
   call start_transaction(e, .true.)
   call insert_into_all_cursors(e, t)
   call end_transaction(e)
   endsubroutine paste

   subroutine handle_backspace(e, word)
   !< `handleBackspace`.
   type(code_editor), intent(inout) :: e    !< Editor.
   logical,           intent(in)    :: word !< By words.
   type(code_pos)                   :: a, b !< Deleted.
   integer(int32)                   :: k    !< Cursor.

   call start_transaction(e, .false.)
   do k = 1_int32, e%cursors%n
      if (cursor_has_selection(e%cursors%c(k))) then
         a = cursor_selection_start(e%cursors%c(k))
      else
         a = doc_left(e%doc, cursor_selection_start(e%cursors%c(k)), word)
      endif
      b = cursor_selection_end(e%cursors%c(k))
      call delete_text(e, a, b)
      call cursor_update(e%cursors%c(k), a, a)
      call cursors_adjust_delete(e%cursors, k - 1_int32, a, b, .false.)
   enddo
   call end_transaction(e)
   endsubroutine handle_backspace

   subroutine handle_delete(e, word)
   !< `handleDelete`.
   type(code_editor), intent(inout) :: e    !< Editor.
   logical,           intent(in)    :: word !< By words.
   type(code_pos)                   :: a, b !< Deleted.
   integer(int32)                   :: k    !< Cursor.

   call start_transaction(e, .false.)
   do k = 1_int32, e%cursors%n
      a = cursor_selection_start(e%cursors%c(k))
      if (cursor_has_selection(e%cursors%c(k))) then
         b = cursor_selection_end(e%cursors%c(k))
      else
         b = doc_right(e%doc, cursor_selection_end(e%cursors%c(k)), word)
      endif
      call delete_text(e, a, b)
      call cursor_update(e%cursors%c(k), a, a)
      call cursors_adjust_delete(e%cursors, k - 1_int32, a, b, .false.)
   enddo
   call end_transaction(e)
   endsubroutine handle_delete

   subroutine remove_selected_lines(e)
   !< `removeSelectedLines`.
   type(code_editor), intent(inout) :: e    !< Editor.
   type(code_pos)                   :: a, b !< Deleted.
   integer(int32)                   :: k    !< Cursor.

   call start_transaction(e, .true.)
   do k = 1_int32, e%cursors%n
      a = pos(start_line(e%cursors%c(k)), 0_int32)
      b = cursor_selection_end(e%cursors%c(k))
      if (b%i /= 0_int32) b = doc_next_line(e%doc, b)
      call delete_text(e, a, b)
      call cursor_update(e%cursors%c(k), a, a)
      call cursors_adjust_delete(e%cursors, k - 1_int32, a, b, .false.)
   enddo
   call end_transaction(e)
   endsubroutine remove_selected_lines

   subroutine insert_line(e, below)
   !< `insertLineAbove`, `insertLineBelow`.
   type(code_editor), intent(inout) :: e     !< Editor.
   logical,           intent(in)    :: below !< Below.
   type(code_pos)                   :: a, b  !< Insert.
   integer(int32)                   :: k     !< Cursor.

   call start_transaction(e, .true.)
   do k = 1_int32, e%cursors%n
      if (below) then
         a = cursor_selection_end(e%cursors%c(k))
         if (a%i /= 0_int32) a = doc_next_line(e%doc, a)
      else
         a = pos(start_line(e%cursors%c(k)), 0_int32)
      endif
      call insert_text(e, a, achar(10), b)
      call cursor_update(e%cursors%c(k), a, a)
      call cursors_adjust_insert(e%cursors, k - 1_int32, a, b, .false.)
   enddo
   call end_transaction(e)
   endsubroutine insert_line

   subroutine indent_lines(e, deindent)
   !< `indentLines`, `deindentLines`.
   type(code_editor), intent(inout) :: e        !< Editor.
   logical,           intent(in)    :: deindent !< Deindent.
   type(code_pos)                   :: a, b, s, t !< The cursor's selection, an edit.
   integer(int32)                   :: k, l, column, index !< Cursor, line, blanks.

   call start_transaction(e, .true.)
   do k = 1_int32, e%cursors%n
      a = cursor_selection_start(e%cursors%c(k))
      b = cursor_selection_end(e%cursors%c(k))
      do l = a%l, b%l
         if (cursor_has_selection(e%cursors%c(k)) .and. pos_eq(pos(l, 0_int32), b)) cycle
         if (e%doc%lines(l + 1)%n == 0_int32) cycle
         if (.not. deindent) then
            s = pos(l, 0_int32)
            call insert_text(e, s, achar(9), t)
            call cursors_adjust_insert(e%cursors, k - 1_int32, s, t, .true.)
         else
            column = 0_int32
            index = 0_int32
            do while (column < e%tab_size .and. index < e%doc%lines(l + 1)%n)
               if (e%doc%lines(l + 1)%cp(index + 1) /= 32_int32 .and. e%doc%lines(l + 1)%cp(index + 1) /= 9_int32) exit
               column = column + e%doc%lines(l + 1)%cols(index + 1)
               index = index + 1_int32
            enddo
            if (index /= 0_int32) then
               s = pos(l, 0_int32)
               t = pos(l, index)
               call delete_text(e, s, t)
               call cursors_adjust_delete(e%cursors, k - 1_int32, s, t, .true.)
            endif
         endif
      enddo
   enddo
   call end_transaction(e)
   endsubroutine indent_lines

   subroutine move_lines(e, down)
   !< `moveUpLines`, `moveDownLines`.
   type(code_editor), intent(inout) :: e    !< Editor.
   logical,           intent(in)    :: down !< Down.
   type(code_pos)                   :: a, b, ds, de, is, ie !< Selection, deleted, inserted.
   character(len=:), allocatable    :: t    !< The lines.
   integer(int32)                   :: k    !< Cursor.

   if (down) then
      if (start_line(e%cursors%c(e%cursors%n)) == e%doc%n - 1_int32) return
   else
      if (start_line(e%cursors%c(1)) == 0_int32) return
   endif
   call start_transaction(e, .true.)
   do k = 1_int32, e%cursors%n
      a = cursor_selection_start(e%cursors%c(k))
      b = cursor_selection_end(e%cursors%c(k))
      ds = pos(a%l, 0_int32)
      de = b
      if (b%i /= 0_int32) de = doc_next_line(e%doc, b)
      t = doc_section_text(e%doc, ds, de)
      call delete_text(e, ds, de)
      call cursors_adjust_delete(e%cursors, k - 1_int32, ds, de, .false.)
      if (down) then
         is = doc_next_line(e%doc, ds)
      else
         is = pos(ds%l - 1_int32, 0_int32)
      endif
      call insert_text(e, is, t, ie)
      call cursors_adjust_insert(e%cursors, k - 1_int32, is, ie, .false.)
      if (down) then
         call cursor_update(e%cursors%c(k), pos(a%l + 1_int32, a%i), pos(b%l + 1_int32, b%i))
      else
         call cursor_update(e%cursors%c(k), pos(a%l - 1_int32, a%i), pos(b%l - 1_int32, b%i))
      endif
   enddo
   call end_transaction(e)
   endsubroutine move_lines

   subroutine toggle_comments(e)
   !< `toggleComments` (the language's line comment, compared byte by byte as the fork does).
   type(code_editor), intent(inout) :: e       !< Editor.
   character(len=:), allocatable    :: comment !< Line comment.
   type(code_pos)                   :: a, b, s, t !< Selection, an edit.
   integer(int32)                   :: k, l, start, i, eoc, n !< Cursor, line, positions, size.

   comment = lang_comment_single(e%language)
   call start_transaction(e, .true.)
   do k = 1_int32, e%cursors%n
      a = cursor_selection_start(e%cursors%c(k))
      b = cursor_selection_end(e%cursors%c(k))
      do l = a%l, b%l
         if (cursor_has_selection(e%cursors%c(k)) .and. pos_eq(pos(l, 0_int32), b)) cycle
         n = e%doc%lines(l + 1)%n
         if (n == 0_int32) cycle
         start = 0_int32
         do while (start < n)
            if (.not. cp_is_white_space(e%doc%lines(l + 1)%cp(start + 1))) exit
            start = start + 1_int32
         enddo
         i = 0_int32
         do while (start + i < n .and. i < len(comment, int32))
            if (e%doc%lines(l + 1)%cp(start + i + 1) /= byte_cp(comment(i + 1:i + 1))) exit
            i = i + 1_int32
         enddo
         if (i == len(comment, int32)) then
            s = pos(l, start)
            eoc = start + i
            if (eoc < n - 1_int32) then
               if (e%doc%lines(l + 1)%cp(eoc + 1) == 32_int32) eoc = eoc + 1_int32
            endif
            t = pos(l, eoc)
            call delete_text(e, s, t)
            call cursors_adjust_delete(e%cursors, k - 1_int32, s, t, .true.)
         else
            s = pos(l, start)
            call insert_text(e, s, comment//' ', t)
            call cursors_adjust_insert(e%cursors, k - 1_int32, s, t, .true.)
         endif
      enddo
   enddo
   call end_transaction(e)
   endsubroutine toggle_comments

   pure function byte_cp(c) result(cp)
   !< `static_cast<ImWchar>(char)`: a byte as the fork's comparison sees it (signed char, 16 bits).
   character(len=1), intent(in) :: c  !< Byte.
   integer(int32)               :: cp !< Value.

   cp = iachar(c)
   if (cp >= 128_int32) cp = cp + 65280_int32
   endfunction byte_cp

   subroutine auto_indent(e)
   !< `autoIndentAllCursors`.
   type(code_editor), intent(inout) :: e      !< Editor.
   type(code_pos)                   :: a, b   !< Positions.
   integer(int32)                   :: k, index, prev, next, i, m, cursor_index !< Counters, code points.
   character(len=:), allocatable    :: blanks, ins !< Leading white space, the insert.
   character(len=4)                 :: u      !< A code point's bytes.

   do k = 1_int32, e%cursors%n
      a = cursor_selection_start(e%cursors%c(k))
      if (cursor_has_selection(e%cursors%c(k))) then
         b = cursor_selection_end(e%cursors%c(k))
         call delete_text(e, a, b)
         call cursors_adjust_delete(e%cursors, k - 1_int32, a, b, .false.)
      endif
      index = a%i
      prev = 0_int32
      next = 0_int32
      if (index > 0_int32) prev = e%doc%lines(a%l + 1)%cp(index)
      if (index < e%doc%lines(a%l + 1)%n) next = e%doc%lines(a%l + 1)%cp(index + 1)
      if (cp_is_white_space(next)) then
         do while (index < e%doc%lines(a%l + 1)%n)
            if (.not. cp_is_white_space(e%doc%lines(a%l + 1)%cp(index + 1))) exit
            index = index + 1_int32
         enddo
         b = pos(a%l, index)
         call delete_text(e, a, b)
         call cursors_adjust_delete(e%cursors, k - 1_int32, a, b, .false.)
      endif
      blanks = ''
      do i = 1_int32, e%doc%lines(a%l + 1)%n
         if (.not. cp_is_white_space(e%doc%lines(a%l + 1)%cp(i))) exit
         call cp_write(e%doc%lines(a%l + 1)%cp(i), u, m)
         blanks = blanks//u(1:m)
      enddo
      ins = achar(10)//blanks
      cursor_index = len(blanks, int32)
      if (prev == 123_int32 .or. prev == 91_int32) then
         if (e%spaces_on_tabs) then
            ins = ins//repeat(' ', e%tab_size)
            cursor_index = cursor_index + e%tab_size
         else
            ins = ins//achar(9)
            cursor_index = cursor_index + 1_int32
         endif
         if ((prev == 123_int32 .and. next == 125_int32) .or. (prev == 91_int32 .and. next == 93_int32)) &
            ins = ins//achar(10)//blanks
      endif
      call insert_text(e, a, ins, b)
      call cursors_adjust_insert(e%cursors, k - 1_int32, a, b, .false.)
      call cursor_update(e%cursors%c(k), pos(a%l + 1_int32, cursor_index), pos(a%l + 1_int32, cursor_index))
   enddo
   endsubroutine auto_indent

   subroutine handle_character(e, ch)
   !< `handleCharacter` (FIGURE completes no pairs: the glue turns it off).
   type(code_editor), intent(inout) :: e  !< Editor.
   integer(int32),    intent(in)    :: ch !< Code point.
   type(code_pos)                   :: a, b !< A glyph overwritten.
   integer(int32)                   :: k, m !< Cursor, bytes.
   character(len=4)                 :: u  !< Its bytes.

   call start_transaction(e, .false.)
   if (.not. e%overwrite .and. e%auto_indent .and. ch == 10_int32) then
      call auto_indent(e)
   else
      if (e%overwrite) then
         do k = 1_int32, e%cursors%n
            if (cursor_has_selection(e%cursors%c(k))) cycle
            a = cursor_selection_start(e%cursors%c(k))
            if (pos_eq(a, doc_end_of_line(e%doc, a))) cycle
            b = doc_right(e%doc, a, .false.)
            call delete_text(e, a, b)
            call cursors_adjust_delete(e%cursors, k - 1_int32, a, b, .false.)
         enddo
      endif
      call cp_write(ch, u, m)
      call insert_into_all_cursors(e, u(1:m))
   endif
   call end_transaction(e)
   if (e%cursors%n == 1_int32) then
      if (ac_start_typing(e, ch)) call make_cursor_visible(e)
   endif
   endsubroutine handle_character

   function ac_word_character(e, cp) result(yes)
   !< `AutoComplete::isWordCharacter` (the glue's extra word characters: blank and dash for key = value).
   type(code_editor), intent(in) :: e   !< Editor.
   integer(int32),    intent(in) :: cp  !< Code point.
   logical                       :: yes !< Part of a search term.

   yes = cp_is_word(cp)
   if (.not. yes .and. e%ac_word_blank) yes = cp == 32_int32 .or. cp == 45_int32
   endfunction ac_word_character

   function ac_start_typing(e, ch) result(started)
   !< `AutoComplete::startTyping` (no trigger characters: the glue sets none).
   type(code_editor), intent(inout) :: e       !< Editor.
   integer(int32),    intent(in)    :: ch      !< Character typed.
   logical                          :: started !< A session asked for.

   started = .false.
   if (e%ac_request_activation) then
      if (ac_word_character(e, ch)) e%ac_location = cursor_selection_end(e%cursors%c(e%cursors%main + 1))
      return
   endif
   if (.not. e%ac_active .and. cp_is_word(ch) .and. e%ac_configured) then
      e%ac_manual = .false.
      call ac_cancel(e)
      e%ac_request_activation = .true.
      e%ac_location = cursor_selection_end(e%cursors%c(e%cursors%main + 1))
      started = .true.
   endif
   endfunction ac_start_typing

   subroutine handle_keys(e)
   !< `handleKeyboardInputs`: the fork's shortcuts in its order (each `Shortcut` asked as the fork asks it), then the
   !< characters typed, the input method's position.
   type(code_editor), intent(inout) :: e      !< Editor.
   logical                          :: mac, ro !< macOS behaviours, read-only.
   integer(c_int)                   :: word_mod, grow_mod, chars(64), n, k !< Modifiers, characters.
   integer(int32)                   :: r, c, page !< Visual position, a page.
   real(c_float)                    :: f(16) !< State.
   integer(c_int)                   :: fi(5) !< Flags.

   if (.not. ct_window_focused()) return
   call ct_state(f, fi)
   mac = fi(3) /= 0_c_int
   ro = e%read_only
   word_mod = merge(ImGuiMod_Alt, ImGuiMod_Ctrl, mac)
   grow_mod = merge(ImGuiMod_Super, ImGuiMod_Alt, mac)
   page = e%last_row - e%first_row - 2_int32
   if (e%ac_active) then
      if (ac_special_key()) then
         if (e%noffered > 0_int32) return
         call ac_cancel(e)
      endif
   endif
   if (ct_shortcut(ImGuiKey_UpArrow, ImGuiInputFlags_Repeat)) then
      call move_up(e, 1_int32, .false.)
   elseif (ct_shortcut(ior(ImGuiMod_Shift, ImGuiKey_UpArrow), ImGuiInputFlags_Repeat)) then
      call move_up(e, 1_int32, .true.)
   elseif (ct_shortcut(ImGuiKey_DownArrow, ImGuiInputFlags_Repeat)) then
      call move_down(e, 1_int32, .false.)
   elseif (ct_shortcut(ior(ImGuiMod_Shift, ImGuiKey_DownArrow), ImGuiInputFlags_Repeat)) then
      call move_down(e, 1_int32, .true.)
   elseif (ct_shortcut(ior(ior(grow_mod, ImGuiMod_Shift), ImGuiKey_LeftArrow), 0_c_int)) then
      call shrink_selections(e)
   elseif (ct_shortcut(ior(ior(grow_mod, ImGuiMod_Shift), ImGuiKey_RightArrow), 0_c_int)) then
      call grow_selections(e)
   elseif (ct_shortcut(ImGuiKey_LeftArrow, ImGuiInputFlags_Repeat)) then
      call move_left(e, .false., .false.)
   elseif (ct_shortcut(ior(ImGuiMod_Shift, ImGuiKey_LeftArrow), ImGuiInputFlags_Repeat)) then
      call move_left(e, .true., .false.)
   elseif (ct_shortcut(ior(word_mod, ImGuiKey_LeftArrow), ImGuiInputFlags_Repeat)) then
      call move_left(e, .false., .true.)
   elseif (ct_shortcut(ior(ior(word_mod, ImGuiMod_Shift), ImGuiKey_LeftArrow), ImGuiInputFlags_Repeat)) then
      call move_left(e, .true., .true.)
   elseif (ct_shortcut(ImGuiKey_RightArrow, ImGuiInputFlags_Repeat)) then
      call move_right(e, .false., .false.)
   elseif (ct_shortcut(ior(ImGuiMod_Shift, ImGuiKey_RightArrow), ImGuiInputFlags_Repeat)) then
      call move_right(e, .true., .false.)
   elseif (ct_shortcut(ior(word_mod, ImGuiKey_RightArrow), ImGuiInputFlags_Repeat)) then
      call move_right(e, .false., .true.)
   elseif (ct_shortcut(ior(ior(word_mod, ImGuiMod_Shift), ImGuiKey_RightArrow), ImGuiInputFlags_Repeat)) then
      call move_right(e, .true., .true.)
   elseif (ct_shortcut(ImGuiKey_PageUp, ImGuiInputFlags_Repeat)) then
      call move_up(e, page, .false.)
   elseif (ct_shortcut(ior(ImGuiMod_Shift, ImGuiKey_PageUp), ImGuiInputFlags_Repeat)) then
      call move_up(e, page, .true.)
   elseif (ct_shortcut(ImGuiKey_PageDown, ImGuiInputFlags_Repeat)) then
      call move_down(e, page, .false.)
   elseif (ct_shortcut(ior(ImGuiMod_Shift, ImGuiKey_PageDown), ImGuiInputFlags_Repeat)) then
      call move_down(e, page, .true.)
   elseif (ct_shortcut(ior(ImGuiMod_Ctrl, ImGuiKey_UpArrow), 0_c_int)) then
      call move_to(e, pos(0_int32, 0_int32), .false.)
   elseif (ct_shortcut(ior(ImGuiMod_Ctrl, ImGuiKey_Home), 0_c_int)) then
      call move_to(e, pos(0_int32, 0_int32), .false.)
   elseif (ct_shortcut(ior(ior(ImGuiMod_Ctrl, ImGuiMod_Shift), ImGuiKey_UpArrow), 0_c_int)) then
      call move_to(e, pos(0_int32, 0_int32), .true.)
   elseif (ct_shortcut(ior(ior(ImGuiMod_Ctrl, ImGuiMod_Shift), ImGuiKey_Home), 0_c_int)) then
      call move_to(e, pos(0_int32, 0_int32), .true.)
   elseif (ct_shortcut(ior(ImGuiMod_Ctrl, ImGuiKey_DownArrow), 0_c_int)) then
      call move_to(e, doc_bottom(e%doc), .false.)
   elseif (ct_shortcut(ior(ImGuiMod_Ctrl, ImGuiKey_End), 0_c_int)) then
      call move_to(e, doc_bottom(e%doc), .false.)
   elseif (ct_shortcut(ior(ior(ImGuiMod_Ctrl, ImGuiMod_Shift), ImGuiKey_DownArrow), 0_c_int)) then
      call move_to(e, doc_bottom(e%doc), .true.)
   elseif (ct_shortcut(ior(ior(ImGuiMod_Ctrl, ImGuiMod_Shift), ImGuiKey_End), 0_c_int)) then
      call move_to(e, doc_bottom(e%doc), .true.)
   elseif (ct_shortcut(ImGuiKey_Home, 0_c_int)) then
      call move_to(e, pos(e%cursors%c(e%cursors%current + 1)%end%l, 0_int32), .false.)
   elseif (ct_shortcut(ior(ImGuiMod_Shift, ImGuiKey_Home), 0_c_int)) then
      call move_to(e, pos(e%cursors%c(e%cursors%current + 1)%end%l, 0_int32), .true.)
   elseif (ct_shortcut(ImGuiKey_End, 0_c_int)) then
      call move_to(e, doc_end_of_line(e%doc, e%cursors%c(e%cursors%current + 1)%end), .false.)
   elseif (ct_shortcut(ior(ImGuiMod_Shift, ImGuiKey_End), 0_c_int)) then
      call move_to(e, doc_end_of_line(e%doc, e%cursors%c(e%cursors%current + 1)%end), .true.)
   elseif (ct_shortcut(ior(ImGuiMod_Ctrl, ImGuiKey_A), 0_c_int)) then
      call move_to(e, pos(0_int32, 0_int32), .false.)
      call move_to(e, doc_bottom(e%doc), .true.)
   elseif (routed(current_selected(e), ior(ImGuiMod_Ctrl, ImGuiKey_D), 0_c_int)) then
      call add_next_occurrence(e, .false.)
   elseif (routed(current_selected(e), ior(ior(ImGuiMod_Ctrl, ImGuiMod_Alt), ImGuiKey_D), 0_c_int)) then
      call add_next_occurrence(e, .true.)
   elseif (routed(current_selected(e), ior(ior(ImGuiMod_Ctrl, ImGuiMod_Alt), ImGuiKey_L), 0_c_int)) then
      call add_next_occurrence(e, .true.)
   elseif (routed(current_selected(e), ior(ior(ImGuiMod_Ctrl, ImGuiMod_Shift), ImGuiKey_D), 0_c_int)) then
      call select_all_of_current(e, .false.)
   elseif (routed(current_selected(e), &
           ior(ior(ior(ImGuiMod_Ctrl, ImGuiMod_Alt), ImGuiMod_Shift), ImGuiKey_D), 0_c_int)) then
      call select_all_of_current(e, .true.)
   elseif (ct_shortcut(ior(ImGuiMod_Ctrl, ImGuiKey_X), 0_c_int)) then
      call cut(e) ! the fork's private cut: no read-only test
   elseif (ct_shortcut(ior(ImGuiMod_Ctrl, ImGuiKey_C), 0_c_int)) then
      call copy(e)
   elseif (ct_shortcut(ior(ImGuiMod_Ctrl, ImGuiKey_Insert), 0_c_int)) then
      call copy(e)
   elseif (routed(.not. ro, ior(ImGuiMod_Ctrl, ImGuiKey_V), ImGuiInputFlags_Repeat)) then
      call paste(e)
   elseif (routed(.not. ro, ior(ImGuiMod_Ctrl, ImGuiKey_Insert), ImGuiInputFlags_Repeat)) then
      call paste(e)
   elseif (routed(.not. ro, ior(ImGuiMod_Ctrl, ImGuiKey_Z), ImGuiInputFlags_Repeat)) then
      call editor_undo_(e)
   elseif (routed(.not. ro, ior(ior(ImGuiMod_Ctrl, ImGuiMod_Shift), ImGuiKey_Z), ImGuiInputFlags_Repeat)) then
      call editor_redo_(e)
   elseif (routed(.not. ro, ior(ImGuiMod_Ctrl, ImGuiKey_Y), ImGuiInputFlags_Repeat)) then
      call editor_redo_(e)
   elseif (routed(.not. ro, ImGuiKey_Delete, ImGuiInputFlags_Repeat)) then
      call handle_delete(e, .false.)
   elseif (routed(.not. ro, ior(ImGuiMod_Shift, ImGuiKey_Delete), ImGuiInputFlags_Repeat)) then
      call handle_delete(e, .false.)
   elseif (routed(.not. ro, ior(word_mod, ImGuiKey_Delete), ImGuiInputFlags_Repeat)) then
      call handle_delete(e, .true.)
   elseif (routed(.not. ro, ImGuiKey_Backspace, ImGuiInputFlags_Repeat)) then
      call handle_backspace(e, .false.)
   elseif (routed(.not. ro, ior(ImGuiMod_Shift, ImGuiKey_Backspace), ImGuiInputFlags_Repeat)) then
      call handle_backspace(e, .false.)
   elseif (routed(.not. ro, ior(word_mod, ImGuiKey_Backspace), ImGuiInputFlags_Repeat)) then
      call handle_backspace(e, .true.)
   elseif (routed(.not. ro, ior(ior(ImGuiMod_Ctrl, ImGuiMod_Shift), ImGuiKey_K), 0_c_int)) then
      call remove_selected_lines(e)
   elseif (routed(.not. ro, ior(ImGuiMod_Ctrl, ImGuiKey_LeftBracket), ImGuiInputFlags_Repeat)) then
      call indent_lines(e, .true.)
   elseif (routed(.not. ro, ior(ImGuiMod_Ctrl, ImGuiKey_RightBracket), ImGuiInputFlags_Repeat)) then
      call indent_lines(e, .false.)
   elseif (routed(.not. ro, ior(ImGuiMod_Alt, ImGuiKey_UpArrow), 0_c_int)) then
      call move_lines(e, .false.)
   elseif (routed(.not. ro, ior(ImGuiMod_Alt, ImGuiKey_DownArrow), 0_c_int)) then
      call move_lines(e, .true.)
   elseif (routed(.not. ro .and. e%language /= 0_int32, ior(ImGuiMod_Ctrl, ImGuiKey_Slash), 0_c_int)) then
      call toggle_comments(e)
   elseif (routed(.not. ro .and. e%language /= 0_int32, ior(ImGuiMod_Ctrl, ImGuiKey_L), 0_c_int)) then
      call toggle_comments(e)
   elseif (routed(e%find_replace, ior(ImGuiMod_Ctrl, ImGuiKey_F), 0_c_int)) then
      if (e%ac_active) then
         call ac_cancel(e)
         e%find_cancelled_ac = .true.
      endif
      call open_find_replace(e)
   elseif (routed(e%find_replace, ior(ior(ImGuiMod_Ctrl, ImGuiMod_Shift), ImGuiKey_F), 0_c_int)) then
      call find_action(e, 3_int32)
   elseif (routed(e%find_replace, ior(ImGuiMod_Ctrl, ImGuiKey_G), ImGuiInputFlags_Repeat)) then
      call find_action(e, 2_int32)
   elseif (routed(.not. ro, ior(ImGuiMod_Ctrl, ImGuiKey_Space), 0_c_int)) then
      if (e%cursors%n == 1_int32) then
         if (ac_start_shortcut(e)) call make_cursor_visible(e)
      endif
   elseif (ct_shortcut(ImGuiKey_Insert, 0_c_int)) then
      e%overwrite = .not. e%overwrite
   elseif (routed(.not. ro, ImGuiKey_Enter, ImGuiInputFlags_Repeat)) then
      call handle_character(e, 10_int32)
   elseif (routed(.not. ro, ImGuiKey_KeypadEnter, ImGuiInputFlags_Repeat)) then
      call handle_character(e, 10_int32)
   elseif (routed(.not. ro, ior(ImGuiMod_Ctrl, ImGuiKey_Enter), ImGuiInputFlags_Repeat)) then
      call insert_line(e, .true.)
   elseif (routed(.not. ro, ior(ImGuiMod_Ctrl, ImGuiKey_KeypadEnter), ImGuiInputFlags_Repeat)) then
      call insert_line(e, .true.)
   elseif (routed(.not. ro, ior(ImGuiMod_Shift, ImGuiKey_Enter), ImGuiInputFlags_Repeat)) then
      call insert_line(e, .false.)
   elseif (routed(.not. ro, ior(ImGuiMod_Shift, ImGuiKey_KeypadEnter), ImGuiInputFlags_Repeat)) then
      call insert_line(e, .false.)
   elseif (routed(.not. ro, ImGuiKey_Tab, ImGuiInputFlags_Repeat)) then
      if (cursors_any_selection(e%cursors)) then
         call indent_lines(e, .false.)
      else
         call handle_character(e, 9_int32)
      endif
   elseif (routed(.not. ro, ior(ImGuiMod_Shift, ImGuiKey_Tab), ImGuiInputFlags_Repeat)) then
      call indent_lines(e, .true.)
   elseif (routed(e%ac_active .or. e%find_visible .or. e%cursors%n > 1_int32, ImGuiKey_Escape, 0_c_int)) then
      if (e%ac_active) then
         call ac_cancel(e)
      elseif (e%find_visible) then
         call close_find_replace(e)
      elseif (e%cursors%n > 1_int32) then
         call cursors_clear_additional(e%cursors, .false.)
      endif
   endif
   n = ct_chars(chars, .false.)
   if (n > 0_c_int) then
      if (.not. (ct_key_down(ImGuiMod_Ctrl) .and. .not. ct_key_down(ImGuiMod_Alt)) .and. .not. ro) then
         do k = 1_c_int, min(n, size(chars, kind=c_int))
            if (chars(k) == 10_c_int .or. chars(k) >= 32_c_int) call handle_character(e, int(chars(k), int32))
         enddo
      endif
      n = ct_chars(chars, .true.)
   endif
   if (.not. ro) then
      call vis_pos(e, e%cursors%c(min(e%cursors%main, e%cursors%n - 1_int32) + 1)%end, r, c)
      call ct_ime(e%screen_x + e%text_left + real(c, c_float) * e%glyph_w - 1.0_c_float, &
                  e%screen_y + real(r, c_float) * e%glyph_h, e%glyph_h)
   endif
   call ct_want_keyboard()
   endsubroutine handle_keys

   function routed(cond, chord, flags) result(yes)
   !< `cond && Shortcut(chord, flags)` with the C++ short circuit: `Shortcut` asked only when `cond` holds (a call
   !< routes its chord: an extra one changes which shortcut wins).
   logical,        intent(in) :: cond  !< The test before the shortcut.
   integer(c_int), intent(in) :: chord !< Key chord.
   integer(c_int), intent(in) :: flags !< `ImGuiInputFlags_*`.
   logical                    :: yes   !< Both.

   yes = .false.
   if (cond) yes = ct_shortcut(chord, flags)
   endfunction routed

   pure function start_line(c) result(l)
   !< The line of a cursor's selection start.
   type(code_cursor), intent(in) :: c !< Cursor.
   integer(int32)                :: l !< Line, from 0.
   type(code_pos)                :: p !< Selection start.

   p = cursor_selection_start(c)
   l = p%l
   endfunction start_line

   pure function current_selected(e) result(yes)
   !< `cursors.currentCursorHasSelection()`.
   type(code_editor), intent(in) :: e   !< Editor.
   logical                       :: yes !< The current cursor has a selection.

   yes = cursor_has_selection(e%cursors%c(e%cursors%current + 1))
   endfunction current_selected

   function ac_special_key() result(yes)
   !< `AutoComplete::isSpecialKeyPressed`.
   logical :: yes !< Tab, enter or an up or down arrow pressed.

   yes = ct_key_pressed(ImGuiKey_Tab) .or. ct_key_pressed(ImGuiKey_Enter) .or. ct_key_pressed(ImGuiKey_KeypadEnter) .or. &
         ct_key_pressed(ImGuiKey_UpArrow) .or. ct_key_pressed(ImGuiKey_DownArrow)
   endfunction ac_special_key

   function ac_start_shortcut(e) result(started)
   !< `AutoComplete::startShortcut`.
   type(code_editor), intent(inout) :: e       !< Editor.
   logical                          :: started !< A session asked for.

   started = .false.
   if (e%ac_active .or. e%ac_request_activation .or. .not. e%ac_configured) return
   e%ac_manual = .true.
   e%ac_request_activation = .true.
   e%ac_location = cursor_selection_end(e%cursors%c(e%cursors%main + 1))
   started = .true.
   endfunction ac_start_shortcut

   subroutine screen_to_doc(e, x, y, glyph, cursor)
   !< `TypeSetter::screenPos2DocPos` (x, y in glyphs from the text's corner).
   type(code_editor), intent(in)  :: e      !< Editor.
   real(c_float),     intent(in)  :: x, y   !< Position [glyphs].
   type(code_pos),    intent(out) :: glyph  !< The glyph under it.
   type(code_pos),    intent(out) :: cursor !< The cursor position nearest to it.
   integer(int32)                 :: row, j, idx, left, right !< Row, glyph, columns.
   real(c_float)                  :: ld, rd !< Distances.

   if (y <= 0.0_c_float) then
      glyph = pos(0_int32, 0_int32)
      cursor = glyph
      return
   endif
   if (y >= real(e%ts_rows, c_float)) then
      glyph = doc_bottom(e%doc)
      cursor = glyph
      return
   endif
   row = int(y, int32)
   if (x <= 0.0_c_float) then
      glyph = pos(row, 0_int32)
      cursor = glyph
   elseif (aint(x) > real(e%ts_cols(row + 1), c_float)) then
      glyph = doc_end_of_line(e%doc, pos(row, 0_int32))
      cursor = glyph
   else
      idx = 0_int32
      left = 0_int32
      right = 0_int32
      j = 1_int32
      do while (real(right, c_float) < x .and. j <= e%doc%lines(row + 1)%n)
         left = right
         right = right + e%doc%lines(row + 1)%cols(j)
         idx = idx + 1_int32
         j = j + 1_int32
      enddo
      ld = x - real(left, c_float)
      rd = real(right, c_float) - x
      if (left == right) then
         glyph = pos(row, idx)
      else
         glyph = pos(row, idx - 1_int32)
      endif
      if (ld <= rd) then
         cursor = pos(row, idx - 1_int32)
      else
         cursor = pos(row, idx)
      endif
   endif
   endsubroutine screen_to_doc

   subroutine handle_mouse(e)
   !< `handleMouseInteractions` (FIGURE sets no context menu or hover callback; no mini-map).
   type(code_editor), intent(inout) :: e      !< Editor.
   real(c_float)                    :: mx, my, wx, wy, ax, ay, sx, sy, dx, dy, ww, wh, factor, now, dz, f(16) !< State.
   integer(c_int)                   :: fi(5)  !< Flags.
   logical                          :: over_numbers, over_text, dbl, triple, handled, extend, add, down !< Tests.
   type(code_pos)                   :: glyph, cur, a, b !< Positions.
   integer(int32)                   :: cp, k  !< Code point, pair.

   call ct_mouse_pos(mx, my)
   call ct_window_pos(wx, wy)
   ax = mx - wx
   ay = my - wy
   mx = mx - e%screen_x
   my = my - e%screen_y
   call ct_scroll(sx, sy)
   call ct_state(f, fi)
   over_numbers = e%line_numbers .and. ax > e%number_left .and. ax < e%number_right
   over_text = mx - sx > e%text_left .and. mx - sx < e%text_right .and. my - sy >= 0.0_c_float .and. my - sy < e%text_h
   call screen_to_doc(e, (mx - e%text_left) / e%glyph_w, my / e%glyph_h, glyph, cur)
   e%panning = e%panning .and. ct_mouse_down(2_c_int)
   if (e%panning .and. ct_mouse_dragging(2_c_int)) then
      call ct_window_size(ww, wh)
      call ct_mouse_drag_delta(2_c_int, dx, dy)
      factor = f(6) * 15.0_c_float
      if (ax < e%text_left + e%glyph_w * 4.0_c_float) then
         dx = (ax - (e%text_left + e%glyph_w * 4.0_c_float)) * factor
      elseif (ax > ww - e%glyph_w * 4.0_c_float) then
         dx = (ax - (ww - e%glyph_w * 4.0_c_float)) * factor
      endif
      if (ay < e%glyph_h * 2.0_c_float) then
         dy = (ay - e%glyph_h * 2.0_c_float) * factor
      elseif (ay > wh - e%glyph_h * 2.0_c_float) then
         dy = (ay - (wh - e%glyph_h * 2.0_c_float)) * factor
      endif
      call ct_set_scroll_x(sx - dx)
      call ct_scroll(sx, sy)
      call ct_set_scroll_y(sy - dy)
      call ct_reset_mouse_drag_delta(2_c_int)
   elseif (e%scrolling) then
      dz = e%glyph_w
      dx = e%scroll_start(1) - ax
      dy = e%scroll_start(2) - ay
      if (dx < 0.0_c_float) then
         dx = min(dx + dz, 0.0_c_float)
      else
         dx = max(dx - dz, 0.0_c_float)
      endif
      if (dy < 0.0_c_float) then
         dy = min(dy + dz, 0.0_c_float)
      else
         dy = max(dy - dz, 0.0_c_float)
      endif
      factor = f(6) * 5.0_c_float
      dx = dx * factor
      dy = dy * factor
      call ct_set_scroll_x(sx - dx)
      call ct_scroll(sx, sy)
      call ct_set_scroll_y(sy - dy)
      if (ct_mouse_clicked(0_c_int) .or. ct_mouse_clicked(2_c_int) .or. ct_mouse_clicked(1_c_int)) e%scrolling = .false.
   elseif (ct_mouse_dragging(0_c_int)) then
      if (e%selecting_text .and. over_numbers) then
         a = pos(cur%l, 0_int32)
         b = doc_normalize(e%doc, pos(cur%l + 1_int32, 0_int32))
         associate(cc => e%cursors%c(e%cursors%current + 1))
            if (pos_lt(cc%end, cc%start)) then
               call cursor_update_keep(cc, a, .true.)
            else
               call cursor_update_keep(cc, b, .true.)
            endif
         endassociate
         call make_cursor_visible(e)
      elseif (e%selecting_text .and. over_text) then
         call cursor_update_keep(e%cursors%c(e%cursors%current + 1), cur, .true.)
         call make_cursor_visible(e)
      endif
   elseif (ct_mouse_released(0_c_int)) then
      e%selecting_text = .false.
   elseif (ct_window_hovered()) then
      if (ct_window_focused() .and. over_text) call ct_set_mouse_cursor(ImGuiMouseCursor_TextInput)
      if (ct_mouse_clicked(2_c_int)) then
         e%panning = .true.
      elseif (ct_mouse_clicked(1_c_int)) then
         continue ! no context menu callbacks
      elseif (ct_mouse_clicked(0_c_int)) then
         e%selecting_text = over_text .or. over_numbers
         dbl = ct_mouse_double_clicked(0_c_int)
         now = real(ct_time(), c_float)
         triple = .not. dbl .and. e%last_click_time /= -1.0_c_float .and. (now - e%last_click_time) < f(7)
         if (triple) then
            e%last_click_time = -1.0_c_float
         else
            e%last_click_time = now
         endif
         if (triple) then
            if (over_text) then
               a = pos(cur%l, 0_int32)
               b = doc_normalize(e%doc, pos(a%l + 1_int32, 0_int32))
               call cursor_update(e%cursors%c(e%cursors%current + 1), a, b)
            endif
         elseif (dbl) then
            if (over_text) then
               cp = doc_cp(e%doc, glyph)
               handled = .false.
               if (cp_is_bracket_opener(cp)) then
                  k = enclosing_brackets(e, doc_right(e%doc, glyph, .false.))
                  if (k > 0_int32) then
                     if (ct_key_down(ImGuiMod_Shift)) then
                        call cursors_set(e%cursors, e%br_start(k), doc_right(e%doc, e%br_end(k), .false.))
                     else
                        call cursors_set(e%cursors, doc_right(e%doc, e%br_start(k), .false.), e%br_end(k))
                     endif
                     handled = .true.
                  endif
               elseif (cp_is_bracket_closer(cp)) then
                  k = enclosing_brackets(e, glyph)
                  if (k > 0_int32) then
                     call cursors_set(e%cursors, e%br_start(k), doc_right(e%doc, e%br_end(k), .false.))
                     handled = .true.
                  endif
               endif
               if (.not. handled .and. glyph%i /= e%doc%lines(glyph%l + 1)%n) then
                  call doc_whole_word(e%doc, glyph, .false., a, b)
                  if (.not. pos_eq(a, b)) call cursor_update(e%cursors%c(e%cursors%current + 1), a, b)
               endif
            endif
         else
            extend = ct_key_down(ImGuiMod_Shift)
            if (fi(3) /= 0_c_int) then
               add = ct_key_down(ImGuiMod_Alt)
            else
               add = ct_key_down(ImGuiMod_Ctrl)
            endif
            if (over_numbers) then
               a = pos(cur%l, 0_int32)
               b = doc_normalize(e%doc, pos(cur%l + 1_int32, 0_int32))
               if (extend) then
                  associate(cc => e%cursors%c(e%cursors%current + 1))
                     if (pos_lt(cc%end, cc%start)) then
                        call cursor_update_keep(cc, a, .true.)
                     else
                        call cursor_update_keep(cc, b, .true.)
                     endif
                  endassociate
                  call ac_cancel(e)
               elseif (add) then
                  call cursors_add(e%cursors, a, b)
                  call ac_cancel(e)
               else
                  call cursors_set(e%cursors, a, b)
               endif
               call make_cursor_visible(e)
            elseif (over_text) then
               if (extend) then
                  call cursor_grow(e%cursors%c(e%cursors%current + 1), cur)
                  call ac_cancel(e)
               elseif (add) then
                  call cursors_add(e%cursors, cur, cur)
                  call ac_cancel(e)
               else
                  call cursors_set(e%cursors, cur, cur)
               endif
               call make_cursor_visible(e)
            endif
         endif
      endif
      down = ct_mouse_down(0_c_int) .or. ct_mouse_down(1_c_int)
      if (down) then
         call cursors_update(e%cursors)
         e%navigating_vertically = .false.
      endif
   endif
   endsubroutine handle_mouse
   ! ---- find and replace's state (its window: szaghi/figure#15 P16 step 13) ----------------------------------------
   subroutine open_find_replace(e)
   !< `openFindReplace`: the main cursor's one-line selection, or the word it is in, as the text to find.
   type(code_editor), intent(inout) :: e    !< Editor.
   type(code_pos)                   :: a, b !< Selection, word.

   associate(c => e%cursors%c(e%cursors%main + 1))
      if (cursor_has_selection(c)) then
         a = cursor_selection_start(c)
         b = cursor_selection_end(c)
         if (a%l == b%l) e%find_text = doc_section_text(e%doc, a, b)
      else
         call doc_whole_word(e%doc, cursor_selection_start(c), .true., a, b)
         if (.not. pos_eq(a, b)) e%find_text = doc_section_text(e%doc, a, b)
      endif
   endassociate
   e%find_visible = .true.
   e%focus_on_find = .true.
   endsubroutine open_find_replace

   subroutine close_find_replace(e)
   !< `closeFindReplace`.
   type(code_editor), intent(inout) :: e !< Editor.

   if (.not. e%find_visible) return
   e%find_visible = .false.
   e%focus_on_editor = .true.
   e%focus_on_find = .false.
   endsubroutine close_find_replace

   subroutine find_action(e, what)
   !< `find` (1), `findNext` (2), `findAll` (3), `replace` (4), `replaceAll` (5).
   type(code_editor), intent(inout) :: e    !< Editor.
   integer(int32),    intent(in)    :: what !< Action.

   if (len(e%find_text) == 0) return
   select case (what)
   case (1_int32, 2_int32)
      call select_next_occurrence(e, e%find_text, e%find_case, e%find_whole)
   case (3_int32)
      call select_all_occurrences(e, e%find_text, e%find_case, e%find_whole)
   case (4_int32)
      if (.not. cursors_any_selection(e%cursors)) call select_next_occurrence(e, e%find_text, e%find_case, e%find_whole)
      call replace_in_current_cursor(e, e%replace_text)
      call select_next_occurrence(e, e%find_text, e%find_case, e%find_whole)
   case default
      call select_all_occurrences(e, e%find_text, e%find_case, e%find_whole)
      call start_transaction(e, .true.)
      call insert_into_all_cursors(e, e%replace_text)
      call end_transaction(e)
   endselect
   e%focus_on_editor = .true.
   e%focus_on_find = .false.
   endsubroutine find_action

   ! ---- the autocomplete popup and the find and replace window (szaghi/figure#15 P16 step 13) ---------------------
   function ac_word_start(e, p) result(q)
   !< `AutoComplete::findWordStart`.
   type(code_editor), intent(in) :: e !< Editor.
   type(code_pos),    intent(in) :: p !< From.
   type(code_pos)                :: q !< Start of the term.

   q = p
   do while (q%i > 0_int32)
      if (.not. ac_word_character(e, e%doc%lines(q%l + 1)%cp(q%i))) exit
      q%i = q%i - 1_int32
   enddo
   endfunction ac_word_start

   function ac_word_end(e, p) result(q)
   !< `AutoComplete::findWordEnd`.
   type(code_editor), intent(in) :: e !< Editor.
   type(code_pos),    intent(in) :: p !< From.
   type(code_pos)                :: q !< End of the word.

   q = p
   do while (q%i < e%doc%lines(q%l + 1)%n)
      if (.not. ac_word_character(e, e%doc%lines(q%l + 1)%cp(q%i + 1))) exit
      q%i = q%i + 1_int32
   enddo
   endfunction ac_word_end

   subroutine ac_update_state(e, in_comment, in_string)
   !< `AutoComplete::updateState`: the search term, where it is, the section a pick replaces.
   type(code_editor), intent(inout) :: e          !< Editor.
   logical,           intent(out)   :: in_comment !< In a comment.
   logical,           intent(out)   :: in_string  !< In a string.
   integer(int32)                   :: s          !< A line state.
   integer(int8)                    :: col        !< A glyph's colour.

   e%ac_term = doc_section_text(e%doc, e%ac_start, e%ac_location)
   if (e%ac_location%i == 0_int32) then
      s = e%doc%lines(e%ac_location%l + 1)%state
      in_comment = s >= 1_int32 .and. s <= 8_int32
      in_string = s >= 9_int32 .and. s <= 20_int32
   else
      col = e%doc%lines(e%ac_location%l + 1)%color(e%ac_location%i)
      in_comment = col == COLOR_COMMENT
      in_string = col == COLOR_STRING
   endif
   e%ac_rstart = e%ac_start
   e%ac_rend = ac_word_end(e, e%ac_location)
   endsubroutine ac_update_state

   subroutine ac_refresh(e)
   !< `refreshSuggestions` with the glue's callback (`suggest`): the program's words starting with the term (in any
   !< case, the term itself left out), then those containing it; a term's leading blanks skipped.
   type(code_editor), intent(inout) :: e    !< Editor.
   character(len=:), allocatable    :: term, w !< The term in lower case, a word.
   integer(int32)                   :: lead, pass, a, k, n !< Blanks, pass, a word's start, counters.

   e%offered = ''
   e%noffered = 0_int32
   lead = 0_int32
   do while (lead < len(e%ac_term, int32))
      if (e%ac_term(lead + 1:lead + 1) /= ' ' .and. e%ac_term(lead + 1:lead + 1) /= achar(9)) exit
      lead = lead + 1_int32
   enddo
   term = lower_ascii(e%ac_term(lead + 1:))
   e%ac_rstart%i = e%ac_rstart%i + lead
   if (len(term) > 0) then
      do pass = 1_int32, 2_int32
         a = 1_int32
         n = len(e%words, int32)
         do k = 1_int32, n + 1_int32
            if (k <= n) then
               if (e%words(k:k) /= achar(10)) cycle
            endif
            w = lower_ascii(e%words(a:k - 1_int32))
            if (pass == 1_int32) then
               if (starts(w, term) .and. .not. (w == term .and. len(w) == len(term))) call offer(e%words(a:k - 1_int32))
            else
               if (.not. starts(w, term) .and. index(w, term) > 0) call offer(e%words(a:k - 1_int32))
            endif
            a = k + 1_int32
         enddo
      enddo
   endif
   e%ac_selection = 0_int32
   contains
      subroutine offer(word)
      !< A suggestion appended.
      character(len=*), intent(in) :: word !< Word.

      if (e%noffered > 0_int32) e%offered = e%offered//achar(10)
      e%offered = e%offered//word
      e%noffered = e%noffered + 1_int32
      endsubroutine offer
   endsubroutine ac_refresh

   pure function starts(w, t) result(yes)
   !< `w` starts with `t`.
   character(len=*), intent(in) :: w, t !< Strings.
   logical                      :: yes  !< A prefix.

   yes = len(w) >= len(t)
   if (yes) yes = w(1:len(t)) == t
   endfunction starts

   pure function lower_ascii(s) result(l)
   !< ASCII lower case.
   character(len=*), intent(in) :: s !< String.
   character(len=len(s))        :: l !< Lower case.
   integer(int32)               :: i, c !< Counter, code.

   l = s
   do i = 1_int32, len(s, int32)
      c = iachar(s(i:i))
      if (c >= 65_int32 .and. c <= 90_int32) l(i:i) = achar(c + 32_int32)
   enddo
   endfunction lower_ascii

   function offered_word(e, k) result(w)
   !< Suggestion k (from 0).
   type(code_editor), intent(in) :: e !< Editor.
   integer(int32),    intent(in) :: k !< Suggestion.
   character(len=:), allocatable :: w !< Word.
   integer(int32)                :: j, a, n, i !< Counters.

   w = ''
   a = 1_int32
   n = 0_int32
   do i = 1_int32, len(e%offered, int32) + 1_int32
      if (i <= len(e%offered, int32)) then
         if (e%offered(i:i) /= achar(10)) cycle
      endif
      if (n == k) then
         w = e%offered(a:i - 1_int32)
         return
      endif
      n = n + 1_int32
      a = i + 1_int32
   enddo
   j = 0_int32
   endfunction offered_word

   function ac_replacement_start(e) result(p)
   !< `getReplacementStart`.
   type(code_editor), intent(in) :: e !< Editor.
   type(code_pos)                :: p !< Start.

   if (e%ac_rstart%l == e%ac_location%l .and. e%ac_rstart%i <= e%ac_location%i) then
      p = e%ac_rstart
   else
      p = e%ac_start
   endif
   endfunction ac_replacement_start

   function ac_replacement_end(e) result(p)
   !< `getReplacementEnd`.
   type(code_editor), intent(in) :: e !< Editor.
   type(code_pos)                :: p !< End.

   if (e%ac_rend%l == e%ac_location%l .and. e%ac_rend%i >= e%ac_location%i .and. &
       e%ac_rend%i <= e%doc%lines(e%ac_rend%l + 1)%n) then
      p = e%ac_rend
   else
      p = ac_word_end(e, e%ac_location)
   endif
   endfunction ac_replacement_end

   function render_suggestion(e, text, term, width, selected) result(clicked)
   !< The fork's `renderSuggestion`: an invisible button, the text glyph by glyph, the term's glyphs as a link.
   type(code_editor), intent(in) :: e        !< Editor.
   character(len=*),  intent(in) :: text     !< Suggestion.
   character(len=*),  intent(in) :: term     !< The term typed.
   real(c_float),     intent(in) :: width    !< Width.
   logical,           intent(in) :: selected !< The selected one.
   logical                       :: clicked  !< Clicked.
   real(c_float)                 :: x, y, h, gw, f(16) !< Position, height, glyph width, style.
   integer(c_int)                :: fi(5), col !< Flags, colour.
   integer(int32)                :: i, j, cp, sp, jn !< Bytes, code points.

   call ct_cursor_screen_pos(x, y)
   h = ct_frame_height_with_spacing()
   clicked = ct_invisible_button('suggestion', width, h)
   gw = ct_text_width('#')
   if (selected) call ct_rect_filled(x, y, x + width, y + h, ct_style_u32(ImGuiCol_Header))
   call ct_state(f, fi)
   x = x + f(14)
   y = y + f(15)
   i = 1_int32
   if (len(text) >= 3) then
      if (text(1:3) == achar(239)//achar(187)//achar(191)) i = 4_int32
   endif
   j = 1_int32
   if (len(term) >= 3) then
      if (term(1:3) == achar(239)//achar(187)//achar(191)) j = 4_int32
   endif
   do while (i <= len(text, int32))
      call cp_read(text, i, cp)
      col = ct_style_u32(ImGuiCol_Text)
      if (j <= len(term, int32)) then
         jn = j
         call cp_read(term, jn, sp)
         if (cp_to_lower(sp) == cp_to_lower(cp)) then
            col = ct_style_u32(ImGuiCol_TextLink)
            j = jn
         endif
      endif
      call ct_char(x, y, col, cp)
      x = x + gw
   enddo
   endfunction render_suggestion

   subroutine render_autocomplete(e, picked)
   !< `AutoComplete::render`; `picked` when the user chose a suggestion.
   type(code_editor), intent(inout) :: e      !< Editor.
   logical,           intent(out)   :: picked !< A suggestion picked.
   logical                          :: in_comment, in_string, scroll !< Where the term is, scroll to the selection.
   type(code_pos)                   :: now, start !< The cursor, its term's start.
   integer(int32)                   :: r, c, n, visible, k !< Visual position, suggestions.
   real(c_float)                    :: x, y, f(16) !< Cursor, style.
   integer(c_int)                   :: fi(5) !< Flags.
   character(len=:), allocatable    :: term  !< The term highlighted.

   picked = .false.
   if (e%ac_request_activation .and. .not. e%ac_active) then
      if (.not. ct_window_focused() .or. .not. pos_eq(cursor_selection_end(e%cursors%c(e%cursors%main + 1)), &
                                                      e%ac_location)) then
         e%ac_request_activation = .false.
      else
         e%ac_request_activation = .false.
         e%ac_start = ac_word_start(e, e%ac_location)
         call ac_update_state(e, in_comment, in_string)
         if (in_comment .or. in_string) return
         call ac_refresh(e)
         call ct_open_popup('AutoCompleteContextMenu')
         e%ac_active = .true.
      endif
   endif
   if (.not. e%ac_active) return
   now = cursor_selection_end(e%cursors%c(e%cursors%main + 1))
   if (.not. pos_eq(now, e%ac_location)) then
      if (now%l /= e%ac_location%l) then
         e%ac_request_deactivation = .true.
      else
         start = ac_word_start(e, now)
         if (pos_eq(start, e%ac_start)) then
            e%ac_location = now
            if (pos_eq(e%ac_location, e%ac_start)) then
               e%ac_request_deactivation = .true.
            else
               call ac_update_state(e, in_comment, in_string)
               call ac_refresh(e)
            endif
         else
            e%ac_request_deactivation = .true.
         endif
      endif
   endif
   call vis_pos(e, e%ac_location, r, c)
   call ct_cursor_screen_pos(x, y)
   call ct_set_next_window_pos(x + e%text_left + real(c, c_float) * e%glyph_w, y + real(r + 1_int32, c_float) * e%glyph_h)
   n = e%noffered
   if (n == 0_int32 .and. .not. e%ac_manual) e%ac_request_deactivation = .true.
   visible = 1_int32
   if (n > 0_int32) visible = min(10_int32, n)
   call ct_state(f, fi)
   call ct_set_next_window_size(30.0_c_float * e%glyph_w, &
                                ct_frame_height_with_spacing() * real(visible, c_float) + f(11) * 2.0_c_float)
   if (ct_begin_popup('AutoCompleteContextMenu', ior(ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav))) then
      if (ct_window_appearing()) call ct_bring_to_front()
      if (e%ac_request_deactivation) then
         call ct_close_current_popup()
         e%ac_request_deactivation = .false.
         e%ac_active = .false.
      elseif (n > 0_int32) then
         scroll = .false.
         if (ct_key_pressed(ImGuiKey_UpArrow)) then
            scroll = .true.
            if (e%ac_selection == 0_int32) then
               e%ac_selection = n - 1_int32
            else
               e%ac_selection = e%ac_selection - 1_int32
            endif
         elseif (ct_key_pressed(ImGuiKey_DownArrow)) then
            scroll = .true.
            if (e%ac_selection == n - 1_int32) then
               e%ac_selection = 0_int32
            else
               e%ac_selection = e%ac_selection + 1_int32
            endif
         elseif (ct_key_pressed(ImGuiKey_Tab) .or. ct_key_pressed(ImGuiKey_Enter) .or. &
                 ct_key_pressed(ImGuiKey_KeypadEnter)) then
            e%ac_request_deactivation = .true.
            picked = .true.
         endif
         term = doc_section_text(e%doc, ac_replacement_start(e), e%ac_location)
         do k = 0_int32, n - 1_int32
            call ct_push_id_int(int(k, c_int))
            if (scroll .and. k == e%ac_selection) call ct_set_scroll_here_y(0.5_c_float)
            call ct_content_avail(x, y)
            if (render_suggestion(e, offered_word(e, k), term, x, k == e%ac_selection)) then
               e%ac_selection = k
               e%ac_request_deactivation = .true.
               picked = .true.
            endif
            call ct_pop_id()
         enddo
      else
         call ct_text_unformatted('No suggestions')
      endif
      call ct_end_popup()
   else
      e%ac_request_deactivation = .false.
      e%ac_active = .false.
   endif
   endsubroutine render_autocomplete

   subroutine replace_section(e, a, b, text)
   !< `replaceSectionText`.
   type(code_editor), intent(inout) :: e    !< Editor.
   type(code_pos),    intent(in)    :: a, b !< Section.
   character(len=*),  intent(in)    :: text !< Text.
   type(code_pos)                   :: t    !< End of the insert.

   call start_transaction(e, .true.)
   call delete_text(e, a, b)
   call insert_text(e, a, text, t)
   call cursors_clear_additional(e%cursors, .false.)
   call cursor_update(e%cursors%c(e%cursors%main + 1), t, t)
   call end_transaction(e)
   endsubroutine replace_section

   function latch_button(label, value, w) result(changed)
   !< The fork's `latchButton`: a button showing a state, toggled by a click.
   character(len=*), intent(in)    :: label   !< Label.
   logical,          intent(inout) :: value   !< State.
   real(c_float),    intent(in)    :: w       !< Width.
   logical                         :: changed !< Toggled.
   real(c_float)                   :: active(4), light(4) !< The style's colours.
   logical                         :: unused  !< Button's result.

   changed = .false.
   call ct_style_color(ImGuiCol_ButtonActive, active)
   call ct_style_color(ImGuiCol_TableBorderLight, light)
   if (value) then
      call ct_push_style_color_vec4(ImGuiCol_Button, active)
      call ct_push_style_color_vec4(ImGuiCol_ButtonHovered, active)
      call ct_push_style_color_vec4(ImGuiCol_ButtonActive, light)
   else
      call ct_push_style_color_vec4(ImGuiCol_Button, light)
      call ct_push_style_color_vec4(ImGuiCol_ButtonHovered, light)
      call ct_push_style_color_vec4(ImGuiCol_ButtonActive, active)
   endif
   unused = ct_button(label, w, 0.0_c_float)
   if (ct_item_clicked()) then
      value = .not. value
      changed = .true.
   endif
   call ct_pop_style_color(3_c_int)
   endfunction latch_button

   subroutine render_find_replace(e)
   !< `renderFindReplace`: the find and replace window, a child at the editor's top right.
   type(code_editor), intent(inout) :: e  !< Editor.
   real(c_float)                    :: sx, sy, f(16), field, b1, b2, opt, wh, ww, avail, wx, wy, scroll_w !< Layout.
   integer(c_int)                   :: fi(5) !< Flags.
   logical                          :: disable, edited, unused !< Find buttons disabled, a field edited.

   if (.not. e%find_visible) return
   call ct_cursor_screen_pos(sx, sy)
   call ct_push_style_var_vec2(ImGuiStyleVar_ItemSpacing, 6.0_c_float, 4.0_c_float)
   call ct_state(f, fi)
   field = 250.0_c_float * f(3)
   b1 = ct_text_width('Find') + f(12) * 2.0_c_float
   b2 = ct_text_width('Find All') + f(12) * 2.0_c_float
   opt = 0.0_c_float
   opt = max(opt, ct_text_width('Aa'))
   opt = max(opt, ct_text_width('[]'))
   opt = max(opt, ct_text_width('x'))
   opt = opt + f(12) * 2.0_c_float
   if (.not. e%read_only) then
      b1 = max(b1, ct_text_width('Replace') + f(12) * 2.0_c_float)
      b2 = max(b2, ct_text_width('Replace All') + f(12) * 2.0_c_float)
   endif
   wh = f(9) * 2.0_c_float
   wh = wh + f(11) * 2.0_c_float
   wh = wh + ct_frame_height()
   if (e%read_only) then
      wh = wh + 0.0_c_float
   else
      wh = wh + (f(13) + ct_frame_height())
   endif
   ww = f(9) * 2.0_c_float
   ww = ww + f(10) * 2.0_c_float
   ww = ww + field
   ww = ww + f(12)
   ww = ww + b1
   ww = ww + f(12)
   ww = ww + b2
   ww = ww + f(12)
   ww = ww + opt * 3.0_c_float
   ww = ww + f(12) * 2.0_c_float
   scroll_w = 0.0_c_float
   if (fi(1) /= 0_c_int) scroll_w = f(8)
   avail = f(16) - 0.0_c_float
   avail = avail - scroll_w
   call ct_window_pos(wx, wy)
   call ct_set_next_window_pos(wx + (avail - ww - f(12)), wy + f(13) * 2.0_c_float)
   call ct_set_next_window_size(ww, wh)
   call ct_set_next_window_bg_alpha(0.75_c_float)
   unused = ct_begin_child('find-replace', ww, wh, ImGuiChildFlags_Borders, 0_c_int)
   call ct_set_next_item_width(field)
   if (e%focus_on_find) then
      call ct_set_keyboard_focus_here()
      e%focus_on_find = .false.
   elseif (e%find_cancelled_ac) then
      call ct_set_keyboard_focus_here()
      e%find_cancelled_ac = .false.
   endif
   edited = ct_input_text('###find', e%find_text, ior(ImGuiInputTextFlags_AutoSelectAll, ImGuiInputTextFlags_NoUndoRedo))
   if (edited) then
      if (len(e%find_text) > 0) then
         call select_first_occurrence(e)
      else
         call cursors_clear_all(e%cursors)
      endif
   endif
   if (ct_item_deactivated()) then
      if (ct_key_pressed(ImGuiKey_Escape)) then
         call close_find_replace(e)
      elseif (ct_key_pressed(ImGuiKey_Enter) .or. ct_key_pressed(ImGuiKey_KeypadEnter)) then
         e%focus_on_editor = .true.
         e%focus_on_find = .false.
      endif
   endif
   disable = len(e%find_text) == 0
   if (disable) call ct_begin_disabled()
   call ct_same_line()
   if (ct_button('Find', b1, 0.0_c_float)) call find_action(e, 1_int32)
   call ct_same_line()
   if (ct_button('Find All', b2, 0.0_c_float)) call find_action(e, 3_int32)
   if (disable) call ct_end_disabled()
   call ct_same_line()
   if (latch_button('Aa', e%find_case, opt)) call find_action(e, 1_int32)
   call ct_same_line()
   if (latch_button('[]', e%find_whole, opt)) call find_action(e, 1_int32)
   call ct_same_line()
   if (ct_button('x', opt, 0.0_c_float)) call close_find_replace(e)
   if (.not. e%read_only) then
      call ct_set_next_item_width(field)
      edited = ct_input_text('###replace', e%replace_text, ImGuiInputTextFlags_NoUndoRedo)
      call ct_same_line()
      if (len(e%find_text) == 0 .or. len(e%replace_text) == 0) then
         call ct_begin_disabled()
         if (ct_button('Replace', b1, 0.0_c_float)) call find_action(e, 4_int32)
         call ct_same_line()
         if (ct_button('Replace All', b2, 0.0_c_float)) call find_action(e, 5_int32)
         call ct_end_disabled()
      else
         if (ct_button('Replace', b1, 0.0_c_float)) call find_action(e, 4_int32)
         call ct_same_line()
         if (ct_button('Replace All', b2, 0.0_c_float)) call find_action(e, 5_int32)
      endif
   endif
   if (ct_window_focused() .and. .not. disable) then
      if (ct_key_chord_pressed(ior(ImGuiMod_Ctrl, ImGuiKey_G))) then
         call ct_clear_window_focus()
         call find_action(e, 1_int32)
      endif
   endif
   call ct_end_child()
   call ct_pop_style_var(1_c_int)
   call ct_set_cursor_screen_pos(sx, sy)
   endsubroutine render_find_replace

   subroutine select_first_occurrence(e)
   !< `selectFirstOccurrenceOf(findText, ...)`.
   type(code_editor), intent(inout) :: e    !< Editor.
   type(code_pos)                   :: a, b !< Occurrence.
   logical                          :: found !< Found.

   call doc_find_text(e%doc, pos(0_int32, 0_int32), e%find_text, e%find_case, e%find_whole, found, a, b)
   if (found) then
      call cursors_set(e%cursors, a, b)
      call make_cursor_visible(e)
   else
      call cursors_clear_additional(e%cursors, .true.)
   endif
   endsubroutine select_first_occurrence
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
   character(len=256)                  :: idb     !< The id, copied (no allocated `str` per frame).
   integer(int32)                      :: k       !< Counter.
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
   if (id_len <= len(idb)) then
      do k = 1_int32, int(id_len, int32)
         idb(k:k) = id(k)
      enddo
      call render(e, idb(1:id_len), real(width, c_float), real(height, c_float), ch)
   else
      call render(e, str(id, int(id_len, int64)), real(width, c_float), real(height, c_float), ch)
   endif
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
