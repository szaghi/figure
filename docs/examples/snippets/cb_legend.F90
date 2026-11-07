!< cb_legend, cookbook: colour-scale legends beside a plot and below it, and a colour chosen with a colour editor.
program cb_legend
!< cb_legend, cookbook: colour-scale legends beside a plot and below it, and a colour chosen with a colour editor.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_color_edit, ig_end, ig_same_line, ig_set_next_window, ig_text, &
                   ip_begin_plot, ip_colormap, ip_colormap_legend, ip_contour, ip_end_plot, ip_heatmap, ip_setup_axes

implicit none
integer(int32), parameter :: N = 81_int32    !< Samples a side, over [-1, 1].
type(app_object)          :: app             !< Application.
real(real64)              :: p(N, N)         !< A pressure-like field, in [-1, 1].
real(real64)              :: h               !< Spacing.
real(real64)              :: line_color(4) = [1.0_real64, 1.0_real64, 1.0_real64, 1.0_real64] !< The contours' colour.
integer(int32)            :: i, j            !< Counters.
character(len=48)         :: text = 'drag a field, or click the square for a picker' !< What the editor did.

h = 2.0_real64 / (N - 1)
do j = 1_int32, N
   do i = 1_int32, N
      p(i, j) = cos(3.0_real64 * (-1.0_real64 + (i - 1) * h)) * sin(2.0_real64 * (-1.0_real64 + (j - 1) * h))
   enddo
enddo

call app%init('FIGURE: colour-scale legends', 760_int32, 620_int32)
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 740.0_real64, 600.0_real64)
   if (ig_begin('Legends')) then
      if (ig_color_edit('contour lines', line_color)) then ! true on the frames the user changes it
         write(text, '(A,4F6.2)') 'changed to', line_color  ! line_color is updated: the lines below use it
      endif
      call ig_text(trim(text))
      if (ip_begin_plot('pressure', width=560.0_real64, height=420.0_real64, equal=.true.)) then
         call ip_setup_axes('x', 'y')
         call ip_heatmap('##p', p, -1.0_real64 - 0.5_real64 * h, 1.0_real64 + 0.5_real64 * h, -1.0_real64 - 0.5_real64 * h, &
                         1.0_real64 + 0.5_real64 * h, scale_min=-1.0_real64, scale_max=1.0_real64,                          &
                         colormap=ip_colormap('balance', levels=8_int32))
         call ip_contour('p', p, -1.0_real64, 1.0_real64, -1.0_real64, 1.0_real64, levels=[-0.5_real64, 0.0_real64, &
                         0.5_real64], color=line_color)
         call ip_end_plot()
      endif
      call ig_same_line()
      call ip_colormap_legend('p levels', ip_colormap('balance'), -1.0_real64, 1.0_real64, levels=8_int32, &
                              height=420.0_real64)                    ! the bands of the heatmap, their edges labelled
      call ig_text('the same map, continuous, horizontal:')
      call ip_colormap_legend('p continuous', ip_colormap('balance'), -1.0_real64, 1.0_real64, horizontal=.true., &
                              width=560.0_real64, label_format='%.1f')
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_legend
