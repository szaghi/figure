!< figure_player, a player for snapshots: previous, play, next, a slider, a speed and a loop mode.
module figure_player
!< figure_player, a player for snapshots: previous, play, next, a slider, a speed and a loop mode.
!<
!< A program that has saved solutions (snapshots 1 to N of a run, frames of an animation) keeps a `player_object` and
!< draws it with `ig_player` every frame; the player says which snapshot to show (`%index`) and is true on the frame it
!< changed it. While it plays it advances on the frame clock (Dear ImGui's time, which headless frames advance by 1/60 s
!< each) and asks for frames, so lazy redraw does not stop it. The player is made of the public widgets of FIGURE
!< (buttons, a slider, a context menu with a number field and radio buttons, inside a group and an id scope), so the
!< scope record of the frame sees it balanced. widgets.md, "Players".
use, intrinsic :: iso_c_binding, only : c_int, c_loc
use, intrinsic :: ieee_arithmetic, only : ieee_is_finite
use, intrinsic :: iso_fortran_env, only : int32, int64, real64
use figure_base, only : cstr, figure_check, figure_draw_refused, figure_fail
use figure_c_native, only : fig_request_frames, FIG_ERR_ARGUMENT, FIG_OK
use figure_cimgui, only : igCalcItemWidth, igGetCursorPosX, igGetFrameCount, igGetFrameHeight, igGetTime, igSliderInt
use figure_cimgui_enums, only : ImGuiSliderFlags_AlwaysClamp, ImGuiSliderFlags_NoInput
use figure_group, only : ig_begin_group, ig_end_group, ig_pop_id, ig_push_id
use figure_icons, only : ICON_PAUSE, ICON_PLAY, ICON_STEP_BACK, ICON_STEP_FORWARD
use figure_imgui, only : ig_button, ig_same_line, ig_set_next_item_width, ig_em, ig_text_disabled
use figure_menu, only : ig_begin_popup_context, ig_end_popup
use figure_numbers, only : ig_input, ig_radio

implicit none
private
public :: player_object, ig_player

character(len=6), parameter :: MODES(3) = ['once  ', 'loop  ', 'bounce'] !< The loop modes, in the menu's order.

type :: player_object
   !< The state of a player of `count` snapshots, drawn by `ig_player`: a plain value the program keeps (one per
   !< player) and may set at any time, as the player does when the user acts on it. `index` is the snapshot shown, 1 to
   !< `count`; `playing` true while it advances by itself, `speed` snapshots per second; `mode` what it does at the
   !< last snapshot: `'once'` stops there, `'loop'` goes on from the first, `'bounce'` turns back (and again at the
   !< first). Usable before `init*` and from a task (it draws nothing).
   integer(int32)   :: index = 1_int32       !< The snapshot shown, 1 to `count`.
   integer(int32)   :: count = 1_int32       !< Snapshots, >= 1.
   logical          :: playing = .false.     !< Advancing by itself.
   real(real64)     :: speed = 10.0_real64   !< Snapshots per second while playing, > 0 [1/s].
   character(len=6) :: mode = 'loop'         !< 'once', 'loop' or 'bounce'.
   integer(int32), private :: direction = 1_int32    !< Bounce: +1 forwards, -1 backwards.
   real(real64),   private :: phase = 0.0_real64     !< Snapshots due and not yet stepped (a fraction of one).
   real(real64),   private :: t_last = 0.0_real64    !< Frame clock at the last frame drawn [s].
   integer(int32), private :: frame_last = -1_int32  !< Dear ImGui's frame number at the last frame drawn.
   logical,        private :: was_playing = .false.  !< `playing` at the end of the last frame drawn.
endtype player_object

