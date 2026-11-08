!< figure_test_tools, a workspace button, a list clipper, text level with fields, focusing a window, headless.
program figure_test_tools
!< figure_test_tools, a workspace button, a list clipper, text level with fields, focusing a window, headless.
!<
!< Two workspace buttons (`ig_tool_button`), the first selected: their default size (room for the icon above the
!< label), a given size, a click on the second. A list of 100000 rows in a region 200 pixels high, clipped
!< (`list_clipper_object`): only the rows in view are drawn, from row 1, and the loop ends. A label before a button,
!< lowered to its text by `ig_align_text_to_frame_padding` (and not without it). Two overlapping windows: the one
!< behind brought forward by `ig_focus_window`; with a popup open, the request is refused and the popup stays open.
!< A text's size (`ig_text_size`): twice the text, twice the width; a label measured without its `##` part.
!< Progress bars (`ig_progress_bar`): the filled width at known fractions, an indeterminate band that moves.
!< Notifications (`app%notify`): shown in the bottom-right corner, the newest under the older, gone after their time
!< (the fixed frame time), dismissed by a click, the kept list (the last 100), an unknown kind refused; the fade: the
!< alpha of the draw data 1 until the last half second, then falling by a frame's share each frame, to about 0.
!< Drops (`app%dropped`, `test_drop`): two paths dropped at once reported together on the next frame, once, with the
!< point of the drop; nothing on the other frames. The clipboard (`ig_set_clipboard`, `ig_get_clipboard`): a text of
!< two lines set and read back, an empty one, and a field's copy (ctrl+a, ctrl+c) read by the program.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, ICON_ACTIVITY, ICON_HOUSE, ig_align_text_to_frame_padding, ig_begin, ig_begin_child, &
                   ig_begin_popup, ig_button, ig_end, ig_end_child, ig_end_popup, ig_focus_window, ig_item_rect, &
                   ig_open_popup, ig_same_line, ig_selectable, ig_set_next_window, ig_text, ig_tool_button, &
                   ig_text_size, list_clipper_object, ig_progress_bar, FIG_ERR_ARGUMENT, FIG_OK, ig_get_style_var, &
                   ig_get_clipboard, ig_input_text, ig_set_clipboard
use figure_cimgui, only : igIsWindowFocused
use figure_testing, only : test_click, test_drawn_extent, test_drop, test_item_center, test_key, test_notification_rect

implicit none
integer(int32), parameter :: MAX_FRAMES = 60_int32 !< Frames run.
type(app_object)          :: app                   !< Application (headless).
type(list_clipper_object) :: clip                  !< Clipper.
logical                   :: test_passed(22)       !< Per-check outcome.
real(real64)              :: size1(2), size2(2), size3(2) !< Text sizes.
integer(int32)            :: frame, i, shown       !< Frame, row, the tool shown.
integer(int32)            :: clicks(2)             !< Clicks per tool button.
integer(int32)            :: drawn, steps, first_drawn !< Rows drawn, clipper steps, the first row drawn.
real(real64)              :: r(4), a(4), b(4)      !< Rectangles.
real(real64)              :: tool_rect(4, 3)       !< The tool buttons: default (2), given size.
real(real64)              :: aligned_dy, plain_dy  !< Label below the button's top: aligned, not.
logical                   :: w1_focused, popup_up, refused, accepted !< Focus and popup states.

