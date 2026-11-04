!< tut02_widgets, tutorial chapter 2: widgets bound to Fortran variables.
program tut02_widgets
!< tut02_widgets, tutorial chapter 2: widgets bound to Fortran variables.
use, intrinsic :: iso_fortran_env, only : int32, real32, real64
use figure, only : app_object, ig_begin, ig_button, ig_checkbox, ig_end, ig_input, ig_same_line, ig_separator, &
                   ig_set_next_window, ig_show_demo_window, ig_slider, ig_text

implicit none
type(app_object)  :: app        !< Application.
integer(int32)    :: cells      !< Grid cells.
real(real32)      :: relax      !< Relaxation factor.
real(real64)      :: cfl        !< CFL number.
real(real64)      :: t_end      !< Final time [s].
logical           :: viscous    !< Viscous terms on.
logical           :: show_tools !< Tools window open.
logical           :: show_demo  !< Dear ImGui demo open.
integer(int32)    :: runs       !< Times "Run" was pressed.
character(len=80) :: line       !< Text buffer.

cells = 100_int32
relax = 0.8_real32
cfl = 0.5_real64
t_end = 1.0_real64
viscous = .true.
show_tools = .true.
show_demo = .false.
runs = 0_int32

call app%init('FIGURE: widgets', 900_int32, 600_int32)
do while (app%next_frame())
   call ig_set_next_window(20.0_real64, 20.0_real64, 420.0_real64, 320.0_real64)
   if (ig_begin('Setup')) then
      if (ig_slider('cells', cells, 10_int32, 1000_int32)) continue
      if (ig_slider('relaxation', relax, 0.1_real32, 1.0_real32)) continue
      if (ig_slider('CFL', cfl, 0.1_real64, 2.0_real64)) continue
      if (ig_input('final time', t_end, step=0.1_real64, format='%.3f')) then
         t_end = max(t_end, 0.0_real64)
      endif
      if (ig_checkbox('viscous', viscous)) continue
      call ig_separator()
      if (ig_button('Run')) runs = runs + 1_int32
      call ig_same_line()
      write(line, '(A,I0,A,I0,A,F5.2)') 'runs: ', runs, ', cells: ', cells, ', CFL: ', cfl
      call ig_text(trim(line))
      if (ig_button('Reset##cfl')) cfl = 0.5_real64
      call ig_same_line()
      if (ig_button('Reset##time')) t_end = 1.0_real64
      if (ig_checkbox('tools window', show_tools)) continue
      if (ig_checkbox('Dear ImGui demo', show_demo)) continue
   endif
   call ig_end()

   if (show_tools) then
      call ig_set_next_window(460.0_real64, 20.0_real64, 300.0_real64, 120.0_real64)
      if (ig_begin('Tools', show_tools)) then
         call ig_text('Close me with the x in the title bar.')
      endif
      call ig_end()
   endif
   if (show_demo) call ig_show_demo_window(show_demo)
enddo
call app%destroy()
endprogram tut02_widgets
