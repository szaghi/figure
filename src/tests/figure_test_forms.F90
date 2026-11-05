!< figure_test_forms, the form widgets (text and integer fields, item width) driven by synthetic input, headless.
program figure_test_forms
!< figure_test_forms, the form widgets (text and integer fields, item width) driven by synthetic input, headless.
!<
!< Each field is clicked, its text selected (ctrl+a) and replaced by typing, then confirmed with enter; the checks read
!< the Fortran variables bound to the fields after the frames have consumed the input.
use, intrinsic :: iso_fortran_env, only : int32, real64, output_unit
use figure, only : app_object, ig_begin, ig_end, ig_input, ig_input_text, ig_item_rect, ig_set_next_item_width, &
                   ig_set_next_window, ImGuiInputTextFlags_CharsNoBlank
use figure_testing, only : test_click, test_item_center, test_key, test_type

implicit none
integer(int32), parameter :: FRAMES = 80_int32  !< Frames run.
type(app_object)          :: app                !< Application.
logical                   :: test_passed(6)     !< Per-check outcome.
character(len=16)         :: grid_file          !< A text field.
character(len=4)          :: short              !< A text field of capacity 4.
character(len=12)         :: no_blank           !< A text field that refuses blanks.
character(len=8)          :: hinted             !< An empty field with a hint, never edited.
integer(int32)            :: levels             !< An integer field.
real(real64)              :: at(2, 4)           !< Centre of each field [pixels].
real(real64)              :: x0, y0, x1, y1     !< An item's rectangle.
real(real64)              :: narrow_width       !< Width of the field after ig_set_next_item_width(120).
integer(int32)            :: edits(4)           !< Frames on which each field reported an edit.
integer(int32)            :: hint_edits         !< Frames on which the hinted field reported an edit.
integer(int32)            :: frame              !< Frame counter.

grid_file = 'CC/cc'
short = ''
no_blank = ''
hinted = ''
levels = 1_int32
edits = 0_int32
hint_edits = 0_int32
narrow_width = 0.0_real64
call app%init_headless(800_int32, 600_int32)
do frame = 1_int32, FRAMES
   if (.not. app%next_frame()) error stop 'figure_test_forms: next_frame returned false in headless mode'
   call ig_set_next_window(20.0_real64, 20.0_real64, 500.0_real64, 400.0_real64, always=.true.)
   if (ig_begin('Form')) then
      if (ig_input_text('grid file', grid_file)) edits(1) = edits(1) + 1_int32
      call test_item_center(at(1, 1), at(2, 1))
      if (ig_input_text('short', short)) edits(2) = edits(2) + 1_int32
      call test_item_center(at(1, 2), at(2, 2))
      if (ig_input_text('no blank', no_blank, flags=ImGuiInputTextFlags_CharsNoBlank)) edits(3) = edits(3) + 1_int32
      call test_item_center(at(1, 3), at(2, 3))
      if (ig_input('levels', levels)) edits(4) = edits(4) + 1_int32
      call test_item_center(at(1, 4), at(2, 4))
      if (ig_input_text('hinted', hinted, hint='root name')) hint_edits = hint_edits + 1_int32
      call ig_set_next_item_width(120.0_real64)
      if (ig_input_text('##narrow', hinted)) continue
      call ig_item_rect(x0, y0, x1, y1)
      narrow_width = x1 - x0
   endif
   call ig_end()
   select case (frame)
   case (2_int32)
      call replace(1_int32, 'MESH/grid')
   case (20_int32)
      call replace(2_int32, 'abcdefg')                  ! longer than the capacity (4)
   case (38_int32)
      call replace(3_int32, 'a b c')                    ! blanks refused
   case (56_int32)
      call replace(4_int32, '42')
   endselect
enddo
call app%destroy()

test_passed(1) = grid_file == 'MESH/grid' .and. edits(1) > 0_int32            ! typed text, written back
test_passed(2) = short == 'abcd'                                               ! cut at the capacity
test_passed(3) = no_blank == 'abc'                                             ! CharsNoBlank
test_passed(4) = levels == 42_int32 .and. edits(4) > 0_int32                   ! integer field
test_passed(5) = hinted == '' .and. hint_edits == 0_int32                      ! a hint is not a value
test_passed(6) = abs(narrow_width - 120.0_real64) < 0.5_real64                 ! ig_set_next_item_width

write(output_unit, '(A,*(L2))') 'figure_test_forms checks:', test_passed
if (.not. all(test_passed)) then
   write(output_unit, '(A)') 'grid_file "'//trim(grid_file)//'", short "'//trim(short)//'", no_blank "'// &
                             trim(no_blank)//'"'
   write(output_unit, '(A,I0,A,F0.1,A,4(I0,1X))') 'levels ', levels, ', narrow width ', narrow_width, ', edits ', edits
endif
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1

contains
   subroutine replace(k, text)
   !< Click field k, select all its text, type `text`, confirm with enter.
   integer(int32),   intent(in) :: k    !< Field.
   character(len=*), intent(in) :: text !< New text.

   call test_click(at(1, k), at(2, k))
   call test_key('ctrl', down=.true.)
   call test_key('a')
   call test_key('ctrl', down=.false.)
   call test_type(text)
   call test_key('enter')
   endsubroutine replace
endprogram figure_test_forms
