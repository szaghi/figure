call view%draw('view')                            ! the rest of the panel; the mouse orbits, pans, zooms
picked = ''
if (view%hovered(mesh, element, p)) then          ! no cost: the view knows what each pixel shows
   if (mesh == carpet_mesh) picked = 'T = '//num(temperature(p(1), p(2)))//' C at ('//num(p(1))//', '// &
                                     num(p(2))//') m'
endif
if (view%clicked(mesh, element, p)) then
   if (mesh == carpet_mesh) then
      point = p(1:2)                              ! the Result panel's probe point moves there
      call app%notify('The probe point is now at the point clicked', kind='info', seconds=3.0_real64)
   endif
endif
