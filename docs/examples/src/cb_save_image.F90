!< cb_save_image, reference example: save the plot just drawn as a PNG file, from a button (window mode).
program cb_save_image
!< cb_save_image, reference example: save the plot just drawn as a PNG file, from a button (window mode).
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, FIG_OK, figure_last_error, ig_begin, ig_button, ig_end, ig_get_style_color, ig_item_rect, &
                   ig_same_line, ig_set_next_window, ig_text, ip_begin_plot, ip_drag_line_y, ip_end_plot, &
                   ip_get_style_var, ip_line, ip_pop_style_color, ip_pop_style_var, ip_push_style_color, &
                   ip_push_style_var, ip_set_style_var, ip_setup_axes, ip_spec

implicit none
integer(int32), parameter     :: N = 200_int32  !< Samples.
type(app_object)              :: app            !< Application.
real(real64)                  :: t(N), x(N)     !< A history.
real(real64)                  :: r(4)           !< The plot's rectangle [pixels].
logical                       :: save_now = .false. !< Save on this frame.
logical                       :: done           !< The last request has its outcome.
character(len=:), allocatable :: written        !< The file written.
character(len=120)            :: message = ''   !< The outcome, shown.
integer(int32)                :: stat           !< Status.
real(real64)                  :: ink(4)         !< The theme's text colour.
real(real64)                  :: pad(2)         !< The plot padding in effect [pixels].
real(real64)                  :: level = 0.5_real64 !< A level the user drags.
integer(int32)                :: nv             !< Values of a style variable.
integer(int32)                :: i              !< Counter.

t = [(0.05_real64 * (i - 1), i = 1_int32, N)]
x = exp(-0.1_real64 * t) * sin(t)
call app%init('FIGURE: save an image', 800_int32, 560_int32)
call ip_set_style_var('PlotBorderSize', 0.0_real64)           ! every plot without its border
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 780.0_real64, 540.0_real64)
   if (ig_begin('History')) then
      save_now = ig_button('Save the plot')                   ! a button, not a menu: nothing covers the plot
      call ig_same_line()
      call ig_text(trim(message))
      call ig_get_style_color('Text', ink)                    ! a line that shows on the window, in any theme
      call ip_get_style_var('PlotPadding', pad, nv)           ! a pair: nv = 2
      call ip_push_style_var('PlotPadding', 2.0_real64 * pad) ! this plot only: room around it in the picture
      call ip_push_style_color('PlotBg', '#00000000')         ! ... and no background of its own
      !region save
      if (ip_begin_plot('history', height=-1.0_real64)) then
         call ip_setup_axes('t', 'x')
         call ip_line('x', t, x, spec=ip_spec(line_color=ink))
         if (ip_drag_line_y(1_int32, level)) level = min(1.0_real64, max(-1.0_real64, level)) ! moved: clamp it
         call ip_end_plot()
      endif
      call ig_item_rect(r(1), r(2), r(3), r(4))               ! the plot just drawn
      if (save_now) call app%save_image('history.png', r(1), r(2), r(3), r(4), stat=stat)
      call app%image_result(written, done, stat=stat)         ! every frame: done once, after the write
      if (done) then
         if (stat == FIG_OK) then
            message = 'saved '//written
         else
            message = figure_last_error()                     ! FIG_ERR_FAILED: the file cannot be written
         endif
      endif
      !endregion save
      call ip_pop_style_color()
      call ip_pop_style_var()
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_save_image
