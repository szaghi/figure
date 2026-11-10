!< cb_save_image, reference example: save the plot just drawn as a PNG file, from a button (window mode).
program cb_save_image
!< cb_save_image, reference example: save the plot just drawn as a PNG file, from a button (window mode).
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, FIG_OK, figure_last_error, ig_begin, ig_button, ig_end, ig_item_rect, ig_same_line, &
                   ig_set_next_window, ig_text, ip_begin_plot, ip_end_plot, ip_line, ip_setup_axes

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
integer(int32)                :: i              !< Counter.

t = [(0.05_real64 * (i - 1), i = 1_int32, N)]
x = exp(-0.1_real64 * t) * sin(t)
call app%init('FIGURE: save an image', 800_int32, 560_int32)
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 780.0_real64, 540.0_real64)
   if (ig_begin('History')) then
      save_now = ig_button('Save the plot')                   ! a button, not a menu: nothing covers the plot
      call ig_same_line()
      call ig_text(trim(message))
      !region save
      if (ip_begin_plot('history', height=-1.0_real64)) then
         call ip_setup_axes('t', 'x')
         call ip_line('x', t, x)
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
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_save_image
