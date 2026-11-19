if (ig_button('Top')) call view%view('+z')        ! the standard views are fitted
call ig_same_line()
if (ig_button('Side')) call view%view('-y')
call ig_same_line()
if (ig_button('Fit')) call view%fit()
call ig_same_line()
if (ig_checkbox('grid', grid3d)) call view%set_mesh(carpet_mesh, edges=grid3d)
call ig_same_line()
if (ig_checkbox('cut along the probe line', cut)) then
   call view%unclip()
   if (cut) call view%clip([-1.0_real64, 0.0_real64, 0.0_real64], [probe_x, 0.0_real64, 0.0_real64]) ! keeps x < probe
endif
call ig_same_line()
call ig_text(trim(picked))
