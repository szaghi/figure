call figure_make_folder(CASES//'/plate/results')     ! the case and its missing parents
open(newunit=u, file=CASES//'/plate/heat.inp', status='replace', action='write')
write(u, '(A)') "&heat title = 'Heated plate' /"
close(u)
call figure_set_file_time(CASES//'/plate/heat.inp', '2026-10-15 09:10') ! local time, as touch -t
call figure_remove(CASES//'/plate/results', recursive=.true.)          ! an earlier run's results
