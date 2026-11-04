!< figure_base, error handling and string conversion shared by the FIGURE modules.
module figure_base
!< figure_base, error handling and string conversion shared by the FIGURE modules.
!<
!< Procedures that can fail take an optional `stat`: if present it receives `FIG_OK` or a `FIG_ERR_*` code and
!< `figure_last_error()` gives the message; if absent, a failure prints the message and stops (`error stop`).
use, intrinsic :: iso_c_binding, only : c_associated, c_char, c_f_pointer, c_int, c_null_char, c_ptr
use, intrinsic :: iso_fortran_env, only : error_unit, int32
use figure_c_native, only : FIG_OK, fig_last_error

implicit none
private
public :: figure_check, figure_last_error, cstr

contains
   function figure_last_error() result(msg)
   !< Message of the last failed call.
   character(len=:), allocatable          :: msg    !< Message.
   character(kind=c_char), pointer        :: buf(:) !< Borrowed C buffer.
   type(c_ptr)                            :: p      !< C pointer to the message.
   integer(c_int)                         :: n      !< Message length [bytes].
   integer(int32)                         :: i      !< Counter.

   p = fig_last_error(n)
   allocate(character(len=max(n, 0_c_int)) :: msg)
   if (n <= 0_c_int .or. .not. c_associated(p)) return
   call c_f_pointer(p, buf, [n])
   do i = 1_int32, n
      msg(i:i) = buf(i)
   enddo
   endfunction figure_last_error

   subroutine figure_check(status, stat)
   !< Store `status` in `stat` if present, else stop on failure with the last error message.
   integer(c_int), intent(in)            :: status !< Status from the native layer.
   integer(int32), intent(out), optional :: stat   !< Status for the caller.

   if (present(stat)) then
      stat = status
   elseif (status /= FIG_OK) then
      write(error_unit, '(A)') 'FIGURE error: '//figure_last_error()
      error stop 1
   endif
   endsubroutine figure_check

   pure function cstr(s) result(c)
   !< `s` NUL-terminated, for cimgui/cimplot (trailing blanks kept: labels are taken verbatim).
   character(len=*), intent(in)               :: s !< Fortran string.
   character(kind=c_char, len=:), allocatable :: c !< C string.

   c = s//c_null_char
   endfunction cstr
endmodule figure_base
