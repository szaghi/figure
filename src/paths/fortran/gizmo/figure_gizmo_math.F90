!< figure_gizmo_math, ImGuizmo's vectors and 4 x 4 matrices (`vec_t`, `matrix_t`) in single precision, as it computes.
module figure_gizmo_math
!< figure_gizmo_math, ImGuizmo's vectors and 4 x 4 matrices (`vec_t`, `matrix_t`) in single precision, as it computes.
!<
!< szaghi/figure#15 P14. The arithmetic of third_party/ImGuizmo/ImGuizmo.cpp's `vec_t` and `matrix_t` (and its free
!< `Frustum`, `Perspective`, `LookAt`, `Cross`, `Dot`, `Normalize`), operation by operation in `real32`, so the gizmos
!< of figure_gizmo move a matrix and draw the same pixels as ImGuizmo's: sums in ImGuizmo's order (parenthesised, so
!< no compiler reorders them), no fused multiply-add (the nvfortran `-fortran` modes build with `-Mnofma`, as the
!< native layer with `-ffp-contract=off`), libm's `sinf`, `cosf`, `tanf` where ImGuizmo calls them.
!<
!< A vector is `real(real32) :: v(4)` (x, y, z, w); a matrix `real(real32) :: m(4, 4)` holding ImGuizmo's `m16` in
!< order: `m(:, 1)` is its `v.right` (`m[0]`), `m(:, 2)` `v.up`, `m(:, 3)` `v.dir`, `m(:, 4)` `v.position`, and
!< `m(j, i)` its `m[i - 1][j - 1]`. ImGuizmo's matrices are OpenGL's column-major ones: `m(:, 4)` is the translation.
!< The 3-D view's own matrices and its camera's quaternion-free azimuth and elevation are figure_view3d's (real64);
!< VecFor's `vector_R8P` is not used here: ImGuizmo's numbers are single precision with a fourth component.
!<
!< `vadd`, `vsub`, `vmul`, `vneg` (a + b, a - b, a s, -a, component by component, as the operators compute them) are
!< what figure_gizmo passes to a procedure instead of an array expression: nvfortran 26.9 makes a heap temporary of
!< every array expression given as an actual argument (even of 4 elements), not of a function's result.
use, intrinsic :: iso_c_binding, only : c_float
use, intrinsic :: iso_fortran_env, only : int32, real32

implicit none
private
public :: FLT_EPSILON, FLT_MAX, ZPI, RAD2DEG, DEG2RAD
public :: vec, vec_length, vec_length_sq, vec_normalize, vec_normalized, vec_cross, vec_dot, vec_dot3, vec_dot4
public :: vec_lerp, vec_transform, vec_transform_point, vec_transform_vector, build_plan
public :: vadd, vsub, vmul, vneg
public :: mat_mul, mat_inverse, mat_identity, mat_translation, mat_scale, mat_rotation_axis, mat_ortho_normalize
public :: look_at, perspective
public :: c_sinf, c_cosf, c_tanf, c_acosf, c_atan2f, c_fmodf

real(real32), parameter :: FLT_EPSILON = epsilon(1.0_real32)          !< C's FLT_EPSILON.
real(real32), parameter :: FLT_MAX = huge(1.0_real32)                 !< C's FLT_MAX.
real(real32), parameter :: ZPI = 3.14159265358979323846_real32        !< ImGuizmo's ZPI.
real(real32), parameter :: RAD2DEG = 180.0_real32 / ZPI               !< ImGuizmo's RAD2DEG.
real(real32), parameter :: DEG2RAD = ZPI / 180.0_real32               !< ImGuizmo's DEG2RAD.

