!< figure_test_plot_frame_items, the Fortran plot frame's lines, markers, scatter, stairs, stems, shaded areas.
program figure_test_plot_frame_items
!< figure_test_plot_frame_items, the Fortran plot frame's lines, markers, scatter, stairs, stems, shaded areas.
!<
!< szaghi/figure#15 P11, group (a). Each case is a plot drawn on NF frames, first by ImPlot through FIGURE's API
!< (`ip_line`, `ip_scatter`, `ip_stairs`, `ip_stems`, `ip_shaded`, styles by `ip_spec`), then by the Fortran frame
!< (`pf_*` of figure_plot_items, styles by `pf_spec` with the same fields), in one headless window at the same place.
!< Checked: the ranges of X1-Y1 on every frame equal to the bit, and the last pictures at FIGURE's oracle rule
!< (|d| <= 2 on every channel, no pixel failing). The cases:
!<
!< 1. lines with markers (circle, square, filled at FillAlpha 0.5, weight 2), given colours;
!< 2. a line's flags: Segments, Loop, SkipNaN (a NaN in the data), Shaded (to y = 0, FillAlpha 0.4);
!< 3. the twelve marker shapes, filled and outlined (scatter), and outlined only (MarkerFillColor transparent);
!< 4. scatter with automatic markers and colours (style 'dark': NextMarker, the colormap), one NoClip at the edges;
!< 5. stairs post and pre step, shaded stairs, stairs with markers (the clip expanded);
!< 6. stems from a reference, horizontal stems;
!< 7. shaded between two crossing curves, against a reference, against -inf and +inf (the plot's edges);
!< 8. the kinds: real32 lines, int32 and int64 abscissae, strided sections (every second element, reversed), values
!<    with xscale and xstart, a matrix's row;
!< 9. the fit of every item (no limits: the plot fits on its first frame), items NoFit and NoLegend;
!< 10. the decimation: a line and a shaded area of 400 000 points (M4 per pixel column), on a linear and a log x axis;
!< 11. a log y axis with markers and stairs;
!< 12. a hovered legend entry: the item's line twice as thick, its markers 1.25 times larger.
!<
!< The data given to the items are arrays or array sections, never elemental expressions of strided sections:
!< nvfortran 26.9 gives `xs(1::4) * 0.25` the extent of `xs` (41 for 11, the rest garbage), as an actual argument and
!< in an assignment to an allocatable (`af` builds them element by element).
!<
!< The pictures are `figure_test_plot_frame_items.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: ieee_arithmetic, only : ieee_negative_inf, ieee_positive_inf, ieee_quiet_nan, ieee_value
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ImGuiWindowFlags_NoDecoration
use figure_implot_ref, only : ip_begin_plot, ip_end_plot, ip_line, ip_plot_limits, ip_scatter, ip_setup_axes, &
                              ip_setup_axes_limits, ip_shaded, ip_spec, ip_stairs, ip_stems
use figure_plot_frame, only : pf_begin_plot, pf_end_plot, pf_plot_limits, pf_setup_axes, pf_setup_axes_limits
use figure_plot_items, only : pf_line, pf_scatter, pf_shaded, pf_spec, pf_stairs, pf_stems
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 440_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 12_int32   !< Cases.
integer(int32), parameter :: NF = 3_int32       !< Frames per side.
integer(int32), parameter :: NP = 41_int32      !< Points of a series.
integer(int32), parameter :: NBIG = 400000_int32 !< Points of a decimated series.
! ImPlotMarker, ImPlot*Flags (implot.h): the same integers on both sides
integer(int32), parameter :: MK_AUTO = -1_int32, MK_CIRCLE = 0_int32, MK_SQUARE = 1_int32 !< Markers.
integer(int32), parameter :: FL_NO_LEGEND = 1_int32, FL_NO_FIT = 2_int32 !< ImPlotItemFlags.
integer(int32), parameter :: FL_SEGMENTS = 1024_int32, FL_LOOP = 2048_int32, FL_SKIP_NAN = 4096_int32 !< Line flags.
integer(int32), parameter :: FL_NO_CLIP = 8192_int32, FL_SHADED = 16384_int32 !< ...
integer(int32), parameter :: FL_SCATTER_NO_CLIP = 1024_int32 !< ImPlotScatterFlags_NoClip.
integer(int32), parameter :: FL_PRE_STEP = 1024_int32, FL_STAIRS_SHADED = 2048_int32 !< ImPlotStairsFlags.
integer(int32), parameter :: FL_HORIZONTAL = 1024_int32 !< ImPlotStemsFlags_Horizontal.
real(real64),   parameter :: C(4, 6) = reshape([0.91_real64, 0.40_real64, 0.30_real64, 1.0_real64,  &
                                                0.30_real64, 0.62_real64, 0.85_real64, 1.0_real64,  &
                                                0.35_real64, 0.75_real64, 0.40_real64, 1.0_real64,  &
                                                0.80_real64, 0.60_real64, 0.20_real64, 1.0_real64,  &
                                                0.55_real64, 0.35_real64, 0.75_real64, 1.0_real64,  &
                                                0.20_real64, 0.20_real64, 0.20_real64, 1.0_real64], [4, 6]) !< Colours.
real(real64),   parameter :: LEG_X = 90.0_real64  !< The pointer over case 12's first legend entry [pixels].
real(real64),   parameter :: LEG_Y = 40.0_real64  !< ...
real(real64),   parameter :: CLEAR(4) = [0.0_real64, 0.0_real64, 0.0_real64, 0.0_real64] !< Transparent.
type(app_object)          :: app                !< Application.
real(real64)              :: xs(NP), ys(NP, 4)  !< Series.
real(real32)              :: xs32(NP), ys32(NP) !< Single precision.
integer(int32)            :: xi32(NP)           !< int32 abscissae.
integer(int64)            :: xi64(NP)           !< int64 abscissae.
real(real64)              :: mat(3, NP)         !< A matrix (rows).
real(real64), allocatable :: xb(:), yb(:), yb2(:) !< The decimated series.
real(real64)              :: yh(NP), xr(NP), yr(NP), yv(NP) !< Case 8's series (named: see the header on nvfortran).
real(real32)              :: y32s(NP), x32s(NP), y32b(NP) !< ...
real(real64)              :: lim(4, NF, 2)      !< Ranges per frame and side.
logical                   :: test_passed(NCASE) !< Per-case outcome.
logical                   :: side_fortran       !< Drawing with the Fortran frame.
integer(int32)            :: cs, f, s, sd, i    !< Case, frame, status, side, counter.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do i = 1_int32, NP
   xs(i) = real(i - 1_int32, real64) * 0.25_real64
   ys(i, 1) = sin(xs(i))
   ys(i, 2) = 0.6_real64 * cos(1.3_real64 * xs(i))
   ys(i, 3) = 0.3_real64 + 0.5_real64 * sin(0.7_real64 * xs(i) + 1.0_real64)
   ys(i, 4) = exp(0.25_real64 * xs(i))
   xs32(i) = real(xs(i), real32)
   ys32(i) = real(ys(i, 2), real32)
   xi32(i) = i - 1_int32
   xi64(i) = int(3_int32 * i, int64)
   mat(:, i) = [ys(i, 1), ys(i, 2), ys(i, 3)]
   yh(i) = ys(i, 1) * 0.5_real64
   xr(i) = xs(i) * 4.0_real64
   yr(i) = ys(i, 2) + 0.7_real64
   yv(i) = ys(i, 3) - 1.0_real64
   y32s(i) = ys32(i) - 0.5_real32
   x32s(i) = xs32(i) + 20.0_real32
   y32b(i) = ys32(i) - 0.3_real32
enddo
allocate(xb(NBIG), yb(NBIG), yb2(NBIG))
do i = 1_int32, NBIG
   xb(i) = 1.0_real64 + real(i - 1_int32, real64) * 1.0e-4_real64
   yb(i) = sin(xb(i) * 3.0_real64) + 0.3_real64 * sin(xb(i) * 401.0_real64)
   yb2(i) = yb(i) - 0.4_real64 - 0.2_real64 * cos(xb(i) * 57.0_real64)
enddo
do cs = 1_int32, NCASE
   if (cs == 4_int32) call app%set_style('dark')
   if (cs == 5_int32) call app%set_style('seal')
   lim = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
      side_fortran = sd == 2_int32
      do f = 1_int32, NF
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_items: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame items', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(cs, f)
         call ig_end()
         if (f == NF) call test_capture(picture(cs, side_fortran), s)
         if (cs == 12_int32 .and. f == 1_int32) call test_mouse_move(LEG_X, LEG_Y)
      enddo
      call test_mouse_move(-100.0_real64, -100.0_real64)
      do i = 1_int32, 40_int32 ! as the other frame tests: the sides apart
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_items: next_frame returned false headless'
      enddo
   enddo
   test_passed(cs) = ranges_equal(cs)
   test_passed(cs) = pictures_equal(cs) .and. test_passed(cs)
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_items checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine draw_case(k, fr)
   !< A case's plot on a frame, by the side drawing.
   integer(int32), intent(in) :: k, fr !< Case, frame.
   real(real64)               :: nan, ninf, pinf !< Specials.
   real(real64)               :: yn(NP)  !< A series with a NaN.
   integer(int32)             :: m       !< Counter.
   character(len=12)          :: tag     !< A label.

   if (.not. begin(k)) return
   select case (k)
   case (1_int32)
      call limits(0.0_real64, 10.0_real64, -1.5_real64, 1.5_real64)
      call line('circles', xs, ys(:, 1), lc=C(:, 1), lw=2.0_real64, mk=MK_CIRCLE, &
                ms=5.0_real64, fa=0.5_real64)
      call line('squares', xs, ys(:, 2), lc=C(:, 2), mk=MK_SQUARE, mfc=C(:, 3))
   case (2_int32)
      nan = ieee_value(nan, ieee_quiet_nan)
      yn = ys(:, 3)
      yn(17) = nan
      call limits(0.0_real64, 10.0_real64, -1.5_real64, 1.5_real64)
      call line('segments', xs, ys(:, 1), lc=C(:, 1), fl=FL_SEGMENTS)
      call line('loop', af(xs(1:12), 0.5_real64, 2.0_real64), ys(1:12, 2), lc=C(:, 2), fl=FL_LOOP)
      call line('skip nan', xs, yn, lc=C(:, 3), fl=FL_SKIP_NAN)
      call line('nan', xs, af(yn, 1.0_real64, -0.6_real64), lc=C(:, 5))
      call line('shaded', xs, af(ys(:, 2), 0.5_real64, 0.0_real64), lc=C(:, 4), fa=0.4_real64, fl=FL_SHADED)
   case (3_int32)
      call limits(-1.0_real64, 12.0_real64, -1.0_real64, 2.5_real64)
      do m = 0_int32, 11_int32
         write(tag, '(A,I0)') 'm', m
         call scatter(trim(tag), [real(m, real64)], [1.5_real64], lc=C(:, 1 + mod(m, 6)), mk=m, ms=7.0_real64, &
                      mfc=C(:, 1 + mod(m + 3, 6)), lw=1.5_real64)
         write(tag, '(A,I0)') 'o', m
         call scatter(trim(tag), [real(m, real64)], [0.0_real64], lc=C(:, 1 + mod(m, 6)), mk=m, ms=6.0_real64, &
                      mfc=CLEAR)
      enddo
   case (4_int32)
      call limits(0.0_real64, 10.0_real64, -1.5_real64, 1.5_real64)
      do m = 1_int32, 4_int32
         write(tag, '(A,I0)') 'auto ', m
         call scatter(trim(tag), xs(m::4), af(ys(m::4, 1 + mod(m, 3)), 1.0_real64, 0.1_real64 * real(m, real64)), &
                      mk=MK_AUTO)
      enddo
      call scatter('no clip', [0.0_real64, 10.0_real64, 5.0_real64], [0.0_real64, 1.5_real64, -1.5_real64], &
                   ms=8.0_real64, fl=FL_SCATTER_NO_CLIP)
   case (5_int32)
      call limits(0.0_real64, 10.0_real64, -1.5_real64, 1.5_real64)
      call stairs('post', xs(::4), ys(::4, 1), lc=C(:, 1), lw=2.0_real64)
      call stairs('pre', xs(::4), ys(::4, 2), lc=C(:, 2), fl=FL_PRE_STEP)
      call stairs('shaded', xs(::4), af(ys(::4, 3), 0.5_real64, 0.0_real64), lc=C(:, 3), fa=0.3_real64, &
                  fl=FL_STAIRS_SHADED)
      call stairs('marked', xs(::5), af(ys(::5, 1), 1.0_real64, -0.5_real64), lc=C(:, 4), mk=MK_CIRCLE, ms=4.0_real64)
   case (6_int32)
      call limits(0.0_real64, 10.0_real64, -1.5_real64, 1.5_real64)
      call stems('stems', xs(::3), ys(::3, 1), ref=-0.25_real64, lc=C(:, 1), mk=MK_CIRCLE)
      call stems('horizontal', af(ys(::4, 2), 3.0_real64, 5.0_real64), af(xs(::4), 0.25_real64, -1.2_real64), &
                 ref=5.0_real64, lc=C(:, 2), mk=MK_SQUARE, fl=FL_HORIZONTAL)
   case (7_int32)
      ninf = ieee_value(ninf, ieee_negative_inf)
      pinf = ieee_value(pinf, ieee_positive_inf)
      call limits(0.0_real64, 10.0_real64, -1.5_real64, 1.5_real64)
      call shaded2('between', xs, ys(:, 1), ys(:, 2), fc=C(:, 1), fa=0.5_real64)
      call shaded1('ref', xs(1:20), af(ys(1:20, 3), 1.0_real64, 0.4_real64), 0.6_real64, fc=C(:, 2), fa=0.5_real64)
      call shaded1('to bottom', xs(21:), af(ys(21:, 3), 1.0_real64, -0.6_real64), ninf, fc=C(:, 3), fa=0.4_real64)
      call shaded1('to top', xs(21:), af(ys(21:, 3), 1.0_real64, 0.6_real64), pinf, fc=C(:, 4), fa=0.4_real64)
   case (8_int32)
      call limits(0.0_real64, 40.0_real64, -1.5_real64, 1.5_real64)
      call kinds()
   case (9_int32)
      call line('fit line', af(xs, 2.0_real64, 0.0_real64), ys(:, 1), lc=C(:, 1), mk=MK_CIRCLE)
      call stems('fit stems', xs(::4), af(ys(::4, 2), 1.0_real64, 2.0_real64), ref=-3.0_real64, lc=C(:, 2))
      call shaded1('fit shaded', xs, ys(:, 3), 4.0_real64, fc=C(:, 3), fa=0.3_real64)
      call line('no fit', af(xs, 10.0_real64, 0.0_real64), af(ys(:, 4), 10.0_real64, 0.0_real64), lc=C(:, 4), &
                fl=FL_NO_FIT)
      call line('no legend', xs, af(ys(:, 2), 1.0_real64, -1.0_real64), lc=C(:, 5), fl=FL_NO_LEGEND)
   case (10_int32)
      call limits(1.0_real64, 41.0_real64, -2.0_real64, 2.0_real64)
      call line('decimated', xb, yb, lc=C(:, 1))
      call shaded2('decimated area', xb, yb, yb2, fc=C(:, 2), fa=0.4_real64)
   case (11_int32)
      call axes_log()
      call limits(0.0_real64, 10.0_real64, 0.5_real64, 20.0_real64)
      call line('exp', xs, ys(:, 4), lc=C(:, 1), mk=MK_CIRCLE, ms=3.0_real64)
      call stairs('steps', xs(::4), af(ys(::4, 4), 0.5_real64, 0.0_real64), lc=C(:, 2), fl=FL_STAIRS_SHADED, &
                  fa=0.3_real64)
   case default
      call limits(0.0_real64, 10.0_real64, -1.5_real64, 1.5_real64)
      call line('hovered', xs, ys(:, 1), lc=C(:, 1), mk=MK_SQUARE, ms=4.0_real64)
      call line('other', xs, ys(:, 2), lc=C(:, 2))
   endselect
   call finish(k, fr)
   endsubroutine draw_case

   subroutine kinds()
   !< Case 8: every kind of data, on both sides.

   if (side_fortran) then
      call pf_line('r32', xs32, ys32, spec=pf_spec(line_color=C(:, 1)))
      call pf_line('i32', xi32, yh, spec=pf_spec(line_color=C(:, 2)))
      call pf_scatter('i64', xi64(::2), ys(::2, 3), spec=pf_spec(marker_line_color=C(:, 3), marker=MK_CIRCLE))
      call pf_stairs('i32 r32', xi32(::3), y32s(::3), spec=pf_spec(line_color=C(:, 4)))
      call pf_line('reversed', xr(NP:1:-1), yr(NP:1:-1), &
                   spec=pf_spec(line_color=C(:, 5)))
      call pf_line('values', yv, xscale=0.75_real64, xstart=2.0_real64, &
                   spec=pf_spec(line_color=C(:, 6)))
      call pf_line('row', mat, 2_int32, xscale=0.5_real64, xstart=10.0_real64, spec=pf_spec(line_color=C(:, 1)))
      call pf_stems('stems i64', xi64(::4), ys(::4, 1), spec=pf_spec(line_color=C(:, 2), marker=MK_SQUARE))
      call pf_shaded('shaded r32', x32s, ys32, y32b, spec=pf_spec(fill_color=C(:, 3)))
   else
      call ip_line('r32', xs32, ys32, spec=ip_spec(line_color=C(:, 1)))
      call ip_line('i32', xi32, yh, spec=ip_spec(line_color=C(:, 2)))
      call ip_scatter('i64', xi64(::2), ys(::2, 3), spec=ip_spec(marker_line_color=C(:, 3), marker=MK_CIRCLE))
      call ip_stairs('i32 r32', xi32(::3), y32s(::3), spec=ip_spec(line_color=C(:, 4)))
      call ip_line('reversed', xr(NP:1:-1), yr(NP:1:-1), &
                   spec=ip_spec(line_color=C(:, 5)))
      call ip_line('values', yv, xscale=0.75_real64, xstart=2.0_real64, &
                   spec=ip_spec(line_color=C(:, 6)))
      call ip_line('row', mat, 2_int32, xscale=0.5_real64, xstart=10.0_real64, spec=ip_spec(line_color=C(:, 1)))
      call ip_stems('stems i64', xi64(::4), ys(::4, 1), spec=ip_spec(line_color=C(:, 2), marker=MK_SQUARE))
      call ip_shaded('shaded r32', x32s, ys32, y32b, spec=ip_spec(fill_color=C(:, 3)))
   endif
   endsubroutine kinds

   function af(a, sc, off) result(r)
   !< a sc + off, element by element (an array, not an expression, given to the items: nvfortran 26.9 sizes an
   !< elemental expression of a strided section as its parent, see the header).
   real(real64), intent(in)  :: a(:)    !< Values.
   real(real64), intent(in)  :: sc, off !< Scale, offset.
   real(real64), allocatable :: r(:)    !< Result.
   integer(int32)            :: j       !< Counter.

   allocate(r(size(a)))
   do j = 1_int32, int(size(a), int32)
      r(j) = a(j) * sc + off
   enddo
   endfunction af

   function begin(k) result(visible)
   !< `ip_begin_plot` or `pf_begin_plot`, 600 x 400, one ID per case.
   integer(int32), intent(in) :: k       !< Case.
   logical                    :: visible !< Plot visible.
   character(len=8)           :: tag     !< The case's number.

   write(tag, '(A,I0)') '##it', k
   if (side_fortran) then
      visible = pf_begin_plot(trim(tag), width=600.0_real64, height=400.0_real64)
   else
      visible = ip_begin_plot(trim(tag), width=600.0_real64, height=400.0_real64)
   endif
   endfunction begin

   subroutine axes_log()
   !< A log y axis.

   if (side_fortran) then
      call pf_setup_axes('', '', yscale='log')
   else
      call ip_setup_axes('', '', yscale='log')
   endif
   endsubroutine axes_log

   subroutine limits(xmin, xmax, ymin, ymax)
   !< X1 and Y1's ranges, every frame.
   real(real64), intent(in) :: xmin, xmax, ymin, ymax !< Ranges.

   if (side_fortran) then
      call pf_setup_axes_limits(xmin, xmax, ymin, ymax, always=.true.)
   else
      call ip_setup_axes_limits(xmin, xmax, ymin, ymax, always=.true.)
   endif
   endsubroutine limits

   subroutine line(label, x, y, lc, lw, fc, fa, mk, ms, mlc, mfc, fl)
   !< `ip_line` or `pf_line` with a style.
   character(len=*), intent(in)           :: label    !< Label.
   real(real64),     intent(in)           :: x(:)     !< Abscissae.
   real(real64),     intent(in)           :: y(:)     !< Ordinates.
   real(real64),     intent(in), optional :: lc(4)    !< Line colour.
   real(real64),     intent(in), optional :: lw       !< Line weight.
   real(real64),     intent(in), optional :: fc(4)    !< Fill colour.
   real(real64),     intent(in), optional :: fa       !< Fill alpha.
   integer(int32),   intent(in), optional :: mk       !< Marker.
   real(real64),     intent(in), optional :: ms       !< Marker size.
   real(real64),     intent(in), optional :: mlc(4)   !< Markers' outline colour.
   real(real64),     intent(in), optional :: mfc(4)   !< Markers' fill colour.
   integer(int32),   intent(in), optional :: fl       !< Flags.

   if (side_fortran) then
      call pf_line(label, x, y, spec=pf_spec(line_color=lc, line_weight=lw, fill_color=fc, fill_alpha=fa, marker=mk, &
                                             marker_size=ms, marker_line_color=mlc, marker_fill_color=mfc, flags=fl))
   else
      call ip_line(label, x, y, spec=ip_spec(line_color=lc, line_weight=lw, fill_color=fc, fill_alpha=fa, marker=mk, &
                                             marker_size=ms, marker_line_color=mlc, marker_fill_color=mfc, flags=fl))
   endif
   endsubroutine line

   subroutine scatter(label, x, y, lc, lw, mk, ms, mfc, fl)
   !< `ip_scatter` or `pf_scatter` with a style (the markers' outline colour `lc`).
   character(len=*), intent(in)           :: label  !< Label.
   real(real64),     intent(in)           :: x(:)   !< Abscissae.
   real(real64),     intent(in)           :: y(:)   !< Ordinates.
   real(real64),     intent(in), optional :: lc(4)  !< Markers' outline colour.
   real(real64),     intent(in), optional :: lw     !< Line weight.
   integer(int32),   intent(in), optional :: mk     !< Marker.
   real(real64),     intent(in), optional :: ms     !< Marker size.
   real(real64),     intent(in), optional :: mfc(4) !< Markers' fill colour.
   integer(int32),   intent(in), optional :: fl     !< Flags.

   if (side_fortran) then
      call pf_scatter(label, x, y, spec=pf_spec(marker_line_color=lc, line_weight=lw, marker=mk, marker_size=ms, &
                                                marker_fill_color=mfc, flags=fl))
   else
      call ip_scatter(label, x, y, spec=ip_spec(marker_line_color=lc, line_weight=lw, marker=mk, marker_size=ms, &
                                                marker_fill_color=mfc, flags=fl))
   endif
   endsubroutine scatter

   subroutine stairs(label, x, y, lc, lw, fa, mk, ms, fl)
   !< `ip_stairs` or `pf_stairs` with a style.
   character(len=*), intent(in)           :: label !< Label.
   real(real64),     intent(in)           :: x(:)  !< Abscissae.
   real(real64),     intent(in)           :: y(:)  !< Ordinates.
   real(real64),     intent(in), optional :: lc(4) !< Line colour.
   real(real64),     intent(in), optional :: lw    !< Line weight.
   real(real64),     intent(in), optional :: fa    !< Fill alpha.
   integer(int32),   intent(in), optional :: mk    !< Marker.
   real(real64),     intent(in), optional :: ms    !< Marker size.
   integer(int32),   intent(in), optional :: fl    !< Flags.

   if (side_fortran) then
      call pf_stairs(label, x, y, spec=pf_spec(line_color=lc, line_weight=lw, fill_alpha=fa, marker=mk, &
                                               marker_size=ms, flags=fl))
   else
      call ip_stairs(label, x, y, spec=ip_spec(line_color=lc, line_weight=lw, fill_alpha=fa, marker=mk, &
                                               marker_size=ms, flags=fl))
   endif
   endsubroutine stairs

   subroutine stems(label, x, y, ref, lc, mk, fl)
   !< `ip_stems` or `pf_stems` with a style.
   character(len=*), intent(in)           :: label !< Label.
   real(real64),     intent(in)           :: x(:)  !< Abscissae.
   real(real64),     intent(in)           :: y(:)  !< Ordinates.
   real(real64),     intent(in), optional :: ref   !< Base.
   real(real64),     intent(in), optional :: lc(4) !< Line colour.
   integer(int32),   intent(in), optional :: mk    !< Marker.
   integer(int32),   intent(in), optional :: fl    !< Flags.

   if (side_fortran) then
      call pf_stems(label, x, y, ref=ref, spec=pf_spec(line_color=lc, marker=mk, flags=fl))
   else
      call ip_stems(label, x, y, ref=ref, spec=ip_spec(line_color=lc, marker=mk, flags=fl))
   endif
   endsubroutine stems

   subroutine shaded2(label, x, y1, y2, fc, fa)
   !< `ip_shaded` or `pf_shaded` between two curves.
   character(len=*), intent(in)           :: label  !< Label.
   real(real64),     intent(in)           :: x(:)   !< Abscissae.
   real(real64),     intent(in)           :: y1(:)  !< First curve.
   real(real64),     intent(in)           :: y2(:)  !< Second curve.
   real(real64),     intent(in), optional :: fc(4)  !< Fill colour.
   real(real64),     intent(in), optional :: fa     !< Fill alpha.

   if (side_fortran) then
      call pf_shaded(label, x, y1, y2, spec=pf_spec(fill_color=fc, fill_alpha=fa))
   else
      call ip_shaded(label, x, y1, y2, spec=ip_spec(fill_color=fc, fill_alpha=fa))
   endif
   endsubroutine shaded2

   subroutine shaded1(label, x, y, yref, fc, fa)
   !< `ip_shaded` or `pf_shaded` against a reference line.
   character(len=*), intent(in)           :: label  !< Label.
   real(real64),     intent(in)           :: x(:)   !< Abscissae.
   real(real64),     intent(in)           :: y(:)   !< Curve.
   real(real64),     intent(in)           :: yref   !< Reference.
   real(real64),     intent(in), optional :: fc(4)  !< Fill colour.
   real(real64),     intent(in), optional :: fa     !< Fill alpha.

   if (side_fortran) then
      call pf_shaded(label, x, y, yref, spec=pf_spec(fill_color=fc, fill_alpha=fa))
   else
      call ip_shaded(label, x, y, yref, spec=ip_spec(fill_color=fc, fill_alpha=fa))
   endif
   endsubroutine shaded1

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
      name = 'figure_test_plot_frame_items.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_items.'//trim(tag)//'.implot.png.tmp'
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
endprogram figure_test_plot_frame_items
