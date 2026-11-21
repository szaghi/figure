!< figure_test_canaries_append, the case of an nvfortran defect: `items = [items, x]`, items an array of a derived type
!< with allocatable components, gives the earlier elements wrong components (nvfortran 26.9, -O0 and -O2).
module figure_test_canaries_append
!< figure_test_canaries_append, the append canary's type and case.
implicit none
private
public :: append_wrong

type :: item_t
   !< An element with allocatable components.
   real, allocatable :: a(:) !< One component.
   real, allocatable :: b(:) !< Another.
endtype item_t

contains
   function append_wrong() result(wrong)
   !< Three elements appended with `items = [items, x]`: an element's components are not the ones it was given.
   logical                   :: wrong    !< The defect.
   type(item_t), allocatable :: items(:) !< The array grown.
   type(item_t)              :: x        !< An element.
   integer                   :: k        !< Counter.

   allocate(items(0))
   do k = 1, 3
      x%a = [real(k), real(k), real(k)]
      x%b = [10.0 * k, 10.0 * k, 10.0 * k]
      items = [items, x] ! nvf-ok: the canary
   enddo
   wrong = .false.
   do k = 1, 3
      wrong = wrong .or. any(items(k)%a /= real(k)) .or. any(items(k)%b /= 10.0 * k)
   enddo
   endfunction append_wrong
endmodule figure_test_canaries_append

!< figure_test_canaries_hoist, the case of an nvfortran defect a canary needs in a procedure of its own: with -mp at -O2,
!< `size(a)` tested in a loop of an internal procedure, `a` an allocatable of the host reallocated by the loop's calls,
!< is read once, before the loop (nvfortran 26.9).
module figure_test_canaries_hoist
!< figure_test_canaries_hoist, the size-hoisting canary's scoping unit: a procedure with internal procedures.
implicit none
private
public :: size_hoisted

contains
   function size_hoisted() result(hoisted)
   !< A loop that waits for `a` to grow (another internal procedure reallocates it at its 10th call) ran to its end.
   logical              :: hoisted !< The defect.
   real,    allocatable :: a(:)    !< The array waited for.
   integer              :: calls   !< Calls of `grow`.
   integer              :: k       !< Iterations of the loop.

   allocate(a(0))
   calls = 0
   call wait_for_a()
   hoisted = k > 11 ! 11: the 10th call grows it, the 11th test sees it
   contains
      subroutine wait_for_a()
      !< The loop: the case of the docs' self-tests waiting for a task's field.
      do k = 1, 100 ! nvf-ok: the canary
         if (size(a) > 0) exit
         call grow()
      enddo
      endsubroutine wait_for_a

      subroutine grow()
      !< `a` reallocated, at the 10th call.
      calls = calls + 1
      if (calls < 10) return
      deallocate(a)
      allocate(a(6))
      endsubroutine grow
   endfunction size_hoisted
endmodule figure_test_canaries_hoist

!< figure_test_canaries_move, the case of an nvfortran defect a canary needs in a procedure of its own: a `move_alloc`
!< into a local array of a program unit that has internal procedures leaves the array's bounds undefined
!< (nvfortran 26.9, -O0 to -O2): its elements are read only once its size is right, or a whole-array operation reads
!< outside it.
module figure_test_canaries_move
!< figure_test_canaries_move, the move_alloc canary's scoping unit: a procedure with an internal procedure.
implicit none
private
public :: moved_size_wrong

contains
   function moved_size_wrong() result(wrong)
   !< `move_alloc(a, moved)`, `moved` a local of this function, which has an internal procedure: the bounds are garbage
   !< (a size of 1, of thousands, negative), so `sum(moved)` is taken only when the size is right.
   logical              :: wrong    !< The defect.
   real,    allocatable :: a(:)     !< The array moved.
   real,    allocatable :: moved(:) !< Where it goes.
   integer              :: i        !< Counter.

   a = [(real(i), i = 1, 6)]
   call move_alloc(a, moved) ! nvf-ok: the canary
   wrong = size(moved) /= 6
   if (.not. wrong) wrong = sum(moved) /= 21.0
   call trigger()
   contains
      subroutine trigger()
      !< Any internal procedure: its presence is the trigger.
      endsubroutine trigger
   endfunction moved_size_wrong
endmodule figure_test_canaries_move

