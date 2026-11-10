!< figure_test_player, the player for snapshots driven by headless frames and synthetic input.
program figure_test_player
!< figure_test_player, the player for snapshots driven by headless frames and synthetic input.
!<
!< Headless frames advance the frame clock by 1/60 s: a player at 6 snapshots per second steps 6 snapshots in 60
!< frames (true on each of those 6 frames), one at 30 steps 30. At 60 per second (one per frame) mode 'loop' goes
!< 3, 4, 1, 2, ...; 'bounce' 1, 2, 3, 2, 1, 2; 'once' stops at the last and stops playing. Next and previous step one
!< snapshot (previous at the first wraps to the last in 'loop'); play starts and pauses; a click at the slider's right
!< end shows the last snapshot, at its left end the first. A right click opens the menu: the speed typed there is
!< taken, the 'bounce' radio button sets the mode; a click outside closes it. An index out of range is moved to the
!< nearest end; labels of the right size are taken; count < 1, speed <= 0 or NaN, an unknown mode and labels of the
!< wrong size are refused with their messages. No frame has a usage error.
use, intrinsic :: ieee_arithmetic, only : ieee_quiet_nan, ieee_value
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : FIG_ERR_ARGUMENT, FIG_OK, app_object, figure_last_error, ig_begin, ig_end, ig_frame_height, &
                   ig_get_style_var, ig_item_rect, ig_line_height, ig_em, ig_player, ig_set_next_item_width,     &
                   ig_set_next_window, player_object
use figure_testing, only : test_click, test_key, test_popup_rect, test_type

implicit none
integer(int32), parameter :: START = 10_int32   !< The frame the timed players start playing.
integer(int32), parameter :: FRAMES = 200_int32 !< Frames of the script.
type(app_object)          :: app                !< Application.
type(player_object)       :: ui                 !< The player driven by clicks.
type(player_object)       :: slow               !< 6 snapshots per second.
type(player_object)       :: half               !< 30 snapshots per second: a step every second frame.
type(player_object)       :: looping            !< Mode 'loop', a step per frame.
type(player_object)       :: bouncing           !< Mode 'bounce', a step per frame.
type(player_object)       :: once               !< Mode 'once', a step per frame.
type(player_object)       :: bad                !< Refused arguments.
logical                   :: ok(16)             !< Per-check outcome.
integer(int32)            :: f                  !< Frame.
integer(int32)            :: s                  !< Status of a frame.
integer(int32)            :: errors             !< Frames with a usage error.
integer(int32)            :: slow_changes       !< Frames on which `slow` returned true.
integer(int32)            :: seq(3, 6)          !< Indices of looping, bouncing, once on the frames after START.
logical                   :: once_playing       !< `once%playing` after its last step.
real(real64)              :: r(4)               !< The ui player's rectangle.
real(real64)              :: p(4)               !< The menu's rectangle.
real(real64)              :: fh                 !< Frame height [pixels].
real(real64)              :: lh                 !< Line height [pixels].
real(real64)              :: sp(2)              !< Item spacing [pixels].
real(real64)              :: pad(2)             !< Window padding [pixels].
integer(int32)            :: n                  !< Values of a style variable.
logical                   :: menu_open          !< A popup is open.
logical                   :: seen(10)           !< States observed along the script.
integer(int32)            :: stat_bad(6)        !< Statuses of the refused calls.
character(len=200)        :: msg_bad(6)         !< Their messages.
logical                   :: clamped            !< The out-of-range index reported as a change.
integer(int32)            :: stat_labels        !< Status with labels of the right size.

