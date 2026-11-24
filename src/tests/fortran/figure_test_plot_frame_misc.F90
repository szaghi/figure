!< figure_test_plot_frame_misc, the Fortran plot frame's pie charts, bubbles, digital signals and texts, as ImPlot's.
program figure_test_plot_frame_misc
!< figure_test_plot_frame_misc, the Fortran plot frame's pie charts, bubbles, digital signals and texts, as ImPlot's.
!<
!< szaghi/figure#15 P11, group (c). Each case is a plot drawn on NF frames, first by ImPlot through FIGURE's API
!< (`ip_pie_chart`, `ip_bubbles`, `ip_digital`, `ip_text`), then by the Fortran frame (`pf_*` of figure_plot_items), in
!< one headless window at the same place. Checked: the ranges of X1-Y1 on every frame equal to the bit, and the last
!< pictures at FIGURE's oracle rule (|d| <= 2 on every channel, no pixel failing). The cases:
!<
!< 1. a pie normalised (values summing above 1), its labels '%.1f', from 90 degrees;
!< 2. a partial pie (values summing below 1), labels '%.2f', from 0 degrees; a second one `normalize`d;
!< 3. a pie in the colormap Viridis, `NoSliceBorder`, no labels ('');
!< 4. a pie `IgnoreHidden` with its first slice hidden (`hide_next_item`);
!< 5. a pie `Exploding`, the pointer on its first legend entry (the slice detached, its label further out);
!< 6. bubbles, filled (FillAlpha 0.5) and outlined, double and single precision;
!< 7. the fit of bubbles (each centre +- its radius) and of texts (no limits);
!< 8. two digital signals (their bands stacked; a NaN skipped);
!< 9. texts, horizontal and vertical, with offsets;
!< 10. a pie of single precision values beside a line.
!<
!< The pictures are `figure_test_plot_frame_misc.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: ieee_arithmetic, only : ieee_quiet_nan, ieee_value
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ImGuiWindowFlags_NoDecoration
use figure_implot_ref, only : ip_begin_plot, ip_bubbles, ip_colormap, ip_digital, ip_end_plot, ip_hide_next_item, &
                              ip_line, ip_pie_chart, ip_plot_limits, ip_setup_axes_limits, ip_spec, ip_text
use figure_plot_frame, only : pf_begin_plot, pf_colormap, pf_end_plot, pf_hide_next_item, pf_plot_limits, &
                              pf_setup_axes_limits
use figure_plot_items, only : pf_bubbles, pf_digital, pf_line, pf_pie_chart, pf_spec, pf_text
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 440_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 10_int32   !< Cases.
integer(int32), parameter :: NF = 3_int32       !< Frames per side.
integer(int32), parameter :: ND = 24_int32      !< Digital samples.
integer(int32), parameter :: FL_IGNORE_HIDDEN = 2048_int32, FL_EXPLODING = 4096_int32, FL_NO_BORDER = 8192_int32 !<
                                                                                         !< ImPlotPieChartFlags.
real(real64),   parameter :: LEG_X = 90.0_real64  !< The pointer over case 5's first legend entry [pixels].
real(real64),   parameter :: LEG_Y = 40.0_real64  !< ...
real(real64),   parameter :: C(4, 3) = reshape([0.91_real64, 0.40_real64, 0.30_real64, 1.0_real64,  &
                                                0.30_real64, 0.62_real64, 0.85_real64, 1.0_real64,  &
                                                0.35_real64, 0.75_real64, 0.40_real64, 1.0_real64], [4, 3]) !< Colours.
type(app_object)          :: app                !< Application.
character(len=8)          :: slices(5)          !< Slices' labels.
real(real64)              :: big(5), small(5)   !< Pies' values: summing above 1, below 1.
real(real32)              :: big32(5)           !< ... single precision.
real(real64)              :: bxs(6), bys(6), brs(6) !< Bubbles.
real(real32)              :: bxs32(6), bys32(6), brs32(6) !< ... single precision.
real(real64)              :: dx(ND), d1(ND), d2(ND) !< Digital signals.
real(real64)              :: lx(5), ly(5)       !< A line.
real(real64)              :: lim(4, NF, 2)      !< Ranges per frame and side.
logical                   :: test_passed(NCASE) !< Per-case outcome.
logical                   :: side_fortran       !< Drawing with the Fortran frame.
integer(int32)            :: cs, f, s, sd, i    !< Case, frame, status, side, counter.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
slices = ['one  ', 'two  ', 'three', 'four ', 'five ']
big = [3.0_real64, 1.5_real64, 2.25_real64, 0.75_real64, 1.0_real64]
small = [0.1_real64, 0.25_real64, 0.05_real64, 0.2_real64, 0.15_real64]
big32 = real(big, real32)
bxs = [1.0_real64, 2.5_real64, 4.0_real64, 5.5_real64, 7.0_real64, 8.5_real64]
bys = [1.0_real64, 2.0_real64, 1.5_real64, 2.5_real64, 0.5_real64, 1.8_real64]
brs = [0.3_real64, 0.6_real64, 0.2_real64, 0.9_real64, 0.45_real64, 0.05_real64]
bxs32 = real(bxs, real32)
bys32 = real(bys, real32) + 0.3_real32
brs32 = real(brs, real32) * 0.5_real32
do i = 1_int32, ND
   dx(i) = real(i - 1_int32, real64) * 0.4_real64
   d1(i) = real(mod(i / 3_int32, 2_int32), real64)
   d2(i) = real(mod(i, 4_int32), real64) * 0.5_real64
enddo
d2(9) = ieee_value(d2(9), ieee_quiet_nan)
lx = [0.0_real64, 1.0_real64, 2.0_real64, 3.0_real64, 4.0_real64]
ly = [0.0_real64, 0.5_real64, -0.5_real64, 0.25_real64, 0.0_real64]
do cs = 1_int32, NCASE
   lim = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
      side_fortran = sd == 2_int32
      do f = 1_int32, NF
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_misc: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame misc', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(cs, f)
         call ig_end()
         if (f == NF) call test_capture(picture(cs, side_fortran), s)
         if (cs == 5_int32 .and. f == 1_int32) call test_mouse_move(LEG_X, LEG_Y)
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      do i = 1_int32, 40_int32 ! as the other frame tests: the sides apart
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_misc: next_frame returned false headless'
      enddo
   enddo
   test_passed(cs) = ranges_equal(cs)
   test_passed(cs) = pictures_equal(cs) .and. test_passed(cs)
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_misc checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine draw_case(k, fr)
   !< A case's plot on a frame, by the side drawing.
   integer(int32), intent(in) :: k, fr !< Case, frame.

   if (.not. begin(k)) return
   select case (k)
   case (1_int32)
      call limits(-1.5_real64, 1.5_real64, -1.0_real64, 1.0_real64)
      call pie(slices, big, 0.0_real64, 0.0_real64, 0.9_real64)
   case (2_int32)
      call limits(-3.0_real64, 3.0_real64, -1.5_real64, 1.5_real64)
      call pie(slices, small, -1.5_real64, 0.0_real64, 1.0_real64, fmt='%.2f', a0=0.0_real64)
      call pie(['n1', 'n2', 'n3', 'n4', 'n5'], small, 1.5_real64, 0.0_real64, 1.0_real64, norm=.true.)
   case (3_int32)
      call limits(-1.5_real64, 1.5_real64, -1.0_real64, 1.0_real64)
      call pie(slices, big, 0.0_real64, 0.0_real64, 0.9_real64, fmt='', fl=FL_NO_BORDER, viridis=.true.)
   case (4_int32)
      call limits(-1.5_real64, 1.5_real64, -1.0_real64, 1.0_real64)
      call hide()
      call pie(slices, big, 0.0_real64, 0.0_real64, 0.9_real64, fl=FL_IGNORE_HIDDEN)
   case (5_int32)
      call limits(-1.5_real64, 1.5_real64, -1.0_real64, 1.0_real64)
      call pie(slices, big, 0.0_real64, 0.0_real64, 0.8_real64, fl=FL_EXPLODING)
   case (6_int32)
      call limits(0.0_real64, 10.0_real64, 0.0_real64, 3.5_real64)
      call bubbles64('double', C(:, 1), C(:, 2))
      call bubbles32('single')
   case (7_int32)
      call bubbles64('fit', C(:, 3), C(:, 1))
      call text('fit text', 12.0_real64, 4.0_real64)
   case (8_int32)
      call limits(0.0_real64, 10.0_real64, -1.0_real64, 1.0_real64)
      call digital('first', d1, C(:, 1))
      call digital('second', d2, C(:, 2))
   case (9_int32)
      call limits(0.0_real64, 10.0_real64, 0.0_real64, 10.0_real64)
      call text('centred', 5.0_real64, 5.0_real64)
      call text('offset', 2.0_real64, 8.0_real64, [10.0_real64, -6.0_real64])
      call text('vertical', 8.0_real64, 3.0_real64, vertical=.true.)
      call text('vertical offset', 1.0_real64, 3.0_real64, [-4.0_real64, 12.0_real64], vertical=.true.)
   case default
      call limits(-1.5_real64, 4.5_real64, -1.0_real64, 1.0_real64)
      if (side_fortran) then
         call pf_pie_chart(slices, big32, 0.0_real64, 0.0_real64, 0.8_real64)
         call pf_line('line', lx, ly, spec=pf_spec(line_color=C(:, 3)))
      else
         call ip_pie_chart(slices, big32, 0.0_real64, 0.0_real64, 0.8_real64)
         call ip_line('line', lx, ly, spec=ip_spec(line_color=C(:, 3)))
      endif
   endselect
   call finish(k, fr)
   endsubroutine draw_case

   subroutine pie(labels, values, x, y, radius, fmt, a0, norm, fl, viridis)
   !< `ip_pie_chart` or `pf_pie_chart`.
   character(len=*), intent(in)           :: labels(:) !< Labels.
   real(real64),     intent(in)           :: values(:) !< Values.
   real(real64),     intent(in)           :: x, y      !< Centre.
   real(real64),     intent(in)           :: radius    !< Radius.
   character(len=*), intent(in), optional :: fmt       !< Labels' format.
   real(real64),     intent(in), optional :: a0        !< Start [degrees].
   logical,          intent(in), optional :: norm      !< Normalize.
   integer(int32),   intent(in), optional :: fl        !< Flags.
   logical,          intent(in), optional :: viridis   !< The colormap Viridis.
   logical                                :: v         !< Viridis.

   v = .false.
   if (present(viridis)) v = viridis
   if (side_fortran) then
      if (v) then
         call pf_pie_chart(labels, values, x, y, radius, label_format=fmt, angle0=a0, normalize=norm, &
                           colormap=pf_colormap('Viridis'), spec=pf_spec(flags=fl))
      else
         call pf_pie_chart(labels, values, x, y, radius, label_format=fmt, angle0=a0, normalize=norm, &
                           spec=pf_spec(flags=fl))
      endif
   else
      if (v) then
         call ip_pie_chart(labels, values, x, y, radius, label_format=fmt, angle0=a0, normalize=norm, &
                           colormap=ip_colormap('Viridis'), spec=ip_spec(flags=fl))
      else
         call ip_pie_chart(labels, values, x, y, radius, label_format=fmt, angle0=a0, normalize=norm, &
                           spec=ip_spec(flags=fl))
      endif
   endif
   endsubroutine pie

   subroutine bubbles64(label, fc, lc)
   !< `ip_bubbles` or `pf_bubbles`, double precision.
   character(len=*), intent(in) :: label  !< Label.
   real(real64),     intent(in) :: fc(4)  !< Fill colour.
   real(real64),     intent(in) :: lc(4)  !< Line colour.

   if (side_fortran) then
      call pf_bubbles(label, bxs, bys, brs, spec=pf_spec(fill_color=fc, line_color=lc, fill_alpha=0.5_real64))
   else
      call ip_bubbles(label, bxs, bys, brs, spec=ip_spec(fill_color=fc, line_color=lc, fill_alpha=0.5_real64))
   endif
   endsubroutine bubbles64

   subroutine bubbles32(label)
   !< `ip_bubbles` or `pf_bubbles`, single precision, automatic colours.
   character(len=*), intent(in) :: label !< Label.

   if (side_fortran) then
      call pf_bubbles(label, bxs32, bys32, brs32)
   else
      call ip_bubbles(label, bxs32, bys32, brs32)
   endif
   endsubroutine bubbles32

   subroutine digital(label, y, fc)
   !< `ip_digital` or `pf_digital`.
   character(len=*), intent(in) :: label !< Label.
   real(real64),     intent(in) :: y(:)  !< Values.
   real(real64),     intent(in) :: fc(4) !< Fill colour.

   if (side_fortran) then
      call pf_digital(label, dx, y, spec=pf_spec(fill_color=fc, size=10.0_real64))
   else
      call ip_digital(label, dx, y, spec=ip_spec(fill_color=fc, size=10.0_real64))
   endif
   endsubroutine digital

   subroutine text(t, x, y, offset, vertical)
   !< `ip_text` or `pf_text`.
   character(len=*), intent(in)           :: t         !< Text.
   real(real64),     intent(in)           :: x, y      !< Point.
   real(real64),     intent(in), optional :: offset(2) !< Offset.
   logical,          intent(in), optional :: vertical  !< Vertical.

   if (side_fortran) then
      if (present(offset)) then
         call pf_text(t, x, y, offset, vertical)
      else
         call pf_text(t, x, y, vertical=vertical)
      endif
   else ! (absent optionals not passed on: see figure_test_plot_frame_bars on nvfortran)
      if (present(offset)) then
         call ip_text(t, x, y, offset, vertical)
      else
         call ip_text(t, x, y, vertical=vertical)
      endif
   endif
   endsubroutine text

   function begin(k) result(visible)
   !< `ip_begin_plot` or `pf_begin_plot`, 600 x 400, one ID per case.
   integer(int32), intent(in) :: k       !< Case.
   logical                    :: visible !< Plot visible.
   character(len=8)           :: tag     !< The case's number.

   write(tag, '(A,I0)') '##mi', k
   if (side_fortran) then
      visible = pf_begin_plot(trim(tag), width=600.0_real64, height=400.0_real64)
   else
      visible = ip_begin_plot(trim(tag), width=600.0_real64, height=400.0_real64)
   endif
   endfunction begin

   subroutine limits(xmin, xmax, ymin, ymax)
   !< X1 and Y1's ranges, every frame.
   real(real64), intent(in) :: xmin, xmax, ymin, ymax !< Ranges.

   if (side_fortran) then
      call pf_setup_axes_limits(xmin, xmax, ymin, ymax, always=.true.)
   else
      call ip_setup_axes_limits(xmin, xmax, ymin, ymax, always=.true.)
   endif
   endsubroutine limits

   subroutine hide()
   !< `ip_hide_next_item` or `pf_hide_next_item`.

   if (side_fortran) then
      call pf_hide_next_item()
   else
      call ip_hide_next_item()
   endif
   endsubroutine hide

   subroutine finish(k, fr)
   !< The frame's ranges kept and the plot ended.
   integer(int32), intent(in) :: k, fr !< Case, frame.
   integer(int32)             :: m     !< Side.

   if (k < 0_int32) return
   m = merge(2_int32, 1_int32, side_fortran)
   associate(v => lim(:, fr, m))
      if (side_fortran) then
         call pf_plot_limits(v(1), v(2), v(3), v(4), 'x1', 'y1')
         call pf_end_plot()
      else
         call ip_plot_limits(v(1), v(2), v(3), v(4), 'x1', 'y1')
         call ip_end_plot()
      endif
   endassociate
   endsubroutine finish

   function ranges_equal(k) result(ok)
   !< Both sides' ranges equal on every frame.
   integer(int32), intent(in) :: k  !< Case.
   logical                    :: ok !< Equal.
   integer(int32)             :: fr !< Frame.

   ok = .true.
   do fr = 1_int32, NF
      if (all(lim(:, fr, 1) == lim(:, fr, 2))) cycle
      ok = .false.
      write(output_unit, '(A,I0,A,I0,A)') 'case ', k, ', frame ', fr, ': ranges ImPlot, frame'
      write(output_unit, '(4ES24.16)') lim(:, fr, 1)
      write(output_unit, '(4ES24.16)') lim(:, fr, 2)
   enddo
   endfunction ranges_equal

   function pictures_equal(k) result(ok)
   !< The last pictures of both sides equal at the oracle's rule.
   integer(int32), intent(in) :: k   !< Case.
   logical                    :: ok  !< Equal.
   integer(int64)             :: nf_ !< Pixels that failed.
   integer(int32)             :: st  !< Status.

   ok = test_compare_image(picture(k, .true.), picture(k, .false.), threshold=2_int32, max_failed=0_int32, &
                           failed=nf_, stat=st)
   if (.not. ok) write(output_unit, '(A,I0,A,I0,A,A)') 'case ', k, ': ', nf_, ' pixels failed: ', figure_last_error()
   endfunction pictures_equal

   function picture(k, fortran) result(name)
   !< A case's picture: ImPlot's or the Fortran frame's.
   integer(int32), intent(in)    :: k       !< Case.
   logical,        intent(in)    :: fortran !< The Fortran frame's.
   character(len=:), allocatable :: name    !< File name.
   character(len=8)              :: tag     !< The case's number.

   write(tag, '(I0)') k
   if (fortran) then
      name = 'figure_test_plot_frame_misc.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_misc.'//trim(tag)//'.implot.png.tmp'
   endif
   endfunction picture

   subroutine remove_files()
   !< The pictures (a mismatch's .new.png and .diff.png are left for inspection).
   integer(int32) :: unit, ios, k, m !< Unit, status, counters.

   do k = 1_int32, NCASE
      do m = 1_int32, 2_int32
         open(newunit=unit, file=picture(k, m == 1_int32), status='old', iostat=ios)
         if (ios == 0) close(unit, status='delete')
      enddo
   enddo
   endsubroutine remove_files
endprogram figure_test_plot_frame_misc
