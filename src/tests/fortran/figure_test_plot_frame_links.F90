!< figure_test_plot_frame_links, the Fortran plot frame's axes linked across plots (`pf_link_axis`), as ImPlot's.
program figure_test_plot_frame_links
!< figure_test_plot_frame_links, the Fortran plot frame's axes linked across plots (`pf_link_axis`), as ImPlot's.
!<
!< szaghi/figure#15 P12, step 2. Each case is drawn on a few frames, first by ImPlot through FIGURE's API
!< (`ip_link_axis`, FIGURE's group over ImPlot's `SetupAxisLinks`), then by the Fortran frame (`pf_link_axis`), with
!< the same synthetic input at the same frames, 40 frames apart. Checked on every frame: each plot's X1, Y1 (and Y2)
!< ranges and the pixels of its plot area's corners, equal to the bit; pictures at FIGURE's oracle rule (|d| <= 2, no
!< pixel failing). The cases:
!<
!< 1. three stacked plots, x linked in one group, their data of different extents: on the first frame each fits its
!<    own, then the three share the first plot's range; the wheel over the third zooms the three;
!< 2. two plots' Y2 linked (their X1 not): a drag over the second plot's Y2 labels pans both Y2;
!< 3. a group whose first plot is drawn on the first frame only: the second plot takes its range on the next frame;
!< 4. two plots linked on X1 and Y2 for four frames, then no longer linked, a pan in the second: X1 apart at once, Y2
!<    still pushing its range to the group (ImPlot keeps an X2..Y3 link: the current path's behaviour, mirrored).
!<
!< The pictures are `figure_test_plot_frame_links.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them; a
!< mismatch's .new.png and .diff.png are left for inspection).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ip_begin_plot, ip_end_plot, &
                   ip_line, ip_link_axis, ip_plot_limits, ip_plot_to_pixels, ip_set_axes, ip_setup_axis, ip_spec,   &
                   ImGuiWindowFlags_NoDecoration
use figure_plot_frame, only : pf_begin_plot, pf_end_plot, pf_link_axis, pf_plot_limits, pf_plot_to_pixels, &
                              pf_set_axes, pf_setup_axis
use figure_plot_items, only : pf_line, pf_spec
use figure_testing, only : test_capture, test_compare_image, test_drag, test_mouse_move, test_wheel

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 640_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 4_int32    !< Cases.
integer(int32), parameter :: NFMAX = 12_int32   !< Frames per side of a case at most.
integer(int32), parameter :: NP = 201_int32     !< Points of a line.
integer(int32), parameter :: NPLOT = 3_int32    !< Plots of a case at most.
integer(int32), parameter :: NV = 10_int32      !< Values per plot: X1, Y1 ranges, corners, Y2's range.
integer(int32), parameter :: NSTATE = NV * NPLOT !< Values checked per frame.
real(real64),   parameter :: C1(4) = [0.91_real64, 0.40_real64, 0.30_real64, 1.0_real64] !< A colour.
real(real64),   parameter :: C2(4) = [0.30_real64, 0.62_real64, 0.85_real64, 1.0_real64] !< Another.
type(app_object)          :: app                !< Application.
real(real64)              :: xs(NP), ys(NP, 4)  !< The lines.
real(real64)              :: state(NSTATE, NFMAX, 2) !< Per frame and side.
logical                   :: test_passed(NCASE) !< Per-case outcome.
logical                   :: side_fortran       !< Drawing with the Fortran frame.
integer(int32)            :: c, f, s, sd, i     !< Case, frame, status, side, counter.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do i = 1_int32, NP
   xs(i) = real(i - 1_int32, real64) * 0.05_real64
   ys(i, 1) = sin(xs(i))
   ys(i, 2) = 10.0_real64**(0.6_real64 * xs(i))
   ys(i, 3) = 0.6_real64 * cos(1.3_real64 * xs(i))
   ys(i, 4) = 100.0_real64 * sin(0.5_real64 * xs(i))
enddo
do c = 1_int32, NCASE
   state = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
      side_fortran = sd == 2_int32
      do f = 1_int32, nframes(c)
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_links: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame links', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(c, f)
         call ig_end()
         if (captured(c, f) > 0_int32) call test_capture(picture(c, captured(c, f), side_fortran), s)
         call pointer(c, f)
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      do i = 1_int32, 40_int32 ! past Dear ImGui's double-click time: the other side's clicks are not a pair
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_links: next_frame returned false headless'
      enddo
   enddo
   test_passed(c) = state_equal(c)
   do i = 1_int32, 2_int32
      if (any(captured_frames(c) == i)) test_passed(c) = pictures_equal(c, i) .and. test_passed(c)
   enddo
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_links checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   pure function nframes(k) result(n)
   !< A case's frames per side.
   integer(int32), intent(in) :: k !< Case.
   integer(int32)             :: n !< Frames.

   select case (k)
   case (3_int32)
      n = 6_int32
   case (1_int32)
      n = 10_int32
   case default
      n = 12_int32
   endselect
   endfunction nframes

   pure function captured(k, fr) result(n)
   !< The picture taken on a frame (0: none, 1: the last frame's, 2: the first frame's).
   integer(int32), intent(in) :: k, fr !< Case, frame.
   integer(int32)             :: n     !< Picture.

   n = 0_int32
   if (fr == nframes(k)) n = 1_int32
   if (fr == 1_int32) n = 2_int32
   endfunction captured

   pure function captured_frames(k) result(n)
   !< The pictures a case takes.
   integer(int32), intent(in) :: k    !< Case.
   integer(int32)             :: n(2) !< Pictures.

   n = [1_int32, 2_int32]
   if (k < 0_int32) n(2) = 0_int32
   endfunction captured_frames

   function pix(k, j, fr) result(v)
   !< A pixel of ImPlot's plot k on frame fr: j 1, 2 the corner (x min, y max), 3, 4 the corner (x max, y min).
   integer(int32), intent(in) :: k, j, fr !< Plot, coordinate, frame.
   real(real64)               :: v        !< Pixel.

   v = state(NV * (k - 1_int32) + 4_int32 + j, fr, 1)
   endfunction pix

   subroutine pointer(k, fr)
   !< A case's input on a frame, the same on both sides (the targets from ImPlot's side's first frame).
   integer(int32), intent(in) :: k, fr !< Case, frame.
   real(real64)               :: x, y  !< A target.

   select case (k)
   case (1_int32) ! the wheel over the third plot
      x = real(nint(0.5_real64 * (pix(3, 1, 1) + pix(3, 3, 1))), real64)
      y = real(nint(0.5_real64 * (pix(3, 2, 1) + pix(3, 4, 1))), real64)
      if (fr == 4_int32) call test_mouse_move(x, y)
      if (fr == 5_int32 .or. fr == 7_int32) call test_wheel(1.0_real64)
      if (fr == 8_int32) call away()
   case (2_int32) ! a drag over the second plot's Y2 labels
      x = real(nint(pix(2, 3, 1) + 20.0_real64), real64)
      y = real(nint(0.5_real64 * (pix(2, 2, 1) + pix(2, 4, 1))), real64)
      if (fr == 3_int32) call test_drag(x, y, x, y + 50.0_real64)
      if (fr == 10_int32) call away()
   case (4_int32) ! a pan in the second plot, after the links stopped
      x = real(nint(0.5_real64 * (pix(2, 1, 1) + pix(2, 3, 1))), real64)
      y = real(nint(0.5_real64 * (pix(2, 2, 1) + pix(2, 4, 1))), real64)
      if (fr == 5_int32) call test_drag(x, y, x - 70.0_real64, y + 30.0_real64)
      if (fr == 11_int32) call away()
   case default
   endselect
   endsubroutine pointer

   subroutine away()
   !< The pointer away from the window.

   call test_mouse_move(-100.0_real64, -100.0_real64)
   endsubroutine away

   subroutine draw_case(k, fr)
   !< A case's plots on a frame, by the side drawing.
   integer(int32), intent(in) :: k, fr !< Case, frame.
   integer(int32)             :: j     !< Plot.

   select case (k)
   case (1_int32)
      do j = 1_int32, 3_int32
         if (pbegin(j, 'it', 190.0_real64)) then
            call link('x1', 'it')
            call line(min(100_int32 * j, NP), merge(1_int32, j + 1_int32, j == 1_int32))
            call pend(j, fr, .false.)
         endif
      enddo
   case (2_int32)
      do j = 1_int32, 2_int32
         if (pbegin(j, 'y2', 280.0_real64)) then
            call axis('y2')
            call link('y2', 'y2 group')
            call line(NP, 1_int32)
            call axes_y2()
            call line(NP, merge(2_int32, 4_int32, j == 1_int32))
            call pend(j, fr, .true.)
         endif
      enddo
   case (3_int32)
      do j = 1_int32, 2_int32
         if (j == 1_int32 .and. fr > 1_int32) cycle
         if (pbegin(j, 'gone', 280.0_real64)) then
            call link('x1', 'gone')
            call line(100_int32 * j, 3_int32)
            call pend(j, fr, .false.)
         endif
      enddo
   case default
      do j = 1_int32, 2_int32
         if (pbegin(j, 'u3', 280.0_real64)) then
            call axis('y2')
            if (fr <= 4_int32) then
               call link('x1', 'u3x')
               call link('y2', 'u3y')
            endif
            call line(80_int32 * j, 1_int32)
            call axes_y2()
            call line(80_int32 * j, 4_int32)
            call pend(j, fr, .true.)
         endif
      enddo
   endselect
   endsubroutine draw_case

   function pbegin(j, prefix, height) result(visible)
   !< `ip_begin_plot` or `pf_begin_plot` of a case's j-th plot, 600 pixels wide.
   integer(int32),   intent(in) :: j       !< Plot.
   character(len=*), intent(in) :: prefix  !< The case's prefix.
   real(real64),     intent(in) :: height  !< Height.
   logical                      :: visible !< Plot visible.

   if (side_fortran) then
      visible = pf_begin_plot('##'//prefix//achar(48_int32 + j), width=600.0_real64, height=height)
   else
      visible = ip_begin_plot('##'//prefix//achar(48_int32 + j), width=600.0_real64, height=height)
   endif
   endfunction pbegin

   subroutine axis(name)
   !< `ip_setup_axis` or `pf_setup_axis`.
   character(len=*), intent(in) :: name !< Axis.

   if (side_fortran) then
      call pf_setup_axis(name)
   else
      call ip_setup_axis(name)
   endif
   endsubroutine axis

   subroutine link(name, group)
   !< `ip_link_axis` or `pf_link_axis`.
   character(len=*), intent(in) :: name, group !< Axis, group.

   if (side_fortran) then
      call pf_link_axis(name, group)
   else
      call ip_link_axis(name, group)
   endif
   endsubroutine link

   subroutine axes_y2()
   !< The next items on X1 and Y2.

   if (side_fortran) then
      call pf_set_axes('x1', 'y2')
   else
      call ip_set_axes('x1', 'y2')
   endif
   endsubroutine axes_y2

   subroutine line(n, j)
   !< `ip_line` or `pf_line` of the first n points of the j-th line.
   integer(int32), intent(in) :: n !< Points.
   integer(int32), intent(in) :: j !< Line.

   if (side_fortran) then
      call pf_line('##l', xs(1:n), ys(1:n, j), spec=pf_spec(line_color=merge(C1, C2, j /= 4_int32)))
   else
      call ip_line('##l', xs(1:n), ys(1:n, j), spec=ip_spec(line_color=merge(C1, C2, j /= 4_int32)))
   endif
   endsubroutine line

   subroutine pend(j, fr, y2)
   !< The j-th plot's ranges (X1, Y1, and Y2 if set up) and the pixels of its corners kept, the plot ended.
   integer(int32), intent(in) :: j, fr !< Plot, frame.
   logical,        intent(in) :: y2    !< Y2 set up.
   integer(int32)             :: m, o  !< Side, offset.
   real(real64)               :: d1, d2 !< Unused x range.

   m = merge(2_int32, 1_int32, side_fortran)
   o = NV * (j - 1_int32)
   associate(v => state(o + 1_int32:o + NV, fr, m))
      if (side_fortran) then
         call pf_plot_limits(v(1), v(2), v(3), v(4), 'x1', 'y1')
         call pf_plot_to_pixels(v(1), v(4), v(5), v(6), 'x1', 'y1')
         call pf_plot_to_pixels(v(2), v(3), v(7), v(8), 'x1', 'y1')
         if (y2) call pf_plot_limits(d1, d2, v(9), v(10), 'x1', 'y2')
         call pf_end_plot()
      else
         call ip_plot_limits(v(1), v(2), v(3), v(4), 'x1', 'y1')
         call ip_plot_to_pixels(v(1), v(4), v(5), v(6), 'x1', 'y1')
         call ip_plot_to_pixels(v(2), v(3), v(7), v(8), 'x1', 'y1')
         if (y2) call ip_plot_limits(d1, d2, v(9), v(10), 'x1', 'y2')
         call ip_end_plot()
      endif
   endassociate
   endsubroutine pend

   function state_equal(k) result(ok)
   !< Both sides' state equal on every frame.
   integer(int32), intent(in) :: k  !< Case.
   logical                    :: ok !< Equal.
   integer(int32)             :: fr !< Frame.

   ok = .true.
   do fr = 1_int32, nframes(k)
      if (all(state(:, fr, 1) == state(:, fr, 2))) cycle
      ok = .false.
      write(output_unit, '(A,I0,A,I0,A)') 'case ', k, ', frame ', fr, ': ImPlot, frame'
      write(output_unit, '(4ES24.16)') state(:, fr, 1)
      write(output_unit, '(4ES24.16)') state(:, fr, 2)
   enddo
   endfunction state_equal

   function pictures_equal(k, n) result(ok)
   !< A case's n-th pictures of both sides equal at the oracle's rule.
   integer(int32), intent(in) :: k, n !< Case, picture.
   logical                    :: ok   !< Equal.
   integer(int64)             :: nf_  !< Pixels that failed.
   integer(int32)             :: st   !< Status.

   ok = test_compare_image(picture(k, n, .true.), picture(k, n, .false.), threshold=2_int32, max_failed=0_int32, &
                           failed=nf_, stat=st)
   if (.not. ok) write(output_unit, '(A,I0,A,I0,A,I0,A,A)') 'case ', k, ', picture ', n, ': ', nf_, &
                                                            ' pixels failed: ', figure_last_error()
   endfunction pictures_equal

   function picture(k, n, fortran) result(name)
   !< A case's n-th picture: ImPlot's or the Fortran frame's.
   integer(int32), intent(in)    :: k, n    !< Case, picture.
   logical,        intent(in)    :: fortran !< The Fortran frame's.
   character(len=:), allocatable :: name    !< File name.
   character(len=16)             :: tag     !< The case's and picture's numbers.

   write(tag, '(I0,A,I0)') k, '.', n
   if (fortran) then
      name = 'figure_test_plot_frame_links.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_links.'//trim(tag)//'.implot.png.tmp'
   endif
   endfunction picture

   subroutine remove_files()
   !< The pictures (a mismatch's .new.png and .diff.png are left for inspection).
   integer(int32) :: unit, ios, k, n, m !< Unit, status, counters.

   do k = 1_int32, NCASE
      do n = 1_int32, 2_int32
         do m = 1_int32, 2_int32
            open(newunit=unit, file=picture(k, n, m == 1_int32), status='old', iostat=ios)
            if (ios == 0) close(unit, status='delete')
         enddo
      enddo
   enddo
   endsubroutine remove_files
endprogram figure_test_plot_frame_links
