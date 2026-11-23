!< figure_test_plot_frame_images, the Fortran plot frame's images and field images, as ImPlot's.
program figure_test_plot_frame_images
!< figure_test_plot_frame_images, the Fortran plot frame's images and field images, as ImPlot's.
!<
!< szaghi/figure#15 P11, group (d). Each case is a plot drawn on NF frames, first by ImPlot through FIGURE's API
!< (`ip_image`, `ip_field_image`: native/figure_field.cpp's colouring), then by the Fortran frame (`pf_image`,
!< `pf_field_image`: figure_plot_field's), in one headless window at the same place. Checked: the ranges of X1-Y1 on
!< every frame equal to the bit, the fields' applied ranges equal, and the last pictures at FIGURE's oracle rule
!< (|d| <= 2 on every channel, no pixel failing):
!<
!< 1. a 4 x 3 texture scaled up, nearest (the texture's own filter, `core_texture_sampling`);
!< 2. the same texture smooth (linear filtering);
!< 3. a field, linear, its range from the data, NaNs in a given colour;
!< 4. a field on a log scale (values <= 0 and NaN masked), vmin given, Jet;
!< 5. a field on a symlog scale across zero, single precision, Plasma;
!< 6. a 400 x 400 field on a log scale (the bit table: 160 000 values);
!< 7. the fit (no limits) of an image and a field;
!< 8. the cache: a field drawn on every frame of the case uploaded once (`changed` absent), then once more with
!<    `changed=.true.`.
!< After the cases: 700 frames without fields (past the 10 s idle time), then one field: the caches hold one colouring
!< on both sides (the idle ones released).
!<
!< `ip_image` takes no tint (FIGURE's API draws images white): no tinted case.
!<
!< The pictures are `figure_test_plot_frame_images.*.png.tmp`, removed at the end (FIGURE_TEST_KEEP=1 keeps them).
use, intrinsic :: ieee_arithmetic, only : ieee_quiet_nan, ieee_value
use, intrinsic :: iso_fortran_env, only : int8, int32, int64, real32, real64, output_unit
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ip_begin_plot, ip_colormap, &
                   ip_end_plot, ip_field_image, ip_image, ip_plot_limits, ip_setup_axes_limits, texture_object,  &
                   ImGuiWindowFlags_NoDecoration
use figure_plot_frame, only : pf_begin_plot, pf_colormap, pf_end_plot, pf_plot_limits, pf_setup_axes_limits
use figure_plot_items, only : pf_field_count, pf_field_image, pf_field_uploads, pf_image
use figure_testing, only : test_capture, test_compare_image, test_field_textures, test_mouse_move

implicit none
integer(int32), parameter :: W = 640_int32      !< Display width [pixels].
integer(int32), parameter :: H = 440_int32      !< Display height [pixels].
integer(int32), parameter :: NCASE = 8_int32    !< Cases.
integer(int32), parameter :: NF = 3_int32       !< Frames per side.
integer(int32), parameter :: NB = 400_int32     !< The large field's side.
real(real64),   parameter :: RED(4) = [1.0_real64, 0.0_real64, 0.0_real64, 1.0_real64] !< NaN colour.
type(app_object)          :: app                !< Application.
type(texture_object)      :: sharp, smooth      !< Textures: nearest, linear.
integer(int8)             :: pixels(4, 4, 3)    !< Their pixels.
real(real64)              :: fa(8, 6), fl(7, 5), big(NB, NB) !< Fields.
real(real32)              :: fs(9, 7)           !< ... single precision.
real(real64)              :: ranges(2, 2)       !< The fields' applied ranges per side.
integer(int64)            :: up0                !< Frame-side uploads before a case.
real(real64)              :: lim(4, NF, 2)      !< Ranges per frame and side.
logical                   :: test_passed(NCASE + 1) !< Per-case outcome, the idle release.
logical                   :: side_fortran       !< Drawing with the Fortran frame.
integer(int32)            :: cs, f, s, sd, i, j !< Case, frame, status, side, counters.
character(len=16)         :: keep               !< FIGURE_TEST_KEEP.

call app%init_headless(W, H)
call test_mouse_move(-100.0_real64, -100.0_real64)
do j = 1_int32, 3_int32
   do i = 1_int32, 4_int32
      pixels(1, i, j) = byte(mod(60 * i, 256))
      pixels(2, i, j) = byte(mod(80 * j, 256))
      pixels(3, i, j) = byte(mod(40 * (i + j), 256))
      pixels(4, i, j) = byte(255)
   enddo
enddo
call sharp%init(4_int32, 3_int32)
call sharp%update(pixels)
call smooth%init(4_int32, 3_int32, smooth=.true.)
call smooth%update(pixels)
do j = 1_int32, 6_int32
   do i = 1_int32, 8_int32
      fa(i, j) = sin(0.6_real64 * real(i, real64)) + cos(0.9_real64 * real(j, real64))
   enddo
enddo
fa(3, 2) = ieee_value(fa(3, 2), ieee_quiet_nan)
do j = 1_int32, 5_int32
   do i = 1_int32, 7_int32
      fl(i, j) = 10.0_real64**(real(i + j, real64) * 0.4_real64 - 2.0_real64)
   enddo
enddo
fl(1, 1) = 0.0_real64
fl(2, 3) = -1.0_real64
fl(5, 4) = ieee_value(fl(5, 4), ieee_quiet_nan)
do j = 1_int32, 7_int32
   do i = 1_int32, 9_int32
      fs(i, j) = real((i - 5) * (j - 3), real32) * 2.5_real32
   enddo
enddo
do j = 1_int32, NB
   do i = 1_int32, NB
      big(i, j) = exp(real(i, real64) * 0.03_real64) * (1.0_real64 + sin(real(j, real64) * 0.05_real64)) + 1.0e-3_real64
   enddo
enddo
do cs = 1_int32, NCASE
   lim = 0.0_real64
   ranges = 0.0_real64
   do sd = 1_int32, 2_int32 ! 1 ImPlot, 2 the Fortran frame
      side_fortran = sd == 2_int32
      up0 = pf_field_uploads()
      do f = 1_int32, NF
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_images: next_frame returned false headless'
         call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
         if (ig_begin('plot frame images', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(cs, f)
         call ig_end()
         if (f == NF) call test_capture(picture(cs, side_fortran), s)
      enddo
      do i = 1_int32, 40_int32 ! as the other frame tests: the sides apart
         if (.not. app%next_frame()) error stop 'figure_test_plot_frame_images: next_frame returned false headless'
      enddo
   enddo
   test_passed(cs) = ranges_equal(cs) .and. all(ranges(:, 1) == ranges(:, 2))
   if (.not. all(ranges(:, 1) == ranges(:, 2))) write(output_unit, '(A,I0,A,4ES24.16)') 'case ', cs, ': ranges ', ranges
   if (cs == 8_int32) then ! uploaded once over the frames, once more when changed
      test_passed(cs) = test_passed(cs) .and. pf_field_uploads() - up0 == 2_int64
      if (pf_field_uploads() - up0 /= 2_int64) write(output_unit, '(A,I0)') 'case 8: uploads ', pf_field_uploads() - up0
   endif
   test_passed(cs) = pictures_equal(cs) .and. test_passed(cs)
enddo
do i = 1_int32, 700_int32 ! past the idle time (10 s at 1/60 s a frame)
   if (.not. app%next_frame()) error stop 'figure_test_plot_frame_images: next_frame returned false headless'
enddo
do sd = 1_int32, 2_int32
   side_fortran = sd == 2_int32
   if (.not. app%next_frame()) error stop 'figure_test_plot_frame_images: next_frame returned false headless'
   call ig_set_next_window(0.0_real64, 0.0_real64, real(W, real64), real(H, real64), always=.true.)
   if (ig_begin('plot frame images', flags=ImGuiWindowFlags_NoDecoration)) call draw_case(9_int32, 1_int32)
   call ig_end()
enddo
if (.not. app%next_frame()) error stop 'figure_test_plot_frame_images: next_frame returned false headless' ! sweeps
test_passed(NCASE + 1) = pf_field_count() == 1_int32 .and. test_field_textures() == 1_int32
if (.not. test_passed(NCASE + 1)) write(output_unit, '(A,2I4)') 'idle release: cached fields (frame, native) ', &
                                                                pf_field_count(), test_field_textures()
call sharp%destroy()
call smooth%destroy()
call app%destroy()
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_plot_frame_images checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   pure function byte(v) result(b)
   !< A channel 0-255 as a signed byte.
   integer, intent(in) :: v !< Value.
   integer(int8)       :: b !< Byte.

   b = int(merge(v - 256, v, v > 127), int8)
   endfunction byte

   subroutine draw_case(k, fr)
   !< A case's plot on a frame, by the side drawing.
   integer(int32), intent(in) :: k, fr !< Case, frame.
   integer(int32)             :: m     !< Side.

   if (.not. begin(k)) return
   m = merge(2_int32, 1_int32, side_fortran)
   select case (k)
   case (1_int32)
      call limits(0.0_real64, 4.0_real64, 0.0_real64, 3.0_real64)
      call image('sharp', sharp)
   case (2_int32)
      call limits(0.0_real64, 4.0_real64, 0.0_real64, 3.0_real64)
      call image('smooth', smooth)
   case (3_int32)
      call limits(0.0_real64, 8.0_real64, 0.0_real64, 6.0_real64)
      if (side_fortran) then
         call pf_field_image('linear', fa, 0.0_real64, 8.0_real64, 0.0_real64, 6.0_real64, nan_color=RED, &
                             range=ranges(:, m))
      else
         call ip_field_image('linear', fa, 0.0_real64, 8.0_real64, 0.0_real64, 6.0_real64, nan_color=RED, &
                             range=ranges(:, m))
      endif
   case (4_int32)
      call limits(0.0_real64, 7.0_real64, 0.0_real64, 5.0_real64)
      if (side_fortran) then
         call pf_field_image('log', fl, 0.0_real64, 7.0_real64, 0.0_real64, 5.0_real64, colormap=pf_colormap('Jet'), &
                             vmin=1.0e-2_real64, scale='log', nan_color=RED, range=ranges(:, m))
      else
         call ip_field_image('log', fl, 0.0_real64, 7.0_real64, 0.0_real64, 5.0_real64, colormap=ip_colormap('Jet'), &
                             vmin=1.0e-2_real64, scale='log', nan_color=RED, range=ranges(:, m))
      endif
   case (5_int32)
      call limits(-1.0_real64, 10.0_real64, -1.0_real64, 8.0_real64)
      if (side_fortran) then
         call pf_field_image('symlog', fs, 0.0_real64, 9.0_real64, 0.0_real64, 7.0_real64, &
                             colormap=pf_colormap('Plasma'), scale='symlog', range=ranges(:, m))
      else
         call ip_field_image('symlog', fs, 0.0_real64, 9.0_real64, 0.0_real64, 7.0_real64, &
                             colormap=ip_colormap('Plasma'), scale='symlog', range=ranges(:, m))
      endif
   case (6_int32)
      call limits(0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64)
      if (side_fortran) then
         call pf_field_image('large', big, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, scale='log', &
                             range=ranges(:, m))
      else
         call ip_field_image('large', big, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, scale='log', &
                             range=ranges(:, m))
      endif
   case (7_int32)
      call image('fit image', sharp, -2.0_real64, 3.0_real64, 1.0_real64, 4.0_real64)
      if (side_fortran) then
         call pf_field_image('fit field', fa, 4.0_real64, 9.0_real64, -1.0_real64, 2.0_real64, range=ranges(:, m))
      else
         call ip_field_image('fit field', fa, 4.0_real64, 9.0_real64, -1.0_real64, 2.0_real64, range=ranges(:, m))
      endif
   case (8_int32)
      call limits(0.0_real64, 8.0_real64, 0.0_real64, 6.0_real64)
      if (side_fortran) then
         call pf_field_image('cached', fa, 0.0_real64, 8.0_real64, 0.0_real64, 6.0_real64, changed=fr == NF, &
                             range=ranges(:, m))
      else
         call ip_field_image('cached', fa, 0.0_real64, 8.0_real64, 0.0_real64, 6.0_real64, changed=fr == NF, &
                             range=ranges(:, m))
      endif
   case default ! the idle probe
      if (side_fortran) then
         call pf_field_image('probe', fs, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64)
      else
         call ip_field_image('probe', fs, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64)
      endif
   endselect
   call finish(k, fr)
   endsubroutine draw_case

   subroutine image(label, tex, x0, x1, y0, y1)
   !< `ip_image` or `pf_image` (default: over the plot's limits [0, 4] x [0, 3]).
   character(len=*),     intent(in)           :: label  !< Label.
   type(texture_object), intent(in)           :: tex    !< Texture.
   real(real64),         intent(in), optional :: x0, x1, y0, y1 !< Edges.
   real(real64)                               :: e(4)   !< Edges.

   e = [0.0_real64, 4.0_real64, 0.0_real64, 3.0_real64]
   if (present(x0)) e = [x0, x1, y0, y1]
   if (side_fortran) then
      call pf_image(label, tex, e(1), e(2), e(3), e(4))
   else
      call ip_image(label, tex, e(1), e(2), e(3), e(4))
   endif
   endsubroutine image

   function begin(k) result(visible)
   !< `ip_begin_plot` or `pf_begin_plot`, 600 x 400, one ID per case.
   integer(int32), intent(in) :: k       !< Case.
   logical                    :: visible !< Plot visible.
   character(len=8)           :: tag     !< The case's number.

   write(tag, '(A,I0)') '##im', k
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
      name = 'figure_test_plot_frame_images.'//trim(tag)//'.fortran.png.tmp'
   else
      name = 'figure_test_plot_frame_images.'//trim(tag)//'.implot.png.tmp'
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
endprogram figure_test_plot_frame_images
