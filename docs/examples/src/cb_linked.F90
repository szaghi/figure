!< cb_linked, cookbook: three plots over one iteration axis, aligned and linked, with a menu on a legend entry.
program cb_linked
!< cb_linked, cookbook: three plots over one iteration axis, aligned and linked, with a menu on a legend entry.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_begin_tooltip, ig_checkbox, ig_end, ig_end_tooltip, ig_set_next_window, &
                   ig_text, ip_begin_aligned,                                                                      &
                   ip_begin_legend_popup, ip_begin_plot, ip_end_aligned, ip_end_legend_popup, ip_end_plot,          &
                   ip_hide_next_item, ip_legend_hovered, ip_line, ip_link_axis, ip_setup_axes

implicit none
integer(int32), parameter :: N = 400_int32 !< Iterations.
type(app_object)          :: app           !< Application.
real(real64)              :: it(N)         !< Iterations.
real(real64)              :: res(N)        !< Residual.
real(real64)              :: cfl(N)        !< CFL number.
real(real64)              :: cl(N)         !< Lift coefficient.
real(real64)              :: cd(N)         !< Drag coefficient.
logical                   :: show_cd       !< The drag coefficient is shown.
character(len=40)         :: line          !< A formatted value.
integer(int32)            :: i             !< Iteration.

it = [(real(i, real64), i = 1_int32, N)]
res = 1.0e3_real64 * exp(-it / 60.0_real64) * (1.0_real64 + 0.3_real64 * sin(it / 7.0_real64))
cfl = min(5.0_real64, 0.5_real64 + it / 40.0_real64)
cl = 0.8_real64 + 0.3_real64 * exp(-it / 80.0_real64) * sin(it / 9.0_real64)
cd = 0.05_real64 + 0.02_real64 * exp(-it / 80.0_real64) * cos(it / 9.0_real64)
show_cd = .true.
call app%init('FIGURE: three plots over one iteration axis', 720_int32, 560_int32)
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 700.0_real64, 540.0_real64)
   if (ig_begin('Run')) then
      !region linked
      if (ip_begin_aligned('history')) then                 ! the plot areas start at the same pixel
         if (ip_begin_plot('residual', height=160.0_real64)) then
            call ip_setup_axes('', 'residual')
            call ip_link_axis('x1', 'iteration')            ! pan or zoom one: the three follow
            call ip_line('residual', it, res)
            call ip_end_plot()
         endif
         if (ip_begin_plot('cfl', height=160.0_real64)) then
            call ip_setup_axes('', 'CFL')
            call ip_link_axis('x1', 'iteration')
            call ip_line('CFL', it, cfl)
            call ip_end_plot()
         endif
         if (ip_begin_plot('forces', height=-1.0_real64)) then
            call ip_setup_axes('iteration', 'coefficient')
            call ip_link_axis('x1', 'iteration')
            call ip_line('lift', it, cl)
            call ip_hide_next_item(.not. show_cd, always=.true.) ! the program decides, every frame
            call ip_line('drag', it, cd)
            if (ip_begin_legend_popup('drag')) then         ! a right click on the entry
               write(line, '(A,F7.4)') 'last value ', cd(N)
               call ig_text(trim(line))
               if (ig_checkbox('shown', show_cd)) continue
               call ip_end_legend_popup()
            endif
            if (ip_legend_hovered('lift')) then               ! the pointer on the entry
               if (ig_begin_tooltip()) then
                  call ig_text('lift: the force normal to the flow, over q S')
                  call ig_end_tooltip()
               endif
            endif
            call ip_end_plot()
         endif
         call ip_end_aligned()
      endif
      !endregion linked
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_linked
