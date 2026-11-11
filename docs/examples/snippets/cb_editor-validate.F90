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
