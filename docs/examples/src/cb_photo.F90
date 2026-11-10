!< cb_photo_work, the work of cb_photo: a photograph read from its file on a task's thread (a module procedure: it runs
!< on a worker thread).
module cb_photo_work
!< cb_photo_work, the work of cb_photo: a photograph read from its file on a task's thread (a module procedure: it runs
!< on a worker thread).
use, intrinsic :: iso_fortran_env, only : int8, int32
use figure, only : FIG_OK, fig_read_image, figure_last_error, task_handle_object

implicit none
private
public :: photo_job, read_photo

!region work
type :: photo_job
   !< What the task is given (the file) and gives back (the pixels, or why there are none).
   character(len=256)         :: file = ''        !< The photograph: PNG or JPEG.
   integer(int8), allocatable :: rgba(:,:,:)      !< Its pixels, rgba(4, width, height), row 1 at the top.
   integer(int32)             :: stat = -1_int32  !< Status of the read.
   character(len=256)         :: message = ''     !< Its message on a failure.
endtype photo_job

contains
   recursive subroutine read_photo(h, data)
   !< Decode the file: fig_read_image draws nothing, so a task may call it.
   type(task_handle_object), intent(inout) :: h    !< The task's handle.
   class(*),                 intent(inout) :: data !< A photo_job.

   if (h%cancelled()) return
   select type (data)
   type is (photo_job)
      call fig_read_image(trim(data%file), data%rgba, data%stat)
      if (data%stat /= FIG_OK) data%message = figure_last_error()
   endselect
   endsubroutine read_photo
!endregion work
endmodule cb_photo_work

program cb_photo
!< cb_photo, cookbook: a photograph (a PNG or a JPEG, read in a task) beside a computed field, at the same height.
!< `cb_photo [FILE]` opens a window; `cb_photo --check FILE` opens none: it reads FILE, draws two frames headless and
!< prints the photograph's size and its centre pixel, then the refusal of a file that does not exist.
use, intrinsic :: iso_fortran_env, only : int8, int32, output_unit, real64
use figure, only : app_object, FIG_OK, fig_read_image, figure_last_error, ig_begin, ig_end, ig_image, ig_same_line, &
                   ig_set_next_window, ig_text, ip_begin_plot, ip_end_plot, ip_field_image, ip_setup_axes, &
                   ImPlotColormap_Greys, task_object, texture_object
use cb_photo_work, only : photo_job, read_photo

implicit none
integer(int32), parameter     :: NX = 180_int32 !< Values along x.
integer(int32), parameter     :: NY = 120_int32 !< Values along y.
type(app_object)              :: app            !< Application.
type(task_object)             :: t              !< The read.
type(texture_object)          :: photo          !< The photograph on the GPU.
type(photo_job)               :: job            !< What the task gave back.
class(*), allocatable         :: data           !< The task's result.
real(real64)                  :: f(NX, NY)      !< The computed field: a density gradient.
real(real64)                  :: h              !< Height of the pictures [pixels].
character(len=256)            :: arg            !< Command-line argument.
character(len=:), allocatable :: status         !< What the window says about the photograph.
logical                       :: check          !< --check: headless.
integer(int32)                :: frame          !< Frames drawn since the photograph came.
integer(int32)                :: i, j           !< Counters.

!run cb_photo ./cb_photo --check ../../../docs/examples/data/schlieren.jpg
call get_command_argument(1, arg)
check = trim(arg) == '--check'
if (check) call get_command_argument(2, arg)
if (len_trim(arg) == 0) arg = 'schlieren.jpg'
do j = 1_int32, NY
   do i = 1_int32, NX
      f(i, j) = field(real(i, real64) / NX, real(j, real64) / NY)
   enddo
enddo
if (check) then
   call app%init_headless(1000_int32, 360_int32)
else
   call app%init('FIGURE: a photograph beside a field', 1000_int32, 360_int32)
endif
!region start
call t%start(read_photo, photo_job(file=arg))  ! the window draws while the file is decoded
status = 'reading '//trim(arg)//' ...'
!endregion start
frame = -1_int32
do while (app%next_frame())
   if (frame >= 0_int32) frame = frame + 1_int32
   !region take
   if (t%done()) then                          ! once: the pixels to the GPU, on the main thread
      call t%result(data)
      select type (data)
      type is (photo_job)
         if (data%stat == FIG_OK) then
            call photo%init(int(size(data%rgba, 2), int32), int(size(data%rgba, 3), int32), smooth=.true.)
            call photo%update(data%rgba)
            status = trim(data%file)
         else
            status = trim(data%message)
         endif
         job = data
         frame = 0_int32
      endselect
   endif
   !endregion take
   call ig_set_next_window(10.0_real64, 10.0_real64, 980.0_real64, 340.0_real64)
   if (ig_begin('Experiment and simulation')) then
      !region draw
      h = 280.0_real64
      if (photo%is_initialized()) then         ! the photograph at the plot's height, its own proportions
         call ig_image(photo, h * photo%width() / photo%height(), h)
      else
         call ig_text(status)
      endif
      call ig_same_line()
      if (ip_begin_plot('simulation', width=-1.0_real64, height=h)) then
         call ip_setup_axes('x / D', 'y / D')
         call ip_field_image('d rho / dx', f, -3.4_real64, 1.9_real64, -1.76_real64, 1.76_real64, &
                             colormap=ImPlotColormap_Greys, vmin=-1.0_real64, vmax=1.0_real64)
         call ip_end_plot()
      endif
      !endregion draw
   endif
   call ig_end()
   if (check .and. frame == 2_int32) exit       ! --check: two frames with the photograph
enddo
if (check) call report()
call photo%destroy()
call app%destroy()

contains
   pure function field(x, y) result(g)
   !< A stand-in for a computed density gradient: a bow shock ahead of a cylinder at the origin, in [-1, 1].
   real(real64), intent(in) :: x !< Position in [0, 1] along x.
   real(real64), intent(in) :: y !< Position in [0, 1] along y.
   real(real64)             :: g !< Value.
   real(real64)             :: xs, d !< The shock's position, the distance to it.

   xs = -0.68_real64 - (sqrt(1.0_real64 + ((y - 0.5_real64) * 3.52_real64 / 1.1_real64)**2) - 1.0_real64) * 1.6_real64
   d = (x * 5.3_real64 - 3.4_real64) - xs
   g = exp(-(d / 0.07_real64)**2)
   if (hypot(x * 5.3_real64 - 3.4_real64, (y - 0.5_real64) * 3.52_real64) < 0.5_real64) g = -1.0_real64
   endfunction field

   subroutine report()
   !< --check: the photograph's size and centre pixel, then a missing file refused.
   integer(int8), allocatable :: none(:,:,:) !< Pixels of the missing file (never allocated).
   integer(int32)             :: s           !< Status.

   if (job%stat == FIG_OK) then
      write(output_unit, '(A,I0,A,I0,A)') 'photograph: ', size(job%rgba, 2), ' x ', size(job%rgba, 3), ' pixels'
      write(output_unit, '(A,4(1X,I0))') 'centre pixel (R, G, B, A):', &
         modulo(int(job%rgba(:, size(job%rgba, 2) / 2, size(job%rgba, 3) / 2), int32), 256_int32)
      write(output_unit, '(A,L1)') 'texture of that size: ', photo%width() == size(job%rgba, 2)
   else
      write(output_unit, '(A)') trim(job%message)
   endif
   call fig_read_image('no-such-photo.jpg', none, s)
   write(output_unit, '(A,I0,A,A)') 'a missing file: stat ', s, ', ', figure_last_error()
   endsubroutine report
endprogram cb_photo
