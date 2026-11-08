i = 1_int32 + nint(probe_x / (flx / (size(field, 1) - 1)), int32)
i0 = max(1_int32, i - 2_int32)
i1 = min(size(field, 1, kind=int32), i + 2_int32)
allocate(y(0), mean(0), below(0), above(0))
do j = 1_int32, size(field, 2, kind=int32), 4_int32
   k = size(y) + 1_int32
   y = [y, (j - 1) * dy]
   mean = [mean, sum(field(i0:i1, j)) / (i1 - i0 + 1)]
   below = [below, mean(k) - minval(field(i0:i1, j))]
   above = [above, maxval(field(i0:i1, j)) - mean(k)]
enddo
write(title, '(A,F5.3,A)') 'Along x = ', probe_x, ' m###profile' ! ### : the title changes, the id stays
if (ip_begin_plot(trim(title), width=-1.0_real64, height=-1.0_real64)) then
   call ip_setup_axes('y [m]', 'T [C]', auto_fit=.true.)
   call ip_line('T', field, i, xscale=dy)        ! the column i of the field, read in place
   call ip_error_bars('5 columns: mean, least, greatest', y, mean, below, above, spec=ip_spec(size=5.0_real64))
   call ip_end_plot()
endif
