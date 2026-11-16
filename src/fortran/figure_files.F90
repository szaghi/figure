!< figure_files, files and folders: make, remove, time, test, the same on every platform.
module figure_files
!< figure_files, files and folders: make, remove, time, test, the same on every platform.
!<
!< Standard Fortran opens, reads and writes files, and `inquire` tests a file, but it has no way to make a folder,
!< remove one, or set a file's time; `execute_command_line` with `mkdir -p` or `touch` works where a POSIX shell
!< runs it, not on Windows, where it runs `cmd.exe`. These procedures do it in the native layer (C++'s
!< `std::filesystem`, the system's file times), the same on Linux, macOS and Windows. Paths are UTF-8, with `/`
!< separators (also `\` on Windows); a relative path is taken from the working folder. Any thread, any time (no
!< `init*` needed).
use, intrinsic :: iso_c_binding, only : c_char, c_int
use, intrinsic :: iso_fortran_env, only : int32
use figure_base, only : figure_check
use figure_c_native, only : FIG_OK, fig_file_exists, fig_file_time, fig_make_folder, fig_remove, fig_set_file_time

implicit none
private
public :: figure_file_exists, figure_file_time, figure_make_folder, figure_remove, figure_set_file_time

contains
   recursive subroutine figure_make_folder(path, parents, stat)
   !< Make the folder `path`, and its missing parents unless `parents=.false.`; a folder already there is no error,
   !< a file there is (`FIG_ERR_FAILED`).
   character(len=*), intent(in)            :: path    !< Folder.
   logical,          intent(in),  optional :: parents !< Make the missing parents (default `.true.`, as `mkdir -p`).
   integer(int32),   intent(out), optional :: stat    !< Status: `FIG_ERR_FAILED` with the system's reason,
                                                      !< `FIG_ERR_ARGUMENT` for an empty path.
   integer(c_int)                          :: p       !< Parents flag.

   p = 1_c_int
   if (present(parents)) then
      if (.not. parents) p = 0_c_int
   endif
   call figure_check(fig_make_folder(path, len(path, c_int), p), stat)
   endsubroutine figure_make_folder

   recursive subroutine figure_remove(path, recursive, stat)
   !< Remove the file or empty folder `path`, or with `recursive=.true.` a folder and everything in it; a path that
   !< does not exist is no error (as `rm -f`), so a program clears without testing first.
   character(len=*), intent(in)            :: path      !< File or folder.
   logical,          intent(in),  optional :: recursive !< Remove a folder's content too (default `.false.`).
   integer(int32),   intent(out), optional :: stat      !< Status: `FIG_ERR_FAILED` with the system's reason (a
                                                        !< folder not empty), `FIG_ERR_ARGUMENT` for an empty path.
   integer(c_int)                          :: r         !< Recursive flag.

   r = 0_c_int
   if (present(recursive)) then
      if (recursive) r = 1_c_int
   endif
   call figure_check(fig_remove(path, len(path, c_int), r), stat)
   endsubroutine figure_remove

   recursive subroutine figure_set_file_time(path, time, stat)
   !< Set the modification time of the file or folder `path` to `time`, a local time `'YYYY-MM-DD hh:mm'` or
   !< `'YYYY-MM-DD hh:mm:ss'` (as `touch -t`): a listing shows the same time on every machine set to that time zone.
   character(len=*), intent(in)            :: path !< File or folder.
   character(len=*), intent(in)            :: time !< Local time, `'YYYY-MM-DD hh:mm[:ss]'`.
   integer(int32),   intent(out), optional :: stat !< Status: `FIG_ERR_ARGUMENT` for a time not of that form or not
                                                   !< a date, `FIG_ERR_FAILED` for a path that cannot be set.

   call figure_check(fig_set_file_time(path, len(path, c_int), time, len(time, c_int)), stat)
   endsubroutine figure_set_file_time

   recursive function figure_file_time(path, stat) result(time)
   !< The modification time of the file or folder `path`, local, `'YYYY-MM-DD hh:mm:ss'`; blank on a failure.
   character(len=*), intent(in)            :: path !< File or folder.
   integer(int32),   intent(out), optional :: stat !< Status: `FIG_ERR_FAILED` for a path that does not exist.
   character(len=19)                       :: time !< Local time.
   character(kind=c_char)                  :: buf(19) !< The native layer's characters.
   integer(c_int)                          :: s    !< Status of the call.
   integer(int32)                          :: k    !< Character.

   buf = ' '
   s = fig_file_time(path, len(path, c_int), buf)
   time = ' '
   if (s == FIG_OK) then
      do k = 1_int32, 19_int32
         time(k:k) = buf(k)
      enddo
   endif
   call figure_check(s, stat)
   endfunction figure_file_time

   recursive function figure_file_exists(path) result(exists)
   !< Whether `path` exists, a file or a folder (what `inquire(file=)` says of a folder is the compiler's choice).
   character(len=*), intent(in) :: path   !< File or folder.
   logical                      :: exists !< It exists.

   exists = fig_file_exists(path, len(path, c_int)) == 1_c_int
   endfunction figure_file_exists
endmodule figure_files
