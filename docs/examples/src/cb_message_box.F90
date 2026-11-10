!< cb_message_box, reference example: a question asked in a box when the user quits, a message after one answer and
!< the question again; the answers polled frame by frame; checked headless by clicking the buttons by their paths.
program cb_message_box
!< cb_message_box, reference example: a question asked in a box when the user quits, a message after one answer and
!< the question again; the answers polled frame by frame; checked headless by clicking the buttons by their paths.
use, intrinsic :: iso_fortran_env, only : int32, output_unit
use figure, only : app_object, ig_begin, ig_button, ig_end
use figure_testing, only : test_item_click, test_quit, test_run

implicit none
type(app_object) :: app              !< Application.
logical          :: asking = .false. !< The quit question is open.
logical          :: saving = .false. !< The save question is open.
integer(int32)   :: answer           !< A box's answer.
!run cb_message_box ./cb_message_box

call app%init_headless(800_int32, 500_int32)
call app%set_confirm_quit(.true.)                          ! the close button asks first
call test_quit()                                           ! the user closes the window
call draw(30_int32)
call test_item_click('Quit?/Save first')                   ! the case saved, a message box
call draw(30_int32)
call test_item_click('Saving/OK')
call draw(30_int32)
call test_item_click('Quit?/Quit')
call draw(30_int32)
call app%destroy()

contains
   subroutine draw(frames)
   !< Draw until idle, at most `frames` frames.
   integer(int32), intent(in) :: frames !< Frames allowed.

   call app%request_frames(3_int32)
   do while (test_run(frames))
      if (.not. app%next_frame()) return
      call frame()
   enddo
   endsubroutine draw

   subroutine frame()
   !< One frame of the interface.
   if (ig_begin('Case')) then
      if (ig_button('Quit')) asking = .true.
   endif
   call ig_end()
   !region ask
   if (app%quit_requested()) asking = .true.
   if (asking) then                                         ! every frame until answered
      answer = app%message_box('quit', 'Quit?', 'The case has unsaved changes.', &
                               [character(len=10) :: 'Quit', 'Save first', 'Cancel'])
      select case (answer)
      case (0)                                              ! still open
      case (1)
         write(output_unit, '(A)') 'quit'
         asking = .false.
         call app%quit()
      case (2)
         write(output_unit, '(A)') 'save first'
         asking = .false.
         saving = .true.                                    ! a message, then the question again
      case default
         write(output_unit, '(A)') 'cancelled'
         asking = .false.
      endselect
   endif
   !endregion ask
   if (saving) then
      if (app%message_box('saved', 'Saving', 'case.inp saved.') /= 0) then ! one button, 'OK'
         write(output_unit, '(A)') 'saved: OK'
         saving = .false.
         asking = .true.                                    ! ask again
      endif
   endif
   endsubroutine frame
endprogram cb_message_box
