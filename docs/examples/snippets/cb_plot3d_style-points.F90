do i = 1_int32, N                     ! cold blue to hot red; the hotter, the larger
   colors(:, i) = [(t(i) - 300.0_real64) / 90.0_real64, 0.25_real64, 1.0_real64 - (t(i) - 300.0_real64) / 90.0_real64, &
                   1.0_real64]
   sizes(i) = 2.0_real64 + 6.0_real64 * (t(i) - 300.0_real64) / 90.0_real64
enddo
call ip3_scatter('probes', x, y, z, spec=unlisted, colors=colors, sizes=sizes)
