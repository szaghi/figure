!< figure_code_unicode, the code editor's UTF-8 and code-point classes, as ImGuiColorTextEdit's TextEditor::CodePoint.
module figure_code_unicode
!< figure_code_unicode, the code editor's UTF-8 and code-point classes, as ImGuiColorTextEdit's TextEditor::CodePoint.
!<
!< szaghi/figure#15 P16. A code point is the fork's `ImWchar`: 16 bits (FIGURE builds Dear ImGui without
!< `IMGUI_USE_WCHAR32`), held here in an `integer(int32)` in [0, 65535]. UTF-8 is read and written as the fork does
!< (`CodePoint::read`, `CodePoint::write`): a sequence cut short or not UTF-8 is U+FFFD and one byte, a four-byte
!< sequence U+FFFD and four bytes, no check of the continuation bytes. The classes search the fork's tables
!< (figure_code_unicode_tables, generated from TextEditor.cpp) by the fork's binary search; the fork's search can read
!< one entry past a table for a code point above its last range (`high` starts at the table's end): such a code point
!< is answered "not in the table" here, as the entry past each table answers there.
!<
!< StringiFor's Unicode 17.0 tables are not used here: they classify some code points otherwise than the fork's tables
!< do, and the editor's words, columns and case changes must be the fork's (the oracle of #15 §4).
use, intrinsic :: iso_fortran_env, only : int32
use figure_code_unicode_tables, only : CASES, EAST_ASIANS, LETTERS, LOWERS, NUMBERS, UPPERS, WHITESPACES, WIDE_GLYPHS, &
                                       XID_CONTINUES, XID_STARTS

implicit none
private
public :: CP_INVALID
public :: cp_read, cp_write, cp_is_letter, cp_is_number, cp_is_word, cp_is_white_space, cp_is_xid_start
public :: cp_is_xid_continue, cp_is_lower, cp_is_upper, cp_is_east_asian, cp_glyph_width, cp_to_upper, cp_to_lower
public :: cp_is_bracket_opener, cp_is_bracket_closer, cp_to_pair_closer, cp_to_pair_opener, cp_is_pair_opener

integer(int32), parameter :: CP_INVALID = 65533_int32 !< IM_UNICODE_CODEPOINT_INVALID (U+FFFD).

contains
   pure subroutine cp_read(text, i, cp)
   !< The code point at byte `i` of `text` (`CodePoint::read`); `i` moves past its sequence. `i` must be in the text.
   character(len=*), intent(in)    :: text !< UTF-8 text.
   integer(int32),   intent(inout) :: i    !< Byte position, from 1.
   integer(int32),   intent(out)   :: cp   !< The code point.
   integer(int32)                  :: n    !< Bytes left from `i`.
   integer(int32)                  :: b0   !< First byte.

   n = len(text, int32) - i + 1_int32
   b0 = iachar(text(i:i))
   if (iand(b0, 128_int32) == 0_int32) then
      cp = b0
      i = i + 1_int32
   elseif (n > 1_int32 .and. iand(b0, 224_int32) == 192_int32) then
      cp = ior(ishft(iand(b0, 31_int32), 6), iand(iachar(text(i + 1:i + 1)), 63_int32))
      i = i + 2_int32
   elseif (n > 2_int32 .and. iand(b0, 240_int32) == 224_int32) then
      cp = ior(ior(ishft(iand(b0, 15_int32), 12), ishft(iand(iachar(text(i + 1:i + 1)), 63_int32), 6)), &
               iand(iachar(text(i + 2:i + 2)), 63_int32))
      i = i + 3_int32
   elseif (n > 3_int32 .and. iand(b0, 248_int32) == 240_int32) then
      cp = CP_INVALID
      i = i + 4_int32
   else
      cp = CP_INVALID
      i = i + 1_int32
   endif
   endsubroutine cp_read

   pure subroutine cp_write(cp, buf, n)
   !< The UTF-8 bytes of `cp` (`CodePoint::write` with 16-bit code points): `n` (1 to 3) bytes in `buf(1:n)`.
   integer(int32),   intent(in)  :: cp  !< Code point, in [0, 65535].
   character(len=4), intent(out) :: buf !< Bytes.
   integer(int32),   intent(out) :: n   !< Bytes written.

   buf = ''
   if (cp < 128_int32) then
      buf(1:1) = achar(cp)
      n = 1_int32
   elseif (cp < 2048_int32) then
      buf(1:1) = achar(ior(192_int32, iand(ishft(cp, -6), 31_int32)))
      buf(2:2) = achar(ior(128_int32, iand(cp, 63_int32)))
      n = 2_int32
   else
      buf(1:1) = achar(ior(224_int32, iand(ishft(cp, -12), 15_int32)))
      buf(2:2) = achar(ior(128_int32, iand(ishft(cp, -6), 63_int32)))
      buf(3:3) = achar(ior(128_int32, iand(cp, 63_int32)))
      n = 3_int32
   endif
   endsubroutine cp_write

   pure function in_strides(table, cp) result(yes)
   !< The fork's `rangeContains`: `cp` in a table of `low, high, stride` ranges.
   integer(int32), intent(in) :: table(:) !< Ranges, flat.
   integer(int32), intent(in) :: cp       !< Code point.
   logical                    :: yes      !< In the table.
   integer(int32)             :: lo, hi, mid !< Search bounds (ranges, from 1).

   yes = .false.
   lo = 1_int32
   hi = size(table, kind=int32) / 3_int32
   do while (lo <= hi)
      mid = lo + (hi - lo) / 2_int32
      if (cp >= table(3 * mid - 2) .and. cp <= table(3 * mid - 1)) then
         yes = table(3 * mid) == 1_int32 .or. mod(cp - table(3 * mid - 2), table(3 * mid)) == 0_int32
         return
      elseif (cp < table(3 * mid - 2)) then
         hi = mid - 1_int32
      else
         lo = mid + 1_int32
      endif
   enddo
   endfunction in_strides

   pure function in_ranges(table, cp) result(yes)
   !< The fork's `rangeFind`: `cp` in a table of `low, high` ranges.
   integer(int32), intent(in) :: table(:) !< Ranges, flat.
   integer(int32), intent(in) :: cp       !< Code point.
   logical                    :: yes      !< In the table.
   integer(int32)             :: lo, hi, mid !< Search bounds (ranges, from 1).

   yes = .false.
   lo = 1_int32
   hi = size(table, kind=int32) / 2_int32
   do while (lo <= hi)
      mid = lo + (hi - lo) / 2_int32
      if (cp >= table(2 * mid - 1) .and. cp <= table(2 * mid)) then
         yes = .true.
         return
      elseif (cp < table(2 * mid - 1)) then
         hi = mid - 1_int32
      else
         lo = mid + 1_int32
      endif
   enddo
   endfunction in_ranges

   pure function case_range(cp) result(k)
   !< The fork's `caseRangeFind` in its case table: the range holding `cp` (from 1), 0 for none.
   integer(int32), intent(in) :: cp !< Code point.
   integer(int32)             :: k  !< Range.
   integer(int32)             :: lo, hi, mid !< Search bounds.

   k = 0_int32
   lo = 1_int32
   hi = size(CASES, kind=int32) / 4_int32
   do while (lo <= hi)
      mid = lo + (hi - lo) / 2_int32
      if (cp >= CASES(4 * mid - 3) .and. cp <= CASES(4 * mid - 2)) then
         k = mid
         return
      elseif (cp < CASES(4 * mid - 3)) then
         hi = mid - 1_int32
      else
         lo = mid + 1_int32
      endif
   enddo
   endfunction case_range

   pure function ascii_letter(cp) result(yes)
   !< `(cp | 32) - 'a' < 26` as unsigned: an ASCII letter.
   integer(int32), intent(in) :: cp  !< Code point below 127.
   logical                    :: yes !< A letter.

   yes = ior(cp, 32_int32) >= 97_int32 .and. ior(cp, 32_int32) <= 122_int32
   endfunction ascii_letter

   pure function cp_is_letter(cp) result(yes)
   !< `CodePoint::isLetter`.
   integer(int32), intent(in) :: cp  !< Code point.
   logical                    :: yes !< A letter.

   if (cp < 127_int32) then
      yes = ascii_letter(cp)
   else
      yes = in_strides(LETTERS, cp)
   endif
   endfunction cp_is_letter

   pure function cp_is_number(cp) result(yes)
   !< `CodePoint::isNumber`.
   integer(int32), intent(in) :: cp  !< Code point.
   logical                    :: yes !< A number.

   if (cp < 127_int32) then
      yes = cp >= 48_int32 .and. cp <= 57_int32
   else
      yes = in_strides(NUMBERS, cp)
   endif
   endfunction cp_is_number

   pure function cp_is_xid_start(cp) result(yes)
   !< `CodePoint::isXidStart`.
   integer(int32), intent(in) :: cp  !< Code point.
   logical                    :: yes !< An identifier's start.

   if (cp < 127_int32) then
      yes = cp == 95_int32 .or. ascii_letter(cp)
   else
      yes = in_strides(XID_STARTS, cp)
   endif
   endfunction cp_is_xid_start

   pure function cp_is_white_space(cp) result(yes)
   !< `CodePoint::isWhiteSpace`.
   integer(int32), intent(in) :: cp  !< Code point.
   logical                    :: yes !< White space.

   if (cp < 127_int32) then
      yes = cp == 32_int32 .or. (cp >= 9_int32 .and. cp <= 13_int32)
   else
      yes = in_strides(WHITESPACES, cp)
   endif
   endfunction cp_is_white_space

   pure function cp_is_word(cp) result(yes)
   !< `CodePoint::isWord`: a letter, a number or `_`.
   integer(int32), intent(in) :: cp  !< Code point.
   logical                    :: yes !< A word's character.

   if (cp < 127_int32) then
      yes = ascii_letter(cp) .or. (cp >= 48_int32 .and. cp <= 57_int32) .or. cp == 95_int32
   else
      yes = in_strides(LETTERS, cp) .or. in_strides(NUMBERS, cp) .or. cp == 95_int32
   endif
   endfunction cp_is_word

   pure function cp_is_xid_continue(cp) result(yes)
   !< `CodePoint::isXidContinue`.
   integer(int32), intent(in) :: cp  !< Code point.
   logical                    :: yes !< An identifier's continuation.

   if (cp < 127_int32) then
      yes = cp == 95_int32 .or. ascii_letter(cp) .or. (cp >= 48_int32 .and. cp <= 57_int32)
   else
      yes = in_strides(XID_CONTINUES, cp)
   endif
   endfunction cp_is_xid_continue

   pure function cp_is_lower(cp) result(yes)
   !< `CodePoint::isLower`.
   integer(int32), intent(in) :: cp  !< Code point.
   logical                    :: yes !< Lower case.

   if (cp < 127_int32) then
      yes = cp >= 97_int32 .and. cp <= 122_int32
   else
      yes = in_strides(LOWERS, cp)
   endif
   endfunction cp_is_lower

   pure function cp_is_upper(cp) result(yes)
   !< `CodePoint::isUpper`.
   integer(int32), intent(in) :: cp  !< Code point.
   logical                    :: yes !< Upper case.

   if (cp < 127_int32) then
      yes = cp >= 65_int32 .and. cp <= 90_int32
   else
      yes = in_strides(UPPERS, cp)
   endif
   endfunction cp_is_upper

   pure function cp_is_east_asian(cp) result(yes)
   !< `CodePoint::isEastAsian`.
   integer(int32), intent(in) :: cp  !< Code point.
   logical                    :: yes !< East Asian.

   yes = .false.
   if (cp < 4352_int32) return
   yes = in_ranges(EAST_ASIANS, cp)
   if (.not. yes) yes = (cp >= 13312_int32 .and. cp <= 19903_int32) .or. (cp >= 19968_int32 .and. cp <= 40959_int32)
   endfunction cp_is_east_asian

   pure function cp_glyph_width(cp) result(w)
   !< `CodePoint::getGlyphWidth`: the columns of a glyph, 1 or 2.
   integer(int32), intent(in) :: cp !< Code point.
   integer(int32)             :: w  !< Columns.
   logical                    :: wide !< Two columns.

   w = 1_int32
   if (cp < 4352_int32) return
   wide = in_ranges(WIDE_GLYPHS, cp)
   if (.not. wide) wide = (cp >= 13312_int32 .and. cp <= 19903_int32) .or. (cp >= 19968_int32 .and. cp <= 40959_int32)
   if (wide) w = 2_int32
   endfunction cp_glyph_width

   pure function cp_to_upper(cp) result(u)
   !< `CodePoint::toUpper`.
   integer(int32), intent(in) :: cp !< Code point.
   integer(int32)             :: u  !< Its upper case.
   integer(int32)             :: k  !< Case range.

   u = cp
   if (cp < 127_int32) then
      if (cp >= 97_int32 .and. cp <= 122_int32) u = iand(cp, 95_int32)
      return
   endif
   k = case_range(cp)
   if (k == 0_int32) return
   if (CASES(4 * k - 1) == 0_int32) return
   if (CASES(4 * k - 1) == 65535_int32) then
      u = iand(cp, 65534_int32)
   else
      u = modulo(cp + CASES(4 * k - 1), 65536_int32)
   endif
   endfunction cp_to_upper

   pure function cp_to_lower(cp) result(l)
   !< `CodePoint::toLower`.
   integer(int32), intent(in) :: cp !< Code point.
   integer(int32)             :: l  !< Its lower case.
   integer(int32)             :: k  !< Case range.

   l = cp
   if (cp < 127_int32) then
      if (cp >= 65_int32 .and. cp <= 90_int32) l = ior(cp, 32_int32)
      return
   endif
   k = case_range(cp)
   if (k == 0_int32) return
   if (CASES(4 * k) == 0_int32) return
   if (CASES(4 * k) == 65535_int32) then
      l = ior(cp, 1_int32)
   else
      l = modulo(cp + CASES(4 * k), 65536_int32)
   endif
   endfunction cp_to_lower

   pure function cp_is_bracket_opener(cp) result(yes)
   !< `{`, `[` or `(`.
   integer(int32), intent(in) :: cp  !< Code point.
   logical                    :: yes !< An opening bracket.

   yes = cp == 123_int32 .or. cp == 91_int32 .or. cp == 40_int32
   endfunction cp_is_bracket_opener

   pure function cp_is_bracket_closer(cp) result(yes)
   !< `}`, `]` or `)`.
   integer(int32), intent(in) :: cp  !< Code point.
   logical                    :: yes !< A closing bracket.

   yes = cp == 125_int32 .or. cp == 93_int32 .or. cp == 41_int32
   endfunction cp_is_bracket_closer

   pure function cp_is_pair_opener(cp) result(yes)
   !< A bracket opener or a quote (`CodePoint::isPairOpener`).
   integer(int32), intent(in) :: cp  !< Code point.
   logical                    :: yes !< Opens a pair.

   yes = cp_is_bracket_opener(cp) .or. cp == 39_int32 .or. cp == 34_int32
   endfunction cp_is_pair_opener

   pure function cp_to_pair_closer(cp) result(c)
   !< `CodePoint::toPairCloser`.
   integer(int32), intent(in) :: cp !< Code point.
   integer(int32)             :: c  !< Its closer (itself for others).

   select case (cp)
   case (123_int32)
      c = 125_int32
   case (91_int32)
      c = 93_int32
   case (40_int32)
      c = 41_int32
   case default
      c = cp
   endselect
   endfunction cp_to_pair_closer

   pure function cp_to_pair_opener(cp) result(o)
   !< `CodePoint::toPairOpener`.
   integer(int32), intent(in) :: cp !< Code point.
   integer(int32)             :: o  !< Its opener (itself for others).

   select case (cp)
   case (125_int32)
      o = 123_int32
   case (93_int32)
      o = 91_int32
   case (41_int32)
      o = 40_int32
   case default
      o = cp
   endselect
   endfunction cp_to_pair_opener
endmodule figure_code_unicode
