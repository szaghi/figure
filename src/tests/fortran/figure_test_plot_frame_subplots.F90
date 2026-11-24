!< figure_test_plot_frame_subplots, the Fortran plot frame's subplots and aligned plots, as ImPlot's.
program figure_test_plot_frame_subplots
!< figure_test_plot_frame_subplots, the Fortran plot frame's subplots and aligned plots, as ImPlot's.
!<
!< szaghi/figure#15 P12, step 1. Each case is drawn on a few frames, first by ImPlot through FIGURE's API
!< (`ip_begin_subplots`, `ip_begin_aligned`, ...), then by the Fortran frame (`pf_*`), with the same synthetic input
!< (figure_testing) at the same frames, 40 frames apart (no double click across the sides). Checked on every frame: each
!< plot's X1-Y1 ranges and the pixels of their corners (the plot area), equal to the bit; and pictures at FIGURE's
!< oracle rule (|d| <= 2 on every channel, no pixel failing). The cases:
!<
!< 1. a titled 2 x 2 subplot, its cells' y tick labels of different widths, axis labels, an outside legend: the first
!<    frames' fit (FIGURE's first-draw fit) and the rows' and columns' alignment;
!< 2. a 1 x 3 subplot without a title, x linked, its cells' data of different extents: the last cell's range shared,
!<    then the wheel over the middle cell zooms the three;
!< 3. a 2 x 2 subplot, x and y linked: a pan in its last cell moves all;
!< 4. a row splitter hovered (its feedback line, after Dear ImGui's hover time), dragged and released (the rows' room);
!< 5. a subplot whose rows and columns change (2 x 1, then 1 x 2): the ratios and links reset;
!< 6. a cell's context menu, its Subplots > Linking > Link Rows (pictured open, then the rows linked);
!< 7. three plots stacked in an aligned group (y tick labels 1 to 1e6, 0 to 1, -100 to 100) and two side by side in
!<    another (one with an x label): the same plot areas' edges as ImPlot's.
!<
!< The pictures are `figure_test_plot_frame_subplots.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them; a
!< mismatch's .new.png and .diff.png are left for inspection).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_same_line, ig_set_next_window, &
                   ImGuiWindowFlags_NoDecoration
use figure_implot_ref, only : ip_begin_aligned, ip_begin_plot, ip_begin_subplots, ip_end_aligned, ip_end_plot, &
                              ip_end_subplots, ip_line, ip_plot_limits, ip_plot_to_pixels, ip_setup_axes, &
                              ip_setup_axes_limits, ip_setup_legend, ip_spec
use figure_plot_frame, only : pf_begin_aligned, pf_begin_plot, pf_begin_subplots, pf_end_aligned, pf_end_plot,  &
                              pf_end_subplots, pf_plot_limits, pf_plot_to_pixels, pf_setup_axes, pf_setup_axes_limits, &
                              pf_setup_legend
use figure_plot_items, only : pf_line, pf_spec
use figure_testing, only : test_capture, test_compare_image, test_drag, test_item_click, test_mouse_button, &
                           test_mouse_move, test_wheel

implicit none
integer(int32), parameter :: W = 800_int32      !< Display width [pixels].
integer(int32), parameter :: H = 640_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 7_int32    !< Cases.
integer(int32), parameter :: NFMAX = 20_int32   !< Frames per side of a case at most.
integer(int32), parameter :: NP = 201_int32     !< Points of a line.
integer(int32), parameter :: NPLOT = 5_int32    !< Plots of a case at most.
integer(int32), parameter :: NSTATE = 8_int32 * NPLOT !< Values checked per frame: per plot, X1-Y1 ranges and corners.
real(real64),   parameter :: C1(4) = [0.91_real64, 0.40_real64, 0.30_real64, 1.0_real64] !< A colour.
real(real64),   parameter :: C2(4) = [0.30_real64, 0.62_real64, 0.85_real64, 1.0_real64] !< Another.
type(app_object)          :: app                !< Application.
real(real64)              :: xs(NP), ys(NP, 4)  !< The lines.
real(real64)              :: state(NSTATE, NFMAX, 2) !< Per frame and side.
logical                   :: test_passed(NCASE) !< Per-case outcome.
logical                   :: side_fortran       !< Drawing with the Fortran frame.
integer(int32)            :: c, f, s, sd, i     !< Case, frame, status, side, counter.
integer(int32)            :: np_                !< The plot being recorded.
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
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_subplots: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame subplots', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(c, f)
         call ig_end()
         if (captured(c, f) > 0_int32) call test_capture(picture(c, captured(c, f), side_fortran), s)
         call pointer(c, f)
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      do i = 1_int32, 40_int32 ! past Dear ImGui's double-click time: the other side's clicks are not a pair
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_subplots: next_frame returned false headless'
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

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_subplots checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   pure function nframes(k) result(n)
   !< A case's frames per side.
   integer(int32), intent(in) :: k !< Case.
   integer(int32)             :: n !< Frames.

   select case (k)
   case (1_int32, 7_int32)
      n = 5_int32
   case (2_int32)
      n = 10_int32
   case (3_int32)
      n = 12_int32
   case (4_int32)
      n = 16_int32
   case (5_int32)
      n = 7_int32
   case default
      n = 20_int32
   endselect
   endfunction nframes

   pure function captured(k, fr) result(n)
   !< The picture taken on a frame (0: none, 1: the first, 2: the second).
   integer(int32), intent(in) :: k, fr !< Case, frame.
   integer(int32)             :: n     !< Picture.

   n = 0_int32
   if (fr == nframes(k)) n = 1_int32
   select case (k)
   case (1_int32, 2_int32, 7_int32)
      if (fr == 1_int32) n = 2_int32
   case (4_int32)
      if (fr == 8_int32) n = 2_int32
   case (6_int32)
      if (fr == 14_int32) n = 2_int32
   endselect
   endfunction captured

   pure function captured_frames(k) result(n)
   !< The pictures a case takes.
   integer(int32), intent(in) :: k    !< Case.
   integer(int32)             :: n(2) !< Pictures (0: none).

   n = [1_int32, 0_int32]
   if (k == 1_int32 .or. k == 2_int32 .or. k == 4_int32 .or. k == 6_int32 .or. k == 7_int32) n(2) = 2_int32
   endfunction captured_frames

   function pix(k, j, fr) result(v)
   !< A pixel of ImPlot's plot k on frame fr: j 1, 2 the corner (x min, y max), 3, 4 the corner (x max, y min).
   integer(int32), intent(in) :: k, j, fr !< Plot, coordinate, frame.
   real(real64)               :: v        !< Pixel.

   v = state(8_int32 * (k - 1_int32) + 4_int32 + j, fr, 1)
   endfunction pix

   subroutine pointer(k, fr)
   !< A case's input on a frame, the same on both sides (the targets from ImPlot's side's first frame).
   integer(int32), intent(in) :: k, fr !< Case, frame.
   real(real64)               :: x, y  !< A target.

   select case (k)
   case (2_int32) ! the wheel over the middle cell
      x = 0.5_real64 * (pix(2, 1, 1) + pix(2, 3, 1))
      y = 0.5_real64 * (pix(2, 2, 1) + pix(2, 4, 1))
      if (fr == 4_int32) call test_mouse_move(real(nint(x), real64), real(nint(y), real64))
      if (fr == 5_int32 .or. fr == 7_int32) call test_wheel(1.0_real64)
      if (fr == 8_int32) call away()
   case (3_int32) ! a pan in the last cell
      x = real(nint(0.5_real64 * (pix(4, 1, 1) + pix(4, 3, 1))), real64)
      y = real(nint(0.5_real64 * (pix(4, 2, 1) + pix(4, 4, 1))), real64)
      if (fr == 3_int32) call test_drag(x, y, x - 80.0_real64, y + 40.0_real64)
      if (fr == 10_int32) call away()
   case (4_int32) ! the row splitter: just above the third cell's frame (its plot area's top less half the padding)
      x = real(nint(0.5_real64 * (pix(1, 1, 1) + pix(1, 3, 1))), real64)
      y = real(nint(pix(3, 2, 1) - 5.0_real64), real64)
      if (fr == 2_int32) call test_mouse_move(x, y)
      if (fr == 9_int32) call test_mouse_button(.true.)
      if (fr == 10_int32) call test_mouse_move(x, y + 20.0_real64)
      if (fr == 11_int32) call test_mouse_move(x, y + 45.0_real64)
      if (fr == 12_int32) call test_mouse_button(.false.)
      if (fr == 13_int32) call away()
   case (6_int32) ! a cell's context menu
      x = real(nint(0.5_real64 * (pix(1, 1, 1) + pix(1, 3, 1))), real64)
      y = real(nint(0.5_real64 * (pix(1, 2, 1) + pix(1, 4, 1))), real64)
      if (fr == 2_int32) call test_mouse_move(x, y)
      if (fr == 3_int32) call test_mouse_button(.true., 'right')
      if (fr == 4_int32) call test_mouse_button(.false., 'right')
      if (fr == 7_int32) call test_item_click('Subplots')
      if (fr == 11_int32) call test_item_click('Linking')
      if (fr == 15_int32) call test_item_click('Link Rows')
      if (fr == 17_int32) call away()
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

   np_ = 0_int32
   select case (k)
   case (1_int32)
      if (.not. sbegin('Grid of four', 2_int32, 2_int32, 520.0_real64, .false., .false.)) return
      if (pbegin('##g1')) then
         call axes('', 'sine')
         call line('##a', NP, 1_int32, C1)
         call pend(fr)
      endif
      if (pbegin('##g2')) then
         call legend_out()
         call line('growth', NP, 2_int32, C2)
         call pend(fr)
      endif
      if (pbegin('##g3')) then
         call axes('time', '')
         call line('##c', NP, 3_int32, C1)
         call pend(fr)
      endif
      if (pbegin('##g4')) then
         call line('##d', NP, 4_int32, C2)
         call pend(fr)
      endif
      call send()
   case (2_int32)
      if (.not. sbegin('##linked x', 1_int32, 3_int32, 0.0_real64, .true., .false.)) return
      do i = 1_int32, 3_int32
         if (pbegin(cell_id('##lx', i))) then
            call line('##l', 60_int32 * i, i, C1)
            call pend(fr)
         endif
      enddo
      call send()
   case (3_int32)
      if (.not. sbegin('##linked xy', 2_int32, 2_int32, 480.0_real64, .true., .true.)) return
      do i = 1_int32, 4_int32
         if (pbegin(cell_id('##lxy', i))) then
            call line('##l', 50_int32 * i, i, C2)
            call pend(fr)
         endif
      enddo
      call send()
   case (4_int32)
      if (.not. sbegin('Resizable', 2_int32, 2_int32, 520.0_real64, .false., .false.)) return
      do i = 1_int32, 4_int32
         if (pbegin(cell_id('##rs', i))) then
            call limits(0.0_real64, 10.0_real64, -1.5_real64, 1.5_real64)
            call line('##l', NP, 1_int32, C1)
            call pend(fr)
         endif
      enddo
      call send()
   case (5_int32)
      if (fr <= 3_int32) then
         if (.not. sbegin('##reshaped', 2_int32, 1_int32, 440.0_real64, .true., .false.)) return
      else
         if (.not. sbegin('##reshaped', 1_int32, 2_int32, 440.0_real64, .true., .false.)) return
      endif
      do i = 1_int32, 2_int32
         if (pbegin(cell_id('##rh', i))) then
            call line('##l', 80_int32 * i, i + 2_int32, C1)
            call pend(fr)
         endif
      enddo
      call send()
   case (6_int32)
      if (.not. sbegin('Menu', 2_int32, 2_int32, 520.0_real64, .false., .false.)) return
      do i = 1_int32, 4_int32
         if (pbegin(cell_id('##mn', i))) then
            call line('##l', NP, i, C2)
            call pend(fr)
         endif
      enddo
      call send()
   case default
      if (abegin('stack', .false.)) then
         do i = 1_int32, 3_int32
            if (pbegin(cell_id('##st', i), 560.0_real64, 150.0_real64)) then
               call line('##l', NP, merge(2_int32, merge(1_int32, 4_int32, i == 2_int32), i == 1_int32), C1)
               call pend(fr)
            endif
         enddo
         call aend()
      endif
      if (abegin('side', .true.)) then
         if (pbegin('##sd1', 300.0_real64, 160.0_real64)) then
            call axes('time', '')
            call line('##l', NP, 3_int32, C2)
            call pend(fr)
         endif
         call ig_same_line()
         if (pbegin('##sd2', 300.0_real64, 160.0_real64)) then
            call line('##l', NP, 1_int32, C2)
            call pend(fr)
         endif
         call aend()
      endif
   endselect
   endsubroutine draw_case

   function cell_id(prefix, k) result(id)
   !< A cell's plot ID: prefix and its number.
   character(len=*), intent(in)  :: prefix !< Prefix.
   integer(int32),   intent(in)  :: k      !< Number.
   character(len=:), allocatable :: id     !< ID.

   id = prefix//achar(48_int32 + k)
   endfunction cell_id

   function sbegin(title, rows, cols, height, lx, ly) result(visible)
   !< `ip_begin_subplots` or `pf_begin_subplots` (`height` 0: the default).
   character(len=*), intent(in) :: title      !< Title.
   integer(int32),   intent(in) :: rows, cols !< Grid.
   real(real64),     intent(in) :: height     !< Height.
   logical,          intent(in) :: lx, ly     !< Links.
   logical                      :: visible    !< Drawn.

   if (side_fortran) then
      if (height > 0.0_real64) then
         visible = pf_begin_subplots(title, rows, cols, height=height, link_x=lx, link_y=ly)
      else
         visible = pf_begin_subplots(title, rows, cols, link_x=lx, link_y=ly)
      endif
   else
      if (height > 0.0_real64) then
         visible = ip_begin_subplots(title, rows, cols, height=height, link_x=lx, link_y=ly)
      else
         visible = ip_begin_subplots(title, rows, cols, link_x=lx, link_y=ly)
      endif
   endif
   endfunction sbegin

   subroutine send()
   !< `ip_end_subplots` or `pf_end_subplots`.

   if (side_fortran) then
      call pf_end_subplots()
   else
      call ip_end_subplots()
   endif
   endsubroutine send

   function abegin(group, horizontal) result(open)
   !< `ip_begin_aligned` or `pf_begin_aligned`.
   character(len=*), intent(in) :: group      !< Group.
   logical,          intent(in) :: horizontal !< Side by side.
   logical                      :: open       !< Open.

   if (side_fortran) then
      open = pf_begin_aligned(group, horizontal=horizontal)
   else
      open = ip_begin_aligned(group, horizontal=horizontal)
   endif
   endfunction abegin

   subroutine aend()
   !< `ip_end_aligned` or `pf_end_aligned`.

   if (side_fortran) then
      call pf_end_aligned()
   else
      call ip_end_aligned()
   endif
   endsubroutine aend

   function pbegin(id, width, height) result(visible)
   !< `ip_begin_plot` or `pf_begin_plot` (a cell's size is its own).
   character(len=*), intent(in)           :: id      !< Plot's ID.
   real(real64),     intent(in), optional :: width   !< Width.
   real(real64),     intent(in), optional :: height  !< Height.
   logical                                :: visible !< Plot visible.

   if (side_fortran) then
      visible = pf_begin_plot(id, width=width, height=height)
   else
      visible = ip_begin_plot(id, width=width, height=height)
   endif
   endfunction pbegin

   subroutine axes(xlabel, ylabel)
   !< `ip_setup_axes` or `pf_setup_axes`.
   character(len=*), intent(in) :: xlabel, ylabel !< Labels.

   if (side_fortran) then
      call pf_setup_axes(xlabel, ylabel)
   else
      call ip_setup_axes(xlabel, ylabel)
   endif
   endsubroutine axes

   subroutine legend_out()
   !< The legend outside the plot area, east.

   if (side_fortran) then
      call pf_setup_legend('e', outside=.true.)
   else
      call ip_setup_legend('e', outside=.true.)
   endif
   endsubroutine legend_out

   subroutine limits(xmin, xmax, ymin, ymax)
   !< X1 and Y1's ranges, every frame.
   real(real64), intent(in) :: xmin, xmax, ymin, ymax !< Ranges.

   if (side_fortran) then
      call pf_setup_axes_limits(xmin, xmax, ymin, ymax, always=.true.)
   else
      call ip_setup_axes_limits(xmin, xmax, ymin, ymax, always=.true.)
   endif
   endsubroutine limits

   subroutine line(label, n, j, col)
   !< `ip_line` or `pf_line` of the first n points of the j-th line.
   character(len=*), intent(in) :: label  !< Label.
   integer(int32),   intent(in) :: n      !< Points.
   integer(int32),   intent(in) :: j      !< Line.
   real(real64),     intent(in) :: col(4) !< Colour.

   if (side_fortran) then
      call pf_line(label, xs(1:n), ys(1:n, j), spec=pf_spec(line_color=col))
   else
      call ip_line(label, xs(1:n), ys(1:n, j), spec=ip_spec(line_color=col))
   endif
   endsubroutine line

   subroutine pend(fr)
   !< The plot's ranges and the pixels of their corners kept, the plot ended.
   integer(int32), intent(in) :: fr !< Frame.
   integer(int32)             :: m, o !< Side, offset.

   m = merge(2_int32, 1_int32, side_fortran)
   np_ = np_ + 1_int32
   o = 8_int32 * (np_ - 1_int32)
   associate(v => state(o + 1_int32:o + 8_int32, fr, m))
      if (side_fortran) then
         call pf_plot_limits(v(1), v(2), v(3), v(4), 'x1', 'y1')
         call pf_plot_to_pixels(v(1), v(4), v(5), v(6), 'x1', 'y1')
         call pf_plot_to_pixels(v(2), v(3), v(7), v(8), 'x1', 'y1')
         call pf_end_plot()
      else
         call ip_plot_limits(v(1), v(2), v(3), v(4), 'x1', 'y1')
         call ip_plot_to_pixels(v(1), v(4), v(5), v(6), 'x1', 'y1')
         call ip_plot_to_pixels(v(2), v(3), v(7), v(8), 'x1', 'y1')
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
      name = 'figure_test_plot_frame_subplots.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_subplots.'//trim(tag)//'.implot.png.tmp'
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
endprogram figure_test_plot_frame_subplots
