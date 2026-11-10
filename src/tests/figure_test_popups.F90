!< figure_test_popups, popups, modals and the confirmation before quitting, driven by synthetic input, headless.
program figure_test_popups
!< figure_test_popups, popups, modals and the confirmation before quitting, driven by synthetic input, headless.
!<
!< A popup opened by a button and closed by a click outside it; with set_confirm_quit, a quit request reported once,
!< answered by a modal: Cancel keeps the program running (and the modal blocks the rest of the interface), Discard ends
!< it through app%quit; without set_confirm_quit, a quit request ends next_frame at once. File dialogs without a window
!< are refused; polling an id with no dialog reports nothing yet. The window's title set after init is read back.
!< Context menus: a right click on a row opens that row's menu, a pick of its entry closes it; on the window's empty
!< space the 'window' menu (not over a row: rows keep theirs), on the background the 'void' menu; a click outside closes
!< a menu. A link's click returns true once; a URL link asks for its URL (read headless by test_opened_url). A tooltip
!< on an item appears after the hover delay, not at once; a tooltip begun anywhere shows its content. No frame has a
!< usage error; an unknown place or button is refused.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : FIG_ERR_ARGUMENT, FIG_ERR_STATE, FIG_OK, app_object, figure_last_error, ig_begin, ig_begin_popup,   &
                   ig_begin_popup_modal, ig_button, ig_checkbox, ig_close_current_popup, ig_end, ig_end_popup,      &
                   ig_open_popup, ig_set_next_window, ig_text, ig_begin_item_tooltip, ig_begin_popup_context,      &
                   ig_begin_tooltip, ig_end_tooltip, ig_item_rect, ig_menu_item, ig_pop_id, ig_push_id,            &
                   ig_selectable, ig_text_disabled, ig_text_link, ig_text_link_url
use figure_testing, only : test_click, test_item_center, test_mouse_move, test_opened_url, test_popup_rect, test_quit

implicit none
integer(int32), parameter :: MAX_FRAMES = 300_int32 !< Guard: the loop must end before this.
type(app_object)          :: app                    !< Application.
logical                   :: test_passed(26)        !< Per-check outcome.
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
modal_open = .false.
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
call context_menus(test_passed(14:26))

