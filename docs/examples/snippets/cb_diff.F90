!< cb_diff, cookbook: what changed between two versions of an input file.
program cb_diff
!< cb_diff, cookbook: what changed between two versions of an input file, drawn as a diff and reported line by line.
!< With `--test`, headless: the lines printed.
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object, code_diff, code_diff_lines, code_language, ig_begin, ig_end, ig_separator, &
                   ig_set_next_window, ig_text, language_object

implicit none
character(len=*), parameter :: LF = achar(10)   !< Line feed.
character(len=*), parameter :: OLD = '[fluid-properties]'//LF//' reynolds number = 1000'//LF//' mach number = 0.3'// &
                                     LF//LF//'[output-parameters]'//LF//' save frequency = 100'//LF !< Before.
character(len=*), parameter :: NEW = '[fluid-properties]'//LF//' reynolds number = 5000'//LF//' mach number = 0.3'// &
                                     LF//LF//'[output-parameters]'//LF//' save frequency = 100'//LF//            &
                                     ' restart file = RST/r'//LF !< After.
type(app_object)            :: app              !< Application.
type(language_object)       :: input            !< The language of both.
integer(int32), allocatable :: added(:)         !< Lines of NEW added.
integer(int32), allocatable :: removed(:)       !< Lines of OLD removed.
character(len=16)           :: arg              !< `--test`: headless.
character(len=64)           :: summary          !< What changed, as text.

call get_command_argument(1, arg)
call code_diff_lines(OLD, NEW, added, removed)     ! no frame needed: a task may call it
write(summary, '(I0,A,I0,A)') size(removed), ' line(s) removed, ', size(added), ' added'
if (trim(arg) == '--test') then
   write(output_unit, '(A)') trim(summary)
   write(output_unit, '(A,*(1X,I0))') 'removed from the old file:', removed
   write(output_unit, '(A,*(1X,I0))') 'added in the new file:', added
   stop
endif
input = code_language('input')
call app%init('FIGURE: a diff', 760_int32, 300_int32)
do while (app%next_frame())
   call ig_set_next_window(10.0_real64, 10.0_real64, 740.0_real64, 280.0_real64, always=.true.)
   if (ig_begin('case.input: before and after')) then
      call ig_text(trim(summary))
      call ig_separator()
      call code_diff('diff', OLD, NEW, side_by_side=.true., language=input)
   endif
   call ig_end()
enddo
call app%destroy()
endprogram cb_diff
