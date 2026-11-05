!< figure_group, widgets that group other widgets: collapsing headers, tabs, id scopes, disabled blocks.
module figure_group
!< figure_group, widgets that group other widgets: collapsing headers, tabs, id scopes, disabled blocks.
!<
!< Pairing rules (Dear ImGui's): `ig_end_tab_bar` only when `ig_begin_tab_bar` returned true, `ig_end_tab` only when
!< `ig_begin_tab` returned true (unlike `ig_begin`/`ig_end`, always paired); `ig_pop_id` after every `ig_push_id`,
!< `ig_end_disabled` after every `ig_begin_disabled`. A collapsing header needs no end call.
use, intrinsic :: iso_c_binding, only : c_bool, c_int, c_loc, c_null_ptr, c_ptr
use, intrinsic :: iso_fortran_env, only : int32
use figure_base, only : cstr
use figure_cimgui, only : igBeginDisabled, igBeginTabBar, igBeginTabItem, igCollapsingHeader_TreeNodeFlags, &
                          igEndDisabled, igEndTabBar, igEndTabItem, igPopID, igPushID_Int, igPushID_Str
use figure_cimgui_enums, only : ImGuiTreeNodeFlags_DefaultOpen

implicit none
private
public :: ig_collapsing_header, ig_begin_tab_bar, ig_end_tab_bar, ig_begin_tab, ig_end_tab, ig_push_id, ig_pop_id
public :: ig_begin_disabled, ig_end_disabled

interface ig_push_id
   !< Open an id scope, by a string or an integer.
   module procedure ig_push_id_str, ig_push_id_i32
endinterface ig_push_id

contains
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
