!< cb_in_place, cookbook: plot the history a solver keeps, read in place: components of an array of derived types with
!< integer iterations, matrix rows, every tenth sample.
program cb_in_place
!< cb_in_place, cookbook: plot the history a solver keeps, read in place: components of an array of derived types with
!< integer iterations, matrix rows, every tenth sample.
!<
!< A solver keeps one record per iteration (`runs(k)%iter`, `%cl`, `%cd`) and the pressure at three probes as the rows
!< of a matrix. The plots read them where they are, with ImPlot's stride. `cb_in_place --check` opens no window: it
!< draws the plots headless and prints, per item, how many arrays FIGURE copied and the stride ImPlot read with.
use, intrinsic :: iso_fortran_env, only : int32, int64, real64, output_unit
use figure, only : app_object, ig_begin, ig_end, ig_set_next_window, ip_begin_plot, ip_end_plot, ip_line
use figure_testing, only : test_plot_copies, test_plot_stride
implicit none
type :: run_record
   !< What the solver keeps of an iteration.
   integer(int32) :: iter = 0_int32  !< Iteration.
   real(real64)   :: cl = 0.0_real64 !< Lift coefficient.
   real(real64)   :: cd = 0.0_real64 !< Drag coefficient.
endtype run_record
integer(int32), parameter :: N = 400_int32       !< Iterations.
type(app_object)          :: app                 !< Application.
type(run_record), target  :: runs(N)             !< One record per iteration.
real(real64),     target  :: probes(3, N)        !< Pressure at three probes: one row each.
real(real64),     target  :: time(N)             !< Physical time of each iteration [s].
character(len=16)         :: arg                 !< First argument.
logical                   :: check               !< --check: headless, print what was copied.
integer(int64)            :: copies(4)           !< Arrays FIGURE copied, per item.
integer(int64)            :: stride(4)           !< Stride ImPlot read with, per item [bytes].
integer(int64)            :: before              !< Copies before an item.
integer(int32)            :: frame               !< Frame counter.
integer(int32)            :: k                   !< Counter.
do k = 1_int32, N
   runs(k) = run_record(k, 0.8_real64 + 0.2_real64 * exp(-k / 60.0_real64) * cos(k / 9.0_real64), &
                        0.05_real64 + 0.1_real64 * exp(-k / 80.0_real64))
   time(k) = 1.0e-3_real64 * k
   probes(:, k) = [1.0_real64, 0.9_real64, 0.8_real64] + 0.05_real64 * sin(k / [7.0_real64, 11.0_real64, 13.0_real64])
enddo
copies = 0_int64
stride = 0_int64
call get_command_argument(1, arg)
check = trim(arg) == '--check'
if (check) then
   call app%init_headless(820_int32, 640_int32)
else
   call app%init('FIGURE: plot data in place', 820_int32, 640_int32)
endif
frame = 0_int32
do while (app%next_frame())
   frame = frame + 1_int32
   call ig_set_next_window(10.0_real64, 10.0_real64, 800.0_real64, 620.0_real64)
   if (ig_begin('History')) then
      if (ip_begin_plot('Coefficients per iteration', height=280.0_real64)) then
         before = test_plot_copies()
         call ip_line('cl', runs%iter, runs%cl) ! integer x: converted; cl read where it is
         copies(1) = test_plot_copies() - before
         stride(1) = test_plot_stride()
         call ip_line('cd', runs%iter, runs%cd)
         call ip_end_plot()
      endif
      if (ip_begin_plot('Probes', height=280.0_real64)) then
         before = test_plot_copies()
         call ip_line('probe 1', time, probes(1, :))  ! a row: time is copied at the row's stride
         copies(2) = test_plot_copies() - before
         stride(2) = test_plot_stride()
         before = test_plot_copies()
         call ip_line('probe 2', probes(2, :), xscale=1.0e-3_real64, xstart=1.0e-3_real64) ! uniform x: no copy
         copies(3) = test_plot_copies() - before
         stride(3) = test_plot_stride()
         before = test_plot_copies()
         call ip_line('probe 3, every 10th', probes(3, ::10), xscale=1.0e-2_real64, xstart=1.0e-3_real64)
         copies(4) = test_plot_copies() - before
         stride(4) = test_plot_stride()
         call ip_end_plot()
      endif
   endif
   call ig_end()
   if (check .and. frame == 3_int32) call app%quit()
enddo
call app%destroy()
if (check) then
   write(output_unit, '(A,I0,A,I0,A)') 'runs%iter, runs%cl:       ', copies(1), ' copied, stride ', stride(1), ' bytes'
   write(output_unit, '(A,I0,A,I0,A)') 'time, probes(1, :):       ', copies(2), ' copied, stride ', stride(2), ' bytes'
   write(output_unit, '(A,I0,A,I0,A)') 'probes(2, :), uniform x:  ', copies(3), ' copied, stride ', stride(3), ' bytes'
   write(output_unit, '(A,I0,A,I0,A)') 'probes(3, ::10), uniform: ', copies(4), ' copied, stride ', stride(4), ' bytes'
endif
endprogram cb_in_place
