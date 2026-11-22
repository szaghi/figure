!< figure_plot_series, where a plot item's arrays are read: in place at their stride, or copied into a scratch.
module figure_plot_series
!< figure_plot_series, where a plot item's arrays are read: in place at their stride, or copied into a scratch.
!<
!< The part of the plot items that does not depend on the plot library (szaghi/figure#15 §2): one address per array and
!< the byte stride the arrays of an item share, an array of another stride (a reversed section, integer abscissae)
!< copied into a slot's scratch, the scratch and the decimation's buffers given back when no item used them for two
!< frames. Used by figure_implot (2-D items) and figure_implot3d (3-D items); `plot_copies` and `plot_stride` are what
!< figure_testing's `test_plot_copies` and `test_plot_stride` read. The array dummies are ASYNCHRONOUS (figure_implot's
!< documentation: without it nvfortran copies a strided section at the inner call).
use, intrinsic :: iso_c_binding, only : c_f_pointer, c_int, c_intptr_t, c_loc, c_null_ptr, c_ptr
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use figure_cimgui, only : igGetFrameCount

implicit none
private
public :: buffer_r32, buffer_r64, series_r32, series_r64
public :: series_lead, series_put, series_gap, series_scratch, scratch_age
public :: kept_r32, kept_r64, kept, kept_frame

integer(int64), public          :: plot_copies = 0   !< Arrays the items copied because ImPlot could not read them in
                                                     !< place (strides, integer abscissae): `test_plot_copies`.
integer(int64), public          :: plot_stride = 0   !< Byte stride given to ImPlot for the last item: `test_plot_stride`.
type :: buffer_r32
   !< A scratch array of the items (single precision): the temporary of an array ImPlot cannot read in place.
   real(real32), allocatable :: v(:) !< Values, at the item's stride.
endtype buffer_r32

type :: buffer_r64
   !< A scratch array of the items (double precision): the temporary of an array ImPlot cannot read in place.
   real(real64), allocatable :: v(:) !< Values, at the item's stride.
endtype buffer_r64

type :: series_r32
   !< Where ImPlot reads the arrays of one item (single precision): one address per array and the byte stride they
   !< share (ImPlot applies one stride to all the arrays of an item); an array copied is read from its slot's scratch.
   type(c_ptr)    :: p(4) = c_null_ptr !< Addresses: 1 x, 2 y (sets the stride), 3-4 the other ordinates.
   integer(int64) :: stride = 4_int64  !< Stride of every array [bytes].
   integer(int64) :: n = 0_int64       !< Points (those kept, once decimated: `series_decimate`).
endtype series_r32

type :: series_r64
   !< Where ImPlot reads the arrays of one item (double precision): one address per array and the byte stride they
   !< share (ImPlot applies one stride to all the arrays of an item); an array copied is read from its slot's scratch.
   type(c_ptr)    :: p(4) = c_null_ptr !< Addresses: 1 x, 2 y (sets the stride), 3-4 the other ordinates.
   integer(int64) :: stride = 8_int64  !< Stride of every array [bytes].
   integer(int64) :: n = 0_int64       !< Points (those kept, once decimated: `series_decimate`).
endtype series_r64

! The items' scratch, one array per slot and precision, kept from item to item (an item's arrays are read by ImPlot
! during the call, and items are drawn by the main thread only): `scratch_reserve_*`, `scratch_age`.
type(buffer_r32), target :: scratch_r32(4)          !< Single precision.
type(buffer_r64), target :: scratch_r64(4)          !< Double precision.
integer(int32)           :: scratch_frame = -1_int32 !< Dear ImGui frame of the last copy into the scratch; -1: none kept.
! The decimation's buffers (figure_implot's `series_decimate`): the points kept, gathered from the item's arrays (x, y,
! the second ordinates), kept from item to item and freed with the scratch (`scratch_age`).
type(buffer_r32), target    :: kept_r32(3)            !< The points kept, single precision.
type(buffer_r64), target    :: kept_r64(3)            !< The points kept, double precision.
integer(int64), allocatable :: kept(:)                !< Their indices.
integer(int32)              :: kept_frame = -1_int32  !< Dear ImGui frame of the last decimation; -1: none kept.






interface series_lead
   !< Place the array that sets an item's stride.
   module procedure lead_r32, lead_r64
