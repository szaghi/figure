!< figure_markdown_search, the matches of a query in a text (UTF-8): the search of the Fortran path's Markdown documents.
module figure_markdown_search
!< figure_markdown_search, the matches of a query in a text (UTF-8): the search of the Fortran path's Markdown documents.
!<
!< szaghi/figure#15 P15: imgui_rich_md's `FindMatches` (`internal/rich_md_search.cpp`), the same matches to the byte. The
!< text and the query are folded code point by code point, and the folded text keeps, for each of its bytes, the offset
!< of its code point in the text: a match found in the folded text maps back to the text's bytes. Folding: the
!< diacritics of Latin-1 and Latin Extended-A (`é` to `e`, `Ł` to `L`; the ligatures and the letters of their own, as
!< `æ` or `ß`, kept), then the case of the Latin, Greek and Cyrillic letters (`Σ` to `σ`, the final `ς` to `σ`). A byte
!< that does not start a whole sequence (a continuation byte, a sequence cut, or one that ends the text: imgui_rich_md
!< reads the last sequence of a text byte by byte) is read as the code point of its value. No Dear ImGui.
use, intrinsic :: iso_fortran_env, only : int32

implicit none
private
public :: find_matches

character(len=*), parameter :: LATIN1_BASES = 'AAAAAA.CEEEEIIII.NOOOOO.OUUUUY..aaaaaa.ceeeeiiii.nooooo.ouuuuy.y' !< U+00C0..U+00FF.
character(len=*), parameter :: LATINA_BASES = 'AaAaAaCcCcCcCcDdDdEeEeEeEeEeGgGgGgGgHhHhIiIiIiIiIi..JjKk.LlLlLlLlLlNnNnNnn'// &
                                              '..OoOoOo..RrRrRrSsSsSsSsTtTtTtUuUuUuUuUuUuWwYyYZzZzZzs' !< U+0100..U+017F.

