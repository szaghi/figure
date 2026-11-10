!< figure_test_fields, a field through a colormap (ip_field_image) and the legend the user drags (S14), headless.
program figure_test_fields
!< figure_test_fields, a field through a colormap (ip_field_image) and the legend the user drags (S14), headless.
!<
!< 1. colours: values at the range's ends get the colormap's ends, values beyond them are clamped, a value in between
!<    gets the colour ImPlot samples at its fraction (real64 and real32); vmin > vmax turns the map over; without vmin
!<    and vmax the range is the data's; NaN and infinite values get nan_color (transparent by default); on 'log' values
!<    <= 0 are masked to nan_color and 10 is the middle of [1, 100]; on 'symlog' 0 is the middle of [-100, 100];
!< 2. the texture is not coloured again while nothing changes (the upload counter), and is when changed, vmax, the
!<    colormap, the scale, the NaN colour or the array change;
!< 3. 1024 x 1024 fields coloured within a time measured here (linear real32, log real32 by the bit table, linear
!<    real64), the log one equal to the colours sampled per pixel within one step;
!< 4. textures not drawn for 10 s released, the two drawn every frame (one label in two plots) kept, each its own,
!<    and not coloured again;
!< 5. the legend the user edits: a drag along the bar moves the range by the drag, the wheel zooms it about the value
!<    under the pointer, on 'log' by factors; the legend reports a change only on the frames it happened;
!< 6. wrong calls.
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64, output_unit
use, intrinsic :: iso_c_binding, only : c_float, c_int
use, intrinsic :: ieee_arithmetic, only : ieee_value, ieee_quiet_nan, ieee_positive_inf, ieee_negative_inf
use figure, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, app_object, ig_begin, ig_end, ig_item_rect, ig_line_height, ig_same_line, &
                   ig_set_next_window, &
                   ip_begin_plot, ip_end_plot, ip_colormap, ip_colormap_legend, ip_colormap_legend_edit, ip_field_image
use figure_cimgui, only : im_vec4
use figure_cimplot, only : ImPlot_SampleColormap
use figure_testing, only : test_drag, test_field_pixel, test_field_textures, test_field_time, test_field_uploads, &
                           test_mouse_move, test_next_frame, test_wheel

