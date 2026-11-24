!< figure_code_editor, the Fortran code editor: ImGuiColorTextEdit's TextEditor and FIGURE's glue, in Fortran.
module figure_code_editor
!< figure_code_editor, the Fortran code editor: ImGuiColorTextEdit's TextEditor and FIGURE's glue, in Fortran.
!<
!< szaghi/figure#15 P16. The procedures are the native glue's (`native/figure_editor.cpp`), with its names, arguments,
!< statuses and messages, as Fortran module procedures: `fig_editor_create`, `fig_editor_set_text`, ..., so that the
!< Fortran path's `figure_editor` is the current path's with its interface block replaced by a `use` of this module
!< (scripts/gen_editor_path.py). An editor is a slot of this module's table, addressed by its handle (from 1, never
!< reused), as the glue's map; it is the fork's `TextEditor` as FIGURE configures it (no blanks shown, no pairs
!< completed, no mini-map, no pan indicator, a decoration column of two glyphs for the marks' icons), with the glue's
!< marks (one marker per line, severities from the marker's colour), completion words and word at the cursor.
!<
!< What the fork does only while it draws (`updateState`: colours, bracket pairs, the layout, the markers' list
!< compressed after deletions) is done here at the same point, by the draw.
use, intrinsic :: iso_c_binding, only : c_char, c_double, c_float, c_int, c_long_long
use, intrinsic :: iso_fortran_env, only : int8, int32, int64
use figure_c_native, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK, fig_set_last_error
use figure_code_document, only : code_cursors, code_document, code_pos, code_undo, cursor_has_selection,             &
                                 cursor_selection_end, cursor_selection_start, cursor_update, cursor_update_keep,     &
                                 cursors_add, cursors_adjust_delete, cursors_adjust_insert, cursors_all_selection,    &
                                 cursors_any_selection, cursors_clear_additional, cursors_clear_all, cursors_set,     &
                                 cursors_update, doc_bottom, doc_cp, doc_delete_text, doc_find_text, doc_insert_text, &
                                 doc_normalize, doc_reset, doc_section_text, doc_set_text, doc_text, pos, pos_lt,     &
                                 pos_eq, undo_add_delete, undo_add_insert, undo_begin, undo_end, undo_redo,           &
                                 undo_reset, undo_undo
use figure_code_language, only : lang_key_value, lang_of
use figure_code_unicode, only : cp_is_word

implicit none
private
public :: code_editor, editor_get
public :: fig_editor_create, fig_editor_destroy, fig_editor_language, fig_editor_set_text, fig_editor_string
public :: fig_editor_mark, fig_editor_clear_marks, fig_editor_mark_of, fig_editor_goto, fig_editor_find
public :: fig_editor_replace, fig_editor_cursor, fig_editor_selection, fig_editor_select, fig_editor_insert
public :: fig_editor_completions, fig_editor_completing, fig_editor_option, fig_editor_undo, fig_editor_info
public :: fig_editor_focus
public :: fail, not_found, str, editor_undo_, editor_redo_, make_cursor_visible, start_transaction, end_transaction
public :: insert_text, delete_text, delete_from_all_cursors, insert_into_all_cursors, line_severity, marker_tooltip
public :: with_alpha, SEVERITY_RGB, N_SEVERITY, INVALID, set_cursor, select_next_occurrence, select_all_occurrences
public :: replace_in_current_cursor, ac_cancel, cursor_text

integer(int32), parameter :: INVALID = -1_int32 !< `invalidLine`.
integer(int32), parameter :: N_SEVERITY = 3_int32 !< Marks' severities: 1 error, 2 warning, 3 info.
!< Okabe-Ito vermilion, orange, blue (`IM_COL32(r, g, b, 255)`).
integer(int64), parameter :: SEVERITY_RGB(N_SEVERITY) = [int(z'FF005ED5', int64), int(z'FF009FE6', int64), &
                                                         int(z'FFB27200', int64)]
character(len=*), parameter :: SEVERITY_WORD(N_SEVERITY) = ['error  ', 'warning', 'info   '] !< Severities' words.
integer(int64), parameter :: TEXT_ALPHA = 64_int64    !< The tint of a marked line.
integer(int64), parameter :: NUMBER_ALPHA = 140_int64 !< ... of its line number.

type :: code_editor
   !< An editor: the fork's `TextEditor` state and the glue's `editor_t`.
   type(code_document) :: doc       !< The text.
   type(code_cursors)  :: cursors   !< The cursors.
   type(code_undo)     :: undo      !< The undo list.
   ! config (TextEditor::Config, as the glue sets it)
   integer(int32) :: tab_size = 4_int32          !< tabSize.
   logical        :: spaces_on_tabs = .false.    !< insertSpacesOnTabs.
   logical        :: read_only = .false.         !< readOnly.
   logical        :: carets_visible = .true.     !< caretsVisible.
   logical        :: auto_indent = .true.        !< autoIndent.
   logical        :: show_spaces = .false.       !< showSpaces (the glue: off).
   logical        :: show_tabs = .false.         !< showTabs (the glue: off).
   logical        :: short_tabs = .true.         !< showShortTabs.
   logical        :: line_numbers = .true.       !< showLineNumbers.
   logical        :: line_highlight = .true.     !< showCurrentLineHighlight.
   logical        :: matching_brackets = .true.  !< showMatchingBrackets.
   logical        :: complete_pairs = .false.    !< completePairedGlyphs (the glue: off).
   logical        :: overwrite = .false.         !< overwrite.
   logical        :: find_replace = .true.       !< findReplaceEnabled.
   integer(int32) :: language = 0_int32          !< config.language (0: none).
   integer(int32) :: colored = 0_int32           !< The colourizer's language.
   ! markers (the fork's, both tooltips the same text, as the glue adds them)
   integer(int32)                :: nm = 0_int32 !< Markers.
   integer(int64),   allocatable :: mk_number(:) !< lineNumberColor.
   integer(int64),   allocatable :: mk_text(:)   !< textColor.
   integer(int64),   allocatable :: mk_off(:)    !< Tooltip's offset in `mk_pool`.
   integer(int64),   allocatable :: mk_len(:)    !< Tooltip's length.
   character(len=:), allocatable :: mk_pool      !< Tooltips.
   integer(int64)                :: mk_used = 0_int64 !< Bytes of `mk_pool` used.
   ! completion (the glue's words; the fork's autocomplete state)
   character(len=:), allocatable :: words        !< The program's words, LF-separated ('' none).
   character(len=:), allocatable :: offered      !< The last suggestions, LF-separated.
   integer(int32)                :: noffered = 0_int32 !< Suggestions offered.
   logical        :: key_value = .false.         !< The language is key = value.
   logical        :: ac_configured = .false.     !< AutoComplete::configured.
   logical        :: ac_active = .false.         !< AutoComplete::active.
   logical        :: ac_request_activation = .false.   !< requestActivation.
   logical        :: ac_request_deactivation = .false. !< requestDeactivation.
   logical        :: ac_word_blank = .false.     !< wordCharacters " -" (key = value).
   ! interaction and scrolling
   type(code_pos) :: scroll_to                   !< scrollToDocPos (line INVALID: none).
   integer(int32) :: scroll_to_line = INVALID    !< scrollToLineNumber.
   logical        :: reset_scrolling = .false.   !< resetDearImGuiScrolling.
   logical        :: focus_on_editor = .false.   !< focusOnEditor.
   logical        :: first_frame = .true.        !< firstFrame.
   logical        :: deletes_happened = .false.  !< deletesHappened.
   real(c_float)  :: caret_timer = -0.3_c_float  !< cursorAnimationTimer.
   integer(int32) :: first_row = 0_int32, last_row = 0_int32, first_column = 0_int32, last_column = 0_int32 !< In view.
   logical        :: drawn = .false.             !< Drawn once (the glue's line_rect).
   integer(int32) :: scroll_align = 1_int32      !< scrollToAlignment: 0 top, 1 middle, 2 bottom.
   real(c_float)  :: scroll_fraction = 0.0_c_float !< scrollToFraction.
   ! the palette (Color::count entries, from 0)
   integer(c_int) :: palette_base(0:32) = 0_c_int !< paletteBase (the glue's: the style's palette).
   integer(c_int) :: palette(0:32) = 0_c_int      !< palette (the style's Alpha applied).
   real(c_float)  :: palette_alpha = -1.0_c_float !< paletteAlpha.
   logical        :: palette_set = .false.        !< The glue set a palette once.
   ! layout (the fork's rendering context)
   real(c_float)  :: cursor_width = 1.0_c_float  !< cursorWidth (FIGURE's patch 0002: initialised).
   real(c_float)  :: screen_x = 0.0_c_float, screen_y = 0.0_c_float !< cursorScreenPos.
   real(c_float)  :: visible_w = 0.0_c_float, visible_h = 0.0_c_float !< visibleSize.
   real(c_float)  :: font_size = 0.0_c_float, font_scale = 1.0_c_float !< fontSize, fontScaleDpi.
   real(c_float)  :: glyph_w = 0.0_c_float, glyph_h = 0.0_c_float !< glyphSize.
   real(c_float)  :: number_left = 0.0_c_float, number_right = 0.0_c_float !< lineNumberLeft/RightOffset.
   real(c_float)  :: decoration_offset = 0.0_c_float !< decorationOffset.
   real(c_float)  :: text_left = 0.0_c_float, text_right = 0.0_c_float !< textLeft/RightOffset.
   real(c_float)  :: text_w = 0.0_c_float, text_h = 0.0_c_float !< textSize.
   real(c_float)  :: total_w = 0.0_c_float, total_h = 0.0_c_float !< totalSize.
   real(c_float)  :: rect(4) = 0.0_c_float        !< The child window's rectangle on the last draw (the glue's).
   ! the type setter (rows are lines: no folding, no wrap)
   integer(int32) :: ts_tab = 0_int32            !< Its tab size.
   integer(int32) :: ts_rows = 0_int32           !< Rows (totalRows).
   integer(int32) :: ts_columns = 0_int32        !< totalColumns.
   integer(int32), allocatable :: ts_cols(:)     !< Each row's columns, as at the last update.
   ! the bracketeer
   logical        :: bk_show = .false.           !< Its showMatchingBrackets.
   integer(int32) :: bk_language = 0_int32       !< Its language.
   integer(int32) :: nb = 0_int32                !< Bracket pairs.
   type(code_pos), allocatable :: br_start(:), br_end(:) !< Pairs' positions.
   integer(int32), allocatable :: br_open(:), br_close(:), br_level(:) !< Their characters, levels.
   logical,        allocatable :: br_visible(:)  !< Visible (not an indentation block).
   ! interaction (the fork's)
   logical        :: navigating_vertically = .false. !< navigatingVertically.
   real(c_float)  :: last_click_time = -1.0_c_float  !< lastClickTime.
   logical        :: panning = .false.           !< panning.
   logical        :: scrolling = .false.         !< scrolling.
   real(c_float)  :: scroll_start(2) = 0.0_c_float !< scrollStart.
   logical        :: selecting_text = .false.    !< selectingText.
   ! the autocomplete's session (AutoComplete)
   type(code_pos) :: ac_location                 !< currentLocation.
   type(code_pos) :: ac_start                    !< startLocation.
   logical        :: ac_manual = .false.         !< triggeredManually.
   integer(int32) :: ac_selection = 0_int32      !< currentSelection, from 0.
   type(code_pos) :: ac_rstart                   !< state.replacementStart.
   type(code_pos) :: ac_rend                     !< state.replacementEnd.
   character(len=:), allocatable :: ac_term      !< state.searchTerm.
   ! find and replace (the fork's window)
   logical        :: find_visible = .false.      !< findReplaceVisible.
   logical        :: focus_on_find = .false.     !< focusOnFind.
   logical        :: find_cancelled_ac = .false. !< findCancelledAutocomplete.
   logical        :: find_case = .false.         !< caseSensitiveFind.
   logical        :: find_whole = .false.        !< wholeWordFind.
   character(len=:), allocatable :: find_text    !< findText.
   character(len=:), allocatable :: replace_text !< replaceText.
endtype code_editor

type :: editor_box
   !< A slot of the table.
   type(code_editor), allocatable :: e !< The editor (unallocated: none).
endtype editor_box

type(editor_box), allocatable, target, save :: editors(:)      !< The editors, by handle.
integer(int32),                       save :: next_editor = 1_int32 !< The next handle.

contains
   ! ---- the table ---------------------------------------------------------------------------------------------------
   function editor_get(handle) result(e)
   !< The editor of a handle (null: none). Valid until the next editor is created.
   integer(c_int), intent(in) :: handle !< Handle.
   type(code_editor), pointer :: e      !< Editor.

   e => null()
   if (.not. allocated(editors)) return
   if (handle < 1_c_int .or. handle > size(editors, kind=int32)) return
   if (.not. allocated(editors(handle)%e)) return
   e => editors(handle)%e
   endfunction editor_get

   function fail(status, message) result(s)
   !< Set the last error message; the status (the glue's `fail`).
   integer(c_int),   intent(in) :: status  !< Status.
   character(len=*), intent(in) :: message !< Message.
   integer(c_int)               :: s       !< `status`.

   call fig_set_last_error(message, len(message, c_int))
   s = status
   endfunction fail

   function not_found(what) result(s)
   !< The glue's `ED_FIND` failure.
   character(len=*), intent(in) :: what !< The method.
   integer(c_int)               :: s    !< FIG_ERR_STATE.

   s = fail(FIG_ERR_STATE, 'code_editor_object%'//what//': the editor is not initialized')
   endfunction not_found

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

   pure function lower(s) result(l)
   !< `s` in lower case (ASCII).
   character(len=*), intent(in) :: s !< String.
   character(len=len(s))        :: l !< Lower case.
   integer(int32)               :: i, c !< Counter, code.

   l = s
   do i = 1_int32, len(s, int32)
      c = iachar(s(i:i))
      if (c >= 65_int32 .and. c <= 90_int32) l(i:i) = achar(c + 32_int32)
   enddo
   endfunction lower

   function give(s, buf, n) result(length)
   !< `s` copied into `buf` (up to `n` bytes); its length (the glue's `give`).
   character(len=*),       intent(in)    :: s      !< String.
   character(kind=c_char), intent(inout) :: buf(*) !< Buffer.
   integer(c_long_long),   intent(in)    :: n      !< Room.
   integer(c_long_long)                  :: length !< Length of `s`.
   integer(int64)                        :: k      !< Counter.

   do k = 1_int64, min(n, len(s, int64))
      buf(k) = s(k:k)
   enddo
   length = len(s, c_long_long)
   endfunction give

   ! ---- the fork's editor operations --------------------------------------------------------------------------------
   subroutine editor_new(e)
   !< A new editor (`TextEditor()` and the glue's `editor_t()`).
   type(code_editor), intent(inout) :: e !< Editor.

   call doc_reset(e%doc)
   call cursors_clear_all(e%cursors)
   call undo_reset(e%undo)
   e%scroll_to = pos(INVALID, 0_int32)
   e%words = ''
   e%offered = ''
   e%find_text = ''
   e%ac_term = ''
   e%replace_text = ''
   allocate(e%mk_number(8), e%mk_text(8), e%mk_off(8), e%mk_len(8))
   allocate(character(len=256) :: e%mk_pool)
   endsubroutine editor_new

   subroutine reset_scrolling(e)
   !< `resetScrolling`.
   type(code_editor), intent(inout) :: e !< Editor.

   e%scroll_to = pos(INVALID, 0_int32)
   e%scroll_to_line = INVALID
   e%first_row = 0_int32
   e%last_row = 0_int32
   e%first_column = 0_int32
   e%last_column = 0_int32
   e%caret_timer = -0.3_c_float
   e%reset_scrolling = .true.
   endsubroutine reset_scrolling

   subroutine make_cursor_visible(e)
   !< `makeCursorVisible`.
   type(code_editor), intent(inout) :: e !< Editor.

   e%scroll_to = e%cursors%c(e%cursors%current + 1)%end
   e%scroll_to_line = INVALID
   e%caret_timer = -0.3_c_float
   endsubroutine make_cursor_visible

   subroutine ac_cancel(e)
   !< `AutoComplete::cancel`.
   type(code_editor), intent(inout) :: e !< Editor.

   if (e%ac_active) e%ac_request_deactivation = .true.
   endsubroutine ac_cancel

   subroutine start_transaction(e, cancels)
   !< `startTransaction`.
   type(code_editor), intent(inout) :: e       !< Editor.
   logical,           intent(in)    :: cancels !< Cancels the autocomplete.

   if (cancels) call ac_cancel(e)
   call undo_begin(e%undo, e%cursors)
   endsubroutine start_transaction

   subroutine end_transaction(e, done)
   !< `endTransaction`.
   type(code_editor), intent(inout)         :: e    !< Editor.
   logical,           intent(out), optional :: done !< It held an action.
   logical                                  :: d    !< Done.

   if (e%undo%na >= e%undo%b_first) call cursors_update(e%cursors)
   call undo_end(e%undo, e%cursors, d)
   if (present(done)) done = d
   endsubroutine end_transaction

   subroutine insert_text(e, start, text, end)
   !< `TextEditor::insertText`: the document changed and the action recorded (cursors untouched).
   type(code_editor), intent(inout) :: e     !< Editor.
   type(code_pos),    intent(in)    :: start !< Where.
   character(len=*),  intent(in)    :: text  !< Text.
   type(code_pos),    intent(out)   :: end   !< End of the insert.

   call doc_insert_text(e%doc, start, text, e%tab_size, e%spaces_on_tabs, end)
   call undo_add_insert(e%undo, start, end, text)
   call make_cursor_visible(e)
   endsubroutine insert_text

   subroutine delete_text(e, a, b)
   !< `TextEditor::deleteText`.
   type(code_editor), intent(inout) :: e    !< Editor.
   type(code_pos),    intent(in)    :: a, b !< Section.

   call undo_add_delete(e%undo, a, b, doc_section_text(e%doc, a, b))
   call doc_delete_text(e%doc, a, b, e%tab_size)
   call make_cursor_visible(e)
   e%caret_timer = -0.3_c_float
   e%deletes_happened = .true.
   endsubroutine delete_text

   subroutine delete_from_all_cursors(e)
   !< `deleteTextFromAllCursors`.
   type(code_editor), intent(inout) :: e    !< Editor.
   type(code_pos)                   :: a, b !< A selection.
   integer(int32)                   :: k    !< Cursor.

   do k = 1_int32, e%cursors%n
      if (cursor_has_selection(e%cursors%c(k))) then
         a = cursor_selection_start(e%cursors%c(k))
         b = cursor_selection_end(e%cursors%c(k))
         call delete_text(e, a, b)
         call cursor_update(e%cursors%c(k), a, a)
         call cursors_adjust_delete(e%cursors, k - 1_int32, a, b, .false.)
      endif
   enddo
   endsubroutine delete_from_all_cursors

   subroutine insert_into_all_cursors(e, text)
   !< `insertTextIntoAllCursors`.
   type(code_editor), intent(inout) :: e    !< Editor.
   character(len=*),  intent(in)    :: text !< Text.
   type(code_pos)                   :: a, b !< Insert.
   integer(int32)                   :: k    !< Cursor.

   call delete_from_all_cursors(e)
   do k = 1_int32, e%cursors%n
      a = cursor_selection_start(e%cursors%c(k))
      call insert_text(e, a, text, b)
      call cursor_update(e%cursors%c(k), b, b)
      call cursors_adjust_insert(e%cursors, k - 1_int32, a, b, .false.)
   enddo
   endsubroutine insert_into_all_cursors

   subroutine set_cursor(e, p)
   !< `setCursor`.
   type(code_editor), intent(inout) :: e !< Editor.
   type(code_pos),    intent(in)    :: p !< Position.

   e%scroll_to = doc_normalize(e%doc, p)
   call cursors_set(e%cursors, e%scroll_to, e%scroll_to)
   endsubroutine set_cursor

   subroutine select_next_occurrence(e, text, case_sensitive, whole_word)
   !< `selectNextOccurrenceOf`.
   type(code_editor), intent(inout) :: e              !< Editor.
   character(len=*),  intent(in)    :: text           !< Text.
   logical,           intent(in)    :: case_sensitive !< By case.
   logical,           intent(in)    :: whole_word     !< Whole words.
   type(code_pos)                   :: a, b           !< Occurrence.
   logical                          :: found          !< Found.

   call doc_find_text(e%doc, cursor_selection_end(e%cursors%c(e%cursors%current + 1)), text, case_sensitive, &
                      whole_word, found, a, b)
   if (found) then
      call cursors_set(e%cursors, a, b)
      call make_cursor_visible(e)
   else
      call cursors_clear_additional(e%cursors, .true.)
   endif
   endsubroutine select_next_occurrence

   subroutine select_all_occurrences(e, text, case_sensitive, whole_word)
   !< `selectAllOccurrencesOf`.
   type(code_editor), intent(inout) :: e              !< Editor.
   character(len=*),  intent(in)    :: text           !< Text.
   logical,           intent(in)    :: case_sensitive !< By case.
   logical,           intent(in)    :: whole_word     !< Whole words.
   type(code_pos)                   :: a, b, na, nb   !< Occurrences.
   logical                          :: found          !< Found.

   call doc_find_text(e%doc, pos(0_int32, 0_int32), text, case_sensitive, whole_word, found, a, b)
   if (found) then
      call cursors_set(e%cursors, a, b)
      do
         call doc_find_text(e%doc, cursor_selection_end(e%cursors%c(e%cursors%current + 1)), text, case_sensitive, &
                            whole_word, found, na, nb)
         if (pos_eq(na, a) .and. pos_eq(nb, b)) exit
         call cursors_add(e%cursors, na, nb)
      enddo
   else
      call cursors_clear_additional(e%cursors, .true.)
   endif
   endsubroutine select_all_occurrences

   subroutine replace_in_current_cursor(e, text)
   !< `replaceTextInCurrentCursor`.
   type(code_editor), intent(inout) :: e       !< Editor.
   character(len=*),  intent(in)    :: text    !< Text.
   type(code_pos)                   :: a, b, c !< Selection, end of the insert.
   integer(int32)                   :: k       !< The current cursor, from 1.

   call start_transaction(e, .true.)
   k = e%cursors%current + 1_int32
   a = cursor_selection_start(e%cursors%c(k))
   b = cursor_selection_end(e%cursors%c(k))
   call delete_text(e, a, b)
   call cursors_adjust_delete(e%cursors, k - 1_int32, a, b, .false.)
   call insert_text(e, a, text, c)
   call cursor_update(e%cursors%c(k), c, c)
   call cursors_adjust_insert(e%cursors, k - 1_int32, a, c, .false.)
   call end_transaction(e)
   endsubroutine replace_in_current_cursor

   subroutine editor_undo_(e)
   !< `undo`.
   type(code_editor), intent(inout) :: e !< Editor.

   if (e%undo%undo_index > 0_int32) then
      call undo_undo(e%undo, e%doc, e%cursors, e%tab_size, e%spaces_on_tabs)
      call make_cursor_visible(e)
   endif
   endsubroutine editor_undo_

   subroutine editor_redo_(e)
   !< `redo`.
   type(code_editor), intent(inout) :: e !< Editor.

   if (e%undo%undo_index < e%undo%nt_) then
      call undo_redo(e%undo, e%doc, e%cursors, e%tab_size, e%spaces_on_tabs)
      call make_cursor_visible(e)
   endif
   endsubroutine editor_redo_

   ! ---- markers -----------------------------------------------------------------------------------------------------
   pure function with_alpha(c, a) result(w)
   !< A packed colour with alpha `a` (the glue's `with_alpha`).
   integer(int64), intent(in) :: c !< Colour (IM_COL32).
   integer(int64), intent(in) :: a !< Alpha, 0-255.
   integer(int64)             :: w !< Colour.

   w = ior(iand(c, int(z'00FFFFFF', int64)), ishft(a, 24))
   endfunction with_alpha

   subroutine add_marker(e, line, number_color, text_color, tooltip)
   !< `addMarker` (both tooltips the same text).
   type(code_editor), intent(inout) :: e            !< Editor.
   integer(int32),    intent(in)    :: line         !< Line, from 0.
   integer(int64),    intent(in)    :: number_color !< lineNumberColor.
   integer(int64),    intent(in)    :: text_color   !< textColor.
   character(len=*),  intent(in)    :: tooltip      !< Tooltip.
   integer(int64), allocatable      :: a(:), b(:), c(:), d(:) !< Grown arrays.
   character(len=:), allocatable    :: p            !< Grown pool.

   if (line >= e%doc%n) return
   if (e%nm == size(e%mk_number, kind=int32)) then
      allocate(a(2 * e%nm), b(2 * e%nm), c(2 * e%nm), d(2 * e%nm))
      a(1:e%nm) = e%mk_number(1:e%nm)
      b(1:e%nm) = e%mk_text(1:e%nm)
      c(1:e%nm) = e%mk_off(1:e%nm)
      d(1:e%nm) = e%mk_len(1:e%nm)
      call move_alloc(a, e%mk_number)
      call move_alloc(b, e%mk_text)
      call move_alloc(c, e%mk_off)
      call move_alloc(d, e%mk_len)
   endif
   if (len(e%mk_pool, int64) < e%mk_used + len(tooltip, int64)) then
      allocate(character(len=max(2_int64 * len(e%mk_pool, int64), e%mk_used + len(tooltip, int64))) :: p)
      p(1:e%mk_used) = e%mk_pool(1:e%mk_used)
      call move_alloc(p, e%mk_pool)
   endif
   e%nm = e%nm + 1_int32
   e%mk_number(e%nm) = number_color
   e%mk_text(e%nm) = text_color
   e%mk_off(e%nm) = e%mk_used
   e%mk_len(e%nm) = len(tooltip, int64)
   e%mk_pool(e%mk_used + 1_int64:e%mk_used + len(tooltip, int64)) = tooltip
   e%mk_used = e%mk_used + len(tooltip, int64)
   e%doc%lines(line + 1)%marker = e%nm
   endsubroutine add_marker

   subroutine clear_markers(e)
   !< `clearMarkers`.
   type(code_editor), intent(inout) :: e !< Editor.
   integer(int32)                   :: k !< Line.

   do k = 1_int32, e%doc%n
      e%doc%lines(k)%marker = 0_int32
   enddo
   e%nm = 0_int32
   e%mk_used = 0_int64
   endsubroutine clear_markers

   function marker_tooltip(e, m) result(t)
   !< Marker `m`'s tooltip (from 1).
   type(code_editor), intent(in) :: e !< Editor.
   integer(int32),    intent(in) :: m !< Marker.
   character(len=:), allocatable :: t !< Tooltip.

   t = e%mk_pool(e%mk_off(m) + 1_int64:e%mk_off(m) + e%mk_len(m))
   endfunction marker_tooltip

   pure function line_severity(e, line) result(sev)
   !< The severity of a line's marker, from its colour (the glue's `line_severity`).
   type(code_editor), intent(in) :: e    !< Editor.
   integer(int32),    intent(in) :: line !< Line, from 0.
   integer(int32)                :: sev  !< 0 none, 1 error, 2 warning, 3 info.
   integer(int32)                :: m, k !< Marker, counter.

   sev = 0_int32
   if (line < 0_int32 .or. line >= e%doc%n) return
   m = e%doc%lines(line + 1)%marker
   if (m == 0_int32 .or. m > e%nm) return
   do k = 1_int32, N_SEVERITY
      if (e%mk_text(m) == with_alpha(SEVERITY_RGB(k), TEXT_ALPHA)) then
         sev = k
         return
      endif
   enddo
   endfunction line_severity

   function mark_text(e, line) result(t)
   !< A line's marker's tooltip (the glue's `mark_text`).
   type(code_editor), intent(in) :: e    !< Editor.
   integer(int32),    intent(in) :: line !< Line, from 0.
   character(len=:), allocatable :: t    !< Tooltip.
   integer(int32)                :: m    !< Marker.

   t = ''
   if (line < 0_int32 .or. line >= e%doc%n) return
   m = e%doc%lines(line + 1)%marker
   if (m > 0_int32 .and. m <= e%nm) t = marker_tooltip(e, m)
   endfunction mark_text

   function word_at_cursor(e) result(w)
   !< The word the main cursor is in or just after (the glue's `word_at_cursor`).
   type(code_editor), intent(in) :: e    !< Editor.
   character(len=:), allocatable :: w    !< Word.
   type(code_pos)                :: p    !< Cursor.
   integer(int32)                :: a, b !< The word's ends.

   w = ''
   p = e%cursors%c(min(e%cursors%main, e%cursors%n - 1_int32) + 1)%end
   if (p%l >= e%doc%n) return
   associate(line => e%doc%lines(p%l + 1))
      a = min(p%i, line%n)
      b = a
      do while (a > 0_int32)
         if (.not. cp_is_word(line%cp(a))) exit
         a = a - 1_int32
      enddo
      do while (b < line%n)
         if (.not. cp_is_word(line%cp(b + 1))) exit
         b = b + 1_int32
      enddo
   endassociate
   if (a < b) w = doc_section_text(e%doc, pos(p%l, a), pos(p%l, b))
   endfunction word_at_cursor

   function cursor_text(e, k) result(t)
   !< `GetCursorText(k)`: cursor `k`'s (from 0) selected text.
   type(code_editor), intent(in) :: e !< Editor.
   integer(int32),    intent(in) :: k !< Cursor, from 0.
   character(len=:), allocatable :: t !< Text.

   t = ''
   if (k < e%cursors%n) t = doc_section_text(e%doc, cursor_selection_start(e%cursors%c(k + 1)), &
                                             cursor_selection_end(e%cursors%c(k + 1)))
   endfunction cursor_text

   subroutine set_words(e, words)
   !< The glue's `set_words`: completion words (LF-separated, none: completion off).
   type(code_editor), intent(inout) :: e     !< Editor.
   character(len=*),  intent(in)    :: words !< Words.

   e%words = words
   e%offered = ''
   e%noffered = 0_int32
   e%ac_configured = len(words) > 0
   e%ac_word_blank = e%key_value
   e%ac_active = .false.
   endsubroutine set_words

   ! ---- the glue's entry points (native/figure_editor.cpp) ------------------------------------------------------------
   function fig_editor_create(handle) result(status)
   !< A new editor; its handle.
   integer(c_int), intent(out) :: handle !< Handle.
   integer(c_int)              :: status !< Status.
   type(editor_box), allocatable :: more(:) !< Grown table.
   integer(int32)              :: k      !< Counter.

   handle = 0_c_int
   if (.not. allocated(editors)) allocate(editors(8))
   if (next_editor > size(editors, kind=int32)) then
      allocate(more(2 * size(editors)))
      do k = 1_int32, size(editors, kind=int32)
         if (allocated(editors(k)%e)) call move_alloc(editors(k)%e, more(k)%e)
      enddo
      call move_alloc(more, editors)
   endif
   handle = next_editor
   next_editor = next_editor + 1_int32
   allocate(editors(handle)%e)
   call editor_new(editors(handle)%e)
   status = FIG_OK
   endfunction fig_editor_create

   subroutine fig_editor_destroy(handle)
   !< Release an editor.
   integer(c_int), intent(in) :: handle !< Handle.

   if (.not. allocated(editors)) return
   if (handle < 1_c_int .or. handle > size(editors, kind=int32)) return
   if (allocated(editors(handle)%e)) deallocate(editors(handle)%e)
   endsubroutine fig_editor_destroy

   function fig_editor_language(handle, packed, packed_len) result(status)
   !< Highlight a language (its packed definition).
   integer(c_int),         intent(in) :: handle     !< Handle.
   character(kind=c_char), intent(in) :: packed(*)  !< Definition.
   integer(c_int),         intent(in) :: packed_len !< Its length.
   integer(c_int)                     :: status     !< Status.
   type(code_editor), pointer         :: e          !< Editor.
   integer(int32)                     :: id, s      !< Language, status.
   character(len=:), allocatable      :: msg        !< Message.

   e => editor_get(handle)
   if (.not. associated(e)) then
      status = not_found('init')
      return
   endif
   call lang_of(str(packed, int(packed_len, int64)), id, s, msg)
   if (s /= 0_int32) then
      status = fail(FIG_ERR_ARGUMENT, msg)
      return
   endif
   e%key_value = lang_key_value(id)
   e%language = id
   if (len(e%words) > 0) call set_words(e, e%words)
   status = FIG_OK
   endfunction fig_editor_language

   function fig_editor_set_text(handle, text, n) result(status)
   !< Replace the text (`SetText`), the marks cleared.
   integer(c_int),         intent(in) :: handle  !< Handle.
   character(kind=c_char), intent(in) :: text(*) !< Text.
   integer(c_long_long),   intent(in) :: n       !< Its length.
   integer(c_int)                     :: status  !< Status.
   type(code_editor), pointer         :: e       !< Editor.

   e => editor_get(handle)
   if (.not. associated(e)) then
      status = not_found('set_text')
      return
   endif
   call undo_reset(e%undo)
   call cursors_clear_all(e%cursors)
   call clear_markers(e)
   call reset_scrolling(e)
   call doc_set_text(e%doc, unix_lines(str(text, max(0_int64, int(n, int64)))), e%tab_size, e%spaces_on_tabs)
   call clear_markers(e)
   status = FIG_OK
   endfunction fig_editor_set_text

   function fig_editor_string(handle, what, buf, n) result(length)
   !< One of the editor's texts: 0 the text, 1 the word at the cursor, 2 the selected text, 3 the completions offered.
   integer(c_int),         intent(in)    :: handle !< Handle.
   integer(c_int),         intent(in)    :: what   !< Which.
   character(kind=c_char), intent(inout) :: buf(*) !< Buffer.
   integer(c_long_long),   intent(in)    :: n      !< Its room.
   integer(c_long_long)                  :: length !< The text's length.
   type(code_editor), pointer            :: e      !< Editor.

   length = 0_c_long_long
   e => editor_get(handle)
   if (.not. associated(e)) return
   select case (what)
   case (0_c_int)
      length = give(doc_text(e%doc), buf, n)
   case (1_c_int)
      length = give(word_at_cursor(e), buf, n)
   case (2_c_int)
      if (cursor_has_selection(e%cursors%c(e%cursors%main + 1))) then
         length = give(cursor_text(e, 0_int32), buf, n)
      else
         length = give('', buf, n)
      endif
   case (3_c_int)
      if (e%ac_active .and. e%noffered > 0_int32) then
         length = give(e%offered, buf, n)
      else
         length = give('', buf, n)
      endif
   endselect
   endfunction fig_editor_string

   function fig_editor_mark(handle, line, severity, message, message_len) result(status)
   !< Mark a line (from 1) with a severity (1 error, 2 warning, 3 info) and a message.
   integer(c_int),         intent(in) :: handle      !< Handle.
   integer(c_int),         intent(in) :: line        !< Line, from 1.
   integer(c_int),         intent(in) :: severity    !< Severity.
   character(kind=c_char), intent(in) :: message(*)  !< Message.
   integer(c_int),         intent(in) :: message_len !< Its length.
   integer(c_int)                     :: status      !< Status.
   type(code_editor), pointer         :: e           !< Editor.
   character(len=:), allocatable      :: text        !< The tooltip.
   character(len=16)                  :: a, b        !< Numbers.
   integer(int32)                     :: sev, old    !< Severities.
   integer(int64)                     :: c           !< Colour.

   e => editor_get(handle)
   if (.not. associated(e)) then
      status = not_found('mark')
      return
   endif
   if (severity < 1_c_int .or. severity > N_SEVERITY) then
      status = fail(FIG_ERR_ARGUMENT, "code_editor_object%mark: severity must be 'error', 'warning' or 'info'")
      return
   endif
   if (line < 1_c_int) then
      status = fail(FIG_ERR_ARGUMENT, 'code_editor_object%mark: lines are numbered from 1')
      return
   endif
   if (line - 1_c_int >= e%doc%n) then
      write(a, '(I0)') line
      write(b, '(I0)') e%doc%n
      status = fail(FIG_ERR_ARGUMENT, 'code_editor_object%mark: line '//trim(a)//' is past the last, '//trim(b))
      return
   endif
   sev = severity
   text = trim(SEVERITY_WORD(sev))//': '//str(message, int(message_len, int64))
   old = line_severity(e, line - 1_int32)
   if (old > 0_int32) then
      text = mark_text(e, line - 1_int32)//achar(10)//text
      sev = min(sev, old)
   endif
   c = SEVERITY_RGB(sev)
   call add_marker(e, line - 1_int32, with_alpha(c, NUMBER_ALPHA), with_alpha(c, TEXT_ALPHA), text)
   status = FIG_OK
   endfunction fig_editor_mark

   function fig_editor_clear_marks(handle) result(status)
   !< Remove every mark.
   integer(c_int), intent(in) :: handle !< Handle.
   integer(c_int)             :: status !< Status.
   type(code_editor), pointer :: e      !< Editor.

   e => editor_get(handle)
   if (.not. associated(e)) then
      status = not_found('clear_marks')
      return
   endif
   call clear_markers(e)
   status = FIG_OK
   endfunction fig_editor_clear_marks

   function fig_editor_mark_of(handle, line, severity, buf, n) result(length)
   !< The severity of the mark on a line (from 1) and its message.
   integer(c_int),         intent(in)    :: handle   !< Handle.
   integer(c_int),         intent(in)    :: line     !< Line, from 1.
   integer(c_int),         intent(out)   :: severity !< 0 none, 1 error, 2 warning, 3 info.
   character(kind=c_char), intent(inout) :: buf(*)   !< Buffer.
   integer(c_long_long),   intent(in)    :: n        !< Its room.
   integer(c_long_long)                  :: length   !< The message's length.
   type(code_editor), pointer            :: e        !< Editor.

   severity = 0_c_int
   length = 0_c_long_long
   e => editor_get(handle)
   if (.not. associated(e) .or. line < 1_c_int) return
   severity = line_severity(e, line - 1_int32)
   length = give(mark_text(e, line - 1_int32), buf, n)
   endfunction fig_editor_mark_of

   function fig_editor_goto(handle, line, column, focus) result(status)
   !< Move the cursor to a line and column (from 1); the keyboard to the editor with `focus`.
   integer(c_int), intent(in) :: handle       !< Handle.
   integer(c_int), intent(in) :: line, column !< Position, from 1.
   integer(c_int), intent(in) :: focus        !< Focus.
   integer(c_int)             :: status       !< Status.
   type(code_editor), pointer :: e            !< Editor.

   e => editor_get(handle)
   if (.not. associated(e)) then
      status = not_found('goto')
      return
   endif
   if (line < 1_c_int .or. column < 1_c_int) then
      status = fail(FIG_ERR_ARGUMENT, 'code_editor_object%goto: lines and columns are numbered from 1')
      return
   endif
   call set_cursor(e, pos(line - 1_int32, column - 1_int32))
   if (focus /= 0_c_int) e%focus_on_editor = .true.
   status = FIG_OK
   endfunction fig_editor_goto

   function fig_editor_find(handle, text, n, case_sensitive, whole_word, found) result(status)
   !< Select the next occurrence of a text.
   integer(c_int),         intent(in)  :: handle         !< Handle.
   character(kind=c_char), intent(in)  :: text(*)        !< Text.
   integer(c_int),         intent(in)  :: n              !< Its length.
   integer(c_int),         intent(in)  :: case_sensitive !< By case.
   integer(c_int),         intent(in)  :: whole_word     !< Whole words.
   integer(c_int),         intent(out) :: found          !< Found.
   integer(c_int)                      :: status         !< Status.
   type(code_editor), pointer          :: e              !< Editor.
   character(len=:), allocatable       :: t, got         !< Text, selection.

   found = 0_c_int
   e => editor_get(handle)
   if (.not. associated(e)) then
      status = not_found('find')
      return
   endif
   t = str(text, int(n, int64))
   if (len(t) == 0) then
      status = fail(FIG_ERR_ARGUMENT, 'code_editor_object%find: the text is empty')
      return
   endif
   call select_next_occurrence(e, t, case_sensitive /= 0_c_int, whole_word /= 0_c_int)
   if (cursor_has_selection(e%cursors%c(e%cursors%main + 1))) then
      got = cursor_text(e, 0_int32)
      if (case_sensitive /= 0_c_int) then
         if (got == t .and. len(got) == len(t)) found = 1_c_int
      else
         if (lower(got) == lower(t) .and. len(got) == len(t)) found = 1_c_int
      endif
   endif
   status = FIG_OK
   endfunction fig_editor_find

   function fig_editor_replace(handle, what, what_len, with, with_len, case_sensitive, whole_word, count) result(status)
   !< Replace every occurrence of a text, in one transaction.
   integer(c_int),         intent(in)  :: handle         !< Handle.
   character(kind=c_char), intent(in)  :: what(*)        !< Text.
   integer(c_int),         intent(in)  :: what_len       !< Its length.
   character(kind=c_char), intent(in)  :: with(*)        !< Replacement.
   integer(c_int),         intent(in)  :: with_len       !< Its length.
   integer(c_int),         intent(in)  :: case_sensitive !< By case.
   integer(c_int),         intent(in)  :: whole_word     !< Whole words.
   integer(c_int),         intent(out) :: count          !< Occurrences replaced.
   integer(c_int)                      :: status         !< Status.
   type(code_editor), pointer          :: e              !< Editor.

   count = 0_c_int
   e => editor_get(handle)
   if (.not. associated(e)) then
      status = not_found('replace')
      return
   endif
   if (what_len <= 0_c_int) then
      status = fail(FIG_ERR_ARGUMENT, 'code_editor_object%replace: the text is empty')
      return
   endif
   if (e%read_only) then
      status = fail(FIG_ERR_STATE, 'code_editor_object%replace: the editor is read-only')
      return
   endif
   call select_all_occurrences(e, str(what, int(what_len, int64)), case_sensitive /= 0_c_int, whole_word /= 0_c_int)
   if (.not. cursors_all_selection(e%cursors)) then
      call cursors_clear_all(e%cursors)
      status = FIG_OK
      return
   endif
   count = e%cursors%n
   call start_transaction(e, .true.)
   call insert_into_all_cursors(e, str(with, int(with_len, int64)))
   call end_transaction(e)
   call cursors_clear_all(e%cursors)
   status = FIG_OK
   endfunction fig_editor_replace

   function fig_editor_cursor(handle, line, column) result(status)
   !< The main cursor's line and column (from 1).
   integer(c_int), intent(in)  :: handle       !< Handle.
   integer(c_int), intent(out) :: line, column !< Position.
   integer(c_int)              :: status       !< Status.
   type(code_editor), pointer  :: e            !< Editor.
   type(code_pos)              :: p            !< Position.

   line = 1_c_int
   column = 1_c_int
   e => editor_get(handle)
   if (.not. associated(e)) then
      status = not_found('cursor')
      return
   endif
   p = e%cursors%c(min(e%cursors%main, e%cursors%n - 1_int32) + 1)%end
   line = p%l + 1_c_int
   column = p%i + 1_c_int
   status = FIG_OK
   endfunction fig_editor_cursor

   function fig_editor_selection(handle, p, has) result(status)
   !< The main cursor's selection (from 1) and whether it has one.
   integer(c_int), intent(in)  :: handle !< Handle.
   integer(c_int), intent(out) :: p(4)   !< First line, column, last line, column.
   integer(c_int), intent(out) :: has    !< A selection.
   integer(c_int)              :: status !< Status.
   type(code_editor), pointer  :: e      !< Editor.
   type(code_pos)              :: a, b   !< Selection.
   integer(int32)              :: k      !< Cursor.

   has = 0_c_int
   e => editor_get(handle)
   if (.not. associated(e)) then
      status = not_found('selection')
      return
   endif
   k = min(e%cursors%main, e%cursors%n - 1_int32) + 1_int32
   a = cursor_selection_start(e%cursors%c(k))
   b = cursor_selection_end(e%cursors%c(k))
   p = [a%l + 1_c_int, a%i + 1_c_int, b%l + 1_c_int, b%i + 1_c_int]
   if (cursor_has_selection(e%cursors%c(e%cursors%main + 1))) has = 1_c_int
   status = FIG_OK
   endfunction fig_editor_selection

   function fig_editor_select(handle, l0, c0, l1, c1) result(status)
   !< Select a region (from 1).
   integer(c_int), intent(in) :: handle         !< Handle.
   integer(c_int), intent(in) :: l0, c0, l1, c1 !< First line, column, last line, column.
   integer(c_int)             :: status         !< Status.
   type(code_editor), pointer :: e              !< Editor.
   type(code_pos)             :: a, b           !< Region.

   e => editor_get(handle)
   if (.not. associated(e)) then
      status = not_found('select')
      return
   endif
   if (l0 < 1_c_int .or. c0 < 1_c_int .or. l1 < 1_c_int .or. c1 < 1_c_int) then
      status = fail(FIG_ERR_ARGUMENT, 'code_editor_object%select: lines and columns are numbered from 1')
      return
   endif
   a = doc_normalize(e%doc, pos(l0 - 1_int32, c0 - 1_int32))
   b = doc_normalize(e%doc, pos(l1 - 1_int32, c1 - 1_int32))
   if (pos_lt(b, a)) then
      call cursors_set(e%cursors, b, a)
   else
      call cursors_set(e%cursors, a, b)
   endif
   status = FIG_OK
   endfunction fig_editor_select

   function fig_editor_insert(handle, text, n) result(status)
   !< Insert a text at the current cursor, in place of its selection, as one transaction.
   integer(c_int),         intent(in) :: handle  !< Handle.
   character(kind=c_char), intent(in) :: text(*) !< Text.
   integer(c_long_long),   intent(in) :: n       !< Its length.
   integer(c_int)                     :: status  !< Status.
   type(code_editor), pointer         :: e       !< Editor.

   e => editor_get(handle)
   if (.not. associated(e)) then
      status = not_found('insert')
      return
   endif
   if (e%read_only) then
      status = fail(FIG_ERR_STATE, 'code_editor_object%insert: the editor is read-only')
      return
   endif
   call replace_in_current_cursor(e, unix_lines(str(text, max(0_int64, int(n, int64)))))
   status = FIG_OK
   endfunction fig_editor_insert

   function fig_editor_completions(handle, words, n) result(status)
   !< The words completion offers, LF-separated (empty ones left out).
   integer(c_int),         intent(in) :: handle   !< Handle.
   character(kind=c_char), intent(in) :: words(*) !< Words.
   integer(c_long_long),   intent(in) :: n        !< Their length.
   integer(c_int)                     :: status   !< Status.
   type(code_editor), pointer         :: e        !< Editor.
   character(len=:), allocatable      :: all, w   !< Words given, kept.
   integer(int64)                     :: a, k     !< Start of a word, counter.

   e => editor_get(handle)
   if (.not. associated(e)) then
      status = not_found('set_completions')
      return
   endif
   all = str(words, max(0_int64, int(n, int64)))
   w = ''
   a = 1_int64
   do k = 1_int64, len(all, int64) + 1_int64
      if (k <= len(all, int64)) then
         if (all(k:k) /= achar(10)) cycle
      endif
      if (k > a) then
         if (len(w) > 0) w = w//achar(10)
         w = w//all(a:k - 1_int64)
      endif
      a = k + 1_int64
   enddo
   call set_words(e, w)
   status = FIG_OK
   endfunction fig_editor_completions

   function fig_editor_completing(handle, active) result(status)
   !< Whether the completion popup is open.
   integer(c_int), intent(in)  :: handle !< Handle.
   integer(c_int), intent(out) :: active !< Open.
   integer(c_int)              :: status !< Status.
   type(code_editor), pointer  :: e      !< Editor.

   active = 0_c_int
   e => editor_get(handle)
   if (.not. associated(e)) then
      status = not_found('completing')
      return
   endif
   if (e%ac_active .and. e%noffered > 0_int32) active = 1_c_int
   status = FIG_OK
   endfunction fig_editor_completing

   function fig_editor_option(handle, option, set, value) result(status)
   !< An option (0 read-only, 1 line numbers, 2 tab size, 3 white space shown, 4 the current line highlighted), set
   !< with `set` /= 0; its value.
   integer(c_int), intent(in)    :: handle !< Handle.
   integer(c_int), intent(in)    :: option !< Option.
   integer(c_int), intent(in)    :: set    !< Write it.
   integer(c_int), intent(inout) :: value  !< Its value.
   integer(c_int)                :: status !< Status.
   type(code_editor), pointer    :: e      !< Editor.

   e => editor_get(handle)
   if (.not. associated(e)) then
      status = not_found('option')
      return
   endif
   select case (option)
   case (0_c_int)
      if (set /= 0_c_int) e%read_only = value /= 0_c_int
      value = merge(1_c_int, 0_c_int, e%read_only)
   case (1_c_int)
      if (set /= 0_c_int) e%line_numbers = value /= 0_c_int
      value = merge(1_c_int, 0_c_int, e%line_numbers)
   case (2_c_int)
      if (set /= 0_c_int) then
         if (value < 1_c_int .or. value > 16_c_int) then
            status = fail(FIG_ERR_ARGUMENT, 'code_editor_object%set_tab_size: in [1, 16]')
            return
         endif
         e%tab_size = value
      endif
      value = e%tab_size
   case (3_c_int)
      if (set /= 0_c_int) then
         e%show_spaces = value /= 0_c_int
         e%show_tabs = value /= 0_c_int
      endif
      value = merge(1_c_int, 0_c_int, e%show_spaces .and. e%show_tabs)
   case (4_c_int)
      if (set /= 0_c_int) e%line_highlight = value /= 0_c_int
      value = merge(1_c_int, 0_c_int, e%line_highlight)
   case default
      status = fail(FIG_ERR_ARGUMENT, 'code editor: unknown option')
      return
   endselect
   status = FIG_OK
   endfunction fig_editor_option

   function fig_editor_undo(handle, redo, done) result(status)
   !< Undo (`redo` 0) or redo the last change; `done` when there was one.
   integer(c_int), intent(in)  :: handle !< Handle.
   integer(c_int), intent(in)  :: redo   !< Redo.
   integer(c_int), intent(out) :: done   !< Done.
   integer(c_int)              :: status !< Status.
   type(code_editor), pointer  :: e      !< Editor.

   done = 0_c_int
   e => editor_get(handle)
   if (.not. associated(e)) then
      status = not_found(merge('redo', 'undo', redo /= 0_c_int))
      return
   endif
   if (redo /= 0_c_int) then
      if (.not. e%read_only .and. e%undo%undo_index < e%undo%nt_) then
         call editor_redo_(e)
         done = 1_c_int
      endif
   else
      if (.not. e%read_only .and. e%undo%undo_index > 0_int32) then
         call editor_undo_(e)
         done = 1_c_int
      endif
   endif
   status = FIG_OK
   endfunction fig_editor_undo

   function fig_editor_info(handle, lines, can_undo, can_redo) result(status)
   !< The number of lines, whether undo and redo can be done.
   integer(c_int), intent(in)  :: handle   !< Handle.
   integer(c_int), intent(out) :: lines    !< Lines.
   integer(c_int), intent(out) :: can_undo !< Undo possible.
   integer(c_int), intent(out) :: can_redo !< Redo possible.
   integer(c_int)              :: status   !< Status.
   type(code_editor), pointer  :: e        !< Editor.

   lines = 0_c_int
   can_undo = 0_c_int
   can_redo = 0_c_int
   e => editor_get(handle)
   if (.not. associated(e)) then
      status = not_found('line_count')
      return
   endif
   lines = e%doc%n
   if (.not. e%read_only .and. e%undo%undo_index > 0_int32) can_undo = 1_c_int
   if (.not. e%read_only .and. e%undo%undo_index < e%undo%nt_) can_redo = 1_c_int
   status = FIG_OK
   endfunction fig_editor_info

   function fig_editor_focus(handle) result(status)
   !< Give the editor the keyboard at the next draw.
   integer(c_int), intent(in) :: handle !< Handle.
   integer(c_int)             :: status !< Status.
   type(code_editor), pointer :: e      !< Editor.

   e => editor_get(handle)
   if (.not. associated(e)) then
      status = not_found('focus')
      return
   endif
   e%focus_on_editor = .true.
   status = FIG_OK
   endfunction fig_editor_focus
endmodule figure_code_editor