interface
   pure function c_sinf(x) result(r) bind(C, name='sinf')
   !< libm's sinf.
   import :: c_float
   implicit none
   real(c_float), value :: x !< Argument.
   real(c_float)        :: r !< Result.
   endfunction c_sinf

   pure function c_cosf(x) result(r) bind(C, name='cosf')
   !< libm's cosf.
   import :: c_float
   implicit none
   real(c_float), value :: x !< Argument.
   real(c_float)        :: r !< Result.
   endfunction c_cosf

   pure function c_tanf(x) result(r) bind(C, name='tanf')
   !< libm's tanf.
   import :: c_float
   implicit none
   real(c_float), value :: x !< Argument.
   real(c_float)        :: r !< Result.
   endfunction c_tanf

   pure function c_acosf(x) result(r) bind(C, name='acosf')
   !< libm's acosf.
   import :: c_float
   implicit none
   real(c_float), value :: x !< Argument.
   real(c_float)        :: r !< Result.
   endfunction c_acosf

   pure function c_atan2f(y, x) result(r) bind(C, name='atan2f')
   !< libm's atan2f.
   import :: c_float
   implicit none
   real(c_float), value :: y, x !< Arguments.
   real(c_float)        :: r    !< Result.
   endfunction c_atan2f

   pure function c_fmodf(x, y) result(r) bind(C, name='fmodf')
   !< libm's fmodf.
   import :: c_float
   implicit none
   real(c_float), value :: x, y !< Arguments.
   real(c_float)        :: r    !< Result.
   endfunction c_fmodf
endinterface

