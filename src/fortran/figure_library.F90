!< figure_library: the root of the static library (fobos modes figure-static-*): what libfigure.a ships.
module figure_library
!< figure_library: the root of the static library (fobos modes figure-static-*): what libfigure.a ships.
!<
!< FoBiS builds a library from one target and the modules it uses. `figure` alone leaves out `figure_testing`, which
!< no part of the interface uses but every downstream test needs: this module uses both, so the archive and lib/mod
!< hold both. It exports nothing; programs `use figure` (and `use figure_testing` in their tests).
use figure, only : app_object
use figure_testing, only : test_click

implicit none
private
endmodule figure_library
