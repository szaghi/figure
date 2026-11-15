!< cb_files, cookbook: a solver's case folder made, dated and cleared, the same on every platform.
program cb_files
!< cb_files, cookbook: a solver's case folder made, dated and cleared, the same on every platform.
!<
!< A GUI for a solver prepares its cases: a folder per case with a results folder inside, an input file written by
!< Fortran, its time set (a listing then shows a known date), the results of an earlier run cleared. No shell
!< commands: `execute_command_line('mkdir -p ...')` runs `cmd.exe` on Windows, which refuses them. Needs no window.
use, intrinsic :: iso_fortran_env, only : int32, output_unit
use figure, only : figure_file_exists, figure_file_time, figure_make_folder, figure_remove, figure_set_file_time

implicit none
character(len=*), parameter :: CASES = 'cb_files_cases' !< The cases' folder, in the working folder.
integer(int32)              :: u                         !< Unit.
!run cb_files ./cb_files

call figure_remove(CASES, recursive=.true.) ! an earlier run's
!region files
call figure_make_folder(CASES//'/plate/results')     ! the case and its missing parents
open(newunit=u, file=CASES//'/plate/heat.inp', status='replace', action='write')
write(u, '(A)') "&heat title = 'Heated plate' /"
close(u)
call figure_set_file_time(CASES//'/plate/heat.inp', '2026-10-15 09:10') ! local time, as touch -t
call figure_remove(CASES//'/plate/results', recursive=.true.)          ! an earlier run's results
!endregion files
write(output_unit, '(A,L2)') 'the input exists:', figure_file_exists(CASES//'/plate/heat.inp')
write(output_unit, '(A,A)') 'its time: ', figure_file_time(CASES//'/plate/heat.inp')
write(output_unit, '(A,L2)') 'the results are gone:', .not. figure_file_exists(CASES//'/plate/results')
call figure_remove(CASES, recursive=.true.)
endprogram cb_files