implicit none
integer(int32), parameter :: NE = 14_int32                   !< Wrong calls checked.
integer(int32), parameter :: NB = 1024_int32                 !< Side of the big fields.
real(real64),   parameter :: MAGENTA(4) = [1.0_real64, 0.0_real64, 1.0_real64, 1.0_real64] !< A NaN colour.
real(real64),   parameter :: GREEN(4) = [0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64]   !< Another.
real(real64),   parameter :: TOL = 1.0e-6_real64             !< Same 8-bit colour.
real(real64),   parameter :: STEP = 1.0_real64 / 255.0_real64 + 1.0e-6_real64 !< One step of a channel.
real(real64),   parameter :: BOUND_MS = 500.0_real64          !< Time allowed for a 1024 x 1024 colouring [ms].
type(app_object)            :: app                 !< Application.
logical                     :: ok(16)              !< Per-check outcome.
integer(int32)              :: cmap                !< cividis.
integer(int32)              :: cmap2               !< magma.
real(real64)                :: ends(3, 2)          !< Values around [0, 1].
real(real32)                :: ends32(3, 2)        !< The same, single precision.
real(real64)                :: auto(3, 1)          !< A field without range.
real(real64)                :: nanf(4, 1)          !< NaN, +Inf, -Inf, 0.5.
real(real64)                :: logf(6, 1)          !< 1, 10, 100, 0, -5, NaN.
real(real64)                :: logauto(4, 1)       !< 0, 0.01, 1, 100.
real(real64)                :: sym(4, 1)           !< -100, 0, 100, 10.
real(real64)                :: cnt(4, 4)           !< The field of the upload counter.
real(real64)                :: cnt2(4, 4)          !< Another array of its shape.
real(real32), allocatable   :: big32(:,:)          !< 1024 x 1024, single precision.
real(real32), allocatable   :: big_log(:,:)        !< ... positive, 6 decades.
real(real64), allocatable   :: big64(:,:)          !< ... double precision.
real(real64)                :: px(4, 24)           !< Pixels read.
real(real64)                :: rauto(2)            !< Range applied to `auto`.
real(real64)                :: rlog(2)             !< ... to `logauto`.
integer(int64)              :: up(4:16)            !< Uploads after each frame of phase 2.
integer(int64)              :: up_keep(2)          !< Uploads around the idle phase.
real(real64)                :: ms(3)               !< Colouring times [ms].
real(real64)                :: lut_err             !< Largest difference of the log field from per-pixel colours.
integer(int32)              :: textures(2)         !< Textures kept before and after the idle phase.
real(real64)                :: lo, hi              !< The edited range.
real(real64)                :: llo, lhi            !< The edited log range.
real(real64)                :: flo, fhi            !< A legend not edited.
real(real64)                :: lo0, hi0            !< The range before the drag.
real(real64)                :: lo1, hi1            !< ... after it.
real(real64)                :: lo2, hi2            !< ... after the wheel.
real(real64)                :: llo1, lhi1          !< The log range after its drag.
real(real64)                :: bar(4)              !< The edited legend's rectangle: x0, y0, x1, y1 [pixels].
real(real64)                :: lbar(4)             !< The log legend's.
real(real64)                :: fbar(4)             !< The fixed legend's.
real(real64)                :: pv                  !< The value under the pointer before the wheel.
real(real64)                :: th = 0.0_real64     !< Text line height [pixels].
real(real64)                :: sp                  !< The value the wheel zoomed about.
integer(int32)              :: changes             !< Frames the edited legend reported a change.
integer(int32)              :: lchanges            !< ... the log legend.
integer(int32)              :: st(NE)              !< Statuses of the wrong calls.
integer(int32)              :: want(NE)            !< ... expected.
real(real64)                :: nan, pinf, ninf     !< Special values.
integer(int32)              :: frame               !< Frame counter.
integer(int32)              :: i, j                !< Counters.

nan = ieee_value(1.0_real64, ieee_quiet_nan)
pinf = ieee_value(1.0_real64, ieee_positive_inf)
ninf = ieee_value(1.0_real64, ieee_negative_inf)
ends = reshape([0.0_real64, 0.5_real64, 1.0_real64, -1.0_real64, 2.0_real64, 0.25_real64], [3, 2])
ends32 = real(ends, real32)
auto(:, 1) = [2.0_real64, 4.0_real64, 6.0_real64]
nanf(:, 1) = [nan, pinf, ninf, 0.5_real64]
logf(:, 1) = [1.0_real64, 10.0_real64, 100.0_real64, 0.0_real64, -5.0_real64, nan]
logauto(:, 1) = [0.0_real64, 0.01_real64, 1.0_real64, 100.0_real64]
sym(:, 1) = [-100.0_real64, 0.0_real64, 100.0_real64, 10.0_real64]
cnt = reshape([(real(i, real64), i = 1, 16)], [4, 4])
cnt2 = -cnt
allocate(big32(NB, NB), big_log(NB, NB), big64(NB, NB))
do j = 1_int32, NB
   do i = 1_int32, NB
      big64(i, j) = sin(0.01_real64 * i) * cos(0.013_real64 * j)
      big_log(i, j) = real(10.0_real64**(-3.0_real64 + 6.0_real64 * real((j - 1) * NB + i - 1, real64) / &
                                         real(NB * NB, real64)), real32)
   enddo
enddo
big32 = real(big64, real32)
ok = .false.
px = -1.0_real64
st = -99_int32
changes = 0_int32
lchanges = 0_int32
lo = 0.0_real64
hi = 1.0_real64
llo = 1.0_real64
lhi = 1000.0_real64
flo = 0.0_real64
fhi = 1.0_real64

