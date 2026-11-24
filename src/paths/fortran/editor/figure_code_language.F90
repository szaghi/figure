!< figure_code_language, the code editor's languages and colourizer, as ImGuiColorTextEdit's Language and Colorizer.
module figure_code_language
!< figure_code_language, the code editor's languages and colourizer, as ImGuiColorTextEdit's Language and Colorizer.
!<
!< szaghi/figure#15 P16. A language is data (`code_lang`): its comments, strings, preprocessor character, keyword sets,
!< and which tokenizers it uses, chosen by an integer (no procedure pointer per glyph): FIGURE's own (identifiers of
!< letters, digits and `_`; numbers with Fortran's kinds and exponents; ASCII punctuation; the key = value lines of
!< `native/figure_editor.cpp`) and the fork's languages' (szaghi/figure#15 P16, a later step). Languages live in a
!< registry for the program's life, as the native layer's map: one per packed definition (`figure_editor.F90`'s
!< `pack_language`), one per fork language; an editor holds a language's index (0: plain text), and the colourizer
!< recolours every line when that index changes, as the fork does when its language pointer changes.
!<
!< `colorize` is `Colorizer::update`: the lines marked as changed recoloured (all of them on a language change), the
!< state at a line's end (in a comment, a string) carried to the next line, which is recoloured in turn when its state
!< changed. Keyword sets are sorted lists in a pool, searched by bisection; an identifier is spelt into a fixed buffer
!< (lower case for a language without case), so colouring allocates nothing.
use, intrinsic :: iso_fortran_env, only : int8, int32, int64
use figure_code_document, only : code_document, code_line, COLOR_COMMENT, COLOR_DECLARATION, COLOR_IDENTIFIER, &
                                 COLOR_KEYWORD, COLOR_KNOWN_IDENTIFIER, COLOR_NUMBER, COLOR_PREPROCESSOR,           &
                                 COLOR_PUNCTUATION, COLOR_STRING, COLOR_TEXT, COLOR_WHITESPACE
use figure_code_unicode, only : cp_is_letter, cp_is_number, cp_is_white_space, cp_read, cp_to_lower, cp_write

implicit none
private
public :: code_lang, lang_of, lang_get, lang_name, lang_key_value, colorize, colorize_reset
public :: STATE_TEXT, STATE_COMMENT, STATE_SINGLE, STATE_DOUBLE, STATE_OTHER, STATE_OTHER_ALT, STATE_STRING0
public :: lang_comment_single

! line states (TextEditor::LineState)
integer(int32), parameter :: STATE_TEXT = 0_int32      !< inText.
integer(int32), parameter :: STATE_COMMENT = 1_int32   !< inComment (inCommentLevel1..7: 2..8).
integer(int32), parameter :: STATE_SINGLE = 9_int32    !< inSingleQuotedString.
integer(int32), parameter :: STATE_DOUBLE = 10_int32   !< inDoubleQuotedString.
integer(int32), parameter :: STATE_OTHER = 11_int32    !< inOtherString.
integer(int32), parameter :: STATE_OTHER_ALT = 12_int32 !< inOtherStringAlt.
integer(int32), parameter :: STATE_STRING0 = 13_int32  !< inStringLevel0 (..7: 13..20).
integer(int32), parameter :: MAX_LEVEL = 7_int32        !< maxCommentLevel, maxStringLevel.

! tokenizers
integer(int32), parameter :: TOK_NONE = 0_int32   !< None.
integer(int32), parameter :: TOK_FIGURE = 1_int32 !< FIGURE's (native/figure_editor.cpp).

type :: code_lang
   !< A language (`TextEditor::Language`).
   character(len=:), allocatable :: name               !< Its name.
   character(len=:), allocatable :: packed             !< The definition it was made from ('' for a fork language).
   logical                       :: case_sensitive = .true. !< Keywords by case.
   integer(int32)                :: preprocess = 0_int32    !< Preprocessor character (0: none).
   character(len=:), allocatable :: line_comment       !< singleLineComment.
   character(len=:), allocatable :: line_comment_alt   !< singleLineCommentAlt.
   character(len=:), allocatable :: comment_start      !< commentStart.
   character(len=:), allocatable :: comment_end        !< commentEnd.
   logical                       :: nested_comments = .false. !< nestedComments.
   logical                       :: single_quotes = .false.   !< hasSingleQuotedStrings.
   logical                       :: double_quotes = .false.   !< hasDoubleQuotedStrings.
   character(len=:), allocatable :: other_start        !< otherStringStart.
   character(len=:), allocatable :: other_end          !< otherStringEnd.
   character(len=:), allocatable :: other_alt_start    !< otherStringAltStart.
   character(len=:), allocatable :: other_alt_end      !< otherStringAltEnd.
   integer(int32)                :: escape = 0_int32   !< stringEscape (0: none).
   logical                       :: indentation_blocks = .false. !< indentationForBlocks.
   character(len=:), allocatable :: words              !< Keyword sets' words, one pool.
   integer(int32), allocatable   :: woff(:), wlen(:)   !< Each word's offset and length in `words`.
   integer(int32), allocatable   :: wset(:)            !< Each word's set: 1 keywords, 2 declarations, 3 identifiers.
   integer(int32)                :: nw = 0_int32       !< Words (sorted by set, then bytes).
   integer(int32)                :: identifier = TOK_NONE  !< getIdentifier.
   integer(int32)                :: number = TOK_NONE      !< getNumber.
   integer(int32)                :: punctuation = TOK_NONE !< isPunctuation.
   integer(int32)                :: custom = TOK_NONE      !< customTokenizer.
   integer(int32)                :: comment_level = TOK_NONE !< commentLevelStart, commentLevelEnd.
   integer(int32)                :: string_level = TOK_NONE  !< stringLevelStart, stringLevelEnd.
   logical                       :: key_value = .false.  !< FIGURE's key = value mode.
endtype code_lang

type :: lang_box
   !< A registry slot.
   type(code_lang), allocatable :: l !< The language.
endtype lang_box

!< The fork's languages, as `TextEditor::GetRegisteredLanguages` lists them (sorted).
character(len=*), parameter :: FORK_NAMES(13) = ['AngelScript', 'C          ', 'C#         ', 'C++        ', &
                                                 'GLSL       ', 'HLSL       ', 'JSON       ', 'Julia      ', &
                                                 'Lua        ', 'Markdown   ', 'Python     ', 'SQL        ', &
                                                 'WGSL       ']
character(len=*), parameter :: US = achar(31) !< Field separator of a packed definition.
character(len=*), parameter :: LF = achar(10) !< Line feed.

type(lang_box), allocatable, target, save :: registry(:) !< The languages.
integer(int32),              save :: nregistry = 0_int32 !< Languages registered.
character(len=1024),         save :: spell               !< An identifier spelt for the keyword lookup.

contains
   ! ---- the registry ------------------------------------------------------------------------------------------------
   function lang_get(id) result(p)
   !< The language `id` (from 1) of the registry.
   integer(int32), intent(in) :: id !< Language.
   type(code_lang), pointer   :: p  !< It.

   p => registry_at(id)
   endfunction lang_get

   function registry_at(id) result(p)
   !< Registry slot `id`'s language (null for 0, plain text). Valid until the next language is registered.
   integer(int32), intent(in) :: id !< Language.
   type(code_lang), pointer   :: p  !< It.

   p => null()
   if (id < 1_int32 .or. id > nregistry) return
   p => registry(id)%l
   endfunction registry_at

   function lang_name(id) result(name)
   !< A language's name ('' for plain text).
   integer(int32), intent(in)    :: id   !< Language (0: plain text).
   character(len=:), allocatable :: name !< Name.

   name = ''
   if (id < 1_int32 .or. id > nregistry) return
   name = registry(id)%l%name
   endfunction lang_name

   function lang_key_value(id) result(yes)
   !< The language is FIGURE's key = value mode.
   integer(int32), intent(in) :: id  !< Language (0: plain text).
   logical                    :: yes !< key = value.

   yes = .false.
   if (id < 1_int32 .or. id > nregistry) return
   yes = registry(id)%l%key_value
   endfunction lang_key_value

   function lang_comment_single(id) result(c)
   !< A language's line comment ('' for none, plain text).
   integer(int32), intent(in)    :: id !< Language.
   character(len=:), allocatable :: c  !< Line comment.

   c = ''
   if (id < 1_int32 .or. id > nregistry) return
   c = registry(id)%l%line_comment
   endfunction lang_comment_single

   subroutine registry_add(l, id)
   !< Add a language; its index.
   type(code_lang), allocatable, intent(inout) :: l  !< The language (moved in).
   integer(int32),               intent(out)   :: id !< Its index.
   type(lang_box), allocatable                 :: more(:) !< Grown registry.
   integer(int32)                              :: k  !< Counter.

   if (.not. allocated(registry)) allocate(registry(8))
   if (nregistry == size(registry, kind=int32)) then
      allocate(more(2_int32 * nregistry))
      do k = 1_int32, nregistry
         call move_alloc(registry(k)%l, more(k)%l)
      enddo
      call move_alloc(more, registry)
   endif
   nregistry = nregistry + 1_int32
   call move_alloc(l, registry(nregistry)%l)
   id = nregistry
   endsubroutine registry_add

   subroutine lang_of(packed, id, status, message)
   !< The language of a packed definition (`language_of` of native/figure_editor.cpp): 0 for plain text ('' or an empty
   !< name), a fork language by name in any case, else FIGURE's own, made once per definition. Status 0, or 1 with the
   !< glue's message for a malformed definition or an unknown fork language.
   character(len=*),              intent(in)  :: packed  !< Definition.
   integer(int32),                intent(out) :: id      !< Language (0: plain text).
   integer(int32),                intent(out) :: status  !< 0, or 1 on failure.
   character(len=:), allocatable, intent(out) :: message !< The failure's message.
   integer(int32)                             :: f(11), nf, k !< Field starts, fields, counter.
   type(code_lang), allocatable               :: l       !< A new language.
   character(len=:), allocatable              :: name    !< Its name.

   id = 0_int32
   status = 0_int32
   message = ''
   if (len(packed) == 0) return
   do k = 1_int32, nregistry
      if (registry(k)%l%packed == packed .and. len(registry(k)%l%packed) == len(packed)) then
         id = k
         return
      endif
   enddo
   nf = 1_int32
   f(1) = 1_int32
   do k = 1_int32, len(packed, int32)
      if (packed(k:k) == US) then
         nf = nf + 1_int32
         if (nf > 10_int32) exit
         f(nf) = k + 1_int32
      endif
   enddo
   if (nf /= 10_int32) then
      status = 1_int32
      message = 'code editor: a malformed language definition'
      return
   endif
   f(11) = len(packed, int32) + 2_int32
   name = field(1_int32)
   if (field(2_int32) == '1') then
      do k = 1_int32, size(FORK_NAMES, kind=int32)
         if (lower(trim(FORK_NAMES(k))) == lower(name) .and. len_trim(FORK_NAMES(k)) == len(name)) then
            id = fork_language(trim(FORK_NAMES(k)))
            return
         endif
      enddo
      status = 1_int32
      message = 'code editor: unknown language "'//name//'"'
      return
   endif
   if (len(name) == 0) return
   allocate(l)
   l%name = name
   l%packed = packed
   call figure_definition(l, field(3_int32), field(4_int32), field(5_int32), field(6_int32), field(7_int32), &
                          field(8_int32), field(9_int32), field(10_int32))
   call registry_add(l, id)
   contains
      function field(i) result(s)
      !< Field `i` of the definition.
      integer(int32), intent(in)    :: i !< Field, from 1.
      character(len=:), allocatable :: s !< Its text.

      s = packed(f(i):f(i + 1) - 2_int32)
      endfunction field
   endsubroutine lang_of

   function fork_language(name) result(id)
   !< The fork's language `name` (as registered), made on first use.
   character(len=*), intent(in) :: name !< Its registered name.
   integer(int32)               :: id   !< Its index.
   type(code_lang), allocatable :: l    !< A new language.
   integer(int32)               :: k    !< Counter.

   do k = 1_int32, nregistry
      if (len(registry(k)%l%packed) == 0 .and. registry(k)%l%name == name .and. len(registry(k)%l%name) == len(name)) &
         then
         id = k
         return
      endif
   enddo
   allocate(l)
   l%name = name
   l%packed = ''
   call fork_definition(l)
   call registry_add(l, id)
   endfunction fork_language

   subroutine figure_definition(l, keywords, types, comment, comment_alt, block_start, block_end, preprocessor, flags)
   !< A language of FIGURE's packed definition, as `language_of` builds it.
   type(code_lang),  intent(inout) :: l            !< The language.
   character(len=*), intent(in)    :: keywords     !< Keywords, LF-separated.
   character(len=*), intent(in)    :: types        !< Types, LF-separated.
   character(len=*), intent(in)    :: comment      !< Line comment.
   character(len=*), intent(in)    :: comment_alt  !< Its alternative.
   character(len=*), intent(in)    :: block_start  !< Block comment's start.
   character(len=*), intent(in)    :: block_end    !< ... end.
   character(len=*), intent(in)    :: preprocessor !< Preprocessor character.
   character(len=*), intent(in)    :: flags        !< Flags, as digits.
   integer(int32)                  :: fl, ios      !< Flags, I/O status.

   fl = 0_int32
   read(flags, *, iostat=ios) fl
   if (ios /= 0) fl = 0_int32
   l%case_sensitive = iand(fl, 8_int32) /= 0_int32
   call add_words(l, keywords, 1_int32)
   call add_words(l, types, 2_int32)
   l%line_comment = comment
   l%line_comment_alt = comment_alt
   l%comment_start = block_start
   l%comment_end = block_end
   l%preprocess = 0_int32
   if (len(preprocessor) > 0) l%preprocess = iachar(preprocessor(1:1))
   l%single_quotes = iand(fl, 1_int32) /= 0_int32
   l%double_quotes = iand(fl, 2_int32) /= 0_int32
   l%punctuation = TOK_FIGURE
   l%identifier = TOK_FIGURE
   if (iand(fl, 4_int32) /= 0_int32) l%number = TOK_FIGURE
   if (iand(fl, 16_int32) /= 0_int32) then
      l%custom = TOK_FIGURE
      l%key_value = .true.
   endif
   l%other_start = ''
   l%other_end = ''
   l%other_alt_start = ''
   l%other_alt_end = ''
   endsubroutine figure_definition

   subroutine fork_definition(l)
   !< A fork language's definition (its name set). Its rules come from the fork's language files (#15 P16, a later
   !< step); until then it colours nothing.
   type(code_lang), intent(inout) :: l !< The language.

   l%line_comment = ''
   l%line_comment_alt = ''
   l%comment_start = ''
   l%comment_end = ''
   l%other_start = ''
   l%other_end = ''
   l%other_alt_start = ''
   l%other_alt_end = ''
   endsubroutine fork_definition

   subroutine add_words(l, list, set)
   !< Add an LF-separated list of words to set `set` (lower case, ASCII, for a language without case, as the glue).
   type(code_lang),  intent(inout) :: l    !< The language.
   character(len=*), intent(in)    :: list !< Words.
   integer(int32),   intent(in)    :: set  !< 1 keywords, 2 declarations, 3 identifiers.
   integer(int32)                  :: a, k !< Start of a word, counter.

   a = 1_int32
   do k = 1_int32, len(list, int32) + 1_int32
      if (k > len(list, int32)) then
         call add_word(l, list(a:k - 1_int32), set)
      elseif (list(k:k) == LF) then
         call add_word(l, list(a:k - 1_int32), set)
         a = k + 1_int32
      endif
   enddo
   endsubroutine add_words

   subroutine add_word(l, word, set)
   !< Add a word to a set, kept sorted (set, then bytes); a word already there is not added again.
   type(code_lang),  intent(inout) :: l    !< The language.
   character(len=*), intent(in)    :: word !< Word.
   integer(int32),   intent(in)    :: set  !< Its set.
   character(len=:), allocatable   :: w    !< The word as stored.
   integer(int32), allocatable     :: o(:), n(:), s(:) !< Grown arrays.
   integer(int32)                  :: at, k, c !< Insertion point, counter, comparison.

   if (len(word) == 0) return
   if (l%case_sensitive) then
      w = word
   else
      w = lower(word)
   endif
   if (.not. allocated(l%woff)) then
      allocate(l%woff(32), l%wlen(32), l%wset(32))
      l%words = ''
   endif
   at = l%nw + 1_int32
   do k = 1_int32, l%nw
      c = compare(set, w, l%wset(k), l%words(l%woff(k) + 1:l%woff(k) + l%wlen(k)))
      if (c == 0_int32) return
      if (c < 0_int32) then
         at = k
         exit
      endif
   enddo
   if (l%nw == size(l%woff, kind=int32)) then
      allocate(o(2 * l%nw), n(2 * l%nw), s(2 * l%nw))
      o(1:l%nw) = l%woff(1:l%nw)
      n(1:l%nw) = l%wlen(1:l%nw)
      s(1:l%nw) = l%wset(1:l%nw)
      call move_alloc(o, l%woff)
      call move_alloc(n, l%wlen)
      call move_alloc(s, l%wset)
   endif
   do k = l%nw, at, -1_int32
      l%woff(k + 1) = l%woff(k)
      l%wlen(k + 1) = l%wlen(k)
      l%wset(k + 1) = l%wset(k)
   enddo
   l%woff(at) = len(l%words, int32)
   l%wlen(at) = len(w, int32)
   l%wset(at) = set
   l%words = l%words//w
   l%nw = l%nw + 1_int32
   endsubroutine add_word

   pure function compare(s1, w1, s2, w2) result(c)
   !< Order of (set, word): -1, 0, 1, bytes compared as unsigned, a prefix first.
   integer(int32),   intent(in) :: s1, s2 !< Sets.
   character(len=*), intent(in) :: w1, w2 !< Words.
   integer(int32)               :: c      !< Order.
   integer(int32)               :: k      !< Counter.

   if (s1 /= s2) then
      c = merge(-1_int32, 1_int32, s1 < s2)
      return
   endif
   do k = 1_int32, min(len(w1, int32), len(w2, int32))
      if (w1(k:k) /= w2(k:k)) then
         c = merge(-1_int32, 1_int32, iachar(w1(k:k)) < iachar(w2(k:k)))
         return
      endif
   enddo
   if (len(w1) == len(w2)) then
      c = 0_int32
   else
      c = merge(-1_int32, 1_int32, len(w1) < len(w2))
   endif
   endfunction compare

   function word_set(l, w) result(set)
   !< The set of word `w` (0: none), by bisection.
   type(code_lang),  intent(in) :: l   !< The language.
   character(len=*), intent(in) :: w   !< Word.
   integer(int32)               :: set !< 1 keyword, 2 declaration, 3 identifier, 0 none.
   integer(int32)               :: s, lo, hi, mid, c !< Set, bounds, comparison.

   set = 0_int32
   do s = 1_int32, 3_int32
      lo = 1_int32
      hi = l%nw
      do while (lo <= hi)
         mid = (lo + hi) / 2_int32
         c = compare(s, w, l%wset(mid), l%words(l%woff(mid) + 1:l%woff(mid) + l%wlen(mid)))
         if (c == 0_int32) then
            set = s
            return
         elseif (c < 0_int32) then
            hi = mid - 1_int32
         else
            lo = mid + 1_int32
         endif
      enddo
   enddo
   endfunction word_set

   pure function lower(s) result(l)
   !< `s` in lower case (ASCII), as the glue's `lower`.
   character(len=*), intent(in) :: s !< String.
   character(len=len(s))        :: l !< Lower case.
   integer(int32)               :: i, c !< Counter, code.

   l = s
   do i = 1_int32, len(s, int32)
      c = iachar(s(i:i))
      if (c >= 65_int32 .and. c <= 90_int32) l(i:i) = achar(c + 32_int32)
   enddo
   endfunction lower

   ! ---- FIGURE's tokenizers (native/figure_editor.cpp) ----------------------------------------------------------------
   pure function ident_start(c) result(yes)
   !< A letter or `_`.
   integer(int32), intent(in) :: c   !< Code point.
   logical                    :: yes !< Starts an identifier.

   yes = cp_is_letter(c) .or. c == 95_int32
   endfunction ident_start

   pure function ident_more(c) result(yes)
   !< A letter, a number or `_`.
   integer(int32), intent(in) :: c   !< Code point.
   logical                    :: yes !< Continues an identifier.

   yes = cp_is_letter(c) .or. cp_is_number(c) .or. c == 95_int32
   endfunction ident_more

   pure function digit(c) result(yes)
   !< An ASCII digit.
   integer(int32), intent(in) :: c   !< Code point.
   logical                    :: yes !< A digit.

   yes = c >= 48_int32 .and. c <= 57_int32
   endfunction digit

   pure function figure_identifier(cp, s, e) result(t)
   !< `get_identifier`: the end of an identifier from `s` (`s` if none). Glyph indices from 1, `e` past the line's end.
   integer(int32), intent(in) :: cp(:) !< The line's code points.
   integer(int32), intent(in) :: s, e  !< Start, end.
   integer(int32)             :: t     !< End of the token.

   t = s
   if (s == e) return
   if (.not. ident_start(cp(s))) return
   do while (t < e)
      if (.not. ident_more(cp(t))) exit
      t = t + 1_int32
   enddo
   endfunction figure_identifier

   pure function figure_number(cp, s, e) result(t)
   !< `get_number` of the glue: digits [. digits] or . digits, an exponent `[eEdDqQ][+-]digits`, a kind `_suffix`.
   integer(int32), intent(in) :: cp(:) !< The line's code points.
   integer(int32), intent(in) :: s, e  !< Start, end.
   integer(int32)             :: t     !< End of the token (`s`: none).
   integer(int32)             :: i, j  !< Positions.
   logical                    :: digits, frac !< Digits seen.

   t = s
   i = s
   digits = .false.
   do while (i < e)
      if (.not. digit(cp(i))) exit
      i = i + 1_int32
      digits = .true.
   enddo
   if (i < e) then
      if (cp(i) == 46_int32) then
         j = i + 1_int32
         frac = .false.
         do while (j < e)
            if (.not. digit(cp(j))) exit
            j = j + 1_int32
            frac = .true.
         enddo
         if (.not. digits .and. .not. frac) return
         if (frac .or. j == e) then
            i = j
         elseif (.not. cp_is_letter(cp(j)) .or. cp(j) == 101_int32 .or. cp(j) == 69_int32 .or. cp(j) == 100_int32 &
                 .or. cp(j) == 68_int32) then
            i = j
         endif
         digits = .true.
      endif
   endif
   if (.not. digits) return
   if (i < e) then
      if (cp(i) == 101_int32 .or. cp(i) == 69_int32 .or. cp(i) == 100_int32 .or. cp(i) == 68_int32 .or. &
          cp(i) == 113_int32 .or. cp(i) == 81_int32) then
         j = i + 1_int32
         if (j < e) then
            if (cp(j) == 43_int32 .or. cp(j) == 45_int32) j = j + 1_int32
         endif
         if (j < e) then
            if (digit(cp(j))) then
               do while (j < e)
                  if (.not. digit(cp(j))) exit
                  j = j + 1_int32
               enddo
               i = j
            endif
         endif
      endif
   endif
   if (i < e) then
      if (cp(i) == 95_int32) then
         j = i + 1_int32
         if (j < e) then
            if (ident_more(cp(j))) then
               do while (j < e)
                  if (.not. ident_more(cp(j))) exit
                  j = j + 1_int32
               enddo
               i = j
            endif
         endif
      endif
   endif
   if (i < e) then
      if (ident_more(cp(i))) return
   endif
   t = i
   endfunction figure_number

   pure function figure_punctuation(c) result(yes)
   !< ASCII punctuation (`c < 128 && ispunct(c)`, the C locale).
   integer(int32), intent(in) :: c   !< Code point.
   logical                    :: yes !< Punctuation.

   yes = (c >= 33_int32 .and. c <= 47_int32) .or. (c >= 58_int32 .and. c <= 64_int32) .or. &
         (c >= 91_int32 .and. c <= 96_int32) .or. (c >= 123_int32 .and. c <= 126_int32)
   endfunction figure_punctuation

   function figure_key_value(cp, s, e, color) result(t)
   !< `key_value_token`: `[section]` alone on its line (declaration), or a key before the line's `=` (keyword).
   integer(int32), intent(in)    :: cp(:) !< The line's code points.
   integer(int32), intent(in)    :: s, e  !< Start, end.
   integer(int8),  intent(inout) :: color !< The token's colour.
   integer(int32)                :: t     !< End of the token (`s`: none).
   integer(int32)                :: i, j, last !< Positions.

   t = s
   if (s == e) return
   if (cp(s) == 91_int32) then
      i = s + 1_int32
      do while (i < e)
         if (cp(i) == 93_int32 .or. cp(i) == 61_int32) exit
         i = i + 1_int32
      enddo
      if (i == e) return
      if (cp(i) /= 93_int32) return
      i = i + 1_int32
      j = i
      do while (j < e)
         if (.not. cp_is_white_space(cp(j))) exit
         j = j + 1_int32
      enddo
      if (j /= e) then
         if (cp(j) /= 33_int32 .and. cp(j) /= 35_int32 .and. cp(j) /= 59_int32) return
      endif
      color = COLOR_DECLARATION
      t = i
      return
   endif
   if (.not. ident_start(cp(s))) return
   i = s
   last = s
   do while (i < e)
      if (.not. (ident_more(cp(i)) .or. cp(i) == 32_int32 .or. cp(i) == 9_int32 .or. cp(i) == 45_int32 .or. &
                 cp(i) == 46_int32 .or. cp(i) == 37_int32)) exit
      if (.not. cp_is_white_space(cp(i))) last = i + 1_int32
      i = i + 1_int32
   enddo
   if (i == e) return
   if (cp(i) /= 61_int32) return
   color = COLOR_KEYWORD
   t = last
   endfunction figure_key_value

   ! ---- the colourizer ----------------------------------------------------------------------------------------------
   pure function matches(line, g, text) result(yes)
   !< `Colorizer::matches`: the glyphs from `g` (from 1) spell `text` (UTF-8).
   type(code_line),  intent(in) :: line !< Line.
   integer(int32),   intent(in) :: g    !< First glyph.
   character(len=*), intent(in) :: text !< Text.
   logical                      :: yes  !< They do.
   integer(int32)               :: i, k, c !< Byte, glyph, code point.

   yes = .false.
   i = 1_int32
   k = g
   do while (i <= len(text, int32))
      if (k > line%n) return
      call cp_read(text, i, c)
      if (line%cp(k) /= c) return
      k = k + 1_int32
   enddo
   yes = .true.
   endfunction matches

   subroutine set_color(line, a, b, color)
   !< Glyphs [a, b) (from 1) coloured `color`, clamped to the line (the fork's sizes are a token's bytes).
   type(code_line), intent(inout) :: line  !< Line.
   integer(int32),  intent(in)    :: a, b  !< Range.
   integer(int8),   intent(in)    :: color !< Colour.

   line%color(a:min(b, line%n + 1_int32) - 1_int32) = color
   endsubroutine set_color

   function update_line(l, line) result(state)
   !< `Colorizer::updateLine`: a line's glyphs coloured; the state at its end.
   type(code_lang), intent(in)    :: l     !< Language.
   type(code_line), intent(inout) :: line  !< Line.
   integer(int32)                 :: state !< State after the line.
   logical                        :: non_white !< A glyph other than blanks and the preprocessor seen.
   integer(int32)                 :: g, start, e, t, size, set, ns, k, m !< Glyphs, a token's end and size, counters.
   integer(int8)                  :: color !< A token's colour.
   character(len=4)               :: b     !< A code point's bytes.

   state = line%state
   non_white = .false.
   g = 1_int32
   e = line%n + 1_int32
   do while (g < e)
      start = g
      if (state == STATE_TEXT) then
         if (.not. non_white .and. l%preprocess /= 0_int32) then
            if (line%cp(g) /= l%preprocess .and. .not. cp_is_white_space(line%cp(g))) non_white = .true.
         endif
         if (g == start) then
            if (cp_is_white_space(line%cp(g))) then
               line%color(g) = COLOR_WHITESPACE
               g = g + 1_int32
            elseif (len(l%comment_start) > 0 .and. matches(line, g, l%comment_start)) then
               state = STATE_COMMENT
               size = len(l%comment_start, int32)
               call set_color(line, g, g + size, COLOR_COMMENT)
               g = g + size
            elseif (len(l%line_comment) > 0 .and. matches(line, g, l%line_comment)) then
               call set_color(line, g, e, COLOR_COMMENT)
               g = e
            elseif (len(l%line_comment_alt) > 0 .and. matches(line, g, l%line_comment_alt)) then
               call set_color(line, g, e, COLOR_COMMENT)
               g = e
            elseif (len(l%other_start) > 0 .and. matches(line, g, l%other_start)) then
               state = STATE_OTHER
               size = len(l%other_start, int32)
               call set_color(line, g, g + size, COLOR_STRING)
               g = g + size
            elseif (len(l%other_alt_start) > 0 .and. matches(line, g, l%other_alt_start)) then
               state = STATE_OTHER_ALT
               size = len(l%other_alt_start, int32)
               call set_color(line, g, g + size, COLOR_STRING)
               g = g + size
            elseif (l%single_quotes .and. line%cp(g) == 39_int32) then
               state = STATE_SINGLE
               line%color(g) = COLOR_STRING
               g = g + 1_int32
            elseif (l%double_quotes .and. line%cp(g) == 34_int32) then
               state = STATE_DOUBLE
               line%color(g) = COLOR_STRING
               g = g + 1_int32
            elseif (l%preprocess /= 0_int32 .and. .not. non_white .and. line%cp(g) == l%preprocess) then
               call set_color(line, 1_int32, e, COLOR_PREPROCESSOR)
               g = e
            endif
         endif
         if (g == start) then
            t = start
            color = COLOR_TEXT
            if (l%custom /= TOK_NONE) t = custom_token(l, line%cp, g, e, color)
            if (t /= start) then
               call set_color(line, g, t, color)
               g = t
            else
               if (l%identifier /= TOK_NONE) t = identifier_token(l, line%cp, g, e)
               if (t /= start) then
                  ns = 0_int32
                  do k = start, t - 1_int32
                     if (l%case_sensitive) then
                        call cp_write(line%cp(k), b, m)
                     else
                        call cp_write(cp_to_lower(line%cp(k)), b, m)
                     endif
                     if (ns + m <= len(spell, int32)) spell(ns + 1:ns + m) = b(1:m)
                     ns = ns + m
                  enddo
                  color = COLOR_IDENTIFIER
                  if (ns <= len(spell, int32)) then
                     set = word_set(l, spell(1:ns))
                     if (set == 1_int32) color = COLOR_KEYWORD
                     if (set == 2_int32) color = COLOR_DECLARATION
                     if (set == 3_int32) color = COLOR_KNOWN_IDENTIFIER
                  endif
                  call set_color(line, g, t, color)
                  g = t
               else
                  if (l%number /= TOK_NONE) t = number_token(l, line%cp, g, e)
                  if (t /= start) then
                     call set_color(line, g, t, COLOR_NUMBER)
                     g = t
                  elseif (is_punctuation(l, line%cp(g))) then
                     line%color(g) = COLOR_PUNCTUATION
                     g = g + 1_int32
                  else
                     line%color(g) = COLOR_TEXT
                     g = g + 1_int32
                  endif
               endif
            endif
         endif
      elseif (state >= STATE_COMMENT .and. state <= STATE_COMMENT + MAX_LEVEL) then
         size = len(l%comment_end, int32)
         if (size > 0_int32 .and. matches(line, g, l%comment_end)) then
            call set_color(line, g, g + size, COLOR_COMMENT)
            g = g + size
            if (l%nested_comments .and. state /= STATE_COMMENT) then
               state = state - 1_int32
            else
               state = STATE_TEXT
            endif
         elseif (l%nested_comments .and. matches(line, g, l%comment_start)) then
            size = len(l%comment_start, int32)
            call set_color(line, g, g + size, COLOR_COMMENT)
            g = g + size
            if (state /= STATE_COMMENT + MAX_LEVEL) state = state + 1_int32
         endif
         if (g == start) then
            line%color(g) = COLOR_COMMENT
            g = g + 1_int32
         endif
      elseif (state == STATE_OTHER .or. state == STATE_OTHER_ALT) then
         if (line%cp(g) == l%escape) then
            line%color(g) = COLOR_STRING
            g = g + 1_int32
            if (g < e) then
               line%color(g) = COLOR_STRING
               g = g + 1_int32
            endif
         elseif (state == STATE_OTHER .and. matches(line, g, l%other_end)) then
            size = len(l%other_end, int32)
            call set_color(line, g, g + size, COLOR_STRING)
            g = g + size
            state = STATE_TEXT
         elseif (state == STATE_OTHER_ALT .and. matches(line, g, l%other_alt_end)) then
            size = len(l%other_alt_end, int32)
            call set_color(line, g, g + size, COLOR_STRING)
            g = g + size
            state = STATE_TEXT
         else
            line%color(g) = COLOR_STRING
            g = g + 1_int32
         endif
      elseif (state == STATE_SINGLE .or. state == STATE_DOUBLE) then
         if (line%cp(g) == l%escape) then
            line%color(g) = COLOR_STRING
            g = g + 1_int32
            if (g < e) then
               line%color(g) = COLOR_STRING
               g = g + 1_int32
            endif
         elseif ((state == STATE_SINGLE .and. line%cp(g) == 39_int32) .or. &
                 (state == STATE_DOUBLE .and. line%cp(g) == 34_int32)) then
            line%color(g) = COLOR_STRING
            g = g + 1_int32
            state = STATE_TEXT
         else
            line%color(g) = COLOR_STRING
            g = g + 1_int32
         endif
      else
         ! a string level (a fork language's tokenizer: a later step): coloured as a string to the line's end
         line%color(g) = COLOR_STRING
         g = g + 1_int32
      endif
   enddo
   endfunction update_line

   function custom_token(l, cp, s, e, color) result(t)
   !< The language's custom tokenizer.
   type(code_lang), intent(in)    :: l     !< Language.
   integer(int32),  intent(in)    :: cp(:) !< The line's code points.
   integer(int32),  intent(in)    :: s, e  !< Start, end.
   integer(int8),   intent(inout) :: color !< The token's colour.
   integer(int32)                 :: t     !< End of the token.

   select case (l%custom)
   case (TOK_FIGURE)
      t = figure_key_value(cp, s, e, color)
   case default
      t = s
   endselect
   endfunction custom_token

   pure function identifier_token(l, cp, s, e) result(t)
   !< The language's identifier tokenizer.
   type(code_lang), intent(in) :: l     !< Language.
   integer(int32),  intent(in) :: cp(:) !< The line's code points.
   integer(int32),  intent(in) :: s, e  !< Start, end.
   integer(int32)              :: t     !< End of the token.

   select case (l%identifier)
   case (TOK_FIGURE)
      t = figure_identifier(cp, s, e)
   case default
      t = s
   endselect
   endfunction identifier_token

   pure function number_token(l, cp, s, e) result(t)
   !< The language's number tokenizer.
   type(code_lang), intent(in) :: l     !< Language.
   integer(int32),  intent(in) :: cp(:) !< The line's code points.
   integer(int32),  intent(in) :: s, e  !< Start, end.
   integer(int32)              :: t     !< End of the token.

   select case (l%number)
   case (TOK_FIGURE)
      t = figure_number(cp, s, e)
   case default
      t = s
   endselect
   endfunction number_token

   pure function is_punctuation(l, c) result(yes)
   !< The language's punctuation.
   type(code_lang), intent(in) :: l   !< Language.
   integer(int32),  intent(in) :: c   !< Code point.
   logical                     :: yes !< Punctuation.

   select case (l%punctuation)
   case (TOK_FIGURE)
      yes = figure_punctuation(c)
   case default
      yes = .false.
   endselect
   endfunction is_punctuation

   subroutine colorize_reset(doc)
   !< Every glyph text-coloured, every line's state in text (no language).
   type(code_document), intent(inout) :: doc !< Document.
   integer(int32)                     :: k   !< Line.

   do k = 1_int32, doc%n
      if (doc%lines(k)%n > 0_int32) doc%lines(k)%color(1:doc%lines(k)%n) = COLOR_TEXT
      doc%lines(k)%state = STATE_TEXT
      doc%lines(k)%needs_colorizing = .false.
   enddo
   endsubroutine colorize_reset

   subroutine colorize(doc, id, current, changed)
   !< `Colorizer::update`: on a language change (`id` /= `current`, which becomes `id`), every line; else, when the
   !< document changed, the lines marked, a line's end state carried to the next (recoloured when it changed).
   type(code_document), intent(inout) :: doc     !< Document.
   integer(int32),      intent(in)    :: id      !< The editor's language (0: plain text).
   integer(int32),      intent(inout) :: current !< The language the colours are of.
   logical,             intent(out)   :: changed !< The language changed.
   type(code_lang), pointer           :: l       !< Language.
   integer(int32)                     :: k, s    !< Line, state.

   changed = id /= current
   l => registry_at(id)
   if (changed) then
      current = id
      if (associated(l)) then
         do k = 1_int32, doc%n
            s = update_line(l, doc%lines(k))
            doc%lines(k)%needs_colorizing = .false.
            if (k < doc%n) doc%lines(k + 1)%state = s
         enddo
      else
         call colorize_reset(doc)
      endif
   elseif (doc%updated) then
      do k = 1_int32, doc%n
         if (.not. doc%lines(k)%needs_colorizing) cycle
         if (associated(l)) then
            s = update_line(l, doc%lines(k))
            doc%lines(k)%needs_colorizing = .false.
            if (k < doc%n) then
               if (doc%lines(k + 1)%state /= s) then
                  doc%lines(k + 1)%state = s
                  doc%lines(k + 1)%needs_colorizing = .true.
               endif
            endif
         else
            if (doc%lines(k)%n > 0_int32) doc%lines(k)%color(1:doc%lines(k)%n) = COLOR_TEXT
            doc%lines(k)%state = STATE_TEXT
            doc%lines(k)%needs_colorizing = .false.
         endif
      enddo
   endif
   endsubroutine colorize
endmodule figure_code_language