endinterface series_lead

interface series_put
   !< Place another array of an item, at its stride.
   module procedure put_r32, put_r64, put_i32_r32, put_i64_r32, put_i32_r64, put_i64_r64
endinterface series_put

interface series_gap
   !< Bytes from one address to the next one: the stride of an array, from the addresses of two consecutive elements.
   module procedure gap
endinterface series_gap

interface series_scratch
   !< The scratch of a slot, at least `n` elements long, for an array an item lays out itself (a grid, a field).
   module procedure scratch_slot_r32, scratch_slot_r64
endinterface series_scratch

interface scratch_copy
   !< Copy an item's array into its slot's scratch at the item's stride (integer abscissae converted).
   module procedure copy_r32, copy_r64, copy_i32_r32, copy_i64_r32, copy_i32_r64, copy_i64_r64
endinterface scratch_copy

contains
   subroutine lead_r32(d, k, a)
   !< Place the array that sets an item's stride (its ordinates) in slot `k`: read in place with its own stride when
   !< that is a positive multiple of the element size within a C int; otherwise (a reversed section, a stride beyond a
   !< C int) copied, contiguous, into the slot's scratch.
   type(series_r32), intent(inout)                    :: d    !< The item's arrays.
   integer(int32),   intent(in)                       :: k    !< Slot.
   real(real32),     intent(in), target, asynchronous :: a(:) !< Array.
   integer(int64)                                     :: es   !< Element size [bytes].
   integer(int64)                                     :: s    !< Its stride [bytes].

   call scratch_age()
   es = storage_size(a, kind=int64) / 8_int64
   d%stride = es
   d%n = size(a, kind=int64)
   if (size(a) == 0) return
   s = es
   if (size(a) > 1) s = gap(c_loc(a(1)), c_loc(a(2)))
   if (s > 0_int64 .and. mod(s, es) == 0_int64 .and. s <= int(huge(0_c_int), int64)) then
      d%stride = s
      d%p(k) = c_loc(a(1))
   else
      call scratch_reserve_r32(k, size(a, kind=int64))
      call scratch_copy(a, scratch_r32(k)%v, 1_int64)
      d%p(k) = c_loc(scratch_r32(k)%v)
      plot_copies = plot_copies + 1_int64
   endif
   endsubroutine lead_r32


   subroutine put_r32(d, k, a)
   !< Place an array of an item in slot `k`: read in place when its stride is the item's (set by `series_lead`, which
   !< comes first); otherwise copied at the item's stride into the slot's scratch.
   type(series_r32), intent(inout)                    :: d    !< The item's arrays.
   integer(int32),   intent(in)                       :: k    !< Slot.
   real(real32),     intent(in), target, asynchronous :: a(:) !< Array.
   integer(int64)                                     :: m    !< The item's stride [elements].

   if (size(a) == 0) return
   if (size(a) == 1) then
      d%p(k) = c_loc(a(1))
      return
   endif
   if (gap(c_loc(a(1)), c_loc(a(2))) == d%stride) then
      d%p(k) = c_loc(a(1))
      return
   endif
   m = d%stride / (storage_size(a, kind=int64) / 8_int64)
   call scratch_reserve_r32(k, (size(a, kind=int64) - 1_int64) * m + 1_int64)
   call scratch_copy(a, scratch_r32(k)%v, m)
   d%p(k) = c_loc(scratch_r32(k)%v)
   plot_copies = plot_copies + 1_int64
   endsubroutine put_r32


   subroutine put_i32_r32(d, k, a)
   !< Place integer abscissae of an item in slot `k`: converted to `real(real32)` (ImPlot reads x and y of one type),
   !< into the slot's scratch laid out at the item's stride, so that the ordinates stay in place.
   type(series_r32), intent(inout)            :: d    !< The item's arrays.
   integer(int32),   intent(in)               :: k    !< Slot.
   integer(int32),   intent(in), asynchronous :: a(:) !< Abscissae.
   integer(int64)                             :: m    !< The item's stride [elements].

   if (size(a) == 0) return
   m = d%stride / 4_int64
   call scratch_reserve_r32(k, (size(a, kind=int64) - 1_int64) * m + 1_int64)
   call scratch_copy(a, scratch_r32(k)%v, m)
   d%p(k) = c_loc(scratch_r32(k)%v)
   plot_copies = plot_copies + 1_int64
   endsubroutine put_i32_r32


   subroutine put_i64_r32(d, k, a)
   !< Place integer abscissae of an item in slot `k`: converted to `real(real32)` (ImPlot reads x and y of one type),
   !< into the slot's scratch laid out at the item's stride, so that the ordinates stay in place.
   type(series_r32), intent(inout)            :: d    !< The item's arrays.
   integer(int32),   intent(in)               :: k    !< Slot.
   integer(int64),   intent(in), asynchronous :: a(:) !< Abscissae.
   integer(int64)                             :: m    !< The item's stride [elements].

   if (size(a) == 0) return
   m = d%stride / 4_int64
   call scratch_reserve_r32(k, (size(a, kind=int64) - 1_int64) * m + 1_int64)
   call scratch_copy(a, scratch_r32(k)%v, m)
   d%p(k) = c_loc(scratch_r32(k)%v)
   plot_copies = plot_copies + 1_int64
   endsubroutine put_i64_r32


   subroutine lead_r64(d, k, a)
   !< Place the array that sets an item's stride (its ordinates) in slot `k`: read in place with its own stride when
   !< that is a positive multiple of the element size within a C int; otherwise (a reversed section, a stride beyond a
   !< C int) copied, contiguous, into the slot's scratch.
   type(series_r64), intent(inout)                    :: d    !< The item's arrays.
   integer(int32),   intent(in)                       :: k    !< Slot.
   real(real64),     intent(in), target, asynchronous :: a(:) !< Array.
   integer(int64)                                     :: es   !< Element size [bytes].
   integer(int64)                                     :: s    !< Its stride [bytes].

   call scratch_age()
   es = storage_size(a, kind=int64) / 8_int64
   d%stride = es
   d%n = size(a, kind=int64)
   if (size(a) == 0) return
   s = es
   if (size(a) > 1) s = gap(c_loc(a(1)), c_loc(a(2)))
   if (s > 0_int64 .and. mod(s, es) == 0_int64 .and. s <= int(huge(0_c_int), int64)) then
      d%stride = s
      d%p(k) = c_loc(a(1))
   else
      call scratch_reserve_r64(k, size(a, kind=int64))
      call scratch_copy(a, scratch_r64(k)%v, 1_int64)
      d%p(k) = c_loc(scratch_r64(k)%v)
      plot_copies = plot_copies + 1_int64
   endif
   endsubroutine lead_r64


   subroutine put_r64(d, k, a)
   !< Place an array of an item in slot `k`: read in place when its stride is the item's (set by `series_lead`, which
   !< comes first); otherwise copied at the item's stride into the slot's scratch.
   type(series_r64), intent(inout)                    :: d    !< The item's arrays.
   integer(int32),   intent(in)                       :: k    !< Slot.
   real(real64),     intent(in), target, asynchronous :: a(:) !< Array.
   integer(int64)                                     :: m    !< The item's stride [elements].

   if (size(a) == 0) return
   if (size(a) == 1) then
      d%p(k) = c_loc(a(1))
      return
   endif
   if (gap(c_loc(a(1)), c_loc(a(2))) == d%stride) then
      d%p(k) = c_loc(a(1))
      return
   endif
   m = d%stride / (storage_size(a, kind=int64) / 8_int64)
   call scratch_reserve_r64(k, (size(a, kind=int64) - 1_int64) * m + 1_int64)
   call scratch_copy(a, scratch_r64(k)%v, m)
   d%p(k) = c_loc(scratch_r64(k)%v)
   plot_copies = plot_copies + 1_int64
   endsubroutine put_r64


   subroutine put_i32_r64(d, k, a)
   !< Place integer abscissae of an item in slot `k`: converted to `real(real64)` (ImPlot reads x and y of one type),
   !< into the slot's scratch laid out at the item's stride, so that the ordinates stay in place.
   type(series_r64), intent(inout)            :: d    !< The item's arrays.
   integer(int32),   intent(in)               :: k    !< Slot.
   integer(int32),   intent(in), asynchronous :: a(:) !< Abscissae.
   integer(int64)                             :: m    !< The item's stride [elements].

   if (size(a) == 0) return
   m = d%stride / 8_int64
   call scratch_reserve_r64(k, (size(a, kind=int64) - 1_int64) * m + 1_int64)
   call scratch_copy(a, scratch_r64(k)%v, m)
   d%p(k) = c_loc(scratch_r64(k)%v)
   plot_copies = plot_copies + 1_int64
   endsubroutine put_i32_r64


   subroutine put_i64_r64(d, k, a)
   !< Place integer abscissae of an item in slot `k`: converted to `real(real64)` (ImPlot reads x and y of one type),
   !< into the slot's scratch laid out at the item's stride, so that the ordinates stay in place.
   type(series_r64), intent(inout)            :: d    !< The item's arrays.
   integer(int32),   intent(in)               :: k    !< Slot.
   integer(int64),   intent(in), asynchronous :: a(:) !< Abscissae.
   integer(int64)                             :: m    !< The item's stride [elements].

   if (size(a) == 0) return
   m = d%stride / 8_int64
   call scratch_reserve_r64(k, (size(a, kind=int64) - 1_int64) * m + 1_int64)
   call scratch_copy(a, scratch_r64(k)%v, m)
   d%p(k) = c_loc(scratch_r64(k)%v)
   plot_copies = plot_copies + 1_int64
   endsubroutine put_i64_r64


   subroutine scratch_age()
   !< Free the items' scratch (both precisions) when no item has copied into it in this frame or the one before: a
   !< program that stops plotting reversed or converted data gives the memory back at its next item. A new Dear ImGui
   !< context (its frame count restarted) frees it too. The decimation's buffers likewise.
   integer(int32) :: k   !< Slot.
   integer(int32) :: age !< Frames since the last copy.

   if (kept_frame >= 0_int32) then
      age = int(igGetFrameCount(), int32) - kept_frame
      if (age /= 0_int32 .and. age /= 1_int32) then
         do k = 1_int32, 3_int32
            if (allocated(kept_r32(k)%v)) deallocate(kept_r32(k)%v)
            if (allocated(kept_r64(k)%v)) deallocate(kept_r64(k)%v)
         enddo
         if (allocated(kept)) deallocate(kept)
         kept_frame = -1_int32
      endif
   endif
   if (scratch_frame < 0_int32) return
   age = int(igGetFrameCount(), int32) - scratch_frame
   if (age == 0_int32 .or. age == 1_int32) return
   do k = 1_int32, 4_int32
      if (allocated(scratch_r32(k)%v)) deallocate(scratch_r32(k)%v)
      if (allocated(scratch_r64(k)%v)) deallocate(scratch_r64(k)%v)
   enddo
   scratch_frame = -1_int32
   endsubroutine scratch_age


   subroutine scratch_slot_r32(k, n, v)
   !< The scratch of slot `k` (single precision), at least `n` elements long, for an array an item lays out itself
   !< (figure_implot3d: a surface's grid), counted as a copy (`test_plot_copies`). Valid until the next item.
   integer(int32),                      intent(in)  :: k    !< Slot.
   integer(int64),                      intent(in)  :: n    !< Elements needed.
   real(real32), pointer, contiguous,   intent(out) :: v(:) !< The slot's first n elements.

   call scratch_age()
   call scratch_reserve_r32(k, n)
   v => scratch_r32(k)%v(1_int64:n)
   plot_copies = plot_copies + 1_int64
   endsubroutine scratch_slot_r32


   subroutine scratch_slot_r64(k, n, v)
   !< The scratch of slot `k` (double precision), at least `n` elements long, for an array an item lays out itself
   !< (figure_implot3d: a surface's grid), counted as a copy (`test_plot_copies`). Valid until the next item.
   integer(int32),                      intent(in)  :: k    !< Slot.
   integer(int64),                      intent(in)  :: n    !< Elements needed.
   real(real64), pointer, contiguous,   intent(out) :: v(:) !< The slot's first n elements.

   call scratch_age()
   call scratch_reserve_r64(k, n)
   v => scratch_r64(k)%v(1_int64:n)
   plot_copies = plot_copies + 1_int64
   endsubroutine scratch_slot_r64


   subroutine scratch_reserve_r32(k, n)
   !< Make the scratch of slot `k` (single precision) at least `n` elements long: kept from item to item and from frame
   !< to frame, grown by half again when too short (a series that grows by a point per frame is not reallocated every
   !< frame), freed by `scratch_age`. A temporary allocated and freed by every item can cost the memory's first touch
   !< every frame (nvfortran 26.9 with glibc: 2.4 ms against 1.0 ms to copy 10**6 doubles; plots.md, "Data in place").
   integer(int32), intent(in) :: k !< Slot.
   integer(int64), intent(in) :: n !< Elements needed.
   integer(int64)             :: c !< Capacity [elements].

   c = 0_int64
   if (allocated(scratch_r32(k)%v)) c = size(scratch_r32(k)%v, kind=int64)
   if (c < n) then
      if (allocated(scratch_r32(k)%v)) deallocate(scratch_r32(k)%v)
      allocate(scratch_r32(k)%v(max(n, c + c / 2_int64)))
   endif
   scratch_frame = int(igGetFrameCount(), int32)
   endsubroutine scratch_reserve_r32


   subroutine copy_r32(a, v, m)
   !< Copy `a` into `v` at a stride of `m` elements, v(1), v(1 + m), ... (the elements between left as they are), single
   !< precision. A reversed section of adjacent elements (`a(n:1:-1)`) is read through a contiguous view of its memory:
   !< with the descending unit stride known to the compiler, the copy runs as fast as a contiguous one (nvfortran 26.9
   !< takes twice as long through the section's descriptor).
   real(real32),   intent(in), target, asynchronous :: a(:) !< Array, any stride.
   real(real32),   intent(inout)                    :: v(:) !< Scratch, at least (size(a) - 1) m + 1 elements long.
   integer(int64), intent(in)                       :: m    !< Stride in v [elements].
   real(real32),   pointer, contiguous              :: r(:) !< A reversed section's elements, in memory order.
   integer(int64)                                   :: n    !< Elements.

   n = size(a, kind=int64)
   if (n == 0_int64) return
   if (n > 1_int64) then
      if (gap(c_loc(a(2)), c_loc(a(1))) == storage_size(a, kind=int64) / 8_int64) then
         call c_f_pointer(c_loc(a(n)), r, [n])
         if (m == 1_int64) then
            v(1_int64:n) = r(n:1_int64:-1_int64)
         else
            v(1_int64:(n - 1_int64) * m + 1_int64:m) = r(n:1_int64:-1_int64)
         endif
         return
      endif
   endif
   v(1_int64:(n - 1_int64) * m + 1_int64:m) = a
   endsubroutine copy_r32


   subroutine copy_i32_r32(a, v, m)
   !< Convert `int32` values to `real(real32)` into `v` at a stride of `m` elements.
   integer(int32), intent(in), asynchronous :: a(:) !< Values, any stride.
   real(real32),   intent(inout)            :: v(:) !< Scratch, at least (size(a) - 1) m + 1 elements long.
   integer(int64), intent(in)               :: m    !< Stride in v [elements].
   integer(int64)                           :: n    !< Elements.

   n = size(a, kind=int64)
   if (n > 0_int64) v(1_int64:(n - 1_int64) * m + 1_int64:m) = real(a, real32)
   endsubroutine copy_i32_r32


   subroutine copy_i64_r32(a, v, m)
   !< Convert `int64` values to `real(real32)` into `v` at a stride of `m` elements.
   integer(int64), intent(in), asynchronous :: a(:) !< Values, any stride.
   real(real32),   intent(inout)            :: v(:) !< Scratch, at least (size(a) - 1) m + 1 elements long.
   integer(int64), intent(in)               :: m    !< Stride in v [elements].
   integer(int64)                           :: n    !< Elements.

   n = size(a, kind=int64)
   if (n > 0_int64) v(1_int64:(n - 1_int64) * m + 1_int64:m) = real(a, real32)
   endsubroutine copy_i64_r32


   subroutine scratch_reserve_r64(k, n)
   !< Make the scratch of slot `k` (double precision) at least `n` elements long: kept from item to item and from frame
   !< to frame, grown by half again when too short (a series that grows by a point per frame is not reallocated every
   !< frame), freed by `scratch_age`. A temporary allocated and freed by every item can cost the memory's first touch
   !< every frame (nvfortran 26.9 with glibc: 2.4 ms against 1.0 ms to copy 10**6 doubles; plots.md, "Data in place").
   integer(int32), intent(in) :: k !< Slot.
   integer(int64), intent(in) :: n !< Elements needed.
   integer(int64)             :: c !< Capacity [elements].

   c = 0_int64
   if (allocated(scratch_r64(k)%v)) c = size(scratch_r64(k)%v, kind=int64)
   if (c < n) then
      if (allocated(scratch_r64(k)%v)) deallocate(scratch_r64(k)%v)
      allocate(scratch_r64(k)%v(max(n, c + c / 2_int64)))
   endif
   scratch_frame = int(igGetFrameCount(), int32)
   endsubroutine scratch_reserve_r64


   subroutine copy_r64(a, v, m)
   !< Copy `a` into `v` at a stride of `m` elements, v(1), v(1 + m), ... (the elements between left as they are), double
   !< precision. A reversed section of adjacent elements (`a(n:1:-1)`) is read through a contiguous view of its memory:
   !< with the descending unit stride known to the compiler, the copy runs as fast as a contiguous one (nvfortran 26.9
   !< takes twice as long through the section's descriptor).
   real(real64),   intent(in), target, asynchronous :: a(:) !< Array, any stride.
   real(real64),   intent(inout)                    :: v(:) !< Scratch, at least (size(a) - 1) m + 1 elements long.
   integer(int64), intent(in)                       :: m    !< Stride in v [elements].
   real(real64),   pointer, contiguous              :: r(:) !< A reversed section's elements, in memory order.
   integer(int64)                                   :: n    !< Elements.

   n = size(a, kind=int64)
   if (n == 0_int64) return
   if (n > 1_int64) then
      if (gap(c_loc(a(2)), c_loc(a(1))) == storage_size(a, kind=int64) / 8_int64) then
         call c_f_pointer(c_loc(a(n)), r, [n])
         if (m == 1_int64) then
            v(1_int64:n) = r(n:1_int64:-1_int64)
         else
            v(1_int64:(n - 1_int64) * m + 1_int64:m) = r(n:1_int64:-1_int64)
         endif
         return
      endif
   endif
   v(1_int64:(n - 1_int64) * m + 1_int64:m) = a
   endsubroutine copy_r64


   subroutine copy_i32_r64(a, v, m)
   !< Convert `int32` values to `real(real64)` into `v` at a stride of `m` elements.
   integer(int32), intent(in), asynchronous :: a(:) !< Values, any stride.
   real(real64),   intent(inout)            :: v(:) !< Scratch, at least (size(a) - 1) m + 1 elements long.
   integer(int64), intent(in)               :: m    !< Stride in v [elements].
   integer(int64)                           :: n    !< Elements.

   n = size(a, kind=int64)
   if (n > 0_int64) v(1_int64:(n - 1_int64) * m + 1_int64:m) = real(a, real64)
   endsubroutine copy_i32_r64


   subroutine copy_i64_r64(a, v, m)
   !< Convert `int64` values to `real(real64)` into `v` at a stride of `m` elements.
   integer(int64), intent(in), asynchronous :: a(:) !< Values, any stride.
   real(real64),   intent(inout)            :: v(:) !< Scratch, at least (size(a) - 1) m + 1 elements long.
   integer(int64), intent(in)               :: m    !< Stride in v [elements].
   integer(int64)                           :: n    !< Elements.

   n = size(a, kind=int64)
   if (n > 0_int64) v(1_int64:(n - 1_int64) * m + 1_int64:m) = real(a, real64)
   endsubroutine copy_i64_r64


   function gap(first, second) result(bytes)
   !< Bytes from one address to the next one: the stride of an array, from the addresses of two consecutive elements.
   !< The integer TRANSFER gives for a C address is processor-dependent; gfortran, nvfortran and ifx give the address.
   type(c_ptr), intent(in) :: first  !< Address of a(i).
   type(c_ptr), intent(in) :: second !< Address of a(i + 1).
   integer(int64)          :: bytes  !< Distance [bytes]; negative for a reversed section.

   bytes = int(transfer(second, 0_c_intptr_t) - transfer(first, 0_c_intptr_t), int64)
   endfunction gap
endmodule figure_plot_series
