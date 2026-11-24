!< figure_gizmo, ImGuizmo's gizmos (`Manipulate`) and view cube (`ViewManipulate`) on figure_core, with FIGURE's glue.
module figure_gizmo
!< figure_gizmo, ImGuizmo's gizmos (`Manipulate`) and view cube (`ViewManipulate`) on figure_core, with FIGURE's glue.
!<
!< szaghi/figure#15 P14. The subset of third_party/ImGuizmo/ImGuizmo.cpp FIGURE uses (`Manipulate` for TRANSLATE,
!< ROTATE and SCALE in WORLD or LOCAL space, with or without snap; `ViewManipulate`; the ID stack; FIGURE's patches
!< 0001, `BeginFrameState`, and 0002, the view cube's last frame landing on its target), in Fortran, its context a set
!< of module variables (ImGuizmo's `gContext`), its arithmetic figure_gizmo_math's (ImGuizmo's, in `real32`), drawn
!< through figure_core into the current window's list. Then the glue of `native/figure_view3d.cpp` (`fig_view3d_cube`,
!< `fig_view3d_gizmo`): `gz_view_cube` and `gz_view_gizmo`, the same arguments, statuses and messages, the view's
!< state read and written through the native view (`fig_view3d_widget`, `fig_view3d_matrices`, `fig_view3d_camera`,
!< `fig_view3d_overlay`).
!<
!< What ImGuizmo does that FIGURE does not ask is left out: orthographic cameras, the axis mask (always none), bounds,
!< the universal scale, `DrawGrid`, `DrawCubes`. ImGuizmo's defects are kept (a gizmo behind the camera returns
!< without popping its clip rectangle; one `overBox` shared by every view cube), so both draw the same. No heap
!< allocation per frame: the per-cube states grow only when a new cube appears.
use, intrinsic :: iso_c_binding, only : c_double, c_int
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64
use, intrinsic :: ieee_arithmetic, only : ieee_is_finite
use figure_c_native, only : fig_set_last_error, FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK
use figure_cimgui_enums, only : ImGuiHoveredFlags_ChildWindows
use figure_core, only : core_active_id, core_any_item_active, core_any_item_hovered, core_clear_active_id, core_color, &
                        core_draw_begin, core_draw_circle, core_draw_convex_poly_filled, core_draw_end,              &
                        core_draw_line, core_draw_polyline, core_draw_rect_filled, core_draw_text,                   &
                        core_draw_triangle_filled, core_frame_count, core_get_id, core_io_input, core_keep_alive,    &
                        core_mouse_clicked, core_mouse_down, core_mouse_hovering_rect, core_mouse_pos,               &
                        core_mouse_pos_valid, core_pop_clip_rect, core_push_clip_rect, core_set_active_id,           &
                        core_want_capture_mouse, core_window_hover_state, core_window_hovered
use figure_gizmo_math, only : DEG2RAD, FLT_EPSILON, FLT_MAX, RAD2DEG, ZPI, build_plan, c_acosf, c_atan2f, c_cosf,    &
                              c_fmodf, c_sinf, look_at, mat_identity, mat_inverse, mat_mul, mat_ortho_normalize,    &
                              mat_rotation_axis, mat_scale, mat_translation, perspective, vec, vec_cross, vec_dot,  &
                              vec_dot3, vec_length, vec_length_sq, vec_lerp, vec_normalize, vec_normalized,         &
                              vec_transform, vec_transform_point, vec_transform_vector
use figure_plot_format, only : fmt_int, fmt_parse, fmt_real, fmt_text, plot_format
use figure_plot_hash, only : plot_hash_int

implicit none
private
public :: gz_view_cube, gz_view_gizmo
public :: GZ_TRANSLATE, GZ_ROTATE, GZ_SCALE, GZ_LOCAL, GZ_WORLD

! ImGuizmo's OPERATION bits
integer(int32), parameter :: TRANSLATE_X = 1_int32, TRANSLATE_Y = 2_int32, TRANSLATE_Z = 4_int32  !< Translations.
integer(int32), parameter :: ROTATE_X = 8_int32, ROTATE_Y = 16_int32, ROTATE_Z = 32_int32        !< Rotations.
integer(int32), parameter :: ROTATE_SCREEN = 64_int32                                             !< ... the screen's.
integer(int32), parameter :: SCALE_X = 128_int32, SCALE_Y = 256_int32, SCALE_Z = 512_int32        !< Scales.
integer(int32), parameter :: GZ_TRANSLATE = 7_int32    !< TRANSLATE.
integer(int32), parameter :: GZ_ROTATE = 120_int32     !< ROTATE (with ROTATE_SCREEN).
integer(int32), parameter :: GZ_SCALE = 896_int32      !< SCALE.
integer(int32), parameter :: TRANSLATE_PLANS(0:2) = [TRANSLATE_Y + TRANSLATE_Z, TRANSLATE_X + TRANSLATE_Z, &
                                                      TRANSLATE_X + TRANSLATE_Y] !< MT_MOVE_YZ, ZX, XY's.
! MODE
integer(int32), parameter :: GZ_LOCAL = 0_int32 !< LOCAL.
integer(int32), parameter :: GZ_WORLD = 1_int32 !< WORLD.
! MOVETYPE
integer(int32), parameter :: MT_NONE = 0_int32, MT_MOVE_X = 1_int32, MT_MOVE_Y = 2_int32, MT_MOVE_Z = 3_int32
integer(int32), parameter :: MT_MOVE_YZ = 4_int32, MT_MOVE_ZX = 5_int32, MT_MOVE_XY = 6_int32, MT_MOVE_SCREEN = 7_int32
integer(int32), parameter :: MT_ROTATE_X = 8_int32, MT_ROTATE_Y = 9_int32, MT_ROTATE_Z = 10_int32
integer(int32), parameter :: MT_ROTATE_SCREEN = 11_int32
integer(int32), parameter :: MT_SCALE_X = 12_int32, MT_SCALE_Y = 13_int32, MT_SCALE_Z = 14_int32
integer(int32), parameter :: MT_SCALE_XYZ = 15_int32
! COLOR
integer(int32), parameter :: DIRECTION_X = 0_int32, DIRECTION_Y = 1_int32, DIRECTION_Z = 2_int32 !< Axes.
integer(int32), parameter :: PLANE_X = 3_int32, SELECTION = 6_int32, INACTIVE = 7_int32          !< ...
integer(int32), parameter :: TRANSLATION_LINE = 8_int32, SCALE_LINE = 9_int32                    !< ...
integer(int32), parameter :: ROTATION_USING_BORDER = 10_int32, ROTATION_USING_FILL = 11_int32    !< ...
integer(int32), parameter :: HATCHED_AXIS_LINES = 12_int32, TEXT = 13_int32, TEXT_SHADOW = 14_int32 !< ...
! constants
real(real32),   parameter :: SCREEN_ROTATE_SIZE = 0.06_real32       !< screenRotateSize.
real(real32),   parameter :: ROTATION_DISPLAY_FACTOR = 1.2_real32   !< rotationDisplayFactor.
integer(int32), parameter :: HALF_CIRCLE = 64_int32                 !< halfCircleSegmentCount.
real(real32),   parameter :: SNAP_TENSION = 0.5_real32              !< snapTension.
real(real32),   parameter :: QUAD_UV(0:7) = [0.5_real32, 0.5_real32, 0.5_real32, 0.8_real32, 0.8_real32, 0.8_real32, &
                                             0.8_real32, 0.5_real32] !< quadUV.
integer(int32), parameter :: INFO_INDEX(0:20) = [0, 0, 0, 1, 0, 0, 2, 0, 0, 1, 2, 0, 0, 2, 0, 0, 1, 0, 0, 1, 2] !<
                                                                    !< translationInfoIndex.
real(real32),   parameter :: UNARY(4, 0:2) = reshape([1.0_real32, 0.0_real32, 0.0_real32, 0.0_real32, &
                                                      0.0_real32, 1.0_real32, 0.0_real32, 0.0_real32, &
                                                      0.0_real32, 0.0_real32, 1.0_real32, 0.0_real32], [4, 3]) !<
                                                                    !< directionUnary.
real(real32),   parameter :: PANEL_POSITION(2, 0:8) = reshape([0.75_real32, 0.75_real32, 0.25_real32, 0.75_real32, &
                                                               0.0_real32, 0.75_real32, 0.75_real32, 0.25_real32,  &
                                                               0.25_real32, 0.25_real32, 0.0_real32, 0.25_real32,  &
                                                               0.75_real32, 0.0_real32, 0.25_real32, 0.0_real32,   &
                                                               0.0_real32, 0.0_real32], [2, 9]) !< panelPosition.
real(real32),   parameter :: PANEL_SIZE(2, 0:8) = reshape([0.25_real32, 0.25_real32, 0.5_real32, 0.25_real32,   &
                                                           0.25_real32, 0.25_real32, 0.25_real32, 0.5_real32,   &
                                                           0.5_real32, 0.5_real32, 0.25_real32, 0.5_real32,     &
                                                           0.25_real32, 0.25_real32, 0.5_real32, 0.25_real32,   &
                                                           0.25_real32, 0.25_real32], [2, 9]) !< panelSize.

type :: tripod_t
   !< TripodState.
   logical      :: below_axis(0:2) = .false.  !< mBelowAxisLimit.
   logical      :: below_plane(0:2) = .false. !< mBelowPlaneLimit.
   real(real32) :: axis_factor(0:2) = 1.0_real32 !< mAxisFactor.
endtype tripod_t

type :: cube_state_t
   !< ViewManipulateState.
   integer(int32) :: id = -1_int32                  !< mID.
   logical        :: dragging = .false.             !< mIsDragging.
   logical        :: clicking = .false.             !< mIsClicking.
   integer(int32) :: frames = 0_int32               !< mInterpolationFrames.
   real(real32)   :: up(4) = 0.0_real32             !< mInterpolationUp.
   real(real32)   :: dir(4) = 0.0_real32            !< mInterpolationDir.
endtype cube_state_t

! ImGuizmo's Style
real(real32) :: st_translation_line_thickness = 3.0_real32   !< TranslationLineThickness.
real(real32) :: st_translation_line_arrow_size = 6.0_real32  !< TranslationLineArrowSize.
real(real32) :: st_rotation_line_thickness = 2.0_real32      !< RotationLineThickness.
real(real32) :: st_rotation_outer_line_thickness = 3.0_real32 !< RotationOuterLineThickness.
real(real32) :: st_scale_line_thickness = 3.0_real32         !< ScaleLineThickness.
real(real32) :: st_scale_line_circle_size = 6.0_real32       !< ScaleLineCircleSize.
real(real32) :: st_hatched_axis_line_thickness = 6.0_real32  !< HatchedAxisLineThickness.
real(real32) :: st_center_circle_size = 6.0_real32           !< CenterCircleSize.
real(real32) :: st_colors(4, 0:14) = reshape([ &
   0.666_real32, 0.000_real32, 0.000_real32, 1.000_real32, 0.000_real32, 0.666_real32, 0.000_real32, 1.000_real32, &
   0.000_real32, 0.000_real32, 0.666_real32, 1.000_real32, 0.666_real32, 0.000_real32, 0.000_real32, 0.380_real32, &
   0.000_real32, 0.666_real32, 0.000_real32, 0.380_real32, 0.000_real32, 0.000_real32, 0.666_real32, 0.380_real32, &
   1.000_real32, 0.500_real32, 0.062_real32, 0.541_real32, 0.600_real32, 0.600_real32, 0.600_real32, 0.600_real32, &
   0.666_real32, 0.666_real32, 0.666_real32, 0.666_real32, 0.250_real32, 0.250_real32, 0.250_real32, 1.000_real32, &
   1.000_real32, 0.500_real32, 0.062_real32, 1.000_real32, 1.000_real32, 0.500_real32, 0.062_real32, 0.500_real32, &
   0.000_real32, 0.000_real32, 0.000_real32, 0.500_real32, 1.000_real32, 1.000_real32, 1.000_real32, 1.000_real32, &
   0.000_real32, 0.000_real32, 0.000_real32, 1.000_real32], [4, 15]) !< Colors.

