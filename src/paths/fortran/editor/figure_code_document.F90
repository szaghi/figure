!< figure_code_document, the code editor's text: lines of glyphs, positions, cursors and the undo list.
module figure_code_document
!< figure_code_document, the code editor's text: lines of glyphs, positions, cursors and the undo list.
!<
!< szaghi/figure#15 P16: ImGuiColorTextEdit's `Document`, `Cursor`, `Cursors`, `Transaction` and `Transactions`
!< (TextEditor.h/.cpp), in Fortran. Positions are the fork's `DocPos`: a line and a glyph index, both from 0 (line `l`
!< is `doc%lines(l + 1)`). A line keeps its glyphs as arrays (code point, colour, columns) with room to grow, so an edit
!< moves glyphs, not lines' storage; the document keeps its lines with room to grow, moved by `move_alloc` when one is
!< inserted or deleted. The undo list is flat: every transaction's actions, their texts and the cursors before and after
!< in pools of the list, appended in order (an undo moves an index; a new transaction cuts the pools at it), so no
!< transaction owns an allocation. Line folding, word wrap, squiggles and user data are the fork's features FIGURE does
!< not use (its glue never turns them on): they are left out, and every line is visible.
use, intrinsic :: iso_fortran_env, only : int8, int32, int64
use figure_code_unicode, only : cp_glyph_width, cp_is_white_space, cp_is_word, cp_read, cp_to_lower, cp_write

implicit none
private
public :: code_pos, code_line, code_document, code_cursor, code_cursors, code_undo
public :: COLOR_TEXT, COLOR_KEYWORD, COLOR_DECLARATION, COLOR_NUMBER, COLOR_STRING, COLOR_PUNCTUATION
public :: COLOR_PREPROCESSOR, COLOR_IDENTIFIER, COLOR_KNOWN_IDENTIFIER, COLOR_COMMENT, COLOR_BACKGROUND, COLOR_CURSOR
public :: COLOR_SELECTION, COLOR_WHITESPACE, COLOR_BRACKET_BACKGROUND, COLOR_BRACKET_ACTIVE, COLOR_BRACKET_LEVEL1
public :: COLOR_BRACKET_LEVEL2, COLOR_BRACKET_LEVEL3, COLOR_BRACKET_ERROR, COLOR_LINE_NUMBER, COLOR_CURRENT_LINE_NUMBER
public :: COLOR_CURRENT_LINE, COLOR_CURRENT_LINE_BORDER, COLOR_COUNT
public :: pos, pos_lt, pos_le, pos_eq, pos_max, pos_min
public :: doc_reset, doc_set_text, doc_text, doc_insert_text, doc_delete_text, doc_section_text, doc_section_length
public :: doc_line_size, doc_cp, doc_bottom, doc_end_of_line, doc_next_line, doc_left, doc_right, doc_normalize
public :: doc_find_word_start, doc_find_word_end, doc_find_text, doc_is_whole_word, doc_whole_word
public :: doc_find_previous_non_white_space, doc_find_next_non_white_space, doc_line_reserve
public :: cursors_clear_all, cursors_set, cursors_add, cursors_clear_additional, cursors_update, cursors_any_selection
public :: cursors_all_selection, cursors_adjust_insert, cursors_adjust_delete, cursor_update, cursor_update_keep
public :: cursor_selection_start, cursor_selection_end, cursor_has_selection, cursor_reset_to_start, cursor_reset_to_end
public :: cursor_grow, cursors_copy
public :: undo_reset, undo_begin, undo_add_insert, undo_add_delete, undo_end, undo_undo, undo_redo

! the palette's colours (TextEditor::Color), as stored in a glyph
integer(int8), parameter :: COLOR_TEXT = 0_int8                 !< Text.
integer(int8), parameter :: COLOR_KEYWORD = 1_int8              !< Keyword.
integer(int8), parameter :: COLOR_DECLARATION = 2_int8          !< Declaration.
integer(int8), parameter :: COLOR_NUMBER = 3_int8               !< Number.
integer(int8), parameter :: COLOR_STRING = 4_int8               !< String.
integer(int8), parameter :: COLOR_PUNCTUATION = 5_int8          !< Punctuation.
integer(int8), parameter :: COLOR_PREPROCESSOR = 6_int8         !< Preprocessor.
integer(int8), parameter :: COLOR_IDENTIFIER = 7_int8           !< Identifier.
integer(int8), parameter :: COLOR_KNOWN_IDENTIFIER = 8_int8     !< Known identifier.
integer(int8), parameter :: COLOR_COMMENT = 9_int8              !< Comment.
integer(int8), parameter :: COLOR_BACKGROUND = 10_int8          !< Background.
integer(int8), parameter :: COLOR_CURSOR = 11_int8              !< Cursor.
integer(int8), parameter :: COLOR_SELECTION = 12_int8           !< Selection.
integer(int8), parameter :: COLOR_WHITESPACE = 13_int8          !< White space.
integer(int8), parameter :: COLOR_BRACKET_BACKGROUND = 14_int8  !< Matching bracket's background.
integer(int8), parameter :: COLOR_BRACKET_ACTIVE = 15_int8      !< Active bracket pair's line.
integer(int8), parameter :: COLOR_BRACKET_LEVEL1 = 16_int8      !< Bracket, level 1.
integer(int8), parameter :: COLOR_BRACKET_LEVEL2 = 17_int8      !< Bracket, level 2.
integer(int8), parameter :: COLOR_BRACKET_LEVEL3 = 18_int8      !< Bracket, level 3.
integer(int8), parameter :: COLOR_BRACKET_ERROR = 19_int8       !< Unmatched bracket.
integer(int8), parameter :: COLOR_LINE_NUMBER = 20_int8         !< Line number.
integer(int8), parameter :: COLOR_CURRENT_LINE_NUMBER = 21_int8 !< The cursor's line number.
integer(int8), parameter :: COLOR_CURRENT_LINE = 22_int8        !< The cursor's line's tint.
integer(int8), parameter :: COLOR_CURRENT_LINE_BORDER = 23_int8 !< ... its border.
integer(int32), parameter :: COLOR_COUNT = 33_int32             !< Colours of a palette (the custom ones included).

type :: code_pos
   !< A position (`DocPos`): line and glyph index, from 0.
   integer(int32) :: l = 0_int32 !< Line.
   integer(int32) :: i = 0_int32 !< Glyph index.
endtype code_pos

