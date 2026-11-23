!< figure_plot_format, the plot frame's labels written without an allocation: C's printf of one real, integers, text.
module figure_plot_format
!< figure_plot_format, the plot frame's labels written without an allocation: C's printf of one real, integers, text.
!<
!< szaghi/figure#15 P10, step 9 (ADR 0001: no allocation per item per frame in the plot frame). Every label the frame
!< draws on every frame (ticks, the colour bar's ticks, dates, the mouse text) is written here into a caller's buffer:
!< each routine appends at `n` (the characters in use, updated) and drops what does not fit (as `snprintf` into
!< ImPlot's `IMPLOT_LABEL_MAX_SIZE` buffers: pass the buffer's first 31 characters for ImPlot's 32 bytes).
!<
!< - `fmt_parse`: a printf format of one real (`Formatter_Default`'s `fmt`; `SetupAxisFormat`, `ColormapScale`'s
!<   label format), parsed once into a `plot_format`: the text before and after the one conversion (`%%` resolved, 32
!<   characters each at most), its flags (`-+ 0#`), width and precision (any digits, read up to 10^8) and type
!<   (`f F e E g G a A`). A format without conversion is text (`text`: printed as it is, as printf ignores the value);
!<   a format it cannot read is `ok = .false.` and labels as "%g". A precision past 1080 is
!<   computed as 1080 (a double's exact expansion ends before: only zeros follow, kept out of the buffers but counted
!<   in the width).
!< - `fmt_real`: the real through a `plot_format`, glibc's output: the conversion from the exact binary value (a double
!<   is m 2^k: its decimal expansion, at most 767 significant digits, in base 10^9 limbs of a fixed work array),
!<   rounded half to even; "inf", "nan" (upper case for `F E G`), the sign of a zero or a NaN kept (as foresight's
!<   `c_real`, whose output it reproduces with fixed buffers instead of deferred-length strings). The value is read
!<   from its bits (sign, exponent, mantissa): subnormals too where the compiler flushes them to zero (nvfortran without
!<   -Kieee). `fmt_g` is "%g". Checked equal to glibc's `snprintf` (32 bytes) on 10^6 doubles (any bits, tick-like
!<   values, decimal ties) and the specials (zeros, inf, NaN, subnormals) in 22 formats, on gfortran, nvfortran, ifx.
!<   `%a` (`A`) as glibc's `printf_fphex`: "0x", the leading digit (1, 0 for zero and subnormals, whose exponent is
!<   -1022), the 13 hexadecimal digits of the mantissa without their trailing zeros (or `prec` of them, rounded half
!<   to even on the bits dropped, a carry raising the leading digit to 2), "p" and the binary exponent in decimal; the
!<   zero padding after the "0x".
!< - `fmt_int`: an integer, zero-padded to a number of digits (`%02d`, `%03d`, `%d`); `fmt_text`: a text.
!<
!< Rejected: Fortran's internal `write` (ties rounded as the processor chooses where glibc rounds half to even, and a
!< run-time that may allocate its internal unit); C's `snprintf` (variadic: not callable through `bind(C)`).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64

implicit none
private
public :: plot_format, fmt_parse, fmt_real, fmt_g, fmt_int, fmt_text, fmt_repeat
public :: FMT_AFFIX_LEN

integer(int32), parameter :: FMT_AFFIX_LEN = 32_int32   !< A format's text before or after its conversion, at most.
integer(int64), parameter :: LIMB = 1000000000_int64    !< Base of the exact decimal expansion.
integer(int32), parameter :: LIMB_ROOM = 130_int32         !< Limbs of a double's expansion (767 digits: 86), and room.
integer(int32), parameter :: DIGITS_LEN = 800_int32     !< Significant digits of a double, at most 767.
integer(int32), parameter :: PREC_CAP = 1080_int32      !< Precision computed at most: past it (a double's fraction has
                                                        !< 1074 digits at most, its expansion 767 significant ones)
                                                        !< only zeros follow, counted, not written.
