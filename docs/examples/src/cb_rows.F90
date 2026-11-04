!< cb_rows, cookbook: plot the rows and the columns of a matrix.
program cb_rows
!< cb_rows, cookbook: plot the rows and the columns of a matrix.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, ig_begin, ig_end, ip_begin_plot, ip_end_plot, ip_line

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

call app%init('FIGURE: rows and columns', 900_int32, 700_int32)
do while (app%next_frame())
   if (ig_begin('Probes')) then
      !region columns
      if (ip_begin_plot('Columns: read in place', height=250.0_real64)) then
         call ip_line('probe 1', t, probes(:, 1))    ! contiguous section: no copy
         call ip_line('probe 2', t, probes(:, 2))
         call ip_end_plot()
      endif
      !endregion columns
      !region rows
      if (ip_begin_plot('Rows: copied', height=250.0_real64)) then
         call ip_line('probe 1', t, history(1, :))   ! strided section: the compiler copies it into a temporary
         row = history(2, :)                         ! or copy it yourself, into a buffer you reuse
         call ip_line('probe 2', t, row)
         call ip_end_plot()
      endif
      !endregion rows
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_rows
