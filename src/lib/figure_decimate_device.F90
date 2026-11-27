!< figure_decimate_device, the decimation of a series that lives on a device (#15 P6): the kernels run where the data are.

#include "fundal.H"

module figure_decimate_device
!< figure_decimate_device, the decimation of a series that lives on a device (#15 P6): the kernels run where the data are.
!<
!< A series the program keeps on a GPU (FUNDAL's `dev_alloc`, or OpenACC device memory) is decimated there by the rules
!< of `figure_decimate` (M4 per sixteenth of a pixel column, a column of at most DECIMATE_THRESHOLD points kept whole,
!< the points off the plot reduced to their extremes, a NaN a gap), and only the points kept, at most 64 a pixel
!< column, are copied to the host. The kernels are written once with FUNDAL's macros (`fundal.H`): OpenACC with
!< nvfortran (`-acc -DDEV_OAC -DCOMPILER_NVF`), OpenMP offload (`-DDEV_OMP`), and FUNDAL's CPU mode otherwise, where
!< the device is the host and the kernels are loops (threaded when OpenMP is on). The work arrays are FUNDAL's device
!< memory, kept from call to call and grown when too short; the program's arrays are only read.
!<
!< Device code: no pointer of a module is referenced in a kernel (each is passed to the kernel's procedure as a dummy,
!< DEVICEVAR), no allocatable, no array private to a thread; scalars only, and ordered comparisons made after the NaN
!< tests (`v /= v`, quiet).
!<
!< One difference from the host: within a sixteenth of a column, the NaNs between its first and its last NaN count as
!< one gap (less than a sixteenth of a pixel wide).
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use fundal, only : dev_alloc, dev_free, dev_memcpy_from_device, dev_memcpy_to_device
use figure_decimate, only : decimate_axis, decimate_columns, DECIMATE_LOG10, DECIMATE_SYMLOG, DECIMATE_PARTS, &
                            DECIMATE_THRESHOLD

implicit none
private
public :: decimate_device_r32, decimate_device_r64

integer(int64), parameter :: PER_PART = 4_int64 !< Per part: lowest, highest, first NaN, last NaN.

! The device's work arrays (FUNDAL's device memory), kept from call to call, grown when too short.
integer(int64), pointer :: d_bound(:) => null()  !< First point of each part, and of the area right of the last one.
integer(int64), pointer :: d_ext(:) => null()    !< Per part (PER_PART each): lowest, highest, first NaN, last NaN (0 none).
integer(int64), pointer :: d_keep(:) => null()   !< The points kept, to gather.
real(real64),   pointer :: d_v64(:) => null()    !< Their abscissae then ordinates (double precision).
real(real32),   pointer :: d_v32(:) => null()    !< Their abscissae then ordinates (single precision).
integer(int64)          :: cap_parts = 0_int64   !< Parts the work arrays hold.
integer(int64)          :: cap_keep = 0_int64    !< Points d_keep holds.
integer(int64)          :: cap_v64 = 0_int64     !< Values d_v64 holds.
integer(int64)          :: cap_v32 = 0_int64     !< Values d_v32 holds.
! ... and the host's.
integer(int64), allocatable :: h_bound(:) !< First point of each part.
integer(int64), allocatable :: h_ext(:)   !< Per part: lowest, highest, first NaN, last NaN.
integer(int64), allocatable :: h_keep(:)  !< The points kept.

contains
   function decimate_device_r64(axis, x, y, xk, yk, nk, ierr) result(done)
   !< Decimate a device-resident series of `real(real64)` points: `.true.` with the points kept, copied to the host;
   !< `.false.` (nothing set): too short, unsorted, or a device error (`ierr` /= 0).
   type(decimate_axis),       intent(in)                     :: axis  !< The x axis.
   real(real64),              intent(in), target             :: x(:)  !< Abscissae, on the device.
   real(real64),              intent(in), target             :: y(:)  !< Ordinates, on the device.
   real(real64), allocatable, intent(inout)                  :: xk(:) !< Abscissae kept (grown when too short).
   real(real64), allocatable, intent(inout)                  :: yk(:) !< Ordinates kept.
   integer(int64),            intent(out)                    :: nk    !< Points kept.
   integer(int32),            intent(out)                    :: ierr  !< FUNDAL's status (0 fine).
   logical                                                   :: done  !< Decimated.
   integer(int64)                                            :: n     !< Points.
   integer(int64)                                            :: kmin, kmax !< Columns.
   integer(int64)                                            :: np    !< Parts.
   integer(int64)                                            :: lo(2), hi(2) !< Extremes left and right of the plot.

   done = .false.
   nk = 0_int64
   ierr = 0_int32
   n = size(y, kind=int64)
   if (size(x, kind=int64) /= n) return
   if (.not. decimate_columns(axis, n, kmin, kmax)) return
   if (unsorted_r64(n, x) > 0_int64) return
   np = DECIMATE_PARTS * (kmax - kmin + 1_int64)
   call reserve_parts(np, ierr)
   if (ierr /= 0_int32) return
   call bounds_r64(axis, n, x, DECIMATE_PARTS * kmin, np, d_bound)
   call parts_r64(n, y, np, d_bound, d_ext)
   call dev_memcpy_from_device(dst=h_bound(1:np + 1_int64), src=d_bound(1:np + 1_int64), ierr=ierr)
   if (ierr == 0_int32) call dev_memcpy_from_device(dst=h_ext(1:PER_PART * np), src=d_ext(1:PER_PART * np), ierr=ierr)
   if (ierr /= 0_int32) return
   call range_r64(n, y, 1_int64, h_bound(1) - 1_int64, lo(1), hi(1))
   call range_r64(n, y, h_bound(np + 1_int64), n, lo(2), hi(2))
   call kept_points(n, np, lo, hi, nk)
   call reserve_keep(nk, ierr)
   if (ierr == 0_int32) call reserve_v64(2_int64 * nk, ierr)
   if (ierr == 0_int32) call dev_memcpy_to_device(dst=d_keep(1:nk), src=h_keep(1:nk), ierr=ierr)
   if (ierr /= 0_int32) return
   call gather_r64(n, x, y, nk, d_keep, d_v64)
   if (allocated(xk)) then
      if (size(xk, kind=int64) < nk) deallocate(xk)
   endif
   if (allocated(yk)) then
      if (size(yk, kind=int64) < nk) deallocate(yk)
   endif
   if (.not. allocated(xk)) allocate(xk(max(nk, 1024_int64)))
   if (.not. allocated(yk)) allocate(yk(max(nk, 1024_int64)))
   call dev_memcpy_from_device(dst=xk(1:nk), src=d_v64(1:nk), ierr=ierr)
   if (ierr == 0_int32) call dev_memcpy_from_device(dst=yk(1:nk), src=d_v64(nk + 1_int64:2_int64 * nk), ierr=ierr)
   done = ierr == 0_int32
   endfunction decimate_device_r64

   function decimate_device_r32(axis, x, y, xk, yk, nk, ierr) result(done)
   !< Decimate a device-resident series of `real(real32)` points: `.true.` with the points kept, copied to the host;
   !< `.false.` (nothing set): too short, unsorted, or a device error (`ierr` /= 0).
   type(decimate_axis),       intent(in)                     :: axis  !< The x axis.
   real(real32),              intent(in), target             :: x(:)  !< Abscissae, on the device.
   real(real32),              intent(in), target             :: y(:)  !< Ordinates, on the device.
   real(real32), allocatable, intent(inout)                  :: xk(:) !< Abscissae kept (grown when too short).
   real(real32), allocatable, intent(inout)                  :: yk(:) !< Ordinates kept.
   integer(int64),            intent(out)                    :: nk    !< Points kept.
   integer(int32),            intent(out)                    :: ierr  !< FUNDAL's status (0 fine).
   logical                                                   :: done  !< Decimated.
   integer(int64)                                            :: n     !< Points.
   integer(int64)                                            :: kmin, kmax !< Columns.
   integer(int64)                                            :: np    !< Parts.
   integer(int64)                                            :: lo(2), hi(2) !< Extremes left and right of the plot.

   done = .false.
   nk = 0_int64
   ierr = 0_int32
   n = size(y, kind=int64)
   if (size(x, kind=int64) /= n) return
   if (.not. decimate_columns(axis, n, kmin, kmax)) return
   if (unsorted_r32(n, x) > 0_int64) return
   np = DECIMATE_PARTS * (kmax - kmin + 1_int64)
   call reserve_parts(np, ierr)
   if (ierr /= 0_int32) return
   call bounds_r32(axis, n, x, DECIMATE_PARTS * kmin, np, d_bound)
   call parts_r32(n, y, np, d_bound, d_ext)
   call dev_memcpy_from_device(dst=h_bound(1:np + 1_int64), src=d_bound(1:np + 1_int64), ierr=ierr)
   if (ierr == 0_int32) call dev_memcpy_from_device(dst=h_ext(1:PER_PART * np), src=d_ext(1:PER_PART * np), ierr=ierr)
   if (ierr /= 0_int32) return
   call range_r32(n, y, 1_int64, h_bound(1) - 1_int64, lo(1), hi(1))
   call range_r32(n, y, h_bound(np + 1_int64), n, lo(2), hi(2))
   call kept_points(n, np, lo, hi, nk)
   call reserve_keep(nk, ierr)
   if (ierr == 0_int32) call reserve_v32(2_int64 * nk, ierr)
   if (ierr == 0_int32) call dev_memcpy_to_device(dst=d_keep(1:nk), src=h_keep(1:nk), ierr=ierr)
   if (ierr /= 0_int32) return
   call gather_r32(n, x, y, nk, d_keep, d_v32)
   if (allocated(xk)) then
      if (size(xk, kind=int64) < nk) deallocate(xk)
   endif
   if (allocated(yk)) then
      if (size(yk, kind=int64) < nk) deallocate(yk)
   endif
   if (.not. allocated(xk)) allocate(xk(max(nk, 1024_int64)))
   if (.not. allocated(yk)) allocate(yk(max(nk, 1024_int64)))
   call dev_memcpy_from_device(dst=xk(1:nk), src=d_v32(1:nk), ierr=ierr)
   if (ierr == 0_int32) call dev_memcpy_from_device(dst=yk(1:nk), src=d_v32(nk + 1_int64:2_int64 * nk), ierr=ierr)
   done = ierr == 0_int32
   endfunction decimate_device_r32

   ! the kernels, double precision

   function unsorted_r64(n, x) result(bad)
   !< Points out of order (a NaN, or less than the one before): 0 for sorted abscissae.
   integer(int64), intent(in)         :: n    !< Points.
   real(real64),   intent(in), target :: x(:) !< Abscissae, on the device.
   integer(int64)                     :: bad  !< Points out of order.
   integer(int64)                     :: i    !< Counter.

   bad = 0_int64
   !$acc parallel loop gang vector reduction(+:bad) DEVICEVAR(x)
   !$omp OMPLOOP reduction(+:bad) DEVICEPTR(x)
   do i = 1_int64, n
      if (x(i) /= x(i)) then
         bad = bad + 1_int64
      elseif (i > 1_int64) then
         if (x(i - 1_int64) == x(i - 1_int64)) then
            if (x(i) < x(i - 1_int64)) bad = bad + 1_int64
         endif
      endif
   enddo
   endfunction unsorted_r64

   subroutine bounds_r64(axis, n, x, j0, np, bnd)
   !< bnd(j) the first point at or right of the part j0 + j - 1's left edge (pixel (j0 + j - 1) / DECIMATE_PARTS), for
   !< j = 1..np + 1: a binary search per part, on the device.
   type(decimate_axis), intent(in)         :: axis   !< The x axis.
   integer(int64),      intent(in)         :: n      !< Points.
   real(real64),        intent(in), target :: x(:)   !< Abscissae, on the device.
   integer(int64),      intent(in)         :: j0     !< First part.
   integer(int64),      intent(in)         :: np     !< Parts.
   integer(int64),      intent(inout), target :: bnd(:) !< First points, on the device.
   real(real64)                            :: a(6)   !< The axis's transform.
   integer(int32)                          :: sc     !< Its scale.
   real(real64)                            :: fb     !< Framebuffer scale.
   real(real64)                            :: t      !< A part's left edge [pixels].
   integer(int64)                          :: j, lo, hi, mid !< Part, search.

   a = [axis%pix_min, axis%plt_min, axis%plt_max, axis%m, axis%sca_min, axis%sca_max]
   sc = axis%scale
   fb = axis%fb_scale
   !$acc parallel loop gang vector private(t, lo, hi, mid) copyin(a) DEVICEVAR(x, bnd)
   !$omp OMPLOOP private(t, lo, hi, mid) DEVICEPTR(x, bnd)
   do j = 1_int64, np + 1_int64
      t = real(j0 + j - 1_int64, real64) / real(DECIMATE_PARTS, real64)
      lo = 1_int64
      hi = n + 1_int64
      do while (lo < hi)
         mid = lo + (hi - lo) / 2_int64
         if (pixel(sc, a, fb, x(mid)) >= t) then
            hi = mid
         else
            lo = mid + 1_int64
         endif
      enddo
      bnd(j) = lo
   enddo
   endsubroutine bounds_r64

   subroutine parts_r64(n, y, np, bnd, ext)
   !< Per part: its lowest and highest point (the first of equal ones; 0 when every value is NaN), its first and last
   !< NaN (0 none): a gang per part, its points shared by the vector lanes.
   integer(int64), intent(in)            :: n      !< Points.
   real(real64),   intent(in), target    :: y(:)   !< Ordinates, on the device.
   integer(int64), intent(in)            :: np     !< Parts.
   integer(int64), intent(in), target    :: bnd(:) !< First points, on the device.
   integer(int64), intent(inout), target :: ext(:) !< Extremes, on the device.
   real(real64)                          :: v, vmin, vmax !< A value, the lowest, the highest.
   integer(int64)                        :: j, i, s, e     !< Part, point, the part's first and last.
   integer(int64)                        :: imin, imax, n1, n2 !< Lowest's, highest's point, first and last NaN.

   !$acc parallel loop gang private(s, e, vmin, vmax, imin, imax, n1, n2) DEVICEVAR(y, bnd, ext)
   !$omp OMPLOOP private(s, e, v, vmin, vmax, imin, imax, n1, n2, i) DEVICEPTR(y, bnd, ext)
   do j = 1_int64, np
      s = bnd(j)
      e = min(bnd(j + 1_int64) - 1_int64, n)
      vmin = huge(1.0_real64)
      vmax = -huge(1.0_real64)
      !$acc loop vector reduction(min:vmin) reduction(max:vmax) private(v)
      do i = s, e
         v = y(i)
         if (v == v) then
            vmin = min(vmin, v)
            vmax = max(vmax, v)
         endif
      enddo
      imin = e + 1_int64
      imax = e + 1_int64
      n1 = e + 1_int64
      n2 = 0_int64
      !$acc loop vector reduction(min:imin, imax, n1) reduction(max:n2) private(v)
      do i = s, e
         v = y(i)
         if (v == v) then
            if (v == vmin) imin = min(imin, i)
            if (v == vmax) imax = min(imax, i)
         else
            n1 = min(n1, i)
            n2 = max(n2, i)
         endif
      enddo
      ext(PER_PART * (j - 1_int64) + 1_int64) = merge(imin, 0_int64, imin <= e)
      ext(PER_PART * (j - 1_int64) + 2_int64) = merge(imax, 0_int64, imax <= e)
      ext(PER_PART * (j - 1_int64) + 3_int64) = merge(n1, 0_int64, n1 <= e)
      ext(PER_PART * (j - 1_int64) + 4_int64) = n2
   enddo
   endsubroutine parts_r64

   subroutine range_r64(n, y, s, e, imin, imax)
   !< The lowest and highest point of y(s:e) (the first of equal ones; 0 none): a reduction over the whole device.
   integer(int64), intent(in)         :: n          !< Points.
   real(real64),   intent(in), target :: y(:)       !< Ordinates, on the device.
   integer(int64), intent(in)         :: s, e       !< First, last point.
   integer(int64), intent(out)        :: imin, imax !< Lowest's, highest's point.
   real(real64)                       :: v, vmin, vmax !< A value, the lowest, the highest.
   integer(int64)                     :: i          !< Point.

   imin = 0_int64
   imax = 0_int64
   if (e < s .or. e > n) return
   vmin = huge(1.0_real64)
   vmax = -huge(1.0_real64)
   !$acc parallel loop gang vector reduction(min:vmin) reduction(max:vmax) private(v) DEVICEVAR(y)
   !$omp OMPLOOP reduction(min:vmin) reduction(max:vmax) private(v) DEVICEPTR(y)
   do i = s, e
      v = y(i)
      if (v == v) then
         vmin = min(vmin, v)
         vmax = max(vmax, v)
      endif
   enddo
   imin = e + 1_int64
   imax = e + 1_int64
   !$acc parallel loop gang vector reduction(min:imin, imax) private(v) DEVICEVAR(y)
   !$omp OMPLOOP reduction(min:imin, imax) private(v) DEVICEPTR(y)
   do i = s, e
      v = y(i)
      if (v == v) then
         if (v == vmin) imin = min(imin, i)
         if (v == vmax) imax = min(imax, i)
      endif
   enddo
   if (imin > e) imin = 0_int64
   if (imax > e) imax = 0_int64
   endsubroutine range_r64

   subroutine gather_r64(n, x, y, nk, keep, v)
   !< v(1:nk) the abscissae of the points kept, v(nk+1:2 nk) their ordinates, on the device.
   integer(int64), intent(in)            :: n       !< Points.
   real(real64),   intent(in), target    :: x(:)    !< Abscissae, on the device.
   real(real64),   intent(in), target    :: y(:)    !< Ordinates, on the device.
   integer(int64), intent(in)            :: nk      !< Points kept.
   integer(int64), intent(in), target    :: keep(:) !< Their indices, on the device.
   real(real64),   intent(inout), target :: v(:)    !< Their values, on the device.
   integer(int64)                        :: i, k    !< Kept point, its index.

   !$acc parallel loop gang vector private(k) DEVICEVAR(x, y, keep, v)
   !$omp OMPLOOP private(k) DEVICEPTR(x, y, keep, v)
   do i = 1_int64, nk
      k = min(max(keep(i), 1_int64), n)
      v(i) = x(k)
      v(nk + i) = y(k)
   enddo
   endsubroutine gather_r64

   ! the kernels, single precision

   function unsorted_r32(n, x) result(bad)
   !< Points out of order (a NaN, or less than the one before): 0 for sorted abscissae.
   integer(int64), intent(in)         :: n    !< Points.
   real(real32),   intent(in), target :: x(:) !< Abscissae, on the device.
   integer(int64)                     :: bad  !< Points out of order.
   integer(int64)                     :: i    !< Counter.

   bad = 0_int64
   !$acc parallel loop gang vector reduction(+:bad) DEVICEVAR(x)
   !$omp OMPLOOP reduction(+:bad) DEVICEPTR(x)
   do i = 1_int64, n
      if (x(i) /= x(i)) then
         bad = bad + 1_int64
      elseif (i > 1_int64) then
         if (x(i - 1_int64) == x(i - 1_int64)) then
            if (x(i) < x(i - 1_int64)) bad = bad + 1_int64
         endif
      endif
   enddo
   endfunction unsorted_r32

   subroutine bounds_r32(axis, n, x, j0, np, bnd)
   !< bnd(j) the first point at or right of the part j0 + j - 1's left edge, j = 1..np + 1 (`bounds_r64`).
   type(decimate_axis), intent(in)            :: axis   !< The x axis.
   integer(int64),      intent(in)            :: n      !< Points.
   real(real32),        intent(in), target    :: x(:)   !< Abscissae, on the device.
   integer(int64),      intent(in)            :: j0     !< First part.
   integer(int64),      intent(in)            :: np     !< Parts.
   integer(int64),      intent(inout), target :: bnd(:) !< First points, on the device.
   real(real64)                               :: a(6)   !< The axis's transform.
   integer(int32)                             :: sc     !< Its scale.
   real(real64)                               :: fb     !< Framebuffer scale.
   real(real64)                               :: t      !< A part's left edge [pixels].
   integer(int64)                             :: j, lo, hi, mid !< Part, search.

   a = [axis%pix_min, axis%plt_min, axis%plt_max, axis%m, axis%sca_min, axis%sca_max]
   sc = axis%scale
   fb = axis%fb_scale
   !$acc parallel loop gang vector private(t, lo, hi, mid) copyin(a) DEVICEVAR(x, bnd)
   !$omp OMPLOOP private(t, lo, hi, mid) DEVICEPTR(x, bnd)
   do j = 1_int64, np + 1_int64
      t = real(j0 + j - 1_int64, real64) / real(DECIMATE_PARTS, real64)
      lo = 1_int64
      hi = n + 1_int64
      do while (lo < hi)
         mid = lo + (hi - lo) / 2_int64
         if (pixel(sc, a, fb, real(x(mid), real64)) >= t) then
            hi = mid
         else
            lo = mid + 1_int64
         endif
      enddo
      bnd(j) = lo
   enddo
   endsubroutine bounds_r32

   subroutine parts_r32(n, y, np, bnd, ext)
   !< Per part: its lowest and highest point, its first and last NaN (`parts_r64`).
   integer(int64), intent(in)            :: n      !< Points.
   real(real32),   intent(in), target    :: y(:)   !< Ordinates, on the device.
   integer(int64), intent(in)            :: np     !< Parts.
   integer(int64), intent(in), target    :: bnd(:) !< First points, on the device.
   integer(int64), intent(inout), target :: ext(:) !< Extremes, on the device.
   real(real32)                          :: v, vmin, vmax !< A value, the lowest, the highest.
   integer(int64)                        :: j, i, s, e     !< Part, point, the part's first and last.
   integer(int64)                        :: imin, imax, n1, n2 !< Lowest's, highest's point, first and last NaN.

   !$acc parallel loop gang private(s, e, vmin, vmax, imin, imax, n1, n2) DEVICEVAR(y, bnd, ext)
   !$omp OMPLOOP private(s, e, v, vmin, vmax, imin, imax, n1, n2, i) DEVICEPTR(y, bnd, ext)
   do j = 1_int64, np
      s = bnd(j)
      e = min(bnd(j + 1_int64) - 1_int64, n)
      vmin = huge(1.0_real32)
      vmax = -huge(1.0_real32)
      !$acc loop vector reduction(min:vmin) reduction(max:vmax) private(v)
      do i = s, e
         v = y(i)
         if (v == v) then
            vmin = min(vmin, v)
            vmax = max(vmax, v)
         endif
      enddo
      imin = e + 1_int64
      imax = e + 1_int64
      n1 = e + 1_int64
      n2 = 0_int64
      !$acc loop vector reduction(min:imin, imax, n1) reduction(max:n2) private(v)
      do i = s, e
         v = y(i)
         if (v == v) then
            if (v == vmin) imin = min(imin, i)
            if (v == vmax) imax = min(imax, i)
         else
            n1 = min(n1, i)
            n2 = max(n2, i)
         endif
      enddo
      ext(PER_PART * (j - 1_int64) + 1_int64) = merge(imin, 0_int64, imin <= e)
      ext(PER_PART * (j - 1_int64) + 2_int64) = merge(imax, 0_int64, imax <= e)
      ext(PER_PART * (j - 1_int64) + 3_int64) = merge(n1, 0_int64, n1 <= e)
      ext(PER_PART * (j - 1_int64) + 4_int64) = n2
   enddo
   endsubroutine parts_r32

   subroutine range_r32(n, y, s, e, imin, imax)
   !< The lowest and highest point of y(s:e) (`range_r64`).
   integer(int64), intent(in)         :: n          !< Points.
   real(real32),   intent(in), target :: y(:)       !< Ordinates, on the device.
   integer(int64), intent(in)         :: s, e       !< First, last point.
   integer(int64), intent(out)        :: imin, imax !< Lowest's, highest's point.
   real(real32)                       :: v, vmin, vmax !< A value, the lowest, the highest.
   integer(int64)                     :: i          !< Point.

   imin = 0_int64
   imax = 0_int64
   if (e < s .or. e > n) return
   vmin = huge(1.0_real32)
   vmax = -huge(1.0_real32)
   !$acc parallel loop gang vector reduction(min:vmin) reduction(max:vmax) private(v) DEVICEVAR(y)
   !$omp OMPLOOP reduction(min:vmin) reduction(max:vmax) private(v) DEVICEPTR(y)
   do i = s, e
      v = y(i)
      if (v == v) then
         vmin = min(vmin, v)
         vmax = max(vmax, v)
      endif
   enddo
   imin = e + 1_int64
   imax = e + 1_int64
   !$acc parallel loop gang vector reduction(min:imin, imax) private(v) DEVICEVAR(y)
   !$omp OMPLOOP reduction(min:imin, imax) private(v) DEVICEPTR(y)
   do i = s, e
      v = y(i)
      if (v == v) then
         if (v == vmin) imin = min(imin, i)
         if (v == vmax) imax = min(imax, i)
      endif
   enddo
   if (imin > e) imin = 0_int64
   if (imax > e) imax = 0_int64
   endsubroutine range_r32

   subroutine gather_r32(n, x, y, nk, keep, v)
   !< v(1:nk) the abscissae of the points kept, v(nk+1:2 nk) their ordinates, on the device.
   integer(int64), intent(in)            :: n       !< Points.
   real(real32),   intent(in), target    :: x(:)    !< Abscissae, on the device.
   real(real32),   intent(in), target    :: y(:)    !< Ordinates, on the device.
   integer(int64), intent(in)            :: nk      !< Points kept.
   integer(int64), intent(in), target    :: keep(:) !< Their indices, on the device.
   real(real32),   intent(inout), target :: v(:)    !< Their values, on the device.
   integer(int64)                        :: i, k    !< Kept point, its index.

   !$acc parallel loop gang vector private(k) DEVICEVAR(x, y, keep, v)
   !$omp OMPLOOP private(k) DEVICEPTR(x, y, keep, v)
   do i = 1_int64, nk
      k = min(max(keep(i), 1_int64), n)
      v(i) = x(k)
      v(nk + i) = y(k)
   enddo
   endsubroutine gather_r32

   ! on the device and the host

   function pixel(sc, a, fb, p) result(px)
   !< Display pixel of an abscissa, as `figure_decimate`'s (ImPlot's Transformer1, rounded to a C float), on the device.
   !$acc routine seq
   integer(int32), intent(in) :: sc   !< Scale.
   real(real64),   intent(in) :: a(6) !< Pixel of the range's minimum, range's min, max, pixels per unit, F(min), F(max).
   real(real64),   intent(in) :: fb   !< Framebuffer scale.
   real(real64),   intent(in) :: p    !< Abscissa.
   real(real64)               :: px   !< Pixel.
   real(real64)               :: q, s !< The abscissa through the scale, its forward transform.

   q = p
   if (sc == DECIMATE_LOG10) then
      s = log10(max(p, tiny(1.0_real64)))
      q = a(2) + (a(3) - a(2)) * ((s - a(5)) / (a(6) - a(5)))
   elseif (sc == DECIMATE_SYMLOG) then
      s = 2.0_real64 * asinh(p / 2.0_real64)
      q = a(2) + (a(3) - a(2)) * ((s - a(5)) / (a(6) - a(5)))
   endif
   px = real(real(a(1) + a(4) * (q - a(2)), real32), real64) * fb
   endfunction pixel

   ! the host's part

   subroutine kept_points(n, np, lo, hi, nk)
   !< The points kept, ascending, into h_keep: the area left of the plot (its first, lowest, highest and last), each
   !< column (whole when it has at most DECIMATE_THRESHOLD points, else per part its first, last, lowest, highest, and
   !< its first and last NaN with the points beside them), the area right of the plot.
   integer(int64), intent(in)  :: n      !< Points.
   integer(int64), intent(in)  :: np     !< Parts.
   integer(int64), intent(in)  :: lo(2)  !< Lowest point left and right of the plot (0 none).
   integer(int64), intent(in)  :: hi(2)  !< Highest point.
   integer(int64), intent(out) :: nk     !< Points kept.
   integer(int64)              :: c(10)  !< A part's candidates.
   integer(int64)              :: nc     !< ... how many.
   integer(int64)              :: k, j, s, e, q !< Column's first part, part, its first and last point, counter.

   nk = 0_int64
   nc = 0_int64
   call add(c, nc, 1_int64)
   call add(c, nc, lo(1))
   call add(c, nc, hi(1))
   call add(c, nc, h_bound(1) - 1_int64)
   call push(1_int64, h_bound(1) - 1_int64)
   do k = 1_int64, np, DECIMATE_PARTS
      s = h_bound(k)
      e = h_bound(k + DECIMATE_PARTS) - 1_int64
      if (e < s) cycle
      if (e - s + 1_int64 <= int(DECIMATE_THRESHOLD, int64)) then
         call grow(nk + e - s + 1_int64)
         do q = s, e
            h_keep(nk + q - s + 1_int64) = q
         enddo
         nk = nk + e - s + 1_int64
         cycle
      endif
      do j = k, k + DECIMATE_PARTS - 1_int64
         s = h_bound(j)
         e = h_bound(j + 1_int64) - 1_int64
         if (e < s) cycle
         nc = 0_int64
         call add(c, nc, s)
         call add(c, nc, e)
         call add(c, nc, h_ext(PER_PART * (j - 1_int64) + 1_int64))
         call add(c, nc, h_ext(PER_PART * (j - 1_int64) + 2_int64))
         if (h_ext(PER_PART * (j - 1_int64) + 3_int64) > 0_int64) then
            call add(c, nc, max(s, h_ext(PER_PART * (j - 1_int64) + 3_int64) - 1_int64))
            call add(c, nc, h_ext(PER_PART * (j - 1_int64) + 3_int64))
            call add(c, nc, h_ext(PER_PART * (j - 1_int64) + 4_int64))
            call add(c, nc, min(e, h_ext(PER_PART * (j - 1_int64) + 4_int64) + 1_int64))
         endif
         call push(s, e)
      enddo
   enddo
   nc = 0_int64
   call add(c, nc, h_bound(np + 1_int64))
   call add(c, nc, lo(2))
   call add(c, nc, hi(2))
   call add(c, nc, n)
   call push(h_bound(np + 1_int64), n)
   contains
      subroutine push(s, e)
      !< The candidates within s..e appended (ascending, as `add` keeps them).
      integer(int64), intent(in) :: s, e !< First, last point of the part.
      integer(int64)             :: q    !< Counter.

      if (e < s) return
      call grow(nk + nc)
      do q = 1_int64, nc
         if (c(q) < s .or. c(q) > e) cycle
         nk = nk + 1_int64
         h_keep(nk) = c(q)
      enddo
      endsubroutine push

      subroutine grow(need)
      !< h_keep at least `need` long, its values kept.
      integer(int64), intent(in)  :: need    !< Size needed.
      integer(int64), allocatable :: more(:) !< Larger.

      if (allocated(h_keep)) then
         if (size(h_keep, kind=int64) >= need) return
         allocate(more(max(need, size(h_keep, kind=int64) * 3_int64 / 2_int64)))
         more(1:size(h_keep)) = h_keep
         call move_alloc(more, h_keep)
      else
         allocate(h_keep(max(need, 65536_int64)))
      endif
      endsubroutine grow
   endsubroutine kept_points

   pure subroutine add(c, nc, j)
   !< A candidate, kept ascending without repetitions; 0 ignored.
   integer(int64), intent(inout) :: c(:) !< Candidates.
   integer(int64), intent(inout) :: nc   !< ... how many.
   integer(int64), intent(in)    :: j    !< Point.
   integer(int64)                :: p    !< Position.
   integer(int64)                :: i    !< Candidate moved.

   if (j <= 0_int64) return
   p = nc
   do while (p > 0_int64)
      if (c(p) < j) exit
      if (c(p) == j) return
      p = p - 1_int64
   enddo
   do i = nc, p + 1_int64, -1_int64 ! up one, the last first (a section copy is a heap temporary on nvfortran, #16 S5)
      c(i + 1_int64) = c(i)
   enddo
   c(p + 1_int64) = j
   nc = nc + 1_int64
   endsubroutine add

   ! the work arrays

   subroutine reserve_parts(np, ierr)
   !< Work arrays for np parts, on the device and the host.
   integer(int64), intent(in)  :: np   !< Parts.
   integer(int32), intent(out) :: ierr !< FUNDAL's status.

   ierr = 0_int32
   if (np <= cap_parts) return
   cap_parts = max(np, 2_int64 * cap_parts)
   if (associated(d_bound)) call dev_free(d_bound)
   if (associated(d_ext)) call dev_free(d_ext)
   call dev_alloc(fptr_dev=d_bound, ubounds=[int(cap_parts + 1_int64, int32)], ierr=ierr, label='figure: bounds')
   if (ierr == 0_int32) call dev_alloc(fptr_dev=d_ext, ubounds=[int(PER_PART * cap_parts, int32)], ierr=ierr, &
                                       label='figure: extremes')
   if (allocated(h_bound)) deallocate(h_bound)
   if (allocated(h_ext)) deallocate(h_ext)
   allocate(h_bound(cap_parts + 1_int64), h_ext(PER_PART * cap_parts))
   if (ierr /= 0_int32) cap_parts = 0_int64
   endsubroutine reserve_parts

   subroutine reserve_keep(nk, ierr)
   !< d_keep at least nk long.
   integer(int64), intent(in)  :: nk   !< Points.
   integer(int32), intent(out) :: ierr !< FUNDAL's status.

   ierr = 0_int32
   if (nk <= cap_keep) return
   cap_keep = max(nk, 2_int64 * cap_keep, 65536_int64)
   if (associated(d_keep)) call dev_free(d_keep)
   call dev_alloc(fptr_dev=d_keep, ubounds=[int(cap_keep, int32)], ierr=ierr, label='figure: kept')
   if (ierr /= 0_int32) cap_keep = 0_int64
   endsubroutine reserve_keep

   subroutine reserve_v64(nv, ierr)
   !< d_v64 at least nv long.
   integer(int64), intent(in)  :: nv   !< Values.
   integer(int32), intent(out) :: ierr !< FUNDAL's status.

   ierr = 0_int32
   if (nv <= cap_v64) return
   cap_v64 = max(nv, 2_int64 * cap_v64, 131072_int64)
   if (associated(d_v64)) call dev_free(d_v64)
   call dev_alloc(fptr_dev=d_v64, ubounds=[int(cap_v64, int32)], ierr=ierr, label='figure: values')
   if (ierr /= 0_int32) cap_v64 = 0_int64
   endsubroutine reserve_v64

   subroutine reserve_v32(nv, ierr)
   !< d_v32 at least nv long.
   integer(int64), intent(in)  :: nv   !< Values.
   integer(int32), intent(out) :: ierr !< FUNDAL's status.

   ierr = 0_int32
   if (nv <= cap_v32) return
   cap_v32 = max(nv, 2_int64 * cap_v32, 131072_int64)
   if (associated(d_v32)) call dev_free(d_v32)
   call dev_alloc(fptr_dev=d_v32, ubounds=[int(cap_v32, int32)], ierr=ierr, label='figure: values')
   if (ierr /= 0_int32) cap_v32 = 0_int64
   endsubroutine reserve_v32
endmodule figure_decimate_device