ok = .false.
seen = .false.
errors = 0_int32
slow_changes = 0_int32
seq = 0_int32
once_playing = .true.
ui%count = 10_int32
slow%count = 100_int32
slow%speed = 6.0_real64
half%count = 100_int32
half%speed = 30.0_real64
looping%count = 4_int32
looping%index = 3_int32
looping%speed = 60.0_real64
bouncing%count = 3_int32
bouncing%speed = 60.0_real64
bouncing%mode = 'bounce'
once%count = 3_int32
once%speed = 60.0_real64
once%mode = 'once'
call app%init_headless(800_int32, 600_int32)
do f = 1_int32, FRAMES
   if (.not. app%next_frame(s)) exit
   if (s /= FIG_OK) errors = errors + 1_int32
   if (f == START) then                                    ! the timed players start: the clock from this frame
      slow%playing = .true.
      half%playing = .true.
      looping%playing = .true.
      bouncing%playing = .true.
      once%playing = .true.
   endif
   call ig_set_next_window(20.0_real64, 20.0_real64, 600.0_real64, 400.0_real64, always=.true.)
   if (ig_begin('Players')) then
      call ig_set_next_item_width(400.0_real64)
      if (ig_player('ui', ui)) continue
      call ig_item_rect(r(1), r(2), r(3), r(4))
      fh = ig_frame_height()
      lh = ig_line_height()
      if (ig_player('slow', slow)) slow_changes = slow_changes + 1_int32
      if (ig_player('half', half)) continue
      if (ig_player('loop', looping)) continue
      if (ig_player('bounce', bouncing)) continue
      if (ig_player('once', once)) continue
   endif
   call ig_end()
   call ig_get_style_var('ItemSpacing', sp, n)
   call ig_get_style_var('WindowPadding', pad, n)
   if (f > START .and. f <= START + 6_int32) then
      seq(:, f - START) = [looping%index, bouncing%index, once%index]
      if (f == START + 2_int32) once_playing = once%playing
   endif
   if (f == START + 60_int32) then                         ! one second of frame time
      ok(1) = slow%index == 7_int32 .and. slow_changes == 6_int32
      ok(2) = half%index == 31_int32
      slow%playing = .false.
      half%playing = .false.
      looping%playing = .false.
      bouncing%playing = .false.
   endif
   call test_popup_rect(p(1), p(2), p(3), p(4), menu_open)
   call script(f)
enddo
call ig_set_next_window(20.0_real64, 20.0_real64, 600.0_real64, 400.0_real64, always=.true.)
if (app%next_frame(s)) continue
if (s /= FIG_OK) errors = errors + 1_int32
if (ig_begin('Players')) then
   bad%count = 0_int32
   if (ig_player('bad', bad, stat=stat_bad(1))) continue
   msg_bad(1) = figure_last_error()
   bad%count = 10_int32
   bad%speed = 0.0_real64
   if (ig_player('bad', bad, stat=stat_bad(2))) continue
   msg_bad(2) = figure_last_error()
   bad%speed = ieee_value(1.0_real64, ieee_quiet_nan)
   if (ig_player('bad', bad, stat=stat_bad(3))) continue
   msg_bad(3) = figure_last_error()
   bad%speed = 2.0_real64
   bad%mode = 'ping'
   if (ig_player('bad', bad, stat=stat_bad(4))) continue
   msg_bad(4) = figure_last_error()
   bad%mode = 'once'
   if (ig_player('bad', bad, labels=['a', 'b'], stat=stat_bad(5))) continue
   msg_bad(5) = figure_last_error()
   bad%index = 50_int32
   clamped = ig_player('bad', bad, stat=stat_bad(6))
   msg_bad(6) = ''
   ok(14) = clamped .and. bad%index == 10_int32 .and. stat_bad(6) == FIG_OK
   if (ig_player('labelled', once, labels=['t = 0.0 s', 't = 0.5 s', '100% done'], stat=stat_labels)) continue
endif
call ig_end()
if (app%next_frame(s)) continue
if (s /= FIG_OK) errors = errors + 1_int32
call app%destroy()