contains
   subroutine find_matches(text, query, match_case, whole_words, mb, me, n)
   !< The matches of `query` in `text`, in order, not overlapping (none for an empty query): their bytes [mb, me),
   !< 0-based offsets in `text`.
   character(len=*),            intent(in)  :: text        !< Text.
   character(len=*),            intent(in)  :: query       !< Query.
   logical,                     intent(in)  :: match_case  !< Case kept.
   logical,                     intent(in)  :: whole_words !< Whole words only.
   integer(int32), allocatable, intent(out) :: mb(:), me(:) !< Matches.
   integer(int32),              intent(out) :: n           !< How many.
   character(len=:), allocatable            :: ft, fq      !< Folded text and query.
   integer(int32), allocatable              :: origin(:), qorigin(:), more(:) !< Offsets of the folded bytes.
   integer(int32)                           :: at, last    !< A match, its end.

   n = 0_int32
   allocate(mb(8), me(8))
   if (len(query) == 0) return
   call fold(text, match_case, ft, origin)
   call fold(query, match_case, fq, qorigin)
   at = index(ft, fq) - 1_int32
   do while (at >= 0_int32)
      last = at + len(fq, int32)
      if (.not. whole_words .or. (.not. word_char_before(ft, at) .and. .not. word_char_at(ft, last))) then
         if (n == size(mb, kind=int32)) then
            allocate(more(2_int32 * n))
            more(1:n) = mb(1:n)
            call move_alloc(more, mb)
            allocate(more(2_int32 * n))
            more(1:n) = me(1:n)
            call move_alloc(more, me)
         endif
         n = n + 1_int32
         mb(n) = origin(at + 1_int32)
         me(n) = origin(last + 1_int32)
         at = find_from(ft, fq, last)
      else
         at = find_from(ft, fq, at + 1_int32)
      endif
   enddo
   endsubroutine find_matches

   pure function find_from(s, q, from) result(at)
   !< `s.find(q, from)`: the 0-based offset of q in s from `from`, -1 when none.
   character(len=*), intent(in) :: s, q !< Text, query.
   integer(int32),   intent(in) :: from !< Start (0-based).
   integer(int32)               :: at   !< Offset.

   at = -1_int32
   if (from > len(s, int32)) return
   at = index(s(from + 1_int32:), q)
   if (at == 0_int32) then
      at = -1_int32
   else
      at = at - 1_int32 + from
   endif
   endfunction find_from

   pure subroutine decode(s, i, cp)
   !< One code point at i (0-based; i advances); a byte that does not start a whole sequence is read as it is.
   character(len=*), intent(in)    :: s  !< Text.
   integer(int32),   intent(inout) :: i  !< Offset.
   integer(int32),   intent(out)   :: cp !< Code point.
   integer(int32)                  :: c, cc, n, k !< Bytes, length, counter.

   c = iachar(s(i + 1:i + 1), int32)
   n = 0_int32
   if (c >= 240_int32) then
      n = 3_int32
   elseif (c >= 224_int32) then
      n = 2_int32
   elseif (c >= 192_int32) then
      n = 1_int32
   endif
   if (c < 128_int32 .or. n == 0_int32 .or. i + n >= len(s, int32)) then
      i = i + 1_int32
      cp = c
      return
   endif
   cp = iand(c, ishft(63_int32, -n))
   do k = 1_int32, n
      cc = iachar(s(i + k + 1:i + k + 1), int32)
      if (iand(cc, 192_int32) /= 128_int32) then
         i = i + 1_int32
         cp = c
         return
      endif
      cp = ior(ishft(cp, 6), iand(cc, 63_int32))
   enddo
   i = i + n + 1_int32
   endsubroutine decode

   pure function encode(cp) result(s)
   !< A code point in UTF-8 (its bytes assigned one by one: nvfortran 26.9 takes `i` as the length in `s//achar(i)`).
   integer(int32), intent(in)    :: cp  !< Code point.
   character(len=:), allocatable :: s   !< Its bytes.
   character(len=4)              :: buf !< The bytes.
   integer(int32)                :: n   !< How many.

   if (cp < 128_int32) then
      buf(1:1) = achar(cp)
      n = 1_int32
   elseif (cp < 2048_int32) then
      buf(1:1) = achar(ior(192_int32, ishft(cp, -6)))
      buf(2:2) = achar(ior(128_int32, iand(cp, 63_int32)))
      n = 2_int32
   elseif (cp < 65536_int32) then
      buf(1:1) = achar(ior(224_int32, ishft(cp, -12)))
      buf(2:2) = achar(ior(128_int32, iand(ishft(cp, -6), 63_int32)))
      buf(3:3) = achar(ior(128_int32, iand(cp, 63_int32)))
      n = 3_int32
   else
      buf(1:1) = achar(ior(240_int32, ishft(cp, -18)))
      buf(2:2) = achar(ior(128_int32, iand(ishft(cp, -12), 63_int32)))
      buf(3:3) = achar(ior(128_int32, iand(ishft(cp, -6), 63_int32)))
      buf(4:4) = achar(ior(128_int32, iand(cp, 63_int32)))
      n = 4_int32
   endif
   s = buf(1:n)
   endfunction encode

   pure function without_diacritics(cp) result(r)
   !< The base letter of U+00C0..U+017F (the others kept).
   integer(int32), intent(in) :: cp !< Code point.
   integer(int32)             :: r  !< Folded.
   character                  :: base !< Its base ('.': none).

   r = cp
   base = '.'
   if (cp >= 192_int32 .and. cp <= 255_int32) then
      base = LATIN1_BASES(cp - 191_int32:cp - 191_int32)
   elseif (cp >= 256_int32 .and. cp <= 383_int32) then
      base = LATINA_BASES(cp - 255_int32:cp - 255_int32)
   endif
   if (base /= '.') r = iachar(base, int32)
   endfunction without_diacritics

   pure function lower(cp) result(r)
   !< The lower case of a Latin, Greek or Cyrillic letter (`Lower`).
   integer(int32), intent(in) :: cp !< Code point.
   integer(int32)             :: r  !< Folded.
   logical                    :: upper_even, upper_odd !< Latin Extended-A's pairs.

   r = cp
   if (cp >= iachar('A', int32) .and. cp <= iachar('Z', int32)) then
      r = cp + 32_int32
   elseif (cp < 192_int32) then
      r = cp
   elseif (cp <= 222_int32) then
      if (cp /= 215_int32) r = cp + 32_int32
   elseif (cp >= 256_int32 .and. cp <= 383_int32) then
      if (cp == 304_int32) then
         r = iachar('i', int32)
      elseif (cp == 376_int32) then
         r = 255_int32
      else
         upper_even = cp <= 311_int32 .or. (cp >= 330_int32 .and. cp <= 375_int32)
         upper_odd = (cp >= 313_int32 .and. cp <= 328_int32) .or. (cp >= 377_int32 .and. cp <= 382_int32)
         if ((upper_even .and. mod(cp, 2_int32) == 0_int32) .or. (upper_odd .and. mod(cp, 2_int32) == 1_int32)) &
            r = cp + 1_int32
      endif
   elseif (cp >= 913_int32 .and. cp <= 937_int32 .and. cp /= 930_int32) then
      r = cp + 32_int32
   elseif (cp == 902_int32) then
      r = 940_int32
   elseif (cp >= 904_int32 .and. cp <= 906_int32) then
      r = cp + 37_int32
   elseif (cp == 908_int32) then
      r = 972_int32
   elseif (cp == 910_int32 .or. cp == 911_int32) then
      r = cp + 63_int32
   elseif (cp == 962_int32) then
      r = 963_int32
   elseif (cp >= 1040_int32 .and. cp <= 1071_int32) then
      r = cp + 32_int32
   elseif (cp >= 1024_int32 .and. cp <= 1039_int32) then
      r = cp + 80_int32
   endif
   endfunction lower

   pure function is_word_char(cp) result(yes)
   !< A letter, a digit or `_` (any code point beyond ASCII, but the punctuation of Latin-1, the general punctuation and
   !< that of CJK).
   integer(int32), intent(in) :: cp  !< Code point.
   logical                    :: yes !< A word's.

   if (cp < 128_int32) then
      yes = (cp >= iachar('a', int32) .and. cp <= iachar('z', int32)) .or. &
            (cp >= iachar('A', int32) .and. cp <= iachar('Z', int32)) .or. &
            (cp >= iachar('0', int32) .and. cp <= iachar('9', int32)) .or. cp == iachar('_', int32)
      return
   endif
   yes = .false.
   if (cp <= 191_int32 .or. cp == 215_int32 .or. cp == 247_int32) return
   if ((cp >= 8192_int32 .and. cp <= 8303_int32) .or. (cp >= 12288_int32 .and. cp <= 12351_int32)) return
   yes = .true.
   endfunction is_word_char

   subroutine fold(s, match_case, folded, origin)
   !< A text folded (the diacritics always, the case unless kept), with each folded byte's code point's offset in the
   !< text (0-based), then the text's length.
   character(len=*),              intent(in)  :: s          !< Text.
   logical,                       intent(in)  :: match_case !< Case kept.
   character(len=:), allocatable, intent(out) :: folded     !< Folded text.
   integer(int32),   allocatable, intent(out) :: origin(:)  !< Offsets.
   character(len=:), allocatable              :: u          !< A code point's bytes.
   integer(int32)                             :: i, start, cp, n, k !< Offsets, code point, bytes.

   allocate(character(len=4 * len(s)) :: folded)
   allocate(origin(4 * len(s) + 1))
   n = 0_int32
   i = 0_int32
   do while (i < len(s, int32))
      start = i
      call decode(s, i, cp)
      cp = without_diacritics(cp)
      if (.not. match_case) cp = lower(cp)
      u = encode(cp)
      do k = 1_int32, len(u, int32)
         n = n + 1_int32
         folded(n:n) = u(k:k)
         origin(n) = start
      enddo
   enddo
   origin(n + 1_int32) = len(s, int32)
   u = folded(1:n)
   call move_alloc(u, folded)
   endsubroutine fold

   function word_char_before(s, i) result(yes)
   !< Whether the code point that ends at i (0-based) is a word character.
   character(len=*), intent(in) :: s   !< Folded text.
   integer(int32),   intent(in) :: i   !< Offset.
   logical                      :: yes !< A word's.
   integer(int32)               :: start, cp !< Its start, code point.

   yes = .false.
   if (i == 0_int32) return
   start = i - 1_int32
   do while (start > 0_int32)
      if (iand(iachar(s(start + 1:start + 1), int32), 192_int32) /= 128_int32) exit
      start = start - 1_int32
   enddo
   call decode(s, start, cp)
   yes = is_word_char(cp)
   endfunction word_char_before

   function word_char_at(s, i) result(yes)
   !< Whether the code point that starts at i (0-based) is a word character.
   character(len=*), intent(in) :: s   !< Folded text.
   integer(int32),   intent(in) :: i   !< Offset.
   logical                      :: yes !< A word's.
   integer(int32)               :: j, cp !< Offset, code point.

   yes = .false.
   if (i >= len(s, int32)) return
   j = i
   call decode(s, j, cp)
   yes = is_word_char(cp)
   endfunction word_char_at
endmodule figure_markdown_search
