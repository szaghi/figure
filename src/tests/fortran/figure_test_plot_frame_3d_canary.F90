!< figure_test_plot_frame_3d_canary, the arithmetic the Fortran 3-D frame shares with ImPlot3D, to the bit.
program figure_test_plot_frame_3d_canary
!< figure_test_plot_frame_3d_canary, the arithmetic the Fortran 3-D frame shares with ImPlot3D, to the bit.
!<
!< szaghi/figure#15 P13, step 1. ImPlot3D (built by g++ -O2 -ffp-contract=off) computes its rotation, rays and box with
!< `ImPlot3DPoint`'s products and sums, unfused, and libm's `sin`, `cos`, `acos` (g++ turns a sin/cos pair of one
!< argument into one `sincos` call) and the float `sinf`, `cosf`, `atan2f`, `acosf`. The Fortran frame computes them
!< with VecFor's `vector_R8P` (`.dot.`, `.cross.`, `sq_norm`, `normalized`) and with libm bound from C. Checked here
!< on 100000 pseudo-random vectors and angles (a fixed linear congruential sequence, the same on every compiler):
!<
!< 1. VecFor's dot and cross products, squared norm and normalized copy equal ImPlot3DPoint's operations written as
!<    statements of their own (`(a*b + c*d) + e*f`, no fused multiply-add: nvfortran fuses VecFor's one-line forms
!<    unless built with -Mnofma, which the nvfortran `-fortran` modes are);
!< 2. libm's `sincos` equals its `sin` and `cos`, and `sincosf` its `sinf` and `cosf` (so the g++ build and the
!<    Fortran calls agree).
!<
!< Reported, not checked: how often each compiler's intrinsic `sin` and `cos` differ from libm's (the reason the frame
!< binds libm from C). Not `acos` nor `atan2`: ifx 2026.2 aborts (an internal error) on either intrinsic compared, in
!< one expression, with libm's function of the same name bound from C.
use, intrinsic :: iso_c_binding, only : c_double, c_float
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64, output_unit
use vecfor_R8P, only : vector_R8P

implicit none
interface
   pure function c_sin(x) result(r) bind(C, name='sin')
   !< libm's sin.
   import :: c_double
   real(c_double), value, intent(in) :: x !< Argument [radians].
   real(c_double)                    :: r !< Sine.
   endfunction c_sin

   pure function c_cos(x) result(r) bind(C, name='cos')
   !< libm's cos.
   import :: c_double
   real(c_double), value, intent(in) :: x !< Argument [radians].
   real(c_double)                    :: r !< Cosine.
   endfunction c_cos

   pure function c_sinf(x) result(r) bind(C, name='sinf')
   !< libm's sinf.
   import :: c_float
   real(c_float), value, intent(in) :: x !< Argument [radians].
   real(c_float)                    :: r !< Sine.
   endfunction c_sinf

   pure function c_cosf(x) result(r) bind(C, name='cosf')
   !< libm's cosf.
   import :: c_float
   real(c_float), value, intent(in) :: x !< Argument [radians].
   real(c_float)                    :: r !< Cosine.
   endfunction c_cosf

   subroutine c_sincos(x, s, c) bind(C, name='sincos')
   !< libm's sincos (GNU).
   import :: c_double
   real(c_double), value, intent(in) :: x !< Argument [radians].
   real(c_double),        intent(out) :: s !< Sine.
   real(c_double),        intent(out) :: c !< Cosine.
   endsubroutine c_sincos

   subroutine c_sincosf(x, s, c) bind(C, name='sincosf')
   !< libm's sincosf (GNU).
   import :: c_float
   real(c_float), value, intent(in) :: x !< Argument [radians].
   real(c_float),        intent(out) :: s !< Sine.
   real(c_float),        intent(out) :: c !< Cosine.
   endsubroutine c_sincosf
endinterface

