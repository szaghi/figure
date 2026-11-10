subroutine commit_cfl()
!< The user left the CFL field after changing it: keep a positive number, or show the last good value again.
real(real64)   :: value !< The number typed.
integer(int32) :: ios   !< Status of the read.
read(cfl_text, *, iostat=ios) value
if (ios /= 0 .or. value <= 0.0_real64) then
   call said('CFL: "'//trim(cfl_text)//'" is not a positive number')
else
   cfls(opened) = value
   call said('CFL of '//trim(cases(opened))//' set')
endif
write(cfl_text, '(F0.2)') cfls(opened)                     ! the field is not edited now: it shows this
endsubroutine commit_cfl
