!< figure_plot_field, a field coloured through a colormap into a cached texture (`ip_field_image`), in Fortran.
module figure_plot_field
!< figure_plot_field, a field coloured through a colormap into a cached texture (`ip_field_image`), in Fortran.
!<
!< szaghi/figure#15 P11, group (d). What native/figure_field.cpp does for `ip_field_image` on the current path, for the
!< Fortran plot frame: a real32 or real64 matrix coloured into an RGBA texture (FIGURE's own texture API,
!< `fig_texture_create`/`update`/`destroy`, path-independent), cached by the item's ID and coloured again only when
!< the program says the values changed or the array (address, shape, kind), the range, the colormap, the scale or the
!< NaN colour differ from the last colouring; an entry not drawn for IDLE_SECONDS is released (`field_sweep`, from the
!< next field drawn). The colours are figure_field.cpp's, bit for bit:
!<
!< - t = (s(v) - s(lo)) / (s(hi) - s(lo)), s the scale (identity, log10, 2 asinh(v/2): C's, bound), v clamped to
!<   [lo, hi] first; the colour the colormap's at t (`LerpTable`: figure_plot_colormaps' `cm_sample`); non-finite
!<   values, and values <= 0 on a log scale, the NaN colour (`lround` of each channel times 255);
!< - log and symlog fields of at least LUT_MIN_PIXELS values through the table indexed by the value's float bits (at
!<   most 65536 bins, each the colour of its centre), as figure_field.cpp; linear fields per value;
!< - the range: vmin/vmax given, else the finite values' (positive ones on log; [0, 1] or [1, 10] when none), a log
!<   range with an end <= 0 rebuilt a decade from the other end; a constant field the colormap's middle.
use, intrinsic :: iso_c_binding, only : c_associated, c_double, c_int, c_long_long, c_loc, c_null_ptr, c_ptr
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use figure_base, only : figure_time
use figure_c_native, only : fig_texture_create, fig_texture_destroy, fig_texture_update
use figure_core, only : core_time
use figure_plot_colormaps, only : cm_generation, cm_sample

implicit none
private
public :: field_colour, field_sweep, field_count, field_uploads, field_time, field_pixel
public :: FIELD_LINEAR, FIELD_LOG, FIELD_SYMLOG

integer(int32), parameter :: FIELD_LINEAR = 0_int32 !< Scale: linear.
integer(int32), parameter :: FIELD_LOG = 1_int32    !< ... log10.
integer(int32), parameter :: FIELD_SYMLOG = 2_int32 !< ... symlog.
real(real64),   parameter :: IDLE_SECONDS = 10.0_real64 !< An entry not drawn for this long is released.
integer(int64), parameter :: LUT_MIN_PIXELS = 131072_int64 !< The bit table above this many values (log, symlog).
integer(int64), parameter :: LUT_BINS = 65536_int64 !< At most this many bins.