integer(int32), parameter :: N = 100000_int32 !< Samples.
integer(int64)            :: seed             !< The sequence's state.
type(vector_R8P)          :: a, b, v          !< Vectors.
real(real64)              :: t1, t2, t3, d, l !< Products and sums, apart.
real(real64)              :: x, s, c          !< An angle, its sine and cosine.
real(real32)              :: xf, sf, cf       !< The same in single precision.
integer(int32)            :: i                !< Sample.
integer(int32)            :: bad(8)           !< Failures: dot, cross, sq_norm, normalized, sincos, sincosf.
integer(int32)            :: dif(2)           !< Intrinsic against libm: sin, cos.

seed = 12345_int64
bad = 0_int32
dif = 0_int32
do i = 1_int32, N
   a%x = next(); a%y = next(); a%z = next()
   b%x = next(); b%y = next(); b%z = next()
   ! dot: (ax*bx + ay*by) + az*bz
   t1 = a%x * b%x
   t2 = a%y * b%y
   t3 = a%z * b%z
   d = t1 + t2
   d = d + t3
   if ((a .dot. b) /= d) bad(1) = bad(1) + 1_int32
   ! cross: y*rz - z*ry, z*rx - x*rz, x*ry - y*rx
   v = a .cross. b
   t1 = a%y * b%z
   t2 = a%z * b%y
   if (v%x /= t1 - t2) bad(2) = bad(2) + 1_int32
   t1 = a%z * b%x
   t2 = a%x * b%z
   if (v%y /= t1 - t2) bad(2) = bad(2) + 1_int32
   t1 = a%x * b%y
   t2 = a%y * b%x
   if (v%z /= t1 - t2) bad(2) = bad(2) + 1_int32
   ! squared norm and normalized copy: l = sqrt((x*x + y*y) + z*z), each component / l
   t1 = a%x * a%x
   t2 = a%y * a%y
   t3 = a%z * a%z
   d = t1 + t2
   d = d + t3
   if (a%sq_norm() /= d) bad(3) = bad(3) + 1_int32
   l = sqrt(d)
   v = a%normalized()
   if (v%x /= a%x / l .or. v%y /= a%y / l .or. v%z /= a%z / l) bad(4) = bad(4) + 1_int32
   ! sincos and its parts
   x = 10.0_real64 * next()
   call c_sincos(x, s, c)
   if (s /= c_sin(x) .or. c /= c_cos(x)) bad(5) = bad(5) + 1_int32
   xf = real(x, real32)
   call c_sincosf(xf, sf, cf)
   if (sf /= c_sinf(xf) .or. cf /= c_cosf(xf)) bad(6) = bad(6) + 1_int32
   ! the compilers' intrinsics, reported
   if (sin(x) /= c_sin(x)) dif(1) = dif(1) + 1_int32
   if (cos(x) /= c_cos(x)) dif(2) = dif(2) + 1_int32
enddo
write(output_unit, '(A,I0,A)') 'figure_test_plot_frame_3d_canary: ', N, ' samples'
write(output_unit, '(A,4(1X,I0))') '  VecFor against unfused statements (dot, cross, sq_norm, normalized), failures:', &
   bad(1:4)
write(output_unit, '(A,2(1X,I0))') '  libm sincos, sincosf against sin/cos, sinf/cosf, failures:', bad(5:6)
write(output_unit, '(A,2(1X,I0))') '  reported: the intrinsic sin and cos differing from libm''s:', dif
if (any(bad /= 0_int32)) then
   write(output_unit, '(A)') '  FAIL'
   error stop 1
endif
write(output_unit, '(A)') '  PASS'

contains
   function next() result(r)
   !< The next value of the sequence, in [-1, 1): two steps of Park and Miller's minimal standard generator (no
   !< integer overflow) make 53 random bits.
   real(real64)   :: r  !< Value.
   integer(int64) :: hi !< The first step's 31 bits.

   seed = mod(seed * 48271_int64, 2147483647_int64)
   hi = seed
   seed = mod(seed * 48271_int64, 2147483647_int64)
   r = real(ishft(hi, 22) + ishft(seed, -9), real64) * (2.0_real64 / 9007199254740992.0_real64) - 1.0_real64
   endfunction next
endprogram figure_test_plot_frame_3d_canary
