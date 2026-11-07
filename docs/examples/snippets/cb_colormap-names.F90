call ip_colormap_names(names)
write(output_unit, '(I0,A)') size(names), ' colormaps, the first ones:'
write(output_unit, '(*(A,:,", "))') (trim(names(i)), i = 1, 6)
