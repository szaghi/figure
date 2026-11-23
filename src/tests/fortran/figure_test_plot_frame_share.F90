!< figure_test_plot_frame_share, the Fortran plot frame's subplot items shared (ShareItems), as ImPlot's.
program figure_test_plot_frame_share
!< figure_test_plot_frame_share, the Fortran plot frame's subplot items shared (ShareItems), as ImPlot's.
!<
!< szaghi/figure#15 P12 (what P10-P12 left, night 2026-11-23 step 12). A 2 x 2 subplot is drawn on a few frames,
!< first by ImPlot through FIGURE's API (`ip_begin_subplots`, ...), then by the Fortran frame (`pf_*`), with the same
!< synthetic input (figure_testing) at the same frames, 40 frames apart. Its cells draw lines of automatic colours,
!< two of them sharing a label ('sin' in the first and second cell, 'cos' in the first and third); the first cell sets
!< its legend up (north, outside, in a row: its own legend's, or the shared one's while the items are shared). Checked on every
!< frame: each cell's X1-Y1 ranges and the pixels of their corners, and the first cell's `legend_hovered('sin')`, equal
!< to the bit; pictures at FIGURE's oracle rule (|d| <= 2 on every channel, no pixel failing). The cases, one after
!< the other on the same subplot (its state goes on from case to case, on each side):
!<
!< 1. the first cell's context menu, Subplots > Settings > Share Items (pictured open): the cells' items one group,
!<    one legend in the subplot's frame (north, in a row), the grid shrunk for it from the frame after;
!< 2. the shared legend's 'sin' entry hovered (the line highlighted in both cells), then clicked: hidden in both;
!< 3. a right click on the shared legend off its entries: its context menu (no Outside: the legend cannot go inside),
!<    'S' and 'V' clicked (the legend south, in a column: the grid's bottom shrunk), a click away;
!< 4. Share Items clicked again (pictured checked): the cells' own items and legends back;
!< 5. another 1 x 2 subplot sharing its items from its first frame: `pf_begin_subplots(share_items=.true.)`, the
!<    Fortran path's own, against cimplot's `BeginSubplots` with `ImPlotSubplotFlags_ShareItems` (FIGURE's
!<    `ip_begin_subplots` cannot ask for it; its first-draw fit asked for the cells, `SetNextAxisToFit`, as it does).
!<
!< The pictures are `figure_test_plot_frame_share.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them; a
!< mismatch's .new.png and .diff.png are left for inspection).
use, intrinsic :: iso_c_binding, only : c_float, c_int, c_null_char, c_null_ptr
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ig_text_size,              &
                   ip_begin_plot, ip_begin_subplots, ip_end_plot, ip_end_subplots, ip_legend_hovered, ip_line,     &
                   ip_plot_limits, ip_plot_to_pixels, ip_setup_legend, ImGuiWindowFlags_NoDecoration
use figure_cimgui, only : im_vec2
use figure_cimplot, only : ImPlot_BeginSubplots, ImPlot_EndSubplots, ImPlot_SetNextAxisToFit
use figure_cimplot_enums, only : ImPlotSubplotFlags_ShareItems
use figure_plot_frame, only : pf_begin_plot, pf_begin_subplots, pf_end_plot, pf_end_subplots, pf_legend_hovered, &
                              pf_plot_limits, pf_plot_to_pixels, pf_setup_legend
use figure_plot_items, only : pf_line
use figure_testing, only : test_capture, test_click, test_compare_image, test_item_click, test_mouse_button, &
                           test_mouse_move

implicit none
integer(int32), parameter :: W = 800_int32      !< Display width [pixels].
integer(int32), parameter :: H = 600_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 5_int32    !< Cases.
integer(int32), parameter :: NFMAX = 20_int32   !< Frames per side of a case at most.
integer(int32), parameter :: NP = 201_int32     !< Points of a line.
integer(int32), parameter :: NPLOT = 4_int32    !< Cells.
integer(int32), parameter :: NSTATE = 8_int32 * NPLOT + 1_int32 !< Values checked per frame: per cell, X1-Y1 ranges and
                                                                !< corners; the first cell's 'sin' entry hovered.
real(real64),   parameter :: TOP = 18.0_real64  !< The shared legend's top, north: the window's padding (8) and the
                                                !< style's PlotPadding (10) [pixels].
type(app_object)          :: app                !< Application.
real(real64)              :: xs(NP), ys(NP, 5)  !< The lines.
real(real64)              :: state(NSTATE, NFMAX, 2) !< Per frame and side.
logical                   :: test_passed(NCASE) !< Per-case outcome.
logical                   :: side_fortran       !< Drawing with the Fortran frame.
integer(int32)            :: c, f, s, sd, i     !< Case, frame, status, side, counter.
integer(int32)            :: np_                !< The cell being recorded.
real(real64)              :: txt_h = 0.0_real64 !< The font's line height [pixels].
real(real64)              :: lab_w(4) = 0.0_real64 !< The shared legend's labels' widths [pixels].
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do i = 1_int32, NP
   xs(i) = real(i - 1_int32, real64) * 0.05_real64
   ys(i, 1) = sin(xs(i))
   ys(i, 2) = 0.6_real64 * cos(1.3_real64 * xs(i))
   ys(i, 3) = 0.5_real64 * sin(xs(i)) + 0.2_real64
   ys(i, 4) = exp(-0.3_real64 * xs(i)) * cos(3.0_real64 * xs(i))
   ys(i, 5) = 10.0_real64**(0.3_real64 * xs(i))
enddo
do c = 1_int32, NCASE
   state = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
      side_fortran = sd == 2_int32
      do f = 1_int32, nframes(c)
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_share: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame share', flags=ImGuiWindowFlags_NoDecoration)) then
            if (txt_h == 0.0_real64) call measure()
            call draw_case(c, f)
         endif
         call ig_end()
         if (captured(c, f) > 0_int32) call test_capture(picture(c, captured(c, f), side_fortran), s)
         call pointer(c, f)
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      do i = 1_int32, 40_int32 ! past Dear ImGui's double-click time: the other side's clicks are not a pair
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_share: next_frame returned false headless'
      enddo
   enddo
   test_passed(c) = state_equal(c)
   do i = 1_int32, 2_int32
      test_passed(c) = pictures_equal(c, i) .and. test_passed(c)
   enddo
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_share checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   pure function nframes(k) result(n)
   !< A case's frames per side.
   integer(int32), intent(in) :: k !< Case.
   integer(int32)             :: n !< Frames.

   select case (k)
   case (2_int32)
      n = 14_int32
   case (5_int32)
      n = 6_int32
   case default
      n = 20_int32
   endselect
   endfunction nframes

   pure function captured(k, fr) result(n)
   !< The picture taken on a frame (0: none, 1: the first, 2: the second).
   integer(int32), intent(in) :: k, fr !< Case, frame.
   integer(int32)             :: n     !< Picture.

   n = 0_int32
   if (fr == nframes(k)) n = 2_int32
   select case (k)
   case (1_int32, 4_int32)
      if (fr == 14_int32) n = 1_int32
   case (2_int32)
      if (fr == 5_int32) n = 1_int32
   case (5_int32)
      if (fr == 1_int32) n = 1_int32
   case default
      if (fr == 7_int32) n = 1_int32
   endselect
   endfunction captured

   subroutine measure()
   !< The font's line height and the shared legend's labels' widths (the same on both sides).
   real(real64) :: e(2) !< A text's extent.

   e = ig_text_size('sin')
   lab_w(1) = e(1)
   txt_h = e(2)
   e = ig_text_size('cos')
   lab_w(2) = e(1)
   e = ig_text_size('damped')
   lab_w(3) = e(1)
   e = ig_text_size('growth')
   lab_w(4) = e(1)
   endsubroutine measure

   function pix(k, j) result(v)
   !< A pixel of ImPlot's cell k on the case's first frame: j 1, 2 the corner (x min, y max), 3, 4 (x max, y min).
   integer(int32), intent(in) :: k, j !< Cell, coordinate.
   real(real64)               :: v    !< Pixel.

   v = state(8_int32 * (k - 1_int32) + 4_int32 + j, 1, 1)
   endfunction pix

   subroutine pointer(k, fr)
   !< A case's input after a frame, the same on both sides (the cells' targets from ImPlot's side's first frame; the
   !< shared legend's from the font: north, in a row, centred in the subplot's frame, 8 to W - 8).
   integer(int32), intent(in) :: k, fr !< Case, frame.
   real(real64)               :: x, y  !< A target.
   real(real64)               :: lw    !< The shared legend's width.

   lw = (5.0_real64 * 2.0_real64 + txt_h * 4.0_real64 + sum(lab_w)) + 3.0_real64 * 5.0_real64
   select case (k)
   case (1_int32, 4_int32) ! the first cell's context menu: Subplots > Settings > Share Items
      x = real(nint(0.5_real64 * (pix(1, 1) + pix(1, 3))), real64)
      y = real(nint(0.5_real64 * (pix(1, 2) + pix(1, 4))), real64)
      if (fr == 2_int32) call test_mouse_move(x, y)
      if (fr == 3_int32) call test_mouse_button(.true., 'right')
      if (fr == 4_int32) call test_mouse_button(.false., 'right')
      if (fr == 7_int32) call test_item_click('Subplots')
      if (fr == 11_int32) call test_item_click('Subplots/Settings')
      if (fr == 15_int32) call test_item_click('Share Items')
      if (fr == 17_int32) call away()
   case (2_int32) ! the 'sin' entry: hovered, then clicked
      x = real(nint(0.5_real64 * real(W, real64) - 0.5_real64 * lw + 5.0_real64 + txt_h + 0.5_real64 * lab_w(1)), &
               real64)
      y = real(nint(TOP + 5.0_real64 + 0.5_real64 * txt_h), real64)
      if (fr == 2_int32) call test_mouse_move(x, y)
      if (fr == 6_int32) call test_mouse_button(.true.)
      if (fr == 7_int32) call test_mouse_button(.false.)
      if (fr == 9_int32) call away()
   case (3_int32) ! the shared legend's context menu: below its entries, inside its padding
      x = 0.5_real64 * real(W, real64)
      y = real(nint(TOP + 5.0_real64 + txt_h + 2.0_real64), real64)
      if (fr == 2_int32) call test_mouse_move(x, y)
      if (fr == 3_int32) call test_mouse_button(.true., 'right')
      if (fr == 4_int32) call test_mouse_button(.false., 'right')
      if (fr == 8_int32) call test_item_click('S')
      if (fr == 12_int32) call test_item_click('V')
      if (fr == 16_int32) call test_click(real(W, real64) - 6.0_real64, real(H, real64) - 6.0_real64)
   case default
   endselect
   endsubroutine pointer

   subroutine away()
   !< The pointer away from the window.

   call test_mouse_move(-100.0_real64, -100.0_real64)
   endsubroutine away

   subroutine draw_case(k, fr)
   !< The subplot on a frame, by the side drawing (the same in the first four cases: the input differs).
   integer(int32), intent(in) :: k, fr !< Case, frame.
   integer(int32)             :: i     !< Axis.

   np_ = 0_int32
   if (k == 5_int32) then ! sharing from the first frame
      if (side_fortran) then
         if (.not. pf_begin_subplots('##api', 1_int32, 2_int32, height=300.0_real64, share_items=.true.)) return
      else
         if (.not. ImPlot_BeginSubplots('##api'//c_null_char, 1_c_int, 2_c_int, im_vec2(-1.0_c_float, 300.0_c_float), &
                                        ImPlotSubplotFlags_ShareItems, c_null_ptr, c_null_ptr)) return
      endif
      do i = 1_int32, 2_int32
         if (.not. side_fortran .and. fr == 1_int32) call fit_next() ! ip_begin_subplots' first-draw fit
         if (pbegin(merge('##a1', '##a2', i == 1_int32))) then
            call line('sin', i)
            if (i == 1_int32) then
               call line('cos', 2_int32)
            else
               call line('growth', 5_int32)
            endif
            call pend(fr)
         endif
      enddo
      if (side_fortran) then
         call pf_end_subplots()
      else
         call ImPlot_EndSubplots()
      endif
      return
   endif
   if (side_fortran) then
      if (.not. pf_begin_subplots('##shared', 2_int32, 2_int32, height=520.0_real64)) return
   else
      if (.not. ip_begin_subplots('##shared', 2_int32, 2_int32, height=520.0_real64)) return
   endif
   if (pbegin('##c1')) then
      if (side_fortran) then
         call pf_setup_legend('n', outside=.true., horizontal=.true.)
      else
         call ip_setup_legend('n', outside=.true., horizontal=.true.)
      endif
      call line('sin', 1_int32)
      call line('cos', 2_int32)
      if (side_fortran) then
         state(NSTATE, fr, 2) = merge(1.0_real64, 0.0_real64, pf_legend_hovered('sin'))
      else
         state(NSTATE, fr, 1) = merge(1.0_real64, 0.0_real64, ip_legend_hovered('sin'))
      endif
      call pend(fr)
   endif
   if (pbegin('##c2')) then
      call line('sin', 3_int32)
      call line('damped', 4_int32)
      call pend(fr)
   endif
   if (pbegin('##c3')) then
      call line('cos', 4_int32)
      call pend(fr)
   endif
   if (pbegin('##c4')) then
      call line('growth', 5_int32)
      call pend(fr)
   endif
   if (side_fortran) then
      call pf_end_subplots()
   else
      call ip_end_subplots()
   endif
   endsubroutine draw_case

   subroutine fit_next()
   !< Every axis of the next plot asked to fit (`ip_begin_plot` on a new subplot's cells).
   integer(c_int) :: i !< Axis.

   do i = 0_c_int, 5_c_int
      call ImPlot_SetNextAxisToFit(i)
   enddo
   endsubroutine fit_next

   function pbegin(id) result(visible)
   !< `ip_begin_plot` or `pf_begin_plot` (a cell's size is its own).
   character(len=*), intent(in) :: id      !< Plot's ID.
   logical                      :: visible !< Plot visible.

   if (side_fortran) then
      visible = pf_begin_plot(id)
   else
      visible = ip_begin_plot(id)
   endif
   endfunction pbegin

   subroutine line(label, j)
   !< `ip_line` or `pf_line` of the j-th line, its colour automatic.
   character(len=*), intent(in) :: label !< Label.
   integer(int32),   intent(in) :: j     !< Line.

   if (side_fortran) then
      call pf_line(label, xs, ys(:, j))
   else
      call ip_line(label, xs, ys(:, j))
   endif
   endsubroutine line

   subroutine pend(fr)
   !< The cell's ranges and the pixels of their corners kept, the plot ended.
   integer(int32), intent(in) :: fr   !< Frame.
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
      name = 'figure_test_plot_frame_share.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_share.'//trim(tag)//'.implot.png.tmp'
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
endprogram figure_test_plot_frame_share