type :: code_line
   !< A line: its glyphs (code point, colour, columns) and the state the overlays keep.
   integer(int32), allocatable :: cp(:)    !< Code points (room beyond `n`).
   integer(int8),  allocatable :: color(:) !< Colours (`COLOR_*`).
   integer(int8),  allocatable :: cols(:)  !< Columns of each glyph (the type setter's).
   integer(int32) :: n = 0_int32           !< Glyphs.
   integer(int32) :: indent = 0_int32      !< Columns of its leading blanks.
   logical        :: needs_colorizing = .true.  !< The colourizer must see it.
   integer(int32) :: state = 0_int32       !< Colourizer's state at its start (`LineState`).
   logical        :: needs_typesetting = .true. !< The type setter must see it.
   integer(int32) :: row = 0_int32         !< Its first row.
   integer(int32) :: rows = 0_int32        !< Its rows.
   integer(int32) :: columns = 0_int32     !< Its columns.
   integer(int32) :: marker = 0_int32      !< Its marker, from 1 (0: none).
endtype code_line

type :: code_document
   !< The text: lines of glyphs.
   type(code_line), allocatable :: lines(:)      !< Lines (room beyond `n`).
   integer(int32)               :: n = 0_int32   !< Lines.
   logical                      :: updated = .false. !< Changed since the last reset of the flag.
endtype code_document

type :: code_cursor
   !< A cursor (`Cursor`): an interactive start and end (the end is where the caret is).
   type(code_pos) :: start                      !< Interactive start.
   type(code_pos) :: end                        !< Interactive end.
   logical        :: main = .false.             !< The main cursor.
   logical        :: current = .true.           !< The current cursor (the one added last).
   logical        :: updated = .true.           !< Changed since the flags were cleared.
   integer(int32) :: preferred = 0_int32        !< Column kept by up and down.
endtype code_cursor

type :: code_cursors
   !< The cursors (`Cursors`): main and current are indices from 0, as the fork's.
   type(code_cursor), allocatable :: c(:)       !< Cursors (room beyond `n`).
   integer(int32)                 :: n = 0_int32 !< Cursors.
   integer(int32)                 :: main = 0_int32    !< Main cursor, from 0.
   integer(int32)                 :: current = 0_int32 !< Current cursor, from 0.
endtype code_cursors

type :: code_undo
   !< The undo list (`Transactions`) and the transaction being built, flat.
   ! the actions of the list's transactions, in order
   integer(int8),     allocatable :: kind(:)       !< 1 insert, 2 delete.
   type(code_pos),    allocatable :: astart(:)     !< Start of each action.
   type(code_pos),    allocatable :: aend(:)       !< End of each action.
   integer(int64),    allocatable :: off(:)        !< Its text's offset in `text`.
   integer(int64),    allocatable :: alen(:)       !< Its text's length.
   character(len=:),  allocatable :: text          !< The actions' texts.
   integer(int32)                 :: na = 0_int32  !< Actions.
   integer(int64)                 :: nt = 0_int64  !< Bytes of `text` used.
   ! the transactions: their actions and their cursors before and after
   integer(int32),    allocatable :: first(:)      !< First action of each transaction.
   integer(int32),    allocatable :: count(:)      !< Its actions.
   integer(int32),    allocatable :: cfirst(:, :)  !< First cursor (before, after) in `cpool`.
   integer(int32),    allocatable :: ccount(:, :)  !< Cursors (before, after).
   integer(int32),    allocatable :: cmain(:, :)   !< Main cursor index (before, after).
   integer(int32),    allocatable :: ccurrent(:, :) !< Current cursor index (before, after).
   type(code_cursor), allocatable :: cpool(:)      !< The saved cursors.
   integer(int32)                 :: ncp = 0_int32 !< Saved cursors used.
   integer(int32)                 :: nt_ = 0_int32 !< Transactions.
   integer(int32)                 :: undo_index = 0_int32 !< Transactions done (the fork's undoIndex).
   ! the transaction being built
   type(code_cursors)             :: before        !< Cursors at its start.
   integer(int32)                 :: b_first = 0_int32 !< Its first action (an index of the list's, past `na`).
   logical                        :: open = .false. !< One is being built.
endtype code_undo

integer(int32), parameter :: ROOM = 16_int32 !< First capacity of a line, of the lines and of the pools.

contains
   ! ---- positions ---------------------------------------------------------------------------------------------------
   elemental function pos(l, i) result(p)
   !< A position.
   integer(int32), intent(in) :: l, i !< Line, index (from 0).
   type(code_pos)             :: p    !< Position.

   p%l = l
   p%i = i
   endfunction pos

   elemental function pos_lt(a, b) result(yes)
   !< a < b.
   type(code_pos), intent(in) :: a, b !< Positions.
   logical                    :: yes  !< a before b.

   if (a%l /= b%l) then
      yes = a%l < b%l
   else
      yes = a%i < b%i
   endif
   endfunction pos_lt

   elemental function pos_le(a, b) result(yes)
   !< a <= b.
   type(code_pos), intent(in) :: a, b !< Positions.
   logical                    :: yes  !< a not after b.

   if (a%l /= b%l) then
      yes = a%l < b%l
   else
      yes = a%i <= b%i
   endif
   endfunction pos_le

   elemental function pos_eq(a, b) result(yes)
   !< a == b.
   type(code_pos), intent(in) :: a, b !< Positions.
   logical                    :: yes  !< Equal.

   yes = a%l == b%l .and. a%i == b%i
   endfunction pos_eq

   elemental function pos_max(a, b) result(m)
   !< The later of two positions (`start > end ? start : end`).
   type(code_pos), intent(in) :: a, b !< Positions.
   type(code_pos)             :: m    !< The later.

   if (pos_lt(b, a)) then
      m = a
   else
      m = b
   endif
   endfunction pos_max

   elemental function pos_min(a, b) result(m)
   !< The earlier of two positions (`start < end ? start : end`).
   type(code_pos), intent(in) :: a, b !< Positions.
   type(code_pos)             :: m    !< The earlier.

   if (pos_lt(a, b)) then
      m = a
   else
      m = b
   endif
   endfunction pos_min

   ! ---- lines -------------------------------------------------------------------------------------------------------
   pure subroutine doc_line_reserve(line, cap)
   !< Room for at least `cap` glyphs in a line (its glyphs kept).
   type(code_line), intent(inout) :: line !< Line.
   integer(int32),  intent(in)    :: cap  !< Glyphs.
   integer(int32), allocatable    :: c(:) !< New code points.
   integer(int8),  allocatable    :: k(:), w(:) !< New colours, columns.
   integer(int32)                 :: m    !< New capacity.

   if (allocated(line%cp)) then
      if (size(line%cp, kind=int32) >= cap) return
      m = max(cap, 2_int32 * size(line%cp, kind=int32))
   else
      m = max(cap, ROOM)
   endif
   allocate(c(m), k(m), w(m))
   if (allocated(line%cp)) then
      c(1:line%n) = line%cp(1:line%n)
      k(1:line%n) = line%color(1:line%n)
      w(1:line%n) = line%cols(1:line%n)
   endif
   call move_alloc(c, line%cp)
   call move_alloc(k, line%color)
   call move_alloc(w, line%cols)
   endsubroutine doc_line_reserve

   pure subroutine line_reset(line)
   !< An empty line, as the fork's `Line()` (its storage kept).
   type(code_line), intent(inout) :: line !< Line.

   line%n = 0_int32
   line%indent = 0_int32
   line%needs_colorizing = .true.
   line%state = 0_int32
   line%needs_typesetting = .true.
   line%row = 0_int32
   line%rows = 0_int32
   line%columns = 0_int32
   line%marker = 0_int32
   endsubroutine line_reset

   pure subroutine line_move(from, to)
   !< Move a line's storage and state from `from` to `to` (`from` left without storage).
   type(code_line), intent(inout) :: from !< Source.
   type(code_line), intent(inout) :: to   !< Destination.

   if (allocated(to%cp)) deallocate(to%cp, to%color, to%cols)
   if (allocated(from%cp)) then
      call move_alloc(from%cp, to%cp)
      call move_alloc(from%color, to%color)
      call move_alloc(from%cols, to%cols)
   endif
   to%n = from%n
   to%indent = from%indent
   to%needs_colorizing = from%needs_colorizing
   to%state = from%state
   to%needs_typesetting = from%needs_typesetting
   to%row = from%row
   to%rows = from%rows
   to%columns = from%columns
   to%marker = from%marker
   endsubroutine line_move

   pure subroutine line_insert_glyph(line, at, cp)
   !< Insert a glyph (colour text) before index `at` (from 0).
   type(code_line), intent(inout) :: line !< Line.
   integer(int32),  intent(in)    :: at   !< Index, from 0.
   integer(int32),  intent(in)    :: cp   !< Code point.
   integer(int32)                 :: k    !< Counter.

   call doc_line_reserve(line, line%n + 1_int32)
   do k = line%n, at + 1_int32, -1_int32
      line%cp(k + 1) = line%cp(k)
      line%color(k + 1) = line%color(k)
      line%cols(k + 1) = line%cols(k)
   enddo
   line%cp(at + 1) = cp
   line%color(at + 1) = COLOR_TEXT
   line%cols(at + 1) = 1_int8
   line%n = line%n + 1_int32
   endsubroutine line_insert_glyph

   pure subroutine line_erase(line, a, b)
   !< Erase glyphs [a, b) (from 0).
   type(code_line), intent(inout) :: line !< Line.
   integer(int32),  intent(in)    :: a, b !< Range.
   integer(int32)                 :: k, d !< Counter, count.

   d = b - a
   if (d <= 0_int32) return
   do k = b + 1_int32, line%n
      line%cp(k - d) = line%cp(k)
      line%color(k - d) = line%color(k)
      line%cols(k - d) = line%cols(k)
   enddo
   line%n = line%n - d
   endsubroutine line_erase

   pure subroutine line_append(line, from, a)
   !< Append the glyphs of `from` from index `a` (from 0) to its end.
   type(code_line), intent(inout) :: line !< Line.
   type(code_line), intent(in)    :: from !< Source line.
   integer(int32),  intent(in)    :: a    !< First glyph of `from`, from 0.
   integer(int32)                 :: m    !< Glyphs appended.

   m = from%n - a
   if (m <= 0_int32) return
   call doc_line_reserve(line, line%n + m)
   line%cp(line%n + 1:line%n + m) = from%cp(a + 1:from%n)
   line%color(line%n + 1:line%n + m) = from%color(a + 1:from%n)
   line%cols(line%n + 1:line%n + m) = from%cols(a + 1:from%n)
   line%n = line%n + m
   endsubroutine line_append

   ! ---- the document's lines ------------------------------------------------------------------------------------------
   pure subroutine doc_reserve(doc, cap)
   !< Room for at least `cap` lines.
   type(code_document), intent(inout) :: doc  !< Document.
   integer(int32),      intent(in)    :: cap  !< Lines.
   type(code_line), allocatable       :: more(:) !< New lines.
   integer(int32)                     :: m, k !< Capacity, counter.

   if (allocated(doc%lines)) then
      if (size(doc%lines, kind=int32) >= cap) return
      m = max(cap, 2_int32 * size(doc%lines, kind=int32))
   else
      m = max(cap, ROOM)
   endif
   allocate(more(m))
   if (allocated(doc%lines)) then
      do k = 1_int32, doc%n
         call line_move(doc%lines(k), more(k))
      enddo
   endif
   call move_alloc(more, doc%lines)
   endsubroutine doc_reserve

   pure subroutine doc_insert_line(doc, offset)
   !< A new empty line inserted as line `offset` (from 0; `doc%n` appends).
   type(code_document), intent(inout) :: doc    !< Document.
   integer(int32),      intent(in)    :: offset !< Its line, from 0.
   integer(int32)                     :: k      !< Counter.

   call doc_reserve(doc, doc%n + 1_int32)
   do k = doc%n, offset + 1_int32, -1_int32
      call line_move(doc%lines(k), doc%lines(k + 1))
   enddo
   doc%n = doc%n + 1_int32
   call line_reset(doc%lines(offset + 1))
   endsubroutine doc_insert_line

   pure subroutine doc_delete_lines(doc, first, last)
   !< Delete lines `first` to `last` (from 0, inclusive).
   type(code_document), intent(inout) :: doc         !< Document.
   integer(int32),      intent(in)    :: first, last !< Lines.
   integer(int32)                     :: k, d        !< Counter, count.

   d = last - first + 1_int32
   if (d <= 0_int32) return
   do k = last + 2_int32, doc%n
      call line_move(doc%lines(k), doc%lines(k - d))
   enddo
   doc%n = doc%n - d
   endsubroutine doc_delete_lines

   pure subroutine doc_reset(doc)
   !< An empty document of one empty line (the fork's `Document()`).
   type(code_document), intent(inout) :: doc !< Document.

   doc%n = 0_int32
   call doc_insert_line(doc, 0_int32)
   endsubroutine doc_reset

   pure function doc_line_size(doc, l) result(n)
   !< The glyphs of line `l` (from 0).
   type(code_document), intent(in) :: doc !< Document.
   integer(int32),      intent(in) :: l   !< Line.
   integer(int32)                  :: n   !< Glyphs.

   n = doc%lines(l + 1)%n
   endfunction doc_line_size

   pure function doc_cp(doc, p) result(cp)
   !< The code point at `p` (`getCodePoint`: U+FFFD past the line's end).
   type(code_document), intent(in) :: doc !< Document.
   type(code_pos),      intent(in) :: p   !< Position.
   integer(int32)                  :: cp  !< Code point.

   if (p%i < doc%lines(p%l + 1)%n) then
      cp = doc%lines(p%l + 1)%cp(p%i + 1)
   else
      cp = 65533_int32
   endif
   endfunction doc_cp

   pure subroutine doc_update_indents(doc, tab_size, first, last)
   !< The indent (columns of leading blanks and tabs) of lines `first` to `last` (`updateIndents`).
   type(code_document), intent(inout) :: doc         !< Document.
   integer(int32),      intent(in)    :: tab_size    !< Tab size.
   integer(int32),      intent(in)    :: first, last !< Lines, from 0.
   integer(int32)                     :: l, j        !< Counters.

   do l = first + 1_int32, last + 1_int32
      associate(line => doc%lines(l))
         line%indent = 0_int32
         do j = 1_int32, line%n
            if (line%cp(j) == 32_int32) then
               line%indent = line%indent + 1_int32
            elseif (line%cp(j) == 9_int32) then
               line%indent = line%indent + tab_size - mod(line%indent, tab_size)
            else
               exit
            endif
         enddo
      endassociate
   enddo
   endsubroutine doc_update_indents

   pure function spaces_to_tab(line, index, tab_size) result(n)
   !< Blanks from glyph `index` to the next tab stop (`getSpacesToTab`).
   type(code_line), intent(in) :: line     !< Line.
   integer(int32),  intent(in) :: index    !< Glyph, from 0.
   integer(int32),  intent(in) :: tab_size !< Tab size.
   integer(int32)              :: n        !< Blanks.
   integer(int32)              :: k, c     !< Counter, columns.

   c = 0_int32
   do k = 1_int32, index
      c = c + cp_glyph_width(line%cp(k))
   enddo
   n = ((c / tab_size) + 1_int32) * tab_size - c
   endfunction spaces_to_tab

   pure subroutine doc_set_text(doc, text, tab_size, spaces_on_tabs)
   !< The document of `text` (`setUtf8Text`): LF ends a line, CR is dropped, a tab becomes blanks with
   !< `spaces_on_tabs`.
   type(code_document), intent(inout) :: doc            !< Document.
   character(len=*),    intent(in)    :: text           !< UTF-8 text.
   integer(int32),      intent(in)    :: tab_size       !< Tab size.
   logical,             intent(in)    :: spaces_on_tabs !< Tabs as blanks.
   integer(int32)                     :: i, cp, s, k    !< Byte, code point, blanks, counter.

   doc%n = 0_int32
   call doc_insert_line(doc, 0_int32)
   i = 1_int32
   do while (i <= len(text, int32))
      call cp_read(text, i, cp)
      if (cp == 10_int32) then
         call doc_insert_line(doc, doc%n)
      elseif (spaces_on_tabs .and. cp == 9_int32) then
         s = spaces_to_tab(doc%lines(doc%n), doc%lines(doc%n)%n, tab_size)
         do k = 1_int32, s
            call line_insert_glyph(doc%lines(doc%n), doc%lines(doc%n)%n, 32_int32)
         enddo
      elseif (cp /= 13_int32) then
         call line_insert_glyph(doc%lines(doc%n), doc%lines(doc%n)%n, cp)
      endif
   enddo
   call doc_update_indents(doc, tab_size, 0_int32, doc%n - 1_int32)
   doc%updated = .true.
   endsubroutine doc_set_text

   pure function doc_text(doc) result(t)
   !< The text (`getUtf8Text`): every line ended by LF but an empty last one.
   type(code_document), intent(in) :: doc !< Document.
   character(len=:), allocatable   :: t   !< UTF-8 text.
   integer(int64)                  :: n   !< Bytes.
   integer(int32)                  :: l, k, m !< Counters, bytes of a glyph.
   character(len=4)                :: b   !< A glyph's bytes.

   n = 0_int64
   do l = 1_int32, doc%n
      do k = 1_int32, doc%lines(l)%n
         call cp_write(doc%lines(l)%cp(k), b, m)
         n = n + m
      enddo
      if (l /= doc%n .or. doc%lines(l)%n > 0_int32) n = n + 1_int64
   enddo
   allocate(character(len=n) :: t)
   n = 0_int64
   do l = 1_int32, doc%n
      do k = 1_int32, doc%lines(l)%n
         call cp_write(doc%lines(l)%cp(k), b, m)
         t(n + 1_int64:n + m) = b(1:m)
         n = n + m
      enddo
      if (l /= doc%n .or. doc%lines(l)%n > 0_int32) then
         t(n + 1_int64:n + 1_int64) = achar(10)
         n = n + 1_int64
      endif
   enddo
   endfunction doc_text

   pure function doc_section_length(doc, a, b) result(n)
   !< The bytes of the text from `a` to `b` (`getSectionText`'s length).
   type(code_document), intent(in) :: doc  !< Document.
   type(code_pos),      intent(in) :: a, b !< Section.
   integer(int64)                  :: n    !< Bytes.
   integer(int32)                  :: l, i, m !< Position, bytes of a glyph.
   character(len=4)                :: buf  !< A glyph's bytes.

   n = 0_int64
   l = a%l
   i = a%i
   do while (l < b%l .or. i < b%i)
      if (i < doc%lines(l + 1)%n) then
         call cp_write(doc%lines(l + 1)%cp(i + 1), buf, m)
         n = n + m
         i = i + 1_int32
      else
         n = n + 1_int64
         l = l + 1_int32
         i = 0_int32
      endif
   enddo
   endfunction doc_section_length

   pure function doc_section_text(doc, a, b) result(t)
   !< The text from `a` to `b` (`getSectionText`: LF between lines).
   type(code_document), intent(in) :: doc  !< Document.
   type(code_pos),      intent(in) :: a, b !< Section.
   character(len=:), allocatable   :: t    !< UTF-8 text.
   integer(int64)                  :: n    !< Bytes written.
   integer(int32)                  :: l, i, m !< Position, bytes of a glyph.
   character(len=4)                :: buf  !< A glyph's bytes.

   allocate(character(len=doc_section_length(doc, a, b)) :: t)
   n = 0_int64
   l = a%l
   i = a%i
   do while (l < b%l .or. i < b%i)
      if (i < doc%lines(l + 1)%n) then
         call cp_write(doc%lines(l + 1)%cp(i + 1), buf, m)
         t(n + 1_int64:n + m) = buf(1:m)
         n = n + m
         i = i + 1_int32
      else
         t(n + 1_int64:n + 1_int64) = achar(10)
         n = n + 1_int64
         l = l + 1_int32
         i = 0_int32
      endif
   enddo
   endfunction doc_section_text

   pure subroutine doc_insert_text(doc, start, text, tab_size, spaces_on_tabs, end)
   !< Insert `text` at `start` (`Document::insertText`); `end` is the position after it.
   type(code_document), intent(inout) :: doc            !< Document.
   type(code_pos),      intent(in)    :: start          !< Where.
   character(len=*),    intent(in)    :: text           !< UTF-8 text.
   integer(int32),      intent(in)    :: tab_size       !< Tab size.
   logical,             intent(in)    :: spaces_on_tabs !< Tabs as blanks.
   type(code_pos),      intent(out)   :: end            !< End of the insert.
   integer(int32)                     :: i, cp, l, idx, s, k !< Byte, code point, line, index, blanks, counter.

   l = start%l
   idx = start%i
   i = 1_int32
   do while (i <= len(text, int32))
      call cp_read(text, i, cp)
      if (cp == 10_int32) then
         call doc_insert_line(doc, l + 1_int32)
         call line_append(doc%lines(l + 2), doc%lines(l + 1), idx)
         doc%lines(l + 1)%n = idx
         l = l + 1_int32
         idx = 0_int32
      elseif (spaces_on_tabs .and. cp == 9_int32) then
         s = spaces_to_tab(doc%lines(l + 1), idx, tab_size)
         do k = 1_int32, s
            call line_insert_glyph(doc%lines(l + 1), idx, 32_int32)
            idx = idx + 1_int32
         enddo
      elseif (cp /= 13_int32) then
         call line_insert_glyph(doc%lines(l + 1), idx, cp)
         idx = idx + 1_int32
      endif
   enddo
   end = pos(l, idx)
   do k = start%l + 1_int32, end%l + 1_int32
      doc%lines(k)%needs_colorizing = .true.
      doc%lines(k)%needs_typesetting = .true.
   enddo
   call doc_update_indents(doc, tab_size, start%l, end%l)
   doc%updated = .true.
   endsubroutine doc_insert_text

   pure subroutine doc_delete_text(doc, a, b, tab_size)
   !< Delete the text from `a` to `b` (`Document::deleteText`): the start line's marker goes.
   type(code_document), intent(inout) :: doc      !< Document.
   type(code_pos),      intent(in)    :: a, b     !< Section.
   integer(int32),      intent(in)    :: tab_size !< Tab size.

   if (a%l == b%l) then
      call line_erase(doc%lines(a%l + 1), a%i, b%i)
   else
      doc%lines(a%l + 1)%n = a%i
      call line_append(doc%lines(a%l + 1), doc%lines(b%l + 1), b%i)
      call doc_delete_lines(doc, a%l + 1_int32, b%l)
   endif
   doc%lines(a%l + 1)%marker = 0_int32
   doc%lines(a%l + 1)%needs_colorizing = .true.
   doc%lines(a%l + 1)%needs_typesetting = .true.
   call doc_update_indents(doc, tab_size, a%l, a%l)
   doc%updated = .true.
   endsubroutine doc_delete_text

   ! ---- coordinates -------------------------------------------------------------------------------------------------
   pure function doc_bottom(doc) result(p)
   !< The end of the last line (`getBottom`).
   type(code_document), intent(in) :: doc !< Document.
   type(code_pos)                  :: p   !< Position.

   p = pos(doc%n - 1_int32, doc%lines(doc%n)%n)
   endfunction doc_bottom

   pure function doc_end_of_line(doc, p) result(q)
   !< The end of `p`'s line.
   type(code_document), intent(in) :: doc !< Document.
   type(code_pos),      intent(in) :: p   !< Position.
   type(code_pos)                  :: q   !< End of its line.

   q = pos(p%l, doc%lines(p%l + 1)%n)
   endfunction doc_end_of_line

   pure function doc_next_line(doc, p) result(q)
   !< The start of the line after `p`'s (`getNextLine`: the end of the last line on the last line).
   type(code_document), intent(in) :: doc !< Document.
   type(code_pos),      intent(in) :: p   !< Position.
   type(code_pos)                  :: q   !< Position.

   q = doc_right(doc, doc_end_of_line(doc, p), .false.)
   endfunction doc_next_line

   pure function doc_normalize(doc, p) result(q)
   !< `p` clamped to the text (`normalizePos`).
   type(code_document), intent(in) :: doc !< Document.
   type(code_pos),      intent(in) :: p   !< Position.
   type(code_pos)                  :: q   !< Clamped.

   if (p%l >= doc%n .or. p%l < 0_int32) then
      q = doc_bottom(doc)
   elseif (p%i > doc%lines(p%l + 1)%n .or. p%i < 0_int32) then
      q = doc_end_of_line(doc, p)
   else
      q = p
   endif
   endfunction doc_normalize

   pure recursive function doc_left(doc, p, word_mode) result(q)
   !< The position left of `p` (`getLeft`; by words with `word_mode`).
   type(code_document), intent(in) :: doc       !< Document.
   type(code_pos),      intent(in) :: p         !< Position.
   logical,             intent(in) :: word_mode !< By words.
   type(code_pos)                  :: q         !< Position.

   if (word_mode) then
      q = p
      if (q%i == 0_int32) q = doc_left(doc, q, .false.)
      q = doc_find_previous_non_white_space(doc, q, .false.)
      q = doc_find_word_start(doc, q, .false.)
   elseif (p%i == 0_int32) then
      if (p%l == 0_int32) then
         q = p
      else
         q = pos(p%l - 1_int32, doc%lines(p%l)%n)
      endif
   else
      q = pos(p%l, p%i - 1_int32)
   endif
   endfunction doc_left

   pure recursive function doc_right(doc, p, word_mode) result(q)
   !< The position right of `p` (`getRight`; by words with `word_mode`).
   type(code_document), intent(in) :: doc       !< Document.
   type(code_pos),      intent(in) :: p         !< Position.
   logical,             intent(in) :: word_mode !< By words.
   type(code_pos)                  :: q         !< Position.

   if (word_mode) then
      q = p
      if (q%i == doc%lines(q%l + 1)%n) q = doc_right(doc, q, .false.)
      q = doc_find_next_non_white_space(doc, q, .false.)
      q = doc_find_word_end(doc, q, .false.)
   elseif (p%i == doc%lines(p%l + 1)%n) then
      if (p%l == doc%n - 1_int32) then
         q = p
      else
         q = pos(p%l + 1_int32, 0_int32)
      endif
   else
      q = pos(p%l, p%i + 1_int32)
   endif
   endfunction doc_right

   pure function doc_find_word_start(doc, p, word_only) result(q)
   !< The start of the word (or blanks, or other characters) before `p` (`findWordStart`).
   type(code_document), intent(in) :: doc       !< Document.
   type(code_pos),      intent(in) :: p         !< Position.
   logical,             intent(in) :: word_only !< Words only.
   type(code_pos)                  :: q         !< Position.
   integer(int32)                  :: idx, first !< Index, the character before `p`.

   associate(line => doc%lines(p%l + 1))
      if (p%i == 0_int32 .or. line%n == 0_int32) then
         q = p
         return
      endif
      idx = p%i
      first = line%cp(idx)
      if (.not. word_only .and. cp_is_white_space(first)) then
         do while (idx > 0_int32)
            if (.not. cp_is_white_space(line%cp(idx))) exit
            idx = idx - 1_int32
         enddo
      elseif (cp_is_word(first)) then
         do while (idx > 0_int32)
            if (.not. cp_is_word(line%cp(idx))) exit
            idx = idx - 1_int32
         enddo
      else
         do while (.not. word_only .and. idx > 0_int32)
            if (cp_is_word(line%cp(idx)) .or. cp_is_white_space(line%cp(idx))) exit
            idx = idx - 1_int32
         enddo
      endif
      q = pos(p%l, idx)
   endassociate
   endfunction doc_find_word_start

   pure function doc_find_word_end(doc, p, word_only) result(q)
   !< The end of the word (or blanks, or other characters) from `p` (`findWordEnd`).
   type(code_document), intent(in) :: doc       !< Document.
   type(code_pos),      intent(in) :: p         !< Position.
   logical,             intent(in) :: word_only !< Words only.
   type(code_pos)                  :: q         !< Position.
   integer(int32)                  :: idx, first !< Index, the character at `p`.

   associate(line => doc%lines(p%l + 1))
      idx = p%i
      if (idx >= line%n) then
         q = p
         return
      endif
      first = line%cp(idx + 1)
      if (.not. word_only .and. cp_is_white_space(first)) then
         do while (idx < line%n)
            if (.not. cp_is_white_space(line%cp(idx + 1))) exit
            idx = idx + 1_int32
         enddo
      elseif (cp_is_word(first)) then
         do while (idx < line%n)
            if (.not. cp_is_word(line%cp(idx + 1))) exit
            idx = idx + 1_int32
         enddo
      else
         do while (.not. word_only .and. idx < line%n)
            if (cp_is_word(line%cp(idx + 1)) .or. cp_is_white_space(line%cp(idx + 1))) exit
            idx = idx + 1_int32
         enddo
      endif
      q = pos(p%l, idx)
   endassociate
   endfunction doc_find_word_end

   pure function is_word_start(doc, p, word_only) result(yes)
   !< `isWordStart`.
   type(code_document), intent(in) :: doc       !< Document.
   type(code_pos),      intent(in) :: p         !< Position.
   logical,             intent(in) :: word_only !< Words only.
   logical                         :: yes       !< A word starts at `p`.
   integer(int32)                  :: g1, g2    !< Glyphs before and at `p`.

   associate(line => doc%lines(p%l + 1))
      if (p%i == line%n) then
         yes = .false.
      elseif (p%i == 0_int32) then
         if (line%n == 0_int32) then
            yes = .false.
         else
            yes = .not. word_only .or. cp_is_word(line%cp(1))
         endif
      else
         g1 = line%cp(p%i)
         g2 = line%cp(p%i + 1)
         if (word_only) then
            yes = .not. cp_is_word(g1) .and. cp_is_word(g2)
         elseif (cp_is_word(g2)) then
            yes = .not. cp_is_word(g1)
         elseif (cp_is_white_space(g2)) then
            yes = .not. cp_is_white_space(g1)
         else
            yes = cp_is_word(g1) .or. cp_is_white_space(g1)
         endif
      endif
   endassociate
   endfunction is_word_start

   pure function is_word_end(doc, p, word_only) result(yes)
   !< `isWordEnd`.
   type(code_document), intent(in) :: doc       !< Document.
   type(code_pos),      intent(in) :: p         !< Position.
   logical,             intent(in) :: word_only !< Words only.
   logical                         :: yes       !< A word ends at `p`.
   integer(int32)                  :: g1, g2    !< Glyphs before and at `p`.

   associate(line => doc%lines(p%l + 1))
      if (p%i == 0_int32) then
         yes = .false.
      elseif (p%i == line%n) then
         if (line%n == 0_int32) then
            yes = .false.
         else
            yes = .not. word_only .or. cp_is_word(line%cp(line%n))
         endif
      else
         g1 = line%cp(p%i)
         g2 = line%cp(p%i + 1)
         if (word_only) then
            yes = cp_is_word(g1) .and. .not. cp_is_word(g2)
         elseif (cp_is_word(g1)) then
            yes = .not. cp_is_word(g2)
         elseif (cp_is_white_space(g1)) then
            yes = .not. cp_is_white_space(g2)
         else
            yes = cp_is_word(g2) .or. cp_is_white_space(g2)
         endif
      endif
   endassociate
   endfunction is_word_end

   pure function doc_is_whole_word(doc, a, b, word_only) result(yes)
   !< `isWholeWord`: [a, b) on one line, a word start to a word end.
   type(code_document), intent(in) :: doc       !< Document.
   type(code_pos),      intent(in) :: a, b      !< Section.
   logical,             intent(in) :: word_only !< Words only.
   logical                         :: yes       !< A whole word.

   if (pos_le(b, a) .or. a%l /= b%l) then
      yes = .false.
   else
      yes = is_word_start(doc, a, word_only)
      if (yes) yes = is_word_end(doc, b, word_only)
   endif
   endfunction doc_is_whole_word

   pure subroutine doc_whole_word(doc, p, word_only, a, b)
   !< The whole word at `p` (`getWholeWord`): [a, b).
   type(code_document), intent(in)  :: doc       !< Document.
   type(code_pos),      intent(in)  :: p         !< Position.
   logical,             intent(in)  :: word_only !< Words only.
   type(code_pos),      intent(out) :: a, b      !< The word.

   if (word_only .and. p%i /= 0_int32 .and. p%i /= doc%lines(p%l + 1)%n) then
      if (.not. cp_is_word(doc%lines(p%l + 1)%cp(p%i + 1))) then
         a = p
         b = p
         return
      endif
   endif
   if (is_word_start(doc, p, word_only)) then
      a = p
      b = doc_find_word_end(doc, p, word_only)
   elseif (is_word_end(doc, p, word_only)) then
      a = doc_find_word_start(doc, p, word_only)
      b = p
   else
      a = doc_find_word_start(doc, p, word_only)
      b = doc_find_word_end(doc, p, word_only)
   endif
   endsubroutine doc_whole_word

   pure function doc_find_previous_non_white_space(doc, p, include_end_of_line) result(q)
   !< `findPreviousNonWhiteSpace`.
   type(code_document), intent(in) :: doc                 !< Document.
   type(code_pos),      intent(in) :: p                   !< Position.
   logical,             intent(in) :: include_end_of_line !< Across lines.
   type(code_pos)                  :: q                   !< Position.
   logical                         :: done                !< Found.
   integer(int32)                  :: idx                 !< Index.

   q = p
   done = .false.
   do while (.not. done)
      idx = q%i
      do while (.not. done .and. idx > 0_int32)
         if (cp_is_white_space(doc%lines(q%l + 1)%cp(idx))) then
            idx = idx - 1_int32
         else
            q%i = idx
            done = .true.
         endif
      enddo
      if (.not. done) then
         if (q%l == 0_int32 .or. .not. include_end_of_line) then
            q%i = 0_int32
            done = .true.
         else
            q = pos(q%l - 1_int32, doc%lines(q%l)%n)
         endif
      endif
   enddo
   endfunction doc_find_previous_non_white_space

   pure function doc_find_next_non_white_space(doc, p, include_end_of_line) result(q)
   !< `findNextNonWhiteSpace` (the fork's test of the last line compares with the line count: it never stops there,
   !< and the end of the last line goes to the next line's start, which is itself).
   type(code_document), intent(in) :: doc                 !< Document.
   type(code_pos),      intent(in) :: p                   !< Position.
   logical,             intent(in) :: include_end_of_line !< Across lines.
   type(code_pos)                  :: q                   !< Position.
   logical                         :: done                !< Found.
   integer(int32)                  :: idx, n              !< Index, line size.

   q = p
   done = .false.
   do while (.not. done)
      n = doc%lines(q%l + 1)%n
      idx = q%i
      do while (.not. done .and. idx < n)
         if (cp_is_white_space(doc%lines(q%l + 1)%cp(idx + 1))) then
            idx = idx + 1_int32
         else
            q%i = idx
            done = .true.
         endif
      enddo
      if (.not. done) then
         if (q%l == doc%n .or. .not. include_end_of_line) then
            q%i = n
            done = .true.
         elseif (q%l == doc%n - 1_int32) then
            q%i = n ! getRightAfterHiddenLines on the last line returns its argument: the fork loops for ever
            done = .true.
         else
            q = pos(q%l + 1_int32, 0_int32)
         endif
      endif
   enddo
   endfunction doc_find_next_non_white_space

   pure subroutine doc_find_text(doc, from, text, case_sensitive, whole_word, found, a, b)
   !< The next occurrence of `text` from `from`, wrapping past the end (`Document::findText`): [a, b).
   type(code_document), intent(in)  :: doc            !< Document.
   type(code_pos),      intent(in)  :: from           !< Where to start.
   character(len=*),    intent(in)  :: text           !< UTF-8 text (LF crosses lines).
   logical,             intent(in)  :: case_sensitive !< By case.
   logical,             intent(in)  :: whole_word     !< Whole words.
   logical,             intent(out) :: found          !< Found.
   type(code_pos),      intent(out) :: a, b           !< The occurrence.
   integer(int32), allocatable      :: search(:)      !< The text's code points.
   integer(int32)                   :: ns, i, cp      !< Code points, byte, code point.
   integer(int32)                   :: sl, si, l, idx, n, j, ch !< Search start, position, line size, counter, glyph.
   logical                          :: done           !< Mismatch.

   found = .false.
   a = from
   b = from
   allocate(search(len(text)))
   ns = 0_int32
   i = 1_int32
   do while (i <= len(text, int32))
      call cp_read(text, i, cp)
      ns = ns + 1_int32
      if (case_sensitive) then
         search(ns) = cp
      else
         search(ns) = cp_to_lower(cp)
      endif
   enddo
   sl = from%l
   si = from%i
   do
      l = sl
      idx = si
      n = doc%lines(l + 1)%n
      done = .false.
      j = 0_int32
      do while (.not. done .and. j < ns)
         if (search(j + 1) == 10_int32) then
            if (idx == n) then
               if (l == doc%n - 1_int32) then
                  done = .true.
               else
                  l = l + 1_int32
                  idx = 0_int32
                  n = doc%lines(l + 1)%n
                  j = j + 1_int32
               endif
            else
               done = .true.
            endif
         elseif (idx == n) then
            done = .true.
         else
            ch = doc%lines(l + 1)%cp(idx + 1)
            if (.not. case_sensitive) ch = cp_to_lower(ch)
            if (ch == search(j + 1)) then
               idx = idx + 1_int32
               j = j + 1_int32
            else
               done = .true.
            endif
         endif
      enddo
      if (j == ns) then
         a = pos(sl, si)
         b = pos(l, idx)
         if (.not. whole_word) then
            found = .true.
            return
         elseif (doc_is_whole_word(doc, a, b, .false.)) then
            found = .true.
            return
         endif
      endif
      if (si == doc%lines(sl + 1)%n) then
         if (sl == doc%n - 1_int32) then
            sl = 0_int32
         else
            sl = sl + 1_int32
         endif
         si = 0_int32
      else
         si = si + 1_int32
      endif
      if (sl == from%l .and. si == from%i) exit
   enddo
   endsubroutine doc_find_text

   ! ---- cursors -----------------------------------------------------------------------------------------------------
   pure function cursor_selection_start(c) result(p)
   !< The selection's start (`getSelectionStart`).
   type(code_cursor), intent(in) :: c !< Cursor.
   type(code_pos)                :: p !< Position.

   p = pos_min(c%start, c%end)
   endfunction cursor_selection_start

   pure function cursor_selection_end(c) result(p)
   !< The selection's end (`getSelectionEnd`).
   type(code_cursor), intent(in) :: c !< Cursor.
   type(code_pos)                :: p !< Position.

   p = pos_max(c%start, c%end)
   endfunction cursor_selection_end

   pure function cursor_has_selection(c) result(yes)
   !< Start and end differ.
   type(code_cursor), intent(in) :: c   !< Cursor.
   logical                       :: yes !< A selection.

   yes = .not. pos_eq(c%start, c%end)
   endfunction cursor_has_selection

   pure subroutine cursor_update(c, a, b)
   !< `update(start, end)`.
   type(code_cursor), intent(inout) :: c    !< Cursor.
   type(code_pos),    intent(in)    :: a, b !< Start, end.

   c%start = a
   c%end = b
   c%updated = .true.
   endsubroutine cursor_update

   pure subroutine cursor_update_keep(c, p, keep)
   !< `update(position, keep)`: the end moved (the start kept with `keep`, else moved too).
   type(code_cursor), intent(inout) :: c    !< Cursor.
   type(code_pos),    intent(in)    :: p    !< Position.
   logical,           intent(in)    :: keep !< Keep the start.

   if (.not. keep) c%start = p
   c%end = p
   c%updated = .true.
   endsubroutine cursor_update_keep

   pure subroutine cursor_reset_to_start(c)
   !< `resetToStart`.
   type(code_cursor), intent(inout) :: c !< Cursor.
   type(code_pos)                   :: p !< Selection start.

   p = cursor_selection_start(c)
   call cursor_update(c, p, p)
   endsubroutine cursor_reset_to_start

   pure subroutine cursor_reset_to_end(c)
   !< `resetToEnd`.
   type(code_cursor), intent(inout) :: c !< Cursor.
   type(code_pos)                   :: p !< Selection end.

   p = cursor_selection_end(c)
   call cursor_update(c, p, p)
   endsubroutine cursor_reset_to_end

   pure subroutine cursor_grow(c, p)
   !< `grow`: the selection extended to `p`.
   type(code_cursor), intent(inout) :: c !< Cursor.
   type(code_pos),    intent(in)    :: p !< Position.
   type(code_pos)                   :: t !< Swap.

   if (pos_lt(p, cursor_selection_start(c))) then
      if (pos_lt(c%start, c%end)) then
         t = c%end
         c%end = c%start
         c%start = t
      endif
      c%end = p
      c%updated = .true.
   elseif (pos_lt(cursor_selection_end(c), p)) then
      if (pos_lt(c%end, c%start)) then
         t = c%end
         c%end = c%start
         c%start = t
      endif
      c%end = p
      c%updated = .true.
   endif
   endsubroutine cursor_grow

   pure subroutine cursors_reserve(cs, cap)
   !< Room for `cap` cursors.
   type(code_cursors), intent(inout) :: cs   !< Cursors.
   integer(int32),     intent(in)    :: cap  !< Cursors.
   type(code_cursor), allocatable    :: more(:) !< New storage.

   if (allocated(cs%c)) then
      if (size(cs%c, kind=int32) >= cap) return
      allocate(more(max(cap, 2_int32 * size(cs%c, kind=int32))))
      more(1:cs%n) = cs%c(1:cs%n)
   else
      allocate(more(max(cap, 4_int32)))
   endif
   call move_alloc(more, cs%c)
   endsubroutine cursors_reserve

   pure subroutine cursors_copy(from, to)
   !< `to = from` (storage of `to` kept when large enough).
   type(code_cursors), intent(in)    :: from !< Source.
   type(code_cursors), intent(inout) :: to   !< Destination.

   call cursors_reserve(to, max(from%n, 1_int32))
   if (from%n > 0_int32) to%c(1:from%n) = from%c(1:from%n)
   to%n = from%n
   to%main = from%main
   to%current = from%current
   endsubroutine cursors_copy

   pure subroutine cursors_set(cs, a, b)
   !< `setCursor(start, end)`: one cursor, main and current.
   type(code_cursors), intent(inout) :: cs   !< Cursors.
   type(code_pos),     intent(in)    :: a, b !< Start, end.

   call cursors_reserve(cs, 1_int32)
   cs%n = 1_int32
   cs%main = 0_int32
   cs%current = 0_int32
   cs%c(1) = code_cursor(start=a, end=b, main=.true., current=.true., updated=.true., preferred=0_int32)
   endsubroutine cursors_set

   pure subroutine cursors_clear_all(cs)
   !< `clearAll`: one cursor at the top.
   type(code_cursors), intent(inout) :: cs !< Cursors.

   call cursors_set(cs, pos(0_int32, 0_int32), pos(0_int32, 0_int32))
   endsubroutine cursors_clear_all

   pure subroutine cursors_add(cs, a, b)
   !< `addCursor(start, end)`: the new cursor is the current one.
   type(code_cursors), intent(inout) :: cs   !< Cursors.
   type(code_pos),     intent(in)    :: a, b !< Start, end.

   cs%c(cs%current + 1)%current = .false.
   call cursors_reserve(cs, cs%n + 1_int32)
   cs%n = cs%n + 1_int32
   cs%c(cs%n) = code_cursor(start=a, end=b, main=.false., current=.true., updated=.true., preferred=0_int32)
   cs%current = cs%n - 1_int32
   endsubroutine cursors_add

   pure subroutine cursors_clear_additional(cs, reset)
   !< `clearAdditional`: the main cursor kept alone (moved to its selection's end with `reset`).
   type(code_cursors), intent(inout) :: cs    !< Cursors.
   logical,            intent(in)    :: reset !< Reset to the end.
   integer(int32)                    :: k, m  !< Counters.

   m = 0_int32
   do k = 1_int32, cs%n
      if (cs%c(k)%main) then
         m = m + 1_int32
         cs%c(m) = cs%c(k)
      endif
   enddo
   cs%n = m
   cs%main = 0_int32
   cs%current = 0_int32
   cs%c(1)%current = .true.
   if (reset) call cursor_reset_to_end(cs%c(1))
   endsubroutine cursors_clear_additional

   pure function cursors_any_selection(cs) result(yes)
   !< `anyHasSelection`.
   type(code_cursors), intent(in) :: cs  !< Cursors.
   logical                        :: yes !< Some cursor has a selection.
   integer(int32)                 :: k   !< Counter.

   yes = .false.
   do k = 1_int32, cs%n
      if (cursor_has_selection(cs%c(k))) then
         yes = .true.
         return
      endif
   enddo
   endfunction cursors_any_selection

   pure function cursors_all_selection(cs) result(yes)
   !< `allHaveSelection`.
   type(code_cursors), intent(in) :: cs  !< Cursors.
   logical                        :: yes !< Every cursor has a selection.
   integer(int32)                 :: k   !< Counter.

   yes = .true.
   do k = 1_int32, cs%n
      if (.not. cursor_has_selection(cs%c(k))) then
         yes = .false.
         return
      endif
   enddo
   endfunction cursors_all_selection

   pure subroutine cursors_update(cs)
   !< `Cursors::update`: when one changed, sorted by their selections' starts and the overlapping ones merged; main
   !< and current found again (as the fork: a main cursor that is also current leaves current at 0).
   type(code_cursors), intent(inout) :: cs   !< Cursors.
   type(code_cursor)                 :: t    !< Swap.
   integer(int32)                    :: k, j, cur, prv !< Counters.
   logical                           :: any  !< Some cursor was updated.

   any = .false.
   do k = 1_int32, cs%n
      if (cs%c(k)%updated) any = .true.
   enddo
   if (.not. any) return
   do k = 1_int32, cs%n
      cs%c(k)%updated = .false.
   enddo
   if (cs%n <= 1_int32) return
   ! sort by selection start (insertion sort, stable)
   do k = 2_int32, cs%n
      t = cs%c(k)
      j = k - 1_int32
      do while (j >= 1_int32)
         if (.not. pos_lt(cursor_selection_start(t), cursor_selection_start(cs%c(j)))) exit
         cs%c(j + 1) = cs%c(j)
         j = j - 1_int32
      enddo
      cs%c(j + 1) = t
   enddo
   ! merge, from the last cursor backwards
   cur = cs%n
   do while (cur > 1_int32)
      prv = cur - 1_int32
      if (pos_le(cursor_selection_end(cs%c(cur)), cursor_selection_end(cs%c(prv)))) then
         if (cs%c(cur)%main) cs%c(prv)%main = .true.
         if (cs%c(cur)%current) cs%c(prv)%current = .true.
         call cursors_erase_after(cs, prv)
         cur = cur - 1_int32
      elseif (pos_lt(cursor_selection_start(cs%c(cur)), cursor_selection_end(cs%c(prv)))) then
         if (pos_lt(cs%c(cur)%end, cs%c(cur)%start)) then
            call cursor_update(cs%c(prv), cursor_selection_end(cs%c(cur)), cursor_selection_start(cs%c(prv)))
         else
            call cursor_update(cs%c(prv), cursor_selection_start(cs%c(prv)), cursor_selection_end(cs%c(cur)))
         endif
         if (cs%c(cur)%main) cs%c(prv)%main = .true.
         if (cs%c(cur)%current) cs%c(prv)%current = .true.
         call cursors_erase_after(cs, prv)
         cur = cur - 1_int32
      else
         cur = cur - 1_int32
      endif
   enddo
   cs%main = 0_int32
   cs%current = 0_int32
   do k = 1_int32, cs%n
      if (cs%c(k)%main) then
         cs%main = k - 1_int32
      elseif (cs%c(k)%current) then
         cs%current = k - 1_int32
      endif
   enddo
   endsubroutine cursors_update

   pure subroutine cursors_erase_after(cs, p)
   !< The fork's `erase(previous.base())` in `Cursors::update`: the cursor after `p` (the later one) goes.
   type(code_cursors), intent(inout) :: cs !< Cursors.
   integer(int32),     intent(in)    :: p  !< The kept cursor, from 1.
   integer(int32)                    :: q  !< Counter.

   do q = p + 1_int32, cs%n - 1_int32
      cs%c(q) = cs%c(q + 1)
   enddo
   cs%n = cs%n - 1_int32
   endsubroutine cursors_erase_after

   pure function adjust_for_insert(p, a, b) result(q)
   !< `adjustCoordinateForInsert`.
   type(code_pos), intent(in) :: p    !< Position.
   type(code_pos), intent(in) :: a, b !< Insert start, end.
   type(code_pos)             :: q    !< Adjusted.

   q = p
   if (q%l == a%l) q%i = q%i + b%i - a%i
   q%l = q%l + b%l - a%l
   endfunction adjust_for_insert

   pure function adjust_for_delete(p, a, b) result(q)
   !< `adjustCoordinateForDelete`.
   type(code_pos), intent(in) :: p    !< Position.
   type(code_pos), intent(in) :: a, b !< Delete start, end.
   type(code_pos)             :: q    !< Adjusted.

   q = p
   if (a%l == b%l) then
      if (q%l == b%l) q%i = q%i - (b%i - a%i)
   else
      q%l = q%l - (b%l - a%l)
      if (q%l == b%l) q%i = q%i - b%i
   endif
   endfunction adjust_for_delete

   pure subroutine cursors_adjust_insert(cs, from, a, b, include_current)
   !< `Cursors::adjustForInsert`: the cursors after `from` (from 0; `from` too with `include_current`).
   type(code_cursors), intent(inout) :: cs              !< Cursors.
   integer(int32),     intent(in)    :: from            !< Cursor, from 0.
   type(code_pos),     intent(in)    :: a, b            !< Insert start, end.
   logical,            intent(in)    :: include_current !< From `from` itself.
   integer(int32)                    :: k               !< Counter.

   do k = merge(from + 1_int32, from + 2_int32, include_current), cs%n
      cs%c(k)%start = adjust_for_insert(cs%c(k)%start, a, b)
      cs%c(k)%end = adjust_for_insert(cs%c(k)%end, a, b)
   enddo
   endsubroutine cursors_adjust_insert

   pure subroutine cursors_adjust_delete(cs, from, a, b, include_current)
   !< `Cursors::adjustForDelete`: the cursors after `from` (from 0; `from` too with `include_current`).
   type(code_cursors), intent(inout) :: cs              !< Cursors.
   integer(int32),     intent(in)    :: from            !< Cursor, from 0.
   type(code_pos),     intent(in)    :: a, b            !< Delete start, end.
   logical,            intent(in)    :: include_current !< From `from` itself.
   integer(int32)                    :: k               !< Counter.

   do k = merge(from + 1_int32, from + 2_int32, include_current), cs%n
      cs%c(k)%start = adjust_for_delete(cs%c(k)%start, a, b)
      cs%c(k)%end = adjust_for_delete(cs%c(k)%end, a, b)
   enddo
   endsubroutine cursors_adjust_delete

   ! ---- the undo list -------------------------------------------------------------------------------------------------
   pure subroutine undo_reset(u)
   !< `Transactions::reset`: no transaction.
   type(code_undo), intent(inout) :: u !< Undo list.

   u%na = 0_int32
   u%nt = 0_int64
   u%ncp = 0_int32
   u%nt_ = 0_int32
   u%undo_index = 0_int32
   u%open = .false.
   endsubroutine undo_reset

   pure subroutine undo_begin(u, cs)
   !< `startTransaction`: a transaction begins, the cursors before it saved.
   type(code_undo),    intent(inout) :: u  !< Undo list.
   type(code_cursors), intent(in)    :: cs !< Cursors now.

   call cursors_copy(cs, u%before)
   u%b_first = u%na + 1_int32
   u%open = .true.
   endsubroutine undo_begin

   pure subroutine reserve_actions(u, n, bytes)
   !< Room for `n` actions and `bytes` of text.
   type(code_undo), intent(inout) :: u     !< Undo list.
   integer(int32),  intent(in)    :: n     !< Actions.
   integer(int64),  intent(in)    :: bytes !< Text.
   integer(int8),  allocatable    :: k(:)  !< New kinds.
   type(code_pos), allocatable    :: s(:), e(:) !< New positions.
   integer(int64), allocatable    :: o(:), l(:) !< New offsets, lengths.
   character(len=:), allocatable  :: t     !< New text.
   integer(int32)                 :: m     !< Capacity.
   integer(int64)                 :: mt    !< Text capacity.

   if (.not. allocated(u%kind)) then
      allocate(u%kind(ROOM), u%astart(ROOM), u%aend(ROOM), u%off(ROOM), u%alen(ROOM))
      allocate(character(len=1024) :: u%text)
   endif
   if (size(u%kind, kind=int32) < n) then
      m = max(n, 2_int32 * size(u%kind, kind=int32))
      allocate(k(m), s(m), e(m), o(m), l(m))
      k(1:u%na) = u%kind(1:u%na)
      s(1:u%na) = u%astart(1:u%na)
      e(1:u%na) = u%aend(1:u%na)
      o(1:u%na) = u%off(1:u%na)
      l(1:u%na) = u%alen(1:u%na)
      call move_alloc(k, u%kind)
      call move_alloc(s, u%astart)
      call move_alloc(e, u%aend)
      call move_alloc(o, u%off)
      call move_alloc(l, u%alen)
   endif
   if (len(u%text, int64) < bytes) then
      mt = max(bytes, 2_int64 * len(u%text, int64))
      allocate(character(len=mt) :: t)
      t(1:u%nt) = u%text(1:u%nt)
      call move_alloc(t, u%text)
   endif
   endsubroutine reserve_actions

   pure subroutine add_action(u, kind, a, b, text)
   !< An action appended to the transaction being built.
   type(code_undo),  intent(inout) :: u    !< Undo list.
   integer(int8),    intent(in)    :: kind !< 1 insert, 2 delete.
   type(code_pos),   intent(in)    :: a, b !< Start, end.
   character(len=*), intent(in)    :: text !< Its text.

   call reserve_actions(u, u%na + 1_int32, u%nt + len(text, int64))
   u%na = u%na + 1_int32
   u%kind(u%na) = kind
   u%astart(u%na) = a
   u%aend(u%na) = b
   u%off(u%na) = u%nt
   u%alen(u%na) = len(text, int64)
   u%text(u%nt + 1_int64:u%nt + len(text, int64)) = text
   u%nt = u%nt + len(text, int64)
   endsubroutine add_action

   pure subroutine undo_add_insert(u, a, b, text)
   !< `Transaction::addInsert`.
   type(code_undo),  intent(inout) :: u    !< Undo list.
   type(code_pos),   intent(in)    :: a, b !< Start, end.
   character(len=*), intent(in)    :: text !< Inserted text.

   call add_action(u, 1_int8, a, b, text)
   endsubroutine undo_add_insert

   pure subroutine undo_add_delete(u, a, b, text)
   !< `Transaction::addDelete`.
   type(code_undo),  intent(inout) :: u    !< Undo list.
   type(code_pos),   intent(in)    :: a, b !< Start, end.
   character(len=*), intent(in)    :: text !< Deleted text.

   call add_action(u, 2_int8, a, b, text)
   endsubroutine undo_add_delete

   pure subroutine reserve_cursors(u, n)
   !< Room for `n` saved cursors.
   type(code_undo), intent(inout) :: u       !< Undo list.
   integer(int32),  intent(in)    :: n       !< Cursors.
   type(code_cursor), allocatable :: more(:) !< New pool.

   if (.not. allocated(u%cpool)) allocate(u%cpool(ROOM))
   if (size(u%cpool, kind=int32) >= n) return
   allocate(more(max(n, 2_int32 * size(u%cpool, kind=int32))))
   more(1:u%ncp) = u%cpool(1:u%ncp)
   call move_alloc(more, u%cpool)
   endsubroutine reserve_cursors

   pure subroutine reserve_transactions(u, n)
   !< Room for `n` transactions.
   type(code_undo), intent(inout) :: u  !< Undo list.
   integer(int32),  intent(in)    :: n  !< Transactions.
   integer(int32), allocatable    :: f(:), c(:), cf(:, :), cc(:, :), cm(:, :), cu(:, :) !< New arrays.
   integer(int32)                 :: m  !< Capacity.

   if (.not. allocated(u%first)) then
      allocate(u%first(ROOM), u%count(ROOM), u%cfirst(2, ROOM), u%ccount(2, ROOM), u%cmain(2, ROOM), &
               u%ccurrent(2, ROOM))
   endif
   if (size(u%first, kind=int32) >= n) return
   m = max(n, 2_int32 * size(u%first, kind=int32))
   allocate(f(m), c(m), cf(2, m), cc(2, m), cm(2, m), cu(2, m))
   f(1:u%nt_) = u%first(1:u%nt_)
   c(1:u%nt_) = u%count(1:u%nt_)
   cf(:, 1:u%nt_) = u%cfirst(:, 1:u%nt_)
   cc(:, 1:u%nt_) = u%ccount(:, 1:u%nt_)
   cm(:, 1:u%nt_) = u%cmain(:, 1:u%nt_)
   cu(:, 1:u%nt_) = u%ccurrent(:, 1:u%nt_)
   call move_alloc(f, u%first)
   call move_alloc(c, u%count)
   call move_alloc(cf, u%cfirst)
   call move_alloc(cc, u%ccount)
   call move_alloc(cm, u%cmain)
   call move_alloc(cu, u%ccurrent)
   endsubroutine reserve_transactions

   pure subroutine save_cursors(u, cs, t, which)
   !< The cursors `cs` saved as transaction `t`'s state `which` (1 before, 2 after).
   type(code_undo),    intent(inout) :: u     !< Undo list.
   type(code_cursors), intent(in)    :: cs    !< Cursors.
   integer(int32),     intent(in)    :: t     !< Transaction, from 1.
   integer(int32),     intent(in)    :: which !< 1 before, 2 after.

   call reserve_cursors(u, u%ncp + cs%n)
   u%cfirst(which, t) = u%ncp + 1_int32
   u%ccount(which, t) = cs%n
   u%cmain(which, t) = cs%main
   u%ccurrent(which, t) = cs%current
   u%cpool(u%ncp + 1:u%ncp + cs%n) = cs%c(1:cs%n)
   u%ncp = u%ncp + cs%n
   endsubroutine save_cursors

   pure subroutine undo_end(u, cs, done)
   !< `endTransaction`'s list part (`Transactions::add`): the transaction built, if it holds an action, made the last
   !< one (the undone ones after the undo index dropped), with `cs` (updated by the caller) as its after state.
   type(code_undo),    intent(inout) :: u    !< Undo list.
   type(code_cursors), intent(in)    :: cs   !< Cursors after it.
   logical,            intent(out)   :: done !< It held an action.
   integer(int32)                    :: na, k, t !< Its actions, counter, its index.
   integer(int64)                    :: keep_t   !< Text kept.
   integer(int32)                    :: keep_a, keep_c !< Actions, cursors kept.

   u%open = .false.
   na = u%na - u%b_first + 1_int32
   done = na > 0_int32
   if (.not. done) return
   ! drop the transactions after the undo index, and their actions, texts and cursors: the new actions move down
   if (u%undo_index < u%nt_) then
      t = u%undo_index + 1_int32
      keep_a = u%first(t) - 1_int32
      keep_c = u%cfirst(1, t) - 1_int32
      if (keep_a < u%b_first - 1_int32) then
         keep_t = u%off(keep_a + 1_int32)
         do k = 1_int32, na
            u%kind(keep_a + k) = u%kind(u%b_first + k - 1_int32)
            u%astart(keep_a + k) = u%astart(u%b_first + k - 1_int32)
            u%aend(keep_a + k) = u%aend(u%b_first + k - 1_int32)
            u%alen(keep_a + k) = u%alen(u%b_first + k - 1_int32)
            u%text(keep_t + 1_int64:keep_t + u%alen(keep_a + k)) = &
               u%text(u%off(u%b_first + k - 1_int32) + 1_int64:u%off(u%b_first + k - 1_int32) + u%alen(keep_a + k))
            u%off(keep_a + k) = keep_t
            keep_t = keep_t + u%alen(keep_a + k)
         enddo
         u%na = keep_a + na
         u%nt = keep_t
         u%b_first = keep_a + 1_int32
      endif
      u%ncp = keep_c
      u%nt_ = u%undo_index
   endif
   call reserve_transactions(u, u%nt_ + 1_int32)
   u%nt_ = u%nt_ + 1_int32
   u%first(u%nt_) = u%b_first
   u%count(u%nt_) = na
   call save_cursors(u, u%before, u%nt_, 1_int32)
   call save_cursors(u, cs, u%nt_, 2_int32)
   u%undo_index = u%nt_
   endsubroutine undo_end

   pure subroutine restore_cursors(u, t, which, cs)
   !< Transaction `t`'s saved state `which` (1 before, 2 after) into `cs`.
   type(code_undo),    intent(in)    :: u     !< Undo list.
   integer(int32),     intent(in)    :: t     !< Transaction, from 1.
   integer(int32),     intent(in)    :: which !< 1 before, 2 after.
   type(code_cursors), intent(inout) :: cs    !< Cursors.
   integer(int32)                    :: f, n  !< First, count.

   f = u%cfirst(which, t)
   n = u%ccount(which, t)
   call cursors_reserve(cs, max(n, 1_int32))
   cs%c(1:n) = u%cpool(f:f + n - 1_int32)
   cs%n = n
   cs%main = u%cmain(which, t)
   cs%current = u%ccurrent(which, t)
   endsubroutine restore_cursors

   pure subroutine undo_undo(u, doc, cs, tab_size, spaces_on_tabs)
   !< `Transactions::undo`: the last done transaction's actions reversed, the cursors as before it.
   type(code_undo),     intent(inout) :: u              !< Undo list.
   type(code_document), intent(inout) :: doc            !< Document.
   type(code_cursors),  intent(inout) :: cs             !< Cursors.
   integer(int32),      intent(in)    :: tab_size       !< Tab size.
   logical,             intent(in)    :: spaces_on_tabs !< Tabs as blanks.
   integer(int32)                     :: t, k           !< Transaction, action.
   type(code_pos)                     :: e              !< End of an insert.

   u%undo_index = u%undo_index - 1_int32
   t = u%undo_index + 1_int32
   do k = u%first(t) + u%count(t) - 1_int32, u%first(t), -1_int32
      if (u%kind(k) == 1_int8) then
         call doc_delete_text(doc, u%astart(k), u%aend(k), tab_size)
      else
         call doc_insert_text(doc, u%astart(k), u%text(u%off(k) + 1_int64:u%off(k) + u%alen(k)), tab_size, &
                              spaces_on_tabs, e)
      endif
   enddo
   call restore_cursors(u, t, 1_int32, cs)
   endsubroutine undo_undo

   pure subroutine undo_redo(u, doc, cs, tab_size, spaces_on_tabs)
   !< `Transactions::redo`: the next undone transaction's actions done again, the cursors as after it.
   type(code_undo),     intent(inout) :: u              !< Undo list.
   type(code_document), intent(inout) :: doc            !< Document.
   type(code_cursors),  intent(inout) :: cs             !< Cursors.
   integer(int32),      intent(in)    :: tab_size       !< Tab size.
   logical,             intent(in)    :: spaces_on_tabs !< Tabs as blanks.
   integer(int32)                     :: t, k           !< Transaction, action.
   type(code_pos)                     :: e              !< End of an insert.

   t = u%undo_index + 1_int32
   u%undo_index = u%undo_index + 1_int32
   do k = u%first(t), u%first(t) + u%count(t) - 1_int32
      if (u%kind(k) == 1_int8) then
         call doc_insert_text(doc, u%astart(k), u%text(u%off(k) + 1_int64:u%off(k) + u%alen(k)), tab_size, &
                              spaces_on_tabs, e)
      else
         call doc_delete_text(doc, u%astart(k), u%aend(k), tab_size)
      endif
   enddo
   call restore_cursors(u, t, 2_int32, cs)
   endsubroutine undo_redo
endmodule figure_code_document
