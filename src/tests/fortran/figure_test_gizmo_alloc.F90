!< figure_test_gizmo_alloc, the Fortran path's view cube, gizmos and gradient editor draw a frame without a heap allocation.
program figure_test_gizmo_alloc
!< figure_test_gizmo_alloc, the Fortran path's view cube, gizmos and gradient editor draw a frame without a heap allocation.
!<
!< szaghi/figure#15 P14 (ADR 0001: no allocation per item per frame), with figure_test_plot_frame_alloc's counter
!< (figure_test_plot_alloc_counter). A 3-D view with its view cube and three gizmos (translate, rotate with a snap,
!< scale) and a gradient editor, through FIGURE's API on the Fortran path (`v%view_cube`, `v%gizmo`, `ig_gradient_edit`),
!< the pointer driving them: the translate gizmo's centre dragged, the scale gizmo's centre dragged, a drag on the view
!< cube, a click on it (its 40-frame turn), the pointer over the gradient's stops. All but the first frames are counted
!< around those calls (not around `v%draw`: the view's native rasterizer is not P14's) and must make none. Checks:
!<
!< 1. no allocation on the counted frames (the stacks of the first ones are printed on standard error);
!< 2. the counter sees allocations: an ALLOCATE, counted.
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, ig_begin, ig_end, ig_gradient_edit, ig_item_rect, ig_set_next_window, ig_text, view3d_object, &
                   ImGuiWindowFlags_NoDecoration
use figure_testing, only : test_mouse_button, test_mouse_move
use figure_test_plot_alloc_counter, only : alloc_arm, alloc_count, alloc_disarm

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 640_int32      !< Display height [pixels].
integer(int32), parameter :: NF = 90_int32      !< Frames.
integer(int32), parameter :: NCOUNT = 86_int32  !< Frames counted (the last ones).
type(app_object)          :: app                !< Application.
type(view3d_object)       :: v                  !< The view.
real(real64), target      :: cube_xyz(3, 8)     !< Cube's vertices.
integer(int32), target    :: cube_quads(4, 6)   !< Cube's faces.
real(real64)              :: m1(4, 4), m2(4, 4), m3(4, 4) !< The gizmos' matrices.
logical                   :: test_passed(2)     !< Per-check outcome.
integer(int64)            :: counted            !< Allocations counted.
integer(int32)            :: f, i, mesh         !< Frame, counter, mesh.
real(real64)              :: x0, y0, x1, y1     !< The view's rectangle.
real(real64)              :: sc(2)              !< The scale gizmo's centre [pixels].
real(real64)              :: vm(4, 4), pm(4, 4), e(4) !< The view's matrices, a point.
logical                   :: moved              !< A result.

cube_xyz = reshape([-1, -1, -1,  1, -1, -1,  1, 1, -1,  -1, 1, -1, &
                    -1, -1,  1,  1, -1,  1,  1, 1,  1,  -1, 1,  1], [3, 8]) * 1.0_real64
cube_quads = reshape([1, 2, 3, 4,  5, 6, 7, 8,  1, 2, 6, 5,  2, 3, 7, 6,  3, 4, 8, 7,  4, 1, 5, 8], [4, 6])
call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
call v%init(lighting=.false.)
mesh = v%quads(cube_xyz, cube_quads, color=[0.8_real64, 0.6_real64, 0.2_real64], edges=.true.)
call v%set_camera(target=[0.0_real64, 0.0_real64, 0.0_real64], distance=8.0_real64, azimuth=30.0_real64, &
                  elevation=20.0_real64)
m1 = 0.0_real64
do i = 1_int32, 4_int32
   m1(i, i) = 1.0_real64
