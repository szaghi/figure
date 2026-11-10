!< figure_test_images_work, the work procedure of figure_test_images and its file helpers (module procedures: the work
!< runs on a task's thread).
module figure_test_images_work
!< figure_test_images_work, the work procedure of figure_test_images and its file helpers (module procedures: the work
!< runs on a task's thread).
use, intrinsic :: iso_c_binding, only : c_int, c_loc
use, intrinsic :: iso_fortran_env, only : int8, int32
use figure, only : FIG_OK, fig_read_image, figure_last_error, task_handle_object, texture_object
use figure_c_native, only : fig_image_write

implicit none
private
public :: read_job, read_work, load_work, write_image, write_bytes

type :: read_job
   !< A PNG read `times` times on a task's thread, compared with the pixels expected; then a missing file read.
   character(len=256)         :: path = ''         !< The PNG.
   character(len=256)         :: missing = ''      !< A file that does not exist.
   integer(int32)             :: times = 0_int32   !< Reads.
   integer(int8), allocatable :: expected(:,:,:)   !< The pixels the PNG holds.
   integer(int32)             :: equal = 0_int32   !< Reads equal to `expected`.
   integer(int32)             :: stat = -1_int32   !< Status of the missing file's read.
   character(len=512)         :: message = ''      !< Its message, read on the task's thread.
endtype read_job

contains
   recursive subroutine read_work(h, data)
   !< Read the PNG `times` times (counting the reads equal to the expected pixels), then the missing file.
   type(task_handle_object), intent(inout) :: h           !< Handle.
   class(*),                 intent(inout) :: data        !< A read_job.
   integer(int8), allocatable              :: rgba(:,:,:) !< Pixels read.
   integer(int32)                          :: k           !< Read.
   integer(int32)                          :: s           !< Status.

   select type (data)
   type is (read_job)
      do k = 1_int32, data%times
         if (h%cancelled()) return
         call fig_read_image(trim(data%path), rgba, s)
         if (s == FIG_OK) then
            if (all(shape(rgba) == shape(data%expected))) then
               if (all(rgba == data%expected)) data%equal = data%equal + 1_int32
            endif
         endif
      enddo
      call fig_read_image(trim(data%missing), rgba, data%stat)
      data%message = figure_last_error()
   endselect
   endsubroutine read_work

   recursive subroutine load_work(h, data)
   !< tex%load from a task: refused (its status in the read_job's `stat`).
   type(task_handle_object), intent(inout) :: h    !< Handle.
   class(*),                 intent(inout) :: data !< A read_job.
   type(texture_object)                    :: tex  !< Texture.

   if (h%cancelled()) return
   select type (data)
   type is (read_job)
      call tex%load(trim(data%path), stat=data%stat)
      data%equal = merge(1_int32, 0_int32, tex%is_initialized())
   endselect
   endsubroutine load_work

   subroutine write_image(path, pixels, quality, stat)
   !< Write `pixels(channels, width, height)` (rows from the top) as a PNG (`quality` 0) or a JPEG (1-100), with
   !< FIGURE's encoder (stb_image_write, not public).
   character(len=*), intent(in)         :: path          !< File name.
   integer(int8),    intent(in), target, contiguous :: pixels(:,:,:) !< Pixels (contiguous: c_loc is their address).
   integer(int32),   intent(in)         :: quality       !< 0: PNG; 1-100: JPEG.
   integer(int32),   intent(out)        :: stat          !< Status.

   stat = int(fig_image_write(path, len(path, c_int), c_loc(pixels), int(size(pixels, 1), c_int), &
                              int(size(pixels, 2), c_int), int(size(pixels, 3), c_int), int(quality, c_int)), int32)
   endsubroutine write_image

   subroutine write_bytes(path, bytes)
   !< Write `bytes` as the whole file `path`.
   character(len=*), intent(in) :: path     !< File name.
   integer(int8),    intent(in) :: bytes(:) !< Contents.
   integer(int32)               :: u        !< Unit.

   open(newunit=u, file=path, access='stream', form='unformatted', status='replace', action='write')
   write(u) bytes
   close(u)
   endsubroutine write_bytes
endmodule figure_test_images_work

program figure_test_images
!< figure_test_images, PNG and JPEG files read (`fig_read_image`, `tex%load`), headless: a PNG written by stb_image_write
!< reads back equal byte for byte (RGBA, grey, grey + alpha), an independent PNG (written by Python's zlib) reads as its
!< pixels with row 1 at the top, a JPEG within its tolerance, a missing file, a file of another format and a corrupt
!< PNG and JPEG refused with their messages, `tex%load` (and the texture kept on a failure, refused from a task), and
!< reads in a task while the main thread draws, the task's message its own. The files are `figure_test_images.*.tmp`,
!< removed at the end.
use, intrinsic :: iso_fortran_env, only : error_unit, int8, int32, output_unit, real64
use figure, only : app_object, FIG_ERR_ARGUMENT, FIG_ERR_FAILED, FIG_ERR_STATE, FIG_OK, fig_read_image, &
                   figure_last_error, ig_begin, ig_end, ig_image, ig_text, task_object, texture_object
use figure_test_images_work, only : load_work, read_job, read_work, write_bytes, write_image

implicit none
character(len=*), parameter :: PNG = 'figure_test_images.rgba.png.tmp'    !< RGBA PNG.
character(len=*), parameter :: GREY = 'figure_test_images.grey.png.tmp'   !< Grey PNG.
character(len=*), parameter :: GREYA = 'figure_test_images.greya.png.tmp' !< Grey + alpha PNG.
character(len=*), parameter :: PYPNG = 'figure_test_images.py.png.tmp'    !< The independent PNG.
character(len=*), parameter :: JPEG = 'figure_test_images.jpg.tmp'        !< JPEG.
character(len=*), parameter :: TEXT = 'figure_test_images.txt.tmp'        !< A text file.
character(len=*), parameter :: BMP = 'figure_test_images.bmp.tmp'         !< A BMP header.
character(len=*), parameter :: CUT = 'figure_test_images.cut.png.tmp'     !< A PNG cut short.
character(len=*), parameter :: BADJ = 'figure_test_images.bad.jpg.tmp'    !< A JPEG with a broken header.
character(len=*), parameter :: NONE = 'figure_test_images.none.png.tmp'   !< Never written.
!< The independent PNG: 3 x 2 RGBA, top row red, green, blue (opaque), bottom row (255, 255, 255, 128), (0, 0, 0, 0),
!< (10, 20, 30, 40); written by Python's zlib and struct (filter 0, deflate level 9), not by FIGURE.
integer(int8), parameter :: PY_BYTES(85) = int([ &
   -119, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 3, 0, 0, 0, 2, 8, 6, 0, 0, &
   0, -99, 116, 102, 26, 0, 0, 0, 28, 73, 68, 65, 84, 120, -38, 99, -8, -49, -64, -16, 31, 12, 25, -2, &
   3, -55, -1, -1, 27, 24, -128, -128, 75, 68, 78, 3, 0, -105, -49, 9, -36, 71, 79, -123, 100, 0, 0, 0, &
   0, 73, 69, 78, 68, -82, 66, 96, -126], int8)
type(app_object)           :: app             !< Application.
logical                    :: test_passed(11) !< Per-check outcome.
integer(int8), allocatable :: rgba(:,:,:)     !< The RGBA image written.

call app%init_headless(400_int32, 300_int32)
call make_rgba(rgba)
test_passed = .false.
call png_equal(test_passed(1))
call grey_equal(test_passed(2))
call independent_png(test_passed(3))
call jpeg_within(test_passed(4))
call missing_refused(test_passed(5))
call other_format_refused(test_passed(6))
call corrupt_refused(test_passed(7))
call texture_load(test_passed(8))
call load_in_task(test_passed(9:10))
call load_refused_in_task(test_passed(11))
call app%destroy()
call remove_files()

write(output_unit, '(A,*(L2))') 'figure_test_images checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine make_rgba(p)
   !< A 37 x 23 RGBA image whose bytes take every value 0-255 (alpha too), no two neighbours alike.
   integer(int8), allocatable, intent(out) :: p(:,:,:) !< Pixels.
   integer(int32)                          :: c, i, j  !< Channel, column, row.

   allocate(p(4, 37, 23))
   do j = 1_int32, 23_int32
      do i = 1_int32, 37_int32
         do c = 1_int32, 4_int32
            p(c, i, j) = int(modulo(c * 61_int32 + i * 7_int32 + j * 37_int32 * c, 256_int32) - 128_int32, int8)
         enddo
      enddo
   enddo
   endsubroutine make_rgba

   subroutine png_equal(ok)
   !< The RGBA image written as a PNG reads back equal byte for byte, its shape (4, 37, 23).
   logical, intent(out)       :: ok        !< Outcome.
   integer(int8), allocatable :: back(:,:,:) !< Pixels read.
   integer(int32)             :: s(2)      !< Statuses.

   call write_image(PNG, rgba, 0_int32, s(1))
   call fig_read_image(PNG, back, s(2))
   ok = all(s == FIG_OK) .and. allocated(back)
   if (ok) ok = all(shape(back) == [4, 37, 23])
   if (ok) ok = all(back == rgba)
   if (.not. ok) write(error_unit, '(A,2(1X,I0),A,A)') 'png equal: statuses', s, ', ', figure_last_error()
   endsubroutine png_equal

   subroutine grey_equal(ok)
   !< A grey PNG reads as R = G = B = the grey, A = 255; a grey + alpha PNG as R = G = B = the grey, A its alpha.
   logical, intent(out)       :: ok          !< Outcome.
   integer(int8), allocatable :: back(:,:,:) !< Pixels read.
   integer(int32)             :: s(4)        !< Statuses.
   integer(int32)             :: c           !< Channel.
   logical                    :: g(2)        !< Each file.
   integer(int8), allocatable :: part(:,:,:) !< The channels written (a contiguous copy).

   part = rgba(1:1,:,:)
   call write_image(GREY, part, 0_int32, s(1))
   call fig_read_image(GREY, back, s(2))
   g(1) = s(1) == FIG_OK .and. s(2) == FIG_OK
   if (g(1)) g(1) = all(shape(back) == [4, 37, 23])
   if (g(1)) then
      g(1) = all(back(4,:,:) == -1_int8)
      do c = 1_int32, 3_int32
         g(1) = g(1) .and. all(back(c,:,:) == rgba(1,:,:))
      enddo
   endif
   part = rgba(1:2,:,:)
   call write_image(GREYA, part, 0_int32, s(3))
   call fig_read_image(GREYA, back, s(4))
   g(2) = s(3) == FIG_OK .and. s(4) == FIG_OK
   if (g(2)) g(2) = all(shape(back) == [4, 37, 23])
   if (g(2)) then
      g(2) = all(back(4,:,:) == rgba(2,:,:))
      do c = 1_int32, 3_int32
         g(2) = g(2) .and. all(back(c,:,:) == rgba(1,:,:))
      enddo
   endif
   ok = all(g)
   if (.not. ok) write(error_unit, '(A,4(1X,I0),2L2)') 'grey equal: statuses, grey, grey + alpha', s, g
   endsubroutine grey_equal

   subroutine independent_png(ok)
   !< The PNG written by Python reads as its pixels: rgba(:, i, 1) the top row, rgba(:, i, 2) the bottom one.
   logical, intent(out)       :: ok          !< Outcome.
   integer(int8), allocatable :: back(:,:,:) !< Pixels read.
   integer(int32)             :: s           !< Status.
   integer(int32)             :: want(4,3,2) !< The pixels, 0-255.

   want(:,1,1) = [255, 0, 0, 255]
   want(:,2,1) = [0, 255, 0, 255]
   want(:,3,1) = [0, 0, 255, 255]
   want(:,1,2) = [255, 255, 255, 128]
   want(:,2,2) = [0, 0, 0, 0]
   want(:,3,2) = [10, 20, 30, 40]
   call write_bytes(PYPNG, PY_BYTES)
   call fig_read_image(PYPNG, back, s)
   ok = s == FIG_OK
   if (ok) ok = all(shape(back) == [4, 3, 2])
   if (ok) ok = all(modulo(int(back, int32), 256_int32) == want)
   if (.not. ok) write(error_unit, '(A,I0,A,A)') 'independent png: status ', s, ', ', figure_last_error()
   endsubroutine independent_png

   subroutine jpeg_within(ok)
   !< A smooth RGB image written as a JPEG of quality 90 reads back within 8 levels of 255 in every byte, 1.5 on
   !< average, opaque (A = 255).
   logical, intent(out)       :: ok          !< Outcome.
   integer(int8), allocatable :: rgb(:,:,:)  !< The image written.
   integer(int8), allocatable :: back(:,:,:) !< Pixels read.
   integer(int32)             :: s(2)        !< Statuses.
   integer(int32)             :: c, i, j     !< Channel, column, row.
   integer(int32)             :: worst       !< Largest difference [levels].
   real(real64)               :: mean        !< Mean difference [levels].

   allocate(rgb(3, 64, 48))
   do j = 1_int32, 48_int32
      do i = 1_int32, 64_int32
         rgb(1, i, j) = byte(4_int32 * (i - 1_int32))
         rgb(2, i, j) = byte(5_int32 * (j - 1_int32))
         rgb(3, i, j) = byte(2_int32 * (i + j))
      enddo
   enddo
   call write_image(JPEG, rgb, 90_int32, s(1))
   call fig_read_image(JPEG, back, s(2))
   ok = all(s == FIG_OK)
   if (ok) ok = all(shape(back) == [4, 64, 48])
   worst = -1_int32
   mean = -1.0_real64
   if (ok) then
      worst = 0_int32
      mean = 0.0_real64
      do c = 1_int32, 3_int32
         worst = max(worst, maxval(abs(modulo(int(back(c,:,:), int32), 256_int32) - &
                                       modulo(int(rgb(c,:,:), int32), 256_int32))))
         mean = mean + sum(abs(modulo(int(back(c,:,:), int32), 256_int32) - &
                               modulo(int(rgb(c,:,:), int32), 256_int32)))
      enddo
      mean = mean / real(size(rgb), real64)
      ok = worst <= 8_int32 .and. mean <= 1.5_real64 .and. all(back(4,:,:) == -1_int8)
   endif
   write(output_unit, '(A,I0,A,F0.3)') 'jpeg quality 90: largest difference ', worst, ', mean ', mean
   if (.not. ok) write(error_unit, '(A,2(1X,I0),A,A)') 'jpeg within: statuses', s, ', ', figure_last_error()
   endsubroutine jpeg_within

   elemental function byte(v) result(b)
   !< The byte of a value 0-255 (128-255 as -128..-1).
   integer(int32), intent(in) :: v !< Value.
   integer(int8)              :: b !< Byte.

   b = int(v - merge(256_int32, 0_int32, v > 127_int32), int8)
   endfunction byte

   subroutine missing_refused(ok)
   !< A file that does not exist: FIG_ERR_FAILED, the message naming the procedure and the file; rgba unallocated.
   logical, intent(out)          :: ok          !< Outcome.
   integer(int8), allocatable    :: back(:,:,:) !< Pixels read.
   integer(int32)                :: s           !< Status.
   character(len=:), allocatable :: msg         !< Message.
   character(len=*), parameter   :: WANT = "fig_read_image: '"//NONE//"' cannot be read: " !< Its start.

   allocate(back(4, 1, 1))
   call fig_read_image(NONE, back, s)
   msg = figure_last_error()
   ok = s == FIG_ERR_FAILED .and. .not. allocated(back) .and. index(msg, WANT) == 1
   if (.not. ok) write(error_unit, '(A,I0,A,A)') 'missing refused: status ', s, ', ', msg
   endsubroutine missing_refused

   subroutine other_format_refused(ok)
   !< A text file and a BMP: FIG_ERR_ARGUMENT, "is not a PNG or JPEG file".
   logical, intent(out)          :: ok          !< Outcome.
   integer(int8), allocatable    :: back(:,:,:) !< Pixels read.
   integer(int32)                :: s(2)        !< Statuses.
   character(len=:), allocatable :: msg(:)      !< Messages.

   allocate(character(len=512) :: msg(2))
   call write_bytes(TEXT, transfer('not an image, a line of text', [0_int8]))
   call fig_read_image(TEXT, back, s(1))
   msg(1) = figure_last_error()
   call write_bytes(BMP, [66_int8, 77_int8, 58_int8, 0_int8, 0_int8, 0_int8, 0_int8, 0_int8, 0_int8, 0_int8, &
                          54_int8, 0_int8, 0_int8, 0_int8, 40_int8, 0_int8])
   call fig_read_image(BMP, back, s(2))
   msg(2) = figure_last_error()
   ok = all(s == FIG_ERR_ARGUMENT) .and. &
        trim(msg(1)) == "fig_read_image: '"//TEXT//"' is not a PNG or JPEG file (the formats FIGURE reads)" .and. &
        trim(msg(2)) == "fig_read_image: '"//BMP//"' is not a PNG or JPEG file (the formats FIGURE reads)"
   if (.not. ok) write(error_unit, '(A,2(1X,I0),4A)') 'other format refused: statuses', s, ', ', trim(msg(1)), &
                                                       ', ', trim(msg(2))
   endsubroutine other_format_refused

   subroutine corrupt_refused(ok)
   !< The RGBA PNG cut to half its length, and a JPEG whose header after its start marker is zeros: FIG_ERR_ARGUMENT,
   !< "is a PNG (JPEG) file that cannot be decoded: Corrupt PNG (JPEG)".
   logical, intent(out)          :: ok          !< Outcome.
   integer(int8), allocatable    :: bytes(:)    !< A file's contents.
   integer(int8), allocatable    :: back(:,:,:) !< Pixels read.
   integer(int32)                :: s(2)        !< Statuses.
   integer(int32)                :: u, n        !< Unit, size [bytes].
   character(len=:), allocatable :: msg(:)      !< Messages.

   allocate(character(len=512) :: msg(2))
   open(newunit=u, file=PNG, access='stream', form='unformatted', status='old', action='read')
   inquire(unit=u, size=n)
   allocate(bytes(n))
   read(u) bytes
   close(u)
   call write_bytes(CUT, bytes(1:n / 2))
   call fig_read_image(CUT, back, s(1))
   msg(1) = figure_last_error()
   call write_bytes(BADJ, [-1_int8, -40_int8, -1_int8, [(0_int8, u = 1, 61)]])
   call fig_read_image(BADJ, back, s(2))
   msg(2) = figure_last_error()
   ok = all(s == FIG_ERR_ARGUMENT) .and. .not. allocated(back) .and. &
        index(msg(1), "fig_read_image: '"//CUT//"' is a PNG file that cannot be decoded: Corrupt PNG") == 1 .and. &
        index(msg(2), "fig_read_image: '"//BADJ//"' is a JPEG file that cannot be decoded: Corrupt JPEG") == 1
   if (.not. ok) write(error_unit, '(A,2(1X,I0),4A)') 'corrupt refused: statuses', s, ', ', trim(msg(1)), ', ', &
                                                      trim(msg(2))
   endsubroutine corrupt_refused

   subroutine texture_load(ok)
   !< tex%load gives a texture of the image's size, drawn in a frame; a failed load names tex%load and leaves the
   !< texture as it was.
   logical, intent(out)          :: ok   !< Outcome.
   type(texture_object)          :: tex  !< Texture.
   integer(int32)                :: s(3) !< Statuses.
   character(len=:), allocatable :: msg  !< Message.
   logical                       :: drawn !< A frame drew it.

   call tex%load(PNG, smooth=.true., stat=s(1))
   ok = s(1) == FIG_OK .and. tex%is_initialized() .and. tex%width() == 37_int32 .and. tex%height() == 23_int32
   drawn = app%next_frame()
   if (drawn) then
      if (ig_begin('image')) call ig_image(tex)
      call ig_end()
   endif
   call tex%load(TEXT, stat=s(2))
   msg = figure_last_error()
   ok = ok .and. drawn .and. s(2) == FIG_ERR_ARGUMENT .and. tex%is_initialized() .and. &
        tex%width() == 37_int32 .and. tex%height() == 23_int32 .and. &
        index(msg, "texture_object%load: '"//TEXT//"' is not a PNG or JPEG file") == 1
   call tex%load(PYPNG, stat=s(3))
   ok = ok .and. s(3) == FIG_OK .and. tex%width() == 3_int32 .and. tex%height() == 2_int32
   call tex%destroy()
   if (.not. ok) write(error_unit, '(A,3(1X,I0),A,A)') 'texture load: statuses', s, ', ', msg
   endsubroutine texture_load

   subroutine load_in_task(ok)
   !< 40 reads of the RGBA PNG in a task, all equal, while the main thread draws frames (more than one); the task's
   !< failure (a missing file) is its own message, and the main thread's last message is left alone.
   logical, intent(out)          :: ok(2)       !< Outcomes: the reads and frames; the messages.
   type(task_object)             :: t           !< Task.
   class(*), allocatable         :: data        !< Result.
   integer(int8), allocatable    :: back(:,:,:) !< Pixels read on the main thread.
   integer(int32)                :: frames      !< Frames while it ran.
   integer(int32)                :: s(2)        !< Statuses: the main thread's failed read, the result.
   character(len=:), allocatable :: before      !< The main thread's message before the task.
   character(len=:), allocatable :: after       !< And after.
   character(len=*), parameter   :: OTHER = 'figure_test_images.other.png.tmp' !< Missing, read by the main thread.
   type(read_job)                :: job         !< What the task is given.

   call fig_read_image(OTHER, back, s(1))
   before = figure_last_error()
   job%path = PNG       ! component by component: a structure constructor here breaks nvfortran 26.9 (internal
   job%missing = NONE   ! compiler error) and ifx 2026.2 (the named constants passed later with a length of 256)
   job%times = 40_int32
   job%expected = rgba
   call t%start(read_work, job)
   frames = 0_int32
   do while (.not. t%done())
      if (.not. app%next_frame()) exit
      frames = frames + 1_int32
      if (ig_begin('drawing')) call ig_text('the main thread draws while the task reads')
      call ig_end()
      if (frames > 10000000_int32) exit
   enddo
   after = figure_last_error()
   call t%result(data, s(2))
   ok = .false.
   select type (data)
   type is (read_job)
      ok(1) = s(2) == FIG_OK .and. data%equal == 40_int32 .and. frames > 1_int32
      ok(2) = s(1) == FIG_ERR_FAILED .and. data%stat == FIG_ERR_FAILED .and. after == before .and. &
              index(data%message, "fig_read_image: '"//NONE//"' cannot be read: ") == 1 .and. &
              index(before, "fig_read_image: '"//OTHER//"' cannot be read: ") == 1
      if (.not. all(ok)) write(error_unit, '(A,4(1X,I0),6A)') 'load in task: statuses, equal reads, frames', s, &
                                                              data%equal, frames, ', task: ', trim(data%message), &
                                                              ', main before: ', before, ', after: ', after
   endselect
   endsubroutine load_in_task

   subroutine load_refused_in_task(ok)
   !< tex%load from a task is refused: FIG_ERR_STATE in its stat and the task's, the message naming it, no texture.
   logical, intent(out)          :: ok   !< Outcome.
   type(task_object)             :: t    !< Task.
   class(*), allocatable         :: data !< Result.
   integer(int32)                :: s    !< Status of the result.
   character(len=:), allocatable :: msg  !< Its message.
   type(read_job)                :: job  !< What the task is given.

   job%path = PNG
   job%equal = -1_int32
   call t%start(load_work, job)
   do while (.not. t%done())
      if (.not. app%next_frame()) exit
   enddo
   call t%result(data, s)
   msg = figure_last_error()
   ok = .false.
   select type (data)
   type is (read_job)
      ok = s == FIG_ERR_STATE .and. data%stat == FIG_ERR_STATE .and. data%equal == 0_int32 .and. &
           index(msg, 'texture_object%load') > 0
      if (.not. ok) write(error_unit, '(A,3(1X,I0),A,A)') 'load refused in task: statuses, texture', s, data%stat, &
                                                          data%equal, ', ', msg
   endselect
   endsubroutine load_refused_in_task

   subroutine remove_files()
   !< Delete the files written.
   character(len=40) :: names(9) !< The files.
   integer(int32)    :: k, u, ios !< Counter, unit, status.

   names = [character(len=40) :: PNG, GREY, GREYA, PYPNG, JPEG, TEXT, BMP, CUT, BADJ]
   do k = 1_int32, size(names, kind=int32)
      open(newunit=u, file=trim(names(k)), status='old', iostat=ios)
      if (ios == 0) close(u, status='delete')
   enddo
   endsubroutine remove_files
endprogram figure_test_images
