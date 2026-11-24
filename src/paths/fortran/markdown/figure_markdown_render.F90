!< figure_markdown_render, the Fortran path's Markdown renderer: imgui_rich_md's, in Fortran over md4c and figure_core.
module figure_markdown_render
!< figure_markdown_render, the Fortran path's Markdown renderer: imgui_rich_md's, in Fortran over md4c and figure_core.
!<
!< szaghi/figure#15 P15. imgui_rich_md (pthom, MIT; forked from imgui_md, Dmitry Mekhontsev, MIT) draws Markdown with
!< Dear ImGui's items as md4c parses it: `print()` hands a fragment (the text of one call) to md4c, whose callbacks enter
!< and leave each block and span and give each piece of text; they draw as they go. This module is that renderer, as
!< FIGURE uses it (`RenderRaw` with FIGURE's options: IBM Plex Sans and Mono, links reported, images from files, no
!< LaTeX, no wikilinks, no folding headings, no fenced block renderers, plain code blocks), drawn through figure_core
!< (figure_core_layout) with the same calls in the same order, so the pictures and the layout are imgui_rich_md's to the
!< bit (the arithmetic in single precision, as its floats). The parser stays C (md4c, figure_md4c; K1).
!<
!< What a fragment draws (`internal/rich_md_renderer.cpp`): paragraphs wrapped word by word (a word that does not fit
!< goes whole to the next line, with the rest of a word glued across the markup); headings (larger, `#` and `##`
!< underlined) and their slugs; emphasis and strong emphasis (italic, bold, bold italic), strikethrough, underline; code
!< spans and code blocks (in a frame with a Copy button); bullet, ordered and task lists; quotes and GitHub's
!< admonitions (`> [!NOTE]`); tables (their cells aligned); thematic breaks; images (PNG and JPEG files, never a URL);
!< links (coloured, underlined, a tooltip with the URL, reported on a click; a link to a heading of the same fragment
!< scrolls there); the HTML of imgui_rich_md (`<br>`, `<hr>`, `<u>`, `<sub>`, `<sup>`, `<kbd>`, `<mark>`,
!< `<md-error>`, `<details>` and `<summary>`, `<pre>`, `<img>`, `<center>`, `<div>`, comments) and `&nbsp;`. The text can
!< be selected with the mouse (a double click a word, a triple click a block), copied (ctrl+c, the menu of a right click:
!< Copy, Copy as Markdown, Select All, Copy Link).
!<
!< One renderer for the program, as imgui_rich_md's context has one: its state (the selection, the anchor being
!< reached, the images' textures) is kept between frames; md4c's text and the fragment are read in place.
use, intrinsic :: iso_c_binding, only : c_associated, c_char, c_f_pointer, c_float, c_funloc, c_int, c_loc, &
                                         c_long_long, c_null_ptr, c_ptr
use, intrinsic :: iso_fortran_env, only : int32
use figure_base, only : figure_check, figure_draw_refused
use figure_c_native, only : FIG_OK
use figure_cimgui_enums, only : ImGuiChildFlags_AlwaysUseWindowPadding, ImGuiChildFlags_AutoResizeY, ImGuiCol_Border, &
                                ImGuiCol_Button, ImGuiCol_ButtonHovered, ImGuiCol_CheckMark, ImGuiCol_ChildBg,         &
                                ImGuiCol_FrameBg, ImGuiCol_Text, ImGuiCol_TextDisabled, ImGuiCol_TextSelectedBg,       &
                                ImGuiCond_Once, ImGuiHoveredFlags_AllowWhenBlockedByActiveItem,                       &
                                ImGuiHoveredFlags_DelayNormal, ImGuiKey_A, ImGuiKey_C, ImGuiMod_Ctrl,                  &
                                ImGuiMouseCursor_Hand, ImGuiMouseCursor_TextInput, ImGuiTableFlags_BordersInnerH,     &
                                ImGuiTableFlags_BordersInnerV, ImGuiTableFlags_BordersOuterH,                         &
                                ImGuiTableFlags_BordersOuterV, ImGuiTableFlags_Resizable,                             &
                                ImGuiTableFlags_SizingStretchProp
use figure_core_layout, only : cl_any_item_hovered, cl_active_id, cl_begin_child, cl_begin_group, cl_begin_popup,     &
                               cl_begin_table, cl_bullet, cl_channels_merge, cl_channels_set, cl_channels_split,      &
                               cl_clear_active_id, cl_collapsing_header, cl_color_u32, cl_color_u32_rgba,             &
                               cl_content_avail, cl_cursor_pos, cl_cursor_screen_pos, cl_draw_line, cl_draw_rect,      &
                               cl_draw_rect_filled, cl_dummy, cl_end_child, cl_end_group, cl_end_popup, cl_end_table,  &
                               cl_float4_to_u32, cl_font, cl_font_scale, cl_font_size, cl_font_text_width,            &
                               cl_frame_count, cl_get_id, cl_hash_str, cl_hsv_to_rgb, cl_image, cl_indent,           &
                               cl_io_state, cl_item_hovered, cl_item_id, cl_item_rect_max, cl_item_rect_min,         &
                               cl_item_rect_size, cl_keep_alive, cl_key_chord_pressed, cl_line_open, cl_menu_item,   &
                               cl_mouse_clicked, cl_mouse_clicked_count, cl_mouse_down, cl_mouse_drag_past,          &
                               cl_mouse_pos, cl_mouse_pos_valid, cl_mouse_released, cl_new_line, cl_open_popup,      &
                               cl_pop_font, cl_pop_id, cl_pop_style_color, cl_ptr_add, cl_ptr_diff, cl_push_font,    &
                               cl_push_id, cl_push_id_int, cl_push_style_color, cl_rgb_to_hsv, cl_same_line,         &
                               cl_scroll_y, cl_separator, cl_set_active_id, cl_set_clipboard, cl_set_cursor_pos,     &
                               cl_set_cursor_pos_x, cl_set_cursor_pos_y, cl_set_mouse_cursor, cl_set_next_item_open,  &
                               cl_set_scroll_y, cl_small_button, cl_splitter_merge, cl_splitter_set,                 &
                               cl_splitter_split, cl_storage_set_int, cl_style, cl_style_color, cl_table_next_column, &
                               cl_table_next_row, cl_text, cl_text_str, cl_text_width, cl_text_width_str,             &
                               cl_tooltip, cl_unindent, cl_utf8_length, cl_vtx_count, cl_vtx_shift, cl_window_focused, &
                               cl_window_hovered, cl_window_pos, cl_window_state, cl_word_wrap
use figure_md4c, only : md_attribute, md_block_code_detail, md_block_h_detail, md_block_li_detail, md_block_ol_detail, &
                        md_block_table_detail, md_block_td_detail, md_block_ul_detail, md_parse, md_parser,           &
                        md_span_a_detail, md_span_img_detail,                                                         &
                        MD_ALIGN_CENTER, MD_ALIGN_DEFAULT, MD_ALIGN_LEFT, MD_BLOCK_CODE, MD_BLOCK_DOC, MD_BLOCK_H,   &
                        MD_BLOCK_HR, MD_BLOCK_HTML, MD_BLOCK_LI, MD_BLOCK_OL, MD_BLOCK_P, MD_BLOCK_QUOTE,             &
                        MD_BLOCK_TABLE, MD_BLOCK_TBODY, MD_BLOCK_TD, MD_BLOCK_TH, MD_BLOCK_THEAD, MD_BLOCK_TR,        &
                        MD_BLOCK_UL, MD_FLAG_PERMISSIVEEMAILAUTOLINKS, MD_FLAG_PERMISSIVEURLAUTOLINKS,                &
                        MD_FLAG_PERMISSIVEWWWAUTOLINKS, MD_FLAG_STRIKETHROUGH, MD_FLAG_TABLES, MD_FLAG_TASKLISTS,      &
                        MD_FLAG_UNDERLINE, MD_SPAN_A, MD_SPAN_CODE, MD_SPAN_DEL, MD_SPAN_EM, MD_SPAN_IMG,             &
                        MD_SPAN_STRONG, MD_SPAN_U, MD_TEXT_BR, MD_TEXT_CODE, MD_TEXT_ENTITY, MD_TEXT_HTML,            &
                        MD_TEXT_LATEXMATH, MD_TEXT_NORMAL, MD_TEXT_NULLCHAR, MD_TEXT_SOFTBR
use figure_texture, only : texture_object, texture_ref
use figure_cimgui, only : im_texture_ref

implicit none
private
public :: md_markdown, md_last_link

real(c_float), parameter :: REGULAR_SIZE = 15.0_c_float !< The text's size [logical pixels] (FIGURE's `TEXT_SIZE`).
real(c_float), parameter :: HEADER_FACTORS(6) = [1.42_c_float, 1.33_c_float, 1.24_c_float, 1.15_c_float, 1.10_c_float, &
                                                 1.05_c_float] !< The headings' sizes, h1 to h6.
! imgui_rich_md's Style, its defaults (colours with a negative alpha are automatic: from Dear ImGui's style)
real(c_float), parameter :: BLOCK_GAP = 0.3_c_float          !< Between blocks [em].
real(c_float), parameter :: LIST_ITEM_GAP = 0.0_c_float      !< Between list items [em].
real(c_float), parameter :: HEADER_GAP_STEP = 0.12_c_float   !< Above a heading, per level below 7 [em].
real(c_float), parameter :: SUB_SUP_SCALE = 0.7_c_float      !< `<sub>` and `<sup>`.
real(c_float), parameter :: QUOTE_BAR_THICKNESS = 2.0_c_float      !< A quote's bar [pixels].
real(c_float), parameter :: ADMONITION_BAR_THICKNESS = 3.0_c_float !< An admonition's.
real(c_float), parameter :: MARK_BACKGROUND(4) = [245.0_c_float / 255.0_c_float, 205.0_c_float / 255.0_c_float, &
                                                  60.0_c_float / 255.0_c_float, 120.0_c_float / 255.0_c_float] !< `<mark>`.
real(c_float), parameter :: ADMONITION_COLORS(4, 5) = reshape([0.35_c_float, 0.65_c_float, 1.00_c_float, 1.0_c_float,  &
                                                               0.25_c_float, 0.73_c_float, 0.32_c_float, 1.0_c_float,  &
                                                               0.82_c_float, 0.60_c_float, 0.97_c_float, 1.0_c_float,  &
                                                               0.95_c_float, 0.75_c_float, 0.22_c_float, 1.0_c_float,  &
                                                               0.97_c_float, 0.32_c_float, 0.29_c_float, 1.0_c_float], &
                                                              [4, 5]) !< Note, Tip, Important, Warning, Caution.
integer(c_int), parameter :: ADMON_NONE = 0_c_int !< Not an admonition.
integer(c_int), parameter :: MD_FLAGS = ior(ior(ior(MD_FLAG_TABLES, MD_FLAG_UNDERLINE), ior(MD_FLAG_STRIKETHROUGH, &
                                        MD_FLAG_TASKLISTS)), ior(ior(MD_FLAG_PERMISSIVEURLAUTOLINKS,               &
                                        MD_FLAG_PERMISSIVEEMAILAUTOLINKS), MD_FLAG_PERMISSIVEWWWAUTOLINKS)) !< md4c's.
integer(c_int), parameter :: REPL_NONE = 0_c_int  !< A run shows its bytes.
integer(c_int), parameter :: REPL_SPACE = 1_c_int !< ... a space (a soft break).
integer(c_int), parameter :: REPL_LF = 2_c_int    !< ... a newline (a hard break).

type :: text_run
   !< A run of text drawn by the fragment: its rectangle, font, the bytes of the fragment it shows.
   real(c_float)  :: x0 = 0.0_c_float, y0 = 0.0_c_float, x1 = 0.0_c_float, y1 = 0.0_c_float !< Rectangle (screen).
   type(c_ptr)    :: font = c_null_ptr  !< C `ImFont*`.
   real(c_float)  :: font_size = 0.0_c_float !< Its size.
   integer(c_int) :: b = 0_c_int        !< First byte (0-based offset in the fragment).
   integer(c_int) :: e = 0_c_int        !< Past the last.
   integer(c_int) :: block = 0_c_int    !< Its block (a newline between two blocks, in a copy).
   integer(c_int) :: href_b = 0_c_int   !< Its link's target: offset in the pool of links (0-based).
   integer(c_int) :: href_n = 0_c_int   !< ... bytes (0: no link).
   integer(c_int) :: repl = REPL_NONE   !< What it shows instead of its bytes.
endtype text_run

type :: md_heading
   !< A heading of the last fragment.
   integer(c_int) :: level = 1_c_int        !< 1 to 6.
   real(c_float)  :: y = 0.0_c_float        !< Its top, in its window's content coordinates.
   logical        :: hidden = .false.       !< Inside a collapsed `<details>`.
   integer(c_int) :: details = 0_c_int      !< What hides it (0: none).
   integer(c_int) :: slug_b = 0_c_int       !< Its slug: offset in the pool of slugs (0-based).
   integer(c_int) :: slug_n = 0_c_int       !< ... bytes.
endtype md_heading

type :: list_info
   !< A list being drawn.
   integer(c_int)         :: cur_ol = 0_c_int           !< The next number.
   character(kind=c_char) :: delim = ' '                !< Its mark or delimiter.
   logical                :: is_ol = .false.            !< Ordered.
   logical                :: first_item_pending = .true. !< Its first item not drawn yet.
endtype list_info

type :: md_image
   !< An image of the cache, by path.
   integer(c_int)       :: path_b = 0_c_int !< Its path: offset in the pool of paths (0-based).
   integer(c_int)       :: path_n = 0_c_int !< ... bytes.
   logical              :: valid = .false.  !< Read (else a broken image, not read again).
   type(texture_object) :: tex              !< Its texture.
endtype md_image