!< figure_test_canaries_select, the case of an nvfortran defect a canary needs at module level: a character parameter
!< array built with a typed array constructor makes `select case` on a function result of deferred length, in the same
!< module, see an empty selector (nvfortran 26.9, -O0 and -O2; #4).
module figure_test_canaries_select
!< figure_test_canaries_select, the module-level case of the nvfortran select-case canary.
implicit none
private
public :: selector_empty

character(len=8), parameter :: NAMES(3) = [character(len=8) :: 'Controls', 'Plots', 'Log'] !< The trigger.

contains
   function name_of(s) result(name)
   !< `s`, as a result of deferred length.
   character(len=*), intent(in)  :: s    !< A name.
   character(len=:), allocatable :: name !< The same.

   name = s
   endfunction name_of

   function selector_empty(s) result(empty)
   !< `select case` on `name_of(s)` (s not blank) took the case of an empty selector.
   character(len=*), intent(in) :: s     !< A non-blank name.
   logical                      :: empty !< The defect.

   select case (name_of(s)) ! nvf-ok: the canary
   case ('')
      empty = .true.
   case default
      empty = .false.
   endselect
   endfunction selector_empty
endmodule figure_test_canaries_select

!< figure_test_canaries, the compiler defects FIGURE works around, checked on the compiler at hand.
program figure_test_canaries
!< figure_test_canaries, the compiler defects FIGURE works around, checked on the compiler at hand.
!<
!< A canary passes while the defect its workaround exists for is still there, and fails when it is gone, naming the
!< workaround to remove (known-issues.md; szaghi/figure#4). Each one knows the compilers the defect was seen on: there
!< it prints "still needed" (the defect is there) or "fixed: remove ..." (a failure); on another compiler it prints "not
!< affected", or fails with "new on this compiler" when the defect appears there too. A defect that corrupts the heap
!< (Bug B) is run in a child process: this program again, with the argument `--probe-ctor`; not on Windows, where such a
!< child can hang instead of ending (Platforms run 43749233755: the job hung until it was cancelled).
use, intrinsic :: iso_fortran_env, only : compiler_options, compiler_version, output_unit
use figure_test_canaries_append, only : append_wrong
use figure_test_canaries_hoist, only : size_hoisted
use figure_test_canaries_move, only : moved_size_wrong
use figure_test_canaries_select, only : selector_empty

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
   if (on_windows()) then ! its child corrupts its heap: on Windows it may never end (Platforms run 43749233755)
      write(output_unit, '(A)') '  not probed on Windows: Bug B, a constructor over a deferred-length string, as an '// &
                                'argument (its child can hang there)'
   else
      call report('Bug B, a constructor over a deferred-length string, as an argument', ['gfortran'], ctor_defect(), &
                  'process arguments filled element by element (docs/examples/src/tut12_run.F90)')
   endif
   call report('char(i) of a variable i, assigned to a deferred-length string', ['nvfortran'], char_defect(), &
               'the fixed-length buffer of the utf8 helpers (docs/examples/src/gallery.F90, src/tests/figure_test_text.F90)')
   call report('select case on a deferred-length function result, with a typed character constructor in the module', &
               ['nvfortran'], selector_empty('Plots only'), &
               'the layout''s name assigned before select case (src/tests/figure_test_app.F90, '// &
               'docs/examples/src/tut24_windows.F90 to tut26_clip.F90)')
   call report('move_alloc into a local of a program unit with internal procedures: a wrong size', ['nvfortran'], &
               moved_size_wrong(), 'the tasks modules'' hand_over (docs/examples/src/tut15_task.F90 to tut26_clip.F90)')
   call report('items = [items, x], a derived type with allocatable components: wrong components', ['nvfortran'], &
               append_wrong(), 'the runs appended through a copy (docs/examples/src/tut21_tables.F90 to tut26_clip.F90)')
   if (openmp() .and. optimized()) then ! the defect needs -O2 and -mp: tests-nvf-acc (no OpenMP) and fpm (no -O) do not
                                        ! probe it
      call report('size of a host''s array, tested in a loop whose calls reallocate it, read once (-mp)', ['nvfortran'], &
                  size_hoisted(), 'the docs'' self-tests'' field_read (docs/examples/src/tut17_tested.F90 to tut26_clip.F90)')
   else
      write(output_unit, '(A)') '  not probed without OpenMP and -O2: the size of a host''s array read once in a loop'
   endif
   call report('execute_command_line(wait=.true.) under -Munixlogical', ['nvfortran'], wait_defect(), &
               'the waits left out in src/tests/figure_test_files.F90')
   write(output_unit, '(A,L1)') 'Are all tests passed? ', .not. failed
   if (failed) error stop 1
   endsubroutine canaries

   function openmp() result(on)
   !< Compiled with OpenMP (conditional compilation: the `!$` line is a statement only then).
   logical :: on !< OpenMP on.

   on = .false.
   !$ on = .true.
   endfunction openmp

   function optimized() result(on)
   !< Compiled at -O2 or above (-O, -O2, -O3, -O4, -fast), by the options this file was compiled with.
   logical                       :: on      !< Optimized.
   character(len=:), allocatable :: options !< The options, blank-delimited.
   integer                       :: k       !< Counter.
   character(len=*), parameter   :: LEVELS(5) = [' -O   ', ' -O2  ', ' -O3  ', ' -O4  ', ' -fast'] !< Levels.

   options = ' '//compiler_options()//' '
   on = .false.
   do k = 1, size(LEVELS)
      on = on .or. index(options, trim(LEVELS(k))//' ') > 0
   enddo
   endfunction optimized

   function on_windows() result(windows)
   !< Windows, by its OS variable (set in every Windows process, MSYS2's included).
   logical            :: windows !< It is Windows.
   character(len=32)  :: os      !< The variable.
   integer            :: length  !< Its length.
   integer            :: status  !< 0: set.

   call get_environment_variable('OS', os, length, status)
   windows = status == 0 .and. trim(os) == 'Windows_NT'
   endfunction on_windows

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
