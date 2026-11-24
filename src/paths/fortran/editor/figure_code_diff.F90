!< figure_code_diff, the text diff: dtl's shortest edit script of two texts' lines, and FIGURE's glue around it.
module figure_code_diff
!< figure_code_diff, the text diff: dtl's shortest edit script of two texts' lines, and FIGURE's glue around it.
!<
!< szaghi/figure#15 P16. `diff_compose` is dtl's `Diff<std::string_view>::compose` (third_party/ImGuiColorTextEdit/dtl.h,
!< BSD): Wu, Manber and Myers' O(NP) algorithm over the lines of two texts (compared whole, byte for byte), the
!< shorter sequence first (swapped when the first is not shorter), the edit path followed back and recorded as the
!< shortest edit script: each line common, added (of the second text) or deleted (of the first), with its index in each
!< text (from 1, 0 for none), in dtl's order (no deletes moved first). A path longer than dtl's 2,000,000 coordinates
!< is recorded in parts, from where the last one stopped, as dtl does. `fig_code_diff_lines` is the glue's (the lines
!< added and removed, as `code_diff_lines` reports them).
use, intrinsic :: iso_c_binding, only : c_char, c_double, c_int, c_long_long
use, intrinsic :: iso_fortran_env, only : int8, int32, int64
use figure_c_native, only : FIG_ERR_STATE, FIG_OK, fig_set_last_error

implicit none
private
public :: SES_DELETE, SES_COMMON, SES_ADD
public :: diff_lines, diff_compose, fig_code_diff_lines, fig_code_diff

integer(int8),  parameter :: SES_DELETE = -1_int8 !< A line of the first text only.
integer(int8),  parameter :: SES_COMMON = 0_int8  !< A line of both.
integer(int8),  parameter :: SES_ADD = 1_int8     !< A line of the second text only.
integer(int64), parameter :: MAX_COORDINATES = 2000000_int64 !< dtl's MAX_CORDINATES_SIZE.

type :: diff_state
   !< dtl's `Diff` state over two texts' lines: A the shorter (B when the texts are swapped).
   integer(int64), allocatable :: loff(:), llen(:) !< The first text's lines (offsets, lengths).
   integer(int64), allocatable :: roff(:), rlen(:) !< The second text's.
   logical                     :: swapped = .false. !< A is the second text.
   integer(int64)              :: a0 = 0_int64, b0 = 0_int64 !< First lines of A and B considered (after restarts).
   integer(int64)              :: m = 0_int64, n = 0_int64   !< Lines of A and B considered.
   integer(int64)              :: delta = 0_int64, offset = 0_int64 !< dtl's.
   integer(int64)              :: ox = 0_int64, oy = 0_int64 !< dtl's offsets of a restart.
   integer(int64), allocatable :: fp(:), path(:)   !< dtl's fp and path, from 0.
   integer(int64), allocatable :: cx(:), cy(:), ck(:) !< dtl's pathCordinates.
   integer(int64)              :: nc = 0_int64     !< Coordinates.
endtype diff_state