! the fonts, the parser, the fragment
type(c_ptr)       :: fonts(5) = c_null_ptr !< Regular, bold, italic, bold italic, code (fig_markdown_fonts).
integer(c_int)    :: generation = 0_c_int  !< The application they belong to.
real(c_float)     :: font_scale = 1.0_c_float !< The scale locked by the render.
type(md_parser), save :: parser            !< md4c's parser: the flags and the callbacks.
logical           :: parser_made = .false. !< ... set.
character(kind=c_char), allocatable, target :: frag(:) !< The fragment, NUL-terminated (its bytes 1..nfrag).
integer(c_int)    :: nfrag = 0_c_int       !< Its bytes.
type(c_ptr)       :: base = c_null_ptr     !< Its first byte.
integer(c_int)    :: fragment_frame = -1_c_int  !< The frame of the last fragment.
integer(c_int)    :: fragment_counter = 0_c_int !< The fragments of this frame (their IDs).
! links reported
logical                       :: link_clicked = .false. !< A link was clicked in the fragment being drawn.
character(len=:), allocatable :: link                   !< Its URL (kept until the next click).
! the renderer's state (rich_md_renderer.h)
character(len=:), allocatable :: href      !< The link being drawn ('': none).
character(len=:), allocatable :: img_src   !< The image being drawn.
logical :: is_underline = .false., is_strikethrough = .false., is_em = .false., is_strong = .false.
logical :: is_sub = .false., is_sup = .false., is_kbd = .false., is_error = .false., is_mark = .false.
character(len=:), allocatable :: error_title !< `<md-error title=...>`.
logical, allocatable :: details_open(:)     !< One per `<details>` open: expanded.
integer(c_int) :: ndetails = 0_c_int        !< ... how many.
logical :: details_awaiting_summary = .false., details_awaiting_open_default = .false.
logical :: details_suppress_next_raw_html = .false., in_html_comment = .false., html_comment_closed = .false.
logical :: html_gap_pending = .false.
integer(c_int) :: details_id_counter = 0_c_int !< `<summary>`s so far.
logical :: in_pre = .false.                    !< Inside `<pre>`.
character(len=:), allocatable, target :: pre_buffer !< Its text so far.
logical :: is_table_header = .false., is_table_body = .false., is_image = .false.
character(len=:), allocatable :: heading_text !< The heading being read.
logical :: in_center = .false.
integer(c_int) :: center_vtx_start = 0_c_int
real(c_float)  :: center_width = 0.0_c_float
logical :: is_code = .false., is_code_block = .false.
logical :: skip_next_block_gap = .true.
real(c_float) :: list_block_mark(2) = 0.0_c_float !< In a list: the last item drawn when a block of an item started.
integer(c_int) :: quote_depth = 0_c_int
real(c_float), allocatable :: quote_start(:,:) !< The indented column at each quote's start.
integer(c_int) :: admonition_kind = ADMON_NONE
logical :: admonition_scan_pending = .false., admonition_skip_next_softbr = .false.
character(len=:), allocatable :: code_block_language
character(len=:), allocatable, target :: code_block !< The code block being read.
integer(c_int) :: hlevel = 0_c_int !< The heading level (0: none).
integer(c_int) :: table_id_counter = 0_c_int
logical :: table_open = .false.
integer(c_int) :: cell_align = MD_ALIGN_DEFAULT, cell_vtx_start = 0_c_int
real(c_float)  :: cell_width = 0.0_c_float
type(list_info), allocatable :: list_stack(:)
integer(c_int) :: nlist = 0_c_int
integer(c_int) :: div_depth = 0_c_int
! the runs, the selection
type(text_run), allocatable :: runs(:)
integer(c_int) :: nruns = 0_c_int
character(len=:), allocatable :: link_pool !< The links' targets of the runs.
integer(c_int) :: nlink_pool = 0_c_int
integer(c_int) :: block_number = 0_c_int, top_block_count = 0_c_int
integer(c_int) :: cell_run_start = 0_c_int, center_run_start = 0_c_int
integer(c_int) :: selection_fragment = 0_c_int, selection_text_hash = 0_c_int
integer(c_int) :: selection_anchor = 0_c_int, selection_focus = 0_c_int
logical :: selection_by_unit = .false., press_in_selection = .false.
character(len=:), allocatable :: menu_link
! the headings and anchors
type(md_heading), allocatable :: headings(:)
integer(c_int) :: nheadings = 0_c_int
character(len=:), allocatable :: slug_pool    !< The headings' slugs.
integer(c_int) :: nslug_pool = 0_c_int
character(len=:), allocatable :: occ_pool     !< The slugs given so far (each followed by a NUL).
integer(c_int), allocatable :: occ_count(:)   !< ... their counts.
integer(c_int), allocatable :: occ_b(:), occ_n(:) !< ... their places in occ_pool.
integer(c_int) :: nocc = 0_c_int
real(c_float)  :: heading_top = -1.0_c_float
real(c_float)  :: hidden_y = 0.0_c_float, hidden_bottom = 0.0_c_float
integer(c_int) :: hidden_id = 0_c_int
integer(c_int) :: container_depth = 0_c_int
character(len=:), allocatable :: anchor_slug  !< An anchor clicked, being reached ('': none).
integer(c_int) :: anchor_frames = 8_c_int
integer(c_int) :: anchor_fragment = 0_c_int
integer(c_int) :: fragment_id = 0_c_int
! the images
type(md_image), allocatable :: images(:)
integer(c_int) :: nimages = 0_c_int
character(len=:), allocatable :: path_pool
integer(c_int) :: npath_pool = 0_c_int
character(kind=c_char, len=1), target :: nul = achar(0, c_char) !< An empty C string.

interface
   function fig_markdown_fonts(f) result(status) bind(C, name='fig_markdown_fonts')
   !< The renderer's fonts (native/figure_markdown.cpp): regular, bold, italic, bold italic, code.
   import :: c_int, c_ptr
   implicit none
   type(c_ptr), intent(out) :: f(5)   !< C `ImFont*`.
   integer(c_int)           :: status !< FIG_* status.
   endfunction fig_markdown_fonts

   function fig_markdown_generation() result(g) bind(C, name='fig_markdown_generation')
   !< The application the renderer's caches belong to.
   import :: c_int
   implicit none
   integer(c_int) :: g !< Generation.
   endfunction fig_markdown_generation
endinterface

