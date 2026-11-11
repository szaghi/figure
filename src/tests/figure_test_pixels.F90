!< figure_test_pixels, FIGURE's CPU renderer (headless and remote modes' pictures) and the picture checks of figure_testing.
program figure_test_pixels
!< figure_test_pixels, FIGURE's CPU renderer (headless and remote modes' pictures) and the picture checks of figure_testing:
!< a fixed window rendered twice gives the same file, on 1 thread as on 7; the window against the committed golden
!< (src/tests/data/figure_test_pixels.golden.png, |d| <= 2); textures sampled as the GPU samples them (nearest, linear
!< at 4x, a field through a colormap: test_field_pixel's colours); a glyph of Dear ImGui's bitmap font drawn exactly as
!< its bitmap (ProggyClean's H); a rectangle with its corners on pixel centres covering the pixels the top-left rule
!< gives, each blended once to the GPU's value, a filled rectangle of that value, a line from -10^7 to 10^7 drawn as
!< one across the display; test_compare_image's threshold, max_failed and masks, and the .new.png and
!< .diff.png it writes and removes; app%save_image in headless mode equal to the capture's rectangle; the same window in
!< remote mode (no client) equal to headless mode's, its save_image too; the refusals. The files are
!< `figure_test_pixels.*.tmp` and `figure_test_pixels.ref*.png`, removed at the end.
use, intrinsic :: iso_c_binding, only : c_int, c_loc
use, intrinsic :: iso_fortran_env, only : error_unit, int8, int32, int64, output_unit, real32, real64
use figure, only : app_object, FIG_ERR_ARGUMENT, FIG_ERR_FAILED, FIG_ERR_STATE, FIG_OK, fig_read_image, &
                   figure_last_error, ig_begin, ig_button, ig_checkbox, ig_end, ig_image, ig_item_rect, &
                   ig_draw_image, ig_draw_line, ig_draw_rect, ig_set_next_window, ig_slider, ig_text, ip_begin_plot, ip_colormap, &
                   ip_end_plot, ip_field_image, ip_plot_to_pixels, ip_setup_axes_limits, texture_object
use figure_c_native, only : fig_image_write, fig_render_threads
use figure_testing, only : test_capture, test_compare_image, test_field_pixel

implicit none
character(len=*), parameter :: GOLDEN = 'src/tests/data/figure_test_pixels.golden.png' !< The committed reference.
character(len=*), parameter :: SHOT1 = 'figure_test_pixels.shot1.png.tmp'    !< The window, first time.
character(len=*), parameter :: SHOT2 = 'figure_test_pixels.shot2.png.tmp'    !< The window, a frame later.
character(len=*), parameter :: ONE = 'figure_test_pixels.one.png.tmp'        !< The window on 1 thread.
character(len=*), parameter :: SEVEN = 'figure_test_pixels.seven.png.tmp'    !< The window on 7 threads.
character(len=*), parameter :: SAVED = 'figure_test_pixels.saved.png.tmp'    !< save_image of the window, headless.
character(len=*), parameter :: TEXS = 'figure_test_pixels.textures.png.tmp'  !< The textures.
character(len=*), parameter :: GLYPH = 'figure_test_pixels.glyph.png.tmp'    !< The glyph.
character(len=*), parameter :: TIES_SHOT = 'figure_test_pixels.ties.png.tmp' !< A rectangle on pixel centres.
character(len=*), parameter :: REF = 'figure_test_pixels.ref.png'            !< A reference made by the test.
character(len=*), parameter :: ALTER = 'figure_test_pixels.alter.png.tmp'    !< The reference, altered.
character(len=*), parameter :: SMALL = 'figure_test_pixels.small.png.tmp'    !< A part of it.
character(len=*), parameter :: REMOTE = 'figure_test_pixels.remote.png.tmp'  !< The window in remote mode.
character(len=*), parameter :: RSAVED = 'figure_test_pixels.rsaved.png.tmp'  !< save_image in remote mode.
integer(int32),   parameter :: W = 480_int32                                 !< Display width [pixels].
integer(int32),   parameter :: H = 360_int32                                 !< Display height [pixels].
type(app_object)            :: app             !< Application.
logical                     :: test_passed(15) !< Per-check outcome.
logical                     :: checked         !< The scene's check box.
real(real64)                :: value           !< The scene's slider.
real(real64)                :: win(4)          !< The scene's window rectangle [pixels].
character(len=8)            :: keep            !< FIGURE_TEST_KEEP.

checked = .true.
value = 0.25_real64
test_passed = .false.
call app%init_headless(W, H)
call twice(test_passed(1:2))
call threads(test_passed(3))
call against_golden(test_passed(4))
call textures(test_passed(5:7))
call masks_and_threshold(test_passed(8:10))
call saved_headless(test_passed(11))
call glyph_exact(test_passed(12))
call refusals(test_passed(13))
call ties(test_passed(15))
call app%destroy()
call remote_mode(test_passed(14))
call get_environment_variable('FIGURE_TEST_KEEP', keep)
if (len_trim(keep) == 0) call remove_files() ! FIGURE_TEST_KEEP=1 keeps the pictures, to look at them

write(output_unit, '(A,*(L2))') 'figure_test_pixels checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine scene()
   !< The window the pictures show: text, a button, a check box, a slider, at a fixed place and size.
   real(real64) :: x0, y0, x1, y1 !< Rectangle of the window's last item.

   call ig_set_next_window(16.0_real64, 16.0_real64, 300.0_real64, 150.0_real64, always=.true.)
   if (ig_begin('Pixels')) then
      call ig_text('FIGURE draws this without a GPU')
      if (ig_button('A button')) continue
      if (ig_checkbox('a check box', checked)) continue
      if (ig_slider('a slider', value, 0.0_real64, 1.0_real64)) continue
      call ig_item_rect(x0, y0, x1, y1)
   endif
   call ig_end()
   win = [16.0_real64, 16.0_real64, 316.0_real64, 166.0_real64]
   endsubroutine scene

   function frames(n, shot) result(ok)
   !< `n` frames of the scene, the last captured to `shot` (written when it ends: one more frame begins).
   integer(int32),   intent(in)           :: n    !< Frames.
   character(len=*), intent(in), optional :: shot !< Capture of the last.
   logical                                :: ok   !< Every frame drawn, the capture asked.
   integer(int32)                         :: k    !< Frame.
   integer(int32)                         :: s    !< Status.

   ok = .true.
   s = FIG_OK
   do k = 1_int32, n
      if (.not. app%next_frame()) then
         ok = .false.
         return
      endif
      call scene()
      if (k == n .and. present(shot)) call test_capture(shot, s)
   enddo
   if (.not. app%next_frame()) ok = .false. ! the captured frame rendered; a new one open, drawn nothing
   call scene()
   ok = ok .and. s == FIG_OK
   endfunction frames

   function same_bytes(a, b) result(same)
   !< Two files equal byte for byte.
   character(len=*), intent(in) :: a, b     !< Files.
   logical                      :: same     !< Equal.
   integer(int8), allocatable   :: x(:), y(:) !< Contents.

   call slurp(a, x)
   call slurp(b, y)
   same = size(x) > 0 .and. size(x) == size(y)
   if (same) same = all(x == y)
   endfunction same_bytes

   subroutine slurp(path, bytes)
   !< A whole file (empty if it cannot be read).
   character(len=*),           intent(in)  :: path     !< File.
   integer(int8), allocatable, intent(out) :: bytes(:) !< Contents.
   integer(int32)                          :: u, n, ios !< Unit, size, status.

   open(newunit=u, file=path, access='stream', form='unformatted', status='old', action='read', iostat=ios)
   if (ios /= 0_int32) then
      allocate(bytes(0))
      return
   endif
   inquire(unit=u, size=n)
   allocate(bytes(max(0_int32, n)))
   if (n > 0_int32) read(u, iostat=ios) bytes
   close(u)
   endsubroutine slurp

   subroutine twice(ok)
   !< The window drawn on two frames: the two captures are the same file, and test_compare_image with threshold 0
   !< agrees; the picture has the display's size and is not blank.
   logical, intent(out)       :: ok(2)         !< Outcomes: equal; size and contents.
   integer(int8), allocatable :: px(:,:,:)     !< The first capture.
   integer(int32)             :: s             !< Status.

   ok(1) = frames(4_int32, SHOT1)
   ok(1) = ok(1) .and. frames(1_int32, SHOT2)
   ok(1) = ok(1) .and. same_bytes(SHOT1, SHOT2)
   if (ok(1)) ok(1) = test_compare_image(SHOT2, SHOT1, threshold=0_int32)
   call fig_read_image(SHOT1, px, s)
   ok(2) = s == FIG_OK
   if (ok(2)) ok(2) = all(shape(px) == [4, W, H])
   if (ok(2)) ok(2) = any(px(1,:,:) /= px(1,1,1)) .and. all(px(4,:,:) == -1_int8) ! drawn, opaque
   if (.not. all(ok)) write(error_unit, '(A,2L2,A,A)') 'twice:', ok, ' ', figure_last_error()
   endsubroutine twice

   subroutine threads(ok)
   !< The same window rendered on 1 and on 7 threads: the same file.
   logical, intent(out) :: ok !< Outcome.

   ok = fig_render_threads(1_c_int) == FIG_OK
   ok = ok .and. frames(1_int32, ONE)
   ok = ok .and. fig_render_threads(7_c_int) == FIG_OK
   ok = ok .and. frames(1_int32, SEVEN)
   ok = ok .and. fig_render_threads(0_c_int) == FIG_OK
   ok = ok .and. same_bytes(ONE, SEVEN) .and. same_bytes(ONE, SHOT1)
   if (.not. ok) write(error_unit, '(A)') 'threads: the pictures differ'
   endsubroutine threads

   subroutine against_golden(ok)
   !< The window's capture against the committed golden, at the default tolerance.
   logical, intent(out) :: ok !< Outcome.
   integer(int64)       :: n  !< Pixels that failed.
   integer(int32)       :: s  !< Status.

   ok = test_compare_image(SHOT1, GOLDEN, failed=n, stat=s)
   if (.not. ok) write(error_unit, '(A,I0,A,I0,A,A)') 'golden: status ', s, ', ', n, ' failed: ', figure_last_error()
   endsubroutine against_golden

   subroutine textures(ok)
   !< A 2 x 1 texture (black, white) drawn 8 x 4 pixels: nearest gives four black then four white columns; linear
   !< gives black, black, 32, 96, 159, 223, white, white (the exact interpolation at the pixel centres, rounded); a
   !< 4 x 1 field through a colormap shows, at each cell's centre, the colour test_field_pixel gives.
   logical, intent(out)       :: ok(3)        !< Outcomes: nearest, linear, field.
   type(texture_object)       :: near, lin    !< Textures.
   integer(int8)              :: two(4, 2, 1) !< Their pixels.
   integer(int8), allocatable :: px(:,:,:)    !< The capture.
   real(real32)               :: f(4, 1)      !< Field.
   real(real64)               :: rn(4), rl(4) !< The images' rectangles [pixels].
   real(real64)               :: cx(4), cy(4) !< The cells' centres [pixels].
   real(real64)               :: rgba(4, 4)   !< The cells' colours [0, 1].
   integer(int32)             :: k, i, j, s   !< Frame, column, row, status.
   integer(int32)             :: lin_want(8)  !< The linear row [0-255].
   integer(int32)             :: cmap         !< Colormap.
   logical                    :: drawn        !< Frames drawn.

   two(:, 1, 1) = [0_int8, 0_int8, 0_int8, -1_int8]
   two(:, 2, 1) = [-1_int8, -1_int8, -1_int8, -1_int8]
   call near%init(2_int32, 1_int32)
   call near%update(two)
   call lin%init(2_int32, 1_int32, smooth=.true.)
   call lin%update(two)
   f(:, 1) = [0.0_real32, 1.0_real32, 2.0_real32, 3.0_real32]
   lin_want = [0_int32, 0_int32, 32_int32, 96_int32, 159_int32, 223_int32, 255_int32, 255_int32]
   cmap = ip_colormap('batlow')
   drawn = .true.
   s = FIG_ERR_STATE
   do k = 1_int32, 4_int32
      if (.not. app%next_frame()) then
         drawn = .false.
         exit
      endif
      call ig_set_next_window(16.0_real64, 16.0_real64, 300.0_real64, 260.0_real64, always=.true.)
      if (ig_begin('Textures')) then
         call ig_image(near, 8.0_real64, 4.0_real64)
         call ig_item_rect(rn(1), rn(2), rn(3), rn(4))
         call ig_image(lin, 8.0_real64, 4.0_real64)
         call ig_item_rect(rl(1), rl(2), rl(3), rl(4))
         if (ip_begin_plot('##field', 260.0_real64, 180.0_real64)) then
            call ip_setup_axes_limits(0.0_real64, 4.0_real64, 0.0_real64, 1.0_real64, always=.true.)
            call ip_field_image('cells', f, 0.0_real64, 4.0_real64, 0.0_real64, 1.0_real64, colormap=cmap, &
                                vmin=0.0_real64, vmax=3.0_real64)
            do i = 1_int32, 4_int32
               call ip_plot_to_pixels(real(i, real64) - 0.5_real64, 0.5_real64, cx(i), cy(i))
            enddo
            call ip_end_plot()
         endif
      endif
      call ig_end()
      if (k == 4_int32) call test_capture(TEXS, s)
   enddo
   drawn = drawn .and. app%next_frame()
   do i = 1_int32, 4_int32
      call test_field_pixel('cells', i, 1_int32, rgba(:, i))
   enddo
   call fig_read_image(TEXS, px, s)
   ok = drawn .and. s == FIG_OK
   if (all(ok)) then
      ! the images start on whole pixels (the window's padding): columns from rn(1) + 1, rows from rn(2) + 1
      do j = 1_int32, 4_int32
         do i = 1_int32, 8_int32
            ok(1) = ok(1) .and. all(at(px, nint(rn(1)) + i, nint(rn(2)) + j) == merge(0, 255, i <= 4))
            ok(2) = ok(2) .and. all(at(px, nint(rl(1)) + i, nint(rl(2)) + j) == lin_want(i))
         enddo
      enddo
      do i = 1_int32, 4_int32
         ok(3) = ok(3) .and. all(at(px, floor(cx(i)) + 1_int32, floor(cy(i)) + 1_int32) == nint(255.0_real64 * rgba(1:3, i)))
      enddo
      ok(3) = ok(3) .and. any(rgba(1:3, 1) /= rgba(1:3, 4)) ! the colormap's ends differ
   endif
   if (.not. all(ok)) then
      write(error_unit, '(A,3L2,A,I0)') 'textures:', ok, ' status ', s
      if (allocated(px)) then
         write(error_unit, '(A,8(1X,I0))') ' nearest row', (at(px, nint(rn(1)) + i, nint(rn(2)) + 1_int32), i = 1, 8)
         write(error_unit, '(A,8(1X,I0))') ' linear row', (at(px, nint(rl(1)) + i, nint(rl(2)) + 1_int32), i = 1, 8)
      endif
   endif
   call near%destroy()
   call lin%destroy()
   endsubroutine textures

   function at(px, i, j) result(rgb)
   !< The RGB of pixel (i, j) of a picture, 0-255 (column i, row j from 1 at the top-left corner).
   integer(int8),  intent(in) :: px(:,:,:) !< Picture.
   integer(int32), intent(in) :: i, j      !< Pixel.
   integer(int32)             :: rgb(3)    !< Colour.

   rgb = -1_int32
   if (i < 1_int32 .or. j < 1_int32 .or. i > size(px, 2) .or. j > size(px, 3)) return
   rgb = modulo(int(px(1:3, i, j), int32), 256_int32)
   endfunction at

   subroutine masks_and_threshold(ok)
   !< A reference picture (the window's capture, as a PNG) and copies of it changed: 7 pixels by 2 pass; by 3 they
   !< fail (7 of them, `failed`), and pass with max_failed 7 or a mask over them, the .new.png and .diff.png written
   !< on the failure (the .new.png the changed picture, the .diff.png red where they failed) and removed on the pass;
   !< a picture of another size fails.
   logical, intent(out)       :: ok(3)        !< Outcomes: threshold; failures, files and masks; size.
   integer(int8), allocatable :: px(:,:,:)    !< The reference.
   integer(int8), allocatable :: alt(:,:,:)   !< Changed.
   integer(int8), allocatable :: back(:,:,:)  !< A file read back.
   integer(int64)             :: n(3)         !< Pixels failed.
   integer(int32)             :: s(3), i      !< Statuses, pixel.
   logical                    :: r(6)         !< Comparisons.
   logical                    :: files(3)     !< The files written and removed.
   real(real64)               :: box(4, 1)    !< A mask over the changed pixels.

   call fig_read_image(SHOT1, px, s(1))
   ok = s(1) == FIG_OK
   if (.not. ok(1)) return
   call write_rgb(REF, px, s(1))
   alt = px
   do i = 1_int32, 7_int32 ! a diagonal from (101, 41) [1-based]: bytes +2 (or -2 near the top of the range)
      alt(1, 100 + i, 40 + i) = shifted(alt(1, 100 + i, 40 + i), 2_int32)
   enddo
   call write_rgb(ALTER, alt, s(2))
   r(1) = test_compare_image(ALTER, REF)
   alt = px
   do i = 1_int32, 7_int32
      alt(2, 100 + i, 40 + i) = shifted(alt(2, 100 + i, 40 + i), 3_int32)
   enddo
   call write_rgb(ALTER, alt, s(3))
   r(2) = .not. test_compare_image(ALTER, REF, failed=n(1))
   files(1) = exists('figure_test_pixels.ref.new.png') .and. exists('figure_test_pixels.ref.diff.png')
   if (files(1)) then
      call fig_read_image('figure_test_pixels.ref.new.png', back, s(1))
      files(1) = s(1) == FIG_OK
      if (files(1)) files(1) = all(back(1:3,:,:) == alt(1:3,:,:))
      call fig_read_image('figure_test_pixels.ref.diff.png', back, s(1))
      files(1) = files(1) .and. s(1) == FIG_OK
      if (files(1)) files(1) = all(at(back, 101_int32, 41_int32) == [255, 0, 0]) .and. &
                               all(at(back, 1_int32, 1_int32) /= [255, 0, 0])
   endif
   r(3) = test_compare_image(ALTER, REF, max_failed=7_int32, failed=n(2))
   files(2) = .not. exists('figure_test_pixels.ref.new.png') .and. .not. exists('figure_test_pixels.ref.diff.png')
   r(4) = .not. test_compare_image(ALTER, REF, max_failed=6_int32)
   box(:, 1) = [100.0_real64, 40.0_real64, 108.0_real64, 48.0_real64]
   r(5) = test_compare_image(ALTER, REF, masks=box, failed=n(3))
   box(:, 1) = [100.0_real64, 40.0_real64, 104.0_real64, 48.0_real64] ! half of them
   r(6) = .not. test_compare_image(ALTER, REF, masks=box)
   files(3) = index(figure_last_error(), '3 pixels of '//ALTER) > 0
   ok(1) = r(1) .and. all(s == FIG_OK)
   ok(2) = all(r(2:6)) .and. all(files) .and. all(n == [7_int64, 7_int64, 0_int64])
   call write_rgb(SMALL, px(:, 1:100, 1:50), s(1))
   ok(3) = s(1) == FIG_OK .and. .not. test_compare_image(SMALL, REF, failed=n(1))
   ok(3) = ok(3) .and. n(1) == -1_int64 .and. exists('figure_test_pixels.ref.new.png') .and. &
           .not. exists('figure_test_pixels.ref.diff.png') .and. index(figure_last_error(), '100x50 pixels') > 0
   n(1) = 7_int64
   if (.not. all(ok)) write(error_unit, '(A,3L2,A,6L2,A,3L2,A,3(1X,I0),2A)') 'masks:', ok, ' r', r, ' files', files, &
                                                                         ' n', n, ' ', figure_last_error()
   endsubroutine masks_and_threshold

   elemental function shifted(b, d) result(c)
   !< A byte moved by d levels, down instead of up where up would leave 0-255.
   integer(int8),  intent(in) :: b !< Byte.
   integer(int32), intent(in) :: d !< Levels.
   integer(int8)              :: c !< Moved.
   integer(int32)             :: v !< Value.

   v = modulo(int(b, int32), 256_int32)
   v = merge(v - d, v + d, v + d > 255_int32)
   c = int(merge(v - 256_int32, v, v > 127_int32), int8)
   endfunction shifted

   subroutine write_rgb(path, rgba, stat)
   !< A picture's RGB as a PNG (FIGURE's encoder).
   character(len=*), intent(in)  :: path        !< File.
   integer(int8),    intent(in)  :: rgba(:,:,:) !< Pixels.
   integer(int32),   intent(out) :: stat        !< Status.
   integer(int8), allocatable, target :: rgb(:,:,:) !< Contiguous RGB.

   rgb = rgba(1:3,:,:)
   stat = int(fig_image_write(path, len(path, c_int), c_loc(rgb), 3_c_int, int(size(rgb, 2), c_int), &
                              int(size(rgb, 3), c_int), 0_c_int), int32)
   endsubroutine write_rgb

   function exists(path) result(found)
   !< A file exists.
   character(len=*), intent(in) :: path  !< File.
   logical                      :: found !< It does.

   inquire(file=path, exist=found)
   endfunction exists

   subroutine saved_headless(ok)
   !< app%save_image of the window's rectangle, headless: reported once, the PNG equal to that rectangle of the
   !< frame's capture.
   logical, intent(out)          :: ok          !< Outcome.
   integer(int8), allocatable    :: full(:,:,:) !< The capture.
   integer(int8), allocatable    :: part(:,:,:) !< The saved rectangle.
   character(len=:), allocatable :: path        !< Reported file.
   logical                       :: done        !< Reported.
   integer(int32)                :: s(3), k     !< Statuses, frame.

   ok = app%next_frame()
   call scene()
   call app%save_image(SAVED, win(1), win(2), win(3), win(4), stat=s(1))
   call test_capture(SHOT2, s(2))
   done = .false.
   do k = 1_int32, 3_int32
      if (.not. app%next_frame()) exit
      call scene()
      call app%image_result(path, done)
      if (done) exit
   enddo
   ok = ok .and. done .and. path == SAVED .and. all(s(1:2) == FIG_OK)
   call fig_read_image(SHOT2, full, s(1))
   call fig_read_image(SAVED, part, s(2))
   ok = ok .and. s(1) == FIG_OK .and. s(2) == FIG_OK
   if (ok) ok = all(shape(part) == [4, 300, 150])
   if (ok) ok = all(part == full(:, 17:316, 17:166))
   call app%image_result(path, done, stat=s(3))
   ok = ok .and. .not. done .and. s(3) == FIG_OK ! once
   if (.not. ok) write(error_unit, '(A,L2,3(1X,I0),2A)') 'save_image headless: done', done, s, ' ', figure_last_error()
   endsubroutine saved_headless

   subroutine glyph_exact(ok)
   !< 'H' in Dear ImGui's bitmap font at its own size (13 pixels, every pixel of a glyph on or off): around the text,
   !< every pixel is the background's colour or the text's, and those of the text's colour are the glyph's bitmap,
   !< 6 x 8 pixels, two strokes and the bar on the fourth row (ProggyClean's 'H').
   logical, intent(out)          :: ok            !< Outcome.
   integer(int8), allocatable    :: px(:,:,:)     !< The capture.
   logical                       :: lit(-2:30, -2:30) !< Pixels of the text's colour, around the text.
   logical                       :: want(6, 8)    !< The glyph.
   integer(int64)                :: other         !< Pixels of neither colour.
   real(real64)                  :: r(4)          !< The text's rectangle [pixels].
   integer(int32)                :: bg(3), fg(3)  !< Background, text colour.
   integer(int32)                :: k, i, j, s    !< Frame, column, row, status.
   integer(int32)                :: x0, y0        !< The glyph's top-left lit pixel.

   want = .false.
   want(1, :) = .true.
   want(6, :) = .true.
   want(:, 4) = .true.
   call app%set_font('proggy', 13.0_real64) ! its own size: sharp
   s = FIG_ERR_STATE
   ok = .true.
   do k = 1_int32, 3_int32
      ok = ok .and. app%next_frame()
      call ig_set_next_window(16.0_real64, 16.0_real64, 120.0_real64, 80.0_real64, always=.true.)
      if (ig_begin('Glyph')) then
         call ig_text('H')
         call ig_item_rect(r(1), r(2), r(3), r(4))
      endif
      call ig_end()
      if (k == 3_int32) call test_capture(GLYPH, s)
   enddo
   ok = ok .and. app%next_frame() .and. s == FIG_OK
   call fig_read_image(GLYPH, px, s)
   ok = ok .and. s == FIG_OK
   other = 0_int64
   fg = -1_int32
   lit = .false.
   x0 = 0_int32
   y0 = 0_int32
   if (ok) then
      bg = at(px, nint(r(1)) - 1_int32, nint(r(2)) - 1_int32) ! outside the text, inside the window
      do j = -2_int32, 30_int32
         do i = -2_int32, 30_int32
            if (all(at(px, nint(r(1)) + i, nint(r(2)) + j) == bg)) cycle
            if (all(fg < 0_int32)) fg = at(px, nint(r(1)) + i, nint(r(2)) + j)
            if (all(at(px, nint(r(1)) + i, nint(r(2)) + j) == fg)) then
               lit(i, j) = .true.
            else
               other = other + 1_int64
            endif
         enddo
      enddo
      ok = other == 0_int64 .and. any(fg /= bg) .and. count(lit) == count(want)
      if (ok) then
         x0 = minval([(i, i = -2_int32, 30_int32)], mask=any(lit, dim=2))
         y0 = minval([(j, j = -2_int32, 30_int32)], mask=any(lit, dim=1))
         ok = x0 + 5_int32 <= 30_int32 .and. y0 + 7_int32 <= 30_int32
         if (ok) ok = all(lit(x0:x0 + 5_int32, y0:y0 + 7_int32) .eqv. want)
      endif
   endif
   call app%set_font('plex-sans', 15.0_real64)
   if (.not. ok) write(error_unit, '(A,2(1X,I0),A,6(1X,I0),A,2(1X,I0))') 'glyph: lit, other', count(lit), other, &
                                                                        ' fg bg', fg, bg, ' at', x0, y0
   endsubroutine glyph_exact

   subroutine ties(ok)
   !< A white image tinted half transparent on the foreground layer (two triangles, no anti-aliased fringe), its corners
   !< on pixel centres, (100.5, 200.5) to (160.5, 240.5): by the image's top-left rule its pixels are columns 100-159
   !< and rows 200-239 (from 0), each blended once (the diagonal its two triangles share lies on pixel centres too) to
   !< the value the GPU's blend gives, computed here in single precision; the rows and columns around it are the
   !< background. A rectangle filled with the same colour, (200, 100) to (340, 140): inside its anti-aliased border,
   !< one colour (triangles wide enough to be blended by the table of their 256 results) and the same value. A line
   !< from x = -10^7 to 10^7 (clipped in double precision before it is rasterized) drawn as the same line from -10 to
   !< the display's width + 10, 20 rows below.
   logical, intent(out)       :: ok        !< Outcome.
   integer(int8), allocatable :: px(:,:,:) !< The capture.
   integer(int32)             :: bg(3)     !< Background.
   integer(int32)             :: want(3)   !< The blend.
   integer(int32)             :: i, j, k, s, inside, wrong !< Column, row, frame, status, counts.
   integer(int32)             :: far       !< Pixels where the far line differs from the near one.
   logical                    :: lit       !< The far line drawn.
   real(real32)               :: a, v, one !< Alpha, a channel, a byte of 255.
   type(texture_object)       :: white     !< A white texture.
   integer(int8)              :: px2(4, 2, 2) !< Its pixels.

   px2 = -1_int8
   call white%init(2_int32, 2_int32)
   call white%update(px2)
   s = FIG_ERR_STATE
   ok = .true.
   do k = 1_int32, 2_int32
      ok = ok .and. app%next_frame()
      call ig_draw_image(white, 100.5_real64, 200.5_real64, 160.5_real64, 240.5_real64, &
                         color=[1.0_real64, 1.0_real64, 1.0_real64, 0.5_real64], layer='foreground')
      call ig_draw_rect(200.0_real64, 100.0_real64, 340.0_real64, 140.0_real64, &
                        [1.0_real64, 1.0_real64, 1.0_real64, 0.5_real64], filled=.true., layer='foreground')
      call ig_draw_line(-1.0e7_real64, 300.3_real64, 1.0e7_real64, 300.3_real64, [0.9_real64, 0.6_real64, 0.2_real64], &
                        thickness=3.0_real64, layer='foreground')
      call ig_draw_line(-10.0_real64, 320.3_real64, real(W + 10_int32, real64), 320.3_real64, &
                        [0.9_real64, 0.6_real64, 0.2_real64], thickness=3.0_real64, layer='foreground')
      if (k == 2_int32) call test_capture(TIES_SHOT, s)
   enddo
   ok = ok .and. app%next_frame() .and. s == FIG_OK
   call fig_read_image(TIES_SHOT, px, s)
   ok = ok .and. s == FIG_OK
   inside = 0_int32
   wrong = 0_int32
   far = 0_int32
   lit = .false.
   if (ok) then
      bg = at(px, 1_int32, 1_int32)
      one = real(255, real32) * (1.0_real32 / 255.0_real32) ! white, and the atlas's white texel
      a = (real(128, real32) * (1.0_real32 / 255.0_real32)) * one ! the vertex alpha (0.5 as the byte 128), the texel's
      do i = 1_int32, 3_int32
         ! as the renderer: ((colour * texel) * alpha) + ((destination / 255) * (1 - alpha)), parentheses kept
         v = ((one * one) * a) + ((real(bg(i), real32) * (1.0_real32 / 255.0_real32)) * (1.0_real32 - a))
         want(i) = int(min(1.0_real32, max(0.0_real32, v)) * 255.0_real32 + 0.5_real32, int32)
      enddo
      do j = 199_int32, 242_int32 ! 1-based: rows 200-241 from 1, one around
         do i = 99_int32, 162_int32
            if (i >= 101_int32 .and. i <= 160_int32 .and. j >= 201_int32 .and. j <= 240_int32) then
               inside = inside + 1_int32
               if (any(at(px, i, j) /= want)) wrong = wrong + 1_int32
            elseif (any(at(px, i, j) /= bg)) then
               wrong = wrong + 1_int32
            endif
         enddo
      enddo
      do j = 102_int32, 139_int32 ! the filled rectangle's inside, its border left out
         do i = 202_int32, 339_int32
            inside = inside + 1_int32
            if (any(at(px, i, j) /= want)) wrong = wrong + 1_int32
         enddo
      enddo
      do j = 296_int32, 306_int32 ! the far line's rows against the near one's
         do i = 1_int32, W
            if (any(abs(at(px, i, j) - at(px, i, j + 20_int32)) > 2_int32)) far = far + 1_int32
         enddo
      enddo
      lit = any(at(px, W / 2_int32, 301_int32) /= bg)
      ok = inside == 2400_int32 + 38_int32 * 138_int32 .and. far == 0_int32 .and. lit .and. wrong == 0_int32 .and. any(want /= bg)
   endif
   call white%destroy()
   if (.not. ok) write(error_unit, '(A,3(1X,I0),L2,A,6(1X,I0))') 'ties: inside, wrong, far, lit', inside, wrong, far, &
                                                                 lit, ' want bg', want, bg
   endsubroutine ties

   subroutine refusals(ok)
   !< test_capture outside a frame and with no name; test_compare_image's bad arguments and a missing file.
   logical, intent(out)          :: ok          !< Outcome.
   integer(int32)                :: s(7)        !< Statuses.
   real(real64)                  :: bad(3, 1)   !< Masks of 3 rows.
   real(real64)                  :: inv(4, 1)   !< A mask upside down.
   logical                       :: r(5)        !< Results.
   character(len=:), allocatable :: msg         !< The missing file's message.

   bad = 0.0_real64
   inv(:, 1) = [10.0_real64, 10.0_real64, 5.0_real64, 20.0_real64]
   ok = app%next_frame()
   call scene()
   call test_capture('', s(1))
   r(1) = test_compare_image(SHOT1, SHOT1, threshold=256_int32, stat=s(2))
   r(2) = test_compare_image(SHOT1, SHOT1, max_failed=-1_int32, stat=s(3))
   r(3) = test_compare_image(SHOT1, SHOT1, masks=bad, stat=s(4))
   r(4) = test_compare_image(SHOT1, SHOT1, masks=inv, stat=s(5))
   r(5) = test_compare_image('figure_test_pixels.none.png.tmp', SHOT1, stat=s(6))
   msg = figure_last_error()
   ok = ok .and. s(1) == FIG_ERR_ARGUMENT .and. all(s(2:5) == FIG_ERR_ARGUMENT) .and. s(6) == FIG_ERR_FAILED .and. &
        .not. any(r) .and. index(msg, "test_compare_image: 'figure_test_pixels.none.png.tmp' cannot be read") == 1
   ok = ok .and. app%next_frame()
   call scene()
   call app%destroy()
   call test_capture(SHOT2, s(7)) ! not initialized
   ok = ok .and. s(7) == FIG_ERR_STATE
   call app%init_headless(W, H)
   if (.not. ok) write(error_unit, '(A,7(1X,I0),5L2,2A)') 'refusals:', s, r, ' ', msg
   endsubroutine refusals

   subroutine remote_mode(ok)
   !< The window in remote mode with no browser connected: its capture equal to headless mode's (the same file), its
   !< save_image equal to the rectangle.
   logical, intent(out)          :: ok          !< Outcome.
   integer(int8), allocatable    :: full(:,:,:) !< The capture.
   integer(int8), allocatable    :: part(:,:,:) !< The saved rectangle.
   character(len=:), allocatable :: path        !< Reported file.
   integer(int32)                :: port        !< Port.
   integer(int32)                :: s(3), k     !< Statuses, frame.
   logical                       :: done        !< save_image reported.

   call app%init_remote(port=0_int32, port_used=port, width=W, height=H, quiet=.true., stat=s(1))
   ok = s(1) == FIG_OK
   if (.not. ok) then
      write(error_unit, '(A,I0)') 'remote: init_remote status ', s(1)
      return
   endif
   call app%set_lazy(.false.)
   ok = frames(4_int32, REMOTE)
   call app%save_image(RSAVED, win(1), win(2), win(3), win(4), stat=s(2))
   done = .false.
   do k = 1_int32, 3_int32
      if (.not. app%next_frame()) exit
      call scene()
      call app%image_result(path, done)
      if (done) exit
   enddo
   call app%destroy()
   ok = ok .and. s(2) == FIG_OK .and. done .and. same_bytes(REMOTE, SHOT1)
   call fig_read_image(REMOTE, full, s(1))
   call fig_read_image(RSAVED, part, s(3))
   ok = ok .and. s(1) == FIG_OK .and. s(3) == FIG_OK
   if (ok) ok = all(shape(part) == [4, 300, 150])
   if (ok) ok = all(part == full(:, 17:316, 17:166))
   if (.not. ok) write(error_unit, '(A,L2,3(1X,I0),2A)') 'remote: done', done, s, ' ', figure_last_error()
   endsubroutine remote_mode

   subroutine remove_files()
   !< The test's files.
   character(len=40) :: names(16) !< Files.
   integer(int32)    :: k, u, ios !< Counter, unit, status.

   names = [character(len=40) :: SHOT1, SHOT2, ONE, SEVEN, SAVED, TEXS, GLYPH, TIES_SHOT, REF, ALTER, SMALL, REMOTE, RSAVED, &
            'figure_test_pixels.ref.new.png', 'figure_test_pixels.ref.diff.png', 'figure_test_pixels.none.png.tmp']
   do k = 1_int32, size(names, kind=int32)
      if (.not. exists(trim(names(k)))) cycle
      open(newunit=u, file=trim(names(k)), status='old', iostat=ios)
      if (ios == 0_int32) close(u, status='delete')
   enddo
   endsubroutine remove_files
endprogram figure_test_pixels
