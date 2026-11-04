x = [((real(i, real64) - 0.5_real64) * 1.5_real64 / real(NX, real64), i = 1_int32, NX)]
y = [((real(j, real64) - 0.5_real64) / real(NY, real64), j = 1_int32, NY)]
do j = 1_int32, NY
   do i = 1_int32, NX
      f(i, j) = exp(-((x(i) - 0.25_real64)**2 + (y(j) - 0.75_real64)**2) / 0.02_real64) ! peak at top left
   enddo
enddo
