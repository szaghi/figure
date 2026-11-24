!< figure_test_plot_frame_fields, the Fortran plot frame's heatmaps and histograms (1-D, 2-D), as ImPlot's.
program figure_test_plot_frame_fields
!< figure_test_plot_frame_fields, the Fortran plot frame's heatmaps and histograms (1-D, 2-D), as ImPlot's.
!<
!< szaghi/figure#15 P11, group (d). Each case is a plot drawn on NF frames, first by ImPlot through FIGURE's API
!< (`ip_heatmap`, `ip_histogram`, `ip_histogram2d`), then by the Fortran frame (`pf_*` of figure_plot_items), in one
!< headless window at the same place. Checked: the ranges of X1-Y1 on every frame equal to the bit, the histograms'
!< `max_count` equal, and the last pictures at FIGURE's oracle rule (|d| <= 2 on every channel, no pixel failing):
!<
!< 1. a heatmap, its scale from the data, Viridis, its values printed ('%.1f');
!< 2. a heatmap with a given scale in Jet, single precision;
!< 3. a constant heatmap (one rectangle of the map's first colour), beside a column-major one;
!< 4. a histogram, Sturges' bins over the values' range;
!< 5. a histogram of 20 bins over a given range, cumulative and density, horizontal;
!< 6. a histogram with NaN values, Scott's rule, bars 0.8 of a bin, NoOutliers and density;
!< 7. a 2-D histogram, default bins and range;
!< 8. a 2-D histogram of given bins and range, density, in Hot;
!< 9. the fit (no limits): a heatmap and a histogram;
!< 10. single precision histograms, 1-D and 2-D.
!<
!< The pictures are `figure_test_plot_frame_fields.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: ieee_arithmetic, only : ieee_quiet_nan, ieee_value
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ImGuiWindowFlags_NoDecoration
use figure_implot_ref, only : ip_begin_plot, ip_colormap, ip_end_plot, ip_heatmap, ip_histogram, ip_histogram2d, &
                              ip_plot_limits, ip_setup_axes_limits, ip_spec
use figure_plot_frame, only : pf_begin_plot, pf_colormap, pf_end_plot, pf_plot_limits, pf_setup_axes_limits
use figure_plot_items, only : pf_heatmap, pf_histogram, pf_histogram2d, pf_spec
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 440_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 10_int32   !< Cases.
integer(int32), parameter :: NF = 3_int32       !< Frames per side.
integer(int32), parameter :: NV = 500_int32     !< Histogram values.
integer(int32), parameter :: FL_HORIZONTAL = 1024_int32, FL_CUMULATIVE = 2048_int32, FL_DENSITY = 4096_int32 !<
                                                                                        !< ImPlotHistogramFlags.
integer(int32), parameter :: FL_NO_OUTLIERS = 8192_int32 !< ImPlotHistogramFlags_NoOutliers.
integer(int32), parameter :: FL_HEAT_COL_MAJOR = 1024_int32 !< ImPlotHeatmapFlags_ColMajor.
integer(int32), parameter :: BIN_SCOTT = -4_int32 !< ImPlotBin_Scott.
type(app_object)          :: app                !< Application.
real(real64)              :: field(6, 4), flat(3, 2) !< Heatmaps.
real(real32)              :: field32(5, 7)      !< ... single precision.
real(real64)              :: vals(NV), vx(NV), vy(NV) !< Histograms' values, points.
real(real32)              :: vals32(NV), vx32(NV), vy32(NV) !< ... single precision.
real(real64)              :: tops(2)            !< max_count per side.
real(real64)              :: lim(4, NF, 2)      !< Ranges per frame and side.
logical                   :: test_passed(NCASE) !< Per-case outcome.
logical                   :: side_fortran       !< Drawing with the Fortran frame.
integer(int32)            :: cs, f, s, sd, i, j !< Case, frame, status, side, counters.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do j = 1_int32, 4_int32
   do i = 1_int32, 6_int32
      field(i, j) = sin(0.7_real64 * real(i, real64)) * cos(0.5_real64 * real(j, real64)) * 10.0_real64
   enddo
enddo
flat = 2.5_real64
do j = 1_int32, 7_int32
   do i = 1_int32, 5_int32
      field32(i, j) = real(i * j, real32) * 0.1_real32
   enddo
enddo
do i = 1_int32, NV ! deterministic, spread values
   vals(i) = sin(real(i, real64) * 0.37_real64) * 3.0_real64 + cos(real(i, real64) * 0.11_real64)
   vx(i) = cos(real(i, real64) * 0.23_real64) * 2.0_real64 + 0.3_real64 * sin(real(i, real64) * 1.7_real64)
   vy(i) = sin(real(i, real64) * 0.19_real64) * 1.5_real64 + 0.2_real64 * cos(real(i, real64) * 2.3_real64)
enddo
vals32 = real(vals, real32)
vx32 = real(vx, real32)
vy32 = real(vy, real32)
do cs = 1_int32, NCASE
   lim = 0.0_real64
   tops = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
      side_fortran = sd == 2_int32
      do f = 1_int32, NF
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_fields: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame fields', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(cs, f)
         call ig_end()
         if (f == NF) call test_capture(picture(cs, side_fortran), s)
      enddo
      do i = 1_int32, 40_int32 ! as the other frame tests: the sides apart
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_fields: next_frame returned false headless'
      enddo
   enddo
   test_passed(cs) = ranges_equal(cs) .and. tops(1) == tops(2)
   if (tops(1) /= tops(2)) write(output_unit, '(A,I0,A,2ES24.16)') 'case ', cs, ': max_count ', tops
   test_passed(cs) = pictures_equal(cs) .and. test_passed(cs)
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_fields checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine draw_case(k, fr)
   !< A case's plot on a frame, by the side drawing.
   integer(int32), intent(in) :: k, fr !< Case, frame.
   real(real64)               :: nan, top !< A NaN, a max_count.
   real(real64)               :: vn(NV)   !< Values with NaNs.

   if (.not. begin(k)) return
   top = 0.0_real64
   select case (k)
   case (1_int32)
      call limits(0.0_real64, 6.0_real64, 0.0_real64, 4.0_real64)
      if (side_fortran) then
         call pf_heatmap('field', field, 0.0_real64, 6.0_real64, 0.0_real64, 4.0_real64, label_format='%.1f')
      else
         call ip_heatmap('field', field, 0.0_real64, 6.0_real64, 0.0_real64, 4.0_real64, label_format='%.1f')
      endif
   case (2_int32)
      call limits(-1.0_real64, 6.0_real64, -1.0_real64, 8.0_real64)
      if (side_fortran) then
         call pf_heatmap('jet', field32, 0.0_real64, 5.0_real64, 0.0_real64, 7.0_real64, scale_min=0.5_real64, &
                         scale_max=3.0_real64, colormap=pf_colormap('Jet'))
      else
         call ip_heatmap('jet', field32, 0.0_real64, 5.0_real64, 0.0_real64, 7.0_real64, scale_min=0.5_real64, &
                         scale_max=3.0_real64, colormap=ip_colormap('Jet'))
      endif
   case (3_int32)
      call limits(0.0_real64, 8.0_real64, 0.0_real64, 4.0_real64)
      if (side_fortran) then
         call pf_heatmap('flat', flat, 0.0_real64, 3.0_real64, 0.0_real64, 2.0_real64)
         call pf_heatmap('col major', field, 4.0_real64, 8.0_real64, 0.0_real64, 4.0_real64, &
                         spec=pf_spec(flags=FL_HEAT_COL_MAJOR))
      else
         call ip_heatmap('flat', flat, 0.0_real64, 3.0_real64, 0.0_real64, 2.0_real64)
         call ip_heatmap('col major', field, 4.0_real64, 8.0_real64, 0.0_real64, 4.0_real64, &
                         spec=ip_spec(flags=FL_HEAT_COL_MAJOR))
      endif
   case (4_int32)
      call limits(-5.0_real64, 5.0_real64, 0.0_real64, 120.0_real64)
      if (side_fortran) then
         call pf_histogram('sturges', vals, max_count=top)
      else
         call ip_histogram('sturges', vals, max_count=top)
      endif
   case (5_int32)
      call limits(0.0_real64, 1.2_real64, -5.0_real64, 5.0_real64)
      if (side_fortran) then
         call pf_histogram('cumulative', vals, bins=20_int32, vmin=-4.0_real64, vmax=4.0_real64, max_count=top, &
                           spec=pf_spec(flags=ior(ior(FL_CUMULATIVE, FL_DENSITY), FL_HORIZONTAL)))
      else
         call ip_histogram('cumulative', vals, bins=20_int32, vmin=-4.0_real64, vmax=4.0_real64, max_count=top, &
                           spec=ip_spec(flags=ior(ior(FL_CUMULATIVE, FL_DENSITY), FL_HORIZONTAL)))
      endif
   case (6_int32)
      nan = ieee_value(nan, ieee_quiet_nan)
      vn = vals
      vn(::7) = nan
      call limits(-5.0_real64, 5.0_real64, 0.0_real64, 0.5_real64)
      if (side_fortran) then
         call pf_histogram('scott', vn, bins=BIN_SCOTT, bar_scale=0.8_real64, max_count=top, vmin=-3.0_real64, &
                           vmax=3.0_real64, spec=pf_spec(flags=ior(FL_NO_OUTLIERS, FL_DENSITY)))
      else
         call ip_histogram('scott', vn, bins=BIN_SCOTT, bar_scale=0.8_real64, max_count=top, vmin=-3.0_real64, &
                           vmax=3.0_real64, spec=ip_spec(flags=ior(FL_NO_OUTLIERS, FL_DENSITY)))
      endif
   case (7_int32)
      call limits(-3.0_real64, 3.0_real64, -2.0_real64, 2.0_real64)
      if (side_fortran) then
         call pf_histogram2d('points', vx, vy, max_count=top)
      else
         call ip_histogram2d('points', vx, vy, max_count=top)
      endif
   case (8_int32)
      call limits(-3.0_real64, 3.0_real64, -2.0_real64, 2.0_real64)
      if (side_fortran) then
         call pf_histogram2d('hot', vx, vy, xbins=12_int32, ybins=8_int32, xmin=-2.5_real64, xmax=2.5_real64, &
                             ymin=-1.5_real64, ymax=1.5_real64, colormap=pf_colormap('Hot'), max_count=top, &
                             spec=pf_spec(flags=FL_DENSITY))
      else
         call ip_histogram2d('hot', vx, vy, xbins=12_int32, ybins=8_int32, xmin=-2.5_real64, xmax=2.5_real64, &
                             ymin=-1.5_real64, ymax=1.5_real64, colormap=ip_colormap('Hot'), max_count=top, &
                             spec=ip_spec(flags=FL_DENSITY))
      endif
   case (9_int32)
      if (side_fortran) then
         call pf_heatmap('fit field', field, -2.0_real64, 4.0_real64, 1.0_real64, 3.0_real64)
         call pf_histogram('fit histogram', vals, max_count=top)
      else
         call ip_heatmap('fit field', field, -2.0_real64, 4.0_real64, 1.0_real64, 3.0_real64)
         call ip_histogram('fit histogram', vals, max_count=top)
      endif
   case default
      call limits(-5.0_real64, 5.0_real64, -3.0_real64, 120.0_real64)
      if (side_fortran) then
         call pf_histogram('single', vals32, max_count=top)
         call pf_histogram2d('single 2d', vx32, vy32, colormap=pf_colormap('Viridis'))
      else
         call ip_histogram('single', vals32, max_count=top)
         call ip_histogram2d('single 2d', vx32, vy32, colormap=ip_colormap('Viridis'))
      endif
   endselect
   tops(merge(2_int32, 1_int32, side_fortran)) = top
   call finish(k, fr)
   endsubroutine draw_case

   function begin(k) result(visible)
   !< `ip_begin_plot` or `pf_begin_plot`, 600 x 400, one ID per case.
   integer(int32), intent(in) :: k       !< Case.
   logical                    :: visible !< Plot visible.
   character(len=8)           :: tag     !< The case's number.

   write(tag, '(A,I0)') '##fi', k
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
      name = 'figure_test_plot_frame_fields.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_fields.'//trim(tag)//'.implot.png.tmp'
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
endprogram figure_test_plot_frame_fields
