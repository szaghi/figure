!< figure_decimate, the per-pixel decimation (M4) of long line-like series: the points that draw the same picture.
module figure_decimate
!< figure_decimate, the per-pixel decimation (M4) of long line-like series: the points that draw the same picture.
!<
!< A line of n points drawn w pixels wide with n >> w puts many points in each pixel column, and draws there a vertical
!< stroke from their minimum to their maximum. M4 (Jugel et al., VLDB 2014) keeps, per pixel column, the first point,
!< the last one, the minimum and the maximum, in their order: the strokes inside each column and the segments that join
!< two columns are the same, with at most 4 points per column (szaghi/figure#15, P4). That holds for lines one pixel
!< wide without anti-aliasing; ImPlot's lines are anti-aliased quads, and where a column's many overlapping strokes
!< lie inside it decides how it and its neighbours' edges are covered. FIGURE applies M4 to each sixteenth of a dense
!< column (SUB parts), at most 64 points a column. Measured against every point drawn (pixels off by more than 2 of
!< 255, and the largest difference): figure_test_plot_view's levels at 600 and 60 points per pixel, M4 per column 33005
!< (205), per quarter 3375 (82), per sixteenth 2248 (87); a steep line at 1700 points per pixel (cb_long_series, its
!< check box drawn checked in one picture only: 54 pixels), per column 38858 (7621 off by more than 96), per quarter
!< 15807 (2471), per eighth 12876 (206), per sixteenth 1167 (54), per 64th 304 (54).
!<
!< The decimation returns the indices of the points kept (ascending), so that an item gathers from each of its arrays
!< (abscissae, one or two ordinates) the same points; the arrays are read in place, any stride (assumed shape). The
!< pixel of an abscissa is computed as the plot's items compute it (ImPlot's `Transformer1`, linear, log10 or symlog
!< axis, rounded to a C float), from the axis given by `decimate_axis` (`fig_plot_x_transform`). The columns are the
!< display's pixels (the framebuffer scale applied). Rules:
!<
!< - only sorted abscissae (non-decreasing, no NaN) are decimated: otherwise `decimate` returns `.false.` and
!<   the item draws every point, as without decimation;
!< - nothing is decimated unless the series has more than DECIMATE_GATE * DECIMATE_THRESHOLD (256) points per pixel
!<   column of the plot area on average; then a column with at most DECIMATE_THRESHOLD (64) points keeps all of them
!<   (a sparse part of a dense series is drawn as without decimation), a denser one, in each of its sixteenths, its
!<   first, last, minimum and maximum (of each ordinate);
!< - the points left (right) of the plot area, a margin of a few pixels beyond its edge apart, form one group each,
!<   reduced to its first, last, minimum and maximum: off the picture, they keep the plot's fit (ImPlot fits the axes
!<   to the points it is given) and the segment that enters the plot;
!< - a NaN ordinate is a gap: the points on each side of it and one NaN of each run of NaNs are kept;
!< - `fill`: the points on each side of every pixel column's centre are kept too (and one more on each side, against
!<   a rounding of the pixel that differs from ImPlot's in the last bit): a filled area (shaded items, stairs and lines
!<   with the `Shaded` flag) covers a pixel when its centre is inside, so the area is the same at every centre.
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use, intrinsic :: ieee_arithmetic, only : ieee_is_nan

implicit none
private
public :: decimate_axis, decimate, DECIMATE_THRESHOLD, DECIMATE_LINEAR, DECIMATE_LOG10, DECIMATE_SYMLOG

integer(int32), parameter :: DECIMATE_THRESHOLD = 64_int32 !< Points per pixel column above which a column is decimated
                                                          !< (4 per sixteenth: fewer, M4 keeps them all).