call app%init_headless(800_int32, 600_int32)
cmap = ip_colormap('cividis')
cmap2 = ip_colormap('magma')
do frame = 1_int32, 700_int32
   if (.not. app%next_frame()) error stop 'figure_test_fields: next_frame returned false in headless mode'
   call ig_set_next_window(10.0_real64, 10.0_real64, 760.0_real64, 560.0_real64, always=.true.)
   if (ig_begin('Fields')) then
      select case (frame)
      case (1_int32:2_int32)
         call colours(frame == 2_int32)
      case (4_int32:16_int32)
         call counter(frame)
      case (17_int32:19_int32)
         call big(frame)
      case (20_int32:640_int32)
         call idle(frame)
      case (641_int32:690_int32)
         call legends(frame)
      case (691_int32)
         call wrong_calls()
      endselect
   endif
   call ig_end()
enddo

! 1. colours (the expected colours sampled from ImPlot: before app%destroy)
ok(1) = same(px(:, 1), sample(cmap, 0.0_real64)) .and. same(px(:, 2), sample(cmap, 1.0_real64)) .and. &
        same(px(:, 3), sample(cmap, 0.5_real64)) .and. same(px(:, 4), sample(cmap, 0.25_real64))
ok(2) = same(px(:, 5), sample(cmap, 0.0_real64)) .and. same(px(:, 6), sample(cmap, 1.0_real64))   ! clamped
ok(3) = same(px(:, 7), sample(cmap, 0.0_real64)) .and. same(px(:, 8), sample(cmap, 1.0_real64)) .and. & ! real32
        same(px(:, 9), sample(cmap, 1.0_real64)) .and. &                                                 ! reversed
        same(px(:, 10), sample(cmap, 0.0_real64)) .and. same(px(:, 11), sample(cmap, 1.0_real64)) .and. & ! auto
        all(abs(rauto - [2.0_real64, 6.0_real64]) < TOL)
ok(4) = same(px(:, 12), MAGENTA) .and. same(px(:, 13), MAGENTA) .and. same(px(:, 14), MAGENTA) .and. &
        same(px(:, 15), sample(cmap, 0.5_real64)) .and. abs(px(4, 16)) < TOL           ! default: transparent
ok(5) = same(px(:, 17), sample(cmap, 0.0_real64)) .and. same(px(:, 18), sample(cmap, 0.5_real64)) .and. &
        same(px(:, 19), sample(cmap, 1.0_real64)) .and. same(px(:, 20), GREEN) .and. same(px(:, 21), GREEN) .and. &
        all(abs(rlog - [0.01_real64, 100.0_real64]) < TOL) .and. same(px(:, 22), sample(cmap, 0.5_real64))
ok(6) = same(px(:, 23), sample(cmap, 0.5_real64)) .and. &
        maxval(abs(px(:, 24) - sample(cmap, (asinh(5.0_real64) + asinh(50.0_real64)) / (2.0_real64 * asinh(50.0_real64))))) &
        <= 2.0_real64 * STEP
! 2. uploads
ok(7) = up(8) == up(4)                        ! nothing changed for 4 frames
ok(8) = up(9) - up(8) == 1_int64 .and. up(10) - up(9) == 1_int64 .and. up(11) - up(10) == 1_int64 .and. &
        up(12) - up(11) == 1_int64 .and. up(13) - up(12) == 1_int64 .and. up(14) - up(13) == 1_int64 .and. &
        up(16) == up(14)
! 3. big fields
ok(9) = all(ms > 0.0_real64) .and. all(ms < BOUND_MS)
ok(10) = lut_err <= STEP
! 4. idle textures
ok(11) = textures(1) >= 10_int32 .and. textures(2) == 2_int32 .and. up_keep(2) - up_keep(1) == 2_int64
! 5. legends
sp = (1.1_real64 * lo2 - lo1) / 0.1_real64 ! the fixed point of the zoom
ok(12) = abs((lo1 - lo0) - (-60.0_real64 / (bar(4) - bar(2) - lh()) * (hi0 - lo0))) <= 0.03_real64 * (hi0 - lo0) .and. &
         abs((hi1 - lo1) - (hi0 - lo0)) < 1.0e-9_real64
ok(13) = abs((hi2 - lo2) - (hi1 - lo1) / 1.1_real64) < 1.0e-9_real64 .and. &
         abs(sp - pv) <= 2.0_real64 / (bar(4) - bar(2) - lh()) * (hi1 - lo1)
