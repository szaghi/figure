!< figure_test_decimate, the per-pixel decimation of long series (figure_decimate, #15 P4): its invariants.
program figure_test_decimate
!< figure_test_decimate, the per-pixel decimation of long series (figure_decimate, #15 P4): its invariants.
!<
!< No window, no plot: `decimate` on an x axis given by hand (500 pixels of plot area from pixel 10, x 0 to 1), its
!< pixels computed here again as ImPlot's items compute them. Checked, on series of pseudo-random sorted abscissae and
!< ordinates of several scales:
!< 1. per pixel column with more than 64 points, in each sixteenth of it: its first and last points, its lowest and its
!<    highest (the first of equal ones) kept; a column of at most 64 points kept whole; the indices ascending, without
!<    repetition; at most 64 points a column, 68 with a fill, 96 with two ordinates;
!< 2. the points left and right of the plot area (x < 0, x > 1): their first, last, lowest and highest kept, so that the
!<    series' extremes (ImPlot's fit) and the segments entering the plot are the same;
!< 3. NaN ordinates: one NaN of each run kept, and the numbers on each side of it;
!< 4. a fill: the two points about each column's centre kept;
!< 5. `real32` and `real64`, strided sections read in place (`y(::3)`), uniform abscissae (x0 + (i - 1) dx), a second
!<    ordinate (its extremes kept too), a log10 axis;
!< 7. with a cache (#15 P5): the same points kept as without, for views panned and zoomed over unchanged data (one
!<    ordinate and two, NaN gaps, fills, single precision, uniform abscissae), and unsorted data refused as without;
!< 6. not decimated (`.false.`): unsorted abscissae, a NaN abscissa, at most 256 points per pixel on average, an inverted
!<    axis.
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64, output_unit
use, intrinsic :: ieee_arithmetic, only : ieee_is_nan, ieee_quiet_nan, ieee_value
use figure_decimate, only : decimate, decimate_axis, decimate_cache, DECIMATE_LOG10

implicit none
integer(int64), parameter   :: N = 300001_int64  !< Points of the long series.
integer(int64), parameter   :: SUB = 16_int64    !< Parts of a dense column.
integer(int64), parameter   :: K = 64_int64      !< Points per column decimated above.
type(decimate_axis)         :: ax                !< The x axis.
type(decimate_axis)         :: axlog             !< A log10 axis.
real(real64),   allocatable :: x(:), y(:), y2(:) !< A series.
real(real64),   allocatable :: big(:)            !< An array whose every third element is a series.
real(real32),   allocatable :: xs(:), ys(:)      !< A series, single precision.
integer(int64), allocatable :: keep(:)           !< Indices kept.
integer(int64)              :: nkeep             !< ... how many.
integer(int64)              :: s                 !< Pseudo-random state.
integer(int64)              :: i                 !< Counter.
logical                     :: test_passed(13)   !< Per-check outcome.
logical                     :: done              !< Decimated.
real(real64)                :: r1, r2            !< Pseudo-random numbers.

ax = decimate_axis(pix_min=10.0_real64, plt_min=0.0_real64, plt_max=1.0_real64, m=500.0_real64, left=10.0_real64, &
                   right=510.0_real64)
axlog = decimate_axis(pix_min=10.0_real64, plt_min=1.0_real64, plt_max=1.0e3_real64, m=500.0_real64 / 999.0_real64, &
                      sca_min=0.0_real64, sca_max=3.0_real64, left=10.0_real64, right=510.0_real64, scale=DECIMATE_LOG10)
s = 7_int64
allocate(x(N), y(N), y2(N))
! sorted abscissae from -0.1 to 1.1, denser in places (a few columns sparse), equal ones included
x(1) = -0.1_real64
do i = 2_int64, N
   r1 = rnd()
   r2 = rnd()
   x(i) = x(i - 1_int64) + 1.2_real64 / real(N, real64) * merge(0.0_real64, 2.0_real64 * r1, r2 < 0.05_real64) * &
          merge(400.0_real64, 1.0_real64, i > 120000_int64 .and. i < 120400_int64)
enddo
do i = 1_int64, N
   r1 = rnd()
   y(i) = sin(40.0_real64 * x(i)) + 0.3_real64 * (r1 - 0.5_real64)
enddo
y(1000:1100) = 2.5_real64 ! equal values: the first of them is the maximum

! 1, 2: one ordinate, real64
done = decimate(ax, x, y, keep, nkeep)
test_passed(1) = done .and. columns_ok(x, y, keep(1:nkeep), .false.)
test_passed(2) = done .and. off_plot_ok(x, y, keep(1:nkeep))
write(output_unit, '(A,I0,A,I0)') 'real64: kept ', nkeep, ' of ', N

! 3: NaN gaps
y2 = y
y2(5000) = ieee_value(1.0_real64, ieee_quiet_nan)
y2(70000:70010) = ieee_value(1.0_real64, ieee_quiet_nan)
y2(N - 3_int64) = ieee_value(1.0_real64, ieee_quiet_nan) ! off the plot
done = decimate(ax, x, y2, keep, nkeep)
test_passed(3) = done .and. gap_ok(y2, keep(1:nkeep), 5000_int64, 5000_int64) .and. &
                 gap_ok(y2, keep(1:nkeep), 70000_int64, 70010_int64) .and. gap_ok(y2, keep(1:nkeep), N - 3_int64, N - 3_int64)

! 4: a fill
done = decimate(ax, x, y, keep, nkeep, fill=.true.)
test_passed(4) = done .and. columns_ok(x, y, keep(1:nkeep), .true.)

! 5: a second ordinate, its extremes kept too
y2 = 0.5_real64 * cos(17.0_real64 * x) - y
done = decimate(ax, x, y, keep, nkeep, y2=y2)
test_passed(5) = done .and. columns_ok(x, y, keep(1:nkeep), .false., most=96_int64) .and. &
                 columns_ok(x, y2, keep(1:nkeep), .false., most=96_int64)

! 5: strided sections, read in place
allocate(big(3 * N))
big = 0.0_real64
big(1::3) = y
done = decimate(ax, x, big(1::3), keep, nkeep)
test_passed(6) = done .and. columns_ok(x, y, keep(1:nkeep), .false.)

! 5: uniform abscissae, x = -0.1 + (i - 1) 1.2 / N
do i = 1_int64, N
   y2(i) = 1.2_real64 / real(N, real64) * real(i - 1_int64, real64) + (-0.1_real64)
enddo
done = decimate(ax, -0.1_real64, 1.2_real64 / real(N, real64), y, keep, nkeep)
test_passed(7) = done .and. columns_ok(y2, y, keep(1:nkeep), .false.)

! 5: single precision
allocate(xs(N), ys(N)) ! not by the assignment: nvfortran -Mstandard does not reallocate on assignment
xs = real(x, real32)
ys = real(y, real32)
done = decimate(ax, xs, ys, keep, nkeep, fill=.true.)
test_passed(8) = done .and. columns_ok(real(xs, real64), real(ys, real64), keep(1:nkeep), .true.)

! 5: a log10 axis, x from 0.5 to 2000
do i = 1_int64, N
   y2(i) = 0.5_real64 * 4000.0_real64 ** (real(i - 1_int64, real64) / real(N - 1_int64, real64))
enddo
done = decimate(axlog, y2, y, keep, nkeep)
test_passed(9) = done .and. columns_ok(y2, y, keep(1:nkeep), .false., axlog) .and. off_plot_ok(y2, y, keep(1:nkeep), axlog)

! 6: not decimated
y2 = x
y2(200) = y2(199) - 1.0e-9_real64
test_passed(10) = .not. decimate(ax, y2, y, keep, nkeep)
y2 = x
y2(N / 2_int64) = ieee_value(1.0_real64, ieee_quiet_nan)
test_passed(10) = test_passed(10) .and. .not. decimate(ax, y2, y, keep, nkeep)
test_passed(11) = .not. decimate(ax, x(1:128000), y(1:128000), keep, nkeep) .and. & ! 256 per pixel at most
                  decimate(ax, x(1:128100), y(1:128100), keep, nkeep)
test_passed(12) = .not. decimate(decimate_axis(pix_min=510.0_real64, m=-500.0_real64, left=10.0_real64, &
                                               right=510.0_real64), x, y, keep, nkeep)

! 7: a cache gives what no cache gives
test_passed(13) = cached_ok()

write(output_unit, '(A,*(L2))') 'figure_test_decimate checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   function cached_ok() result(ok)
   !< Invariant 7: with a cache, the points kept are those kept without, view after view.
   logical                     :: ok          !< Holds.
   type(decimate_cache)        :: c(5)        !< One per series.
   type(decimate_axis)         :: v           !< A view.
   integer(int64), allocatable :: k1(:), k2(:) !< Kept with and without the cache.
   integer(int64)              :: n1, n2      !< ... how many.
   real(real64),   allocatable :: g(:), w(:)  !< Ordinates with NaN gaps; second ordinates.
   integer(int32)              :: f           !< View.
   logical                     :: d1, d2      !< Decimated.

   ok = .true.
   allocate(g(N), w(N)) ! not by the assignments: nvfortran -Mstandard does not reallocate on assignment
   g = y
   g(5000:5003) = ieee_value(1.0_real64, ieee_quiet_nan)
   g(150001) = ieee_value(1.0_real64, ieee_quiet_nan)
   w = 0.5_real64 * cos(17.0_real64 * x)
   do f = 1_int32, 12_int32
      v = ax
      v%plt_min = -0.2_real64 + 0.07_real64 * f            ! panned
      v%plt_max = v%plt_min + 1.4_real64 / real(f, real64) ! and zoomed
      v%m = 500.0_real64 / (v%plt_max - v%plt_min)
      d1 = decimate(v, x, g, k1, n1, cache=c(1))
      d2 = decimate(v, x, g, k2, n2)
      ok = ok .and. same(d1, d2, k1, n1, k2, n2)
      d1 = decimate(v, x, y, k1, n1, y2=w, fill=.true., cache=c(2))
      d2 = decimate(v, x, y, k2, n2, y2=w, fill=.true.)
      ok = ok .and. same(d1, d2, k1, n1, k2, n2)
      d1 = decimate(v, xs, ys, k1, n1, cache=c(3))
      d2 = decimate(v, xs, ys, k2, n2)
      ok = ok .and. same(d1, d2, k1, n1, k2, n2)
      d1 = decimate(v, -0.1_real64, 1.2_real64 / real(N, real64), g, k1, n1, cache=c(4))
      d2 = decimate(v, -0.1_real64, 1.2_real64 / real(N, real64), g, k2, n2)
      ok = ok .and. same(d1, d2, k1, n1, k2, n2)
      if (.not. ok) then
         write(output_unit, '(A,I0)') 'cached_ok fails at view ', f
         return
      endif
   enddo
   w = x
   w(200) = w(199) - 1.0e-9_real64
   ok = ok .and. .not. decimate(ax, w, y, k1, n1, cache=c(5)) .and. .not. decimate(ax, w, y, k1, n1, cache=c(5))
   endfunction cached_ok

   function same(d1, d2, k1, n1, k2, n2) result(eq)
   !< Both decimated or neither, the same points kept.
   logical,        intent(in) :: d1, d2  !< Decimated.
   integer(int64), allocatable, intent(in) :: k1(:) !< Kept, one way.
   integer(int64), intent(in) :: n1      !< ... how many.
   integer(int64), allocatable, intent(in) :: k2(:) !< Kept, the other.
   integer(int64), intent(in) :: n2      !< ... how many.
   logical                    :: eq      !< Equal.

   eq = d1 .eqv. d2
   if (eq .and. d1) eq = n1 == n2
   if (eq .and. d1) eq = all(k1(1:n1) == k2(1:n2))
   endfunction same

   function rnd() result(r)
   !< A pseudo-random number in [0, 1) (an LCG: the same series everywhere).
   real(real64) :: r !< Number.

   s = modulo(s * 1103515245_int64 + 12345_int64, 2147483648_int64)
   r = real(s, real64) / 2147483648.0_real64
   endfunction rnd

   function pix(a, p) result(px)
   !< The pixel of an abscissa, as ImPlot's items compute it (Transformer1), rounded to a C float.
   type(decimate_axis), intent(in) :: a  !< Axis.
   real(real64),        intent(in) :: p  !< Abscissa.
   real(real64)                    :: px !< Pixel.
   real(real64)                    :: q  !< Through the scale.

   q = p
   if (a%scale == DECIMATE_LOG10) q = a%plt_min + (a%plt_max - a%plt_min) * &
                                      ((log10(max(p, tiny(1.0_real64))) - a%sca_min) / (a%sca_max - a%sca_min))
   px = real(real(a%pix_min + a%m * (q - a%plt_min), real32), real64)
   endfunction pix

   function columns_ok(xx, yy, kept, fill, axis, most) result(ok)
   !< Invariant 1 (and 4 with a fill), on the pixel columns of the plot area.
   real(real64),        intent(in)           :: xx(:), yy(:) !< The series.
   integer(int64),      intent(in)           :: kept(:)      !< Indices kept.
   logical,             intent(in)           :: fill         !< A fill: the points about each centre kept too.
   type(decimate_axis), intent(in), optional :: axis         !< Axis (default ax).
   integer(int64),      intent(in), optional :: most         !< Points a dense column may keep (default 64, 68 with
                                                             !< a fill).
   logical                                   :: ok           !< Holds.
   type(decimate_axis)                       :: a            !< Axis.
   logical, allocatable                      :: is_kept(:)   !< Point kept.
   integer(int64)                            :: c            !< Column.
   integer(int64)                            :: b, e, j, q   !< First, last point of a column or part; counters.
   integer(int64)                            :: imin, imax   !< Extremes.
   integer(int64)                            :: nmax         !< Points a column may keep.
   integer(int64)                            :: pb, pe       !< A quarter's first, last point.
   real(real64)                              :: lo, hi       !< Its edges [pixels].

   a = ax
   if (present(axis)) a = axis
   ok = all(kept(2:) > kept(:size(kept) - 1)) .and. kept(1) >= 1 .and. kept(size(kept)) <= size(yy)
   allocate(is_kept(size(yy)))
   is_kept = .false.
   is_kept(kept) = .true.
   nmax = merge(68_int64, 64_int64, fill)
   if (present(most)) nmax = most
   b = 1_int64
   do c = 10_int64, 509_int64
      do while (b <= size(xx) .and. pix(a, xx(min(b, size(xx, kind=int64)))) < real(c, real64))
         b = b + 1_int64
      enddo
      e = b
      do while (e <= size(xx) .and. pix(a, xx(min(e, size(xx, kind=int64)))) < real(c + 1_int64, real64))
         e = e + 1_int64
      enddo
      e = e - 1_int64 ! points b..e in column c
      if (e < b) cycle
      if (e - b + 1_int64 <= K) then
         ok = ok .and. all(is_kept(b:e))
         cycle
      endif
      ok = ok .and. count(is_kept(b:e)) <= nmax
      do q = 0_int64, SUB - 1_int64 ! each sixteenth: its first, last, lowest and highest kept
         lo = real(c, real64) + real(q, real64) / real(SUB, real64)
         hi = lo + 1.0_real64 / real(SUB, real64)
         pb = b
         do while (pb <= e .and. pix(a, xx(min(pb, size(xx, kind=int64)))) < lo)
            pb = pb + 1_int64
         enddo
         pe = pb
         do while (pe <= e .and. pix(a, xx(min(pe, size(xx, kind=int64)))) < hi)
            pe = pe + 1_int64
         enddo
         pe = pe - 1_int64
         if (pe < pb) cycle
         imin = pb - 1_int64 + minloc(yy(pb:pe), 1, kind=int64)
         imax = pb - 1_int64 + maxloc(yy(pb:pe), 1, kind=int64)
         ok = ok .and. is_kept(pb) .and. is_kept(pe) .and. is_kept(imin) .and. is_kept(imax)
      enddo
      if (fill) then ! the pair about the centre: j - 1, j with j the first at or right of it
         j = b
         do while (j <= e .and. pix(a, xx(min(j, size(xx, kind=int64)))) < real(c, real64) + 0.5_real64)
            j = j + 1_int64
         enddo
         if (j > b) ok = ok .and. is_kept(j - 1_int64)
         if (j <= e) ok = ok .and. is_kept(j)
      endif
      if (.not. ok) then
         write(output_unit, '(A,4(1X,I0))') 'columns_ok fails at column, b, e, kept: ', c, b, e, count(is_kept(b:e))
         return
      endif
   enddo
   endfunction columns_ok

   function off_plot_ok(xx, yy, kept, axis) result(ok)
   !< Invariant 2: off the plot area (and its margins), the first, last, lowest and highest points kept; the series'
   !< extremes the same.
   real(real64),        intent(in)           :: xx(:), yy(:) !< The series.
   integer(int64),      intent(in)           :: kept(:)      !< Indices kept.
   type(decimate_axis), intent(in), optional :: axis         !< Axis (default ax).
   logical                                   :: ok           !< Holds.
   type(decimate_axis)                       :: a            !< Axis.
   integer(int64)                            :: e, b         !< Last point left of the margin, first right of it.

   a = ax
   if (present(axis)) a = axis
   ok = kept(1) == 1_int64 .and. kept(size(kept)) == size(yy, kind=int64)
   ok = ok .and. minval(yy(kept)) == minval(yy) .and. maxval(yy(kept)) == maxval(yy)
   e = 0_int64 ! the margins: 4 pixels (the default reach, 2, and 2 more), then the areas reduced as one group each
   do while (pix(a, xx(e + 1_int64)) < 10.0_real64 - 4.0_real64)
      e = e + 1_int64
   enddo
   b = size(xx, kind=int64) + 1_int64
   do while (pix(a, xx(b - 1_int64)) >= 510.0_real64 + 4.0_real64)
      b = b - 1_int64
   enddo
   if (e > 0_int64) ok = ok .and. any(kept == 1_int64 - 1_int64 + minloc(yy(1:e), 1, kind=int64)) .and. &
                         any(kept == maxloc(yy(1:e), 1, kind=int64))
   if (b <= size(xx)) ok = ok .and. any(kept == b - 1_int64 + minloc(yy(b:), 1, kind=int64)) .and. &
                          any(kept == b - 1_int64 + maxloc(yy(b:), 1, kind=int64))
   if (.not. ok) write(output_unit, '(A,2(1X,I0))') 'off_plot_ok fails; margins end at ', e, b
   endfunction off_plot_ok

   function gap_ok(yy, kept, first, last) result(ok)
   !< Invariant 3: a run of NaNs first..last keeps one of them and the points on each side.
   real(real64),   intent(in) :: yy(:)       !< Ordinates.
   integer(int64), intent(in) :: kept(:)     !< Indices kept.
   integer(int64), intent(in) :: first, last !< The run.
   logical                    :: ok          !< Holds.
   integer(int64)             :: j           !< Counter.

   ok = any(kept == first - 1_int64) .and. any(kept == last + 1_int64)
   ok = ok .and. count([(any(kept == j), j = first, last)]) >= 1
   ok = ok .and. all(ieee_is_nan(yy(first:last)))
   if (.not. ok) write(output_unit, '(A,2(1X,I0))') 'gap_ok fails for the NaNs ', first, last
   endfunction gap_ok
endprogram figure_test_decimate
