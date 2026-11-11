!< figure_menu, menus, popups and keyboard shortcuts.
module figure_menu
!< figure_menu, menus, popups and keyboard shortcuts.
!<
!< Every drawing procedure of this module refuses a call from a task (`FIG_ERR_STATE`): see processes.md; and a call
!< with no frame open, a usage error (`FIG_ERR_STATE`, `<procedure>: no frame open`). Every begin/end and push/pop
!< pair registers in the scope record of the frame, which checks each end before Dear ImGui sees it: a wrong end is
!< refused and reported by `app%next_frame` (`app%set_checks`; errors.md, "Pairing and frames").
!<
!< Pairing (Dear ImGui's): each `ig_end_*` only after its `ig_begin_*` returned true. A window's own menu bar needs the
!< window flag `ImGuiWindowFlags_MenuBar` in its `ig_begin`. A menu item's shortcut text is only shown: the program
!< reacts to the keys with `ig_shortcut`, every frame, outside the menu (the menu is closed most of the time).
!<
!< Shortcuts are routed (Dear ImGui's `Shortcut`): a chord goes to one place, by the call's scope: 'focused' (the
!< default) to the focused window, 'global' wherever the focus is, 'item' to the item being edited or held; 'always'
!< is not routed (Dear ImGui's `IsKeyChordPressed`): every call fires; see menus.md, "Shortcuts".
!<
!< A popup is opened once, by an event (`ig_open_popup`, not every frame), and declared every frame
!< (`ig_begin_popup`/`ig_begin_popup_modal`, then `ig_end_popup` only when the begin returned true); it closes when
!< the user clicks outside it (a plain popup) or when the program calls `ig_close_current_popup` inside it. Open and
!< begin must use the same id in the same id scope (the same window). A context menu (`ig_begin_popup_context`) opens
!< itself, on a click of the right button over an item, a window's empty space or the display's background.
use, intrinsic :: iso_c_binding, only : c_bool, c_char, c_int, c_loc, c_null_char, c_null_ptr
use, intrinsic :: iso_fortran_env, only : int32
use figure_base, only : cstr, figure_check, figure_draw_refused, figure_fail, figure_scope_open, figure_scope_refused, &
                        SCOPE_MAIN_MENU_BAR, SCOPE_MENU, SCOPE_MENU_BAR, SCOPE_POPUP
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_OK, fig_set_next_item_shortcut, fig_shortcut
use figure_cimgui, only : igBeginMainMenuBar, igBeginMenu, igBeginMenuBar, igEndMainMenuBar, igEndMenu, igEndMenuBar, &
                          igMenuItem_BoolPtr, igBeginPopup, igBeginPopupModal,         &
                          igCloseCurrentPopup, igEndPopup, igOpenPopup_Str, igBeginPopupContextItem,          &
                          igBeginPopupContextVoid, igBeginPopupContextWindow
use figure_cimgui_enums, only : ImGuiWindowFlags_AlwaysAutoResize, ImGuiPopupFlags_MouseButtonLeft,           &
                                ImGuiPopupFlags_MouseButtonMiddle, ImGuiPopupFlags_MouseButtonRight,          &
                                ImGuiPopupFlags_NoOpenOverItems

implicit none
private
public :: ig_begin_main_menu_bar, ig_end_main_menu_bar, ig_begin_menu_bar, ig_end_menu_bar, ig_begin_menu, ig_end_menu
public :: ig_menu_item, ig_set_next_item_shortcut, ig_shortcut
public :: ig_open_popup, ig_begin_popup, ig_begin_popup_modal, ig_end_popup, ig_close_current_popup
public :: ig_begin_popup_context

contains
   recursive function ig_begin_main_menu_bar() result(visible)
   !< Begin the menu bar along the top of the display; when true, declare menus, then `ig_end_main_menu_bar`.
   logical :: visible !< The bar is drawn.

   visible = .false.
   if (figure_draw_refused('ig_begin_main_menu_bar')) return ! a task does not draw
   visible = logical(igBeginMainMenuBar())
   call figure_scope_open(SCOPE_MAIN_MENU_BAR, 'ig_begin_main_menu_bar', '', visible)
   endfunction ig_begin_main_menu_bar

   recursive subroutine ig_end_main_menu_bar()
   !< End the main menu bar (only after `ig_begin_main_menu_bar` returned true).
   if (figure_scope_refused(SCOPE_MAIN_MENU_BAR, 'ig_end_main_menu_bar')) return ! a task, no frame, or not innermost
   call igEndMainMenuBar()
   endsubroutine ig_end_main_menu_bar

   recursive function ig_begin_menu_bar() result(visible)
   !< Begin the current window's menu bar (the window needs `ImGuiWindowFlags_MenuBar`); then `ig_end_menu_bar`.
   logical :: visible !< The bar is drawn.

   visible = .false.
   if (figure_draw_refused('ig_begin_menu_bar')) return ! a task does not draw
   visible = logical(igBeginMenuBar())
   call figure_scope_open(SCOPE_MENU_BAR, 'ig_begin_menu_bar', '', visible)
   endfunction ig_begin_menu_bar

   recursive subroutine ig_end_menu_bar()
   !< End the window's menu bar (only after `ig_begin_menu_bar` returned true).
   if (figure_scope_refused(SCOPE_MENU_BAR, 'ig_end_menu_bar')) return ! a task, no frame, or not the innermost scope
   call igEndMenuBar()
   endsubroutine ig_end_menu_bar

   recursive function ig_begin_menu(label, enabled) result(open)
   !< A menu of a menu bar (or a submenu of a menu); true while it is open: declare its items, then `ig_end_menu`.
   character(len=*), intent(in)           :: label   !< Label (also its id).
   logical,          intent(in), optional :: enabled !< The menu can be opened (default true).
   logical                                :: open    !< The menu is open.
   logical(c_bool)                        :: e       !< C copy of `enabled`.

   open = .false.
   if (figure_draw_refused('ig_begin_menu')) return ! a task does not draw
   e = .true._c_bool
   if (present(enabled)) e = logical(enabled, c_bool)
   open = logical(igBeginMenu(cstr(label), e))
   call figure_scope_open(SCOPE_MENU, 'ig_begin_menu', label, open)
   endfunction ig_begin_menu

   recursive subroutine ig_end_menu()
   !< End a menu (only after `ig_begin_menu` returned true).
   if (figure_scope_refused(SCOPE_MENU, 'ig_end_menu')) return ! a task, no frame, or not the innermost scope
   call igEndMenu()
   endsubroutine ig_end_menu

   recursive function ig_menu_item(label, shortcut, selected, enabled) result(picked)
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

   picked = .false.
   if (figure_draw_refused('ig_menu_item')) return ! a task does not draw
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

   recursive function ig_shortcut(keys, scope, repeat, stat) result(pressed)
   !< True on the frame the key chord `keys` is pressed and routed to this call, e.g. `'ctrl+s'`, `'ctrl+shift+z'`,
   !< `'f5'`, `'escape'`: modifiers (`ctrl`, `shift`, `alt`, `super`) and one key, by the names of `test_key`, joined
   !< by `+`. On macOS `ctrl` is the cmd key (Dear ImGui follows the platform), so `'ctrl+s'` is cmd+s there. Call it
   !< every frame (a route is taken for the next frame), outside menus.
   !<
   !< `scope` (Dear ImGui's `ImGuiInputFlags_Route*`): `'focused'` (default) fires when the calling window, or a window
   !< inside it, has the focus; called outside every window it fires unless a focused window routes the same chord.
   !< While a text field is edited, a focused chord of a key alone or with shift (other than f1-f24) does not fire.
   !< `'global'` fires whatever window has the focus, before the focused ones. `'item'` fires while the item drawn
   !< just before the call is active (a text field being edited, a button held). Of two `'global'` calls of one chord
   !< in different windows, the first of the frame fires. `'always'` is not routed (v0.3's behaviour): every call of
   !< the chord fires, whatever has the focus, a text field being edited included.
   !<
   !< An unknown key or scope: false, and `FIG_ERR_ARGUMENT` in `stat` (or `error stop` without it); no frame open or a
   !< task: `FIG_ERR_STATE`. The same in window, headless (keys of `test_key`) and remote mode (the browser's keys).
   character(len=*), intent(in)            :: keys    !< Key chord.
   character(len=*), intent(in),  optional :: scope   !< 'focused' (default), 'global', 'item' or 'always'.
   logical,          intent(in),  optional :: repeat  !< Fire again while the chord is held (default false: once).
   integer(int32),   intent(out), optional :: stat    !< Status.
   logical                                 :: pressed !< Pressed this frame.
   integer(c_int)                          :: rep     !< C copy of `repeat`.
   integer(c_int)                          :: fired   !< 1 when it fired.
   integer(c_int)                          :: status  !< Status of the call.

   pressed = .false.
   if (figure_draw_refused('ig_shortcut', stat)) return ! a task does not draw
   rep = 0_c_int
   if (present(repeat)) rep = merge(1_c_int, 0_c_int, repeat)
   fired = 0_c_int
   if (present(scope)) then
      status = fig_shortcut(keys, len(keys, c_int), scope, len(scope, c_int), rep, fired)
   else
      status = fig_shortcut(keys, len(keys, c_int), 'focused', 7_c_int, rep, fired)
   endif
   call figure_check(status, stat)
   pressed = fired /= 0_c_int
   endfunction ig_shortcut

   recursive subroutine ig_set_next_item_shortcut(keys, scope, stat)
   !< The next item owns the key chord `keys` (as `ig_shortcut`'s, e.g. `'ctrl+r'`): the chord presses it (a button
   !< reports the press, a text field takes the keyboard), and its tooltip shows the chord. Call it just before the
   !< item, every frame. `scope` (Dear ImGui's `ImGuiInputFlags_Route*`): `'focused'` (default) while the item's window
   !< has the focus, `'global'` wherever the focus is; while a text field is edited, a focused chord of a key alone or
   !< with shift (other than f1-f24) is not given. An unknown key or scope (`'item'` and `'always'` included: the item
   !< owns the chord through a route) is refused with `FIG_ERR_ARGUMENT` in `stat` (or `error stop` without it), and
   !< the item has no chord; no frame open or a task: `FIG_ERR_STATE`. The same in window, headless and remote mode.
   character(len=*), intent(in)            :: keys   !< Key chord.
   character(len=*), intent(in),  optional :: scope  !< 'focused' (default) or 'global'.
   integer(int32),   intent(out), optional :: stat   !< Status.
   integer(c_int)                          :: status !< Status of the call.

   if (figure_draw_refused('ig_set_next_item_shortcut', stat)) return ! a task does not draw
   if (present(scope)) then
      status = fig_set_next_item_shortcut(keys, len(keys, c_int), scope, len(scope, c_int))
   else
      status = fig_set_next_item_shortcut(keys, len(keys, c_int), 'focused', 7_c_int)
   endif
   call figure_check(status, stat)
   endsubroutine ig_set_next_item_shortcut

   recursive subroutine ig_open_popup(id)
   !< Open the popup `id` (call once, on the event that opens it: a click, a quit request; not every frame).
   character(len=*), intent(in) :: id !< Popup id, as given to `ig_begin_popup` or `ig_begin_popup_modal`.

   if (figure_draw_refused('ig_open_popup')) return ! a task does not draw
   if (igOpenPopup_Str(cstr(id), 0_c_int)) continue
   endsubroutine ig_open_popup

   recursive function ig_begin_popup(id) result(open)
   !< A popup (no title bar), declared every frame; true while open: declare its content, then `ig_end_popup`. It
   !< closes when the user clicks outside it.
   character(len=*), intent(in) :: id   !< Popup id.
   logical                      :: open !< The popup is open.

   open = .false.
   if (figure_draw_refused('ig_begin_popup')) return ! a task does not draw
   open = logical(igBeginPopup(cstr(id), 0_c_int))
   call figure_scope_open(SCOPE_POPUP, 'ig_begin_popup', id, open)
   endfunction ig_begin_popup

   recursive function ig_begin_popup_modal(title, open) result(shown)
   !< A modal dialog titled `title` (also its id), declared every frame; true while open: the rest of the interface
   !< is greyed out and ignores input until it closes (`ig_close_current_popup`, inside it). With `open`, a close
   !< button in its title bar sets it false. Its size fits its content.
   character(len=*), intent(in)              :: title !< Title and id.
   logical,          intent(inout), optional :: open  !< Close button.
   logical                                   :: shown !< The dialog is open.
   logical(c_bool), target                   :: o     !< C copy of `open`.

   shown = .false.
   if (figure_draw_refused('ig_begin_popup_modal')) return ! a task does not draw
   if (present(open)) then
      o = logical(open, c_bool)
      shown = logical(igBeginPopupModal(cstr(title), c_loc(o), ImGuiWindowFlags_AlwaysAutoResize))
      open = logical(o)
   else
      shown = logical(igBeginPopupModal(cstr(title), c_null_ptr, ImGuiWindowFlags_AlwaysAutoResize))
   endif
   call figure_scope_open(SCOPE_POPUP, 'ig_begin_popup_modal', title, shown)
   endfunction ig_begin_popup_modal

   recursive function ig_begin_popup_context(id, on, button, stat) result(open)
   !< A context menu (Dear ImGui's `BeginPopupContextItem`, `BeginPopupContextWindow`, `BeginPopupContextVoid`):
   !< declared every frame, it opens itself when the user releases `button` over the place `on` says, and is true
   !< while open: declare its entries (`ig_menu_item`, any widget), then `ig_end_popup` only after true. It closes on a
   !< pick of an `ig_menu_item`, on `ig_close_current_popup`, or on a click outside it.
   !<
   !< `on`: `'item'` (default), the item drawn just before the call (a row, a node, a text: any item, interactive or
   !< not); `'window'`, the current window's empty space, not over its items (so items keep their own menus); `'void'`,
   !< the display's background, where no window is (call it outside every window). `id` names the menu in the current
   !< id scope: `ig_open_popup(id)` in the same window opens it too (a key, a button). An unknown `on` or `button`:
   !< false, `FIG_ERR_ARGUMENT` in `stat` (or `error stop` without it); no frame open or a task: false,
   !< `FIG_ERR_STATE`. The same in window, headless (`test_click(..., button='right')`) and remote mode.
   character(len=*), intent(in)            :: id     !< Menu id.
   character(len=*), intent(in),  optional :: on     !< 'item' (default), 'window' or 'void'.
   character(len=*), intent(in),  optional :: button !< Mouse button: 'right' (default), 'left' or 'middle'.
   integer(int32),   intent(out), optional :: stat   !< Status.
   logical                                 :: open   !< The menu is open.
   integer(c_int)                          :: flags  !< Dear ImGui's popup flags.
   character(len=:), allocatable           :: where  !< `on`, or its default.
   character(kind=c_char, len=1), allocatable, target :: cid(:) !< `id`, NUL-terminated.
   integer                                 :: i      !< Character.

   open = .false.
   if (figure_draw_refused('ig_begin_popup_context', stat)) return ! a task does not draw
   flags = ImGuiPopupFlags_MouseButtonRight
   if (present(button)) then
      select case (button)
      case ('right')
      case ('left')
         flags = ImGuiPopupFlags_MouseButtonLeft
      case ('middle')
         flags = ImGuiPopupFlags_MouseButtonMiddle
      case default
         call figure_fail(FIG_ERR_ARGUMENT, 'ig_begin_popup_context: unknown button "'//button// &
                          '" (''right'', ''left'' or ''middle'')', stat)
         return
      endselect
   endif
   where = 'item'
   if (present(on)) where = on
   allocate(cid(len(id) + 1))
   do i = 1, len(id)
      cid(i) = id(i:i)
   enddo
   cid(len(id) + 1) = c_null_char
   select case (where)
   case ('item')
      open = logical(igBeginPopupContextItem(c_loc(cid), flags))
   case ('window')
      open = logical(igBeginPopupContextWindow(c_loc(cid), ior(flags, ImGuiPopupFlags_NoOpenOverItems)))
   case ('void')
      open = logical(igBeginPopupContextVoid(c_loc(cid), flags))
   case default
      call figure_fail(FIG_ERR_ARGUMENT, 'ig_begin_popup_context: unknown place "'//where// &
                       '" (''item'', ''window'' or ''void'')', stat)
      return
   endselect
   if (present(stat)) stat = int(FIG_OK, int32)
   call figure_scope_open(SCOPE_POPUP, 'ig_begin_popup_context', id, open)
   endfunction ig_begin_popup_context

   recursive subroutine ig_end_popup()
   !< End a popup, context menu or modal (only after its begin returned true).
   if (figure_scope_refused(SCOPE_POPUP, 'ig_end_popup')) return ! a task, no frame, or not the innermost scope
   call igEndPopup()
   endsubroutine ig_end_popup

   recursive subroutine ig_close_current_popup()
   !< Close the popup or modal being declared (call it inside, e.g. when its OK button is pressed).
   if (figure_draw_refused('ig_close_current_popup')) return ! a task does not draw
   call igCloseCurrentPopup()
   endsubroutine ig_close_current_popup
endmodule figure_menu
