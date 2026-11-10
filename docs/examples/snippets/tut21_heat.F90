!< tut21_heat, tutorial chapter 21: chapter 11's solver, which also prints the plate's mean temperature and writes snapshots.
program tut21_heat
!< tut21_heat, tutorial chapter 21: chapter 11's solver, which also prints the plate's mean temperature and writes snapshots.
!<
!< `tut21_heat CASE [--pace MS] [--snapshots K]` reads `CASE/heat.inp` (the namelist `&heat` of the studio), solves
!< Laplace's equation for the temperature on an nx x ny grid by successive over-relaxation, prints the residual and the
!< mean temperature of every iteration, and writes the field to `CASE/field.dat`. A plain Fortran program: it does not
!< use FIGURE. `--pace MS` waits MS milliseconds after each printed line, so that a run of this small case lasts long
!< enough to be watched; `--snapshots K` writes the field every K iterations to `CASE/snap_NNNNNN.dat`, listed with
!< their iterations in `CASE/snapshots.txt` (rewritten by every run).
!< Exit codes: 0 converged, 1 the input cannot be read, 2 not converged in max_iter iterations.
use, intrinsic :: iso_fortran_env, only : error_unit, int32, int64, output_unit, real64

implicit none
character(len=64)             :: title                 !< The namelist &heat, as the studio writes it.
integer(int32)                :: nx, ny, max_iter
real(real64)                  :: lx, ly, bc_value(4), body_x, body_y, body_r, body_t, omega, tolerance
character(len=12)             :: bc_kind(4)
namelist /heat/ title, nx, ny, lx, ly, bc_kind, bc_value, body_x, body_y, body_r, body_t, omega, tolerance, max_iter
real(real64), allocatable     :: t(:,:)                !< Temperature t(i, j) at x = (i - 1) dx, y = (j - 1) dy [C].
logical, allocatable          :: fixed(:,:)            !< Nodes held at a fixed temperature.
character(len=512)            :: case_dir              !< The case's folder.
character(len=256)            :: arg                   !< An argument.
character(len=256)            :: iomsg                 !< The run time's message.
real(real64)                  :: dx, dy                !< Grid spacing [m].
real(real64)                  :: ax, ay                !< Weights of the neighbours along x and y.
real(real64)                  :: residual              !< RMS change of an iteration, over the temperature range.
real(real64)                  :: change                !< A node's change.
real(real64)                  :: span                  !< Temperature range of the fixed values [C].
integer(int32)                :: pace                  !< Wait after each printed line [ms].
integer(int32)                :: every                 !< Iterations between two snapshots (0: none).
real(real64)                  :: mean                  !< The plate's mean temperature [C].
character(len=16)             :: name                  !< A snapshot's file name.
integer(int32)                :: it, i, j, u, ios, a, us

call get_command_argument(1, case_dir)
pace = 0_int32
every = 0_int32
do a = 2_int32, command_argument_count() - 1_int32
   call get_command_argument(a, arg)
   if (trim(arg) == '--pace') then
      call get_command_argument(a + 1_int32, arg)
      read(arg, *, iostat=ios) pace
   elseif (trim(arg) == '--snapshots') then
      call get_command_argument(a + 1_int32, arg)
      read(arg, *, iostat=ios) every
   endif
