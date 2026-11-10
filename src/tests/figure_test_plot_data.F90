!< figure_test_plot_data, plot data read in place with a stride, copied only when needed, headless.
program figure_test_plot_data
!< figure_test_plot_data, plot data read in place with a stride, copied only when needed, headless.
!<
!< One plot with fixed limits draws the same six items (a line, markers, bars, a shaded area, error bars and a line of
!< uniform abscissae) from the same numbers passed eight ways: contiguous copies (the reference); components of an
!< array of derived types (`runs%cl`); the same with `int32` abscissae; `int64` abscissae with strided ordinates;
!< contiguous abscissae with strided ordinates (different strides); reversed sections (negative strides); sections of
!< a rank-3 array (`q(1, :, k)`); rows of a single-precision matrix. Each way draws every item with the extent and the
!< number of vertices of the reference (`test_drawn_extent`), gives ImPlot the stride of the data it received
!< (`test_plot_stride`) and copies exactly the arrays ImPlot cannot read in place (`test_plot_copies`): none for a
!< common stride, the abscissae when their stride or type differs from the ordinates', every array of a reversed
!< section. Empty strided sections draw nothing and report FIG_OK.
!<
!< What FIGURE receives depends on the compiler: some copy a strided actual argument into a contiguous temporary before
!< the call. The items' array dummies are ASYNCHRONOUS, and then gfortran 16.2 and nvfortran 26.9 pass rows, strided
!< and reversed sections in place and copy a component of an array of derived types (`runs%cl`); ifx 2026.2 passes
!< every one in place. These are written per compiler below (unknown compilers: the probe `same_address`, whose
!< dummy has the items' attributes), and the strides and copies of every way follow from them. A last frame draws
!< every 1-D item specific (both precisions, real and integer abscissae) with strided ordinates and checks the stride
!< ImPlot was given: the element size where the compiler made a temporary. It is the guard of nvfortran's in-place
!< passing, which comes from ASYNCHRONOUS and is not required by the standard (plots.md, "Data in place").
use, intrinsic :: iso_c_binding, only : c_intptr_t, c_loc, c_ptr
use, intrinsic :: iso_fortran_env, only : int32, int64, real32, real64, output_unit
use figure, only : FIG_OK, app_object, ig_begin, ig_end, ig_set_next_window, ip_bars, ip_begin_plot, ip_end_plot, &
                   ip_error_bars, ip_histogram2d, ip_inf_lines, ip_line, ip_scatter, ip_setup_axes_limits, ip_shaded, &
                   ip_spec, ip_stairs, ip_stems, ImPlotMarker_Circle, plot_spec_object
use figure_testing, only : test_drawn_extent, test_plot_copies, test_plot_stride

implicit none
type :: run_type
   !< A record of a run, as a solver keeps it: the plotted series are components of an array of these.
   integer(int32) :: iter = 0_int32    !< Iteration.
   integer(int64) :: step = 0_int64    !< The same, 64-bit.
   real(real64)   :: t = 0.0_real64    !< The same, real.
   real(real64)   :: cl = 0.0_real64   !< A coefficient.
   real(real64)   :: cd = 0.0_real64   !< Another one.
   real(real32)   :: t32 = 0.0_real32  !< t, single precision.
   real(real32)   :: cl32 = 0.0_real32 !< cl, single precision.
   real(real32)   :: cd32 = 0.0_real32 !< cd, single precision.
endtype run_type

integer(int32),    parameter :: N = 50_int32       !< Records.
integer(int32),    parameter :: NI = 6_int32       !< Items drawn per way.
integer(int32),    parameter :: NW = 8_int32       !< Ways.
integer(int32),    parameter :: FPW = 3_int32      !< Frames per way (measured on the last).
integer(int32),    parameter :: NP = 56_int32      !< Item specifics probed in the last frame.
character(len=10), parameter :: WAYS(NW) = [character(len=10) :: 'copies', 'in place', 'int32 x', 'int64 x', &
                                            'strides', 'reversed', 'rank 3', 'real32'] !< Their names.
real(real64),      parameter :: C(4, NI) = reshape([0.9_real64, 0.1_real64, 0.1_real64, 1.0_real64, &
                                                    0.1_real64, 0.8_real64, 0.1_real64, 1.0_real64, &
                                                    0.1_real64, 0.2_real64, 0.9_real64, 1.0_real64, &
                                                    0.8_real64, 0.7_real64, 0.1_real64, 1.0_real64, &
                                                    0.7_real64, 0.1_real64, 0.8_real64, 1.0_real64, &
                                                    0.1_real64, 0.7_real64, 0.8_real64, 1.0_real64], [4, NI]) !< Colours.
type(app_object)             :: app                !< Application.
type(run_type), target       :: runs(N)            !< The records.
real(real64),   target       :: tc(N)              !< Contiguous copies: t ...
real(real64),   target       :: clc(N)             !< ... cl ...
real(real64),   target       :: cdc(N)             !< ... cd.
real(real64),   target       :: q(3, N, 2)         !< A rank-3 array: q(1, :, 2) is t, q(2, :, 2) cl, q(3, :, 2) cd.
real(real64),   target       :: every2(2 * N)      !< cl at the odd indices.
real(real64),   target       :: cd2(2 * N)         !< cd at the odd indices.
real(real64),   target       :: t2(2 * N)          !< t at the odd indices.
integer(int32), target       :: iter32(N)          !< Iterations, contiguous.
integer(int64), target       :: step64(N)          !< Iterations, 64-bit, contiguous.
real(real32),   target       :: s32(3, N)          !< Single precision: rows t, cl, cd.
real(real64)                 :: ext(4, NI, NW)     !< Extents drawn [pixels].
integer(int32)               :: nv(NI, NW)         !< Vertices drawn.
logical                      :: found(NI, NW)      !< Something drawn.
integer(int64)               :: copies(NW)         !< Arrays copied in the measured frame.
integer(int64)               :: want(NW)           !< ... expected.
integer(int64)               :: strides(NW)        !< Stride of the line item in the measured frame [bytes].
integer(int64)               :: want_stride(NW)    !< ... expected.
logical                      :: comp_in_place      !< The compiler passes `runs%cl` in place to the items.
logical                      :: sect_in_place      !< ... a strided section of an array (a row included).
logical                      :: rev_in_place       !< ... a reversed section.
logical                      :: probed(3)          !< The same three, as `same_address` finds them.
integer(int64)               :: pst(NP)            !< Stride of each item specific probed [bytes].
integer(int64)               :: pwant(NP)          !< ... expected.
integer(int32)               :: pk                 !< Item specifics probed so far.
integer(int64)               :: rec                !< Size of a record [bytes].
integer(int32)               :: stats(NI, NW)      !< Statuses of the items in the measured frame.
integer(int32)               :: s_empty(3)         !< Statuses of empty strided sections.
logical                      :: ok(3 * (NW - 1) + 4) !< Per-check outcome.
integer(int32)               :: frame              !< Frame counter.
integer(int32)               :: w                  !< Way.
integer(int32)               :: i                  !< Counter.
real(real64)                 :: tol                !< Tolerance of an extent [pixels].

do i = 1_int32, N
   runs(i)%iter = i
   runs(i)%step = int(i, int64)
   runs(i)%t = real(i, real64)
   runs(i)%cl = 5.0_real64 + 3.0_real64 * sin(real(i, real64) / 5.0_real64)
   runs(i)%cd = 2.0_real64 + cos(real(i, real64) / 7.0_real64)
   runs(i)%t32 = real(runs(i)%t, real32)
   runs(i)%cl32 = real(runs(i)%cl, real32)
   runs(i)%cd32 = real(runs(i)%cd, real32)
enddo
tc = runs%t
clc = runs%cl
cdc = runs%cd
q = 0.0_real64
q(1, :, 2) = tc
q(2, :, 2) = clc
q(3, :, 2) = cdc
every2 = -1.0_real64
every2(1::2) = clc
t2 = -1.0_real64
t2(1::2) = tc
iter32 = runs%iter
cd2 = -1.0_real64
cd2(1::2) = cdc
step64 = runs%step
s32(1, :) = runs%t32
s32(2, :) = runs%cl32
s32(3, :) = runs%cd32
probed = [same_address(runs%cl, c_loc(runs(1)%cl)), same_address(every2(::2), c_loc(every2(1))), &
          same_address(tc(N:1:-1), c_loc(tc(N)))]
#if defined(__NVCOMPILER)
comp_in_place = .false. ! nvfortran 26.9: a component copied; sections in place only for ASYNCHRONOUS dummies
sect_in_place = .true.
rev_in_place = .true.
#elif defined(__INTEL_LLVM_COMPILER)
comp_in_place = .true.  ! ifx 2026.2: everything in place
sect_in_place = .true.
rev_in_place = .true.
#elif defined(__GFORTRAN__)
comp_in_place = .false. ! gfortran 16.2: a component of an array of derived types copied
sect_in_place = .true.
rev_in_place = .true.
#else
comp_in_place = probed(1)
sect_in_place = probed(2)
rev_in_place = probed(3)
#endif
rec = storage_size(runs(1), kind=int64) / 8_int64
want = [0_int64, 0_int64, 5_int64, 5_int64, 0_int64, 0_int64, 0_int64, 0_int64] ! integer abscissae: converted
if (sect_in_place) want(5) = 5_int64  ! contiguous x, strided y: x copied at y's stride, per item but the uniform one
if (rev_in_place) want(6) = 12_int64  ! reversed: every array (2 + 2 + 2 + 3 + 3)
want_stride = [8_int64, 8_int64, 8_int64, 8_int64, 8_int64, 8_int64, 8_int64, 4_int64]
if (comp_in_place) want_stride([2, 3]) = rec
if (sect_in_place) want_stride([4, 5]) = 16_int64
if (sect_in_place) want_stride(8) = 12_int64
if (sect_in_place) want_stride(7) = 24_int64
pwant(1:NP / 2) = 8_int64                         ! double precision: every2(::2), 16 bytes in place
pwant(NP / 2 + 1:) = 4_int64                      ! single precision: s32(2, :), 12 bytes in place
if (sect_in_place) pwant(1:NP / 2) = 16_int64
if (sect_in_place) pwant(NP / 2 + 1:) = 12_int64
pst = -1_int64
strides = -1_int64
ext = 0.0_real64
nv = 0_int32
found = .false.
copies = -1_int64
stats = -1_int32
s_empty = -1_int32

call app%init_headless(800_int32, 600_int32)
do frame = 1_int32, NW * FPW + 1_int32
   if (.not. app%next_frame()) error stop 'figure_test_plot_data: next_frame returned false in headless mode'
   w = (frame - 1_int32) / FPW + 1_int32
   call ig_set_next_window(10.0_real64, 10.0_real64, 700.0_real64, 520.0_real64, always=.true.)
   if (ig_begin('Data')) then
      if (ip_begin_plot('data', width=640.0_real64, height=460.0_real64)) then
         call ip_setup_axes_limits(0.0_real64, 51.0_real64, -1.0_real64, 11.0_real64, always=.true.)
         if (w > NW) then
            call probe_items()
            call ip_end_plot()
            call ig_end()
            cycle
         endif
         call draw_way(w, mod(frame, FPW) == 0_int32)
         call ip_end_plot()
         if (mod(frame, FPW) == 0_int32) then
            do i = 1_int32, NI
               call test_drawn_extent(C(:, i), ext(1, i, w), ext(2, i, w), ext(3, i, w), ext(4, i, w), found(i, w), &
                                      vertices=nv(i, w))
            enddo
         endif
      endif
   endif
   call ig_end()
enddo
if (app%next_frame()) continue
call app%destroy()

ok(1) = all(found(:, 1)) .and. all(ext(3, :, 1) - ext(1, :, 1) > 10.0_real64) .and. all(nv(:, 1) > 0_int32) .and. &
        all(stats(:, 1) == FIG_OK) .and. copies(1) == 0_int64 .and. strides(1) == 8_int64 ! the reference drew all
ok(2) = all(s_empty == FIG_OK)                                                         ! empty strided sections
do w = 2_int32, NW
   tol = 1.0e-3_real64
   if (WAYS(w) == 'real32') tol = 1.0_real64
   ok(2 * w - 1) = all(found(:, w)) .and. all(abs(ext(:, :, w) - ext(:, :, 1)) <= tol) .and. &
                   all(nv(:, w) == nv(:, 1)) .and. all(stats(:, w) == FIG_OK)          ! draws as the reference
   ok(2 * w) = copies(w) == want(w)                                                    ! copies only what it must
   ok(2 * (NW - 1) + 1 + w) = strides(w) == want_stride(w)                             ! reads with the stride it got
enddo
ok(3 * (NW - 1) + 3) = all(probed .eqv. [comp_in_place, sect_in_place, rev_in_place])  ! the compiler as written
ok(3 * (NW - 1) + 4) = all(pst == pwant)                                               ! every item in place

write(output_unit, '(A,*(L2))') 'figure_test_plot_data checks:', ok
write(output_unit, '(A,3L2,A,3L2,A,*(I3))') 'passed in place by the compiler: component, section, reversed', &
   comp_in_place, sect_in_place, rev_in_place, '; same_address', probed, '; strides', strides
if (.not. all(ok)) then
   do w = 1_int32, NW
      write(output_unit, '(A10,A,I4,A,I4,A,I4,A,I4)') WAYS(w), ' copies', copies(w), ' want', want(w), ' stride', &
                                                     strides(w), ' want', want_stride(w)
      do i = 1_int32, NI
         write(output_unit, '(A,I2,L2,I6,I4,4F9.2)') '   item', i, found(i, w), nv(i, w), stats(i, w), ext(:, i, w)
      enddo
   enddo
   write(output_unit, '(A,3I4)') 'empty statuses ', s_empty
   write(output_unit, '(A,3L2)') 'same_address probe: component, section, reversed', probed
   write(output_unit, '(A,*(I3))') 'probed item strides', pst
   write(output_unit, '(A,*(I3))') '              want', pwant
endif
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(ok)

contains
   function same_address(a, first) result(same)
   !< Whether the compiler passed an actual argument in place: the dummy's first element is the actual's. The dummy has
   !< the attributes of the items' (TARGET, ASYNCHRONOUS).
   real(real64), intent(in), target, asynchronous :: a(:)  !< The actual argument, as received.
   type(c_ptr),  intent(in)                       :: first !< Address of the actual's first element.
   logical                                        :: same  !< In place.

   same = transfer(c_loc(a(1)), 0_c_intptr_t) == transfer(first, 0_c_intptr_t)
   endfunction same_address

   subroutine draw_way(way, measured)
   !< The six items from the numbers passed the way `way`; in the measured frame, the copies they made.
   integer(int32), intent(in) :: way      !< Way.
   logical,        intent(in) :: measured !< The frame is measured.
   integer(int64)             :: before   !< Copies before the items.
   integer(int32)             :: s(NI)    !< Statuses.
   integer(int64)             :: line_stride !< Stride of the line item [bytes].

   before = test_plot_copies()
   select case (way)
   case (1_int32) ! contiguous copies
      call ip_line('line', tc, clc, spec=ip_spec(line_color=C(:, 1)), stat=s(1))
      line_stride = test_plot_stride()
      call ip_scatter('markers', tc, cdc, spec=markers(), stat=s(2))
      call ip_bars('bars', tc, cdc, 0.5_real64, spec=bar_spec(), stat=s(3))
      call ip_shaded('shaded', tc, clc, cdc, spec=ip_spec(fill_color=C(:, 4)), stat=s(4))
      call ip_error_bars('errors', tc, clc, cdc, spec=ip_spec(line_color=C(:, 5)), stat=s(5))
      call ip_line('uniform', clc, xscale=1.0_real64, xstart=1.0_real64, spec=ip_spec(line_color=C(:, 6)), stat=s(6))
   case (2_int32) ! components of an array of derived types
      call ip_line('line', runs%t, runs%cl, spec=ip_spec(line_color=C(:, 1)), stat=s(1))
      line_stride = test_plot_stride()
      call ip_scatter('markers', runs%t, runs%cd, spec=markers(), stat=s(2))
      call ip_bars('bars', runs%t, runs%cd, 0.5_real64, spec=bar_spec(), stat=s(3))
      call ip_shaded('shaded', runs%t, runs%cl, runs%cd, spec=ip_spec(fill_color=C(:, 4)), stat=s(4))
      call ip_error_bars('errors', runs%t, runs%cl, runs%cd, spec=ip_spec(line_color=C(:, 5)), stat=s(5))
      call ip_line('uniform', runs%cl, xscale=1.0_real64, xstart=1.0_real64, spec=ip_spec(line_color=C(:, 6)), &
                   stat=s(6))
      call ip_line('empty', runs(1:0)%t, runs(1:0)%cl, stat=s_empty(1))
      call ip_line('empty int', runs(1:0)%iter, runs(1:0)%cl, stat=s_empty(2))
      call ip_line('empty uniform', runs(1:0)%cl, stat=s_empty(3))
   case (3_int32) ! int32 abscissae
      call ip_line('line', runs%iter, runs%cl, spec=ip_spec(line_color=C(:, 1)), stat=s(1))
      line_stride = test_plot_stride()
      call ip_scatter('markers', runs%iter, runs%cd, spec=markers(), stat=s(2))
      call ip_bars('bars', runs%iter, runs%cd, 0.5_real64, spec=bar_spec(), stat=s(3))
      call ip_shaded('shaded', runs%iter, runs%cl, runs%cd, spec=ip_spec(fill_color=C(:, 4)), stat=s(4))
      call ip_error_bars('errors', runs%iter, runs%cl, runs%cd, spec=ip_spec(line_color=C(:, 5)), stat=s(5))
      call ip_line('uniform', clc, xscale=1.0_real64, xstart=1.0_real64, spec=ip_spec(line_color=C(:, 6)), stat=s(6))
   case (4_int32) ! int64 abscissae, strided ordinates
      call ip_line('line', step64, every2(::2), spec=ip_spec(line_color=C(:, 1)), stat=s(1))
      line_stride = test_plot_stride()
      call ip_scatter('markers', step64, cd2(::2), spec=markers(), stat=s(2))
      call ip_bars('bars', step64, cd2(::2), 0.5_real64, spec=bar_spec(), stat=s(3))
      call ip_shaded('shaded', step64, every2(::2), cd2(::2), spec=ip_spec(fill_color=C(:, 4)), stat=s(4))
      call ip_error_bars('errors', step64, every2(::2), cd2(::2), spec=ip_spec(line_color=C(:, 5)), stat=s(5))
      call ip_line('uniform', clc, xscale=1.0_real64, xstart=1.0_real64, spec=ip_spec(line_color=C(:, 6)), stat=s(6))
   case (5_int32) ! contiguous abscissae, strided ordinates
      call ip_line('line', tc, every2(::2), spec=ip_spec(line_color=C(:, 1)), stat=s(1))
      line_stride = test_plot_stride()
      call ip_scatter('markers', tc, cd2(::2), spec=markers(), stat=s(2))
      call ip_bars('bars', tc, cd2(::2), 0.5_real64, spec=bar_spec(), stat=s(3))
      call ip_shaded('shaded', tc, every2(::2), cd2(::2), spec=ip_spec(fill_color=C(:, 4)), stat=s(4))
      call ip_error_bars('errors', tc, every2(::2), cd2(::2), spec=ip_spec(line_color=C(:, 5)), stat=s(5))
      call ip_line('uniform', every2(::2), xscale=1.0_real64, xstart=1.0_real64, spec=ip_spec(line_color=C(:, 6)), &
                   stat=s(6))
   case (6_int32) ! reversed sections
      call ip_line('line', tc(N:1:-1), clc(N:1:-1), spec=ip_spec(line_color=C(:, 1)), stat=s(1))
      line_stride = test_plot_stride()
      call ip_scatter('markers', tc(N:1:-1), cdc(N:1:-1), spec=markers(), stat=s(2))
      call ip_bars('bars', tc(N:1:-1), cdc(N:1:-1), 0.5_real64, spec=bar_spec(), stat=s(3))
      call ip_shaded('shaded', tc(N:1:-1), clc(N:1:-1), cdc(N:1:-1), spec=ip_spec(fill_color=C(:, 4)), stat=s(4))
      call ip_error_bars('errors', tc(N:1:-1), clc(N:1:-1), cdc(N:1:-1), spec=ip_spec(line_color=C(:, 5)), stat=s(5))
      call ip_line('uniform', clc, xscale=1.0_real64, xstart=1.0_real64, spec=ip_spec(line_color=C(:, 6)), stat=s(6))
   case (7_int32) ! sections of a rank-3 array
      call ip_line('line', q(1, :, 2), q(2, :, 2), spec=ip_spec(line_color=C(:, 1)), stat=s(1))
      line_stride = test_plot_stride()
      call ip_scatter('markers', q(1, :, 2), q(3, :, 2), spec=markers(), stat=s(2))
      call ip_bars('bars', q(1, :, 2), q(3, :, 2), 0.5_real64, spec=bar_spec(), stat=s(3))
      call ip_shaded('shaded', q(1, :, 2), q(2, :, 2), q(3, :, 2), spec=ip_spec(fill_color=C(:, 4)), stat=s(4))
      call ip_error_bars('errors', q(1, :, 2), q(2, :, 2), q(3, :, 2), spec=ip_spec(line_color=C(:, 5)), stat=s(5))
      call ip_line('uniform', q(2, :, 2), xscale=1.0_real64, xstart=1.0_real64, spec=ip_spec(line_color=C(:, 6)), &
                   stat=s(6))
   case default ! rows of a single-precision matrix
      call ip_line('line', s32(1, :), s32(2, :), spec=ip_spec(line_color=C(:, 1)), stat=s(1))
      line_stride = test_plot_stride()
      call ip_scatter('markers', s32(1, :), s32(3, :), spec=markers(), stat=s(2))
      call ip_bars('bars', s32(1, :), s32(3, :), 0.5_real64, spec=bar_spec(), stat=s(3))
      call ip_shaded('shaded', s32(1, :), s32(2, :), s32(3, :), spec=ip_spec(fill_color=C(:, 4)), stat=s(4))
      call ip_error_bars('errors', s32(1, :), s32(2, :), s32(3, :), spec=ip_spec(line_color=C(:, 5)), stat=s(5))
      call ip_line('uniform', s32(2, :), xscale=1.0_real64, xstart=1.0_real64, spec=ip_spec(line_color=C(:, 6)), &
                   stat=s(6))
   endselect
   if (measured) then
      copies(way) = test_plot_copies() - before
      strides(way) = line_stride
      stats(:, way) = s
   endif
   endsubroutine draw_way

   subroutine probe_items()
   !< Every 1-D item specific with strided ordinates (real, `int32` and `int64` abscissae; double, then single
   !< precision), the stride each gave ImPlot in `pst`.

   pk = 0_int32
   call ip_line('p', t2(::2), every2(::2));                   call record()
   call ip_line('p', iter32, every2(::2));                    call record()
   call ip_line('p', step64, every2(::2));                    call record()
   call ip_line('p', every2(::2));                            call record()
   call ip_scatter('p', t2(::2), every2(::2));                call record()
   call ip_scatter('p', iter32, every2(::2));                 call record()
   call ip_scatter('p', step64, every2(::2));                 call record()
   call ip_bars('p', t2(::2), every2(::2), 0.5_real64);       call record()
   call ip_bars('p', iter32, every2(::2), 0.5_real64);        call record()
   call ip_bars('p', step64, every2(::2), 0.5_real64);        call record()
   call ip_shaded('p', t2(::2), every2(::2), cd2(::2));       call record()
   call ip_shaded('p', iter32, every2(::2), cd2(::2));        call record()
   call ip_shaded('p', step64, every2(::2), cd2(::2));        call record()
   call ip_shaded('p', t2(::2), every2(::2), 1.0_real64);     call record()
   call ip_shaded('p', iter32, every2(::2), 1.0_real64);      call record()
   call ip_shaded('p', step64, every2(::2), 1.0_real64);      call record()
   call ip_error_bars('p', t2(::2), every2(::2), cd2(::2));   call record()
   call ip_error_bars('p', iter32, every2(::2), cd2(::2));    call record()
   call ip_error_bars('p', step64, every2(::2), cd2(::2));    call record()
   call ip_error_bars('p', t2(::2), every2(::2), cd2(::2), cd2(::2)); call record()
   call ip_stairs('p', t2(::2), every2(::2));                 call record()
   call ip_stairs('p', iter32, every2(::2));                  call record()
   call ip_stairs('p', step64, every2(::2));                  call record()
   call ip_stems('p', t2(::2), every2(::2));                  call record()
   call ip_stems('p', iter32, every2(::2));                   call record()
   call ip_stems('p', step64, every2(::2));                   call record()
   call ip_inf_lines('p', every2(::2));                       call record()
   call ip_histogram2d('p', t2(::2), every2(::2));            call record()
   call ip_line('p', s32(1, :), s32(2, :));                   call record()
   call ip_line('p', iter32, s32(2, :));                      call record()
   call ip_line('p', step64, s32(2, :));                      call record()
   call ip_line('p', s32(2, :));                              call record()
   call ip_scatter('p', s32(1, :), s32(2, :));                call record()
   call ip_scatter('p', iter32, s32(2, :));                   call record()
   call ip_scatter('p', step64, s32(2, :));                   call record()
   call ip_bars('p', s32(1, :), s32(2, :), 0.5_real64);       call record()
   call ip_bars('p', iter32, s32(2, :), 0.5_real64);          call record()
   call ip_bars('p', step64, s32(2, :), 0.5_real64);          call record()
   call ip_shaded('p', s32(1, :), s32(2, :), s32(3, :));      call record()
   call ip_shaded('p', iter32, s32(2, :), s32(3, :));         call record()
   call ip_shaded('p', step64, s32(2, :), s32(3, :));         call record()
   call ip_shaded('p', s32(1, :), s32(2, :), 1.0_real64);     call record()
   call ip_shaded('p', iter32, s32(2, :), 1.0_real64);        call record()
   call ip_shaded('p', step64, s32(2, :), 1.0_real64);        call record()
   call ip_error_bars('p', s32(1, :), s32(2, :), s32(3, :));  call record()
   call ip_error_bars('p', iter32, s32(2, :), s32(3, :));     call record()
   call ip_error_bars('p', step64, s32(2, :), s32(3, :));     call record()
   call ip_error_bars('p', s32(1, :), s32(2, :), s32(3, :), s32(3, :)); call record()
   call ip_stairs('p', s32(1, :), s32(2, :));                 call record()
   call ip_stairs('p', iter32, s32(2, :));                    call record()
   call ip_stairs('p', step64, s32(2, :));                    call record()
   call ip_stems('p', s32(1, :), s32(2, :));                  call record()
   call ip_stems('p', iter32, s32(2, :));                     call record()
   call ip_stems('p', step64, s32(2, :));                     call record()
   call ip_inf_lines('p', s32(2, :));                         call record()
   call ip_histogram2d('p', s32(1, :), s32(2, :));            call record()
   endsubroutine probe_items

   subroutine record()
   !< The stride of the item specific just drawn, in `pst`.

   pk = pk + 1_int32
   pst(pk) = test_plot_stride()
   endsubroutine record

   function markers() result(spec)
   !< Circles in the second colour.
   type(plot_spec_object) :: spec !< Style.

   spec = ip_spec(marker=ImPlotMarker_Circle, marker_fill_color=C(:, 2), marker_line_color=C(:, 2), &
                  line_color=C(:, 2))
   endfunction markers

   function bar_spec() result(spec)
   !< Bars filled and outlined in the third colour.
   type(plot_spec_object) :: spec !< Style.

   spec = ip_spec(fill_color=C(:, 3), line_color=C(:, 3))
   endfunction bar_spec
endprogram figure_test_plot_data
