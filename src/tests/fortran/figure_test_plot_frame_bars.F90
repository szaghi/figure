!< figure_test_plot_frame_bars, the Fortran plot frame's bars, bar groups, error bars and infinite lines.
program figure_test_plot_frame_bars
!< figure_test_plot_frame_bars, the Fortran plot frame's bars, bar groups, error bars and infinite lines.
!<
!< szaghi/figure#15 P11, group (b). Each case is a plot drawn on NF frames, first by ImPlot through FIGURE's API
!< (`ip_bars`, `ip_bar_groups`, `ip_error_bars`, `ip_inf_lines`, styles by `ip_spec`), then by the Fortran frame
!< (`pf_*` of figure_plot_items, styles by `pf_spec`), in one headless window at the same place. Checked: the ranges of
!< X1-Y1 on every frame equal to the bit, and the last pictures at FIGURE's oracle rule (|d| <= 2 on every channel, no
!< pixel failing). The cases:
!<
!< 1. bars with a fill and an outline of another colour (weight 2), and automatic bars (fill and outline one colour:
!<    no outline);
!< 2. horizontal bars (`ImPlotBarsFlags_Horizontal`), FillAlpha 0.5;
!< 3. bars narrower than a pixel (ImPlot widens them to one);
!< 4. bar groups side by side, the plot's colours; then with the colormap Viridis;
!< 5. stacked bar groups with negative values, vertical and horizontal;
!< 6. stacked bar groups with the first item hidden (`hide_next_item`: `IsItemHidden` skips its values);
!< 7. error bars, symmetric and asymmetric, the text colour; horizontal ones of a given colour, weight 2, whiskers 8;
!< 8. infinite lines, vertical (real64) and horizontal (int32);
!< 9. the fit (no limits): bars (their half widths), error bars (their ends), infinite lines (x only);
!< 10. the kinds: real32 bars, int32 and int64 positions, real32 bar groups, int64 error bars' abscissae.
!<
!< The data given to the items are arrays or array sections, never elemental expressions of strided sections
!< (nvfortran 26.9 sizes those as their parent: figure_test_plot_frame_items' header); an absent optional array is
!< not passed on to `ip_error_bars`'s `err_high` (nvfortran 26.9 stops there: "TMP_DESC: invalid original").
!<
!< The pictures are `figure_test_plot_frame_bars.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ImGuiWindowFlags_NoDecoration
use figure_implot_ref, only : ip_bar_groups, ip_bars, ip_begin_plot, ip_colormap, ip_end_plot, ip_error_bars, &
                              ip_hide_next_item, ip_inf_lines, ip_plot_limits, ip_setup_axes_limits, ip_spec
use figure_plot_frame, only : pf_begin_plot, pf_colormap, pf_end_plot, pf_hide_next_item, pf_plot_limits, &
                              pf_setup_axes_limits
use figure_plot_items, only : pf_bar_groups, pf_bars, pf_error_bars, pf_inf_lines, pf_spec
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 440_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 10_int32   !< Cases.
integer(int32), parameter :: NF = 3_int32       !< Frames per side.
integer(int32), parameter :: NB = 8_int32       !< Bars.
integer(int32), parameter :: FL_HORIZONTAL = 1024_int32 !< ImPlotBarsFlags_Horizontal (ImPlotErrorBarsFlags_...).
real(real64),   parameter :: C(4, 4) = reshape([0.91_real64, 0.40_real64, 0.30_real64, 1.0_real64,  &
                                                0.30_real64, 0.62_real64, 0.85_real64, 1.0_real64,  &
                                                0.35_real64, 0.75_real64, 0.40_real64, 1.0_real64,  &
                                                0.20_real64, 0.20_real64, 0.20_real64, 1.0_real64], [4, 4]) !< Colours.
type(app_object)          :: app                !< Application.
real(real64)              :: bx(NB), by(NB), by2(NB), err(NB), errh(NB) !< Bars, errors.
real(real32)              :: bx32(NB), by32(NB) !< Single precision.
integer(int32)            :: bxi32(NB)          !< int32 positions.
integer(int64)            :: bxi64(NB)          !< int64 positions.
real(real64)              :: groups(4, 3)       !< values(group, item).
real(real64)              :: signed(4, 3)       !< ... with negatives.
real(real32)              :: groups32(4, 3)     !< ... single precision.
real(real64)              :: vlines(3), tiny_x(NB) !< Infinite lines' positions, narrow bars' positions.
integer(int32)            :: hlines(2)          !< ... horizontal, integer.
character(len=8)          :: names(3)           !< Bar groups' labels.
real(real64)              :: lim(4, NF, 2)      !< Ranges per frame and side.
logical                   :: test_passed(NCASE) !< Per-case outcome.
logical                   :: side_fortran       !< Drawing with the Fortran frame.
integer(int32)            :: cs, f, s, sd, i    !< Case, frame, status, side, counter.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do i = 1_int32, NB
   bx(i) = real(i, real64)
   by(i) = 1.5_real64 + sin(real(i, real64))
   by2(i) = 0.5_real64 * cos(real(i, real64))
   err(i) = 0.1_real64 + 0.05_real64 * real(i, real64)
   errh(i) = 0.3_real64 - 0.02_real64 * real(i, real64)
   bx32(i) = real(bx(i), real32)
   by32(i) = real(by(i), real32)
   bxi32(i) = 2_int32 * i
   bxi64(i) = int(i, int64)
   tiny_x(i) = 1.0_real64 + 0.01_real64 * real(i, real64)
enddo
groups = reshape([1.0_real64, 2.0_real64, 3.0_real64, 2.5_real64, 0.5_real64, 1.5_real64, 2.0_real64, 1.0_real64, &
                  2.0_real64, 1.0_real64, 0.5_real64, 3.0_real64], [4, 3])
signed = reshape([1.0_real64, -2.0_real64, 3.0_real64, -0.5_real64, 0.5_real64, 1.5_real64, -2.0_real64, 1.0_real64, &
                  -1.0_real64, 1.0_real64, 0.5_real64, -3.0_real64], [4, 3])
groups32 = real(groups, real32) * 0.5_real32
names = ['alpha', 'beta ', 'gamma']
vlines = [2.5_real64, 4.0_real64, 6.25_real64]
hlines = [1_int32, 2_int32]
do cs = 1_int32, NCASE
   lim = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
      side_fortran = sd == 2_int32
      do f = 1_int32, NF
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_bars: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame bars', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(cs, f)
         call ig_end()
         if (f == NF) call test_capture(picture(cs, side_fortran), s)
      enddo
      do i = 1_int32, 40_int32 ! as the other frame tests: the sides apart
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_bars: next_frame returned false headless'
      enddo
   enddo
   test_passed(cs) = ranges_equal(cs)
   test_passed(cs) = pictures_equal(cs) .and. test_passed(cs)
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_bars checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine draw_case(k, fr)
   !< A case's plot on a frame, by the side drawing.
   integer(int32), intent(in) :: k, fr !< Case, frame.

   if (.not. begin(k)) return
   select case (k)
   case (1_int32)
      call limits(0.0_real64, 9.0_real64, -1.0_real64, 3.0_real64)
      call bars('outlined', bx, by, 0.6_real64, fc=C(:, 1), lc=C(:, 4), lw=2.0_real64)
      call bars('auto', bx, by2, 0.3_real64)
   case (2_int32)
      call limits(-1.0_real64, 3.0_real64, 0.0_real64, 9.0_real64)
      call bars('horizontal', by, bx, 0.5_real64, fc=C(:, 2), fa=0.5_real64, fl=FL_HORIZONTAL)
   case (3_int32)
      call limits(0.0_real64, 9.0_real64, -1.0_real64, 3.0_real64)
      call bars('narrow', tiny_x, by, 0.001_real64, fc=C(:, 3))
      call bars('wide', bx(5:), by(5:), 0.9_real64, fc=C(:, 1), lc=C(:, 2))
   case (4_int32)
      call limits(-0.5_real64, 3.5_real64, 0.0_real64, 3.5_real64)
      call groups_(names, groups, gs=0.5_real64)
      call groups_(['v1', 'v2', 'v3'], groups, gs=0.8_real64, sh=0.1_real64, viridis=.true.)
   case (5_int32)
      call limits(-1.0_real64, 4.0_real64, -4.0_real64, 5.0_real64)
      call groups_(names, signed, stacked=.true.)
      call groups_(['h1', 'h2', 'h3'], signed, stacked=.true., horizontal=.true., gs=0.4_real64, sh=0.2_real64)
   case (6_int32)
      call limits(-1.0_real64, 4.0_real64, 0.0_real64, 7.0_real64)
      call hide()
      call groups_(names, groups, stacked=.true.)
   case (7_int32)
      call limits(0.0_real64, 9.0_real64, -1.0_real64, 3.5_real64)
      call bars('bars', bx, by, 0.5_real64, fc=C(:, 3), fa=0.4_real64)
      call errors('symmetric', bx, by, err)
      call errors('asymmetric', bx, by2, err, high=errh, lc=C(:, 1))
      call errors('horizontal', bx, by, errh, lc=C(:, 2), lw=2.0_real64, sz=8.0_real64, horizontal=.true.)
   case (8_int32)
      call limits(0.0_real64, 9.0_real64, -1.0_real64, 3.0_real64)
      call inf_v('vertical', vlines)
      call inf_h('horizontal', hlines)
   case (9_int32)
      call bars('fit bars', bx, by, 0.7_real64, fc=C(:, 1))
      call errors('fit errors', bx, by, err)
      call inf_v('fit lines', [-2.0_real64, 12.0_real64])
   case default
      call limits(0.0_real64, 17.0_real64, -1.0_real64, 3.0_real64)
      call kinds()
   endselect
   call finish(k, fr)
   endsubroutine draw_case

   subroutine kinds()
   !< Case 10: every kind of data, on both sides.

   if (side_fortran) then
      call pf_bars('r32', bx32, by32, 0.4_real64, spec=pf_spec(fill_color=C(:, 1)))
      call pf_bars('i32', bxi32, by2, 0.4_real64, spec=pf_spec(fill_color=C(:, 2)))
      call pf_bars('i64', bxi64, by2, 0.2_real64, spec=pf_spec(fill_color=C(:, 3)))
      call pf_error_bars('errors i64', bxi64, by, err, spec=pf_spec(line_color=C(:, 4)))
      call pf_bar_groups(names, groups32, shift=10.0_real64)
      call pf_inf_lines('i64 lines', bxi64(::3))
   else
      call ip_bars('r32', bx32, by32, 0.4_real64, spec=ip_spec(fill_color=C(:, 1)))
      call ip_bars('i32', bxi32, by2, 0.4_real64, spec=ip_spec(fill_color=C(:, 2)))
      call ip_bars('i64', bxi64, by2, 0.2_real64, spec=ip_spec(fill_color=C(:, 3)))
      call ip_error_bars('errors i64', bxi64, by, err, spec=ip_spec(line_color=C(:, 4)))
      call ip_bar_groups(names, groups32, shift=10.0_real64)
      call ip_inf_lines('i64 lines', bxi64(::3))
   endif
   endsubroutine kinds

   function begin(k) result(visible)
   !< `ip_begin_plot` or `pf_begin_plot`, 600 x 400, one ID per case.
   integer(int32), intent(in) :: k       !< Case.
   logical                    :: visible !< Plot visible.
   character(len=8)           :: tag     !< The case's number.

   write(tag, '(A,I0)') '##ba', k
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

   subroutine bars(label, x, y, bar_size, fc, lc, lw, fa, fl)
   !< `ip_bars` or `pf_bars` with a style.
   character(len=*), intent(in)           :: label    !< Label.
   real(real64),     intent(in)           :: x(:)     !< Positions.
   real(real64),     intent(in)           :: y(:)     !< Heights.
   real(real64),     intent(in)           :: bar_size !< Width.
   real(real64),     intent(in), optional :: fc(4)    !< Fill colour.
   real(real64),     intent(in), optional :: lc(4)    !< Line colour.
   real(real64),     intent(in), optional :: lw       !< Line weight.
   real(real64),     intent(in), optional :: fa       !< Fill alpha.
   integer(int32),   intent(in), optional :: fl       !< Flags.

   if (side_fortran) then
      call pf_bars(label, x, y, bar_size, spec=pf_spec(fill_color=fc, line_color=lc, line_weight=lw, fill_alpha=fa, &
                                                       flags=fl))
   else
      call ip_bars(label, x, y, bar_size, spec=ip_spec(fill_color=fc, line_color=lc, line_weight=lw, fill_alpha=fa, &
                                                       flags=fl))
   endif
   endsubroutine bars

   subroutine groups_(labels, values, gs, sh, stacked, horizontal, viridis)
   !< `ip_bar_groups` or `pf_bar_groups`.
   character(len=*), intent(in)           :: labels(:)    !< Labels.
   real(real64),     intent(in)           :: values(:, :) !< Values.
   real(real64),     intent(in), optional :: gs           !< Group size.
   real(real64),     intent(in), optional :: sh           !< Shift.
   logical,          intent(in), optional :: stacked      !< Stacked.
   logical,          intent(in), optional :: horizontal   !< Horizontal.
   logical,          intent(in), optional :: viridis      !< The colormap Viridis.
   logical                                :: v            !< Viridis.

   v = .false.
   if (present(viridis)) v = viridis
   if (side_fortran) then
      if (v) then
         call pf_bar_groups(labels, values, group_size=gs, shift=sh, stacked=stacked, horizontal=horizontal, &
                            colormap=pf_colormap('Viridis'))
      else
         call pf_bar_groups(labels, values, group_size=gs, shift=sh, stacked=stacked, horizontal=horizontal)
      endif
   else
      if (v) then
         call ip_bar_groups(labels, values, group_size=gs, shift=sh, stacked=stacked, horizontal=horizontal, &
                            colormap=ip_colormap('Viridis'))
      else
         call ip_bar_groups(labels, values, group_size=gs, shift=sh, stacked=stacked, horizontal=horizontal)
      endif
   endif
   endsubroutine groups_

   subroutine errors(label, x, y, e, high, lc, lw, sz, horizontal)
   !< `ip_error_bars` or `pf_error_bars` with a style.
   character(len=*), intent(in)           :: label      !< Label.
   real(real64),     intent(in)           :: x(:), y(:) !< Points.
   real(real64),     intent(in)           :: e(:)       !< Errors.
   real(real64),     intent(in), optional :: high(:)    !< Errors above.
   real(real64),     intent(in), optional :: lc(4)      !< Line colour.
   real(real64),     intent(in), optional :: lw         !< Line weight.
   real(real64),     intent(in), optional :: sz         !< Whiskers' size.
   logical,          intent(in), optional :: horizontal !< Along x.

   if (side_fortran) then
      if (present(high)) then
         call pf_error_bars(label, x, y, e, high, spec=pf_spec(line_color=lc, line_weight=lw, size=sz), &
                            horizontal=horizontal)
      else
         call pf_error_bars(label, x, y, e, spec=pf_spec(line_color=lc, line_weight=lw, size=sz), horizontal=horizontal)
      endif
   else ! (an absent `high` not passed on: nvfortran 26.9 stops in ip_error_bars, "TMP_DESC: invalid original")
      if (present(high)) then
         call ip_error_bars(label, x, y, e, high, spec=ip_spec(line_color=lc, line_weight=lw, size=sz), &
                            horizontal=horizontal)
      else
         call ip_error_bars(label, x, y, e, spec=ip_spec(line_color=lc, line_weight=lw, size=sz), horizontal=horizontal)
      endif
   endif
   endsubroutine errors

   subroutine inf_v(label, v)
   !< `ip_inf_lines` or `pf_inf_lines`, vertical.
   character(len=*), intent(in) :: label !< Label.
   real(real64),     intent(in) :: v(:)  !< Positions.

   if (side_fortran) then
      call pf_inf_lines(label, v, spec=pf_spec(line_color=C(:, 1), line_weight=2.0_real64))
   else
      call ip_inf_lines(label, v, spec=ip_spec(line_color=C(:, 1), line_weight=2.0_real64))
   endif
   endsubroutine inf_v

   subroutine inf_h(label, v)
   !< `ip_inf_lines` or `pf_inf_lines`, horizontal, integer positions.
   character(len=*), intent(in) :: label !< Label.
   integer(int32),   intent(in) :: v(:)  !< Positions.

   if (side_fortran) then
      call pf_inf_lines(label, v, horizontal=.true.)
   else
      call ip_inf_lines(label, v, horizontal=.true.)
   endif
   endsubroutine inf_h

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
      name = 'figure_test_plot_frame_bars.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_bars.'//trim(tag)//'.implot.png.tmp'
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
endprogram figure_test_plot_frame_bars
