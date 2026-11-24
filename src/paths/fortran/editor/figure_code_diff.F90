!< figure_code_diff, the text diff: dtl's shortest edit script of two texts' lines, and FIGURE's glue around it.
module figure_code_diff
!< figure_code_diff, the text diff: dtl's shortest edit script of two texts' lines, and FIGURE's glue around it.
!<
!< szaghi/figure#15 P16. `diff_compose` is dtl's `Diff<std::string_view>::compose` (third_party/ImGuiColorTextEdit/dtl.h,
!< BSD): Wu, Manber and Myers' O(NP) algorithm over the lines of two texts (compared whole, byte for byte), the
!< shorter sequence first (swapped when the first is not shorter), the edit path followed back and recorded as the
!< shortest edit script: each line common, added (of the second text) or deleted (of the first), with its index in each
!< text (from 1, 0 for none), in dtl's order (no deletes moved first). A path longer than dtl's 2,000,000 coordinates
!< is recorded in parts, from where the last one stopped, as dtl does. `fig_code_diff_lines` is the glue's (the lines
!< added and removed, as `code_diff_lines` reports them).
use, intrinsic :: iso_c_binding, only : c_char, c_double, c_float, c_int, c_long_long
use, intrinsic :: iso_fortran_env, only : int8, int32, int64
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_OK, fig_pop_font, fig_push_font, fig_set_last_error
use figure_cimgui_enums, only : ImGuiChildFlags_Borders, ImGuiCol_ChildBg, ImGuiInputFlags_Repeat, ImGuiKey_DownArrow, &
                                ImGuiKey_End, ImGuiKey_Home, ImGuiKey_LeftArrow, ImGuiKey_PageDown, ImGuiKey_PageUp,      &
                                ImGuiKey_RightArrow, ImGuiKey_UpArrow, ImGuiMod_Ctrl, ImGuiStyleVar_ItemSpacing,          &
                                ImGuiWindowFlags_HorizontalScrollbar, ImGuiWindowFlags_NoMove
use figure_code_document, only : code_document, code_line, doc_reset, doc_set_text, COLOR_BACKGROUND, COLOR_LINE_NUMBER, &
                                 COLOR_WHITESPACE
use figure_code_language, only : colorize, lang_of
use figure_code_unicode, only : cp_glyph_width
use figure_code_view, only : col32, style_palette, FONT_NAME
use figure_core_text, only : ct_begin_child, ct_char, ct_circle_filled, ct_clip_rect, ct_content_avail,                 &
                             ct_cursor_screen_pos, ct_end_child, ct_float4_to_u32, ct_font_size, ct_frame_count,        &
                             ct_get_id, ct_hscroll, ct_line, ct_line_height_with_spacing, ct_pop_clip,                 &
                             ct_pop_style_color, ct_pop_style_var, ct_push_clip, ct_push_style_color_u32,              &
                             ct_push_style_var_vec2, ct_rect_filled, ct_scroll, ct_set_next_window_content_size,       &
                             ct_set_scroll_y, ct_shortcut, ct_state, ct_text, ct_text_width, ct_vscroll

implicit none
private
public :: SES_DELETE, SES_COMMON, SES_ADD
public :: diff_lines, diff_compose, fig_code_diff_lines, fig_code_diff

integer(int8),  parameter :: SES_DELETE = -1_int8 !< A line of the first text only.
integer(int8),  parameter :: SES_COMMON = 0_int8  !< A line of both.
integer(int8),  parameter :: SES_ADD = 1_int8     !< A line of the second text only.
integer(int64), parameter :: MAX_COORDINATES = 2000000_int64 !< dtl's MAX_CORDINATES_SIZE.
integer(c_int), parameter :: DIFF_KEEP_FRAMES = 600_c_int !< A diff not drawn for this many frames is forgotten.

type :: diff_state
   !< dtl's `Diff` state over two texts' lines: A the shorter (B when the texts are swapped).
   integer(int64), allocatable :: loff(:), llen(:) !< The first text's lines (offsets, lengths).
   integer(int64), allocatable :: roff(:), rlen(:) !< The second text's.
   logical                     :: swapped = .false. !< A is the second text.
   integer(int64)              :: a0 = 0_int64, b0 = 0_int64 !< First lines of A and B considered (after restarts).
   integer(int64)              :: m = 0_int64, n = 0_int64   !< Lines of A and B considered.
   integer(int64)              :: delta = 0_int64, offset = 0_int64 !< dtl's.
   integer(int64)              :: ox = 0_int64, oy = 0_int64 !< dtl's offsets of a restart.
   integer(int64), allocatable :: fp(:), path(:)   !< dtl's fp and path, from 0.
   integer(int64), allocatable :: cx(:), cy(:), ck(:) !< dtl's pathCordinates.
   integer(int64)              :: nc = 0_int64     !< Coordinates.
endtype diff_state

