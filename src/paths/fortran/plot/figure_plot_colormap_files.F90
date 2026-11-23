!< figure_plot_colormap_files, the plot frame's user colormaps read from files: CSV tables and ParaView JSON presets.
module figure_plot_colormap_files
!< figure_plot_colormap_files, the plot frame's user colormaps read from files: CSV tables and ParaView JSON presets.
!<
!< szaghi/figure#15 P10 (what P10-P12 left, night 2026-11-23 step 06). What FIGURE's `fig_load_colormap`
!< (native/figure_colormap.cpp: `parse_csv`, `parse_paraview`, its JSON reader and colour spaces) makes of a file, the
!< same table to the bit and the same messages:
!<
!< - `cmf_csv`: one colour a row, "r, g, b" (or "x, r, g, b": x a position, the table resampled at 256 uniform
!<   positions, linearly), the numbers separated by commas, semicolons, blanks or tabs, `#` comments, a first line that
!<   is not numeric a header; components in [0, 1], or in [0, 255] when one exceeds 1 (then divided by 255); at least
!<   2 rows, at most 65536;
!< - `cmf_paraview`: a JSON object or an array of them (ParaView's "Export"), the one whose `Name` is the map's name
!<   (the last such), or the only one; its `RGBPoints` (x, r, g, b, ...) sampled at 256 uniform positions in its
!<   `ColorSpace`: RGB, Lab (and Lab/CIEDE2000, CIELAB: interpolated in CIELAB, D65, as VTK's vtkMath), Diverging
!<   (Moreland's Msh with its white middle and hue spin, as vtkColorTransferFunction), HSV (the shorter way round the
!<   hue) or Step.
!<
!< Numbers are read by the C library's `strtod` (bound: the digits C reads, hexadecimal and "inf" included); `pow`,
!< `cbrt`, `acos`, `atan2`, `cos`, `sin`, `fmod` are the C library's as the native code calls them; each sum of
!< products is written term by term in statements of their own (no FMA). This is FIGURE's own C++ ported, not a new
!< parser of outside data (ADR 0001 K1; proposed K10, the owner's to confirm). Run once per file, not per frame: it
!< allocates freely.
use, intrinsic :: iso_c_binding, only : c_char, c_double, c_intptr_t, c_loc, c_null_char, c_ptr
use, intrinsic :: iso_fortran_env, only : int32, int64, real64

implicit none
private
public :: cmf_csv, cmf_paraview, cmf_resample, CMF_SAMPLES, CMF_MAX_ROWS

integer(int32), parameter :: CMF_SAMPLES = 256_int32    !< Samples of a map given by positions.
integer(int32), parameter :: CMF_MAX_ROWS = 65536_int32 !< Rows of a user table at most.
real(real64),   parameter :: PI = 3.14159265358979323846_real64 !< Pi.
real(real64),   parameter :: WX = 0.9505_real64, WY = 1.0_real64, WZ = 1.089_real64 !< D65's white.
! the JSON values' kinds
integer(int32), parameter :: J_NUL = 0_int32, J_BOOL = 1_int32, J_NUMBER = 2_int32, J_STRING = 3_int32, &
                             J_ARRAY = 4_int32, J_OBJECT = 5_int32 !< Kinds.

type :: json_doc
   !< A JSON document as a table of nodes: an array's items and an object's members are a node's children (first,
   !< next sibling); a member's name and a string's text in `txt`.
   integer(int32),   allocatable :: kind(:)       !< A node's kind.
   real(real64),     allocatable :: num(:)        !< ... its number.
   integer(int32),   allocatable :: str_off(:)    !< ... its string's start in `txt`.
   integer(int32),   allocatable :: str_len(:)    !< ... its length.
   integer(int32),   allocatable :: key_off(:)    !< ... its member name's start (an object's member).
   integer(int32),   allocatable :: key_len(:)    !< ... its length.
   integer(int32),   allocatable :: first(:)      !< ... its first child (0: none).
   integer(int32),   allocatable :: last(:)       !< ... its last child.
   integer(int32),   allocatable :: next(:)       !< ... its next sibling (0: none).
   integer(int32)                :: n = 0_int32   !< Nodes.
   character(len=:), allocatable :: txt           !< Strings, unescaped.
   integer(int32)                :: n_txt = 0_int32 !< Characters in use.
endtype json_doc

interface
   function c_strtod(s, endp) result(v) bind(C, name='strtod')
   !< C's `strtod`.
   import :: c_double, c_ptr, c_char
   implicit none
   character(kind=c_char), intent(in) :: s(*) !< Text, NUL-terminated.
   type(c_ptr),            intent(out) :: endp !< Where the number ends.
   real(c_double)                     :: v    !< Value.
   endfunction c_strtod

   pure function c_pow(x, y) result(r) bind(C, name='pow')
   !< C's `pow`.
   import :: c_double
   implicit none
   real(c_double), value :: x, y !< Base, exponent.
   real(c_double)        :: r    !< Power.
   endfunction c_pow

   pure function c_cbrt(x) result(r) bind(C, name='cbrt')
   !< C's `cbrt`.
   import :: c_double
   implicit none
   real(c_double), value :: x !< Value.
   real(c_double)        :: r !< Cube root.
   endfunction c_cbrt

   pure function c_acos(x) result(r) bind(C, name='acos')
   !< C's `acos`.
   import :: c_double
   implicit none
   real(c_double), value :: x !< Value.
   real(c_double)        :: r !< Angle.
   endfunction c_acos

   pure function c_atan2(y, x) result(r) bind(C, name='atan2')
   !< C's `atan2`.
   import :: c_double
   implicit none
   real(c_double), value :: y, x !< Ordinate, abscissa.
   real(c_double)        :: r    !< Angle.
   endfunction c_atan2

   pure function c_cos(x) result(r) bind(C, name='cos')
   !< C's `cos`.
   import :: c_double
   implicit none
   real(c_double), value :: x !< Angle.
   real(c_double)        :: r !< Cosine.
   endfunction c_cos

   pure function c_sin(x) result(r) bind(C, name='sin')
   !< C's `sin`.
   import :: c_double
   implicit none
   real(c_double), value :: x !< Angle.
   real(c_double)        :: r !< Sine.
   endfunction c_sin

   pure function c_fmod(x, y) result(r) bind(C, name='fmod')
   !< C's `fmod`.
   import :: c_double
   implicit none
   real(c_double), value :: x, y !< Dividend, divisor.
   real(c_double)        :: r    !< Remainder.
   endfunction c_fmod
endinterface

contains
   ! numbers

   function number(t, v) result(ok)
   !< `number`: the whole token read by `strtod`, finite.
   character(len=*), intent(in)  :: t  !< Token.
   real(real64),     intent(out) :: v  !< Value.
   logical                       :: ok !< Read.
   character(kind=c_char), allocatable, target :: buf(:) !< The token, NUL-terminated.
   type(c_ptr)                   :: e  !< Where `strtod` stopped.
   integer(int32)                :: k  !< Counter.

   v = 0.0_real64
   ok = .false.
   if (len(t) == 0) return
   allocate(buf(len(t) + 1))
   do k = 1_int32, len(t, kind=int32)
      buf(k) = t(k:k)
   enddo
   buf(len(t) + 1) = c_null_char
   v = c_strtod(buf, e)
   ok = transfer(e, 0_c_intptr_t) - transfer(c_loc(buf(1)), 0_c_intptr_t) == int(len(t), c_intptr_t) .and. &
        abs(v) <= huge(1.0_real64)
   endfunction number

   pure function itoa(i) result(s)
   !< An integer as `std::to_string` writes it.
   integer(int32), intent(in)    :: i !< Value.
   character(len=:), allocatable :: s !< Text.
   character(len=16)             :: b !< Buffer.

   write(b, '(I0)') i
   s = trim(b)
   endfunction itoa

   ! CSV tables

   subroutine cmf_csv(text, where, rows, err)
   !< `parse_csv`: the table of a CSV text; `err` empty when read, else the message (`where` its start).
   character(len=*),              intent(in)  :: text      !< The file's text.
   character(len=*),              intent(in)  :: where     !< `"ip_load_colormap: <file>"`.
   real(real64),     allocatable, intent(out) :: rows(:,:) !< The table (3, n), components in [0, 1].
   character(len=:), allocatable, intent(out) :: err       !< Message ('' when read).
   real(real64),     allocatable :: x(:), c(:,:), more(:,:), xm(:) !< Positions, colours, grown copies.
   integer(int32)                :: nc, columns, line_no, a, b, o, k, ncell, cs(5), ce(5) !< Counters, cells.
   real(real64)                  :: v(4), top      !< A row's numbers, the largest component.
   logical                       :: data, numeric  !< A data row seen, a row of numbers.
   character(len=:), allocatable :: line           !< A line, its separators blanked.

   err = ''
   allocate(x(64), c(3, 64))
   nc = 0_int32
   columns = 0_int32
   line_no = 0_int32
   data = .false.
   a = 1_int32
   do while (a <= len(text, kind=int32))
      b = index(text(a:), achar(10))
      if (b == 0) then
         b = len(text, kind=int32) + 1_int32
      else
         b = a + b - 1_int32
      endif
      line_no = line_no + 1_int32
      line = text(a:b - 1_int32)
      a = b + 1_int32
      k = index(line, '#')
      if (k > 0) line = line(1:k - 1)
      do k = 1_int32, len(line, kind=int32)
         if (scan(line(k:k), ',;'//achar(9)//achar(13)) > 0) line(k:k) = ' '
      enddo
      call cells(line, ncell, cs, ce)
      if (ncell == 0_int32) cycle
      numeric = ncell <= 4_int32
      do k = 1_int32, min(ncell, 4_int32)
         if (.not. numeric) exit
         numeric = number(line(cs(k):ce(k)), v(k))
      enddo
      if (.not. numeric .and. .not. data) then ! the header
         data = .true.
         cycle
      endif
      data = .true.
      if (.not. numeric .or. ncell < 3_int32) then
         err = where//':'//itoa(line_no)//': expected 3 numbers (r, g, b) or 4 (x, r, g, b)'
         return
      endif
      if (columns == 0_int32) columns = ncell
      if (ncell /= columns) then
         err = where//':'//itoa(line_no)//': '//itoa(ncell)//' numbers, the rows above '//itoa(columns)
         return
      endif
      o = columns - 3_int32
      if (nc == size(c, 2, kind=int32)) then
         allocate(more(3, 2_int32 * nc), xm(2_int32 * nc))
         more(:, 1:nc) = c(:, 1:nc)
         xm(1:nc) = x(1:nc)
         call move_alloc(more, c)
         call move_alloc(xm, x)
      endif
      if (o == 1_int32) then
         if (nc > 0_int32) then
            if (v(1) < x(nc)) then
               err = where//':'//itoa(line_no)//': the positions (first column) must not decrease'
               return
            endif
         endif
         x(nc + 1_int32) = v(1)
      endif
      if (v(o + 1_int32) < 0.0_real64 .or. v(o + 2_int32) < 0.0_real64 .or. v(o + 3_int32) < 0.0_real64) then
         err = where//':'//itoa(line_no)//': a negative colour component'
         return
      endif
      nc = nc + 1_int32
      c(:, nc) = v(o + 1_int32:o + 3_int32)
      if (nc > CMF_MAX_ROWS) then
         err = where//': more than '//itoa(CMF_MAX_ROWS)//' rows'
         return
      endif
   enddo
   if (nc < 2_int32) then
      err = where//': a colormap needs at least 2 colours, found '//itoa(nc)
      return
   endif
   top = 0.0_real64
   do k = 1_int32, nc
      top = max(top, c(1, k), c(2, k), c(3, k))
   enddo
   if (top > 255.0_real64) then
      err = where//': colour components above 255 (expected [0, 1] or [0, 255])'
      return
   endif
   if (top > 1.0_real64) c(:, 1:nc) = c(:, 1:nc) / 255.0_real64
   if (columns == 4_int32) then
      if (.not. x(nc) > x(1)) then
         err = where//': the positions (first column) span no range'
         return
      endif
      call cmf_resample(x(1:nc), c(:, 1:nc), CMF_SAMPLES, rows)
   else
      allocate(rows(3, nc))
      rows = c(:, 1:nc)
   endif
   endsubroutine cmf_csv

   pure subroutine cells(line, n, cs, ce)
   !< The blank-separated cells of a line (`>>` of a stream: C's `isspace`), the first five.
   character(len=*), intent(in)  :: line   !< Line.
   integer(int32),   intent(out) :: n      !< Cells (counted past five).
   integer(int32),   intent(out) :: cs(5), ce(5) !< Their ends.
   integer(int32)                :: k      !< Position.
   logical                       :: inside !< In a cell.

   n = 0_int32
   cs = 1_int32
   ce = 0_int32
   inside = .false.
   do k = 1_int32, len(line, kind=int32)
      if (is_space(line(k:k))) then
         if (inside .and. n <= 5_int32) ce(n) = k - 1_int32
         inside = .false.
      elseif (.not. inside) then
         inside = .true.
         n = n + 1_int32
         if (n <= 5_int32) cs(n) = k
      endif
   enddo
   if (inside .and. n <= 5_int32) ce(n) = len(line, kind=int32)
   endsubroutine cells

   pure function is_space(ch) result(yes)
   !< C's `isspace` in the C locale.
   character(len=1), intent(in) :: ch  !< Character.
   logical                      :: yes !< Blank.

   yes = ch == ' ' .or. (iachar(ch) >= 9 .and. iachar(ch) <= 13)
   endfunction is_space

   subroutine cmf_resample(x, c, n, out)
   !< `resample`: the colours c at the positions x (non-decreasing, at least two distinct) linearly interpolated at n
   !< uniform positions.
   real(real64),              intent(in)  :: x(:)     !< Positions.
   real(real64),              intent(in)  :: c(:,:)   !< Colours (3, size(x)).
   integer(int32),            intent(in)  :: n        !< Samples.
   real(real64), allocatable, intent(out) :: out(:,:) !< Table (3, n).
   real(real64)                           :: t, w, p, q !< Position, weight, terms.
   integer(int32)                         :: i, k, j, m !< Counters, positions.

   allocate(out(3, n))
   m = size(x, kind=int32)
   i = 1_int32
   do k = 0_int32, n - 1_int32
      call position(x, k, n, t)
      do while (i + 2_int32 <= m)
         if (.not. x(i + 1_int32) <= t) exit
         i = i + 1_int32
      enddo
      call weight(x, i, t, w)
      do j = 1_int32, 3_int32
         p = (1.0_real64 - w) * c(j, i)
         q = w * c(j, i + 1_int32)
         out(j, k + 1_int32) = p + q
      enddo
   enddo
   endsubroutine cmf_resample

   pure subroutine position(x, k, n, t)
   !< The k-th of n uniform positions over x's span: x0 + (x1 - x0) k / (n - 1).
   real(real64),   intent(in)  :: x(:) !< Positions.
   integer(int32), intent(in)  :: k, n !< Sample, samples.
   real(real64),   intent(out) :: t    !< Position.
   real(real64)                :: d    !< A product.

   d = (x(size(x)) - x(1)) * real(k, real64)
   d = d / real(n - 1_int32, real64)
   t = x(1) + d
   endsubroutine position

   pure subroutine weight(x, i, t, w)
   !< The weight of x(i + 1) at t: clamp((t - x(i)) / (x(i + 1) - x(i)), 0, 1), 1 on an empty step.
   real(real64),   intent(in)  :: x(:) !< Positions.
   integer(int32), intent(in)  :: i    !< Step.
   real(real64),   intent(in)  :: t    !< Position.
   real(real64),   intent(out) :: w    !< Weight.

   if (x(i + 1) > x(i)) then
      w = (t - x(i)) / (x(i + 1) - x(i))
      w = min(max(w, 0.0_real64), 1.0_real64)
   else
      w = 1.0_real64
   endif
   endsubroutine weight

   ! ParaView presets

   subroutine cmf_paraview(text, where, name, rows, err)
   !< `parse_paraview`: the table of a ParaView preset; `err` empty when read, else the message.
   character(len=*),              intent(in)  :: text      !< The file's text.
   character(len=*),              intent(in)  :: where     !< `"ip_load_colormap: <file>"`.
   character(len=*),              intent(in)  :: name      !< The map's name (the preset's `Name`).
   real(real64),     allocatable, intent(out) :: rows(:,:) !< The table (3, 256).
   character(len=:), allocatable, intent(out) :: err       !< Message ('' when read).
   type(json_doc)                :: d          !< The document.
   character(kind=c_char), allocatable, target :: s(:) !< The text, NUL-terminated.
   character(len=:), allocatable :: perr, space !< The parser's message, the colour space.
   integer(int32)                :: p, root, it, preset, np, pts, cs, nm, k, i, npt, m !< Positions, nodes, counters.
   real(real64),     allocatable :: x(:), c(:,:) !< Positions, colours.
   real(real64)                  :: v(4), t, w !< A point, a sample's position, its weight.

   err = ''
   allocate(s(len(text) + 1))
   do k = 1_int32, len(text, kind=int32)
      s(k) = text(k:k)
   enddo
   s(len(text) + 1) = c_null_char
   allocate(d%kind(64), d%num(64), d%str_off(64), d%str_len(64), d%key_off(64), d%key_len(64), d%first(64), &
            d%last(64), d%next(64))
   allocate(character(len=max(256, len(text))) :: d%txt)
   p = 1_int32
   perr = ''
   if (.not. json_value(d, s, len(text, kind=int32), p, 0_int32, root, perr)) then
      err = where//': '//perr
      return
   endif
   ! the presets: the root object, or the objects of the root array; the one named `name` (the last), or the only one
   np = 0_int32
   preset = 0_int32
   if (d%kind(root) == J_OBJECT) then
      np = 1_int32
      preset = root
      call named(root)
   elseif (d%kind(root) == J_ARRAY) then
      it = d%first(root)
      do while (it > 0_int32)
         if (d%kind(it) == J_OBJECT) then
            np = np + 1_int32
            if (np == 1_int32) preset = it
         endif
         it = d%next(it)
      enddo
      if (np /= 1_int32) preset = 0_int32
      it = d%first(root)
      do while (it > 0_int32)
         if (d%kind(it) == J_OBJECT) call named(it)
         it = d%next(it)
      enddo
   endif
   if (preset == 0_int32) then
      err = where//': '//itoa(np)//" presets, none named '"//name//"'"
      return
   endif
   pts = member(d, preset, 'RGBPoints')
   if (pts == 0_int32) then
      err = where//': the preset has no RGBPoints (an indexed preset, IndexedColors, is not a colormap)'
      return
   endif
   if (d%kind(pts) /= J_ARRAY) then
      err = where//': the preset has no RGBPoints (an indexed preset, IndexedColors, is not a colormap)'
      return
   endif
   npt = children(d, pts)
   if (npt < 8_int32 .or. mod(npt, 4_int32) /= 0_int32) then
      err = where//': RGBPoints must hold x, r, g, b for at least 2 points, found '//itoa(npt)//' numbers'
      return
   endif
   space = 'RGB'
   cs = member(d, preset, 'ColorSpace')
   if (cs > 0_int32) then
      if (d%kind(cs) == J_STRING) space = d%txt(d%str_off(cs):d%str_off(cs) + d%str_len(cs) - 1_int32)
   endif
   if (same(space, 'Lab/CIEDE2000') .or. same(space, 'CIELAB')) space = 'Lab'
   if (.not. (same(space, 'RGB') .or. same(space, 'Lab') .or. same(space, 'Diverging') .or. same(space, 'HSV') .or. &
              same(space, 'Step'))) then
      err = where//": the colour space '"//space//"' is not supported (RGB, Lab, Diverging, HSV, Step)"
      return
   endif
   m = npt / 4_int32
   allocate(x(m), c(3, m))
   it = d%first(pts)
   do i = 1_int32, m
      do k = 1_int32, 4_int32
         if (d%kind(it) /= J_NUMBER .or. .not. abs(d%num(it)) <= huge(1.0_real64)) then
            err = where//': RGBPoints holds a value that is not a number'
            return
         endif
         v(k) = d%num(it)
         it = d%next(it)
      enddo
      if (i > 1_int32) then
         if (v(1) < x(i - 1_int32)) then
            err = where//': the positions of RGBPoints must not decrease'
            return
         endif
      endif
      if (v(2) < 0.0_real64 .or. v(2) > 1.0_real64 .or. v(3) < 0.0_real64 .or. v(3) > 1.0_real64 .or. &
          v(4) < 0.0_real64 .or. v(4) > 1.0_real64) then
         err = where//': an RGBPoints colour outside [0, 1]'
         return
      endif
      x(i) = v(1)
      c(:, i) = v(2:4)
   enddo
   if (.not. x(m) > x(1)) then
      err = where//': the positions of RGBPoints span no range'
      return
   endif
   allocate(rows(3, CMF_SAMPLES))
   i = 1_int32
   do k = 0_int32, CMF_SAMPLES - 1_int32
      call position(x, k, CMF_SAMPLES, t)
      do while (i + 2_int32 <= m)
         if (.not. x(i + 1_int32) <= t) exit
         i = i + 1_int32
      enddo
      call weight(x, i, t, w)
      if (same(space, 'Step')) then
         if (w < 1.0_real64) then
            rows(:, k + 1_int32) = c(:, i)
         else
            rows(:, k + 1_int32) = c(:, i + 1_int32)
         endif
      else
         rows(:, k + 1_int32) = blend(space, c(:, i), c(:, i + 1_int32), w)
      endif
   enddo
   contains
      subroutine named(node)
      !< `preset` set to `node` if its `Name` is the map's.
      integer(int32), intent(in) :: node !< An object.

      nm = member(d, node, 'Name')
      if (nm == 0_int32) return
      if (d%kind(nm) /= J_STRING) return
      if (d%txt(d%str_off(nm):d%str_off(nm) + d%str_len(nm) - 1_int32) == name .and. d%str_len(nm) == len(name)) &
         preset = node
      endsubroutine named
   endsubroutine cmf_paraview

   pure function same(a, b) result(yes)
   !< Two texts equal as C++ strings (their lengths too: Fortran's == pads with blanks).
   character(len=*), intent(in) :: a, b !< Texts.
   logical                      :: yes  !< Equal.

   yes = len(a) == len(b)
   if (yes) yes = a == b
   endfunction same

   function member(d, obj, key) result(node)
   !< `json_t::get`: an object's first member named `key` (0: none).
   type(json_doc),   intent(in) :: d    !< Document.
   integer(int32),   intent(in) :: obj  !< Object.
   character(len=*), intent(in) :: key  !< Name.
   integer(int32)               :: node !< Member.

   node = d%first(obj)
   do while (node > 0_int32)
      if (d%key_len(node) == len(key)) then
         if (d%txt(d%key_off(node):d%key_off(node) + d%key_len(node) - 1_int32) == key) return
      endif
      node = d%next(node)
   enddo
   endfunction member

   function children(d, node) result(n)
   !< A node's children.
   type(json_doc), intent(in) :: d    !< Document.
   integer(int32), intent(in) :: node !< Node.
   integer(int32)             :: n    !< Children.
   integer(int32)             :: it   !< Child.

   n = 0_int32
   it = d%first(node)
   do while (it > 0_int32)
      n = n + 1_int32
      it = d%next(it)
   enddo
   endfunction children

   ! the JSON reader (`json_parser_t`)

   recursive function json_value(d, s, ns, p, depth, node, err) result(ok)
   !< `value`: the value at p (blanks skipped), a new node; false with `err` (the first error, its line) if malformed.
   type(json_doc),                 intent(inout) :: d     !< Document.
   character(kind=c_char), target, intent(in)    :: s(:)  !< Text, NUL-terminated.
   integer(int32),                 intent(in)    :: ns    !< Its length (the NUL excluded).
   integer(int32),                 intent(inout) :: p     !< Position (1-based).
   integer(int32),                 intent(in)    :: depth !< Nesting.
   integer(int32),                 intent(out)   :: node  !< The value's node.
   character(len=:), allocatable,  intent(inout) :: err   !< Message.
   logical                                       :: ok    !< Read.
   integer(int32)                                :: item, ko, kl !< A child, a member's name.
   type(c_ptr)                                   :: e     !< Where `strtod` stopped.

   ok = .false.
   node = new_node(d)
   if (depth > 64_int32) then
      call error('nested too deeply')
      return
   endif
   call blank()
   if (p > ns) then
      call error('unexpected end of the file')
      return
   endif
   select case (s(p))
   case ('{')
      d%kind(node) = J_OBJECT
      p = p + 1_int32
      call blank()
      if (p <= ns) then
         if (s(p) == '}') then
            p = p + 1_int32
            ok = .true.
            return
         endif
      endif
      do
         call blank()
         if (p > ns) then
            call error('expected a member name')
            return
         endif
         if (s(p) /= '"') then
            call error('expected a member name')
            return
         endif
         if (.not. json_string(d, s, ns, p, ko, kl, err)) return
         call blank()
         if (p > ns) then
            call error("expected ':'")
            return
         endif
         if (s(p) /= ':') then
            call error("expected ':'")
            return
         endif
         p = p + 1_int32
         if (.not. json_value(d, s, ns, p, depth + 1_int32, item, err)) return
         d%key_off(item) = ko
         d%key_len(item) = kl
         call append(node, item)
         call blank()
         if (p <= ns) then
            if (s(p) == ',') then
               p = p + 1_int32
               cycle
            endif
            if (s(p) == '}') then
               p = p + 1_int32
               ok = .true.
               return
            endif
         endif
         call error("expected ',' or '}'")
         return
      enddo
   case ('[')
      d%kind(node) = J_ARRAY
      p = p + 1_int32
      call blank()
      if (p <= ns) then
         if (s(p) == ']') then
            p = p + 1_int32
            ok = .true.
            return
         endif
      endif
      do
         if (.not. json_value(d, s, ns, p, depth + 1_int32, item, err)) return
         call append(node, item)
         call blank()
         if (p <= ns) then
            if (s(p) == ',') then
               p = p + 1_int32
               cycle
            endif
            if (s(p) == ']') then
               p = p + 1_int32
               ok = .true.
               return
            endif
         endif
         call error("expected ',' or ']'")
         return
      enddo
   case ('"')
      d%kind(node) = J_STRING
      ok = json_string(d, s, ns, p, ko, kl, err)
      d%str_off(node) = ko
      d%str_len(node) = kl
      return
   case default
   endselect
   if (literal('true')) then
      d%kind(node) = J_BOOL
      d%num(node) = 1.0_real64
      ok = .true.
      return
   endif
   if (literal('false')) then
      d%kind(node) = J_BOOL
      ok = .true.
      return
   endif
   if (literal('null')) then
      ok = .true.
      return
   endif
   d%kind(node) = J_NUMBER
   d%num(node) = c_strtod(s(p), e) ! (the element: no copy of the text, `e` points into it)
   if (transfer(e, 0_c_intptr_t) == transfer(c_loc(s(p)), 0_c_intptr_t)) then
      call error('expected a value')
      return
   endif
   p = p + int(transfer(e, 0_c_intptr_t) - transfer(c_loc(s(p)), 0_c_intptr_t), int32)
   ok = .true.
   contains
      subroutine blank()
      !< Blanks skipped (`isspace`).
      do while (p <= ns)
         if (.not. is_space(s(p))) exit
         p = p + 1_int32
      enddo
      endsubroutine blank

      function literal(word) result(yes)
      !< The word at p, skipped.
      character(len=*), intent(in) :: word !< Word.
      logical                      :: yes  !< Found.
      integer(int32)               :: k    !< Counter.

      yes = .false.
      if (p + len(word) - 1 > ns) return
      do k = 1_int32, len(word, kind=int32)
         if (s(p + k - 1_int32) /= word(k:k)) return
      enddo
      p = p + len(word, kind=int32)
      yes = .true.
      endfunction literal

      subroutine append(parent, child)
      !< A child appended to a node.
      integer(int32), intent(in) :: parent, child !< Nodes.

      if (d%first(parent) == 0_int32) then
         d%first(parent) = child
      else
         d%next(d%last(parent)) = child
      endif
      d%last(parent) = child
      endsubroutine append

      subroutine error(what)
      !< The first error, with its line.
      character(len=*), intent(in) :: what !< Message.

      call json_error(s, ns, p, what, err)
      endsubroutine error
   endfunction json_value

   subroutine json_error(s, ns, p, what, err)
   !< `error`: the message, unless one is kept, as `"line <n>: <what>"` (n: the lines up to p).
   character(kind=c_char),        intent(in)    :: s(:) !< Text.
   integer(int32),                intent(in)    :: ns   !< Its length.
   integer(int32),                intent(in)    :: p    !< Position.
   character(len=*),              intent(in)    :: what !< Message.
   character(len=:), allocatable, intent(inout) :: err  !< The first one.
   integer(int32)                               :: k, line !< Counters.

   if (len(err) > 0) return
   line = 1_int32
   do k = 1_int32, min(p - 1_int32, ns)
      if (s(k) == achar(10)) line = line + 1_int32
   enddo
   err = 'line '//itoa(line)//': '//what
   endsubroutine json_error

   function json_string(d, s, ns, p, off, n, err) result(ok)
   !< `string`: the string at p (its opening quote), unescaped into the document's text (`\u` and its four digits
   !< as '?'); false on a bad escape or no closing quote.
   type(json_doc),                intent(inout) :: d    !< Document.
   character(kind=c_char),        intent(in)    :: s(:) !< Text.
   integer(int32),                intent(in)    :: ns   !< Its length.
   integer(int32),                intent(inout) :: p    !< Position.
   integer(int32),                intent(out)   :: off, n !< The string's start and length in `d%txt`.
   character(len=:), allocatable, intent(inout) :: err  !< Message.
   logical                                      :: ok   !< Read.
   character(len=1)                             :: ch   !< An escape.
   integer(int32)                               :: f    !< Its place among the escapes.
   character(len=8), parameter                  :: FROM = '"\/bfnrt' !< Escapes.

   ok = .false.
   off = d%n_txt + 1_int32
   n = 0_int32
   p = p + 1_int32 ! the opening quote
   do while (p <= ns)
      if (s(p) == '"') exit
      if (s(p) == '\') then
         p = p + 1_int32
         if (p > ns) exit
         ch = s(p)
         if (ch == 'u') then
            if (p + 4_int32 > ns) exit
            p = p + 4_int32
            call put('?')
         else
            f = index(FROM, ch)
            if (f == 0_int32) then
               call json_error(s, ns, p, 'a bad escape in a string', err)
               return
            endif
            select case (f)
            case (4_int32)
               call put(achar(8))
            case (5_int32)
               call put(achar(12))
            case (6_int32)
               call put(achar(10))
            case (7_int32)
               call put(achar(13))
            case (8_int32)
               call put(achar(9))
            case default
               call put(ch)
            endselect
         endif
      else
         call put(s(p))
      endif
      p = p + 1_int32
   enddo
   if (p > ns) then
      call json_error(s, ns, p, 'a string without its closing quote', err)
      return
   endif
   p = p + 1_int32
   ok = .true.
   contains
      subroutine put(c)
      !< A character of the string.
      character(len=1), intent(in) :: c !< Character.
      character(len=:), allocatable :: more !< Grown text.

      if (d%n_txt >= len(d%txt)) then
         allocate(character(len=2 * len(d%txt)) :: more)
         more(1:d%n_txt) = d%txt(1:d%n_txt)
         call move_alloc(more, d%txt)
      endif
      d%n_txt = d%n_txt + 1_int32
      d%txt(d%n_txt:d%n_txt) = c
      n = n + 1_int32
      endsubroutine put
   endfunction json_string

   function new_node(d) result(node)
   !< A new node of kind null, no children (the table grown when full).
   type(json_doc), intent(inout) :: d    !< Document.
   integer(int32)                :: node !< Node.
   integer(int32),   allocatable :: ia(:) !< A grown column.
   real(real64),     allocatable :: ra(:) !< ...
   integer(int32)                :: m     !< New room.

   if (d%n == size(d%kind, kind=int32)) then
      m = 2_int32 * d%n
      call grow_i(d%kind)
      call grow_i(d%str_off)
      call grow_i(d%str_len)
      call grow_i(d%key_off)
      call grow_i(d%key_len)
      call grow_i(d%first)
      call grow_i(d%last)
      call grow_i(d%next)
      allocate(ra(m))
      ra(1:d%n) = d%num(1:d%n)
      call move_alloc(ra, d%num)
   endif
   d%n = d%n + 1_int32
   node = d%n
   d%kind(node) = J_NUL
   d%num(node) = 0.0_real64
   d%str_off(node) = 1_int32
   d%str_len(node) = 0_int32
   d%key_off(node) = 1_int32
   d%key_len(node) = 0_int32
   d%first(node) = 0_int32
   d%last(node) = 0_int32
   d%next(node) = 0_int32
   contains
      subroutine grow_i(a)
      !< A column doubled.
      integer(int32), allocatable, intent(inout) :: a(:) !< Column.

      allocate(ia(m))
      ia(1:d%n) = a(1:d%n)
      call move_alloc(ia, a)
      endsubroutine grow_i
   endfunction new_node

   ! colour spaces (VTK's, as native/figure_colormap.cpp)

   function blend(space, c1, c2, t) result(out)
   !< `blend`: c1 to c2 at t in the colour space (RGB, Lab, Diverging, HSV).
   character(len=*), intent(in) :: space  !< Colour space.
   real(real64),     intent(in) :: c1(3), c2(3) !< Colours.
   real(real64),     intent(in) :: t      !< Position in [0, 1].
   real(real64)                 :: out(3) !< Colour.
   real(real64)                 :: a(3), b(3) !< The ends in the space.

   select case (space)
   case ('Diverging')
      out = diverging(c1, c2, t)
   case ('Lab')
      a = rgb_to_lab(c1)
      b = rgb_to_lab(c2)
      out = lab_to_rgb(mix3(a, b, t))
   case ('HSV')
      a = rgb_to_hsv(c1)
      b = rgb_to_hsv(c2)
      if (b(1) - a(1) > 0.5_real64) then
         a(1) = a(1) + 1.0_real64
      elseif (a(1) - b(1) > 0.5_real64) then
         b(1) = b(1) + 1.0_real64
      endif
      out = hsv_to_rgb(mix3(a, b, t))
   case default
      out = mix3(c1, c2, t)
   endselect
   endfunction blend

   pure function mix3(a, b, t) result(m)
   !< (1 - t) a + t b, each channel.
   real(real64), intent(in) :: a(3), b(3) !< Ends.
   real(real64), intent(in) :: t          !< Weight of b.
   real(real64)             :: m(3)       !< Mix.
   real(real64)             :: p, q       !< Terms.
   integer(int32)           :: j          !< Channel.

   do j = 1_int32, 3_int32
      p = (1.0_real64 - t) * a(j)
      q = t * b(j)
      m(j) = p + q
   enddo
   endfunction mix3

   pure function to_linear(c) result(l)
   !< sRGB to linear.
   real(real64), intent(in) :: c !< Component.
   real(real64)             :: l !< Linear.

   if (c > 0.04045_real64) then
      l = c_pow((c + 0.055_real64) / 1.055_real64, 2.4_real64)
   else
      l = c / 12.92_real64
   endif
   endfunction to_linear

   pure function from_linear(c) result(s)
   !< Linear to sRGB.
   real(real64), intent(in) :: c !< Linear.
   real(real64)             :: s !< Component.

   if (c > 0.0031308_real64) then
      s = 1.055_real64 * c_pow(c, 1.0_real64 / 2.4_real64)
      s = s - 0.055_real64
   else
      s = 12.92_real64 * c
   endif
   endfunction from_linear

   pure function sum3(a, x, b, y, c, z) result(s)
   !< a x + b y + c z, left to right, without FMA.
   real(real64), intent(in) :: a, x, b, y, c, z !< Factors.
   real(real64)             :: s                !< Sum.
   real(real64)             :: t                !< A product.

   s = a * x
   t = b * y
   s = s + t
   t = c * z
   s = s + t
   endfunction sum3

   pure function lab_f(t) result(f)
   !< CIELAB's f.
   real(real64), intent(in) :: t !< Ratio.
   real(real64)             :: f !< Value.

   if (t > 0.008856_real64) then
      f = c_cbrt(t)
   else
      f = 7.787_real64 * t
      f = f + 16.0_real64 / 116.0_real64
   endif
   endfunction lab_f

   pure function lab_g(t) result(g)
   !< CIELAB's inverse of f.
   real(real64), intent(in) :: t !< Value.
   real(real64)             :: g !< Ratio.
   real(real64)             :: t3 !< t cubed.

   t3 = t * t
   t3 = t3 * t
   if (t3 > 0.008856_real64) then
      g = t3
   else
      g = (t - 16.0_real64 / 116.0_real64) / 7.787_real64
   endif
   endfunction lab_g

   pure function rgb_to_lab(c) result(lab)
   !< sRGB in [0, 1] to CIELAB (D65).
   real(real64), intent(in) :: c(3)   !< Colour.
   real(real64)             :: lab(3) !< L, a, b.
   real(real64)             :: r, g, b, x, y, z !< Linear components, XYZ.

   r = to_linear(c(1))
   g = to_linear(c(2))
   b = to_linear(c(3))
   x = sum3(0.4124_real64, r, 0.3576_real64, g, 0.1805_real64, b) / WX
   y = sum3(0.2126_real64, r, 0.7152_real64, g, 0.0722_real64, b) / WY
   z = sum3(0.0193_real64, r, 0.1192_real64, g, 0.9505_real64, b) / WZ
   x = lab_f(x)
   y = lab_f(y)
   z = lab_f(z)
   lab(1) = 116.0_real64 * y
   lab(1) = lab(1) - 16.0_real64
   lab(2) = 500.0_real64 * (x - y)
   lab(3) = 200.0_real64 * (y - z)
   endfunction rgb_to_lab

   pure function lab_to_rgb(lab) result(c)
   !< CIELAB (D65) to sRGB, clamped to [0, 1].
   real(real64), intent(in) :: lab(3) !< L, a, b.
   real(real64)             :: c(3)   !< Colour.
   real(real64)             :: fy, fx, fz, x, y, z, r, g, b, t !< CIELAB's f, XYZ, linear components, a term.

   fy = (lab(1) + 16.0_real64) / 116.0_real64
   fx = fy + lab(2) / 500.0_real64
   fz = fy - lab(3) / 200.0_real64
   x = WX * lab_g(fx)
   y = WY * lab_g(fy)
   z = WZ * lab_g(fz)
   r = 3.2406_real64 * x
   t = 1.5372_real64 * y
   r = r - t
   t = 0.4986_real64 * z
   r = r - t
   g = -0.9689_real64 * x
   t = 1.8758_real64 * y
   g = g + t
   t = 0.0415_real64 * z
   g = g + t
   b = 0.0557_real64 * x
   t = 0.2040_real64 * y
   b = b - t
   t = 1.0570_real64 * z
   b = b + t
   c(1) = min(max(from_linear(r), 0.0_real64), 1.0_real64)
   c(2) = min(max(from_linear(g), 0.0_real64), 1.0_real64)
   c(3) = min(max(from_linear(b), 0.0_real64), 1.0_real64)
   endfunction lab_to_rgb

   pure function lab_to_msh(lab) result(msh)
   !< CIELAB to Moreland's Msh.
   real(real64), intent(in) :: lab(3) !< L, a, b.
   real(real64)             :: msh(3) !< M, s, h.
   real(real64)             :: m      !< Magnitude.

   m = sqrt(sum3(lab(1), lab(1), lab(2), lab(2), lab(3), lab(3)))
   msh(1) = m
   if (m > 0.001_real64) then
      msh(2) = c_acos(lab(1) / m)
      msh(3) = c_atan2(lab(3), lab(2))
   else
      msh(2) = 0.0_real64
      msh(3) = 0.0_real64
   endif
   endfunction lab_to_msh

   pure function msh_to_lab(msh) result(lab)
   !< Moreland's Msh to CIELAB.
   real(real64), intent(in) :: msh(3) !< M, s, h.
   real(real64)             :: lab(3) !< L, a, b.

   lab(1) = msh(1) * c_cos(msh(2))
   lab(2) = msh(1) * c_sin(msh(2))
   lab(2) = lab(2) * c_cos(msh(3))
   lab(3) = msh(1) * c_sin(msh(2))
   lab(3) = lab(3) * c_sin(msh(3))
   endfunction msh_to_lab

   pure function adjust_hue(msh, unsat_m) result(h)
   !< `adjust_hue`: the hue of a diverging segment's unsaturated end.
   real(real64), intent(in) :: msh(3)  !< The saturated end.
   real(real64), intent(in) :: unsat_m !< The unsaturated end's M.
   real(real64)             :: h       !< Hue.
   real(real64)             :: spin, a, b !< The spin, terms.

   if (msh(1) >= unsat_m - 0.1_real64) then
      h = msh(3)
      return
   endif
   a = unsat_m * unsat_m
   b = msh(1) * msh(1)
   spin = msh(2) * sqrt(a - b)
   spin = spin / (msh(1) * c_sin(msh(2)))
   if (msh(3) > -0.3_real64 * PI) then
      h = msh(3) + spin
   else
      h = msh(3) - spin
   endif
   endfunction adjust_hue

   pure function angle_diff(a, b) result(d)
   !< The angle between two hues.
   real(real64), intent(in) :: a, b !< Hues.
   real(real64)             :: d    !< Difference.

   d = abs(a - b)
   if (d > PI) d = 2.0_real64 * PI - d
   endfunction angle_diff

   pure function diverging(c1, c2, t0) result(c)
   !< `diverging`: Moreland's diverging blend (through white when both ends are saturated and far apart in hue).
   real(real64), intent(in) :: c1(3), c2(3) !< Ends.
   real(real64), intent(in) :: t0           !< Position.
   real(real64)             :: c(3)         !< Colour.
   real(real64)             :: a(3), b(3), t, mid !< Ends in Msh, position, the middle's M.

   t = t0
   a = lab_to_msh(rgb_to_lab(c1))
   b = lab_to_msh(rgb_to_lab(c2))
   if (a(2) > 0.05_real64 .and. b(2) > 0.05_real64 .and. angle_diff(a(3), b(3)) > 0.33_real64 * PI) then
      mid = max(a(1), b(1), 88.0_real64)
      if (t < 0.5_real64) then
         b = [mid, 0.0_real64, 0.0_real64]
         t = t * 2.0_real64
      else
         a = [mid, 0.0_real64, 0.0_real64]
         t = 2.0_real64 * t
         t = t - 1.0_real64
      endif
   endif
   if (a(2) < 0.05_real64 .and. b(2) > 0.05_real64) then
      a(3) = adjust_hue(b, a(1))
   elseif (b(2) < 0.05_real64 .and. a(2) > 0.05_real64) then
      b(3) = adjust_hue(a, b(1))
   endif
   c = lab_to_rgb(msh_to_lab(mix3(a, b, t)))
   endfunction diverging

   pure function rgb_to_hsv(c) result(hsv)
   !< sRGB to HSV, the hue in [0, 1).
   real(real64), intent(in) :: c(3)   !< Colour.
   real(real64)             :: hsv(3) !< H, S, V.
   real(real64)             :: mx, mn, d, h !< Extremes, their difference, hue.

   mx = max(c(1), c(2), c(3))
   mn = min(c(1), c(2), c(3))
   d = mx - mn
   h = 0.0_real64
   if (d > 0.0_real64) then
      if (mx == c(1)) then
         h = c_fmod((c(2) - c(3)) / d + 6.0_real64, 6.0_real64)
      elseif (mx == c(2)) then
         h = (c(3) - c(1)) / d + 2.0_real64
      else
         h = (c(1) - c(2)) / d + 4.0_real64
      endif
   endif
   hsv(1) = h / 6.0_real64
   hsv(2) = merge(d / max(mx, tiny(1.0_real64)), 0.0_real64, mx > 0.0_real64)
   hsv(3) = mx
   endfunction rgb_to_hsv

   pure function hsv_to_rgb(hsv) result(c)
   !< HSV to sRGB.
   real(real64), intent(in) :: hsv(3) !< H, S, V.
   real(real64)             :: c(3)   !< Colour.
   real(real64)             :: h, s, v, f, p, q, u, a !< Hue sector, the terms.
   integer(int32)           :: i      !< Sector.

   h = c_fmod(hsv(1) + 1.0_real64, 1.0_real64) * 6.0_real64
   s = hsv(2)
   v = hsv(3)
   i = mod(int(h, int32), 6_int32)
   f = h - floor(h)
   p = v * (1.0_real64 - s)
   a = s * f
   q = v * (1.0_real64 - a)
   a = s * (1.0_real64 - f)
   u = v * (1.0_real64 - a)
   select case (i)
   case (0_int32)
      c = [v, u, p]
   case (1_int32)
      c = [q, v, p]
   case (2_int32)
      c = [p, v, u]
   case (3_int32)
      c = [p, q, v]
   case (4_int32)
      c = [u, p, v]
   case default
      c = [v, p, q]
   endselect
   endfunction hsv_to_rgb
endmodule figure_plot_colormap_files
