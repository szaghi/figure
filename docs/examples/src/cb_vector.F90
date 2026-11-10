!< cb_vector, cookbook: a vector parameter with units: gravity dragged, a probe point typed, a wind direction in degrees.
program cb_vector
!< cb_vector, cookbook: a vector parameter with units: gravity dragged, a probe point typed, a wind direction in degrees.
!<
!< The gravity vector is one widget of three drag boxes, each showing its unit; the probe point three fields; the wind
!< direction a slider in degrees over a variable in radians. `cb_vector --check` opens no window: it drags component 3
!< of gravity and types component 2 of the probe headless, and prints the values.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, ig_begin, ig_drag, ig_em, ig_end, ig_input, ig_item_rect, ig_set_next_item_width, &
                   ig_set_next_window, ig_slider_angle, ig_text
use figure_testing, only : test_click, test_drag, test_key, test_type
implicit none
real(real64), parameter :: PI = acos(-1.0_real64) !< pi.
type(app_object)        :: app                    !< Application.
real(real64)            :: g(3)                   !< Gravity [m/s^2].
real(real64)            :: probe(3)               !< Probe point [m].
real(real64)            :: wind                   !< Wind direction, from the north, clockwise [radians].
real(real64)            :: width                  !< Width of the widgets [pixels].
real(real64)            :: g_at(4)                !< Rectangle of the gravity drags [pixels].
real(real64)            :: probe_at(4)            !< Rectangle of the probe fields [pixels].
character(len=16)       :: arg                    !< First argument.
logical                 :: check                  !< --check: headless, scripted input.
integer(int32)          :: frame                  !< Frame counter.
!run cb_vector ./cb_vector --check
g = [0.0_real64, 0.0_real64, -9.81_real64]
probe = [1.0_real64, 0.0_real64, 0.5_real64]
wind = 0.25_real64 * PI
g_at = 0.0_real64
probe_at = 0.0_real64
call get_command_argument(1, arg)
check = trim(arg) == '--check'
if (check) then
   call app%init_headless(620_int32, 200_int32)
else
   call app%init('FIGURE: a vector parameter', 620_int32, 200_int32)
endif
frame = 0_int32
do while (app%next_frame())
   frame = frame + 1_int32
   call ig_set_next_window(10.0_real64, 10.0_real64, 600.0_real64, 180.0_real64)
   if (ig_begin('Case')) then
      width = ig_em(24.0_real64)
      !region vector
      call ig_set_next_item_width(width)
      if (ig_drag('gravity', g, speed=0.01_real64, vmin=-50.0_real64, vmax=50.0_real64, format='%.2f m/s²')) then
         continue                                     ! g changed: the program reacts here
      endif
      call ig_item_rect(g_at(1), g_at(2), g_at(3), g_at(4))
      call ig_set_next_item_width(width)
      if (ig_input('probe', probe, format='%.3f m')) continue
      call ig_item_rect(probe_at(1), probe_at(2), probe_at(3), probe_at(4))
      call ig_set_next_item_width(width)
      if (ig_slider_angle('wind from', wind, 0.0_real64, 360.0_real64)) continue ! radians, shown in degrees
      !endregion vector
      call ig_text('|g| = '//number(norm2(g))//' m/s², wind '//number(wind)//' rad')
   endif
   call ig_end()
   if (check) then
      call script(frame)
      if (frame == 40_int32) exit
   endif
enddo
call app%destroy()
contains
   subroutine script(f)
   !< The input of --check, by frame: component 3 of gravity dragged 100 pixels left (0.01 m/s^2 per pixel), then
   !< 0.25 typed into component 2 of the probe.
   integer(int32), intent(in) :: f    !< Frame.
   real(real64)                :: x    !< Centre of a component [pixels].
   real(real64)                :: y    !< Centre line [pixels].

   select case (f)
   case (3_int32)
      call said('at the start')
      x = g_at(1) + 2.5_real64 * width / 3.0_real64      ! the third of three boxes
      y = 0.5_real64 * (g_at(2) + g_at(4))
      call test_drag(x, y, x - 100.0_real64, y)
   case (15_int32)
      call said('component 3 of gravity dragged 100 pixels left')
      x = probe_at(1) + 1.5_real64 * width / 3.0_real64  ! the second of three fields
      y = 0.5_real64 * (probe_at(2) + probe_at(4))
      call test_click(x, y)
      call test_type('0.25')
      call test_key('enter')
   case (30_int32)
      call said('0.25 typed into component 2 of the probe')
   endselect
   endsubroutine script

   subroutine said(what)
   !< Print the values after `what` happened.
   character(len=*), intent(in) :: what !< What happened.
   write(output_unit, '(A)') what//':'
   write(output_unit, '(A,3F8.2,A)') '  gravity', g, ' m/s^2'
   write(output_unit, '(A,3F9.3,A)') '  probe  ', probe, ' m'
   write(output_unit, '(A,F8.1,A)') '  wind   ', wind * 180.0_real64 / PI, ' degrees'
   endsubroutine said

   pure function number(x) result(text)
   !< `x` written with two decimals.
   real(real64), intent(in)      :: x    !< The number.
   character(len=:), allocatable :: text !< Its text.
   character(len=16)             :: buf  !< Buffer.
   write(buf, '(F0.2)') x
   text = trim(buf)
   endfunction number
endprogram cb_vector
