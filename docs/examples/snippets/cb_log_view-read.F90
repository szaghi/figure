call log%in_view(first, last)
write(output_unit, '(A,I0,A,A)') 'kept: ', log%count(), ', the oldest: ', log%line(1_int32)
write(output_unit, '(A,L1,A,I0,A,I0,A,A)') 'following: ', log%following(), ', in view: ', first, ' to ', last, &
                                           ', the newest: ', log%line(log%count())