ok(14) = llo1 < 1.0_real64 .and. llo1 > 0.0_real64 .and. abs(lhi1 / llo1 - 1000.0_real64) < 1.0e-6_real64
ok(15) = changes == 2_int32 .and. lchanges == 1_int32 .and. flo == 0.0_real64 .and. fhi == 1.0_real64
! 6. wrong calls
want = [FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, &
        FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_ERR_ARGUMENT,     &
        FIG_ERR_ARGUMENT, FIG_ERR_ARGUMENT]
ok(16) = all(st == want)
call app%destroy()

write(output_unit, '(A,2F10.4)') 'range of a field without vmin, vmax ', rauto
write(output_unit, '(A,2F10.4)') 'range of a log field without them   ', rlog
write(output_unit, '(A,13I4)')   'uploads, frames 4-16                ', up - up(4)
write(output_unit, '(A,3F10.3)') '1024^2 coloured [ms]: lin32 log32 lin64 ', ms
write(output_unit, '(A,F10.6)')  'log field by the bit table vs per pixel, max ', lut_err
write(output_unit, '(A,2I4)')    'textures kept before and after 10 s idle ', textures
write(output_unit, '(A,4F12.6)') 'edited range: before, after the drag', lo0, hi0, lo1, hi1
write(output_unit, '(A,4F12.6)') 'after the wheel; its fixed point, the pointer', lo2, hi2, sp, pv
write(output_unit, '(A,2F12.6)') 'log range after its drag            ', llo1, lhi1
write(output_unit, '(A,2I4)')    'frames reporting a change           ', changes, lchanges
do i = 1_int32, NE
   if (st(i) /= want(i)) write(output_unit, '(A,I0,A,I0,A,I0,A)') 'wrong call ', i, ': stat ', st(i), ' (want ', &
                                                                 want(i), ')'
enddo
do i = 1_int32, size(ok)
   write(output_unit, '(A,I0,A,L1)') 'check ', i, ': ', ok(i)
enddo
if (.not. all(ok)) error stop 'figure_test_fields: FAILED'
write(output_unit, '(A)') 'figure_test_fields: all checks passed'