contains
   ! ---- the entry point ---------------------------------------------------------------------------------------------
   function md_markdown(text, link_url, stat) result(clicked)
   !< `ig_markdown` on the Fortran path: draw `text` (Markdown, UTF-8) at the cursor, inside a window; true on the frame
   !< one of its links is clicked, its URL in `link_url` (`''` on the other frames). Statuses as `ig_markdown`'s.
   character(len=*),              intent(in)            :: text     !< Markdown.
   character(len=:), allocatable, intent(out), optional :: link_url !< The URL of the link clicked.
   integer(int32),                intent(out), optional :: stat     !< Status.
   logical                                              :: clicked  !< A link was clicked this frame.
   integer(c_int)                                       :: s        !< Status.

   clicked = .false.
   if (present(link_url)) link_url = ''
   if (figure_draw_refused('ig_markdown', stat)) return
   s = ready()
   if (s /= FIG_OK) then
      call figure_check(s, stat)
      return
   endif
   link_clicked = .false.
   call render_raw(text)
   clicked = link_clicked
   link_clicked = .false.
   if (clicked .and. present(link_url)) link_url = link
   if (present(stat)) stat = FIG_OK
   endfunction md_markdown

   function md_last_link() result(url)
   !< The URL of the last link clicked (`''`: none yet).
   character(len=:), allocatable :: url !< URL.

   url = ''
   if (allocated(link)) url = link
   endfunction md_last_link

   function ready() result(status)
   !< The fonts of this application (made at its first fragment), the caches of an earlier one forgotten.
   integer(c_int) :: status !< FIG_* status.
   integer(c_int) :: g      !< Generation.

   g = fig_markdown_generation()
   if (g /= generation) then ! a new application: its textures went with the last one
      nimages = 0_c_int
      npath_pool = 0_c_int
      selection_fragment = 0_c_int
      fragment_frame = -1_c_int
      if (allocated(anchor_slug)) anchor_slug = ''
      generation = g
   endif
   status = fig_markdown_fonts(fonts)
   endfunction ready

   subroutine render_raw(text)
   !< imgui_rich_md's `RenderRaw`: the fragment in its own ID scope (its rank among this frame's), in the default font.
   character(len=*), intent(in) :: text !< Markdown.
   integer(c_int)                :: frame !< Frame.

   frame = cl_frame_count()
   if (fragment_frame /= frame) then
      fragment_frame = frame
      fragment_counter = 0_c_int
   endif
   call cl_push_id_int(fragment_counter)
   fragment_counter = fragment_counter + 1_c_int
   font_scale = cl_font_scale()
   call cl_push_font(fonts(1), REGULAR_SIZE * font_scale)
   call print_fragment(text)
   call cl_pop_font()
   call cl_pop_id()
   endsubroutine render_raw

   ! ---- the fragment ------------------------------------------------------------------------------------------------
   subroutine print_fragment(text)
   !< imgui_rich_md's `Renderer::print`: the fragment parsed and drawn, its selection updated and drawn behind it.
   character(len=*), intent(in) :: text !< Markdown.
   integer(c_int)               :: selection_id, r, k !< IDs, status, counter.
   logical                      :: draw_selection     !< A selection to draw.

   nheadings = 0_c_int
   nocc = 0_c_int
   if (len(text) == 0) return
   call set_fragment(text)
   skip_next_block_gap = .true.
   in_html_comment = .false.
   html_comment_closed = .false.
   html_gap_pending = .false.
   table_id_counter = 0_c_int
   details_id_counter = 0_c_int
   container_depth = 0_c_int
   in_pre = .false.
   pre_buffer = ''
   nruns = 0_c_int
   nlink_pool = 0_c_int
   nslug_pool = 0_c_int
   block_number = 0_c_int
   top_block_count = 0_c_int
   selection_id = cl_get_id('##rich_md_selection')
   fragment_id = selection_id
   if (selection_fragment == selection_id) then
      if (cl_hash_str(base, nfrag) /= selection_text_hash) selection_fragment = 0_c_int
   endif
   draw_selection = selection_fragment == selection_id .and. selection_anchor /= selection_focus
   if (draw_selection) then
      call cl_splitter_split(2_c_int)
      call cl_splitter_set(1_c_int)
   endif
   call reset_state()
   r = md_parse(base, nfrag, parser, c_null_ptr)
   call resolve_anchor(selection_id)
   call update_selection(selection_id)
   if (draw_selection) then
      call cl_splitter_set(0_c_int)
      call draw_selection_rects()
      call cl_splitter_merge()
   endif
   call end_line()
   k = r
   endsubroutine print_fragment

   subroutine set_fragment(text)
   !< The fragment copied into the module's buffer (grown when needed: no allocation once it is large enough), the
   !< parser made at the first use.
   character(len=*), intent(in) :: text !< Markdown.
   integer(c_int)               :: n, k !< Bytes, counter.

   n = len(text, c_int)
   if (.not. allocated(frag)) allocate(frag(max(n + 1_c_int, 1024_c_int)))
   if (size(frag, kind=c_int) < n + 1_c_int) then
      deallocate(frag)
      allocate(frag(2_c_int * n + 1_c_int))
   endif
   do k = 1_c_int, n
      frag(k) = text(k:k)
   enddo
   frag(n + 1_c_int) = achar(0, c_char)
   nfrag = n
   base = c_loc(frag(1))
   if (.not. parser_made) then
      parser%abi_version = 0_c_int
      parser%flags = MD_FLAGS
      parser%enter_block = c_funloc(cb_enter_block)
      parser%leave_block = c_funloc(cb_leave_block)
      parser%enter_span = c_funloc(cb_enter_span)
      parser%leave_span = c_funloc(cb_leave_span)
      parser%text = c_funloc(cb_text)
      parser_made = .true.
   endif
   endsubroutine set_fragment

   subroutine reset_state()
   !< The span and block state at a fragment's start (what a fragment left open, as md4c closes every block it opens).
   href = ''
   img_src = ''
   error_title = ''
   heading_text = ''
   code_block = ''
   code_block_language = ''
   if (.not. allocated(menu_link)) menu_link = ''
   if (.not. allocated(anchor_slug)) anchor_slug = ''
   if (.not. allocated(link)) link = ''
   endsubroutine reset_state

   ! ---- md4c's callbacks --------------------------------------------------------------------------------------------
   function cb_enter_block(type, detail, userdata) result(res) bind(C)
   !< md4c entering a block.
   integer(c_int), value :: type     !< `MD_BLOCKTYPE`.
   type(c_ptr),    value :: detail   !< Its detail.
   type(c_ptr),    value :: userdata !< Unused.
   integer(c_int)        :: res      !< 0: go on.

   res = 0_c_int
   if (c_associated(userdata)) continue
   call block(type, detail, .true.)
   endfunction cb_enter_block

   function cb_leave_block(type, detail, userdata) result(res) bind(C)
   !< md4c leaving a block.
   integer(c_int), value :: type     !< `MD_BLOCKTYPE`.
   type(c_ptr),    value :: detail   !< Its detail.
   type(c_ptr),    value :: userdata !< Unused.
   integer(c_int)        :: res      !< 0: go on.

   res = 0_c_int
   if (c_associated(userdata)) continue
   call block(type, detail, .false.)
   endfunction cb_leave_block

   function cb_enter_span(type, detail, userdata) result(res) bind(C)
   !< md4c entering a span.
   integer(c_int), value :: type     !< `MD_SPANTYPE`.
   type(c_ptr),    value :: detail   !< Its detail.
   type(c_ptr),    value :: userdata !< Unused.
   integer(c_int)        :: res      !< 0: go on.

   res = 0_c_int
   if (c_associated(userdata)) continue
   call span(type, detail, .true.)
   endfunction cb_enter_span

   function cb_leave_span(type, detail, userdata) result(res) bind(C)
   !< md4c leaving a span.
   integer(c_int), value :: type     !< `MD_SPANTYPE`.
   type(c_ptr),    value :: detail   !< Its detail.
   type(c_ptr),    value :: userdata !< Unused.
   integer(c_int)        :: res      !< 0: go on.

   res = 0_c_int
   if (c_associated(userdata)) continue
   call span(type, detail, .false.)
   endfunction cb_leave_span

   function cb_text(type, text, size, userdata) result(res) bind(C)
   !< md4c giving a piece of text (in the fragment: its offsets are read from the pointer).
   integer(c_int), value :: type     !< `MD_TEXTTYPE`.
   type(c_ptr),    value :: text     !< `const MD_CHAR*`.
   integer(c_int), value :: size     !< Bytes.
   type(c_ptr),    value :: userdata !< Unused.
   integer(c_int)        :: res      !< 0: go on.
   integer(c_int)        :: b        !< Offset.

   res = 0_c_int
   if (c_associated(userdata)) continue
   b = cl_ptr_diff(text, base)
   call on_text(type, b, b + size)
   endfunction cb_text

   ! ---- small helpers -----------------------------------------------------------------------------------------------
   pure function at(o) result(c)
   !< The fragment's byte at offset o (0-based).
   integer(c_int), intent(in) :: o !< Offset.
   character(kind=c_char)     :: c !< Byte.

   c = frag(o + 1_c_int)
   endfunction at

   function ptr(o) result(p)
   !< The pointer to the fragment's byte at offset o.
   integer(c_int), intent(in) :: o !< Offset.
   type(c_ptr)                :: p !< Pointer.

   p = cl_ptr_add(base, o)
   endfunction ptr

   function slice(b, e) result(s)
   !< The fragment's bytes [b, e) as a string.
   integer(c_int), intent(in)    :: b, e !< Offsets.
   character(len=:), allocatable :: s    !< Text.
   integer(c_int)                :: k    !< Counter.

   allocate(character(len=max(e - b, 0_c_int)) :: s)
   do k = b, e - 1_c_int
      s(k - b + 1_c_int:k - b + 1_c_int) = frag(k + 1_c_int)
   enddo
   endfunction slice

   pure function is_blank(c) result(yes)
   !< A blank: space, tab, LF, CR.
   character(kind=c_char), intent(in) :: c   !< Byte.
   logical                            :: yes !< Blank.

   yes = c == ' ' .or. c == achar(9) .or. c == achar(10) .or. c == achar(13)
   endfunction is_blank

   function attribute(a) result(s)
   !< An md4c attribute's text.
   type(md_attribute), intent(in) :: a !< Attribute.
   character(len=:), allocatable  :: s !< Text.
   character(kind=c_char), pointer :: t(:) !< Its bytes.
   integer(c_int)                  :: k    !< Counter.

   allocate(character(len=max(a%size, 0_c_int)) :: s)
   if (a%size <= 0_c_int .or. .not. c_associated(a%text)) return
   call c_f_pointer(a%text, t, [a%size])
   do k = 1_c_int, a%size
      s(k:k) = t(k)
   enddo
   endfunction attribute

   function strncmp_eq(b, e, lit) result(yes)
   !< C's `strncmp(str, lit, e - b) == 0` for the fragment's bytes [b, e) (not NUL-terminated): equal when they are a
   !< prefix of `lit` (or `lit` itself).
   integer(c_int),   intent(in) :: b, e !< Offsets.
   character(len=*), intent(in) :: lit  !< Literal.
   logical                      :: yes  !< Equal.
   integer(c_int)               :: n, k !< Bytes, counter.

   n = e - b
   yes = n <= len(lit, c_int)
   if (.not. yes) return
   do k = 0_c_int, n - 1_c_int
      if (at(b + k) /= lit(k + 1:k + 1)) then
         yes = .false.
         return
      endif
   enddo
   endfunction strncmp_eq

   function starts_with(b, e, prefix) result(yes)
   !< The fragment's bytes [b, e) start with `prefix`.
   integer(c_int),   intent(in) :: b, e   !< Offsets.
   character(len=*), intent(in) :: prefix !< Prefix.
   logical                      :: yes    !< Starts with it.
   integer(c_int)               :: k      !< Counter.

   yes = e - b >= len(prefix, c_int)
   if (.not. yes) return
   do k = 0_c_int, len(prefix, c_int) - 1_c_int
      if (at(b + k) /= prefix(k + 1:k + 1)) then
         yes = .false.
         return
      endif
   enddo
   endfunction starts_with

   function style_color(idx) result(rgba)
   !< `GetStyle().Colors[idx]`.
   integer(c_int), intent(in) :: idx     !< `ImGuiCol_*`.
   real(c_float)              :: rgba(4) !< Colour.

   call cl_style_color(idx, rgba)
   endfunction style_color

   function style_value(k) result(v)
   !< A value of the style (figure_core_layout's `cl_style`).
   integer(c_int), intent(in) :: k !< Its index.
   real(c_float)              :: v !< Value.
   real(c_float)              :: s(12) !< Values.

   call cl_style(s)
   v = s(k)
   endfunction style_value

   subroutine end_line()
   !< Ends the open line, if any (imgui_rich_md's `end_line`).
   if (cl_line_open()) call cl_new_line()
   endsubroutine end_line

   subroutine add_block_gap(gap_em)
   !< A gap between blocks, below the open line (a zero gap only ends the line).
   real(c_float), intent(in) :: gap_em !< Gap [em].

   call end_line()
   if (gap_em > 0.0_c_float) call cl_dummy(0.0_c_float, cl_font_size() * gap_em)
   endsubroutine add_block_gap

   function separate_block() result(added)
   !< The gap above a top-level block, except above the first one.
   logical :: added !< Added.

   if (skip_next_block_gap) then
      skip_next_block_gap = .false.
      added = .false.
      return
   endif
   call add_block_gap(BLOCK_GAP)
   added = .true.
   endfunction separate_block

   function hidden() result(yes)
   !< Inside a collapsed `<details>`.
   logical        :: yes !< Hidden.
   integer(c_int) :: k   !< Counter.

   yes = .false.
   do k = 1_c_int, ndetails
      if (.not. details_open(k)) yes = .true.
   enddo
   endfunction hidden

   function top_level() result(yes)
   !< Outside lists, quotes and `<details>`.
   logical :: yes !< At the top level.

   yes = container_depth == 0_c_int .and. ndetails == 0_c_int
   endfunction top_level

   ! ---- fonts and colours -------------------------------------------------------------------------------------------
   subroutine get_font(font, size)
   !< MarkdownRenderer's `get_font`: the code font, or the text's by its emphasis and heading level.
   type(c_ptr),   intent(out) :: font !< C `ImFont*`.
   real(c_float), intent(out) :: size !< Size.
   logical                    :: bold, italic !< Emphasis.
   integer(c_int)             :: k    !< Font.

   if (is_code) then
      font = fonts(5)
      size = REGULAR_SIZE * font_scale
      return
   endif
   bold = is_strong .or. is_table_header
   italic = is_em
   k = 1_c_int
   if (bold .and. .not. italic) k = 2_c_int
   if (italic .and. .not. bold) k = 3_c_int
   if (bold .and. italic) k = 4_c_int
   font = fonts(k)
   if (hlevel <= 0_c_int) then
      size = REGULAR_SIZE * font_scale
   else
      size = REGULAR_SIZE * HEADER_FACTORS(min(hlevel, 6_c_int))
      size = size * font_scale
   endif
   endsubroutine get_font

   function get_font_size() result(size)
   !< `get_font().size`.
   real(c_float) :: size !< Size.
   type(c_ptr)   :: font !< Font.

   call get_font(font, size)
   endfunction get_font_size

   subroutine set_font(e)
   !< Push the font of the state (enter), or pop it.
   logical, intent(in) :: e    !< Enter.
   type(c_ptr)         :: font !< Font.
   real(c_float)       :: size !< Size.

   if (e) then
      call get_font(font, size)
      call cl_push_font(font, size)
   else
      call cl_pop_font()
   endif
   endsubroutine set_font

   function link_color() result(rgba)
   !< The automatic link colour: the text colour shifted to blue (`default_link_color`).
   real(c_float) :: rgba(4) !< Colour.
   real(c_float) :: h, s, v !< HSV.

   rgba = style_color(ImGuiCol_Text)
   call cl_rgb_to_hsv(rgba(1), rgba(2), rgba(3), h, s, v)
   h = 0.57_c_float
   if (v >= 0.8_c_float) v = 0.8_c_float
   if (v <= 0.5_c_float) v = 0.5_c_float
   if (s <= 0.5_c_float) s = 0.5_c_float
   call cl_hsv_to_rgb(h, s, v, rgba(1), rgba(2), rgba(3))
   endfunction link_color

   subroutine set_color(e)
   !< Push the text colour of the state (a link's, or the text's), or pop it.
   logical, intent(in) :: e !< Enter.

   if (e) then
      if (len(href) > 0) then
         call cl_push_style_color(ImGuiCol_Text, link_color())
      else
         call cl_push_style_color(ImGuiCol_Text, style_color(ImGuiCol_Text))
      endif
   else
      call cl_pop_style_color()
   endif
   endsubroutine set_color

   function admonition_color(kind) result(rgba)
   !< An admonition's colour (its label and its bar); a plain quote's: the disabled text's.
   integer(c_int), intent(in) :: kind    !< Kind.
   real(c_float)              :: rgba(4) !< Colour.

   if (kind == ADMON_NONE) then
      rgba = style_color(ImGuiCol_TextDisabled)
   else
      rgba = ADMONITION_COLORS(:, kind)
   endif
   endfunction admonition_color

   subroutine line(rgba, under)
   !< A line under the last item (or through it).
   real(c_float), intent(in) :: rgba(4) !< Colour.
   logical,       intent(in) :: under   !< Under (else through, at half the font size).
   real(c_float)             :: x0, y0, x1, y1 !< The item.

   call cl_item_rect_min(x0, y0)
   call cl_item_rect_max(x1, y1)
   if (.not. under) y1 = y1 - cl_font_size() / 2.0_c_float
   y0 = y1
   call cl_draw_line(x0, y0, x1, y1, cl_float4_to_u32(rgba), cl_font_size() / 14.5_c_float)
   endsubroutine line

   function link_item(url) result(clicked)
   !< The last item decorated as a link (underline, hand cursor, the URL as a tooltip): true when it was clicked (a
   !< release where it was pressed, without a drag).
   character(len=*), intent(in), target :: url     !< URL.
   logical                              :: clicked !< Clicked.
   real(c_float)                        :: underline(4) !< Its colour.

   clicked = .false.
   if (cl_item_hovered(ImGuiHoveredFlags_AllowWhenBlockedByActiveItem)) then
      call cl_set_mouse_cursor(ImGuiMouseCursor_Hand)
      if (cl_item_hovered(ImGuiHoveredFlags_DelayNormal)) then
         if (len(url) > 0) then
            call cl_tooltip(c_loc(url), len(url, c_int))
         else
            call cl_tooltip(c_loc(nul), 0_c_int)
         endif
      endif
      underline = style_color(ImGuiCol_ButtonHovered)
      clicked = cl_mouse_released(0_c_int) .and. .not. cl_mouse_drag_past(0_c_int)
   else
      underline = style_color(ImGuiCol_Button)
   endif
   call line(underline, .true.)
   endfunction link_item

   ! ---- links and anchors -------------------------------------------------------------------------------------------
   subroutine open_url()
   !< A link's URL reported (FIGURE's `on_link`).
   link = href
   link_clicked = .true.
   endsubroutine open_url

   subroutine follow_link()
   !< A click on a link: an anchor (`#slug`) waits for the end of the fragment, where its heading is known.
   if (len(href) > 1) then
      if (href(1:1) == '#') then
         anchor_slug = href(2:)
         anchor_frames = 8_c_int
         anchor_fragment = fragment_id
         return
      endif
   endif
   call open_url()
   endsubroutine follow_link

   subroutine resolve_anchor(fragment)
   !< The anchor clicked in this fragment: scrolled to (a heading the fragment lacks is reported as a link).
   integer(c_int), intent(in)    :: fragment !< The fragment's ID.
   character(len=:), allocatable :: slug     !< The anchor.
   integer(c_int)                :: status   !< Reached (1), waiting (0), not found (-1).

   if (len(anchor_slug) == 0 .or. anchor_fragment /= fragment) return
   slug = anchor_slug
   status = reach_anchor()
   if (status < 0_c_int) then
      href = '#'//slug
      call open_url()
      href = ''
   endif
   endsubroutine resolve_anchor

   function find_anchor_heading() result(i)
   !< The heading of the anchor (`FindAnchorHeading`): its index (from 1), 0 while a section that hides it opens, -1
   !< when no heading has the anchor's slug.
   integer(c_int) :: i !< Heading.

   do i = 1_c_int, nheadings
      if (slug_pool(headings(i)%slug_b + 1:headings(i)%slug_b + headings(i)%slug_n) == anchor_slug) exit
   enddo
   if (i > nheadings) then
      i = -1_c_int
      return
   endif
   if (headings(i)%hidden) then
      anchor_frames = anchor_frames - 1_c_int
      if (anchor_frames > 0_c_int) then
         call cl_storage_set_int(headings(i)%details, 1_c_int) ! the section opens at the next frame
         i = 0_c_int
      endif
   endif
   endfunction find_anchor_heading

   function reach_anchor() result(status)
   !< One frame of the way to the anchor (`ResolveAnchor`): 1 reached, 0 waiting, -1 not found.
   integer(c_int) :: status !< Status.
   integer(c_int) :: i      !< Heading.

   i = find_anchor_heading()
   if (i < 0_c_int) then
      anchor_slug = ''
      status = -1_c_int
      return
   endif
   status = 0_c_int
   if (i == 0_c_int) return
   if (correct_scroll(scroll_to_show_at_top(headings(i)%y), anchor_frames)) then
      anchor_slug = ''
      status = 1_c_int
   endif
   endfunction reach_anchor

   function scroll_to_show_at_top(y) result(scroll)
   !< The scroll of the current window that shows its content's y at its top (`ScrollToShowAtTop`).
   real(c_float), intent(in) :: y      !< Content ordinate.
   real(c_float)             :: scroll !< Scroll.
   real(c_float)             :: s(14)  !< The window.

   call cl_window_state(s)
   scroll = y - s(7)
   scroll = scroll - s(8)
   scroll = real(int(scroll), c_float)
   if (scroll < 0.0_c_float) then
      scroll = 0.0_c_float
   elseif (scroll > s(6)) then
      scroll = s(6)
   endif
   endfunction scroll_to_show_at_top

   function correct_scroll(scroll, frames) result(holds)
   !< One frame of the correction of a scroll (`CorrectScroll`): true when it holds or the frames ran out.
   real(c_float),  intent(in)    :: scroll !< The scroll wanted.
   integer(c_int), intent(inout) :: frames !< Frames left.
   logical                       :: holds  !< Over.

   holds = .true.
   if (abs(cl_scroll_y() - scroll) <= 1.0_c_float) return
   frames = frames - 1_c_int
   if (frames <= 0_c_int) return
   call cl_set_scroll_y(scroll)
   holds = .false.
   endfunction correct_scroll

   ! ---- headings ----------------------------------------------------------------------------------------------------
   subroutine add_heading(level, y, is_hidden)
   !< A heading of the fragment, its slug unique in it.
   integer(c_int), intent(in)    :: level     !< Level.
   real(c_float),  intent(in)    :: y         !< Its top.
   logical,        intent(in)    :: is_hidden !< Hidden by a collapsed section.
   character(len=:), allocatable :: slug      !< Its slug.
   type(md_heading), allocatable :: more(:)   !< Grown list.
   integer(c_int)                :: k         !< Counter.

   slug = unique_slug(heading_text)
   if (.not. allocated(headings)) allocate(headings(16))
   if (nheadings == size(headings, kind=c_int)) then
      allocate(more(2 * nheadings))
      do k = 1_c_int, nheadings
         more(k) = headings(k)
      enddo
      call move_alloc(more, headings)
   endif
   nheadings = nheadings + 1_c_int
   headings(nheadings)%level = level
   headings(nheadings)%y = y
   headings(nheadings)%hidden = is_hidden
   headings(nheadings)%details = merge(hidden_id, 0_c_int, is_hidden)
   call pool_add(slug_pool, nslug_pool, slug, headings(nheadings)%slug_b, headings(nheadings)%slug_n)
   endsubroutine add_heading

   function heading_slug(text) result(slug)
   !< A heading's anchor as GitHub makes it: lower case, the blanks as `-`, the ASCII punctuation dropped but `-`, `_`.
   character(len=*), intent(in)  :: text !< The heading's text.
   character(len=:), allocatable :: slug !< Slug.
   integer                       :: k, c !< Counter, byte.
   character(len=1)              :: ch   !< A byte (nvfortran 26.9: `s//achar(i)` takes i as the length).

   slug = ''
   do k = 1, len(text)
      c = iachar(text(k:k))
      if (c >= 128 .or. (c >= iachar('a') .and. c <= iachar('z')) .or. (c >= iachar('0') .and. c <= iachar('9')) &
          .or. text(k:k) == '-' .or. text(k:k) == '_') then
         slug = slug//text(k:k)
      elseif (c >= iachar('A') .and. c <= iachar('Z')) then
         ch = achar(c - iachar('A') + iachar('a'))
         slug = slug//ch
      elseif (text(k:k) == ' ') then
         slug = slug//'-'
      endif
   enddo
   endfunction heading_slug

   function unique_slug(text) result(slug)
   !< A slug unique among those given so far in the fragment: a repeated one gets `-1`, `-2`, ... (`UniqueSlug`).
   character(len=*), intent(in)  :: text !< The heading's text.
   character(len=:), allocatable :: slug !< Slug.
   character(len=:), allocatable :: root !< The slug of the text.
   character(len=16)             :: num  !< A number.
   integer(c_int)                :: kb   !< The root's entry.

   root = heading_slug(text)
   slug = root
   do while (occ_find(slug) > 0_c_int)
      kb = occ_find(root)
      if (kb == 0_c_int) kb = occ_add(root)
      occ_count(kb) = occ_count(kb) + 1_c_int
      write(num, '(I0)') occ_count(kb)
      slug = root//'-'//trim(num)
   enddo
   kb = occ_find(slug)
   if (kb == 0_c_int) kb = occ_add(slug)
   occ_count(kb) = 0_c_int
   endfunction unique_slug

   function occ_find(slug) result(k)
   !< The entry of a slug among those given (0: none).
   character(len=*), intent(in) :: slug !< Slug.
   integer(c_int)               :: k    !< Entry.

   do k = 1_c_int, nocc
      if (occ_n(k) == len(slug, c_int)) then
         if (occ_pool(occ_b(k) + 1:occ_b(k) + occ_n(k)) == slug) return
      endif
   enddo
   k = 0_c_int
   endfunction occ_find

   function occ_add(slug) result(k)
   !< A slug given, with a count of 0: its entry.
   character(len=*), intent(in) :: slug !< Slug.
   integer(c_int)               :: k    !< Entry.
   integer(c_int), allocatable  :: more(:) !< Grown arrays.
   integer(c_int)               :: n    !< Pool bytes.

   if (.not. allocated(occ_count)) then
      allocate(occ_count(16), occ_b(16), occ_n(16))
      occ_pool = ''
   endif
   if (nocc == size(occ_count, kind=c_int)) then
      allocate(more(2 * nocc))
      more(1:nocc) = occ_count(1:nocc)
      call move_alloc(more, occ_count)
      allocate(more(2 * nocc))
      more(1:nocc) = occ_b(1:nocc)
      call move_alloc(more, occ_b)
      allocate(more(2 * nocc))
      more(1:nocc) = occ_n(1:nocc)
      call move_alloc(more, occ_n)
   endif
   if (nocc == 0_c_int) occ_pool = ''
   n = len(occ_pool, c_int)
   occ_pool = occ_pool//slug
   nocc = nocc + 1_c_int
   k = nocc
   occ_b(k) = n
   occ_n(k) = len(slug, c_int)
   occ_count(k) = 0_c_int
   endfunction occ_add

   subroutine pool_add(pool, n, s, b, l)
   !< A string appended to a pool of strings: its place.
   character(len=:), allocatable, intent(inout) :: pool !< Pool.
   integer(c_int),                intent(inout) :: n    !< Bytes used.
   character(len=*),              intent(in)    :: s    !< String.
   integer(c_int),                intent(out)   :: b, l !< Its offset (0-based), bytes.
   character(len=:), allocatable                :: more !< Grown pool.

   if (.not. allocated(pool)) allocate(character(len=256) :: pool)
   if (n + len(s, c_int) > len(pool, c_int)) then
      allocate(character(len=2 * (n + len(s, c_int))) :: more)
      more(1:n) = pool(1:n)
      call move_alloc(more, pool)
   endif
   b = n
   l = len(s, c_int)
   pool(n + 1:n + l) = s
   n = n + l
   endsubroutine pool_add

   ! ---- blocks ------------------------------------------------------------------------------------------------------
   subroutine block(type, d, e)
   !< md4c's block callback (`Renderer::block`): the gaps between blocks, then the block's own work.
   integer(c_int), intent(in) :: type !< `MD_BLOCKTYPE`.
   type(c_ptr),    intent(in) :: d    !< Its detail.
   logical,        intent(in) :: e    !< Enter.
   type(md_block_h_detail), pointer :: h !< A heading's detail.
   logical                    :: eligible, gap !< A gap above it.
   integer(c_int)             :: steps !< A heading's extra gap.
   real(c_float)              :: x, y  !< The last item.

   html_gap_pending = .false.
   if (type == MD_BLOCK_QUOTE .or. type == MD_BLOCK_LI) container_depth = container_depth + merge(1_c_int, -1_c_int, e)
   if (e) then
      select case (type)
      case (MD_BLOCK_P, MD_BLOCK_H, MD_BLOCK_QUOTE, MD_BLOCK_HR, MD_BLOCK_CODE, MD_BLOCK_HTML, MD_BLOCK_TABLE, &
            MD_BLOCK_UL, MD_BLOCK_OL)
         if (container_depth == merge(1_c_int, 0_c_int, type == MD_BLOCK_QUOTE)) top_block_count = top_block_count + 1_c_int
      endselect
   endif
   if (hidden()) then
      if (type == MD_BLOCK_H) then ! a heading inside a collapsed section: listed, at the section's header
         call c_f_pointer(d, h)
         if (e) then
            hlevel = h%level
            heading_text = ''
         else
            call add_heading(h%level, hidden_y, .true.)
            hlevel = 0_c_int
         endif
      endif
      return
   endif
   if (e) block_number = block_number + 1_c_int
   if (e) then
      eligible = .false.
      select case (type)
      case (MD_BLOCK_P, MD_BLOCK_H, MD_BLOCK_QUOTE, MD_BLOCK_HR, MD_BLOCK_CODE, MD_BLOCK_HTML, MD_BLOCK_TABLE, &
            MD_BLOCK_UL, MD_BLOCK_OL)
         eligible = nlist == 0_c_int
      endselect
      if (eligible) then
         if (type == MD_BLOCK_HTML) then
            html_gap_pending = .true.
         else
            gap = separate_block()
            if (gap .and. type == MD_BLOCK_H) then
               call c_f_pointer(d, h)
               steps = 7_c_int - h%level
               if (steps > 0_c_int) call cl_dummy(0.0_c_float, cl_font_size() * HEADER_GAP_STEP * real(steps, c_float))
            endif
         endif
      endif
   endif
   if (e .and. nlist > 0_c_int) then
      select case (type)
      case (MD_BLOCK_P, MD_BLOCK_H, MD_BLOCK_QUOTE, MD_BLOCK_HR, MD_BLOCK_CODE, MD_BLOCK_TABLE)
         call cl_item_rect_min(x, y)
         if (x /= list_block_mark(1) .or. y /= list_block_mark(2)) call add_block_gap(BLOCK_GAP)
         call cl_item_rect_min(list_block_mark(1), list_block_mark(2))
      endselect
   endif
   select case (type)
   case (MD_BLOCK_DOC, MD_BLOCK_HTML, MD_BLOCK_P)
   case (MD_BLOCK_QUOTE)
      call block_quote(e)
   case (MD_BLOCK_UL)
      call block_ul(d, e)
   case (MD_BLOCK_OL)
      call block_ol(d, e)
   case (MD_BLOCK_LI)
      call block_li(d, e)
   case (MD_BLOCK_HR)
      if (.not. e) call cl_separator()
   case (MD_BLOCK_H)
      call block_h(d, e)
   case (MD_BLOCK_CODE)
      call block_code(d, e)
   case (MD_BLOCK_TABLE)
      call block_table(d, e)
   case (MD_BLOCK_THEAD)
      is_table_header = e
      call set_font(e)
   case (MD_BLOCK_TBODY)
      is_table_body = e
   case (MD_BLOCK_TR)
      if (table_open .and. e) call cl_table_next_row()
   case (MD_BLOCK_TH, MD_BLOCK_TD)
      call block_td(d, e)
   endselect
   endsubroutine block

   subroutine block_ul(d, e)
   !< A bullet list.
   type(c_ptr), intent(in) :: d !< Detail.
   logical,     intent(in) :: e !< Enter.
   type(md_block_ul_detail), pointer :: ul !< Detail.

   if (e) then
      call c_f_pointer(d, ul)
      call list_push(0_c_int, ul%mark, .false.)
   else
      nlist = nlist - 1_c_int
   endif
   endsubroutine block_ul

   subroutine block_ol(d, e)
   !< An ordered list.
   type(c_ptr), intent(in) :: d !< Detail.
   logical,     intent(in) :: e !< Enter.
   type(md_block_ol_detail), pointer :: ol !< Detail.

   if (e) then
      call c_f_pointer(d, ol)
      call list_push(ol%start, ol%mark_delimiter, .true.)
   else
      nlist = nlist - 1_c_int
   endif
   endsubroutine block_ol

   subroutine list_push(start, delim, is_ol)
   !< A list opened.
   integer(c_int),         intent(in) :: start !< First number.
   character(kind=c_char), intent(in) :: delim !< Mark or delimiter.
   logical,                intent(in) :: is_ol !< Ordered.
   type(list_info), allocatable       :: more(:) !< Grown stack.
   integer(c_int)                     :: k     !< Counter.

   if (.not. allocated(list_stack)) allocate(list_stack(8))
   if (nlist == size(list_stack, kind=c_int)) then
      allocate(more(2 * nlist))
      do k = 1_c_int, nlist
         more(k) = list_stack(k)
      enddo
      call move_alloc(more, list_stack)
   endif
   nlist = nlist + 1_c_int
   list_stack(nlist)%cur_ol = start
   list_stack(nlist)%delim = delim
   list_stack(nlist)%is_ol = is_ol
   list_stack(nlist)%first_item_pending = .true.
   endsubroutine list_push

   subroutine block_li(d, e)
   !< A list item: its marker (a task's box, a number, a bullet), then its content indented.
   type(c_ptr), intent(in) :: d !< Detail.
   logical,     intent(in) :: e !< Enter.
   type(md_block_li_detail), pointer :: li    !< Detail.
   logical                           :: is_first, is_top !< The first item of a top-level list.
   real(c_float)                     :: cx, cy !< Cursor.
   character(len=24)                 :: num   !< A number.

   if (.not. e) then
      call cl_unindent()
      return
   endif
   is_first = list_stack(nlist)%first_item_pending
   list_stack(nlist)%first_item_pending = .false.
   is_top = nlist == 1_c_int
   if (.not. (is_first .and. is_top)) call add_block_gap(LIST_ITEM_GAP)
   li => null()
   if (c_associated(d)) call c_f_pointer(d, li)
   if (associated(li)) then
      if (li%is_task /= 0_c_int) then
         call render_task_marker(li%task_mark == 'x' .or. li%task_mark == 'X')
         call cl_same_line()
         if (list_stack(nlist)%is_ol) list_stack(nlist)%cur_ol = list_stack(nlist)%cur_ol + 1_c_int
         call cl_item_rect_min(list_block_mark(1), list_block_mark(2))
         call cl_indent()
         return
      endif
   endif
   if (list_stack(nlist)%is_ol) then
      write(num, '(I0)') list_stack(nlist)%cur_ol
      list_stack(nlist)%cur_ol = list_stack(nlist)%cur_ol + 1_c_int
      call cl_text_str(trim(num)//list_stack(nlist)%delim)
      call cl_same_line()
   elseif (list_stack(nlist)%delim == '*') then
      call cl_cursor_pos(cx, cy)
      cx = cx - style_value(1_c_int) * 2.0_c_float
      call cl_set_cursor_pos_x(cx)
      call cl_bullet()
   else
      call cl_text_str(list_stack(nlist)%delim)
      call cl_same_line()
   endif
   call cl_item_rect_min(list_block_mark(1), list_block_mark(2))
   call cl_indent()
   endsubroutine block_li

   subroutine render_task_marker(checked)
   !< A task's box, with a check mark when done.
   logical, intent(in) :: checked !< Done.
   real(c_float)       :: h, sz, cx, cy, y_center, tl(2), br(2), rounding, thickness, pad, a(2), b(2), c(2), check_thick
   integer(c_int)      :: border, mark !< Colours.

   h = cl_font_size()
   sz = h * 0.75_c_float
   call cl_cursor_screen_pos(cx, cy)
   y_center = cy + h * 0.5_c_float
   tl = [cx, y_center - sz * 0.5_c_float]
   br = [cx + sz, y_center + sz * 0.5_c_float]
   border = cl_color_u32(ImGuiCol_Text)
   rounding = sz * 0.15_c_float
   thickness = 1.0_c_float
   if (sz / 12.0_c_float > 1.0_c_float) thickness = sz / 12.0_c_float
   call cl_draw_rect(tl(1), tl(2), br(1), br(2), border, rounding, thickness)
   if (checked) then
      mark = cl_color_u32(ImGuiCol_CheckMark)
      pad = sz * 0.22_c_float
      a = [tl(1) + pad, tl(2) + sz * 0.55_c_float]
      b = [tl(1) + sz * 0.45_c_float, br(2) - pad]
      c = [br(1) - pad, tl(2) + pad]
      check_thick = 1.5_c_float
      if (sz / 8.0_c_float > 1.5_c_float) check_thick = sz / 8.0_c_float
      call cl_draw_line(a(1), a(2), b(1), b(2), mark, check_thick)
      call cl_draw_line(b(1), b(2), c(1), c(2), mark, check_thick)
   endif
   call cl_dummy(sz, h)
   endsubroutine render_task_marker

   subroutine block_h(d, e)
   !< A heading: its font, its underline (levels 1 and 2), its slug.
   type(c_ptr), intent(in) :: d !< Detail.
   logical,     intent(in) :: e !< Enter.
   type(md_block_h_detail), pointer :: h   !< Detail.
   real(c_float)                    :: top, x, y !< Its top, the cursor.

   call c_f_pointer(d, h)
   if (e) then
      hlevel = h%level
      heading_text = ''
      heading_top = -1.0_c_float
   else
      hlevel = 0_c_int
   endif
   call set_font(e)
   if (e) return
   if (heading_top >= 0.0_c_float) then
      top = heading_top
   else
      call cl_cursor_pos(x, y)
      top = y
   endif
   if (h%level <= 2_c_int) then
      call end_line()
      call cl_separator()
   endif
   call add_heading(h%level, top, .false.)
   endsubroutine block_h

   subroutine block_quote(e)
   !< A quote: indented, its bar drawn at its end (an admonition's in its colour).
   logical, intent(in) :: e !< Enter.
   real(c_float), allocatable :: more(:,:)   !< Grown stack.
   real(c_float)              :: x, y, start_y, indented_x, end_y, bar_x, thickness, bar(4) !< The bar.

   if (e) then
      quote_depth = quote_depth + 1_c_int
      call cl_indent()
      if (nlist == 0_c_int) skip_next_block_gap = .true.
      if (.not. allocated(quote_start)) allocate(quote_start(2, 8))
      if (quote_depth > size(quote_start, 2)) then
         allocate(more(2, 2 * size(quote_start, 2)))
         more(:, 1:size(quote_start, 2)) = quote_start
         call move_alloc(more, quote_start)
      endif
      call cl_cursor_screen_pos(x, y)
      quote_start(:, quote_depth) = [x, y]
      admonition_scan_pending = .true.
      admonition_kind = ADMON_NONE
   else
      start_y = quote_start(2, quote_depth)
      indented_x = quote_start(1, quote_depth)
      call cl_item_rect_max(x, end_y)
      bar_x = indented_x - style_value(3_c_int) * 0.5_c_float
      if (admonition_kind /= ADMON_NONE) then
         thickness = ADMONITION_BAR_THICKNESS
         bar = admonition_color(admonition_kind)
      else
         thickness = QUOTE_BAR_THICKNESS
         bar = style_color(ImGuiCol_TextDisabled)
      endif
      call cl_draw_line(bar_x, start_y, bar_x, end_y, cl_float4_to_u32(bar), thickness)
      call cl_unindent()
      quote_depth = quote_depth - 1_c_int
      admonition_kind = ADMON_NONE
      admonition_scan_pending = .false.
      admonition_skip_next_softbr = .false.
   endif
   endsubroutine block_quote

   function match_admonition_marker(b, e, marker_end) result(kind)
   !< A `[!NOTE]` ... `[!CAUTION]` marker (any case) at the start of [b, e): its kind, and the byte after its `]`.
   integer(c_int), intent(in)  :: b, e       !< Offsets.
   integer(c_int), intent(out) :: marker_end !< After the marker.
   integer(c_int)              :: kind       !< Kind (0: none).
   integer(c_int)              :: close, k, j !< The `]`, counters.
   character(len=:), allocatable :: name     !< The marker's name, upper case.
   integer                     :: c          !< Byte.

   kind = ADMON_NONE
   marker_end = b
   if (e - b < 4_c_int) return
   if (at(b) /= '[' .or. at(b + 1_c_int) /= '!') return
   close = b + 2_c_int
   do while (close < e)
      if (at(close) == ']') exit
      close = close + 1_c_int
   enddo
   if (close >= e) return
   allocate(character(len=close - b - 2_c_int) :: name)
   do k = b + 2_c_int, close - 1_c_int
      c = iachar(at(k))
      if (c >= iachar('a') .and. c <= iachar('z')) c = c - iachar('a') + iachar('A')
      name(k - b - 1_c_int:k - b - 1_c_int) = achar(c)
   enddo
   do j = 1, 5
      if (name == admonition_label(int(j, c_int))) kind = int(j, c_int)
   enddo
   if (kind /= ADMON_NONE) marker_end = close + 1_c_int
   endfunction match_admonition_marker

   pure function admonition_label(kind) result(label)
   !< An admonition's label (a function, not a typed character array constructor: nvfortran 26.9's defect, ADR 0001).
   integer(c_int), intent(in)    :: kind  !< Kind, 1 to 5.
   character(len=:), allocatable :: label !< Label.

   select case (kind)
   case (1_c_int)
      label = 'NOTE'
   case (2_c_int)
      label = 'TIP'
   case (3_c_int)
      label = 'IMPORTANT'
   case (4_c_int)
      label = 'WARNING'
   case default
      label = 'CAUTION'
   endselect
   endfunction admonition_label

   subroutine render_admonition_header(kind)
   !< An admonition's label, bold, in its colour.
   integer(c_int), intent(in) :: kind  !< Kind.
   logical                    :: saved !< Strong before.

   call cl_push_style_color(ImGuiCol_Text, admonition_color(kind))
   saved = is_strong
   is_strong = .true.
   call set_font(.true.)
   call cl_text_str(admonition_label(kind))
   call set_font(.false.)
   is_strong = saved
   call cl_pop_style_color()
   endsubroutine render_admonition_header

   subroutine block_code(d, e)
   !< A code block: its text gathered, then drawn at its end.
   type(c_ptr), intent(in) :: d !< Detail.
   logical,     intent(in) :: e !< Enter.
   type(md_block_code_detail), pointer :: cd !< Detail.

   is_code_block = e
   if (e) then
      code_block = ''
   else
      call end_line()
      call render_code_block()
   endif
   call c_f_pointer(d, cd)
   code_block_language = attribute(cd%lang)
   endsubroutine block_code

   subroutine render_code_block()
   !< MarkdownRenderer's `render_code_block` and `_RenderCodeBlockPlain`: the code without its last line when blank,
   !< in a frame (a child window of the frame's colour) with a Copy button, in the code font.
   character(len=:), allocatable, target :: code !< The code shown.
   integer(c_int)                        :: k, last !< Counters.
   real(c_float)                         :: copy_width, cx, cy, ax, ay !< Layout.
   logical                               :: blank !< The last line is blank.

   code = code_block
   last = 0_c_int ! the start of the last line
   do k = len(code, c_int), 1_c_int, -1_c_int
      if (code(k:k) == achar(10)) then
         last = k
         exit
      endif
   enddo
   blank = .true.
   do k = last + 1_c_int, len(code, c_int)
      if (index(' '//achar(9)//achar(13)//achar(10)//achar(12)//achar(11), code(k:k)) == 0) blank = .false.
   enddo
   if (blank) then
      if (last > 0_c_int) then
         code = code(1:last - 1_c_int)
      else
         code = ''
      endif
   endif
   if (len(code_block) > 0) then
      call cl_push_id(c_loc(code_block), len(code_block, c_int))
   else
      call cl_push_id(c_loc(nul), 0_c_int) ! PushID(""): a NUL where the text ends
   endif
   call cl_push_style_color(ImGuiCol_ChildBg, style_color(ImGuiCol_FrameBg))
   if (cl_begin_child('code', 0.0_c_float, 0.0_c_float, &
                      ior(ImGuiChildFlags_AutoResizeY, ImGuiChildFlags_AlwaysUseWindowPadding), 0_c_int)) then
      copy_width = cl_text_width_str('Copy') + style_value(1_c_int) * 2.0_c_float
      call cl_cursor_pos(cx, cy)
      call cl_content_avail(ax, ay)
      call cl_set_cursor_pos_x(cx + ax - copy_width)
      if (cl_small_button('Copy')) then
         if (len(code) > 0) then
            call cl_set_clipboard(c_loc(code), len(code, c_int))
         else
            call cl_set_clipboard(c_loc(nul), 0_c_int)
         endif
      endif
      call cl_set_cursor_pos_x(style_value(6_c_int))
      call cl_push_font(fonts(5), REGULAR_SIZE * font_scale)
      if (len(code) > 0) then
         call cl_text(c_loc(code), len(code, c_int))
      else
         call cl_text_str('')
      endif
      call cl_pop_font()
   endif
   call cl_end_child()
   call cl_pop_style_color()
   call cl_pop_id()
   endsubroutine render_code_block

   subroutine block_table(d, e)
   !< A table: Dear ImGui's, resizable, with borders, in its own ID scope.
   type(c_ptr), intent(in) :: d !< Detail.
   logical,     intent(in) :: e !< Enter.
   type(md_block_table_detail), pointer :: t !< Detail.
   integer(c_int)                       :: flags !< Its flags.

   if (e) then
      call c_f_pointer(d, t)
      call cl_push_id_int(table_id_counter)
      table_id_counter = table_id_counter + 1_c_int
      flags = ior(ImGuiTableFlags_SizingStretchProp, ImGuiTableFlags_Resizable)
      flags = ior(flags, ior(ior(ImGuiTableFlags_BordersInnerV, ImGuiTableFlags_BordersOuterV), &
                             ior(ImGuiTableFlags_BordersOuterH, ImGuiTableFlags_BordersInnerH)))
      table_open = cl_begin_table('##md', t%col_count, flags)
   else
      if (table_open) call cl_end_table()
      table_open = .false.
      call cl_pop_id()
   endif
   endsubroutine block_table

   subroutine block_td(d, e)
   !< A cell: the next column, its content aligned at its end (centre, right: its vertices moved).
   type(c_ptr), intent(in) :: d !< Detail.
   logical,     intent(in) :: e !< Enter.
   type(md_block_td_detail), pointer :: td !< Detail.

   if (.not. table_open) return
   if (e) then
      call c_f_pointer(d, td)
      call cl_table_next_column()
      cell_align = td%align
      call begin_aligned_cell(cell_align, cell_vtx_start, cell_width)
      cell_run_start = nruns
   else
      call shift_runs(cell_run_start, end_aligned_cell(cell_align, cell_vtx_start, cell_width))
      cell_align = MD_ALIGN_DEFAULT
   endif
   endsubroutine block_td

   subroutine begin_aligned_cell(align, vtx_start, width)
   !< A centred or right-aligned content starts: a group, the vertices so far, the room.
   integer(c_int), intent(in)  :: align     !< `MD_ALIGN`.
   integer(c_int), intent(out) :: vtx_start !< Vertices so far.
   real(c_float),  intent(out) :: width     !< Room.
   real(c_float)               :: h         !< Unused.

   if (align == MD_ALIGN_DEFAULT .or. align == MD_ALIGN_LEFT) return
   call cl_content_avail(width, h)
   vtx_start = cl_vtx_count()
   call cl_begin_group()
   endsubroutine begin_aligned_cell

   function end_aligned_cell(align, vtx_start, width) result(offset)
   !< A centred or right-aligned content ends: its vertices moved; the shift.
   integer(c_int), intent(in) :: align     !< `MD_ALIGN`.
   integer(c_int), intent(in) :: vtx_start !< Vertices before it.
   real(c_float),  intent(in) :: width     !< Room.
   real(c_float)              :: offset    !< Shift.
   real(c_float)              :: content_w, h !< Its width.

   offset = 0.0_c_float
   if (align == MD_ALIGN_DEFAULT .or. align == MD_ALIGN_LEFT) return
   call cl_end_group()
   call cl_item_rect_size(content_w, h)
   if (content_w >= width) return
   if (align == MD_ALIGN_CENTER) then
      offset = (width - content_w) * 0.5_c_float
   else
      offset = width - content_w
   endif
   if (offset <= 0.0_c_float) then
      offset = 0.0_c_float
      return
   endif
   call cl_vtx_shift(vtx_start, offset)
   endfunction end_aligned_cell

   subroutine shift_runs(first, dx)
   !< The runs from `first` (0-based) moved right with their content.
   integer(c_int), intent(in) :: first !< First run.
   real(c_float),  intent(in) :: dx    !< Shift.
   integer(c_int)             :: k     !< Counter.

   if (dx == 0.0_c_float) return
   do k = first + 1_c_int, nruns
      runs(k)%x0 = runs(k)%x0 + dx
      runs(k)%x1 = runs(k)%x1 + dx
   enddo
   endsubroutine shift_runs

   ! ---- spans -------------------------------------------------------------------------------------------------------
   subroutine span(type, d, e)
   !< md4c's span callback (`Renderer::span`).
   integer(c_int), intent(in) :: type !< `MD_SPANTYPE`.
   type(c_ptr),    intent(in) :: d    !< Its detail.
   logical,        intent(in) :: e    !< Enter.
   type(md_span_a_detail),   pointer :: a  !< A link's.
   type(md_span_img_detail), pointer :: im !< An image's.

   if (hidden()) return
   if (e .and. admonition_scan_pending) admonition_scan_pending = .false.
   select case (type)
   case (MD_SPAN_EM)
      is_em = e
      call set_font(e)
   case (MD_SPAN_STRONG)
      is_strong = e
      call set_font(e)
   case (MD_SPAN_A)
      call c_f_pointer(d, a)
      if (e) then
         href = attribute(a%href)
      else
         href = ''
      endif
      call set_color(e)
   case (MD_SPAN_IMG)
      call c_f_pointer(d, im)
      call span_img(im, e)
   case (MD_SPAN_CODE)
   case (MD_SPAN_DEL)
      is_strikethrough = e
   case (MD_SPAN_U)
      is_underline = e
   endselect
   endsubroutine span

   subroutine span_img(im, e)
   !< An image: drawn at the text's scale, as wide as the room at most; a click on it follows its link.
   type(md_span_img_detail), intent(in) :: im !< Detail.
   logical,                  intent(in) :: e  !< Enter.
   integer(c_long_long)                 :: tex_id !< Its texture.
   real(c_float)                        :: w, h, scale, ax, ay, r !< Size.

   is_image = e
   if (.not. e) then
      img_src = ''
      return
   endif
   img_src = attribute(im%src)
   if (.not. get_image(tex_id, w, h)) return
   scale = style_value(11_c_int) * style_value(12_c_int)
   w = w * scale
   h = h * scale
   call cl_content_avail(ax, ay)
   if (w > ax) then
      r = h / w
      w = ax
      h = ax * r
   endif
   call cl_image(tex_id, w, h, 0.0_c_float, 0.0_c_float, 1.0_c_float, 1.0_c_float)
   call cl_same_line(0.0_c_float, 0.0_c_float)
   if (cl_item_hovered()) then
      call cl_set_mouse_cursor(ImGuiMouseCursor_Hand)
      if (cl_mouse_clicked(0_c_int)) call follow_link()
   endif
   endsubroutine span_img

   function get_image(tex_id, w, h) result(ready_)
   !< The image at `img_src` (FIGURE's `on_image`, then imgui_rich_md's `OnImage_Default`): none from a URL (any
   !< `scheme://`) nor a network path; a file read once (PNG, JPEG), its texture kept by path; a file that cannot be
   !< read is not read again, and is drawn from its second frame as an empty image (imgui_rich_md's broken image,
   !< which FIGURE does not bundle).
   integer(c_long_long), intent(out) :: tex_id  !< Its texture.
   real(c_float),        intent(out) :: w, h    !< Its size [pixels].
   logical                           :: ready_  !< Drawn.
   type(md_image), allocatable       :: more(:) !< Grown cache.
   type(im_texture_ref)              :: ref     !< A texture's reference.
   integer(c_int)                    :: k, s    !< Counter, status.

   ready_ = .false.
   tex_id = 0_c_long_long
   w = 0.0_c_float
   h = 0.0_c_float
   if (index(img_src, '://') > 0) return
   do k = 1_c_int, nimages
      if (images(k)%path_n /= len(img_src, c_int)) cycle
      if (path_pool(images(k)%path_b + 1:images(k)%path_b + images(k)%path_n) /= img_src) cycle
      ready_ = .true. ! a broken image too, from its second frame: imgui_rich_md's cache gives its empty texture
      if (images(k)%valid) then
         ref = texture_ref(images(k)%tex)
         tex_id = ref%TexID
         w = real(images(k)%tex%width(), c_float)
         h = real(images(k)%tex%height(), c_float)
      endif
      return
   enddo
   if (.not. allocated(images)) allocate(images(8))
   if (nimages == size(images, kind=c_int)) then
      allocate(more(2 * nimages))
      do k = 1_c_int, nimages
         more(k)%path_b = images(k)%path_b
         more(k)%path_n = images(k)%path_n
         more(k)%valid = images(k)%valid
         more(k)%tex = images(k)%tex
      enddo
      call move_alloc(more, images)
   endif
   nimages = nimages + 1_c_int
   call pool_add(path_pool, npath_pool, img_src, images(nimages)%path_b, images(nimages)%path_n)
   images(nimages)%valid = .false.
   if (network_path(img_src)) return
   call images(nimages)%tex%load(img_src, smooth=.true., stat=s)
   images(nimages)%valid = s == FIG_OK
   if (.not. images(nimages)%valid) return
   ready_ = .true.
   ref = texture_ref(images(nimages)%tex)
   tex_id = ref%TexID
   w = real(images(nimages)%tex%width(), c_float)
   h = real(images(nimages)%tex%height(), c_float)
   endfunction get_image

   pure function network_path(path) result(yes)
   !< A path that names a host (`\\host\share`, `//host/share`, `file:`).
   character(len=*), intent(in) :: path !< Path.
   logical                      :: yes  !< A network path.

   yes = .false.
   if (len(path) >= 2) yes = (path(1:1) == '\' .or. path(1:1) == '/') .and. (path(2:2) == '\' .or. path(2:2) == '/')
   if (len(path) >= 5) yes = yes .or. path(1:5) == 'file:'
   endfunction network_path

   ! ---- text --------------------------------------------------------------------------------------------------------
   subroutine on_text(type, b, e)
   !< md4c's text callback (`Renderer::text`): bytes [b, e) of the fragment.
   integer(c_int), intent(in) :: type !< `MD_TEXTTYPE`.
   integer(c_int), intent(in) :: b, e !< Offsets.
   logical                    :: after_comment !< The previous chunk closed a comment.
   integer(c_int)             :: kind, marker_end, s !< An admonition, its end, a start.

   if (hidden() .and. type /= MD_TEXT_HTML) then
      if (hlevel > 0_c_int .and. (type == MD_TEXT_NORMAL .or. type == MD_TEXT_CODE)) heading_text = heading_text//slice(b, e)
      return
   endif
   after_comment = html_comment_closed
   html_comment_closed = .false.
   select case (type)
   case (MD_TEXT_NORMAL)
      if (hlevel > 0_c_int) heading_text = heading_text//slice(b, e)
      if (admonition_scan_pending) then
         admonition_scan_pending = .false.
         kind = match_admonition_marker(b, e, marker_end)
         if (kind /= ADMON_NONE) then
            admonition_kind = kind
            call render_admonition_header(kind)
            admonition_skip_next_softbr = .true.
            s = marker_end
            do while (s < e)
               if (at(s) /= ' ' .and. at(s) /= achar(9)) exit
               s = s + 1_c_int
            enddo
            if (s < e) call render_text(s, e)
            return
         endif
      endif
      call render_text(b, e)
   case (MD_TEXT_CODE)
      if (hlevel > 0_c_int) heading_text = heading_text//slice(b, e)
      if (is_code_block) then
         code_block = code_block//slice(b, e)
      else
         call render_inline_code(b, e)
      endif
   case (MD_TEXT_NULLCHAR)
   case (MD_TEXT_BR)
      call cl_new_line()
      call record_run(-1_c_int, -1_c_int, REPL_LF)
      runs(nruns)%x0 = runs(nruns)%x1
   case (MD_TEXT_SOFTBR)
      if (admonition_skip_next_softbr) then
         admonition_skip_next_softbr = .false.
      else
         call soft_break()
      endif
   case (MD_TEXT_ENTITY)
      if (.not. render_entity(b, e)) call render_text(b, e)
   case (MD_TEXT_HTML)
      if (skip_html_comment(b, e, after_comment)) return
      if (html_gap_pending) then
         html_gap_pending = .false.
         if (separate_block()) continue
      endif
      if (.not. check_html(b, e)) then
         if (details_suppress_next_raw_html) then
            details_suppress_next_raw_html = .false.
         elseif (.not. hidden()) then
            call render_text(b, e)
         endif
      endif
   case (MD_TEXT_LATEXMATH)
      call render_text(b, e)
   endselect
   endsubroutine on_text

   subroutine soft_break()
   !< A soft break: a space, except at the start of a line.
   if (.not. cl_line_open()) return
   call cl_text_str(' ')
   call record_run(-1_c_int, -1_c_int, REPL_SPACE)
   call cl_same_line(0.0_c_float, 0.0_c_float)
   endsubroutine soft_break

   function render_entity(b, e) result(done)
   !< `&nbsp;`: an empty text, then the line kept open with the style's spacing.
   integer(c_int), intent(in) :: b, e !< Offsets.
   logical                    :: done !< Drawn.

   done = strncmp_eq(b, e, '&nbsp;')
   if (.not. done) return
   call cl_text_str('')
   call cl_same_line()
   endfunction render_entity

   subroutine render_inline_code(b, e)
   !< A code span: the code font, the text colour a little more blue.
   integer(c_int), intent(in) :: b, e !< Offsets.

   is_code = .true.
   call push_code_style()
   call render_text(b, e)
   call pop_code_style()
   is_code = .false.
   endsubroutine render_inline_code

   subroutine push_code_style()
   !< The code font and colour.
   type(c_ptr)   :: font    !< Font.
   real(c_float) :: size    !< Size.
   real(c_float) :: rgba(4) !< Colour.

   call get_font(font, size)
   call cl_push_font(font, size)
   rgba = style_color(ImGuiCol_Text)
   rgba(3) = rgba(3) * 1.15_c_float
   call cl_push_style_color(ImGuiCol_Text, rgba)
   endsubroutine push_code_style

   subroutine pop_code_style()
   !< Back from the code font and colour.
   call cl_pop_style_color()
   call cl_pop_font()
   endsubroutine pop_code_style

   function glued_width(e) result(w)
   !< The width of the rest of the word that goes on after e, across the markup (`(**alignment**),` is one word): 0
   !< when the span ends a word. Measured with the current font.
   integer(c_int), intent(in)    :: e    !< Offset.
   real(c_float)                 :: w    !< Width.
   character(len=:), allocatable :: rest !< The rest of the word.
   integer(c_int)                :: s    !< Offset.
   character(kind=c_char)        :: c    !< Byte.

   w = 0.0_c_float
   if (e <= 0_c_int .or. e >= nfrag) return
   if (is_blank(at(e - 1_c_int))) return
   rest = ''
   s = e
   do while (s < nfrag)
      c = at(s)
      if (is_blank(c) .or. c == '<') exit
      if (c == ']' .and. s + 1_c_int < nfrag) then
         if (at(s + 1_c_int) == '(') then
            do while (s < nfrag)
               if (at(s) == ')') exit
               s = s + 1_c_int
            enddo
            s = s + 1_c_int
            cycle
         endif
      endif
      if (c /= '*' .and. c /= '_' .and. c /= '`' .and. c /= '~' .and. c /= '[') rest = rest//c
      s = s + 1_c_int
   enddo
   if (len(rest) > 0) w = cl_text_width_str(rest)
   endfunction glued_width

   subroutine render_text(b0, e)
   !< Text, wrapped word by word in the room left (`Renderer::render_text`): runs drawn and recorded, links,
   !< underline, strikethrough, `<sub>`, `<sup>`, `<kbd>`, `<mark>`, `<md-error>` applied; the line left open.
   integer(c_int), intent(in) :: b0, e !< Offsets.
   integer(c_int)             :: b, te, ws, we, lw !< Offsets.
   logical                    :: is_lf, pushed_small, adjusted_y, mark_split !< State.
   real(c_float)              :: base_font_size, sub_sup_y_offset, size, glued, wl, ah, chunk, small, saved_y !< Sizes.
   real(c_float)              :: cx, cy, x0, y0, x1, y1, err(4) !< Layout.
   type(c_ptr)                :: font !< Font.

   b = b0
   is_lf = .false.
   pushed_small = .false.
   base_font_size = get_font_size()
   sub_sup_y_offset = 0.0_c_float
   if (is_sub .or. is_sup) then
      call get_font(font, size)
      small = size * SUB_SUP_SCALE
      call cl_push_font(font, small)
      pushed_small = .true.
      if (.not. is_sup) sub_sup_y_offset = base_font_size - small
   endif
   size = cl_font_size()
   glued = 0.0_c_float
   if (.not. (is_image .or. is_table_header)) glued = glued_width(e)
   if (.not. is_image .and. .not. is_table_header .and. b < e) then
      call cl_content_avail(wl, ah)
      ws = b
      do while (ws < e)
         if (at(ws) /= ' ' .and. at(ws) /= achar(9)) exit
         ws = ws + 1_c_int
      enddo
      we = ws
      do while (we < e)
         if (at(we) == ' ' .or. at(we) == achar(10) .or. at(we) == achar(9)) exit
         we = we + 1_c_int
      enddo
      if (we > ws) then
         chunk = cl_text_width(ptr(b), we - b)
         if (we == e) chunk = chunk + glued
         if (chunk > wl .and. cl_line_open()) then
            call cl_new_line()
            b = ws
         endif
      endif
   endif
   do while (.not. is_image .and. b < e)
      te = e
      if (.not. is_table_header) then
         call cl_content_avail(wl, ah)
         te = b + cl_word_wrap(size, ptr(b), e - b, wl)
         if (cl_line_open() .and. te > b .and. te < e) then
            if (.not. is_blank(at(te - 1_c_int)) .and. .not. is_blank(at(te))) then
               do while (te > b)
                  if (is_blank(at(te - 1_c_int))) exit
                  te = te - 1_c_int
               enddo
               if (te == b) then
                  call cl_new_line()
                  cycle
               endif
            endif
         endif
         if (te == b) te = te + 1_c_int
         if (te == e .and. glued > 0.0_c_float) then
            if (cl_text_width(ptr(b), te - b) + glued > wl) then
               lw = te
               do while (lw > b)
                  if (is_blank(at(lw - 1_c_int))) exit
                  lw = lw - 1_c_int
               enddo
               if (lw > b) te = lw
            endif
         endif
      endif
      adjusted_y = .false.
      saved_y = 0.0_c_float
      if (sub_sup_y_offset /= 0.0_c_float) then
         call cl_cursor_pos(cx, saved_y)
         call cl_set_cursor_pos_y(saved_y + sub_sup_y_offset)
         adjusted_y = .true.
      endif
      mark_split = is_mark
      if (mark_split) then
         call cl_channels_split(2_c_int)
         call cl_channels_set(1_c_int)
      endif
      if (is_error) then
         err = admonition_color(5_c_int)
         call cl_push_style_color(ImGuiCol_Text, err)
      endif
      call cl_text(ptr(b), te - b)
      call record_run(b, te, REPL_NONE)
      if (is_error) then
         call cl_pop_style_color()
         if (len(error_title) > 0) then
            if (cl_item_hovered()) call tooltip_str(error_title)
         endif
      endif
      if (mark_split) then
         call cl_channels_set(0_c_int)
         call cl_item_rect_min(x0, y0)
         call cl_item_rect_max(x1, y1)
         x0 = x0 - 2.0_c_float
         x1 = x1 + 2.0_c_float
         call cl_draw_rect_filled(x0, y0, x1, y1, cl_color_u32_rgba(MARK_BACKGROUND), 2.0_c_float)
         call cl_channels_merge()
      endif
      if (is_kbd) then
         call cl_item_rect_min(x0, y0)
         call cl_item_rect_max(x1, y1)
         x0 = x0 - 3.0_c_float
         x1 = x1 + 3.0_c_float
         call cl_draw_rect(x0, y0, x1, y1, cl_color_u32_rgba(style_color(ImGuiCol_Border)), 3.0_c_float, 1.0_c_float)
      endif
      if (adjusted_y) then
         call cl_cursor_pos(cx, cy)
         call cl_set_cursor_pos(cx, saved_y)
      endif
      if (te > b) then
         if (at(te - 1_c_int) == achar(10)) is_lf = .true.
      endif
      if (len(href) > 0) then
         if (link_item(href)) call follow_link()
      endif
      if (is_underline) call line(style_color(ImGuiCol_Text), .true.)
      if (is_strikethrough) call line(style_color(ImGuiCol_Text), .false.)
      b = te
      do while (b < e)
         if (at(b) /= ' ') exit
         b = b + 1_c_int
      enddo
   enddo
   if (pushed_small) call cl_pop_font()
   if (.not. is_lf) call cl_same_line(0.0_c_float, 0.0_c_float)
   endsubroutine render_text

   subroutine tooltip_str(text)
   !< A tooltip of a string.
   character(len=*), intent(in), target :: text !< Text.

   if (len(text) > 0) then
      call cl_tooltip(c_loc(text), len(text, c_int))
   else
      call cl_tooltip(c_loc(nul), 0_c_int)
   endif
   endsubroutine tooltip_str

   ! ---- raw HTML ----------------------------------------------------------------------------------------------------
   function skip_html_comment(b, e, after_comment) result(skip)
   !< An HTML comment (`<!-- ... -->`, a chunk per line in a block) is not shown: true for its chunks, and for the
   !< newline that follows one.
   integer(c_int), intent(in) :: b, e          !< Offsets.
   logical,        intent(in) :: after_comment !< The chunk before closed a comment.
   logical                    :: skip          !< Skipped.
   integer(c_int)             :: start, k      !< Offsets.
   logical                    :: found         !< A blank chunk.

   start = b
   found = .false.
   do while (start < e)
      if (.not. is_blank(at(start))) then
         found = .true.
         exit
      endif
      start = start + 1_c_int
   enddo
   if (.not. in_html_comment) then
      if (.not. found) then
         skip = after_comment
         return
      endif
      if (.not. (e - start >= 4_c_int .and. starts_with(start, e, '<!--'))) then
         skip = .false.
         return
      endif
      in_html_comment = .true.
      start = start + 4_c_int
   endif
   if (found) then
      do k = start, e - 3_c_int
         if (at(k) == '-' .and. at(k + 1_c_int) == '-' .and. at(k + 2_c_int) == '>') then
            in_html_comment = .false.
            html_comment_closed = .true.
            exit
         endif
      enddo
   endif
   skip = .true.
   endfunction skip_html_comment

   function check_html(b, e) result(done)
   !< imgui_rich_md's HTML tags (`Renderer::check_html`): true when the chunk was one.
   integer(c_int), intent(in)    :: b, e !< Offsets.
   logical                       :: done !< Handled.
   character(len=:), allocatable :: tag  !< The chunk.
   integer(c_int)                :: close, q, k, n !< Offsets.

   done = .true.
   tag = slice(b, e)
   if (tag == '<br>' .or. tag == '<br/>' .or. tag == '<br />') then
      call cl_new_line()
      return
   endif
   if (tag == '<hr>' .or. tag == '<hr/>' .or. tag == '<hr />') then
      call cl_separator()
      return
   endif
   if (strncmp_eq(b, e, '<u>')) then
      is_underline = .true.
      return
   endif
   if (strncmp_eq(b, e, '</u>')) then
      is_underline = .false.
      return
   endif
   if (strncmp_eq(b, e, '<sub>')) then
      is_sub = .true.
      return
   endif
   if (strncmp_eq(b, e, '</sub>')) then
      is_sub = .false.
      return
   endif
   if (strncmp_eq(b, e, '<sup>')) then
      is_sup = .true.
      return
   endif
   if (strncmp_eq(b, e, '</sup>')) then
      is_sup = .false.
      return
   endif
   if (strncmp_eq(b, e, '<kbd>')) then
      is_kbd = .true.
      return
   endif
   if (strncmp_eq(b, e, '</kbd>')) then
      is_kbd = .false.
      return
   endif
   if (strncmp_eq(b, e, '<mark>')) then
      is_mark = .true.
      return
   endif
   if (strncmp_eq(b, e, '</mark>')) then
      is_mark = .false.
      return
   endif
   if (e - b > 9_c_int .and. starts_with(b, e, '<md-error')) then
      is_error = .true.
      error_title = ''
      k = index(tag, 'title="')
      if (k > 0) then
         q = index(tag(k + 7:), '"')
         if (q > 0) error_title = tag(k + 7:k + 7 + q - 2)
      endif
      return
   endif
   if (strncmp_eq(b, e, '</md-error>')) then
      is_error = .false.
      return
   endif
   if (in_pre) then
      close = index(tag, '</pre>')
      if (close > 0) then
         pre_buffer = pre_buffer//tag(1:close - 1)
         call render_pre(pre_buffer)
         pre_buffer = ''
         in_pre = .false.
      else
         pre_buffer = pre_buffer//tag
      endif
      return
   endif
   if (starts_with(b, e, '<pre>') .or. starts_with(b, e, '<pre ')) then
      k = index(tag, '>')
      if (k == 0) k = len(tag)
      close = index(tag(k + 1:), '</pre>')
      if (close > 0) then
         call render_pre(tag(k + 1:k + close - 1))
      else
         pre_buffer = tag(k + 1:)
         in_pre = .true.
      endif
      return
   endif
   if (starts_with(b, e, '<details>') .or. starts_with(b, e, '<details ')) then
      details_awaiting_summary = .true.
      details_awaiting_open_default = has_open_attribute(tag)
      details_suppress_next_raw_html = .true.
      return
   endif
   if (starts_with(b, e, '<summary>')) then
      call summary(tag)
      return
   endif
   if (starts_with(b, e, '</details>')) then
      if (ndetails > 0_c_int) then
         ndetails = ndetails - 1_c_int
         if (details_open(ndetails + 1_c_int)) call cl_unindent()
      endif
      details_awaiting_summary = .false.
      details_suppress_next_raw_html = .true.
      return
   endif
   if (e - b >= 4_c_int .and. starts_with(b, e, '<img')) then
      if (hidden()) return
      done = html_img(tag)
      return
   endif
   if (strncmp_eq(b, e, '<center>')) then
      if (hidden()) return
      if (.not. in_center) then
         in_center = .true.
         call begin_aligned_cell(MD_ALIGN_CENTER, center_vtx_start, center_width)
         center_run_start = nruns
      endif
      return
   endif
   if (strncmp_eq(b, e, '</center>')) then
      if (hidden()) return
      if (in_center) then
         in_center = .false.
         call shift_runs(center_run_start, end_aligned_cell(MD_ALIGN_CENTER, center_vtx_start, center_width))
      endif
      return
   endif
   n = min(e - b, 4_c_int)
   if (strncmp_eq(b, b + n, '<div')) then
      div_depth = div_depth + 1_c_int
      return
   endif
   if (strncmp_eq(b, e, '</div>')) then
      if (div_depth == 0_c_int) then
         done = .false.
         return
      endif
      div_depth = div_depth - 1_c_int
      return
   endif
   done = .false.
   endfunction check_html

   pure function has_open_attribute(tag) result(yes)
   !< `<details open>` (or `open=...`): the `open` attribute between the tag's start and its `>`.
   character(len=*), intent(in) :: tag !< The tag's chunk.
   logical                      :: yes !< Open at first.
   integer                      :: tag_end, q !< Offsets (1-based).

   yes = .false.
   tag_end = index(tag, '>')
   if (tag_end == 0) tag_end = len(tag) + 1
   do q = 1, tag_end - 4
      if (q > 1) then
         if (tag(q - 1:q - 1) /= ' ' .and. tag(q - 1:q - 1) /= achar(9)) cycle
      endif
      if (tag(q:q + 3) /= 'open') cycle
      if (q + 4 == tag_end) then
         yes = .true.
      elseif (index(' '//achar(9)//'=>', tag(q + 4:q + 4)) > 0) then
         yes = .true.
      endif
      if (yes) return
   enddo
   endfunction has_open_attribute

   subroutine summary(tag)
   !< `<summary>label</summary>`: a collapsing header (its entities decoded); a collapsed one hides what follows until
   !< its `</details>`.
   character(len=*), intent(in)  :: tag   !< The chunk.
   character(len=:), allocatable :: raw, label !< Its label.
   integer                       :: close, i  !< Offsets.
   logical                       :: open      !< Open.
   real(c_float)                 :: x0, y0, x1, y1, wx, wy !< Its rectangle.
   logical, allocatable          :: more(:)   !< Grown stack.

   close = index(tag(10:), '</summary>')
   if (close > 0) then
      raw = tag(10:10 + close - 2)
   else
      raw = tag(10:)
   endif
   label = ''
   i = 1
   do while (i <= len(raw))
      if (raw(i:i) == '&') then
         if (i + 3 <= len(raw)) then
            if (raw(i:i + 3) == '&lt;') then
               label = label//'<'
               i = i + 4
               cycle
            elseif (raw(i:i + 3) == '&gt;') then
               label = label//'>'
               i = i + 4
               cycle
            endif
         endif
         if (i + 4 <= len(raw)) then
            if (raw(i:i + 4) == '&amp;') then
               label = label//'&'
               i = i + 5
               cycle
            elseif (raw(i:i + 4) == '&#39;') then
               label = label//"'"
               i = i + 5
               cycle
            endif
         endif
         if (i + 5 <= len(raw)) then
            if (raw(i:i + 5) == '&quot;') then
               label = label//'"'
               i = i + 6
               cycle
            elseif (raw(i:i + 5) == '&apos;') then
               label = label//"'"
               i = i + 6
               cycle
            endif
         endif
      endif
      label = label//raw(i:i)
      i = i + 1
   enddo
   if (.not. details_awaiting_summary) then
      call cl_text_str(label)
      return
   endif
   if (.not. allocated(details_open)) allocate(details_open(8))
   if (ndetails == size(details_open, kind=c_int)) then
      allocate(more(2 * ndetails))
      more(1:ndetails) = details_open(1:ndetails)
      call move_alloc(more, details_open)
   endif
   if (hidden()) then
      details_id_counter = details_id_counter + 1_c_int
      ndetails = ndetails + 1_c_int
      details_open(ndetails) = .false.
      details_awaiting_summary = .false.
      details_awaiting_open_default = .false.
      return
   endif
   call cl_push_id_int(details_id_counter)
   details_id_counter = details_id_counter + 1_c_int
   if (details_awaiting_open_default) call cl_set_next_item_open(.true., ImGuiCond_Once)
   open = cl_collapsing_header(label)
   call cl_pop_id()
   if (.not. open) then
      call cl_item_rect_min(x0, y0)
      call cl_item_rect_max(x1, y1)
      call cl_window_pos(wx, wy)
      hidden_y = y0 - wy + cl_scroll_y()
      hidden_bottom = y1 - wy + cl_scroll_y()
      hidden_id = cl_item_id()
   endif
   ndetails = ndetails + 1_c_int
   details_open(ndetails) = open
   if (open) call cl_indent()
   details_awaiting_summary = .false.
   details_awaiting_open_default = .false.
   details_suppress_next_raw_html = .true.
   endsubroutine summary

   subroutine render_pre(text)
   !< `<pre>` text: monospaced lines (a leading newline dropped), not when hidden.
   character(len=*), intent(in), target :: text !< Text.
   integer                              :: s, eol, n !< Offsets.
   type(c_ptr)                          :: font !< Font.
   real(c_float)                        :: size !< Size.

   s = 1
   n = len(text)
   if (s <= n) then
      if (text(s:s) == achar(10)) s = s + 1
   endif
   if (hidden()) return
   is_code = .true.
   call get_font(font, size)
   call cl_push_font(font, size)
   do while (s <= n)
      eol = s
      do while (eol <= n)
         if (text(eol:eol) == achar(10)) exit
         eol = eol + 1
      enddo
      if (eol > s) then
         call cl_text(c_loc(text(s:s)), int(eol - s, c_int))
      else
         call cl_new_line()
      endif
      if (eol <= n) then
         s = eol + 1
      else
         s = n + 1
      endif
   enddo
   call cl_pop_font()
   is_code = .false.
   endsubroutine render_pre

   function html_attribute(tag, name) result(v)
   !< An attribute's value in an HTML tag (`extract_html_attr`): quoted, or up to a blank or `>`.
   character(len=*), intent(in)  :: tag  !< Tag.
   character(len=*), intent(in)  :: name !< Attribute.
   character(len=:), allocatable :: v    !< Value ('': none).
   integer                       :: p, q, k !< Offsets.

   v = ''
   p = index(tag, name//'=')
   if (p == 0) return
   p = p + len(name) + 1
   if (p > len(tag)) return
   if (tag(p:p) == '"' .or. tag(p:p) == "'") then
      q = index(tag(p + 1:), tag(p:p))
      if (q == 0) return
      v = tag(p + 1:p + q - 1)
      return
   endif
   q = len(tag) + 1
   do k = p, len(tag)
      if (index(' '//achar(9)//achar(10)//'>', tag(k:k)) > 0) then
         q = k
         exit
      endif
   enddo
   v = tag(p:q - 1)
   endfunction html_attribute

   function html_int_attribute(tag, name, default) result(v)
   !< An integer attribute (`std::stoi`: blanks, a sign, digits), `default` when it has none.
   character(len=*), intent(in)  :: tag     !< Tag.
   character(len=*), intent(in)  :: name    !< Attribute.
   integer(c_int),   intent(in)  :: default !< Default.
   integer(c_int)                :: v       !< Value.
   character(len=:), allocatable :: s       !< Its text.
   integer                       :: k, sgn, digits !< Parsing.
   integer(c_long_long)          :: acc     !< Value read.

   v = default
   s = html_attribute(tag, name)
   if (len(s) == 0) return
   k = 1
   do while (k <= len(s))
      if (index(' '//achar(9)//achar(10)//achar(11)//achar(12)//achar(13), s(k:k)) == 0) exit
      k = k + 1
   enddo
   sgn = 1
   if (k <= len(s)) then
      if (s(k:k) == '-' .or. s(k:k) == '+') then
         if (s(k:k) == '-') sgn = -1
         k = k + 1
      endif
   endif
   acc = 0_c_long_long
   digits = 0
   do while (k <= len(s))
      if (s(k:k) < '0' .or. s(k:k) > '9') exit
      acc = acc * 10_c_long_long + int(iachar(s(k:k)) - iachar('0'), c_long_long)
      if (acc > 2147483648_c_long_long) return ! out of range: stoi throws, the default
      digits = digits + 1
      k = k + 1
   enddo
   if (digits == 0) return
   acc = sgn * acc
   if (acc > 2147483647_c_long_long) return
   v = int(acc, c_int)
   endfunction html_int_attribute

   function html_img(tag) result(done)
   !< `<img src=... width=... height=...>`: the image, at the size given (one side: the other kept in proportion), as
   !< wide as the room at most.
   character(len=*), intent(in)  :: tag  !< Tag.
   logical                       :: done !< Handled.
   integer(c_int)                :: width, height !< Attributes.
   integer(c_long_long)          :: tex_id !< Texture.
   real(c_float)                 :: w, h, scale, natural_w, natural_h, ax, ay, r !< Sizes.

   done = .true.
   img_src = html_attribute(tag, 'src')
   if (len(img_src) == 0) then
      done = .false.
      return
   endif
   width = html_int_attribute(tag, 'width', 0_c_int)
   height = html_int_attribute(tag, 'height', 0_c_int)
   if (get_image(tex_id, w, h)) then
      scale = style_value(11_c_int) * style_value(12_c_int)
      natural_w = w * scale
      natural_h = h * scale
      if (width > 0_c_int .and. height > 0_c_int) then
         w = real(width, c_float)
         h = real(height, c_float)
      elseif (width > 0_c_int) then
         w = real(width, c_float)
         h = natural_h * (real(width, c_float) / natural_w)
      elseif (height > 0_c_int) then
         w = natural_w * (real(height, c_float) / natural_h)
         h = real(height, c_float)
      else
         w = natural_w
         h = natural_h
      endif
      call cl_content_avail(ax, ay)
      if (w > ax) then
         r = h / w
         w = ax
         h = ax * r
      endif
      call cl_image(tex_id, w, h, 0.0_c_float, 0.0_c_float, 1.0_c_float, 1.0_c_float)
      call cl_same_line(0.0_c_float, 0.0_c_float)
   endif
   img_src = ''
   endfunction html_img

   ! ---- the runs and the selection ----------------------------------------------------------------------------------
   subroutine record_run(b, e, repl)
   !< The item just drawn recorded as a run: its rectangle, font, the bytes it shows (a break takes the byte after
   !< the run before).
   integer(c_int), intent(in) :: b, e !< Offsets (-1: not from the text).
   integer(c_int), intent(in) :: repl !< What it shows instead.
   type(text_run), allocatable :: more(:) !< Grown list.
   integer(c_int)              :: k       !< Counter.
   logical                     :: newlines !< Only newlines.
   real(c_float)               :: wx, wy  !< Window.

   if (repl == REPL_NONE) then
      newlines = .true.
      do k = b, e - 1_c_int
         if (at(k) /= achar(10) .and. at(k) /= achar(13)) then
            newlines = .false.
            exit
         endif
      enddo
      if (newlines) return
   endif
   if (.not. allocated(runs)) allocate(runs(64))
   if (nruns == size(runs, kind=c_int)) then
      allocate(more(2 * nruns))
      do k = 1_c_int, nruns
         more(k) = runs(k)
      enddo
      call move_alloc(more, runs)
   endif
   nruns = nruns + 1_c_int
   associate(r => runs(nruns))
      call cl_item_rect_min(r%x0, r%y0)
      call cl_item_rect_max(r%x1, r%y1)
      r%font = cl_font()
      r%font_size = cl_font_size()
      r%block = block_number
      r%href_n = 0_c_int
      r%href_b = 0_c_int
      if (len(href) > 0) call pool_add(link_pool, nlink_pool, href, r%href_b, r%href_n)
      r%repl = repl
      if (b >= 0_c_int .and. b < e .and. e <= nfrag) then
         r%b = b
         r%e = e
      else
         r%b = 0_c_int
         if (nruns > 1_c_int) r%b = runs(nruns - 1_c_int)%e
         r%e = r%b + 1_c_int
      endif
      if (hlevel > 0_c_int .and. heading_top < 0.0_c_float) then
         call cl_window_pos(wx, wy)
         heading_top = r%y0 - wy + cl_scroll_y()
      endif
   endassociate
   endsubroutine record_run

   function offset_at(px, py) result(o)
   !< The character boundary nearest to a position: in the run under it, else on its line, else in the first run below.
   real(c_float), intent(in) :: px, py !< Position.
   integer(c_int)            :: o      !< Offset.
   integer(c_int)            :: k, left, right !< Runs.

   o = 0_c_int
   if (nruns == 0_c_int) return
   left = 0_c_int
   right = 0_c_int
   do k = 1_c_int, nruns
      if (py < runs(k)%y0 .or. py >= runs(k)%y1) cycle
      if (px >= runs(k)%x0 .and. px < runs(k)%x1) then
         o = offset_in_run(k, px)
         return
      endif
      if (runs(k)%x1 <= px) then
         if (left == 0_c_int) then
            left = k
         elseif (runs(k)%x1 > runs(left)%x1) then
            left = k
         endif
      endif
      if (runs(k)%x0 > px) then
         if (right == 0_c_int) then
            right = k
         elseif (runs(k)%x0 < runs(right)%x0) then
            right = k
         endif
      endif
   enddo
   if (left > 0_c_int) then
      o = runs(left)%e
      return
   endif
   if (right > 0_c_int) then
      o = runs(right)%b
      return
   endif
   do k = 1_c_int, nruns
      if (runs(k)%y0 > py) then
         o = runs(k)%b
         return
      endif
   enddo
   o = runs(nruns)%e
   endfunction offset_at

   function offset_in_run(k, px) result(o)
   !< The character boundary of run k nearest to px.
   integer(c_int), intent(in) :: k  !< Run.
   real(c_float),  intent(in) :: px !< Abscissa.
   integer(c_int)             :: o  !< Offset.
   integer(c_int)             :: s, n !< Offset, bytes of a character.
   real(c_float)              :: x, w !< Abscissa, width.

   if (runs(k)%repl /= REPL_NONE) then
      if (px < (runs(k)%x0 + runs(k)%x1) * 0.5_c_float) then
         o = runs(k)%b
      else
         o = runs(k)%e
      endif
      return
   endif
   x = runs(k)%x0
   s = runs(k)%b
   do while (s < runs(k)%e)
      n = cl_utf8_length(ptr(s), runs(k)%e - s)
      w = cl_font_text_width(runs(k)%font, runs(k)%font_size, ptr(s), n)
      if (px < x + w * 0.5_c_float) then
         o = s
         return
      endif
      x = x + w
      s = s + n
   enddo
   o = runs(k)%e
   endfunction offset_in_run

   function run_at(o) result(k)
   !< The run showing the byte at an offset (or ending there): 0 none.
   integer(c_int), intent(in) :: o !< Offset.
   integer(c_int)             :: k !< Run.
   integer(c_int)             :: j, ending !< Counter, a run ending there.

   ending = 0_c_int
   do j = 1_c_int, nruns
      if (o >= runs(j)%b .and. o < runs(j)%e) then
         k = j
         return
      endif
      if (o == runs(j)%e) ending = j
   enddo
   k = ending
   endfunction run_at

   pure function in_word(c) result(yes)
   !< A byte of a word: beyond ASCII, a letter, a digit, `_`.
   character(kind=c_char), intent(in) :: c   !< Byte.
   logical                            :: yes !< In a word.
   integer                            :: i   !< Code.

   i = iachar(c)
   yes = i >= 128 .or. (i >= iachar('a') .and. i <= iachar('z')) .or. (i >= iachar('A') .and. i <= iachar('Z')) .or. &
         (i >= iachar('0') .and. i <= iachar('9')) .or. c == '_'
   endfunction in_word

   subroutine select_at(fragment, o, clicks)
   !< A click at an offset: one places the selection there, two select the word, three the block.
   integer(c_int), intent(in) :: fragment, o, clicks !< Fragment, offset, clicks.
   integer(c_int)             :: k, j, b, e          !< Run, counter, range.

   selection_fragment = fragment
   selection_text_hash = cl_hash_str(base, nfrag)
   selection_anchor = o
   selection_focus = o
   selection_by_unit = clicks >= 2_c_int
   k = run_at(o)
   if (clicks < 2_c_int .or. k == 0_c_int) return
   b = runs(k)%b
   e = runs(k)%e
   if (clicks >= 3_c_int) then
      do j = 1_c_int, nruns
         if (runs(j)%block == runs(k)%block) then
            b = min(b, runs(j)%b)
            e = max(e, runs(j)%e)
         endif
      enddo
   elseif (runs(k)%repl == REPL_NONE) then
      b = o
      e = o
      do while (b > runs(k)%b)
         if (.not. in_word(at(b - 1_c_int))) exit
         b = b - 1_c_int
      enddo
      do while (e < runs(k)%e)
         if (.not. in_word(at(e))) exit
         e = e + 1_c_int
      enddo
   endif
   selection_anchor = b
   selection_focus = e
   endsubroutine select_at

   subroutine select_all(fragment)
   !< The whole fragment selected.
   integer(c_int), intent(in) :: fragment !< Fragment.

   selection_fragment = fragment
   selection_text_hash = cl_hash_str(base, nfrag)
   selection_anchor = 0_c_int
   selection_focus = nfrag
   endsubroutine select_all

   function selected_markdown() result(s)
   !< The Markdown of the selection, extended to whole lines.
   character(len=:), allocatable :: s    !< Markdown.
   integer(c_int)                :: b, e !< Range.

   b = min(selection_anchor, selection_focus)
   e = min(max(selection_anchor, selection_focus), nfrag)
   do while (b > 0_c_int)
      if (at(b - 1_c_int) == achar(10)) exit
      b = b - 1_c_int
   enddo
   if (e > b) then
      if (at(e - 1_c_int) /= achar(10)) then
         do while (e < nfrag)
            if (at(e) == achar(10)) exit
            e = e + 1_c_int
         enddo
      endif
   endif
   s = slice(b, e)
   endfunction selected_markdown

   function visible_text(b, e) result(out)
   !< The text the runs between two offsets show: a run's replacement, a space at a wrap (blanks only between two runs
   !< of a block), a newline between two blocks.
   integer(c_int), intent(in)    :: b, e !< Range.
   character(len=:), allocatable :: out  !< Text.
   character(len=:), allocatable :: piece !< A run's part.
   integer(c_int)                :: k, prev, i, from, to !< Runs, offsets.
   logical                       :: blank !< Only blanks between two runs.

   out = ''
   prev = 0_c_int
   do k = 1_c_int, nruns
      if (runs(k)%e <= b .or. runs(k)%b >= e) cycle
      from = max(b, runs(k)%b)
      to = min(e, runs(k)%e)
      select case (runs(k)%repl)
      case (REPL_SPACE)
         piece = ' '
      case (REPL_LF)
         piece = achar(10)
      case default
         piece = slice(from, to)
      endselect
      if (prev > 0_c_int) then
         if (runs(k)%block /= runs(prev)%block) then
            out = out//achar(10)
         elseif (runs(k)%b > runs(prev)%e .and. len(out) > 0 .and. len(piece) > 0) then
            if (out(len(out):len(out)) /= ' ' .and. out(len(out):len(out)) /= achar(10) .and. piece(1:1) /= ' ') then
               blank = .true.
               do i = runs(prev)%e, runs(k)%b - 1_c_int
                  if (at(i) /= ' ' .and. at(i) /= achar(9) .and. at(i) /= achar(10)) then
                     blank = .false.
                     exit
                  endif
               enddo
               if (blank) out = out//' '
            endif
         endif
      endif
      out = out//piece
      prev = k
   enddo
   endfunction visible_text

   subroutine copy_string(s)
   !< A string to the clipboard.
   character(len=*), intent(in), target :: s !< Text.

   if (len(s) > 0) then
      call cl_set_clipboard(c_loc(s), len(s, c_int))
   else
      call cl_set_clipboard(c_loc(nul), 0_c_int)
   endif
   endsubroutine copy_string

   subroutine update_selection(fragment)
   !< The selection by the mouse and the keys (`Renderer::update_selection`): a click on a line of text starts one
   !< (and takes the active ID), a drag extends it, a double click selects a word, a triple click a block, a click
   !< away clears it; ctrl+c copies it, ctrl+a selects the whole fragment, a right click opens the menu.
   integer(c_int), intent(in) :: fragment !< The fragment's ID.
   real(c_float)              :: mx, my, cpx, cpy, wheel, dx !< Mouse.
   logical                    :: on_line, mouse_free, mac, want_text, touch, shift, slash !< State.
   integer(c_int)             :: k, hovered, o, chars !< Runs, offset.

   call cl_mouse_pos(mx, my)
   hovered = 0_c_int
   on_line = .false.
   do k = 1_c_int, nruns
      if (my >= runs(k)%y0 .and. my < runs(k)%y1) then
         on_line = .true.
         if (mx >= runs(k)%x0 .and. mx < runs(k)%x1) then
            hovered = k
            exit
         endif
      endif
   enddo
   mouse_free = cl_window_hovered(0_c_int)
   if (mouse_free) mouse_free = .not. cl_any_item_hovered() .and. cl_active_id() == 0_c_int
   if (hovered > 0_c_int .and. mouse_free) then
      if (runs(hovered)%href_n == 0_c_int) call cl_set_mouse_cursor(ImGuiMouseCursor_TextInput)
   endif
   call cl_io_state(cpx, cpy, wheel, dx, mac, want_text, touch, shift, chars, slash)
   if (mouse_free .and. cl_mouse_clicked(0_c_int)) then
      if (on_line) then
         call cl_set_active_id(fragment, .true.)
         o = offset_at(mx, my)
         press_in_selection = selection_fragment == fragment .and. cl_mouse_clicked_count(0_c_int) == 1_c_int .and. &
                              o >= min(selection_anchor, selection_focus) .and. o < max(selection_anchor, selection_focus)
         if (.not. press_in_selection) call select_at(fragment, o, cl_mouse_clicked_count(0_c_int))
      elseif (selection_fragment == fragment) then
         selection_fragment = 0_c_int
      endif
   endif
   if (cl_active_id() == fragment) then
      call cl_keep_alive(fragment)
      if (.not. cl_mouse_down(0_c_int)) then
         if (press_in_selection .and. cl_mouse_pos_valid()) call select_at(fragment, offset_at(cpx, cpy), 1_c_int)
         press_in_selection = .false.
         call cl_clear_active_id()
      elseif (press_in_selection) then
         if (cl_mouse_drag_past(0_c_int)) then
            press_in_selection = .false.
            call select_at(fragment, offset_at(cpx, cpy), 1_c_int)
            selection_focus = offset_at(mx, my)
         endif
      elseif (.not. selection_by_unit .or. cl_mouse_drag_past(0_c_int)) then
         if (cl_mouse_pos_valid()) selection_focus = offset_at(mx, my)
      endif
   endif
   if (mouse_free .and. on_line .and. cl_mouse_released(1_c_int)) then
      menu_link = ''
      if (hovered > 0_c_int) then
         if (runs(hovered)%href_n > 0_c_int) &
            menu_link = link_pool(runs(hovered)%href_b + 1:runs(hovered)%href_b + runs(hovered)%href_n)
      endif
      if (selection_fragment /= fragment) call select_at(fragment, offset_at(mx, my), 1_c_int)
      call cl_open_popup('##rich_md_selection_menu')
   endif
   if (selection_fragment == fragment .and. cl_window_focused(0_c_int) .and. .not. want_text) then
      if (selection_anchor /= selection_focus .and. cl_key_chord_pressed(ior(ImGuiMod_Ctrl, ImGuiKey_C))) &
         call copy_string(visible_text(min(selection_anchor, selection_focus), max(selection_anchor, selection_focus)))
      if (cl_key_chord_pressed(ior(ImGuiMod_Ctrl, ImGuiKey_A))) call select_all(fragment)
   endif
   call show_selection_menu(fragment, mac)
   endsubroutine update_selection

   subroutine show_selection_menu(fragment, mac)
   !< The menu of a right click: Copy Link over a link, Copy, Copy as Markdown, Select All.
   integer(c_int), intent(in)    :: fragment !< The fragment's ID.
   logical,        intent(in)    :: mac      !< macOS: Cmd.
   character(len=:), allocatable :: modifier !< The shortcuts' modifier.
   logical                       :: has_selection !< A selection to copy.

   if (.not. cl_begin_popup('##rich_md_selection_menu')) return
   modifier = merge('Cmd+ ', 'Ctrl+', mac)
   modifier = trim(modifier)
   has_selection = selection_fragment == fragment .and. selection_anchor /= selection_focus
   if (len(menu_link) > 0) then
      if (cl_menu_item('Copy Link', '', .false., .true.)) call copy_string(menu_link)
      call cl_separator()
   endif
   if (cl_menu_item('Copy', modifier//'C', .false., has_selection)) &
      call copy_string(visible_text(min(selection_anchor, selection_focus), max(selection_anchor, selection_focus)))
   if (cl_menu_item('Copy as Markdown', '', .false., has_selection)) call copy_string(selected_markdown())
   call cl_separator()
   if (cl_menu_item('Select All', modifier//'A', .false., .true.)) call select_all(fragment)
   call cl_end_popup()
   endsubroutine show_selection_menu

   subroutine draw_selection_rects()
   !< The highlight of the selected parts of the runs.
   integer(c_int) :: k, b, e, col !< Runs, range, colour.
   real(c_float)  :: x0, x1       !< A part.

   b = min(selection_anchor, selection_focus)
   e = max(selection_anchor, selection_focus)
   col = cl_color_u32(ImGuiCol_TextSelectedBg)
   do k = 1_c_int, nruns
      if (runs(k)%e <= b .or. runs(k)%b >= e) cycle
      x0 = runs(k)%x0
      x1 = runs(k)%x1
      if (runs(k)%repl == REPL_NONE) then
         if (b > runs(k)%b) x0 = x0 + cl_font_text_width(runs(k)%font, runs(k)%font_size, ptr(runs(k)%b), b - runs(k)%b)
         if (e < runs(k)%e) &
            x1 = runs(k)%x0 + cl_font_text_width(runs(k)%font, runs(k)%font_size, ptr(runs(k)%b), e - runs(k)%b)
      endif
      call cl_draw_rect_filled(x0, runs(k)%y0, x1, runs(k)%y1, col, 0.0_c_float)
   enddo
   endsubroutine draw_selection_rects
endmodule figure_markdown_render