contains
   pure subroutine diff_lines(t, off, n, count)
   !< The lines of `t` (LF-separated; the part after the last LF is a line, empty or not): their offsets and lengths.
   character(len=*),            intent(in)  :: t      !< Text.
   integer(int64), allocatable, intent(out) :: off(:) !< Offsets (bytes before each line).
   integer(int64), allocatable, intent(out) :: n(:)   !< Lengths.
   integer(int32),              intent(out) :: count  !< Lines.
   integer(int64)                           :: k, a   !< Counter, start of a line.

   count = 1_int32
   do k = 1_int64, len(t, int64)
      if (t(k:k) == achar(10)) count = count + 1_int32
   enddo
   allocate(off(count), n(count))
   count = 0_int32
   a = 1_int64
   do k = 1_int64, len(t, int64)
      if (t(k:k) == achar(10)) then
         count = count + 1_int32
         off(count) = a - 1_int64
         n(count) = k - a
         a = k + 1_int64
      endif
   enddo
   count = count + 1_int32
   off(count) = a - 1_int64
   n(count) = len(t, int64) + 1_int64 - a
   endsubroutine diff_lines

   subroutine diff_compose(left, right, kind, before, after, nses)
   !< dtl's shortest edit script of `left`'s lines into `right`'s: `kind(k)` (`SES_*`), the line's index in `left`
   !< (`before`) and in `right` (`after`), from 1 (0 for none), for k = 1..`nses`.
   character(len=*),            intent(in)  :: left      !< The first text.
   character(len=*),            intent(in)  :: right     !< The second text.
   integer(int8),  allocatable, intent(out) :: kind(:)   !< Each entry's kind.
   integer(int64), allocatable, intent(out) :: before(:) !< Its line in `left`.
   integer(int64), allocatable, intent(out) :: after(:)  !< Its line in `right`.
   integer(int32),              intent(out) :: nses      !< Entries.
   type(diff_state)                         :: st        !< dtl's state.
   integer(int32)                           :: nl, nr    !< Lines of each text.
   integer(int64)                           :: p, k, r   !< dtl's.
   integer(int64), allocatable              :: vx(:), vy(:) !< The path followed back (dtl's epc).
   integer(int64)                           :: nv, i     !< Its points, counter.
   integer(int64)                           :: x_idx, y_idx, px, py !< recordSequence's.
   logical                                  :: done      !< Recorded whole.

   call diff_lines(left, st%loff, st%llen, nl)
   call diff_lines(right, st%roff, st%rlen, nr)
   st%swapped = .not. (nl < nr)
   if (st%swapped) then
      st%m = nr
      st%n = nl
   else
      st%m = nl
      st%n = nr
   endif
   allocate(kind(nl + nr), before(nl + nr), after(nl + nr))
   nses = 0_int32
   allocate(st%cx(1024), st%cy(1024), st%ck(1024))
   do
      st%delta = st%n - st%m
      st%offset = st%m + 1_int64
      allocate(st%fp(0:st%m + st%n + 2_int64), st%path(0:st%m + st%n + 2_int64))
      st%fp = -1_int64
      st%path = -1_int64
      st%nc = 0_int64
      p = -1_int64
      do
         p = p + 1_int64
         do k = -p, st%delta - 1_int64
            st%fp(k + st%offset) = snake(st, left, right, k)
         enddo
         do k = st%delta + p, st%delta + 1_int64, -1_int64
            st%fp(k + st%offset) = snake(st, left, right, k)
         enddo
         st%fp(st%delta + st%offset) = snake(st, left, right, st%delta)
         if (st%fp(st%delta + st%offset) == st%n .or. st%nc >= MAX_COORDINATES) exit
      enddo
      ! the path, back from its end
      r = st%path(st%delta + st%offset)
      nv = 0_int64
      allocate(vx(st%nc + 1_int64), vy(st%nc + 1_int64))
      do while (r /= -1_int64)
         nv = nv + 1_int64
         vx(nv) = st%cx(r + 1_int64)
         vy(nv) = st%cy(r + 1_int64)
         r = st%ck(r + 1_int64)
      enddo
      ! recordSequence
      x_idx = 1_int64
      y_idx = 1_int64
      px = 0_int64
      py = 0_int64
      do i = nv, 1_int64, -1_int64
         do while (px < vx(i) .or. py < vy(i))
            if (vy(i) - vx(i) > py - px) then
               if (.not. st%swapped) then
                  call add(SES_ADD, 0_int64, y_idx + st%oy)
               else
                  call add(SES_DELETE, y_idx + st%oy, 0_int64)
               endif
               y_idx = y_idx + 1_int64
               py = py + 1_int64
            elseif (vy(i) - vx(i) < py - px) then
               if (.not. st%swapped) then
                  call add(SES_DELETE, x_idx + st%ox, 0_int64)
               else
                  call add(SES_ADD, 0_int64, x_idx + st%ox)
               endif
               x_idx = x_idx + 1_int64
               px = px + 1_int64
            else
               if (.not. st%swapped) then
                  call add(SES_COMMON, x_idx + st%ox, y_idx + st%oy)
               else
                  call add(SES_COMMON, y_idx + st%oy, x_idx + st%ox)
               endif
               x_idx = x_idx + 1_int64
               y_idx = y_idx + 1_int64
               px = px + 1_int64
               py = py + 1_int64
            endif
         enddo
      enddo
      done = x_idx > st%m .and. y_idx > st%n
      deallocate(st%fp, st%path, vx, vy)
      if (done) exit
      ! a path too long: what is left compared again, from where the recording stopped
      st%a0 = st%a0 + x_idx - 1_int64
      st%b0 = st%b0 + y_idx - 1_int64
      st%m = st%m - (x_idx - 1_int64)
      st%n = st%n - (y_idx - 1_int64)
      st%ox = x_idx - 1_int64
      st%oy = y_idx - 1_int64
   enddo
   contains
      subroutine add(t, bi, ai)
      !< An entry of the script (writes the host's dummies only).
      integer(int8),  intent(in) :: t      !< Kind.
      integer(int64), intent(in) :: bi, ai !< Its lines in `left`, `right`.

      nses = nses + 1_int32
      kind(nses) = t
      before(nses) = bi
      after(nses) = ai
      endsubroutine add
   endsubroutine diff_compose

   pure function same(st, left, right, ia, ib) result(yes)
   !< Line `ia` of A equals line `ib` of B (from 0, past the restarts' offsets).
   type(diff_state), intent(in) :: st          !< State.
   character(len=*), intent(in) :: left, right !< Texts.
   integer(int64),   intent(in) :: ia, ib      !< Lines.
   logical                      :: yes         !< Equal.
   integer(int64)               :: la, lb, oa, ob, na, nb !< Lines, offsets, lengths.

   la = st%a0 + ia + 1_int64
   lb = st%b0 + ib + 1_int64
   if (st%swapped) then
      oa = st%roff(la)
      na = st%rlen(la)
      ob = st%loff(lb)
      nb = st%llen(lb)
      yes = na == nb
      if (yes) yes = right(oa + 1_int64:oa + na) == left(ob + 1_int64:ob + nb)
   else
      oa = st%loff(la)
      na = st%llen(la)
      ob = st%roff(lb)
      nb = st%rlen(lb)
      yes = na == nb
      if (yes) yes = left(oa + 1_int64:oa + na) == right(ob + 1_int64:ob + nb)
   endif
   endfunction same

   function snake(st, left, right, k) result(y)
   !< dtl's `snake`: the furthest point on diagonal `k` from its neighbours' fp, its coordinate recorded.
   type(diff_state), intent(inout) :: st          !< State.
   character(len=*), intent(in)    :: left, right !< Texts.
   integer(int64),   intent(in)    :: k           !< Diagonal.
   integer(int64)                  :: y           !< Its y.
   integer(int64)                  :: above, below, r, x !< fp of the neighbours, previous coordinate, x.
   integer(int64), allocatable     :: g(:)        !< Grown coordinates.

   above = st%fp(k - 1_int64 + st%offset) + 1_int64
   below = st%fp(k + 1_int64 + st%offset)
   if (above > below) then
      r = st%path(k - 1_int64 + st%offset)
   else
      r = st%path(k + 1_int64 + st%offset)
   endif
   y = max(above, below)
   x = y - k
   do while (x >= 0_int64 .and. x < st%m .and. y >= 0_int64 .and. y < st%n)
      if (.not. same(st, left, right, x, y)) exit
      x = x + 1_int64
      y = y + 1_int64
   enddo
   st%path(k + st%offset) = st%nc
   if (st%nc == size(st%cx, kind=int64)) then
      allocate(g(2_int64 * st%nc))
      g(1:st%nc) = st%cx(1:st%nc)
      call move_alloc(g, st%cx)
      allocate(g(2_int64 * st%nc))
      g(1:st%nc) = st%cy(1:st%nc)
      call move_alloc(g, st%cy)
      allocate(g(2_int64 * st%nc))
      g(1:st%nc) = st%ck(1:st%nc)
      call move_alloc(g, st%ck)
   endif
   st%nc = st%nc + 1_int64
   st%cx(st%nc) = x
   st%cy(st%nc) = y
   st%ck(st%nc) = r
   endfunction snake

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

   function fig_code_diff_lines(left, left_len, right, right_len, added, n_added, removed, n_removed, cap) &
      result(status)
   !< The lines of `right` added and of `left` removed (from 1), by the diff's algorithm: counts in `n_added`,
   !< `n_removed`; up to `cap` of each written. No Dear ImGui: a task may call it.
   character(kind=c_char), intent(in)    :: left(*)    !< The old text.
   integer(c_long_long),   intent(in)    :: left_len   !< Its length.
   character(kind=c_char), intent(in)    :: right(*)   !< The new text.
   integer(c_long_long),   intent(in)    :: right_len  !< Its length.
   integer(c_int),         intent(inout) :: added(*)   !< Lines added.
   integer(c_int),         intent(out)   :: n_added    !< Their count.
   integer(c_int),         intent(inout) :: removed(*) !< Lines removed.
   integer(c_int),         intent(out)   :: n_removed  !< Their count.
   integer(c_int),         intent(in)    :: cap        !< Room in each.
   integer(c_int)                        :: status     !< Status.
   integer(int8),  allocatable           :: kind(:)    !< The script.
   integer(int64), allocatable           :: b(:), a(:) !< Its lines.
   integer(int32)                        :: nses, k, li, ri !< Entries, counter, lines.

   n_added = 0_c_int
   n_removed = 0_c_int
   call diff_compose(unix_lines(str(left, max(0_int64, int(left_len, int64)))), &
                     unix_lines(str(right, max(0_int64, int(right_len, int64)))), kind, b, a, nses)
   li = 0_int32
   ri = 0_int32
   do k = 1_int32, nses
      select case (kind(k))
      case (SES_COMMON)
         li = li + 1_int32
         ri = ri + 1_int32
      case (SES_ADD)
         ri = ri + 1_int32
         if (n_added < cap) added(n_added + 1_c_int) = ri
         n_added = n_added + 1_c_int
      case (SES_DELETE)
         li = li + 1_int32
         if (n_removed < cap) removed(n_removed + 1_c_int) = li
         n_removed = n_removed + 1_c_int
      endselect
   enddo
   status = FIG_OK
   endfunction fig_code_diff_lines

   function fig_code_diff(id, id_len, left, left_len, right, right_len, packed, packed_len, side_by_side, width, &
                          height) result(status)
   !< The diff drawn by id (#15 P16: the view is a later step of the Fortran path; refused until then).
   character(kind=c_char), intent(in) :: id(*)        !< Widget id.
   integer(c_int),         intent(in) :: id_len       !< Its length.
   character(kind=c_char), intent(in) :: left(*)      !< The old text.
   integer(c_long_long),   intent(in) :: left_len     !< Its length.
   character(kind=c_char), intent(in) :: right(*)     !< The new text.
   integer(c_long_long),   intent(in) :: right_len    !< Its length.
   character(kind=c_char), intent(in) :: packed(*)    !< Language.
   integer(c_int),         intent(in) :: packed_len   !< Its length.
   integer(c_int),         intent(in) :: side_by_side !< Two columns.
   real(c_double),         intent(in) :: width        !< Width.
   real(c_double),         intent(in) :: height       !< Height.
   integer(c_int)                     :: status       !< Status.
   character(len=*), parameter        :: MSG = 'code_diff: not yet on the Fortran path' !< Message.

   call fig_set_last_error(MSG, len(MSG, c_int))
   status = FIG_ERR_STATE
   endfunction fig_code_diff
endmodule figure_code_diff
