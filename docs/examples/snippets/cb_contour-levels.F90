levels = ip_contour_levels(f, 8_int32)                  ! about 8 round numbers inside f's range, as nlevels=8 picks
call ip_contour_lines(f, 0.0_real64, 2.0_real64, 0.0_real64, 1.0_real64, levels, sx, sy, first) ! the lines, not drawn
do i = 1_int32, size(levels, kind=int32)
   write(output_unit, '(A,F6.2,A,I0,A)') 'level ', levels(i), ': ', (first(i + 1) - first(i)) / 2, ' segments'
enddo
