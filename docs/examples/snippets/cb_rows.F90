!< cb_rows, cookbook: plot the rows and the columns of a matrix.
program cb_rows
!< cb_rows, cookbook: plot the rows and the columns of a matrix.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_end, ig_set_next_window, ip_begin_plot, ip_end_plot, ip_line

implicit none
integer(int32), parameter :: NT = 500_int32  !< Time levels.
integer(int32), parameter :: NP = 4_int32    !< Probes.
type(app_object)          :: app             !< Application.
real(real64)              :: t(NT)           !< Time.
real(real64)              :: probes(NT, NP)  !< Probe signals, one probe per column.
real(real64)              :: history(NP, NT) !< The same, one probe per row.
real(real64)              :: row(NT)         !< Contiguous buffer for a row.
integer(int32)            :: i               !< Counter.
integer(int32)            :: p               !< Probe counter.

t = [(real(i - 1, real64) * 0.01_real64, i = 1_int32, NT)]
do p = 1_int32, NP
   probes(:, p) = exp(-0.1_real64 * real(p, real64) * t) * cos(real(p, real64) * t)
enddo
history = transpose(probes)

call app%init('FIGURE: rows and columns', 900_int32, 900_int32)
do while (app%next_frame())
   call ig_set_next_window(20.0_real64, 20.0_real64, 860.0_real64, 860.0_real64)
   if (ig_begin('Probes')) then
      if (ip_begin_plot('Columns: read in place', height=250.0_real64)) then
         call ip_line('probe 1', t, probes(:, 1))    ! contiguous section: no copy
         call ip_line('probe 2', t, probes(:, 2))
         call ip_end_plot()
      endif
      if (ip_begin_plot('Rows: read in place, with a stride', height=250.0_real64)) then
         call ip_line('probe 1', history, 1_int32, xscale=0.01_real64)  ! row 1, x = 0.01 (j - 1): no copy
         call ip_line('probe 2', history, 2_int32, xscale=0.01_real64)
         call ip_end_plot()
      endif
      if (ip_begin_plot('Rows with any x: copied', height=250.0_real64)) then
         call ip_line('probe 1', t, history(1, :))   ! strided section: the compiler copies it into a temporary
         row = history(2, :)                         ! or copy it yourself, into a buffer you reuse
         call ip_line('probe 2', t, row)
         call ip_end_plot()
      endif
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_rows