contains
   recursive function ig_player(id, player, labels, stat) result(changed)
   !< A player for `player%count` snapshots, on one line: previous, play/pause, next, and a slider over the snapshots
   !< that shows `labels(player%index)` (default: `index / count`). True on the frame the player changed
   !< `player%index`: a button, the slider, or the time while it plays; the program then shows that snapshot.
   !< Previous and next step one snapshot and stop the playing (in mode `'loop'` they wrap around, in the others they
   !< stop at the ends); a drag of the slider stops it too; play at the last snapshot in mode `'once'` starts again from
   !< the first. A right click on the player opens its menu: the speed (snapshots per second, typed; a value <= 0 is
   !< not taken) and the mode (`'once'`, `'loop'`, `'bounce'`).
   !<
   !< Time: while `player%playing`, `player%speed` snapshots per second of the frame clock (Dear ImGui's time: the
   !< display's frame times in a window, 1/60 s per frame headless, the time between frames in remote mode); a frame
   !< that takes longer steps more snapshots at once. The clock runs on the frames the player is drawn: hidden (a closed
   !< tab), it pauses. While playing, it asks for 1 more frame on each frame (`app%request_frames`), so a lazy loop
   !< keeps drawing. Its width is the current item width (`ig_set_next_item_width` before it, or
   !< `ig_push_item_width`); it is a group: `ig_last_item` and `ig_item_rect` after it report the whole player. An
   !< `index` outside 1 to `count` is moved to the nearest end (and true is returned).
   !<
   !< Refused, nothing drawn, false and `FIG_ERR_ARGUMENT` in `stat` (or `error stop` without it): `count` < 1, `speed`
   !< <= 0 or not finite, an unknown `mode`, `labels` not of `count` entries. No frame open or a task: false,
   !< `FIG_ERR_STATE`. The same in window, headless and remote mode.
   character(len=*),    intent(in)            :: id        !< Its id, unique in the current id scope.
   type(player_object), intent(inout)         :: player    !< The player's state.
   character(len=*),    intent(in),  optional :: labels(:) !< One label per snapshot (a time, a file name).
   integer(int32),      intent(out), optional :: stat      !< Status.
   logical                                    :: changed   !< `player%index` changed this frame.
   integer(int32)                             :: start     !< `player%index` on entry.
   integer(int32)                             :: m         !< The mode's position in MODES.
   integer(int32)                             :: f         !< Dear ImGui's frame number.
   real(real64)                               :: t         !< The frame clock [s].
   real(real64)                               :: fh        !< Frame height: the buttons' side [pixels].
   real(real64)                               :: width     !< The player's width [pixels].
   real(real64)                               :: x0        !< The cursor's x at the player's start [pixels].
   real(real64)                               :: s         !< Speed typed in the menu [1/s].
   integer(c_int), target                     :: v         !< C copy of the index, for the slider.
   character(len=:), allocatable              :: shown     !< A button's label; the slider's text (a format).
   character(len=12)                          :: num       !< A number written.

   changed = .false.
   if (figure_draw_refused('ig_player', stat)) return ! a task does not draw
   if (player%count < 1_int32) then
      write(num, '(I0)') player%count
      call figure_fail(FIG_ERR_ARGUMENT, 'ig_player: count must be at least 1 (got '//trim(num)//')', stat)
      return
   endif
   if (.not. speed_ok(player%speed)) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ig_player: speed must be > 0 snapshots per second', stat)
      return
   endif
   m = findloc(MODES, player%mode, dim=1)
   if (m == 0) then
      call figure_fail(FIG_ERR_ARGUMENT, 'ig_player: unknown mode "'//trim(player%mode)// &
                       '" (''once'', ''loop'' or ''bounce'')', stat)
      return
   endif
   if (present(labels)) then
      if (size(labels, kind=int64) /= int(player%count, int64)) then
         write(num, '(I0)') size(labels, kind=int64)
         call figure_fail(FIG_ERR_ARGUMENT, 'ig_player: labels has '//trim(num)//' entries, not count', stat)
         return
      endif
   endif
   call figure_check(FIG_OK, stat)
   start = player%index
   player%index = max(1_int32, min(player%count, player%index))

   ! the clock: once per frame, on a frame that follows one drawn while playing
   f = int(igGetFrameCount(), int32)
   t = real(igGetTime(), real64)
   if (f /= player%frame_last) then
      if (player%playing .and. player%was_playing .and. player%frame_last == f - 1_int32) then
         player%phase = player%phase + (t - player%t_last) * player%speed
         call advance(player)
      elseif (.not. player%playing) then
         player%phase = 0.0_real64
      endif
   endif

   call ig_push_id(id)
   width = real(igCalcItemWidth(), real64) ! before the buttons, which take what ig_set_next_item_width set
   fh = real(igGetFrameHeight(), real64)
   x0 = real(igGetCursorPosX(), real64)
   call ig_begin_group()
   if (ig_button(ICON_STEP_BACK//'##previous', fh, fh)) then
      player%playing = .false.
      if (player%index > 1_int32) then
         player%index = player%index - 1_int32
      elseif (player%mode == 'loop') then
         player%index = player%count
      endif
   endif
   call ig_same_line()
   if (player%playing) then
      shown = ICON_PAUSE//'###play'
   else
      shown = ICON_PLAY//'###play'
   endif
   if (ig_button(shown, fh, fh)) then
      player%playing = .not. player%playing
      if (player%playing .and. player%mode == 'once' .and. player%index == player%count) player%index = 1_int32
      player%phase = 0.0_real64
   endif
   call ig_same_line()
   if (ig_button(ICON_STEP_FORWARD//'##next', fh, fh)) then
      player%playing = .false.
      if (player%index < player%count) then
         player%index = player%index + 1_int32
      elseif (player%mode == 'loop') then
         player%index = 1_int32
      endif
   endif
   call ig_same_line()
   if (present(labels)) then
      shown = percent_doubled(trim(labels(player%index)))
   else
      write(num, '(I0)') player%count
      shown = '%d / '//trim(num)
   endif
   call ig_set_next_item_width(max(fh, width - (real(igGetCursorPosX(), real64) - x0)))
   v = int(player%index, c_int)
   if (igSliderInt(cstr('##snapshot'), c_loc(v), 1_c_int, int(player%count, c_int), cstr(shown), &
                   ior(ImGuiSliderFlags_NoInput, ImGuiSliderFlags_AlwaysClamp))) then
      player%index = max(1_int32, min(player%count, int(v, int32)))
      player%playing = .false.
   endif
   call ig_end_group()
   if (ig_begin_popup_context('menu')) then ! a right click on any part of the player
      call ig_text_disabled('Player')
      s = player%speed
      call ig_set_next_item_width(ig_em(5.0_real64))
      if (ig_input('snapshots per second', s)) then
         if (speed_ok(s)) player%speed = s
      endif
      if (ig_radio('once: stop at the last', m, 1_int32)) continue
      if (ig_radio('loop: go on from the first', m, 2_int32)) continue
      if (ig_radio('bounce: turn back at the ends', m, 3_int32)) continue
      if (MODES(m) /= player%mode) then
         player%mode = MODES(m)
         player%direction = 1_int32
      endif
      call ig_end_popup()
   endif
   call ig_pop_id()

   if (player%playing) call fig_request_frames(1_c_int) ! lazy redraw keeps time
   player%t_last = t
   player%frame_last = f
   player%was_playing = player%playing
   changed = player%index /= start
   endfunction ig_player

   ! ---- private -------------------------------------------------------------------------------------------------------
   pure subroutine advance(player)
   !< Step the snapshots due (the whole part of `phase`), as the mode says; `once` stops playing at the last.
   type(player_object), intent(inout) :: player !< The player.
   integer(int64)                     :: n      !< Snapshots to step.
   integer(int64)                     :: k      !< Step.

   n = int(min(player%phase + 1.0e-9_real64, 1.0e9_real64), int64) ! 1e-9: the clock's rounding at whole steps
   if (n < 1_int64) return
   player%phase = max(0.0_real64, player%phase - real(n, real64))
   select case (player%mode)
   case ('loop')
      n = mod(n, int(player%count, int64)) ! a whole round changes nothing
   case ('bounce')
      if (player%count > 1_int32) n = mod(n, 2_int64 * int(player%count - 1_int32, int64))
   case default
      n = min(n, int(player%count, int64))
   endselect
   do k = 1_int64, n
      select case (player%mode)
      case ('loop')
         player%index = mod(player%index, player%count) + 1_int32
      case ('bounce')
         if (player%count == 1_int32) exit
         if (player%index + player%direction > player%count .or. player%index + player%direction < 1_int32) &
            player%direction = -player%direction
         player%index = player%index + player%direction
      case default ! once
         if (player%index < player%count) player%index = player%index + 1_int32
         if (player%index == player%count) then
            player%playing = .false.
            player%phase = 0.0_real64
            exit
         endif
      endselect
   enddo
   endsubroutine advance

   elemental function speed_ok(speed) result(ok)
   !< A speed is finite and above 0 (NaN never compared: no invalid-operation trap in debug builds).
   real(real64), intent(in) :: speed !< Snapshots per second [1/s].
   logical                  :: ok    !< Taken.

   ok = .false.
   if (ieee_is_finite(speed)) ok = speed > 0.0_real64
   endfunction speed_ok

   pure function percent_doubled(s) result(r)
   !< `s` with each `%` doubled: a label shown through a printf format as it is.
   character(len=*), intent(in)  :: s !< Text.
   character(len=:), allocatable :: r !< Text for a format.
   integer                       :: i !< Character.

   r = ''
   do i = 1, len(s)
      if (s(i:i) == '%') then
         r = r//'%%'
      else
         r = r//s(i:i)
      endif
   enddo
   endfunction percent_doubled
endmodule figure_player
