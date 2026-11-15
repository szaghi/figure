!< figure_test_file_api, files and folders: figure_make_folder, figure_remove, figure_set_file_time, figure_file_time,
!< figure_file_exists, on every platform (no init*: they need no window).
program figure_test_file_api
!< figure_test_file_api, files and folders: figure_make_folder, figure_remove, figure_set_file_time, figure_file_time,
!< figure_file_exists, on every platform (no init*: they need no window).
use, intrinsic :: iso_fortran_env, only : int32, output_unit
use figure, only : FIG_ERR_ARGUMENT, FIG_ERR_FAILED, FIG_OK, figure_file_exists, figure_file_time, &
                   figure_make_folder, figure_remove, figure_set_file_time

implicit none
character(len=*), parameter :: ROOT = 'figure_test_file_api.tmp' !< The test's own folder, in the working folder.
logical                     :: test_passed(14)                 !< Outcomes.
character(len=19)           :: t                               !< A time read back.
integer(int32)              :: stat                            !< Status.
integer(int32)              :: s2                              !< Another status.
integer(int32)              :: u                               !< Unit.

test_passed = .false.
call figure_remove(ROOT, recursive=.true.) ! an earlier run's

! 1. a folder and its missing parents
call figure_make_folder(ROOT//'/a/b/c', stat=stat)
test_passed(1) = stat == FIG_OK .and. figure_file_exists(ROOT//'/a/b/c')
! 2. one already there is no error
call figure_make_folder(ROOT//'/a/b/c', stat=stat)
test_passed(2) = stat == FIG_OK
! 3. parents=.false.: a missing parent is refused, nothing made
call figure_make_folder(ROOT//'/x/y', parents=.false., stat=stat)
test_passed(3) = stat == FIG_ERR_FAILED .and. .not. figure_file_exists(ROOT//'/x')
! 4. a file's time set and read back, minutes ('YYYY-MM-DD hh:mm') and seconds
open(newunit=u, file=ROOT//'/a/input.nml', status='replace', action='write')
write(u, '(A)') '&case /'
close(u)
call figure_set_file_time(ROOT//'/a/input.nml', '2026-10-15 09:10', stat=stat)
t = figure_file_time(ROOT//'/a/input.nml', stat=s2)
test_passed(4) = stat == FIG_OK .and. s2 == FIG_OK .and. t == '2026-10-15 09:10:00'
call figure_set_file_time(ROOT//'/a/input.nml', '2026-01-02 23:59:42', stat=stat)
test_passed(5) = stat == FIG_OK .and. figure_file_time(ROOT//'/a/input.nml') == '2026-01-02 23:59:42'
! 6. a folder's time
call figure_set_file_time(ROOT//'/a/b', '2026-10-15 09:05', stat=stat)
test_passed(6) = stat == FIG_OK .and. figure_file_time(ROOT//'/a/b') == '2026-10-15 09:05:00'
! 7. a time not of the form, or not a date, is refused
call figure_set_file_time(ROOT//'/a/input.nml', '15/10/2026 09:10', stat=stat)
call figure_set_file_time(ROOT//'/a/input.nml', '2026-02-30 10:00', stat=s2)
test_passed(7) = stat == FIG_ERR_ARGUMENT .and. s2 == FIG_ERR_ARGUMENT .and. &
                 figure_file_time(ROOT//'/a/input.nml') == '2026-01-02 23:59:42'
! 8. the time of a missing path: a failure, blank
t = figure_file_time(ROOT//'/missing', stat=stat)
test_passed(8) = stat == FIG_ERR_FAILED .and. t == ' '
! 9. a folder over a file is refused
call figure_make_folder(ROOT//'/a/input.nml', stat=stat)
test_passed(9) = stat == FIG_ERR_FAILED
! 10. a folder not empty is not removed without recursive
call figure_remove(ROOT//'/a', stat=stat)
test_passed(10) = stat == FIG_ERR_FAILED .and. figure_file_exists(ROOT//'/a/input.nml')
! 11. a file removed; a missing path is no error
call figure_remove(ROOT//'/a/input.nml', stat=stat)
call figure_remove(ROOT//'/a/input.nml', stat=s2)
test_passed(11) = stat == FIG_OK .and. s2 == FIG_OK .and. .not. figure_file_exists(ROOT//'/a/input.nml')
! 12. a name beyond ASCII (UTF-8)
call figure_make_folder(ROOT//'/données ∇', stat=stat)
test_passed(12) = stat == FIG_OK .and. figure_file_exists(ROOT//'/données ∇')
! 13. empty paths are refused
call figure_make_folder('', stat=stat)
call figure_remove('', stat=s2)
test_passed(13) = stat == FIG_ERR_ARGUMENT .and. s2 == FIG_ERR_ARGUMENT .and. .not. figure_file_exists('')
! 14. a tree removed
call figure_remove(ROOT, recursive=.true., stat=stat)
test_passed(14) = stat == FIG_OK .and. .not. figure_file_exists(ROOT)

write(output_unit, '(A,*(L2))') 'figure_test_file_api checks:', test_passed
write(output_unit, '(A,L1)') 'Are all tests passed? ', all(test_passed)
if (.not. all(test_passed)) error stop 1
endprogram figure_test_file_api
