!< figure_menu, menus, popups and keyboard shortcuts.
module figure_menu
!< figure_menu, menus, popups and keyboard shortcuts.
!<
!< Pairing (Dear ImGui's): each `ig_end_*` only after its `ig_begin_*` returned true. A window's own menu bar needs the
!< window flag `ImGuiWindowFlags_MenuBar` in its `ig_begin`. A menu item's shortcut text is only shown: the program
!< reacts to the keys with `ig_shortcut`, every frame, outside the menu (the menu is closed most of the time).
!<
!< A popup is opened once, by an event (`ig_open_popup`, not every frame), and declared every frame
!< (`ig_begin_popup`/`ig_begin_popup_modal`, then `ig_end_popup` only when the begin returned true); it closes when
!< the user clicks outside it (a plain popup) or when the program calls `ig_close_current_popup` inside it. Open and
!< begin must use the same id in the same id scope (the same window).
use, intrinsic :: iso_c_binding, only : c_bool, c_int, c_loc, c_null_ptr
use, intrinsic :: iso_fortran_env, only : int32
use figure_base, only : cstr, figure_check, figure_refused
use figure_c_native, only : FIG_OK, fig_key_chord
use figure_cimgui, only : igBeginMainMenuBar, igBeginMenu, igBeginMenuBar, igEndMainMenuBar, igEndMenu, igEndMenuBar, &
                          igIsKeyChordPressed_Nil, igMenuItem_BoolPtr, igBeginPopup, igBeginPopupModal,         &
                          igCloseCurrentPopup, igEndPopup, igOpenPopup_Str
use figure_cimgui_enums, only : ImGuiWindowFlags_AlwaysAutoResize

implicit none
private
public :: ig_begin_main_menu_bar, ig_end_main_menu_bar, ig_begin_menu_bar, ig_end_menu_bar, ig_begin_menu, ig_end_menu
public :: ig_menu_item, ig_shortcut
public :: ig_open_popup, ig_begin_popup, ig_begin_popup_modal, ig_end_popup, ig_close_current_popup

contains
   function ig_begin_main_menu_bar() result(visible)
   !< Begin the menu bar along the top of the display; when true, declare menus, then `ig_end_main_menu_bar`.
   logical :: visible !< The bar is drawn.

   visible = .false.
   if (figure_refused('ig_begin_main_menu_bar')) return ! a task does not draw
   visible = logical(igBeginMainMenuBar())
   endfunction ig_begin_main_menu_bar

   subroutine ig_end_main_menu_bar()
   !< End the main menu bar (only after `ig_begin_main_menu_bar` returned true).
   call igEndMainMenuBar()
   endsubroutine ig_end_main_menu_bar

   function ig_begin_menu_bar() result(visible)
   !< Begin the current window's menu bar (the window needs `ImGuiWindowFlags_MenuBar`); then `ig_end_menu_bar`.
   logical :: visible !< The bar is drawn.

   visible = .false.
   if (figure_refused('ig_begin_menu_bar')) return ! a task does not draw
   visible = logical(igBeginMenuBar())
   endfunction ig_begin_menu_bar

   subroutine ig_end_menu_bar()
   !< End the window's menu bar (only after `ig_begin_menu_bar` returned true).
   call igEndMenuBar()
   endsubroutine ig_end_menu_bar

   function ig_begin_menu(label, enabled) result(open)
   !< A menu of a menu bar (or a submenu of a menu); true while it is open: declare its items, then `ig_end_menu`.
   character(len=*), intent(in)           :: label   !< Label (also its id).
   logical,          intent(in), optional :: enabled !< The menu can be opened (default true).
   logical                                :: open    !< The menu is open.
   logical(c_bool)                        :: e       !< C copy of `enabled`.

   e = .true._c_bool
   if (present(enabled)) e = logical(enabled, c_bool)
   open = logical(igBeginMenu(cstr(label), e))
   endfunction ig_begin_menu

   subroutine ig_end_menu()
   !< End a menu (only after `ig_begin_menu` returned true).
   call igEndMenu()
   endsubroutine ig_end_menu

   function ig_menu_item(label, shortcut, selected, enabled) result(picked)
   !< An item of an open menu; true on the frame it is picked (the menu then closes). `shortcut` is shown on the right
   !< (the keys themselves are read with `ig_shortcut`); with `selected`, the item shows a check mark and a pick toggles
   !< it; a disabled item (`enabled=.false.`) is greyed out and cannot be picked.
   character(len=*), intent(in)              :: label    !< Label (also its id).
   character(len=*), intent(in),    optional :: shortcut !< Shortcut text, e.g. `'Ctrl+S'`.
   logical,          intent(inout), optional :: selected !< Check mark, toggled by a pick.
   logical,          intent(in),    optional :: enabled  !< The item can be picked (default true).
   logical                                   :: picked   !< Picked this frame.
   logical(c_bool)                           :: e        !< C copy of `enabled`.
   logical(c_bool), target                   :: s        !< C copy of `selected`.
   character(len=:), allocatable             :: keys     !< Shortcut text, NUL-terminated (empty when absent).

   e = .true._c_bool
   if (present(enabled)) e = logical(enabled, c_bool)
   keys = cstr('')
   if (present(shortcut)) keys = cstr(shortcut)
   if (present(selected)) then
      s = logical(selected, c_bool)
      picked = logical(igMenuItem_BoolPtr(cstr(label), keys, c_loc(s), e))
      selected = logical(s)
   else
      picked = logical(igMenuItem_BoolPtr(cstr(label), keys, c_null_ptr, e))
   endif
   endfunction ig_menu_item

   function ig_shortcut(keys, stat) result(pressed)
   !< True on the frame the key chord `keys` is pressed, e.g. `'ctrl+s'`, `'ctrl+shift+z'`, `'f5'`, `'escape'`:
   !< modifiers (`ctrl`, `shift`, `alt`, `super`) and one key, by the names of `test_key`, joined by `+`. Once per
   !< press, not repeated while held. On macOS `ctrl` is the cmd key (Dear ImGui follows the platform), so `'ctrl+s'`
   !< is cmd+s there. Call it every frame, outside menus. An unknown name: false, and `FIG_ERR_ARGUMENT` in `stat` (or
   !< `error stop` without it).
   character(len=*), intent(in)            :: keys    !< Key chord.
   integer(int32),   intent(out), optional :: stat    !< Status.
   logical                                 :: pressed !< Pressed this frame.
   integer(c_int)                          :: chord   !< ImGuiKeyChord.
   integer(c_int)                          :: status  !< Status of the parse.

   pressed = .false.
   chord = 0_c_int
   status = fig_key_chord(keys, len(keys, c_int), chord)
   call figure_check(status, stat)
   if (status /= FIG_OK) return
   pressed = logical(igIsKeyChordPressed_Nil(chord))
   endfunction ig_shortcut

   subroutine ig_open_popup(id)
   !< Open the popup `id` (call once, on the event that opens it: a click, a quit request; not every frame).
   character(len=*), intent(in) :: id !< Popup id, as given to `ig_begin_popup` or `ig_begin_popup_modal`.

   if (igOpenPopup_Str(cstr(id), 0_c_int)) continue
   endsubroutine ig_open_popup

   function ig_begin_popup(id) result(open)
   !< A popup (no title bar), declared every frame; true while open: declare its content, then `ig_end_popup`. It
   !< closes when the user clicks outside it.
   character(len=*), intent(in) :: id   !< Popup id.
   logical                      :: open !< The popup is open.

   open = .false.
   if (figure_refused('ig_begin_popup')) return ! a task does not draw
   open = logical(igBeginPopup(cstr(id), 0_c_int))
   endfunction ig_begin_popup

   function ig_begin_popup_modal(title, open) result(shown)
   !< A modal dialog titled `title` (also its id), declared every frame; true while open: the rest of the interface
   !< is greyed out and ignores input until it closes (`ig_close_current_popup`, inside it). With `open`, a close
   !< button in its title bar sets it false. Its size fits its content.
   character(len=*), intent(in)              :: title !< Title and id.
   logical,          intent(inout), optional :: open  !< Close button.
   logical                                   :: shown !< The dialog is open.
   logical(c_bool), target                   :: o     !< C copy of `open`.

   shown = .false.
   if (figure_refused('ig_begin_popup_modal')) return ! a task does not draw
   if (present(open)) then
      o = logical(open, c_bool)
      shown = logical(igBeginPopupModal(cstr(title), c_loc(o), ImGuiWindowFlags_AlwaysAutoResize))
      open = logical(o)
   else
      shown = logical(igBeginPopupModal(cstr(title), c_null_ptr, ImGuiWindowFlags_AlwaysAutoResize))
   endif
   endfunction ig_begin_popup_modal

   subroutine ig_end_popup()
   !< End a popup or modal (only after its begin returned true).
   call igEndPopup()
   endsubroutine ig_end_popup

   subroutine ig_close_current_popup()
   !< Close the popup or modal being declared (call it inside, e.g. when its OK button is pressed).
   call igCloseCurrentPopup()
   endsubroutine ig_close_current_popup
endmodule figure_menu
