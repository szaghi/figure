!< figure_test_plot_frame_rest, the Fortran plot frame's series cache, device lines and last item colour, as ImPlot's.
program figure_test_plot_frame_rest
!< figure_test_plot_frame_rest, the Fortran plot frame's series cache, device lines and last item colour, as ImPlot's.
!<
!< szaghi/figure#15 P11, the rest. Cases drawn on NF frames by ImPlot through FIGURE's API, then by the Fortran frame,
!< in one headless window at the same place; checked: ranges of every frame equal to the bit, the last pictures at
!< FIGURE's oracle rule (|d| <= 2 on every channel, no pixel failing), and:
!<
!< 1. the series cache (`ip_cache_next_item` / `pf_cache_next_item`): a 400 000-point line and a shaded area drawn
!<    on every frame, their data changed on the first frame only: the caches built and reused as many times on both
!<    sides (figure_implot's `plot_cache_builds`, `plot_cache_hits`; the frame's `pf_cache_counts`);
!< 2. lines of arrays "on a device" (`ip_line_device` / `pf_line_device`: in these modes FUNDAL's CPU mode, the
!<    device is the host): a 400 000-point series decimated there, a short unsorted one copied whole, single and
!<    double precision;
!< 3. `pf_last_item_color`: after a line of a given colour, that colour as Dear ImGui packs and unpacks it; after a
!<    hidden item, its colour; zeros after the plot's end.
!<
!< The pictures are `figure_test_plot_frame_rest.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ip_begin_plot,   &
                   ip_cache_next_item, ip_end_plot, ip_hide_next_item, ip_line, ip_line_device, ip_plot_limits, &
                   ip_setup_axes_limits, ip_shaded, ip_spec, ImGuiWindowFlags_NoDecoration
use figure_implot, only : plot_cache_builds, plot_cache_hits
use figure_plot_frame, only : pf_begin_plot, pf_end_plot, pf_hide_next_item, pf_last_item_color, pf_plot_limits, &
                              pf_setup_axes_limits
use figure_plot_items, only : pf_cache_counts, pf_cache_next_item, pf_line, pf_line_device, pf_shaded, pf_spec
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 440_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 3_int32    !< Cases.
integer(int32), parameter :: NF = 4_int32       !< Frames per side.
integer(int32), parameter :: NBIG = 400000_int32 !< Points of a long series.
real(real64),   parameter :: C1(4) = [0.91_real64, 0.40_real64, 0.30_real64, 1.0_real64] !< A colour.
real(real64),   parameter :: C2(4) = [0.30_real64, 0.62_real64, 0.85_real64, 0.8_real64] !< Another.
type(app_object)          :: app                !< Application.
real(real64), allocatable :: xb(:), yb(:), yb2(:) !< Long series.
real(real32), allocatable :: xb32(:), yb32(:)   !< ... single precision.
real(real64)              :: xu(7), yu(7)       !< A short unsorted series.
integer(int64)            :: counts(2, 2)       !< Cache builds, hits per side.
integer(int64)            :: b0, h0             !< Counters before a side.
real(real64)              :: lim(4, NF, 2)      !< Ranges per frame and side.
logical                   :: test_passed(NCASE + 1) !< Per-case outcome, the colours.
logical                   :: colours_ok         !< pf_last_item_color's checks.
logical                   :: side_fortran       !< Drawing with the Fortran frame.
integer(int32)            :: cs, f, s, sd, i    !< Case, frame, status, side, counter.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
allocate(xb(NBIG), yb(NBIG), yb2(NBIG), xb32(NBIG), yb32(NBIG))
do i = 1_int32, NBIG
   xb(i) = 1.0_real64 + real(i - 1_int32, real64) * 1.0e-4_real64
   yb(i) = sin(xb(i) * 3.0_real64) + 0.3_real64 * sin(xb(i) * 401.0_real64)
   yb2(i) = yb(i) - 0.4_real64
enddo
xb32 = real(xb, real32)
yb32 = real(yb, real32) * 0.5_real32
xu = [5.0_real64, 1.0_real64, 30.0_real64, 12.0_real64, 22.0_real64, 8.0_real64, 40.0_real64]
yu = [0.5_real64, -1.0_real64, 1.2_real64, 0.1_real64, -0.6_real64, 0.9_real64, 0.0_real64]
colours_ok = .true.
do cs = 1_int32, NCASE
   lim = 0.0_real64
   counts = 0_int64
   do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
      side_fortran = sd == 2_int32
      call counters(b0, h0)
      do f = 1_int32, NF
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_rest: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame rest', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(cs, f)
         call ig_end()
         if (f == NF) call test_capture(picture(cs, side_fortran), s)
      enddo
      call counters(counts(1, sd), counts(2, sd))
      counts(:, sd) = counts(:, sd) - [b0, h0]
      do i = 1_int32, 40_int32 ! as the other frame tests: the sides apart
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_rest: next_frame returned false headless'
      enddo
   enddo
   test_passed(cs) = ranges_equal(cs) .and. all(counts(:, 1) == counts(:, 2))
   if (.not. all(counts(:, 1) == counts(:, 2))) write(output_unit, '(A,I0,A,4I8)') 'case ', cs, &
                                                    ': cache builds, hits (ImPlot, frame) ', counts
   test_passed(cs) = pictures_equal(cs) .and. test_passed(cs)
enddo
test_passed(NCASE + 1) = colours_ok
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_rest checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine counters(b, h)
   !< The side's cache counters.
   integer(int64), intent(out) :: b, h !< Builds, hits.

   if (side_fortran) then
      call pf_cache_counts(b, h)
   else
      b = plot_cache_builds
      h = plot_cache_hits
   endif
   endsubroutine counters

   subroutine draw_case(k, fr)
   !< A case's plot on a frame, by the side drawing.
   integer(int32), intent(in) :: k, fr !< Case, frame.
   real(real64)               :: got(4) !< A last item colour.

   if (.not. begin(k)) return
   select case (k)
   case (1_int32)
      call limits(1.0_real64, 41.0_real64, -2.0_real64, 2.0_real64)
      if (side_fortran) then
         call pf_cache_next_item(changed=fr == 1_int32)
         call pf_line('cached line', xb, yb, spec=pf_spec(line_color=C1))
         call pf_cache_next_item(changed=fr == 1_int32)
         call pf_shaded('cached area', xb, yb, yb2, spec=pf_spec(fill_color=C2, fill_alpha=0.4_real64))
      else
         call ip_cache_next_item(changed=fr == 1_int32)
         call ip_line('cached line', xb, yb, spec=ip_spec(line_color=C1))
         call ip_cache_next_item(changed=fr == 1_int32)
         call ip_shaded('cached area', xb, yb, yb2, spec=ip_spec(fill_color=C2, fill_alpha=0.4_real64))
      endif
   case (2_int32)
      call limits(0.0_real64, 42.0_real64, -2.0_real64, 2.0_real64)
      if (side_fortran) then
         call pf_line_device('device', xb, yb, spec=pf_spec(line_color=C1))
         call pf_line_device('device r32', xb32, yb32, spec=pf_spec(line_color=C2))
         call pf_line_device('unsorted', xu, yu)
      else
         call ip_line_device('device', xb, yb, spec=ip_spec(line_color=C1))
         call ip_line_device('device r32', xb32, yb32, spec=ip_spec(line_color=C2))
         call ip_line_device('unsorted', xu, yu)
      endif
   case default
      call limits(0.0_real64, 42.0_real64, -2.0_real64, 2.0_real64)
      if (side_fortran) then
         call pf_line('first', xu, yu, spec=pf_spec(line_color=C1))
         got = pf_last_item_color()
         colours_ok = colours_ok .and. all(got == packed(C1))
         call pf_hide_next_item()
         call pf_line('hidden', xu, yu * 0.5_real64, spec=pf_spec(line_color=C2))
         got = pf_last_item_color()
         colours_ok = colours_ok .and. all(got == packed(C2))
      else
         call ip_line('first', xu, yu, spec=ip_spec(line_color=C1))
         call ip_hide_next_item()
         call ip_line('hidden', xu, yu * 0.5_real64, spec=ip_spec(line_color=C2))
      endif
   endselect
   call finish(k, fr)
   if (k == 3_int32 .and. side_fortran) then
      got = pf_last_item_color()
      colours_ok = colours_ok .and. all(got == 0.0_real64)
   endif
   if (.not. colours_ok .and. side_fortran .and. k == 3_int32) write(output_unit, '(A,4F12.8)') 'last item colour ', got
   endsubroutine draw_case

   pure function packed(c) result(v)
   !< A colour as Dear ImGui packs it (`ColorConvertFloat4ToU32`) and unpacks it (`ColorConvertU32ToFloat4`).
   real(real64), intent(in) :: c(4) !< RGBA.
   real(real64)             :: v(4) !< Through the bytes.
   integer(int32)           :: k    !< Channel.
   integer(int32)           :: b    !< Byte.

   do k = 1_int32, 4_int32
      b = int(min(max(real(c(k), real32), 0.0_real32), 1.0_real32) * 255.0_real32 + 0.5_real32, int32)
      v(k) = real(real(b, real32) * (1.0_real32 / 255.0_real32), real64)
   enddo
   endfunction packed

   function begin(k) result(visible)
   !< `ip_begin_plot` or `pf_begin_plot`, 600 x 400, one ID per case.
   integer(int32), intent(in) :: k       !< Case.
   logical                    :: visible !< Plot visible.
   character(len=8)           :: tag     !< The case's number.

   write(tag, '(A,I0)') '##re', k
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
      name = 'figure_test_plot_frame_rest.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_rest.'//trim(tag)//'.implot.png.tmp'
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
endprogram figure_test_plot_frame_rest
