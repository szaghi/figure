!< figure_test_numbers, numbers and choices driven by synthetic input, headless: vectors, drags, kinds, formats,
!< scales, angles, ranges, radio buttons, list boxes.
program figure_test_numbers
!< figure_test_numbers, numbers and choices driven by synthetic input, headless: vectors, drags, kinds, formats,
!< scales, angles, ranges, radio buttons, list boxes.
!<
!< A value typed into component 2 of a 3-vector changes only that component. A drag of 100 pixels at speed 0.01
!< changes the value by 1; at speed 0.01234 with format '%.2f' the value is rounded to what the format shows. A log
!< slider from 1e-3 to 10 clicked at its centre gives the geometric mean of its ends, 0.1. An int64 beyond 2**31 is
!< shown through its format ('%d cells', copied to the clipboard) and typed back; an int64 slider reaches 5e9. A radio
!< group of three selects the one clicked. A list box of 100 items scrolled by the wheel: the row at its top, clicked,
!< is far down the list. A range's lower end dragged past its upper end stops there. An angle slider at its centre
!< is 90 degrees, pi/2 radians. With enter_returns a field is true only on enter; read_only does not change. Wrong
!< arguments refused with their messages, the values untouched; no frame has a usage error.
use, intrinsic :: ieee_arithmetic, only : ieee_quiet_nan, ieee_value
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64, output_unit
use figure, only : FIG_ERR_ARGUMENT, FIG_OK, app_object, figure_last_error, ig_begin, ig_drag, ig_drag_range, ig_end, &
                   ig_get_clipboard, ig_input, ig_item_rect, ig_last_item, ig_list_box, ig_radio, ig_set_next_item_width, &
                   ig_set_next_window, ig_slider, ig_slider_angle, ig_text, item_status_object
use figure_testing, only : test_click, test_drag, test_key, test_mouse_move, test_type, test_wheel

implicit none
integer(int32), parameter :: NITEMS = 100_int32                   !< Items of the list box.
real(real64),   parameter :: PI = acos(-1.0_real64)               !< pi.
real(real64),   parameter :: W = 300.0_real64                     !< Width of every widget [pixels].
type(app_object)          :: app                                  !< Application.
type(item_status_object)  :: s                                    !< Status of an item.
logical                   :: ok(18)                               !< Per-check outcome.
real(real64)              :: vec(3)                               !< A 3-vector typed into.
real(real64)              :: d                                    !< A dragged value.
real(real32)              :: f2(2)                                !< A dragged 2-vector with a format.
real(real64)              :: cfl                                  !< A log slider.
integer(int64)            :: big                                  !< An int64 typed into.
integer(int64)            :: s64                                  !< An int64 slider.
integer(int32)            :: scheme                               !< A radio group.
integer(int32)            :: pick                                 !< A list box.
integer(int32)            :: lo                                   !< Lower end of a range.
integer(int32)            :: hi                                   !< Upper end.
real(real64)              :: angle                                !< An angle [radians].
real(real64)              :: e                                    !< A field true only on enter.
real(real64)              :: ro                                   !< A read-only field.
real(real64)              :: rect(4, 12)                          !< Rectangles of the widgets [pixels].
character(len=10)         :: items(NITEMS)                        !< The list box's items.
character(len=:), allocatable :: copied                           !< The int64 field's text, copied.
integer(int32)            :: radio_clicks                         !< Radio buttons returning true.
integer(int32)            :: radio_edits                          !< ... reported as edits.
integer(int32)            :: list_picks                           !< List box picks.
integer(int32)            :: list_edits                           !< ... reported as edits.
integer(int32)            :: vec_changes                          !< Frames the vector field returned true.
integer(int32)            :: enter_true                           !< Frames the enter field returned true.
integer(int32)            :: enter_true_left                      !< ... by the time it was left without enter.
real(real64)              :: e_left                               !< Its value then.
integer(int32)            :: ro_changes                           !< Frames the read-only field returned true.
integer(int32)            :: f                                    !< Frame.
integer(int32)            :: i                                    !< Counter.
integer(int32)            :: st                                   !< Status of a frame.
integer(int32)            :: errors                               !< Frames with a usage error.
integer(int32)            :: bad(13)                              !< Statuses of refused calls.
character(len=160)        :: msg(13)                              !< Their messages.
real(real64), allocatable :: vbad(:)                             !< A vector of no components.
real(real64)              :: nan                                  !< NaN.
integer(int32)            :: ibad                                 !< Values given to refused calls.
real(real64)              :: rbad                                 !< ...

