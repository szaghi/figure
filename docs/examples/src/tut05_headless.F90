!< tut05_headless, tutorial chapter 5: test a panel without a display, by synthetic mouse input.
module tut05_panel
!< The panel under test: the same procedure the application calls every frame.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : ig_begin, ig_button, ig_end, ig_item_rect, ig_set_next_window

implicit none
private
public :: panel_object, draw_panel

type :: panel_object
   !< State of the panel: ordinary variables.
   integer(int32) :: runs = 0_int32          !< Times "Run" was pressed.
   real(real64)   :: run_at(2) = 0.0_real64  !< Center of the "Run" button [pixels], for the test.
endtype panel_object

contains
   subroutine draw_panel(panel)
   !< Declare the panel for this frame.
   type(panel_object), intent(inout) :: panel !< Panel.
   real(real64)                      :: x0    !< Item rectangle, left [pixels].
   real(real64)                      :: y0    !< Item rectangle, top [pixels].
   real(real64)                      :: x1    !< Item rectangle, right [pixels].
   real(real64)                      :: y1    !< Item rectangle, bottom [pixels].

   call ig_set_next_window(10.0_real64, 10.0_real64, 300.0_real64, 200.0_real64, always=.true.)
   if (ig_begin('Panel')) then
      if (ig_button('Run')) panel%runs = panel%runs + 1_int32
      call ig_item_rect(x0, y0, x1, y1)
      panel%run_at = [0.5_real64 * (x0 + x1), 0.5_real64 * (y0 + y1)]
   endif
   call ig_end()
   endsubroutine draw_panel
endmodule tut05_panel

program tut05_headless
!< Click "Run" once: hover, press, release, one frame each.
use, intrinsic :: iso_c_binding, only : c_float, c_int
use, intrinsic :: iso_fortran_env, only : int32, output_unit
use figure, only : app_object
use figure_c_native, only : fig_input_mouse
use tut05_panel, only : panel_object, draw_panel

implicit none
type(app_object)   :: app   !< Application.
type(panel_object) :: panel !< Panel under test.
integer(int32)     :: frame !< Frame counter.
!run tut05 ./tut05_headless

!region test
call app%init_headless(400_int32, 300_int32)
do frame = 1_int32, 6_int32
   if (.not. app%next_frame()) exit
   call draw_panel(panel)
   ! the input queued now is seen by the next frame
   select case (frame)
   case (1_int32, 2_int32)
      call fig_input_mouse(real(panel%run_at(1), c_float), real(panel%run_at(2), c_float), 0_c_int) ! hover
   case (3_int32)
      call fig_input_mouse(real(panel%run_at(1), c_float), real(panel%run_at(2), c_float), 1_c_int) ! press
   case (4_int32)
      call fig_input_mouse(real(panel%run_at(1), c_float), real(panel%run_at(2), c_float), 0_c_int) ! release
   endselect
enddo
call app%destroy()
write(output_unit, '(A,I0)') 'runs: ', panel%runs
if (panel%runs /= 1_int32) error stop 'tut05_headless: expected one click'
!endregion test
endprogram tut05_headless