! ImGuizmo's Context (gContext)
integer(int32) :: g_mode = 0_int32                          !< mMode.
real(real32)   :: view_mat(4,4) = 0.0_real32                !< mViewMat.
real(real32)   :: proj_mat(4,4) = 0.0_real32                !< mProjectionMat.
real(real32)   :: model(4,4) = 0.0_real32                   !< mModel.
real(real32)   :: model_local(4,4) = 0.0_real32             !< mModelLocal.
real(real32)   :: model_inverse(4,4) = 0.0_real32           !< mModelInverse.
real(real32)   :: model_source(4,4) = 0.0_real32            !< mModelSource.
real(real32)   :: model_source_inverse(4,4) = 0.0_real32    !< mModelSourceInverse.
real(real32)   :: mvp(4,4) = 0.0_real32                     !< mMVP.
real(real32)   :: mvp_local(4,4) = 0.0_real32               !< mMVPLocal.
real(real32)   :: view_projection(4,4) = 0.0_real32         !< mViewProjection.
real(real32)   :: model_scale_origin(4) = 0.0_real32        !< mModelScaleOrigin.
real(real32)   :: camera_eye(4) = 0.0_real32                !< mCameraEye.
real(real32)   :: camera_right(4) = 0.0_real32              !< mCameraRight.
real(real32)   :: camera_dir(4) = 0.0_real32                !< mCameraDir.
real(real32)   :: camera_up(4) = 0.0_real32                 !< mCameraUp.
real(real32)   :: ray_origin(4) = 0.0_real32                !< mRayOrigin.
real(real32)   :: ray_vector(4) = 0.0_real32                !< mRayVector.
real(real32)   :: radius_square_center = 0.0_real32         !< mRadiusSquareCenter.
real(real32)   :: square_center(2) = 0.0_real32             !< mScreenSquareCenter.
real(real32)   :: square_min(2) = 0.0_real32                !< mScreenSquareMin.
real(real32)   :: square_max(2) = 0.0_real32                !< mScreenSquareMax.
real(real32)   :: screen_factor = 0.0_real32                !< mScreenFactor.
real(real32)   :: relative_origin(4) = 0.0_real32           !< mRelativeOrigin.
logical        :: using = .false.                           !< mbUsing.
logical        :: using_view_manipulate = .false.           !< mbUsingViewManipulate.
logical        :: enabled = .true.                          !< mbEnable.
logical        :: mouse_over = .false.                      !< mbMouseOver.
logical        :: view_manipulator_hovered = .false.        !< mIsViewManipulatorHovered.
real(real32)   :: translation_plan(4) = 0.0_real32          !< mTranslationPlan.
real(real32)   :: translation_plan_origin(4) = 0.0_real32   !< mTranslationPlanOrigin.
real(real32)   :: matrix_origin(4) = 0.0_real32             !< mMatrixOrigin.
real(real32)   :: translation_last_delta(4) = 0.0_real32    !< mTranslationLastDelta.
real(real32)   :: rotation_vector_source(4) = 0.0_real32    !< mRotationVectorSource.
real(real32)   :: rotation_angle = 0.0_real32               !< mRotationAngle.
real(real32)   :: rotation_angle_origin = 0.0_real32        !< mRotationAngleOrigin.
real(real32)   :: scale(4) = 0.0_real32                     !< mScale.
real(real32)   :: scale_value_origin(4) = 0.0_real32        !< mScaleValueOrigin.
real(real32)   :: scale_last(4) = 0.0_real32                !< mScaleLast.
real(real32)   :: save_mouse_posx = 0.0_real32              !< mSaveMousePosx.
integer(int32) :: axis_mask = 0_int32                       !< mAxisMask (FIGURE sets none).
type(tripod_t) :: tripod_state                              !< mTripodState.
type(tripod_t) :: active_tripod_state                       !< mActiveTripodState.
real(real32)   :: axis_limit = 0.0025_real32                !< mAxisLimit.
real(real32)   :: plane_limit = 0.02_real32                 !< mPlaneLimit.
integer(int32) :: current_handle_type = MT_NONE             !< mCurrentHandleType.
integer(int32) :: hovered_handle_type = MT_NONE             !< mHoveredHandleType.
real(real32)   :: rx = 0.0_real32, ry = 0.0_real32          !< mX, mY.
real(real32)   :: rwidth = 0.0_real32, rheight = 0.0_real32 !< mWidth, mHeight.
real(real32)   :: rxmax = 0.0_real32, rymax = 0.0_real32    !< mXMax, mYMax.
real(real32)   :: display_ratio = 1.0_real32                !< mDisplayRatio.
logical        :: over_hotspot = .false.                    !< mbOverGizmoHotspot.
logical        :: over_hotspot_last_frame = .false.         !< mbOverGizmoHotspotLastFrame.
integer(int32) :: id_stack(64) = 0_int32                    !< mIDStack.
integer(int32) :: id_depth = 0_int32                        !< ... its size.
integer(int32) :: editing_id = -1_int32                     !< mEditingID.
integer(int32) :: g_operation = 0_int32                     !< mOperation.
type(cube_state_t), allocatable :: cube_states(:)           !< mViewManipulateStates.
integer(int32) :: n_cube_states = 0_int32                   !< ... in use.
logical        :: allow_axis_flip = .true.                  !< mAllowAxisFlip.
real(real32)   :: gizmo_size_clip_space = 0.1_real32        !< mGizmoSizeClipSpace.
integer(int32) :: over_box = -1_int32                       !< ViewManipulate's static overBox.
! FIGURE's glue
real(real32)   :: mouse(2) = 0.0_real32                     !< io.MousePos while ImGuizmo runs (`mouse_guard`).
integer(int32) :: last_frame = -1_int32                     !< The frame of the last `BeginFrameState`.

interface
   function fig_view3d_widget(handle, drawn, rect) result(status) bind(C, name='fig_view3d_widget')
   !< The view's widget as drawn last: drawn 1 in this frame and the current window; rect its pixel x, y, width,
   !< height.
   import :: c_double, c_int
   implicit none
   integer(c_int), value :: handle  !< View.
   integer(c_int)        :: drawn   !< Drawn in this frame and window.
   real(c_double)        :: rect(4) !< Its rectangle.
   integer(c_int)        :: status  !< Status.
   endfunction fig_view3d_widget

   function fig_view3d_overlay(handle, what, cube) result(status) bind(C, name='fig_view3d_overlay')
   !< What the gizmos tell the view (bits of what): 1 the cube's rectangle (relative to the image), 2 an overlay over
   !< the view on this frame, 4 the cube turned the camera.
   import :: c_double, c_int
   implicit none
   integer(c_int), value :: handle  !< View.
   integer(c_int), value :: what    !< Bits.
   real(c_double)        :: cube(4) !< The cube's min x, y, max x, y.
   integer(c_int)        :: status  !< Status.
   endfunction fig_view3d_overlay

   function fig_view3d_matrices(handle, view, projection) result(status) bind(C, name='fig_view3d_matrices')
   !< The camera's view and projection matrices.
   import :: c_double, c_int
   implicit none
   integer(c_int), value :: handle         !< View.
   real(c_double)        :: view(16)       !< View matrix.
   real(c_double)        :: projection(16) !< Projection matrix.
   integer(c_int)        :: status         !< Status.
   endfunction fig_view3d_matrices

   function fig_view3d_camera(handle, set, mask, target, distance, azimuth, elevation, fov) result(status) &
      bind(C, name='fig_view3d_camera')
   !< The camera, set or read.
   import :: c_double, c_int
   implicit none
   integer(c_int), value :: handle    !< View.
   integer(c_int), value :: set       !< 1 set, 0 read.
   integer(c_int), value :: mask      !< Parts set.
   real(c_double)        :: target(3) !< Target.
   real(c_double)        :: distance  !< Distance.
   real(c_double)        :: azimuth   !< Azimuth [degrees].
   real(c_double)        :: elevation !< Elevation [degrees].
   real(c_double)        :: fov       !< Field of view [degrees].
   integer(c_int)        :: status    !< Status.
   endfunction fig_view3d_camera

   pure function c_atan2(y, x) result(r) bind(C, name='atan2')
   !< libm's atan2.
   import :: c_double
   implicit none
   real(c_double), value :: y, x !< Arguments.
   real(c_double)        :: r    !< Result.
   endfunction c_atan2

   pure function c_asin(x) result(r) bind(C, name='asin')
   !< libm's asin.
   import :: c_double
   implicit none
   real(c_double), value :: x !< Argument.
   real(c_double)        :: r !< Result.
   endfunction c_asin

   pure function c_remainder(x, y) result(r) bind(C, name='remainder')
   !< libm's remainder.
   import :: c_double
   implicit none
   real(c_double), value :: x, y !< Arguments.
   real(c_double)        :: r    !< Result.
   endfunction c_remainder
endinterface

