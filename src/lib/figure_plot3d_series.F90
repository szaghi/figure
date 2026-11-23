!< figure_plot3d_series, the 3-D items' argument checks that do not depend on the plot library.
module figure_plot3d_series
!< figure_plot3d_series, the 3-D items' argument checks that do not depend on the plot library.
!<
!< szaghi/figure#15 P13 (the 3-D seam, as figure_plot_series for the 2-D one): what figure_implot3d (over ImPlot3D, the
!< current path) and the Fortran 3-D frame (src/paths/fortran/plot3d/) both need, moved verbatim from figure_implot3d:
!< a surface's colour range (`field_range_r32`, `field_range_r64`), the checks of per-point colours and sizes
!< (`per_point_ok`), of a grid's shapes (`grid_ok`), of an optional colour (`rgba_ok`), and colours packed as Dear
!< ImGui packs them (`packed_colors`).
use, intrinsic :: iso_c_binding, only : c_double, c_int
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use, intrinsic :: ieee_arithmetic, only : ieee_is_finite
use figure_base, only : figure_fail
use figure_c_native, only : FIG_ERR_ARGUMENT

implicit none
private
public :: field_range_r32, field_range_r64, grid_ok, packed_colors, per_point_ok, rgba_ok

contains
   subroutine field_range_r32(z, scale_min, scale_max, lo, hi)
   !< The heights at a surface's first and last colours: the given ones, else z's finite range (widened by one about
   !< its centre when z is flat: ImPlot3D would divide by a zero range, an FPE under traps).
   real(real32),   intent(in), asynchronous :: z(:,:)    !< Heights.
   real(real64),   intent(in), optional     :: scale_min !< Given first height.
   real(real64),   intent(in), optional     :: scale_max !< Given last height.
   real(c_double), intent(out)              :: lo        !< First height.
   real(c_double), intent(out)              :: hi        !< Last height.

   if (present(scale_min)) then
      lo = real(scale_min, c_double)
      hi = real(scale_max, c_double)
      return
   endif
   lo = real(minval(z, mask=ieee_is_finite(z)), c_double)
   hi = real(maxval(z, mask=ieee_is_finite(z)), c_double)
   if (.not. lo < hi) then
      if (.not. (ieee_is_finite(lo) .and. ieee_is_finite(hi))) then
         lo = 0.0_c_double
         hi = 0.0_c_double
      endif
      lo = lo - 0.5_c_double
      hi = hi + 0.5_c_double
   endif
   endsubroutine field_range_r32

   subroutine field_range_r64(z, scale_min, scale_max, lo, hi)
   !< The heights at a surface's first and last colours: the given ones, else z's finite range (widened by one about
   !< its centre when z is flat: ImPlot3D would divide by a zero range, an FPE under traps).
   real(real64),   intent(in), asynchronous :: z(:,:)    !< Heights.
   real(real64),   intent(in), optional     :: scale_min !< Given first height.
   real(real64),   intent(in), optional     :: scale_max !< Given last height.
   real(c_double), intent(out)              :: lo        !< First height.
   real(c_double), intent(out)              :: hi        !< Last height.

   if (present(scale_min)) then
      lo = real(scale_min, c_double)
      hi = real(scale_max, c_double)
      return
   endif
   lo = real(minval(z, mask=ieee_is_finite(z)), c_double)
   hi = real(maxval(z, mask=ieee_is_finite(z)), c_double)
   if (.not. lo < hi) then
      if (.not. (ieee_is_finite(lo) .and. ieee_is_finite(hi))) then
         lo = 0.0_c_double
         hi = 0.0_c_double
      endif
      lo = lo - 0.5_c_double
      hi = hi + 0.5_c_double
   endif
   endsubroutine field_range_r64

   function per_point_ok(who, n, colors, sizes, stat) result(ok)
   !< Whether the per-point colours, (4, n) in [0, 1], and radii, n finite values >= 0, fit an item of n points.
   character(len=*), intent(in)            :: who         !< Calling procedure, for the message.
   integer(int64),   intent(in)            :: n           !< Points.
   real(real64),     intent(in), optional  :: colors(:,:) !< Per-point RGBA.
   real(real64),     intent(in), optional  :: sizes(:)    !< Per-point radii [pixels].
   integer(int32),   intent(out), optional :: stat        !< Status, on a failure.
   logical                                 :: ok          !< Acceptable.

   ok = .false.
   if (present(colors)) then
      if (size(colors, 1, kind=int64) /= 4_int64 .or. size(colors, 2, kind=int64) /= n) then
         call figure_fail(FIG_ERR_ARGUMENT, who//': colors must be (4, size(x)): one RGBA per point', stat)
         return
      endif
      if (.not. all(colors >= 0.0_real64 .and. colors <= 1.0_real64)) then
         call figure_fail(FIG_ERR_ARGUMENT, who//': colour components must be in [0, 1]', stat)
         return
      endif
   endif
   if (present(sizes)) then
      if (size(sizes, kind=int64) /= n) then
         call figure_fail(FIG_ERR_ARGUMENT, who//': sizes must be one per point', stat)
         return
      endif
      if (.not. all(sizes >= 0.0_real64 .and. sizes <= huge(1.0_real32))) then
         call figure_fail(FIG_ERR_ARGUMENT, who//': sizes must be finite and not below 0', stat)
         return
      endif
   endif
   ok = .true.
   endfunction per_point_ok

   recursive function grid_ok(sx, sy, sz, stat) result(ok)
   !< Whether the vertex arrays of a surface over a grid all have z's shape (`FIG_ERR_ARGUMENT` otherwise).
   integer(int64), intent(in)            :: sx(2) !< Shape of x.
   integer(int64), intent(in)            :: sy(2) !< Shape of y.
   integer(int64), intent(in)            :: sz(2) !< Shape of z.
   integer(int32), intent(out), optional :: stat  !< Status, on a refusal.
   logical                               :: ok    !< Same shapes.

   ok = all(sx == sz) .and. all(sy == sz)
   if (.not. ok) call figure_fail(FIG_ERR_ARGUMENT, 'ip3_surface: x, y and z of a grid must have the same shape', stat)
   endfunction grid_ok

   pure function packed_colors(colors) result(u)
   !< RGBA colours in [0, 1], one per column, packed as Dear ImGui's ImU32 (R in the low byte, A in the high one).
   real(real64), intent(in) :: colors(:,:) !< RGBA, (4, n).
   integer(c_int)           :: u(size(colors, 2)) !< Packed colours.
   integer(int64)           :: c(4)        !< Components, 0-255.
   integer(int64)           :: w           !< Packed, unsigned.
   integer                  :: i           !< Counter.

   do i = 1, size(colors, 2)
      c = int(min(max(colors(:, i), 0.0_real64), 1.0_real64) * 255.0_real64 + 0.5_real64, int64)
      w = c(1) + c(2) * 256_int64 + c(3) * 65536_int64 + c(4) * 16777216_int64
      if (w >= 2147483648_int64) w = w - 4294967296_int64 ! the same bits as a signed C int
      u(i) = int(w, c_int)
   enddo
   endfunction packed_colors

   pure function rgba_ok(color) result(ok)
   !< Whether an optional colour is absent or has 4 components.
   real(real64), intent(in), optional :: color(:) !< Colour, RGBA.
   logical                            :: ok       !< Acceptable.

   ok = .true.
   if (present(color)) ok = size(color) == 4
   endfunction rgba_ok
endmodule figure_plot3d_series