vec = [1.0_real64, 2.0_real64, 3.0_real64]
d = 2.0_real64
f2 = [2.0_real32, 5.0_real32]
cfl = 1.0_real64
big = 5000000000_int64
s64 = 0_int64
scheme = 1_int32
pick = 1_int32
lo = 20_int32
hi = 60_int32
angle = 0.0_real64
e = 1.0_real64
ro = 1.0_real64
do i = 1_int32, NITEMS
   write(items(i), '(A,I0)') 'item ', i
enddo
copied = ''
rect = 0.0_real64
radio_clicks = 0_int32
radio_edits = 0_int32
list_picks = 0_int32
list_edits = 0_int32
vec_changes = 0_int32
enter_true = 0_int32
enter_true_left = -1_int32
e_left = 0.0_real64
ro_changes = 0_int32
errors = 0_int32
bad = -1_int32
msg = ''
nan = ieee_value(nan, ieee_quiet_nan)
allocate(vbad(0))
ibad = 7_int32
rbad = 7.0_real64
call app%init_headless(900_int32, 760_int32)
do f = 1_int32, 240_int32
   if (.not. app%next_frame(st)) exit
   if (st /= FIG_OK) errors = errors + 1_int32
   call ig_set_next_window(10.0_real64, 10.0_real64, 860.0_real64, 740.0_real64, always=.true.)
   if (ig_begin('Numbers')) then
      call ig_set_next_item_width(W)
      if (ig_input('##vec', vec)) vec_changes = vec_changes + 1_int32
      call ig_item_rect(rect(1, 1), rect(2, 1), rect(3, 1), rect(4, 1))
      call ig_set_next_item_width(W)
      if (ig_drag('##drag', d, speed=0.01_real64, format='%.4f')) continue
      call ig_item_rect(rect(1, 2), rect(2, 2), rect(3, 2), rect(4, 2))
      call ig_set_next_item_width(W)
      if (ig_drag('##fmt', f2, speed=0.01234_real64, format='%.2f')) continue
      call ig_item_rect(rect(1, 3), rect(2, 3), rect(3, 3), rect(4, 3))
      call ig_set_next_item_width(W)
      if (ig_slider('##cfl', cfl, 1.0e-3_real64, 10.0_real64, format='%.6g', scale='log')) continue
      call ig_item_rect(rect(1, 4), rect(2, 4), rect(3, 4), rect(4, 4))
      call ig_set_next_item_width(W)
      if (ig_input('##big', big, format='%d cells')) continue
      call ig_item_rect(rect(1, 5), rect(2, 5), rect(3, 5), rect(4, 5))
      if (ig_radio('WENO5', scheme, 1_int32)) call radio_clicked()
      if (ig_radio('WENO7', scheme, 2_int32)) call radio_clicked()
      if (ig_radio('TVD', scheme, 3_int32)) call radio_clicked()
      call ig_item_rect(rect(1, 6), rect(2, 6), rect(3, 6), rect(4, 6))
      call ig_set_next_item_width(W)
      if (ig_list_box('##list', pick, items, height=120.0_real64)) then
         list_picks = list_picks + 1_int32
         s = ig_last_item()
         if (s%edited) list_edits = list_edits + 1_int32
      endif
      call ig_item_rect(rect(1, 7), rect(2, 7), rect(3, 7), rect(4, 7))
      call ig_set_next_item_width(W)
      if (ig_slider('##s64', s64, 0_int64, 10000000000_int64)) continue
      call ig_item_rect(rect(1, 8), rect(2, 8), rect(3, 8), rect(4, 8))
      call ig_set_next_item_width(W)
      if (ig_drag_range('##range', lo, hi, speed=1.0_real64, vmin=0_int32, vmax=100_int32)) continue
      call ig_item_rect(rect(1, 9), rect(2, 9), rect(3, 9), rect(4, 9))
      call ig_set_next_item_width(W)
      if (ig_slider_angle('##angle', angle, 0.0_real64, 180.0_real64)) continue
      call ig_item_rect(rect(1, 10), rect(2, 10), rect(3, 10), rect(4, 10))
      call ig_set_next_item_width(W)
      if (ig_input('##enter', e, enter_returns=.true.)) enter_true = enter_true + 1_int32
      call ig_item_rect(rect(1, 11), rect(2, 11), rect(3, 11), rect(4, 11))
      call ig_set_next_item_width(W)
      if (ig_input('##ro', ro, read_only=.true.)) ro_changes = ro_changes + 1_int32
      call ig_item_rect(rect(1, 12), rect(2, 12), rect(3, 12), rect(4, 12))
      call ig_text('the end')
      if (f == 220_int32) call refused_calls()
   endif
   call ig_end()
   call script(f)
