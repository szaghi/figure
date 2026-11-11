if (ig_slider('tolerance', inp%tolerance, 1.0e-10_real64, 1.0e-2_real64, format='%.1e', scale='log')) &
   changing = .true.                            ! a decade per equal stretch of the slider
