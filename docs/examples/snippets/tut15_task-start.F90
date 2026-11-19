if (loader%running()) then
   call app%notify('A field is being read: open the case again when it is done', kind='warning')
   return
endif
if (loader%done()) call take_field()              ! a result not taken yet: taken, then replaced
request%file = case_dir//'/field.dat'
call loader%start(read_field, request, stat=stat) ! the task gets a copy of request
if (stat /= FIG_OK) call app%notify(figure_last_error(), kind='error')
show_result = .true.                              ! the Result panel shows the progress