test_passed = .false.
clicks = 0_int32
shown = 1_int32
w1_focused = .false.
popup_up = .false.
refused = .false.
accepted = .false.
call app%init_headless(900_int32, 700_int32)
frame = 0_int32
do while (app%next_frame())
   frame = frame + 1_int32
   if (frame > MAX_FRAMES) exit
   call ig_set_next_window(10.0_real64, 10.0_real64, 400.0_real64, 650.0_real64, always=.true.)
   if (ig_begin('Tools')) then
      if (ig_tool_button('Input##t1', ICON_HOUSE, selected=shown == 1_int32)) then
         shown = 1_int32
         clicks(1) = clicks(1) + 1_int32
      endif
      call ig_item_rect(tool_rect(1, 1), tool_rect(2, 1), tool_rect(3, 1), tool_rect(4, 1))
      call ig_same_line()
      if (ig_tool_button('Monitor##t2', ICON_ACTIVITY, selected=shown == 2_int32, accent=[0.85_real64, 0.3_real64, &
                         0.22_real64])) then
         shown = 2_int32
         clicks(2) = clicks(2) + 1_int32
      endif
      call ig_item_rect(tool_rect(1, 2), tool_rect(2, 2), tool_rect(3, 2), tool_rect(4, 2))
      if (ig_tool_button('Sized', ICON_HOUSE, width=90.0_real64, height=70.0_real64)) continue
      call ig_item_rect(tool_rect(1, 3), tool_rect(2, 3), tool_rect(3, 3), tool_rect(4, 3))
      size1 = ig_text_size('abc')
      size2 = ig_text_size('abcabc')
      size3 = ig_text_size('abc##hidden')
      call ig_align_text_to_frame_padding()                     ! a label level with the button beside it
      call ig_text('label')
      call ig_item_rect(a(1), a(2), a(3), a(4))
      call ig_same_line()
      if (ig_button('field')) continue
      call ig_item_rect(b(1), b(2), b(3), b(4))
      aligned_dy = a(2) - b(2)
      call ig_text('plain')                                     ! the same without
      call ig_item_rect(a(1), a(2), a(3), a(4))
      call ig_same_line()
      if (ig_button('field2')) continue
      call ig_item_rect(b(1), b(2), b(3), b(4))
      plain_dy = a(2) - b(2)
      drawn = 0_int32
      steps = 0_int32
      first_drawn = 0_int32
      if (ig_begin_child('list', height=200.0_real64)) then
         call clip%begin(100000_int32)
         do while (clip%step())
            steps = steps + 1_int32
            if (steps > 10_int32) exit                          ! guard: a clipper takes a few steps
            if (first_drawn == 0_int32) first_drawn = clip%first
            do i = clip%first, clip%last
               if (ig_selectable('row '//itoa(i), .false.)) continue
               drawn = drawn + 1_int32
            enddo
         enddo
      endif
      call ig_end_child()
   endif
   call ig_end()
   ! two windows, overlapping: W2 drawn last is in front; W1 brought forward on frame 20; a popup in W2 from frame 30
   call ig_set_next_window(450.0_real64, 10.0_real64, 300.0_real64, 200.0_real64)
   if (ig_begin('W1')) call ig_text('one')
   w1_focused = igIsWindowFocused(0_int32)
   call ig_end()
   call ig_set_next_window(470.0_real64, 30.0_real64, 300.0_real64, 200.0_real64)
   if (ig_begin('W2')) then
      call ig_text('two')
      if (frame == 30_int32) call ig_open_popup('pop')
      popup_up = .false.
      if (ig_begin_popup('pop')) then
         popup_up = .true.
         call ig_text('a popup')
         call ig_end_popup()
      endif
   endif
   call ig_end()
   if (frame == 15_int32) test_passed(7) = .not. w1_focused             ! W2, in front, has the focus
   if (frame == 20_int32) accepted = ig_focus_window('W1')
   if (frame == 25_int32) test_passed(7) = test_passed(7) .and. accepted .and. w1_focused
   if (frame == 34_int32) refused = .not. ig_focus_window('W2')
   if (frame == 38_int32) test_passed(8) = refused .and. popup_up
   if (frame == 5_int32) call test_click(0.5_real64 * (tool_rect(1, 2) + tool_rect(3, 2)), &
                                         0.5_real64 * (tool_rect(2, 2) + tool_rect(4, 2)))
enddo

r = tool_rect(:, 1)
test_passed(1) = r(3) - r(1) >= 4.6_real64 * 13.0_real64 .and. r(4) - r(2) > 3.0_real64 * 13.0_real64 ! default size
test_passed(2) = abs(tool_rect(3, 3) - tool_rect(1, 3) - 90.0_real64) < 0.5_real64 .and. &
                 abs(tool_rect(4, 3) - tool_rect(2, 3) - 70.0_real64) < 0.5_real64              ! given size
test_passed(3) = clicks(2) == 1_int32 .and. clicks(1) == 0_int32 .and. shown == 2_int32       ! the second clicked
test_passed(4) = first_drawn == 1_int32 .and. drawn > 0_int32 .and. drawn < 40_int32          ! rows in view only
test_passed(5) = steps <= 10_int32                                                              ! the loop ended
test_passed(6) = aligned_dy > 0.5_real64 .and. abs(plain_dy) < 0.5_real64                      ! level with the field
test_passed(9) = size1(1) > 0.0_real64 .and. abs(size2(1) - 2.0_real64 * size1(1)) < 1.0_real64 .and. &
                 size1(2) > 0.0_real64 .and. abs(size3(1) - size1(1)) < 1.0e-6_real64    ! a text's size, a label's
if (.not. all(test_passed)) then
   write(output_unit, '(A,4F8.1)') 'tool button: ', tool_rect(:, 1)
   write(output_unit, '(A,4I8)') 'clicks, shown, drawn: ', clicks, shown, drawn
   write(output_unit, '(A,2I8)') 'first drawn, steps: ', first_drawn, steps
   write(output_unit, '(A,2F8.2)') 'dy aligned, plain: ', aligned_dy, plain_dy
endif
call progress_bars(test_passed(10:11))
call notifications(test_passed(12:16))
call drops_and_clipboard(test_passed(17:21))
call notification_fade(test_passed(22))
write(output_unit, '(A,*(L2))') 'figure_test_tools checks:', test_passed
do i = 1_int32, size(test_passed, kind=int32)
   if (.not. test_passed(i)) write(output_unit, '(A,I0,A)') 'figure_test_tools: check ', i, ' FAILED'
enddo
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
call app%destroy()
if (.not. all(test_passed)) error stop 1

contains
   subroutine notification_fade(ok)
   !< A notification of 1 s, its alpha read from the draw data every frame (frames of 1/60 s): 1 while it is shown in
   !< full, then falling by 1/30 a frame (a frame over the fade's half second) for the last 30 frames, to below 0.05;
   !< then it is gone (the notifications kept shown by the check before, until dismissed, then come first: an alpha
   !< rising again ends the samples).
   logical, intent(out) :: ok          !< Outcome.
   real(real64)         :: alpha(90)   !< The alpha, per frame (-1: not shown).
   real(real64)         :: r(4)        !< Its rectangle.
   logical              :: found       !< Shown.
   logical              :: gone        !< Another notification is the newest shown.
   integer(int32)       :: fr          !< Frame.
   integer(int32)       :: full        !< Frames shown in full.
   integer(int32)       :: fading      !< Frames fading.
   integer(int32)       :: last        !< The last frame shown.

   alpha = -1.0_real64
   gone = .false.
   call app%notify('fading out', seconds=1.0_real64)
   do fr = 1_int32, size(alpha, kind=int32)
      if (.not. app%next_frame()) exit
      call test_notification_rect(1_int32, r(1), r(2), r(3), r(4), found, alpha=alpha(fr))
      if (fr > 1_int32) gone = gone .or. alpha(fr) > alpha(fr - 1_int32) + 0.01_real64
      if (.not. found .or. gone) alpha(fr) = -1.0_real64
   enddo
   full = count(alpha >= 254.0_real64 / 255.0_real64)
   fading = count(alpha >= 0.0_real64 .and. alpha < 254.0_real64 / 255.0_real64)
   last = 0_int32
   do fr = 1_int32, size(alpha, kind=int32)
      if (alpha(fr) >= 0.0_real64) last = fr
   enddo
   ok = full >= 25_int32 .and. fading >= 28_int32 .and. fading <= 31_int32 .and. last == full + fading
   if (ok) ok = all(alpha(1:full) >= 254.0_real64 / 255.0_real64) .and. alpha(last) < 0.05_real64 .and. &
                all(abs(alpha(full + 1:last) - alpha(full:last - 1) + 1.0_real64 / 30.0_real64) < 0.01_real64)
   if (.not. ok) write(output_unit, '(A,2(I0,1X),A,90F6.3)') 'notification fade: full, fading ', full, fading, &
                                                             ', alpha ', alpha
   endsubroutine notification_fade

   subroutine drops_and_clipboard(ok)
   !< A drop of two paths (one with a space and a non-ASCII letter) at (123, 45): reported on the next frame only, the
   !< paths in order, at that point; no drop before it. The clipboard: two lines set and read back, then an empty one;
   !< a field's text selected and copied (ctrl+a, ctrl+c) read back by the program; a drop of nothing refused.
   logical, intent(out)          :: ok(5)        !< Outcomes.
   character(len=*), parameter   :: SECOND = '/tmp/case '//char(195)//char(169)//'/run.log' !< "case é".
   character(len=*), parameter   :: TWO_LINES = 'p = 1.5e5'//char(10)//'T = 300' !< A text of two lines.
   character(len=:), allocatable :: paths(:)     !< Paths dropped.
   character(len=:), allocatable :: back         !< The clipboard read back.
   character(len=:), allocatable :: empty        !< ... after an empty text.
   character(len=:), allocatable :: copied       !< ... after the field's copy.
   character(len=32)             :: field        !< A field's text.
   real(real64)                  :: x, y         !< Point of the drop.
   real(real64)                  :: field_at(2)  !< Centre of the field.
   integer(int32)                :: fr           !< Frame.
   integer(int32)                :: reported     !< Frames on which a drop was reported.
   integer(int32)                :: reported_at  !< The frame of the report.
   integer(int32)                :: stat         !< Status.
   logical                       :: early        !< A drop was reported before the drop.
   logical                       :: got_drop     !< The paths and the point matched.

   x = 0.0_real64
   y = 0.0_real64
   reported = 0_int32
   reported_at = 0_int32
   early = .false.
   got_drop = .false.
   field = 'mesh/grid'
   copied = ''
   call ig_set_clipboard(TWO_LINES)
   back = ig_get_clipboard()
   call ig_set_clipboard('')
   empty = ig_get_clipboard()
   do fr = 1_int32, 30_int32
      if (.not. app%next_frame()) exit
      call ig_set_next_window(10.0_real64, 10.0_real64, 300.0_real64, 100.0_real64, always=.true.)
      if (ig_begin('clipboard')) then
         if (ig_input_text('##field', field)) continue
         call test_item_center(field_at(1), field_at(2))
      endif
      call ig_end()
      if (app%dropped(paths, x, y)) then
         reported = reported + 1_int32
         reported_at = fr
         got_drop = size(paths) == 2 .and. x == 123.0_real64 .and. y == 45.0_real64
         if (got_drop) got_drop = paths(1) == '/tmp/case' .and. paths(2) == SECOND .and. len(paths) == len(SECOND)
      elseif (size(paths) /= 0) then
         early = .true.
      endif
      select case (fr)
      case (3_int32)
         if (reported /= 0_int32) early = .true.
         call test_drop([character(len=len(SECOND)) :: '/tmp/case', SECOND], 123.0_real64, 45.0_real64)
      case (8_int32)
         call test_click(field_at(1), field_at(2))
      case (14_int32)
         call test_key('shortcut', down=.true.)
         call test_key('a')
         call test_key('c')
         call test_key('shortcut', down=.false.)
      case (22_int32)
         copied = ig_get_clipboard()
      endselect
   enddo
   call test_drop([character(len=1) ::], 0.0_real64, 0.0_real64, stat=stat)
   ok(1) = got_drop .and. reported_at == 4_int32                 ! both paths, together, the frame after, at the point
   ok(2) = reported == 1_int32 .and. .not. early                 ! once, and nothing on the other frames
   ok(3) = back == TWO_LINES .and. empty == ''                   ! the clipboard set and read back
   ok(4) = copied == 'mesh/grid'                                 ! a field's copy read by the program
   ok(5) = stat == FIG_ERR_ARGUMENT                              ! a drop of nothing refused
   if (.not. all(ok)) write(output_unit, '(A,2I4,L2,2F8.1,A)') 'drops: reported, at, early, x, y ', reported, &
                                                              reported_at, early, x, y, &
                                                              ', clipboard "'//back//'" "'//copied//'"'
   endsubroutine drops_and_clipboard

   subroutine progress_bars(ok)
   !< Bars 400 pixels wide at 0, 0.25, 0.75 and 1: the fill (PlotHistogram) grows in proportion, empty at 0, full at 1
   !< (inside the frame's border); an indeterminate bar's band is narrower than the bar and moves between frames.
   logical, intent(out)  :: ok(2)       !< Outcomes.
   real(real64)          :: fill(4, 5)  !< (xmin, ymin, xmax, ymax) of each bar's fill; 5: indeterminate, frame 10.
   real(real64)          :: band0(4)    !< The indeterminate band at frame 5.
   real(real64)          :: bar(4)      !< The bar's rectangle.
   real(real64)          :: v(2)        !< FrameBorderSize.
   real(real64)          :: w(4)        !< Fill widths.
   real(real64), parameter :: F(4) = [0.0_real64, 0.25_real64, 0.75_real64, 1.0_real64] !< Fractions.
   logical               :: found(5)    !< Something filled.
   logical               :: found0      !< The band at frame 5.
   integer(int32)        :: k, fr, n    !< Bar, frame, values.

   found = .false.
   found0 = .false.
   do fr = 1_int32, 10_int32
      if (.not. app%next_frame()) exit
      do k = 1_int32, 5_int32
         call ig_set_next_window(10.0_real64, 10.0_real64 + 70.0_real64 * k, 460.0_real64, 60.0_real64, always=.true.)
         if (ig_begin('bar '//itoa(k))) then
            if (k <= 4_int32) then
               call ig_progress_bar(F(k), width=400.0_real64)
            else
               call ig_progress_bar(-1.0_real64, width=400.0_real64)
            endif
            if (k == 2_int32) call ig_item_rect(bar(1), bar(2), bar(3), bar(4))
            call test_drawn_extent('PlotHistogram', fill(1, k), fill(2, k), fill(3, k), fill(4, k), found(k))
            if (k == 5_int32 .and. fr == 5_int32) then
               band0 = fill(:, 5)
               found0 = found(5)
            endif
         endif
         call ig_end()
      enddo
   enddo
   call ig_get_style_var('FrameBorderSize', v, n)
   w = fill(3, 1:4) - fill(1, 1:4)
   ok(1) = .not. found(1) .and. all(found(2:4)) .and. abs(w(2) - 0.25_real64 * (400.0_real64 - 2.0_real64 * v(1))) &
           < 1.0_real64 .and. abs(w(3) - 3.0_real64 * w(2)) < 1.5_real64 .and.                                 &
           abs(fill(1, 4) - bar(1) - v(1)) < 0.5_real64 .and. abs(bar(3) - v(1) - fill(3, 4)) < 0.5_real64
   ok(2) = found0 .and. found(5) .and. fill(3, 5) - fill(1, 5) < 0.9_real64 * 400.0_real64 .and. &
           abs(fill(1, 5) - band0(1)) > 0.5_real64
   if (.not. all(ok)) write(output_unit, '(A,4F8.2,A,4L2,A,2F8.2)') 'progress: widths ', w, ', found ', found(1:4), &
                                                                  ', band x0 ', band0(1), fill(1, 5)
   endsubroutine progress_bars

   subroutine notifications(ok)
   !< Two notifications stacked in the bottom-right corner, the newest under; the first gone after its second (60
   !< frames of 1/60 s), the second dismissed by a click; the kept list; 105 notified, the last 100 kept; a wrong kind.
   logical, intent(out)          :: ok(5)     !< Outcomes.
   character(len=:), allocatable :: list(:)   !< Texts kept.
   character(len=7), allocatable :: kinds(:)  !< Their kinds.
   logical,          allocatable :: shown(:)  !< Still shown.
   real(real64)                  :: r1(4), r2(4) !< The newest, the one above it.
   logical                       :: f1, f2    !< Found.
   logical                       :: after_time(2) !< Found after the first's time: newest, second.
   logical                       :: after_click   !< Anything shown after the click.
   integer(int32)                :: fr, stat  !< Frame, status.

   after_time = .false.
   after_click = .true.
   call app%notify('first: the grid is read', seconds=1.0_real64)
   do fr = 1_int32, 140_int32
      if (.not. app%next_frame()) exit
      if (fr == 2_int32) call app%notify('second: residual above tolerance', kind='warning', seconds=0.0_real64)
      select case (fr)
      case (5_int32)
         call test_notification_rect(1_int32, r1(1), r1(2), r1(3), r1(4), f1)
         call test_notification_rect(2_int32, r2(1), r2(2), r2(3), r2(4), f2)
      case (75_int32)                               ! 'first' is past its second
         call test_notification_rect(2_int32, a(1), a(2), a(3), a(4), after_time(2))
         call test_notification_rect(1_int32, a(1), a(2), a(3), a(4), after_time(1))
         call test_click(0.5_real64 * (a(1) + a(3)), 0.5_real64 * (a(2) + a(4)))  ! on the one left
      case (90_int32)
         call test_notification_rect(1_int32, a(1), a(2), a(3), a(4), after_click)
      endselect
   enddo
   ok(1) = f1 .and. f2 .and. r1(2) > r2(4) .and. r1(4) > 600.0_real64 .and. r1(3) > 850.0_real64 .and. &
           r1(3) <= 900.0_real64 .and. r1(4) <= 700.0_real64              ! bottom-right, the newest under
   ok(2) = after_time(1) .and. .not. after_time(2)                       ! the first gone after its time
   ok(3) = .not. after_click                                              ! the second dismissed by a click
   call app%notifications(list, kinds, shown)
   ok(4) = size(list) == 2
   if (ok(4)) ok(4) = list(1) == 'first: the grid is read' .and. trim(list(2)) == 'second: residual above tolerance' &
                      .and. kinds(1) == 'info' .and. kinds(2) == 'warning' .and. .not. any(shown)
   do fr = 1_int32, 105_int32
      call app%notify('note '//itoa(fr), seconds=0.0_real64)
   enddo
   call app%notifications(list)
   call app%notify('?', kind='fatal', stat=stat)
   ok(5) = size(list) == 100 .and. trim(list(1)) == 'note 6' .and. trim(list(100)) == 'note 105' .and. &
           stat == FIG_ERR_ARGUMENT
   if (.not. all(ok)) then
      write(output_unit, '(A,8F8.1,2L2)') 'notifications: rects ', r1, r2, f1, f2
      write(output_unit, '(A,3L2,A,I0)') 'notifications: after time, after click ', after_time, after_click, &
                                         ', kept ', size(list)
   endif
   if (stat == FIG_OK) continue
   endsubroutine notifications

   pure function itoa(n) result(s)
   !< An integer as text.
   integer(int32), intent(in)    :: n   !< Integer.
   character(len=:), allocatable :: s   !< Text.
   character(len=12)             :: buf !< Buffer.

   write(buf, '(I0)') n
   s = trim(buf)
   endfunction itoa
endprogram figure_test_tools
