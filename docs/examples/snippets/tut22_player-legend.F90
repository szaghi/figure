if (bands > 0_int32) then                         ! drag it to move the range, the wheel over it to zoom it
   if (ip_colormap_legend_edit('legend', cmap, t_lo, t_hi, levels=bands, height=-1.0_real64, label_format='%.0f')) &
      continue                                    ! t_lo, t_hi changed in place: the field is coloured again
else
   if (ip_colormap_legend_edit('legend', cmap, t_lo, t_hi, height=-1.0_real64, label_format='%.0f')) continue
endif
