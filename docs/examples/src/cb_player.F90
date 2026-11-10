!< cb_player, cookbook: step through saved solutions with a player: previous, play, next, a slider, a speed.
program cb_player
!< cb_player, cookbook: step through saved solutions with a player: previous, play, next, a slider, a speed.
!<
!< Forty saved solutions of a pulse moving along a duct, u(x) at t = 0, 0.05, ..., 1.95 s, kept in an array; a
!< player above the plot says which one to draw, and plays them at 8 snapshots per second, back and forth.
!< `cb_player --check` opens no window: it plays one second of headless frames (1/60 s each), steps with next and
!< previous, and prints the snapshot shown.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, ig_begin, ig_end, ig_item_rect, ig_player, ig_set_next_window, ig_text_disabled, &
                   ip_begin_plot, ip_end_plot, ip_line, ip_setup_axes, ip_setup_axes_limits, player_object,    &
                   ig_frame_height, ig_get_style_var
use figure_testing, only : test_click
implicit none
integer(int32), parameter :: NX = 200_int32       !< Points along the duct.
integer(int32), parameter :: NS = 40_int32        !< Saved solutions.
real(real64),   parameter :: DT = 0.05_real64     !< Time between two snapshots [s].
type(app_object)          :: app                  !< Application.
type(player_object)       :: player               !< The player over the snapshots.
real(real64)              :: x(NX)                !< Abscissae [m].
real(real64)              :: u(NX, NS)            !< The saved solutions, one per column [m/s].
character(len=12)         :: times(NS)            !< The snapshots' times, shown on the slider.
real(real64)              :: at(4)                !< The player's rectangle [pixels].
character(len=16)         :: arg                  !< First argument.
logical                   :: check                !< --check: headless, scripted input.
integer(int32)            :: frame                !< Frame counter.
integer(int32)            :: k                    !< Snapshot.
!run cb_player ./cb_player --check
x = [(real(k - 1, real64) / real(NX - 1, real64), k = 1_int32, NX)]
do k = 1_int32, NS
   u(:, k) = exp(-((x - 0.15_real64 - 0.35_real64 * (k - 1) * DT) / 0.06_real64)**2)
   write(times(k), '(A,F4.2,A)') 't = ', (k - 1) * DT, ' s'
enddo
at = 0.0_real64
call get_command_argument(1, arg)
check = trim(arg) == '--check'
if (check) then
   call app%init_headless(640_int32, 400_int32)
else
   call app%init('FIGURE: step through saved solutions', 640_int32, 400_int32)
endif
!region player
player%count = NS                                   ! the snapshots saved
player%speed = 8.0_real64                           ! snapshots per second while playing
player%mode = 'bounce'                              ! back and forth
!endregion player
frame = 0_int32
do while (app%next_frame())
   frame = frame + 1_int32
   call ig_set_next_window(10.0_real64, 10.0_real64, 620.0_real64, 380.0_real64)
   if (ig_begin('Solutions')) then
      !region draw
      if (ig_player('snapshots', player, labels=times)) then
         if (check) write(output_unit, '(A,I0,A,I0,A)') 'frame ', frame, ': snapshot ', player%index, &
                                                        ' ('//trim(times(player%index))//')'
      endif
      call ig_item_rect(at(1), at(2), at(3), at(4))
      call ig_text_disabled('right click on the player: speed and mode')
      if (ip_begin_plot('u(x)', height=-1.0_real64)) then
         call ip_setup_axes('x [m]', 'u [m/s]')
         call ip_setup_axes_limits(0.0_real64, 1.0_real64, -0.1_real64, 1.1_real64)
         call ip_line('u', x, u(:, player%index))     ! the snapshot the player shows
         call ip_end_plot()
      endif
      !endregion draw
   endif
   call ig_end()
   if (check) then
      call script(frame)
      if (frame == 120_int32) exit
   endif
enddo
call app%destroy()
contains
   subroutine script(f)
   !< The input of --check, by frame: play pressed, one second later paused, then next and previous.
   integer(int32), intent(in) :: f     !< Frame.
   real(real64)               :: fh    !< The buttons' side [pixels].
   real(real64)               :: sp(2) !< The space between items [pixels].
   integer(int32)             :: n     !< Values of the style variable.

   fh = ig_frame_height()
   call ig_get_style_var('ItemSpacing', sp, n)
   select case (f)
   case (5_int32)
      write(output_unit, '(A)') 'frame 5: play (8 snapshots per second, 1/60 s per headless frame)'
      call test_click(at(1) + 1.5_real64 * fh + sp(1), at(2) + 0.5_real64 * fh)
   case (65_int32)
      write(output_unit, '(A)') 'frame 65: pause'
      call test_click(at(1) + 1.5_real64 * fh + sp(1), at(2) + 0.5_real64 * fh)
   case (80_int32)
      write(output_unit, '(A)') 'frame 80: next'
      call test_click(at(1) + 2.5_real64 * fh + 2.0_real64 * sp(1), at(2) + 0.5_real64 * fh)
   case (95_int32)
      write(output_unit, '(A)') 'frame 95: previous'
      call test_click(at(1) + 0.5_real64 * fh, at(2) + 0.5_real64 * fh)
   endselect
   endsubroutine script
endprogram cb_player