write(output_unit, '(A,*(L2))') 'figure_test_popups checks:', test_passed
if (.not. all(test_passed)) write(output_unit, '(A,I0,A,I0,A,I0,A,I0,A,I0)') 'requests ', requests, &
   ', options presses ', options_presses, ', in modal ', presses_in_modal, ', last frame ', last_frame, &
   ', modal frames ', modal_frames
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1
contains
   subroutine context_menus(ok)
   !< Context menus, links and tooltips, driven by synthetic input on a fresh headless application.
   logical, intent(out)          :: ok(13)        !< The checks.
   integer(int32), parameter     :: ROWS = 3_int32 !< Rows of the list.
   real(real64)                  :: row_at(2, ROWS) !< Centre of each row.
   real(real64)                  :: entry_at(2)   !< Centre of the open menu's entry.
   real(real64)                  :: details_at(2) !< Centre of the link.
   real(real64)                  :: docs_at(2)    !< Centre of the URL link.
   real(real64)                  :: help_at(2)    !< Centre of the button with a tooltip.
   real(real64)                  :: r(4)          !< A popup's rectangle.
   real(real64)                  :: tip(4)        !< The rectangle of the text in a tooltip.
   logical                       :: found         !< A popup is open.
   integer(int32)                :: f             !< Frame.
   integer(int32)                :: i             !< Row.
   integer(int32)                :: s             !< Status of a frame.
   integer(int32)                :: errors        !< Frames with a usage error.
   integer(int32)                :: menu_row      !< The row whose menu is open (0: none).
   integer(int32)                :: deleted       !< The row deleted from its menu.
   integer(int32)                :: added         !< Rows added from the window's menu.
   integer(int32)                :: created       !< Windows created from the background's menu.
   integer(int32)                :: links         !< Clicks on the link.
   integer(int32)                :: tip_first     !< The first frame the item's tooltip showed.
   integer(int32)                :: stat_on       !< Status of an unknown place.
   integer(int32)                :: stat_button   !< Status of an unknown button.
   logical                       :: space_open    !< The window's menu is open.
   logical                       :: void_open     !< The background's menu is open.
   logical                       :: shown         !< ig_begin_tooltip returned true.
   logical                       :: rows_seen(4)  !< Checks along the way.
   character(len=:), allocatable :: url_before    !< test_opened_url before the click.
   character(len=:), allocatable :: msg_on        !< Message of an unknown place.

   ok = .false.
   rows_seen = .false.
   errors = 0_int32
   deleted = 0_int32
   added = 0_int32
   created = 0_int32
   links = 0_int32
   tip_first = 0_int32
   shown = .false.
   tip = 0.0_real64
   entry_at = 0.0_real64
   call app%init_headless(800_int32, 600_int32)
   url_before = test_opened_url()
   do f = 1_int32, 150_int32
      if (.not. app%next_frame(s)) exit
      if (s /= FIG_OK) errors = errors + 1_int32
      menu_row = 0_int32
      space_open = .false.
      void_open = .false.
      call ig_set_next_window(20.0_real64, 20.0_real64, 400.0_real64, 300.0_real64, always=.true.)
      if (ig_begin('Rows')) then
         do i = 1_int32, ROWS
            call ig_push_id(i)
            if (ig_selectable('row', .false.)) continue
            call test_item_center(row_at(1, i), row_at(2, i))
            if (ig_begin_popup_context('row')) then                 ! on the row just drawn
               menu_row = i
               call ig_text_disabled('a row')
               if (ig_menu_item('Delete')) deleted = i
               call test_item_center(entry_at(1), entry_at(2))
               call ig_end_popup()
            endif
            call ig_pop_id()
         enddo
         if (ig_text_link('details')) links = links + 1_int32
         call test_item_center(details_at(1), details_at(2))
         call ig_text_link_url('docs', 'https://example.org/figure')
         call test_item_center(docs_at(1), docs_at(2))
         if (ig_button('help')) continue
         call test_item_center(help_at(1), help_at(2))
         if (ig_begin_item_tooltip()) then
            if (tip_first == 0_int32) tip_first = f
            call ig_text('opens the help')
            call ig_end_tooltip()
         endif
         if (ig_begin_popup_context('space', on='window')) then    ! the window's empty space
            space_open = .true.
            if (ig_menu_item('Add row')) added = added + 1_int32
            call test_item_center(entry_at(1), entry_at(2))
            call ig_end_popup()
         endif
      endif
      call ig_end()
      if (ig_begin_popup_context('background', on='void')) then     ! where no window is
         void_open = .true.
         if (ig_menu_item('New window')) created = created + 1_int32
         call test_item_center(entry_at(1), entry_at(2))
         call ig_end_popup()
      endif
      if (f == 140_int32) then                                      ! a tooltip begun anywhere
         shown = ig_begin_tooltip()
         if (shown) then
            call ig_text('anywhere')
            call ig_item_rect(tip(1), tip(2), tip(3), tip(4))
            call ig_end_tooltip()
         endif
      endif
      call test_popup_rect(r(1), r(2), r(3), r(4), found)
      select case (f)
      case (5_int32)
         call test_click(row_at(1, 2), row_at(2, 2), button='right') ! row 2's menu
      case (12_int32)
         ok(1) = found .and. r(3) > r(1) .and. r(4) > r(2) .and. menu_row == 2_int32 .and. .not. space_open
         call test_click(entry_at(1), entry_at(2))                  ! its Delete
      case (20_int32)
         ok(2) = deleted == 2_int32 .and. .not. found .and. menu_row == 0_int32
         call test_click(200.0_real64, 280.0_real64, button='right') ! the window's empty space
      case (28_int32)
         ok(3) = found .and. space_open .and. menu_row == 0_int32
         call test_click(entry_at(1), entry_at(2))                  ! Add row
      case (36_int32)
         ok(4) = added == 1_int32 .and. .not. found .and. .not. space_open
         call test_click(row_at(1, 1), row_at(2, 1), button='right') ! over a row: its menu, not the window's
      case (44_int32)
         ok(5) = found .and. menu_row == 1_int32 .and. .not. space_open
         call test_click(700.0_real64, 500.0_real64)                ! a click outside closes it
      case (52_int32)
         ok(6) = .not. found .and. menu_row == 0_int32 .and. deleted == 2_int32
         call test_click(700.0_real64, 500.0_real64, button='right') ! the background
      case (60_int32)
         rows_seen(1) = found .and. void_open .and. .not. space_open .and. menu_row == 0_int32
         call test_click(entry_at(1), entry_at(2))                  ! New window
      case (68_int32)
         ok(7) = rows_seen(1) .and. created == 1_int32 .and. .not. found
         call test_click(details_at(1), details_at(2))              ! the link
      case (76_int32)
         rows_seen(2) = links == 1_int32
         call test_click(docs_at(1), docs_at(2))                    ! the URL link
      case (84_int32)
         ok(8) = rows_seen(2) .and. links == 1_int32
         ok(9) = url_before == '' .and. test_opened_url() == 'https://example.org/figure'
         call test_mouse_move(help_at(1), help_at(2))               ! rest on the button
      case (86_int32)
         rows_seen(3) = tip_first == 0_int32                        ! not at once
      endselect
   enddo
   if (app%next_frame(s)) continue
   if (s /= FIG_OK) errors = errors + 1_int32
   if (ig_begin_popup_context('x', on='row', stat=stat_on)) continue
   msg_on = figure_last_error()
   if (ig_begin_popup_context('x', button='back', stat=stat_button)) continue
   ok(13) = stat_on == int(FIG_ERR_ARGUMENT, int32) .and. stat_button == int(FIG_ERR_ARGUMENT, int32) .and.        &
            msg_on == 'ig_begin_popup_context: unknown place "row" (''item'', ''window'' or ''void'')' .and.          &
            figure_last_error() == 'ig_begin_popup_context: unknown button "back" (''right'', ''left'' or ''middle'')'
   if (app%next_frame(s)) continue
   if (s /= FIG_OK) errors = errors + 1_int32
   call app%destroy()
   ok(10) = rows_seen(3) .and. tip_first > 90_int32 .and. tip_first < 120_int32 ! after the delay (0.3 s: 18 frames)
   ok(11) = shown .and. tip(3) > tip(1) .and. tip(4) > tip(2)
   ok(12) = errors == 0_int32
   if (.not. all(ok)) write(output_unit, '(A,13L2,A,I0,A,I0,A,I0)') 'context menus:', ok, '; tooltip at frame ', &
                                                                   tip_first, ', usage errors ', errors, ', links ', links
   endsubroutine context_menus
endprogram figure_test_popups