enddo
title = 'untitled'
nx = 48_int32; ny = 32_int32; lx = 1.5_real64; ly = 1.0_real64; max_iter = 4000_int32
bc_kind = 'fixed'; bc_value = 0.0_real64
body_x = 0.0_real64; body_y = 0.0_real64; body_r = 0.0_real64; body_t = 0.0_real64
omega = 1.8_real64; tolerance = 1.0e-6_real64
open(newunit=u, file=trim(case_dir)//'/heat.inp', status='old', action='read', iostat=ios, iomsg=iomsg)
if (ios == 0) read(u, nml=heat, iostat=ios, iomsg=iomsg)
if (ios /= 0) then
   write(error_unit, '(A)') 'heat: '//trim(case_dir)//'/heat.inp: '//trim(iomsg)
   stop 1, quiet=.true.                              ! the exit code, without a message
endif
close(u)
if (nx < 3_int32 .or. ny < 3_int32 .or. lx <= 0.0_real64 .or. ly <= 0.0_real64) then
   write(error_unit, '(A)') 'heat: the grid needs nx, ny >= 3 and lx, ly > 0'
   stop 1, quiet=.true.                              ! the exit code, without a message
endif
write(output_unit, '(A,I0,A,I0,A,F4.2)') 'heat: '//trim(title)//', grid ', nx, ' x ', ny, ', omega ', omega

allocate(t(nx, ny), fixed(nx, ny))
dx = lx / (nx - 1)
dy = ly / (ny - 1)
ax = 1.0_real64 / dx**2
ay = 1.0_real64 / dy**2
fixed = .false.
t = sum(bc_value, mask=bc_kind == 'fixed') / max(1, count(bc_kind == 'fixed'))
do j = 1_int32, ny
   do i = 1_int32, nx
      if (((i - 1) * dx - body_x)**2 + ((j - 1) * dy - body_y)**2 <= body_r**2) then
         fixed(i, j) = .true.
         t(i, j) = body_t
      endif
   enddo
enddo
call hold_sides()
span = max(1.0_real64, maxval(t, mask=fixed) - minval(t, mask=fixed))
if (every > 0_int32) open(newunit=us, file=trim(case_dir)//'/snapshots.txt', status='replace', action='write')

do it = 1_int32, max_iter
   residual = 0.0_real64
   do j = 2_int32, ny - 1_int32
      do i = 2_int32, nx - 1_int32
         if (fixed(i, j)) cycle
         change = (ax * (t(i - 1, j) + t(i + 1, j)) + ay * (t(i, j - 1) + t(i, j + 1))) / (2.0_real64 * (ax + ay)) &
                  - t(i, j)
         t(i, j) = t(i, j) + omega * change
         residual = residual + change**2
      enddo
   enddo
   call hold_sides()
   residual = sqrt(residual / ((nx - 2) * (ny - 2))) / span
   mean = sum(t) / size(t)
   write(output_unit, '(A,I6,A,ES9.3,A,F8.3)') 'iteration ', it, '  residual ', residual, '  mean ', mean
   flush(output_unit)                                ! the studio reads each line as it is printed
   call wait(pace)
   if (every > 0_int32) then
      if (mod(it, every) == 0_int32) then             ! a snapshot, and its line in the list
         write(name, '(A,I6.6,A)') 'snap_', it, '.dat'
         call write_field(trim(case_dir)//'/'//trim(name))
         write(us, '(I0,1X,A)') it, trim(name)
         flush(us)
      endif
   endif
   if (residual < tolerance) exit
enddo
if (every > 0_int32) close(us)
if (residual >= tolerance) then
   write(output_unit, '(A,I0,A,ES8.2)') 'heat: not converged in ', max_iter, ' iterations, residual ', residual
   stop 2, quiet=.true.
endif
write(output_unit, '(A,I0,A,ES8.2)') 'heat: converged in ', it, ' iterations, residual ', residual
call write_field(trim(case_dir)//'/field.dat')
write(output_unit, '(A)') 'heat: field written to field.dat'

contains
   subroutine write_field(file)
   !< The field to `file`: a comment, nx ny lx ly, then t(i, j), one row of i per j, j = 1 at the bottom.
   character(len=*), intent(in) :: file !< File.
   integer(int32)               :: uf   !< Unit.
   integer(int32)               :: jj   !< Row.

   open(newunit=uf, file=file, status='replace', action='write')
   write(uf, '(A)') '# heat: '//trim(title)//': nx ny lx ly, then t(i, j), one row of i per j, j = 1 at the bottom'
   write(uf, '(I0,1X,I0,2(1X,ES23.15))') nx, ny, lx, ly
   do jj = 1_int32, ny
      write(uf, '(*(ES14.6))') t(:, jj)
   enddo
   close(uf)
   endsubroutine write_field

   subroutine hold_sides()
   !< The sides: a fixed one at its temperature, an insulated one as its inner neighbour (no flux across it).
   if (bc_kind(1) == 'insulated') t(1, :) = t(2, :)
   if (bc_kind(2) == 'insulated') t(nx, :) = t(nx - 1, :)
   if (bc_kind(3) == 'insulated') t(:, 1) = t(:, 2)
   if (bc_kind(4) == 'insulated') t(:, ny) = t(:, ny - 1)
   if (bc_kind(1) == 'fixed') call hold(t(1, :), fixed(1, :), bc_value(1))
   if (bc_kind(2) == 'fixed') call hold(t(nx, :), fixed(nx, :), bc_value(2))
   if (bc_kind(3) == 'fixed') call hold(t(:, 1), fixed(:, 1), bc_value(3))
   if (bc_kind(4) == 'fixed') call hold(t(:, ny), fixed(:, ny), bc_value(4))
   endsubroutine hold_sides

   subroutine hold(side, held, value)
   !< A side held at `value`.
   real(real64), intent(inout) :: side(:)  !< The side's temperatures.
   logical,      intent(inout) :: held(:)  !< The side's nodes are fixed.
   real(real64), intent(in)    :: value    !< Its temperature [C].

   side = value
   held = .true.
   endsubroutine hold

   subroutine wait(ms)
   !< Wait `ms` milliseconds (standard Fortran has no sleep: the clock is read until they pass).
   integer(int32), intent(in) :: ms    !< Milliseconds.
   integer(int64)             :: start !< Clock at the start.
   integer(int64)             :: now   !< Clock now.
   integer(int64)             :: rate  !< Ticks per second.

   if (ms <= 0_int32) return
   call system_clock(start, rate)
   do
      call system_clock(now)
      if (real(now - start, real64) / real(rate, real64) * 1000.0_real64 >= ms) exit
   enddo
   endsubroutine wait
endprogram tut21_heat
