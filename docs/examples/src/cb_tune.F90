!< cb_tune, cookbook: tune the style in Dear ImGui's style editor and keep it as a theme file.
program cb_tune
!< cb_tune, cookbook: tune the style in Dear ImGui's style editor and keep it as a theme file.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_button, ig_checkbox, ig_end, ig_set_next_window, ig_show_style_editor, &
                   ig_slider, ig_text, ip_begin_plot, ip_end_plot, ip_line

implicit none
integer(int32), parameter :: N = 200_int32 !< Points.
type(app_object)          :: app           !< Application.
real(real64)              :: x(N)          !< Abscissae.
real(real64)              :: level         !< A value.
logical                   :: on            !< A flag.
integer(int32)            :: i             !< Counter.
integer(int32)            :: stat          !< Status of the save.
character(len=64)         :: saved         !< What the last save did.

x = [(real(i - 1, real64) / real(N - 1, real64), i = 1_int32, N)]
level = 0.6_real64
on = .true.
saved = ''

call app%init('FIGURE: tune a theme', 1100_int32, 680_int32)
do while (app%next_frame())
   call ig_set_next_window(560.0_real64, 20.0_real64, 520.0_real64, 640.0_real64)
   !region tune
   call ig_show_style_editor()                          ! every colour and size, live
   call ig_set_next_window(20.0_real64, 20.0_real64, 520.0_real64, 400.0_real64)
   if (ig_begin('Sample')) then
      if (ig_button('Save theme')) then
         call app%save_style('my-theme.toml', stat=stat) ! what differs from the base, as a theme file
         if (stat == 0_int32) then
            saved = 'saved to my-theme.toml'
         else
            saved = 'cannot write my-theme.toml'
         endif
      endif
      call ig_text(trim(saved))
      !endregion tune
      if (ig_checkbox('enabled', on)) continue
      if (ig_slider('level', level, 0.0_real64, 1.0_real64)) continue
      if (ip_begin_plot('Response', height=-1.0_real64)) then
         call ip_line('level', x, level * sin(6.0_real64 * x))
         call ip_end_plot()
      endif
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_tune