integer(int32), parameter :: DECIMATE_LINEAR = 0_int32    !< Linear axis (ImPlot's linear and time scales).
integer(int32), parameter :: DECIMATE_LOG10 = 1_int32     !< Base 10 logarithmic axis.
integer(int32), parameter :: DECIMATE_SYMLOG = 2_int32    !< Symmetric logarithmic axis.
integer(int32), parameter :: GROUP_MAX = 24_int32         !< Indices a part of a column can keep (two ordinates, a fill).
integer(int64), parameter :: SUB = 16_int64               !< Parts of a dense pixel column reduced each on its own.
integer(int32), parameter :: DECIMATE_GATE = 4_int32      !< A series is decimated when it averages more than
                                                          !< DECIMATE_GATE * DECIMATE_THRESHOLD points a column: below,
                                                          !< what decimation saves ImPlot does not pay its own pass.

type :: decimate_axis
   !< An x axis as the items map an abscissa p to a pixel: pix_min + m (T(p) - plt_min), rounded to a C float, with
   !< T(p) = p on a linear axis, else plt_min + (plt_max - plt_min) (F(p) - sca_min) / (sca_max - sca_min), F the scale's
   !< forward transform (ImPlot's `Transformer1`).
   real(real64)   :: pix_min = 0.0_real64         !< Pixel of the range's minimum.
   real(real64)   :: plt_min = 0.0_real64         !< Range's minimum.
   real(real64)   :: plt_max = 1.0_real64         !< Range's maximum.
   real(real64)   :: m = 1.0_real64               !< Pixels per unit (per unit of T).
   real(real64)   :: sca_min = 0.0_real64         !< F of the range's minimum.
   real(real64)   :: sca_max = 1.0_real64         !< F of the range's maximum.
   real(real64)   :: left = 0.0_real64            !< Plot area's left edge [pixels].
   real(real64)   :: right = 0.0_real64           !< Plot area's right edge [pixels].
   real(real64)   :: fb_scale = 1.0_real64        !< Display pixels per pixel (the framebuffer scale).
   real(real64)   :: reach = 2.0_real64           !< How far a point draws beyond itself: half the line's weight and
                                                  !< its anti-aliasing fringe [pixels].
   integer(int32) :: scale = DECIMATE_LINEAR      !< DECIMATE_LINEAR, DECIMATE_LOG10 or DECIMATE_SYMLOG.
endtype decimate_axis

interface decimate
   !< The indices of the points of a series that draw it: `decimate(axis, x, y, keep, nkeep [, y2] [, fill])`,
   !< x and y `real32` or `real64` arrays of any stride; or `decimate(axis, x0, dx, y, keep, nkeep [, y2] [,
   !< fill])` for abscissae x0 + (i - 1) dx (computed as ImPlot does). `.false.`: not decimated, draw every point.
   module procedure decimate_r32, decimate_r64, decimate_uniform_r32, decimate_uniform_r64
endinterface decimate

! The columns' first indices, kept from call to call (the decimation runs on the main thread, as the items).
integer(int64), allocatable :: bound(:)  !< bound(k): first point in the pixel column k (or later).
integer(int64), allocatable :: centre(:) !< centre(k): first point at or right of the centre of column k.

contains
   function decimate_r64(axis, x, y, keep, nkeep, y2, fill) result(done)
   !< Decimate a series of `real(real64)` points (x(i), y(i)) (and y2(i)): `.true.` with the kept indices, else draw
   !< every point (unsorted x, too few points per column).
   type(decimate_axis),         intent(in)           :: axis     !< The x axis.
   real(real64),                intent(in)           :: x(:)     !< Abscissae, any stride.
   real(real64),                intent(in)           :: y(:)     !< Ordinates, any stride.
   integer(int64), allocatable, intent(inout)        :: keep(:)  !< Indices kept, ascending (grown when too short).
   integer(int64),              intent(out)          :: nkeep    !< Indices kept.
   real(real64),                intent(in), optional :: y2(:)    !< Second ordinates (a shaded item's), any stride.
   logical,                     intent(in), optional :: fill     !< Keep the points about each column's centre.
   logical                                           :: done     !< Decimated.
   integer(int64)                                    :: n        !< Points.
   integer(int64)                                    :: kmin     !< First column (the left margin's).
   integer(int64)                                    :: kmax     !< Last column (the right margin's).

   nkeep = 0_int64
   done = .false.
   n = size(y, kind=int64)
   if (.not. columns(axis, n, kmin, kmax)) return
   if (.not. sorted_r64(x)) return
   call bounds(kmin, kmax, n, opt_fill(fill), pixel_of)
   if (present(y2)) then
      call reduce_r64(kmin, kmax, n, y, keep, nkeep, opt_fill(fill), y2)
   else
      call reduce_r64(kmin, kmax, n, y, keep, nkeep, opt_fill(fill))
   endif
   done = .true.
   contains
      function pixel_of(j) result(p)
      !< Display pixel of point j.
      integer(int64), intent(in) :: j !< Point.
      real(real64)               :: p !< Pixel.

      p = pixel(axis, x(j))
      endfunction pixel_of
   endfunction decimate_r64

   function decimate_r32(axis, x, y, keep, nkeep, y2, fill) result(done)
   !< Decimate a series of `real(real32)` points (x(i), y(i)) (and y2(i)): `.true.` with the kept indices, else draw
   !< every point (unsorted x, too few points per column).
   type(decimate_axis),         intent(in)           :: axis     !< The x axis.
   real(real32),                intent(in)           :: x(:)     !< Abscissae, any stride.
   real(real32),                intent(in)           :: y(:)     !< Ordinates, any stride.
   integer(int64), allocatable, intent(inout)        :: keep(:)  !< Indices kept, ascending (grown when too short).
   integer(int64),              intent(out)          :: nkeep    !< Indices kept.
   real(real32),                intent(in), optional :: y2(:)    !< Second ordinates (a shaded item's), any stride.
   logical,                     intent(in), optional :: fill     !< Keep the points about each column's centre.
   logical                                           :: done     !< Decimated.
   integer(int64)                                    :: n        !< Points.
   integer(int64)                                    :: kmin     !< First column (the left margin's).
   integer(int64)                                    :: kmax     !< Last column (the right margin's).

   nkeep = 0_int64
   done = .false.
   n = size(y, kind=int64)
   if (.not. columns(axis, n, kmin, kmax)) return
   if (.not. sorted_r32(x)) return
   call bounds(kmin, kmax, n, opt_fill(fill), pixel_of)
   if (present(y2)) then
      call reduce_r32(kmin, kmax, n, y, keep, nkeep, opt_fill(fill), y2)
   else
      call reduce_r32(kmin, kmax, n, y, keep, nkeep, opt_fill(fill))
   endif
   done = .true.
   contains
      function pixel_of(j) result(p)
      !< Display pixel of point j (ImPlot reads a float abscissa as a double).
      integer(int64), intent(in) :: j !< Point.
      real(real64)               :: p !< Pixel.

      p = pixel(axis, real(x(j), real64))
      endfunction pixel_of
   endfunction decimate_r32

   function decimate_uniform_r64(axis, x0, dx, y, keep, nkeep, y2, fill) result(done)
   !< Decimate a series of `real(real64)` ordinates at x = x0 + (i - 1) dx: `.true.` with the kept indices, else draw
   !< every point (dx < 0, too few points per column).
   type(decimate_axis),         intent(in)           :: axis     !< The x axis.
   real(real64),                intent(in)           :: x0       !< First abscissa.
   real(real64),                intent(in)           :: dx       !< Spacing of the abscissae.
   real(real64),                intent(in)           :: y(:)     !< Ordinates, any stride.
   integer(int64), allocatable, intent(inout)        :: keep(:)  !< Indices kept, ascending (grown when too short).
   integer(int64),              intent(out)          :: nkeep    !< Indices kept.
   real(real64),                intent(in), optional :: y2(:)    !< Second ordinates, any stride.
   logical,                     intent(in), optional :: fill     !< Keep the points about each column's centre.
   logical                                           :: done     !< Decimated.
   integer(int64)                                    :: n        !< Points.
   integer(int64)                                    :: kmin     !< First column (the left margin's).
   integer(int64)                                    :: kmax     !< Last column (the right margin's).

   nkeep = 0_int64
   done = .false.
   n = size(y, kind=int64)
   if (ieee_is_nan(dx) .or. ieee_is_nan(x0)) return
   if (dx < 0.0_real64) return
   if (.not. columns(axis, n, kmin, kmax)) return
   call bounds(kmin, kmax, n, opt_fill(fill), pixel_of)
   if (present(y2)) then
      call reduce_r64(kmin, kmax, n, y, keep, nkeep, opt_fill(fill), y2)
   else
      call reduce_r64(kmin, kmax, n, y, keep, nkeep, opt_fill(fill))
   endif
   done = .true.
   contains
      function pixel_of(j) result(p)
      !< Display pixel of point j, its abscissa as ImPlot's `IndexerLin` computes it.
      integer(int64), intent(in) :: j !< Point.
      real(real64)               :: p !< Pixel.

      p = pixel(axis, dx * real(j - 1_int64, real64) + x0)
      endfunction pixel_of
   endfunction decimate_uniform_r64

   function decimate_uniform_r32(axis, x0, dx, y, keep, nkeep, y2, fill) result(done)
   !< Decimate a series of `real(real32)` ordinates at x = x0 + (i - 1) dx: `.true.` with the kept indices, else draw
   !< every point (dx < 0, too few points per column).
   type(decimate_axis),         intent(in)           :: axis     !< The x axis.
   real(real64),                intent(in)           :: x0       !< First abscissa.
   real(real64),                intent(in)           :: dx       !< Spacing of the abscissae.
   real(real32),                intent(in)           :: y(:)     !< Ordinates, any stride.
   integer(int64), allocatable, intent(inout)        :: keep(:)  !< Indices kept, ascending (grown when too short).
   integer(int64),              intent(out)          :: nkeep    !< Indices kept.
   real(real32),                intent(in), optional :: y2(:)    !< Second ordinates, any stride.
   logical,                     intent(in), optional :: fill     !< Keep the points about each column's centre.
   logical                                           :: done     !< Decimated.
   integer(int64)                                    :: n        !< Points.
   integer(int64)                                    :: kmin     !< First column (the left margin's).
   integer(int64)                                    :: kmax     !< Last column (the right margin's).

   nkeep = 0_int64
   done = .false.
   n = size(y, kind=int64)
   if (ieee_is_nan(dx) .or. ieee_is_nan(x0)) return
   if (dx < 0.0_real64) return
   if (.not. columns(axis, n, kmin, kmax)) return
   call bounds(kmin, kmax, n, opt_fill(fill), pixel_of)
   if (present(y2)) then
      call reduce_r32(kmin, kmax, n, y, keep, nkeep, opt_fill(fill), y2)
   else
      call reduce_r32(kmin, kmax, n, y, keep, nkeep, opt_fill(fill))
   endif
   done = .true.
   contains
      function pixel_of(j) result(p)
      !< Display pixel of point j, its abscissa as ImPlot's `IndexerLin` computes it.
      integer(int64), intent(in) :: j !< Point.
      real(real64)               :: p !< Pixel.

      p = pixel(axis, dx * real(j - 1_int64, real64) + x0)
      endfunction pixel_of
   endfunction decimate_uniform_r32

   ! the columns

   function columns(axis, n, kmin, kmax) result(ok)
   !< The display columns of the plot area and its margins, kmin to kmax; `.false.` when the series is too short to
   !< decimate (at most DECIMATE_GATE * DECIMATE_THRESHOLD points per column of the plot area) or the axis cannot be
   !< mapped.
   type(decimate_axis), intent(in)  :: axis !< The x axis.
   integer(int64),      intent(in)  :: n    !< Points.
   integer(int64),      intent(out) :: kmin !< First column.
   integer(int64),      intent(out) :: kmax !< Last column.
   logical                          :: ok   !< Decimate.
   real(real64)                     :: w    !< Plot area's width [display pixels].
   integer(int64)                   :: mg   !< Margin [columns].

   ok = .false.
   kmin = 0_int64
   kmax = -1_int64
   if (.not. (axis%m > 0.0_real64) .or. .not. (axis%fb_scale > 0.0_real64)) return ! an inverted or empty axis
   if (axis%scale /= DECIMATE_LINEAR .and. .not. (axis%sca_max > axis%sca_min)) return
   w = (axis%right - axis%left) * axis%fb_scale
   if (.not. (w >= 1.0_real64) .or. w > 1.0e6_real64) return
   if (real(n, real64) <= real(DECIMATE_GATE * DECIMATE_THRESHOLD, real64) * w) return
   mg = int(ceiling(axis%reach * axis%fb_scale), int64) + 2_int64
   kmin = int(floor(axis%left * axis%fb_scale), int64) - mg
   kmax = int(ceiling(axis%right * axis%fb_scale), int64) + mg - 1_int64
   ok = .true.
   endfunction columns

   subroutine bounds(kmin, kmax, n, fill, pixel_of)
   !< The first point of each part of the columns kmin..kmax + 1 (bound(SUB k + r), r = 0..SUB - 1: the column's r-th
   !< part of 1/SUB pixel) and, for a fill, the first point at or right of each column's centre (centre(k)): binary
   !< searches over the pixels, non-decreasing with the index.
   integer(int64), intent(in) :: kmin   !< First column.
   integer(int64), intent(in) :: kmax   !< Last column.
   integer(int64), intent(in) :: n      !< Points.
   logical,        intent(in) :: fill   !< The centres too.
   interface
      function pixel_of(j) result(p)
      !< Display pixel of point j.
      import :: int64, real64
      integer(int64), intent(in) :: j !< Point.
      real(real64)               :: p !< Pixel.
      endfunction pixel_of
   endinterface
   integer(int64)             :: k      !< Column.
   integer(int64)             :: lo     !< Search's start.

   call reserve(bound, SUB * kmin, SUB * (kmax + 1_int64))
   if (fill) call reserve(centre, kmin, kmax)
   lo = 1_int64
   do k = SUB * kmin, SUB * (kmax + 1_int64)
      lo = first_at(lo, real(k, real64) / real(SUB, real64))
      bound(k) = lo
   enddo
   if (.not. fill) return
   do k = kmin, kmax
      centre(k) = first_at(bound(SUB * k), real(k, real64) + 0.5_real64)
   enddo
   contains
      function first_at(from, p) result(j)
      !< First point from `from` on whose pixel is at least p (n + 1: none): a galloping search, then a binary one.
      integer(int64), intent(in) :: from !< First point searched.
      real(real64),   intent(in) :: p    !< Pixel.
      integer(int64)             :: j    !< Point.
      integer(int64)             :: hi   !< Search's end (excluded).
      integer(int64)             :: mid  !< Its middle.

      j = from
      hi = from + 1_int64 ! galloping: the bracket doubled from `from` (the columns' bounds are close to each other)
      do while (hi <= n)
         if (pixel_of(hi) >= p) exit
         j = hi + 1_int64
         hi = from + 2_int64 * (hi - from)
      enddo
      hi = min(hi, n + 1_int64)
      do while (j < hi)
         mid = j + (hi - j) / 2_int64
         if (pixel_of(mid) >= p) then
            hi = mid
         else
            j = mid + 1_int64
         endif
      enddo
      endfunction first_at
   endsubroutine bounds

   subroutine reserve(a, lo, hi)
   !< Make a(lo:hi) available: reallocated only when it does not cover the range (kept from call to call).
   integer(int64), allocatable, intent(inout) :: a(:) !< Array.
   integer(int64),              intent(in)    :: lo   !< First index needed.
   integer(int64),              intent(in)    :: hi   !< Last index needed.

   if (allocated(a)) then
      if (lbound(a, 1, kind=int64) <= lo .and. ubound(a, 1, kind=int64) >= hi) return
      deallocate(a)
   endif
   allocate(a(lo - 64_int64:hi + 64_int64))
   endsubroutine reserve

   ! the reduction of the ordinates

   subroutine reduce_r64(kmin, kmax, n, y, keep, nkeep, fill, y2)
   !< The kept indices of a `real(real64)` series, its columns known (`bounds`).
   integer(int64),              intent(in)           :: kmin    !< First column.
   integer(int64),              intent(in)           :: kmax    !< Last column.
   integer(int64),              intent(in)           :: n       !< Points.
   real(real64),                intent(in)           :: y(:)    !< Ordinates.
   integer(int64), allocatable, intent(inout)        :: keep(:) !< Indices kept.
   integer(int64),              intent(inout)        :: nkeep   !< Indices kept.
   logical,                     intent(in)           :: fill    !< Keep the points about each column's centre.
   real(real64),                intent(in), optional :: y2(:)   !< Second ordinates.
   integer(int64)                                    :: k       !< Column.
   integer(int64)                                    :: j       !< Part of a column.
   integer(int64)                                    :: c       !< First point at or right of its centre; 0 none.

   call group(1_int64, bound(SUB * kmin) - 1_int64, 0_int64)
   do k = kmin, kmax
      if (bound(SUB * (k + 1_int64)) - bound(SUB * k) <= int(DECIMATE_THRESHOLD, int64)) then
         call push_range(keep, nkeep, bound(SUB * k), bound(SUB * (k + 1_int64)) - 1_int64)
      else
         c = 0_int64
         if (fill) c = centre(k) ! not merge(): it would read centre, unallocated without a fill
         do j = SUB * k, SUB * k + SUB - 1_int64
            call group(bound(j), bound(j + 1_int64) - 1_int64, c)
         enddo
      endif
   enddo
   call group(bound(SUB * (kmax + 1_int64)), n, 0_int64)
   contains
      subroutine group(s, e, c)
      !< The kept indices of the points s..e of a part of a dense column (or of the area left or right of the plot).
      integer(int64), intent(in) :: s, e    !< First, last point.
      integer(int64), intent(in) :: c       !< First point at or right of the column's centre; 0 none.
      integer(int64)             :: cand(GROUP_MAX) !< Candidates.
      integer(int64)             :: nc      !< Candidates found.
      integer(int64)             :: i, r    !< Counters, run's first point.
      logical                    :: gap     !< A NaN found.

      if (e < s) return
      nc = 0_int64
      call extremes(s, e, cand, nc, gap)
      if (.not. gap) then
         call centres(s, e, c, cand, nc)
         call push_sorted(keep, nkeep, cand, nc)
         return
      endif
      ! NaNs: each run of numbers reduced, one NaN of each run of NaNs kept
      r = s
      do i = s, e
         if (nan_at(i)) then
            if (r < i) then
               nc = 0_int64
               call extremes(r, i - 1_int64, cand, nc, gap)
               call centres(r, i - 1_int64, c, cand, nc)
               call push_sorted(keep, nkeep, cand, nc)
            endif
            if (i == s) then
               call push_range(keep, nkeep, i, i)
            elseif (.not. nan_at(i - 1_int64)) then
               call push_range(keep, nkeep, i, i)
            endif
            r = i + 1_int64
         endif
      enddo
      if (r <= e) then
         nc = 0_int64
         call extremes(r, e, cand, nc, gap)
         call centres(r, e, c, cand, nc)
         call push_sorted(keep, nkeep, cand, nc)
      endif
      endsubroutine group

      function nan_at(i) result(nan)
      !< Whether point i has a NaN ordinate.
      integer(int64), intent(in) :: i      !< Point.
      logical                    :: nan    !< NaN.

      nan = ieee_is_nan(y(i))
      if (present(y2)) nan = nan .or. ieee_is_nan(y2(i))
      endfunction nan_at

      subroutine extremes(s, e, cand, nc, gap)
      !< First, last, minimum and maximum (of each ordinate) of the points s..e; whether one has a NaN.
      integer(int64), intent(in)    :: s, e       !< First, last point.
      integer(int64), intent(inout) :: cand(:)    !< Candidates.
      integer(int64), intent(inout) :: nc         !< Candidates found.
      logical,        intent(out)   :: gap        !< A NaN found.
      integer(int64)                :: imin, imax !< Minimum's, maximum's point.
      logical                       :: gap2       !< A NaN found in the second ordinates.

      call extremes_of_r64(y, s, e, imin, imax, gap)
      call add(cand, nc, s)
      call add(cand, nc, imin)
      call add(cand, nc, imax)
      call add(cand, nc, e)
      if (present(y2)) then
         call extremes_of_r64(y2, s, e, imin, imax, gap2)
         call add(cand, nc, imin)
         call add(cand, nc, imax)
         gap = gap .or. gap2
      endif
      endsubroutine extremes
   endsubroutine reduce_r64

   subroutine reduce_r32(kmin, kmax, n, y, keep, nkeep, fill, y2)
   !< The kept indices of a `real(real32)` series, its columns known (`bounds`).
   integer(int64),              intent(in)           :: kmin    !< First column.
   integer(int64),              intent(in)           :: kmax    !< Last column.
   integer(int64),              intent(in)           :: n       !< Points.
   real(real32),                intent(in)           :: y(:)    !< Ordinates.
   integer(int64), allocatable, intent(inout)        :: keep(:) !< Indices kept.
   integer(int64),              intent(inout)        :: nkeep   !< Indices kept.
   logical,                     intent(in)           :: fill    !< Keep the points about each column's centre.
   real(real32),                intent(in), optional :: y2(:)   !< Second ordinates.
   integer(int64)                                    :: k       !< Column.
   integer(int64)                                    :: j       !< Part of a column.
   integer(int64)                                    :: c       !< First point at or right of its centre; 0 none.

   call group(1_int64, bound(SUB * kmin) - 1_int64, 0_int64)
   do k = kmin, kmax
      if (bound(SUB * (k + 1_int64)) - bound(SUB * k) <= int(DECIMATE_THRESHOLD, int64)) then
         call push_range(keep, nkeep, bound(SUB * k), bound(SUB * (k + 1_int64)) - 1_int64)
      else
         c = 0_int64
         if (fill) c = centre(k) ! not merge(): it would read centre, unallocated without a fill
         do j = SUB * k, SUB * k + SUB - 1_int64
            call group(bound(j), bound(j + 1_int64) - 1_int64, c)
         enddo
      endif
   enddo
   call group(bound(SUB * (kmax + 1_int64)), n, 0_int64)
   contains
      subroutine group(s, e, c)
      !< The kept indices of the points s..e of a part of a dense column (or of the area left or right of the plot).
      integer(int64), intent(in) :: s, e    !< First, last point.
      integer(int64), intent(in) :: c       !< First point at or right of the column's centre; 0 none.
      integer(int64)             :: cand(GROUP_MAX) !< Candidates.
      integer(int64)             :: nc      !< Candidates found.
      integer(int64)             :: i, r    !< Counters, run's first point.
      logical                    :: gap     !< A NaN found.

      if (e < s) return
      nc = 0_int64
      call extremes(s, e, cand, nc, gap)
      if (.not. gap) then
         call centres(s, e, c, cand, nc)
         call push_sorted(keep, nkeep, cand, nc)
         return
      endif
      ! NaNs: each run of numbers reduced, one NaN of each run of NaNs kept
      r = s
      do i = s, e
         if (nan_at(i)) then
            if (r < i) then
               nc = 0_int64
               call extremes(r, i - 1_int64, cand, nc, gap)
               call centres(r, i - 1_int64, c, cand, nc)
               call push_sorted(keep, nkeep, cand, nc)
            endif
            if (i == s) then
               call push_range(keep, nkeep, i, i)
            elseif (.not. nan_at(i - 1_int64)) then
               call push_range(keep, nkeep, i, i)
            endif
            r = i + 1_int64
         endif
      enddo
      if (r <= e) then
         nc = 0_int64
         call extremes(r, e, cand, nc, gap)
         call centres(r, e, c, cand, nc)
         call push_sorted(keep, nkeep, cand, nc)
      endif
      endsubroutine group

      function nan_at(i) result(nan)
      !< Whether point i has a NaN ordinate.
      integer(int64), intent(in) :: i      !< Point.
      logical                    :: nan    !< NaN.

      nan = ieee_is_nan(y(i))
      if (present(y2)) nan = nan .or. ieee_is_nan(y2(i))
      endfunction nan_at

      subroutine extremes(s, e, cand, nc, gap)
      !< First, last, minimum and maximum (of each ordinate) of the points s..e; whether one has a NaN.
      integer(int64), intent(in)    :: s, e       !< First, last point.
      integer(int64), intent(inout) :: cand(:)    !< Candidates.
      integer(int64), intent(inout) :: nc         !< Candidates found.
      logical,        intent(out)   :: gap        !< A NaN found.
      integer(int64)                :: imin, imax !< Minimum's, maximum's point.
      logical                       :: gap2       !< A NaN found in the second ordinates.

      call extremes_of_r32(y, s, e, imin, imax, gap)
      call add(cand, nc, s)
      call add(cand, nc, imin)
      call add(cand, nc, imax)
      call add(cand, nc, e)
      if (present(y2)) then
         call extremes_of_r32(y2, s, e, imin, imax, gap2)
         call add(cand, nc, imin)
         call add(cand, nc, imax)
         gap = gap .or. gap2
      endif
      endsubroutine extremes
   endsubroutine reduce_r32

   function sorted_r64(x) result(ok)
   !< Whether abscissae are sorted (non-decreasing, no NaN).
   real(real64), intent(in) :: x(:) !< Abscissae, any stride.
   logical                  :: ok   !< Sorted.
   integer(int64)           :: i    !< Counter.

   ok = .false.
   if (size(x) > 0) then
      if (ieee_is_nan(x(1))) return
   endif
   do i = 2_int64, size(x, kind=int64) ! NaNs tested first: an ordered comparison with a NaN raises IEEE invalid
      if (ieee_is_nan(x(i))) return
      if (x(i) < x(i - 1_int64)) return ! unsorted
   enddo
   ok = .true.
   endfunction sorted_r64

   function sorted_r32(x) result(ok)
   !< Whether abscissae are sorted (non-decreasing, no NaN).
   real(real32), intent(in) :: x(:) !< Abscissae, any stride.
   logical                  :: ok   !< Sorted.
   integer(int64)           :: i    !< Counter.

   ok = .false.
   if (size(x) > 0) then
      if (ieee_is_nan(x(1))) return
   endif
   do i = 2_int64, size(x, kind=int64) ! NaNs tested first: an ordered comparison with a NaN raises IEEE invalid
      if (ieee_is_nan(x(i))) return
      if (x(i) < x(i - 1_int64)) return ! unsorted
   enddo
   ok = .true.
   endfunction sorted_r32

   subroutine extremes_of_r64(y, s, e, imin, imax, gap)
   !< The points of the minimum and of the maximum of y(s:e) (the first of equal ones; 0 when all are NaN), and
   !< whether one is NaN.
   real(real64),   intent(in)  :: y(:)       !< Ordinates.
   integer(int64), intent(in)  :: s, e       !< First, last point.
   integer(int64), intent(out) :: imin, imax !< Minimum's, maximum's point.
   logical,        intent(out) :: gap        !< A NaN found.
   real(real64)                :: v          !< A value.
   real(real64)                :: vmin, vmax !< Minimum, maximum so far.
   integer(int64)              :: i          !< Counter.
   integer(int64)              :: valid      !< Values that are numbers.

   imin = 0_int64
   imax = 0_int64
   vmin = huge(1.0_real64)
   vmax = -huge(1.0_real64)
   valid = 0_int64
   do i = s, e ! NaNs tested first: an ordered comparison with a NaN raises IEEE invalid (a trap under -ffpe-trap)
      v = y(i)
      if (ieee_is_nan(v)) cycle
      valid = valid + 1_int64
      if (v < vmin) then
         vmin = v
         imin = i
      endif
      if (v > vmax) then
         vmax = v
         imax = i
      endif
   enddo
   gap = valid < e - s + 1_int64
   if (imin == 0_int64 .and. valid > 0_int64) imin = first_equal_r64(y, s, e, vmin) ! every number is +huge
   if (imax == 0_int64 .and. valid > 0_int64) imax = first_equal_r64(y, s, e, vmax) ! every number is -huge
   endsubroutine extremes_of_r64

   subroutine extremes_of_r32(y, s, e, imin, imax, gap)
   !< The points of the minimum and of the maximum of y(s:e) (the first of equal ones; 0 when all are NaN), and
   !< whether one is NaN.
   real(real32),   intent(in)  :: y(:)       !< Ordinates.
   integer(int64), intent(in)  :: s, e       !< First, last point.
   integer(int64), intent(out) :: imin, imax !< Minimum's, maximum's point.
   logical,        intent(out) :: gap        !< A NaN found.
   real(real32)                :: v          !< A value.
   real(real32)                :: vmin, vmax !< Minimum, maximum so far.
   integer(int64)              :: i          !< Counter.
   integer(int64)              :: valid      !< Values that are numbers.

   imin = 0_int64
   imax = 0_int64
   vmin = huge(1.0_real32)
   vmax = -huge(1.0_real32)
   valid = 0_int64
   do i = s, e ! NaNs tested first: an ordered comparison with a NaN raises IEEE invalid (a trap under -ffpe-trap)
      v = y(i)
      if (ieee_is_nan(v)) cycle
      valid = valid + 1_int64
      if (v < vmin) then
         vmin = v
         imin = i
      endif
      if (v > vmax) then
         vmax = v
         imax = i
      endif
   enddo
   gap = valid < e - s + 1_int64
   if (imin == 0_int64 .and. valid > 0_int64) imin = first_equal_r32(y, s, e, vmin) ! every number is +huge
   if (imax == 0_int64 .and. valid > 0_int64) imax = first_equal_r32(y, s, e, vmax) ! every number is -huge
   endsubroutine extremes_of_r32

   function first_equal_r64(y, s, e, v) result(j)
   !< The first point of y(s:e) equal to v (s when none).
   real(real64),   intent(in) :: y(:) !< Ordinates.
   integer(int64), intent(in) :: s, e !< First, last point.
   real(real64),   intent(in) :: v    !< Value.
   integer(int64)             :: j    !< Point.

   do j = s, e
      if (y(j) == v) return
   enddo
   j = s
   endfunction first_equal_r64

   function first_equal_r32(y, s, e, v) result(j)
   !< The first point of y(s:e) equal to v (s when none).
   real(real32),   intent(in) :: y(:) !< Ordinates.
   integer(int64), intent(in) :: s, e !< First, last point.
   real(real32),   intent(in) :: v    !< Value.
   integer(int64)             :: j    !< Point.

   do j = s, e
      if (y(j) == v) return
   enddo
   j = s
   endfunction first_equal_r32

   ! the kept indices

   subroutine centres(s, e, c, cand, nc)
   !< For a fill, the points about the column's centre that fall in s..e: c - 2 to c + 1 (c the first point at or
   !< right of the centre: the pair c - 1, c straddles it, one more on each side against a last-bit rounding).
   integer(int64), intent(in)    :: s, e    !< First, last point.
   integer(int64), intent(in)    :: c       !< First point at or right of the centre; 0 none.
   integer(int64), intent(inout) :: cand(:) !< Candidates.
   integer(int64), intent(inout) :: nc      !< Candidates found.
   integer(int64)                :: j       !< Point.

   if (c <= 0_int64) return
   do j = max(s, c - 2_int64), min(e, c + 1_int64)
      call add(cand, nc, j)
   enddo
   endsubroutine centres

   pure subroutine add(cand, nc, j)
   !< A candidate, kept sorted and without repetitions (insertion: a few per column); 0 ignored.
   integer(int64), intent(inout) :: cand(:) !< Candidates, ascending.
   integer(int64), intent(inout) :: nc      !< Candidates.
   integer(int64), intent(in)    :: j       !< Point.
   integer(int64)                :: p       !< Position.

   if (j <= 0_int64) return
   p = nc
   do while (p > 0_int64)
      if (cand(p) < j) exit
      if (cand(p) == j) return
      p = p - 1_int64
   enddo
   cand(p + 2_int64:nc + 1_int64) = cand(p + 1_int64:nc)
   cand(p + 1_int64) = j
   nc = nc + 1_int64
   endsubroutine add

   subroutine push_sorted(keep, nkeep, cand, nc)
   !< Append the candidates (ascending) to the kept indices.
   integer(int64), allocatable, intent(inout) :: keep(:) !< Indices kept.
   integer(int64),              intent(inout) :: nkeep   !< Indices kept.
   integer(int64),              intent(in)    :: cand(:) !< Candidates.
   integer(int64),              intent(in)    :: nc      !< Candidates.

   call grow(keep, nkeep + nc)
   keep(nkeep + 1_int64:nkeep + nc) = cand(1_int64:nc)
   nkeep = nkeep + nc
   endsubroutine push_sorted

   subroutine push_range(keep, nkeep, s, e)
   !< Append the points s..e to the kept indices.
   integer(int64), allocatable, intent(inout) :: keep(:) !< Indices kept.
   integer(int64),              intent(inout) :: nkeep   !< Indices kept.
   integer(int64),              intent(in)    :: s, e    !< First, last point.
   integer(int64)                             :: j       !< Point.

   call grow(keep, nkeep + e - s + 1_int64)
   do j = s, e
      keep(nkeep + j - s + 1_int64) = j
   enddo
   nkeep = nkeep + e - s + 1_int64
   endsubroutine push_range

   subroutine grow(keep, need)
   !< Make the kept indices hold at least `need` (grown by half again, the indices kept).
   integer(int64), allocatable, intent(inout) :: keep(:) !< Indices kept.
   integer(int64),              intent(in)    :: need    !< Size needed.
   integer(int64), allocatable                :: more(:) !< The larger array.
   integer(int64)                             :: c       !< Capacity.

   c = 0_int64
   if (allocated(keep)) c = size(keep, kind=int64)
   if (c >= need) return
   allocate(more(max(need, c + c / 2_int64, 1024_int64)))
   if (c > 0_int64) more(1_int64:c) = keep
   call move_alloc(more, keep)
   endsubroutine grow

   ! the pixels

   function pixel(axis, p) result(px)
   !< Display pixel of an abscissa: as ImPlot's `Transformer1` (the scale's transform, then rounded to a C float), times
   !< the framebuffer scale.
   type(decimate_axis), intent(in) :: axis !< The x axis.
   real(real64),        intent(in) :: p    !< Abscissa.
   real(real64)                    :: px   !< Pixel.
   real(real64)                    :: q    !< The abscissa through the scale.
   real(real64)                    :: s    !< Its forward transform.

   select case (axis%scale)
   case (DECIMATE_LOG10)
      s = log10(merge(tiny(1.0_real64), p, p <= 0.0_real64))
      q = axis%plt_min + (axis%plt_max - axis%plt_min) * ((s - axis%sca_min) / (axis%sca_max - axis%sca_min))
   case (DECIMATE_SYMLOG)
      s = 2.0_real64 * asinh(p / 2.0_real64)
      q = axis%plt_min + (axis%plt_max - axis%plt_min) * ((s - axis%sca_min) / (axis%sca_max - axis%sca_min))
   case default
      q = p
   endselect
   px = real(real(axis%pix_min + axis%m * (q - axis%plt_min), real32), real64) * axis%fb_scale
   endfunction pixel

   pure function opt_fill(fill) result(f)
   !< An optional `fill`, default false.
   logical, intent(in), optional :: fill !< Given.
   logical                       :: f    !< Value.

   f = .false.
   if (present(fill)) f = fill
   endfunction opt_fill
endmodule figure_decimate
