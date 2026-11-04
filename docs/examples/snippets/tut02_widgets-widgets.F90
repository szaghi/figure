if (ig_slider('cells', cells, 10_int32, 1000_int32)) continue
if (ig_slider('relaxation', relax, 0.1_real32, 1.0_real32)) continue
if (ig_slider('CFL', cfl, 0.1_real64, 2.0_real64)) continue
if (ig_input('final time', t_end, step=0.1_real64, format='%.3f')) then
   t_end = max(t_end, 0.0_real64)
endif
if (ig_checkbox('viscous', viscous)) continue
call ig_separator()
if (ig_button('Run')) runs = runs + 1_int32
call ig_same_line()
write(line, '(A,I0,A,I0,A,F5.2)') 'runs: ', runs, ', cells: ', cells, ', CFL: ', cfl
call ig_text(trim(line))