type :: diff_view
   !< A diff drawn by id (the glue's `diff_t`: TextDiff and its texts).
   integer(c_int)                :: key = 0_c_int        !< Its Dear ImGui id.
   integer(c_int)                :: last_frame = 0_c_int !< The frame it was last drawn.
   character(len=:), allocatable :: left, right, packed  !< Texts (LF), the language's definition.
   integer(int32)                :: side_code = -1_int32 !< The layout drawn (-1: none yet).
   logical                       :: side = .false.       !< sideBySideMode.
   logical                       :: prev_side = .false.  !< previousSideBySideMode.
   integer(int32)                :: lang = 0_int32       !< config.language.
   integer(int32)                :: lcur = 0_int32, rcur = 0_int32 !< The colourizers' languages.
   type(code_document)           :: ldoc, rdoc           !< The documents.
   integer(int32)                :: n = 0_int32          !< Rows (the script's entries).
   integer(int8),  allocatable   :: kind(:)              !< Each row's kind (`SES_*`).
   integer(int32), allocatable   :: lline(:), rline(:)   !< Its lines (from 0).
   integer(int32), allocatable   :: rcols(:)             !< Its columns.
   logical                       :: show_spaces = .false., show_tabs = .false. !< The glue: no blanks shown.
   logical                       :: minimap = .true.     !< showScrollbarMiniMap.
   integer(c_int)                :: palette_base(0:32) = 0_c_int !< paletteBase.
   integer(c_int)                :: palette(0:32) = 0_c_int      !< palette.
   real(c_float)                 :: palette_alpha = -1.0_c_float !< paletteAlpha.
   integer(c_int)                :: added = 0_c_int, deleted = 0_c_int !< addedColor, deletedColor.
   integer(int32)                :: i_ts_l = 0_int32, i_ts_r = 0_int32, i_max = 0_int32 !< The integrated view's.
   real(c_float)                 :: i_scroll = 0.0_c_float !< ... textScroll.
   integer(int32)                :: s_ts_l = 0_int32, s_ts_r = 0_int32, s_max = 0_int32 !< The side-by-side view's.
   real(c_float)                 :: s_scroll = 0.0_c_float !< ... textScroll.
endtype diff_view

type :: diff_box
   !< A slot of the views' table.
   type(diff_view), allocatable :: v !< The view.
endtype diff_box

type(diff_box), allocatable, save :: views(:)          !< The views drawn.
integer(int32),              save :: nviews = 0_int32  !< Views.

interface
   pure function c_log10(x) result(r) bind(C, name='log10')
   !< C's `log10`.
   import :: c_double
   implicit none
   real(c_double), value :: x !< Argument.
   real(c_double)        :: r !< Result.
   endfunction c_log10
endinterface

contains
   pure subroutine diff_lines(t, off, n, count)
   !< The lines of `t` (LF-separated; the part after the last LF is a line, empty or not): their offsets and lengths.
   character(len=*),            intent(in)  :: t      !< Text.
   integer(int64), allocatable, intent(out) :: off(:) !< Offsets (bytes before each line).
   integer(int64), allocatable, intent(out) :: n(:)   !< Lengths.
   integer(int32),              intent(out) :: count  !< Lines.
   integer(int64)                           :: k, a   !< Counter, start of a line.

   count = 1_int32
   do k = 1_int64, len(t, int64)
      if (t(k:k) == achar(10)) count = count + 1_int32
   enddo
   allocate(off(count), n(count))
   count = 0_int32
   a = 1_int64
   do k = 1_int64, len(t, int64)
      if (t(k:k) == achar(10)) then
         count = count + 1_int32
         off(count) = a - 1_int64
         n(count) = k - a
         a = k + 1_int64
      endif
   enddo
   count = count + 1_int32
   off(count) = a - 1_int64
   n(count) = len(t, int64) + 1_int64 - a
   endsubroutine diff_lines

   subroutine diff_compose(left, right, kind, before, after, nses)
   !< dtl's shortest edit script of `left`'s lines into `right`'s: `kind(k)` (`SES_*`), the line's index in `left`
   !< (`before`) and in `right` (`after`), from 1 (0 for none), for k = 1..`nses`.
   character(len=*),            intent(in)  :: left      !< The first text.
   character(len=*),            intent(in)  :: right     !< The second text.
   integer(int8),  allocatable, intent(out) :: kind(:)   !< Each entry's kind.
   integer(int64), allocatable, intent(out) :: before(:) !< Its line in `left`.
   integer(int64), allocatable, intent(out) :: after(:)  !< Its line in `right`.
   integer(int32),              intent(out) :: nses      !< Entries.
   type(diff_state)                         :: st        !< dtl's state.
   integer(int32)                           :: nl, nr    !< Lines of each text.
   integer(int64)                           :: p, k, r   !< dtl's.
   integer(int64), allocatable              :: vx(:), vy(:) !< The path followed back (dtl's epc).
   integer(int64)                           :: nv, i     !< Its points, counter.
   integer(int64)                           :: x_idx, y_idx, px, py !< recordSequence's.
   logical                                  :: done      !< Recorded whole.

   call diff_lines(left, st%loff, st%llen, nl)
   call diff_lines(right, st%roff, st%rlen, nr)
   st%swapped = .not. (nl < nr)
   if (st%swapped) then
      st%m = nr
      st%n = nl
   else
      st%m = nl
      st%n = nr
   endif
   allocate(kind(nl + nr), before(nl + nr), after(nl + nr))
   nses = 0_int32
   allocate(st%cx(1024), st%cy(1024), st%ck(1024))
   do
      st%delta = st%n - st%m
      st%offset = st%m + 1_int64
      allocate(st%fp(0:st%m + st%n + 2_int64), st%path(0:st%m + st%n + 2_int64))
      st%fp = -1_int64
      st%path = -1_int64
      st%nc = 0_int64
      p = -1_int64
      do
         p = p + 1_int64
         do k = -p, st%delta - 1_int64
            st%fp(k + st%offset) = snake(st, left, right, k)
         enddo
         do k = st%delta + p, st%delta + 1_int64, -1_int64
            st%fp(k + st%offset) = snake(st, left, right, k)
         enddo
         st%fp(st%delta + st%offset) = snake(st, left, right, st%delta)
         if (st%fp(st%delta + st%offset) == st%n .or. st%nc >= MAX_COORDINATES) exit
      enddo
      ! the path, back from its end
      r = st%path(st%delta + st%offset)
      nv = 0_int64
      allocate(vx(st%nc + 1_int64), vy(st%nc + 1_int64))
      do while (r /= -1_int64)
         nv = nv + 1_int64
         vx(nv) = st%cx(r + 1_int64)
         vy(nv) = st%cy(r + 1_int64)
         r = st%ck(r + 1_int64)
      enddo
      ! recordSequence
      x_idx = 1_int64
      y_idx = 1_int64
      px = 0_int64
      py = 0_int64
      do i = nv, 1_int64, -1_int64
         do while (px < vx(i) .or. py < vy(i))
            if (vy(i) - vx(i) > py - px) then
               if (.not. st%swapped) then
                  call add(SES_ADD, 0_int64, y_idx + st%oy)
               else
                  call add(SES_DELETE, y_idx + st%oy, 0_int64)
               endif
               y_idx = y_idx + 1_int64
               py = py + 1_int64
            elseif (vy(i) - vx(i) < py - px) then
               if (.not. st%swapped) then
                  call add(SES_DELETE, x_idx + st%ox, 0_int64)
               else
                  call add(SES_ADD, 0_int64, x_idx + st%ox)
               endif
               x_idx = x_idx + 1_int64
               px = px + 1_int64
            else
               if (.not. st%swapped) then
                  call add(SES_COMMON, x_idx + st%ox, y_idx + st%oy)
               else
                  call add(SES_COMMON, y_idx + st%oy, x_idx + st%ox)
               endif
               x_idx = x_idx + 1_int64
               y_idx = y_idx + 1_int64
               px = px + 1_int64
               py = py + 1_int64
            endif
         enddo
      enddo
      done = x_idx > st%m .and. y_idx > st%n
      deallocate(st%fp, st%path, vx, vy)
      if (done) exit
      ! a path too long: what is left compared again, from where the recording stopped
      st%a0 = st%a0 + x_idx - 1_int64
      st%b0 = st%b0 + y_idx - 1_int64
      st%m = st%m - (x_idx - 1_int64)
      st%n = st%n - (y_idx - 1_int64)
      st%ox = x_idx - 1_int64
      st%oy = y_idx - 1_int64
   enddo
   contains
      subroutine add(t, bi, ai)
      !< An entry of the script (writes the host's dummies only).
      integer(int8),  intent(in) :: t      !< Kind.
      integer(int64), intent(in) :: bi, ai !< Its lines in `left`, `right`.

      nses = nses + 1_int32
      kind(nses) = t
      before(nses) = bi
      after(nses) = ai
      endsubroutine add
   endsubroutine diff_compose

   pure function same(st, left, right, ia, ib) result(yes)
   !< Line `ia` of A equals line `ib` of B (from 0, past the restarts' offsets).
   type(diff_state), intent(in) :: st          !< State.
   character(len=*), intent(in) :: left, right !< Texts.
   integer(int64),   intent(in) :: ia, ib      !< Lines.
   logical                      :: yes         !< Equal.
   integer(int64)               :: la, lb, oa, ob, na, nb !< Lines, offsets, lengths.

   la = st%a0 + ia + 1_int64
   lb = st%b0 + ib + 1_int64
   if (st%swapped) then
      oa = st%roff(la)
      na = st%rlen(la)
      ob = st%loff(lb)
      nb = st%llen(lb)
      yes = na == nb
      if (yes) yes = right(oa + 1_int64:oa + na) == left(ob + 1_int64:ob + nb)
   else
      oa = st%loff(la)
      na = st%llen(la)
      ob = st%roff(lb)
      nb = st%rlen(lb)
      yes = na == nb
      if (yes) yes = left(oa + 1_int64:oa + na) == right(ob + 1_int64:ob + nb)
   endif
   endfunction same

   function snake(st, left, right, k) result(y)
   !< dtl's `snake`: the furthest point on diagonal `k` from its neighbours' fp, its coordinate recorded.
   type(diff_state), intent(inout) :: st          !< State.
   character(len=*), intent(in)    :: left, right !< Texts.
   integer(int64),   intent(in)    :: k           !< Diagonal.
   integer(int64)                  :: y           !< Its y.
   integer(int64)                  :: above, below, r, x !< fp of the neighbours, previous coordinate, x.
   integer(int64), allocatable     :: g(:)        !< Grown coordinates.

   above = st%fp(k - 1_int64 + st%offset) + 1_int64
   below = st%fp(k + 1_int64 + st%offset)
   if (above > below) then
      r = st%path(k - 1_int64 + st%offset)
   else
      r = st%path(k + 1_int64 + st%offset)
   endif
   y = max(above, below)
   x = y - k
   do while (x >= 0_int64 .and. x < st%m .and. y >= 0_int64 .and. y < st%n)
      if (.not. same(st, left, right, x, y)) exit
      x = x + 1_int64
      y = y + 1_int64
   enddo
   st%path(k + st%offset) = st%nc
   if (st%nc == size(st%cx, kind=int64)) then
      allocate(g(2_int64 * st%nc))
      g(1:st%nc) = st%cx(1:st%nc)
      call move_alloc(g, st%cx)
      allocate(g(2_int64 * st%nc))
      g(1:st%nc) = st%cy(1:st%nc)
      call move_alloc(g, st%cy)
      allocate(g(2_int64 * st%nc))
      g(1:st%nc) = st%ck(1:st%nc)
      call move_alloc(g, st%ck)
   endif
   st%nc = st%nc + 1_int64
   st%cx(st%nc) = x
   st%cy(st%nc) = y
   st%ck(st%nc) = r
   endfunction snake

   pure function str(a, n) result(s)
   !< A C string's first `n` bytes as a Fortran string.
   character(kind=c_char), intent(in) :: a(*) !< Bytes.
   integer(int64),         intent(in) :: n    !< Length.
   character(len=max(n, 0_int64))     :: s    !< String.
   integer(int64)                     :: k    !< Counter.

   do k = 1_int64, n
      s(k:k) = a(k)
   enddo
   endfunction str

   pure function unix_lines(t) result(u)
   !< `t` with CR LF and a lone CR as LF (the glue's `unix_lines`).
   character(len=*), intent(in)  :: t !< Text.
   character(len=:), allocatable :: u !< Text with LF ends.
   integer(int64)                :: i, n !< Counters.

   allocate(character(len=len(t)) :: u)
   n = 0_int64
   i = 1_int64
   do while (i <= len(t, int64))
      n = n + 1_int64
      if (t(i:i) == achar(13)) then
         u(n:n) = achar(10)
         if (i < len(t, int64)) then
            if (t(i + 1_int64:i + 1_int64) == achar(10)) i = i + 1_int64
         endif
      else
         u(n:n) = t(i:i)
      endif
      i = i + 1_int64
   enddo
   u = u(1:n)
   endfunction unix_lines

   function fig_code_diff_lines(left, left_len, right, right_len, added, n_added, removed, n_removed, cap) &
      result(status)
   !< The lines of `right` added and of `left` removed (from 1), by the diff's algorithm: counts in `n_added`,
   !< `n_removed`; up to `cap` of each written. No Dear ImGui: a task may call it.
   character(kind=c_char), intent(in)    :: left(*)    !< The old text.
   integer(c_long_long),   intent(in)    :: left_len   !< Its length.
   character(kind=c_char), intent(in)    :: right(*)   !< The new text.
   integer(c_long_long),   intent(in)    :: right_len  !< Its length.
   integer(c_int),         intent(inout) :: added(*)   !< Lines added.
   integer(c_int),         intent(out)   :: n_added    !< Their count.
   integer(c_int),         intent(inout) :: removed(*) !< Lines removed.
   integer(c_int),         intent(out)   :: n_removed  !< Their count.
   integer(c_int),         intent(in)    :: cap        !< Room in each.
   integer(c_int)                        :: status     !< Status.
   integer(int8),  allocatable           :: kind(:)    !< The script.
   integer(int64), allocatable           :: b(:), a(:) !< Its lines.
   integer(int32)                        :: nses, k, li, ri !< Entries, counter, lines.

   n_added = 0_c_int
   n_removed = 0_c_int
   call diff_compose(unix_lines(str(left, max(0_int64, int(left_len, int64)))), &
                     unix_lines(str(right, max(0_int64, int(right_len, int64)))), kind, b, a, nses)
   li = 0_int32
   ri = 0_int32
   do k = 1_int32, nses
      select case (kind(k))
      case (SES_COMMON)
         li = li + 1_int32
         ri = ri + 1_int32
      case (SES_ADD)
         ri = ri + 1_int32
         if (n_added < cap) added(n_added + 1_c_int) = ri
         n_added = n_added + 1_c_int
      case (SES_DELETE)
         li = li + 1_int32
         if (n_removed < cap) removed(n_removed + 1_c_int) = li
         n_removed = n_removed + 1_c_int
      endselect
   enddo
   status = FIG_OK
   endfunction fig_code_diff_lines

   ! ---- the view (TextDiff) and the glue's fig_code_diff (szaghi/figure#15 P16 step 14) -----------------------------
   subroutine view_reserve(v, n)
   !< Room for n views.
   integer(int32), intent(in) :: n       !< Views.
   type(diff_box), allocatable :: more(:) !< Grown table.
   integer(int32)              :: k       !< Counter.
   logical                     :: v       !< Unused (the table is the module's).

   v = .true.
   if (.not. allocated(views)) allocate(views(8))
   if (size(views, kind=int32) >= n) return
   allocate(more(2_int32 * n))
   do k = 1_int32, nviews
      call move_alloc(views(k)%v, more(k)%v)
   enddo
   call move_alloc(more, views)
   endsubroutine view_reserve

   pure function int_field(n, w) result(s)
   !< `%*d`: n right-aligned in w characters (wider when it needs).
   integer(int32), intent(in)    :: n, w !< Number, width.
   character(len=:), allocatable :: s    !< Field.
   character(len=16)             :: b    !< Digits.

   write(b, '(I0)') n
   s = repeat(' ', max(0_int32, w - len_trim(b, int32)))//trim(b)
   endfunction int_field

   subroutine typeset_doc(doc, ts_tab, tab, updated)
   !< `TypeSetter::update` of a diff's document (no wrap, no folding): the glyphs' columns and each line's.
   type(code_document), intent(inout) :: doc     !< Document.
   integer(int32),      intent(inout) :: ts_tab  !< The type setter's tab size.
   integer(int32),      intent(in)    :: tab     !< The configuration's.
   logical,             intent(out)   :: updated !< The layout changed.
   logical                            :: changed !< The tab size changed.
   integer(int32)                     :: k, j, c, w !< Line, glyph, columns, width.

   changed = ts_tab /= tab
   if (changed) ts_tab = tab
   do k = 1_int32, doc%n
      if (.not. changed .and. .not. (doc%updated .and. doc%lines(k)%needs_typesetting)) cycle
      c = 0_int32
      do j = 1_int32, doc%lines(k)%n
         if (doc%lines(k)%cp(j) == 9_int32) then
            w = ts_tab - mod(c, ts_tab)
         else
            w = cp_glyph_width(doc%lines(k)%cp(j))
         endif
         doc%lines(k)%cols(j) = int(w, int8)
         c = c + w
      enddo
      doc%lines(k)%rows = 1_int32
      doc%lines(k)%columns = c
      doc%lines(k)%needs_typesetting = .false.
   enddo
   updated = changed .or. doc%updated
   endsubroutine typeset_doc

   subroutine set_texts(v, left, right)
   !< `TextDiff::SetText`: both documents (each text's lines, a BOM skipped), the shortest edit script as the rows.
   type(diff_view),  intent(inout) :: v           !< View.
   character(len=*), intent(in)    :: left, right !< Texts.
   character(len=:), allocatable   :: l, r        !< Texts without a BOM.
   integer(int8),  allocatable     :: kind(:)     !< The script.
   integer(int64), allocatable     :: b(:), a(:)  !< Its lines.
   integer(int32)                  :: n, k, li, ri !< Entries, counter, lines.

   l = no_bom(left)
   r = no_bom(right)
   call doc_set_text(v%ldoc, l, 4_int32, .false.)
   call doc_set_text(v%rdoc, r, 4_int32, .false.)
   call diff_compose(l, r, kind, b, a, n)
   if (allocated(v%kind)) deallocate(v%kind, v%lline, v%rline, v%rcols)
   allocate(v%kind(max(n, 1_int32)), v%lline(max(n, 1_int32)), v%rline(max(n, 1_int32)), v%rcols(max(n, 1_int32)))
   v%n = n
   li = 0_int32
   ri = 0_int32
   do k = 1_int32, n
      v%kind(k) = kind(k)
      select case (kind(k))
      case (SES_COMMON)
         v%lline(k) = li
         v%rline(k) = ri
         li = li + 1_int32
         ri = ri + 1_int32
      case (SES_ADD)
         v%lline(k) = li
         v%rline(k) = ri
         ri = ri + 1_int32
      case default
         v%lline(k) = li
         v%rline(k) = ri
         li = li + 1_int32
      endselect
   enddo
   endsubroutine set_texts

   pure function no_bom(t) result(u)
   !< `t` without a leading UTF-8 byte order mark (`CodePoint::skipBOM`).
   character(len=*), intent(in)  :: t !< Text.
   character(len=:), allocatable :: u !< Text.

   u = t
   if (len(t) >= 3) then
      if (t(1:3) == achar(239)//achar(187)//achar(191)) u = t(4:)
   endif
   endfunction no_bom

   subroutine update_layout(v, side)
   !< `updateLayout` of a view (a row per line): each row's columns, the widest.
   type(diff_view), intent(inout) :: v    !< View.
   logical,         intent(in)    :: side !< The side-by-side view's.
   integer(int32)                 :: k, c, m !< Row, columns, widest.

   m = 0_int32
   do k = 1_int32, v%n
      if (v%kind(k) == SES_ADD) then
         c = v%rdoc%lines(v%rline(k) + 1)%columns
      else
         c = v%ldoc%lines(v%lline(k) + 1)%columns
      endif
      v%rcols(k) = c
      m = max(m, c)
   enddo
   if (side) then
      v%s_max = m
   else
      v%i_max = m
   endif
   endsubroutine update_layout

   subroutine render_line(v, x, y, line, scroll, last_col, first_col, gw, fs)
   !< `renderLine` (no wrap): a line's glyphs from x, scrolled.
   type(diff_view), intent(in) :: v          !< View.
   real(c_float),   intent(in) :: x, y       !< Position.
   type(code_line), intent(in) :: line       !< Line.
   real(c_float),   intent(in) :: scroll     !< textScroll.
   integer(int32),  intent(in) :: last_col   !< lastVisibleColumn.
   integer(int32),  intent(in) :: first_col  !< firstRenderableColumn.
   real(c_float),   intent(in) :: gw, fs     !< Glyph width, font size.
   integer(int32)              :: j, column  !< Glyph, column.
   real(c_float)               :: gx, x1, x2, y1, d !< Positions.

   j = 0_int32
   column = 0_int32
   do while (column < line%columns .and. column <= last_col)
      j = j + 1_int32
      gx = x + real(column, c_float) * gw
      gx = gx - scroll
      if (line%cp(j) == 9_int32) then
         if (v%show_tabs .and. column >= first_col) then
            x1 = gx + gw * 0.3_c_float
            x2 = gx + gw
            y1 = y + fs * 0.5_c_float
            d = fs * 0.16_c_float
            call ct_line(x1, y1, x2, y1, v%palette(COLOR_WHITESPACE))
            call ct_line(x2, y1, x2 - d, y1 - d, v%palette(COLOR_WHITESPACE))
            call ct_line(x2, y1, x2 - d, y1 + d, v%palette(COLOR_WHITESPACE))
         endif
      elseif (line%cp(j) == 32_int32) then
         if (v%show_spaces .and. column >= first_col) &
            call ct_circle_filled(gx + gw * 0.5_c_float, y + fs * 0.5_c_float, 1.5_c_float, v%palette(COLOR_WHITESPACE), &
                                  4_c_int)
      elseif (column >= first_col) then
         call ct_char(gx, y, v%palette(line%color(j)), line%cp(j))
      endif
      column = column + line%cols(j)
   enddo
   endsubroutine render_line

   subroutine render_minimap(v)
   !< `renderMiniMap`: the changed rows marked on the vertical scroll bar.
   type(diff_view), intent(in) :: v      !< View.
   real(c_float)               :: r(7), rh, off, left, right, ly !< Bar, row height, its marks.
   integer(int32)              :: k      !< Row.

   if (.not. ct_vscroll(r)) return
   rh = (r(4) - r(2)) / real(v%n, c_float)
   off = (r(3) - r(1)) * 0.3_c_float
   left = r(1) + off
   right = r(3) - off
   call ct_push_clip(r(1), r(2), r(3), r(4), .false.)
   do k = 1_int32, v%n
      if (v%kind(k) == SES_COMMON) cycle
      ly = anint(r(2) + real(k - 1_int32, c_float) * rh)
      call ct_rect_filled(left, ly, right, ly + rh, merge(v%added, v%deleted, v%kind(k) == SES_ADD))
   enddo
   call ct_pop_clip()
   endsubroutine render_minimap

   subroutine vertical_keys(gh, visible_rows)
   !< The views' vertical scrolling by the keys (`renderScrollbar(s)`'s end).
   real(c_float),  intent(in) :: gh           !< Row height.
   integer(int32), intent(in) :: visible_rows !< visibleRows.
   real(c_float)              :: sx, sy, r(7) !< Scroll, the bar's values.
   logical                    :: has          !< Unused.

   call ct_scroll(sx, sy)
   has = ct_vscroll(r)
   if (ct_shortcut(ImGuiKey_UpArrow, ImGuiInputFlags_Repeat)) then
      call ct_set_scroll_y(max(sy - gh, 0.0_c_float))
   elseif (ct_shortcut(ior(ImGuiMod_Ctrl, ImGuiKey_UpArrow), 0_c_int)) then
      call ct_set_scroll_y(0.0_c_float)
   elseif (ct_shortcut(ImGuiKey_DownArrow, ImGuiInputFlags_Repeat)) then
      call ct_set_scroll_y(min(sy + gh, r(6)))
   elseif (ct_shortcut(ior(ImGuiMod_Ctrl, ImGuiKey_DownArrow), 0_c_int)) then
      call ct_set_scroll_y(r(6))
   elseif (ct_shortcut(ImGuiKey_PageUp, ImGuiInputFlags_Repeat)) then
      call ct_set_scroll_y(max(sy - real(visible_rows - 2_int32, c_float) * gh, 0.0_c_float))
   elseif (ct_shortcut(ImGuiKey_PageDown, ImGuiInputFlags_Repeat)) then
      call ct_set_scroll_y(min(sy + real(visible_rows - 2_int32, c_float) * gh, r(6)))
   endif
   endsubroutine vertical_keys

   subroutine horizontal_keys(scroll, gw, maxw, tcw)
   !< The views' horizontal scrolling by the wheel and the keys, the text wider than its column.
   real(c_float), intent(inout) :: scroll    !< textScroll.
   real(c_float), intent(in)    :: gw, maxw, tcw !< Glyph width, the widest line, the column.
   real(c_float)                :: r(7), t   !< The bar's values, a scroll.
   logical                      :: has       !< Unused.

   has = ct_vscroll(r)
   t = scroll - r(7) * ct_font_size()
   if (t < 0.0_c_float) then
      scroll = 0.0_c_float
   elseif (maxw - tcw < t) then
      scroll = maxw - tcw
   else
      scroll = t
   endif
   if (ct_shortcut(ImGuiKey_LeftArrow, ImGuiInputFlags_Repeat)) then
      scroll = max(scroll - gw, 0.0_c_float)
   elseif (ct_shortcut(ImGuiKey_RightArrow, ImGuiInputFlags_Repeat)) then
      scroll = min(scroll + gw, maxw - tcw)
   elseif (ct_shortcut(ImGuiKey_Home, 0_c_int)) then
      scroll = 0.0_c_float
   elseif (ct_shortcut(ImGuiKey_End, 0_c_int)) then
      scroll = maxw - tcw
   endif
   endsubroutine horizontal_keys

   subroutine render_integrated(v, title, w, h)
   !< `IntegratedView::render`: one column, each removed line before the added one, line numbers of both texts.
   type(diff_view),  intent(inout) :: v     !< View.
   character(len=*), intent(in)    :: title !< Child id.
   real(c_float),    intent(in)    :: w, h  !< Size.
   real(c_float)  :: gw, gh, fs, sx0, sy0, vw, vh, lnw, tcw, lnp, tp, te, sx, sy, y, yt, yb, cx0, cy0, cx1, cy1, r(7)
   integer(int32) :: ld, rd, visible_rows, first, last, fcol, lcol, frc, k !< Layout.
   integer(c_long_long) :: s !< Scroll bar's scroll.
   logical        :: changed, open, has !< Layout changed, child open, a bar.

   fs = ct_font_size()
   gw = ct_text_width('#')
   gh = ct_line_height_with_spacing() * 1.0_c_float
   call ct_set_next_window_content_size(0.0_c_float, gh * real(v%n, c_float))
   call ct_push_style_var_vec2(ImGuiStyleVar_ItemSpacing, 0.0_c_float, 0.0_c_float)
   call ct_push_style_color_u32(ImGuiCol_ChildBg, v%palette(COLOR_BACKGROUND))
   open = ct_begin_child(title, w, h, ImGuiChildFlags_Borders, ior(ImGuiWindowFlags_NoMove, &
                                                                     ImGuiWindowFlags_HorizontalScrollbar))
   call ct_cursor_screen_pos(sx0, sy0)
   call ct_content_avail(vw, vh)
   ld = int(c_log10(real(v%ldoc%n + 1_int32, c_double)) + 1.0_c_double, int32)
   rd = int(c_log10(real(v%rdoc%n + 1_int32, c_double)) + 1.0_c_double, int32)
   lnw = gw * real(ld + rd + 3_int32, c_float)
   tcw = vw - lnw
   tcw = floor(tcw / gw) * gw
   call typeset_doc(v%ldoc, v%i_ts_l, 4_int32, changed)
   call typeset_doc(v%rdoc, v%i_ts_r, 4_int32, has)
   changed = changed .or. has
   if (changed .or. (v%side .neqv. v%prev_side)) call update_layout(v, .false.)
   lnp = sx0
   tp = lnp + lnw
   te = tp + tcw
   visible_rows = max(int(ceiling(vh / gh), int32), 0_int32)
   call ct_scroll(sx, sy)
   first = max(int(floor(sy / gh), int32), 0_int32)
   last = min(int(ceiling((sy + vh) / gh), int32), v%n - 1_int32)
   fcol = max(int(floor(v%i_scroll / gw), int32), 0_int32)
   lcol = int(ceiling((v%i_scroll + tcw) / gw), int32)
   frc = (fcol / 4_int32) * 4_int32
   ! background
   y = sy0 + real(first, c_float) * gh
   do k = first + 1_int32, last + 1_int32
      select case (v%kind(k))
      case (SES_COMMON)
         call ct_text(lnp, y, v%palette(COLOR_LINE_NUMBER), ' '//int_field(v%lline(k) + 1_int32, ld)//' '// &
                      int_field(v%rline(k) + 1_int32, rd))
      case (SES_ADD)
         call ct_text(lnp, y, v%palette(COLOR_LINE_NUMBER), ' '//repeat(' ', ld)//' '//int_field(v%rline(k) + 1_int32, rd) &
                      //' +')
         call ct_rect_filled(lnp, y, te, y + gh, v%added)
      case default
         call ct_text(lnp, y, v%palette(COLOR_LINE_NUMBER), ' '//int_field(v%lline(k) + 1_int32, ld)//' '// &
                      repeat(' ', rd)//' -')
         call ct_rect_filled(lnp, y, te, y + gh, v%deleted)
      endselect
      y = y + gh
   enddo
   ! text
   call ct_clip_rect(cx0, cy0, cx1, cy1)
   yt = cy0
   yb = cy1
   has = ct_vscroll(r)
   if (real(v%i_max, c_float) * gw > tcw) yb = yb - (scrollbar_size() + r(5))
   call ct_push_clip(tp, yt, te, yb, .false.)
   do k = first + 1_int32, last + 1_int32
      y = sy0 + real(k - 1_int32, c_float) * gh
      if (v%kind(k) == SES_ADD) then
         call render_line(v, tp, y, v%rdoc%lines(v%rline(k) + 1), v%i_scroll, lcol, frc, gw, fs)
      else
         call render_line(v, tp, y, v%ldoc%lines(v%lline(k) + 1), v%i_scroll, lcol, frc, gw, fs)
      endif
   enddo
   call ct_pop_clip()
   ! scroll bar
   if (real(v%i_max, c_float) * gw > tcw) then
      s = int(v%i_scroll, c_long_long)
      if (ct_hscroll(tp, te, 'textScroll', s, tcw, real(v%i_max, c_float) * gw)) v%i_scroll = real(s, c_float)
      call horizontal_keys(v%i_scroll, gw, real(v%i_max, c_float) * gw, tcw)
   else
      v%i_scroll = 0.0_c_float
   endif
   call vertical_keys(gh, visible_rows)
   if (v%minimap) call render_minimap(v)
   call ct_end_child()
   call ct_pop_style_color(1_c_int)
   call ct_pop_style_var(1_c_int)
   endsubroutine render_integrated

   subroutine render_side(v, title, w, h)
   !< `SideBySideView::render`: the two texts side by side, each with its line numbers.
   type(diff_view),  intent(inout) :: v     !< View.
   character(len=*), intent(in)    :: title !< Child id.
   real(c_float),    intent(in)    :: w, h  !< Size.
   real(c_float)  :: gw, gh, fs, sx0, sy0, vw, vh, lw, rw, tcw, llp, ltp, rlp, rtp, rte, sx, sy, y, yt, yb, cx0, cy0, &
                     cx1, cy1, r(7)
   integer(int32) :: ld, rd, visible_rows, first, last, fcol, lcol, frc, k !< Layout.
   integer(c_long_long) :: s !< Scroll bars' scroll.
   logical        :: changed, open, has !< Layout changed, child open, a bar.

   fs = ct_font_size()
   gw = ct_text_width('#')
   gh = ct_line_height_with_spacing() * 1.0_c_float
   call ct_set_next_window_content_size(0.0_c_float, gh * real(v%n, c_float))
   call ct_push_style_var_vec2(ImGuiStyleVar_ItemSpacing, 0.0_c_float, 0.0_c_float)
   call ct_push_style_color_u32(ImGuiCol_ChildBg, v%palette(COLOR_BACKGROUND))
   open = ct_begin_child(title, w, h, ImGuiChildFlags_Borders, ImGuiWindowFlags_NoMove)
   call ct_cursor_screen_pos(sx0, sy0)
   call ct_content_avail(vw, vh)
   ld = int(c_log10(real(v%ldoc%n + 1_int32, c_double)) + 1.0_c_double, int32)
   rd = int(c_log10(real(v%rdoc%n + 1_int32, c_double)) + 1.0_c_double, int32)
   lw = gw * real(ld + 4_int32, c_float)
   rw = gw * real(rd + 4_int32, c_float)
   tcw = vw - lw
   tcw = tcw - rw
   tcw = tcw / 2.0_c_float
   tcw = floor(tcw / gw) * gw
   call typeset_doc(v%ldoc, v%s_ts_l, 4_int32, changed)
   call typeset_doc(v%rdoc, v%s_ts_r, 4_int32, has)
   changed = changed .or. has
   if (changed .or. (v%side .neqv. v%prev_side)) call update_layout(v, .true.)
   llp = sx0
   ltp = llp + lw
   rlp = ltp + tcw
   rtp = rlp + rw
   rte = rtp + tcw
   visible_rows = max(int(ceiling(vh / gh), int32), 0_int32)
   call ct_scroll(sx, sy)
   first = max(int(floor(sy / gh), int32), 0_int32)
   last = min(int(floor((sy + vh) / gh), int32), v%n - 1_int32)
   fcol = max(int(floor(v%s_scroll / gw), int32), 0_int32)
   lcol = int(floor((v%s_scroll + tcw) / gw), int32)
   frc = (fcol / 4_int32) * 4_int32
   ! background
   y = sy0 + real(first, c_float) * gh
   do k = first + 1_int32, last + 1_int32
      select case (v%kind(k))
      case (SES_COMMON)
         call ct_text(llp, y, v%palette(COLOR_LINE_NUMBER), ' '//int_field(v%lline(k) + 1_int32, ld))
         call ct_text(rlp, y, v%palette(COLOR_LINE_NUMBER), ' '//int_field(v%rline(k) + 1_int32, rd))
      case (SES_ADD)
         call ct_text(rlp, y, v%palette(COLOR_LINE_NUMBER), ' '//int_field(v%rline(k) + 1_int32, rd)//' +')
         call ct_rect_filled(rtp, y, rte, y + gh, v%added)
      case default
         call ct_text(llp, y, v%palette(COLOR_LINE_NUMBER), ' '//int_field(v%lline(k) + 1_int32, ld)//' -')
         call ct_rect_filled(ltp, y, rlp, y + gh, v%deleted)
      endselect
      y = y + gh
   enddo
   ! text
   call ct_clip_rect(cx0, cy0, cx1, cy1)
   yt = cy0
   yb = cy1
   has = ct_vscroll(r)
   if (real(v%s_max, c_float) * gw > tcw) yb = yb - (scrollbar_size() + r(5))
   call ct_push_clip(ltp, yt, rlp, yb, .false.)
   do k = first + 1_int32, last + 1_int32
      if (v%kind(k) == SES_ADD) cycle
      y = sy0 + real(k - 1_int32, c_float) * gh
      call render_line(v, ltp, y, v%ldoc%lines(v%lline(k) + 1), v%s_scroll, lcol, frc, gw, fs)
   enddo
   call ct_pop_clip()
   call ct_push_clip(rtp, yt, rte, yb, .false.)
   do k = first + 1_int32, last + 1_int32
      if (v%kind(k) == SES_DELETE) cycle
      y = sy0 + real(k - 1_int32, c_float) * gh
      call render_line(v, rtp, y, v%rdoc%lines(v%rline(k) + 1), v%s_scroll, lcol, frc, gw, fs)
   enddo
   call ct_pop_clip()
   ! scroll bars
   if (real(v%s_max, c_float) * gw > tcw) then
      s = int(v%s_scroll, c_long_long)
      if (ct_hscroll(ltp, rlp, 'leftTextScroll', s, tcw, real(v%s_max, c_float) * gw)) v%s_scroll = real(s, c_float)
      if (ct_hscroll(rtp, rte, 'rightTextScroll', s, tcw, real(v%s_max, c_float) * gw)) v%s_scroll = real(s, c_float)
      call horizontal_keys(v%s_scroll, gw, real(v%s_max, c_float) * gw, tcw)
   else
      v%s_scroll = 0.0_c_float
   endif
   call vertical_keys(gh, visible_rows)
   if (v%minimap) call render_minimap(v)
   call ct_end_child()
   call ct_pop_style_color(1_c_int)
   call ct_pop_style_var(1_c_int)
   endsubroutine render_side

   function scrollbar_size() result(s)
   !< The style's ScrollbarSize.
   real(c_float)  :: s     !< Size.
   real(c_float)  :: f(16) !< State.
   integer(c_int) :: fi(5) !< Flags.

   call ct_state(f, fi)
   s = f(8)
   endfunction scrollbar_size

   subroutine view_render(v, title, w, h)
   !< `TextDiff::Render`.
   type(diff_view),  intent(inout) :: v     !< View.
   character(len=*), intent(in)    :: title !< Child id.
   real(c_float),    intent(in)    :: w, h  !< Size.
   real(c_float)                   :: f(16), c(4) !< State, a colour.
   integer(c_int)                  :: fi(5) !< Flags.
   integer(int32)                  :: k     !< Colour.
   logical                         :: lch   !< Language changed.

   call ct_state(f, fi)
   if (v%palette_alpha /= f(5)) then
      v%palette_alpha = f(5)
      do k = 0_int32, 32_int32
         c = u32_to_float4(v%palette_base(k))
         c(4) = c(4) * v%palette_alpha
         v%palette(k) = ct_float4_to_u32(c)
      enddo
   endif
   call colorize(v%ldoc, v%lang, v%lcur, lch)
   call colorize(v%rdoc, v%lang, v%rcur, lch)
   if (v%side) then
      call render_side(v, title, w, h)
   else
      call render_integrated(v, title, w, h)
   endif
   v%prev_side = v%side
   v%ldoc%updated = .false.
   v%rdoc%updated = .false.
   endsubroutine view_render

   pure function u32_to_float4(c) result(f)
   !< `ColorConvertU32ToFloat4`.
   integer(c_int), intent(in) :: c    !< Packed colour.
   real(c_float)              :: f(4) !< RGBA.
   real(c_float), parameter   :: S = 1.0_c_float / 255.0_c_float !< Scale.
   integer(int32)             :: k    !< Channel.

   do k = 1_int32, 4_int32
      f(k) = real(iand(ishft(c, -8 * (k - 1)), 255_c_int), c_float) * S
   enddo
   endfunction u32_to_float4

   function fig_code_diff(id, id_len, left, left_len, right, right_len, packed, packed_len, side_by_side, width, &
                          height) result(status)
   !< The glue's `fig_code_diff`: the diff drawn by id, its state kept per Dear ImGui id (the texts compared again when
   !< they, the language or the layout change), forgotten when not drawn for 600 frames.
   character(kind=c_char), intent(in) :: id(*)        !< Widget id.
   integer(c_int),         intent(in) :: id_len       !< Its length.
   character(kind=c_char), intent(in) :: left(*)      !< The old text.
   integer(c_long_long),   intent(in) :: left_len     !< Its length.
   character(kind=c_char), intent(in) :: right(*)     !< The new text.
   integer(c_long_long),   intent(in) :: right_len    !< Its length.
   character(kind=c_char), intent(in) :: packed(*)    !< Language.
   integer(c_int),         intent(in) :: packed_len   !< Its length.
   integer(c_int),         intent(in) :: side_by_side !< Two columns.
   real(c_double),         intent(in) :: width        !< Width.
   real(c_double),         intent(in) :: height       !< Height.
   integer(c_int)                     :: status       !< Status.
   character(len=:), allocatable      :: label, l, r, p, msg !< Its id, texts, language, a message.
   integer(c_int)                     :: key, frame, pal(0:32) !< Its key, the frame, the style's palette.
   integer(int32)                     :: k, j, lang, s !< Views, language, status.
   logical                            :: unused !< Unused.

   label = str(id, int(id_len, int64))
   if (len(label) == 0) then
      call fig_set_last_error('code_diff: the id is empty', 26_c_int)
      status = FIG_ERR_ARGUMENT
      return
   endif
   key = ct_get_id(label)
   k = 0_int32
   do j = 1_int32, nviews
      if (views(j)%v%key == key) then
         k = j
         exit
      endif
   enddo
   if (k == 0_int32) then
      call view_reserve(unused, nviews + 1_int32)
      nviews = nviews + 1_int32
      k = nviews
      allocate(views(k)%v)
      views(k)%v%key = key
      views(k)%v%left = ''
      views(k)%v%right = ''
      views(k)%v%packed = ''
      call dark(views(k)%v%palette_base)
      views(k)%v%added = col32(0_int32, 150_int32, 32_int32, 128_int32)
      views(k)%v%deleted = col32(180_int32, 0_int32, 32_int32, 128_int32)
      call doc_reset(views(k)%v%ldoc)
      call doc_reset(views(k)%v%rdoc)
   endif
   frame = ct_frame_count()
   associate(v => views(k)%v)
      v%last_frame = frame
      l = unix_lines(str(left, max(0_int64, int(left_len, int64))))
      r = unix_lines(str(right, max(0_int64, int(right_len, int64))))
      p = str(packed, int(packed_len, int64))
      if (.not. (p == v%packed .and. len(p) == len(v%packed)) .or. v%side_code < 0_int32) then
         call lang_of(p, lang, s, msg)
         if (s /= 0_int32) then
            call fig_set_last_error(msg, len(msg, c_int))
            status = FIG_ERR_ARGUMENT
            return
         endif
         v%lang = lang
         v%packed = p
         v%side_code = -1_int32
      endif
      if (v%side_code /= side_by_side .or. .not. (l == v%left .and. len(l) == len(v%left)) .or. &
          .not. (r == v%right .and. len(r) == len(v%right))) then
         v%left = l
         v%right = r
         v%side_code = side_by_side
         v%side = side_by_side /= 0_c_int
         call set_texts(v, v%left, v%right)
      endif
      call style_palette(pal)
      if (any(pal /= v%palette_base)) then
         v%palette_base = pal
         v%palette_alpha = -1.0_c_float
      endif
      status = fig_push_font(FONT_NAME, len(FONT_NAME, c_int), 0.0_c_double)
      if (status /= FIG_OK) return
      call view_render(v, label, real(width, c_float), real(height, c_float))
      status = fig_pop_font()
   endassociate
   ! forget the views no longer drawn
   j = 1_int32
   do while (j <= nviews)
      if (frame - views(j)%v%last_frame > DIFF_KEEP_FRAMES) then
         deallocate(views(j)%v)
         do k = j, nviews - 1_int32
            call move_alloc(views(k + 1)%v, views(k)%v)
         enddo
         nviews = nviews - 1_int32
      else
         j = j + 1_int32
      endif
   enddo
   status = FIG_OK
   endfunction fig_code_diff

   pure subroutine dark(p)
   !< The fork's dark palette (TextDiff's default, `GetDefaultPalette`).
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
   endsubroutine dark
endmodule figure_code_diff
