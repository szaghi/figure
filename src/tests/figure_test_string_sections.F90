!< figure_test_string_sections, sections of an array of StringiFor strings designate the right elements (#4's bug A).
program figure_test_string_sections
!< figure_test_string_sections, sections of an array of StringiFor strings designate the right elements (#4's bug A).
!<
!< gfortran (16.2.0 and earlier) takes a section of a rank-1 deferred-length character array, `names(3:4)` of
!< `character(len=:), allocatable :: names(:)`, at the array's first elements (szaghi/figure#4, bug A). An array of
!< `type(string)` is an array of a derived type, not of `character(len=:)`: its sections should not take that path
!< (szaghi/figure#15, P3). Checked as #4 shows the bug: a section in an output list and as an actual argument
!< (assumed-shape), with a unit and a non-unit stride, and the first element of a section.
!<
!< Not checked: nvfortran 26.9 fails to assign a section of an assumed-shape dummy array of such a type (a derived type
!< with a deferred-length component) to an allocatable, `inner = items(2:3)`: a crash at -O2, a huge allocation at -O0
!< with StringiFor's type. A compiler defect of its own, for any such type, recorded in P3's log.
use, intrinsic :: iso_fortran_env, only : error_unit, output_unit
use stringifor, only : string

implicit none
type(string), allocatable :: names(:)       !< Five strings.
character(len=16)         :: listed         !< A section written to a file, read back.
integer                   :: scratch        !< Scratch file unit.
logical                   :: test_passed(4) !< Per-check outcome.

names = [string('aaa'), string('bbb'), string('ccc'), string('ddd'), string('eee')]

! a section in an output list (StringiFor's defined output), to an external file: nvfortran 26.9's defined output to an
! internal file writes garbage (crashes on an array), a compiler defect of its own
open(newunit=scratch, status='scratch', form='formatted', action='readwrite')
write(scratch, '(2DT)') names(3:4)
rewind(scratch)
read(scratch, '(A)') listed
close(scratch)
test_passed(1) = listed == 'cccddd'
test_passed(2) = joined(names(3:4)) == 'ccc,ddd'
test_passed(3) = joined(names(2:4:2)) == 'bbb,ddd'
test_passed(4) = first_of(names(4:5)) == 'ddd'

write(output_unit, '(A,4L2)') 'figure_test_string_sections checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) then
   write(error_unit, '(A)') 'listed: '//trim(listed)//', names(3:4): '//joined(names(3:4))//', names(2:4:2): '// &
                            joined(names(2:4:2))//', first of names(4:5): '//first_of(names(4:5))
   error stop 1
endif
contains
   function joined(items) result(text)
   !< The items, comma-separated: the section is the actual argument of an assumed-shape dummy.
   type(string), intent(in)      :: items(:) !< Items.
   character(len=:), allocatable :: text     !< Joined text.
   integer                       :: i        !< Counter.

   text = ''
   do i = 1, size(items)
      text = text//items(i)%chars()
      if (i < size(items)) text = text//','
   enddo
   endfunction joined

   function first_of(items) result(text)
   !< The first item of a section.
   type(string), intent(in)      :: items(:) !< Items.
   character(len=:), allocatable :: text     !< Its first.

   text = items(1)%chars()
   endfunction first_of
endprogram figure_test_string_sections
