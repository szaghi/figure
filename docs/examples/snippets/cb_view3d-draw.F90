call view%draw('view')                                       ! the rest of the window
if (view%clicked(mesh, cell, point)) then
   if (mesh == hull) then
      i = int(mod(cell - 1_int64, int(NI - 1, int64)), int32) + 1_int32  ! cell (i, j) of the surface
      j = int((cell - 1_int64) / (NI - 1), int32) + 1_int32
      write(text, '(A,I0,A,I0,A,F6.3,A,3F6.2,A)') 'cell (', i, ', ', j, '): Cp = ', cp(i, j), ' at (', point, ')'
   endif
endif
