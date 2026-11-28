!< figure_test_plot_style_editor, the style editor's ImPlot section on the Fortran path (figure_plot_style_editor).
program figure_test_plot_style_editor
!< figure_test_plot_style_editor, the style editor's ImPlot section on the Fortran path (figure_plot_style_editor).
!<
!< szaghi/figure#15 G2: `ig_show_style_editor`'s "ImPlot" header draws the Fortran widget, which edits the plots' style
!< store. Headless: the Dear ImGui header closed and the ImPlot one opened by clicks; then
!<
!< 1. the MinorAlpha slider dragged to its right end: `ip_get_style_var('MinorAlpha')` reads 1 (the store's, through the
!<    native layer);
!< 2. PlotBg's Auto button clicked twice: the colour made explicit (its resolved value), then automatic again;
!< 3. the explicit colour the Auto button gives is the automatic one, resolved (`ps_vec4`).
use, intrinsic :: iso_fortran_env, only : int32, real32, real64, output_unit
use figure, only : app_object, ig_set_next_window, ig_show_style_editor, ip_get_style_var
use figure_plot_style, only : PC_PLOT_BG, ps_color_named, ps_vec4
use figure_testing, only : test_click, test_drag, test_item_rect

implicit none
type(app_object) :: app            !< Application.
logical          :: test_passed(3) !< Per-check outcome.
real(real64)     :: x, y, w, h     !< An item's rectangle.
real(real64)     :: v(2)           !< A variable.
real(real32)     :: c(4), c2(4)    !< PlotBg as stored.
integer(int32)   :: n, st          !< Values, status.

test_passed = .false.
call app%init_headless(900, 1600)
call frames(3_int32)
if (test_item_rect('Style editor/Dear ImGui', x, y, w, h)) call test_click(x + 0.5_real64 * w, y + 0.5_real64 * h)
call frames(6_int32)
if (test_item_rect('Style editor/ImPlot', x, y, w, h)) call test_click(x + 0.5_real64 * w, y + 0.5_real64 * h)
call frames(6_int32)
! 1. a slider
if (test_item_rect('Style editor/MinorAlpha', x, y, w, h)) then
   call test_drag(x + 0.5_real64 * w, y + 0.5_real64 * h, x + 4.0_real64 * w, y + 0.5_real64 * h)
   call frames(8_int32)
   call ip_get_style_var('MinorAlpha', v, n)
   test_passed(1) = n == 1_int32 .and. abs(v(1) - 1.0_real64) < 1.0e-6_real64
endif
! 2. the Auto button, twice
call ps_color_named('PlotBg', 2_int32, c, st)
if (test_item_rect('Style editor/Auto##PlotBg', x, y, w, h)) then
   call test_click(x + 0.5_real64 * w, y + 0.5_real64 * h)
   call frames(6_int32)
   call ps_color_named('PlotBg', 2_int32, c2, st)
   test_passed(2) = (c(4) == -1.0_real32) .neqv. (c2(4) == -1.0_real32)
   if (c(4) == -1.0_real32) test_passed(3) = all(c2 == real(ps_vec4(PC_PLOT_BG), real32)) ! (made explicit)
   call test_click(x + 0.5_real64 * w, y + 0.5_real64 * h)
   call frames(6_int32)
   call ps_color_named('PlotBg', 2_int32, c2, st)
   test_passed(2) = test_passed(2) .and. ((c(4) == -1.0_real32) .eqv. (c2(4) == -1.0_real32))
endif
call app%destroy()

write(output_unit, '(A,*(L2))') 'figure_test_plot_style_editor checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine frames(k)
   !< `k` frames of the style editor, its window over the display.
   integer(int32), intent(in) :: k !< Frames.
   integer(int32)             :: i !< Counter.

   do i = 1_int32, k
      if (.not. app%next_frame()) error stop 'figure_test_plot_style_editor: next_frame returned false headless'
      call ig_set_next_window(0.0_real64, 0.0_real64, 900.0_real64, 1600.0_real64, always=.true.)
      call ig_show_style_editor()
   enddo
   endsubroutine frames
endprogram figure_test_plot_style_editor
