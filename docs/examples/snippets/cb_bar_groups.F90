!< cb_bar_groups, cookbook: the cost of each phase per case as grouped and stacked bars, and the solver's state as a
!< digital signal under its residual.
program cb_bar_groups
!< cb_bar_groups, cookbook: the cost of each phase per case as grouped and stacked bars, and the solver's state as a
!< digital signal under its residual.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_end, ig_set_next_window, ip_bar_groups, ip_begin_plot, ip_digital,     &
                   ip_end_plot, ip_line, ip_setup_axes

implicit none
integer(int32),   parameter :: N = 300_int32                                          !< Iterations.
character(len=*), parameter :: PHASE(3) = ['solver   ', 'I/O      ', 'overset  '] !< The items: the phases.
real(real64),     parameter :: COST(4, 3) = reshape([12.0_real64, 30.0_real64, 55.0_real64, 104.0_real64, & ! solver
                                                     2.0_real64, 3.5_real64, 6.0_real64, 9.0_real64,       & ! I/O
                                                     3.0_real64, 8.0_real64, 11.0_real64, 26.0_real64],    & ! overset
                                                    [4, 3])                             !< Seconds: case, phase.
type(app_object) :: app       !< Application.
real(real64)     :: it(N)     !< Iterations.
real(real64)     :: res(N)    !< Residual.
real(real64)     :: writing(N) !< 1 while the solver writes its output, else 0.
integer(int32)   :: i         !< Iteration.

it = [(real(i, real64), i = 1_int32, N)]
res = exp(-it / 70.0_real64)
writing = merge(1.0_real64, 0.0_real64, mod(i_of(it), 50_int32) < 8_int32)
call app%init('FIGURE: grouped bars and a digital signal', 720_int32, 560_int32)
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 700.0_real64, 540.0_real64)
   if (ig_begin('Costs')) then
      if (ip_begin_plot('cost per case', height=170.0_real64)) then  ! group g: case g; item i: phase i
         call ip_setup_axes('case', 'seconds')
         call ip_bar_groups(PHASE, COST, group_size=0.7_real64)
         call ip_end_plot()
      endif
      if (ip_begin_plot('cost per case, stacked', height=170.0_real64)) then
         call ip_setup_axes('case', 'seconds')
         call ip_bar_groups(PHASE, COST, stacked=.true.)
         call ip_end_plot()
      endif
      if (ip_begin_plot('residual and output', height=-1.0_real64)) then
         call ip_setup_axes('iteration', 'residual')
         call ip_line('residual', it, res)
         call ip_digital('writing', it, writing)                  ! 0 or 1, drawn in a band of its own
         call ip_end_plot()
      endif
   endif
   call ig_end()
enddo
call app%destroy()
contains
   elemental function i_of(x) result(k)
   !< `x` as an integer.
   real(real64), intent(in) :: x !< A whole number.
   integer(int32)           :: k !< The integer.

   k = nint(x, int32)
   endfunction i_of
endprogram cb_bar_groups
