call loader%result(data, stat=stat)               ! moved out of the task; the task object is free again
if (stat /= FIG_OK) then
   call app%notify('field.dat does not read: '//figure_last_error(), kind='error') ! h%fail's message
   return
endif
if (load_cancelled) then                          ! what was read is left as it was: not shown
   load_cancelled = .false.
   call app%notify('Reading field.dat was stopped', kind='warning')
   return
endif
select type (data)
type is (field_t)
   call move_alloc(data%values, field)
   call move_alloc(data%coarse, coarse)
   flx = data%lx
   fly = data%ly
   stride = data%stride
endselect
