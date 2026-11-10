!< cb_canvas_test, reference example: a drawing placed where the next item goes, reserved by an invisible button,
!< and tested headless by the extent of its colour.
program cb_canvas_test
!< cb_canvas_test, reference example: a drawing placed where the next item goes, reserved by an invisible button,
!< and tested headless by the extent of its colour.
use, intrinsic :: iso_fortran_env, only : int32, int64, output_unit, real64
use figure, only : app_object, ig_begin, ig_cursor_screen_pos, ig_draw_rect, ig_end, ig_invisible_button, &
                   ig_set_next_window, ig_text
use figure_testing, only : test_click, test_drawn_extent

implicit none
real(real64), parameter :: FILL(4) = [0.20_real64, 0.60_real64, 0.85_real64, 1.0_real64] !< The bar's colour.
type(app_object) :: app                   !< Application.
real(real64)     :: level = 0.25_real64   !< The gauge's level, in [0, 1].
real(real64)     :: at(2) = 0.0_real64    !< Where the gauge is drawn [screen pixels].
real(real64)     :: e(4)                  !< The extent drawn in FILL [screen pixels].
logical          :: found                 !< Something was drawn in FILL.
integer(int32)   :: vertices              !< How many vertices have FILL.
integer(int32)   :: frame                 !< Frame counter.

call app%init_headless(400_int32, 240_int32)
do frame = 1_int32, 8_int32
   if (.not. app%next_frame()) exit
   call ig_set_next_window(10.0_real64, 10.0_real64, 380.0_real64, 220.0_real64, always=.true.)
   if (ig_begin('Gauge')) then
      call ig_text('Click the gauge to fill it.')
      call ig_cursor_screen_pos(at(1), at(2))                 ! where the next item goes [screen pixels]
      call ig_draw_rect(at(1), at(2), at(1) + 300.0_real64, at(2) + 24.0_real64, [0.5_real64, 0.5_real64, 0.5_real64])
      call ig_draw_rect(at(1), at(2), at(1) + 300.0_real64 * level, at(2) + 24.0_real64, FILL, filled=.true.)
      if (ig_invisible_button('gauge', 300.0_real64, 24.0_real64)) level = 1.0_real64 ! reserves the place, takes clicks
      call test_drawn_extent(FILL, e(1), e(2), e(3), e(4), found=found, vertices=vertices) ! drawn so far in FILL
   endif
   call ig_end()
   if (frame == 2_int32) call test_click(at(1) + 150.0_real64, at(2) + 12.0_real64)
enddo
call app%destroy()
write(output_unit, '(A,L1,A,I0,A,F3.1,A,I0,A)') 'found: ', found, ', width: ', nint(e(3) - e(1), int64), &
                                                ' pixels at level ', level, ', ', vertices, ' vertices (a filled rectangle)'
if (.not. found .or. nint(e(3) - e(1)) /= 300 .or. vertices /= 4_int32) error stop 'cb_canvas_test: not as drawn'
endprogram cb_canvas_test
