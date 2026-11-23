!< figure_plot3d_camera, the 3-D plot's rotation, its maps between plot, NDC and pixels, its box and rays (ImPlot3D's).
module figure_plot3d_camera
!< figure_plot3d_camera, the 3-D plot's rotation, its maps between plot, NDC and pixels, its box and rays (ImPlot3D's).
!<
!< szaghi/figure#15 P13. The camera of the Fortran 3-D frame (figure_plot3d_frame), reproduced from implot3d.cpp
!< (ImPlot3D 0.6 WIP, FIGURE's copy) operation for operation:
!<
!< - the rotation (`plot3d_quat`, `ImPlot3DQuat`): from an angle and an axis, from elevation and azimuth (`FromElAz`),
!<   from two vectors (`FromTwoVectors`), the product, inverse, normalisation, a vector rotated (`q * v`: two cross
!<   products, `v + uv w 2 + uuv 2`), `Slerp`;
!< - the state of a plot that the maps read (`view3d`): the rotation, the plot rectangle, the three axes' ranges, scales
!<   (linear, log10, symlog: figure_plot_locators' transforms), inversion and NDC scale (`SetupBoxScale`);
!< - the maps: `plot_to_ndc`, `ndc_to_plot`, `ndc_to_pixels`, `plot_to_pixels`, `pixels_to_ndc_ray`,
!<   `ndc_ray_to_plot_ray`, `pixels_to_plot_plane`, `point_depth` (`GetPointDepth`: the plot point rotated as is);
!< - the box: `active_faces` (`ComputeActiveFaces`, the 2-D plane when two faces are seen edge on), `box_corners`,
!<   `box_corners_pix`, `axes_parameters` (`GetAxesParameters`: the corners of each axis's edge), the faces' and edges'
!<   tables; hover geometry: `mouse_over_plane`, `edge_outward_dir`, `in_edge_region`, `triangle_contains`.
!<
!< VecFor's `vector_R8P` carries the per-frame vector algebra (the rays, `FromTwoVectors`, the tick directions); the
!< per-point maps (`plot_to_pixels`, `point_depth`) are scalar code with the same operations in the same order. Sums
!< are written left to right with the parentheses C's evaluation implies; the nvfortran `-fortran` modes build without
!< FMA (`-Mnofma`), as ImPlot3D is built (`-ffp-contract=off`). libm's `sin`, `cos`, `acos` are bound from C (the
!< compilers' intrinsics differ in the last bit). ImPlot3D mixes float and double: `IM_PI` is a float
!< (`elevation * IM_PI / 180.0` multiplies by the float's double value), the view scale and the pixel centre are
!< floats, the ray's pixel offsets are float quotients, the plane test's `1e-12f` is a float literal; each is kept.
use, intrinsic :: iso_c_binding, only : c_double, c_float
use, intrinsic :: iso_fortran_env, only : int32, real32, real64
use, intrinsic :: ieee_arithmetic, only : ieee_quiet_nan, ieee_value
use vecfor_R8P, only : vector_R8P
use figure_plot_locators, only : transform_log10, inverse_log10, transform_symlog, inverse_symlog

implicit none
private
public :: plot3d_quat, view3d
public :: quat_axis_angle, quat_from_el_az, quat_from_two_vectors, quat_mul, quat_inverse, quat_normalize, quat_dot
public :: quat_slerp, quat_rotate, quat_rotate_v
public :: view_scale, rect_center, plot_to_ndc, ndc_to_plot, ndc_to_pixels, plot_to_pixels, axis_ndc_to_plot
public :: pixels_to_ndc_ray, ndc_ray_to_plot_ray, pixels_to_plot_plane, point_depth
public :: active_faces, box_corners, box_corners_pix, axes_parameters
public :: mouse_over_plane, edge_outward_dir, in_edge_region, triangle_contains
public :: c_sin, c_cos, c_acos, c_sinf, c_cosf, c_atan2f, c_acosf
public :: SCALE3_LINEAR, SCALE3_LOG10, SCALE3_SYMLOG, IM_PI_F, FACES, EDGES, FACE_EDGES

real(real32),   parameter :: IM_PI_F = 3.14159265358979323846_real32 !< Dear ImGui's IM_PI (a float).
integer(int32), parameter :: SCALE3_LINEAR = 0_int32 !< ImPlot3DScale_Linear.
integer(int32), parameter :: SCALE3_LOG10 = 1_int32  !< ImPlot3DScale_Log10.
integer(int32), parameter :: SCALE3_SYMLOG = 2_int32 !< ImPlot3DScale_SymLog.
! the box's tables, 0-based corner and edge indices as ImPlot3D's
integer(int32), parameter :: FACES(0:3, 0:5) = reshape([0, 3, 7, 4, 0, 4, 5, 1, 0, 1, 2, 3, 1, 2, 6, 5, 3, 7, 6, 2, &
                                                        4, 5, 6, 7], [4, 6]) !< Corners of each face.
integer(int32), parameter :: EDGES(0:1, 0:11) = reshape([0, 1, 1, 2, 2, 3, 3, 0, 4, 5, 5, 6, 6, 7, 7, 4, 0, 4, 1, 5, &
                                                         2, 6, 3, 7], [2, 12]) !< Corners of each edge.
integer(int32), parameter :: FACE_EDGES(0:3, 0:5) = reshape([3, 11, 8, 7, 0, 8, 4, 9, 0, 1, 2, 3, 1, 9, 5, 10, 2, 10, &
                                                             6, 11, 4, 5, 6, 7], [4, 6]) !< Edges of each face.
integer(int32), parameter :: AXIS_CORNERS_3D(0:1, 0:2, 0:7) = reshape([3, 2, 1, 2, 1, 5, 7, 6, 5, 6, 1, 5, &
                                                                       0, 1, 1, 2, 2, 6, 4, 5, 5, 6, 2, 6, &
                                                                       3, 2, 0, 3, 0, 4, 7, 6, 4, 7, 0, 4, &
                                                                       0, 1, 0, 3, 3, 7, 4, 5, 4, 7, 3, 7], &
                                                                      [2, 3, 8]) !< axis_corners_lookup_3d.

type :: plot3d_quat
   !< A rotation (`ImPlot3DQuat`): x, y, z the vector part, w the scalar one.
   real(real64) :: x = 0.0_real64 !< x.
   real(real64) :: y = 0.0_real64 !< y.
   real(real64) :: z = 0.0_real64 !< z.
   real(real64) :: w = 1.0_real64 !< w.
endtype plot3d_quat

type :: view3d
   !< What the maps read of a plot: its rotation, its plot rectangle, its axes (ranges, scales, inversion, NDC scale).
   type(plot3d_quat) :: rot                        !< Rotation.
   real(real32)      :: rect(4) = 0.0_real32       !< PlotRect: min x, min y, max x, max y [pixels].
   real(real32)      :: factor = 1.0_real32        !< ImPlot3DStyle::ViewScaleFactor.
   real(real64)      :: rmin(3) = 0.0_real64       !< Ranges' minima.
   real(real64)      :: rmax(3) = 1.0_real64       !< Ranges' maxima.
   real(real64)      :: smin(3) = 0.0_real64       !< Scaled ranges' minima (ScaledRange).
   real(real64)      :: smax(3) = 1.0_real64       !< Scaled ranges' maxima.
   real(real64)      :: ndc(3) = 1.0_real64        !< NDCScale.
   integer(int32)    :: scale(3) = SCALE3_LINEAR   !< Scales.
   logical           :: invert(3) = .false.        !< ImPlot3DAxisFlags_Invert.
endtype view3d

interface
   pure function c_sin(x) result(r) bind(C, name='sin')
   !< C's `sin`.
   import :: c_double
   implicit none
   real(c_double), value :: x !< Angle.
   real(c_double)        :: r !< Sine.
   endfunction c_sin

   pure function c_cos(x) result(r) bind(C, name='cos')
   !< C's `cos`.
   import :: c_double
   implicit none
   real(c_double), value :: x !< Angle.
   real(c_double)        :: r !< Cosine.
   endfunction c_cos

   pure function c_acos(x) result(r) bind(C, name='acos')
   !< C's `acos`.
   import :: c_double
   implicit none
   real(c_double), value :: x !< Cosine.
   real(c_double)        :: r !< Angle.
   endfunction c_acos

   pure function c_sinf(x) result(r) bind(C, name='sinf')
   !< C's `sinf`.
   import :: c_float
   implicit none
   real(c_float), value :: x !< Angle.
   real(c_float)        :: r !< Sine.
   endfunction c_sinf

   pure function c_cosf(x) result(r) bind(C, name='cosf')
   !< C's `cosf`.
   import :: c_float
   implicit none
   real(c_float), value :: x !< Angle.
   real(c_float)        :: r !< Cosine.
   endfunction c_cosf

   pure function c_atan2f(y, x) result(r) bind(C, name='atan2f')
   !< C's `atan2f`.
   import :: c_float
   implicit none
   real(c_float), value :: y !< Ordinate.
   real(c_float), value :: x !< Abscissa.
   real(c_float)        :: r !< Angle.
   endfunction c_atan2f

   pure function c_acosf(x) result(r) bind(C, name='acosf')
   !< C's `acosf`.
   import :: c_float
   implicit none
   real(c_float), value :: x !< Cosine.
   real(c_float)        :: r !< Angle.
   endfunction c_acosf
endinterface

contains
   ! the rotation

   pure function quat_axis_angle(angle, ax) result(q)
   !< `ImPlot3DQuat(angle, axis)`: half the angle's sine times the axis, its cosine.
   real(real64), intent(in) :: angle !< Angle [radians].
   real(real64), intent(in) :: ax(3) !< Axis (unit).
   type(plot3d_quat)        :: q     !< Rotation.
   real(real64)             :: h, s  !< Half angle, its sine.

   h = angle * 0.5_real64
   s = c_sin(h)
   q%x = s * ax(1)
   q%y = s * ax(2)
   q%z = s * ax(3)
   q%w = c_cos(h)
   endfunction quat_axis_angle

   pure function quat_from_el_az(elevation, azimuth) result(q)
   !< `FromElAz`: the rotation of an elevation and an azimuth [radians]: elevation * zero * azimuth, the zero a turn of
   !< -IM_PI/2 (a float quotient) about x.
   real(real64), intent(in) :: elevation !< Elevation [radians].
   real(real64), intent(in) :: azimuth   !< Azimuth [radians].
   type(plot3d_quat)        :: q         !< Rotation.
   type(plot3d_quat)        :: qa, qe, qz !< Azimuth's, elevation's, zero's.
   real(real64), parameter  :: EX(3) = [1.0_real64, 0.0_real64, 0.0_real64] !< x.
   real(real64), parameter  :: EZ(3) = [0.0_real64, 0.0_real64, 1.0_real64] !< z.

   qa = quat_axis_angle(azimuth, EZ)
   qe = quat_axis_angle(elevation, EX)
   qz = quat_axis_angle(real(-IM_PI_F / 2.0_real32, real64), EX)
   q = quat_mul(quat_mul(qe, qz), qa)
   endfunction quat_from_el_az

   pure function quat_mul(a, b) result(q)
   !< The product a b (`ImPlot3DQuat::operator*`).
   type(plot3d_quat), intent(in) :: a, b !< Factors.
   type(plot3d_quat)             :: q    !< Product.

   q%x = ((a%w * b%x + a%x * b%w) + a%y * b%z) - a%z * b%y
   q%y = ((a%w * b%y - a%x * b%z) + a%y * b%w) + a%z * b%x
   q%z = ((a%w * b%z + a%x * b%y) - a%y * b%x) + a%z * b%w
   q%w = ((a%w * b%w - a%x * b%x) - a%y * b%y) - a%z * b%z
   endfunction quat_mul

   pure function quat_inverse(a) result(q)
   !< `Inverse`: the conjugate over the squared length.
   type(plot3d_quat), intent(in) :: a  !< Rotation.
   type(plot3d_quat)             :: q  !< Inverse.
   real(real64)                  :: l2 !< Squared length.

   l2 = ((a%x * a%x + a%y * a%y) + a%z * a%z) + a%w * a%w
   q%x = -a%x / l2
   q%y = -a%y / l2
   q%z = -a%z / l2
   q%w = a%w / l2
   endfunction quat_inverse

   pure function quat_normalize(a) result(q)
   !< `Normalize`/`Normalized`: each component over the length.
   type(plot3d_quat), intent(in) :: a !< Rotation.
   type(plot3d_quat)             :: q !< Normalised.
   real(real64)                  :: l !< Length.

   l = sqrt(((a%x * a%x + a%y * a%y) + a%z * a%z) + a%w * a%w)
   q%x = a%x / l
   q%y = a%y / l
   q%z = a%z / l
   q%w = a%w / l
   endfunction quat_normalize

   pure function quat_dot(a, b) result(d)
   !< `Dot`.
   type(plot3d_quat), intent(in) :: a, b !< Rotations.
   real(real64)                  :: d    !< Dot product.

   d = ((a%x * b%x + a%y * b%y) + a%z * b%z) + a%w * b%w
   endfunction quat_dot

   pure subroutine quat_rotate(q, px, py, pz, rx, ry, rz)
   !< `q * point` on scalars (the per-point form): uv = qv x p, uuv = qv x uv, p + uv w 2 + uuv 2.
   type(plot3d_quat), intent(in)  :: q          !< Rotation.
   real(real64),      intent(in)  :: px, py, pz !< Point.
   real(real64),      intent(out) :: rx, ry, rz !< Rotated.
   real(real64)                   :: ux, uy, uz, vx, vy, vz !< uv, uuv.

   ux = q%y * pz - q%z * py
   uy = q%z * px - q%x * pz
   uz = q%x * py - q%y * px
   vx = q%y * uz - q%z * uy
   vy = q%z * ux - q%x * uz
   vz = q%x * uy - q%y * ux
   rx = (px + (ux * q%w) * 2.0_real64) + vx * 2.0_real64
   ry = (py + (uy * q%w) * 2.0_real64) + vy * 2.0_real64
   rz = (pz + (uz * q%w) * 2.0_real64) + vz * 2.0_real64
   endsubroutine quat_rotate

   pure function quat_rotate_v(q, p) result(r)
   !< `q * point` on VecFor's vectors (the per-frame form): the same operations.
   type(plot3d_quat), intent(in) :: q   !< Rotation.
   type(vector_R8P),  intent(in) :: p   !< Point.
   type(vector_R8P)              :: r   !< Rotated.
   type(vector_R8P)              :: qv, uv, uuv !< Vector part, the two cross products.

   qv%x = q%x
   qv%y = q%y
   qv%z = q%z
   uv = qv .cross. p
   uuv = qv .cross. uv
   r = (p + (uv * q%w) * 2.0_real64) + uuv * 2.0_real64
   endfunction quat_rotate_v

   function quat_from_two_vectors(v0, v1) result(q)
   !< `FromTwoVectors`: the rotation taking v0's direction to v1's (identity when they are within 1e-6 of each other,
   !< a half turn about an orthogonal axis when opposite).
   type(vector_R8P), intent(in) :: v0, v1 !< Vectors.
   type(plot3d_quat)            :: q      !< Rotation.
   type(vector_R8P)             :: ax     !< Axis.
   real(real64)                 :: d, l0, l1, nd, h, s !< Dot, lengths, normalised dot, half angle, its sine.

   d = v0 .dot. v1
   l0 = v0%normL2()
   l1 = v1%normL2()
   nd = d / (l0 * l1)
   if (abs(nd - 1.0_real64) < 1.0e-6_real64) then
      q = plot3d_quat(0.0_real64, 0.0_real64, 0.0_real64, 1.0_real64)
      return
   endif
   if (abs(nd + 1.0_real64) < 1.0e-6_real64) then
      if (abs(v0%x) > abs(v0%z)) then
         ax%x = -v0%y
         ax%y = v0%x
         ax%z = 0.0_real64
      else
         ax%x = 0.0_real64
         ax%y = -v0%z
         ax%z = v0%y
      endif
      call normalize(ax)
      q = plot3d_quat(ax%x, ax%y, ax%z, 0.0_real64)
      return
   endif
   ax = v0 .cross. v1
   call normalize(ax)
   h = c_acos(nd) * 0.5_real64
   s = c_sin(h)
   q%x = s * ax%x
   q%y = s * ax%y
   q%z = s * ax%z
   q%w = c_cos(h)
   endfunction quat_from_two_vectors

   pure function quat_slerp(q1, q2, t_in) result(q)
   !< `Slerp`: from q1 towards q2 by t in [0, 1], the shorter way; linear (then normalised) when within 0.9995.
   type(plot3d_quat), intent(in) :: q1, q2 !< Ends.
   real(real64),      intent(in) :: t_in   !< Fraction.
   type(plot3d_quat)             :: q      !< Interpolated.
   type(plot3d_quat)             :: b      !< q2, or its opposite.
   real(real64)                  :: t, d, th0, th, st, st0, s1, s2 !< Fraction, dot, angles, sines, weights.

   t = min(max(t_in, 0.0_real64), 1.0_real64)
   d = ((q1%x * q2%x + q1%y * q2%y) + q1%z * q2%z) + q1%w * q2%w
   b = q2
   if (d < 0.0_real64) then
      b = plot3d_quat(-q2%x, -q2%y, -q2%z, -q2%w)
      d = -d
   endif
   if (d > 0.9995_real64) then
      q%x = q1%x + t * (b%x - q1%x)
      q%y = q1%y + t * (b%y - q1%y)
      q%z = q1%z + t * (b%z - q1%z)
      q%w = q1%w + t * (b%w - q1%w)
      q = quat_normalize(q)
      return
   endif
   th0 = c_acos(d)
   th = th0 * t
   st = c_sin(th)
   st0 = c_sin(th0)
   s1 = c_cos(th) - d * st / st0
   s2 = st / st0
   q%x = s1 * q1%x + s2 * b%x
   q%y = s1 * q1%y + s2 * b%y
   q%z = s1 * q1%z + s2 * b%z
   q%w = s1 * q1%w + s2 * b%w
   endfunction quat_slerp

   ! the maps

   pure function view_scale(v) result(s)
   !< `GetViewScale`: min(width, height) / 1.8 times the style's factor, in float.
   type(view3d), intent(in) :: v !< View.
   real(real32)             :: s !< Pixels per NDC unit.

   s = min(v%rect(3) - v%rect(1), v%rect(4) - v%rect(2)) / 1.8_real32 * v%factor
   endfunction view_scale

   pure subroutine rect_center(v, cx, cy)
   !< `PlotRect.GetCenter()` (floats).
   type(view3d), intent(in)  :: v      !< View.
   real(real32), intent(out) :: cx, cy !< Centre [pixels].

   cx = (v%rect(1) + v%rect(3)) * 0.5_real32
   cy = (v%rect(2) + v%rect(4)) * 0.5_real32
   endsubroutine rect_center

   pure subroutine plot_to_ndc(v, p, n)
   !< `PlotToNDC`: each axis's value (transformed when log10 or symlog) as t in [0, 1] of its range, then
   !< (t - 0.5) (or 0.5 - t, inverted) times the axis's NDC scale.
   type(view3d), intent(in)  :: v    !< View.
   real(real64), intent(in)  :: p(3) !< Plot point.
   real(real64), intent(out) :: n(3) !< NDC point.
   real(real64)              :: t, s !< Fraction, scaled value.
   integer(int32)            :: i    !< Axis.

   do i = 1_int32, 3_int32
      select case (v%scale(i))
      case (SCALE3_LOG10)
         s = transform_log10(p(i))
         t = (s - v%smin(i)) / (v%smax(i) - v%smin(i))
      case (SCALE3_SYMLOG)
         s = transform_symlog(p(i))
         t = (s - v%smin(i)) / (v%smax(i) - v%smin(i))
      case default
         t = (p(i) - v%rmin(i)) / (v%rmax(i) - v%rmin(i))
      endselect
      if (v%invert(i)) then
         n(i) = (0.5_real64 - t) * v%ndc(i)
      else
         n(i) = (t - 0.5_real64) * v%ndc(i)
      endif
   enddo
   endsubroutine plot_to_ndc

   pure function axis_ndc_to_plot(v, i, t) result(p)
   !< `ImPlot3DAxis::NDCToPlot`: the value at fraction t of axis i's range (through the inverse transform).
   type(view3d),   intent(in) :: v !< View.
   integer(int32), intent(in) :: i !< Axis (1-3).
   real(real64),   intent(in) :: t !< Fraction.
   real(real64)               :: p !< Value.
   real(real64)               :: s !< Scaled value.

   select case (v%scale(i))
   case (SCALE3_LOG10)
      s = t * (v%smax(i) - v%smin(i)) + v%smin(i)
      p = inverse_log10(s)
   case (SCALE3_SYMLOG)
      s = t * (v%smax(i) - v%smin(i)) + v%smin(i)
      p = inverse_symlog(s)
   case default
      p = v%rmin(i) + t * (v%rmax(i) - v%rmin(i))
   endselect
   endfunction axis_ndc_to_plot

   pure subroutine ndc_to_plot(v, n, p)
   !< `NDCToPlot`: each axis's NDC value back to a fraction of its range, then to a value.
   type(view3d), intent(in)  :: v    !< View.
   real(real64), intent(in)  :: n(3) !< NDC point.
   real(real64), intent(out) :: p(3) !< Plot point.
   real(real64)              :: r, t !< Half the NDC scale, fraction.
   integer(int32)            :: i    !< Axis.

   do i = 1_int32, 3_int32
      r = 0.5_real64 * v%ndc(i)
      if (v%invert(i)) then
         t = r - n(i)
      else
         t = n(i) + r
      endif
      t = t / v%ndc(i)
      p(i) = axis_ndc_to_plot(v, i, t)
   enddo
   endsubroutine ndc_to_plot

   pure subroutine ndc_to_pixels(v, n, px, py)
   !< `NDCToPixels`: the NDC point rotated, times the view scale, y down, about the plot rectangle's centre.
   type(view3d), intent(in)  :: v      !< View.
   real(real64), intent(in)  :: n(3)   !< NDC point.
   real(real32), intent(out) :: px, py !< Pixel.
   real(real64)              :: rx, ry, rz, s !< Rotated point, view scale.
   real(real32)              :: cx, cy !< Centre.

   call quat_rotate(v%rot, n(1), n(2), n(3), rx, ry, rz)
   s = real(view_scale(v), real64)
   rx = s * rx
   ry = s * ry
   ry = ry * (-1.0_real64)
   call rect_center(v, cx, cy)
   rx = rx + real(cx, real64)
   ry = ry + real(cy, real64)
   px = real(rx, real32)
   py = real(ry, real32)
   endsubroutine ndc_to_pixels

   pure subroutine plot_to_pixels(v, p, px, py)
   !< `PlotToPixels`: `NDCToPixels(PlotToNDC(p))`.
   type(view3d), intent(in)  :: v      !< View.
   real(real64), intent(in)  :: p(3)   !< Plot point.
   real(real32), intent(out) :: px, py !< Pixel.
   real(real64)              :: n(3)   !< NDC point.

   call plot_to_ndc(v, p, n)
   call ndc_to_pixels(v, n, px, py)
   endsubroutine plot_to_pixels

   pure function point_depth(v, p) result(z)
   !< `GetPointDepth`: the plot point (its coordinates negated on inverted axes) rotated; its z.
   type(view3d), intent(in) :: v    !< View.
   real(real64), intent(in) :: p(3) !< Plot point.
   real(real64)             :: z    !< Depth.
   real(real64)             :: q(3), rx, ry !< The point, the rotated x and y.

   q = p
   if (v%invert(1)) q(1) = -q(1)
   if (v%invert(2)) q(2) = -q(2)
   if (v%invert(3)) q(3) = -q(3)
   call quat_rotate(v%rot, q(1), q(2), q(3), rx, ry, z)
   endfunction point_depth

   subroutine pixels_to_ndc_ray(v, px, py, o, d)
   !< `PixelsToNDCRay`: the pixel's offset from the centre over the view scale (floats), the points at NDC z = +10 and
   !< -10 turned back by the inverse rotation; the ray from the near one, its direction normalised.
   type(view3d),     intent(in)  :: v      !< View.
   real(real32),     intent(in)  :: px, py !< Pixel.
   type(vector_R8P), intent(out) :: o, d   !< Origin, direction.
   type(plot3d_quat)             :: qi     !< Inverse rotation.
   type(vector_R8P)              :: a, far !< A point, the far one.
   real(real32)                  :: zoom, cx, cy, x, y !< View scale, centre, offsets.

   zoom = view_scale(v)
   call rect_center(v, cx, cy)
   x = (px - cx) / zoom
   y = (-(py - cy)) / zoom
   qi = quat_inverse(v%rot)
   a%x = real(x, real64)
   a%y = real(y, real64)
   a%z = 10.0_real64
   o = quat_rotate_v(qi, a)
   a%z = -10.0_real64
   far = quat_rotate_v(qi, a)
   d = far - o
   call normalize(d)
   endsubroutine pixels_to_ndc_ray

   subroutine ndc_ray_to_plot_ray(v, o, d, po, pd)
   !< `NDCRayToPlotRay`: the origin and the point one unit along the ray in plot coordinates; their difference,
   !< normalised, the direction.
   type(view3d),     intent(in)  :: v      !< View.
   type(vector_R8P), intent(in)  :: o, d   !< NDC ray.
   type(vector_R8P), intent(out) :: po, pd !< Plot ray.
   type(vector_R8P)              :: a      !< The point along.
   real(real64)                  :: n(3), p(3) !< NDC and plot points.

   n(1) = o%x
   n(2) = o%y
   n(3) = o%z
   call ndc_to_plot(v, n, p)
   po%x = p(1)
   po%y = p(2)
   po%z = p(3)
   a = o + d
   n(1) = a%x
   n(2) = a%y
   n(3) = a%z
   call ndc_to_plot(v, n, p)
   pd%x = p(1) - po%x
   pd%y = p(2) - po%y
   pd%z = p(3) - po%z
   call normalize(pd)
   endsubroutine ndc_ray_to_plot_ray

   subroutine pixels_to_plot_plane(v, px, py, plane, mask, p, found)
   !< `PixelsToPlotPlane`: where the pixel's ray meets the box's face of the plane (0 YZ, 1 XZ, 2 XY) that is drawn
   !< (`active_faces`); with `mask`, only inside the box. `found` false where ImPlot3D returns NaNs (parallel, behind,
   !< outside); `p` then NaN.
   type(view3d),   intent(in)  :: v      !< View.
   real(real32),   intent(in)  :: px, py !< Pixel.
   integer(int32), intent(in)  :: plane  !< Plane (0-2).
   logical,        intent(in)  :: mask   !< Only inside the box.
   real(real64),   intent(out) :: p(3)   !< Plot point.
   logical,        intent(out) :: found  !< A point.
   type(vector_R8P)            :: o, d, q !< Ray, the meeting point.
   real(real64)                :: coord, denom, numer, t, b(3) !< The face's coordinate, the solve, half the box.
   logical                     :: af(3) !< Active faces.
   integer(int32)              :: p2    !< 2-D plane (unused).

   p = ieee_value(1.0_real64, ieee_quiet_nan)
   found = .false.
   call pixels_to_ndc_ray(v, px, py, o, d)
   call active_faces(v, af, p2)
   if (af(plane + 1_int32)) then
      coord = real(0.5_real32, real64) * v%ndc(plane + 1_int32)
   else
      coord = real(-0.5_real32, real64) * v%ndc(plane + 1_int32)
   endif
   select case (plane)
   case (0_int32)
      denom = d%x
      numer = coord - o%x
   case (1_int32)
      denom = d%y
      numer = coord - o%y
   case default
      denom = d%z
      numer = coord - o%z
   endselect
   if (abs(denom) < real(1.0e-12_real32, real64)) return
   t = numer / denom
   if (t < 0.0_real64) return
   q = o + d * t
   if (mask) then
      b = 0.5_real64 * v%ndc
      select case (plane)
      case (0_int32)
         if (.not. (0.0_real64 >= -b(1) .and. 0.0_real64 <= b(1) .and. q%y >= -b(2) .and. q%y <= b(2) .and. &
                    q%z >= -b(3) .and. q%z <= b(3))) return
      case (1_int32)
         if (.not. (q%x >= -b(1) .and. q%x <= b(1) .and. 0.0_real64 >= -b(2) .and. 0.0_real64 <= b(2) .and. &
                    q%z >= -b(3) .and. q%z <= b(3))) return
      case default
         if (.not. (q%x >= -b(1) .and. q%x <= b(1) .and. q%y >= -b(2) .and. q%y <= b(2) .and. &
                    0.0_real64 >= -b(3) .and. 0.0_real64 <= b(3))) return
      endselect
   endif
   b(1) = q%x
   b(2) = q%y
   b(3) = q%z
   call ndc_to_plot(v, b, p)
   found = .true.
   endsubroutine pixels_to_plot_plane

   ! the box

   pure subroutine active_faces(v, af, plane_2d)
   !< `ComputeActiveFaces`: per axis, the face drawn (true: the max face): the rotated axis seen edge on (|z| < 0.025)
   !< takes the min face for bottom/left, else the face whose normal points away; `plane_2d` the plane seen face on
   !< when exactly two are edge on (0-2), else -1.
   type(view3d),   intent(in)  :: v        !< View.
   logical,        intent(out) :: af(3)    !< Active faces.
   integer(int32), intent(out) :: plane_2d !< The 2-D plane, or -1.
   real(real64)                :: e(3), rx, ry, rz !< A unit axis, rotated.
   integer(int32)              :: i, ndeg  !< Axis, axes seen edge on.

   plane_2d = -1_int32
   ndeg = 0_int32
   do i = 1_int32, 3_int32
      e = 0.0_real64
      e(i) = 1.0_real64
      call quat_rotate(v%rot, e(1), e(2), e(3), rx, ry, rz)
      if (abs(rz) < 0.025_real64) then
         af(i) = rx + ry < 0.0_real64
         ndeg = ndeg + 1_int32
      else
         if (v%invert(i)) then
            af(i) = rz > 0.0_real64
         else
            af(i) = rz < 0.0_real64
         endif
         plane_2d = i - 1_int32
      endif
   enddo
   if (ndeg /= 2_int32) plane_2d = -1_int32
   endsubroutine active_faces

   pure subroutine box_corners(v, c)
   !< `ComputeBoxCorners`: the eight corners of the ranges' box (0: all minima, ... as ImPlot3D numbers them).
   type(view3d), intent(in)  :: v           !< View.
   real(real64), intent(out) :: c(3, 0:7)   !< Corners.
   integer(int32)            :: k           !< Corner.

   do k = 0_int32, 7_int32 ! x max at 1, 2, 5, 6; y max at 2, 3, 6, 7; z max at 4-7
      c(1, k) = v%rmin(1)
      if (k == 1_int32 .or. k == 2_int32 .or. k == 5_int32 .or. k == 6_int32) c(1, k) = v%rmax(1)
      c(2, k) = v%rmin(2)
      if (k == 2_int32 .or. k == 3_int32 .or. k == 6_int32 .or. k == 7_int32) c(2, k) = v%rmax(2)
      c(3, k) = v%rmin(3)
      if (k >= 4_int32) c(3, k) = v%rmax(3)
   enddo
   endsubroutine box_corners

   pure subroutine box_corners_pix(v, c, cp)
   !< `ComputeBoxCornersPix`: the corners' pixels.
   type(view3d), intent(in)  :: v          !< View.
   real(real64), intent(in)  :: c(3, 0:7)  !< Corners.
   real(real32), intent(out) :: cp(2, 0:7) !< Their pixels.
   integer(int32)            :: i          !< Corner.

   do i = 0_int32, 7_int32
      call plot_to_pixels(v, c(:, i), cp(1, i), cp(2, i))
   enddo
   endsubroutine box_corners_pix

   subroutine axes_parameters(v, af, cp, c, plane_2d, ac)
   !< `GetAxesParameters`: the active faces, the corners and their pixels, the 2-D plane, and for each axis the two
   !< corners of the edge it is drawn on (`axis_corners`; -1 for the axis normal to a 2-D view): from the lookup table
   !< in 3-D, from the 2-D face's common edges otherwise.
   type(view3d),   intent(in)  :: v          !< View.
   logical,        intent(out) :: af(3)      !< Active faces.
   real(real32),   intent(out) :: cp(2, 0:7) !< Corners' pixels.
   real(real64),   intent(out) :: c(3, 0:7)  !< Corners.
   integer(int32), intent(out) :: plane_2d   !< 2-D plane, or -1.
   integer(int32), intent(out) :: ac(0:1, 0:2) !< Axis corners.
   integer(int32)              :: face, ce(0:1), oc, xc, yc, xa, ya, ai, i, j, k, edge, fi, idx !< Work.
   real(real32)                :: xv(2), yv(2) !< 2-D edge vectors [pixels].
   type(vector_R8P)            :: o3, x3, y3   !< 3-D origin and directions.
   real(real64)                :: x3c(3), y3c(3) !< Their components.
   logical                     :: xinv, yinv   !< Directions inverted.

   call active_faces(v, af, plane_2d)
   call box_corners(v, c)
   call box_corners_pix(v, c, cp)
   if (plane_2d /= -1_int32) then
      face = plane_2d + 3_int32 * merge(1_int32, 0_int32, af(plane_2d + 1_int32))
      ce = -1_int32
      do i = 0_int32, 3_int32
         edge = FACE_EDGES(i, face)
         do j = 0_int32, 1_int32
            ai = mod(plane_2d + 1_int32 + j, 3_int32)
            fi = ai + merge(1_int32, 0_int32, af(ai + 1_int32)) * 3_int32
            do k = 0_int32, 3_int32
               if (FACE_EDGES(k, fi) == edge) then
                  ce(j) = edge
                  exit
               endif
            enddo
         enddo
      enddo
      oc = -1_int32
      xc = -1_int32
      yc = -1_int32
      do i = 0_int32, 1_int32
         do j = 0_int32, 1_int32
            if (EDGES(i, ce(0)) == EDGES(j, ce(1))) then
               oc = EDGES(i, ce(0))
               xc = EDGES(1_int32 - i, ce(0))
               yc = EDGES(1_int32 - j, ce(1))
            endif
         enddo
      enddo
      xv = cp(:, xc) - cp(:, oc)
      yv = cp(:, yc) - cp(:, oc)
      if (yv(1) > xv(1)) then
         idx = xc
         xc = yc
         yc = idx
      endif
      o3%x = c(1, oc)
      o3%y = c(2, oc)
      o3%z = c(3, oc)
      x3%x = c(1, xc)
      x3%y = c(2, xc)
      x3%z = c(3, xc)
      y3%x = c(1, yc)
      y3%y = c(2, yc)
      y3%z = c(3, yc)
      x3 = x3 - o3
      call normalize(x3)
      y3 = y3 - o3
      call normalize(y3)
      x3c(1) = x3%x
      x3c(2) = x3%y
      x3c(3) = x3%z
      y3c(1) = y3%x
      y3c(2) = y3%y
      y3c(3) = y3%z
      xa = -1_int32
      ya = -1_int32
      xinv = .false.
      yinv = .false.
      do i = 0_int32, 1_int32
         ai = mod(plane_2d + 1_int32 + i, 3_int32)
         if (ya /= -1_int32 .or. (abs(x3c(ai + 1_int32)) > real(1.0e-8_real32, real64) .and. xa == -1_int32)) then
            xa = ai
            xinv = x3c(ai + 1_int32) < 0.0_real64
         else
            ya = ai
            yinv = y3c(ai + 1_int32) < 0.0_real64
         endif
      enddo
      ac(:, plane_2d) = -1_int32
      if (xinv) then
         ac(0, xa) = xc
         ac(1, xa) = oc
      else
         ac(0, xa) = oc
         ac(1, xa) = xc
      endif
      if (yinv) then
         ac(0, ya) = yc
         ac(1, ya) = oc
      else
         ac(0, ya) = oc
         ac(1, ya) = yc
      endif
   else
      idx = 4_int32 * merge(1_int32, 0_int32, af(1)) + 2_int32 * merge(1_int32, 0_int32, af(2)) + &
            merge(1_int32, 0_int32, af(3))
      ac = AXIS_CORNERS_3D(:, :, idx)
   endif
   endsubroutine axes_parameters

   ! hover geometry

   pure function triangle_contains(ax, ay, bx, by, cx, cy, px, py) result(yes)
   !< `ImTriangleContainsPoint`: the point on the same side of the three edges.
   real(real32), intent(in) :: ax, ay, bx, by, cx, cy, px, py !< Triangle, point.
   logical                  :: yes !< Inside.
   logical                  :: b1, b2, b3 !< Sides.

   b1 = ((px - bx) * (ay - by) - (py - by) * (ax - bx)) < 0.0_real32
   b2 = ((px - cx) * (by - cy) - (py - cy) * (bx - cx)) < 0.0_real32
   b3 = ((px - ax) * (cy - ay) - (py - ay) * (cx - ax)) < 0.0_real32
   yes = (b1 .eqv. b2) .and. (b2 .eqv. b3)
   endfunction triangle_contains

   pure function mouse_over_plane(af, cp, mx, my) result(plane)
   !< `GetMouseOverPlane`: the active face (0 YZ, 1 XZ, 2 XY) under the pointer (valid), or -1.
   logical,      intent(in) :: af(3)      !< Active faces.
   real(real32), intent(in) :: cp(2, 0:7) !< Corners' pixels.
   real(real32), intent(in) :: mx, my     !< Pointer.
   integer(int32)           :: plane      !< Plane, or -1.
   integer(int32)           :: a, f       !< Axis, face.
   real(real32)             :: p(2, 0:3)  !< The face's corners.

   plane = -1_int32
   do a = 0_int32, 2_int32
      f = a + 3_int32 * merge(1_int32, 0_int32, af(a + 1_int32))
      p(:, 0) = cp(:, FACES(0, f))
      p(:, 1) = cp(:, FACES(1, f))
      p(:, 2) = cp(:, FACES(2, f))
      p(:, 3) = cp(:, FACES(3, f))
      if (triangle_contains(p(1, 0), p(2, 0), p(1, 1), p(2, 1), p(1, 2), p(2, 2), mx, my) .or. &
          triangle_contains(p(1, 2), p(2, 2), p(1, 3), p(2, 3), p(1, 0), p(2, 0), mx, my)) then
         plane = a
         return
      endif
   enddo
   endfunction mouse_over_plane

   pure subroutine edge_outward_dir(p0, p1, center, o)
   !< `ComputeEdgeOutwardDir`: the edge's unit normal pointing away from the centre ((0, 0) for an edge shorter than
   !< 0.001 pixels).
   real(real32), intent(in)  :: p0(2), p1(2), center(2) !< Edge, box centre [pixels].
   real(real32), intent(out) :: o(2)                    !< Outward direction.
   real(real32)              :: d(2), l, ec(2), te(2)   !< Direction, length, edge centre, to the edge.

   d = p1 - p0
   l = sqrt(d(1) * d(1) + d(2) * d(2))
   o = 0.0_real32
   if (l < 0.001_real32) return
   d = d / l
   o(1) = -d(2)
   o(2) = d(1)
   ec = (p0 + p1) * 0.5_real32
   te = ec - center
   if (o(1) * te(1) + o(2) * te(2) < 0.0_real32) o = -o
   endsubroutine edge_outward_dir

   pure function in_edge_region(pt, p0, p1, outward, width) result(yes)
   !< `IsPointInEdgeHoverRegion`: the point within the rectangle that extends `width` pixels outward from the edge.
   real(real32), intent(in) :: pt(2), p0(2), p1(2), outward(2), width !< Point, edge, outward direction, width.
   logical                  :: yes !< Inside.
   real(real32)             :: d(2), l, lc(2), along, across !< Direction, length, local point, its coordinates.

   yes = .false.
   d = p1 - p0
   l = sqrt(d(1) * d(1) + d(2) * d(2))
   if (l < 0.001_real32) return
   d = d / l
   lc = pt - p0
   along = lc(1) * d(1) + lc(2) * d(2)
   across = lc(1) * outward(1) + lc(2) * outward(2)
   yes = along >= 0.0_real32 .and. along <= l .and. across >= 0.0_real32 .and. across <= width
   endfunction in_edge_region

   ! private

   pure subroutine normalize(a)
   !< `ImPlot3DPoint::Normalize`: each component over the length (VecFor's `normalize` adds `tiny` to a null length:
   !< ImPlot3D divides by it; the frame never normalises a null vector).
   type(vector_R8P), intent(inout) :: a !< Vector.
   real(real64)                    :: l !< Length.

   l = sqrt(a%sq_norm())
   a%x = a%x / l
   a%y = a%y / l
   a%z = a%z / l
   endsubroutine normalize
endmodule figure_plot3d_camera