enddo
if (app%next_frame(st)) continue
if (st /= FIG_OK) errors = errors + 1_int32
call app%destroy()

ok(1) = all(vec == [1.0_real64, 7.5_real64, 3.0_real64]) .and. vec_changes >= 1_int32 ! only component 2
ok(2) = abs(d - 3.0_real64) < 1.0e-9_real64                          ! 100 pixels at 0.01 per pixel: +1
ok(3) = abs(f2(1) - 3.23_real32) < 1.0e-6_real32 .and. f2(2) == 5.0_real32 ! +1.234, rounded to '%.2f'
ok(4) = abs(cfl / 0.1_real64 - 1.0_real64) < 1.0e-4_real64           ! log scale: the centre is sqrt(1e-3 * 10)
ok(5) = copied == '5000000000 cells'                                  ! the int64 through its format
ok(6) = big == 9000000000_int64                                       ! ... typed back (its upper 32 bits differ)
ok(7) = abs(s64 - 5000000000_int64) < 100000000_int64                 ! an int64 slider beyond 2**31
ok(8) = scheme == 3_int32 .and. radio_clicks == 1_int32 .and. radio_edits == 1_int32 ! one of the group
ok(9) = pick > 6_int32 .and. list_picks == 1_int32 .and. list_edits == 1_int32 ! scrolled, then picked
ok(10) = abs((rect(4, 7) - rect(2, 7)) - 120.0_real64) < 1.0_real64   ! the list box's height
ok(11) = lo == 60_int32 .and. hi == 60_int32                          ! the lower end stops at the upper one
ok(12) = abs(angle - 0.5_real64 * PI) < 1.0e-5_real64                 ! 90 degrees, in radians
ok(13) = enter_true_left == 0_int32 .and. abs(e_left - 4.5_real64) < 1.0e-12_real64 ! left: changed, not true
ok(14) = enter_true == 1_int32 .and. abs(e - 8.5_real64) < 1.0e-12_real64 ! enter: true
ok(15) = ro == 1.0_real64 .and. ro_changes == 0_int32                 ! read-only
ok(16) = all(bad == int(FIG_ERR_ARGUMENT, int32)) .and. ibad == 7_int32 .and. rbad == 7.0_real64 .and. &
         index(msg(1), "ig_input: format '%f' is not a format of an integer") == 1 .and.                   &
         msg(2) == "ig_drag: unknown scale 'cubic' ('linear' or 'log')" .and.                            &
         msg(3) == "ig_drag: scale 'log' needs vmin and vmax" .and.                                      &
         msg(4) == 'ig_slider: vmax 2147483647 is out of -1073741823 to 1073741823' .and.                &
         msg(5) == 'ig_slider: vmin is NaN' .and.                                                        &
         msg(6) == 'ig_drag: speed 0.00000E+000 is not above 0 and within single precision' .and.        &
         msg(7) == 'ig_input: value has no components' .and.                                             &
         msg(8) == 'ig_drag_range: lo 5 is above hi 2' .and.                                             &
         msg(9) == 'ig_slider_angle: deg_min is NaN' .and.                                               &
         msg(10) == "ig_drag: format '%0000000000000000000000001.2f' has a conversion longer than 24 characters" .and. &
         msg(11) == 'ig_list_box: height is NaN' .and.                                                   &
         msg(12) == "ig_slider: format '%d' is not a format of a real: one conversion %f, %e, %g or %a (or %F, %E, "// &
                    "%G, %A) expected, with optional flags, width and precision" .and.                    &
         msg(13) == 'ig_slider: vmin -1.79769E+308 is out of -8.98847E+307 to 8.98847E+307' ! negative reals written
