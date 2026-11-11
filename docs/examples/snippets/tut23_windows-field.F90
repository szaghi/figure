! the cells' edges: half a spacing beyond the first and last nodes
call ip_field_image('##t', shown_field, -0.5_real64 * dx, cx + 0.5_real64 * dx, -0.5_real64 * dy, &
                    cy + 0.5_real64 * dy, colormap=cmap, vmin=t_lo, vmax=t_hi, changed=recolour)
recolour = .false.                             ! coloured: until the values, the range or the map change
