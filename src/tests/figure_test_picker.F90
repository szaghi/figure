!< figure_test_picker, the colour picker (ig_color_picker) driven by synthetic input, headless.
program figure_test_picker
!< figure_test_picker, the colour picker (ig_color_picker) driven by synthetic input, headless.
!<
!< Four pickers 240 pixels wide, each in its own window. A, RGB with the hue bar: a click at the saturation-value
!< square's top-left corner makes the colour white, at its bottom-left black, at its top-right the pure hue (red, the
!< colour it started from), and a click on the hue bar a third of the way down turns it green. B, RGBA: a click at the
!< bottom of the alpha bar makes the alpha 0 and leaves the colour. C, `wheel=.true.`: a click on the hue wheel's ring
!< to the right of its centre turns blue to red (the same point on a hue bar would be cyan). D, `inputs=.false.`: the
!< same width as A, shorter by the fields A has below. A colour of 2 components is refused with its status and message;
!< no picker reports a change on a frame without input.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : FIG_ERR_ARGUMENT, FIG_OK, app_object, figure_last_error, ig_begin, ig_color_picker, ig_end, &
                   ig_frame_height, ig_get_style_var, ig_item_rect, ig_pop_item_width, ig_push_item_width,      &
                   ig_set_next_window
use figure_testing, only : test_click

