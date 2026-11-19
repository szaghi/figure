!< cb_golden_platform, cookbook: a golden test whose tolerance the CI job sets for its platform.
program cb_golden_platform
!< cb_golden_platform, cookbook: a golden test whose tolerance the CI job sets for its platform.
!<
!< The goldens are made on one platform (Linux here); on another, where the C library's maths moves a pixel, the job
!< gives the tolerance measured there in GOLDEN_THRESHOLD and GOLDEN_MAX_FAILED. Usage: cb_golden_platform GOLDEN.
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object, figure_last_error, ig_begin, ig_end, ig_set_next_window, ig_text
use figure_testing, only : test_capture, test_compare_image

implicit none
type(app_object)   :: app        !< Application.
character(len=256) :: golden     !< The committed picture.
integer(int32)     :: threshold  !< Largest difference of a channel that passes [0-255].
integer(int32)     :: max_failed !< Pixels allowed to fail.
integer(int32)     :: frame      !< Frame counter.
logical            :: same       !< The picture matches.

call get_command_argument(1, golden)
call app%init_headless(320_int32, 160_int32)
do frame = 1, 3                               ! a window is placed from its second frame
   if (.not. app%next_frame()) exit
   call draw()
enddo
call test_capture('panel.png')                ! this frame, written when it is rendered
if (app%next_frame()) call draw()             ! ... now
threshold = env_int('GOLDEN_THRESHOLD', 2_int32)  ! test_compare_image's defaults where the goldens are made
max_failed = env_int('GOLDEN_MAX_FAILED', 0_int32)
same = test_compare_image('panel.png', trim(golden), threshold=threshold, max_failed=max_failed)
if (.not. same) then
   write(output_unit, '(A)') figure_last_error() ! how many pixels failed, by how much, where
   error stop 1                                  ! panel.new.png and panel.diff.png are beside the golden
endif
call app%destroy()

contains
   subroutine draw()
   !< The panel under test.
   call ig_set_next_window(10.0_real64, 10.0_real64, 300.0_real64, 140.0_real64, always=.true.)
   if (ig_begin('Panel')) call ig_text('a golden test')
   call ig_end()
   endsubroutine draw

   function env_int(name, default) result(value)
   !< An integer from the environment variable `name`, or `default` when it is not set or not an integer.
   character(len=*), intent(in) :: name    !< Variable.
   integer(int32),   intent(in) :: default !< Value when not set.
   integer(int32)               :: value   !< Value.
   character(len=32)            :: text    !< The variable's text.
   integer(int32)               :: status  !< Its status.
   integer(int32)               :: ios     !< Read status.

   value = default
   call get_environment_variable(name, text, status=status)
   if (status /= 0) return
   read(text, *, iostat=ios) value
   if (ios /= 0) value = default
   endfunction env_int
endprogram cb_golden_platform
