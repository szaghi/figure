!< figure_test_plots, tick formats, linked subplots and a window docked after the layout was built, headless.
program figure_test_plots
!< figure_test_plots, tick formats, linked subplots and a window docked after the layout was built, headless.
!<
!< A y axis with a printf format: every tick label follows it (and without it, none does); two subplots with linked x
!< show the same x range although their data do not; unlinked, they do not; a window that first appears after the
!< layout was built lands in the node given by ig_set_next_window_dock.
use, intrinsic :: iso_c_binding, only : c_int
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, ig_begin, ig_dock_id, ig_dock_layout_begin, ig_dock_layout_end, ig_dock_space, &
                   ig_dock_split, ig_dock_window, ig_end, ig_set_next_window_dock, ig_text, ig_window_dock,   &
                   ip_begin_plot, ip_begin_subplots, ip_end_plot, ip_end_subplots, ip_line, ip_setup_axes
use figure_cimplot, only : im_plot_rect, ImPlot_GetPlotLimits
use figure_testing, only : test_plot_tick

implicit none
integer(int32), parameter     :: FRAMES = 20_int32 !< Frames run.
type(app_object)              :: app               !< Application.
logical                       :: test_passed(6)    !< Per-check outcome.
character(len=:), allocatable :: label             !< A tick label.
integer(int32)                :: nticks(2)         !< Ticks: formatted axis, default axis.
logical                       :: all_formatted     !< Every tick of the formatted axis starts with 'T='.
logical                       :: any_default       !< ... and some tick of the default axis does.
type(im_plot_rect)            :: linked(2)         !< x limits of the two linked subplots.
type(im_plot_rect)            :: unlinked(2)       !< ... of two unlinked ones.
integer(int32)                :: root, left, right !< Dock nodes.
integer(int32)                :: late_node         !< Node the late window is in.
logical                       :: late_docked       !< The late window is docked.
logical                       :: drawn_subplots(2) !< ip_begin_subplots returned true.
integer(int32)                :: frame             !< Frame counter.
integer(int32)                :: k                 !< Counter.

late_node = 0_int32
late_docked = .false.
call app%init_headless(1000_int32, 800_int32)
do frame = 1_int32, FRAMES
   if (.not. app%next_frame()) error stop 'figure_test_plots: next_frame returned false in headless mode'
   root = ig_dock_id('main')
   if (ig_dock_layout_begin(root)) then
      call ig_dock_split(root, 'left', 0.5_real64, left, right)
      call ig_dock_window('Plots', left)
      call ig_dock_layout_end(root)
   endif
   call ig_dock_space(root)
   if (ig_begin('Plots')) then
      if (ip_begin_plot('formatted', height=200.0_real64)) then
         call ip_setup_axes('x', 'force', yformat='T=%.4f')
         call ip_line('f', [0.0_real64, 1.0_real64], [-3781.312_real64, -3781.318_real64])
         all_formatted = .true.
         call test_plot_tick('y', 1_int32, label, nticks(1))
         do k = 1_int32, nticks(1)
            call test_plot_tick('y', k, label)
            all_formatted = all_formatted .and. index(label, 'T=') == 1
         enddo
         call ip_end_plot()
      endif
      if (ip_begin_plot('default', height=200.0_real64)) then
         call ip_setup_axes('x', 'force')
         call ip_line('f', [0.0_real64, 1.0_real64], [-3781.312_real64, -3781.318_real64])
         any_default = .false.
         call test_plot_tick('y', 1_int32, label, nticks(2))
         do k = 1_int32, nticks(2)
            call test_plot_tick('y', k, label)
            any_default = any_default .or. index(label, 'T=') == 1
         enddo
         call ip_end_plot()
      endif
      drawn_subplots(1) = ip_begin_subplots('linked', 1_int32, 2_int32, height=200.0_real64, link_x=.true.)
      if (drawn_subplots(1)) then
         do k = 1_int32, 2_int32
            if (ip_begin_plot('##linked'//achar(48 + k))) then
               call ip_line('d', [0.0_real64, 10.0_real64**(k - 1)], [0.0_real64, 1.0_real64])
               call ImPlot_GetPlotLimits(-1_c_int, -1_c_int, linked(k))
               call ip_end_plot()
            endif
         enddo
         call ip_end_subplots()
      endif
      drawn_subplots(2) = ip_begin_subplots('unlinked', 1_int32, 2_int32, height=200.0_real64)
      if (drawn_subplots(2)) then
         do k = 1_int32, 2_int32
            if (ip_begin_plot('##unlinked'//achar(48 + k))) then
               call ip_line('d', [0.0_real64, 10.0_real64**(k - 1)], [0.0_real64, 1.0_real64])
               call ImPlot_GetPlotLimits(-1_c_int, -1_c_int, unlinked(k))
               call ip_end_plot()
            endif
         enddo
         call ip_end_subplots()
      endif
   endif
   call ig_end()
   if (frame >= 10_int32) then                       ! a window that appears after the layout was built
      call ig_set_next_window_dock(right)
      if (ig_begin('Late')) then
         call ig_text('appeared on frame 10')
         call ig_window_dock(late_node, late_docked)
      endif
      call ig_end()
   endif
enddo
call app%destroy()

test_passed(1) = nticks(1) > 1_int32 .and. all_formatted                       ! every label follows the format
test_passed(2) = nticks(2) > 1_int32 .and. .not. any_default                   ! the default does not
test_passed(3) = all(drawn_subplots)                                           ! the figures are drawn
test_passed(4) = abs(linked(1)%X%Max - linked(2)%X%Max) < 1.0e-9_real64 .and. linked(1)%X%Max > 9.99_real64 ! linked,
                                                                    ! fitted to the data (ImPlot gives linked axes none)
test_passed(5) = unlinked(1)%X%Max < 5.0_real64 .and. unlinked(2)%X%Max > 5.0_real64     ! unlinked: their own
test_passed(6) = late_docked .and. late_node == right                          ! the late window in its node

write(output_unit, '(A,*(L2))') 'figure_test_plots checks:', test_passed
if (.not. all(test_passed)) write(output_unit, '(A,2I3,A,2L2,A,4F9.3,A,2I12,L2)') 'ticks', nticks, &
   ', formatted/default', all_formatted, any_default, ', x max linked/unlinked', linked(1)%X%Max, linked(2)%X%Max, &
   unlinked(1)%X%Max, unlinked(2)%X%Max, ', late node/right/docked', late_node, right, late_docked
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1
endprogram figure_test_plots