ok(17) = errors == 0_int32                                            ! no usage error kept for a frame
ok(18) = all(rect(3, :) > rect(1, :))                                 ! the geometry was read

write(output_unit, '(A,*(L2))') 'figure_test_numbers checks:', ok
if (.not. all(ok)) then
   write(output_unit, '(A,3F10.4,A,I0)') 'vec ', vec, ' changes ', vec_changes
   write(output_unit, '(A,F12.6,A,2F10.5,A,ES14.6)') 'd ', d, ' f2 ', f2, ' cfl ', cfl
   write(output_unit, '(A,A,A,I0,A,I0)') 'copied "', copied, '" big ', big, ' s64 ', s64
   write(output_unit, '(A,3I4,A,3I4)') 'scheme, clicks, edits ', scheme, radio_clicks, radio_edits, &
      ' pick, picks, edits ', pick, list_picks, list_edits
   write(output_unit, '(A,F8.1,A,2I4,A,F12.8)') 'list height ', rect(4, 7) - rect(2, 7), ' range ', lo, hi, &
      ' angle ', angle
   write(output_unit, '(A,I3,F8.3,A,I3,F8.3,A,F8.3,I3)') 'enter left ', enter_true_left, e_left, ' enter ', &
      enter_true, e, ' ro ', ro, ro_changes
   write(output_unit, '(A,13I3,A,I0)') 'statuses ', bad, ' errors ', errors
   do i = 1_int32, 13_int32
      write(output_unit, '(A)') trim(msg(i))
   enddo
