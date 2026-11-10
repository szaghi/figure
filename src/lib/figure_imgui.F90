!< figure_imgui, Dear ImGui widgets with Fortran arguments.
module figure_imgui
!< figure_imgui, Dear ImGui widgets with Fortran arguments.
!<
!< Every drawing procedure of this module refuses a call from a task (`FIG_ERR_STATE`): see processes.md; and a call
!< with no frame open, a usage error (`FIG_ERR_STATE`, `<procedure>: no frame open`). Every begin/end and push/pop
!< pair registers in the scope record of the frame, which checks each end before Dear ImGui sees it: a wrong end is
!< refused and reported by `app%next_frame` (`app%set_checks`; errors.md, "Pairing and frames").
!<
!< Immediate mode: call the widgets every frame; each returns what happened this frame (`ig_button` is true on the
!< frame it is clicked, `ig_checkbox` is true when it changed the value). Values are ordinary Fortran
!< variables, updated in place: no handles, no callbacks, no `target` requirements (the C `bool*` of a checkbox is a
!< local copy, written back).
use, intrinsic :: iso_c_binding, only : c_bool, c_char, c_double, c_f_pointer, c_float, c_int, c_loc, c_long_long, &
                                        c_null_char, c_null_ptr, c_ptr
use, intrinsic :: ieee_arithmetic, only : ieee_is_nan
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use figure_base, only : cstr, figure_check, figure_draw_refused, figure_fail, figure_refused, figure_scope_open, &
                        figure_scope_refused, SCOPE_ITEM_WIDTH, SCOPE_TOOLTIP, SCOPE_WINDOW
use figure_c_native, only : fig_begin_side_bar, fig_texture_sampling, fig_tool_button, fig_widget_input_text, &
                            fig_text_get, fig_text_length, fig_text_release, fig_text_set, fig_widget_input_text_multiline, &
                            fig_get_clipboard, fig_set_clipboard, fig_item_status, fig_last_item, fig_mark_last_item_edited, &
                            fig_items_tooltip, FIG_ERR_ARGUMENT, FIG_OK
use figure_texture, only : texture_object, texture_ref
use figure_cimgui, only : igGetTime, igProgressBar, &
                          im_vec2, igBegin, igBeginCombo, igBeginItemTooltip, igEndCombo, igEndTooltip, igPopID, &
                          igPushID_Int, igSelectable_Bool, igSetItemDefaultFocus, igButton, igCheckbox, igEnd, &
                          igGetItemRectMax, igGetItemRectMin, igImage, igSameLine, &
                          igSeparator, igSetNextItemWidth, igSetNextWindowPos, igSetNextWindowSize, igShowDemoWindow, &
                          igTextUnformatted, im_vec4, igGetStyleColorVec4, igPopStyleColor, &
                          igPopTextWrapPos, igPushStyleColor_Vec4, igPushTextWrapPos, igAlignTextToFramePadding, &
                          igIsPopupOpen_Str, igSetWindowFocus_Str, igCalcTextSize, igColorEdit4, igIsAnyItemActive, &
                          igIsAnyItemHovered, igIsItemHovered, igGetCursorStartPos, igGetScrollMaxX, igGetScrollMaxY, &
                          igGetScrollX, igGetScrollY, igSetKeyboardFocusHere, igSetScrollFromPosX_Float,           &
                          igSetScrollFromPosY_Float, igSetScrollHereX, igSetScrollHereY, igSetScrollX_Float,       &
                          igSetScrollY_Float, igDummy, igGetContentRegionAvail, igGetFontSize, igGetFrameHeight, &
                          igGetFrameHeightWithSpacing, igGetTextLineHeight, igGetTextLineHeightWithSpacing,          &
                          igIndent, igNewLine, igPopItemWidth, igPushItemWidth, igSeparatorText, igSpacing, igUnindent, &
                          igBeginTooltip, igTextLink, igTextLinkOpenURL
use figure_cimgui_enums, only : ImGuiCond_Always, ImGuiCond_FirstUseEver, &
                                ImGuiCol_Text, ImGuiCol_TextDisabled, ImGuiPopupFlags_AnyPopup, &
                                ImGuiInputTextFlags_AllowTabInput, ImGuiInputTextFlags_ReadOnly, &
                                ImGuiColorEditFlags_AlphaBar, ImGuiColorEditFlags_NoAlpha, ImGuiHoveredFlags_DelayNormal, &
                                ImGuiHoveredFlags_DelayShort, ImGuiHoveredFlags_None

implicit none
private
public :: ig_begin, ig_begin_side_bar, ig_end, ig_button, ig_checkbox, ig_text, ig_same_line, ig_separator
public :: ig_show_demo_window, ig_set_next_window, ig_item_rect, ig_image, ig_input_text, ig_set_next_item_width
public :: ig_combo, ig_tooltip, ig_selectable, ig_text_wrapped, ig_text_disabled, ig_text_colored
public :: ig_tool_button, ig_focus_window, ig_align_text_to_frame_padding, ig_text_size
public :: ig_progress_bar
public :: ig_color_edit
public :: ig_input_text_multiline, text_buffer_object
public :: ig_set_clipboard, ig_get_clipboard
public :: item_status_object, ig_last_item, ig_item_hovered, ig_any_item_hovered, ig_any_item_active
public :: ig_scroll_here, ig_get_scroll, ig_set_scroll, ig_scroll_to_pos, ig_focus_here, ig_default_focus
public :: ig_font_size, ig_line_height, ig_frame_height, ig_em, ig_available, ig_spacing, ig_dummy, ig_new_line
public :: ig_indent, ig_unindent, ig_separator_text, ig_push_item_width, ig_pop_item_width
public :: ig_begin_tooltip, ig_begin_item_tooltip, ig_end_tooltip, ig_text_link, ig_text_link_url

type :: text_buffer_object
   !< Text of any length, edited by `ig_input_text_multiline`: a file shown or edited as text, notes, a read-only view.
   !< The text is kept by FIGURE's native layer, which grows it while the user types or pastes (no capacity to choose,
   !< no copy per frame); `set` replaces it, `text` returns a copy. Lines end with LF (`set` turns CRLF into LF).
   !< Usable before `init*` and from a task (it draws nothing). Not to be copied: the copy would share the text, and
   !< the first of the two to end would take it away from the other.
   integer(c_int), private :: id = 0_c_int !< Native handle (0: no text yet, an empty one).
   contains
      procedure, pass(self) :: set => text_buffer_set       !< Replace the text.
      procedure, pass(self) :: text => text_buffer_text     !< A copy of the text.
      procedure, pass(self) :: length => text_buffer_length !< Its length [bytes].
      final                 :: text_buffer_final
endtype text_buffer_object

