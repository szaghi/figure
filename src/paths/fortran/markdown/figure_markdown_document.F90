!< figure_markdown_document, the Fortran path's Markdown documents: imgui_rich_md's, a text in a scroll area of its own.
module figure_markdown_document
!< figure_markdown_document, the Fortran path's Markdown documents: imgui_rich_md's, a text in a scroll area of its own.
!<
!< szaghi/figure#15 P15. imgui_rich_md's documents (`BeginDocument`, `EndDocument` and their helpers in rich_md.cpp), as
!< FIGURE uses them (`markdown_view_object`, native/figure_markdown.cpp's views): a document is two child windows, the
!< content (where the renders put their headings, the anchors clicked in them and the matches of the search) and the
!< table of contents beside it (from three headings; a line above the content when the document is narrow or the
!< reader hid the panel). `md_document_begin` decides the layout from the state the document kept at the last frame
!< (the number of its headings, the panel's width, whether the reader hid it), hands the query to the renders and opens
!< the content; `md_document_end` works in the content's window (the current match among this frame's, one frame of
!< the scroll in progress, scroll anchoring), closes it, draws the table of contents from this frame's headings and
!< the find bar over the content. A scroll (to an anchor, an entry of the table of contents, a match) measures its
!< target again at each frame: eased over 0.3 s, then corrected until it holds. The search: ctrl+f (or `/`) opens the
!< find bar; enter, shift+enter and the arrows step through the matches, escape closes it; the matches are listed
!< under the bar and in the Search tab, counted per section in the table of contents, ticked on the scrollbar.
!<
!< The views (`md_view_*`): FIGURE's `markdown_view_object` on the Fortran path, a text kept by handle and drawn as a
!< document, with a search and a scroll to a heading asked by the program (its anchor is not reported as a link).
!< Drawn through figure_core (figure_core_layout) with imgui_rich_md's calls in its order.
use, intrinsic :: iso_c_binding, only : c_char, c_double, c_float, c_int, c_null_char, c_ptr
use, intrinsic :: iso_fortran_env, only : int32
use figure_cimgui_enums, only : ImGuiChildFlags_AlwaysUseWindowPadding, ImGuiChildFlags_AutoResizeY,                  &
                                ImGuiChildFlags_Borders, ImGuiCol_ChildBg, ImGuiCol_MenuBarBg, ImGuiCol_SeparatorActive, &
                                ImGuiCol_SeparatorHovered, ImGuiCol_Text, ImGuiCol_TextDisabled,                     &
                                ImGuiComboFlags_HeightLarge, ImGuiCond_Always, ImGuiCond_Appearing, ImGuiDir_Down,    &
                                ImGuiDir_Left, ImGuiDir_Right, ImGuiDir_Up, ImGuiFocusedFlags_ChildWindows,          &
                                ImGuiHoveredFlags_AllowWhenBlockedByActiveItem, ImGuiHoveredFlags_ChildWindows,      &
                                ImGuiKey_Enter, ImGuiKey_Escape, ImGuiKey_F, ImGuiKey_KeypadEnter, ImGuiMod_Ctrl,    &
                                ImGuiMouseButton_Left, ImGuiMouseCursor_ResizeEW
use figure_core_layout, only : cl_separator, cl_set_cursor_screen_pos, &
                               cl_align_text_to_frame_padding, cl_arrow_button, cl_begin_child, cl_begin_combo,      &
                               cl_begin_popup, cl_begin_tab_bar, cl_begin_tab_item, cl_begin_tooltip, cl_button,    &
                               cl_checkbox, cl_close_current_popup, cl_color_u32, cl_color_u32_rgba, cl_content_avail, &
                               cl_cursor_pos, cl_cursor_screen_pos, cl_draw_circle, cl_draw_line, cl_draw_rect_filled, &
                               cl_draw_text, cl_dummy, cl_end_child, cl_end_combo, cl_end_popup, cl_end_tab_bar,     &
                               cl_end_tab_item, cl_end_tooltip, cl_find_field, cl_font_size, cl_frame_height,         &
                               cl_frame_height_with_spacing, cl_get_id, cl_indent, cl_invisible_button, cl_io_state,  &
                               cl_item_active, cl_item_deactivated, cl_item_hovered, cl_item_rect_max,               &
                               cl_item_rect_min, cl_item_rect_size, cl_item_visible, cl_key_pressed,                 &
                               cl_mouse_drag_past, cl_mouse_hovering_rect, cl_mouse_pos, cl_mouse_released,          &
                               cl_new_line, cl_open_popup, cl_pop_clip_rect, cl_pop_font, cl_pop_id, cl_pop_style_color, &
                               cl_push_clip_rect, cl_push_font, cl_push_id_int, cl_push_style_color, cl_same_line,   &
                               cl_scroll_y, cl_scrollbar_rect, cl_selectable, cl_set_cursor_pos, cl_set_cursor_pos_x, &
                               cl_set_keyboard_focus_here, cl_set_mouse_cursor, cl_set_next_item_width,              &
                               cl_set_next_window_focus, cl_set_next_window_pos, cl_set_scroll_here_y,                &
                               cl_set_scroll_y, cl_shortcut, cl_storage_set_int, cl_style, cl_style_color, cl_text_str, &
                               cl_text_width_str, cl_text_line_height, cl_time, cl_window_appearing,                 &
                               cl_window_focused, cl_window_height, cl_window_hovered, cl_window_state
use figure_markdown_render, only : doc_blk_frag, doc_blk_index, doc_blk_y, doc_clicked_anchor, doc_content_start_y,    &
                                   doc_heads, doc_matches, doc_nblocks, doc_on, doc_query, md_admonition_color,         &
                                   md_correct_scroll, md_doc_reset, md_find_anchor_heading, md_heading_slug,           &
                                   md_heading_slug_of, md_heading_text, md_link_clicked, md_match_text, md_open_link,  &
                                   md_ready, md_regular_font, md_render_raw, md_scroll_to_show_at_top, md_swallow,     &
                                   SEARCH_MATCH, SEARCH_MATCH_CURRENT

implicit none
private
public :: md_document_begin, md_document_end
public :: md_view_create, md_view_destroy, md_view_set_text, md_view_text, md_view_find, md_view_scroll_to, &
          md_view_info, md_view_draw, md_view_exists, md_view_load_text

real(c_float),  parameter :: PANEL_MIN_EM = 8.0_c_float    !< The narrowest table of contents [em].
real(c_float),  parameter :: CONTENT_MIN_EM = 16.0_c_float !< The narrowest content beside it [em].
real(c_float),  parameter :: SCROLL_SECONDS = 0.3_c_float  !< An animated scroll's duration [s].
integer(c_int), parameter :: TOC_MIN_HEADINGS = 3_c_int    !< With fewer headings, no table of contents.
integer(c_int), parameter :: TOC_MAX_LEVEL = 3_c_int       !< The deepest level listed.
real(c_float),  parameter :: NARROW_WIDTH = 40.0_c_float   !< Narrower than this [em]: the line, not the panel.
integer(c_int), parameter :: LISTED_MATCHES_MAX = 300_c_int !< The matches listed at most.
integer(c_int), parameter :: QUERY_SIZE = 256_c_int        !< The query's room [bytes], its NUL included.
integer(c_int), parameter :: ICON_CLOSE = 1_c_int, ICON_FIND = 2_c_int, ICON_LIST = 3_c_int !< The buttons' icons.
integer(c_int), parameter :: WRAP_NONE = 0_c_int, WRAP_END = 1_c_int, WRAP_TOP = 2_c_int    !< The find bar's message.

type :: doc_state
   !< The state of a document between frames (imgui_rich_md's DocumentState), by its ID.
   integer(c_int)  :: id = 0_c_int                          !< The document's ID.
   ! the scroll it is making (DocumentScroll): to a heading (its slug), else to a match
   character(len=:), allocatable :: scroll_slug             !< The heading ('': none).
   integer(c_int)  :: scroll_anchor_frames = 8_c_int        !< The anchor's frames (a collapsed section opening).
   integer(c_int)  :: scroll_match_fragment = -1_c_int      !< The match: its fragment (-1: none), its first byte.
   integer(c_int)  :: scroll_match_begin = 0_c_int
   integer(c_int)  :: scroll_frames = 0_c_int               !< The frames left for the correction.
   real(c_float)   :: scroll_from = 0.0_c_float             !< The animation: its start.
   real(c_double)  :: scroll_start = -1.0_c_double
   logical         :: scroll_animated = .false.
   real(c_float)   :: panel_width = 16.0_c_float            !< The table of contents' width [em].
   logical         :: panel_shown = .true.
   integer(c_int)  :: heading_count = 0_c_int               !< At the last frame.
   integer(c_int)  :: current_section = -1_c_int
   logical         :: search_open = .false., focus_query = .false., select_query = .false., focus_content = .false.
   character(kind=c_char) :: query(QUERY_SIZE) = c_null_char !< The query, NUL-terminated (the find field's buffer).
   logical         :: match_case = .false., whole_words = .false., highlight_all = .true.
   integer(c_int)  :: current_fragment = -1_c_int, current_begin = 0_c_int
   integer(c_int)  :: step = 0_c_int
   logical         :: jump_to_first = .false.
   integer(c_int)  :: match_count = 0_c_int, current_match = -1_c_int !< At the last frame (current from 0).
   logical         :: match_moved = .false., dropdown_open = .false.
   integer(c_int), allocatable :: tick_matches(:)           !< The matches of the ticks clicked (from 0).
   integer(c_int)  :: ntick = 0_c_int
   real(c_float)   :: tick_popup_pos(2) = 0.0_c_float
   integer(c_int)  :: wrap_message = WRAP_NONE
   real(c_float)   :: find_bar_height = 0.0_c_float
   integer(c_int)  :: select_fragment = -1_c_int, select_begin = 0_c_int, select_end = 0_c_int
   real(c_float)   :: find_bar_bottom = 0.0_c_float
   integer(c_int)  :: kept_fragment = 0_c_int, kept_index = -1_c_int !< The block kept in place.
   real(c_float)   :: kept_y = 0.0_c_float, kept_scroll = 0.0_c_float
endtype doc_state

type :: md_view
   !< A view (FIGURE's `markdown_view_object` on the Fortran path): its text, options, the search and scroll asked.
   logical                       :: used = .false.     !< In use.
   character(len=:), allocatable :: text               !< Markdown.
   logical                       :: toc = .true.       !< A table of contents.
   logical                       :: search = .true.    !< A search.
   logical                       :: find_due = .false. !< A search asked.
   character(len=:), allocatable :: query              !< ... its text.
   logical                       :: scroll_due = .false. !< A scroll asked.
   character(len=:), allocatable :: slug               !< ... its heading's slug.
   integer(c_int)                :: matches = 0_c_int  !< At the last draw.
   integer(c_int)                :: current = -1_c_int !< At the last draw (from 0; -1: none).
endtype md_view

type(doc_state), allocatable, target :: states(:) !< The documents' states.
integer(c_int) :: nstates = 0_c_int
type(md_view), allocatable :: views(:)            !< The views, by handle (from 1).
! the document being drawn (DocumentFrame)
integer(c_int) :: fr_state = 0_c_int              !< Its state's index.
logical        :: fr_toc = .true., fr_search = .true. !< Its options.
real(c_float)  :: fr_origin(2) = 0.0_c_float      !< Its top left, in its window.
real(c_float)  :: fr_size(2) = 0.0_c_float        !< Its size.
logical        :: fr_panel = .false., fr_line = .false., fr_narrow = .false.
real(c_float)  :: fr_panel_width = 0.0_c_float, fr_splitter_width = 0.0_c_float
real(c_float)  :: fr_scroll_y = 0.0_c_float       !< The content's scroll.
! what md_document_end gathers for the table of contents and the lists (_DocumentView)
integer(c_int), allocatable :: listed(:)          !< The headings listed (from 1).
integer(c_int) :: nlisted = 0_c_int
integer(c_int) :: view_current = 0_c_int          !< The current section's heading (0: none).
integer(c_int), allocatable :: sections(:)        !< Per match: the listed heading above it (0: none).
integer(c_int), allocatable :: counts(:)          !< Per heading: its matches.

contains
   ! ---- the views (FIGURE's markdown_view_object) --------------------------------------------------------------------
   subroutine md_view_create(toc, search, handle)
   !< A view, empty: its handle.
   logical,        intent(in)  :: toc, search !< Options.
   integer(c_int), intent(out) :: handle      !< Handle (from 1).
   type(md_view), allocatable  :: more(:)     !< Grown list.
   integer(c_int)              :: k           !< Counter.

   if (.not. allocated(views)) allocate(views(4))
   do handle = 1_c_int, size(views, kind=c_int)
      if (.not. views(handle)%used) exit
   enddo
   if (handle > size(views, kind=c_int)) then
      allocate(more(2 * size(views)))
      do k = 1_c_int, size(views, kind=c_int)
         more(k)%used = views(k)%used
         if (allocated(views(k)%text)) more(k)%text = views(k)%text
         more(k)%toc = views(k)%toc
         more(k)%search = views(k)%search
         more(k)%find_due = views(k)%find_due
         if (allocated(views(k)%query)) more(k)%query = views(k)%query
         more(k)%scroll_due = views(k)%scroll_due
         if (allocated(views(k)%slug)) more(k)%slug = views(k)%slug
         more(k)%matches = views(k)%matches
         more(k)%current = views(k)%current
      enddo
      call move_alloc(more, views)
   endif
   views(handle)%used = .true.
   views(handle)%text = ''
   views(handle)%toc = toc
   views(handle)%search = search
   views(handle)%find_due = .false.
   views(handle)%query = ''
   views(handle)%scroll_due = .false.
   views(handle)%slug = ''
   views(handle)%matches = 0_c_int
   views(handle)%current = -1_c_int
   endsubroutine md_view_create

   function md_view_exists(handle) result(yes)
   !< Whether a handle is a view's.
   integer(c_int), intent(in) :: handle !< Handle.
   logical                    :: yes    !< A view.

   yes = .false.
   if (.not. allocated(views)) return
   if (handle < 1_c_int .or. handle > size(views, kind=c_int)) return
   yes = views(handle)%used
   endfunction md_view_exists

   subroutine md_view_destroy(handle)
   !< A view released.
   integer(c_int), intent(in) :: handle !< Handle.

   if (.not. md_view_exists(handle)) return
   views(handle)%used = .false.
   views(handle)%text = ''
   endsubroutine md_view_destroy

   subroutine md_view_set_text(handle, text)
   !< A view's text replaced.
   integer(c_int),   intent(in) :: handle !< Handle.
   character(len=*), intent(in) :: text   !< Markdown.

   views(handle)%text = text
   endsubroutine md_view_set_text

   subroutine md_view_load_text(handle, text)
   !< A view's text replaced by a file's (read by the caller).
   integer(c_int),   intent(in) :: handle !< Handle.
   character(len=*), intent(in) :: text   !< Markdown.

   views(handle)%text = text
   endsubroutine md_view_load_text

   function md_view_text(handle) result(text)
   !< A view's text.
   integer(c_int), intent(in)    :: handle !< Handle.
   character(len=:), allocatable :: text   !< Markdown.

   text = views(handle)%text
   endfunction md_view_text

   subroutine md_view_find(handle, query)
   !< A search asked, from the next draw ('': it ends).
   integer(c_int),   intent(in) :: handle !< Handle.
   character(len=*), intent(in) :: query  !< Text searched (checked by the caller: one line, below 256 bytes).

   views(handle)%query = query
   views(handle)%find_due = .true.
   endsubroutine md_view_find

   subroutine md_view_scroll_to(handle, heading)
   !< A scroll to a heading asked, from the next draw: its text, or `#` and its anchor.
   integer(c_int),   intent(in) :: handle  !< Handle.
   character(len=*), intent(in) :: heading !< Heading (not empty).

   if (heading(1:1) == '#') then
      views(handle)%slug = heading(2:)
   else ! a heading's text: its slug, as the renderer makes it (GitHub's)
      views(handle)%slug = md_heading_slug_of(heading)
   endif
   views(handle)%scroll_due = .true.
   endsubroutine md_view_scroll_to

   subroutine md_view_info(handle, matches, current)
   !< The matches of the search at the last draw and the current one (from 0; -1: none).
   integer(c_int), intent(in)  :: handle           !< Handle.
   integer(c_int), intent(out) :: matches, current !< Matches, current.

   matches = views(handle)%matches
   current = views(handle)%current
   endsubroutine md_view_info

   function md_view_draw(handle, id, width, height, clicked) result(status)
   !< A view drawn (native/figure_markdown.cpp's `fig_markdown_view_draw`): the search and the scroll asked applied to
   !< its document's state, then `BeginDocument`, its text, `EndDocument`. A FIG_* status (0: done).
   integer(c_int),   intent(in)  :: handle  !< Handle.
   character(len=*), intent(in)  :: id      !< Widget ID (not empty).
   real(c_float),    intent(in)  :: width   !< Width (0: the available width).
   real(c_float),    intent(in)  :: height  !< Height (0: the available height).
   logical,          intent(out) :: clicked !< A link was clicked.
   integer(c_int)                :: status  !< Status.
   integer(c_int)                :: s, k    !< A state, counter.

   clicked = .false.
   status = md_ready()
   if (status /= 0_c_int) return
   s = state_of(cl_get_id(id))
   associate(v => views(handle), st => states(s))
      if (v%find_due) then
         st%query = c_null_char
         do k = 1_c_int, min(len(v%query, c_int), QUERY_SIZE - 1_c_int)
            st%query(k) = v%query(k:k)
         enddo
         st%search_open = len(v%query) > 0
         st%focus_query = .false.
         st%select_query = .false.
         st%jump_to_first = .true.
         st%current_fragment = -1_c_int
         v%find_due = .false.
      endif
      if (v%scroll_due) then
         call scroll_reset(st)
         st%scroll_slug = v%slug
         st%scroll_frames = 8_c_int
         md_swallow = v%slug
         v%scroll_due = .false.
      endif
   endassociate
   if (md_link_clicked(.true.)) continue
   call md_document_begin(id, width, height, views(handle)%toc, views(handle)%search)
   call md_render_raw(views(handle)%text)
   call md_document_end()
   s = state_of(cl_get_id(id))
   if (.not. allocated(md_swallow)) md_swallow = ''
   if (len(states(s)%scroll_slug) == 0) md_swallow = '' ! reached, or no heading has it
   views(handle)%matches = merge(states(s)%match_count, 0_c_int, states(s)%search_open)
   views(handle)%current = merge(states(s)%current_match, -1_c_int, states(s)%search_open)
   clicked = md_link_clicked(.true.)
   endfunction md_view_draw

   ! ---- the states --------------------------------------------------------------------------------------------------
   function state_of(id) result(k)
   !< The state of a document (made at its first use).
   integer(c_int), intent(in)  :: id   !< Its ID.
   integer(c_int)              :: k    !< Its index.
   type(doc_state), allocatable :: more(:) !< Grown list.
   integer(c_int)              :: j    !< Counter.

   do k = 1_c_int, nstates
      if (states(k)%id == id) return
   enddo
   if (.not. allocated(states)) allocate(states(4))
   if (nstates == size(states, kind=c_int)) then
      allocate(more(2 * nstates))
      do j = 1_c_int, nstates
         call state_copy(states(j), more(j))
      enddo
      call move_alloc(more, states)
   endif
   nstates = nstates + 1_c_int
   k = nstates
   states(k)%id = id
   states(k)%scroll_slug = ''
   allocate(states(k)%tick_matches(8))
   endfunction state_of

   subroutine state_copy(a, b)
   !< A state copied, component by component.
   type(doc_state), intent(in)    :: a !< Source.
   type(doc_state), intent(inout) :: b !< Copy.

   b%id = a%id
   b%scroll_slug = a%scroll_slug
   b%scroll_anchor_frames = a%scroll_anchor_frames
   b%scroll_match_fragment = a%scroll_match_fragment
   b%scroll_match_begin = a%scroll_match_begin
   b%scroll_frames = a%scroll_frames
   b%scroll_from = a%scroll_from
   b%scroll_start = a%scroll_start
   b%scroll_animated = a%scroll_animated
   b%panel_width = a%panel_width
   b%panel_shown = a%panel_shown
   b%heading_count = a%heading_count
   b%current_section = a%current_section
   b%search_open = a%search_open
   b%focus_query = a%focus_query
   b%select_query = a%select_query
   b%focus_content = a%focus_content
   b%query = a%query
   b%match_case = a%match_case
   b%whole_words = a%whole_words
   b%highlight_all = a%highlight_all
   b%current_fragment = a%current_fragment
   b%current_begin = a%current_begin
   b%step = a%step
   b%jump_to_first = a%jump_to_first
   b%match_count = a%match_count
   b%current_match = a%current_match
   b%match_moved = a%match_moved
   b%dropdown_open = a%dropdown_open
   b%tick_matches = a%tick_matches
   b%ntick = a%ntick
   b%tick_popup_pos = a%tick_popup_pos
   b%wrap_message = a%wrap_message
   b%find_bar_height = a%find_bar_height
   b%select_fragment = a%select_fragment
   b%select_begin = a%select_begin
   b%select_end = a%select_end
   b%find_bar_bottom = a%find_bar_bottom
   b%kept_fragment = a%kept_fragment
   b%kept_index = a%kept_index
   b%kept_y = a%kept_y
   b%kept_scroll = a%kept_scroll
   endsubroutine state_copy

   subroutine scroll_reset(st)
   !< No scroll in progress (`DocumentScroll()`).
   type(doc_state), intent(inout) :: st !< State.

   st%scroll_slug = ''
   st%scroll_anchor_frames = 8_c_int
   st%scroll_match_fragment = -1_c_int
   st%scroll_match_begin = 0_c_int
   st%scroll_frames = 0_c_int
   st%scroll_from = 0.0_c_float
   st%scroll_start = -1.0_c_double
   st%scroll_animated = .false.
   endsubroutine scroll_reset

   function query_text(st) result(q)
   !< A state's query, as a string.
   type(doc_state), intent(in)   :: st !< State.
   character(len=:), allocatable :: q  !< Query.
   integer(c_int)                :: n, k !< Bytes, counter.

   n = 0_c_int
   do while (n < QUERY_SIZE)
      if (st%query(n + 1_c_int) == c_null_char) exit
      n = n + 1_c_int
   enddo
   allocate(character(len=n) :: q)
   do k = 1_c_int, n
      q(k:k) = st%query(k)
   enddo
   endfunction query_text

   function em_now() result(em)
   !< `GetFontSize()`.
   real(c_float) :: em !< Size.

   em = cl_font_size()
   endfunction em_now

   subroutine push_regular_font()
   !< The Markdown's regular font pushed.
   type(c_ptr)   :: font !< Font.
   real(c_float) :: size !< Size.

   call md_regular_font(font, size)
   call cl_push_font(font, size)
   endsubroutine push_regular_font

   function style_value(k) result(v)
   !< A value of the style (figure_core_layout's `cl_style`).
   integer(c_int), intent(in) :: k !< Its index.
   real(c_float)              :: v !< Value.
   real(c_float)              :: s(12) !< Values.

   call cl_style(s)
   v = s(k)
   endfunction style_value

   ! ---- begin and end -----------------------------------------------------------------------------------------------
   subroutine md_document_begin(id, width, height, toc, search)
   !< `BeginDocument(id, ImVec2(width, height), options)`: the layout from the state of the last frame, the content
   !< opened, its renders given the search.
   character(len=*), intent(in) :: id            !< ID.
   real(c_float),    intent(in) :: width, height !< Size (0: the available room).
   logical,          intent(in) :: toc, search   !< Options.
   real(c_float)                :: em, max_em, left, content(4), line_height, room, x, y !< Layout.
   logical                      :: has_toc       !< A table of contents.
   logical                      :: mac, want_text, touch, shift, slash !< Input.
   real(c_float)                :: cpx, cpy, wheel, dx !< Input.
   integer(c_int)               :: chars !< Input.
   type(c_ptr)                  :: font  !< Font.
   real(c_float)                :: size  !< Size.

   fr_state = state_of(cl_get_id(id))
   fr_toc = toc
   fr_search = search
   associate(st => states(fr_state))
      if (cl_begin_child(id, width, height, 0_c_int, 0_c_int)) continue
      call cl_cursor_pos(fr_origin(1), fr_origin(2))
      call cl_content_avail(fr_size(1), fr_size(2))
      em = cl_font_size()
      has_toc = toc .and. st%heading_count >= TOC_MIN_HEADINGS
      fr_narrow = fr_size(1) < NARROW_WIDTH * em
      fr_panel = has_toc .and. st%panel_shown .and. .not. fr_narrow
      fr_line = has_toc .and. .not. fr_panel
      if (st%focus_content) then
         call cl_set_next_window_focus()
         st%focus_content = .false.
      endif
      content = [fr_origin, fr_size]
      fr_panel_width = 0.0_c_float
      fr_splitter_width = 0.0_c_float
      if (fr_panel) then
         max_em = max(PANEL_MIN_EM, fr_size(1) / em - CONTENT_MIN_EM)
         st%panel_width = min(max(st%panel_width, PANEL_MIN_EM), max_em)
         fr_panel_width = st%panel_width * em
         call cl_io_state(cpx, cpy, wheel, dx, mac, want_text, touch, shift, chars, slash)
         fr_splitter_width = em * merge(1.0_c_float, 0.5_c_float, touch)
         left = fr_panel_width + fr_splitter_width
         content(1) = content(1) + left
         content(3) = content(3) - left
      elseif (fr_line) then
         call md_regular_font(font, size)
         call cl_push_font(font, size)
         line_height = cl_frame_height_with_spacing()
         call cl_pop_font()
         content(2) = content(2) + line_height
         content(4) = content(4) - line_height
      endif
      if (fr_narrow .and. search .and. st%search_open) then
         room = st%find_bar_height + style_value(5_c_int)
         content(2) = content(2) + room
         content(4) = content(4) - room
      endif
      call cl_set_cursor_pos(content(1), content(2))
      if (cl_begin_child('##content', content(3), content(4), ImGuiChildFlags_AlwaysUseWindowPadding, 0_c_int)) continue
      fr_scroll_y = cl_scroll_y()
      call cl_cursor_pos(x, y)
      if (search .and. st%search_open) then
         call md_doc_reset(query_text(st), st%match_case, st%whole_words, st%highlight_all, st%current_fragment, &
                           st%current_begin, st%select_fragment, st%select_begin, st%select_end)
      else
         call md_doc_reset('', .false., .false., .true., -1_c_int, 0_c_int, st%select_fragment, st%select_begin, &
                           st%select_end)
      endif
      doc_content_start_y = y
      st%select_fragment = -1_c_int
   endassociate
   endsubroutine md_document_begin

   subroutine md_document_end()
   !< `EndDocument`: in the content's window the anchor clicked, the current match, the scroll in progress, the place
   !< kept; then the content closed, the table of contents and the find bar drawn.
   real(c_float)  :: top, cmin(2), cmax(2), mx, my, wheel, dx, cpx, cpy !< Layout.
   integer(c_int) :: k, nxt, section, chars !< Counters.
   logical        :: mac, want_text, touch, shift, slash !< Input.

   associate(st => states(fr_state))
      if (len(doc_clicked_anchor) > 0) call scroll_to_heading(st, doc_clicked_anchor)
      call update_current_match(st)
      call update_scroll(st)
      call keep_place(st)
      ! the entries of the table of contents, and the current section
      if (.not. allocated(listed)) allocate(listed(16))
      if (size(listed) < doc_heads%n) then
         deallocate(listed)
         allocate(listed(2 * doc_heads%n))
      endif
      nlisted = 0_c_int
      view_current = 0_c_int
      do k = 1_c_int, doc_heads%n
         if (doc_heads%level(k) > TOC_MAX_LEVEL) cycle
         nlisted = nlisted + 1_c_int
         listed(nlisted) = k
         top = max(fr_scroll_y, doc_content_start_y) + cl_font_size() * 0.5_c_float
         if (.not. doc_heads%hidden(k) .and. doc_heads%y(k) <= top) view_current = k
      enddo
      ! the section of each match
      if (allocated(counts)) deallocate(counts)
      allocate(counts(max(doc_heads%n, 1_c_int)))
      counts = 0_c_int
      if (allocated(sections)) deallocate(sections)
      allocate(sections(max(doc_matches%n, 1_c_int)))
      nxt = 1_c_int
      section = 0_c_int
      do k = 1_c_int, doc_matches%n
         do while (nxt <= nlisted)
            if (.not. (doc_heads%y(listed(nxt)) <= doc_matches%y(k) + 1.0_c_float)) exit
            section = listed(nxt)
            nxt = nxt + 1_c_int
         enddo
         sections(k) = section
         if (section > 0_c_int) counts(section) = counts(section) + 1_c_int
      enddo
      if (fr_search) call draw_scrollbar_ticks(st)
      call cl_end_child() ! the content
      call cl_item_rect_min(cmin(1), cmin(2))
      call cl_item_rect_max(cmax(1), cmax(2))
      st%heading_count = nlisted
      if (fr_panel) then
         call draw_toc_panel(st)
      elseif (fr_line) then
         call draw_toc_line(st)
      endif
      st%current_section = view_current
      if (fr_search) then
         if (cl_shortcut(ior(ImGuiMod_Ctrl, ImGuiKey_F))) call open_search(st)
         call cl_io_state(cpx, cpy, wheel, dx, mac, want_text, touch, shift, chars, slash)
         if (.not. want_text .and. cl_window_focused(ImGuiFocusedFlags_ChildWindows) .and. slash) call open_search(st)
         if (st%search_open) then
            if (cl_shortcut(ImGuiKey_Escape)) call close_search(st)
         endif
         if (st%search_open) then
            call draw_find_bar(st, cmin, cmax)
         else
            st%find_bar_bottom = 0.0_c_float
         endif
      endif
      call cl_mouse_pos(mx, my)
   endassociate
   doc_on = .false.
   call cl_end_child() ! the document
   endsubroutine md_document_end

   ! ---- scrolls -----------------------------------------------------------------------------------------------------
   subroutine scroll_to_heading(st, slug)
   !< A scroll to a heading (`_ScrollToHeading`).
   type(doc_state),  intent(inout) :: st   !< State.
   character(len=*), intent(in)    :: slug !< Its slug.

   call scroll_reset(st)
   st%scroll_slug = slug
   st%scroll_frames = 8_c_int
   endsubroutine scroll_to_heading

   subroutine scroll_to_match(st, fragment, begin)
   !< A scroll to a match (`_ScrollToMatch`).
   type(doc_state), intent(inout) :: st              !< State.
   integer(c_int),  intent(in)    :: fragment, begin !< The match.

   call scroll_reset(st)
   st%scroll_match_fragment = fragment
   st%scroll_match_begin = begin
   st%scroll_frames = 8_c_int
   endsubroutine scroll_to_match

   function scroll_toward(st, scroll) result(over)
   !< One frame of a scroll toward `scroll`, in the content's window (`_ScrollToward`): eased over the animation, then
   !< corrected until it holds; the wheel stops it.
   type(doc_state), intent(inout) :: st     !< State.
   real(c_float),   intent(in)    :: scroll !< Target.
   logical                        :: over   !< Over.
   real(c_float)                  :: t, eased, cpx, cpy, wheel, dx !< Animation, input.
   logical                        :: mac, want_text, touch, shift, slash !< Input.
   integer(c_int)                 :: chars !< Input.

   over = .true.
   call cl_io_state(cpx, cpy, wheel, dx, mac, want_text, touch, shift, chars, slash)
   if (wheel /= 0.0_c_float) then
      if (cl_window_hovered(ImGuiHoveredFlags_ChildWindows)) return ! the reader took over
   endif
   if (.not. st%scroll_animated) then
      if (st%scroll_start < 0.0_c_double .and. SCROLL_SECONDS > 0.0_c_float) then
         st%scroll_from = cl_scroll_y()
         st%scroll_start = cl_time()
      endif
      if (st%scroll_start < 0.0_c_double) then
         t = 1.0_c_float
      else
         t = real(cl_time() - st%scroll_start, c_float) / SCROLL_SECONDS
      endif
      if (t < 1.0_c_float) then
         eased = (1.0_c_float - t) * (1.0_c_float - t)
         eased = 1.0_c_float - eased * (1.0_c_float - t)
         call cl_set_scroll_y(st%scroll_from + (scroll - st%scroll_from) * eased)
         over = .false.
         return
      endif
      st%scroll_animated = .true.
   endif
   over = md_correct_scroll(scroll, st%scroll_frames)
   endfunction scroll_toward

   subroutine update_scroll(st)
   !< The scroll the document is making, its target measured again at each frame (`_UpdateScroll`).
   type(doc_state), intent(inout) :: st !< State.
   integer(c_int)                 :: i, m, k !< Heading, match, counter.
   real(c_float)                  :: height, em, top !< Layout.

   if (len(st%scroll_slug) > 0) then
      i = md_find_anchor_heading(doc_heads, st%scroll_slug, st%scroll_anchor_frames)
      if (i < 0_c_int) then ! an anchor that no heading of the document has
         call md_open_link('#'//st%scroll_slug)
         call scroll_reset(st)
      elseif (i > 0_c_int) then
         if (scroll_toward(st, md_scroll_to_show_at_top(doc_heads%y(i)))) call scroll_reset(st)
      endif
   elseif (st%scroll_match_fragment >= 0_c_int) then
      m = 0_c_int
      do k = 1_c_int, doc_matches%n
         if (doc_matches%frag(k) == st%scroll_match_fragment .and. doc_matches%b(k) == st%scroll_match_begin) m = k
      enddo
      if (m > 0_c_int) then
         if (doc_matches%details(m) /= 0_c_int) then
            st%scroll_frames = st%scroll_frames - 1_c_int
            if (st%scroll_frames > 0_c_int) then
               call cl_storage_set_int(doc_matches%details(m), 1_c_int) ! the section opens at the next frame
               return
            endif
         endif
      endif
      height = cl_window_height()
      em = cl_font_size()
      if (st%find_bar_bottom > 0.0_c_float) then
         top = min(st%find_bar_bottom + em, height - 3.0_c_float * em)
      else
         top = height / 3.0_c_float
      endif
      if (m == 0_c_int) then
         call scroll_reset(st)
      elseif (scroll_toward(st, md_scroll_to_show_at_top(doc_matches%y(m) - top))) then
         call scroll_reset(st)
      endif
   endif
   endsubroutine update_scroll

   subroutine keep_place(st)
   !< Scroll anchoring (`_KeepPlace`): the block kept at the last frame keeps its place on the screen when the content
   !< above it changed height, while the scroll is the one it was chosen at.
   type(doc_state), intent(inout) :: st !< State.
   real(c_float)                  :: scroll, view_top, s(14) !< Layout.
   logical                        :: scrolling !< A scroll in progress.
   integer(c_int)                 :: k         !< Block.

   scroll = fr_scroll_y
   scrolling = len(st%scroll_slug) > 0 .or. st%scroll_match_fragment >= 0_c_int
   if (st%kept_index >= 0_c_int .and. .not. scrolling .and. abs(scroll - st%kept_scroll) < 0.5_c_float) then
      do k = 1_c_int, doc_nblocks
         if (doc_blk_frag(k) == st%kept_fragment .and. doc_blk_index(k) == st%kept_index) then
            if (abs(doc_blk_y(k) - st%kept_y) >= 1.0_c_float) then
               scroll = scroll + doc_blk_y(k) - st%kept_y
               scroll = real(floor(max(scroll, 0.0_c_float) + 0.5_c_float), c_float)
               call cl_set_scroll_y(scroll) ! applied at the next frame
            endif
            exit
         endif
      enddo
   endif
   st%kept_fragment = 0_c_int
   st%kept_index = -1_c_int
   st%kept_y = 0.0_c_float
   st%kept_scroll = scroll
   if (scroll <= 0.0_c_float) return
   call cl_window_state(s)
   view_top = scroll + s(7)
   view_top = view_top + s(8)
   view_top = view_top + 1.0_c_float
   do k = 1_c_int, doc_nblocks
      if (doc_blk_y(k) <= view_top) then
         st%kept_fragment = doc_blk_frag(k)
         st%kept_index = doc_blk_index(k)
         st%kept_y = doc_blk_y(k)
      endif
   enddo
   endsubroutine keep_place

   subroutine update_current_match(st)
   !< The current match (`_UpdateCurrentMatch`): found again by its render and first byte; a new query makes the
   !< first match below the top of the view current; a step goes to the next or previous one, wrapping around.
   type(doc_state), intent(inout) :: st !< State.
   integer(c_int)                 :: current, k, n, nxt !< Matches.
   real(c_float)                  :: view_top, view_bottom !< The view.
   logical                        :: scroll !< Scroll to it.

   st%match_count = doc_matches%n
   if (len(doc_query) == 0 .or. doc_matches%n == 0_c_int) then
      st%current_match = -1_c_int
      st%match_moved = .false.
      st%wrap_message = WRAP_NONE
      st%step = 0_c_int
      st%jump_to_first = .false.
      return
   endif
   current = 0_c_int
   do k = 1_c_int, doc_matches%n
      if (doc_matches%frag(k) == st%current_fragment .and. doc_matches%b(k) == st%current_begin) current = k
   enddo
   view_top = fr_scroll_y + st%find_bar_bottom
   view_bottom = fr_scroll_y + cl_window_height()
   scroll = .false.
   if (current == 0_c_int .or. st%jump_to_first) then
      current = 1_c_int
      do k = 1_c_int, doc_matches%n
         if (doc_matches%y(k) >= view_top) then
            current = k
            exit
         endif
      enddo
      scroll = st%jump_to_first
      if (st%jump_to_first) st%wrap_message = WRAP_NONE
      st%jump_to_first = .false.
   endif
   if (st%step /= 0_c_int) then
      n = doc_matches%n
      nxt = (current - 1_c_int) + st%step
      st%wrap_message = WRAP_NONE
      if (nxt >= n) st%wrap_message = WRAP_END
      if (nxt < 0_c_int) st%wrap_message = WRAP_TOP
      current = modulo(nxt + n, n) + 1_c_int
      st%step = 0_c_int
      scroll = .true.
   endif
   st%match_moved = current - 1_c_int /= st%current_match
   st%current_match = current - 1_c_int
   st%current_fragment = doc_matches%frag(current)
   st%current_begin = doc_matches%b(current)
   if (scroll .and. (doc_matches%details(current) /= 0_c_int .or. doc_matches%y(current) < view_top .or. &
                     doc_matches%bottom(current) > view_bottom)) &
      call scroll_to_match(st, doc_matches%frag(current), doc_matches%b(current))
   endsubroutine update_current_match

   ! ---- the search's widgets ----------------------------------------------------------------------------------------
   function icon_button(id, icon) result(clicked)
   !< A square button with a drawn icon: a cross, a lens, three lines (`_IconButton`).
   character(len=*), intent(in) :: id      !< ID.
   integer(c_int),   intent(in) :: icon    !< Icon.
   logical                      :: clicked !< Clicked.
   real(c_float)                :: size, a(2), b(2), c(2), r, thickness, lens(2), y !< Geometry.
   integer(c_int)               :: col, k  !< Colour, counter.

   size = cl_frame_height()
   clicked = cl_button(id, size, size)
   call cl_item_rect_min(a(1), a(2))
   call cl_item_rect_max(b(1), b(2))
   c = [(a(1) + b(1)) * 0.5_c_float, (a(2) + b(2)) * 0.5_c_float]
   r = size * 0.22_c_float
   thickness = max(1.5_c_float, size / 20.0_c_float)
   col = cl_color_u32(ImGuiCol_Text)
   select case (icon)
   case (ICON_CLOSE)
      call cl_draw_line(c(1) - r, c(2) - r, c(1) + r, c(2) + r, col, thickness)
      call cl_draw_line(c(1) - r, c(2) + r, c(1) + r, c(2) - r, col, thickness)
   case (ICON_FIND)
      lens = [c(1) - r * 0.3_c_float, c(2) - r * 0.3_c_float]
      call cl_draw_circle(lens(1), lens(2), r * 0.75_c_float, col, .false., thickness)
      call cl_draw_line(lens(1) + r * 0.55_c_float, lens(2) + r * 0.55_c_float, c(1) + r * 1.1_c_float, &
                        c(2) + r * 1.1_c_float, col, thickness * 1.3_c_float)
   case default
      do k = -1_c_int, 1_c_int
         y = r * 0.8_c_float
         y = c(2) + real(k, c_float) * y
         call cl_draw_line(c(1) - r, y, c(1) + r, y, col, thickness)
      enddo
   endselect
   endfunction icon_button

   subroutine open_search(st)
   !< The find bar opened, its field focused and selected.
   type(doc_state), intent(inout) :: st !< State.

   st%search_open = .true.
   st%focus_query = .true.
   st%select_query = .true.
   endsubroutine open_search

   subroutine close_search(st)
   !< The find bar closed: its current match becomes the selection, the content takes the focus back.
   type(doc_state), intent(inout) :: st !< State.
   integer(c_int)                 :: m  !< The current match (from 1).

   st%search_open = .false.
   st%focus_content = .true.
   st%wrap_message = WRAP_NONE
   m = st%current_match + 1_c_int
   if (m >= 1_c_int .and. m <= doc_matches%n) then
      if (doc_matches%in_runs(m)) then
         st%select_fragment = doc_matches%frag(m)
         st%select_begin = doc_matches%b(m)
         st%select_end = doc_matches%e(m)
      endif
   endif
   endsubroutine close_search

   subroutine go_to_match(st, m)
   !< A match made current and scrolled to.
   type(doc_state), intent(inout) :: st !< State.
   integer(c_int),  intent(in)    :: m  !< Match (from 1).

   st%wrap_message = WRAP_NONE
   st%current_fragment = doc_matches%frag(m)
   st%current_begin = doc_matches%b(m)
   call scroll_to_match(st, doc_matches%frag(m), doc_matches%b(m))
   endsubroutine go_to_match

   function row_height() result(h)
   !< A row of the lists (a finger needs a taller one).
   real(c_float)  :: h !< Height.
   real(c_float)  :: cpx, cpy, wheel, dx !< Input.
   logical        :: mac, want_text, touch, shift, slash !< Input.
   integer(c_int) :: chars !< Input.

   call cl_io_state(cpx, cpy, wheel, dx, mac, want_text, touch, shift, chars, slash)
   h = cl_text_line_height() * merge(2.0_c_float, 1.0_c_float, touch)
   endfunction row_height

   function fit_left(text, width) result(r)
   !< The end of a text that fits in a width, cut at a space, `...` in front when cut ('' when no word fits).
   character(len=*), intent(in)  :: text  !< Text.
   real(c_float),    intent(in)  :: width !< Width.
   character(len=:), allocatable :: r     !< Fitted.
   character(len=:), allocatable :: s     !< The text without its leading spaces.
   integer                       :: start, space !< Offsets (1-based).

   start = verify(text, ' ')
   if (start == 0) then
      s = ''
   else
      s = text(start:)
   endif
   if (cl_text_width_str(s) <= width) then
      r = s
      return
   endif
   space = index(s, ' ')
   do while (space > 0)
      r = '...'//s(space + 1:)
      if (cl_text_width_str(r) <= width) return
      start = index(s(space + 1:), ' ')
      if (start == 0) exit
      space = space + start
   enddo
   r = ''
   endfunction fit_left

   function fit_right(text, width) result(r)
   !< The start of a text that fits in a width, cut at a space, `...` at the end when cut ('' when no word fits).
   character(len=*), intent(in)  :: text  !< Text.
   real(c_float),    intent(in)  :: width !< Width.
   character(len=:), allocatable :: r     !< Fitted.
   integer                       :: space !< Offset (1-based).

   if (cl_text_width_str(text) <= width) then
      r = text
      return
   endif
   space = index(text, ' ', back=.true.)
   do while (space > 1)
      r = text(1:space - 1)//'...'
      if (cl_text_width_str(r) <= width) return
      space = index(text(1:space - 1), ' ', back=.true.)
   enddo
   r = ''
   endfunction fit_right

   subroutine draw_snippet(m, x, y, width)
   !< A match with its context on one line, the context cut to fit, the match highlighted (`_DrawSnippet`).
   integer(c_int), intent(in)    :: m        !< Match (from 1).
   real(c_float),  intent(in)    :: x, y     !< Where.
   real(c_float),  intent(in)    :: width    !< Room.
   character(len=:), allocatable :: before, after, text !< The parts.
   real(c_float)                 :: match_width, room, px !< Layout.
   integer(c_int)                :: col      !< Colour.

   text = md_match_text(doc_matches, m, 2_c_int)
   match_width = cl_text_width_str(text)
   room = max(0.0_c_float, width - match_width)
   before = fit_left(md_match_text(doc_matches, m, 1_c_int), room * 0.4_c_float)
   after = fit_right(md_match_text(doc_matches, m, 3_c_int), room - cl_text_width_str(before))
   col = cl_color_u32(ImGuiCol_Text)
   call cl_draw_text(x, y, col, before)
   px = x + cl_text_width_str(before)
   call cl_draw_rect_filled(px, y, px + match_width, y + cl_text_line_height(), cl_color_u32_rgba(SEARCH_MATCH), 0.0_c_float)
   call cl_draw_text(px, y, col, text)
   call cl_draw_text(px + match_width, y, col, after)
   endsubroutine draw_snippet

   function section_title(m) result(t)
   !< The title of a match's section ('(top)': none).
   integer(c_int), intent(in)    :: m !< Match (from 1).
   character(len=:), allocatable :: t !< Title.

   if (sections(m) > 0_c_int) then
      t = md_heading_text(doc_heads, sections(m))
   else
      t = '(top)'
   endif
   endfunction section_title

   function match_row(st, m, width) result(clicked)
   !< A row of a list of matches (width 0: the available width): true when clicked.
   type(doc_state), intent(inout) :: st      !< State.
   integer(c_int),  intent(in)    :: m       !< Match (from 1).
   real(c_float),   intent(in)    :: width   !< Width.
   logical                        :: clicked !< Clicked.
   real(c_float)                  :: rh, w, x, y, ay, indent !< Layout.

   rh = row_height()
   w = width
   if (w <= 0.0_c_float) call cl_content_avail(w, ay)
   call cl_push_id_int(m - 1_c_int)
   call cl_cursor_screen_pos(x, y)
   clicked = cl_selectable('##match', m - 1_c_int == st%current_match, 0_c_int, w, rh)
   if (m - 1_c_int == st%current_match .and. (cl_window_appearing() .or. st%match_moved)) &
      call cl_set_scroll_here_y(0.5_c_float)
   indent = cl_font_size() * 0.5_c_float
   call draw_snippet(m, x + indent, y + (rh - cl_text_line_height()) * 0.5_c_float, w - indent)
   call cl_pop_id()
   endfunction match_row

   function draw_match_list(st) result(clicked)
   !< The matches with their context under their sections' titles (`_DrawMatchList`): true when one was clicked.
   type(doc_state), intent(inout) :: st      !< State.
   logical                        :: clicked !< Clicked.
   integer(c_int)                 :: section, shown, m !< Counters.
   character(len=24)              :: num     !< A number.

   clicked = .false.
   if (.not. st%search_open) then
      if (cl_button('Find in the document', 0.0_c_float, 0.0_c_float)) then
         call open_search(st)
         call cl_close_current_popup()
      endif
      return
   endif
   if (len(doc_query) == 0 .or. doc_matches%n == 0_c_int) then
      call text_disabled(merge('Type in the find bar.', 'No match.            ', len(doc_query) == 0))
      return
   endif
   section = -2_c_int
   shown = min(doc_matches%n, LISTED_MATCHES_MAX)
   do m = 1_c_int, shown
      if (sections(m) /= section) then
         section = sections(m)
         call text_disabled(section_title(m))
      endif
      if (match_row(st, m, 0.0_c_float)) then
         call go_to_match(st, m)
         clicked = .true.
      endif
   enddo
   if (shown < doc_matches%n) then
      write(num, '(I0)') doc_matches%n - shown
      call text_disabled(trim(num)//' more matches')
   endif
   endfunction draw_match_list

   subroutine text_disabled(text)
   !< `TextDisabled("%s", text)`.
   character(len=*), intent(in) :: text !< Text.
   real(c_float)                :: rgba(4) !< Colour.

   call cl_style_color(ImGuiCol_TextDisabled, rgba)
   call cl_push_style_color(ImGuiCol_Text, rgba)
   call cl_text_str(trim(text))
   call cl_pop_style_color()
   endsubroutine text_disabled

   subroutine draw_scrollbar_ticks(st)
   !< The matches as ticks on the content's scrollbar; a hover shows their context, a click lists them in a small
   !< window (`_DrawScrollbarTicks`).
   type(doc_state), intent(inout) :: st !< State.
   real(c_float)                  :: em, width, bx0, by0, bx1, by1, content_height, half, y, rgba(4), s(14), mx, my !< Layout.
   integer(c_int)                 :: m, nh, k
   integer(c_int), allocatable    :: hovered(:)
   logical                        :: current, mac, want_text, touch, shift, slash
   real(c_float)                  :: cpx, cpy, wheel, dx, at(2), px, py
   integer(c_int)                 :: chars
   character(len=24)              :: num

   call push_regular_font()
   em = cl_font_size()
   width = em * 24.0_c_float
   call cl_window_state(s)
   allocate(hovered(max(doc_matches%n, 1_c_int)))
   nh = 0_c_int
   if (s(12) /= 0.0_c_float .and. doc_matches%n > 0_c_int) then
      call cl_scrollbar_rect(bx0, by0, bx1, by1)
      content_height = s(6) + s(11)
      half = max(2.0_c_float, em * 0.15_c_float)
      call cl_push_clip_rect(bx0, by0, bx1, by1)
      do m = 1_c_int, doc_matches%n
         current = m - 1_c_int == st%current_match
         if (.not. current .and. .not. st%highlight_all) cycle
         y = doc_matches%y(m) / content_height * (by1 - by0)
         y = by0 + y
         if (current) then
            rgba = SEARCH_MATCH_CURRENT
         else
            rgba = SEARCH_MATCH
         endif
         rgba(4) = 1.0_c_float
         call cl_draw_rect_filled(bx0 + 1.0_c_float, y - half, bx1 - 1.0_c_float, y + half, cl_color_u32_rgba(rgba), &
                                  0.0_c_float)
         if (cl_mouse_hovering_rect(bx0, y - 2.0_c_float * half, bx1, y + 2.0_c_float * half, .false.)) then
            nh = nh + 1_c_int
            hovered(nh) = m
         endif
      enddo
      call cl_pop_clip_rect()
      if (nh > 0_c_int .and. cl_window_hovered(ImGuiHoveredFlags_AllowWhenBlockedByActiveItem)) then
         call cl_mouse_pos(mx, my)
         at = [bx0 - em * 0.5_c_float, my]
         call cl_io_state(cpx, cpy, wheel, dx, mac, want_text, touch, shift, chars, slash)
         if (.not. touch) then
            call cl_set_next_window_pos(at(1), at(2), ImGuiCond_Always, 1.0_c_float, 0.5_c_float)
            if (cl_begin_tooltip()) then
               do k = 1_c_int, min(nh, 5_c_int)
                  call text_disabled(section_title(hovered(k)))
                  call cl_cursor_screen_pos(px, py)
                  call cl_dummy(width, cl_text_line_height())
                  call draw_snippet(hovered(k), px, py, width)
               enddo
               call cl_end_tooltip()
            endif
         endif
         if (cl_mouse_released(ImGuiMouseButton_Left) .and. .not. cl_mouse_drag_past(ImGuiMouseButton_Left)) then
            if (size(st%tick_matches) < nh) then
               deallocate(st%tick_matches)
               allocate(st%tick_matches(nh))
            endif
            st%tick_matches(1:nh) = hovered(1:nh) - 1_c_int
            st%ntick = nh
            st%tick_popup_pos = at
            call cl_open_popup('##ticks')
         endif
      endif
   endif
   call cl_set_next_window_pos(st%tick_popup_pos(1), st%tick_popup_pos(2), ImGuiCond_Appearing, 1.0_c_float, 0.5_c_float)
   if (cl_begin_popup('##ticks')) then
      if (st%ntick == 1_c_int) then
         call text_disabled('1 match here')
      else
         write(num, '(I0)') st%ntick
         call text_disabled(trim(num)//' matches here')
      endif
      do k = 1_c_int, st%ntick
         m = st%tick_matches(k) + 1_c_int
         if (m <= doc_matches%n) then
            if (match_row(st, m, width)) call go_to_match(st, m)
         endif
      enddo
      call cl_end_popup()
   endif
   call cl_pop_font()
   endsubroutine draw_scrollbar_ticks

   subroutine draw_find_bar(st, cmin, cmax)
   !< The find bar over the top right of the content (`_DrawFindBar`): the query, the count, the previous and the next
   !< match, the list of the matches, the options; enter and shift+enter step, escape closes it.
   type(doc_state), intent(inout) :: st !< State.
   real(c_float),   intent(in)    :: cmin(2), cmax(2) !< The content's rectangle.
   real(c_float)                  :: em, pad, width, button, count_width, rgba(4), ax, ay, x, y, rows, height, below, h
   character(len=32)              :: count
   character(kind=c_char)         :: saved(QUERY_SIZE)
   logical                        :: typing, dropdown, select_query, mac, want_text, touch, shift, slash
   real(c_float)                  :: cpx, cpy, wheel, dx
   integer(c_int)                 :: chars, step
   character(len=:), allocatable  :: message

   call push_regular_font()
   em = cl_font_size()
   pad = em * 0.4_c_float
   width = cmax(1) - cmin(1)
   if (fr_narrow) then
      call cl_set_cursor_screen_pos(cmin(1), cmin(2) - st%find_bar_height - style_value(5_c_int))
   else
      width = min(em * 30.0_c_float, width - style_value(10_c_int) - 2.0_c_float * pad)
      call cl_set_cursor_screen_pos(cmax(1) - style_value(10_c_int) - pad - width, cmin(2) + pad)
   endif
   call cl_style_color(ImGuiCol_MenuBarBg, rgba)
   rgba(4) = 1.0_c_float
   call cl_push_style_color(ImGuiCol_ChildBg, rgba)
   if (cl_begin_child('##findbar', width, 0.0_c_float, ior(ior(ImGuiChildFlags_Borders, ImGuiChildFlags_AutoResizeY), &
                      ImGuiChildFlags_AlwaysUseWindowPadding), 0_c_int)) continue
   call cl_pop_style_color()
   button = cl_frame_height()
   count_width = cl_text_width_str('000/000')
   count = ''
   if (st%match_count > 0_c_int) then
      write(count, '(I0,A,I0)') st%current_match + 1_c_int, '/', st%match_count
   elseif (st%query(1) /= c_null_char) then
      count = '0/0'
   endif
   call cl_content_avail(ax, ay)
   x = ax - 4.0_c_float * (button + style_value(4_c_int))
   x = x - count_width
   x = x - style_value(4_c_int)
   call cl_set_next_item_width(x)
   if (st%focus_query) then
      call cl_set_keyboard_focus_here()
      st%focus_query = .false.
   endif
   saved = st%query
   step = st%step
   dropdown = st%dropdown_open
   select_query = st%select_query
   if (cl_find_field('##query', 'Find in the document', st%query, step, dropdown, select_query)) st%jump_to_first = .true.
   st%step = step
   st%dropdown_open = dropdown
   st%select_query = select_query
   typing = cl_item_active() .or. cl_item_deactivated()
   if (typing .and. (cl_key_pressed(ImGuiKey_Enter) .or. cl_key_pressed(ImGuiKey_KeypadEnter))) then
      call cl_io_state(cpx, cpy, wheel, dx, mac, want_text, touch, shift, chars, slash)
      st%step = merge(-1_c_int, 1_c_int, shift)
      st%focus_query = .true.
   endif
   if (typing .and. cl_key_pressed(ImGuiKey_Escape)) then
      st%query = saved
      call close_search(st)
   endif
   call cl_same_line()
   call cl_cursor_pos(x, y)
   call cl_set_cursor_pos_x(x + count_width - cl_text_width_str(trim(count)))
   call cl_align_text_to_frame_padding()
   call cl_text_str(trim(count))
   call cl_same_line()
   if (cl_arrow_button('##previous', ImGuiDir_Up)) st%step = -1_c_int
   call cl_same_line()
   if (cl_arrow_button('##next', ImGuiDir_Down)) st%step = 1_c_int
   call cl_same_line()
   if (icon_button('##list', ICON_LIST)) st%dropdown_open = .not. st%dropdown_open
   call cl_same_line()
   if (icon_button('##close', ICON_CLOSE)) call close_search(st)
   call option('Match case', st%match_case, .true.)
   call option('Whole words', st%whole_words, .false.)
   call option('Highlight all', st%highlight_all, .false.)
   if (st%wrap_message /= WRAP_NONE) then
      if (st%wrap_message == WRAP_END) then
         message = 'Reached the end, continued from the top.'
      else
         message = 'Reached the top, continued from the end.'
      endif
      call cl_push_style_color(ImGuiCol_Text, md_admonition_color(4_c_int))
      call cl_text_str(message)
      call cl_pop_style_color()
   endif
   if (st%dropdown_open .and. len(doc_query) > 0) then
      call cl_separator()
      rows = real(min(max(doc_matches%n, 1_c_int), 10_c_int), c_float) + 1.0_c_float
      height = rows * (row_height() + style_value(5_c_int))
      call cl_cursor_screen_pos(x, y)
      below = cmax(2) - y
      below = below - style_value(7_c_int)
      below = below - 2.0_c_float * pad
      if (fr_narrow) then
         height = min(height, fr_size(2) * 0.35_c_float)
      else
         height = min(height, below)
      endif
      if (cl_begin_child('##matches', 0.0_c_float, max(height, cl_frame_height()), 0_c_int, 0_c_int)) continue
      if (draw_match_list(st)) continue
      call cl_end_child()
   endif
   call cl_end_child()
   call cl_item_rect_size(x, h)
   st%find_bar_height = h
   if (fr_narrow) then
      st%find_bar_bottom = 0.0_c_float
   else
      call cl_item_rect_max(x, y)
      st%find_bar_bottom = y - cmin(2)
   endif
   call cl_pop_font()
   contains
      subroutine option(label, value, first)
      !< An option of the search, on the bar's row when it fits.
      character(len=*), intent(in)    :: label !< Label.
      logical,          intent(inout) :: value !< Value.
      logical,          intent(in)    :: first !< The first one.
      real(c_float)                   :: ax_, ay_ !< Room.

      if (.not. first) then
         call cl_same_line()
         call cl_content_avail(ax_, ay_)
         if (ax_ < cl_frame_height() + style_value(8_c_int) + cl_text_width_str(label)) call cl_new_line()
      endif
      if (cl_checkbox(label, value)) continue
      endsubroutine option
   endsubroutine draw_find_bar

   ! ---- the table of contents ---------------------------------------------------------------------------------------
   function draw_toc_entries(st) result(clicked)
   !< The entries of the table of contents: a click scrolls to the entry's heading (`_DrawTocEntries`).
   type(doc_state), intent(inout) :: st      !< State.
   logical                        :: clicked !< An entry was clicked.
   integer(c_int)                 :: min_level, j, k, cnt, col !< Counters.
   real(c_float)                  :: line_height, rh, x, y, lw !< Layout.
   logical                        :: searching, dim !< State.
   character(len=32)              :: label  !< A count.
   character(len=:), allocatable  :: text   !< A heading's text.

   min_level = 6_c_int
   do j = 1_c_int, nlisted
      min_level = min(min_level, doc_heads%level(listed(j)))
   enddo
   line_height = cl_text_line_height()
   rh = row_height()
   searching = len(doc_query) > 0
   clicked = .false.
   do j = 1_c_int, nlisted
      k = listed(j)
      call cl_push_id_int(k - 1_c_int)
      if (cl_selectable('##entry', k == view_current, 0_c_int, 0.0_c_float, rh)) then
         call scroll_to_heading(st, md_heading_slug(doc_heads, k))
         clicked = .true.
      endif
      if (k == view_current .and. st%current_section /= view_current .and. .not. cl_item_visible()) &
         call cl_set_scroll_here_y(0.5_c_float)
      call cl_item_rect_min(x, y)
      lw = real(doc_heads%level(k) - min_level, c_float) * cl_font_size()
      x = x + style_value(1_c_int) + lw
      y = y + (rh - line_height) * 0.5_c_float
      cnt = 0_c_int
      if (searching) cnt = counts(k)
      dim = doc_heads%hidden(k) .or. (searching .and. cnt == 0_c_int)
      col = cl_color_u32(merge(ImGuiCol_TextDisabled, ImGuiCol_Text, dim))
      text = md_heading_text(doc_heads, k)
      call cl_draw_text(x, y, col, text)
      if (cnt > 0_c_int) then
         write(label, '(A,I0,A)') '  (', cnt, ')'
         x = x + cl_text_width_str(text)
         call cl_draw_text(x, y, cl_color_u32(ImGuiCol_TextDisabled), trim(label))
      endif
      call cl_pop_id()
   enddo
   endfunction draw_toc_entries

   subroutine draw_toc_tabs(st)
   !< The table of contents, and the matches in a second tab (`_DrawTocTabs`).
   type(doc_state), intent(inout) :: st    !< State.
   character(len=48)              :: label !< The Search tab's label.

   if (.not. cl_begin_tab_bar('##tabs')) return
   if (cl_begin_tab_item('Contents')) then
      if (draw_toc_entries(st)) continue
      call cl_end_tab_item()
   endif
   if (len(doc_query) == 0) then
      label = 'Search###search'
   else
      write(label, '(A,I0,A)') 'Search (', doc_matches%n, ')###search'
   endif
   if (cl_begin_tab_item(trim(label))) then
      if (draw_match_list(st)) continue
      call cl_end_tab_item()
   endif
   call cl_end_tab_bar()
   endsubroutine draw_toc_tabs

   subroutine draw_toc_panel(st)
   !< The table of contents beside the content, and its edge, dragged to resize it (`_DrawTocPanel`).
   type(doc_state), intent(inout) :: st !< State.
   logical                        :: active, mac, want_text, touch, shift, slash !< State.
   real(c_float)                  :: a(2), b(2), x, cpx, cpy, wheel, dx !< Layout.
   integer(c_int)                 :: chars !< Input.

   call cl_set_cursor_pos(fr_origin(1), fr_origin(2))
   if (cl_begin_child('##toc', fr_panel_width, fr_size(2), ImGuiChildFlags_Borders, 0_c_int)) continue
   call push_regular_font()
   if (cl_arrow_button('##hide', ImGuiDir_Left)) st%panel_shown = .false.
   call cl_same_line()
   if (fr_search) then
      call draw_toc_tabs(st)
   else
      call cl_align_text_to_frame_padding()
      call text_disabled('Contents')
      call cl_separator()
      if (draw_toc_entries(st)) continue
   endif
   call cl_pop_font()
   call cl_end_child()
   call cl_set_cursor_pos(fr_origin(1) + fr_panel_width, fr_origin(2))
   if (cl_invisible_button('##edge', fr_splitter_width, fr_size(2))) continue
   active = cl_item_active()
   if (active) then
      call cl_io_state(cpx, cpy, wheel, dx, mac, want_text, touch, shift, chars, slash)
      st%panel_width = st%panel_width + dx / cl_font_size()
   endif
   if (active .or. cl_item_hovered()) then
      call cl_set_mouse_cursor(ImGuiMouseCursor_ResizeEW)
      call cl_item_rect_min(a(1), a(2))
      call cl_item_rect_max(b(1), b(2))
      x = (a(1) + b(1)) * 0.5_c_float
      call cl_draw_line(x, a(2), x, b(2), cl_color_u32(merge(ImGuiCol_SeparatorActive, ImGuiCol_SeparatorHovered, &
                        active)), 2.0_c_float)
   endif
   endsubroutine draw_toc_panel

   subroutine draw_toc_line(st)
   !< The table of contents hidden, or a narrow document: a line above the content with the current section, which
   !< opens the table of contents as a menu, a button that shows the panel again, the magnifier (`_DrawTocLine`).
   type(doc_state), intent(inout) :: st    !< State.
   character(len=:), allocatable  :: title !< The current section.
   real(c_float)                  :: find_width !< The magnifier's room.

   call cl_set_cursor_pos(fr_origin(1), fr_origin(2))
   call push_regular_font()
   if (.not. fr_narrow) then
      if (cl_arrow_button('##show', ImGuiDir_Right)) st%panel_shown = .true.
      call cl_same_line()
   endif
   if (view_current > 0_c_int) then
      title = md_heading_text(doc_heads, view_current)
   else
      title = 'Contents'
   endif
   find_width = 0.0_c_float
   if (fr_search) find_width = cl_frame_height() + style_value(4_c_int)
   call cl_set_next_item_width(-tiny(1.0_c_float) - find_width)
   if (cl_begin_combo('##section', title, ImGuiComboFlags_HeightLarge)) then
      if (fr_search) then
         call draw_toc_tabs(st)
      else
         if (draw_toc_entries(st)) continue
      endif
      call cl_end_combo()
   endif
   if (fr_search) then
      call cl_same_line()
      if (icon_button('##find', ICON_FIND)) call open_search(st)
   endif
   call cl_pop_font()
   endsubroutine draw_toc_line
endmodule figure_markdown_document
