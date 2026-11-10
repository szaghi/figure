!< cb_shortcut_always, cookbook: one key that every panel acts on (an unrouted shortcut, scope 'always').
program cb_shortcut_always
!< cb_shortcut_always, cookbook: one key that every panel acts on (an unrouted shortcut, scope 'always').
!<
!< Two panels both act on ctrl+p (cmd+p on macOS): the Run panel pauses the run, the Plot panel freezes its curve.
!< With scope 'always' both calls fire, wherever the focus is, a text field being edited included; with 'global' only
!< the first call of the frame would fire. `cb_shortcut_always --check` opens no window: it presses ctrl+p while the
!< note field is edited, then f12 (bound with 'global' in both panels), and prints what each panel did.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, ig_begin, ig_end, ig_input_text, ig_set_next_window, ig_shortcut, ig_text
use figure_testing, only : test_click, test_item_center, test_key

implicit none
type(app_object)  :: app        !< Application.
character(len=32) :: note       !< The Run panel's note field.
logical           :: paused     !< The run is paused.
logical           :: frozen     !< The plot is frozen.
character(len=16) :: arg        !< First argument.
logical           :: check      !< --check: headless, scripted keys.
real(real64)      :: note_at(2) !< Centre of the note field.
integer(int32)    :: frame      !< Frame counter.
!run cb_shortcut_always ./cb_shortcut_always --check

note = ''
paused = .false.
frozen = .false.
call get_command_argument(1, arg)
check = trim(arg) == '--check'
if (check) then
   call app%init_headless(640_int32, 240_int32)
else
   call app%init('FIGURE: one key for every panel', 640_int32, 240_int32)
endif
frame = 0_int32
do while (app%next_frame())
   frame = frame + 1_int32
   call ig_set_next_window(10.0_real64, 10.0_real64, 300.0_real64, 220.0_real64)
   if (ig_begin('Run')) then
      call ig_text(merge('paused ', 'running', paused))
      if (ig_input_text('note', note)) continue
      call test_item_center(note_at(1), note_at(2))
      !region always
      if (ig_shortcut('ctrl+p', scope='always')) then ! fires here and in Plot, a text field edited or not
         paused = .not. paused
         call did('Run: '//merge('paused ', 'resumed', paused))
      endif
      !endregion always
      if (ig_shortcut('f12', scope='global')) call did('Run: f12')
   endif
   call ig_end()
   call ig_set_next_window(330.0_real64, 10.0_real64, 300.0_real64, 220.0_real64)
   if (ig_begin('Plot')) then
      call ig_text(merge('frozen', 'live  ', frozen))
      if (ig_shortcut('ctrl+p', scope='always')) then
         frozen = .not. frozen
         call did('Plot: '//merge('frozen', 'live  ', frozen))
      endif
      if (ig_shortcut('f12', scope='global')) call did('Plot: f12') ! 'global': the first call of the frame only
   endif
   call ig_end()
   if (check) then
      call press(frame)
      if (frame == 30_int32) exit
   endif
enddo
call app%destroy()

contains
   subroutine did(what)
   !< Print what a key did, in --check.
   character(len=*), intent(in) :: what !< What happened.

   if (check) write(output_unit, '(A,I0,A)') 'frame ', frame, ': '//trim(what)
   endsubroutine did

   subroutine press(f)
   !< The keys of --check, by frame.
   integer(int32), intent(in) :: f !< Frame.

   select case (f)
   case (5_int32)                       ! edit the note field
      call test_click(note_at(1), note_at(2))
   case (10_int32)                      ! ctrl+p (cmd+p on macOS) while the field is edited
      call test_key('shortcut', down=.true.)
      call test_key('p')
      call test_key('shortcut', down=.false.)
   case (16_int32)
      call test_key('escape')
   case (20_int32)                      ! f12, bound with 'global' in both panels
      call test_key('f12')
   endselect
   endsubroutine press
endprogram cb_shortcut_always