type :: item_status_object
   !< What happened to an item, as `ig_last_item` found it right after the item was drawn: a snapshot, a plain value
   !< the program keeps (later items do not change it). The event states (`activated`, `edited`, `deactivated`,
   !< `deactivated_after_edit`, `toggled_open`, `clicked`, `double_clicked`) are true on one frame only, the frame of
   !< the event; the others (`hovered`, `active`, `focused`, `visible`) last as long as the condition. Which widgets
   !< report which states: widgets.md, "What happened to an item".
   logical      :: hovered = .false.                !< The pointer is over the item, and no other item is held.
   logical      :: active = .false.                 !< Held (a button pressed, a slider dragged) or being edited.
   logical      :: focused = .false.                !< It has the keyboard focus (keyboard navigation's cursor).
   logical      :: visible = .false.                !< Not clipped: inside its window or region's visible area.
   logical      :: activated = .false.              !< It became active on this frame.
   logical      :: edited = .false.                 !< It changed its value on this frame.
   logical      :: deactivated = .false.            !< It stopped being active on this frame.
   logical      :: deactivated_after_edit = .false. !< It stopped being active on this frame, its value changed meanwhile.
   logical      :: toggled_open = .false.           !< A tree node or header opened or closed on this frame.
   logical      :: clicked(3) = .false.             !< Clicked on this frame, per button: left, right, middle.
   logical      :: double_clicked(3) = .false.      !< Double-clicked on this frame, per button: left, right, middle.
   real(real64) :: rect(4) = 0.0_real64             !< x, y (top left), width, height [pixels].
endtype item_status_object

interface ig_em
   !< A length of `x` em [pixels]: `x` times the current font size, so that a size given in lines of text follows the
   !< font and the display's scale.
   module procedure ig_em_r64, ig_em_i32
endinterface ig_em

contains
   recursive function ig_begin(name, open, flags) result(visible)
   !< Begin a window; always pair with `ig_end`. With `open`, the window has a close button that sets it false.
   !< `flags` combine `ImGuiWindowFlags_*` with `ior` (`NoTitleBar`, `NoResize`, `NoMove`, `AlwaysAutoResize`,
   !< `NoBackground`, `NoDecoration`, `NoDocking`, ...).
   character(len=*), intent(in)              :: name    !< Window name (unique id and title).
   logical,          intent(inout), optional :: open    !< Window open.
   integer(int32),   intent(in),    optional :: flags   !< `ImGuiWindowFlags_*` (default none).
   logical                                   :: visible !< False when collapsed or clipped: skip its content.
   integer(c_int)                            :: f       !< Flags.
   logical(c_bool), target                   :: o       !< C copy of `open`.
   type(c_ptr)                               :: p       !< bool* or null.

   visible = .false.
   if (figure_draw_refused('ig_begin')) return ! a task does not draw
   p = c_null_ptr
   if (present(open)) then
      o = logical(open, c_bool)
      p = c_loc(o)
   endif
   f = 0_c_int
   if (present(flags)) f = int(flags, c_int)
   visible = logical(igBegin(cstr(name), p, f))
   if (present(open)) open = logical(o)
   call figure_scope_open(SCOPE_WINDOW, 'ig_begin', name, visible)
   endfunction ig_begin

   recursive function ig_begin_side_bar(name, side, size) result(visible)
   !< Begin a bar along one side of the display: a toolbar, a status bar. `side` is `'left'`, `'right'`, `'top'` or
   !< `'bottom'`; `size` its width (left, right) or height (top, bottom) [pixels]. It is a window without title bar,
   !< not movable, not resizable, not dockable, which the work area leaves out: a dock space (`ig_dock_space`) and
   !< the main menu bar's neighbours fill the rest. Declare it every frame, after the main menu bar and before the dock
   !< space; always pair with `ig_end`. An unknown side is taken as `'left'`.
   character(len=*), intent(in) :: name    !< Window name (unique id).
   character(len=*), intent(in) :: side    !< left, right, top, bottom.
   real(real64),     intent(in) :: size    !< Width or height [pixels].
   logical                      :: visible !< Its content is drawn.
   integer(c_int)               :: s       !< Side code.

   visible = .false.
   if (figure_draw_refused('ig_begin_side_bar')) return ! a task does not draw
   select case (side)
   case ('right')
      s = 1_c_int
   case ('top')
      s = 2_c_int
   case ('bottom')
      s = 3_c_int
   case default
      s = 0_c_int
   endselect
   visible = fig_begin_side_bar(name, len(name, c_int), s, real(size, c_double)) == 1_c_int
   call figure_scope_open(SCOPE_WINDOW, 'ig_begin_side_bar', name, visible)
   endfunction ig_begin_side_bar

   recursive function ig_focus_window(name) result(focused)
   !< Bring window `name` forward and give it the keyboard (a docked window: its tab is shown). Not while a popup or a
   !< modal is open, since focusing another window would close it: then nothing happens and the result is false; ask
   !< again on a later frame. A window not drawn yet (this frame or before) is not found: ask after its `ig_begin`.
   character(len=*), intent(in) :: name    !< Window name (as given to `ig_begin`, or its `###id` part).
   logical                      :: focused !< Focused (false: a popup is open, ask again later).

   focused = .false.
   if (figure_draw_refused('ig_focus_window')) return ! a task does not draw
   focused = .not. logical(igIsPopupOpen_Str(c_null_char, ImGuiPopupFlags_AnyPopup))
   if (focused) call igSetWindowFocus_Str(cstr(name))
   endfunction ig_focus_window

   recursive subroutine ig_end()
   !< End the window opened by `ig_begin` or `ig_begin_side_bar` (whatever it returned). Refused (`FIG_ERR_STATE`,
   !< reported by `app%next_frame`) when the innermost open scope is not a window: errors.md, "Pairing and frames".
   if (figure_scope_refused(SCOPE_WINDOW, 'ig_end')) return ! a task, no frame, or not the innermost scope
   call igEnd()
   endsubroutine ig_end

   recursive subroutine ig_set_next_window(x, y, width, height, always)
   !< Position (and size) of the next window [pixels]: on first use only, or every frame if `always`.
   real(real64), intent(in)           :: x      !< Left [pixels].
   real(real64), intent(in)           :: y      !< Top [pixels].
   real(real64), intent(in), optional :: width  !< Width [pixels].
   real(real64), intent(in), optional :: height !< Height [pixels].
   logical,      intent(in), optional :: always !< Enforce every frame (default: first use only).
   integer(c_int)                     :: cond   !< ImGuiCond.

   if (figure_draw_refused('ig_set_next_window')) return ! a task does not draw
   cond = ImGuiCond_FirstUseEver
   if (present(always)) then
      if (always) cond = ImGuiCond_Always
   endif
   call igSetNextWindowPos(im_vec2(real(x, c_float), real(y, c_float)), cond, im_vec2(0.0_c_float, 0.0_c_float))
   if (present(width) .and. present(height)) &
      call igSetNextWindowSize(im_vec2(real(width, c_float), real(height, c_float)), cond)
   endsubroutine ig_set_next_window

   recursive function ig_button(label, width, height) result(pressed)
   !< A button; true on the frame it is clicked.
   character(len=*), intent(in)           :: label   !< Label.
   real(real64),     intent(in), optional :: width   !< Width [pixels] (default: fit the label).
   real(real64),     intent(in), optional :: height  !< Height [pixels] (default: fit the label).
   logical                                :: pressed !< Clicked this frame.
   type(im_vec2)                          :: extent   !< Size (not `size`: see docs/guide/known-issues.md).

   pressed = .false.
   if (figure_draw_refused('ig_button')) return ! a task does not draw
   extent = im_vec2(0.0_c_float, 0.0_c_float)
   if (present(width)) extent%x = real(width, c_float)
   if (present(height)) extent%y = real(height, c_float)
   pressed = logical(igButton(cstr(label), extent))
   endfunction ig_button

   recursive function ig_tool_button(label, icon, width, height, selected, accent) result(clicked)
   !< A workspace button, as Fusion 360's: `icon` (an `ICON_*`) above `label`, larger than it, on a framed, rounded button
   !< that shades under the pointer. `selected`: framed and tinted in the accent colour, the icon drawn in it (`accent`
   !< `[r, g, b]` in [0, 1]; default: the style's CheckMark colour). `width`, `height` [pixels]: default as wide as the
   !< label (at least 4.6 font sizes) and tall enough for the icon (1.8 font sizes) above the label. The text before
   !< `##` is shown, all of `label` is the id. True on the frame it is clicked; `ig_tooltip` and `ig_item_rect` apply to
   !< it as to any widget.
   character(len=*), intent(in)           :: label    !< Label (also its id).
   character(len=*), intent(in)           :: icon     !< Icon (UTF-8: an ICON_* constant).
   real(real64),     intent(in), optional :: width    !< Width [pixels].
   real(real64),     intent(in), optional :: height   !< Height [pixels].
   logical,          intent(in), optional :: selected !< The one shown (default false).
   real(real64),     intent(in), optional :: accent(3) !< Accent colour.
   logical                                :: clicked  !< Clicked this frame.
   real(c_double)                         :: w, h, acc(4) !< C copies.
   integer(c_int)                         :: sel      !< C copy of `selected`.

   clicked = .false.
   if (figure_draw_refused('ig_tool_button')) return ! a task does not draw
   w = 0.0_c_double
   h = 0.0_c_double
   if (present(width)) w = real(width, c_double)
   if (present(height)) h = real(height, c_double)
   sel = 0_c_int
   if (present(selected)) sel = merge(1_c_int, 0_c_int, selected)
   acc = [0.0_c_double, 0.0_c_double, 0.0_c_double, -1.0_c_double]
   if (present(accent)) acc = [real(accent, c_double), 1.0_c_double]
   clicked = fig_tool_button(label, len(label, c_int), icon, len(icon, c_int), w, h, sel, acc) == 1_c_int
   endfunction ig_tool_button

   recursive function ig_text_size(text) result(extent)
   !< The size a text takes in the current font [pixels]: width and height (the text before `##` when it is a label):
   !< buttons of one width, a column as wide as its longest value.
   character(len=*), intent(in) :: text    !< Text (UTF-8).
   real(real64)                 :: extent(2) !< Width, height.
   type(im_vec2)                :: ext     !< Its extent.

   extent = 0.0_real64
   if (figure_refused('ig_text_size')) return ! a task does not draw
   ext = igCalcTextSize(cstr(text), c_null_ptr, .true._c_bool, -1.0_c_float)
   extent = [real(ext%x, real64), real(ext%y, real64)]
   endfunction ig_text_size

   recursive subroutine ig_align_text_to_frame_padding()
   !< The text that follows on this line is lowered to the text of framed widgets (fields, buttons): a label or a value
   !< beside fields, in a table row of fields.
   if (figure_draw_refused('ig_align_text_to_frame_padding')) return ! a task does not draw
   call igAlignTextToFramePadding()
   endsubroutine ig_align_text_to_frame_padding

   recursive function ig_checkbox(label, value) result(changed)
   !< A check box bound to `value`; true when the user toggled it.
   character(len=*), intent(in)    :: label   !< Label.
   logical,          intent(inout) :: value   !< Value.
   logical                         :: changed !< Toggled this frame.
   logical(c_bool), target         :: v       !< C copy of `value`.

   changed = .false.
   if (figure_draw_refused('ig_checkbox')) return ! a task does not draw
   v = logical(value, c_bool)
   changed = logical(igCheckbox(cstr(label), c_loc(v)))
   value = logical(v)
   endfunction ig_checkbox

   recursive function ig_input_text(label, value, hint, flags) result(changed)
   !< A text field bound to `value`; true when the user edited it. The text can be as long as `value` (its length is
   !< the field's capacity); trailing blanks are not part of the text (Fortran pads with them). `hint` is shown while
   !< the field is empty; `flags` combine `ImGuiInputTextFlags_*` with `ior` (`CharsNoBlank`, `CharsDecimal`,
   !< `CharsScientific`, `ReadOnly`, `EnterReturnsTrue`, ...).
   character(len=*), intent(in)               :: label   !< Label.
   character(len=*), intent(inout)            :: value   !< Text.
   character(len=*), intent(in),    optional  :: hint    !< Shown while the field is empty.
   integer(int32),   intent(in),    optional  :: flags   !< `ImGuiInputTextFlags_*` (default none).
   logical                                    :: changed !< Edited this frame.
   character(kind=c_char)                     :: buf(len(value) + 1) !< C copy of the text, NUL-terminated.
   integer(c_int)                             :: f       !< Flags.
   integer(int32)                             :: n       !< Length of the text.
   integer(int32)                             :: i       !< Counter.

   changed = .false.
   if (figure_draw_refused('ig_input_text')) return ! a task does not draw
   n = len_trim(value)
   do i = 1_int32, n
      buf(i) = value(i:i)
   enddo
   buf(n + 1:) = c_null_char
   f = 0_c_int
   if (present(flags)) f = int(flags, c_int)
   if (present(hint)) then
      changed = fig_widget_input_text(label, len(label, c_int), hint, len(hint, c_int), buf, size(buf, kind=c_int), &
                                      f) == 1_c_int
   else
      changed = fig_widget_input_text(label, len(label, c_int), '', 0_c_int, buf, size(buf, kind=c_int), f) == 1_c_int
   endif
   if (.not. changed) return
   value = ''
   do i = 1_int32, len(value, kind=int32)
      if (buf(i) == c_null_char) exit
      value(i:i) = buf(i)
   enddo
   endfunction ig_input_text

   recursive function ig_input_text_multiline(label, buffer, width, height, read_only, tab_input, flags) result(changed)
   !< A multi-line text field (`InputTextMultiline`) over `buffer`; true on the frame the user edited the text.
   !< Enter inserts a newline; the field scrolls when the text is longer than it. Keys (cmd for ctrl on macOS):
   !< ctrl+z undoes, ctrl+y or ctrl+shift+z redoes, ctrl+a selects all, ctrl+c, ctrl+x and ctrl+v copy, cut and
   !< paste. `width`, `height` [pixels]: absent or 0, the item width and 8 lines; negative, up to that distance from
   !< the region's right or bottom edge. `read_only`: the text can be selected and copied, not changed. `tab_input`:
   !< Tab inserts a tab character (default: it moves to the next widget). `flags` add `ImGuiInputTextFlags_*` with
   !< `ior` (`WordWrap`, `NoUndoRedo`, ...). The same in every mode; from a task it draws nothing and returns false
   !< (the task's status becomes `FIG_ERR_STATE`).
   character(len=*),         intent(in)           :: label     !< Label (`'##text'`: none shown).
   type(text_buffer_object), intent(inout)        :: buffer    !< The text.
   real(real64),             intent(in), optional :: width     !< Width [pixels].
   real(real64),             intent(in), optional :: height    !< Height [pixels].
   logical,                  intent(in), optional :: read_only !< Selection and copy only (default false).
   logical,                  intent(in), optional :: tab_input !< Tab inserts a tab (default false).
   integer(int32),           intent(in), optional :: flags     !< More `ImGuiInputTextFlags_*` (default none).
   logical                                        :: changed   !< Edited this frame.
   real(c_double)                                 :: w         !< Width.
   real(c_double)                                 :: h         !< Height.
   integer(c_int)                                 :: f         !< Flags.

   changed = .false.
   if (figure_draw_refused('ig_input_text_multiline')) return ! a task does not draw
   w = 0.0_c_double
   if (present(width)) w = real(width, c_double)
   h = 0.0_c_double
   if (present(height)) h = real(height, c_double)
   f = 0_c_int
   if (present(flags)) f = int(flags, c_int)
   if (present(read_only)) then
      if (read_only) f = ior(f, ImGuiInputTextFlags_ReadOnly)
   endif
   if (present(tab_input)) then
      if (tab_input) f = ior(f, ImGuiInputTextFlags_AllowTabInput)
   endif
   changed = fig_widget_input_text_multiline(buffer%id, label, len(label, c_int), w, h, f) == 1_c_int
   endfunction ig_input_text_multiline

   recursive subroutine ig_set_clipboard(text, stat)
   !< Put `text` (UTF-8, trailing blanks included: pass `trim` of a padded variable) on the clipboard, as a copy in a
   !< field does. Window mode: the system's clipboard (SDL's). Headless mode: a clipboard of the program's own.
   !< Remote mode: the program's own on the server, also written to the browser's clipboard where the browser allows
   !< it (a page reached as https or localhost, and in a few browsers only right after a click or a key). Status:
   !< `FIG_ERR_STATE` before `init*` or from a task (`stat` optional: absent, `error stop` with the message).
   character(len=*), intent(in)            :: text !< Text.
   integer(int32),   intent(out), optional :: stat !< Status.

   if (figure_refused('ig_set_clipboard', stat)) return ! a task does not reach Dear ImGui
   call figure_check(fig_set_clipboard(text, len(text, c_int)), stat)
   endsubroutine ig_set_clipboard

   recursive function ig_get_clipboard() result(text)
   !< The clipboard's text (UTF-8), as a paste in a field reads it: the system's in window mode, the program's own in
   !< headless mode; in remote mode the program's own, which a paste in the page (ctrl+v, cmd+v) sets from the
   !< browser's clipboard first. `''` before `init*`, for an empty clipboard, or from a task.
   character(len=:), allocatable :: text !< Text.
   integer(c_long_long)          :: n    !< Bytes asked.
   integer(c_long_long)          :: got  !< The text's length when copied.
   character(len=1)              :: probe !< A buffer for the length alone.

   if (figure_refused('ig_get_clipboard')) then ! a task does not reach Dear ImGui
      text = ''
      return
   endif
   n = fig_get_clipboard(probe, 0_c_long_long)
   do ! another program may change the clipboard between the two calls: copy again while it is longer than asked
      allocate(character(len=n) :: text)
      got = fig_get_clipboard(text, n)
      if (got <= n) exit
      deallocate(text)
      n = got
   enddo
   if (got < n) text = text(1:got)
   endfunction ig_get_clipboard

   ! ---- text_buffer_object --------------------------------------------------------------------------------------------
   recursive subroutine text_buffer_set(self, text, stat)
   !< Replace the text with `text` (UTF-8, lines ended by LF or CRLF; trailing blanks are part of it: pass `trim` of a
   !< padded line). A field being edited shows the new text at once, its undo history kept. A NUL byte ends the text.
   !< Status: `FIG_ERR_ARGUMENT` for a text of 2 GiB or more (`stat` optional: absent, `error stop` with the message).
   class(text_buffer_object), intent(inout)         :: self !< Buffer.
   character(len=*),          intent(in)            :: text !< New text.
   integer(int32),            intent(out), optional :: stat !< Status.

   call figure_check(fig_text_set(self%id, text, len(text, c_long_long)), stat)
   endsubroutine text_buffer_set

   recursive function text_buffer_text(self) result(text)
   !< A copy of the text (`''` before any `set` or edit).
   class(text_buffer_object), intent(in) :: self !< Buffer.
   character(len=:), allocatable         :: text !< The text.
   integer(c_long_long)                  :: n    !< Bytes asked.
   integer(c_long_long)                  :: got  !< The text's length when copied.

   n = fig_text_length(self%id)
   do ! the text may change between the two calls (a task's set): copy again while it is longer than asked
      allocate(character(len=n) :: text)
      got = fig_text_get(self%id, text, n)
      if (got <= n) exit
      deallocate(text)
      n = got
   enddo
   if (got < n) text = text(1:got)
   endfunction text_buffer_text

   recursive function text_buffer_length(self) result(length)
   !< The length of the text [bytes] (UTF-8: a character outside ASCII takes 2 to 4).
   class(text_buffer_object), intent(in) :: self   !< Buffer.
   integer(int64)                        :: length !< Length [bytes].

   length = int(fig_text_length(self%id), int64)
   endfunction text_buffer_length

   recursive subroutine text_buffer_final(self)
   !< The buffer ends: its text is released.
   type(text_buffer_object), intent(inout) :: self !< Buffer.

   if (self%id /= 0_c_int) call fig_text_release(self%id)
   self%id = 0_c_int
   endsubroutine text_buffer_final

   recursive function ig_color_edit(label, rgba, alpha, stat) result(changed)
   !< A colour editor (`ColorEdit4`) bound to `rgba`, components in [0, 1]: a swatch that opens a picker (a
   !< saturation-value square and a hue bar) when clicked, and one field per component, dragged or typed (0-255). A
   !< `rgba` of 3 components is RGB; of 4, RGBA, with the alpha shown unless `alpha=.false.` (then `rgba(4)` is left
   !< alone). True on the frames the user changes the colour; `rgba` is written only then (Dear ImGui edits single
   !< precision: an untouched colour keeps its double precision bits). Right-click on the swatch: Dear ImGui's options
   !< (RGB, HSV or hexadecimal fields, copy as text). Statuses: `FIG_ERR_ARGUMENT` for a size other than 3 or 4,
   !< `FIG_ERR_STATE` from a task. The same in every mode.
   character(len=*), intent(in)            :: label   !< Label (also the id; '##id' hides it).
   real(real64),     intent(inout)         :: rgba(:) !< Colour, RGB or RGBA in [0, 1].
   logical,          intent(in), optional  :: alpha   !< Show and edit the alpha (default: when size(rgba) is 4).
   integer(int32),   intent(out), optional :: stat    !< Status.
   logical                                 :: changed !< Changed this frame.
   real(c_float), target                   :: c(4)    !< Single-precision copy for Dear ImGui.
   integer(c_int)                          :: flags   !< ImGuiColorEditFlags.
   integer(int32)                          :: n       !< Components.

   changed = .false.
   if (figure_draw_refused('ig_color_edit', stat)) return ! a task does not draw
   n = size(rgba, kind=int32)
   if (n /= 3_int32 .and. n /= 4_int32) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ig_color_edit: the colour needs 3 (RGB) or 4 (RGBA) components', stat)
      return
   endif
   flags = ImGuiColorEditFlags_AlphaBar
   if (n == 3_int32) flags = ImGuiColorEditFlags_NoAlpha
   if (present(alpha)) then
      if (.not. alpha) flags = ImGuiColorEditFlags_NoAlpha
   endif
   c = 1.0_c_float
   c(1:n) = real(rgba, c_float)
   changed = logical(igColorEdit4(cstr(label), c_loc(c), flags))
   if (changed) then
      if (iand(flags, ImGuiColorEditFlags_NoAlpha) /= 0_c_int) then
         rgba(1:3) = real(c(1:3), real64)
      else
         rgba = real(c, real64)
      endif
   endif
   call figure_check(FIG_OK, stat)
   endfunction ig_color_edit

   recursive function ig_combo(label, current, items) result(changed)
   !< A drop-down list of `items`; `current` is the index of the one chosen (1 to `size(items)`; any other value shows
   !< none chosen). True on the frame the user picks an item (`current` is then its index).
   character(len=*), intent(in)    :: label    !< Label.
   integer(int32),   intent(inout) :: current  !< Index of the chosen item.
   character(len=*), intent(in)    :: items(:) !< Items (trailing blanks are not shown).
   logical                         :: changed  !< An item was picked this frame.
   integer(int32)                  :: i        !< Item.
   logical                         :: chosen   !< Item i is the current one.

   changed = .false.
   if (figure_draw_refused('ig_combo')) return ! a task does not draw
   changed = .false.
   if (current >= 1_int32 .and. current <= size(items, kind=int32)) then
      if (.not. logical(igBeginCombo(cstr(label), cstr(trim(items(current))), 0_c_int))) return
   else
      if (.not. logical(igBeginCombo(cstr(label), cstr(''), 0_c_int))) return
   endif
   do i = 1_int32, size(items, kind=int32)
      chosen = i == current
      call igPushID_Int(int(i, c_int))                ! items may repeat a text: the index tells them apart
      if (logical(igSelectable_Bool(cstr(trim(items(i))), logical(chosen, c_bool), 0_c_int, &
                                    im_vec2(0.0_c_float, 0.0_c_float)))) then
         current = i
         changed = .true.
      endif
      if (chosen) call igSetItemDefaultFocus()        ! keyboard navigation starts from the current item
      call igPopID()
   enddo
   call igEndCombo()
   if (changed) call fig_mark_last_item_edited() ! as Dear ImGui's Combo: ig_last_item reports the pick as an edit
   endfunction ig_combo

   recursive subroutine ig_tooltip(text)
   !< A tooltip on the previous widget: `text` shows while the pointer rests on it (after Dear ImGui's usual delay).
   character(len=*), intent(in) :: text !< Text.

   if (figure_draw_refused('ig_tooltip')) return ! a task does not draw
   call fig_items_tooltip()                       ! the item has a tooltip (test_unnamed_items), hovered or not
   if (.not. logical(igBeginItemTooltip())) return
   call igTextUnformatted(cstr(text), c_null_ptr)
   call igEndTooltip()
   endsubroutine ig_tooltip

   recursive function ig_begin_tooltip() result(shown)
   !< Begin a tooltip with any content (Dear ImGui's `BeginTooltip`): a window that follows the pointer, drawn this
   !< frame whatever is hovered; declare its content (text, a table, a plot), then `ig_end_tooltip`. Call it on the
   !< frames it must show, e.g. after `ig_last_item()` reported the item hovered. True in every frame (Dear ImGui's
   !< begin cannot fail today), but `ig_end_tooltip` only after true, as for every "after true" pair. No frame open or a
   !< task: false, refused (`FIG_ERR_STATE`). The same in window, headless and remote mode.
   logical :: shown !< The tooltip is being declared.

   shown = .false.
   if (figure_draw_refused('ig_begin_tooltip')) return ! a task does not draw
   shown = logical(igBeginTooltip())
   call figure_scope_open(SCOPE_TOOLTIP, 'ig_begin_tooltip', '', shown)
   endfunction ig_begin_tooltip

   recursive function ig_begin_item_tooltip() result(shown)
   !< Begin a tooltip on the item drawn just before (Dear ImGui's `BeginItemTooltip`): true while the pointer rests on
   !< it, after Dear ImGui's tooltip delay (`ig_tooltip`'s: still for 0.15 s, the style's `HoverStationaryDelay`, and
   !< hovered for 0.15 s, `HoverDelayShort`); declare the content, then `ig_end_tooltip` only after true. No frame open
   !< or a task: false, refused (`FIG_ERR_STATE`). The same in window, headless and remote mode.
   logical :: shown !< The tooltip is being declared.

   shown = .false.
   if (figure_draw_refused('ig_begin_item_tooltip')) return ! a task does not draw
   call fig_items_tooltip() ! the item has a tooltip (test_unnamed_items), hovered or not
   shown = logical(igBeginItemTooltip())
   call figure_scope_open(SCOPE_TOOLTIP, 'ig_begin_item_tooltip', '', shown)
   endfunction ig_begin_item_tooltip

   recursive subroutine ig_end_tooltip()
   !< End a tooltip (only after `ig_begin_tooltip` or `ig_begin_item_tooltip` returned true). A wrong end (after a false
   !< begin, or with another scope innermost) is refused and reported (`FIG_ERR_STATE`; errors.md, "Pairing and
   !< frames").
   if (figure_scope_refused(SCOPE_TOOLTIP, 'ig_end_tooltip')) return ! a task, no frame, or not the innermost scope
   call igEndTooltip()
   endsubroutine ig_end_tooltip

   recursive function ig_text_link(label) result(clicked)
   !< Text drawn as a link (Dear ImGui's `TextLink`: the style's `TextLink` colour, underlined, a hand pointer over it);
   !< true on the frame it is clicked. The text before `##` is shown, all of `label` is the id. No frame open or a
   !< task: false, refused (`FIG_ERR_STATE`). The same in window, headless and remote mode.
   character(len=*), intent(in) :: label   !< Label (also its id).
   logical                      :: clicked !< Clicked this frame.

   clicked = .false.
   if (figure_draw_refused('ig_text_link')) return ! a task does not draw
   clicked = logical(igTextLink(cstr(label)))
   endfunction ig_text_link

   recursive subroutine ig_text_link_url(label, url)
   !< A link that opens `url` when clicked (Dear ImGui's `TextLinkOpenURL`): a window opens it with the system's
   !< handler (SDL_OpenURL: the browser, or the program a file's type is given to); remote mode sends it to the page,
   !< which opens it in a new tab of the browser (where the browser allows pop-ups); headless mode opens nothing
   !< (`test_opened_url` reads it). The pointer resting on it shows the URL; a right click offers "Copy Link". FIGURE
   !< does not check the URL: pass a link of your own, not text a user typed. No frame open or a task: refused
   !< (`FIG_ERR_STATE`).
   character(len=*), intent(in)                      :: label !< Label (also its id).
   character(len=*), intent(in)                      :: url   !< The address, e.g. `'https://...'`.
   character(kind=c_char, len=1), allocatable, target :: u(:)  !< `url`, NUL-terminated.
   integer                                           :: i     !< Character.

   if (figure_draw_refused('ig_text_link_url')) return ! a task does not draw
   allocate(u(len(url) + 1))
   do i = 1, len(url)
      u(i) = url(i:i)
   enddo
   u(len(url) + 1) = c_null_char
   if (igTextLinkOpenURL(cstr(label), c_loc(u))) continue
   endsubroutine ig_text_link_url

   recursive subroutine ig_set_next_item_width(width)
   !< Width of the next widget's field [pixels]; negative: up to that distance from the window's right edge.
   real(real64), intent(in) :: width !< Width [pixels].

   if (figure_draw_refused('ig_set_next_item_width')) return ! a task does not draw
   call igSetNextItemWidth(real(width, c_float))
   endsubroutine ig_set_next_item_width

   recursive subroutine ig_push_item_width(width)
   !< Width of the fields of every widget that follows in the current window [pixels] (Dear ImGui's `PushItemWidth`),
   !< until `ig_pop_item_width`; always paired, the pop in the same window and scope (a pop closes the innermost scope,
   !< as `ig_pop_id`). Negative: up to that distance from the right edge of the window or region; 0: the window's
   !< default. `ig_set_next_item_width` still sets the next widget's alone. No frame open or a task: nothing done (a
   !< usage error, reported by `app%next_frame`). The same in window, headless and remote mode.
   real(real64), intent(in) :: width !< Width [pixels]; < 0: up to that distance from the right edge; 0: the default.

   if (figure_draw_refused('ig_push_item_width')) return ! a task does not draw
   call igPushItemWidth(real(width, c_float))
   call figure_scope_open(SCOPE_ITEM_WIDTH, 'ig_push_item_width', '')
   endsubroutine ig_push_item_width

   recursive subroutine ig_pop_item_width()
   !< Back to the width of the fields before the last `ig_push_item_width` (Dear ImGui's `PopItemWidth`).
   if (figure_scope_refused(SCOPE_ITEM_WIDTH, 'ig_pop_item_width')) return ! a task, no frame, or not innermost
   call igPopItemWidth()
   endsubroutine ig_pop_item_width

   recursive subroutine ig_text(text)
   !< Plain text (no formatting: compose it with Fortran internal writes).
   character(len=*), intent(in) :: text !< Text.

   if (figure_draw_refused('ig_text')) return ! a task does not draw
   call igTextUnformatted(cstr(text), c_null_ptr)
   endsubroutine ig_text

   recursive subroutine ig_same_line(offset)
   !< Put the next item on the same line as the previous one; with `offset`, at that distance [pixels] from the
   !< window's left edge (aligned columns of labels and fields).
   real(real64), intent(in), optional :: offset !< Distance from the window's left edge [pixels].

   if (figure_draw_refused('ig_same_line')) return ! a task does not draw
   if (present(offset)) then
      call igSameLine(real(offset, c_float), -1.0_c_float)
   else
      call igSameLine(0.0_c_float, -1.0_c_float)
   endif
   endsubroutine ig_same_line

   recursive function ig_selectable(label, selected) result(clicked)
   !< A line of a list, highlighted when `selected`; true on the frame it is clicked (the program then updates what is
   !< selected: the line does not change `selected` itself).
   character(len=*), intent(in) :: label    !< Label (also its id).
   logical,          intent(in) :: selected !< Highlighted.
   logical                      :: clicked  !< Clicked this frame.

   clicked = .false.
   if (figure_draw_refused('ig_selectable')) return ! a task does not draw
   clicked = logical(igSelectable_Bool(cstr(label), logical(selected, c_bool), 0_c_int, &
                                       im_vec2(0.0_c_float, 0.0_c_float)))
   endfunction ig_selectable

   recursive subroutine ig_text_wrapped(text)
   !< Text wrapped at the right edge of the window or region (help text, long messages).
   character(len=*), intent(in) :: text !< Text.

   if (figure_draw_refused('ig_text_wrapped')) return ! a task does not draw
   call igPushTextWrapPos(0.0_c_float)
   call igTextUnformatted(cstr(text), c_null_ptr)
   call igPopTextWrapPos()
   endsubroutine ig_text_wrapped

   recursive subroutine ig_text_disabled(text)
   !< Text in the style's disabled colour (a default value, a hint, something that does not apply).
   character(len=*), intent(in) :: text  !< Text.
   type(im_vec4), pointer       :: muted !< The style's TextDisabled colour.

   if (figure_draw_refused('ig_text_disabled')) return ! a task does not draw
   call c_f_pointer(igGetStyleColorVec4(ImGuiCol_TextDisabled), muted)
   call igPushStyleColor_Vec4(ImGuiCol_Text, muted)
   call igTextUnformatted(cstr(text), c_null_ptr)
   call igPopStyleColor(1_c_int)
   endsubroutine ig_text_disabled

   recursive subroutine ig_text_colored(text, color)
   !< Text in `color` ([r, g, b] or [r, g, b, a] in [0, 1]); pair a colour with a mark or a word (an error marker), so
   !< that it does not rest on colour alone.
   character(len=*), intent(in) :: text     !< Text.
   real(real64),     intent(in) :: color(:) !< [r, g, b] or [r, g, b, a].
   type(im_vec4)                :: c        !< Colour.

   if (figure_draw_refused('ig_text_colored')) return ! a task does not draw
   c = im_vec4(1.0_c_float, 1.0_c_float, 1.0_c_float, 1.0_c_float)
   if (size(color) >= 3) then
      c%x = real(color(1), c_float)
      c%y = real(color(2), c_float)
      c%z = real(color(3), c_float)
   endif
   if (size(color) >= 4) c%w = real(color(4), c_float)
   call igPushStyleColor_Vec4(ImGuiCol_Text, c)
   call igTextUnformatted(cstr(text), c_null_ptr)
   call igPopStyleColor(1_c_int)
   endsubroutine ig_text_colored

   recursive subroutine ig_progress_bar(fraction, label, width)
   !< A progress bar (`ProgressBar`), `fraction` of it filled, in [0, 1] (clamped); `fraction` < 0 gives an
   !< indeterminate bar, a band sliding along it (animated by FIGURE with the frame clock: draw it every frame).
   !< `label` is written over it (default: the percentage; none for an indeterminate bar); `width` [pixels] (default:
   !< the width left; negative: up to that distance from the right edge). The same in every mode.
   real(real64),     intent(in)           :: fraction !< Done, in [0, 1]; < 0: indeterminate.
   character(len=*), intent(in), optional :: label    !< Text over the bar.
   real(real64),     intent(in), optional :: width    !< Width [pixels].
   character(kind=c_char, len=:), allocatable, target :: text !< C copy of `label`.
   real(c_float)                          :: f        !< Fraction.
   real(c_float)                          :: w        !< Width.
   type(c_ptr)                            :: overlay  !< Label or null.

   if (figure_draw_refused('ig_progress_bar')) return ! a task does not draw
   f = real(fraction, c_float)
   if (fraction < 0.0_real64) f = -real(igGetTime(), c_float) ! Dear ImGui's indeterminate form: a moving negative
   w = -tiny(1.0_c_float)                                      ! -FLT_MIN: the width left
   if (present(width)) w = real(width, c_float)
   overlay = c_null_ptr
   if (present(label)) then
      text = cstr(label)
      overlay = c_loc(text)
   endif
   call igProgressBar(f, im_vec2(w, 0.0_c_float), overlay)
   endsubroutine ig_progress_bar

   recursive subroutine ig_separator()
   !< Horizontal separator.
   if (figure_draw_refused('ig_separator')) return ! a task does not draw
   call igSeparator()
   endsubroutine ig_separator

   recursive subroutine ig_separator_text(label)
   !< A horizontal separator with `label` written in it, at its left (Dear ImGui's `SeparatorText`): the title of a
   !< part of a form. The text before `##` is shown. No frame open or a task: nothing drawn (a usage error, reported
   !< by `app%next_frame`). The same in window, headless and remote mode.
   character(len=*), intent(in) :: label !< Text of the separator.

   if (figure_draw_refused('ig_separator_text')) return ! a task does not draw
   call igSeparatorText(cstr(label))
   endsubroutine ig_separator_text

   recursive function ig_font_size() result(size_px)
   !< The size of the current font [pixels] (Dear ImGui's `GetFontSize`): the size set by `app%set_font` (or pushed by
   !< `ig_push_font`) times the display's content scale (`app%content_scale()`), the height of a line of text without
   !< spacing. The unit of `ig_em`. No frame open or a task: 0 (a usage error, reported by `app%next_frame`). The same
   !< in window, headless and remote mode (headless and remote: content scale 1).
   real(real64) :: size_px !< Font size [pixels].

   size_px = 0.0_real64
   if (figure_draw_refused('ig_font_size')) return ! a task does not draw
   size_px = real(igGetFontSize(), real64)
   endfunction ig_font_size

   recursive function ig_line_height(spacing) result(height)
   !< The height of a line of text [pixels] (Dear ImGui's `GetTextLineHeight`): the font size; with `spacing`, plus
   !< the style's vertical item spacing, the distance between two lines of text (`GetTextLineHeightWithSpacing`). No
   !< frame open or a task: 0 (a usage error, reported by `app%next_frame`).
   logical, intent(in), optional :: spacing !< Add the spacing below the line (default false).
   real(real64)                  :: height  !< Height [pixels].
   logical                       :: sp      !< Spacing.

   height = 0.0_real64
   if (figure_draw_refused('ig_line_height')) return ! a task does not draw
   sp = .false.
   if (present(spacing)) sp = spacing
   if (sp) then
      height = real(igGetTextLineHeightWithSpacing(), real64)
   else
      height = real(igGetTextLineHeight(), real64)
   endif
   endfunction ig_line_height

   recursive function ig_frame_height(spacing) result(height)
   !< The height of a framed widget (a button, a field, a combo) [pixels] (Dear ImGui's `GetFrameHeight`): the font
   !< size plus twice the style's vertical frame padding; with `spacing`, plus the vertical item spacing, the distance
   !< between two rows of fields (`GetFrameHeightWithSpacing`). No frame open or a task: 0 (a usage error).
   logical, intent(in), optional :: spacing !< Add the spacing below the widget (default false).
   real(real64)                  :: height  !< Height [pixels].
   logical                       :: sp      !< Spacing.

   height = 0.0_real64
   if (figure_draw_refused('ig_frame_height')) return ! a task does not draw
   sp = .false.
   if (present(spacing)) sp = spacing
   if (sp) then
      height = real(igGetFrameHeightWithSpacing(), real64)
   else
      height = real(igGetFrameHeight(), real64)
   endif
   endfunction ig_frame_height

   recursive function ig_em_r64(x) result(length)
   !< `x` em [pixels]: `x` times the current font size (`ig_font_size`). No frame open or a task: 0 (a usage error).
   real(real64), intent(in) :: x      !< Length [em].
   real(real64)             :: length !< Length [pixels].

   length = 0.0_real64
   if (figure_draw_refused('ig_em')) return ! a task does not draw
   length = x * real(igGetFontSize(), real64)
   endfunction ig_em_r64

   recursive function ig_em_i32(x) result(length)
   !< `x` em [pixels], `x` an integer: `x` times the current font size. No frame open or a task: 0 (a usage error).
   integer(int32), intent(in) :: x      !< Length [em].
   real(real64)               :: length !< Length [pixels].

   length = 0.0_real64
   if (figure_draw_refused('ig_em')) return ! a task does not draw
   length = real(x, real64) * real(igGetFontSize(), real64)
   endfunction ig_em_i32

   recursive subroutine ig_available(width, height)
   !< The space left in the current window or region from where the next item goes [pixels] (Dear ImGui's
   !< `GetContentRegionAvail`): to the right edge of its content (`width`) and to its bottom (`height`); in a table
   !< cell, to the cell's right edge. A side bar or a child region drawn beside takes its width out of it. No frame
   !< open or a task: zeros (a usage error, reported by `app%next_frame`).
   real(real64), intent(out) :: width  !< Width left [pixels].
   real(real64), intent(out) :: height !< Height left [pixels].
   type(im_vec2)             :: avail  !< Dear ImGui's answer.

   width = 0.0_real64
   height = 0.0_real64
   if (figure_draw_refused('ig_available')) return ! a task does not draw
   avail = igGetContentRegionAvail()
   width = real(avail%x, real64)
   height = real(avail%y, real64)
   endsubroutine ig_available

   recursive subroutine ig_spacing()
   !< A vertical gap of the style's item spacing before the next item (Dear ImGui's `Spacing`).
   if (figure_draw_refused('ig_spacing')) return ! a task does not draw
   call igSpacing()
   endsubroutine ig_spacing

   recursive subroutine ig_dummy(width, height)
   !< An empty item `width` x `height` pixels (Dear ImGui's `Dummy`): a gap of a given size, a place kept for something
   !< drawn later; it counts for `ig_same_line`, groups and the window's size like any item.
   real(real64), intent(in) :: width  !< Width [pixels].
   real(real64), intent(in) :: height !< Height [pixels].

   if (figure_draw_refused('ig_dummy')) return ! a task does not draw
   call igDummy(im_vec2(real(width, c_float), real(height, c_float)))
   endsubroutine ig_dummy

   recursive subroutine ig_new_line()
   !< End the line (after `ig_same_line`), or add an empty line of text's height (Dear ImGui's `NewLine`).
   if (figure_draw_refused('ig_new_line')) return ! a task does not draw
   call igNewLine()
   endsubroutine ig_new_line

   recursive subroutine ig_indent(width)
   !< Move the left edge of the lines that follow right by `width` pixels (default, or 0: the style's indent spacing),
   !< until `ig_unindent` with the same width (Dear ImGui's `Indent`). Not a scope: the program keeps the two balanced
   !< (a window's indent is reset when it begins).
   real(real64), intent(in), optional :: width !< Indent [pixels] (default: the style's indent spacing).

   if (figure_draw_refused('ig_indent')) return ! a task does not draw
   if (present(width)) then
      call igIndent(real(width, c_float))
   else
      call igIndent(0.0_c_float)
   endif
   endsubroutine ig_indent

   recursive subroutine ig_unindent(width)
   !< Move the left edge of the lines that follow back left by `width` pixels (default, or 0: the style's indent
   !< spacing) (Dear ImGui's `Unindent`).
   real(real64), intent(in), optional :: width !< Indent removed [pixels] (default: the style's indent spacing).

   if (figure_draw_refused('ig_unindent')) return ! a task does not draw
   if (present(width)) then
      call igUnindent(real(width, c_float))
   else
      call igUnindent(0.0_c_float)
   endif
   endsubroutine ig_unindent

   recursive subroutine ig_show_demo_window(open)
   !< The Dear ImGui demo window (a live catalogue of every widget).
   logical, intent(inout), optional :: open !< Window open (close button).
   logical(c_bool), target          :: o    !< C copy of `open`.

   if (figure_draw_refused('ig_show_demo_window')) return ! a task does not draw
   if (present(open)) then
      o = logical(open, c_bool)
      call igShowDemoWindow(c_loc(o))
      open = logical(o)
   else
      call igShowDemoWindow(c_null_ptr)
   endif
   endsubroutine ig_show_demo_window

   recursive subroutine ig_item_rect(xmin, ymin, xmax, ymax)
   !< Screen rectangle of the last item [pixels] (tests, custom layout).
   real(real64), intent(out) :: xmin !< Left.
   real(real64), intent(out) :: ymin !< Top.
   real(real64), intent(out) :: xmax !< Right.
   real(real64), intent(out) :: ymax !< Bottom.
   type(im_vec2)             :: v    !< Corner.

   xmin = 0.0_real64
   ymin = 0.0_real64
   xmax = 0.0_real64
   ymax = 0.0_real64
   if (figure_draw_refused('ig_item_rect')) return ! a task does not draw
   v = igGetItemRectMin()
   xmin = real(v%x, real64)
   ymin = real(v%y, real64)
   v = igGetItemRectMax()
   xmax = real(v%x, real64)
   ymax = real(v%y, real64)
   endsubroutine ig_item_rect

   recursive function ig_last_item() result(s)
   !< What happened to the item drawn last (Dear ImGui's `IsItem*`, `IsMouseDoubleClicked`, `GetItemRect*`), in one
   !< call: hovered, active, focused, visible, activated, edited, deactivated, deactivated_after_edit, toggled_open,
   !< clicked and double_clicked per button, its rectangle. Call it right after the item: the next item drawn replaces
   !< "the last item", the snapshot does not change. Event states are true on one frame. The same in window, headless
   !< and remote mode. No frame open or a task: all false (a usage error, reported by `app%next_frame`).
   type(item_status_object) :: s      !< Status of the item.
   type(fig_item_status)    :: c      !< C copy.
   integer(c_int)           :: status !< Status of the call.

   s = item_status_object()
   if (figure_draw_refused('ig_last_item')) return ! a task does not draw
   status = fig_last_item(c)
   call figure_check(status)
   if (status /= FIG_OK) return
   s%hovered = c%hovered /= 0_c_int
   s%active = c%active /= 0_c_int
   s%focused = c%focused /= 0_c_int
   s%visible = c%visible /= 0_c_int
   s%activated = c%activated /= 0_c_int
   s%edited = c%edited /= 0_c_int
   s%deactivated = c%deactivated /= 0_c_int
   s%deactivated_after_edit = c%deactivated_after_edit /= 0_c_int
   s%toggled_open = c%toggled_open /= 0_c_int
   s%clicked = c%clicked /= 0_c_int
   s%double_clicked = c%double_clicked /= 0_c_int
   s%rect = real(c%rect, real64)
   endfunction ig_last_item

   recursive function ig_item_hovered(delay, stat) result(hovered)
   !< True while the pointer is over the item drawn last (Dear ImGui's `IsItemHovered`), and no other item is held.
   !< `delay`: `'none'` (default) at once; `'short'` (0.15 s) and `'normal'` (0.40 s) once the pointer has been over
   !< the item that long (Dear ImGui's `ImGuiHoveredFlags_DelayShort`/`DelayNormal`). The time counts only on frames
   !< that make a delayed call, so call it every frame; it is shared between items (moving to a neighbour keeps it) and
   !< cleared 0.25 s after the last delayed call over an item. An unknown delay: false, `FIG_ERR_ARGUMENT` in `stat`
   !< (or `error stop` without it); no frame open or a task: `FIG_ERR_STATE`. The same in window, headless and remote
   !< mode.
   character(len=*), intent(in),  optional :: delay   !< 'none' (default), 'short' or 'normal'.
   integer(int32),   intent(out), optional :: stat    !< Status.
   logical                                 :: hovered !< Hovered (after the delay).
   integer(c_int)                          :: flags   !< ImGuiHoveredFlags.

   hovered = .false.
   if (figure_draw_refused('ig_item_hovered', stat)) return ! a task does not draw
   flags = ImGuiHoveredFlags_None
   if (present(delay)) then
      select case (delay)
      case ('none')
         flags = ImGuiHoveredFlags_None
      case ('short')
         flags = ImGuiHoveredFlags_DelayShort
      case ('normal')
         flags = ImGuiHoveredFlags_DelayNormal
      case default
         call figure_fail(FIG_ERR_ARGUMENT, 'ig_item_hovered: unknown delay "'//delay// &
                          '" (''none'', ''short'' or ''normal'')', stat)
         return
      endselect
   endif
   hovered = logical(igIsItemHovered(flags))
   if (present(stat)) stat = FIG_OK
   endfunction ig_item_hovered

   recursive function ig_any_item_hovered() result(hovered)
   !< True while the pointer is over any item (Dear ImGui's `IsAnyItemHovered`): a click there goes to a widget, not to
   !< the window's background. No frame open or a task: false (a usage error, reported by `app%next_frame`).
   logical :: hovered !< Some item hovered.

   hovered = .false.
   if (figure_draw_refused('ig_any_item_hovered')) return ! a task does not draw
   hovered = logical(igIsAnyItemHovered())
   endfunction ig_any_item_hovered

   recursive function ig_any_item_active() result(active)
   !< True while any item is active (Dear ImGui's `IsAnyItemActive`): a text field edited, a slider dragged, a button
   !< held. No frame open or a task: false (a usage error, reported by `app%next_frame`).
   logical :: active !< Some item active.

   active = .false.
   if (figure_draw_refused('ig_any_item_active')) return ! a task does not draw
   active = logical(igIsAnyItemActive())
   endfunction ig_any_item_active

   recursive subroutine ig_scroll_here(ratio, axis, stat)
   !< Scroll the current window or region so that the line drawn last (the last item's line) is at `ratio` of its
   !< visible height: 0 top, 0.5 centre (default), 1 bottom (Dear ImGui's `SetScrollHereY`; `axis='x'`:
   !< `SetScrollHereX`, the last item at `ratio` of the visible width). Call it after the item, inside the window or
   !< region that scrolls. The scroll moves when that window or region is begun on the next frame: the item is in place
   !< one frame later. A ratio outside [0, 1] or an unknown axis: nothing done, `FIG_ERR_ARGUMENT` in `stat` (or
   !< `error stop` without it); no frame open or a task: `FIG_ERR_STATE`. The same in window, headless and remote mode.
   real(real64),     intent(in),  optional :: ratio !< Where the line goes, in [0, 1] of the visible height (width).
   character(len=*), intent(in),  optional :: axis  !< 'y' (default) or 'x'.
   integer(int32),   intent(out), optional :: stat  !< Status.
   real(real64)                            :: r     !< Ratio.
   integer(int32)                          :: a     !< Axis: 1 x, 2 y.

   if (figure_draw_refused('ig_scroll_here', stat)) return ! a task does not draw
   if (.not. scroll_arguments('ig_scroll_here', ratio, axis, r, a, stat)) return
   if (a == 1_int32) then
      call igSetScrollHereX(real(r, c_float))
   else
      call igSetScrollHereY(real(r, c_float))
   endif
   if (present(stat)) stat = FIG_OK
   endsubroutine ig_scroll_here

   recursive subroutine ig_get_scroll(y, ymax, x, xmax)
   !< The scroll of the current window or region [pixels] (Dear ImGui's `GetScrollY`, `GetScrollMaxY`, `GetScrollX`,
   !< `GetScrollMaxX`): `y` from 0 (top) to `ymax` (bottom; 0: nothing to scroll), `x` from 0 (left) to `xmax`. The
   !< values of the last layout: a scroll asked for on this frame is not in them yet. No frame open or a task: zeros
   !< (a usage error, reported by `app%next_frame`). The same in window, headless and remote mode.
   real(real64), intent(out)           :: y    !< Vertical scroll [pixels].
   real(real64), intent(out)           :: ymax !< Largest vertical scroll [pixels].
   real(real64), intent(out), optional :: x    !< Horizontal scroll [pixels].
   real(real64), intent(out), optional :: xmax !< Largest horizontal scroll [pixels].

   y = 0.0_real64
   ymax = 0.0_real64
   if (present(x)) x = 0.0_real64
   if (present(xmax)) xmax = 0.0_real64
   if (figure_draw_refused('ig_get_scroll')) return ! a task does not draw
   y = real(igGetScrollY(), real64)
   ymax = real(igGetScrollMaxY(), real64)
   if (present(x)) x = real(igGetScrollX(), real64)
   if (present(xmax)) xmax = real(igGetScrollMaxX(), real64)
   endsubroutine ig_get_scroll

   recursive subroutine ig_set_scroll(y, x)
   !< Scroll the current window or region to `y` (and/or `x`) [pixels] (Dear ImGui's `SetScrollY`, `SetScrollX`):
   !< clamped to [0, the largest scroll] when applied, on the next frame (one frame late, as `ig_scroll_here`). An
   !< absent coordinate is left as it is. No frame open or a task: nothing done (a usage error, reported by
   !< `app%next_frame`). The same in window, headless and remote mode.
   real(real64), intent(in), optional :: y !< Vertical scroll [pixels].
   real(real64), intent(in), optional :: x !< Horizontal scroll [pixels].

   if (figure_draw_refused('ig_set_scroll')) return ! a task does not draw
   if (present(y)) call igSetScrollY_Float(real(y, c_float))
   if (present(x)) call igSetScrollX_Float(real(x, c_float))
   endsubroutine ig_set_scroll

   recursive subroutine ig_scroll_to_pos(pos, ratio, axis, stat)
   !< Scroll the current window or region so that the point `pos` [pixels] of its content is at `ratio` of its visible
   !< height: 0 top, 0.5 centre (default), 1 bottom (Dear ImGui's `SetScrollFromPosY`; `axis='x'`: `SetScrollFromPosX`
   !< and the width). `pos` is measured from the top (left) of the content, where its first item starts, whatever the
   !< scroll is now: row `i` of a list of rows `h` pixels apart starts at `(i - 1) * h`. It reaches a row that is not
   !< drawn on this frame (a list clipper's). Applied on the next frame, as `ig_scroll_here`. A ratio outside [0, 1] or
   !< an unknown axis: nothing done, `FIG_ERR_ARGUMENT` in `stat` (or `error stop` without it); no frame open or a
   !< task: `FIG_ERR_STATE`. The same in window, headless and remote mode.
   real(real64),     intent(in)            :: pos   !< Point of the content [pixels from its top (left)].
   real(real64),     intent(in),  optional :: ratio !< Where it goes, in [0, 1] of the visible height (width).
   character(len=*), intent(in),  optional :: axis  !< 'y' (default) or 'x'.
   integer(int32),   intent(out), optional :: stat  !< Status.
   real(real64)                            :: r     !< Ratio.
   integer(int32)                          :: a     !< Axis: 1 x, 2 y.
   type(im_vec2)                           :: start !< Where the content starts, in window coordinates.

   if (figure_draw_refused('ig_scroll_to_pos', stat)) return ! a task does not draw
   if (.not. scroll_arguments('ig_scroll_to_pos', ratio, axis, r, a, stat)) return
   start = igGetCursorStartPos() ! the content's origin, relative to the window (it moves with the scroll)
   if (a == 1_int32) then
      call igSetScrollFromPosX_Float(start%x + real(pos, c_float), real(r, c_float))
   else
      call igSetScrollFromPosY_Float(start%y + real(pos, c_float), real(r, c_float))
   endif
   if (present(stat)) stat = FIG_OK
   endsubroutine ig_scroll_to_pos

   recursive function scroll_arguments(name, ratio, axis, r, a, stat) result(ok)
   !< Check the ratio and axis of a scroll call: their values, or false with `FIG_ERR_ARGUMENT` reported.
   character(len=*), intent(in)            :: name  !< The calling procedure.
   real(real64),     intent(in),  optional :: ratio !< Ratio, in [0, 1] (default 0.5).
   character(len=*), intent(in),  optional :: axis  !< 'y' (default) or 'x'.
   real(real64),     intent(out)           :: r     !< The ratio.
   integer(int32),   intent(out)           :: a     !< The axis: 1 x, 2 y.
   integer(int32),   intent(out), optional :: stat  !< Status.
   logical                                 :: ok    !< Both valid.
   character(len=32)                       :: text  !< The ratio, written.

   ok = .false.
   r = 0.5_real64
   a = 2_int32
   if (present(ratio)) r = ratio
   ok = .not. ieee_is_nan(r)                                 ! tested apart: a comparison would signal (Fortran's
   if (ok) ok = r >= 0.0_real64 .and. r <= 1.0_real64        ! .or. does not short-circuit)
   if (ieee_is_nan(r)) then
      text = 'NaN'
   else
      write(text, '(G0)') r
   endif
   if (.not. ok) then
      call figure_fail(FIG_ERR_ARGUMENT, name//': ratio '//trim(text)//' is not in [0, 1]', stat)
      return
   endif
   ok = .false.
   if (present(axis)) then
      select case (axis)
      case ('y')
         a = 2_int32
      case ('x')
         a = 1_int32
      case default
         call figure_fail(FIG_ERR_ARGUMENT, name//': unknown axis "'//axis//'" (''y'' or ''x'')', stat)
         return
      endselect
   endif
   ok = .true.
   endfunction scroll_arguments

   recursive subroutine ig_focus_here(offset, stat)
   !< Give the keyboard focus to the next item (Dear ImGui's `SetKeyboardFocusHere`): call it before the item, on one
   !< frame (the frame a dialog opens, a button asks for it), not on every frame. A text or number field is then edited
   !< as if clicked: typed keys go into it, from the next frame. `offset` 1 is the item after the next, 2 the one after
   !< that; -1 is the item drawn last. The window or region is scrolled to show the item. An offset below -1: nothing
   !< done, `FIG_ERR_ARGUMENT` in `stat` (or `error stop` without it); no frame open or a task: `FIG_ERR_STATE`. The
   !< same in window, headless and remote mode.
   integer(int32), intent(in),  optional :: offset !< Which item: 0 the next (default), 1 the one after, -1 the last.
   integer(int32), intent(out), optional :: stat   !< Status.
   integer(int32)                        :: o      !< Offset.
   character(len=16)                     :: text   !< The offset, written.

   if (figure_draw_refused('ig_focus_here', stat)) return ! a task does not draw
   o = 0_int32
   if (present(offset)) o = offset
   if (o < -1_int32) then
      write(text, '(I0)') o
      call figure_fail(FIG_ERR_ARGUMENT, 'ig_focus_here: offset '//trim(text)//' is below -1', stat)
      return
   endif
   call igSetKeyboardFocusHere(int(o, c_int))
   if (present(stat)) stat = FIG_OK
   endsubroutine ig_focus_here

   recursive subroutine ig_default_focus()
   !< Make the item drawn last the one that has the keyboard focus when its window appears (Dear ImGui's
   !< `SetItemDefaultFocus`): a dialog's safe button, the field a form starts from. Call it after the item; it acts on
   !< the frame the window (a modal, a popup, a window opened by the program) appears, and does nothing on the others,
   !< so it may be called on every frame. The item is focused, not activated: enter or space presses it (keyboard
   !< navigation), a field is edited after enter. No frame open or a task: nothing done (a usage error, reported by
   !< `app%next_frame`). The same in window, headless and remote mode.
   if (figure_draw_refused('ig_default_focus')) return ! a task does not draw
   call igSetItemDefaultFocus()
   endsubroutine ig_default_focus

   recursive subroutine ig_image(tex, width, height)
   !< A texture, pixel row 1 at the top (screen and image-file convention), `width` x `height` pixels (default: the
   !< texture's size).
   type(texture_object), intent(in)           :: tex    !< Texture.
   real(real64),         intent(in), optional :: width  !< Width [pixels].
   real(real64),         intent(in), optional :: height !< Height [pixels].
   type(im_vec2)                              :: extent !< Size (named so: a local `size` crashes nvfortran 26.9).

   if (figure_draw_refused('ig_image')) return ! a task does not draw
   extent = im_vec2(real(tex%width(), c_float), real(tex%height(), c_float))
   if (present(width)) extent%x = real(width, c_float)
   if (present(height)) extent%y = real(height, c_float)
   call fig_texture_sampling(0_c_int, 1_c_int) ! the texture's own filter (nearest unless created smooth)
   call igImage(texture_ref(tex), extent, im_vec2(0.0_c_float, 0.0_c_float), im_vec2(1.0_c_float, 1.0_c_float))
   call fig_texture_sampling(0_c_int, 0_c_int)
   endsubroutine ig_image
endmodule figure_imgui
