!< figure_group, widgets that group other widgets: child regions, headers, tabs, tables, id scopes, disabled blocks.
module figure_group
!< figure_group, widgets that group other widgets: child regions, headers, tabs, tables, id scopes, disabled blocks.
!<
!< Pairing rules (Dear ImGui's): `ig_end_tab_bar` only when `ig_begin_tab_bar` returned true, `ig_end_tab` only when
!< `ig_begin_tab` returned true, `ig_end_table` only when `ig_begin_table` returned true (unlike `ig_begin`/`ig_end`,
!< always paired); `ig_pop_id` after every `ig_push_id`, `ig_end_disabled` after every `ig_begin_disabled`,
!< `ig_end_child` after every `ig_begin_child`. A collapsing header needs no end call.
!<
!< A table: `ig_begin_table`, then optionally one `ig_table_setup_column` per column and `ig_table_headers_row`, then
!< per row `ig_table_next_row` and per cell `ig_table_next_column` (or `ig_table_set_column`) before its widgets.
!< Widgets repeated on every row need an id scope per row (`ig_push_id(row)`) or distinct labels.
use, intrinsic :: iso_c_binding, only : c_bool, c_float, c_int, c_loc, c_null_ptr, c_ptr
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure_base, only : cstr
use figure_cimgui, only : igBeginChild_Str, igEndChild, im_vec2, igBeginDisabled, igBeginTabBar, igBeginTabItem, &
                          igBeginTable,                                                                         &
                          igCollapsingHeader_TreeNodeFlags, igEndDisabled, igEndTabBar, igEndTabItem, igEndTable, &
                          igPopID, igPushID_Int, igPushID_Str, igTableHeadersRow, igTableNextColumn, igTableNextRow, &
                          igTableSetColumnIndex, igTableSetupColumn
use figure_cimgui_enums, only : ImGuiTableColumnFlags_WidthFixed, ImGuiTableColumnFlags_WidthStretch,        &
                                ImGuiTableFlags_Borders, ImGuiTableFlags_Resizable, ImGuiTableFlags_RowBg,    &
                                ImGuiTreeNodeFlags_DefaultOpen, ImGuiChildFlags_Borders

implicit none
private
public :: ig_collapsing_header, ig_begin_tab_bar, ig_end_tab_bar, ig_begin_tab, ig_end_tab, ig_push_id, ig_pop_id
public :: ig_begin_disabled, ig_end_disabled
public :: ig_begin_table, ig_end_table, ig_table_setup_column, ig_table_headers_row, ig_table_next_row
public :: ig_table_next_column, ig_table_set_column, ig_begin_child, ig_end_child

interface ig_push_id
   !< Open an id scope, by a string or an integer.
   module procedure ig_push_id_str, ig_push_id_i32
endinterface ig_push_id

contains
   function ig_begin_child(id, width, height, border) result(visible)
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

   extent = im_vec2(0.0_c_float, 0.0_c_float)
   if (present(width)) extent%x = real(width, c_float)
   if (present(height)) extent%y = real(height, c_float)
   flags = 0_c_int
   if (present(border)) then
      if (border) flags = ImGuiChildFlags_Borders
   endif
   visible = logical(igBeginChild_Str(cstr(id), extent, flags, 0_c_int))
   endfunction ig_begin_child

   subroutine ig_end_child()
   !< End the region opened by `ig_begin_child` (whatever it returned).
   call igEndChild()
   endsubroutine ig_end_child

   function ig_collapsing_header(label, default_open) result(open)
   !< A header that shows or hides what follows it; true while open (then draw the content). No end call.
   character(len=*), intent(in)           :: label        !< Label (also its id).
   logical,          intent(in), optional :: default_open !< Open the first time it is shown (default: closed).
   logical                                :: open         !< The header is open.
   integer(c_int)                         :: flags        !< ImGuiTreeNodeFlags.

   flags = 0_c_int
   if (present(default_open)) then
      if (default_open) flags = ImGuiTreeNodeFlags_DefaultOpen
   endif
   open = logical(igCollapsingHeader_TreeNodeFlags(cstr(label), flags))
   endfunction ig_collapsing_header

   function ig_begin_tab_bar(id) result(visible)
   !< Begin a bar of tabs; when true, declare the tabs (`ig_begin_tab`) and close it with `ig_end_tab_bar`.
   character(len=*), intent(in) :: id      !< Id of the bar (not shown).
   logical                      :: visible !< The bar is drawn.

   visible = logical(igBeginTabBar(cstr(id), 0_c_int))
   endfunction ig_begin_tab_bar

   subroutine ig_end_tab_bar()
   !< End a bar of tabs (only after `ig_begin_tab_bar` returned true).
   call igEndTabBar()
   endsubroutine ig_end_tab_bar

   function ig_begin_tab(label, open) result(selected)
   !< A tab of the current bar; true when it is the selected one: draw its content, then `ig_end_tab`. With `open`,
   !< the tab has a close button that sets it false.
   character(len=*), intent(in)              :: label    !< Label (also its id).
   logical,          intent(inout), optional :: open     !< Tab open.
   logical                                   :: selected !< The tab is selected.
   logical(c_bool), target                   :: o        !< C copy of `open`.
   type(c_ptr)                               :: p        !< bool* or null.

   p = c_null_ptr
   if (present(open)) then
      o = logical(open, c_bool)
      p = c_loc(o)
   endif
   selected = logical(igBeginTabItem(cstr(label), p, 0_c_int))
   if (present(open)) open = logical(o)
   endfunction ig_begin_tab

   subroutine ig_end_tab()
   !< End the content of a tab (only after `ig_begin_tab` returned true).
   call igEndTabItem()
   endsubroutine ig_end_tab

   function ig_begin_table(id, columns, flags, height) result(visible)
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

   f = ior(ior(ImGuiTableFlags_Borders, ImGuiTableFlags_RowBg), ImGuiTableFlags_Resizable)
   if (present(flags)) f = int(flags, c_int)
   outer = im_vec2(0.0_c_float, 0.0_c_float)
   if (present(height)) outer%y = real(height, c_float)
   visible = logical(igBeginTable(cstr(id), int(columns, c_int), f, outer, 0.0_c_float))
   endfunction ig_begin_table

   subroutine ig_end_table()
   !< End a table (only after `ig_begin_table` returned true).
   call igEndTable()
   endsubroutine ig_end_table

   subroutine ig_table_setup_column(label, width)
   !< Declare the next column (before the first row): its header label and, with `width` [pixels], a fixed width
   !< (default: the columns share the width left).
   character(len=*), intent(in)           :: label !< Header label.
   real(real64),     intent(in), optional :: width !< Fixed width [pixels].

   if (present(width)) then
      call igTableSetupColumn(cstr(label), ImGuiTableColumnFlags_WidthFixed, real(width, c_float), 0_c_int)
   else
      call igTableSetupColumn(cstr(label), ImGuiTableColumnFlags_WidthStretch, 0.0_c_float, 0_c_int)
   endif
   endsubroutine ig_table_setup_column

   subroutine ig_table_headers_row()
   !< A row with the labels of the columns declared by `ig_table_setup_column` (click a header to resize, ...).
   call igTableHeadersRow()
   endsubroutine ig_table_headers_row

   subroutine ig_table_next_row()
   !< Start a new row.
   call igTableNextRow(0_c_int, 0.0_c_float)
   endsubroutine ig_table_next_row

   subroutine ig_table_next_column()
   !< Move to the next cell of the row (the first after `ig_table_next_row`); the widgets that follow go in it.
   if (igTableNextColumn()) continue
   endsubroutine ig_table_next_column

   subroutine ig_table_set_column(column)
   !< Move to cell `column` (1 to the number of columns) of the current row.
   integer(int32), intent(in) :: column !< Column, 1-based.

   if (igTableSetColumnIndex(int(column - 1_int32, c_int))) continue
   endsubroutine ig_table_set_column

   subroutine ig_push_id_str(id)
   !< Open an id scope named `id`: widgets with the same label in different scopes are different widgets.
   character(len=*), intent(in) :: id !< Scope name.

   call igPushID_Str(cstr(id))
   endsubroutine ig_push_id_str

   subroutine ig_push_id_i32(id)
   !< Open an id scope numbered `id` (rows of a table, items of a loop).
   integer(int32), intent(in) :: id !< Scope number.

   call igPushID_Int(int(id, c_int))
   endsubroutine ig_push_id_i32

   subroutine ig_pop_id()
   !< Close the id scope opened by the last `ig_push_id`.
   call igPopID()
   endsubroutine ig_pop_id

   subroutine ig_begin_disabled(disabled)
   !< Widgets up to `ig_end_disabled` are greyed out and ignore input (when `disabled`, default true).
   logical, intent(in), optional :: disabled !< Disable (default true).
   logical(c_bool)               :: d        !< C copy.

   d = .true._c_bool
   if (present(disabled)) d = logical(disabled, c_bool)
   call igBeginDisabled(d)
   endsubroutine ig_begin_disabled

   subroutine ig_end_disabled()
   !< End the block opened by `ig_begin_disabled`.
   call igEndDisabled()
   endsubroutine ig_end_disabled
endmodule figure_group
