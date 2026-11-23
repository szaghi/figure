!< figure_test_plot_frame_3d_alloc, the Fortran 3-D frame draws a frame without a heap allocation.
program figure_test_plot_frame_3d_alloc
!< figure_test_plot_frame_3d_alloc, the Fortran 3-D frame draws a frame without a heap allocation.
!<
!< szaghi/figure#15 P13 (ADR 0001: no allocation per item per frame in the plot frame), as figure_test_plot_frame_alloc
!< for the 2-D frame, its counter (figure_test_plot_alloc_counter) reused. A 3-D plot with every per-frame string of
!< the frame so far: a title with a hidden part, three axis labels, the ticks' labels of three axes, an inverted axis,
!< a scaled box, a rotation; (step 4) a line with per-point colours, a scatter with per-point colours and sizes, a line
!< with markers, their legend. Drawn first by ImPlot3D through FIGURE's API (`ip3_*`), then by the Fortran frame
!< (`pf3_*`), NF frames each: on the Fortran side the last NCOUNT frames are counted, from `pf3_begin_plot` to
!< `pf3_end_plot`, and must make none. Checks:
!<
!< 1. no allocation on the counted frames (the stacks of the first ones are printed on standard error);
!< 2. the counter sees allocations: an ALLOCATE and a character concatenation of run-time length, counted;
!< 3. the pictures of the last frame of both sides equal at FIGURE's oracle rule (|d| <= 2, no pixel failing).
!<
!< The pictures are `figure_test_plot_frame_3d_alloc.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ip3_begin_plot, ip3_end_plot, &
                   ip3_setup_axes, ip3_setup_axis, ip3_setup_box, ip3_line, ip3_scatter, ip3_spec,                &
                   ImGuiWindowFlags_NoDecoration
use figure_plot3d_frame, only : pf3_begin_plot, pf3_end_plot, pf3_setup_axes, pf3_setup_axis, pf3_setup_box
use figure_plot3d_items, only : pf3_line, pf3_scatter, pf3_spec
use figure_testing, only : test_capture, test_compare_image, test_mouse_move
use figure_test_plot_alloc_counter, only : alloc_arm, alloc_count, alloc_disarm

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 480_int32      !< Display height [pixels].
integer(int32), parameter :: NF = 20_int32      !< Frames per side.
integer(int32), parameter :: NCOUNT = 10_int32  !< The last frames counted.
real(real64),   parameter :: LIM(6) = [-3.0_real64, 3.0_real64, 0.0_real64, 100.0_real64, -1.0_real64, 1.0_real64] !<
                                                !< Limits.
real(real64),   parameter :: BOX(3) = [1.0_real64, 1.5_real64, 0.75_real64] !< Box scale.
integer(int32), parameter :: NP = 60_int32      !< Points.
type(app_object)          :: app                !< Application.
real(real64)              :: x(NP), y(NP), z(NP), zh(NP), xh(NP), cols(4, NP), sizes(NP) !< The items (named
                                                !< arrays: nvfortran allocates an expression's temporary).
integer(int64)            :: counted            !< Allocations on the counted frames.
integer(int64)            :: control            !< Allocations of the control.
logical                   :: test_passed(3)     !< Per-check outcome.
logical                   :: side_fortran       !< Drawing with the Fortran frame.
integer(int32)            :: f, s, sd, i        !< Frame, status, side, counter.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do i = 1_int32, NP
   x(i) = 2.5_real64 * cos(real(i, real64) * 0.2_real64)
   y(i) = 50.0_real64 + 40.0_real64 * sin(real(i, real64) * 0.2_real64)
   z(i) = -1.0_real64 + real(i, real64) / real(NP, real64) * 2.0_real64
   zh(i) = z(i) * 0.5_real64
   xh(i) = x(i) * 0.5_real64
   cols(1, i) = real(i, real64) / real(NP, real64)
   cols(2, i) = 0.6_real64
   cols(3, i) = 0.3_real64
   cols(4, i) = 1.0_real64
   sizes(i) = 2.0_real64 + mod(real(i, real64), 4.0_real64)
enddo
counted = 0_int64
do sd = 1_int32, 2_int32 ! 1 ImPlot3D, 2 the Fortran frame
   side_fortran = sd == 2_int32
   do f = 1_int32, NF
      if (.not. app%next_frame()) error stop 'figure_test_plot_frame_3d_alloc: next_frame returned false headless'
      call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
      if (ig_begin('plot frame 3d alloc', flags=ImGuiWindowFlags_NoDecoration)) &
         call draw(f > NF - NCOUNT .and. side_fortran)
      call ig_end()
      if (f == NF) call test_capture(picture(side_fortran), s)
   enddo
   do i = 1_int32, 40_int32 ! as the other frame tests: the sides apart
      if (.not. app%next_frame()) error stop 'figure_test_plot_frame_3d_alloc: next_frame returned false headless'
   enddo
enddo
control = control_count()
call app%destroy()
test_passed(1) = counted == 0_int64
test_passed(2) = control > 0_int64
test_passed(3) = pictures_equal()
if (.not. test_passed(1)) write(output_unit, '(A,I0,A,I0,A)') 'allocations on the ', NCOUNT, ' counted frames: ', &
                                                             counted, ' (stacks on standard error)'
if (.not. test_passed(2)) write(output_unit, '(A)') 'the counter saw no allocation of the control'
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_3d_alloc checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine draw(count)
   !< The 3-D plot, by the side drawing; `count`: the frame's allocations counted.
   logical, intent(in) :: count !< Count.

   if (count) call alloc_arm()
   if (side_fortran) then
      if (pf3_begin_plot('Allocations##alloc3', width=600.0_real64, height=440.0_real64)) then
         call pf3_setup_axes('x', 'y', 'z', limits=LIM, elevation=25.0_real64, azimuth=-40.0_real64)
         call pf3_setup_axis('y', label='y (inverted)', invert=.true.)
         call pf3_setup_box(scale=BOX)
         call pf3_line('wave', x, y, z, colors=cols)
         call pf3_scatter('dots', x(::3), y(::3), zh(::3), colors=cols(:, ::3), sizes=sizes(::3))
         call pf3_line('marked', xh(1:20), y(1:20), z(1:20), spec=pf3_spec(marker=2_int32))
         call pf3_end_plot()
      endif
   else
      if (ip3_begin_plot('Allocations##alloc3', width=600.0_real64, height=440.0_real64)) then
         call ip3_setup_axes('x', 'y', 'z', limits=LIM, elevation=25.0_real64, azimuth=-40.0_real64)
         call ip3_setup_axis('y', label='y (inverted)', invert=.true.)
         call ip3_setup_box(scale=BOX)
         call ip3_line('wave', x, y, z, colors=cols)
         call ip3_scatter('dots', x(::3), y(::3), zh(::3), colors=cols(:, ::3), sizes=sizes(::3))
         call ip3_line('marked', xh(1:20), y(1:20), z(1:20), spec=ip3_spec(marker=2_int32))
         call ip3_end_plot()
      endif
   endif
   if (count) then
      call alloc_disarm()
      counted = counted + alloc_count()
   endif
   endsubroutine draw

   function control_count() result(n)
   !< The allocations the counter sees of an ALLOCATE and of a concatenation of run-time length.
   integer(int64)                :: n    !< Allocations.
   real(real64),     allocatable :: a(:) !< An array.
   character(len=:), allocatable :: t    !< A text.
   integer(int32)                :: k    !< Its length.

   k = 200_int32 + int(LIM(2), int32) ! run-time enough
   call alloc_arm()
   allocate(a(k))
   a = 1.0_real64
   t = repeat('x', k)//'y'
   call alloc_disarm()
   n = alloc_count()
   if (len(t) /= k + 1_int32 .or. a(k) /= 1.0_real64) n = -1_int64 ! used: not optimised away
   endfunction control_count

   function pictures_equal() result(ok)
   !< Both sides' pictures equal at the oracle's rule.
   logical        :: ok  !< Equal.
   integer(int64) :: nf_ !< Pixels that failed.
   integer(int32) :: st  !< Status.

   ok = test_compare_image(picture(.true.), picture(.false.), threshold=2_int32, max_failed=0_int32, failed=nf_, &
                           stat=st)
   if (.not. ok) write(output_unit, '(A,I0,A,A)') 'pictures: ', nf_, ' pixels failed: ', figure_last_error()
   endfunction pictures_equal

   function picture(fortran) result(name)
   !< The picture of ImPlot3D's side or the Fortran frame's.
   logical,          intent(in)  :: fortran !< The Fortran frame's.
   character(len=:), allocatable :: name    !< File name.

   if (fortran) then
      name = 'figure_test_plot_frame_3d_alloc.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_3d_alloc.implot3d.png.tmp'
   endif
   endfunction picture

   subroutine remove_files()
   !< The pictures (a mismatch's .new.png and .diff.png are left for inspection).
   integer(int32) :: unit, ios, m !< Unit, status, side.

   do m = 1_int32, 2_int32
      open(newunit=unit, file=picture(m == 1_int32), status='old', iostat=ios)
      if (ios == 0) close(unit, status='delete')
   enddo
   endsubroutine remove_files
endprogram figure_test_plot_frame_3d_alloc
