!< cb_dnd, cookbook: cases dragged from a tree onto a plot, which plots each case dropped on it; a bin takes them back.
program cb_dnd
!< cb_dnd, cookbook: cases dragged from a tree onto a plot, which plots each case dropped on it; a bin takes them back.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_begin_table, ig_button, ig_drag_source, ig_dragging, ig_drop_target,  &
                   ig_end, ig_end_table, ig_set_next_window, ig_table_next_column, ig_table_next_row,              &
                   ig_table_setup_column, ig_text_disabled, ig_tree_node, ig_tree_pop, ip_begin_plot,              &
                   ip_drop_target, ip_end_plot, ip_line, ip_setup_axes

implicit none
integer(int32),   parameter :: CASES = 4_int32                                     !< Cases in the tree.
integer(int32),   parameter :: N = 200_int32                                       !< Points of a residual history.
character(len=*), parameter :: NAME(CASES) = ['re1e5-coarse', 're1e5-fine  ', 're1e6-coarse', 're1e6-fine  ']
real(real64),     parameter :: RATE(CASES) = [0.030_real64, 0.018_real64, 0.024_real64, 0.012_real64] !< Decay rates.
type(app_object)              :: app       !< Application.
character(len=:), allocatable :: payload   !< A case dropped.
logical                       :: shown(CASES) !< Cases plotted.
real(real64)                  :: it(N)     !< Iterations.
real(real64)                  :: res(N)    !< A residual history.
integer(int32)                :: c         !< Case.
integer(int32)                :: i         !< Point.

shown = .false.
it = [(real(i, real64), i = 1_int32, N)]
call app%init('FIGURE: drag and drop', 720_int32, 420_int32)
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 700.0_real64, 400.0_real64)
   if (ig_begin('Cases')) then
      if (ig_begin_table('layout', 2_int32)) then
         call ig_table_setup_column('cases', width=170.0_real64)
         call ig_table_setup_column('plot')
         call ig_table_next_row()
         call ig_table_next_column()
         !region source
         if (ig_tree_node('cases', default_open=.true.)) then
            do c = 1_int32, CASES
               if (ig_tree_node(trim(NAME(c)), leaf=.true., selected=shown(c))) call ig_tree_pop()
               if (ig_drag_source('case', trim(NAME(c)))) continue   ! the node carries its name
            enddo
            call ig_tree_pop()
         endif
         if (ig_button('Bin')) shown = .false.                        ! a click empties the plot
         if (ig_drop_target('case', payload)) call show(payload, .false.) ! a case dropped here leaves it
         if (ig_dragging('case')) call ig_text_disabled('drop on the plot')
         !endregion source
         call ig_table_next_column()
         !region plot
         if (ip_begin_plot('residuals', height=-1.0_real64)) then
            call ip_setup_axes('iteration', 'residual', auto_fit=.true.)
            do c = 1_int32, CASES
               if (.not. shown(c)) cycle
               res = exp(-RATE(c) * it)
               call ip_line(trim(NAME(c)), it, res)
            enddo
            if (ip_drop_target('case', payload)) call show(payload, .true.) ! a case dropped here is plotted
            call ip_end_plot()
         endif
         !endregion plot
         call ig_end_table()
      endif
   endif
   call ig_end()
enddo
call app%destroy()
contains
   subroutine show(case_name, on)
   !< Plot (on) or remove the case named `case_name`.
   character(len=*), intent(in) :: case_name !< Its name.
   logical,          intent(in) :: on        !< Plotted.
   integer(int32)               :: k         !< Case.

   do k = 1_int32, CASES
      if (trim(NAME(k)) == case_name) shown(k) = on
   enddo
   endsubroutine show
endprogram cb_dnd
