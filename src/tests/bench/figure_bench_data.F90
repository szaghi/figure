!< figure_bench_data, the per-frame data of the benchmark scenes (figure_bench_scenes), built with the same flags on
!< both paths.
module figure_bench_data
!< figure_bench_data, the per-frame data of the benchmark scenes (figure_bench_scenes), built with the same flags on
!< both paths.
!<
!< The heatmap, field and surface scenes recompute their values every frame, inside the timed frame. The test modes leave
!< this file out of their sources and link this module built apart with the compiler and flags of the default
!< test mode (fobos `bench-data-<mode>`, through `dependon`; `scripts/check_sync.py` checks the flags). A `-fortran`
!< mode inherits its default mode's, though its own flags differ (`-Mnofma`, `-fp-model precise`: the oracle's). The
!< two builds of the benchmark compute the scenes' data with the same code, and comparing them
!< (`scripts/bench_scenes.py --against`) measures the two paths alone. Before, ifx's `-fp-model precise` turned this
!< loop's vectorised `sin` and `cos` (SVML) into scalar calls: heatmap256's data took 151 M instructions on the Fortran
!< path against 61 M on the current path (szaghi/figure#16, C7).
use, intrinsic :: iso_fortran_env, only : int32, int64, real64

implicit none
private
public :: field_values

contains
   subroutine field_values(f, phase)
   !< A field's values at a phase: two waves moving one cell a frame.
   real(real64), contiguous, intent(out) :: f(:,:) !< The field.
   integer(int32),           intent(in)  :: phase  !< Frame.
   integer(int64)                        :: a, b   !< Cells.
   real(real64)                          :: c      !< A wave number.

   c = 12.0_real64 / real(size(f, 1), real64)
   do b = 1_int64, size(f, 2, kind=int64)
      do a = 1_int64, size(f, 1, kind=int64)
         f(a, b) = sin(c * real(a + phase, real64)) * cos(c * real(b, real64))
      enddo
   enddo
   endsubroutine field_values
endmodule figure_bench_data