implicit none
real(real64), parameter :: WIDTH = 240.0_real64 !< The pickers' item width [pixels].
real(real64), parameter :: TOL = 0.03_real64    !< Tolerance of a component (single precision, a pixel's step).
type(app_object)        :: app                  !< Application.
logical                 :: ok(10)               !< Per-check outcome.
real(real64)            :: rgb(3)               !< Picker A's colour.
real(real64)            :: rgba(4)              !< Picker B's.
real(real64)            :: wheel(3)             !< Picker C's.
real(real64)            :: plain(3)             !< Picker D's.
real(real64)            :: bad(2)               !< A colour of 2 components.
real(real64)            :: ra(4), rb(4)         !< Rectangles of pickers A and B [pixels].
real(real64)            :: rc(4), rd(4)         !< ... C and D.
real(real64)            :: inner(2)             !< The style's ItemInnerSpacing [pixels].
real(real64)            :: bars                 !< Width of the hue and alpha bars: the frame height [pixels].
real(real64)            :: sv                   !< Side of A's saturation-value square [pixels].
real(real64)            :: svb                  !< ... of B's (narrower: B has an alpha bar).
real(real64)            :: seen(3, 4)           !< A's colour after each of its four clicks.
real(real64)            :: before(3)            !< B's colour before its click.
integer(int32)          :: changes(4)           !< Frames each picker reported a change.
integer(int32)          :: idle_changes         !< Changes reported before the first click or after the last.
integer(int32)          :: st_bad               !< Status of the refused call.
character(len=160)      :: msg_bad              !< Its message.
integer(int32)          :: nv                   !< Values of a style variable.
integer(int32)          :: f                    !< Frame.

rgb = [1.0_real64, 0.0_real64, 0.0_real64]
rgba = [0.2_real64, 0.4_real64, 0.6_real64, 1.0_real64]
wheel = [0.0_real64, 0.0_real64, 1.0_real64]
plain = [0.5_real64, 0.5_real64, 0.5_real64]
bad = 0.5_real64
ok = .false.
seen = -1.0_real64
before = -1.0_real64
changes = 0_int32
idle_changes = 0_int32
st_bad = -1_int32
msg_bad = ''
call app%init_headless(900_int32, 900_int32)
do f = 1_int32, 80_int32
   if (.not. app%next_frame()) exit
   call ig_get_style_var('ItemInnerSpacing', inner, nv)
   bars = ig_frame_height()
   call picker_window('A', 10.0_real64, 10.0_real64, 1_int32)
   call picker_window('B', 310.0_real64, 10.0_real64, 2_int32)
   call picker_window('C', 10.0_real64, 410.0_real64, 3_int32)
   call picker_window('D', 310.0_real64, 410.0_real64, 4_int32)
   sv = WIDTH - (bars + inner(1))
   svb = WIDTH - 2.0_real64 * (bars + inner(1))
   select case (f)
   case (10_int32)                                                ! A: top-left of the square, white
      call test_click(ra(1) + 2.0_real64, ra(2) + 2.0_real64)
   case (20_int32)                                                ! A: bottom-left, black
      seen(:, 1) = rgb
      call test_click(ra(1) + 2.0_real64, ra(2) + sv - 2.0_real64)
   case (30_int32)                                                ! A: top-right, the pure hue
      seen(:, 2) = rgb
      call test_click(ra(1) + sv - 2.0_real64, ra(2) + 2.0_real64)
   case (40_int32)                                                ! A: the hue bar, a third of the way down
      seen(:, 3) = rgb
      call test_click(ra(1) + sv + inner(1) + 0.5_real64 * bars, ra(2) + sv / 3.0_real64)
   case (50_int32)                                                ! B: the bottom of the alpha bar
      seen(:, 4) = rgb
      before = rgba(1:3)
      call test_click(rb(1) + svb + 2.0_real64 * inner(1) + 1.5_real64 * bars, rb(2) + svb - 2.0_real64)
   case (60_int32)                                                ! C: the wheel's ring, right of its centre (the last)
      call test_click(rc(1) + 0.5_real64 * (sv + bars) + 0.46_real64 * sv, rc(2) + 0.5_real64 * sv)
   endselect
enddo
call app%destroy()

ok(1) = all(abs(seen(:, 1) - 1.0_real64) < TOL)                                                   ! white
ok(2) = all(abs(seen(:, 2)) < TOL)                                                                ! black
ok(3) = abs(seen(1, 3) - 1.0_real64) < TOL .and. all(abs(seen(2:3, 3)) < TOL)                     ! red, the hue kept
ok(4) = seen(2, 4) > 1.0_real64 - TOL .and. seen(1, 4) < TOL .and. seen(3, 4) < TOL               ! green
ok(5) = abs(rgba(4)) < TOL .and. all(abs(rgba(1:3) - before) < TOL)                              ! alpha 0, colour kept
ok(6) = wheel(1) > 1.0_real64 - TOL .and. wheel(2) < TOL .and. wheel(3) < TOL                     ! the wheel: red
ok(7) = abs((rd(3) - rd(1)) - (ra(3) - ra(1))) < 1.0_real64 .and. rd(4) - rd(2) < ra(4) - ra(2) - bars ! no fields
ok(8) = all(changes(1:3) >= 1_int32) .and. changes(4) == 0_int32 .and. idle_changes == 0_int32
ok(9) = st_bad == FIG_ERR_ARGUMENT .and. msg_bad == 'ig_color_picker: the colour needs 3 (RGB) or 4 (RGBA) components'
ok(10) = all(bad == 0.5_real64)

write(output_unit, '(A,4F8.1)') 'picker A rect ', ra
write(output_unit, '(A,4F8.1)') 'picker D rect ', rd
write(output_unit, '(A,3F7.3)') 'after the white click ', seen(:, 1)
write(output_unit, '(A,3F7.3)') 'after the black click ', seen(:, 2)
write(output_unit, '(A,3F7.3)') 'after the hue corner  ', seen(:, 3)
write(output_unit, '(A,3F7.3)') 'after the hue bar     ', seen(:, 4)
write(output_unit, '(A,4F7.3)') 'B after the alpha bar ', rgba
write(output_unit, '(A,3F7.3)') 'C after the ring      ', wheel
write(output_unit, '(A,4I4,I4)') 'changes, idle ', changes, idle_changes
write(output_unit, '(A,*(L2))') 'figure_test_picker checks:', ok
if (.not. all(ok)) error stop 'figure_test_picker: FAILED'
write(output_unit, '(A)') 'figure_test_picker: all checks passed'

contains
   subroutine picker_window(name, x, y, which)
   !< One picker in a window of its own at (x, y), its rectangle and changes recorded.
   character(len=*), intent(in) :: name  !< Window name.
   real(real64),     intent(in) :: x, y  !< Window position [pixels].
   integer(int32),   intent(in) :: which !< 1 A, 2 B, 3 C, 4 D.
   logical                      :: changed !< The picker changed its colour this frame.
   integer(int32)               :: s       !< Status.

   call ig_set_next_window(x, y, 290.0_real64, 390.0_real64, always=.true.)
   if (ig_begin(name)) then
      call ig_push_item_width(WIDTH)
      select case (which)
      case (1_int32)
         changed = ig_color_picker('##rgb', rgb, stat=s)
         call ig_item_rect(ra(1), ra(2), ra(3), ra(4))
      case (2_int32)
         changed = ig_color_picker('##rgba', rgba, stat=s)
         call ig_item_rect(rb(1), rb(2), rb(3), rb(4))
      case (3_int32)
         changed = ig_color_picker('##wheel', wheel, wheel=.true., stat=s)
         call ig_item_rect(rc(1), rc(2), rc(3), rc(4))
      case default
         changed = ig_color_picker('##plain', plain, inputs=.false., stat=s)
         call ig_item_rect(rd(1), rd(2), rd(3), rd(4))
         if (ig_color_picker('##bad', bad, stat=st_bad)) continue
         if (st_bad /= FIG_OK) msg_bad = figure_last_error()
      endselect
      call ig_pop_item_width()
      if (changed) then
         changes(which) = changes(which) + 1_int32
         if (f < 10_int32 .or. f > 70_int32) idle_changes = idle_changes + 1_int32 ! before the clicks, or after
      endif
   endif
   call ig_end()
   endsubroutine picker_window
endprogram figure_test_picker
