!< figure_cmake_consumer, a program built by CMake against an installed FIGURE: three frames drawn headless.
program figure_cmake_consumer
!< figure_cmake_consumer, a program built by CMake against an installed FIGURE: three frames drawn headless.
use figure, only : app_object, ig_begin, ig_end, ig_text

implicit none
type(app_object) :: app   !< Application.
integer          :: frame !< Frame.

call app%init_headless(320, 240)
do frame = 1, 3
   if (.not. app%next_frame()) exit
   if (ig_begin('CMake')) call ig_text('FIGURE through find_package')
   call ig_end()
enddo
call app%destroy()
print '(a)', 'figure_cmake_consumer: three frames drawn headless'
endprogram figure_cmake_consumer