contains
   function sample(c, t) result(rgba)
   !< ImPlot's colour of the colormap `c` at the fraction `t`.
   integer(int32), intent(in) :: c       !< Colormap.
   real(real64),   intent(in) :: t       !< Fraction in [0, 1].
   real(real64)               :: rgba(4) !< Colour.
   type(im_vec4)              :: v       !< ImPlot's.

   call ImPlot_SampleColormap(real(t, c_float), int(c, c_int), v)
   rgba = real([v%x, v%y, v%z, v%w], real64)
   endfunction sample

   pure function same(a, b) result(yes)
   !< Two colours equal to 8 bits.
   real(real64), intent(in) :: a(4) !< A colour.
   real(real64), intent(in) :: b(4) !< Another.
   logical                  :: yes  !< Equal.

   yes = all(abs(a - b) < 0.5_real64 / 255.0_real64)
   endfunction same

   function lh() result(h)
   !< The text line height [pixels], read in phase 5: the legend's bar is shorter than the item by one.
   real(real64) :: h !< Height.

   h = th
   endfunction lh

   subroutine colours(read)
   !< Phase 1: the fields of known values, read back on the second frame.
   logical, intent(in) :: read !< Read the pixels.

   if (ip_begin_plot('colours', 700.0_real64, 500.0_real64)) then
      call ip_field_image('ends', ends, 0.0_real64, 3.0_real64, 0.0_real64, 2.0_real64, colormap=cmap, &
                          vmin=0.0_real64, vmax=1.0_real64)
      call ip_field_image('ends32', ends32, 0.0_real64, 3.0_real64, 2.0_real64, 4.0_real64, colormap=cmap, &
                          vmin=0.0_real64, vmax=1.0_real64)
      call ip_field_image('reversed', ends, 3.0_real64, 6.0_real64, 0.0_real64, 2.0_real64, colormap=cmap, &
                          vmin=1.0_real64, vmax=0.0_real64)
      call ip_field_image('auto', auto, 3.0_real64, 6.0_real64, 2.0_real64, 3.0_real64, colormap=cmap, range=rauto)
      call ip_field_image('nan', nanf, 0.0_real64, 4.0_real64, 4.0_real64, 5.0_real64, colormap=cmap, &
                          vmin=0.0_real64, vmax=1.0_real64, nan_color=MAGENTA)
      call ip_field_image('nan default', nanf, 0.0_real64, 4.0_real64, 5.0_real64, 6.0_real64, colormap=cmap, &
                          vmin=0.0_real64, vmax=1.0_real64)
      call ip_field_image('log', logf, 0.0_real64, 6.0_real64, 6.0_real64, 7.0_real64, colormap=cmap, &
                          vmin=1.0_real64, vmax=100.0_real64, scale='log', nan_color=GREEN)
      call ip_field_image('log auto', logauto, 0.0_real64, 4.0_real64, 7.0_real64, 8.0_real64, colormap=cmap, &
                          scale='log', range=rlog)
      call ip_field_image('symlog', sym, 0.0_real64, 4.0_real64, 8.0_real64, 9.0_real64, colormap=cmap, &
                          vmin=-100.0_real64, vmax=100.0_real64, scale='symlog')
      call ip_end_plot()
   endif
   if (.not. read) return
   call test_field_pixel('ends', 1_int32, 1_int32, px(:, 1))
   call test_field_pixel('ends', 3_int32, 1_int32, px(:, 2))
   call test_field_pixel('ends', 2_int32, 1_int32, px(:, 3))
   call test_field_pixel('ends', 3_int32, 2_int32, px(:, 4))
   call test_field_pixel('ends', 1_int32, 2_int32, px(:, 5))
   call test_field_pixel('ends', 2_int32, 2_int32, px(:, 6))
   call test_field_pixel('ends32', 1_int32, 1_int32, px(:, 7))
   call test_field_pixel('ends32', 3_int32, 1_int32, px(:, 8))
   call test_field_pixel('reversed', 1_int32, 1_int32, px(:, 9))
   call test_field_pixel('auto', 1_int32, 1_int32, px(:, 10))
   call test_field_pixel('auto', 3_int32, 1_int32, px(:, 11))
   call test_field_pixel('nan', 1_int32, 1_int32, px(:, 12))
   call test_field_pixel('nan', 2_int32, 1_int32, px(:, 13))
   call test_field_pixel('nan', 3_int32, 1_int32, px(:, 14))
   call test_field_pixel('nan', 4_int32, 1_int32, px(:, 15))
   call test_field_pixel('nan default', 1_int32, 1_int32, px(:, 16))
   call test_field_pixel('log', 1_int32, 1_int32, px(:, 17))
   call test_field_pixel('log', 2_int32, 1_int32, px(:, 18))
   call test_field_pixel('log', 3_int32, 1_int32, px(:, 19))
   call test_field_pixel('log', 4_int32, 1_int32, px(:, 20))
   call test_field_pixel('log', 5_int32, 1_int32, px(:, 21))
   call test_field_pixel('log auto', 3_int32, 1_int32, px(:, 22))
   call test_field_pixel('symlog', 2_int32, 1_int32, px(:, 23))
   call test_field_pixel('symlog', 4_int32, 1_int32, px(:, 24))
   endsubroutine colours

   subroutine counter(frame)
   !< Phase 2: one field drawn every frame, one input changed on each of frames 9-14.
   integer(int32), intent(in) :: frame !< Frame.

   if (ip_begin_plot('counter', 700.0_real64, 500.0_real64)) then
      select case (frame)
      case (9_int32)
         call ip_field_image('count', cnt, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, colormap=cmap, &
                             vmin=0.0_real64, vmax=16.0_real64, changed=.true.)
      case (10_int32)
         call ip_field_image('count', cnt, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, colormap=cmap, &
                             vmin=0.0_real64, vmax=17.0_real64)
      case (11_int32)
         call ip_field_image('count', cnt, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, colormap=cmap2, &
                             vmin=0.0_real64, vmax=17.0_real64)
      case (12_int32)
         call ip_field_image('count', cnt, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, colormap=cmap2, &
                             vmin=0.0_real64, vmax=17.0_real64, scale='symlog')
      case (13_int32)
         call ip_field_image('count', cnt, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, colormap=cmap2, &
                             vmin=0.0_real64, vmax=17.0_real64, scale='symlog', nan_color=GREEN)
      case (14_int32:16_int32)
         call ip_field_image('count', cnt2, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, colormap=cmap2, &
                             vmin=0.0_real64, vmax=17.0_real64, scale='symlog', nan_color=GREEN)
      case default
         call ip_field_image('count', cnt, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, colormap=cmap, &
                             vmin=0.0_real64, vmax=16.0_real64)
      endselect
      call ip_end_plot()
   endif
   up(frame) = test_field_uploads()
   endsubroutine counter

   subroutine big(frame)
   !< Phase 3: 1024 x 1024 fields, timed.
   integer(int32), intent(in) :: frame !< Frame.
   real(real64)                :: c(4) !< A pixel.
   real(real64)                :: t    !< Its fraction.
   integer(int32)              :: k    !< Sample.

   if (ip_begin_plot('big', 700.0_real64, 500.0_real64)) then
      select case (frame)
      case (17_int32)
         call ip_field_image('big32', big32, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, colormap=cmap, &
                             vmin=-1.0_real64, vmax=1.0_real64, changed=.true.)
         ms(1) = test_field_time()
      case (18_int32)
         call ip_field_image('big log', big_log, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, colormap=cmap, &
                             vmin=1.0e-3_real64, vmax=1.0e3_real64, scale='log', changed=.true.)
         ms(2) = test_field_time()
         lut_err = 0.0_real64
         do k = 0_int32, 997_int32 ! samples across the six decades
            i = 1_int32 + mod(k * 7919_int32, NB)
            j = 1_int32 + mod(k * 104729_int32, NB)
            call test_field_pixel('big log', i, j, c)
            t = (log10(real(big_log(i, j), real64)) + 3.0_real64) / 6.0_real64
            lut_err = max(lut_err, maxval(abs(c - sample(cmap, min(max(t, 0.0_real64), 1.0_real64)))))
         enddo
      case (19_int32)
         call ip_field_image('big64', big64, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, colormap=cmap, &
                             vmin=-1.0_real64, vmax=1.0_real64, changed=.true.)
         ms(3) = test_field_time()
         textures(1) = test_field_textures()
      endselect
      call ip_end_plot()
   endif
   endsubroutine big

   subroutine idle(frame)
   !< Phase 4: only two fields drawn, one label in two plots, for more than 10 s of frames (1/60 s each headless).
   integer(int32), intent(in) :: frame !< Frame.

   if (ip_begin_plot('idle', 700.0_real64, 240.0_real64)) then
      call ip_field_image('keep', cnt, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, colormap=cmap)
      call ip_end_plot()
   endif
   if (ip_begin_plot('idle too', 700.0_real64, 240.0_real64)) then ! the same label in another plot: its own texture
      call ip_field_image('keep', cnt2, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, colormap=cmap)
      call ip_end_plot()
   endif
   if (frame == 20_int32) up_keep(1) = test_field_uploads() - 2_int64 ! their first colourings counted
   if (frame == 640_int32) then
      up_keep(2) = test_field_uploads()
      textures(2) = test_field_textures()
   endif
   endsubroutine idle

   subroutine legends(frame)
   !< Phase 5: a legend the user edits, one on a log scale, one fixed; dragged and scrolled.
   integer(int32), intent(in) :: frame !< Frame.
   real(real64)                :: x0, y0, x1, y1 !< An item's rectangle.

   if (ip_colormap_legend_edit('edit', cmap, lo, hi, height=300.0_real64)) changes = changes + 1_int32
   call ig_item_rect(x0, y0, x1, y1)
   if (frame == 641_int32) then
      bar = [x0, y0, x1, y1]
      th = ig_line_height()
   endif
   call ig_same_line()
   if (ip_colormap_legend_edit('log edit', cmap, llo, lhi, height=300.0_real64, scale='log')) lchanges = lchanges + 1_int32
   call ig_item_rect(x0, y0, x1, y1)
   if (frame == 641_int32) lbar = [x0, y0, x1, y1]
   call ig_same_line()
   call ip_colormap_legend('fixed', cmap, flo, fhi, height=300.0_real64)
   call ig_item_rect(x0, y0, x1, y1)
   if (frame == 641_int32) fbar = [x0, y0, x1, y1]
   select case (frame)
   case (642_int32)
      lo0 = lo
      hi0 = hi
      call test_drag(bar(1) + 5.0_real64, 0.5_real64 * (bar(2) + bar(4)), bar(1) + 5.0_real64, &
                     0.5_real64 * (bar(2) + bar(4)) - 60.0_real64)
   case (655_int32)
      lo1 = lo
      hi1 = hi
      call test_mouse_move(bar(1) + 5.0_real64, bar(2) + 0.25_real64 * (bar(4) - bar(2)))
      call test_next_frame()
      call test_wheel(1.0_real64)
   case (656_int32)
      pv = lo1 + (hi1 - lo1) * (bar(4) - 0.5_real64 * lh() - (bar(2) + 0.25_real64 * (bar(4) - bar(2)))) / &
           (bar(4) - bar(2) - lh())
   case (665_int32)
      lo2 = lo
      hi2 = hi
      call test_drag(lbar(1) + 5.0_real64, 0.5_real64 * (lbar(2) + lbar(4)), lbar(1) + 5.0_real64, &
                     0.5_real64 * (lbar(2) + lbar(4)) - 60.0_real64)
   case (678_int32)
      llo1 = llo
      lhi1 = lhi
      call test_drag(fbar(1) + 5.0_real64, 0.5_real64 * (fbar(2) + fbar(4)), fbar(1) + 5.0_real64, &
                     0.5_real64 * (fbar(2) + fbar(4)) - 60.0_real64)
   endselect
   endsubroutine legends

   subroutine wrong_calls()
   !< Phase 6: arguments refused, and a field outside a plot.
   real(real64) :: a, b !< A range.

   a = -1.0_real64
   b = 1.0_real64
   if (ip_begin_plot('wrong', 700.0_real64, 500.0_real64)) then
      call ip_field_image('w', ends, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, scale='time', stat=st(1))
      call ip_field_image('w', ends, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, scale='log', vmin=0.0_real64, &
                          stat=st(2))
      call ip_field_image('w', ends, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, vmin=1.0_real64, &
                          vmax=1.0_real64, stat=st(3))
      call ip_field_image('w', ends, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, nan_color=[1.0_real64, 0.0_real64, &
                          0.0_real64], stat=st(4))
      call ip_field_image('w', ends, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, nan_color=[2.0_real64, 0.0_real64, &
                          0.0_real64, 1.0_real64], stat=st(5))
      call ip_field_image('w', ends, 0.0_real64, 0.0_real64, 0.0_real64, 1.0_real64, stat=st(6))
      call ip_field_image('w', ends, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, vmax=nan, stat=st(7))
      call ip_field_image('w', ends, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, colormap=-1_int32, stat=st(8))
      call ip_field_image('w', ends, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, scale='log', vmax=-2.0_real64, &
                          stat=st(9))
      call ip_field_image('w', ends, 0.0_real64, pinf, 0.0_real64, 1.0_real64, stat=st(10))
      call ip_end_plot()
   endif
   call ip_field_image('w', ends, 0.0_real64, 1.0_real64, 0.0_real64, 1.0_real64, stat=st(11))
   call ip_colormap_legend('w1', cmap, -1.0_real64, 1.0_real64, scale='log', stat=st(12))
   call ip_colormap_legend('w2', cmap, -1.0_real64, 1.0_real64, scale='loglog', stat=st(13))
   if (ip_colormap_legend_edit('w3', cmap, a, b, scale='log', stat=st(14))) st(14) = -1_int32
   endsubroutine wrong_calls
endprogram figure_test_fields
