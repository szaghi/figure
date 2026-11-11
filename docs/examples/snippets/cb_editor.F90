!< cb_editor, cookbook: edit an input file with its errors marked, its keys completed.
module cb_editor_ui
!< cb_editor_ui, the editor of cb_editor: an input file checked again whenever the user changes it.
use, intrinsic :: iso_fortran_env, only : int32, real64
use figure, only : code_editor_object, code_language, ig_begin, ig_end, ig_set_next_window, ig_text

implicit none
private
public :: KEYS, CASE_FILE, start, draw, validate

character(len=*), parameter :: LF = achar(10) !< Line feed.
!< The keys the solver reads, offered by completion.
character(len=*), parameter :: KEYS(5) = [character(len=16) :: 'reynolds number', 'mach number', 'prandtl number', &
                                          'save frequency', 'grid file']
!< The file the editor opens.
character(len=*), parameter :: CASE_FILE = '[fluid-properties]'//LF//' reynolds number = -15'//LF// &
                                           ' mach numbr = 0.3'//LF//' prandtl number = 0.71'//LF//LF// &
                                           '[output-parameters]'//LF//' save frequency = 100'//LF//LF

contains
   subroutine start(ed)
   !< The editor of an input file: its language, its text, the keys to complete, its first check.
   type(code_editor_object), intent(inout) :: ed !< Editor.

   call ed%init(code_language('input'))   ! [sections], keys, values, ! and # comments
   call ed%set_text(CASE_FILE)
   call ed%set_completions(KEYS)          ! typing "rey" offers "reynolds number"
   call validate(ed)
   endsubroutine start

   subroutine validate(ed)
   !< Check every line again and mark what is wrong: an unknown key or a value that is not a number (errors), a
   !< Reynolds number that is not positive (an error), a supersonic Mach number (a warning).
   type(code_editor_object), intent(inout) :: ed      !< Editor.
   character(len=:), allocatable           :: text    !< The text.
   character(len=:), allocatable           :: key     !< A line's key.
   character(len=:), allocatable           :: val     !< ... its value.
   real(real64)                            :: x       !< ... as a number.
   integer(int32)                          :: n, a, b, eq, ios !< Line, its start and end, its "=", a status.

   call ed%clear_marks()
   text = ed%text()
   n = 0_int32
   a = 1_int32
   do while (a <= len(text, int32))
      b = index(text(a:), LF)
      if (b == 0) b = len(text, int32) - a + 2_int32
      b = a + b - 2_int32                                ! the line is text(a:b)
      n = n + 1_int32
      eq = index(text(a:b), '=')
      if (eq > 0) then
         key = trim(adjustl(text(a:a + eq - 2)))
         val = trim(adjustl(text(a + eq:b)))
         if (all(KEYS /= key)) then
            call ed%mark(n, 'error', 'unknown key "'//key//'"')
         elseif (key /= 'grid file') then
            read(val, *, iostat=ios) x
            if (ios /= 0) then
               call ed%mark(n, 'error', key//' is a number')
            elseif (key == 'reynolds number' .and. x <= 0.0_real64) then
               call ed%mark(n, 'error', 'reynolds number must be positive')
            elseif (key == 'mach number' .and. x >= 1.0_real64) then
               call ed%mark(n, 'warning', 'supersonic: the incompressible solver ignores the mach number')
            endif
         endif
      endif
      a = b + 2_int32
   enddo
   endsubroutine validate

   subroutine draw(ed)
   !< The window: the editor, then where the cursor is.
   type(code_editor_object), intent(inout) :: ed           !< Editor.
   integer(int32)                          :: line, column !< The cursor.
   character(len=48)                       :: where        !< ... as text.

   call ig_set_next_window(10.0_real64, 10.0_real64, 560.0_real64, 280.0_real64, always=.true.)
   if (ig_begin('case.input')) then
      if (ed%draw('editor', height=-30.0_real64)) call validate(ed) ! the user changed it: check it again
      call ed%cursor(line, column)
      write(where, '(A,I0,A,I0)') 'line ', line, ', column ', column
      call ig_text(trim(where))
   endif
   call ig_end()
   endsubroutine draw
endmodule cb_editor_ui

program cb_editor
!< cb_editor, cookbook: edit an input file with its errors marked, its keys completed. With `--test`, headless: a fix
!< typed, a key completed, the marks printed before and after.
use, intrinsic :: iso_fortran_env, only : int32, output_unit, real64
use figure, only : app_object, code_editor_object
use figure_testing, only : test_key, test_run, test_type
use cb_editor_ui, only : draw, start, validate

implicit none
type(app_object)         :: app  !< Application.
type(code_editor_object) :: ed   !< The editor.
character(len=16)        :: arg  !< `--test`: headless.
integer(int32)           :: fixed !< Occurrences replaced.

call get_command_argument(1, arg)
if (trim(arg) == '--test') then
   call app%init_headless(580_int32, 300_int32)
else
   call app%init('FIGURE: an input file', 580_int32, 300_int32)
endif
call start(ed)
if (trim(arg) == '--test') then
   call frames()
   call report('opened')
   call ed%goto(2_int32, 21_int32, focus=.true.)  ! after the "-" of -15
   call frames()
   call test_key('backspace')                     ! as the user would fix it
   call frames()
   call report('after the fix')
   call ed%goto(5_int32, 1_int32, focus=.true.)   ! the empty line
   call frames()
   call test_type(' mach n')
   call frames()
   if (ed%completing()) write(output_unit, '(A)') 'completion offers a key'
   call test_key('tab')
   call frames()
   write(output_unit, '(A)') 'line 5: "'//line_of(5_int32)//'"'
   if (ed%find('numbr')) then                     ! selected, scrolled to at the next draw
      fixed = ed%replace('mach numbr', 'mach number') ! every occurrence, in one undo
      call validate(ed)
      write(output_unit, '(I0,A)') fixed, ' key renamed'
   endif
   call report('at the end')
else
   do while (app%next_frame())
      call draw(ed)
   enddo
endif
call ed%destroy()
call app%destroy()

contains
   subroutine frames()
   !< Draw four frames, then until the queued input is applied and the interface is idle (at most 30 more).
   integer(int32) :: k !< Frame.

   do k = 1_int32, 4_int32
      if (.not. app%next_frame()) return
      call draw(ed)
   enddo
   do while (test_run(30_int32))
      if (.not. app%next_frame()) exit
      call draw(ed)
   enddo
   endsubroutine frames

   subroutine report(when)
   !< The marks of the first lines.
   character(len=*), intent(in)  :: when !< When.
   character(len=:), allocatable :: msg  !< A mark's message.
   character(len=:), allocatable :: sev  !< Its severity.
   integer(int32)                :: n    !< Line.

   write(output_unit, '(A)') when//':'
   do n = 1_int32, 4_int32
      sev = ed%mark_of(n, msg)
      if (len(sev) > 0) write(output_unit, '(A,I0,A)') '  line ', n, ': '//msg
   enddo
   endsubroutine report

   function line_of(n) result(t)
   !< Line `n` of the text.
   integer(int32), intent(in)    :: n    !< Line.
   character(len=:), allocatable :: t    !< Its text.
   character(len=:), allocatable :: all  !< The text.
   integer(int32)                :: k, a, b !< Counters.

   all = ed%text()
   a = 1_int32
   do k = 1_int32, n - 1_int32
      a = a + index(all(a:), achar(10))
   enddo
   b = index(all(a:), achar(10))
   t = all(a:a + b - 2)
   endfunction line_of
endprogram cb_editor
