!< cb_plot_readout, cookbook: read the value under the pointer, the iteration nearest to it marked on the plot, tagged
!< on the x axis and its residual written beside it.
program cb_plot_readout
!< cb_plot_readout, cookbook: read the value under the pointer, the iteration nearest to it marked on the plot, tagged
!< on the x axis and its residual written beside it.
!<
!< While the pointer is over the plot, the program reads its position in plot units, takes the nearest iteration, and
!< marks it: a vertical line across the plot, a dot on the curve, a tag on the x axis with the iteration and an
!< annotation with the residual beside the dot (a tag on the y axis wider than its tick labels would widen the axis,
!< and the plot area would shift under the pointer). A box dragged with the right button shows the iterations in it;
!< enter takes them as the program's window of iterations, and ImPlot does not zoom to the box. `cb_plot_readout
!< --check` opens no window: it moves the pointer to iteration 250 with FIGURE's scripted input and prints what the
!< readout shows, then drags a box to iteration 300 and takes it with enter.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, ig_begin, ig_end, ig_set_next_window, ig_shortcut, ip_begin_plot, ip_cancel_selection, &
                   ip_end_plot, ip_inf_lines, ip_line, ip_pixels_to_plot, ip_plot_hovered, ip_plot_limits, &
                   ip_plot_mouse, ip_plot_selection, ip_plot_size, ip_plot_to_pixels, ip_scatter, ip_setup_axis, &
                   ip_setup_axis_constraints, ip_spec, ip_tag, ip_annotation, plot_spec_object, ImPlotMarker_Circle
use figure_testing, only : test_key, test_mouse_button, test_mouse_move
implicit none
integer(int32), parameter :: N = 400_int32                                      !< Iterations.
real(real64),   parameter :: AMBER(4) = [0.96_real64, 0.69_real64, 0.25_real64, 1.0_real64] !< Readout colour.
type(app_object)          :: app           !< Application.
real(real64)              :: it(N)         !< Iteration.
real(real64)              :: residual(N)   !< Residual, from 1 to about 1e-6.
type(plot_spec_object)    :: cursor        !< Style of the vertical line.
type(plot_spec_object)    :: dot           !< Style of the dot.
character(len=16)         :: arg           !< First argument.
character(len=16)         :: text          !< The residual, printed for its tag.
logical                   :: check         !< --check: headless, scripted pointer.
logical                   :: hovered       !< The pointer is over the plot.
real(real64)              :: x, y          !< The pointer [plot units].
real(real64)              :: px, py        !< A plot point [pixels].
integer(int32)            :: k             !< The nearest iteration.
integer(int32)            :: shown         !< The iteration read out (0: none).
integer(int32)            :: frame         !< Frame counter.
real(real64)              :: box(4)        !< The box dragged: x from, to; y from, to [plot units].
integer(int32)            :: window(2)     !< The iterations taken from a box (0: none yet).
character(len=32)         :: span          !< The box's iterations, written.
real(real64)              :: back(2)       !< A pixel back in plot units (--check).
real(real64)              :: area(2)       !< The data area [pixels] (--check).
real(real64)              :: xlim(4)       !< The x axis's range before and after the box (--check).
!run cb_plot_readout ./cb_plot_readout --check
do k = 1_int32, N
   it(k) = real(k, real64)
   residual(k) = 10.0_real64**(-6.0_real64 * real(k, real64) / real(N, real64)) * &
                 (1.0_real64 + 0.4_real64 * sin(real(k, real64) / 7.0_real64))
enddo
cursor = ip_spec(line_color=AMBER, line_weight=1.0_real64)
dot = ip_spec(marker=ImPlotMarker_Circle, marker_size=5.0_real64, marker_fill_color=AMBER, marker_line_color=AMBER)
call get_command_argument(1, arg)
check = trim(arg) == '--check'
if (check) then
   call app%init_headless(900_int32, 520_int32)
else
   call app%init('FIGURE: read the value under the pointer', 900_int32, 520_int32)
endif
frame = 0_int32
shown = 0_int32
window = 0_int32
do while (app%next_frame())
   frame = frame + 1_int32
   call ig_set_next_window(10.0_real64, 10.0_real64, 880.0_real64, 500.0_real64)
   if (ig_begin('Convergence')) then
      if (ip_begin_plot('Residual', height=-1.0_real64)) then
         call ip_setup_axis('x1', label='iteration', format='%.0f')
         call ip_setup_axis('y1', label='residual', scale='log')
         call ip_setup_axis_constraints('x1', vmin=0.0_real64, vmax=real(N + 1, real64)) ! no pan or zoom past the run
         call ip_line('residual', it, residual)
         !region readout
         hovered = ip_plot_hovered()
         if (hovered) then
            call ip_plot_mouse(x, y)                               ! the pointer in plot units
            k = min(max(nint(x), 1_int32), N)                      ! the nearest iteration
            call ip_inf_lines('##cursor', [k], spec=cursor)        ! a line across the plot, at an integer
            call ip_scatter('##point', it(k:k), residual(k:k), spec=dot)
            write(text, '(ES9.2)') residual(k)
            call ip_tag('x1', it(k), color=AMBER)                  ! the iteration, as the axis labels it
            call ip_annotation(it(k), residual(k), trim(adjustl(text)), color=AMBER, &
                               offset=[40.0_real64, -24.0_real64])         ! the residual beside the dot
            shown = k
         endif
         !endregion readout
         !region box
         if (ip_plot_selection(box(1), box(2), box(3), box(4))) then ! a box dragged with the right button
            write(span, '(A,I0,A,I0)') 'iterations ', max(nint(box(1)), 1_int32), ' to ', min(nint(box(2)), N)
            call ip_annotation(box(2), box(4), trim(span), color=AMBER, offset=[8.0_real64, 8.0_real64])
            if (ig_shortcut('enter', scope='global')) then        ! enter: the program takes the box ...
               window = [max(nint(box(1)), 1_int32), min(nint(box(2)), N)]
               call ip_cancel_selection()                         ! ... and ImPlot zooms nothing on the release
            endif
         endif
         !endregion box
         if (check) call script()
         call ip_end_plot()
      endif
   endif
   call ig_end()
   if (check .and. frame == 20_int32) exit
enddo
call app%destroy()

contains
   subroutine script()
   !< The input of --check, by frame, inside the plot.
   select case (frame)
   case (4_int32)                                                 ! the pointer to iteration 250
      call ip_plot_to_pixels(it(250), residual(250), px, py)
      call ip_pixels_to_plot(px, py, back(1), back(2))            ! and back: to a fraction of a pixel
      call ip_plot_size(area(1), area(2))
      call test_mouse_move(px, py)
   case (8_int32)
      write(output_unit, '(A,L1)') 'pointer over the plot: ', hovered
      write(output_unit, '(A,I0)') 'nearest iteration:     ', shown
      write(output_unit, '(A,A)')  'residual shown:        ', trim(adjustl(text))
      write(output_unit, '(A,L1,A,L1)') 'pixel to iteration 250 and back within a pixel: ', &
         abs(back(1) - it(250)) < (N - 1) / area(1), ', a data area: ', all(area > 0.0_real64)
      call ip_plot_limits(xlim(1), xlim(2), back(1), back(2))
      call test_mouse_button(.true., 'right')                     ! a box from iteration 250 ...
   case (10_int32)
      call ip_plot_to_pixels(it(300), residual(300), px, py)
      call test_mouse_move(px, py)                                ! ... to 300
   case (13_int32)
      call test_key('enter')                                      ! taken
   case (15_int32)
      call test_mouse_button(.false., 'right')
   case (18_int32)
      call ip_plot_limits(xlim(3), xlim(4), back(1), back(2))
      write(output_unit, '(A,I0,A,I0,A,L1)') 'box taken: iterations ', window(1), ' to ', window(2), &
         ', the x axis not zoomed: ', all(abs(xlim(3:4) - xlim(1:2)) < 1.0e-9_real64)
   endselect
   endsubroutine script
endprogram cb_plot_readout
