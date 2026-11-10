!< figure_group, widgets that group other widgets: child regions, headers, tabs, tables, trees, id scopes, disabled blocks,
!< layout groups and aligned groups.
module figure_group
!< figure_group, widgets that group other widgets: child regions, headers, tabs, tables, trees, id scopes, disabled blocks,
!< layout groups and aligned groups.
!<
!< Every drawing procedure of this module refuses a call from a task (`FIG_ERR_STATE`): see processes.md; and a call
!< with no frame open, a usage error (`FIG_ERR_STATE`, `<procedure>: no frame open`). Every begin/end and push/pop
!< pair registers in the scope record of the frame, which checks each end before Dear ImGui sees it: a wrong end is
!< refused and reported by `app%next_frame` (`app%set_checks`; errors.md, "Pairing and frames").
!<
!< Pairing rules (Dear ImGui's): `ig_end_tab_bar` only when `ig_begin_tab_bar` returned true, `ig_end_tab` only when
!< `ig_begin_tab` returned true, `ig_end_table` only when `ig_begin_table` returned true, `ig_tree_pop` only when
!< `ig_tree_node` returned true (unlike `ig_begin`/`ig_end`,
!< always paired); `ig_pop_id` after every `ig_push_id`, `ig_end_disabled` after every `ig_begin_disabled`,
!< `ig_end_child` after every `ig_begin_child`, `ig_end_group` after every `ig_begin_group`, `ig_align_end` after every
!< `ig_align_begin`. A collapsing header needs no end call.
!<
!< A table: `ig_begin_table`, then optionally one `ig_table_setup_column` per column and `ig_table_headers_row`, then
!< per row `ig_table_next_row` and per cell `ig_table_next_column` (or `ig_table_set_column`) before its widgets.
!< Widgets repeated on every row need an id scope per row (`ig_push_id(row)`) or distinct labels.
use, intrinsic :: iso_c_binding, only : c_associated, c_bool, c_double, c_float, c_int, c_loc, c_null_ptr, c_ptr
use, intrinsic :: ieee_arithmetic, only : ieee_is_nan
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure_base, only : cstr, figure_check, figure_draw_refused, figure_fail, figure_scope_open, figure_scope_refused, &
                        SCOPE_ALIGN, SCOPE_CHILD, SCOPE_DISABLED, SCOPE_GROUP, SCOPE_ID, SCOPE_TAB, SCOPE_TAB_BAR,      &
                        SCOPE_TABLE, SCOPE_TREE
use figure_c_native, only : fig_align_begin, fig_align_end, fig_align_next, fig_clipper_begin, fig_clipper_delete, &
                            fig_clipper_new, fig_clipper_step, FIG_ERR_ARGUMENT, FIG_OK
use figure_cimgui, only : igBeginGroup, igEndGroup, &
                          igBeginChild_Str, igEndChild, im_vec2, igBeginDisabled, igBeginTabBar, igBeginTabItem, &
                          igBeginTable,                                                                         &
                          igCollapsingHeader_TreeNodeFlags, igEndDisabled, igEndTabBar, igEndTabItem, igEndTable, &
                          igPopID, igPushID_Int, igPushID_Str, igTableHeadersRow, igTableNextColumn, igTableNextRow, &
                          igTableSetColumnIndex, igTableSetupColumn, igIsItemClicked, igIsItemToggledOpen,          &
                          igSetNextItemOpen, igTreeNodeEx_Str, igTreePop
use figure_cimgui_enums, only : ImGuiTableColumnFlags_WidthFixed, ImGuiTableColumnFlags_WidthStretch,        &
                                ImGuiTableFlags_Borders, ImGuiTableFlags_Resizable, ImGuiTableFlags_RowBg,    &
                                ImGuiTreeNodeFlags_DefaultOpen, ImGuiChildFlags_Borders, ImGuiCond_Always,      &
                                ImGuiCond_Once, ImGuiTreeNodeFlags_Leaf, ImGuiTreeNodeFlags_OpenOnArrow,       &
                                ImGuiTreeNodeFlags_OpenOnDoubleClick, ImGuiTreeNodeFlags_Selected,             &
                                ImGuiTreeNodeFlags_SpanFullWidth

implicit none
private
public :: ig_collapsing_header, ig_begin_tab_bar, ig_end_tab_bar, ig_begin_tab, ig_end_tab, ig_push_id, ig_pop_id
public :: ig_begin_disabled, ig_end_disabled
public :: ig_begin_table, ig_end_table, ig_table_setup_column, ig_table_headers_row, ig_table_next_row
public :: ig_table_next_column, ig_table_set_column, ig_begin_child, ig_end_child
public :: ig_tree_node, ig_tree_pop, ig_set_next_item_open
public :: ig_begin_group, ig_end_group, ig_align_begin, ig_align_end, ig_align_next
public :: list_clipper_object

type :: list_clipper_object
   !< Only the rows of a long list that are in view are drawn: `call clip%begin(n)`, then
   !< `do while (clip%step())`, drawing rows `clip%first` to `clip%last` (rows of equal height; in a window, a child
   !< region or a table). The loop ends by itself; a clipper left before its end is closed when it is begun again or
   !< goes out of scope.
   integer(int32)          :: first = 1_int32  !< First row to draw (1-based).
   integer(int32)          :: last = 0_int32   !< Last row to draw.
   real(real64)            :: item_height = 0.0_real64 !< Row pitch [pixels]: given to `begin` or measured on the
                                                       !< first row (0 until known); row `i` starts `(i - 1) *
                                                       !< item_height` below the list's top (`ig_scroll_to_pos`).
   type(c_ptr),    private :: p = c_null_ptr   !< Dear ImGui's clipper.
   contains
      procedure, pass(self) :: begin => clipper_begin !< Start: the number of rows.
      procedure, pass(self) :: step => clipper_step   !< The next rows to draw: false at the end.
      final                 :: clipper_final
endtype list_clipper_object

interface ig_push_id
   !< Open an id scope, by a string or an integer.
   module procedure ig_push_id_str, ig_push_id_i32
endinterface ig_push_id

contains
   recursive subroutine clipper_begin(self, count, item_height)
   !< Start clipping `count` rows; `item_height` [pixels] (default: measured on the first row drawn).
   class(list_clipper_object), intent(inout)        :: self        !< Clipper.
   integer(int32),             intent(in)           :: count       !< Rows.
   real(real64),               intent(in), optional :: item_height !< Row height.
   real(c_double)                                   :: h           !< C copy.

   if (figure_draw_refused('list_clipper_object%begin')) return ! a task does not draw
   if (c_associated(self%p)) call fig_clipper_delete(self%p)
   self%p = fig_clipper_new()
   h = -1.0_c_double
   if (present(item_height)) then
      h = real(item_height, c_double)
      self%item_height = item_height
   endif
   call fig_clipper_begin(self%p, int(max(count, 0_int32), c_int), h)
   self%first = 1_int32
   self%last = 0_int32
   endsubroutine clipper_begin

   recursive function clipper_step(self) result(more)
   !< The next rows to draw, `self%first` to `self%last`: true while there are some (false: the clipper ended).
   class(list_clipper_object), intent(inout) :: self  !< Clipper.
   logical                                   :: more  !< Draw first..last.
   integer(c_int)                            :: f, l  !< C copies.
   real(c_double)                            :: h     !< C copy of the row height.

   more = .false.
   if (figure_draw_refused('list_clipper_object%step')) return ! a task does not draw
   more = .false.
   if (.not. c_associated(self%p)) return
   more = fig_clipper_step(self%p, f, l, h) == 1_c_int
   if (h > 0.0_c_double) self%item_height = real(h, real64)
   if (more) then
      self%first = int(f, int32)
      self%last = int(l, int32)
   else
      call fig_clipper_delete(self%p)
      self%p = c_null_ptr
   endif
   endfunction clipper_step

   subroutine clipper_final(self)
   !< A clipper going out of scope: freed.
   type(list_clipper_object), intent(inout) :: self !< Clipper.

   if (c_associated(self%p)) call fig_clipper_delete(self%p)
   self%p = c_null_ptr
   endsubroutine clipper_final

   recursive function ig_begin_child(id, width, height, border) result(visible)
   !< A region inside the window, scrolling on its own (a list that scrolls while a help panel stays); always pair with
   !< `ig_end_child`, whatever this returned. `width`/`height` [pixels]: 0 or absent fills what is left, negative leaves
   !< that much.
   character(len=*), intent(in)           :: id      !< Id of the region (not shown).
   real(real64),     intent(in), optional :: width   !< Width [pixels].
   real(real64),     intent(in), optional :: height  !< Height [pixels].
   logical,          intent(in), optional :: border  !< Draw a border (default: none).
   logical                                :: visible !< False when clipped: skip its content (still call ig_end_child).
   type(im_vec2)                          :: extent  !< Size.
   integer(c_int)                         :: flags   !< ImGuiChildFlags.

   visible = .false.
   if (figure_draw_refused('ig_begin_child')) return ! a task does not draw
   extent = im_vec2(0.0_c_float, 0.0_c_float)
   if (present(width)) extent%x = real(width, c_float)
   if (present(height)) extent%y = real(height, c_float)
   flags = 0_c_int
   if (present(border)) then
      if (border) flags = ImGuiChildFlags_Borders
   endif
   visible = logical(igBeginChild_Str(cstr(id), extent, flags, 0_c_int))
   call figure_scope_open(SCOPE_CHILD, 'ig_begin_child', id, visible)
   endfunction ig_begin_child

   recursive subroutine ig_end_child()
   !< End the region opened by `ig_begin_child` (whatever it returned).
   if (figure_scope_refused(SCOPE_CHILD, 'ig_end_child')) return ! a task, no frame, or not the innermost scope
   call igEndChild()
   endsubroutine ig_end_child

   recursive function ig_collapsing_header(label, default_open) result(open)
   !< A header that shows or hides what follows it; true while open (then draw the content). No end call.
   character(len=*), intent(in)           :: label        !< Label (also its id).
   logical,          intent(in), optional :: default_open !< Open the first time it is shown (default: closed).
   logical                                :: open         !< The header is open.
   integer(c_int)                         :: flags        !< ImGuiTreeNodeFlags.

   open = .false.
   if (figure_draw_refused('ig_collapsing_header')) return ! a task does not draw
   flags = 0_c_int
   if (present(default_open)) then
      if (default_open) flags = ImGuiTreeNodeFlags_DefaultOpen
   endif
   open = logical(igCollapsingHeader_TreeNodeFlags(cstr(label), flags))
   endfunction ig_collapsing_header

   recursive function ig_tree_node(label, default_open, selected, leaf, span_full_width, clicked) result(open)
   !< A node of a tree (`TreeNodeEx`); true while open: draw its children, then `ig_tree_pop` (only after true).
   !< The arrow, or a double-click on the label, opens and closes the node; a single click on the label is reported
   !< by `clicked` (`IsItemClicked` and not `IsItemToggledOpen`), so choosing a node and expanding it stay different.
   !< A leaf has no arrow and is always open: it too is popped.
   character(len=*), intent(in)            :: label           !< Label (also its id).
   logical,          intent(in),  optional :: default_open    !< Open the first time it is shown (default: closed).
   logical,          intent(in),  optional :: selected        !< Highlighted as selected (the program keeps it).
   logical,          intent(in),  optional :: leaf            !< No children: no arrow (default: false).
   logical,          intent(in),  optional :: span_full_width !< Highlight and hit the whole width (or cell).
   logical,          intent(out), optional :: clicked         !< The label was clicked this frame (not the arrow).
   logical                                 :: open            !< The node is open: draw its children, then pop.
   integer(c_int)                          :: flags           !< ImGuiTreeNodeFlags.

   open = .false.
   if (present(clicked)) clicked = .false.
   if (figure_draw_refused('ig_tree_node')) return ! a task does not draw
   flags = ior(ImGuiTreeNodeFlags_OpenOnArrow, ImGuiTreeNodeFlags_OpenOnDoubleClick)
   if (present(default_open)) then
      if (default_open) flags = ior(flags, ImGuiTreeNodeFlags_DefaultOpen)
   endif
   if (present(selected)) then
      if (selected) flags = ior(flags, ImGuiTreeNodeFlags_Selected)
   endif
   if (present(leaf)) then
      if (leaf) flags = ior(flags, ImGuiTreeNodeFlags_Leaf)
   endif
   if (present(span_full_width)) then
      if (span_full_width) flags = ior(flags, ImGuiTreeNodeFlags_SpanFullWidth)
   endif
   open = logical(igTreeNodeEx_Str(cstr(label), flags))
   call figure_scope_open(SCOPE_TREE, 'ig_tree_node', label, open)
   if (present(clicked)) clicked = logical(igIsItemClicked(0_c_int)) .and. .not. logical(igIsItemToggledOpen())
   endfunction ig_tree_node

   recursive subroutine ig_tree_pop()
   !< Close the children of a node (only after `ig_tree_node` returned true).
   if (figure_scope_refused(SCOPE_TREE, 'ig_tree_pop')) return ! a task, no frame, or not the innermost scope
   call igTreePop()
   endsubroutine ig_tree_pop

   recursive subroutine ig_set_next_item_open(open, always)
   !< Open or close the next tree node (or collapsing header) from the program: the first time it is shown, or, with
   !< `always`, on this frame whatever its state (an "expand all" button calls it with `always` once per node).
   logical, intent(in)           :: open   !< Open (true) or closed.
   logical, intent(in), optional :: always !< Enforce on this frame (default: only when the node has no state yet).
   integer(c_int)                :: cond   !< ImGuiCond.

   if (figure_draw_refused('ig_set_next_item_open')) return ! a task does not draw
   cond = ImGuiCond_Once
   if (present(always)) then
      if (always) cond = ImGuiCond_Always
   endif
   call igSetNextItemOpen(logical(open, c_bool), cond)
   endsubroutine ig_set_next_item_open

   recursive function ig_begin_tab_bar(id) result(visible)
   !< Begin a bar of tabs; when true, declare the tabs (`ig_begin_tab`) and close it with `ig_end_tab_bar`.
   character(len=*), intent(in) :: id      !< Id of the bar (not shown).
   logical                      :: visible !< The bar is drawn.

   visible = .false.
   if (figure_draw_refused('ig_begin_tab_bar')) return ! a task does not draw
   visible = logical(igBeginTabBar(cstr(id), 0_c_int))
   call figure_scope_open(SCOPE_TAB_BAR, 'ig_begin_tab_bar', id, visible)
   endfunction ig_begin_tab_bar

   recursive subroutine ig_end_tab_bar()
   !< End a bar of tabs (only after `ig_begin_tab_bar` returned true).
   if (figure_scope_refused(SCOPE_TAB_BAR, 'ig_end_tab_bar')) return ! a task, no frame, or not the innermost scope
   call igEndTabBar()
   endsubroutine ig_end_tab_bar

   recursive function ig_begin_tab(label, open) result(selected)
   !< A tab of the current bar; true when it is the selected one: draw its content, then `ig_end_tab`. With `open`,
   !< the tab has a close button that sets it false.
   character(len=*), intent(in)              :: label    !< Label (also its id).
   logical,          intent(inout), optional :: open     !< Tab open.
   logical                                   :: selected !< The tab is selected.
   logical(c_bool), target                   :: o        !< C copy of `open`.
   type(c_ptr)                               :: p        !< bool* or null.

   selected = .false.
   if (figure_draw_refused('ig_begin_tab')) return ! a task does not draw
   p = c_null_ptr
   if (present(open)) then
      o = logical(open, c_bool)
      p = c_loc(o)
   endif
   selected = logical(igBeginTabItem(cstr(label), p, 0_c_int))
   if (present(open)) open = logical(o)
   call figure_scope_open(SCOPE_TAB, 'ig_begin_tab', label, selected)
   endfunction ig_begin_tab

   recursive subroutine ig_end_tab()
   !< End the content of a tab (only after `ig_begin_tab` returned true).
   if (figure_scope_refused(SCOPE_TAB, 'ig_end_tab')) return ! a task, no frame, or not the innermost scope
   call igEndTabItem()
   endsubroutine ig_end_tab

   recursive function ig_begin_table(id, columns, flags, height) result(visible)
   !< Begin a table of `columns` columns; when true, fill it and close it with `ig_end_table`. `flags` combine
   !< `ImGuiTableFlags_*` with `ior` (default: borders, alternating row background, resizable columns); `height`
   !< [pixels] fixes the table's height (with `ImGuiTableFlags_ScrollY`, the rows scroll inside it).
   character(len=*), intent(in)           :: id      !< Id of the table (not shown).
   integer(int32),   intent(in)           :: columns !< Columns (1 to 512).
   integer(int32),   intent(in), optional :: flags   !< `ImGuiTableFlags_*`.
   real(real64),     intent(in), optional :: height  !< Height [pixels] (default: fit the rows).
   logical                                :: visible !< The table is drawn.
   integer(c_int)                         :: f       !< Flags.
   type(im_vec2)                          :: outer   !< Outer size.

   visible = .false.
   if (figure_draw_refused('ig_begin_table')) return ! a task does not draw
   f = ior(ior(ImGuiTableFlags_Borders, ImGuiTableFlags_RowBg), ImGuiTableFlags_Resizable)
   if (present(flags)) f = int(flags, c_int)
   outer = im_vec2(0.0_c_float, 0.0_c_float)
   if (present(height)) outer%y = real(height, c_float)
   visible = logical(igBeginTable(cstr(id), int(columns, c_int), f, outer, 0.0_c_float))
   call figure_scope_open(SCOPE_TABLE, 'ig_begin_table', id, visible)
   endfunction ig_begin_table

   recursive subroutine ig_end_table()
   !< End a table (only after `ig_begin_table` returned true).
   if (figure_scope_refused(SCOPE_TABLE, 'ig_end_table')) return ! a task, no frame, or not the innermost scope
   call igEndTable()
   endsubroutine ig_end_table

   recursive subroutine ig_table_setup_column(label, width)
   !< Declare the next column (before the first row): its header label and, with `width` [pixels], a fixed width
   !< (default: the columns share the width left).
   character(len=*), intent(in)           :: label !< Header label.
   real(real64),     intent(in), optional :: width !< Fixed width [pixels].

   if (figure_draw_refused('ig_table_setup_column')) return ! a task does not draw
   if (present(width)) then
      call igTableSetupColumn(cstr(label), ImGuiTableColumnFlags_WidthFixed, real(width, c_float), 0_c_int)
   else
      call igTableSetupColumn(cstr(label), ImGuiTableColumnFlags_WidthStretch, 0.0_c_float, 0_c_int)
   endif
   endsubroutine ig_table_setup_column

   recursive subroutine ig_table_headers_row()
   !< A row with the labels of the columns declared by `ig_table_setup_column` (click a header to resize, ...).
   if (figure_draw_refused('ig_table_headers_row')) return ! a task does not draw
   call igTableHeadersRow()
   endsubroutine ig_table_headers_row

   recursive subroutine ig_table_next_row()
   !< Start a new row.
   if (figure_draw_refused('ig_table_next_row')) return ! a task does not draw
   call igTableNextRow(0_c_int, 0.0_c_float)
   endsubroutine ig_table_next_row

   recursive subroutine ig_table_next_column()
   !< Move to the next cell of the row (the first after `ig_table_next_row`); the widgets that follow go in it.
   if (figure_draw_refused('ig_table_next_column')) return ! a task does not draw
   if (igTableNextColumn()) continue
   endsubroutine ig_table_next_column

   recursive subroutine ig_table_set_column(column)
   !< Move to cell `column` (1 to the number of columns) of the current row.
   integer(int32), intent(in) :: column !< Column, 1-based.

   if (figure_draw_refused('ig_table_set_column')) return ! a task does not draw
   if (igTableSetColumnIndex(int(column - 1_int32, c_int))) continue
   endsubroutine ig_table_set_column

   recursive subroutine ig_push_id_str(id)
   !< Open an id scope named `id`: widgets with the same label in different scopes are different widgets.
   character(len=*), intent(in) :: id !< Scope name.

   if (figure_draw_refused('ig_push_id')) return ! a task does not draw
   call igPushID_Str(cstr(id))
   call figure_scope_open(SCOPE_ID, 'ig_push_id', id)
   endsubroutine ig_push_id_str

   recursive subroutine ig_push_id_i32(id)
   !< Open an id scope numbered `id` (rows of a table, items of a loop).
   integer(int32), intent(in) :: id !< Scope number.

   if (figure_draw_refused('ig_push_id')) return ! a task does not draw
   call igPushID_Int(int(id, c_int))
   call figure_scope_open(SCOPE_ID, 'ig_push_id', '', aux=id) ! the record prints the number only for a message
   endsubroutine ig_push_id_i32

   recursive subroutine ig_pop_id()
   !< Close the id scope opened by the last `ig_push_id`.
   if (figure_scope_refused(SCOPE_ID, 'ig_pop_id')) return ! a task, no frame, or not the innermost scope
   call igPopID()
   endsubroutine ig_pop_id

   recursive subroutine ig_begin_group()
   !< Begin a group (Dear ImGui's `BeginGroup`): the items up to `ig_end_group` are laid out as usual, then count as
   !< one item, their bounding rectangle: `ig_same_line` after `ig_end_group` puts the next item beside the whole group,
   !< `ig_last_item` reports its rectangle (hovered when one of its items is, edited when one of them changed). Always
   !< paired with `ig_end_group`, in the same window; a group nests and closes innermost first. No frame open or a task:
   !< nothing done (a usage error, reported by `app%next_frame`). The same in window, headless and remote mode.
   if (figure_draw_refused('ig_begin_group')) return ! a task does not draw
   call igBeginGroup()
   call figure_scope_open(SCOPE_GROUP, 'ig_begin_group', '')
   endsubroutine ig_begin_group

   recursive subroutine ig_end_group()
   !< End the group begun by the last `ig_begin_group`.
   if (figure_scope_refused(SCOPE_GROUP, 'ig_end_group')) return ! a task, no frame, or not the innermost scope
   call igEndGroup()
   endsubroutine ig_end_group

   recursive subroutine ig_align_begin(id, where, stat)
   !< Begin a group centred (`where='centre'`) or right-aligned (`'right'`) in the space left on the line of the current
   !< window or region: buttons at the right of a dialog, a title in the middle. The group's width is the one it had on
   !< the previous frame, kept in Dear ImGui's storage of the window under `id` (a name unique in the window): on the
   !< first frame it is drawn where a group starts (at the left), and FIGURE asks for one more frame (under lazy redraw
   !< too), which draws it in place; so does a frame on which its width changed (a font size). Always paired with
   !< `ig_align_end`, as `ig_begin_group`; the group counts as one item. An unknown `where`: the group is begun, not
   !< moved, and `FIG_ERR_ARGUMENT` is returned in `stat` (or `error stop` without it). No frame open or a task:
   !< nothing begun, `FIG_ERR_STATE` (end it neither). The same in window, headless and remote mode.
   character(len=*), intent(in)            :: id    !< Name of the group, unique in its window.
   character(len=*), intent(in)            :: where !< 'centre' or 'right'.
   integer(int32),   intent(out), optional :: stat  !< Status.
   integer(c_int)                          :: w     !< 1 centre, 2 right, 0 unknown.
   integer(c_int)                          :: s     !< Native status.

   if (figure_draw_refused('ig_align_begin', stat)) return ! a task does not draw
   w = align_where(where)
   s = fig_align_begin(id, len(id, c_int), w)
   if (s /= FIG_OK) then
      call figure_check(s, stat)
      return
   endif
   call figure_scope_open(SCOPE_ALIGN, 'ig_align_begin', id)
   if (w == 0_c_int) then
      call figure_fail(FIG_ERR_ARGUMENT, "ig_align_begin: where is 'centre' or 'right', not '"//where// &
                       "' (the group is begun, not moved)", stat)
      return
   endif
   if (present(stat)) stat = FIG_OK
   endsubroutine ig_align_begin

   recursive subroutine ig_align_end()
   !< End the group begun by the last `ig_align_begin`; its width is kept for the next frame.
   if (figure_scope_refused(SCOPE_ALIGN, 'ig_align_end')) return ! a task, no frame, or not the innermost scope
   call fig_align_end()
   endsubroutine ig_align_end

   recursive subroutine ig_align_next(width, where, stat)
   !< Centre (`where='centre'`) or right-align (`'right'`) the next item, `width` pixels wide, in the space left on the
   !< line: for an item whose width the program knows (`ig_set_next_item_width`, a button of a given width,
   !< `ig_text_size` of a text), right on the first frame. Nothing moves when the item is wider than the space. A
   !< negative or NaN `width` or an unknown `where`: nothing done, `FIG_ERR_ARGUMENT` in `stat` (or `error stop`
   !< without it); no frame open or a task: `FIG_ERR_STATE`. The same in window, headless and remote mode.
   real(real64),     intent(in)            :: width !< Width of the next item [pixels].
   character(len=*), intent(in)            :: where !< 'centre' or 'right'.
   integer(int32),   intent(out), optional :: stat  !< Status.
   integer(c_int)                          :: w     !< 1 centre, 2 right, 0 unknown.
   character(len=32)                       :: text  !< The width, written.

   if (figure_draw_refused('ig_align_next', stat)) return ! a task does not draw
   w = align_where(where)
   if (w == 0_c_int) then
      call figure_fail(FIG_ERR_ARGUMENT, "ig_align_next: where is 'centre' or 'right', not '"//where//"'", stat)
      return
   endif
   if (ieee_is_nan(width)) then                     ! tested apart: a comparison would signal
      call figure_fail(FIG_ERR_ARGUMENT, 'ig_align_next: width NaN is not a width', stat)
      return
   endif
   if (width < 0.0_real64) then
      write(text, '(G0)') width
      call figure_fail(FIG_ERR_ARGUMENT, 'ig_align_next: width '//trim(text)//' is negative', stat)
      return
   endif
   call fig_align_next(real(width, c_double), w)
   if (present(stat)) stat = FIG_OK
   endsubroutine ig_align_next

   pure function align_where(where) result(w)
   !< `where` of the alignment calls: 1 'centre', 2 'right', 0 anything else.
   character(len=*), intent(in) :: where !< 'centre' or 'right'.
   integer(c_int)               :: w     !< Code.

   select case (where)
   case ('centre')
      w = 1_c_int
   case ('right')
      w = 2_c_int
   case default
      w = 0_c_int
   endselect
   endfunction align_where

   recursive subroutine ig_begin_disabled(disabled)
   !< Widgets up to `ig_end_disabled` are greyed out and ignore input (when `disabled`, default true).
   logical, intent(in), optional :: disabled !< Disable (default true).
   logical(c_bool)               :: d        !< C copy.

   if (figure_draw_refused('ig_begin_disabled')) return ! a task does not draw
   d = .true._c_bool
   if (present(disabled)) d = logical(disabled, c_bool)
   call igBeginDisabled(d)
   call figure_scope_open(SCOPE_DISABLED, 'ig_begin_disabled', '')
   endsubroutine ig_begin_disabled

   recursive subroutine ig_end_disabled()
   !< End the block opened by `ig_begin_disabled`.
   if (figure_scope_refused(SCOPE_DISABLED, 'ig_end_disabled')) return ! a task, no frame, or no block open
   call igEndDisabled()
   endsubroutine ig_end_disabled
endmodule figure_group