enddo
m2 = m1
m3 = m1
m2(1:3, 4) = [1.5_real64, 0.0_real64, 0.0_real64]
m3(1:3, 4) = [-1.5_real64, 0.0_real64, 0.0_real64]
counted = 0_int64
do f = 1_int32, NF
   if (.not. app%next_frame()) error stop 'figure_test_gizmo_alloc: next_frame returned false headless'
   call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
   if (ig_begin('gizmo alloc', flags=ImGuiWindowFlags_NoDecoration)) then
      call ig_text('XYZ : -0123456789. deg rad Screen') ! the information texts' glyphs baked before the count (Dear
                                                        ! ImGui allocates a glyph at its first use)
      call v%draw('view', 400.0_real64, 400.0_real64)
      call ig_item_rect(x0, y0, x1, y1)
      if (f > NF - NCOUNT) call alloc_arm()
      call v%view_cube()
      moved = v%gizmo('t', m1, mode='translate')
      moved = v%gizmo('r', m2, mode='rotate', snap=15.0_real64)
      moved = v%gizmo('s', m3, mode='scale', space='local')
      moved = ig_gradient_edit('##g', 'Viridis', width=400.0_real64)
      if (f > NF - NCOUNT) then
         call alloc_disarm()
         counted = counted + alloc_count()
      endif
   endif
   call ig_end()
   if (f == 1_int32) then ! the scale gizmo's centre
      call v%view_matrix(vm)
      call v%projection_matrix(pm)
      e = matmul(pm, matmul(vm, [-1.5_real64, 0.0_real64, 0.0_real64, 1.0_real64]))
      sc = [x0 + (e(1) / e(4) * 0.5_real64 + 0.5_real64) * (x1 - x0), y0 + (0.5_real64 - e(2) / e(4) * 0.5_real64) * (y1 - y0)]
   endif
   select case (f)
   case (3_int32) ! the translate gizmo's centre dragged
      call test_mouse_move(0.5_real64 * (x0 + x1), 0.5_real64 * (y0 + y1))
   case (5_int32)
      call test_mouse_button(.true.)
   case (7_int32:20_int32)
      call test_mouse_move(0.5_real64 * (x0 + x1) + real(mod(f, 5_int32), real64), 0.5_real64 * (y0 + y1) + 2.0_real64)
   case (21_int32)
      call test_mouse_button(.false.)
   case (23_int32) ! the scale gizmo's centre dragged
      call test_mouse_move(sc(1), sc(2))
   case (25_int32)
      call test_mouse_button(.true.)
   case (27_int32:34_int32)
      call test_mouse_move(sc(1) + 3.0_real64 * real(f - 26_int32, real64), sc(2))
   case (35_int32)
      call test_mouse_button(.false.)
   case (37_int32) ! a drag on the view cube (top-right, 96 pixels)
      call test_mouse_move(x1 - 48.0_real64, y0 + 48.0_real64)
   case (39_int32)
      call test_mouse_button(.true.)
   case (41_int32:46_int32)
      call test_mouse_move(x1 - 48.0_real64 + 4.0_real64 * real(f - 40_int32, real64), y0 + 48.0_real64)
   case (47_int32)
      call test_mouse_button(.false.)
   case (48_int32) ! a click on it
      call test_mouse_move(x1 - 48.0_real64, y0 + 48.0_real64)
   case (50_int32)
      call test_mouse_button(.true.)
   case (51_int32)
      call test_mouse_button(.false.)
   case (52_int32) ! over the gradient's stops
      call test_mouse_move(x0 + 12.0_real64, y1 + 60.0_real64)
   endselect
enddo
test_passed(1) = counted == 0_int64
if (.not. test_passed(1)) write(output_unit, '(A,I0,A)') 'allocations on the counted frames: ', counted
test_passed(2) = control() > 0_int64
call v%destroy()
call app%destroy()

write(output_unit, '(A,*(L2))') 'figure_test_gizmo_alloc checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   function control() result(n)
   !< The allocations the counter sees of an ALLOCATE.
   integer(int64)            :: n    !< Allocations counted.
   real(real64), allocatable :: a(:) !< Array.

   call alloc_arm()
   allocate(a(1000))
   a = 1.0_real64
   call alloc_disarm()
   n = alloc_count()
   if (a(1) < 0.0_real64) n = -1_int64
   endfunction control
endprogram figure_test_gizmo_alloc
