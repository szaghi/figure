!< figure_test_sibling_libs, the owner's Fortran libraries fetched by `fobis fetch` compile and work with FIGURE's flags.
program figure_test_sibling_libs
!< figure_test_sibling_libs, the owner's Fortran libraries fetched by `fobis fetch` compile and work with FIGURE's flags.
!<
!< FIGURE's library does not use them yet (szaghi/figure#15, P3), and a FoBiS mode compiles only what a program uses: this
!< program uses the root module of each one, so that the tests modes compile every library with FIGURE's flags on each
!< compiler. One call per library checks that it links and runs: a library that fails here fails before any FIGURE layer
!< depends on it.
use, intrinsic :: iso_fortran_env, only : error_unit, output_unit
use befor64, only : b64_encode, b64_init
use face, only : colorize
use foresight, only : foresight_figure => figure_object
use foresight_format, only : fixed
use fundal, only : dev_alloc, dev_free
use penf, only : I1P, I4P, R8P, penf_init, str
use stringifor, only : string

implicit none
character(len=:), allocatable :: code          !< Base64 code.
character(len=:), allocatable :: colored       !< Colorized text.
type(string)                  :: csv           !< Text to split.
type(string), allocatable     :: tokens(:)     !< Its fields.
real(R8P), pointer            :: buffer(:)     !< FUNDAL buffer (CPU mode: host memory).
integer(I4P)                  :: ierr          !< FUNDAL error status.
type(foresight_figure)        :: plot          !< A foresight figure (its root module compiles the whole library).
logical                       :: test_passed(6) !< Per-check outcome.

call penf_init
test_passed(1) = trim(adjustl(str(n=42_I4P, no_sign=.true.))) == '42'

call b64_init
call b64_encode(n=77_I1P, code=code) ! 'M'
test_passed(2) = code == 'TQ=='

colored = colorize('x', color_fg='red')
test_passed(3) = len(colored) > 1 .and. index(colored, 'x') > 0

csv = 'a,b,c'
call csv%split(tokens=tokens, sep=',')
test_passed(4) = size(tokens) == 3
if (test_passed(4)) test_passed(4) = tokens(3)%chars() == 'c'

nullify(buffer)
call dev_alloc(fptr_dev=buffer, ubounds=[4_I4P], ierr=ierr, init_value=1._R8P)
test_passed(5) = ierr == 0 .and. associated(buffer)
if (test_passed(5)) test_passed(5) = all(buffer == 1._R8P)
call dev_free(buffer)

test_passed(6) = fixed(1.25_R8P, 2_I4P) == '1.25' .and. fixed(-0.5_R8P, 1_I4P) == '-0.5'

write(output_unit, '(A,6L2)') 'figure_test_sibling_libs checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) then
   write(error_unit, '(A)') 'checks: penf str, befor64 encode, face colorize, stringifor split, fundal alloc, foresight fixed'
   error stop 1
endif
endprogram figure_test_sibling_libs
