!< figure_test_canaries, the compiler defects FIGURE works around, checked on the compiler at hand.
program figure_test_canaries
!< figure_test_canaries, the compiler defects FIGURE works around, checked on the compiler at hand.
!<
!< A canary passes while the defect its workaround exists for is still there, and fails when it is gone, naming the
!< workaround to remove (known-issues.md; szaghi/figure#4). Each one knows the compilers the defect was seen on: there
!< it prints "still needed" (the defect is there) or "fixed: remove ..." (a failure); on another compiler it prints "not
!< affected", or fails with "new on this compiler" when the defect appears there too. A defect that corrupts the heap
!< (Bug B) is run in a child process: this program again, with the argument `--probe-ctor`.
use, intrinsic :: iso_fortran_env, only : compiler_version, output_unit

implicit none
character(len=:), allocatable :: compiler  !< The compiler's name: gfortran, nvfortran, ifx, other.
character(len=512)            :: argument  !< The first command argument.
logical                       :: failed    !< A canary failed.

call get_command_argument(1, argument)
if (trim(argument) == '--probe-ctor') then ! the child of the Bug B canary: the defect aborts it
   call probe_ctor()
else
   call canaries()
endif

contains
   subroutine canaries()
   !< Every canary, with its verdict; a failure stops the program.

   compiler = compiler_name()
   failed = .false.
   write(output_unit, '(A)') 'figure_test_canaries on '//compiler//' ('//compiler_version()//')'
   call report('Bug A, a section of a deferred-length character array', ['gfortran'], section_defect(), &
               'the fixed-length copies of ip_colormap_names'' sections (docs/examples/src/gallery.F90)')
   call report('Bug B, a constructor over a deferred-length string, as an argument', ['gfortran'], ctor_defect(), &
               'process arguments filled element by element (docs/examples/src/tut11_run.F90)')
   call report('char(i) of a variable i, assigned to a deferred-length string', ['nvfortran'], char_defect(), &
               'the fixed-length buffer of the utf8 helpers (docs/examples/src/gallery.F90, src/tests/figure_test_text.F90)')
   call report('execute_command_line(wait=.true.) under -Munixlogical', ['nvfortran'], wait_defect(), &
               'the waits left out in src/tests/figure_test_files.F90')
   write(output_unit, '(A,L1)') 'Are all tests passed? ', .not. failed
   if (failed) error stop 1
   endsubroutine canaries

   function compiler_name() result(name)
   !< The compiler, from compiler_version().
   character(len=:), allocatable :: name !< gfortran, nvfortran, ifx or other.
   character(len=:), allocatable :: v    !< compiler_version().

   v = compiler_version()
   if (index(v, 'GCC') > 0) then
      name = 'gfortran'
   elseif (index(v, 'nvfortran') > 0 .or. index(v, 'NVIDIA') > 0) then
      name = 'nvfortran'
   elseif (index(v, 'Intel') > 0) then
      name = 'ifx'
   else
      name = 'other'
   endif
   endfunction compiler_name

   subroutine report(what, seen_on, defect, workaround)
   !< One canary's line, and its verdict.
   character(len=*), intent(in) :: what        !< The defect.
   character(len=*), intent(in) :: seen_on(:)  !< The compilers it was seen on.
   logical,          intent(in) :: defect      !< It is there on this compiler.
   character(len=*), intent(in) :: workaround  !< The workaround it exists for.

   if (any(seen_on == compiler)) then
      if (defect) then
         write(output_unit, '(A)') '  still needed: '//what
      else
         write(output_unit, '(A)') '  fixed: remove '//workaround//' ('//what//')'
         failed = .true.
      endif
   elseif (defect) then
      write(output_unit, '(A)') '  new on this compiler: '//what//'; the workaround covers it: '//workaround
      failed = .true.
   else
      write(output_unit, '(A)') '  not affected: '//what
   endif
   endsubroutine report

   function section_defect() result(defect)
   !< Bug A: `names(3:4)` arrives as `names(1:2)` (gfortran 11 to 16.2).
   logical                       :: defect   !< The section arrived wrong.
   character(len=:), allocatable :: names(:) !< A deferred-length array.

   names = ['aaa', 'bbb', 'ccc', 'ddd', 'eee']
   defect = .not. first_is(names(3:4), 'ccc')
   endfunction section_defect

   function first_is(x, want) result(same)
   !< The first element of an assumed-shape, assumed-length dummy.
   character(len=*), intent(in) :: x(:) !< The section.
   character(len=*), intent(in) :: want !< Its expected first element.
   logical                      :: same !< It is.

   same = size(x) == 2 .and. x(1) == want
   endfunction first_is

   function ctor_defect() result(defect)
   !< Bug B, in a child process (it corrupts the heap): the child exits non-zero or prints a wrong result.
   logical            :: defect !< The child failed.
   character(len=512) :: self   !< This program.
   integer            :: estat  !< The child's exit status.
   integer            :: cstat  !< Whether it ran.
   character(len=*), parameter :: CHILD_LOG = 'figure_test_canaries.child' !< The child's output.

   call get_command_argument(0, self)
   estat = -1
   cstat = -1
   ! the child's messages (an abort, a backtrace) go to a file, removed after: the log keeps the verdict only
   call execute_command_line('"'//trim(self)//'" --probe-ctor > '//CHILD_LOG//' 2>&1', exitstat=estat, cmdstat=cstat)
   defect = cstat /= 0 .or. estat /= 0
   call remove(CHILD_LOG)
   endfunction ctor_defect

   subroutine probe_ctor()
   !< Bug B's case: `[character(len=512) :: a]` passed to a `len=*` dummy; a wrong size, length or value fails.
   character(len=:), allocatable :: a !< A deferred-length string.

   a = 'solver'
   call check_ctor([character(len=512) :: a])
   endsubroutine probe_ctor

   subroutine check_ctor(x)
   !< The constructor as the dummy sees it.
   character(len=*), intent(in) :: x(:) !< The constructor.

   if (size(x) /= 1 .or. len(x) /= 512 .or. x(1) /= 'solver') error stop 1
   endsubroutine check_ctor

   function char_defect() result(defect)
   !< `g = char(i)`, i a variable, gives g the length i (nvfortran 26.9), not 1.
   logical                       :: defect !< The length is wrong.
   character(len=:), allocatable :: g      !< A deferred-length string.
   integer                       :: i      !< A character code.

   i = 206
   g = char(i)
   defect = len(g) /= 1
   endfunction char_defect

   function wait_defect() result(defect)
   !< `execute_command_line(..., wait=.true.)` returns before the command ends (nvfortran with -Munixlogical). Probed
   !< on nvfortran only, which runs on Linux: the command is a POSIX shell's (`sleep`), which cmd.exe has not.
   logical                     :: defect                                 !< It did not wait.
   character(len=*), parameter :: MARK = 'figure_test_canaries.waited'    !< Written by the command.
   logical                     :: there                                  !< The mark exists on return.
   integer                     :: u                                      !< A unit.

   defect = .false.
   if (compiler /= 'nvfortran') return
   open(newunit=u, file=MARK, status='replace')
   close(u, status='delete')
   call execute_command_line('sleep 1 && echo > '//MARK, wait=.true.)
   inquire(file=MARK, exist=there)
   defect = .not. there
   call execute_command_line('sleep 2') ! the command ends before the mark is removed (wait absent: waits everywhere)
   inquire(file=MARK, exist=there)
   if (there) then
      open(newunit=u, file=MARK, status='old')
      close(u, status='delete')
   endif
   endfunction wait_defect

   subroutine remove(file)
   !< Remove a file, if it exists.
   character(len=*), intent(in) :: file !< The file.
   logical                      :: there !< It exists.
   integer                      :: u     !< A unit.

   inquire(file=file, exist=there)
   if (.not. there) return
   open(newunit=u, file=file, status='old')
   close(u, status='delete')
   endsubroutine remove
endprogram figure_test_canaries