contains
   ! vectors

   pure function vec(x, y, z, w) result(v)
   !< `makeVect(x, y, z, w)` (z, w default 0).
   real(real32), intent(in)           :: x, y !< Components.
   real(real32), intent(in), optional :: z, w !< Components.
   real(real32)                       :: v(4) !< Vector.

   v = [x, y, 0.0_real32, 0.0_real32]
   if (present(z)) v(3) = z
   if (present(w)) v(4) = w
   endfunction vec

   pure function vadd(a, b) result(r)
   !< a + b.
   real(real32), intent(in) :: a(4), b(4)   !< Vectors.
   real(real32)             :: r(4)         !< Sum.

   r = a + b
   endfunction vadd

   pure function vsub(a, b) result(r)
   !< a - b.
   real(real32), intent(in) :: a(4), b(4)   !< Vectors.
   real(real32)             :: r(4)         !< Difference.

   r = a - b
   endfunction vsub

   pure function vmul(a, s) result(r)
   !< a s.
   real(real32), intent(in) :: a(4)         !< Vector.
   real(real32), intent(in) :: s            !< Factor.
   real(real32)             :: r(4)         !< Product.

   r = a * s
   endfunction vmul

   pure function vneg(a) result(r)
   !< -a.
   real(real32), intent(in) :: a(4)         !< Vector.
   real(real32)             :: r(4)         !< Opposite.

   r = -a
   endfunction vneg

   pure function vec_length_sq(v) result(l)
   !< `LengthSq`: x x + y y + z z.
   real(real32), intent(in) :: v(4) !< Vector.
   real(real32)             :: l    !< Squared length.
   real(real32)             :: a, b, c !< Products.

   a = v(1) * v(1)
   b = v(2) * v(2)
   c = v(3) * v(3)
   l = (a + b) + c
   endfunction vec_length_sq

   pure function vec_length(v) result(l)
   !< `Length`: sqrtf(LengthSq).
   real(real32), intent(in) :: v(4) !< Vector.
   real(real32)             :: l    !< Length.

   l = sqrt(vec_length_sq(v))
   endfunction vec_length

   pure subroutine vec_normalize(v)
   !< `vec_t::Normalize`: the four components times 1 / max(Length, FLT_EPSILON) (Length > FLT_EPSILON, else
   !< FLT_EPSILON).
   real(real32), intent(inout) :: v(4) !< Vector.
   real(real32)                :: l, s !< Length, factor.

   l = vec_length(v)
   if (.not. l > FLT_EPSILON) l = FLT_EPSILON
   s = 1.0_real32 / l
   v = v * s
   endsubroutine vec_normalize

   pure function vec_normalized(v) result(r)
   !< `Normalized(v)`.
   real(real32), intent(in) :: v(4) !< Vector.
   real(real32)             :: r(4) !< Normalized.

   r = v
   call vec_normalize(r)
   endfunction vec_normalized

   pure function vec_cross(a, b) result(r)
   !< `Cross(a, b)`, w 0.
   real(real32), intent(in) :: a(4), b(4) !< Vectors.
   real(real32)             :: r(4)       !< Cross product.
   real(real32)             :: p, q       !< Products.

   p = a(2) * b(3)
   q = a(3) * b(2)
   r(1) = p - q
   p = a(3) * b(1)
   q = a(1) * b(3)
   r(2) = p - q
   p = a(1) * b(2)
   q = a(2) * b(1)
   r(3) = p - q
   r(4) = 0.0_real32
   endfunction vec_cross

   pure function vec_dot(a, b) result(d)
   !< The free `Dot(v1, v2)` (and `Dot3`): x, y, z.
   real(real32), intent(in) :: a(4), b(4) !< Vectors.
   real(real32)             :: d          !< Dot product.
   real(real32)             :: p, q, r    !< Products.

   p = a(1) * b(1)
   q = a(2) * b(2)
   r = a(3) * b(3)
   d = (p + q) + r
   endfunction vec_dot

   pure function vec_dot3(a, b) result(d)
   !< `vec_t::Dot3`.
   real(real32), intent(in) :: a(4), b(4) !< Vectors.
   real(real32)             :: d          !< Dot product.

   d = vec_dot(a, b)
   endfunction vec_dot3

   pure function vec_dot4(a, b) result(d)
   !< `vec_t::Dot`: the four components.
   real(real32), intent(in) :: a(4), b(4) !< Vectors.
   real(real32)             :: d          !< Dot product.
   real(real32)             :: p, q, r, s !< Products.

   p = a(1) * b(1)
   q = a(2) * b(2)
   r = a(3) * b(3)
   s = a(4) * b(4)
   d = ((p + q) + r) + s
   endfunction vec_dot4

   pure subroutine vec_lerp(v, b, t)
   !< `vec_t::Lerp`: v += (b - v) t.
   real(real32), intent(inout) :: v(4) !< Vector.
   real(real32), intent(in)    :: b(4) !< Target.
   real(real32), intent(in)    :: t    !< Fraction.
   real(real32)                :: d    !< A difference times t.
   integer(int32)              :: k    !< Component.

   do k = 1_int32, 4_int32
      d = (b(k) - v(k)) * t
      v(k) = v(k) + d
   enddo
   endsubroutine vec_lerp

   pure function vec_transform(v, m) result(r)
   !< `vec_t::Transform`: the four components through the matrix (w included).
   real(real32), intent(in) :: v(4), m(4,4) !< Vector, matrix.
   real(real32)             :: r(4)         !< Transformed.
   integer(int32)           :: j            !< Component.

   do j = 1_int32, 4_int32
      r(j) = ((v(1) * m(j, 1) + v(2) * m(j, 2)) + v(3) * m(j, 3)) + v(4) * m(j, 4)
   enddo
   endfunction vec_transform

   pure function vec_transform_point(v, m) result(r)
   !< `vec_t::TransformPoint`: x, y, z through the matrix, plus its translation row (the input's w ignored).
   real(real32), intent(in) :: v(4), m(4,4) !< Vector, matrix.
   real(real32)             :: r(4)         !< Transformed.
   integer(int32)           :: j            !< Component.

   do j = 1_int32, 4_int32
      r(j) = ((v(1) * m(j, 1) + v(2) * m(j, 2)) + v(3) * m(j, 3)) + m(j, 4)
   enddo
   endfunction vec_transform_point

   pure function vec_transform_vector(v, m) result(r)
   !< `vec_t::TransformVector`: x, y, z through the matrix, no translation.
   real(real32), intent(in) :: v(4), m(4,4) !< Vector, matrix.
   real(real32)             :: r(4)         !< Transformed.
   integer(int32)           :: j            !< Component.

   do j = 1_int32, 4_int32
      r(j) = (v(1) * m(j, 1) + v(2) * m(j, 2)) + v(3) * m(j, 3)
   enddo
   endfunction vec_transform_vector

   pure function build_plan(p, n) result(r)
   !< `BuildPlan(point, normal)`: the normal normalised (its four components), w its four-component dot with the point.
   real(real32), intent(in) :: p(4), n(4) !< Point, normal.
   real(real32)             :: r(4)       !< Plane (normal, distance).
   real(real32)             :: u(4)       !< Normal.

   u = vec_normalized(n)
   r(4) = vec_dot4(u, p)
   r(1:3) = u(1:3)
   endfunction build_plan

   ! matrices

   pure function mat_mul(a, b) result(r)
   !< `a * b` (`FPU_MatrixF_x_MatrixF(a, b, r)`): r[i][j] = sum over k of a[i][k] b[k][j], left to right.
   real(real32), intent(in) :: a(4,4), b(4,4) !< Matrices.
   real(real32)             :: r(4,4)         !< Product.
   integer(int32)           :: i, j           !< Row, column (ImGuizmo's).

   do i = 1_int32, 4_int32
      do j = 1_int32, 4_int32
         r(j, i) = ((a(1, i) * b(j, 1) + a(2, i) * b(j, 2)) + a(3, i) * b(j, 3)) + a(4, i) * b(j, 4)
      enddo
   enddo
   endfunction mat_mul

   pure function mat_identity() result(m)
   !< `SetToIdentity`.
   real(real32) :: m(4,4) !< Identity.

   m = 0.0_real32
   m(1, 1) = 1.0_real32
   m(2, 2) = 1.0_real32
   m(3, 3) = 1.0_real32
   m(4, 4) = 1.0_real32
   endfunction mat_identity

   pure function mat_translation(t) result(m)
   !< `Translation(t)`: the identity, its position (t.x, t.y, t.z, 1).
   real(real32), intent(in) :: t(4)   !< Translation.
   real(real32)             :: m(4,4) !< Matrix.

   m = mat_identity()
   m(1:3, 4) = t(1:3)
   endfunction mat_translation

   pure function mat_scale(s) result(m)
   !< `Scale(s)`: the diagonal (s.x, s.y, s.z, 1).
   real(real32), intent(in) :: s(4)   !< Scales.
   real(real32)             :: m(4,4) !< Matrix.

   m = mat_identity()
   m(1, 1) = s(1)
   m(2, 2) = s(2)
   m(3, 3) = s(3)
   endfunction mat_scale

   pure subroutine mat_ortho_normalize(m)
   !< `OrthoNormalize`: right, up and dir normalised (`vec_t::Normalize`, their w too).
   real(real32), intent(inout) :: m(4,4) !< Matrix.

   call vec_normalize(m(:, 1))
   call vec_normalize(m(:, 2))
   call vec_normalize(m(:, 3))
   endsubroutine mat_ortho_normalize

   pure function mat_inverse(src4) result(m)
   !< `matrix_t::Inverse(src)` (not affine): the cofactors of the transpose, in ImGuizmo's order, over the determinant.
   real(real32), intent(in) :: src4(4,4) !< Matrix.
   real(real32)             :: m(4,4)    !< Inverse.
   real(real32)             :: s(0:15), t(0:11), o(0:15), det, invdet !< Transpose, pairs, result, determinant.
   integer(int32)           :: i         !< Counter.

   do i = 0_int32, 3_int32 ! src[i] = m16[i * 4], ...: the transpose
      s(i) = src4(1, i + 1_int32)
      s(i + 4_int32) = src4(2, i + 1_int32)
      s(i + 8_int32) = src4(3, i + 1_int32)
      s(i + 12_int32) = src4(4, i + 1_int32)
   enddo
   t(0) = s(10) * s(15)
   t(1) = s(11) * s(14)
   t(2) = s(9) * s(15)
   t(3) = s(11) * s(13)
   t(4) = s(9) * s(14)
   t(5) = s(10) * s(13)
   t(6) = s(8) * s(15)
   t(7) = s(11) * s(12)
   t(8) = s(8) * s(14)
   t(9) = s(10) * s(12)
   t(10) = s(8) * s(13)
   t(11) = s(9) * s(12)
   o(0) = c3(t(0), s(5), t(3), s(6), t(4), s(7)) - c3(t(1), s(5), t(2), s(6), t(5), s(7))
   o(1) = c3(t(1), s(4), t(6), s(6), t(9), s(7)) - c3(t(0), s(4), t(7), s(6), t(8), s(7))
   o(2) = c3(t(2), s(4), t(7), s(5), t(10), s(7)) - c3(t(3), s(4), t(6), s(5), t(11), s(7))
   o(3) = c3(t(5), s(4), t(8), s(5), t(11), s(6)) - c3(t(4), s(4), t(9), s(5), t(10), s(6))
   o(4) = c3(t(1), s(1), t(2), s(2), t(5), s(3)) - c3(t(0), s(1), t(3), s(2), t(4), s(3))
   o(5) = c3(t(0), s(0), t(7), s(2), t(8), s(3)) - c3(t(1), s(0), t(6), s(2), t(9), s(3))
   o(6) = c3(t(3), s(0), t(6), s(1), t(11), s(3)) - c3(t(2), s(0), t(7), s(1), t(10), s(3))
   o(7) = c3(t(4), s(0), t(9), s(1), t(10), s(2)) - c3(t(5), s(0), t(8), s(1), t(11), s(2))
   t(0) = s(2) * s(7)
   t(1) = s(3) * s(6)
   t(2) = s(1) * s(7)
   t(3) = s(3) * s(5)
   t(4) = s(1) * s(6)
   t(5) = s(2) * s(5)
   t(6) = s(0) * s(7)
   t(7) = s(3) * s(4)
   t(8) = s(0) * s(6)
   t(9) = s(2) * s(4)
   t(10) = s(0) * s(5)
   t(11) = s(1) * s(4)
   o(8) = c3(t(0), s(13), t(3), s(14), t(4), s(15)) - c3(t(1), s(13), t(2), s(14), t(5), s(15))
   o(9) = c3(t(1), s(12), t(6), s(14), t(9), s(15)) - c3(t(0), s(12), t(7), s(14), t(8), s(15))
   o(10) = c3(t(2), s(12), t(7), s(13), t(10), s(15)) - c3(t(3), s(12), t(6), s(13), t(11), s(15))
   o(11) = c3(t(5), s(12), t(8), s(13), t(11), s(14)) - c3(t(4), s(12), t(9), s(13), t(10), s(14))
   o(12) = c3(t(2), s(10), t(5), s(11), t(1), s(9)) - c3(t(4), s(11), t(0), s(9), t(3), s(10))
   o(13) = c3(t(8), s(11), t(0), s(8), t(7), s(10)) - c3(t(6), s(10), t(9), s(11), t(1), s(8))
   o(14) = c3(t(6), s(9), t(11), s(11), t(3), s(8)) - c3(t(10), s(11), t(2), s(8), t(7), s(9))
   o(15) = c3(t(10), s(10), t(4), s(8), t(9), s(9)) - c3(t(8), s(9), t(11), s(10), t(5), s(8))
   det = ((s(0) * o(0) + s(1) * o(1)) + s(2) * o(2)) + s(3) * o(3)
   invdet = 1.0_real32 / det
   do i = 0_int32, 15_int32
      m(mod(i, 4_int32) + 1_int32, i / 4_int32 + 1_int32) = o(i) * invdet
   enddo
   contains
      pure function c3(a, b, c, d, e, f) result(r)
      !< a b + c d + e f, left to right.
      real(real32), intent(in) :: a, b, c, d, e, f !< Factors.
      real(real32)             :: r                !< Sum.
      real(real32)             :: p, q, u          !< Products.

      p = a * b
      q = c * d
      u = e * f
      r = (p + q) + u
      endfunction c3
   endfunction mat_inverse

   pure function mat_rotation_axis(axis, angle) result(m)
   !< `RotationAxis(axis, angle)`: the rotation by `angle` [radians] about `axis` (the identity for an axis shorter than
   !< sqrt(FLT_EPSILON)).
   real(real32), intent(in) :: axis(4) !< Axis.
   real(real32), intent(in) :: angle   !< Angle [radians].
   real(real32)             :: m(4,4)  !< Rotation.
   real(real32)             :: l2, n(4), s, c, k, xx, yy, zz, xy, yz, zx, xs, ys, zs !< ImGuizmo's terms.

   l2 = vec_length_sq(axis)
   if (l2 < FLT_EPSILON) then
      m = mat_identity()
      return
   endif
   n = axis * (1.0_real32 / sqrt(l2))
   s = c_sinf(angle)
   c = c_cosf(angle)
   k = 1.0_real32 - c
   xx = (n(1) * n(1)) * k
   xx = xx + c
   yy = (n(2) * n(2)) * k
   yy = yy + c
   zz = (n(3) * n(3)) * k
   zz = zz + c
   xy = (n(1) * n(2)) * k
   yz = (n(2) * n(3)) * k
   zx = (n(3) * n(1)) * k
   xs = n(1) * s
   ys = n(2) * s
   zs = n(3) * s
   m(:, 1) = [xx, xy + zs, zx - ys, 0.0_real32]
   m(:, 2) = [xy - zs, yy, yz + xs, 0.0_real32]
   m(:, 3) = [zx + ys, yz - xs, zz, 0.0_real32]
   m(:, 4) = [0.0_real32, 0.0_real32, 0.0_real32, 1.0_real32]
   endfunction mat_rotation_axis

   pure subroutine normalize3(a, r)
   !< The free `Normalize(a, r)`: a / (sqrtf(Dot(a, a)) + FLT_EPSILON).
   real(real32), intent(in)  :: a(3) !< Vector.
   real(real32), intent(out) :: r(3) !< Normalized.
   real(real32)              :: il   !< Inverse length.

   il = 1.0_real32 / (sqrt(dot3f(a, a)) + FLT_EPSILON)
   r = a * il
   endsubroutine normalize3

   pure function dot3f(a, b) result(d)
   !< The free `Dot(a, b)` of three floats.
   real(real32), intent(in) :: a(3), b(3) !< Vectors.
   real(real32)             :: d          !< Dot product.
   real(real32)             :: p, q, r    !< Products.

   p = a(1) * b(1)
   q = a(2) * b(2)
   r = a(3) * b(3)
   d = (p + q) + r
   endfunction dot3f

   pure function cross3f(a, b) result(r)
   !< The free `Cross(a, b, r)` of three floats.
   real(real32), intent(in) :: a(3), b(3) !< Vectors.
   real(real32)             :: r(3)       !< Cross product.
   real(real32)             :: p, q       !< Products.

   p = a(2) * b(3)
   q = a(3) * b(2)
   r(1) = p - q
   p = a(3) * b(1)
   q = a(1) * b(3)
   r(2) = p - q
   p = a(1) * b(2)
   q = a(2) * b(1)
   r(3) = p - q
   endfunction cross3f

   pure function look_at(eye, at, up, right_handed) result(m)
   !< `LookAt(eye, at, up, m16, rightHanded)`.
   real(real32), intent(in) :: eye(3), at(3), up(3) !< Eye, target, up.
   logical,      intent(in) :: right_handed         !< Right-handed.
   real(real32)             :: m(4,4)               !< View matrix.
   real(real32)             :: x(3), y(3), z(3), tmp(3) !< Basis, scratch.

   if (right_handed) then
      tmp = eye - at
   else
      tmp = at - eye
   endif
   call normalize3(tmp, z)
   call normalize3(up, y)
   tmp = cross3f(y, z)
   call normalize3(tmp, x)
   tmp = cross3f(z, x)
   call normalize3(tmp, y)
   m(:, 1) = [x(1), y(1), z(1), 0.0_real32]
   m(:, 2) = [x(2), y(2), z(2), 0.0_real32]
   m(:, 3) = [x(3), y(3), z(3), 0.0_real32]
   m(:, 4) = [-dot3f(x, eye), -dot3f(y, eye), -dot3f(z, eye), 1.0_real32]
   endfunction look_at

   pure function perspective(fovy, aspect, znear, zfar, right_handed) result(m)
   !< `Perspective(fovyInDegrees, aspectRatio, znear, zfar, m16, rightHanded)` (ImGuizmo's: tanf of the whole angle),
   !< through `Frustum`.
   real(real32), intent(in) :: fovy, aspect, znear, zfar !< Field of view [degrees], aspect, planes.
   logical,      intent(in) :: right_handed              !< Right-handed.
   real(real32)             :: m(4,4)                    !< Projection.
   real(real32)             :: ymax, xmax, temp, temp2, temp3, temp4, sgn, left, right, bottom, top !< Frustum's terms.

   ymax = znear * c_tanf(fovy * DEG2RAD)
   xmax = ymax * aspect
   left = -xmax
   right = xmax
   bottom = -ymax
   top = ymax
   temp = 2.0_real32 * znear
   temp2 = right - left
   temp3 = top - bottom
   temp4 = zfar - znear
   sgn = merge(-1.0_real32, 1.0_real32, right_handed)
   m = 0.0_real32
   m(1, 1) = temp / temp2
   m(2, 2) = temp / temp3
   m(1, 3) = (right + left) / temp2
   m(2, 3) = (top + bottom) / temp3
   m(3, 3) = sgn * (zfar + znear) / temp4
   m(4, 3) = sgn
   m(3, 4) = (-temp * zfar) / temp4
   endfunction perspective
endmodule figure_gizmo_math
