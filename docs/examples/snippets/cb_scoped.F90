!< cb_scoped, cookbook: one red button, a large value, a window without decorations.
program cb_scoped
!< cb_scoped, cookbook: one red button, a large value, a window without decorations.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_button, ig_end, ig_pop_font, ig_pop_style_color, ig_pop_style_var,  &
                   ig_push_font, ig_push_style_color, ig_push_style_var, ig_same_line, ig_set_next_window,    &
                   ig_text, ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoBackground,                  &
                   ImGuiWindowFlags_NoDecoration

implicit none
type(app_object) :: app     !< Application.
logical          :: running !< The computation runs.
real(real64)     :: residual !< A value to show large.
character(len=32) :: line   !< Text buffer.

running = .true.
residual = 3.2e-7_real64

call app%init('FIGURE: scoped styles', 640_int32, 300_int32)
do while (app%next_frame())
   call ig_set_next_window(20.0_real64, 20.0_real64, 360.0_real64, 260.0_real64)
   if (ig_begin('Run control')) then
      if (ig_button('Start')) running = .true.
      call ig_same_line()
      call ig_push_style_color('Button', '#b42d1a')         ! this button only
      call ig_push_style_color('ButtonHovered', '#d9442c')
      call ig_push_style_color('ButtonActive', '#e8664c')
      call ig_push_style_var('FramePadding', [16.0_real64, 6.0_real64])
      if (ig_button('Stop')) running = .false.
      call ig_pop_style_var()
      call ig_pop_style_color(3)                            ! the three colours
      call ig_text('residual')
      write(line, '(ES9.2)') residual
      call ig_push_font('', 36.0_real64)                    ! the current font, larger
      call ig_text(trim(adjustl(line)))
      call ig_pop_font()
      if (running) then
         call ig_text('running')
      else
         call ig_text('stopped')
      endif
   endif
   call ig_end()
   call ig_set_next_window(420.0_real64, 30.0_real64)
   if (ig_begin('##overlay', flags=ior(ImGuiWindowFlags_NoDecoration,                     &
                                       ior(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoBackground)))) then
      call ig_text('no title, no frame,')
      call ig_text('no background')
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_scoped