endif
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(ok)
if (.not. all(ok)) error stop 1
contains
   subroutine radio_clicked()
   !< A radio button returned true: count it, and whether it is reported as an edit.
   radio_clicks = radio_clicks + 1_int32
   s = ig_last_item()
   if (s%edited) radio_edits = radio_edits + 1_int32
   endsubroutine radio_clicked

   subroutine refused_calls()
   !< Wrong arguments, each refused with FIG_ERR_ARGUMENT and its message; the values are left alone.
   real(real32)   :: angle32 !< An angle.
   integer(int32) :: k(2)    !< A range upside down.

   angle32 = 0.0_real32
   if (ig_input('e1', ibad, format='%f', stat=bad(1))) continue
   msg(1) = figure_last_error()
   if (ig_drag('e2', rbad, scale='cubic', stat=bad(2))) continue
   msg(2) = figure_last_error()
   if (ig_drag('e3', rbad, scale='log', stat=bad(3))) continue
   msg(3) = figure_last_error()
   if (ig_slider('e4', ibad, 0_int32, huge(0_int32), stat=bad(4))) continue
   msg(4) = figure_last_error()
   if (ig_slider('e5', rbad, nan, 1.0_real64, stat=bad(5))) continue
   msg(5) = figure_last_error()
   if (ig_drag('e6', rbad, speed=0.0_real64, stat=bad(6))) continue
   msg(6) = figure_last_error()
   if (ig_input('e7', vbad, stat=bad(7))) continue
   msg(7) = figure_last_error()
   k = [5_int32, 2_int32]
   if (ig_drag_range('e8', k(1), k(2), stat=bad(8))) continue
   msg(8) = figure_last_error()
   if (ig_slider_angle('e9', angle32, deg_min=real(nan, real32), stat=bad(9))) continue
   msg(9) = figure_last_error()
   if (ig_drag('e10', rbad, format='%0000000000000000000000001.2f', stat=bad(10))) continue
   msg(10) = figure_last_error()
   if (ig_list_box('e11', ibad, items, height=nan, stat=bad(11))) continue
   msg(11) = figure_last_error()
   if (ig_slider('e12', rbad, 0.0_real64, 1.0_real64, format='%d', stat=bad(12))) continue
   msg(12) = figure_last_error()
   if (ig_slider('e13', rbad, -huge(1.0_real64), 1.0_real64, stat=bad(13))) continue ! a negative real in the message
   msg(13) = figure_last_error()
   endsubroutine refused_calls

   subroutine script(frame)
   !< The input, by frame.
   integer(int32), intent(in) :: frame !< Frame.
   real(real64)                :: y    !< A centre line.

   select case (frame)
   case (5_int32)                                 ! component 2 of the vector: the middle third
      call replace(0.5_real64 * (rect(1, 1) + rect(3, 1)), centre(1), '7.5')
      call test_key('enter')
   case (20_int32)                                ! 100 pixels to the right
      call test_drag(mid(2), centre(2), mid(2) + 100.0_real64, centre(2))
   case (35_int32)                                ! component 1 of the 2-vector, 100 pixels to the right
      call test_drag(rect(1, 3) + 40.0_real64, centre(3), rect(1, 3) + 140.0_real64, centre(3))
   case (50_int32)                                ! the log slider's centre
      call test_click(mid(4), centre(4))
   case (65_int32)                                ! the int64 field: copy its text
      call test_click(mid(5), centre(5))
      call test_key('shortcut', down=.true.)
      call test_key('c')
      call test_key('shortcut', down=.false.)
   case (75_int32)                                ! ... then type a value beyond 2**32
      copied = ig_get_clipboard()
      call replace(mid(5), centre(5), '9000000000')
      call test_key('enter')
   case (90_int32)                                ! the third radio button
      call test_click(rect(1, 6) + 8.0_real64, centre(6))
   case (105_int32)                               ! the wheel over the list box
      call test_mouse_move(mid(7), centre(7))
      call test_wheel(-5.0_real64)
   case (115_int32)                               ! the row at its top
      call test_click(mid(7), rect(2, 7) + 12.0_real64)
   case (130_int32)                               ! the int64 slider's centre
      call test_click(mid(8), centre(8))
   case (145_int32)                               ! the range's lower end, 100 pixels right: past the upper end
      call test_drag(rect(1, 9) + 30.0_real64, centre(9), rect(1, 9) + 130.0_real64, centre(9))
   case (160_int32)                               ! the angle slider's centre
      call test_click(mid(10), centre(10))
   case (175_int32)                               ! the enter field, left by a click elsewhere
      call replace(mid(11), centre(11), '4.5')
      y = rect(4, 12) + 60.0_real64
      call test_click(mid(11), y)
   case (188_int32)
      enter_true_left = enter_true
      e_left = e
   case (190_int32)                               ! ... then enter
      call replace(mid(11), centre(11), '8.5')
      call test_key('enter')
   case (205_int32)                               ! the read-only field
      call replace(mid(12), centre(12), '9')
      call test_key('enter')
   endselect
   endsubroutine script

   pure function mid(k) result(x)
   !< Abscissa of the centre of widget `k`.
   integer(int32), intent(in) :: k !< Widget.
   real(real64)               :: x !< Abscissa [pixels].
   x = 0.5_real64 * (rect(1, k) + rect(3, k))
   endfunction mid

   pure function centre(k) result(y)
   !< Ordinate of the centre of widget `k`.
   integer(int32), intent(in) :: k !< Widget.
   real(real64)               :: y !< Ordinate [pixels].
   y = 0.5_real64 * (rect(2, k) + rect(4, k))
   endfunction centre

   subroutine replace(x, y, text)
   !< Click the field at (x, y), select its text (end, shift+home) and type `text`.
   real(real64),     intent(in) :: x    !< Abscissa [pixels].
   real(real64),     intent(in) :: y    !< Ordinate [pixels].
   character(len=*), intent(in) :: text !< New text.
   call test_click(x, y)
   call test_key('end')
   call test_key('shift', down=.true.)
   call test_key('home')
   call test_key('shift', down=.false.)
   call test_type(text)
   endsubroutine replace
endprogram figure_test_numbers