ok(3) = all(seq(1, :) == [4, 1, 2, 3, 4, 1])  ! loop
ok(4) = all(seq(2, :) == [2, 3, 2, 1, 2, 3])  ! bounce
ok(5) = all(seq(3, :) == [2, 3, 3, 3, 3, 3]) .and. .not. once_playing .and. .not. once%playing ! once
ok(6) = seen(1) .and. seen(2)                  ! next, previous
ok(7) = seen(3)                                ! previous at the first wraps (loop)
ok(8) = seen(4) .and. seen(5)                  ! play, pause
ok(9) = seen(6) .and. seen(7)                  ! slider ends
ok(10) = seen(8) .and. ui%speed == 20.0_real64 ! the menu's speed
ok(11) = seen(9) .and. ui%mode == 'bounce'     ! the menu's mode
ok(12) = seen(10)                              ! closed by a click outside
ok(13) = all(stat_bad(1:5) == int(FIG_ERR_ARGUMENT, int32)) .and.                                       &
         msg_bad(1) == 'ig_player: count must be at least 1 (got 0)' .and.                               &
         msg_bad(2) == 'ig_player: speed must be > 0 snapshots per second' .and.                         &
         msg_bad(3) == 'ig_player: speed must be > 0 snapshots per second' .and.                         &
         msg_bad(4) == 'ig_player: unknown mode "ping" (''once'', ''loop'' or ''bounce'')' .and.         &
         msg_bad(5) == 'ig_player: labels has 2 entries, not count'
ok(15) = stat_labels == FIG_OK
ok(16) = errors == 0_int32
if (.not. all(ok)) then
   write(output_unit, '(A,16L2)') 'checks:', ok
   write(output_unit, '(A,2(I0,1X),A,I0)') 'slow, half: ', slow%index, half%index, '; slow changes ', slow_changes
   write(output_unit, '(A,18(I0,1X))') 'loop, bounce, once: ', seq
   write(output_unit, '(A,10L2,A,G0,A,A)') 'seen:', seen, '; speed ', ui%speed, ', mode ', ui%mode
   write(output_unit, '(A,I0)') 'usage errors: ', errors
endif
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(ok)
if (.not. all(ok)) error stop 1

contains
   subroutine script(frame)
   !< The clicks on the ui player and its menu, and the states they lead to.
   integer(int32), intent(in) :: frame !< Frame.
   real(real64)               :: y     !< The buttons' centre ordinate [pixels].

   y = r(2) + 0.5_real64 * fh
   select case (frame)
   case (90_int32)
      call test_click(r(1) + 2.0_real64 * (fh + sp(1)) + 0.5_real64 * fh, y)   ! next
   case (98_int32)
      seen(1) = ui%index == 2_int32 .and. .not. ui%playing
      call test_click(r(1) + 0.5_real64 * fh, y)                               ! previous
   case (106_int32)
      seen(2) = ui%index == 1_int32
      call test_click(r(1) + 0.5_real64 * fh, y)                               ! previous at the first
   case (114_int32)
      seen(3) = ui%index == 10_int32
      call test_click(r(1) + fh + sp(1) + 0.5_real64 * fh, y)                  ! play
   case (122_int32)
      seen(4) = ui%playing
      call test_click(r(1) + fh + sp(1) + 0.5_real64 * fh, y)                  ! pause
   case (130_int32)
      seen(5) = .not. ui%playing
      call test_click(r(3) - 2.0_real64, y)                                    ! the slider's right end
   case (138_int32)
      seen(6) = ui%index == 10_int32
      call test_click(r(1) + 3.0_real64 * (fh + sp(1)) + 2.0_real64, y)        ! its left end
   case (146_int32)
      seen(7) = ui%index == 1_int32
      call test_click(0.5_real64 * (r(1) + r(3)), y, button='right')           ! the menu
   case (154_int32)
      seen(8) = menu_open                                                      ! the speed field, below the title
      call test_click(p(1) + pad(1) + ig_em(2.5_real64), p(2) + pad(2) + lh + sp(2) + 0.5_real64 * fh)
   case (158_int32)
      call test_type('20')
   case (160_int32)
      call test_key('enter')
   case (166_int32)
      seen(8) = seen(8) .and. ui%speed == 20.0_real64 .and. menu_open           ! the 'bounce' radio button
      call test_click(p(1) + pad(1) + 0.5_real64 * fh, p(2) + pad(2) + lh + sp(2) + 3.0_real64 * (fh + sp(2)) + &
                      0.5_real64 * fh)
   case (174_int32)
      seen(9) = ui%mode == 'bounce' .and. menu_open
      call test_click(700.0_real64, 550.0_real64)                              ! outside
   case (182_int32)
      seen(10) = .not. menu_open
   endselect
   endsubroutine script
endprogram figure_test_player