integer(int32), parameter :: NUM_CAP = 100000000_int32  !< A width or precision read at most (C's int beyond).
integer(int32), parameter :: BODY_LEN = 1536_int32      !< A number's text (%.1080f of 1.8e308: 1390 characters).

type :: plot_format
   !< A printf format of one real, parsed (`%[flags][width][.prec]type` between two texts).
   character(len=FMT_AFFIX_LEN) :: prefix = ''        !< Text before the conversion.
   integer(int32)               :: prefix_len = 0_int32 !< ... its length.
   character(len=FMT_AFFIX_LEN) :: suffix = ''        !< Text after it.
   integer(int32)               :: suffix_len = 0_int32 !< ... its length.
   logical                      :: minus = .false.    !< Flag `-`: left-justified.
   logical                      :: plus = .false.     !< Flag `+`: a sign always.
   logical                      :: space = .false.    !< Flag ` `: a blank for a positive sign.
   logical                      :: zero = .false.     !< Flag `0`: zero-padded.
   logical                      :: alt = .false.      !< Flag `#`: the point always.
   integer(int32)               :: width = 0_int32    !< Field width (0: none).
   integer(int32)               :: prec = -1_int32    !< Precision (-1: absent, 6).
   character(len=1)             :: ctype = 'g'        !< Conversion: f F e E g G.
   logical                      :: ok = .true.        !< Read (else "%g").
   logical                      :: text = .false.     !< No conversion: the text alone (`prefix`, `%%` resolved).
endtype plot_format

contains
   ! the format

   pure subroutine fmt_parse(text, f)
   !< A printf format of one real parsed (`ok` false, and "%g", if it has no conversion, two, or one not of a real).
   character(len=*),  intent(in)  :: text !< Format.
   type(plot_format), intent(out) :: f    !< Parsed.
   integer(int32)                 :: i, m    !< Position, length.
   logical                        :: found   !< The conversion read.

   found = .false.
   m = len(text, kind=int32)
   i = 1_int32
   do while (i <= m)
      if (text(i:i) /= '%') then
         call affix_to(f, found, text(i:i))
         i = i + 1_int32
         cycle
      endif
      if (i < m) then
         if (text(i + 1_int32:i + 1_int32) == '%') then ! '%%'
            call affix_to(f, found, '%')
            i = i + 2_int32
            cycle
         endif
      endif
      if (found .or. i == m) then ! a second conversion, or a '%' at the end
         call fail(f)
         return
      endif
      found = .true.
      i = i + 1_int32
      do while (i <= m)
         select case (text(i:i))
         case ('-')
            f%minus = .true.
         case ('+')
            f%plus = .true.
         case (' ')
            f%space = .true.
         case ('0')
            f%zero = .true.
         case ('#')
            f%alt = .true.
         case default
            exit
         endselect
         i = i + 1_int32
      enddo
      f%width = 0_int32
      do while (i <= m)
         if (scan(text(i:i), '0123456789') == 0) exit
         f%width = min(10_int32 * f%width + (iachar(text(i:i)) - iachar('0')), NUM_CAP)
         i = i + 1_int32
      enddo
      if (i <= m) then
         if (text(i:i) == '.') then
            i = i + 1_int32
            f%prec = 0_int32
            do while (i <= m)
               if (scan(text(i:i), '0123456789') == 0) exit
               f%prec = min(10_int32 * f%prec + (iachar(text(i:i)) - iachar('0')), NUM_CAP)
               i = i + 1_int32
            enddo
         endif
      endif
      if (i > m) then
         call fail(f)
         return
      endif
      if (scan(text(i:i), 'fFeEgGaA') == 0) then
         call fail(f)
         return
      endif
      f%ctype = text(i:i)
      i = i + 1_int32
   enddo
   if (.not. found) f%text = .true. ! printf prints the text and ignores the value
   endsubroutine fmt_parse

   pure subroutine affix_to(f, after, c)
   !< A character of the text before the conversion, or after it.
   type(plot_format), intent(inout) :: f     !< Format.
   logical,           intent(in)    :: after !< After the conversion.
   character(len=1),  intent(in)    :: c     !< Character.

   if (after) then
      call affix(f%suffix, f%suffix_len, c)
   else
      call affix(f%prefix, f%prefix_len, c)
   endif
   endsubroutine affix_to

   pure subroutine affix(s, n, c)
   !< A character appended to a format's text (dropped past its room).
   character(len=*), intent(inout) :: s !< Text.
   integer(int32),   intent(inout) :: n !< Its length.
   character(len=1), intent(in)    :: c !< Character.

   if (n >= len(s, kind=int32)) return
   n = n + 1_int32
   s(n:n) = c
   endsubroutine affix

   pure subroutine fail(f)
   !< A format not read: "%g".
   type(plot_format), intent(inout) :: f !< Format.

   f = plot_format()
   f%ok = .false.
   endsubroutine fail

   ! appending

   pure subroutine fmt_text(buf, n, s)
   !< A text appended.
   character(len=*), intent(inout) :: buf !< Buffer.
   integer(int32),   intent(inout) :: n   !< Characters in use.
   character(len=*), intent(in)    :: s   !< Text.
   integer(int32)                  :: k   !< Characters that fit.

   k = min(len(s, kind=int32), len(buf, kind=int32) - n)
   if (k <= 0_int32) return
   buf(n + 1_int32:n + k) = s(1:k)
   n = n + k
   endsubroutine fmt_text

   pure subroutine fmt_repeat(buf, n, c, m)
   !< `m` copies of a character appended.
   character(len=*), intent(inout) :: buf !< Buffer.
   integer(int32),   intent(inout) :: n   !< Characters in use.
   character(len=1), intent(in)    :: c   !< Character.
   integer(int32),   intent(in)    :: m   !< Copies.
   integer(int32)                  :: k   !< Counter.

   do k = 1_int32, min(m, len(buf, kind=int32) - n) ! (what does not fit dropped)
      call fmt_text(buf, n, c)
   enddo
   endsubroutine fmt_repeat

   pure subroutine fmt_int(buf, n, v, digits)
   !< An integer appended, its magnitude zero-padded to `digits` digits (default 1: `%d`).
   character(len=*), intent(inout)        :: buf    !< Buffer.
   integer(int32),   intent(inout)        :: n      !< Characters in use.
   integer(int32),   intent(in)           :: v      !< Value.
   integer(int32),   intent(in), optional :: digits !< Digits at least.
   character(len=12)                      :: d      !< Digits, right-aligned.
   integer(int64)                         :: a      !< Magnitude.
   integer(int32)                         :: k, m   !< Position, digits wanted.

   m = 1_int32
   if (present(digits)) m = max(1_int32, min(10_int32, digits))
   a = abs(int(v, int64))
   k = len(d, kind=int32)
   do
      d(k:k) = achar(iachar('0') + int(mod(a, 10_int64), int32))
      a = a / 10_int64
      k = k - 1_int32
      if (a == 0_int64 .and. len(d, kind=int32) - k >= m) exit
   enddo
   if (v < 0_int32) call fmt_text(buf, n, '-')
   call fmt_text(buf, n, d(k + 1_int32:))
   endsubroutine fmt_int

   pure subroutine fmt_g(buf, n, v)
   !< A real appended as "%g".
   character(len=*), intent(inout) :: buf !< Buffer.
   integer(int32),   intent(inout) :: n   !< Characters in use.
   real(real64),     intent(in)    :: v   !< Value.
   type(plot_format)               :: f   !< "%g".

   call fmt_real(buf, n, f, v)
   endsubroutine fmt_g

   pure subroutine fmt_real(buf, n, f, v)
   !< A real appended through a parsed format: its prefix, the conversion (glibc's), its suffix.
   character(len=*),  intent(inout) :: buf  !< Buffer.
   integer(int32),    intent(inout) :: n    !< Characters in use.
   type(plot_format), intent(in)    :: f    !< Format.
   real(real64),      intent(in)    :: v    !< Value.
   character(len=DIGITS_LEN)        :: dg   !< Exact significant digits of |v|.
   character(len=BODY_LEN)          :: body !< The number without its sign.
   character(len=3)                 :: lead !< Sign and, for `%a`, "0x" (`lead(1:nl)`).
   integer(int32)                   :: nd, e, nb, nl, p, x, gap !< Digits, exponent, lengths, precision, padding.
   integer(int32)                   :: extra !< Zeros past PREC_CAP, counted in the width, not written.
   logical                          :: upper, finite !< Upper case, a finite value.
   integer(int64)                   :: bits !< The value's bits.

   call fmt_text(buf, n, f%prefix(1:f%prefix_len))
   if (f%text) return
   upper = scan(f%ctype, 'FEGA') > 0
   nl = 0_int32
   lead = ' '
   bits = transfer(v, 0_int64) ! the value read from its bits: the sign of a zero or a NaN, subnormals under DAZ
   if (btest(bits, 63)) then
      lead(1:1) = '-'
      nl = 1_int32
   elseif (f%plus) then
      lead(1:1) = '+'
      nl = 1_int32
   elseif (f%space) then
      lead(1:1) = ' '
      nl = 1_int32
   endif
   finite = ibits(bits, 52, 11) /= 2047_int64
   nb = 0_int32
   extra = 0_int32
   if (f%prec > PREC_CAP .and. finite .and. (scan(f%ctype, 'gG') == 0 .or. f%alt)) extra = f%prec - PREC_CAP
   if (.not. finite) then
      if (ibits(bits, 0, 52) /= 0_int64) then
         call put(body, nb, merge('NAN', 'nan', upper))
      else
         call put(body, nb, merge('INF', 'inf', upper))
      endif
   elseif (scan(f%ctype, 'aA') > 0) then
      call hex_text(bits, min(f%prec, PREC_CAP), f%alt, upper, body, nb)
      lead(nl + 1_int32:nl + 2_int32) = merge('0X', '0x', upper)
      nl = nl + 2_int32
   else
      call exact_digits(v, dg, nd, e)
      p = min(f%prec, PREC_CAP)
      if (p < 0_int32) p = 6_int32
      select case (f%ctype)
      case ('f', 'F')
         call fixed_text(dg, nd, e, p, body, nb)
         if (f%alt .and. p == 0_int32) call put(body, nb, '.')
      case ('e', 'E')
         call exp_text(dg, nd, e, p, body, nb, x)
         if (f%alt .and. p == 0_int32) call put(body, nb, '.')
         call exponent_text(merge('E', 'e', upper), x, body, nb)
      case default ! g, G: precision in significant digits, the fixed form when the exponent is in [-4, p)
         if (p == 0_int32) p = 1_int32
         call exp_text(dg, nd, e, p - 1_int32, body, nb, x)
         if (x < p .and. x >= -4_int32) then
            nb = 0_int32
            call fixed_text(dg, nd, e, p - 1_int32 - x, body, nb)
            call trailing(body, nb, f%alt)
         else
            ! glibc (2.39): `#` with a value whose rounding up to the next power of ten made the exponent p (the fixed
            ! form's, before the rounding) keeps no zeros: "%#g" of 999999.5 is "1.e+06"
            if (f%alt .and. x == p .and. x /= nd - 1_int32 + e) nb = 1_int32
            call trailing(body, nb, f%alt)
            call exponent_text(merge('E', 'e', upper), x, body, nb)
         endif
      endselect
   endif
   gap = f%width - nl - nb - extra
   if (gap > 0_int32 .and. f%minus) then
      if (nl > 0_int32) call fmt_text(buf, n, lead(1:nl))
      call fmt_text(buf, n, body(1:nb))
      call fmt_repeat(buf, n, ' ', gap)
   elseif (gap > 0_int32 .and. f%zero .and. finite) then
      if (nl > 0_int32) call fmt_text(buf, n, lead(1:nl))
      call fmt_repeat(buf, n, '0', gap)
      call fmt_text(buf, n, body(1:nb))
   else
      if (gap > 0_int32) call fmt_repeat(buf, n, ' ', gap)
      if (nl > 0_int32) call fmt_text(buf, n, lead(1:nl))
      call fmt_text(buf, n, body(1:nb))
   endif
   call fmt_text(buf, n, f%suffix(1:f%suffix_len))
   endsubroutine fmt_real

   ! the conversion

   pure subroutine hex_text(bits, prec, alt, upper, body, nb)
   !< `%a` of the finite double of these bits, without its sign and its "0x" (glibc's `__printf_fphex`): the leading
   !< digit, the point (with digits, or `#`), the mantissa's hexadecimal digits (all but the trailing zeros, or `prec`
   !< of them rounded half to even), "p", the exponent's sign and its decimal digits; upper case for `%A`.
   integer(int64),   intent(in)    :: bits  !< The value's bits.
   integer(int32),   intent(in)    :: prec  !< Precision (-1: absent).
   logical,          intent(in)    :: alt   !< Flag `#`: the point always.
   logical,          intent(in)    :: upper !< `%A`.
   character(len=*), intent(inout) :: body  !< Text.
   integer(int32),   intent(inout) :: nb    !< Its length.
   character(len=16), parameter    :: HEX = '0123456789abcdef' !< The digits.
   character(len=13)               :: hd    !< The mantissa's digits.
   character(len=1)                :: lead  !< The leading digit.
   integer(int64)                  :: m     !< The mantissa's bits.
   integer(int32)                  :: be, x, nh, p, k, d, last, next, n0 !< Biased and binary exponents, counters.
   logical                         :: up, more !< Round up, bits after the half.

   m = ibits(bits, 0, 52)
   be = int(ibits(bits, 52, 11), int32)
   do k = 1_int32, 13_int32
      d = int(ibits(m, 4 * (13 - k), 4), int32)
      hd(k:k) = HEX(d + 1_int32:d + 1_int32)
   enddo
   if (be == 0_int32) then ! zero (exponent 0), or a subnormal (-1022)
      lead = '0'
      x = merge(0_int32, -1022_int32, m == 0_int64)
   else
      lead = '1'
      x = be - 1023_int32
   endif
   nh = 13_int32 ! the trailing zeros dropped
   do while (nh > 0_int32)
      if (hd(nh:nh) /= '0') exit
      nh = nh - 1_int32
   enddo
   p = prec
   if (p < 0_int32) then
      p = nh
   elseif (p < nh) then ! round_away to nearest: a half and (an odd last digit or more bits)
      if (p > 0_int32) then
         last = index(HEX, hd(p:p)) - 1_int32
      else
         last = index(HEX, lead) - 1_int32
      endif
      next = index(HEX, hd(p + 1_int32:p + 1_int32)) - 1_int32
      more = iand(next, 7_int32) /= 0_int32 .or. p + 1_int32 < nh
      up = next >= 8_int32 .and. (iand(last, 1_int32) /= 0_int32 .or. more)
      if (up) then
         k = p
         do while (k >= 1_int32)
            d = index(HEX, hd(k:k)) - 1_int32
            if (d < 15_int32) then
               hd(k:k) = HEX(d + 2_int32:d + 2_int32)
               exit
            endif
            hd(k:k) = '0'
            k = k - 1_int32
         enddo
         if (k == 0_int32) lead = achar(iachar(lead) + 1) ! 0 -> 1, 1 -> 2 (a double's leading digit)
      endif
   endif
   n0 = nb
   call put(body, nb, lead)
   if (p > 0_int32 .or. alt) call put(body, nb, '.')
   if (p > 0_int32) then
      call put(body, nb, hd(1:min(nh, p)))
      do k = nh + 1_int32, p
         call put(body, nb, '0')
      enddo
   endif
   call put(body, nb, 'p')
   call put(body, nb, merge('-', '+', x < 0_int32))
   call fmt_int(body, nb, abs(x))
   if (upper) then
      do k = n0 + 1_int32, nb
         if (body(k:k) >= 'a' .and. body(k:k) <= 'z') body(k:k) = achar(iachar(body(k:k)) - 32)
      enddo
   endif
   endsubroutine hex_text

   pure subroutine exact_digits(v, dg, nd, e)
   !< The exact decimal value of the finite v: |v| = dg(1:nd) 10^e, `dg` without leading or trailing zeros ('0' for
   !< zero). A double is m 2^k, that is m 5^(-k) 10^k when k < 0: the product computed exactly in base 10^9 limbs.
   real(real64),     intent(in)  :: v   !< Value.
   character(len=*), intent(out) :: dg  !< Digits.
   integer(int32),   intent(out) :: nd  !< Their count.
   integer(int32),   intent(out) :: e   !< Decimal exponent.
   integer(int64)                :: limbs(LIMB_ROOM) !< Base 10^9 digits, least significant first.
   integer(int64)                :: m, q, bits !< Binary mantissa, a limb, the value's bits.
   integer(int32)                :: k, nl, step, i, j, d !< Binary exponent, limbs in use, counters.

   e = 0_int32
   bits = transfer(v, 0_int64)
   m = ibits(bits, 0, 52)
   k = int(ibits(bits, 52, 11), int32)
   if (k == 0_int32 .and. m == 0_int64) then
      dg(1:1) = '0'
      nd = 1_int32
      return
   endif
   if (k == 0_int32) then ! subnormal
      k = -1074_int32
   else
      m = m + 4503599627370496_int64 ! 2^52
      k = k - 1075_int32
   endif
   do while (k < 0_int32 .and. modulo(m, 2_int64) == 0_int64)
      m = m / 2_int64
      k = k + 1_int32
   enddo
   limbs = 0_int64
   limbs(1) = modulo(m, LIMB)
   limbs(2) = modulo(m / LIMB, LIMB)
   limbs(3) = m / (LIMB * LIMB)
   nl = 3_int32
   if (k >= 0_int32) then
      do while (k > 0_int32)
         step = min(k, 30_int32)
         call limbs_multiply(limbs, nl, 2_int64**step)
         k = k - step
      enddo
   else
      e = k
      k = -k
      do while (k > 0_int32)
         step = min(k, 13_int32)
         call limbs_multiply(limbs, nl, 5_int64**step)
         k = k - step
      enddo
   endif
   do while (nl > 1_int32 .and. limbs(nl) == 0_int64)
      nl = nl - 1_int32
   enddo
   ! the top limb without its leading zeros, the others nine digits each
   nd = 0_int32
   q = limbs(nl)
   d = 0_int32
   do while (q > 0_int64)
      d = d + 1_int32
      q = q / 10_int64
   enddo
   q = limbs(nl)
   do j = d, 1_int32, -1_int32
      dg(j:j) = achar(iachar('0') + int(mod(q, 10_int64), int32))
      q = q / 10_int64
   enddo
   nd = d
   do i = nl - 1_int32, 1_int32, -1_int32
      q = limbs(i)
      do j = nd + 9_int32, nd + 1_int32, -1_int32
         dg(j:j) = achar(iachar('0') + int(mod(q, 10_int64), int32))
         q = q / 10_int64
      enddo
      nd = nd + 9_int32
   enddo
   do while (nd > 1_int32 .and. dg(nd:nd) == '0')
      nd = nd - 1_int32
      e = e + 1_int32
   enddo
   endsubroutine exact_digits

   pure subroutine limbs_multiply(limbs, nl, f)
   !< limbs(1:nl) times f (base 10^9, least significant first; f below 2^31), nl grown with the carry.
   integer(int64), intent(inout) :: limbs(:) !< Digits.
   integer(int32), intent(inout) :: nl       !< Limbs in use.
   integer(int64), intent(in)    :: f        !< Factor.
   integer(int64)                :: carry, p !< Carry, partial product.
   integer(int32)                :: j        !< Counter.

   carry = 0_int64
   do j = 1_int32, nl
      p = limbs(j) * f
      p = p + carry
      limbs(j) = modulo(p, LIMB)
      carry = p / LIMB
   enddo
   do while (carry > 0_int64)
      nl = nl + 1_int32
      limbs(nl) = modulo(carry, LIMB)
      carry = carry / LIMB
   enddo
   endsubroutine limbs_multiply

   pure subroutine round_keep(dg, nd, keep, r, nr)
   !< dg(1:nd) rounded half to even to its first `keep` digits (`keep` > nd: zeros appended; `keep` <= 0: 0 or 1),
   !< as an integer without leading zeros ('0' for zero): r(1:nr).
   character(len=*), intent(in)  :: dg   !< Digits (no leading zero, unless '0').
   integer(int32),   intent(in)  :: nd   !< Their count.
   integer(int32),   intent(in)  :: keep !< Digits kept.
   character(len=*), intent(out) :: r    !< Rounded digits.
   integer(int32),   intent(out) :: nr   !< Their count.
   integer(int32)                :: k, i !< Counters.
   logical                       :: up   !< Round up.

   if (keep <= 0_int32) then ! below 0.1 units: 0; in [0.1, 1): 1 above a half (a half alone: 0, even)
      up = keep == 0_int32 .and. (dg(1:1) > '5' .or. (dg(1:1) == '5' .and. nd > 1_int32))
      r(1:1) = merge('1', '0', up)
      nr = 1_int32
      return
   endif
   if (keep >= nd) then
      r(1:nd) = dg(1:nd)
      do k = nd + 1_int32, keep
         r(k:k) = '0'
      enddo
      nr = keep
   else
      r(1:keep) = dg(1:keep)
      nr = keep
      if (dg(keep + 1_int32:keep + 1_int32) > '5') then
         up = .true.
      elseif (dg(keep + 1_int32:keep + 1_int32) < '5') then
         up = .false.
      elseif (nd > keep + 1_int32) then ! digits after the 5 (no trailing zeros: one of them is not 0)
         up = .true.
      else
         up = scan(dg(keep:keep), '13579') > 0
      endif
      if (up) then
         k = keep
         do while (k >= 1_int32)
            if (r(k:k) /= '9') exit
            r(k:k) = '0'
            k = k - 1_int32
         enddo
         if (k == 0_int32) then ! 99..9 up: 100..0
            r(1:1) = '1'
            do k = 2_int32, keep + 1_int32
               r(k:k) = '0'
            enddo
            nr = keep + 1_int32
         else
            r(k:k) = achar(iachar(r(k:k)) + 1)
         endif
      endif
   endif
   k = 1_int32 ! leading zeros (of zero itself)
   do while (k < nr .and. r(k:k) == '0')
      k = k + 1_int32
   enddo
   if (k > 1_int32) then
      do i = k, nr
         r(i - k + 1_int32:i - k + 1_int32) = r(i:i)
      enddo
      nr = nr - k + 1_int32
   endif
   endsubroutine round_keep

   pure subroutine fixed_text(dg, nd, e, prec, body, nb)
   !< dg 10^e with `prec` decimals (`%.<prec>f`), appended to body(1:nb).
   character(len=*), intent(in)    :: dg   !< Digits.
   integer(int32),   intent(in)    :: nd   !< Their count.
   integer(int32),   intent(in)    :: e    !< Exponent.
   integer(int32),   intent(in)    :: prec !< Decimals.
   character(len=*), intent(inout) :: body !< Text.
   integer(int32),   intent(inout) :: nb   !< Its length.
   character(len=BODY_LEN)         :: u    !< The value in units of 10^-prec.
   integer(int32)                  :: nu, z, k !< Its digits, zeros put before them, counter.

   if (dg(1:1) == '0') then
      u(1:1) = '0'
      nu = 1_int32
   else
      call round_keep(dg, nd, nd + e + prec, u, nu)
   endif
   z = prec + 1_int32 - nu ! one digit before the point at least: zeros before the digits
   if (z > 0_int32) then
      do k = nu, 1_int32, -1_int32
         u(k + z:k + z) = u(k:k)
      enddo
      do k = 1_int32, z
         u(k:k) = '0'
      enddo
      nu = nu + z
   endif
   call put(body, nb, u(1:nu - prec))
   if (prec > 0_int32) then
      call put(body, nb, '.')
      call put(body, nb, u(nu - prec + 1_int32:nu))
   endif
   endsubroutine fixed_text

   pure subroutine exp_text(dg, nd, e, prec, body, nb, x)
   !< The mantissa of dg 10^e in exponent form with `prec` decimals (`%.<prec>e`) appended to body(1:nb), and its
   !< exponent x.
   character(len=*), intent(in)    :: dg   !< Digits.
   integer(int32),   intent(in)    :: nd   !< Their count.
   integer(int32),   intent(in)    :: e    !< Exponent.
   integer(int32),   intent(in)    :: prec !< Decimals.
   character(len=*), intent(inout) :: body !< Text.
   integer(int32),   intent(inout) :: nb   !< Its length.
   integer(int32),   intent(out)   :: x    !< Exponent of the leading digit.
   character(len=BODY_LEN)         :: kept !< Significant digits kept.
   integer(int32)                  :: nk   !< Their count.

   if (dg(1:1) == '0') then
      do nk = 1_int32, prec + 1_int32
         kept(nk:nk) = '0'
      enddo
      x = 0_int32
   else
      x = nd - 1_int32 + e
      call round_keep(dg, nd, prec + 1_int32, kept, nk)
      if (nk > prec + 1_int32) x = x + 1_int32 ! rounded up to the next power of ten (its trailing zero dropped)
   endif
   call put(body, nb, kept(1:1))
   if (prec > 0_int32) then
      call put(body, nb, '.')
      call put(body, nb, kept(2:prec + 1_int32))
   endif
   endsubroutine exp_text

   pure subroutine exponent_text(letter, x, body, nb)
   !< C's exponent appended: the letter, the sign, two digits at least.
   character(len=1), intent(in)    :: letter !< 'e' or 'E'.
   integer(int32),   intent(in)    :: x      !< Exponent.
   character(len=*), intent(inout) :: body   !< Text.
   integer(int32),   intent(inout) :: nb     !< Its length.

   call put(body, nb, letter)
   call put(body, nb, merge('-', '+', x < 0_int32))
   call fmt_int(body, nb, abs(x), 2_int32)
   endsubroutine exponent_text

   pure subroutine trailing(body, nb, alt)
   !< `%g`'s end of a number: the fraction's trailing zeros and a bare point removed; with `#`, a point always.
   character(len=*), intent(inout) :: body !< Text.
   integer(int32),   intent(inout) :: nb   !< Its length.
   logical,          intent(in)    :: alt  !< Flag `#`.

   if (alt) then
      if (index(body(1:nb), '.') == 0) call put(body, nb, '.')
      return
   endif
   if (index(body(1:nb), '.') == 0) return
   do while (body(nb:nb) == '0')
      nb = nb - 1_int32
   enddo
   if (body(nb:nb) == '.') nb = nb - 1_int32
   endsubroutine trailing

   pure subroutine put(s, n, t)
   !< A text appended to a work buffer (its room is enough by construction).
   character(len=*), intent(inout) :: s !< Buffer.
   integer(int32),   intent(inout) :: n !< Characters in use.
   character(len=*), intent(in)    :: t !< Text.

   s(n + 1_int32:n + len(t, kind=int32)) = t
   n = n + len(t, kind=int32)
   endsubroutine put
endmodule figure_plot_format
