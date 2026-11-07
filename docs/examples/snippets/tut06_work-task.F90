call ig_begin_disabled(smoother%running())
if (ig_button('Smooth the field')) call smoother%start(smooth_field, field) ! a copy of field goes to the task
call ig_end_disabled()
call ig_same_line()
if (smoother%running()) then
   call smoother%progress(fraction, msg)
   call ig_progress_bar(fraction, label=msg, width=300.0_real64) ! fraction < 0 before the first report
else
   if (smoother%done()) then
      call smoother%result(data)                     ! given back without a copy
      select type (data)
      type is (field_t)
         call move_alloc(data%v, field%v)
      endselect
      write(status, '(A,F6.4)') 'smoothed: value 500 is ', field%v(500)
      call app%notify('The field is smoothed', kind='success') ! seen even if the user looks elsewhere
   endif
   call ig_text(trim(status))
endif
