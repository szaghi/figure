!< cb_languages, cookbook: the languages the code editor highlights, side by side (the gallery of editor.md).
program cb_languages
!< cb_languages, cookbook: the languages the code editor highlights, side by side: FIGURE's Fortran and input files,
!< a language of the program's own, and three of the fork's (Python, C++, JSON), each in a read-only editor.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : app_object, code_editor_object, code_language, ig_begin, ig_end, ig_set_next_window, &
                   language_object

implicit none
character(len=*), parameter :: LF = achar(10)         !< Line feed.
integer(int32),   parameter :: N = 6_int32            !< Editors.
character(len=*), parameter :: TITLES(N) = [character(len=24) :: 'Fortran', 'input', 'a solver log (own)', &
                                            'Python', 'C++', 'JSON'] !< Window titles.
type(app_object)            :: app                    !< Application.
type(code_editor_object)    :: ed(N)                  !< The editors.
type(language_object)       :: lang                   !< A language of the program's own.
integer(int32)              :: k                      !< Counter.

call app%init('FIGURE: the editor''s languages', 1140_int32, 560_int32)
!region own
call lang%init('solver log', keywords=['converged', 'diverged ', 'restart  '], types=['step', 'time'], comment='#', &
               case_sensitive=.false.)
!endregion own
call ed(1)%init(code_language('fortran'))
call ed(1)%set_text('module heat'//LF//'use, intrinsic :: iso_fortran_env, only : real64'//LF//'implicit none'//LF// &
                    'contains'//LF//'   pure subroutine step(u, dt)'//LF//'   !< One explicit step.'//LF//          &
                    '   real(real64), intent(inout) :: u(:)'//LF//'   real(real64), intent(in) :: dt'//LF//      &
                    '   u(2:size(u) - 1) = u(2:size(u) - 1) + 0.5_real64*dt*(u(1:size(u) - 2) - 2*u(2:size(u) - 1))' &
                    //LF//'   endsubroutine step'//LF//'endmodule heat')
call ed(2)%init(code_language('input'))
call ed(2)%set_text('[fluid-properties]'//LF//' reynolds number = 1.5e6'//LF//' mach number = 0.3   ! subsonic'// &
                    LF//' turbulence = yes'//LF//LF//'# output'//LF//'[output-parameters]'//LF//                     &
                    ' save frequency = 100'//LF//' grid file = GRID/t.grd')
call ed(3)%init(lang)
call ed(3)%set_text('# run 7, 2026-11-10'//LF//'step 100 time 0.25 residual 1.2e-3'//LF//                        &
                    'step 200 time 0.50 residual 3.4e-5'//LF//'step 300 time 0.75 residual 8.9e-7'//LF//           &
                    'converged after 300 steps'//LF//'restart written')
call ed(4)%init(code_language('python'))
call ed(4)%set_text('import numpy as np'//LF//LF//'def residual(u: np.ndarray) -> float:'//LF//                    &
                    '    """The largest change of a step."""'//LF//'    return float(np.abs(u).max())  # L-inf'// &
                    LF//LF//'print(residual(np.ones(8)))')
call ed(5)%init(code_language('c++'))
call ed(5)%set_text('#include <vector>'//LF//LF//'// one explicit step'//LF//                                     &
                    'void step(std::vector<double> &u, double dt) {'//LF//                                      &
                    '   for (size_t i = 1; i + 1 < u.size(); ++i)'//LF//'      u[i] += 0.5 * dt * (u[i - 1] - u[i]);'// &
                    LF//'}')
call ed(6)%init(code_language('json'))
call ed(6)%set_text('{'//LF//'   "case": "cavity",'//LF//'   "reynolds": 1000,'//LF//'   "lid": [1.0, 0.0],'// &
                    LF//'   "restart": false'//LF//'}')
do k = 1_int32, N
   call ed(k)%read_only(.true.)
enddo
do while (app%next_frame())
   do k = 1_int32, N
      call ig_set_next_window(10.0_real64 + 375.0_real64 * real(modulo(k - 1_int32, 3_int32), real64), &
                              10.0_real64 + 275.0_real64 * real((k - 1_int32) / 3_int32, real64),      &
                              365.0_real64, 265.0_real64, always=.true.)
      if (ig_begin(trim(TITLES(k)))) then
         if (ed(k)%draw('code')) continue
      endif
      call ig_end()
   enddo
enddo
do k = 1_int32, N
   call ed(k)%destroy()
enddo
call app%destroy()
endprogram cb_languages