contains
   ! FIGURE's glue (native/figure_view3d.cpp)

   function gz_view_cube(handle, size, corner, changed) result(status)
   !< `fig_view3d_cube`: a view cube (`ViewManipulate`) in a corner of the view drawn in this frame and window.
   integer(c_int), intent(in)  :: handle  !< View.
   real(c_double), intent(in)  :: size    !< Side [pixels].
   integer(c_int), intent(in)  :: corner  !< 0 top-right, 1 top-left, 2 bottom-right, 3 bottom-left.
   integer(c_int), intent(out) :: changed !< 1 when it turned the camera.
   integer(c_int)              :: status  !< Status.
   real(c_double)              :: rect(4) !< The view's image.
   integer(c_int)              :: drawn   !< Drawn in this frame and window.
   real(real32)                :: s, relx, rely, px, py !< The cube's side, its corner relative and absolute.
   real(real32)                :: fv(4,4), fp(4,4), cv(4,4), before(4,4), ident(4,4), swap(4) !< Matrices, a colour.
   real(c_double)              :: o(3), dist, az, el, u(3), b(3), tg(3), fov !< Target, distance, the camera turned.
   real(c_double)              :: cube(4) !< The cube's rectangle.
   integer(int32)              :: id      !< The cube's ID.
   logical                     :: using_before, using_it, inside !< ImGuizmo's use, the pointer on the cube.
   real(real64)                :: mx, my  !< The pointer.
   character(len=40)           :: label   !< The cube's ID's label.
   integer(int32)              :: nl      !< Its length.
   integer(c_int)              :: what    !< Overlay bits.

   changed = 0_c_int
   status = fig_view3d_widget(handle, drawn, rect)
   if (status /= FIG_OK) return
   if (drawn == 0_c_int) then
      status = fail(FIG_ERR_STATE, 'view3d_object%view_cube: draw the view first, in this frame and in this window')
      return
   endif
   if (.not. size > 0.0_c_double) then
      status = fail(FIG_ERR_ARGUMENT, 'view3d_object%view_cube: the size must be positive')
      return
   endif
   if (corner < 0_c_int .or. corner > 3_c_int) then
      status = fail(FIG_ERR_ARGUMENT, 'view3d_object%view_cube: unknown corner')
      return
   endif
   s = real(min(size, rect(3), rect(4)), real32)
   if (corner == 1_c_int .or. corner == 3_c_int) then
      relx = 0.0_real32
   else
      relx = real(rect(3), real32) - s
   endif
   if (corner == 2_c_int .or. corner == 3_c_int) then
      rely = real(rect(4), real32) - s
   else
      rely = 0.0_real32
   endif
   px = real(rect(1), real32) + relx
   py = real(rect(2), real32) + rely
   call gizmo_frame()
   call core_draw_begin()
   call set_rect(real(rect(1), real32), real(rect(2), real32), real(rect(3), real32), real(rect(4), real32))
   status = gizmo_matrices(handle, fv, fp, o, dist)
   if (status /= FIG_OK) return
   ! the camera into the cube's y-up world: V' = V C^-1, C^-1 (x', y', z') = (x', -z', y'): columns 1 and 2 of the
   ! rotation become column 2 and -column 1
   cv = fv
   cv(1:3, 2) = fv(1:3, 3)
   cv(1:3, 3) = -fv(1:3, 2)
   before = cv
   ident = mat_identity()
   swap = st_colors(:, DIRECTION_Y) ! y' is FIGURE's z
   st_colors(:, DIRECTION_Y) = st_colors(:, DIRECTION_Z)
   st_colors(:, DIRECTION_Z) = swap
   nl = 0_int32
   call fmt_text(label, nl, '##figure-view-cube-')
   call fmt_int(label, nl, int(handle, int32))
   id = core_get_id(label(1:nl))
   call push_id(id)
   using_before = using_view_manipulate
   call guard_mouse()
   call view_manipulate(cv, fp, GZ_TRANSLATE, GZ_WORLD, ident, real(dist, real32), px, py, s, s, 0_int32)
   using_it = using_view_manipulate .and. .not. using_before
   call pop_id()
   swap = st_colors(:, DIRECTION_Y)
   st_colors(:, DIRECTION_Y) = st_colors(:, DIRECTION_Z)
   st_colors(:, DIRECTION_Z) = swap
   call core_mouse_pos(mx, my)
   inside = mx >= real(px, real64) .and. mx < real(px + s, real64) .and. my >= real(py, real64) .and. &
            my < real(py + s, real64)
   if (inside) inside = core_window_hovered(int(ImGuiHoveredFlags_ChildWindows, int32))
   if (inside) inside = core_mouse_clicked(0_int32)
   call hold_active(id, using_it .or. inside)
   call core_draw_end()
   cube = [real(relx, c_double), real(rely, c_double), real(relx + s, c_double), real(rely + s, c_double)]
   what = 1_c_int
   if (using_it) what = what + 2_c_int
   if (any(bits(cv) /= bits(before))) then ! back to FIGURE's world: rows 1 (up) and 2 (back), by C^-1
      u = [real(cv(2, 1), c_double), -real(cv(2, 3), c_double), real(cv(2, 2), c_double)]
      b = [real(cv(3, 1), c_double), -real(cv(3, 3), c_double), real(cv(3, 2), c_double)]
      call orientation(b, u, az, el)
      az = c_remainder(az, 360.0_c_double)
      el = min(max(el, -90.0_c_double), 90.0_c_double)
      tg = 0.0_c_double
      fov = 0.0_c_double
      status = fig_view3d_camera(handle, 1_c_int, 12_c_int, tg, dist, az, el, fov)
      if (status /= FIG_OK) return
      what = what + 4_c_int
      changed = 1_c_int
   endif
   status = fig_view3d_overlay(handle, what, cube)
   endfunction gz_view_cube

   function gz_view_gizmo(handle, id, matrix, mode, space, has_snap, snap, changed) result(status)
   !< `fig_view3d_gizmo`: a gizmo (`Manipulate`) moving `matrix` (column-major 4 x 4), over the view drawn in this frame
   !< and window: mode 0 translate, 1 rotate, 2 scale; space 0 world, 1 local; snap (has_snap 1).
   integer(c_int),   intent(in)    :: handle      !< View.
   character(len=*), intent(in)    :: id          !< Gizmo ID.
   real(c_double),   intent(inout) :: matrix(16)  !< The matrix moved.
   integer(c_int),   intent(in)    :: mode        !< Mode.
   integer(c_int),   intent(in)    :: space       !< Space.
   integer(c_int),   intent(in)    :: has_snap    !< Snap given.
   real(c_double),   intent(in)    :: snap        !< Snap.
   integer(c_int),   intent(out)   :: changed     !< 1 when moved.
   integer(c_int)                  :: status      !< Status.
   integer(int32),   parameter     :: OPS(0:2) = [GZ_TRANSLATE, GZ_ROTATE, GZ_SCALE] !< Operations.
   real(c_double)                  :: rect(4), o(3), dist, cube(4) !< The image, the target, the distance, unused.
   integer(c_int)                  :: drawn       !< Drawn in this frame and window.
   real(real32)                    :: w, h, px    !< The view's size, the gizmo's.
   real(real32)                    :: fv(4,4), fp(4,4), fm(4,4), s3(3) !< Matrices, snap.
   integer(int32)                  :: gid, k      !< The gizmo's ID, counter.
   logical                         :: moved, using_it, over !< ImGuizmo's results.

   changed = 0_c_int
   status = fig_view3d_widget(handle, drawn, rect)
   if (status /= FIG_OK) return
   if (drawn == 0_c_int) then
      status = fail(FIG_ERR_STATE, 'view3d_object%gizmo: draw the view first, in this frame and in this window')
      return
   endif
   if (mode < 0_c_int .or. mode > 2_c_int) then
      status = fail(FIG_ERR_ARGUMENT, 'view3d_object%gizmo: unknown mode')
      return
   endif
   if (has_snap /= 0_c_int) then
      if (.not. (snap > 0.0_c_double .and. ieee_is_finite(snap))) then
         status = fail(FIG_ERR_ARGUMENT, 'view3d_object%gizmo: snap must be positive')
         return
      endif
   endif
   do k = 1_int32, 16_int32
      if (ieee_is_finite(matrix(k))) cycle
      status = fail(FIG_ERR_ARGUMENT, 'view3d_object%gizmo: the matrix is not finite')
      return
   enddo
   if (matrix(4) /= 0.0_c_double .or. matrix(8) /= 0.0_c_double .or. matrix(12) /= 0.0_c_double .or. &
       matrix(16) /= 1.0_c_double) then
      status = fail(FIG_ERR_ARGUMENT, "view3d_object%gizmo: the matrix's last row must be (0, 0, 0, 1)")
      return
   endif
   call gizmo_frame()
   call core_draw_begin()
   w = real(rect(3), real32)
   h = real(rect(4), real32)
   call set_rect(real(rect(1), real32), real(rect(2), real32), w, h)
   ! the axes about a fifth of the view's shorter side, in [40, 120] pixels; ImGuizmo's size is in clip space,
   ! measured along the view's longer side
   px = 0.2_real32 * min(w, h)
   if (px < 40.0_real32) then
      px = 40.0_real32
   elseif (120.0_real32 < px) then
      px = 120.0_real32
   endif
   gizmo_size_clip_space = (2.0_real32 * px) / max(max(w, h), 1.0_real32)
   allow_axis_flip = .false. ! the arrows point along +x, +y, +z (ImGuizmo's default flips them to the eye)
   status = gizmo_matrices(handle, fv, fp, o, dist)
   if (status /= FIG_OK) return
   do k = 1_int32, 16_int32
      if (k >= 13_int32 .and. k <= 15_int32) then
         fm(mod(k - 1_int32, 4_int32) + 1_int32, (k - 1_int32) / 4_int32 + 1_int32) = real(matrix(k) - o(k - 12_int32), real32)
      else
         fm(mod(k - 1_int32, 4_int32) + 1_int32, (k - 1_int32) / 4_int32 + 1_int32) = real(matrix(k), real32)
      endif
   enddo
   s3 = real(snap, real32)
   gid = core_get_id(id)
   call push_id(gid)
   call guard_mouse()
   moved = manipulate(fv, fp, OPS(mode), merge(GZ_LOCAL, GZ_WORLD, space == 1_c_int), fm, s3, has_snap /= 0_c_int)
   using_it = is_using()
   over = hovered_handle_type /= MT_NONE
   call pop_id()
   call hold_active(gid, using_it)
   call core_draw_end()
   if (using_it .or. over) then
      cube = 0.0_c_double
      status = fig_view3d_overlay(handle, 2_c_int, cube)
      if (status /= FIG_OK) return
   endif
   if (moved) then
      do k = 1_int32, 16_int32 ! float + 0.0 (a -0 is +0 after it) or + the target
         matrix(k) = real(fm(mod(k - 1_int32, 4_int32) + 1_int32, (k - 1_int32) / 4_int32 + 1_int32), c_double)
         if (k >= 13_int32 .and. k <= 15_int32) then
            matrix(k) = matrix(k) + o(k - 12_int32)
         elseif (matrix(k) == 0.0_c_double) then
            matrix(k) = 0.0_c_double
         endif
      enddo
      matrix(4) = 0.0_c_double
      matrix(8) = 0.0_c_double
      matrix(12) = 0.0_c_double
      matrix(16) = 1.0_c_double
      changed = 1_c_int
   endif
   endfunction gz_view_gizmo

   function fail(status, message) result(s)
   !< A failure: its message set (`fail` of the native layer).
   integer(c_int),   intent(in) :: status  !< Status.
   character(len=*), intent(in) :: message !< Message.
   integer(c_int)               :: s       !< Status.

   call fig_set_last_error(message, len(message, c_int))
   s = status
   endfunction fail

   subroutine gizmo_frame()
   !< ImGuizmo's per-frame state, once a frame (`BeginFrameState`, FIGURE's patch 0001).
   integer(int32) :: f !< Frame.

   f = core_frame_count()
   if (f == last_frame) return
   last_frame = f
   over_hotspot_last_frame = over_hotspot
   over_hotspot = .false.
   using_view_manipulate = .false.
   view_manipulator_hovered = .false.
   endsubroutine gizmo_frame

   function gizmo_matrices(handle, fv, fp, o, dist) result(status)
   !< `gizmo_matrices`: the view's matrices for its widget size, the world moved by -o (o: the camera's target), in
   !< single precision, the projection's depth range widened to [distance / 1000, 1000 distance].
   integer(c_int), intent(in)  :: handle   !< View.
   real(real32),   intent(out) :: fv(4,4)  !< View.
   real(real32),   intent(out) :: fp(4,4)  !< Projection.
   real(c_double), intent(out) :: o(3)     !< Target.
   real(c_double), intent(out) :: dist     !< Distance.
   integer(c_int)              :: status   !< Status.
   real(c_double)              :: v(16), p(16), zn, zf, az, el, fov, t !< Matrices, planes, camera, a term.
   integer(int32)              :: r, k     !< Counters.

   fv = 0.0_real32
   fp = 0.0_real32
   status = fig_view3d_matrices(handle, v, p)
   if (status /= FIG_OK) return
   status = fig_view3d_camera(handle, 0_c_int, 0_c_int, o, dist, az, el, fov)
   if (status /= FIG_OK) return
   zn = 1.0e-3_c_double * dist
   zf = 1.0e3_c_double * dist
   p(11) = (zf + zn) / (zn - zf)
   t = 2.0_c_double * zf
   t = t * zn
   p(15) = t / (zn - zf)
   do r = 1_int32, 3_int32 ! V * T(o)
      t = (v(r) * o(1) + v(4 + r) * o(2)) + v(8 + r) * o(3)
      v(12 + r) = v(12 + r) + t
   enddo
   do k = 1_int32, 16_int32
      fv(mod(k - 1_int32, 4_int32) + 1_int32, (k - 1_int32) / 4_int32 + 1_int32) = real(v(k), real32)
      fp(mod(k - 1_int32, 4_int32) + 1_int32, (k - 1_int32) / 4_int32 + 1_int32) = real(p(k), real32)
   enddo
   endfunction gizmo_matrices

   subroutine guard_mouse()
   !< `mouse_guard`: io.MousePos as ImGuizmo reads it, Dear ImGui's "no mouse" position (-FLT_MAX) replaced by one far
   !< outside the view, so the rays computed from it do not overflow.
   real(real64) :: x, y !< Pointer.

   if (core_mouse_pos_valid()) then
      call core_mouse_pos(x, y)
      mouse = [real(x, real32), real(y, real32)]
   else
      mouse = [-1.0e5_real32, -1.0e5_real32]
   endif
   endsubroutine guard_mouse

   subroutine hold_active(id, using_it)
   !< `hold_active`: Dear ImGui's active ID kept on `id` while a gizmo is dragged with the left button.
   integer(int32), intent(in) :: id       !< ID.
   logical,        intent(in) :: using_it !< In use.

   if (using_it .and. core_mouse_down(0_int32)) then
      if (core_active_id() == 0_int32) call core_set_active_id(id)
      if (core_active_id() == id) call core_keep_alive(id)
   elseif (core_active_id() == id) then
      call core_clear_active_id()
   endif
   endsubroutine hold_active

   subroutine orientation(b, u, azimuth, elevation)
   !< `orientation`: the azimuth and elevation [degrees] of a camera whose back vector is b and up vector u.
   real(c_double), intent(in)  :: b(3), u(3)         !< Back, up.
   real(c_double), intent(out) :: azimuth, elevation !< Angles [degrees].
   real(c_double), parameter   :: DEG = 3.14159265358979323846_c_double / 180.0_c_double !< A degree [radians].
   real(c_double)              :: n, bz, p, q, r     !< Norm, b's z, products.

   p = b(1) * b(1)
   q = b(2) * b(2)
   r = b(3) * b(3)
   n = sqrt((p + q) + r)
   bz = 0.0_c_double
   if (n > 0.0_c_double) bz = b(3) / n
   if (bz > 1.0_c_double - 1.0e-6_c_double) then
      elevation = 90.0_c_double
      azimuth = c_atan2(-u(2), -u(1)) / DEG
   elseif (bz < -1.0_c_double + 1.0e-6_c_double) then
      elevation = -90.0_c_double
      azimuth = c_atan2(u(2), u(1)) / DEG
   else
      elevation = c_asin(bz) / DEG
      azimuth = c_atan2(b(2), b(1)) / DEG
   endif
   endsubroutine orientation

   pure elemental function bits(x) result(i)
   !< A float's bits (`memcmp`).
   real(real32), intent(in) :: x !< Value.
   integer(int32)           :: i !< Bits.

   i = transfer(x, i)
   endfunction bits

   ! ImGuizmo's IDs, rectangle, state

   function current_id() result(id)
   !< `GetCurrentID`: the top of ImGuizmo's ID stack (-1 pushed when empty).
   integer(int32) :: id !< ID.

   if (id_depth == 0_int32) then
      id_depth = 1_int32
      id_stack(1) = -1_int32
   endif
   id = id_stack(id_depth)
   endfunction current_id

   subroutine push_id(n)
   !< `PushID(int)`: the integer hashed with the current ID.
   integer(int32), intent(in) :: n !< Integer.
   integer(int32)             :: id !< ID.

   id = plot_hash_int(n, current_id())
   id_depth = id_depth + 1_int32
   id_stack(id_depth) = id
   endsubroutine push_id

   subroutine pop_id()
   !< `PopID`.

   id_depth = id_depth - 1_int32
   endsubroutine pop_id

   subroutine set_rect(x, y, width, height)
   !< `SetRect`.
   real(real32), intent(in) :: x, y, width, height !< Rectangle [pixels].

   rx = x
   ry = y
   rwidth = width
   rheight = height
   rxmax = rx + rwidth
   rymax = ry + rheight
   display_ratio = width / height
   endsubroutine set_rect

   function is_using() result(yes)
   !< `IsUsing`.
   logical :: yes !< In use by the current ID.

   yes = using
   if (yes) yes = current_id() == editing_id
   endfunction is_using

   function tripod() result(t)
   !< `GetTripodState`'s choice: true for the active drag's frozen state.
   logical :: t !< The active one.

   t = using
   if (t) t = current_id() == editing_id
   endfunction tripod

   function color_u32(idx) result(col)
   !< `GetColorU32`: a style colour packed (`ColorConvertFloat4ToU32`).
   integer(int32), intent(in) :: idx !< Colour.
   integer(int32)             :: col !< Packed.

   col = core_color(real(st_colors(1, idx), real64), real(st_colors(2, idx), real64), real(st_colors(3, idx), real64), &
                    real(st_colors(4, idx), real64))
   endfunction color_u32

   ! geometry

   subroutine world_to_pos(world, mat, p, origin, size)
   !< `worldToPos`: a point through a matrix to pixels (ImGuizmo's rectangle, or `origin` and `size`); (-FLT_MAX,
   !< -FLT_MAX) at w 0.
   real(real32), intent(in)           :: world(4), mat(4,4) !< Point, matrix.
   real(real32), intent(out)          :: p(2)               !< Pixel.
   real(real32), intent(in), optional :: origin(2), size(2) !< Rectangle.
   real(real32)                       :: t(4), s, o(2), z(2) !< Transformed, a factor, the rectangle.

   o = [rx, ry]
   z = [rwidth, rheight]
   if (present(origin)) o = origin
   if (present(size)) z = size
   t = vec_transform_point(world, mat)
   if (abs(t(4)) < FLT_EPSILON) then
      p = [-FLT_MAX, -FLT_MAX]
      return
   endif
   s = 0.5_real32 / t(4)
   t = t * s
   t(1) = t(1) + 0.5_real32
   t(2) = t(2) + 0.5_real32
   t(2) = 1.0_real32 - t(2)
   t(1) = t(1) * z(1)
   t(2) = t(2) * z(2)
   p(1) = t(1) + o(1)
   p(2) = t(2) + o(2)
   endsubroutine world_to_pos

   subroutine camera_ray(origin, dir, view, proj, mx, my, px, py, sx, sy)
   !< `ComputeCameraRay`: the ray through the pointer from the near plane.
   real(real32), intent(out) :: origin(4), dir(4) !< Ray.
   real(real32), intent(in)  :: view(4,4), proj(4,4) !< Matrices.
   real(real32), intent(in)  :: mx, my, px, py, sx, sy !< Pointer, rectangle.
   real(real32)              :: inv(4,4), vinv(4,4), mox, moy, ha(4), hb(4), pa(4), pb(4), eye(4), t !< ImGuizmo's.
   logical                   :: a_inf, b_inf     !< At infinity.

   inv = mat_inverse(mat_mul(view, proj))
   t = (mx - px) / sx
   mox = t * 2.0_real32 - 1.0_real32
   t = 1.0_real32 - ((my - py) / sy)
   moy = t * 2.0_real32 - 1.0_real32
   ha = vec_transform(vec(mox, moy, 0.0_real32, 1.0_real32), inv)
   hb = vec_transform(vec(mox, moy, 1.0_real32 - FLT_EPSILON, 1.0_real32), inv)
   a_inf = abs(ha(4)) < FLT_EPSILON
   b_inf = abs(hb(4)) < FLT_EPSILON
   pa = ha
   if (.not. a_inf) pa = ha * (1.0_real32 / ha(4))
   pb = hb
   if (.not. b_inf) pb = hb * (1.0_real32 / hb(4))
   vinv = mat_inverse(view)
   eye = vinv(:, 4)
   if (vec_length_sq(pa - eye) <= vec_length_sq(pb - eye)) then
      origin = pa
      if (b_inf) then
         dir = vec_normalized(pa - eye)
      else
         dir = vec_normalized(pb - pa)
      endif
   else
      origin = pb
      if (a_inf) then
         dir = vec_normalized(pb - eye)
      else
         dir = vec_normalized(pa - pb)
      endif
   endif
   endsubroutine camera_ray

   function segment_length_clip(start, end_, local) result(l)
   !< `GetSegmentLengthClipSpace`.
   real(real32), intent(in) :: start(4), end_(4) !< Segment.
   logical,      intent(in) :: local             !< Through mMVPLocal.
   real(real32)             :: l                 !< Length.
   real(real32)             :: s(4), e(4), a(4), p, q !< Ends, axis, products.

   if (local) then
      s = vec_transform_point(start, mvp_local)
      e = vec_transform_point(end_, mvp_local)
   else
      s = vec_transform_point(start, mvp)
      e = vec_transform_point(end_, mvp)
   endif
   if (abs(s(4)) > FLT_EPSILON) s = s * (1.0_real32 / s(4))
   if (abs(e(4)) > FLT_EPSILON) e = e * (1.0_real32 / e(4))
   a = e - s
   if (display_ratio < 1.0_real32) then
      a(1) = a(1) * display_ratio
   else
      a(2) = a(2) / display_ratio
   endif
   p = a(1) * a(1)
   q = a(2) * a(2)
   l = sqrt(p + q)
   endfunction segment_length_clip

   function parallelogram(o, a, b) result(surface)
   !< `GetParallelogram`.
   real(real32), intent(in) :: o(4), a(4), b(4) !< Corner, sides' ends.
   real(real32)             :: surface          !< Area in clip space.
   real(real32)             :: pts(4, 3), sa(4), sb(4), ortho(4), dt, p, q !< ImGuizmo's.
   integer(int32)           :: i                !< Counter.

   pts(:, 1) = o
   pts(:, 2) = a
   pts(:, 3) = b
   do i = 1_int32, 3_int32
      pts(:, i) = vec_transform_point(pts(:, i), mvp)
      if (abs(pts(4, i)) > FLT_EPSILON) pts(:, i) = pts(:, i) * (1.0_real32 / pts(4, i))
   enddo
   sa = pts(:, 2) - pts(:, 1)
   sb = pts(:, 3) - pts(:, 1)
   sa(2) = sa(2) / display_ratio
   sb(2) = sb(2) / display_ratio
   ortho = vec(-sa(2), sa(1))
   call vec_normalize(ortho)
   dt = vec_dot3(ortho, sb)
   p = sa(1) * sa(1)
   q = sa(2) * sa(2)
   surface = sqrt(p + q) * abs(dt)
   endfunction parallelogram

   function point_on_segment(point, v1, v2) result(r)
   !< `PointOnSegment`.
   real(real32), intent(in) :: point(4), v1(4), v2(4) !< Point, segment.
   real(real32)             :: r(4)                   !< Closest point.
   real(real32)             :: c(4), v(4), d, t       !< ImGuizmo's.

   c = point - v1
   v = vec_normalized(v2 - v1)
   d = vec_length(v2 - v1)
   t = vec_dot3(v, c)
   if (t < 0.0_real32) then
      r = v1
   elseif (t > d) then
      r = v2
   else
      r = v1 + v * t
   endif
   endfunction point_on_segment

   pure function intersect_ray_plane(o, v, plan) result(t)
   !< `IntersectRayPlane`: -1 for a ray parallel to the plane.
   real(real32), intent(in) :: o(4), v(4), plan(4) !< Ray, plane.
   real(real32)             :: t                   !< Distance along the ray.
   real(real32)             :: numer, denom        !< ImGuizmo's.

   numer = vec_dot3(plan, o) - plan(4)
   denom = vec_dot3(plan, v)
   if (abs(denom) < FLT_EPSILON) then
      t = -1.0_real32
      return
   endif
   t = -(numer / denom)
   endfunction intersect_ray_plane

   function hovering_window() result(yes)
   !< `IsHoveringWindow`: the window drawn into is hovered, or none is and the pointer is in its inner rectangle.
   logical      :: yes      !< Hovered.
   integer(int32) :: state  !< 1 hovered, 2 no window hovered, 0 another.
   real(real64) :: inner(4) !< Its inner rectangle.

   call core_window_hover_state(state, inner)
   yes = state == 1_int32
   if (state == 2_int32) yes = core_mouse_hovering_rect(inner(1), inner(2), inner(3), inner(4), clip=.false.)
   endfunction hovering_window

   subroutine compute_context(view, proj, matrix, mode)
   !< `ComputeContext`.
   real(real32),   intent(in) :: view(4,4), proj(4,4), matrix(4,4) !< Matrices.
   integer(int32), intent(in) :: mode                              !< LOCAL or WORLD.
   real(real32)               :: vinv(4,4), rvi(4), rl, c(2)        !< ImGuizmo's.

   g_mode = mode
   view_mat = view
   proj_mat = proj
   mouse_over = hovering_window()
   model_local = matrix
   call mat_ortho_normalize(model_local)
   if (mode == GZ_LOCAL) then
      model = model_local
   else
      model = mat_translation(matrix(:, 4))
   endif
   model_source = matrix
   model_scale_origin = [vec_length(model_source(:, 1)), vec_length(model_source(:, 2)), vec_length(model_source(:, 3)), &
                         0.0_real32]
   model_inverse = mat_inverse(model)
   model_source_inverse = mat_inverse(model_source)
   view_projection = mat_mul(view_mat, proj_mat)
   mvp = mat_mul(model, view_projection)
   mvp_local = mat_mul(model_local, view_projection)
   vinv = mat_inverse(view_mat)
   camera_dir = vinv(:, 3)
   camera_eye = vinv(:, 4)
   camera_right = vinv(:, 1)
   camera_up = vinv(:, 2)
   rvi = vec_transform_vector(vinv(:, 1), model_inverse)
   rl = segment_length_clip(vec(0.0_real32, 0.0_real32), rvi, .false.)
   screen_factor = gizmo_size_clip_space / rl
   call world_to_pos(vec(0.0_real32, 0.0_real32), mvp, c)
   square_center = c
   square_min = [c(1) - 10.0_real32, c(2) - 10.0_real32]
   square_max = [c(1) + 10.0_real32, c(2) + 10.0_real32]
   call camera_ray(ray_origin, ray_vector, view_mat, proj_mat, mouse(1), mouse(2), rx, ry, rwidth, rheight)
   endsubroutine compute_context

   subroutine compute_colors(colors, type, operation)
   !< `ComputeColors`.
   integer(int32), intent(out) :: colors(0:6) !< Colours.
   integer(int32), intent(in)  :: type        !< Hovered or used handle.
   integer(int32), intent(in)  :: operation   !< TRANSLATE, ROTATE or SCALE.
   integer(int32), parameter   :: WHITE = -1_int32 !< IM_COL32_WHITE.
   integer(int32)              :: sel, i      !< Selection colour, counter.

   if (.not. enabled) then
      colors = color_u32(INACTIVE)
      return
   endif
   sel = color_u32(SELECTION)
   colors = 0_int32
   select case (operation)
   case (GZ_TRANSLATE)
      colors(0) = merge(sel, WHITE, type == MT_MOVE_SCREEN)
      do i = 0_int32, 2_int32
         colors(i + 1) = merge(sel, color_u32(DIRECTION_X + i), type == MT_MOVE_X + i)
         colors(i + 4) = merge(sel, color_u32(PLANE_X + i), type == MT_MOVE_YZ + i)
         if (type == MT_MOVE_SCREEN) colors(i + 4) = sel
      enddo
   case (GZ_ROTATE)
      colors(0) = merge(sel, WHITE, type == MT_ROTATE_SCREEN)
      do i = 0_int32, 2_int32
         colors(i + 1) = merge(sel, color_u32(DIRECTION_X + i), type == MT_ROTATE_X + i)
      enddo
   case (GZ_SCALE)
      colors(0) = merge(sel, WHITE, type == MT_SCALE_XYZ)
      do i = 0_int32, 2_int32
         colors(i + 1) = merge(sel, color_u32(DIRECTION_X + i), type == MT_SCALE_X + i)
      enddo
   endselect
   endsubroutine compute_colors

   subroutine tripod_axis(a, dir_axis, dir_x, dir_y, below_axis, below_plane, local)
   !< `ComputeTripodAxisAndVisibility`.
   integer(int32), intent(in)  :: a                          !< Axis (0, 1, 2).
   real(real32),   intent(out) :: dir_axis(4), dir_x(4), dir_y(4) !< Axis and plane directions.
   logical,        intent(out) :: below_axis, below_plane    !< Visible.
   logical,        intent(in)  :: local                      !< Through mMVPLocal.
   real(real32)               :: ld, ldm, lx, lxm, ly, lym, ma, mx, my, al, ps !< ImGuizmo's.
   integer(int32)              :: b, c                       !< The other axes.
   logical                     :: masked, mask_plane         !< The axis mask's tests.

   b = mod(a + 1_int32, 3_int32)
   c = mod(a + 2_int32, 3_int32)
   dir_axis = UNARY(:, a)
   dir_x = UNARY(:, b)
   dir_y = UNARY(:, c)
   masked = iand(ishft(1_int32, a), axis_mask) /= 0_int32
   mask_plane = ishft(1_int32, a) == axis_mask .or. axis_mask == 0_int32
   if (tripod()) then
      below_axis = active_tripod_state%below_axis(a) .and. .not. masked
      below_plane = active_tripod_state%below_plane(a) .and. mask_plane
      dir_axis = dir_axis * active_tripod_state%axis_factor(a)
      dir_x = dir_x * active_tripod_state%axis_factor(b)
      dir_y = dir_y * active_tripod_state%axis_factor(c)
   else
      ld = segment_length_clip(vec(0.0_real32, 0.0_real32, 0.0_real32), dir_axis, local)
      ldm = segment_length_clip(vec(0.0_real32, 0.0_real32, 0.0_real32), -dir_axis, local)
      lx = segment_length_clip(vec(0.0_real32, 0.0_real32, 0.0_real32), dir_x, local)
      lxm = segment_length_clip(vec(0.0_real32, 0.0_real32, 0.0_real32), -dir_x, local)
      ly = segment_length_clip(vec(0.0_real32, 0.0_real32, 0.0_real32), dir_y, local)
      lym = segment_length_clip(vec(0.0_real32, 0.0_real32, 0.0_real32), -dir_y, local)
      ma = flip(ld, ldm)
      mx = flip(lx, lxm)
      my = flip(ly, lym)
      dir_axis = dir_axis * ma
      dir_x = dir_x * mx
      dir_y = dir_y * my
      al = segment_length_clip(vec(0.0_real32, 0.0_real32, 0.0_real32), dir_axis * screen_factor, local)
      ps = parallelogram(vec(0.0_real32, 0.0_real32, 0.0_real32), dir_x * screen_factor, dir_y * screen_factor)
      below_plane = ps > axis_limit .and. mask_plane
      below_axis = al > plane_limit .and. .not. masked
      tripod_state%axis_factor(a) = ma
      tripod_state%axis_factor(b) = mx
      tripod_state%axis_factor(c) = my
      tripod_state%below_axis(a) = below_axis
      tripod_state%below_plane(a) = below_plane
   endif
   contains
      function flip(l, lm) result(m)
      !< -1 when the axis is flipped toward the eye (flips allowed), else 1.
      real(real32), intent(in) :: l, lm !< Lengths of the axis and its opposite.
      real(real32)             :: m     !< Factor.

      m = 1.0_real32
      if (allow_axis_flip .and. l < lm) then
         if (abs(l - lm) > FLT_EPSILON) m = -1.0_real32
      endif
      endfunction flip
   endsubroutine tripod_axis

   subroutine compute_snap(v, snap)
   !< `ComputeSnap(float*, float)`.
   real(real32), intent(inout) :: v    !< Value.
   real(real32), intent(in)    :: snap !< Step.
   real(real32)                :: modulo, ratio, sgn !< ImGuizmo's.

   if (snap <= FLT_EPSILON) return
   modulo = c_fmodf(v, snap)
   ratio = abs(modulo) / snap
   if (ratio < SNAP_TENSION) then
      v = v - modulo
   elseif (ratio > (1.0_real32 - SNAP_TENSION)) then
      sgn = 1.0_real32
      if (v < 0.0_real32) sgn = -1.0_real32
      v = (v - modulo) + snap * sgn
   endif
   endsubroutine compute_snap

   function angle_on_plan() result(angle)
   !< `ComputeAngleOnPlan`.
   real(real32) :: angle !< Angle [radians].
   real(real32) :: l, local_pos(4), perp(4), c !< ImGuizmo's.

   l = intersect_ray_plane(ray_origin, ray_vector, translation_plan)
   local_pos = vec_normalized((ray_origin + ray_vector * l) - model(:, 4))
   perp = vec_cross(rotation_vector_source, translation_plan)
   call vec_normalize(perp)
   c = vec_dot(local_pos, rotation_vector_source)
   if (c < -1.0_real32) then
      c = -1.0_real32
   elseif (c > 1.0_real32) then
      c = 1.0_real32
   endif
   angle = c_acosf(c)
   if (vec_dot(local_pos, perp) < 0.0_real32) then
      angle = angle * 1.0_real32
   else
      angle = angle * (-1.0_real32)
   endif
   endfunction angle_on_plan

   ! drawing

   subroutine line(a, b, col, thickness)
   !< `AddLine`.
   real(real32),   intent(in) :: a(2), b(2) !< Ends [pixels].
   integer(int32), intent(in) :: col        !< Colour.
   real(real32),   intent(in) :: thickness  !< Thickness.

   call core_draw_line(real(a(1), real64), real(a(2), real64), real(b(1), real64), real(b(2), real64), col, &
                       real(thickness, real64))
   endsubroutine line

   subroutine circle(c, r, col, filled, segments, thickness)
   !< `AddCircle`, `AddCircleFilled`.
   real(real32),   intent(in)           :: c(2), r   !< Centre, radius [pixels].
   integer(int32), intent(in)           :: col       !< Colour.
   logical,        intent(in)           :: filled    !< Filled.
   integer(int32), intent(in), optional :: segments  !< Segments (default 0: automatic).
   real(real32),   intent(in), optional :: thickness !< Thickness (default 1).
   integer(int32)                       :: s         !< Segments.
   real(real64)                         :: t         !< Thickness.

   s = 0_int32
   if (present(segments)) s = segments
   t = 1.0_real64
   if (present(thickness)) t = real(thickness, real64)
   call core_draw_circle(real(c(1), real64), real(c(2), real64), real(r, real64), col, filled=filled, thickness=t, &
                         segments=s)
   endsubroutine circle

   subroutine text_at(p, s, n)
   !< ImGuizmo's information text, its shadow first.
   real(real32),      intent(in) :: p(2) !< The point it follows [pixels].
   character(len=*),  intent(in) :: s    !< Text buffer.
   integer(int32),    intent(in) :: n    !< Its length.

   call core_draw_text(real(p(1) + 15.0_real32, real64), real(p(2) + 15.0_real32, real64), color_u32(TEXT_SHADOW), s(1:n))
   call core_draw_text(real(p(1) + 14.0_real32, real64), real(p(2) + 14.0_real32, real64), color_u32(TEXT), s(1:n))
   endsubroutine text_at

   subroutine format_values(head, v, nv, unit2, buf, n)
   !< A text of ImGuizmo's masks: `head` then each value as `%5.3f` (`unit2` empty) or `%5.2f`, separated as the
   !< masks separate them (the names in `head` are `X`, `Y`, `Z`, `XYZ`, `Screen`).
   character(len=*),  intent(in)    :: head(:)  !< Names, one per value.
   real(real32),      intent(in)    :: v(:)     !< Values.
   integer(int32),    intent(in)    :: nv       !< Values used.
   character(len=*),  intent(in)    :: unit2    !< Format of each value (`%5.3f`, `%5.2f`).
   character(len=*),  intent(inout) :: buf      !< Text.
   integer(int32),    intent(out)   :: n        !< Its length.
   type(plot_format)                :: f        !< Format.
   integer(int32)                   :: k        !< Counter.

   call fmt_parse(unit2, f)
   n = 0_int32
   do k = 1_int32, nv
      if (k > 1_int32) call fmt_text(buf, n, ' ')
      call fmt_text(buf, n, trim(head(k)))
      call fmt_text(buf, n, ' : ')
      call fmt_real(buf, n, f, real(v(k), real64))
   enddo
   endsubroutine format_values

   subroutine draw_rotation(op, type)
   !< `DrawRotationGizmo`.
   integer(int32), intent(in) :: op, type !< Operation, handle.
   integer(int32), parameter  :: NMAX = 2_int32 * HALF_CIRCLE + 1_int32 !< Points of a circle.
   integer(int32) :: colors(0:6), axis, cmul, i, n, k        !< Colours, counters.
   real(real32)   :: vinv(4,4), vdn(4), hand, ang0, ng, ap(4), pos(4), cp(2, NMAX), center(2), r, d(2) !< ImGuizmo's.
   real(real64)   :: xs(NMAX), ys(NMAX)                       !< Points, for figure_core.
   real(real32)   :: rot(4,4), t                              !< A rotation, a fraction.
   logical        :: has_rsc, using_axis, right_handed        !< ImGuizmo's.
   character(len=96) :: buf                                   !< Text.
   character(len=6), parameter :: NAMES(4) = ['X     ', 'Y     ', 'Z     ', 'Screen'] !< rotationInfoMask's names.
   type(plot_format) :: f                                     !< `%5.2f`.

   if (iand(op, GZ_ROTATE) == 0_int32) return
   call compute_colors(colors, type, GZ_ROTATE)
   vinv = mat_inverse(view_mat)
   hand = 1.0_real32
   if (.not. vec_dot(vec_cross(vinv(:, 1), vinv(:, 2)), vinv(:, 3)) >= 0.0_real32) hand = -1.0_real32
   vdn = vec_normalized(camera_dir) * hand
   vdn = vec_transform_vector(vdn, model_inverse)
   radius_square_center = SCREEN_ROTATE_SIZE * rheight
   has_rsc = iand(op, ROTATE_SCREEN) /= 0_int32
   call world_to_pos(model(:, 4), view_projection, center)
   do axis = 0_int32, 2_int32
      if (iand(op, ishft(ROTATE_Z, -axis)) == 0_int32) cycle
      using_axis = using .and. type == MT_ROTATE_Z - axis
      cmul = 2_int32
      if (has_rsc .and. .not. using_axis) cmul = 1_int32
      n = cmul * HALF_CIRCLE + 1_int32
      right_handed = proj_mat(4, 3) < 0.0_real32
      ang0 = c_atan2f(vdn(mod(4_int32 - axis, 3_int32) + 1_int32), vdn(mod(3_int32 - axis, 3_int32) + 1_int32))
      ang0 = ang0 + (-ZPI) * 0.5_real32
      if (.not. right_handed) then
         ang0 = ang0 + ZPI
      else
         ang0 = ang0 + 0.0_real32
      endif
      do i = 0_int32, n - 1_int32
         t = real(i, real32) / real(cmul * HALF_CIRCLE, real32)
         ng = (real(cmul, real32) * ZPI) * t
         ng = ang0 + ng
         ap = vec(c_cosf(ng), c_sinf(ng), 0.0_real32)
         pos = vec(ap(axis + 1_int32), ap(mod(axis + 1_int32, 3_int32) + 1_int32), ap(mod(axis + 2_int32, 3_int32) + 1_int32))
         pos = pos * screen_factor
         pos = pos * ROTATION_DISPLAY_FACTOR
         call world_to_pos(pos, mvp, cp(:, i + 1_int32))
      enddo
      if (.not. using .or. using_axis) then
         xs(1:n) = real(cp(1, 1:n), real64)
         ys(1:n) = real(cp(2, 1:n), real64)
         call core_draw_polyline(xs(1:n), ys(1:n), colors(3 - axis), real(st_rotation_line_thickness, real64))
      endif
      d = center - cp(:, 1)
      r = sqrt(d(1) * d(1) + d(2) * d(2))
      if (r > radius_square_center) radius_square_center = r
   enddo
   if (has_rsc .and. (.not. using .or. type == MT_ROTATE_SCREEN)) &
      call circle(center, radius_square_center, colors(0), .false., 64_int32, st_rotation_outer_line_thickness)
   if (is_using() .and. type >= MT_ROTATE_X .and. type <= MT_ROTATE_SCREEN) then
      cp(:, 1) = center
      do i = 1_int32, HALF_CIRCLE
         t = real(i - 1_int32, real32) / real(HALF_CIRCLE - 1_int32, real32)
         ng = rotation_angle * t
         rot = mat_rotation_axis(translation_plan, ng)
         pos = vec_transform_point(rotation_vector_source, rot)
         pos = pos * (screen_factor * ROTATION_DISPLAY_FACTOR)
         call world_to_pos(pos + model(:, 4), view_projection, cp(:, i + 1_int32))
      enddo
      n = HALF_CIRCLE + 1_int32
      xs(1:n) = real(cp(1, 1:n), real64)
      ys(1:n) = real(cp(2, 1:n), real64)
      call core_draw_convex_poly_filled(xs(1:n), ys(1:n), color_u32(ROTATION_USING_FILL))
      call core_draw_polyline(xs(1:n), ys(1:n), color_u32(ROTATION_USING_BORDER), real(st_rotation_line_thickness, real64), &
                              closed=.true.)
      call fmt_parse('%5.2f', f)
      k = 0_int32
      call fmt_text(buf, k, trim(NAMES(type - MT_ROTATE_X + 1_int32)))
      call fmt_text(buf, k, ' : ')
      call fmt_real(buf, k, f, real((rotation_angle / ZPI) * 180.0_real32, real64))
      call fmt_text(buf, k, ' deg ')
      call fmt_real(buf, k, f, real(rotation_angle, real64))
      call fmt_text(buf, k, ' rad')
      call text_at(cp(:, 2), buf, k)
   endif
   endsubroutine draw_rotation

   subroutine draw_hatched_axis(axis)
   !< `DrawHatchedAxis`.
   real(real32), intent(in) :: axis(4) !< Axis.
   real(real32)             :: a(2), b(2) !< A dash.
   integer(int32)           :: j       !< Counter.

   if (st_hatched_axis_line_thickness <= 0.0_real32) return
   do j = 1_int32, 9_int32
      call world_to_pos(((axis * 0.05_real32) * real(j * 2_int32, real32)) * screen_factor, mvp, a)
      call world_to_pos(((axis * 0.05_real32) * real(j * 2_int32 + 1_int32, real32)) * screen_factor, mvp, b)
      call line(a, b, color_u32(HATCHED_AXIS_LINES), st_hatched_axis_line_thickness)
   enddo
   endsubroutine draw_hatched_axis

   subroutine draw_scale(op, type)
   !< `DrawScaleGizmo`.
   integer(int32), intent(in) :: op, type !< Operation, handle.
   integer(int32) :: colors(0:6), i, k, ci                   !< Colours, counters.
   real(real32)   :: sd(4), da(4), dx(4), dy(4), base(2), noscale(2), tip(2), dest(2), marker !< ImGuizmo's.
   logical        :: ba, bp, has_t                           !< Visibility, a translation on the axis.
   character(len=64) :: buf                                  !< Text.
   character(len=3), parameter :: NAMES(4) = ['X  ', 'Y  ', 'Z  ', 'XYZ'] !< scaleInfoMask's names.

   if (iand(op, GZ_SCALE) == 0_int32) return
   call compute_colors(colors, type, GZ_SCALE)
   sd = 1.0_real32
   if (is_using()) sd = scale
   do i = 0_int32, 2_int32
      if (iand(op, ishft(SCALE_X, i)) == 0_int32) cycle
      if (.not. (.not. using .or. (using .and. type == MT_SCALE_X + i))) cycle
      call tripod_axis(i, da, dx, dy, ba, bp, .true.)
      if (.not. ba) cycle
      has_t = iand(op, ishft(TRANSLATE_X, i)) == ishft(TRANSLATE_X, i)
      marker = 1.0_real32
      if (has_t) marker = 1.4_real32
      call world_to_pos((da * 0.1_real32) * screen_factor, mvp, base)
      call world_to_pos((da * marker) * screen_factor, mvp, noscale)
      call world_to_pos(((da * marker) * sd(i + 1_int32)) * screen_factor, mvp, tip)
      if (is_using()) then
         call line(base, noscale, color_u32(SCALE_LINE), st_scale_line_thickness)
         call circle(noscale, st_scale_line_circle_size, color_u32(SCALE_LINE), .true.)
      endif
      if (.not. has_t .or. using) call line(base, tip, colors(i + 1), st_scale_line_thickness)
      call circle(tip, st_scale_line_circle_size, colors(i + 1), .true.)
      if (current_tripod_factor(i) < 0.0_real32) call draw_hatched_axis(da * sd(i + 1_int32))
   enddo
   call circle(square_center, st_center_circle_size, colors(0), .true., 32_int32)
   if (is_using() .and. type >= MT_SCALE_X .and. type <= MT_SCALE_XYZ) then
      call world_to_pos(model(:, 4), view_projection, dest)
      ci = (type - MT_SCALE_X) * 3_int32
      call format_values(NAMES(type - MT_SCALE_X + 1_int32:), [sd(INFO_INDEX(ci) + 1_int32)], 1_int32, '%5.2f', buf, k)
      call text_at(dest, buf, k)
   endif
   endsubroutine draw_scale

   function current_tripod_factor(i) result(f)
   !< `GetTripodState().mAxisFactor[i]`.
   integer(int32), intent(in) :: i !< Axis.
   real(real32)               :: f !< Factor.

   if (tripod()) then
      f = active_tripod_state%axis_factor(i)
   else
      f = tripod_state%axis_factor(i)
   endif
   endfunction current_tripod_factor

   subroutine draw_translation(op, type)
   !< `DrawTranslationGizmo`.
   integer(int32), intent(in) :: op, type !< Operation, handle.
   integer(int32) :: colors(0:6), i, j, k, ci, nv             !< Colours, counters.
   real(real32)   :: origin(2), da(4), dx(4), dy(4), base(2), tip(2), dir(2), ortho(2), a(2), d, corner(4) !< ImGuizmo's.
   real(real32)   :: quad(2, 4), src(2), dest(2), dif(4), delta(4), vals(3) !< ImGuizmo's.
   real(real64)   :: xs(4), ys(4)                             !< A quad, for figure_core.
   logical        :: ba, bp                                   !< Visibility.
   character(len=96) :: buf                                   !< Text.
   character(len=1), parameter :: AXES(3) = ['X', 'Y', 'Z']   !< The axes' names.
   character(len=1)  :: names(3)                              !< A mask's names.

   if (iand(op, GZ_TRANSLATE) == 0_int32) return
   call compute_colors(colors, type, GZ_TRANSLATE)
   call world_to_pos(model(:, 4), view_projection, origin)
   do i = 0_int32, 2_int32
      call tripod_axis(i, da, dx, dy, ba, bp, .false.)
      if (.not. using .or. (using .and. type == MT_MOVE_X + i)) then
         if (ba .and. iand(op, ishft(TRANSLATE_X, i)) /= 0_int32) then
            call world_to_pos((da * 0.1_real32) * screen_factor, mvp, base)
            call world_to_pos(da * screen_factor, mvp, tip)
            call line(base, tip, colors(i + 1), st_translation_line_thickness)
            dir = origin - tip
            d = sqrt(dir(1) * dir(1) + dir(2) * dir(2))
            dir = dir / d
            dir = dir * st_translation_line_arrow_size
            ortho = [dir(2), -dir(1)]
            a = tip + dir
            call core_draw_triangle_filled(real(tip(1) - dir(1), real64), real(tip(2) - dir(2), real64),  &
                                           real(a(1) + ortho(1), real64), real(a(2) + ortho(2), real64), &
                                           real(a(1) - ortho(1), real64), real(a(2) - ortho(2), real64), colors(i + 1))
            if (current_tripod_factor(i) < 0.0_real32) call draw_hatched_axis(da)
         endif
      endif
      if (.not. using .or. (using .and. type == MT_MOVE_YZ + i)) then
         if (bp .and. iand(op, TRANSLATE_PLANS(i)) == TRANSLATE_PLANS(i)) then
            do j = 0_int32, 3_int32
               corner = (dx * QUAD_UV(j * 2_int32) + dy * QUAD_UV(j * 2_int32 + 1_int32)) * screen_factor
               call world_to_pos(corner, mvp, quad(:, j + 1_int32))
            enddo
            xs = real(quad(1, :), real64)
            ys = real(quad(2, :), real64)
            call core_draw_polyline(xs, ys, color_u32(DIRECTION_X + i), 1.0_real64, closed=.true.)
            call core_draw_convex_poly_filled(xs, ys, colors(i + 4))
         endif
      endif
   enddo
   call circle(square_center, st_center_circle_size, colors(0), .true., 32_int32)
   if (is_using() .and. type >= MT_MOVE_X .and. type <= MT_MOVE_SCREEN) then
      call world_to_pos(matrix_origin, view_projection, src)
      call world_to_pos(model(:, 4), view_projection, dest)
      dif = vec(dest(1) - src(1), dest(2) - src(2), 0.0_real32, 0.0_real32)
      call vec_normalize(dif)
      dif = dif * 5.0_real32
      call circle(src, 6.0_real32, color_u32(TRANSLATION_LINE), .false.)
      call circle(dest, 6.0_real32, color_u32(TRANSLATION_LINE), .false.)
      call line([src(1) + dif(1), src(2) + dif(2)], [dest(1) - dif(1), dest(2) - dif(2)], color_u32(TRANSLATION_LINE), &
                2.0_real32)
      delta = model(:, 4) - matrix_origin
      ci = (type - MT_MOVE_X) * 3_int32
      select case (type)
      case (MT_MOVE_X, MT_MOVE_Y, MT_MOVE_Z)
         nv = 1_int32
      case (MT_MOVE_SCREEN)
         nv = 3_int32
      case default
         nv = 2_int32
      endselect
      do j = 1_int32, nv
         vals(j) = delta(INFO_INDEX(ci + j - 1_int32) + 1_int32)
         names(j) = AXES(INFO_INDEX(ci + j - 1_int32) + 1_int32)
      enddo
      call format_values(names, vals, nv, '%5.3f', buf, k)
      call text_at(dest, buf, k)
   endif
   endsubroutine draw_translation

   ! interaction

   function can_activate() result(yes)
   !< `CanActivate`: a click on no item.
   logical :: yes !< A gizmo may take the press.

   yes = core_mouse_clicked(0_int32)
   if (yes) yes = .not. core_any_item_hovered()
   if (yes) yes = .not. core_any_item_active()
   endfunction can_activate

   function move_type(op) result(type)
   !< `GetMoveType(op, NULL)`.
   integer(int32), intent(in) :: op   !< Operation.
   integer(int32)             :: type !< Handle hovered.
   real(real32)   :: sc(4), da(4), dx(4), dy(4), l, pop(4), as(2), ae(2), cl(4), x, y !< ImGuizmo's.
   integer(int32) :: i                !< Axis.
   logical        :: ba, bp, masked, multiple, none !< Visibility, the axis mask.

   type = MT_NONE
   if (iand(op, GZ_TRANSLATE) == 0_int32 .or. using .or. .not. mouse_over) return
   none = axis_mask == 0_int32
   multiple = iand(axis_mask, axis_mask - 1_int32) /= 0_int32
   if (mouse(1) >= square_min(1) .and. mouse(1) <= square_max(1) .and. mouse(2) >= square_min(2) .and. &
       mouse(2) <= square_max(2) .and. iand(op, GZ_TRANSLATE) == GZ_TRANSLATE) type = MT_MOVE_SCREEN
   sc = vec(mouse(1) - rx, mouse(2) - ry)
   do i = 0_int32, 2_int32
      if (type /= MT_NONE) exit
      masked = iand(ishft(1_int32, i), axis_mask) /= 0_int32
      call tripod_axis(i, da, dx, dy, ba, bp, .false.)
      da = vec_transform_vector(da, model)
      dx = vec_transform_vector(dx, model)
      dy = vec_transform_vector(dy, model)
      l = intersect_ray_plane(ray_origin, ray_vector, build_plan(model(:, 4), da))
      pop = ray_origin + ray_vector * l
      call world_to_pos(model(:, 4) + (da * screen_factor) * 0.1_real32, view_projection, as)
      as = as - [rx, ry]
      call world_to_pos(model(:, 4) + da * screen_factor, view_projection, ae)
      ae = ae - [rx, ry]
      cl = point_on_segment(sc, vec(as(1), as(2)), vec(ae(1), ae(2)))
      if (vec_length(cl - sc) < 12.0_real32 .and. iand(op, ishft(TRANSLATE_X, i)) /= 0_int32) then
         if (masked) exit
         type = MT_MOVE_X + i
      endif
      x = vec_dot3(dx, (pop - model(:, 4)) * (1.0_real32 / screen_factor))
      y = vec_dot3(dy, (pop - model(:, 4)) * (1.0_real32 / screen_factor))
      if (bp .and. x >= QUAD_UV(0) .and. x <= QUAD_UV(4) .and. y >= QUAD_UV(1) .and. y <= QUAD_UV(3) .and. &
          iand(op, TRANSLATE_PLANS(i)) == TRANSLATE_PLANS(i)) then
         if ((.not. masked .or. multiple) .and. .not. none) exit
         type = MT_MOVE_YZ + i
      endif
   enddo
   endfunction move_type

   function scale_type(op) result(type)
   !< `GetScaleType(op)` (no universal scale).
   integer(int32), intent(in) :: op   !< Operation.
   integer(int32)             :: type !< Handle hovered.
   real(real32)   :: da(4), dx(4), dy(4), l, pop(4), ps(2), as(2), ae(2), cl(4), so, eo !< ImGuizmo's.
   integer(int32) :: i                !< Axis.
   logical        :: ba, bp, masked, has_t !< Visibility, the axis mask, a translation on the axis.

   type = MT_NONE
   if (using) return
   if (mouse(1) >= square_min(1) .and. mouse(1) <= square_max(1) .and. mouse(2) >= square_min(2) .and. &
       mouse(2) <= square_max(2) .and. iand(op, GZ_SCALE) == GZ_SCALE) type = MT_SCALE_XYZ
   do i = 0_int32, 2_int32
      if (type /= MT_NONE) exit
      if (iand(op, ishft(SCALE_X, i)) == 0_int32) cycle
      masked = iand(ishft(1_int32, i), axis_mask) /= 0_int32
      call tripod_axis(i, da, dx, dy, ba, bp, .true.)
      da = vec_transform_vector(da, model_local)
      dx = vec_transform_vector(dx, model_local)
      dy = vec_transform_vector(dy, model_local)
      l = intersect_ray_plane(ray_origin, ray_vector, build_plan(model_local(:, 4), da))
      pop = ray_origin + ray_vector * l
      has_t = iand(op, ishft(TRANSLATE_X, i)) == ishft(TRANSLATE_X, i)
      so = 0.1_real32
      eo = 1.0_real32
      if (has_t) then
         so = 1.0_real32
         eo = 1.4_real32
      endif
      call world_to_pos(pop, view_projection, ps)
      call world_to_pos(model_local(:, 4) + (da * screen_factor) * so, view_projection, as)
      call world_to_pos(model_local(:, 4) + (da * screen_factor) * eo, view_projection, ae)
      cl = point_on_segment(vec(ps(1), ps(2)), vec(as(1), as(2)), vec(ae(1), ae(2)))
      if (vec_length(cl - vec(ps(1), ps(2))) < 12.0_real32) then
         if (.not. masked) type = MT_SCALE_X + i
      endif
   enddo
   endfunction scale_type

   function rotate_type(op) result(type)
   !< `GetRotateType(op)`.
   integer(int32), intent(in) :: op   !< Operation.
   integer(int32)             :: type !< Handle hovered.
   real(real32)   :: ds(4), dist, mvpos(4), plan(4), l, iwp(4), ivp(4), ideal(4), is(2), dos(2) !< ImGuizmo's.
   integer(int32) :: i                !< Axis.
   logical        :: none, multiple, masked !< The axis mask.

   type = MT_NONE
   if (using) return
   none = axis_mask == 0_int32
   multiple = iand(axis_mask, axis_mask - 1_int32) /= 0_int32
   ds = vec(mouse(1) - square_center(1), mouse(2) - square_center(2), 0.0_real32, 0.0_real32)
   dist = vec_length(ds)
   if (iand(op, ROTATE_SCREEN) /= 0_int32 .and. dist >= (radius_square_center - 4.0_real32) .and. &
       dist < (radius_square_center + 4.0_real32)) then
      if (.not. none) return
      type = MT_ROTATE_SCREEN
   endif
   mvpos = vec_transform_point(model(:, 4), view_mat)
   do i = 0_int32, 2_int32
      if (type /= MT_NONE) exit
      if (iand(op, ishft(ROTATE_X, i)) == 0_int32) cycle
      masked = iand(ishft(1_int32, i), axis_mask) /= 0_int32
      plan = build_plan(model(:, 4), model(:, i + 1_int32))
      l = intersect_ray_plane(ray_origin, ray_vector, plan)
      iwp = ray_origin + ray_vector * l
      ivp = vec_transform_point(iwp, view_mat)
      if (abs(mvpos(3)) - abs(ivp(3)) < -FLT_EPSILON) cycle
      ideal = vec_normalized(iwp - model(:, 4))
      ideal = vec_transform_vector(ideal, model_inverse)
      call world_to_pos((ideal * ROTATION_DISPLAY_FACTOR) * screen_factor, mvp, is)
      dos = is - mouse
      if (vec_length(vec(dos(1), dos(2))) < 8.0_real32) then
         if ((.not. masked .or. multiple) .and. .not. none) exit
         type = MT_ROTATE_X + i
      endif
   enddo
   endfunction rotate_type

   function handle_translation(matrix, op, type, snap, has_snap) result(modified)
   !< `HandleTranslation`.
   real(real32),   intent(inout) :: matrix(4,4) !< The matrix moved.
   integer(int32), intent(in)    :: op          !< Operation.
   integer(int32), intent(inout) :: type        !< Handle.
   real(real32),   intent(in)    :: snap(3)     !< Snap.
   logical,        intent(in)    :: has_snap    !< Snap given.
   logical                       :: modified    !< Moved.
   logical        :: local                      !< applyRotationLocaly.
   real(real32)   :: sl, l, np(4), no(4), delta(4), av(4), loa, cd(4), msn(4,4), msni(4,4), mpn(4, 0:6), cmn(4), ov(4) !<
                                                !< ImGuizmo's.
   integer(int32) :: ai, i                      !< Axis, counter.

   modified = .false.
   if (iand(op, GZ_TRANSLATE) == 0_int32 .or. type /= MT_NONE) return
   local = g_mode == GZ_LOCAL .or. current_handle_type == MT_MOVE_SCREEN
   if (is_using() .and. current_handle_type >= MT_MOVE_X .and. current_handle_type <= MT_MOVE_SCREEN) then
      call core_want_capture_mouse()
      sl = intersect_ray_plane(ray_origin, ray_vector, translation_plan)
      l = abs(sl)
      np = ray_origin + ray_vector * l
      no = np - relative_origin * screen_factor
      delta = no - model(:, 4)
      if (current_handle_type >= MT_MOVE_X .and. current_handle_type <= MT_MOVE_Z) then
         ai = current_handle_type - MT_MOVE_X
         av = model(:, ai + 1_int32)
         loa = vec_dot(av, delta)
         delta = av * loa
      endif
      if (has_snap) then
         cd = (model(:, 4) + delta) - matrix_origin
         if (local) then
            msn = model_source
            call mat_ortho_normalize(msn)
            msni = mat_inverse(msn)
            cd = vec_transform_vector(cd, msni)
            do i = 1_int32, 3_int32
               call compute_snap(cd(i), snap(i))
            enddo
            cd = vec_transform_vector(cd, msn)
         else
            do i = 1_int32, 3_int32
               call compute_snap(cd(i), snap(i))
            enddo
         endif
         delta = (matrix_origin + cd) - model(:, 4)
      endif
      if (any(bits(delta) /= bits(translation_last_delta))) modified = .true.
      translation_last_delta = delta
      matrix = mat_mul(model_source, mat_translation(delta))
      if (.not. core_mouse_down(0_int32)) using = .false.
      type = current_handle_type
   else
      if (over_hotspot) then
         type = MT_NONE
      else
         type = move_type(op)
      endif
      over_hotspot = over_hotspot .or. type /= MT_NONE
      if (type /= MT_NONE) call core_want_capture_mouse()
      if (type /= MT_NONE) then
         if (can_activate()) then
            active_tripod_state = tripod_state
            using = .true.
            editing_id = current_id()
            current_handle_type = type
            mpn(:, 0) = model(:, 1)
            mpn(:, 1) = model(:, 2)
            mpn(:, 2) = model(:, 3)
            mpn(:, 3) = model(:, 1)
            mpn(:, 4) = model(:, 2)
            mpn(:, 5) = model(:, 3)
            mpn(:, 6) = -camera_dir
            cmn = vec_normalized(model(:, 4) - camera_eye)
            do i = 0_int32, 2_int32
               ov = vec_cross(mpn(:, i), cmn)
               mpn(:, i) = vec_cross(mpn(:, i), ov)
               call vec_normalize(mpn(:, i))
            enddo
            translation_plan = build_plan(model(:, 4), mpn(:, type - MT_MOVE_X))
            l = intersect_ray_plane(ray_origin, ray_vector, translation_plan)
            translation_plan_origin = ray_origin + ray_vector * l
            matrix_origin = model(:, 4)
            relative_origin = (translation_plan_origin - model(:, 4)) * (1.0_real32 / screen_factor)
         endif
      endif
   endif
   endfunction handle_translation

   function handle_scale(matrix, op, type, snap, has_snap) result(modified)
   !< `HandleScale`.
   real(real32),   intent(inout) :: matrix(4,4) !< The matrix moved.
   integer(int32), intent(in)    :: op          !< Operation.
   integer(int32), intent(inout) :: type        !< Handle.
   real(real32),   intent(in)    :: snap(3)     !< Snap.
   logical,        intent(in)    :: has_snap    !< Snap given.
   logical                       :: modified    !< Moved.
   real(real32)   :: mpn(4, 0:6), l, np(4), no(4), delta(4), av(4), loa, bv(4), ratio, sdelta !< ImGuizmo's.
   integer(int32) :: ai, i                      !< Axis, counter.

   modified = .false.
   if (iand(op, GZ_SCALE) == 0_int32 .or. type /= MT_NONE .or. .not. mouse_over) return
   if (.not. using) then
      if (over_hotspot) then
         type = MT_NONE
      else
         type = scale_type(op)
      endif
      over_hotspot = over_hotspot .or. type /= MT_NONE
      if (type /= MT_NONE) call core_want_capture_mouse()
      if (type /= MT_NONE) then
         if (can_activate()) then
            active_tripod_state = tripod_state
            using = .true.
            editing_id = current_id()
            current_handle_type = type
            mpn(:, 0) = model_local(:, 2)
            mpn(:, 1) = model_local(:, 3)
            mpn(:, 2) = model_local(:, 1)
            mpn(:, 3) = model_local(:, 3)
            mpn(:, 4) = model_local(:, 2)
            mpn(:, 5) = model_local(:, 1)
            mpn(:, 6) = -camera_dir
            translation_plan = build_plan(model_local(:, 4), mpn(:, type - MT_SCALE_X))
            l = intersect_ray_plane(ray_origin, ray_vector, translation_plan)
            translation_plan_origin = ray_origin + ray_vector * l
            matrix_origin = model_local(:, 4)
            scale = vec(1.0_real32, 1.0_real32, 1.0_real32)
            relative_origin = (translation_plan_origin - model_local(:, 4)) * (1.0_real32 / screen_factor)
            scale_value_origin = vec(vec_length(model_source(:, 1)), vec_length(model_source(:, 2)), &
                                     vec_length(model_source(:, 3)))
            save_mouse_posx = mouse(1)
         endif
      endif
   endif
   if (is_using() .and. current_handle_type >= MT_SCALE_X .and. current_handle_type <= MT_SCALE_XYZ) then
      call core_want_capture_mouse()
      l = intersect_ray_plane(ray_origin, ray_vector, translation_plan)
      np = ray_origin + ray_vector * l
      no = np - relative_origin * screen_factor
      delta = no - model_local(:, 4)
      if (current_handle_type >= MT_SCALE_X .and. current_handle_type <= MT_SCALE_Z) then
         ai = current_handle_type - MT_SCALE_X
         av = model_local(:, ai + 1_int32)
         loa = vec_dot(av, delta)
         delta = av * loa
         bv = translation_plan_origin - model_local(:, 4)
         ratio = vec_dot(av, bv + delta) / vec_dot(av, bv)
         scale(ai + 1_int32) = fmax(ratio, 0.001_real32)
      else
         sdelta = (mouse(1) - save_mouse_posx) * 0.01_real32
         scale = fmax(1.0_real32 + sdelta, 0.001_real32)
      endif
      if (has_snap) then
         do i = 1_int32, 3_int32
            call compute_snap(scale(i), snap(1))
         enddo
      endif
      do i = 1_int32, 3_int32
         scale(i) = fmax(scale(i), 0.001_real32)
      enddo
      if (any(bits(scale_last) /= bits(scale))) modified = .true.
      scale_last = scale
      matrix = mat_mul(mat_scale(scale * scale_value_origin), model_local)
      if (.not. core_mouse_down(0_int32)) then
         using = .false.
         scale = vec(1.0_real32, 1.0_real32, 1.0_real32)
      endif
      type = current_handle_type
   endif
   contains
      pure function fmax(a, b) result(m)
      !< ImGuizmo's `max`: a > b ? a : b.
      real(real32), intent(in) :: a, b !< Values.
      real(real32)             :: m    !< Larger.

      m = b
      if (a > b) m = a
      endfunction fmax
   endfunction handle_scale

   function handle_rotation(matrix, op, type, snap, has_snap) result(modified)
   !< `HandleRotation`.
   real(real32),   intent(inout) :: matrix(4,4) !< The matrix moved.
   integer(int32), intent(in)    :: op          !< Operation.
   integer(int32), intent(inout) :: type        !< Handle.
   real(real32),   intent(in)    :: snap(3)     !< Snap.
   logical,        intent(in)    :: has_snap    !< Snap given.
   logical                       :: modified    !< Moved.
   logical        :: local                      !< applyRotationLocaly.
   real(real32)   :: rpn(4, 0:3), l, lp(4), ral(4), dr(4,4), res(4,4), sir !< ImGuizmo's.

   modified = .false.
   if (iand(op, GZ_ROTATE) == 0_int32 .or. type /= MT_NONE .or. .not. mouse_over) return
   local = g_mode == GZ_LOCAL
   if (.not. using) then
      if (over_hotspot) then
         type = MT_NONE
      else
         type = rotate_type(op)
      endif
      over_hotspot = over_hotspot .or. type /= MT_NONE
      if (type /= MT_NONE) call core_want_capture_mouse()
      if (type == MT_ROTATE_SCREEN) local = .true.
      if (type /= MT_NONE) then
         if (can_activate()) then
            using = .true.
            editing_id = current_id()
            current_handle_type = type
            rpn(:, 0) = model(:, 1)
            rpn(:, 1) = model(:, 2)
            rpn(:, 2) = model(:, 3)
            rpn(:, 3) = -camera_dir
            if (local) then
               translation_plan = build_plan(model(:, 4), rpn(:, type - MT_ROTATE_X))
            else
               translation_plan = build_plan(model_source(:, 4), UNARY(:, type - MT_ROTATE_X))
            endif
            l = intersect_ray_plane(ray_origin, ray_vector, translation_plan)
            lp = (ray_origin + ray_vector * l) - model(:, 4)
            rotation_vector_source = vec_normalized(lp)
            rotation_angle_origin = angle_on_plan()
         endif
      endif
   endif
   if (is_using() .and. current_handle_type >= MT_ROTATE_X .and. current_handle_type <= MT_ROTATE_SCREEN) then
      call core_want_capture_mouse()
      rotation_angle = angle_on_plan()
      if (has_snap) then
         sir = snap(1) * DEG2RAD
         call compute_snap(rotation_angle, sir)
      endif
      ral = vec_transform_vector(vec(translation_plan(1), translation_plan(2), translation_plan(3), 0.0_real32), &
                                 model_inverse)
      call vec_normalize(ral)
      dr = mat_rotation_axis(ral, rotation_angle - rotation_angle_origin)
      if (rotation_angle /= rotation_angle_origin) modified = .true.
      rotation_angle_origin = rotation_angle
      if (local) then
         matrix = mat_mul(mat_mul(mat_scale(model_scale_origin), dr), model_local)
      else
         res = model_source
         res(:, 4) = 0.0_real32
         matrix = mat_mul(res, dr)
         matrix(:, 4) = model_source(:, 4)
      endif
      if (.not. core_mouse_down(0_int32)) then
         using = .false.
         editing_id = -1_int32
      endif
      type = current_handle_type
   endif
   endfunction handle_rotation

   function manipulate(view, proj, op, mode, matrix, snap, has_snap) result(manipulated)
   !< `Manipulate(view, projection, operation, mode, matrix, NULL, snap)`.
   real(real32),   intent(in)    :: view(4,4), proj(4,4) !< Matrices.
   integer(int32), intent(in)    :: op, mode             !< Operation, mode.
   real(real32),   intent(inout) :: matrix(4,4)          !< The matrix moved.
   real(real32),   intent(in)    :: snap(3)              !< Snap.
   logical,        intent(in)    :: has_snap             !< Snap given.
   logical                       :: manipulated          !< Moved.
   real(real32)                  :: csp(4)               !< The model's origin in clip space.
   integer(int32)                :: type, m              !< Handle, mode.

   call core_push_clip_rect(real(rx, real64), real(ry, real64), real(rx + rwidth, real64), real(ry + rheight, real64), &
                            intersect=.false.)
   m = mode
   if (iand(op, GZ_SCALE) /= 0_int32) m = GZ_LOCAL ! scale is always local
   call compute_context(view, proj, matrix, m)
   hovered_handle_type = MT_NONE
   manipulated = .false.
   csp = vec_transform_point(vec(0.0_real32, 0.0_real32, 0.0_real32), mvp)
   if (csp(3) < 0.001_real32 .and. .not. using) return ! behind the camera (ImGuizmo leaves its clip rectangle pushed)
   type = MT_NONE
   if (enabled) then
      manipulated = handle_translation(matrix, op, type, snap, has_snap)
      if (.not. manipulated) manipulated = handle_scale(matrix, op, type, snap, has_snap)
      if (.not. manipulated) manipulated = handle_rotation(matrix, op, type, snap, has_snap)
   endif
   g_operation = op
   hovered_handle_type = MT_NONE
   if (.not. using) hovered_handle_type = type
   call draw_rotation(op, type)
   call draw_translation(op, type)
   call draw_scale(op, type)
   call core_pop_clip_rect()
   endfunction manipulate

   subroutine view_manipulate(view, proj, op, mode, matrix, length, px, py, sx, sy, background)
   !< `ViewManipulate(view, projection, operation, mode, matrix, length, position, size, backgroundColor)`, with
   !< FIGURE's patch 0002.
   real(real32),   intent(inout) :: view(4,4)   !< The camera, turned.
   real(real32),   intent(in)    :: proj(4,4)   !< Projection.
   integer(int32), intent(in)    :: op, mode    !< Operation, mode.
   real(real32),   intent(in)    :: matrix(4,4) !< Model.
   real(real32),   intent(in)    :: length      !< The camera's distance to its target.
   real(real32),   intent(in)    :: px, py      !< The cube's corner [pixels].
   real(real32),   intent(in)    :: sx, sy      !< Its size [pixels].
   integer(int32), intent(in)    :: background  !< Its background colour.
   integer(int32), parameter :: GREY = int(z'80808080', int32)  !< IM_COL32(0x80, 0x80, 0x80, 0x80).
   integer(int32), parameter :: HOVER = int(z'00080808', int32) !< IM_COL32(0x08, 0x08, 0x08, 0).
   real(real32)   :: svg_view(4,4), svg_proj(4,4), vinv(4,4), hs, cam_target(4), fov, cube_proj(4,4), cube_view(4,4) !<
                                                                 !< ImGuizmo's.
   real(real32)   :: dir(4), up(4), eye(4), res(4,4), ivx(4), ivy(4), box_origin(4), n(4), vsn(4), vsp(4), vsfp(4) !< ...
   real(real32)   :: fplan(4), l, pop(4), lx, ly, dx(4), dy(4), origin(4), bc(4), p(2), s(2), pp(4, 4), fcs(2, 4) !< ...
   real(real32)   :: inv_, new_dir(4), new_up(4), new_eye(4), right(4), rxm(4,4), rym(4,4), roll(4,4), plan_dir(4), dt !<
   real(real32)   :: md(2), ms(4,4)                              !< io.MouseDelta, mModelSource.
   integer(int32) :: mo                                          !< mMode.
   real(real64)   :: ddx, ddy, wheel, wheel_h, drag(5), xs(4), ys(4) !< io, a face for figure_core.
   real(real32), parameter :: REF_UP(4) = [0.0_real32, 1.0_real32, 0.0_real32, 0.0_real32] !< referenceUp.
   integer(int32) :: k, pass, face, ni, px_, py_, panel, bci, cx, cy, cz, mods, col, c !< Counters, ImGuizmo's.
   logical        :: hovered, right_handed, boxes(0:26), inside, dnd, down !< ImGuizmo's.

   if (iand(op, GZ_SCALE) /= 0_int32) then
      call compute_context(view, proj, matrix, GZ_LOCAL)
   else
      call compute_context(view, proj, matrix, mode)
   endif
   k = cube_state()
   mouse_over = hovering_window()
   svg_view = view_mat
   svg_proj = proj_mat
   hovered = mouse_over .and. mouse(1) >= px .and. mouse(2) >= py .and. mouse(1) < px + sx .and. mouse(2) < py + sy
   call core_draw_rect_filled(real(px, real64), real(py, real64), real(px + sx, real64), real(py + sy, real64), background)
   vinv = mat_inverse(view)
   right_handed = proj_mat(4, 3) < 0.0_real32
   hs = merge(1.0_real32, -1.0_real32, right_handed)
   cam_target = vinv(:, 4) - (vinv(:, 3) * hs) * length
   fov = c_acosf(3.0_real32 / (sqrt(3.0_real32 * 3.0_real32 + 3.0_real32))) * RAD2DEG
   cube_proj = perspective(fov / sqrt(2.0_real32), sx / sy, 0.01_real32, 1000.0_real32, right_handed)
   dir = vec(vinv(1, 3), vinv(2, 3), vinv(3, 3))
   up = vec(vinv(1, 2), vinv(2, 2), vinv(3, 2))
   eye = (dir * hs) * 3.0_real32
   cube_view = look_at(eye(1:3), [0.0_real32, 0.0_real32, 0.0_real32], up(1:3), right_handed)
   view_mat = cube_view
   proj_mat = cube_proj
   call camera_ray(ray_origin, ray_vector, view_mat, proj_mat, mouse(1), mouse(2), px, py, sx, sy)
   res = mat_mul(cube_view, cube_proj)
   boxes = .false.
   down = core_mouse_down(0_int32)
   do pass = 0_int32, 1_int32
      do face = 0_int32, 5_int32
         ni = mod(face, 3_int32)
         px_ = mod(ni + 1_int32, 3_int32)
         py_ = mod(ni + 2_int32, 3_int32)
         inv_ = 1.0_real32
         if (face > 2_int32) inv_ = -1.0_real32
         ivx = UNARY(:, px_) * inv_
         ivy = UNARY(:, py_) * inv_
         box_origin = ((UNARY(:, ni) * (-inv_)) - ivx) - ivy
         n = UNARY(:, ni) * inv_
         vsn = vec_transform_vector(n, cube_view)
         call vec_normalize(vsn)
         vsp = vec_transform_point(n * 0.5_real32, cube_view)
         vsfp = build_plan(vsp, vsn)
         if (vsfp(4) > 0.0_real32) cycle ! back face culling
         fplan = build_plan(n * 0.5_real32, n)
         l = intersect_ray_plane(ray_origin, ray_vector, fplan)
         pop = (ray_origin + ray_vector * l) - (n * 0.5_real32)
         lx = vec_dot(UNARY(:, px_), pop) * inv_ + 0.5_real32
         ly = vec_dot(UNARY(:, py_), pop) * inv_ + 0.5_real32
         dx = UNARY(:, px_)
         dy = UNARY(:, py_)
         origin = (UNARY(:, ni) - dx) - dy
         do panel = 0_int32, 8_int32
            bc = ((box_origin + ivx * real(mod(panel, 3_int32), real32)) + ivy * real(panel / 3_int32, real32)) + &
                 vec(1.0_real32, 1.0_real32, 1.0_real32)
            p = PANEL_POSITION(:, panel) * 2.0_real32
            s = PANEL_SIZE(:, panel) * 2.0_real32
            pp(:, 1) = dx * p(1) + dy * p(2)
            pp(:, 2) = dx * p(1) + dy * (p(2) + s(2))
            pp(:, 3) = dx * (p(1) + s(1)) + dy * (p(2) + s(2))
            pp(:, 4) = dx * (p(1) + s(1)) + dy * p(2)
            do c = 1_int32, 4_int32
               call world_to_pos(((pp(:, c) + origin) * 0.5_real32) * inv_, res, fcs(:, c), [px, py], [sx, sy])
            enddo
            inside = lx > PANEL_POSITION(1, panel) .and. lx < PANEL_POSITION(1, panel) + PANEL_SIZE(1, panel) .and. &
                     ly > PANEL_POSITION(2, panel) .and. ly < PANEL_POSITION(2, panel) + PANEL_SIZE(2, panel)
            bci = int((bc(1) * 9.0_real32 + bc(2) * 3.0_real32) + bc(3), int32)
            boxes(bci) = boxes(bci) .or. (inside .and. .not. cube_states(k)%dragging .and. mouse_over)
            if (pass == 1_int32) then
               col = ior(color_u32(DIRECTION_X + ni), GREY)
               if (hovered) col = ior(col, HOVER)
               xs = real(fcs(1, :), real64)
               ys = real(fcs(2, :), real64)
               call core_draw_convex_poly_filled(xs, ys, col)
               if (boxes(bci)) then
                  call core_draw_convex_poly_filled(xs, ys, color_u32(SELECTION))
                  if (down .and. .not. cube_states(k)%clicking .and. .not. cube_states(k)%dragging .and. &
                      core_active_id() == 0_int32) then
                     over_box = bci
                     cube_states(k)%clicking = .true.
                     cube_states(k)%dragging = .true.
                  endif
               endif
            endif
         enddo
      enddo
   enddo
   if (cube_states(k)%frames /= 0_int32) then
      cube_states(k)%frames = cube_states(k)%frames - 1_int32
      new_dir = vinv(:, 3) * hs
      call vec_lerp(new_dir, cube_states(k)%dir * hs, 0.2_real32)
      call vec_normalize(new_dir)
      if (cube_states(k)%frames == 0_int32) new_dir = cube_states(k)%dir * hs ! FIGURE's patch 0002
      new_up = cube_states(k)%up
      new_eye = cam_target + new_dir * length
      view = look_at(new_eye(1:3), cam_target(1:3), new_up(1:3), right_handed)
   endif
   view_manipulator_hovered = view_manipulator_hovered .or. hovered
   call core_io_input(ddx, ddy, wheel, wheel_h, drag, mods, dnd)
   md = [real(ddx, real32), real(ddy, real32)]
   if (down .and. (md(1) /= 0.0_real32 .or. md(2) /= 0.0_real32) .and. cube_states(k)%clicking) &
      cube_states(k)%clicking = .false.
   if (.not. down) then
      if (cube_states(k)%clicking) then ! the new view direction
         cx = over_box / 9_int32
         cy = (over_box - cx * 9_int32) / 3_int32
         cz = mod(over_box, 3_int32)
         cube_states(k)%dir = vec(1.0_real32 - real(cx, real32), 1.0_real32 - real(cy, real32), &
                                  1.0_real32 - real(cz, real32)) * hs
         call vec_normalize(cube_states(k)%dir)
         if (abs(vec_dot(cube_states(k)%dir, REF_UP)) > 1.0_real32 - 0.01_real32) then
            right = vinv(:, 1)
            if (abs(right(1)) > abs(right(3))) then
               right(3) = 0.0_real32
            else
               right(1) = 0.0_real32
            endif
            call vec_normalize(right)
            cube_states(k)%up = vec_cross(cube_states(k)%dir * hs, right)
            call vec_normalize(cube_states(k)%up)
         else
            cube_states(k)%up = REF_UP
         endif
         cube_states(k)%frames = 40_int32
      endif
      cube_states(k)%clicking = .false.
      cube_states(k)%dragging = .false.
   endif
   if (cube_states(k)%dragging) then
      rxm = mat_rotation_axis(REF_UP, ((-md(1)) * 0.01_real32) * hs)
      rym = mat_rotation_axis(vinv(:, 1), ((-md(2)) * 0.01_real32) * hs)
      roll = mat_mul(rxm, rym)
      new_dir = vec_transform_vector(vinv(:, 3), roll)
      call vec_normalize(new_dir)
      plan_dir = vec_cross(vinv(:, 1), REF_UP)
      plan_dir(2) = 0.0_real32
      call vec_normalize(plan_dir)
      dt = vec_dot(plan_dir, new_dir)
      if (dt < 0.0_real32) then
         new_dir = new_dir + plan_dir * dt
         call vec_normalize(new_dir)
      endif
      new_eye = cam_target + (new_dir * hs) * length
      view = look_at(new_eye(1:3), cam_target(1:3), REF_UP(1:3), right_handed)
   endif
   using_view_manipulate = using_view_manipulate .or. (cube_states(k)%frames /= 0_int32 .or. cube_states(k)%dragging)
   if (cube_states(k)%clicking .or. cube_states(k)%frames /= 0_int32 .or. cube_states(k)%dragging .or. hovered) &
      call core_want_capture_mouse()
   ms = model_source
   mo = g_mode
   call compute_context(svg_view, svg_proj, ms, mo) ! the view and projection restored
   endsubroutine view_manipulate

   function cube_state() result(k)
   !< `GetViewManipulateState`: the state of the current ID's cube, created on its first use.
   integer(int32)                  :: k     !< Its index.
   integer(int32)                  :: id    !< Current ID.
   type(cube_state_t), allocatable :: more(:) !< Grown.

   id = current_id()
   do k = 1_int32, n_cube_states
      if (cube_states(k)%id == id) return
   enddo
   if (.not. allocated(cube_states)) allocate(cube_states(4))
   if (n_cube_states == size(cube_states, kind=int32)) then
      allocate(more(2_int32 * n_cube_states))
      more(1:n_cube_states) = cube_states
      call move_alloc(more, cube_states)
   endif
   n_cube_states = n_cube_states + 1_int32
   k = n_cube_states
   cube_states(k) = cube_state_t(id=id)
   endfunction cube_state
endmodule figure_gizmo
