!< figure_test_popups, popups, modals and the confirmation before quitting, driven by synthetic input, headless.
program figure_test_popups
!< figure_test_popups, popups, modals and the confirmation before quitting, driven by synthetic input, headless.
!<
!< A popup opened by a button and closed by a click outside it; with set_confirm_quit, a quit request reported once,
!< answered by a modal: Cancel keeps the program running (and the modal blocks the rest of the interface), Discard ends
!< it through app%quit; without set_confirm_quit, a quit request ends next_frame at once. File dialogs without a window
!< are refused; polling an id with no dialog reports nothing yet. The window's title set after init is read back.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : FIG_ERR_STATE, app_object, ig_begin, ig_begin_popup, ig_begin_popup_modal, &
                   ig_button, ig_checkbox,                                                                  &
                   ig_close_current_popup, ig_end, ig_end_popup, ig_open_popup, ig_set_next_window, ig_text
use figure_testing, only : test_click, test_item_center, test_quit

implicit none
integer(int32), parameter :: MAX_FRAMES = 300_int32 !< Guard: the loop must end before this.
type(app_object)          :: app                    !< Application.
logical                   :: test_passed(13)        !< Per-check outcome.
real(real64)              :: options_at(2)          !< Centre of the button that opens the popup.
real(real64)              :: cancel_at(2)           !< Centre of the modal's Cancel.
real(real64)              :: discard_at(2)          !< Centre of the modal's Discard.
logical                   :: flag                   !< A check box in the popup.
logical                   :: popup_seen             !< The popup was open on some frame.
logical                   :: popup_open             !< ... on the last frame.
logical                   :: modal_open             !< The modal is open on this frame.
integer(int32)            :: requests               !< Frames on which quit_requested was true.
integer(int32)            :: options_presses        !< Presses of the Options button.
integer(int32)            :: presses_in_modal       !< ... while the modal was open.
integer(int32)            :: frame                  !< Frame counter.
integer(int32)            :: last_frame             !< Frame on which the loop ended.
integer(int32)            :: modal_frames           !< Frames with the modal open.
logical                   :: alive_after_cancel     !< The loop ran past the Cancel.
logical                   :: ended_plain            !< Without confirmation, a quit request ends next_frame.
integer(int32)            :: stat_dialog(2)         !< File dialogs headless: open refused, unknown id.
character(len=:), allocatable :: chosen             !< Path from a dialog.
logical                   :: dialog_done            !< A dialog answered.
character(len=:), allocatable :: titles(:)          !< The title: before set_title, after it.
integer(int32)            :: stat_title             !< Status of set_title.

flag = .false.
popup_seen = .false.
popup_open = .false.
requests = 0_int32
options_presses = 0_int32
presses_in_modal = 0_int32
modal_frames = 0_int32
alive_after_cancel = .false.
frame = 0_int32
call app%init_headless(800_int32, 600_int32)
call app%set_confirm_quit(.true.)
do while (app%next_frame())
   frame = frame + 1_int32
   if (frame > MAX_FRAMES) exit
   call ig_set_next_window(20.0_real64, 20.0_real64, 500.0_real64, 400.0_real64, always=.true.)
   if (ig_begin('Editor')) then
      if (ig_button('Options')) then
         options_presses = options_presses + 1_int32
         if (modal_frames > 0_int32 .and. modal_open) presses_in_modal = presses_in_modal + 1_int32
         call ig_open_popup('options')
      endif
      call test_item_center(options_at(1), options_at(2))
      popup_open = .false.
      if (ig_begin_popup('options')) then
         popup_open = .true.
         popup_seen = .true.
         if (ig_checkbox('verbose', flag)) continue
         call ig_end_popup()
      endif
      if (app%quit_requested()) then              ! the close button: ask first
         requests = requests + 1_int32
         call ig_open_popup('Discard changes?')
      endif
      modal_open = .false.
      if (ig_begin_popup_modal('Discard changes?')) then
         modal_open = .true.
         modal_frames = modal_frames + 1_int32
         call ig_text('The input file has unsaved changes.')
         if (ig_button('Cancel')) call ig_close_current_popup()
         call test_item_center(cancel_at(1), cancel_at(2))
         if (ig_button('Discard')) call app%quit()
         call test_item_center(discard_at(1), discard_at(2))
         call ig_end_popup()
      endif
   endif
   call ig_end()
   select case (frame)
   case (3_int32)
      call test_click(options_at(1), options_at(2))   ! open the popup
   case (12_int32)
      call test_click(700.0_real64, 500.0_real64)     ! click outside it: it closes
   case (22_int32)
      call test_quit()                                ! the close button: a request, then the modal
   case (30_int32)
      call test_click(options_at(1), options_at(2))   ! behind the modal: ignored
   case (40_int32)
      call test_click(cancel_at(1), cancel_at(2))     ! Cancel: the program goes on
   case (55_int32)
      alive_after_cancel = .not. modal_open
      call test_quit()                                ! again, and this time Discard
   case (65_int32)
      call test_click(discard_at(1), discard_at(2))
   endselect
enddo
last_frame = frame
call app%destroy()

call app%init_headless(800_int32, 600_int32)          ! without confirmation: a request ends the loop at once
ended_plain = .false.
do frame = 1_int32, 20_int32
   if (.not. app%next_frame()) then
      ended_plain = frame == 4_int32
      exit
   endif
   if (frame == 3_int32) call test_quit()
enddo
call app%destroy()

call app%init_headless(800_int32, 600_int32)          ! file dialogs need a window
call app%open_file_dialog('open', ['Input files|input;inp'], stat=stat_dialog(1))
call app%file_dialog_result('never opened', chosen, dialog_done, stat=stat_dialog(2))
allocate(character(len=32) :: titles(2))
titles(1) = app%title()                               ! headless: no title given
call app%set_title('* case/overset.input', stat=stat_title)
titles(2) = app%title()
call app%destroy()

test_passed(1) = popup_seen                                  ! a popup opened by a button
test_passed(2) = .not. popup_open                            ! ... closed by a click outside it
test_passed(3) = requests == 2_int32                         ! two requests, each reported once
test_passed(4) = presses_in_modal == 0_int32 .and. options_presses == 1_int32 ! the modal blocks the rest
test_passed(5) = alive_after_cancel                          ! Cancel: the modal closed, the program runs
test_passed(6) = last_frame > 65_int32 .and. last_frame < 80_int32 ! Discard: app%quit ended the loop
test_passed(7) = modal_frames > 0_int32                      ! the modal was shown
test_passed(8) = ended_plain                                 ! no confirmation: a request ends next_frame
test_passed(9) = last_frame <= MAX_FRAMES                    ! the loop did end
test_passed(10) = stat_dialog(1) == int(FIG_ERR_STATE, int32)  ! no file dialog without a window
test_passed(11) = stat_dialog(2) == 0_int32 .and. .not. dialog_done .and. chosen == '' ! no dialog: nothing yet
test_passed(12) = len_trim(titles(1)) == 0                   ! no title before set_title (headless)
test_passed(13) = stat_title == 0_int32 .and. titles(2) == '* case/overset.input' ! set_title kept, read back

write(output_unit, '(A,*(L2))') 'figure_test_popups checks:', test_passed
if (.not. all(test_passed)) write(output_unit, '(A,I0,A,I0,A,I0,A,I0,A,I0)') 'requests ', requests, &
   ', options presses ', options_presses, ', in modal ', presses_in_modal, ', last frame ', last_frame, &
   ', modal frames ', modal_frames
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1
endprogram figure_test_popups