type :: field_entry
   !< A cached colouring (figure_field.cpp's entry_t).
   integer(int32)       :: id = 0_int32          !< The item's ID.
   logical              :: used = .false.        !< The slot holds an entry.
   integer(c_long_long) :: tex = 0_c_long_long   !< Texture (0: none).
   integer(int64)       :: nx = 0_int64, ny = 0_int64 !< Shape.
   integer(int32)       :: kind = 0_int32        !< 4, 8.
   type(c_ptr)          :: data = c_null_ptr     !< The array's address.
   logical              :: has_vmin = .false., has_vmax = .false. !< Range given.
   real(real64)         :: vmin = 0.0_real64, vmax = 0.0_real64   !< ... its ends.
   real(real64)         :: lo = 0.0_real64, hi = 1.0_real64       !< The range applied.
   integer(int32)       :: cmap = -1_int32, scale = FIELD_LINEAR  !< Colormap, scale.
   integer(int32)       :: colormaps = -1_int32 !< The colormaps' generation (`cm_generation`: an edited map).
   integer(int32)       :: nan = 0_int32         !< NaN colour (packed).
   real(real64)         :: last_time = 0.0_real64 !< Time of the last drawing.
   character(len=:), allocatable :: label        !< The item's label (`field_pixel`).
   integer(int32),   allocatable :: px(:)        !< The colours of its last colouring (`field_pixel`).
endtype field_entry

type(field_entry), allocatable :: cache(:) !< The colourings.
integer(int32),    allocatable, target :: rgba(:) !< The colours of the last colouring (kept, grown).
integer(int32),    allocatable :: lut(:)   !< The bit table (kept, grown).
integer(int64)                 :: uploads = 0_int64 !< Colourings uploaded since the start (tests).
real(real64)                   :: last_ms = 0.0_real64 !< The last colouring's time, upload included [ms] (tests).
! the colouring in progress (`colour_setup`)
real(real64)   :: lo_ = 0.0_real64, hi_ = 1.0_real64 !< Range, ordered.
real(real64)   :: s0_ = 0.0_real64, inv_ = 1.0_real64 !< s(lo), 1 / (s(hi) - s(lo)).
logical        :: const_ = .false.                    !< A constant field.
logical        :: table_ = .false.                    !< Through the bit table.
integer(int64) :: k0_ = 0_int64                       !< The table's first key.
integer(int32) :: shift_ = 0_int32                    !< Its bins' width, a power of two of keys.

interface
   pure function c_log10(x) result(r) bind(C, name='log10')
   !< C's `log10`.
   import :: c_double
   implicit none
   real(c_double), value :: x !< Value.
   real(c_double)        :: r !< Logarithm.
   endfunction c_log10

   pure function c_asinh(x) result(r) bind(C, name='asinh')
   !< C's `asinh`.
   import :: c_double
   implicit none
   real(c_double), value :: x !< Value.
   real(c_double)        :: r !< Inverse hyperbolic sine.
   endfunction c_asinh
endinterface

contains
   subroutine field_colour(id, f32, f64, nx, ny, cmap, vmin, vmax, scale, nan_rgba, changed, tex, lo, hi, stat, label)
   !< The texture of a field (coloured again when needed): `f32` or `f64` (one present), nx x ny, f(i, j) the texture's
   !< pixel (i, j); the range applied in lo, hi. With `label`, the colours are kept under it for `field_pixel` (as
   !< figure_field.cpp keeps them: a test reads them), and the colouring's time for `field_time`.
   integer(int32),         intent(in)                   :: id          !< The item's ID.
   real(real32),           intent(in), target, optional :: f32(:,:)    !< Field, single precision.
   real(real64),           intent(in), target, optional :: f64(:,:)    !< Field, double precision.
   integer(int64),         intent(in)                   :: nx, ny      !< Shape.
   integer(int32),         intent(in)                   :: cmap        !< Colormap.
   real(real64),           intent(in), optional         :: vmin, vmax  !< Range given.
   integer(int32),         intent(in)                   :: scale       !< FIELD_*.
   real(real32),           intent(in)                   :: nan_rgba(4) !< NaN colour.
   logical,                intent(in)                   :: changed     !< The values changed.
   integer(c_long_long),   intent(out)                  :: tex         !< Texture.
   real(real64),           intent(out)                  :: lo, hi      !< The range applied.
   integer(int32),         intent(out)                  :: stat        !< Status (0: ok).
   character(len=*),       intent(in), optional         :: label       !< The item's label.
   type(c_ptr)                                          :: p           !< The array's address.
   real(real64)                                         :: t0          !< The colouring's start [s].
   integer(int32)                                       :: k, kind, nanc, st !< Slot, kind, NaN colour, status.
   integer(int64)                                       :: n           !< Values.
   real(real64)                                         :: dlo, dhi    !< The data's range.
   logical                                              :: again, any_ !< Colour again, values found.

   stat = 0_int32
   tex = 0_c_long_long
   lo = 0.0_real64
   hi = 1.0_real64
   if (present(f32)) then
      kind = 4_int32
      p = c_loc(f32)
   else
      kind = 8_int32
      p = c_loc(f64)
   endif
   nanc = to_u32(nan_rgba)
   k = slot(id)
   associate(e => cache(k))
      again = e%tex == 0_c_long_long .or. changed .or. .not. same_ptr(e%data, p) .or. e%kind /= kind .or. &
              e%nx /= nx .or. e%ny /= ny .or. e%cmap /= cmap .or. e%colormaps /= cm_generation() .or. &
              e%scale /= scale .or. e%nan /= nanc .or. &
              (e%has_vmin .neqv. present(vmin)) .or. (e%has_vmax .neqv. present(vmax))
      if (.not. again .and. present(vmin)) again = e%vmin /= vmin
      if (.not. again .and. present(vmax)) again = e%vmax /= vmax
      e%last_time = core_time()
      if (again) then
         t0 = figure_time()
         n = nx * ny
         if (e%tex == 0_c_long_long .or. e%nx /= nx .or. e%ny /= ny) then
            if (e%tex /= 0_c_long_long) call fig_texture_destroy(e%tex)
            e%tex = 0_c_long_long
            st = int(fig_texture_create(int(nx, c_int), int(ny, c_int), 0_c_int, e%tex), int32)
            if (st /= 0_int32) then
               e%used = .false.
               stat = st
               return
            endif
         endif
         e%data = p
         e%kind = kind
         e%nx = nx
         e%ny = ny
         e%cmap = cmap
         e%colormaps = cm_generation()
         e%scale = scale
         e%nan = nanc
         e%has_vmin = present(vmin)
         e%has_vmax = present(vmax)
         e%vmin = 0.0_real64
         e%vmax = 0.0_real64
         if (present(vmin)) e%vmin = vmin
         if (present(vmax)) e%vmax = vmax
         dlo = 0.0_real64
         dhi = 1.0_real64
         any_ = present(vmin) .and. present(vmax) ! the data's range only when needed
         if (.not. any_) then
            if (kind == 4_int32) then
               any_ = data_range_r32(f32, scale, dlo, dhi)
            else
               any_ = data_range_r64(f64, scale, dlo, dhi)
            endif
         endif
         if (.not. any_) then ! nothing to measure: [0, 1], or [1, 10] on a log scale
            dlo = merge(1.0_real64, 0.0_real64, scale == FIELD_LOG)
            dhi = merge(10.0_real64, 1.0_real64, scale == FIELD_LOG)
         endif
         e%lo = dlo
         e%hi = dhi
         if (present(vmin)) e%lo = vmin
         if (present(vmax)) e%hi = vmax
         if (scale == FIELD_LOG .and. (e%lo <= 0.0_real64 .or. e%hi <= 0.0_real64)) then
            if (.not. (e%lo > 0.0_real64)) e%lo = e%hi / 10.0_real64
            if (.not. (e%hi > 0.0_real64)) e%hi = e%lo * 10.0_real64
         endif
         if (allocated(rgba)) then
            if (size(rgba, kind=int64) < n) deallocate(rgba)
         endif
         if (.not. allocated(rgba)) allocate(rgba(max(n, 1024_int64)))
         if (kind == 4_int32) then
            call colour_r32(f32, e, n)
         else
            call colour_r64(f64, e, n)
         endif
         st = int(fig_texture_update(e%tex, int(nx, c_int), int(ny, c_int), c_loc(rgba)), int32)
         if (st /= 0_int32) then
            stat = st
            return
         endif
         uploads = uploads + 1_int64
         last_ms = (figure_time() - t0) * 1000.0_real64
         if (present(label)) then ! kept for field_pixel (allocated when coloured, not per frame)
            if (allocated(e%px)) then
               if (size(e%px, kind=int64) /= n) deallocate(e%px)
            endif
            if (.not. allocated(e%px)) allocate(e%px(n))
            e%px(1:n) = rgba(1:n)
            e%label = label
         endif
      endif
      tex = e%tex
      lo = e%lo
      hi = e%hi
   endassociate
   endsubroutine field_colour

   subroutine field_sweep()
   !< The entries not drawn for IDLE_SECONDS released (their textures destroyed).
   integer(int32) :: k   !< Slot.
   real(real64)   :: now !< Time.

   if (.not. allocated(cache)) return
   now = core_time()
   do k = 1_int32, size(cache, kind=int32)
      if (.not. cache(k)%used) cycle
      if (now - cache(k)%last_time <= IDLE_SECONDS) cycle
      if (cache(k)%tex /= 0_c_long_long) call fig_texture_destroy(cache(k)%tex)
      call entry_reset(cache(k))
   enddo
   endsubroutine field_sweep

   subroutine entry_reset(e)
   !< An entry emptied, field by field (`a(i) = T()` for a type with allocatable components crashes nvfortran 26.9).
   type(field_entry), intent(inout) :: e !< Entry.

   e%id = 0_int32
   e%used = .false.
   e%tex = 0_c_long_long
   e%nx = 0_int64
   e%ny = 0_int64
   e%kind = 0_int32
   e%data = c_null_ptr
   e%has_vmin = .false.
   e%has_vmax = .false.
   e%vmin = 0.0_real64
   e%vmax = 0.0_real64
   e%lo = 0.0_real64
   e%hi = 1.0_real64
   e%cmap = -1_int32
   e%scale = FIELD_LINEAR
   e%colormaps = -1_int32
   e%nan = 0_int32
   e%last_time = 0.0_real64
   if (allocated(e%label)) deallocate(e%label)
   if (allocated(e%px)) deallocate(e%px)
   endsubroutine entry_reset

   function field_time() result(ms)
   !< The last colouring's time, upload included [ms] (tests: `test_field_time`).
   real(real64) :: ms !< Time [ms].

   ms = last_ms
   endfunction field_time

   function field_pixel(label, i, j, rgba_) result(status)
   !< The colour of the value (i, j) of the field `label` in its last colouring (tests: `test_field_pixel`, as
   !< figure_field.cpp's `fig_field_pixel`): 0, 1 for (i, j) outside the field, 2 for no field of that label cached.
   character(len=*), intent(in)  :: label    !< The field's label.
   integer(int32),   intent(in)  :: i, j     !< Indices, from 1.
   real(real32),     intent(out) :: rgba_(4) !< Colour, RGBA in [0, 1] (steps of 1/255).
   integer(int32)                :: status   !< Status.
   integer(int32)                :: k, c, b  !< Slot, packed colour, channel.

   rgba_ = 0.0_real32
   status = 2_int32
   if (.not. allocated(cache)) return
   do k = 1_int32, size(cache, kind=int32)
      if (.not. cache(k)%used) cycle
      if (.not. allocated(cache(k)%label)) cycle
      if (cache(k)%label /= label .or. len(cache(k)%label) /= len(label)) cycle
      status = 1_int32
      if (i < 1_int32 .or. int(i, int64) > cache(k)%nx .or. j < 1_int32 .or. int(j, int64) > cache(k)%ny) return
      if (.not. allocated(cache(k)%px)) return
      c = cache(k)%px(int(j - 1_int32, int64) * cache(k)%nx + int(i, int64))
      do b = 1_int32, 4_int32
         rgba_(b) = real(iand(ishft(c, -8_int32 * (b - 1_int32)), 255_int32), real32) / 255.0_real32
      enddo
      status = 0_int32
      return
   enddo
   endfunction field_pixel

   function field_count() result(n)
   !< The colourings cached (tests: `test_field_textures`).
   integer(int32) :: n !< Entries.

   n = 0_int32
   if (allocated(cache)) n = count(cache(:)%used)
   endfunction field_count

   function field_uploads() result(n)
   !< The colourings uploaded since the start (tests: `test_field_uploads`).
   integer(int64) :: n !< Uploads.

   n = uploads
   endfunction field_uploads

   function slot(id) result(k)
   !< The cache's slot of an ID, a free one (the table grown, doubled) when new.
   integer(int32), intent(in) :: id !< ID.
   integer(int32)             :: k  !< Slot.
   type(field_entry), allocatable :: more(:) !< Grown table.
   integer(int32)             :: j, n !< Counter, size.

   if (.not. allocated(cache)) allocate(cache(8))
   do k = 1_int32, size(cache, kind=int32)
      if (cache(k)%used .and. cache(k)%id == id) return
   enddo
   do k = 1_int32, size(cache, kind=int32)
      if (.not. cache(k)%used) exit
   enddo
   n = size(cache, kind=int32)
   if (k > n) then
      allocate(more(2_int32 * n))
      do j = 1_int32, n
         more(j) = cache(j)
      enddo
      call move_alloc(more, cache)
   endif
   call entry_reset(cache(k))
   cache(k)%used = .true.
   cache(k)%id = id
   endfunction slot

   function same_ptr(a, b) result(yes)
   !< Two addresses equal.
   type(c_ptr), intent(in) :: a, b !< Addresses.
   logical                 :: yes  !< Equal.

   yes = c_associated(a, b) .or. (.not. c_associated(a) .and. .not. c_associated(b))
   endfunction same_ptr

   pure function forward(scale, v) result(s)
   !< The scale's transform: v, log10(v), 2 asinh(v / 2) (C's).
   integer(int32), intent(in) :: scale !< FIELD_*.
   real(real64),   intent(in) :: v     !< Value.
   real(real64)               :: s     !< Transformed.

   select case (scale)
   case (FIELD_LOG)
      s = c_log10(v)
   case (FIELD_SYMLOG)
      s = 2.0_real64 * c_asinh(v / 2.0_real64)
   case default
      s = v
   endselect
   endfunction forward

   pure function masked(scale, v) result(yes)
   !< A value without a colour of the map: not finite, or <= 0 on a log scale.
   integer(int32), intent(in) :: scale !< FIELD_*.
   real(real64),   intent(in) :: v     !< Value.
   logical                    :: yes   !< Masked.

   yes = .not. (abs(v) <= huge(1.0_real64)) .or. (scale == FIELD_LOG .and. v <= 0.0_real64)
   endfunction masked

   function data_range_r64(f, scale, lo, hi) result(any_)
   !< The range of the finite values (positive on a log scale); false when none.
   real(real64),   intent(in)  :: f(:,:)  !< Field.
   integer(int32), intent(in)  :: scale   !< FIELD_*.
   real(real64),   intent(out) :: lo, hi  !< Range.
   logical                     :: any_    !< Found.
   integer(int64)              :: i, j    !< Counters.

   any_ = .false.
   lo = 0.0_real64
   hi = 0.0_real64
   do j = 1_int64, size(f, 2, kind=int64)
      do i = 1_int64, size(f, 1, kind=int64)
         if (masked(scale, f(i, j))) cycle
         if (.not. any_) then
            lo = f(i, j)
            hi = f(i, j)
            any_ = .true.
         else
            lo = merge(f(i, j), lo, f(i, j) < lo) ! std::min(lo, v): v < lo ? v : lo
            hi = merge(f(i, j), hi, hi < f(i, j)) ! std::max(hi, v): hi < v ? v : hi
         endif
      enddo
   enddo
   endfunction data_range_r64

   function data_range_r32(f, scale, lo, hi) result(any_)
   !< The range of the finite values (positive on a log scale), single precision field; false when none.
   real(real32),   intent(in)  :: f(:,:)  !< Field.
   integer(int32), intent(in)  :: scale   !< FIELD_*.
   real(real64),   intent(out) :: lo, hi  !< Range.
   logical                     :: any_    !< Found.
   integer(int64)              :: i, j    !< Counters.
   real(real64)                :: v       !< A value.

   any_ = .false.
   lo = 0.0_real64
   hi = 0.0_real64
   do j = 1_int64, size(f, 2, kind=int64)
      do i = 1_int64, size(f, 1, kind=int64)
         v = real(f(i, j), real64)
         if (masked(scale, v)) cycle
         if (.not. any_) then
            lo = v
            hi = v
            any_ = .true.
         else
            lo = merge(v, lo, v < lo)
            hi = merge(v, hi, hi < v)
         endif
      enddo
   enddo
   endfunction data_range_r32

   subroutine colour_r64(f, e, n)
   !< The colours of a double precision field (figure_field.cpp's `colour`).
   real(real64),      intent(in) :: f(:,:) !< Field.
   type(field_entry), intent(in) :: e      !< Entry.
   integer(int64),    intent(in) :: n      !< Values.
   integer(int64)                :: i, j, k !< Counters.

   call colour_setup(e, n)
   k = 0_int64
   do j = 1_int64, size(f, 2, kind=int64)
      do i = 1_int64, size(f, 1, kind=int64)
         k = k + 1_int64
         rgba(k) = colour_of(e, f(i, j))
      enddo
   enddo
   endsubroutine colour_r64

   subroutine colour_r32(f, e, n)
   !< The colours of a single precision field.
   real(real32),      intent(in) :: f(:,:) !< Field.
   type(field_entry), intent(in) :: e      !< Entry.
   integer(int64),    intent(in) :: n      !< Values.
   integer(int64)                :: i, j, k !< Counters.

   call colour_setup(e, n)
   k = 0_int64
   do j = 1_int64, size(f, 2, kind=int64)
      do i = 1_int64, size(f, 1, kind=int64)
         k = k + 1_int64
         rgba(k) = colour_of(e, real(f(i, j), real64))
      enddo
   enddo
   endsubroutine colour_r32

   ! the colouring's state for one field: the per-value constants and, for large log/symlog fields, the bit table
   subroutine colour_setup(e, n)
   !< `colour`'s set-up: the transformed range, and the bit table when it applies.
   type(field_entry), intent(in) :: e !< Entry.
   integer(int64),    intent(in) :: n !< Values.
   integer(int64)                :: span, kc, i, bins !< Keys.
   real(real32)                  :: flo, fhi          !< The range as floats.

   lo_ = min(e%lo, e%hi)
   hi_ = max(e%lo, e%hi)
   const_ = e%lo == e%hi
   if (const_) return
   s0_ = forward(e%scale, e%lo)
   inv_ = 1.0_real64 / (forward(e%scale, e%hi) - s0_)
   flo = real(lo_, real32)
   fhi = real(hi_, real32)
   table_ = e%scale /= FIELD_LINEAR .and. n >= LUT_MIN_PIXELS .and. flo < fhi .and. abs(flo) <= huge(flo) .and. &
            abs(fhi) <= huge(fhi)
   if (.not. table_) return
   k0_ = fkey(flo)
   span = fkey(fhi) - k0_
   shift_ = 0_int32
   do while (ishft(span, -shift_) >= LUT_BINS - 1_int64)
      shift_ = shift_ + 1_int32
   enddo
   bins = ishft(span, -shift_) + 1_int64
   if (allocated(lut)) then
      if (size(lut, kind=int64) < bins) deallocate(lut)
   endif
   if (.not. allocated(lut)) allocate(lut(bins))
   do i = 0_int64, bins - 1_int64 ! the bin's centre
      kc = k0_ + ishft(i, shift_) + ishft(ishft(1_int64, shift_), -1)
      if (kc - k0_ > span) kc = k0_ + span
      lut(i + 1_int64) = at(e, min(max(real(funkey(kc), real64), lo_), hi_))
   enddo
   endsubroutine colour_setup

   function colour_of(e, v) result(col)
   !< A value's colour: NaN colour, the constant field's middle, the table's bin or the map at t.
   type(field_entry), intent(in) :: e   !< Entry.
   real(real64),      intent(in) :: v   !< Value.
   integer(int32)                :: col !< Colour.

   if (masked(e%scale, v)) then
      col = e%nan
   elseif (const_) then
      col = cm_sample(e%cmap, 0.5_real32)
   elseif (table_) then
      col = lut(ishft(fkey(min(max(real(v, real32), real(lo_, real32)), real(hi_, real32))) - k0_, -shift_) + 1_int64)
   else
      col = at(e, min(max(v, lo_), hi_))
   endif
   endfunction colour_of

   function at(e, v) result(col)
   !< The colour of a value in [lo, hi]: t = (s(v) - s(lo)) / (s(hi) - s(lo)), clamped, as a float.
   type(field_entry), intent(in) :: e   !< Entry.
   real(real64),      intent(in) :: v   !< Value.
   integer(int32)                :: col !< Colour.
   real(real64)                  :: t   !< Position.

   t = (forward(e%scale, v) - s0_) * inv_
   col = cm_sample(e%cmap, real(min(max(t, 0.0_real64), 1.0_real64), real32))
   endfunction at

   pure function fkey(x) result(k)
   !< The order-preserving 32-bit key of a float (as an unsigned in an int64).
   real(real32), intent(in) :: x !< Value.
   integer(int64)           :: k !< Key.
   integer(int64)           :: u !< Bits.

   u = iand(int(transfer(x, 0_int32), int64), 4294967295_int64)
   if (btest(u, 31)) then
      k = ieor(u, 4294967295_int64)
   else
      k = ieor(u, 2147483648_int64)
   endif
   endfunction fkey

   pure function funkey(k) result(x)
   !< The float of a key.
   integer(int64), intent(in) :: k !< Key.
   real(real32)               :: x !< Value.
   integer(int64)             :: u !< Bits.

   if (btest(k, 31)) then
      u = ieor(k, 2147483648_int64)
   else
      u = ieor(k, 4294967295_int64)
   endif
   if (u >= 2147483648_int64) u = u - 4294967296_int64
   x = transfer(int(u, int32), x)
   endfunction funkey

   pure function to_u32(c) result(col)
   !< A colour packed as figure_field.cpp's `to_u32`: each channel clamped, times 255, `lround`.
   real(real32), intent(in) :: c(4) !< RGBA.
   integer(int32)           :: col  !< Packed.
   integer(int64)           :: u    !< Unsigned.
   integer(int32)           :: k    !< Channel.

   u = 0_int64
   do k = 1_int32, 4_int32
      u = ior(u, ishft(int(nint(min(max(c(k), 0.0_real32), 1.0_real32) * 255.0_real32), int64), 8 * (k - 1_int32)))
   enddo
   if (u >= 2147483648_int64) u = u - 4294967296_int64
   col = int(u, int32)
   endfunction to_u32
endmodule figure_plot_field
