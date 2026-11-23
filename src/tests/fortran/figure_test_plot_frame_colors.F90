!< figure_test_plot_frame_colors, the Fortran plot frame's colormaps: the style's line colours and colour bars.
program figure_test_plot_frame_colors
!< figure_test_plot_frame_colors, the Fortran plot frame's colormaps: the style's line colours and colour bars.
!<
!< szaghi/figure#15 P10, step 7. Each case is a few frames drawn twice in one headless window, at the same place:
!< first by ImPlot through FIGURE's API (`ip_begin_plot`, `ip_line` without a colour, `ip_end_plot`, `ip_colormap`,
!< `ip_colormap_scale`), then by the Fortran frame (`pf_*`, figure_plot_colormaps); the pictures of the last frame
!< compared at FIGURE's oracle rule (|d| <= 2 on every channel, no pixel failing). The cases:
!<
!< 1. FIGURE's default style seal: nine lines of automatic colours (its eight line colours, the ninth the first
!<    again), their legend; 2. the style 'dark' (no line colours of its own: ImPlot's Deep); 3. seal again (the
!<    style's map registered once, used again); 4. a colour bar of the default map (Viridis) on [0, 1], labelled;
!<    5. Deep (qualitative: a strip per key) on [-5, 5], 120 x 380 pixels; 6. Viridis on a reversed range [10, -10];
!<    7. a label format '%.2f K' and no label ('##'); 8. a bundled map (inferno, FIGURE's table); 9. Viridis in 6
!<    bands (`levels`); 10. a bundled map reversed (cool-warm_r).
!<
!< The pictures are `figure_test_plot_frame_colors.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them; a
!< mismatch's .new.png and .diff.png are left for inspection).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ip_begin_plot, ip_colormap, &
                   ip_colormap_scale, ip_end_plot, ip_line, ip_setup_axes_limits, ImGuiWindowFlags_NoDecoration
use figure_plot_frame, only : pf_begin_plot, pf_colormap, pf_colormap_scale, pf_end_plot, pf_setup_axes_limits
use figure_plot_items, only : pf_line
use figure_testing, only : test_capture, test_compare_image, test_mouse_move

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 440_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 10_int32   !< Cases.
integer(int32), parameter :: NF = 3_int32       !< Frames per side.
integer(int32), parameter :: NP = 101_int32     !< Points of a line.
type(app_object)          :: app                !< Application.
real(real64)              :: xs(NP), ys(NP, 9)  !< The lines.
logical                   :: test_passed(NCASE) !< Per-case outcome.
logical                   :: side_fortran       !< Drawing with the Fortran frame.
integer(int32)            :: c, f, s, sd, i, j  !< Case, frame, status, side, counters.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do i = 1_int32, NP
   xs(i) = real(i - 1_int32, real64) * 0.1_real64
   do j = 1_int32, 9_int32
      ys(i, j) = sin(xs(i) + 0.6_real64 * real(j, real64)) * (1.0_real64 - 0.08_real64 * real(j, real64))
   enddo
enddo
do c = 1_int32, NCASE
   if (c == 2_int32) call app%set_style('dark')
   if (c == 3_int32) call app%set_style('seal')
   do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
      side_fortran = sd == 2_int32
      do f = 1_int32, NF
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_colors: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame colors', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(c)
         call ig_end()
         if (f == NF) call test_capture(picture(c, side_fortran), s)
      enddo
   enddo
   if (.not. app%next_frame()) error stop 'figure_test_plot_frame_colors: next_frame returned false headless' ! renders
   test_passed(c) = pictures_equal(c)
enddo
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_colors checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine draw_case(k)
   !< A case's plot or colour bar, by the side drawing.
   integer(int32), intent(in) :: k !< Case.
   character(len=8)           :: tag !< A number.
   integer(int32)             :: n, m !< Lines, counter.

   select case (k)
   case (1_int32, 2_int32, 3_int32)
      write(tag, '(I0)') k
      n = merge(9_int32, 3_int32, k == 1_int32)
      if (side_fortran) then
         if (pf_begin_plot('##c'//trim(tag), width=600.0_real64, height=400.0_real64)) then
            call pf_setup_axes_limits(0.0_real64, 10.0_real64, -1.2_real64, 1.2_real64, always=.true.)
            do m = 1_int32, n
               write(tag, '(A,I0)') 'line ', m
               call pf_line(trim(tag), xs, ys(:, m))
            enddo
            call pf_end_plot()
         endif
      else
         if (ip_begin_plot('##c'//trim(tag), width=600.0_real64, height=400.0_real64)) then
            call ip_setup_axes_limits(0.0_real64, 10.0_real64, -1.2_real64, 1.2_real64, always=.true.)
            do m = 1_int32, n
               write(tag, '(A,I0)') 'line ', m
               call ip_line(trim(tag), xs, ys(:, m))
            enddo
            call ip_end_plot()
         endif
      endif
   case (4_int32)
      call scale('Viridis', 0.0_real64, 1.0_real64)
   case (5_int32)
      call scale('Deep', -5.0_real64, 5.0_real64, map=colormap('Deep'), width=120.0_real64, height=380.0_real64)
   case (6_int32)
      call scale('reversed', 10.0_real64, -10.0_real64)
   case (7_int32)
      call scale('##no label', 273.15_real64, 373.15_real64, fmt='%.2f K')
   case (8_int32)
      call scale('inferno', 0.0_real64, 100.0_real64, map=colormap('inferno'))
   case (9_int32)
      call scale('Viridis in 6 bands', 0.0_real64, 6.0_real64, map=colormap('Viridis', 6_int32))
   case default
      call scale('cool-warm_r', -1.0_real64, 1.0_real64, map=colormap('cool-warm_r'))
   endselect
   endsubroutine draw_case

   function colormap(name, levels) result(id)
   !< `ip_colormap` or `pf_colormap`.
   character(len=*), intent(in)           :: name   !< Name.
   integer(int32),   intent(in), optional :: levels !< Bands.
   integer(int32)                         :: id     !< Id.

   if (side_fortran) then
      id = pf_colormap(name, levels)
   else
      id = ip_colormap(name, levels)
   endif
   endfunction colormap

   subroutine scale(label, vmin, vmax, map, width, height, fmt)
   !< `ip_colormap_scale` or `pf_colormap_scale`.
   character(len=*), intent(in)           :: label         !< Label.
   real(real64),     intent(in)           :: vmin, vmax    !< Range.
   integer(int32),   intent(in), optional :: map           !< Colormap.
   real(real64),     intent(in), optional :: width, height !< Size.
   character(len=*), intent(in), optional :: fmt           !< Label format.

   if (side_fortran) then
      call pf_colormap_scale(label, vmin, vmax, width=width, height=height, label_format=fmt, colormap=map)
   else
      call ip_colormap_scale(label, vmin, vmax, width=width, height=height, label_format=fmt, colormap=map)
   endif
   endsubroutine scale

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
      name = 'figure_test_plot_frame_colors.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_colors.'//trim(tag)//'.implot.png.tmp'
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
endprogram figure_test_plot_frame_colors
