call ig_begin_disabled(smoother%running())
if (ig_button('Smooth the field')) call smoother%start(smooth_field, field) ! a copy of field goes to the task
call ig_end_disabled()
call ig_same_line()
if (smoother%running()) then
   call smoother%progress(fraction, msg)
   write(status, '(A,A,F5.1,A)') msg, ' ', 100.0_real64 * max(fraction, 0.0_real64), ' %'
elseif (smoother%done()) then
   call smoother%result(data)                        ! given back without a copy
   select type (data)
   type is (field_t)
      call move_alloc(data%v, field%v)
   endselect
   write(status, '(A,F6.4)') 'smoothed: value 500 is ', field%v(500)
endif
call ig_text(trim(status))
